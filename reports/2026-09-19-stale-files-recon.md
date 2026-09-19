# Stale-files recon — 2026-09-19 — read-only

A read-only inventory of old, unused and stale files in and around this project, plus every item
the notebook still carries as open. **Nothing was deleted, moved, renamed, edited or chmod-ed;
nothing was built, installed or launched; neither Apple TV was touched; no process of this project
was started or stopped.** The only write is this file, its commit and its push. `COLD-START.md` and
`DECISIONS.md` were **not** updated, because this pass allows one new file and nothing else — so
the notebook does not yet know this report exists.

Sizes are exact bytes summed from `stat`; "MB" is 1 048 576 bytes and "GB" is 1 024 MB. Every count below was re-taken
with a second, independent command after the list was built (§8).

## 1. Result in one screen

| list | files | bytes | MB |
|---|---:|---:|---:|
| **IN USE** — repo | 4 932 | 2 141 562 106 | 2 042.4 |
| **IN USE** — outside the repo | 261 906 | 18 799 734 892 | 17 928.8 |
| **NOTEBOOK SAYS KEEP** — repo | 6 | 99 435 | 0.1 |
| **NOTEBOOK SAYS KEEP** — outside the repo | 4 707 | 666 464 719 | 635.6 |
| **CANDIDATE TO DELETE** — repo | 1 638 | 2 943 524 268 | 2 807.2 |
| **CANDIDATE TO DELETE** — outside the repo | 7 444 | 4 119 317 207 | 3 928.5 |
| **Owner's own files** (unsorted, §5) | 3 | 5 873 431 | 5.6 |
| **LOW CONFIDENCE** (§6) | 0 | 0 | 0 |

**All candidates together: 9 082 files, 7 062 841 475 bytes (6 735.6 MB).** Four items are all but
1 MB of it: the stock VLCKit Swift package still sitting in the in-repo DerivedData (2.74 GB),
VLCKit's two packaging archives (2.94 GB), a byte-identical second copy of the framework (725 MB)
and a host test build of VLC last used for the dropped patch 0021 (196 MB).

The repo partitions exactly: 4 932 + 6 + 1 638 + 3 = **6 579** files on disk (871 tracked, 5 + 3
untracked, 39 in `.git`, 109 in `Frameworks/`, 5 547 in `build/`, 5 `.DS_Store` outside `build/`).
`~/vlckit-build` partitions exactly: **264 388** files, 23 254 404 652 bytes (22 177 MB). That
discharges `COLD-START.md:139`, "`~/vlckit-build` was 22 GB on 2026-09-13 (not re-measured since)".

**Per-file rows are given for every candidate, keep and owner entry.** The IN USE lists are given
per group, because two of the groups are 870 tracked files (`git ls-files` is their listing) and a
251 725-file build tree.

## 2. Where this project writes — found from the files, then confirmed on disk

| place | named by | on disk today |
|---|---|---|
| the repo, incl. `build/DerivedData` (every build command uses `-derivedDataPath build/DerivedData`, `COLD-START.md:156`) and `Frameworks/` | notebook, `.gitignore`, `build.sh` | present |
| `~/vlckit-build` | `tools/vlckit-truehd/build.sh:11`, D013, 34 notebook mentions | present, 22 177 MB |
| `/Library/Frameworks/Python.framework` and `/Applications/Python 3.14` | `build.sh:14`, `COLD-START.md:127–128` | present, installed 2026-09-13 23:02 |
| session scratch ("stays in scratch", "stay off-repo", "the session scratchpad") | 21 of the 31 reports, never with a path | **gone** — see below |
| `/tmp/…` recon folders of pass 1b (`vlckit-recon`, `vlckit-build-recon`, `vlckit-patchcheck`, `vlckit-check-index`, `py-pkg`, two `.html`, `tools-two.sums`) | past session transcripts only | all 10 checked, **all absent** |
| `~/Library/Developer/Xcode/DerivedData` | nothing (no report names it) | empty folder, no `Marlin_Media_TV-*` |
| `~/Library/Developer/Xcode/Archives` | nothing | does not exist |
| `~/Library/Caches/org.swift.swiftpm` | nothing | does not exist |
| simulators | nothing ("never the simulator") | no copy of the bundle id in any of 6 devices |
| `~/Downloads`, `~/Desktop`, `~/Documents` (depth 2) | nothing | no match for the project, VLCKit, the Python installer or the design system |
| the rest of `~` (depth 5, excluding `Library`) | — | no second copy of the repo or the app, no `.xcarchive`, no stray `VLCKit*.xcframework`; the only `.xcresult` bundles are Marlin DVR TV's, which is not this project |
| Trash | — | empty |
| the NAS (`/Volumes/UNAS4Pro`) — D013: "NAS backup of the framework is separate and the owner's" | D013 | mounted; **no match by name** to depth 3, nor in `Backups/` to depth 5 (which lists empty) |
| Claude Code's own store for this project (`~/.claude/projects/-Users-…-Marlin-Media-TV`, `~/Library/Caches/claude-cli-nodejs/-Users-…`) | the memory index | present, 47 files / ≈100 MB and growing — this session writes to it |
| the two Apple TVs (app containers, installed builds) | many reports | **not inspected — this pass may not touch them** |

