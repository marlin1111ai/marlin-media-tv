# Pass 2 — resume, watched, Continue Watching, Recently Added

2026-09-15. Built against the server's playback state (image 0.3.0) and verified on Home Theater
with a real build. Decisions: DECISIONS.md **D023–D030**. Recon: `reports/2026-09-15-pass2-recon.md`.

## Result

**Steps 1, 2, 3, 4, 6, 7, 8 and 9 are built and proven on the device. Step 5 is built and proven
except its press-and-hold, which does not work and was not retried — the pass stopped there.**

| Step | What | State |
|---|---|---|
| 1 | Recently Added sort on all three tabs | **done**, proven (t1) |
| 2 | `GET /api/continue-watching`, `PUT …/playback`, failures to the log only | **done**, proven (every test) |
| 3 | Continue Watching row, per-kind, server order, card plays from the saved position | **done**, proven (t1, t4, t5) |
| 4 | Movie + video detail: pill, Resume, Start over, Mark watched/unwatched, multi-edition rule, picker line | **done**, proven (t2, t3, t6) |
| 5 | Show detail: "N unwatched", per-episode state column, resume on click | **done**, proven (t7) |
| 5 | Show detail: **press-and-hold mark menu** | **FAILS — see "Where it stopped"** |
| 6 | Position every 10 s / pause / stop / exit, never under 120 s | **done**, proven (t2b, t4, t5b, t6, t8) |
| 7 | Watched at 90 %, once | **done**, proven (t5b) |
| 8 | Start at a saved position | **done**, proven (t2b, t4, t5b); mechanism below |
| 9 | Notebook | **done** (DECISIONS.md D023–D030, COLD-START.md) |

## Where it stopped — step 5's press-and-hold

A hold on an episode row **plays the episode** instead of opening the mark menu.

- **Evidence** (`reports/logs/2-t7-app.log`, harness note, `reports/screenshots/p2/p2-t7-02-hold-menu.png`):
  the hold began at 21:13:49.409 on S1E2 and one second later the log reads
  `[playback] file 9 saved position 0.0 s watched=false; starting at 0 ms`. The screenshot taken where
  the menu should be shows the player on "S1 E2 · The Source of Magic" at 00:01. The harness note reads
  `HOLD MENU DID NOT OPEN — focus is ["()"]`. The server confirms nothing was written: file 9 is still
  `position 0, watched false, last_played null`.
- **Cause.** `.onLongPressGesture(minimumDuration:)` was attached to the episode row's `Button`. On tvOS
  the Button consumes the select press and fires its own action on release, so the long-press recognizer
  never gets the gesture. This is an implementation choice of mine, not anything in D008/D021.
- **Not retried**, per the stop-and-report rule. The menu itself (`markMenu(for:)`, the picker's styling,
  the write and the reload) is built and correct; only the way in is missing. Candidates for the next pass,
  none implemented: (a) a `UILongPressGestureRecognizer` on a `UIViewRepresentable` host around the row,
  which is how `PlayerHost` already handles presses; (b) making the row a focusable non-Button view with
  `.onLongPressGesture` and an explicit select handler; (c) a different gesture entirely (e.g. Play/Pause
  on the focused row), which would be a new owner decision.

Everything else in step 5 is proven by `reports/screenshots/p2/p2-t7-01-show-detail-states.png`:
"13 unwatched" at the end of the meta row, E1 reading "36 min left" with the bar across its still, and
E2–E5 reading "Unwatched".

## The resume mechanism (step 8)

**Chosen: play, then one seek at the first `Playing` state** — D021's landing path
(`PlayerModel.applyStartPositionIfNeeded`).

| Film | Saved | Seek | Time at +1 s | Effective landing |
|---|---|---|---|---|
| Stargate Extended (MPEG-2, .mkv) | 1 800.0 s | 1 800 000 ms | 1 800 835 ms | ≈ **−165 ms** |
| Magicians S1E1 (H.264, .mp4) | 904.452 s | 904 452 ms | 905 191 ms | ≈ **−261 ms** |
| Food S4E2 (H.264, .mkv) | 3 560.0 s | 3 560 000 ms | 3 560 771 ms | ≈ **−229 ms** |

(The +1 s sample includes a second of playback, so the landing is the offset minus ~1 000 ms.)
`length` is the file's own in every case, 0 `PCR is called … late` and 0 `clock gap` in every run, and the
single `ES_OUT_RESET_PCR` per resume is that seek's own (`SET_TIME to 1800000000`, preroll pts 1 799.815 s —
D014's trusted cues landing just before the target). D008, D014, D016 and D021 are untouched.

