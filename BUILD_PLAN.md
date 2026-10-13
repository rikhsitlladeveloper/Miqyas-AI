# Build plan and acceptance checks

Read PRODUCT_SPEC.md for authoritative requirements. Each milestone ends with a runnable build and an honest record of passed, failed and unperformed checks.

## Technical direction
Default: TypeScript, React Native and Expo development builds; SQLite persistence. Use pure geometry and decimal-safe estimate modules independent of UI. Keep measurement transport, renderer, persistence and report generation behind small interfaces.
Development builds allow custom native libraries needed for BLE: https://docs.expo.dev/develop/development-builds/introduction/ . Expo Go alone is not the device-integration target.
SQLite reference: https://docs.expo.dev/versions/latest/sdk/sqlite/ . Resolve supported current dependency versions during implementation and commit a lockfile.
Prototype an offline bundled Three.js renderer in a native WebView for room display and image capture. This is a candidate, not a verified integration: prove offline loading, gestures and image export on both platforms before expanding geometry. Reference: https://threejs.org/docs/pages/WebGLRenderer.html . If unsuitable, record evidence and choose an alternative before coupling the editor to it.

## 1. Rectangular-room vertical slice
Build project/floor/room creation, rectangle dimensions, one door/window, manual and clearly labeled simulated measurements, 2D dimensions, interactive shell, manual estimates, local persistence, quote snapshot, PDF and backup/restore. Establish four translation dictionaries; founder approval of translations follows.
Prove the renderer and PDF capture early on physical devices. Keep native BLE and billing out of this milestone; expose replaceable measurement and entitlement boundaries.

### Numeric acceptance fixture
- Interior room: length 5000 mm, width 4000 mm, height 3000 mm; wall thickness 200 mm.
- Door on a 5000 mm wall: width 900 mm, height 2100 mm, offset 500 mm from wall start, bottom at floor.
- Window on the opposite wall: width 1200 mm, height 1500 mm, offset 1000 mm, sill 900 mm.
- Floor and ceiling each 20 m2; interior perimeter 18 m; gross wall face area 54 m2; opening areas 1.89 and 1.80 m2; net wall face area 50.31 m2. This fixture excludes reveals and columns. Label that area convention.
- Example UZS with precision 0: paint 12 units x 50,000 = 600,000; flooring 22 m2 x 120,000 = 2,640,000; labor 1,000,000. Materials 3,240,000; grand total 4,240,000. Quantities deliberately remain manual.
- Changing length to 6000 mm makes floor 24 m2, perimeter 20 m and net wall area 56.31 m2; estimate still totals 4,240,000. An earlier issued quote retains the original geometry and values.

### Behavioral acceptance
- Simulator event fills only the selected dimension after confirmation; cancel leaves it unchanged. Manual input works without any Bluetooth permission.
- Openings appear in the correct walls and floor plan/3D/PDF agree.
- Force close and reopen an installed build offline; geometry, entries and snapshots survive. An app requiring a development server is not sufficient proof of offline behavior.
- Generate/share a multipage PDF offline with readable dimensions, 3D view, correct totals and complete Cyrillic/Uzbek glyphs. Test all four report languages and long line-item names.
- Export backup, restore into a clean test database, compare geometry/rows/snapshots/assets; corrupt backup fails without damaging current records.
- Test currency precision 0, 2 and 3, decimal quantities and line rounding.
- Record physical iPhone and Android results separately; mark any unperformed check as pending.

## 2. Actual device integration (when hardware arrives)
Record exact model/firmware, advertised services and characteristics with permission. Compare to reference before implementing a parser. Capture sanitized packets and add fixture tests for valid/invalid messages, units, duplicates and truncation. A bad packet must never silently change a dimension.
Validate multiple known distances against device display, front/rear reference modes, reconnects, permissions denied, Bluetooth off and app interruption on both phones. Retain manual entry throughout. Document supported hardware only after this passes.

## 3. Release geometry
Add multiple rooms/floors, polygon sketching with explicit constraints, angled walls, rectangular columns/recesses and per-room heights. Decide and document column/recess surface-area conventions before calculating them. Test concave polygons, self-intersections, impossible constraints, opening bounds and undo/redo. Maintain agreement among 2D, 3D, quantities and PDFs; preserve existing saved projects through migrations.

## 4. Pilot hardening
Founder completes real jobs; then recruit external builders to measure completion time, mistakes, comprehension of manual quantities and willingness to pay. Fix failures before increasing inventory or claiming time savings. Validate large reports, low storage, interrupted writes, backup portability, localization and accessible input controls. Add provided logo and visually inspect reports.

## 5. Commercial release
Determine price and sales bundle from pilot evidence. Implement native subscription purchasing/restore and verified entitlement state; define offline entitlement validity and clock-change handling before paid launch. Test active/expired states: saved projects and reports remain accessible, creation/editing gates work, backup stays available. Review current store rules at implementation time. Establish supported-device matrix, supplier quality checks, customer onboarding and support/returns process. Keep commercial launch distinct from technical pilot completion.
