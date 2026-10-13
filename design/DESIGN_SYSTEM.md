# METRX design system

Status: Stage 3 handoff, 13 October 2026. Direction A, "Chizma" (the drawing), in the soft-card style chosen from the community UI kit. Every value below was read from the running prototype on the Android emulator, not taken from memory.

Sizes are in CSS pixels, which map 1:1 to Android dp and iOS pt.

## 0. Current look: minimal (13 October 2026)

After the handoff the founder supplied a minimal design for Home, Projects and New project and asked for it across the whole app. The prototype now uses it everywhere except the sign-in screens (section 2.7). **Where this section and a later one disagree, this section is right.** Sections 2 to 13 still describe the earlier look value by value, and stay correct for everything not listed here: status colours, drawing conventions, states, the PDF. The earlier look, with its prototype and documents, is kept in `design/archive/design-v1-chizma-2026-10-13/`.

| Token | Earlier | Now | Use |
| --- | --- | --- | --- |
| `cobalt` | `#1C4BD1` | `#374FDD` | Main actions, links, active tab |
| `cobalt2` | `#1238A8` | `#2A3FBF` | Pressed main button, text on the wash |
| `wash` | `#EAF0FE` | `#EEF2FE` | Icon tiles, selected chips, focus ring |
| `paper` | `#F4F5F7` | `#F7F8FA` | Page |
| `ink` | `#0E1C36` | `#0B1020` | Text |
| `ink2` | `#47536A` | `#566074` | Secondary text |
| `ink3` | `#6B7486` | `#667085` | Hints, placeholders |
| `rule` | `#E3E6EB` | `#E4E8EF` | Hairline around cards and fields |
| `fill` | `#EEF0F4` | `#F1F4F8` | Secondary buttons, neutral chips |

- **Typeface:** Manrope for all interface text (400 to 800). It covers Latin, Russian and the Uzbek Cyrillic letters ў, қ, ғ, ҳ. Numbers on drawings, in tables and in the calculator stay in IBM Plex Sans Condensed, so long values still fit.
- **Cards:** white, 22 radius, a 1 px `rule` hairline and no shadow. Large feature cards (the New project card on Home, the empty Projects card) use 26.
- **Buttons:** 16 radius; full-width and footer buttons are 54 tall with 18 radius and weight 700. The main button has a soft blue shadow.
- **Fields:** 56 tall, 16 radius, 1 px hairline, 18 side padding. Labels are 15 / 700 in `ink`; "Optional" sits at the right of the label. Focus is a 2 px `cobalt` border with a 4 px wash ring.
- **Tab bar:** a floating white bar, 72 tall, 26 radius, 12 from the screen edges and 8 above the gesture area. The active tab is a filled `cobalt` block (20 radius) with a white icon and label; the others are `ink2`.
- **Titles:** page title 30 / 800. Home greeting 32 / 800. A page may carry a small blue line (13.5 / 600) above its title.
- **Sheets:** 28 top radius. Toasts and banners: 16 radius.
- **Contrast, measured:** white on `cobalt` 6.3:1 · `ink2` on `paper` 5.9:1 · `ink3` on `paper` 4.7:1 · `cobalt` on `wash` 5.6:1. The card hairline is decorative (1.2:1).

## 1. Principles

1. **Built for a building site.** Big numbers, big buttons, one main action per screen, nothing that needs a careful tap.
2. **The drawing is the product.** Plans use technical-drawing conventions: hatched walls, dimension lines, lettered walls, numbered corners.
3. **A value is either received or confirmed, and you can always tell which.** This distinction is never shown by colour alone.
4. **Calm surfaces, one accent.** Grey page, white cards, cobalt for the thing to press. Amber, green and red are reserved for status.
5. **Simulated is labelled.** Anything not real carries the hatched "Simulation" tag.

## 2. Colour

### 2.1 Core tokens

