# Marlin Media TV — cold start

Read this and DECISIONS.md before any work; do not re-derive what they settle. Per-pass
reports live in `reports/`. **Current state** is where the project stands now; **Pass history**
holds every pass note, oldest first.

## What this is

The tvOS client for **marlin-media**, the home media server (repo marlin1111ai/marlin-media;
Go, SQLite, TMDB metadata, direct-play streaming). The app opens on a Home screen and shows the
server's movies, TV shows and videos, and plays the original files with VLCKit — the server never
transcodes; it serves the file bytes with HTTP Range support at `/stream/{fileId}`.

Since pass 2 it also carries the server's playback state (D023–D029): Continue Watching, Resume
with "N min left", Start over, watched marks, the per-episode state column and a Recently Added
sort. Reading that state is `GET /api/continue-watching` plus the `playback` block the server puts
on every file of an item (`MediaFile.playback` — editions, episodes and videos alike); writing it
is `PUT /api/files/{fileId}/playback`, the app's only write.

## Where things are

- **Server:** `http://192.168.1.250:8093`, fixed in `ServerConfig.baseURL` (D007: no settings
  screen). Never the marlinpc dev copy. Image **0.3.0** when it was last read (`GET /api/health`,
  pass 2 recon 2026-09-15 — the app itself never calls `/api/health`). **Every call the app
  makes**, read from the source:
  - `GET /api/movies` and `GET /api/movies/{id}` — the movie list, and one movie with its
    editions (`ServerAPI.swift:67–68`).
  - `GET /api/shows` and `GET /api/shows/{id}` — the show list, and one show with its seasons and
    episodes. The list carries no episodes, so Home asks for one `GET /api/shows/{id}` **per show,
    every time it appears** (D040), and the show screen asks for its own (`ServerAPI.swift:69–70`,
    `LibraryModel.swift:131`).
  - `GET /api/videos` (`ServerAPI.swift:71`).
  - `GET /api/continue-watching?limit=200` — the server's in-progress list (`position > 0` and not
    watched), newest `last_played` first, one entry per file, decoded as `ContinueEntry`. A failure
    here is a log line and an absent row, not a library failure (D024, `ServerAPI.swift:82`).
  - `PUT /api/files/{fileId}/playback` with `{position?, watched?}` — **the app's first and only
    write** (D024, D028). An omitted key means "leave unchanged"; the server stamps `last_played`
    itself and answers with the block it stored. Every write goes through `PlaybackWrite.send`,
    which logs the request and the answer; **a failed write is a log line and nothing else**
    (`ServerAPI.swift:88–101`, `PlaybackWrite` at `:149`).
  - `GET /stream/{fileId}` — the original file, Range-served, handed to VLCKit. The path is the
    item's own `file.stream`, resolved against the base URL (`Models.swift:50–52`).
  - `GET /api/artwork/…` — posters, backdrops and episode stills, as server-relative paths carried
    in the JSON and resolved the same way (`ServerImage.swift`, `Artwork` in `Models.swift`).
  - the timeline stills of image 0.3.0 (pass 2g):
    - `GET /api/files/{fileId}/thumbs` — the index: `interval` (10 s), `tile_width` (320),
      `tile_height` (214 on the films measured), `columns` (6), `rows` (5), `per_sheet` (30),
      `count`, `state` (`none` | `generating` | `complete` | `failed`) and `sheets`, an array of the
      sheets that exist **at that moment**, each `{index, first_still, url}`. Generation starts on
      the first index request, so the first caller usually gets `generating` with `sheets: []`; a
      file with no usable duration returns `none`, and `failed` re-queues on request. An unknown
      file id is `404 {"error":"file not found"}`. Asked for **once when a detail screen opens**,
      for the file that would play, and never polled or re-fetched (D021, `ServerAPI.swift:76`).
    - `GET /api/thumbs/{fileId}/{n}.jpg` — one sprite sheet, 6 × 5 tiles, row-major and
      chronological (1920 × 1070 for a 320 × 214 tile, ~90 KB, `Cache-Control: max-age=86400`).
      The index's `sheet.url` carries a `?v=` cache-buster. Fetched as needed for display, on
      `URLSession.shared`, and kept for the rest of the player's life (`ThumbStrip.swift:125–143`).
- **Repo:** https://github.com/marlin1111ai/marlin-media-tv (branch `main`).
- **Working folder:** `~/Xcode/Marlin Media TV`. `Marlin DVR TV` next to it is read-only prior
  art (same owner, same device, same team); nothing else under `~/Xcode` is touched.
- **Design:** the Claude Design export, unzipped in place. `Design/Marlin Media.dc.html` holds
  **20 frames** — counted in the file: 00, 00b, 00c (Home), 01–04 (the three library tabs and the
  empty Videos state), 05 (the sort control open), 06–09 (movie detail, edition picker, show
  detail, video detail), 10–15 (the player), 16–17 (loading and "can't reach server"). Nineteen of
  them are 1920 × 1080 artboards carrying `data-screen-label`; frame 05 is a 760 × 1080 detail
  board standing beside frame 04 and has no such attribute. `Design/Marlin Media Prototype.dc.html`
  is the clickable companion (Esc = Menu, Space = play/pause, ← → = skip or frame step, E = server
  error), `Design/support.js` its runtime, and the Nocturne tokens are in
  `Design/_ds/nocturne-cd16098c-beea-4866-98d8-a7f5e2b3cacd/styles.css`, mirrored in
  `Marlin Media TV/Theme.swift`.
  This is the **Design2** export (D042): the owner's `Marlin Media tvOS Design2.zip` was unzipped
  over the pass-1 frames, prototype, `support.js` and `_ds/`, and that zip was then deleted — it is
  not in the folder and was never committed. The **older `Design/Marlin Media tvOS Design.zip` is
  still there**, untouched, and holds the pass-1 (17-frame) copies of the same files (`.thumbnail`,
  the two `.dc.html`, `support.js` and the five under `_ds/`). What
  Design2 changed: frames 00, 00b, 00c are new; 01–04, 06–09, 16 and 17 differ only by the clock
  (and 01–04 by the sort control's 260 pt shift); 10–15, the player, are unchanged.
  Build what the frames show; design nothing (D006).
- **The app icon's and Top Shelf's source:** `Design/tvos icons/Marlin Media tvOS Design.zip`
  (7.25 MB, tracked from pass 4 and **replaced by a newer export in pass 5**). Its `icons/` folder
  holds 14 files:
  - the layered app icon as three size pairs — `icon-400x240`, `icon-800x480`, `icon-1280x768`,
    each `-back` and `-front`, all with alpha (D048). Pass 5's export left these **byte-identical**
    to pass 4's, so the icon stacks were not touched.
  - the four Top Shelf banners, new in pass 5 — `topshelf-1920x720`, `topshelf-3840x1440`,
    `topshelf-wide-2320x720`, `topshelf-wide-4640x1440`, every one fully opaque (D049).
  - `-flat` files and `preview-b.png`, which are flattened previews and are **not** used.

  It is a different file from `Design/Marlin Media tvOS Design.zip`, which is the pass-1 frames.
- **Devices.** Two physical Apple TVs are paired with this Mac, and they are **not** equals:
  - **Home Theater** — Apple TV 4K (3rd generation, `AppleTV14,1`, arm64e), tvOS 26.6, Developer
    Mode enabled, on the local network. **The dev/test device (D005), and still the only one.**
    Every build, matrix, log and screenshot of evidence comes from here.
  - **Master Bedroom ATV** — Apple TV 4K (1st generation, `AppleTV6,2`, arm64), tvOS 26.6,
    Developer Mode enabled, on the local network. **It carries the app as a convenience for the
    household, at the owner's request (D050, pass 5) — it is not a test device.** Nothing is
    proven there, no evidence is taken there, and it is not reinstalled on as a matter of course.
    Before pass 5 this box was off-limits entirely; D050 is the narrow exception and does not
    reopen it for testing.

  All the facts above were read from `xcrun devicectl` on 2026-09-16.
- **Xcode:** 27.0 (27A266a), tvOS 27.0 SDK (24J360) — since 2026-09-14 (pass 1e rerun; supersedes
  26.6 (17F113) / tvOS 26.5 SDK). Bundle id `com.marlin1111.marlin-media-tv`, team `C879JNVK7Z`,
  automatic signing (both read from Marlin DVR TV). The UI-test target is
  `com.marlin1111.marlin-media-tv.UITests`.

## Toolchain facts

- **VLCKit:** a custom build of VideoLAN's VLCKit 4.0.0-a24 with the TrueHD/MLP decoder compiled in
  (D012). It lives at `Frameworks/VLCKit.xcframework` (git-ignored at `.gitignore:47`, 725 MB; tvOS
  device arm64 + simulator arm64/x86_64 slices) and the Xcode project links and embeds it by path —
  the Swift package is gone (D013). Nothing under `Frameworks/` has ever been tracked or pushed on
  any ref. Built by `tools/vlckit-truehd/build.sh` at `~/vlckit-build` (VideoLAN's scripts cannot
  take spaces in paths) from libvlc master 5dd4aebda + 20 patches: VLCKit's 17 (0007 minus its mlp
  hunk), **0018** (TrueHD/MLP decoder frames coalesced into 20 ms blocks, D015), **0019**
  (VideoToolbox picture-reorder fix, D017) and **0020** (no paused read-ahead after a frame step,
  D019). The four patch files this repo owns are in `tools/vlckit-truehd/`; a fifth, 0021, was
  written in pass 2f and **dropped** in pass 2g (D022), so the recipe is 20 patches and the patch
  text survives only as
  `reports/logs/2f-0021-es_out-no-late-pcr-compensation-while-paused.diff.txt`.
  Current framework (full recipe, pass 2g, 20 `Applying:` lines, libvlc clean at `6d623583`):
  contribs and libvlc compiled clean on Xcode 27.0 / tvOS SDK 27.0, packaged with VLCKit's project
  tvOS target set to 26.0 (`MinimumOSVersion` 26.0, `LC_BUILD_VERSION minos 26.0 sdk 27.0`, D018),
  `_ff_truehd_decoder` present on the device slice and no instrumentation strings. ffmpeg 9.0
  (`Lavc63.1.100`), Video Toolbox decoding, `samplebufferdisplay` video output, `avsamplebuffer`
  audio output. Reported version string: `4.0.0-dev Otto Chriek`.
