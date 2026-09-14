# Pass 1b: custom VLCKit with TrueHD decoder — 2026-09-13 — STOPPED at step 4

**Result: stopped, nothing built.** VideoLAN's build script cannot run from this repo's path.
`compileAndBuildVLCKit.sh` expands `${ROOT_DIR}` unquoted when it applies its patches, and the
repo lives at `~/Xcode/Marlin Media TV`, so git was handed `/Users/marlin1111/Xcode/Marlin` and
the script exited 20 seconds in. Steps 1–3 are done and validated; steps 5–8 were not reached.
Per the pass rules there was no retry and no workaround; the choice of where to build is the
owner's (open question 1).

Committed locally (recipe, ignore rules, harness change, this report). **Not pushed.**

## What happened (step 4)

`vlckit-build/build.log`, complete:
```
build start: 2026-09-13 22:36:49
command: ./compileAndBuildVLCKit.sh -v -f -t -r  (cwd /Users/marlin1111/Xcode/Marlin Media TV/vlckit-build/VLCKit)
[info] Preparing build dirs
Cloning into 'vlc'...
[info] Applying patches to vlc.git
Switched to a new branch 'localBranch'
branch 'localBranch' set up to track 'origin/master'.
fatal: could not open '/Users/marlin1111/Xcode/Marlin' for reading: No such file or directory
build exit=128 end: 2026-09-13 22:37:09
```
Wall clock: 20 s (22:36:49 → 22:37:09), all of it the libvlc clone. Disk: `vlckit-build/` 488 MB
(the VLCKit clone and the full libvlc master clone at `localBranch` = 5dd4aebda, no patch applied,
no rebase in progress), `Frameworks/` 0 B.

Cause, in VideoLAN's script (`vlckit-build/VLCKit/compileAndBuildVLCKit.sh`):
```
529:            git am ${ROOT_DIR}/libvlc/patches/*.patch        ← unquoted; ROOT_DIR = `pwd` (line 512)
540:            git am ${ROOT_DIR}/libvlc/patches/*.patch        ← same, on the "vlc already cloned" path
```
The shell splits `/Users/marlin1111/Xcode/Marlin Media TV/vlckit-build/VLCKit/libvlc/patches/*.patch`
at the spaces; the first word is what git reported. The same script has further unquoted path
uses that would hit later — `cp $VLCSTATICMODULELIST $PROJECT_DIR/…` (line 330),
`rm -f`/`touch $PROJECT_DIR/…` (342, 343, 374), `lipo $VLCSTATICLIBS` (363, 399) — and below it
sit autotools, make and 55 contrib builds whose behaviour with spaces in the prefix path was not
examined. So a quoting fix to the one line would not be a fix.

This is not the patch set failing: the same 17 patches, with the edited 0007, were applied
cleanly on a throwaway libvlc checkout at 5dd4aebda before the build (step 3 below).

## Files touched, by step

| Step | Files / actions |
|---|---|
| 1 | `.gitignore` (+`vlckit-build/`, `Frameworks/`); folders `vlckit-build/`, `Frameworks/`, `tools/vlckit-truehd/` |
| 2 | `vlckit-build/VLCKit` — shallow clone of https://code.videolan.org/videolan/VLCKit at tag `4.0.0-a24` (commit 6cbc4e7, `TESTEDHASH="5dd4aebda"`); ignored |
| 3 | `vlckit-build/VLCKit/libvlc/patches/0007-…patch` edited (ignored tree); the edit saved as `tools/vlckit-truehd/0007-truehd-enable.diff`; `tools/vlckit-truehd/build.sh`; `tools/vlckit-truehd/README.md` (4 lines) |
| 4 | `vlckit-build/build.log` (kept, ignored); `vlckit-build/build.pid` |
| 5, 6 | not reached |
| 7 | `Marlin Media TVUITests/EvidenceUITests.swift` — test4 reopens the Audio panel after selecting TrueHD and takes `11-audio-panel-truehd-checked` (prepared, never run) |
| 8 | this report; `COLD-START.md` (one paragraph on the stop). D012/D013 **not** added: nothing they would record exists yet |

