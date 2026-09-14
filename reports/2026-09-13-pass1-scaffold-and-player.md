# Pass 1: scaffold, library screens, VLCKit player, first device-proof — 2026-09-13

**Result: built, installed and proven on Home Theater.** The library (3 movies, 2 shows, empty
Videos), sort by Title and Year, the movie / show / video detail screens, the edition picker and
the VLCKit player all run on the Apple TV against the live server at 192.168.1.250:8093. All four
MKVs and a Magicians episode played; skips, pause, frame step, and the audio and subtitle panels
were exercised and logged. Two findings need the owner: **this VLCKit build cannot decode
TrueHD** (Wonder Woman plays on its AC-3 5.1 track), and **the seek-based frame-back step shows
a wrong frame and destabilises this VLC alpha over HTTP** (the native forward step is fine).

Committed locally on `main` (one commit). **Not pushed** — the owner tests first.

## Files touched, by step

| Step | Files |
|---|---|
| 1 | `.gitignore` (the Xcode/Swift ignore set from Marlin DVR TV), `git init -b main`, remote `origin` = https://github.com/marlin1111ai/marlin-media-tv.git |
| 2 | `Marlin Media TV.xcodeproj/project.pbxproj` (written by hand: objectVersion 71, synchronized groups, tvOS 26.0, bundle id `com.marlin1111.marlin-media-tv`, team `C879JNVK7Z`, automatic signing), `project.xcworkspace/contents.xcworkspacedata`, `xcshareddata/xcschemes/Marlin Media TV.xcscheme`, `Info.plist` (`NSAllowsLocalNetworking` for plain HTTP to the LAN server), `Marlin Media TV/MarlinMediaTVApp.swift` |
| 3 | `project.pbxproj` (`XCRemoteSwiftPackageReference` https://code.videolan.org/videolan/VLCKit, `exactVersion 4.0.0-a24`; product `VLCKit` linked), `project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (revision `6cbc4e7b248aa51ec0906697abb30ecae47194b7`) |
| 4 | `Marlin Media TV/ServerAPI.swift`, `Models.swift`, `ServerImage.swift`, `LibraryModel.swift` |
| 5 | `Marlin Media TV/LibraryScreen.swift`, `Theme.swift`, `ContentView.swift` |
| 6 | `Marlin Media TV/MovieDetailScreen.swift` (frames 06 + 07) |
| 7 | `Marlin Media TV/ShowDetailScreen.swift` |
| 8 | `Marlin Media TV/VideoDetailScreen.swift` |
| 9 | `Marlin Media TV/PlayerModel.swift`, `PlayerHost.swift`, `PlayerScreen.swift`, `PlayRequest.swift`, `EvidenceLog.swift` |
| 10 | `COLD-START.md`, `DECISIONS.md` (D001–D011 verbatim), this report, `reports/screenshots/*.jpg` (23), `reports/logs/*.log` (4) |
| 11 | device build + install (below); `Marlin Media TVUITests/EvidenceUITests.swift` — the evidence harness that drove the remote and took the screenshots (the Marlin DVR TV convention) |
| — | `Design/` — the owner's zip unzipped in place, zip kept |

Nothing was installed on the Mac. No CocoaPods, no xcodegen, no brew.

## Evidence

### Xcode device build (final, after all fixes)

```
$ xcodebuild build -project "Marlin Media TV.xcodeproj" -scheme "Marlin Media TV" \
    -destination 'platform=tvOS,name=Home Theater' -derivedDataPath build/DerivedData -allowProvisioningUpdates
ProcessProductPackaging "" build/DerivedData/Build/Intermediates.noindex/Marlin Media TV.build/Debug-appletvos/Marlin Media TV.build/Marlin Media TV.app.xcent (in target 'Marlin Media TV' from project 'Marlin Media TV')
CodeSign build/DerivedData/Build/Products/Debug-appletvos/Marlin Media TV.app (in target 'Marlin Media TV' from project 'Marlin Media TV')
Validate build/DerivedData/Build/Products/Debug-appletvos/Marlin Media TV.app (in target 'Marlin Media TV' from project 'Marlin Media TV')
** BUILD SUCCEEDED **
```
No warnings from the app's own sources (the only warning is Xcode's AppIntents metadata note).
Package resolution: `Resolved source packages: VLCKit: https://code.videolan.org/videolan/VLCKit @ 4.0.0-a24`.
The app bundle embeds `Frameworks/VLCKit.framework`; VLCKit reports itself as `4.0.0-dev Otto Chriek`.

