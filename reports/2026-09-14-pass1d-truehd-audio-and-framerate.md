# Pass 1d: TrueHD audio batching, frame-rate/dynamic-range matching, Menu-in-panel fix — 2026-09-14

## Result

| Item | Result |
|---|---|
| 1 TrueHD block coalescing | **Done, in VLCKit** (libvlc patch 0018 via the recipe). The TrueHD decoder's 40-sample frames now reach the tvOS renderer as 960-sample / 20 ms blocks: VLC's own counter shows **50 audio buffers per second** (3 003/min) instead of 1 200/s, and the output's per-block `deferring start` lines fall from 762 to 66. DTS, AC-3 and AAC are untouched (94/s, 31/s, 43/s — the same figures as diag3/diag1; no coalescing line on those runs; the change is gated on the codec id). No underrun / late / silence / drift line in any run. Audibility is the owner's check. |
| 2 Frame-rate / dynamic-range matching | **Done, in the app** (D016). The player asks `AVDisplayManager` for the stream's rate and range before `play()`; tvOS reported a mode switch (start → end, ~2.9 s) on Stargate (29.971 fps SDR), Magicians (29.970 fps SDR) and Wonder Woman (23.976 fps HDR10, both tracks: the screen went to **24 Hz**, `maximumFramesPerSecond` 60 → 24). Divergent got no request: VLC exposes no frame rate for that stream at all (§2, question 3). Two findings on the way: VLCKit's parser timeout is in microseconds (first attempt timed out in 5 ms), and VLC's Matroska parse may report no frame rate for an HEVC MKV, in which case the request is attempted from the player's own video track ~0.1 s after `play()`; Wonder Woman's parse did carry 23.976 in the final runs, Divergent's stream carries no rate anywhere VLC exposes, so it alone gets no request (§2). tvOS exposes no "current display mode" API: `UIScreen.maximumFramesPerSecond` stayed 60 through every switch; what is logged is the switch itself. |
| 3 Menu with a panel open | **Done** (`PlayerScreen.swift:35`, one line): on Home Theater the audio panel opened, Menu closed it (`[player] panel closed`, no dismiss) with playback continuing (00:18 → 00:23 in the next shots), and a second Menu exited to the detail screen — four screenshots, §3. |
| 4 Build, install | VLCKit rebuilt by the recipe in 3 min 10 s (incremental; contribs untouched), app built and installed on Home Theater three times (the two fixes above); the build installed last (13:34) is exactly the committed code (temporary statistics line removed, harness deleted). |
| 5 Device proof | Seven runs on Home Theater (§2–§4), logs and per-minute screenshots committed. |
| 6 Notebook | D015, D016, Menu defect closed; COLD-START updated. |

Nothing installed on the Mac; the framework stays out of git; deployment target 26.0; server unchanged. Committed locally, not pushed.

## 1. TrueHD block coalescing (item 1)

**Where and why.** The narrowest codec-specific point is the avcodec audio decoder module: the `mlp` packetizer must keep one access unit per block (FFmpeg decodes TrueHD one AU at a time), and the Apple output makes one `CMSampleBuffer` per block for every codec, so the decoder is where TrueHD/MLP frames can be gathered without touching anything else. VLCKit exposes no point in the app where audio blocks pass (the only app-side audio hook replaces the whole output), so the change is in VLCKit's libvlc source:

| File | Lines (patched tree) | Change |
|---|---|---|
| `modules/codec/avcodec/audio.c` | `decoder_sys_t` +4 fields (`b_coalesce`, `i_coalesce_target`, `i_coalesce_capacity`, `p_coalesce`) | state |
| same | `CoalesceAndQueue()` before `Flush()` (≈70 lines) | gathers frames into a block of ⌈rate/50 ÷ frame⌉ × frame samples (960 at 48 kHz = 24 AUs = 20 ms), PTS/flags from the first frame, length summed; a discontinuity flushes the pending block first; a frame ≥ the target passes through; one `msg_Dbg` when the target is first computed |
| same | `InitAudioDec` | `b_coalesce = (codec->id == AV_CODEC_ID_TRUEHD \|\| codec->id == AV_CODEC_ID_MLP)` — the only gate |
| same | `DecodeBlock` | `if (b_coalesce) CoalesceAndQueue(...) else decoder_QueueAudio(...)`; on drain (`pp_block == NULL`) the remainder is queued |
| same | `Flush`, `EndAudioDec` | drop / free the accumulator |
| `tools/vlckit-truehd/0018-avcodec-audio-coalesce-TrueHD-MLP-frames.patch` | 177 lines, `git format-patch` format | the change as VLCKit patch 0018 |
| `tools/vlckit-truehd/build.sh` | step 2b | copies patch 0018 into `VLCKit/libvlc/patches/` so VideoLAN's script applies it after the seventeen upstream patches (it resets libvlc to `TESTEDHASH` and re-applies `libvlc/patches/*.patch` on every run, `compileAndBuildVLCKit.sh:538-540`) |
| `tools/vlckit-truehd/README.md` | one paragraph | |

Build: `tools/vlckit-truehd/build.sh` → `build.log` lines 37-40 `Applying: … Applying: avcodec audio: coalesce TrueHD/MLP decoder frames into ~20 ms blocks`; `build start 12:47:01`, `build end 12:50:11`; `nm` still lists `_ff_mlp_decoder _ff_mlp_parser _ff_truehd_decoder`; the framework and the app bundle's copy both contain the new debug string (`strings … | grep -c 'coalescing %u-sample'` → 1). `Frameworks/VLCKit.xcframework` replaced (git-ignored, D013).

### Before / after at the renderer (Wonder Woman, TrueHD track, five minutes each)

| | diag3 (before, `reports/logs/d3-ww-truehd.log`) | pass 1d (`reports/logs/1d-ww-truehd-60hz.log`) |
|---|---|---|
| Decoder line | `codec (truehd) started`, `MLP channels: 8 samplerate: 48000` | same, then **`coalescing 40-sample decoder frames into 960-sample blocks (20 ms) before the audio output`** |
| Output format | `Output on HDMI, channel count: 8`, `format: 48000 rate, 8 nch, 4 bps, fl32` | identical |
| Blocks reaching the output before start (`deferring start` lines) | 762, 76–93 µs apart | **66** |
| Start line | `starting late (-45 us)` | `started` |
| Blocks played per minute (VLC `playedAudioBuffers`, temporary `[stats]` line) | not logged then; 1 200/s by construction (40 samples) | **3 053, 3 003, 3 003, 3 004, 2 999 = 50.0/s** (960 samples) |
| `lostAudioBuffers` per minute | — | 0, 0, 0, 0, 0 |
| `decodedAudio` = `playedAudio` | — | yes, every minute |
| Anomaly lines in five minutes (`underrun`, `too slow`, `late`, `silence`, `way too early`, `discarded audio`, `discontinuity`, `resampling`, `drift`, `flushedAutomatically`, `StatusFailed`, `outputConfigurationChanged`, `resetting master clock`) | none | **none** |

### The other codecs are untouched

| Track (run) | Packetizer / decoder lines | `coalescing` line | `deferring start` (diag3/diag1 → 1d) | `playedAudioBuffers` per minute → per second | Frame size implied | Anomalies |
|---|---|---|---|---|---|---|
| Wonder Woman AC-3 (`1d-ww-ac3-60hz.log`, switched at +14 s) | `a52` / `codec (ac3) started`, `A/52 channels:6 samplerate:48000 bitrate:448000`, `Output on HDMI, channel count: 6` | none | 44 → 44-equivalent (the switch path) | 1 876 / 1 875 / 1 884 / 1 871 → **31.3/s** | 1 536 samples (unchanged) | see the route note in §5 |
| Divergent DTS (`1d-divergent-dts.log`) | `dts` / `codec (dca) started`, `DTS samplerate:48000 bitrate:1536000`, 8 ch | none | 139 → **139** | 5 741 / 5 620 / 5 638 → **94/s** | 512 samples (unchanged) | none |
| Stargate Extended AC-3 (`1d-stargate-extended-ac3.log`) | `a52` / `codec (ac3) started`, 6 ch | none | 40 → **40** | 1 910 / 1 879 / 1 876 → **31.3/s** | 1 536 (unchanged) | none |
| Magicians AAC (`1d-magicians-aac.log`) | `codec (aac) started`, `Output on HDMI, channel count: 2`, `format: 44100 rate, 2 nch` | none | 55 → **55** | 2 634 / 2 589 / 2 580 → **43.1/s** | 1 024 samples at 44.1 kHz (unchanged) | none |

