# METRX screenshots for the redesign

114 screenshots of the current app, taken on 13 October 2026 from the Android emulator (1080 × 2400 px, real device frame with status bar). The interface language is Uzbek Latin. Files are numbered in the order a builder meets the screens.

For the product rules, scope and design tokens that go with these, see `../REDESIGN_CONTEXT.md`.

## If the tool takes only a few images, start with these

| File | Why |
| --- | --- |
| `024-home.png` | Home with real data |
| `026-projects.png` | Project cards |
| `027-project-workspaces.png` | Project page and its tabs |
| `039-workspace.png` | Workspace with rooms, a photo and a note |
| `050-room-editor-reading-received.png` | The key screen: a laser reading waiting for confirmation |
| `055-room-editor-all-measurements.png` | Measurement list and wall areas |
| `062-wall-view-door.png` | A wall face-on with a door |
| `065-room-3d.png` | 3D room |
| `030-project-estimate.png` | Estimate table |
| `079-report-page-1.png` | Report preview |
| `089-measure-wall-calculator.png` | Quick measure with the calculator |
| `095-board.png` | Board |
| `097-profile.png` | Profile |

## All screens

| Files | Area |
| --- | --- |
| 001–010 | Opening animation, welcome, language menu, continue without an account, sign up (name and phone, number already registered, SMS code, wrong code, password, account created) |
| 011–017 | Empty states: Home, Projects, new project form and its errors, Measure, Board, Profile |
| 018–023 | Sign out, log in, wrong password, forgot password, Google account chooser |
| 024–026 | Home (top and scrolled), Projects |
| 027–029 | Project: workspaces list, all rooms in 2D, all rooms in 3D |
| 030–034 | Estimate: table, add material, room areas, a row with a missing price, edit row with the number keyboard |
| 035–038 | Quotes tab, Details tab, project menu, new workspace |
| 039–042 | Workspace, the Add sheet, sketch choice, new room |
| 043–045 | Room editor: first-time tip, not measured, laser not connected |
| 046–049 | Laser device sheet: not connected, searching, found, connected |
| 050–056 | Room editor: reading received, confirmed with Undo, type a value, typing error, all confirmed, all measurements, measure again |
| 057–061 | Doors and windows: empty list, add door, door too wide, add window, plan with both |
| 062–064 | Wall view with a door, wall view with a window, edit window |
| 065–068 | 3D room, 3D top view, room info, readings tray |
| 069–072 | L-shaped room; free-sketch room: tip, drawn outline, result |
| 073–078 | Photo with dimensions, photo source, free drawing, note with checklist, item menu, workspace menu |
| 079–087 | Report pages 1 to 4, report set-up, page zoom, share, issue quote, issued quote |
| 088–094 | Measure: readings and area, wall calculator, type a value, readings list, send to a room, continuous mode, laser not connected |
| 095–096 | Board, job detail |
| 097–104 | Profile (top and scrolled), more settings, app language, PDF contents, currency, door and window defaults, builder details |
| 105–109 | Backup, restore (choose file, damaged file, good file), subscription |
| 110–114 | Subscription expired on Home, "Subscription needed", Profile with all three warnings, no internet, save failed |

## Not included

- The other three languages (Russian, Uzbek Cyrillic, English). Russian and Uzbek labels are longer, so a new layout must leave room for them.
- A few small sheets: units, room label, About, rename, delete confirmations, move to another workspace.
- Corner-by-corner shape editing and the diagonal check for non-rectangular rooms.

## Notes on what you see

- Dashed "Simulyatsiya" labels mark simulated things (laser readings, SMS, share sheet). They are part of the prototype, not the final design.
- The grey on-screen keyboard is the prototype's own model of a phone keyboard.
- "QORALAMA" across report pages is the draft watermark.
