import SwiftUI
import UIKit

/*
 * The laser radar (approved 24 Oct 2026; mockups laser-radar, laser-connect-anim variant A, laser-connect-fail;
 * Android ui/main/LaserRadar.kt): a full page that finds the ZB-08 and connects it. The phone is the blue disc in the
 * middle, rings pulse out from it, a sweep turns; every laser the scan hears ("ZB…" or the SPS service) is a bubble at
 * a fixed angle for its identifier and as near the middle as its signal is strong (−45 dBm near … −90 dBm at the edge).
 * Other Bluetooth devices are behind a link. Tapping a laser connects it: the radar stops and a dashed beam with dots
 * flowing both ways joins the two until the link is ready; then the laser glides into the middle, the middle turns
 * green with a check, the phone gives one soft tap and the next real measurement shows in a box. A failure snaps the
 * beam, shakes the laser, turns the middle orange (fixable) or red (not a laser) and taps twice, with a card saying
 * what to do.
 *
 * The connection itself is RealLaser's (plus the reasons it now tells: Laser/LaserLinkRules.swift). While this page is
 * open, measurements come here first (LaserRouter.radarTake), the "connected"/"lost" toasts are left out, a lost link
 * counts down 4 s here before the app connects again, and background tries wait at most that long.
 *
 * iPhone differences: iOS cannot turn Bluetooth on for an app, so "Bluetooth’ni yoqish" opens Settings (the card says
 * to turn it on there); there is no location switch; the permission is asked by iOS itself when the page opens.
 */

private enum LrMode: String { case noBt, off, denied, search, nothing, found, saved, connecting, connected, failed, lost }

private enum LrTone { case cobalt, warn, bad, off, ok }

/// The mockups' colours that G has no name for (light, dark).
private enum LrC {
    static var dark: Bool { Theme.shared.dark }
    static var warn: Color { dark ? Color(argb: 0xFFFBBF24) : Color(argb: 0xFFD97706) }
    static var warnSoft: Color { warn.opacity(dark ? 0.18 : 0.14) }
    static var warnBg: Color { dark ? G.amberWash : Color(argb: 0xFFFFF4E5) }
    static var bad: Color { dark ? Color(argb: 0xFFF87171) : Color(argb: 0xFFDC2626) }
    static var badSoft: Color { bad.opacity(dark ? 0.16 : 0.12) }
    static var off: Color { dark ? Color(argb: 0xFF56627A) : Color(argb: 0xFF94A3B8) }
    static var okSoft: Color { G.green.opacity(dark ? 0.16 : 0.12) }
    static var cobaltSoft: Color { G.cobalt.opacity(dark ? 0.18 : 0.12) }
    static var hair: Color { G.ink.opacity(dark ? 0.09 : 0.08) }
    static var screen: Color { dark ? Color(argb: 0xFF0F1424) : Color(argb: 0xFFF4F6FC) }

    static func of(_ t: LrTone) -> Color {
        switch t {
        case .cobalt: return G.cobalt
        case .warn: return warn
        case .bad: return bad
        case .off: return off
        case .ok: return G.green
        }
    }

    static func soft(_ t: LrTone) -> Color {
        switch t {
        case .warn: return warnSoft
        case .bad: return badSoft
        case .ok: return okSoft
        default: return cobaltSoft
        }
    }
}

/// The mockups' icons (24 × 24 SVG paths).
private enum LrIcon {
    static let phone = "M9 2.5h6a2.5 2.5 0 0 1 2.5 2.5v14a2.5 2.5 0 0 1 -2.5 2.5h-6a2.5 2.5 0 0 1 -2.5 -2.5v-14a2.5 2.5 0 0 1 2.5 -2.5zM10.5 18.5h3"
    static let check = "M5 12.5l4.5 4.5L19 7"
    static let bang = "M12 6v8M12 18.5v.01"
    static let x = "M7 7l10 10M17 7L7 17"
    static let lock = "M7 11h10a2 2 0 0 1 2 2v5a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-5a2 2 0 0 1 2 -2zM8 11V8a4 4 0 0 1 8 0v3"
    static let btOff = "M7 7l10 10-5 5V2l5 5-4 4M3 3l18 18"
    static let shield = "M12 3l7 3v6c0 4-3 7-7 9-4-2-7-5-7-9V6zM12 9v4M12 16v.01"
    static let sync = "M20 12a8 8 0 0 1 -14 5.3M4 12a8 8 0 0 1 14 -5.3M18 3v4h-4M6 21v-4h4"
    static let help = "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0zM9.5 9.5a2.5 2.5 0 1 1 4 2c-.9.6-1.5 1-1.5 2M12 17v.01"
    static let info = "M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0zM12 8v5M12 16.5v.01"
    static let laser = "M5 7h8a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-8a2 2 0 0 1 -2 -2v-6a2 2 0 0 1 2 -2zM15 12h6M6.5 10.5h3M7.5 14v.01"
}

/// A laser on the radar.
private struct LrBub: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let avg: Double
    var saved = false
    var tone: LrTone = .cobalt
    var badge: String? = nil
    var dim = false
    var sig = false
    var sigText: String? = nil
}

/// cubic-bezier(.3, .8, .3, 1): the laser gliding into the middle.
private func lrGlide(_ x: Double) -> Double {
    let x1 = 0.3, y1 = 0.8, x2 = 0.3, y2 = 1.0
    func bx(_ t: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t
    }
    func by(_ t: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t
    }
    func dx(_ t: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2)
    }
    var t = min(max(x, 0), 1)
    for _ in 0..<8 {
        let d = dx(t)
        if abs(d) < 1e-6 { break }
        t = min(max(t - (bx(t) - x) / d, 0), 1)
    }
    return by(t)
}

/// A value moving from one number to another over dur seconds (times on the reference-date clock); dur 0 is at once.
private struct LrTween {
    var from: Double
    var to: Double
    var at: Double = 0
    var dur: Double = 0
    var glide = false

    init(_ v: Double, glide: Bool = false) { from = v; to = v; self.glide = glide }

    func value(_ now: Double) -> Double {
        if dur <= 0 { return to }
        let t = min(max((now - at) / dur, 0), 1)
        let e = glide ? lrGlide(t) : t
        return from + (to - from) * e
    }

    mutating func go(_ v: Double, _ now: Double, _ d: Double) {
        from = value(now); to = v; at = now; dur = d
    }

    mutating func snap(_ v: Double) { from = v; to = v; dur = 0 }
}

/// The page's motion: the laser gliding in (1 = in the middle) and fading there, the snapped beam, the shake, the jolt.
private struct LrFx {
    var glide = LrTween(0, glide: true)
    var gone = LrTween(0)
    var snapAt: Double? = nil
    var shakeAt: Double? = nil
    var joltAt: Double? = nil

    static func progress(_ start: Double?, _ now: Double, _ dur: Double) -> Double {
        guard let start else { return 1 }
        return min(max((now - start) / dur, 0), 1)
    }

