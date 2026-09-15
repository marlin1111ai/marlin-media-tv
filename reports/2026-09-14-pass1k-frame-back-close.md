# Pass 1k — native frame-back closed out — 2026-09-14/15

**Result.**
- **Stepping is exact.** Native frame-back while paused steps exactly one picture per click on Home Theater:
  - **Back:** Stargate (MPEG-2, avcodec), Divergent and Wonder Woman (HEVC, VideoToolbox).
  - **Forward:** the same three films.

  The proof is VLC's decode runs in the trace, the app's per-click positions, and screenshot pixel comparison (§3).
- **Resume is right on every film.** Across five films, each with five back steps, five forward steps and no step after an ~80 s pause, the on-screen clock is right on Play in every run (00:36–00:38 at +3 s, 01:33–01:35 at +60 s).
  - **No-step controls:** 0 dropped.
  - **After steps:** the accepted drop of the pictures below the demuxer's clock start, 21–29 after back steps and 26–45 after forward steps (§2).
- **Audio start is not measured.** The clean build has no timestamped audio-start event, which is what you chose. The first audio block's scheduled time is traced instead (§2.2).
- **The step 4 check:**
  - **Stargate's control:** 1 picture displayed late by 3 ms at resume, against pass 1i's 0. You ruled that within noise. Its clock and drop count match pass 1i.
  - **Other films:** pass 1i had no controls for them.
- **Written and committed:**
  - D008 revised (seek-back superseded), D019 (patch 0020) and D020 (the two accepted items);
  - the correction note in pass 1i's report;
  - the VideoLAN draft (not submitted);
  - COLD-START;
  - `PlayerModel.swift` with the native step.

  **Local only, not pushed:** the owner tests on Home Theater first.

## Result per step

| Step | Result |
|---|---|
| 1 1f diff, build, install | **Done.** The diff was already in the working tree from pass 1i (`git apply --check --reverse` passes, `gotoPreviousFrame` ×2). `** TEST BUILD SUCCEEDED **`, 0 trace strings in the embedded framework, `App installed:`. Committed this pass. |
| 2 Matrix | **Done**: 15 runs, all test cases passed (§2). |
| 3 Exactness | **Done.** Back on Stargate, Divergent, Wonder Woman; forward on the same three (§3). |
| 4 Controls / exactness | Steps exact. Stargate control 1 late (3 ms) vs 0 in pass 1i: **your ruling, within noise**. Continued. |
| 5 D008 | **Done.** The old line is marked superseded in part; D008 (revised) is under "2026-09-14 — pass 1k". |
| 6 D019 (0020) | **Done.** |
| 7 D020 (accepted) | **Done**, with the measured drop range. |
| 8 Pass 1i correction | **Done.** A note under that report's title; the rest untouched. |
| 9 VideoLAN draft | **Done.** `reports/logs/1k-upstream-videolan-draft.md`, not submitted. |
| 10 COLD-START | **Done.** Toolchain paragraph at 20 patches (with 0020); pass 1k note. |
| 11 This report | Done. |
| 12 Commit + framework check | §4, §6. |

## 1. Method

- **Build.** HEAD `0b4bbff` + the 1f diff, and `Frameworks/VLCKit.xcframework` from the full recipe (§4). `xcodebuild build-for-testing … 'platform=tvOS,name=Home Theater'`, `devicectl device install app`.
- **Runs.** Console launch with VLCKit's tvOS defaults and the JSON tracer, then the attach-mode XCUITest `Diag1kUITests`. That is pass 1j's harness renamed; it was temporary, is out of the repo and isn't committed.
  - **Container path probe:** the launch is stopped before its output is read, and a run is refused without a path.
  - **Order:** the 18 runs went one after another, stopping on any failed test case: 3 exactness runs, then per film no step → back → forward. 23:44:29 → 01:02:06, all passed.
