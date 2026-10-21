# METRX for furniture makers — plan

Status: plan agreed with the founder on 17 October 2026 (32 decisions, listed at the end). Nothing is built yet.
The work starts with a clickable design for approval (section 11, step D).

METRX today serves house builders: measure rooms, see them in 3D, write the estimate, issue a PDF quote. This plan
adds a second industry, **furniture makers for homes** (kitchens, wardrobes, living room and bedroom furniture), in
the same app. Builders keep everything they have; nothing in their screens changes.

---

## 1. Who it is for

**A workshop maker.** One person or a small workshop that goes to the customer's flat, measures the room, designs the
furniture with the customer, quotes a price, takes a prepayment, cuts the boards (or orders cutting at a saw shop),
assembles and installs.

What they need from METRX, in their order:

1. Measure the room once, including what furniture must avoid: sockets, switches, water, sewer and gas pipes.
2. Design a kitchen or wardrobe that fits those measurements, quickly, on the phone, with the customer watching.
3. Show the customer a 3D picture with doors that open, and a price.
4. Know the real cost and the profit before agreeing the price.
5. Get a cut list and sheet layout for production, and a hardware list for buying.
6. Track the order from measuring to the final payment.

---

## 2. The journey

```
Sign in / Continue without account
        │
        ▼
Industry picker ── Builder ──────────► today's app, unchanged
        │
        └── Furniture maker
                │
                ▼
Home: New order · recent orders · money owed
        │
        ▼
New order (customer, phone, address) ─► stage: Measuring
        │
        ▼
Workspace → Room plan (existing editor) + site details (sockets, switches, pipes)
        │
        ▼
Add furniture: Kitchen │ Wardrobe │ (Stage 2: Living room, Bedroom/other)
        │
        ▼
Designer for that type (2D front views + 3D) ─► stage: Design
        │
        ▼
Price: cost from the cut list ▸ customer price (margin % / per running metre / fixed) ▸ profit
        │
        ├─► Customer PDF (3D, fronts with sizes, materials, price, prepayment) ─► Quote №n ─► stage: Quote sent
        │
        └─► Workshop pack (cut list, sheet layouts, hardware, part sizes, cost) — maker only
                │
Approved + prepayment ─► In production ─► Installed ─► Paid in full
```

---

## 3. Industry picker

**When:** right after the sign-in screens: after "Hisob yaratish", "Kirish", Google, and after "Hisobsiz davom
etish", before Home. It shows once. After that it is changed in Profile → **Soha** (industry).

