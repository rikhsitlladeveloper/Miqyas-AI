# METRX — App Store listing texts (iPhone, first release)

Paste each block into App Store Connect → the app → the version → the language. App Store Connect has **no Uzbek** store language, so **Russian is the primary language** and **English** is the second localization. The app itself still opens in Uzbek (and has Russian and English inside).

Counts are Unicode characters (what App Store Connect counts), checked by a script against Apple’s limits: name 30, subtitle 30, promotional text 170, description 4000, keywords 100, What’s New 4000.

Rules kept: keywords are comma-separated with no spaces after commas, don’t repeat the app name, and don’t repeat words already in the subtitle (Apple indexes name, subtitle and keywords together). No other brands or app names are used, except the ZB-08 laser, only to say it is compatible. Everything described is in the current iPhone build (ios-native at 29cf63e and later): the start dialog after a new order, the shared room editor (walls up to 999 m, openings with styles and size steps, inner walls from ready pieces), furniture against a wall or free, editing cabinets on the picture, live-accuracy GPS, voice input, auto kitchen and the client 3D file.

## Count summary

| Field | Limit | Russian | English |
|---|---:|---:|---:|
| App name | 30 | 5 | 5 |
| Subtitle | 30 | 26 | 29 |
| Promotional text | 170 | 157 | 157 |
| Description | 4000 | 3588 | 3494 |
| Keywords | 100 | 96 | 99 |
| What’s New | 4000 | 484 | 487 |

---

## Russian — Русский (primary language)

### App name

```text
METRX
```

### Subtitle

```text
Лазерный замер, 3D и смета
```

### Promotional text

Can be changed at any time without a new review.

```text
Новое: один редактор комнаты для всех профессий, внутренние стены, мебель свободно в комнате и правка шкафов прямо на картинке. Без интернета и без аккаунта.
```

### Description

```text
Замерьте комнату, посмотрите её в 3D и дайте заказчику понятное PDF-предложение. Всё на телефоне, с интернетом и без него.

METRX сделан для строителей, мебельщиков и мастеров Узбекистана. Снимайте размеры Bluetooth-лазером, называйте голосом или вводите вручную. Приложение рисует комнату в точном масштабе, показывает её в 3D и считает, что нужно для работы.

ВЫБЕРИТЕ СВОЮ ПРОФЕССИЮ
У каждой профессии своё простое приложение:
• Строитель — замер комнат, стены в 3D, смета на материалы и работу, PDF-предложение.
• Мебельщик — кухни, шкафы, купе, горки, кровати, столы и другая мебель в 3D. Размеры вводятся по шагам, мебель ставится к стене или свободно посреди комнаты, приложение покажет, если двери задевают друг друга или мебель мешает проходу. Автокухня: выберите стену и стиль, кухня соберётся сама.
• Плиточник — выберите рисунок укладки, каждая плитка и каждый рез видны в 3D. Количество считается по настоящей раскладке.
• Электрик — розетки, выключатели и свет по комнатам, щит, линии и трассы кабеля, предупреждения о безопасности.
• Сантехник — приборы, стояк, холодная и горячая вода, канализация и отопление, по комнатам.
• Окна и двери — изделия из галереи встают в замеренные проёмы, створки разбиваете сами.
Профессию можно сменить в любой момент в Профиле.

НАЧНИТЕ ЗАКАЗ ТАК, КАК УДОБНО
После создания заказа выберите: сначала замерить комнату или сразу перейти к дизайну по размерам. Можно выбрать и позже.

ЛАЗЕРОМ, ГОЛОСОМ ИЛИ ВРУЧНУЮ
METRX работает с Bluetooth-дальномером ZB-08. Выберите размер, нажмите кнопку лазера — расстояние встанет на место. Вы проверяете и подтверждаете. Нет лазера? Удерживайте микрофон и скажите «три тысячи четыреста» или введите число вручную. Голос распознаётся на самом телефоне, на узбекском и русском: голосовой пакет (около 57 МБ) скачивается один раз по Wi-Fi, дальше интернет не нужен.

ОДИН РЕДАКТОР КОМНАТЫ ДЛЯ ВСЕХ ПРОФЕССИЙ
Выберите форму комнаты и введите стены по одной — до 999 м. Перетащите дверь, окно или розетку на нужную стену, выберите вид (одностворчатая, купе, арка, балконный блок и другие) и задайте размеры по шагам. Внутренние стены собираются из готовых частей: прямая, Г, Т, полустена, колонна, арка — они сами примыкают к стенам, на них тоже ставятся двери, окна и мебель. Сфотографируйте стену и нанесите размеры прямо на фото.

ПРАВКА МЕБЕЛИ ПРЯМО НА КАРТИНКЕ
Нажмите на модуль кухни или шкафа: потяните край, чтобы изменить ширину, удерживайте и перетащите, чтобы переставить. Внизу — панель инструментов: тип, фасад, ручки, наполнение, копия, удаление. Отмена и повтор всегда под рукой.

3D, КОТОРОЕ МОЖНО ПОКАЗАТЬ ЗАКАЗЧИКУ
Поворачивайте комнату одним пальцем и показывайте результат заказчику прямо на месте. Мебельщик отправляет заказчику 3D-файл: тот крутит его на своём телефоне.

СМЕТА И PDF-ПРЕДЛОЖЕНИЕ
Строитель получает смету на материалы и работу и аккуратное PDF-предложение. В других профессиях количество, цены, раскрой и предложения открываются в «Расширенном режиме» в Профиле. Отправьте PDF через меню «Поделиться» или распечатайте. Язык отчёта может отличаться от языка приложения.

ДОРОГА К ОБЪЕКТУ
Сохраните место объекта в заказе (только когда вы нажмёте): GPS показывает точность в метрах и сам её уточняет, работает без интернета. Потом одним нажатием откройте маршрут в приложении карт.

БЕЗ ИНТЕРНЕТА И БЕЗ АККАУНТА
Без регистрации, без рекламы, без слежки. Проекты, фото и замеры остаются на вашем телефоне. Приложение работает без интернета: на стройке, в подвале, где угодно.

ЯЗЫКИ
Узбекский (латиница и кириллица), русский и английский.

METRX бесплатный и без рекламы.
```

