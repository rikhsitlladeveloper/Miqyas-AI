# Miqyas AI — Functional Requirements

Version 1.0 · 2026-10-12

Every function of the Miqyas AI app and web panel, one by one, with what it does, the rules it follows and when it ships. Requirement IDs (F4.3 etc.) are used in Notion tasks, GitHub issues and tests.

## Overview

14 modules across three releases. v1 is a working measuring tool for one person; v2 turns it into a sales tool for companies; v3 adds the AI features that save the most money.

**Users**

- **Measurer (o‘lchovchi)** — visits the client, measures rooms, makes the quote. Uses the phone app.
- **Owner / manager** — assigns visits, sets prices, checks staff and orders. Uses the web panel and the app.
- **Workshop (ustaxona)** — receives orders and cut lists. Read-only link or web panel.
- **Client (mijoz)** — receives the plan and quote in Telegram, signs on the measurer's phone or by link.

| ID | Module | Main user | Release |
| --- | --- | --- | --- |
| F1 | Accounts, company and roles | Owner | v2 (v1: no login) |
| F2 | Bluetooth laser device | Measurer | v1 |
| F3 | Visits, clients and projects | Measurer, owner | v1 basic, v2 visits |
| F4 | Room editor and laser measuring | Measurer | v1 |
| F5 | Calculations and AI geometry check | Measurer | v1 calc, v2 check |
| F6 | AI capture: voice, photo, LiDAR, old plan | Measurer | v2 voice, v3 rest |
| F7 | Hidden wires and pipes map | Installer, developer | v3 |
| F8 | Material optimizer | Measurer, client | v2 |
| F9 | Price list, quote and signature | Measurer, owner | v2 |
| F10 | Export and sharing | Measurer | v1 |
| F11 | Workshop orders and AI order check | Owner, workshop | v2 order, v3 AI check |
| F12 | Owner web dashboard | Owner | v2 |
| F13 | Subscription and payments | Owner | v2 |
| F14 | Settings, languages, offline, sync, notifications | All | v1 offline, v2 sync |

## F1 · Accounts, company and roles

One company account holds measurers, prices and projects; each person signs in with a phone number.

- **F1.1 Sign-in by phone** — Uzbek phone number + SMS code. No passwords. Session stays logged in on the device.
- **F1.2 Solo mode** — a person can use the app without a company (solo plan). All data is theirs.
- **F1.3 Create company** — name, logo, INN (STIR), address, phone. The creator becomes Owner.
- **F1.4 Invite staff** — owner sends an invite link or adds a phone number; the person joins on next sign-in.
- **F1.5 Roles**
  - Owner: everything, including prices, billing, deleting projects.
  - Manager: assign visits, see all projects, edit quotes, send orders.
  - Measurer: own visits and projects only; can make quotes from the company price list; cannot change prices.
  - Workshop: sees orders sent to it; cannot see client phone numbers.
- **F1.6 Remove staff** — removed user loses access at once; their projects stay with the company.
- **F1.7 Audit log** — who created, edited, sent or deleted a project or quote, with time.

**Done when:** an owner can create a company, invite 2 measurers, and each measurer sees only their own projects.

## F2 · Bluetooth laser device

The app works with our own-brand laser and with popular models, and never loses a reading.

- **F2.1 Scan** — list nearby Bluetooth devices; supported models on top with name and signal strength; unknown devices under "Boshqa" (Other) to try.
- **F2.2 Connect and remember** — one tap to connect; the device is saved as default and reconnects automatically when the app opens.
- **F2.3 Status** — connection dot (grey / blue connecting / green), battery %, last reading, visible on every measuring screen.
- **F2.4 Receive reading** — each laser shot arrives as one measurement in metres, regardless of the unit set on the device.
- **F2.5 Remote trigger** — if the device supports it, the app's Laser button fires the laser.
- **F2.6 Angle** — if the device has a tilt sensor, the angle is received with the reading.
- **F2.7 Auto-reconnect** — after a drop, retry for 30 s; then show a Reconnect button.
- **F2.8 Duplicate filter** — ignore identical packets within 300 ms.
- **F2.9 Diagnostics** — last 200 raw packets viewable and shareable, to add support for new models.
- **F2.10 Supported models list** — v1: our device; v2: + Mileseey, Bosch GLM C, Leica DISTO; list grows by driver.
- **F2.11 Battery warning** — notify at 15%; owner sees low batteries in the web panel.

