# Pass 2d — the owner's scrub flow — committed — 2026-09-15

**Result.**
- **Your defect is found, and it was the app** (step 1, §1). A paused swipe was read as a left/right **swipe**, not a scrub. The scrub pan waited for the swipe recognizers to fail, so a flick always ended as a swipe, and D008's paused rule drops a swipe.
- **Your flow is built as written** (step 2):
  - Play/Pause pauses.
  - Paused, a swipe or drag scrubs: the picture holds and nothing seeks until landing.
  - Paused, a left/right click steps one frame.
  - Play/Pause, or a click on the touch surface, lands at the target and plays.
  - Menu cancels and stays paused where the drag began.
  - While playing, a drag does nothing; skips are unchanged.
- **Drag-while-playing is removed** (step 3). D021 is revised (step 4).
- **Verified on Home Theater on all four films** (step 5, §2–§4). Drags were scripted through the model.
  - **24 paused scrubs.** 16 landings put the first picture **−74 to +94 ms** from the target. The picture on screen 3 s later is within 0.78 s of where 3 s of playback puts it. The 8 Menu cancels stay paused at the drag's start.
  - **Frame steps:** five left and five right clicks gave **one picture per click** on every film, by pixel comparison.
  - **Playing:** both drags on every film were refused (no scrub, no pause), and −10 s / +30 s were exact.
- **Step 7 was not triggered.**
- **One test run failed and was re-run at your call** (§5). A Play/Pause press XCTest reports sending never reached the app. The re-run and all later runs lost no press.
- **Not yet exercised on the device: the gesture itself** (step 6). XCUIRemote cannot touch the surface. §6 lists exactly what to try by hand.
- **Committed locally**, not pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Diagnose | **Done** (§1). Your app log was copied off Home Theater before any launch or install. |
| 2 The flow | **Done.** `PlayerHost.swift`: the pan no longer `require(toFail:)`s the side swipes, recognizes alongside them, and begins only while paused for a mostly horizontal drag. `PlayerModel.swift`: no scrub while playing; the scrub appears once the drag moves the target (a touch with a click shows no bar and blocks no click); a press ends a drag that hasn't moved the target; Menu drops the scrub and stays paused. Landing is unchanged from pass 2c (`play()`, then one seek). |
| 3 Remove drag-while-playing | **Done.** `scrubBegan` returns while playing (`[scrub] drag while playing: no action`), and the pan refuses to begin while playing. |
| 4 D021 | **Done.** `DECISIONS.md` "2026-09-15 — pass 2d", **D021 (revised)**; the pass 2c interaction is marked superseded and kept for the record. |
| 5 Verify | **Done**, 4 films (§2–§4). |
| 6 The gesture on the device | **Not possible with the test API** (XCUIRemote has presses only). What to try by hand: §6. |
| 7 Stop conditions | Not met: every landing is within 1 s, and every click moved one picture. |
| 8 COLD-START, this report | **Done.** |

## 1. Step 1 — the cause

