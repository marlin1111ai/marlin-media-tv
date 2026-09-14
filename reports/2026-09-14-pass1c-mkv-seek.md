# Pass 1c: trusted MKV cues on seek — 2026-09-14

## Result

**Done and proven on Home Theater.** One media option — `:demux=mkv_trusted`, added to `.mkv` streams only — makes every forward seek in the four MKVs land on the file's cue point just before the target. Ten +30 s presses now bring the picture back **0.09–0.55 s** after the last press on every MKV, in both the paced and the rapid variant (yesterday: 8–51 s), each press resumes on its own before the next one arrives, one exact HTTP Range request is made per seek and none is repeated, the audio output starts once after the seek and logs no anomaly, and the overlay clock advances 59 s per 59-s interval afterwards in all ten runs. Nothing regressed against yesterday's from-start runs: Wonder Woman's steady 3.6 drops/s is unchanged, Stargate's deinterlace hiccups are unchanged, the MP4 is untouched (it never took the option). The one item that looks different — a 20-frame drop burst at the end of both Stargate Theatrical runs — is the same interlaced section yesterday's runs were cut off in; §5 has the evidence. Item 4's stop conditions were not met. Frame step on Stargate while paused: forward unchanged; the back step now lands on the previous cue instead of the file start (§3).

## 1. The change (item 1)

| File | Line | Change |
|---|---|---|
| `Marlin Media TV/PlayerModel.swift` | 144-149 (`attach(drawable:)`; the `if` is lines 147-149) | after `VLCMedia(url:)` succeeds: `if request.file.path.lowercased().hasSuffix(".mkv") { media.addOption(":demux=mkv_trusted") }` with a four-line comment naming D014. Nothing else. |

Why this option (from `reports/2026-09-14-diag2-seek.md` §4.1): the default `mkv` demux module opens with `trust_cues = false` (`mkv.cpp:280-284`), so every cue point is filed as *questionable* and, because the HTTP access reports "not fast-seekable" (`modules/access/http/access.c:79-80`), the pass that would verify them never runs; a seek then walks back to the last keyframe already read. The capability-0 submodule `mkv_trusted` (`mkv.cpp:286-290`, shortcut `mkv_trusted`) is the same demuxer with `trust_cues = true`. VLCKit's `addOption:` hands the string to `libvlc_media_add_option` (`Sources/Media/VLCMedia.m:314-317`), which adds it as a trusted, unique option; libvlc strips the leading colon (`src/misc/variables.c:920-921`). "Applied only to MKV": decided from the file path the server reports (`request.file.path`, e.g. `Movies/Wonder Woman/Wonder Woman (2017).mkv`), which is what the player already logs; the `.mp4` episode does not get the option (its log still reads `looking for demux module matching "any"`). The demuxer is forced by name, so a non-Matroska file with an `.mkv` name would fail to open — none exists in the library; question 2 in §6.

Proof in every MKV log of this pass, e.g. `reports/logs/1c-seek-divergent-A.log` lines 16, 57-58: `gives access 'http' demux 'mkv_trusted'`, `creating demux "mkv_trusted"`, `looking for demux module matching "mkv_trusted": 1 candidates` (yesterday: `matching "any": 58 candidates`). The `using demux module "mkv"` line that follows is the submodule reporting its plugin's name. The literal is in the built app (`Marlin Media TV.debug.dylib`, where Xcode 26 puts the Swift code: `grep -c mkv_trusted` → 1; the 92 KB main executable is a stub).

## 2. Before / after (item 2)

Build: `xcodebuild build-for-testing … -destination 'platform=tvOS,name=Home Theater'` → `TEST BUILD SUCCEEDED`, app product rebuilt 09:41:32 (was 2026-09-13 23:22:39); installed with `xcrun devicectl device install app` (`App installed: bundleID com.marlin1111.marlin-media-tv`). Harness: yesterday's `DiagSeekUITests` re-created from the diag2 appendix (plus the item-3 test), run 09:41:54 → 10:37:46 on Home Theater, logs copied after each run. Same ten runs as diag2: 20 s play, ten +30 s presses (A: 1.2 s apart; B: all within 2.0 s), four minute-marks. "diag2" numbers are yesterday's from `reports/2026-09-14-diag2-seek.md`; "1c" are today's.

