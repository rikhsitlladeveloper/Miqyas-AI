#!/usr/bin/env python3
"""Writes listing.md next to this file: the Play listing texts with their character counts (Unicode characters, what
Play Console counts). Edit the texts here, then run: python design/playstore/make_listing.py
It stops with an error if any text is over Play's limit."""
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent / "listing.md"
LIM = {"name": 30, "short": 80, "full": 4000, "notes": 500}

T = {}

T["uz"] = dict(
    label="Uzbek (Latin) — O‘zbekcha",
    name="METRX: o‘lchash, 3D va smeta",
    name_alt="METRX",
    short="Xonani lazer yoki qo‘lda o‘lchang, 3D da ko‘ring, smeta va PDF taklif bering",
    full="""Xonani o‘lchang, 3D da ko‘ring va mijozga aniq PDF taklif bering. Hammasi telefoningizda, internet bo‘lsa ham, bo‘lmasa ham.

METRX O‘zbekistondagi quruvchilar, mebelchilar va ustalar uchun. O‘lchamlarni Bluetooth lazer bilan oling, ovoz bilan ayting yoki qo‘lda yozing. Ilova xonani aniq o‘lchamda chizadi, 3D da ko‘rsatadi va ish uchun nima kerakligini hisoblaydi.

Sohangizni tanlang
Har bir soha uchun o‘z sodda ilovasi:
• Quruvchi — xonalarni o‘lchash, devorlar 3D da, material va ish smetasi, PDF taklif.
• Mebelchi — oshxona, shkaf, kupe, gorka, karavot, stol va boshqa mebel 3D da. O‘lchamlar qadamma-qadam kiritiladi, mebelni devorga yoki xonaning o‘rtasiga erkin qo‘yasiz, eshiklar bir-biriga tegsa yoki mebel o‘tish joyini to‘sib qo‘ysa, ilova ko‘rsatadi. Avto oshxona: devor va uslubni tanlang, oshxona o‘zi quriladi.
• Kafelchi — naqshni tanlang, har bir kafel va kesik 3D da ko‘rinadi. Soni haqiqiy terishdan hisoblanadi.
• Elektrik — xonalar bo‘yicha rozetka, vyklyuchatel va chiroqlar, shchit, liniyalar va kabel yo‘llari, xavfsizlik ogohlantirishlari.
• Santexnik — jihozlar, stoyak, sovuq va issiq suv, kanalizatsiya va isitish, xonama-xona.
• Deraza-eshik — galereyadagi mahsulotlar o‘lchangan teshiklarga o‘rnatiladi, tabaqalarni o‘zingiz bo‘lasiz.
Sohani istalgan vaqtda Profilda o‘zgartirasiz.

Buyurtmani qulay yo‘l bilan boshlang
Yangi buyurtmadan keyin tanlaysiz: avval xonani o‘lchash yoki darrov o‘lchamlar bilan dizaynga o‘tish. Keyinroq tanlasa ham bo‘ladi.

Lazer bilan, ovoz bilan yoki qo‘lda
METRX ZB-08 Bluetooth lazer o‘lchagichi bilan ishlaydi. O‘lchamni tanlang, lazer tugmasini bosing — masofa shu joyga tushadi. Siz tekshirib, tasdiqlaysiz. Lazer yo‘qmi? Mikrofonni bosib turib «uch ming to‘rt yuz» deng yoki raqamni qo‘lda yozing. Ovoz o‘zbek va rus tilida, telefonning o‘zida taniladi: ovoz paketi (taxminan 50 MB) bir marta Wi-Fi orqali yuklanadi, keyin internet kerak emas.

Barcha sohalar uchun bitta xona muharriri
Xona shaklini tanlang va devorlarni birma-bir kiriting — 999 m gacha. Eshik, deraza yoki rozetkani kerakli devorga sudrab qo‘ying, turini tanlang (bir tabaqali, kupe, arka, balkon bloki va boshqalar) va o‘lchamlarini qadamma-qadam bering. Ichki devorlar tayyor bo‘laklardan yig‘iladi: to‘g‘ri, L, T, yarim devor, ustun, arka — ular o‘zi devorlarga yopishadi, ularga ham eshik, deraza va mebel qo‘yiladi. Devorni suratga oling va ustiga o‘lcham chizing.

Mebelni rasmning o‘zida tahrirlang
Oshxona yoki shkaf modulini bosing: kengligini o‘zgartirish uchun chetini torting, joyini almashtirish uchun bosib turib suring. Pastdagi asboblar qatorida turi, fasad, tutqich, ichki qism, nusxa va o‘chirish bor. Bekor qilish va qaytarish doim yonida.

Mijozga ko‘rsatsa bo‘ladigan 3D
Xonani bir barmoq bilan aylantiring va natijani mijozga shu yerning o‘zida ko‘rsating. Mebelchi mijozga 3D faylni yuboradi: mijoz uni o‘z telefonida aylantirib ko‘radi.

Smeta va PDF taklif
Quruvchi material va ish smetasi hamda chiroyli PDF taklif oladi. Boshqa sohalarda miqdor, narx, raskroy va takliflar Profildagi «Kengaytirilgan rejim»da ochiladi. PDF ni messenjer yoki ulashish menyusi orqali yuboring yoki chop eting. Hisobot tili ilova tilidan boshqa bo‘lishi mumkin.

Obyektga yo‘l
Buyurtmaga obyekt joyini saqlang (faqat siz bosganingizda): GPS aniqlikni metrlarda ko‘rsatadi va uni o‘zi yaxshilaydi, internetsiz ishlaydi. Keyin xarita ilovasida yo‘lni bir bosishda oching.

Internetsiz va hisobsiz
Ro‘yxatdan o‘tish yo‘q, reklama yo‘q, kuzatish yo‘q. Loyihalar, suratlar va o‘lchamlar telefoningizda qoladi. Ilova internetsiz ishlaydi: qurilishda, yerto‘lada, istalgan joyda.

Tillar
O‘zbekcha (lotin va kirill), ruscha va inglizcha.

METRX bepul, reklamasiz.""",
    notes="""METRX Google Play’da birinchi marta!
• Olti soha: quruvchi, mebelchi, kafelchi, elektrik, santexnik, deraza-eshik.
• ZB-08 Bluetooth lazer, ovoz bilan yoki qo‘lda o‘lchash.
• Xona va mebel 3D da, smeta va PDF taklif.
• Internetsiz ishlaydi, hisob ochish shart emas.""",
    notes101="""1.0.1 da yangi:
• Hamma sohaga yangi xona muharriri: devor 999 m gacha, eshik, deraza va nuqtalar devorga sudraladi, turi va o‘lchami qadamma-qadam.
• Tayyor bo‘laklardan ichki devor: to‘g‘ri, L, T, yarim devor, ustun, arka.
• Mebel devorga yoki xona o‘rtasiga erkin, burish va o‘tishni tekshirish bilan.
• Oshxona va shkaf rasmning o‘zida tahrirlanadi: chetini torting, modulni suring.
• Yangi buyurtmada: xonani o‘lchash yoki darrov dizayn.
• GPS aniqligi jonli ko‘rinadi.
• Ko‘plab tuzatishlar.""",
)

