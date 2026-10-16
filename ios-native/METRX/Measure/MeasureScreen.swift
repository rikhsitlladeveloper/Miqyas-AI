import SwiftUI
import Observation

/*
 * The Measure page (prototype measure.js "one press + quick area", glass look; Android ui/measure/MeasureScreen.kt):
 * a meter with the laser's state and the last reading, single or continuous measuring, five calculators fed by
 * readings, the readings themselves (send one to a room, delete it), manual entry, and the camera. Reached from Home's
 * "O‘lchash" and "Kalkulyator" cards.
 */

private let NAVY = Color(argb: 0xFF0E1C36)
private let MUTED = Color(argb: 0xFFB7C3D9)
private let AMBER_RING = Color(argb: 0xFFFFB547)
private let BRICK_ICON = "M3 6h8v5H3zM13 6h8v5h-8zM7 13h10v5H7z"

struct CalcVal: Equatable { let id: String; let mm: Int }

/// The calculator's state, kept while the app runs (prototype U.qc).
@Observable
final class MeasureCalc {
    static let shared = MeasureCalc()
    var tool = "area"
    /// Per tool, the readings put into its slots, nil where still empty.
    var vals: [String: [CalcVal?]] = ["area": [], "wall": [], "vol": [], "sum": [], "brick": []]
    var act: Int? = nil
    var brickOpening = false
    var cont = false
    private(set) var live = false
    var liveVal: Int? = nil
    var showList = false
    @ObservationIgnored private var timer: Timer? = nil

    var cur: [CalcVal?] { vals[tool] ?? [] }
    private var slots: [String] { let s = CALC_SLOTS[tool] ?? []; return tool == "brick" && !brickOpening ? Array(s.prefix(2)) : s }

    /// The slot the next reading goes into: the one picked, else the first empty one (prototype qcActive).
    func active() -> Int? {
        let v = cur
        if tool == "sum" { return v.count }
        let n = slots.count
        if let a = act, a < n { return a }
        for i in 0..<n where i >= v.count || v[i] == nil { return i }
        return nil
    }

    func fill(_ r: Reading) {
        guard let i = active() else { return }
        var v = cur
        while v.count <= i { v.append(nil) }
        v[i] = CalcVal(id: r.id, mm: r.mm); vals[tool] = v; act = nil
    }

    func clear() { vals[tool] = []; act = nil }
    func remove(_ i: Int) { var v = cur; if i < v.count { v.remove(at: i) }; vals[tool] = v }

    func toggleBrickOpening() {
        brickOpening.toggle()
        if !brickOpening { var v = cur; while v.count > 2 { v.removeLast() }; vals[tool] = v }
        act = nil
    }

    func setLive(_ v: Bool) { live = v; if v { startLive() } else { stopLive() } }

    // continuous mode: the simulated laser keeps reporting a value that moves a little
    private func startLive() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AppSettings.shared.laser != .connected { self.setLive(false); return }
            self.liveVal = min(max((self.liveVal ?? Int.random(in: 600..<8200)) + Int.random(in: -3...3), 300), 9000)
        }
    }
    private func stopLive() { timer?.invalidate(); timer = nil }
}

struct MeasureScreen: View {
    let app: AppModel
    let calcTitle: Bool
    @State private var c = MeasureCalc.shared

