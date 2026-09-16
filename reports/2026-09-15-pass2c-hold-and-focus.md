# Pass 2c — the episode hold and the Continue Watching focus

2026-09-15, on top of local commit `8def8cd`. Decisions: DECISIONS.md **D031 (revised)**, **D032a**,
**D033 (revised)**. Earlier: `reports/2026-09-15-pass2-resume-watched.md`,
`reports/2026-09-15-pass2b-followups.md`.

## Result

| Step | What | State |
|---|---|---|
| 1 (D031) | The row is a focusable view, not a Button — **click plays / resumes** | **works** (c2, c3) |
| 1 (D031) | …and a **press-and-hold opens the mark menu** | **STOPPED — a hold still plays** |
| 2 (D033) | Focus entering the Continue Watching row lands on its first card | **works**, all four cases (c4) |
| 3 | Notebook (D031, D032a, D033, COLD-START) | done |

No server write of this pass's own: every write came from the app's own buttons while the tests ran.
The second Continue Watching card that step 2 needed was made by letting the app play Wonder Woman
past the 120 s floor, not by seeding.

## Step 1 — what was removed, what was built, and where it stops

**Removed (pass 2b's candidate (a)):** the `HoldReceiver` `UIViewRepresentable`, its
`UILongPressGestureRecognizer` on the window, the `.background(HoldReceiver…)` on the screen, and
that attempt's `[hold] recogniser added / state / removed` instrumentation. Pass 2b proved it
attaches but never receives the press, because a focused SwiftUI Button consumes select.

**Built (candidate (b)):** the episode row is now a **focusable view rather than a Button** —
`EpisodeRowLabel` with `.focusable()`, `.focused($focusedEpisode, equals:)`, the accessibility
identifier and the button trait, and the row's own
`.onLongPressGesture(minimumDuration: 0.6, perform:onPressingChanged:)`. `EpisodeRowLabel` itself is
untouched and still takes its look from `@Environment(\.isFocused)`, which `.focusable()` drives
exactly as the Button did, so **the row draws and focuses as before** (`p2c-c1-01-before.png`,
`p2c-c4-…`).

**The click half works.** From the two clean runs:

```
c2  22:12:56.362 [hold] press down on S1E3
    22:12:56.377 [hold] press up on S1E3            ← 15 ms
    22:12:56.377 [hold] click: playing S1E3 from 0 ms
c3  22:13:53.181 [hold] press down on S1E1
    22:13:53.185 [hold] press up on S1E1            ← 4 ms
    22:13:53.185 [hold] click: playing S1E1 from 968576 ms
    22:13:53.671 [playback] seeking to the saved position 968576 ms (length 3128562 ms)
```

**The hold half does not, and the pass stopped there.** Instrumented timing of the 1.4 s hold:

```
22:10:28.293 [hold] press down on S1E2
22:10:28.894 [hold] press up on S1E2        ← 601 ms, capped at the 0.6 s threshold
22:10:28.895 [hold] click: playing S1E2 from 0 ms
```

and **no `[hold] mark menu` line**. Read against the 4–15 ms of a real click, the press *was* held
past the threshold and the long press *was* recognised — SwiftUI simply delivers
**`onPressingChanged(false)` before `perform`**. My release handler therefore treats it as a click
and starts playback; `perform` runs a moment later, finds `playerUp` already true, and refuses. The
fault is my handler's ordering, not the platform's gesture.

**The fix, not applied:** stop racing the callbacks — remember the press-down instant and, on
release, treat anything past the threshold as a hold rather than a click. One state variable and one
comparison. It was not made, because "the hold still plays" is this pass's stop condition and the
brief forbids a blind retry. **The press-down/press-up instrumentation is left in** (D032a).

Server proof that nothing was written by the failed runs: The Magicians is still 13/13 unwatched and
S1E2 (file 9) is still `position 0, watched false, last_played null`.

## Step 2 — first-card focus (works)

Every card carries `@FocusState`; when focus arrives and no card held it a moment before, it is moved
to the first card. Moving between cards is untouched. Pass 2b's `focusScope` / `prefersDefaultFocus`
is removed.

With two cards on the Movies tab — `["continue.4", "continue.2"]`:

| Entering from | Focus lands on | |
|---|---|---|
| the **sort control** (far right) | `continue.4` | ✓ redirected |
| the **Movies tab** the row sits under | `continue.4` | ✓ redirected |
| the header, **after moving to the second card** | `continue.4` | ✓ redirected |
| the header, **after returning from the player** | `continue.4` | ✓ arrived there already |

The three redirects each logged
`[focus] continue row entered at card 2; moved to the first card 4`; the fourth needed none, so no
line. Screenshots: `p2c-c4-02-from-sort.png`, `p2c-c4-03-re-entered.png`, `p2c-c4-04-after-player.png`.

## Files touched, by step

| File | Step |
|---|---|
| `Marlin Media TV/ShowDetailScreen.swift` | 1 — candidate (a) removed; the row made a focusable non-Button with its own long-press and press handlers; press timing instrumentation |
| `Marlin Media TV/LibraryScreen.swift` | 2 — `@FocusState` on the cards and the entry redirect; `focusScope` / `prefersDefaultFocus` removed |
| `DECISIONS.md`, `COLD-START.md` | 3 |
| `Marlin Media TVUITests/Pass2cUITests.swift` | the harness — **not committed** |

No layout or visual change was made to any screen (D006): `EpisodeRowLabel`, `ContinueCardLabel` and
every other view are byte-for-byte as they were.

## What was run, and what was not

- **A hold opening the menu; Mark watched / unwatched from it** — **not run: the menu never opened.**
  The server was read before and after and is unchanged.
- **A clean, separate run: a click on a different episode plays it** — run (c2), passes.
- **A click on an episode with a saved position resumes it** — run (c3), passes, with the seek.
- **Focus entering the row in all four listed cases** — run (c4), passes.
- **Nothing else was re-run.**

## The playback state left on the server

| File | Item | position | watched | last_played |
|---|---|---|---|---|
| 1 | Divergent | 0 | false | 2026-09-16T01:45:31Z |
| 2 | Stargate · Extended | 1 821.678 | false | 2026-09-16T00:55:13Z |
| 3 | Stargate · Theatrical | 0 | false | null |
| 4 | Wonder Woman | **161.4** | false | 2026-09-16T02:18:04Z |
| 5 | Food That Built America S4E2 | 0 | **true** | 2026-09-16T01:09:39Z |
| 8 | Magicians S1E1 | **985.898** | false | 2026-09-16T02:14:14Z |
| 6, 7, 9–20 | everything else | 0 | false | null |

Continue Watching holds three entries: Wonder Woman, Magicians S1E1, Stargate Extended. Wonder Woman
and the S1E1 position are new in this pass, written by the app itself while testing. All of it is
test state, to be zeroed once the owner accepts the three passes (D037).

## Committed vs pushed

**Committed locally on top of `8def8cd`; nothing pushed** — the owner tests passes 2, 2b and 2c
together. Home Theater is left running this build. Not committed: `Pass2cUITests.swift`,
`Pass2bUITests.swift`, `Diag2gUITests.swift`, the `PlayerHost.swift` hook, and the owner's
`Design/Marlin Media tvOS Design2.zip`.

## Open questions

1. Apply the one-line ordering fix to D031 (judge the press by its own elapsed time) in the next
   pass, or hand the hold to UIKit entirely, as `PlayerHost` already does for the player?
2. With the release deciding the click, a *cancelled* press (finger off the surface, or focus moving
   mid-press) would also read as a click. Should a cancelled press do nothing?
3. 0.6 s is the hold threshold. Is that the right feel on the real remote, or should it be longer?
4. The row is no longer a Button, so it gains no system focus effect of its own. It looked identical
   in every screenshot taken, but only the owner's eye on the real television can settle that.
5. Wonder Woman is now in Continue Watching at 2 m 41 s purely because step 2 needed a second card.
   Clear it with the rest of the test state?

## Least sure

1. **That `onPressingChanged(false)` precedes `perform` is inferred** from the log order and the
   601 ms press, not from a SwiftUI trace. It is the only reading that fits both the timing and the
   missing menu line, but it is an inference.
2. **The 601 ms figure is the app's view of the press**, from two `EvidenceLog` lines; XCUIRemote was
   asked for 1.4 s. Why the two differ is not established — most likely SwiftUI ends its pressing
   state at `minimumDuration` — and a hand-held press may behave differently again.
3. **The row's appearance is judged from screenshots**, which match; no pixel comparison was made
   against pass 2b's frames.
4. **Only the Movies tab's row was used for step 2**, with two cards. Three or more cards, and the
   TV Shows and Videos tabs, are untested.
5. **The video detail screen (D038) still has never run on a device.**
