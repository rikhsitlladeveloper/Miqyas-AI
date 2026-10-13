# METRX: project context for a redesign

This file gives a designer or an AI design tool everything it needs to redesign the app without access to the earlier conversations. Paste it in whole, then attach screenshots or `design/prototype/index.html`.

Status on 13 October 2026: the product scope is approved, a full clickable prototype exists, and no production code has been written yet.

---

## 1. The product in one paragraph

METRX is a mobile app for builders in Uzbekistan. A builder measures a room with a Bluetooth laser distance meter (or types the numbers), gets a dimensioned plan and a basic 3D shell, enters materials and labour by hand, and sends the customer a PDF quote. The first target users are **brickmasons**. "METRX" is a working name; the final name and logo are not decided. The GitHub repository is called Miqyas-AI.

## 2. Who uses it and where

- **Users:** brickmasons and small renovation crews in Uzbekistan. Practical people, not office workers; many use low-cost Android phones.
- **Where:** on a building site. Dust, gloves, sunlight, one hand free, sometimes on a ladder.
- **What they care about:** net wall area (walls minus doors and windows), because that is what they price by; a quote that looks professional; not losing their data.
- **Devices:** Android and iPhone. The founder tests on an iPhone 16 Pro Max and Android devices.
- **Languages:** Uzbek Latin (main), Uzbek Cyrillic, Russian, English. The PDF language is chosen separately from the app language. Russian and Uzbek labels are long, and they must fit at 360 px width.
- **Connectivity:** the core workflow works fully offline. No account is required.

## 3. Rules a redesign must not break

These are approved product rules, not style choices.

1. **A measurement is never applied without confirmation.** Every dimension has three states: not measured, received (from the laser, waiting), confirmed. A received value changes nothing until the builder taps Confirm. The three states must look clearly different.
2. **Never show status by colour alone.** Each state needs an icon and a word as well.
3. **Typing a value always works**, with or without Bluetooth, and the Bluetooth status must never block it.
4. **Material quantities and labour charges are typed by hand.** The app calculates dimensions, areas and money totals only. Changing a room never rewrites the estimate. A brick and mortar calculator is an open founder decision (see section 11).
5. **An issued quote is frozen.** Issuing creates a snapshot of geometry, 3D views, rows, totals, currency, language and both parties. Later changes become quote №2; №1 stays as it was.
6. **Simulated data is labelled.** While there is no real laser support, simulated readings carry a visible "Simulyatsiya" label.
7. **Everything stays on the phone.** There is no cloud sync in this release, so backup must be easy to find and its state must be visible.
8. **An expired subscription makes the app read-only, not locked.** Viewing, quick measuring, backup and PDF export of saved work keep working. Creating and editing open a "Subscription needed" sheet.
9. **One currency per project**, chosen in settings, with a set number of decimals. No currency conversion.
10. **Large touch targets:** 44 px minimum for anything tappable.

## 4. Scope

**In this release**

- Projects, organised into **workspaces** (places such as "1st floor", "Bathroom", "Yard").
- Rooms: rectangle, L-shape, or free sketch with straight and angled walls. Interior dimensions define the room; wall thickness is separate. Each room has a flat ceiling and its own height.
- Doors and windows: wall, width, height, distance from the wall's start corner, and sill height for windows. One universal look and one colour (no style picker).
- 2D plan with dimensions, face-on wall views, interactive 3D shell with basic surface colours and saved views.
- Workspace items besides rooms: free drawings, photos with dimension lines and arrows, notes with checklists.
- Estimate: material rows (name, unit, quantity, unit price, line total) and labour rows (description, total). Subtotals and a grand total.
- Draft report, issued quotes with revisions, PDF with plans, measurements, 3D views, estimate and notes.
- Backup and restore to a file. Optional sign-in (phone number and SMS code, or Google).

**Deferred, do not design for**

Curved walls, sloping ceilings, stairs, furniture, realistic rendering, AI interior design, rooms joined into one floor plan, shared price catalogues, automatic material takeoff, cloud sync, discounts, taxes and deposits.

## 5. Screens

Five bottom tabs: **Asosiy** (Home), **Loyihalar** (Projects), **O‘lchash** (Measure), **Doska** (Board), **Profil** (Profile). Screens inside a project hide the tab bar.

