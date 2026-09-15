# Pass 2f — patch 0021 (candidate C1) and a picture that follows the thumb — STOPPED at step 9 — 2026-09-15

**Result.**
- **Patch 0021 does what pass 2e predicted.**
  - **The change:** one condition on one line, `es_out.c:3661`, so a late PCR is not compensated while es_out is paused.
  - **Tests:** VLC's own tests give identical results before and after on a macOS build (`src/` 28 pass, `test/` 73 pass, the same failures in both, all host-build gaps).
  - **Framework:** the full recipe builds it with 21 patches; both slices check.
  - **On Home Theater:** 20 paused scrubs on four films (Stargate, Wonder Woman, Divergent, Magicians S1E1) show **0 "PCR is called late" lines during any drag**. Every landing played from within 81 ms before to 305 ms after its target, 2–273 ms after the press. The accepted behaviours of step 7 and the paused states of step 8 match HEAD.
- **Stopped at step 9, for three reasons, all quoted in §4.**
  1. **Magicians: the reported time freezes after landing.**
     - Every one of its five endings logged `clock gap, unexpected stream discontinuity`.
     - After four of them VLCKit's time stopped moving: `land +3 s time=238848 ms` while the trace showed 241 810 ms on screen, and the on-screen clock read 03:59.
     - The next drag then started from the stale time: `begin at 238848 ms` 30 s later.
     - HEAD's pass 2d Magicians and Stargate sessions logged 0 clock gaps.
  2. **The picture does not track during the drag on the two HEVC films.**
     - Wonder Woman showed its drag seeks' pictures for 1–5 of 8–9 seeks, Divergent 1–4 of 8–9; the lift picture took up to 1.14 s.
     - On Magicians scrub 3 the lift seek's picture never appeared: the screen held the previous seek's `262298` ms for a 270 134 ms target.
     - Stargate (MPEG-2) tracked 7–8 of 8–9 seeks in 84–181 ms.
  3. **Stargate scrub 4 dropped 7 pictures at landing** (`missing 30658 ms`), against 1 in pass 2d's HEAD run of the same scrub.
- **Not done, as step 9 says.** No further fix. No D021 update, no new decision, no app commit (step 10). No COLD-START recipe count change beyond a stop note, and no upstream-draft change (steps 11–12).
- **State, snapshotted and not changed after the runs.**
  - **Home Theater:** runs the 0021 build with the uncommitted app change and harness hook.
  - **Frameworks and libvlc:** `Frameworks/` holds the 21-patch framework, and libvlc is at the recipe's 21-patch tree.
  - **Uncommitted:** the app code, the harness, and `tools/vlckit-truehd/` (0021, `build.sh`, README). All saved as copies in `reports/logs/`.
  - **Committed locally:** only the report, the evidence and the COLD-START note. Nothing pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Patch 0021 | **Done, uncommitted.** `tools/vlckit-truehd/0021-es_out-no-late-pcr-compensation-while-paused.diff`, `git format-patch` form as 0019/0020; `build.sh` step 2c'' copies it to `libvlc/patches/0021-….patch` after 0020; README line. One line: `if (p_pgrm != p_sys->p_pgrm \|\| p_sys->p_next_frame_es != NULL \|\| p_sys->b_paused)`. |
| 2 VLC tests before/after | **Done, no difference** (§1). No expectation encoded the old behaviour, so 0021 carries no test change. |
| 3 Full recipe, checks | **Done** (§2). |
| 4 Picture follows the thumb | **Done, uncommitted** (§3). |
| 5 Build, install | **Done.** `** TEST BUILD SUCCEEDED **`, `App installed`, harness hook included. |
| 6 Four films, paused scrubs | **Run: 20 scrubs** (§4 table). **Tracking fails on the HEVC films and Magicians scrub 3; Magicians' time freezes** (§4). |
| 7 Accepted behaviours | **Run on HEAD and 0021: same on all four films** (§5). |
| 8 Paused states C1 runs through | **Run on HEAD and 0021: same** (§6). |
| 9 Stop conditions | **HIT — STOP** (§4). |
| 10–12 | **Not done** (stopped). |

