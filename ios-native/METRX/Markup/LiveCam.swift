import SwiftUI
import AVFoundation
import UIKit
import Observation

/*
 * The live camera (prototype camera.js PAGES.liveCam; Android ui/markup/LiveCam.kt): draw a line on the live view,
 * take its length from the laser or type it, then save the frame. The app never works a distance out from the picture:
 * the number is the laser's or typed. The line stays where it was drawn on the screen (no AR tracking), so the saved
 * frame is the lasting record.
 */

private let LC_BG = Color(argb: 0xFF0B1020)
private let LC_VIEW = Color(argb: 0xFF161D30)
private let LC_MUTED = Color(argb: 0xFFC9D1E3)
private let LC_RED = Color(argb: 0xFFD92D20)

/// The live camera's line (as parts of the view's width and height), its length and where the length came from.
@Observable
final class LiveLine {
    static let shared = LiveLine()
    var line: [Double]? = nil
    var v: Int? = nil
    var src: String? = nil
    func clear() { line = nil; v = nil; src = nil }
}

/// The camera: the back camera's preview, and the latest frame for saving.
final class LiveCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "metrx.livecam")
    private let ctx = CIContext()
    private var last: CGImage? = nil
    private let lock = NSLock()

    /// Starts the camera; done(false) when there is none.
    func start(_ done: @escaping (Bool) -> Void) {
        queue.async {
            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: dev) else { DispatchQueue.main.async { done(false) }; return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            if self.session.canAddInput(input) { self.session.addInput(input) }
            let out = AVCaptureVideoDataOutput()
            out.setSampleBufferDelegate(self, queue: self.queue)
            out.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(out) { self.session.addOutput(out) }
            if let c = out.connection(with: .video) {
                if #available(iOS 17.0, *), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async { done(true) }
        }
    }

    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let px = CMSampleBufferGetImageBuffer(sb), let cg = ctx.createCGImage(CIImage(cvPixelBuffer: px), from: CIImage(cvPixelBuffer: px).extent) else { return }
        lock.lock(); last = cg; lock.unlock()
    }

    /// The latest frame, cropped to what a view of this aspect shows (the preview fills its view).
    func frame(aspect: CGFloat) -> UIImage? {
        lock.lock(); let cg = last; lock.unlock()
        guard let cg else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        var r = CGRect(x: 0, y: 0, width: w, height: h)
        if w / h > aspect { r.size.width = h * aspect; r.origin.x = (w - r.width) / 2 } else { r.size.height = w / aspect; r.origin.y = (h - r.height) / 2 }
        return cg.cropping(to: r.integral).map { UIImage(cgImage: $0) }
    }
}

private final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        if #available(iOS 17.0, *), let c = v.preview.connection, c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        return v
    }
    func updateUIView(_ v: PreviewUIView, context: Context) {}
}

struct LiveCamScreen: View {
    let app: AppModel
    @State private var cam = LiveCamera()
    @State private var s = LiveLine.shared
    @State private var err: String? = nil
    @State private var on = false
    @State private var viewSize = CGSize.zero
    @State private var start: CGPoint? = nil

