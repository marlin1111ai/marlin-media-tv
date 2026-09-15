# Pass 2c — preview-playhead scrub — landed and committed — 2026-09-15

**Result.**
- **The scrub lands within one second on every run.** On Home Theater I ran 48 scrubs on Stargate, Wonder Woman, Divergent and Magicians S1E1: forward and back, from playing and from paused, each ending with a click, Play/Pause or Menu.
  - **The 32 landings:** the first picture after the click is **−72 to +104 ms** from the target. The picture on screen 3 s later is within 0.73 s of where 3 s of playback from the target puts it. Click → picture 0.06–0.85 s. At most 1 dropped and 2 late in the 30 s after landing.
  - **The 16 cancels:** playback resumes within 0.81 s of the drag's start position from playing, and at exactly the start from paused.
  - **Pass 2a's case repeated** (Magicians, playing, forward, target 238 564 ms from 175 993 ms): the first picture is +10 ms and the position at +3 s is 241 176 ms, against pass 2a's +27.7 s and 268 585 ms.
- **The picture holds during the drag.** Every drag re-renders a single PTS, the frame the drag began at. Nothing seeks until the scrub lands.
- **Step 8 is unchanged on all four films.** +30 s / −10 s skips land exactly, each click steps one frame back and forward, and Menu closes the open audio panel before it exits.
- **Committed (step 10).** The scrub code, **D021** and COLD-START. The harness hook and the test harness are not committed. Nothing pushed: you test the gesture on the real remote first.
- **The limit on this proof.** Drags are scripted through the model's scrub calls (Page Up/Down hook), because XCUIRemote can't touch the surface. So the recognizer itself is not tested.
- **Found and not diagnosed.** A pause taken after a landing lets the demuxer read at 1× while paused, up to ~36 s of stream (§3). No landing moved.

## Result per step

| Step | Result |
|---|---|
| 1 Re-apply the 2a diffs | **Done.** `2a-harness-app.diff` = `2a-scrub-app.diff` + the 19-line hook (pass 2b), so it was applied alone on HEAD `acb04fa`; the tree then matched it line for line. |
| 2 No seek during the drag | **Done.** `scrubSeekInterval`, the seek task and throttle, the seek on lift and `seekScrubTarget` are removed. `scrubMoved` only moves the target; `scrubLifted` only logs. `PlayerModel.swift` has two seeks left: the landing's and the existing skip's (playing only). |
| 3 Land / cancel | **Done.** Select and Play/Pause → `landScrub(source)`: `play()`, then one `player.time = target` when the target differs from the start. Menu → `cancelScrub()`: no seek; `play()` if the drag began while playing. |
| 4 Drag pauses; 25%; 1 s short | Kept from pass 2a (`scrubSpan = 0.25`, clamp `lengthMs − 1000`, `pause()` on begin). |
| 5 Existing meanings | Unchanged: the scrub gate returns before `handle`'s switch only while a scrub is up. |
| 6 Matrix | **Done**: 8 sessions, 48 scrubs (§2). |
| 7 Landing within 1 s | **Met on every run.** No stop. |
| 8 Step-5 checks | **Done**, 4 films (§4). One harness mistake on the first Stargate control run, fixed and re-run (§4.1). |
| 9 Screenshots | **Done** (§5). |
| 10 Commit, D021, COLD-START | **Done.** |
| 11 This report | Done. |

## 1. Method

- **Build.** HEAD `acb04fa` + `2a-harness-app.diff` + the pass 2c changes. `xcodebuild build-for-testing … 'platform=tvOS,name=Home Theater'` → `** TEST BUILD SUCCEEDED **`, installed. The framework is the full recipe's (untouched).
- **Drags.** The uncommitted hook: Page Up / Page Down → `scrubBegan()`, then 120 × `scrubMoved(fraction:)` over ~2 s to +0.08 / −0.04 of the surface width, then `scrubLifted()`. These are the same calls `panned(_:)` makes. Kept as `reports/logs/2c-harness-app.diff`.
- **Sessions.** Attach-mode XCUITest `Diag2cUITests` (`reports/logs/2c-harness-Diag2cUITests.swift.txt`) under a console launch with VLCKit's tvOS defaults and the JSON tracer (pass 2a's `runone2c.sh`). One session per film × start state:
  - play 30 s, 4 × Right (+30 s), 20 s;
  - then six scrubs: forward/back × click, forward/back × Play/Pause, forward/back × Menu;
  - in a paused session the player is paused 3 s before each scrub;
  - each scrub: drag, screenshot at +1 s (mid-drag), the ending at +5 s, screenshot 3 s later, then 29 s of playback (7 s after a cancel).
  - Every session passed its test case, 280–305 s each.
