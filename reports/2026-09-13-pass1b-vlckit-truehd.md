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

---

# Rerun 3, python.org Python 3.14.7 installed — 2026-09-13 — STOPPED at step 3 (make jobserver)

**Result: stopped, nothing built.** Python fixed the meson stage: the meson-based contribs
(dav1d, fribidi, freetype2, glslang, rnnoise, librist, libnoidea and more) now build. The run then
lost five contribs — vpx, twolame, speex, modplug, libtasn1 — to GNU make's job pipe, not to any
compiler error (the log has none): Xcode's make 3.81 aborted six times with
`read jobs pipe: Resource temporarily unavailable`, and the jobserver-aware ninja that VLC's tools
stage installs failed twenty times with `Could not initialize jobserver: Invalid file descriptors`.
`build.sh` printed `ERROR: Building contribs failed`, exit 1, 48 s after the start. Per the pass
rules: no retry, no workaround, no change to VideoLAN's scripts. Steps 0 and 1 are done; 4–7 not reached.

Committed locally (this record). **Not pushed.**

## Step 0 — Python

```
/Library/Frameworks/Python.framework/Versions/: 3.14, Current -> 3.14
/Library/Frameworks/Python.framework/Versions/3.14/bin/python3 --version: Python 3.14.7
compileAndBuildVLCKit.sh 549: PYTHON3_PATH=$(echo /Library/Frameworks/Python.framework/Versions/3.*/bin | awk '{print $1;}')
  → resolves to /Library/Frameworks/Python.framework/Versions/3.14/bin, placed first on PATH at line 568
```

## Step 1 — patch check

`git apply --check` of the edited 0007 against the base commit's index: OK (worktree at patch 17, clean).

## Step 3 — the run

`~/vlckit-build/build.log`, head, the stage markers and the failure:
```
build start: 2026-09-13 23:03:55
[info] Preparing build dirs
[info] Building tools                                   (all present from rerun 2; nothing rebuilt)
[info] Compiling aarch64 with SDK version 26.5, platform appletvos
Building contribs for arm64
make: *** read jobs pipe: Resource temporarily unavailable.  Stop.      (line 1152, during 'env cmake --build png/vlc_build')
ninja: warning: Jobserver 'pipe' mode detected, a pool that implements 'fifo' mode would be more reliable!
ninja: error: Could not initialize jobserver: Invalid file descriptors    (20 times, under cmake --build / meson compile)
make: *** [.vpx] Error 2
make: *** [.twolame] Error 2
make: *** [.speex] Error 2
make: *** [.modplug] Error 2
make: *** [.libtasn1] Error 2
ERROR: Building contribs failed
build exit=1 end: 2026-09-13 23:04:43
```
The patch step succeeded (checked at 23:04:03, before ffmpeg configured): libvlc head at patch 17
on 5dd4aebda; `contrib/src/ffmpeg/rules.mak` lines 43–48 hold only `--disable-securetransport`;
no `--disable-*=mlp`. ffmpeg's configure still did not run (make stopped first).
Compiler errors in the log: 0. Contribs completed before the stop (stamps): dav1d, dvbpsi,
freetype2, fribidi, glslang, gpg-error, gsm, jpeg, lame, libebur128, libnoidea, librist, libxml2,
markupsafe, mpg123, mysofa, nfs, ogg, openapv, openjpeg, opus, png, rnnoise, smb2, speexdsp,
taglib, upnp, utfcpp, vulkan-headers, zlib.

Why. The build's PATH holds only Xcode's `/usr/bin/make` (GNU Make 3.81), and both scripts run
it with `-j24`/`-j25` (`compileAndBuildVLCKit.sh` lines 29–31, 219; `build.sh` lines 89–90, 574),
so make hands a jobserver pipe to every sub-build. VLC's tools bootstrap knows this pairing is
fragile: `extras/tools/bootstrap` lines 217–245 say "with GNU make 4.4 we should use ninja 1.13.x
and above, otherwise we must use the patched version from kitware", and on make 3.81 it built
that patched ninja (`ninja --version` → `1.13.2.git.kitware.jobserver-pipe-1`). In this run the
pairing failed: ninja could not use the pipe, and make's own reads on it returned EAGAIN. The
failures began only once meson/ninja builds were running alongside the autotools ones (first
`meson compile` at log line 1014, first pipe error at 1152), which is why rerun 2 — where every
meson build died at setup — never reached this. VideoLAN's CI does not build on Xcode's make:
`.gitlab-ci.yml` line 6 sets `VLC_PATH: /Users/videolanci/sandbox/bin`, a directory of extra host
tools that `compileAndBuildVLCKit.sh` line 568 puts on the build PATH ahead of `/usr/bin`.
`extras/tools` does not build GNU make itself, and no GNU make 4.x exists on this Mac
(`/opt/homebrew/bin/gmake` absent).

