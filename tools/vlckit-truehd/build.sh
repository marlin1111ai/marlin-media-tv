#!/bin/sh
# Marlin Media TV — build VLCKit 4.0.0-a24 for tvOS with the TrueHD/MLP decoder compiled in.
# Pass 1b, 2026-09-13. Run from anywhere. The build lives OUTSIDE the repo because VideoLAN's
# scripts cannot take spaces in paths (the repo is "~/Xcode/Marlin Media TV"):
#   BUILD_DIR   where VLCKit and libvlc are cloned and built (default ~/vlckit-build; no spaces)
#   REPO        the app repo, receives Frameworks/VLCKit.xcframework (git-ignored)
# Log: $BUILD_DIR/build.log. Result: $BUILD_DIR/VLCKit/build/tvOS/VLCKit.xcframework → $REPO/Frameworks/.
set -e
BUILD_DIR="${BUILD_DIR:-$HOME/vlckit-build}"
REPO="${REPO:-$HOME/Xcode/Marlin Media TV}"
case "$BUILD_DIR" in *" "*) echo "BUILD_DIR must not contain spaces: $BUILD_DIR" >&2; exit 1;; esac

# Step 1/2 — VLCKit source at the tag the app used as a Swift package.
mkdir -p "$BUILD_DIR" "$REPO/Frameworks"
cd "$BUILD_DIR"
[ -d VLCKit ] || git clone --depth 1 --branch 4.0.0-a24 https://code.videolan.org/videolan/VLCKit.git VLCKit
cd VLCKit

# Step 2 — drop the hunk of VLCKit's patch 0007 that disables ffmpeg's mlp decoder/demuxer/parser
# (its commit message: "to be in compliance with the App Store ToS"). The AudioToolbox AC-3 part stays.
# Idempotent: skipped when the diff is already applied.
if git apply --check "$REPO/tools/vlckit-truehd/0007-truehd-enable.diff" 2>/dev/null; then
    git apply "$REPO/tools/vlckit-truehd/0007-truehd-enable.diff"
elif git apply --check --reverse "$REPO/tools/vlckit-truehd/0007-truehd-enable.diff" 2>/dev/null; then
    echo "patch 0007 already edited"
else
    echo "0007-truehd-enable.diff neither applies nor is applied — stop" >&2; exit 1
fi

# Step 3 — VideoLAN's own build: clones libvlc master at the pinned hash (TESTEDHASH in the script),
# applies the 17 patches, builds host tools under extras/tools, the contribs, libvlc, then the framework.
# -v verbose, -f device + simulator + xcframework, -t tvOS, -r Release.
echo "build start: $(date '+%Y-%m-%d %H:%M:%S')" | tee "$BUILD_DIR/build.log"
./compileAndBuildVLCKit.sh -v -f -t -r >> "$BUILD_DIR/build.log" 2>&1
echo "build end:   $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$BUILD_DIR/build.log"

# Step 4 — the proof: the decoder symbols in the tvOS device slice.
nm build/tvOS/VLCKit.xcframework/tvos-arm64/VLCKit.framework/VLCKit | grep -E 'ff_(mlp|truehd)_(decoder|parser)$'

# Step 5 — hand the result to the app.
rm -rf "$REPO/Frameworks/VLCKit.xcframework"
cp -R build/tvOS/VLCKit.xcframework "$REPO/Frameworks/VLCKit.xcframework"
echo "done: $REPO/Frameworks/VLCKit.xcframework"
