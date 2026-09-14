# Diagnosis 3: Wonder Woman — (A) silent on TrueHD, audible on AC-3; (B) judder on every track — 2026-09-14

Read-only pass. No app code, project setting, VLCKit build or Mac install was changed. Working-tree change: this report plus the evidence it cites (`reports/logs/d3-*.log`, `reports/screenshots/d3-*`). A temporary XCUITest harness (`Diag3UITests.swift`, Appendix A) drove Home Theater and was deleted afterwards. Build under test: HEAD `7bd50ab` (pass 1c), app dylib built 09:41:31 today, unchanged by this pass.

## Findings, first

**A — TrueHD silence: shortlist of two, one strongly supported.**
1. **The TrueHD path feeds the tvOS audio renderer 1 200 sample buffers per second of 40 samples (0.83 ms) each; DTS feeds 94 of 512 samples, AC-3 31 of 1 536.** Every other stage is identical (same decoder module, same converter/filter/resampler chain, same 8-channel float 48 kHz format, same HDMI channel count, same session category, no error, warning, drift, underrun or restart line in five minutes on any track). The block size is set by the codec: TrueHD access units are 40 samples (`modules/packetizer/mlp.c:182`), VLC makes one block per decoded frame (`modules/codec/avcodec/audio.c:216`) and the Apple output makes one `CMSampleBuffer` per block (`modules/audio_output/apple/avsamplebuffer.m:143-197`). The log corroborates it: 762 `deferring start` lines 76–93 µs apart before the TrueHD output starts, versus 139 for DTS and 40 for AC-3. This is the only difference in the pipeline between the silent and the audible tracks, and it is 13–38× in magnitude.
2. **The decoded PCM cannot be inspected from here** (no tracer, no PCM dump, no way to hear it), so "the TrueHD decoder of this custom FFmpeg produces zeros or garbage" is not excluded by evidence. It is weakened by: FFmpeg's decoder reports the header correctly (`MLP channels: 8 samplerate: 48000`), no decode error reaches the log, and the same decoder build is the one pass 1b proved to *run*; it is not ruled out because nobody has heard or captured its output.

What is excluded: the channel layout and session (identical lines to DTS, which is audible), the session channel count (8 granted, no `setPreferredOutputNumberOfChannels failed`), passthrough/bitstream (both fall back to linear PCM), a decoder restart, a PTS discontinuity, the resampler (loaded for all three, never active: no `resampling` line on TrueHD).

**B — judder: the video output drops one picture in seven on Wonder Woman at a constant rate, on every audio track, and the shortest differential to Divergent is the stream itself, not the pipeline.** 1 081 drops in 305.6 s (3.54/s, 14.8 % of frames) with TrueHD, 1 147 in 322.6 s (3.56/s, 14.8 %) with AC-3, 0 in 305.7 s on Divergent, with identical decoder, output and session lines. Per minute the rate is flat (164/218/232/223/227 per interval on TrueHD). Every dropped picture is late by one frame period (42–53 ms); no picture is shown late; the decoder never reports a drop, session error or restart. The two files share profile, tier, level, bit depth, chroma, frame rate and decoder path; they differ in pixels per frame (+35 %), bits per frame (**4.4×**: 2.30 vs 0.53 Mbit), keyframe spacing (1 s vs 2.75 s), SPS reorder depth (3 vs 2) and origin (disc remux vs re-encode). VLC targets 23.976 fps for both (container `DefaultDuration`); no frame-rate mismatch or cadence line exists in this VLC; the runner sees a 60 Hz screen (`maximumFramesPerSecond=60`). CPU could not be read (Instruments cannot attach: §7).

## A. TrueHD silence

### A.1 Side by side from today's device logs (five minutes each, `reports/logs/d3-*.log`)

