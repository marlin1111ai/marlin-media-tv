# Pass 7b — notebook only: the evidence log decided, six stale lines corrected — 2026-09-19

Decision: **D067**. Follows pass 7 (`reports/2026-09-19-pass7-cleanup.md`, commit `f4fafa1`).

**All five steps done.** The only files written are `COLD-START.md`, `DECISIONS.md`, this report
and, outside the repo, my own saved memory note about the bedroom Apple TV. No Swift, project,
asset, design, recipe or harness file was touched; nothing was built, installed or launched;
neither Apple TV and nothing under `~/vlckit-build` was touched. The `PlayerHost.swift` hook, the
five harnesses, `Notes/` and `icon pixel/` are exactly as they were, unstaged.

**Two more lines turned up that disagree with the decisions. Both are reported below and neither
was edited** (§2).

## Result per step

| step | result |
|---|---|
| 1 | **D067** recorded under "2026-09-19 — pass 7b"; the evidence-log item removed from COLD-START's Open items, which now holds three entries, all parked |
| 2 | the six lines corrected, each to its decision; the listing removed from Current state; **two further lines found and reported, not edited** |
| 3 | the memory note rewritten to match D061; before and after in §3 |
| 4 | pass 7b note added to Pass history; this report |
| 5 | one commit of three files by explicit path, pushed fast-forward; SHAs in the closing message |

## 1. D067 and Open items

`DECISIONS.md` gained one heading and one decision: **the evidence log stays on in the everyday
app; closed.** It carries pass 7's facts as asked — each launch replaces
`Library/Caches/marlin-media-tv.log` (`EvidenceLog.swift:31`); nothing caps its size; 53 049 bytes
over 25.3 s on Home Theater on 2026-09-19; pass 1k's 0.7–0.9 MB an hour — and that a whole film's
worth was never measured.

**COLD-START.md's Open items as it now stands — three entries, counted by hand:**
1. **PARKED — the scrub thumbnails (D055).** Waiting on the server generating thumbnails at scan;
   the owner's direction for when it lands; and, parked with it, the letterboxed stills, the
   missing "which still" log line and the thumbnail's untested ground.
2. **PARKED — an edition with no name** — "show nothing where an edition has no name"; not built
   (D064).
3. **PARKED — badges on shows, possibly later** (D064).

Its lead now reads: "49 of the recon's 56 are closed. **Three entries remain, all parked (seven of
the recon's numbers). Nothing is open.**" The arithmetic: 56 − 7 parked (§10a 8, 9, 10, 11;
§10b 7, 8, 26) = 49 closed; pass 7 had 48 closed and §10b 10 open.

## 2. The six lines, before and after

| # | where | before | after | decision |
|---|---|---|---|---|
| 1 | Where things are → Devices, Master Bedroom ATV | "Nothing is proven there, no evidence is taken there, and it is not reinstalled on as a matter of course." | "Nothing is proven there and no evidence is taken there. **Every push pass that follows the owner's acceptance of a pass that changed the app also installs the accepted build there — install only, no launch (D061).**" | D061 |
| 2 | Toolchain facts → Fonts | "no font is bundled (still an open question in the pass-1 report)." | "no font is bundled — the system font stays and Inter is overruled (D059)." | D059 |
| 3 | Build, install, run → Evidence harnesses | "Copies of the pass 2g pair are committed as evidence: `reports/logs/2g-harness-Diag2gUITests.swift.txt` and `reports/logs/2g-harness-hook.diff`." | "The evidence copies of the pass 2g pair, `…Diag2gUITests.swift.txt` and `…2g-harness-hook.diff`, live in history at `e7676fa` (D066)." | D066 |
| 4 | How the app is put together → `LibraryScreen.swift` | "Frame 17's "Browse cached" button is still not built." | "Frame 17's "Browse cached" button is not built: no cache and no button, the frame overruled (D059)." | D059 |
| 5 | same → `VideoDetailScreen.swift` | "**Never run on a device** — this library has no videos (D038)." | "The owner reports videos run fine on the device, which discharges D038's owed check (D052)." | D052 |
| 6 | same → `Theme.swift` | "(Its header comment still says "the 17 frames", from before D042 replaced the export.)" | "(Its header comment says "the 20 frames" of the Design2 export, D042 — corrected in pass 7, D065.)" | D065 |

