# Pass 2e — paused-seek scrub diagnosis (why the picture can't follow the thumb) — diagnosis only — 2026-09-15

**Result.**
- **The cause is one mechanism, the same on Magicians S1E1 (MP4, no subtitle track) and Stargate Extended (MKV, subtitle track).**
  - When a seek's rebuffer ends while VLC is paused, es_out anchors the input clock at the **pause date**, not at now (`es_out.c:1219`).
  - The next PCR is then late by about *(time since the pause − pts_delay)* (`input_clock.c:318–319`).
  - Its late branch (`es_out.c:3661–3721`) issues `ES_OUT_RESET_PCR`, which flushes the decoders and rebuffers **without moving the demuxer**. So the target's data is thrown away and the demuxer carries on from where it is.
  - Every lap repeats this. Once pts_delay stops growing (the jitter cap, `clock-jitter` 5000 ms), the lateness grows with wall time and the laps run until Play.
- **Numbers on Home Theater (instrumented libvlc), Play-only landings:**
  - Magicians: a target of 238 890 ms played from **452 488 ms**.
  - Stargate: a target of 333 004 ms played from **666 549 ms**.
  - Fresh launch, Magicians, a **single** seek on lift: a target of 238 874 ms played from **334 370 ms**.
  - These are far worse than pass 2a's 27.7 s, because the pauses ran 3–30 s where pass 2a's ran ~2 s.
- **It does not depend on how often the drag seeks.** One seek laps as badly as nine (§3, §6).
- **The need-data flag:**
  - **Magicians (no subtitle track):** not involved. The flag is raised and cleared only by the video decoder, and the pause gate never let the demuxer read on the flag alone (0 times).
  - **Stargate:** the subtitle decoder's request does open the gate after a rebuffer (300–813 times per scrub). That adds reads while paused, but it is not what makes the laps (§3.3).
- **Fix candidates in §5.** One contained change is clearly indicated: **C1**, `es_out.c:3661`, which skips the late compensation while es_out is paused. **Nothing implemented.**
- **Without a libvlc change the picture cannot follow the thumb** (§6):
  - Laps happen on any paused seek taken more than pts_delay after the pause (1 s at first, up to ~6 s later in a session), however often the drag seeks.
  - At one seek per 250 ms most seeks show no picture anyway.
  - During the hold the picture drifts forward past the target while the bar shows the target.
  - HEAD's landing (play, then one seek) still lands right after laps.
- **Restored.**
  - **libvlc:** clean, and `Frameworks/VLCKit.xcframework` rebuilt with the full recipe (§7).
  - **App:** at HEAD, built and installed on Home Theater (§8).
  - **Commits:** the report and evidence are committed locally. Nothing pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Picture follows the thumb, temporary | **Done, uncommitted, reverted in step 8.** On HEAD `70fd94a`: pass 2a's paused seeks during a scrub drag (one per 250 ms and one on lift). Play/Pause lands as pass 2a did (the paused seek already went to the target, so only `play()`). A click lands as HEAD does (`play()`, then one seek). Page Up/Down harness hook (Page Down = the same drag seeking on lift only). Diff: `reports/logs/2e-app-diag.diff`. |
| 2 Instrument, scripted drags, land, full trace | **Done.** 95 log lines in 5 files (`reports/logs/2e-libvlc-instrumentation.diff`). Three traced sessions on Home Theater: Magicians (4 scrubs), Stargate (4 scrubs), a fresh Magicians launch (2 scrubs). |
| 3 Answers with quoted lines | §3 |
| 4 What it settles from 2a / 2c | §4 |
| 5 Fix candidates | §5. C1 named; none implemented. |
| 6 Without a libvlc change? | §6: **no**, not reliably. |
| 7 libvlc clean, full recipe, checks | §7 |
| 8 App at HEAD on Home Theater | §8 |
| 9 This report | Done. |

## 1. Method

- **Instrumentation.** Log-only lines, all with `vlc_tick_now()`:
  - Pass 1g's clock/pause lines, pass 1h's pause-gate and need-data lines, pass 1j's es_out lines.
  - New `2e:` lines:
    - `input_clock_Update`'s late computation (stream, system, reference, pts_delay, expected, late) while paused or late;
    - every PCR es_out sees while paused;
    - the late branch's decision (`late_reset`: late, total delay, jitter, cap, time since pause);
    - `stop_buffering`'s components;
    - the decoders' need-data notifies **with the ES category** (pass 1h's least-sure 1);
    - es_out's forward/drop of each request (0020's check);
    - the paused flush's countdown;
    - the first picture and each picture put while paused;
    - `SET_TIME`'s result.
- **Build.** Pass 1h's method:
  - Only the device slice's `src/` recompiled (6 compile lines), `libvlc-full-static.a` relinked from `static-libs-list`, then `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh`.
  - Framework strings: `2e:` 11, `1g:` 14, `1h:` 6; `_ff_truehd_decoder` present.