## 1. Step 2 — VLC's own tests, before and after 0021

Evidence: `reports/logs/2f-vlc-tests.txt`.
- **Build.** Pass 1i's host macOS build (`~/vlckit-build/host-test-1i`, same configure), against the recipe tree after 0020 (`017a5fabe2`) for **before**, with 0021 applied by `git am` for **after**. `make` recompiled `input/libvlccore_la-es_out.lo` and the revision objects.
- **Two host-build obstacles, both before any change:**
  - **bison.** `git am` had rewritten mtimes, so make regenerated `modules/demux/json/grammar.c`, and Xcode's bison refused it (`bison: invalid option -- W`). The rebuild used libvlc's own `extras/tools/build/bin/bison`, which the recipe had built; nothing was installed.
  - **One test program doesn't link.** `test_modules_demux_json` fails with `duplicate symbol '_json_read'` / `'_json_parse_error'`, which stops `make -C test check` before any test runs (also with `-k`). So `test/` ran with `check_PROGRAMS`/`TESTS` set to the other 88 programs, as pass 1i did for the player group.

**Results:**

| Suite | Before 0021 | After 0021 |
|---|---|---|
| `make -C src check` (30) | 28 pass, 1 skip (`test_url`), 1 fail (`test_interrupt`, exit 139, 3 of 3 re-runs) | identical |
| `test/` (88 programs) | 73 pass, 7 skip, 8 fail | identical: `## differences before → after (test/ list)` → `no difference` |

- **The clock and player tests:**
  - `test_input_clock` PASS, `test_input_es_out` PASS, `test_src_clock_start` PASS;
  - all 19 working `test_src_player_*` PASS (`pause`, `seeks`, `next_prev`, `titles`, `tracks`, `es_selection`, …), and `test_src_player_attachments` FAIL (no BMP encoder, as in pass 1i);
  - `test_src_clock_clock` FAILS in both: `Assertion failed: (converted - expected_system_end == scenario->total_drift_duration), function drift_check, file clock.c, line 662`. That test covers `src/clock/clock.c`, which 0021 doesn't touch.
- **The other failures, identical before and after:**
  - `test_libvlc_media` and `test_src_preparser_cmp_internal_external`: exit 139;
  - `test_src_input_decoder`: `Assertion failed: (subpic != NULL)`;
  - `test_src_video_output_spu`: `Assertion failed: (spu)`;
  - `test_modules_video_output_opengl_filters`: `GL_INVALID_OPERATION`;
  - `test_src_misc_image_cvpx`: no PNG encoder.

  All are missing modules or GL in this stripped host build.

## 2. Step 3 — full recipe, 21 patches

- **Run.** `tools/vlckit-truehd/build.sh` (no `PACKAGE_ONLY`), 12:15:40–12:18:48.
  - **Output:** `patch 0018 installed` … `patch 0021 installed`, `VLCKit.xcodeproj TVOS_DEPLOYMENT_TARGET = 26.0 (4 build configurations)`.
  - **Patches:** 21 `Applying:` lines, the last `Applying: input: es_out: do not compensate a late PCR while paused`.
  - **Archive:** `ARCHIVE SUCCEEDED` ×2. The patch lives in `tools/`, and my temporary libvlc worktree was removed before the build.
- **libvlc after the recipe:** `49639abdcd`, status clean, 0021's condition present.

| Slice | `MinimumOSVersion` | `LC_BUILD_VERSION` | `DTXcodeBuild` | `1g:` / `1h:` / `1j:` / `2e:` strings |
|---|---|---|---|---|
| `tvos-arm64` | 26.0 | `platform TVOS minos 26.0 sdk 27.0` | 27A266a | 0 / 0 / 0 / 0 |
| `tvos-arm64_x86_64-simulator` | 26.0 | `platform TVOSSIMULATOR minos 26.0 sdk 27.0` (x86_64 and arm64) | 27A266a | 0 / 0 / 0 / 0 |

