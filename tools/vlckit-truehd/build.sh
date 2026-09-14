#!/bin/sh
# Marlin Media TV — build VLCKit 4.0.0-a24 for tvOS with the TrueHD/MLP decoder compiled in.
# Pass 1b, 2026-09-13. Run from the repo root. Result: vlckit-build/VLCKit/build/tvOS/VLCKit.xcframework,
# then copied to Frameworks/VLCKit.xcframework (both folders are git-ignored). Log: vlckit-build/build.log.
set -e
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"

# Step 2 — VLCKit source at the tag the app used as a Swift package.
mkdir -p vlckit-build Frameworks
[ -d vlckit-build/VLCKit ] || git clone --depth 1 --branch 4.0.0-a24 https://code.videolan.org/videolan/VLCKit.git vlckit-build/VLCKit

# Step 3 — drop the hunk of VLCKit's patch 0007 that disables ffmpeg's mlp decoder/demuxer/parser
# (its commit message: "to be in compliance with the App Store ToS"). The AudioToolbox AC-3 part stays.
cd vlckit-build/VLCKit
git apply --check "$ROOT/tools/vlckit-truehd/0007-truehd-enable.diff" && git apply "$ROOT/tools/vlckit-truehd/0007-truehd-enable.diff"

# Step 4 — VideoLAN's own build: clones libvlc master at the pinned hash (TESTEDHASH in the script),
# applies the 17 patches, builds host tools under extras/tools, the contribs, libvlc, then the framework.
# -v verbose, -f device + simulator + xcframework, -t tvOS, -r Release.
echo "build start: $(date '+%Y-%m-%d %H:%M:%S')" | tee "$ROOT/vlckit-build/build.log"
./compileAndBuildVLCKit.sh -v -f -t -r >> "$ROOT/vlckit-build/build.log" 2>&1
echo "build end:   $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$ROOT/vlckit-build/build.log"

# Step 5 — the proof: the decoder symbols in the tvOS device slice.
nm build/tvOS/VLCKit.xcframework/tvos-arm64/VLCKit.framework/VLCKit | grep -E 'ff_(mlp|truehd)_(decoder|parser)$'

# Step 6 — hand the result to the app.
rm -rf "$ROOT/Frameworks/VLCKit.xcframework"
cp -R build/tvOS/VLCKit.xcframework "$ROOT/Frameworks/VLCKit.xcframework"
echo "done: $ROOT/Frameworks/VLCKit.xcframework"