The listing "Lines above this section that pass 7 made out of date" is removed from Current state.
A diff of everything above Current state, before against after, shows these six changes and no
other.

**Further lines that disagree with D052–D066 — reported, not edited:**

- **A seventh, which pass 7's own listing already held.** *Toolchain facts*, lines 121–122: patch
  0021's "text survives only as
  `reports/logs/2f-0021-es_out-no-late-pcr-compensation-while-paused.diff.txt`". That file left the
  tree in pass 7 and lives at `e7676fa` (D066). **My count was wrong in pass 7:** its report said
  "six lines" and named six, but the listing it wrote into COLD-START named seven, this one
  included. The six corrected here are the six the report named. With the listing gone, this line
  is covered only by the general statement under **Pushed** — every `reports/logs/…` path resolves
  at `e7676fa`.
- **An eighth, new.** *Build, install, run → "Building for the other Apple TV"*, lines 174–175:
  "Do that **only when the owner asks**: Home Theater is the dev/test device (D005), and the
  bedroom box is in household use". D061 now has the push pass install there without a separate
  ask. Pass 7 did not list it; I found it by searching the upper sections for wording about the
  bedroom box, open questions, videos and the removed folders.

## 3. The memory note

File: `~/.claude/projects/-Users-marlin1111-Xcode-Marlin-Media-TV/memory/bedroom-appletv-off-limits.md`
(same file, same name, so the memory index still points at it).

**Before** — description and the parts that changed:
> description: Master Bedroom ATV carries the app (D050) but is never a test device — Home Theater
> only; confirm before touching it
>
> "Master Bedroom ATV" … **has the app installed** since 2026-09-16, pass 5 / **D050**, at the
> owner's explicit request. That is the only thing that changed. It is **not** a test device: no
> build, run, matrix, log, screenshot or evidence of any kind is taken there. All device work is
> Home Theater (D005).
>
> **Why:** the bedroom box is in household use — launching there puts the app on a television
> someone may be watching. D050 is a narrow convenience install, not permission to test.
>
> **How to apply:** still **confirm before touching it**, even when a prompt names it; one
> confirmation covers that pass only. Never install there as preparation or "while we're at it".
> Do not reinstall to keep it current unless asked — it is expected to go stale, and its
> development provisioning profile will eventually expire. Nothing about playback on that slower
> A10X has ever been tested.

**After:**
> description: Master Bedroom ATV gets each accepted build from the push pass (D061, install only,
> no launch) but is never a test device — nothing else there without the owner asking
>
> "Master Bedroom ATV" … carries the app for the household (D050, pass 5). **Standing rule since
> 2026-09-19, D061 (pass 7), revising D050's "only if the owner asks":** every push pass that
> follows the owner's acceptance of a pass that changed the app also installs the accepted build
> there — **install only, no launch**. That install is also what renews its provisioning profile;
> if the app ever refuses to open there, the remedy is a reinstall.
>
> It is still **not** a test device: **D005 is unchanged**, and no run, matrix, log, screenshot or
> evidence of any kind is taken there. All device work is Home Theater. The owner reports playback
> works on the bedroom box; no pass has tested it.
>
> **Why:** the bedroom box is in household use — launching there puts the app on a television
> someone may be watching. The owner wants it kept current without it ever becoming a second test
> target.
>
> **How to apply:** the D061 install needs no separate confirmation when the pass is such a push
> pass — but it is install only: never launch, never photograph, never copy a log off it. A pass
> that did not change the app, or that is not the push following the owner's acceptance, installs
> nothing there (pass 7 and 7b installed nothing). **Anything else on that box — a launch, a build
> for it outside a push pass, an uninstall, any test — still happens only when the owner asks, and
> one ask covers that pass only.** A pass prompt that says "do not touch Master Bedroom ATV" wins
> over D061.

