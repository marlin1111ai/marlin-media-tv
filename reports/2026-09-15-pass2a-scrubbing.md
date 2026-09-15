# Pass 2a — touch-surface scrubbing — STOPPED at step 5 (landing hits the paused-seek read-ahead) — 2026-09-15

**Result.**
- **Built (steps 1–4), not committed.** The code is written and builds (`** BUILD SUCCEEDED **`), and Home Theater runs it.
  - A horizontal drag on the touch surface pauses playback and shows a scrub bar.
  - The picture follows the target through paused seeks.
  - Click lands and plays; Menu returns to where the drag began.
- **Step 5 hit on the first traced run.** Magicians S1E1: drag forward while playing, then land. Landing plays from where VLC's paused-seek rebuffer loop had read ahead to, not from the target.
  - **Target on the bar:** 03:59 (238 564 ms).
  - **After the click:** the first picture is PTS 266 302 ms. VLC's time at +3 s is 268 585 ms. The on-screen clock reads **04:29** at +3 s and 04:56 at +30 s.
  - **Trace:** after the last seek, VLC laps its rebuffer 12 times in 1.3 s and reads PCR 238.2 → 269.0 s, then stops (§2).
  - **Probe:** the earlier untraced probe did the same (target 79 571 ms, VLC time 102 242 ms at +3 s).
