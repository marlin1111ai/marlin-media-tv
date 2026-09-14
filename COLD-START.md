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
- **Xcode:** 26.6 (17F113), tvOS 26.5 SDK. Bundle id `com.marlin1111.marlin-media-tv`, team
  `C879JNVK7Z`, automatic signing (both read from Marlin DVR TV).

## Toolchain facts

- **VLCKit:** a custom build of VideoLAN's VLCKit 4.0.0-a24 with the TrueHD/MLP decoder compiled in
  (D012). It lives at `Frameworks/VLCKit.xcframework` (git-ignored, 716 MB; tvOS device + simulator
  slices) and the Xcode project links and embeds it by path — the Swift package is gone (D013).
  Built by `tools/vlckit-truehd/build.sh` at `~/vlckit-build` (VideoLAN's scripts cannot take spaces
  in paths) from libvlc master 5dd4aebda + VLCKit's 17 patches, patch 0007 minus its mlp hunk;
  ffmpeg 9.0 (`Lavc63.1.100`), Video Toolbox decoding, `samplebufferdisplay` video output,
  `avsamplebuffer` audio output. Reported version string: `4.0.0-dev Otto Chriek`.
- **VLCKit build prerequisites (not the app's):** python.org Python 3.14.7 at
  `/Library/Frameworks/Python.framework` (installed 2026-09-13; VideoLAN's script looks only there)
  and GNU make 4.4.1 built into `~/vlckit-build/tools` and passed as `VLC_PATH` (Xcode's make 3.81
  breaks the jobserver with VLC's ninja). A full build took 9 min 13 s on the M2 Ultra; the first
  run also builds VLC's host tools (about 8 min more). `~/vlckit-build` is 22 GB.
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
