# METRX Android shell

A small native Android app that shows the METRX web app (`../prototype/`) full screen in a WebView and gives it the phone's keyboard, camera, location, share sheet and files. It is not the React Native app described in `BUILD_PLAN.md`.

- Package: `uz.metrx.prototype`, label "METRX", minSdk 26, targetSdk 36. Java, no extra libraries.
- Every build copies `../prototype/index.html` into `app/src/main/assets/`. After you edit `prototype.html`, run `python make_index.py` in `design/prototype` first.
- The system Back gesture closes sheets, the keyboard and pop-ups, then steps back through screens to Home. On Home, it leaves the app.
- Saved data lives in the WebView's localStorage. To start again, clear the app's storage (`adb shell pm clear uz.metrx.prototype`).
- The page resizes above the Android keyboard (`adjustResize` plus the keyboard inset).
- "Take a photo" opens the camera app; "Find location" asks for the location permission.
- The PDF report is drawn page by page from an off-screen WebView, saved to `Download/METRX` and passed to the share sheet. The backup file (`.metrx`) is saved and shared the same way.
- Web fonts and Three.js (3D) load from public CDNs, so the emulator or phone needs internet. Without it, the 3D view shows its "3D didn't load" state.
- WebView debugging is on: open `chrome://inspect` in desktop Chrome while the app runs.

## Build and run
- **Android Studio:** open this folder, pick an emulator, and press Run.
- **Command line** (uses Android Studio's bundled JDK):

```bash
JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" ./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

## Emulator note
The real-app build was tested on the `Medium_Phone` emulator. To see the on-screen keyboard there, set `hw.keyboard = no` in `~/.android/avd/Medium_Phone.avd/config.ini`; with a hardware keyboard the emulator only shows a small floating bar. For GPS, send a position first: `adb emu geo fix 69.2034 41.2856`.
