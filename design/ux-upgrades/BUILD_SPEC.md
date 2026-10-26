# UX upgrades — build spec (approved 26 Oct 2026)

The approved mockup is `design/ux-upgrades/mockup.html` (published at https://claude.ai/artifact/DBvAy1pw7WWvELoYn7rRUY). Open it in a browser and click through the "Yangi" mode, because it is the reference for layout, wording and behaviour. The audit behind it is in `design/UX_AUDIT_2026-10-26.md`.

The rules below apply to the **furniture maker** flow first. Builders get the shared parts (bottom toasts, laser at sizes, haptics, almost-solid bars) but keep metres.

## 1. Inside an order or a designer
- Hide the Asosiy / Buyurtmalar / Profil tab bar.
- The top bar has Back and the order name. The name wraps to 2 lines and is never cut.
- A **bottom action bar**, within thumb reach, has:
  - one big next-step button;
  - a small Undo;
  - in the designers only, a 2D/3D switch.
- Remove the dark "Keyingi qadam" card and any second "next" button, so the next step appears only once.
- The order screen has two tabs: **Mebel** and **Ma'lumot**.
  - Ma'lumot holds the client details and the **7 production stages**, which are no longer on the main page. Advanced mode changes stages there.

## 2. Progress bar
- Every order shows **Xona → Mebel → Dizayn → Narx → PDF**:
  - done steps show ✓;
  - the current step is blue;
  - Xona shows "–" when the order has no room.
- Each step can be tapped and opens that place.
- In simple mode the last step is called **"Yuborish"**; in Advanced it is "PDF".
- The designer shows a compact version.
- Order cards on Home and in Buyurtmalar show a small 5-segment line plus "Keyingi: <step>".

## 3. Feedback
- Toasts appear at the **bottom**, just above the bottom bar, with a **48 dp/pt "Ortga qaytarish"** (Undo) button.
- Toasts never cover Back.
- Quick actions in the designers (door, handle, style…) each give a toast with Undo.

## 4. Price
- Simple mode shows a grey "≈ 12 345 000 so‘m (taxminiy)" in:
  - the order header;
  - the order cards;
  - the designer price chip;
  - the price screen.
- Advanced keeps the exact price, cost and profit.

## 5. Units
- Furniture makers use **millimetres everywhere**, including the size steps: "3400 mm", with no decimals.
- Builders keep metres.
- Profile has a "Mebel uchun o‘lcham birligi" setting: Millimetr / Santimetr / Metr, default mm.

## 6. Size steps
- A big number field with the native numeric keyboard. The mockup's keypad only stands in for the system keyboard.
- Below the field, always visible:
  - a **laser button**: "Lazerni ulash" when no laser is connected (it opens the existing radar search), and "Lazer · o‘lchash" when connected;
  - a **hold-to-talk mic**.
- A laser or voice value **flashes the field** (a short green glow) and gives a haptic tick.
- A wrong number shows an inline error, for example "Raqam noto‘g‘ri. Masalan: 3400", plus a warning haptic.

## 7. Shorter start
- The **style is picked in the gallery**: a horizontal style row on top, and the cards repaint at once. The separate "Dizayn uslubi" screen goes away.
- **"Qaysi xonaga?" is skipped** when the order has no measured room: the piece is placed room-less and the flow goes straight to the designer.
- **Templates keep the style and layout, with sizes refit** to the new room.

## 8. Telegram
- The price screen has a big main **"Telegram’ga yuborish"** button and a small "Boshqa…" underneath for the system share sheet.
  - **Android** opens Telegram directly (package `org.telegram.messenger`, then `org.telegram.messenger.web`/`org.thunderdog.challegram`). If none is installed it falls back to the share sheet.
  - **iPhone** uses the share sheet.
- Sending through Telegram **issues (freezes) the quote** at once, with no confirm sheet. A toast offers Undo, which returns the quote to a draft.
- The "Qoralamani ulashish" and "Taklifni chiqarish" buttons show their full text and wrap to 2 lines when needed.

## 9. Voice
- Uzbek and Russian, **hold-to-talk** on a size field, fully **offline**.
- The engine pack (about 50 MB per language) **downloads on first use, over Wi-Fi only**.
  - A first-use sheet reads "Ovoz paketi (50 MB) — Wi-Fi da yuklab olish" with Keyinroq.
  - Profile shows the pack's state: not loaded / loading with a progress bar / ready.
- Number words map to millimetres: "uch ming to‘rt yuz" → 3400, "три тысячи четыреста" → 3400, "ikki yarim metr" → 2500, and digits as said.
- The result is written into the field straight away, with a "Bekor" chip that restores the previous value.
- A shared parser test list lives in `design/ux-upgrades/voice-cases.json`. Both apps must pass it.
- The app needs a microphone permission. Audio never leaves the phone.

## 10. Haptics
- On by default, with a Profile switch "Tebranish (haptik)". There is no sound.
- Kinds:
  - **tick:** a step, an undo, a switch;
  - **confirm:** a laser or voice value, a quote sent;
  - **warn:** an error.

## 11. Help
- On first launch, **3 tour cards** with "O‘tkazib yuborish": measure (laser/voice), the 3D gallery, Telegram send.
- After the tour, **coach marks** appear the first time on each screen: order, gallery, size, designer and price, as in the mockup.
- Profile → "Maslahatlarni qayta ko‘rsatish" restores the tour, the coach marks and the sample order.
- A **"Namuna — oshxona" sample order** (an L kitchen, style "Tabiiy yog‘och", 3400 × 2600 room):
  - it has a NAMUNA badge;
  - it can be deleted in one tap, with Undo;
  - it is **never counted** in reports, totals or counts.

## 12. Look
- The header and bottom bars are almost solid (about 92–96 % opacity of the glass colour), with blur only at the edges, so text is readable over the drawing.

## Strings
- All new strings go into the one-line `android-native/app/src/main/assets/strings.json` as `"key":["uz","uzc","ru","en"]` with the prefix `ux.`. Use the Uzbek ‘ (U+2018).
- The ru and uz-Cyrillic texts are drafts for founder review.
- On a merge or rebase conflict in strings.json, run `python design/tools/merge_strings.py`.
