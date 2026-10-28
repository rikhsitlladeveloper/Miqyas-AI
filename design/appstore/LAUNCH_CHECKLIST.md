# METRX on the App Store — launch checklist for the founder

From enrolling to pressing "Submit for Review". Bundle id `uz.metrx.app`, version 1.0 (from `ios-native/project.yml`), iPhone only, free, Uzbekistan first.

**Who does what:** **[F]** = only you (your Apple ID, identity, money, legal acceptances, keys). **[D]** = a developer can do it in the repo for you. Never send anyone your Apple ID password, the `.p8` key file or its text; you paste the key into GitHub yourself.

Related files: `listing.md` (store texts), `review-notes.md` (App Review notes), `app-privacy.md` (App Privacy and the other questionnaires), `captions.json` + `frame_shots.py` (screenshots).

---

## 0. Fix the launch blockers first

Found in `ios-native` on 28 Oct 2026 (ios-native at 29cf63e). These are app-code changes for a developer; nothing here was changed.

| # | Blocker | Why it matters | Fix |
|---|---|---|---|
| B1 | **No privacy policy link inside the app.** Android has Profile → "Privacy policy"; iPhone has none (the `prof.privacy` text already exists in `strings.json`). | Guideline 5.1.1(i): the link must be in App Store Connect **and** easy to find in the app. A common rejection. | A Profile row "Privacy policy" opening `https://metrx-site.pages.dev/privacy`, as on Android. **[D]** |
| B2 | **`NSPhotoLibraryAddUsageDescription` is missing** from `Info.plist`. A marked-up photo is shared as a JPEG (`Markup/MarkupScreen.swift` `shareShot`); the share sheet then offers "Save Image". | Without the key, iOS ends the app when the user taps "Save Image" (a crash App Review can hit). | Add the key with a short uz / ru / en text ("to save the picture with its dimensions to your Photos"). **[D]** |
| B3 | **The privacy manifest misses the file-timestamp API.** `Furniture/CardCache.swift` reads `contentModificationDate` (and `Furniture/Client3DShare.swift` calls `attributesOfItem`). | Apple's upload check sends "ITMS-91053: Missing API declaration" and can reject the build. | Add `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1` to `METRX/PrivacyInfo.xcprivacy`. **[D]** |

Should fix (not a hard reject, but do them in the same pass):

| # | Item | Fix |
|---|---|---|
| S1 | The location text says "Faqat siz bosganingizda aniqlanadi / only when you tap", but since the live-GPS change the app also reads the position quietly while the new-order form is open, if location is already allowed (`UX/OrderLocation.swift` `warm()`). | Reword, e.g. "Used on the order screen to save the place of the order; it is saved only when you tap. / …" so the text matches the behaviour. **[D]** |
| S2 | Permission texts are one bilingual Uzbek / English string each; no Russian, while Russian is the store's primary language. The comment above `NSMicrophoneUsageDescription` talks about Bluetooth (copy-paste). | Move the texts to `uz.lproj`, `ru.lproj`, `en.lproj` `InfoPlist.strings` (and add `CFBundleLocalizations` uz, ru, en so the store's "Languages" line lists all three). **[D]** |
| S3 | `NSBluetoothPeripheralUsageDescription` is obsolete (iOS 13+ uses `NSBluetoothAlwaysUsageDescription`). | Harmless; can be removed. **[D]** |

Checked and fine:
- **Version and build:** `MARKETING_VERSION` 1.0, and each TestFlight upload gets the workflow's run number as the build number, so builds always go up. (Android is 1.0.1; see the decision at the end.)
- **iPad-safe:** `TARGETED_DEVICE_FAMILY` = 1 (iPhone only, portrait). On an iPad it runs in iPhone mode; both share sheets anchor their popover, so they don't crash there.
- **App icon:** one 1024 × 1024 RGB PNG without transparency in `Assets.xcassets/AppIcon.appiconset` ("universal, single size"); Xcode makes every smaller size from it. App Store accepts this.
- **Encryption:** `ITSAppUsesNonExemptEncryption` = false (only system HTTPS for the voice pack).
- **No test or demo hooks a user can reach:** the `-uiReset`, `-uiSimLaser`, `-uiSamplePhoto`, `-uiTour` launch arguments and the `UI_LANG` variable only work when a test runner starts the app. The "Lazer sinovi" page is behind 7 taps on the version (disclosed in `review-notes.md`). Sign-in screens are hidden (`AuthFlags.accounts = false`), no "METRX Pro" card, no "Tez kunda". The sample order ("Namuna") is a real feature.
- **Privacy:** nothing leaves the device; location is read on the device only and saved only on a tap; the only download is the voice pack, with no user data. App Privacy answer: "Data Not Collected".

