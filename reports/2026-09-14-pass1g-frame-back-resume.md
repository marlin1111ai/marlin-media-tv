# Pass 1g — native paused frame-back, resume fix — STOPPED at step 4 (more than one plausible fix point) — 2026-09-14

**Result.**
- **Pass 1f's cause is only half right.** The instrumented build confirms that a paused previous-frame step resets VLC's main clock and discards the pause date, so resume adds no delay (§2, quoted). But that is not what makes resume fail: Play re-anchors the main clock anyway.
- **What does make it fail.** After each paused step, VLC anchors its clocks at the **pause date**, and the demuxer keeps reading while paused, paced by that anchor. It reads the whole pause's worth of stream into the video decoder's queue: Stargate 33.1 s → 114.7 s of PCR in the ~20 s between the first step and Play, video fifo 1 945 packets / 38.7 MB. On Play, VLC flushes every stream except video, so it plays the read-ahead pictures, all late: 1 002 dropped in the first 20 s, and the on-screen clock goes 00:33 → 01:59 → 02:56.
- **The two controls (step 3).**
  - **No step:** resumes correctly. The pause delay is applied, 0 dropped, 0 late, and the audio renders 116 ms after the first picture.
  - **Pass 1's seek-back:** does **not** resume correctly. Its paused rebuffer loop (792 `ES_OUT_RESET_PCR`) reads ahead the same way, and Play jumps to 03:32 (0 dropped, 3 late). Pass 1f's "43 ms late" control only counted late-picture lines and missed the jump.
- **Why I stopped.** The failure crosses at least three code points (the pause-date anchor, the demux gate while paused, the resume flush that keeps video), plus the main-clock pause date as a fourth candidate. By step 4's rule I stopped and listed the candidates with their lines (§4). Steps 5–10 were not done: no patch 0020, no full rebuild, no VLC test run, no four-film matrix, no D008 or new decision, no VideoLAN draft.

**State.**
- **Working tree:** `PlayerModel.swift` carries the native back step, uncommitted, as step 1 asks.
- **Device:** Home Theater runs exactly that build, with a framework carrying no instrumentation (0 `1g:` strings).
- **libvlc:** the tree at `~/vlckit-build` is clean at `e50d9ac36a` again. `tools/vlckit-truehd/` is untouched.
- **Commits:** the evidence and this report are committed locally. Nothing pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Re-apply the 1f diff, build, install | **Done.** `git apply reports/logs/1f-playermodel-native-prevframe.diff` (12+/17−). `xcodebuild build … 'platform=tvOS,name=Home Theater'` → `** BUILD SUCCEEDED **`, `devicectl device install app` → `App installed`. |
| 2 Instrument the clock and pause path, Stargate back-step run | **Done.** Cause partly confirmed, partly refuted (§2). |
| 3 Controls: no step; pass 1 seek-back | **Done.** No step resumes correctly; seek-back does not (§3). |
| 4 Patch 0020 if one contained change | **STOP:** four candidate points in three files (§4). |
| 5–10 | Not started. |

## 1. Method

- **Instrumentation.** `reports/logs/1g-libvlc-clock-instrumentation.diff`: 32 log-only lines tagged `1g:` in 4 files.
  - `src/clock/clock.c`: `vlc_clock_main_reset`, `vlc_clock_main_SetFirstPcr`, `vlc_clock_main_ChangePause`, with the "no delay" branch conditional.
  - `src/input/es_out.c`: `EsOutChangePause`, `EsOutChangePosition`, the anchor in `EsOutDecodersStopBuffering`, `ES_OUT_PRIV_RESET_PCR_FRAME_PREV`, `ES_OUT_RESET_PCR`.
  - `src/input/input.c`: `SeekFramePrevious`, `ControlPause`, `ControlUnpause`, `INPUT_CONTROL_SET_TIME`.
  - `src/video_output/video_output.c`: `vout_ChangePause`.