- **Step 2 run.** Play 30 s, pause, hold 77 s, five clicks ~4.2 s apart (or none), wait 20 s, Play, 60 s, with screenshots at Play+3 s and +60 s. The "paused" column (121–123 s) is the whole pause, including the clicks and the 20 s.
- **Step 3 run.** Pass 1f's pattern: play 60 s, pause, 5 × Left, 5 × Right, 5 × Left, 4.2 s apart, with a screenshot 3 s after each, then Play.
- **Measures** (`reports/logs/1k-analysis.txt`, with every output and script):
  - **Position at pause:** the app's `state Paused at`. **At Play:** `play (select) at`.
  - **Dropped / late:** the trace's video `toolate` / `late` events in the 60 s after the vout `resumed` event (`matrix1k.py`). Pass 1i's clean Stargate runs give the same counts as pass 1i with this script (21 / 1, 26 / 1, 0 / 0).
  - **Clock:** Vision OCR of the overlay's clock in the screenshots (crops in `reports/screenshots/1k-clock/`).
  - **Exactness:** §3.
- **Evidence.**
  - `reports/logs/1k-<run>.log.gz`: 18 redacted app + VLC logs, 172 KB together.
  - `reports/screenshots/1k-exact/`: 54 JPEGs, 960 wide (16 paused frames and 2 after Play per run).
  - `reports/screenshots/1k-clock/`: 30 crops.
  - `reports/screenshots/1k-{stargate-back,ww-back,divergent-fwd,magicians-fwd,food-none}-{06-play+3s,07-play+60s}.jpg`.
  - The JSON traces stay off-repo.

## 2. Step 2 — resume matrix

| Run | Position at pause | Position at Play | Dropped / late (first 60 s) | Clock at Play +3 s / +60 s | First audio block's scheduled time vs first picture (traced; not audio start) |
|---|---|---|---|---|---|
| Stargate (a) back ×5 | 33 974 ms | 33 834 ms | **21 / 2** | 00:37 / 01:34 | +130 ms |
| Stargate (b) forward ×5 | 33 975 ms | 34 251 ms | **26 / 1** | 00:38 / 01:35 | +6 ms |
| Stargate (c) no step | 33 954 ms | 33 954 ms | 0 / 1 | 00:37 / 01:34 | n/a |
| Wonder Woman (a) | 34 024 ms | 33 867 ms | **21 / 2** | 00:37 / 01:34 | +127 ms |
| Wonder Woman (b) | 34 027 ms | 34 326 ms | **29 / 1** | 00:38 / 01:35 | +31 ms |
| Wonder Woman (c) | 34 060 ms | 34 060 ms | 0 / 0 | 00:37 / 01:34 | n/a |
| Divergent (a) | 33 878 ms | 33 742 ms | **25 / 1** | 00:37 / 01:34 | +194 ms |
| Divergent (b) | 33 967 ms | 34 243 ms | **29 / 1** | 00:38 / 01:35 | +16 ms |
| Divergent (c) | 33 851 ms | 33 860 ms | 0 / 0 | 00:37 / 01:34 | n/a |
| Magicians S1E1 (a) | 33 599 ms | 33 469 ms | **29 / 2** | 00:37 / 01:34 | +110 ms |
| Magicians S1E1 (b) | 33 570 ms | 33 769 ms | **45 / 2** | 00:38 / 01:35 | +1 ms |
| Magicians S1E1 (c) | 33 832 ms | 33 838 ms | 0 / 2 | 00:37 / 01:34 | n/a |
| Food That Built America S04E02 (a) | 33 635 ms | 33 500 ms | **28 / 2** | 00:37 / 01:34 | +103 ms |
| Food That Built America S04E02 (b) | 33 645 ms | 33 867 ms | **41 / 1** | 00:38 / 01:35 | −8 ms |
| Food That Built America S04E02 (c) | 33 632 ms | 33 632 ms | 0 / 0 | 00:36 / 01:33 | n/a |

**Reading the table.**
- **Position at pause** is VLC's interpolated clock. **Position at Play** after steps is the stepped picture. Back steps land about 130–140 ms earlier; forward steps about 200–300 ms later (VLC's clock at pause runs ahead of the picture).
- **Dropped pictures after steps are D020's accepted item 1.**
  - First-picture lateness from the trace: 953 ms (Stargate back), 1 170 ms (Stargate forward), 1 004 / 1 527 ms (Magicians back / forward), 977 / 1 397 ms (Food back / forward).
  - The 29.97 fps episodes drop more pictures for about the same time, and forward steps drop more than back steps.