### 2.1 Picture back after the last press, preroll of the last seek, HTTP

| Run | Last press → picture (diag2 → 1c) | Preroll of the 10th seek (diag2 → 1c) | Presses that resumed before the next press (diag2 → 1c) | HTTP requests during the ten presses (diag2 → 1c) | Repeated range (diag2 → 1c) | Requests after resume |
|---|---|---|---|---|---|---|
| Divergent A | 10.1 s → **0.53 s** | 145.2 s → 5.91 s | 0 → 9 | 4 → 9 | none → none | 0 → 0 |
| Divergent B | 20.2 s → **0.55 s** | 275.9 s → 5.89 s | 0 → 2 | 2 → 11 | none → none | 0 → 0 |
| Stargate Ext A | 8.5 s → **0.16 s** | 330.7 s → 0.16 s | 0 → 9 | 10 → 8 | `5816-` ×10 → none | 0 → 0 |
| Stargate Ext B | 8.1 s → **0.15 s** | 330.7 s → 0.15 s | 0 → 8 | 3 → 9 | `5816-` ×3 → none | 0 → 0 |
| Stargate Thea A | 10.7 s → **0.21 s** | 330.6 s → 0.22 s | 0 → 9 | 9 → 7 | `5816-` ×9 → none | 0 → 0 |
| Stargate Thea B | 8.3 s → **0.09 s** | 330.7 s → 0.20 s | 0 → 7 | 3 → 9 | `5816-` ×3 → none | 0 → 0 |
| Wonder Woman A | 43.0 s → **0.45 s** | 223.6 s → 0.94 s | 0 → 9 | 4 → 10 | none → none | 0 → 0 |
| Wonder Woman B | 51.1 s → **0.36 s** | 288.5 s → 0.94 s | 0 → 0 | 2 → 10 | none → none | 0 → 0 |
| Magicians MP4 A (no option) | 0.18 s → 0.19 s | 0.32 s → 0.32 s | 9 → 9 | 10 → 10 | none → none | 0 → 0 |
| Magicians MP4 B (no option) | 0.11 s → 0.21 s | 0.24 s → 0.27 s | 6 → 6 | 10 → 10 | none → none | 0 → 0 |

Preroll per seek today (from the demuxer's `seek: preroll{ req, start-pts }` lines): Divergent 5.89 / 5.86 / 0.12 / 5.63 / 1.10 / 0.65 / 5.25 / 6.18 / 0.35 / 5.91 s (the file's cue gaps, median 2.75 s); Stargate Extended 0.03–0.50 s and Theatrical 0.22–0.49 s (cues every 0.5 s); Wonder Woman 0.07–1.14 s (cues every ~1 s). Yesterday the same seeks started 31–146 s (Divergent), 224–289 s (Wonder Woman) and the whole 60–331 s (Stargate) behind their targets. Every HTTP request today is at a cue's byte offset (e.g. Wonder Woman A: `120198951-`, `250650711-`, … `1526730057-`); "8 or 9 of 10" means the odd seek's cue was already inside the 16 MiB read-ahead window. Divergent B's 11th is one extra read next to the first cue (`44082590-` after `43978329-`).

### 2.2 Audio, drops, clock after the seek

| Run | Audio-output starts after the last press (diag2 → 1c) | Audio anomalies (both) | Dropped / shown late after resume (diag2 → 1c) | Overlay clock min 1 → 4 (1c) | Δ per minute |
|---|---|---|---|---|---|
| Divergent A | `started` ×1 → ×1 | none | 0 / 1 → 1 / 0 | 06:29 · 07:28 · 08:27 · 09:26 | 59 s |
| Divergent B | ×1 → ×2 | none | 1 / 0 → 0 / 1 | 06:28 · 07:27 · 08:26 · 09:25 | 59 s |
| Stargate Ext A | ×1 → ×1 | none | 0 / 9 → 0 / 11 | 06:30 · 07:29 · 08:28 · 09:26 | 58–59 s |
| Stargate Ext B | ×1 → ×1 | none | 0 / 9 → 0 / 10 | 06:29 · 07:28 · 08:27 · 09:25 | 58–59 s |
| Stargate Thea A | ×1 → ×1 | none | 2 / 8 → 20 / 19 (§5) | 06:30 · 07:29 · 08:28 · 09:27 | 59 s |
| Stargate Thea B | ×1 → ×1 | none | 4 / 9 → 20 / 18 (§5) | 06:29 · 07:28 · 08:27 · 09:26 | 59 s |
| Wonder Woman A | `starting late` ×1 → `starting late` ×1 | none | 708 / 2 (3.6/s) → 873 / 0 (3.66/s over 238 s) | 06:30 · 07:29 · 08:28 · 09:27 | 59 s |
| Wonder Woman B | `starting late` ×1 → `starting late` ×1 | none | 674 / 0 (3.6/s) → 869 / 0 (3.66/s over 237 s) | 06:29 · 07:28 · 08:27 · 09:26 | 59 s |
| Magicians A | ×1 → ×1 | none | 0 / 0 → 0 / 0 | 06:30 · 07:29 · 08:28 · 09:27 | 59 s |
| Magicians B | ×1 → ×1 | none | 0 / 0 → 0 / 0 | 06:29 · 07:28 · 08:27 · 09:26 | 59 s |

