# Pass 1h — why the demuxer reads while paused after a native back step (candidate B) — diagnosis — 2026-09-14

**Result.** One instrumented run on Home Theater pins candidate B:
- **The condition.** The demuxer keeps reading while paused because `next_frame_need_data` stays true. The pause gate at `input.c:668–669` then lets 22 700 of 23 073 paused evaluations demux.
- **Who sets it.** Stargate's **subtitle decoder**. The first back step's seek flushes it while paused, which gives it `frames_countdown = 1` (`decoder.c:2789–2793`). With an empty fifo it asks for data (12 288 × `decoder notify need_data=1 frames_countdown=1`).
- **Why nothing clears it.** While VLC is in frame-step mode, es_out drops every block that isn't for the stepping video stream (`es_out.c:3164–3169`). The subtitle decoder never receives a block, and only a received block clears the request (`decoder.c:2686–2687`).
- **What the steps do.** Only Play clears it (`INPUT_CONTROL_SET_STATE`). Steps 2–5 don't set it again; it is already set.
- **The reading rate.** It follows the pause-date anchor: flat out while the wakeup lies in the past (median −39 to −55 s), then 1× once the stream has caught up to wall time since that anchor. The PCR reached 134.5 s at +100 s after the pause.
- **A after B.** From this trace, A (the pause-date anchor) acted only on reads that `next_frame_need_data` licensed, so it would not be needed for the read-ahead once B is in place (§4).

**State.**
- **libvlc and Framework:** libvlc is back to clean `e50d9ac36a`, and `Frameworks/VLCKit.xcframework` is the full recipe's own build (§5).
- **App and device:** `PlayerModel.swift` is back at HEAD, and Home Theater runs that build (§6).
- **Recipe files:** `tools/vlckit-truehd/` and `DECISIONS.md` untouched.
- **Commits:** the evidence and this report are committed locally. Nothing pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Trace lines on the two demux checks, plus 1g's | **Done.** `reports/logs/1h-libvlc-demux-gate-instrumentation.diff` (`input.c`, `decoder.c`). Method in §1. |
| 2 Re-apply the 1g instrumentation and the 1f app diff (uncommitted) | **Done.** `git apply reports/logs/1g-libvlc-clock-instrumentation.diff` on the clean tree. `PlayerModel.swift` already carried the 1f diff from pass 1g, and `git apply --reverse --check` confirmed it (the working-tree diff is byte-identical to the saved file). |
| 3 Build and install on Home Theater | **Done.** 5 objects recompiled, 15 `1g:` + 8 `1h:` strings in the framework, `** TEST BUILD SUCCEEDED **`, install exit 0. |
| 4 One Stargate run | **Done**, 21:46:27–21:50:36. Pause at 00:33, 80.6 s wait, five back steps, 20 s wait, Play, 60 s. Full trace captured (app log 12.7 MB, JSON trace 19 MB). |
| 5 Answers with quotes | §2–§3 |
| 6 Candidate B detail | §4 (not implemented) |
| 7 Is A still needed with B | §4.3 |
| 8 Clean libvlc, full recipe | §5 |
| 9 PlayerModel at HEAD, build, install | §6 |

## 1. Method