    var body: some View {
        let bt = AppSettings.shared.laser == .connected
        let en = AppSettings.shared.lang == .en
        let stateText = s.v != nil ? tr(s.src == "laser" ? "cm.s2l" : "cm.s2m") : s.line != nil ? tr(bt ? "cm.s1" : "cm.s1off") : tr("cm.s0")
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                MIcon("x", .white, 22, 2).frame(width: 44, height: 44).pressable(0.95, label: tr("common.close")) { app.pop() }.accessibilityIdentifier("back")
                T(tr("cm.live"), ui(17, 700, .white), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    MIcon(bt ? "bt" : "btoff", bt ? .white : Color(argb: 0xFFFFD7A8), 16, 2)
                    T(tr(bt ? "dev.conn" : "dev.disc"), ui(12.5, 500, bt ? .white : Color(argb: 0xFFFFD7A8)), lines: 1)
                }
                .padding(.horizontal, 10).frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.14)))
                .pressable(0.97) { app.openLaser() }
            }
            .padding(.leading, 6).padding(.trailing, 12).frame(minHeight: 56)
            if let err {
                VStack(spacing: 12) {
                    MIcon("camera", .white, 32, 2).frame(width: 72, height: 72).background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.12)))
                    T(tr("cm.errT"), ui(20, 800, .white))
                    T(tr(err == "denied" ? "cm.errDenied" : "cm.errNone"), ui(14.5, 400, LC_MUTED, lh: 1.5), align: .center).frame(maxWidth: 300)
                    GBtn(tr("cm.photo"), icon: "camera", fill: false) { MarkOps.shared.pickPhoto(PhotoTarget(pid: nil, wid: nil), camera: true) }
                        .accessibilityIdentifier("lc.photo")
                }
                .padding(.horizontal, 28).padding(.vertical, 24).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .top) {
                    LC_VIEW
                    if on { CameraPreview(session: cam.session) }
                    GeometryReader { geo in
                        Canvas { ctx, size in drawLine(ctx, size, en) }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                                guard on, app.sheet == nil else { return }
                                let a = at(v.startLocation, geo.size), b = at(v.location, geo.size)
                                if start == nil { start = v.startLocation; s.v = nil; s.src = nil }
                                s.line = [a.0, a.1, b.0, b.1]
                            }.onEnded { _ in
                                start = nil
                                if let l = s.line, hypot((l[2] - l[0]) * geo.size.width, (l[3] - l[1]) * geo.size.height) < 18 { s.line = nil }
                            })
                            .onAppear { viewSize = geo.size }
                            .onChange(of: geo.size) { _, n in viewSize = n }
                    }
                    if on && s.line == nil {
                        T(tr("cm.hint"), ui(13.5, 500, .white), align: .center).padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LC_BG.opacity(0.72))).padding(12)
                    }
                    if !on { T(tr("cm.starting"), ui(14, 400, LC_MUTED)).frame(maxHeight: .infinity) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 10)
            }
            T(stateText, ui(14, 600, .white, lh: 1.35)).frame(maxWidth: .infinity, minHeight: 30, alignment: .leading).padding(.horizontal, 16).padding(.top, 10)
            HStack(alignment: .top, spacing: 8) { MIcon("info", LC_MUTED, 16, 2); T(tr("cm.steady"), ui(12.5, 400, LC_MUTED, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading) }
                .padding(.horizontal, 16).padding(.top, 4)
            HStack(spacing: 8) {
                LcBtn(icon: "kbd", label: tr("ed2.manual"), enabled: s.line != nil, pri: false) { app.sheet = .lcManual }
                LcBtn(icon: "laser", label: tr("qc.measure"), enabled: s.line != nil, pri: true) { measure() }.layoutPriority(1)
                LcBtn(icon: "save", label: tr("common.save"), enabled: s.v != nil && on, pri: false) { save() }
            }
            .padding(.horizontal, 10).padding(.vertical, 12)
        }
        .background(LC_BG.ignoresSafeArea())
        .onAppear { begin() }
        .onDisappear { cam.stop() }
        // with a line drawn, a real laser's measurement is its length
        .laserSink { mm in
            guard LiveLine.shared.line != nil else { return false }
            LiveLine.shared.v = mm; LiveLine.shared.src = "laser"
            return true
        }
    }

    /// The real laser's next measurement; with no laser the radar to connect one; the screen tests' simulator: a
    /// made-up length.
    private func measure() {
        let ln = LiveLine.shared
        if LaserRouter.shared.isReal {
            LaserRouter.shared.waitFor { mm in
                if ln.line != nil { ln.v = mm; ln.src = "laser" } else { AppSettings.shared.addReading(mm, "laser") }
            }
            return
        }
        guard LaserRouter.shared.simOn else { app.openLaser(); return }
        ln.v = 600 + Int.random(in: 0...7600); ln.src = "laser"
    }

    private func at(_ p: CGPoint, _ size: CGSize) -> (Double, Double) {
        (Double(min(max(p.x / max(1, size.width), 0.015), 0.985)), Double(min(max(p.y / max(1, size.height), 0.015), 0.985)))
    }

    private func begin() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cam.start { ok in if ok { on = true } else { err = "none" } }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { if ok { cam.start { if $0 { on = true } else { err = "none" } } } else { err = "denied" } }
            }
        default: err = "denied"
        }
    }

    private func save() {
        guard let ln = s.line, let v = s.v, viewSize.height > 0 else { return }
        guard let frame = cam.frame(aspect: viewSize.width / viewSize.height) else { app.say("mk.photoErr", kind: .info); return }
        let id = uid()
        guard let saved = PhotoFiles.save(id, frame, quality: 0.78) else { app.say("mk.photoErr", kind: .info); return }
        let hh = 1000 * Double(saved.2) / Double(max(1, saved.1))
        let el = MkEl(id: uid(), t: "dim", pts: [[(ln[0] * 1000).rounded(), (ln[1] * hh).rounded()], [(ln[2] * 1000).rounded(), (ln[3] * hh).rounded()]],
                      c: "red", v: v, src: s.src == "laser" ? "laser" : "manual")
        let it = MarkOps.shared.addPhoto(PhotoTarget(pid: nil, wid: nil), id, saved.0, saved.1, saved.2, els: [el])
        s.clear()
        app.pop(); app.say("cm.saved"); app.push(.markup(pid: nil, iid: it.id))
    }

    /// The red line drawn over the live view, with its length (prototype lcLineSVG).
    private func drawLine(_ ctx: GraphicsContext, _ size: CGSize, _ en: Bool) {
        guard let l = s.line else { return }
        let x1 = l[0] * size.width, y1 = l[1] * size.height, x2 = l[2] * size.width, y2 = l[3] * size.height
        let dx = x2 - x1, dy = y2 - y1, len0 = hypot(dx, dy), len = len0 > 0 ? len0 : 1
        let nx = -dy / len * 9, ny = dx / len * 9
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2))
        p.move(to: CGPoint(x: x1 - nx, y: y1 - ny)); p.addLine(to: CGPoint(x: x1 + nx, y: y1 + ny))
        p.move(to: CGPoint(x: x2 - nx, y: y2 - ny)); p.addLine(to: CGPoint(x: x2 + nx, y: y2 + ny))
        ctx.stroke(p, with: .color(Color.white.opacity(0.85)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        ctx.stroke(p, with: .color(LC_RED), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let has = s.v != nil
        let txt = has ? Geo.fmtLen(s.v, AppSettings.shared.unit, en, full: true) + " " + unitName() : "?"
        let t = ctx.resolve(Text(txt).font(.custom(fontName(.num, 700), fixedSize: 17)).foregroundColor(has ? .white : Color(argb: 0xFFB42318)))
        let ts = t.measure(in: CGSize(width: 400, height: 100))
        let tw = ts.width + 24, mx = (x1 + x2) / 2, ly = max(18, (y1 + y2) / 2 - 26)
        let pill = Path(roundedRect: CGRect(x: mx - tw / 2, y: ly - 15, width: tw, height: 30), cornerRadius: 15)
        ctx.fill(pill, with: .color(has ? LC_RED : .white)); ctx.stroke(pill, with: .color(LC_RED), lineWidth: 1.5)
        ctx.draw(t, at: CGPoint(x: mx, y: ly), anchor: .center)
    }
}

private struct LcBtn: View {
    let icon: String
    let label: String
    let enabled: Bool
    let pri: Bool
    let action: () -> Void
    var body: some View {
        HStack(spacing: 6) { MIcon(icon, .white, 18, 2); T(label, ui(15, 700, .white), lines: 1) }
            .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(pri ? G.cobalt : Color.white.opacity(0.14)))
            .opacity(enabled ? 1 : 0.4)
            .pressable(0.97) { if enabled { action() } }
    }
}

private enum LF: Hashable { case v }

/// Typing the line's length (prototype SHEETS.lcManual).
struct LcManualSheet: View {
    let app: AppModel
    @State private var v = ""
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: LF?
    var body: some View {
        let s = LiveLine.shared, st = AppSettings.shared, en = st.lang == .en
        let parsed = Geo.lenErr(v, Geo.dimMax("A"), st.unit, en)
        GlassSheet(tr("cm.manT"), onClose: { app.sheet = nil }) {
            NumField(label: tr("mk.value"), value: $v, suffix: unitName(), error: errText(parsed), showError: tried || !v.isEmpty, focus: $focus, me: .v)
        } footer: {
            GBtn(tr("common.save")) {
                guard !v.isEmpty, let mm = parsed.value else { tried = true; return }
                s.v = Int(mm); s.src = "manual"; app.sheet = nil
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true; v = s.v.map { Geo.fmtLen($0, st.unit, en, full: true) } ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .v }
        }
    }
}