T["ru"] = dict(
    label="Russian — Русский (ru-RU)",
    name="METRX: замер, 3D и смета",
    name_alt="METRX",
    short="Замер лазером или вручную, комната и мебель в 3D, смета и PDF для заказчика",
    full="""Замерьте комнату, посмотрите её в 3D и дайте заказчику понятное PDF-предложение. Всё на телефоне, с интернетом и без него.

METRX сделан для строителей, мебельщиков и мастеров Узбекистана. Снимайте размеры Bluetooth-лазером, называйте голосом или вводите вручную. Приложение рисует комнату в точном масштабе, показывает её в 3D и считает, что нужно для работы.

Выберите свою профессию
У каждой профессии своё простое приложение:
• Строитель — замер комнат, стены в 3D, смета на материалы и работу, PDF-предложение.
• Мебельщик — кухни, шкафы, купе, горки, кровати, столы и другая мебель в 3D. Размеры вводятся по шагам, мебель ставится к стене или свободно посреди комнаты, приложение покажет, если двери задевают друг друга или мебель мешает проходу. Автокухня: выберите стену и стиль, кухня соберётся сама.
• Плиточник — выберите рисунок укладки, каждая плитка и каждый рез видны в 3D. Количество считается по настоящей раскладке.
• Электрик — розетки, выключатели и свет по комнатам, щит, линии и трассы кабеля, предупреждения о безопасности.
• Сантехник — приборы, стояк, холодная и горячая вода, канализация и отопление, по комнатам.
• Окна и двери — изделия из галереи встают в замеренные проёмы, створки разбиваете сами.
Профессию можно сменить в любой момент в Профиле.

Начните заказ так, как удобно
После создания заказа выберите: сначала замерить комнату или сразу перейти к дизайну по размерам. Можно выбрать и позже.

Лазером, голосом или вручную
METRX работает с Bluetooth-дальномером ZB-08. Выберите размер, нажмите кнопку лазера — расстояние встанет на место. Вы проверяете и подтверждаете. Нет лазера? Удерживайте микрофон и скажите «три тысячи четыреста» или введите число вручную. Голос распознаётся на самом телефоне, на узбекском и русском: голосовой пакет (около 50 МБ) скачивается один раз по Wi-Fi, дальше интернет не нужен.

Один редактор комнаты для всех профессий
Выберите форму комнаты и введите стены по одной — до 999 м. Перетащите дверь, окно или розетку на нужную стену, выберите вид (одностворчатая, купе, арка, балконный блок и другие) и задайте размеры по шагам. Внутренние стены собираются из готовых частей: прямая, Г, Т, полустена, колонна, арка — они сами примыкают к стенам, на них тоже ставятся двери, окна и мебель. Сфотографируйте стену и нанесите размеры прямо на фото.

Правка мебели прямо на картинке
Нажмите на модуль кухни или шкафа: потяните край, чтобы изменить ширину, удерживайте и перетащите, чтобы переставить. Внизу — панель инструментов: тип, фасад, ручки, наполнение, копия, удаление. Отмена и повтор всегда под рукой.

3D, которое можно показать заказчику
Поворачивайте комнату одним пальцем и показывайте результат заказчику прямо на месте. Мебельщик отправляет заказчику 3D-файл: тот крутит его на своём телефоне.

Смета и PDF-предложение
Строитель получает смету на материалы и работу и аккуратное PDF-предложение. В других профессиях количество, цены, раскрой и предложения открываются в «Расширенном режиме» в Профиле. Отправьте PDF в мессенджер или через меню «Поделиться», или распечатайте. Язык отчёта может отличаться от языка приложения.

Дорога к объекту
Сохраните место объекта в заказе (только когда вы нажмёте): GPS показывает точность в метрах и сам её уточняет, работает без интернета. Потом одним нажатием откройте маршрут в приложении карт.

Без интернета и без аккаунта
Без регистрации, без рекламы, без слежки. Проекты, фото и замеры остаются на вашем телефоне. Приложение работает без интернета: на стройке, в подвале, где угодно.

Языки
Узбекский (латиница и кириллица), русский и английский.

METRX бесплатный и без рекламы.""",
    notes="""Первый выпуск METRX в Google Play!
• Шесть профессий: строитель, мебельщик, плиточник, электрик, сантехник, окна и двери.
• Замер Bluetooth-лазером ZB-08, голосом или вручную.
• Комната и мебель в 3D, смета и PDF-предложение.
• Работает без интернета, аккаунт не нужен.""",
    notes101="""Что нового в 1.0.1:
• Новый редактор комнаты для всех профессий: стены до 999 м, двери, окна и точки перетаскиваются на стену, вид и размеры по шагам.
• Внутренние стены из готовых частей: прямая, Г, Т, полустена, колонна, арка.
• Мебель к стене или свободно в комнате, с поворотом и проверкой проходов.
• Правка кухни и шкафа прямо на картинке: тяните край, переставляйте модули.
• После нового заказа: замер комнаты или сразу дизайн.
• GPS с точностью в реальном времени.
• Много исправлений.""",
)

