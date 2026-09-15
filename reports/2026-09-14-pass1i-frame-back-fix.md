# Pass 1i — patch 0020 (design B1) for native frame-back resume — STOPPED at step 8 — 2026-09-14

**Result.**
- **0020 does what B1 was meant to do.** The need-data flag no longer keeps the demuxer reading while paused after a step.
  - **Directly, in an instrumented run** on Home Theater (Stargate, five back steps): the flag is cleared at the first step (`setter 0 -> 0`), never set while paused, and the pause gate only opens during each step's own rebuffer (`('1','0','0','1'): 374`, need_data always 0).
  - **Indirectly, in the clean recipe build:** 0 demux reads while paused outside a step, against 22 700 in pass 1h. The highest PCR read while paused is 34.45 s, where pass 1h reached 154 s. The clock at Play+60 s is **01:34**, not 03:36.
- **Resume after steps is still worse than the no-step control.** Same session, same clean build, Stargate Extended:

  | Run | Dropped / late (first 60 s) | Audio's first render after the first picture |
  |---|---|---|
  | (a) five back steps | **21 / 1** | **1 477 ms** |
  | (b) five forward steps | **26 / 1** | **1 361 ms** |
  | (c) no step | 0 / 0 | 176 ms |

  Play plays about 1 s of pictures that are already late: the first picture is 925 ms late after back steps, 1 166 ms after forward steps. Audio restarts about 1 s further into the film than the picture.
- **Why I stopped.** By step 8's rule, I stopped at Stargate and reported with the trace (§4). Not done:
  - Wonder Woman, Divergent, Magicians and The Food That Built America (step 6)
  - step 7 (exactness)
  - step 9: D008 unchanged, no new decision, `PlayerModel.swift` not committed
  - step 11 (VideoLAN draft)

  No other fix was tried.