### Keywords

```text
рулетка,дальномер,ремонт,строитель,мебель,кухня,шкаф,плитка,электрик,сантехник,окна,двери,чертеж
```

### What’s New

App Store Connect asks for this only from the second version on; keep it for then (or for the TestFlight “What to Test” box).

```text
Первый выпуск METRX в App Store!
• Шесть профессий: строитель, мебельщик, плиточник, электрик, сантехник, окна и двери.
• Один редактор комнаты для всех: стены до 999 м, двери, окна и точки перетаскиваются на стену, внутренние стены из готовых частей.
• Мебель к стене или свободно в комнате, правка шкафов прямо на картинке.
• Замер Bluetooth-лазером ZB-08, голосом или вручную; GPS с точностью в реальном времени.
• Смета и PDF-предложение. Работает без интернета, аккаунт не нужен.
```

---

## English (second localization)

### App name

```text
METRX
```

### Subtitle

```text
Laser measure, 3D & estimates
```

### Promotional text

```text
New: one room editor for every trade, inner walls, furniture anywhere in the room and cabinet editing right on the picture. Works offline, no account needed.
```

### Description

```text
Measure a room, see it in 3D and give your customer a clear PDF quote. All on your phone, with or without internet.

METRX is made for builders, furniture makers and trades in Uzbekistan. Take sizes with a Bluetooth laser, say them out loud or type them by hand. The app draws the room to scale, shows it in 3D and works out what the job needs.

PICK YOUR TRADE
Each trade gets its own simple app:
• Builder — measure rooms, see the walls in 3D, make a material and labour estimate and a PDF quote.
• Furniture maker — kitchens, wardrobes, sliding-door wardrobes, wall units, beds, tables and more in 3D. Enter sizes step by step, place pieces against a wall or freely in the middle of the room, and see when doors would hit each other or a piece blocks the way. Auto kitchen: pick the wall and a style, and the kitchen builds itself.
• Tiler — pick a pattern and see every tile and every cut in 3D. Counts come from the real layout.
• Electrician — sockets, switches and lights room by room, the panel, circuits and cable routes, with safety warnings.
• Plumber — fixtures, the riser, cold and hot water, drains and heating, room by room.
• Windows and doors — products from the gallery fill the measured openings, and you split the sashes.
You can change your trade at any time in Profile.

START AN ORDER YOUR WAY
After you create an order, choose: measure the room first, or go straight to the design with your sizes. You can also decide later.

LASER, VOICE OR BY HAND
METRX works with the ZB-08 Bluetooth laser meter. Pick a size, press the laser’s button and the distance goes in. You check it and confirm it. No laser? Hold the mic and say the number, or type it. Voice works in Uzbek and Russian and is recognised on the phone itself: the voice pack (about 57 MB) downloads once over Wi-Fi, and after that no internet is needed.

ONE ROOM EDITOR FOR EVERY TRADE
Pick the room’s shape and enter the walls one by one, up to 999 m. Drag a door, window or socket onto the right wall, pick its style (single, sliding, arch, balcony block and more) and set its sizes step by step. Build inner walls from ready pieces: straight, L, T, half wall, column and arch. They snap to the walls, and doors, windows and furniture go on them too. Take a photo of a wall and draw the sizes on it.

EDIT FURNITURE RIGHT ON THE PICTURE
Tap a kitchen or wardrobe module: drag its edge to change the width, or press and hold to move it. The tool bar below has type, fronts, handles, insides, copy and delete. Undo and redo are always at hand.

3D YOU CAN SHOW THE CUSTOMER
Turn the room with one finger and show the customer the result right there on site. Furniture makers can send the customer a 3D file to turn on their own phone.

ESTIMATES AND PDF QUOTES
Builders get a material and labour estimate and a neat PDF quote. In the other trades, quantities, prices, cut lists and quotes open with Advanced mode in Profile. Send the PDF from the share menu or print it. The report language can differ from the app language.

THE WAY TO THE SITE
Save the site’s location in the order (only when you tap): GPS shows its accuracy in metres and keeps improving it, with no internet needed. Later, open the route in your maps app with one tap.

OFFLINE, NO ACCOUNT
No sign-up, no ads, no tracking. Your projects, photos and measurements stay on your phone. The app works without internet: on site, in a basement, anywhere.

LANGUAGES
Uzbek (Latin and Cyrillic), Russian and English.

METRX is free and has no ads.
```