**Done when:** a reading reaches the selected wall in under 1 s, and the device reconnects after walking out of range and back.

## F3 · Visits, clients and projects

A project is one address for one client; it holds rooms, quotes and orders.

- **F3.1 Create project** — client name, phone, address (with map pin), job type (kitchen, wardrobe, ceiling, windows, renovation, other), notes. Only address is required.
- **F3.2 Projects list** — sorted by visit date; search by client, phone, address; filter by status.
- **F3.3 Project status** — Yangi → O‘lchandi → Smeta yuborildi → Imzolandi → Buyurtmada → O‘rnatildi / Rad etildi. Changes automatically where possible.
- **F3.4 Rooms** — add, rename, reorder, duplicate, delete; each shows area and measurement status (drawn / partly / fully measured).
- **F3.5 Visits (v2)** — manager assigns project, measurer, date and time. Measurer sees today's visits with a route button (Yandex Maps / Google Maps).
- **F3.6 Call and Telegram** — one tap to call the client or open a Telegram chat.
- **F3.7 Photos and notes** — attach photos to project or room; voice notes transcribed to text.
- **F3.8 Client history** — one client can have several projects; repeat clients recognised by phone.
- **F3.9 Delete / archive** — measurers archive; only owner deletes. Deleted projects recoverable for 30 days.

**Done when:** a manager assigns 3 visits, the measurer sees them in order on the home screen and opens the route to the first.

## F4 · Room editor and laser measuring

The core screen: draw the room roughly, then the laser makes it exact. One hand, no paper.

- **F4.1 Draw walls** — tap corners on a grid; each tap adds a wall; tap the first corner to close the room.
- **F4.2 Snap** — angles snap to 90° and 45° within 7°; points snap to the 10 cm grid and to corners. Can be turned off.
- **F4.3 Room templates** — rectangle, L-shape, U-shape, corridor.
- **F4.4 Select a wall** — tap a wall; it highlights; its length field opens.
- **F4.5 Laser to wall** — a reading goes into the selected wall; the next wall is selected automatically.
- **F4.6 Type a length** — same effect as a laser reading.
- **F4.7 Rescale** — setting a length moves the end corner along the wall direction; following walls shift; the plan stays connected.
- **F4.8 Length source** — drawn (grey, "?"), typed, laser or voice; drawn lengths flagged in exports.
- **F4.9 Doors, windows, openings** — width, height, sill height, opening side, distance from corner (laser or typed).
- **F4.10 Ceiling height** — per room, default from settings, can be measured by laser; sloped ceilings in v3.
- **F4.11 Columns, niches, boxes (v2)** — adjust floor and wall areas.
- **F4.12 Diagonals (v2)** — fix real angles of non-square rooms.
- **F4.13 Undo / redo** — unlimited within the session.
- **F4.14 Zoom and pan** — pinch, two-finger pan, double-tap to fit.
- **F4.15 Multiple rooms in one plan (v2)** — shared walls snap together.
- **F4.16 Autosave** — every change saved locally at once.

**Done when:** a rectangular room with one door and one window is fully measured by laser in under 3 minutes.

## F5 · Calculations and AI geometry check

- **F5.1 Per room** — floor area, ceiling area, perimeter, wall area gross, openings area, wall area net, volume, skirting length, window slope length.
- **F5.2 Per project** — totals across rooms.
- **F5.3 Precision** — metres to 3 decimals; displayed to 2 (cm) or 3 (m).
- **F5.4 Closure check** — red badge if the outline does not close within 2 cm.
- **F5.5 Angle check (v2)** — flag corners off by more than 1° with the gap in mm at 3 m.
- **F5.6 Wall plumb check (v3)** — flag walls out of plumb by more than 5 mm/m.
- **F5.7 Room summary screen** — all numbers, wall list with source, openings, warnings.

**Done when:** areas match a hand-checked reference within 1% on 5 test rooms, including an L-shaped one.

## F6 · AI capture: voice, photo, LiDAR, old plan

Every AI result is shown for confirmation before it changes the plan.

