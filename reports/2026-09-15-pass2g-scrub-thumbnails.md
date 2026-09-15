# Pass 2g — drop 0021, put the server's timeline stills on the scrub — 2026-09-15

**Result: done, all seven steps, verified on Home Theater.**

- **Patch 0021 is dropped.** `tools/vlckit-truehd/0021-*.diff`, its `build.sh` step 2c'' and its
  README line are gone, the app is back at HEAD's scrub, and the framework is rebuilt by the full
  recipe at **20 patches**. Both slices check: `MinimumOSVersion` 26.0, `LC_BUILD_VERSION minos 26.0
  sdk 27.0`, `_ff_truehd_decoder` on the device slice, and no instrumentation strings. Recorded as
  **D022**.
- **The scrub now carries a thumbnail.** During a paused drag the still nearest the target shows
  above the bar and changes as the target moves; where the server has no still there is nothing
  above the bar. The index is fetched **once** per detail screen and never polled or re-fetched;
  sheets are fetched as needed. Recorded in **D021 (revised again)**; the endpoints are in
  COLD-START.md.
- **On Home Theater (Stargate Extended, one session, 191.5 s, passed).** One index line and **two**
  sheet fetches (185 ms, 115 ms) served four targets across three drags. The thumbnail tracked the
  target at 03:59 → 05:32 → 08:08 → 06:50, the drag rates were exact (±0 ms against 25% of the
  running time per surface width), landing seeked to the target with **0 ms** error at +1 s, Menu
  cancel returned to the drag's start (**0 ms**) and stayed Paused, and the five frame steps back
  were retraced forward to **pixel-identical** screenshots.
- **Committed locally; nothing pushed.** The harness and its `PlayerHost` hook stay uncommitted, as
  in passes 2c–2f.

## Result per step

| Step | Result |
|---|---|
| 1 Drop 0021, rebuild at 20 patches, record it | **Done** (§1). D022 added. |
| 2 Server endpoints | **Measured live before any code was written** (§2). |
| 3 Index fetched once per detail screen, no polling, no re-fetch | **Done** (§3, §4.1). One `[thumbs] file 2` line in the whole session. |
| 4 One thumbnail above the bar, nearest the target, nothing where no still exists | **Done** (§3, §4.2). |
| 5 The rest of D021 unchanged | **Done and verified** (§4.3): picture holds, click lands and plays, Menu cancels paused, 25% per width, 1 s short of the end, frame step unchanged. |
| 6 Nocturne tokens and the overlay's spacing, nothing focusable, no other UI | **Done** (§3). |
| 7 Update D021, COLD-START endpoints | **Done.** |
| Verify on Home Theater, Stargate only, one mid-drag screenshot | **Done** (§4); 10 screenshots committed. |

## 1. Step 1 — 0021 dropped and the framework rebuilt at 20 patches

Evidence: `reports/logs/2g-framework-checks.txt`.

**Removed:** `tools/vlckit-truehd/0021-es_out-no-late-pcr-compensation-while-paused.diff`, the
`build.sh` step 2c'' that installed it, and its README paragraph — `PlayerHost.swift`,
`PlayerModel.swift`, `README.md` and `build.sh` were returned to HEAD with `git checkout`, so the
app is exactly HEAD's scrub again. **The stale copy in the build tree mattered:** the recipe resets
libvlc and re-applies `libvlc/patches/*.patch` on every run, and
`~/vlckit-build/VLCKit/libvlc/patches/0021-….patch` was still there from pass 2f; it was deleted
before the build, or the rebuild would have silently been a 21-patch one again.

**The rebuild** (`tools/vlckit-truehd/build.sh`, no `PACKAGE_ONLY`, 19:02:47–19:06:02):

- `patch 0018 installed`, `patch 0019 installed`, `patch 0020 installed` — and no 0021 line.
- **20 `Applying:` lines** (pass 2f had 21), the last being
  `input: es_out: forward next-frame data requests only from the stepped ES`.
- `ARCHIVE SUCCEEDED` ×2; `0021` appears **0** times in the recipe log.
- **libvlc:** `6d623583307c08bfef62444ea829f136236f6cd6` (0020 is the tip), working tree clean.
  `es_out.c:3661` is back to `if (p_pgrm != p_sys->p_pgrm || p_sys->p_next_frame_es != NULL)` —
  0021's `|| p_sys->b_paused` is gone — and 0020's `es_out.c:539` guard is still present.

