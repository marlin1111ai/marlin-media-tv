# Pass 5: the Top Shelf banners, and the app on the bedroom Apple TV — done — 2026-09-16

Two things the owner asked for in one pass: fill the Top Shelf slots pass 4 left empty, from a
newer Claude Design export; and install the app on Master Bedroom ATV, reversing the standing
"the bedroom Apple TV is not used" line.

Decisions **D049** (Top Shelf) and **D050** (the bedroom install). Nothing was pushed.
**No Swift file was touched, and neither app icon stack was touched.**

## Result per step

| step | result |
|---|---|
| 1. The four topshelf files into the existing slots | done — nothing else in the catalog changed |
| 2. Build, install, launch on Home Theater | done — `BUILD SUCCEEDED`, banner photographed on screen |
| 3. Master Bedroom ATV | done — every gate cleared; built, installed, launched |
| 4. Notebook | done — COLD-START.md updated in six sections, D049 and D050 added |
| 5. Commit the listed paths, do not push | done — one commit, nothing pushed |

## 1. Step 1 — the Top Shelf images

**The source changed under us, as the prompt said it would.**
`Design/tvos icons/Marlin Media tvOS Design.zip` went from 2 461 833 to 7 254 893 bytes: the newer
export carries 14 files where pass 4's carried 10, the four new ones being the Top Shelf banners.

**First check: are the app icon layers the same?** If the export had changed them, filling the Top
Shelf would have silently dragged a new icon in with it. SHA-256 on all six against the committed
copies:

```
icon-400x240-back.png      identical to committed
icon-800x480-back.png      identical to committed
icon-400x240-front.png     identical to committed
icon-800x480-front.png     identical to committed
icon-1280x768-back.png     identical to committed
icon-1280x768-front.png    identical to committed
```

So the icon stacks were left untouched, as the prompt required.

**The four banners, as delivered:**

| imageset | scale | file | pixels | alpha channel | minimum alpha |
|---|---|---|---|---|---|
| `Top Shelf Image` | 1x | `topshelf-1920x720.png` | 1920 × 720 | present | 255 — fully opaque |
| `Top Shelf Image` | 2x | `topshelf-3840x1440.png` | 3840 × 1440 | present | 255 — fully opaque |
| `Top Shelf Image Wide` | 1x | `topshelf-wide-2320x720.png` | 2320 × 720 | present | 255 — fully opaque |
| `Top Shelf Image Wide` | 2x | `topshelf-wide-4640x1440.png` | 4640 × 1440 | present | 255 — fully opaque |

Every one is exactly the size its name claims, and every pixel of every one has alpha 255 — they
carry an alpha channel but no transparency, which is what a Top Shelf image needs. They were used
**exactly as delivered**: no crop, no scale, no recolour.

**What changed in the catalog:** the two Top Shelf `Contents.json` files gained their filenames,
and the four PNGs were added beside them. `git status` over the catalog shows those six paths and
nothing else — both image stacks, the brandassets `Contents.json` and the catalog `Contents.json`
are untouched.

## 2. Step 2 — Home Theater

```
** BUILD SUCCEEDED **
```

Two warnings, both pre-existing and unrelated: a `NS_SWIFT_NAME` note from VLCKit's own
`VLCMediaPlayer.h`, and `appintentsmetadataprocessor` saying there is no AppIntents dependency.
Neither is from this change.

**The compiled catalog.** `Assets.car` grew from 575 208 to 2 335 208 bytes, and `assetutil` lists:

| name | type | idiom | scale | pixels |
|---|---|---|---|---|
| `Top Shelf Image` | Image | tv | 1 | 1920 × 720 |
| `Top Shelf Image` | Image | tv | 2 | 3840 × 1440 |
| `Top Shelf Image Wide` | Image | tv | 1 | 2320 × 720 |
| `Top Shelf Image Wide` | Image | tv | 2 | 4640 × 1440 |

with `App Icon`, `App Icon/Back/Content` and `App Icon/Front/Content` unchanged beside them.

**Install and launch** (identifier redacted):

```
App installed:
• bundleID: com.marlin1111.marlin-media-tv
• installationURL: file:///private/var/containers/Bundle/Application/EFDDA7BA-.../Marlin%20Media%20TV.app/

Launched application with com.marlin1111.marlin-media-tv bundle identifier.
[library] loaded 3 movies, 2 shows, 0 videos from http://192.168.1.250:8093
12:55:19.338 AM [continue] 0 entries: 
12:55:19.351 AM [log] started 2026-09-16 04:55:19 +0000 VLCKit 4.0.0-dev Otto Chriek
12:55:19.405 AM [home] 2 of 2 shows detailed for the TV row
```

**The banner was photographed on screen.** After the launch ended the device sat on tvOS's Home
screen with Marlin Media as the focused tile of the top row — which is exactly the state that draws
the Top Shelf image — so `reports/screenshots/p5/p5-1-home-theater-topshelf.png` catches the banner
in place above the row. That was luck of timing rather than steering: nothing here can press the
remote.

## 3. Step 3 — Master Bedroom ATV

**The gate.** `xcrun devicectl list devices` (identifiers redacted):

```
Master Bedroom ATV   <REDACTED> (UDID)   available (paired)   Apple TV 4K (AppleTV6,2)   physical
```

and `devicectl device info details`:

| fact | value |
|---|---|
| Device Name | `Master Bedroom ATV` |
| Marketing Name | Apple TV 4K |
| Product Type | `AppleTV6,2` — **1st generation** (Home Theater is `AppleTV14,1`) |
| CPU | arm64 (Home Theater is arm64e) |
| OS Version | **26.6** |
| Developer Mode | **Enabled (1)** |
| Pairing / state | paired, connected, localNetwork |

Present, paired, available, Developer Mode on, and tvOS 26.6 against the app's 26.0 minimum (D004).
Every gate cleared, so the pass proceeded rather than stopping.

**Build, install, launch** (identifier redacted):

```
xcodebuild ... -destination 'platform=tvOS,name=Master Bedroom ATV' ... -allowProvisioningUpdates
** BUILD SUCCEEDED **        (no errors)

App installed:
• bundleID: com.marlin1111.marlin-media-tv
• installationURL: file:///private/var/containers/Bundle/Application/44BE9979-.../Marlin%20Media%20TV.app/

Launched application with com.marlin1111.marlin-media-tv bundle identifier.
[library] loaded 3 movies, 2 shows, 0 videos from http://192.168.1.250:8093
12:57:45.890 AM [continue] 0 entries: 
12:57:45.897 AM [log] started 2026-09-16 04:57:45 +0000 VLCKit 4.0.0-dev Otto Chriek
12:57:45.943 AM [home] 2 of 2 shows detailed for the TV row
```

The first `[library]` line is identical to Home Theater's. `p5-2-bedroom-app-running.png` shows Home
drawn correctly on that box: MOVIES · 3 with the three posters, TV SHOWS · 2 with episode cards, the
clock at the top right, and no Continue Watching row — D047's reset, as expected.

**The Top Shelf banner could not be photographed there.** A newly installed tvOS app lands at the
end of the app grid rather than the top row, and the banner only draws for the focused top-row app.
Moving focus needs a remote press, which neither `devicectl` nor `XCUIRemote` can send from outside
the app. `p5-3-bedroom-home-screen.png` is that device's Home screen, with a different app focused
and its banner showing — included as the evidence of why, not as evidence of our banner.

**Nothing else on either device was changed.** No settings, no other app, no server write.

## 4. Files touched, by step

| step | path | what |
|---|---|---|
| 1 | `…/AppIcon.brandassets/Top Shelf Image.imageset/Contents.json` | filenames added |
| 1 | `…/AppIcon.brandassets/Top Shelf Image.imageset/topshelf-1920x720.png` | new |
| 1 | `…/AppIcon.brandassets/Top Shelf Image.imageset/topshelf-3840x1440.png` | new |
| 1 | `…/AppIcon.brandassets/Top Shelf Image Wide.imageset/Contents.json` | filenames added |
| 1 | `…/AppIcon.brandassets/Top Shelf Image Wide.imageset/topshelf-wide-2320x720.png` | new |
| 1 | `…/AppIcon.brandassets/Top Shelf Image Wide.imageset/topshelf-wide-4640x1440.png` | new |
| 4 | `COLD-START.md` | six sections updated, plus the pass 5 note |
| 4 | `DECISIONS.md` | D049, D050 |
| 5 | `Design/tvos icons/Marlin Media tvOS Design.zip` | the owner's replacement, committed |
| 5 | `reports/2026-09-16-pass5-topshelf-and-bedroom.md` | this report |
| 5 | `reports/screenshots/p5/*.png` | 3 device screenshots |

Not touched: every Swift file, both app icon image stacks, `Frameworks/`, `tools/`,
`Design/Marlin Media tvOS Design.zip` and the rest of `Design/`, `icon pixel/`, `Notes/`, the
`PlayerHost.swift` hook and the five harnesses.

## 5. Open questions

1. **Which Top Shelf imageset did tvOS actually draw?** Both pairs are in the catalog and the
   screenshot proves *a* banner is drawn, but nothing identifies which one fed it. The 1920 and 2320
   crops differ, so it matters to whoever tunes the artwork.
2. **The bedroom install will go stale and nothing watches it.** No later pass reinstalls there
   unless asked. Reinstall on request, on some schedule, or let it rot?
3. **Its provisioning profile will expire.** A development-signed build stops launching when the
   profile lapses, with no warning beyond the app refusing to open.
4. **Nothing is known about the app on `AppleTV6,2`.** It launched and drew Home; no playback, seek,
   frame step, scrub, display-matching or TrueHD path has run on that slower A10X. D005 keeps
   Home Theater as the only test device, so this is untested, not known-good.
5. **`icon pixel/` and `Notes/` are still untracked** and belong to no pass.

## 6. What I am least sure of

1. **The Home Theater banner shot was luck, not method.** The device happened to be sitting with our
   app focused on the top row when the screenshot was taken. I could not have steered it there, and
   I cannot reproduce it on demand — so "the banner draws" rests on one frame.
2. **How the banner is cropped on a real screen is unjudged.** tvOS scales and masks the Top Shelf
   area, and the screenshot is one 16:9 frame at one moment. Whether the marlin and the wordmark sit
   where the owner wants them, at the size the TV actually shows, is the owner's to see.
3. **The bedroom device was verified by its own report of itself.** `Developer Mode Status: Enabled`
   and `OS Version: 26.6` come from `devicectl`, not from anything I observed on the television.
4. **"Nothing else on either device changed" is a claim about what I ran,** not an audit. I issued
   only install, launch, screenshot and info commands, but I did not diff device state before and
   after.