- **App.** HEAD + the step-1 diff + the hook + `Diag2eUITests` (`reports/logs/2e-harness-Diag2eUITests.swift.txt`). `** TEST BUILD SUCCEEDED **`, `App installed`. Deployment target 26.0 untouched.
- **Sessions.** Pass 2d's attach-mode runner: console launch with VLCKit's tvOS defaults and the JSON tracer into the container. Each session plays 30 s, skips 4 × +30 s, plays 20 s, then runs its scrubs:

  | Session | Scrub | Pause before the drag | Drag seeks | Landing |
  |---|---|---|---|---|
  | `magicians-scrub`, `stargate-scrub` | 1 | 3 s | during the drag (pass 2a) | Play/Pause: play only (pass 2a's landing) |
  | | 2 | 3 s | during the drag | click: play, then seek (HEAD's landing) |
  | | 3 | 20 s | during the drag | Play/Pause |
  | | 4 | 3 s | on lift only | Play/Pause |
  | `magicians-fresh` (a second launch; added after scrub 4 turned out to be affected by scrub 1's raised pts_delay) | 1 | 3 s | on lift only | Play/Pause |
  | | 2 | 20 s | during the drag | click |

  - **The drag** is pass 2a's shape: 2 s, +0.08 of the width, nine throttled seeks plus the lift seek. Landing is at drag +9 s, followed by 30 s of playback.
  - **The difference from pass 2a.** HEAD's flow (D021) takes a scrub only while paused, so each drag starts 3 s or 20 s after a Play/Pause. Pass 2a's drag paused and seeked 17 ms later.
  - **Outcome.** All three test cases passed: `tMagiciansScrub` 296.6 s, `tStargateScrub` 289.7 s, `tMagiciansFresh` 201.5 s.
- **Analysis.** `diag2e.py` (per seek and landing), `laps2e.py` (laps, jitter cap, need-data traffic, gate), `follow2e.py` (pictures per seek from the trace), `filt2e.py` (key-line excerpts). All outputs and scripts are in `reports/logs/2e-analysis.txt`; the logs are in `reports/logs/2e-{magicians-scrub,stargate-scrub,magicians-fresh}.log.gz`.
- **Clock and line numbers.** `[scrub] tick=` and VLC's `now=` are the same CLOCK_MONOTONIC µs; ES category 1 = video, 3 = subtitles. Line numbers below are libvlc `9279ed3615` (the recipe tree, uninstrumented) unless a quote is from a log.

## 2. The runs

| Session / scrub | Pause → first seek | Seeks | Target | First picture after landing (trace pts) | VLCKit time at +3 s | Late resets (at the jitter cap) |
|---|---|---|---|---|---|---|
| magicians-scrub 1 | 3.28 s | 9, Play/Pause | 238 890 | **452 488** | **454 119** | 39 (33) |
| magicians-scrub 2 | 3.27 s | 9, click (play → seek) | 544 424 | 544 413 | 546 653 | 0 |
| magicians-scrub 3 | 20.27 s | 10, Play/Pause | 636 996 | **836 205** | **837 874** | 34 (34) |
| magicians-scrub 4 | 5.32 s | lift only, Play/Pause | 928 180 | 928 163 | 930 934 | 0 — pts_delay already 5.96 s (§3.1) |
| stargate-scrub 1 | 3.27 s | 10, Play/Pause | 333 004 | **666 549** | **668 726** | 65 (51) |
| stargate-scrub 2 | 3.27 s | 9, click | 852 348 | 852 318 | 854 778 | 0 |
| stargate-scrub 3 | 20.27 s | 10, Play/Pause | 1 038 371 | **1 362 695** | **1 365 341** | 58 (58) |
| stargate-scrub 4 | 5.32 s | lift only, Play/Pause | 1 548 974 | 1 548 964 | 1 551 977 | 0 — pts_delay already raised |
| **magicians-fresh 1** | 5.31 s | **one, on lift**, Play/Pause | 238 874 | **334 370** | **335 951** | 18 (13) |
| **magicians-fresh 2** | 20.27 s | 10, **click** | 426 278 | 426 262 | 428 716 | 15 (15) |

Times in ms. "Pause → first seek" is the seek's tick minus es_out's pause date.

Screenshots in `reports/screenshots/2e/` (960 wide):
- `p2e-magicians-scrub-01-…-b-lifted.jpg`: bar at **03:59**, a close-up of the actor.
- `…-c-before-land.jpg`: the bar still at 03:59, but the picture is a different scene (the tree): **the picture has moved on during the hold while the bar shows the target.**
- `…-d-after+3s.jpg`: after landing.
- The same set for Stargate. Fresh session 1: lifted and after+3 s. Fresh session 2: before-land and after+3 s.
- Lift-only landings: `…-04-liftonly-playpause-d-after+3s.jpg` for both films.

## 3. Step 3 — the answers

### 3.1 What triggers the repeated "PCR is called late" → `ES_OUT_RESET_PCR` during a paused drag

**The anchor at the pause date.** When a rebuffer ends while es_out is paused, `EsOutDecodersStopBuffering` anchors the input clock at `i_pause_date`:
```
es_out.c:1219   const vlc_tick_t i_current_date = p_sys->b_paused ? p_sys->i_pause_date : vlc_tick_now();
es_out.c:1221   const vlc_tick_t update = i_current_date - i_buffering_duration;
                … input_clock_ChangeSystemOrigin( p_sys->p_pgrm->p_input_clock, update );
input_clock.c:318  i_system_expected = ClockStreamToSystem( cl, i_ck_stream + AvgGet( &cl->drift ) );
input_clock.c:319  i_late = (i_ck_system - cl->i_pts_delay ) - i_system_expected;
```
So the next PCR's "expected" system time lies around the pause date, and it is late by about *(now − pause date) − pts_delay*.

**Fresh launch, Magicians, first seek, 3.4 s after the pause, pts_delay 1 s** (`2e-analysis.txt`, "magicians scrub 1, first seek"):
```
11:30:46.909 AM [scrub] seek 176840 ms tick=527605353465
[DBG] Stream buffering done (1723 ms in 90 ms)
[DBG] 1g: es_out stop_buffering now=527605494465 paused=1 pause_date=527602077426 current_date=527602077426 buffering_duration=1716643 update=527600360783 stream_start=176123357
[WARN] 2e: input_clock update stream=177864876 system=527605494976 ref.stream=176123357 ref.system=527600360783 drift=0 pts_delay=1000000 expected=527602102302 late=2392674 buffering=0 reset_ref=0 paused=1
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 2392 ms late (pts_delay increased to 1000 ms)
[DBG] 2e: late_reset pcr=177864876 late=2392674 total_delay=1000000 new_jitter=0 pts_delay=1000000 old_jitter=0 jitter_max=5000000 paused=1 now-pause_date=3417798
[DBG] ES_OUT_RESET_PCR called
```
`current_date` equals the pause date. `expected` (527602102302) sits 25 ms after the pause date, while `now` is 3.42 s after it. Late = 3 418 − 1 000 − 25 ≈ **2 393 ms**.

**Stargate, first seek, the same numbers** (`2e-analysis.txt`, "stargate scrub 1, first seek"):
```
[DBG] 1g: es_out stop_buffering now=527964583723 paused=1 pause_date=527961198370 current_date=527961198370 buffering_duration=1064001 update=527960134369 stream_start=178278000
[WARN] 2e: input_clock update stream=179379367 system=527964584368 … pts_delay=1000000 expected=527961235736 late=2348632 buffering=0 reset_ref=0 paused=1
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 2348 ms late (pts_delay increased to 1000 ms)
```

**Why it repeats.** The late branch raises the jitter, resets and rebuffers (`es_out.c:3688–3727`). The rebuffer ends paused, so the clock is anchored at the pause date again, and the next PCR is late again. Pts_delay climbs lap by lap. Once the jitter reaches `clock-jitter` (5000 ms), it stops climbing (`jitter of … ignored`) while the wall-clock distance from the pause keeps growing. From there every lap is late. Magicians scrub 1, after the lift seek:
```
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 2375 ms late (pts_delay increased to 5042 ms)
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 921 ms late (pts_delay increased to 5810 ms)
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 324 ms late (pts_delay increased to 5963 ms)
[ERR] ES_OUT_SET_(GROUP_)PCR  is called 424 ms late (jitter of 5135 ms ignored)
…
[DBG] 2e: late_reset pcr=451488799 late=7257610 total_delay=12990902 new_jitter=4963779 pts_delay=1000000 old_jitter=4963779 jitter_max=5000000 paused=1 now-pause_date=13232268
```
Per scrub (`laps2e.py`): Magicians 1: 39 late resets, 33 at the cap. Magicians 3: 34, all at the cap. Stargate 1: 65 (51). Stargate 3: 58 (58). Fresh 1: 18 (13). Fresh 2: 15 (15).

**When it doesn't happen.** The input clock keeps the pts_delay the laps raised; `input_clock_SetJitter` only ever raises it (`input_clock.c:488`). In the first session that value was 5.96 s after scrub 1. Scrubs 2 and 4 seeked 3.3 s and 5.3 s after their pauses, so they were not late:
```
[DBG] 1g: es_out stop_buffering now=527759258670 paused=1 pause_date=527753451963 current_date=527753451963 buffering_duration=7249629 update=527746202334 stream_start=926894150
[WARN] 2e: input_clock update stream=934185216 system=527759258981 … pts_delay=5963779 expected=527753493400 late=-198198 buffering=0 reset_ref=0 paused=1
[DBG] 1h: check1 now=527759259209 state=PAUSE_S es_out_GetBuffering=0 b_eof=0 next_frame_need_data=0 -> demux_allowed=0
```
In the fresh launch the same lift-only scrub, 5.31 s after its pause with pts_delay still 1 s, lapped 18 times:
```
[DBG] 2e: late_reset pcr=239885352 late=4410937 total_delay=1000000 new_jitter=0 pts_delay=1000000 old_jitter=0 jitter_max=5000000 paused=1 now-pause_date=5422408
```
So the condition is *time since the pause > the input clock's pts_delay* (1 s at the start of a launch, ~6 s at most after the cap). Seek count and drag pace don't enter it.

**Where the anchor comes from.** `git log -L1219,1219:src/input/es_out.c` ends at `5708e0cd1c 2008-11-25 Laurent Aimar — Fixed seeking while paused (visible with high caching)`. That commit replaced `mdate()` with `p_sys->b_paused ? p_sys->i_pause_date : mdate()`. The reason: on resume `input_clock_ChangePause` (`input_clock.c:367–383`) shifts the reference by *resume − pause date*, so an anchor at the pause date plays correctly after Play. The late check in `input_clock_Update` doesn't know the clock is paused.

### 3.2 What keeps the demuxer reading after each seek

Two things, one after the other.

**(a) The rebuffer itself.** `ES_OUT_RESET_PCR` → `EsOutChangePosition` sets `b_buffering = true` (`es_out.c:1120`). The pause gate lets the demuxer run while buffering (`input.c:666–667`: `b_paused = !es_out_GetBuffering(…) || b_eof`), and `EsOutGetWakeup` returns 0 while buffering (`es_out.c:815`), so it reads flat out. On Magicians that is **every** paused read the gate allowed:
```
magicians-scrub scrub 1: gate (buffering, need_data, allowed) {('1','1','1'): 245, ('1','0','1'): 755, ('0','0','0'): 1} | allowed by need_data alone: 0
magicians-fresh scrub 1: gate {('1','1','1'): 93, ('1','0','1'): 311, ('0','0','0'): 1} | allowed by need_data alone: 0
```

**(b) The late PCR arrives in the same demux pass that ended the rebuffer**, before the gate is checked again. The buffering end and the late PCR are consecutive log lines, with no `check1` between them:
```
10599: [DBG] Stream buffering done (4154 ms in 374 ms)
10601: [DBG] 1g: es_out stop_buffering now=527607909231 paused=1 pause_date=527602077426 current_date=527602077426 buffering_duration=4134660 update=527597942766 stream_start=238190295
10606: [WARN] 1g: set_first_pcr now=527607909468 system=527597942766 ts=238190295 paused=1 pause_date=0
10607: [WARN] 2e: input_clock update stream=242346667 system=527607909752 … pts_delay=3434955 expected=527602099138 late=2375659 buffering=0 reset_ref=0 paused=1
10609: [ERR] ES_OUT_SET_(GROUP_)PCR  is called 2375 ms late (pts_delay increased to 5042 ms)
10611: [DBG] ES_OUT_RESET_PCR called
10613: [DBG] 1g: es_out change_position now=527608070588 paused=1 pause_date=527602077426 buffering=0 next_frame_es=0
```
The reset flushes, but the demuxer isn't moved. The next lap starts at the demuxer's position, just after the late PCR (`pcr=242346667` → `stream_start=242378101`):
```
12060: [DBG] 1g: es_out stop_buffering now=527608070055 paused=1 pause_date=527602077426 current_date=527602077426 buffering_duration=5042536 update=527597034890 stream_start=242378101
```
The demuxer is sought only by `INPUT_CONTROL_SET_TIME` (`input.c:2129` → `ControlSetTime`), and only the app's seeks issue that (`2e: SET_TIME val=… ret=0`). The late reset sends no control to the input. After Magicians scrub 1's lift seek the demuxer read PCR **230.3 → 457.5 s** in 8.1 s of hold (13 160 PCRs).

**How the laps end.**
- **By chance.** The laps stop when a rebuffer ends on the last PCR of a demux pass: no late PCR follows, and the closed gate stops the reading:
  ```
  57109: [DBG] Stream buffering done (5972 ms in 198 ms)
  57112: [DBG] 1g: es_out stop_buffering now=527615509557 paused=1 pause_date=527602077426 current_date=527602077426 buffering_duration=5963779 update=527596113647 stream_start=451520367
  57119: [DBG] 1h: check1 now=527615510058 state=PAUSE_S es_out_GetBuffering=0 b_eof=0 next_frame_need_data=0 -> demux_allowed=0
  ```
  Magicians 1 ended this way 0.83 s before landing, fresh 1 at 5.0 s, fresh 2 at 5.3 s.
- **At Play.** Stargate 1 was still lapping 14 ms before Play (§3.4).

### 3.3 Is the need-data flag involved on a film with no subtitle track?

**Magicians (no subtitle track): no.**
- **Only the video decoder sets it.** The video decoder's paused flush sets `frames_countdown = 1` (`decoder.c:2789–2793`), and it asks for data while its fifo is empty. Every notify in the session is category 1, and es_out forwards them all, since 0020 filters only while frame stepping:
  ```
  [DBG] 2e: paused flush cat=1 frames_countdown=1 now=527758778496
  [DBG] 2e: decoder notify need_data=1 cat=1 frames_countdown=1 now=527758779645
  [DBG] 2e: need_data from cat=1 need_data=1 next_frame_es=0 -> forwarded now=527758779839
  magicians-scrub scrub 1: decoder notify (value, cat) {('1','1'): 2205, ('0','1'): 1056} | es_out (cat, result) {('1','forwarded'): 3261}
  ```
- **It clears itself.** The decoder clears the flag as soon as a block lands in its empty fifo (`decoder.c:2686–2687`): 1 056 clears against 2 205 requests in scrub 1, flag `'1 -> 0': 728`.
- **It licensed no read.** The gate never let the demuxer read on the flag alone (`allowed by need_data alone: 0`, §3.2a). Every paused read on Magicians was licensed by `es_out_GetBuffering`, and every lap by a late PCR from the demux pass that ended a rebuffer.

**Stargate (subtitle track `spu`): involved, but it doesn't make the laps.**
- **The subtitle decoder opens the gate.** Its paused flush also gets `frames_countdown = 1` (`2e: paused flush cat=3 frames_countdown=1`). Its request (category 3) is forwarded, and it keeps the gate open after a rebuffer ends:
  ```
  stargate-scrub scrub 1: decoder notify (value, cat) {('1','1'): 1059, ('1','3'): 10610, ('0','1'): 697, ('0','3'): 64} | allowed by need_data alone: 300
  2263: [DBG] 1h: check1 now=527964584105 state=PAUSE_S es_out_GetBuffering=0 b_eof=0 next_frame_need_data=1 -> demux_allowed=1
  2275: [WARN] 2e: input_clock update stream=179379367 … late=2348632 buffering=0 reset_ref=0 paused=1
  ```
- **With no laps (scrub 4) it still reads while paused**, paced by the same pause-date anchor (its wakeup lies in the past):
  ```
  304939: [DBG] 2e: decoder notify need_data=1 cat=3 frames_countdown=1 now=528117024677
  304940: [DBG] 2e: need_data from cat=3 need_data=1 next_frame_es=0 -> forwarded now=528117024702
  304941: [DBG] 1h: demuxed-while-paused now=528117024758 wakeup=528111350153 wakeup-now=-5674605
  304946: [DBG] 1h: check1 now=528117024864 state=PAUSE_S es_out_GetBuffering=0 b_eof=0 next_frame_need_data=1 -> demux_allowed=1
  PCR reads after buffering done until land: 329 first (528117024957, 1554853001) last (528125124622, 1568768001)
  ```
  That is 20 s of stream past the target in 8.1 s. The landing still started at the target (1 548 964), because nothing was flushed.
- **Not the laps' cause.** Magicians laps the same way with no subtitle decoder. On Stargate the flag only changes which reads carry the late PCR.

### 3.4 Why the landing then plays from the end of the read-ahead instead of the target

- **Pass 2a's landing issued no seek.** Its last seek was the lift seek, and the landing only called `play()`:
  ```
  7:22:44.390 AM [scrub] seek 238564 ms tick=512722931150
  7:22:51.501 AM [scrub] land from 175993 ms at 238564 ms tick=512730042223
  ```
  (`reports/logs/2a-magicians-playfwd.log.gz`, the only two `[scrub] seek|land` lines after the lift.) This pass's Play/Pause landings reproduce exactly that.
- **Each lap throws the target away.** Every lap flushes the decoders, and the demuxer is never sent back (§3.2b), so the target's data is gone after the first lap. What is queued at Play is whatever the **last** lap read: its first picture (put while paused) and the blocks after it.
- **Magicians 1: Play resumes where the last lap left off.** The laps had ended. The last lap's first picture was on screen, and Play resumed from it with no re-anchoring of position:
  ```
  56403: [DBG] 2e: first picture pts=452488000 output_paused=1 frames_countdown=1 now=527615344012
  57112: [DBG] 1g: es_out stop_buffering … stream_start=451520367
  57121: 11:30:57.694 AM [scrub] land playPause from 176319 ms at 238890 ms tick=527616138423
  57123: [DBG] 1g: es_out change_pause paused=0 date=527616139801 now=527616140029 was_paused=1 old_pause_date=527602077426 buffering=0 extra_initial=0
  57125: [WARN] 1g: main_change_pause resume: pause_date INVALID, no delay applied
  57403: 11:31:00.719 AM [scrub] land +3 s time=454119 ms (expected 238890 ms) state Playing
  trace: first realtime render +0.007 s pts 452488000
  ```
- **Stargate 1: Play arrived during a lap.** The rebuffer finished after Play, so its anchor is taken at now, at the read-ahead position:
  ```
  142404: 11:36:56.510 AM [scrub] land playPause from 177043 ms at 333004 ms tick=527974954725
  142412: [DBG] 1g: es_out change_pause paused=0 date=527974955725 now=527974955784 was_paused=1 old_pause_date=527961198370 buffering=1 extra_initial=0
  142491: [DBG] Stream buffering done (5873 ms in -13635 ms)
  142494: [DBG] 1g: es_out stop_buffering now=527975065389 paused=0 pause_date=527974955725 current_date=527975065387 buffering_duration=5867438 update=527969197949 stream_start=666132001
  ```
- **During the hold the screen shows each lap's first picture.** The trace's renders from the lift seek to landing run `pts first 238874601 last 452488000` on Magicians 1, and the screenshot pair in §2 shows it. The picture doesn't stay on the target before landing either.
- **A seek after Play does land on the target, even after laps.** Fresh Magicians 2, with 15 laps, landed by click. The input thread handles the seek, then the resume, and the rebuffer ends playing, anchored at now:
  ```
  [scrub] seek 426278 ms after play tick=528430331526
  [DBG] 2e: SET_TIME val=426278000 fast=0 ret=0 state=3 now=528430341138
  [DBG] 1g: es_out change_pause paused=0 date=528430341307 now=528430341579 was_paused=1 old_pause_date=528399305162 buffering=1 extra_initial=0
  [DBG] 2e: first picture pts=426261801 output_paused=0 frames_countdown=0 now=528430493929
  [DBG] 1g: es_out stop_buffering now=528430622056 paused=0 pause_date=528430341307 current_date=528430622051 buffering_duration=7690691 update=528422931360 stream_start=424391112
  [scrub] land +3 s time=428716 ms (expected 426278 ms) state Playing
  ```

## 4. Step 4 — what this settles from passes 2a and 2c

**Settled, from pass 2a:**
- **§2.3 "Which VLC condition licenses the laps."** It is the pause-date anchor (`es_out.c:1219`) meeting the input clock's late check (`input_clock.c:319`) and the late branch's reset without a seek (`es_out.c:3720–3721`). The reads come from the rebuffer (`es_out_GetBuffering`) and from the late PCR inside the same demux pass (§3.1, §3.2).
- **"Not ruled out: the video decoder's own paused-seek request."** Ruled out as the licence: on Magicians the gate never let the demuxer read on the flag alone (§3.3).
- **"Whether the laps depend on the drag… A single paused seek wasn't isolated."** Isolated. One lift-only seek on a fresh launch lapped 18 times and landed 95.5 s late (fresh 1). The laps depend on the time since the pause, not the number of seeks.
- **"The loop stops by itself" after 12 laps.** In pass 2a the drag seeked 17 ms after the pause, so the last seek came only 2.06 s after it, close enough for pts_delay to catch up before the cap. With 3 s and 20 s pauses the laps run 15–65 times, reaching the jitter cap. They end only when a rebuffer happens to end on a demux pass's last PCR (§3.2), or at Play.
- **"MKV films and a film with a subtitle track weren't run."** Stargate (MKV, subtitle track) laps the same way, and adds reads on the subtitle decoder's need-data request (§3.3).
- **Least-sure 4, "the scripted drag's pace may change how far VLC reads ahead."** Pace doesn't enter the condition (§3.1). The read-ahead length is set by how long the laps run.
- **Report wording.** Pass 2a's "landing plays from the read-ahead" had no landing seek; it was `play()` alone (§3.4). Pass 2b's question of whether fast seek would change the loop is answered in principle: the laps start after the seek's buffering ends, whatever the preroll.

**Settled, from pass 2c (D021's rationale and one least-sure item):**
- **"Rejected: seeking during the drag."** The rejection stands, with the cause now known.
- **Least-sure 2, "whether VLC processes the seek before or after it resumes."** The input handles `SET_TIME` first (`now=…341138`), then the resume (`change_pause paused=0 … now=…341579`). The rebuffer ends playing and is anchored at now (§3.4). The same order shows on Stargate scrub 2 (`SET_TIME … now=528019375795`, then `change_pause … now=528019375993`). This is why HEAD's landing is right even after paused laps.

**Not settled:**
- **Pass 2c §3 / D021's "a pause after a landing lets the demuxer read at 1× while paused, up to ~36 s", on films with no subtitle track.** Not measured. This pass instrumented seeks while paused, not plain pauses after landings. Stargate's subtitle request explains reads while paused on that film (§3.3); Wonder Woman, Divergent and Magicians were said to read the same way with no subtitle track, and this pass shows no cause for that.
- **Pass 2c's "one old-position picture before the target" in 3 of 32 landings.** Not examined.
- **Pass 2a's recognizer questions and the scrub feel values.** Out of scope; drags were scripted again.
- **Whether the laps behave the same on Wonder Woman and Divergent** (HEVC MKV, no subtitle track selected). Not run. The mechanism is in es_out and the input clock, not in a demuxer or codec, but that is by code, not by trace.

## 5. Step 5 — fix candidates (none implemented)

Line numbers are libvlc `9279ed3615`.

| # | Where (exact lines) | The change | What else reads the same code | Risk |
|---|---|---|---|---|
| **C1** | `src/input/es_out.c:3661`: `if (p_pgrm != p_sys->p_pgrm \|\| p_sys->p_next_frame_es != NULL)` → add `\|\| p_sys->b_paused`, ahead of `if (i_late <= 0)` (3665) and the late branch (3688–3727) | While es_out is paused, a PCR never goes through the late compensation, so no `ES_OUT_RESET_PCR` and no jitter rise. A paused seek rebuffers once, shows the target and stops, as scrub 4 did in the first session. Play resumes from the displayed target: the anchor at the pause date is shifted by `input_clock_ChangePause` on resume, which is the case 5708e0cd1c built it for. | This block is the only late compensation in VLC. `input_clock_Update` has one caller in the input (`es_out.c:3636`) plus its unit test (`src/clock/test/input_clock.c:66`), and `input_clock_GetJitter` has one reader (`es_out.c:3682`). The same line already exempts frame stepping (`p_next_frame_es`) for the same reason: no output runs. Every paused state is covered: user pause, paused seek, paused track, title or chapter change. | **Low–moderate.** (1) `input_clock_Update` still records the paused late values in `cl->late` (`input_clock.c:320–324`), and `input_clock_GetJitter` takes their median at the next late PCR after Play. A paused seek long after the pause could leave a large value that raises pts_delay once after resume; not traced. (2) Nothing stops the reads the subtitle need-data request licenses while paused (Stargate §3.3); those continue as today, without flushes. (3) A genuinely late network while paused isn't compensated until Play, when the normal check resumes. |
| C1b | `src/clock/input_clock.c:319–324`: while `cl->b_paused`, return a late of 0 and record nothing | Same effect as C1, and no paused late values enter the median. | `input_clock_Update` has the same one caller plus the clock unit test. `cl->b_paused` is set by `input_clock_ChangePause` (`input_clock.c:367–383`) from `EsOutProgramChangePause`. | Low–moderate. It lives in the clock module rather than es_out, and changes what `input_clock_Update` returns to every caller, including the unit test, which wasn't read for paused cases. It also relies on the input clock's pause flag matching es_out's: they are set together, but only by the order in `EsOutChangePause`. |
| C2 | `src/input/es_out.c:1219`: anchor a paused rebuffer at `vlc_tick_now()` | A PCR after a paused rebuffer is on time, so no laps. | The same anchor serves every paused rebuffer, and resume shifts it again by *resume − pause date* (`input_clock.c:372–377`). | **High.** It undoes 5708e0cd1c: after a paused seek taken *t* s after the pause, Play would hold the first picture ~*t* s. It needs a companion change to the pause date or `input_clock_ChangePause`, which is two points. |
| C3 | `src/input/es_out.c:3720–3721`: replace the late reset with a reset **and** a seek back to the last position | The laps would re-read from the target instead of running forward. | `ES_OUT_RESET_PCR` has 7 senders (`input.c:2105/2129/2212/2353/2397/3141`, `es_out.c:3721`). A seek from inside es_out would need a new es_out → input control. | High. It keeps the laps and the network reads, and only hides the drift. It is new cross-module state. |
| C4 | `src/input/input.c:666–669`: the pause gate | — | — | **Not a fix.** The laps are licensed by buffering, and on Magicians the late PCR comes inside the demux pass that ended the rebuffer (§3.2). |
| C5 | `src/input/decoder.c:2789–2793` / `es_out.c:539` (the subtitle request while paused) | Stop the subtitle decoder's paused-seek request from opening the gate. | This is D019's B2/B3/B1 area; B2 and B3 were rejected there. | Not the laps' cause (Magicians). It would only remove Stargate's extra paused reads, and would change subtitle display after a paused seek. Separate question. |

**The narrowest point: C1.**
- **Every lap starts in this block while paused.** Every `2e: late_reset` line in all three sessions carries `paused=1`: 229 late resets in 10 scrubs, none while playing.
- **The late value it acts on is an artefact of the paused anchor**, not a network delay (§3.1).
- **No output runs while paused**, so compensating lateness has nothing to protect.
- **VLC already skips this block for the other paused mode**, frame stepping, on the same line.
- **One condition, one file**, inside es_out, where 0020 already lives.

**Open before any patch.** The recorded late values (C1's risk 1) decide between C1 and C1b. That needs a C1 build on the device, a paused seek long after a pause, then Play, watching for a `pts_delay increased` line after resume.

## 6. Step 6 — can the picture follow the thumb without a libvlc change?

**No, not reliably. The trace ties the laps to the time since the pause, not to how often or how the drag seeks.**
- **Seeking less often doesn't help.** A single seek on lift lapped 18 times on a fresh launch and landed 95.5 s past its target (fresh 1). Nine seeks lapped the same way. The condition is *now − pause date > the input clock's pts_delay* (§3.1). That is 1 s at the start of a launch, and it can only grow to ~6 s, after a first scrub has lapped and raised it. After a pause of more than 1 s at launch, or more than ~6 s later, any paused seek laps.
- **Seeking more often doesn't make the picture follow.** At one seek per 250 ms, the picture reached the target before the next seek for only 1–2 of 8 drag seeks on Magicians, and 3–6 of 9 on Stargate (`follow2e.py`). The rest were cancelled by the next seek mid-rebuffer:
  ```
  magicians-scrub scrub 1:
    seek 176840 ms: window 253 ms, renders 3 … picture within 1 s of target: +139 ms after the seek
    seek 184140 ms: window 258 ms, renders 0 … none      (and the same for 191961, 199783, 207604, 215426, 223247)
    seek 238890 ms: window 8753 ms, renders 105, distinct pts [238874, 244280, 248284, 253956]…[445814, 452488]
  ```
  The MP4 preroll decodes from the previous sync sample (`seeking with 649ms preroll`, `1251ms preroll`), which doesn't fit in 250 ms. After lift the picture sits on the target only until the first lap, then moves forward (§3.4).
- **HEAD's landing fixes the landing, not the picture.**
  - Fresh 2 and the two scrub-2 click landings played from the target: first picture −16…−30 ms from it, +3 s within 2.4 s of it (§2).
  - But during the hold the screen showed each lap's picture, 426 → 514 s on fresh 2, while the bar showed 07:06.
  - And the demuxer read ~100 s of stream over HTTP per scrub.
- **Re-pausing right before each seek is untested.** `play()` then `pause()` would set a new pause date, so by the trace the seek would not be late. But it resumes audio and video for that moment. `ControlPause` defers a pause that arrives while buffering (`input.c:1759`, `b_pause_after_buffering`). None of it was built or traced. It is a guess from §3.1, not a finding.
- **`--clock-jitter` is untested.** A larger value raises the cap, but the lateness still grows with the pause, and the raised pts_delay then carries into playback.

## 7. Step 7 — libvlc clean, full recipe, framework checks

- **Clean libvlc.** The final instrumentation was compared with the saved diff (`saved diff matches the tree`), then the five files were reset with `git checkout`: `libvlc status after checkout: '' HEAD 9279ed3615`.
- **Full recipe.** `tools/vlckit-truehd/build.sh` with no `PACKAGE_ONLY`, 11:44:05–11:47:19, exit 0.
  - **Output:** `patch 0020 installed`, `VLCKit.xcodeproj TVOS_DEPLOYMENT_TARGET = 26.0 (4 build configurations)`, `** ARCHIVE SUCCEEDED **` ×2, `done: …/Frameworks/VLCKit.xcframework`.
  - **20 `Applying:` lines**, the last three:
    - `avcodec audio: coalesce TrueHD/MLP decoder frames into ~20 ms blocks`
    - `videotoolbox: dpb: do not bump ahead of the arriving picture on latency alone`
    - `input: es_out: forward next-frame data requests only from the stepped ES`
  - **Rebuilt libs:** the three `libvlc-full-static.a` were rewritten at 11:45 / 11:46 / 11:45. `build.log` has no `error:` line.
- **libvlc after the recipe.** HEAD `017a5fabe2` (the recipe's `git am` rewrites hashes), status clean. Tree `9d30b7229e`, the same as `9279ed3615`'s tree `9d30b7229e`.

**Checks on `Frameworks/VLCKit.xcframework`:**

| Slice | `MinimumOSVersion` | `LC_BUILD_VERSION` | `DTXcodeBuild` | `1g:` / `1h:` / `1j:` / `2e:` strings |
|---|---|---|---|---|
| `tvos-arm64` | 26.0 | `platform TVOS minos 26.0 sdk 27.0` | 27A266a | 0 / 0 / 0 / 0 |
| `tvos-arm64_x86_64-simulator` | 26.0 | `platform TVOSSIMULATOR minos 26.0 sdk 27.0` (x86_64 and arm64) | 27A266a | 0 / 0 / 0 / 0 |

- **Device slice `nm`:** `000000000236e730 S _ff_truehd_decoder`, `_ff_mlp_decoder`, `_ff_mlp_parser`.
- **Identical to the build output:** `diff -rq ~/vlckit-build/VLCKit/build/tvOS/VLCKit.xcframework Frameworks/VLCKit.xcframework` finds no differences. The binary is dated 11:47, 725 MB, git-ignored.
- **`tools/vlckit-truehd/`:** `git status --short tools` is empty.

## 8. Step 8 — the app at HEAD on Home Theater

- **Revert.**
  - `git checkout -- "Marlin Media TV/PlayerModel.swift" "Marlin Media TV/PlayerHost.swift"`, and `Marlin Media TVUITests/Diag2eUITests.swift` deleted.
  - `git diff --quiet HEAD -- "Marlin Media TV" "Marlin Media TVUITests" "Marlin Media TV.xcodeproj"` → `sources at HEAD 70fd94a`.
  - Neither player file contains `scrubSeekInterval` or `scriptedDrag`.
- **Build.**
  - `TVOS_DEPLOYMENT_TARGET = 26.0` (2 configurations).
  - `xcodebuild build … -destination 'platform=tvOS,name=Home Theater'` → `** BUILD SUCCEEDED **`, against the step-7 framework.
  - The embedded framework has `1g:` 0 and `2e:` 0 strings.
- **Install.** `xcrun devicectl device install app --device "Home Theater" …` → `App installed:` / `bundleID: com.marlin1111.marlin-media-tv`.
- **Result.** Home Theater and the repo match: HEAD's app code (D021 as committed in pass 2d) with the recipe's framework.
- **Not done.** No launch or playback on this final build; the pass asks for build and install.

## 9. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1 | `Marlin Media TV/PlayerModel.swift`, `PlayerHost.swift` (paused seeks during the drag, landing variants, Page Up/Down hook); `Marlin Media TVUITests/Diag2eUITests.swift` | **No.** Reverted/removed in step 8; saved as `reports/logs/2e-app-diag.diff` and `reports/logs/2e-harness-Diag2eUITests.swift.txt` (committed) |
| 2 | libvlc `src/clock/clock.c`, `src/clock/input_clock.c`, `src/input/decoder.c`, `src/input/es_out.c`, `src/input/input.c` in `~/vlckit-build` (temporary) | Outside the repo; restored in step 7; saved as `reports/logs/2e-libvlc-instrumentation.diff` (committed) |
| 2 | `Frameworks/VLCKit.xcframework` (instrumented package, then the recipe's) | Git-ignored |
| 2–6 | `reports/logs/2e-analysis.txt`, `2e-magicians-scrub.log.gz`, `2e-stargate-scrub.log.gz`, `2e-magicians-fresh.log.gz`; `reports/screenshots/2e/` (14 JPEGs) | Committed |
| 9 | This report; `COLD-START.md` (pass 2e note) | Committed |
| — | JSON traces (22–63 MB), raw screenshots, console output, scripts' working copies | Scratch only; the scripts are also in the analysis file |

- **Not touched:** `tools/vlckit-truehd/` (0007, 0018, 0019, 0020, `build.sh`); `DECISIONS.md` (no decision in a diagnosis pass); Design/; Marlin DVR TV; VLCKit's private player pointer; the bedroom Apple TV.
- **Constraints kept:** `TVOS_DEPLOYMENT_TARGET = 26.0`; Home Theater only, no simulator; the largest committed file is 2.2 MB; no UUID or device UDID in committed files (the `configured with /Users/…/vlckit-build/…` line is kept, as in passes 1k–2d); run names non-empty (the runner refuses empty or malformed tags, and each run got a new folder).
- **Pushed:** nothing.

## 10. What could not be tested live, and what was traced instead

- **The fix candidates.** None built. C1's effect is predicted from the code and from scrubs that happened not to lap (first-session scrubs 2 and 4, where `late` was negative), not from a C1 build.
- **The late median after resume** (C1 risk 1, C1b). Traced the recording path (`input_clock.c:320–324`), not its effect.
- **Re-pausing before each seek; `--clock-jitter`.** Not built or run (§6).
- **The drag itself.** Scripted through the model as in passes 2a–2d. XCUIRemote cannot touch the surface.
- **Wonder Woman and Divergent.** Not run; the brief names Magicians and Stargate.
- **Audio during the laps and at landing.** Not measured, as in passes 1k–2d.

## 11. Open questions

1. **Write patch 0021 as C1** (one condition, `es_out.c:3661`) in a fix pass? Or first a C1b-vs-C1 check of the late median after resume?
2. **If the picture should follow the thumb, is a libvlc patch acceptable** for it, given §6? Or does the committed D021 flow (picture holds, one seek after Play) stay as the answer?
3. **Stargate's subtitle need-data reads while paused** (§3.3, C5) are a separate cost: ~20 s of stream in 8 s of hold. Look at them with pass 2c's unexplained reads after a landing, or leave them?

## 12. Least-sure items

1. **"Laps end by chance when a rebuffer ends on a demux pass's last PCR."** This is inferred from log order: no `check1` line between the buffering end and the late PCR, and a closed gate after the last lap. The demux calls themselves weren't logged.
2. **C1's safety for other paused paths.** A paused track change and a paused title change reach the same PCR block. Only paused seeks were traced.
3. **The ~6 s ceiling.** It is 1 s of pts_delay plus the 5 s `clock-jitter` default, read from the logged `total_delay`/`new_jitter` values (`new_jitter=4963779`, `4867438`, `4803803`) in three launches. A different network caching setting would move it.
4. **The first session's scrubs 2–4 inherited scrub 1's pts_delay.** The fresh launch covers the lift-only case. The 20 s drag + click in the fresh launch also followed a lapped scrub.
