# Pass 3 — the episode rows, the Home page and the clock

2026-09-15, on top of local commit `ef9ce11`. Decisions: DECISIONS.md **D039–D042**. The owner tests
this pass by hand, so the verification is short: it builds, it is installed, it launches on Home,
and four screenshots.

## Result

| Step | What | State |
|---|---|---|
| 1 | The episode row's focus highlight | **works** — `reports/screenshots/p3/p3-3-episode-row-focused.png` |
| 1 | Press-and-hold opens the mark menu; a click still plays or resumes | **works** — `[hold] menu for S1E2 file 9 after 1383 ms` |
| 2 | The design replaced from Design2.zip, and the diff | **done** — list below |
| 3 | The Home page, and the app opening on it | **works** — `p3-1-home.png` |
| 4 | The clock, and the Sort control moved | **works** — `p3-2-library-tab-with-clock.png` |
| 5 | Notebook (D039–D042, COLD-START) | done |

Build succeeded, installed on Home Theater, launched on Home, and the device is left running this
build. No server write of this pass's own: the only writes were the app's own during the run.

## Step 1 — the row, fixed twice

**The highlight.** Pass 2c made the row a focusable view rather than a Button; `EpisodeRowLabel`
read `@Environment(\.isFocused)`, which a Button's style provides but a plain `.focusable()` view
does not, so it always drew the unfocused look. The row now takes `focused:` explicitly from
`@FocusState`. The drawing itself is untouched — the same background, border and colours as pass
2/2b — and the screenshot matches those runs.

**The hold.** The press-down instant is remembered and the release measured against it: **0.6 s or
more opens the mark menu and plays nothing; shorter plays or resumes.**

Pass 2c got this wrong twice over, and the fix took both parts:
1. It raced SwiftUI's callbacks — `onPressingChanged(false)` arrives before `perform` — so the
   release was taken as a click.
2. Measuring elapsed time alone was still not enough: **SwiftUI ends the press at the gesture's own
   `minimumDuration`**, which pass 2c measured at 601 ms against a 600 ms threshold. Comparing the
   measured length against the same 0.6 s the gesture uses is a race that can be lost by a
   millisecond — and was: `[episode] click: playing S1E2 from 0 ms`.

So the gesture's minimum is now set beyond any real press (3600 s). It never ends the press itself,
the release is the true one, and its length decides. On the device the 1.4 s hold measured
**1383 ms** and opened the menu (`p3-4-hold-menu.png`); a click still plays from 0 or resumes.
Pass 2c's press-down/press-up instrumentation is removed; one line is logged per outcome.

## Step 2 — the design replacement and the diff

`Design/Marlin Media tvOS Design2.zip` was unzipped into `Design/`, replacing
`Marlin Media.dc.html`, `Marlin Media Prototype.dc.html`, `support.js` and `_ds/`, and the zip was
deleted once the replacement was in place. The older `Marlin Media tvOS Design.zip` was left alone.
`Marlin Media.dc.html` went from 65 887 to 87 024 bytes.

**Every difference, old frames vs new** (text of each frame compared; the only screens that changed
at all are listed):

| Frame | Difference | Built? |
|---|---|---|
| **00 · Home** | **New.** Clock; MARLIN + Movies / TV Shows / Videos buttons; Continue watching row (progress bar in the art, title, line 2, line 3); Movies · N row; bottom fade. | yes (step 3) |
| **00b · Home — scrolled** | **New.** TV Shows · N row and Videos · N row, the latter in a wide 340 × 191 card. | yes (step 3) |
| **00c · Home — nothing in progress** | **New.** No Continue watching row; Movies focused in the header. | yes (step 3) |
| 01, 02, 03, 04 | Clock added at right 80, top 56; **Sort control moved 260 pt in from the right** to clear it. | yes (step 4) |
| 06, 07, 08, 09 | Clock added. Nothing else. | yes (step 4) |
| 16, 17 | Clock added. Nothing else. | **no** — loading and error screens; the clock was not added there, and it is not in the pass's list. Reported here, not built. |
| 05 (the sort-menu panel) | Clock added at right **60** — that artboard is a narrow detail panel, not a screen. | n/a |
| **10, 11, 12, 13, 14, 15** | **Identical** — the player frames are unchanged, and carry no clock. | n/a |

Nothing else in any frame moved: no new copy, no layout change, no colour change.

## Step 3 — Home

`HomeScreen.swift` draws frames 00/00b/00c and `ContentView` makes it the root, with the library
tabs pushed above it so Menu pops back. The rows:

- **Continue watching** — `model.continueWatching` as the server gives it, every kind mixed, newest
  first, the same `ContinueCardLabel` the library tabs use; a card plays its file from its saved
  spot. Absent when the list is empty.
- **Movies · N** — up to six: those with an edition in progress first, most recently played first,
  then the rest by title; a card opens the movie screen.
