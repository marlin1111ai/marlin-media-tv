# Pass 1f — native frame-back while paused — STOPPED at item 3 (resume after stepping fails) — 2026-09-14

**Result.**
- **Stepping is exact on Stargate.** VLCKit's native `gotoPreviousFrame` steps exactly one picture per left click on Stargate Extended (MPEG-2, avcodec). Five back, five forward and five back land on the file's picture grid one picture at a time. The screenshots return to the same pictures, and there's no `RESET_PCR` loop.
- **Resuming fails.** Play after the steps starts with every picture ~57.6 s late: the whole time spent paused. VLC drops 713 pictures in 23.6 s and the position runs from 01:03.8 to 02:25.4.
- **Why I stopped.** That is item 3's "resume plays normally" failing, so by the pass's failure rule I stopped after Stargate. Wonder Woman and Magicians were not run, and nothing was retried.
- **Cause, from VLC's source.** A previous-frame seek while paused resets VLC's main clock, which discards the pause date, so resume adds no pause delay (§3).

**Code state.** Item 1's change was built, installed on Home Theater and tested. It is **not committed**: `PlayerModel.swift` is back at HEAD, and the tested change is kept as `reports/logs/1f-playermodel-native-prevframe.diff`. Committing it would replace the old seek-back, whose resume worked, with one whose resume doesn't (question 1). **Home Theater still has the pass 1f build installed.** DECISIONS.md D008 is unchanged: item 5's "frame-back now native, exact" applies only if the pass passes. Committed locally, not pushed.

## Result per item

| Item | Result |
|---|---|
| 1 Native previous frame on left click while paused | **Written and built.** `frameStep(-1)` calls `player.gotoPreviousFrame()` in place of the one-frame seek. `frameDurationMs` (used only by the seek) is removed. A `mediaPlayer(_:previousFrameSteppedWith:)` delegate logs the result. Forward step, skips, pause and everything else untouched. 12 insertions, 17 deletions. **Reverted after item 3's failure** (diff kept). |
| 2 Build, install on Home Theater | `xcodebuild build-for-testing … -destination 'platform=tvOS,name=Home Theater'` → `** TEST BUILD SUCCEEDED **`. `devicectl device install app` exit 0. |
| 3 Device verification | **Stargate: stepping exact, resume FAILED → STOP.** Wonder Woman, Magicians: not run. |
| 4 Stop rule for stepping | Not triggered: Stargate stepped exactly one picture per click with no loop. The stop came from item 3's resume check under the failure rule. |
| 5 D008, COLD-START, report | D008 **not** updated (the pass did not pass). COLD-START: a pass 1f note. This report. |

## 1. Method

- **Traced run.** Console launch with the pass 1e VLCParams plus `--tracer=json --json-tracer-file=<container>/Library/Caches/vlc-trace-stargate.json`. The container path came from a probe run's `opening logfile` line after the install. Then the attach-mode XCUITest `Diag1fUITests/tF_Stargate` (Appendix A), 20:52:39–20:55:35 EDT.
- **What the test did.**
  - Stargate Extended from the start.
  - Select at 60 s to pause.
  - Clicks 1–5 Left, 6–10 Right, 11–15 Left, 3.6 s apart, with a screenshot 3 s after each.
  - Select to resume, with screenshots 3 s and 23 s later, then Menu.
- **Positions.** The app's lines per click:
  - `[framestep] −1 gotoPreviousFrame before=` / `+1 gotoNextFrame before=`
  - the `previousFrameStepped` / `nextFrameStepped` callback with `player.time`
  - `after(400 ms)=`
- **Picture PTS.** From the trace's video decoder output (`DEC OUT pts`), read with VLC's own previous-frame rule (`src/input/decoder_prevframe.c`, `decoder_prevframe_AddPic`): the decoder decodes forward from a seek point and shows the last picture before the one whose PTS reaches the previously displayed PTS.
- **Picture identity.** A mean-absolute-difference matrix over the video area of the 16 paused screenshots, excluding the overlay and pause glyph (`picdiff.py`).
- **Evidence.**
  - `reports/logs/1f-stargate-framestep.log` (app + VLC log, 172 KB).
  - `reports/logs/1f-stargate-analysis.txt`: every analysis output and the three scripts.
  - `reports/screenshots/p1f-stargate-*.jpg`: 18 files, 1920×1080, 2.2 MB.
  - The trace (24 MB) stays off-repo. The trace file also held an older Stargate session from pass 1e (same container, the tracer appends); the scripts use only the session after the last > 600 s gap.

