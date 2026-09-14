# Pass 1e: VLC picture-reorder fix (patch 0019) — STOPPED — 2026-09-14

**Stopped before item 1's build, for two reasons, each needing the owner:**
1. **Xcode was upgraded to 27.0 and its license is not accepted, so every `xcrun` tool fails** (`devicectl`, `xcodebuild`). This blocks items 0, 1 (rebuild), 3 and 4.
2. **The requested change cannot be made as worded in `dpb.c` alone, and the literal wording would break Divergent.** Two correct alternatives exist; choosing one widens or narrows the patch, which the pass rules reserve for the owner.

Nothing was built, installed or changed: no VLC source edit, no patch file, no framework copy, no app build, no device action succeeded. The only new files are this report and `reports/logs/1e-candidates-simulation.txt`. Committed locally, not pushed.

## Result per item

| Item | Result |
|---|---|
| 0 Uninstall from the Master Bedroom Apple TV | **Not done — blocked.** `xcrun devicectl device uninstall app --device "Master Bedroom ATV" com.marlin1111.marlin-media-tv` printed `You have not agreed to the Xcode license agreements. Please run 'sudo xcodebuild -license' from within a Terminal window to review and agree to the Xcode and Apple SDKs license.` The follow-up `devicectl device info apps` failed the same way, so its "not listed" count means nothing. Reachability is unknown for the same reason. The app is presumably still installed there. |
| 1 Patch 0019 + VLCKit rebuild | **Not started.** Blocked by the license (the recipe runs `xcodebuild`/clang through VideoLAN's script), and by the design question (§2). No diff exists. |
| 2 Simulation against the patched logic | **Done for three candidate designs** (Wonder Woman and Divergent; §2). The literal reading misorders both files; two alternatives give 0 on both. The Magicians episode is an MP4 (`/stream/8`), which diag4's MKV frame parser cannot read, so H.264 is not simulated. |
| 3 Build, install on Home Theater | **Not done — blocked** (license). The leftover trace files (284.6 MB, diag4 §7) are still in the app container. |
| 4 Device verification | **Not done — blocked** (license). |
| 5 D017, COLD-START, report | Report only. No D017 and no COLD-START change, because no patch exists to record. |

## 1. The blocker: Xcode 27.0 with an unaccepted license

| Evidence | Value |
|---|---|
| `xcode-select -p` | `/Applications/Xcode.app/Contents/Developer` |
| Xcode version / build (`Info.plist`, `version.plist`) | **27.0 / 27A266a** (the project notebook records 26.6 / 17F113) |
| `stat` Xcode.app | modified **Sep 14 15:39:21 2026**. Diagnosis 4's last device run ended 15:15 on 26.6. |
| `defaults read /Library/Preferences/com.apple.dt.Xcode` | `IDEXcodeVersionForAgreedToGMLicense = "26.5"`, `IDELastGMLicenseAgreedTo = EA1990` |
| `xcrun --find devicectl` / `xcrun devicectl list devices` | exit **69** both |

Accepting the license needs `sudo xcodebuild -license` (admin, interactive), so it was not attempted. Retrying would not change the result.

It also opens a second question (§5, question 2). `Frameworks/VLCKit.xcframework` (12:50 today) was built with the tvOS 26.5 SDK of Xcode 26.6. An incremental rebuild under Xcode 27 would compile the patched libvlc objects with a different toolchain and SDK than the rest of the static framework and the contribs. The recipe has never run on Xcode 27.

## 2. The design question, with the simulation (item 2)

**Where the arriving picture is stored today.** `modules/codec/videotoolbox/decoder.c` `OnDecodedFrame` (lines 871-915 of the patched tree) calls `DPBOutputAndRemoval(&p_sys->dpb, &p_sys->pts, p_info)` and outputs what it returns. Only after that does it call `InsertIntoDPB(&p_sys->dpb, p_info)`. `dpb.c` `DPBOutputAndRemoval` does the latency increment, then either the IRAP flush (`EmptyDPB`) or the regular `BumpDPB` (fullness, reorder, latency). So storing the arriving picture before the release check means moving the `InsertIntoDPB` call in `decoder.c`. `dpb.c` receives the picture but does not store it.

**Three candidates**, simulated over the real decode order of the first 250 s of each file (`p1e-candidates.py`, output in `reports/logs/1e-candidates-simulation.txt`; same inputs and limits as diag4: Wonder Woman reorder 3 / latency 4 / DPB 5, Divergent 2 / 6 / 5; POC = display index since the IDR; IDR = flush):

| Candidate | What changes | Files | Wonder Woman misordered / released | Divergent misordered / released | Most pictures held after a step (WW / Div) |
|---|---|---|---|---|---|
| **vlc** (as built) | — | — | **869** / 5 995 | 0 / 5 995 | 4 / 3 |
| **L** — literal "store the arriving picture before the release check" | `InsertIntoDPB` moved before `DPBOutputAndRemoval`, nothing else | `decoder.c` | **260** / 5 995 | **46** / 5 995 | 3 / 2 |
| **A** — diag4's counter-simulation | IRAP flush and fullness/reorder release before storing; store; latency increment and reorder/latency release after | `decoder.c` (call order) + `dpb.c` (split `DPBOutputAndRemoval` in two) | **0** | **0** | 3 / 2 |
| **B** — `dpb.c`-only guard | VLC's order unchanged; in `BumpDPB`, a release triggered **only** by the latency condition stops when the head picture follows the arriving picture in output order (fullness and reorder releases untouched) | `dpb.c` | **0** | **0** | 4 / 3 |

Reading of the table:
- **L breaks Divergent** (46 new out-of-order releases on a file that plays clean today). The likely mechanism, not separately traced: an IRAP stored first is sorted ahead of the previous GOP's pictures still waiting, so the flush outputs it first.
- **A is the change diag4 described** (§1 point 4 there: "doing the insert of the current picture before the latency increment and the latency bump"). It touches two files, not only `dpb.c`.
- **B stays in `dpb.c`** and gives the same 0/0. It is a different mechanism: it withholds a release instead of storing first. It keeps one more picture waiting at peak (4 vs 3 on Wonder Woman), still under the DPB size of 5.
- Neither A nor B has been checked against H.264 (Magicians, the MP4) or MPEG-2. Both share `OnDecodedFrame`/`dpb.c`, and H.264 uses `b_strict_reorder = false`, whose "Raising max DPB" path runs just before the release step. They are also not checked against `dpb_test.c`, VLC's own unit test for this file (it exists in the tree; building it needs clang, i.e. the blocked toolchain).

## 3. Files touched

| Step | Files |
|---|---|
| 0, 1, 3, 4 | none (blocked) |
| 2 | `reports/logs/1e-candidates-simulation.txt` (script and output) |
| 5 | this report |

Unchanged: `tools/vlckit-truehd/*`, `~/vlckit-build` (libvlc at `a2b09c9741`, 18 patches, tree clean), `Frameworks/VLCKit.xcframework` (12:50), the app, `DECISIONS.md`, `COLD-START.md`.

## 4. What could not be tested

- Everything on a device (items 0, 3, 4) and every build (item 1): the Xcode license.
- The before/after drop table: no "after" exists. The "before" is diag4's (Wonder Woman 153 / 230 / 246 dropped per minute, 642 misordered in 3 min; Divergent 0 / 0).
- H.264 and MPEG-2 in the simulation: no frame-order reader for MP4 (Magicians) or for Stargate's BlockGroups within this pass's scope.
- Whether candidate B holds up against VLC's `dpb_test.c` cases: needs the toolchain.

## 5. Questions for the owner

1. **License:** please run `sudo xcodebuild -license` (or open Xcode 27 once and accept) on the Mac. Was the upgrade to 27.0 intended? The notebook pins Xcode 26.6.
2. **Toolchain:** once accepted, may pass 1e rebuild VLCKit with Xcode 27's tvOS SDK? Options: (a) incremental (patched objects on 27, the rest from 26.6); (b) a full clean rebuild on 27 (~9 min + host tools); (c) reinstall Xcode 26.6 alongside and select it with `xcode-select` (an install, so owner-approved only).
3. **Design:** which change should patch 0019 carry?
   - **A** — the diag4 change, faithful to "store before the release check", but in `decoder.c` and `dpb.c`.
   - **B** — `dpb.c` only, a guard on latency-only releases.
   Both give 0 misordered on Wonder Woman and keep Divergent at 0 in simulation. **L**, the literal one-line move, is ruled out: it breaks Divergent (46).
4. **Bedroom Apple TV:** the uninstall is still pending. Retry it first thing once `xcrun` works, before any build?

## 6. Least-sure items

1. The simulation models VLC's DPB step, not VideoToolbox. The diag4 device run matched it picture for picture on Wonder Woman (642/642), but the candidates themselves have only run in Python.
2. Why L misorders Divergent (IRAP flush ordering) is an explanation from the step structure. The individual 46 releases were not traced.
3. Whether Xcode 27's tvOS SDK changes anything for the app or VLCKit at deployment target 26.0 is unknown until something builds.

## 7. Method

- Blocker evidence: the commands in §1 (no `xcrun` needed for version/plist/stat).
- Code reading: `~/vlckit-build/VLCKit/libvlc/vlc/modules/codec/videotoolbox/decoder.c` 871-915 (`OnDecodedFrame`), `dpb.c` (`BumpDPB`, `DPBOutputAndRemoval`, `InsertIntoDPB`), `decoder.c` 1388-1416 (H.264 `b_strict_reorder = false`, HEVC `true`).
- Simulation: `p1e-candidates.py` over the diag4 decode-order lists (`mkvframes.py` output for `/stream/4` and `/stream/1`, 5 995 video blocks each), limits from diag4's `sps.py`.

---

# Pass 1e RERUN on Xcode 27 — STOPPED at item 2 (neither candidate passes VLC's dpb_test) — 2026-09-14

**Stopped at item 2 by the pass rule "If neither, STOP with the evidence".** VLC's own `modules/codec/videotoolbox/dpb_test.c` passes unmodified on today's code, and fails on both candidates. For B, the only failing expectation is the out-of-order release this pass is meant to remove. For A, it's also three cases where A releases the same pictures, in the same order, one step earlier. Changing the test's expectations, or picking a candidate that fails it, is an extra, so it's a question below.

Nothing was patched, rebuilt, built or installed, and no device was used after item 1. Working-tree changes: `COLD-START.md` (item 0), this record, and `reports/logs/1e-dpbtest-candidates.txt`. Committed locally, not pushed.

## Result per item

| Item | Result |
|---|---|
| 0 Xcode 27 license | **Accepted.** `xcodebuild -version` → `Xcode 27.0` / `Build version 27A266a` (exit 0); `xcrun --sdk appletvos --show-sdk-version` → `27.0`, build `24J360`; `xcrun devicectl list devices` exit 0, Home Theater and Master Bedroom ATV `available (paired)`. Recorded in COLD-START (supersedes 26.6 / 26.5). |
| 1 Bedroom uninstall | **Done.** `xcrun devicectl device uninstall app --device "Master Bedroom ATV" com.marlin1111.marlin-media-tv` → `App uninstalled.` (exit 0). The app listing afterwards no longer contains Marlin Media TV. It still contains **`Marlin Media TVUITests-Runner` (`com.marlin1111.marlin-media-tv.UITests.xctrunner`)**, which diagnosis 4's stopped bedroom run installed. Not removed: the item named only the app (question 3). |
| 2 dpb_test against A and B | **Neither passes → STOP.** Baseline exit 0, A exit 134, B exit 134 (§R2). The simulation re-run on a chosen candidate was not done: no candidate was chosen. |
| 3 Patch 0019, clean rebuild | Not started. |
| 4 App build, install, fresh container | Not started. The diag4 trace files (284.6 MB) are still in the Home Theater app container. |
| 5 Device verification | Not started. |
| 6 D017, D018, COLD-START, report | COLD-START records Xcode 27 (item 0). No D017 or D018: no patch and no framework built on Xcode 27. |

## R2. VLC's dpb_test against candidates A and B

**The harness.** VLC builds `videotoolbox_dpb_test` from `dpb_test.c` + `dpb.c` + `dpb.h` with `-DDPB_DEBUG` (`modules/codec/Makefile.am:360-366`). There is no macOS libvlc build in `~/vlckit-build`, so the same three files were compiled for the Mac with Xcode 27's clang, using the tvOS-simulator arm64 `config.h` and the two date functions it needs copied verbatim from `src/misc/mtime.c`. All of this was in scratch copies; the libvlc tree is untouched. **Unmodified, it exits 0**, so it reproduces VLC's test on today's code.

**The candidates as written** (full diffs in `reports/logs/1e-dpbtest-candidates.txt`):
- **A** (the diag4 change): in `dpb.c`, the latency increment leaves `DPBOutputAndRemoval`. `BumpDPB` gains a `b_before_insert` flag: flush and fullness only before storing, latency only after. A new `DPBOutputAfterInsert` does the latency increment, then the reorder/latency bump. 30 changed lines in `dpb.c`, 1 in `dpb.h`. The test's `CheckOutput` follows A's `decoder.c` order (release, store, release), 7 lines. That is the only test change, and it mirrors the call site.
- **B** (`dpb.c` only): in `BumpDPB`, a release triggered only by the latency condition stops when the head picture follows the arriving one in output order. 5 changed lines.

**Unmodified expectations** (the test aborts at its first mismatch):

| Build | Exit | First failing check (from `run.txt`) |
|---|---|---|
| Baseline | 0 | — |
| A | 134 | "dual parameters": enqueue 4, 2, then **8** → `output 2, no output was expected` → `Assertion failed: (output == NULL), function VaCheckOutput, file dpb_test.c, line 87.` |
| B | 134 | "Max latency requirements": enqueue 10, 8, 6, then **2** → `no output, 6 was expected` |

**All mismatches.** Diagnostic copies of the test keep going after a mismatch and log expected vs actual for every check (53 checks each; baseline 0 mismatches, A 8, B 2; no other assertion failed):

| Check (case) | Test expects | Today | A | B |
|---|---|---|---|---|
| 14 (dual parameters, enqueue 8) | — | — | `2` | — |
| 15 (dual parameters, enqueue 6) | `2` | `2` | `4` | `2` |
| 16 (plain drained reorder output) | `4 6 8` | `4 6 8` | `6 8` | `4 6 8` |
| 20 (RASL, enqueue 26) | — | — | `20` | — |
| 21 (RASL, enqueue 28) | `20` | `20` | `22 24` | `20` |
| 22 (RASL drain) | `22 24 26 28` | `22 24 26 28` | `26 28` | `22 24 26 28` |
| **36 (Max latency, enqueue 2)** | **`6 8 10`** | `6 8 10` | `2 6 8 10` | — |
| **37 (Max latency drain)** | **`2`** | `2` | — | `2 6 8 10` |

How to read it:
- **The test encodes the defect.** Its "Max latency requirements" case (`dpb_test.c:332-360`, comment `/* 10 has latency == 3 */`) expects `6, 8, 10` released while picture 2, which displays before all three, is still being stored, and `2` only at the drain. That is a backward release, the same shape as Wonder Woman's (diag4 §1). Both A and B release these pictures in display order instead.
- **B differs from the test only there.** Every other check, including the IRAP, RASL, NoRaslOutputFlag, field and mixed field/frame cases, gives exactly today's output.
- **A differs in three more checks, on timing, not order.** It releases the same pictures in the same order one enqueue earlier in "dual parameters" and "RASL, non-needed slots", because its reorder condition is also evaluated after storing. That is a behaviour change beyond the latency fix, even though it misorders nothing here.

## R3. Files touched

| Step | Files |
|---|---|
| 0 | `COLD-START.md` (the Xcode line) |
| 1 | none in the repo (device action only) |
| 2 | `reports/logs/1e-dpbtest-candidates.txt` (harness command, both diffs, both runs, the mismatch table, the diagnostic outputs); scratch copies only under the session scratchpad |
| 3–5 | none |
| 6 | this record |

Unchanged: `~/vlckit-build` (libvlc `a2b09c9741`, tree clean), `tools/vlckit-truehd/*`, `Frameworks/VLCKit.xcframework` (built 12:50 with the 26.6 toolchain), the app, `DECISIONS.md`.

## R4. What could not be tested

- Items 3–5, since the pass stopped at item 2. So there's no before/after drop table: "before" is still diagnosis 4's (Wonder Woman 153 / 230 / 246 dropped per minute and 642 misordered in 3 min; Divergent 0 / 0).
- VLC's test runs as a Mac binary built with the tvOS-simulator `config.h`, not through VLC's own `make check` (there is no host build). The unmodified test passing (exit 0, 53 checks, 0 mismatches) is the evidence that the harness is equivalent.
- Neither candidate was checked on H.264 or MPEG-2 picture order. The test's cases are POC sequences, not per-codec.

## R5. Questions for the owner

1. **Which way for patch 0019, given that VLC's own test encodes the misordering?**
   - (a) **B**, plus a change to `dpb_test.c`'s "Max latency requirements" expectation: `-1` at the enqueue of 2 instead of `6, 8, 10`, and `2, 6, 8, 10` at the drain. Two lines, and a test change.
   - (b) **A**, plus changes to the three "dual parameters" / "RASL" / "Max latency" expectation groups (eight checks). A also changes release timing in cases unrelated to latency.
   - (c) Report the test expectation to VideoLAN first and wait.

   My reading of the table: B fixes exactly the defect and nothing else. A changes more behaviour than the fix needs.
2. **Toolchain.** The framework in `Frameworks/` is still the 26.6 build. Should the clean rebuild on Xcode 27 (item 3) wait for the patch decision, or go ahead as a plain toolchain rebuild (D018 only, no 0019)?
3. **Bedroom Apple TV.** The UITests runner bundle (`Marlin Media TVUITests-Runner`) from diagnosis 4 is still installed there. Uninstall it too?

## R6. Least-sure items

1. **Harness fidelity:** the test was compiled against the tvOS-simulator `config.h` on macOS. The unmodified test passes, but a platform-specific branch in `dpb.c` would not show up this way; I found none in `dpb.c`/`dpb.h`, which include only `vlc_common.h`, `vlc_tick.h`, `vlc_picture.h`.
2. **A as written:** it is one faithful reading of "store before the release check" split across two calls. A version of A without the post-insert reorder release might pass everything except "Max latency". That variant was not written or tested; it would be a third design.
3. **B's guard compares against the arriving picture's FOC.** For field-coded H.264 (FOC = POC + field), the field test cases pass unchanged, but no real interlaced stream was run.