**State.**
- **Recipe.** `tools/vlckit-truehd/0020-…diff`, `build.sh` (installs it after 0019) and `README.md` are committed locally.
- **Framework.** `Frameworks/VLCKit.xcframework` is the full recipe's build with 20 patches (§3).
- **App code.** `PlayerModel.swift` carries the 1f native back step, **uncommitted**.
- **Device.** Home Theater runs that app with the clean framework.
- **libvlc.** Clean at `03632d2eb8` (the recipe's `git am`).
- **Pushed:** nothing.

## Result per step

| Step | Result |
|---|---|
| 1 Patch 0020 | **Done.** `tools/vlckit-truehd/0020-es_out-forward-next-frame-need-data-only-from-stepped-es.diff`, `git format-patch` form like 0019, installed by `build.sh` as `libvlc/patches/0020-….patch` after 0019. One file, `src/input/es_out.c`, 2 insertions / 1 deletion (§1). |
| 2 VLC's own tests | **Done.** `test/src/player` (20 programs, including `next_prev`, which steps back with a subtitle track and resumes) on a host macOS build of the same tree: 19 pass, 1 fail, **identical before and after 0020**. The failure is `attachments` (`no suitable encoder module for fourcc 'bmp '`, a module my stripped host configure left out). No expectation encodes the old behaviour; nothing corrected (§2). |
| 3 Full rebuild | **Done.** `tools/vlckit-truehd/build.sh`, not `PACKAGE_ONLY`, 22:43:32–22:46:43, exit 0, 20 `Applying:` lines. Both slices `MinimumOSVersion 26.0`, `LC_BUILD_VERSION minos 26.0 sdk 27.0`; `_ff_truehd_decoder` on the device slice; no trace strings (§3). |
| 4 1f diff, build, install | **Done.** `git apply reports/logs/1f-playermodel-native-prevframe.diff`; `** TEST BUILD SUCCEEDED **`; `App installed` on Home Theater. |
| 5 Subtitle tracks | **Done** (§5). No subtitle tracks: all 13 Magicians episodes and all 3 Food That Built America episodes. |
| 6 Matrix | **Stargate only**, then STOP (§4). |
| 7 Exactness | Not run. |
| 8 Worse than control? | **Yes → STOP** (§4). |
| 9 D008, decision, commit | Not done (step 8). |
| 10 This report | Done. |
| 11 VideoLAN draft | Not written (step 8). |
| 12 COLD-START pass 1e paragraph | **Done.** "Not pushed" and the two owner checks are replaced. Local `origin/main` is at `b22f9c9`, pass 1e rerun 4's commit, so the paragraph says pass 1e's HEAD is pushed. No fetch was made. |

## 1. Patch 0020

Line numbers in this report are in libvlc `03632d2eb8` (with 0020).

```diff
@@ -536,7 +536,7 @@ decoder_frame_next_need_data(vlc_input_decoder_t *decoder, bool need_data,
-    if (!p_sys->p_input)
+    if (!p_sys->p_input || (p_sys->p_next_frame_es != NULL && p_sys->p_next_frame_es != id))
         return;
@@ -1385,6 +1385,7 @@ static void EsOutFrameNext(es_out_sys_t *p_sys, bool previous)
             msg_Warn( p_sys->p_input, "No video track selected, ignoring 'frame next'" );
             return;
         }
+        input_ControlPushHelper( p_sys->p_input, INPUT_CONTROL_NEED_DATA_FRAME_NEXT, &(vlc_value_t){ .b_bool = false } );
     }
```

**Line 1 (B1).** While `p_next_frame_es` is set, a decoder callback from any other ES returns before it pushes `INPUT_CONTROL_NEED_DATA_FRAME_NEXT`. With no frame stepping (`p_next_frame_es == NULL`), paused seeks behave as before.

**Line 2 (the clear).** It runs only when frame stepping starts, after the video ES is chosen, and pushes `false` as a control:
- **Why a control and not a direct write.** A request already queued is processed first and then cleared.
- **Why it can't lose a forward step's request.** The clear is pushed before `vlc_input_decoder_FrameNext` / `FramePrevious`. A forward step's own request comes from the decoder thread after `StopFrameNextLocked` signals its fifo, so it's queued after the clear.

**Controls aren't merged.** `ControlGetReducedIndexLocked` (`input.c:1484–1525`) collapses only `SET_STATE`, `SET_RATE`, `SET_POSITION`, `SET_TIME`, `SET_PROGRAM`, `SET_TITLE`, `SET_SEEKPOINT`, `SET_VIEWPOINT` and `UPDATE_VIEWPOINT`. `NEED_DATA_FRAME_NEXT` is never merged.

**Timing assumption from pass 1h (least-sure 3), now traced.** `p_next_frame_es` is set in `EsOutFrameNext` before the step's seek flushes the subtitle decoder. In the instrumented run, step 1 logs the clear (`setter 0 -> 0`) and then decoder notifications that never reach the input (§4.1).

**Where frame stepping can end while paused.** `ES_OUT_PRIV_RESET_PCR_FRAME_PREV` with duration 0 (`es_out.c:4130–4137` → `EsOutResumeFromNextFrame`). Only `SeekFramePrevious`'s failed-same-PTS branch uses it (`input.c:2047–2058`: start of file, or VLC's "invalid" case). There, a subtitle flush after the mode ends can set the flag again. Not run.

## 2. Step 2 — VLC's test suite