Audio: in every run the audio ES stayed selected through the seeks (no `track selected` line between Play and dismiss), the decoder was not restarted, and after the last press the Apple audio output logged exactly one start and none of `underrun`, `flushedAutomatically`, `outputConfigurationChanged`, `AVQueuedSampleBufferRenderingStatusFailed`, `discontinuity: flushing output`, `resetting master clock`, `clock gap` (grep of each whole session). Audible output could not be checked from the harness (same limit as both diagnoses). The "after-skips" screenshot (taken ~1 s after the last press) shows 05:31/05:32 with the picture already playing on every MKV today; yesterday it showed the pending target over a frozen picture. Pre-seek shots read 00:25 in all ten runs. Every minute value is within 3 s of "target + wall time since resume" and the four values step by 59 s (one 58 s step from rounding). Cross-check from the app's dismiss lines: Wonder Woman A `dismiss at 568537 ms` after 281.3 s wall = 330.6 + 238.3 = 568.9 s expected.

Wonder Woman's drops before the first press (84 in the first 31 s, both runs) and after the seek (3.66/s) equal yesterday's from-start rate (1 774 in 496 s = 3.58/s; diag2 post-seek 3.6/s): the option changed the seek and nothing about that file's steady picture drops, which `reports/2026-09-14-diag-mkv-stutter.md` attributes to the 2160p HEVC decode/display path.

## 3. Frame step on Stargate while paused (item 3)

Run `frameStep_StargateExtended` (Appendix A), 10:36:40 → 10:37:40 EDT: Stargate Extended from the start, Select at 24.0 s to pause, then five Right clicks (native `gotoNextFrame`, D008) and five Left clicks (a seek of one frame duration back, D008), 2 s apart, screenshots after each; log `reports/logs/1c-framestep-stargate-extended.log`, frames `reports/screenshots/1c-framestep-*.jpg`.

**Forward — unchanged.** Five native steps, one `nextFrameStepped result=0` callback each, no buffering, no HTTP request, positions from the app's lines (VLC's MPEG-2 time is coarse, as in pass 1):

```
10:37:07.696 [player] pause (select) at 24000 ms          → state Paused at 24134 ms
10:37:10.259 [framestep] +1 gotoNextFrame before=24134 ms → nextFrameStepped time=24241 ms
10:37:12.819 [framestep] +1 gotoNextFrame before=24241 ms → after(400 ms)=24274 ms
10:37:15.373 [framestep] +1 gotoNextFrame before=24274 ms → nextFrameStepped time=24324 ms
10:37:17.937 [framestep] +1 gotoNextFrame before=24324 ms → nextFrameStepped time=24358 ms
10:37:20.495 [framestep] +1 gotoNextFrame before=24358 ms → nextFrameStepped time=24408 ms
```

The paused picture and all five forward frames are the black gap between two title cards (`1c-framestep-paused.jpg` … `1c-framestep-forward-5.jpg`), consistent with 24.1–24.4 s of the opening credits.

