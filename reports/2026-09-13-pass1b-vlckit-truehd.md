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
