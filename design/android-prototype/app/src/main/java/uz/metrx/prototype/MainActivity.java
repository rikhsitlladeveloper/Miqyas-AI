package uz.metrx.prototype;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ClipData;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Insets;
import android.graphics.pdf.PdfDocument;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.window.OnBackInvokedDispatcher;

import java.io.ByteArrayOutputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

/** Hosts the METRX web app full screen and gives it the phone's camera, location, share sheet and files. */
public class MainActivity extends Activity {
    private static final int PICK_FILE = 41;
    private static final int TAKE_PHOTO = 42;
    private static final int ASK_LOCATION = 43;
    private WebView web;
    private FrameLayout root;
    private View statusBg;
    private ValueCallback<Uri[]> fileCallback;
    private Uri cameraUri;
    private String geoOrigin;
    private GeolocationPermissions.Callback geoCallback;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView.enableSlowWholeDocumentDraw();   // lets the report pages be drawn into a PDF; must come before any WebView
        root = new FrameLayout(this);
        root.setBackgroundColor(Color.WHITE);
        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        statusBg = new View(this);
        statusBg.setBackgroundColor(Color.WHITE);
        root.addView(statusBg, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, 0));
        setContentView(root);

        // Keep the page clear of the status bar, navigation bar, display cutout and the on-screen keyboard
        // (targetSdk 36 draws edge to edge, so the keyboard no longer resizes the window by itself).
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            int l, t, r, b;
            if (Build.VERSION.SDK_INT >= 30) {
                Insets in = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout()
                        | WindowInsets.Type.ime());
                l = in.left; t = in.top; r = in.right; b = in.bottom;
            } else {
                l = insets.getSystemWindowInsetLeft(); t = insets.getSystemWindowInsetTop();
                r = insets.getSystemWindowInsetRight(); b = insets.getSystemWindowInsetBottom();
            }
            FrameLayout.LayoutParams wp = (FrameLayout.LayoutParams) web.getLayoutParams();
            wp.setMargins(l, t, r, b);
            web.setLayoutParams(wp);
            FrameLayout.LayoutParams sp = (FrameLayout.LayoutParams) statusBg.getLayoutParams();
            sp.height = t;
            statusBg.setLayoutParams(sp);
            return insets;
        });

        // Light system bars to match the app background (Android 14 and older don't draw edge to edge).
        getWindow().setStatusBarColor(Color.WHITE);
        getWindow().setNavigationBarColor(Color.WHITE);
        if (Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                c.setSystemBarsAppearance(
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS);
            }
        }

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);          // the app saves its data in localStorage
        s.setAllowFileAccess(true);
        s.setGeolocationEnabled(true);
        s.setTextZoom(100);                    // keep the designed type sizes regardless of system font scale
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);

        web.setWebViewClient(new WebViewClient() {
            // "Call" opens the dialer and "Open in maps" opens the maps app, instead of loading inside the page.
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri u = request.getUrl();
                String scheme = u.getScheme() == null ? "" : u.getScheme();
                try {
                    if ("tel".equals(scheme)) { startActivity(new Intent(Intent.ACTION_DIAL, u)); return true; }
                    if ("http".equals(scheme) || "https".equals(scheme) || "geo".equals(scheme)) {
                        startActivity(new Intent(Intent.ACTION_VIEW, u));
                        return true;
                    }
                } catch (Exception ignored) { return true; }
                return false;
            }
        });

        web.setWebChromeClient(new WebChromeClient() {
            // <input type="file">: the camera when the page asks for a capture, otherwise the system picker.
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                if (params.isCaptureEnabled() && openCamera()) return true;
                try {
                    startActivityForResult(params.createIntent(), PICK_FILE);
                } catch (Exception e) {
                    fileCallback = null;
                    return false;
                }
                return true;
            }

            // navigator.geolocation: ask for the Android permission once, then let the page have the position.
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    callback.invoke(origin, true, false);
                    return;
                }
                geoOrigin = origin;
                geoCallback = callback;
                requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION}, ASK_LOCATION);
            }
        });

        web.addJavascriptInterface(new NativeBridge(), "MetrxNative");
        WebView.setWebContentsDebuggingEnabled(true); // inspect via chrome://inspect while testing

        if (savedInstanceState != null) web.restoreState(savedInstanceState);
        else web.loadUrl("file:///android_asset/index.html");

        if (Build.VERSION.SDK_INT >= 33) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                    OnBackInvokedDispatcher.PRIORITY_DEFAULT, this::handleBack);
        }
    }

    /** Ask the page to step back (close sheet, pop screen, return to Home); leave the app only when it declines. */
    private void handleBack() {
        web.evaluateJavascript("(window.metrxBack&&window.metrxBack())?'1':'0'", result -> {
            if (!"\"1\"".equals(result)) moveTaskToBack(true);
        });
    }

    @SuppressWarnings("deprecation")
    @Override
    public void onBackPressed() {
        handleBack();
    }

    /** Opens the camera app; the photo goes to the phone's gallery and back to the page. */
    private boolean openCamera() {
        try {
            ContentValues cv = new ContentValues();
            cv.put(MediaStore.Images.Media.DISPLAY_NAME, "METRX_" + System.currentTimeMillis() + ".jpg");
            cv.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
            cameraUri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cv);
            if (cameraUri == null) return false;
            Intent i = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            i.putExtra(MediaStore.EXTRA_OUTPUT, cameraUri);
            i.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivityForResult(i, TAKE_PHOTO);
            return true;
        } catch (Exception e) {
            dropCameraUri();
            return false;
        }
    }

    private void dropCameraUri() {
        try { if (cameraUri != null) getContentResolver().delete(cameraUri, null, null); } catch (Exception ignored) { }
        cameraUri = null;
    }

    @SuppressWarnings("deprecation")
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PICK_FILE && fileCallback != null) {
            fileCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data));
            fileCallback = null;
        } else if (requestCode == TAKE_PHOTO && fileCallback != null) {
            if (resultCode == RESULT_OK && cameraUri != null) {
                fileCallback.onReceiveValue(new Uri[]{cameraUri});
                cameraUri = null;
            } else {
                fileCallback.onReceiveValue(null);
                dropCameraUri();
            }
            fileCallback = null;
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == ASK_LOCATION && geoCallback != null) {
            boolean ok = false;
            for (int g : grantResults) if (g == PackageManager.PERMISSION_GRANTED) ok = true;
            geoCallback.invoke(geoOrigin, ok, false);
            geoCallback = null;
        }
    }

    /** Saves a file to Downloads/METRX and returns its address for sharing. Needs Android 10 or newer. */
    private Uri saveToDownloads(String name, String mime, byte[] data) throws Exception {
        if (Build.VERSION.SDK_INT < 29) return null;
        ContentValues cv = new ContentValues();
        cv.put(MediaStore.Downloads.DISPLAY_NAME, name);
        cv.put(MediaStore.Downloads.MIME_TYPE, mime);
        cv.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/METRX");
        Uri u = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
        if (u == null) return null;
        try (OutputStream os = getContentResolver().openOutputStream(u)) {
            if (os == null) return null;
            os.write(data);
        }
        return u;
    }

    private void shareUri(Uri u, String mime, String title) {
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType(mime);
        i.putExtra(Intent.EXTRA_STREAM, u);
        i.putExtra(Intent.EXTRA_SUBJECT, title);
        i.putExtra(Intent.EXTRA_TITLE, title);
        i.setClipData(ClipData.newUri(getContentResolver(), title, u));   // the share sheet shows the file name
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivity(Intent.createChooser(i, title));
    }

    /** Lays the report out off screen at A4 width, draws each page into a PDF, saves it and opens the share sheet. */
    @SuppressLint("SetJavaScriptEnabled")
    private void makePdf(String html, String name, int pages) {
        final float density = getResources().getDisplayMetrics().density;
        final int pageW = Math.round(595 * density), pageH = Math.round(842 * density);
        final int count = Math.max(1, Math.min(pages, 60));
        final WebView w = new WebView(this);
        w.setVisibility(View.INVISIBLE);
        w.getSettings().setTextZoom(100);
        root.addView(w, 0, new FrameLayout.LayoutParams(pageW, pageH * count));
        w.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                // give the web fonts and embedded photos a moment to paint
                view.postDelayed(() -> {
                    try {
                        PdfDocument doc = new PdfDocument();
                        for (int i = 0; i < count; i++) {
                            PdfDocument.Page page = doc.startPage(new PdfDocument.PageInfo.Builder(595, 842, i + 1).create());
                            Canvas c = page.getCanvas();
                            c.scale(595f / pageW, 595f / pageW);
                            c.translate(0, -i * pageH);
                            view.draw(c);
                            doc.finishPage(page);
                        }
                        ByteArrayOutputStream out = new ByteArrayOutputStream();
                        doc.writeTo(out);
                        doc.close();
                        Uri u = saveToDownloads(name, "application/pdf", out.toByteArray());
                        if (u != null) shareUri(u, "application/pdf", name);
                        web.evaluateJavascript("window.__metrxShared&&window.__metrxShared(" + (u != null) + ")", null);
                    } catch (Exception e) {
                        web.evaluateJavascript("window.__metrxShared&&window.__metrxShared(false)", null);
                    } finally {
                        root.removeView(view);
                        view.destroy();
                    }
                }, 900);
            }
        });
        w.loadDataWithBaseURL("file:///android_asset/", html, "text/html", "utf-8", null);
    }

    /** What the page can ask the phone to do. */
    private class NativeBridge {
        /** Switches the area behind the status bar between light screens and the dark opening/welcome screens. */
        @JavascriptInterface
        public void setDarkTop(boolean dark) {
            runOnUiThread(() -> {
                statusBg.setBackgroundColor(dark ? Color.rgb(14, 28, 54) : Color.WHITE);
                getWindow().setStatusBarColor(dark ? Color.rgb(14, 28, 54) : Color.WHITE);
                if (Build.VERSION.SDK_INT >= 30) {
                    WindowInsetsController c = getWindow().getInsetsController();
                    if (c != null) c.setSystemBarsAppearance(dark ? 0 : WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS,
                            WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS);
                }
            });
        }

        /** A report or quote as a PDF in the phone's share sheet. */
        @JavascriptInterface
        public void sharePdf(String html, String name, int pages) {
            runOnUiThread(() -> makePdf(html, name, pages));
        }

        /** A text file (the backup) in the phone's share sheet. */
        @JavascriptInterface
        public void shareFile(String name, String text, String mime) {
            runOnUiThread(() -> {
                try {
                    Uri u = saveToDownloads(name, mime, text.getBytes(StandardCharsets.UTF_8));
                    if (u != null) shareUri(u, mime, name);
                } catch (Exception ignored) { }
            });
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }
}