    var body: some View {
        let s = AppSettings.shared
        let en = s.lang == .en, u = s.unit, m = unitName()
        let on = s.laser == .connected
        let rs = Array(s.readings.reversed())
        let last = on && c.cont && c.liveVal != nil ? c.liveVal : rs.first?.mm
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                    T(tr(calcTitle ? "gl.calc" : "tab.measure"), ui(36, 800, G.ink, lh: 1.15, ls: -0.02), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                    LaserButton { app.sheet = .device }.frame(width: 52, height: 52)
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
                ScrollViewReader { sr in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Meter(c: c, on: on, last: last, u: u, en: en, m: m)
                            Tools(c: c).id("tools")
                            CalcCard(app: app, c: c, u: u, en: en, m: m)
                            if !rs.isEmpty && !c.cur.contains(where: { $0 != nil }) { T(tr("qc.pick"), ui(13, 400, G.ink2, lh: 1.4)) }
                            HStack {
                                T(tr("qc.readings"), ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading)
                                if !rs.isEmpty {
                                    T(tr(c.showList ? "qc.hide" : "qc.list"), ui(14, 500, G.cobalt)).padding(.horizontal, 6).padding(.vertical, 10)
                                        .pressable(0.96) { c.showList.toggle() }
                                        .accessibilityIdentifier("qc.list")
                                }
                            }
                            .frame(minHeight: 44).padding(.horizontal, 2)
                            if rs.isEmpty { T(tr("qc.none"), ui(13, 400, G.ink2, lh: 1.4)) }
                            else { Chips(c: c, rs: rs, u: u, en: en) }
                            if c.showList && !rs.isEmpty { ReadingList(app: app, rs: rs, u: u, en: en, m: m) }
                            if !s.shots.isEmpty { Shots(app: app, ss: s.shots, u: u, en: en, m: m) }
                        }
                        .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 110 + NAV_SPACE)
                    }
                    // "Kalkulyator" opens the page at its tools row (prototype glScroll 'calc')
                    .onAppear { if calcTitle { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { sr.scrollTo("tools", anchor: .top) } } }
                }
            }
            FloatingFooter {
                HStack(spacing: 8) {
                    MIcon("camera", G.cobalt, 20, 2).frame(width: 56, height: 54)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.cobalt.opacity(0.12)))
                        .pressable(0.96, label: tr("cm.btn")) { openCamera(app) }
                        .accessibilityIdentifier("qm.camera")
                    HStack(spacing: 8) { MIcon("kbd", G.cobalt, 18, 2); T(tr("ed2.manual"), ui(16, 700, G.cobalt), lines: 1) }
                        .padding(.horizontal, 14).frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.cobalt.opacity(0.12)))
                        .pressable(0.97) { app.sheet = .qmManual }
                        .accessibilityIdentifier("qm.manual")
                    if !on { GBtn(tr("qc.connect"), icon: "bt") { app.sheet = .device }.accessibilityIdentifier("qm.connect") }
                    else if c.cont {
                        GBtn(tr("qc.saveLive"), icon: "save", enabled: c.liveVal != nil) {
                            if let v = c.liveVal { c.fill(s.addReading(v, "sim")); app.say("qm.saved") }
                        }
                    } else {
                        GBtn(tr("qc.measure"), icon: "laser") { c.fill(s.addReading(Int.random(in: 600..<8200), "sim")) }.accessibilityIdentifier("qm.measure")
                    }
                }
            }
            .padding(.bottom, NAV_SPACE - 12)
        }
        .onChange(of: on) { _, v in if !v { c.setLive(false) } }
    }
}

/// The camera button: the live camera, or a photo to draw on.
func openCamera(_ app: AppModel) { app.sheet = .cameraPick }

