# Diagnosis: "MKV playback stutters/buffers and loses audio on Home Theater; MP4 episodes play fine" — 2026-09-14

Read-only pass. No app code, project setting, VLCKit build or Mac install was changed. The only working-tree change is this report plus the evidence files it cites (`reports/logs/diag-*.log`, `reports/screenshots/diag-*`). A temporary XCUITest harness (`DiagUITests.swift`, source in Appendix A) drove the device and was deleted afterwards; it was never committed.

## Finding

**Reproduced, but only on one of the four MKVs, and it is not a buffering or network fault.** Wonder Woman (4K 2160p HEVC Main 10 HDR, 55.2 Mbit/s, TrueHD 7.1) drops about one picture in seven, continuously, from the first second of playback: VLC's video output logged `picture is too late to be displayed` 1 774 times in 8 min 16 s, every one of them 42–53 ms late, at a constant rate, while in the same 8 minutes there was **no** re-buffering event, **no** second HTTP request, and **no** audio-output error. The other three MKVs (Divergent 4K HEVC HDR DTS at 12.6 Mbit/s; Stargate Extended and Theatrical, SD MPEG-2 AC-3 at 5.9 Mbit/s) and the Magicians MP4 control each played 8 minutes with one initial 1-second buffer fill, one HTTP connection, and a media clock that kept pace with the wall clock to within a second.

The evidence points at the **video decode/display pipeline on Home Theater for this specific stream** (VideoToolbox HEVC decode → `samplebufferdisplay` output at 3840×2160 10-bit), not at the network path, the server's Range handling, the Matroska demuxer, the 16 MiB read-ahead, or the TrueHD audio decoder. Divergent is the control that isolates this: same container, same codec family, same decoder and output modules, same HDR chroma forcing, zero late pictures. "MKV vs MP4" is a coincidence of which library files happen to be MKV. Audio loss was not observed in any log; audible output could not be checked from the harness (see §7).

Wall-clock and per-file numbers are in §1; the shortlist with what would confirm each item is in §6.

## 0. Build under test

| Item | Value |
|---|---|
| Repo HEAD before the pass | `95ee75e Pass 1b done: custom VLCKit with TrueHD decoder, linked as a local xcframework` |
| App binary on the device | built 2026-09-13 23:22 from that commit (pass 1b device proof); `build-for-testing` for the harness reported `TEST BUILD SUCCEEDED` and left the app binary's timestamp unchanged |
| VLCKit | custom 4.0.0-a24 build with the TrueHD decoder (`Frameworks/VLCKit.xcframework`, D012/D013); log header `VLC media player - 4.0.0-dev Otto Chriek`, `revision 4.0.0-dev-38816-gf9ee42b122` |
| Device | Apple TV "Home Theater", `AppleTV14,1` (Apple TV 4K, 3rd generation), tvOS 26.6 (Bonjour `model`/`osvers`) |
| Server | http://192.168.1.250:8093 (`ServerAPI.swift`, `ServerConfig.baseURL`) |
| Mac | Xcode 26.6; Mac is on 10GbE (`en0`, `10Gbase-T`) |

## 1. Reproduction on Home Theater — five 8-minute runs

Each run: cold launch, open the title, press Play, and every 60 s press Up (shows the overlay without pausing) and photograph the screen; after minute 8 press Menu. Logs are VLCKit's `.debug` file logger plus the app's own timestamped lines, copied off the device after each run (`reports/logs/diag-<file>.log`). Local times are EDT; HTTP `Date` headers are GMT (EDT+4).

### 1.1 Time to first picture and initial buffering

| Run | File | `play()` called | `state Playing` | `Stream buffering done` | `Decoder wait done` |
|---|---|---|---|---|---|
| diag1 | Divergent (MKV) | 07:37:47.303 | +0.249 s | 1001 ms in 36 ms | 62 ms |
| diag2 | Stargate Extended (MKV) | 07:47:19.692 | +0.150 s | 1001 ms in 9 ms | 46 ms |
| diag3 | Stargate Theatrical (MKV) | 07:56:39.823 | +0.173 s | 1056 ms in 9 ms | 108 ms |
| diag4 | Wonder Woman (MKV) | 08:05:58.931 | +0.187 s | 1000 ms in 19 ms | 71 ms |
| diag5 | Magicians S1E1 (MP4) | 08:15:31.672 | 08:15:31.672ING | 1021 ms in 6 ms | 42 ms |

