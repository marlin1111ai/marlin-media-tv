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

---

# Pass 1e RERUN 2 — patch 0019 = candidate B — STOPPED at item 3 (Xcode 27 rejects VLCKit's tvOS deployment target) — 2026-09-14

**Items 1 and 2 are done and verified. Item 3's clean rebuild compiled libvlc and every contrib for all three tvOS slices with Xcode 27 / SDK 27.0, then failed at VLCKit's own `xcodebuild archive`:**

```
~/vlckit-build/VLCKit/VLCKit.xcodeproj: error: The tvOS deployment target 'TVOS_DEPLOYMENT_TARGET' is set to 11.0, but the range of supported deployment target versions is 15.0 to 27.0.x. (in target 'VLCKit' from project 'VLCKit')
** ARCHIVE FAILED **

The following build commands failed:
	Archiving project VLCKit with scheme VLCKit
(1 failure)
```

Getting past it means changing a deployment target the recipe does not set today (VLCKit's project, or the script's archive call), so it is an extra and a question for the owner (§R2-8). `Frameworks/VLCKit.xcframework` is untouched: still the 12:50 framework built with Xcode 26.6, without 0019, because `build.sh` stops on the first error and copies only at the end. Items 4–6 were not started: no app build, no install, no device run, no D017/D018. Committed locally, not pushed.

## Result per item

| Item | Result |
|---|---|
| 1 Bedroom UITests runner | **Done.** `xcrun devicectl device uninstall app --device "Master Bedroom ATV" com.marlin1111.marlin-media-tv.UITests.xctrunner` → `App uninstalled.` (exit 0). Afterwards the app listing holds no `com.marlin1111.marlin-media-tv` bundle (count 0); remaining apps: Channels Beta, Marlin DVR TV, Marlin Home Assistant. Nothing else was done on that device. |
| 2 Patch 0019, dpb_test, simulation | **Done.** `tools/vlckit-truehd/0019-videotoolbox-dpb-no-latency-bump-ahead-of-arriving-picture.diff` (§R2-2). VLC's `dpb_test` built from the patched tree: **exit 0**, 0 warnings. Diagnostic copy: **53 checks, 0 mismatches**. Simulation: Wonder Woman **0** / 5 995 misordered (VLC as built: 869), Divergent **0** / 5 995. Recipe: `build.sh` step 2c; README paragraph. Evidence: `reports/logs/1e-rerun2-dpbtest-and-simulation.txt`. |
| 3 Clean VLCKit rebuild on Xcode 27 | **Failed at the VLCKit archive step** after libvlc and the contribs built (§R2-3, §R2-4). No framework produced; `Frameworks/` unchanged. `nm` on the framework still in `Frameworks/` (the 26.6 build) lists `_ff_mlp_decoder`, `_ff_mlp_parser`, `_ff_truehd_decoder`. That is the old framework, not a proof for this build. |
| 4 App build, install, fresh container | Not started. The diag4 trace files are still in the Home Theater app container. |
| 5 Device verification | Not started. |
| 6 D017, D018, COLD-START | Not written. D017 and D018 describe a framework that does not exist yet. COLD-START already records Xcode 27 / SDK 27.0 (rerun 1). |

## R2-2. Patch 0019 (item 2)

Libvlc commit on `localBranch` over 0018, exported with `git format-patch -1`. The recipe's `git am` has since re-applied it as `e50d9ac36a` (19 patches on `5dd4aebda`, tree clean).