Disk: `~/vlckit-build` 4.3G; `Frameworks/` 0 B.

## Files touched, by step (rerun 3)

| Step | Files / actions |
|---|---|
| 0, 1 | checks only |
| 3 | `~/vlckit-build/build.log` (kept); previous logs `build.log.stopped-2236`, `-2242`, `-2247` |
| 4–6 | not reached |
| 7 | this section; `COLD-START.md` (paragraph updated). D012/D013 still not added |

## Open questions for the owner

1. **A GNU make 4.4+ for the build.** VideoLAN's own hook is `VLC_PATH`: a directory of extra
   tools placed on the build PATH. Options: (a) build GNU make 4.4.x from ftp.gnu.org into
   `~/vlckit-build/tools/bin` (a local build inside the build directory, nothing on the system) and
   run with `VLC_PATH=~/vlckit-build/tools/bin`; (b) `brew install make` and point `VLC_PATH` at
   Homebrew's gnubin (an install). Either is outside this pass's rules, so neither was done.
   With make 4.4+ the tools bootstrap switches to the standard ninja path (bootstrap lines
   230–232); whether it accepts the Kitware ninja already built, or rebuilds, was not traced.
2. Alternatively run the script with `MAKEFLAGS=-j1` (no jobserver at all): serial contribs, an
   unknown but long build time, and a change to the exact command. Not recommended over 1(a).
3. D013 as before (record `~/vlckit-build`).

## Least sure of

- That GNU make 4.4+ alone clears the jobserver failures; VLC's own comment implies it, and
  ninja's warning names the fifo jobserver that 4.4 introduced, but it was not tried.
- Whether further contribs fail after these five; make stopped at the first batch.
- The full build's duration.

---

# Rerun 4, GNU make 4.4.1 on VLC_PATH — 2026-09-13 — DONE

**Result: built, installed and proven on Home Theater.** The custom VLCKit decodes Wonder Woman's
TrueHD track (`codec (truehd) started`, no "not supported") and hands tvOS 8-channel 48 kHz float
PCM over HDMI; VLC now selects that track by itself at start. Divergent (DTS) and Stargate (AC-3)
play with the same decoder and output fields as in pass 1. The app links
`Frameworks/VLCKit.xcframework` by path; the VideoLAN Swift package is removed.

Committed locally. **Not pushed** — the owner tests first.

## Step 0 — a GNU make local to the build directory

```
ftp.gnu.org/gnu/make/: latest 4.x = make-4.4.1.tar.gz (+ .sig); no gpg on this Mac, so the checksum
GNU published in the release announcement was used (info-gnu, Feb 2023, msg00011 "GNU Make 4.4.1 released!"):
  published MD5: c8469a3713cbbe04d955d4ae4be23eeb  make-4.4.1.tar.gz
  computed  MD5: c8469a3713cbbe04d955d4ae4be23eeb   → MATCH
./configure --prefix=~/vlckit-build/tools && make -j8 && make install   (configure/make/install exit 0)
~/vlckit-build/tools/bin/make --version → GNU Make 4.4.1, Built for aarch64-apple-darwin25.6.0
compileAndBuildVLCKit.sh 568: export PATH="${PYTHON3_PATH}:${VLCROOT}/extras/tools/build/bin:${VLCROOT}/contrib/${TARGET}/bin:$VLC_PATH:/usr/bin:/bin:/usr/sbin:/sbin"
```
`tools/vlckit-truehd/build.sh` builds it when absent and exports `VLC_PATH`; the README says why.
Nothing was installed on the system (the tarball, source and binary are all under `~/vlckit-build/tools`).

## Step 1 — patch check

`git apply --check` of the edited 0007 against the base commit's index: OK.

## Step 3 — the build

