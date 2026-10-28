# METRX for Android (Kotlin + Jetpack Compose)

The native Android app. The HTML prototype in `design/prototype/` stays the reference for every screen;
the founder's decisions for this build are listed at the end.

## Build and run

Needs the Android SDK (compile SDK 37) and the JDK that comes with Android Studio.

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
./gradlew :app:assembleDebug      # app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:assembleRelease    # signed, shrunk: app/build/outputs/apk/release/app-release.apk
./gradlew :app:bundleRelease      # Google Play upload: app/build/outputs/bundle/release/app-release.aab
./gradlew :app:installQa          # the release build (R8) as uz.metrx.app.qa, debug-signed, next to the debug app
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Google Play 1.0.0 (versionCode 10, 28 Oct 2026) follows the App Store v1 rules: no sign-in buttons (`AuthFlags.accounts`),
name and phone optional, every laser button opens the radar when no ZB-08 is connected (the simulator only in a debug
build with test mode on), test mode by 7 taps on Profile's version line (the "Lazer sinovi" page), no Pro card or
subscription page, a privacy-policy row in Profile. Keep R8's `mapping.txt` of each Play build for its crash reports.

The release key is not in the repo. `app/build.gradle.kts` reads `D:/WORKDESK/TOKENS/metrx-keystore.properties`
(or the file named by the `METRX_KEYSTORE` variable). Without it, release builds come out unsigned.
Back up `metrx-release.jks` and its properties file together: the same key is needed for every future update.