### Install and launch on Home Theater

```
$ xcrun devicectl device install app --device <Home Theater> "build/DerivedData/Build/Products/Debug-appletvos/Marlin Media TV.app"
App installed:
• bundleID: com.marlin1111.marlin-media-tv
$ xcrun devicectl device process launch --console --terminate-existing --device <Home Theater> com.marlin1111.marlin-media-tv
Launched application with com.marlin1111.marlin-media-tv bundle identifier.
[library] loaded 3 movies, 2 shows, 0 videos from http://192.168.1.250:8093
$ xcrun devicectl device info apps --device <Home Theater> --bundle-id com.marlin1111.marlin-media-tv
Name              Bundle Identifier                Version   Bundle Version
Marlin Media TV   com.marlin1111.marlin-media-tv   1.0       1
```

### Library (frames 01, 02, 04, 05) — `EvidenceUITests.test1_Library`, passed

Screenshots in `reports/screenshots/`:
- `01-library-movies-title.jpg` — Movies tab, sort Title: Divergent, Stargate, Wonder Woman with real posters; 4K + HDR badges on Divergent and Wonder Woman (from `resolution_label` / `hdr`), none on Stargate (SD); focus on the first poster with the frame-01 ring, lift and glow.
- `05-sort-open.jpg` — the sort control open, Title checked with the accent mark, Year below.
- `01b-library-movies-year.jpg` — after choosing Year (control reads "SORT Year"). In that run the tab had followed focus to Videos on the way to the control (see "tabs switch on click" below); the order under Year on the server's data is Wonder Woman 2017, Divergent 2014, Stargate 1994 (`LibraryModel.sortedMovies`).
- `02-library-shows.jpg` — TV Shows: The Food That Built America (no year on the server), The Magicians 2015.
- `04-videos-empty.jpg` — "No videos yet" with the frame-04 copy.

### Movie detail, picker, playback — the four MKVs and one episode

Every playback below is the server's original file over `/stream/{id}` (206 Partial Content, `video/x-matroska` / `video/mp4`), decoded on the Apple TV. Log files are the app's per-launch `Library/Caches/marlin-media-tv.log` (VLCKit's file logger at debug level plus the app's `[player]` lines), copied off with `devicectl device copy from`.

**Divergent** (`06-movie-detail-divergent.jpg`, `10-player-divergent.jpg`, `reports/logs/divergent-vlckit.log`) — 3840×1600 HEVC Main 10, HDR, DTS 7.1:
```
[player] request Divergent — Divergent (2014).mkv · 4K HDR · DTS 7.1 — http://192.168.1.250:8093/stream/1
[DBG] ES track added: 'video/1' (fourcc: 'hevc')
[DBG] ES track added: 'audio/2' (fourcc: 'dts ')
[DBG] using decoder device module "videotoolbox"
[WARN] forcing output chroma (kCVPixelFormatType): x420
[INF] Using Video Toolbox to decode 'hevc'
[DBG] using vout display module "samplebufferdisplay"
[DBG] original format sz 3840x1600, of (0,0), vsz 3840x1600, 4cc CVPP, sar 1:1, orient: normal
[DBG] codec (dca) started
[DBG] using audio decoder module "avcodec"
[WARN] failed to start passthrough audio output, failing back to linear format
[DBG] Output on HDMI, channel count: 8
[DBG] output 'f32l' 48000 Hz 3F2M2R/LFE frame=1 samples/32 bytes
[DBG] format: 48000 rate, 8 nch, 4 bps, fl32
[player] length 8379371 ms
[player] state Playing at 0 ms
[player] pause (select) at 27000 ms → state Paused at 27509 ms → play (select) → Playing
```
Video: Video Toolbox, 10-bit 4:2:0 (`x420`), `samplebufferdisplay`. Audio: DTS decoded by avcodec (`dca`), passthrough refused by the audio output, handed to tvOS as 32-bit float PCM, 8 channels, 48 kHz, HDMI channel count 8.

