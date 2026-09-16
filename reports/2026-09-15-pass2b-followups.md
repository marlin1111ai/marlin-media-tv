# Pass 2b — pass 2's follow-ups

2026-09-15, on top of local commit `b3f3b02`. Decisions: DECISIONS.md **D031–D038**.
Pass 2: `reports/2026-09-15-pass2-resume-watched.md`.

## Result

**One of the three builds works. Two are STOPPED, both with evidence and neither retried blind.**

| Step | What | State |
|---|---|---|
| 1 (D031) | Episode press-and-hold opens the mark menu | **STOPPED — the hold still plays the episode** |
| 2 (D032) | Detail screens re-read when the player closes | **works**, proven on Home Theater (b2) |
| 3 (D033) | Focus entering the Continue Watching row lands on its first card | **STOPPED — it lands on the nearest card** |
| 4 | Notebook (D031–D038, COLD-START) | done |

No server write of this pass's own was made: every write below came from the app's own buttons
while the tests ran.

## Step 1 — the press-and-hold: what it does, and why

**Mechanism chosen: pass 2's candidate (a)** — a `UILongPressGestureRecognizer` limited to the
select press (`allowedPressTypes = [.select]`, `minimumPressDuration` 0.6 s), added to the **window**
while the show detail is up, with `@FocusState` naming the row it applies to and a `holdFired` flag
to swallow the click that ends a hold.

It had to be the window rather than the row: SwiftUI's `.background` puts its view *beside* the
content, not around it, so a recogniser there is never in the press's path, and a recogniser on the
row's own Button is beaten by the Button's action. Candidate (b) — rebuilding the row as a focusable
non-Button view with its own select handling — was not chosen first because it changes how every
episode row takes a click, which is behaviour pass 2 already proved.

**It does not work, and the instrumented run says exactly where it breaks**
(`reports/logs/2b-b1i-app.log`):

```
21:43:55.847 [hold] recogniser added to the window (minimum 0.6 s, select press only)
…no "[hold] recogniser state …" line, ever…
21:44:08.947 [player] request The Magicians — S1 E2 · The Source of Magic — …/stream/9
21:44:08.948 [playback] file 9 saved position 0.0 s watched=false; starting at 0 ms
```

- The recogniser **attaches** — so this is not a wiring or lifetime problem.
- It **never reaches any state at all**, not even `.possible`: the select press never reaches a
  window-level recogniser while a SwiftUI Button holds focus. The Button consumes it and fires its
  action on release.
- The 1.4 s hold therefore lands as an ordinary click and **plays S1E2**, exactly as in pass 2.
- Snapshot: `reports/screenshots/p2b/b1-p2b-b1-02-hold-menu.png` — a frame of S1E2 playing where the
  menu should be.

**Not retried.** Candidate (b) is the next thing to try and was deliberately not attempted here.

**The instrumentation stays in** `ShowDetailScreen.swift` (`[hold] recogniser added / state / removed`):
it costs nothing, and whoever tries candidate (b) will want it.

## Step 2 — detail screens re-read when the player closes (works)

`ContentView` counts player closes and hands the count to the three detail screens, which re-read
their item from it. A full-screen cover never takes its content off screen, so there is no
appearance callback to hang this on. The show screen re-reads without its loading state, so the
list does not flash and the chosen season is kept.

Proven by **b2** (`reports/logs/2b-b2-app.log`), on Divergent, which pass 2 left at 223.5 s:

```
21:45:31.673 [playback] PUT file 1 position=0.0 (start over) → 200 position=0.0 watched=false
21:45:31.687 [playback] file 1 saved position 241.815 s watched=false; starting at 0 ms
21:45:48.409 [playback] position 16.0 s not written (exit): under 120 s
21:45:48.500 [detail] movie 1 re-read: position 0.0 watched false
21:45:48.567 [continue] 2 entries: episode/8@968s, movie/2@1821s
```

and by the test's own assertion — `after the player closed: startover exists=false`. The screen that
showed "Resume · 2 h 16 min left" with Start over before
(`b2-p2b-b2-01-detail-resume.png`) shows **Play** alone after (`b2-p2b-b2-03-detail-after.png`), and
Divergent drops off the Continue Watching row in the same moment.

## Step 3 — first-card focus (does not work)

The row is a focus scope (`.focusScope`) whose first card is `.prefersDefaultFocus(true, in:)`.
On the device that does not govern where directional focus enters. **b3**'s recorded path, with the
row holding `["continue.1", "continue.2"]` left to right:

| Entering from | Lands on | |
|---|---|---|
| the **sort control** (far right of the header) | `continue.2` | ✗ the nearest card wins |
| the header, after moving to the second card | `continue.2` | ✗ |
| the header, after playing a card and returning | `continue.1` | ✓ — but see below |

