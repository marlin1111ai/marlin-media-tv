# Marlin Media TV — decisions

The standing calls for the tvOS client. Newest at the bottom. Each carries its date; a
superseded decision stays in place with a note. The server's own decisions live in
marlin1111ai/marlin-media (DECISIONS.md there) and are referenced by their numbers.

## 2026-09-13 — pass 1

- **D001** own repo marlin1111ai/marlin-media-tv, folder ~/Xcode/Marlin Media TV, notebook at root — supersedes marlin-media D007/D010.
- **D002** Claude Code runs on the Mac.
- **D003** VLCKit via VideoLAN SPM 4.0.0-a24; fallback if the alpha fails is CocoaPods 3.7.3.
- **D004** minimum tvOS 26.0.
- **D005** dev/test device is Home Theater.
- **D006** all UI from Claude Design exports (carries marlin-media D009).
- **D007** server address fixed, no settings screen.
- **D008** skips −10 s / +30 s while playing; frame step on click while paused, forward exact, back approximate (carries marlin-media D005). **Superseded in part 2026-09-14 (pass 1k):** the back step is VLC's native previous-frame, exact — D008 (revised) under pass 1k.
- **D009** resume/watched state and Recently Added are in — server request sent 2026-09-13, client wires them once served.
- **D010** sort control: Title, Year, Recently Added.
- **D011** device-proof: VLCKit logs + device screenshot from builder, HDR indicator and Denon panel from owner.
- **D012** custom VLCKit build with the TrueHD decoder compiled in — supersedes playing a TrueHD title on its AC-3 core. Reason: 7.1 PCM to the Denon. VLCKit 4.0.0-a24 from VideoLAN's own scripts, one change: the hunk of VLCKit's patch 0007 that disables ffmpeg's mlp decoder/demuxer/parser is removed (`tools/vlckit-truehd/0007-truehd-enable.diff`).
- **D013** the built framework stays out of git at `Frameworks/VLCKit.xcframework` (ignored; 716 MB); it is built at `~/vlckit-build` because VideoLAN's scripts cannot take spaces in paths, with a local GNU make 4.4.1 (`~/vlckit-build/tools`, passed as `VLC_PATH`) and python.org Python 3.14.7; recipe in `tools/vlckit-truehd/`; NAS backup of the framework is separate and the owner's.

## 2026-09-14 — pass 1c

- **D014** trusted Matroska cues on seek: the player adds the media option `:demux=mkv_trusted` to every `.mkv` stream (`PlayerModel.swift`, `attach(drawable:)`) and nothing else. Reason: the HTTP access is not fast-seekable, so VLC's default `mkv` demuxer files the file's Cues as untrusted and never verifies them; every forward seek then prerolls from the last keyframe it has read (Divergent, Wonder Woman) or from the first cluster (Stargate, whose MPEG-2 sits in BlockGroups) — 8–51 s of frozen picture after ten +30 s skips (`reports/2026-09-14-diag2-seek.md`). `mkv_trusted` is the same demuxer with `trust_cues = true`, so a seek lands on the cue before the target: 0.09–0.55 s to picture in the same runs (`reports/2026-09-14-pass1c-mkv-seek.md`). MKV only, decided by the server path's `.mkv` suffix; the MP4 path is untouched.

## 2026-09-14 — pass 1d