T["en"] = dict(
    label="English (United States) — en-US",
    name="METRX: Measure, 3D, Estimate",
    name_alt="METRX",
    short="Measure by laser, voice or hand, see rooms in 3D, send estimates and PDF quotes",
    full="""Measure a room, see it in 3D and give your customer a clear PDF quote. All on your phone, with or without internet.

METRX is made for builders, furniture makers and trades in Uzbekistan. Take sizes with a Bluetooth laser, say them out loud or type them by hand. The app draws the room to scale, shows it in 3D and works out what the job needs.

Pick your trade
Each trade gets its own simple app:
• Builder — measure rooms, see the walls in 3D, make a material and labour estimate and a PDF quote.
• Furniture maker — kitchens, wardrobes, sliding-door wardrobes, wall units, beds, tables and more in 3D. Enter sizes step by step, place pieces against a wall or freely in the middle of the room, and see when doors would hit each other or a piece blocks the way. Auto kitchen: pick the wall and a style, and the kitchen builds itself.
• Tiler — pick a pattern and see every tile and every cut in 3D. Counts come from the real layout.
• Electrician — sockets, switches and lights room by room, the panel, circuits and cable routes, with safety warnings.
• Plumber — fixtures, the riser, cold and hot water, drains and heating, room by room.
• Windows and doors — products from the gallery fill the measured openings, and you split the sashes.
You can change your trade at any time in Profile.

Start an order your way
After you create an order, choose: measure the room first, or go straight to the design with your sizes. You can also decide later.

Laser, voice or by hand
METRX works with the ZB-08 Bluetooth laser meter. Pick a size, press the laser’s button and the distance goes in. You check it and confirm it. No laser? Hold the mic and say the number, or type it. Voice works in Uzbek and Russian and is recognised on the phone itself: the voice pack (about 50 MB) downloads once over Wi-Fi, and after that no internet is needed.

One room editor for every trade
Pick the room’s shape and enter the walls one by one, up to 999 m. Drag a door, window or socket onto the right wall, pick its style (single, sliding, arch, balcony block and more) and set its sizes step by step. Build inner walls from ready pieces: straight, L, T, half wall, column and arch. They snap to the walls, and doors, windows and furniture go on them too. Take a photo of a wall and draw the sizes on it.

Edit furniture right on the picture
Tap a kitchen or wardrobe module: drag its edge to change the width, or press and hold to move it. The tool bar below has type, fronts, handles, insides, copy and delete. Undo and redo are always at hand.

3D you can show the customer
Turn the room with one finger and show the customer the result right there on site. Furniture makers can send the customer a 3D file to turn on their own phone.

Estimates and PDF quotes
Builders get a material and labour estimate and a neat PDF quote. In the other trades, quantities, prices, cut lists and quotes open with Advanced mode in Profile. Send the PDF to a messenger or from the share menu, or print it. The report language can differ from the app language.

The way to the site
Save the site’s location in the order (only when you tap): GPS shows its accuracy in metres and keeps improving it, with no internet needed. Later, open the route in your maps app with one tap.

Offline, no account
No sign-up, no ads, no tracking. Your projects, photos and measurements stay on your phone. The app works without internet: on site, in a basement, anywhere.

Languages
Uzbek (Latin and Cyrillic), Russian and English.

METRX is free and has no ads.""",
    notes="""METRX is on Google Play for the first time!
• Six trades: builder, furniture maker, tiler, electrician, plumber, windows and doors.
• Measure with the ZB-08 Bluetooth laser, by voice or by hand.
• Rooms and furniture in 3D, estimates and PDF quotes.
• Works offline, no account needed.""",
    notes101="""What’s new in 1.0.1:
• A new room editor for every trade: walls up to 999 m, drag doors, windows and points onto a wall, pick a style, sizes step by step.
• Inner walls from ready pieces: straight, L, T, half wall, column, arch.
• Furniture against a wall or free in the room, with rotation and passage checks.
• Edit kitchens and wardrobes right on the picture: drag an edge, move modules.
• After a new order: measure the room or go straight to design.
• GPS with live accuracy.
• Many fixes.""",
)

