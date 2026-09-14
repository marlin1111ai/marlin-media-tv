# Diagnosis 4: Wonder Woman judder — where the lateness is born — 2026-09-14

Read-only pass for the committed app: no app code, project setting or VLCKit build changed; nothing installed on the Mac. Temporary experiment harness `Marlin Media TVUITests/Diag4UITests.swift` (VLC options passed only as the `VLCParams` launch argument of each run) was deleted before this report (Appendix A). Build under test: HEAD `4086761` (pass 1d), app dylib 13:34 today, unchanged. Device: Home Theater only (5(e) withdrawn — §7). Evidence: `reports/logs/d4-*.log` (app + VLC logs per run), `reports/logs/d4-analysis-output.txt` (every analysis output quoted here); the JSON traces stay off-repo (Wonder Woman traced 99 MB / 759 404 lines, Divergent 14 MB / 122 790, (a) 99 MB / 761 320, (c) 99 MB / 759 382, (d) 6.2 MB / 54 116).

## 1. Push
- `git status` clean on `main`; `git push -u origin main` → `* [new branch] main -> main`, `branch 'main' set up to track 'origin/main'`.
- `git fetch origin`: local `4086761152f6dce89931f3108e6eab2bf97db079` = origin/main `4086761152f6dce89931f3108e6eab2bf97db079`.
- Largest tracked files (`git ls-files -z | xargs -0 du -h | sort -h | tail`): 796 K `reports/logs/stargate-both-editions-vlckit.log` is the biggest; nothing over 10 MB (`du -k … | awk '$1>10240'` empty); `.git` 11 M.
- Identifiers: the devicectl identifier and hardware UDID of all three paired devices grepped in the tree (`git grep`) and in full history (`git log --all -p`): 0 hits each. `udid|ecid` case-insensitive hits are only "de**cid**ed" and "Codec**Id**".

## Finding, first (item 6 in one paragraph at §6)

**Named cause (confirmed): VLC's VideoToolbox reorder buffer releases the next mini-GOP's anchor before the last B-picture of the current mini-GOP, and the video output then discards that B-picture as one frame late.** It is a picture-*order* defect in `modules/codec/videotoolbox/dpb.c`, triggered by Wonder Woman's SPS (`sps_max_latency_increase_plus1` = 2 → VLC `max_latency_pics` = 4) and not by Divergent's (5 → 6). It is not decode speed (the dropped pictures leave the decoder 234–442 ms early), not the network (10 s caching: no change; no input dip), not audio (no audio track: no change) and not the display (pass 1d: 24 Hz and 60 Hz identical).

