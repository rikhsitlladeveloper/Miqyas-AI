# METRX iPhone shell

A small iPhone app that shows the METRX web app (`../prototype/index.html`) full screen, the same way `../android-prototype` does on Android, and gives it the iPhone's keyboard, camera, location and share sheet.

Nothing here has been run on an iPhone yet: there is no Mac or device on the build PC, so the code is only compiled in GitHub Actions. Test the list under "What the shell does" on a real phone.

## How it is built

GitHub Actions builds it on a Mac runner: `.github/workflows/ios-ipa.yml`. Every push to `builders-v1` that changes the prototype or this folder produces a new build.

1. The workflow copies `design/prototype/index.html` into `App/Resources/`.
2. XcodeGen creates the Xcode project from `project.yml`.
3. `xcodebuild` builds it without code signing and packs `METRX-unsigned.ipa`.
4. The IPA is attached to the workflow run as the artifact **METRX-ipa**.

## Installing on an iPhone

The IPA is unsigned, so iOS will not install it as it is. It gets signed when you install it:

- **Sideloadly or AltStore** (Windows or Mac) sign it with your own Apple ID and install it over USB. With a free Apple ID the app works for 7 days, then needs installing again.
- With a paid Apple Developer account the build can be signed in CI instead, or sent to TestFlight. That needs a certificate and a provisioning profile added as repository secrets.

After installing, open Settings → General → VPN & Device Management and trust the developer profile.

## What the shell does

- Loads the bundled `index.html` in a web view, below the status bar and down to the bottom edge.
- The status bar turns dark on the opening and welcome screens (`MetrxNative.setDarkTop`, the same bridge as Android).
- A swipe from the left edge acts as Back.
- Text and number fields use the iPhone keyboard.
- "Call" opens the Phone app, "Open in maps" opens the link outside the app. Adding a photo opens the camera or the photo library.
- "Find location" asks for location permission and returns the GPS position (`MetrxNative.getLocation` → `window.__metrxLoc`).
- The PDF report is made on the phone (`MetrxNative.sharePdf`: each A4 page is taken from an off-screen web view and joined with PDFKit) and passed to the share sheet. The backup file goes to the share sheet too (`MetrxNative.shareFile`); "Save to Files" keeps it. Restore opens the Files picker.
- Needs internet for the web fonts and the 3D library, like the Android wrapper.