errs = []
for lang, t in T.items():
    for k, lim in (("name", 30), ("short", 80), ("full", 4000), ("notes", 500), ("notes101", 500)):
        n = len(t[k])
        if n > lim:
            errs.append(f"{lang} {k} {n}>{lim}")
if errs:
    print("\n".join(errs)); sys.exit(1)

c = {l: {k: len(t[k]) for k in ("name", "short", "full", "notes", "notes101")} for l, t in T.items()}

md = []
w = md.append
TAG = {"uz": "uz", "ru": "ru-RU", "en": "en-US"}

w("# METRX — Google Play store listing (1.0.1, versionCode 11)")
w("")
w("Generated by `make_listing.py` (edit the texts there, then run `python design/playstore/make_listing.py`). Counts are Unicode "
  "characters, which is what Play Console counts; the script stops if any text is over Play’s limits: app name 30, short "
  "description 80, full description 4000, release notes 500.")
w("")
w("## 1.0.1 steps for the founder")
w("")
w("1.0.0 (versionCode 10) was sent for review on 28 Oct 2026 on the **Closed testing - Alpha** track. 1.0.1 (versionCode 11) "
  "adds the room editor v2, inner walls, free furniture placing, the new designer editing and live-accuracy GPS, plus many fixes.")
w("")
w("1. **Build the AAB** — done by the lead developer: `builds/play-1.0.1/METRX-1.0.1.aab`, version 1.0.1, versionCode 11, "
  "signed with the same upload key as 1.0.0. You don’t need to touch the keystore.")