## 2. Frame-rate and dynamic-range matching (item 2)

**What the app does** (`Marlin Media TV/PlayerModel.swift`, all in `attach(drawable:)` and the `display matching (D016)` section): logs the display state; parses the stream with `VLCMediaParser` (5 s timeout, `parse` = libvlc's network parse); on completion builds a `CMVideoFormatDescription` for the stream (codec HEVC or H.264, the parsed width × height, and colour extensions — BT.2020 primaries / SMPTE ST 2084 PQ transfer / BT.2020 matrix when the server reports `hdr: true`, BT.709 for all three otherwise), wraps it with the frame rate in `AVDisplayCriteria(refreshRate:formatDescription:)` (the only initializer in the tvOS 26 SDK; `AVDisplayCriteria.h`, tvOS 17+), sets `UIWindow.avDisplayManager.preferredDisplayCriteria`, registers for `AVDisplayManagerModeSwitchStart/End/SettingsChanged`, logs again 4 s later, and starts playback. `dismiss()` sets the criteria back to `nil` and logs. The server reports resolution, HDR and codec but **no frame rate**; the rate comes from VLC.

**Two things found while doing it (both in the log, both fixed before the final runs):**
1. `VLCMediaParser(library:timeout:)` passes its integer straight into `libvlc_parser_cfg.timeout`, which is in **microseconds** (`include/vlc/libvlc_parser.h:373`, `lib/parser.c:422-433`). 5 000 meant 5 ms: `parse finished with status 4` (timeout) 11 ms after queuing on the first two runs. Fixed to 5 000 000.
2. With the parse working, the HEVC MKVs' parsed video track reports frame rate `0/0` — VLC's Matroska demuxer sets `i_frame_rate = 1000000, i_frame_rate_base = DefaultDuration in ns` (`modules/demux/mkv/matroska_segment_parse.cpp:512-513`), which the ES output reduces to nothing usable; the MPEG-2 MKV and the MP4 do carry a rate at parse. The player's own video track carries the rate the packetizer reads from the stream (SPS VUI; pass 1 logged `500000/16683` for Stargate), so when the parse gives none the request is made from that track at the first `mediaPlayerTrackAdded/Updated`, about 0.1 s after `play()` and before the first picture. That is the one deviation from "set before playback", and it only applies when the parse has no rate. In the final runs Wonder Woman's parse did carry 23.976 (request before `play()`); Divergent's stream carries no rate in either place, so it gets no request and plays as before.

### What tvOS reported, per run

| Run | Request | Set when | `mode switch start` → `end` | `UIScreen.maximumFramesPerSecond` before / during / after | `edrHeadroom` | Cleared at exit |
|---|---|---|---|---|---|---|
| Stargate Extended (MPEG-2 480i, SDR) | `refresh=29.971 range=SDR (BT.709) codec=MPEG-1/2 Video 720x480` | before `play()` (parse gave the rate) | 13:07:58.113 → 13:08:00.985 (2.87 s) | 60 / 60 / 60 | 1.00/1.00 | yes, `criteria=nil` |
| Magicians S1E1 (H.264 1080p, SDR) | `refresh=29.970 range=SDR (BT.709) codec=H264 - MPEG-4 AVC (part 10) 1920x1080` | before `play()` | 13:11:45.109 → 13:11:47.974 (2.87 s) | 60 / 60 / 60 | 1.00/1.00 | yes |
| Divergent (HEVC 4K HDR, DTS; `1d-divergent-dts.log`, `1d-divergent-dts-fallback.log`) | **none** — the parse reports `0/0` and the player's video track never reports a rate either (no `request (from player video track)` line in 190 s) | — | no switch | 60 / 60 / 60 | 1.00/1.00 | nothing to clear |
| Wonder Woman TrueHD (HEVC 4K HDR, `1d-ww-truehd-matched.log`) | `refresh=23.976 range=HDR10 (PQ, BT.2020) codec=MPEG-H Part2/HEVC (H.265) 3840x2160` | before `play()` (this parse carried the rate) | 13:16:50.640 → 13:16:53.537 (2.90 s) | 60 / 60 / **24** (24 at +4 s and still 24 at exit) | 1.00/1.00 | yes |
| Wonder Woman AC-3 (`1d-ww-ac3-matched.log`) | same request (the file's, before the track switch) | before `play()` | 13:22:58.602 → 13:23:01.497 (2.90 s) | 60 / 60 / **24** | 1.00/1.00 | yes |

Every run's `before` line read `matchingEnabled=true` (the owner's Match Frame Rate / Dynamic Range settings), `switchInProgress=false`, `gamut=1` (P3), `edrHeadroom=1.00/1.00`. tvOS gives no public "active display mode" (refresh rate, HDR) to read; `maximumFramesPerSecond` did not change across a switch tvOS itself reported, and `currentEDRHeadroom` stayed 1.00 (the HDR runs — Wonder Woman both tracks, Divergent — reported `edrHeadroom=1.00/1.00` before and after their switches as well, so EDR headroom is not the HDR indicator on this box either). The switch notifications are therefore the evidence that the panel was re-timed.

### Drop counters on Wonder Woman, 60 Hz vs matched

VLC's own counters (`lostPictures` = pictures the video output discarded as too late, `displayedPictures`, `latePictures` = shown late), per minute, five minutes per run, same build (coalescing in place); the only difference between the pairs is the display request.

| Minute | TrueHD at 60 Hz (`1d-ww-truehd-60hz.log`) lost / displayed | TrueHD matched 24 Hz (`1d-ww-truehd-matched.log`) | AC-3 at 60 Hz (`1d-ww-ac3-60hz.log`) | AC-3 matched 24 Hz (`1d-ww-ac3-matched.log`) |
|---|---|---|---|---|
| 1 | 144 / 1 288 | 145 / 1 287 | 144 / 1 285 | 144 / 1 286 |
| 2 | 220 / 1 220 | 221 / 1 224 | 220 / 1 220 | 220 / 1 220 |
| 3 | 235 / 1 205 | 235 / 1 205 | 236 / 1 204 | 236 / 1 204 |
| 4 | 227 / 1 214 | 227 / 1 214 | 227 / 1 218 | 227 / 1 218 |
| 5 | 232 / 1 207 | 232 / 1 211 | 240 / 1 193 | 231 / 1 207 |
| vout `too late` lines, whole run | 1 101 in 310 s (3.55/s) | 1 101 in 310 s (3.55/s) | 1 175 in 327 s (3.59/s) | 1 166 in 327 s (3.57/s) |
| `latePictures` | 1 | 0 | 2 | 0 |
| `decodedVideo` per minute | 1 438–1 441 (24.0 fps) | 1 438–1 445 | 1 432–1 442 | 1 433–1 442 |

The 24 Hz mode changes nothing about the drops: the same pictures are lost, minute for minute, on both tracks. The video output decides "too late" against its own clock before it hands a picture to the display layer (diag3 §B), so the panel's refresh rate is not in that decision. What the switch does change is how the *displayed* pictures reach the panel (one per refresh instead of 3:2 on 60 Hz), which only the owner's eyes can judge.

## 3. Menu with a panel open (item 3)

Cause (diag3): with a track panel showing, the Menu press reached SwiftUI's `.onExitCommand` on the player screen, which called `model.dismiss()`, before the UIKit host's `pressesBegan` (which routes Menu through `PlayerModel.handle(.menu)`: close the panel if one is open, else dismiss). Fix: `PlayerScreen.swift:35` now reads `.onExitCommand { model.handle(.menu) }` — the same routing on both paths; one line.

Device sequence (`r6_MenuInPanel`, Divergent, `reports/logs/1d-menu-in-panel.log`, screenshots `reports/screenshots/1d-menu-*.jpg`):

| Step | Log | Screenshot |
|---|---|---|
| Up, Up, Select at ~15 s | `13:15:50.321 [audio] panel opened: audio/2 English DTS 7.1 ✓` | `1d-menu-1-panel-open.jpg` — AUDIO panel, one track ticked, clock 00:15, Playing |
| **Menu** | `13:15:53.016 [player] panel closed` — no `dismiss` line | `1d-menu-2-after-first-menu.jpg` — panel gone, overlay with the Audio button highlighted, clock 00:18, Playing; harness: `player exists true, panel gone true` |
| 3 s later, Up | — | `1d-menu-3-still-playing.jpg` — clock 00:23, Playing |
| **Menu** again | `13:16:01.691 [player] dismiss at 23639 ms, state Playing` → `Stopping` → `Stopped` | `1d-menu-4-after-second-menu.jpg` — the Divergent detail screen; harness: `player exists false` |

Both XCTest assertions (player still present after the first Menu, gone after the second) passed. Before the fix the same first Menu produced `[player] dismiss` (diag3, `d3/attempt1`).

## 4. Files touched, by step

| Step | Files |
|---|---|
| 1 | `tools/vlckit-truehd/0018-avcodec-audio-coalesce-TrueHD-MLP-frames.patch` (new), `tools/vlckit-truehd/build.sh` (step 2b), `tools/vlckit-truehd/README.md`; `Frameworks/VLCKit.xcframework` rebuilt (not in git); the libvlc source in `~/vlckit-build` carries the commit the patch was exported from |
| 2 | `Marlin Media TV/PlayerModel.swift` (imports AVFoundation/AVKit/CoreMedia; `VLCMediaParserDelegate`; parse-before-play, `requestDisplayMode…`, `observeModeSwitches`, `clearDisplayRequest`, `displayState`) |
| 3 | `Marlin Media TV/PlayerScreen.swift` (one line) |
| 4 | none in the repo (build products) |
| 5 | temporary `Marlin Media TVUITests/Diag4UITests.swift` (deleted; Appendix A) and a temporary `[stats]` log task in `PlayerModel.swift` (removed before the commit; its text is in Appendix B); evidence: `reports/logs/1d-*.log`, `reports/screenshots/1d-*` |
| 6 | `DECISIONS.md` (D015, D016), `COLD-START.md`, this report |

## 5. Least-sure items

1. **Audibility.** The TrueHD change is proven at the renderer (block rate, no error lines), not by ear. If the track is still silent with 20 ms blocks, the shortlist's second item from diag3 (decoder output content) is next, and the coalescing stays useful anyway.
2. **The HDMI route flap in the AC-3 run** (`1d-ww-ac3-60hz.log`): between the minute-4 and minute-5 counters (13:01:38–13:02:38) the renderer was flushed by the system twice (`[WARN] flushedAutomatically` → `restart requested (3)` → `restarting output…`), the first restart opening `Output on Default, channel count: 6`, the second `Output on HDMI, channel count: 6` — the HDMI audio route went away and came back within that minute. Four minutes after the track switch, no display request active (that run predates the timeout fix), nothing done from the Mac at that time; `lostAudioBuffers` stayed 0 and the played-buffer count for the minute was 1 871 vs 1 875–1 884. Not seen in any other run today or in diag3. Cause unknown (AVR/TV HDMI handshake?) — noted, not chased.
3. **The 0.1 s deviation for HEVC MKVs** (§2): the request goes in after `play()` for those files. If a switch-before-first-picture matters, the alternative is to read the SPS timing from the container in the app (an extra HTTP range read) — a question, not built.
4. **`UIScreen.maximumFramesPerSecond` never changed** across switches tvOS reported; if the owner sees the TV stay at 60 Hz for the 23.976 files, the criteria may be accepted but not honoured for HEVC-with-PQ format descriptions — the log cannot distinguish that from a switch to 24 Hz. The TV's own info panel is the check.
5. The temporary `[stats]` line was removed after the runs; the committed app does not log counters.

## 6. Open questions

1. Is the TrueHD track audible now? If not, the next step is the diag3 shortlist's decoder-content check (a PCM capture via VLC's tracer or a sout — one media option each).
2. Does the TV report 24 Hz (and HDR) while Wonder Woman plays, and 30 Hz for the episodes? That confirms the switches tvOS logged are the right modes.
3. For HEVC MKVs the request lands ~0.1 s after play; acceptable, or should a later pass read the frame rate from the container before play?
4. The AC-3 route flap (§5.2): has the Denon or the TV shown an HDMI re-sync around 13:02 today?