What confirms it, each from a log or a run:
1. **The pictures the vout drops are exactly the pictures the decoder releases out of order.** Traced run (`reports/logs/d4-ww-traced.log`, 99 MB JSON trace off-repo): the decoder's output (`DEC OUT` events) steps backwards in PTS **642** times; the vout drops **642** pictures `too late` (tracer `toolate` events = file-log lines = 642). Each backward step is exactly one frame (`[(1, 642)]`), and the earlier picture follows the later one by 166 ms median (p95 171).
2. **Always the same slot.** The late-released picture sits at display position 4, 9, 14 or 19 after the IDR (162 + 148 + 138 + 128 = 576 of 642 in the 124 standard 24-picture GOPs, exactly 4.00 per GOP; the other 66 fall in the 20-odd GOPs of other shapes around scene changes, and every one of them is also predicted by the simulation in point 3), and the picture released before it is 5, 10, 15 or 20 — the anchor of the next mini-GOP. In decode order the GOP is `0, 5,3,2,1,4, 10,8,7,6,9, 15,13,12,11,14, 20,18,17,16,19, 23,22,21`: the dropped picture is the last B of each five-picture mini-GOP.
3. **A simulation of VLC's own DPB code, fed the file's pictures strictly in decode order, reproduces the drops picture for picture.** `dpbsim.py` implements `DPBOutputAndRemoval` / `BumpDPB` / `InsertIntoDPB` as coded (latency increment for entries with a higher POC, then bump on fullness ≥ 5, reorder > 3, latency ≥ 4, then insert the current picture). Over the PTS range of the device run it releases 642 pictures after a later-PTS picture; **all 642 are the 642 the device dropped; the simulation predicts no other** (`in both 642 | device only 7 | simulation only 0`; the 7 device-only are the last pictures decoded before exit, PTS 191 566–191 817 ms, not `toolate`). No timing, pool or VideoToolbox behaviour enters the simulation, so the misorder is deterministic for this stream.
4. **The ordering of one step is what causes it.** With the same stream, limits and code, doing the insert of the current picture before the latency increment and the latency bump gives **0** backward releases on Wonder Woman (`dpbsim-order.py`: `vlc (869, 5995)` → `after (0, 5995)`; Divergent `0` both ways).
5. **The trigger is the stream's SPS, parsed from each file's `hvcC`** (`sps.py`): Wonder Woman `dec_pic_buffering_minus1=4 num_reorder_pics=3 latency_increase_plus1=2` → VLC `max_dec_pic_buffering=5 max_num_reorder=3 max_latency_pics=4`; Divergent `4 / 2 / 5` → `5 / 2 / 6`. Both have one sub-layer.

