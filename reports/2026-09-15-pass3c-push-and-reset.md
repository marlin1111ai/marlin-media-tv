# Pass 3c — the push, and the test-state reset

2026-09-15. The owner tested passes 2, 2b, 2c, 3 and 3b on Home Theater and **accepted them all**
("all good"). This pass pushes those five commits and zeroes the playback state the builder passes
wrote. Decisions: DECISIONS.md **D046**, **D047** (which discharges **D037**). No app source was
touched and nothing was built or installed.

## Result

| Step | What | State |
|---|---|---|
| 1 | Push `main` to `origin`, fast-forward, no force | **done** — `3597d0a..896ee12`, five commits |
| 2 | Reset the playback state on every file a builder pass wrote | **done** — five files, five `200`s, Continue Watching empty |
| 3 | Notebook (D046, D047) and this report | done |

## Step 1 — the push

Checked before pushing:

```
$ git fetch origin
$ git rev-parse origin/main        3597d0a80e3012da1dd8ea594ca804cfe421ea13
$ git merge-base --is-ancestor 3597d0a main    → 3597d0a IS an ancestor of main
$ git log --merges --oneline 3597d0a..main     → (empty)
$ git rev-list --count 3597d0a..main           → 5
```

Every commit in the range has exactly one parent, so the range is linear and the push is a genuine
fast-forward. The five commits, oldest first:

| SHA | Commit |
|---|---|
| `b3f3b02` | Pass 2: resume, watched, Continue Watching and Recently Added — STOPPED at step 5's press-and-hold |
| `8def8cd` | Pass 2b: detail screens re-read on player close; the hold and first-card focus STOPPED |
| `ef9ce11` | Pass 2c: Continue Watching focus fixed; the episode hold STOPPED one step short |
| `a99cccc` | Pass 3: the episode rows fixed, the Home page built, the clock added |
| `896ee12` | Pass 3b: launch focus on the first Continue Watching card, the player's paused clock |

```
$ git push origin main
To https://github.com/marlin1111ai/marlin-media-tv.git
   3597d0a..896ee12  main -> main
```

Verified afterwards — all three agree:

```
local main:   896ee1293ac98d643c073775f5f9d191e1aa5d5c
origin/main:  896ee1293ac98d643c073775f5f9d191e1aa5d5c
ls-remote:    896ee1293ac98d643c073775f5f9d191e1aa5d5c
```

`Frameworks/VLCKit.xcframework` stays git-ignored (`.gitignore:47`) and nothing under `Frameworks/`
is tracked on any ref, so the custom VLCKit was not pushed, as in passes 1l and 2h.

## Step 2 — the test-state reset (D037)

### Which files, and who wrote them

Every `PUT …/playback` line in `reports/logs/` across all five passes names **five file ids and no
others**:

```
$ grep -rhoE "PUT file [0-9]+ [^→]*→ [0-9]+" reports/logs/ | ...
file 1 ×4     file 2 ×5     file 4 ×9     file 5 ×2     file 8 ×7
```

Pass 2 also seeded positions by hand with `PUT` (files 2, 5 and 8) so that a resume and the 90 %
mark could be tested in seconds rather than an hour; those are inside the same set.

A full read of the library before writing anything confirms the list is not just "at least" but
**exactly** complete — of the twenty files on this server, only these five carry any state, and
files 3, 6, 7 and 9–20 are all `position 0, watched false, last_played null`:

| file | item | before: position | watched | last_played | written by |
|---|---|---|---|---|---|
| 1 | Divergent | 0 | false | `2026-09-16T01:45:31Z` | pass 2b, Start over (`PUT file 1 position=0.0 (start over) → 200`) |
| 2 | Stargate · Extended | 1 821.678 | false | `2026-09-16T00:55:13Z` | pass 2, the stop write (`PUT file 2 position=1821.7 (stop) → 200`) |
| 4 | Wonder Woman | 2 457.189 | false | `2026-09-16T03:24:21Z` | pass 2c (161.4 s), then pass 3's run, then the owner's acceptance testing |
| 5 | The Food That Built America S4 E2 · Holiday Treats | 0 | **true** | `2026-09-16T01:09:39Z` | pass 2, the 90 % mark (`PUT file 5 position=0.0 watched=true (90% watched) → 200`) |
| 8 | The Magicians S1 E1 · Unauthorized Magic | 1 224.173 | false | `2026-09-16T02:24:50Z` | pass 2 (seeded 904.452 s), then 2b/2c/3; pass 3b's log reads `episode/8@1224s` |

Files 4 and 8 stand **past the figures in the pass 2c report**, and that is expected rather than a
surprise: pass 3's own run played both (its report records no write of its own beyond the app's), and
pass 3b's log line `[continue] 3 entries: movie/4@2444s, episode/8@1224s, movie/2@1821s` already shows
4 at 2 444 s and 8 at the 1 224 s read here. File 4's last_played of `03:24:21Z` (8:24 PM local) is
later still — the owner's own testing this evening. Every one of the five is test state on a test
title, traceable to a builder write; none needed a stop.

Before the writes:

```
GET /api/continue-watching?limit=200 → 3 entries: movie/4@2457.189s, episode/8@1224.173s, movie/2@1821.678s
```