`prefersDefaultFocus` applies to initial and programmatic focus, not to a Down press, which tvOS
resolves by nearest neighbour in the direction of travel. **The one case the owner named — entering
the row after the player closes — did land on the first card, but the Movies tab sits directly above
that card, so geometry explains it and it is not evidence that the change works.** Screenshot:
`b3-p2b-b3-02-entered-from-sort.png`, the focus ring on Stargate, the second card.

What would actually decide it (untried, and a new mechanism, so not attempted here): driving the
row's focus with `@FocusState` and setting it when focus enters the section, or laying the row out so
the first card is the nearest neighbour from every header item.

## Files touched, by step

| File | Step |
|---|---|
| `Marlin Media TV/ShowDetailScreen.swift` | 1 — `HoldReceiver`, `@FocusState` row, `holdFired`, the instrumentation; 2 — `playerClosed`, `reload()` without the loading state |
| `Marlin Media TV/ContentView.swift` | 2 — the player-close counter, handed to all three detail screens |
| `Marlin Media TV/MovieDetailScreen.swift` | 2 — `playerClosed`, re-read on change |
| `Marlin Media TV/VideoDetailScreen.swift` | 2 — the same (still never run on a device: no videos on this server, D038) |
| `Marlin Media TV/LibraryScreen.swift` | 3 — `.focusScope` + `.prefersDefaultFocus` on the first card |
| `DECISIONS.md`, `COLD-START.md` | 4 |
| `Marlin Media TVUITests/Pass2bUITests.swift` | the harness — **not committed** |

## What was run, and what was not

- **A hold opening the menu, and Mark watched / unwatched from it** — **not run: the menu never
  opened.** The server was read before and after anyway and is unchanged: The Magicians is 13/13
  unwatched, file 9 (S1E2) still `position 0, watched false, last_played null`.
- **A click on a different episode still plays** — shown incidentally: the hold fell through to a
  click and played S1E2 twice (both runs). The dedicated leg on S1E3 was not reached cleanly,
  because by then the run had already diverged from the script.
- **Start over then Menu back shows current state** — run, passes (above).
- **Focus entering the row after playing from a card** — run; lands on the first card, for the
  geometric reason above.
- **Nothing else was re-run**, as instructed: no pass 2 test was repeated.

## The playback state left on the server

| File | Item | position | watched | last_played |
|---|---|---|---|---|
| 1 | Divergent | **0** | false | 2026-09-16T01:45:31Z |
| 2 | Stargate · Extended | 1 821.678 | false | 2026-09-16T00:55:13Z |
| 3 | Stargate · Theatrical | 0 | false | null |
| 4 | Wonder Woman | 0 | false | 2026-09-16T00:58:35Z |
| 5 | Food That Built America S4E2 | 0 | **true** | 2026-09-16T01:09:39Z |
| 8 | Magicians S1E1 | 968.576 | false | 2026-09-16T01:07:27Z |
| 6, 7, 9–20 | everything else | 0 | false | null |

Continue Watching now holds two entries: Magicians S1E1 and Stargate Extended. Divergent left it
when Start over wrote 0. All of this is test state, to be reset once both passes are accepted (D037).

## Committed vs pushed

**Committed locally on top of `b3f3b02`; nothing pushed** — the owner tests passes 2 and 2b together.
Home Theater is left running this build. Not committed: `Marlin Media TVUITests/Pass2bUITests.swift`,
`Marlin Media TVUITests/Diag2gUITests.swift`, the `PlayerHost.swift` hook, and the owner's
`Design/Marlin Media tvOS Design2.zip`.

## Open questions

1. Step 1: try candidate (b) — the episode row as a focusable non-Button view with its own select
   handling — or take the hold somewhere it is not competing with a Button (the row's own UIKit
   host, as `PlayerHost` already does for the player)?
2. Step 3: should the row's focus be driven explicitly with `@FocusState` when focus enters the
   section, or should the layout change so the first card is the nearest neighbour from every header
   item? Both are new mechanisms and neither was attempted.
3. Is "lands on the first card" wanted even when the owner is walking along the row and steps out and
   back deliberately, or only when arriving from elsewhere?
4. The non-working hold code stays in the tree and does nothing. Keep it (with its instrumentation)
   for the next attempt, or strip it back out?
5. D035 says Start over leaves `watched` set, so a rewatch shows Resume beside "✓ Watched". Should
   the pill be worded differently in that state?

## Least sure

1. **Why the window recogniser never sees the press is read from its own silence** — attach logs,
   no state ever logs — plus the Button playing the episode. That the focused SwiftUI Button
   consumes the press is the explanation that fits; it is not traced through UIKit.
2. **Step 3's one passing leg is attributed to geometry**, not measured as such: I did not construct
   a case where the first card is far from the header item focus came from.
3. **`prefersDefaultFocus` may still matter for initial focus** — it was only ever tested by
   directional entry here.
4. **The video detail screen (D038) has still never run on a device.**
5. **b1's later legs are unreliable** after its first assertion failed: the run continued pressing
   into a player it did not expect, so only the hold itself and the playback it caused are
   trustworthy evidence from that test.