    /// Something of this is still moving at now (the radar's clock runs only then).
    func moving(_ now: Double) -> Bool {
        if glide.dur > 0 && now < glide.at + glide.dur { return true }
        if gone.dur > 0 && now < gone.at + gone.dur { return true }
        if LrFx.progress(snapAt, now, 1.1) < 1 { return true }
        if LrFx.progress(shakeAt, now, 0.5) < 1 { return true }
        return LrFx.progress(joltAt, now, 0.66) < 1
    }
}

private func lrNow() -> Double { Date().timeIntervalSinceReferenceDate }

/// One soft tap when connected, two short ones on a failure.
@MainActor private func lrBuzz(twice: Bool) {
    if twice {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare()
        g.impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 170_000_000)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    } else {
        // one soft tap (a "success" notification would be a double pulse)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

/// What the radar draws, worked out by the page.
private struct LrLook {
    var reduced = false
    var grey = false
    var active = false
    var beamOn = false
    var snapOn = false
    var coreTone: LrTone = .cobalt
    var coreIcon: String = LrIcon.phone
    var bubbles: [LrBub] = []
    var focus: LrBub? = nil
    var fx = LrFx()
}

@MainActor
struct LaserRadarScreen: View {
    let app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduced

    @State private var reading: LaserReading? = nil
    @State private var readingSeq = 0
    @State private var now = Date()
    /// A lost link this page has not answered yet ("Uzish" / "Qidiruvga" answer it).
    @State private var lostAck = RealLaser.shared.lostSeq
    @State private var failStart = RealLaser.shared.failSeq
    @State private var lostStart = RealLaser.shared.lostSeq
    /// When the searching began (nil while not searching, so a new search never starts as "nothing found").
    @State private var searchFrom: Date? = nil
    @State private var othersOpen = false
    @State private var checkOn = false
    @State private var seenConnecting = false
    @State private var fx = LrFx()
    @State private var modeToken = 0
    @State private var lostToken = 0
    /// +1 when a glide, fade or shake has ended: the page is drawn once more, so the radar's clock can stop.
    @State private var settle = 0

    private var real: RealLaser { RealLaser.shared }

    // ---------- what the page is in ----------

    /// The remembered laser is being tried in the background (planned or going on): the dashed bubble, no beam.
    private var savedTrying: Bool {
        guard real.savedId != nil, !real.stopped, !real.paused else { return false }
        return real.retryAt != nil || (real.link == .connecting && !real.userConnect)
    }

    private var lasersNow: [LzFound] {
        let up = lzUptimeMs()
        let trying = savedTrying
        let sid = real.savedId
        // the remembered laser is the dashed bubble while it is tried; every other laser the scan hears shows beside it
        let all = real.found.values.filter { d in d.laser && !LaserRadarMath.stale(d.seen, up) && !(trying && d.id == sid) }
        return all.sorted { $0.avg > $1.avg }
    }

    private var othersNow: [LzFound] {
        real.found.values.filter { !$0.laser }.sorted { $0.rssi > $1.rssi }
    }

    private var lostActive: Bool { real.lostSeq != lostAck }

    private func modeNow(_ lasers: [LzFound]) -> LrMode {
        let fail = real.failure
        if !lzHasBt() || real.bt == .unsupported { return .noBt }
        if fail == .btOff { return .failed }
        if real.bt == .off { return .off }
        if real.bt == .unauthorized { return .denied }
        if real.connected { return .connected }
        // a background try is shown calmly (the dashed SAVED bubble), unless the link was just lost here
        if real.link == .connecting && (real.userConnect || lostActive) { return .connecting }
        if fail != nil { return .failed }
        if lostActive { return .lost }
        if savedTrying { return .saved }
        if !lasers.isEmpty { return .found }
        if let f = searchFrom, now.timeIntervalSince(f) >= 8 { return .nothing }
        return .search
    }

    private func searchish(_ m: LrMode) -> Bool { m == .search || m == .nothing || m == .found }

    private func many(_ m: LrMode) -> Bool {
        guard m == .failed, let f = real.failure else { return false }
        return LaserLinkRules.showMany(f, real.failStreak)
    }

    private var shownName: String { real.linkName ?? real.failName ?? real.savedName ?? "ZB-08" }

    // ---------- the page ----------

    var body: some View {
        let _ = settle
        let lasers = lasersNow
        let m = modeNow(lasers)
        let every = tickEvery(m)
        GeometryReader { geo in
            let size: CGFloat = min(geo.size.width * 0.84, geo.size.height * 0.40, 310)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                    LrRadar(look: look(m, lasers), size: size) { b in tapLaser(b, m) }
                        .padding(.top, 10)
                    statusView(m, lasers)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                cardArea(m, lasers, maxH: geo.size.height * 0.46)
                if othersOpen { othersSheet }
            }
        }
        .onAppear { opened() }
        .onDisappear { closed() }
        .task(id: every) { await tick(every) }
        .task(id: scanKey(m)) { await scanLoop(m) }
        // (initial: the page opened during a try in progress still gets its glide, check and tap)
        .onChange(of: m, initial: true) { _, v in modeChanged(v) }
        .onChange(of: searchish(m), initial: true) { _, v in searchFrom = v ? Date() : nil }
        .onChange(of: real.failSeq) { _, v in failChanged(v) }
        .onChange(of: real.lostSeq) { _, v in lostChanged(v) }
        .onChange(of: othersOpen) { _, v in
            if v { app.backOverride = { othersOpen = false } } else { app.backOverride = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
            VStack(alignment: .leading, spacing: 0) {
                T(tr("lr.title"), ui(19, 800, ls: -0.01), lines: 1)
                T(tr("lr.sub"), ui(12, 600, G.ink3), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).frame(height: 64)
    }

    // ---------- opening, closing, the clock, the scans ----------

    private func opened() {
        real.radar = true
        real.clearFailure()
        real.prepare()
        real.opened()
        LaserRouter.shared.radarTake = { r in
            reading = r
            readingSeq += 1
        }
        if real.connected { checkOn = true; fx.glide.snap(1); fx.gone.snap(1) }
        LaserLog.add("=== radar page open ===")
    }

    private func closed() {
        LaserLog.add("=== radar page closed ===")
        real.radar = false
        // the delayed check, tap and snap of this page do not come after it closed
        modeToken += 1
        lostToken += 1
        LaserRouter.shared.radarTake = nil
        if real.scanning { real.stopScan() }
        real.clearFailure()
        real.kick()
        if othersOpen { app.backOverride = nil }
    }

    /// How often the page's clock ticks in mode m (0: not at all): the lost link's countdown bar 10 a second, the moving
    /// dots of a title 3 a second, "nothing found" after 8 s and lasers not heard for a while leaving once a second.
    private func tickEvery(_ m: LrMode) -> Double {
        if m == .lost { return 0.1 }
        let dotted = m == .search || m == .nothing || m == .saved || m == .connecting || (m == .connected && !checkOn)
        if dotted && !reduced { return 0.3 }
        if dotted || searchish(m) { return 1 }
        return 0
    }

    /// The page's clock (see tickEvery); nothing redraws the page while no clock is needed.
    private func tick(_ every: Double) async {
        now = Date()
        if every <= 0 { return }
        let ns = UInt64(every * 1_000_000_000)
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: ns)
            now = Date()
        }
    }

    /// Scanning goes on while searching and beside the remembered laser's background tries (another laser may show).
    private func scanMode(_ m: LrMode) -> Bool { searchish(m) || m == .saved }

    private func scanKey(_ m: LrMode) -> String { "\(scanMode(m))-\(real.scanning)-\(real.link)" }

    /// Scan after scan while searching (15 s each, the list kept); a scan that would not start is tried again.
    private func scanLoop(_ m: LrMode) async {
        if !scanMode(m) {
            if real.scanning { real.stopScan() }
            return
        }
        if real.scanning || real.link != .idle { return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        while !Task.isCancelled {
            real.startScan(keep: true)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    // ---------- motion ----------

    private func modeChanged(_ m: LrMode) {
        let failText = real.failure.map { " (\($0), try \(real.failStreak))" } ?? ""
        LaserLog.add("radar: \(m.rawValue)" + failText)
        modeToken += 1
        let token = modeToken
        switch m {
        case .connecting:
            seenConnecting = true; checkOn = false
            fx.glide.snap(0); fx.gone.snap(0)
            reading = nil
        case .saved:
            // the remembered laser coming up by itself gets the same glide, check and tap as a tapped one
            seenConnecting = true; checkOn = false
            fx.glide.snap(0); fx.gone.snap(0)
        case .connected:
            if seenConnecting {
                seenConnecting = false
                let d: Double = reduced ? 0 : 0.7
                fx.glide.go(1, lrNow(), d)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
                    guard token == modeToken else { return }
                    checkOn = true
                    lrBuzz(twice: false)
                    let fade: Double = reduced ? 0 : 0.32
                    fx.gone.go(1, lrNow(), fade)
                    settleAfter(fade)
                }
            } else {
                checkOn = true; fx.glide.snap(1); fx.gone.snap(1)
            }
        case .lost:
            checkOn = false
        default:
            checkOn = false; seenConnecting = false
            if m != .failed { fx.glide.snap(0); fx.gone.snap(0) }
        }
    }

    private func failFx(line: Bool) {
        lrBuzz(twice: true)
        if reduced { return }
        let t = lrNow()
        if line { fx.snapAt = t }
        fx.shakeAt = t
        fx.joltAt = t
        settleAfter(1.1)
    }

    /// Draws the page once more after s seconds, when the motion started now has ended (the radar's clock stops then).
    private func settleAfter(_ s: Double) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((s + 0.05) * 1_000_000_000))
            settle += 1
        }
    }

    private func failChanged(_ seq: Int) {
        guard seq != failStart, let f = real.failure, f != .permission else { return }
        fx.glide.snap(0); fx.gone.snap(0)
        failFx(line: f != .btOff)
    }

    /// The laser comes back out of the middle to its spot, then the beam snaps.
    private func lostChanged(_ seq: Int) {
        guard seq != lostStart else { return }
        fx.gone.snap(0); fx.glide.snap(1)
        let d: Double = reduced ? 0 : 0.6
        fx.glide.go(0, lrNow(), d)
        lostToken += 1
        let token = lostToken
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
            guard token == lostToken else { return }
            failFx(line: true)
        }
    }

    // ---------- what the radar draws ----------

    private func look(_ m: LrMode, _ lasers: [LzFound]) -> LrLook {
        let fail = real.failure
        let failedFixable = m == .failed && (fail == .btOff || fail == .permission)
        var l = LrLook()
        l.reduced = reduced
        l.grey = m == .noBt || m == .off || m == .denied || failedFixable
        l.active = !l.grey && (searchish(m) || m == .saved)
        l.coreTone = coreTone(m, fail, l.grey)
        l.coreIcon = coreIcon(m, fail)
        l.bubbles = bubbles(m, lasers)
        let focusId: UUID?
        switch m {
        case .connecting, .connected: focusId = real.linkId
        case .lost: focusId = real.linkId ?? real.savedId
        case .failed: focusId = real.failId
        default: focusId = nil
        }
        l.focus = l.bubbles.first { $0.id == focusId }
        l.beamOn = m == .connecting
        l.snapOn = (m == .failed && !failedFixable) || m == .lost
        l.fx = fx
        return l
    }

    private func coreTone(_ m: LrMode, _ fail: LaserFail?, _ grey: Bool) -> LrTone {
        if grey { return .off }
        if m == .failed && fail == .notLaser { return .bad }
        if m == .failed || m == .lost { return .warn }
        if m == .connected && checkOn { return .ok }
        return .cobalt
    }

    private func coreIcon(_ m: LrMode, _ fail: LaserFail?) -> String {
        if m == .off || m == .noBt || (m == .failed && fail == .btOff) { return LrIcon.btOff }
        if m == .denied || (m == .failed && fail == .permission) { return LrIcon.shield }
        if m == .connected && checkOn { return LrIcon.check }
        if many(m) { return LrIcon.help }
        if m == .failed && fail == .timeout { return LrIcon.bang }
        if m == .failed && fail == .busy { return LrIcon.lock }
        if m == .failed && fail == .notLaser { return LrIcon.x }
        if m == .lost { return LrIcon.sync }
        return LrIcon.phone
    }

    private func bub(_ id: UUID?, _ name: String?, _ make: (UUID, String, Int, Double) -> LrBub) -> LrBub? {
        guard let id else { return nil }
        let d = real.found[id]
        return make(id, d?.name ?? name ?? "ZB-08", d?.rssi ?? -60, d?.avg ?? -60)
    }

    private func bubbles(_ m: LrMode, _ lasers: [LzFound]) -> [LrBub] {
        switch m {
        case .search, .nothing, .found:
            return lasers.map { LrBub(id: $0.id, name: $0.name ?? "ZB", rssi: $0.rssi, avg: $0.avg, sig: true) }
        case .saved:
            let word = tr("lr.reconnecting") + "…"
            let b = bub(real.savedId, real.savedName) { i, n, r, v in LrBub(id: i, name: n, rssi: r, avg: v, saved: true, sigText: word) }
            let others: [LrBub] = lasers.map { LrBub(id: $0.id, name: $0.name ?? "ZB", rssi: $0.rssi, avg: $0.avg, sig: true) }
            return (b.map { [$0] } ?? []) + others
        case .connecting:
            let b = bub(real.linkId, real.linkName) { i, n, r, v in LrBub(id: i, name: n, rssi: r, avg: v, sig: real.found[i] != nil) }
            return b.map { [$0] } ?? []
        case .connected:
            // the laser has glided into the middle and faded there
            if fx.gone.to >= 1 && fx.gone.value(lrNow()) >= 1 { return [] }
            let b = bub(real.linkId, real.linkName) { i, n, r, v in LrBub(id: i, name: n, rssi: r, avg: v) }
            return b.map { [$0] } ?? []
        case .failed:
            return failedBubbles()
        case .lost:
            let b = bub(real.linkId ?? real.savedId, real.linkName ?? real.savedName) { i, n, r, v in
                LrBub(id: i, name: n, rssi: r, avg: v, tone: .warn, dim: true)
            }
            return b.map { [$0] } ?? []
        default:
            return []
        }
    }

    private func failedBubbles() -> [LrBub] {
        let fail = real.failure
        if fail == .permission { return [] }
        let b = bub(real.failId, real.failName) { i, n, r, v in
            switch fail {
            case .notLaser?: return LrBub(id: i, name: n, rssi: r, avg: v, tone: .bad, badge: LrIcon.x, dim: true)
            case .busy?: return LrBub(id: i, name: n, rssi: r, avg: v, tone: .warn, badge: LrIcon.lock)
            case .btOff?: return LrBub(id: i, name: n, rssi: r, avg: v, tone: .off, dim: true)
            default: return LrBub(id: i, name: n, rssi: r, avg: v, tone: .warn)
            }
        }
        return b.map { [$0] } ?? []
    }

    private func tapLaser(_ b: LrBub, _ m: LrMode) {
        switch m {
        case .search, .nothing, .found: real.connect(b.id, b.name)
        case .saved: real.connect(b.id, b.id == real.savedId ? (real.savedName ?? b.name) : b.name)
        default: break
        }
    }

    // ---------- the words under the radar ----------

    private func dots(_ s: String) -> String {
        if reduced { return s + "…" }
        let n = Int(now.timeIntervalSinceReferenceDate / 0.3) % 4
        return s + String(repeating: ".", count: n)
    }

    private func connectingTitle() -> String {
        let user = real.userConnect
        let streak = real.failStreak
        let word = dots(tr(lostActive || !user ? "lr.reconnecting" : "lr.connecting"))
        let tryWord = streak >= 1 && user ? " " + tr("lr.try", ["k": streak + 1]) : ""
        return word + tryWord
    }

    private func words(_ m: LrMode, _ lasers: [LzFound]) -> (String, String) {
        let name = shownName
        switch m {
        case .noBt: return (tr("lt.noBt"), "")
        case .off: return (tr("dev.off"), tr("lr.btOffSub"))
        case .denied: return (tr("lr.permNeed"), tr("lr.permSub"))
        case .search: return (dots(tr("lr.searching")), tr("lr.searchSub"))
        case .nothing:
            let secs = Int(now.timeIntervalSince(searchFrom ?? now))
            return (dots(tr("lr.searching")), tr("lr.noneSub", ["s": secs]))
        case .found: return (tr("lr.found", ["n": lasers.count]), tr("lr.foundSub", ["n": lasers.first?.name ?? "ZB-08"]))
        case .saved: return (dots(tr("lr.reconnecting")), tr("lr.savedSub", ["n": real.savedName ?? "ZB-08"]))
        case .connecting: return (connectingTitle(), tr("lr.connectingSub", ["n": name]))
        case .connected:
            if !checkOn { return (connectingTitle(), tr("lr.connectingSub", ["n": name])) }
            if lostActive { return (tr("lr.reconnected", ["n": name]), tr("lr.goOn")) }
            return (tr("lr.connected", ["n": name]), tr("lr.connectedSub"))
        case .lost: return (tr("lr.lost"), tr("lr.reconnecting") + "…")
        case .failed: return failWords(m, name)
        }
    }

    private func failWords(_ m: LrMode, _ name: String) -> (String, String) {
        if many(m) { return (tr("lr.fMany"), tr("lr.fManySub", ["k": real.failStreak])) }
        switch real.failure {
        case .timeout?: return (tr("lr.fTimeout"), tr("lr.fTimeoutSub", ["n": name]))
        case .busy?: return (tr("lr.fBusy"), tr("lr.fBusySub", ["n": name]))
        case .notLaser?: return (tr("lr.fNot"), tr("lr.fNotSub"))
        case .btOff?: return (tr("lr.fBt"), tr("lr.fBtSub"))
        default: return (tr("lr.permNeed"), tr("lr.permSub"))
        }
    }

    private func statusView(_ m: LrMode, _ lasers: [LzFound]) -> some View {
        let w = words(m, lasers)
        return VStack(spacing: 4) {
            T(w.0, ui(18, 800, lh: 1.25), align: .center)
            if !w.1.isEmpty { T(w.1, ui(13, 400, G.ink2, lh: 1.45), align: .center) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22).padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    // ---------- the card at the bottom, one per state ----------

    private func cardKey(_ m: LrMode, _ lasers: [LzFound]) -> String {
        switch m {
        case .failed: return many(m) ? "many" : "fail:" + String(describing: real.failure)
        case .found: return "found:" + (lasers.first?.id.uuidString ?? "")
        case .connected: return checkOn ? "connected" : "connecting"
        default: return m.rawValue
        }
    }

    private func cardArea(_ m: LrMode, _ lasers: [LzFound], maxH: CGFloat) -> some View {
        let key = cardKey(m, lasers)
        let warnCard = (m == .failed && real.failure != .notLaser) || m == .lost || m == .noBt || m == .off || m == .denied
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let rise: AnyTransition = reduced ? .opacity : .asymmetric(insertion: .offset(y: 20).combined(with: .opacity), removal: .opacity)
        let inner = VStack(alignment: .leading, spacing: 0) { cardBody(m, lasers) }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        return ZStack(alignment: .bottom) {
            // the card never grows over the words under the radar (Russian, large text, the help list): it scrolls instead
            ViewThatFits(in: .vertical) {
                inner
                ScrollView { inner }
            }
                .frame(maxHeight: maxH)
                .glassCard(shape, fill: warnCard ? LrC.warnBg : G.sheet(0.78), shadowBlur: 30, shadowY: 14)
                .id(key)
                .transition(rise)
        }
        .animation(.easeOut(duration: reduced ? 0.01 : 0.35), value: key)
        .padding(14)
    }

    @ViewBuilder private func cardBody(_ m: LrMode, _ lasers: [LzFound]) -> some View {
        switch m {
        case .noBt, .off, .denied: blockedCard(m)
        case .search: othersLink
        case .nothing:
            LrCardHead(icon: LrIcon.info, tone: .cobalt, title: tr("lr.noneTitle"), text: tr("lr.noneBody"))
            LrTipArt()
            othersLink
        case .found: foundCard(lasers)
        case .saved: savedCard
        case .connecting:
            GBtn(tr("common.cancel"), kind: .secondary, height: 50, corner: 16, fontSize: 15) {
                real.cancelConnect()
                lostAck = real.lostSeq
            }
        case .connected: connectedCard
        case .lost: lostCard
        case .failed: failCard(m)
        }
    }

    private var othersLink: some View {
        let n = othersNow.count
        return LrCardLink(text: tr("lr.others", ["n": n])) { othersOpen = true }
    }

    /// No Bluetooth, Bluetooth off, permission refused. iOS cannot switch Bluetooth on for an app: the button opens
    /// Settings and the card says to turn it on there.
    @ViewBuilder private func blockedCard(_ m: LrMode) -> some View {
        switch m {
        case .off:
            LrCardHead(icon: LrIcon.btOff, tone: .warn, title: tr("lr.btOnTitle"), text: tr("dv.offBody"))
            LrOne(label: tr("lr.btOn"), icon: "bt") { lzOpenSettings() }
        case .denied:
            LrCardHead(icon: LrIcon.shield, tone: .warn, title: tr("lr.permTitle"), text: tr("dv.deniedBody"))
            LrTwo(secLabel: tr("lr.later"), sec: { app.pop() }, label: tr("lr.settings")) { lzOpenSettings() }
        default:
            LrCardHead(icon: LrIcon.btOff, tone: .warn, title: tr("lt.noBt"))
        }
    }

    @ViewBuilder private func foundCard(_ lasers: [LzFound]) -> some View {
        if let best = lasers.first {
            LrCardHead(icon: LrIcon.laser, tone: .cobalt, title: best.name ?? "ZB", text: tr(LaserRadarMath.qualityKey(best.rssi)))
            LrOne(label: tr("dv.connect")) { real.connect(best.id, best.name) }
        }
        othersLink
    }

    private var savedCard: some View {
        let sn = real.savedName ?? "ZB-08"
        return VStack(alignment: .leading, spacing: 0) {
            LrCardHead(icon: LrIcon.laser, tone: .cobalt, title: tr("lr.savedTitle", ["n": sn]), text: tr("lr.savedBody"))
            LrTwo(secLabel: tr("lz.forget"), sec: { real.forget() }, label: tr("lr.now")) {
                if let s = real.savedId { real.connect(s, sn) }
            }
        }
    }

    @ViewBuilder private var connectedCard: some View {
        if !checkOn {
            GBtn(tr("common.cancel"), kind: .secondary, enabled: false, height: 50, corner: 16, fontSize: 15) {}
        } else {
            LrCardHead(icon: LrIcon.laser, tone: .cobalt, title: tr("lr.tryTitle"), text: tr("lr.tryBody"))
            LrReadingBox(r: reading, seq: readingSeq, reduced: reduced)
            LrOne(label: tr("lr.done")) { app.pop() }
        }
    }

    private var lostCard: some View {
        let at = real.retryAt
        let total = Int64(real.retryTotal * 1000)
        var secs = 0
        var done: Double = 0
        if let at {
            let cd = LaserLinkRules.countdown(now: lrMs(now), at: lrMs(at), total: total)
            secs = cd.secs
            done = cd.done
        }
        let msg = at != nil ? tr("lr.lostBody", ["s": secs]) : tr("lr.lostBodyIdle")
        let target = real.linkId ?? real.savedId
        let name = shownName
        return VStack(alignment: .leading, spacing: 0) {
            LrCardHead(icon: LrIcon.sync, tone: .warn, title: tr("lr.lostTitle"), text: msg)
            if at != nil { LrBar(done: done) }
            LrTwo(secLabel: tr("dv.disconnect"), sec: { lostAck = real.lostSeq; real.disconnect() }, label: tr("lr.now")) {
                if let t = target { real.connect(t, name) }
            }
        }
    }

    @ViewBuilder private func failCard(_ m: LrMode) -> some View {
        let fail = real.failure
        let name = shownName
        if many(m) {
            LrCardHead(icon: LrIcon.help, tone: .warn, title: tr("lr.fManyTitle"),
                       bullets: [tr("lr.fMany1"), tr("lr.fMany2"), tr("lr.fMany3"), tr("lr.fMany4")])
            // the laser test page is there only in test mode (7 taps on Profile's version line)
            if AppSettings.shared.devMode {
                LrTwo(secLabel: tr("lt.row"), sec: { app.push(.laserTest) }, label: tr("lr.retry")) { retry() }
            } else {
                LrTwo(secLabel: tr("lr.toSearch"), sec: { toSearch() }, label: tr("lr.retry")) { retry() }
            }
        } else if fail == .timeout {
            LrCardHead(icon: LrIcon.bang, tone: .warn, title: tr("lr.fTimeoutTitle"), bullets: [tr("lr.fTimeout1"), tr("lr.fTimeout2")])
            LrTwo(secLabel: tr("lr.toSearch"), sec: { toSearch() }, label: tr("lr.retry")) { retry() }
        } else if fail == .busy {
            LrCardHead(icon: LrIcon.lock, tone: .warn, title: tr("lr.fBusyTitle"), text: tr("lr.fBusyBody"))
            LrTwo(secLabel: tr("common.cancel"), sec: { toSearch() }, label: tr("lr.retry")) { retry() }
        } else if fail == .notLaser {
            LrCardHead(icon: LrIcon.x, tone: .bad, title: tr("lr.fNotTitle"), text: tr("lr.fNotBody"))
            LrOne(label: tr("lr.fNotBtn")) { toSearch() }
        } else if fail == .btOff {
            // iOS: Bluetooth is turned on in Settings (or Control Centre); the try goes on by itself once it is
            LrCardHead(icon: LrIcon.btOff, tone: .warn, title: tr("lr.fBtTitle"), text: tr("dv.offBody") + " " + tr("lr.fBtBody", ["n": name]))
            LrOne(label: tr("lr.btOn"), icon: "bt") { lzOpenSettings() }
        } else {
            LrCardHead(icon: LrIcon.shield, tone: .warn, title: tr("lr.permTitle"), text: tr("dv.deniedBody"))
            LrTwo(secLabel: tr("lr.later"), sec: { real.clearFailure(); app.pop() }, label: tr("lr.settings")) { lzOpenSettings() }
        }
    }

    private func retry() {
        if let id = real.failId { real.connect(id, real.failName) }
    }

    private func toSearch() {
        lostAck = real.lostSeq
        real.clearFailure()
    }

    // ---------- other Bluetooth devices ----------

    private var othersSheet: some View {
        let others = othersNow
        return GlassSheet(tr("lr.othersTitle"), onClose: { othersOpen = false }) {
            if others.isEmpty { T(tr("lr.othersNone"), ui(13.5, 500, G.ink2, lh: 1.4)) }
            ForEach(Array(others.prefix(30))) { d in
                LrOtherRow(d: d) {
                    othersOpen = false
                    real.connect(d.id, d.name)
                }
            }
        }
        .zIndex(5)
    }
}

private func lrMs(_ d: Date) -> Int64 { Int64(d.timeIntervalSince1970 * 1000) }

// ---------- the radar ----------

private struct LrRadar: View {
    let look: LrLook
    let size: CGFloat
    let onTap: (LrBub) -> Void

    var body: some View {
        // the clock runs only while the radar turns, the beam shows or a glide, fade or shake is going on
        let t0 = lrNow()
        let still = look.reduced || (!look.active && !look.beamOn && !look.fx.moving(t0))
        TimelineView(.animation(minimumInterval: nil, paused: still)) { tl in
            let t: Double = still ? t0 : tl.date.timeIntervalSinceReferenceDate
            LrRadarFrame(look: look, size: size, t: t, onTap: onTap)
        }
        .frame(width: size, height: size)
    }
}

/// One frame of the radar at time t (seconds on the reference-date clock).
private struct LrRadarFrame: View {
    let look: LrLook
    let size: CGFloat
    let t: Double
    let onTap: (LrBub) -> Void

    private var r: CGFloat { size / 2 }
    private var coreD: CGFloat { size * 0.26 }

    var body: some View {
        let glide = look.fx.glide.value(t)
        let gone = look.fx.gone.value(t)
        ZStack(alignment: .topLeading) {
            ringsLayer
            sweepLayer
            beamLayer(glide)
            snapLayer(glide)
            ForEach(look.bubbles) { b in bubble(b, glide, gone) }
            core
        }
        .frame(width: size, height: size, alignment: .topLeading)
    }

    /// Where a laser sits: its angle, its distance (g: 1 = glided into the middle).
    private func spot(_ b: LrBub, _ g: Double) -> CGPoint {
        let a = LaserRadarMath.angle(b.id.uuidString) * .pi / 180
        let dist: CGFloat = r * CGFloat(LaserRadarMath.radius(b.avg) * (1 - g))
        let x: CGFloat = r + dist * CGFloat(cos(a))
        let y: CGFloat = r + dist * CGFloat(sin(a))
        return CGPoint(x: x, y: y)
    }

    private var ringsLayer: some View {
        let col = look.grey ? LrC.hair : LrC.cobaltSoft
        let radius = r
        return Canvas { ctx, _ in LrDraw.rings(ctx, radius, col) }
            .frame(width: size, height: size)
            .opacity(look.active || look.grey ? 1 : 0)
            .animation(.easeInOut(duration: look.reduced ? 0.01 : 0.4), value: look.active || look.grey)
    }

    @ViewBuilder private var sweepLayer: some View {
        if !look.reduced {
            let radius = r
            let coreR = coreD / 2
            let time = t
            let cobalt = G.cobalt
            Canvas { ctx, _ in LrDraw.sweep(ctx, radius, coreR, time, cobalt) }
                .frame(width: size, height: size)
                .opacity(look.active ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: look.active)
        }
    }

    @ViewBuilder private func beamLayer(_ glide: Double) -> some View {
        if let f = look.focus {
            let p = spot(f, glide)
            let c = CGPoint(x: r, y: r)
            let time = t
            let moving = !look.reduced
            let cobalt = G.cobalt
            Canvas { ctx, _ in LrDraw.beam(ctx, p, c, cobalt, time, moving) }
                .frame(width: size, height: size)
                .opacity(look.beamOn ? 1 : 0)
                .animation(.easeInOut(duration: look.reduced ? 0.01 : 0.3), value: look.beamOn)
        }
    }

    @ViewBuilder private func snapLayer(_ glide: Double) -> some View {
        let prog = LrFx.progress(look.fx.snapAt, t, 1.1)
        if look.snapOn, prog < 1, let f = look.focus {
            let p = spot(f, glide)
            let c = CGPoint(x: r, y: r)
            let tone: LrTone = f.tone == .bad ? .bad : .warn
            let col = LrC.of(tone)
            let radius = r
            Canvas { ctx, _ in LrDraw.snap(ctx, p, c, col, prog, radius) }
                .frame(width: size, height: size)
        }
    }

    private func bubble(_ b: LrBub, _ glide: Double, _ gone: Double) -> some View {
        let isFocus = b.id == look.focus?.id
        let p = spot(b, isFocus ? glide : 0)
        let shakeP = LrFx.progress(look.fx.shakeAt, t, 0.5)
        let shake: CGFloat = isFocus && shakeP < 1 ? lrShake(shakeP) : 0
        return LrBubbleView(b: b, reduced: look.reduced, gone: isFocus ? gone : 0) { onTap(b) }
            .offset(x: p.x - 48 + shake, y: p.y - 26)
            .animation(.easeInOut(duration: look.reduced ? 0.01 : 0.7), value: b.avg)
    }

    private var core: some View {
        let joltP = LrFx.progress(look.fx.joltAt, t, 0.66)
        let jolt: CGFloat = joltP < 1 ? CGFloat(sin(joltP * 6 * .pi) * 3) : 0
        let col = LrC.of(look.coreTone)
        let shadow = look.coreTone == .off ? Color.clear : col.opacity(0.4)
        let icon = look.coreIcon
        let stroke: CGFloat = icon == LrIcon.check ? 2.8 : 2
        return ZStack {
            Circle().fill(col)
            PathIcon(icon, .white, coreD * 0.42, stroke)
                .id(icon)
                .transition(.opacity)
        }
        .frame(width: coreD, height: coreD)
        .background(Circle().fill(Color.black.opacity(0.001)).boxShadow(shadow, blur: 22, y: 10))
        .animation(.easeInOut(duration: look.reduced ? 0.01 : 0.35), value: look.coreTone)
        .animation(.easeInOut(duration: look.reduced ? 0.01 : 0.25), value: icon)
        .offset(x: r - coreD / 2 + jolt, y: r - coreD / 2)
        .accessibilityHidden(true)
    }
}

/// The shake's offset in points at t (0…1): −6, 6, −4, 4, 0 as in the mockup.
private func lrShake(_ t: Double) -> CGFloat {
    let keys: [Double] = [0, -6, 6, -4, 4, 0]
    let x = t * 5
    let i = min(max(Int(x), 0), 4)
    let v = keys[i] + (keys[i + 1] - keys[i]) * (x - Double(i))
    return CGFloat(v)
}

/// The radar's drawings (Canvas).
private enum LrDraw {
    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    static func rings(_ ctx: GraphicsContext, _ r: CGFloat, _ color: Color) {
        let c = CGPoint(x: r, y: r)
        let ks: [CGFloat] = [1, 0.68, 0.36]
        for k in ks {
            ctx.stroke(circle(c, r * k - 1), with: .color(color), lineWidth: 1.5)
        }
    }

    /// The turning sweep (3 s a turn) and three staggered pulses out of the phone (2.4 s).
    static func sweep(_ ctx: GraphicsContext, _ r: CGFloat, _ coreR: CGFloat, _ t: Double, _ cobalt: Color) {
        let c = CGPoint(x: r, y: r)
        let spin = t.truncatingRemainder(dividingBy: 3) / 3 * 360
        let stops: [Gradient.Stop] = [
            Gradient.Stop(color: cobalt.opacity(0), location: 0),
            Gradient.Stop(color: cobalt.opacity(0), location: 0.833),
            Gradient.Stop(color: cobalt.opacity(0.05), location: 0.875),
            Gradient.Stop(color: cobalt.opacity(0.28), location: 1)
        ]
        let shading = GraphicsContext.Shading.conicGradient(Gradient(stops: stops), center: c, angle: .degrees(spin))
        ctx.fill(circle(c, r), with: shading)
        let pulse = t.truncatingRemainder(dividingBy: 2.4) / 2.4
        for i in 0..<3 {
            let p = (pulse + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let e = 1 - (1 - p) * (1 - p)
            let rr: CGFloat = coreR * CGFloat(1 + 1.6 * e)
            ctx.stroke(circle(c, rr), with: .color(cobalt.opacity(0.55 * (1 - e))), lineWidth: 2)
        }
    }

    /// Variant A: a dashed line from the laser p to the phone c, its dashes moving, three dots flowing both ways.
    static func beam(_ ctx: GraphicsContext, _ p: CGPoint, _ c: CGPoint, _ color: Color, _ t: Double, _ moving: Bool) {
        var line = Path()
        line.move(to: p)
        line.addLine(to: c)
        let dash: Double = moving ? t.truncatingRemainder(dividingBy: 0.6) / 0.6 : 0
        let phase = CGFloat(1 - dash) * 22
        let style = StrokeStyle(lineWidth: 2.4, lineCap: .butt, dash: [5, 6], dashPhase: phase)
        ctx.stroke(line, with: .color(color.opacity(0.75)), style: style)
        if !moving { return }
        let dots = t.truncatingRemainder(dividingBy: 1.2) / 1.2
        // dots 1 and 3 go laser → phone, dot 2 phone → laser
        for i in 0..<3 {
            var u = (dots - Double(i) / 3).truncatingRemainder(dividingBy: 1)
            if u < 0 { u += 1 }
            let q = i == 1 ? lerp(c, p, CGFloat(u)) : lerp(p, c, CGFloat(u))
            ctx.fill(circle(q, 3.6), with: .color(color))
        }
    }

    /// The link breaking: the line splits in the middle, the gap drifts apart with a small zigzag, then it fades (1.1 s).
    static func snap(_ ctx: GraphicsContext, _ p: CGPoint, _ c: CGPoint, _ color: Color, _ prog: Double, _ r: CGFloat) {
        let ms = prog * 1100
        let dx = p.x - c.x
        let dy = p.y - c.y
        let len = max((dx * dx + dy * dy).squareRoot(), 1)
        let ux = dx / len
        let uy = dy / len
        let m = CGPoint(x: (p.x + c.x) / 2, y: (p.y + c.y) / 2)
        let k = r / 125      // the mockup's stage was 250 px
        let grow = CGFloat(min(max(ms / 350, 0), 1))
        let g: CGFloat = (8.5 + (28.3 - 8.5) * grow) * k
        let la: Double = ms < 600 ? 1 : min(max(1 - (ms - 600) / 500, 0), 1)
        if la > 0 {
            var a = Path()
            a.move(to: p)
            a.addLine(to: CGPoint(x: m.x + ux * g, y: m.y + uy * g))
            var b = Path()
            b.move(to: CGPoint(x: m.x - ux * g, y: m.y - uy * g))
            b.addLine(to: c)
            let st = StrokeStyle(lineWidth: 2.4, lineCap: .round)
            ctx.stroke(a, with: .color(color.opacity(la)), style: st)
            ctx.stroke(b, with: .color(color.opacity(la)), style: st)
        }
        let za: Double = ms < 450 ? ms / 450 : min(max(1 - (ms - 450) / 450, 0), 1)
        if za > 0 {
            var z = Path()
            z.move(to: CGPoint(x: m.x - 7 * k, y: m.y - 3 * k))
            z.addLine(to: CGPoint(x: m.x - 2 * k, y: m.y - 7 * k))
            z.addLine(to: CGPoint(x: m.x, y: m.y - 1 * k))
            z.addLine(to: CGPoint(x: m.x + 5 * k, y: m.y - 5 * k))
            let st = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            ctx.stroke(z, with: .color(color.opacity(za)), style: st)
        }
    }

    /// The "nothing found" tip: a simple drawing of the laser with its Bluetooth button lit (86 × 48 box, scale k).
    static func tip(_ ctx: GraphicsContext, _ k: CGFloat, _ cobalt: Color, _ soft: Color, _ screen: Color) {
        func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ cr: CGFloat) -> Path {
            Path(roundedRect: CGRect(x: x * k, y: y * k, width: w * k, height: h * k), cornerRadius: cr * k)
        }
        let body = rr(4, 6, 60, 36, 7)
        ctx.fill(body, with: .color(soft))
        ctx.stroke(body, with: .color(cobalt), lineWidth: 2 * k)
        let glass = rr(12, 13, 26, 12, 2)
        ctx.fill(glass, with: .color(screen))
        ctx.stroke(glass, with: .color(cobalt), lineWidth: 1.5 * k)
        let btC = CGPoint(x: 52 * k, y: 19 * k)
        ctx.stroke(circle(btC, 9 * k), with: .color(cobalt.opacity(0.5)), lineWidth: 1.5 * k)
        ctx.fill(circle(btC, 5 * k), with: .color(cobalt))
        var rune = Path()
        rune.move(to: CGPoint(x: 50 * k, y: 16.5 * k))
        rune.addLine(to: CGPoint(x: 54 * k, y: 20.5 * k))
        rune.addLine(to: CGPoint(x: 52 * k, y: 22.5 * k))
        rune.addLine(to: CGPoint(x: 52 * k, y: 13.5 * k))
        rune.addLine(to: CGPoint(x: 54 * k, y: 15.5 * k))
        rune.addLine(to: CGPoint(x: 50 * k, y: 19.5 * k))
        ctx.stroke(rune, with: .color(.white), style: StrokeStyle(lineWidth: 1.2 * k, lineCap: .round, lineJoin: .round))
        var beam = Path()
        beam.move(to: CGPoint(x: 64 * k, y: 24 * k))
        beam.addLine(to: CGPoint(x: 82 * k, y: 24 * k))
        ctx.stroke(beam, with: .color(cobalt), style: StrokeStyle(lineWidth: 2 * k, dash: [3 * k, 3 * k]))
    }

    /// Signal bars 1…4.
    static func bars(_ ctx: GraphicsContext, _ size: CGSize, _ n: Int, _ color: Color) {
        let bw: CGFloat = 2.6
        let gap: CGFloat = 1.5
        for i in 0..<4 {
            let h: CGFloat = size.height * (0.4 + 0.2 * CGFloat(i))
            let rect = CGRect(x: CGFloat(i) * (bw + gap), y: size.height - h, width: bw, height: h)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color.opacity(i < n ? 1 : 0.28)))
        }
    }
}