private struct Meter: View {
    let c: MeasureCalc
    let on: Bool
    let last: Int?
    let u: LenUnit
    let en: Bool
    let m: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(on && c.live ? G.green : G.greyIcon).frame(width: 7, height: 7)
                T(tr(!on ? "dev.disc" : c.live ? "meas.live" : "meas.idle"), ui(12.5, 600, G.ink2))
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(last.map { Geo.fmtLen($0, u, en, full: true) } ?? "–,–––").st(num(54, 600)).lineLimit(1).accessibilityIdentifier("qm.last")
                Text(m).st(num(22, 500, G.ink2))
            }
            .frame(maxWidth: .infinity)
            if on {
                HStack(spacing: 2) {
                    ForEach([(false, "meas.single"), (true, "meas.cont")], id: \.1) { cont, k in
                        let sel = c.cont == cont
                        T(tr(k), ui(14, sel ? 600 : 500, sel ? G.ink : G.ink2)).frame(maxWidth: .infinity).frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(sel ? G.glass(0.9) : .clear))
                            .boxShadow(sel ? Color(argb: 0x24101828) : .clear, blur: 3, y: 1)
                            .pressable(0.98) { c.cont = cont; c.setLive(false) }
                            .accessibilityIdentifier(k)
                    }
                }
                .padding(3).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
                if c.cont {
                    HStack(spacing: 8) { MIcon("laser", c.live ? G.green : G.cobalt, 18, 2); T(tr(c.live ? "qc.stop" : "qc.start"), ui(15, 700, c.live ? G.green : G.cobalt)) }
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.live ? G.green.opacity(0.14) : G.cobalt.opacity(0.1)))
                        .pressable(0.98) { c.setLive(!c.live) }
                        .accessibilityIdentifier("qc.live")
                }
            } else {
                HStack(alignment: .top, spacing: 8) { MIcon("btoff", G.amberInk, 18, 2); T(tr("ms.discBody"), ui(13.5, 500, G.ink, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading) }
                    .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
            }
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 12)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }
}

private struct Tools: View {
    let c: MeasureCalc
    var body: some View {
        HStack(spacing: 5) {
            ForEach([("area", "room"), ("wall", "walls"), ("vol", "cube"), ("sum", "dim"), ("brick", "")], id: \.0) { k, ic in
                let on = c.tool == k
                let tint: Color = on ? .white : G.ink
                VStack(spacing: 3) {
                    if ic.isEmpty { PathIcon(BRICK_ICON, tint, 18, 2) } else { MIcon(ic, tint, 18, 2) }
                    T(tr("qc." + k), ui(11.5, 600, tint), lines: 1)
                }
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? G.cobalt : G.glass(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? .clear : G.rim, lineWidth: 1))
                .boxShadow(on ? Color(argb: 0x401C4BD1) : .clear, blur: 12, y: 4)
                .pressable(0.97) { c.tool = k; c.act = nil }
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("qc." + k)
            }
        }
    }
}

/// The dark calculator card: slots, the result and Clear (prototype qcCalc).
private struct CalcCard: View {
    let app: AppModel
    let c: MeasureCalc
    let u: LenUnit
    let en: Bool
    let m: String

    private func g(_ i: Int) -> Int? { i < c.cur.count ? c.cur[i]?.mm : nil }

