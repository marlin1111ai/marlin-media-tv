# Pass 4: the tvOS app icon — done — 2026-09-16

The app had no asset catalog and so no app icon; the tvOS Home screen drew the generic tile
(pass 1's open question 11). This pass puts the owner's Claude Design icon export into a layered
tvOS app icon, builds it, installs it, launches it and photographs it on Home Theater.

Decision: **D048**. Nothing was pushed. **No Swift file was touched.**

## Result per step

| step | result |
|---|---|
| 1. Use only the six layer files | done — the three `-back` / `-front` pairs; `-flat` and `preview-b.png` ignored |
| 2. Two-layer stacks, no Middle slot, target points at it | done — catalog created, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` added |
| 3. Build, install, launch on Home Theater | done — `BUILD SUCCEEDED`, no warnings; installed; launched; photographed |
| 4. Notebook | done — COLD-START.md updated in six sections, D048 added |
| 5. Commit the listed paths, do not push | done — one commit, nothing pushed |

## 1. Step 1 — the source

`Design/tvos icons/Marlin Media tvOS Design.zip` (2 461 833 bytes), unzipped to a scratch folder
outside the repo. Its `icons/` folder holds ten PNGs. The six used, with the sizes read back by
`sips`:

| file | pixels | alpha |
|---|---|---|
| `icon-400x240-back.png` | 400 × 240 | yes |
| `icon-400x240-front.png` | 400 × 240 | yes |
| `icon-800x480-back.png` | 800 × 480 | yes |
| `icon-800x480-front.png` | 800 × 480 | yes |
| `icon-1280x768-back.png` | 1280 × 768 | yes |
| `icon-1280x768-front.png` | 1280 × 768 | yes |

Every one is exactly the size its name claims. The four `icon-*-flat.png` files and `preview-b.png`
were **not** used: they are flattened composites, and a flattened tvOS icon cannot do the focus
parallax. The zip was never unzipped into `Design/`, and nothing else in `Design/` was touched.

## 2. Step 2 — the catalog

`Marlin Media TV/Assets.xcassets` is new — the project had no asset catalog at all. Its only
content is the icon:

```
Marlin Media TV/Assets.xcassets/
  Contents.json
  AppIcon.brandassets/
    Contents.json
    App Icon.imagestack/                      400x240, idiom tv
      Contents.json                             layers: Front, Back      <- no Middle
      Front.imagestacklayer/Content.imageset/   1x icon-400x240-front.png   400x240
                                               2x icon-800x480-front.png   800x480
      Back.imagestacklayer/Content.imageset/    1x icon-400x240-back.png    400x240
                                               2x icon-800x480-back.png    800x480
    App Icon - App Store.imagestack/          1280x768, idiom tv-marketing
      Contents.json                             layers: Front, Back      <- no Middle
      Front.imagestacklayer/Content.imageset/   1x icon-1280x768-front.png  1280x768
      Back.imagestacklayer/Content.imageset/    1x icon-1280x768-back.png   1280x768
    Top Shelf Image.imageset/Contents.json      2 slots, no file           <- left as they are
    Top Shelf Image Wide.imageset/Contents.json 2 slots, no file           <- left as they are
```

**The Middle slot.** Xcode's tvOS template gives each image stack three layers. The prompt said to
remove that slot rather than leave it empty or fill it, so neither stack has a `Middle.imagestacklayer`
folder and neither `Contents.json` names one. `find … -iname '*Middle*'` returns nothing and
`grep -rl Middle` over the catalog returns nothing.

**Top Shelf.** Both imagesets are declared with their standard 1x/2x slots and no filenames — the
shape Xcode's template creates before anyone drops artwork in. The build did not need them.

**Wiring it to the target.** `Marlin Media TV/` is a `PBXFileSystemSynchronizedRootGroup`
(objectVersion 71), so the catalog joined the app target by being in that folder; no file reference
was added. The only project edit was the app-icon setting, on the app target's two configurations:

```
 		BB00000000000000000000B7 /* Debug */ = {
 			buildSettings = {
+				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
 				CODE_SIGN_STYLE = Automatic;
 		BB00000000000000000000B8 /* Release */ = {
 			buildSettings = {
+				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
 				CODE_SIGN_STYLE = Automatic;
```

Two inserted lines, `1 file changed, 2 insertions(+)`. The UI-test target's configurations were not
touched.

The brandassets is named `AppIcon.brandassets` rather than Xcode's default
"App Icon & Top Shelf Image.brandassets", matching the sibling project `Marlin DVR TV`, which is
the shipping tvOS app on the same device and team.

## 3. Step 3 — build, install, launch, photograph

**Build.** The COLD-START command, unchanged:

```
** BUILD SUCCEEDED **
```

No warnings, no errors. `actool` ran with `--app-icon AppIcon` and compiled a 575 208-byte
`Assets.car` into the app.

**What the built app carries.**

- `Info.plist` → `CFBundleIcons` → `CFBundlePrimaryIcon` = `App Icon`.
- `xcrun assetutil --info … /Assets.car`:

| name | type | idiom / scale |
|---|---|---|
| `App Icon` | ImageStack | universal |
| `App Icon/Back/Content` | Image | tv 1, tv 2 |
| `App Icon/Front/Content` | Image | tv 1, tv 2 |

The App Store stack is absent from the device build, which is correct — `tv-marketing` assets are
stripped by thinning (`--filter-for-thinning-device-configuration AppleTV14,1`).

**Install.**

```
App installed:
• bundleID: com.marlin1111.marlin-media-tv
• installationURL: file:///private/var/containers/Bundle/Application/5049427F-.../Marlin%20Media%20TV.app/
```

**Launch.**

```
Launched application with com.marlin1111.marlin-media-tv bundle identifier.
[library] loaded 3 movies, 2 shows, 0 videos from http://192.168.1.250:8093
12:27:27.356 AM [continue] 0 entries: 
12:27:27.360 AM [log] started 2026-09-16 04:27:27 +0000 VLCKit 4.0.0-dev Otto Chriek
12:27:27.375 AM [home] 2 of 2 shows detailed for the TV row
```

The app behaves exactly as pass 3b left it — `[continue] 0 entries` is D047's reset still standing,
so Home opens with no Continue Watching row, as recorded.

**Photograph.** `xcrun devicectl device capture screenshot` takes a 3840 × 2160 PNG of whatever the
device is showing, tvOS's own Home screen included. The app had exited to the Home screen, so the
shot catches the icon in place:

- `reports/screenshots/p4/p4-1-appletv-home-screen.png` — the Home screen, the app's icon first in
  the top row, showing the marlin / clapperboard / film-strip artwork on its light card where the
  generic tile used to be.
- `reports/screenshots/p4/p4-2-icon-closeup.png` — that icon cropped at native resolution.

Both are committed. The original 3840 × 2160 frame is 22 MB, three to four times the size of any
screenshot committed by an earlier pass, so the Home-screen shot is committed at 1920 × 1080 (1.9 MB)
and the close-up at its native 720 × 400 (652 KB); the full-resolution original stayed in the
scratch folder. Say so if you want the 22 MB frame in the repo instead.

The app was relaunched afterwards, so Home Theater is left running this build.

## 4. Files touched, by step

| step | path | what |
|---|---|---|
| 2 | `Marlin Media TV/Assets.xcassets/**` | new — 14 `Contents.json` and the 6 layer PNGs |
| 2 | `Marlin Media TV.xcodeproj/project.pbxproj` | 2 inserted lines (the app-icon setting) |
| 4 | `COLD-START.md` | six sections updated, plus the pass 4 note |
| 4 | `DECISIONS.md` | D048 |
| 5 | `Design/tvos icons/Marlin Media tvOS Design.zip` | newly tracked (the icon's source) |
| 5 | `reports/2026-09-16-pass4-app-icon.md` | this report |
| 5 | `reports/screenshots/p4/*.png` | 2 device screenshots |

Not touched: every Swift file, `Frameworks/`, `tools/`, `Design/Marlin Media tvOS Design.zip` and
the rest of `Design/`, `icon pixel/`, `Notes/`, the uncommitted `PlayerHost.swift` hook and the five
uncommitted harnesses.

## 5. Open questions

1. **The Top Shelf images are empty slots.** tvOS draws its default top shelf when this app is the
   focused one in the top row. The export carries no top-shelf artwork. Ask Claude Design for
   1920 × 720 and 2320 × 720 (with their @2x), or leave it?
2. **The App Store icon has never been rendered anywhere.** It is built, but `tv-marketing` assets
   are stripped from device builds, so it first appears on an App Store Connect upload — which this
   project has never done.
3. **The focused icon's parallax was not photographed.** A tvOS icon separates its layers only while
   focused. Reaching that state needs a Home-button press on the remote; `devicectl` cannot send
   remote presses and `XCUIRemote` only works inside the app under test. The two layers are proven
   in the catalog and in `Assets.car`, not by a picture of the effect.
4. **`icon pixel/Marlin Media.pxd` and `Notes/` are still untracked** and belong to no pass. The
   `.pxd` looks like the icon's editable source; should it be tracked next to the zip, or stay out?
5. **The brandassets is named `AppIcon`,** after `Marlin DVR TV`, not Xcode's default
   "App Icon & Top Shelf Image". Cosmetic, but it is what the build setting points at.

## 6. What I am least sure of

1. **The icon was seen unfocused only.** The Home-screen photograph shows the flattened stack at
   rest. How the parallax reads when a hand moves onto it — how far the marlin lifts off the card,
   whether the wordmark holds together — is the owner's to judge on the television.
2. **Layer order is asserted from the file names,** `-front` over `-back`. It looks right in the
   photograph (artwork and wordmark over a light card), but nothing in the export states the order,
   and a two-layer stack looks plausible either way at rest.
3. **Only the 1x/2x Home screen pair was exercised.** The 1280 × 768 App Store pair is wired by the
   same rule and never rendered.
4. **The screenshot is one frame from one moment.** tvOS was showing the Home screen with the
   sibling app focused; the icon under test was unfocused and second-hand-sized at 1920 × 1080.
   The close-up is a crop of that same frame, not a separate capture.
