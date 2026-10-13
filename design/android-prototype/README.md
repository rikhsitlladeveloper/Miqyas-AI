# METRX prototype for Android (design wrapper)

A minimal native Android app that shows the HTML design prototype (`../prototype/`) full screen in a WebView. It is for hands-on testing of the design on a phone or emulator. It is **not** the production React Native app described in `BUILD_PLAN.md`.

- Package: `uz.metrx.prototype`, label "METRX prototip", minSdk 26, targetSdk 36. Java, no extra libraries.
- Every build copies `../prototype/index.html` into `app/src/main/assets/`. After you edit `prototype.html`, run `python make_index.py` in `design/prototype` first.
- The system Back gesture closes sheets, the keyboard and pop-ups, then steps back through screens to Home. On Home, it leaves the app.
- Saved prototype data lives in the WebView's localStorage. Clear the app's storage, or use the in-app Demo panel → "Jump to", to reset.
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
On the `Medium_Phone` emulator (Android 37.2 beta, 16 KB page-size image), the WebView renders but its window shows as black. Use the `zedtest` emulator (Android 14, API 34) or a real phone.