    private func slot(_ i: Int, _ lab: String) -> some View {
        let x: CalcVal? = i < c.cur.count ? c.cur[i] : nil
        let act = c.active() == i
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(spacing: 1) {
            Text(x.map { Geo.fmtLen($0.mm, u, en, full: true) } ?? "?").st(num(20, 600, x != nil ? .white : MUTED))
            T(tr("qc." + lab), ui(11, 400, MUTED))
        }
        .padding(.vertical, 7).padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: 55)
        .background(shape.fill(x != nil ? Color.white.opacity(0.1) : .clear))
        .overlay { if x == nil { shape.strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.33, dash: [6, 5])) } }
        .overlay { if act { shape.inset(by: 1).strokeBorder(AMBER_RING, lineWidth: 2) } }
        .pressable(0.98) { c.act = i }
        .accessibilityIdentifier("qc.slot")
    }

    private func op(_ t: String) -> some View { Text(t).st(num(18, 600, MUTED)) }

    var body: some View {
        let v = c.cur
        VStack(alignment: .leading, spacing: 8) {
            switch c.tool {
            case "sum":
                FlowLayout(spacing: 6) {
                    ForEach(Array(v.enumerated()), id: \.offset) { i, x in
                        HStack(spacing: 6) {
                            if i > 0 { op("+") }
                            Text(Geo.fmtLen(x?.mm ?? 0, u, en, full: true)).st(num(20, 600, .white)).padding(.horizontal, 10).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                                .pressable(0.97) { c.remove(i) }
                        }
                    }
                    HStack(spacing: 6) {
                        if !v.isEmpty { op("+") }
                        Text("?").st(num(20, 600, MUTED)).padding(.horizontal, 14).padding(.vertical, 7)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AMBER_RING, lineWidth: 2))
                    }
                }
            case "wall", "brick":
                HStack(spacing: 6) { slot(0, "L"); op("×"); slot(1, "H") }
                if c.tool == "wall" { T(tr("qc.open"), ui(12, 400, MUTED)) }
                if c.tool == "wall" || c.brickOpening { HStack(spacing: 6) { slot(2, "ow"); op("×"); slot(3, "oh") } }
                if c.tool == "brick" {
                    HStack(spacing: 6) { MIcon(c.brickOpening ? "x" : "plus", MUTED, 14, 2.4); T(tr(c.brickOpening ? "qb.openDel" : "qb.openAdd"), ui(13, 500, MUTED)) }
                        .padding(.vertical, 6).padding(.horizontal, 4)
                        .pressable(0.97) { c.toggleBrickOpening() }
                }
            default:
                HStack(spacing: 6) {
                    ForEach(Array((CALC_SLOTS[c.tool] ?? []).enumerated()), id: \.offset) { i, lab in
                        if i > 0 { op("×") }
                        slot(i, lab)
                    }
                }
            }
            // the result
            let res = result()
            HStack(spacing: 8) {
                T(tr(["area": "qc.rArea", "wall": "qc.rWall", "vol": "qc.rVol", "sum": "qc.rSum", "brick": "qc.rBrick"][c.tool] ?? ""), ui(13, 400, MUTED))
                Group {
                    if let err = res.err {
                        HStack(spacing: 6) { MIcon("alert", Color(argb: 0xFFFFB4A8), 16, 2); T(err, ui(13, 600, Color(argb: 0xFFFFB4A8))) }
                    } else {
                        Text(res.txt ?? "—").st(num(30, 700, res.txt != nil ? .white : MUTED)).lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("qc.result")
                    }
                }
                .frame(maxWidth: .infinity)
                T(tr("qc.clear"), ui(13, 400, MUTED)).padding(.horizontal, 4).frame(minHeight: 44).pressable(0.96) { c.clear() }
                    .accessibilityIdentifier("qc.clear")
            }
            .padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
            if c.tool == "brick" {
                let b = AppSettings.shared.brick
                if let sub = res.sub { HStack { T(sub.0, ui(12.5, 400, MUTED)).frame(maxWidth: .infinity, alignment: .leading); T(sub.1, ui(12.5, 400, MUTED)) } }
                HStack {
                    T(tr("qb.spec", ["l": b.l, "w": b.w, "h": b.h, "j": b.j, "s": b.s]), ui(12.5, 400, MUTED)).frame(maxWidth: .infinity, alignment: .leading)
                    T(tr("qb.change"), ui(13, 700, .white)).padding(.horizontal, 6).padding(.vertical, 8).pressable(0.96) { app.sheet = .brickSet }
                        .accessibilityIdentifier("qb.change")
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NAVY))
    }

    private func result() -> (txt: String?, err: String?, sub: (String, String)?) {
        let m2 = tr("u.m2")
        let dec = { (s: String) in en ? s : s.replacingOccurrences(of: ".", with: ",") }
        switch c.tool {
        case "area":
            if let a = g(0), let b = g(1) { return (Geo.fmtArea(Int64(a) * Int64(b), en) + " " + m2, nil, nil) }
        case "wall":
            if let a = g(0), let b = g(1) {
                let op = g(2).flatMap { w in g(3).map { Int64(w) * Int64($0) } } ?? 0
                let net = Int64(a) * Int64(b) - op
                return net > 0 ? (Geo.fmtArea(net, en) + " " + m2, nil, nil) : (nil, tr("qc.opBig"), nil)
            }
        case "vol":
            if let a = g(0), let b = g(1), let h = g(2) { return (dec(String(format: "%.2f", Double(a) * Double(b) * Double(h) / 1e9)) + " " + tr("u.m") + "³", nil, nil) }
        case "sum":
            if !c.cur.isEmpty { return (Geo.fmtLen(c.cur.reduce(0) { $0 + ($1?.mm ?? 0) }, u, en) + " " + m, nil, nil) }
        case "brick":
            if let a = g(0), let b = g(1) {
                let op = c.brickOpening ? (g(2).flatMap { w in g(3).map { Int64(w) * Int64($0) } } ?? 0) : 0
                let net = Int64(a) * Int64(b) - op
                if net <= 0 { return (nil, tr("qc.opBig"), nil) }
                let (n, mo) = brickCount(Double(net), AppSettings.shared.brick)
                let ns = Money.str(Decimal(n), 0, en)
                return (ns + " " + tr("u.pcs"), nil, (tr("qb.mortar") + " " + dec(String(format: "%.2f", mo)) + " " + tr("u.m") + "³", Geo.fmtArea(net, en) + " " + m2))
            }
        default: break
        }
        return (nil, nil, nil)
    }
}