```diff
diff --git a/modules/codec/videotoolbox/dpb.c b/modules/codec/videotoolbox/dpb.c
index 684bbaee8f..8b092401a1 100644
--- a/modules/codec/videotoolbox/dpb.c
+++ b/modules/codec/videotoolbox/dpb.c
@@ -153,6 +153,7 @@ static picture_t * BumpDPB(struct dpb_s *dpb, date_t *ptsdate, const frame_info_
     for(;dpb->i_stored_fields;)
     {
         bool b_output = false;
+        bool b_latency_only = false;
 
         if(p_info->b_flush && dpb->i_stored_fields > 0)
             b_output = true;
@@ -170,6 +171,7 @@ static picture_t * BumpDPB(struct dpb_s *dpb, date_t *ptsdate, const frame_info_
                    p->i_latency >= p_info->i_max_latency_pics)
                 {
                     b_output = true;
+                    b_latency_only = true;
                     break;
                 }
             }
@@ -178,6 +180,10 @@ static picture_t * BumpDPB(struct dpb_s *dpb, date_t *ptsdate, const frame_info_
         if(!b_output)
             break;
 
+        /* never release ahead of the arriving picture on latency alone */
+        if(b_latency_only && dpb->p_entries->i_foc > p_info->i_foc)
+            break;
+
         *pp_output_next = DPBOutputFrame(dpb, ptsdate, dpb->p_entries);
         if(*pp_output_next)
             pp_output_next = &((*pp_output_next)->p_next);
diff --git a/modules/codec/videotoolbox/dpb_test.c b/modules/codec/videotoolbox/dpb_test.c
index 1bc0e00924..4ee017b92c 100644
--- a/modules/codec/videotoolbox/dpb_test.c
+++ b/modules/codec/videotoolbox/dpb_test.c
@@ -353,9 +353,9 @@ static void CheckDPBWithFramesTest(void)
     info.i_foc = 2;
     info.i_poc = info.i_foc & ~1;
     info.b_flush = (info.i_foc == 0);
-    CheckOutput(&dpb, &pts, withpic(infocopy(&info), info.i_foc), 6, 8, 10, -1); /* 10 has latency == 3 */
+    CheckOutput(&dpb, &pts, withpic(infocopy(&info), info.i_foc), -1); /* 10 has latency == 3, but 2 precedes it */
 
-    CheckDrain(&dpb, &pts, 2, -1);
+    CheckDrain(&dpb, &pts, 2, 6, 8, 10, -1);
 
     assert(dpb.i_size == 0);
 }
-- 
```

- **`dpb.c`:** 6 inserted lines (5 non-blank). The `dpb.c` hunks are byte-identical to candidate B as tested in rerun 1 (`cmp`).
- **`dpb_test.c`, "Max latency requirements":** 2 changed lines. The enqueue of POC 2 now expects no output, and the drain expects `2, 6, 8, 10`. The patched test's own run shows `enqueing foc 2 flush 0 dpb sz 3 ndsz 3` → `no output, no output was expected`, then `drain` → `output 2, 2 was expected` / `output 6, 6 …` / `output 8, 8 …` / `output 10, 10 …`.
- **Recipe:** VideoLAN's `compileAndBuildVLCKit.sh` applies `libvlc/patches/*.patch` with `git am` (lines 525–540), so `build.sh` step 2c copies the `.diff` there as `0019-….patch`. The run's log shows 19 `Applying:` lines, the last `videotoolbox: dpb: do not bump ahead of the arriving picture on latency alone`.
- **Scope, verified in source:**
  - The guard can fire only when a picture has a latency limit (`BumpDPB`: `i_max_latency_pics > 0`, `dpb.c:165`).
  - Only `FillReorderInfoH264` / `FillReorderInfoHEVC` set that limit; `CreateReorderInfo` defaults it to 0 (`decoder.c:821-850`).
  - So it can change H.264 and HEVC decoded by VideoToolbox, and nothing else. VideoToolbox's other codecs (MPEG-4 Part 2, H.263, ProRes, DV) never set the limit.
  - Stargate's MPEG-2 is decoded by avcodec on this device (`using video decoder module "avcodec"`, pass 1d and diag1 logs), so it never reaches this code.

## R2-3. The clean rebuild (item 3)

**Removed before the run** (all built with Xcode 26.6 / SDK 26.5), `rm` at 16:49:28:

| Removed | Size before | Why |
|---|---|---|
| `libvlc/vlc/build-appletvos-arm64`, `build-appletvsimulator-arm64`, `build-appletvsimulator-x86_64` | 1.1 G each | not SDK-versioned, so the recipe would have reused them |
| `libvlc/vlc/contrib/contrib-arm64-apple-tvOS_11.0`, `contrib-arm64-apple-tvOS-Simulator_12.0`, `contrib-x86_64-apple-tvOS-Simulator_12.0` | 2.7–2.8 G each | contrib build trees, named by deployment target, not SDK |
| `libvlc/vlc/contrib/{arm64-appletvos,arm64-appletvsimulator,x86_64-appletvsimulator}26.5` | 731–771 M | contrib installs for SDK 26.5 |
| `VLCKit/build` | — | the 12:50 xcframework and both xcarchives |

Kept: `contrib/tarballs` (sources, 505 M) and `extras/tools/build` (the Mac host tools, 139 M, not linked into the framework).

**What the run built** (`build.log`, colour codes stripped; excerpt in `reports/logs/1e-rerun2-archive-failure.txt`):

| Step | Evidence |
|---|---|
| Recipe start | `patch 0007 already edited`, `m4-1.4.21.tar.gz: OK`, `gettext-0.26.tar.gz: OK`, `GNU Make 4.4.1`, `patch 0018 installed`, `patch 0019 installed`, `build start: 2026-09-14 16:49:46` |
| SDK | `SDK Version: 27.0`; `Compiling aarch64 with SDK version 27.0, platform appletvos` |
| Patches | 19 `Applying:` lines, 0019 last |
| Contribs compiled locally, not prebuilt | "prebuilt" appears only in VLC's help text (`make prebuilt fetch and install prebuilt binaries`). The device slice logged 3 168 compile lines before libvlc finished (ffmpeg, gcrypt, gsm, lame, libdvbpsi, libgpg-error, libmodplug, libshout, libtasn1, libtheora, libvpx, live555, rnnoise, speex, speexdsp, twolame, zvbi). The new contrib build tree's `config.mak`: `CC := /Applications/Xcode.app/…/XcodeDefault.xctoolchain/usr/bin/clang`, `-isysroot …/AppleTVOS27.0.sdk`. `libavcodec.a` 16:51:38. |
| libvlc per slice | `Finished compiling libvlc for aarch64 … appletvos` (build.log line 37139), `… x86_64 … appletvsimulator` (87621), `… aarch64 … appletvsimulator` (137046) |
| Left on disk | `build-appletvos-arm64/static-lib/libvlc-full-static.a` 747.2 MB (16:53:02); `build-appletvsimulator-x86_64/…` 785.0 MB (16:56:03); `build-appletvsimulator-arm64/…` 750.5 MB (16:58:57); 83 static libs in each of `contrib/{arm64-appletvos,arm64-appletvsimulator,x86_64-appletvsimulator}27.0/lib` |
| VLCKit archive | `** ARCHIVE FAILED **`, the error above; recipe exit 65 at 16:59:00; `VLCKit/build` does not exist |

## R2-4. Why the archive fails

- **VLCKit's project sets the old target.** `VLCKit.xcodeproj/project.pbxproj` sets `TVOS_DEPLOYMENT_TARGET = 11.0` (4 build configurations), `IPHONEOS_DEPLOYMENT_TARGET = 9.0` (4) and `MACOSX_DEPLOYMENT_TARGET = 10.11` (2).
- **The script only overrides the iOS setting.** Its archive call (`compileAndBuildVLCKit.sh:165-186`) passes `IPHONEOS_DEPLOYMENT_TARGET=${SDK_MIN}` (`SDK_MIN=9.0`, line 11), so a tvOS archive keeps the project's 11.0.
- **Xcode 27 no longer accepts it.** Its supported tvOS range is 15.0–27.0.x, and it stops the build. Xcode 26.6 built the same project at 12:50.
- **libvlc and contribs use old targets too.** `VLC_DEPLOYMENT_TARGET_TVOS="11.0"` and `VLC_DEPLOYMENT_TARGET_TVOS_SIMULATOR="12.0"` (`extras/package/apple/build.conf:19-20`). Xcode 27's clang compiled them without complaint; only the Xcode project check rejects 11.0.

## R2-5. Before/after drop table

No "after": the pass stopped before any device run. Before, for the next attempt:

| File | Before (run) | Dropped (too late) | Shown late | Misordered releases |
|---|---|---|---|---|
| Wonder Woman TrueHD | diag4 traced, 3 min | 153 / 230 / 246 per minute segment (642) | 0 | 642 |
| Divergent DTS | diag4 traced, 3 min | 0 | 0 | 0 |
| Magicians S1E1 (H.264 MP4, VideoToolbox) | pass 1d 3 min 11 s; diag1 8 min 17 s | 0; 0 | 1; 0 | not traced |
| Stargate Extended (MPEG-2, avcodec) | pass 1d 3 min 11 s; diag1 8 min 16 s | 2; 4 | 6; 15 | not traced |
| Wonder Woman seek (pass 1c, ten +30 s paced) | `1c-seek-wonder-woman-A.log` | last press → picture 0.446 s | — | — |

**Stargate** was never zero-drop, and its decoder is not the patched one, so its "unchanged" means counts of this size. **Magicians** is the only H.264 check of the patch.

## R2-6. Files touched, by step

| Step | Files |
|---|---|
| 1 | none (device action) |
| 2 | `tools/vlckit-truehd/0019-videotoolbox-dpb-no-latency-bump-ahead-of-arriving-picture.diff` (new), `tools/vlckit-truehd/build.sh` (step 2c), `tools/vlckit-truehd/README.md` (one paragraph), `reports/logs/1e-rerun2-dpbtest-and-simulation.txt` (new) |
| 3 | `reports/logs/1e-rerun2-archive-failure.txt` (new); outside the repo: the removals in §R2-3 and the new 27.0 build output in `~/vlckit-build` |
| 4–6 | none; temporary `Marlin Media TVUITests/Diag1eUITests.swift` written for item 5, never built, deleted (Appendix R2-A) |
| record | this section |

## R2-7. What could not be tested

- **Everything after the archive step:** the Xcode 27 framework itself (`nm` proof on it, size), the app build on Xcode 27, the install and container check, and all device runs (drop counts, release order, audio block rate, seek, frame step).
- **`dpb_test`'s build method:** it is still a Mac build of VLC's test with the tvOS-simulator `config.h` (no host libvlc), as in rerun 1.

## R2-8. Questions for the owner

1. **Which tvOS deployment target should VLCKit's framework be archived with on Xcode 27, and where should it be set?** Xcode 27 accepts 15.0 to 27.0.x. Options:
   - (a) A recipe step that sets `TVOS_DEPLOYMENT_TARGET` in VLCKit's project, like the 0007 edit. It could be **26.0**, matching the app (D004) — my recommendation, as it matches what ships — or **15.0**, the lowest Xcode 27 accepts.
   - (b) A patch to `compileAndBuildVLCKit.sh` so its archive call also passes `TVOS_DEPLOYMENT_TARGET`.
   - (c) Also raise libvlc's own `VLC_DEPLOYMENT_TARGET_TVOS` (11.0) and `…_SIMULATOR` (12.0) in `build.conf` to the same value. That forces another full contrib and libvlc build (~10 min), and changes the availability floor VLC's code compiles against.
2. **Resuming:** the three libvlc slices and the 27.0 contribs on disk are from this clean Xcode 27 run with 0019. After (a) or (b), rerunning the recipe would reuse them, since only the archive step failed. That counts as the same clean build continued, not a return to the 26.6 objects. After (c), everything rebuilds. Acceptable?

## R2-9. Least-sure items

1. **Whether 11.0 matters beyond the archive check.** Xcode 27's clang compiled libvlc and the contribs with an 11.0 minimum and no warning surfaced in the grep. Whether a framework with VLCKit's target raised but libvlc's left at 11.0 behaves any differently at runtime is unknown until one is built.
2. **The fix itself, untested on a device.** The patch is proven by VLC's test and by the simulation of the misordered stream only; no framework containing it has run on the device.
3. **Host tools kept from 26.6.** `extras/tools/build` (make, meson, ninja and friends, built for the Mac with Xcode 26.6) was not rebuilt. It produces no framework code, but "clean" here excludes it.

