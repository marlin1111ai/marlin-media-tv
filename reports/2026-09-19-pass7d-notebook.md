# Pass 7d — notebook only: the two "superseded" notes in DECISIONS.md — 2026-09-19

No new decision. Follows pass 7c (`reports/2026-09-19-pass7c-notebook.md`, commit `ee3613b`),
whose open question 3 this pass answers.

**All three steps done.** The only files written are `DECISIONS.md`, `COLD-START.md` and this
report. Nothing was built, installed or launched; neither Apple TV and nothing under
`~/vlckit-build` was touched. The `PlayerHost.swift` hook, the five harnesses, `Notes/` and
`icon pixel/` are exactly as they were, unstaged.

## Result per step

| step | result |
|---|---|
| 1 | two notes added to `DECISIONS.md`, in D008's style; the original wording of both entries stays; no other line changed |
| 2 | pass 7d note added to Pass history; Current state's "As of" line and Pushed list kept current; this report |
| 3 | one commit of three files by explicit path, pushed fast-forward; SHAs in the closing message |

## 1. The two entries, before and after

The file's rule, from its own head: "a superseded decision stays in place with a note". The style
followed is D008's — "**Superseded in part 2026-09-14 (pass 1k):** the back step is VLC's native
previous-frame, exact — D008 (revised) under pass 1k." — a bold dated lead, what now holds, and
where the later decision sits.

**D045 — before:**
> - **D045** **The clock is on the player while paused, and only while paused.** This **revises
>   D041's "not on the player"**: frames 10–15 draw no clock, and the owner's call of 2026-09-15
>   adds one for the paused state.

**D045 — after:**
> - **D045** **The clock is on the player while paused, and only while paused.** This **revises
>   D041's "not on the player"**: frames 10–15 draw no clock, and the owner's call of 2026-09-15
>   adds one for the paused state. **Superseded in part 2026-09-19 (pass 7):** the clock shows
>   whenever the film is not playing, scrub and buffering included — D054 under pass 7.

**D064, item 10 — before:**
> - 10 **OPEN:** keep the evidence log on, or switch it off in the everyday app — the owner
>   decides from pass 7's numbers (`reports/2026-09-19-pass7-cleanup.md` §2).

**D064, item 10 — after:**
> - 10 **OPEN:** keep the evidence log on, or switch it off in the everyday app — the owner
>   decides from pass 7's numbers (`reports/2026-09-19-pass7-cleanup.md` §2). **Closed 2026-09-19
>   (pass 7b):** the log stays on in the everyday app — D067 under pass 7b.

`git diff` of `DECISIONS.md` shows two hunks and nothing else: line 424 became two lines, line 714
became two lines. Each hunk keeps the original words and adds only the note. The notes sit at the
end of the sentence they qualify, as D008's does; D045's other paragraphs ("What shows", "Hidden
while a track panel is open", "Nothing else in the player changed") are untouched, and none of
them says "only while paused".

For item 10 the note says "Closed", not "Superseded": D067 did not replace a decision, it answered
a question D064 had left open. The form is otherwise D008's.

## 2. COLD-START.md

- Pass history: a pass 7d note, the last entry.
- Current state, first line: "As of **pass 7d (2026-09-19)**, the newest pass …", with one clause
  added for this pass.
- Pushed: one bullet, "**Pass 7d as one notebook commit on top of `ee3613b`**, which is pass 7c's
  commit (`d813054..ee3613b`)".

This pass's prompt names both of those Current state lines, which settles the question passes 7b
and 7c asked about them.

## 3. Commit and push

One commit on top of `ee3613b`, three files staged by explicit path — `DECISIONS.md`,
`COLD-START.md`, `reports/2026-09-19-pass7d-notebook.md` — pushed to `origin main` as a
fast-forward, no force. The SHA and the three-way comparison are in the closing message.

**Pushed:** those three files. **Stays local, exactly as before:** the `PlayerHost.swift` hook, the
five harnesses, `Notes/`, `icon pixel/` and everything git-ignored.

`git status --porcelain --ignored` before the pass:
```
 M "Marlin Media TV/PlayerHost.swift"
?? "Marlin Media TVUITests/Diag2gUITests.swift"
?? "Marlin Media TVUITests/Pass2bUITests.swift"
?? "Marlin Media TVUITests/Pass2cUITests.swift"
?? "Marlin Media TVUITests/Pass3ShotsUITests.swift"
?? "Marlin Media TVUITests/Pass3bShotsUITests.swift"
?? Notes/
?? "icon pixel/"
!! .DS_Store
!! Design/.DS_Store
!! Frameworks/
!! build/
!! reports/.DS_Store
!! tools/.DS_Store
```
After the commit it is expected to be the same block, line for line; the closing message shows the
actual diff.

**One line in that block is new since pass 7c, and it is not this pass's:** `!! tools/.DS_Store`.
It was already there when this pass took its first snapshot, before anything was written — Finder
writes that file when a folder is opened in it. It is git-ignored, and this pass did not create,
read or touch it.

## Files touched, by step

| step | files |
|---|---|
| 1 | `DECISIONS.md` (two notes) |
| 2 | `COLD-START.md` (Pass history note, the "As of" line, one Pushed bullet); this report |
| 3 | none |

Scratch: a status snapshot and a before-copy of `DECISIONS.md` in the session scratch folder,
deleted at the end.

## Open questions

None from this pass. Still standing from earlier, and unchanged: COLD-START's three parked items
(the scrub thumbnails, D055; the edition with no name and badges on shows, D064), and pass 7c's
open question 1 — whether "the paused clock (D045)" in `PlayerScreen.swift`'s line was a
contradiction or merely old. This pass's notes to D045 lean the same way as that correction.

## The things I am least sure of

1. **"Closed" rather than "Superseded" for item 10.** The prompt asked for the "superseded" note in
   D008's style for both. I kept D008's form and used the word that fits what happened; if the
   uniform word is wanted, it is one word to change.
2. **That these were the only two.** Pass 7c found them while reading `COLD-START.md`, not by
   reading `DECISIONS.md` end to end for superseded entries. D050 already carries its revision in
   D061's own text ("This revises D050's 'only if the owner asks'") but has **no note on D050
   itself**; D041's "Not on the player" is likewise revised by D045 with the note only on D045's
   side. I did not edit either — this pass names two entries and says no other line changes — but
   by the file's rule they are the same kind of gap.