/// The latest readings as chips: a tap puts one into the calculator (prototype .qm-chips).
private struct Chips: View {
    let c: MeasureCalc
    let rs: [Reading]
    let u: LenUnit
    let en: Bool
    var body: some View {
        let used = Set(c.cur.compactMap { $0?.id })
        FlowLayout(spacing: 6) {
            ForEach(rs.prefix(12)) { x in
                let inUse = used.contains(x.id)
                Text(Geo.fmtLen(x.mm, u, en, full: true)).st(num(15, 600, inUse ? G.cobalt2 : G.ink))
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(inUse ? G.cobalt.opacity(0.14) : G.glass(0.55)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(inUse ? G.cobalt.opacity(0.4) : G.rim, lineWidth: 1))
                    .pressable(0.97) { c.fill(x) }
                    .accessibilityIdentifier("qm.chip")
            }
        }
    }
}

private struct ReadingList: View {
    let app: AppModel
    let rs: [Reading]
    let u: LenUnit
    let en: Bool
    let m: String
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rs.enumerated()), id: \.element.id) { i, x in
                if i > 0 { Hairline() }
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Geo.fmtLen(x.mm, u, en, full: true) + " " + m).st(num(20, 600))
                        T(tr("qm.reading", ["n": x.n]) + ", " + fmtTime(x.ts) + (x.used.map { ", → " + $0 } ?? ""), ui(12.5, 400, G.ink2))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if x.src == "manual" { T(tr("src.manual"), ui(12.5, 400, G.ink2)) }
                    MIcon("send", G.cobalt, 18, 2).frame(width: 44, height: 44).pressable(0.95, label: tr("qm.send")) { app.sheet = .sendReading(id: x.id) }
                        .accessibilityIdentifier("qm.send")
                    MIcon("trash", G.ink2, 18, 2).frame(width: 44, height: 44).pressable(0.95, label: tr("common.delete")) { AppSettings.shared.deleteReading(x.id); app.say("qm.del") }
                }
                .padding(.leading, 14).padding(.trailing, 4).frame(minHeight: 60)
            }
        }
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }
}

/// The pictures taken here (prototype camStrip): each with its first measured line, opens in the photo editor.
private struct Shots: View {
    let app: AppModel
    let ss: [Item]
    let u: LenUnit
    let en: Bool
    let m: String
    var body: some View {
        HStack {
            T(tr("cm.shots"), ui(15, 600))
            Spacer()
            Text("\(ss.count)").st(num(12, 600, G.ink2)).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(G.ink.opacity(0.06)))
        }
        .padding(.horizontal, 2).padding(.vertical, 4)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ss) { it in
                    let v = it.els.first { $0.t == "dim" && $0.v != nil }?.v
                    VStack(alignment: .leading, spacing: 2) {
                        MarkThumb(it: it, slice: true).frame(width: 112, height: 78).background(Color(argb: 0xFF0E1C36)).clipped()
                        if let v { Text(Geo.fmtLen(v, u, en) + " " + m).st(num(15, 600)).lineLimit(1).padding(.horizontal, 10).padding(.top, 6) }
                        else { T(tr("cm.noVal"), ui(12.5, 500, G.ink3, lh: 1.3), lines: 1).padding(.horizontal, 10).padding(.top, 6) }
                        T(dn(it.name), ui(12, 400, G.ink2), lines: 1).padding(.horizontal, 10)
                    }
                    .padding(.bottom, 8).frame(width: 112, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.7)))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .pressable(0.98) { app.push(.markup(pid: nil, iid: it.id)) }
                    .accessibilityIdentifier("qm.shot")
                }
            }
        }
        .padding(.bottom, 6)
    }
}