| | Wonder Woman **TrueHD** (`d3-ww-truehd.log`) | Wonder Woman **AC-3** (`d3-ww-ac3.log`) | Divergent **DTS** (`d3-divergent-dts.log`) |
|---|---|---|---|
| ES | `audio/2` fourcc `mlpa` | `audio/3` fourcc `a52 ` (picked in the audio panel at +10.7 s; `audio/2` TrueHD ran for the first 10 s) | `audio/2` fourcc `dts ` |
| Packetizer | `using audio packetizer module "mlp"` | `using audio packetizer module "a52"` | `using audio packetizer module "dts"` |
| Decoder | `codec (truehd) started`, `using audio decoder module "avcodec"` | `codec (ac3) started`, `using audio decoder module "avcodec"` | `codec (dca) started`, `using audio decoder module "avcodec"` |
| Header line | `MLP channels: 8 samplerate: 48000` | `A/52 channels:6 samplerate:48000 bitrate:448000` | `DTS samplerate:48000 bitrate:1536000` |
| Decoder in / packetizer out | `i_rate 0 / 48000`, `i_channels 0 / 8` | `i_rate 0 / 48000`, `i_physical_channels 0 / 4199` | `i_channels 8 / 6`, `i_physical_channels 0 / 4199`, `profile -1 / 1` (the DTS core is 5.1; VLC still opens the output with 8 channels) |
| Passthrough | `failed to start passthrough audio output, failing back to linear format` | same | same |
| Output route | `Output on HDMI, channel count: 8` | `Output on HDMI, channel count: 6` | `Output on HDMI, channel count: 8` |
| Layout | `swapping Surround and RearSurround channels for 7.1 Rear Surround`, `VLC keeping the same input layout` | `VLC keeping the same input layout` (no swap line: 5.1) | same two lines |
| Volume / filter / converter / resampler | `float_mixer`; `scaletempo`; `audio_format`; `soxr` (`Using SoX Resampler … 'Medium 16-bit with medium roll-off'`) | `float_mixer`; `scaletempo`; `soxr` — no `audio_format` converter (the decoder already delivers float) | same four |
| Output format | `format: 48000 rate, 8 nch, 4 bps, fl32` | `format: 48000 rate, 6 nch, 4 bps, fl32` | `format: 48000 rate, 8 nch, 4 bps, fl32` |
| Output start | `deferring start` ×762 (blocks 76–93 µs apart), then `starting late (-N us)` ×1 | `deferring start` ×44, then `started` ×1 | `deferring start` ×139, then `started` ×1 |
| In the following five minutes: `underrun`, `too slow`, `late`, `silence`, `way too early`, `discarded audio`, `discontinuity`, `resampling`, `drift`, `flushedAutomatically`, `StatusFailed`, `outputConfigurationChanged`, `resetting master clock` | **none** | **none** (five minutes after the switch) | **none** (five minutes) |
| Audio ES re-selection / decoder restart during the run | none | the one deliberate switch at +10.7 s (`killing decoder fourcc 'mlpa'` → `codec (ac3) started`, `ES track selected (forced): 'audio/3'`); none after | none |

Timing relation between audio PTS and the clock: the audio output is the master clock (`program(0): using clock source: 'audio'` in all three) and reports its position once a second through the renderer's periodic time observer (`avsamplebuffer.m:245-270`); VLC prints a line only when it has to correct (`resampling …`, `drift`, `way too early … playing silence`, `resetting master clock`). None appears in five minutes on any of the three runs, so from the log the audio clock advanced steadily on TrueHD exactly as on DTS — which is also why the video kept pace with the wall clock on every run since pass 1.

### A.2 — the buffers the TrueHD decoder produces (container + source; VLC's log does not print per-block PTS)

