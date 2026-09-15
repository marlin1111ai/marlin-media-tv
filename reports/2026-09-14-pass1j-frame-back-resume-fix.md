# Pass 1j — patch 0021 (start the clock at the picture on screen) — STOPPED at step 1 — 2026-09-14

**Result.**
- **The picture half of pass 1i's cause is confirmed, line by line, from an instrumented run on Home Theater.**
  - At Play the displayed picture is PTS 33 834 ms.
  - Play resets the input clock, and the demuxer's first PCR after the reset (34 785 ms) becomes the clock's start.
  - Every queued picture below that start is late: **21 dropped** (PTS 33 917 … 34 751 ms), and the displayed picture renders 955 ms late.
- **The audio half is not.** There is no 1.4 s audio delay.
  - The tvOS audio output starts **92 ms after the first picture** (`avs startNow` at +101.6 ms; first picture at +9.4 ms).
  - Pass 1i's number was the output's **1-second periodic timing report**, the first "RENDER realtime" event in the trace, not the start of sound.
- **Why I stopped.** Step 1 says to stop if the cause isn't what pass 1i inferred, and it partly isn't. It also matters for step 2:
  - The first audio block after Play is PTS 34 912 ms, 1.08 s after the displayed picture.
  - A clock started at the displayed picture would play ~1.1 s of pictures before any sound: silence instead of dropped pictures, where today audio starts with the first picture.
  - That is a design question for you (§4).
- **Step 7's case, on this build (before any 0021).** The need-data flag is set again by Play's resume flush and stays set through a later plain pause. The demuxer read 3 967 times while paused (PCR 98.4 → 182.4 s). That resume was still clean: pause delay applied, 0 dropped.
- **Step 13.** `git fetch` done. `origin/main` is `b22f9c99dc…` (pass 1e rerun 4); local `main` is `65caf6d`, 4 ahead. Pass 1i's COLD-START statement was right; nothing corrected.

**Not done (step 1 STOP):**
- no 0021, no player tests (step 3), no step 4 recipe build of a 0021
- no matrix (step 6), no step 7 on the final build, no step 8
- no D008 change or decisions, no PlayerModel commit
- no VideoLAN draft (step 12)

**State.**
- **libvlc and framework.** The libvlc instrumentation is reverted, and `Frameworks/VLCKit.xcframework` is again the full recipe's build with 20 patches, as in pass 1i (§6).
- **Device.** Home Theater runs HEAD + the uncommitted 1f diff on that framework.
- **Commits.** Evidence, this report and COLD-START are committed locally. Nothing pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Instrument resume, Stargate | **Done → STOP.** Picture cause confirmed; audio part of pass 1i's inference wrong (§2, §3). |
| 2 Patch 0021 | Not written (step 1 STOP). Candidates and lines in §4. |
| 3 Player tests before/after | Not run (no 0021). |
| 4 Full rebuild | Done only to restore the pass 1i framework after the instrumented build (§6); no 0021. |
| 5 1f diff, build, install | Already applied (uncommitted since pass 1i, `gotoPreviousFrame` ×2). Instrumented build installed for step 1, then the clean one (§6). |
| 6 Matrix | Not run. |
| 7 Second pause | Not run on a final build; **traced in the step 1 run** (§5). |
| 8 Exactness | Not run. |
| 9–10 | Not reached. |
| 11 This report | Done. |
| 12 VideoLAN draft | Not written. |
| 13 Fetch origin | **Done.** No correction needed. |

## 1. Method