There is no read-back route for a single file (`GET /api/files/1/playback` is `404 page not found`,
pass 2's recon §2.5), so each block above was read off its item — `GET /api/movies/{id}` for the
editions, `GET /api/shows/{id}` for the episodes.

### The writes

`PUT /api/files/{fileId}/playback` with body `{"position": 0, "watched": false}`, five files and no
others:

```
PUT file 1 -> 200  {"position": 0, "watched": false, "last_played": "2026-09-16T03:29:43Z"}
PUT file 2 -> 200  {"position": 0, "watched": false, "last_played": "2026-09-16T03:29:43Z"}
PUT file 4 -> 200  {"position": 0, "watched": false, "last_played": "2026-09-16T03:29:43Z"}
PUT file 5 -> 200  {"position": 0, "watched": false, "last_played": "2026-09-16T03:29:43Z"}
PUT file 8 -> 200  {"position": 0, "watched": false, "last_played": "2026-09-16T03:29:43Z"}
```

### After

Re-read off the items, and the row re-read:

| file | item | after: position | watched | last_played |
|---|---|---|---|---|
| 1 | Divergent | 0 | false | `2026-09-16T03:29:43Z` |
| 2 | Stargate · Extended | 0 | false | `2026-09-16T03:29:43Z` |
| 4 | Wonder Woman | 0 | false | `2026-09-16T03:29:43Z` |
| 5 | The Food That Built America S4 E2 | 0 | false | `2026-09-16T03:29:43Z` |
| 8 | The Magicians S1 E1 | 0 | false | `2026-09-16T03:29:43Z` |

```
GET /api/continue-watching?limit=200 → []
```

A sweep of all twenty files afterwards finds **no file anywhere carrying a position or a watched
flag**. The Magicians is 13/13 unwatched again and The Food That Built America 3/3.

### One thing the reset does not clear, and why it does not matter

`last_played` is **not null** on the five — it is the reset's own timestamp, `2026-09-16T03:29:43Z`,
because the server stamps it on every write and the body the brief specifies carries no way to clear
it. So the five files are not byte-identical to a file that has never been played (`last_played:
null`); they are **behaviourally identical** everywhere the app looks:

- **Continue Watching** is `position > 0 and watched = false` server-side (pass 2 recon §2.5), so a
  non-null `last_played` puts nothing back in the row — proven by the empty list above.
- **Recently Added** (D023) sorts on the item's `added` field, not on `last_played`, and no `added`
  was touched.
- **The detail screens** read `position` and `watched` for the pill, Resume and the bar (D026, D027);
  none of them reads `last_played`.
- **The multi-edition rule** (D026/D034) picks the *followed* edition by `last_played`. On Stargate,
  Extended (file 2) now has a `last_played` and Theatrical (file 3) still has null, so the buttons
  will still follow Extended. That is the one visible trace of the reset, and it is the same edition
  they followed before.

## Files touched

| File | Why |
|---|---|
| `DECISIONS.md` | D046, D047 |
| `COLD-START.md` | the current-state note for this pass |
| `reports/2026-09-15-pass3c-push-and-reset.md` | this report |

**No app source, no `Design/`, no `Frameworks/`, no `tools/`.** Nothing was built, installed or
launched; Home Theater is left running the pass 3b build, which is now the pushed `main`.

## Still uncommitted, deliberately

Unchanged by this pass and left in the working tree exactly as they were:

- `Marlin Media TV/PlayerHost.swift` — the Page Up / Page Down hook (pass 2g), the only modification
  to a tracked file; a copy is committed as `reports/logs/2g-harness-hook.diff`.
- `Marlin Media TVUITests/Diag2gUITests.swift` (pass 2g; copy committed as
  `reports/logs/2g-harness-Diag2gUITests.swift.txt`)
- `Marlin Media TVUITests/Pass2bUITests.swift`, `Pass2cUITests.swift`, `Pass3ShotsUITests.swift`,
  `Pass3bShotsUITests.swift` — the pass 2b/2c/3/3b harnesses.

## Open questions

1. The five reset files keep a `last_played` of the reset instant rather than null. If a true virgin
   state is wanted, it needs either a server-side clear or a `last_played` field on the PUT — a
   request to the server repo, not a client change.
2. D038 still stands: Videos Recently Added and the video detail screen have never run on a device,
   because this library has no videos.
3. Pass 3's open questions 3–6 (Home's per-show fetches, the TV row's wide card, the Videos heading
   with no videos, the pinned header) and pass 3b's 1–3 are untouched and still open.

## Least sure

1. **File 4's advance from 2 444 s to 2 457 s is attributed to the owner's acceptance testing.** That
   is the only thing that ran between pass 3b's log and this read, and the 13 s gap with a later
   `last_played` fits, but nothing instrumented it.
2. **The provenance column is read from the logs and the report tables**, not from server-side audit:
   the server keeps one playback row per file, not a history, so "who wrote this" is inference from
   matching timestamps and positions. Every one of the five matches a logged line exactly except
   file 4's final 13 s.
3. **"Behaviourally identical" is traced from the code and the recon, not re-tested on the device.**
   The empty Continue Watching list is measured; the detail screens and the edition rule were not
   re-photographed on Home Theater after the reset.
