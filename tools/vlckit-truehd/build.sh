#!/bin/sh
# Marlin Media TV — build VLCKit 4.0.0-a24 for tvOS with the TrueHD/MLP decoder compiled in.
# Pass 1b, 2026-09-13. Run from anywhere. The build lives OUTSIDE the repo because VideoLAN's
# scripts cannot take spaces in paths (the repo is "~/Xcode/Marlin Media TV"):
#   BUILD_DIR   where VLCKit and libvlc are cloned and built (default ~/vlckit-build; no spaces)
#   REPO        the app repo, receives Frameworks/VLCKit.xcframework (git-ignored)
#   PACKAGE_ONLY=1  package the libvlc slices already built in BUILD_DIR: no clone, no patching, no host tools,
#               no contrib/libvlc compile (VideoLAN's script with -n -l); step 2d still runs. Default: full build.
# Log: $BUILD_DIR/build.log. Result: $BUILD_DIR/VLCKit/build/tvOS/VLCKit.xcframework → $REPO/Frameworks/.
set -e
BUILD_DIR="${BUILD_DIR:-$HOME/vlckit-build}"
REPO="${REPO:-$HOME/Xcode/Marlin Media TV}"
case "$BUILD_DIR" in *" "*) echo "BUILD_DIR must not contain spaces: $BUILD_DIR" >&2; exit 1;; esac
ls -d /Library/Frameworks/Python.framework/Versions/3.[1-9][0-9]/bin >/dev/null 2>&1 || { echo "needs python.org Python 3.10+ installed at /Library/Frameworks/Python.framework (VideoLAN's script looks only there; meson refuses Xcode's 3.9.6)" >&2; exit 1; }

# Step 1/2 — VLCKit source at the tag the app used as a Swift package.
mkdir -p "$BUILD_DIR" "$REPO/Frameworks"
cd "$BUILD_DIR"
if [ "$PACKAGE_ONLY" = "1" ]; then
    # pass 1e rerun 4 (D018): reuse what a previous full run built; stop if any of it is missing.
    [ -d VLCKit/libvlc/vlc ] || { echo "PACKAGE_ONLY=1 needs an existing $BUILD_DIR/VLCKit/libvlc/vlc" >&2; exit 1; }
    for slice in build-appletvos-arm64 build-appletvsimulator-arm64 build-appletvsimulator-x86_64; do
        [ -f "VLCKit/libvlc/vlc/$slice/static-lib/libvlc-full-static.a" ] || { echo "PACKAGE_ONLY=1: missing $slice/static-lib/libvlc-full-static.a" >&2; exit 1; }
    done
    echo "PACKAGE_ONLY=1: packaging the existing libvlc slices (no clone, patches, host tools or compile)"
else
[ -d VLCKit ] || git clone --depth 1 --branch 4.0.0-a24 https://code.videolan.org/videolan/VLCKit.git VLCKit
fi
cd VLCKit

if [ "$PACKAGE_ONLY" != "1" ]; then
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

# Step 0 (rerun 2) — two host-tool tarballs are pre-fetched from ftp.gnu.org because the GNU mirror
# network and VideoLAN's contrib mirror don't reliably carry them; VLC's extras/tools only downloads
# what is absent and its SHA512SUMS is the check. Same paths the makefile uses ($(GNU)/m4, $(GNU)/gettext).
TOOLS="$BUILD_DIR/VLCKit/libvlc/vlc/extras/tools"
if [ -d "$TOOLS" ]; then
    for f in m4/m4-1.4.21.tar.gz gettext/gettext-0.26.tar.gz; do
        b=$(basename "$f")
        [ -f "$TOOLS/$b" ] || curl -f -sS -L --retry 3 --output "$TOOLS/$b" "https://ftp.gnu.org/gnu/$f"
        (cd "$TOOLS" && grep -E " $b\$" SHA512SUMS | shasum -a 512 -c -) || { echo "checksum failed for $b" >&2; exit 1; }
    done
fi

# Step 0 (rerun 4) — GNU make 4.4.1 local to the build directory, put on VLC_PATH (VideoLAN's own hook,
# compileAndBuildVLCKit.sh line 568: PATH puts $VLC_PATH ahead of /usr/bin). Xcode's make 3.81 breaks
# the jobserver with the ninja VLC's tools build. Tarball from ftp.gnu.org, MD5 from GNU's release
# announcement (info-gnu 2023-02 msg00011). Nothing is installed on the system.
if [ ! -x "$BUILD_DIR/tools/bin/make" ]; then
    mkdir -p "$BUILD_DIR/tools/src" && cd "$BUILD_DIR/tools/src"
    [ -f make-4.4.1.tar.gz ] || curl -f -sS -L --retry 3 -o make-4.4.1.tar.gz https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz
    [ "$(md5 -q make-4.4.1.tar.gz)" = "c8469a3713cbbe04d955d4ae4be23eeb" ] || { echo "make-4.4.1.tar.gz: MD5 mismatch" >&2; exit 1; }
    rm -rf make-4.4.1 && tar xzf make-4.4.1.tar.gz && cd make-4.4.1 && ./configure --prefix="$BUILD_DIR/tools" && /usr/bin/make -j8 && /usr/bin/make install
    cd "$BUILD_DIR/VLCKit"
