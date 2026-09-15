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
  `/api/shows`, `/api/shows/{id}`, `/api/videos`, `/api/artwork/…`, `/stream/{fileId}`.
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

**Pass 1l (2026-09-15): pushed.** The owner tested native frame-back while paused on Home Theater and **accepted it** (D008 revised, D019, D020). `main` was pushed to `origin` as a fast-forward, no force: `b22f9c9..6bfdbad`, six commits (passes 1f–1k). After a fetch, local `main` and `origin/main` were both `6bfdbad69e9f`. This note's commit was pushed the same way, so HEAD is on `origin/main`. `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`), and nothing under `Frameworks/` has ever been tracked or pushed.
