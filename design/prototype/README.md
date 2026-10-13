# METRX clickable prototype (Stage 2, Direction A "Chizma")

This is a design artifact, not the React Native app. It runs in a browser and behaves like the phone app: real navigation, bottom sheets, a modelled on-screen keyboard, editable sample values, local saving and a 3D room shell.

## Files

| File | Purpose |
| --- | --- |
| `prototype.html` | The prototype source. This is the page published as a claude.ai Artifact (no `<html>`/`<body>` wrapper). |
| `index.html` | Generated from `prototype.html` for local or Wi-Fi preview. Rebuild with `python make_index.py` after editing. |
| `make_index.py` | Wraps `prototype.html` into `index.html`. |
| `modules/` | The source of each page (`home`, `projects`, `project`, `editor`, `workspace`, `openings`, `estimate`, `measure`, `board`, `profile`, `report`). Edit a module, then run `python ../tools/sync_modules.py` to paste it into `prototype.html` and rebuild `index.html`. See `../tools/README.md`. |

## Preview on your phone

**Option 1: the Artifact link (easiest).** Open the claude.ai link on your phone while signed in to claude.ai. Under 600 px wide, the app fills the whole screen. A small **Demo** tab on the left edge opens the prototype controls.

**Option 2: over your Wi-Fi from this PC.**

1. In this folder, run:

   ```bash
   python -m http.server 8000 --bind 0.0.0.0
   ```

2. On the phone (same Wi-Fi), open `http://<PC address>:8000/` — this PC was `192.168.1.115` when the prototype was built (check with `ipconfig`).
3. If Windows asks, allow Python through the firewall for private networks.
4. Optional: in Safari or Chrome, choose "Add to Home Screen" to hide the browser bar.

**Option 3: on the PC.** Open `index.html` directly, or use the server above and visit `http://localhost:8000/`. Wide windows show the phone in a frame next to the control panel.

Needs an internet connection for the web fonts and the Three.js 3D library (loaded from cdnjs). Without it, the 3D view shows the designed "3D didn't load" state. The production app bundles these locally.

## Navigation

The five bottom tabs, from left to right:

- **Asosiy (Home):** the founder chose option A ("Today's work") with option C's big tiles. Top to bottom:
  - the date and a greeting, with the laser status, which you can tap;
  - **Continue**, showing the last room's plan, where it is (project › workspace) and its exact next step, e.g. "Wall A: measure" or "Height: confirm";
  - **Needs attention**: unconfirmed measurements, door/window errors, openings placed by dragging, quotes waiting for a reply, estimate rows not filled in, and missing builder details. Each one opens the right screen;
  - four big tiles: New project, Measure, Photo and Note. Photo and Note go to the last room's workspace;
  - three recent projects.
- **Loyihalar (Projects):** the founder chose option B (site cards) with option A's Active / Done / All switch.
  - **Each card:** the customer and address, a stage label, and three numbers a brickmason prices by: net wall area, measurements confirmed (e.g. 3/3), and the estimate total in millions.
  - **What's waiting:** the same signals as Home, e.g. "2 measurements not confirmed" or "quote sent 2 days ago".
  - **Buttons:** **Call** opens the phone's dialer with the customer's number. The main button does the next job for the project: fix an error, continue measuring, add a room, fill in the estimate, issue a quote, or view quotes.
  - **Search and new projects:** search covers name, customer, address and phone. "+ Project" floats above the tab bar.