**Stargate, Extended and Theatrical** (`06-movie-detail-stargate.jpg`, `07-edition-picker.jpg`, `10-player-stargate-extended.jpg`, `10-player-stargate-theatrical.jpg`, `reports/logs/stargate-both-editions-vlckit.log`) — 720×480 MPEG-2, AC-3 5.1 + AC-3 2.0, one SRT:
```
[player] request Stargate — Extended · SD · AC-3 5.1 — http://192.168.1.250:8093/stream/2
[player] request Stargate — Theatrical · SD · AC-3 5.1 — http://192.168.1.250:8093/stream/3
[DBG] ES track added: 'video/1' (fourcc: 'mpgv')      [DBG] ES track added: 'audio/2' (fourcc: 'a52 ')
[DBG] ES track added: 'audio/3' (fourcc: 'a52 ')      [DBG] ES track added: 'spu/4' (fourcc: 'subt')
[DBG] codec (mpeg2video) started   [DBG] using video decoder module "avcodec"
[DBG] codec (ac3) started          [DBG] using audio decoder module "avcodec"
[WARN] failed to start passthrough audio output, failing back to linear format
[DBG] Output on HDMI, channel count: 6
[DBG] output 'f32l' 48000 Hz 3F2M/LFE frame=1 samples/24 bytes
[DBG] format: 48000 rate, 6 nch, 4 bps, fl32
[DBG] using vout display module "samplebufferdisplay"
[player] track selected type=2 selected=spu/4 unselected=      ← VLC turned the SRT track on by itself
```
Both editions played (the picker chose Extended, then Theatrical). MPEG-2 is software-decoded (avcodec), AC-3 5.1 decoded to 6-channel float PCM at 48 kHz.