**The scratch folders are gone, and with them every artefact the notebook says "stays in scratch"
or "stays off-repo".** Past sessions' transcripts name one scratch root 2 238 times:
`/private/tmp/claude-501/-Users-marlin1111-Xcode-Marlin-Media-TV/<session>/scratchpad`. The Mac was
rebooted today at about 09:44 (`uptime`: up 7:18 at 17:02; `/private/tmp` created 09:44), which
clears `/private/tmp`; the only session folder there now is this pass's own. So these are not stale
files to clean up — they no longer exist on this Mac: the JSON traces the reports cite as off-repo
evidence (4–108 MB each, passes diag4 through 2f), the analysis scripts' working copies, the raw
full-size screenshots, the moved-out `Diag1jUITests.swift`, and pass 4's 22 MB full-resolution
Home-screen frame ("the full-resolution original stayed in the scratch folder",
`reports/2026-09-16-pass4-app-icon.md:149`). The committed copies under `reports/` are all that
remains, as each report intended.

## 3. IN USE

### 3a. In the repo — 4 932 files, 2 141 562 106 bytes

| group | files | bytes | what it is, what uses it |
|---|---:|---:|---|
| tracked files, all but one | 870 | 474 357 242 | everything `git ls-files` prints except `Design/Marlin Media tvOS Design.zip` (§4). 43 app files, 2 committed harnesses, 3 project files, 6 recipe files, 10 design files, 4 at the root, and **802 under `reports/`** (31 reports, 202 logs, 569 screenshots — 444 MB of the total). All on `origin/main`. |
| `.git/` | 39 | 374 696 969 | one pack, 357 MB; no stashes, no tags, no extra branches, one worktree |
| `Frameworks/VLCKit.xcframework` | 109 | 759 995 933 | the custom VLCKit (D012/D013), linked and embedded by `project.pbxproj:31`; git-ignored; last built 2026-09-15 19:06 (pass 2g, 20 patches) |
| `build/DerivedData`, minus the two candidates in §6 | 3 911 | 532 491 470 | the documented build's derived data. Holds the pass 5 `Marlin Media TV.app` (2026-09-16 00:56) that is on both Apple TVs, the pass 3b test runner, module caches and the index. Regenerable by one build, but it is what the next build reuses. |
| `.DS_Store` ×3 (`./`, `Design/`, `reports/`) | 3 | 20 492 | Finder's, not the project's; written 17:00:01–17:00:15 today, as this pass began, so they go here by the pass's own rule |

`Marlin Media TV/PlayerHost.swift` is counted among the tracked files; its uncommitted hook is a
modification, not a file, and is covered by §4.

