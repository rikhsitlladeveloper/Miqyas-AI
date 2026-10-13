# Prototype tools

Small scripts used while building the prototype. They resolve paths from their own location, so run them from anywhere.

| Script | What it does |
| --- | --- |
| `sync_modules.py` | Pastes `prototype/modules/*.css` and `*.js` into `prototype/prototype.html` between their markers, then rebuilds `index.html`. Run it after editing a module. |
| `add_markers.py <name>` | Adds empty markers for a new module before the auth block. Then add the name to `ORDER` in `sync_modules.py`. |
| `build_options.py <body> <out> "<title>"` | Builds a "three options" comparison page from a body fragment, reusing the head of `projects/projects-options.html`. |
| `cdp.js` | Runs a JavaScript expression in the Android WebView and saves a screenshot. |

## Editing a page

1. Edit the module in `design/prototype/modules/` (for example `board.js`, `board.css`).
2. Run `python design/tools/sync_modules.py`.
3. Open `design/prototype/index.html`, or rebuild the Android app (see `design/android-prototype/README.md`).

`auth`, `wallview` and `sketch` are the exception: their code lives directly in `prototype.html`, and `modules/` keeps a reference copy that the sync script does not touch.

## Checking on the emulator

```bash
adb forward tcp:9333 localabstract:webview_devtools_remote_$(adb shell pidof uz.metrx.prototype)
curl -s localhost:9333/json
node design/tools/cdp.js <webSocketDebuggerUrl from the line above> shot.png "document.title"
```