**Evidence:** `reports/logs/2d-owner-remote-session.log.gz` (your session, 09:01:51–09:03:30; the app truncates the log once per launch, so this is that launch's whole record; full sequence in `reports/logs/2d-analysis.txt` §step 1).

**Which input the paused swipe was read as: a left/right swipe** (`UISwipeGestureRecognizer`, source `"swipe"`). D008's paused rule ignores it:
```
9:02:31.244 AM [player] state Paused at 1039059 ms
9:02:31.941 AM [player] right swipe while paused: no action (frame step is on click)
9:02:32.424 AM [player] right swipe while paused: no action (frame step is on click)
9:02:32.707 AM [player] right swipe while paused: no action (frame step is on click)
9:02:32.971 AM [player] right swipe while paused: no action (frame step is on click)
9:02:33.457 AM [player] right swipe while paused: no action (frame step is on click)
…
9:03:27.605 AM [player] state Paused at 4531 ms          (Wonder Woman)
9:03:28.195 AM [player] right swipe while paused: no action (frame step is on click)
9:03:29.566 AM [player] left swipe while paused: no action (frame step is on click)
```
Counts over the session: `swipe while paused` **19**, `[scrub] begin` **4**, `ignored while scrubbing` **27**. The paused picture shows the frame-step hints ("click: frame back / frame forward") and nothing moves, which is why it looked like frame-by-frame mode.

**Why the scrub gesture did not start.** Pass 2a's `PlayerHost` set `for swipe in sideSwipes { pan.require(toFail: swipe) }`. A pan with that requirement can only begin once both side swipes have *failed*. A flick is a successful swipe, so the pan fails with it and `scrubBegan` is never called. Only a drag slow enough for the swipe recognizer to give up began a scrub, 4 times in your session. Once a scrub was up, each further flick was still recognized as a swipe and ignored:
```
9:02:39.525 AM [scrub] begin at 1039674 ms playing=false
9:02:41.635 AM [scrub] right(source: "swipe") ignored while scrubbing
9:02:42.346 AM [scrub] right(source: "swipe") ignored while scrubbing
9:02:43.570 AM [scrub] left(source: "swipe") ignored while scrubbing
```

**A second problem in the same log: scrubs started while playing.** A click to land, then a touch-pan right after it:
```
9:02:04.560 AM [scrub] land select from 2686 ms at 1023072 ms
9:02:04.605 AM [player] state Playing at 1023072 ms
9:02:04.760 AM [scrub] begin at 1023072 ms playing=true
9:02:04.816 AM [player] state Paused at 1023072 ms
```
Also after two +30 s swipe skips (`9:03:06.870 AM [scrub] begin at 2508333 ms playing=true`). Pass 2c's drag-while-playing paused the film each time. Removed in this pass (step 3).

## 2. Step 5 — paused scrubs

**Method** (as pass 2c; details and scripts in `reports/logs/2d-analysis.txt`):
- **Build and runs.** The committed code plus an uncommitted Page Up/Down hook that plays a 2 s scripted drag through the model's scrub calls (`reports/logs/2d-harness-app.diff`). Attach-mode `Diag2dUITests` under a traced console launch, one session per film.
- **Each session:** play 30 s, 4 × +30 s, 20 s, then six scrubs. The harness presses Play/Pause to pause before each scrub that follows a landing.
  - forward → Play/Pause
  - back → click
  - forward → click
  - back → Play/Pause
  - forward → Menu
  - back → Menu
- **Measures:**
  - **First picture − target:** the first realtime video render after the press within 2 s of the target, minus the target (for Menu, minus the start).
  - **+3 s:** the picture on screen 3 s after the press (trace), with its error against target + (3 s − press → picture), and VLCKit's time.
  - **Dropped / late:** in the 30 s from the first picture.
  - **Reads while paused:** demux reads between the drag's start and the press.
- **Lost presses:** a press count compares XCTest's sent presses with the app's logged ones on every run. None were lost on these four runs (Play/Pause 7 of 7, Menu 3 of 3 on each).

| Session | # | Drag | Ending | Before (ms) | Target shown (ms) | +3 s trace (error) | +3 s VLCKit | First picture − target (ms) | Press → picture (s) | Dropped / late | Reads while paused |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Stargate | 1 | fwd | Play/Pause | 176362 | 332323 | 334768 (−491) | 334794 | −58 | 0.064 | 0 / 1 | 0 |
| Stargate | 2 | back | click | 364436 | 286456 | 288972 (−369) | 289048 | −37 | 0.115 | 0 / 1 | 315 |
| Stargate | 3 | fwd | click | 318646 | 474607 | 477227 (−319) | 476624 | −50 | 0.061 | 0 / 0 | 304 |
| Stargate | 4 | back | Play/Pause | 506880 | 428900 | 431348 (−488) | 431395 | −5 | 0.064 | 1 / 1 | 314 |
| Stargate | 5 | fwd | Menu | 461026 | 616987 | 461094 (+68) | 461026 | +68 | 0.013 | 0 / 1 | 313 |
| Stargate | 6 | back | Menu | 461026 | 383046 | 461094 (+68) | 461026 | +68 | 0.094 | 0 / 0 | 312 |
| Wonder Woman | 1 | fwd | Play/Pause | 175632 | 345156 | 347305 (−662) | 347365 | −61 | 0.189 | 0 / 0 | 0 |
| Wonder Woman | 2 | back | click | 377045 | 292283 | 294377 (−772) | 294439 | −74 | 0.134 | 0 / 0 | 7051 |
| Wonder Woman | 3 | fwd | click | 324137 | 493661 | 495996 (−528) | 496047 | +41 | 0.137 | 0 / 0 | 6964 |
| Wonder Woman | 4 | back | Play/Pause | 525734 | 440972 | 443276 (−543) | 443312 | +94 | 0.153 | 0 / 0 | 7049 |
| Wonder Woman | 5 | fwd | Menu | 473024 | 642548 | 473056 (+32) | 473024 | +32 | 0.05 | 0 / 0 | 6984 |
| Wonder Woman | 6 | back | Menu | 473024 | 388262 | 473056 (+32) | 473024 | +32 | 0.011 | 0 / 0 | 7102 |
| Divergent (re-run) | 1 | fwd | Play/Pause | 174832 | 342419 | 344553 (−578) | 344614 | +48 | 0.288 | 1 / 0 | 0 |
| Divergent (re-run) | 2 | back | click | 374351 | 290558 | 292459 (−626) | 291560 | +24 | 0.473 | 0 / 0 | 691 |
| Divergent (re-run) | 3 | fwd | click | 322261 | 489848 | 492325 (−451) | 492368 | +16 | 0.072 | 0 / 0 | 679 |
| Divergent (re-run) | 4 | back | Play/Pause | 522070 | 438277 | 439981 (−360) | 439283 | −6 | 0.936 | 0 / 1 | 666 |
| Divergent (re-run) | 5 | fwd | Menu | 469726 | 637313 | 469761 (+35) | 469726 | +35 | 0.02 | 0 / 0 | 674 |
| Divergent (re-run) | 6 | back | Menu | 469726 | 385933 | 469761 (+35) | 469726 | +35 | 0.073 | 0 / 0 | 695 |
| Magicians S1E1 | 1 | fwd | Play/Pause | 176294 | 238865 | 241210 (−571) | 241236 | −57 | 0.084 | 1 / 1 | 0 |
| Magicians S1E1 | 2 | back | click | 270953 | 239668 | 241910 (−616) | 241947 | −59 | 0.142 | 0 / 1 | 421 |
| Magicians S1E1 | 3 | fwd | click | 271662 | 334233 | 336672 (−387) | 336704 | −30 | 0.174 | 0 / 1 | 420 |
| Magicians S1E1 | 4 | back | Play/Pause | 366449 | 335164 | 337573 (−467) | 337597 | −27 | 0.124 | 0 / 1 | 420 |
| Magicians S1E1 | 5 | fwd | Menu | 367318 | 429889 | 367403 (+85) | 367318 | +85 | 0.091 | 0 / 0 | 420 |
| Magicians S1E1 | 6 | back | Menu | 367318 | 336033 | 367403 (+85) | 367318 | +85 | 0.059 | 0 / 0 | 420 |

- **Landings (16):**
  - **Position:** first picture −74 to +94 ms from the target, the same for Play/Pause and click. The +3 s picture is −319 to −772 ms from its expected value (the first second after a seek isn't fully paced).
  - **Speed:** press → picture 0.061–0.936 s. The 0.936 s is Divergent back + Play/Pause, a seek decoding from a keyframe far before the target, with one picture from the old position shown first.
  - **Drops:** at most 1 dropped and 1 late.
- **Menu (8):** VLCKit's time at +3 s equals the start exactly, so the film stayed paused where the drag began. The +32…+85 ms is the displayed frame against VLCKit's reported time.
- **The picture holds:** during all 24 drags the realtime video renders carry one PTS, the frame at the drag's start (e.g. Stargate scrub 1: 60 renders, PTS 176 443 001 for a start of 176 362 ms).
- **Reads while paused:** the pass 2c pattern, not diagnosed. None before the first landing; afterwards the demuxer reads at 1× while paused, capped at ~36 s of stream (35.6 / 36.2 / 36.3 / 36.0 s). No seek or flush in any drag window.

## 3. Step 5 — frame step, five left and five right clicks (paused)

`fs2d.py`, pass 1k's pixel method (mean absolute difference ×10 over the picture area, 960×540), on screenshots 3 s after each click, plus the app's per-click positions. Rule: every click shows a different picture from the one before, and the right clicks retrace the left clicks with identical pictures (R6 = L4, R7 = L3, R8 = L2, R9 = L1, R10 = the paused picture).

| Film | Difference from the previous picture, clicks 1–10 | R6=L4, R7=L3, R8=L2, R9=L1, R10=paused | App positions (back ×5, then forward ×5) |
|---|---|---|---|
| Stargate (MPEG-2) | 17 16 16 14 16 · 16 14 16 16 17 | **0 0 0 0 0** | 69536 69486 69453 69403 69369 · 69403 69453 69486 69536 69570 (33/50 ms grid) |
| Wonder Woman (HEVC) | 128 128 128 127 125 · 125 127 128 128 128 | **0 0 0 0 0** | 69456 69444 69403 69361 69319 · 69361 69403 69444 69486 69528 |
| Divergent (HEVC) | 16 16 16 16 15 · 15 16 16 16 16 | **0 0 0 0 0** | 69613 69611 69569 69528 69486 · 69486 69528 69569 69611 69653 |
| Magicians S1E1 (H.264) | 69 **5** 76 79 75 · 75 79 76 **5** 69 | **0 0 0 0 0** | 69190 69171 69138 69105 69071 · 69105 69138 69171 69205 69238 (33/34 ms grid) |

- **One picture per click on all four films.** Full matrices are in the analysis file.
- **The app's positions are VLC's interpolated clock read 400 ms after each click,** so a few readings under-state the first step: Wonder Woman −12 ms, Divergent −2 / +0 ms, Magicians −19 ms. The pixels are the proof.
- **Magicians clicks 1→2 differ by only 5.** That is two distinct but nearly identical pictures (not 0), consistent with a repeated frame in this 29.97 fps episode. Least-sure 4.

## 4. Step 5 — while playing: drags do nothing; skips

`ctl2d.py` on each control session: play 30 s, scripted drag forward, scripted drag back, then Right (+30 s) and Left (−10 s).

| Film | Drag forward while playing | Drag back while playing | +30 s | −10 s |
|---|---|---|---|---|
| Stargate | `[scrub] drag while playing: no action`; no scrub, no pause | same | 44 000 → 74 000 | 76 726 → 66 726 |
| Wonder Woman | same | same | 44 675 → 74 675 | 76 936 → 66 936 |
| Divergent | same | same | 45 000 → 75 000 | 77 008 → 67 008 |
| Magicians S1E1 | same | same | 44 457 → 74 457 | 76 443 → 66 443 |

Screenshots `p2d-divergent-control-01-playing-drag-fwd-mid.jpg` / `-02-…-after.jpg`: the picture only, no bar, still playing.

These drags go through the model (`scrubBegan`), so they prove the model refuses them. That the pan itself refuses to begin while playing (`gestureRecognizerShouldBegin`) is by code, and is in your hand test (§6).

## 5. The failed first Divergent run, and the re-run

**What failed.** The first Divergent scrub session failed its test case after 2 of its 6 scrubs.
- **Scrubs 1 and 2 landed −17 and +9 ms from the target.**
- **The lost press.** XCTest logged `t = 159.73s Pressing Play/Pause button` at 09:38:40.87 (the harness's pause before scrub 3), but the app logged no Play/Pause line.
- **The trace confirms it:** video kept rendering straight through, about 70 pictures per 3 s with advancing PTS, and the first pause came 9.03 s later from the harness's next click.
- **What followed was the harness running inverted.** Its drag was correctly refused (`[scrub] drag while playing: no action`), its "land" click paused, and each later Play/Pause flipped play and pause. A Menu then exited the player, and the final check timed out (`Failed to get matching snapshots: Timed out while evaluating UI query`).
- **Cause unknown.** Every Play/Pause press goes `pressesBegan` → `handle(.playPause)` → a logged `togglePlayPause`; this pass changed nothing on that path except clearing a pending drag. The same pause, 33 s after a landing, arrived a minute earlier in that run, and your remote log shows every Play/Pause handled.

**Separately:** 14 pictures were dropped at +29.63 s after scrub 2's click, within 25 ms, 3 s before the lost press.

**What I did.** I asked; you chose to re-run Divergent once and stop if a press was lost again. The re-run and the three remaining runs were clean (press counts in the analysis file). Log: `reports/logs/2d-divergent-scrub1-lost-press.log.gz`.

## 6. What you must test by hand (step 6)

XCUIRemote on tvOS sends presses only (Up/Down/Left/Right, Select, Menu, Play/Pause, Home, Page Up/Down…); it cannot touch the Siri Remote's surface. So the pan recognizer, its start only while paused, its running alongside the swipes, and the translation width a real thumb produces were **not exercised on the device**.

Home Theater runs the committed build. With any film:
1. **Pause.** Play, then press **Play/Pause**. The overlay shows Paused.
2. **Quick flick while paused.** A quick flick right on the touch surface: the scrub bar appears and the target and times move forward; **the picture stays still**. A quick flick left moves the target back.
3. **Slow drag while paused.** A slow drag right, then left: the target follows your thumb (one full width ≈ a quarter of the running time). Lift your thumb: the bar stays, and the picture is still.
4. **Land with Play/Pause.** It plays from the target.
5. **Land with a click.** Pause again, flick, then **click the centre of the touch surface**: it plays from the target.
6. **Cancel with Menu.** Pause, flick, press **Menu**: the bar goes, the film **stays paused** on the same picture, and the clock is as before the flick.
7. **Frame step while paused, no bar up.** **Click the left edge** five times, then **the right edge** five times: one frame per click, and **no bar appears**. Also try clicking while your thumb is resting on or slightly moving across the surface.
8. **While playing.** A **quick flick right / left** skips **+30 s / −10 s** (skip pill), with no bar and no pause. A **slow drag** does nothing: no bar, keeps playing. **Clicks** on the edges skip the same way.
9. **Vertical swipe while paused.** A swipe up still reaches Audio / Subtitles, with no scrub.

Then tell me before you relaunch the app: I'll copy the log off Home Theater (as in step 1) and check each gesture against it. Also say whether 25% per width feels right.

## 7. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1 | `reports/logs/2d-owner-remote-session.log.gz` (your session, redacted) | Committed |
| 2, 3 | `Marlin Media TV/PlayerHost.swift` (no `require(toFail:)`; simultaneous recognition; pan begins only while paused, logs a drag while playing), `Marlin Media TV/PlayerModel.swift` (no scrub while playing; scrub appears once the target moves; a press ends an unmoved drag; `Scrub` without `wasPlaying`; Menu stays paused; header comment). The diff is `reports/logs/2d-scrub-app.diff` (52+/32−). | **Committed** |
| 4 | `DECISIONS.md`: D021 (revised) under "2026-09-15 — pass 2d"; the pass 2c interaction marked superseded | **Committed** |
| 5 | `reports/logs/2d-analysis.txt`; `2d-{stargate,ww,magicians}-scrub.log.gz`, `2d-divergent-scrub2.log.gz`, `2d-{stargate,ww,divergent,magicians}-control.log.gz`, `2d-divergent-scrub1-lost-press.log.gz`; `2d-harness-app.diff`, `2d-harness-Diag2dUITests.swift.txt`; `reports/screenshots/2d/` (8) | Committed |
| 8 | `COLD-START.md` (pass 2d note), this report | Committed |
| 5 | The Page Up/Down hook in `PlayerHost.swift` and `Marlin Media TVUITests/Diag2dUITests.swift` | **Not committed.** Removed after the runs; copies in the reports above. Traces, raw screenshots and scripts stay in scratch. |

- **The committed code:** the tree's diff equals `2d-scrub-app.diff` (shasum `f5e0804f…`), with no harness line. Rebuilt (`** BUILD SUCCEEDED **`) and installed on Home Theater.
- **Not touched:** `tools/vlckit-truehd/` (0007, 0018, 0019, 0020), `Frameworks/VLCKit.xcframework`, libvlc, Design/, Marlin DVR TV. `PlayerScreen.swift` is unchanged this pass.
- **Constraints kept:**
  - `TVOS_DEPLOYMENT_TARGET = 26.0` (both configurations);
  - Home Theater only, no simulator;
  - largest committed file 73 KB (the analysis file 65 KB);
  - logs redacted (0 UUID/UDID patterns; the one VLC `configured with` line naming the Mac's build path is kept, as in passes 1k–2c);
  - run names non-empty.
- **Pushed:** nothing.

## 8. Open questions

1. **Arrow clicks while a scrub is up are ignored** (logged). Should a left/right click then cancel the scrub and step, nudge the target, or stay ignored?
2. **The lost Play/Pause press** in the first Divergent run (§5) is unexplained. Watch for a press that does nothing during your hand test; the log will show it.
3. **Reads while paused after a landing** (up to ~36 s of stream in memory): look into it, or accept? (Carried from pass 2c.)
4. **Divergent's slowest landing, 0.94 s,** when the target is far past a keyframe, with one old-position picture first: acceptable?

## 9. Least-sure items

1. **The recognizer on the real remote.** Does the pan begin before a quick flick ends? Does simultaneous recognition keep the swipe skips working while playing? What does a thumb's travel map to? None of this is tested on the device (§6).
2. **A click with thumb jitter while paused.** The scrub appears as soon as the target moves by any amount, and 1 point of travel on a 2 h film is ~0.9 s of target. So a click with visible thumb movement could still raise a bar, and while the bar is up the arrow click is ignored (question 1). The scripted runs can't show how often a real click moves the thumb.
3. **The lost press's cause** (§5).
4. **Magicians clicks 1→2** differ by 5, not 0 and not ~70. Two distinct pictures by the app's positions (69 205 → 69 171 ms), but "a repeated frame in the episode" is an inference.
5. **One run per case, at one scripted drag pace.** Audio at landing isn't measured (as passes 1k–2c).
