# METRX (iPhone) — App Privacy, age rating, category, export and content rights

What to answer in App Store Connect, and why. Checked against the iPhone code in `ios-native/METRX` on 24 Oct 2026, and again on 28 Oct 2026 (ios-native at 29cf63e: room editor v2, inner walls, free furniture, Designer C v2, live-accuracy GPS). The answer is unchanged: **Data Not Collected** — nothing leaves the device, and the location stays on the device.

## 1. What the code actually does (the evidence)

| Question | What I found in `ios-native/METRX` |
|---|---|
| Does the app talk to any server? | **Only for one file download (since the UX upgrades, 26 Oct 2026).** `UX/VoicePack.swift` downloads the voice pack (whisper.cpp's `ggml-base-q5_1.bin`, about 57 MB, from `huggingface.co/ggerganov/whisper.cpp`, pinned to one version and checked by SHA-256) when the user taps "Yuklab olish". Wi-Fi only (`allowsCellularAccess`, `allowsExpensiveNetworkAccess` and `allowsConstrainedNetworkAccess` off; `NWPathMonitor` only to show whether Wi-Fi is there). It is a plain GET with no user data; the file is kept in Application Support (not backed up). Nothing else: no `URLRequest` with user data, WebKit, CloudKit or iCloud. |
| Third-party code (SDKs, analytics, ads, crash tools)? | **No analytics, ads or crash tools.** One library: whisper.cpp's official XCFramework (MIT licence, release b5130) as a local Swift package (`ios-native/Packages/WhisperBin`), for on-device speech to text. It makes no network calls. Fonts: OFL licence (`ios-native/FONT_LICENSE_OFL.txt`). |
| Where is data stored? | On the phone only: projects as JSON files in the app's Application Support folder (`Data/Store.swift`), 3D pictures and photos next to them (`Data/ViewFiles.swift`), small settings in `UserDefaults` (`Core/Settings.swift`). Nothing is excluded from the iPhone's own backups, so iCloud Backup or a computer backup made by the user includes it. Apple keeps that, not us. |
| Links the app opens | All started by the user: `tel:` (the "Call" button opens the Phone app), the iPhone's Settings page for METRX (when a permission is off), and the maps links of `UX/OrderLocation.swift` / `Projects/ProjectScreen.swift` ("Open in maps" / "Route"): Yandex Maps, Yandex Navigator or Google Maps (`yandexmaps://`, `yandexnavi://`, `comgooglemaps://` in `LSApplicationQueriesSchemes`), or their website in Safari. They open outside the app with the saved coordinates. "Copy" puts the coordinates on the clipboard. |
| Sharing | Through the iPhone's share sheet, to an app or person the user chooses: the PDF quote (`Report/ReportScreen.swift`), a marked-up photo as a JPEG (`Markup/MarkupScreen.swift` `shareShot`) and the client 3D files, USDZ + HTML (`Furniture/Client3DShare.swift`). |
| Bluetooth | CoreBluetooth only, to find and connect the ZB-08 laser and read its distance messages (`Laser/RealLaser.swift`). No background modes. |
| Camera / Photos | `AVCaptureSession` and `UIImagePickerController` for photos the user takes or picks to draw dimensions on (`Markup/`). Photos are saved inside the app only. |
| Microphone | `NSMicrophoneUsageDescription` (Uzbek and English). `AVAudioEngine` records only while the size field's mic button is held (`UX/VoiceEngine.swift`); whisper.cpp turns it into text on the phone and `UX/VoiceParse.swift` into millimetres. The audio is kept in memory only, never saved or sent. |
| Location | **Yes, optional, on the device only.** `NSLocationWhenInUseUsageDescription` and `NSLocationTemporaryUsageDescriptionDictionary` (key `OrderPlace`, for temporary precise access) are in `Info.plist`; `CLLocationManager` lives in `UX/OrderLocation.swift` (`Gps`, best accuracy). The permission is asked when the user taps **"Get my location"**. Updates then run while the screen is open: the accuracy shows live ("±X m"), the search stops at ±20 m or after 30 s, and "Good enough" saves early. If the app is already allowed, `warm()` starts updates quietly when the new-order form, a new project or the location sheet opens, so the first tap is quick; nothing is saved until the user accepts a point, and updates stop when the screen goes. It saves latitude, longitude and accuracy in that project, and it can be removed. No background mode, no geocoding, no network. Only a **builder's** PDF quote prints the coordinates (`Report/Snapshot.swift`: furniture and the other trades keep them for the maker). GPS works without internet. |
| Personal details typed by the user | The user's own name and phone (printed on quotes), and customers' names, phones and addresses in projects. All stay on the phone. |

## 2. App Privacy questionnaire

**App Store Connect → App Privacy → Get Started**

1. *"Do you or your third-party partners collect data from this app?"* → **No, we do not collect data from this app.**
2. Result shown on the store: **"Data Not Collected."**

**Why this is correct.** Apple defines *collect* as sending data off the device so that you or your partners can access it for longer than it takes to answer the request in real time. Data handled only on the device is not collected. METRX has no servers and no analytics, ads or crash SDKs; its only network call is the plain voice-pack download, which sends no user data. So nothing the user enters leaves the phone through the app.

The edge cases, and why they don't change the answer:

- **Share PDF.** The user chooses where the file goes, through Apple's share sheet. We never receive it.
- **Open in maps.** Only when the user taps it, the saved coordinates go to Google Maps in a URL. This hands the place over to another app the user picked. We don't receive it, and Google isn't a partner built into the app.
- **Call.** This opens the Phone app with the customer's number.
- **iPhone backups.** These are made by iOS to the user's own iCloud or computer.
- **Crash reports.** If a user turns on *Share with App Developers* in iOS Settings, iOS sends crash logs through Apple. The app doesn't do this, and it isn't counted as the app's data collection.

**Tracking:** No. There is no IDFA, no `AppTrackingTransparency` prompt, no ads, and nothing is linked to other companies' data.

**Privacy Policy URL** (required): `https://metrx-site.pages.dev/privacy` (live; the same page covers iPhone and Android; source `web/metrx-site/privacy.html`). Switch to `https://metrxai.uz/privacy` once the domain works.
**Support URL** (required): `https://metrx-site.pages.dev`

The old GitHub Pages draft in `site/` (privacy effective 25 Oct) is superseded by the live page; don't publish it.
**Marketing URL**: leave empty (optional).

### Privacy manifest (`ios-native/METRX/PrivacyInfo.xcprivacy`)

It exists (added 24 Oct, bundled as a resource by `project.yml`) with tracking `false`, no tracking domains, no collected data types (matches "Data Not Collected"), and these required-reason APIs:

| Key | Value | In the manifest? |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` — the app's own settings (`Core/Settings.swift`, `Data/Store.swift`, `Furniture/DzcKit.swift`) | yes |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` — `ProcessInfo.systemUptime` in `Laser/LaserLog.swift` times the laser's events | yes |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` — `Furniture/CardCache.swift` reads `contentModificationDate` of its own cached gallery cards (in the app's Caches folder) to keep the newest; `Furniture/Client3DShare.swift` calls `attributesOfItem` (size only) on a file it just wrote | **no — must be added** (App Store Connect sends an ITMS-91053 "Missing API declaration" mail and can reject the upload) |