## 2. Stargate Extended (MPEG-2 480i, avcodec) — per-click positions

The file's decoded picture grid around the pause (normal playback before the pause, from the trace) alternates 33/34 and 50 ms. It's 3:2-pulldown film, 23.976 pictures/s: `…63814, 63864, 63897, 63947, 63981, 64031, 64064…` ms. "One frame" here is one step on that grid, 33 or 50 ms.

| Click | Key | App `before` (ms) | Callback result / `time` (ms) | App `after(400 ms)` (ms) | Picture PTS (trace, ms) | Step (ms) | Screenshot: same picture as |
|---|---|---|---|---|---|---|---|
| paused | Select | `pause at 63682`, `state Paused at 63970` | — | — | **64031** | — | P0 |
| 1 | L | 63970 | 0 / 63970 | 63981 | 63981 | −50 | P1 (new; MAD 1.2 vs P0) |
| 2 | L | 63981 | 0 / 63981 | 63947 | 63947 | −34 | P2 (new) |
| 3 | L | 63947 | 0 / 63947 | 63897 | 63897 | −50 | P3 (new) |
| 4 | L | 63897 | 0 / 63897 | 63864 | 63864 | −33 | P4 (new) |
| 5 | L | 63864 | 0 / 63864 | 63814 | 63814 | −50 | P5 (new) |
| 6 | R | 63814 | 0 / 63864 | 63864 | 63864 | +50 | P4 (MAD 0 vs click 4) |
| 7 | R | 63864 | 0 / 63897 | 63897 | 63897 | +33 | P3 (0 vs click 3) |
| 8 | R | 63897 | 0 / 63897 | 63947 | 63947 | +50 | P2 (0 vs click 2) |
| 9 | R | 63947 | 0 / 63981 | 63981 | 63981 | +34 | P1 (0 vs click 1) |
| 10 | R | 63981 | 0 / 63981 | 64031 | 64031 | +50 | **P0 (0 vs the paused picture)** |
| 11 | L | 64031 | 0 / 64031 | 63981 | 63981 | −50 | P1 (0 vs click 1) |
| 12 | L | 63981 | 0 / 63981 | 63947 | 63947 | −34 | P2 |
| 13 | L | 63947 | 0 / 63947 | 63897 | 63897 | −50 | P3 |
| 14 | L | 63897 | 0 / 63897 | 63864 | 63864 | −33 | P4 |
| 15 | L | 63864 | 0 / 63864 | 63814 | 63814 | −50 | P5 (0 vs click 5) |

**Reading the table.**
- **Where the positions come from.** The paused picture's PTS (64031) is the `pf_pts` VLC used for click 1: that step's decode run ends at 64031, and the picture shown is the one before it, 63981. `player.time` at pause (63970) is VLC's interpolated clock, not the picture.
- **Back-step callbacks.** They report the old `player.time`. Every `after(400 ms)` equals the picture PTS.
- **Picture matrix.** Six distinct pictures P0…P5, adjacent ones differing by MAD 1.2–1.6 (×10 scale 12–16), and each screenshot identical (0) to the one at the same PTS. Full matrix in the analysis file.
- **What it shows.** Each click moved exactly one picture, both ways, and the picture matches the position. The screenshots show the scarab/door close-up at 01:04 (`p1f-stargate-05-L.jpg`).

**No loop.**
- **Counts from the pause to the resume.** `RESET_PCR` 0, `ES_OUT_SET_(GROUP_)PCR is called … late` 0, `nextFrameStepped` callbacks exactly 5 and `previousFrameStepped` exactly 10 (one per click), `Stream buffering done` 10.
- **Per back step.** One HTTP `Range` request, ~0.9 s of pre-roll (the decode runs start at 63647 ms), and click → `previousFrameStepped` in 125–234 ms.
- **Forward steps.** No request or buffering.
- **Before this pass (pass 1c).** The seek-back looped 105–237 times per step until the next input.
- **Clicks 3 and 13.** VLC decoded the 63647… run twice within ~150 ms (two `buffering 0.0` pairs; trace groups 3 and 12). The picture shown is still the one-picture step.

## 3. Resume after stepping — FAILED

