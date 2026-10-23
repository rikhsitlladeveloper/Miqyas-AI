import SwiftUI

/*
 * The trades' calculator on the estimate tab (Trades/Trades.swift; Android ui/projects/TradeScreens.kt): what it worked
 * out from the measured rooms, and the button that puts it into the estimate. Its lines replace the ones it made
 * before; lines typed by hand stay.
 */

/// Puts the calculator's lines into the project's estimate, in place of the ones it made before. Their names and units
/// are stored as keys ("@tr.glue", "@u.m2"), so they follow the app's and the report's language like typed rows' units.
func applyTrade(_ app: AppModel, _ p: Project) {
    let st = AppSettings.shared
    let r = tradeRows(p.industry, p.rooms, st.trade, { k, v in k.hasPrefix("tu.") ? "@u." + String(k.dropFirst(3)) : keyName(k, v) }, st.angleSnap, true)
    Store.shared.update(p.id) { pr in
        if pr.stage == "measure" { pr.stage = "estimate" }
        pr.estimate.materials = pr.estimate.materials.filter { !$0.id.hasPrefix("t-") } + r.mats.map { var x = $0; x.id = "t-" + uid(); return x }
        pr.estimate.labor = pr.estimate.labor.filter { !$0.id.hasPrefix("t-") } + r.labor.map { var x = $0; x.id = "t-" + uid(); return x }
    }
    app.say("trc.done", ["n": r.mats.count + r.labor.count])
}

/// The calculator's card at the top of a trade project's estimate: the trade, how much of what, add or update.
struct TradeCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let st = AppSettings.shared, en = st.lang == .en
        let r = tradeRows(p.industry, p.rooms, st.trade, { k, v in tr(k, v) }, st.angleSnap, en)
        func d(_ v: Double?) -> String {
            guard let v else { return "0" }
            let s = String(format: "%.1f", v)
            return en ? s : s.replacingOccurrences(of: ".", with: ",")
        }
        func n(_ k: String) -> Int { Int(r.facts[k] ?? 0) }
        let fact: String = {
            switch p.industry {
            case "tiler": return tr("trc.tiler", ["a": d(r.facts["area"]), "b": n("boxes")])
            case "elec": return tr("trc.elec", ["n": n("points"), "m": d(r.facts["cable"])])
            case "plumb": return tr("trc.plumb", ["n": n("points"), "m": d(r.facts["pipe"])])
            default: return tr("trc.win", ["n": n("count")])
            }
        }()
        let made = p.estimate.materials.contains { $0.id.hasPrefix("t-") } || p.estimate.labor.contains { $0.id.hasPrefix("t-") }
        return VStack(alignment: .leading, spacing: 8) {
            T(tr("trc.title", ["n": tr("ind.\(p.industry)")]), ui(16, 800))
            T(fact, num(14.5, 700))
            T(tr("trc.body." + p.industry), ui(12.5, 400, G.ink2, lh: 1.4))
            if !p.rooms.contains(where: { Geo.ready3D($0, st.angleSnap) }) { T(tr("trc.noRooms"), ui(13, 500, G.amberInk, lh: 1.4)) }
            HStack(spacing: 8) {
                // half the width each: two lines rather than cut off
                GBtn(tr(made ? "trc.update" : "trc.apply"), enabled: !r.mats.isEmpty || !r.labor.isEmpty, height: 44, corner: 14, fontSize: 14, lines: 2) { applyTrade(app, p) }
                    .accessibilityIdentifier("trc.apply")
                GBtn(tr("trc.setB"), kind: .secondary, icon: "sliders", height: 44, corner: 14, fontSize: 14, lines: 2) { app.sheet = .tradeCalc(pid: p.id) }
                    .accessibilityIdentifier("trc.set")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

struct TradeSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .tradeCalc: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .tradeCalc(let pid): TradeCalcSheet(app: app, pid: pid)
        default: EmptyView()
        }
    }
}