- **Instrumentation.** Log-only, applied to libvlc `03632d2eb8` (VLCKit's 17 + 0018 + 0019 + 0020):
  - pass 1h's combined diff (1g clock lines + 1h need-data flag lines);
  - 11 new `1j:` lines, `reports/logs/1j-libvlc-resume-instrumentation.diff` (the whole instrumented tree's diff).

  | Site | New `1j:` line |
  |---|---|
  | `decoder.c` `vlc_input_decoder_StopFrameNext` | stepping state at Play: `pf_pts`, countdown, fifo count |
  | `decoder.c` `ModuleThread_PlayVideo` | the first 40 pictures put to the vout |
  | `decoder.c` `ModuleThread_PlayAudio` | the first 8 audio blocks |
  | `audio_output/dec.c` `vlc_aout_stream_Play` | first plays after a flush: play date vs now |
  | `audio_output/dec.c` `vlc_aout_stream_NotifyTiming` | the first timing points |
  | `clock/input_clock.c` `input_clock_Update` | the reference point |
  | `video_output.c` | every picture dropped or rendered late, with its PTS |
  | `modules/audio_output/apple/avsamplebuffer.m` | first play, `startNow`, `time_observed` |

- **Build.** Device slice `src/` and `modules/` recompiled and installed, `libvlc-full-static.a` relinked, `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh`. 11 `1j:` strings in the static lib, the framework and the installed app. `** TEST BUILD SUCCEEDED **`, `App installed`.
  - A first attempt failed to compile (my counter declared after its first use in `decoder.c`), before anything was packaged. It was fixed and rebuilt.
- **Run.** Console launch with VLCKit's tvOS defaults and the JSON tracer, then the attach-mode XCUITest `Diag1jUITests/tStargateTwice`:
  - Stargate Extended, play 30 s, pause, hold 77 s
  - five Left clicks ~4.2 s apart, 20 s
  - **Play 1**, 60 s
  - **pause 2** held 80 s, **Play 2**, 60 s

  The run was 23:22–23:29, test passed (395.7 s).
- **Container path probe.** Pass 1i's failure is fixed: the console launch is stopped before its output is read, so the output is flushed; the run is refused if no path is found.
- **Evidence.**
  - `reports/logs/1j-analysis.txt`: harness notes, `resume1j.py` output with the script, `matrix.py` and `pausereads.py` outputs
  - `reports/logs/1j-instr-stargate-twice-full.log.gz`: redacted full app + VLC log
  - `reports/screenshots/1j-instr-stargate-twice-{06-play1+3s,07-play1+60s,10-play2+3s,11-play2+60s}.jpg`
  - the JSON trace (10.6 MB) stays off-repo in scratch
- **Times.** Relative to the 1g `input control_unpause` date, in ms.

## 2. Step 1 — where Play's clock start comes from

Play 1 (`resume1j.py`):
```
11:25:15.050 PM [player] play (select) at 33834 ms
    +0.0 ms [DBG] 1g: input control_unpause date=484073621342 now=484073621376
    +0.3 ms [DBG] 1g: es_out change_pause paused=0 date=484073621342 … was_paused=1 old_pause_date=483951765637
    +0.4 ms [DBG] 1j: stop_frame_next cat=1 countdown=-1 pf_pts=33834001 fifo=21 now=484073621707
    +0.4 ms [DBG] 1g: es_out change_position now=484073621733 paused=1 pause_date=483951765637 buffering=0 next_frame_es=1
    +0.5 ms [WARN] 1g: main_change_pause resume: pause_date INVALID, no delay applied
    +0.6 ms [DBG] 1j: video put pts=33867001 force=1 now=484073621904
    +1.6 ms [WARN] 1j: input_clock reference stream=34785001 system=484073622939 buffering=1 discontinuity=0 now=484073622941
            [DBG] Stream buffering done (1001 ms in 3 ms)
    +5.2 ms [DBG] 1g: es_out stop_buffering now=484073626560 paused=0 pause_date=484073621342 current_date=484073626558 buffering_duration=1000000 update=484072626558 stream_start=34785001
    +5.3 ms [WARN] 1g: set_first_pcr now=484073626632 system=484072626558 ts=34785001 paused=0 pause_date=0
    +9.4 ms [DBG] 1j: vout late render pts=33834001 late=955189 now=484073630747
   +10.7 ms [DBG] 1j: vout drop pts=33917001 system_pts-now=-873457 now=484073632015
   … (21 drops, pts 33917001 … 34751001, lateness falling 873 → 50 ms)
   +21.3 ms [DBG] 1j: vout drop pts=34751001 system_pts-now=-50057 now=484073642615
   +23.1 ms [DBG] 1j: vout late render pts=34785001 late=17866 now=484073644424
```

**The chain, with the lines each quote sits on** (libvlc `03632d2eb8`):
1. **Play enters `EsOutResumeFromNextFrame`** (`es_out.c:1014–1018`). It stops frame stepping, with the displayed picture `pf_pts=33834001` in the video decoder (`decoder.c:136`, set from `vout_Flush`'s `displayed.timestamp` at `decoder.c:3052`). It then calls `EsOutChangePosition(p_sys, video)`.
2. **`EsOutChangePosition` resets the input clock** (`input_clock_Reset`, `es_out.c:1101`) and sets `b_buffering`.
3. **The next PCR the demuxer delivers becomes the clock's reference** (`input_clock.c:276–281`: `cl->ref = clock_point_Create(i_ck_system, i_ck_stream)`), here `stream=34785001`.
   - **Why that PCR is 951 ms ahead of the picture.** The demuxer stands where normal buffering left it: the pts-delay of ~1 s ahead of what is displayed. That's the same `Stream buffering done (1001 ms …)`.
4. **The buffering end takes `i_stream_start` from that reference** (`input_clock_GetState`, `es_out.c:1138–1141`) and anchors the main clock at `update = now − buffering_duration` (`es_out.c:1219–1221`). The call is `vlc_clock_main_SetFirstPcr(update, i_stream_start)` (`es_out.c:1253–1254`).
   - With the ~1 s output delay the conversion adds back (`clock.c:675–700`), PTS 34 785 plays at "now", so a picture at PTS *p* is (34 785 − *p*) ms late.
5. **The video decoder was not flushed** (it is the no-flush ES of step 1), so its queue still starts at the picture after the displayed one. The vout drops every picture whose lateness is past its threshold (`IsPictureLateToStaticFilter`, `video_output.c:1106–1116`).
6. **Where the displayed PTS lives.** Only in the decoder (`owner->video.pf_pts`) and the vout (`displayed.timestamp`); nothing on es_out's side reads it. So the anchor can only be the demuxer's position.

**Which dropped pictures follow from it: all of them.**
- **Dropped.** 21 `too late` lines between Play 1 and pause 2, all with PTS below the reference: `dropped pts range: 33917001 34751001`.
- **Late.** 2 `displayed late`: the displayed picture itself (955 ms) and the reference picture (17 ms).
- **No others.** No picture at or after PTS 34 785 was dropped (`Play 1 → pause 2: too late 21, displayed late 2, 1j vout drop 21`).
- **Pass 1i's clean runs.** 21 / 26 dropped with first-picture lateness 925 / 1 166 ms, the same mechanism: (reference − displayed PTS) over the picture grid.

## 3. Step 1 — the audio: no 1.4 s delay

Play 1, same window:
```
    +5.3 ms [DBG] 1j: audio dec play pts=34912001 samples=1536 now=484073626678
    +5.4 ms [DBG] 1j: aout play pts=34912001 play_date=484073753558 now=484073626694 play_date-now=126864 first=1
    +5.4 ms [DBG] 1j: avs first play pts=34912001 date=484073753558 now=484073626717 date-now=126839
            [DBG] deferring start (987420 us)
            … (deferring start, falling to 56110 us)
            [DBG] started
  +101.6 ms [DBG] 1j: avs startNow delta=0 now=484073722929 firstPts=34912001
 +1563.4 ms [DBG] 1j: avs time_observed time=1000129 pos=35912130 now=484075184776
 +1563.6 ms [DBG] 1j: aout notify_timing system_ts=484075184776 audio_ts=35912130 now=484075184986
```

**Sequence.**
1. Audio was flushed by the resume. Its first block after Play is PTS 34 912, the first audio the demuxer delivers after the new reference.
2. The audio core converts it to a play date 127 ms ahead.
3. The tvOS output defers its start to that date and starts the renderer at **+101.6 ms**. The first picture rendered at +9.4 ms, so audio starts **~92 ms after the first picture**, in sync with the clock (PTS 34 912 at anchor + 127 ms).

**Why pass 1i measured 1.4 s.** The tvOS output only reports timing through `addPeriodicTimeObserverForInterval` with a 1 s interval, and ignores `time.value == 0` (`avsamplebuffer.m:244–270`). Its first report is 1 s of audio in (`time=1000129`, `pos=35912130`, +1563 ms). Those reports are the trace's audio `RENDER realtime` events, so "first audio render" there is always ≥1 s after sound starts.
- **The control only looked right.** In pass 1i's no-step control the renderer was never flushed and its observer kept firing at the usual spacing, so the first report after Play came within ~234 ms.
- **The metric is unusable.** Pass 1i's "1 477 / 1 361 ms after the first picture" and "176 ms" are not audio start times.

**Which part of the audio follows from the clock start.** The *film position* gap: sound resumes at 34.912 s while the pictures resume at 33.834 s (the 21 dropped pictures play no sound). The *wall-time* start does not: audio begins ~92 ms after the first picture.

## 4. Why step 2 was not written, and the candidates

**What "start the clock at the picture on screen" would do.**
- **Pictures.** An anchor at PTS 33 834 plays the queued pictures from 33.834 s on time, so there's nothing to drop.
- **Audio.** It was flushed, and its first block is PTS 34 912 (es_out doesn't keep audio across the resume). It would be ~1.08 s *early* for that clock, so the audio core holds it: sound starts **~1.1 s after the first picture**. Today it starts ~92 ms after.
- **This is inferred** from the traced PTS and `vlc_aout_stream_Play`'s early handling, not run.

The trade is 21 dropped pictures (0.9 s of picture with its sound skipped) for ~1.1 s of picture with no sound. Your call, before anything is written.

**Where each design would touch** (none written):

| # | Design | Lines touched | Notes |
|---|---|---|---|
| E1 | Anchor at the displayed PTS: pass it from the decoder to es_out and use it for `i_stream_start` when resuming from frame stepping | `decoder.h` (new getter or `vlc_input_decoder_StopFrameNext` returning a tick), `decoder.c:2977–2982` (`StopFrameNext`; `pf_pts` is cleared by `StopFrameNextLocked` at `2971`), `es_out.c:1014–1018` (keep it), `es_out.c:1138–1141` / `1253–1254` (use it) | Three files, so not one contained change. Back steps only: `pf_pts` is set by `FramePrevious` (`decoder.c:3052`). A forward step has no `pf_pts`; it needs the vout's `displayed.timestamp` (`video_output.c:1140`), which has no getter. Leaves ~1.1 s of silence (above). |
| E2 | E1 for the video anchor plus the audio re-read from the displayed PTS | E1 + a seek of the demuxer to the displayed PTS on resume | That is pass 1g's candidate C (resume as a seek), excluded by this pass. |
| E3 | Leave the anchor; drop the stale pictures before resume instead of at the vout | `es_out.c:1014–1018` (flush video too) | Also candidate C's territory; excluded. |

## 5. Step 7's case, traced in the same run — the second pause

- **The flag is set again 0.8 ms after Play 1**, by the resume flush's subtitle request, after `p_next_frame_es` is already NULL, so 0020 lets it through. Nothing clears it until Play 2. Full log, lines 2654–2667 and 14819–14820:
  ```
  11:25:15.050 PM [player] play (select) at 33834 ms
  [DBG] 1h: INPUT_CONTROL_NEED_DATA_FRAME_NEXT 0 -> 1 now=484073622133
  …
  11:27:41.550 PM [player] play (select) at 96857 ms
  [DBG] 1h: next_frame_need_data cleared by control 0 now=484220121898
  ```
- **During pause 2 the flag stays set and the gate stays open on every evaluation** (`resume1j.py`):
  ```
  [11:26:17.552 PM [player] pause (select) at 96349 ms] -> [11:27:41.550 PM [player] play (select) at 96857 ms]: flag writes {}; check1 (GetBuffering,b_eof,need_data,demux_allowed) {('0', '0', '1', '1'): 3967}; demuxed-while-paused 3967
  ```
- **For comparison, pause 1** (before and during the steps):
  ```
  [11:23:13.194 PM [player] pause (select) at 33678 ms] -> [11:25:15.050 PM [player] play (select) at 33834 ms]: flag writes {'0->0': 1}; check1 … {('0', '0', '0', '0'): 6, ('1', '0', '0', '1'): 357}; demuxed-while-paused 357
  ```
- **The trace over pause 2** (`pausereads.py`) shows reads at 1× through the whole pause:
  ```
  +  0s  PCR 98431367..103487001 ms (114)       demux out {'video/1': 121, 'audio/2': 159}
  …
  totals while paused: demux out {'video/1': 2073, 'audio/2': 2625, 'spu/4': 1}; highest PCR read 182382367 ms
  ```
  - PCR 98.4 → 182.4 s over the 83.9 s pause: about **84 s read ahead**. The script's "read-ahead 83984.366 s" label is a µs/ms slip.
  - The one subtitle packet at +10 s did not clear the flag.
- **Play 2 still resumes cleanly.** No stepping means no re-anchor, and the pause delay is applied:
  ```
  [WARN] 1g: main_change_pause resume: delay=83997759 applied, …
  [DBG] picture displayed late (missing 14 ms)
  ```
  Play 2 → end: 0 too late, 1 displayed late (14 ms). The audio renderer kept running (`avs time_observed` at +99.6 ms). Clock 01:40 at +3 s and 02:37 at +60 s, from a pause at 01:36.
- **So after a step and Play, a later plain pause reads the stream while paused** (memory: ~84 s of stream queued), where a pause with no earlier step reads nothing (pass 1g). It did not break that resume here. This is 0020's remaining gap (pass 1i open question 4), now shown.

## 6. State restored

- **libvlc.** The 8 instrumented files were reverted with `git checkout`, and the diff is saved as `reports/logs/1j-libvlc-resume-instrumentation.diff`.
- **Full recipe.** `tools/vlckit-truehd/build.sh`, not `PACKAGE_ONLY`, re-applied the 20 patches (no 0021 exists). The app was rebuilt and installed on Home Theater. Checks: §6.1.

### 6.1 Restore checks

- **Full recipe.** `tools/vlckit-truehd/build.sh`: `patch 0019 installed`, `patch 0020 installed`, `VLCKit.xcodeproj TVOS_DEPLOYMENT_TARGET = 26.0 (4 build configurations)`, `build start: 2026-09-14 23:30:42`, `build end: 2026-09-14 23:33:59`, `done: …/Frameworks/VLCKit.xcframework`, `recipe exit 0`; 20 `Applying:` lines.
- **`Frameworks/VLCKit.xcframework`.**

  | Slice | `MinimumOSVersion` | `LC_BUILD_VERSION` | `1g:`/`1h:`/`1j:` strings |
  |---|---|---|---|
  | `tvos-arm64` | 26.0 | `minos 26.0 sdk 27.0` | 0 |
  | `tvos-arm64_x86_64-simulator` | 26.0 | `minos 26.0 sdk 27.0` (×2) | 0 |

  Device slice: `000000000236e730 S _ff_truehd_decoder` (and `_ff_mlp_decoder`, `_ff_mlp_parser`).
- **libvlc.** `git status --short` is empty at `9279ed3615`; the recipe's `git am` rewrote the hash. `git diff 03632d2eb8 HEAD` is empty, so it's the same content as the tree the run was instrumented on. The three `libvlc-full-static.a` were rewritten at 23:31:42 (device), 23:32:35 and 23:33:27 (simulators).
- **App.** `xcodebuild build … 'platform=tvOS,name=Home Theater'` → `** BUILD SUCCEEDED **`. 0 instrumentation strings in the embedded framework. `devicectl device install app` → `App installed:`. `TVOS_DEPLOYMENT_TARGET = 26.0` in both configurations. Home Theater now runs HEAD + the uncommitted 1f diff on the recipe framework.

## 7. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1 | libvlc (8 files, temporary) → `reports/logs/1j-libvlc-resume-instrumentation.diff`; `reports/logs/1j-analysis.txt`, `1j-instr-stargate-twice-full.log.gz`; `reports/screenshots/1j-instr-stargate-twice-*.jpg` (4) | Evidence committed; libvlc reverted |
| 1 | `Frameworks/VLCKit.xcframework` (instrumented, then the recipe build again) | Git-ignored |
| 1 | Temporary `Marlin Media TVUITests/Diag1jUITests.swift` (pass 1i's harness + `twice(_:)`, `tStargateTwice`, `tDivergentTwice`, `tWonderWomanExact`) | Moved out of the repo to scratch; not committed |
| 5 | `Marlin Media TV/PlayerModel.swift` (1f diff, from pass 1i) | **Not committed** |
| 11, 13 | This report; `COLD-START.md` (pass 1j note; pass 1i's pushed statement verified, unchanged) | Committed |

- **Not touched:** 0007, 0018, 0019, 0020; `build.sh`; `DECISIONS.md`; Design/; Marlin DVR TV.
- **Constraints kept:** deployment target 26.0; Home Theater only; nothing over 10 MB; identifiers redacted; run name non-empty; no scratch folder deleted.
- **Pushed:** nothing.

## 8. Open questions

1. **Resume design, given the audio finding.** Today: 21–26 pictures (~0.9 s) are dropped, and sound starts ~92 ms after the first picture. With the clock at the displayed picture (E1): no drops, ~1.1 s of picture with no sound. With E2 (also re-read audio from the displayed picture): both fixed, but that is a seek on resume (candidate C). Which, or accept today's behaviour?
2. **The second-pause read-ahead (§5).** Should a pass fix it? The flag is set by the resume flush's subtitle request after stepping ends. Candidate points:
   - `es_out.c:1014–1018`: clear after the resume flush;
   - `decoder.c:2789–2793`: the paused-flush countdown;
   - `input.c:2151`: the order of the Play clear.
3. **The audio metric.** Pass 1i's "audio vs first picture" numbers are wrong. Future passes need the tvOS output's start line with a timestamp (an instrumented run) or another measure. Should pass 1i's report be annotated?

## 9. Least-sure items

1. **One run, one film, back steps only.** The forward-step resume isn't instrumented. By the code, the same anchor applies, but it has no `pf_pts`.
2. **"Audio starts" is `startNow`,** when the tvOS renderer's synchroniser is set to rate 1. The audible latency after that (HDMI, the receiver) isn't measured.
3. **E1's ~1.1 s of silence** is inferred from the traced PTS and the audio core's code, not run.
4. **The flag's re-set after Play 1** is read from the setter line's position in the log. Which decoder sent it is by elimination (as pass 1h): the subtitle decoder's flush while es_out still counts as paused.
