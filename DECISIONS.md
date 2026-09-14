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