/* ---------------- sheets ---------------- */

struct QuickSheet: View {
    let app: AppModel
    let sheet: Sheet
    var body: some View {
        switch sheet {
        case .qmManual: ManualSheet(app: app)
        case .brickSet: BrickSheet(app: app)
        case .sendReading(let id): SendSheet(app: app, id: id)
        default: EmptyView()
        }
    }
    static func handles(_ s: Sheet) -> Bool { switch s { case .qmManual, .brickSet, .sendReading: return true; default: return false } }
}

private enum QF: Hashable { case v, b(Int) }

/// Typing a distance (prototype SHEETS.qmManual).
private struct ManualSheet: View {
    let app: AppModel
    @State private var v = ""
    @State private var tried = false
    @FocusState private var focus: QF?
    var body: some View {
        let r = Geo.lenErr(v, 100_000, AppSettings.shared.unit, AppSettings.shared.lang == .en)
        GlassSheet(tr("meas.manualTitle"), onClose: { app.sheet = nil }) {
            NumField(label: tr("qc.dist"), value: $v, suffix: unitName(), error: errText(r), showError: tried, focus: $focus, me: .v, id: "qm.value")
        } footer: {
            GBtn(tr("common.save")) {
                guard let mm = r.value else { tried = true; return }
                MeasureCalc.shared.fill(AppSettings.shared.addReading(Int(mm), "manual")); app.sheet = nil; app.say("qm.saved")
            }
            .accessibilityIdentifier("qm.save")
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .v } }
    }
}

/// Brick size, joint and spare (prototype SHEETS.qbSet).
private struct BrickSheet: View {
    let app: AppModel
    @State private var f: [String] = []
    @State private var tried = false
    @FocusState private var focus: QF?
    private let keys = ["l", "w", "h", "j", "s"]

    private func err(_ i: Int) -> String? {
        guard i < f.count, let rg = BRICK_LIMITS[keys[i]] else { return nil }
        let t = f[i].trimmingCharacters(in: .whitespaces)
        if let n = Int(t), rg.contains(n), t.allSatisfy(\.isNumber) { return nil }
        return tr("qb.errRange", ["a": rg.lowerBound, "b": rg.upperBound])
    }
    private func bind(_ i: Int) -> Binding<String> { Binding(get: { i < f.count ? f[i] : "" }, set: { if i < f.count { f[i] = $0 } }) }

