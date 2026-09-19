# Pass 7 — the cleanup, and the owner's calls on every open item — 2026-09-19

It follows `reports/2026-09-19-stale-files-recon.md` (commit `e7676fa`): that report's §6 is this
pass's delete list, and its §10a / §10b numbering is the one the owner's calls use. Decisions:
**D052–D066**.

**All eight steps done; nothing skipped, nothing stopped.** No Swift code changed (one comment line
did), `tools/vlckit-truehd/build.sh` was not run, and nothing was installed or launched on either
Apple TV. Before step 3 the owner was asked once, plainly, whether to run the pass as written —
deleting the framework's only spare copy included — and answered "Run it as written".

Sizes are exact bytes from `stat`; "MB" is 1 048 576 bytes and "GB" is 1 024 MB.

## Result per step

| step | result |
|---|---|
| 1 Recon | **Every check passed; no candidate had changed.** §1 |
| 2 App log | **Each launch replaces the log; nothing caps its size.** Home Theater's current log: 53 049 bytes over 25.3 s. §2 |
| 3 Delete | **9 082 files, 7 062 841 475 bytes, permanently** — the recon's §6a and §6b exactly. §3 |
| 4 `git rm` | **770 files, 459 748 317 bytes** out of the tree: 569 screenshots + 201 logs. `e7676fa` is the last commit holding them. §4 |
| 5 Text fixes | `Theme.swift:5` and `tools/vlckit-truehd/README.md:10`, one line each. §5 |
| 6 Notebook | D052–D066; COLD-START's Current state rewritten, size line replaced, pass 7 note added; this report. §6 |
| 7 Build | **`** BUILD SUCCEEDED **`**; `SourcePackages` did not come back. §7 |
| 8 Commit, push | one fast-forward commit on `e7676fa`; SHAs in the closing message. §8 |

## 1. Recon (read-only)

- `git status --ignored`: the block in §8, "before". `git fetch`: local `main`, `origin/main` and
  `git ls-remote origin main` all `e7676fa4c471bed6076c4152130d54a18f3dd74c`.
- **All 21 candidate paths of §6a and §6b, and the 46 Finder files of V12, were re-measured and
  every one matched the recon's file count and byte size exactly.** Nothing under `~/vlckit-build`
  was newer than the recon. The empty `PackageFrameworks` folder was still empty.
- **`~/vlckit-build/VLCKit/build/tvOS/VLCKit.xcframework` re-hashed against
  `Frameworks/VLCKit.xcframework`: SHA-256 of all 109 files on each side, identical.**
- Tracked evidence files: 569 under `reports/screenshots/`, 202 under `reports/logs/`, as the recon
  counted.

## 2. The evidence log (read-only — no code changed)

**From `Marlin Media TV/EvidenceLog.swift`:**
- **Each launch replaces the file.** The first line a launch logs calls `ensureHandle()`, which
  runs `FileManager.default.createFile(atPath: url.path, contents: nil)` (`:31`) — creating the
  file empty over whatever the previous launch left — and then opens it for writing. Its own
  comment says the same: "The file is opened (and truncated) by whichever comes first" (`:25`).
  The handle is kept for the life of the process, so it happens once per launch.
- **There is no size cap.** Nothing rotates, trims or limits the file. It grows for as long as
  that launch lives, and VLCKit's own logger writes to the same handle at **debug** level
  (`:47–48`), which is nearly all of the volume. The only other limit is tvOS itself, which may
  purge `Library/Caches` when it wants the space.

**From Home Theater**, copied with COLD-START's `devicectl device copy from` command at 18:13 —
no launch, no terminate, nothing else sent to the device:

| | |
|---|---|
| size | **53 049 bytes**, 1 111 lines (71 the app's own timestamped lines, the rest VLC's) |
| launches in it | 1 — one `[log] started` line, which agrees with the code reading |
| first timestamp | `5:53:14.708 PM` — `[log] started 2026-09-19 21:53:14 +0000` |
| last timestamp | `5:53:40.022 PM` — `[player] state Stopped at 3853339 ms` |
| span | **25.3 s** |
| rate over that span | 2 096 bytes/s = **7 544 000 bytes an hour (7.2 MB/h)** |

That launch was the owner's own, 20 minutes before the copy: two short plays (file 8 for 2.2 s,
then file 4 resumed at 3 851 s for 3 s). Nothing was written after the second player closed.