---

## 1. Enroll in the Apple Developer Program [F]

1. On the iPhone 16 Pro Max, make sure your Apple ID has **two-factor authentication** on (Settings → your name → Sign-In & Security).
2. Easiest: install the **Apple Developer** app → Account → **Enroll Now**, or go to developer.apple.com/programs/enroll.
3. Choose **Individual / Sole Proprietor** (no D-U-N-S number needed). Your legal name becomes the seller name shown on the store.
4. Pay **US$99 per year**. Approval usually takes from a few hours to two days; you get an email.
5. developer.apple.com → Account → **Membership details**: copy the **Team ID** (10 characters). You need it in step 4.
6. App Store Connect (appstoreconnect.apple.com) → **Business** (Agreements, Tax, and Banking): check that the **Free Apps** agreement shows *Active*, and accept any new agreement shown at the top. For a free app, no bank or tax forms are needed.

## 2. Create the App ID (bundle id) [F]

developer.apple.com → Account → **Certificates, Identifiers & Profiles** → Identifiers → **+** → App IDs → App.

| Field | Value |
|---|---|
| Description | `METRX` |
| Bundle ID | **Explicit**: `uz.metrx.app` (must match `project.yml`) |
| Capabilities | none to tick (no iCloud, push or Sign in with Apple). Bluetooth, camera, location and microphone need no capability. |

Certificates and provisioning profiles: **don't make them by hand**. The TestFlight workflow uses automatic signing with the API key and creates them on the build machine.

## 3. Create the app in App Store Connect [F]

App Store Connect → **Apps** → **+** → **New App**.

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `METRX` (if taken, see `listing.md` → Notes 2) |
| Primary language | **Russian** (App Store Connect has no Uzbek) |
| Bundle ID | `uz.metrx.app` (from step 2) |
| SKU | `metrx-ios` (any text only you see) |
| User access | Full access |