- **D015** TrueHD/MLP block coalescing in VLCKit: `tools/vlckit-truehd/0018-avcodec-audio-coalesce-TrueHD-MLP-frames.patch` (a libvlc patch in VLCKit's own patch format, installed by `build.sh`) makes `modules/codec/avcodec/audio.c` gather the decoder's 40-sample TrueHD/MLP frames into ~20 ms blocks (960 samples at 48 kHz; whole frames, PTS of the first, summed length) before `decoder_QueueAudio`, gated on `AV_CODEC_ID_TRUEHD` / `AV_CODEC_ID_MLP`; DTS, AC-3, AAC and every other codec are untouched. Where: the decoder module is the narrowest codec-specific point — the packetizer must stay one access unit per block for FFmpeg, and the Apple output makes one CMSampleBuffer per block for every codec. Why: with 40-sample blocks the tvOS renderer received 1 200 sample buffers per second and the track was silent while the Denon read "Multi In" (`reports/2026-09-14-diag3-wonder-woman.md` §A); with the change VLC's counter shows 50 buffers per second and no anomaly line (`reports/2026-09-14-pass1d-truehd-audio-and-framerate.md` §1). Audibility remains the owner's check.
- **D016** the app asks tvOS to match the display to the stream: `PlayerModel.swift` parses the stream with `VLCMediaParser` before play (the server reports no frame rate; the parser timeout is in microseconds), builds `AVDisplayCriteria(refreshRate:formatDescription:)` from the video track's frame rate and size and from the server's `hdr` flag (PQ / BT.2020 extensions for HDR10, BT.709 for SDR), sets `UIWindow.avDisplayManager.preferredDisplayCriteria` before `play()` — or, when VLC's Matroska parse carries no frame rate, from the player's own video track about 0.1 s after `play()` — logs the display state before/after and on tvOS's mode-switch notifications, and clears the criteria in `dismiss()`. Home Theater has Match Frame Rate and Match Dynamic Range on; tvOS switched to 24 Hz for the 23.976 fps files and reported 2.9 s switches for the 29.97 fps ones. The switch does not change Wonder Woman's picture-drop rate (pass 1d §2).
- Defect closed (no decision): Menu with a track panel open now closes the panel — `PlayerScreen.swift` routes `onExitCommand` through `PlayerModel.handle(.menu)`; Menu with no panel exits as before (pass 1d §3).

## 2026-09-14 — pass 1e

- **D017** VideoToolbox picture-reorder fix as VLCKit patch 0019: `tools/vlckit-truehd/0019-videotoolbox-dpb-no-latency-bump-ahead-of-arriving-picture.diff` (a libvlc patch in `git format-patch` form, kept as `.diff`; `build.sh` copies it into `libvlc/patches/` as `.patch`, so it is applied with `git am` after 0018). Cause (diag4): `modules/codec/videotoolbox/dpb.c` bumps pictures before the arriving picture is stored. When the only trigger was the max-latency count, it released the next mini-GOP's anchor before the current mini-GOP's last B-picture. On Wonder Woman (`sps_max_num_reorder_pics` 3, `sps_max_latency_increase_plus1` 2) the vout then dropped 642 pictures per 3 minutes as one frame late; Divergent's latency limit of 6 is never reached. Chosen design: **candidate B** — in `BumpDPB`, a release triggered only by the latency condition stops at the first picture that follows the arriving picture in output order; fullness, reorder and flush releases are unchanged (6 inserted lines in `dpb.c`, 5 non-blank). Not A (split the release around the store across `decoder.c` and `dpb.c`), which also moved release timing in three unrelated cases of VLC's test. VLC's own `dpb_test.c` encoded the misorder in its "Max latency requirements" case (`6, 8, 10` released before `2`); that one expectation is corrected to display order (2 changed lines), and the test then passes (53 checks). Scope: the guard can fire only when a picture carries a latency limit, which only `FillReorderInfoH264` / `FillReorderInfoHEVC` set (`CreateReorderInfo` defaults `i_max_latency_pics = 0`), so it covers **H.264 and HEVC** decoded by VideoToolbox and cannot change MPEG-4 Part 2, H.263, ProRes or DV. MPEG-2 (Stargate) is decoded by avcodec on this device and never reaches this code. Evidence: `reports/2026-09-14-diag4-judder.md`, `reports/2026-09-14-pass1e-reorder-fix.md`, `reports/logs/1e-rerun2-dpbtest-and-simulation.txt`.
- **D018** Toolchain: Xcode 27.0 (27A266a) with the tvOS 27.0 SDK (24J360), replacing Xcode 26.6 (17F113) / tvOS 26.5 SDK. It was installed on the Mac on 2026-09-14 at 15:39, and the owner accepted the license. `Frameworks/VLCKit.xcframework` is rebuilt on it in two stages, both through `tools/vlckit-truehd/build.sh`:
  1. **Full clean build (pass 1e rerun 2, 16:49–16:59).** Every output from the 26.6 toolchain was removed first: libvlc's `build-appletv*` directories, which aren't SDK-versioned; the contrib build trees `contrib/contrib-*-apple-tvOS*`; the contrib installs `contrib/*-appletv*26.5`; and `VLCKit/build`. It then compiled the contribs locally (their `config.mak` records Xcode 27's clang and `AppleTVOS27.0.sdk`) and libvlc for all three slices with 19 patches (VideoLAN's 17, 0018, 0019). It failed at VLCKit's own `xcodebuild archive`: `TVOS_DEPLOYMENT_TARGET 11.0` is outside Xcode 27's supported 15.0–27.0.x.
  2. **Packaging (pass 1e rerun 4, 18:41:34–18:42:06).** `build.sh` step 2d sets `TVOS_DEPLOYMENT_TARGET = 26.0` in VLCKit's `VLCKit.xcodeproj` (4 build configurations) before the build, matching the app's minimum (D004). libvlc's own minimum in `build.conf` stays 11.0 (simulator 12.0). `PACKAGE_ONLY=1` skips the clone, patching, host tools and contrib/libvlc compiles and calls VideoLAN's script with `-n -l`, so it packages the slices a previous full run left. Here it reused rerun 2's three `libvlc-full-static.a` unchanged: size, time and SHA-1 were identical before and after, as was libvlc HEAD `e50d9ac36a`.
  - **Result:** both slices have `MinimumOSVersion 26.0` and `LC_BUILD_VERSION minos 26.0 sdk 27.0`, and `DTXcodeBuild` 27A266a. The device slice's `nm` lists `_ff_mlp_decoder`, `_ff_mlp_parser` and `_ff_truehd_decoder`.
  - **Kept from 26.6:** `contrib/tarballs` (sources) and `extras/tools/build` (the Mac host tools, which aren't linked into the framework).
  - **When to use which:** without `PACKAGE_ONLY` the recipe is the full build. That is required whenever the patches or the toolchain change, because every full run resets libvlc and re-applies the patches with `git am`.
  - **The app:** it builds on the same toolchain with deployment target 26.0 and embeds the framework with code-sign-on-copy. The only difference from `Frameworks/` is the signature and `__LINKEDIT`'s `vmsize`.

## 2026-09-14 — pass 1k

- **D008 (revised)** skips −10 s / +30 s while playing; while paused, a left/right click steps exactly one picture back/forward through VLCKit's native `gotoPreviousFrame` / `gotoNextFrame` (`PlayerModel.swift` `frameStep`; the diff kept as `reports/logs/1f-playermodel-native-prevframe.diff`, committed in pass 1k). **Superseded: the seek-back** (`player.time = before − one frame's duration`). Why: a seek lands on a keyframe/cue and decodes to the target time, so it showed a wrong picture, and while paused over HTTP it put this VLC build into an `ES_OUT_RESET_PCR` loop (105–237 laps per step before D014's cues, 792 in pass 1g) that read ahead while paused, so Play jumped to the read-ahead position (pass 1g: 03:32 from a pause at 00:33). Native steps on Home Theater: one decoded picture per click, both ways — Stargate (MPEG-2, avcodec) back and forward, Divergent (HEVC, VideoToolbox) back and forward, Wonder Woman (HEVC, VideoToolbox) back and forward; screenshots of the same position are identical (MAD 0) and adjacent ones differ (pass 1k §3; Stargate also pass 1f). Resume after steps: see D020. Needs VLCKit patch 0020 (D019). Evidence: `reports/2026-09-14-pass1f-frame-back.md`, `reports/2026-09-14-pass1g-frame-back-resume.md`, `reports/2026-09-14-pass1k-frame-back-close.md`, `reports/logs/1k-analysis.txt`.
- **D019** paused read-ahead after a frame step fixed as VLCKit patch 0020: `tools/vlckit-truehd/0020-es_out-forward-next-frame-need-data-only-from-stepped-es.diff` (libvlc patch in `git format-patch` form; `build.sh` installs it as `libvlc/patches/0020-….patch`, applied with `git am` after 0019; the recipe is 20 patches). **Cause** (passes 1g–1h): the previous-frame seek flushes every decoder while paused; a flushed subtitle decoder gets `frames_countdown = 1` (`src/input/decoder.c:2789–2793`) and, finding its fifo empty, asks for data (`decoder.c:2065–2070`). While frame stepping es_out drops every block not for the stepped video ES (`src/input/es_out.c:3164–3169`), so the request is never met and never cleared (`decoder.c:2686–2687`): `next_frame_need_data` stays true until Play, the input's pause gate (`src/input/input.c:668–669`) lets the demuxer run while paused (22 700 of 23 073 paused evaluations in pass 1h), paced by the clock anchored at the pause date, and the whole pause's worth of stream is queued (Stargate PCR 33 → 154 s) and played late on Play (1 495 dropped, clock 03:36 at Play+60 s from 00:33). **Chosen design: B1** — `decoder_frame_next_need_data` (`es_out.c:539`) forwards the request only from the stepped ES while `p_next_frame_es` is set, and `EsOutFrameNext` (`es_out.c:1388`) clears a request already standing when frame stepping starts, pushed as a control before the decoder's step call so a forward step's own request is queued after it; 2 lines, one file. **Rejected: B2** (`decoder.c:2791–2793`, no `frames_countdown` for SPU on a paused flush) **and B3** (`decoder.c:2065–2070`, request data only for video) — both change every paused flush, not only frame stepping: after a user seek or a title, chapter or track change while paused, the subtitle for the new position would not be fetched and shown until Play, which is what that line exists for; B3 also leaves the subtitle decoder looping on an empty fifo with `frames_countdown = 1`. Also rejected: B4 (gate in `input.c`: breaks forward stepping at the buffer edge and needs new es_out → input state) and B5 (let subtitle blocks through: met only when a subtitle packet arrives, ~80 s away on Stargate). **Scope:** frame stepping only; paused seeks without frame stepping (`p_next_frame_es == NULL`) unchanged; codec- and demuxer-independent; it matters only when a subtitle decoder is running (in pass 1k only Stargate had a subtitle track selected). **Tests:** VLC's `test/src/player` on a host macOS build, 19/20 before and after (`next_prev` passes; `attachments` fails in both from the host build's missing BMP encoder). **Device:** flag never set while paused and no reads outside a step's own rebuffer (pass 1i instrumented and clean); pass 1k clock at Play+60 s 01:34–01:35 after back and forward steps on every film (01:33–01:34 in the no-step controls). **Known gap:** `decoder_frame_next_need_data` reads `p_sys->p_next_frame_es` from a decoder thread without `p_sys->lock` (taking it there could deadlock against the decoder fifo lock the callback runs under); in the flush paths the write reaches that thread through the fifo lock, but it is formally a data race a thread sanitizer would flag. Evidence: `reports/2026-09-14-pass1h-demux-pause-diagnosis.md`, `reports/logs/1h-analysis.txt`, `reports/2026-09-14-pass1i-frame-back-fix.md`, `reports/logs/1i-instr-analysis.txt`, `reports/logs/1i-analysis.txt`, `reports/logs/1i-vlc-player-tests.txt`, `reports/2026-09-14-pass1k-frame-back-close.md`, `reports/logs/1k-analysis.txt`.
- **D020** known and accepted, not defects (native frame-back):
  1. **Pictures dropped on Play after any frame step.** Play resumes a stepped pause through `EsOutResumeFromNextFrame` → `EsOutChangePosition`, which resets the input clock; the demuxer's first PCR after the reset — about 1 s ahead of the picture on screen, the buffering it had already done — becomes the clock start (`input_clock.c:276–281` → `es_out.c:1138–1141`, `1253–1254`), while the video queue still starts at the displayed picture, so the pictures below that start are late and dropped (pass 1j trace: displayed `pf_pts=33834001`, clock start `stream=34785001`, dropped PTS 33 917 … 34 751). Measured in pass 1k, first 60 s: after five back steps 21 (Stargate, Wonder Woman), 25 (Divergent), 29 (Magicians), 28 (Food That Built America); after five forward steps 26, 29, 29, 45, 41 — about 0.9–1.0 s of picture after back steps and 1.0–1.5 s after forward steps (the 29.97 fps episodes drop more pictures for the same time). On-screen position and clock are right (00:37–00:38 at Play+3 s, 01:34–01:35 at +60 s, as the no-step control). **Rejected E1** (start the clock at the displayed picture): audio is flushed by the same resume and restarts at the demuxer's position (first audio PTS ~1.1 s after the displayed picture), so it would put ~1.1 s of picture with no sound first, and it needs a new decoder → es_out path in three files plus a vout getter for forward steps. **Rejected E2** (also re-read audio from the displayed picture): that is a seek on resume (pass 1g candidate C), a larger change to es_out/decoder resume handling for a ~1 s effect.
  2. **0020's remaining gap: a later plain pause after a step can read ahead.** Play's resume flush runs after frame stepping has ended, so the subtitle decoder's new request is forwarded and `next_frame_need_data` is set again (`INPUT_CONTROL_NEED_DATA_FRAME_NEXT 0 -> 1` 0.8 ms after Play); it stays set until a subtitle block arrives or the next Play, so a plain pause taken before then lets the demuxer read while paused — pass 1j: 3 967 demux calls, PCR 98.4 → 182.4 s (~84 s) over an 83.9 s pause. That resume was clean (pause delay applied, 0 dropped, 1 late at 14 ms, clock 01:40 / 02:37 from 01:36); the cost is memory for the queued stream. Only with a subtitle track selected. Evidence: `reports/2026-09-14-pass1j-frame-back-resume-fix.md`, `reports/logs/1j-analysis.txt`, `reports/2026-09-14-pass1k-frame-back-close.md`, `reports/logs/1k-analysis.txt`.

## 2026-09-15 — pass 2c

- **D021** touch-surface scrub with a preview playhead. **Revised in pass 2d (below) to the owner's flow: the pass 2c interaction here is superseded** — a drag no longer pauses playback, Menu no longer restores a playing state, and the pan no longer waits for the swipes to fail. The pass 2c interaction, kept for the record:
  - **The drag.** A horizontal drag on the Siri Remote's touch surface pauses playback and shows the scrub bar. The pan waits for the left/right swipes to fail and begins only when mostly horizontal (`PlayerHost.swift`). The bar is frame 10's timeline row in frames 14/15's place: the target's elapsed and remaining time, and a mark where the drag began (`PlayerScreen.swift`).
  - **The rate.** One surface width moves the target by **25% of the running time**. The target stops 1 s short of the end.
  - **The picture holds.** Nothing seeks during the drag or on lift: the picture stays on the frame the drag began at, and only the bar, the target and the times move.
  - **Landing.** A **click or Play/Pause** lands: `play()`, then **one seek** to the target (`PlayerModel.landScrub`).
  - **Cancel.** **Menu** cancels with no seek and restores the play state from before the drag.
  - **Everything else.** While a scrub is up, arrows, swipes and up/down do nothing (logged). With no scrub, every D008 meaning is unchanged.

  **Rejected: seeking during the drag** (pass 2a: paused seeks at most every 250 ms, plus one on lift). After the last paused seek, VLC re-buffered 12 times in 1.3 s (`ES_OUT_SET_(GROUP_)PCR is called … late` → `ES_OUT_RESET_PCR`), reading PCR 238.2 → 269.0 s for a 238.6 s target. Play then started at the read-ahead end: the first picture was 27.7 s past the target, the clock showed 04:29 for 03:59. This is pass 1g's paused-seek read-ahead. **Not used: VLC's fast seek** (pass 2b): VLCKit has no seek-speed setting, and nothing in this libvlc reads `input-fast-seek`.

  **Measured** (pass 2c, Home Theater, drags scripted through the model; the gesture itself is not yet tried on the real remote):
  - **Scope:** 48 scrubs on Stargate, Wonder Woman, Divergent and Magicians S1E1, forward and back, from playing and from paused.
  - **32 landings:** the first picture was −72 to +104 ms from the target, 0.06–0.85 s after the click (Divergent's 0.85 s is a seek decoding from a keyframe 9 s back). At most 1 dropped and 2 late in the 30 s after.
  - **16 cancels:** playback resumed within 0.81 s after the start from playing, and 0 ms from it from paused.
  - **The held picture:** one PTS through every drag.

  **Observed, not decided:** a pause after a landing lets the demuxer read at 1× while paused until resume, up to ~36 s of stream. It happened on all four films, with or without a subtitle track. No seek is involved and no landing moved.

  Evidence: `reports/2026-09-15-pass2a-scrubbing.md`, `reports/2026-09-15-pass2b-fast-seek.md`, `reports/2026-09-15-pass2c-scrub-preview.md`, `reports/logs/2a-analysis.txt`, `reports/logs/2c-analysis.txt`.

## 2026-09-15 — pass 2d

- **D021 (revised)** touch-surface scrub: **the owner's flow**. Supersedes the pass 2c interaction above.

  **The flow:**
  1. **Play/Pause pauses** the film (D008).
  2. **Paused, a swipe or drag scrubs.** The scrub bar appears once the drag moves the target (frame 10's timeline row in frames 14/15's place; `PlayerScreen.swift`). The picture holds; nothing seeks during the drag or on lift.
     - **The pan** on the touch surface runs **alongside** the swipe recognizers (it no longer waits for them to fail). It begins only **while paused**, for a drag that travels more across than up or down (`PlayerHost.swift`).
     - **The rate.** One surface width moves the target by **25% of the running time**; the target stops 1 s short of the end.
  3. **Paused, a left/right click steps back/forward one frame** (D008) whenever no scrub is up. A touch that comes with a click moves no target, so it shows no bar and holds back no click. A press also ends a drag that has not moved the target (`PlayerModel.swift`).
  4. **Play/Pause, or a click on the touch surface, lands** at the target and plays: `play()`, then one seek.
  5. **Menu cancels** with no seek. The film stays paused where the drag began.
  6. **While playing, a drag does nothing** (`[scrub] drag while playing: no action`). Swipes and clicks keep D008's −10 s / +30 s.
  7. **While a scrub is up,** arrows, swipes and up/down do nothing (logged).

  **Why the pass 2c pan changed.** From the owner's session on the real remote (`reports/logs/2d-owner-remote-session.log.gz`): because the pan waited for the side swipes to fail, a paused flick was recognized as a swipe and dropped by D008's paused rule. That showed as `right swipe while paused: no action (frame step is on click)` 19 times, with only 4 `[scrub] begin` in the same session. Touches around a click, or after swipe skips, also started scrubs while playing (`[scrub] begin at 1023072 ms playing=true` right after a click landing).

  **Still rejected:** seeking during the drag (pass 2a) and VLC's fast seek (pass 2b), as above.

  **Measured** (pass 2d, Home Theater, drags scripted through the model; the recognizer is the owner's hand test):
  - **Scope:** 24 paused scrubs on Stargate, Wonder Woman, Divergent and Magicians S1E1.
  - **16 landings** (8 Play/Pause, 8 click): first picture −74 to +94 ms from the target, 0.06–0.94 s after the press, at most 1 dropped and 1 late in 30 s.
  - **8 Menu cancels:** paused at the start (0 ms).
  - **The held picture:** one PTS through every drag.
  - **8 drags while playing:** refused, no pause.
  - **Skips:** exact.
  - **Frame steps:** 5 left + 5 right clicks were one picture each on all four films (pixel comparison: the right clicks retrace the left ones with a difference of 0).

  **Observed, not decided** (as in pass 2c): a pause after a landing lets the demuxer read at 1× while paused, up to ~36 s of stream.

  Evidence: `reports/2026-09-15-pass2d-owner-flow.md`, `reports/logs/2d-analysis.txt`.

## 2026-09-15 — pass 2g

- **D022** **VLCKit patch 0021 was tried and dropped; the recipe stays at 20 patches.** 0021
  (`src/input/es_out.c:3661`, one condition: no late-PCR compensation while es_out is paused) was
  written in pass 2f to let the picture follow the thumb during a paused scrub. It did end the
  paused-seek laps — 0 `PCR is called late` lines in 20 drags on four films, every landing within
  −81…+305 ms of its target — but it was dropped because the picture did not actually track and one
  film's clock broke:
  - **The picture tracked on Stargate only** (MPEG-2/avcodec): 7–8 of 8–9 drag seeks shown, in
    84–181 ms. On the HEVC films decoded by VideoToolbox each paused seek needed 0.2–1.1 s to show
    a picture, so the 250 ms seek cadence cancelled most of them: **Wonder Woman 1–5 of 8–9,
    Divergent 1–4 of 8–9**. During a drag the screen held the first seek's picture and then jumped
    to the lift target.
  - **Magicians S1E1 (the one MP4):** every one of the five endings logged
    `clock gap, unexpected stream discontinuity`, and after **4 of 5** VLCKit's reported time froze,
    so the overlay clock and the next drag's start were stale. HEAD's pass 2d sessions logged 0
    clock gaps. The gap is exposed rather than created by 0021 (a non-lapping paused seek produced
    one in pass 2e's 20-patch build too), and why the time freezes after some gaps and not others
    was never established.
  - **Stargate scrub 4** dropped 7 pictures at landing, against 1 in pass 2d's HEAD run of it.
  - **Dropped, not parked:** `tools/vlckit-truehd/0021-*.diff`, its `build.sh` step 2c'' and its
    README line are removed, and the framework is rebuilt at 20 patches (20 `Applying:` lines,
    libvlc tip = 0020, `es_out.c:3661` back to `p_pgrm != p_sys->p_pgrm || p_sys->p_next_frame_es
    != NULL`). The patch text survives only as pass 2f's evidence copy,
    `reports/logs/2f-0021-es_out-no-late-pcr-compensation-while-paused.diff.txt`.
  - **What replaces it:** the picture holds during the drag (D021, unchanged) and the server's
    timeline stills show the target instead — D021's thumbnail below. Evidence:
    `reports/2026-09-15-pass2f-scrub-live-picture.md` (§4 and its table),
    `reports/logs/2f-analysis.txt`, `reports/2026-09-15-pass2g-scrub-thumbnails.md`.

- **D021 (revised again)** the scrub carries a **timeline thumbnail**. The pass 2d flow above is
  unchanged in every other respect — a scrub only from paused, the picture holds during the drag,
  click or Play/Pause lands and plays, Menu cancels and leaves it paused, 25% of the running time
  per surface width, the target stopping 1 s short of the end; frame step, skips and the panels are
  untouched.

  **What shows.** During a paused scrub, one still above the bar: the server's still nearest the
  target, changing as the target moves (`PlayerScreen.swift`, `ScrubOverlay.still`). It appears with
  the bar once the target first moves and stays until the scrub lands or is cancelled, as the bar
  does. **Where the server has no still for the target there is nothing above the bar** — no
  placeholder, no held image, no message (`ThumbStrip.draw`).

  **Where the stills come from.** `GET /api/files/{fileId}/thumbs` (the index) and
  `GET /api/thumbs/{fileId}/{n}.jpg` (a 6 × 5 row-major sprite sheet), both new in the server's
  image 0.3.0 and written out in COLD-START.md. A still's number is
  `round(target ÷ interval)` clamped to `count − 1`; its sheet is `number ÷ per_sheet` and its tile
  `number − sheet.first_still`, row-major (`ThumbIndex.still(nearestMs:)`, `.place(still:)`).

  **When it is fetched.** The index is asked for **once, when a detail screen opens**, for the file
  that would play, and is never polled and never re-fetched (`MovieDetailScreen.loadThumbs`,
  `ShowDetailScreen.load`, `VideoDetailScreen.loadThumbs`). Because the first index request is what
  starts generation on the server, a file whose stills do not exist yet shows none this time round;
  the next visit has them. Sheets are fetched as they are needed for display and kept for the rest
  of the player's life (`ThumbStrip`, `Frameworks`-independent, `URLSession.shared`); while a sheet
  is still downloading nothing is drawn above the bar.

  **Which file "would play".** One index per screen means one file: the **first edition** of a
  movie (Play on a multi-edition movie opens the picker, so there is no single file until the owner
  chooses), the **first episode of the first season** of a show, and its one file for a video. A
  request carries the index only when the index's `fileId` is the file being played
  (`PlayRequest.matching`), so any other edition or episode simply plays with no thumbnail rather
  than the wrong one. Flagged as the open question of pass 2g.

  **Placement and styling** (Nocturne tokens and the overlay's own spacing): the server's tile size
  (320 × 214) at 1×, 26 pt above the bar row — the row's own gap — inside the same 80 pt side
  padding, carried over the target's place on the track with the bar row's 130 pt time columns as
  its margins and stopped at either end of the track; 8 pt corners, a `neutral700` hairline and a
  soft drop shadow. Nothing focusable, nothing else added.

## 2026-09-15 — pass 2 (resume, watched, Continue Watching, Recently Added)

The owner's calls for the playback state D009 deferred. Evidence for all of them:
`reports/2026-09-15-pass2-resume-watched.md`. The server side (image 0.3.0) is marlin-media's
D032–D035; this app's only write is `PUT /api/files/{fileId}/playback`.

- **D023** **Recently Added** joins the sort control (completing D010): `added`, newest first, on
  Movies, TV Shows and Videos. A **show sorts by the show's own `added`** — the server puts no date
  on an episode, so there is nothing else to sort by. Every tab still **opens on Title**, and the
  episode order inside a show is untouched. `LibraryModel.SortOrder`; the menu picks the third
  option up from `allCases`, so frame 05's three rows appear by themselves.

- **D024** **The client's two new calls.** `GET /api/continue-watching?limit=200` with a Decodable
  entry type (`ContinueEntry`), and `PUT /api/files/{fileId}/playback {position?, watched?}` —
  the app's first and only write, and an omitted key means "leave unchanged". Every write goes
  through `PlaybackWrite.send`, which logs the request and the server's answer. **A failed write is
  a log line and nothing else:** nothing appears on screen and playback is unaffected. A failed
  continue-watching read is the same — the row is simply absent, because the library itself is fine.

- **D025** **The Continue Watching row** (frames 01, 02), above the grid on each tab. It shows only
  **that tab's kind** (movie / episode / video), in the **server's order** (newest `last_played`
  first), **every entry**, scrolling sideways. Movie and video cards carry the title and
  "N min left"; episode cards carry the show's title, "S# E# · episode title" and "N min left";
  both carry the bar across the foot of the art. **No entries: no heading and no row, and the grid
  moves up.** The row is re-read **every time the library appears**, including the return from the
  player. **A card plays its own file straight away** — no detail screen and no edition picker —
  after fetching that file's thumbnail index as a detail screen would (D021); because the entry
  carries no path, HDR flag or codecs, the item's detail is read first so that D014's `.mkv` rule
  and D016's display match still apply. **Grid posters get no bar and no watched mark.**

- **D026** **Movie detail (frame 06) and video detail (frame 09), identical behaviour.**
  - A **"✓ Watched"** pill at the end of the meta row when watched, and no pill when not.
    **The frame's watch count ("Watched 2 ×") is dropped — the owner's call:** the server's
    `playback` keeps a boolean, not a count.
  - A saved position > 0 gives **"▶ Resume · N min left"** with the bar inside the button, plus
    **"Start over"**. A position of 0 gives **"▶ Play"** alone — no bar, no Start over.
  - A third button reads **"Mark watched"** when not watched and **"Mark unwatched"** when watched.
    Both write **position 0** (with `watched` true / false) and then re-read the screen.
  - **Start over** writes position 0 first, then plays from the beginning.
  - On a movie with several editions the buttons **follow the edition with the latest
    `last_played`** (the first edition when none has been played), and pressing Play or Resume
    **still opens the picker** (frame 07), where **"Resume · N min left"** shows under the editions
    that have a saved position and nothing under the others. Start over and the mark buttons act on
    the followed edition.

- **D027** **Show detail (frame 08).** "**N unwatched**" at the end of the meta row counts every
  episode of the show not marked watched, **a partly watched one included**. Each episode row's
  right-hand column reads **"Watched ✓"**, **"N min left"** (with the bar across its still) or
  **"Unwatched"**. Clicking a row with a saved position **resumes there**; one without plays from
  the start. **Press-and-hold** on a row opens an overlay in the edition picker's style carrying
  **"Mark watched"** or **"Mark unwatched"**, with the same writes as D026.

- **D028** **What the player writes.** The position in seconds is written **every 10 s while
  playing, once on pause, on stop and on exit**; a dismiss and the stop that follows it write once
  between them, not twice. **A position under 120 s is never written**, so a peek leaves no saved
  spot. At **90 % of the file's own length** (VLCKit's `length`, not the server's `duration`)
  the app writes **`watched: true` with `position: 0`** once, which is exactly what takes the item
  off the server's continue-watching list (marlin-media D033); **after that mark no further
  position is written for that playback**.

- **D029** **Starting at a saved position: one seek, once the film is playing.** A request carrying
  a `startMs` plays from the beginning and is seeked once at the first `Playing` state — D021's
  landing path. On Home Theater (Stargate Extended, saved 1 800 s): `length 7798056 ms`,
  `resume +1 s time=1800835 ms`, 0 `PCR is called … late`, 0 clock gaps, and the one
  `ES_OUT_RESET_PCR` is the seek's own (`SET_TIME to 1800000000`, preroll pts 1 799.815 s — D014's
  cues landing just before the target). D008, D014, D016 and D021 are untouched.

  **Rejected: the `:start-time=` media option**, tried first on Home Theater in this pass. It plays
  the right picture, but it **re-bases VLC's whole timeline**: for the same file `length` came back
  as **5 998 056 ms** (7 798 056 − 1 800 000) and `player.time` restarted at **0**, so the overlay
  read 00:15 / −1:39:43 with the knob at the left. Every position written would have been wrong by
  the start offset, the 90 % mark would have measured the remainder rather than the file, and
  D021's scrub would have mapped over a short timeline. Compensating with an offset would have
  meant changing every path that reads the clock — the skips, the frame step and the scrub — which
  is exactly what this pass was told not to disturb.

- **D030** **A home page is wanted as its own design and its own pass, after pass 2.** It is not
  designed yet: the 17 frames have no home screen, and nothing of it is built here.

## 2026-09-15 — pass 2b (pass 2 follow-ups)

The owner's calls. Evidence, and which of them is actually working, is in
`reports/2026-09-15-pass2b-followups.md`; two of the three builds below do **not** work yet and
the report says so.

- **D031** **Press-and-hold on an episode row opens the mark menu, and a click still plays or
  resumes.** A different gesture was not allowed.

  **Pass 2b's candidate (a) is gone** (removed in pass 2c): a `UILongPressGestureRecognizer`
  restricted to the select press, on the window while the show detail was up. Instrumented on Home
  Theater it **attached** (`[hold] recogniser added to the window`) but **never received the
  press** — no recogniser state was ever reported — because a focused SwiftUI Button consumes the
  select press and acts on release.

  **Pass 2c built candidate (b): the row is a focusable view, not a Button** — `EpisodeRowLabel`
  with `.focusable()`, `.focused($focusedEpisode, equals:)` and the row's own
  `.onLongPressGesture(minimumDuration: 0.6, perform:onPressingChanged:)`. It draws and focuses
  exactly as before (the label is untouched and still reads `@Environment(\.isFocused)`), and
  **the click half works**: a press reaches the row, and a release plays or resumes it
  (`[hold] click: playing S1E3 from 0 ms`; `… S1E1 from 968576 ms` then
  `seeking to the saved position 968576 ms`).

  **The hold half still does not work, and pass 2c stopped there.** Instrumented press timing on
  the device: an ordinary click is 4–15 ms between down and up, while the 1.4 s hold measured
  **601 ms** — capped at the 0.6 s threshold — and no `[hold] mark menu` line followed. So the long
  press *is* recognised, but SwiftUI delivers **`onPressingChanged(false)` before `perform`**: the
  release handler treats it as a click and starts playback, and `perform` then finds `playerUp`
  true and refuses. The cause is the handler's ordering, not the platform's gesture. **The fix is
  to classify the press by its own elapsed time** — remember the press-down instant and treat a
  release past the threshold as a hold rather than a click — which removes the race entirely. It
  was not applied: the hold still played, which is pass 2c's stop condition.

- **D032a** The press-down/press-up instrumentation in `ShowDetailScreen` stays in, as pass 2b's
  did, for whoever finishes D031.

- **D032** **Every detail screen re-reads its item when the player closes**, so the Resume / Play
  button, its bar, the watched pill, the episode states and the unwatched count are current on the
  way back. `ContentView` counts the closes (a full-screen cover never takes its content off
  screen, so there is no appearance callback to use) and hands the count to the movie, show and
  video screens, which re-read on it. The show screen re-reads without its loading state, so the
  list does not flash and the chosen season is kept.

- **D033** **Focus entering the Continue Watching row lands on its first card.** **Working, from
  pass 2c.**

  **The mechanism:** every card carries `@FocusState` (`.focused($focusedCard, equals: entry.fileId)`),
  and the row watches that state. When focus arrives and **no card held it a moment before**, it is
  moved to the first card; a move from one card to another inside the row has a previous card and is
  left alone, so left/right along the row is unchanged.

  **Pass 2b's attempt is removed:** a focus scope whose first card was `prefersDefaultFocus`. It did
  nothing, because tvOS resolves a directional press by nearest neighbour and `prefersDefaultFocus`
  governs only initial and programmatic focus — entering from the sort control landed on the
  **rightmost** card.

  **Evidence** (Home Theater, pass 2c, with two cards — `continue.4` then `continue.2`): focus lands
  on `continue.4` entering **from the sort control**, **from the tab the row sits under**, **after
  moving to the second card and leaving and re-entering**, and **after returning from the player**.
  The three that needed a move logged
  `[focus] continue row entered at card 2; moved to the first card 4`; the fourth arrived on the
  first card already and needed none.

- **D034** On a movie with several editions, **Start over and the mark buttons act on the followed
  edition without the picker**, while Play / Resume opens the picker (pass 2 open question 3).

- **D035** **Start over does not clear `watched`.** A rewatch therefore shows Resume together with
  the "✓ Watched" pill, and only Mark unwatched clears the flag.

- **D036** **The 90 % watched mark keeps VLCKit's `length`** — the file's own length, as the player
  reports it — rather than the server's `duration`.

- **D037** **No "clear playback state" control in the app.** The state pass 2 and 2b wrote while
  testing is reset to zero once the owner has accepted both passes, as a later step.

- **D038** **A check is still owed:** Videos Recently Added and the video detail screen, once a
  video exists on the server. Neither has ever run on a device, because this library has no videos.

## 2026-09-15 — pass 3 (the episode rows, Home and the clock)

Evidence: `reports/2026-09-15-pass3-home-and-rows.md`. The owner tests this pass by hand, so it was
built, installed and launched, with four screenshots and no test matrix.

- **D039** **The episode row, fixed twice over.**
  - **Its focus highlight is back.** A plain `.focusable()` view does not put `isFocused` into its
    child's environment the way a Button's style does, so after pass 2c `EpisodeRowLabel` always saw
    `false` and drew nothing. The row now takes `focused:` explicitly from `@FocusState`. The drawing
    is the pass 2/2b row, unchanged.
  - **The press decides itself.** The press-down instant is remembered, and the release is measured
    against it: held **0.6 s or more** opens the mark menu and plays nothing; shorter plays or
    resumes, as before. Pass 2c raced SwiftUI's callbacks instead — `onPressingChanged(false)`
    arrives before `perform` — so a hold was taken as a click and started playback. Pass 2c's
    press-down/press-up instrumentation is removed.

- **D040** **Home is the app's first screen** (frames 00, 00b, 00c). MARLIN, then Movies / TV Shows /
  Videos, which open that library tab; Menu on a library tab comes back to Home. Then the rows, each
  scrolling sideways:
  - **Continue watching** — every in-progress movie, episode and video mixed, newest first, the same
    cards the library tabs use; a card plays its file from its saved spot. **Hidden when empty**
    (frame 00c).
  - **Movies · <total>** — up to 6: the in-progress ones first (most recently played first), then
    the rest by title. A card opens the movie screen.
  - **TV Shows · <total shows>** — up to 6 **episode** cards in frame 00b's wide card, each with
    that episode's own still (the picture the show screen's episode list uses), the show's title and
    "S# E# · episode title". The order: the episodes in progress, newest watched first; then, for
    each show, the next episode after the last one it finished; then on down each show, a step at a
    time, until the row is full. A show never watched joins from S1 E1, after the shows that have
    been watched. A card plays that episode, resuming if it has a saved spot.
  - **Videos · <total>** — up to 6, in-progress first and then by title; a card opens the video
    screen. With no videos the heading still shows, with nothing under it.
  - **Home re-reads itself every time it appears**, including on the way back from the player. That
    needs every show's episodes, which the shows list does not carry, so Home fetches one
    `GET /api/shows/{id}` per show alongside the lists.

- **D041** **The clock.** The current date and time ("TUE 15 SEP" · "9:40 PM") at the top right —
  `right: 80, top: 56` — on Home, the three library tabs and the movie, show and video screens. It
  keeps time while it is on screen. **Not on the player** (frames 10–15 do not draw it). The **Sort
  control moves 260 pt in from the right edge**, as the new frames 01–04 draw it, to clear it.

- **D042 (see also pass 3b below)** **The design is replaced.** `Design/Marlin Media tvOS Design2.zip` was unzipped into
  `Design/`, replacing `Marlin Media.dc.html`, `Marlin Media Prototype.dc.html`, `support.js` and
  `_ds/`, and the zip was deleted once the replacement was in place. The earlier
  `Marlin Media tvOS Design.zip` is left as it was. What changed: **frames 00, 00b and 00c are new**;
  frames 01, 02, 03, 04, 06, 07, 08, 09, 16 and 17 differ **only** by the clock (and 01–04 by the
  Sort control's 260 pt shift); frames 10–15, the player, are unchanged. Nothing else in any frame
  moved.

## 2026-09-15 — pass 3b (the owner's three fixes)

The owner's calls, given after testing pass 3. Evidence:
`reports/2026-09-15-pass3b-fixes.md`, screenshots `reports/screenshots/p3b/`.

- **D043** **When the app opens, focus lands on the first Continue Watching card** — frame 00's own
  label ("first card focused"), and pass 3's open question 1. Before this, tvOS chose for itself and
  picked a Movies card, so Home opened slightly scrolled with the top row cut.

  **The mechanism.** Every Continue Watching card on Home carries `@FocusState`
  (`.focused($focusedCard, equals: entry.fileId)`), as the library tabs' cards already did for D033.
  The first card is **asked for until it takes focus** — the focus engine ignores a request for a
  view that is not on screen yet, and the row is built from the in-progress list, which arrives after
  Home's first appearance — so the request is repeated every 120 ms, at most 12 times, and stops the
  moment any card of the row holds focus.

  **Placed once per session.** A `launchFocusPlaced` flag means it happens on the first list Home
  receives and never again: moving along the row, coming back from the player and Home's own re-reads
  (D040) are untouched, and a viewer who moves before the card arrives is not pulled back.

  **With nothing in progress there is no row and nothing is placed** — the focus engine keeps
  today's behaviour, as the owner asked. This is Home only; D033's rule for the library tabs (focus
  *entering* the row from outside moves to the first card) is unchanged and not copied here.

- **D044** **The clock is on the loading and "can't reach server" screens (frames 16 and 17), and no
  code was needed for it.** Pass 3 reported it as not built; that report was wrong. The clock overlay
  D041 added sits on the **container**, outside the phase switch, in both screens that can show those
  states — `HomeScreen.swift` (the overlay is applied to the whole `ZStack`, after the
  `loading / failed / loaded` switch and before `ignoresSafeArea`) and `LibraryScreen.swift` (the
  same) — so `LibraryLoadingView` (frame 16) and `LibraryErrorView` (frame 17) are drawn beneath it
  and carry the clock at `right: 80, top: 56`, which is exactly where the new frames 16 and 17 put
  it (`position:absolute;right:80px;top:56px;z-index:6`, the same 18 px/500 `.1em` date and 24 px/500
  tabular time as every other frame).

  **Not photographed on the device, and why.** Neither state can be reached on Home Theater without
  changing something that is out of scope: the loading phase is over before the app paints its first
  frame (the session recording's own frames show tvOS at 2.80 s and Marlin's Home, already populated,
  at 2.85 s — the loading screen never appears), and the error screen needs the server unreachable,
  which would mean either a server write, a change to `ServerConfig.baseURL` or pulling Home Theater
  off the network. It is a **code trace, not device proof** — recorded as such in the pass 3b report.

- **D045** **The clock is on the player while paused, and only while paused.** This **revises D041's
  "not on the player"**: frames 10–15 draw no clock, and the owner's call of 2026-09-15 adds one for
  the paused state.

  **What shows.** The same `NowClock` pair, the same style, and the same place as every other screen
  — `right: 80, top: 56` (`PlayerScreen.swift`, `pausedClock`). **While playing there is none.** The
  condition is the one frame 13's pause mark already uses, `!model.isPlaying`, so the clock and the
  pause mark appear and go together, and it needs no new state in `PlayerModel.swift` (untouched).

  **Hidden while a track panel is open.** Frames 11 and 12 put the panel in that same top-right
  corner (760 pt wide, `top: 90`, `trailing: 80`), so the clock would sit on top of it; with
  `model.panel != nil` it is not drawn. It **does** show during a paused scrub (D021), where the bar
  and the thumbnail are at the foot of the screen and nothing collides.

  **Nothing else in the player changed.** The clock is added to the visuals-only `ZStack`, which is
  `allowsHitTesting(false)`, so it takes no press, no touch and no focus; D008's skips, the frame
  step, the panels and D021's scrub are untouched, and `PlayerModel.swift` and `PlayerHost.swift`
  were not edited.

## 2026-09-15 — pass 3c (the push, and the test-state reset)

The owner tested passes 2, 2b, 2c, 3 and 3b on Home Theater and **accepted them all** ("all good",
2026-09-15). Evidence: `reports/2026-09-15-pass3c-push-and-reset.md`. No app source was touched and
nothing was built.

- **D046** **Passes 2–3b are accepted and pushed.** `main` went to `origin` as a fast-forward, no
  force: **`3597d0a..896ee12`, five commits** — `b3f3b02` (pass 2), `8def8cd` (2b), `ef9ce11` (2c),
  `a99cccc` (3), `896ee12` (3b). Checked before the push: `origin/main` was `3597d0a`, it is an
  ancestor of `main`, and the range holds five single-parent commits and **no merges**. Checked
  after: local `main`, `origin/main` and `git ls-remote origin main` are all `896ee1293ac9`.
  `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`) and nothing under `Frameworks/`
  is tracked on any ref, so the custom VLCKit was not pushed — as in passes 1l and 2h. The notebook
  and report commit of this pass was pushed the same way.

- **D047** **The test playback state is reset — D037 is discharged.** The five passes wrote playback
  state on **five files and no others**, which a full read of the library confirmed was exactly the
  set (files 3, 6, 7 and 9–20 were all `position 0, watched false, last_played null` and were not
  touched). Each was read off its item first — there is no read-back route for a single file — then
  written with `PUT /api/files/{fileId}/playback {"position": 0, "watched": false}`, five `200`s:

  | file | item | before | after |
  |---|---|---|---|
  | 1 | Divergent | 0, false, `01:45:31Z` | 0, false, `03:29:43Z` |
  | 2 | Stargate · Extended | 1 821.678, false, `00:55:13Z` | 0, false, `03:29:43Z` |
  | 4 | Wonder Woman | 2 457.189, false, `03:24:21Z` | 0, false, `03:29:43Z` |
  | 5 | The Food That Built America S4 E2 | 0, **true**, `01:09:39Z` | 0, false, `03:29:43Z` |
  | 8 | The Magicians S1 E1 | 1 224.173, false, `02:24:50Z` | 0, false, `03:29:43Z` |

  (all timestamps 2026-09-16 UTC). Continue Watching went from **3 entries** —
  `movie/4@2457.189s, episode/8@1224.173s, movie/2@1821.678s` — to **`[]`**, and no file on the
  server now carries a position or a watched flag.

  **`last_played` is not cleared, and is not meant to be.** The server stamps it on every write and
  the body carries no way to null it, so the five read the reset's own instant rather than `null`.
  Nothing the app does depends on that: Continue Watching is `position > 0 and watched = false`
  server-side, Recently Added (D023) sorts on `added`, and the detail screens read only `position`
  and `watched`. The one visible trace is D026/D034's *followed* edition, chosen by `last_played` —
  on Stargate that is still Extended (file 2 stamped, file 3 still null), exactly as before. A true
  virgin state would need a server-side clear, which is the server repo's call, not the client's.

## 2026-09-16 — pass 4 (the app icon)

Evidence: `reports/2026-09-16-pass4-app-icon.md`, screenshots `reports/screenshots/p4/`. No Swift
file was touched. This answers pass 1's open question 11 (no asset catalog, so no app icon).

- **D048** **The app has a layered tvOS icon, from Claude Design (D006).**

  **Where it came from.** `Design/tvos icons/Marlin Media tvOS Design.zip` — a second Claude Design
  export, separate from the frames, delivered by the owner on 2026-09-16 and **now tracked in the
  repo** so the icon's source travels with it. Six files from its `icons/` folder are used, and only
  those six:

  | catalog slot | file | pixels |
  |---|---|---|
  | App Icon · Back · 1x | `icon-400x240-back.png` | 400 × 240 |
  | App Icon · Back · 2x | `icon-800x480-back.png` | 800 × 480 |
  | App Icon · Front · 1x | `icon-400x240-front.png` | 400 × 240 |
  | App Icon · Front · 2x | `icon-800x480-front.png` | 800 × 480 |
  | App Icon – App Store · Back · 1x | `icon-1280x768-back.png` | 1280 × 768 |
  | App Icon – App Store · Front · 1x | `icon-1280x768-front.png` | 1280 × 768 |

  The export's `icon-*-flat.png` files and `preview-b.png` are **flattened previews and are not
  used** — a tvOS icon must stay in layers or it cannot do the focus parallax. All six carry alpha.

  **The shape.** `Marlin Media TV/Assets.xcassets/AppIcon.brandassets`, the project's first asset
  catalog, holding the icon and nothing else (no accent colour, no launch image; the UI's colours
  stay in `Theme.swift`). Two image stacks, each of **exactly two layers, Front over Back**:
  `App Icon.imagestack` at 400 × 240 (idiom `tv`, 1x and 2x) and
  `App Icon - App Store.imagestack` at 1280 × 768 (idiom `tv-marketing`, 1x).
  **The Middle layer slot Xcode's template creates was removed, not left empty and not filled** —
  the owner's call for this pass, and the export supplies two layers, not three.

  **The Top Shelf images are declared and deliberately empty.** `Top Shelf Image.imageset` and
  `Top Shelf Image Wide.imageset` carry their standard 1x/2x slots with no file. The build does not
  need them (it succeeded with no warning), and the export has no top-shelf artwork. Open.

  **How it reaches the target.** `Marlin Media TV/` is a `PBXFileSystemSynchronizedRootGroup`, so
  the catalog joined the app target simply by being in that folder — no file reference was added.
  The only project edit is `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on the app target's Debug
  and Release configurations: **two inserted lines in `project.pbxproj`, nothing else moved**, and
  the UI-test target's configurations were not touched.

  **Proof on Home Theater** (build, install, launch, photograph; no test matrix):
  - `** BUILD SUCCEEDED **` with **no warnings and no errors**; `actool` invoked with
    `--app-icon AppIcon`.
  - The built `Info.plist` carries `CFBundleIcons → CFBundlePrimaryIcon = "App Icon"`, and
    `assetutil` on the app's `Assets.car` lists `App Icon` as an `ImageStack` with
    `App Icon/Back/Content` and `App Icon/Front/Content` at tv 1x and tv 2x.
  - Installed and launched; the app came up unchanged (`[library] loaded 3 movies, 2 shows,
    0 videos`, `[continue] 0 entries`, D047's reset still in place).
  - **Photographed on the device:** `reports/screenshots/p4/p4-1-appletv-home-screen.png` — tvOS's
    own Home screen with the artwork in the app's place, where the generic tile used to be — and
    `p4-2-icon-closeup.png`, that icon at native resolution.
  - **Not shown:** the focus parallax (it needs the icon focused, which needs a Home-button press
    that nothing here can send) and the App Store icon (`tv-marketing` assets are stripped from a
    device build). Both are traced from the catalog and `Assets.car`, not photographed.

  **A route worth keeping, found here:** `xcrun devicectl device capture screenshot --device <id>
  --destination <file.png>` photographs whatever is on the device, **tvOS's own Home screen and
  other apps included**. The UI-test harnesses cannot do this — XCUITest only ever sees the app
  under test. `devicectl device info processes` says what is running.

  **Not pushed.** Committed on `main` and held there for the owner to look at the icon on the
  television first, as every feature pass has been.