```
build start: 2026-09-13 23:12:25
command: VLC_PATH=/Users/marlin1111/vlckit-build/tools/bin ./compileAndBuildVLCKit.sh -v -f -t -r
make on VLC_PATH: GNU Make 4.4.1
[info] Building tools · Compiling aarch64 (appletvos) · Building contribs for arm64 · Building VLC for arm64 · Build succeeded!
[info] Compiling x86_64 (appletvsimulator) … Build succeeded! · Compiling aarch64 (appletvsimulator) … Build succeeded!
[info] building simulator static lib for appletv · building device static lib for appletv · all done
[info] Building VLCKit.xcframework for tvOS · Building VLCKit (Release, appletvos) · Building VLCKit (Release, appletvsimulator)
[info] Build of VLCKit.xcframework for tvOS completed
build exit=0 end: 2026-09-13 23:21:38
```
Wall clock 9 min 13 s for this run (the host tools were already built by rerun 2, which spent
7 min 34 s mostly on them; rerun 3 added 48 s). Jobserver errors this run: 0.

Rules check, taken at 23:12:33 after the script had reset and re-patched libvlc and before ffmpeg
configured: libvlc head at patch 17 on 5dd4aebda; `contrib/src/ffmpeg/rules.mak` lines 43–48
hold only `--disable-securetransport`; the only `mlp` left in the file is inside the watchOS-only
whitelist. ffmpeg's configure as it actually ran (build.log line 153, compiler and flag
arguments elided):
```
cd ffmpeg/vlc_build && CC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" CXX="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++" OBJC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" OBJCXX="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/cla
```
It carries `--disable-decoder=opus` and no mlp entry.

## Step 4 — nm proof

```
$ nm ~/vlckit-build/VLCKit/build/tvOS/VLCKit.xcframework/tvos-arm64/VLCKit.framework/VLCKit | grep -E ' _ff_(mlp|truehd)_(decoder|parser)$'
0000000002344b90 S _ff_mlp_decoder
0000000002344b58 S _ff_mlp_parser
0000000002344c40 S _ff_truehd_decoder
```
(the simulator slice has the same three; the a24 package binary had none — TrueHD symbol recon).
The xcframework: `tvos-arm64` + `tvos-arm64_x86_64-simulator`, 716 MB with debug symbols.

## Step 5 — the app

`Frameworks/VLCKit.xcframework` is the copy (ignored). `project.pbxproj`: the
`XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency` sections, `packageReferences` and
`packageProductDependencies` are removed; a `PBXFileReference` (`wrapper.xcframework`, path
`Frameworks/VLCKit.xcframework`) in a `Frameworks` group is linked in the Frameworks phase and
embedded by a new "Embed Frameworks" copy phase with `CodeSignOnCopy, RemoveHeadersOnCopy`;
`Package.resolved` deleted. Nothing else in the project changed (diff: 53 lines in the pbxproj).

## Step 6 — device build and proof

```
$ xcodebuild build-for-testing … -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates
ProcessXCFramework Frameworks/VLCKit.xcframework → build/DerivedData/Build/Products/Debug-appletvos/VLCKit.framework
CodeSign …/Marlin Media TV.app/Frameworks/VLCKit.framework · CodeSign …/Marlin Media TV.app · Validate …/Marlin Media TV.app
** TEST BUILD SUCCEEDED **
embedded Marlin Media TV.app/Frameworks/VLCKit.framework/VLCKit: _ff_mlp_decoder, _ff_mlp_parser, _ff_truehd_decoder present; TeamIdentifier=C879JNVK7Z
```
Harness runs on Home Theater (all passed): test4_WonderWoman 121.9 s, test2_Divergent 54.6 s,
test3_Stargate 99.9 s. Screenshots `reports/screenshots/1b-*.jpg`, logs `reports/logs/1b-*.log`.