- **TV Shows · N** — up to six episode cards in the wide card, each with the episode's own still,
  the show's title and "S# E# · episode title". Order: episodes in progress (newest first); then,
  for each show, the next episode after the last one it finished; then on down each show, a step at
  a time, until six. Shows with history come before shows never watched, which join from their first
  episode. A card plays that episode, resuming if it has a spot.
- **Videos · N** — up to six, in-progress first then by title; a card opens the video screen. The
  heading shows even with none, as asked.

Home re-reads everything each time it appears and each time the player closes. That needs every
show's episodes, which `GET /api/shows` does not carry, so it also fetches one
`GET /api/shows/{id}` per show (`[home] 2 of 2 shows detailed for the TV row`).

## Step 4 — the clock

`NowClock` draws the frames' pair — the date 18 px/500, `.1em`, uppercase, `#75798c`; the time
24 px/500, `#cfd3e5`, tabular — and ticks once a second while it is on screen. It is placed at
`right: 80, top: 56` on Home, the three library tabs and the movie, show and video screens, and is
**not** on the player. The Sort control is moved 260 pt in from the right.

Two placement faults were found and fixed from the first device screenshots, both visible in
`reports/logs`/the first run's shots: the clock sat ~60 pt low because the overlay was applied after
`ignoresSafeArea` (it now goes on before), and Home's rows painted over the pinned header because
the vertical scroll had clipping disabled (only the horizontal rows keep that, for the focus glow).

## Files touched, by step

| File | Step |
|---|---|
| `Marlin Media TV/ShowDetailScreen.swift` | 1 — `focused:` from `@FocusState`; the press-length hold; pass 2c's instrumentation removed; 4 — the clock |
| `Design/` (`Marlin Media.dc.html`, `Marlin Media Prototype.dc.html`, `support.js`, `_ds/`) | 2 — replaced; `Marlin Media tvOS Design2.zip` deleted |
| `Marlin Media TV/HomeScreen.swift` | 3 — new: the Home page, its rows and the wide card |
| `Marlin Media TV/LibraryModel.swift` | 3 — every show's episodes, the three Home row orders, `refresh()`, the episode play request |
| `Marlin Media TV/ContentView.swift` | 3 — Home as the root, library tabs pushed, Menu back to Home |
| `Marlin Media TV/NowClock.swift` | 4 — new: the clock |
| `Marlin Media TV/LibraryScreen.swift` | 4 — the clock, the Sort control's 260 pt shift |
| `Marlin Media TV/MovieDetailScreen.swift`, `VideoDetailScreen.swift` | 4 — the clock |
| `DECISIONS.md`, `COLD-START.md` | 5 |
| `Marlin Media TVUITests/Pass3ShotsUITests.swift` | the four screenshots — **not committed** |

## Committed vs pushed

**Committed locally on top of `ef9ce11`; nothing pushed** — the owner tests passes 2 and 3 together.
Not committed: `Pass3ShotsUITests.swift`, `Pass2cUITests.swift`, `Pass2bUITests.swift`,
`Diag2gUITests.swift` and the `PlayerHost.swift` hook.

## Open questions

1. **Launch focus lands on a Movies card, not the first Continue Watching card**, so Home opens
   slightly scrolled and the top row is cut. Frame 00's own label reads "first card focused".
   Initial focus is not in this pass's list, so it was not built — should it be?
2. **Frames 16 and 17 gained the clock too** (loading and "can't reach server"). They are not in the
   pass's list, so the clock was not added there. Add it?
3. Home fetches **one `GET /api/shows/{id}` per show every time it appears**. That is 2 requests
   here and would be 34 on the owner's full library. Cache them, or ask only when the shows list
   changes?
4. The TV row uses the **wide card** as the brief says, while frames 00b/00c draw the TV Shows row
   as posters. The brief wins, but the frames and the app now differ there.
5. With no videos, the Videos heading shows above an empty space, as asked. Is that the wanted look
   once a video exists, or should the row hide like Continue watching?
6. Home's rows are one vertical scroll; the frames show 00 and 00b as two scrolled states of the
   same screen. Nothing pins the header other than its place above the scroll — is the header meant
   to stay put, as it does now?

## Least sure

1. **Menu from a library tab returning to Home was not run** — it is `NavigationStack`'s ordinary
   pop and nothing in the code intercepts it, but no screenshot proves it. Traced, not run.
2. **The TV row's order is barely exercised by this library:** two shows, one episode in progress,
   nothing finished. The "next after the last finished" and the walk on down each show are written
   to the rule but have almost no real data behind them here.
3. **The Videos row has never been seen with a video in it** (D038 still stands), so its card, its
   spec line and its in-progress ordering are traced from the code.
4. **The clock's minute rollover was not watched.** It ticks once a second by construction; the
   screenshots show one instant each, 10:53 and 10:59.
5. **Home's appearance is judged from one screenshot** at launch, with focus on a Movies card. The
   scrolled states of frames 00b/00c were not photographed.
6. **The hold threshold is 0.6 s** and the harness presses for 1.4 s. Where the boundary actually
   falls for a hand on the real remote is the owner's to feel.
