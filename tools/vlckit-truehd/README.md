# VLCKit with TrueHD — the recipe

VLCKit 4.0.0-a24 for tvOS, rebuilt from VideoLAN's own scripts with one change: `0007-truehd-enable.diff` removes the hunk of VLCKit's patch 0007 that switches off ffmpeg's MLP/TrueHD decoder, so Wonder Woman's TrueHD 7.1 track decodes to 7.1 PCM (DECISIONS.md D012).
Rerun: `tools/vlckit-truehd/build.sh` from the repo root (network: libvlc clone, host-tool and contrib tarballs; hours, not minutes). It writes `vlckit-build/build.log` and leaves the result at `Frameworks/VLCKit.xcframework`, which the Xcode project links by path (D013). Neither folder is in git.