## Appendix R2-A — the temporary item 5 harness (written, never built, deleted; not committed)

```swift
//
//  Diag1eUITests.swift — temporary harness for pass 1e rerun 2 (2026-09-14). Not committed.
//  Built from the diag4 harness (attach mode for tracer runs launched by `devicectl process launch --console`,
//  per-minute subtitle-panel anchor, 3-minute watch) and the pass 1c harness (seek run, frame step).
//

import XCTest

final class Diag1eUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]

    override func setUp() { continueAfterFailure = true }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func note(_ t: String) { let a = XCTAttachment(string: t); a.name = "note"; a.lifetime = .keepAlways; add(a); NSLog("[p1e] %@", t) }
    private func press(_ b: XCUIRemote.Button, _ n: Int = 1, wait: UInt32 = 1) { for _ in 0..<n { remote.press(b); sleep(wait) } }
    private func focusedIds() -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex.map { $0.identifier.isEmpty ? "(\($0.label))" : $0.identifier }
    }
    private func isFocused(_ id: String) -> Bool { focusedIds().contains(id) }
    private func isFocused(prefix: String) -> Bool { focusedIds().contains { $0.hasPrefix(prefix) } }
    @discardableResult private func moveUntilFocused(_ id: String, pressing b: XCUIRemote.Button, limit: Int = 8) -> Bool {
        for _ in 0..<limit { if isFocused(id) { return true }; press(b) }
        return isFocused(id)
    }
    private func focusHeader() { for _ in 0..<8 { if isFocused(prefix: "tab.") || isFocused("sort") { return }; press(.up) } }
    private func focusHeaderItem(_ id: String) {
        focusHeader(); guard let target = headerOrder.firstIndex(of: id) else { return }
        for _ in 0..<8 { if isFocused(id) { return }; let cur = headerOrder.firstIndex { isFocused($0) } ?? 0; press(cur < target ? .right : .left) }
    }
    private func selectTab(_ name: String) { focusHeaderItem("tab.\(name)"); press(.select, wait: 2) }
    private func openPoster(_ id: String, tab: String) {
        selectTab(tab); press(.down); if !isFocused(prefix: "poster.") { press(.down) }
        _ = moveUntilFocused(id, pressing: .right, limit: 6) || moveUntilFocused(id, pressing: .left, limit: 6)
        press(.select, wait: 3)
        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 20), "detail did not open; focus \(focusedIds())")
        sleep(2)
    }
    private func pressPlay() { if !isFocused("play") { moveUntilFocused("play", pressing: .up, limit: 6) }; press(.select, wait: 2) }
    private func stamp() -> String { let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date()) }
    private func openStargate(_ edition: String, dir: XCUIRemote.Button) {
        openPoster("poster.Stargate", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.buttons["pick.\(edition)"].waitForExistence(timeout: 5)); moveUntilFocused("pick.\(edition)", pressing: dir, limit: 3); press(.select, wait: 2)
    }
    private func openMagicians() {
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30)); sleep(2)
        moveUntilFocused("episode.1.1", pressing: .down, limit: 4); press(.select, wait: 2)
    }

    /// Launch variants: the app is already running (started by `devicectl … --console` with the run's VLCParams).
    private func attach() {
        app = XCUIApplication(); app.activate()
        note("attached at \(stamp())")
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
    }
    private func launchFresh() {
        app = XCUIApplication(); app.launch()
        note("launched at \(stamp())")
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "library did not load")
        sleep(3)
    }

    /// Minute anchor (diag3/diag4): subtitle panel opened, photographed, closed with "Off" → stamped app log lines.
    private func anchor(_ tag: String, _ m: Int) {
        press(.up, wait: 1); press(.up, wait: 1); press(.right, wait: 1); press(.select, wait: 1)
        shot("p1e-\(tag)-min\(m)")
        note("\(tag): minute \(m) anchor at \(stamp())")
        press(.select, wait: 1); press(.down, wait: 1)
    }
    private func watch(_ tag: String, minutes: Int = 3) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("\(tag): player up at \(stamp())")
        for m in 1...minutes {
            sleep(55)
            anchor(tag, m)
            if !app.otherElements["player"].exists { note("\(tag): player gone at minute \(m)"); break }
        }
        press(.menu, wait: 3)
    }

    func tA_WonderWoman() { attach(); openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay(); watch("ww") }
    func tA_Divergent()   { attach(); openPoster("poster.Divergent", tab: "Movies"); pressPlay(); watch("divergent") }
    func tA_Magicians()   { attach(); openMagicians(); watch("magicians") }
    func tA_StargateExtended() { attach(); openStargate("Extended", dir: .up); watch("stargate-extended") }

    /// Pass 1c seek test on Wonder Woman, five +30 s presses at a user's pace (~1 s apart), then 60 s of playback.
    func tS_SeekWonderWoman() {
        launchFresh(); openPoster("poster.Wonder Woman", tab: "Movies"); pressPlay()
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("seek: player up at \(stamp())")
        sleep(20)
        press(.down, wait: 1)
        press(.up, wait: 1); shot("p1e-seek-pre"); press(.down, wait: 1)
        sleep(4)
        note("seek: five +30 s skips begin at \(stamp())")
        for _ in 0..<5 { remote.press(.right); sleep(1) }
        note("seek: skips end at \(stamp())")
        sleep(1); shot("p1e-seek-after-skips")
        sleep(56)
        press(.up, wait: 1); shot("p1e-seek-min1"); note("seek: minute shot at \(stamp()), player exists \(app.otherElements["player"].exists)"); press(.down, wait: 1)
        press(.menu, wait: 3)
    }

    /// Pass 1c frame step on Stargate Extended while paused: five forward clicks (D008 native gotoNextFrame).
    func tF_FrameStepStargate() {
        launchFresh(); openStargate("Extended", dir: .up)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "player did not appear; focus \(focusedIds())")
        note("framestep: player up at \(stamp())")
        sleep(20)
        press(.down, wait: 1)
        press(.select, wait: 2)
        shot("p1e-framestep-paused")
        note("framestep: paused at \(stamp())")
        for i in 1...5 { press(.right, wait: 2); shot("p1e-framestep-forward-\(i)"); note("framestep: forward \(i) at \(stamp())") }
        press(.menu, wait: 3)
    }
}
```