## 7. Method

1. VLCKit: the change was made in the libvlc tree at `~/vlckit-build/VLCKit/libvlc/vlc` on the branch VideoLAN's script creates (`localBranch`, 5dd4aebda + 17 patches), committed there and exported with `git format-patch -1` to `tools/vlckit-truehd/0018-…patch`; `git apply --check` against the 17-patch base passed; then `tools/vlckit-truehd/build.sh` (which now installs patch 0018 and runs `compileAndBuildVLCKit.sh -v -f -t -r`; the script resets libvlc to the pinned hash and re-applies all 18 patches) — `~/vlckit-build/build.log` and `build-1d.out`.
2. App: `xcodebuild build-for-testing … -destination 'platform=tvOS,name=Home Theater'` (three builds today: the change set, the microsecond timeout fix, the frame-rate fallback), `xcrun devicectl device install app` for the first; `xcodebuild test-without-building` installs the current products for each run.
3. Runs: Appendix A. Batch 1 (12:51–13:16 EDT): r1 Wonder Woman TrueHD 5 min, r2 Wonder Woman AC-3 5 min (both with the 5 ms timeout build → no display request → the "60 Hz" figures), r3 Divergent 3 min (timeout fixed, no fallback yet → no request), r4 Stargate Extended 3 min, r5 Magicians 3 min, r6 Menu. Batch 2 (13:16–13:29): r1 and r2 again with the fallback build → the "matched" figures. Logs copied with `xcrun devicectl device copy from … Library/Caches/marlin-media-tv.log` after each run; the analysed segment starts at the run's `[player] request` line.
4. Numbers: the app's temporary `[stats]` line (VLC's `libvlc_media_player_get_stats` via `VLCMedia.statistics`, once a minute: displayed / late / lost pictures, decoded video/audio, played / lost audio buffers, demux bytes and bitrates) — per-minute deltas in the tables; audio block rate = played audio buffers per minute ÷ 60; `deferring start` lines counted per session; anomaly grep as in diag3.
5. Committed evidence: seven session logs (`reports/logs/1d-*.log`) and the overlay strip per minute plus the four Menu frames (`reports/screenshots/1d-*`).