There is no "first picture displayed" line in VLC 4's log; the start screenshot (taken about 6 s after Play) shows a picture on every run. "1001 ms in 36 ms" means VLC collected its 1000 ms `network-caching` target in 36 ms of wall time, i.e. the server delivered the first second of each file at far above real time.

### 1.2 Buffering events after start

| Run | app `[player] buffering` lines after the initial fill | VLC `Buffering N%` lines after `Stream buffering done` | HTTP requests after the first second |
|---|---|---|---|
| Divergent | none in 496 s | none | 0 |
| Stargate Extended | none in 496 s | none | 0 |
| Stargate Theatrical | none in 496 s | none | 0 |
| Wonder Woman | none in 496 s | none | 0 |
| Magicians (MP4) | none in 497 s | none | 0 |

The app logs `[player] buffering 0.0` whenever VLC starts a buffer fill and `1.0` when it completes (`PlayerModel.swift:402`); every run has exactly one such pair, at +0.01 s / +0.2 s. libvlc's own `Buffering N%` lines (`src/input/es_out.c:1182`) appear only during that first fill.

### 1.3 Late, dropped and audio lines

Grep of every VLC line matching late / drop / too slow / underrun / flush / discontinuity / resetting master clock / clock gap / StatusFailed / outputConfigurationChanged over the whole session:

| Run | `picture is too late to be displayed` (dropped) | `picture displayed late` (shown late) | audio output anomalies | other |
|---|---|---|---|---|
| Divergent | 0 | 0 | none | — |
| Stargate Extended | 4 (82, 50, 83, 50 ms) | 15 (2–18 ms) | none | see §5.3 |
| Stargate Theatrical | 4 (73, 41, 79, 46 ms) | 15 (6–16 ms) | none | see §5.3 |
| Wonder Woman | **1 774** (42–53 ms, mean 49) | 0 | none | — |
| Magicians (MP4) | 0 | 0 | none | — |