**What happened.**
- **Play and the first picture.** `8:55:05.930 PM [player] play (select) at 63814 ms`. The first picture: `picture displayed late (missing 57580 ms)`. Then `picture is too late to be displayed (missing 58799 ms)` … `(missing 56 ms)`: **713** too-late lines in 23.57 s, with `more than 110 … 122 frames of late video -> dropping frame` errors among them.
- **Trace.**
  - The first realtime video renders after resume have drift −57 580, −57 532, −58 893 … −59 245 ms.
  - Decoded PTS runs 63 897 → 146 563 ms in 23.57 s of wall time: 82.7 s of film.
  - The audio output's `started` line appears only ~250 lines into the drops.
- **Screenshots.** `p1f-stargate-16-resumed.jpg`, 3 s after Play, clock **02:05** (paused at 01:04). `p1f-stargate-17-resumed-20s.jpg`, clock **02:23**, "Executive Producer Mario Kassar". `dismiss at 145370 ms`.
- **The size of the error.** The paused time, from `state Paused` 20:54:08.241 to `play` 20:55:05.930, is **57.689 s**. The error equals the time spent paused.

**Control, from logs already committed.**
- **Plain pause/resume.** No step: every earlier pause → Play in `reports/logs/` has at most one picture 43–51 ms late on resume. That covers 1.2 s pauses on Wonder Woman, Divergent and Magicians, and a 16.1 s pause on Stargate (`1b-stargate-both-editions-vlckit.log`, none).
- **Pass 1's seek-back.** A 16.1 s pause with pass 1's forward steps and seek-back steps (`stargate-both-editions-vlckit.log`, 9:56:57 → 9:57:13) resumed with one picture 43 ms late.
- The scan looked at the first 400 lines after each Play; its command and output are at the end of `reports/logs/1f-stargate-analysis.txt`.

**Cause, from VLC's source** (libvlc `e50d9ac36a`, read-only):
1. **The seek.** A previous-frame step sends `INPUT_CONTROL_SEEK_FRAME_PREVIOUS` → `SeekFramePrevious` (`src/input/input.c:2020`) → `ES_OUT_PRIV_RESET_PCR_FRAME_PREV` → `EsOutChangePosition` and a seek.
2. **The re-anchor.** When the buffering after that seek ends (`src/input/es_out.c:1219–1254`), VLC takes `i_current_date = p_sys->b_paused ? p_sys->i_pause_date : vlc_tick_now()`: the date the user paused. It calls `vlc_clock_main_Reset`, then `vlc_clock_main_SetFirstPcr(update = i_pause_date − buffering, …)`.
3. **The pause date is lost.** `vlc_clock_main_reset` sets `main_clock->pause_date = VLC_TICK_INVALID` (`src/clock/clock.c`).
4. **Resume.** `vlc_clock_main_ChangePause(now, false)` returns early: `/* Reset was called before resume from Pause */ if (main_clock->pause_date == VLC_TICK_INVALID) return;` (`clock.c:1065`). No pause delay is added to the reference.
5. **The result.** The clock's first PCR stays anchored at the original pause date, so every picture after Play is late by (resume − pause). Measured: 57.58 s, against 57.69 s paused.

This is read from the source and matches the numbers. It was not instrumented (least-sure 1).

## 4. Files touched

| Step | Files |
|---|---|
| 1 | `Marlin Media TV/PlayerModel.swift`: changed, built, installed, **reverted to HEAD**. The change is kept as `reports/logs/1f-playermodel-native-prevframe.diff`. |
| 3 | Temporary `Marlin Media TVUITests/Diag1fUITests.swift` (Appendix A): built, run, deleted, not committed. Evidence: `reports/logs/1f-stargate-framestep.log`, `reports/logs/1f-stargate-analysis.txt`, `reports/screenshots/p1f-stargate-{00-paused,01…15-L/R,16-resumed,17-resumed-20s}.jpg` |
| 5 | `COLD-START.md` (pass 1f note), this report. `DECISIONS.md` unchanged. |

Nothing installed on the Mac, VLCKit not rebuilt, project file untouched, deployment target 26.0, server 192.168.1.250:8093 only, nothing over 10 MB committed. Committed locally, **not pushed**.

## 5. What could not be tested

- **Wonder Woman (HEVC, VideoToolbox) and Magicians (H.264)**: not run, because the pass stopped at Stargate's resume. Whether VideoToolbox titles step exactly with the native call is unknown.
- **Audio after resume.** The harness can't hear. The log shows the audio output started only after the video drops.
- **Resume after forward steps only**, or after a single back step: not run (no second experiment after a failure).

## 6. Open questions