- **Device slice `nm`:** `000000000236e730 S _ff_truehd_decoder`.
- **The copy:** `Frameworks/` is identical to the build output.
- **The app's embedded copy** has the same `LC_UUID` as `Frameworks/`' device slice; it is larger only by its signature.

## 3. Step 4 — the app change (uncommitted; `reports/logs/2f-app-with-hook.diff`)

**From pass 2e's diff:**
- `PlayerModel.scrubMoved` schedules a paused seek to the target, at most one per 250 ms (`scrubSeekInterval`).
- `scrubLifted` seeks to the exact target.

**Unchanged from D021:** a scrub only from paused, 25% of the running time per surface width, the target stopping 1 s short of the end, and the pan recognizer.

**Two points D021 doesn't settle for a moving picture. I chose these and flag them (open question 4):**
- **Landing** (click or Play/Pause) makes any pending seek to the target, then `play()`. There is no second seek after Play, because the picture is already at the target. D021's current text says "`play()`, then one seek".
- **Menu** seeks back to where the drag began and stays paused, since the picture has moved. D021 says it "stays paused where the drag began".

**Harness only (not for commit):** the Page Up / Page Down hook in `PlayerHost` (+0.08 / −0.04 of the width over 2 s), as in pass 2d.

## 4. Step 6 — paused scrubs on the 0021 build, and why the pass stopped

**Sessions.** One per film, each a fresh launch: play 30 s, 4 × +30 s, 20 s. Then five paused scrubs:

| Scrub | Pause before | Drag | Ending |
|---|---|---|---|
| 1 | 3 s | forward | Play/Pause |
| 2 | 3 s | back | click |
| 3 | 20 s | forward | click |
| 4 | 20 s | back | Play/Pause |
| 5 | 3 s | forward | Menu |

- **Every press reached the app.** Play/Pause 8 of 8 sent, Page Up/Down 5 of 5, on every run.
- **Test cases:** `tStargateScrub` 329.5 s, `tWonderWomanScrub` 337.9 s, `tDivergentScrub` 336.6 s, `tMagiciansScrub` 340.8 s, all passed.
- **Measures:** `scrub2f.py`, outputs in `reports/logs/2f-analysis.txt`.
  - **Tracked:** of the drag's paused seeks, how many showed a picture within 1 s of their target before the next seek; then the lift seek's time to its target picture, and whether the picture held there until the ending.
  - **+3 s:** the trace's pts on screen 3 s after the press (its error against the target plus the elapsed play), and VLCKit's reported time.
  - **Late resets:** VLC's `ES_OUT_SET_(GROUP_)PCR is called … late` lines from drag start to the ending.
  - **Reads:** demux reads from drag start to the ending.