- **Late pictures in the controls:**
  - Stargate: `picture displayed late (missing 3 ms)`, trace `late` at +43.6 ms after resume.
  - Magicians: `missing 44 ms` and `missing 14 ms`, trace `late` at +82.9 and +85.8 ms.
  - Wonder Woman, Divergent, Food: none.
- **Subtitles.** Only Stargate had a subtitle track selected in these runs (`ES track selected: 'spu/4'`). Wonder Woman's and Divergent's tracks weren't auto-selected, and the two episodes have none. So 0020's need-data path was exercised on Stargate only.
- **Wonder Woman (a) resumed with its displayed picture 24 s late.** `picture displayed late (missing 24297 ms)`, then `too late … (missing 24257 ms)`, `(missing 24215 ms)`. Trace: a video `RENDER realtime` for PTS 33 867 with `drift -24221107000`, 75.7 ms *before* the vout's `resumed` event.
  - The displayed picture was re-rendered against a clock left from the last step ~24 s earlier. The rest of the resume matched the other films: 21 dropped, clock 00:37 / 01:34.
  - It isn't in any other run, and it isn't instrumented this pass (open question 2).

### 2.1 Step 4: the controls against pass 1i

Pass 1i ran a control on Stargate only: 0 dropped / 0 late, clock 00:37 / 01:34. Pass 1k's Stargate control: 0 dropped / 1 late (3 ms), clock 00:37 / 01:34. I asked you, and your answer was: *"Within noise, continue."* Passes 1e and 1j had also logged a single late picture on a plain resume.

### 2.2 Audio start: not measured, and what was traced instead

**Not measurable in the clean build.** No timestamped audio-start event exists there:
- **Trace.** After Play it carries the audio output's `flushed` / `reset_user` / `resumed` (before any audio is decoded), decoder `DEC IN` / `DEC OUT`, and then only the tvOS output's periodic timing reports (`RENDER … realtime`, first at +1487 ms after steps).
- **Log lines.** The output's `started` / `starting late` lines carry no timestamp. libvlc's `file` logger prints none either, and VLCKit's `libvlc_log_set` replaces the logger modules.

You chose to name it untested.