/// A laser bubble: glass circle with the laser drawing, its name, its signal; dashed when remembered, grey when dimmed.
private struct LrBubbleView: View {
    let b: LrBub
    let reduced: Bool
    let gone: Double
    let onTap: () -> Void
    @State private var pop = false

    var body: some View {
        let pv: Double = pop || reduced ? 1 : 0.3
        let s: CGFloat = CGFloat(pv * (1 - 0.6 * gone))
        let a: Double = pv * (1 - gone) * (b.dim ? 0.6 : 1)
        VStack(spacing: 4) {
            disc
            nameTag
            signal
        }
        .frame(width: 96)
        .scaleEffect(s, anchor: UnitPoint(x: 0.5, y: 26.0 / 80.0))
        .opacity(a)
        .onAppear {
            if !reduced { withAnimation(.spring(response: 0.36, dampingFraction: 0.45)) { pop = true } }
        }
    }

    private var disc: some View {
        let col = b.dim ? LrC.off : LrC.of(b.tone)
        let dashed = b.saved || b.dim
        let ring = StrokeStyle(lineWidth: 2, dash: dashed ? [5, 3.5] : [])
        return ZStack(alignment: .topTrailing) {
            PathIcon(LrIcon.laser, col, 28, 2)
                .frame(width: 52, height: 52)
                .background(Circle().fill(G.sheet(0.8)))
                .overlay(Circle().inset(by: 1).stroke(col, style: ring))
                .background(Circle().fill(Color.black.opacity(0.001)).boxShadow(col.opacity(b.dim ? 0 : 0.25), blur: 18, y: 8))
                .pressable(0.94, label: tr("lr.bubble", ["n": b.name]), onTap)
            if let badge = b.badge {
                PathIcon(badge, .white, 14, 2.6)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(LrC.of(b.tone)))
                    .boxShadow(Color.black.opacity(0.2), blur: 6, y: 2)
                    .offset(x: 6, y: -6)
                    .allowsHitTesting(false)
            }
        }
    }

    private var nameTag: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return T(b.name, ui(12, 800), lines: 1)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(shape.fill(G.sheet(0.8)))
            .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var signal: some View {
        if let st = b.sigText {
            T(st, ui(10, 700, G.ink3), lines: 1)
        } else if b.sig {
            HStack(spacing: 4) {
                LrBars(n: LaserRadarMath.bars(b.rssi))
                T("\(b.rssi) dBm", ui(10, 700, G.ink3), lines: 1)
            }
        }
    }
}