## Step 3 evidence — the patch edit and its validation

The edit removes exactly the hunk that adds the three mlp disables (the `ifdef HAVE_IOS` block)
and keeps the AudioToolbox AC-3/E-AC-3 hunk; the second hunk's header moves from `+251,7` to
`+245,7` and the diffstat from 7/27 to 1/21 lines (`tools/vlckit-truehd/0007-truehd-enable.diff`).
Validation on a throwaway `git fetch --shallow-since=2026-08-29` checkout of libvlc master at
5dd4aebdabf4a625822036bda08a24a91295158c (in /tmp, deleted afterwards):
```
patches 0001-0006 applied
git apply --check 0007 (edited): OK
0007 applied
patches 0008-0017 applied
patch commits on top: 17
contrib/src/ffmpeg/rules.mak after all 17 patches — lines matching mlp|HAVE_IOS|disable-decoder:
149:ifdef HAVE_IOS                                        (the --enable-pic line, and the watchOS-only whitelist)
154:FFMPEGCONF += --enable-parser='…,mlp,…'               (inside ifdef HAVE_WATCHOS)
250:	$(APPLY) $(SRC)/ffmpeg/avcodec-enable-audiotoolbox-ac3.patch
```
No `--disable-decoder=mlp`, `--disable-demuxer=mlp` or `--disable-parser=mlp` remains for a tvOS
host, and patch 0009 (which also touches these rules) still applies after the change.

## Not tested, and what was traced instead

Everything from the ffmpeg configure onward: the tools bootstrap on this Mac (traced in the build
recon: it builds autoconf, automake, libtool, pkg-config, cmake, nasm, meson, ninja, gettext,
help2man, ant, xz, zstd itself), the 55 contribs, libvlc, the framework archives, the `nm` proof,
the project change, and the device playback. The harness change for step 7 is unexecuted.

## Open questions for the owner

1. **Where should the build live?** The script needs a path without spaces. Options:
   (a) a folder outside the repo, e.g. `~/vlckit-build`, with `tools/vlckit-truehd/build.sh`
   taking that path as a variable and copying the result into `Frameworks/` as now;
   (b) a second diff in `tools/vlckit-truehd/` quoting VideoLAN's script — but the later unquoted
   uses and the contrib/autotools layer make this a guess, not a fix;
   (c) a symlink from a space-free path — not tested; tools that resolve the physical path
   (make, realpath) would still see the spaces.
   Recommendation: (a). The clone already made can be moved rather than re-fetched.
