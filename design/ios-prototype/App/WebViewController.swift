import CoreLocation
import PDFKit
import UIKit
import WebKit

/// Shows the bundled web app (index.html) in a web view, the same way the Android shell does, and gives it the
/// phone's share sheet, files and location.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler,
                               CLLocationManagerDelegate {
    private var webView: WKWebView!
    private let topBar = UIView()
    private let ink = UIColor(red: 14 / 255, green: 28 / 255, blue: 54 / 255, alpha: 1)
    private var pdfWeb: WKWebView?
    private var pdfName = "METRX.pdf"
    private var pdfPages = 1
    private let locationManager = CLLocationManager()
    private var waitingForLocationPermission = false

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
        let bridge = """
        (function(){var post=function(m){window.webkit.messageHandlers.metrx.postMessage(m)};
        window.MetrxNative={
          setDarkTop:function(d){post({darkTop:!!d})},
          sharePdf:function(html,name,pages){post({pdf:String(html),name:String(name),pages:pages|0})},
          shareFile:function(name,text,mime){post({file:String(text),name:String(name)})},
          getLocation:function(){post({location:true})}
        };})();
        """
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
        guard let body = message.body as? [String: Any] else { return }
        if let dark = body["darkTop"] as? Bool { darkTop = dark }
        if let html = body["pdf"] as? String {
            makePDF(html: html, name: (body["name"] as? String) ?? "METRX.pdf", pages: (body["pages"] as? Int) ?? 1)
        }
        if let text = body["file"] as? String { shareText(text, name: (body["name"] as? String) ?? "metrx-backup.metrx") }
        if body["location"] != nil { requestLocation() }
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

    // MARK: PDF, files and the share sheet

    /// Lays the report out off screen at A4 width, takes each 595 x 842 page as PDF and opens the share sheet.
    private func makePDF(html: String, name: String, pages: Int) {
        pdfWeb?.removeFromSuperview()
        let off = WKWebView(frame: CGRect(x: -2000, y: 0, width: 595, height: 842))
        off.navigationDelegate = self
        view.insertSubview(off, at: 0)
        pdfWeb = off
        pdfName = name
        pdfPages = max(1, min(pages, 60))
        off.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === pdfWeb else { return }
        // give the web fonts and embedded photos a moment to paint
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.addPDFPage(0, to: PDFDocument())
        }
    }

    private func addPDFPage(_ index: Int, to document: PDFDocument) {
        guard let off = pdfWeb else { return }
        if index >= pdfPages { finishPDF(document); return }
        let config = WKPDFConfiguration()
        config.rect = CGRect(x: 0, y: CGFloat(index) * 842, width: 595, height: 842)
        off.createPDF(configuration: config) { [weak self] result in
            if case .success(let data) = result, let part = PDFDocument(data: data), let page = part.page(at: 0) {
                document.insert(page, at: document.pageCount)
            }
            self?.addPDFPage(index + 1, to: document)
        }
    }

    private func finishPDF(_ document: PDFDocument) {
        pdfWeb?.removeFromSuperview()
        pdfWeb = nil
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(pdfName)
        let ok = document.pageCount > 0 && document.write(to: url)
        if ok { share(url) }
        webView.evaluateJavaScript("window.__metrxShared&&window.__metrxShared(\(ok))", completionHandler: nil)
    }

    private func shareText(_ text: String, name: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            share(url)
        } catch { }
    }

    private func share(_ url: URL) {
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        present(sheet, animated: true)
    }

    // MARK: Location

    private func requestLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        switch locationManager.authorizationStatus {
        case .notDetermined:
            waitingForLocationPermission = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            sendLocation(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForLocationPermission else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .authorizedWhenInUse, .authorizedAlways:
            waitingForLocationPermission = false
            manager.requestLocation()
        default:
            waitingForLocationPermission = false
            sendLocation(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        sendLocation(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        sendLocation(nil)
    }

    private func sendLocation(_ location: CLLocation?) {
        var script = "window.__metrxLoc&&window.__metrxLoc(null)"
        if let l = location {
            script = "window.__metrxLoc&&window.__metrxLoc(\(l.coordinate.latitude),\(l.coordinate.longitude),\(l.horizontalAccuracy))"
        }
        webView.evaluateJavaScript(script, completionHandler: nil)
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