**Back — what it does now.** Each Left click seeks to `before − 33 ms` (targets 24375, 24342, 24309, 24276, 24243 ms). With trusted cues the demuxer now starts each of these at the cue just before the target — `seek: preroll{ req: 24375001, start-pts: 24107001, start-fpos: 12311112 }` (24.107 s, preroll ≤ 0.27 s) — with one HTTP request per step at that byte (`Range: bytes=12311112-` ×5). In pass 1 the same step went back to the file start (`Range: bytes=5816-`, `[ERR] reading while paused (buggy demux?)`) and prerolled ~20 s; today `reading while paused` appears once (first step) and the preroll is a fraction of a second. **What has not changed:** after the seek, while paused, VLC runs the rebuffer loop the pass-1 report described — `ES_OUT_RESET_PCR called` → `Received first picture` → `Stream buffering done (1302 ms in 72 ms)` → `[ERR] ES_OUT_SET_(GROUP_)PCR is called N ms late (pts_delay increased to 1000 ms)` → again, one iteration every ~22 ms, and the app receives a `nextFrameStepped` callback per iteration:

| Back step | target | iterations until the next input (`nextFrameStepped` / `buffering 1.0` / `RESET_PCR`) | duration | HTTP |
|---|---|---|---|---|
| 1 | 24375 ms | 111 / 113 / 114 | +0.14 s … +2.60 s after the click (next click at +2.62 s) | 1 (`12311112-`) |
| 2 | 24342 ms | 109 / 108 / 109 | +0.31 … +2.60 s | 1 |
| 3 | 24309 ms | 105 / 109 / 110 | +0.33 … +2.58 s | 1 |
| 4 | 24276 ms | 106 / 105 / 106 | +0.27 … +2.59 s | 1 |
| 5 | 24243 ms | 237 / 240 / 241 | +0.26 … +6.02 s, until the Menu press at +6.05 s | 1 |

The loop ends only with the next input (the next click, or Menu); it does not re-request HTTP (one request per step, then the read-ahead serves it) and it does not move the reported position (each `−1 after=` equals its target; `dismiss at 24243 ms, state Paused`). The 22 000-line log is this loop (14 913 `Buffering N%` lines, 680 `RESET_PCR`). The picture: after back step 1 the screen shows the "Director of Photography" title card (`1c-framestep-back-1.jpg`) instead of the black frame 33 ms before the paused one; after step 5 the same card (`…-back-5.jpg`); three seconds later, still paused at the same reported position, a desert scene from much later in the film (`…-framestep-end.jpg`) — the loop keeps decoding forward and showing "first pictures" while the clock stays at 00:24. This is the pass-1 finding ("shows a later frame and puts this VLC alpha into a rebuffer loop over HTTP", open question 2) with a different, nearer starting point; D014 neither caused nor fixed it. It is not exercised by the +30 s skips while playing (§2), and it is question 1 in §6.

## 4. Files touched, by step

| Step | Files |
|---|---|
| 1 | `Marlin Media TV/PlayerModel.swift` (one `if` + comment, `attach(drawable:)`) |
| 2 | none in the repo; temporary `Marlin Media TVUITests/DiagSeekUITests.swift` (built, run, deleted; Appendix A); evidence added: `reports/logs/1c-seek-*.log` (10), `reports/logs/1c-framestep-stargate-extended.log`, `reports/screenshots/1c-seek-*-strip.jpg` (60), `reports/screenshots/1c-framestep-*.jpg` |
| 3 | the same temporary harness (test `frameStep_StargateExtended`) |
| 5 | `DECISIONS.md` (D014), `COLD-START.md` (current state), this report |

Nothing installed on the Mac; VLCKit not rebuilt; project file untouched; deployment target still 26.0 (`TVOS_DEPLOYMENT_TARGET = 26.0`); server address unchanged. Committed locally, not pushed.

## 5. Least-sure items