No disk-space or active-keyboard APIs were found. The whisper.cpp XCFramework is not on Apple's list of SDKs that need their own manifest. Check again if code changes before the upload.

## 3. Age rating

**App Store Connect → App Information → Age Rating → Edit.** Answer **None / No** to everything:

| Group | Answer |
|---|---|
| In-app controls (parental controls, age assurance) | None |
| Capabilities: unrestricted web access | **No.** There is no browser in the app. "Open in maps" leaves the app. |
| Capabilities: user-generated content shared with others | **No.** Projects are private on the phone; nothing is posted or shown to other users. |
| Capabilities: messaging or chat | No |
| Capabilities: advertising | No |
| Mature themes, profanity or crude humour, horror or fear | None |
| Medical or treatment information, health or wellness topics | None / No |
| Sexuality, nudity | None |
| Violence (cartoon, realistic, graphic), weapons | None |
| Alcohol, tobacco, drugs | None |
| Gambling, simulated gambling, contests, loot boxes | None / No |

Expected rating: **4+.** The question list was updated in 2025, so the exact wording on screen may differ. The answers stay the same.

## 4. Category

- **Primary: Productivity.** The app is a work tool: measure → design → count → quote. Productivity is where people look for tools that get a job done faster, and it matches the subtitle "measure, 3D, estimate".
- **Secondary: Business.** Estimates, prices, cut lists, orders with install dates and customer quotes are small-business work. This catches contractors who browse Business.
- Not chosen:
  - **Utilities** is crowded with simple measuring and flashlight apps and undersells the estimates and quotes.
  - **Lifestyle** is for homeowners decorating, not tradespeople.
  - **Graphics & Design** suggests drawing apps.

You can change the category later.

## 5. Export compliance (encryption)

- `ITSAppUsesNonExemptEncryption` is already **`false`** in `ios-native/METRX/Info.plist`, so App Store Connect won't ask about each build.
- If it asks anyway: *"Does your app use encryption?"* → **No** (no proprietary or non-standard encryption). The only network use is the voice pack download over HTTPS through Apple's `URLSession`, and the app has no cryptography code of its own; both are exempt.
- Nothing to upload (no French declaration, no CCATS).

## 6. Content rights

- *"Does your app contain, show, or access third-party content?"* → **No.**
  - All texts, icons, 3D furniture, tiles and fittings are drawn by the app's own code.
  - The fonts (Plus Jakarta Sans, Manrope, IBM Plex) are under the SIL Open Font License, which allows bundling them.
  - Users' own photos stay on their phone.
- The **Google "G" logo** is only on the hidden "Continue with Google" button (`Auth/AuthScreens.swift`, never shown while `AuthFlags.accounts = false`). Keep it hidden: without a real Google sign-in, that logo could be a trademark problem.
- The store texts name the **ZB-08** laser only to say it is compatible. That's fine, but don't use the laser maker's logo or photos in screenshots without their permission. Your own photos of the device are fine.

## 7. Other App Store Connect answers

- **Price:** Free (0.00). **In-app purchases:** none.
- **Availability:** Uzbekistan first (you can add countries later).
- **EU Digital Services Act (trader status):** App Store Connect asks this once for the account. It matters only for EU storefronts. As an individual with a free app and no business, the usual answer is *not a trader*. If you later sell in the EU as a trader, your address, phone and email are shown on the EU store.
- **Sign-in required for review:** No.

## Voice input (added 26 Oct 2026)

- App Privacy stays **"Data Not Collected"**: the audio is processed on the device and discarded; the voice pack download sends no user data (Apple's definition of *collect* is data sent off the device that we can access).
- The live privacy policy (`https://metrx-site.pages.dev/privacy`, all three languages) names the microphone permission and the one-time voice pack download from the whisper.cpp project's Hugging Face page.
- Export compliance is unchanged: the download is HTTPS by the system (exempt encryption).