Evidence: `reports/logs/1i-vlc-player-tests.txt`.
- **Host build.** Out-of-tree configure of `~/vlckit-build/VLCKit/libvlc/vlc` in `~/vlckit-build/host-test-1i` with Xcode 27's clang. The full configure line is in the file: avcodec, lua, qt, NLS, matroska and others are disabled, and `PKG_CONFIG_LIBDIR=/nonexistent` keeps Homebrew libraries out. `make -j12` exit 0.
- **Tests.** `make -C test check check_PROGRAMS="$P" TESTS="$P"` over the 20 `player_programs` of `test/Makefile.am`.
- **A (51f8302c27, before 0020):** `# TOTAL: 20 # PASS: 19 # FAIL: 1`, `FAIL: test_src_player_attachments`.
- **B (a931ccc17e, 0020 applied with `git am`; make recompiled `input/libvlccore_la-es_out.lo`):** `# TOTAL: 20 # PASS: 19 # FAIL: 1`, the same `attachments` failure (`main encoder error: no suitable encoder module for fourcc 'bmp '` … `exit status: 142`, the test's alarm).
- **What covers the touched code.** `test_src_player_next_prev` runs `test_prev` with 1 video + 1 audio + **1 SPU** track, then `check_resumed_timer` and `check_seek_timer`. It passes both times. It checks timecodes and states, not demux reads while paused, so it could not have detected the read-ahead either way.

## 3. Step 3 — full rebuild

- **The libvlc tree was cleaned first.** The instrumented files were put back with `git checkout`. The instrumentation applied was exactly `reports/logs/1h-libvlc-instrumentation-combined.diff`.
- **`tools/vlckit-truehd/build.sh`:** `patch 0018 installed`, `patch 0019 installed`, `patch 0020 installed`, `VLCKit.xcodeproj TVOS_DEPLOYMENT_TARGET = 26.0 (4 build configurations)`, `build start: 2026-09-14 22:43:33`, `build end: 2026-09-14 22:46:42`, `** ARCHIVE SUCCEEDED **` ×2, `done: …/Frameworks/VLCKit.xcframework`, `recipe exit 0`.
- **Build log.** The last `Applying:` is `input: es_out: forward next-frame data requests only from the stepped ES`, 20 in total. The three `error:` hits are live555's `sprintf` warning text.
- **Compiles.** All three `libvlc-full-static.a` were rewritten (22:44:32 device, 22:45:22 simulator x86_64, 22:46:12 simulator arm64). libvlc HEAD is `03632d2eb8`, tree clean.

| Slice | `MinimumOSVersion` | `LC_BUILD_VERSION` | `DTXcodeBuild` | Instrumentation strings (`check1`, `demuxed-while-paused`, `decoder notify need_data`, `es_out change_pause`, `main_change_pause`) |
|---|---|---|---|---|
| `tvos-arm64` | 26.0 | `platform TVOS minos 26.0 sdk 27.0` | 27A266a | 0 |
| `tvos-arm64_x86_64-simulator` | 26.0 | `platform TVOSSIMULATOR minos 26.0 sdk 27.0` (×2) | 27A266a | 0 |

- **Device slice `nm`:** `000000000236e730 S _ff_truehd_decoder`, `_ff_mlp_decoder`, `_ff_mlp_parser`.
- **Copied intact:** `diff -rq` against the build output reports no differences (725 MB).
- **A false positive.** A bare `grep -c "1h:"` counts 1 / 2 matches. They are the bytes `;/1h:` inside binary data, not a log string.
- **The installed app:** 0 of those strings in the embedded framework, 2 `gotoPreviousFrame` in `PlayerModel.swift`, `** TEST BUILD SUCCEEDED **`, `App installed`. `TVOS_DEPLOYMENT_TARGET = 26.0` in both configurations.

## 4. Step 6 / step 8 — Stargate, and why it stopped

**Method.**
- **Launch.** Console launch with VLCKit's eight tvOS defaults plus `--tracer=json --json-tracer-file=<container>/Library/Caches/vlc-trace-<run>.json`, then the attach-mode XCUITest `Diag1iUITests` (Appendix A; pass 1h's run shape).
- **Run shape.** Play 30 s, pause, hold 77 s, five clicks ~4.2 s apart (or none), 20 s still paused, Play, 60 s.
- **Measures.**
  - Positions from the app log.
  - Dropped and late from the trace's video `toolate` / `late` events in the 60 s after the vout `resumed` event.
  - Audio start from the first realtime audio render against the first realtime video render.
  - Clock read from the screenshots.
- **Scripts and outputs:** `reports/logs/1i-analysis.txt` (`matrix.py`, `pausereads.py`, `resumepts.py`). Logs: `reports/logs/1i-clean-stargate-{back,fwd,none}.log`.

### 4.1 The need-data flag across the run