**Wonder Woman, TrueHD** (`1b-wonder-woman-truehd-vlckit.log`, line numbers):
```
 10  [player] request Wonder Woman — Wonder Woman (2017).mkv · 4K HDR · TrueHD 7.1 — http://192.168.1.250:8093/stream/4
449  [DBG] ES track added: 'audio/2' (fourcc: 'mlpa')
491  [DBG] using audio packetizer module "mlp"
499  [DBG] codec (truehd) started
500  [DBG] using audio decoder module "avcodec"
501  [DBG] ES track selected: 'audio/2' (fourcc: 'mlpa')          ← VLC's own default choice now
517  [WARN] failed to start passthrough audio output, failing back to linear format
557  [DBG] Output on HDMI, channel count: 8
560  [DBG] output 'f32l' 48000 Hz 3F2M2R/LFE frame=1 samples/32 bytes
565  [DBG] format: 48000 rate, 8 nch, 4 bps, fl32
2445 [audio] panel opened: audio/2 English TrueHD 7.1 ✓ | audio/3 English AC-3 5.1 | audio/4 English AC-3 5.1
2458 [audio] select audio/2 Surround 7.1 - [English] TrueHD Audio ch=8
2514 [audio] panel opened: audio/2 English TrueHD 7.1 ✓ | …          ← 1b-11-audio-panel-truehd-checked.jpg
2540 [DBG] killing decoder fourcc `mlpa'                               (switching to AC-3 on purpose, then PGS on)
2577 [DBG] Output on HDMI, channel count: 6
```
No "not supported" / "could not decode" line exists in the log. Skips: +30 s 29000→59000 ms,
−10 s 59000→49000 ms; subtitles PGS selected (spu/5). Screenshots: `1b-11-audio-panel.jpg` and
`1b-11-audio-panel-truehd-checked.jpg` (Audio panel open, "English / TrueHD · 7.1" with the check,
film playing at 00:56 and 01:16), `1b-10-player-wonder-woman.jpg`.

**Divergent, DTS** (`1b-divergent-vlckit.log`): `Using Video Toolbox to decode 'hevc'`, `x420`,
`codec (dca) started`, `Output on HDMI, channel count: 8`, `output 'f32l' 48000 Hz 3F2M2R/LFE`,
`format: 48000 rate, 8 nch, 4 bps, fl32` — identical to pass 1. `1b-10-player-divergent.jpg`.

**Stargate, both editions, AC-3** (`1b-stargate-both-editions-vlckit.log`): `codec (mpeg2video)`
and `codec (ac3) started` via avcodec, `Output on HDMI, channel count: 6`, `output 'f32l' 48000 Hz
3F2M/LFE`, `format: 48000 rate, 6 nch, 4 bps, fl32` — identical to pass 1. Frame step unchanged:
+1 19527→19653→19686 ms; −1 seek 19686→19653→19620 ms (the D008 back-step caveat from pass 1 stands).

## Disk and time

`~/vlckit-build` 22 GB (two clones, three contrib trees, three libvlc builds, the archives, tools);
`Frameworks/` 716 MB. This run 9 min 13 s; the recipe from scratch is that plus the host tools
(about 8 min) plus GNU make 4.4.1 (under a minute).

## Files touched, by step (rerun 4)

| Step | Files / actions |
|---|---|
| 0 | `~/vlckit-build/tools/{src,bin,…}` (make 4.4.1, outside the repo); `tools/vlckit-truehd/build.sh` (make step + `VLC_PATH`); `tools/vlckit-truehd/README.md` (one line) |
| 1 | check only |
| 3 | `~/vlckit-build/build.log` (kept); earlier logs `build.log.stopped-2236/-2242/-2247/-2303` |
| 4 | nm only |
| 5 | `Frameworks/VLCKit.xcframework` (ignored); `Marlin Media TV.xcodeproj/project.pbxproj`; `Marlin Media TV.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (deleted) |
| 6 | `reports/screenshots/1b-*.jpg` (17), `reports/logs/1b-*.log` (3) |
| 7 | `DECISIONS.md` (D012, D013), `COLD-START.md`, this section |

## Not tested, and what was traced instead

- The Denon's input display (D011, the owner's): the log proves 8-channel 48 kHz float PCM leaves
  VLC; what the receiver shows was not seen.
- The simulator slice was built and carries the symbols, but nothing was run in a simulator (D005).
- The Magicians episode (AAC) was not replayed this pass; its path is unchanged code and the same
  avcodec audio module used by AC-3 and DTS above.
- A full clean rebuild from an empty `~/vlckit-build` with the final `build.sh` was not run; the
  recipe was assembled from the four runs and its syntax checked.

## Open questions for the owner

1. The pass-1 open question on the frame-back step (native `gotoPreviousFrame`) is still open.
2. The 22 GB build directory: keep for incremental rebuilds, or delete once the framework is
   backed up to the NAS (D013)?
3. VLC picks the TrueHD track by default now; if the Denon cannot take 8-channel PCM at 48 kHz on
   some input, the Audio panel still offers the AC-3 tracks.

## Least sure of

- Whether VideoLAN's App Store reasoning for disabling MLP (2016) matters for a development-signed home app.
- The recipe end to end from an empty directory (see above).
- Long-run stability of the custom build: the longest playback here was about 100 s.
