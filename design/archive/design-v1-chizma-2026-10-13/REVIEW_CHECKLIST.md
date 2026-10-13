# METRX review checklist

Status: Stage 3 review, 13 October 2026. This records what was actually checked, how, and what is still unchecked. Nothing here is marked as passed unless it was run.

## How it was checked

- **Device:** Android emulator "Medium Phone", Android 17 (API 37), 1080 × 2400, system WebView 149.
- **Build:** the prototype wrapped in the Android app in `design/android-prototype/`, installed fresh with its data cleared.
- **Widths:** 411 wide (the emulator's default) and 360 wide (by raising the screen density).
- **Method:** a script drove the app through its own buttons and read the results from the screen. Real touches were used where a gesture matters: dragging a door, drawing a room outline, rotating 3D, swiping pages, pinching, the Back button, and tapping Call and the photo picker.
- **Not a device test.** No real phone, laser, camera or iPhone was involved.

## Legend

| Mark | Meaning |
| --- | --- |
| ✅ | Ran and passed |
| 🔧 | Failed, fixed during the review, then passed |
| ⚠️ | Works, but something should change. Listed under "Open" |
| 📱 | Needs a real device |
| ❓ | Not checked |

---

## 1. Acceptance fixture (from BUILD_PLAN.md)

| Check | Expected | Result |
| --- | --- | --- |
| Room 5,00 × 4,00 × 3,00 m: floor | 20,00 m² | ✅ |
| Perimeter | 18,00 m | ✅ |
| Walls gross | 54,00 m² | ✅ |
| Door 0,90 × 2,10 | 1,89 m² | ✅ |
| Window 1,20 × 1,50, sill 0,90 | 1,80 m² | ✅ |
| Walls net | 50,31 m² | ✅ |
| Volume | 60,00 m³ | ✅ |
| Paint 12 × 50 000 | 600 000 | ✅ |
| Flooring 22 m² × 120 000 | 2 640 000 | ✅ |
| Materials | 3 240 000 | ✅ |
| Labour | 1 000 000 | ✅ |
| Grand total | 4 240 000 so‘m | ✅ |
| Length changed to 6,00 m: floor, perimeter, net wall | 24,00 m², 20,00 m, 56,31 m² | ✅ |
| Estimate after that change | Unchanged | ✅ |
| Quote №1 after that change | Still 5,00 m, 20,00 m², 50,31 m², 4 240 000 | ✅ |
| Plan, wall view, 3D and PDF agree on openings | Door on wall A, window on wall C in all four | ✅ |

## 2. Measuring

| Check | Result |
| --- | --- |
| A laser reading arrives as "Unconfirmed" and the area stays "?" | ✅ |
| Confirm applies it; a toast offers Undo | ✅ |
| "Again" discards the reading and keeps the old value | ✅ |
| Typed value: empty, zero, negative, not a number, 4 decimals, over 100 m each give their own message | ✅ |
| Undo and redo of a dimension | ✅ |
| Measuring a confirmed wall again by typing moves the card on | 🔧 |
| Laser not connected, Bluetooth off, no permission: typing still works | ✅ |
| Search → found → connect in the device sheet | ✅ |
| Wall-view measure sheet: waiting → received → confirm | ✅ |
| A reading sent from the Measure tab arrives as Received in the room, labelled as such | 🔧 |
| Readings tray lists readings with "Assign to" | ✅ opened; assigning from it ❓ |

## 3. Room shapes

| Check | Result |
| --- | --- |
| L-shape: four measured sides, two calculated ("=") | ✅ |
| L-shape floor 25,51 m² and walls 66,06 m², checked by hand | ✅ |
| Free outline in one stroke becomes four straight walls | ✅ |
| A self-crossing outline is rejected with a message | ✅ |
| Corner-tap mode, "not closed" message, Close room | ✅ |
| Five walls with a 45° wall: two sides calculated correctly | ✅ |
| Dragging a corner leaves confirmed lengths unchanged | ✅ |
| A diagonal that disagrees with the plan warns and does not change the plan | ✅ |
| A diagonal is called "Diagonal X1", not "Wall X1" | 🔧 |
| Free-drawn floor area | ⚠️ 16,99 shown, 16,98 exact |

## 4. Doors and windows

| Check | Result |
| --- | --- |
| Add a door and a window with default sizes | ✅ |
| Wider than the wall, taller than the room, past the corner: each rejected with the excess in metres | ✅ |
| Overlapping another opening is rejected | ✅ |
| Drag along the wall by finger; position becomes "≈"; Undo | ✅ |
| Typing an exact distance removes "≈" | ✅ |
| All four walls by arrows and by swipe; areas per wall | ✅ |
| Columns and recesses show the "later" explanation | ✅ |

## 5. 3D

| Check | Result |
| --- | --- |
| Rectangular, L-shaped and five-wall rooms render with openings | ✅ |
| Rotate by finger | ✅ |
| Pinch to zoom, in and out | ✅ two fingers simulated through the browser engine |
| Presets, wall and floor colours | ✅ |
| Save view; it appears in the report | ✅ |
| Zooming in has no limit; the camera can pass through a wall | ⚠️ |

## 6. Workspaces and their items

| Check | Result |
| --- | --- |
| Create workspaces of type Room and Floor | ✅ |
| Photo: real picker opens and cancels cleanly | ✅ |
| Photo: simulated camera, dimension line by drag, laser value, typed value, arrow, pen, undo, redo, caption | ✅ |
| Free drawing by finger | ✅ |
| Note with text and a checklist item; "Add to report" | ✅ |
| "PDF" badge no longer covers the note text | 🔧 |
| Leaving an empty note removes it | 🔧 |
| Copy, rename, move to another workspace, delete with Undo | ✅ |
| Delete a workspace: confirmation, then Undo | ✅ |
| Delete a project: confirmation, then Undo | 🔧 it used to delete at once |
| Text and eraser tools | ❓ |

## 7. Estimate and money

| Check | Result |
| --- | --- |
| Empty name, "1,2,3", negative quantity each rejected | ✅ |
| Row saved with no price shows "?" and "—", with a warning above the table | ✅ |
| Issuing is blocked until the row is filled in | ✅ |
| UZS, no decimals | ✅ |
| USD, 2 decimals: 2,5 × 3,33 = 8,33 | ✅ |
| USD: a price with 3 decimals is rejected | ✅ |
| EUR, 3 decimals: 1,5 × 2,005 = 3,008 and 0,333 × 1,115 = 0,371 | ✅ |
| Zero price is accepted and not flagged | ✅ |
| Lines are rounded, then summed | ✅ |
| 97-character item name: the row wraps, nothing is cut | ✅ |
| Decimal quantity 1250,5 × 1 850 = 2 313 425 | ✅ |
| Deleting a row offers no Undo | ⚠️ |

## 8. Report and quotes

| Check | Result |
| --- | --- |
| Total strip, page count, language | ✅ |
| One page per swipe; arrows; counter | ✅ after a fix on 12 October |
| Tap to zoom; close | ✅ |
| Report language changes the pages at once, in all four languages | ✅ |
| Long item name in the PDF in all four languages: nothing outside the page | ✅ |
| Photos, drawings, notes and a saved 3D view appear on their pages | ✅ |
| Notes typed in Set up appear in the PDF | ✅ |
| Share sheet | ✅ simulated |
| Issue №1; it is frozen; the draft is marked "same" then "differs" | ✅ |
| Issue №2 after a change; both are listed with their own totals | ✅ |
| An issued PDF has no watermark and carries its number and date | ✅ |
| Cyrillic and Uzbek letters in a real PDF file | 📱 the prototype shows pages on screen and does not write a file |

## 9. Home, Projects, Board, Measure, Profile

| Check | Result |
| --- | --- |
| Empty states on all five tabs | ✅ |
| Home: Continue, attention row, four tiles, recent projects | ✅ |
| Projects: Active/Done/All, search with and without a match, card buttons | ✅ |
| Board: strip, tick a task, Next stage, both Undos, Done fold, job detail, move back a stage | ✅ |
| Board: "waiting N days" highlight | ❓ the test quote was sent the same day |
| Measure: one press, continuous, typed reading, four calculator tools, list, send | ✅ |
| Measure, brick tool (added after the review): 3,600 × 3,200 m, one brick thick, gives 1 241 bricks and 0,58 m³ | ✅ checked by hand |
| Brick tool: ½, 1,5 and 2 bricks give 621, 1 861 and 2 482 | ✅ |
| Brick tool: taking off a 0,9 × 2,1 door gives 9,63 m² and 1 038 bricks | ✅ |
| Brick tool: brick 250×120×88 with 10% spare gives 995 | ✅ |
| Brick tool: out-of-range size and spare are rejected with the allowed range | ✅ |
| Brick tool in four languages at 360 wide, and on the emulator | ✅ |
| Profile: tiles in normal and warning states, each opens its fix | ✅ |
| More settings page and Back | ✅ |
| Settings sheets open in all four languages | ✅ opened; changing each value ❓ |
| Backup: create; restore a damaged file; restore a good file keeping both copies | ✅ simulated files |
| Restore with "Replace" and "Skip" | ❓ |

## 10. Sign-in

| Check | Result |
| --- | --- |
| Welcome in four languages | ✅ |
| Sign up: empty and short fields, number already registered | ✅ |
| Code: wrong, then right; auto-verify on the sixth digit | ✅ |
| Password rules tick live; show and hide | ✅ |
| Back from the code or password step keeps the name and phone | 🔧 |
| Log in: empty, wrong password, unknown number, no internet | ✅ |
| Reset password: mismatch, save, old password refused, new one accepted | ✅ |
| Google chooser | ✅ simulated |
| Continue without an account | ✅ |
| Sign out keeps the projects | ✅ |
| Resend code after the countdown; "Use another account" | ❓ |

After the review the sign-in screens were redrawn from the founder's Figma file. They were checked again on 13 October 2026:

| Check | Result |
| --- | --- |
| Every sign-in screen (20 states) in four languages at 411 and 360 wide: no cut-off text, nothing past the edge | ✅ in the browser |
| Every control at least 44 × 44, apart from the keys of the simulated system keyboard | ✅ in the browser |
| With a keyboard open at 360 × 740, the field and the main button are both visible | ✅ in the browser |
| Number pad: nine digits at most, backspace, Clear, Close; a short number shows its message | ✅ |
| "Number has an account" sheet: Log in with password, Change number, Forgot password, tap outside, Back | ✅ in the browser |
| Back from Log in or Reset password, when the sheet led there, returns to step 1 with the name and phone | ✅ in the browser |
| Full sign-up on the emulator: Welcome, number pad, the sheet, wrong code, one-tap code, password, "Account created" | ✅ |
| Opening animation on the emulator; the status bar stays light with dark icons | ✅ |
| Welcome at 360 × 740: fits without scrolling in Uzbek; Russian scrolls by about 40 | ✅ |

## 11. System states

| Check | Result |
| --- | --- |
| Subscription expired: banner; new project, add/edit row, issue, edit dimension, add opening all blocked | ✅ |
| Expired: viewing, 3D, report, share, quick measuring still work | ✅ |
| No internet: chip shown, measuring and saving work | ✅ |
| Save failed: banner with Retry; clears after retry | ✅ |
| Airplane mode, force-close, reopen: projects, quotes and report intact | ✅ network confirmed down |
| Data survives a crash of the web engine and an emulator reboot | ✅ |
| Fonts and 3D with no network on a first launch | ⚠️ they loaded only from the phone's cache |

## 12. Layout and languages

| Check | Result |
| --- | --- |
| 44 screens × 4 languages at 411 wide: no cut-off text | ✅ |
| 44 screens × 4 languages at 360 wide: no cut-off text | ✅ |
| Every tappable control at least 44 on its short side | 🔧 about 30 kinds of control were 22 to 42 before |
| Toast no longer covers the main button | 🔧 |
| Script errors during all runs | ✅ none |
| Browser check at 360 wide for each page as it was designed | ✅ 12 October |

## 13. Android

| Check | Result |
| --- | --- |
| Back: keyboard, then sheet, then page, then Home, then leaves the app | ✅ |
| Call opens the dialer with +998 90 123 45 67 | ✅ |
| Gallery opens the system photo picker | ✅ |
| App reopens on the same screen | ✅ |

---

## Fixed during the review

1. Room editor: a typed value now ends "measure again" and moves the step card on.
2. Workspace: the "PDF" badge no longer covers a note's first words.
3. Notes: leaving a note with nothing in it removes it.
4. A reading sent from the Measure tab is labelled "from the Measure tab", not "from the laser".
5. Sign-up and password reset: going Back keeps the name and phone.
6. Touch targets: about 30 kinds of control raised to 44. The slim handle above the step card stays 22 tall with a tappable area of about 44.
7. Toasts appear under the app bar on pages with a footer or 3D controls, and have rounded corners.
8. A diagonal is named "Diagonal X1".
9. Deleting a project asks for confirmation and says how many issued quotes go with it.

## Open

Things that work today but should change, or need the founder's decision.

| # | Item | Suggested action |
| --- | --- | --- |
| 1 | Board tasks "Measure the rooms", "Build the estimate", "Send the quote" are ticked by hand even when the app knows they are done | Tick them automatically. Founder to confirm |
| 2 | Brick and mortar calculator | **Decided:** the founder chose a stand-alone Brick tool on the Measure tab. It is built. The brick sizes, joint and spare are starting values and need the founder's figures. Cement and sand are not calculated |
| 3 | In the room editor, Bluetooth off and no permission show the general "Laser not connected" line | Name each case, as the Measure tab does |
| 4 | Deleting an estimate row has no Undo | Add an Undo toast |
| 5 | Free-drawn room: floor area can be 0,01 m² off, because calculated sides are rounded to whole millimetres before the area is worked out | In the build, calculate areas from unrounded geometry and round only for display |
| 6 | 3D zoom-in is unlimited | Add a nearest distance |
| 7 | On a wide free-drawn room, the "Shape" and "Diagonal" buttons can sit over the top-right dimension, and a diagonal's label can sit over a wall letter | Move the buttons out of the drawing area; offset the label |
| 8 | Pages without a footer show a white strip above the gesture bar on a grey page | Extend the page colour to the bottom edge |
| 9 | After the connection returns, the "No internet" message on the log-in screen stays until the next attempt | Clear it when the connection returns |
| 10 | Small grey text (`ink3`) on the grey page is 4.3:1 | Use `ink2` there |
| 11 | The demo account's email looks like a real address | Change it to an `example.com` address |
| 12 | Uzbek Cyrillic is machine-converted; Russian and English are drafts | Native review by the founder |
| 13 | The header of the PDF shows the METRX wordmark | Replace with the logo when it is supplied |
| 14 | The sign-in screens use the colours and type of the founder's Figma (blue `#3355B4`, IBM Plex Mono labels). The rest of the app uses the earlier palette (cobalt `#1C4BD1`) | Founder to decide whether the Figma style replaces the app-wide one |
| 15 | Welcome: the Figma shows "BLE ONLINE", "±1.5 mm PRECISION" and "METRX v2.4 • Toshkent". The prototype shows "Sample room" and the room's height, and no version line, because no laser is connected on this screen and the accuracy and version are not established | Founder to confirm, or supply the real accuracy and version |
| 16 | Welcome: the Figma says "in one minute" about the PDF report, and step 1 says a 4-digit code while the code step has six boxes. The prototype leaves out "in one minute" and says 6-digit | Founder to confirm |
| 17 | The "number has an account" sheet: the Figma's title is a question ("Do you have an account?") and its last link is "Log in by SMS", which the app doesn't have. The prototype says "This number already has an account" and links to "Forgot your password?" | Founder to confirm, or add log-in by SMS to the scope |
| 18 | Sign-up step 1 in the Figma has a tinted page, fields without outlines, a second step counter and a profile button. The prototype keeps the white page, outlined fields and single header of the other Figma frames | Founder to confirm |
| 19 | Sign-in outlines (fields, buttons, code boxes) are 1.5:1 against white, as in the Figma | Darken to about `#8496B0` if the outlines must meet 3:1 |
| 20 | "Terms of Use" and "Privacy Policy" are underlined but open nothing | Write the two documents and link them |

## Needs a real device 📱

- A real Bluetooth laser: pairing, the reference edge, range, a dropped connection, a bad packet.
- Real camera photos and their size in the report.
- Writing a real PDF file with Cyrillic and Uzbek letters, the system share sheet, printing.
- A real backup file: export, restore on a second phone, a truly corrupt file.
- Reading the screen in sunlight; tapping with dusty hands or gloves.
- The system keyboard covering fields, and its decimal key in each language.
- iPhone: safe areas, the back swipe, the keyboard bar, the photo picker.
- Speed and memory on a low-cost Android phone, with a project of 20 or more rooms.
- The web engine crashed once in the background on the emulator. Watch for it on a phone.

## Limits of the prototype that the build must not copy

- Fonts and the 3D library load from the internet. The app must bundle them.
- Data is kept in the browser's local storage. The app needs a real database with atomic writes and versioned backups.
- The on-screen keyboard is drawn by the prototype. The app uses the system keyboard.
- Laser readings, SMS codes, Google sign-in, the camera, GPS, the map, sharing, printing, backup files and subscription state are all simulated.
- Pages of the report are drawn on screen. No PDF file is produced.