Versions: AGP 9.4.1, Gradle 9.6.0, Kotlin 2.3.20 (Compose compiler), Compose BOM 2026.09.00, Haze 1.7.3 (glass blur),
SceneView 4.48.0 (Filament 1.72.1) for 3D. Java 21 bytecode (SceneView's math library needs it).
Package `uz.metrx.app`, Android 8.0 (API 26) and newer, portrait.

## Where things are

| Path | What |
|---|---|
| `core/Strings.kt` | four languages; `assets/strings.json` is extracted from the prototype by `tools/extractD.js` (key → uz, uz-Cyrl, ru, en) |
| `core/Settings.kt` | language, first run, builder name and phone, visit counter, simulated laser state; phone and number formats |
| `ui/theme/Theme.kt` | glass and sign-in colours, Plus Jakarta Sans (Latin), Manrope (Cyrillic and sign-in), IBM Plex Mono |
| `ui/glass/Glass.kt` | aurora background, frosted cards, real blur (Android 12+) with a frosted tint below |
| `ui/icons/` | the prototype's 61 icons, converted by `tools/icons2kt.py` |
| `ui/splash/` | the "Room hops" opening animation, option B "Line + read hold" (3.4 s), redrawn from the founder's artifact |
| `ui/auth/` | welcome, sign up, log in, continue without an account |
| `ui/main/` | tab bar, Home, empty Projects, Profile (part 1), language and laser sheets |
| `data/` | the project model (same shape as the prototype), SQLite store, names and counts |
| `ui/App.kt` | one back stack per tab, the open sheet, toasts with Undo |
| `ui/projects/` | Projects list, new and edit project, project page, workspace, note, their sheets |
| `geo/` | room geometry, typed-value rules, the polygon solver and sketch processing (unit-tested: `app/src/test`) |
| `ui/editor/` | room editor: plans (rectangle and drawn), step card and list, wall view, sketch pad, sheets, undo; the room's 3D page |
| `geo/Shell3D.kt` | the 3D shell: wall pieces, doors and windows, drawn rooms, rows of rooms, camera limits, the prototype's lighting (unit-tested) |
| `ui/three/` | the 3D picture on SceneView: camera and fingers, cut-away walls, labels, the report screenshot |
| `ui/projects/ProjectViews.kt` | the Workspaces tab as plans side by side (2D) and in 3D |
| `data/ViewFiles.kt` | 3D pictures added to the report, as JPEG files in the app's storage |
| `core/Money.kt` | the estimate's numbers: typed values, line totals, totals, display (exact whole numbers, unit-tested) |
| `ui/projects/Estimate.kt` | the Smeta tab, its total, the row sheet and the areas sheet |
| `report/` | the report: snapshot and fingerprint, the A4 pages (drawn once for the preview and the PDF), PDF writing and sharing, freezing a quote |
| `ui/report/` | the report and quote pages, the zoom viewer, the set-up and issue sheets |
| `ui/measure/` | the Measure page: meter, single and continuous readings, five calculators, readings, sending one to a room |
| `core/Calc.kt` | the brick tool's count and mortar (unit-tested) |
| `ui/markup/` | free drawings and photos with marks (one renderer for the editor, cards, Measure pictures and the PDF), the live camera (CameraX), the photo pickers |
| `data/PhotoFiles.kt` | photos as JPEG files in the app's storage (upright, at most 1280 px) |
| `ui/main/ProfileScreens.kt` | Profile, more settings, subscription and their sheets |

To refresh the texts after the prototype changes:
`node tools/extractD.js ../design/prototype/prototype.html app/src/main/assets/strings.json`

## Status: part 1 of 7 (14 October 2026)

Built: opening animation, welcome, sign-up and log-in screens (their buttons say accounts are coming soon),
continue without an account, three-tab bar, Home, empty Projects, part of Profile, app language, the laser sheet
with the labelled simulator, toasts, launcher icon, signed release build.

Checked on the emulator (Pixel-type, 1080 × 2400, Android 16):
- the animation plays and docks into the next screen's logo; a tap skips it;
- welcome, sign up, log in and the no-account form match the prototype; fields use the phone's own keyboard;
  the phone field keeps 9 digits and shows them as 90 123 45 67; buttons stay disabled until the form is valid;
- name and phone are kept after the app is closed; the greeting line changes on every start;
- the laser button turns green after connecting the simulator, which the sheet labels as a simulation;
- Uzbek Latin, Uzbek Cyrillic, Russian and English on Home, Projects, Profile and the welcome screen: no clipped text;
- Back closes the menu, sheets and steps first; Back on the first screen leaves the app;
- the signed release build (1.75 MB) runs the same path without crashes.

Not checked yet: a real phone; Android 8–11 (the frosted fallback instead of blur); large font sizes; TalkBack.

Known differences from the prototype:
- Plus Jakarta Sans has no Cyrillic letters, so Russian and Uzbek Cyrillic screens use Manrope throughout
  (the prototype mixes the two letter by letter). Manrope also lacks қ ғ ҳ, which come from the phone's font.
- Dark mode (Profile switch) arrived in part 7.

## Status: part 2 of 7 (14 October 2026)

Built: projects stored on the phone (SQLite, one JSON document per project, saved 250 ms after a change and at once
when the app goes to the background); Projects list with search and Active / Done / All chips; new project and
edit project (name, customer, phone, address, real GPS location, currency); project page with the three numbers
and four tabs (Workspaces and Details work, Estimate and Quotes show which part adds them); call and map buttons;
delete a project with Undo; workspaces: create with a type, rename, change type, delete with Undo; the workspace
page with its empty state, cards and the dashed add tile; the add sheet (Chizma → room plan or free drawing,
Surat → camera or gallery, Eslatma); notes with title, text, checklist and the report switch; item menu
(rename, move to another workspace, duplicate, report, delete with Undo).

Checked on the emulator: the whole path above in Uzbek Latin; the project page, workspace and lists in Russian
(no clipped text; a suggested workspace name follows the language, "Hammom" → "Ванная"); the signed release build
keeps projects, workspaces and notes after a force-close, including text typed just before pressing Home.

Not checked yet: GPS on a real phone (the emulator has no fix), Android 8–11, TalkBack, many projects.

## Status: part 3 of 7 (14 October 2026)

Built: new room (rectangle, L-shape, free sketch); the room editor with the plan, the step card (laser reading →
confirm / again, measure again, typed values with the prototype's rules), the full list (measurements, wall areas,
doors and windows), Plan / Walls / Openings tools, undo and redo (40 steps, per room), the first-time tip; doors and
windows (sheet with wall picker, drawing, checks: past the wall, too tall, overlap, wall not measured); dragging a door
or window along its wall in the plan; room info (areas, volume, rename, rotate, delete with Undo); the wall view
(elevation to scale, pager and swipe, chain dimensions, stats, drag doors along and windows up and down with the
prototype's snapping, approximate marks, guides); drawn rooms: the sketch pad (one stroke or corner taps, 45° snap,
cleaning, crossing check), the polygon plan with computed walls, Shape mode (move corners with snapping), diagonals;
room cards with small plans on the workspace page, workspace and project totals, thumbnails in the lists.

Checked: unit tests (11) including the BUILD_PLAN fixture (5 × 4 × 3 m, door and window: net walls 50,31 m²; at 6 m:
56,31 m²) and an L-shape solved from four walls; on the emulator: the whole rectangle path, a door drag with Undo,
the wall view, an L-shape (E and F computed, 25,50 m²), a hand-drawn six-wall room, a diagonal; the release build keeps
a room after a force-close.

Simplified compared with the prototype: the sketch pad has no magnifier; the polygon plan puts one dimension per wall
(nudged outward when two would overlap) instead of the prototype's stacked chains; moving a corner shows guides but not
the angle arc. The readings tray opens empty until the Measure tab exists (part 7); 3D buttons say part 4.

## Status: part 4 of 7 (14 October 2026)

Built: the room's 3D page (Plan | 3D on the room page, wall letters, From above / From the corner, wall and floor colours,
"Add to report" on the picture with the views listed under it, at most 4, × to take one out); the project's 2D view (every
workspace's rooms at one scale, tap opens the room) and 3D view (one workspace at a time, rooms in rows, a room's name zooms
to it, "All" goes back). One finger turns the view, two fingers move it and pinch zooms, inside the prototype's limits;
walls facing the camera become see-through. Doors and windows are modelled as in the prototype (frames, leaf, handle,
two-pane window, sill); drawn rooms are extruded along their solved shape with glass in the windows.

