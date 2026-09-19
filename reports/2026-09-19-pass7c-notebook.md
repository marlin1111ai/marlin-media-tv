# Pass 7c — notebook only: COLD-START read in full against D052–D067 — 2026-09-19

No decision; `DECISIONS.md` was not edited. Follows pass 7b
(`reports/2026-09-19-pass7b-notebook.md`, commit `d813054`).

**All six steps done.** The only files written are `COLD-START.md`,
`reports/2026-09-19-pass7b-notebook.md` (step 3 only), this report and, outside the repo, the one
index line in my `MEMORY.md`. No Swift, project, asset, design, recipe or harness file was touched;
nothing was built, installed or launched; neither Apple TV and nothing under `~/vlckit-build` was
touched. The `PlayerHost.swift` hook, the five harnesses, `Notes/` and `icon pixel/` are exactly as
they were, unstaged.

## Result per step

| step | result |
|---|---|
| 1 | the two lines pass 7b reported are corrected (D066, D061) |
| 2 | **a full read, top to bottom; one further contradicting line found and corrected (D054)** |
| 3 | the 7b report's two citations corrected to lines 121–122 and 174–175 |
| 4 | the `MEMORY.md` index line rewritten to match the note and D061 |
| 5 | pass 7c note added to Pass history; this report |
| 6 | one commit of three files by explicit path, pushed fast-forward; SHAs in the closing message |

## 1 and 2. Every corrected line, before and after

**Three lines corrected — counted by hand: two from step 1, one from step 2.**

| # | step | where | before | after | decision |
|---|---|---|---|---|---|
| 1 | 1 | *Toolchain facts* → VLCKit | "…so the recipe is 20 patches and the patch text survives only as `reports/logs/2f-0021-es_out-no-late-pcr-compensation-while-paused.diff.txt`." | "…so the recipe is 20 patches and the patch text lives in history at `e7676fa`, as `reports/logs/2f-0021-es_out-no-late-pcr-compensation-while-paused.diff.txt` (D066)." | D066 |
| 2 | 1 | *Build, install, run* → "Building for the other Apple TV" | "…builds and installs on the bedroom box (D050). Do that **only when the owner asks**: Home Theater is the dev/test device (D005), and the bedroom box is in household use — launching there puts the app on a television someone may be watching." | "…builds and installs on the bedroom box (D050). **Every push pass that follows the owner's acceptance of a pass that changed the app installs the accepted build there — install only, no launch (D061).** Home Theater is the dev/test device (D005), and the bedroom box is in household use — launching there puts the app on a television someone may be watching." | D061 |
| 3 | 2 | *How the app is put together* → `PlayerScreen.swift` | "…the scrub bar and its thumbnail, and the paused clock (D045)." | "…the scrub bar and its thumbnail, and the clock, which shows whenever the film is not playing, scrub and buffering included (D045, D054)." | D054 |

**Why line 3 counts as a contradiction and not merely old.** D045 put the clock on the player
"while paused, and only while paused"; the recon's §10a 7 asked whether showing it during a scrub
and while buffering was wanted; D054 answered that it "shows whenever the film is not playing,
scrub and buffering included". "The paused clock (D045)" describes it by the narrower rule that
D054 replaced. Current state already said it D054's way; this line did not.

A diff of the whole file against its state before this pass shows these three changes, the two
bookkeeping lines of §5 and the appended pass 7c note, and nothing else.

## 2. The full read

**Step 2 was a full read.** I read `COLD-START.md` from line 1 to line 952, every line, in this
pass — not a keyword search — holding it against D052–D067 one decision at a time. Lines 1–451 are
everything a pass may edit; lines 452–952 are the Pass history notes, which I read and, as records
of what was written at the time, did not edit.

| decision | what it says | result |
|---|---|---|
| D052 | videos run on the device; D038 discharged | no contradicting line left (the `VideoDetailScreen.swift` line was corrected in pass 7b) |
| D053 | Home stays as built: per-show fetch, wide episode cards, Videos heading always shows, header scrolls | no contradicting line left |
| D054 | frames 16/17 by code trace, accepted; the player clock shows whenever the film is not playing | **line 3 above, corrected** |
| D055 | the scrub thumbnails parked on the server; the owner's direction for later | no contradicting line left — the "asked for once when a detail screen opens … never polled or re-fetched" line describes the app as it is today, which D055 does not change |
| D056 | the player's known behaviours and one-offs accepted; arrow clicks ignored during a scrub | no contradicting line left |
| D057 | nothing is submitted to VideoLAN; the draft stays | no contradicting line left |
| D058 | `last_played` closed | no contradicting line left |
| D059 | Inter, "Browse cached" and frame 06's "R" overruled | no contradicting line left (the Fonts and `LibraryScreen.swift` lines were corrected in pass 7b) |
| D060 | the icon and Top Shelf items closed | no contradicting line left |
| D061 | the push pass installs accepted builds on Master Bedroom ATV, install only | **line 2 above, corrected** (the Devices line was corrected in pass 7b) |
| D062 | `~/vlckit-build` kept; its size | no contradicting line left |
| D063 | `icon pixel/` and `Notes/` are the owner's, outside git | no contradicting line left |
| D064 | pass 1's questions: subtitles, unnamed edition and badges parked, the audio panel | no contradicting line left |
| D065 | closed on the owner's word; `Theme.swift`'s comment | no contradicting line left (the `Theme.swift` line was corrected in pass 7b) |
| D066 | the screenshots and logs live at `e7676fa` | **line 1 above, corrected** (the pass 2g copies line was corrected in pass 7b) |
| D067 | the evidence log stays on | no contradicting line left |

