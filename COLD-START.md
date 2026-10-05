# Marlin Media TV — cold start

Read this and DECISIONS.md before any work; do not re-derive what they settle. Per-pass
reports live in `reports/`. **Current state** is where the project stands now; **Pass history**
holds every pass note, oldest first.

**How the work is run (D068, since 2026-10-04):** the owner directs it in the chat, with no
foreman. The rules are in `CLAUDE.md` at the repo root; `/wrap` (`.claude/commands/wrap.md`) ends a
session and brings this notebook up to date. Commit locally; **never push until the owner says
"push it".** The numbered passes and their `reports/` files end with pass 7d — work after that is
recorded here and in `DECISIONS.md` by date, and no report file is written unless the owner asks.

## What this is

Five tvOS apps for **marlin-media**, the home media server (repo marlin1111ai/marlin-media; Go,
SQLite, TMDB metadata, direct-play streaming), built from this one project on one shared code base
(D069): **Marlin Movies, Marlin TV Shows, Marlin Videos, Marlin Music and Marlin Adult**, one per
kind of the one server. Until 2026-10-04 it was a single app, Marlin Media TV, with a combined
Home screen; that app is off both Apple TVs and out of the project (D070). Each app opens straight
onto its own library and plays the original files with VLCKit — the server never transcodes; it
serves the file bytes with HTTP Range support.

Marlin Movies, Marlin TV Shows and Marlin Videos carry the server's playback state (D023–D029):
Continue Watching, Resume with "N min left", Start over, watched marks, the per-episode state
column and a Recently Added sort; Marlin TV Shows adds an Up next row. Reading that state is
`GET /api/continue-watching` plus the `playback` block the server puts on every file of an item
(`MediaFile.playback` — editions, episodes and videos alike); writing it is
`PUT /api/files/{fileId}/playback`. **Marlin Adult** is the Movies screens on the server's separate
adult routes, with its own playback state there (D071). **Marlin Music** plays albums and saves
nothing to the server (D073).

## Where things are