1. **The resume failure.** Which way?
   - (a) A VLCKit patch 0020 in `es_out.c`/`clock.c`: for example, keep the pause date across a reset while paused, or anchor the new first PCR at the resume. That means a full VLCKit rebuild and dpb-style testing.
   - (b) App-side: after one or more back steps, re-set the position to the current picture on Play. That is itself a seek, which this pass ruled out.
   - (c) Keep D008's seek-back for now. Its resume works; its paused picture is wrong and it loops.
   - (d) Also report it to VideoLAN.
2. **Commit the native call?** It is not committed here (the diff is kept). Home Theater runs it now. Should a later pass reinstall the HEAD build?
3. **Screenshots.** 18 JPGs (2.2 MB) are committed as evidence. Keep them?

## 7. Least-sure items

1. **The clock mechanism is from source reading** matched to the measured 57.58 s vs 57.69 s, not from instrumented code. I haven't explained why pass 1's paused seek-back resumed correctly, although a user seek while paused also ends buffering through `EsOutChangePosition`. A difference in how `ControlSetTime` handles the pause for a user seek is likely, but not read.
2. **Clicks 3 and 13 decoded the pre-roll run twice.** The prevframe code re-seeks when the first run fails to reach the target (`pf->failed`, `seek_steps += 2`). Whether that was the trigger isn't visible in the trace.
3. **The paused picture's PTS (64031)** is inferred from VLC's rule, confirmed by the screenshot matrix (paused = click 10, whose `after(400 ms)` is 64031).
4. **The control scan** (§3) checked the first 400 log lines after each earlier Play for a too-late line. It didn't compare whole windows.

## Appendix A — the temporary harness (built, run, deleted; not committed)

```swift
//
//  Diag1fUITests.swift — temporary harness for pass 1f (2026-09-14). Not committed.
//  Attach mode (the app is started by `devicectl … --console` with the run's VLCParams, tracer on), from the pass 1e
//  harness. Per title: play 60 s, pause, five left clicks, five right clicks, five left clicks (3 s apart, a screenshot
//  after each), then resume and play 20 s.
//

import XCTest

final class Diag1fUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]

    override func setUp() { continueAfterFailure = true }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func note(_ t: String) { let a = XCTAttachment(string: t); a.name = "note"; a.lifetime = .keepAlways; add(a); NSLog("[p1f] %@", t) }
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
    private func openStargate(_ edition: String, dir: XCUIRemote.Button) {
        openPoster("poster.Stargate", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.buttons["pick.\(edition)"].waitForExistence(timeout: 5)); moveUntilFocused("pick.\(edition)", pressing: dir, limit: 3); press(.select, wait: 2)
    }
    private func openMagicians() {
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30)); sleep(2)
        moveUntilFocused("episode.1.1", pressing: .down, limit: 4); press(.select, wait: 2)
    }
    private func attach() {
        app = XCUIApplication(); app.activate()
        note("attached at \(stamp())")
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
    }

    /// Pause, then 5 × left, 5 × right, 5 × left (3 s apart, screenshot after each), resume, 20 s of playback.
    private func stepRun(_ tag: String) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(stamp())")
        sleep(60)
        press(.down, wait: 1)
        note("\(tag): pause at \(stamp())")
        press(.select, wait: 3)
        shot("p1f-\(tag)-00-paused")
        var n = 0
        for (button, name) in [(XCUIRemote.Button.left, "L"), (.right, "R"), (.left, "L")] {
            for _ in 1...5 {
                n += 1
                note("\(tag): click \(n) \(name) at \(stamp())")
                remote.press(button); sleep(3)
                shot(String(format: "p1f-\(tag)-%02d-\(name)", n))
            }
        }
        note("\(tag): resume at \(stamp())")
        press(.select, wait: 3)
        shot("p1f-\(tag)-16-resumed")
        sleep(17)
        press(.up, wait: 1)
        shot("p1f-\(tag)-17-resumed-20s")
        note("\(tag): resumed-20s shot at \(stamp()), player exists \(app.otherElements["player"].exists)")
        press(.down, wait: 1)
        press(.menu, wait: 3)
    }

    func t0_AttachAndPlay() { attach(); openMagicians(); XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20)); sleep(20); press(.menu, wait: 3) }
    func tF_Stargate() { attach(); openStargate("Extended", dir: .up); stepRun("stargate") }
    func tF_WonderWoman() { attach(); openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); stepRun("ww") }
    func tF_Magicians() { attach(); openMagicians(); stepRun("magicians") }
}
```