---

# Pass 1e RERUN 3 — package the Xcode 27 build — STOPPED before item 2's run (the recipe would recompile) — 2026-09-14

**Item 1 is done. Item 2 was not run, because the evidence shows the recipe would recompile libvlc and contribs rather than only repackage.** Every run, VideoLAN's script resets libvlc to `5dd4aebda` and re-applies all 19 patches with `git am`. That rewrites 65 source files, including two contrib rule files, with fresh timestamps, so `make` would rebuild what depends on them. The script's own `-n -l` flags would package only, but the recipe does not pass them, and changing that is outside the numbered items (§R3-3, question 1).

No framework was built. `Frameworks/` is still the 12:50 Xcode 26.6 build without 0019. No app build, install or device run; no D017/D018. The rerun-2 libvlc slices and 27.0 contribs are untouched. Committed locally, not pushed.

## Result per item

| Item | Result |
|---|---|
| 1 tvOS deployment target 26.0 in the recipe | **Done (written, not yet run).** `tools/vlckit-truehd/build.sh` step 2d, before the VLCKit build: `sed` sets `TVOS_DEPLOYMENT_TARGET = 26.0;` in `VLCKit.xcodeproj/project.pbxproj`, replacing the project's 11.0 in 4 build configurations (pbxproj lines 1381, 1472, 1651, 1727). It is idempotent and stops if any other tvOS target value remains. libvlc's `VLC_DEPLOYMENT_TARGET_TVOS` is unchanged. README: one line. `sh -n tools/vlckit-truehd/build.sh` → syntax ok. |
| 2 Rerun the recipe, packaging only | **Not run — the recipe as written would recompile** (§R3-2). |
| 3 App build, install, fresh container | Not started. |
| 4 Device verification | Not started. |
| 5 D017, D018, COLD-START | Not written (no framework with 0019 exists). |

