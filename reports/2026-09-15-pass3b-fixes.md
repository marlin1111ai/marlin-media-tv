# Pass 3b — three fixes

2026-09-15, on top of local commit `a99cccc`. Decisions: DECISIONS.md **D043–D045**. The owner tests
this pass by hand, so the verification is short: it builds, it is installed, it launches with focus
on the first Continue Watching card, and two device screenshots.

## Result

| Step | What | State |
|---|---|---|
| 1 | Home opens with focus on the first Continue Watching card | **works** — `reports/screenshots/p3b/p3b-2-home-launch-focus.png`, `[focus] launch: … focus is now 4` |
| 2 | The clock on frames 16 and 17 (loading, can't reach server) | **already there; no code was needed** — and neither screen could be photographed. Code trace, not device proof |
| 3 | The clock on the player while paused, and not while playing | **works** — `reports/screenshots/p3b/p3b-3-player-paused-clock.png` |
| 4 | Notebook (D043–D045, COLD-START) | done |

Build succeeded, installed on Home Theater, launched, and the device is **left running this build**.
**No server write of this pass's own:** the harness played Divergent from 0 and paused at 15.6 s,
under D028's 120 s floor, so the app wrote nothing —
`[playback] position 15.6 s not written (pause): under 120 s` (`reports/logs/3b-run1.log`).

## Step 1 — the launch focus

Pass 3 left this as its open question 1: tvOS chose for itself and picked a Movies card, so Home
opened slightly scrolled with the top row cut, while frame 00's own label reads "first card focused".

**What was built.** Home's Continue Watching cards now carry `@FocusState`
(`.focused($focusedCard, equals: entry.fileId)`), as the library tabs' cards already did for D033,
and `placeLaunchFocus()` asks for the first card.

Two things made a single request useless, and both are handled:

1. **The cards do not exist when Home first appears.** The row is built from the in-progress list,
   which arrives from the server afterwards, and the focus engine ignores a request for a view that
   is not on screen. So the request is repeated every 120 ms, at most 12 times (1.4 s), and it is
   also triggered by the list's own arrival (`onChange(of: model.continueWatching.count)`).
2. **It must not fight the viewer, or Home's own re-reads.** The loop stops the moment *any* card of
   the row holds focus, and a `launchFocusPlaced` flag means the whole thing happens **once per
   session** — moving along the row, coming back from the player and D040's re-read on every
   appearance are untouched.

**With the row empty nothing is placed at all**, so today's behaviour is kept, as asked.

**On Home Theater.** The log line is
`[focus] launch: asked for the first Continue Watching card 4; focus is now 4`, 0.27 s after the
in-progress list arrived (`[continue] 3 entries: movie/4@2444s, episode/8@1224s, movie/2@1821s`), and
the screenshot shows Wonder Woman — the first card — ringed, with the row at the top of the screen
and nothing scrolled away. The test's own assertion on the focused element passed:
`focus ["home.continue.4"]`.

## Step 2 — the clock on frames 16 and 17

**It is already drawn, and pass 3's report was wrong to say otherwise.** D041's clock overlay sits on
the **container**, outside the phase switch, in both screens that can show those states:

- `LibraryScreen.swift:52` — the overlay is applied to the whole `ZStack`, after the
  `loading / failed / loaded` switch (lines 37–47) and before `ignoresSafeArea`.
- `HomeScreen.swift:63` — the same shape, and Home is the app's first screen, so it is the one that
  shows the loading and error states at launch.

So `LibraryLoadingView` (frame 16) and `LibraryErrorView` (frame 17) are drawn *beneath* the clock
and carry it at `right: 80, top: 56`. That is exactly what the new frames draw
(`position:absolute;right:80px;top:56px;z-index:6`, the 18 px/500 `.1em` uppercase date and the
24 px/500 tabular time). **No code was written for this step.**

**Neither screen could be photographed on the device, and this is the pass's weakest evidence.**

- **Frame 16 (loading).** The state is over before the app paints. The session's own screen
  recording was swept at 0.05 s: tvOS's home screen is still up at **2.80 s**, and at **2.85 s**
  Marlin's Home is already there with its rows populated (artwork still fading in) — the skeleton
  loading screen never appears at all. Both frames are kept as
  `reports/screenshots/p3b/p3b-0-first-painted-frame-2.85s.jpg` and `…-2.90s.jpg`. A launch-and-shoot
  loop with no sleeps (`s0_LoadingShots`, six frames back to back) caught Home every time, because
  `XCUIApplication.launch()` returns only once the app is ready.
- **Frame 17 (can't reach server).** Reaching it needs the server unreachable, and every way of
  arranging that is outside this pass: a server write, a change to `ServerConfig.baseURL`, or taking
  Home Theater off the network.

If the owner wants device proof, the cheap route is a throwaway build pointed at a dead host — say so
and it is a five-minute pass.

## Step 3 — the clock on the player while paused

`PlayerScreen.swift` gains `pausedClock`: the same `NowClock`, the same style, the same place
(`right: 80, top: 56`) as Home, the library tabs and the detail screens.

- **While playing there is none.** The condition is `!model.isPlaying` — the very condition frame
  13's pause mark already uses — so the clock and the pause mark appear and go together, and no new
  state was added to `PlayerModel.swift` (untouched, as required).
- **Hidden while a track panel is open.** Frames 11 and 12 put the panel in that same corner (760 pt
  wide, `top: 90`, `trailing: 80`), so the clock would sit on top of it. With `model.panel != nil` it
  is not drawn. It **does** show during a paused scrub, where the bar and thumbnail are at the foot
  of the screen and nothing collides.
- **Nothing else in the player changed.** It goes into the visuals-only `ZStack`, which is
  `allowsHitTesting(false)`: it takes no press, no touch and no focus. D008's skips, the frame step,
  the panels and D021's scrub are untouched.

**On Home Theater:** `p3b-3-player-paused-clock.png` — Divergent paused at 00:16, "❙❙ Paused" on the
overlay, frame 13's pause mark in the middle, and "TUE 15 SEP 11:13 PM" at the top right in the
frames' own type. The run's log carries the ordinary paused player lines and no new ones.

## Files touched, by step

| File | Step |
|---|---|
| `Marlin Media TV/HomeScreen.swift` | 1 — `@FocusState` on the cards, `placeLaunchFocus()`, its two triggers |
| — | 2 — **no file changed** |
| `Marlin Media TV/PlayerScreen.swift` | 3 — `pausedClock` and its condition |
| `DECISIONS.md`, `COLD-START.md` | 4 |
| `reports/2026-09-15-pass3b-fixes.md`, `reports/logs/3b-run1.log`, `reports/screenshots/p3b/` | this report and its evidence |
| `Marlin Media TVUITests/Pass3bShotsUITests.swift` | the screenshots — **not committed** |

`PlayerModel.swift` and `PlayerHost.swift` were not edited; `PlayerHost.swift`'s Page Up/Down hook
stays uncommitted in the working tree, as before.

## Committed vs pushed

**Committed locally on top of `a99cccc`; nothing pushed** — the owner tests passes 2, 2b, 2c, 3 and
3b together. Not committed: `Pass3bShotsUITests.swift`, `Pass3ShotsUITests.swift`,
`Pass2cUITests.swift`, `Pass2bUITests.swift`, `Diag2gUITests.swift` and the `PlayerHost.swift` hook.

## Open questions

1. **Frames 16 and 17 have no device proof** (step 2). Worth a throwaway dead-host build, or is the
   code trace enough?
2. **The paused clock during a scrub.** It is shown, on the grounds that nothing collides. The frames
   say nothing either way, because they draw no clock on the player at all.
3. **The clock while the player is buffering or opening.** `!isPlaying` is true then too, so the
   clock shows in those moments exactly as the pause mark does. That follows frame 13's existing
   rule; it was not separately asked for.
4. Pass 3's open questions 3–6 (Home's per-show fetches, the TV row's wide card, the Videos heading
   with no videos, the pinned header) are untouched and still open.

## Least sure

1. **Step 2 is a code trace, not a photograph** — the weakest evidence in this pass, and the reason
   the step is reported as "already there" rather than "proven".
2. **The launch focus was seen on one library shape**: three Continue Watching entries, artwork
   cached, the server answering in well under a second. A cold server, a slow first fetch, or an
   empty row would exercise the retry loop and the "nothing to place" branch, and neither was run.
3. **The 1.4 s retry window** (12 × 120 ms) was never observed being exhausted: the card took focus
   on the first or second ask in every launch seen. What happens on a much slower fetch is written to
   the rule, not measured.
4. **The paused clock was photographed once**, on one film, with no track panel open. The
   panel-open case (clock hidden) and the paused-scrub case (clock shown) are traced from the code,
   not photographed.
5. **The minute rollover** on the player's clock was not watched, as in pass 3.