## Appendix A — the temporary harness (deleted after the runs; not committed)

```swift
//
//  Diag4UITests.swift — temporary harness for pass 1d verification (2026-09-14). Built from the diag3 appendix
//  (same navigation helpers). Five playback runs with a screenshot per minute (the app now logs VLC's counters
//  itself, temporarily), plus the Menu-in-panel sequence. Not a standing test; not committed.
//

//  Diag3UITests.swift — temporary harness for the 2026-09-14 Wonder Woman diagnosis (diag3). Built from the
//  pass-1c appendix (same navigation helpers). Plays a title for five minutes and, once a minute, opens and
//  closes the subtitle panel (app log lines with timestamps, no playback change) as the per-minute anchor,
//  photographs the screen and records what the runner's own AVAudioSession sees of the output route.
//  Not a standing test; not committed.
//
//  DiagSeekUITests.swift — temporary harness, re-created from reports/2026-09-14-diag2-seek.md Appendix A for pass 1c
//  (same ten seek runs) plus the frame-step test for item 3.
//  Plays a file for 20 s, presses the +30 s skip (right click while playing) ten times — variant A at a
//  user's pace (~1.5 s apart), variant B as fast as XCUIRemote can send them (the nearest available stand-in
//  for one long jump: the app has no scrub) — then photographs the overlay each minute for four minutes.
//  Not a standing test; not committed.
//

import XCTest
import AVFoundation

final class Diag4UITests: XCTestCase {
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

    private func minuteShot(_ tag: String, _ m: Int) {
        press(.up, wait: 1); shot("p1d-\(tag)-min\(m)"); note("\(tag): minute \(m) shot at \(stamp())"); press(.down, wait: 1)
    }

    private func watch(_ tag: String, minutes: Int) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(stamp())")
        sleep(5); press(.up, wait: 1); shot("p1d-\(tag)-start"); press(.down, wait: 1)
        for m in 1...minutes {
            sleep(57)
            minuteShot(tag, m)
            if !app.otherElements["player"].exists { note("\(tag): player gone at minute \(m)"); break }
        }
        press(.menu, wait: 3)
    }

    func r1_WonderWomanTrueHD() { openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); watch("ww-truehd", minutes: 5) }

    func r2_WonderWomanAC3() {
        openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        sleep(5)
        press(.up, wait: 1); press(.up, wait: 1); press(.select, wait: 1)
        XCTAssertTrue(app.staticTexts["AUDIO"].waitForExistence(timeout: 5), "the audio panel did not open; focus \(focusedIds())")
        press(.down, wait: 1); press(.select, wait: 3)          // row 1 = AC-3 5.1
        note("ww-ac3: AC-3 selected at \(stamp())")
        press(.down, wait: 1)
        watch("ww-ac3", minutes: 5)
    }

    func r3_DivergentDTS() { openPoster("poster.Divergent", tab: "Movies"); pressPlay(); watch("divergent-dts", minutes: 3) }

    func r4_StargateExtendedAC3() {
        openPoster("poster.Stargate", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.buttons["pick.Extended"].waitForExistence(timeout: 5)); moveUntilFocused("pick.Extended", pressing: .up, limit: 3); press(.select, wait: 2)
        watch("stargate-extended-ac3", minutes: 3)
    }

    func r5_MagiciansAAC() {
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30)); sleep(2)
        moveUntilFocused("episode.1.1", pressing: .down, limit: 4); press(.select, wait: 2)
        watch("magicians-aac", minutes: 3)
    }

    /// Item 3: Menu with the audio panel open closes the panel and playback continues; Menu again exits.
    func r6_MenuInPanel() {
        openPoster("poster.Divergent", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        sleep(8)
        press(.up, wait: 1); press(.up, wait: 1); press(.select, wait: 1)
        XCTAssertTrue(app.staticTexts["AUDIO"].waitForExistence(timeout: 5), "the audio panel did not open; focus \(focusedIds())")
        shot("p1d-menu-1-panel-open"); note("menu: panel open at \(stamp())")
        press(.menu, wait: 2)
        let stillThere = app.otherElements["player"].exists
        let panelGone = !app.staticTexts["AUDIO"].exists
        shot("p1d-menu-2-after-first-menu"); note("menu: after first Menu at \(stamp()) — player exists \(stillThere), panel gone \(panelGone)")
        XCTAssertTrue(stillThere, "the first Menu press exited the player")
        sleep(3)
        press(.up, wait: 1); shot("p1d-menu-3-still-playing"); note("menu: overlay after 3 s at \(stamp())"); press(.down, wait: 1)
        press(.menu, wait: 3)
        let exited = !app.otherElements["player"].exists
        shot("p1d-menu-4-after-second-menu"); note("menu: after second Menu at \(stamp()) — player exists \(!exited)")
        XCTAssertTrue(exited, "the second Menu press did not exit the player")
    }
}
```

## Appendix B — the temporary statistics log (removed before the commit)

```swift
    // TEMP pass 1d evidence: VLC's own counters once a minute — removed after the device runs.
    private func startStatsLog() {
        statsTask?.cancel()
        statsTask = Task { @MainActor [weak self] in
            var minute = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                minute += 1
                guard let self, !Task.isCancelled, let st = self.player.media?.statistics else { return }
                EvidenceLog.line("[stats] min \(minute) t=\(self.timeMs) ms displayed=\(st.displayedPictures) late=\(st.latePictures) lost=\(st.lostPictures) decodedVideo=\(st.decodedVideo) decodedAudio=\(st.decodedAudio) playedAudio=\(st.playedAudioBuffers) lostAudio=\(st.lostAudioBuffers) demuxRead=\(st.demuxReadBytes) demuxBitrate=\(st.demuxBitrate) inputBitrate=\(st.inputBitrate)")
            }
        }
    }

    // and in stateChanged(.playing): if statsTask == nil { startStatsLog() }   // TEMP pass 1d
    // and in dismiss(): statsTask?.cancel()
```