| Slice | `MinimumOSVersion` | `LC_BUILD_VERSION` | `DTXcodeBuild` |
|---|---|---|---|
| `tvos-arm64` | 26.0 | `platform 3 (TVOS) minos 26.0 sdk 27.0` | 27A266a |
| `tvos-arm64_x86_64-simulator` | 26.0 | `platform 8 minos 26.0 sdk 27.0` (both architectures) | 27A266a |

- **Device slice `nm`:** `_ff_mlp_decoder`, `_ff_mlp_parser`, `_ff_truehd_decoder`
  (`000000000236e730`) — D012 intact.
- **Instrumentation strings** from the diagnosis passes: `1g:` 0, `1j:` 0, `2e:` 0 on both slices.
  `1h:` matches once on the device slice and twice on the simulator slice, and in every case the
  whole string run is `;/1h:` — a 5-byte run in the binaries' data, not a libvlc log format string
  (those printed `1h: …` with trailing text). The libvlc tree is clean at 0020's tip, so no
  instrumentation can be compiled in.

**Why 0021 was dropped** is written up as **D022** in DECISIONS.md, with pass 2f's numbers: the
picture tracked on Stargate only (7–8 of 8–9 seeks), 1–5 of 8–9 on the HEVC films, and VLCKit's
reported time froze after 4 of 5 Magicians landings.

## 2. Step 2 — the endpoints, measured live

Probed against `http://192.168.1.250:8093` before any code was written; written into COLD-START.md.

- **`GET /api/files/{fileId}/thumbs`** — `interval` 10, `tile_width` 320, `tile_height` **214**,
  `columns` 6, `rows` 5, `per_sheet` 30, `count` 780 (Stargate Extended), `state`, `sheets`.
- **Generation really does start on the first index request, and the index is a snapshot.** The
  first call for file 2 returned `"state": "generating"` with **`"sheets": []`**; about 40 s later
  the same call returned `"state": "complete"` with 26 sheets, each
  `{index, first_still, url}` — `url` server-relative with a `?v=` cache-buster
  (`/api/thumbs/2/0.jpg?v=1789513182`).
- **`GET /api/thumbs/{fileId}/{n}.jpg`** — `image/jpeg`, **1920 × 1070** (6 × 320 by 5 × 214),
  ~91 KB, `Cache-Control: public, max-age=86400`, `Accept-Ranges: bytes`.
- **An unknown file id** is `404 {"error":"file not found"}`.

## 3. Steps 3–6 — the app change

