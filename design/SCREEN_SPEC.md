# METRX screen specification

Status: Stage 3 handoff, 13 October 2026. This describes what each screen does and every state it can be in, as built and tested in `design/prototype/`. It is the behaviour the real app should reproduce. Where the prototype only simulates something, that is marked **(simulated)**.

Read with `PRODUCT_SPEC.md` (the rules), `DESIGN_SYSTEM.md` (how it looks) and `REVIEW_CHECKLIST.md` (what was tested).

Interface text is quoted in English. The Uzbek and Russian wording is in the prototype's dictionaries.

## Contents

1. Rules that apply everywhere
2. Sign-in
3. Home
4. Projects
5. New project
6. Project page
7. Workspace page
8. New room and the free-drawn outline
9. Room editor (plan)
10. Wall view
11. Doors and windows
12. 3D view
13. Photo, free drawing and note
14. Estimate
15. Report (draft)
16. Issued quote
17. Measure
18. Board
19. Profile and settings
20. Shared sheets and system states

---

## 1. Rules that apply everywhere

### 1.1 Navigation

- **Five tabs:** Home, Projects, Measure, Board, Profile. The active tab is raised in a cobalt circle.
- **Each tab keeps its own stack.** Tapping the active tab returns to that tab's first page.
- **The tab bar is hidden** on full-screen pages (room editor, wall view, 3D, free-drawn outline, workspace, note, photo, drawing, report, quote, new project, builder details, backup, subscription) and whenever a sheet or the keyboard is open.
- **Back** (the bar's arrow or the Android back button) undoes one layer at a time, in this order: keyboard, sheet, page, then from any root tab to Home. From Home, Back leaves the app.
- **Sheets** slide up from the bottom, dim the page, and close with the X, a tap on the dimmed area, or Back.

### 1.2 Saving

- Every change is saved at once. There is no Save button for data, only for forms and sheets.
- The app bar shows a chip: "Saved 12:01".
- **Save failed:** a banner says "The last change was not saved. Earlier data is safe." with **Retry**. Nothing else is blocked.
- **No internet:** a chip says "No internet". Everything except sign-in keeps working.
- Reopening the app returns to the same screen with the same data, including after a crash or a reboot.

### 1.3 The measurement rule

Every dimension is in exactly one of three states.

| State | Meaning | Shown as |
| --- | --- | --- |
| Not measured | No value yet | "?" and the chip "Not measured" |
| Received | A value arrived from the laser or the Measure tab and is waiting | The value, a clock icon and "Unconfirmed" |
| Confirmed | The builder accepted or typed it | The value, a tick, and its source (Laser, Simulation, Typed) |

- A received value **never** changes the plan, the areas, 3D or the report. Only **Confirm** does.
- **Again** discards a received value and keeps whatever was confirmed before.
- A typed value is confirmed when it is saved.
- Simulated readings always carry the hatched "Simulation" tag.

### 1.4 Numbers

- Lengths are stored in millimetres and shown in metres. Areas are in m², volumes in m³.
- The decimal mark follows the language: comma in Uzbek and Russian, point in English. Both are accepted when typing.
- Length input is rejected, with its own message, when it is empty, zero, negative, not a number, has more than 3 decimals, or exceeds the limit (100 m for walls, 20 m for height, 2 m for wall thickness).
- Money uses the project's currency and precision (0, 2 or 3 decimals). Each line is rounded, then lines are summed. A zero price is valid. Negative values and extra decimals are rejected.

### 1.5 Geometry and money stay separate

- Room sizes calculate dimensions and areas only.
- Changing a room never changes a quantity, a price or a labour amount.
- An issued quote is a frozen copy. Later changes create a new quote and leave old ones untouched.

### 1.6 Deleting

- **Project** and **workspace:** a confirmation sheet names what else is deleted, then an Undo toast appears.
- **Room, photo, drawing, note, door, window:** deleted at once with an Undo toast.
- **Estimate row:** deleted at once. There is no Undo yet (see the checklist).

### 1.7 Subscription expired (read-only)

- A banner on every page says "Subscription expired. Viewing, measuring, backup and PDF work." with **Renew**.
- Still works: viewing everything, 3D, the Measure tab, backup and restore, the report, sharing a PDF.
- Blocked: new project, room, workspace, opening; editing any dimension or estimate row; issuing a quote. Each opens the "Subscription needed" sheet.
- During the pilot everything is unlocked.

### 1.8 One-time tips

The room editor, free-drawn room, outline screen and wall view each show a tip card on first use, with "Don't show this again" and "Got it". Without the tick the tip returns next session. Profile has "Show tips again".

---

## 2. Sign-in

An account is optional. Projects always stay on the phone.

### 2.1 Welcome

- **Reached:** first launch, after an opening animation; or Profile → "Sign in or create an account" (then with a Back arrow).
- **Shows:** wordmark, a small plan drawing, the headline, and a language menu (four languages).
- **Actions:** Continue with Google · Create account · Log in · Continue without an account.

### 2.2 Create account, 3 steps

| Step | Fields | Rules and states |
| --- | --- | --- |
| 1 of 3 | Name or company, phone | Both required. Phone must be 9 digits. A number that already has an account shows "An account already exists for this number" with a Log in link. No internet shows a message that sign-in needs a connection but work can continue without an account. |
| 2 of 3 | 6-digit code | Verified automatically on the sixth digit. A wrong code shows "The code is wrong"; typing again starts a new code. Resend is available after a 0:59 countdown. "Change number" goes back. **(simulated: no SMS is sent, the test code is shown.)** |
| 3 of 3 | Password | Three live rules: at least 8 characters, a digit, a letter. Show/hide toggle. The button stays inactive until all pass. |

- Going Back from step 2 or 3 returns to step 1 with the name and phone still filled in.
- **Done screen:** "Account created", an explanation that the subscription is tied to the account and projects stay on this phone, and **Start**.

### 2.3 Log in

- Phone and password. Empty fields show their own messages.
- A wrong password and an unknown number both show "The phone number or password is wrong".
- While checking, the button shows "Checking…".
- "Forgot your password?" starts the reset.

### 2.4 Reset password

Phone (already filled in) → 6-digit code → new password twice. A mismatch shows "The passwords are not the same". Success shows "Password updated" and returns to Log in with the phone filled in.

### 2.5 Google **(simulated)**

An account chooser appears. Choosing an account signs in. If the builder's name and phone are missing, one more step asks for them.

### 2.6 Continue without an account

Asks for the builder's name and phone if they aren't set, then opens the app. The name and phone appear on every quote.

### 2.7 Sign out

Profile → Sign out → a sheet says "Projects stay on this phone. You can sign in again at any time." After confirming, a toast repeats that the projects stayed.

---

## 3. Home

- **Purpose:** continue where you stopped, see what needs attention, start something new.
- **Shows, top to bottom:**
  - wordmark and the Saved chip;
  - the date and a laser chip (opens the device sheet);
  - a greeting with the builder's first name;
  - **Continue card:** the last room's plan, its path (project › workspace), its status, and **Continue**, which opens that room;
  - **Needs attention**, with a count. Each row opens the place to fix it. Possible rows, most urgent first:
    - "A door or window needs fixing";
    - "3 measurements not confirmed";
    - "2 openings placed roughly" (dragged, not yet measured);
    - "Quote sent today" or "Waiting for a reply to the quote, 3 days";
    - "1 estimate row not filled in";
    - "Add your name and phone for reports";
  - **four tiles:** New project (primary), Measure (shows the laser state), Photo for "workspace", Note for "workspace". The last two add to the most recent workspace;
  - **Recent projects** with "All".
- **Empty state:** "Start with the first project", **New project**, and "Restore from backup".

---

## 4. Projects

- **Shows:** a search field, a switch (Active · Done · All, each with its count), project cards, and a floating "+ Project" button.
- **Card:** name, customer and address, stage chip, three numbers (Net wall, Measured n/n, Estimate), one line saying what is waiting, and two buttons.
- **First button:** Call, which opens the dialer, when the customer has a phone number; otherwise Open.
- **Second button** is the one main action for the project's state. The first matching row applies:

| State | Line on the card | Main button |
| --- | --- | --- |
| A door or window has an error | "A door or window needs fixing" | Fix the error |
| A dimension is not confirmed | "3 measurements not confirmed" | Continue measuring |
| No rooms | "No rooms measured yet" | Add a room |
| No estimate rows, or a row is missing a value | "1 estimate row not filled in" | Fill in the estimate |
| No quote issued yet | — | Issue a quote |
| Quote issued | "Quote sent today" / "Waiting for a reply, 3 days" | View quotes |

- **Search** matches project name, customer and address.
- **States:** no projects ("No projects yet", New project, Restore from backup) · nothing in this section · no match for the search.

---

## 5. New project

- **Fields:** project name (required), customer name (required), customer phone (optional, 9 digits), address (optional).
- **Location (optional):** "Detect location" fills coordinates with their accuracy, then offers "Detect again" and "Remove". GPS works without internet. **(simulated coordinates)**
- **Currency and precision:** a sheet with UZS, USD, EUR, RUB and 0, 2 or 3 decimals. The choice applies to this and future projects; existing projects and issued quotes don't change.
- **Save** shows each missing or invalid field with its own message and keeps the form open.
- After saving, the project page opens with an empty Workspaces tab.

---

## 6. Project page

- **Header:** back, Saved chip; project name; Call (if a phone is set), Map, and a menu (Project details, Delete project); customer and address; stage chip.
- **Three numbers** (Workspaces tab only): Net wall, Measured n/n, Estimate.
- **Four tabs:** Workspaces · Estimate · Quotes (with a count) · Info.

### Workspaces tab

- A workspace is a floor, room, bathroom, kitchen, balcony, yard or other place. It holds rooms, photos, drawings and notes.
- Once rooms exist, a switch offers **List · 2D · 3D**. 2D and 3D show all rooms at one scale; they are not joined into one plan.
- **Workspace card:** plan thumbnail, name, what it contains ("1 room, 1 drawing, 1 photo, 1 note"), net wall area, and 2D plan / 3D buttons.
- **New workspace** opens a sheet: pick a type (which fills in a default name) and create.
- **Empty state:** "Create the first workspace".

### Info tab

Customer, phone with Call, address, location with "Open in map" **(simulated)**, currency and precision, report language, and **Edit details**.

### Deleting the project

Menu → Delete project → a sheet: "Its rooms, estimate and N issued quotes are deleted too." → Delete → Undo toast.

---

## 7. Workspace page

- **Header:** back to the project, Saved chip, menu (Rename and change type · Delete workspace).
- **Shows:** icon, name and type; three numbers (Net wall, Floor, Measured n/n); a **Rooms** section and a **Photos, drawings, notes** section, each a grid of cards; a floating **+ Add** button.
- **Card:** thumbnail, kind, name, a status line, a "PDF" badge when it is included in the report, and a menu.
- **Card menu:** Rename · Move to another workspace · Copy · Add to / remove from report · Delete.
- **+ Add sheet:**

| Choice | Next |
| --- | --- |
| Sketch | Room plan (walls, dimensions, doors and windows; feeds 3D and areas) or Free drawing (pen and lines only; does not affect anything) |
| Photo | Take a photo **(simulated sample photo)** or Choose from gallery (the phone's real picker) |
| Note | Opens a new note |

- **Empty state:** "This place is empty. Press + to add a sketch, photo or note."
- **Deleting the workspace:** a sheet lists what is inside, then an Undo toast.

---

## 8. New room and the free-drawn outline

### 8.1 New room sheet

- **Fields:** room name (required), shape (Rectangle · L-shape · Free drawing), wall thickness (0,20 m by default).
- A note says dimensions start empty and each wall is measured and confirmed.

### 8.2 Free-drawn outline

- **Two modes:** **Draw** (trace the outline in one stroke) and **Corners** (tap each corner, then tap the first one or "Close room").
- **90°/45° snapping** is on by default and can be switched off.
- **Sample stroke** draws an example **(simulated)**. **Redraw** clears. In Corners mode, Undo removes the last corner.
- **States:**

| State | Message | Create room |
| --- | --- | --- |
| Nothing drawn | "Draw the room outline in one stroke" | Off |
| Valid outline | "5 walls. You'll measure each one next." | On |
| Lines cross | "The walls cross each other. Redraw without crossing." | Off |
| Not closed | "The outline is not closed. Join the ends or press Close room." | Off |

- Drawing sets the shape and angles only. Lengths come from measuring.

---

## 9. Room editor (plan)

- **Purpose:** give a room its dimensions one at a time and watch the plan fill in.
- **Reached:** a room card, "Continue" on Home, a new room, or sending a reading from the Measure tab.
- **Layout:** app bar (room name, path, laser status, undo, redo, menu) · the plan · a "Readings n" button · the **step card** · four mode buttons (Plan, Walls, Openings, 3D).
- **Menu (⋮):** a summary of the room: floor area, perimeter, height, wall thickness, walls gross, openings, walls net and volume, with the note that openings are deducted and reveals and columns are not counted.

### 9.1 The plan

- Walls are hatched and lettered A, B, C…; corners are numbered clockwise from 1.
- Each dimension has a chip on a dimension line. Tapping a wall or chip selects it in the step card.
- The room name and floor area sit in the middle ("? m²" until the area can be calculated).
- A calculated side is dashed, blue and starts with "=".

### 9.2 The step card

It always shows one dimension and the next thing to do.

| State | Title | Buttons | Footer |
| --- | --- | --- | --- |
| Not measured | "Next: Wall A" | Type it · Take from laser | "Then: Wall B. 2 more" |
| Received | "Wall A, from the laser" or "…from the Measure tab" | Again · Confirm | same |
| Confirmed | "Wall A, Typed" (or its source) | Edit · Measure again | same |
| Measuring again | "Measure again: Wall A", with "Now: 5,00 m. It doesn't change until the new one is confirmed." and Cancel | Type it · Take from laser | same |
| All confirmed | "Everything is confirmed", floor and net wall areas | Walls · 3D | — |
| Laser not connected | adds "Laser not connected. Type the value." | Type it · Laser (opens the device sheet) | same |

- After Confirm the card moves to the next unmeasured dimension and a toast offers Undo.
- The order is walls, then height. Wall thickness is confirmed from its default.
- **All** opens a list: wall areas (gross, openings, net, per wall and in total), doors and windows, and every dimension with its state and source. A handle above the card opens the same list by swiping up.

### 9.3 Typing a value

A sheet with one field, the unit, the current value and its source, and "A typed value is confirmed when saved." Errors keep the sheet open and the old value in place.

### 9.4 L-shaped and free-drawn rooms

- **Shape:** drag a corner. Confirmed lengths don't change. Snapping can be toggled. **Done** returns to measuring.
- **Calculated sides:** when the confirmed sides fix the rest, the remaining sides are calculated and shown with "=". They are not measured.
- **Diagonal:** tap two corners to add a diagonal (X1, X2…) and measure it like a wall.
- **Conflict:** if a diagonal disagrees with the plan, the plan is **not** changed. A warning says how much it differs, that a corner may not be 90°, and offers **Measure again**. The diagonal shows in brackets with a warning icon.

### 9.5 Readings tray

"Readings n" opens a sheet: "Measure first, then assign to a wall. An assigned value still waits for your confirmation." It has a laser button and lists the saved readings, each with **Assign to** A · B · Height. An assigned reading arrives as Received.

### 9.6 The measure sheet

The wall view measures through a sheet instead of the step card. It has the same states:

| Phase | Shows | Buttons |
| --- | --- | --- |
| Waiting | "Press the measure button on the laser", the current value and its source | Type it |
| Received | The reading, "Received, not confirmed yet", the current value | Type it · Measure again · Confirm |
| Typing | One field with the usual errors | Cancel · Save |
| Laser not connected | Goes straight to typing | Cancel · Save |

### 9.7 Other states

- **Undo and redo** cover dimensions, openings and shape changes within the session.
- **Read-only:** everything is visible; editing opens "Subscription needed".

---

## 10. Wall view

- **Purpose:** see one wall from inside the room and place doors and windows on it.
- **Shows:** the wall's letter and room, a pager (arrows, dots, swipe left or right), a small map marking which wall this is, the wall drawn to scale with its length and height, and each door and window with its sizes and distances.
- **Drag** a door or window along the wall. Its position is then marked "≈" (approximate) until an exact distance is typed. A toast offers Undo.
- **Tap** a door or window to edit it. Tap a dimension chip to measure it.
- **Below the drawing:** Wall gross, Openings, Wall net; then a card for each opening on this wall; then **Add opening**.
- **Empty state:** "No openings on this wall."

---

## 11. Doors and windows

- **Sheet fields:** Door or Window · wall (with each wall's length) · width · height · distance from the wall's start corner · sill height (windows).
- A small diagram shows the start corner and the direction of measuring (clockwise).
- New openings start from the default sizes in Profile.
- **Errors keep the sheet open:**

| Problem | Message |
| --- | --- |
| Too wide or too far along | "The door runs 1,50 m past the wall. Reduce the width or the distance." |
| Too tall | "The door is 0,50 m taller than the room. Reduce the height or the sill." |
| Overlap | "The door touches another opening. Change the distance." |

- After a drag, the sheet says the position is approximate and asks for a measured value.
- **Columns and recesses** are deferred. The entry opens a short explanation.
- One standard look and one colour for all doors and windows.

---

## 12. 3D view

- **Shows:** the room shell with wall letters, doors and windows; a Plan/3D switch; the laser chip.
- **Gestures:** drag to rotate, pinch to zoom.
- **Presets:** From above · From a corner.
- **Colours:** four wall colours and four floor colours.
- **Save view** stores the current picture for the report and shows "Saved views: n".
- The project's 3D tab shows all rooms together.
- **If 3D cannot load,** a message says so and the plan stays usable.

---

## 13. Photo, free drawing and note

### 13.1 Photo

- **Tools:** Dimension · Arrow · Text · Pen · Eraser. Three colours. Undo and redo. A caption.
- **Dimension:** drag along what you measure, then a sheet offers the laser (the value arrives as "Received", with "Use this") or typing. It also offers "Delete line" and "Later".
- A line without a value shows "?" and the card says how many dimensions are open.
- Photo dimensions are for information. They never change a room plan.

### 13.2 Free drawing

Pen, Line, Text, Eraser; thin or thick; three colours; undo and redo. It does not affect areas or the estimate.

### 13.3 Note

- **Fields:** title, text, a checklist (add, tick, delete items), and an "Add to report" switch.
- Text is saved as you type.
- Leaving a note with no title, text or list items removes it.

---

## 14. Estimate (project tab)

- **Top:** "Currency: UZS, no decimals" and **Room areas**, a sheet listing each room's floor, perimeter and net walls. It is for reference: nothing is copied into quantities.
- **Materials table:** name with its unit underneath · quantity · price · sum. Then "+ Add row" and the materials subtotal.
- **Labour table:** description ("Agreed sum" underneath) · amount. Then "+ Add row" and the labour subtotal.
- **Footer:** Grand total and **View report**.
- A note says quantities and prices are entered by the builder and don't change when room sizes change.

### Row sheet

- **Material:** name, unit (pcs, can, m², m, kg, bag, litre, set), quantity, unit price. The line total updates as you type.
- **Labour:** description and amount.
- Quantity, price or amount may be left empty and filled in later. Name is required.
- Editing a row offers **Delete**.

### States

| State | What shows |
| --- | --- |
| Empty | "No materials. Add a row." and "No labour." |
| Missing values | A warning "1 row has no quantity or price"; the cell shows an amber "?" and the sum "—"; that row adds nothing to the total |
| After issuing | "The draft is the same as quote №1", or that it differs |
| Read-only | Adding or editing opens "Subscription needed" |

---

## 15. Report (draft)

- **Purpose:** read the document before sending it.
- **Header:** back, "Report", project name, and **Set up**.
- **Warnings** above everything: builder details missing (with Add) · N dimensions unconfirmed (they are marked "approximate" in the PDF).
- **Total strip:** grand total, page count, report language.
- **Pages** at full width. Swipe moves exactly one page; arrows and "1 / 4" sit below. Tap a page to open it full-screen with zoom.
- **Footer:** Share draft · Issue quote.

### Set up sheet

Report language · which rooms · which photos, drawings and notes · which saved 3D views · a notes field · **Done**. Language changes re-render the pages at once.

### What the PDF contains

| Page | Content |
| --- | --- |
| 1 | Header, builder and customer, project and location, first room: plan, dimensions, floor, perimeter, walls gross, openings, walls net, each opening, volume |
| next | Further rooms, two per page |
| next | Photos and drawings with captions; then notes with their checklists |
| last | Saved 3D views, materials table, labour table, grand total, notes, signature lines |

- A draft carries a "DRAFT" watermark and the title "Estimate (draft)".
- Footnotes state that areas come from the room model, that quantities were entered by the builder, and the currency.
- Profile → PDF content switches off plans, dimensions, 3D views, the estimate or signatures.

### Issuing

- **Blocked** while any estimate row is missing a value: "Fill in 1 estimate row before issuing a quote."
- Otherwise a sheet confirms: "Geometry, views, rows, totals, currency, language and parties are frozen. Later changes become a new quote." It shows the total, the language and the builder.
- If the builder's details are missing, the sheet asks for them first.
- After issuing, the Quotes tab opens and a toast offers to move the job to "Quote sent" on the Board.

### Share **(simulated)**

A sheet with the file name and page count, and Telegram, WhatsApp, Save to Files, Print. The real app opens the phone's share sheet.

---

## 16. Issued quote

- **Reached:** project → Quotes tab → a quote; or Home's attention list.
- **Quotes tab:** newest first. Each row has the number, issue date and time, language, room count, total, and whether the current draft is the same or differs.
- **Quote page:** a lock banner ("This quote is frozen. To change it, edit the estimate and issue a new quote.") with the issue date; the total strip; the pages (title "Quote", "№1, 13.10.2026", no watermark); **Share PDF**.
- A quote keeps the geometry and prices it was issued with, whatever changes later.

---

## 17. Measure

- **Purpose:** measure without opening a project, and do quick sums.
- **Meter:** laser status, the reference edge ("from the rear edge"), the last reading in large digits, and a Single / Continuous switch.
- **Single:** the main button **Measure** takes a reading and saves it in one press.
- **Continuous:** Start/Stop; the meter follows the laser; the main button becomes **Save**.
- **Type it** opens a sheet for a typed reading.
- **Calculator:** Area (length × width) · Wall (length × height, minus an optional opening) · Volume · Sum · Brick.
  - The box with the yellow frame is filled next: by a new reading, or by tapping a reading chip.
  - Tap a box to choose it. In Sum, tapping a value removes it.
  - An opening bigger than the wall shows a warning, never a negative area.
  - The calculator never touches the estimate.
- **Brick tool:** how many bricks and how much mortar one wall takes.
  - **Inputs:** length × height. "Take off a door or window" adds two more boxes for an opening; "Count without the opening" removes them.
  - **Wall thickness, in bricks:** ½ · 1 · 1,5 · 2, each showing its thickness in mm (120 · 250 · 380 · 510 for the default brick). The choice is remembered.
  - **Result:** bricks as a whole number, rounded up, with spare included; underneath, the mortar in m³ and the net wall face in m².
  - **Brick and joint:** one line shows the current values ("250×120×65, 10 mm joint, 5% spare") with **Change**. The sheet has two preset sizes (250×120×65 and 250×120×88), three size fields, joint thickness and spare. Each field accepts a whole number in its range (length 100 to 600 mm, width 50 to 400, height 30 to 300, joint 0 to 30 mm, spare 0 to 30%) and shows the range when the value is outside it.
  - **How it is worked out:** bricks per m² = half-bricks of thickness ÷ ((brick length + joint) × (brick height + joint)); mortar = wall face × thickness, minus the bricks' own volume. Spare is added to the bricks only.
  - It is a stand-alone answer. Nothing is written to the estimate, and it needs no project.
- **Readings:** recent ones as chips (those in use are highlighted). **List** shows all, each with **Send** and **Delete**.
- **Send** asks "Which dimension?" and lists the rooms' dimensions. The value arrives in that room as Received and must be confirmed there.
- **Laser not connected:** a warning in the meter and the main button becomes **Connect laser**. Typing still works.

---

## 18. Board

- **Purpose:** where each job stands and what to do next. It stays on this phone and the customer never sees it.
- **Stage strip:** Measuring · Estimating · Quote · Work · Done, each with its count. Tap to jump. Empty stages are dimmed.
- **One list per stage.** Each row shows the job, customer and address, and the next open task with its progress ("0/3"). Tick the task there; a toast offers Undo.
- **Next stage** in one tap (To estimate · To quote · Start work · Finish), with Undo.
- **Quote rows** show the total and "Quote sent today" or "Waiting for reply: 3 days" (highlighted from day 2), and a Call button if a phone is set.
- **Done** folds into one row with Show/Hide.
- **Job detail:** stage chips (any stage, forward or back) · tasks with progress, tick and add · notes with time, add · Open project.
- **Empty state:** "The board is empty. A new project appears here at Measuring."

---

## 19. Profile and settings

- **Header:** avatar, name, phone, edit. A line says "This name and phone appear on every quote."
- **Three status tiles,** each opening its fix:

| Tile | Normal | Warning (amber, with icon) |
| --- | --- | --- |
| Laser | Connected | Not connected · Bluetooth off · No access |
| Backup | Today · N days ago | Not yet (when projects exist) · 7 days or more |
| Subscription | Active | Expired |

- **Language and report:** app language · default report language · PDF content · currency and precision.
- **Measuring and drawing:** default door and window sizes · 45°/90° snapping.
- **Account:** sign in, or the signed-in account with Sign out.
- **More settings:** units (metres) · room label (name and area, name, area, none) · show tips again · device · backup · subscription · about.

### Builder details

Name (required) and phone. They appear on every quote from then on. Issued quotes keep what they had.

### Backup and restore **(simulated files)**

- **Create backup** writes all projects, quotes and views to one file and shows when the last one was made.
- **Restore** validates the whole file first.
  - A damaged file: "The file is damaged or incomplete. Current data did not change."
  - A good file: "The file has 2 projects. 1 is also on this phone." with a choice for duplicates: Keep both · Replace · Skip. Keeping both adds "(2)" to the name.

### Subscription

Status, what keeps working after expiry, and what needs a subscription. Purchasing is outside this release.

### Device sheet

Status · **Search** → "Searching…" → found devices → **Connect** / Disconnect. It states that typing always works. **(Only the simulator is available.)**

---

## 20. Shared sheets and system states

| Item | Behaviour |
| --- | --- |
| Toast | One line, optional action (Undo). Shows for about 5 seconds. It never covers the page's main button |
| Banner | Inline warning with an icon, text and at most one action |
| Subscription needed | "Creating and editing projects and estimates needs a subscription. Your saved work stays open." |
| Rename | One field, Save |
| Move | A list of the project's other workspaces |
| Keyboard | Numbers: digits, comma, point, minus, backspace, previous/next field, Hide, Done. Text: letters with shift and a number layer. The real app uses the system keyboard, with the decimal pad for numbers |

### What the prototype simulates

Laser readings · SMS codes · Google sign-in · the camera · GPS coordinates · the map · sharing and printing · backup files · subscription state. Each is labelled in the interface.

### Data the app keeps

- **Settings:** language, default report language, builder (name, phone), currency, precision, door and window defaults, snapping, room label, PDF content, hidden tips, last backup time.
- **Project:** name, customer, phone, address, location, currency, precision, report language; workspaces; rooms; estimate; report choices and notes; quotes; board (stage, tasks, notes).
- **Workspace:** name, type, items (photos, drawings, notes).
- **Room:** name, workspace, shape, wall thickness, dimensions (each with value, source and any pending value), openings, saved 3D views.
- **Quote:** number, time, the frozen copy, total.
- **Readings:** value, time, source, where it was sent.
