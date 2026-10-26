# Order location + room shapes — build spec (approved 26 Oct 2026)

The approved clickable mockup is `design/room-shapes/mockup.html` (https://claude.ai/artifact/Geg9qBtjihgVMnfAUuGzjK). Use it as the reference for wording, layout and behaviour. The founder changed a few things when approving it; **where the mockup differs from this file, this file wins.**

## 1. Order location (all trades: furniture, tiler, electrician, plumber, windows; they share one new-order form)
- **Form fields:** "Mijoz ismi", "Telefon" (optional) and "Manzil". The address **stays optional**, as it is today.
- **"Joylashuv" block** under the address:
  - A "Joylashuvni aniqlash" button reads the phone's GPS. It runs **only when tapped** and works without internet.
  - The location comes **from GPS only. There is no "Havolani qo‘yish" and no link pasting.**
  - "Keyinroq" skips it.
- **States**, as in the mockup:
  - locating: a spinner with "Bekor";
  - success: a pin row with the coordinates and "±N m", plus "Qayta aniqlash" and "Olib tashlash";
  - failure: "Joylashuvni aniqlab bo‘lmadi" with a hint about permission and GPS, plus "Qayta urinish";
  - skipped.
- Location permission is asked on the first tap; a refusal shows the failure state. The builder's project form already has a GPS block (`ProjectsScreens.kt`, the `loc.*` strings). Reuse its code and strings where they fit.
- **Order card** (home and orders list):
  - With a location: a green "Joylashuv bor" chip and a blue **"Yo‘l"** button.
  - Without one: a muted "Joylashuv yo‘q" chip and "+ Qo‘shish", which opens a sheet with the GPS button.
  - Any change gives a toast with Undo.
- **"Yo‘l" sheet** opens the pin in:
  - Yandex Maps (`yandexmaps://maps.yandex.ru/?pt=LON,LAT&z=17`);
  - Yandex Navigator (`yandexnavi://build_route_on_map?lat_to=LAT&lon_to=LON`);
  - Google Maps (`geo:LAT,LON?q=LAT,LON`, or `comgooglemaps://` / the https link on iPhone).
  - Apps that aren't installed fall back to the https map link. "Nusxa olish" copies the coordinates.
- **Ma'lumot tab** of an order:
  - a location card with the coordinates, "±N m", the Yo‘l button and "O‘zgartirish";
  - no live map: a simple offline drawing is fine, or none.
- The location is **not printed** in any PDF.

## 2. Room shape (all trades that add rooms: builder, furniture, tiler, electrician, plumber, windows)
1. **Sheet:** room type chips (each trade keeps its own list), a name prefilled from the type ("Oshxona 2" for the second one), then "Davom etish".
2. **"Xona shakli" screen:** a separate full screen with a 2-column grid of 8 picture cards:
   - To‘rtburchak, L shakl, U shakl, Kesik burchak, T shakl, Z shakl, Erker;
   - Erkin chizish.
   - Each card says how many sizes it asks for.
   - The selected card shows "Ko‘zgu" (mirror) and "Burish" (turn 90°).
3. **Wall steps:** one asked size per step, like the furniture size steps from the UX upgrades:
   - a big plan with the asked wall glowing and a "?" pill; done walls show mm; derived walls are dashed and labelled "avtomat";
   - the plan redraws to scale while typing;
   - a big mm field (native number keyboard), the laser button and hold-to-talk voice, with haptics and a flash;
   - "Devor 2 / 4" in the header;
   - Ko‘zgu / Burish on the picture.
   - Units: furniture uses mm; other trades follow their unit setting.
4. **Free sketch:** reuse the builder's sketch screen (one stroke or tapped corners, snap to 90°/45°). Then **every** wall is asked, plus an optional "Diagonal (ixtiyoriy)" step that locks the shape.
5. **Height:** prefilled with the last height used (2700 the first time). One tap keeps it. Allowed range 2000–6000.
6. **Optional step "Eshik, deraza, suv, gaz bormi?":** picture buttons Eshik, Deraza, Sovuq suv, Kanalizatsiya, Gaz truba.
   - Tap one, then a wall on the plan, then type the distance from the corner marked with a dot.
   - A door or window also asks its width and height. **A window also asks its sill height, prefilled with 900.**
   - Each added item shows a toast with Undo; the list has ×.
   - "O‘tkazib yuborish" skips the step; once something is added the button reads "Tayyor".
   - These become the app's real doors, windows and site points (water, sewer, gas), which the auto kitchen uses.
7. **Summary:** the plan, size and area, with "O‘zgartirish" on every asked value, then "Xonani ochish", which opens the trade's room editor. The new room gets a toast with Undo.

## Geometry (must match the mockup exactly)
Port the mockup's `params()` and `geom()` (in `mockup.html`, "shapes" section).
- **Shapes made of right angles** (rectangle, L, U, T, Z): walk round from wall A along the shape's direction string. Every wall except the last two is asked; those two are derived.
  - rect `RDLU`: 2 asked
  - L `RDRDLU`: 4 asked
  - U `RDRURDLU`: 6 asked
  - T `RDLDLULU`: 6 asked
  - Z `RDRDLULU`: 6 asked
- **Cut corner:** asks A, B, D, E. The cut wall C and its angle are derived, so any angle works. It is an error unless D < A and B < E.
- **Erker (bay):** asks wall G (opposite the bay), wall H (side), wall A (corner to the bay), the bay width and the bay depth. The bay sides are 45°. It is an error if the bay doesn't fit the wall, or if it is too deep for its width.
- **Free sketch:**
  - every wall is asked, with directions from the sketch;
  - a closing gap up to max(30 mm, 1 % of the perimeter) is spread over the walls, and a bigger gap is an error;
  - a diagonal is checked within max(30 mm, 2 %).
- **Mirror and turn:** mirror flips x; each turn maps (x, y) → (−y, x). The wall letters move with the shape.
- **Limits:** walls 300–20 000 mm. Openings must fit their wall, and their height must be ≤ the room height.
- **Tests:** `design/room-shapes/shape-cases.json` was generated from the mockup by `gen_cases.js`. **Both apps must pass every case** — corners, wall lengths, which walls are derived, and which cases must be rejected.

## Strings
New strings go into the one-line `android-native/app/src/main/assets/strings.json` as `"key":["uz","uzc","ru","en"]`, edited with Python. Uzbek uses ‘ (U+2018). The iPhone bundles the same file.
- Prefixes: `loc.*` for location (reuse existing keys) and `rsh.*` for the room-shape flow.
- On merge conflicts in that file, use `python design/tools/merge_strings.py`.