| Screen | Purpose | What the founder chose |
| --- | --- | --- |
| Opening and sign-in | Welcome, sign up (name and phone, SMS code, password), log in, forgot password, Google, "Continue without an account" | Optional sign-in, phone and SMS instead of email, language switcher on the welcome screen |
| Home | "What do I do now?" | Date, greeting and laser status; a **Continue** card with the last room and its next step; **Needs attention** list; four big tiles (New project, Measure, Photo, Note); recent projects |
| Projects | Find a job | Site cards with customer, address, stage and three numbers (net wall area, measurements confirmed, estimate total); Active / Done / All switch; search; Call button |
| Project | One job | Header with Call, Map and menu; three numbers; four tabs: Workspaces, Estimate, Quotes, Details. Workspaces can be seen as a list, all plans in 2D, or all rooms in 3D |
| Workspace | One place on site | Totals on top; two sections (Rooms; Photos, drawings, notes) as two-column card grids; a floating **+ Add** button that offers Sketch, Photo or Note |
| Room editor (plan) | Give a room its dimensions | Big plan; toolbar: Plan, Walls, Openings, 3D; a bottom **step card** for the current measurement that expands into a list of all measurements, wall areas and openings |
| Wall view | One wall face-on | Swipe or arrows between walls; doors and windows to scale; drag an opening to move it; gross, openings and net area |
| Door or window sheet | Add or edit an opening | Type, wall, width, height, distance from corner, sill; a small diagram; clear error messages |
| 3D | Check the shell | Rotate and pinch; Top and Corner presets; wall and floor colours; Save view (goes into the report) |
| Photo, drawing, note | Site records | Photo markup with dimension lines, arrows, text and pen; free drawing; note with title, text and checklist |
| Estimate | Bill of materials | A table: Name, Qty, Price, Sum; labour as agreed sums; subtotals; grand total and "Preview report" in the footer. A row may be saved with an empty price; it shows "?" and blocks issuing |
| Report | Check and send | PDF pages at full width, swipe between them, tap to zoom; a dark strip with the grand total, page count and language; settings in a "Set up" sheet; Share draft and Issue quote |
| Issued quote | Read-only copy | Same viewer under a "frozen" banner with the issue date; Share PDF |
| Measure | Quick measuring without a project | One press measures and saves; a calculator for Area, Wall (minus one opening), Volume and Sum, filled by tapping readings; a reading can be sent to a room dimension, where it still waits for confirmation |
| Board | Where is each job? | A five-step strip with counts (Measuring, Estimating, Quote sent, In progress, Done); one list per stage; each row shows the next task and a one-tap "next stage" button with Undo; quotes show days waiting and a Call button |
| Job detail (from Board) | Tasks and notes for a job | Stage picker, task checklist, notes, Open project |
| Profile | Me and settings | Name and phone (they appear on every quote); three status tiles: Laser, Backup, Subscription (amber when there is a problem, tap to fix); two short settings groups; account; "More settings" |
| Backup, Subscription, Device | Support screens | Create a backup file, restore with a check for damaged files; what works when expired; scan for and connect the laser |

## 6. States that need a design

- **Measurement:** not measured, received, confirmed, measuring again (old value stays until the new one is confirmed).
- **Laser:** connected, not connected, Bluetooth off, permission denied, searching, found.
- **Empty:** no projects, no workspaces, empty workspace, no readings, empty estimate, empty board.
- **Errors while typing:** empty, zero, negative, too many decimals, over 100 m, not a number. The sheet stays open and the old value is kept.
- **Door and window errors:** wider than the wall, taller than the room, past the corner, overlapping another opening. A dragged position is "approximate" (shown with "≈") until saved exactly.
- **Estimate:** a row with a missing price or quantity; issuing blocked until rows are complete.
- **App-wide:** saved (with the time), save failed with Retry, no internet, subscription expired.
- **Sign-in:** number already registered, wrong SMS code, weak password, wrong password, no internet.
- **Keyboard:** numeric entry is central. The prototype models its own on-screen keyboard to show the real space it takes.

## 7. The reference scenario and its numbers

Any redesign should be shown with this content, so results can be compared.

- Project **Yusupovlar uyi**, customer Akmal Yusupov, Toshkent, Chilonzor 14. Builder Bobur Rahimov, +998 93 555 12 34.
- Room **Mehmonxona**: 5,00 × 4,00 m, height 3,00 m, wall thickness 0,20 m.
- Door on wall A: 0,90 × 2,10 m, 0,50 m from corner 1. Window on wall C: 1,20 × 1,50 m, sill 0,90 m.
- Results: floor 20,00 m², perimeter 18,00 m, gross wall 54,00 m², openings 3,69 m², **net wall 50,31 m²**, volume 60,00 m³.
- Estimate: paint 12 × 50 000 = 600 000; flooring 22 m² × 120 000 = 2 640 000; labour 1 000 000. **Total 4 240 000 so‘m.**
- Uzbek number style: decimal comma, space between thousands ("4 240 000", "50,31").

## 8. The current visual design

The chosen direction is called **"Chizma"** (drafting): an architect's drawing look for plans, with a soft modern app shell around it.