- **F6.1 Voice input (v2)** — Uzbek or Russian commands ("o‘ng devor uch yuz qirq ikki"); recognised list; tap "Qo‘llash" to apply.
- **F6.2 Voice notes (v2)** — free speech saved as a text note.
- **F6.3 Photo to openings (v3)** — AI proposes doors, windows, sockets, radiators on a wall.
- **F6.4 LiDAR quick scan (v3, iPhone/iPad Pro)** — outline from a 30–60 s scan; laser replaces scanned lengths.
- **F6.5 Old plan import (v3)** — photo of a kadastr/BTI plan becomes editable rooms.
- **F6.6 Confidence** — low-confidence values stay grey ("?") until confirmed.

**Done when (voice):** 9 of 10 spoken wall lengths from 3 measurers are recognised correctly in a real apartment.

## F7 · Hidden wires and pipes map (v3)

- **F7.1 Wall elevation view** — length × ceiling height with openings.
- **F7.2 Draw routes** — electric, cold/hot water, heating, gas, sewage, internet; one colour per layer.
- **F7.3 Exact position by laser** — distance from floor and nearest corner.
- **F7.4 Points** — sockets, switches, boxes, taps, outlets with height.
- **F7.5 Photo evidence** — dated photos pinned; AI traces conduits/pipes to confirm.
- **F7.6 No-drill zones** — automatic bands (default 15 cm each side) in red hatch.
- **F7.7 Layer toggles**.
- **F7.8 House passport PDF** — all walls, routes, points and photos.
- **F7.9 AR view (v3+)** — routes over the camera image.

**Done when:** a finished wall's elevation shows every cable and pipe within 3 cm of the photographed position.

## F8 · Material optimizer (v2)

- **F8.1 Types** — wallpaper, tiles, laminate/parquet, plasterboard, ceiling film, paint, skirting, plaster/putty.
- **F8.2 Parameters** — roll width/length/pattern repeat; tile size and joint; plank size and direction; paint coverage and coats.
- **F8.3 Room and surface selection**.
- **F8.4 Cutting plan** — strips per wall around openings; tile/plank layout; film seams.
- **F8.5 Offcut reuse** — leftovers used in other rooms before opening a new unit.
- **F8.6 Result** — quantity per room and total in purchase units, waste %, comparison with area-based estimate.
- **F8.7 Cut list** — per roll/box: which piece goes where.
- **F8.8 Waste margin** — company default, editable.
- **F8.9 Send to quote**.

**Done when:** for 3 real apartments the roll count matches an experienced installer, or is lower with a valid cut plan.

## F9 · Price list, quote and signature (v2)

- **F9.1 Price list** — name, unit, price in so‘m, category, which measurement it uses.
- **F9.2 Import** — Excel, or AI reads a supplier PDF/photo.
- **F9.3 Auto-quote** — quantities from measurements, prices from the list.
- **F9.4 Edit lines** — add/remove/change (role permitting); free-text lines.
- **F9.5 Discounts and extras**.
- **F9.6 Currency** — so‘m; USD option with Central Bank rate.
- **F9.7 Number and validity** — auto-numbered; valid 7 days by default.
- **F9.8 Versions** — client always sees the latest.
- **F9.9 Signature** — finger on phone, or Telegram link + SMS code.
- **F9.10 Prepayment** — Payme / Click deposit from the quote link.
- **F9.11 Follow-up** — reminder after 3 days unsigned.

**Done when:** a priced quote for a measured 3-room apartment is made and sent in under 2 minutes and can be signed from Telegram.

## F10 · Export and sharing

- **F10.1 PDF plan** — A4 per room + project sheet, scale 1:50/1:100/fit, dimensions, symbols, areas, logo, client, date.
- **F10.2 PDF quote** — with signature and QR link.
- **F10.3 PNG** — quick preview.
- **F10.4 DXF** — walls, doors, windows, dimensions, room names on layers, metres.
- **F10.5 Excel / CSV**.
- **F10.6 JSON** — full project data.
- **F10.7 Share sheet** — Telegram first; prefilled caption.
- **F10.8 Client link (v2)** — view plan and quote in a browser.
- **F10.9 Warnings** — unmeasured lengths marked "?".

**Done when:** the DXF opens in AutoCAD and NanoCAD at correct scale, and the PDF reaches the client in Telegram in under 30 s.

## F11 · Workshop orders and AI order check

