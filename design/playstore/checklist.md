# METRX (Android) — Google Play Console checklist

Package `uz.metrx.app` · free · no ads · no in-app purchases · no account. Personal developer account. Files referenced here are in `design/playstore/`.

## 1.0.1 (versionCode 11) — steps for the founder

State on 28 Oct 2026: 1.0.0 (versionCode 10) is in Google's review on **Closed testing - Alpha**, with the Russian listing (default), the English translation, the icon, the feature graphic and 8 ru + 8 en screenshots. 1.0.1 adds the room editor v2 (start dialog, walls up to 999 m, openings with styles and size steps, one room editor for every trade), inner walls from ready pieces, "Mebel joylash" (furniture against a wall or free), Designer C v2 (editing cabinets on the picture), live-accuracy GPS and many fixes.

| # | Step | Who |
|---|---|---|
| 1 | **Build the AAB**: `builds/play-1.0.1/METRX-1.0.1.aab`, versionName `1.0.1`, versionCode `11`, signed with the existing upload key (the same as 1.0.0). Check it has no debug-only `PreviewActivity`. | lead developer |
| 2 | **Upload it**: Test and release → Testing → Closed testing → **Closed testing - Alpha** → **Create new release** → upload `METRX-1.0.1.aab` (the upload key is recognised automatically). Release name `1.0.1 (11)`. If 1.0.0 is still in review, save 1.0.1 as a draft and send it after 1.0.0 is approved, so the first review doesn't restart. | **[F]** |
| 3 | **Paste the release notes**: the `<ru-RU>…</ru-RU>` `<en-US>…</en-US>` block from `listing.md` → *Ready to paste: 1.0.1 release notes*, as it is, into the release's "Release notes" box. | **[F]** |
| 4 | **Update the listing drafts**: Grow users → Store presence → Main store listing (Russian) → *Full description* = the Russian 1.0.1 text in `listing.md`; Translations → English (en-US) → *Full description* = the English 1.0.1 text. Name and short descriptions stay. Save. | **[F]** |
| 5 | **Screenshots: keep the existing 8 ru + 8 en.** Don't delete or replace them; the icon and feature graphic stay too. | **[F]** |
| 6 | **Send for review**: Publishing overview → Send changes for review. Testers get 1.0.1 as a normal update; the 14-day closed-test count is not reset by an update. | **[F]** |
| 7 | Never open, copy or move the keystore in `D:\WORKDESK\TOKENS`; keep its offline backup as it is. | **[F]** |

---

## Reference: the full 1.0.0 setup (done on 28 Oct 2026)


**Who does what:** **[F]** = only the founder can do it (his Google account, identity, money, legal acceptances, testers). **[A]** = anyone with access to the Play Console account (the founder, or someone he invites under *Users and permissions*) — the texts and answers are ready in this folder.

---

## 0. Before you start

| # | Step | Who |
|---|---|---|
| 0.1 | **Developer account** at play.google.com/console: choose **Personal**, pay the one-time US$25, verify identity (passport/ID), verify the contact email and phone, and verify an Android phone with the *Play Console* app. Identity checks can take a few days. | **[F]** |
| 0.2 | Developer name on the store (e.g. "METRX" or your name) and the public developer email `developer.sanjar@gmail.com`. Play shows the developer name and email on the store page. | **[F]** |
| 0.3 | **Privacy policy**: live at `https://metrx-site.pages.dev/privacy` (source `web/metrx-site/privacy.html`, copy `privacy-android.html`); `https://metrxai.uz/privacy` once the domain works. **Done.** The 1.0.1 wording (GPS warm-up, PDF location only for builders) is in the source and needs one deploy. | done; redeploy for 1.0.1 |
| 0.4 | Check the AAB exists: `C:\Users\User\Desktop\METRX\builds\play-1.0.0\METRX-1.0.0.aab` (not there yet on 28 Oct — another agent is building it). Confirm in it: `versionName 1.0.0`, a **new versionCode** (the working tree still says `versionCode = 8`, `0.7.1`), signed with the upload key below, and no `androidx.compose.ui.tooling.PreviewActivity` in its manifest (debug-only). | [A] |
| 0.5 | Keep a backup of the upload keystore (`D:\WORKDESK\TOKENS\…`) and its passwords somewhere safe and offline. If it's lost, Play can reset the upload key, but only after a support request. | **[F]** |