## R3-1. The recipe change (item 1)

```sh
# Step 2d — pass 1e rerun 3 (D018): Xcode 27 refuses to archive VLCKit.xcodeproj with its tvOS deployment target 11.0
# ("supported deployment target versions is 15.0 to 27.0.x"); VideoLAN's archive call overrides only the iOS target.
# Set the project's TVOS_DEPLOYMENT_TARGET to 26.0 (the app's minimum, D004) before the build. libvlc's own minimum
# (extras/package/apple/build.conf) is left as is. Idempotent; stops if any other tvOS target value remains.
PBX="$BUILD_DIR/VLCKit/VLCKit.xcodeproj/project.pbxproj"
sed -i '' 's/TVOS_DEPLOYMENT_TARGET = 11\.0;/TVOS_DEPLOYMENT_TARGET = 26.0;/' "$PBX"
[ "$(grep -c 'TVOS_DEPLOYMENT_TARGET = ' "$PBX")" = "$(grep -c 'TVOS_DEPLOYMENT_TARGET = 26\.0;' "$PBX")" ] || { echo "VLCKit.xcodeproj: a TVOS_DEPLOYMENT_TARGET other than 26.0 remains" >&2; exit 1; }
echo "VLCKit.xcodeproj TVOS_DEPLOYMENT_TARGET = 26.0 ($(grep -c 'TVOS_DEPLOYMENT_TARGET = 26\.0;' "$PBX") build configurations)"
```

## R3-2. Why a recipe rerun would not be packaging only

1. **`compileAndBuildVLCKit.sh:522-541`**, when `libvlc/vlc` already exists and `-n` is not given, runs `git fetch --all`, `git reset --hard ${TESTEDHASH}` and `git am ${ROOT_DIR}/libvlc/patches/*.patch` on every run. `build.sh` calls the script with `-v -f -t -r`, without `-n`.
2. **What the 19 patches touch** (`git diff --stat 5dd4aebda HEAD` in libvlc): 65 files changed, 2569 insertions(+), 176 deletions(-). By area: 13 contrib/src; 11 modules/access; 5 modules/demux; 4 modules/misc; 3 modules/codec; 3 include/vlc; 1 test/Makefile.am; 1 test/libvlc; 1 src/player; 1 src/network; 1 src/misc; 1 src/libvlccore.sym; 1 src/libvlc.c; 1 src/input; 1 NEWS/; 1 modules/stream_out; 1 modules/common.am; 1 modules/access_output; 1 lib/meson.build; 1 lib/media.c; 1 lib/media_player.c; 1 lib/media_internal.h; 1 lib/Makefile.am; 1 lib/libvlc.sym; 1 lib/downloader.c; 1 include/vlc_stream.h; 1 include/vlc_player.h; 1 include/vlc_http.h; 1 include/meson.build; 1 extras/tools; 1 doc/Makefile.am; 1 doc/libvlc; . Contrib files:
  - `contrib/src/ffmpeg/avcodec-enable-audiotoolbox-ac3.patch`
  - `contrib/src/ffmpeg/rules.mak`
  - `contrib/src/live555/DISABLE_LOOPBACK_IP_ADDRESS_CHECK.patch`
  - `contrib/src/live555/SHA512SUMS`
  - `contrib/src/live555/add-pkgconfig-file.patch`
  - `contrib/src/live555/android-no-ifaddrs.patch`
  - `contrib/src/live555/expose_server_string.patch`
  - `contrib/src/live555/in_addr-s_addr-field.patch`
  - `contrib/src/live555/live555-nosignal.patch`
  - `contrib/src/live555/live555-vista-inet.patch`
  - `contrib/src/live555/no-null-reference.patch`
  - `contrib/src/live555/rules.mak`
  - `contrib/src/live555/winstore.patch`