- **Order.** Stargate → Wonder Woman → Divergent → Magicians. Each session was analysed before the next was started.
- **Clocks.** `[scrub] … tick=` is CLOCK_MONOTONIC µs, VLC's `vlc_tick_now()` clock; the tracer's timestamps are ns on the same clock.
- **Measures** (`scrub2c.py`, `paused2c.py`; `reports/logs/2c-analysis.txt` holds all outputs and scripts):
  - **Before / target:** the app's `begin at` and `lift target=` lines.
  - **First picture − target:** the first realtime video render after the click whose PTS is within 2 s of the target (for Menu, of the start), minus the target. Its time from the click is **click → picture**.
  - **Position at +3 s (trace):** the PTS on screen 3 s after the click. Its error is against target + (3 s − click → picture). VLCKit's own time at +3 s is listed beside it; it lags on slow starts (§2.2).
  - **Dropped / late:** video `toolate` / `late` from the first picture for 30 s.
  - **Demux reads while paused during the drag:** tracer DEMUX OUT events from begin to the ending.
- **Step 7's test.** The first picture's PTS against the target, and the +3 s trace position against its expected value. Both must be within 1 s.

## 2. Step 6 — the matrix

Columns: session, scrub number, start state, drag direction, ending; position before the drag (ms); target shown (ms); position at +3 s from the trace (ms, error in parentheses); VLCKit's time at +3 s (ms); first picture − target (ms; for Menu, − start); click → picture (s); dropped / late in 30 s; demux reads while paused during the drag.