**The instrumentation method (the same as 1g's).**
1. **Edit the sources.** Log-only lines in the libvlc tree at `~/vlckit-build/VLCKit/libvlc/vlc`, uncommitted in its git.
2. **Recompile only the device slice's `src/`.** `make -C src` and `make -C src install` in `build-appletvos-arm64/build` with the local GNU make 4.4.1 (`~/vlckit-build/tools/bin` on `PATH`).
3. **Relink the static lib.** `xcrun libtool -static -no_warning_for_no_symbols -filelist static-libs-list -o libvlc-full-static.a` in `build-appletvos-arm64/static-lib`, the same call as `extras/package/apple/build.sh:941–945`.
4. **Package.** `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh`.
5. **Check.** Count the tag strings in the packaged binary with `strings | grep -c`.

The simulator slices are not rebuilt. This is a diagnostic build, not the recipe's; step 8 replaces it.

**New lines (`1h:`).** Every one logs `vlc_tick_now()`.
- **Check 1** (`input.c:660–669`, the pause gate). The three inputs are captured into locals: `es_out_GetBuffering`, `master->b_eof`, `next_frame_need_data`. The logic is unchanged (`b_paused = !buffering || eof; if (b_paused && need_data) b_paused = false`). One line on every evaluation while `i_state == PAUSE_S`: `1h: check1 … -> demux_allowed=`.
- **After each demux call while paused:** the wakeup returned by `es_out_GetWakeup` and `wakeup − now` (`1h: demuxed-while-paused`).
- **The control-wait step:** the postpone condition (`es_out_GetBuffering && !eof`), the wakeup and the deadline (`1h: wait`).
- **Check 2** (`input.c:759–764`, the wakeup update after a control). Control id, `next_frame_need_data`, old and new wakeup (`1h: check2`).
- **Every writer of `next_frame_need_data`.** The `INPUT_CONTROL_NEED_DATA_FRAME_NEXT` setter (old → new). The five clears in `Control()` (logged only when it was true). Both decoder notifications in `decoder.c` (2069 true, 2687 false) with `frames_countdown`.
- **Plus 1g's 15 clock and pause lines**, unchanged.

**Run.**
- **Launch.** Console launch with pass 1e's VLCParams and `--tracer=json` into the app container.
- **Harness.** Attach-mode XCUITest `Diag1hUITests/tStargateBack` (Appendix A): Stargate Extended from the start, play 30 s, Select to pause at 00:33, wait 80.6 s, five Left clicks 4.2 s apart, wait 20 s, Select, 60 s of playback.
- **Screenshots.** `reports/screenshots/1h-stargate-back-{00-paused,05,05b-before-play,06-play+3s,07-play+60s}.jpg`: 00:33 paused, 00:33 before Play, **02:39** at Play+3 s, **03:36** at Play+60 s. The resume failure of 1g reproduces.

**Evidence.**
- **Full app log:** `reports/logs/1h-stargate-back-full.log.gz` (0.94 MB; 12.7 MB unpacked).
- **Readable excerpt:** `reports/logs/1h-stargate-back-excerpt.log` (457 KB). Every non-repetitive line and every check-1 transition, with the repetitive `1h:` runs cut to 12 + 12 lines.
- **Analyses:** `reports/logs/1h-analysis.txt`, holding every output quoted below and its scripts (`gatecheck.py`, `pacecheck.py`, `fifocheck.py`, `pcrcheck.py`, `resume60.py`, `excerpt.py`).
- **The JSON trace (19 MB)** stays off-repo.
- **Time bases.** VLC ticks in the log are µs; trace timestamps are ns (tick × 1000).

## 2. Step 5 — which condition keeps the demuxer reading, and who sets and clears it

**2.1 The condition.** Before the first step, the gate is closed:
```
[DBG] 1h: check1 now=478204584606 state=PAUSE_S es_out_GetBuffering=0 b_eof=0 next_frame_need_data=0 -> demux_allowed=0
```
From step 1 to Play it is open on every evaluation. `gatecheck.py` prints each change of the four values:
```
line 1065: GetBuffering=0 b_eof=0 need_data=0 -> demux_allowed=0   [after: 9:47:25.996 PM [player] state Paused at 33483 ms]
line 1112: GetBuffering=1 b_eof=0 need_data=1 -> demux_allowed=1   [after: 9:48:46.638 PM [player] buffering 0.0]
   … held 116 evaluations
line 1560: GetBuffering=0 b_eof=0 need_data=1 -> demux_allowed=1   [after: 9:48:46.723 PM [player] buffering 1.0]
   … held 3956 evaluations
   (steps 2–5 repeat: GetBuffering=1 for 61–67 evaluations, then GetBuffering=0 need_data=1 for 4 152 / 4 349 / 4 547 / 5 696)
totals (GetBuffering, b_eof, need_data, demux_allowed): {('0','0','0','0'): 1, ('1','0','1','1'): 372, ('0','0','1','1'): 22700}
```
`es_out_GetBuffering` is true only during each step's own ~70 ms rebuffer (372 evaluations). `b_eof` is never true. **`next_frame_need_data = 1` is the condition** for the other 22 700 evaluations (a representative one: `1h: check1 now=478285294598 state=PAUSE_S es_out_GetBuffering=0 b_eof=0 next_frame_need_data=1 -> demux_allowed=1`). Check 2 then sets the wakeup to 0 on every repeated request: `1h: check2 now=478285250384 control=35 state=PAUSE_S next_frame_need_data=1 old_wakeup=0 -> wakeup=0 wakeup-now=0`. Control 35 is `INPUT_CONTROL_NEED_DATA_FRAME_NEXT`.

**2.2 What sets it.** Step 1's seek flushes the decoders while paused, and 8 ms later a decoder with `frames_countdown=1` asks for data. The input sets the flag 15 ms after that:
```
9:48:46.634 PM [framestep] −1 gotoPreviousFrame before=33483 ms
[DBG] 1g: es_out change_position now=478285206032 paused=1 pause_date=478204561297 buffering=0 next_frame_es=0
[DBG] 1h: decoder notify need_data=1 frames_countdown=1 now=478285214055
[DBG] 1h: check2 now=478285229469 control=36 state=PAUSE_S next_frame_need_data=0 old_wakeup=478204580235 -> wakeup=0 wakeup-now=0
[DBG] 1h: INPUT_CONTROL_NEED_DATA_FRAME_NEXT 0 -> 1 now=478285229545
```
The breakdown over the whole run: `12288 1h: decoder notify need_data=1 frames_countdown=1`, `2 … 0 -> 1`, `12286 … 1 -> 1`, and **0** `need_data=0` notifications.

**Which decoder.** The notify line doesn't name its decoder, so this is established by elimination from the run's values and VLC's code:
- **Only video or subtitle decoders can hold `frames_countdown = 1`.** It is set only when a decoder is flushed while paused (`decoder.c:2791–2793`: `if( p_owner->paused && ( cat == VIDEO_ES || cat == SPU_ES ) && p_owner->frames_countdown == 0 ) p_owner->frames_countdown = 1;`). The audio decoder is excluded (paused at 0).
- **Not video.** The video decoder is in previous-frame mode (−1), and it never finds its fifo empty. `fifocheck.py`, pause → Play: `video/1  fifo queue events 11893, count min 1 max 2956 last 2956 (64799670 B) | DEMUX OUT 11893 DEC IN 79 DEC OUT 62`. The request comes from the decoder loop's empty-fifo branch (`decoder.c:2065–2070`).
- **The subtitle decoder exists in this run:** `using spu decoder module "subsdec"`, `ES track selected: 'spu/4' (fourcc: 'subt')`.

**2.3 What clears it, and why nothing does while paused.**
- **The decoder's own clear** runs when a block is queued into its empty fifo (`decoder.c:2686–2687`: `if (vlc_fifo_IsEmpty(p_owner->p_fifo) && p_owner->frames_countdown > 0) decoder_Notify(p_owner, frame_next_need_data, false);`). The subtitle decoder never receives a block while stepping, because es_out drops them (`es_out.c:3164–3169`: `/* Drop all ESes except the video one in case of next-frame */ if( p_sys->p_next_frame_es != NULL && p_sys->p_next_frame_es != es ) { block_Release( p_block ); … return VLC_SUCCESS; }`). From the trace, pause → Play:
  ```
  audio/2  fifo queue events 0 | DEMUX OUT 15459 DEC IN 0 DEC OUT 0
  spu/4    fifo queue events 0 | DEMUX OUT 5 DEC IN 0 DEC OUT 0
  ```
  Five subtitle packets were demuxed (`{'type': 'DEMUX', 'id': 'spu/4', 'stream': 'OUT', 'pts': '113414001000' …}`, once per step) and none reached the decoder.
- **The input's clears** run on `INPUT_CONTROL_SET_POSITION`, `SET_TIME`, `SET_STATE`, and title and seekpoint changes. In this run, once, at Play:
  ```
  9:49:28.212 PM [player] play (select) at 33333 ms
  [DBG] 1h: next_frame_need_data cleared by control 0 now=478326785202
  ```
  Control 0 is `INPUT_CONTROL_SET_STATE`. Play then goes through `EsOutResumeFromNextFrame`, which flushes the subtitle decoder again while es_out still counts as paused, and the flag is set again at once:
  ```
  [DBG] 1g: es_out change_position now=478326791527 paused=1 pause_date=478204561297 buffering=0 next_frame_es=1
  [DBG] 1h: decoder notify need_data=1 frames_countdown=1 now=478326791740
  [DBG] 1h: INPUT_CONTROL_NEED_DATA_FRAME_NEXT 0 -> 1 now=478326792090
  ```

**2.4 Does each back step set it again?** **No.** It is set once (step 1: `0 -> 1 now=478285229545`) and stays set through steps 2–5. The only other `0 -> 1` is the one at Play above. Steps 2–5 only repeat the request: per step, 2 258 / 2 367 / 2 460 / 3 076 notifications and **no** `0 -> 1`. Each step's own buffering also reads while `es_out_GetBuffering=1` (33 / 34 / 34 / 29 reads). Steps 2–5 needed **0** reads after their buffering ended before `previousFrameStepped`; step 1 needed 16.

## 3. Step 5 — does the reading rate follow the pause-date anchor?

**Yes.** Each step's buffering end anchors at the pause date. Offsets are from the pause (`pacecheck.py`):
```
anchor at +  80.733 s: paused=1 current_date=pause date update=+-1.318 s stream_start=33116 ms
anchor at +  84.984 s … 89.231 s … 93.463 s … 97.697 s: paused=1 current_date=pause date update=+-1.284 … -1.151 s stream_start=33116 ms
anchor at + 122.239 s: paused=0 current_date=+122.239 s update=+121.239 s stream_start=156790 ms      (Play)
```
Reads while paused, per 5 s, with the wakeup `es_out_GetWakeup` returned (`input_clock_GetWakeup` on the anchored input clock):
```
+ 80s demux calls while paused  4172  wakeup=0:   181  wakeup-now ms: min  -85066.4 median  -39389.8 max     159.8
+ 85s demux calls while paused  6027  wakeup=0:    64  wakeup-now ms: min  -89314.2 median  -55413.4 max     151.9
+ 90s demux calls while paused  6114  wakeup=0:    62  wakeup-now ms: min  -93546.1 median  -40111.6 max     159.7
+ 95s demux calls while paused  5720  wakeup=0:    60  wakeup-now ms: min  -97779.9 median  -38105.7 max     160.0
+100s demux calls while paused   232  wakeup=0:     0  wakeup-now ms: min      -7.0 median      20.7 max     156.9
+105s …115s                      ~232                    median 16.3–17.5 ms
```
The trace's demux PCR over the same buckets: `+80s 33116000..38112001`, `+85s 38171001..77494001`, `+90s 77632001..113497001`, `+95s 113530001..134496001`, `+100s 134518001..139439001` (normal from here).
- **Flat out until +100 s.** While the anchored wakeup lies up to 98 s in the past, the input doesn't wait.
- **The caught-up point is what the anchor predicts.** Stream 33.116 s is anchored at pause − 1.318 s, so wall time +100 s maps to 33.116 + 101.3 = **134.4 s**; the PCR is 134.518 s at the start of the +100 s bucket.
- **Then 1×.** The wakeup lies ~17 ms ahead, and there are 232 reads per 5 s.
- **The requests follow the reads:** `{80: 2171, 85: 3233, 90: 3267, 95: 3080, 100: 120, 105: 121, …}` notifications per 5 s.

So **whether** the demuxer reads is decided by `next_frame_need_data`; **how fast** is decided by the anchor. Reads during a step's own buffering are not paced by any anchor: 367 of those 372 had `wakeup=0`, because `EsOutGetWakeup` returns 0 while `b_buffering` (`es_out.c`, `EsOutGetWakeup`).

**3.1 Pass 1g's three least-sure points.**
1. *"Why the demuxer runs while paused"*: **settled.** It is `next_frame_need_data`, set by the subtitle decoder's request and never cleared while stepping (§2). The decoder identity is by elimination, not a logged id (§8.1).
2. *"The reading speed follows the pause-date anchor"*: **settled.** Wakeup − now, and the catch-up to 134.4 s predicted from the anchor (§3).
3. *"Frameworks/ is a hand relink"*: **settled by step 8, not by this run** (§5).

Not settled: the seek-back loop's trigger (pass 1g §9 item 3). No seek-back run was in this pass.

## 4. Step 6 — candidate B in detail (not implemented)

Lines are libvlc `e50d9ac36a`, uninstrumented.

**4.1 Where the condition lives.**

| Site | Lines | Role |
|---|---|---|
| es_out's send path | `src/input/es_out.c:3164–3169` | Drops every non-step stream's block in frame-step mode, so a subtitle or audio decoder's data request can't be met. |
| Paused flush | `src/input/decoder.c:2789–2793` | A video or subtitle decoder flushed while paused gets `frames_countdown = 1` ("display one frame/subtitle"). |
| Decoder request | `src/input/decoder.c:2065–2070` | Empty fifo and `frames_countdown > 0` → `frame_next_need_data, true`. |
| Decoder clear | `src/input/decoder.c:2686–2687` | A block queued into an empty fifo with `frames_countdown > 0` → `frame_next_need_data, false`. |
| es_out forwarding | `src/input/es_out.c:529–545` | `decoder_frame_next_need_data` pushes `INPUT_CONTROL_NEED_DATA_FRAME_NEXT` for **any** stream's decoder. |
| Input setter | `src/input/input.c:2549–2550` | `priv->next_frame_need_data = param.val.b_bool;` |
| Input clears | `src/input/input.c:2107` (`SET_POSITION`), `2131` (`SET_TIME`), `2151` (`SET_STATE`), `2355` (`SET_TITLE`/`_NEXT`/`_PREV`), `2399` (`SET_SEEKPOINT`/`_NEXT`/`_PREV`); init `287` | |
| **Readers** | `src/input/input.c:668–669` (pause gate), `760–761` (`i_wakeup = 0`) | The only two readers in VLC. |

**4.2 The possible changes.** Each is one change at one site; none is written.

| # | Change | What it does | What else reads or depends on it | Risk |
|---|---|---|---|---|
| B1 | `es_out.c:529–545`: forward the request only from the stepping stream while in frame-step mode (`if (p_sys->p_next_frame_es != NULL && id != p_sys->p_next_frame_es) return;`) | The subtitle (or any non-video) decoder's request no longer reaches the input while stepping. The video decoder's own request for a forward step is still forwarded. | The same callback serves paused seeks with no frame-step mode (`p_next_frame_es == NULL`), which stay unchanged. The input's two readers see fewer requests. | **A flag set before frame-step mode starts stays set.** For example a paused user seek's subtitle request followed by a step: nothing clears it until Play or a seek. That would need a clear on entering frame-step mode (a second line). It also relies on `p_next_frame_es` being set before the flush: `EsOutFrameNext` sets it before `vlc_input_decoder_FramePrevious`, but the step's own flush (`ES_OUT_PRIV_RESET_PCR_FRAME_PREV` → `EsOutChangePosition(p_sys, NULL)`) runs after. This wasn't traced for timing. |
| B2 | `decoder.c:2789–2793`: don't set `frames_countdown = 1` for `SPU_ES` | A paused flush no longer makes the subtitle decoder request data. | **Every** paused flush: user seek while paused, title/chapter change while paused, track changes. | After a seek while paused, the subtitle for the new position is no longer fetched and shown until Play. That is the stated purpose of the line ("display one frame/subtitle"). It also changes paused seeks outside frame stepping, including pass 1's seek-back loop, whose trigger is unknown. |
| B3 | `decoder.c:2065–2070`: request data only for `VIDEO_ES` | Same effect as B2, at the request instead of the countdown. | All subtitle decoders' next-frame handling, everywhere. | Same as B2. The subtitle decoder would also keep `frames_countdown = 1` indefinitely, so its paused-wait branch (`decoder.c:2046`, `paused && frames_countdown == 0`) is never taken, and it keeps looping on an empty fifo. Not traced. |
| B4 | `input.c:668–669` / `760–761`: stop honouring `next_frame_need_data` unless the input knows a video step is pending | The gate itself refuses reads while paused. | The two readers. **Forward frame step** (`gotoNextFrame`) past the data already queued needs this path (`vlc_input_decoder_FrameNext` → countdown > 0 → request). | The input has no field today for "video step pending", so this needs new state crossing es_out → input. It would break forward stepping at the buffer edge, and paused-seek subtitle fetch too. |
| B5 | `es_out.c:3164–3169`: let subtitle blocks through in frame-step mode | The subtitle request is met, and `decoder.c:2686–2687` clears it. | Subtitle decoding while stepping. | It clears only when a subtitle packet arrives. In this run the first came from a read ahead at PCR ~113 s, 80 s ahead, so the read-ahead is **not** prevented in films with sparse or no subtitles. Not a fix on its own. |

B1 is the narrowest: one callback, frame-step mode only. Its first risk probably needs a second line, so it isn't clearly "one contained change". A decision for you (§7).

**4.3 Step 7 — is A still needed once B is in place?** From this trace:
- **What the anchor paced.** All 22 700 anchor-paced reads were licensed only by `next_frame_need_data` (`GetBuffering=0 need_data=1 wakeup=0:0 → 22700`).
- **What it didn't.** The reads a step needs for its own rebuffer ran with `es_out_GetBuffering=1` and, for 367 of 372, `wakeup=0` (`GetBuffering=1 need_data=1 wakeup=0:1 → 367`). No anchor paces those.
- **Reads after buffering.** Steps 2–5 needed no read after their buffering ended (`reads after buffering ended and before previousFrameStepped: 0`). Step 1 needed 16, licensed by the flag.
- **At Play,** the anchor is taken at now (`anchor at + 122.239 s: paused=0 current_date=+122.239 s`).

So in this run the pause-date anchor had no observable effect other than the speed of reads that B removes. **The trace shows A isn't needed for the read-ahead once B stops those reads.**

What the trace does **not** show:
- whether step 1 still completes without its 16 extra reads
- whether Play is then correct, given the main clock's lost pause date (1g candidate D, `resume: pause_date INVALID, no delay applied` again at 478326791928)

Both need a B build on the device.

## 5. Step 8 — clean libvlc, full recipe

**Clean libvlc.**
- **Instrumentation removed.** The final instrumentation was saved (`reports/logs/1h-libvlc-instrumentation-combined.diff`), and the five files were reset with `git checkout`: `git status --short` empty at `e50d9ac36a`.
- **The recipe rewrites the hashes.** It resets to VideoLAN's pinned hash and re-applies the 19 patches with `git am` (build.log: 19 `Applying:` lines, the last `Applying: videotoolbox: dpb: do not bump ahead of the arriving picture on latency alone`). The new HEAD is therefore `51f8302c27`, committer date `Mon Sep 14 21:55:09 2026`.
- **The content is `e50d9ac36a`'s.** `git diff e50d9ac36a HEAD` is empty and both tree ids are `b92c77079914`. `e50d9ac36a` still resolves. The tree is clean after the build.

**Full recipe.** `tools/vlckit-truehd/build.sh` with no `PACKAGE_ONLY`, 21:55:08–21:58:24, exit 0.
- **Output:** `patch 0018 installed`, `patch 0019 installed`, `VLCKit.xcodeproj TVOS_DEPLOYMENT_TARGET = 26.0 (4 build configurations)`, `** ARCHIVE SUCCEEDED **` ×2, `done: …/Frameworks/VLCKit.xcframework`.
- **Compile.** The contribs were up to date. `make` recompiled what the re-applied patches touched, and the three `libvlc-full-static.a` were rewritten at 21:56 / 21:57 / 21:57. Build log grep for `error:` finds only live555's `sprintf` warning text, no errors.

**Checks on `Frameworks/VLCKit.xcframework`.**

| Slice | `MinimumOSVersion` | `LC_BUILD_VERSION` | `DTXcodeBuild` | `1g:`/`1h:` strings |
|---|---|---|---|---|
| `tvos-arm64` | 26.0 | `platform TVOS minos 26.0 sdk 27.0` | 27A266a | 0 / 0 |
| `tvos-arm64_x86_64-simulator` | 26.0 | `platform TVOSSIMULATOR minos 26.0 sdk 27.0` (×2, both architectures) | 27A266a | 0 / 0 |

- **Device slice `nm`:** `000000000236e730 S _ff_truehd_decoder`, `_ff_mlp_decoder`, `_ff_mlp_parser`.
- **Identical to the build output:** `diff -rq ~/vlckit-build/VLCKit/build/tvOS/VLCKit.xcframework Frameworks/VLCKit.xcframework` → no differences. 725 MB, git-ignored.
- **Not a hand relink.** This is the recipe's own build and replaces passes 1g/1h's hand-relinked device slice.

## 6. Step 9 — PlayerModel.swift at HEAD, build, install

- **Revert.** `git checkout -- "Marlin Media TV/PlayerModel.swift"`, then `git diff --quiet HEAD` on it (exit 0). `gotoPreviousFrame` is no longer in the file (count 0); the back step is D008's seek again.
- **Build.** `TVOS_DEPLOYMENT_TARGET = 26.0` (both configurations). `xcodebuild build … -destination 'platform=tvOS,name=Home Theater'` → `** BUILD SUCCEEDED **`. The embedded framework has 0 `1g:` / 0 `1h:` strings.
- **Install.** `xcrun devicectl device install app --device "Home Theater" …` → `App installed:` / `bundleID: com.marlin1111.marlin-media-tv`.
- **Result.** The repo and Home Theater now match: HEAD app code, the recipe's framework.
- **Not done.** No launch or playback run on this final build (the pass asks for build and install only).

## 7. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1–2 | libvlc `src/clock/clock.c`, `src/input/es_out.c`, `src/input/input.c`, `src/input/decoder.c`, `src/video_output/video_output.c` in `~/vlckit-build` (temporary) → `reports/logs/1h-libvlc-instrumentation-combined.diff` (1g + 1h), `reports/logs/1h-libvlc-demux-gate-instrumentation.diff` (`input.c` + `decoder.c` part) | Diffs committed; tree reset to `e50d9ac36a`, then rebuilt by the recipe at `51f8302c27` (same tree, §5) |
| 8 | `Frameworks/VLCKit.xcframework` (full recipe build), `~/vlckit-build` build outputs | Git-ignored / outside the repo |
| 9 | `Marlin Media TV/PlayerModel.swift` reverted to HEAD; app built and installed on Home Theater | Nothing to commit (matches HEAD) |
| 2 | `Marlin Media TV/PlayerModel.swift` (1f diff, already present) | Never committed; reverted to HEAD in step 9 |
| 3 | `Frameworks/VLCKit.xcframework` (instrumented package) | Git-ignored; replaced in step 8 |
| 4 | Temporary `Marlin Media TVUITests/Diag1hUITests.swift` (Appendix A) | Deleted; not committed |
| 4–5 | `reports/logs/1h-stargate-back-full.log.gz`, `reports/logs/1h-stargate-back-excerpt.log`, `reports/logs/1h-analysis.txt`, `reports/screenshots/1h-stargate-back-*.jpg` (5) | Committed |
| — | `COLD-START.md` (pass 1h note), this report | Committed |

Not touched: `tools/vlckit-truehd/` (0007, 0018, 0019, `build.sh`), `DECISIONS.md`, Design/, Marlin DVR TV. Deployment target 26.0. Device Home Theater only. Nothing over 10 MB committed. Pushed: nothing.

## 8. Least-sure items

1. **The requesting decoder is the subtitle decoder by elimination**: `frames_countdown=1` plus an empty fifo, from the run's values and `decoder.c:2789–2793`. The notify line doesn't carry the stream id.
2. **Why the subtitle decoder repeats its request ~3 200 times per 5 s and then ~120** is not explained. The rate tracks the demux reads, but what wakes that decoder's empty-fifo loop wasn't traced.
3. **B1's timing assumption.** That `p_next_frame_es` is set before the step's flush reaches the subtitle decoder is read from the code order, not traced.
4. **The film.** One run, one film, one subtitle track. A film with no subtitle track may never set the flag, so its read-ahead would have a different cause, or none. Wonder Woman, Magicians and Divergent were not run (the pass says Stargate only).

## 9. Open questions

1. **B1 with a clear on entering frame-step mode (two lines in one file), or B2/B3 (one line, but they change every paused seek's subtitle)?**
2. **Instrument D in the next pass?** Once B is in, whether Play resumes correctly still depends on the main clock's lost pause date (1g candidate D). Only a B build can show it: the read-ahead masks it today.
3. **A film without a subtitle track.** Should a later diagnosis check one steps back and resumes without read-ahead? Whether any title in the library lacks a subtitle track was not checked in this pass.

## Appendix A — the temporary harness (built, run, deleted; not committed)

```swift
//
//  Diag1hUITests.swift — temporary harness for pass 1h (2026-09-14). Not committed.
//  Attach mode (the app is started by `devicectl … --console` with the run's VLCParams, tracer on), from pass 1f.
//  Pass 1h run: play 30 s (to about 00:33), pause, hold ~80 s, five left clicks (native previous frame; ~4.2 s apart,
//  screenshot after each), wait ~20 s still paused, Play, 60 s of playback (screenshots at +3 s and +60 s), Menu.
//

import XCTest

final class Diag1hUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]

    override func setUp() { continueAfterFailure = true }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func note(_ t: String) { let a = XCTAttachment(string: t); a.name = "note"; a.lifetime = .keepAlways; add(a); NSLog("[p1h] %@", t) }
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
        shot("p1h-\(tag)-00-paused")
        sleep(77)
        for n in 1...5 {
            switch kind {
            case "back": note("\(tag): click \(n) L at \(stamp())"); remote.press(.left)
            case "fwd": note("\(tag): click \(n) R at \(stamp())"); remote.press(.right)
            default: note("\(tag): hold \(n) at \(stamp())")
            }
            sleep(3)
            shot(String(format: "p1h-\(tag)-%02d", n))
            usleep(600_000)
        }
        note("\(tag): wait after steps from \(stamp())")
        sleep(20)
        shot("p1h-\(tag)-05b-before-play")
        note("\(tag): play at \(stamp())")
        press(.select, wait: 3)
        shot("p1h-\(tag)-06-play+3s")
        sleep(56)
        press(.up, wait: 1)
        shot("p1h-\(tag)-07-play+60s")
        note("\(tag): play+60s shot at \(stamp()), player exists \(app.otherElements["player"].exists)")
        press(.down, wait: 1)
        press(.menu, wait: 3)
    }

    func t0_AttachAndPlay() { attach(); openMagicians(); XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20)); sleep(20); press(.menu, wait: 3) }
    func tStargateBack() { run("stargate", "back") }
}
```