- **Stopped as the pass says.** No further runs, no fix, no libvlc patch, no rebuilt framework.
  - **Not run:** 23 of the 24 matrix runs (Stargate, Wonder Woman and Divergent entirely; Magicians' other five) and the step-4 controls.
  - **Also not done:** your physical drag check.
- **How drags were driven.** XCUIRemote cannot touch the remote's surface (§1.1). You chose the hybrid: an uncommitted Page Up / Page Down hook plays a scripted drag through the same model calls as the pan recognizer. So on the device, the recognizer itself is untested.

**State.**
- **Working tree:** the three player files carry the scrub diff, uncommitted. The same diff is saved as `reports/logs/2a-scrub-app.diff` (shasum of the tree's diff = the saved file's, `efd3ac62…`). The harness hook and the temporary `Diag2aUITests.swift` are out of the tree.
- **Home Theater:** runs that tree without the hook. Rebuilt and installed after the traced run (`** BUILD SUCCEEDED **`, `App installed`).
- **Untouched:** 0007/0018/0019/0020, `Frameworks/`, libvlc, DECISIONS.md, Design/, Marlin DVR TV.
- **Committed locally:** report, evidence, COLD-START. Nothing pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Scrub on the touch surface | **Built, not device-proven for the gesture.** Pan recognizer on the surface (indirect touches) that waits for the left/right swipes to fail and begins only for a mostly horizontal drag. The model pauses, moves the target, lands on click, returns on Menu. The drag itself was driven by the harness hook, not a thumb. |
| 2 Scrub bar visuals | **Built, shown on the device** (§3): frame 10's timeline row (30 pt medium clock labels, 130 pt wide, 26 pt spacing, 8 pt track, accent fill, 10×34 knob with glow) at frames 14/15's place, 80 pt from the sides and 78 pt from the bottom, over frame 10's bottom shade. Knob = target; elapsed/remaining = the target's; a 4×20 `neutral300` mark = where the drag began. Nothing focusable, no thumbnails. |
| 3 Picture follows the target | **Built, works while dragging** (the probe's mid-drag and lifted screenshots show different pictures at 00:54 and 01:20). Paused seeks at most one per 250 ms, plus one on lift. **This is where step 5 hits** (§2). |
| 4 Existing meanings intact | **By code, and partly on the device.** The scrub gate returns before `handle`'s existing switch only while a scrub is up; with no scrub the switch is unchanged. On the device: the traced run's four +30 s click skips while playing landed exactly (`before=32000 target=62000`, `after=62000`, and three more). Frame step, −10 s, Menu-with-panel: **not re-run** (the control runs come after the matrix, which stopped). |
| 5 Read-ahead / need-data | **HIT — STOP** (§2). Paused-seek read-ahead. The need-data flag isn't logged in the clean build (§2.3). |
| Verification matrix | 1 of 24 runs (+ probe). Table in §2.1. |

## 1. Method

### 1.1 Why the drags are scripted

`XCUIRemote` on tvOS has presses only. The SDK header (`XCUIAutomation.framework/Headers/XCUIRemote.h`) lists Up/Down/Left/Right, Select, Menu, PlayPause, Home, PageUp/PageDown, Guide, TVProvider, OneTwoThree, FourColors, and `pressButton:` / `pressButton:forDuration:`. There's no touch or drag API. Marlin DVR TV never automated a swipe either (its DECISIONS 2026-09-07: *"a swipe on the touch surface is not a `UIPress`"*).

I asked; you chose the **hybrid**:
- an uncommitted hook in `PlayerHost` maps Page Up / Page Down (which the Siri Remote doesn't have, and which XCUIRemote can send) to a scripted drag: `scrubBegan()`, then `scrubMoved(fraction:)` 120 times over ~2 s to +0.08 (Page Up) or −0.04 (Page Down) of the surface width, then `scrubLifted()`. These are the same three model calls `panned(_:)` makes (`reports/logs/2a-harness-app.diff`);
- a physical check by you afterwards. **Not done:** the pass stopped first.

### 1.2 Runs

- **Build.** HEAD `e9df636` + the scrub diff + the hook. `xcodebuild build-for-testing … 'platform=tvOS,name=Home Theater'` → `** TEST BUILD SUCCEEDED **`; `devicectl device install app` → `App installed`. Framework: the full recipe's (binary 2026-09-14 23:33:59).
- **Probe** (`probe2a.sh`, test `t0_Probe`): Magicians S1E1, play 15 s, Page Up, land after ~4 s. The console launch reads the app container path; the tracer can't write to its default path, so this run has no trace.
- **Traced run** (`runone2a.sh tMagiciansPlayFwd magicians-playfwd`): pass 1k's console launch with VLCKit's tvOS defaults and the JSON tracer into the container, plus the attach-mode `Diag2aUITests`.
  - **Sequence:** play 30 s, 4 × Right (+30 s) 1.5 s apart, 20 s, Page Up, screenshots at +1 s (mid-drag) and +3 s (lifted), hold to +8 s, Select (land), screenshots at land +3 s and +30 s, Menu.
  - **Timing:** 07:21:08–07:23:32. `Test Case … tMagiciansPlayFwd passed (130.213 seconds)`.
  - **Why Magicians first:** it reproduces the probe's jump on the same file with a trace. The matrix's other runs were queued Stargate → Wonder Woman → Divergent → Magicians.
- **Clocks line up.** Every `[scrub]` line logs `tick=` from `clock_gettime_nsec_np(CLOCK_MONOTONIC)`, VLC's `vlc_tick_now()` clock (`src/posix/thread.c:248`); the tracer's timestamps are ns on that clock. Check: the vout `paused` event is 0.093 s after `[scrub] begin`, which calls `pause()`.
- **Measures** (`reports/logs/2a-analysis.txt`, with outputs and scripts):
  - `scrub2a.py`: position before, target, positions after, click → first realtime video render, dropped/late in 30 s after the vout `resumed` event, DEMUX OUT and PCR from begin to land (split at lift + 2 s).
  - `timeline2a.py`: per-second PCR, reads and events.
  - `laps2a.py`: rebuffer laps after the last seek.
  - Vision OCR of the screenshots' clocks.
- **Evidence.**
  - Logs: `reports/logs/2a-magicians-probe.log.gz`, `reports/logs/2a-magicians-playfwd.log.gz` (redacted app + VLC logs).
  - Screenshots: `reports/screenshots/2a/` (7 JPEGs, 960 wide).
  - Harness: `reports/logs/2a-harness-app.diff` (scrub diff + hook), `reports/logs/2a-harness-Diag2aUITests.swift.txt`.
  - The JSON trace (10.4 MB) stays off-repo.

## 2. Step 5 — landing plays from the paused-seek read-ahead

### 2.1 The numbers

| Run | Position before the drag | Target shown | Position after landing (VLC +1 s / +3 s; on-screen at +3 s / +30 s) | Click → picture | Dropped / late, 30 s after landing | Demux reads while paused during the drag |
|---|---|---|---|---|---|---|
| Magicians S1E1, playing, drag forward, land (traced) | 175 993 ms (02:56) | **238 564 ms (03:59)** | 238 564 / **268 585 ms**; **04:29** / 04:56 | 0.021 s to the first realtime render; its PTS is **266 302 ms**, 27.7 s past the target | 0 / 0 | **3 739** DEMUX OUT, PCR 176.1 → **269.0 s**, all in the ~3.4 s after begin. Of that, after the last seek: 12 laps, PCR 238.2 → 269.0 s. **0** in the 5.1 s hold before the click. |
| Magicians S1E1, playing, drag forward, land (probe, untraced) | 17 000 ms | 79 571 ms (01:20) | 79 571 / **102 242 ms** | not traced | not traced | not traced; 21 `ES_OUT_RESET_PCR` lines between begin and land +3 s |
| The other 23 runs (Stargate, Wonder Woman, Divergent × 6; Magicians × 5) | — | — | — | — | — | **not run (stopped)** |

"Click → picture" is when the first picture rendered; it says nothing about the position. "+1 s" still shows the target because VLCKit's reported time lags the jump; "+3 s" and the screen agree.

### 2.2 The trace

Magicians is an MP4 (`Content-Type: video/mp4`), so D014's `mkv_trusted` doesn't apply. It has no subtitle track.

The drag's nine seeks each run VLC's normal paused seek: `ES_OUT_RESET_PCR called`, `seeking with N ms preroll`, `Stream buffering done`. After the **last** seek (238 564 ms at +2.062 s, lift at +2.061 s), VLC doesn't settle on the target. It laps:
```
7:22:44.390 AM [scrub] seek 238564 ms tick=512722931150
[DBG] seeking with 323ms preroll (use input-fast-seek to avoid) to 238564000
[DBG] Received first picture
7:22:44.574 AM [framestep] nextFrameStepped result=0 time=238564 ms
[DBG] Stream buffering done (1904 ms in 118 ms)
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 739 ms late (pts_delay increased to 1793 ms)
[DBG] ES_OUT_RESET_PCR called
[DBG] Received first picture
7:22:44.638 AM [framestep] nextFrameStepped result=0 time=238564 ms
[DBG] Stream buffering done (1811 ms in 75 ms)
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 534 ms late (pts_delay increased to 2258 ms)
[DBG] ES_OUT_RESET_PCR called
…
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 178 ms late (pts_delay increased to 2327 ms)
```
`laps2a.py` (tracer `input` `reset_user` events come in pairs, one read per pair):
```
last seek 238564 ms at +2.062 s; lift +2.061 s; land +9.173 s
input reset_user events after the last seek: 24
  event  2 + 2.131 s  PCR 238190295 .. 240109167
  event  4 + 2.286 s  PCR 240117552 .. 241944334
  event  6 + 2.363 s  PCR 241951928 .. 244227483
  …
  event 22 + 3.153 s  PCR 262831867 .. 265845261
  event 24 + 3.262 s  PCR 265868234 .. 269004701
last demux PCR before land at +3.387 s: 269004701; target 238564 ms
render after land +0.016 s pts 266302000 drift 502.0 ms
```
`timeline2a.py`, from begin:
```
+  2s PCR 230232634..259204354 (1277)  out {'video': 637, 'audio': 918}  events {… 'input:reset_user': 18 …}
+  3s PCR 259228267..269004701 (587)   out {'video': 293, 'audio': 421}  events {… 'input:reset_user': 6 …}
+  4s … +  8s PCR -                    out {}                               (paused, no reads)
+  9s PCR 269026395..270005701 (60)    events {'audio/2:resumed': 1, 'video/1:resumed': 1}   (land)
```
So the drag leaves ~30 s of stream read past the target within ~1.3 s. The loop stops by itself, and Play starts from its end: 0 dropped, 0 late, and the clock jumps.

This is **pass 1g §3's seek-back control on a different file**: *"Each Left seeks while paused through `INPUT_CONTROL_SET_TIME` → `ES_OUT_RESET_PCR` … Then VLC loops … But playback restarts at the read-ahead position."* There it was 792 laps and a jump from 33.8 s to 209 s on Stargate.

### 2.3 What the trace does not settle

- **Which VLC condition licenses the laps.**
  - The visible trigger is the one pass 1c named: `ES_OUT_SET_(GROUP_)PCR is called … late` → `pts_delay` raised → `ES_OUT_RESET_PCR` → rebuffer. It repeats while `pts_delay` climbs: 11 late lines after lift, 1793 → 2258 → 2327 → … → 3134 ms, with 12 `ES_OUT_RESET_PCR` (all in `2a-analysis.txt`). It stops once the PCR is no longer late.
  - Whether `next_frame_need_data` is also set isn't logged in the clean build, and there's no instrumented build this pass.
  - **The subtitle need-data path (D019) is ruled out** for this file (no subtitle track).
  - **Not ruled out:** the video decoder's own paused-seek request. VLCKit's `nextFrameStepped` fires on each lap, so VLC 4's paused seek goes through the next-frame display path.
- **Whether the laps depend on the drag.** Nine throttled seeks in 2 s, the last with a 323 ms preroll. A single paused seek wasn't isolated.
- **MKV films** (Stargate, Wonder Woman, Divergent, with D014's cues) and a film with a subtitle track (Stargate) weren't run. Pass 1g's seek-back loop was on Stargate MKV, so the same behaviour is likely but not shown.

## 3. Screenshots

`reports/screenshots/2a/`:
- **Traced run** (clock by OCR):
  - `p2a-magicians-playfwd-01-mid-drag.jpg`: bar at 03:32 / −48:36, the picture already moved.
  - `…-02-lifted.jpg`: **03:59** / −48:10.
  - `…-03-after+3s.jpg`: the overlay after landing, **04:29** Playing.
  - `…-04-after+30s.jpg`: 04:56.
- **Probe:**
  - `p2a-magicians-probe-01-mid-drag.jpg`: 00:54 / −51:15, start mark near the left, a park scene.
  - `…-02-lifted.jpg`: 01:20 / −50:49, a different scene (the picture follows the target).
  - `…-03-after+5s.jpg`: after landing.

## 4. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1 | `Marlin Media TV/PlayerHost.swift`: pan recognizer that waits for the side swipes to fail, `panned(_:)`, `gestureRecognizerShouldBegin`. `Marlin Media TV/PlayerModel.swift`: `Scrub` state, `scrubBegan` / `scrubMoved` / `scrubLifted`, land on Select, return on Menu, `[scrub]` log lines with `tick=` | **No**: working tree, and `reports/logs/2a-scrub-app.diff` (committed) |
| 2 | `Marlin Media TV/PlayerScreen.swift`: `ScrubOverlay`, `Scrubber`'s `mark`, overlay / pause mark / skip pill hidden while scrubbing | **No**: same diff |
| 3 | `PlayerModel.swift`: throttled paused seeks (`scrubSeekInterval` 250 ms) and one on lift | **No**: same diff |
| 4 | `PlayerModel.handle`: the scrub gate before the unchanged switch | **No**: same diff |
| 5 / verification | `reports/logs/2a-analysis.txt`, `2a-magicians-probe.log.gz`, `2a-magicians-playfwd.log.gz`, `2a-harness-app.diff`, `2a-harness-Diag2aUITests.swift.txt`; `reports/screenshots/2a/` (7) | Committed |
| verification | Temporary `Marlin Media TVUITests/Diag2aUITests.swift` and the Page Up/Down hook; traces, raw screenshots and scripts in scratch | Not committed. Removed from the tree; copies kept in the reports above and in scratch |
| — | `COLD-START.md` (pass 2a note), this report | Committed |

- **Not touched:** `tools/vlckit-truehd/` (0007 `41df2136…`, 0018 `a491edd8…`, 0019 `39a73a44…`, 0020 `3ea7c4f2…`; `git diff HEAD -- tools` empty); `Frameworks/VLCKit.xcframework` (binary 2026-09-14 23:33:59, no rebuild); libvlc; `DECISIONS.md`; Design/; Marlin DVR TV.
- **Constraints kept:** `TVOS_DEPLOYMENT_TARGET = 26.0` (both configurations); Home Theater only; the largest committed file is 117 KB; UUIDs and UDIDs redacted (0 left in the committed logs); run names non-empty (`runone2a.sh` refuses empty or malformed tags).
- **Pushed:** nothing.

The app diff stays uncommitted because the pass stopped with a known landing defect in it. This follows passes 1f/1g, which kept a stopped change out of `main` and saved its diff. Commit it anyway? (Question 5.)

## 5. What could not be tested live, and what was traced instead

- **The gesture itself:** the pan recognizer, its wait for the swipes to fail, the horizontal-only start, and how far a real thumb moves the target. Driven instead by the scripted drag through the model's calls; your physical check was not done.
- **Swipe skips alongside the pan:** a swipe can't be scripted either, so they're untested. Click skips while playing were on the device (4 of 4 exact).
- **Frame step, −10 s, Menu closing a panel after the change:** not re-run. They're unchanged by code (the scrub gate is inert with no scrub).
- **The need-data flag:** not logged. Read-ahead traced instead (DEMUX OUT, PCR, laps).

## 6. Open questions

1. **How to keep step 3 without the read-ahead, and without a libvlc change?** Options, none tried:
   - (a) the picture doesn't follow while paused: bar only, one seek on click after Play, since seeks while playing land in 0.09–0.55 s (pass 1c);
   - (b) seek while paused only on lift, not during the drag (still a paused seek; may still lap);
   - (c) VLC's `input-fast-seek`, which the log names (`use input-fast-seek to avoid`): untested, and whether it changes the loop is unknown;
   - (d) a diagnosis pass like 1g/1h on the paused-seek loop, which pass 1g's least-sure item 3 left open. The trigger visible here is `PCR is called late` → `pts_delay` up → `ES_OUT_RESET_PCR`.

   Which do you want?
2. **Menu restores the play state** the drag started in: a drag from playing plays again, a drag from paused stays paused. My reading of "returns to where it started"; confirm.
3. **During a scrub, Play/Pause, arrow clicks, swipes and up/down do nothing** (logged `ignored while scrubbing`), since the pass names only click and Menu. tvOS's own player treats Play/Pause as landing. Keep, or define?
4. **Scrub feel values:** one surface width = 25% of the running time, a seek at most every 250 ms, and the target clamped to the running time − 1 s (a target at the very end would stop the input and close the player). Set without a thumb on the remote; your physical check should judge them.
5. **Commit the scrub diff now** (known landing defect, fix pending question 1), or keep it out of `main` until landing is right?
6. **Your physical check** (drag vs swipe, land, Menu) is still to do on the build Home Theater runs now.

## 7. Least-sure items

1. **The recognizer is unproven on the device.** Three things are unverified: that `require(toFail:)` on the side swipes leaves a real drag to the pan quickly enough, that the flick still skips, and what translation width the indirect surface reports. The scripted drag bypasses all of it.
2. **One traced run, one file (MP4 H.264), one direction, one start state.** The probe shows the same jump, untraced. Playing vs paused start, backward drags, cancel, and the MKV films aren't measured.
3. **Which VLC condition drives the laps** (§2.3): the PCR-late/`RESET_PCR` loop is visible; `next_frame_need_data`'s part isn't logged.
4. **The scripted drag's pace** (nine seeks in 2 s) may not match a thumb's. More or fewer paused seeks may change how far VLC reads ahead.
5. **"Click → picture 0.021 s"** is the first render after Play, not the target's picture.
