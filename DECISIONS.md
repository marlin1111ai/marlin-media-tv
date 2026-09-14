# Marlin Media TV — decisions

The standing calls for the tvOS client. Newest at the bottom. Each carries its date; a
superseded decision stays in place with a note. The server's own decisions live in
marlin1111ai/marlin-media (DECISIONS.md there) and are referenced by their numbers.

## 2026-09-13 — pass 1

- **D001** own repo marlin1111ai/marlin-media-tv, folder ~/Xcode/Marlin Media TV, notebook at root — supersedes marlin-media D007/D010.
- **D002** Claude Code runs on the Mac.
- **D003** VLCKit via VideoLAN SPM 4.0.0-a24; fallback if the alpha fails is CocoaPods 3.7.3.
- **D004** minimum tvOS 26.0.
- **D005** dev/test device is Home Theater.
- **D006** all UI from Claude Design exports (carries marlin-media D009).
- **D007** server address fixed, no settings screen.
- **D008** skips −10 s / +30 s while playing; frame step on click while paused, forward exact, back approximate (carries marlin-media D005).
- **D009** resume/watched state and Recently Added are in — server request sent 2026-09-13, client wires them once served.
- **D010** sort control: Title, Year, Recently Added.
- **D011** device-proof: VLCKit logs + device screenshot from builder, HDR indicator and Denon panel from owner.
- **D012** custom VLCKit build with the TrueHD decoder compiled in — supersedes playing a TrueHD title on its AC-3 core. Reason: 7.1 PCM to the Denon. VLCKit 4.0.0-a24 from VideoLAN's own scripts, one change: the hunk of VLCKit's patch 0007 that disables ffmpeg's mlp decoder/demuxer/parser is removed (`tools/vlckit-truehd/0007-truehd-enable.diff`).
- **D013** the built framework stays out of git at `Frameworks/VLCKit.xcframework` (ignored; 716 MB); it is built at `~/vlckit-build` because VideoLAN's scripts cannot take spaces in paths, with a local GNU make 4.4.1 (`~/vlckit-build/tools`, passed as `VLC_PATH`) and python.org Python 3.14.7; recipe in `tools/vlckit-truehd/`; NAS backup of the framework is separate and the owner's.

## 2026-09-14 — pass 1c

- **D014** trusted Matroska cues on seek: the player adds the media option `:demux=mkv_trusted` to every `.mkv` stream (`PlayerModel.swift`, `attach(drawable:)`) and nothing else. Reason: the HTTP access is not fast-seekable, so VLC's default `mkv` demuxer files the file's Cues as untrusted and never verifies them; every forward seek then prerolls from the last keyframe it has read (Divergent, Wonder Woman) or from the first cluster (Stargate, whose MPEG-2 sits in BlockGroups) — 8–51 s of frozen picture after ten +30 s skips (`reports/2026-09-14-diag2-seek.md`). `mkv_trusted` is the same demuxer with `trust_cues = true`, so a seek lands on the cue before the target: 0.09–0.55 s to picture in the same runs (`reports/2026-09-14-pass1c-mkv-seek.md`). MKV only, decided by the server path's `.mkv` suffix; the MP4 path is untouched.

## 2026-09-14 — pass 1d

- **D015** TrueHD/MLP block coalescing in VLCKit: `tools/vlckit-truehd/0018-avcodec-audio-coalesce-TrueHD-MLP-frames.patch` (a libvlc patch in VLCKit's own patch format, installed by `build.sh`) makes `modules/codec/avcodec/audio.c` gather the decoder's 40-sample TrueHD/MLP frames into ~20 ms blocks (960 samples at 48 kHz; whole frames, PTS of the first, summed length) before `decoder_QueueAudio`, gated on `AV_CODEC_ID_TRUEHD` / `AV_CODEC_ID_MLP`; DTS, AC-3, AAC and every other codec are untouched. Where: the decoder module is the narrowest codec-specific point — the packetizer must stay one access unit per block for FFmpeg, and the Apple output makes one CMSampleBuffer per block for every codec. Why: with 40-sample blocks the tvOS renderer received 1 200 sample buffers per second and the track was silent while the Denon read "Multi In" (`reports/2026-09-14-diag3-wonder-woman.md` §A); with the change VLC's counter shows 50 buffers per second and no anomaly line (`reports/2026-09-14-pass1d-truehd-audio-and-framerate.md` §1). Audibility remains the owner's check.
- **D016** the app asks tvOS to match the display to the stream: `PlayerModel.swift` parses the stream with `VLCMediaParser` before play (the server reports no frame rate; the parser timeout is in microseconds), builds `AVDisplayCriteria(refreshRate:formatDescription:)` from the video track's frame rate and size and from the server's `hdr` flag (PQ / BT.2020 extensions for HDR10, BT.709 for SDR), sets `UIWindow.avDisplayManager.preferredDisplayCriteria` before `play()` — or, when VLC's Matroska parse carries no frame rate, from the player's own video track about 0.1 s after `play()` — logs the display state before/after and on tvOS's mode-switch notifications, and clears the criteria in `dismiss()`. Home Theater has Match Frame Rate and Match Dynamic Range on; tvOS switched to 24 Hz for the 23.976 fps files and reported 2.9 s switches for the 29.97 fps ones. The switch does not change Wonder Woman's picture-drop rate (pass 1d §2).
- Defect closed (no decision): Menu with a track panel open now closes the panel — `PlayerScreen.swift` routes `onExitCommand` through `PlayerModel.handle(.menu)`; Menu with no panel exits as before (pass 1d §3).