The History paragraph (the withdrawn run of 2026-09-14, the confirmed install of 2026-09-16) is
unchanged.

## 4. Pass history, and two lines of bookkeeping I should name

The pass 7b note is the last entry of Pass history.

**Two edits to Current state that the prompt did not name**, made because every pass before this
one has kept them current and leaving them would have made Current state wrong the moment this
pass was committed:
- its first line, "As of **pass 7 (2026-09-19)**, the newest pass …" → "As of **pass 7b
  (2026-09-19)**, the newest pass. Pass 7 was … (D052–D066); pass 7b, notebook only, recorded the
  last of them (D067).";
- one bullet added under **Pushed**: "**Pass 7b as one notebook commit on top of `f4fafa1`**,
  which is pass 7's commit (`e7676fa..f4fafa1`) — a fast-forward, no force". It is also the first
  place the notebook gives pass 7's SHA, which pass 7 could not write into its own commit.

If either should not have been touched, they are two self-contained lines to revert.

## 5. Commit and push

One commit on top of `f4fafa1`, three files staged by explicit path — `COLD-START.md`,
`DECISIONS.md`, `reports/2026-09-19-pass7b-notebook.md` — pushed to `origin main` as a
fast-forward, no force. The SHA and the three-way comparison are in the closing message.

**Pushed:** those three files. **Stays local, exactly as before:** the `PlayerHost.swift` hook, the
five harnesses, `Notes/`, `icon pixel/`, everything git-ignored — and the memory note, which lives
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
| 1 | `DECISIONS.md` (D067); `COLD-START.md` (Open items) |
| 2 | `COLD-START.md` (six lines; the listing removed) |
| 3 | the memory note, outside the repo |
| 4 | `COLD-START.md` (Pass history note; the as-of line and one Pushed bullet, §4); this report |
| 5 | none |

Scratch: a status snapshot and a before-copy of `COLD-START.md` in the session scratch folder,
deleted at the end.

## Open questions

1. **The two further stale lines** (§2): the 0021 "survives only as" line at 121–122 and the "only
   when the owner asks" paragraph at 174–175. Correct them in the next notebook pass? Suggested
   wording, each to its decision and nothing more: "…and the patch text lives in history at
   `e7676fa` (D066)"; and "The push pass that follows the owner's acceptance of a pass that changed
   the app installs there, install only, no launch (D061); anything else there, only when the owner
   asks."
2. **The memory index line.** `MEMORY.md`, the one-line index next to the note, still reads
   "Bedroom Apple TV: app yes, testing no — … still confirm before touching it". The pass allowed
   one write outside the repo, the note itself, so the index was left. The note's own description
   is current, and the note is what gets read when the bedroom box comes up; the index hook is
   half-stale until someone says to change it.
3. **The two bookkeeping edits of §4** — acceptable, or to be reverted?

## The things I am least sure of

1. **Which six.** Pass 7's report said six and its COLD-START listing held seven. I took "the six
   lines pass 7 listed" to be the six its report named, and treated the 0021 line as the seventh
   the prompt told me to report rather than edit. Read the other way, the 0021 line was one of the
   listed ones and is still uncorrected.
2. **"Nothing more."** Line 1 keeps the sentence after it ("Before pass 5 this box was off-limits
   entirely; D050 is the narrow exception and does not reopen it for testing"), which is still
   true under D061 because D005 is unchanged. Line 5 drops "this library has no videos", since the
   owner's report contradicts it, and does not claim any pass has run the video screen.
3. **That there is no ninth.** The search for further stale lines was by keyword over the sections
   above Current state, plus the read of them during pass 7; it was not a line-by-line re-read of
   all 295 lines against all sixteen decisions.
4. **The memory note's "How to apply"** goes a little past D061's text in spelling out what the
   rule does not permit (no launch, no photograph, no log copy; a prompt's "do not touch" wins).
   That is my reading of "D005 unchanged; nothing else is done there without the owner asking",
   written so that a future session cannot over-read the rule.