private struct LrBars: View {
    let n: Int
    var body: some View {
        let c = G.ink3
        let count = n
        Canvas { ctx, sz in LrDraw.bars(ctx, sz, count, c) }
            .frame(width: 15, height: 10)
            .accessibilityHidden(true)
    }
}

// ---------- the card's pieces ----------


private struct LrCardHead: View {
    let icon: String
    let tone: LrTone
    let title: String
    var text: String? = nil
    var bullets: [String] = []

    var body: some View {
        let plain = text == nil && bullets.isEmpty
        HStack(alignment: plain ? .center : .top, spacing: 12) {
            PathIcon(icon, LrC.of(tone), 24, 2)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LrC.soft(tone)))
            VStack(alignment: .leading, spacing: 4) {
                T(title, ui(15, 800, lh: 1.3))
                if let text { T(text, ui(13, 400, G.ink2, lh: 1.45)) }
                if !bullets.isEmpty { bulletList.padding(.top, 4) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { item in
                HStack(alignment: .top, spacing: 6) {
                    T("•", ui(13, 700, G.ink2, lh: 1.5))
                    T(item.element, ui(13, 400, G.ink2, lh: 1.5)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct LrOne: View {
    let label: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        GBtn(label, icon: icon, height: 50, corner: 16, fontSize: 15, action)
            .padding(.top, 12)
    }
}

private struct LrTwo: View {
    let secLabel: String
    let sec: () -> Void
    let label: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            GBtn(secLabel, kind: .secondary, height: 48, corner: 15, fontSize: 14, lines: 2, sec)
            GBtn(label, height: 48, corner: 15, fontSize: 14, lines: 2, action)
        }
        .padding(.top, 12)
    }
}

private struct LrCardLink: View {
    let text: String
    let action: () -> Void
    var body: some View {
        T(text, ui(13, 700, G.cobalt), align: .center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .pressable(0.98, label: text, action)
            .padding(.top, 10)
    }
}

/// The lost link's countdown bar.
private struct LrBar: View {
    let done: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(LrC.hair)
                RoundedRectangle(cornerRadius: 2).fill(LrC.warn).frame(width: g.size.width * CGFloat(done))
            }
        }
        .frame(height: 4)
        .padding(.top, 10)
    }
}

/// The "Sinab ko‘ring" box: the next real measurement, with a green "aniq" tag when it came.
private struct LrReadingBox: View {
    let r: LaserReading?
    let seq: Int
    let reduced: Bool
    @State private var hit: Double = 0