| Session | # | From | Drag | Ending | Before | Target shown | +3 s (trace, error) | +3 s (VLCKit) | First picture − target | Click → picture | Dropped / late | Reads while paused |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| stargate-play | 1 | playing | fwd | click | 176991 | 332952 | 335635 (−244) | 335661 | −19 | 0.073 | 0 / 2 | 0 |
| stargate-play | 2 | playing | back | click | 364960 | 286980 | 289673 (−247) | 289008 | −10 | 0.06 | 0 / 0 | 314 |
| stargate-play | 3 | playing | fwd | Play/Pause | 319008 | 474969 | 477610 (−281) | 476976 | −28 | 0.078 | 1 / 0 | 314 |
| stargate-play | 4 | playing | back | Play/Pause | 506976 | 428996 | 431648 (−258) | 431705 | −17 | 0.09 | 0 / 2 | 314 |
| stargate-play | 5 | playing | fwd | Menu | 461024 | 616985 | 464264 (+306) | 464280 | +320 | 0.066 | 0 / 0 | 313 |
| stargate-play | 6 | playing | back | Menu | 471279 | 393299 | 474891 (+679) | 474908 | +693 | 0.067 | 0 / 0 | 0 |
| stargate-pause | 1 | paused | fwd | click | 177029 | 332990 | 335435 (−471) | 335488 | −24 | 0.084 | 0 / 2 | 0 |
| stargate-pause | 2 | paused | back | click | 365120 | 287140 | 289673 (−349) | 289776 | −53 | 0.118 | 0 / 0 | 311 |
| stargate-pause | 3 | paused | fwd | Play/Pause | 319366 | 475327 | 477944 (−315) | 477976 | −19 | 0.068 | 0 / 0 | 317 |
| stargate-pause | 4 | paused | back | Play/Pause | 507623 | 429643 | 432098 (−480) | 432153 | −47 | 0.065 | 0 / 1 | 305 |
| stargate-pause | 5 | paused | fwd | Menu | 461769 | 617730 | 461795 (+26) | 461769 | +26 | 0.007 | 0 / 1 | 318 |
| stargate-pause | 6 | paused | back | Menu | 461769 | 383789 | 461795 (+26) | 461769 | +26 | 0.016 | 0 / 0 | 316 |
| ww-play | 1 | playing | fwd | click | 176259 | 345783 | 348181 (−461) | 348241 | −21 | 0.141 | 0 / 1 | 0 |
| ww-play | 2 | playing | back | click | 377786 | 293024 | 295462 (−434) | 295520 | +19 | 0.128 | 0 / 0 | 6923 |
| ww-play | 3 | playing | fwd | Play/Pause | 325033 | 494557 | 497080 (−261) | 497126 | +104 | 0.216 | 0 / 0 | 7108 |
| ww-play | 4 | playing | back | Play/Pause | 526560 | 441798 | 444361 (−288) | 444425 | +60 | 0.149 | 0 / 0 | 6979 |
| ww-play | 5 | playing | fwd | Menu | 473813 | 643337 | 477060 (+363) | 477097 | +411 | 0.116 | 0 / 0 | 6955 |
| ww-play | 6 | playing | back | Menu | 484098 | 399336 | 487737 (+732) | 487813 | +803 | 0.093 | 0 / 0 | 0 |
| ww-pause | 1 | paused | fwd | click | 176519 | 346043 | 348181 (−726) | 348207 | −72 | 0.136 | 0 / 0 | 0 |
| ww-pause | 2 | paused | back | click | 377913 | 293151 | 295504 (−522) | 295555 | +17 | 0.125 | 0 / 0 | 7164 |
| ww-pause | 3 | paused | fwd | Play/Pause | 325255 | 494779 | 497080 (−532) | 497140 | +90 | 0.167 | 0 / 1 | 6961 |
| ww-pause | 4 | paused | back | Play/Pause | 526831 | 442069 | 444611 (−281) | 444648 | +81 | 0.177 | 0 / 0 | 7105 |
| ww-pause | 5 | paused | fwd | Menu | 474347 | 643871 | 474391 (+44) | 474347 | +44 | 0.046 | 0 / 0 | 7096 |
| ww-pause | 6 | paused | back | Menu | 474347 | 389585 | 474391 (+44) | 474347 | +44 | 0.07 | 0 / 0 | 6865 |
| divergent-play | 1 | playing | fwd | click | 174746 | 342333 | 344761 (−261) | 344818 | +9 | 0.311 | 0 / 0 | 0 |
| divergent-play | 2 | playing | back | click | 374336 | 290543 | 292709 (−329) | 292750 | +39 | 0.505 | 0 / 0 | 679 |
| divergent-play | 3 | playing | fwd | Play/Pause | 321751 | 489338 | 491700 (−293) | 491770 | −16 | 0.345 | 0 / 1 | 671 |
| divergent-play | 4 | playing | back | Play/Pause | 521344 | 437551 | 439439 (−262) | 438557 | +11 | 0.85 | 0 / 0 | 668 |
| divergent-play | 5 | playing | fwd | Menu | 468557 | 636144 | 472097 (+621) | 472141 | +662 | 0.081 | 0 / 0 | 669 |
| divergent-play | 6 | playing | back | Menu | 479557 | 395764 | 482816 (+359) | 482825 | +381 | 0.1 | 0 / 0 | 0 |
| divergent-pause | 1 | paused | fwd | click | 174258 | 341845 | 344177 (−446) | 344232 | −45 | 0.222 | 1 / 0 | 0 |
| divergent-pause | 2 | paused | back | click | 373934 | 290141 | 292209 (−521) | 292277 | −18 | 0.411 | 0 / 1 | 671 |
| divergent-pause | 3 | paused | fwd | Play/Pause | 321974 | 489561 | 491866 (−331) | 491918 | +53 | 0.364 | 1 / 0 | 676 |
| divergent-pause | 4 | paused | back | Play/Pause | 521629 | 437836 | 439648 (−335) | 438845 | +18 | 0.853 | 0 / 0 | 676 |
| divergent-pause | 5 | paused | fwd | Menu | 469400 | 636987 | 469469 (+69) | 469400 | +69 | 0.048 | 0 / 0 | 682 |
| divergent-pause | 6 | paused | back | Menu | 469400 | 385607 | 469469 (+69) | 469400 | +69 | 0.019 | 0 / 0 | 675 |
| magicians-play | 1 | playing | fwd | click | 175993 | 238564 | 241176 (−292) | 241186 | +10 | 0.096 | 0 / 0 | 0 |
| magicians-play | 2 | playing | back | click | 270561 | 239276 | 241844 (−305) | 241865 | −1 | 0.127 | 0 / 0 | 403 |
| magicians-play | 3 | playing | fwd | Play/Pause | 271258 | 333829 | 336238 (−295) | 336258 | −26 | 0.296 | 0 / 0 | 420 |
| magicians-play | 4 | playing | back | Play/Pause | 365810 | 334525 | 337106 (−338) | 337141 | −22 | 0.081 | 0 / 0 | 0 |
| magicians-play | 5 | playing | fwd | Menu | 366507 | 429078 | 369805 (+367) | 369836 | +396 | 0.069 | 0 / 0 | 421 |
| magicians-play | 6 | playing | back | Menu | 377506 | 346221 | 380516 (+74) | 380552 | +107 | 0.064 | 0 / 0 | 0 |
| magicians-pause | 1 | paused | fwd | click | 176298 | 238869 | 241310 (−439) | 241359 | −61 | 0.12 | 1 / 1 | 0 |
| magicians-pause | 2 | paused | back | click | 271077 | 239792 | 242144 (−489) | 242188 | −16 | 0.159 | 0 / 0 | 421 |
| magicians-pause | 3 | paused | fwd | Play/Pause | 271882 | 334453 | 336972 (−409) | 337012 | −16 | 0.072 | 0 / 0 | 420 |
| magicians-pause | 4 | paused | back | Play/Pause | 366744 | 335459 | 337973 (−347) | 337994 | −21 | 0.139 | 0 / 1 | 420 |
| magicians-pause | 5 | paused | fwd | Menu | 367713 | 430284 | 367736 (+23) | 367713 | +24 | 0.088 | 0 / 0 | 421 |
| magicians-pause | 6 | paused | back | Menu | 367713 | 336428 | 367736 (+23) | 367713 | +24 | 0.071 | 0 / 0 | 422 |