| Token | Hex | Use |
| --- | --- | --- |
| `ink` | `#0E1C36` | Text, plan walls, dark surfaces (calculator, total strip, toast) |
| `ink2` | `#47536A` | Secondary text, inactive icons |
| `ink3` | `#6B7486` | Hints and placeholders on white only |
| `paper` | `#F4F5F7` | Page background |
| `sheet` | `#FFFFFF` | Cards, sheets, fields, footers |
| `fill` | `#EEF0F4` | Secondary buttons, segmented tracks, neutral chips |
| `rule` | `#E3E6EB` | Borders, dividers |
| `rule2` | `#EEF0F3` | Dividers inside cards |
| `cobalt` | `#1C4BD1` | Main actions, links, active tab, selection |
| `cobalt2` | `#1238A8` | Text on the cobalt wash |
| `wash` | `#EAF0FE` | Selected chips, light action buttons, info banners |

### 2.2 Status colours

Each status is a pale background with dark text of the same hue, plus an icon and a word.

| Status | Background | Text | Used for |
| --- | --- | --- | --- |
| Received, warning | `#FFF1DF` | `#9A4D00` | Unconfirmed values, warning banners, amber tiles |
| Confirmed, connected | `#E6F4EF` | `#0B7A5A` | Confirmed values, laser connected, backup fresh |
| Error | `#FDEDEB` | `#B42318` | Field errors, delete buttons |
| Locked | `#EEF0F4` | `#47536A` | Frozen quote, expired subscription |
| Calculated | `#EAF0FE` | `#1C4BD1` | Sides the app worked out ("=") |

### 2.3 Board stage colours

| Stage | Background | Text | Dot |
| --- | --- | --- | --- |
| Measuring | `#FFF1DF` | `#8A4500` | `#E8963A` |
| Estimating | `#EAF0FE` | `#1238A8` | `#5B7FE6` |
| Quote sent | `#ECE7FC` | `#4A2FB0` | `#8B6FE0` |
| Work | `#E3E7EE` | `#0E1C36` | `#7C8699` |
| Done | `#E3F3EC` | `#0B6B4F` | `#2E9C78` |

### 2.4 Contrast (measured)

| Pair | Ratio | Verdict |
| --- | --- | --- |
| ink on paper | 15.5:1 | Pass |
| ink2 on paper | 7.1:1 | Pass |
| ink3 on sheet | 4.7:1 | Pass |
| ink3 on paper | 4.3:1 | **Just under 4.5:1.** Use `ink2` for small text on the grey page |
| White on cobalt | 7.1:1 | Pass |
| cobalt2 on wash | 8.5:1 | Pass |
| Amber text on amber wash | 5.5:1 | Pass |
| Green text on green wash | 4.7:1 | Pass |
| Red on red wash | 5.8:1 | Pass |
| Violet on violet wash | 7.5:1 | Pass |
| Calculator grey `#B7C3D9` on ink | 9.5:1 | Pass |

### 2.5 Door and window colours

One standard look for all doors and windows: `#E2E6EC` in 2D, `#C5CBD4` in 3D.

### 2.6 3D surface colours

- **Walls:** `#ECE8E1`, `#D9D4CB`, `#D6E0EC`, `#E6D3B3`.
- **Floor:** `#C49A6C`, `#8A6343`, `#B9BDC2`, `#A7A39C`.

### 2.7 Sign-in screens

The sign-in screens (opening animation, Welcome, Create account, Log in, Reset password) take their look from the founder's Figma file. The values below apply to those screens only; the rest of the app uses the tokens above. Whether this style replaces the app-wide one is an open decision (see the review checklist).

| Token | Value | Use |
| --- | --- | --- |
| `auth.primary` | `#3355B4` | Main button, links, progress, active outline, laser line |
| `auth.primaryPressed` | `#27448F` | Pressed main button |
| `auth.wash` | `#EBF2FC` | Focus ring, icon circles |
| `auth.page` | `#FFFFFF` | Every sign-in page |
| `auth.ink` | `#0B1226` | Headings, values, plan walls |
| `auth.ink2` | `#56627A` | Body text, labels |
| `auth.ink3` | `#626E87` | Small print, field icons, placeholders |
| `auth.outline` | `#C9D6E8` | Outlines of fields, buttons, cards and code boxes |
| `auth.hairline` | `#E7ECF3` | Dividers |
| `auth.tint` | `#F1F6FA` | "Continue without an account" card |
| `auth.chip` | `#D3DFEF` | "Sample room" chip |
| `auth.padCard` | `#EEF2FC` | Number pad card |
| `auth.keyboard` | `#F3F4F9` | Ground of the code keyboard |

