# Marlin Media TV — cold start

Read this and DECISIONS.md before any work; do not re-derive what they settle. Per-pass
reports live in `reports/`.

## What this is

The tvOS client for **marlin-media**, the home media server (repo marlin1111ai/marlin-media;
Go, SQLite, TMDB metadata, direct-play streaming). The app shows the server's movies, TV shows
and videos, and plays the original files with VLCKit — the server never transcodes; it serves
the file bytes with HTTP Range support at `/stream/{fileId}`.

## Where things are

- **Server:** `http://192.168.1.250:8093`, fixed in `ServerConfig.baseURL` (D007: no settings
  screen). Never the marlinpc dev copy. Endpoints used: `/api/movies`, `/api/movies/{id}`,
  `/api/shows`, `/api/shows/{id}`, `/api/videos`, `/api/artwork/…`, `/stream/{fileId}`, and the
  timeline stills of image 0.3.0 (pass 2g):
  - `GET /api/files/{fileId}/thumbs` — the index: `interval` (10 s), `tile_width` (320),
    `tile_height` (214 on the films measured), `columns` (6), `rows` (5), `per_sheet` (30),
    `count`, `state` (`none` | `generating` | `complete` | `failed`) and `sheets`, an array of the
    sheets that exist **at that moment**, each `{index, first_still, url}`. Generation starts on
    the first index request, so the first caller usually gets `generating` with `sheets: []`; a
    file with no usable duration returns `none`, and `failed` re-queues on request. An unknown
    file id is `404 {"error":"file not found"}`.
  - `GET /api/thumbs/{fileId}/{n}.jpg` — one sprite sheet, 6 × 5 tiles, row-major and
    chronological (1920 × 1070 for a 320 × 214 tile, ~90 KB, `Cache-Control: max-age=86400`).
    The index's `sheet.url` carries a `?v=` cache-buster.
- **Repo:** https://github.com/marlin1111ai/marlin-media-tv (branch `main`).
- **Working folder:** `~/Xcode/Marlin Media TV`. `Marlin DVR TV` next to it is read-only prior
  art (same owner, same device, same team); nothing else under `~/Xcode` is touched.
- **Design:** `Design/Marlin Media tvOS Design.zip`, unzipped in place. The 17 frames in
  `Design/Marlin Media.dc.html` and the clickable `Design/Marlin Media Prototype.dc.html` are the
  design; the Nocturne tokens are in `Design/_ds/nocturne-…/styles.css` and are mirrored in
  `Marlin Media TV/Theme.swift`. Build what the frames show; design nothing (D006).
- **Device:** Apple TV 4K (3rd generation), named **Home Theater**, tvOS 26.6, Developer Mode on,
  paired with this Mac (D005). The bedroom Apple TV is not used.
- **Xcode:** 27.0 (27A266a), tvOS 27.0 SDK (24J360) — since 2026-09-14 (pass 1e rerun; supersedes 26.6 (17F113) / tvOS 26.5 SDK). Bundle id `com.marlin1111.marlin-media-tv`, team
  `C879JNVK7Z`, automatic signing (both read from Marlin DVR TV).

## Toolchain facts

- **VLCKit:** a custom build of VideoLAN's VLCKit 4.0.0-a24 with the TrueHD/MLP decoder compiled in
  (D012). It lives at `Frameworks/VLCKit.xcframework` (git-ignored, 725 MB; tvOS device arm64 +
  simulator arm64/x86_64 slices) and the Xcode project links and embeds it by path — the Swift package
  is gone (D013). Built by `tools/vlckit-truehd/build.sh` at `~/vlckit-build` (VideoLAN's scripts cannot
  take spaces in paths) from libvlc master 5dd4aebda + 20 patches: VLCKit's 17 (0007 minus its mlp hunk),
  **0018** (TrueHD/MLP decoder frames coalesced into 20 ms blocks, D015), **0019** (VideoToolbox
  picture-reorder fix, D017) and **0020** (no paused read-ahead after a frame step, D019). Current framework
  (full recipe, 2026-09-14 23:30–23:33, 20 `Applying:` lines; the first 19-patch build was 18:42): contribs and libvlc compiled clean on
  Xcode 27.0 / tvOS SDK 27.0, packaged with VLCKit's project tvOS target set to 26.0 (`MinimumOSVersion`
  26.0, `LC_BUILD_VERSION minos 26.0 sdk 27.0`, D018). ffmpeg 9.0 (`Lavc63.1.100`), Video Toolbox decoding,
  `samplebufferdisplay` video output, `avsamplebuffer` audio output. Reported version string:
  `4.0.0-dev Otto Chriek`.