**Rejected: the `:start-time=` media option**, tried first on the device. It shows the right picture but
**re-bases VLC's timeline**: for Stargate Extended `length` came back as **5 998 056 ms** instead of
7 798 056, and `player.time` restarted at 0 — the overlay read `00:15 / −1:39:43` with the knob at the far
left (`reports/logs/2-t2-app.log`, and the two clock screenshots below). Every position written would have
been short by the start offset, the 90 % mark would have measured the remainder, and D021's scrub would have
mapped over a truncated timeline. Compensating with an offset would have meant touching every path that
reads the clock — skips, frame step, scrub — which this pass was told not to disturb.

- Rejected: `reports/screenshots/p2/p2-t2-03-resumed-clock.png` (00:15 / −1:39:43).
- Chosen: the same shot after the change, `30:14 / −1:39:44` with the knob a quarter along.

## Files touched, by step

| File | Steps |
|---|---|
| `Marlin Media TV/LibraryModel.swift` | 1 (SortOrder + the three sorts), 3 (the row's state, refresh, `playRequest(for:)`) |
| `Marlin Media TV/Models.swift` | 1 (`Format.addedAt`/`rfc3339`), 2 (`ContinueEntry`), 3/4/5 (`Format.timeLeft`, `Format.share`) |
| `Marlin Media TV/ServerAPI.swift` | 2 (`continueWatching`, `putPlayback`, `PlaybackWrite`) |
| `Marlin Media TV/LibraryScreen.swift` | 3 (the row, the cards, the grid's lead, `.focusSection()`) |
| `Marlin Media TV/ContentView.swift` | 3 (a card opens the player; the row is re-read when the player closes) |
| `Marlin Media TV/MovieDetailScreen.swift` | 4 (pill, Resume + bar, Start over, mark, followed edition, picker line; the shared `WatchedPill`, `ResumeButtonLabel`, `SecondaryButtonLabel`) |
| `Marlin Media TV/VideoDetailScreen.swift` | 4 |
| `Marlin Media TV/ShowDetailScreen.swift` | 5 (unwatched count, state column, in-still bar, resume on click, the mark menu — unreachable) |
| `Marlin Media TV/PlayRequest.swift` | 8 (`startMs`, `resume:`) |
| `Marlin Media TV/PlayerModel.swift` | 6, 7, 8 (writes, the 90 % mark, the resume seek) |
| `Marlin Media TV/EvidenceLog.swift` | 6/7 support: the log file is opened on the first line, not only when a player starts — the detail screens' writes happen with no player up and would otherwise never reach the file |
| `Marlin Media TVUITests/Pass2UITests.swift` | the evidence harness (new) |
| `DECISIONS.md`, `COLD-START.md` | 9 |

## What was measured, per requirement

- **A movie resumed from a saved spot, landing vs saved position** — t2b, table above.
- **Start over** — `PUT file 4 position=0.0 (start over) → 200` *before* playback, then
  `starting at 0 ms` with the full `length 8476217 ms`; the 13 s that followed wrote nothing (under the floor).
- **Mark watched / unwatched on a movie** — `PUT file 4 position=0.0 watched=true (mark watched) → 200`
  and `… watched=false (mark unwatched) → 200`, the screen re-read each time
  (`p2-t3-04-marked-watched-pill.png` shows the pill, "Play" with no bar and no Start over, and
  "Mark unwatched").
- **Mark via the episode hold menu** — **not run: the menu cannot be opened** (above).
- **The 90 % mark, and removal from Continue Watching** — `90% reached at 3578411 ms of 3975982 ms`
  (threshold 3 578 384), `PUT file 5 position=0.0 watched=true → 200`, then
  `position not written … already marked watched` three times and once at exit; the server shows
  `position 0, watched true` and the row drops from 3 entries to 2
  (`p2-t5-01-row-before.png` → `p2-t5-03-row-after.png`).
- **A peek under two minutes leaving no saved spot** — 48 s of Divergent: four periodic attempts and the
  exit attempt all logged `under 120 s`, **0 PUTs in the run**, and the server still reads
  `position 0, watched false, last_played null`.
- **A Continue Watching card playing an episode with scrub thumbnails** — one Down from the tabs focuses
  `continue.8`, the card plays file 8 directly (no detail screen, no picker), `[thumbs] file 8: 313 stills
  … state complete`, and a paused drag shows the server's still above the bar
  (`p2-t4-04-scrub-thumbnail.png`), with Menu cancelling back to exactly 919 251 ms.
- **A multi-edition movie's button and picker** — the buttons follow Extended (the only edition with a
  `last_played`), Play opens the picker, and "Resume · 1 h 40 min left" shows under Extended only
  (`p2-t2-01-detail-resume-button.png`, `p2-t2-02-picker-resume-line.png`).
- **Recently Added on all three tabs** — t1: the menu lists Title / Year / Recently Added, and the sort was
  applied on Movies, TV Shows and Videos. **The Videos tab has no videos on this server**, so its ordering
  could not be observed — only that the tab accepts the sort and still shows frame 04's empty state.
- **Empty-row hiding** — with continue-watching empty, there is no heading and no row and the grid sits
  directly under the header (`p2-t1-01-movies-title-no-continue-row.png`).
- **Skips, frame step and scrub unchanged** — +30 s 23 626 → 53 626 ms and −10 s 55 682 → 45 682 ms (exact);
  three back and three forward steps moving one picture each on the 41–42 ms grid (47 798 → 47 839 → 47 881
  → 47 923); a scrub landing `time=215510 ms (expected 215510 ms)` — 0 ms off.

## The playback state left on the server

| File | Item | position | watched | last_played |
|---|---|---|---|---|
| 1 | Divergent | 223.52 | false | 2026-09-16T01:16:25Z |
| 2 | Stargate · Extended | 1 821.678 | false | 2026-09-16T00:55:13Z |
| 3 | Stargate · Theatrical | 0 | false | null |
| 4 | Wonder Woman | 0 | false | 2026-09-16T00:58:35Z |
| 5 | Food That Built America S4E2 | 0 | **true** | 2026-09-16T01:09:39Z |
| 8 | Magicians S1E1 | 968.576 | false | 2026-09-16T01:07:27Z |
| 6, 7, 9–20 | everything else | 0 | false | null |

Continue Watching therefore holds three entries: Divergent (223.5 s), Magicians S1E1 (968.6 s) and
Stargate Extended (1 821.7 s). All of it is test state written by this pass — the owner may want it cleared
before real use.

## Committed vs pushed

**Committed locally on `main`; nothing pushed** — the owner tests on Home Theater first, as instructed.
Home Theater is left running this build. Still uncommitted and untouched, as instructed:
`Marlin Media TVUITests/Diag2gUITests.swift` and the Page Up / Page Down hook in
`Marlin Media TV/PlayerHost.swift` (the hook is what let the scrub be scripted in t4 and t8).

## Open questions

1. How should the press-and-hold be reached — a `UILongPressGestureRecognizer` host, a focusable
   non-Button row, or a different gesture entirely?
2. A detail screen re-reads itself after the mark buttons but **not** on return from the player, so after
   Start over (or after watching) it can show a stale "Resume · N min left" until it is re-entered
   (`p2-t3-03-detail-after-start-over.png` shows exactly this). Should detail screens re-read on appear?
3. On a movie with several editions, Start over and the mark buttons act on the **followed** edition
   without opening the picker, while Play/Resume opens it. Is that the wanted split?
4. The Continue Watching row remembers its own last focused card, so returning to a tab lands on the card
   last used rather than the first. Leave it?
5. Should the row show a title already marked watched but with a position (impossible today: the mark
   writes position 0), and should "Start over" also clear `watched`?
6. Nothing clears test state: is a "clear playback state" action wanted anywhere, or is that server-side?
7. The Videos tab could not exercise Recently Added (no videos on the server). Worth re-checking when a
   video exists?
8. The 90 % mark uses VLCKit's `length`; the server's `duration` differs slightly on some files
   (3 975 982 ms vs 3 975.981065 s here — the same, but not guaranteed). Keep VLCKit's?

## Least sure

1. **The hold menu's failure mode is diagnosed from the log and the screenshot, not instrumented.** That a
   SwiftUI `Button` swallows the tvOS long press is the reading of the evidence (hold → play, no menu), not
   a traced call.
2. **The resume landings are computed**, not measured against the picture: the log samples `player.time` one
   second after the seek, so the quoted offsets subtract a nominal 1 000 ms of playback.
3. **The 10 s cadence is the task's, not the wall clock's** — the writes sit at 9–10 s apart in the logs.
4. **The video detail's behaviour (step 4) was never run on the device**: this library has no videos, so
   `VideoDetailScreen` is traced from the code and from the movie detail it mirrors, not observed.
5. **Positions were seeded by PUT** to make resume and the 90 % mark testable in seconds; nothing watched a
   film for an hour, so a long real session is unproven.
6. **`.focusSection()` on the row** fixed the focus path on this tvOS build; it is one line of layout
   behaviour and could shift with a future tvOS.
