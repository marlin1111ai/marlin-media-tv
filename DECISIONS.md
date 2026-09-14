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