w("2. **Upload it as a new release on the same track:** Play Console → METRX → Test and release → Testing → Closed testing → "
  "**Closed testing - Alpha** → **Create new release** → upload `METRX-1.0.1.aab`. Release name: `1.0.1 (11)`. "
  "If 1.0.0 is still “In review”: Play Console lets you prepare 1.0.1 now, but sending it adds it to the changes under review and can make the review start again. To keep 1.0.0’s place in the queue, prepare and save the 1.0.1 release as a draft and send it after 1.0.0 is approved.")
w("3. **Paste the release notes:** copy the block under *Ready to paste: 1.0.1 release notes* below into the release’s "
  "“Release notes” box as it is (both language tags included). Then **Next → Save → Send changes for review** "
  "(Publishing overview).")
w("4. **Update the listing drafts:** Grow users → Store presence → Main store listing → **Russian (ru-RU)**: replace the "
  "*Full description* with the Russian one below. Then **Translations → English (en-US)**: replace its *Full description* with "
  "the English one below. App name `METRX: замер, 3D и смета` and both short descriptions stay the same. Save; the listing goes "
  "to review together with the release.")
w("5. **Screenshots: change nothing.** Keep the 8 Russian and 8 English phone screenshots already uploaded, the icon and the "
  "feature graphic.")
w("6. The testers who already joined get 1.0.1 as a normal Play update; the 14-day closed-test counter is not reset.")
w("")
w("## Ready to paste: 1.0.1 release notes")
w("")
w(f"Russian {c['ru']['notes101']} / 500, English {c['en']['notes101']} / 500 characters (Play counts each language "
  "separately; the tags don’t count).")
