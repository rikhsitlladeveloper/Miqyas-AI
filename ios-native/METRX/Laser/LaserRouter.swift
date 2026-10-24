import SwiftUI
import Observation

/*
 * Where each laser measurement goes, app-wide (Android laser/LaserRouter.kt).
 *
 * With the real laser connected (isReal), a measurement goes, in this order, to:
 *  1. the app's "Lazer" button that is waiting for it (waitFor; the "Lazerda o‘lchang…" bar with Cancel shows meanwhile),
 *  2. the size the screen (or its sheet) has in focus (.laserSink, the newest one on screen first; a sink may pass),
 *  3. the readings' inbox (AppSettings.readings, src "laser"), which the editor's tray and the Measure page show.
 * Without the real laser, the screens make up readings as before ("sim"), when the simulator is connected (simOn):
 * a founder decision, so the app can be tried without a laser.
 */
@Observable
final class LaserRouter {
    static let shared = LaserRouter()

    var real: RealLaser { RealLaser.shared }
    /// The simulated laser is "connected".
    private(set) var simOn = false
    func setSim(_ on: Bool) { simOn = on }

    /// A real laser is connected: every laser button waits for its measurement, nothing is made up.
    var isReal: Bool { real.connected }

    /// The state every screen shows (AppSettings.laser).
    func state() -> Laser {
        if real.connected || simOn { return .connected }
        if real.scanning || (real.link == .connecting && real.userConnect) { return .searching }
        if real.found.values.contains(where: { $0.laser }) { return .found }
        return .disconnected
    }

    /// A button waiting for the next measurement, made on page owner (leaving the page cancels it).
    struct Waiter {
        let owner: Route
        let onCancel: (() -> Void)?
        let take: (Int) -> Void
    }
    private(set) var waiter: Waiter? = nil

    /// The app's "Lazer" button with the real laser: the next measurement goes to take.
    func waitFor(onCancel: (() -> Void)? = nil, _ take: @escaping (Int) -> Void) {
        let old = waiter
        waiter = nil
        old?.onCancel?()
        waiter = Waiter(owner: AppModel.shared.top, onCancel: onCancel, take: take)
    }

    func cancel() {
        guard let w = waiter else { return }
        waiter = nil
        w.onCancel?()
    }

    @ObservationIgnored private var sinks: [LzSinkBox] = []
    func addSink(_ b: LzSinkBox) { if !sinks.contains(where: { $0 === b }) { sinks.append(b) } }
    func removeSink(_ b: LzSinkBox) { sinks.removeAll { $0 === b } }

    @ObservationIgnored private var started = false

    /// Once, when the app starts: the real laser's measurements and news come here, and its state goes to every screen.
    func start() {
        if started { return }
        started = true
        real.onReading = { [weak self] r in self?.dispatch(r) }
        real.onEvent = { [weak self] k, n, u in self?.event(k, n, u) }
        watch()
        real.attach()
    }

    /// Copies state() into AppSettings.laser now and again each time what it is made of changes.
    private func watch() {
        let st = withObservationTracking { state() } onChange: { [weak self] in
            DispatchQueue.main.async { self?.watch() }
        }
        if AppSettings.shared.laser != st { AppSettings.shared.laser = st }
    }

    /// A measurement from the real laser (main thread).
    func dispatch(_ r: LaserReading) {
        if r.mm <= 0 { return }
        if let w = waiter {
            waiter = nil
            LaserLog.add("reading \(r.mm) mm → the waiting button")
            w.take(r.mm)
            return
        }
        for s in sinks.reversed() where s.take(r.mm) {
            LaserLog.add("reading \(r.mm) mm → the size in focus")
            return
        }
        toInbox(r.mm)
    }

    /// The readings' inbox, said as a toast.
    func toInbox(_ mm: Int) {
        let s = AppSettings.shared
        s.addReading(mm, "laser")
        LaserLog.add("reading \(mm) mm → the readings' inbox")
        let v = Geo.fmtLen(mm, s.unit, s.lang == .en, full: true) + " " + unitName()
        AppModel.shared.say("lz.inbox", ["v": v], kind: .info)
    }

    /// The real laser's news, said as a toast; a laser picked in the open Device sheet closes it.
    func event(_ kind: String, _ name: String?, _ user: Bool) {
        let app = AppModel.shared
        switch kind {
        case "connected":
            simOn = false
            if user && app.sheet == .device { app.sheet = nil }
            app.say("lz.connected", ["n": name ?? "ZB-08"])
        case "lost":
            cancel()
            app.say("lz.lost", kind: .info)
        default: break
        }
    }
}

/// A screen's "size in focus": take returns false to pass the measurement on.
final class LzSinkBox {
    var take: (Int) -> Bool
    init(_ take: @escaping (Int) -> Bool) { self.take = take }
}

private struct LzSinkMod: ViewModifier {
    let take: (Int) -> Bool
    @State private var box = LzSinkBox { _ in false }
    func body(content: Content) -> some View {
        // the newest closure, so it sees the screen's current state
        box.take = take
        return content
            .onAppear { LaserRouter.shared.addSink(box) }
            .onDisappear { LaserRouter.shared.removeSink(box) }
    }
}

extension View {
    /// While this is on screen, a real-laser measurement goes to take (the size in focus); take returns false to pass
    /// it on (to a sink below, or the readings' inbox). The newest sink on screen (a sheet over its page) comes first.
    func laserSink(_ take: @escaping (Int) -> Bool) -> some View { modifier(LzSinkMod(take: take)) }
}

/// "Lazerda o‘lchang…" at the top while a button waits for the real laser, with Cancel (Android LaserWaitBar).
struct LaserWaitBar: View {
    var body: some View {
        let on = LaserRouter.shared.waiter != nil
        VStack {
            if on {
                HStack(spacing: 12) {
                    MIcon("laser", Color(argb: 0xFF9DB1FF), 18, 2.2).frame(width: 32, height: 32)
                        .background(Circle().fill(Color(argb: 0xFF9DB1FF).opacity(0.2)))
                    VStack(alignment: .leading, spacing: 1) {
                        T(tr("lz.wait"), ui(14.5, 700, .white, lh: 1.3))
                        T(tr("lz.waitSub"), ui(12.5, 500, Color.white.opacity(0.7), lh: 1.3))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    T(tr("common.cancel"), ui(14, 700, .white), lines: 1)
                        .padding(.horizontal, 14).frame(minHeight: 42)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.12)))
                        .pressable(0.97) { LaserRouter.shared.cancel() }
                        .accessibilityIdentifier("lz.cancel")
                }
                .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 8)
                .frame(minHeight: 58)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(argb: 0xFF0F1626)))
                .boxShadow(Color(argb: 0x52000000), blur: 32, y: 12)
                .padding(.horizontal, 10).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }
            Spacer()
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: on)
        .allowsHitTesting(on)
    }
}