    var body: some View {
        let mm = tr("qb.mm")
        GlassSheet(tr("qb.title"), onClose: { app.sheet = nil }) {
            T(tr("qb.size"), ui(15, 700))
            HStack(spacing: 8) {
                ForEach(Array(BRICK_PRESETS.enumerated()), id: \.offset) { _, b in
                    let on = f.count == 5 && f[0] == "\(b.0)" && f[1] == "\(b.1)" && f[2] == "\(b.2)"
                    Text("\(b.0)×\(b.1)×\(b.2)").st(num(14, 600, on ? .white : G.ink)).padding(.horizontal, 14).frame(minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? G.cobalt : G.glass(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? G.cobalt : G.rim, lineWidth: 1))
                        .pressable(0.97) { if f.count == 5 { f[0] = "\(b.0)"; f[1] = "\(b.1)"; f[2] = "\(b.2)" } }
                }
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(["qb.len", "qb.wid", "qb.hei"].enumerated()), id: \.offset) { i, k in
                    NumField(label: tr(k), value: bind(i), suffix: mm, error: err(i), showError: tried, focus: $focus, me: .b(i))
                }
            }
            HStack(alignment: .top, spacing: 8) {
                NumField(label: tr("qb.joint"), value: bind(3), suffix: mm, error: err(3), showError: tried, focus: $focus, me: .b(3))
                NumField(label: tr("qb.spare"), value: bind(4), suffix: "%", error: err(4), showError: tried, focus: $focus, me: .b(4))
            }
            HStack(alignment: .top, spacing: 8) { MIcon("info", G.ink2, 18, 2); T(tr("qb.note"), ui(13, 400, G.ink2, lh: 1.45)) }
        } footer: {
            GBtn(tr("common.save")) {
                if (0..<5).contains(where: { err($0) != nil }) { tried = true; return }
                let n = f.map { Int($0.trimmingCharacters(in: .whitespaces))! }
                AppSettings.shared.setBrickSpec(BrickSpec(l: n[0], w: n[1], h: n[2], j: n[3], s: n[4])); app.sheet = nil
            }
        }
        .onAppear { if f.isEmpty { let b = AppSettings.shared.brick; f = ["\(b.l)", "\(b.w)", "\(b.h)", "\(b.j)", "\(b.s)"] } }
    }
}

/// Sending a reading to a room's wall or height (prototype SHEETS.sendReading): it waits there for confirmation.
private struct SendSheet: View {
    let app: AppModel
    let id: String
    var body: some View {
        let s = AppSettings.shared
        if let x = s.readings.first(where: { $0.id == id }) {
            let rooms = Store.shared.projects.flatMap { p in p.rooms.map { (p, $0) } }
            GlassSheet(tr("qm.sendTitle"), onClose: { app.sheet = nil }) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(Geo.fmtLen(x.mm, s.unit, s.lang == .en, full: true)).st(num(34, 600)); T(" " + unitName(), ui(18, 500, G.ink2))
                }
                if rooms.isEmpty { T(tr("qm.noRooms"), ui(14, 400, G.ink2)) }
                ForEach(Array(rooms.enumerated()), id: \.offset) { _, pr in
                    let p = pr.0, r = pr.1
                    VStack(alignment: .leading, spacing: 6) {
                        T(dn(p.name) + ": " + dn(r.name), ui(15, 700))
                        FlowLayout(spacing: 8) {
                            ForEach(Geo.stepKeys(r, s.angleSnap), id: \.self) { k in
                                let label = k == "H" ? tr("ed.Hs") : tr("op.wall") + " " + k
                                T(label, ui(14, 600)).padding(.horizontal, 12).frame(minHeight: 40)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.6)))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                                    .pressable(0.97) { send(x, p, r, k, label) }
                                    .accessibilityIdentifier("send." + k)
                            }
                        }
                    }
                }
            }
        }
    }

    private func send(_ x: Reading, _ p: Project, _ r: Room, _ k: String, _ label: String) {
        Store.shared.update(p.id) { pp in
            if let i = pp.rooms.firstIndex(where: { $0.id == r.id }) { pp.rooms[i].dims[k] = Dim(v: pp.rooms[i].dim(k).v, src: pp.rooms[i].dim(k).src, pending: Pending(mm: x.mm, src: x.src, from: "quick")) }
        }
        AppSettings.shared.markReadingUsed(x.id, label)
        app.sheet = nil
        // to the room, with that measurement chosen (prototype doSend)
        app.tab = .projects
        app.stacks[.projects] = [.root, .project(id: p.id, tab: "rooms"), .editor(pid: p.id, rid: r.id, mode: "plan")]
        RoomOps.shared.focusKey = k; RoomOps.shared.focusRoom = r.id
        app.say("qm.sent", kind: .info)
    }
}