w("")
w("```text")
w("<ru-RU>"); w(T["ru"]["notes101"]); w("</ru-RU>")
w("<en-US>"); w(T["en"]["notes101"]); w("</en-US>")
w("```")
w("")
w("## Store languages (decided)")
w("")
w("Play has no Uzbek store-listing language ([Play Console Help: list of available languages]"
  "(https://support.google.com/googleplay/android-developer/answer/9844778)), so the listing is **Russian (ru-RU) default + "
  "English (en-US)**, as saved in Play Console on 28 Oct 2026. The Uzbek texts below are kept for the website and for the day "
  "Play adds Uzbek. The app itself still opens in Uzbek.")
w("")
w("## Count summary")
w("")
w("| Field | Limit | Uzbek | Russian | English |")
w("|---|---:|---:|---:|---:|")
w(f"| App name (in use) | 30 | {c['uz']['name']} | {c['ru']['name']} | {c['en']['name']} |")
w(f"| Short description | 80 | {c['uz']['short']} | {c['ru']['short']} | {c['en']['short']} |")
w(f"| Full description (1.0.1) | 4000 | {c['uz']['full']} | {c['ru']['full']} | {c['en']['full']} |")
w(f"| Release notes 1.0.1 | 500 | {c['uz']['notes101']} | {c['ru']['notes101']} | {c['en']['notes101']} |")
w(f"| Release notes 1.0.0 (sent) | 500 | {c['uz']['notes']} | {c['ru']['notes']} | {c['en']['notes']} |")
w("")
w("Texts follow Play’s metadata rules: no prices or “free” in the title, no “best/#1”, no emojis, no ALL-CAPS headings, and no "
  "other brand or app named except the ZB-08 laser, only to say it is compatible. Uzbek Latin uses ‘ (U+2018) in o‘ and g‘ and "
  "’ (U+2019) for the apostrophe.")
w("")

for lang in ("uz", "ru", "en"):
    t = T[lang]
    w("---")
    w("")
    w(f"## {t['label']}")
    w("")
    w(f"### App name — {c[lang]['name']} / 30" + (" (in use, unchanged)" if lang != "uz" else " (website only)"))
    w("")
    w("```text"); w(t["name"]); w("```")
    w("")
    w(f"### Short description — {c[lang]['short']} / 80 (unchanged)")
    w("")
    w("```text"); w(t["short"]); w("```")
    w("")
    w(f"### Full description for 1.0.1 — {c[lang]['full']} / 4000" + (" (paste over the old one)" if lang != "uz" else ""))
    w("")
    w("```text"); w(t["full"]); w("```")
    w("")
    w(f"### Release notes for 1.0.1 — {c[lang]['notes101']} / 500")
    w("")
    if lang == "uz":
        w("Not used on Play (no Uzbek store language); kept for the website, Telegram and the in-app “what’s new”.")
    else:
        w(f"Already inside the *Ready to paste* block above, wrapped in `<{TAG[lang]}>` … `</{TAG[lang]}>`.")
    w("")
    w("```text"); w(t["notes101"]); w("```")
    w("")
    w(f"### Release notes for 1.0.0 — {c[lang]['notes']} / 500 (already sent, for reference)")
    w("")
    w("```text"); w(t["notes"]); w("```")
    w("")

w("---")
w("")
w("## Store settings (Grow users → Store presence → Store settings)")
w("")
w("### App or game: **App**")
w("")
w("### Category — recommended: **House & Home**; alternative: **Productivity**")
w("")
w("- **House & Home (recommended for Play).** Play’s House & Home category is where renovation, furniture, interior and "
  "floor-plan apps live, and it is what people in Uzbekistan browse when they think “ремонт / мебель / ta’mir”. In a small "
  "country the category’s top charts are short, so a new app with a few hundred installs can appear in them — free visibility "
  "that Productivity (crowded with office, notes and e-mail apps from big companies) won’t give.")
w("- **Productivity (alternative).** Matches the App Store choice and says “work tool”. Choose it if you want the two stores "
  "to match.")
w("- **Not Tools.** On Play, Tools is for phone utilities (flashlights, cleaners, file managers, plain tape-measure apps). It "
  "undersells 3D, estimates and quotes.")