- **Project page:** the founder chose option A.
  - **Header:** the name, customer and address, and the stage, with **Call**, **Map** and **⋯** buttons. Call and Map show only when the project has a phone number or location.
  - **Three numbers:** net wall area, measurements confirmed, and the estimate total.
  - **Tabs:**
    - **Ish joylari (Workspaces):** each workspace with a small plan, counts and its own net wall area. "2D plan" and "3D" buttons show all rooms, and a floating "+ Ish joyi" (Workspace) button adds one.
    - **Smeta (Estimate)** and **Takliflar (Quotes):** as before.
    - **Ma’lumot (Details):** customer, phone with Call, address, location with "Open in maps", currency and decimals, report language, and "Edit details".
  - **Russian tab labels:** shortened to "Зоны" and "КП" so all four fit at 360 px. Inside a project, the Rooms section switches between List, 2D (every room drawn at one scale, with name and area) and 3D (the floor's measured rooms side by side).
- **O‘lchash (Measure):** live laser readout in single or continuous mode, saved readings, typed values, and sending a reading to a room.
- **Doska (Board):** kanban columns for Measuring → Estimating → Quote sent → In progress → Done. Each project card has tasks, notes and a Move action.
- **Profil (Profile):** builder details, counts, and all settings, including backup and subscription.

The navbar follows the "Animated Mobile App Navbar" community component: the active tab rises into a filled circle that slides between tabs. It is recoloured to the app's cobalt. The 2D/3D project views take their plan conventions from the "Interior Design Kit": solid walls, the room name and area in the middle, and a cut-away 3D view.

## Opening animation and optional sign-in

The structure follows the "Log in, Registration, Onboarding / Sign in & Sign up / Forgot password" community kit (welcome, three-step sign-up, log in with error states, three-step password reset, success screens). It is restyled in the app's drafting look and adapted to the market.

- **Opening animation (about 3 s, tap to skip):** a room plan draws itself, a simulated laser reading counts up to 5,000 m, the dimension lines appear, then the METRX wordmark. The plan stays at the top of the welcome screen. Reduced-motion settings skip the animation.
- **Welcome:**
  - Continue with Google, Create an account, Log in.
  - "Continue without an account", which leads to the existing name and phone step.
  - A language switcher in the top corner replaces the old separate language step.
- **Phone number and SMS code instead of email:**
  - Sign up: name and phone (1/3), 6-digit SMS code (2/3), password with live rules and a strength bar (3/3), then "Account created".
  - Forgot password uses the same pattern: phone (1/3), code (2/3), new password (3/3).
- **Simulated:**
  - Nothing is sent. The test SMS code is **482913**, and the keyboard offers it as "From Messages" autofill.
  - The test account is **+998 93 555 12 34 / metrx2026**. Accounts you create are kept in this browser or phone.
  - Google opens a simulated account chooser. Google doesn't share a phone number, so the app then asks for one.
  - Turning on "No internet" in the Demo panel shows the offline message on these screens.
- **Profile → Account:** "Log in or create an account" when signed out. When signed in, it shows the method, plus Log out with a confirmation. Logging out keeps all projects on the phone.
- **Account scope:** an account only identifies the builder and would carry the subscription. Projects stay on the phone (cloud sync is deferred in the spec).

## First run and new projects

- **First run without an account:** enter your name and phone. The phone field has a fixed +998 prefix, a phone keypad, and a check that the number has 9 digits. Both are required. They stay on the phone and appear on reports.
- **New project:** project name and customer name (both required), customer phone, address, and location (all optional). In this prototype, "Joylashuvni aniqlash" fills in simulated GPS coordinates, shown with the accuracy and a map placeholder.
- **Settings instead of form fields:** currency, decimal places and report language are no longer on the form. A new project copies them from Profil → "Valyuta va kasr" and "Standart hisobot tili". Changing those settings affects new projects only, so a project never switches currency after its rows are entered. The report preview still lets you pick a different language for one report.

The interface style follows the "Mobile Apps – Prototyping Kit" community file: soft grey backgrounds, rounded white cards, pill segmented controls, underline tabs and icon tiles in settings. The drawing conventions (hatched walls, dimension lines, the PDF layout) are unchanged.

## Emulator test, 13 October 2026

A clean install was walked through on the Android emulator (1080 × 2400), with real touches for drags, swipes, 3D rotation and the back button. Twelve areas passed, 40 screens were checked in each of the four languages with no cut-off text, and the app raised no script errors. Five problems were found and fixed:

- **Room editor:** typing a new value while measuring a wall again left the step card on "measure again". Any confirmed value now ends that state.
- **Workspace:** the "PDF" badge covered the first words of a note on its card.
- **Notes:** leaving a note with no title, text or list items now removes it, so Home's Note tile no longer leaves empty notes behind.
- **Sent readings:** a reading sent from the Measure tab is labelled "from the Measure tab" in the room, not "from the laser".
- **Sign-up:** going Back from the password or code step keeps the name and phone already typed. The same applies to the forgot-password phone.

Still open: 14 controls are under 40 px on their short side, Board tasks are ticked by hand, and the room editor shows one general message for Bluetooth off and permission denied. Not covered by this run: pinch zoom, L-shaped and free-drawn rooms, deleting or moving items, and confirming a restore.

## Report and quote

The founder chose option A: read it first. The PDF itself is unchanged.

- **Pages at full width:** the PDF pages fill the screen width. Swipe moves exactly one page, or use the arrows with the "1 / 3" counter. Tap a page to open the zoomable full-screen viewer.
- **Total strip:** a dark strip above the pages shows the grand total, the page count and the report language.
- **Set up sheet:** the "Sozlash" button opens a sheet with report language, rooms, drawings/photos/notes from workspaces, 3D views and the notes field. "Done" applies the notes to the preview. Changing the language re-renders the pages straight away.
- **Warnings:** missing builder details and unconfirmed dimensions still show as amber banners above the total.
- **Footer:** "Share draft" (marked DRAFT) and "Issue quote", as before.
- **Issued quote:** uses the same viewer and total strip, under the "frozen" banner with the issue date. The footer has "Share PDF".

## Profile

The founder chose option A: status first, short groups.

- **Header:** your name and phone, with an edit button. A line underneath says they appear on every quote.
- **Status tiles:** Laser, Backup and Subscription. Each one shows its state in words. A problem turns amber with a warning icon (laser not connected, Bluetooth off, no backup or none in 7+ days, subscription expired), and tapping the tile opens the fix: the device sheet, Backup and restore, or Subscription.
- **Two short groups:** "Language and report" (app language, default report language, PDF content, currency) and "Measuring and drawing" (door and window sizes, 45°/90° snapping). The account group follows.
- **More settings:** a separate page with units, room labels, "show tips again", the device, backup, subscription and About.
- **Removed:** the projects/quotes/rooms stats. The "phone only" note moved to the bottom.

## Board

The founder chose option A: a stage list, top to bottom.

- **Stage strip:** five boxes (Measuring, Estimating, Quote, Work, Done), each with its count. Tap one to jump to its list; stages with no jobs are dimmed.
- **Stage lists:** one card per stage, listing its jobs. Each row shows the job name, the customer and address, and the next open task. Tick the box to mark the task done; Undo is in the toast.
- **Next stage:** a one-tap button moves the job on (To estimate, To quote, Start work, Finish), with Undo in the toast. Moving back a stage still goes through the job's detail page.
- **Quotes:** the row shows the quote total and how many days the quote has been waiting, highlighted from two days on. If the customer has a phone number, there's also a call button that opens the dialer.
- **Done:** finished jobs fold into one row, which opens with "Show".
- **Removed:** the side-scrolling columns, the duplicate stage chips and the Move sheet. The "phone only" note moved to the bottom. Tapping a row still opens the job detail (stage, tasks, notes).

## Measure

The founder chose option C: one press to measure, plus a quick calculator.

- **One press:** "Measure" takes the simulated laser reading and saves it in a single tap. In continuous mode the reading follows the laser; "Start/Stop" controls it and the main button becomes "Save". "Type it" opens a sheet for manual entry, with the usual validation messages (empty, zero, too long, wrong precision).
- **Meter:** shows the last saved reading. In continuous mode it shows the live value. With no laser connected, a warning appears and the main button becomes "Connect laser"; typing still works.
- **Calculator:** four tools.
  - Area: length × width.
  - Wall: length × height, minus an optional door or window (width × height). An opening bigger than the wall shows a warning instead of a negative area.
  - Volume: length × width × height.
  - Sum: adds lengths.
- **Filling the calculator:** the box with the yellow frame is filled next. A new reading goes into it automatically, or you can tap a reading chip. Tap a box to choose it; in Sum, tapping a value removes it. Readings in use are highlighted.
- **Readings:** recent readings appear as chips. "List" opens the full list, where you can send a reading to a room dimension or delete it.
- **Geometry only:** the calculator never changes the estimate. Quantities stay manual, as before.

## Estimate (BOM)

The founder chose option A, a table.

- **Layout:** materials as Name | Qty | Price | Sum, with the unit under the name. Labour is listed as agreed sums. Each section has "+ Add row" and a subtotal; the grand total and "Preview report" stay in the footer.
- **Missing values:** a row can be saved with its quantity, price or labour amount still empty, for when you know the quantity before the price. Missing values show as an amber "?", and a warning above the table counts them. A zero price is valid and isn't flagged. Invalid text is still rejected.
- **Issuing a quote:** blocked until every row is filled in, with the message "Fill in N estimate rows before issuing a quote".
- **Quantities stay manual:** nothing is calculated automatically. A brick and mortar calculator is a pending founder decision because the spec defers automatic material takeoff.
- **Project page:** the three numbers under the header now show only on the Workspaces tab, which leaves more room for the table.

## Room editor

The founder chose option A (a big plan), with option B's step card and option C's list in one bottom panel.

- **Header:** the room name, project › workspace, a laser status icon, undo, redo, and ⋯ (room info). Below it the plan fills most of the screen.
- **Toolbar:** Plan, Walls (wall view), Openings, 3D.
- **Bottom panel, collapsed: the step card for the current measurement.**
  - Not measured: "Next: Wall A" with **Type it** and **Take from laser**. If the laser isn't connected, the second button opens the device screen.
  - Received from the laser: the value in large amber numbers, "Not confirmed", and **Again** / **Confirm**. A received value is never applied without Confirm.
  - Confirmed: the value with **Edit** and **Measure again**. While measuring again, the confirmed value stays until a new reading is confirmed, and you can cancel.
  - Door or window error: the message with **Fix**.
  - All confirmed: floor and net wall area, with Walls and 3D buttons.
  - The footer says what comes next and how many are left.
- **Bottom panel, expanded** (tap or swipe up the handle, or "All"):
  - every measurement (walls, height, wall thickness) with its state and a Confirm or Measure button;
  - wall areas per wall (gross, doors/windows, net, total), shown once the height is confirmed;
  - the doors and windows, plus "Add a door or window".
- **Tapping a wall or a value on the plan** brings the step card to it instead of opening a sheet. Typing a value still uses the familiar sheet.
- **L-shaped and free-shape rooms:** "Shape" and "Diagonal" float on the plan. Shape editing and the diagonal check keep their own screens. Solver warnings appear in the panel.

## Doors and windows: one standard look, drag to move

The current users are brickmasons, so every door and window uses **one universal design and one colour**: a plain door leaf with a handle, and a two-pane window with an inside sill board. The same look is used in the wall view, the plan and the 3D model. There is no design or colour picker.

- **Wall view:** drag sideways to move along the wall, or drag a window up or down to change its sill height.
- **Plan:** drag along the wall. This works for rectangular rooms; for non-rectangular rooms use the wall view.
- **While dragging:** a live label shows the distance from the corner and the sill height. It snaps to 1 cm, the middle of the wall, the wall ends and the default sill height.
- **Limits:** an opening can't leave its wall. If it would overlap another opening, it goes back to where it was. Moves can be undone.
- **Dragged = approximate:** a dragged position shows a dashed amber outline and "≈" on the cards and in the PDF, until you confirm it by opening the door/window sheet and saving.

## Workspaces

A project is organised into **workspaces**: places such as "1st floor", "Bathroom" or "Yard". Workspaces replace the old Floors.

- **After saving a new project:** it opens on the **Workspaces** tab with a "Create your first workspace" prompt.
- **Creating a workspace:** a name plus one tap on a type (Floor, Room, Bathroom, Kitchen, Balcony, Outdoor, Other). The type sets the icon and suggests a name.
- **The workspace page** (option A, chosen by the founder):
  - **Empty:** a blank white page with a **+ Add** button.
  - **Totals at the top:** net wall area, floor area, and measurements confirmed. "+?" means some rooms aren't measured yet.
  - **Two sections instead of filters:** **Rooms**, and **Photos, drawings, notes**, each a two-column grid, newest first.
  - **Room cards show their state:** e.g. "Wall A: measure", "Wall B: confirm", or a green "50,31 m² wall" when done.
- **The + button** opens three tiles:
  - **Sketch:** choose **Room plan** (the existing room editor, which feeds 3D, areas and the estimate) or **Free drawing**. Free drawing tools: pen in 3 colours and 2 widths; a straight line that snaps to 0/45/90° and takes a value from the laser or keyboard; text label; eraser; undo/redo.
  - **Photo:** **Take a photo** (simulated camera with 3 sample photos) or **Choose from gallery** (a real photo from the phone, reduced to 1280 px). On the photo you can add dimension lines (laser or typed), arrows, text, pen and a caption. Photo dimensions are reference only and never change a room plan.
  - **Note:** a title, multi-line text and a checklist. Enter on the last checklist item adds the next one.
- **Card actions (⋯ or long-press):** Rename, Move to another workspace, Duplicate, Include in report, Delete (with Undo).
- **The workspace ⋯ menu:** rename or change type, delete (with Undo).
- **The PDF report:** drawings and photos are included by default, notes are not. Change this per item on the card or in Report → "Drawings, photos and notes".
  - Drawings and photos print two per page.
  - Notes get a Notes page, with ☑/☐ for checklist items.
- **Android:** "Choose from gallery" opens the system picker.
- **Storage limit:** photos are stored in the prototype's local storage (about 5–10 MB in total), so a few dozen photos is the practical limit in this prototype.

## Sketching and walls (patterns adapted from Bosch MeasureOn)

The behaviour is copied, not Bosch's look, icons or wording.

- **Editor toolbar:** Balandlik (Height), Devorlar (Walls), Ochiq joylar (Openings), Xona (Room info).
- **Wall view:** each wall is shown face-on from inside the room.
  - Moving around: a dot pager, ‹ › arrows or swipe, and a mini plan showing which wall you are on.
  - On the wall: doors and windows drawn to scale, with offset and width dimensions you can tap to measure.
  - Below: gross, openings and net area, plus an openings strip with an Add button.
- **Room shapes:** the new-room sheet offers Rectangle, L-shape and Free sketch.
  - **Free sketch:** draw the room in one stroke, or tap the corners. The outline is straightened and snapped to 90°/45°, and you're warned if it isn't closed or the lines cross. "Namuna chiziq" (sample stroke) is a labelled demo.
  - **Non-rectangular rooms:** each wall has its own dimension. The app computes the last two walls when it can (shown with "="). A value that doesn't fit is shown in brackets with the difference and is never changed automatically. A diagonal "check measurement" flags corners that aren't square. "Edit shape" lets you drag corners with guides and an angle readout; measured numbers never change.
- **Room info:** floor area, perimeter, height, wall thickness, gross and net wall area, room volume. Actions: rename, walls, rotate the plan view (90° steps; wall letters stay), wall thickness, delete.
- **Readings tray (O‘lchovlar):** measure first, assign to a wall later. An assigned reading still waits for your confirmation.
- **Profile → Chizma (Drawing):** angle snap, default door/window sizes, room label (name and/or area), PDF contents, show tips again.
- **One-time tips:** in the editor, wall view and sketch screen, with "Don't show this again". The keyboard has ‹ › to move between fields.

The sign-in, wall-view and sketch code lives directly in `prototype.html`; `modules/auth.*`, `modules/wallview.*` and `modules/sketch.*` are reference copies that the sync script does not touch. All other modules are the source and are pasted in by `tools/sync_modules.py`.

## Core scenario

Create project → create rectangular room → enter dimensions (5 × 4 × 3 m) → add door (0,90 × 2,10) and window (1,20 × 1,50) → inspect the 3D shell → add materials and labor (total 4 240 000 so‘m) → preview report → issue and see the saved quote. To test a revision, change wall A to 6,00 m and issue again. Quote №1 keeps 5,00 m.

Form fields start with the sample values from the brief. Every field can be cleared and retyped with the on-screen keyboard (or a physical keyboard on a PC).

## What is simulated

Everything simulated carries a dashed **Simulyatsiya** label in the app:

- laser readings (the "Lazer tugmasini bosish" button stands in for the device)
- Bluetooth search, permission and settings screens
- the on-screen keyboard (modelled so the layout shows real keyboard height)
- the phone share sheet for PDFs
- backup file creation and the file picker for restore
- subscription expiry and renewal

The control panel (desktop side panel, or the Demo tab on a phone) switches language, screen size, laser state, expired subscription, no internet and a failed save. It can also jump to saved points in the scenario, and it shows a checklist of the scenario steps and states you have seen.

## Language review

Uzbek Latin is the main draft. Russian and English are drafts. Uzbek Cyrillic is transliterated automatically from the Uzbek Latin draft and needs a native review, especially loanwords. "Compare uz / ru / uz-Cyrl" shows the current screen in three languages side by side and outlines any text that gets cut off.

Data is saved in this browser only (localStorage). "Jump to" or clearing site data resets it.