**Wonder Woman** (`10-player-wonder-woman.jpg`, `11-audio-panel.jpg`, `11-audio-truehd-selected.jpg`, `12-subtitle-panel.jpg`, `14-skip-back.jpg`, `15-skip-forward.jpg`, `10-player-wonder-woman-after-switch.jpg`, `reports/logs/wonder-woman-vlckit.log`) — 3840×2160 HEVC Main 10, HDR, TrueHD 7.1 + AC-3 5.1 ×2, one PGS:
```
[player] request Wonder Woman — Wonder Woman (2017).mkv · 4K HDR · TrueHD 7.1 — http://192.168.1.250:8093/stream/4
[DBG] |   |   |   + Track CodecId=A_TRUEHD
[DBG] ES track added: 'audio/2' (fourcc: 'mlpa')
[DBG] using audio packetizer module "mlp"
[DBG] codec not found (TrueHD Audio)
[ERR] Codec `mlpa' (TrueHD Audio) is not supported.
[ERR] VLC could not decode the format "mlpa" (TrueHD Audio)
[DBG] codec (ac3) started          [DBG] using audio decoder module "avcodec"
[WARN] failed to start passthrough audio output, failing back to linear format
[INF] Using Video Toolbox to decode 'hevc'    [WARN] forcing output chroma (kCVPixelFormatType): x420
[DBG] Output on HDMI, channel count: 6
[DBG] output 'f32l' 48000 Hz 3F2M/LFE frame=1 samples/24 bytes
[player] track selected type=0 selected=audio/3 unselected=     ← VLC's own choice after TrueHD failed
```
**TrueHD does not decode in VLCKit 4.0.0-a24's tvOS build** (no `mlp` decoder in its avcodec, and no bitstream passthrough on tvOS). Selecting the TrueHD track in the Audio panel repeats the error and leaves no audio track selected; the AC-3 5.1 tracks decode to 6-channel PCM. See "Open questions".

### Frame step while paused, both directions (Stargate Extended) — `test3_Stargate`, rerun, passed

`13-paused-stargate.jpg` (pause glyph, "Paused", the click hints), `13-frame-forward-stargate.jpg` ("Frame +1" indicator), `13-frame-back-stargate.jpg` ("Frame −1" indicator). Positions from the log, forward first:
```
9:56:57.342 [player] pause (select) at 19000 ms → state Paused at 19409 ms
9:56:59.974 [framestep] +1 gotoNextFrame before=19410 ms
9:57:00.404 [framestep] +1 after(400 ms)=19520 ms
9:57:02.214 [framestep] +1 gotoNextFrame before=19520 ms
9:57:02.633 [framestep] +1 after(400 ms)=19570 ms
9:57:06.222 [framestep] −1 seek before=19570 ms frame=33 ms (500000/16683 fps) target=19537 ms
9:57:06.648 [framestep] −1 after=19537 ms
9:57:09.442 [framestep] −1 seek before=19537 ms frame=33 ms (500000/16683 fps) target=19504 ms
9:57:09.869 [framestep] −1 after=19504 ms
```
Forward (VLC's native next-frame): the reported position moves by roughly a frame (19410 → 19520 → 19570; VLC's time has coarse granularity on MPEG-2) and the picture stays on the same title card, as a one-frame step should. Frame duration came from VLC's video track (500000/16683 = 29.97 fps → 33 ms).

Back (the D008 seek): the reported position lands on the target, **but the picture is wrong and VLC destabilises**. After each back seek VLC logs
```
[ERR] reading while paused (buggy demux?)
[DBG] resuming
```
re-requests the stream, then loops `ES_OUT_RESET_PCR → Received first picture → Stream buffering done → ES_OUT_SET_(GROUP_)PCR is called N ms late (pts_delay increased …)` — 117 and 147 "next frame stepped" callbacks at 19537 and 19504 ms in this run — and the frame it shows is a later title card ("In association with Carolco") than the paused one ("Le Studio Canal+ / Centropolis"), which a 33 ms step back cannot reach. In the first run, with the back step done before the forward step, the following native next-frame displayed a frame from 112746 ms (`[framestep] +1 gotoNextFrame before=112746 ms`, first-run log kept in the xcresult, not committed).

### Audio and subtitle switching (Wonder Woman) — `test4_WonderWoman`, rerun, passed

```
9:58:58.158 [audio] panel opened: audio/2 English TrueHD 7.1 | audio/3 English AC-3 5.1 ✓ | audio/4 English AC-3 5.1
9:59:03.285 [audio] select audio/2 Surround 7.1 - [English] TrueHD Audio ch=8
9:59:03.382 [player] track selected type=0 selected= unselected=audio/3
            [ERR] Codec `mlpa' (TrueHD Audio) is not supported.
9:59:03.597 [audio] now selected: audio=[] text=[]
9:59:18.432 [audio] select audio/4 Surround 5.1 - [English] Audio Coding 3 (AC-3) ch=6
9:59:18.437 [player] track selected type=0 selected=audio/4 unselected=
9:59:18.754 [audio] now selected: audio=["audio/4"] text=[]
9:59:27.586 [subtitles] panel opened: spu/5 English BD PGS subtitles
9:59:32.669 [subtitles] select spu/5 Track 0 - [English] BD PGS subtitles
9:59:32.672 [player] track selected type=2 selected=spu/5 unselected=
            [DBG] libavcodec codec (pgssub) started
9:59:32.982 [subtitles] now selected: audio=["audio/4"] text=["spu/5"]
```
Skips while playing, same run: `[skip] +30 s (click) before=29655 ms target=59655 ms → after=59655 ms`; `[skip] -10 s (click) before=59655 ms target=49655 ms → after=49667 ms` (`15-skip-forward.jpg`, `14-skip-back.jpg`).

### The Magicians S1E1 — `test5_MagiciansEpisode`, passed

`08-show-detail-magicians.jpg` (Season 1, 13 episodes with stills, numbers, titles, durations, synopses), `10-player-magicians-s01e01.jpg`, `reports/logs/magicians-s01e01-vlckit.log`:
```
[player] request The Magicians — S1 E1 · Unauthorized Magic — http://192.168.1.250:8093/stream/8
[INF] Using Video Toolbox to decode 'h264'   [WARN] forcing output chroma (kCVPixelFormatType): 420v
[DBG] codec (aac) started   [DBG] using audio decoder module "avcodec"
[DBG] output 'f32l' 44100 Hz Stereo frame=1 samples/8 bytes
[DBG] Output on HDMI, channel count: 2
[player] length 3128562 ms → Playing → pause/play at 22000 ms → dismiss
```

### What could not be tested live, and what was traced instead