**Files whose content matches another file (SHA-256), and why they stay.** 53 groups, 133 files:
- 50 groups, 124 files are **screenshots under `reports/screenshots/`**. The identity is the
  evidence — a frame step retraced to "identical pictures (MAD 0)" *is* two files with one hash
  (`1k-exact/`, `p1f-stargate-*`, `2g/…-retrace-of-L1`), and the rest are the same screen
  photographed by two runs (`diag2-*` = `1c-*`, `1b-*` = pass 1's). All tracked and pushed.
- 2 groups, 7 files are Xcode's boilerplate `Contents.json` inside `Assets.xcassets`.
- 1 group is `Marlin Media TVUITests/Diag2gUITests.swift` =
  `reports/logs/2g-harness-Diag2gUITests.swift.txt` — the harness and the evidence copy the
  notebook says it made (`COLD-START.md:377–378`).

22 of the 202 evidence logs are named nowhere in the notebook by exact name or glob (the
`1i-clean-stargate-*`, `2c-<film>-{play,pause,control}` and `2d-<film>-{scrub,control}` families).
They are tracked, pushed, and belong to run families the reports do describe; they stay IN USE.

### 3b. Outside the repo — 261 906 files, 18 799 734 892 bytes

| path | files | bytes | what uses it |
|---|---:|---:|---|
| `~/vlckit-build/VLCKit/`, minus §4's and §6's carve-outs | 251 725 | 18 448 192 178 | the recipe's working tree. `PACKAGE_ONLY=1` refuses to run without `VLCKit/libvlc/vlc` and the three `build-appletv*/static-lib/libvlc-full-static.a` (`build.sh:21–24`); a full run reuses the clone, the contrib build trees (8.2 GB) and installs (2.2 GB) and the libvlc builds (3.3 GB + 2.2 GB of `install-*`). libvlc is clean at `6d62358330` on `localBranch`, as pass 2g left it; `libvlc/patches/` holds exactly 0001–0020, no orphan. **Regenerable, at a cost the notebook has measured only in part** (§9). |
| `~/vlckit-build/tools/` | 511 | 15 409 859 | GNU make 4.4.1. Only `bin/make` (300 008 bytes) is used, as `VLC_PATH` (`build.sh:59–67`); the other 510 files are its tarball and build tree under `src/`, which `build.sh` would re-create if `bin/make` were missing |
| `~/vlckit-build/build.log` | 1 | 5 020 689 | the live recipe log, rewritten by every run (`build.sh:100`); this one is pass 2g's, 2026-09-15 19:06 |
| `/Library/Frameworks/Python.framework` + `/Applications/Python 3.14` | 9 669 | 331 112 166 | the recipe's prerequisite; `build.sh:14` exits without it |

Also in use, not added into the totals because this session is writing to it while it is measured:
Claude Code's per-project store (47 files, ≈104.6 MB when read: the 4 memory files this project's
passes rely on, 14 session transcripts, and this session's tool output) and its 2-file MCP log
cache. It is the tool's record of the passes, not a project artefact; see §9.

## 4. NOTEBOOK SAYS KEEP

### 4a. In the repo — 6 files, 99 435 bytes

| file | bytes | modified | the notebook's wording |
|---|---:|---|---|
| `Marlin Media TVUITests/Diag2gUITests.swift` | 6 710 | 2026-09-15 19:07 | `COLD-START.md:367–378`: "### Deliberately uncommitted — These stay out of git on purpose and are expected in `git status`: … Five UI-test harnesses, all in `Marlin Media TVUITests/`" |
| `Marlin Media TVUITests/Pass2bUITests.swift` | 10 187 | 2026-09-15 21:37 | same |
| `Marlin Media TVUITests/Pass2cUITests.swift` | 10 640 | 2026-09-15 22:05 | same |
| `Marlin Media TVUITests/Pass3ShotsUITests.swift` | 4 862 | 2026-09-15 22:56 | same |
| `Marlin Media TVUITests/Pass3bShotsUITests.swift` | 4 867 | 2026-09-15 23:15 | same; and `COLD-START.md:982–983` (pass 6): "**Still uncommitted, unchanged, and deliberate:** the `PlayerHost.swift` Page Up / Down hook and the five UI-test harnesses" |
| `Design/Marlin Media tvOS Design.zip` (tracked) | 62 169 | 2026-09-13 20:52 | `DECISIONS.md:375–376` (D042): "The earlier `Marlin Media tvOS Design.zip` is left as it was."; `COLD-START.md:73–74`: "The **older `Design/Marlin Media tvOS Design.zip` is still there**, untouched, and holds the pass-1 (17-frame) copies of the same files"; pass 1 report `:28`: "zip kept" |

The zip is the one **superseded version** in the tree: by `COLD-START.md:74–75` it holds the nine
pass-1 files that D042's Design2 export replaced (this pass did not open it). Nothing reads it. The notebook records leaving it, so it is here
and not in §6 — but the wording describes what pass 3 did rather than instructing anyone (§9).

Only `Diag2gUITests.swift` has a committed evidence copy. `Pass2b`, `Pass2c`, `Pass3Shots` and
`Pass3bShots` exist **nowhere else** — not in git, not in `reports/logs/`.

### 4b. Outside the repo — 4 707 files, 666 464 719 bytes

| path | files | bytes | modified | the notebook's wording |
|---|---:|---:|---|---|
| `~/vlckit-build/VLCKit/libvlc/vlc/contrib/tarballs/` | 63 | 529 105 845 | 2026-09-13 22:54 | `DECISIONS.md:40` (D018): "**Kept from 26.6:** `contrib/tarballs` (sources) and `extras/tools/build` (the Mac host tools, which aren't linked into the framework)." |
| `~/vlckit-build/VLCKit/libvlc/vlc/extras/tools/build/` | 4 640 | 131 769 593 | built 2026-09-13 22:54 | same; and `COLD-START.md:131–132`: "the host tools in `extras/tools/build` were kept" |
| `~/vlckit-build/build.log.stopped-2236` | 1 | 482 | 2026-09-13 22:37 | pass 1b report `:125`: "The stopped run's log was kept as `~/vlckit-build/build.log.stopped-2236`." |
| `~/vlckit-build/build.log.stopped-2242` | 1 | 31 480 | 2026-09-13 22:42 | pass 1b report `:293`: "`~/vlckit-build/build.log` (kept), previous logs `build.log.stopped-2236`, `build.log.stopped-2242`" |
| `~/vlckit-build/build.log.stopped-2247` | 1 | 5 003 431 | 2026-09-13 22:54 | pass 1b report `:391`: "`~/vlckit-build/build.log` (kept); previous logs `build.log.stopped-2236`, `-2242`, `-2247`" |
| `~/vlckit-build/build.log.stopped-2303` | 1 | 553 888 | 2026-09-13 23:04 | pass 1b report `:547`: "`~/vlckit-build/build.log` (kept); earlier logs `build.log.stopped-2236/-2242/-2247/-2303`" |

The four stopped-run logs are pass 1b's four failed builds, each already quoted at length in that
report. "Kept" there is a record of that evening, not a standing order (§9).

## 5. The owner's own files — unsorted, for the owner to decide

**3 files, 5 873 431 bytes.** All untracked, none opened by this pass (listed by name, size and
date only). The notebook: "still untracked and still nobody's decision … Neither was opened, moved
or committed; whoever picks them up should ask first" (`COLD-START.md:386–388`).

| file | bytes | modified |
|---|---:|---|
| `Notes/Marlin Mediatvos.pxd` | 2 060 404 | 2026-09-16 00:25 |
| `Notes/Marlin Mediatvos.png` | 1 791 976 | 2026-09-15 23:57 |
| `icon pixel/Marlin Media.pxd` | 2 021 051 | 2026-09-15 23:57 |

By type: 2 Pixelmator documents, 1 PNG export. No media, uploads or other documents of the owner's
were found in any place this project writes. The two `.pxd` files differ in size and hash; they are
not copies of each other.

## 6. CANDIDATE TO DELETE — nothing here was deleted

### 6a. In the repo — 1 638 files, 2 943 524 268 bytes (all git-ignored, none tracked)

| # | path | files | bytes | modified | what it is, and the evidence |
|---|---|---:|---:|---|---|
| R1 | `build/DerivedData/SourcePackages/` | 1 630 | 2 943 163 190 | 2026-09-13 21:18–21:33 (one folder 21:46) | **The stock VideoLAN VLCKit 4.0.0-a24 Swift package**, fetched by Xcode in pass 1: the all-platform binary `artifacts/vlckit/VLCKit/VLCKit.xcframework` (ten slices — iOS, macOS, tvOS, watchOS, xrOS; 2.73 GB), a source checkout, a bare repository and `workspace-state.json`. **Superseded by D013** — "the Swift package is gone" (`COLD-START.md:111–112`); pass 1b removed the package references and deleted `Package.resolved` (pass 1b report `:484–489`, `:549`). `grep` for `XCRemoteSwiftPackageReference`, `XCSwiftPackageProductDependency`, `packageReferences` or `videolan` in `project.pbxproj` finds **nothing**; the project links `Frameworks/VLCKit.xcframework` by path. The newest file in it is dated 2026-09-13 21:33 — nothing has written there since pass 1. The empty folder `Build/Products/Debug-appletvos/PackageFrameworks` (0 files, 2026-09-13) is the same leftover. |
| R2 | `build/DerivedData/Build/Products/Marlin Media TV_Marlin Media TV_appletvos26.5-arm64.xctestrun` | 1 | 6 847 | 2026-09-14 14:46 | the test-run descriptor written against the **tvOS 26.5 SDK**, which D018 replaced that afternoon. Its successor sits beside it: `…appletvos27.0-arm64.xctestrun`, 2026-09-15 23:15. Nothing names the 26.5 file. |
| R3 | `build/1i-app-build.out` | 1 | 54 015 | 2026-09-14 22:48 | captured `xcodebuild` output from passes 1i–1k. **Named nowhere** in `COLD-START.md`, `DECISIONS.md`, any report or any evidence log. The build lines those passes needed are quoted in their reports. |
| R4 | `build/1i-instr-app-build.out` | 1 | 96 408 | 2026-09-14 22:41 | same |
| R5 | `build/1j-instr-app-build.out` | 1 | 90 744 | 2026-09-14 23:20 | same |
| R6 | `build/1j-restore-app-build.out` | 1 | 53 322 | 2026-09-14 23:34 | same |
| R7 | `build/1k-app-build.out` | 1 | 47 446 | 2026-09-14 23:44 | same |
| R8 | `Design/tvos icons/.DS_Store`, `reports/screenshots/.DS_Store` | 2 | 12 296 | 2026-09-16 00:51, 2026-09-15 19:47 | Finder metadata, git-ignored (`.gitignore:32`), made by Finder and not by the project; Finder re-creates them |

### 6b. Outside the repo — 7 444 files, 4 119 317 207 bytes (all under `~/vlckit-build`)

| # | path | files | bytes | modified | what it is, and the evidence |
|---|---|---:|---:|---|---|
| V1 | `VLCKit/build/VLCKit-appletvos.xcarchive` | 55 | 1 029 388 684 | 2026-09-15 19:05 | **packaging intermediates** of the last recipe run. VideoLAN's script re-archives to the same `-archivePath` on every run, full or `PACKAGE_ONLY` (`compileAndBuildVLCKit.sh:178`), and reads the archives only within that same run (`:619–643`). Nothing in the repo or the notebook reads them. Pass 1e deleted this whole folder once already (`DECISIONS.md:37`, "and `VLCKit/build`") and the recipe rebuilt it. |
| V2 | `VLCKit/build/VLCKit-appletvsimulator.xcarchive` | 57 | 2 124 137 551 | 2026-09-15 19:06 | same |
| V3 | `VLCKit/build/tvOS/VLCKit.xcframework` | 109 | 759 995 933 | 2026-09-15 19:06 | **a byte-identical duplicate of `Frameworks/VLCKit.xcframework`**: all 109 files compared by SHA-256 in this pass, no difference. It is what `build.sh:115` copied from; the script `rm -rf`s and re-creates it on every run (`:641–643`). **Caveat:** it is also the only second copy of the framework on this Mac, the framework is not in git, and no NAS backup was found (§9). |
| V4 | `host-test-1i/` | 7 170 | 205 092 677 | 2026-09-14 → 2026-09-15 12:15 | a **host macOS build of VLC** made in pass 1i to run VLC's own player tests, reused once in pass 2f to test patch 0021 — which D022 then dropped. `build.sh` never touches it. Its results are committed (`reports/logs/1i-vlc-player-tests.txt`, `2f-vlc-tests.txt`). The notebook mentions it four times and never says to keep it. It would be wanted again only by a future libvlc patch that needs VLC's host tests, and is rebuilt by configure + make. |
| V5 | `1i-instr-build.out` | 1 | 19 719 | 2026-09-14 22:40 | captured build output of pass 1i's instrumented libvlc. Named nowhere. |
| V6 | `1i-recipe.out` | 1 | 526 | 2026-09-14 22:46 | `build.sh`'s console output, pass 1i. Named nowhere. |
| V7 | `1j-instr-build.out` | 1 | 332 572 | 2026-09-14 23:20 | as V5, pass 1j. Named nowhere. |
| V8 | `1j-recipe.out` | 1 | 526 | 2026-09-14 23:34 | as V6, pass 1j. Named nowhere. |
| V9 | `1j-libvlc-instrumentation.diff` | 1 | 22 841 | 2026-09-14 23:19 | **SHA-256-identical to the tracked `reports/logs/1j-libvlc-resume-instrumentation.diff`** — a working copy of evidence that is committed and pushed |
| V10 | `build-1d.out` | 1 | 356 | 2026-09-14 12:50 | `build.sh`'s console output, pass 1d. Named once, as a source (pass 1d report `:135`), with no keep wording; the two lines it holds are quoted there. |
| V11 | `build.pid` | 1 | 6 | 2026-09-13 23:12 | the pid of pass 1b's last build, which ended that night. Named once (pass 1b report `:52`), never again. Not read here beyond its size; whether that pid is alive now was not checked, since it could only belong to some unrelated process. |
| V12 | `.DS_Store` ×46 across `VLCKit/libvlc/vlc/…` | 46 | 325 816 | 2026-09-19 16:49:47–16:50:51 | Finder metadata, written when the tree was browsed in Finder ten minutes before this pass began. They are the **only** files under `~/vlckit-build` newer than 2026-09-15 19:06, and none changed after the pass started. (Three older `.DS_Store` files dated 2002 ship inside LAME's source tarball and are counted with the tree, §3b.) |

## 7. LOW CONFIDENCE

**None.** Every path found could be attributed. Considered and left out because they are **not**
this project's: the 23 `.xcresult` bundles under `~/Xcode/Marlin DVR TV/build/` (that project's
own), the other seven folders in `~/Xcode`, and Xcode's global `UserData`/`CodingAssistant`.

## 8. Verify

**Counts, taken a second time by different commands.** harnesses 5 / 37 266 bytes
(`git ls-files --others`); owner files 3 / 5 873 431; `build/*.out` 5 / 341 935; `SourcePackages`
1 630; loose `~/vlckit-build` candidates 7 / 376 546; stopped logs 4 / 5 589 281; xcarchives 2
folders / 112 files; `.DS_Store` in the repo 6 (4 written at 17:00 today, one of them inside
DerivedData; 2 older); `.DS_Store` under `~/vlckit-build` 49 = 46 today + 3 from 2002. Both trees
were then partitioned by one classifier each, every file landing in exactly one list, and the
parts sum to the wholes (6 579 and 264 388).

**`git status --porcelain --ignored`, before (17:00) and after the report was written:**
```
 M "Marlin Media TV/PlayerHost.swift"
?? "Marlin Media TVUITests/Diag2gUITests.swift"
?? "Marlin Media TVUITests/Pass2bUITests.swift"
?? "Marlin Media TVUITests/Pass2cUITests.swift"
?? "Marlin Media TVUITests/Pass3ShotsUITests.swift"
?? "Marlin Media TVUITests/Pass3bShotsUITests.swift"
?? Notes/
?? "icon pixel/"
!! .DS_Store
!! Design/.DS_Store
!! "Design/tvos icons/.DS_Store"
!! Frameworks/
!! build/
!! reports/.DS_Store
!! reports/screenshots/.DS_Store
```
After writing, the one added line is `?? reports/2026-09-19-stale-files-recon.md`; after the
commit the status is the block above again, line for line. The `PlayerHost.swift` hook, the five
harnesses, `Notes/` and `icon pixel/` — everything `COLD-START.md` lists under "Deliberately
uncommitted" — are in both and were not touched. The commit SHA, the fetch and the local-vs-remote
comparison cannot be inside the file they describe; they are in the pass's closing message.

**What this pass created, other than this report.** In its own scratch folder under
`/private/tmp/claude-501/…/scratchpad`: `status-before.txt`, `fw-repo.sha`, `fw-build.sha`,
`repo.sha`, `vb-loose.sha`, `notebook-all.txt`, `logs-unnamed.txt` — all deleted at the end, with
the listing shown in the closing message. Nothing was written into the repo, `~/vlckit-build` or
anywhere else. Not removable by the pass: Claude Code's own record of this session (its transcript,
the four readers' output files, its MCP logs), which the tool writes as it runs.

## 9. The things I am least sure of

1. **The 31 reports were read by four delegated readers, not by me.** I read `COLD-START.md`
   (983 lines) and `DECISIONS.md` (633) in full myself; each reader read its batch in full (its
   line counts match `wc -l`: 1 932 + 2 085 + 2 301 + 2 064) and returned quotes with line
   numbers. Every quote used in §10 I then checked against the file. An open item the readers
   missed is missing here.
2. **"Closed by the owner's acceptance" is my judgement** wherever a builder's "not run" was
   followed by the owner testing that feature by hand and saying "all good". §10b keeps only what
   the owner could not have seen, or what no later entry answers.
3. **`~/vlckit-build` has never been rebuilt from empty.** Pass 1b: "A full clean rebuild from an
   empty `~/vlckit-build` with the final `build.sh` was not run" (`:560`), and no later pass did
   it — pass 1e's "clean" build kept the clones, the tarballs and the host tools. None of §6b's
   candidates is an input to the recipe, so this does not weaken them; it is why the 17.2 GB tree
   is IN USE rather than "regenerable, so a candidate". The 9 min 11 s figure is for contribs and
   libvlc with the host tools already built; the notebook's other figure is "hours, not minutes"
   (`tools/vlckit-truehd/README.md:4`).
4. **V3 is a duplicate and also the only spare.** If `Frameworks/` were lost, V3 is the 30-second
   way back (`PACKAGE_ONLY=1` would also remake it, from the static libs in §3b). D013's NAS backup
   was not found: I searched `/Volumes/UNAS4Pro` by name only, to depth 3 (depth 5 in `Backups/`),
   and did not crawl `Media/` or the other shares. It may exist under a name I did not match.
5. **R1 rests on the project file, not on a build.** No package reference exists, so nothing can
   ask for `SourcePackages`; but this pass may not build, so "the app builds without it" is
   reasoned, not run.
6. **The "kept" wording in §4.** For the stopped logs and the pass-1 Design zip the notebook
   records that something *was* kept or left, in the past tense. I filed them under KEEP because
   the pass says to quote and defer; on the evidence alone both are superseded and unread.
7. **The Apple TVs were not looked at.** Every traced pass from 1e to 2f wrote
   `Library/Caches/vlc-trace-<run>.json` into the app's container on Home Theater. diag4's 284.6 MB
   was cleared by pass 1e's uninstall/reinstall (`reports/2026-09-14-pass1e-reorder-fix.md:581`);
   no later report says the later traces were. Whether they survive depends on whether each
   install made a fresh container, which the reports answer both ways (pass 1f `:39` found pass
   1e's trace still there). Unknown, and out of reach of this pass.
8. **Claude Code's store is filed as IN USE** because the memory files are read every session and
   this session is writing there. The 13 older transcripts (≈100 MB) are read by nothing in the
   project; they are the tool's history, and whether to prune them is a question about the tool.
9. **The `.DS_Store` timing.** I attribute them to Finder because 46 appeared in 46 folders within
   64 seconds with no other file changing, and four more in the repo at 17:00. I did not see who
   opened the folders.

## 10. Every item the notebook still carries as open

### 10a. The 25 items `COLD-START.md` lists under "Open items" — all still open

Each was checked against its cited source; none is closed or superseded by a later entry, and pass
6 says so itself: "**The open items are unchanged**" (`COLD-START.md:979`).

| # | `COLD-START.md` line | wording |
|---|---|---|
| 1 | 423 | "**Videos have never run on a device.**" — also D038, `DECISIONS.md:329`: "**A check is still owed:** Videos Recently Added and the video detail screen, once a video exists on the server." |
| 2 | 429 | "**Home fetches one `GET /api/shows/{id}` per show every time it appears** … Cache them, or ask only when the shows list changes?" |
| 3 | 432 | "**The TV Shows row uses the wide episode card** the brief asked for, while frames 00b/00c draw that row as posters." |
| 4 | 435 | "**With no videos the Videos heading shows above an empty space**, as asked. Is that the wanted look once a video exists, or should the row hide the way Continue watching does?" |
| 5 | 438 | "**Nothing pins Home's header** … Is the header meant to stay put?" |
| 6 | 444 | "**Frames 16 and 17 carry the clock by code trace, not device proof.**" — D044 |
| 7 | 448 | "**The paused clock shows during a scrub, and while the player is buffering or opening** … Neither was separately asked for" |
| 8 | 455 | "**"The file that would play" is a guess on multi-file screens.** … Fetch per selection, or lazily when the player opens?" — D021, `DECISIONS.md:167`: "Flagged as the open question of pass 2g." |
| 9 | 459 | "**A file's first visit shows no stills at all** … Accept "second visit onwards", or re-ask when the player opens?" |
| 10 | 462 | "**The stills are letterboxed** … Crop them in the client, or leave the server's tile as it is?" |
| 11 | 464 | "**Nothing logs which still is drawn.**" |
| 12 | 469 | "**A pause after a scrub landing lets the demuxer read at 1× while paused**, up to about 36 s of stream. … Observed, not decided." — `DECISIONS.md:70`, `:102` |
| 13 | 472 | "**Start-up late pictures.** … Accept as start-up behaviour, or a later diagnosis pass?" |
| 14 | 476 | "**Wonder Woman's displayed picture rendered 24 s late at one resume** … One run, not reproduced on the other films, not instrumented." |
| 15 | 479 | "**Audio start is still unmeasured.**" |
| 16 | 484 | "**The VideoLAN report is drafted and not submitted.** "Submit it, and in whose name?"" |
| 17 | 487 | "**`last_played` was not cleared by the reset** and cannot be … a request to the server repo, not a client change." — D047 |
| 18 | 494 | "**Inter is not bundled**" |
| 19 | 496 | "**Frame 17's "Browse cached" button and its "Last successful sync … cached" line are not built**, because there is no cache." |
| 20 | 504 | "**Which Top Shelf size tvOS actually chose was not established.**" — D049, `DECISIONS.md:578–579` |
| 21 | 512 | "**The App Store icon has never been rendered.**" |
| 22 | 515 | "**The focused icon's parallax was not photographed.**" |
| 23 | 522 | "**The app on Master Bedroom ATV will go stale and nothing watches it.** … Reinstall on request, on a schedule, or leave it to rot?" — D050 |
| 24 | 526 | "**Its provisioning profile will expire.**" |
| 25 | 529 | "**Nothing about the app has been tested on `AppleTV6,2` hardware.**" |

### 10b. Open in the notebook, and **not** in that list — 31 items

Found in a report, `COLD-START.md` or `DECISIONS.md`, with no later entry that answers, closes or
supersedes them.

**About the files this pass is looking at**

1. `reports/2026-09-13-pass1b-vlckit-truehd.md:566–567` — "The 22 GB build directory: keep for
   incremental rebuilds, or delete once the framework is backed up to the NAS (D013)?" Never
   answered; no report says the NAS backup was made.
2. same report `:560–561` — "A full clean rebuild from an empty `~/vlckit-build` with the final
   `build.sh` was not run; the recipe was assembled from the four runs and its syntax checked."
3. `COLD-START.md:386–388` — `icon pixel/` and `Notes/` are "**still untracked and still nobody's
   decision**"; pass 4 report `:182–183`: "should it be tracked next to the zip, or stay out?"
4. `COLD-START.md:139` — "`~/vlckit-build` was 22 GB on 2026-09-13 (not re-measured since)."
   **Measured by this pass** (§1); the line itself still stands, because this pass may not edit it.
5. `COLD-START.md:269–270` — `Theme.swift`'s "header comment still says "the 17 frames", from
   before D042 replaced the export." Still so: `Marlin Media TV/Theme.swift:5`.

**Pass 1's questions that no later entry answers** (`COLD-START.md` lists only 8 and 9 as "never
settled"; these six sit beside them in the same list and were not answered either)

6. pass 1 report `:199` — "**VLC turns subtitles on by itself** on Stargate … Leave to VLC, or
   force "Off" at start?"
7. `:201` — "**Unnamed edition.** … the row and the overlay show the file name
   (`Wonder Woman (2017).mkv`). Preferred label?"
8. `:202` — "**Shows carry no 4K/HDR badges** … Leave, or ask the server for a show-level
   summary?"
9. `:203` — "**Rating chip** shows `TMDB 7.2` … the frame drew "R"."
10. `:206` — "**Evidence logging** … is in the app because the device-proof needs it. Keep it for
    pass 2, or gate it?"
11. `:208` — "**Audio track names** come from VLC … VLC does not report "Atmos" or "DTS-HD MA";
    neither does the server."

**The player and VLCKit**

12. `reports/2026-09-14-pass1c-mkv-seek.md:107` — "Should the MKV decision use the server's
    `Content-Type: video/x-matroska` (a HEAD request before play) instead of the path suffix?"
13. same `:108` — "The Stargate Theatrical deinterlace burst (§5.1): worth a short from-9:10 check
    in a later pass …?" Pass 1e `:636` still lists "The Stargate Theatrical edition" as not run.
14. `reports/2026-09-14-pass1d-truehd-audio-and-framerate.md:130` — "For HEVC MKVs the request
    lands ~0.1 s after play; acceptable, or should a later pass read the frame rate from the
    container before play?"
15. same `:131` — "The AC-3 route flap (§5.2): has the Denon or the TV shown an HDMI re-sync around
    13:02 today?"
16. `reports/2026-09-14-pass1e-reorder-fix.md:634` — "**Whether Magicians exercised the patched
    guard at all.** … An H.264 stream that does reach one was not available."
17. same `:643` — "**Stargate's two start-up drops** are two MPEG-2 pictures released out of order
    by avcodec (not the patched code). Worth a separate item?"
18. same `:644` — "**Upstream.** Report the `dpb.c` defect and the `dpb_test.c` expectation to
    VideoLAN, with patch 0019?" Item 16 of §10a does **not** cover this: the draft
    (`reports/logs/1k-upstream-videolan-draft.md`) is about the paused previous-frame step only
    and mentions `dpb`/VideoToolbox once. No draft exists for 0019.
19. same `:651` — "**libvlc's own minimum stays tvOS 11.0** inside a framework whose `minos` is
    26.0. … nothing beyond these runs checks it."
20. `DECISIONS.md:47` (D019) — "**Known gap:** `decoder_frame_next_need_data` reads
    `p_sys->p_next_frame_es` from a decoder thread without `p_sys->lock` … it is formally a data
    race a thread sanitizer would flag."
21. `reports/2026-09-15-pass2d-owner-flow.md:207` — "**Arrow clicks while a scrub is up are
    ignored** (logged). Should a left/right click then cancel the scrub and step, nudge the
    target, or stay ignored?" D021 records "ignored" as the behaviour; the question was not
    answered as a question.
22. same `:208` — "**The lost Play/Pause press** in the first Divergent run (§5) is unexplained."
    And `:163`: "14 pictures were dropped at +29.63 s after scrub 2's click, within 25 ms, 3 s
    before the lost press." — reported, never explained.
23. `reports/2026-09-15-pass2e-scrub-seek-diagnosis.md:281` — "**Pass 2c's "one old-position
    picture before the target" in 3 of 32 landings.** Not examined."
24. `reports/2026-09-15-pass2f-scrub-live-picture.md:318` — "**`test_src_clock_clock` fails on
    this host build before and after.** Look into it, or accept it as a host artefact like
    `test_interrupt`?" (The host build is candidate V4.)
25. `DECISIONS.md:122–124` (D022) — the MP4 clock gap: "The gap is exposed rather than created by
    0021 (a non-lapping paused seek produced one in pass 2e's 20-patch build too), and why the
    time freezes after some gaps and not others was never established."

**Untested claims the owner's hand tests could not have covered**

26. `reports/2026-09-15-pass2g-scrub-thumbnails.md:219–225` — "**One film, one session.** Stargate
    only … Wonder Woman, Divergent and Magicians were not run at all this pass"; and "A cold or
    still-generating file, or a drag that crosses many sheets in one sweep … was never exercised
    on the device — only reasoned from the code."
27. `reports/2026-09-15-pass2c-hold-and-focus.md:154–155` — "**Only the Movies tab's row was used
    for step 2**, with two cards. Three or more cards, and the TV Shows and Videos tabs, are
    untested."
28. `reports/2026-09-15-pass3-home-and-rows.md:145–147` — "**The TV row's order is barely
    exercised by this library** … The "next after the last finished" and the walk on down each
    show are written to the rule but have almost no real data behind them here."
29. `COLD-START.md:412–413` — with Continue Watching empty "D043's launch focus deliberately
    places nothing — that branch is the one in play and it has not been seen on the device."
    With it, pass 3b `:140–142`: "**The 1.4 s retry window** (12 × 120 ms) was never observed
    being exhausted".
30. `reports/2026-09-15-pass3b-fixes.md:143–146` — "The panel-open case (clock hidden) and the
    paused-scrub case (clock shown) are traced from the code, not photographed." and "**The minute
    rollover** on the player's clock was not watched, as in pass 3."
31. `reports/2026-09-15-pass3c-push-and-reset.md:191–193` — "**"Behaviourally identical" is traced
    from the code and the recon, not re-tested on the device.**"

**Closed by events, noted so nobody chases them.** Pass 1e `:645` ("The harness saved screenshots
… They are not committed; do you want them in `reports/screenshots/`?") and pass 4 `:149–150`
("Say so if you want the 22 MB frame in the repo instead.") can no longer be answered yes: both
sets were in session scratch, which is gone (§2).

**Found by this pass, not in the notebook.** `tools/vlckit-truehd/README.md:10` still describes
patch 0020 as "(pass 1i; no decision yet — pass 1i stopped at step 8)". D019 has been that
decision since pass 1k. Reported, not edited.

No `TODO`, `FIXME`, `XXX` or `HACK` marker exists in any Swift file, harness or recipe file.