### 2.1 Reading the table

- **Landings.** First picture −72…+104 ms from the target; the +3 s trace position is −244…−726 ms from its expected value. Every landing is within 1 s on both measures.
  - The negative +3 s error is the part of the first second before normal pacing: the first picture after a seek is held until audio starts.
  - Menu rows are "resume − start": from playing, +74…+732 ms (the pause lands a few frames after `begin` reads the time). From paused, +23…+69 ms is the displayed frame against VLCKit's reported time; the position is unchanged, as VLCKit's +3 s time shows.
- **The picture holds.** `paused2c.py`: during each of the 48 drags, the realtime video renders all carry one PTS, the frame at the drag's start. Stargate play scrub 1: 60 renders, PTS 177 110 001 for a start of 176 991 ms.
- **Old-position pictures.** Between the click and the target picture, one picture at the old position rendered in 3 of 32 landings: stargate-play 4, stargate-pause 2 and 3. That's `play()` resuming for a frame before the seek's flush. Audio in that moment was not measured.
- **Late starts.** Divergent back + Play/Pause (0.85 s / 0.853 s): that seek's preroll decoded from a keyframe 9 s before the target (`Stream buffering done (9009 ms in 602 ms)`). After the first picture, playback ran with no gap: 30 / 22 / 24 renders per second, largest gap 103 ms (§2.2).
- **Reads while paused:** §3.

### 2.2 Divergent back + Play/Pause (the slow start)

From `reports/logs/2c-analysis.txt`:
```
landing 4 (playPause) target 437551 ms: first picture +0.850 s pts 437562001
  picture+0s: renders 30 pts 437562001..438438001 max gap 103 ms
  picture+1s: renders 22 pts 438480001..439272001 max gap 86 ms
  picture+2s: renders 24 pts 439314001..440273001 max gap 46 ms
8:24:43.382 AM [scrub] land playPause from 521344 ms at 437551 ms tick=516441923217
8:24:43.382 AM [scrub] seek 437551 ms after play tick=516441923713
[DBG] seek: preroll{ req: 437551001, start-pts: 429554001, start-fpos: 770615056}
[DBG] Stream buffering done (9009 ms in 602 ms)
8:24:44.414 AM [scrub] land +1 s time=437551 ms (expected 437551 ms) state Playing
8:24:46.425 AM [scrub] land +3 s time=438557 ms (expected 437551 ms) state Playing
```
VLCKit's time at +3 s (438 557 ms) reads 1.14 s behind the picture on screen (439 439 ms). That is why the +3 s check uses the trace.

## 3. Demux reads while paused (found, not diagnosed)