/// One number of the calculator's settings: a label, the value as typed, its unit; dec for a decimal mark (a rate, up to
/// 3 decimals; prices are whole), max for a count or size, pos more than 0 (what a box holds: it divides).
/// A unit as "kg/m²", "/m", "mm" in the app's script ("кг/м²").
func unitText(_ u: String) -> String {
    let words: [(String, String)] = [("mm", tr("u.mm")), ("m²", tr("u.m2")), ("kg", tr("u.kg")), ("m", tr("u.m"))]
    var out = ""
    var rest = Substring(u)
    while !rest.isEmpty {
        if let w = words.first(where: { rest.hasPrefix($0.0) }) {
            out += w.1
            rest = rest.dropFirst(w.0.count)
        } else {
            out.append(rest.removeFirst())
        }
    }
    return out
}

private struct TF {
    let key: String
    let unit: String
    var dec = false
    var max: Int? = nil
    var pos = false
    let get: (TradeSet) -> String
    let set: (inout TradeSet, String) -> Void
}

private func fieldsOf(_ trade: String) -> [TF] {
    switch trade {
    case "tiler": return [
        TF(key: "tileW", unit: "mm", max: 10_000, get: { "\($0.tileW)" }, set: { t, v in t.tileW = Int(v) ?? t.tileW }),
        TF(key: "tileH", unit: "mm", max: 10_000, get: { "\($0.tileH)" }, set: { t, v in t.tileH = Int(v) ?? t.tileH }),
        TF(key: "boxM2", unit: "m²", dec: true, pos: true, get: { $0.boxM2 }, set: { t, v in t.boxM2 = v }),
        TF(key: "waste", unit: "%", max: 100, get: { "\($0.waste)" }, set: { t, v in t.waste = Int(v) ?? t.waste }),
        TF(key: "wallH", unit: "mm", max: 20_000, get: { "\($0.wallH)" }, set: { t, v in t.wallH = Int(v) ?? 0 }),
        TF(key: "pTile", unit: "/m²", get: { $0.pTile }, set: { t, v in t.pTile = v }),
        TF(key: "glueKg", unit: "kg/m²", dec: true, get: { $0.glueKg }, set: { t, v in t.glueKg = v }),
        TF(key: "pGlue", unit: "/25 kg", get: { $0.pGlue }, set: { t, v in t.pGlue = v }),
        TF(key: "groutKg", unit: "kg/m²", dec: true, get: { $0.groutKg }, set: { t, v in t.groutKg = v }),
        TF(key: "pGrout", unit: "/kg", get: { $0.pGrout }, set: { t, v in t.pGrout = v }),
        TF(key: "lTile", unit: "/m²", get: { $0.lTile }, set: { t, v in t.lTile = v })]
    case "elec": return [
        TF(key: "lights", unit: "", max: 100, get: { "\($0.lights)" }, set: { t, v in t.lights = Int(v) ?? t.lights }),
        TF(key: "pSocket", unit: "", get: { $0.pSocket }, set: { t, v in t.pSocket = v }),
        TF(key: "pSwitch", unit: "", get: { $0.pSwitch }, set: { t, v in t.pSwitch = v }),
        TF(key: "pLight", unit: "", get: { $0.pLight }, set: { t, v in t.pLight = v }),
        TF(key: "pCable", unit: "/m", get: { $0.pCable }, set: { t, v in t.pCable = v }),
        TF(key: "pConduit", unit: "/m", get: { $0.pConduit }, set: { t, v in t.pConduit = v }),
        TF(key: "pBreaker", unit: "", get: { $0.pBreaker }, set: { t, v in t.pBreaker = v }),
        TF(key: "lPoint", unit: "", get: { $0.lPoint }, set: { t, v in t.lPoint = v })]
    case "plumb": return [
        TF(key: "pPipe", unit: "/m", get: { $0.pPipe }, set: { t, v in t.pPipe = v }),
        TF(key: "pSewer", unit: "/m", get: { $0.pSewer }, set: { t, v in t.pSewer = v }),
        TF(key: "pFitting", unit: "", get: { $0.pFitting }, set: { t, v in t.pFitting = v }),
        TF(key: "pTap", unit: "", get: { $0.pTap }, set: { t, v in t.pTap = v }),
        TF(key: "lPlumb", unit: "", get: { $0.lPlumb }, set: { t, v in t.lPlumb = v })]
    default: return [
        TF(key: "pWinM2", unit: "/m²", get: { $0.pWinM2 }, set: { t, v in t.pWinM2 = v }),
        TF(key: "pDoorM2", unit: "/m²", get: { $0.pDoorM2 }, set: { t, v in t.pDoorM2 = v }),
        TF(key: "pSillM", unit: "/m", get: { $0.pSillM }, set: { t, v in t.pSillM = v }),
        TF(key: "pRevealM", unit: "/m", get: { $0.pRevealM }, set: { t, v in t.pRevealM = v }),
        TF(key: "lWin", unit: "", get: { $0.lWin }, set: { t, v in t.lWin = v })]
    }
}