- **HDR10 metadata.** VLC's debug log carries no line naming ST 2084 / mastering-display metadata for either 4K file; what it shows is the 10-bit path (`x420` from Video Toolbox into `samplebufferdisplay`). Whether the Apple TV switched its output to HDR is the owner's HDR-indicator check (D011).
- **The Denon.** All audio reaches tvOS as multichannel float PCM (`failed to start passthrough audio output, failing back to linear format` on every file), so the receiver should show a multichannel PCM input, not DTS or Dolby. Owner's panel check (D011).
- **Videos list and video detail (frames 03, 09).** The server has no videos, so only the empty state ran on the device; `VideoList`, `VideoRowLabel` and `VideoDetailScreen` are traced against `videoJSON` in the server source (`server/api.go`) and compile, nothing more.
- **Swipes.** `XCUIRemote` can only click; the harness drove skips with edge clicks (`[skip] … (click)`). The swipe recognizers (`UISwipeGestureRecognizer`, indirect touches) are wired the way Marlin DVR TV's notes say a physical swipe arrives, but no swipe reached them in this pass. Same for "overlay appears on touch": touches were not exercised; the overlay was shown by pause/resume.
- **Can't-reach-server (frame 17).** Not exercised on the device (the server was up throughout); the state is reached by any `APIError` and shows the error text in full.
- **End of file / auto-dismiss on VLC "Stopped".** Not reached.

## Open questions for the owner

1. **TrueHD.** VLCKit 4.0.0-a24 (tvOS) cannot decode TrueHD (`mlpa`) and cannot bitstream it. Wonder Woman plays on its AC-3 5.1 core. Options: accept AC-3 for TrueHD titles; try the D003 fallback (CocoaPods TVVLCKit 3.7.3 — untested whether its build carries the `mlp` decoder); wait for a newer 4.0 alpha. Which?
2. **Frame back.** D008's seek-back is not just approximate on this build: it shows a later frame and puts VLC into a rebuffer loop over HTTP. VLCKit 4.0.0-a24 has a native `gotoPreviousFrame` (with a `previousFrameSteppedWith:` callback and a `CannotSeekBack` result). Not tried, because D008 records the seek. Should pass 2 try it?
3. **VLC turns subtitles on by itself** on Stargate (the SRT track is selected at start, both editions). Leave to VLC, or force "Off" at start?
4. **Tabs and seasons switch on click**, as the prototype does (the first run switched on focus, which dragged the tab to Videos whenever focus travelled to the sort control). Confirm.
5. **Unnamed edition.** Divergent's and Wonder Woman's one edition has `name: null`; the row and the overlay show the file name (`Wonder Woman (2017).mkv`). Preferred label?
6. **Shows carry no 4K/HDR badges**: `/api/shows` has no per-file resolution or HDR (only episodes do). Leave, or ask the server for a show-level summary?
7. **Rating chip** shows `TMDB 7.2` (the server has `rating`, no certification, as the admin UI already decided); the frame drew "R".
8. **Inter** is not bundled; the system font is used at the frames' sizes and weights.
9. **Frame 17's "Last successful sync … cached" line** was left out with the "Browse cached" button (there is no cache).
10. **Evidence logging** (`EvidenceLog.swift`: VLCKit's file logger at debug level into Library/Caches, plus the console) is in the app because the device-proof needs it. Keep it for pass 2, or gate it?
11. **No app icon** — there is no asset catalog; the Home screen shows the generic tile.
12. **Audio track names** come from VLC ("Surround 7.1 - [English]"); the panel shows the language ("English") and a short codec ("TrueHD · 7.1"). VLC does not report "Atmos" or "DTS-HD MA"; neither does the server.

## Least sure of

- Whether tvOS actually goes to HDR output for the two 4K HDR files (no log line proves it either way).
- The overlay time while paused after a seek: VLC does not post time changes while paused, so the app re-reads `player.time` 400 ms after a step or skip; during VLC's rebuffer loop the label may lag the picture.
- The real Siri Remote's swipes and touch-surface taps (only clicks were sent by the harness).
- Focus behaviour returning from the player: the harness found focus on an edition row rather than Play once, and re-found Play by pressing up; a person will see the same.
- Long-run stability of VLCKit 4.0.0-a24 (the longest playback here was ~95 s).
- `Format.layout` mapping "5.1(side)" → "5.1" and "stereo" → "2.0" for display; the server's raw strings are kept in the model.