2. Should D013 ("framework out of git at Frameworks/, recipe in tools/vlckit-truehd/, NAS backup
   separate") gain the build location once chosen?

## Least sure of

- Whether option (c) works at all; it was not tried because the rules said no workaround.
- Whether the tools bootstrap accepts Xcode's Python 3.9.6 (the README wants python.org 3.7+;
  the script's PATH lookup for that framework finds nothing on this Mac).
- The time the full build takes: still unmeasured; the only run ended at the clone.

---

# Rerun, build relocated to ~/vlckit-build — 2026-09-13 — STOPPED at step 3 (host tools)

**Result: stopped, nothing built.** With the build moved out of the repo path, VideoLAN's script
got past its patch step, but its host-tools stage (`extras/tools`) could not download two of the
thirteen tool tarballs it needs — `m4-1.4.21.tar.gz` and `gettext-0.26.tar.gz` — and `make`
exited 2 after 9 seconds. The tarballs exist on `ftp.gnu.org`; the two sources the makefile
uses (VideoLAN's contrib mirror, then `ftpmirror.gnu.org`, which redirects to a random public
mirror) both answered 404 tonight. Per the pass rules: no retry, no workaround, no change to
VideoLAN's scripts. Steps 1 and 2 are done; steps 4–7 were not reached.

Committed locally (recipe pointing at ~/vlckit-build, ignore rule, this record). **Not pushed.**

## Step 1 — relocation

`vlckit-build/` was moved with `mv` to `~/vlckit-build` (both clones intact, nothing
re-fetched); the empty folder and its ignore line are gone, `Frameworks/` stays ignored.
`tools/vlckit-truehd/build.sh` now takes `BUILD_DIR` (default `~/vlckit-build`, refuses spaces)
and `REPO`, and ends by copying the result to `$REPO/Frameworks/VLCKit.xcframework`; the README
says so. The stopped run's log was kept as `~/vlckit-build/build.log.stopped-2236`.

## Step 2 — patch check at the new location

```
libvlc clone: 5dd4aebdab macosx: fix favorite albums detail row layout, 0 dirty files, no rebase in progress
git apply --check 0007 (edited) on libvlc @ 5dd4aebdab: OK
```

## Step 3 — the run

`~/vlckit-build/build.log` (363 lines), head and the failure:
```
build start: 2026-09-13 22:42:12
command: ./compileAndBuildVLCKit.sh -v -f -t -r  (cwd /Users/marlin1111/vlckit-build/VLCKit)
[info] Preparing build dirs
[info] Building tools
curl: (22) The requested URL returned error: 404
make: *** [m4-1.4.21.tar.gz] Error 22
make: *** Waiting for unfinished jobs....
curl: (22) The requested URL returned error: 404
make: *** [gettext-0.26.tar.gz] Error 22
…   (pkg-config 0.28-1 finished building and installing in the meantime)
build exit=2 end: 2026-09-13 22:42:21
```
Wall clock: 9 s. The patch step, which the script runs silently on an existing clone
(`git fetch --all; git reset --hard 5dd4aebda; git am`), succeeded before that:
```
libvlc patched at 22:42:19: 9b3e39bbbd doc: add samples_libvlc_downloader        (patch 17 of 17)
base: 5dd4aebdab macosx: fix favorite albums detail row layout
contrib/src/ffmpeg/rules.mak, lines matching mlp|HAVE_IOS|disable-decoder:
  25:	--disable-decoder=opus \
  149:ifdef HAVE_IOS                       (the --enable-pic line; the whitelist below it is ifdef HAVE_WATCHOS)
  154:FFMPEGCONF += --enable-parser='…,mlp,…'
lines 43-48:  ifdef HAVE_DARWIN_OS / FFMPEGCONF += \ / --disable-securetransport / endif / (blank) / ifdef ENABLE_PDB
```
So the applied rules carry no `--disable-decoder=mlp`, `--disable-demuxer=mlp` or
`--disable-parser=mlp`; the ffmpeg contrib was never reached (no `contrib-*/ffmpeg` directory).

Why the downloads failed (`extras/tools/tools.mak` lines 38–39, `packages.mak` lines 1, 4, 22–23, 46–47):
`download_pkg` tries `https://downloads.videolan.org/pub/contrib/<tarball>` and then the
package's own URL under `GNU=https://ftpmirror.gnu.org/gnu`. Read-only HEAD requests tonight:
```
https://ftpmirror.gnu.org/gnu/m4/m4-1.4.21.tar.gz            404  (redirected to ftp.snt.utwente.nl)
https://ftpmirror.gnu.org/gnu/gettext/gettext-0.26.tar.gz    404  (redirected to mirror.clientvps.com)
https://downloads.videolan.org/pub/contrib/m4-1.4.21.tar.gz  404
https://downloads.videolan.org/pub/contrib/gettext-0.26.tar.gz 404
https://ftp.gnu.org/gnu/m4/m4-1.4.21.tar.gz                  200
https://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.gz          200
ftp.gnu.org lists m4-1.4.18 … 1.4.21 and gettext-0.24.2 … 0.26
```
The other eleven tool tarballs did download (ant, autoconf 2.73, automake 1.18.1, bison 3.8.2,
cmake 4.1.2, help2man, libtool 2.6.2, meson 1.12.0, nasm 2.16.03, ninja, pkg-config, xz, zstd —
in `~/vlckit-build/VLCKit/libvlc/vlc/extras/tools/`), and pkg-config was built and installed.

Disk: `~/vlckit-build` 559M; `Frameworks/`   0B.

## Files touched, by step (this rerun)

| Step | Files / actions |
|---|---|
| 1 | `vlckit-build/` → `~/vlckit-build/` (mv); `.gitignore` (ignore line removed, `Frameworks/` kept); `tools/vlckit-truehd/build.sh` (BUILD_DIR/REPO variables, copy to the repo's Frameworks/); `tools/vlckit-truehd/README.md` |
| 2 | check only, nothing written |
| 3 | `~/vlckit-build/build.log` (kept), `~/vlckit-build/build.log.stopped-2236` (the first run's log) |
| 4–6 | not reached |
| 7 | this section; `COLD-START.md` (paragraph updated). D012/D013 still **not** added: nothing to record yet |

## Not tested, and what was traced instead

Everything after the tools stage, as in the first stop: the remaining tool builds, 55 contribs,
libvlc, the framework archives, the `nm` proof, the project change, the device playback. The
harness change for the TrueHD-checked Audio panel screenshot remains unexecuted.

## Open questions for the owner

1. The two missing tarballs are a mirror problem, not a version problem. The tools makefile
   uses any tarball already present in `extras/tools/` (it only downloads what is absent). Is
   placing the two files there from `ftp.gnu.org` (verified 200) acceptable as the way to unblock
   the next run, or would you rather rerun and let `ftpmirror.gnu.org` pick another mirror?
   Both are outside this pass's rules, so neither was done.
2. As before: should D013 record the `~/vlckit-build` location (it is written into the recipe now)?

## Least sure of

- Whether the next mirror `ftpmirror.gnu.org` chooses would have the files; two different
  mirrors were missing them tonight.
- The full build's duration is still unmeasured.

---

# Rerun 2, tool tarballs pre-fetched — 2026-09-13 — STOPPED at step 3 (contribs: meson needs Python 3.10+)

**Result: stopped, nothing built.** With `m4-1.4.21` and `gettext-0.26` pre-fetched (step 0), the
host-tools stage completed in full and the tvOS contrib build began, but every contrib that
builds with meson fails at once: the meson VideoLAN's tools stage installs (1.12.0) refuses to run
on the only Python the build's PATH offers, Xcode's `/usr/bin/python3` 3.9.6. fribidi and
dav1d failed first, `make` stopped, `build.sh` printed `ERROR: Building contribs failed`, exit 1,
7 min 34 s after the start. This was the recon's flagged uncertainty ("whether the tools
bootstrap accepts Xcode's Python 3.9.6"): it builds meson fine and meson then declines to run.
Per the pass rules: no retry, no workaround. The fix is an install or a PATH change, both the
owner's call (open question 1). Steps 0 and 1 are done; steps 4–7 were not reached.

Committed locally (recipe with the pre-fetch step, this record). **Not pushed.**

## Step 0 — the two tarballs

Fetched with the makefile's own URL layout from ftp.gnu.org into libvlc's
`extras/tools/` (`~/vlckit-build/VLCKit/libvlc/vlc/extras/tools/`, where VLC's tools makefile lives):
```
m4-1.4.21.tar.gz: HTTP 200 3558201 bytes
gettext-0.26.tar.gz: HTTP 200 31353014 bytes
shasum -a 512 -c (entries from extras/tools/SHA512SUMS lines 5 and 13):
m4-1.4.21.tar.gz: OK
gettext-0.26.tar.gz: OK
```
`tools/vlckit-truehd/build.sh` gained the pre-fetch-and-verify block; the README a line.

## Step 1 — patch check

```
git apply --check 0007 (edited) vs 5dd4aebda (against the base commit's index; the worktree was still patched from the previous run): OK
```

## Step 3 — the run

`~/vlckit-build/build.log` (35 600 lines). Head, the stage markers, and the failure:
```
build start: 2026-09-13 22:47:12
command: ./compileAndBuildVLCKit.sh -v -f -t -r  (cwd /Users/marlin1111/vlckit-build/VLCKit)
[info] Preparing build dirs
[info] Building tools                                              (all 13 tools built: stamps )
[info] Compiling aarch64 with SDK version 26.5, platform appletvos
Building contribs for arm64
Meson works correctly only with python 3.10+.
You have python 3.9.6 (default, May 22 2026, 11:13:45)
[Clang 21.0.0 (clang-2100.1.1.101)].
Please update your environment
make: *** [.fribidi] Error 1
make: *** Waiting for unfinished jobs....
make: *** [.dav1d] Error 1
ERROR: Building contribs failed
build exit=1 end: 2026-09-13 22:54:46
```
The patch step succeeded again (checked before the tools stage, exactly as in the previous run):
libvlc head at patch 17 on 5dd4aebda, `contrib/src/ffmpeg/rules.mak` lines 43–48 hold only the
`--disable-securetransport` block, no `--disable-*=mlp` anywhere for a tvOS host. ffmpeg 9.0's
tarball was verified and unpacked (`.sum-ffmpeg` stamp, `contrib-arm64-apple-tvOS_11.0/ffmpeg`
directory) but its configure never ran: no ffmpeg configure line is in the log.
Contribs that did complete before make stopped: dvbpsi, gsm, lame, openjpeg, utfcpp, zlib.

Why: VideoLAN's script builds its own PATH (`compileAndBuildVLCKit.sh` line 568) from a
python.org framework install if present (lines 548–553; none on this Mac), its own tools,
and `/usr/bin:/bin:/usr/sbin:/sbin` — Homebrew's `/opt/homebrew/bin/python3.11` is deliberately
not on it (README line 162: "do NOT use homebrew … it will be ignored by VLC's build process").
The meson wrapper the tools stage installs is `python3 …/extras/tools/meson/meson.py "$@"`, and
`meson.py` line 10 exits on `sys.version_info < (3, 10)`. `/usr/bin/python3` is 3.9.6. Eighteen
contribs in this build use meson (ass, dav1d, freetype2, fribidi, harfbuzz, libdsm, libnoidea,
libplacebo, librist, opus, and the disabled bluray/basu/dvdread/dvdnav/dvdcss/glib/microdns/
medialibrary), so the build cannot pass this stage on this Mac as it stands.

Disk: `~/vlckit-build` 3.7G; `Frameworks/` 0 B.

## Files touched, by step (rerun 2)

| Step | Files / actions |
|---|---|
| 0 | `~/vlckit-build/VLCKit/libvlc/vlc/extras/tools/{m4-1.4.21,gettext-0.26}.tar.gz` (outside the repo); `tools/vlckit-truehd/build.sh` (pre-fetch block); `tools/vlckit-truehd/README.md` (one line) |
| 1 | check only |
| 3 | `~/vlckit-build/build.log` (kept), previous logs `build.log.stopped-2236`, `build.log.stopped-2242` |
| 4–6 | not reached |
| 7 | this section; `COLD-START.md` (paragraph updated). D012/D013 still not added |

## Open questions for the owner

1. **Python 3.10+ for the build.** VideoLAN's supported way is the python.org installer
   (creates `/Library/Frameworks/Python.framework`, which the script puts first on its PATH) —
   an install on the Mac, so not done. The alternative is a one-line PATH change in the recipe
   pointing at Homebrew's existing `python3.11` (`/opt/homebrew/bin`), which VideoLAN's README
   says not to do but which needs no install. Which?
2. D013 as before (record `~/vlckit-build`).

## Least sure of

- Whether Homebrew's Python 3.11 would carry the whole build (meson is the only Python
  consumer seen so far; VLC's README warns against it without saying why).
- Whether more contribs fail after the meson ones; make stopped at the first two.
- The full build's duration: 7½ minutes reached the contrib stage with 24 cores; the rest is unmeasured.