| Run | # | Paused | Drag | Ending | Target shown (ms) | Tracked during the drag | +3 s trace (error) / VLCKit (ms) | Press → picture (s) | Picture − target (ms) | Dropped / late in 30 s | PCR-late lines | Reads while paused (last PCR − target) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Stargate | 1 | 3 s | fwd | Play/Pause | 332 958 | 8/8, lift 106 ms, held | 335 886 (−42) / 335 960 | 0.030 | −25 | 0 / 2 | 0 | 2 960 (+14.9 s) |
| Stargate | 2 | 3 s | back | click | 285 597 | 7/9, lift 158 ms, held | 288 555 (−14) / 288 600 | 0.028 | +38 | 1 / 0 | 0 | 2 886 (+14.9 s) |
| Stargate | 3 | 20 s | fwd | click | 472 186 | 8/8, lift 132 ms, held | 475 141 (−20) / 475 192 | 0.025 | −81 | 1 / 1 | 0 | 4 028 (+31.8 s) |
| Stargate | 4 | 20 s | back | Play/Pause | 424 834 | 8/8, lift 150 ms, held | 427 811 (+10) / 427 864 | 0.033 | −76 | **7** / 1 | 0 | 4 204 (+31.8 s) |
| Stargate | 5 | 3 s | fwd | Menu | 611 424 (back to 455 463) | 7/8, lift 115 ms, held | 455 505 (0) / 455 463 | 0.063 | +42 from start | 6 / 0 * | 0 | 3 089 (+14.9 s) |
| Wonder Woman | 1 | 3 s | fwd | Play/Pause | 345 096 | **1/8, lift 1 137 ms**, held | 347 556 (−459) / 347 584 | 0.081 | −1 | 0 / 0 | 0 | 9 959 (+1.0 s) |
| Wonder Woman | 2 | 3 s | back | click | 290 532 | **1/8, lift 699 ms**, held | 293 084 (−333) / 293 112 | 0.115 | +50 | 0 / 0 | 0 | 8 386 (+1.1 s) |
| Wonder Woman | 3 | 20 s | fwd | click | 490 380 | 3/9, lift 208 ms, held | 492 909 (−444) / 492 924 | 0.027 | −15 | 0 / 1 | 0 | 10 094 (+1.0 s) |
| Wonder Woman | 4 | 20 s | back | Play/Pause | 435 877 | 5/8, lift 326 ms, held | 438 855 (−20) / 438 893 | 0.002 | +17 | 0 / 0 | 0 | 48 845 (+32.1 s) |
| Wonder Woman | 5 | 3 s | fwd | Menu | 636 124 (back to 466 600) | 3/9, lift 861 ms, held | 466 675 (0) / 466 600 | 0.255 | +75 from start | 0 / 0 | 0 | 10 478 (+1.0 s) |
| Divergent | 1 | 3 s | fwd | Play/Pause | 341 799 | **3/8, lift 572 ms**, held | 344 427 (−326) / 344 438 | 0.046 | −41 | 0 / 0 | 0 | 2 014 (+1.1 s) |
| Divergent | 2 | 3 s | back | click | 288 381 | **1/9, lift 367 ms**, held | 290 874 (−484) / 290 889 | 0.023 | +32 | 0 / 0 | 0 | 1 580 (+1.1 s) |
| Divergent | 3 | 20 s | fwd | click | 486 201 | **1/8, lift 743 ms**, held | 489 072 (−53) / 489 105 | 0.076 | −7 | 0 / 0 | 0 | 2 488 (+1.1 s) |
| Divergent | 4 | 20 s | back | Play/Pause | 433 054 | 4/9, lift 602 ms, held | 435 935 (−72) / 435 962 | 0.047 | −38 | 0 / 0 | 0 | 2 146 (+1.0 s) |
| Divergent | 5 | 3 s | fwd | Menu | 631 273 (back to 463 686) | 2/8, lift 419 ms, held | 463 672 (0) / 463 686 | 0.273 | −14 from start | 0 / 0 | 0 | 1 995 (+1.0 s) |
| Magicians | 1 | 3 s | fwd | Play/Pause | 238 855 | 6/9, lift 140 ms, held | 241 810 (−20) / **238 848** | 0.025 | −47 | 1 / 0 | 0 | 1 345 (+1.2 s) |
| Magicians | 2 | 3 s | back | click | 207 563 † | 6/8, lift 254 ms, held | 210 579 (+35) / **207 563** | 0.019 | −20 | 9 / 2 | 0 | 1 211 (+1.1 s) |
| Magicians | 3 | 20 s | fwd | click | 270 134 † | 4/8, **lift picture never at target** | 273 042 (+27) / 272 806 | 0.119 | +305 | 0 / 0 | 0 | 1 269 (+1.1 s) |
| Magicians | 4 | 20 s | back | Play/Pause | 268 867 | 5/9, lift 204 ms, held | 271 874 (+21) / **268 869** | 0.014 | −29 | 6 / 2 | 0 | 1 142 (+1.2 s) |
| Magicians | 5 | 3 s | fwd | Menu | 331 440 (back to 268 869 †) | 5/8, lift 230 ms, held | 268 837 (0) / 268 869 | 0.084 | −31 from start | 10 / 1 | 0 | 1 271 (+1.2 s) |