Contrast, measured: white on `auth.primary` 6.8:1 · `auth.ink2` on white 6.1:1 · `auth.ink3` on white 5.1:1 · `auth.primary` on `auth.wash` 6.0:1. The outline is 1.5:1 against white, as drawn in the Figma. A field is still recognisable by its label and icon, but the outline alone does not meet the 3:1 asked of input boundaries.

- **Shape:** fields 56 tall with a 1.5 outline and 12 radius. Buttons 52 tall, 12 radius; the main one has a soft blue shadow. Code boxes 64 tall with a 2 outline. Plan card 16 radius. Sheets 28 radius with a 48 × 4 handle.
- **Focused field:** the outline turns `auth.primary` with a 3 wash ring. **Wrong:** the outline turns red with a line of text and an icon underneath.
- **Labels in capitals:** the tagline, the chips on the plan card, "Offline mode" and the number pad's title are IBM Plex Mono, about 10.5, in capitals with wide letter-spacing. They are short labels only; sentences are never set this way.

## 3. Typography

- **IBM Plex Sans** for all interface text. It has full Latin and Cyrillic, including the Uzbek letters ў, қ, ғ, ҳ.
- **IBM Plex Sans Condensed** for numbers: dimensions, areas, money, counters. Narrow digits keep long values on one line.
- **IBM Plex Mono**, on the sign-in screens only: the wordmark, the small labels in capitals, the phone number, the SMS code and the keys of the number pad. It has the same Latin and Cyrillic coverage.
- Fallbacks: Segoe UI, Roboto, the system font.
- **Bundle the families in the app.** The prototype loads them from the internet; the real app must not.

### 3.1 Scale

| Role | Size / weight | Family | Example |
| --- | --- | --- | --- |
| Meter reading | 54 / 600 | Condensed | "3,600" on the Measure tab |
| Page title | 28 / 700 | Sans | "Loyihalar" |
| Project title | 23 / 700 | Sans | Project page header |
| Grand total | 23 / 600 | Condensed | Estimate footer |
| Sheet title | 17 / 600 | Sans | "Yangi material" |
| Card title | 16.5 / 600 | Sans | Project name on a card |
| Tile and section title | 16 / 600 | Sans | "So‘nggi loyihalar" |
| Field text | 16 / 400 | Sans | Typed values |
| List row | 15.5 / 500 | Sans | Settings rows |
| Body | 15 / 400 | Sans | Card subtitles |
| Tab | 15 / 600 | Sans | Project tabs |
| Row value | 14 / 400 | Sans | Setting values |
| Field label | 13.5 / 500 | Sans | Above each field |
| Group heading, saved chip | 13 / 500 | Sans | "Til va hisobot" |
| Tab bar label | 12 / 400 (600 active) | Sans | "Asosiy" |
| Table heading | 11.5 / 400 | Sans | "Miqdor", "Narx" |

### 3.2 Rules

- Sentence case everywhere. Room names on a plan are the one exception: small capitals with letter-spacing.
- Line height is about 1.4 for text and 1.0 to 1.15 for big numbers.
- Numbers in tables are right-aligned and use tabular figures.
- A unit follows its number in a smaller, lighter size: "5,00 m", "20,00 m²".
- Thousands are separated by a space in Uzbek and Russian ("4 240 000") and a comma in English ("4,240,000").

## 4. Spacing, shape and depth