## 1. Create the app

**Play Console → Home → Create app**

| Field | Value | Who |
|---|---|---|
| App name | `METRX` (or the longer name from `listing.md`; can be changed later) | [A] |
| Default language | **Russian – ru-RU** (Uzbek isn't on Play's language list — see `listing.md`; if the picker does show Uzbek, choose it) | **[F]** decides |
| App or game | **App** | [A] |
| Free or paid | **Free** — note: a free app can **never** be changed to paid later. A paid Advanced mode would have to be an in-app purchase/subscription through Google Play Billing. | **[F]** |
| Declarations | Developer Program Policies ✓, US export laws ✓ | **[F]** (legal acceptance) |

## 2. App content (Policy → App content) — all must say *Completed*

| # | Item | Answer | Where it's written |
|---|---|---|---|
| 2.1 | **Privacy policy** | `https://metrx-site.pages.dev/privacy.html` (switch to `https://metrxai.uz/privacy.html` later) | step 0.3 |
| 2.2 | **Ads** | No, my app does not contain ads | `content-rating.md` §3 |
| 2.3 | **App access** | All functionality is available without any special access | `content-rating.md` §4 |
| 2.4 | **Content rating** (IARC) | category *All Other App Types*, all content questions **No** → Everyone / PEGI 3 | `content-rating.md` §1 — **[F]** accepts the IARC terms |
| 2.5 | **Target audience** | **18 and over** only; doesn't appeal to children → not in Families | `content-rating.md` §2 |
| 2.6 | **Data safety** | "Does your app collect or share…?" **No**; no account creation | `data-safety.md` |
| 2.7 | **Advertising ID** | No | `data-safety.md` §5 |
| 2.8 | **Government apps** | No | `content-rating.md` §5 |
| 2.9 | **Financial features** | My app doesn't provide any financial features | `content-rating.md` §6 |
| 2.10 | **Health apps** | My app does not have any health features | `content-rating.md` §7 |
| 2.11 | **News apps** | No | `content-rating.md` §8 |
| 2.12 | Anything else Play lists (COVID-19 apps, etc.) | Not applicable / No | `content-rating.md` §9 |

## 3. Store listing (Grow users → Store presence)

| # | Step | Who |
|---|---|---|
| 3.1 | **Main store listing** (default language): app name, short description, full description — paste from `listing.md` (Russian block if the default is Russian). | [A] |
| 3.2 | **Translations → Add your own translations**: English (en-US) from `listing.md`; Uzbek only if Play offers it. Don't use machine translation. | [A] |
| 3.3 | **Graphics**: app icon `graphics/icon-512.png`; feature graphic `graphics/feature-graphic-1024x500.png`; phone screenshots (8, 1080 × 1920) made per `screenshots.md`. | [A] (screenshots after the release test) |
| 3.4 | **Store settings**: category **House & Home** (or Productivity — `listing.md` explains), up to 5 tags, email `developer.sanjar@gmail.com`, website `https://metrx-site.pages.dev` until `https://metrxai.uz` works. | **[F]** picks the category |

## 4. Closed testing — required before production for this account

Personal accounts created after 13 Nov 2023 must run a **closed test with at least 12 testers who stay opted in for the last 14 days in a row** before the **Apply for production** button unlocks. (Google lowered it from 20 to 12 testers in Dec 2024.) Internal testing does **not** count.