The step, traced by `dpbstep.py` through the first standard GOP after 5 s (VLC's order: latency +1 for waiting pictures with a higher POC, then bump, then insert; POC = display index after the IDR; limits 5 / 3 / 4):

| Arrives (POC) | Waiting before, POC:latency after increment | Released by the bump (reason) | Stored after insert |
|---|---|---|---|
| 0 | — | — | 0 |
| 5 | 0:0 | — | 0 5 |
| 3 | 0:0 5:1 | — | 0 3 5 |
| 2 | 0:0 3:1 5:2 | — | 0 2 3 5 |
| 1 | 0:0 2:1 3:2 5:3 | 0 (reorder > 3) | 1 2 3 5 |
| 4 | 1:0 2:1 3:2 5:4 | 1 (reorder > 3), 2 (latency ≥ 4), 3 (latency ≥ 4), 5 (latency ≥ 4) | 4 |
| 10 | 4:0 | — | 4 10 |
| 8 | 4:0 10:1 | — | 4 8 10 |
| 7 | 4:0 8:1 10:2 | — | 4 7 8 10 |
| 6 | 4:0 7:1 8:2 10:3 | 4 (reorder > 3) | 6 7 8 10 |
| 9 | 6:0 7:1 8:2 10:4 | 6 (reorder > 3), 7 (latency ≥ 4), 8 (latency ≥ 4), 10 (latency ≥ 4) | 9 |
| 15 | 9:0 | — | 9 15 |
| 13 | 9:0 15:1 | — | 9 13 15 |
| 12 | 9:0 13:1 15:2 | — | 9 12 13 15 |
| 11 | 9:0 12:1 13:2 15:3 | 9 (reorder > 3) | 11 12 13 15 |
| 14 | 11:0 12:1 13:2 15:4 | 11 (reorder > 3), 12 (latency ≥ 4), 13 (latency ≥ 4), 15 (latency ≥ 4) | 14 |
| 20 | 14:0 | — | 14 20 |
| 18 | 14:0 20:1 | — | 14 18 20 |
| 17 | 14:0 18:1 20:2 | — | 14 17 18 20 |
| 16 | 14:0 17:1 18:2 20:3 | 14 (reorder > 3) | 16 17 18 20 |
| 19 | 16:0 17:1 18:2 20:4 | 16 (reorder > 3), 17 (latency ≥ 4), 18 (latency ≥ 4), 20 (latency ≥ 4) | 19 |
| 23 | 19:0 | — | 19 23 |
| 22 | 19:0 23:1 | — | 19 22 23 |
| 21 | 19:0 22:1 23:2 | — | 19 21 22 23 |

Release order within the GOP: [0, 1, 2, 3, 5, 4, 6, 7, 8, 10, 9, 11, 12, 13, 15, 14, 16, 17, 18, 20] — 5 before 4, 10 before 9, 15 before 14, 20 before 19; the last mini-GOP (23, 22, 21: depth 2) never reaches latency 4. The device trace shows the same bursts: e.g. 6, 7, 8, 10 released in the same millisecond, 9 156 ms later (`d4-analysis-output.txt`, `out-ww-order`).

At the vout (`src/video_output/video_output.c:1063-1115`, `1016-1038`): pictures are taken from the decoder FIFO in arrival order; 5 is displayed at its time, then 4 is popped with a display time one frame period earlier, `late = render/filter high − (system_pts − now)` exceeds the frame duration (41.7 ms) and it is released with `picture is too late to be displayed (missing 43–54 ms)` — median 48 ms = one frame period + ~6 ms render cost. No picture is ever shown late; the decoder never drops.
## 2. Where the lateness is born — per-picture timeline (item 2)

Tracer events used (VLC 4 JSON tracer, one line per event, `Timestamp` = `vlc_tick_now()` in ns): `DEMUX OUT` (`es_out.c:3122`, per packet, pts/dts), `DEC IN` (`decoder.c:1792`, before `pf_decode`, pts/dts), `DEC OUT` (`decoder.c:1572`, `ModuleThread_QueueVideo`, i.e. after VLC's VT reorder buffer), `RENDER … mode realtime` (`clock.c:202`, `vlc_clock_UpdateVideo` after `vout_display_Display`, pts + `render_ts`), `RENDER event toolate` (`video_output.c:1033`), `RENDER event late` (`:1474`), decoder input FIFO depth (`decoder.c:2698`), input clock `buffering` (`es_out.c:3643`). "Display time" of a picture = its PTS mapped through the render clock (median `render_ts − pts` of its neighbours); the vout's own "late" decision is against the same main clock (audio master: `using clock source: 'audio'`).

| 3-minute traced run | Wonder Woman (`d4-ww-traced.log`, 14:53) | Divergent (`d4-divergent-traced.log`, 14:57) |
|---|---|---|
| Pictures demuxed / fed to decoder / out of decoder / rendered | 4 625 / 4 605 / 4 600 / 3 951 | 4 625 / 4 601 / 4 597 / 4 589 |
| `toolate` (vout drop) / `late` (shown late) | **642** / 0 | 0 / 0 |
| Late by (file log `missing N ms`) median / p95 / min / max | 48 / 50 / 43 / 54 ms | — |
| Decoder in → out (DEC IN → DEC OUT) median / p95 / max | 172 / 220 / 377 ms (dropped pictures: 214 / 219 / 374) | 134 / 334 / 474 ms |
| DEC OUT ahead of its display time, rendered pictures | median 365 ms early; 95 % at least 320 ms early; least early 163 ms, most 649 ms | median 366 ms early; 95 % at least 363 ms early; least early 163 ms, most 551 ms |
| DEC OUT ahead of its display time, **dropped** pictures | median 281 ms early; 95 % at least 278 ms early; least early 234 ms, most 442 ms — never late out of the decoder | — |
| Against which clock the drop is decided | vout main clock (audio master), `IsPictureLateToStaticFilter` → threshold = frame duration 41.7 ms (`video_output.c:1016-1038`) | same |
| Clustering of dropped pictures | display position 4/9/14/19 after IDR (576 of 767 such slots; 4.00 per standard 24-picture GOP), all reference pictures (`TRAIL_R`; the file has no non-reference pictures), each released one frame after its successor; spacing 5 frames (434 pairs) or 9 (128, across the depth-2 end of a GOP) | none |
| Keyframes / B / reorder boundary | not after keyframes (position 0–3: 0 drops); on the deepest B of each depth-3 mini-GOP; exactly at the reorder boundary | — |
| Vout render time | not traced by this VLC (`chrono.render` is internal); the 48 ms median lateness = 41.7 ms frame + ~6 ms is the only proxy | — |

Distribution of the per-minute drop count in the traced run: 153 / 230 / 246 (anchors at 61.9 / 62.9 / 62.9 s), identical to four untraced runs (§5), so the ~100 MB trace did not perturb playback.

## 3. Decoder output cadence (item 3)

| | Wonder Woman | Divergent |
|---|---|---|
| Pictures out of the decoder per wall-clock second, median / p95 / min / max | 24 / 26 / 20 / 28 (134 of 188 s at exactly 24) | 24 / 24 / 22 / 26 (174 of 188 s at 24) |
| Gap between successive DEC OUT, median / p95 / max | **0.1** / 168 / 324 ms; 890 gaps > 80 ms, 2 489 < 5 ms | **41.9** / 46.1 / 219.7 ms; 33 gaps > 80 ms |
| Burst then gap? | **yes**: the bumping in §1 releases up to four pictures at once when the last B arrives, then nothing for ~160 ms | no |
| Out-of-display-order releases | 642 | 0 |
| Pictures held between DEC IN and DEC OUT (VT in flight + VLC DPB) | 3–8 (mode 6); 3 at 625 of the 642 misordered releases | — (not computed separately) |
| Pictures queued in the vout (decoded − rendered − dropped), sampled 1/s | median 8, max 11 | median 9, max 11 |
| SPS reorder depth (`num_reorder_pics`) | 3 | 2 |

Does the lateness equal one reorder slot? It equals **one picture position**: every misordered picture is released exactly one frame after its successor (`[(1, 642)]`), and the vout rejects it by one frame period plus render cost (48 ms median). The depth-3 vs depth-2 difference from diag3 matters only through the latency limit: with reorder 3 and `latency_increase_plus1` 2 the latency limit (4) equals the number of pictures that follow each anchor in decode order within a mini-GOP (3, 2, 1, 4), so the anchor hits the limit on the arrival of the fourth — before that fourth picture is stored. Measured over 250 s of each file with VLC's step order (`maxlatency.py`): a waiting picture's latency count reaches 4 on 869 arrivals in Wonder Woman — its limit, and the same 869 arrivals that misorder — and also peaks at 4 in Divergent (1 145 arrivals), where the limit is 6, so it is never reached.

## 4. Input side (item 4)

| | Wonder Woman | Divergent |
|---|---|---|
| Video bits demuxed per second (block sizes from the file × DEMUX OUT times), median / p95 / max | 32.7 / 69.3 / 76.8 Mbit/s (file average 55.2 Mbit/s including audio, diag3) | 9.4 / 19.6 / 23.5 Mbit/s |
| Demux lead (display time − DEMUX OUT), median / p95 / min | 1.4 / 1.6 / 0.2 s | 1.4 / 1.6 / 0.2 s |
| DEMUX OUT → DEC IN, median / p95 / max | 894 / 964 / 1 009 ms | 946 / 992 / 1 004 ms |
| Decoder input FIFO, packets median / p95 / max (MB median / max) | 22 / 23 / 25 (3.7 / 9.7) | 23 / 24 / 25 (1.1 / 3.2) |
| Input clock `buffering` (es_out, per PCR), median / p95 / min / max | 1 142 / 1 187 / 994 / 1 951 ms | 1 137 / 1 264 / 1 000 / 1 967 ms |
| Stream cache (prefetch, 16 MiB) fill | not observable: `prefetch` logs only `using 16777216 bytes buffer` and `Stream buffering done (1000 ms in 48 ms)`; its fill level is a commented-out debug line (`prefetch.c:261`) | same |
| Decoder input FIFO after the first 5 s, min / median | 20 / 22 packets (never below 20 in 4 478 samples) | 21 / 23 (4 476 samples) |
| Demux lead after the first 5 s, min / median | 1.25 / 1.42 s | 1.31 / 1.45 s |
| At the 625 `toolate` events after 5 s vs at rendered pictures | FIFO min 22, median 23 · lead min 1.26 s, median 1.41 s — vs rendered: FIFO median 23 · lead 1.42 s: **no late picture coincides with an input dip** | — |

## 5. Experiments (item 5) — Wonder Woman, TrueHD track, Home Theater, 3 minutes each, same build; reverted = options exist only in the launch arguments of that run

Counts are the vout's own lines between the app's stamped per-minute anchors (`picture is too late to be displayed` = dropped, `picture displayed late` = shown late); "misordered" = backward steps in the decoder's output order from the tracer.

| Run (time) | Change (how applied, and the log line proving it applied) | Dropped per minute (min 1 incl. start / 2 / 3) | Shown late per minute | Missing ms median / p95 / min / max | Misordered | Result |
|---|---|---|---|---|---|---|
| Baseline, traced (14:53) | `--tracer=json --json-tracer-file=…/Library/Caches/…` (trace 759 404 lines) | 153 / 230 / 246 | 0 / 0 / 0 | 48 / 50 / 43 / 54 | 642 | reference |
| Baseline, untraced (14:28) | none effective (`--tracer=json_tracer`: no such module) | 151 / 230 / 248 | 0 | 48 / 51 / 44 / 53 | — | same as traced |
| **(a)** late tolerance (15:02) | `--no-drop-late-frames` (`drop-late-frames`, `video_output.c:2270`: this build has no numeric tolerance — the threshold is the frame duration, `:1024-1029`); proof: 0 `too late` lines, 642 `displayed late` lines | **0 / 0 / 0** | **152 / 231 / 246** | 47 / 49 / 41 / 55 (displayed-late lines, n=642) | **642** | drops become the same pictures shown one frame late — out of order on screen; misorder unchanged |
| **(b)** network caching 10 s (14:23) | `--network-caching=10000`; proof: `Stream buffering done (10017 ms in 583 ms)` (baseline `1000 ms`) | 150 / 231 / 247 | 0 | 48 / 51 / 44 / 53 | not traced | no change |
| **(c)** chroma not x420 (15:07) | `--videotoolbox-cvpx-chroma=420v` (8-bit bi-planar instead of the 10-bit `x420` VLC picks for Main 10); proof: `forcing output chroma (kCVPixelFormatType): 420v` and `output chroma (kCVPixelFormatType): 420v` (baseline `x420`) | 152 / 231 / 246 | 0 / 0 / 0 | 47 / 50 / 42 / 51 | 642 | no change |
| **(d)** audio disabled (15:11) | `--no-audio`; proof: no `codec (truehd)`, no audio decoder, no `Output on HDMI` line in the log and 0 audio events in the trace (54 116 lines, all video/input) | 153 / 231 / 245 | 0 / 0 / 0 | 49 / 51 / 45 / 56 | 642 | no change — the audio path is not involved |
| (e) Master Bedroom Apple TV | withdrawn by the owner mid-pass — §7 | — | — | — | — | not tested |
## 6. Differential (item 6)

**On Wonder Woman, VLC's VideoToolbox reorder buffer (`dpb.c`) outputs each depth-3 mini-GOP's anchor before its last B-picture — because it applies the latency bump before storing the arriving picture, and this stream's SPS latency limit (4) is reached exactly on that picture — so the vout receives four of every 24 pictures one position out of order and drops each as one frame late. Divergent's SPS gives a latency limit of 6 that its mini-GOPs never reach, so its order is never broken.** Decode speed, input, audio and display are the same on both and are not involved: the dropped pictures leave the decoder 234–442 ms before their display time, and a timing-free simulation of the same code reproduces all 642 drops.

## 7. What could not be tested

- **Experiment 5(e), the Master Bedroom Apple TV:** withdrawn by the owner during the pass. Before the change arrived the app had been installed there (14:33) and a run started (14:33:47, playback from 14:34:20); it was stopped after its minute-2 anchor (14:36:25). No log was copied from that device and no number from it is used. The app is still installed there and may have been left on screen — not touched further (question 1).
- **Files the experiments left on Home Theater** (app data container, listed with `devicectl device info files` after the last run): `Library/Caches/vlc-trace-ww-trace.json` 87.9 MB, `…-div-trace.json` 14.4 MB, `…-ww-nodroplate.json` 88.2 MB, `…-ww-420v.json` 87.9 MB, `…-ww-noaudio.json` 6.2 MB (284.6 MB together), and the empty `Library/Logs/vlc-log.json` created by `devicectl device copy to` for the first tracer attempt. devicectl can copy into and out of the container but not delete a file; they go with an app uninstall or when tvOS purges Caches. Not removed (question 4).
- **VideoToolbox callback order and VT-internal decode time:** not traced by this VLC (`DecoderCallback` has no tracer event); `DEC IN` is stamped before `pic_pacer_WaitAllocatableSlot` blocks, so DEC IN → DEC OUT includes pacer wait and the DPB hold. The simulation makes the callback order unnecessary for the conclusion.
- **Vout render time per picture** (`chrono.render` is not traced) and the stream cache fill level (not logged).
- **The fix itself** (reordering the insert and latency bump in `dpb.c`) needs a VLCKit rebuild — out of scope; the counter-simulation is the only evidence for it.
- **The default tracer path** fails on tvOS (`Library/Logs/vlc-log.json`: `Operation not permitted`; `/dev/stderr`: `Operation not permitted`); the working method is in §9.
- The first traced-launch attempts (`--tracer=json` with the default path, `--tracer=json_tracer`, a stale absolute path, `/dev/stderr`) produced no trace; each of those runs is an untraced run in §5. The app log of the first one (14:18) was overwritten by a later copy before it was saved; its per-minute counts (153 / 230 / 246, missing 43–52 ms) were printed in the session before that and are the only record.

## 8. Questions for the owner

1. The Master Bedroom Apple TV still has Marlin Media TV installed (installed 14:33 today before 5(e) was withdrawn), and the stopped run may have left the app on screen. Do you want it uninstalled from here (`devicectl device uninstall app`), or will you remove it yourself?
2. Fix pass: the candidate change is in VLC's `modules/codec/videotoolbox/decoder.c` `OnDecodedFrame` / `dpb.c` `DPBOutputAndRemoval` — store the arriving picture before the latency increment and the latency bump. Its only evidence so far is the counter-simulation (§1 point 4); its size and any side effect on H.264 (which shares the DPB code) are not assessed. It would be VLCKit patch 0019 through the same recipe as D015. Do you want that pass, and should it also carry an upstream report to VideoLAN?
3. Until a patched VLCKit exists, nothing tried here removes the defect without a rebuild: raising the late tolerance only shows the same pictures out of order (experiment a) and 10 s of caching changes nothing (b); 8-bit decoder output instead of 10-bit changes nothing (c), and neither does playing with no audio at all (d). Do you want to wait for the patch, or also test a re-encode of Wonder Woman with a different GOP structure (e.g. reorder depth 2) as a stop-gap?
4. The experiment traces (284.6 MB in `Library/Caches`) and the empty `Library/Logs/vlc-log.json` remain in the app's container on Home Theater. Leave them for tvOS to purge, or should a later pass uninstall and reinstall the app to clear them?

## 9. Method

1. **Harness** (Appendix A): the pass-1d/diag3 navigation helpers and per-minute anchor (subtitle panel opened, photographed, closed with "Off" → stamped `[subtitles] panel opened` lines), 3-minute watch. Built with `xcodebuild build-for-testing … -destination 'platform=tvOS,name=Home Theater'` (`TEST BUILD SUCCEEDED`; the app product was not rebuilt, dylib still 13:34).
2. **VLC options without an app change:** VLCKit uses the `VLCParams` user default as its whole default option list (`Sources/Core/VLCLibrary.m` `_defaultOptions`); each run passed `-VLCParams '(<VLCKit's eight tvOS defaults>, <run options>)'` in the argument domain. Proven on the device by `Stream buffering done (10017 ms …)` for `--network-caching=10000`, by 0 `too late` / 642 `displayed late` for `--no-drop-late-frames`, and by the tracer file itself.
3. **Getting a trace on tvOS** (four failed attempts, each kept as an untraced run): `--tracer=json` with the default path → `error opening log file '<container>/Library/Logs/vlc-log.json': Operation not permitted` (seen only on stderr, via `devicectl device process launch --console`, because libvlc creates the tracer before the app installs its loggers); `--tracer=json_tracer` → no module (the static build names it `json`); an absolute `Library/Caches` path → `No such file or directory` (the container path changes when xcodebuild reinstalls the app); `/dev/stderr` → `Operation not permitted`. Working method: a console launch with the default path to read the current container path from libvlc's own `opening logfile` line; then, without rebuilding, `devicectl device process launch --console --terminate-existing … -VLCParams '(…, "--tracer=json", "--json-tracer-file=<container>/Library/Caches/vlc-trace-<run>.json", …)'`, the harness attaching with `XCUIApplication().activate()` (tests `tA_*`), and `devicectl device copy from … Library/Caches/vlc-trace-<run>.json` afterwards. The container path is not written anywhere in this report or the logs.
4. **Per-picture file facts:** `mkvframes.py` streamed each MKV's first 250 s from the server and listed every video block in decode order (timecode, size, keyframe flag, first VCL NAL type, temporal id; 5 995 blocks each). `sps.py` parsed each file's SPS from the `hvcC` CodecPrivate up to the `sps_max_*` loop.
5. **Analysis** (outputs verbatim in `reports/logs/d4-analysis-output.txt`): `analyze.py` (timeline, latencies, clustering, cadence, input side), `order.py` (backward releases), `inputdips.py`, `shapes.py`, `perminute.py` (vout lines between anchors), `dpbsim.py` / `dpbsim-order.py` / `dpbstep.py` (VLC's `dpb.c` bumping over the file's decode order; the second with the insert moved before the latency bump), `simcheck.py` (simulated vs device-dropped pictures), `maxlatency.py` (highest DPB latency count reached per file). Tracer PTS were matched to the file by `round((pts_ns/1000 − 1)/1000)` ms (VLC_TICK_0 = 1).
6. **Source references** are to `~/vlckit-build/VLCKit` (VLCKit 4.0.0-a24 + libvlc master 5dd4aebda + the 18 patches, the tree of the framework under test).
7. **Scope note:** a first version of this pass installed the app on the Master Bedroom Apple TV and started a run there (item 5(e) as first written); stopped on the owner's change, nothing used (§7).

## Appendix A — the temporary harness (deleted after the runs; not committed)

```swift
//
//  Diag4UITests.swift — temporary harness for diagnosis 4 (2026-09-14, Wonder Woman judder). Not committed.
//  Built from the diag3 appendix (same navigation and per-minute subtitle-panel anchor). Each test launches the
//  app with VLCKit's `VLCParams` user default in the argument domain: VLCKit's tvOS default option list
//  (VLCLibrary.m _defaultOptions) plus the run's extra libvlc options (JSON tracer, drop-late, caching, chroma,
//  no-audio). The committed app is not changed.
//

import XCTest

final class Diag4UITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]
    private let vlckitDefaults = ["--no-color", "--no-osd", "--no-video-title-show", "--no-snapshot-preview",
                                  "--http-reconnect", "--text-renderer=freetype", "--avi-index=3", "--audio-resampler=soxr"]

    override func setUp() { continueAfterFailure = true }

    private func launch(_ extra: [String]) {
        app = XCUIApplication()
        let list = (vlckitDefaults + extra).map { "\"\($0)\"" }.joined(separator: ",")
        app.launchArguments = ["-VLCParams", "(\(list))"]
        app.launch()
        note("launched with VLCParams (\(list)) at \(stamp())")
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func note(_ t: String) { let a = XCTAttachment(string: t); a.name = "note"; a.lifetime = .keepAlways; add(a); NSLog("[diag4] %@", t) }
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

    /// Minute anchor (diag3): subtitle panel opened, photographed, closed with its "Off" row → stamped app log lines.
    private func anchor(_ tag: String, _ m: Int) {
        press(.up, wait: 1); press(.up, wait: 1); press(.right, wait: 1); press(.select, wait: 1)
        shot("d4-\(tag)-min\(m)")
        note("\(tag): minute \(m) anchor at \(stamp())")
        press(.select, wait: 1); press(.down, wait: 1)
    }

    private func watch(_ tag: String, minutes: Int = 3) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(stamp())")
        for m in 1...minutes {
            sleep(55)
            anchor(tag, m)
            if !app.otherElements["player"].exists { note("\(tag): player gone at minute \(m)"); break }
        }
        press(.menu, wait: 3)
    }

    private func ww(_ tag: String, _ extra: [String]) { launch(extra); openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); watch(tag) }
    /// The app container (read from libvlc's console line in this session; uncommitted harness only). Library/Logs
    /// pre-created by devicectl is not openable by the app ("Operation not permitted"); Library/Caches is.
    private let container = "<app container path, redacted>"
    private func tracer(_ tag: String) -> [String] { ["--tracer=json", "--json-tracer-file=\(container)/Library/Caches/vlc-trace-\(tag).json"] }

    func t1_WonderWomanTraced()      { ww("ww-trace", tracer("ww-trace")) }
    func t2_DivergentTraced()        { launch(tracer("div-trace")); openPoster("poster.Divergent", tab: "Movies"); pressPlay(); watch("div-trace") }
    func t3_WonderWomanNoTracer()    { ww("ww-notrace", []) }
    func t4_WonderWomanNoDropLate()  { ww("ww-nodroplate", tracer("ww-nodroplate") + ["--no-drop-late-frames"]) }
    func t5_WonderWomanCaching()     { ww("ww-caching", tracer("ww-caching") + ["--network-caching=10000"]) }
    func t6_WonderWomanChroma420v()  { ww("ww-420v", tracer("ww-420v") + ["--videotoolbox-cvpx-chroma=420v"]) }
    func t7_WonderWomanNoAudio()     { ww("ww-noaudio", tracer("ww-noaudio") + ["--no-audio"]) }

    /// Attaches to an app already launched by `devicectl process launch --console` (its stderr shows libvlc's
    /// messages from before the app installs its loggers, e.g. the tracer's file-open result) and plays 20 s.
    func t0_AttachAndPlayWonderWoman() {
        app = XCUIApplication(); app.activate()
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
        openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear")
        sleep(20); press(.menu, wait: 3)
    }

    /// Attach variants (the app is launched beforehand by `devicectl process launch --console` with the run's
    /// VLCParams and `--json-tracer-file=/dev/stderr`: an absolute container path does not survive the reinstall
    /// each xcodebuild test run performs). Same navigation, anchors and 3-minute watch as above.
    private func attach() {
        app = XCUIApplication(); app.activate()
        note("attached at \(stamp())")
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
    }
    func tA_WonderWoman() { attach(); openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); watch("attach-ww") }
    func tA_Divergent()   { attach(); openPoster("poster.Divergent", tab: "Movies"); pressPlay(); watch("attach-div") }
}
```