**Direct trace — the instrumented build** (0020 + pass 1h's instrumentation, device slice relinked, `PACKAGE_ONLY`; `reports/logs/1i-instr-analysis.txt`, full log `1i-instr-stargate-back-full.log.gz`):
```
  app: 10:44:37.685 PM [player] pause (select) at 33205 ms
  app: 10:45:58.333 PM [framestep] −1 gotoPreviousFrame before=33473 ms
    setter 0 -> 0 now=481716905682
      decoder notifies since: {'need_data=1 countdown=1': 1}
      decoder notifies since: {'need_data=1 countdown=1': 5}
  … (steps 2–5: 1–21 decoder notifications each, no setter line)
  app: 10:46:39.900 PM [player] play (select) at 33333 ms
    setter 0 -> 1 now=481758473383
pause segment from [10:44:37.685 PM [player] pause (select) at 33205 ms]: check1 (GetBuffering, b_eof, need_data, demux_allowed) -> {('0', '0', '0', '0'): 6, ('1', '0', '0', '1'): 374}
```
- **What reaches the input.** The subtitle decoder still asks: `decoder notify need_data=1 countdown=1`, 109 times while paused, where pass 1h had 12 288. None of those requests reaches the input.
- **The flag's writes.** Its only writes are the clear at step 1 (`0 -> 0`) and a `0 -> 1` right after Play. The Play one is the resume flush of `EsOutResumeFromNextFrame`, after `p_next_frame_es` is already NULL.
- **The gate.** Every paused evaluation had `need_data=0`, and the gate opened only while es_out was buffering for a step (374).
- **The trace.** Demux reads only in the four 5-s buckets holding steps (`+80s … demux out {'video/1': 96, 'audio/2': 99}` … `+95s`); the highest PCR read while paused was 34.451 s.

**Proxy trace — the three clean runs** (the flag isn't logged in the clean build). The input demuxes while paused only when es_out is buffering or the flag is set (`input.c:668–669`), so reads while paused outside a step's rebuffer would mark the flag. `matrix.py`:
```
stargate-back: spu ['spu/4'] | pause at 33495 ms, Play at 33333 ms, paused 122.2 s | steps 5 | reads while paused: 384 within 2.5 s of a step, 0 otherwise; highest PCR while paused 34451 ms | 60 s after resume: dropped 21, late 1, first video drift -925.2 ms, audio − video first render 1477 ms
stargate-fwd: spu ['spu/4'] | pause at 33972 ms, Play at 34251 ms, paused 122.2 s | steps 5 | reads while paused: 0 within 2.5 s of a step, 0 otherwise; highest PCR while paused 35392 ms | 60 s after resume: dropped 26, late 1, first video drift -1166.4 ms, audio − video first render 1361 ms
stargate-none: spu ['spu/4'] | pause at 33979 ms, Play at 33979 ms, paused 121.0 s | steps 0 | reads while paused: 0 within 2.5 s of a step, 0 otherwise; highest PCR while paused None ms | 60 s after resume: dropped 0, late 0, first video drift -1.1 ms, audio − video first render 176 ms
```
- **Pass 1h for comparison:** 22 700 reads licensed only by the flag, and PCR 33 → 154 s while paused.
- **Why forward has no PCR reads.** "Highest PCR while paused 35392" in (b) is the demuxer's last PCR event at the pause edge; there were 0 demux OUT events. Forward steps used pictures already queued.

### 4.2 Step 6 numbers (Stargate only)

| Stargate Extended, clean build | Position at pause | Position at Play | Paused (trace) | Dropped / late, first 60 s | Audio starts at the first picture? | Clock at Play +3 s / +60 s |
|---|---|---|---|---|---|---|
| (a) five back steps | 33 495 ms | 33 333 ms | 122.2 s | **21 / 1** | **No**: first audio render 1 477 ms after the first picture | 00:37 / 01:34 |
| (b) five forward steps | 33 972 ms | 34 251 ms | 122.2 s | **26 / 1** | **No**: 1 361 ms after | 00:38 / 01:35 |
| (c) no step (control) | 33 979 ms | 33 979 ms | 121.0 s | 0 / 0 | Yes: 176 ms after | 00:37 / 01:34 |
| instrumented back (0020 + 1h lines) | 33 473 ms | 33 333 ms | 122.1 s | 22 / 2 | No: 1 504 ms after | 00:37 / 01:34 |
| *pass 1h, back, no 0020 (for reference)* | *33 483 ms* | *33 333 ms* | *122.2 s* | *1 495 / 4* | *No: 1 484 ms after* | *02:39 / 03:36* |

- **Position at pause** is VLC's `state Paused at` (its interpolated clock); **position at Play** is `play (select) at`.
- **Screenshots:** `reports/screenshots/1i-stargate-{back,fwd,none}-{00-paused,05,05b-before-play,06-play+3s,07-play+60s}.jpg` and `1i-instr-stargate-back-{06-play+3s,07-play+60s}.jpg`.
- **What the clock doesn't show.** The on-screen clock is the same in all three runs, so the late pictures are about the first second only. They're dropped, not a position error.

Not run: Wonder Woman, Divergent, Magicians and The Food That Built America (the no-subtitle title from step 5), because of step 8.

### 4.3 The trace behind the STOP (`resumepts.py`, times relative to the vout `resumed` event)

```
== stargate-back
first PCRs after resume: [(0.4, 34334), (1.6, 34367), (1.9, 34400)]
first video renders (t ms, pts ms, drift ms): [(10.0, 33333, -925.2), (11.8, 33367, -893.0), (35.9, 34284, -0.1)]
first audio DEC OUT (t ms, pts ms): [(1.3, 34336), (8.0, 34368), (12.6, 34400)]
first audio renders (t ms, pts ms, drift ms): [(1487.2, 35336, 0.0), (2487.3, 36336, 0.0), (3487.2, 37336, 0.0)]
== stargate-fwd
first PCRs after resume: [(1.2, 35419), (1.5, 35452), (2.8, 35616)]
first video renders (t ms, pts ms, drift ms): [(87.3, 34251, -1166.4), (90.8, 34668, -752.9), (113.0, 35419, -24.0)]
first audio DEC OUT (t ms, pts ms): [(2.3, 35424), (14.2, 35456), (14.5, 35488)]
first audio renders (t ms, pts ms, drift ms): [(1448.7, 36424, 0.0), (2449.3, 37424, 0.0), (3447.6, 38424, 0.0)]
== stargate-none
first PCRs after resume: [(17.6, 35392), (43.7, 35419), (71.3, 35452)]
first video renders (t ms, pts ms, drift ms): [(58.0, 34034, -1.1), (111.7, 34084, -4.7), (145.4, 34117, -5.5)]
first audio DEC OUT (t ms, pts ms): [(17.9, 35392), (18.0, 35424), (18.1, 35456)]
first audio renders (t ms, pts ms, drift ms): [(233.8, 34006, 0.0), (234.5, 34007, 0.0), (1227.3, 35000, 0.0)]
```
App log after Play (a):
```
10:54:36.610 PM [player] play (select) at 33333 ms
[DBG] Stream buffering done (1031 ms in 7 ms)
[DBG] picture displayed late (missing 925 ms)
[WARN] picture is too late to be displayed (missing 848 ms)
… 21 "too late" lines in all
```
Instrumented run, the same moment with the clock lines (`1i-instr-analysis.txt`):
```
[DBG] 1g: es_out change_position now=481758472198 paused=1 pause_date=481636256804 buffering=0 next_frame_es=1
[WARN] 1g: main_change_pause resume: pause_date INVALID, no delay applied
[DBG] Stream buffering done (1031 ms in 10 ms)
[DBG] 1g: es_out stop_buffering now=481758484581 paused=0 pause_date=481758471969 current_date=481758484577 buffering_duration=1000000 update=481757484577 stream_start=34304001
[WARN] 1g: set_first_pcr now=481758484765 system=481757484577 ts=34304001 paused=0 pause_date=0
```

**Reading, from the trace (not instrumented further).**
- **The resume flush.** Play goes through `EsOutResumeFromNextFrame`. It flushes every ES except video, and the input rebuffers from where the demuxer stands: PCR 34.33 s after back steps (the step pre-roll's end), 35.42 s after forward steps (the read-ahead VLC keeps at normal play).
- **The new anchor.** The buffering end anchors the main clock at that PCR, `stream_start=34304001` at `now − 1 s` (`update=…484577 − 1 000 000`). That is ~1 s after the picture on screen.
- **Video.** The fifo still starts at the displayed picture (33 333 / 34 251 ms). The pictures before the anchor play 0.9–1.2 s late, and the vout drops 21–26 of them until PTS ≈ the anchor (34 284 ms at drift −0.1).
- **Audio.** It was flushed. It restarts from the first PCR's block (DEC OUT 34 336 / 35 424 ms), but its first render is at PTS 35 336 / 36 424 ms, 1.45–1.49 s after resume. In the control, audio renders PTS 34 006 at +234 ms. Why the audio output's first render lands 1 s after the first decoded block is not explained by this trace (least-sure 2).
- **The control.** It never re-anchors: no `Stream buffering done` after Play, and the pause delay is applied as in pass 1g.

So what's left is on the resume side, pass 1g's candidate C area (the resume flush keeps video and re-anchors at the demuxer's position), possibly with D (`pause_date INVALID`). Nothing was implemented, by step 8's rule.

## 5. Step 5 — the library and its subtitle tracks

From `GET /api/movies` and `GET /api/shows/{id}` on 192.168.1.250:8093 (22:35); `subtitle_tracks` per file:

| Title | File | Subtitle tracks |
|---|---|---|
| Divergent (2014) | `Movies/Divergent/Divergent (2014).mkv` | 6: subrip, subrip, hdmv_pgs_subtitle ×4 |
| Stargate (1994), Extended | `Stargate (1994) {edition-Extended}.mkv` | 1: subrip |
| Stargate (1994), Theatrical | `Stargate (1994) {edition-Theatrical}.mkv` | 1: subrip |
| Wonder Woman (2017) | `Wonder Woman (2017).mkv` | 1: hdmv_pgs_subtitle |
| The Food That Built America S04E02 Holiday Treats | `.mp4` | **none** |
| The Food That Built America S04E05 Clash of the Coffee | `.mp4` | **none** |
| The Food That Built America S07E11 Spilling the Tea | `.mp4` | **none** |
| The Magicians S1E1 Unauthorized Magic … S1E13 Have You Brought Me Little Cakes? (13 episodes) | `.mp4` | **none** (all 13) |

Videos: 0.

**No subtitle tracks:** all 13 Magicians episodes and all 3 Food That Built America episodes. The server's list was not cross-checked against VLC's own track list on those files, because they weren't played in this pass. Step 6 on a no-subtitle title (The Food That Built America S04E02, harness `tFood*`) was not run, because of step 8.

## 6. What could not be tested, and what was traced instead

- **The need-data flag in the clean build.** It isn't logged there. Traced instead:
  - demux reads while paused (0 outside steps), valid because the gate has only two inputs (`input.c:668–669`);
  - one instrumented run on the same sources plus log lines, which shows the flag directly.
- **Audio "starting at the first picture":** measured as trace render events, not heard.
- **VideoToolbox titles, MP4 titles, a no-subtitle title:** not run (step 8).
- **Exactness per click (step 7):** not run. The runs' app lines show one step per click on the file's grid:
  - back: `after(400 ms)=` 33 500, 33 450, 33 417, 33 367, 33 333 (instrumented run);
  - forward (clean run (b)): see `1i-analysis.txt` "per-click positions".

  No screenshot pixel comparison was made.

## 7. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1 | `tools/vlckit-truehd/0020-es_out-forward-next-frame-need-data-only-from-stepped-es.diff` (new), `tools/vlckit-truehd/build.sh` (step 2c′ copies 0020), `tools/vlckit-truehd/README.md` (0020 paragraph) | Committed |
| 1 | libvlc `src/input/es_out.c` in `~/vlckit-build` (drafted in a temporary git worktree, since removed; applied with `git am`) | Outside the repo; now in the recipe's own tree `03632d2eb8` |
| 2 | Host test build `~/vlckit-build/host-test-1i` (outside the repo); `reports/logs/1i-vlc-player-tests.txt` | Evidence committed |
| 3 | `Frameworks/VLCKit.xcframework` (full recipe build) | Git-ignored |
| 4 | `Marlin Media TV/PlayerModel.swift` (the 1f diff) | **Not committed** (step 9 not reached); built and installed |
| 6 | Temporary `Marlin Media TVUITests/Diag1iUITests.swift` (Appendix A); instrumented framework (0020 + 1h diff, device slice relinked, `PACKAGE_ONLY`), later replaced by step 3 | Harness moved out of the repo, not committed; framework replaced |
| 6 | `reports/logs/1i-analysis.txt`, `1i-clean-stargate-{back,fwd,none}.log`, `1i-instr-analysis.txt`, `1i-instr-stargate-back-full.log.gz`; `reports/screenshots/1i-*.jpg` (17, 2.0 MB) | Committed |
| 10, 12 | This report; `COLD-START.md` (pass 1e paragraph rewritten, pass 1i note) | Committed |

- **Not touched:** 0007, 0018, 0019; `DECISIONS.md`; Design/; Marlin DVR TV.
- **Constraints kept:**
  - Deployment target 26.0.
  - Device: Home Theater only, no simulator run.
  - Nothing over 10 MB committed.
  - Container paths and device identifiers redacted from committed logs.
  - Pushed: nothing.

**Lost evidence, and why.** My run loop in zsh passed an empty run tag (zsh doesn't word-split `set -- $t`). The run script then removed its scratch `runs/` folder. That deleted the instrumented run's raw JSON trace (6 MB, off-repo anyway) and seven of its nine raw screenshots. Its analysis outputs, the redacted full log and the two resume screenshots had already been saved and are committed. The clean runs came after that and are complete. The script now refuses an empty tag, a bad test name, a missing container path or an existing run folder.

## 8. Open questions

1. **The ~1 s resume error after any step.** It shows after forward steps too, so it isn't specific to back steps. Which way?
   - (a) Resume from a stepped pause as a seek to the displayed picture: flush video too. That is pass 1g's candidate C, in `es_out.c` `EsOutResumeFromNextFrame`, plus `decoder.c`'s resume-picture handling.
   - (b) Anchor the resume clock at the displayed picture's PTS instead of the first PCR read after Play.
   - (c) Accept it: ~1 s of dropped pictures and late audio at Play after stepping.
2. **Is the forward-step resume error older than 0020?** No pass ran forward steps then Play on a build without 0020 (pass 1f's forward clicks were mixed with back clicks). One run on a 0019 build would answer it.
3. **Keep 0020 in the recipe?** It's committed and in the current framework. It removes the 80–120 s read-ahead (a clear gain), but the pass didn't reach its decision.
4. **The flag is set again at Play** (`setter 0 -> 1` from the resume flush's subtitle request). While playing that's harmless, but a *later* plain pause before the next subtitle packet arrives would let the demuxer read while paused. On Stargate the next subtitle is ~80 s ahead. Not tested. Should a follow-up check pause → step → Play → pause again?
5. **VideoLAN draft (step 11)**: write it now for the need-data part alone, or after the resume question is settled?

## 9. Least-sure items

1. **The resume mechanism in §4.3** is read from trace timestamps (the anchor PCR vs the first rendered PTS), not from instrumented `EsOutResumeFromNextFrame` code in the clean build. The instrumented run's `stop_buffering … stream_start=34304001` matches it.
2. **Audio's 1 s gap** between its first decoded block (+1.3 ms, PTS 34 336) and its first render (+1 487 ms, PTS 35 336) isn't explained. It may be the audio output restarting after the flush.
3. **B1's pointer read is unsynchronised.** `decoder_frame_next_need_data` reads `p_sys->p_next_frame_es` from a decoder thread without `p_sys->lock`; taking that lock there could deadlock against the fifo lock. The write reaches the reading thread through the subtitle fifo lock in the flush paths, so the value is visible. Formally it is still a data race, and a thread sanitizer would flag it. Upstream would likely want it atomic.
4. **One run per condition, one film.**
5. **Step 5 comes from the server's metadata,** not VLC's track list on those MP4s.

## Appendix A — the temporary harness (built, run, moved out of the repo; not committed)

The same file as pass 1h's `Diag1hUITests` (pass 1h report, Appendix A), with these differences:
- the tag `p1i`;
- `openEpisode(show:season:episode:)` in place of `openMagicians()`: poster → `season.N` if needed → `episode.N.M`, reached by focus;
- a `food` case (The Food That Built America S04E02);
- pass 1f's L/R/L `exact(_:)` pattern (60 s play, 15 clicks 3.6 s apart, Play, 20 s);
- tests `t{Stargate,WonderWoman,Magicians,Divergent,Food}{Back,Fwd,None}` and `t{Stargate,Divergent}Exact`.

`run(_:_:)` is unchanged from pass 1h apart from the screenshot prefix. Run driver: `runone.sh` in `reports/logs/1i-analysis.txt`.