| # | Step | Who |
|---|---|---|
| 4.1 | **Find 15–20 testers** (more than 12, because anyone who opts out or uninstalls during the 14 days drops out of the count). Builders, furniture makers, friends — each needs a **Google account** and an **Android phone** with Play Store, in a country the test is available in. | **[F]** |
| 4.2 | Make a tester list: either a **Google Group** (groups.google.com → create group, e.g. `metrx-testers@googlegroups.com`, add members or let them join) — easiest to manage — or an **email list** in Play Console (Test and release → Testing → Closed testing → Testers → Create email list; paste their Gmail addresses). | **[F]** |
| 4.3 | **Test and release → Testing → Closed testing → Create track** (or use the default "Closed testing – Alpha"). Countries/regions: **Uzbekistan** (+ any country a tester lives in). Testers: select the Google Group or email list. Feedback channel: `developer.sanjar@gmail.com` or a Telegram group link. | [A] |
| 4.4 | **Create release** on that track → **Play App Signing**: choose *"Use Google-generated key"* (default — **Google manages the app signing key**; we only keep the upload key). Upload `METRX-1.0.0.aab`. Play records our **upload key** from the AAB — check it shows SHA-256 starting `FE:93:C5:04` and ending `D5:28` under *Setup → App signing → Upload key certificate*. Release name `1.0.0`; release notes from `listing.md` (`<ru-RU>…</ru-RU>`, `<en-US>…</en-US>`). | **[F]** accepts App Signing terms; upload [A] |
| 4.5 | **Review release → Start rollout to Closed testing → Send for review** (Publishing overview). The first review of a new app can take several days. | [A] |
| 4.6 | When it's approved, copy the **opt-in link** (Closed testing → Testers → "Join on the web": `https://play.google.com/apps/testing/uz.metrx.app`) and send it to the testers with two lines: *1) open the link while signed in to the same Google account that's on your phone and tap "Become a tester"; 2) then install METRX from the Play Store (the link's "download it on Google Play"), not from an APK.* Sideloaded APKs don't count. | **[F]** |
| 4.7 | Keep **≥ 12 opted-in** testers for **14 full days in a row**. Ask them to open the app several times and send feedback — Google asks about it in step 6. Fix bugs with new closed-test releases (higher versionCode); updating doesn't reset the 14 days. Watch the counter on the Dashboard ("x of 12 testers, y of 14 days"). | **[F]** |

## 5. Pre-launch report and vitals (while testing)

| # | Step | Who |
|---|---|---|
| 5.1 | **Test and release → Pre-launch report**: Google's robots open the app on real devices. Check crashes, the accessibility and security warnings. No login is needed, so they can walk the whole app. | [A] |
| 5.2 | **App bundle explorer**: confirm no "16 KB page size" warning for the native libraries (Vosk, JNA, Filament) and see the download size. | [A] |

## 6. Apply for production (after the 14 days)

| # | Step | Who |
|---|---|---|
| 6.1 | **Dashboard → Apply for production**. Google asks about the closed test, the app and production readiness. Answer honestly, in your own words; drafts below. Review usually takes up to ~7 days. | **[F]** |
| 6.2 | When approved: **Test and release → Production → Countries/regions → Add** **Uzbekistan** first (more later: Kazakhstan, Kyrgyzstan, Tajikistan, Russia…). | **[F]** decides |
| 6.3 | **Production → Create release → Add from library** (promote the tested AAB) or upload a newer one → release notes → **Rollout** (a staged rollout, e.g. 20 %, is safer). | [A] |
| 6.4 | Publishing overview → **Send for review**. With *Managed publishing* off, it goes live after approval. | [A] |

Draft answers for 6.1 (change to what really happened):
- *How did you recruit testers?* — "Builders and furniture makers in Tashkent who measure rooms every day, plus friends with Android phones; invited through a Google Group and a Telegram group."
- *How easy was it to recruit?* — honest choice.
- *Describe the engagement / feedback received.* — e.g. "Testers measured real rooms with and without the ZB-08 laser, made furniture designs and PDF quotes, and reported N issues (…)."
- *What changes did you make based on the feedback?* — list the fixes in the 1.0.x test releases.
- *Who is the app for / value?* — "Tradespeople in Uzbekistan: measure rooms (Bluetooth laser, voice or by hand), design furniture and trade work in 3D, and send customers estimates and PDF quotes. Works offline, no account."
- *How do you know it's ready?* — crash-free sessions in the pre-launch report and vitals, tester feedback fixed.

---

## Things that could fail review — checked in the code (28 Oct 2026)

| Risk | Status | Action |
|---|---|---|
| Privacy policy link inside the app | **OK** | Profile → "Maxfiylik siyosati" opens `https://metrx-site.pages.dev/privacy.html` (built into 1.0.0). |
| Privacy URL live | OK | `https://metrx-site.pages.dev/privacy` returns the page (checked 28 Oct 2026). |
| Bluetooth permissions | OK | `BLUETOOTH_SCAN` has `neverForLocation`; `BLUETOOTH_CONNECT`; legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` capped at API 30. Bluetooth needs no Play declaration. |
| Location | OK | Fine + coarse, **foreground only**, asked when the user taps "Joylashuvni aniqlash". Since 1.0.1 the fix warms up quietly while the new-order form is open (only if already allowed) and stops when the screen closes — still foreground. **No `ACCESS_BACKGROUND_LOCATION`** → no location declaration or video needed. Data safety stays "no data collected": the point stays on the phone. |
| Foreground services | OK | **None** in the merged manifest → no foreground-service declaration. |
| Microphone | OK | Asked on the first hold of the mic button; audio stays on the phone. No declaration needed. |
| Downloaded content (Device and Network Abuse policy: no code from outside Play) | OK | The voice pack is **model data** (zip of Vosk model files), not dex or `.so` code; the native `libvosk.so` ships inside the AAB. |
| Photos / storage | OK | System photo picker; no `READ_MEDIA_*` / `MANAGE_EXTERNAL_STORAGE` → no photo/video declaration. |
| Package visibility | OK | Specific `<queries>` (camera intent, Telegram, Yandex, Google Maps, https VIEW); no `QUERY_ALL_PACKAGES`. |
| Target API level | OK | `targetSdk 36` (meets the 2025–2026 requirement). |
| 16 KB page size | OK in config | `useLegacyPackaging = false`, Vosk 0.3.75 and JNA 5.19.1 are 16 KB aligned (per `build.gradle.kts`) — confirm in App bundle explorer (5.2). |
| OpenGL ES 3.0 required (`uses-feature glEsVersion 0x30000 required`, from SceneView) | Note | Very old phones without GLES 3 can't install. Fine for 2026 phones. |
| Debug-only exported `PreviewActivity` | Check | Comes from `ui-tooling` (debugImplementation) — must not be in the release AAB (step 0.4). |
| Sign-in / Google logo | OK | Sign-in screens hidden (`AuthFlags.accounts = false`); the Google-logo button is never shown. Keep it so — a fake "Continue with Google" would be rejected and is a trademark problem. |
| "METRX Pro" / paid features | OK | `gl.pro` string unused; no purchase UI. |
| Store listing metadata | OK | No other app or brand names except the compatible ZB-08 laser; no "free"/"best" in the title; no ALL-CAPS headings. |
| Screenshots | OK | 8 ru + 8 en uploaded with 1.0.0; kept for 1.0.1. |
| Laser can't be tested by Google | OK | Every size can be typed or spoken; the description says so. |
| App name taken | Unknown | If "METRX" clashes with an existing app or trademark, Play may ask; the descriptive title helps. |

## Decisions

Already decided (28 Oct 2026): Russian default + English; title `METRX: замер, 3D и смета`; category House & Home; privacy policy published at metrx-site.pages.dev/privacy; in-app privacy row built; countries Uzbekistan; keep the 8 ru + 8 en screenshots and the Uzbek feature graphic.

Still open for the founder:
1. **Testers:** the 12+ (better 15–20) tester Gmail addresses for the "METRX testers" list, then share the opt-in link once the release is live.
2. **When to send 1.0.1:** right away (may restart the first review) or after 1.0.0 is approved (recommended).
3. **Redeploy the privacy page** with the 1.0.1 wording (one `wrangler pages deploy` from `web/`, see `website-hosting`).
4. **Free forever as a store listing:** a free Play app can't become paid; a future paid Advanced must be an in-app purchase.