**How far that number can be pushed: not far.** A 25-second span with two player opens in it is a
burst — VLC's debug output is heaviest when a stream opens and closes. For scale, from logs that
were still in the tree when this was measured (now in history at `e7676fa`): pass 1k's full
app + VLC logs of about 220 s of film, most of it paused, were 44–57 KB each —
**0.7–0.9 MB an hour**; pass 3b's 37 s launch-and-pause was 3.3 MB/h. So a long evening's film
is more likely a few MB than tens, but **no pass has ever logged a whole film**, and that is the
number the decision actually wants.

## 3. Deleted — counted again by hand after the fact

Measured by summing every file's size before and after, not added up from the recon:

| tree | files before → after | bytes before → after | deleted |
|---|---|---|---|
| repo (outside `.git`) | 6 541 → 4 903 | 4 716 398 686 → 1 772 874 418 | **1 638 files, 2 943 524 268 bytes** |
| `~/vlckit-build` | 264 388 → 256 944 | 23 254 404 652 → 19 135 087 445 | **7 444 files, 4 119 317 207 bytes** |
| **both** | | | **9 082 files, 7 062 841 475 bytes (6 735.6 MB)** |

Both differences equal the recon's §6a and §6b totals to the byte.

**On the disk:** `df` for the data volume went from 186 777 220 KB used to 180 590 028 KB —
**6 187 192 KB freed (5.90 GB)**, read 28 s apart with step 3 the only thing this pass did in
between. `du` fell by 6 916 412 KB (4 037 828 under `~/vlckit-build`, 2 878 584 in the repo).
`df` is about 712 MB short of the byte sum, close to the size of one framework; my guess, not
checked, is that the xcframework and the xcarchive it was assembled from shared blocks on APFS, so
the same bytes were counted in two files and freed once.

**What went** (each deleted by its own explicit path, through a guard that refused anything
outside `build/`, the two named `.DS_Store` files and `~/vlckit-build`):
- §6a: `build/DerivedData/SourcePackages/` (1 630 files); the empty
  `…/Debug-appletvos/PackageFrameworks` folder (`rmdir`, 0 files); the tvOS 26.5 `.xctestrun`;
  `build/1i-app-build.out`, `1i-instr-app-build.out`, `1j-instr-app-build.out`,
  `1j-restore-app-build.out`, `1k-app-build.out`; `Design/tvos icons/.DS_Store`;
  `reports/screenshots/.DS_Store`.
- §6b: `VLCKit/build/VLCKit-appletvos.xcarchive`, `VLCKit/build/VLCKit-appletvsimulator.xcarchive`,
  `VLCKit/build/tvOS/VLCKit.xcframework`, `host-test-1i/`, `1i-instr-build.out`, `1i-recipe.out`,
  `1j-instr-build.out`, `1j-recipe.out`, `1j-libvlc-instrumentation.diff`, `build-1d.out`,
  `build.pid`, and the 46 Finder `.DS_Store` files, deleted from a list written in step 1 and
  bounded to their 16:49–16:51 timestamps. The now-empty folders `VLCKit/build/` and
  `VLCKit/build/tvOS/` were left; the recon did not list them.

**Every one of the 21 paths was listed afterwards and is gone. Skipped: none.**

**Still there, at the recon's exact counts and sizes** (re-counted after step 3):