    var body: some View {
        let s = AppSettings.shared
        let unitWord = tr(unitKey(s.unit))
        let value: String = r.map { Geo.fmtLen($0.mm, s.unit, s.lang == .en, full: true) + " " + unitWord } ?? "— " + unitWord
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 2) {
            tag
            ZStack {
                T(value, mono(38, 700, r == nil ? G.ink3 : G.ink, ls: -0.02), lines: 1)
                T(value, mono(38, 700, G.green, ls: -0.02), lines: 1).opacity(hit)
            }
            .minimumScaleFactor(0.5)
            .scaleEffect(1 + 0.12 * hit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(value))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(shape.fill(LrC.screen))
        .overlay(shape.strokeBorder(LrC.hair, lineWidth: 1))
        .padding(.top, 12)
        .onChange(of: seq) { _, _ in flash() }
    }

    @ViewBuilder private var tag: some View {
        if r == nil {
            T(tr("lr.last"), ui(12, 700, G.ink3))
        } else {
            HStack(spacing: 6) {
                T(tr("lr.fromLaser"), ui(12, 700, G.ink3))
                T(tr("lr.exact"), ui(11, 800, G.green))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(LrC.okSoft))
            }
        }
    }

    private func flash() {
        if reduced { return }
        hit = 1
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)
            withAnimation(.easeOut(duration: 0.6)) { hit = 0 }
        }
    }
}