### Keywords

```text
rangefinder,room,renovation,builder,furniture,kitchen,wardrobe,tile,electrician,plumber,window,door
```

### What’s New

```text
METRX is on the App Store for the first time!
• Six trades: builder, furniture maker, tiler, electrician, plumber, windows and doors.
• One room editor for all: walls up to 999 m, drag doors, windows and points onto a wall, inner walls from ready pieces.
• Furniture against a wall or free in the room; edit cabinets right on the picture.
• Measure with the ZB-08 Bluetooth laser, by voice or by hand; GPS with live accuracy.
• Estimates and PDF quotes. Works offline, no account needed.
```

---

## App Store Connect fields outside the texts

| Field | Value |
|---|---|
| Primary language | Russian |
| Localizations | Russian, English (U.S.) |
| Privacy Policy URL | `https://metrx-site.pages.dev/privacy` (switch to `https://metrxai.uz/privacy` once the domain works) |
| Support URL | `https://metrx-site.pages.dev` |
| Marketing URL | leave empty |
| Support email (App Review contact) | `developer.sanjar@gmail.com` |
| Copyright | `2026 <your full name>` (the individual account’s legal name) |
| Category | Productivity (primary), Business (secondary) — see `app-privacy.md` §4 |
| Price | Free, no in-app purchases |
| Availability | Uzbekistan first |

## Notes and open choices

1. **Uzbek.** App Store Connect has no Uzbek store language, so the Uzbek texts are not used here (they live on the website). Don’t put Uzbek text into another language’s slot (for example English U.K.): Apple expects each localization in its own language, which is a review risk.
2. **The name METRX** may already be taken on the App Store. App Store Connect says so when you create the app record. Fallbacks within 30 characters: “METRX: замер, 3D и смета” (24, the Play name), “METRX Smeta” (11), “METRX Measure” (13).
3. **What the texts promise, and must stay true in the build you send:** no sign-up (sign-in screens hidden, `AuthFlags.accounts = false`), free with no purchases (no “METRX Pro” card), the ZB-08 laser connects, voice input after the voice pack download, PDF quotes for the builder, Advanced mode for the other trades, four app languages, and the new room editor, inner walls, free furniture and on-picture editing. Not promised: kitchen runs standing free (kitchens stay on walls) and inner walls in the PDF plan.
4. **Promotional text** can be changed at any time without a new review; the rest changes only with a new version.
5. **Screenshots** come from `.github/workflows/ios-screenshots.yml` (tag `shots-*`), framed by `frame_shots.py` with `captions.json`: 6.9-inch, 1320 × 2868. Upload the Russian set to the Russian localization and the English set to English (the Uzbek set is for the website).