3. **Timestamps from rerun 2 show the dependency.** The patched source `modules/codec/videotoolbox/dpb.c` is dated **16:49:49** (written by that run's `git am`); its object `build-appletvos-arm64/build/modules/codec/videotoolbox/libvideotoolbox_plugin_la-dpb.o` is dated **16:52:37**. `contrib/src/ffmpeg/rules.mak` is 16:49:49 and `contrib-arm64-apple-tvOS_11.0/.ffmpeg` 16:51. A new reset + `git am` gives all 65 files a new time, newer than their objects and stamps.
4. **libvlc's `extras/package/apple/build.sh` runs the builds every time for each slice.** It runs contrib `../bootstrap` and `$MAKE` (lines ~711-742) unless contribs are disabled, then `configure` and `$MAKE` / `$MAKE install` for libvlc (lines ~830-842), then regenerates the static module list and `libvlc-full-static.a`. With the patched sources newer than their objects, `make` recompiles those objects (at least the libvlc ones; the contrib stamps may also trigger FFmpeg/live555 rebuilds) in all three slices before any packaging.

## R3-3. The packaging-only path the script already has (not taken)

- `-n` (`NONETWORK=yes`, line 428): skips the fetch / reset / `git am` block (line 522). The libvlc tree stays at `e50d9ac36a` with the 19 patches, the state rerun 2 compiled.
- `-l` (`SKIPLIBVLCCOMPILATION=yes`, line 431): skips building the host tools (line 564) and every `buildLibVLC` call (line 229). The static-lib steps then `lipo` the existing `build-appletv*/static-lib/libvlc-full-static.a` (747.2 / 750.5 / 785.0 MB from rerun 2), and the script goes on to the two `xcodebuild archive` calls and `-create-xcframework`.

Running `compileAndBuildVLCKit.sh -v -f -t -r -n -l` once, after step 2d's project edit, would therefore package today's Xcode 27 slices with the 26.0 project target. That is either a new recipe option (e.g. a `PACKAGE_ONLY=1` switch adding `-n -l`) or a one-off direct call outside the recipe — both are extras under the scope lock.

## R3-4. Files touched

| Step | Files |
|---|---|
| 1 | `tools/vlckit-truehd/build.sh` (step 2d), `tools/vlckit-truehd/README.md` (one line) |
| 2–5 | none |
| record | this section |

Unchanged: `~/vlckit-build` (the step 2d edit has not run, so `VLCKit.xcodeproj` still says 11.0; libvlc tree `e50d9ac36a`, clean; rerun-2 slices and contribs intact), `Frameworks/`, the app, `DECISIONS.md`, `COLD-START.md`.

## R3-5. What could not be tested

- **Items 2–4 entirely**, so the before/after drop table still has no "after" (the "before" is in §R2-5).
- **Whether contrib stamps would really rebuild FFmpeg and live555** after a new `git am`. I read it from the timestamps and the rules; I did not run it, since running it is the recompile the pass forbids.

## R3-6. Questions for the owner

1. **How should the Xcode 27 slices be packaged?**
   - (a) A recipe switch, e.g. `PACKAGE_ONLY=1 tools/vlckit-truehd/build.sh`, which runs steps 2b–2d and calls VideoLAN's script with `-v -f -t -r -n -l`, then the `nm` check and the copy. **My recommendation:** it keeps "everything through the recipe" and reuses today's objects exactly.
   - (b) A one-off direct call of `compileAndBuildVLCKit.sh -v -f -t -r -n -l` after running step 2d by hand, with the recipe otherwise unchanged.
   - (c) Let the recipe recompile. The result is still Xcode 27 throughout, and should take minutes rather than a clean build's hour, but it is not the reuse this pass asked for.
2. **`-n` also skips `git fetch --all`.** Is it acceptable that a packaging-only run never touches the network? The tree it packages is the one rerun 2 fetched and patched.

## R3-7. Least-sure items

1. **How much a rerun would rebuild.** The size of the recompile is inferred from make's timestamp rules and the files the patches touch, not measured. It could be only the ~52 libvlc files plus relinks, or also FFmpeg and live555.
2. **Whether `-l` still regenerates anything per slice** before `lipo`. The code shows it goes straight from the existing `libvlc-full-static.a` to `xcodebuild archive`, but that path has never been run in this project.