\* Stargate 5's 6 drops come at 10.6 s, at the harness's Play after the Menu cancel, not at the cancel.
† The drag started from VLCKit's stale time (see 4.1), not from where the film was.

**What holds:**
- **No lap.** 0 PCR-late lines in all 20 drags. The rebuffers counted are the drag's own seeks (`RESET_PCR` 9–10 per scrub, one per seek).
- **Reads stop at the target.** The demuxer read to 1.0–1.2 s past the target on Wonder Woman, Divergent and Magicians, 15–32 s past on Stargate, instead of pass 2e's 95–333 s.
- **Landings are on target.** Every landing's first picture is −81…+305 ms from its target, 2–273 ms after the press.

### 4.1 Stop 1 — Magicians: a clock gap at every ending, and VLCKit's time freezes

The app log after scrub 1's landing (`reports/logs/2f-c21-magicians-scrub.log.gz`):
```
1:04:40.806 PM [scrub] land playPause from 176284 ms at 238855 ms tick=533239250772
[WARN] picture is too late to be displayed (missing 13855 ms)
1:04:40.837 PM [player] state Playing at 238848 ms
[WARN] clock gap, unexpected stream discontinuity: system_diff: -5396646 stream_diff: 15605
[WARN] feeding synchro with a new reference point trying to recover from clock gap
[WARN] new clock context(1) @240024672
1:04:41.859 PM [scrub] land +1 s time=238848 ms (expected 238855 ms) state Playing
1:04:43.919 PM [scrub] land +3 s time=238848 ms (expected 238855 ms) state Playing
1:05:11.533 PM [player] pause (playPause button) at 238848 ms
1:05:14.798 PM [scrub] begin at 238848 ms tick=533273242205
```
- **What the trace shows.** The picture on screen at +3 s is pts 241 810 ms, and audio decodes and renders after the landing (`audio/2 DEC OUT 261` in 4 s).
- **What the screen shows.** `p2f-magicians-scrub-01-pause3s-fwd-playpause-d-after+3s.jpg` shows the overlay at **03:59 Playing**, 3 s after landing at 03:59. `p2f-magicians-scrub-02-pause3s-back-click-a-mid-drag.jpg` shows the next drag's bar at 03:41, moving back from the stale 03:58, though the film had played on to about 04:28.

**Per ending** (`2f-analysis.txt`, "clock gap per ending"):

| Session | Clock gaps | VLCKit time after the ending |
|---|---|---|
| c21 Magicians | 5 endings, 5 gaps (`system_diff` −5.4, −5.4, −22.2, −22.5, −13.9 s) | frozen after endings 1, 2, 4 and 5; moved after ending 3 (`+1 s 271088`, `+3 s 272806`) |
| c21 Stargate, Wonder Woman, Divergent | 0 | moved |
| HEAD pass 2d Magicians and Stargate (landing = play, then seek) | 0 | moved |
| Pass 2e Magicians (20 patches): the non-lapping scrub 4 | 1 gap | moved |
| Pass 2e Magicians: the lapping scrubs | 0 | moved |

- **So the gap isn't created by 0021.** On this MP4, a paused seek that doesn't lap ends in a clock gap at resume. 0021 makes every paused seek one that doesn't lap.
- **Why the time freezes after some gaps and not others is not established.** No instrumented run in this pass. What the logs show: the gap's `feeding synchro with a new reference point` resets the input clock's reference and opens a new clock context. After ending 3 the audio clock switched to the new context (`clock(audio/2): using clock context(3)`), and the time moved. After ending 1 only `clock(input): using clock context(1)` appears before the +3 s line.

### 4.2 Stop 2 — the picture doesn't track on the HEVC films