- **Colours:** ink `#0E1C36` (text, plan walls); cobalt `#1C4BD1` (main actions) and `#1238A8`; page background `#F4F5F7`; cards `#FFFFFF`; hairlines `#E3E6EB`; pale fill `#EEF0F4`; pale blue `#EAF0FE`. Status: amber `#8A4500` on `#FFF1DF` (received, warnings), green `#0B6B4F` on `#E3F3EC` (confirmed, connected), red `#B42318` on `#FDEDEB` (errors), violet `#4A2FB0` on `#ECE7FC` (quote sent).
- **Type:** IBM Plex Sans for the interface; IBM Plex Sans Condensed for numbers and measurements. Page title 28 px bold, card title 16.5 px semibold, body 15 px, the laser readout 54 px.
- **Shapes:** white cards with a 16 px radius and a soft shadow; buttons 44 to 56 px tall with a 12 to 16 px radius; pill-shaped segmented controls; bottom sheets for forms.
- **Tab bar:** the active tab rises into a filled cobalt circle.
- **Drawings:** hatched wall sections, dimension lines with tick marks, wall letters A to D in circles, corner numbers, room name and area in the middle of the plan.
- **PDF:** A4, a header with the document title and date, a table for builder and customer, room pages with plan and measurements, then drawings and photos, notes, and the estimate with signature lines. Drafts carry a "QORALAMA" (draft) watermark.

References used so far: Bosch MeasureOn (behaviour of the wall view and sketching only, not its look), and community Figma kits for the sign-in flow, the animated tab bar and the general app shell.

## 9. What exists today

- **Clickable prototype:** one HTML file that behaves like the app, with real navigation, saving, validation, a modelled keyboard and a Three.js 3D view. It runs in a browser and inside an Android wrapper app.
- **Options pages:** for each page, the three designs that were compared before one was chosen.
- **Tested** on the Android emulator on 13 October 2026: the full scenario, all states above, and about 40 screens in each of the four languages with no cut-off text. Five problems were found and fixed.
- **Not built:** the production app. The plan is React Native with Expo, SQLite storage and a bundled Three.js renderer.
- **Simulated in the prototype:** laser readings, Bluetooth search, SMS codes, Google sign-in, the share sheet, backup files, GPS and subscription expiry.

## 10. Where the files are

Repository: `https://github.com/rikhsitlladeveloper/Miqyas-AI`, branch `builders-v1` (public).

| Path | Contents |
| --- | --- |
| `PRODUCT_SPEC.md` | Approved scope and rules |
| `BUILD_PLAN.md` | Technical plan and acceptance checks |
| `design/prototype/index.html` | The prototype; open it in a browser |
| `design/prototype/README.md` | Detailed description of every screen and decision |
| `design/prototype/modules/` | Source of each page (`home`, `projects`, `project`, `workspace`, `editor`, `openings`, `estimate`, `measure`, `board`, `profile`, `report`) |
| `design/<page>/<page>-options.html` | The three options compared for each page |
| `design/stage1/directions.html` | The three visual directions from the start |
| `design/stage3/stage3-preview.html` | Test results and the planned handoff documents |
| `design/stage3/emulator-shots/` | Screenshots from the emulator |
| `design/android-prototype/` | Android app that wraps the prototype |

The local folder has a few fixes that are not pushed yet: larger touch targets, a confirmation before deleting a project, and a label for diagonal measurements.

## 11. Open decisions

1. **Brick and mortar calculator.** The spec says quantities are typed by hand. For brickmasons, calculating bricks from the net wall area would save the most time, but it changes the approved scope.
2. **Board tasks.** Each job starts with "Measure the rooms", "Build the estimate" and "Send the quote", ticked by hand even when the app knows they are done.
3. **Quote layout.** The PDF is headed "METRX" and the total is on the last page. An alternative was proposed and not chosen: the builder's name and trade as a letterhead, with the total on page 1.
4. **Laser message in the room editor.** Bluetooth off and permission denied show the same general line.
5. **Name and logo.** Still to come.
6. **Translations.** Uzbek Cyrillic is generated automatically from Uzbek Latin; Russian and English are drafts. All need a native review.
7. **Real laser.** The device is ordered and its Bluetooth protocol is unverified.

## 12. What was never checked on a real device

A real laser, sunlight readability, use with gloves, real camera photos, the real share sheet and printing, iPhone behaviour, and speed on a low-cost phone.

---

## A prompt to start the other tool with

> You are redesigning a mobile app called METRX for brickmasons in Uzbekistan. Read the attached context file fully before proposing anything. Keep every rule in section 3 and every screen and state in sections 5 and 6; you may change layout, visual style, navigation and wording. Use the reference scenario in section 7 as the content for every mockup, in Uzbek Latin, at 360 px width, and show the same screen in Russian to prove long labels fit. Start with three screens only: Home, Room editor (with a measurement in the "received" state) and Estimate. Explain what you changed from the current design in section 8 and why it is better on a building site.
