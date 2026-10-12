# Miqyas AI — App Spec v1

A Flutter app for measurers: a laser measurement over Bluetooth lands on a sketched wall, the app computes areas and exports a plan as PDF/DXF, shared via Telegram. Offline-first, Uzbek and Russian.

Functional detail for every module: `functional-requirements.md`. This file covers how v1 is built.

## 1. Scope

v1 does one job: a measurer walks a room, shoots the laser, and leaves with a dimensioned plan and areas, shareable in Telegram.

**In v1**

- Android first, iOS from the same codebase after Android is stable.
- Languages: Uzbek (Latin), Russian; English strings as the base in code.
- Fully offline. No login; local storage only. Cloud sync is v2.
- One Bluetooth laser driver (the ordered device) behind an interface so more can be added.
- Units: metres with 3 decimals internally; display in cm or m.

**Not in v1:** accounts, teams, dashboard, payments · quotes, price lists, material optimizer, wires map · voice, photo, LiDAR · 3D, furniture, curved walls · multi-floor.

## 2. Screens

| # | Screen | Contents | Main actions |
| --- | --- | --- | --- |
| S1 | Projects list | Cards: project, client, address, date, room count, plan thumbnail | New · open · delete (swipe, confirm) · search |
| S2 | Project | Client name, phone, address, notes; rooms with area; total area | Add room · open room · export · share |
| S3 | Room editor | Grid canvas; toolbar Wall, Door, Window, Opening, Undo, Redo, Laser; status bar with device and last reading; selected-wall panel | Draw walls · tap wall + shoot laser · type length · add openings · ceiling height · done |
| S4 | Room summary | Floor area, perimeter, net wall area, ceiling area, volume; walls; openings | Edit · export room PDF |
| S5 | Device | BLE scan list by name/RSSI; battery, last reading | Connect · disconnect · forget · test reading |
| S6 | Export | Plan preview; PDF, PNG, DXF, JSON; scale 1:50 / 1:100 / fit; dimensions, areas, logo toggles | Generate · share (Telegram first) |
| S7 | Settings | Language, units, default ceiling height, wall thickness, company name and logo, snap on/off | Save |

Design: claude.ai canvas *Miqyas AI — App UI* (screens 1–15; v1 uses 1–9 and 13).

**Room editor layout:** top bar (room name, back, done) · device status strip with last reading in large type · canvas (pinch zoom, two-finger pan, 10 cm grid, 1 m major lines) · bottom sheet with the selected wall's length and a large red Laser button · toolbar with 44 px minimum targets.

**Navigation:** S1 → S2 → S3 ↔ S4; S5 and S7 from the app bar; S6 from S2 and S4.

## 3. Core flow and rules

**Drawing a room**

1. Tap Wall, tap the canvas to place corners; tap the first corner to close.
2. Snap to 90°/45° within 7°; to 10 cm grid and to corners within 20 px (setting).
3. Each wall starts with its drawn length in grey; real values in black; red if conflicting.
4. Select a wall and shoot: the reading becomes its length; the next wall is auto-selected.
5. Typing a length does the same.
6. Rescale: the selected wall keeps its start corner and direction; its end moves; following walls translate; the last wall absorbs the difference and is flagged if the gap is over 2 cm.

**Openings:** tap a wall, choose Door/Window/Opening, tap the start point; set width, height, sill (window), swing (door), offset from corner (auto, editable, or by laser). Openings reduce wall area, not perimeter.

**Ceiling height:** one per room, default from settings, editable or by laser.

**Calculations (on every change)**

- Floor area = shoelace formula over corner coordinates (m).
- Perimeter = sum of wall lengths.
- Wall area gross = perimeter × ceiling height; net = gross − openings.
- Ceiling area = floor area; volume = floor area × ceiling height.
- Project totals = sums over rooms.

Store doubles, round to 3 decimals; display 2 (cm) or 3 (m).

## 4. Data model

SQLite via drift. Room geometry is one JSON blob per room; scalar fields are columns for fast lists. Lengths and coordinates in metres, first corner at (0,0).

| Table | Fields |
| --- | --- |
| projects | id (uuid), name, client_name, client_phone, address, notes, created_at, updated_at, thumbnail_path |
| rooms | id, project_id, name, sort_order, ceiling_height_m, wall_thickness_m, geometry_json, floor_area_m2, perimeter_m, wall_area_net_m2, volume_m3, is_closed, closure_gap_m, created_at, updated_at |
| devices | id, name, ble_address, driver_id, last_connected_at, is_default |
| settings | key, value |

```json
{
  "v": 1,
  "corners": [ {"id":"c1","x":0.0,"y":0.0}, {"id":"c2","x":4.2,"y":0.0} ],
  "walls": [
    { "id":"w1", "from":"c1", "to":"c2", "length_m":4.2,
      "source":"laser", "measured_at":"2026-10-12T10:14:00Z" }
  ],
  "openings": [
    { "id":"o1", "wall_id":"w1", "type":"window", "offset_m":1.1,
      "width_m":1.2, "height_m":1.5, "sill_m":0.9, "swing":null }
  ]
}
```