Trace, video renders in each seek's window (`2f-analysis.txt` §1 of the STOP evidence):
```
== c21-ww-scrub scrub 1
  seek  176984 ms: window   254 ms | renders   2 | distinct pts [176927] | picture at target after 165 ms
  seek  198175 ms: window   257 ms | renders   0 | distinct pts [] | picture at target after None ms
  … (the same for 217953, 239143, 260334, 281524, 302715, 323905)
  seek  345096 ms: window  8644 ms | renders  89 | distinct pts [345095] | picture at target after 1137 ms
== c21-stargate-scrub scrub 1
  seek  178296 ms: window   254 ms | renders   2 | distinct pts [178278] | picture at target after 97 ms
  seek  196492 ms: window   264 ms | renders   3 | distinct pts [196413] | picture at target after 84 ms
  … every seek shows its picture in 84–181 ms
== c21-magicians-scrub scrub 3
  seek  262312 ms: window   242 ms | renders   1 | distinct pts [254490] | picture at target after None ms
  seek  270134 ms: window  8656 ms | renders   1 | distinct pts [262298] | picture at target after None ms
```
- **HEVC.** Wonder Woman and Divergent, decoded by VideoToolbox, need 0.2–1.1 s per paused seek to show a picture, so a 250 ms cadence cancels most of them. During a drag the screen stays on the first seek's picture, then jumps to the lift target.
- **Magicians scrub 3.** During the 8.7 s hold the only render after the lift seek is the previous seek's picture (262 298 ms), so the target picture never appeared before landing.
- **Why the lift seek showed no picture there** is not traced. This scrub also started from the stale time of §4.1.

### 4.3 Stop 3 — Stargate scrub 4 drops 7 pictures at landing

```
[WARN] picture is too late to be displayed (missing 30658 ms)
[WARN] picture is too late to be displayed (missing 30625 ms)
… 7 lines; trace: 7 video 'toolate' events 34–35 ms after the press
```
- **The count.** Pass 2d's HEAD run of the same scrub (20 s paused, back, Play/Pause) dropped 1.
- **The size.** The dropped pictures' lateness (~30.6 s) is about the pause plus the drag.
- **The landing itself** was on target (first picture −76 ms, +3 s error +10 ms).
- **Not diagnosed.**

## 5. Step 7 — the accepted behaviours, HEAD and 0021

**Session per film:**
1. Play 30 s.
2. Up, Up, Select (the audio panel), Menu.
3. +30 s, then −10 s.
4. Pause; 5 left + 5 right clicks with a screenshot each.
5. While paused: an audio switch, and subtitles on, then off.
6. Play, 60 s.
7. A plain pause of ~80 s, then Play, 60 s.

**Where it ran:**
- **HEAD:** the app at HEAD with the 20-patch framework, run before any 0021 build was installed.
- **0021:** the build of §3.

All eight test cases passed. Output: `ctl2f.py` / `fs2f.py` in `2f-analysis.txt`.

| Film | Menu closes the open panel | +30 s / −10 s | Frame step: one picture per click, the right clicks retrace the left (MAD) | Play after steps + switches: reads while paused, dropped / late | Plain ~80 s pause then Play: reads while paused, dropped / late | PCR-late lines while paused |
|---|---|---|---|---|---|---|
| Stargate HEAD | `panel closed`, no dismiss | 42 000→72 000, 74 015→64 015 | yes, 0 0 0 0 0 | 347, 19 / 0 | 0, 0 / 0 | 0 |
| Stargate 0021 | same | 41 208→71 208, 73 243→63 243 | yes, 0 0 0 0 0 | 397, 17 / 1 | 0, 0 / 0 | 0 |
| Wonder Woman HEAD | same | 42 000→72 000, 74 013→64 013 | yes, 0 0 0 0 0 | 7 458, 16 / 1 | 0, 0 / 1 | 0 |
| Wonder Woman 0021 | same | 42 000→72 000, 74 013→64 013 | yes, 0 0 0 0 0 | 8 188, 14 / 1 | 0, 0 / 0 | 0 |
| Divergent HEAD | same | 42 000→72 000, 74 000→64 000 | yes, 0 0 0 0 0 | 1 044, 19 / 1 | 0, 0 / 1 | 0 |
| Divergent 0021 | same | 42 000→72 000, 74 000→64 000 | yes, 0 0 0 0 0 | 1 041, 19 / 1 | 0, 0 / 0 | 0 |
| Magicians HEAD | same | 42 000→72 000, 73 981→63 981 | yes, 0 0 0 0 0 | 698, 22 / 2 | 0, 0 / 0 | 0 |
| Magicians 0021 | same | 42 000→72 000, 73 982→63 982 | yes, 0 0 0 0 0 | 662, 28 / 2 | 0, 0 / 0 | 0 |