**Lines I weighed and left alone — old or general, but contradicting no decision:**
- *Where things are → Design:* "Build what the frames show; design nothing (D006)." D053 and D059
  overrule the frames in four named places. D006 is the standing rule and was not withdrawn; the
  overrules are the owner's exceptions to it, and Current state lists them.
- *How the app is put together → `HomeScreen.swift`:* "up to six **episode** cards in the frames'
  wide card". The wide card is the frames' own element; the line does not say the frames draw the
  TV Shows row with it, which is the thing D053 overrules.
- *Where things are → Devices:* "D050 is the narrow exception and does not reopen it for testing."
  Still true under D061, which leaves D005 unchanged. The closing line of that block, "All the
  facts above were read from `xcrun devicectl` on 2026-09-16", now sits under a sentence about
  D061 that `devicectl` did not supply — awkward, not a contradiction.
- *Current state → Pushed:* pass 7's bullet still says "the SHA is in the pass's closing message".
  True when written; the pass 7b bullet below it gives the SHA.
- **In Pass history, not edited by rule:** older notes naturally say things the decisions later
  changed — pass 6's "The open items are unchanged", pass 2h's "copies are committed as",
  pass 3's clock "**not** on the player", pass 7's "one is open". They are records.

## 3. The 7b report's citations

`reports/2026-09-19-pass7b-notebook.md` cited the two further lines at "lines 119–120" and
"lines 171–173". Those were their places **before** pass 7b's own edits moved them. In the file as
pass 7b committed it (`git show d813054:COLD-START.md`) the quoted words are on **lines 121–122**
and **lines 174–175**, and the report now says so — in §2, where they are cited, and in open
question 1, which repeated the same two numbers. Nothing else in that report changed.

**My closing message for pass 7b gave "120–121 and 173–175". That was one line off at each
start**; 121–122 and 174–175 are the numbers checked against the commit.

## 4. The memory index line

File: `~/.claude/projects/-Users-marlin1111-Xcode-Marlin-Media-TV/memory/MEMORY.md`, the third of
its three lines. The other two lines were not touched.

**Before:**
> - [Bedroom Apple TV: app yes, testing no](bedroom-appletv-off-limits.md) — it carries the app
>   since D050, but Home Theater stays the only test device; still confirm before touching it

**After:**
> - [Bedroom Apple TV: accepted builds yes, testing no](bedroom-appletv-off-limits.md) — D061: the
>   push pass after the owner's acceptance installs there, install only, no launch; Home Theater
>   stays the only test device (D005); anything else there only when the owner asks

(Each is one line in the file; wrapped here.)

## 5. Pass history, and the same two bookkeeping lines as pass 7b

The pass 7c note is the last entry of Pass history. As in pass 7b, two lines of Current state were
kept current although the prompt did not name them: its first line now reads "As of **pass 7c
(2026-09-19)**, the newest pass …", and **Pushed** gained one bullet, "**Pass 7c as one notebook
commit on top of `d813054`**, which is pass 7b's commit (`f4fafa1..d813054`)". Pass 7b's report
asked whether these were acceptable; this pass's prompt neither confirmed nor objected, so I did
the same again and name it again.

## 6. Commit and push

One commit on top of `d813054`, three files staged by explicit path — `COLD-START.md`,
`reports/2026-09-19-pass7b-notebook.md`, `reports/2026-09-19-pass7c-notebook.md` — pushed to
`origin main` as a fast-forward, no force. The SHA and the three-way comparison are in the closing
message.

**Pushed:** those three files. **Stays local, exactly as before:** the `PlayerHost.swift` hook, the
five harnesses, `Notes/`, `icon pixel/`, everything git-ignored — and `MEMORY.md`, which lives
outside the repo.

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
```
After the commit it is expected to be the same block, line for line; the closing message shows the
actual diff.

## Files touched, by step

| step | files |
|---|---|
| 1 | `COLD-START.md` (two lines) |
| 2 | `COLD-START.md` (one line) |
| 3 | `reports/2026-09-19-pass7b-notebook.md` (two citations, each in the two places it appears) |
| 4 | `MEMORY.md`, outside the repo (one line) |
| 5 | `COLD-START.md` (Pass history note; the as-of line and one Pushed bullet); this report |
| 6 | none |

Scratch: a status snapshot and a before-copy of `COLD-START.md` in the session scratch folder,
deleted at the end.

## Open questions

1. **Line 3.** I judged "the paused clock (D045)" a contradiction of D054 and corrected it. If that
   reads as merely old, it is one self-contained line to put back.
2. **The bookkeeping lines** (§5), asked in pass 7b and still unanswered: should every notebook pass
   keep Current state's first line and the Pushed list current, as I have done twice now?
3. **`DECISIONS.md` itself carries two lines that a later decision overtook** — D045's "while
   paused, and only while paused" (D054) and D064's "10 **OPEN**" (D067). The file's own rule is
   that "a superseded decision stays in place with a note", and neither has that note. This pass
   may not edit `DECISIONS.md`; reported only.

## The things I am least sure of

1. **The four lines left alone** (§2). Each is a judgement that a line is general or old rather
   than contradicting — the "Build what the frames show" line most of all, since four overrules now
   sit against it.
2. **A full read finds what the reader recognises.** I read every line against sixteen decisions,
   but a contradiction that depends on a fact I do not hold — something about the app's behaviour
   that neither the notebook nor the decisions state — would pass unnoticed.
3. **The 7b report was edited in three places, not two**: the two citations, and open question 1
   where the same two numbers were repeated. I took "the two line-number citations" to mean the two
   numbers wherever they appear.
