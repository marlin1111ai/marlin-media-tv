# Pass 2b — VLC's fast seek on the scrub path — STOPPED at step 2 (cannot be scoped as a media option or player setting) — 2026-09-15

**Result.**
- **Stopped before any change, at your call.** Step 2's named mechanisms can't make only the scrub seeks fast:
  - **The media option does nothing.** In this libvlc tree nothing reads `input-fast-seek`. It is declared (`src/libvlc-module.c:1897`) and created on the input (`src/input/var.c:87`); the only readers are the Qt and macOS preference dialogs. The mp4 demuxer's "use input-fast-seek to avoid" is only log text (`modules/demux/mp4/mp4.c:1955`).
  - **There is no player setting.** VLCKit's public headers have no seek-speed property or method, and its time setter always asks for a precise seek: `libvlc_media_player_set_time(_playerInstance, time_us, NO)` (`VLCMediaPlayer.m:1034`).
- **Fast versus precise is a per-seek argument.** `libvlc_media_player_set_time(p_mi, i_time, b_fast)` maps `b_fast` to `VLC_PLAYER_SEEK_FAST` (`lib/media_player.c:1509`). That reaches the input as `b_fast_seek` (`src/player/input.c:175`) and the demuxer as `!fast_seek` (`src/input/input.c:1962`, `1971`).
- **The one scoped route needs a workaround.** Read VLCKit's private `_playerInstance` through the Objective-C runtime (it is in the metadata as `_OBJC_IVAR_$_VLCMediaPlayer._playerInstance`) and call the exported C function `_libvlc_media_player_set_time` from `PlayerModel`. Its header ships but is excluded from the Swift module map.
  - **Your answer:** I asked whether to use it or stop; you chose **STOP and report**.
- **Not done:**
  - Step 1 was only checked: the harness diff applies cleanly to HEAD. Nothing was applied.
  - Steps 3–7: no build, no install, no device runs, no step-6 checks.
  - Step 4's table has no pass 2b numbers.
  - There is no step-5 verdict on fast seek.
- **Step 7: the scrub code is not worth committing.** Pass 2a's landing overshoot (27.7–30 s past the target on Magicians) is unchanged and untested against fast seek. The pass allows a commit only if every landing is within one second.