/// The "nothing found" tip: a simple drawing of the laser with its Bluetooth button lit.
private struct LrTipArt: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let cobalt = G.cobalt
        let soft = LrC.cobaltSoft
        let screen = LrC.screen
        HStack(spacing: 12) {
            Canvas { ctx, sz in LrDraw.tip(ctx, sz.width / 86, cobalt, soft, screen) }
                .frame(width: 86, height: 48)
                .accessibilityHidden(true)
            Text(tipText).st(ui(12, 400, G.ink2)).lineSpacing(ui(12, 400, lh: 1.4).extraLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(shape.fill(LrC.screen))
        .overlay(shape.strokeBorder(LrC.hair, lineWidth: 1))
        .padding(.top, 10)
    }

    /// "{bt}" in the words is the Bluetooth sign, in blue.
    private var tipText: AttributedString {
        let parts = tr("lr.noneTip").components(separatedBy: "{bt}")
        var out = AttributedString(parts.first ?? "")
        if parts.count > 1 {
            var rune = AttributedString("ᛒ")
            rune.foregroundColor = G.cobalt
            out += rune
            out += AttributedString(parts[1])
        }
        return out
    }
}

/// A Bluetooth device that is not a laser, in the "Boshqa Bluetooth qurilmalari" sheet.
private struct LrOtherRow: View {
    let d: LzFound
    let onTap: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 12) {
            MIcon("bt", G.ink2, 22, 2)
            VStack(alignment: .leading, spacing: 1) {
                T(d.name ?? "—", ui(15, 700), lines: 1)
                T(lzShortId(d.id) + " · \(d.rssi) dBm", mono(11.5, 500, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            T(tr("dv.connect"), ui(14, 700, G.cobalt))
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
        .background(shape.fill(G.glass(0.55)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.98, label: d.name ?? lzShortId(d.id), onTap)
    }
}