Lines that appear in every run and are not faults: `[WARN] failed to start passthrough audio output, failing back to linear format` (VLC first tries bitstream passthrough, then PCM), `[DBG] deferring start (N us)` × 40–857 (the Apple audio output waiting for the first block's presentation time, `modules/audio_output/apple/avsamplebuffer.m:297`), `[DBG] connection failed` × 3 and `end of stream` × 2 during the Matroska header parse (each seek to the Cues at the end of the file abandons the open HTTP body, `modules/access/http/h1conn.c:130`), `[WARN] lookup failed (-25300: 'Item not found')` (keychain, at library init).

Wonder Woman's drops in detail: the first `too late` line is the very next line after the audio output's `starting late (-26 us)`; from there to the Menu press the log is 200 `too late` lines per 200 lines, i.e. a steady rate to the end. 1 774 ÷ 495.6 s = 3.6 pictures/s, ≈ 15 % of frames at 23.976 fps. The lateness is tightly clustered (864 values in 42–49 ms, 910 in 50–53 ms, none outside 42–53). The drop rule is `src/video_output/video_output.c:1019-1035` (`IsPictureLateToProcess`): a picture is dropped when it would be displayed more than one frame period (41.7 ms) late; a picture shown less than that late logs `picture displayed late` instead (`video_output.c:1475`). Zero of the latter means every picture that was shown was on time and every picture that was late was late by almost exactly one frame.

### 1.4 Audio presence

What the logs show for each run: the audio ES is selected at open (`[player] track selected type=0 selected=audio/2` or `audio/4`), the decoder starts (`codec (dca|ac3|truehd) started`), the Apple output opens (`Output on HDMI, channel count: 8/6/2`, `format: 48000 rate, N nch, 4 bps, fl32`), it starts once (`started` or `starting late`), and no stop, flush, underrun, `AVQueuedSampleBufferRenderingStatusFailed`, `flushedAutomatically`, `outputConfigurationChanged` or `discontinuity` line follows until the Menu press. The audio track stays selected through the whole run (the next `track selected` line is the unselect at Stopping). The minute screenshots cannot show audio; nothing in the harness can hear the HDMI output (§7).

### 1.5 Minute-by-minute overlay clock (screenshots, `reports/screenshots/diag-*`)

| Run | start | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | state in all 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| Divergent | 00:09 | 01:10 | 02:10 | 03:11 | 04:12 | 05:13 | 06:13 | 07:14 | 08:15 | Playing |
| Stargate Extended | 00:09 | 01:10 | 02:10 | 03:11 | 04:12 | 05:12 | 06:13 | 07:14 | 08:15 | Playing |
| Stargate Theatrical | 00:09 | 01:10 | 02:10 | 03:11 | 04:12 | 05:12 | 06:13 | 07:14 | 08:15 | Playing |
| Wonder Woman | 00:09 | 01:10 | 02:10 | 03:11 | 04:12 | 05:13 | 06:14 | 07:14 | 08:15 | Playing |
| Magicians (MP4) | 00:09 | 01:10 | 02:10 | 03:11 | 04:12 | 05:13 | 06:14 | 07:15 | 08:16 | Playing |

Wall time between shots was 60–61 s (59 s sleep + press + capture). The media clock advanced 60–61 s per minute on every file, Wonder Woman included: the dropped pictures do not stall the clock (audio is the master clock), they thin the picture stream. Cross-check from the app lines: `dismiss at 495646 ms` after 496.431 s of wall time for Wonder Woman; 495640 / 496.406 s Divergent; 494666 / 495.756 s Stargate Extended; 494643 / 495.709 s Theatrical; 495655 / 496.906 s Magicians.

## 2. Bandwidth

### 2.1 Bitrate from the API (`size` × 8 ÷ `duration`, fields from `/api/movies/<id>` and `/api/shows/2`)

| File | Resolution / codec | size (B) | duration (s) | Mbit/s | MB/s | stream |
|---|---|---|---|---|---|---|
| Divergent | 3840×1600 hevc Main 10, dts 7.1 | 13 214 700 163 | 8 379.4 | 13 214 700 163 × 8 ÷ 8 379.4 ÷ 10⁶ = **12.62** | 1.58 | /stream/1 |
| Stargate Extended | 720×480 mpeg2video, ac3 5.1 | 5 722 251 076 | 7 798.1 | **5.87** | 0.73 | /stream/2 |
| Stargate Theatrical | 720×480 mpeg2video, ac3 5.1 | 5 346 213 686 | 7 265.6 | **5.89** | 0.74 | /stream/3 |
| Wonder Woman | 3840×2160 hevc Main 10 HDR, truehd 7.1 | 58 483 322 537 | 8 476.2 | 58 483 322 537 × 8 ÷ 8 476.2 ÷ 10⁶ = **55.20** | 6.90 | /stream/4 |
| Magicians S1E1 | 1920×1080 h264 High, aac stereo | 3 180 161 687 | 3 128.6 | **8.13** | 1.02 | /stream/8 |

Read-ahead available at those rates: the `prefetch` filter's 16 777 216-byte ring buffer holds 10.6 s of Divergent, 22.9 s / 22.7 s of Stargate, 2.4 s of Wonder Woman, 16.4 s of Magicians, on top of the 1000 ms `network-caching` target.

### 2.2 Throughput from the Mac (`curl -o /dev/null -m 60`, sequential, no device playback running, 07:3x EDT)

| Stream | bytes in the window | wall | B/s |
|---|---|---|---|
| /stream/1 | 13 214 700 163 (whole file) | 51.96 s | 254 301 368 (254 MB/s) |
| /stream/2 | 5 722 251 076 (whole) | 23.33 s | 245 316 326 |
| /stream/3 | 5 346 213 686 (whole) | 21.77 s | 245 572 282 |
| /stream/4 | 14 724 046 848 (60 s cap hit) | 60.00 s | 245 399 124 (245 MB/s = 36× Wonder Woman's 6.90 MB/s) |
| /stream/8 | 3 180 161 687 (whole) | 13.63 s | 233 344 707 |

This measures server + Mac path (both 10GbE), not the Apple TV's path.

### 2.3 VLC's read/demux rate

VLC only exposes input/demux byte rates through `libvlc_media_player_get_stats`; the app does not read them and the debug log does not print them, so no figure. The implied rate is the file bitrate: the read-ahead never ran dry in any run (§1.2), so the access kept up with 6.90 MB/s for Wonder Woman over 8 minutes on a single connection (≈ 3.4 GB delivered, one request).

### 2.4 Apple TV interface (Ethernet vs Wi-Fi)

Not readable through Xcode's tooling: `xcrun devicectl device info details` reports only `transportType: localNetwork`, `tunnelTransportProtocol: tcp` and a tunnel IPv6; none of the `device info` subcommands (`appIcon apps authListing ddiServices details displays files lockState processes`) reports the interface. Read-only hints gathered instead (identifiers redacted):

| Host | ping min/avg/max/stddev (ms) |
|---|---|
| Home Theater 192.168.1.30 (first 20 packets, during the Divergent run) | 4.028 / 18.315 / 268.036 / 57.301 |
| Home Theater (second 10 packets) | 4.292 / 5.336 / 8.483 / 1.290 |
| UniFi gateway 192.168.1.1 (wired) | 0.481 / 0.617 / 0.918 / 0.160 |
| Denon AVR 192.168.1.39 (wired) | 0.600 / 0.800 / 1.004 / 0.134 |
| the other Apple TV 192.168.1.41 | 2.801 / 10.867 / 77.890 / 22.355 |
| server 192.168.1.250 | 0.502 / 0.638 / 0.789 / 0.096 |

Wired hosts on this LAN answer in under 1 ms; Home Theater never answered in under 4 ms and jittered to 268 ms. That is consistent with Wi-Fi, not proof. Whatever the link is, it carried 55 Mbit/s for 8 minutes without a single re-buffer, so it was not the limiting factor in this session.

## 3. VLC options in play

### What the app passes
Nothing. `Marlin Media TV/PlayerModel.swift` creates the library and the player with no option array and the media with no `addOption`:

| File:line | Code | Effect |
|---|---|---|
| `PlayerModel.swift:121` | `library = VLCLibrary.shared()` | shared library, built with VLCKit's default option list only |
| `PlayerModel.swift:122-127` | file logger `.debug` + console logger `.info` | logging only, no playback effect |
| `PlayerModel.swift:128` | `player = VLCMediaPlayer(library: library)` | no player options |
| `PlayerModel.swift:139` | `VLCMedia(url: request.url)` | no `addOption(_:)` call anywhere (`grep -n addOption` → nothing) |

### What VLCKit adds on tvOS (`~/vlckit-build/VLCKit/Sources/Core/VLCLibrary.m`, `_defaultOptions`, lines 183-204, `TARGET_OS_IPHONE` branch)
`--no-color --no-osd --no-video-title-show --no-snapshot-preview --http-reconnect --text-renderer=freetype --avi-index=3 --audio-resampler=soxr`.
`--avcodec-fast` is inside `#ifndef __LP64__` (line 195-199) and tvOS arm64 defines `__LP64__` (checked with `xcrun --sdk appletvos clang -arch arm64 -E` → 1), so it is **not** passed. `--http-reconnect` is defined only by the legacy `modules/access/http.c:72`; the HTTP access actually loaded is the newer `modules/access/http/access.c` (log: `using access module "http"` … `outgoing request:`/`incoming response:` are its strings), which never reads `http-reconnect` (`grep -rn http-reconnect modules/access/http/` → nothing). Net effect of the VLCKit list on streaming: only `--audio-resampler=soxr`.

### libvlc defaults for everything left unset (source in `~/vlckit-build/VLCKit/libvlc/vlc`)
| Option | Default | Source | Meaning here |
|---|---|---|---|
| `network-caching` | 1000 ms | `src/libvlc-module.c:1996` | the PTS delay the http access reports (`modules/access/http/access.c:99-101`) → the "Stream buffering done (1001 ms …)" target |
| `file-caching` | 1000 ms | `src/libvlc-module.c:1984` | not used (network source) |
| `live-caching` / `disc-caching` | 300 ms (`DEFAULT_PTS_DELAY`, `include/vlc_config.h:68`) | `src/libvlc-module.c:1988-1992` | not used |
| `clock-jitter` | 5000 ms | `src/libvlc-module.c:2006` | max PCR jitter tolerated before a clock reset |
| `clock-synchro` | -1 (auto) | `src/libvlc-module.c:2003` | |
| `cr-average` | 40 | `src/libvlc-module.c:2001` | clock-reference averaging window |
| `clock-master` | auto | `src/libvlc-module.c:2009` | audio master |
| `prefetch-buffer-size` | 16384 KiB (= 16 777 216 B, log: `using 16777216 bytes buffer`) | `modules/stream_filter/prefetch.c:552` | read-ahead ring buffer between the HTTP access and the demuxer |
| `prefetch-seek-threshold` | 16384 B | `modules/stream_filter/prefetch.c:556` | forward skips larger than buffered+16 KiB become a new HTTP Range request |
| `http-continuous` | false | `modules/access/http/access.c:296` | |
| `http-forward-cookies` | true | `modules/access/http/access.c:299` | |
| `http-user-agent` / `http-referrer` / `http-token` | unset | `modules/access/http/access.c:301-312` | UA seen on the wire: `VLC/4.0.0-dev LibVLC/4.0.0-dev` |
| `avcodec-threads` | 0 (auto) | `modules/codec/avcodec/avcodec.c:128` | |
| `avcodec-dr` | true | `modules/codec/avcodec/avcodec.c:107` | |
| `avcodec-skip-frame` / `avcodec-skip-idct` | 0 | `modules/codec/avcodec/avcodec.c:112-115` | |
| `mkv-preload-clusters` | false | `modules/demux/mkv/mkv.cpp:81` | clusters read on demand, not indexed up front |
| `mkv-use-ordered-chapters` / `mkv-use-chapter-codec` / `mkv-preload-local-dir` | true | `modules/demux/mkv/mkv.cpp:61-69` | |
| `mkv-seek-percent` / `mkv-use-dummy` | false | `modules/demux/mkv/mkv.cpp:73-77` | |

Read-ahead in seconds at each file's bitrate (16 777 216 B ÷ MB/s from step 2): Divergent 10.6 s, Stargate 22.9 s / 22.7 s, Wonder Woman 2.4 s, Magicians 16.4 s. Plus the 1000 ms `network-caching` es_out buffer.

## 4. Server range support and request pattern

### `curl -I -H 'Range: bytes=0-1'` (2026-09-14 07:33 and 07:41 EDT)
| Stream | Status | Accept-Ranges | Content-Range | Content-Type |
|---|---|---|---|---|
| /stream/1 Divergent | 206 Partial Content | bytes | bytes 0-1/13214700163 | video/x-matroska |
| /stream/2 Stargate Extended | 206 | bytes | bytes 0-1/5722251076 | video/x-matroska |
| /stream/3 Stargate Theatrical | 206 | bytes | bytes 0-1/5346213686 | video/x-matroska |
| /stream/4 Wonder Woman | 206 | bytes | bytes 0-1/58483322537 | video/x-matroska |
| /stream/8 Magicians S1E1 | 206 | bytes | bytes 0-1/3180161687 | video/mp4 |

Every response also carries `Content-Length: 2`, `Last-Modified` and `Date`; no `Connection`, `Cache-Control`, `Server` or `Transfer-Encoding` header. A closed range is honoured exactly: `Range: bytes=1000000-2048575` on /stream/4 → `206`, `size_download=1048576`, 0.084 s. `HEAD /stream/8` without Range → `200`, `Content-Length: 3180161687`, `Accept-Ranges: bytes`.

## 5. Differential: MP4 vs MKV, and MKV vs MKV

| | Magicians MP4 | Divergent MKV | Stargate MKV (×2) | Wonder Woman MKV |
|---|---|---|---|---|
| access / filters | http, prefetch (16 MiB) + record | http, prefetch (16 MiB) + record | same | same |
| demux | mp4 | mkv | mkv | mkv |
| HTTP pattern | 3 requests in the first second (0-, moov tail 3 313 556 B at 3176848131-, 48-), then one connection to the end | 5 requests in the first second (0-, Cues tail, 108-, tail, 126-), then one connection to the end | same shape (0-, Cues tail, 123-, tail, 183-) | same shape (0-, Cues tail 168 401 B, 123-, tail 2 075 B, 183-) |
| initial fill | 1021 ms in 6 ms | 1001 ms in 36 ms | 1001/1056 ms in 9 ms | 1000 ms in 19 ms |
| re-buffers in 8 min | 0 | 0 | 0 | 0 |
| video decoder | videotoolbox (hw), output chroma forced to 420v | videotoolbox (hw), output chroma forced to x420 | avcodec (software MPEG-2) + deinterlace filter toggling | videotoolbox (hw), x420 |
| vout | samplebufferdisplay | samplebufferdisplay | samplebufferdisplay | samplebufferdisplay |
| audio decoder / output | avcodec aac → HDMI 2 ch fl32 44.1 kHz | avcodec dca → HDMI 8 ch fl32 48 kHz | avcodec ac3 → HDMI 6 ch | mlp packetizer + avcodec truehd → HDMI 8 ch fl32 48 kHz |
| audio output format changes after start | none | none | none | none |
| dropped pictures | 0 | 0 | 4 + 4 (start and deinterlace toggles) | 1 774, steady |

### 5.1 What separates Wonder Woman from Divergent
Same demuxer, same access path and request shape, same decoder device and module, same forced chroma, same vout, same audio output format (8 ch fl32 48 kHz), same 0 re-buffers. The differences are the stream itself: 3840×2160 vs 3840×1600 (35 % more pixels per frame), 55.2 vs 12.6 Mbit/s (4.4× the HEVC bit budget per second), TrueHD vs DTS. The TrueHD half is excluded by the earlier logs in `reports/logs/`: with the pass 1 SPM VLCKit (no TrueHD decoder, VLC auto-selected the AC-3 track) Wonder Woman logged 75 `too late` drops in its first 28 s; with the custom build and TrueHD selected, 75 in the first 28 s; after switching to AC-3 in that run, drops continued (6 in the short window before the test ended). So the drop rate is the same with AC-3 and TrueHD audio, and the audio decoder is not the variable.

### 5.2 What separates the MKVs from the MP4
Nothing in the transport. Both containers go through the same access module, the same 16 MiB read-ahead and the same one-connection pattern once playback starts. The only container-specific behaviour is at open: the MP4 needs three requests because its `moov` atom sits at the end of the file (`Range: bytes=0-`, then `3176848131-` for the 3.3 MB tail, then `48-` to stream), the MKVs need five (SeekHead → Cues at the end of the file → back to the first cluster → the tail once more → back to the first cluster). Both fill the 1-second target in under 40 ms. After open, the MP4 and three of the four MKVs behave identically: no re-buffer, no dropped picture (bar Stargate's software-decoder handful, §5.3), clock in step with wall time. The single outlier is one MKV whose *stream* is 2160p HEVC at 55 Mbit/s (6.8× the MP4's bitrate; 8.3 Mpixel vs 2.1 Mpixel per frame), and its fault sits at the video output, downstream of everything the container touches. The library has no MP4 at 4K/HEVC bitrates, so "MP4 episodes play fine" is, in this library, a statement about 1080p H.264 at 8 Mbit/s.

### 5.3 Stargate's few late pictures
Both SD runs show the same shape: four `too late` (41–83 ms) in the first eight lines after the audio output starts, then one or two `picture displayed late` (5–18 ms) each time the deinterlace filter is inserted or removed (`deinterlace -1, mode auto, is_needed 1` ↔ `Detected progressive video … is_needed 0`; 7 cycles in 8 minutes on Theatrical, 6 on Extended, each followed 1–3 lines later by a late line, `diag-stargate-*.log`). Software MPEG-2 decode with an interlace detector that flips; a couple of frames per toggle, no re-buffering, clock steady. Not the reported fault.

## 6. Shortlist, with evidence and what would confirm it

1. **Video pipeline throughput/latency for the 2160p HEVC 55 Mbit/s stream on Home Theater (VideoToolbox decode → x420 CVPixelBuffer → `samplebufferdisplay`).** Evidence: 1 774 drops at a constant 3.6/s from the first second, each exactly ~one frame late, none shown late, no input starvation, no audio anomaly, identical modules on Divergent with 0 drops. The pattern (dropped pictures are late by one frame period + 0–11 ms; the pictures in between are on time) says pictures reach the vout in a rhythm that is one frame behind about every seventh frame, rather than a slowly accumulating lag. Would confirm: (a) VLC's picture statistics (`libvlc_media_player_get_stats`: `i_displayed_pictures` / `i_lost_pictures`) logged once a minute — a code change, so not done; (b) the same file played by the official VLC for tvOS (same decoder lineage) and by a native AVFoundation-based player on the same box — if only VLC drops, it is VLC's pipeline; if both drop, the box; (c) an HEVC stream of the same resolution at a lower bitrate, or Wonder Woman remuxed to MP4 unchanged (rules the container in or out with the same bits); (d) the stream's SPS/VPS parameters (reorder depth, level, tier) compared with Divergent's — needs ffprobe on the server or a parser, neither run here.
2. **Wi-Fi on Home Theater as an intermittent factor at other times.** Evidence for: ping signature (§2.4). Evidence against for this session: 8 minutes at 55 Mbit/s with zero re-buffers and zero extra requests. Would confirm: the interface shown in Settings → Network on the Apple TV; a run at a busier time of day with the same harness.
3. **Audio loss.** Not reproduced: no audio-output stop/flush/restart/underrun line in 33 minutes of MKV playback, and the audio ES stayed selected. Could not be heard (§7). Would confirm: which track is selected when it happens (TrueHD 7.1 vs AC-3), whether the AVR's display shows the PCM format changing, and a log from that moment (the app's log file is at `Library/Caches/marlin-media-tv.log`, copy command in COLD-START.md).

Excluded by this evidence: server Range support (206 with exact `Content-Range` on every stream, closed ranges honoured, one connection sustains 6.9 MB/s), request churn during playback (5 requests at open, then none), the 16 MiB prefetch / 1 s network-caching running dry (no `Buffering` line after the first fill on any file), the Matroska demuxer (three MKVs clean), the TrueHD decoder (§5.1).

## 7. What could not be tested

- Audible audio: the harness has no path to the HDMI/eARC output. Only the audio-output module's log lines and the track-selection state were observable.
- Home Theater's network interface: not exposed by `devicectl`; only inferred from ping (§2.4).
- Server-side logs and the server's own transmit rate to the Apple TV: no access from this pass; the server address is the only thing the app knows.
- VLC's live read/demux/decoded/dropped statistics: not logged by VLC's debug output and not read by the app.
- Playback beyond 8 min 16 s from the start, and playback after a seek: out of the spec.
- Stargate's PGS/subrip and Wonder Woman's PGS tracks were left at VLC's defaults (subrip auto-selected on Stargate, visible in the minute-6/7/8 screenshots); not varied.
- The temporary harness could not read the overlay's text through accessibility (`player.state` / `player.elapsed` always reported "(overlay hidden)"), so the clock values in §1.5 were read from the screenshots by eye.

## 8. Questions for the owner

1. When you see the stutter, is it Wonder Woman specifically, or also Divergent / Stargate? Do you see the on-screen clock stall (buffering) or does the clock keep running while motion judders (frame drops)? The logs here show only the second kind, only on Wonder Woman.
2. Is Home Theater on Ethernet or Wi-Fi (Settings → Network)? And is the other Apple TV in the same state?
3. When audio drops, which audio track is selected (the Audio panel shows the tick), and what does the AVR display at that moment?
4. Would you accept, in a later pass, one added log line per minute with VLC's displayed/lost picture counters (`libvlc_media_player_get_stats`)? It is the one measurement that would turn the shortlist's item 1 from "the evidence points at" into a number, and it is not built here because it is a code change.
5. The Magicians MP4 control played 8 minutes with no re-buffer and no dropped picture, but it is 1080p H.264 at 8 Mbit/s. If you have an MP4 at 4K/HEVC bitrates (or can remux Wonder Woman to MP4 unchanged), that is the cleanest container-vs-stream test and needs no app change.

## 9. Method (for re-running)

1. Harness: Appendix A, added to the UITests target, built once with `xcodebuild build-for-testing -project "Marlin Media TV.xcodeproj" -scheme "Marlin Media TV" -destination 'platform=tvOS,name=Home Theater' -derivedDataPath build/DerivedData` (TEST BUILD SUCCEEDED; the app product was not rebuilt).
2. Each run: `xcodebuild test-without-building … -only-testing:"Marlin Media TVUITests/DiagUITests/<test>" -resultBundlePath <n>.xcresult`; screenshots via `xcrun xcresulttool export attachments`; log via `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier com.marlin1111.marlin-media-tv --source Library/Caches/marlin-media-tv.log`. The log file accumulates across launches; each analysis took the segment after the last `[player] play() called`.
3. Log analysis: app lines carry `h:mm:ss.SSS AM/PM` stamps (note the narrow no-break space before AM/PM); VLC lines carry none, but each HTTP response carries the server's `Date:` header at 1 s resolution, which is how requests per minute were counted. Counts above are plain `grep -c` over the session segment.
4. Bandwidth: §2.1 arithmetic from the API JSON; §2.2 `curl -sS -o /dev/null -m 60 -w '%{size_download} %{time_total} %{speed_download}' <stream>`; §4 `curl -I -H 'Range: bytes=0-1'`.
5. Screenshots committed here are the overlay strip (y 1560–2080 of the 3840×2160 capture, halved) for each minute plus the full start frame per file, JPEG; the full-size PNG set stays in the session scratchpad.

## Appendix A — the temporary harness (deleted after the runs; not committed)

```swift
//
//  DiagUITests.swift — temporary diagnostic harness for the 2026-09-14 MKV stutter diagnosis.
//  Plays one file for eight minutes from the start and photographs the overlay each minute
//  (an "up" press shows the overlay without pausing). Not a standing test; not committed.
//

import XCTest

final class DiagUITests: XCTestCase {
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
    private func note(_ t: String) { let a = XCTAttachment(string: t); a.name = "note"; a.lifetime = .keepAlways; add(a); NSLog("[diag] %@", t) }
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

    /// Eight minutes from the start; the overlay is summoned with "up" (no pause) before each shot.
    private func watch(_ tag: String, minutes: Int = 8) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(Date())")
        sleep(5); press(.up, wait: 1); shot("diag-\(tag)-start")
        for m in 1...minutes {
            sleep(59)
            press(.up, wait: 1)
            shot("diag-\(tag)-min\(m)")
            let state = app.staticTexts["player.state"].exists ? app.staticTexts["player.state"].label : "(overlay hidden)"
            let elapsed = app.staticTexts["player.elapsed"].exists ? app.staticTexts["player.elapsed"].label : "?"
            note("\(tag): minute \(m) — state \(state), elapsed \(elapsed), player exists \(app.otherElements["player"].exists)")
            if !app.otherElements["player"].exists { note("\(tag): player gone at minute \(m)"); break }
        }
        press(.menu, wait: 3)
    }

    func diag1_Divergent() { openPoster("poster.Divergent", tab: "Movies"); pressPlay(); watch("divergent") }
    func diag2_StargateExtended() {
        openPoster("poster.Stargate", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.buttons["pick.Extended"].waitForExistence(timeout: 5)); moveUntilFocused("pick.Extended", pressing: .up, limit: 3); press(.select, wait: 2)
        watch("stargate-extended")
    }
    func diag3_StargateTheatrical() {
        openPoster("poster.Stargate", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.buttons["pick.Theatrical"].waitForExistence(timeout: 5)); moveUntilFocused("pick.Theatrical", pressing: .down, limit: 3); press(.select, wait: 2)
        watch("stargate-theatrical")
    }
    func diag4_WonderWoman() { openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); watch("wonder-woman") }
    func diag5_MagiciansE1() {
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30)); sleep(2)
        moveUntilFocused("episode.1.1", pressing: .down, limit: 4); press(.select, wait: 2)
        watch("magicians-s01e01")
    }
}
```