/// The calculator's options and prices for the project's trade; saving also puts the lines into the estimate.
private struct TradeCalcSheet: View {
    let app: AppModel
    let pid: String
    // the fields keep what is typed; the numbers are read when saving, so the cursor never jumps
    @State private var texts: [String: String]
    @State private var floorOn: Bool
    @State private var tried = false
    @FocusState private var focus: String?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        let start = AppSettings.shared.trade
        let fields = fieldsOf(Store.shared.get(pid)?.industry ?? "")
        _texts = State(initialValue: Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.get(start)) }))
        _floorOn = State(initialValue: start.floor)
    }
    var body: some View {
        if let p = Store.shared.get(pid) {
            let fields = fieldsOf(p.industry)
            GlassSheet(tr("trc.set"), onClose: { app.sheet = nil }) {
                if p.industry == "tiler" {
                    VStack(alignment: .leading, spacing: 6) {
                        T(tr("trc.surfaces"), ui(15, 700))
                        Seg(items: [("1", tr("trc.floorOn")), ("0", tr("trc.floorOff"))], cur: floorOn ? "1" : "0") { floorOn = $0 == "1" }
                    }
                }
                ForEach(Array(stride(from: 0, to: fields.count, by: 2)), id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        field(fields[i])
                        if i + 1 < fields.count { field(fields[i + 1]) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                    }
                }
                T(tr("trc.note"), ui(12.5, 400, G.ink2, lh: 1.4))
            } footer: {
                GBtn(tr("trc.saveApply")) { save(p, fields) }.accessibilityIdentifier("trc.save")
            }
        }
    }

    private func field(_ f: TF) -> some View {
        // at most 12 characters, so a number can never be absurd
        let text = Binding(get: { texts[f.key] ?? "" }, set: { v in
            let c = String(v.filter { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }.prefix(12))
            if c != texts[f.key] { texts[f.key] = c }
        })
        return GField(label: tr("trf.\(f.key)"), value: text, placeholder: "0", error: fieldErr(f, texts[f.key] ?? ""), showError: tried, focus: $focus, me: f.key,
                      labelRight: f.unit.isEmpty ? nil : unitText(f.unit), number: !f.dec, decimal: f.dec, id: "trf." + f.key)
    }

    /// What a typed setting is wrong with, in words; nil when fine or empty (an empty one keeps the old value).
    private func fieldErr(_ f: TF, _ v: String) -> String? {
        switch Money.parse(v, f.dec ? 3 : 0) {
        case .empty: return nil
        case .ok(let x):
            if f.pos && x == 0 { return tr("err.zero") }
            if let m = f.max, x > Decimal(m) { return tr("err.max", ["max": m]) }; return nil
        case .format: return tr("err.format")
        case .negative: return tr("err.negative")
        case .precision(let n): return n > 0 ? tr("err.precision", ["n": n]) : tr("err.whole")
        }
    }

    private func save(_ p: Project, _ fields: [TF]) {
        if fields.contains(where: { fieldErr($0, texts[$0.key] ?? "") != nil }) { tried = true; return }
        var t = AppSettings.shared.trade
        t.floor = floorOn
        // a field left empty keeps its old value
        for f in fields {
            let v = (texts[f.key] ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            if !v.isEmpty { f.set(&t, v) }
        }
        AppSettings.shared.setTradeSet(t)
        app.sheet = nil
        applyTrade(app, Store.shared.get(pid) ?? p)
    }
}
