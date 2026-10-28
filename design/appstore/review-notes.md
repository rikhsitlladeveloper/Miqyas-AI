# METRX — App Review notes (iPhone, first release)

Paste the text between the lines into App Store Connect → the version → **App Review Information → Notes**.
Also in that section:

- **Sign-in required:** leave unchecked (there is no account, so no demo login is needed).
- **Contact:** your name, a phone number and developer.sanjar@gmail.com.
- **Attachment:** upload the laser video there too (or put the link in the notes below). Replace `[VIDEO LINK]` before you submit.

Lines in [square brackets] are for you. Delete them, or change them to match the build you send. The button names below are the app’s English texts (from `strings.json`); walk through the steps once on TestFlight in English before you submit.

---

```text
Thank you for reviewing METRX.

WHAT IT IS
METRX helps builders and tradespeople in Uzbekistan measure rooms, see them in 3D and make estimates and PDF quotes for their customers. There are six trades: builder, furniture maker, tiler, electrician, plumber, and windows and doors. The app is free and has no in-app purchases.

NO ACCOUNT NEEDED
There is no sign-up and no login. Everything is stored on the device. The app has no server, sends no user data anywhere, and has no analytics, ads or tracking. The only network use is an optional one-time download of the offline voice model (see VOICE below).

LANGUAGE
The app starts in Uzbek. To switch to English, tap the language button (globe icon, top right) on the first screen, or go to Profile > App language.

TRY THE MAIN FLOW
1. Start: on first launch, after the short opening animation, tap "Start". The name and phone fields are optional (they are only printed on the PDF quote and stay on the device). Then choose the trade "Builder".
2. Measure: Projects > New project > enter a project name > Create project. The app asks "Where do we start?": tap "Measure the room". Pick a room shape, then type each wall's length by hand.
3. Doors and windows: in the room editor, drag the door or window icon from the bottom bar onto a wall, pick a style, and set its sizes step by step (or tap "Standard"). "Add a wall" adds an inner wall from ready pieces (straight, L, T, half wall, column, arch). Open the 3D view and turn it with one finger.
4. Quote: in the project, open the estimate, add a material or labour line, then create the PDF report and tap "Share PDF".

Furniture: Profile > Trade > "Furniture maker" > New order > Create order > "Design only (with sizes)" (or "Measure the room"). Pick a piece from the 3D gallery and enter its sizes step by step; then choose "Against a wall" or "In the middle of the room (free)". In the designer, tap a cabinet module: drag its edge to change the width, press and hold to move it, and use the tool bar at the bottom. Prices, cut lists and quotes for these trades appear when "Advanced mode" is turned on in Profile.

THE BLUETOOTH LASER (ZB-08)
METRX works with the ZB-08 Bluetooth laser distance meter. When the laser is connected, the user picks a size, presses the laser's own button, and the distance goes into that size; the user checks and confirms it.
You do not need the laser to review the app: every size can be typed by hand, and all features work the same. Without a laser, the laser buttons open the Bluetooth search page, which looks for the laser and explains how to turn it on. The app never makes up a reading.
A video of the app with the real ZB-08 laser: [VIDEO LINK]

VOICE (optional)
Holding the microphone button next to a size lets the user say the number ("three thousand four hundred" -> 3400). Speech is recognised on the device with the open-source whisper.cpp engine. The model (about 57 MB) is downloaded once, over Wi-Fi only, from the whisper.cpp project's page on Hugging Face, only after the user taps download. No audio or other user data is sent.

PERMISSIONS (each is asked only when the user uses that feature)
- Bluetooth: when the user searches for the laser. Used only to read distances from the laser.
- Camera: when the user takes a photo of a wall to draw dimensions on it.
- Photos: when the user picks a photo from the library to draw dimensions on it. [Keep "and saves a picture to Photos" only if NSPhotoLibraryAddUsageDescription is in the build.]
- Microphone: only while the user holds the microphone button (on-device speech to text, nothing recorded or sent).
- Location (optional, While Using only): asked when the user taps "Get my location" in a new order or a project. The accuracy is shown live ("±X m") and improves for up to 30 seconds; "Good enough" saves early. If location was already allowed, the app starts reading the position quietly while the new-order form is open, so the point is ready sooner; nothing is saved until the user taps and accepts the point, and reading stops when the screen closes. The point is saved inside that project so the user can find the site later, and stays on the device. If Precise Location is off, iOS asks once for temporary precise access. "Open in maps" / "Route" hand the saved coordinates to Yandex Maps, Yandex Navigator or Google Maps (app or website), whichever the user picks. There is no background location.
Every feature still works if a permission is refused, except the one that needs it.

PRIVACY POLICY
https://metrx-site.pages.dev/privacy [and in the app: Profile > "Privacy policy" — keep this only once the row is in the iPhone build]

[Keep the next paragraph only if the hidden laser test page is still in the build.]
SUPPORT PAGE
Tapping the version number in Profile 7 times opens a Bluetooth diagnostics page. It shows the laser's raw Bluetooth messages so we can help users whose laser does not connect. It has no other function.

CONTACT
developer.sanjar@gmail.com
```

---

## Check before you submit

- [x] The build has no sign-in buttons (Create an account / Log in / Google) and no "METRX Pro" card (`AuthFlags.accounts = false`, checked 28 Oct 2026). A "Coming soon" sign-in screen would be rejected as an unfinished feature (Guideline 2.1).
- [x] Name and phone are optional on the first screen (Guideline 5.1.1: don't require personal data the app doesn't need).
- [ ] **A privacy policy link inside the app** (Guideline 5.1.1(i) asks for one both in App Store Connect and in the app). The Android app has Profile → "Privacy policy"; the iPhone app does **not** yet (the `prof.privacy` text exists in `strings.json`). See `LAUNCH_CHECKLIST.md` → blockers.
- [ ] `NSPhotoLibraryAddUsageDescription` is in `Info.plist`: the JPEG of a marked-up photo goes through the share sheet, whose "Save Image" would crash the app without it. See `LAUNCH_CHECKLIST.md` → blockers.
- [ ] The privacy manifest declares the file-timestamp API (`Furniture/CardCache.swift` reads `contentModificationDate`). See `LAUNCH_CHECKLIST.md` → blockers.
- [ ] Steps 1–4 above match the build: go through them once in English on TestFlight and fix any button name that differs.
- [ ] `[VIDEO LINK]` is replaced. An unlisted YouTube video or a Google Drive link that anyone can open both work. Show: the laser turning on, the search page finding "ZB-08", connecting, and one reading going into a room size.
- [ ] The diagnostics paragraph is kept or deleted to match the build.