w("- **Not Business.** Fits the quotes and prices, but the trades don’t browse Business for a measuring tool.")
w("- You can change the category any time; it does not need a new release.")
w("")
w("### Tags (up to 5, picked from Play’s list)")
w("")
w("Play Console only lets you pick tags from its own list, which changes by category. After choosing the category, open "
  "**Manage tags** and pick the closest 5 of these, in this order: **Home improvement / Renovation**, **Interior design**, "
  "**Measurement / Measuring tools**, **Furniture**, **Floor plans / 3D design**, then **Construction** or **Business tools** if "
  "they are offered. Don’t pick tags that don’t describe the app (Play may remove irrelevant tags).")
w("")
w("### Store listing contact details")
w("")
w("| Field | Value |")
w("|---|---|")
w("| Email (required, shown publicly) | `developer.sanjar@gmail.com` |")
w("| Phone (optional) | leave empty unless you want it public |")
w("| Website (optional) | `https://metrxai.uz` once the domain points to the site; until then `https://metrx-site.pages.dev` |")
w("| Privacy policy (App content → Privacy policy) | `https://metrx-site.pages.dev/privacy` (live; saved in Play Console). Switch to `https://metrxai.uz/privacy` once the domain works. Source: `web/metrx-site/privacy.html` (copy: `design/playstore/privacy-android.html`) |")
w("")
w("### External marketing: leave **on** (lets Google show the app in ads/surfaces outside Play at no cost to you).")
w("")
w("## Graphics (Main store listing → Graphics)")
w("")
w("| Asset | File | Play’s rule | Status |")
w("|---|---|---|---|")
w("| App icon | `graphics/icon-512.png` | 512 × 512, 32-bit PNG, ≤ 1 MB, full square (Play rounds the corners) | 512 × 512 RGBA, 14 KB, identical to the app icon |")
w("| Feature graphic | `graphics/feature-graphic-1024x500.png` | 1024 × 500, JPEG or 24-bit PNG (no alpha), ≤ 15 MB | 1024 × 500 RGB, 166 KB |")
w("| Phone screenshots | see `screenshots.md` | 2–8, PNG/JPEG, 320–3840 px, long side ≤ 2 × short side | 8 ru + 8 en uploaded with 1.0.0 (`screenshots/ru`, `screenshots/en`); keep them for 1.0.1 |")
w("| Video (optional) | YouTube link | public or unlisted, no ads | the ZB-08 laser video would fit here |")
w("")
w("The feature graphic’s text is Uzbek (“Lazer o‘lchash · 3D · Smeta”). If the default listing is Russian, either keep it (it "
  "is the brand line and readable to the audience) or ask for a Russian version (`make_graphics.py` takes a minute to change).")
w("")
w("## What the texts promise — must stay true in the AAB you upload")
w("")
w("- No sign-up or log-in screen (`AuthFlags.accounts = false` in the current code — keep it so).")
w("- Free, no purchases, no ads; no “METRX Pro” card (the `gl.pro` string exists but is not used).")
w("- The ZB-08 laser connects; voice input works in Uzbek and Russian after the voice pack download; auto kitchen, client 3D "
  "file and route to the site are in the build.")
w("- Four app languages; PDF quotes for the builder; Advanced mode for the other trades.")
w("- New in 1.0.1, named in the description and notes: the start dialog after a new order (measure the room / design only), "
  "walls up to 999 m, drag-on doors/windows/points with styles and step-by-step sizes, one room editor for every trade, inner "
  "walls from ready pieces, furniture against a wall or free (rotation, red/yellow passage checks), editing cabinets right on "
  "the picture (edge drag, long-press move, tool bar, undo/redo), and GPS with live accuracy. Not promised: free kitchen runs "
  "(kitchens stay on walls) and inner walls in the PDF plan.")
w("- If Advanced mode becomes paid later (the website says “Tez orada · Advanced … Narxi keyin e’lon qilinadi”), it must use "
  "Google Play Billing and the description’s “bepul / free” line must change.")

OUT.write_text("\n".join(md) + "\n", encoding="utf-8")
print(c)
