package uz.metrx.prototype;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.graphics.Color;
import android.graphics.Insets;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.window.OnBackInvokedDispatcher;

/** Hosts the METRX HTML design prototype full screen. Not the production app. */
public class MainActivity extends Activity {

    private static final int PICK_FILE = 41;
    private WebView web;
    private FrameLayout root;
    private View statusBg;
    private ValueCallback<Uri[]> fileCallback;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.WHITE);
        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        statusBg = new View(this);
        statusBg.setBackgroundColor(Color.WHITE);
        root.addView(statusBg, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, 0));
        setContentView(root);

        // Keep the page clear of the status bar, navigation bar and display cutout (targetSdk 36 draws edge to edge).
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            int l, t, r, b;
            if (Build.VERSION.SDK_INT >= 30) {
                Insets in = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
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
        s.setDomStorageEnabled(true);          // the prototype saves its data in localStorage
        s.setAllowFileAccess(true);
        s.setTextZoom(100);                    // keep the designed type sizes regardless of system font scale
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setWebViewClient(new WebViewClient() {
            // "Call" on a project card: open the phone's dialer instead of loading the tel: link in the page
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri u = request.getUrl();
                if ("tel".equals(u.getScheme())) {
                    try { startActivity(new Intent(Intent.ACTION_DIAL, u)); } catch (Exception ignored) { }
                    return true;
                }
                return false;
            }
        });
        // <input type="file"> (Photo → Choose from gallery) opens the system picker.
        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                try {
                    startActivityForResult(params.createIntent(), PICK_FILE);
                } catch (Exception e) {
                    fileCallback = null;
                    return false;
                }
                return true;
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

    /** Ask the prototype to step back (close sheet, pop screen, return to Home); leave the app only when it declines. */
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

    @SuppressWarnings("deprecation")
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PICK_FILE && fileCallback != null) {
            fileCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data));
            fileCallback = null;
        }
    }

    /** Lets the page switch the area behind the status bar between light screens and the dark opening/welcome screens. */
    private class NativeBridge {
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
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }
}