- **Server:** `http://192.168.1.250:8093`, fixed in `ServerConfig.baseURL` (D007: no settings
  screen). Never the marlinpc dev copy. Image **0.10.0** when it was last read (`GET /api/health`,
  2026-10-04 — the apps themselves never call `/api/health`). **Every call the apps make**, read
  from the source (`APIClient` in `ServerAPI.swift`). The client knows which app it serves and
  **refuses a route across the adult line before it leaves the Apple TV**: Marlin Adult sends
  nothing outside `/api/adult/`, and the other four send nothing inside it (D071).
  - **Marlin Movies:** `GET /api/movies` and `GET /api/movies/{id}` — the movie list, and one movie
    with its editions.
  - **Marlin TV Shows:** `GET /api/shows` and `GET /api/shows/{id}` — the show list, and one show
    with its seasons and episodes. The list carries no episodes, so the first screen asks for one
    `GET /api/shows/{id}` **per show, every time it appears**, for the Up next row (D040's order,
    D069), and the show screen asks for its own.
  - **Marlin Videos:** `GET /api/videos`.
  - **Those three:** `GET /api/continue-watching?limit=200` — the server's in-progress list
    (`position > 0` and not watched), newest `last_played` first, one entry per file, decoded as
    `ContinueEntry`; each app shows only its own kind. A failure here is a log line and an absent
    row, not a library failure (D024).
  - **Those three:** `PUT /api/files/{fileId}/playback` with `{position?, watched?}` — **their only
    write** (D024, D028). An omitted key means "leave unchanged"; the server stamps `last_played`
    itself and answers with the block it stored. Every write goes through `PlaybackWrite.send`,
    which logs the request and the answer; **a failed write is a log line and nothing else**.
  - **Marlin Music:** `GET /api/albums`, `GET /api/albums/{id}` (one album with its tracks) and
    `GET /api/artists`. An artist's albums are picked out of the album list by `artist_id`; the
    server's `/api/artists/{id}` and `/api/tracks` are not used. **No write of any kind** — the
    client refuses a playback write in this app (D073).
  - **Marlin Adult:** `GET /api/adult/titles` and `GET /api/adult/titles/{id}` — the movie shape
    without the TMDB fields, plus `studio`, `release_date`, `performers` and `overview` since
    server 0.10.0 — and `PUT /api/adult/files/{fileId}/playback`, the same body and the same 90 %
    rule. **The server keeps no continue list for adult**: the app's Continue Watching row is made
    from the titles' own `playback` blocks (D071).
  - the stream — `GET /stream/{fileId}`, or `/api/adult/stream/{fileId}` for an adult file — the
    original file, Range-served, handed to VLCKit. The path is the item's own `stream` field,
    resolved against the base URL (`Models.swift:50–52`); a music track carries one too.
  - `GET /api/artwork/…` (and `/api/adult/artwork/…`, and an album's `cover`) — posters,
    backdrops, episode stills and covers, as server-relative paths carried in the JSON and resolved
    the same way (`ServerImage.swift`, `Artwork` in `Models.swift`, `AlbumArtwork` in
    `MusicModels.swift`).
  - the timeline stills, there since image 0.3.0 (pass 2g), for the three film apps and Marlin
    Adult (whose index is `/api/adult/files/{fileId}/thumbs`; its sheet URLs come back under
    `/api/adult/thumbs/`):
    - `GET /api/files/{fileId}/thumbs` — the index: `interval` (10 s), `tile_width` (320),
      `tile_height` (214 on the films measured), `columns` (6), `rows` (5), `per_sheet` (30),
      `count`, `state` (`none` | `generating` | `complete` | `failed`) and `sheets`, an array of the
      sheets that exist **at that moment**, each `{index, first_still, url}`. Generation starts on
      the first index request, so the first caller usually gets `generating` with `sheets: []`; a
      file with no usable duration returns `none`, and `failed` re-queues on request. An unknown
      file id is `404 {"error":"file not found"}`. Asked for **once when a detail screen opens**,
      for the file that would play, and never polled or re-fetched (D021, `APIClient.thumbs`).
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
  Build what the frames show; design nothing (D006). **Marlin Music's and Marlin Adult's screens
  have no frames:** by the owner's decision they follow the frames' look (D073).
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

  **The five apps' sets (D072, 2026-10-04)** are that artwork re-lettered. In each
  `AppIcon-<Kind>.brandassets` the back layers are byte-identical copies, and the front layers and
  the four Top Shelf banners carry the same marlin artwork with "MARLIN MEDIA" replaced by the
  app's own words — MARLIN MOVIES, MARLIN TV SHOWS, MARLIN VIDEOS, MARLIN MUSIC, MARLIN ADULT — in
  Verdana Bold, black, at the old lettering's size and baseline, centred on the picture. They were
  drawn by a one-off script that was not kept. The owner may replace them with designed ones later.
- **Devices.** Two physical Apple TVs are paired with this Mac, and they are **not** equals:
  - **Home Theater** — Apple TV 4K (3rd generation, `AppleTV14,1`, arm64e), tvOS 26.6, Developer
    Mode enabled, on the local network. **The dev/test device (D005), and still the only one.**
    Every build, check, log and screenshot of evidence comes from here. It carries Marlin Movies,
    Marlin TV Shows, Marlin Videos and Marlin Music. **It never carries Marlin Adult (D071):** a
    check of that app puts it on Home Theater at a time the owner picks and removes it straight
    afterwards. **It is also the household's television:** look at what is on its screen before
    launching or reinstalling anything, and ask the owner if another app is in use.
  - **Master Bedroom ATV** — Apple TV 4K (1st generation, `AppleTV6,2`, arm64), tvOS 26.6,
    Developer Mode enabled, on the local network. **It carries all five apps for the household,
    Marlin Adult among them (D050, D071) — it is not a test device.** Nothing is proven there and
    no evidence is taken there, its screen included. **Every push that follows the owner's
    acceptance of work that changed the apps also installs the accepted builds there — install
    only, no launch (D061).**

  The hardware facts were read from `xcrun devicectl` on 2026-09-16; both boxes were paired and
  reachable on 2026-10-04.
- **Xcode:** 27.0 (27A266a), tvOS 27.0 SDK (24J360) — since 2026-09-14 (pass 1e rerun; supersedes
  26.6 (17F113) / tvOS 26.5 SDK). Team `C879JNVK7Z`, automatic signing (both read from Marlin DVR
  TV). **Five bundle ids, one per app:** `com.marlin1111.marlin-movies-tv`,
  `com.marlin1111.marlin-tv-shows-tv`, `com.marlin1111.marlin-videos-tv`,
  `com.marlin1111.marlin-music-tv` and `com.marlin1111.marlin-adult-tv`. The old app's
  `com.marlin1111.marlin-media-tv` is retired (D070); the UI-test target keeps
  `com.marlin1111.marlin-media-tv.UITests`. The signing profile is the team's wildcard tvOS
  profile (created 2026-08-17, a year's life, both boxes on it), so a new bundle id needs nothing
  more.

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
  text lives in history at `e7676fa`, as
  `reports/logs/2f-0021-es_out-no-late-pcr-compensation-while-paused.diff.txt` (D066).
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
  `~/vlckit-build` is **19 135 087 445 bytes in 256 944 files (17.8 GB; `du` 18 G)**, measured on 2026-09-19
  after pass 7 deleted the recon's §6b leftovers from it (D062). It was 22 GB on 2026-09-13.
- **Minimum tvOS:** 26.0 exactly (`TVOS_DEPLOYMENT_TARGET = 26.0`, D004). Both Apple TVs run 26.6.
- **No CocoaPods, no xcodegen, no brew installs.** The project file was written by hand
  (objectVersion 71, file-system-synchronized groups); Xcode opens it normally. The one source
  folder, `Marlin Media TV/`, belongs to **all five app targets**, so everything in it is in every
  app by virtue of being in the folder (D069).
- **Fonts:** the system font. The design names Inter; no font is bundled — the system font stays
  and Inter is overruled (D059).
- **Asset catalog:** `Marlin Media TV/Assets.xcassets` holds five brand-asset sets and nothing
  else — `AppIcon-Movies`, `AppIcon-TVShows`, `AppIcon-Videos`, `AppIcon-Music` and
  `AppIcon-Adult` (`.brandassets`), each a layered tvOS app icon (D048's shape) and the two Top
  Shelf banners (D049's shape), re-lettered for its app (D072). Each target's
  `ASSETCATALOG_COMPILER_APPICON_NAME` names its own set, and only that set is compiled into the
  app (read from each built `Assets.car` on 2026-10-04). There is no accent colour, no launch image
  and no other asset — the UI's colours are `Theme.swift`'s tokens, not the catalog.

## Build, install, run (all from the repo root)

One scheme, one target and one product per app (D069):

| App | Scheme, target and product name | Bundle id | `MARLIN_APP` |
|---|---|---|---|
| Marlin Movies | `Marlin Movies` | `com.marlin1111.marlin-movies-tv` | `movies` |
| Marlin TV Shows | `Marlin TV Shows` | `com.marlin1111.marlin-tv-shows-tv` | `shows` |
| Marlin Videos | `Marlin Videos` | `com.marlin1111.marlin-videos-tv` | `videos` |
| Marlin Music | `Marlin Music` | `com.marlin1111.marlin-music-tv` | `music` |
| Marlin Adult | `Marlin Adult` | `com.marlin1111.marlin-adult-tv` | `adult` |

```
xcodebuild build -project "Marlin Media TV.xcodeproj" -scheme "<scheme>" \
  -destination 'platform=tvOS,name=Home Theater' -derivedDataPath build/DerivedData -allowProvisioningUpdates
xcrun devicectl device install app --device <Home Theater identifier> \
  "build/DerivedData/Build/Products/Debug-appletvos/<scheme>.app"
xcrun devicectl device process launch --console --terminate-existing --device <id> <bundle id>
```
**A change to the shared code means building all five schemes**; after the first, each takes a
few seconds. `xcrun devicectl list devices` gives the identifier. Each launch writes
`Library/Caches/marlin-media-tv.log` in **that app's own** container (VLCKit's debug log plus the
app's `[player]`, `[playback]`, `[detail]`, `[focus]`, `[hold]`, `[scrub]`, `[thumbs]`,
`[continue]`, `[upnext]`, `[music]`, `[album]` and `[app]` lines); copy it off with
`xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier <bundle id> --source Library/Caches/marlin-media-tv.log --destination <file>`.
`EvidenceLog` opens the file on its **first line**, not when a player starts, because the detail
screens write with no player up (pass 2). **Marlin Adult's log carries ids only** — no title,
studio, performer or file name — **and no VLCKit lines at all** (D071).

**Building for the other Apple TV.** The same command with
`-destination 'platform=tvOS,name=Master Bedroom ATV'` builds for the bedroom box (D050). Both
boxes take the same arm64 build: on 2026-10-04 the builds made and checked for Home Theater were
installed on the bedroom box as they were. **Every push that follows the owner's acceptance of
work that changed the apps installs the accepted builds there — install only, no launch (D061).**
Home Theater is the dev/test device (D005), and the bedroom box is in household use — launching
there puts the app on a television someone may be watching. **Marlin Adult is installed on the
bedroom box only** (D071).

**Photographing the device without a harness** (pass 4):
`xcrun devicectl device capture screenshot --device <id> --destination <file.png>` takes a
3840 × 2160 PNG of whatever is on the screen, **including tvOS's own Home screen and any other
app** — which the UI-test harnesses cannot reach, because XCUITest only ever sees the app under
test. `devicectl device info processes --device <id>` says what is running. Use this for anything
outside the Marlin apps; use a harness when the shot has to be taken at a particular point in an
app's own flow. **It is also how to see whether Home Theater is in use before launching anything**
— delete such a picture once it has been looked at, and never take one of the bedroom box.

**Evidence harnesses** (the Marlin DVR TV convention — throwaways written for one check, not a
standing test suite). **There is none in the repo or in the working tree** (D076). The UI-test
target `Marlin Media TVUITests` is still in the project, hosted on Marlin Movies, but its folder
holds no file and does not exist in a fresh clone: create `Marlin Media TVUITests/`, write the
harness into it, and delete it after the check. A harness drives the real remote through
`XCUIRemote` on Home Theater and photographs the screen; it navigates by reading which element has
focus (`hasFocus == YES`), never by counting presses. **One harness can drive any of the five
apps** with `XCUIApplication(bundleIdentifier:)`. Build with `build-for-testing` on the
`Marlin Movies` scheme, then
`xcodebuild test-without-building … -only-testing:"Marlin Media TVUITests/<Class>/<test>" -resultBundlePath <x.xcresult>`
and `xcrun xcresulttool export attachments --path <x.xcresult> --output-path <dir>` for the PNGs.
- Each run leaves a `Marlin Media TVUITests-Runner` app with a blank icon on the Home Screen.
  Remove it when the check is done:
  `xcrun devicectl device uninstall app --device <id> com.marlin1111.marlin-media-tv.UITests.xctrunner`.
- On this television `XCUIRemote.press(.home)` opens the Apple TV app; a second press reaches the
  Home Screen. In a grid, Down from a right-hand column above a short last row goes nowhere — walk
  back to the row's first column before pressing Down.
- `XCUIRemote` has no touch-surface API, so a paused scrub drag cannot be scripted by a harness
  alone. Passes 2a–2g did it with a Page Up / Page Down hook in `PlayerHost.swift` that was never
  committed. The hook and the pass 2g harness are in history at `e7676fa`
  (`reports/logs/2g-harness-hook.diff`, `reports/logs/2g-harness-Diag2gUITests.swift.txt`, D066);
  the other four harnesses of those passes are gone (D076).
- **Marlin Adult is checked without pictures** (D071): counts and yes/no answers only, and its log
  searched for the title, studio, performers and file name with only the number of hits printed.

## How the app is put together

Twenty-two Swift files, all of them in `Marlin Media TV/` and so in all five app targets. The
project has six targets: the five apps — alike but for their name, bundle id, icon set and
`MARLIN_APP` — and the UI-test target.

**Entry and shell**
- `MarlinMediaTVApp.swift` — the `@main` scene; one `WindowGroup` holding `ContentView`.
- `AppKind.swift` — which of the five apps this is (D069). `AppKind.current` reads the Info.plist
  key `MarlinApp`, which each target fills from its `MARLIN_APP` build setting; a missing or
  unknown value stops the app at launch rather than opening the wrong library. It also gives the
  header's word and the first screen's tabs.
- `ContentView.swift` — the navigation: **the app's own library is the root** (D069), detail
  screens push above it, and the film player is a full-screen cover above everything. It counts
  the player's closes (`playerClosed`) and hands that count to every detail screen, because a
  full-screen cover never takes its content off screen and so fires no appearance callback (D032),
  and it re-reads the library on each close. In Marlin Music it owns the `MusicPlayer` from launch,
  sends the remote's Play/Pause to it from any screen, pops Now Playing when the music ends, and
  stops the music when the app leaves the screen (D073).

**Server and data**
- `Models.swift` — Decodable models of the server JSON (every field real; decoded with
  `convertFromSnakeCase`), including `Artwork`, `Playback` and `ContinueEntry`, plus `Format`, the
  display mapping of the server's values (codec names, "7.1", "2 h 20 min", "13.2 GB"). `Movie`
  also reads Marlin Adult's titles: with the adult flag in the decoder's `userInfo` the TMDB fields
  are not asked of it and `studio` and `performers` are read; a movie is still read strictly.
- `MusicModels.swift` — `Album`, `Artist` and `Track` (and `AlbumArtwork`), read against the live
  server on 2026-10-04, and a track's "FLAC · 96 kHz · 24-bit · 2.0" line.
- `ServerAPI.swift` — `ServerConfig` (the fixed base URL and path resolution), `APIError` (every
  failure carries a message the UI shows in full; `.refused` is a route the app is not allowed to
  ask for) and `APIClient`, which knows its `AppKind`: the calls listed above, the adult line, and
  no write in Marlin Music.
- `ServerImage.swift` — artwork loading from server-relative paths, with the frames' placeholder
  (`InitialTile`: the gradient tile with the title's initial) while loading, when there is no
  artwork and when the load fails.
- `PlayRequest.swift` — what the player is asked to play: the stream URL, frame 10's two overlay
  lines, and `startMs`, where playback begins (D029). It also decides whether a thumbnail index
  belongs to the file being played (`PlayRequest.matching`).
- `LibraryModel.swift` — **the lists of its own app's kind and no other** (a failure is the whole
  library's failure, frame 17), the Continue Watching list (whose failure is only a log line;
  Marlin Adult's is made from its titles' own positions, and Marlin Music has none), `SortOrder`
  (**Title / Year / Recently Added**, D010/D023), every show's episodes and the Up next row built
  from them (D040's order, D069), and Marlin Music's albums and artists.

**Screens**
- `LibraryScreen.swift` — **each app's first screen**: frames 01 (Movies), 02 (TV Shows),
  03 (Videos), 04 (Videos empty), 05 (the sort control open), 16 (loading) and 17 (can't reach
  server), without the tab bar — the app's word stands where the tabs were, except in Marlin
  Music, whose tabs are Albums and Artists and switch on click. The sort menu is **Title / Year /
  Recently Added**; a Continue Watching row sits above the grid, focus entering that row lands on
  its first card (D033), and **the launch focus goes to that card** (D043, carried over from Home).
  Marlin TV Shows adds the **Up next** row under it, in frame 00b's wide card. The grid and the
  video list scroll **clipped**, so a row scrolled away is cut off below the header (D075). The
  screen re-reads itself every time it appears. Marlin Adult's grid is headed "All titles" and
  shows the studio under each poster. Frame 17's "Browse cached" button is not built: no cache and
  no button, the frame overruled (D059).
- `MovieDetailScreen.swift` — frames 06 (movie detail) and 07 (edition picker), with the watched
  pill, "Resume · N min left" and its in-button bar, "Start over", "Mark watched / unwatched" and
  the multi-edition rule (D026, D034). In Marlin Adult the meta row is the date, the studio and the
  file's length, with the performers under it (D071).
- `ShowDetailScreen.swift` — frame 08: season selector and episode list, "N unwatched" in the meta
  row, the per-episode state column, a click that resumes at the saved position and a
  press-and-hold that opens the mark menu (D027, D031, D039).
- `VideoDetailScreen.swift` — frame 09, behaving exactly as the movie detail but with one file, so
  no picker and nothing to follow. The owner reports videos run fine on the device, which
  discharges D038's owed check (D052).
- `MusicScreens.swift` — Marlin Music, in the frames' look with no frames of its own (D073): the
  square cover card of the Albums and Artists grids; one artist's albums; the album page (cover,
  the album's lines, Play, and the tracks with disc headings, the playing track marked); and Now
  Playing (cover, track, artist, album, format, time bar, Previous / Pause / Next and the next
  track's name). The headers and the album page carry a Now Playing button while music is playing
  or paused.
- `NowClock.swift` — the date-and-time pair the new frames put at the top right (D041). It draws
  only the pair; the placement (`right: 80, top: 56`) belongs to each screen. It ticks once a
  second while it is on screen.

**Player**
- `PlayerModel.swift` — VLCKit and the remote's meaning (D008 revised): click = play/pause,
  Menu = back, skips while playing, a native one-picture frame step on a left/right click while
  paused, and the paused touch-surface scrub with its landing and cancel (D021). It also adds
  `:demux=mkv_trusted` on `.mkv` streams (D014), asks tvOS to match the display to the stream
  (D016), seeks once to a `startMs` at the first `Playing` state (D029), and writes the position on
  the D028 schedule. In Marlin Adult it attaches no VLCKit logger and withholds names from its own
  log lines (D071).
- `PlayerHost.swift` — the UIKit surface that owns every press, touch and swipe, and the VLCKit
  drawable. An edge click is a `UIPress`; a swipe is not a press at all; the scrub pan runs
  alongside the swipe recognizers and begins only while paused. The uncommitted Page Up / Page
  Down harness hook this file carried in the working tree from pass 2a is gone (D076).
- `PlayerScreen.swift` — frames 10–15 plus the scrub bar and its thumbnail, and the clock, which
  shows whenever the film is not playing, scrub and buffering included (D045, D054). Visuals only:
  the whole stack is `allowsHitTesting(false)` and nothing in it is focusable.
- `ThumbStrip.swift` — the server's timeline stills: the index model (`ThumbIndex`, `ThumbSheet`),
  the arithmetic that turns a target time into a sheet and a tile, the sheet fetches and the draw.
  Where a still does not exist, nothing is drawn (D021).
- `MusicPlayer.swift` — Marlin Music's player (D073): one VLCKit player with no picture, alive
  from launch; an album's tracks are its queue. A track's end starts the next; a change of track
  stops the player first and loads the new one from the `Stopped` state that follows; Previous
  goes to the track's start after 3 s and to the track before until then. It writes nothing to the
  server.

**Support**
- `Theme.swift` — the Nocturne tokens from `Design/_ds/…/styles.css` plus the values the frames use
  inline; screens are 1920 × 1080 at 1×, content 80 pt from the sides. (Its header comment says
  "the 20 frames" of the Design2 export, D042 — corrected in pass 7, D065.)
- `EvidenceLog.swift` — one log file per launch in `Library/Caches`, VLCKit's own debug logger and
  the app's bracketed lines interleaved, also echoed to the console (D011). In Marlin Adult
  `named()` withholds every name on its way into a line, and no VLCKit logger is handed out (D071).

Outside the Swift files:
- `Marlin Media TV/Assets.xcassets` — the asset catalog: the five apps' brand-asset sets (see
  Toolchain facts). Each holds the tvOS Home screen icon (`App Icon.imagestack`, 400 × 240 @1x and
  800 × 480 @2x) and the App Store icon (`App Icon - App Store.imagestack`, 1280 × 768), each a
  **two-layer** stack, Front over Back, with no Middle slot (D048), and the **Top Shelf banners**
  (D049) — `Top Shelf Image.imageset` at 1920 × 720 @1x and 3840 × 1440 @2x, and
  `Top Shelf Image Wide.imageset` at 2320 × 720 @1x and 4640 × 1440 @2x, flat opaque PNGs. The
  banners are what tvOS draws above the Home screen's top row when the app is the focused one
  there. Being inside `Marlin Media TV/`, the catalog joins every app target through the
  synchronized group.
- `Frameworks/VLCKit.xcframework` — the custom VLCKit (D012/D013), linked and embedded (code-sign
  on copy) by each app target; not in git. Rebuild with `tools/vlckit-truehd/build.sh`.
- `Info.plist` carries `NSAppTransportSecurity` → `NSAllowsLocalNetworking`, so plain HTTP to
  192.168.1.250 is allowed, and `MarlinApp` = `$(MARLIN_APP)`, which is how an app knows its kind.

## Current state

As of **2026-10-04**, the evening the app became five (D068–D076). The owner now directs the work
directly (D068). That session built the five apps from the one code base, checked four of them on
Home Theater and Marlin Adult briefly there, had the owner's test and acceptance of all five, put
all five on the bedroom box, removed the old Marlin Media TV app from both boxes, and pushed. The
last numbered pass before it was pass 7d (2026-09-19), notebook only.

### Built and owner-accepted

Every feature below has been tested by the owner on the Apple TVs and accepted; **nothing is
waiting on an owner test.**

- **The five apps (D069–D075, 2026-10-04):** Marlin Movies, Marlin TV Shows, Marlin Videos and
  Marlin Music on Home Theater — the owner's words, "all work" — and Marlin Adult on the bedroom
  box — "1 works". Each opens straight onto its own library with its own Continue Watching row;
  Marlin TV Shows has the Up next row; Marlin Music has Albums, Artists, the album page and Now
  Playing, plays on while browsing and stops when the app is left; Marlin Adult is the Movies
  screens on the adult routes with the date, studio, length and performers. Each has its own
  re-lettered icon and Top Shelf banners (D072).
- **The library and the player** (pass 1): the three library tabs, movie, show and video detail,
  the edition picker, and VLCKit playing the four MKVs and a Magicians episode directly — the
  overlay, the −10 s / +30 s skips, pause, the audio and subtitle panels, and Menu closing an open
  panel. The custom VLCKit decodes TrueHD to 8-channel PCM (D012, D015), MKV seeks use the file's
  cues (D014), tvOS matches the display to the stream (D016), and the VideoToolbox reorder fix
  ended Wonder Woman's judder (D017). **Videos run on the device too, on the owner's report
  (D052)** — no pass has photographed them.
- **Native frame-back while paused** (D008 revised, D019, D020): a left/right click steps exactly
  one picture, both ways, on avcodec and VideoToolbox streams. Accepted and pushed in pass 1l.
- **The paused touch-surface scrub with timeline thumbnails** (D021 revised again, D022): a swipe
  or drag while paused moves the target and the server's nearest still, the picture holds, click or
  Play/Pause lands and plays, Menu cancels and stays paused, and arrow clicks are ignored while a
  scrub is up (D056). The owner tried the gesture by hand and accepted it; pushed in pass 2h. **The
  thumbnails' next step is parked on the server (D055).**
- **Playback state** (D023–D029, D032, D034–D036): Recently Added in each of the three film apps' sort, the
  Continue Watching row in each app's library (it was on Home and each library tab until D069), Resume / Start over / the watched pill / Mark watched
  and unwatched on the movie and video details, "N unwatched" and the per-episode state column on
  the show detail, position writes on the D028 schedule with a 120 s floor and the watched mark at
  90 %, and resuming at a saved position with one seek.
- **The episode row** (D031, D039): a click plays or resumes, a hold of 0.6 s or more opens the
  mark menu, and the focus highlight is back.
- **The Continue Watching focus rule** (D033) in each app's library, and **launch focus on the
  first Continue Watching card** (D043) on each app's first screen, carried over from Home (D069).
- **The combined Home screen is gone** (D069, which supersedes D040's first screen and D053). What
  it left behind: its TV row's order, now Marlin TV Shows' Up next row without the episodes in
  progress — still one `GET /api/shows/{id}` per show every time the first screen appears — and
  its wide episode card.
- **The library's rows are cut off below the header** when the screen scrolls (D075).
- **The clock** (D041, D044, D045, D054): on every app's first screen, the movie, show and video
  screens, Marlin Music's screens, frames 16 and 17 (a code trace, accepted as such), and the
  player **whenever the film is not playing — paused, scrubbing or buffering**.

**Where the frames are overruled (D059):** the system font stays and Inter is not bundled; there is
no cache and no "Browse cached" button on frame 17; the rating chip shows the TMDB score, not frame
06's "R". The audio panel shows what VLC reports (D064). Marlin Music's and Marlin Adult's screens have no
frames at all and follow the frames' look (D073), and the five icon sets are the old artwork
re-lettered, not a Claude Design export (D072).

**Known and accepted as behaviour rather than defects, not open:**
- **D020's two** — Play after any frame step drops the pictures below the demuxer's clock start
  (21–45 pictures, about 0.9–1.5 s), and patch 0020's remaining gap, where a plain pause taken
  after a frame step can read ahead while paused if a subtitle track is selected.
- **D056's** — a pause after a scrub landing lets the demuxer read at 1× while paused, up to about
  36 s of stream; one picture late or dropped at audio start while tvOS switches display mode;
  audio start unmeasured and accepted by ear; and the list of one-offs D056 names, each reopened
  only if the owner sees it again.
- **Nothing goes to VideoLAN (D057).** The draft stays at
  `reports/logs/1k-upstream-videolan-draft.md`, unsent.

### Pushed

Everything up to `015ed7f` is on `origin/main`. **The notebook commit that records the 2026-10-04
session (this file and `DECISIONS.md`, made at wrap-up) sits on top of it and is pushed when the
owner says "push it"** — `git status -sb` says whether it has been.

- Passes 1–1e up to `b22f9c9` (pass 1e rerun 4).
- Passes 1f–1k as `b22f9c9..6bfdbad`, six commits (pass 1l).
- Passes 2a–2g as `e9df636..1e13538`, seven commits (pass 2h).
- Passes 2–3b as `3597d0a..896ee12`, five commits (pass 3c, D046).
- Passes 4 and 5 as `ceae8c2..6de2d9b`, two commits (pass 6, D051); pass 6's own notebook commit
  is `033c587`.
- The stale-files recon as `033c587..e7676fa`, one commit holding one file,
  `reports/2026-09-19-stale-files-recon.md`.
- **Pass 7 as one commit on top of `e7676fa`**, a fast-forward, no force, no merges: the removal
  of 770 files from `reports/` (D066), the two one-line text fixes, the notebook and the pass 7
  report. After the push, local `main`, `origin/main` and `git ls-remote origin main` were compared
  and agree; the SHA is in the pass's closing message, since a commit cannot name itself.
- **Pass 7b as one notebook commit on top of `f4fafa1`**, which is pass 7's commit
  (`e7676fa..f4fafa1`) — a fast-forward, no force; the three SHAs were compared after the push and
  agree.
- **Pass 7c as one notebook commit on top of `d813054`**, which is pass 7b's commit
  (`f4fafa1..d813054`) — a fast-forward, no force; the three SHAs were compared after the push and
  agree.
- **Pass 7d as one notebook commit on top of `ee3613b`**, which is pass 7c's commit
  (`d813054..ee3613b`) — a fast-forward, no force; the three SHAs were compared after the push and
  agree.
- **The working rules as `7816a21..acd2b29`**, one commit: `CLAUDE.md` and
  `.claude/commands/wrap.md` (D068). A fast-forward, no force; the three SHAs were compared after
  the push and agree.
- **The five apps as `acd2b29..015ed7f`**, four commits, pushed on the owner's word after the
  acceptance: `c065545` (the five apps), `49559fa` (the album page's track list), `bd708fa` (the
  rows cut off below the header, D075) and `015ed7f` (the old app's icon set and its two test
  scripts removed, D070). A fast-forward, no force, no merges; local `main`, `origin/main` and
  `git ls-remote origin main` were compared after the push and agree.
- **`e7676fa` is the last commit that holds `reports/screenshots/` and `reports/logs/` (D066).**
  Every path this notebook or any report cites under those two folders resolves only there:
  `git show e7676fa:reports/logs/<file>`. The one file still in the tree is
  `reports/logs/1k-upstream-videolan-draft.md`.
- `bd708fa` is the newest commit that changed Swift **code**; `015ed7f` after it removed assets
  and test scripts only. Before 2026-10-04 the newest was `896ee12`.
- `Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`). Nothing under `Frameworks/`
  is tracked on any ref, so the 725 MB framework has never been pushed. **Since pass 7 it is the
  only copy of the framework on this Mac**: the byte-identical one under `~/vlckit-build` was
  deleted as a duplicate. `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh` remakes it in about 30 s
  from the static libraries that were kept.

### Deliberately uncommitted

- **`icon pixel/` and `Notes/` — the owner's own files, deliberately outside git (D063).** They
  are not opened, moved, staged or committed by any work here. They are the only entries
  `git status` shows.
- **Nothing else.** The Page Up / Page Down hook in `PlayerHost.swift` and the five UI-test
  harnesses that were kept uncommitted from passes 2a–3b were deleted on 2026-10-04, at the
  owner's word (D076): they drove the old app's Home screen and tabs and could no longer run.

The owner's `Design/Marlin Media tvOS Design2.zip` is not in the folder at all: pass 3 unzipped it
and deleted the zip (D042). The older `Design/Marlin Media tvOS Design.zip` is tracked and stays.

### What the Apple TVs run

Both carry **the builds of 2026-10-04, 20:37–20:38**: `bd708fa`'s Swift code, built from a working
tree that still held the `PlayerHost.swift` harness hook. That hook is the only difference from
the code on `main`, and the next install replaces it. The old Marlin Media TV app was removed
from both boxes on 2026-10-04 (D070).

- **Home Theater** — the dev/test device (D005): Marlin Movies, Marlin TV Shows, Marlin Videos and
  Marlin Music; on 2026-10-04 they sat in the Home Screen's top row. **No Marlin Adult** (D071):
  it was there for its check that evening, from 21:05 for a few minutes, and was removed.
- **Master Bedroom ATV** — all five, installed and never launched from here. **Standing rule
  (D061): every push that follows the owner's acceptance of work that changed the apps also
  installs the accepted builds there — install only, no launch.** That install is also what renews
  the provisioning; if an app ever refuses to open there, the remedy is a reinstall. D005 is
  unchanged: no evidence is taken there.

### The server's state

Read on 2026-10-04 at wrap-up: image **0.10.0**; 3 movies, 5 shows, 20 seasons, 344 episodes,
3 videos, 11 albums by 4 artists, 155 tracks (`GET /api/health`, which does not count adult), and
4 adult titles (`GET /api/adult/titles`, counted, not read). It grew during the session: 4 shows
and no adult title at about 19:40, one adult title by 21:00. The in-progress list held two
entries, the owner's own viewing (`movie/4`, `episode/17`), and the session's checks left both as
they were. The music is FLAC but for one album in APE (album 5, nine tracks), all of it stereo at
44.1 or 96 kHz.

### Open items

The owner ruled on every open item on 2026-09-19 (D052–D067): 49 of the recon's 56 are closed.
**Three entries remain, all parked (seven of the recon's numbers). Nothing is open.**

1. **PARKED — the scrub thumbnails (D055).** Waiting on the server (marlin-media) generating
   thumbnails when it scans a file in, which the owner is taking to that project. When it lands:
   **the app fetches the index for the file actually played, and asks again at scrub start until
   the server reports `complete`.** Until then the app is as pass 2g left it — one index per detail
   screen, for a movie's first edition or a show's first episode of season 1, never re-fetched, so
   any other edition or episode plays with no thumbnails and a file's first visit shows none.
   Parked with it, undecided: the stills are letterboxed into the server's 320 × 214 tile (crop in
   the client, or leave it?); nothing logs which still is drawn; and the thumbnail has only ever
   run on Stargate with a warm server.
2. **PARKED — an edition with no name.** The owner chose **"show nothing where an edition has no
   name"** (today the row and the overlay show the file name, e.g. `Wonder Woman (2017).mkv`).
   Not built. — D064.
3. **PARKED — badges on shows, possibly later.** `/api/shows` carries no per-file resolution or
   HDR. The owner reports the posters show no badges at all today. — D064.

**From the five apps (2026-10-04) — known, not open:**
- **Not tried by anyone:** whether Marlin Music keeps playing when the screensaver comes on, and
  whether a gap is heard between tracks (each track starts when the one before it has ended;
  nothing was measured).
- **The icons and Top Shelf banners are the old artwork re-lettered** (D072); the owner may send
  designed ones.
- **Marlin Music and Marlin Adult have no design frames** (D073); they follow the frames' look.
- **The adult title played in the check had no timeline stills:** the server answered its index
  with `state failed`. A server matter; the app drew no thumbnail, as D021 has it.
- **The UI-test target has no file** (D076); see Evidence harnesses under Build, install, run.
- A stale `Marlin Media TV.app` from before the split is still among the products in the shared
  `build/` folder. Nothing uses it.

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

### Pass 7 — the cleanup, and the owner's calls on every open item (`reports/2026-09-19-pass7-cleanup.md`)

**Pass 7 (2026-09-19): the stale files deleted, the evidence files taken out of the tree, and every
open item ruled on.** Decisions D052–D066; report `reports/2026-09-19-pass7-cleanup.md`. It follows
the read-only recon of the same day, `reports/2026-09-19-stale-files-recon.md` (commit `e7676fa`,
no pass number and no note of its own here), whose §6 was this pass's delete list and whose §10a /
§10b numbering the owner's calls use. **No Swift code changed — one comment line did — and nothing
was installed or launched on either Apple TV.**
- **Deleted, permanently (D062): 9 082 files, 7 062 841 475 bytes**, every one re-verified against
  the recon first and none skipped. In the repo 1 638 files / 2 943 524 268 bytes — the stock VLCKit
  Swift package left in `build/DerivedData/SourcePackages` since pass 1 (2.74 GB), the tvOS 26.5
  `.xctestrun`, five `build/*.out` captures and two `.DS_Store`. Under `~/vlckit-build` 7 444 files /
  4 119 317 207 bytes — VLCKit's two `.xcarchive` packaging intermediates (2.94 GB), the
  byte-identical second copy of the framework (725 MB, re-hashed by SHA-256 before it went),
  `host-test-1i` (196 MB), seven loose build outputs and 46 Finder `.DS_Store`. The volume's used
  space fell by 6 187 192 KB. **`~/vlckit-build` is kept** and is now 17.8 GB; everything the recon
  listed as in use or to keep was re-counted afterwards at its exact recon size.
- **The screenshots and logs are out of the tree (D066):** `git rm` of all 569 files under
  `reports/screenshots/` and 201 of the 202 under `reports/logs/` — 770 files, 459 748 317 bytes —
  leaving `reports/logs/1k-upstream-videolan-draft.md` and every written report. **`e7676fa` is
  the last commit that holds them.**
- **Two text fixes:** `Theme.swift:5` says "the 20 frames" (D042), and
  `tools/vlckit-truehd/README.md:10` says patch 0020 was decided as D019 in pass 1k.
- **The evidence log, read only:** each launch replaces it and nothing caps it; Home Theater's
  current one was 53 049 bytes over 25.3 s. The on-or-off decision is the owner's — open item 4.
- **Built once, not installed:** `** BUILD SUCCEEDED **` with the package folder gone, and
  `SourcePackages` did not come back.
- **The owner's calls closed 48 of the recon's 56 open items.** Seven are parked — five of them
  the scrub thumbnails — and one is open: four entries under **Open items**. The new standing rule is D061: a push pass that follows the owner's acceptance of
  a pass that changed the app also installs on Master Bedroom ATV, install only.
- **Committed and pushed** as one fast-forward commit on top of `e7676fa`. Still uncommitted,
  unchanged, and deliberate: the `PlayerHost.swift` hook, the five harnesses, and the owner's
  `icon pixel/` and `Notes/` (D063).

### Pass 7b — the evidence log decided, and six stale lines corrected (`reports/2026-09-19-pass7b-notebook.md`)

**Pass 7b (2026-09-19): notebook only.** Decision D067; report
`reports/2026-09-19-pass7b-notebook.md`. No Swift, project, asset, design, recipe or harness file
was touched; nothing was built, installed or launched; neither Apple TV and nothing under
`~/vlckit-build` was touched.
- **The evidence log stays on in the everyday app (D067)** — the owner's call on the one item pass 7
  left open. It carries pass 7's measurements, and that a whole film's worth was never measured.
  **Open items now holds three entries, all parked.**
- **The six lines pass 7 listed as out of date are corrected**, each to what its decision says: the
  bedroom Apple TV's installs (D061), the fonts (D059), the pass 2g evidence copies (D066), frame
  17's "Browse cached" button (D059), the video detail screen (D052) and `Theme.swift`'s header
  comment (D065). The listing itself is gone from Current state.
- **Committed and pushed** as one fast-forward commit on top of `f4fafa1` (pass 7). Still
  uncommitted, unchanged, and deliberate: the `PlayerHost.swift` hook, the five harnesses, and the
  owner's `icon pixel/` and `Notes/` (D063).

### Pass 7c — COLD-START read in full against D052–D067 (`reports/2026-09-19-pass7c-notebook.md`)

**Pass 7c (2026-09-19): notebook only.** No decision; `DECISIONS.md` was not edited. Report
`reports/2026-09-19-pass7c-notebook.md`. No Swift, project, asset, design, recipe or harness file
was touched; nothing was built, installed or launched; neither Apple TV and nothing under
`~/vlckit-build` was touched.
- **The two lines pass 7b reported are corrected:** patch 0021's text lives in history at `e7676fa`
  (D066), and "Building for the other Apple TV" states D061's rule in place of "only when the owner
  asks".
- **This file was then read in full, top to bottom, against D052–D067, one decision at a time.**
  One further line contradicted a decision and is corrected: `PlayerScreen.swift`'s "the paused
  clock (D045)" now says the clock shows whenever the film is not playing (D054). For the other
  fifteen decisions no contradicting line is left. Pass history notes were read and, as records,
  not edited.
- **The pass 7b report's two line-number citations are corrected** to the file as pass 7b committed
  it: lines 121–122 and 174–175.
- **Committed and pushed** as one fast-forward commit on top of `d813054` (pass 7b). Still
  uncommitted, unchanged, and deliberate: the `PlayerHost.swift` hook, the five harnesses, and the
  owner's `icon pixel/` and `Notes/` (D063).

### Pass 7d — the two "superseded" notes in DECISIONS.md (`reports/2026-09-19-pass7d-notebook.md`)

**Pass 7d (2026-09-19): notebook only.** No new decision. Report
`reports/2026-09-19-pass7d-notebook.md`. No file outside `DECISIONS.md`, this file and the report
was written; nothing was built, installed or launched; neither Apple TV and nothing under
`~/vlckit-build` was touched.
- **`DECISIONS.md` gained the two notes its own rule calls for** ("a superseded decision stays in
  place with a note"), in the style D008 carries, and no other line of it changed. **D045**'s
  "while paused, and only while paused" is marked superseded in part by D054 (pass 7): the clock
  shows whenever the film is not playing, scrub and buffering included. **D064**'s item "10 OPEN" is
  marked closed by D067 (pass 7b): the evidence log stays on. The original wording of both stays.
- **Committed and pushed** as one fast-forward commit on top of `ee3613b` (pass 7c). Still
  uncommitted, unchanged, and deliberate: the `PlayerHost.swift` hook, the five harnesses, and the
  owner's `icon pixel/` and `Notes/` (D063).

### 2026-10-04 — the owner takes over, and Marlin Media becomes five apps (no report file)

- **How the work is run changed (D068).** The owner dropped the foreman and directs the work in
  the chat. `CLAUDE.md` and `.claude/commands/wrap.md` were written from the owner's text and
  pushed as `acd2b29`. Neither notebook file said a foreman ran the work, so no line needed
  correcting; the two mentions in `reports/2026-09-15-pass2-recon.md` are history and stay. The
  owner's own rules file for all projects, outside this repo, was trimmed of pass and pasted-brief
  wording the same evening.
- **The brief.** "I want the Apple TV app split the same way I just split the PC box app": five
  apps, one per kind, on the one server (0.10.0, no server change). A look-only pass read this app,
  the PC box's notes and code as the feature list (marlin1111ai/marlin-tv-box: its D54–D58 and
  `api.py`, `app.py`, `music.py` — no code copied), the server's COLD-START and its pass-8 report,
  and the live server's shapes. The owner then answered four decisions and a fifth that the
  answers raised (D070–D072), and chose one build and one test (D074).
- **What was built (`c065545`).** Five app targets on the one source folder, each told its kind by
  `MARLIN_APP`. The first screen is the app's own library; the combined Home screen and
  `HomeScreen.swift` are gone; Marlin TV Shows has Up next; Marlin Music is new (`MusicModels.swift`,
  `MusicPlayer.swift`, `MusicScreens.swift`); Marlin Adult is the Movies screens on the adult
  routes, with the client refusing routes across that line and its log kept to ids. The five icon
  and Top Shelf sets were drawn by re-lettering the old ones (D072). All five built clean; the only
  compiler warnings are the three that were there before (two in `PlayerModel.swift`, one in a
  VLCKit header).
- **Checked on Home Theater, the four apps installed there**, with a throwaway harness that
  launched each by its bundle id. Home Theater was in use when the build finished, so nothing was
  launched until the owner said the television was free.
  - **Marlin Movies:** no tab bar, the header's word, Continue Watching (Wonder Woman) with the
    launch focus on its card, "All movies · 3". Stargate played from its page to 16.6 s.
  - **Marlin TV Shows:** Continue Watching (The Magicians S1 E10) and an Up next row of six in
    D040's order — The Magicians S1 E1, Stargate Atlantis S1 E1, Stargate SG-1 S1 E1, The Magicians
    S1 E2, Stargate Atlantis S1 E3, Stargate SG-1 S1 E3. The library holds no S1 E2 of either
    Stargate show, and The Food That Built America has nothing after its last finished episode. An
    Up next card played its episode.
  - **Marlin Videos:** the list of three, a video's page, a video playing.
  - **Marlin Music:** the Albums grid (11) and the Artists tab (4); an album page; a track started
    the album from there and opened Now Playing; Pause and Play; Previous after 3 s went to the
    track's start; Menu left the music playing and the album page marked the playing track;
    Play/Pause on the remote paused and resumed it from the album page; the last track ran out at
    86.7 s, the log said "the album has ended" and Now Playing was gone; the APE album played
    (VLC's `avcodec` decoder, "codec (ape) started") and Next moved to its second track; leaving
    the app logged the scene going to the background and the music stopping.
  - **The icons and a Top Shelf banner** were seen on the Home Screen with their own words.
  - **Nothing was written to the server:** every film played had no saved position and stayed
    under the 120 s floor, no log held a `PUT`, and afterwards the in-progress list and the played
    files' playback blocks were as before.
- **Two faults the check found, both fixed and checked again on the device.** The album page's
  track list ran under the clock when it scrolled (`49559fa`: the list stops short of it). And in
  every library the row above slid up over the header when focus moved down — the old app's tabs
  did the same; the owner chose to have it fixed (`bd708fa`, D075).
- **The owner's test:** "all work" for the four on Home Theater.
- **Marlin Adult (D071).** The server had no adult title when the apps were built and one by the
  time of the check. First, on the Mac, the app's own `Models.swift` read the live title (studio,
  date, two performers, poster, backdrop, the adult stream route) with nothing but counts printed.
  Then the app went onto Home Theater at 21:05 with the owner's word: the library loaded with one
  title under "All titles" and the header's "Adult"; the title's page showed a date and a length
  and neither a runtime nor a TMDB rating; it played to 13.1 s on `/api/adult/stream/…` and Menu
  came back. No screenshot was taken. Its log held no title, studio, performer or file name (each
  searched for, the hits counted: none but the word "adult" in the stream's own address), three
  "(withheld)" marks, no VLCKit line and no `PUT`; the title's playback block was untouched. The
  app was then removed from Home Theater and installed, unopened, on the bedroom box, where the
  owner tested it: "1 works". Saving a position, Resume and its Continue Watching row were the
  owner's to try, not the check's.
- **After the acceptance.** The other four were installed on the bedroom box (install only), the
  old Marlin Media TV app was removed from both boxes, its icon set and its two test scripts were
  taken out of the project (`015ed7f`, D070), all five still built, and `acd2b29..015ed7f` was
  pushed.
- **At wrap-up** the owner had the five old uncommitted harnesses and the `PlayerHost.swift` hook
  deleted (D076); all five apps built without the hook, and so did Marlin Movies with no UI-test
  folder at all, as a fresh clone has it.
- **The check's screenshots, logs and scripts were session scratch** and were deleted when each
  check was done, with the test runner app the checks left on Home Theater; what they showed is
  written here.