**New: `Marlin Media TV/ThumbStrip.swift`.** `ThumbSheet` / `ThumbIndex` decode the index (with the
project's existing `convertFromSnakeCase`), and:

- `still(nearestMs:)` = `round(ms ÷ 1000 ÷ interval)` clamped to `count − 1`;
- `place(still:)` finds the sheet `n ÷ per_sheet` **in the `sheets` array** and the tile
  `n − first_still`, row-major — a still whose sheet is not in the index yet simply has no place,
  which is how "no still exists" becomes "nothing above the bar";
- `ThumbStrip` is the per-player store: it keeps the decoded sheets, fetches one when a target needs
  it (`URLSession`, decoded off the main actor), and re-draws when a fetch lands, because the target
  may have moved on while it downloaded. Nothing is drawn while a sheet is still downloading.

**Wiring.** `APIClient.thumbs(fileId:)`; `PlayRequest` carries `thumbs: FileThumbs?` and keeps it
only when the index's `fileId` is the file being played (`PlayRequest.matching`), so a different
edition or episode plays with **no** thumbnail rather than the wrong one. The three detail screens
fetch once on open; `ContentView` now passes `library.api` to the movie and video screens too.
`PlayerModel` builds the strip in `init` and drives it from `scrubMoved`, clearing it in
`landScrub` / `cancelScrub`.

**Drawing** (`PlayerScreen.ScrubOverlay`): the tile at the server's own 320 × 214 in the frames'
1920 × 1080 space, 26 pt above the bar row — the row's own gap — inside the same 80 pt side padding,
carried over the target's place on the track with the bar row's 130 pt time columns as its margins
and stopped at either end; 8 pt corners, a `neutral700` hairline, a soft drop shadow.
`Image(decorative:)`, inside the overlay's existing `.allowsHitTesting(false)` — nothing focusable,
no other UI added.

**Two points the prompt leaves open; I chose these and flag them (open questions 1 and 4):**

- **Where it sits horizontally.** "Above the bar" doesn't say where along it, so the still is carried
  over the knob, which is what ties it to the target.
- **It stays after the lift.** The bar stays up from the lift until landing or cancel, and the
  thumbnail stays with it rather than disappearing on lift.

## 4. Verification on Home Theater (Stargate Extended only)

One session, `Diag2gUITests/tStargateThumbs`, **passed in 191.5 s**. Drags are scripted through the
model by the uncommitted Page Up / Page Down hook (XCUIRemote has no touch-surface API — passes
2a–2f). Log: `reports/logs/2g-stargate-thumbs.log.gz`, analysis `reports/logs/2g-analysis.txt`,
screenshots `reports/screenshots/2g/`.

### 4.1 The index is fetched once, and sheets only as needed

```
7:09:41.326 PM [thumbs] file 2: 780 stills every 10.0 s, 26 of 26 sheets, state complete
7:10:45.395 PM [thumbs] sheet 0 loaded 1920x1070 in 185 ms
7:10:46.885 PM [thumbs] sheet 1 loaded 1920x1070 in 115 ms
```

- **One** `[thumbs] file` line in the whole session — fetched when the detail screen opened, never
  polled and never re-fetched.
- **Two** sheet fetches served all four targets of the session (stills 18, 33, 49, 41 — sheets 0
  and 1), and **0** failed.

### 4.2 The thumbnail tracks the target

| Screenshot | Moment | Bar reads | What is above the bar |
|---|---|---|---|
| `01-paused-no-scrub` | paused, before any drag | no bar (frame 13's paused centre, 02:56) | **nothing** — there is no scrub |
| `02-drag1-mid` | mid-drag 1 | 03:59 | a night still, knob-aligned near the left |
| `03-drag1-lifted-0532` | drag 1 lifted | 05:32 | a different still (the camp), knob moved right |
| `04-drag2-lifted-0808` | drag 2 lifted | 08:08 | a different still (interior), knob further right |
| `05-drag3-back-lifted-0650` | drag 3, backwards | 06:50 | a different still (the fire), knob moved back left |
| `07-cancel-drag-mid` | mid-drag, cancel case | 08:38 | a different still again |

The picture behind the bar is the frame the drag began at in every one of them — it holds, as D021
says. The drag arithmetic is exact: `+0.08` of the width moved the target by **155 961 ms** each
time (0.08 × 25% × 7 798 056 ms) and `−0.04` by **77 980 ms**:

```
[scrub] begin at 176339 ms → lift target=332300 → lift target=488261 → lift target=410281
```

### 4.3 The rest of D021 is unchanged

- **Landing** (click): `[scrub] land select from 176339 ms at 410281 ms`, then
  `[scrub] seek 410281 ms after play` — HEAD's rule, play then one seek — and
  `land +1 s time=410281 ms (expected 410281 ms) state Playing`: **0 ms** error.
- **Menu cancel:** `cancel menu at 589290 ms, back to 433329 ms`, then `cancel +1 s` and `+3 s` both
  `time=433329 ms (expected 433329 ms) state Paused` — **0 ms**, still paused, no seek of its own.
- **Frame step** after the cancel: five left clicks walked 433 329 → 433 183 ms on the file's
  33/50 ms grid, and the five right clicks retraced them to **byte-identical screenshots**
  (SHA-1 of the 4K PNGs: R6 = L4, R7 = L3, R8 = L2, R9 = L1; L5 and R10 are the two endpoints,
  which have no partner). `p2g-stargate-09-framestep-L1.jpg` and
  `p2g-stargate-10-framestep-R9-retrace-of-L1.jpg` are that pair.
- **Skips** while playing: 32 000 → 62 000, 63 016 → 93 016, 94 024 → 124 024, 125 032 → 155 032.
- **Nothing in the log reads as a failure** (the analysis' last section is empty).

## 5. Files touched, by step; committed vs local

| Step | Files | Committed? |
|---|---|---|
| 1 | `tools/vlckit-truehd/0021-*.diff` (**deleted**), `tools/vlckit-truehd/build.sh`, `tools/vlckit-truehd/README.md` (both back to HEAD), `DECISIONS.md` (D022) | **Yes** |
| 1 | `Frameworks/VLCKit.xcframework` (20 patches), `~/vlckit-build` | Git-ignored / outside the repo |
| 2, 7 | `COLD-START.md` (endpoints + the pass 2g note) | **Yes** |
| 3–6 | `Marlin Media TV/ThumbStrip.swift` (new), `ServerAPI.swift`, `PlayRequest.swift`, `ContentView.swift`, `MovieDetailScreen.swift`, `ShowDetailScreen.swift`, `VideoDetailScreen.swift`, `PlayerModel.swift`, `PlayerScreen.swift` | **Yes** |
| 7 | `DECISIONS.md` (D021 revised again) | **Yes** |
| verify | `Marlin Media TVUITests/Diag2gUITests.swift`, the `PlayerHost.swift` Page Up/Down hook | **No** — copies committed as `reports/logs/2g-harness-Diag2gUITests.swift.txt` and `reports/logs/2g-harness-hook.diff` |
| verify | `reports/logs/2g-{framework-checks.txt,analysis.txt,stargate-thumbs.log.gz}`, `reports/screenshots/2g/` (10) | **Yes** |

- **Not touched:** 0007, 0018, 0019, 0020 (shasums `41df2136…`, `a491edd8…`, `39a73a44…`,
  `3ea7c4f2…` unchanged); `Design/`; `Marlin DVR TV`; VLCKit's private player pointer.
- **Constraints kept:** `TVOS_DEPLOYMENT_TARGET = 26.0`; Home Theater only, never the simulator,
  and the Master Bedroom Apple TV untouched; largest committed file 203 KB; no device identifier,
  container UUID or token in anything committed (checked by grep).
- **Pushed:** nothing.

## 6. Open questions

1. **"The file that would play" is a guess for multi-file screens.** One index request per screen
   means one file: a movie's **first edition**, a show's **first episode of the first season**.
   Play Stargate Theatrical, or episode 2, and there are simply no thumbnails. Fetch per selection
   instead (more than one request per screen), or fetch lazily when the player opens?
2. **The first visit to a file shows no thumbnails at all.** The first index request is what starts
   generation, and the answer to it is `generating` with `sheets: []`. The session above only
   worked because the recon in §2 had already triggered generation ~10 minutes earlier. Accept
   "second visit onwards", or re-ask when the player opens?
3. **The stills are letterboxed.** The server fits Stargate's 2.35:1 picture into a 320 × 214 tile,
   so the thumbnail carries black bands top and bottom (visible in every screenshot). Crop them in
   the client, or leave the server's tile as it is?
4. **The two design points of §3** — the still carried over the knob, and staying up after the lift
   until landing or cancel.
5. **Nothing logs which still is drawn.** The proof that it follows the target is the screenshots;
   the log shows only the index and the sheet fetches. A `[thumbs] still N` line would make future
   passes measurable without screenshots.

## 7. What I am least sure of

1. **One film, one session.** Stargate only, as the prompt asked. Wonder Woman, Divergent and
   Magicians were not run at all this pass, so nothing here says how the thumbnail behaves on an
   MP4 or on the 4K HEVC files — in particular whether sheet fetches stay this quick.
2. **The sheets were already complete and the server warm.** 185 ms and 115 ms are LAN fetches of
   an already-generated sheet. A cold or still-generating file, or a drag that crosses many sheets
   in one sweep, would show nothing above the bar for as long as each fetch takes, and that path was
   never exercised on the device — only reasoned from the code.
3. **Three drags is a small sample** for "changes as the target moves". It is unambiguous in the
   screenshots, but it is four targets, not a matrix.
4. **The `;/1h:` string.** I argue it is coincidental data because the libvlc tree is clean, rather
   than having traced the bytes to a specific constant.
5. **The gesture itself is still untested by hand.** As in passes 2c–2f, drags were scripted through
   the model; the owner's own swipe on the real remote is the outstanding check, and the push gate
   waits on it.