**Traced instead:** the first audio block's decoder output (`DEC OUT`, timestamped) and the wall time its PTS is scheduled for. It's mapped through the first video render with |drift| < 5 ms: `sched = t(render) − drift + (pts_audio − pts_render)`, reported relative to the first picture.
- **After steps:** audio was flushed, and the first block is scheduled −8 to +194 ms from the first picture.
- **No step:** the renderer was not flushed, so audio queued before the pause plays first. The first `DEC OUT` is then a later block (the script gives 1.35–1.59 s, which isn't the start of sound), so the column says n/a.

**How far this is from sound.** Pass 1j's instrumented run showed the tvOS output starting its renderer (`startNow`) 25 ms before the scheduled date. Its first timing report implies the renderer's timebase left zero only ~460 ms after that. So audible start may be later than the scheduled time; it isn't measured.

## 3. Step 3 — exactness

**Trace method.** Video `DEC OUT` between the pause and Play, grouped by gaps over 1 s (clicks are 4.2 s apart). For a back step, the picture shown is the group's **second-to-last** output, by VLC's previous-frame rule: the stored picture is released when a PTS at or past the displayed one arrives (`decoder_prevframe_AddPic`). This is pass 1f's rule (`stepcheck2.py`) without its stop at the first long group, which VideoToolbox's long decode runs had tripped. A forward step shows the next decoded picture; its group is a 1–6 picture refill. The app's `[framestep] … after(400 ms)=` line gives each click's position.

**Stargate Extended** (MPEG-2 480i, 3:2 grid 33/50 ms):
```
group  1 +  3.69 s: n=  10 pts 63647..64031 last3 [63947, 63981, 64031] -> back step shows 63981
group  2 +  7.78 s: n=  10 pts 63647..64064 last3 [63897, 63947, 63981] -> back step shows 63947 step -34 ms
group  3 + 12.05 s: n=  18 pts 63647..64031 last3 [63864, 63897, 63947] -> back step shows 63897 step -50 ms
group  4 + 16.31 s: n=   7 pts 63647..63897 last3 [63814, 63864, 63897] -> back step shows 63864 step -33 ms
group  5 + 20.53 s: n=   6 pts 63647..63864 last3 [63780, 63814, 63864] -> back step shows 63814 step -50 ms
group  6 + 28.97 s: n=   1 … group 9 + 41.69 s: n=   1   (forward refills 63897, 63947, 63981, 64031)
group 10 + 45.95 s … group 14 + 62.90 s: back steps show 63981, 63947, 63897, 63864, 63814
11:47:43.096 +1 gotoNextFrame before=63814 ms   11:47:43.500 +1 after(400 ms)=63864 ms
… after(400 ms) = 63864, 63897, 63947, 63981, 64031 for clicks 6–10
```
Group 3 decodes its run twice, as pass 1f saw on the same click.

**Divergent** (HEVC 2160p, VideoToolbox, 41.7 ms grid). Each back step decodes from a keyframe ~9 s back (`pts 54763..`):
```
group  1 +  3.71 s: n= 440 pts 54763..63897 last3 [63814, 63855, 63897] -> back step shows 63855
group  2 +  7.85 s: n= 221 … -> back step shows 63814 step -41 ms
group  3 + 12.15 s: n= 220 … -> back step shows 63772 step -42 ms
group  4 + 16.46 s: n= 219 … -> back step shows 63730 step -42 ms
group  5 + 20.76 s: n= 218 … -> back step shows 63689 step -41 ms
forward clicks 6–10: after(400 ms) = 63730, 63772, 63814, 63855, 63897
groups 8–12: back steps show 63855, 63814, 63772, 63730, 63689
```

**Wonder Woman** (HEVC 2160p, VideoToolbox):
```
group  2 +  4.03 s: n=  75 pts 62771..63772 last3 [63689, 63730, 63772] -> back step shows 63730
group  3 +  7.90 s: n=  29 … -> back step shows 63689 step -41 ms
group  4 + 12.25 s: n=  23 … -> back step shows 63647 step -42 ms
group  5 + 16.45 s: n=  23 … -> back step shows 63605 step -42 ms
group  6 + 20.75 s: n=  23 … -> back step shows 63564 step -41 ms
forward clicks 6–10: after(400 ms) = 63605, 63647, 63689, 63730, 63772
groups 9–13: back steps show 63730, 63689, 63647, 63605, 63564
```
Divergent group 7 and Wonder Woman group 8 are labelled "back step" by the script's heuristic. They are refills after the forward clicks (4 and 6 outputs, no run from an earlier keyframe), and the app's positions show no step there.

**Pixel comparison** (`exact1k.py`: mean absolute difference ×10 over the video area, 960×540 scale, pass 1f's crop).

All three films show the same structure:
- **Clicks 1–5 (back):** each gives a new picture. Neighbouring pictures differ (Stargate 12–16, Divergent 6–7, Wonder Woman 137–149), and the difference grows with distance.
- **Clicks 6–10 (forward):** each is identical (**0**) to clicks 4, 3, 2, 1 and the paused picture, in that order.
- **Clicks 11–15 (back again):** each is identical (**0**) to clicks 1–5.

Stargate row, for example:
```
    01-L     12      0     15     24     32     37     32     24     15      0     12      0     15     24     32     37
```
Full matrices are in `1k-analysis.txt`. Screenshots: `reports/screenshots/1k-exact/`.

**Result:** every back click and every forward click moved exactly one decoded picture, on all three films. Forward steps are covered on Stargate and two other films, one more than asked.

**What didn't work.** Two click-window scripts (`exact1k.py`'s trace part, `stepwin.py`) misattributed VideoToolbox decode runs to neighbouring clicks. Their outputs are kept in the analysis file as not used; the gap grouping above is the method used.

## 4. Step 12 — the framework

| Slice | `MinimumOSVersion` | `LC_BUILD_VERSION` | `DTXcodeBuild` | Trace strings |
|---|---|---|---|---|
| `tvos-arm64` | 26.0 | `platform TVOS minos 26.0 sdk 27.0` | 27A266a | 0 |
| `tvos-arm64_x86_64-simulator` | 26.0 | `platform TVOSSIMULATOR minos 26.0 sdk 27.0` (×2) | 27A266a | 0 |

- **Trace strings searched:** `1g: `, `1h: `, `1j: `, `check1`, `demuxed-while-paused`, `decoder notify need_data`, `stop_frame_next`, `avs startNow`.
- **Device slice:** `000000000236e730 S _ff_truehd_decoder`, `_ff_mlp_decoder`, `_ff_mlp_parser`.
- **It is the full recipe's build.** `diff -rq ~/vlckit-build/VLCKit/build/tvOS/VLCKit.xcframework Frameworks/VLCKit.xcframework` reports no differences. That build is pass 1j's restore run of `tools/vlckit-truehd/build.sh`, not `PACKAGE_ONLY`: `patch 0018 installed`, `patch 0019 installed`, `patch 0020 installed`, `build start: 2026-09-14 23:30:42`, `build end: 2026-09-14 23:33:59`, `recipe exit 0`, 20 `Applying:` lines (the last `input: es_out: forward next-frame data requests only from the stepped ES`).
- **Binary date:** 2026-09-14 23:33:59. libvlc is clean at `9279ed3615`.
- **The app** embeds it: 0 trace strings. `TVOS_DEPLOYMENT_TARGET = 26.0` in both configurations.

## 5. What could not be tested live, and what was traced instead

- **Audio start** (step 2): not measured. Traced instead: the first audio block's `DEC OUT` and its scheduled time through an on-time picture (§2.2).
- **Why Wonder Woman (a)'s first picture was 24 s late:** the trace shows it (`drift -24221107000` before `resumed`), but the clock state behind it wasn't instrumented.
- **The need-data flag** in these clean runs isn't logged. 0020's behaviour is pass 1i's and 1j's instrumented evidence; the clocks after Play show no read-ahead.
- **0020's second-pause gap** (D020 item 2) wasn't re-run. It's pass 1j's trace.

## 6. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1, 12 | `Marlin Media TV/PlayerModel.swift` (the 1f diff) | Committed |
| 2, 3 | `reports/logs/1k-analysis.txt`; `reports/logs/1k-*.log.gz` (18); `reports/screenshots/1k-exact/` (54), `1k-clock/` (30), `1k-*-06-play+3s.jpg` / `07-play+60s.jpg` (10) | Committed |
| 2, 3 | Temporary `Marlin Media TVUITests/Diag1kUITests.swift`; traces, raw screenshots and scripts in scratch | Not committed (scratch; nothing deleted) |
| 5–7 | `DECISIONS.md` (D008 marked, D008 revised, D019, D020) | Committed |
| 8 | `reports/2026-09-14-pass1i-frame-back-fix.md` (correction note only) | Committed |
| 9 | `reports/logs/1k-upstream-videolan-draft.md` | Committed; not submitted |
| 10 | `COLD-START.md` (toolchain at 20 patches; pass 1k note) | Committed |
| 11 | This report | Committed |

- **Not touched:** 0007, 0018, 0019, 0020; `build.sh`; libvlc; `Frameworks/` (checked only); Design/; Marlin DVR TV.
- **Constraints kept:** deployment target 26.0; Home Theater only; nothing over 10 MB; identifiers redacted; run names non-empty.
- **Pushed:** nothing.

## 7. Open questions

1. **The drop after forward steps is larger** (26–45 pictures, up to 1.5 s on 29.97 fps episodes) than after back steps (21–29). D020 accepts both as measured. Is that still acceptable once you test?
2. **Wonder Woman (a)'s displayed picture rendered 24 s late at resume**, against a clock from the last step. One run, not reproduced on the other films, not instrumented. Look at it in a later pass?
3. **Audio start stays unmeasured.** A future measurement needs either a timestamped log line (app-side logging, or an instrumented build) or measuring outside the device.
4. **VideoLAN draft:** it's ready. Submit it, and in whose name?

## 8. Least-sure items

1. **Exactness rests on three films and one run each.** The trace rule (second-to-last output per decode run) reads VLC's previous-frame logic from source. Two earlier scripts misread VideoToolbox runs; the gap grouping agrees with the app's positions and the pixel matrices, which are the strongest evidence.
2. **"Within noise" for Stargate's control** is your ruling on one run each (pass 1i and 1k).
3. **The scheduled audio time is not audible start** (§2.2), and pass 1j's own start figure (`startNow`) is only the renderer's rate change.
4. **The 29.97 fps episodes' larger drops** come from one run per step kind.