- `source`: `laser` | `manual` | `voice` | `drawn`. Exports warn on `drawn`.
- `offset_m`: from the wall's `from` corner to the opening start.
- Corners clockwise; closed when the last wall's `to` is the first corner.

Domain classes: `Project`, `Room`, `Corner`, `Wall`, `Opening`, `Measurement`. A pure-Dart `RoomGeometry` holds rescale, snap, closure and area maths, unit-tested, no Flutter imports.

## 5. Bluetooth layer

The app talks to a `LaserDevice` interface; each model gets a driver. A `FakeLaserDevice` returns test readings so UI work starts on day one.

```dart
abstract class LaserDevice {
  String get driverId;                 // e.g. "zhenbing_a100"
  Stream<Measurement> get readings;    // one event per shot
  Stream<DeviceState> get state;       // disconnected, connecting, connected, error
  int? get batteryPercent;
  Future<void> connect(String bleAddress);
  Future<void> disconnect();
  Future<void> triggerMeasure();       // no-op if unsupported
}
```

- Scan filters by known service UUID or name prefix; unknown devices listed under "Boshqa".
- Auto-reconnect for 30 s, then a Reconnect button.
- A reading with nothing selected is kept as "last reading" with a "Use last" action.
- Debounce duplicates within 300 ms.
- Parse in the driver: raw bytes → metres.
- Ring buffer of the last 200 raw packets in Settings › Diagnostics.

Package: `flutter_blue_plus`. Permissions: Android 12+ `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`; Android ≤ 11 location; iOS `NSBluetoothAlwaysUsageDescription`.

## 6. Export formats

Generated on device, then the OS share sheet. File name `{project}_{room}_{yyyyMMdd}.{ext}`.

| Format | Contents | Package | Priority |
| --- | --- | --- | --- |
| PDF | A4 per room + project sheet: plan to scale, all dimensions, door/window symbols, areas table, ceiling height, logo, date, page numbers | `pdf` + `printing` | Must |
| PNG | Plan image 2000 px wide | `RenderRepaintBoundary` | Must |
| DXF | R12 ASCII: layers WALLS (closed LWPOLYLINE), DOORS, WINDOWS, DIM, ROOM; metres, `$INSUNITS` = 6 | own writer (~200 lines) | Must |
| JSON | Project + every room's geometry | `dart:convert` | Must |
| Telegram share | PDF + PNG with caption "{project} — {rooms} rooms, {area} m², measured {date}" | `share_plus` | Must |
| Excel / CSV | Walls and areas | `excel` | Nice |

PDF rules: wall bands 0.15 m, dimensions outside the room, 9 pt minimum text, 1:50 if a 6×8 m room fits A4, else 1:100, else fit; drawn lengths shown with "?" and a footnote.

## 7. Tech stack and architecture

- Flutter 3.x, Dart 3. Min Android 8 (API 26), iOS 14.
- Riverpod · go_router · drift · flutter_blue_plus · pdf + printing · share_plus · ARB i18n (`app_en`, `app_uz`, `app_ru`) · `CustomPainter` canvas.
- Brand: Nile teal `#0F6E74`, laser red `#C9381F`, ink `#10202B`, sand `#F4EFE6`; fonts Archivo (display) and Manrope (UI).

**Folders under `lib/`:** `domain/` (pure Dart maths, models, DXF/JSON writers) · `data/` (drift, repositories) · `ble/` (interface, drivers, scanner) · `features/` (one folder per screen) · `export/` (PDF/PNG, share).

**Rules:** maths and writers unit-tested before UI · editor works with the fake device from day one · all strings in ARB · computed columns written on every save · CHANGELOG kept, builds tagged `v0.x.0`.

## 8. Milestones and acceptance

| Week | Milestone | Done when |
| --- | --- | --- |
| 1 | Skeleton | Projects list, DB, settings, 3 languages, fake device streaming |
| 2–4 | Room editor | Draw, snap, close, type lengths, rescale; areas correct on 5 test rooms |
| 4 | Real BLE driver | A reading lands on the selected wall in < 1 s |
| 5 | Openings + ceiling | Net wall area correct |
| 6–7 | Exports | PDF, PNG, DXF, JSON; DXF opens in AutoCAD and NanoCAD |
| 8 | Share + polish | Telegram share; empty/error states; uz/ru reviewed by native speakers |
| 9 | Field test | 3 pilot measurers, one week of real jobs |
| 10 | Release | Play internal track; TestFlight |

**Acceptance (real apartment)**

- [ ] 3-room apartment measured and exported in under 15 minutes by a first-time user
- [ ] Floor areas within 1% of tape reference
- [ ] Closure gap under 2 cm or the warning shows
- [ ] DXF opens in AutoCAD with walls on WALLS
- [ ] Works in airplane mode end to end
- [ ] Device reconnects within 30 s after leaving range