Then add the **English (U.S.)** localization (the language menu at the top of the app's page).

## 4. API key → GitHub secrets [F]

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → Team Keys → **Generate API Key** (the first time, you may need to request access, which is granted at once).
2. Name `METRX CI`, Access **Admin** (automatic signing on the build machine needs it to create the certificate and profile).
3. Note the **Key ID** (10 characters) and the **Issuer ID** (a UUID above the list). **Download** the `AuthKey_<KEYID>.p8` file — Apple lets you download it **only once**. Keep it offline (for example next to the Play keystore backup), never in the repo.
4. GitHub → the METRX repository → **Settings → Secrets and variables → Actions → New repository secret**. Add exactly these four names (they are what `.github/workflows/ios-testflight.yml` reads):

| Secret name | Value |
|---|---|
| `ASC_KEY_ID` | the Key ID, e.g. `2X9R4HXF34` |
| `ASC_ISSUER_ID` | the Issuer ID (UUID) |
| `ASC_KEY_P8` | the **whole text** of `AuthKey_<KEYID>.p8`, from `-----BEGIN PRIVATE KEY-----` to the `-----END PRIVATE KEY-----` line (open it in Notepad, select all, copy, paste) |
| `APPLE_TEAM_ID` | the Team ID from step 1.5 |

The workflow checks that all four are there, writes the key to the build machine only for the run, never prints it, and deletes it at the end.

## 5. First TestFlight build [F or D]

1. A developer makes sure the blockers B1–B3 are fixed on the `ios-native` branch and the normal CI (`ios-native.yml`) is green.
2. Start the upload with a tag (hand-run workflows only show "Run workflow" once they are on `main`):
   ```
   git tag testflight-1 origin/ios-native
   git push origin testflight-1
   ```
   Use a new number each time (`testflight-2`, …). The build number is the workflow's run number, so it always goes up.
3. GitHub → **Actions → iOS TestFlight**: about 15–30 minutes. Green = uploaded. If "Check the secrets" fails, a secret name or value is wrong (the error names it). The signed IPA is kept 7 days as the artifact `METRX-appstore-ipa`.
4. App Store Connect → the app → **TestFlight**: the build appears after Apple's processing (5–30 minutes). If it shows **"Missing Compliance"**, answer *No* to encryption (normally not asked, because `ITSAppUsesNonExemptEncryption` is false).
5. TestFlight → **Internal Testing** → **+** → group `Team` → add yourself (your Apple ID is already a user of the account) → add the build.

## 6. Install on your iPhone 16 Pro Max [F]

1. On the iPhone, install **TestFlight** from the App Store and sign in with the same Apple ID.
2. Open the invitation email (or the TestFlight app) → **Accept** → **Install**. This replaces sideloading: no Sideloadly / iLoader needed.
3. Go through `review-notes.md` → *TRY THE MAIN FLOW* in English, connect the real ZB-08, try voice, location, the room editor, inner walls, free furniture and the designer. Record the **laser video** for App Review (laser on → search finds ZB-08 → connect → one reading goes into a size); upload it unlisted to YouTube or as a public Google Drive link.
4. Found a bug? It gets fixed, then a new `testflight-N` tag; TestFlight updates the app.

## 7. Screenshots [F or D]

1. Start the screenshot workflow with a tag:
   ```
   git tag shots-1 origin/ios-native
   git push origin shots-1
   ```
2. GitHub → **Actions → iOS App Store screenshots** (about 30–60 minutes). It runs `METRXUITests/AppStoreShots.swift` on the biggest iPhone simulator (6.9-inch) in Uzbek, Russian and English, and frames them with `design/appstore/frame_shots.py` and `captions.json`.
3. Download the artifact **`appstore-final`**: `ru/` and `en/` hold the store pictures, 1320 × 2868. Look at the run summary: any `*-skip-*` picture means a step wasn't reached; that shot needs a fix and a new `shots-N` tag.
4. App Store Connect → the version → **Russian** → iPhone 6.9" Display → drag the `ru` pictures in order; same for **English** with `en`. Smaller iPhone sizes are made from the 6.9" set automatically.

## 8. Fill in the version page [F]

App Store Connect → the app → **iOS App 1.0 (Prepare for Submission)**:

| Section | What to enter |
|---|---|
| Promotional text, Description, Keywords | from `listing.md` (Russian into Russian, English into English) |
| Support URL | `https://metrx-site.pages.dev` |
| Marketing URL | empty |
| Build | **+** → pick the tested TestFlight build |
| App Review Information | sign-in **not** required; contact name, phone, **developer.sanjar@gmail.com**; Notes from `review-notes.md` with `[VIDEO LINK]` replaced; attach the video if you like |
| Version release | "Manually release this version" (you press Release after approval) or automatic |
| Copyright | `2026 <your full legal name>` |

App-level pages (left menu):

| Page | What to enter |
|---|---|
| **App Information** | Subtitle per language (from `listing.md`); Category **Productivity**, secondary **Business**; Content Rights → *does not use third-party content*; Age Rating → answer None/No everywhere (→ 4+), see `app-privacy.md` §3 |
| **App Privacy** | Privacy Policy URL **`https://metrx-site.pages.dev/privacy`**; Data collection → **"No, we do not collect data from this app"** (`app-privacy.md` §2) |
| **Pricing and Availability** | Price **Free**; Availability **Uzbekistan** (add others later) |
| EU Digital Services Act | asked once per account: as an individual with a free app, usually *not a trader* (`app-privacy.md` §7) |

## 9. Make the repository private — right before you submit [F]

The repo stays public until launch because public repos get free macOS CI minutes. Right before step 10:

1. Make sure the last TestFlight build you will submit is uploaded and the screenshots are downloaded.
2. GitHub → the repository → **Settings → General → Danger Zone → Change repository visibility → Make private**.
3. After that, every macOS CI run uses the account's private-repo minutes (macOS minutes count 10×, so the free 2 000 minutes are about 200 macOS minutes a month — roughly 6–10 builds). The secrets and tags stay.

## 10. Submit [F]

1. On the version page, check every section has no red mark, then **Add for Review** → **Submit for Review**.
2. Apple's review usually takes 1–3 days. Answer any question in **App Review → Messages** in English; a rejection names the guideline, so it can be fixed and sent again.
3. When it says **Pending Developer Release**, press **Release This Version** (if you chose manual release).

---

## Decisions for you

1. **iPhone version number:** ship as **1.0** (as now) or as **1.0.1** to match Android. Either is fine for Apple; matching makes support easier. It is one line in `project.yml` (`MARKETING_VERSION`).
2. **App name** if `METRX` is taken on the App Store (`listing.md` → Notes 2).
3. **Release:** manual (you choose the day) or automatic after approval.
4. **The hidden "Lazer sinovi" page:** keep it (disclosed to App Review) or remove it from the store build.
5. **When to go private:** right before submitting (recommended), or keep public until after approval to keep free CI for fixes during review.