- **After steps + switches:** the first picture is the paused picture in every run, e.g. Stargate HEAD `first render pts 66900001` for `play at 66900 ms`, 0021 `66116001` for `66116 ms`. The drops are D020's known drop after frame steps.
- **After the plain pause:** 0 reads while paused, and the picture resumes where it paused, e.g. Wonder Woman 0021 `app play at 130648 ms | … first render pts 130714001`.
- **The same in HEAD and 0021.** The 60 s position after each resume, and the audio panel contents, match in both.

## 6. Step 8 — the paused states C1 also runs through, HEAD and 0021

- **Audio and subtitle track switches while paused.** Same actions in both builds (§5):

  | Film | Audio | Subtitles |
  |---|---|---|
  | Stargate | `audio/2` → `audio/3` | `spu/4` re-selected, then `off` |
  | Wonder Woman | TrueHD `audio/2` → AC-3 `audio/3` | PGS `spu/5` on, then `off` |
  | Divergent | `audio/2` re-selected (one track) | SRT `spu/3` on, then `off` |
  | Magicians | one track, nothing to switch | none |

  - **Identical selections:** `now selected` lines and `ES track (un)selected` are the same in both builds, e.g. Wonder Woman `ES track unselected: 'audio/2' (fourcc: 'mlpa')`, `ES track selected (forced): 'audio/3'`.
  - **Clock:** 0 PCR-late lines and 0 `ES_OUT_RESET_PCR` during those paused stretches, in both builds.
  - **Resume:** the resume numbers in §5 match.
- **Edition change while paused** (Stargate Extended → Theatrical) and **episode change while paused** (Magicians S1E1 → S1E2).
  - **Where C1 isn't.** Menu dismisses the paused player (`[player] dismiss at 32739 ms, state Paused` → `state Stopped`), and a new player starts. So the paused es_out is torn down, not carried into the new title; C1 is not on this path.
  - **Results** (`chg2f.py`):

    | Change | Build | First picture | Dropped / late in 30 s | PCR-late lines | Errors |
    |---|---|---|---|---|---|
    | Edition | HEAD | 0.001 ms | 4 / 4 | 0 | 0 |
    | Edition | 0021 | 0.001 ms | 4 / 4 | 0 | 0 |
    | Episode | HEAD | 69.367 ms | 0 / 0 | 0 | 0 |
    | Episode | 0021 | 69.367 ms | 0 / 0 | 0 | 0 |

- **Not tested: title or chapter change inside one input while paused.** The app has no control for it.

## 7. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1 | `tools/vlckit-truehd/0021-es_out-no-late-pcr-compensation-while-paused.diff`, `tools/vlckit-truehd/build.sh` (step 2c''), `tools/vlckit-truehd/README.md` | **No** (stopped). Copies: `reports/logs/2f-0021-es_out-no-late-pcr-compensation-while-paused.diff.txt`, `reports/logs/2f-recipe-build-readme.diff` (committed) |
| 2 | `~/vlckit-build/host-test-1i` (host build, outside the repo); `reports/logs/2f-vlc-tests.txt` | Evidence committed |
| 3 | `Frameworks/VLCKit.xcframework` (21 patches), `~/vlckit-build` | Git-ignored / outside the repo |
| 4 | `Marlin Media TV/PlayerModel.swift` (paused seeks, landing, Menu back to the start), `Marlin Media TV/PlayerHost.swift` (harness hook, never for commit) | **No.** Copy: `reports/logs/2f-app-with-hook.diff` (committed) |
| 5–8 | `Marlin Media TVUITests/Diag2fUITests.swift` (temporary) | **No.** Copy: `reports/logs/2f-harness-Diag2fUITests.swift.txt` (committed) |
| 6–8 | `reports/logs/2f-analysis.txt`; 16 logs `reports/logs/2f-{head,c21}-*.log.gz` (224 KB total); `reports/screenshots/2f/` (16) | Committed |
| 9 | This report; `COLD-START.md` (pass 2f stop note) | Committed |