The pass asked for the count per run (the table's last column). What the traces show (`paused2c.py`, all in the analysis file):
- **When it happens.** A pause (a drag's own, or the harness's before a paused scrub) that follows an earlier landing: the demuxer keeps reading at **1×** while paused (PCR +2 s per 2 s of wall time) until Play.
  - **The cap.** In the long paused stretches it stops after **35.9 / 36.1 / 36.2 / 36.2 s** of stream (Stargate / Wonder Woman / Divergent / Magicians), e.g. 36.1 s over a 96.2 s pause on Wonder Woman.
  - **When it doesn't.** The first scrub of each session (paused 20 s after the skips) reads nothing. So do most scrubs after a cancel, and Magicians play scrub 4 after a landing.
- **Not subtitles.** Only Stargate has a subtitle track selected (`ES track selected: 'spu/4'`); Wonder Woman, Divergent and Magicians have none and read the same way.
- **What it is not:**
  - **Not pass 2a's read-ahead:** no seek happens while paused, there are no flush events in any drag window (0 in all 48), and it runs at 1×, not flat out.
  - **No effect on landings:** the landing seek flushes it; see §2.
- **What it costs:** memory for up to ~36 s of queued stream while paused; not measured beyond the event counts.
- **Why:** not investigated, as the pass asks. It may be D020 item 2's `next_frame_need_data` path or VLC's network-cache refill; neither is shown.

## 4. Step 8 — existing meanings

`reports/logs/2c-analysis.txt` §"step 8 controls". The control run: play 30 s, Right, Left, pause, 3 × Left and 3 × Right clicks, Play, Up, Up, Select (audio panel), Menu, Menu. All four passed their test case.

| Film | +30 s (before → after) | −10 s | Back clicks (after 400 ms) | Forward clicks | Menu with panel open | Second Menu |
|---|---|---|---|---|---|---|
| Stargate | 32 676 → 62 676 | 65 321 → 55 321 | 58 191, 58 141, 58 108 | 58 141, 58 191, 58 225 | `panel closed` | `dismiss` |
| Wonder Woman | 32 674 → 62 674 | 64 953 → 54 953 | 57 594, 57 599, 57 558 | 57 599, 57 641, 57 683 | `panel closed` | `dismiss` |
| Divergent | 32 000 → 62 000 | 64 016 → 54 016 | 56 390, 56 390, 56 306 | 56 348, 56 390, 56 431 | `panel closed` | `dismiss` |
| Magicians S1E1 | 32 000 → 62 000 | 64 572 → 54 572 | 57 393, 57 359, 57 326 | 57 359, 57 393, 57 426 | `panel closed` | `dismiss` |

- **Skips:** exact to the millisecond.
- **Frame steps:** on each file's grid (Stargate 33/50 ms, the HEVC films ~41.7 ms, Magicians 33.4 ms). Forward clicks retrace the back clicks' positions and then step one further.
- **The first back click's reading.** On Wonder Woman and Divergent it reads the same as or above the paused clock. The app reads the time 400 ms after the call, which is VLC's interpolated clock, as in pass 1k (least-sure 5). Pass 1k's exactness proof (trace plus pixels) was not repeated.

### 4.1 One harness mistake, fixed

The first Stargate control run **failed**. The harness pressed Up once after Play, when the overlay had already faded. `handle(.up)` only moves focus to Audio `if overlayVisible`, so Up only showed the overlay; Select then paused (`[player] pause (select) at 65040 ms`) and Menu exited.
- **The app's behaviour is unchanged** from HEAD: the Up rule is untouched.
- **The fix:** press Up twice. It needed a test rebuild, so the controls ran after all sessions (a reinstall changes the container path), and the run was repeated as `stargate-control2` (passed).
- **The log kept:** `reports/logs/2c-stargate-control1-harness-fail.log.gz`.

## 5. Step 9 — screenshots

`reports/screenshots/2c/` (960 wide; clocks read by OCR from the 3840×2160 originals):
- `p2c-stargate-play-01-fwd-click-a-mid-drag.jpg`: the bar mid-drag, **04:28** / −2:05:30, start mark at the left of the knob. The picture is the frame the drag began at (02:57).
- `p2c-magicians-pause-02-back-click-a-mid-drag.jpg`: a backward drag from paused, 04:13 / −47:56.
- `p2c-ww-play-01-fwd-click-b-after+3s.jpg`: after landing with a **click**, overlay **05:48** Playing (target 05:45.8).
- `p2c-ww-play-03-fwd-playpause-b-after+3s.jpg`: after landing with **Play/Pause**, **08:17** Playing (target 08:14.6).
- `p2c-stargate-play-05-fwd-menu-b-after+3s.jpg`: after **Menu** cancels a drag from playing, **07:44** Playing (start 07:41.0).
- `p2c-magicians-pause-05-fwd-menu-b-after+3s.jpg`: after **Menu** cancels a drag from paused, **06:08** Paused (start 06:07.7), frame-step hints shown.

## 6. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1–5 | `Marlin Media TV/PlayerHost.swift` (pan recognizer, `panned`, `gestureRecognizerShouldBegin`; as pass 2a), `PlayerModel.swift` (scrub state, gate with Select / Play/Pause / Menu, `scrubBegan` / `scrubMoved` / `scrubLifted` with no seek, `landScrub(source)` with play then one seek, `cancelScrub` with no seek, `[scrub]` lines), `PlayerScreen.swift` (`ScrubOverlay`, `Scrubber` mark; as pass 2a). The diff is `reports/logs/2c-scrub-app.diff` (192+/6−). | **Committed** |
| 10 | `DECISIONS.md` (D021), `COLD-START.md` (pass 2c note) | **Committed** |
| 6–9 | `reports/logs/2c-analysis.txt`; `2c-{stargate,ww,divergent,magicians}-{play,pause}.log.gz` (8); `2c-{stargate-control2,ww,divergent,magicians}-control.log.gz`, `2c-stargate-control1-harness-fail.log.gz`; `2c-harness-app.diff`, `2c-harness-Diag2cUITests.swift.txt`; `reports/screenshots/2c/` (6) | **Committed** |
| 11 | This report | **Committed** |
| 6–9 | The Page Up/Down hook in `PlayerHost.swift` and `Marlin Media TVUITests/Diag2cUITests.swift` | **Not committed.** Removed from the tree after the runs; copies in the reports above. JSON traces (≤ 13 MB each), raw screenshots and scripts stay in scratch. |

- **Home Theater** runs the committed code: `** BUILD SUCCEEDED **`, `App installed` after the hook was removed.
- **Not touched:** `tools/vlckit-truehd/` (0007, 0018, 0019, 0020), `Frameworks/VLCKit.xcframework`, libvlc, VLCKit's private player pointer, Design/, Marlin DVR TV.
- **Constraints kept:** `TVOS_DEPLOYMENT_TARGET = 26.0` (both configurations); Home Theater only, no simulator; the largest committed file is 75 KB; logs redacted (0 UUID/UDID patterns); run names non-empty (one empty tag was refused by the run script and nothing ran).
- **Pushed:** nothing.

## 7. Open questions

1. **Your test on the real remote.** It is the part this pass couldn't prove. What to check:
   - does a slow thumb drag scrub while a flick still skips?
   - does a vertical drag leave the scrub alone?
   - is 25% per width comfortable?
   - do click, Play/Pause and Menu do what D021 says?
2. **Reads while paused after a landing** (§3), up to ~36 s of stream held in memory, no effect on position. Look into it in a later pass, or accept it?
3. **One old-position picture** before the target in 3 of 32 landings (§2.1), from `play()` before the seek. Acceptable, or should the landing seek come first (which would be a paused seek again)?
4. **Arrows, swipes and up/down do nothing during a scrub** (pass 2a question 3; Play/Pause now lands). Keep?
5. **Divergent's 0.85 s start** when the target is far past a keyframe: acceptable?

## 8. Least-sure items

1. **The gesture recognizer is untested on the device.** The pan's wait for the side swipes to fail, the horizontal-only start and the touch surface's translation width are all bypassed by the scripted drag.
2. **What VLC does between `play()` and the seek.** The two calls are made back to back on the main thread. Whether VLC processes the seek before or after it resumes isn't traced at the control level; the landings are right either way in these runs.
3. **Audio at landing and cancel** isn't measured (no timestamped audio start, as pass 1k).
4. **One run per case.** 48 scrubs, each case once, at one scripted drag pace.
5. **Frame-step "exactly one frame"** rests on the app's positions this pass, not pass 1k's trace and pixel comparison. The first back click's 400 ms reading is the interpolated clock.
6. **The cause and memory cost of the reads while paused** (§3) are unknown.