fi
"$BUILD_DIR/tools/bin/make" --version | head -1
export VLC_PATH="$BUILD_DIR/tools/bin"

# Step 2b — pass 1d (D015): install the TrueHD/MLP block-coalescing patch as VLCKit patch 0018 so that
# compileAndBuildVLCKit.sh applies it with the other seventeen (it resets libvlc to TESTEDHASH and re-applies
# libvlc/patches/*.patch on every run). Idempotent copy.
cp "$REPO/tools/vlckit-truehd/0018-avcodec-audio-coalesce-TrueHD-MLP-frames.patch" "$BUILD_DIR/VLCKit/libvlc/patches/"
echo "patch 0018 installed"

# Step 2c — pass 1e (D017): the VideoToolbox DPB fix as VLCKit patch 0019, applied by git am after 0018. Kept in the
# repo as a .diff (git format-patch output); VideoLAN's script only picks up libvlc/patches/*.patch. Idempotent copy.
cp "$REPO/tools/vlckit-truehd/0019-videotoolbox-dpb-no-latency-bump-ahead-of-arriving-picture.diff" \
   "$BUILD_DIR/VLCKit/libvlc/patches/0019-videotoolbox-dpb-no-latency-bump-ahead-of-arriving-picture.patch"
echo "patch 0019 installed"
fi # PACKAGE_ONLY

# Step 2d — pass 1e rerun 3 (D018): Xcode 27 refuses to archive VLCKit.xcodeproj with its tvOS deployment target 11.0
# ("supported deployment target versions is 15.0 to 27.0.x"); VideoLAN's archive call overrides only the iOS target.
# Set the project's TVOS_DEPLOYMENT_TARGET to 26.0 (the app's minimum, D004) before the build. libvlc's own minimum
# (extras/package/apple/build.conf) is left as is. Idempotent; stops if any other tvOS target value remains.
PBX="$BUILD_DIR/VLCKit/VLCKit.xcodeproj/project.pbxproj"
sed -i '' 's/TVOS_DEPLOYMENT_TARGET = 11\.0;/TVOS_DEPLOYMENT_TARGET = 26.0;/' "$PBX"
[ "$(grep -c 'TVOS_DEPLOYMENT_TARGET = ' "$PBX")" = "$(grep -c 'TVOS_DEPLOYMENT_TARGET = 26\.0;' "$PBX")" ] || { echo "VLCKit.xcodeproj: a TVOS_DEPLOYMENT_TARGET other than 26.0 remains" >&2; exit 1; }
echo "VLCKit.xcodeproj TVOS_DEPLOYMENT_TARGET = 26.0 ($(grep -c 'TVOS_DEPLOYMENT_TARGET = 26\.0;' "$PBX") build configurations)"

# Step 3 — VideoLAN's own build: clones libvlc master at the pinned hash (TESTEDHASH in the script),
# applies the 17 patches, builds host tools under extras/tools, the contribs, libvlc, then the framework.
# -v verbose, -f device + simulator + xcframework, -t tvOS, -r Release.
echo "build start: $(date '+%Y-%m-%d %H:%M:%S')" | tee "$BUILD_DIR/build.log"
if [ "$PACKAGE_ONLY" = "1" ]; then
    # -n: no fetch / reset / git am of libvlc; -l: no host tools and no buildLibVLC — the existing
    # build-appletv*/static-lib/libvlc-full-static.a are lipo'd and archived as they are.
    ./compileAndBuildVLCKit.sh -v -f -t -r -n -l >> "$BUILD_DIR/build.log" 2>&1
else
    ./compileAndBuildVLCKit.sh -v -f -t -r >> "$BUILD_DIR/build.log" 2>&1
fi
echo "build end:   $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$BUILD_DIR/build.log"

# Step 4 — the proof: the decoder symbols in the tvOS device slice.
nm build/tvOS/VLCKit.xcframework/tvos-arm64/VLCKit.framework/VLCKit | grep -E 'ff_(mlp|truehd)_(decoder|parser)$'

# Step 5 — hand the result to the app.
rm -rf "$REPO/Frameworks/VLCKit.xcframework"
cp -R build/tvOS/VLCKit.xcframework "$REPO/Frameworks/VLCKit.xcframework"
echo "done: $REPO/Frameworks/VLCKit.xcframework"