| | Wonder Woman TrueHD (track 2) | Wonder Woman AC-3 (track 3) | Divergent DTS (track 2) |
|---|---|---|---|
| Container frame duration (`TrackEntry.DefaultDuration`) | 833 333 ns = **40 samples** at 48 kHz | 32 000 000 ns = 1 536 samples | 10 666 667 ns = 512 samples |
| How the frames sit in the file (first cluster, `cues/scan-audio-blocks.py`) | 11 SimpleBlocks/s, each **EBML-laced with 120 frames**, 100 ms apart (21 kB each) | 3 frames per block (fixed lacing), 96 ms apart | 8 frames per block (fixed lacing), 85 ms apart |
| What the demuxer sends | one packet per laced frame (`modules/demux/mkv/mkv.cpp:588-593`, `NumberFrames()` loop) → **1 200 packets/s** | 31/s | 94/s |
| Packetizer | `mlp`: one block per access unit, `i_samples = 40 << rate_idx` (`modules/packetizer/mlp.c:182`) | `a52`: 1 536 samples | `dts`: `i_frame_length` = 512 (`modules/packetizer/dts.c:125`) |
| Decoder | `avcodec` (FFmpeg `mlpdec`, `access_unit_size` = 40; output `AV_SAMPLE_FMT_S32`, `libavcodec/mlpdec.c:424`) → VLC `S32N` (`modules/codec/avcodec/audio.c:594,637`) | `avcodec` ac3 (fltp) | `avcodec` dca (fltp; `dca_core.c:2075` `nb_samples = npcmblocks × 32`) |
| Blocks handed to the audio output | one `block_t` per decoded frame, `i_nb_samples = frame->nb_samples` (`audio.c:216`) → **40-sample blocks, 1 200 per second** | 1 536-sample blocks, 31/s | 512-sample blocks, 94/s |
| At the Apple output | one `CMSampleBuffer` per block (`modules/audio_output/apple/avsamplebuffer.m:143-197`, `wrapBuffer:`; `numSamples = block->i_nb_samples`) → **1 200 sample buffers/s of 0.83 ms** enqueued into `AVSampleBufferAudioRenderer` | 31/s of 32 ms | 94/s of 10.7 ms |