How it matches the prototype: the shell is a port of build3D / opModel3D / the sketch and ux modules; the colours are
worked out the way three.js lights the prototype's Lambert walls and handed to Filament as flat colours with its
post-processing off, so walls, floor and background come out within 1–2 steps of the prototype's pixels; the camera's
start distance and limits use the same formulas (checked: the wall letters land on the same pixels for the same picture size).

Checked: 17 unit tests (6 new: wall pieces around the fixture's door and window, sizes and labels, the start distance,
the lighting against a prototype pixel, an L-shaped room's floor of 16 m², rooms in rows without overlap); on the emulator:
both 3D views, turning, zooming to a room and back, presets, colours, adding and removing report pictures (the file goes too),
an L-shaped room, Russian; 20 openings and closings of the 3D screens in a row; the signed release build (12.2 MB) from first
start to a measured room in 3D and a report picture.

Emulator note: with the 3D drawn into a TextureView, the emulator itself crashed (in the PC's NVIDIA OpenGL driver) after a
few openings; with a SurfaceView it did not. The app uses a SurfaceView and one Filament engine for its whole life. Because a
SurfaceView is not clipped to rounded corners, the project's 3D card paints its corners with the background behind them.

Differences: in the prototype the floor grid shows faintly through the floor (a depth-precision effect of the browser); here
only at a distance. The room's camera is not reset when a colour changes (the prototype resets the zoom). The 3D card on the
project page cannot be scrolled by a finger that starts on it (the same in the prototype).

## Status: part 5 of 7 (15 October 2026)

Built: the Smeta tab as in the prototype's glass design (stages 4–6): three tiles (net walls and floor, which open the
areas by room, and the currency); materials and labour cards with each row's quantity × price and sum, rows missing a
number marked in amber; an empty state with Material / Labour and quick adds; the total over the tab bar (grand total,
materials and labour, "View report" — part 6). The row sheet: Material | Labour for a new row, name with suggestions,
unit chips, quantity and price with their units, "take from the rooms" (net walls or floor area) and +10 % spare for m²,
the line total worked out while typing, the prototype's number rules and messages, "Add another", delete. A row left
unsaved is kept as a draft (also when the app goes to the background), marked on its add button and brought back with
"Clear". The first saved row moves the project from Measuring to Estimate; the project header shows the estimate in
millions. Sheets now stay above the keyboard and scroll when long (all sheets).

Checked: 21 unit tests (4 new: the BUILD_PLAN total 4 240 000 so'm, the typing rules, half-up rounding, display); on the
emulator: quick add with the wall area and +10 % (150,06 m² → 165,066 m² × 120 000 = 19 807 920), labour, wrong price
("Butun son kiriting"), draft kept, restored and cleared, edit and delete, the areas sheet, Russian; the signed release
build (12.2 MB) from first start to the BUILD_PLAN estimate, kept after a force-close.

Same as the prototype on purpose: deleting a row has no Undo; row names stay as typed when the language changes.
The "same as / changed since quote №" banner arrives with quotes in part 6.

## Status: part 6 of 7 (15 October 2026)

Built: the report page (prototype "read it first"): the A4 pages across the screen, swipe or arrows between them, tap
to zoom (all pages, + for full size); a dark strip with the total, page count and language; notices for a missing
builder (with a sheet to add name and phone) and unconfirmed measurements. "Sozlash": report language, rooms, notes,
3D views and the report's note. "Qoralamani ulashish" makes the PDF with its DRAFT mark and opens the phone's share
sheet. "Taklifni chiqarish" (blocked while estimate rows lack numbers, and asking for the builder first if needed)
freezes quote №n: the pages, total, language and parties, with copies of its 3D pictures; the Quotes tab lists them
(newest first, whether the draft still matches), each opens in the same viewer with a lock banner and can be shared.
The Smeta tab says whether the draft is the same as the last quote or has changed since.

The pages follow the prototype's reportPages and .a4 styles (header with the mark, parties table, each room's plan
beside its measurements, notes page, 3D views, materials and labour tables, grand total with the double rule,
footnotes, signatures, page numbers, the diagonal DRAFT mark). They are drawn once with Compose drawing commands, as a
picture for the preview and as a vector PDF (595 × 842 pt, fonts embedded, text selectable). Where the prototype would
cut content off at the bottom of a page, it continues on the next page (a table repeats its heading row).

Checked: 26 unit tests (5 new: what changes the fingerprint and what does not, the quote total, the file name); on the
emulator: a four-room project with an L-shaped room, a note and an estimate gives 5 pages like the prototype's; the PDF
pulled from the phone is valid (5 pages, fonts embedded, the text reads back); language and room choices redraw the
pages; issuing, the stage offer, the frozen quote staying at its total after the estimate changed, the "changed since"
notice; the zoom viewer; a 3D picture on the estimate page; the signed release build (12.3 MB) from first start to a
shared draft and an issued quote that reopens after a force-close.

Differences: the glass app has no Board tab, so after issuing the toast asks "Bosqich: Taklif berildi?" with "Ko‘chirish";
"add the builder" is a sheet instead of a page; sharing uses the phone's own share sheet. Drawings and photos join the
report in part 7. The PDF parts switches (plan, measurements, views, estimate, signatures) are wired in and all on until
Profile gets them in part 7.

## Status: part 7 of 7 (15 October 2026)

Built:
- Profile: name card, METRX Pro card (everything unlocked), app and report language, PDF parts, currency, dark mode,
  door and window defaults (new openings start from them), angle snapping, units (m or cm), room label on plans, hints
  back, about, more settings, the subscription page.
- Measure page (Home's "O‘lchash", or "Kalkulyator" opening it at the calculators): the meter with the laser's state,
  single or continuous measuring with the simulated laser, five calculators (area, net wall less an opening, volume,
  sum, bricks with mortar and its own brick/joint/spare sheet), readings as chips and a list, typing one, sending one to
  any room's wall or height (it waits there for confirmation), deleting one. The room editor's readings tray lists them,
  assigns them to walls, counts the unused ones on its badge, and has the laser button when connected.
- Drawings and photos in workspaces: free drawing (pen, line with length, text, eraser), photo from the phone's camera app
  or gallery (dimension, arrow, text, pen, eraser), three colours, thin/thick pen, undo/redo, caption; tapping a length or
  a text opens it; lengths from the laser or typed. Card thumbnails; duplicate, move, rename, delete as for notes.
- The live camera: draw a line on the live view, take its length from the laser or type it, save the frame; pictures
  live under "Suratlar" on the Measure page, open in the photo editor, can be shared as one JPEG or moved into a
  workspace. Refused camera access shows its own screen with "Surat olish".
- Report: drawings and photos chosen for the report get pages of their own, two a page, with name, workspace and
  caption, and the photo footnote; issued quotes keep copies of their photos.
- Dark mode (no dark design exists yet; ours, from the "Tun" glass option): near-black aurora, smoky glass, light text,
  a lifted blue; room plans in the editor turn light-on-dark; paper things stay white (room plan cards, drawings, the
  report pages, the PDF). Status bar icons follow.

Checked: 34 unit tests (8 new: bricks, marks' fit and hit areas, eraser reach, which items reach the report); on the
emulator: every item above in light, the main screens again in dark and back in light; the camera app photo path after
the permission prompt; the live camera with the emulator's camera; refused permission; the report preview with a
drawing and a photo page; the signed release build (12.9 MB) from a fresh install through readings, the live camera,
saving and a force-close (pictures and readings kept, no crashes).

Not checked yet: a real phone and its camera; picking from a gallery with real photos (the emulator's is empty);
Android 8–11; the 3D scene keeps its light background in dark mode (only the page around it is dark).

Differences: Home stays the glass prototype's (greeting, one big card, two small ones) — the older Home's "continue"
and "needs attention" blocks are not in the glass design. Taking a photo uses the phone's camera app rather than a
camera inside the app; the app asks for camera access first because Android requires it once the app itself uses the
camera.

## Founder's decisions for this build

Kotlin + Compose (iPhone later in Swift); name METRX; every prototype screen; look identical to the glass prototype;
native 3D (SceneView); Android 8.0+; laser simulated and labelled until a device is chosen; sign-in screens without
a server; Pro card shown with everything unlocked; light theme with a dark switch; "Room hops" B (Line + read hold) on every cold start, tap to skip;
no crash reporting; APK files first; new package, no data moved from the old test app.