| Item | Value |
| --- | --- |
| Screen gutter | 16 |
| Card padding | 12 |
| Gap between cards | 10 to 12 |
| Gap inside a card | 6 to 8 |
| App bar height | 52 |
| Tab bar height | 64 |
| Footer padding | 10 top, 16 sides, 26 bottom (clears the gesture bar) |

| Shape | Radius |
| --- | --- |
| Card, tile | 16 |
| Dark panels (calculator, total strip) | 16 to 18 |
| Main button on the Measure tab | 16 |
| Button, field, chip, key in a group | 12 |
| Status tile | 14 |
| Bottom sheet | 22, top corners only |
| Pill (status, stage, laser chip) | Fully round |
| Floating button | Fully round, 54 tall |
| PDF page preview | 6 |

- **Shadow:** one soft shadow for all cards: `0 1px 2px rgba(16,24,40,.05), 0 2px 10px rgba(16,24,40,.06)`.
- **Dimmed background** behind a sheet: `rgba(14,28,54,.42)`.
- Cards sit on the page by shadow, not by border. Fields have a 1 px `rule` border.

## 5. Controls

### 5.1 Touch targets

**Nothing tappable is smaller than 44 on its short side.** This was measured on 44 screens in four languages at 411 and 360 wide. One deliberate exception: the slim handle above the room editor's step card is 22 tall, but its tappable area extends to about 44.

### 5.2 Buttons

| Kind | Look | Height | Use |
| --- | --- | --- | --- |
| Primary | Cobalt, white text | 44; 52 in the room editor; 56 on the Measure tab | The one main action |
| Secondary | `fill`, ink text | Same as its neighbour | The alternative |
| Light action | `wash`, cobalt2 text | 44 | "Next stage", "Set up" |
| Danger | Red | 44 | Delete, sign out |
| Locked | Grey with a lock icon | 44 | Blocked by an expired subscription |
| Text link | Cobalt text | 44 tall hit area | "All", "List", "Clear" |
| Icon button | Icon in a 44 × 44 box | 44 | Back, undo, menu, call |
| Floating | Cobalt pill with icon and word | 54 | "+ Project", "+ Add" |

- A footer holds one or two buttons. With two, the primary is on the right and wider.
- An inactive primary is the same cobalt at reduced opacity. It keeps its label.
- Long labels wrap onto two lines inside the button. They are never cut.

### 5.3 Fields

- 48 tall, radius 12, 1 px border, label above, unit inside on the right.
- **Focused:** 2 px cobalt border with a soft glow.
- **Error:** red border, and a red line underneath with a warning icon and the message.
- **Optional** is written next to the label.
- A hint sits under the field in `ink2`.

### 5.4 Choices

| Control | Use | Size |
| --- | --- | --- |
| Segmented switch | Two or three exclusive views (Active/Done/All, Plan/3D, Single/Continuous) | 44 tall; the selected segment is a white raised pill |
| Choice chips | Pick one of several (unit, wall, language, workspace type) | 44 tall, 44 wide at least; selected is `wash` with a cobalt border |
| Toggle chips | Include or exclude (rooms, items in the report) | Same, with a tick or plus icon |
| Switch | A setting that is on or off | 46 × 28 |
| Option rows | Shapes, share targets | Full-width rows with an icon and a chevron or tick |

### 5.5 Lists, cards and tiles

- **List row:** 56 tall, icon in a small rounded square, label, value on the right, chevron.
- **Project card:** title and stage chip, three small number boxes, one status line, two buttons.
- **Workspace item card:** a 4:3 thumbnail, kind, name, one status line, a "PDF" badge at top left, a menu at bottom right.
- **Home tile:** about 185 × 115, icon in a square, title, one line. The first tile is cobalt.
- **Status tile:** icon, label, state in words. Green outline when good, amber fill when it needs attention.

### 5.6 Bars and sheets