PTS: the container timecodes step exactly 100 ms per 120-frame block (gaps `[100, 100, …]`), i.e. 0.8333 ms per frame; nothing in any log shows a backwards or gapped audio PTS (`discontinuity`, `discarded audio buffer`, `way too early`: none in the TrueHD runs). Whether blocks are dropped inside the decoder or at the output is not printed by this VLC (the aout's sync decisions go to the tracer only, `src/audio_output/dec.c:641-647`; no tracer is loaded) — see "could not test".

### A.4 — where the TrueHD path differs from the DTS path (VLCKit source at ~/vlckit-build)

| Stage | TrueHD | DTS | Same? |
|---|---|---|---|
| Demux | `mkv` (D014: `mkv_trusted`), laced frames split per frame `mkv.cpp:588-593` | same | yes |
| Packetizer | `modules/packetizer/mlp.c` (40-sample AUs; `MLP channels: 8 samplerate: 48000` at `mlp.c` SyncInfo) | `modules/packetizer/dts.c` (512-sample frames) | **no — block size 13× smaller** |
| Decoder module | `avcodec` → FFmpeg `truehd` (`mlpdec.c`), `S32` out | `avcodec` → FFmpeg `dca`, `fltp` out | module same; **native sample format differs (S32 vs float)** |
| Sample-format converter | `audio_format` (S32N → FL32) | `audio_format` (planar float → FL32 interleave handled in `audio.c`; converter still loaded) | both load `audio converter module "audio_format"` |
| Volume / filters / resampler | `float_mixer`, `scaletempo`, `soxr` | same three lines | yes |
| Layout to tvOS | `Output on HDMI, channel count: 8`, `swapping Surround and RearSurround channels for 7.1 Rear Surround` (`coreaudio_common.c:632-634`), `VLC keeping the same input layout`, `format: 48000 rate, 8 nch, 4 bps, fl32` | identical four lines | yes |
| AVAudioSession | category Playback, mode MoviePlayback (`avaudiosession_common.m:214-224`), `setPreferredOutputNumberOfChannels:8` checked against `outputNumberOfChannels` (`:61-66`, no warning logged → 8 granted) | same | yes |
| Output | `avsamplebuffer` (`AVSampleBufferAudioRenderer` + `AVSampleBufferRenderSynchronizer`), one sample buffer per block, start deferred until the first block's deadline (`:292-310`) | same module | same module, **38× more sample buffers per second** |

No AudioToolbox / passthrough path is taken for either: `failed to start passthrough audio output, failing back to linear format` appears for both (VLC tries bitstreaming first, then PCM).

### A.3 tvOS side — what could be read

- **From the app's own log** (VLCKit's session code, `avaudiosession_common.m`): category `AVAudioSessionCategoryPlayback`, mode `AVAudioSessionModeMoviePlayback` (`:214-224`), `setPreferredOutputNumberOfChannels:` to the stream's channel count, then verified against `outputNumberOfChannels` — a mismatch would log `Requested channel count N not fully supported` or `setPreferredOutputNumberOfChannels failed` and fall back to stereo (`:54-67`). Neither line appears in any run; the log's `Output on HDMI, channel count: 8` is printed after that check (`avsamplebuffer.m:454`), so the session granted 8 channels for TrueHD, AC-3 (6) and DTS (8) alike. Sample rate: `setPreferredSampleRate:48000` (`:98`), no failure line.
- **From the runner's own AVAudioSession** (temporary note in the harness, taken at each minute mark while the app played; the app's session is not readable from another process): route `HDMIOutput / "Home Theater"`, port channel descriptors `1…6`, `sampleRate 48000`, `outputNumberOfChannels 8`, `maximumOutputNumberOfChannels 32`, `outputLatency 0.080 s`, identical on all three runs (identical on the TrueHD and DTS runs; during the AC-3 run `outputNumberOfChannels` read 6 and the port listed eight descriptors, i.e. the system output followed the app's preferred count each time — 8 for TrueHD and DTS, 6 for AC-3). tvOS has no output data sources. Note the port lists six channel descriptors while the system output channel count is eight; both are the same for the audible DTS run, so this does not separate the silent case from the audible one.
- Not readable: the app session's actual `outputNumberOfChannels` at the moment of play (only inferable from the absence of the failure lines), the AVR's reaction (what the Denon displays), and whether the eight-channel PCM carries signal.

## B. Judder

### B.5 Per-minute picture counters (from the vout's own lines; VLC's `libvlc_media_player_get_stats` counters are not printed and the app does not read them — §7)

Anchors are the app's stamped `panel opened` / `panel closed` lines produced by the harness once a minute (subtitle panel opened and closed with its "Off" row; no VLC track change: the files have no text track selected). "dropped" = `picture is too late to be displayed` (the vout discards the picture, `src/video_output/video_output.c:1019-1035`), "shown late" = `picture displayed late`; decoder drops = `decoder dropped frame` (`modules/codec/videotoolbox/decoder.c:2133,2153`); displayed ≈ frames in the interval − dropped.

| Interval | WW TrueHD dropped / shown late / decoder dropped | WW AC-3 | Divergent DTS |
|---|---|---|---|
| Playing → min 1 (≈66 s) | 164 / 0 / 0 | 26 + 189 / 0 / 0 (0–11 s on TrueHD, 11–83 s on AC-3) | 0 / 0 / 0 |
| min 1 → 2 (59 s) | 218 / 0 / 0 | 233 / 0 / 0 | 0 / 0 / 0 |
| min 2 → 3 | 232 / 0 / 0 | 224 / 0 / 0 | 0 / 0 / 0 |
| min 3 → 4 | 223 / 0 / 0 | 230 / 0 / 0 | 0 / 0 / 0 |
| min 4 → 5 | 227 / 0 / 0 | 229 / 0 / 0 | 0 / 0 / 0 |
| whole run | **1 081 in 305.6 s = 3.54/s (14.8 % of 7 327 frames)** | **1 147 in 322.6 s = 3.56/s (14.8 % of 7 735)** | **0 in 305.7 s** (7 330 frames) |

Demux read rate: not printed by VLC; every run made its 5 open-time requests and none afterwards, with a single post-open `Buffering` fill (15 `Buffering N%` lines at open, 0 later) — the input delivered the file's bitrate (6.90 MB/s for Wonder Woman, 1.58 MB/s for Divergent) without ever running dry. Output frame rate: both containers declare 41 708 333 ns per frame = 23.976 fps, and that is the frame rate the vout uses for its late threshold (41.7 ms; every dropped picture is 42–53 ms late). VLC logs no display refresh (the `samplebufferdisplay` output hands each picture to `AVSampleBufferDisplayLayer` with a presentation timestamp and does not query the screen), no frame-rate mismatch and no 3:2 cadence; the runner reports `UIScreen.maximumFramesPerSecond = 60`. Whether tvOS's "Match Frame Rate" switches the panel to 24 Hz is a device setting the harness cannot read (§8).

### B.6 — per-file decode facts (headers fetched from the server, `d3/parse-tracks.py`, `d3/parse-sps.py`)

| | Wonder Woman | Divergent |
|---|---|---|
| Muxer | `libmakemkv v1.18.4` (MakeMKV, a disc remux) | `no_variable_data` (an encoder pipeline, not a remux) |
| HEVC profile / tier / level (hvcC and SPS) | Main 10 (profile_idc 2), **High tier**, level 5.1 (153) | Main 10, High tier, level 5.1 |
| Picture | 3840×2160, 4:2:0, 10-bit luma/chroma | 3840×1600, 4:2:0, 10-bit |
| Frame rate (`DefaultDuration`) | 41 708 333 ns = 23.976 fps | 41 708 333 ns = 23.976 fps |
| SPS `max_dec_pic_buffering` / `max_num_reorder_pics` / `max_latency_increase_plus1` | 5 / **3** / 2 | 5 / **2** / 5 |
| Keyframes (Cues, yesterday's parse) | every ~1.0 s (min 0.42, median 1.00, max 1.38) | every ~2.75 s (min 1.0, median 2.75, max 10.0) |
| Bitrate → bits per frame | 55.2 Mbit/s → **2.30 Mbit/frame** (288 kB) | 12.6 Mbit/s → 0.53 Mbit/frame (66 kB) |
| Pixels per frame | 8.29 M | 6.14 M (−26 %) |
| hvcC NAL arrays | VPS, SPS, PPS | VPS, SPS, PPS + a 2 119-byte SEI array (type 39) |
| Matroska `Colour` element | present (byte 8295 of the header) | absent |
| HDR per the server's probe | `hdr: true` | `hdr: true` |
| Decoder on Home Theater (log) | `using decoder device module "videotoolbox"`, `Using Video Toolbox to decode 'hevc'`, `forcing output chroma (kCVPixelFormatType): x420`, `session accepted first frame 1` | identical four lines |
| Output | `samplebufferdisplay`: the decoder's CVPixelBuffer is wrapped without a copy (`VLCSampleBufferDisplay.m:891-951`: `cvpxpic_get_ref` → `CMVideoFormatDescriptionCreateForImageBuffer` → `CMSampleBufferCreateReadyWithImageBuffer` → `enqueueSampleBuffer`, PTS mapped to `CACurrentMediaTime`); `converter` only for non-cvpx pictures | identical |
| Software fallback / restart lines | none (`vt session error`, `restarting vt session`, `decoder dropped frame`, `Raising max DPB`: 0 in every WW log) | none |

### B.7 Differential — Wonder Woman vs Divergent in the video pipeline (shortest list)

Same on both (evidence: identical log lines in `d3-ww-truehd.log`, `d3-ww-ac3.log`, `d3-divergent-dts.log` and yesterday's 8-minute logs): demuxer (`mkv`, now `mkv_trusted`), read-ahead and single HTTP connection, `videotoolbox` decoder device and decoder, `forcing output chroma x420`, `session accepted first frame 1`, no software fallback, no session error, no restart, no decoder-side drop, `samplebufferdisplay` output with a copy-free enqueue, 23.976 fps target, 60 Hz screen, audio as master clock, no clock resets.

What differs, in the order the evidence weighs it:
1. **Bits per frame: 2.30 Mbit vs 0.53 Mbit (4.4×)** — bitrate from the API sizes/durations (`reports/2026-09-14-diag-mkv-stutter.md` §2.1) over the same 23.976 fps. Decode work per frame in a hardware HEVC decoder scales with coded bits as well as pixels.
2. **Pixels per frame: 8.29 M vs 6.14 M (+35 %)** — headers.
3. **Reorder depth: `sps_max_num_reorder_pics` 3 vs 2** (SPS parsed from each file's `hvcC`), with the same `sps_max_dec_pic_buffering` = 5. VLC's VideoToolbox wrapper sizes its picture pacer from these (`decoder.c:875-879`, `pacer.c:107-119`); a deeper reorder means each output picture is released later relative to its decode.
4. **Keyframe every 1.0 s vs every 2.75 s** — Cues; more I-frames per minute on Wonder Woman, each the largest frame of its group.
5. **Origin: MakeMKV disc remux (`libmakemkv v1.18.4`) vs an encoder output (`no_variable_data`)**, and a Matroska `Colour` element only on Wonder Woman; both are flagged HDR by the server.
Not different: level (5.1 High tier), bit depth, chroma, frame rate, container structure (SimpleBlocks, one keyframe per cluster), the audio track in use (the drop rate is the same on TrueHD and AC-3: §B.5).

The drop pattern itself (from yesterday's report, unchanged today): every dropped picture is 42–53 ms late and no picture is ever shown late, i.e. about one picture in seven reaches the vout a frame late in a steady rhythm, not a slowly accumulating lag. That is the signature of a decode/output pipeline running at the edge of real time for this stream — items 1–3 are all of that kind — rather than of the network (no buffering), the audio path (same on every track), or the display (same screen, same output module, Divergent clean).

## 6. What would confirm

- **A1 (block size):** feed the TrueHD decoder output to the renderer in larger blocks and listen — a VLC change (an audio filter that coalesces blocks, or a decoder option); or play a TrueHD file whose decoder emits bigger frames. Not done here (no fix in this pass).
- **A2 (decoded content):** a PCM capture of the decoder output (VLC's `--sout` to a WAV, or the JSON tracer) — both need an app option, so not done; or simply listening with the AVR's input display in view while switching TrueHD ↔ AC-3 (the owner can; the harness cannot hear).
- **B:** VLC's own counters per minute (`libvlc_media_player_get_stats`: displayed / lost pictures, decoded video) logged by the app — a code change; and one of: the same file remuxed to MP4 unchanged (rules the container out), a 4K HEVC stream at Divergent's bitrate but Wonder Woman's pixel count, or the official VLC for tvOS playing the same file on the same box. CPU: Instruments cannot attach to this network-paired Apple TV (§7); a USB-cabled connection or the tvOS `log stream` from a wired Mac would give `videotoolboxd`/app CPU.

## 7. What could not be tested

- Audible output: nothing in the harness hears HDMI.
- The decoder's per-block output (samples, PTS, drops at decoder vs output): VLC 4 sends those to a tracer (`src/audio_output/dec.c:641-647`, `vlc_tracer_TraceEvent … "early_silence"` etc.); no tracer is loaded and loading one is an app option. Block size and PTS spacing are therefore taken from the container, the packetizer and the decoder source (§A.2), and corroborated by the `deferring start` spacing in the log.
- libavcodec's own messages do not reach the file log (VLC maps its verbosity to `av_log_set_level`, `modules/codec/avcodec/avcommon.h:81-102`, but installs no callback into its logger), so a decoder-internal error on TrueHD frames would be invisible here.
- The app's AVAudioSession values at play time (only the absence of VLC's failure lines).
- CPU on the device: `xcrun xctrace record --template 'Activity Monitor' --device <Home Theater>` (both the devicectl and the xctrace identifiers were tried) ends with `Waiting for device to boot … Timed out waiting for device to boot: Home Theater (26.6)`; no trace. `devicectl` has no process-CPU command.
- VLC's picture/stat counters (not logged; app change).
- The display's current refresh rate / Match Frame Rate state (device setting).
- What the Denon displays for the incoming format on each track.

## 8. Questions for the owner

1. When Wonder Woman is silent on TrueHD, what does the Denon's display show for the input (PCM 7.1 / Multi-ch In / nothing)? That single observation separates "no signal" from "signal carrying silence".
2. Is "Match Frame Rate" on in tvOS Settings → Video and Audio? (It changes what 23.976 fps output looks like on both files, not the drop rate, but it matters for what you see.)
3. For A1's confirmation a later pass would need one VLC-side change (coalescing TrueHD blocks before the Apple renderer, or the tracer for one run). Do you want that pass, and if so which first: the tracer (diagnostic only) or the coalescing filter (possible fix)?
4. For B, would you accept an app log line per minute with VLC's displayed/lost counters (asked in the first diagnosis)? Without it the drop counts above rest on the vout's per-picture log lines, which are complete but indirect.
5. Do you have a second UHD-BD-rate HEVC MKV (or can remux Wonder Woman to MP4)? Either would settle whether B is "this stream's bit rate" or "this file".

## 9. Method

1. Harness (Appendix A) in the UITests target, built with `xcodebuild build-for-testing … -destination 'platform=tvOS,name=Home Theater'` (`TEST BUILD SUCCEEDED`; the app product was not rebuilt — its dylib timestamp stayed at today's 09:41:31). Three runs of `xcodebuild test-without-building … -only-testing:"Marlin Media TVUITests/Diag3UITests/<test>"`: Wonder Woman on TrueHD, Wonder Woman switched to AC-3 in the audio panel at +10 s, Divergent on DTS; five minutes each, a screenshot and a runner-side `AVAudioSession` note per minute, the log copied off with `xcrun devicectl device copy from … Library/Caches/marlin-media-tv.log` after each run. A first attempt used the Menu button to close the anchor panel and exited the player at minute 1 (SwiftUI's `onExitCommand` takes Menu while a panel is open, `PlayerScreen.swift:35`); the anchor was changed to the subtitle panel closed by its "Off" row (`[subtitles] off (deselectAllTextTracks)`, a no-op for VLC since no text track is selected) and the runs repeated. The first attempt's 66-second TrueHD log agrees with the full run and is not used.
2. Per-minute counts: the vout lines between the app's stamped `panel opened` anchors (`d3/analyze-d3.py`); audio pipeline lines with a grep over the session (`d3/audio-side.py`); the "wall time between blocks" figure is the difference between successive `deferring start (N us)` deltas, which the output prints once per `play()` call before the start deadline (`avsamplebuffer.m:297`).
3. File facts: each MKV's header (bytes 0 … first cluster) and its Cues fetched from the server with `Range` requests and parsed with three short EBML/H.265 readers (`d3/parse-tracks.py`, `d3/parse-sps.py`, `cues/scan-audio-blocks.py`, all in the session scratchpad; the SPS parser handles `profile_tier_level` and the `sps_max_*` fields and stops before the VUI).
4. Source references are to `~/vlckit-build/VLCKit` (VLCKit 4.0.0-a24 + libvlc master 5dd4aebda + the 17 patches, the tree this app's framework was built from) and its FFmpeg contrib (`contrib/…/ffmpeg/libavcodec`).
5. Instruments: `xcrun xctrace list devices` shows Home Theater; `xcrun xctrace record --template 'Activity Monitor' --device <id> --all-processes --time-limit 15s` was tried once with the devicectl identifier (`No devices found matching`) and once with the identifier xctrace lists (`Waiting for device to boot` → `Timed out waiting for device to boot: Home Theater (26.6)`), device idle, 30 s. No third attempt.
6. Committed evidence: the three session logs (`reports/logs/d3-*.log`) and the overlay strips per minute (`reports/screenshots/d3-*-strip.jpg`); identifiers checked before commit.

## Appendix A — the temporary harness (deleted after the runs; not committed)

```swift
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

final class Diag3UITests: XCTestCase {
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

    /// What this (runner) process can read of the shared output route; the app's own session is not readable from here.
    private func routeNote() -> String {
        let s = AVAudioSession.sharedInstance()
        let outs = s.currentRoute.outputs.map { o -> String in
            let ch = (o.channels ?? []).map { "\($0.channelNumber):\($0.channelName)" }.joined(separator: ",")
            return "\(o.portType.rawValue)/\(o.portName) channels=[\(ch)]"
        }.joined(separator: "; ")
        return "route: \(outs) | sampleRate=\(s.sampleRate) outputChannels=\(s.outputNumberOfChannels) maxOutputChannels=\(s.maximumOutputNumberOfChannels) outputLatency=\(s.outputLatency) runnerCategory=\(s.category.rawValue) screenMaxFPS=\(UIScreen.main.maximumFramesPerSecond)"
    }

    /// Minute anchor: Up (overlay), Up (focus Audio), Right (focus Subtitles), Select (subtitle panel opens →
    /// "[subtitles] panel opened" in the app log), shot, Select on row 0 "Off" (no text track is selected on these
    /// files, so this is a no-op for VLC; it logs "[subtitles] off" and "[player] panel closed"), Down (focus back).
    /// Menu is not used: with a panel open the Menu press is taken by SwiftUI's onExitCommand and exits the player
    /// (seen in attempt 1: "[player] dismiss" instead of "panel closed").
    private func anchor(_ tag: String, _ m: Int) {
        press(.up, wait: 1); press(.up, wait: 1); press(.right, wait: 1); press(.select, wait: 1)
        shot("d3-\(tag)-min\(m)")
        note("\(tag): minute \(m) anchor at \(stamp()) — \(routeNote())")
        press(.select, wait: 1); press(.down, wait: 1)
    }

    private func watch(_ tag: String, minutes: Int = 5) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(stamp()) — \(routeNote())")
        sleep(5); press(.up, wait: 1); shot("d3-\(tag)-start"); press(.down, wait: 1)
        for m in 1...minutes {
            sleep(51)
            anchor(tag, m)
            if !app.otherElements["player"].exists { note("\(tag): player gone at minute \(m)"); break }
        }
        press(.menu, wait: 3)
    }

    /// Wonder Woman on its default (TrueHD 7.1) track, five minutes.
    func a1_WonderWomanTrueHD() { openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); watch("ww-truehd") }

    /// Wonder Woman switched to the AC-3 5.1 track (row 2 of the audio panel) right after start, five minutes.
    func a2_WonderWomanAC3() {
        openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        sleep(5)
        press(.up, wait: 1); press(.up, wait: 1); press(.select, wait: 1)      // audio panel: row 0 = TrueHD (selected)
        XCTAssertTrue(app.staticTexts["AUDIO"].waitForExistence(timeout: 5), "the audio panel did not open; focus \(focusedIds())")
        shot("d3-ww-ac3-panel")
        press(.down, wait: 1); press(.select, wait: 3)                          // row 1 = AC-3 5.1 → "[audio] select audio/3 …", panel closes
        note("ww-ac3: AC-3 selected at \(stamp())")
        press(.down, wait: 1)
        watch("ww-ac3")
    }

    /// Divergent on its DTS 7.1 track, five minutes (the control).
    func a3_DivergentDTS() { openPoster("poster.Divergent", tab: "Movies"); pressPlay(); watch("divergent-dts") }
}
```
