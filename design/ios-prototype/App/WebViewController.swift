import UIKit
import WebKit

/// Shows the bundled prototype (index.html) in a web view, the same way the Android wrapper does.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private let topBar = UIView()
    private let ink = UIColor(red: 14 / 255, green: 28 / 255, blue: 54 / 255, alpha: 1)

    /// The opening and welcome screens are dark; the page tells us through MetrxNative.setDarkTop.
    private var darkTop = false {
        didSet {
            topBar.backgroundColor = darkTop ? ink : .white
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { darkTop ? .lightContent : .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let content = WKUserContentController()
        content.add(self, name: "metrx")
        // Same bridge name the Android wrapper exposes, so the page needs no iPhone-specific code.
        let bridge = "window.MetrxNative={setDarkTop:function(d){window.webkit.messageHandlers.metrx.postMessage({darkTop:!!d})}};"
        content.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // Keep the designed type sizes, and stop long-press text selection and link previews inside the app.
        let css = "html{-webkit-text-size-adjust:100%}body{-webkit-user-select:none;-webkit-touch-callout:none}"
        let style = "var s=document.createElement('style');s.textContent='\(css)';document.head.appendChild(s);"
        content.addUserScript(WKUserScript(source: style, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never   // the page handles the home-indicator area itself
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false // pinch belongs to the 3D view, not page zoom
        if #available(iOS 16.4, *) { webView.isInspectable = true }  // inspect from Safari on a Mac while testing

        topBar.backgroundColor = .white
        topBar.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            // Below the status bar and the Dynamic Island; down to the bottom edge of the screen.
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // A swipe from the left edge does what the Android back button does.
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeBack(_:)))
        edge.edges = .left
        view.addGestureRecognizer(edge)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("<p style='font:17px -apple-system;padding:24px'>index.html is missing from the app bundle.</p>", baseURL: nil)
        }
    }

    @objc private func edgeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, gesture.translation(in: view).x > 50 else { return }
        webView.evaluateJavaScript("window.metrxBack && window.metrxBack()", completionHandler: nil)
    }

    // MARK: WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: Any], let dark = body["darkTop"] as? Bool { darkTop = dark }
    }

    // MARK: WKNavigationDelegate

    /// "Call" on a project card opens the Phone app; web links open in Safari. The prototype itself is a local file.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }
        let internalSchemes: Set<String> = ["file", "about", "blob", "data"]
        if internalSchemes.contains(scheme) || navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        decisionHandler(.cancel)
    }

    // MARK: WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