- **Not touched:** 0007, 0018, 0019, 0020 (shasums `41df2136…`, `a491edd8…`, `39a73a44…`, `3ea7c4f2…` unchanged); `DECISIONS.md`; `reports/logs/1k-upstream-videolan-draft.md`; Design/; Marlin DVR TV; VLCKit's private player pointer.
- **Constraints kept:**
  - `TVOS_DEPLOYMENT_TARGET = 26.0` in both configurations;
  - Home Theater only, no simulator;
  - largest committed file 18 KB;
  - no UUID or device UDID in committed files;
  - run names non-empty, and no scratch folder deleted: the traces (4–108 MB) stay in scratch.
- **Pushed:** nothing.

**State left as the stop found it:**
- **Home Theater:** runs the 0021 build (21-patch framework, step-4 app change, harness hook).
- **Frameworks and libvlc:** `Frameworks/` is the 21-patch framework; libvlc is at `49639abdcd`.
- **Uncommitted in the working tree:** the two player files, `Diag2fUITests.swift`, and the three `tools/` files.

## 8. What could not be tested live, and what was traced instead

- **The gesture on the real remote.** Drags were scripted through the model, as in passes 2a–2e.
- **Why the Magicians time freezes.** No instrumentation this pass. Traced instead: the clock-gap and clock-context lines per ending, VLCKit's +1/+3 s times against the trace pts, and screenshots.
- **Why HEVC paused seeks take 0.2–1.1 s to show a picture.** Traced instead: renders per seek window. Decoder timing was not traced.
- **Title or chapter change within one input while paused.** No control in the app. Edition and episode changes stop the input (§6).
- **The late median after resume (pass 2e's C1 risk 1).** No `pts_delay increased` line appeared after any resume in these runs. The paused late values were not logged.
- **Audio at landing.** Not measured.

## 9. Open questions

1. **The Magicians clock gap and frozen time.**
   - **Option A:** an instrumented pass on the MP4 resume path, the input clock's `last.system` and reference at a resume after a paused seek, to decide whether 0021 needs a companion change.
   - **Option B:** drop 0021.
2. **Tracking on HEVC.** Keep a moving picture only where the decoder can keep up? Or change how the drag seeks (for example, only after the thumb rests)? Or accept that the picture shows the lift target only?
3. **Keep or revert the recipe and device state.** Home Theater, `Frameworks/` and the libvlc tree now carry 0021, uncommitted in `tools/`. Keep them for the next pass, or rebuild with 20 patches and reinstall HEAD?
4. **The two design points of §3.** Landing plays without a second seek; Menu seeks back to the start. D021's current text describes the no-moving-picture flow.
5. **`test_src_clock_clock` fails on this host build before and after.** Look into it, or accept it as a host artefact like `test_interrupt`?

## 10. Least-sure items

1. **Stop 1's scope.** Only Magicians (the one MP4) was run. Whether other MP4s behave the same is not known. A clock gap after a non-lapping paused seek already happened once in pass 2e's 20-patch build, so 0021 exposes it rather than creates it. That rests on one earlier instance.
2. **"Tracked".** It is defined as a render within 1 s of the seek target before the next seek. A picture that appears just after the next seek starts isn't counted, so Wonder Woman's and Divergent's counts may understate what the eye sees.
3. **Stargate scrub 4's 7 drops** are one run against pass 2d's one run. The drops after scrub 5 follow a Play the pass 2d harness never pressed.
4. **The landing design choice (§3)** shapes the landing numbers. A landing with a second seek after Play (D021's current rule) was not run on the 0021 build.
