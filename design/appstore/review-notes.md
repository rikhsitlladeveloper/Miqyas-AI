# METRX 1.0 — App Review notes

Paste the text between the lines into App Store Connect → the version → **App Review Information → Notes**.
Also in that section:

- **Sign-in required:** leave unchecked (there is no account, so no demo login is needed).
- **Contact:** your name, a phone number and developer.sanjar@gmail.com.
- **Attachment:** upload the laser video there too (or put the link in the notes below). Replace `[VIDEO LINK]` before you submit.

Lines in [square brackets] are for you. Delete them, or change them to match the build you send.

---

```text
Thank you for reviewing METRX.

WHAT IT IS
METRX helps builders and tradespeople in Uzbekistan measure rooms, see them in 3D and make estimates and PDF quotes for their customers. There are six trades: builder, furniture maker, tiler, electrician, plumber, and windows and doors. The app is free and has no in-app purchases.

NO ACCOUNT NEEDED
There is no sign-up and no login. Everything is stored on the device. The app has no server, sends no data anywhere, and has no analytics, ads or tracking.

LANGUAGE
The app starts in Uzbek. To switch to English, tap the language button (globe icon, top right) on the first screen, or go to Profile > App language.

TRY THE MAIN FLOW IN 3 STEPS
1. Start: on first launch, tap "Start". The name and phone fields are optional (they are only printed on the PDF quote and stay on the device). Then choose the trade "Builder".
2. Measure: Projects > New project > enter a project name and a customer name > Add room > type the room's length, width and height by hand > open the room's 3D view and turn it with one finger.
3. Quote: in the project, open the estimate, add a material or labour line, then create the PDF report and tap "Share PDF".

Other trades: Profile > Trade > for example "Furniture maker" > New order > pick a piece from the 3D gallery and enter its sizes step by step. Prices, cut lists and quotes for these trades appear when "Advanced mode" is turned on in Profile.

THE BLUETOOTH LASER (ZB-08)
METRX works with the ZB-08 Bluetooth laser distance meter. When the laser is connected, the user picks a size, presses the laser's own button, and the distance goes into that size; the user checks and confirms it.
You do not need the laser to review the app: every size can be typed by hand, and all features work the same. Without a laser, the laser buttons open the Bluetooth search page, which looks for the laser and explains how to turn it on. The app never makes up a reading.
A video of the app with the real ZB-08 laser: [VIDEO LINK]

PERMISSIONS (each is asked only when the user uses that feature)
- Bluetooth: when the user searches for the laser. Used only to read distances from the laser.
- Camera: when the user takes a photo of a wall to draw dimensions on it.
- Photos: when the user picks a photo from the library to draw dimensions on it.
- Location (optional): only when the user taps "Get my location" in a project's details. The place is saved inside that project so the user can find the site later. It stays on the device. "Open in maps" hands the saved coordinates to Google Maps.
Every feature still works if a permission is refused, except the one that needs it.

[Keep the next paragraph only if the hidden laser test page is still in the build.]
SUPPORT PAGE
Tapping the version number in Profile 7 times opens a Bluetooth diagnostics page. It shows the laser's raw Bluetooth messages so we can help users whose laser does not connect. It has no other function.

CONTACT
developer.sanjar@gmail.com
```

---

## Check before you submit

- [x] The build has no sign-in buttons (Create an account / Log in / Google) and no "METRX Pro" card, as decided. If a "Coming soon" sign-in screen is still there, App Review may reject it as an unfinished feature (Guideline 2.1).
- [ ] Steps 1–3 above match the build: go through them once in English on TestFlight and fix any button name that differs.
- [x] Step 1: name and phone are optional since commit after b4d867a (was: required). Apple asks apps not to require personal data that the app doesn't need to work (Guideline 5.1.1). Making both fields optional (they are only used on the PDF) removes this risk. Until then, step 1 tells the reviewer to type any values.
- [ ] A **privacy policy link inside the app** (for example in Profile → About) to the published privacy.html. Guideline 5.1.1(i) asks for one both in App Store Connect and in the app.
- [x] (removed with the sign-in screen) The first screen's "Terms of Use" and "Privacy Policy" text is underlined but can't be tapped. Link it to the site (Terms → Apple's standard EULA, https://www.apple.com/legal/internet-services/itunes/dev/stdeula/), or remove it with the sign-in screen.
- [ ] `[VIDEO LINK]` is replaced. An unlisted YouTube video or a Google Drive link that anyone can open both work. Show: the laser turning on, the search page finding "ZB-08", connecting, and one reading going into a room size.
- [ ] The diagnostics paragraph is kept or deleted to match the build.