- **The instrumented framework.** Applied to the libvlc tree at `e50d9ac36a` (19 patches). Only the tvOS device slice's `src/` was recompiled (4 objects) with the local GNU make, installed into its prefix, and relinked into `libvlc-full-static.a` from VLC's own `static-libs-list` (the same `libtool -static -filelist` call as `extras/package/apple/build.sh:941–945`). Then `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh`: exit 0, `nm` shows the TrueHD symbols, and the device binary has 15 `1g:` strings.
- **Afterwards.** The four files were reset with `git checkout`, the device slice was recompiled and relinked, and `PACKAGE_ONLY` was run again: 0 `1g:` strings in the static lib, the framework and the installed app. Not VLC's full recipe; that is step 5's.
- **Runs.** Home Theater, 21:14–21:30.
  - Console launch with the pass 1e VLCParams and the JSON tracer, then the attach-mode XCUITest `Diag1gUITests` (Appendix A). Stargate Extended from the start: play 30 s, pause, hold 60 s, five clicks 4.2 s apart (or none), Play, 60 s of playback, screenshots at pause, Play+3 s and Play+60 s.
  - The seek-back control ran the same test with the app built from HEAD (D008's one-frame seek on Left), then the native diff was re-applied.
- **Analysis scripts.** In `reports/logs/1g-instr-analysis.txt`, with their outputs:
  - `resumecheck.py --clock`: the app and `1g:` lines from pause to Play+5 s.
  - `pcrcheck.py`: the trace's demux PCR, demux-out counts and video fifo per 5 s from the vout `paused` event.
  - `resume60.py`: video `toolate` (dropped) and `late` render events in the 60 s after the vout `resumed` event, with the first video and audio render.
- **Evidence.** Logs `reports/logs/1g-instr-stargate-{back,none,seekback}.log` (214 KB / 54 KB / 1.26 MB). Screenshots `reports/screenshots/1g-stargate-{back,none,seekback}-{00-paused,06-play+3s,07-play+60s}.jpg`. The traces (15 / 5.3 / 31 MB) stay off-repo.

## 2. Native back steps (step 2) — what the clock does

**At pause** (`1g-instr-stargate-back.log`):
```
9:15:06.070 PM [player] pause (select) at 33203 ms
[DBG] 1g: es_out change_pause paused=1 date=476264641449 now=476264641577 was_paused=0 old_pause_date=-1 buffering=0 extra_initial=0
[WARN] 1g: main_change_pause paused=1 date=476264641449 now=476264641797 pause_date=0 last.system=476264153740 first_pcr.system=476229413567 start_time.system=0 wait_sync_ref.system=0
```
**At step 1, 60.6 s later.** The seek, then the buffering end anchors at the pause date, and the main clock's reset drops the pause date:
```
9:16:06.716 PM [framestep] −1 gotoPreviousFrame before=33489 ms
[DBG] 1g: input seek_frame_previous now=476325287727 pts=33534001 steps=1 failed=0 enabled=1
[DBG] 1g: es_out RESET_PCR_FRAME_PREV duration=199998 now=476325287786 paused=1 pause_date=476264641449
[DBG] 1g: es_out change_position now=476325287815 paused=1 pause_date=476264641449 buffering=0 next_frame_es=0
[DBG] 1g: input seek_frame_previous now=476325380922 pts=33534001 steps=3 failed=1 enabled=1
[DBG] Stream buffering done (1335 ms in 11 ms)
[DBG] 1g: es_out stop_buffering now=476325392774 paused=1 pause_date=476264641449 current_date=476264641449 buffering_duration=1318002 update=476263323447 stream_start=33116000
[WARN] 1g: main_reset now=476325392814 paused=1 pause_date=476264641449 first_pcr.system=476229413567 last.system=476264650060
[WARN] 1g: main_reset now=476325392883 paused=1 pause_date=0 first_pcr.system=0 last.system=0
[WARN] 1g: set_first_pcr now=476325392918 system=476263323447 ts=33116000 paused=1 pause_date=0
[framestep] previousFrameStepped result=0 time=33489 ms
```
`current_date` = the pause date (`476264641449`), not `now` (`476325392774`, 60.75 s later). Steps 2–5 repeat the same sequence with `pause_date=0` already (log lines in the analysis file).

**At Play:**
```
9:16:27.923 PM [player] play (select) at 33333 ms
[DBG] 1g: es_out change_pause paused=0 date=476346495288 now=476346496253 was_paused=1 old_pause_date=476264641449 buffering=0 extra_initial=0
[DBG] 1g: es_out change_position now=476346496418 paused=1 pause_date=476264641449 buffering=0 next_frame_es=1
[WARN] 1g: main_change_pause paused=0 date=476346495288 now=476346496585 pause_date=0 last.system=0 first_pcr.system=476263490447 start_time.system=0 wait_sync_ref.system=476265758448
[WARN] 1g: main_change_pause resume: pause_date INVALID, no delay applied
[DBG] Stream buffering done (1001 ms in 16 ms)
[DBG] 1g: es_out stop_buffering now=476346513582 paused=0 pause_date=476346495288 current_date=476346513578 buffering_duration=1000000 update=476345513578 stream_start=116316367
[WARN] 1g: main_reset now=476346513677 paused=0 pause_date=0 first_pcr.system=476263490447 last.system=0
[WARN] 1g: set_first_pcr now=476346513880 system=476345513578 ts=116316367 paused=0 pause_date=0
```

**Verdict on the 1f hypothesis.**
- **Confirmed:** the paused step's `main_reset` sets `pause_date` from `476264641449` to 0, and on Play `vlc_clock_main_ChangePause` returns with no delay.
- **Refuted as the cause:** Play goes through `EsOutResumeFromNextFrame` (`change_position … next_frame_es=1`), which rebuffers and re-anchors the main clock at `now − 1 s`. The missing delay is overwritten. What is wrong is the new anchor's stream time, `stream_start=116316367` (116.3 s), while the pictures that play first are at 33.4 s. That gives the 82.9 s lateness (first late picture: `missing 81715 ms`, then 82907…).

**Where 116 s comes from** (trace, `pcrcheck.py`, 5-s buckets from the pause):

| From pause | Demux PCR | Video demux out | Video fifo (packets, bytes) |
|---|---|---|---|
| 0–60 s | none (paused, no reads) | 0 | — |
| 60 s (step 1 at +60.6) | 33 116 → 37 600 ms | 1 729 | 97, 2.2 MB |
| 65 s | 37 604 → 77 632 ms | 2 655 | 1 058, 20.1 MB |
| 70 s | 77 644 → 109 472 ms | 2 560 | 1 823, 36.1 MB |
| 75 s | 109 493 → 114 531 ms | 2 017 | 1 945, 38.7 MB |
| 80 s (Play at +81.8) | 114 688 → 120 672 ms | 146 | 19 |
| 85 s on | +5 s per 5 s (normal) | ~120 | ~19 |

Once the first step anchored the clocks at the pause date (`update=476263323447`), the demuxer read at up to ~8× speed until the stream caught up with wall time since the pause (33.1 + 81.4 ≈ 114.5 s), then continued at 1× while still paused. The no-step control reads nothing at all while paused (§3). The video fifo held those pictures, and Play flushed everything but video.

## 3. The controls (step 3)

**No step, 80.7 s paused** (`1g-instr-stargate-none.log`). The pause date survives, the delay is applied, and there's no reposition:
```
9:20:50.176 PM [player] play (select) at 33681 ms
[DBG] 1g: es_out change_pause paused=0 date=476608754868 now=476608755223 was_paused=1 old_pause_date=476528075780 buffering=0 extra_initial=0
[WARN] 1g: main_change_pause paused=0 date=476608754868 now=476608755421 pause_date=476528075780 last.system=476528077456 first_pcr.system=476492872772 start_time.system=0 wait_sync_ref.system=0
[WARN] 1g: main_change_pause resume: delay=80679088 applied, last.system=476608756544 first_pcr.system=476573551860
```
Trace: no demux PCR at all from pause to Play; after Play, PCR 35 368 ms onwards at 1×.

**Pass 1 seek-back, 81.9 s paused** (`1g-instr-stargate-seekback.log`, app built from HEAD). Each Left seeks while paused through `INPUT_CONTROL_SET_TIME` → `ES_OUT_RESET_PCR`, and the buffering end again anchors at the pause date (`current_date=476886109375`). Then VLC loops: `ES_OUT_RESET_PCR` is called **792** times between the pause and Play, with `stream_start` climbing on every lap (`33617000, 35104001, 36203001, 37287001, …`). At Play:
```
[DBG] 1g: es_out stop_buffering now=476968025660 paused=1 pause_date=476886109375 current_date=476886109375 buffering_duration=1000000 update=476885109375 stream_start=207904001
9:26:49.461 PM [player] play (select) at 33777 ms
[WARN] 1g: main_change_pause resume: pause_date INVALID, no delay applied
[DBG] Stream buffering done (1018 ms in -81900 ms)
[DBG] 1g: es_out stop_buffering now=476968051259 paused=0 … stream_start=208992001
[WARN] 1g: set_first_pcr now=476968051371 system=476967051256 ts=208992001 paused=0 pause_date=0
```
It shows no mass drop because each loop lap flushes the decoders, so nothing stale is queued. But playback restarts at the read-ahead position, 209 s instead of 33.8 s.

**Why only the no-step control resumes correctly.** Nothing moves the demuxer or re-anchors a clock while paused, so resume's `ChangePause` shifts the existing references by the pause (`delay=80679088`). Both step kinds re-anchor at the pause date while paused, and the demuxer runs ahead against that anchor. The native step keeps the read-ahead video (→ late pictures); the seek loop discards it (→ a position jump).

| Stargate Extended, instrumented build | Paused (wall) | Dropped, first 60 s after Play (per 20 s) | Late | First video render drift | Audio's first render after video's | Clock at Play+3 s / +60 s |
|---|---|---|---|---|---|---|
| a. native back ×5 | 81.9 s | **1 002** (1 002 / 0 / 0) | 4 | −81 715 ms | 1 407 ms | 01:59 / 02:56 (paused at 00:33) |
| c. no step | 80.7 s | **0** | 0 | −2.0 ms | 116 ms | — / 01:34 (correct) |
| seek-back ×5 (pass 1) | 81.9 s | **0** | 3 | −80 331 ms | 1 348 ms | 03:32 / 04:29 (jumped) |

## 4. Candidates (step 4 — STOP)

Line numbers are in libvlc `e50d9ac36a`, uninstrumented.

| # | Where | Lines | What the change would be | For / against |
|---|---|---|---|---|
| A | `src/input/es_out.c`, `EsOutDecodersStopBuffering` | 1219 `const vlc_tick_t i_current_date = p_sys->b_paused ? p_sys->i_pause_date : vlc_tick_now();`, feeding `input_clock_ChangeSystemOrigin` (1237) and `vlc_clock_main_SetFirstPcr` (1253–1254) | Anchor a paused rebuffer at `vlc_tick_now()`, so the input clock doesn't license reading the pause's worth of stream. | Explains the ×8 catch-up and the lateness ≈ pause. It still lets the demuxer run at 1× while paused, and it changes every paused seek, including user seeks. |
| B | `src/input/input.c`, `MainLoop` demux gate | 660–669 (`b_paused = !es_out_GetBuffering(…) \|\| b_eof; if (b_paused && next_frame_need_data) b_paused = false;`) and wakeup 759–764 | Stop demuxing while `PAUSE_S` once the previous frame is shown. | Removes the read-ahead at its source. **Not pinned**: after `Stream buffering done`, `es_out_GetBuffering` should report false, and previous-frame sets `frames_countdown = -1`, not `next_frame_need_data`. What keeps the loop demuxing for 20 s was not instrumented (least-sure 1). |
| C | `src/input/es_out.c`, `EsOutResumeFromNextFrame` → `EsOutChangePosition(p_sys, EsOutStopNextFrame(p_sys))` | 1014–1018 (keeps the video decoder's fifo), `src/input/decoder.c` 367–404 (`Decoder_HandlePreviousFrame` keeps `resume_pic`) | On resume after a previous-frame, flush the video ES too and seek to the displayed PTS. | Hides the read-ahead instead of preventing it. Reaches into decoder.c's resume-picture handling. The seek-back control shows a position jump survives if the demuxer still runs ahead. |
| D | `src/clock/clock.c`, `vlc_clock_main_reset` / `vlc_clock_main_ChangePause` | 981 (`main_clock->pause_date = VLC_TICK_INVALID;` in reset), 1064–1066 (early return) | Keep the pause date across a reset while paused. | The confirmed defect of pass 1f, but §2 shows Play re-anchors the main clock anyway. On its own it would not change the 82.9 s lateness. |

A and B act on the read-ahead; C and D act on resume. More than one is plausible, and none is a single contained change at one point, so no patch was written.

## 5. Files touched, by step

| Step | Files | Committed? |
|---|---|---|
| 1 | `Marlin Media TV/PlayerModel.swift` (the 1f diff re-applied) | **No**, uncommitted by instruction. Built and installed on Home Theater. |
| 2–3 | libvlc `src/clock/clock.c`, `src/input/es_out.c`, `src/input/input.c`, `src/video_output/video_output.c` in `~/vlckit-build` (temporary, reset afterwards) → `reports/logs/1g-libvlc-clock-instrumentation.diff` | Diff committed; the tree is clean at `e50d9ac36a`. |
| 2–3 | `Frameworks/VLCKit.xcframework`: instrumented, then re-packaged without instrumentation | Git-ignored. The device slice's `libvlc-full-static.a` was relinked from recompiled clean objects, so it is not byte-identical to the 16:53 build (same sources). |
| 2–3 | Temporary `Marlin Media TVUITests/Diag1gUITests.swift` (Appendix A) | Deleted; not committed. |
| 2–3 | `reports/logs/1g-instr-stargate-{back,none,seekback}.log`, `reports/logs/1g-instr-analysis.txt`, `reports/screenshots/1g-stargate-*.jpg` (9, 0.35 MB) | Committed. |
| — | `COLD-START.md` (pass 1g note), this report | Committed. |

Not touched: `tools/vlckit-truehd/` (0007, 0018, 0019, `build.sh`), `DECISIONS.md`, Design/, Marlin DVR TV. Deployment target 26.0. Nothing over 10 MB committed. Device Home Theater only. Committed locally, not pushed.

## 6. Step 8 numbers

Not run (stopped at step 4). The only numbers are Stargate's, from the instrumented build, in the table in §3. Wonder Woman, Magicians and Divergent were not run in this pass. Forward steps then Play (8b) and the per-click exactness (8d) were not run either; 8d on Stargate is pass 1f's.

## 7. What could not be tested, and what was traced instead

- **The demux gate that runs while paused after a step (candidate B):** not instrumented. What was traced instead: the demux PCR, demux-out and fifo timeline from VLC's JSON tracer.
- **Audio "starting at the first picture":** measured as the first audio render event after the first video render in the trace (116 ms for no step; 1.4 s after steps). Not heard.
- **VideoToolbox titles:** not run in this pass, so whether the same read-ahead happens with HEVC/H.264 is not shown. The mechanism is codec-independent in the code read (es_out/input/clock).

## 8. Open questions

1. **Which fix design?** A (anchor at now), B (no demux while paused after a step), C (resume from a previous-frame as a seek), or a combination. A+B looks like it removes the cause for both native steps and paused seeks. It changes two points in two files, so it is your call.
2. **Seek-back is broken too.** Pass 1f's control was wrong (§3). Does that change what D008 should say today?
3. **Instrumenting the gate.** A short follow-up that instruments `MainLoop`'s pause gate would pin B before choosing. Do you want it?
4. **VideoLAN draft (step 10).** Write it after the design is chosen, or now with the evidence as it stands?

## 9. Least-sure items

1. **Why the input demuxes while paused after a step.** It's shown by the trace, not by a gate log. `es_out_GetBuffering` (es_out.c 4078–4084) returns `b_buffering`, which `Stream buffering done` clears, so something else keeps the loop demuxing. Not identified.
2. **"Demux paced by the pause-date anchor."** Inferred from the PCR catching up to wall time (114.5 s ≈ 33.1 + 81.4) and then running at 1×. There is no wakeup log.
3. **The 792 seek-back loops** are counted from `ES_OUT_RESET_PCR called` lines. What triggers each lap (1c named `PCR is called late`) wasn't re-read in this build.
4. **The re-packaged framework** is from clean sources but a relinked static lib, not the recipe's full build (see §5).
5. **Audio timing** is from trace render events, one run each.

## Appendix A — the temporary harness (built, run, deleted; not committed)

```swift
//
//  Diag1gUITests.swift — temporary harness for pass 1g (2026-09-14). Not committed.
//  Attach mode (the app is started by `devicectl … --console` with the run's VLCParams, tracer on), from pass 1f.
//  Per run: play 30 s, pause, hold 60 s, five clicks (left, right or none; 3.6 s apart, screenshot after each),
//  Play, 60 s of playback (screenshots at +3 s and +60 s), Menu.
//

import XCTest

final class Diag1gUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]

    override func setUp() { continueAfterFailure = true }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func note(_ t: String) { let a = XCTAttachment(string: t); a.name = "note"; a.lifetime = .keepAlways; add(a); NSLog("[p1g] %@", t) }
    private func press(_ b: XCUIRemote.Button, _ n: Int = 1, wait: UInt32 = 1) { for _ in 0..<n { remote.press(b); sleep(wait) } }
    private func focusedIds() -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex.map { $0.identifier.isEmpty ? "(\($0.label))" : $0.identifier }
    }
    private func isFocused(_ id: String) -> Bool { focusedIds().contains(id) }
    private func isFocused(prefix: String) -> Bool { focusedIds().contains { $0.hasPrefix(prefix) } }
    @discardableResult private func moveUntilFocused(_ id: String, pressing b: XCUIRemote.Button, limit: Int = 8) -> Bool {
        for _ in 0..<limit { if isFocused(id) { return true }; press(b) }
        return isFocused(id)
    }
    private func focusHeader() { for _ in 0..<8 { if isFocused(prefix: "tab.") || isFocused("sort") { return }; press(.up) } }
    private func focusHeaderItem(_ id: String) {
        focusHeader(); guard let target = headerOrder.firstIndex(of: id) else { return }
        for _ in 0..<8 { if isFocused(id) { return }; let cur = headerOrder.firstIndex { isFocused($0) } ?? 0; press(cur < target ? .right : .left) }
    }
    private func selectTab(_ name: String) { focusHeaderItem("tab.\(name)"); press(.select, wait: 2) }
    private func openPoster(_ id: String, tab: String) {
        selectTab(tab); press(.down); if !isFocused(prefix: "poster.") { press(.down) }
        _ = moveUntilFocused(id, pressing: .right, limit: 6) || moveUntilFocused(id, pressing: .left, limit: 6)
        press(.select, wait: 3)
        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 20), "detail did not open; focus \(focusedIds())")
        sleep(2)
    }
    private func pressPlay() { if !isFocused("play") { moveUntilFocused("play", pressing: .up, limit: 6) }; press(.select, wait: 2) }
    private func stamp() -> String { let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date()) }
    private func openStargate() {
        openPoster("poster.Stargate", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.buttons["pick.Extended"].waitForExistence(timeout: 5)); moveUntilFocused("pick.Extended", pressing: .up, limit: 3); press(.select, wait: 2)
    }
    private func openMagicians() {
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30)); sleep(2)
        moveUntilFocused("episode.1.1", pressing: .down, limit: 4); press(.select, wait: 2)
    }
    private func open(_ film: String) {
        switch film {
        case "stargate": openStargate()
        case "ww": openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay()
        case "divergent": openPoster("poster.Divergent", tab: "Movies"); pressPlay()
        default: openMagicians()
        }
    }
    private func attach() {
        app = XCUIApplication(); app.activate()
        note("attached at \(stamp())")
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
    }

    /// kind: "back" (5 × left), "fwd" (5 × right), "none" (no click; same hold).
    private func run(_ film: String, _ kind: String) {
        attach(); open(film)
        let tag = "\(film)-\(kind)"
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(stamp())")
        sleep(30)
        press(.down, wait: 1)
        note("\(tag): pause at \(stamp())")
        press(.select, wait: 3)
        shot("p1g-\(tag)-00-paused")
        sleep(57)
        for n in 1...5 {
            switch kind {
            case "back": note("\(tag): click \(n) L at \(stamp())"); remote.press(.left)
            case "fwd": note("\(tag): click \(n) R at \(stamp())"); remote.press(.right)
            default: note("\(tag): hold \(n) at \(stamp())")
            }
            sleep(3)
            shot(String(format: "p1g-\(tag)-%02d", n))
            usleep(600_000)
        }
        note("\(tag): play at \(stamp())")
        press(.select, wait: 3)
        shot("p1g-\(tag)-06-play+3s")
        sleep(56)
        press(.up, wait: 1)
        shot("p1g-\(tag)-07-play+60s")
        note("\(tag): play+60s shot at \(stamp()), player exists \(app.otherElements["player"].exists)")
        press(.down, wait: 1)
        press(.menu, wait: 3)
    }

    func t0_AttachAndPlay() { attach(); openMagicians(); XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20)); sleep(20); press(.menu, wait: 3) }
    func tStargateBack() { run("stargate", "back") }
    func tStargateFwd() { run("stargate", "fwd") }
    func tStargateNone() { run("stargate", "none") }
    func tWonderWomanBack() { run("ww", "back") }
    func tWonderWomanFwd() { run("ww", "fwd") }
    func tWonderWomanNone() { run("ww", "none") }
    func tMagiciansBack() { run("magicians", "back") }
    func tMagiciansFwd() { run("magicians", "fwd") }
    func tMagiciansNone() { run("magicians", "none") }
    func tDivergentBack() { run("divergent", "back") }
    func tDivergentFwd() { run("divergent", "fwd") }
    func tDivergentNone() { run("divergent", "none") }
}
```