- **VLCKit build prerequisites (not the app's):** python.org Python 3.14.7 at
  `/Library/Frameworks/Python.framework` (installed 2026-09-13; VideoLAN's script looks only there)
  and GNU make 4.4.1 built into `~/vlckit-build/tools` and passed as `VLC_PATH` (Xcode's make 3.81
  breaks the jobserver with VLC's ninja). On Xcode 27 a clean build compiled the contribs and all three
  libvlc slices in 9 min 11 s (16:49:46–16:58:57, 2026-09-14; the host tools in `extras/tools/build`
  were kept). `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh` re-packages the slices already built (no
  clone, patching, host tools or compiles; VideoLAN's script with `-n -l`) in about 30 s. Any change to
  the patches or the toolchain needs the full build, which resets libvlc and re-applies every patch.
  `~/vlckit-build` was 22 GB on 2026-09-13 (not re-measured since).
- **Minimum tvOS:** 26.0 exactly (`TVOS_DEPLOYMENT_TARGET = 26.0`, D004). Both Apple TVs run 26.6.
- **No CocoaPods, no xcodegen, no brew installs.** The project file was written by hand
  (objectVersion 71, file-system-synchronized groups); Xcode opens it normally.
- **Fonts:** the system font. The design names Inter; no font is bundled (open question in
  the pass-1 report).

## Build, install, run (all from the repo root)

```
xcodebuild build -project "Marlin Media TV.xcodeproj" -scheme "Marlin Media TV" \
  -destination 'platform=tvOS,name=Home Theater' -derivedDataPath build/DerivedData -allowProvisioningUpdates
xcrun devicectl device install app --device <Home Theater identifier> \
  "build/DerivedData/Build/Products/Debug-appletvos/Marlin Media TV.app"
xcrun devicectl device process launch --console --terminate-existing --device <id> com.marlin1111.marlin-media-tv
```
`xcrun devicectl list devices` gives the identifier. Each launch writes
`Library/Caches/marlin-media-tv.log` in the app container (VLCKit's debug log plus the app's
`[player]` lines); copy it off with
`xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.marlin1111.marlin-media-tv --source Library/Caches/marlin-media-tv.log --destination <file>`.

**Evidence harness** (the Marlin DVR TV convention — not a standing test):
`Marlin Media TVUITests/EvidenceUITests.swift` drives the real remote through `XCUIRemote` on
Home Theater and photographs the screen. Build with `build-for-testing`, then
`xcodebuild test-without-building … -only-testing:"Marlin Media TVUITests/EvidenceUITests/test1_Library" -resultBundlePath <x.xcresult>`
and `xcrun xcresulttool export attachments --path <x.xcresult> --output-path <dir>` for the PNGs.
It navigates by reading which element has focus (`hasFocus == YES`), never by counting presses.
It makes no server write.

## How the app is put together

- `Models.swift` — Decodable models of the server JSON (every field real; decoded with
  `convertFromSnakeCase`) and `Format`, the display mapping of the server's values (codec names,
  "7.1", "2 h 20 min", "13.2 GB").
- `ServerAPI.swift` — `ServerConfig` (base URL) and `APIClient`; every failure is an `APIError`
  with a message the UI shows in full.
- `LibraryModel.swift` / `LibraryScreen.swift` — frames 01–05, 16, 17. Tabs and seasons switch on
  click (the prototype's behaviour); the sort menu is Title / Year (Recently Added waits for D009).
- `MovieDetailScreen.swift` (frames 06, 07), `ShowDetailScreen.swift` (08),
  `VideoDetailScreen.swift` (09).
- `PlayerModel.swift` (VLCKit + the remote's meaning, D008), `PlayerHost.swift` (the UIKit
  surface that owns every press, touch and swipe — an edge click is a `UIPress`, a swipe is not),
  `PlayerScreen.swift` (frames 10–15, visuals only, nothing focusable), `EvidenceLog.swift`.
- `Frameworks/VLCKit.xcframework` — the custom VLCKit (D012/D013), linked and embedded (code-sign on
  copy) by the project; not in git. Rebuild with `tools/vlckit-truehd/build.sh`.
- `Info.plist` carries `NSAllowsLocalNetworking` so plain-HTTP to 192.168.1.250 is allowed.

## Current state after pass 1 (2026-09-13)

See `reports/2026-09-13-pass1-scaffold-and-player.md`. Built and proven on Home Theater:
library (3 movies, 2 shows, empty Videos), sort by Title and Year, movie/show detail, edition
picker, and VLCKit playback of the four MKVs and a Magicians episode with the overlay, skips,
pause, frame step, audio and subtitle panels. Committed locally on `main`; **not pushed** — the
owner tests first.

**Pass 1b (2026-09-13) done after four stops** (repo path spaces, missing GNU mirror tarballs,
Xcode's Python 3.9.6, Xcode's make 3.81 — all recorded in
`reports/2026-09-13-pass1b-vlckit-truehd.md`): the custom VLCKit decodes Wonder Woman's TrueHD
track on Home Theater and hands tvOS 8-channel 48 kHz PCM; Divergent (DTS) and Stargate (AC-3)
unchanged. The app links `Frameworks/VLCKit.xcframework`; the Swift package is gone.

One finding still waits on the owner (pass-1 report, open question 2): **the D008 seek-based
frame back shows a wrong frame and puts this VLC alpha into a rebuffer loop over HTTP** — the
native `gotoPreviousFrame` exists in this build but was not tried. TrueHD is solved by pass 1b. Deferred to a later pass (D009):
Continue Watching, progress, watched marks, Resume / Start over, Recently Added.

**Pass 1c (2026-09-14):** MKV seeks now use the file's Cues — one media option, `:demux=mkv_trusted`, on `.mkv` streams only (D014). Ten +30 s skips bring the picture back in under 0.6 s on all four MKVs (8–51 s before); nothing else changed. Numbers in `reports/2026-09-14-pass1c-mkv-seek.md`; the two diagnosis reports of 2026-09-14 (`…-diag-mkv-stutter.md`, `…-diag2-seek.md`) hold the evidence and VLC's code path. Still open: Wonder Woman's steady ~3.6 dropped pictures/s (2160p HEVC decode/display path, not the network), and the paused frame-back step, which now starts from the previous cue instead of the file start but still runs VLC's paused-seek rebuffer loop until the next input (pass-1 open question 2, D008).

**Pass 1d (2026-09-14):** three changes. (1) VLCKit patch 0018 (D015) coalesces TrueHD/MLP decoder frames into 20 ms blocks — the framework was rebuilt with `tools/vlckit-truehd/build.sh` (which now installs that patch too; 3 min when contribs are already built) and `Frameworks/VLCKit.xcframework` replaced. (2) The player requests display matching per stream (D016): frame rate from VLC's parse or the player's video track, HDR10/SDR from the server's flag; tvOS switches to 24 Hz for the 4K films. (3) Menu closes an open track panel instead of exiting. Numbers in `reports/2026-09-14-pass1d-truehd-audio-and-framerate.md`. Still open: Wonder Woman's ~3.6 dropped pictures/s (unchanged at 24 Hz — a decode/output limit for that stream, `…-diag3-wonder-woman.md` §B), the paused frame-back step (D008, pass-1 open question 2), and whether TrueHD is now audible (the owner's check).

**Pass 1e (2026-09-14):** Wonder Woman's judder is fixed.
- **Cause.** VLC's VideoToolbox reorder buffer released each mini-GOP's anchor before its last B-picture when only the max-latency count triggered a release (diag4), so the vout dropped 642 pictures per 3 minutes.
- **Fix.** VLCKit patch 0019 (D017) stops such releases at the arriving picture. VLC's own `dpb_test.c` expected the misorder and is corrected in the same patch. The framework is now built clean on Xcode 27.0 / tvOS SDK 27.0 with VLCKit's project tvOS target set to 26.0 (D018). `PACKAGE_ONLY=1` re-packages existing slices without recompiling.
- **Device proof on Home Theater, 3-minute traced runs.**
  - Wonder Woman: 0 dropped, 0 out-of-order releases, audio 50 blocks/s with no anomaly line.
  - Divergent: 0.
  - Magicians (H.264): in order, one start-up drop.
  - Stargate (MPEG-2, avcodec): 2 dropped / 5 shown late, as in pass 1d.
  - Seek: resumes in 0.393 s. Stargate frame step: unchanged.
- **Where it is written up.** `reports/2026-09-14-pass1e-reorder-fix.md` (rerun 4).
- **Owner-accepted.** TrueHD audibility and the TV's 24 Hz/HDR indication, the owner's checks, are accepted.
- **Still open after pass 1e.**
  - A single late picture at audio start / display mode switch (Wonder Woman, Magicians, after a seek).
  - The paused frame-back step (D008; passes 1f–1i).
  - An upstream report to VideoLAN.
- **Pushed.** Pass 1e's HEAD `b22f9c9` is on `origin/main`; the passes after it were local until the owner tested (pushed in pass 1l, `6bfdbad`).


**Pass 1f (2026-09-14): STOPPED at item 3.**
- **Stepping.** VLCKit's native `gotoPreviousFrame` steps exactly one picture per left click on Stargate Extended, both ways. Five back, five forward and five back stay on the file's 33/50 ms picture grid, the screenshots return to identical pictures, and there's no `RESET_PCR` loop.
- **Resume.** Play after stepping starts with every picture late by the whole paused time: 57.6 s measured, 57.7 s paused. VLC drops 713 pictures and the clock runs 01:04 → 02:23.
- **Cause.** Read from VLC's source (not instrumented): the paused previous-frame seek resets the main clock, which discards the pause date, so `vlc_clock_main_ChangePause` adds no delay on resume.
- **Not run.** Wonder Woman and Magicians.
- **Code state.** The native call is **not committed**; `PlayerModel.swift` is at HEAD with D008's seek-back, and the tested diff is `reports/logs/1f-playermodel-native-prevframe.diff`. **Home Theater still has the pass 1f build installed.** D008 unchanged.
- **Where it is written up.** `reports/2026-09-14-pass1f-frame-back.md`, with the fix options as question 1.

**Pass 1g (2026-09-14): STOPPED at step 4.**
- **Cause, from an instrumented libvlc on Home Theater.** The instrumentation was 32 log lines, since removed; the diff is `reports/logs/1g-libvlc-clock-instrumentation.diff`.
  - A paused previous-frame step does reset the main clock and drop its pause date, as pass 1f said. That's not what breaks resume, though: Play re-anchors the clock anyway.
  - The failure: each paused step re-anchors the clocks at the **pause date** (`es_out.c:1219`), and the demuxer then reads ahead while paused. On Stargate that was 33 → 115 s of stream in ~20 s, 38.7 MB queued.
  - Play flushes every stream except video, so VLC plays the stale pictures: 1 002 dropped, clock 00:33 → 01:59.
- **Controls.** Pausing with no step resumes correctly (delay applied, 0 dropped). Pass 1's seek-back does **not**: its paused rebuffer loop reads ahead the same way, and Play jumps to 03:32.
- **Why it stopped.** There are four candidate fix points (es_out anchor, input `MainLoop` demux gate, resume flush, clock pause date), so no patch 0020 was written. Candidates and lines are in `reports/2026-09-14-pass1g-frame-back-resume.md` §4.
- **State.**
  - `PlayerModel.swift` has the native back step, **uncommitted**, and Home Theater runs that build with an uninstrumented framework.
  - The libvlc tree is clean at `e50d9ac36a`. `Frameworks/`' device slice was relinked from clean objects (same sources, not byte-identical).
  - D008 unchanged; `tools/vlckit-truehd/` untouched. Not pushed.

**Pass 1h (2026-09-14), diagnosis only.** Pinned candidate B from pass 1g with one instrumented Stargate run on Home Theater.
- **What keeps the demuxer reading while paused.** `next_frame_need_data` stays true. The first native back step flushes the subtitle decoder while paused, which gives it `frames_countdown = 1` (`decoder.c:2789–2793`). It then asks for data (12 288 requests).
- **Why nothing clears it.** es_out drops every non-video block in frame-step mode (`es_out.c:3164–3169`), so the request is never met or cleared (`decoder.c:2686–2687`). Only Play clears it (`INPUT_CONTROL_SET_STATE`), and Play's resume flush sets it again at once.
- **The rate.** It follows the pause-date anchor: flat out until the stream catches up to wall time since that anchor (PCR 134.5 s at +100 s), then 1×. From the trace, A isn't needed once B stops those reads.
- **Candidates.** B1–B5 with lines and risks are in `reports/2026-09-14-pass1h-demux-pause-diagnosis.md` §4. No patch written.
- **State.**
  - `Frameworks/VLCKit.xcframework` is again the full recipe's own build (21:55–21:58; both slices `MinimumOSVersion 26.0`, `minos 26.0 sdk 27.0`; `_ff_truehd_decoder` on the device slice).
  - libvlc is at `51f8302c27`, the same tree as `e50d9ac36a` (the recipe's `git am` rewrites hashes).
  - `PlayerModel.swift` is at HEAD, and Home Theater runs that build. D008 unchanged. Not pushed.

**Pass 1i (2026-09-14): STOPPED at step 8.**
- **Patch 0020** (`tools/vlckit-truehd/0020-es_out-forward-next-frame-need-data-only-from-stepped-es.diff`, design B1, 2 lines in `src/input/es_out.c`): while frame stepping, only the stepped video ES's need-data request reaches the input, and a request standing when stepping starts is cleared. `build.sh` installs it after 0019. VLC's player tests: 19/20 before and after (the one failure, `attachments`, is the host test build's missing BMP encoder).
- **Framework.** Full recipe, 22:43–22:46, 20 patches, libvlc `03632d2eb8`. Both slices `MinimumOSVersion 26.0` and `minos 26.0 sdk 27.0`; `_ff_truehd_decoder` on the device slice; no instrumentation strings.
- **What 0020 fixes.** An instrumented Stargate run logged the flag directly: never set while paused, reads only inside each step's own rebuffer. The clean runs show 0 reads while paused outside a step, against 22 700 in pass 1h, and the clock at Play+60 s is 01:34, not 03:36.
- **Why it stopped.** Stargate after five back steps drops 21 pictures and starts audio 1 477 ms after the first picture. After five forward steps: 26 dropped, 1 361 ms. The no-step control in the same session: 0 dropped, 176 ms. Play re-anchors the clock at the first PCR read after resume (~1 s past the displayed picture) while the video fifo still starts at the displayed picture. Wonder Woman, Divergent, Magicians, Food That Built America, step 7, step 9 and step 11 were not run.
- **State.** `PlayerModel.swift` carries the 1f native back step, **uncommitted**; Home Theater runs that build with the clean recipe framework. D008 unchanged, no new decision. Report: `reports/2026-09-14-pass1i-frame-back-fix.md`. Not pushed.

**Pass 1j (2026-09-14): STOPPED at step 1.** An instrumented Stargate run (pause, five back steps, Play, 60 s, second pause ~80 s, Play) settles the resume trace; report `reports/2026-09-14-pass1j-frame-back-resume-fix.md`.
- **Pictures — pass 1i's cause confirmed.** At Play the picture on screen is `pf_pts=33834001`. `EsOutChangePosition` resets the input clock, and the demuxer's first PCR becomes its reference (`input_clock reference stream=34785001`). The buffering end anchors the main clock there (`set_first_pcr ts=34785001`). Every queued picture below it is late: 21 dropped (`vout drop pts=33917001` … `34751001`), and the displayed one renders 955 ms late.
- **Audio — pass 1i's "1.4 s delay" was a measuring error.** The tvOS audio output starts 92 ms after the first picture (`avs startNow` at +101.6 ms). The trace's first audio render event is the output's 1 s periodic timing report (`time_observed time=1000129` at +1563 ms). The first audio block is PTS 34.912 s, so a clock started at the displayed picture would put ~1.1 s of silence under the first pictures. That's why step 2 was not written.
- **Second pause (0020's gap, step 7's case).** The resume flush sets the need-data flag again after frame stepping ends, and it stays set through a later plain pause: 3 967 demux calls while paused, PCR 98.4 → 182.4 s. Resume 2 was still clean (delay applied, 0 dropped).
- **Origin (step 13).** After `git fetch`, `origin/main` is `b22f9c9` (pass 1e rerun 4) and local `main` is 4 commits ahead, so pass 1i's "pushed" line was right.
- **State.** No patch 0021. libvlc clean and `Frameworks/` rebuilt by the full recipe (20 patches, as pass 1i). Home Theater runs HEAD + the uncommitted 1f diff. D008 unchanged. Not pushed.

**Pass 1k (2026-09-14/15): native frame-back closed out.** Report `reports/2026-09-14-pass1k-frame-back-close.md`.
- **Frame-back state.** While paused, a left/right click steps exactly one picture through VLCKit's native previous/next-frame (D008 revised; the seek-back is superseded). `PlayerModel.swift` carries it, committed. It needs patch 0020 (D019), which is in the 20-patch recipe and in `Frameworks/`. Exact on Home Theater for back and forward steps on Stargate (avcodec), Divergent and Wonder Woman (VideoToolbox): each click shows a new picture and the returning clicks show identical pictures (MAD 0).
- **Resume matrix** (five films × back / forward / no step, ~80 s pauses): clock at Play+60 s 01:33–01:35 in every run (01:34–01:35 after steps); no-step controls 0 dropped.
- **Known and accepted (D020), not defects.**
  1. Play after any frame step drops the pictures below the demuxer's clock start: 21–29 after five back steps, 26–45 after five forward steps (~0.9–1.5 s of picture; the 29.97 fps episodes drop more). E1/E2 rejected.
  2. 0020's remaining gap: Play's flush after stepping sets the need-data flag again, so a later plain pause with a subtitle track selected reads ahead (~84 s in pass 1j's run; that resume was clean).
- **Audio start** has no timestamped event in the clean build and is not measured; pass 1k traces the first audio block's scheduled time instead. Pass 1i's audio figures carry a correction note (they were the tvOS output's periodic timing report).
- **VideoLAN.** Draft `reports/logs/1k-upstream-videolan-draft.md`, not submitted.
- **Push.** The owner tested native frame-back on Home Theater and accepted it; pushed in pass 1l.

**Pass 2a (2026-09-15): touch-surface scrubbing — STOPPED at step 5.** Report `reports/2026-09-15-pass2a-scrubbing.md`.
- **Built, uncommitted.** A horizontal drag pauses and shows a scrub bar (frame 10's timeline row, target elapsed/remaining, a start mark), the picture follows the target by paused seeks (one per 250 ms and one on lift), click lands and plays, Menu returns. The diff is in the working tree and saved as `reports/logs/2a-scrub-app.diff`. Home Theater runs it (no harness hook).
- **Why it stopped.** Landing hits the paused-seek read-ahead (pass 1g's seek-back loop), on Magicians S1E1 (MP4, no subtitle track): after the last paused seek VLC laps its rebuffer 12 times in 1.3 s (`PCR is called … late`, `ES_OUT_RESET_PCR`), reading PCR 238.2 → 269.0 s for a 238.6 s target; Play then starts at the read-ahead end (first picture PTS 266.3 s; clock 04:29 at +3 s for a 03:59 target). Trace in `reports/logs/2a-analysis.txt`. No fix; 23 of the 24 matrix runs and the step-4 controls not run.
- **Drags can't be scripted on the remote.** XCUIRemote has no touch-surface API; the owner chose a hybrid: an uncommitted Page Up/Down hook plays a scripted drag through the model (`reports/logs/2a-harness-app.diff`), plus a physical check by the owner (not done — stopped first).

**Pass 2d (2026-09-15): the owner's scrub flow — committed (D021 revised).** Report `reports/2026-09-15-pass2d-owner-flow.md`.
- **The owner's defect (real remote): a paused swipe did not scrub.** The pan waited for the left/right swipe recognizers to fail, so every paused flick was recognized as a side swipe and dropped by D008's paused rule (`right swipe while paused: no action (frame step is on click)`, 19 times in the owner's session; `[scrub] begin` 4 times). Touches around a click, or after swipe skips, also started scrubs while playing.
- **The flow now.** Play/Pause pauses. Paused: a swipe or drag scrubs (the picture holds, nothing seeks until landing); a left/right click steps one frame. Play/Pause or a click on the surface lands at the target and plays. Menu cancels and stays paused where the drag began. Playing: a drag does nothing; skips unchanged. 25% of the running time per width; target 1 s short of the end. `PlayerHost.swift` (the pan runs alongside the swipes and begins only while paused), `PlayerModel.swift` (the scrub appears once the target moves; no scrub while playing; Menu stays paused).
- **Proof on Home Theater** (drags scripted through the model — XCUIRemote cannot touch the surface): 24 paused scrubs on Stargate, Wonder Woman, Divergent, Magicians S1E1 — 16 landings −74…+94 ms from the target, 8 Menu cancels paused at the start; 8 drags while playing refused; skips exact; 5 + 5 clicks one picture each on all four (pixel comparison). One Divergent run lost a Play/Pause press between XCTest and the app (no app line, VLC kept playing); re-run once at the owner's call, clean.
- **The owner must still try the gesture by hand** (report §6); nothing is pushed until then.

**Pass 2c (2026-09-15): preview-playhead scrub — landed and committed (D021).** Report `reports/2026-09-15-pass2c-scrub-preview.md`.
- **Behaviour.** A horizontal drag on the touch surface pauses and shows the scrub bar; the picture holds, nothing seeks during the drag or on lift; click or Play/Pause plays and then seeks once to the target; Menu cancels with no seek and restores the play state. 25% of the running time per surface width; target stops 1 s short of the end. `PlayerHost.swift` (pan), `PlayerModel.swift` (scrub state, land, cancel), `PlayerScreen.swift` (bar).
- **Proof on Home Theater** (drags scripted through the model by an uncommitted Page Up/Down hook — `reports/logs/2c-harness-app.diff`; XCUIRemote cannot touch the surface): 48 scrubs on Stargate, Wonder Woman, Divergent and Magicians S1E1 — 32 landings with the first picture −72…+104 ms from the target, 16 cancels within 0.81 s; skips, frame steps and Menu-closes-panel unchanged on all four films.
- **Still open.** The owner's test of the gesture on the real remote (not yet done; push waits for it). A pause after a landing reads the stream at 1× while paused, up to ~36 s (no effect on landings; not diagnosed).

**Pass 2b (2026-09-15): fast seek on the scrub path — STOPPED at step 2, owner's call.** Report `reports/2026-09-15-pass2b-fast-seek.md`, evidence `reports/logs/2b-fast-seek-recon.txt`.
- **Why it can't be scoped as asked.** Nothing in this libvlc reads the `input-fast-seek` option (declared, created on the input, read only by desktop GUI prefs), so a media option is inert; VLCKit has no seek-speed setting (`setTime:` always passes `b_fast = NO`). Fast vs precise is per seek: `libvlc_media_player_set_time(p, t, b_fast)`. The only scoped route is VLCKit's private `_playerInstance` plus that exported C call; the owner chose to stop rather than use it.
- **State.** Nothing applied, built, installed or run. Tree and Home Theater as after pass 2a (scrub diff uncommitted). The scrub code is not committed: pass 2a's ~30 s landing overshoot stands.

**Pass 2f (2026-09-15): patch 0021 (C1) with a moving scrub picture — STOPPED at step 9.** Report `reports/2026-09-15-pass2f-scrub-live-picture.md`, evidence `reports/logs/2f-analysis.txt`, `reports/logs/2f-vlc-tests.txt`.
- **What works.** 0021 (`es_out.c:3661`, no late-PCR compensation while paused; one line) passes VLC's host tests unchanged. The full recipe built it with 21 patches; both slices check. On Home Theater, 20 paused scrubs on four films had 0 PCR-late lines, and every landing was within −81…+305 ms of its target. Steps 7–8 (skips, frame steps, panels, paused track switches, plain pause, edition/episode change) matched HEAD.
- **Why it stopped.**
  - **Magicians (MP4):** every ending logged a `clock gap`, and VLCKit's time froze after 4 of 5, so the overlay clock and the next drag's start were stale.
  - **The picture did not track during drags** on Wonder Woman and Divergent (HEVC: 1–5 of 8–9 seeks shown), nor on Magicians scrub 3's lift.
  - **Stargate scrub 4** dropped 7 pictures at landing.
- **State, uncommitted.**
  - `tools/vlckit-truehd/` (0021, `build.sh`, README), the app change and the harness. Copies are in `reports/logs/2f-*`.
  - `Frameworks/` and the libvlc tree carry 21 patches, and Home Theater runs the 0021 build with the harness hook.
  - D021 and DECISIONS unchanged. Nothing pushed.

**Pass 2e (2026-09-15): why paused seeks can't make the picture follow the thumb — diagnosis only.** Report `reports/2026-09-15-pass2e-scrub-seek-diagnosis.md`, evidence `reports/logs/2e-analysis.txt`.
- **Cause (instrumented libvlc, Magicians S1E1 and Stargate on Home Theater).**
  - A paused seek's rebuffer anchors the input clock at the **pause date** (`es_out.c:1219`). The next PCR is late by about (time since the pause − pts_delay), so the late branch resets and rebuffers without moving the demuxer (`es_out.c:3661–3721`).
  - Lap after lap reads forward, and past the 5 s `clock-jitter` cap the laps run until Play. Play-only landings played from 452 s for a 239 s target (Magicians) and from 667 s for 333 s (Stargate).
  - A single seek on lift laps the same way, so seek count and pace don't matter. The need-data flag isn't involved on Magicians; Stargate's subtitle request adds paused reads.
- **What still works.** HEAD's landing (play, then one seek) lands on the target even after laps. But during the hold the picture drifts forward while the bar shows the target.
- **Candidates.** C1 (`es_out.c:3661`, skip late compensation while es_out is paused) is the narrowest; not implemented. No decision.
- **State.** libvlc clean, and `Frameworks/` rebuilt by the full recipe (20 patches; both slices `MinimumOSVersion 26.0`, `minos 26.0 sdk 27.0`; `_ff_truehd_decoder`; no trace strings). The app is at HEAD and installed on Home Theater. Committed locally, not pushed.

**Pass 2g (2026-09-15): 0021 dropped, the scrub gained timeline thumbnails — done.** Report `reports/2026-09-15-pass2g-scrub-thumbnails.md`, evidence `reports/logs/2g-*`, screenshots `reports/screenshots/2g/`.
- **0021 is gone** (D022): the patch file, its `build.sh` step and its README line are removed, the app is back at HEAD's scrub, and the full recipe rebuilt `Frameworks/` at **20 patches** (20 `Applying:` lines, `ARCHIVE SUCCEEDED` ×2, libvlc clean at `6d623583` with `es_out.c:3661` back to its HEAD condition; both slices `MinimumOSVersion 26.0`, `minos 26.0 sdk 27.0`, `_ff_truehd_decoder`, no instrumentation strings). A stale `0021-….patch` was still sitting in `~/vlckit-build/VLCKit/libvlc/patches/` and had to be deleted first, or the recipe would have re-applied it.
- **The thumbnail** (D021 revised again): during a paused drag the server's still nearest the target shows above the bar and changes with it; where no still exists, nothing shows. `ThumbStrip.swift` is new; the index is fetched once per detail screen (never polled, never re-fetched) and sheets as needed.
- **On Home Theater** (Stargate Extended, one session, 191.5 s, passed): one index line, two sheet fetches (185/115 ms) for four targets, the thumbnail tracking 03:59 → 05:32 → 08:08 → 06:50, exact drag rates, landing 0 ms from the target, Menu cancel 0 ms back at the drag's start and still paused, and five frame steps retraced to pixel-identical screenshots.
- **Owner-accepted.** The owner tried the gesture by hand on Home Theater — the push gate standing since pass 2c — and **accepted the scrub and its thumbnails**; pushed in pass 2h.
- **Still open:** which file a multi-edition movie or multi-episode show should fetch an index for; and that a file's **first** visit shows no thumbnails, because that first request is what starts generation.

**Pass 2h (2026-09-15): pushed.** The owner tested the touch-surface scrub with its timeline thumbnails on Home Theater and **accepted it** (D021 revised again, D022). `main` was pushed to `origin` as a fast-forward, no force: `e9df636..1e13538`, **seven commits** (passes 2a–2g). After a fetch, local `main`, `origin/main` and the live remote ref were all `1e13538317da`. This note's commit was pushed the same way, so HEAD is on `origin/main`. `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`): nothing under `Frameworks/` is tracked on any ref, so the 725 MB framework was not pushed and never has been. **Deliberately not pushed, and still uncommitted:** the pass 2g UI-test harness (`Marlin Media TVUITests/Diag2gUITests.swift`) and its `PlayerHost.swift` Page Up / Page Down hook, which exist only to script drags that XCUIRemote cannot perform — copies are committed as `reports/logs/2g-harness-Diag2gUITests.swift.txt` and `reports/logs/2g-harness-hook.diff`.

**Pass 1l (2026-09-15): pushed.** The owner tested native frame-back while paused on Home Theater and **accepted it** (D008 revised, D019, D020). `main` was pushed to `origin` as a fast-forward, no force: `b22f9c9..6bfdbad`, six commits (passes 1f–1k). After a fetch, local `main` and `origin/main` were both `6bfdbad69e9f`. This note's commit was pushed the same way, so HEAD is on `origin/main`. `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`), and nothing under `Frameworks/` has ever been tracked or pushed.