- **VLCKit build prerequisites (not the app's):** python.org Python 3.14.7 at
  `/Library/Frameworks/Python.framework` (installed 2026-09-13; VideoLAN's script looks only there)
  and GNU make 4.4.1 built into `~/vlckit-build/tools` and passed as `VLC_PATH` (Xcode's make 3.81
  breaks the jobserver with VLC's ninja). On Xcode 27 a clean build compiled the contribs and all three
  libvlc slices in 9 min 11 s (16:49:46–16:58:57, 2026-09-14; the host tools in `extras/tools/build`
  were kept). `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh` re-packages the slices already built (no
  clone, patching, host tools or compiles; VideoLAN's script with `-n -l`) in about 30 s. Any change to
  the patches or the toolchain needs the full build, which resets libvlc and re-applies every patch.
  `build.sh` only **copies** 0018/0019/0020 into `~/vlckit-build/VLCKit/libvlc/patches/` and never
  clears that folder, while VideoLAN's script applies every `*.patch` it finds there. **A withdrawn
  patch must be deleted by hand** — pass 2g found an orphaned `0021-….patch` still sitting there,
  which the recipe would otherwise have re-applied.
  `~/vlckit-build` was 22 GB on 2026-09-13 (not re-measured since).
- **Minimum tvOS:** 26.0 exactly (`TVOS_DEPLOYMENT_TARGET = 26.0`, D004). Both Apple TVs run 26.6.
- **No CocoaPods, no xcodegen, no brew installs.** The project file was written by hand
  (objectVersion 71, file-system-synchronized groups); Xcode opens it normally. Everything in
  `Marlin Media TV/` is therefore in the app target by virtue of being in the folder.
- **Fonts:** the system font. The design names Inter; no font is bundled (still an open question in
  the pass-1 report).
- **Asset catalog:** `Marlin Media TV/Assets.xcassets`, added in pass 4, holding one thing:
  `AppIcon.brandassets` — the layered tvOS app icon (D048) and, since pass 5, the two Top Shelf
  banners (D049). `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on both configurations of the app
  target is what points at it. There is no accent colour, no launch image and no other asset — the
  UI's colours are `Theme.swift`'s tokens, not the catalog.

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
`[player]`, `[playback]`, `[detail]`, `[focus]`, `[hold]`, `[scrub]` and `[thumbs]` lines); copy it
off with
`xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.marlin1111.marlin-media-tv --source Library/Caches/marlin-media-tv.log --destination <file>`.
`EvidenceLog` opens the file on its **first line**, not when a player starts, because the detail
screens write with no player up (pass 2).

**Building for the other Apple TV.** The same command with
`-destination 'platform=tvOS,name=Master Bedroom ATV'` builds and installs on the bedroom box
(D050). Do that **only when the owner asks**: Home Theater is the dev/test device (D005), and the
bedroom box is in household use — launching there puts the app on a television someone may be
watching.

**Photographing the device without a harness** (pass 4):
`xcrun devicectl device capture screenshot --device <id> --destination <file.png>` takes a
3840 × 2160 PNG of whatever is on the screen, **including tvOS's own Home screen and any other
app** — which the UI-test harnesses cannot reach, because XCUITest only ever sees the app under
test. `devicectl device info processes --device <id>` says what is running. Use this for anything
outside Marlin Media TV; use a harness when the shot has to be taken at a particular point in the
app's own flow.

**Evidence harnesses** (the Marlin DVR TV convention — per-pass throwaways, not a standing test
suite). Each drives the real remote through `XCUIRemote` on Home Theater and photographs the
screen; each navigates by reading which element has focus (`hasFocus == YES`), never by counting
presses. Build with `build-for-testing`, then
`xcodebuild test-without-building … -only-testing:"Marlin Media TVUITests/<Class>/<test>" -resultBundlePath <x.xcresult>`
and `xcrun xcresulttool export attachments --path <x.xcresult> --output-path <dir>` for the PNGs.
- **Committed:** `EvidenceUITests.swift` (pass 1, library and player; makes no server write) and
  `Pass2UITests.swift` (pass 2's resume/watched matrix, which seeds positions by PUT so a resume
  or a 90 % mark takes seconds rather than an hour).
- **Deliberately uncommitted**, with the `PlayerHost.swift` Page Up / Page Down hook they need:
  `Diag2gUITests.swift`, `Pass2bUITests.swift`, `Pass2cUITests.swift`, `Pass3ShotsUITests.swift`,
  `Pass3bShotsUITests.swift`. They exist only to script touch-surface drags, which `XCUIRemote`
  cannot perform. Copies of the pass 2g pair are committed as evidence:
  `reports/logs/2g-harness-Diag2gUITests.swift.txt` and `reports/logs/2g-harness-hook.diff`.

## How the app is put together

Nineteen Swift files, all of them in `Marlin Media TV/` and so all in the app target.

**Entry and shell**
- `MarlinMediaTVApp.swift` — the `@main` scene; one `WindowGroup` holding `ContentView`.
- `ContentView.swift` — the navigation: **Home is the root** (D040), the three Home buttons push a
  library tab, Menu there pops back, detail screens push above either, and the player is a
  full-screen cover above everything. It also counts the player's closes (`playerClosed`) and hands
  that count to Home and every detail screen, because a full-screen cover never takes its content
  off screen and so fires no appearance callback (D032).

**Server and data**
- `Models.swift` — Decodable models of the server JSON (every field real; decoded with
  `convertFromSnakeCase`), including `Artwork`, `Playback` and `ContinueEntry`, plus `Format`, the
  display mapping of the server's values (codec names, "7.1", "2 h 20 min", "13.2 GB").
- `ServerAPI.swift` — `ServerConfig` (the fixed base URL and path resolution), `APIError` (every
  failure carries a message the UI shows in full) and `APIClient` with the calls listed above,
  including the one write.
- `ServerImage.swift` — artwork loading from server-relative paths, with the frames' placeholder
  (`InitialTile`: the gradient tile with the title's initial) while loading, when there is no
  artwork and when the load fails.
- `PlayRequest.swift` — what the player is asked to play: the stream URL, frame 10's two overlay
  lines, and `startMs`, where playback begins (D029). It also decides whether a thumbnail index
  belongs to the file being played (`PlayRequest.matching`).
- `LibraryModel.swift` — the three lists loaded together (any one failing is the whole library's
  failure, frame 17), the Continue Watching list (whose failure is only a log line), `SortOrder`
  (**Title / Year / Recently Added**, D010/D023), every show's episodes for Home, and the three
  Home rows with their orders (D040).

**Screens**
- `HomeScreen.swift` — frames 00, 00b, 00c: MARLIN and the three library buttons, then Continue
  watching (every kind mixed, newest first, hidden when empty), Movies · N, TV Shows · N (up to six
  **episode** cards in the frames' wide card) and Videos · N. It re-reads itself every time it
  appears, and it places the launch focus on the first Continue Watching card (D043).
- `LibraryScreen.swift` — frames 01 (Movies), 02 (TV Shows), 03 (Videos), 04 (Videos empty),
  05 (the sort control open), 16 (loading) and 17 (can't reach server). Tabs and seasons switch on
  click (the prototype's behaviour); the sort menu is **Title / Year / Recently Added**; each tab
  carries a Continue Watching row above its grid holding only that tab's kind, and focus entering
  that row lands on its first card (D033). Frame 17's "Browse cached" button is still not built.
- `MovieDetailScreen.swift` — frames 06 (movie detail) and 07 (edition picker), with the watched
  pill, "Resume · N min left" and its in-button bar, "Start over", "Mark watched / unwatched" and
  the multi-edition rule (D026, D034).
- `ShowDetailScreen.swift` — frame 08: season selector and episode list, "N unwatched" in the meta
  row, the per-episode state column, a click that resumes at the saved position and a
  press-and-hold that opens the mark menu (D027, D031, D039).
- `VideoDetailScreen.swift` — frame 09, behaving exactly as the movie detail but with one file, so
  no picker and nothing to follow. **Never run on a device** — this library has no videos (D038).
- `NowClock.swift` — the date-and-time pair the new frames put at the top right (D041). It draws
  only the pair; the placement (`right: 80, top: 56`) belongs to each screen. It ticks once a
  second while it is on screen.

**Player**
- `PlayerModel.swift` — VLCKit and the remote's meaning (D008 revised): click = play/pause,
  Menu = back, skips while playing, a native one-picture frame step on a left/right click while
  paused, and the paused touch-surface scrub with its landing and cancel (D021). It also adds
  `:demux=mkv_trusted` on `.mkv` streams (D014), asks tvOS to match the display to the stream
  (D016), seeks once to a `startMs` at the first `Playing` state (D029), and writes the position on
  the D028 schedule.
- `PlayerHost.swift` — the UIKit surface that owns every press, touch and swipe, and the VLCKit
  drawable. An edge click is a `UIPress`; a swipe is not a press at all; the scrub pan runs
  alongside the swipe recognizers and begins only while paused. **This file is the one with the
  uncommitted Page Up / Page Down harness hook in the working tree** — HEAD's copy has no hook.
- `PlayerScreen.swift` — frames 10–15 plus the scrub bar and its thumbnail, and the paused clock
  (D045). Visuals only: the whole stack is `allowsHitTesting(false)` and nothing in it is focusable.
- `ThumbStrip.swift` — the server's timeline stills: the index model (`ThumbIndex`, `ThumbSheet`),
  the arithmetic that turns a target time into a sheet and a tile, the sheet fetches and the draw.
  Where a still does not exist, nothing is drawn (D021).

**Support**
- `Theme.swift` — the Nocturne tokens from `Design/_ds/…/styles.css` plus the values the frames use
  inline; screens are 1920 × 1080 at 1×, content 80 pt from the sides. (Its header comment still
  says "the 17 frames", from before D042 replaced the export.)
- `EvidenceLog.swift` — one log file per launch in `Library/Caches`, VLCKit's own debug logger and
  the app's bracketed lines interleaved, also echoed to the console (D011).

Outside the Swift files:
- `Marlin Media TV/Assets.xcassets` — the asset catalog, whose only content is
  `AppIcon.brandassets`:
  - the tvOS Home screen icon (`App Icon.imagestack`, 400 × 240 @1x and 800 × 480 @2x) and the App
    Store icon (`App Icon - App Store.imagestack`, 1280 × 768), each a **two-layer** stack, Front
    over Back, with no Middle slot (D048);
  - the **Top Shelf banners** (D049, pass 5) — `Top Shelf Image.imageset` at 1920 × 720 @1x and
    3840 × 1440 @2x, and `Top Shelf Image Wide.imageset` at 2320 × 720 @1x and 4640 × 1440 @2x,
    four flat opaque PNGs straight from the export. These are what tvOS draws above the Home
    screen's top row when the app is the focused one there.

  Being inside `Marlin Media TV/`, it joins the app target through the synchronized group; the
  build setting `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` selects it.
- `Frameworks/VLCKit.xcframework` — the custom VLCKit (D012/D013), linked and embedded (code-sign
  on copy) by the project; not in git. Rebuild with `tools/vlckit-truehd/build.sh`.
- `Info.plist` carries `NSAppTransportSecurity` → `NSAllowsLocalNetworking`, so plain HTTP to
  192.168.1.250 is allowed.

## Current state

As of **pass 6 (2026-09-16)**, the newest pass.

### Built and owner-accepted

Every feature below has been tested by the owner on the Apple TVs and accepted; **nothing is
waiting on an owner test.**

- **The library and the player** (pass 1): the three library tabs, movie, show and video detail,
  the edition picker, and VLCKit playing the four MKVs and a Magicians episode directly — the
  overlay, the −10 s / +30 s skips, pause, the audio and subtitle panels, and Menu closing an open
  panel. The custom VLCKit decodes TrueHD to 8-channel PCM (D012, D015), MKV seeks use the file's
  cues (D014), tvOS matches the display to the stream (D016), and the VideoToolbox reorder fix
  ended Wonder Woman's judder (D017).
- **Native frame-back while paused** (D008 revised, D019, D020): a left/right click steps exactly
  one picture, both ways, on avcodec and VideoToolbox streams. Accepted and pushed in pass 1l.
- **The paused touch-surface scrub with timeline thumbnails** (D021 revised again, D022): a swipe
  or drag while paused moves the target and the server's nearest still, the picture holds, click or
  Play/Pause lands and plays, Menu cancels and stays paused. The owner tried the gesture by hand
  and accepted it; pushed in pass 2h.
- **Playback state** (D023–D029, D032, D034–D036): Recently Added on all three tabs, the Continue
  Watching row on Home and each library tab, Resume / Start over / the watched pill / Mark watched
  and unwatched on the movie and video details, "N unwatched" and the per-episode state column on
  the show detail, position writes on the D028 schedule with a 120 s floor and the watched mark at
  90 %, and resuming at a saved position with one seek.
- **The episode row** (D031, D039): a click plays or resumes, a hold of 0.6 s or more opens the
  mark menu, and the focus highlight is back.
- **The Continue Watching focus rule** (D033) on the library tabs, and **launch focus on the first
  Continue Watching card** (D043) on Home.
- **Home as the app's first screen** (D040), frames 00/00b/00c, with Menu on a library tab
  returning to it.
- **The clock** (D041, D044, D045): on Home, the three library tabs, the movie, show and video
  screens, frames 16 and 17, and the player **while paused only**. Frames 16 and 17 are a code
  trace, not device proof — open item 6.
- **The app icon** (D048, pass 4): the layered tvOS icon from the
  Claude Design export, Front over Back, on the Home screen icon and the App Store icon. Proven on
  Home Theater by a device screenshot of tvOS's own Home screen
  (`reports/screenshots/p4/p4-1-appletv-home-screen.png`), where the app now shows the artwork
  instead of the generic tile. The parallax lift a focused icon gets was **not** seen, because
  photographing it needs the icon focused and nothing here can press the remote's Home button.
- **The Top Shelf banners** (D049, pass 5): the four flat opaque
  PNGs from the export fill `Top Shelf Image` and `Top Shelf Image Wide`, closing what was open
  item 20. Proven on Home Theater by a device screenshot of tvOS's Home screen with the app
  focused and the banner drawn above the top row
  (`reports/screenshots/p5/p5-1-home-theater-topshelf.png`).

Known and accepted as behaviour rather than defects, not open: **D020's two** — Play after any
frame step drops the pictures below the demuxer's clock start (21–45 pictures, about 0.9–1.5 s),
and patch 0020's remaining gap, where a plain pause taken after a frame step can read ahead while
paused if a subtitle track is selected.

### Pushed

Everything on `main` is on `origin/main`; **nothing is waiting to be pushed.**

- Passes 1–1e up to `b22f9c9` (pass 1e rerun 4).
- Passes 1f–1k as `b22f9c9..6bfdbad`, six commits (pass 1l).
- Passes 2a–2g as `e9df636..1e13538`, seven commits (pass 2h).
- **Passes 2–3b as `3597d0a..896ee12`, five commits** — `b3f3b02` (pass 2), `8def8cd` (2b),
  `ef9ce11` (2c), `a99cccc` (3), `896ee12` (3b) — each a fast-forward, no force, no merges (D046).
  After that push, local `main`, `origin/main` and `git ls-remote origin main` were all
  `896ee1293ac9`.
- **Passes 4 and 5 as `ceae8c2..6de2d9b`, two commits** — `1a4d4ab` (pass 4, the app icon) and
  `6de2d9b` (pass 5, the Top Shelf banners and the bedroom install) — a fast-forward, no force, no
  merges (D051). After that push, local `main`, `origin/main` and `git ls-remote origin main` were
  all `6de2d9b4029516c6f8c1ad65c1b789bbc5188553`.
- `896ee12` is still the newest commit carrying **Swift** source. Everything after it — pass 3c's
  notebook commit `d64679a`, the COLD-START rewrite `ceae8c2`, pass 4's `1a4d4ab`, pass 5's
  `6de2d9b` and pass 6's own commit — changed no Swift file: pass 4 added the asset catalog and two
  lines of `project.pbxproj`, pass 5 filled the catalog's two Top Shelf slots, and passes 3c and 6
  are notebook-only.
- `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`). Nothing under `Frameworks/`
  is tracked on any ref, so the 725 MB framework has never been pushed.

### Deliberately uncommitted

These stay out of git on purpose and are expected in `git status`:

- `Marlin Media TV/PlayerHost.swift` — the Page Up / Page Down hook (pass 2g), the only
  modification to a tracked file. It exists to script touch-surface drags through the model,
  because `XCUIRemote` has no touch-surface API. A copy is committed as
  `reports/logs/2g-harness-hook.diff`.
- Five UI-test harnesses, all in `Marlin Media TVUITests/`: `Diag2gUITests.swift`,
  `Pass2bUITests.swift`, `Pass2cUITests.swift`, `Pass3ShotsUITests.swift`,
  `Pass3bShotsUITests.swift`. A copy of the pass 2g one is committed as
  `reports/logs/2g-harness-Diag2gUITests.swift.txt`.

The owner's `Design/Marlin Media tvOS Design2.zip` is not in the folder at all: pass 3 unzipped it
and deleted the zip (D042).

Three further untracked paths appeared on 2026-09-16 from the owner's own work, outside any pass.
**One of them is now tracked and pushed:** `Design/tvos icons/Marlin Media tvOS Design.zip` is the
source of both the app icon and the Top Shelf banners — pass 4 committed it (D048) and pass 5
committed the owner's newer export over it (D049). The other two are **still untracked and still
nobody's decision** — `icon pixel/Marlin Media.pxd` (the icon's Pixelmator document, ~2 MB) and
`Notes/`. Neither was opened, moved or committed; whoever picks them up should ask first.

### What the Apple TVs run

Both carry the **pass 5 build**, which is now the pushed `main` (`6de2d9b`) — `896ee12`'s Swift
source plus the pass 4 icon, the pass 5 Top Shelf banners and the app-icon build setting, built from
the working tree and so still carrying the uncommitted `PlayerHost.swift` hook. No Swift file has
changed since pass 3b. Pass 6 touched no source and built nothing, so this is still what is on both
devices.

- **Home Theater** — installed, launched and left running by pass 5, as by every pass before it.
- **Master Bedroom ATV** — installed, launched and left running by pass 5, the first time the app
  has been put there deliberately (D050). It is **not** kept in step with Home Theater: later
  passes install there only if the owner asks again.

### The server's state

The library, counted by `GET /api/health` on 2026-09-15 (pass 2 recon): **3 movies, 2 shows,
3 seasons, 16 episodes, 0 videos, 0 unmatched**, on 20 files. That is why D038's video check
has never run.

Pass 3c reset the playback state the test passes had written (D047). Files 1, 2, 4, 5 and 8 are all
back to `position 0, watched false`, no other file was ever touched, and
`GET /api/continue-watching` is **`[]`**. So the app now opens with **no Continue Watching row** on
Home (frame 00c) or on any library tab, and D043's launch focus deliberately places nothing — that
branch is the one in play and it has not been seen on the device. `last_played` survives on the
five, stamped to the reset's own instant, which leaves Stargate's *followed* edition (D026/D034)
still Extended, exactly as before.

### Open items

Each is recorded as open in DECISIONS.md or in a pass report; the source follows it.

**The library's coverage**

1. **Videos have never run on a device.** Recently Added on the Videos tab and the whole video
   detail screen are traced from the code, because this library has no videos. — `DECISIONS.md`
   D038; `reports/2026-09-15-pass3c-push-and-reset.md` open question 2.

**Home (raised in pass 3, untouched through 3b and 3c)**

2. **Home fetches one `GET /api/shows/{id}` per show every time it appears** — two requests on this
   library, about 34 on the owner's full one. Cache them, or ask only when the shows list changes?
   — `reports/2026-09-15-pass3-home-and-rows.md` open question 3.
3. **The TV Shows row uses the wide episode card** the brief asked for, while frames 00b/00c draw
   that row as posters. The brief won, but the app and the frames now differ there. — same report,
   open question 4.
4. **With no videos the Videos heading shows above an empty space**, as asked. Is that the wanted
   look once a video exists, or should the row hide the way Continue watching does? — same report,
   open question 5.
5. **Nothing pins Home's header**; the rows are one vertical scroll, and frames 00 and 00b are two
   scrolled states of the same screen. Is the header meant to stay put? — same report, open
   question 6.

**The clock**

6. **Frames 16 and 17 carry the clock by code trace, not device proof.** Neither state can be
   reached on Home Theater without something out of scope — the loading phase is over before the
   first painted frame, and the error screen needs the server unreachable. — `DECISIONS.md` D044;
   `reports/2026-09-15-pass3b-fixes.md` open question 1.
7. **The paused clock shows during a scrub, and while the player is buffering or opening**
   (`!isPlaying` is true then too). Neither was separately asked for, and the frames say nothing
   either way because they draw no clock on the player at all. —
   `reports/2026-09-15-pass3b-fixes.md` open questions 2 and 3.

**The scrub thumbnails (pass 2g)**

8. **"The file that would play" is a guess on multi-file screens.** One index per screen means a
   movie's first edition and a show's first episode of season 1; play any other edition or episode
   and there are simply no thumbnails. Fetch per selection, or lazily when the player opens? —
   `DECISIONS.md` D021 (revised again); `reports/2026-09-15-pass2g-scrub-thumbnails.md` §6.1.
9. **A file's first visit shows no stills at all**, because that first index request is what starts
   generation on the server. Accept "second visit onwards", or re-ask when the player opens? — same
   report, §6.2.
10. **The stills are letterboxed** into the server's 320 × 214 tile. Crop them in the client, or
    leave the server's tile as it is? — same report, §6.3.
11. **Nothing logs which still is drawn.** The proof that it follows the target is the screenshots
    alone. — same report, §6.5.

**The player**

12. **A pause after a scrub landing lets the demuxer read at 1× while paused**, up to about 36 s of
    stream. No seek is involved and no landing moved. Observed, not decided. — `DECISIONS.md` D021
    ("Observed, not decided", carried through the pass 2c and 2d entries).
13. **Start-up late pictures.** Wonder Woman and Magicians each show one picture late or dropped at
    the moment the audio output starts, while tvOS switches display mode. Accept as start-up
    behaviour, or a later diagnosis pass? — `reports/2026-09-14-pass1e-reorder-fix.md` §R4-6
    question 1.
14. **Wonder Woman's displayed picture rendered 24 s late at one resume**, against a clock from the
    last step. One run, not reproduced on the other films, not instrumented. —
    `reports/2026-09-14-pass1k-frame-back-close.md` open question 2.
15. **Audio start is still unmeasured.** It needs either a timestamped app log line, an instrumented
    build, or measuring outside the device. — same report, open question 3.

**Outside the app**

16. **The VideoLAN report is drafted and not submitted.** "Submit it, and in whose name?" — draft
    `reports/logs/1k-upstream-videolan-draft.md`;
    `reports/2026-09-14-pass1k-frame-back-close.md` open question 4.
17. **`last_played` was not cleared by the reset** and cannot be: the server stamps it on every
    write and the PUT body carries no way to null it. A true virgin state needs a server-side clear
    or a `last_played` field on the PUT — a request to the server repo, not a client change. —
    `DECISIONS.md` D047; `reports/2026-09-15-pass3c-push-and-reset.md` open question 1.

**Never settled since pass 1**

18. **Inter is not bundled** — the system font is used at the frames' sizes and weights. —
    `reports/2026-09-13-pass1-scaffold-and-player.md` open question 8.
19. **Frame 17's "Browse cached" button and its "Last successful sync … cached" line are not
    built**, because there is no cache. — same report, open question 9.

    *Closed:* pass 1's open question 11, "no asset catalog and so no app icon", is **answered by
    D048** — the catalog and the icon exist and are on the device.

**The app icon and Top Shelf (passes 4 and 5)**

20. **Which Top Shelf size tvOS actually chose was not established.** The catalog offers both the
    1920 × 720 pair and the 2320 × 720 "wide" pair; the Home Theater screenshot proves a banner is
    drawn, but nothing in it says which imageset fed it, and `assetutil` lists both. — `DECISIONS.md`
    D049; `reports/2026-09-16-pass5-topshelf-and-bedroom.md`.

    *Closed:* pass 4's open item, "the Top Shelf images are still empty slots", is **answered by
    D049** — all four banners are in place and one is on screen.

21. **The App Store icon has never been rendered.** It is built as a two-layer 1280 × 768 stack,
    but `tv-marketing` assets are stripped from a device build, so nothing here can show it. It
    would first appear in an App Store Connect upload. — same sources.
22. **The focused icon's parallax was not photographed.** A tvOS icon separates its layers only
    while focused, and reaching that state needs a Home-button press on the remote, which neither
    `devicectl` nor `XCUIRemote` can send from outside the app. The layer split is proven by the
    catalog and the compiled `Assets.car`, not by a photograph of the effect. — same sources.

**The bedroom Apple TV (pass 5)**

23. **The app on Master Bedroom ATV will go stale and nothing watches it.** It was installed once,
    at the owner's request (D050); no later pass reinstalls there unless asked, so it will drift
    behind `main` silently. Reinstall on request, on a schedule, or leave it to rot? —
    `DECISIONS.md` D050; `reports/2026-09-16-pass5-topshelf-and-bedroom.md`.
24. **Its provisioning profile will expire.** A development-signed build stops launching after the
    profile lapses (typically a week for a free profile, a year for a paid team). The owner will see
    the app refuse to open rather than any warning. — same sources.
25. **Nothing about the app has been tested on `AppleTV6,2` hardware.** It launched and drew Home,
    but the 1st-generation Apple TV 4K is a slower A10X, and no playback, seek, frame step, scrub or
    TrueHD path has ever run there. D005 keeps Home Theater as the only test device, so these are
    untested, not known-good. — same sources.

## Pass history

Every pass note as it was written, oldest first. Two passes were numbered 2b and two 2c; each is
headed by its own report file.

### Pass 1b — the custom VLCKit with the TrueHD decoder (`reports/2026-09-13-pass1b-vlckit-truehd.md`)

**Pass 1b (2026-09-13) done after four stops** (repo path spaces, missing GNU mirror tarballs,
Xcode's Python 3.9.6, Xcode's make 3.81 — all recorded in
`reports/2026-09-13-pass1b-vlckit-truehd.md`): the custom VLCKit decodes Wonder Woman's TrueHD
track on Home Theater and hands tvOS 8-channel 48 kHz PCM; Divergent (DTS) and Stargate (AC-3)
unchanged. The app links `Frameworks/VLCKit.xcframework`; the Swift package is gone.

One finding still waits on the owner (pass-1 report, open question 2): **the D008 seek-based
frame back shows a wrong frame and puts this VLC alpha into a rebuffer loop over HTTP** — the
native `gotoPreviousFrame` exists in this build but was not tried. TrueHD is solved by pass 1b. Deferred to a later pass (D009):
Continue Watching, progress, watched marks, Resume / Start over, Recently Added.

### Pass 1c — MKV seeks on the file's cues (`reports/2026-09-14-pass1c-mkv-seek.md`)

**Pass 1c (2026-09-14):** MKV seeks now use the file's Cues — one media option, `:demux=mkv_trusted`, on `.mkv` streams only (D014). Ten +30 s skips bring the picture back in under 0.6 s on all four MKVs (8–51 s before); nothing else changed. Numbers in `reports/2026-09-14-pass1c-mkv-seek.md`; the two diagnosis reports of 2026-09-14 (`…-diag-mkv-stutter.md`, `…-diag2-seek.md`) hold the evidence and VLC's code path. Still open: Wonder Woman's steady ~3.6 dropped pictures/s (2160p HEVC decode/display path, not the network), and the paused frame-back step, which now starts from the previous cue instead of the file start but still runs VLC's paused-seek rebuffer loop until the next input (pass-1 open question 2, D008).

### Pass 1d — TrueHD blocks, display matching, Menu closes a panel (`reports/2026-09-14-pass1d-truehd-audio-and-framerate.md`)

**Pass 1d (2026-09-14):** three changes. (1) VLCKit patch 0018 (D015) coalesces TrueHD/MLP decoder frames into 20 ms blocks — the framework was rebuilt with `tools/vlckit-truehd/build.sh` (which now installs that patch too; 3 min when contribs are already built) and `Frameworks/VLCKit.xcframework` replaced. (2) The player requests display matching per stream (D016): frame rate from VLC's parse or the player's video track, HDR10/SDR from the server's flag; tvOS switches to 24 Hz for the 4K films. (3) Menu closes an open track panel instead of exiting. Numbers in `reports/2026-09-14-pass1d-truehd-audio-and-framerate.md`. Still open: Wonder Woman's ~3.6 dropped pictures/s (unchanged at 24 Hz — a decode/output limit for that stream, `…-diag3-wonder-woman.md` §B), the paused frame-back step (D008, pass-1 open question 2), and whether TrueHD is now audible (the owner's check).

### Pass 1e — the VideoToolbox picture-reorder fix (`reports/2026-09-14-pass1e-reorder-fix.md`)

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

### Pass 1f — native frame-back tried (STOPPED) (`reports/2026-09-14-pass1f-frame-back.md`)

**Pass 1f (2026-09-14): STOPPED at item 3.**
- **Stepping.** VLCKit's native `gotoPreviousFrame` steps exactly one picture per left click on Stargate Extended, both ways. Five back, five forward and five back stay on the file's 33/50 ms picture grid, the screenshots return to identical pictures, and there's no `RESET_PCR` loop.
- **Resume.** Play after stepping starts with every picture late by the whole paused time: 57.6 s measured, 57.7 s paused. VLC drops 713 pictures and the clock runs 01:04 → 02:23.
- **Cause.** Read from VLC's source (not instrumented): the paused previous-frame seek resets the main clock, which discards the pause date, so `vlc_clock_main_ChangePause` adds no delay on resume.
- **Not run.** Wonder Woman and Magicians.
- **Code state.** The native call is **not committed**; `PlayerModel.swift` is at HEAD with D008's seek-back, and the tested diff is `reports/logs/1f-playermodel-native-prevframe.diff`. **Home Theater still has the pass 1f build installed.** D008 unchanged.
- **Where it is written up.** `reports/2026-09-14-pass1f-frame-back.md`, with the fix options as question 1.

### Pass 1g — the paused read-ahead found (STOPPED) (`reports/2026-09-14-pass1g-frame-back-resume.md`)

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

### Pass 1h — the demux-pause diagnosis (`reports/2026-09-14-pass1h-demux-pause-diagnosis.md`)

**Pass 1h (2026-09-14), diagnosis only.** Pinned candidate B from pass 1g with one instrumented Stargate run on Home Theater.
- **What keeps the demuxer reading while paused.** `next_frame_need_data` stays true. The first native back step flushes the subtitle decoder while paused, which gives it `frames_countdown = 1` (`decoder.c:2789–2793`). It then asks for data (12 288 requests).
- **Why nothing clears it.** es_out drops every non-video block in frame-step mode (`es_out.c:3164–3169`), so the request is never met or cleared (`decoder.c:2686–2687`). Only Play clears it (`INPUT_CONTROL_SET_STATE`), and Play's resume flush sets it again at once.
- **The rate.** It follows the pause-date anchor: flat out until the stream catches up to wall time since that anchor (PCR 134.5 s at +100 s), then 1×. From the trace, A isn't needed once B stops those reads.
- **Candidates.** B1–B5 with lines and risks are in `reports/2026-09-14-pass1h-demux-pause-diagnosis.md` §4. No patch written.
- **State.**
  - `Frameworks/VLCKit.xcframework` is again the full recipe's own build (21:55–21:58; both slices `MinimumOSVersion 26.0`, `minos 26.0 sdk 27.0`; `_ff_truehd_decoder` on the device slice).
  - libvlc is at `51f8302c27`, the same tree as `e50d9ac36a` (the recipe's `git am` rewrites hashes).
  - `PlayerModel.swift` is at HEAD, and Home Theater runs that build. D008 unchanged. Not pushed.

### Pass 1i — patch 0020 (STOPPED) (`reports/2026-09-14-pass1i-frame-back-fix.md`)

**Pass 1i (2026-09-14): STOPPED at step 8.**
- **Patch 0020** (`tools/vlckit-truehd/0020-es_out-forward-next-frame-need-data-only-from-stepped-es.diff`, design B1, 2 lines in `src/input/es_out.c`): while frame stepping, only the stepped video ES's need-data request reaches the input, and a request standing when stepping starts is cleared. `build.sh` installs it after 0019. VLC's player tests: 19/20 before and after (the one failure, `attachments`, is the host test build's missing BMP encoder).
- **Framework.** Full recipe, 22:43–22:46, 20 patches, libvlc `03632d2eb8`. Both slices `MinimumOSVersion 26.0` and `minos 26.0 sdk 27.0`; `_ff_truehd_decoder` on the device slice; no instrumentation strings.
- **What 0020 fixes.** An instrumented Stargate run logged the flag directly: never set while paused, reads only inside each step's own rebuffer. The clean runs show 0 reads while paused outside a step, against 22 700 in pass 1h, and the clock at Play+60 s is 01:34, not 03:36.
- **Why it stopped.** Stargate after five back steps drops 21 pictures and starts audio 1 477 ms after the first picture. After five forward steps: 26 dropped, 1 361 ms. The no-step control in the same session: 0 dropped, 176 ms. Play re-anchors the clock at the first PCR read after resume (~1 s past the displayed picture) while the video fifo still starts at the displayed picture. Wonder Woman, Divergent, Magicians, Food That Built America, step 7, step 9 and step 11 were not run.
- **State.** `PlayerModel.swift` carries the 1f native back step, **uncommitted**; Home Theater runs that build with the clean recipe framework. D008 unchanged, no new decision. Report: `reports/2026-09-14-pass1i-frame-back-fix.md`. Not pushed.

### Pass 1j — the resume trace (STOPPED) (`reports/2026-09-14-pass1j-frame-back-resume-fix.md`)

**Pass 1j (2026-09-14): STOPPED at step 1.** An instrumented Stargate run (pause, five back steps, Play, 60 s, second pause ~80 s, Play) settles the resume trace; report `reports/2026-09-14-pass1j-frame-back-resume-fix.md`.
- **Pictures — pass 1i's cause confirmed.** At Play the picture on screen is `pf_pts=33834001`. `EsOutChangePosition` resets the input clock, and the demuxer's first PCR becomes its reference (`input_clock reference stream=34785001`). The buffering end anchors the main clock there (`set_first_pcr ts=34785001`). Every queued picture below it is late: 21 dropped (`vout drop pts=33917001` … `34751001`), and the displayed one renders 955 ms late.
- **Audio — pass 1i's "1.4 s delay" was a measuring error.** The tvOS audio output starts 92 ms after the first picture (`avs startNow` at +101.6 ms). The trace's first audio render event is the output's 1 s periodic timing report (`time_observed time=1000129` at +1563 ms). The first audio block is PTS 34.912 s, so a clock started at the displayed picture would put ~1.1 s of silence under the first pictures. That's why step 2 was not written.
- **Second pause (0020's gap, step 7's case).** The resume flush sets the need-data flag again after frame stepping ends, and it stays set through a later plain pause: 3 967 demux calls while paused, PCR 98.4 → 182.4 s. Resume 2 was still clean (delay applied, 0 dropped).
- **Origin (step 13).** After `git fetch`, `origin/main` is `b22f9c9` (pass 1e rerun 4) and local `main` is 4 commits ahead, so pass 1i's "pushed" line was right.
- **State.** No patch 0021. libvlc clean and `Frameworks/` rebuilt by the full recipe (20 patches, as pass 1i). Home Theater runs HEAD + the uncommitted 1f diff. D008 unchanged. Not pushed.

### Pass 1k — native frame-back closed out (`reports/2026-09-14-pass1k-frame-back-close.md`)

**Pass 1k (2026-09-14/15): native frame-back closed out.** Report `reports/2026-09-14-pass1k-frame-back-close.md`.
- **Frame-back state.** While paused, a left/right click steps exactly one picture through VLCKit's native previous/next-frame (D008 revised; the seek-back is superseded). `PlayerModel.swift` carries it, committed. It needs patch 0020 (D019), which is in the 20-patch recipe and in `Frameworks/`. Exact on Home Theater for back and forward steps on Stargate (avcodec), Divergent and Wonder Woman (VideoToolbox): each click shows a new picture and the returning clicks show identical pictures (MAD 0).
- **Resume matrix** (five films × back / forward / no step, ~80 s pauses): clock at Play+60 s 01:33–01:35 in every run (01:34–01:35 after steps); no-step controls 0 dropped.
- **Known and accepted (D020), not defects.**
  1. Play after any frame step drops the pictures below the demuxer's clock start: 21–29 after five back steps, 26–45 after five forward steps (~0.9–1.5 s of picture; the 29.97 fps episodes drop more). E1/E2 rejected.
  2. 0020's remaining gap: Play's flush after stepping sets the need-data flag again, so a later plain pause with a subtitle track selected reads ahead (~84 s in pass 1j's run; that resume was clean).
- **Audio start** has no timestamped event in the clean build and is not measured; pass 1k traces the first audio block's scheduled time instead. Pass 1i's audio figures carry a correction note (they were the tvOS output's periodic timing report).
- **VideoLAN.** Draft `reports/logs/1k-upstream-videolan-draft.md`, not submitted.
- **Push.** The owner tested native frame-back on Home Theater and accepted it; pushed in pass 1l.

### Pass 1l — the push of passes 1f–1k (no separate report)

**Pass 1l (2026-09-15): pushed.** The owner tested native frame-back while paused on Home Theater and **accepted it** (D008 revised, D019, D020). `main` was pushed to `origin` as a fast-forward, no force: `b22f9c9..6bfdbad`, six commits (passes 1f–1k). After a fetch, local `main` and `origin/main` were both `6bfdbad69e9f`. This note's commit was pushed the same way, so HEAD is on `origin/main`. `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`), and nothing under `Frameworks/` has ever been tracked or pushed.

### Pass 2 — resume, watched, Continue Watching, Recently Added (`reports/2026-09-15-pass2-resume-watched.md`)

**Pass 2 (2026-09-15): resume, watched, Continue Watching, Recently Added — built and verified on
Home Theater, one step short.** Decisions D023–D030; report `reports/2026-09-15-pass2-resume-watched.md`,
evidence `reports/logs/2-*.log`, screenshots `reports/screenshots/p2/`.
- **The server's playback state is now wired.** The app's only write is `PUT /api/files/{fileId}/playback`;
  it also reads `GET /api/continue-watching?limit=200`. Every write and the server's answer are in the app
  log, and a failed write is a log line and nothing else (D024).
- **Built:** Recently Added on all three tabs (D023); the Continue Watching row on frames 01/02, each tab
  showing only its kind, a card playing its file straight from its saved position (D025); the watched pill,
  "Resume · N min left" with its bar, "Start over" and "Mark watched / unwatched" on the movie and video
  details, with the multi-edition rule and the picker's resume line (D026); "N unwatched" and the per-episode
  state column on the show detail (D027); position writes every 10 s / pause / stop / exit with a 120 s floor,
  and the watched mark at 90 % (D028); and resuming at a saved position (D029).
- **Measured on Home Theater** (harness `Marlin Media TVUITests/Pass2UITests.swift`, positions seeded by PUT
  so a resume or a 90 % mark takes seconds rather than an hour): resume landings −165 / −229 / −261 ms from
  the saved position on Stargate Extended, Food S4E2 and Magicians S1E1; the 90 % mark at 3 578 411 ms of
  3 975 982 ms (threshold 3 578 384) with every later write refused; a 48 s peek writing nothing; skips exact;
  frame steps one picture per click; a scrub landing 0 ms off. 0 `PCR is called … late`, 0 clock gaps in every
  run.
- **STOPPED at step 5's press-and-hold.** `.onLongPressGesture` on the episode row never fires on tvOS — the
  Button's own action wins, so a hold *plays* the episode instead of opening the mark menu (log: hold at
  21:13:49.409 → `[playback] file 9 … starting at 0 ms`). The menu itself is built and unreachable; no retry
  was made. Everything else in step 5 works. Diagnosis and the candidates are in the report.
- **Also changed:** `EvidenceLog` now opens its file on the first line rather than only when a player starts,
  because the detail screens' writes happen with no player up.
- **Committed locally, not pushed** — the owner tests on Home Theater first. Home Theater is left running
  this build. `Marlin Media TVUITests/Diag2gUITests.swift` and the `PlayerHost.swift` Page Up/Down hook stay
  uncommitted, as before.

### Pass 2a — touch-surface scrubbing (STOPPED) (`reports/2026-09-15-pass2a-scrubbing.md`)

**Pass 2a (2026-09-15): touch-surface scrubbing — STOPPED at step 5.** Report `reports/2026-09-15-pass2a-scrubbing.md`.
- **Built, uncommitted.** A horizontal drag pauses and shows a scrub bar (frame 10's timeline row, target elapsed/remaining, a start mark), the picture follows the target by paused seeks (one per 250 ms and one on lift), click lands and plays, Menu returns. The diff is in the working tree and saved as `reports/logs/2a-scrub-app.diff`. Home Theater runs it (no harness hook).
- **Why it stopped.** Landing hits the paused-seek read-ahead (pass 1g's seek-back loop), on Magicians S1E1 (MP4, no subtitle track): after the last paused seek VLC laps its rebuffer 12 times in 1.3 s (`PCR is called … late`, `ES_OUT_RESET_PCR`), reading PCR 238.2 → 269.0 s for a 238.6 s target; Play then starts at the read-ahead end (first picture PTS 266.3 s; clock 04:29 at +3 s for a 03:59 target). Trace in `reports/logs/2a-analysis.txt`. No fix; 23 of the 24 matrix runs and the step-4 controls not run.
- **Drags can't be scripted on the remote.** XCUIRemote has no touch-surface API; the owner chose a hybrid: an uncommitted Page Up/Down hook plays a scripted drag through the model (`reports/logs/2a-harness-app.diff`), plus a physical check by the owner (not done — stopped first).

### Pass 2b — fast seek on the scrub path (STOPPED) (`reports/2026-09-15-pass2b-fast-seek.md`)

**Pass 2b (2026-09-15): fast seek on the scrub path — STOPPED at step 2, owner's call.** Report `reports/2026-09-15-pass2b-fast-seek.md`, evidence `reports/logs/2b-fast-seek-recon.txt`.
- **Why it can't be scoped as asked.** Nothing in this libvlc reads the `input-fast-seek` option (declared, created on the input, read only by desktop GUI prefs), so a media option is inert; VLCKit has no seek-speed setting (`setTime:` always passes `b_fast = NO`). Fast vs precise is per seek: `libvlc_media_player_set_time(p, t, b_fast)`. The only scoped route is VLCKit's private `_playerInstance` plus that exported C call; the owner chose to stop rather than use it.
- **State.** Nothing applied, built, installed or run. Tree and Home Theater as after pass 2a (scrub diff uncommitted). The scrub code is not committed: pass 2a's ~30 s landing overshoot stands.

### Pass 2b — pass 2's follow-ups (`reports/2026-09-15-pass2b-followups.md`)

**Pass 2b (2026-09-15): pass 2's follow-ups — one of three built and working, two STOPPED.**
Decisions D031–D038; report `reports/2026-09-15-pass2b-followups.md`, evidence
`reports/logs/2b-*.log`, screenshots `reports/screenshots/p2b/`.
- **Works (D032): every detail screen re-reads its item when the player closes.** `ContentView`
  counts the closes — a full-screen cover never takes its content off screen, so there is no
  appearance callback — and the movie, show and video screens re-read on that count. Proven on Home
  Theater: Start over on Divergent wrote `position=0.0`, played from 0 ms, and on the way back the
  screen showed **Play** with no Start over, with `[detail] movie 1 re-read: position 0.0 watched
  false` in the log.
- **STOPPED (D031): the episode press-and-hold still plays instead of opening the mark menu.**
  Candidate (a) — a `UILongPressGestureRecognizer` for the select press, on the window while the
  show detail is up — was instrumented: it **attaches** but **never receives the press** (no
  recogniser state is ever logged), because a focused SwiftUI Button consumes the select press
  first. Candidate (b), a focusable non-Button row, is untried. No blind retry was made.
- **STOPPED (D033): focus entering the Continue Watching row still does not land on the first
  card.** `prefersDefaultFocus` in a focus scope does not govern directional entry: from the sort
  control focus goes to the **rightmost** card, and re-entering goes to the card last left. The one
  case the owner named (entering after the player closes) did land on the first card, but geometry
  explains it, so it is not proof.
- **No server writes of this pass's own:** every write in pass 2b came from the app's own buttons
  while the tests ran.
- **Committed locally on top of `b3f3b02`, not pushed** — the owner tests passes 2 and 2b together.
  Home Theater is left running this build. The pass 2b harness
  (`Marlin Media TVUITests/Pass2bUITests.swift`) is **not** committed, nor is the owner's
  `Design/Marlin Media tvOS Design2.zip`.

### Pass 2c — the preview-playhead scrub (`reports/2026-09-15-pass2c-scrub-preview.md`)

**Pass 2c (2026-09-15): preview-playhead scrub — landed and committed (D021).** Report `reports/2026-09-15-pass2c-scrub-preview.md`.
- **Behaviour.** A horizontal drag on the touch surface pauses and shows the scrub bar; the picture holds, nothing seeks during the drag or on lift; click or Play/Pause plays and then seeks once to the target; Menu cancels with no seek and restores the play state. 25% of the running time per surface width; target stops 1 s short of the end. `PlayerHost.swift` (pan), `PlayerModel.swift` (scrub state, land, cancel), `PlayerScreen.swift` (bar).
- **Proof on Home Theater** (drags scripted through the model by an uncommitted Page Up/Down hook — `reports/logs/2c-harness-app.diff`; XCUIRemote cannot touch the surface): 48 scrubs on Stargate, Wonder Woman, Divergent and Magicians S1E1 — 32 landings with the first picture −72…+104 ms from the target, 16 cancels within 0.81 s; skips, frame steps and Menu-closes-panel unchanged on all four films.
- **Still open.** The owner's test of the gesture on the real remote (not yet done; push waits for it). A pause after a landing reads the stream at 1× while paused, up to ~36 s (no effect on landings; not diagnosed).

### Pass 2c — the episode hold and the Continue Watching focus (`reports/2026-09-15-pass2c-hold-and-focus.md`)

**Pass 2c (2026-09-15): the Continue Watching focus is fixed; the episode hold is STOPPED one step
from working.** Decisions D031 (revised), D032a, D033 (revised); report
`reports/2026-09-15-pass2c-hold-and-focus.md`, evidence `reports/logs/2c-*.log`, screenshots
`reports/screenshots/p2c/`.
- **Works (D033): focus entering the Continue Watching row always lands on its first card.** The
  cards carry `@FocusState`, and when focus arrives from outside the row (no card had it a moment
  before) it is moved to the first card; moving between cards inside the row is untouched. Proven
  on Home Theater with two cards, in all four cases asked for — from the sort control, from the tab
  the row sits under, after moving along the row and leaving and re-entering, and after returning
  from the player — with `[focus] continue row entered at card 2; moved to the first card 4` in the
  log for the three that needed a move. Pass 2b's `focusScope` / `prefersDefaultFocus` attempt is
  removed.
- **Works (D031, the click half): the episode row is now a focusable view rather than a Button**,
  and a click still plays (`from 0 ms`) or resumes (`from 968576 ms`, then the seek). The row draws
  and focuses exactly as before — `EpisodeRowLabel` is untouched.
- **STOPPED (D031, the hold half).** Candidate (a)'s window recogniser was removed and candidate (b)
  built, but a hold still plays the episode. Instrumented timing: a click is 4–15 ms down-to-up, the
  1.4 s hold measured 601 ms (capped at the 0.6 s threshold), and no mark menu followed — SwiftUI
  delivers `onPressingChanged(false)` **before** `perform`, so the release is taken as a click and
  `perform` then finds the player already up. The fix is to judge the press by its own elapsed time
  instead of racing the callbacks; it was not applied, because the hold playing is this pass's stop
  condition.
- **No server writes of this pass's own:** every write came from the app's own buttons while the
  tests ran. A second Continue Watching card was made by letting the app play Wonder Woman past the
  120 s floor.
- **Committed locally on top of `8def8cd`, not pushed** — the owner tests passes 2, 2b and 2c
  together. Home Theater is left running this build. The pass 2c harness
  (`Marlin Media TVUITests/Pass2cUITests.swift`) is not committed, nor is the owner's
  `Design/Marlin Media tvOS Design2.zip`.

### Pass 2d — the owner's scrub flow (`reports/2026-09-15-pass2d-owner-flow.md`)

**Pass 2d (2026-09-15): the owner's scrub flow — committed (D021 revised).** Report `reports/2026-09-15-pass2d-owner-flow.md`.
- **The owner's defect (real remote): a paused swipe did not scrub.** The pan waited for the left/right swipe recognizers to fail, so every paused flick was recognized as a side swipe and dropped by D008's paused rule (`right swipe while paused: no action (frame step is on click)`, 19 times in the owner's session; `[scrub] begin` 4 times). Touches around a click, or after swipe skips, also started scrubs while playing.
- **The flow now.** Play/Pause pauses. Paused: a swipe or drag scrubs (the picture holds, nothing seeks until landing); a left/right click steps one frame. Play/Pause or a click on the surface lands at the target and plays. Menu cancels and stays paused where the drag began. Playing: a drag does nothing; skips unchanged. 25% of the running time per width; target 1 s short of the end. `PlayerHost.swift` (the pan runs alongside the swipes and begins only while paused), `PlayerModel.swift` (the scrub appears once the target moves; no scrub while playing; Menu stays paused).
- **Proof on Home Theater** (drags scripted through the model — XCUIRemote cannot touch the surface): 24 paused scrubs on Stargate, Wonder Woman, Divergent, Magicians S1E1 — 16 landings −74…+94 ms from the target, 8 Menu cancels paused at the start; 8 drags while playing refused; skips exact; 5 + 5 clicks one picture each on all four (pixel comparison). One Divergent run lost a Play/Pause press between XCTest and the app (no app line, VLC kept playing); re-run once at the owner's call, clean.
- **The owner must still try the gesture by hand** (report §6); nothing is pushed until then.

### Pass 2e — why paused seeks can't follow the thumb (`reports/2026-09-15-pass2e-scrub-seek-diagnosis.md`)

**Pass 2e (2026-09-15): why paused seeks can't make the picture follow the thumb — diagnosis only.** Report `reports/2026-09-15-pass2e-scrub-seek-diagnosis.md`, evidence `reports/logs/2e-analysis.txt`.
- **Cause (instrumented libvlc, Magicians S1E1 and Stargate on Home Theater).**
  - A paused seek's rebuffer anchors the input clock at the **pause date** (`es_out.c:1219`). The next PCR is late by about (time since the pause − pts_delay), so the late branch resets and rebuffers without moving the demuxer (`es_out.c:3661–3721`).
  - Lap after lap reads forward, and past the 5 s `clock-jitter` cap the laps run until Play. Play-only landings played from 452 s for a 239 s target (Magicians) and from 667 s for 333 s (Stargate).
  - A single seek on lift laps the same way, so seek count and pace don't matter. The need-data flag isn't involved on Magicians; Stargate's subtitle request adds paused reads.
- **What still works.** HEAD's landing (play, then one seek) lands on the target even after laps. But during the hold the picture drifts forward while the bar shows the target.
- **Candidates.** C1 (`es_out.c:3661`, skip late compensation while es_out is paused) is the narrowest; not implemented. No decision.
- **State.** libvlc clean, and `Frameworks/` rebuilt by the full recipe (20 patches; both slices `MinimumOSVersion 26.0`, `minos 26.0 sdk 27.0`; `_ff_truehd_decoder`; no trace strings). The app is at HEAD and installed on Home Theater. Committed locally, not pushed.

### Pass 2f — patch 0021 with a moving scrub picture (STOPPED) (`reports/2026-09-15-pass2f-scrub-live-picture.md`)

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

### Pass 2g — 0021 dropped, the scrub gained timeline thumbnails (`reports/2026-09-15-pass2g-scrub-thumbnails.md`)

**Pass 2g (2026-09-15): 0021 dropped, the scrub gained timeline thumbnails — done.** Report `reports/2026-09-15-pass2g-scrub-thumbnails.md`, evidence `reports/logs/2g-*`, screenshots `reports/screenshots/2g/`.
- **0021 is gone** (D022): the patch file, its `build.sh` step and its README line are removed, the app is back at HEAD's scrub, and the full recipe rebuilt `Frameworks/` at **20 patches** (20 `Applying:` lines, `ARCHIVE SUCCEEDED` ×2, libvlc clean at `6d623583` with `es_out.c:3661` back to its HEAD condition; both slices `MinimumOSVersion 26.0`, `minos 26.0 sdk 27.0`, `_ff_truehd_decoder`, no instrumentation strings). A stale `0021-….patch` was still sitting in `~/vlckit-build/VLCKit/libvlc/patches/` and had to be deleted first, or the recipe would have re-applied it.
- **The thumbnail** (D021 revised again): during a paused drag the server's still nearest the target shows above the bar and changes with it; where no still exists, nothing shows. `ThumbStrip.swift` is new; the index is fetched once per detail screen (never polled, never re-fetched) and sheets as needed.
- **On Home Theater** (Stargate Extended, one session, 191.5 s, passed): one index line, two sheet fetches (185/115 ms) for four targets, the thumbnail tracking 03:59 → 05:32 → 08:08 → 06:50, exact drag rates, landing 0 ms from the target, Menu cancel 0 ms back at the drag's start and still paused, and five frame steps retraced to pixel-identical screenshots.
- **Owner-accepted.** The owner tried the gesture by hand on Home Theater — the push gate standing since pass 2c — and **accepted the scrub and its thumbnails**; pushed in pass 2h.
- **Still open:** which file a multi-edition movie or multi-episode show should fetch an index for; and that a file's **first** visit shows no thumbnails, because that first request is what starts generation.

### Pass 2h — the push of passes 2a–2g (no separate report)

**Pass 2h (2026-09-15): pushed.** The owner tested the touch-surface scrub with its timeline thumbnails on Home Theater and **accepted it** (D021 revised again, D022). `main` was pushed to `origin` as a fast-forward, no force: `e9df636..1e13538`, **seven commits** (passes 2a–2g). After a fetch, local `main`, `origin/main` and the live remote ref were all `1e13538317da`. This note's commit was pushed the same way, so HEAD is on `origin/main`. `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`): nothing under `Frameworks/` is tracked on any ref, so the 725 MB framework was not pushed and never has been. **Deliberately not pushed, and still uncommitted:** the pass 2g UI-test harness (`Marlin Media TVUITests/Diag2gUITests.swift`) and its `PlayerHost.swift` Page Up / Page Down hook, which exist only to script drags that XCUIRemote cannot perform — copies are committed as `reports/logs/2g-harness-Diag2gUITests.swift.txt` and `reports/logs/2g-harness-hook.diff`.

### Pass 3 — the episode rows, Home, the clock (`reports/2026-09-15-pass3-home-and-rows.md`)

**Pass 3 (2026-09-15): the episode rows fixed, Home built, the clock added — all of it working.**
Decisions D039–D042; report `reports/2026-09-15-pass3-home-and-rows.md`, evidence
`reports/logs/3-*.log`, screenshots `reports/screenshots/p3/`. The owner tests this pass by hand,
so it was built, installed and launched, with four screenshots and no matrix.
- **The episode row is right again (D039).** Its focus highlight is back — a plain `.focusable()`
  view does not hand `isFocused` to its child the way a Button's style does, so the row now takes
  `focused:` from `@FocusState`. And the press decides itself: the press-down instant is remembered
  and the release measured against it, so a hold opens the mark menu and plays nothing. **Proven on
  Home Theater:** `[hold] menu for S1E2 file 9 after 1383 ms`. Pass 2c failed because SwiftUI ends
  the press *at* `minimumDuration` — 601 ms against a 600 ms threshold — so the gesture's own
  minimum is now set out of reach (3600 s) and only the measured length decides. Pass 2c's
  instrumentation is gone.
- **Home is the first screen (D040)**, frames 00/00b/00c: MARLIN and the three library buttons, then
  Continue watching (every kind mixed, newest first, hidden when empty), Movies · N, TV Shows · N
  (up to six **episode** cards in frame 00b's wide card, each with its own still, ordered
  in-progress → next after the last finished → on down each show), and Videos · N. Menu on a
  library tab returns to Home. Home re-reads itself every time it appears, which needs one
  `GET /api/shows/{id}` per show for the episodes the shows list does not carry.
- **The clock (D041)** — "TUE 15 SEP · 9:40 PM" at right 80, top 56 — is on Home, the three library
  tabs and the movie, show and video screens, and **not** on the player. The Sort control moves
  260 pt in from the right, as the new frames draw it.
- **The design was replaced (D042):** `Design2.zip` unzipped into `Design/` over the old frames,
  prototype, `support.js` and `_ds/`, and the zip deleted. **Frames 00, 00b, 00c are new; frames
  01–09, 16 and 17 differ only by the clock (and 01–04 by the Sort shift); frames 10–15, the player,
  are unchanged.**
- **Committed locally on top of `ef9ce11`, not pushed** — the owner tests passes 2–3 together. Home
  Theater is left running this build. The harnesses are not committed.
- **Known and reported, not built:** at launch focus lands on a Movies card rather than the first
  Continue Watching card, so Home opens slightly scrolled; frame 00's label says "first card
  focused". Initial focus is not in the pass's list, so it was left alone. **Built in pass 3b
  (D043).**

### Pass 3b — the owner's three fixes (`reports/2026-09-15-pass3b-fixes.md`)

**Pass 3b (2026-09-15): the owner's three fixes after testing pass 3 — two built, one found already
done.** Decisions D043–D045; report `reports/2026-09-15-pass3b-fixes.md`, evidence
`reports/logs/3b-run1.log`, screenshots `reports/screenshots/p3b/`. The owner tests by hand, so it
was built, installed and launched, with two device screenshots and no matrix.
- **Launch focus (D043).** The app now opens with focus on the **first Continue Watching card**, as
  frame 00 draws it — pass 3's open question 1. Home's cards carry `@FocusState`, and the first card
  is asked for every 120 ms until it takes focus (the row is built from a list that arrives after
  Home's first appearance, and the focus engine ignores a request for a view not yet on screen); the
  request is placed **once per session** and stops as soon as any card of the row has focus, so the
  row, the return from the player and Home's re-reads are untouched. **With nothing in progress
  nothing is placed.** Proven on Home Theater: `[focus] launch: asked for the first Continue Watching
  card 4; focus is now 4` and `p3b-2-home-launch-focus.png` (Wonder Woman ringed, the row at the top).
- **Frames 16 and 17 already carry the clock (D044).** Pass 3's report was wrong about this: D041's
  overlay sits on the container, outside the phase switch, in both `HomeScreen` and `LibraryScreen`,
  so the loading and error views are drawn under it at the frames' own `right: 80, top: 56`. **No
  code was needed, and neither state could be photographed** — the loading phase is over before the
  first painted frame, and the error screen needs the server unreachable. Code trace, not device
  proof.
- **The player's clock while paused (D045).** The same pair, style and place as every other screen,
  shown on `!isPlaying` (frame 13's own condition) and hidden while a track panel is open, because
  frames 11/12 occupy that corner. Proven on Home Theater: `p3b-3-player-paused-clock.png` (Divergent
  paused at 00:16, the clock at the top right). `PlayerModel.swift` and `PlayerHost.swift` were not
  touched; `PlayerScreen.swift` changed for this step only.
- **No server write of this pass's own:** the harness played Divergent from 0 and paused at 15.6 s,
  under D028's 120 s floor, so the app wrote nothing (`position 15.6 s not written (pause): under
  120 s`).
- **Committed locally on top of `a99cccc`, not pushed** — the owner tests passes 2–3b together. Home
  Theater is left running this build. The harnesses (`Pass3bShotsUITests.swift` and the earlier ones)
  and the `PlayerHost.swift` hook stay uncommitted.

### Pass 3c — the push of passes 2–3b, and the test-state reset (`reports/2026-09-15-pass3c-push-and-reset.md`)

**Pass 3c (2026-09-15): passes 2–3b accepted and pushed, and the test state reset.** Decisions
D046, D047 (which discharges D037); report `reports/2026-09-15-pass3c-push-and-reset.md`. The owner
tested passes 2, 2b, 2c, 3 and 3b on Home Theater and accepted them all ("all good"). **No app
source was touched, and nothing was built, installed or launched** — Home Theater is left running
the pass 3b build, which is now the pushed `main`.
- **Pushed (D046).** `main` went to `origin` as a fast-forward, no force: **`3597d0a..896ee12`, five
  commits** (`b3f3b02` pass 2, `8def8cd` 2b, `ef9ce11` 2c, `a99cccc` 3, `896ee12` 3b). Before the
  push `origin/main` was `3597d0a`, an ancestor of `main`, and the range held five single-parent
  commits and no merges; after it, local `main`, `origin/main` and `git ls-remote origin main` were
  all `896ee1293ac9`. This note's commit was pushed the same way, so HEAD is on `origin/main`.
  `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`) and has never been tracked or
  pushed.
- **The server's test state is gone (D047).** The five passes wrote playback state on **files 1, 2,
  4, 5 and 8 and no others** — a full read confirmed the rest of the library was untouched — and
  each was read, then written with `PUT …/playback {"position": 0, "watched": false}`, five `200`s.
  Before: Stargate Extended 1 821.678 s, Wonder Woman 2 457.189 s, Magicians S1E1 1 224.173 s, Food
  S4E2 `watched: true`, Divergent 0 with a `last_played`. After: **all five at position 0, watched
  false**, and `GET /api/continue-watching` is **`[]`**. So the app now opens with **no Continue
  Watching row** on Home (frame 00c) or on any library tab, and the launch focus D043 places is
  deliberately not placed — that branch is now the one in play, and it has not been seen on the
  device.
- **`last_played` survives the reset**, stamped to the write's own instant rather than null: the
  server sets it on every write and the body cannot clear it. Nothing depends on it — Continue
  Watching is `position > 0 and watched = false` server-side, Recently Added sorts on `added`, and
  the detail screens read only `position` and `watched` — except D026/D034's *followed* edition,
  which is still Extended on Stargate, as before.
- **Still uncommitted, unchanged, and deliberate:** the `PlayerHost.swift` Page Up / Down hook and
  the five UI-test harnesses (`Diag2gUITests.swift`, `Pass2bUITests.swift`, `Pass2cUITests.swift`,
  `Pass3ShotsUITests.swift`, `Pass3bShotsUITests.swift`).

### Pass 4 — the app icon (`reports/2026-09-16-pass4-app-icon.md`)

**Pass 4 (2026-09-16): the tvOS app icon — built, on the device, awaiting the owner.** Decision
D048; report `reports/2026-09-16-pass4-app-icon.md`, screenshots `reports/screenshots/p4/`. This
closes pass 1's open question 11 ("no asset catalog, no app icon"). **No Swift file was touched.**
- **The catalog is new.** `Marlin Media TV/Assets.xcassets/AppIcon.brandassets`, the project's first
  asset catalog, holding only the icon: `App Icon.imagestack` (400 × 240 @1x, 800 × 480 @2x) and
  `App Icon - App Store.imagestack` (1280 × 768), each a **two-layer** stack — Front over Back — and
  **neither carries a Middle slot**, which was removed rather than left empty. The six layer files
  come from `Design/tvos icons/Marlin Media tvOS Design.zip`, a second Claude Design export (D006);
  its `-flat` files and `preview-b.png` are previews and were not used. The zip is now tracked.
- **How it reaches the target.** `Marlin Media TV/` is a file-system-synchronized group, so the
  catalog joined the app target by being in the folder; the only project change was
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on the app target's Debug and Release
  configurations — **two added lines, and nothing else in `project.pbxproj` moved.**
- **Proven on Home Theater.** `BUILD SUCCEEDED` with no warnings; `actool` ran with `--app-icon
  AppIcon`; the built `Info.plist` carries `CFBundlePrimaryIcon = "App Icon"` and the compiled
  `Assets.car` lists `App Icon` as an `ImageStack` with `App Icon/Back/Content` and
  `App Icon/Front/Content` at tv 1x and 2x. Installed, launched (`[library] loaded 3 movies,
  2 shows, 0 videos`, `[continue] 0 entries` — the D047 reset still in place), and **photographed:
  tvOS's own Home screen shows the artwork where the generic tile used to be**.
- **The screenshot route is new** and worth keeping: `xcrun devicectl device capture screenshot`
  photographs anything on the device, tvOS's Home screen included, which no XCUITest harness can
  reach.
- **Top Shelf left alone,** as the pass required: both slots are declared and empty, and the build
  did not need them.
- **Committed, not pushed** — the owner looks first. Home Theater is left running this build. The
  `PlayerHost.swift` hook and the five harnesses stay uncommitted, unchanged.

### Pass 5 — the Top Shelf banners, and the app on the bedroom Apple TV (`reports/2026-09-16-pass5-topshelf-and-bedroom.md`)

**Pass 5 (2026-09-16): the Top Shelf banners land, and the app goes on Master Bedroom ATV at the
owner's request.** Decisions D049, D050; report `reports/2026-09-16-pass5-topshelf-and-bedroom.md`,
screenshots `reports/screenshots/p5/`. **No Swift file was touched, and neither app icon stack was
touched.**
- **The export was replaced (D049).** The owner put a newer Claude Design export at
  `Design/tvos icons/Marlin Media tvOS Design.zip` (2.4 MB → 7.25 MB), adding the four Top Shelf
  banners to the ten files pass 4 saw. **The six icon layers came back byte-identical** to the
  committed ones — checked by SHA-256 — so the icon stacks were left alone.
- **The Top Shelf slots are filled.** `Top Shelf Image` takes `topshelf-1920x720.png` @1x and
  `topshelf-3840x1440.png` @2x; `Top Shelf Image Wide` takes `topshelf-wide-2320x720.png` @1x and
  `topshelf-wide-4640x1440.png` @2x. All four are the size their name claims and **fully opaque**
  (minimum alpha 255 over every pixel). Nothing else in the catalog changed.
- **Proven on Home Theater.** `BUILD SUCCEEDED`; `Assets.car` grew 575 KB → 2.3 MB and now lists
  `Top Shelf Image` at 1920 × 720 / 3840 × 1440 and `Top Shelf Image Wide` at 2320 × 720 /
  4640 × 1440. Installed, launched (`[library] loaded 3 movies, 2 shows, 0 videos`), and
  **photographed with the banner actually on screen** — the app was the focused tile on tvOS's top
  row and the banner was drawn above it (`p5-1-home-theater-topshelf.png`).
- **The bedroom Apple TV now has the app (D050).** The owner confirmed it explicitly, reversing the
  standing "not used" line. `Master Bedroom ATV` is an Apple TV 4K 1st generation (`AppleTV6,2`,
  arm64), **tvOS 26.6, Developer Mode enabled, paired and connected** — so it cleared every gate.
  The same working tree built for it, installed and launched: same `[library]` line, Home drawn
  correctly (`p5-2-bedroom-app-running.png`). **It is not a test device** — D005 is unchanged and
  Home Theater remains the only place evidence is taken.
- **The bedroom Top Shelf could not be photographed.** A newly installed tvOS app lands at the end
  of the app grid, not the top row, and nothing here can press the remote to move focus there
  (`p5-3-bedroom-home-screen.png` shows a different app focused). The banner is proven on Home
  Theater only.
- **Committed, not pushed** — the owner looks first. Both Apple TVs are left running this build.
  The `PlayerHost.swift` hook and the five harnesses stay uncommitted, unchanged.

### Pass 6 — passes 4 and 5 accepted and pushed (`reports/2026-09-16-pass5-topshelf-and-bedroom.md`, no separate report)

**Pass 6 (2026-09-16): the owner accepted passes 4 and 5 and they are pushed.** Decision D051. The
owner tested the app icon, the Top Shelf banners and the bedroom install on the Apple TVs and
accepted them all ("all good"). **No app source, asset, project file or design file was touched,
nothing was built, installed or launched, and no device was touched.**
- **Pushed (D051).** `main` went to `origin` as a fast-forward, no force: **`ceae8c2..6de2d9b`, two
  commits** — `1a4d4ab` (pass 4, the app icon) and `6de2d9b` (pass 5, the Top Shelf banners and the
  bedroom install). Before the push `origin/main` was `ceae8c2`, an ancestor of `main`, and the
  range held two single-parent commits and no merges; after it, local `main`, `origin/main` and
  `git ls-remote origin main` were all `6de2d9b4029516c6f8c1ad65c1b789bbc5188553`. This note's
  commit was pushed the same way, so HEAD is on `origin/main`.
  `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`) and has never been tracked or
  pushed.
- **Nothing is waiting on the owner, and nothing is waiting to be pushed.** Every feature in
  **Current state** is accepted.
- **The open items are unchanged** — passes 4 and 5 answered none of them by being accepted, and
  raised none of their own here. The Top Shelf size question, the App Store icon, the icon parallax
  and the three bedroom items all still stand.
- **Still uncommitted, unchanged, and deliberate:** the `PlayerHost.swift` Page Up / Down hook and
  the five UI-test harnesses, plus the owner's `icon pixel/` and `Notes/`.