**Screen:** title "Qaysi soha bo'yicha ishlaysiz?" and a short line under it ("Ilova shu sohaga moslashadi, keyin
Profilda o'zgartirish mumkin"). Two large glass cards to choose from:

| Card | Text | Picture |
|---|---|---|
| **Quruvchi** (Builder) | Xona o'lchash, 3D, smeta va PDF hisobot | room plan line drawing |
| **Mebelchi** (Furniture maker) | Oshxona, shkaf va mebel loyihasi, raskroy, narx | kitchen front line drawing |

Below them, greyed **"Tez kunda"** (coming soon) cards that can't be selected: Kafelchi (tiler), Elektrik,
Santexnik, Deraza-eshik o'rnatuvchi. Tapping one shows a toast "Tez kunda qo'shiladi". We count these taps locally
for later.

**Rules**
- The choice is stored in settings (`industry = build | furniture`).
- Every project stores its own type when it is created (`Project.industry`). Switching industry **never changes or
  deletes** a project.
- The Projects list shows the current industry's projects. A chip row adds "Boshqa sohalar (n)" when the other type
  has projects, so nothing ever disappears.
- One METRX Pro unlocks every industry. Everything stays unlocked for now, as today.
- Empty, error and offline states don't apply: the picker works offline and has no error state.

---

## 4. What changes in the shared screens for a furniture maker

| Screen | Builder (unchanged) | Furniture maker |
|---|---|---|
| Home | greeting, big card, two small | greeting; **Yangi buyurtma** (new order); recent orders with their stage; **money owed** (sum of remaining payments) |
| Projects list | projects | orders; card shows stage and remaining amount ("Qoldi: 6 500 000") |
| Project tabs | Workspaces · Smeta · Quotes · Details | Workspaces · **Narx** (price) · Quotes · Details (+ payments) |
| Stages | measure → estimate → quote → work → done | measure → design → quote → approved → production → installed → paid |
| Measure page | laser, readings, 5 calculators (incl. bricks) | laser, readings, area, net wall, volume, sum; **bricks hidden**; **Listlar** (sheets needed) calculator added |
| Room editor | as today | as today + **site details** (section 5) |
| Profile | as today | + **Soha**, **Ustaxona sozlamalari** (workshop settings), **Materiallar**, **Furnitura** (hardware) |
| Units | m or cm | furniture screens always in **mm**; room measuring keeps the user's unit |

**Payments (furniture orders only):** in Details, "To'lovlar": add a payment (amount, date, note, "oldindan
to'lov" for prepayment). The order shows paid, remaining and the stage. "Tasdiqlandi" (approved) asks for the
prepayment amount (default 50 %, editable). "To'liq to'landi" (paid in full) is set automatically when the remaining
amount reaches 0.

---

## 5. Site details in the room editor (furniture orders only)

New marks on a wall, placed in the wall view (the existing "one wall seen from inside" page) by tapping "+ Nuqta":

| Type | Symbol | Data |
|---|---|---|
| Rozetka (socket), single/double | ⊡ | wall, offset from the left corner, height from the floor (mm) |
| Viklyuchatel (switch) | ⊙ | same |
| Suv (water: cold/hot) | ● blue / red | same + pipe diameter (optional) |
| Kanalizatsiya (sewer) | ● grey | same, diameter 50/110 |
| Gaz (gas pipe, gas meter) | ● yellow | same; meter has width × height |

- They are drawn on the plan (small symbols at the wall), in the wall view (to scale) and in 3D (small markers).
- The laser can fill the offset and the height, as for openings; values wait for confirmation in the same way.
- **Fit checks** in the designers use them: a cabinet side or a back panel over a socket gives a warning ("Rozetka
  shkaf orqasida qoladi", the socket ends up behind the cabinet); a sink far from water or sewer (> 1 m) gives a
  warning; a hob next to the gas pipe gets an OK badge; a cabinet over the gas meter is blocked.
- Builders don't see these marks (founder's choice, Q30).

---

## 6. The shared furniture core

Every designer, whatever its screens, produces the same thing: a list of **modules** made of **parts**. One core
turns that list into the 3D boxes, the cut list, the sheet layout, the hardware list, the cost and the PDFs. That is
why kitchens, wardrobes and later types can never disagree on numbers, and why each new type costs less.

### 6.1 Data (stored inside the project file, like rooms and notes)

```
Furniture            id, kind (kitchen | wardrobe | living | bedroom | ...), name, roomId, wallIds,
                     materials (carcass, fronts, back, worktop: material ids), modules[], extras[]
Module               id, type (base | wall | tall | corner | sink | drawer | housing | wardrobeSection | ...),
                     x (mm along the run), width, height, depth, elevation (mm above floor),
                     fronts[], inserts[], options (legs/plinth, handle type, soft-close)
Front                kind (door | drawer | flap | open | applianceFront), split (count, heights), hinge side
Insert               kind (shelf | fixedShelf | rail | drawer | trouserRack | shoeRack | lift), position (mm), qty
Extra                worktop segments, backsplash, plinth, cornice, LED strip, fillers, end panels
Appliance            kind (sink, hob, oven, dishwasher, fridge, hood, microwave), size, built-in or free-standing
```

### 6.2 Construction rules (Profile → Ustaxona sozlamalari)

One standard construction with a few settings. They are set once and used in every order. Every number is a default
for the founder's makers to check (section 12).

| Setting | Default |
|---|---|
| Carcass board | LDSP 16 mm (choice 16 / 18) |
| Sides | stand on the bottom panel; top panel between the sides (base cabinets: two 100 mm rails instead of a top) |
| Back | HDF 3.2 mm, nailed on (choice: in a groove) |
| Base support | adjustable legs 100 mm + plinth (choice: plinth on the carcass) |
| Gap between fronts | 3 mm; 1.5 mm at the outer edges |
| Edge banding | visible edges 2 mm PVC; hidden edges 0.4 mm; back edges none |
| Fronts | LDSP 16 mm or MDF 18 mm (from materials) |

### 6.3 Parts generator

For each module the core makes its parts with exact sizes. Example, a base cabinet 600 × 720 × 560, LDSP 16:

| Part | Size (mm) | Qty | Banding |
|---|---|---|---|
| Bottom (sides stand on it) | 600 × 560 | 1 | front edge 2 mm |
| Side | 704 × 560 | 2 | front edge 2 mm |
| Rail (between the sides) | 568 × 100 | 2 | front edge 0.4 mm |
| Shelf (2 mm play) | 566 × 540 | 1 | front edge 2 mm |
| Back (HDF, 2 mm in from each edge) | 716 × 596 | 1 | — |
| Door (gaps 3 mm between, 1.5 mm outside) | 717 × 297 | 2 | all edges 2 mm |

The rules live in one place per module type and are covered by unit tests with fixed expected sizes. Android and
iPhone run the same test cases from one shared JSON file, so both apps produce identical cut lists.

### 6.4 Cut list

- Every part gets: number, name, module, length × width (length along the grain), thickness, material, quantity,
  banding per edge (drawn as a small rectangle with marked edges).
- Grouped by material, with a total area per material and total banding length per type (plus 30 mm per banded edge
  for trimming).
- Parts marked "grain matters" (fronts and visible sides with a wood décor) keep their direction in the sheet layout.

### 6.5 Sheet layout (раскрой)

- Inputs per material: sheet size (LDSP 2800 × 2070), saw kerf 4 mm, edge trim 10 mm per side, grain on/off.
- A guillotine cut layout (straight saw cuts from edge to edge, as on panel saws) fills each sheet, biggest parts
  first, and tries both orientations where the grain allows.
- Output: number of sheets to buy per material, a drawing of each sheet with numbered parts, waste %, and the
  offcuts larger than 300 × 300 mm.
- Speed target: a full kitchen (about 150 parts) is laid out in under 1 s on a mid-range phone, worked out in the
  background.
- The layout doesn't have to be optimal. It has to be correct (nothing overlaps, kerf and trim respected) and good
  enough that a maker accepts the sheet count. Makers compare it with their saw shop's result (section 12).

### 6.6 Hardware counting (Profile → Furnitura holds names and prices)

| Item | Rule (default) |
|---|---|
| Hinges | per door by height: ≤ 900 → 2, ≤ 1600 → 3, ≤ 2000 → 4, more → 5; soft-close if the module says so |
| Drawer runners | 1 pair per drawer, length = cabinet depth rounded down to 50 mm (300–600) |
| Handles | 1 per door/drawer (unless push-open) |
| Legs | 4 per base or tall module; 6 when wider than 900 mm |
| Shelf pins | 4 per adjustable shelf |
| Rails | 1 per rail insert, length = inner width; 2 rail holders |
| Confirmat screws | 4 per carcass joint |
| Wall hangers | 2 per wall cabinet; mounting rail = total wall-run length |
| Sliding system (Stage 1b) | top + bottom profile = wardrobe width; 1 roller set per door; vertical profiles 2 per door |
| Lift mechanism | 1 per flap front |

The app ships presets (hinge, soft-close hinge, runners 300–600, handle, leg, shelf pin, rail, confirmat, hanger,
lift, sliding set). The maker renames them to their brand (Blum, Hettich, GTV, Boyard or other) and sets prices once.

### 6.7 Cost and price

**Cost (always computed, maker only):**
```
sheets to buy × sheet price          (per material, from the sheet layout)
+ banding metres × price per metre   (per banding type)
+ hardware count × price
+ worktop (running metres or m² × price), backsplash, plinth...
+ appliances only if the maker supplies them (otherwise "customer supplies")
+ labour lines: cutting per sheet, banding per metre, assembly per module, delivery, installation (rates in Profile)
```

**Customer price, chosen per order:**
1. cost + margin % (default 30 %);
2. per running metre: base-run metres × rate + wall-run metres × rate (+ tall units per piece), for kitchens;
3. a fixed price typed by hand.

The Narx (price) tab shows cost, customer price and **profit** (amount and %), and turns red when the profit is
negative. The customer PDF shows only the customer price. Money uses the existing exact `Money` code (whole sums,
rounded half up).

---

## 7. Kitchen designer

**Layouts:** straight, L-shaped, U-shaped, island and peninsula. The maker picks the layout, then the walls of the
measured room it runs along. The run lengths come from the confirmed wall measurements, minus the openings and
blocked zones.

**Screen layout (phone portrait):**
```
┌─────────────────────────────┐
│ ‹ Oshxona 1         2D │ 3D │  ← top bar, undo/redo
├─────────────────────────────┤
│  wall A front view, to scale │  ← swipe between walls; plan strip shows which wall
│  [wall cabinets row]         │
│  [worktop line]              │
│  [base cabinets row]         │
│  sockets/pipes shown as marks│
├─────────────────────────────┤
│ Run: 3 260 mm · free 140 mm  │  ← what is left to fill, red when over
│ [+ Modul] [Texnika] [Bo'shliq]│
└─────────────────────────────┘
```

- **Modules** come from a library with standard sizes, editable in mm:
  - base: 300–1000 wide, drawer base, sink base 600/800, corner base (blind or L);
  - wall: 300–1000 wide, 720 or 900 high, corner wall, hood cabinet;
  - tall: pantry, oven housing, fridge housing (600 wide, up to 2100).
- **Appliances** with standard sizes: sink, hob 600, oven 600, dishwasher 450/600, fridge (free-standing or built-in),
  hood 600/900, microwave. Built-in ones get a housing module or a gap of the right size.
- **Editing:** tap a module to open its sheet (width, fronts, inside, handle, soft-close). Drag a module to move it
  along the run; neighbours shift. "Fill the gap" offers a filler or a resized module.
- **Fit checks:** the run is too long; a module covers a socket or pipe; the sink is far from water or sewer; a wall
  cabinet hits a window; the hood is too low over the hob (< 650 mm electric, < 750 mm gas).
- **Worktop:**
  - Stage 1a: one simple item, total length × depth × thickness (600 × 38 by default), priced per running metre
    or m².
  - Stage 1b: segments with joints at corners (45° or butt), cut-outs for sink and hob with their sizes, edge
    finishing.
- **Stage 1b extras:** backsplash panel (between base and wall rows; size and material), plinth (total length,
  corners), cornice, LED strip under wall cabinets (length + power supply), end panels.

## 8. Wardrobe designer

Steps, in the way of the qdesign video:

1. **Joy** (place): pick the wall, or a niche between two walls. Width and height come from the measurements, minus
   the gaps (default 10 mm per side, 20 mm at the top).
2. **O'lchamlar** (sizes): overall width × height × depth; built-in (no sides at the walls) or free-standing; number
   of sections and their widths (equal by default; each can be locked); plinth or legs.
3. **Eshiklar** (doors), per section:
   - Stage 1a: hinged (1–2 doors, handle or push-open) or open;
   - Stage 1b: sliding (купе) over the whole wardrobe, 2–4 doors with LDSP, mirror or glass panels; the
     profile set goes into the hardware list.
4. **Ichki qism** (filling), per section in the 2D front view: shelves, drawers, rails, trouser rack, shoe rack and
   lift; each placed at a height in mm, with "evenly" for shelves. The panel shows the selected section's settings
   (count, type, height), as in the video.
5. **Material:** carcass, fronts, back, from the maker's list.

The result is shown in 2D (front view with sizes, doors closed or open) and in 3D.

## 9. Furniture 3D

- It reuses the existing 3D page and engine: SceneView/Filament on Android, RealityKit on iPhone. Every part is a box
  in its material's colour, placed in the measured room (walls cut away as today).
- Tap a door to swing it open (hinged, about 100°) or slide it; tap a drawer to pull it out. "Hammasini ochish"
  (open all) and "Yopish" (close) buttons.
- Saved views go to the customer PDF (up to 4, as today).
- Site details appear as small markers.
- Stage 3 brings wood and stone textures and lighting. Until then, colours are plain, as agreed (Q16).

## 10. Documents

**Customer PDF** (A4, the existing report pages):
1. Header, parties (maker, customer), order number.
2. 3D views.
3. Front drawings per wall or per wardrobe, with the main sizes.
4. Materials and colours: carcass, fronts, worktop and handles, as colour swatches with their names.
5. Price: customer total, prepayment, remaining, delivery and installation time.

The customer PDF never contains costs, the cut list or profit. It has no warranty or signatures section (Q26).
Issuing it freezes **Quote №n**, as the builder's quotes do today.

**Workshop pack** (a separate PDF, only from the Narx tab; its button is labelled "Ustaxona uchun" so it can't be
mistaken for the customer's):
1. Order summary, materials and their sheet counts.
2. Cut list by material (section 6.4).
3. Sheet layout drawings, one per sheet, with numbered parts.
4. Hardware list with counts.
5. Part sizes per module (small drawings with banded edges marked).
6. Cost, customer price and profit.

## 11. Stages and parts

Each part is built on Android first, checked on the emulator, then stopped for the founder's OK. The iPhone port of
the same part follows and goes through CI, as with parts 1–7.

| Step | What | Done when |
|---|---|---|
| **D** Design | Clickable design in the glass look: industry picker, site details, kitchen designer, wardrobe designer, Narx tab, both PDFs. The makers review it | Founder approves; makers have commented on sizes and words |
| **1a-1** Industry | Picker, Project.industry, list filter, furniture Home, stages + payments, Measure page tools | Pick → furniture Home → new order; switching keeps all projects |
| **1a-2** Site details | Sockets, switches, water, sewer, gas in wall view, plan and 3D; laser input | Marks saved, drawn to scale, confirmed like other measurements |
| **1a-3** Core | Data model, construction settings, materials and hardware lists, parts generator, cut list, sheet layout, hardware count, cost; unit tests | Golden test cases pass on both apps; sheet layout checked against a maker's real order |
| **1a-4** Kitchen | Layouts, runs, module library, appliances, simple worktop, fit checks, 2D front views | A real L-kitchen designed from a measured room in < 10 min |
| **1a-5** Wardrobe | Steps 1–5 with hinged and open doors, filling | The video's 4-section wardrobe rebuilt to the mm |
| **1a-6** 3D | Furniture boxes in the room, opening doors and drawers, saved views | Kitchen and wardrobe shown, doors open |
| **1a-7** Price + documents | Narx tab, three price modes, profit, customer PDF, workshop pack, quotes | Full order: measure → design → PDF → prepayment → paid |
| **1b-1** Kitchen extras | Worktop joints and cut-outs, backsplash, plinth, cornice, LED, end panels | All in the cut list, hardware list and price |
| **1b-2** Sliding doors | купе system, panel types, profile lengths | Profile and panel sizes match a maker's order |
| **2** More types | Living room (TV unit, shelving, sideboard), bedroom and other (dresser, nightstand, vanity, hallway, desk), as new designers on the same core | Each type: design → cut list → PDF |
| **3** Realistic 3D | Wood and stone textures, lighting | Customer-ready pictures |

Grilling continues before Stage 2: which living room and bedroom pieces, and their own options.

## 12. Defaults to check with the founder's furniture makers

Every one of these is an assumption until a maker confirms it. They are changeable in Profile.

| What | Default |
|---|---|
| Sheet size LDSP / MDF / HDF | 2800 × 2070 mm |
| Saw kerf, edge trim | 4 mm, 10 mm per side |
| Carcass board | LDSP 16 mm |
| Base cabinet | 720 high (carcass) × 560 deep, legs 100, worktop 38 → worktop height 858 |
| Wall cabinet | 720 high × 300 deep, bottom 600 above the worktop |
| Tall unit | up to 2100 high × 560 deep |
| Front gap | 3 mm (1.5 at the outer edges) |
| Banding | 2 mm visible, 0.4 mm hidden |
| Worktop | 600 deep × 38 mm, sheet 3000 / 4100 long |
| Hood above hob | ≥ 650 mm electric, ≥ 750 mm gas |
| Hinges per door | 2 / 3 / 4 / 5 by height (section 6.6) |
| Margin | 30 % |
| Prepayment | 50 % |
| Trade words | the list in section 13 |

## 13. Words (draft, Uzbek Latin; Cyrillic and Russian follow; makers review)

The trade's own words, as makers use them:

| Meaning | uz (Latin) | ru |
|---|---|---|
| Furniture maker | Mebelchi | Мебельщик |
| Order | Buyurtma | Заказ |
| Chipboard (laminated) | LDSP | ЛДСП |
| Edge banding | Kromka | Кромка |
| Front (door/drawer face) | Fasad | Фасад |
| Worktop | Stoleshnitsa | Столешница |
| Plinth | Tsokol | Цоколь |
| Backsplash | Fartuk | Фартук |
| Carcass | Korpus | Корпус |
| Hardware | Furnitura | Фурнитура |
| Cut list | Detallar ro'yxati | Список деталей |
| Sheet layout | Raskroy | Раскрой |
| Running metre | Pogon metr | Погонный метр |
| Sliding wardrobe | Kupe shkaf | Шкаф-купе |
| Workshop pack | Ustaxona uchun | Для цеха |
| Prepayment | Oldindan to'lov | Предоплата |

All new texts go into `strings.json` under the `fu.` prefix, in all four languages, as drafts for review.

## 14. Where it goes in the code

Both apps get the same structure. As with `Shell3D`, the core is written once in Kotlin, ported 1:1 to Swift and
checked with the same test cases.

**Changed files**

| Area | Android (`android-native/app/src/main/java/uz/metrx/app/`) | iPhone (`ios-native/METRX/`) |
|---|---|---|
| Industry + workshop settings, materials, hardware | `core/Settings.kt` | `Core/Settings.swift` |
| Project.industry, payments, stages; Room site points; Workspace furniture | `data/Model.kt`, `data/Store.kt` | `Data/Model.swift`, `Data/Store.swift` |
| Picker after sign-in | `ui/auth/AuthScreens.kt` (+ new `ui/auth/IndustryScreen.kt`) | `Auth/AuthScreens.swift` (+ `Auth/IndustryScreen.swift`) |
| Furniture Home, Projects filter, stages | `ui/main/MainScreens.kt`, `ui/projects/ProjectsScreens.kt`, `ui/projects/ProjectScreen.kt` | `Main/MainScreens.swift`, `Projects/ProjectsList.swift`, `Projects/ProjectScreen.swift` |
| Site details in the wall view and plan | `ui/editor/WallView.kt`, `ui/editor/PlanCanvas.kt`, `ui/editor/EditorSheets.kt` | `Editor/WallView.swift`, `Editor/RectPlan.swift`, `Editor/EditorSheets.swift` |
| Measure page tools | `ui/measure/MeasureScreen.kt`, `core/Calc.kt` | `Measure/MeasureScreen.swift`, `Core/Calc.swift` |
| Profile sections | `ui/main/ProfileScreens.kt` | `Main/Profile.swift` |
| "Furniture" in the workspace add sheet | `ui/projects/SpaceScreens.kt`, `ui/projects/ProjectSheets.kt` | `Projects/SpaceScreens.swift`, `Projects/ProjectSheets.swift` |
| Texts | `assets/strings.json` (shared by both apps) | — |

**New files**

| What | Android | iPhone |
|---|---|---|
| Core: model, parts, cut list, sheet layout, hardware, cost | `furniture/FModel.kt`, `Parts.kt`, `CutList.kt`, `SheetLayout.kt`, `Hardware.kt`, `Costing.kt` | `Furniture/Core/*.swift` (same names) |
| Kitchen designer | `ui/furniture/KitchenScreen.kt`, `KitchenSheets.kt` | `Furniture/KitchenScreen.swift`, `KitchenSheets.swift` |
| Wardrobe designer | `ui/furniture/WardrobeScreen.kt` | `Furniture/WardrobeScreen.swift` |
| 2D front view (shared by both designers) | `ui/furniture/Elevation.kt` | `Furniture/Elevation.swift` |
| Narx tab | `ui/furniture/PriceTab.kt` | `Furniture/PriceTab.swift` |
| 3D furniture | `ui/three/Furniture3D.kt` (on `Scene3D`) | `Three/Furniture3D.swift` |
| Customer PDF + workshop pack | `report/FurniturePages.kt`, `report/WorkshopPages.kt` | `Report/FurniturePages.swift`, `Report/WorkshopPages.swift` |
| Tests | `test/.../furniture/*Test.kt` + `furniture-cases.json` | `METRXTests/Furniture*Tests.swift` (same JSON) |

**Compatibility:** older project files have no `industry` and are read as builder projects. New fields are optional,
so the builder side and existing data need no changes.

## 15. Risks and how we handle them

| Risk | Handling |
|---|---|
| Sheet layout not good enough for makers | Compare with a real saw shop order in 1a-3; show waste %; the layout is replaceable later |
| Design work on a phone feels slow | Module library with standard sizes, "fill the gap", sizes typed with the number pad; target: L-kitchen in < 10 min |
| Construction differs between workshops | Settings in Profile; makers check the defaults before 1a-3 |
| Four designers is a lot of screens | Shared core, shared 2D front view and 3D; staged delivery |
| Trade words wrong | Makers review during step D |
| Android and iPhone give different numbers | Same test JSON on both; the core is ported 1:1 |

## 16. Decisions (17 October 2026)

| # | Decision |
|---|---|
| 1 | First user: workshop maker (measures, designs, quotes, cuts, installs) |
| 2 | One app, one industry per user, switchable in Profile |
| 3 | Furniture types: kitchen, wardrobe, living room, bedroom/other |
| 4 | Outputs: priced quote + PDF, 3D for the customer, cut list, hardware list |
| 5 | Picker: Builder + Furniture maker, plus greyed "coming soon" trades |
| 6, 9 | A separate designer per type, with one shared calculation core |
| 7 | Measuring reuses the room editor, plus site details |
| 8, 25 | Staged: 1a, 1b, 2, 3 |
| 10 | Materials: the maker's own list on top of built-in presets |
| 11, 13 | Cost always computed; customer price by margin, per running metre or fixed; profit shown to the maker only |
| 12 | Cut list in PDF + sheet layout (раскрой); no export file or drilling yet |
| 14 | Standard construction with a few workshop settings |
| 15 | Kitchen layouts: straight, L, U, island/peninsula |
| 16 | 3D: plain colours first, textures later |
| 17 | Order stages with prepayment and remaining amount |
| 18, 21 | Kitchen: appliances, worktop with joints and cut-outs, backsplash, plinth, cornice, LED (extras in 1b) |
| 19 | Wardrobe: hinged, sliding (купе), open, all inside filling |
| 20 | Hardware: own list on top of presets |
| 22 | Projects keep their industry; the list filters by the current one |
| 23 | Same layout for Home and the Measure page, with furniture tools |
| 24, 30 | Site details: sockets, switches, water, sewer, gas; furniture orders only |
| 26 | Customer PDF: 3D views, front drawings, materials and colours, price and payment terms |
| 27 | A separate workshop pack, never offered to the customer |
| 28 | Uzbek with the trade's own terms |
| 29 | Design first, then Android in parts, then iPhone |
| 31 | One METRX Pro for all industries |
| 32 | The founder's furniture makers review the defaults and wording |