- **App bar:** 52 tall. Back arrow with the previous page's name, or a title with a subtitle. The right side holds the Saved chip or actions.
- **Tab bar:** 64 tall, five items. The active one is raised in a cobalt circle with a white ring.
- **Bottom sheet:** grab handle, title, close button, scrolling body, fixed footer with the buttons. At most 92% of the screen height.
- **Toast:** ink background, white text, radius 12, one optional action in light blue. It shows for about 5 seconds. On pages with a footer or 3D controls it appears under the app bar, so it never covers the main button.
- **Banner:** pale background, radius 12, an icon, text, and at most one action.
- **Tip card:** centred card with an illustration, title, two lines, "Don't show this again" and one button.

### 5.7 Keyboard

The prototype draws its own keyboard so the layouts show real keyboard height (240 for numbers). The real app uses the system keyboard: the decimal pad for numbers, and "Next" to move between fields.

The sign-in screens are the exception. As drawn in the Figma, they have their own keyboards, which the real app would build too:

- **Phone number:** a number pad on a tinted card with its title and "Close". Three columns of 48-tall keys; the last row is Clear, 0 and backspace.
- **SMS code:** a four-column pad with 52-tall keys, backspace at the top right and "Done" at the bottom right. Above the keys, one button offers the code from the SMS for one-tap entry.
- Name and password use the system keyboard.

## 6. States and status language

Status is always an icon plus a word. Colour only supports it.

### 6.1 Dimension

| State | Icon | Word | Colour |
| --- | --- | --- | --- |
| Not measured | "?" | "O‘lchanmagan" | Neutral |
| Received | Clock | "Tasdiqlanmagan" | Amber |
| Confirmed | Tick | "Tasdiqlangan" plus the source | Green |
| Calculated | "=" prefix, dashed outline, italic | "hisoblangan" | Cobalt |
| Approximate | "≈" prefix | "taxminiy" | Neutral |
| In conflict | Warning triangle, value in brackets | Explained in a banner | Amber |

### 6.2 Laser

| State | Chip |
| --- | --- |
| Connected | Bluetooth icon with a green dot, "Ulangan" |
| Not connected | Crossed Bluetooth icon, "Lazer ulanmagan", amber outline |
| Bluetooth off | Same icon, "Bluetooth o‘chiq" |
| No permission | Same icon, "Ruxsat yo‘q" |
| Simulator | Dashed outline and the "Simulyatsiya" tag |

### 6.3 Other

- **Saved:** a document icon with a tick and "Saqlandi 12:01".
- **Simulated:** dashed 1 px border with diagonal hatching and the word. Simulated reading chips are hatched too.
- **Read-only:** a lock icon on the blocked button and a grey banner with "Yangilash".
- **Missing value in a table:** an amber "?" in the cell and "—" for the sum.
- **Empty screen:** a line saying what belongs here, and the button that adds it.

## 7. Icons

- One family of line icons: 24 grid, 1.8 stroke, round caps and joins, no fill. Sizes 20 (default), 16 (inside buttons and chips), 14.
- Icons take the colour of their text.
- The set: status, plane, back, chev, x, more, undo, redo, bt, btoff, check, clock, alert, info, plus, door, window, column, dim, room, cube, folder, tape, sliders, device, layers, kbd, edit, doc, lock, share, trash, copy, camera, globe, user, ruler, coin, save, restore, card, send, search, home, board, box, boxok, pin, phone, walls, laser, pen, note, bath, kitchen, balcony, tree, eraser, arrow, text, line.
- Workspace types have their own icon: floor (layers), room, bathroom, kitchen, balcony, yard (tree).
- An icon-only button always has a spoken label.

## 8. Drawing conventions

### 8.1 Plan

- Walls are a thick ink outline with 45° hatching, drawn at the wall's thickness.
- Wall letters (A, B, C…) sit in circles inside the room. Corner numbers (1, 2, 3…) sit at the corners, clockwise from the top left.
- Dimension lines have ticks at both ends and the value in a white chip. Chains of smaller dimensions show the distances to and between openings.
- A door is a gap with its swing arc. A window is a gap with a double line.
- The room name and floor area are centred.
- A light grid lies behind the plan.

### 8.2 Wall view