| path | files / bytes |
|---|---|
| `Frameworks/VLCKit.xcframework` | 109 / 759 995 933 |
| `~/vlckit-build/VLCKit` tree in use | 251 725 / 18 448 192 178 |
| `~/vlckit-build/tools` | 511 / 15 409 859 |
| `~/vlckit-build/build.log` | 1 / 5 020 689 |
| `…/contrib/tarballs` | 63 / 529 105 845 |
| `…/extras/tools/build` | 4 640 / 131 769 593 |
| the four `build.log.stopped-*` | 4 / 5 589 281 |
| the five harnesses | 5 / 37 266 |
| `PlayerHost.swift`'s hook | 18 insertions, 1 deletion, unstaged |
| `Notes/` | 2 / 3 852 380 (sizes only; not opened) |
| `icon pixel/` | 1 / 2 021 051 (size only; not opened) |
| `Design/` | no change to any tracked file; both zips at 62 169 and 7 254 893 |
| `build/DerivedData`, the in-use part | 3 911 / 532 491 470 (before step 7's build) |
| Python framework + `/Applications/Python 3.14` | 9 669 / 331 112 166 |

`~/vlckit-build` now holds `build.log`, the four stopped logs, `tools/` and `VLCKit/` and nothing
else: **19 135 087 445 bytes in 256 944 files (17.8 GB; `du` 18 G)** — D062's figure.

## 4. The screenshots and logs, out of the tree

`git rm` of every tracked file under `reports/screenshots/` and `reports/logs/` except
`reports/logs/1k-upstream-videolan-draft.md`:

| | recon | removed | kept | bytes removed |
|---|---:|---:|---:|---:|
| `reports/screenshots/` | 569 | **569** | 0 | 444 007 762 |
| `reports/logs/` | 202 | **201** | 1 | 15 740 555 |
| | 771 | **770** | 1 | **459 748 317** |

The only difference from the recon's 569 + 202 is the one file told to stay, the VideoLAN draft
(10 064 bytes; 15 740 555 + 10 064 = the recon's 15 750 619). The index shows 770 deletions and no
other. `reports/screenshots/` no longer exists as a folder; `reports/logs/` holds the draft alone;
all 32 written reports are untouched.

**The last commit that still holds these files: `e7676fa4c471bed6076c4152130d54a18f3dd74c`.**
`git show e7676fa:reports/logs/<file>` or `git checkout e7676fa -- reports/screenshots` brings any
of them back. The notebook cites those two folders 36 times in `COLD-START.md`, 22 times in
`DECISIONS.md` and 231 times across the reports; all of those paths now resolve only there (D066).
The pack in `.git` is no smaller for this — the files are still in history, which is the point.

## 5. Two text fixes

- `Marlin Media TV/Theme.swift:5` — "plus the values the **17** frames in" → "the **20** frames in"
  (D042's Design2 export; `COLD-START.md` counts the 20). A comment; nothing else in the file.
- `tools/vlckit-truehd/README.md:10` — "(pass 1i; no decision yet — pass 1i stopped at step 8)" →
  "(pass 1i; decided as D019 in pass 1k)".

Each is one changed line. Both files were staged by explicit path; `PlayerHost.swift` was never
staged.

## 6. Notebook

- **`DECISIONS.md`:** a "2026-09-19 — pass 7" heading with **D052–D066**, the owner's calls as
  given, grouped by subject with the recon's numbers beside each. **48 of the recon's 56 items are
  closed; seven are parked** (§10a 8–11 and §10b 26, the scrub thumbnails, D055; §10b 7 and 8,
  D064) **and one is open** (§10b 10, the evidence log, D064). D061 is the new standing rule for
  the bedroom Apple TV and revises D050. D066 records the removal of the evidence files, the two
  "closed by events" items and the README finding.
- **`COLD-START.md`:** Current state rewritten whole (Built and owner-accepted, Pushed,
  Deliberately uncommitted, What the Apple TVs run, The server's state, Open items); the
  `~/vlckit-build` size line replaced with this pass's measurement; a pass 7 note added at the end
  of Pass history. Open items now holds four entries: the three parked subjects and the one open
  question.
- **One thing added that was not asked for by name,** inside Current state: a short list,
  "Lines above this section that pass 7 made out of date". The pass limited the rewrite to named
  parts, and six lines in the sections above them now disagree with the owner's calls (the bedroom
  box "not reinstalled as a matter of course", Inter "still an open question", "Browse cached"
  "still not built", the video screen "never run on a device", `Theme.swift` "still says the 17
  frames", the 2g copies "committed as evidence"). I listed them rather than edit them. See open
  question 1.

## 7. Build

COLD-START's command, once, 18:16:12–18:16:20, exit 0:
```
xcodebuild build -project "Marlin Media TV.xcodeproj" -scheme "Marlin Media TV" \
  -destination 'platform=tvOS,name=Home Theater' -derivedDataPath build/DerivedData -allowProvisioningUpdates
…
** BUILD SUCCEEDED **
```
- **`build/DerivedData/SourcePackages` did not come back**, and neither did `PackageFrameworks`;
  the build output has no package-resolution line at all. That is the recon's least-sure item 5
  answered: the app builds without the stock package.
- Two warnings, neither new to this pass's changes: VLCKit's own header
  (`VLCMediaPlayer.h:36`, "'NS_SWIFT_NAME' attribute ignored when parsing type"), shown because
  the comment edit made the Swift module recompile, and `appintentsmetadataprocessor`'s "no
  AppIntents.framework dependency found". No errors.
- The product `Marlin Media TV.app` was rebuilt at 18:16:20. **It was not installed and nothing was
  launched**; both Apple TVs still run the pass 5 build.

## 8. Commit and push

One commit on top of `e7676fa`, pushed to `origin main` as a fast-forward, no force. Its SHA, the
fetch and the three-way comparison are in the pass's closing message — a commit cannot name itself.

**Pushed:** the 770 removals (step 4); `Marlin Media TV/Theme.swift` and
`tools/vlckit-truehd/README.md` (step 5); `COLD-START.md`, `DECISIONS.md` and this report (step 6).
**Stays local, exactly as before:** the `PlayerHost.swift` hook, the five harnesses, `Notes/`,
`icon pixel/`, and everything git-ignored.

**`git status --porcelain --ignored`, before the pass:**
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
**After the commit** the expected differences are two lines gone and none added —
`!! "Design/tvos icons/.DS_Store"` and `!! reports/screenshots/.DS_Store`, both deleted in step 3.
The closing message shows the actual diff.

## Files touched, by step

| step | files |
|---|---|
| 1, 2 | none in the repo. Scratch only: a status snapshot, two hash lists, the copied device log, the V12 list, a before/after measurement, the build output — all deleted at the end |
| 3 | deleted: the 21 paths and 46 Finder files of §3, in `build/`, `Design/tvos icons/`, `reports/screenshots/` and `~/vlckit-build` |
| 4 | removed from git and the working tree: 569 files under `reports/screenshots/`, 201 under `reports/logs/` |
| 5 | `Marlin Media TV/Theme.swift`, `tools/vlckit-truehd/README.md` |
| 6 | `DECISIONS.md`, `COLD-START.md`, `reports/2026-09-19-pass7-cleanup.md` (new) |
| 7 | `build/DerivedData/` (git-ignored), rewritten by the build |
| 8 | none |

## Open questions

1. **The six lines in COLD-START's upper sections that now disagree with Current state** (§6).
   Rewrite them in a later pass, or is the list under Current state enough?
2. **The evidence log (D064, open item 4).** The numbers in §2 are what this pass could get without
   launching anything, and the honest summary is "small per hour, never measured over a whole
   film, and never capped". If the deciding number is a film's worth, the cheapest way to get it is
   to copy the log off Home Theater after the owner's next full evening — the file survives until
   the next launch.
3. **D061's first install.** The rule fires on "a push pass that follows the owner's acceptance of
   a pass that changed the app". Pass 7 changed one comment and is not such a pass, so nothing was
   installed on Master Bedroom ATV, as this pass's own rules also required. The bedroom box keeps
   the pass 5 build until a pass that changes the app is accepted.
4. **Four harnesses have no copy anywhere.** `Pass2bUITests.swift`, `Pass2cUITests.swift`,
   `Pass3ShotsUITests.swift` and `Pass3bShotsUITests.swift` exist only in the working tree (the
   recon said so; step 4 did not change it, since no copy of them was ever under `reports/logs/`).
   Deliberate, or worth a copy somewhere?

## The things I am least sure of

1. **The `df` shortfall** (§3). 712 MB fewer freed than the byte sum; shared APFS blocks between
   the xcframework and its xcarchive is a guess I did not test. The byte sums are exact; the `df`
   figure is what the volume reported.
2. **The log's hourly rate** (§2) is an extrapolation from 25 seconds.
3. **"The owner's launch" at 17:53** is an inference: this session launched nothing, and the log's
   own start line gives the time. I cannot see who pressed the remote.
4. **The server's state in COLD-START** now rests on one line of the app's log and the owner's
   report, not on a read of the server; pass 7 had no step that reads it.
5. **Grouping the owner's calls into fifteen decisions** was my arrangement. Every call is there
   with its recon number, and nothing was added to what was decided, but the grouping and the
   one-line descriptions of the §10b items are my wording of the recon's.
6. **The framework now has one copy on this Mac.** It was the owner's call, asked about directly
   before step 3. The way back is `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh` — the three static
   libraries it needs were re-counted and are intact — but that path was not run in this pass.