1. **Stargate Theatrical's 20 dropped frames after the seek (both runs).** They are one burst at the very end of the run: after the 4th deinterlace insertion (`deinterlace -1, mode auto, is_needed 1`, no later `Detected progressive video`) the log repeats `picture displayed late (~14 ms)`, `too late (~83 ms)`, `too late (~51 ms)` ten times (≈30 frames ≈ 1 s at 29.97 fps) and then the Menu press. Yesterday's diag2 Theatrical A and B logs end with the *same* pattern beginning — `late 15, DROP 83, DROP 50, late 12` (2 drops, dismiss at 557.4 s) and `late 13, DROP 79, DROP 47, late 13, DROP 82, DROP 49` (4 drops, dismiss at 558.6 s). Today's runs resumed 8–10 s sooner and therefore played to 567.0–567.8 s, i.e. 10 s further into that interlaced section, before the harness pressed Menu. The from-start run (0–495 s) never reaches it; the 1c Extended runs (a different cut) show 0 drops. So: same content, same software deinterlacer, seen longer because the seek is faster; not the option. It would be settled by playing Theatrical from 9:10 for a minute with and without the option — not done (item 4 says no second experiment).
2. **The MKV decision is by file extension** (`.mkv` at the end of the server's path). The library has no other Matroska extension (`.mka`, `.mks`, `.webm`) and no MKV under another name; if one appears, it would take the default path (and a non-Matroska file named `.mkv` would fail to open, since the demuxer is forced by name).
3. **The "1 candidates" line is the only direct proof the submodule was chosen**; the behaviour (seeks landing on cues, `matching "mkv_trusted"`) is the corroboration. `using demux module "mkv"` is printed either way.
4. **Divergent's worst-case preroll is its cue spacing** (max 10.0 s in its Cues; 6.2 s seen today): a seek that lands just after a sparse stretch could take up to ~1 s of 4K decode to show a picture. All ten today were under 0.6 s.

## 6. Open questions

1. Frame back on Stargate now lands on the previous cue and prerolls to the target (§3). D008 records the back step as "approximate"; do you want it left as is, or should a later pass try VLCKit's native `gotoPreviousFrame` (pass-1 report, open question 2)? Not touched here.
2. Should the MKV decision use the server's `Content-Type: video/x-matroska` (a HEAD request before play) instead of the path suffix? That is an extra request and a code path, so not built; the suffix is what the app already has.
3. The Stargate Theatrical deinterlace burst (§5.1): worth a short from-9:10 check in a later pass, or leave with the SD/MPEG-2 hiccups already noted yesterday?

## 7. Method

1. Harness: Appendix A (yesterday's ten tests verbatim plus `frameStep_StargateExtended`), built with `xcodebuild build-for-testing -project "Marlin Media TV.xcodeproj" -scheme "Marlin Media TV" -destination 'platform=tvOS,name=Home Theater' -derivedDataPath build/DerivedData -allowProvisioningUpdates` (TEST BUILD SUCCEEDED; this also rebuilt the app product with the change), installed with `xcrun devicectl device install app --device <id> "build/DerivedData/Build/Products/Debug-appletvos/Marlin Media TV.app"`.
2. Eleven runs via `xcodebuild test-without-building … -only-testing:"Marlin Media TVUITests/DiagSeekUITests/<test>" -resultBundlePath <n>.xcresult`; screenshots via `xcrun xcresulttool export attachments`; the log via `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier com.marlin1111.marlin-media-tv --source Library/Caches/marlin-media-tv.log`; each analysed segment is everything after the last `[player] play() called`.
3. Numbers: "last press → picture" = the app's stamped `[player] buffering 1.0` after the last `[skip] +30 s` line; preroll = `req − start-pts` from the demuxer's `seek: preroll{ … }` line (MKV) or `seeking with Nms preroll` (MP4); requests = `outgoing request:` blocks with their `Range:`; drops = `grep -c 'too late to be displayed'` between resume and `[player] dismiss`; audio = `started` / `starting late` lines after the last press and a grep for the anomaly strings listed in §2.2; clock = the overlay strips (`reports/screenshots/1c-*-strip.jpg`, y 1560–2080 of the 3840×2160 capture, halved).
4. The diag2 column is copied from `reports/2026-09-14-diag2-seek.md` §1.1–1.2; both days' logs are in `reports/logs/` (`diag2-*` and `1c-*`).

## Appendix A — the temporary harness (deleted after the runs; not committed)

```swift
//
//  DiagSeekUITests.swift — temporary harness, re-created from reports/2026-09-14-diag2-seek.md Appendix A for pass 1c
//  (same ten seek runs) plus the frame-step test for item 3.
//  Plays a file for 20 s, presses the +30 s skip (right click while playing) ten times — variant A at a
//  user's pace (~1.5 s apart), variant B as fast as XCUIRemote can send them (the nearest available stand-in
//  for one long jump: the app has no scrub) — then photographs the overlay each minute for four minutes.
//  Not a standing test; not committed.
//

import XCTest

final class DiagSeekUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func note(_ t: String) { let a = XCTAttachment(string: t); a.name = "note"; a.lifetime = .keepAlways; add(a); NSLog("[diag2] %@", t) }
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

    private func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date())
    }

    /// 20 s from the start, then ten +30 s skips (right click while playing), then four minute-marks.
    /// `.down` is the app's "focus back on the surface" press (a no-op when focus is already there), so a
    /// `.right` afterwards is a skip and not a move between the overlay buttons.
    private func seekRun(_ tag: String, rapid: Bool) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(stamp())")
        sleep(20)
        press(.down, wait: 1)
        press(.up, wait: 1); shot("seek-\(tag)-pre"); press(.down, wait: 1)
        sleep(4)
        note("\(tag): ten +30 s skips (\(rapid ? "rapid" : "paced")) begin at \(stamp())")
        for _ in 0..<10 { remote.press(.right); if !rapid { sleep(1) } }
        note("\(tag): skips end at \(stamp())")
        sleep(1); shot("seek-\(tag)-after-skips")
        note("\(tag): after-skips shot at \(stamp()), player exists \(app.otherElements["player"].exists)")
        for m in 1...4 {
            sleep(56)
            press(.up, wait: 1)
            shot("seek-\(tag)-min\(m)")
            note("\(tag): minute \(m) shot at \(stamp()), player exists \(app.otherElements["player"].exists)")
            press(.down, wait: 1)
            if !app.otherElements["player"].exists { note("\(tag): player gone at minute \(m)"); break }
        }
        press(.menu, wait: 3)
    }

    private func openStargate(_ edition: String, dir: XCUIRemote.Button) {
        openPoster("poster.Stargate", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.buttons["pick.\(edition)"].waitForExistence(timeout: 5)); moveUntilFocused("pick.\(edition)", pressing: dir, limit: 3); press(.select, wait: 2)
    }
    private func openMagicians() {
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30)); sleep(2)
        moveUntilFocused("episode.1.1", pressing: .down, limit: 4); press(.select, wait: 2)
    }

    func seekA_Divergent() { openPoster("poster.Divergent", tab: "Movies"); pressPlay(); seekRun("divergent-A", rapid: false) }
    func seekB_Divergent() { openPoster("poster.Divergent", tab: "Movies"); pressPlay(); seekRun("divergent-B", rapid: true) }
    func seekA_StargateExtended() { openStargate("Extended", dir: .up); seekRun("stargate-extended-A", rapid: false) }
    func seekB_StargateExtended() { openStargate("Extended", dir: .up); seekRun("stargate-extended-B", rapid: true) }
    func seekA_StargateTheatrical() { openStargate("Theatrical", dir: .down); seekRun("stargate-theatrical-A", rapid: false) }
    func seekB_StargateTheatrical() { openStargate("Theatrical", dir: .down); seekRun("stargate-theatrical-B", rapid: true) }
    func seekA_WonderWoman() { openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); seekRun("wonder-woman-A", rapid: false) }
    func seekB_WonderWoman() { openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); seekRun("wonder-woman-B", rapid: true) }
    func seekA_MagiciansE1() { openMagicians(); seekRun("magicians-s01e01-A", rapid: false) }
    func seekB_MagiciansE1() { openMagicians(); seekRun("magicians-s01e01-B", rapid: true) }

    // MARK: pass 1c item 3 — frame step on Stargate Extended while paused, five clicks each way
    func frameStep_StargateExtended() {
        openStargate("Extended", dir: .up)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("framestep: player up at \(stamp())")
        sleep(20)
        press(.down, wait: 1)
        press(.select, wait: 2)                       // pause (select on the surface toggles play/pause)
        shot("framestep-paused")
        note("framestep: paused at \(stamp())")
        for i in 1...5 { press(.right, wait: 2); shot("framestep-forward-\(i)"); note("framestep: forward \(i) at \(stamp())") }
        for i in 1...5 { press(.left, wait: 2); shot("framestep-back-\(i)"); note("framestep: back \(i) at \(stamp())") }
        sleep(3); shot("framestep-end")
        press(.menu, wait: 3)
    }
}
```