- **F11.1 Create order (v2)** — from a signed quote.
- **F11.2 Order sheets by trade (v2)** — kitchen/wardrobe; stretch ceiling; windows/doors.
- **F11.3 Send to workshop (v2)** — internal user or external link/PDF.
- **F11.4 Order status (v2)** — Yuborildi → Qabul qilindi → Ishlab chiqarishda → Tayyor → O‘rnatildi.
- **F11.5 AI order check (v3)** — modules that do not fit (mm), off-square corners, conflicts with sockets/pipes/no-drill zones, sill/radiator clashes, missing measurements.
- **F11.6 Fix suggestion (v3)** — e.g. "last module 600 → 570 mm".
- **F11.7 Block on critical errors (v3)** — manager override required.

**Done when:** a kitchen order with a 30 mm overrun is flagged before sending, with the correct fix.

## F12 · Owner web dashboard (v2)

- **F12.1 Overview** — measurements, m², quotes sent/signed, conversion, signed amount, AI-caught errors.
- **F12.2 Visit calendar** — by measurer; drag to reassign.
- **F12.3 Measurers** — visits, m², conversion, time per visit, re-measures.
- **F12.4 Projects and quotes**.
- **F12.5 Orders board**.
- **F12.6 Price list editor** — bulk change by %.
- **F12.7 Attention list** — unsigned quotes, order errors, low batteries, late visits.
- **F12.8 Reports** — Excel / PDF.
- **F12.9 Clients**.

**Done when:** the owner sees yesterday's work by every measurer and all unsigned quotes on one page.

## F13 · Subscription and payments (v2)

- **F13.1 Plans** — Free, Solo, Company. Prices: [NARX] — not decided.
- **F13.2 Device bundle activation** — code in the box gives a free Solo period.
- **F13.3 Payment** — Payme, Click, Uzcard/Humo; monthly or yearly.
- **F13.4 Invoices** — bank transfer invoice; e-faktura.
- **F13.5 Seats** — add/remove measurers.
- **F13.6 Grace period** — 7 days, then read-only.
- **F13.7 AI usage limits** — fair-use per seat.

**Done when:** a company pays with Click, adds a third measurer, and the seat works the same minute.

## F14 · Settings, languages, offline, sync, notifications

- **F14.1 Languages** — Uzbek (Latin), Russian, English; Uzbek Cyrillic in v3.
- **F14.2 Units** — cm or m; mm for order sheets.
- **F14.3 Defaults** — ceiling height, wall thickness, snap, waste margin, quote validity.
- **F14.4 Company branding** — logo and details on PDFs and links.
- **F14.5 Offline first (v1)** — all measuring, calculation and export works offline.
- **F14.6 Cloud sync (v2)** — last edit per room wins, copy kept.
- **F14.7 Backup** — v1 export file; v2 automatic.
- **F14.8 Notifications (v2)** — visits, signed quotes, order status, low battery, payment due.
- **F14.9 Telegram bot (v2)** — daily visits, owner summary, client quote links.
- **F14.10 Help** — short videos in Uzbek and Russian; Telegram support.

**Done when:** a project measured in airplane mode appears in the web panel within 1 minute of reconnecting.

## Non-functional requirements

| Area | Requirement |
| --- | --- |
| Platforms | Android 8+ first, iOS 14+; web panel on latest Chrome, Edge, Safari |
| Speed | App opens < 2 s; laser reading on screen < 1 s; PDF export < 5 s for 5 rooms |
| Reliability | No data loss on crash or dead battery; 99.5% backend uptime |
| Accuracy | Areas within 1% of tape reference; DXF scale exact |
| Security | Encrypted in transit and at rest; role-based access; client phones hidden from workshop role |
| Privacy and law | Personal data of Uzbek citizens stored on servers in Uzbekistan (confirm with a lawyer) |
| Usability | Touch targets ≥ 44 px; one-hand Laser button; readable in sunlight |
| Localisation | All text in translation files |

## Open questions

- [ ] Final subscription prices (F13.1) and device-bundle free period (F13.2)
- [ ] First trade for order sheets (F11.2): kitchens or stretch ceilings?
- [ ] Uzbek speech-recognition provider (F6.1)
- [ ] Hosting in Uzbekistan for personal data
- [ ] Which external workshops accept orders by link vs need a login