**State.**
- **Working tree:** unchanged from pass 2a. The three player files carry `reports/logs/2a-scrub-app.diff`, uncommitted (tree diff shasum `efd3ac62…` = the saved file's). No harness hook, no `Diag2aUITests.swift`.
- **Home Theater:** still runs pass 2a's final build (scrub, no hook).
- **Untouched:** `tools/vlckit-truehd/`, `Frameworks/`, libvlc, `DECISIONS.md`, Design/, Marlin DVR TV.
- **Committed locally:** this report, `reports/logs/2b-fast-seek-recon.txt` and the COLD-START note. Nothing pushed.

## Result per step

| Step | Result |
|---|---|
| 1 Re-apply the 2a diffs | **Checked, not applied.** `2a-harness-app.diff` is `2a-scrub-app.diff` plus the 19-line Page Up/Down hook (0 lines removed), so it is the one diff to apply; applying both in turn would conflict. `git apply --check` of it on copies of HEAD `1324f17`'s three player files passes. Not applied, because step 2 stopped first. |
| 2 `input-fast-seek` on the scrub seeks only | **STOP.** No media option or player setting does it (§1). The per-seek route through VLCKit's private pointer was put to you; you chose to stop. |
| 3 Build, install | Not done. |
| 4 Matrix on four films + the 2a comparison run | Not run. |
| 5 Removes / reduces / moves the overshoot | **No verdict**: fast seek was never applied. Pass 2a's overshoot stands (below). |
| 6 Step-4 checks | Not run. |
| 7 Worth committing? | **No** (see Result). |

## 1. Evidence: where the seek speed is decided

All quoted in `reports/logs/2b-fast-seek-recon.txt`: commands and full outputs, libvlc tree `9279ed3615`, the recipe's clean tree.

**Every mention of `input-fast-seek`** in `src`, `modules`, `lib`, `include`:
```
src/libvlc-module.c:1897:    add_bool( "input-fast-seek", false,
src/input/var.c:87:        var_Create(obj, "input-fast-seek", VLC_VAR_BOOL|inherit_flag);
modules/demux/mp4/mp4.c:1955:            !b_accurate ? "alignment" : "preroll (use input-fast-seek to avoid)", i_date );
modules/gui/qt/dialogs/preferences/simple_preferences.cpp:659:            configBool( "input-fast-seek", ui.fastSeekBox );
modules/gui/macosx/preferences/VLCSimplePrefsController.m:764:    [self setupButton:_input_fastSeekCheckbox forBoolValue: "input-fast-seek"];
modules/gui/macosx/preferences/VLCSimplePrefsController.m:1066:        config_PutInt("input-fast-seek", [_input_fastSeekCheckbox state]);
```
No `var_GetBool` or `var_InheritBool` of it anywhere in the input, the player, a demuxer or libvlc. A `:input-fast-seek` media option would be set on the input and never read.

**How the speed is decided:**
```
lib/media_player.c:1509:    enum vlc_player_seek_speed speed = b_fast ? VLC_PLAYER_SEEK_FAST
src/player/input.c:175:            .time.b_fast_seek = speed == VLC_PLAYER_SEEK_FAST,
src/input/input.c:2134:                                        param.time.b_fast_seek );
src/input/input.c:1962:                           !fast_seek );        (demux_SetTime … precise)
```

**VLCKit:**
```
- (void)setTime:(VLCTime *)value
{
    // VLCTime is in milliseconds; libvlc_media_player_set_time expects microseconds
    const libvlc_time_t time_us = value ? [[value value] longLongValue] * 1000 : 0;
    libvlc_media_player_set_time(_playerInstance, time_us, NO);
```
`libvlc_media_player_set_position(_playerInstance, newPosition, NO)` (`VLCMediaPlayer.m:1688`) is the only other seek, also precise. `jumpWithOffset:` goes through `setTime:`. The public headers mention "fast" only for `fastForward` / `fastForwardAtRate:` (playback rate, not seek).

**The route not taken** (what the scoped change would have used):
```
@interface VLCMediaPlayer ()
{
    VLCLibrary *_privateLibrary;                ///< Internal
    libvlc_media_player_t * _playerInstance;    ///< Internal
000000000241fd34 s _OBJC_IVAR_$_VLCMediaPlayer._playerInstance
000000000031788c T _libvlc_media_player_set_time
```
`Headers/vlc/libvlc_media_player.h` ships in the framework, but `module.modulemap` has `exclude header "vlc/libvlc_media_player.h"`. A Swift call would need a hand-written declaration and the ivar read through the runtime. It is fragile: a VLCKit update can rename or retype the ivar with no compile error.

## 2. Step 4 table against pass 2a

| Run | Pass 2a (precise seeks) | Pass 2b (fast seek) |
|---|---|---|
| Magicians S1E1, playing, drag forward, land | before 175 993 ms; target 238 564 ms (03:59); +3 s 268 585 ms (04:29 on screen); click → first render 0.021 s at PTS 266 302 ms; 0 dropped / 0 late; 3 739 demux reads while paused (PCR to 269.0 s), 0 in the 5 s hold | **not run** |
| Magicians probe, playing, forward, land | before 17 000 ms; target 79 571 ms; +3 s 102 242 ms | **not run** |
| Stargate, Wonder Woman, Divergent × 4; Magicians back / paused | not run in 2a | **not run** |

## 3. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1–2 | `reports/logs/2b-fast-seek-recon.txt` (read-only searches of libvlc, VLCKit sources, the framework's headers, symbols and module map; the apply check) | Committed |
| — | This report; `COLD-START.md` (pass 2b note) | Committed |
| 1 | Scratch copies of HEAD's three player files for `git apply --check` | Scratch only |
| — | `Marlin Media TV/PlayerHost.swift`, `PlayerModel.swift`, `PlayerScreen.swift` | **Not touched this pass.** Still pass 2a's uncommitted scrub diff. |

- **Not touched:** `tools/vlckit-truehd/` (0007, 0018, 0019, 0020), `Frameworks/VLCKit.xcframework` (read only: headers, `nm`), libvlc (read only), `DECISIONS.md`, Design/, Marlin DVR TV.
- **Constraints:** no build, so `TVOS_DEPLOYMENT_TARGET` stays 26.0 untouched; no device or simulator use; the committed recon file is 6.9 KB; no device identifiers in it; no runs, so no run names.
- **Pushed:** nothing.

## 4. Open questions

1. **Try fast seek through the scoped libvlc call after all?** Private `_playerInstance` read, `libvlc_media_player_set_time(…, true)` for scrub seeks only. It's the only way to test the hypothesis in this build without a framework change.
2. **Or drop "picture follows the target while paused" (pass 2a step 3)** and seek once on click after Play (pass 2a question 1a). Seeks while playing were clean in pass 1c.
3. **Pass 2a's open questions 2–6 still stand:** Menu restores play state; inputs ignored during a scrub; the feel values; commit timing; your physical check.

## 5. Least-sure items

1. **"Nothing reads `input-fast-seek`" rests on a text search** of `src`, `modules`, `lib` and `include` for the literal name. A reader that builds the name at runtime (string concatenation) would be missed. None is known in VLC, but no build was run to prove the option inert.
2. **Whether fast seek would fix the overshoot is unknown.** The mp4 demuxer's fast path skips the preroll ("alignment" instead of "preroll"). Pass 2a's laps are `PCR is called late` → `ES_OUT_RESET_PCR`, which may not depend on the preroll at all.
3. **The route not taken was not compiled.** That the ivar read and the hand-declared C call would build and link in the app is inferred from the symbols (`s` ivar offset, `T` function), not tried.