The wall seen from inside the room, on a floor line with ground hatching. Corners are numbered at the top. Height is on the left, length underneath, with the opening distances above it.

### 8.3 3D

Light walls with a slightly darker shade away from the light, the chosen floor colour, a faint ground grid, wall letters as floating labels, and semi-transparent walls where they would hide the room.

## 9. The PDF

- A4, 595 × 842 pt, margins 36 top and bottom, 38 at the sides.
- **Header:** the wordmark on the left (to be replaced by the logo), the document title and number or date on the right, with a rule underneath.
- **Parties table:** builder and customer side by side, the project and location underneath.
- **Room block:** the plan on the left, a table of dimensions and areas on the right.
- **Estimate:** numbered tables with right-aligned figures, subtotals, and the grand total in its own bar.
- **Footer:** project name on the left, "1 / 4" on the right.
- **Draft:** a large diagonal "DRAFT" in pale cobalt across each page.
- Base text is 10 pt. Footnotes state where each kind of number comes from.

## 10. Motion

- Pages slide in from the right and out to the right. Sheets slide up. The dimmed background fades.
- A toast rises in about 0.2 s.
- Nothing moves on its own except the opening animation and the live meter in continuous mode.
- Respect the system's "reduce motion" setting.

## 11. Languages

- Four languages: Uzbek Latin (the main draft), Uzbek Cyrillic, Russian, English. The report language is chosen separately from the interface language.
- Uzbek Cyrillic is generated from the Latin text in the prototype and needs a native review, especially for loanwords.
- Russian is the longest. Layouts are sized for it: buttons wrap to two lines, tabs use the short forms "Зоны" and "КП", tiles use short labels such as "Резерв".
- Plurals follow each language's rules (Russian has three forms).
- Dates are day.month.year. Time is 24-hour.

## 12. Platform notes

| Topic | Android | iPhone |
| --- | --- | --- |
| Back | The system back button or gesture: keyboard, then sheet, then page, then Home | The same order with the edge swipe and the bar's back arrow |
| Status bar | Light background with dark icons; dark icons switch to light over dark pages | The same |
| Safe areas | Leave room for the gesture bar under footers and the tab bar | Also the notch or island at the top and the home indicator |
| Photos | The system photo picker | The system photo picker |
| Calls | `tel:` opens the dialer with the number filled in | The same, with the system's confirmation |
| Sharing | The system share sheet | The system share sheet |
| Bluetooth | Ask for permission only when the builder first connects a laser. Typing must work without it | The same |
| Keyboard | Decimal pad for numbers | Decimal pad, with a "Done" bar above it |
| Fonts and 3D | Bundled in the app | Bundled in the app |

## 13. Tokens for the build

```
color.ink        #0E1C36    radius.card     16
color.ink2       #47536A    radius.control  12
color.ink3       #6B7486    radius.sheet    22
color.paper      #F4F5F7    radius.pill     999
color.sheet      #FFFFFF    space.gutter    16
color.fill       #EEF0F4    space.card      12
color.rule       #E3E6EB    size.target     44
color.cobalt     #1C4BD1    size.field      48
color.cobalt2    #1238A8    size.appbar     52
color.wash       #EAF0FE    size.tabbar     64
color.amber      #9A4D00    size.button     44 / 52 / 56
color.amberWash  #FFF1DF    font.ui         IBM Plex Sans
color.green      #0B7A5A    font.number     IBM Plex Sans Condensed
color.greenWash  #E6F4EF
color.red        #B42318
color.redWash    #FDEDEB

Sign-in screens only (section 2.7):
auth.primary     #3355B4    auth.outline    #C9D6E8
auth.pressed     #27448F    auth.hairline   #E7ECF3
auth.wash        #EBF2FC    auth.tint       #F1F6FA
auth.ink         #0B1226    auth.padCard    #EEF2FC
auth.ink2        #56627A    auth.keyboard   #F3F4F9
auth.ink3        #626E87    font.mono       IBM Plex Mono
size.authField   56         size.authButton 52
size.codeBox     64         radius.authSheet 28
```
