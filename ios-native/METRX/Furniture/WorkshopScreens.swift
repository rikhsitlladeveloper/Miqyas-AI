import SwiftUI

/*
 * Stage 1a part 3 (furniture plan sections 6.2, 6.6, 6.7; design canvas screens 12 and 13; Android
 * ui/furniture/WorkshopScreens.kt): the workshop's construction and price rules, and its boards and hardware, in
 * Profile. A sample unit shows what the rules make.
 */

/// A workshop value: how it is typed and shown. mm = whole mm, mm10 = tenths of a mm, pct, money.
private enum WKind { case mm, mm10, pct, money }

private struct WField {
    let key: String, label: String, kind: WKind
    let get: (Workshop) -> String
    let set: (inout Workshop, String) -> Void
}

private func intF(_ key: String, _ kind: WKind, _ kp: WritableKeyPath<Workshop, Int>) -> WField {
    WField(key: key, label: "wk." + key, kind: kind, get: { String($0[keyPath: kp]) }, set: { w, v in w[keyPath: kp] = Int(v) ?? w[keyPath: kp] })
}
private func moneyF(_ key: String, _ kp: WritableKeyPath<Workshop, String>) -> WField {
    WField(key: key, label: "wk." + key, kind: .money, get: { $0[keyPath: kp] }, set: { w, v in w[keyPath: kp] = v })
}

private let FIELDS: [WField] = [
    intF("gap", .mm10, \.gap10), intF("edge", .mm10, \.edge10), intF("band", .mm10, \.band10), intF("legH", .mm, \.legH),
    intF("sheetL", .mm, \.sheetL), intF("sheetW", .mm, \.sheetW), intF("kerf", .mm, \.kerf), intF("trim", .mm, \.trim),
    // remnants: offcuts at least this big each way are kept (bazis ideas, 23 Oct 2026)
    WField(key: "remMin", label: "bz.remMin", kind: .mm, get: { String($0.remMin) }, set: { w, v in w.remMin = Int(v) ?? w.remMin }),
    intF("margin", .pct, \.margin), intF("prepay", .pct, \.prepay),
    moneyF("rCut", \.rCut), moneyF("rBand", \.rBand), moneyF("rAsm", \.rAsm), moneyF("rInstall", \.rInstall), moneyF("rDeliver", \.rDeliver)
]
private func field(_ k: String) -> WField { FIELDS.first { $0.key == k }! }

/// Tenths of a mm as "1,5", or a stored value as it is shown.
func tenths(_ v: Int, _ en: Bool) -> String { v % 10 == 0 ? "\(v / 10)" : "\(v / 10)\(en ? "." : ",")\(v % 10)" }

private func shown(_ f: WField, _ w: Workshop) -> String {
    let s = AppSettings.shared, en = s.lang == .en, raw = f.get(w)
    switch f.kind {
    case .mm10: return tenths(Int(raw) ?? 0, en) + U_MM
    case .mm: return raw + U_MM
    case .pct: return raw + " %"
    case .money: return Money.str(Decimal(string: raw) ?? 0, 0, en) + " " + Money.cur(s.currency)
    }
}

/// A board's colour from "#RRGGBB".
func matColor(_ hex: String) -> Color { Color(argb: 0xFF00_0000 | UInt32(rgbOf(hex))) }

/// A sub-page with a back button and a title (as Profile's More settings).
private struct WPage<Content: View>: View {
    let app: AppModel
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                T(title, ui(17, 700)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).frame(height: 64)
            ScrollView { VStack(alignment: .leading, spacing: 10) { content }.padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24) }
        }
    }
}

private struct WCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            T(title, ui(15, 800)).padding(.bottom, 4)
            content
        }
        .padding(.leading, 14).padding(.trailing, 10).padding(.top, 12).padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }
}

private struct ValRow: View {
    let label: String, value: String, id: String
    let action: () -> Void
    var body: some View {
        Hairline()
        HStack(spacing: 8) {
            T(label, ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading)
            T(value, num(14.5, 700), lines: 1)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.vertical, 6).frame(minHeight: 50)
        .pressable(0.99, action)
        .accessibilityIdentifier(id)
    }
}

/* ---------------- workshop settings ---------------- */

struct WorkshopScreen: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared, w = s.workshop, en = s.lang == .en
        func rows(_ keys: [String]) -> some View {
            ForEach(keys, id: \.self) { k in ValRow(label: tr(field(k).label), value: shown(field(k), w), id: "wk." + k) { app.sheet = .wsField(key: k) } }
        }
        return WPage(app: app, title: tr("wk.title")) {
            WCard(title: tr("wk.build")) {
                Hairline()
                HStack {
                    T(tr("wk.t"), ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading)
                    Seg(items: [("16", "16" + U_MM), ("18", "18" + U_MM)], cur: String(w.t)) { v in var n = w; n.t = Int(v) ?? 16; s.setWorkshopRules(n) }.frame(width: 150)
                }
                .padding(.vertical, 8)
                Hairline()
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("wk.back"), ui(14.5, 500))
                    Seg(items: [("nail", tr("wk.nail")), ("groove", tr("wk.groove"))], cur: w.back) { v in var n = w; n.back = v; s.setWorkshopRules(n) }
                }
                .padding(.vertical, 8)
                rows(["gap", "edge", "band", "legH"])
                Hairline()
                HStack(spacing: 8) { T(tr("wk.bandOff"), ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading); GSwitch(on: w.bandOff) }
                    .padding(.vertical, 6).frame(minHeight: 52)
                    .pressable(0.99) { var n = w; n.bandOff.toggle(); s.setWorkshopRules(n) }
                    .accessibilityValue(w.bandOff ? "1" : "0").accessibilityAddTraits(.isToggle)
                    .accessibilityIdentifier("wk.bandOff")
            }
            WCard(title: tr("wk.sheet")) { rows(["sheetL", "sheetW", "kerf", "trim"]) }
            // remnants: what the cut lists keep and use first (bazis ideas, 23 Oct 2026)
            WCard(title: tr("bz.rem")) {
                rows(["remMin"])
                ValRow(label: tr("bz.remList"), value: tr("bz.remN", ["n": s.remnants.filter { $0.used.isEmpty }.count]), id: "wk.remList") { app.push(.remnants) }
            }
            WCard(title: tr("wk.price")) { rows(["margin", "prepay", "rCut", "rBand", "rAsm", "rInstall", "rDeliver"]) }
            HStack(alignment: .top, spacing: 8) { MIcon("info", G.ink2, 16, 2); T(tr("wk.note"), ui(13, 400, G.ink2, lh: 1.4)) }
            SampleCard(w: w, en: en)
        }
    }
}

/// The sample unit with today's rules: its parts with finished and cut sizes, and what it costs.
private struct SampleCard: View {
    let w: Workshop
    let en: Bool
    var body: some View {
        let s = AppSettings.shared
        let m = Module(id: "s", type: "base", w: 600, h: 720, d: 560, fronts: Fronts("door", 2), inserts: [Insert("shelf", qty: 1)], label: "600")
        let f = Furniture(id: "s", kind: "kitchen", modules: [m])
        let rows = cutList([f], w)
        let cost = costOf([f], w, s.mats, s.hws, order: false)
        VStack(alignment: .leading, spacing: 6) {
            T(tr("wk.sample"), ui(15, 800))
            T(tr("wk.sampleS"), ui(12.5, 400, G.ink2))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                Hairline()
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        T(tr(r.p.key), ui(13.5, 700), lines: 1)
                        T(s.mats.first { $0.id == r.mat }?.name ?? r.mat, ui(11.5, 400, G.ink2), lines: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 1) {
                        T("\(r.p.L) × \(r.p.W) × \(r.p.qty)", num(13.5, 700))
                        if r.cutL != r.p.L || r.cutW != r.p.W { T(tr("wk.cut", ["v": "\(r.cutL) × \(r.cutW)"]), ui(11.5, 400, G.ink2)) }
                    }
                }
                .padding(.vertical, 2)
            }
            Hairline()
            HStack {
                T(tr("wk.cost"), ui(14, 600)).frame(maxWidth: .infinity, alignment: .leading)
                T(Money.str(cost.total, 0, en) + " " + Money.cur(s.currency), num(16, 800)).accessibilityIdentifier("wk.costV")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }
}

/* ---------------- materials and hardware ---------------- */

struct MaterialsScreen: View {
    let app: AppModel
    @State private var tab = "m"
    var body: some View {
        let s = AppSettings.shared, en = s.lang == .en
        WPage(app: app, title: tr("wk.mats")) {
            Seg(items: [("m", tr("mt.mats") + " · \(s.mats.count)"), ("h", tr("mt.hws") + " · \(s.hws.count)")], cur: tab) { tab = $0 }
            T(tr("mt.lead"), ui(12.5, 400, G.ink2, lh: 1.45))
            if tab == "m" {
                ForEach(s.mats) { m in
                    ItemRow(swatch: matColor(m.rgb), name: m.name, sub: matSub(m, en), price: priceOf(m.price, en), unit: unitOf(m)) { app.sheet = .matForm(id: m.id) }
                        .accessibilityIdentifier("mt." + m.id)
                }
            } else {
                ForEach(s.hws) { h in
                    ItemRow(swatch: nil, name: h.name, sub: tr("hk." + h.kind), price: priceOf(h.price, en), unit: tr(perKey(h.kind))) { app.sheet = .hwForm(id: h.id) }
                        .accessibilityIdentifier("hw." + h.id)
                }
            }
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            HStack(spacing: 8) { MIcon("plus", G.cobalt2, 18, 2.4); T(tr(tab == "m" ? "mt.addMat" : "mt.addHw"), ui(15, 700, G.cobalt2)) }
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay(shape.strokeBorder(G.cobalt.opacity(0.45), lineWidth: 2))
                .contentShape(shape)
                .pressable(0.98) { app.sheet = tab == "m" ? .matForm(id: nil) : .hwForm(id: nil) }
                .accessibilityIdentifier("mt.add")
        }
    }
}

private func matSub(_ m: Mat, _ en: Bool) -> String {
    switch m.kind {
    case "band": return tr("mt.bandK") + " · " + tenths(m.t, en) + U_MM
    case "back": return tr("mt.backK") + " · \(m.l) × \(m.w)"
    case "worktop": return tr("mt.wtK") + " · \(m.t) mm · \(m.l) × \(m.w)"
    default: return tr("mt.board") + " · \(m.t) mm · \(m.l) × \(m.w)" + (m.grain ? " · ↕" : "")
    }
}

private func unitOf(_ m: Mat) -> String { tr(m.kind == "band" || m.kind == "worktop" || m.kind == "splash" ? "mt.perM" : "mt.perSheet") }

/// A hardware kind's price unit: by the metre (slide tracks, profiles, cornice, LED, plinth, bar rail), by the m² (mirror,
/// glass, glass shelf, glass door), else a piece (Hardware.swift hwUnit).
private func perKey(_ kind: String) -> String {
    switch hwUnit(kind) {
    case "m": return "mt.perM"
    case "m2": return "mt.perM2"
    default: return "mt.perPc"
    }
}

private func priceOf(_ p: String, _ en: Bool) -> String {
    p.range(of: "^\\d+$", options: .regularExpression) != nil ? Money.str(Decimal(string: p) ?? 0, 0, en) : tr("mt.noPrice")
}

private struct ItemRow: View {
    let swatch: Color?
    let name: String, sub: String, price: String, unit: String
    let action: () -> Void
    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 8, style: .continuous)
        HStack(spacing: 10) {
            if let swatch { tile.fill(swatch).overlay(tile.strokeBorder(G.ink.opacity(0.18), lineWidth: 1)).frame(width: 28, height: 28) }
            else { MIcon("sliders", G.ink2, 16, 2).frame(width: 28, height: 28).background(tile.fill(G.ink.opacity(0.07))) }
            VStack(alignment: .leading, spacing: 1) {
                T(name, ui(14, 700), lines: 1)
                T(sub, ui(11.5, 400, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 1) { T(price, num(14, 800)); T(unit, ui(11, 400, G.ink2)) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .glassCard(RoundedRectangle(cornerRadius: 16, style: .continuous), fill: G.glass(0.55))
        .pressable(0.99, action)
    }
}

/* ---------------- sheets ---------------- */

struct WorkshopSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .wsField, .matForm, .hwForm: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .wsField(let k): FieldSheet(app: app, key: k)
        case .matForm(let id): MatSheet(app: app, id: id)
        case .hwForm(let id): HwSheet(app: app, id: id)
        default: EmptyView()
        }
    }
}

/// A typed workshop value: digits, and for tenths of a mm one decimal; nil when it is not a sensible number.
/// Sizes that keep the sheet layout working: a board of 300 to 5000 mm, a saw cut under 10 mm, a trim under 100 mm.
private func mmRange(_ key: String) -> ClosedRange<Int> {
    switch key {
    case "sheetL", "sheetW": return 300...5000
    case "kerf": return 0...10
    case "trim": return 0...100
    case "remMin": return 100...2000
    case "legH": return 0...300
    default: return 0...10000
    }
}

private func parseField(_ kind: WKind, _ text: String, _ key: String = "") -> String? {
    let t = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
    switch kind {
    case .mm10: return Double(t).flatMap { $0 >= 0 && $0 <= 50 ? String(Int(($0 * 10).rounded())) : nil }
    case .mm: return Int(t).flatMap { mmRange(key).contains($0) ? String($0) : nil }
    // a prepayment is part of the price; the markup may be more than the cost
    case .pct: return Int(t).flatMap { (key == "prepay" ? 0...100 : 0...500).contains($0) ? String($0) : nil }
    case .money: return !t.isEmpty && t.allSatisfy(\.isASCIIDigitChar) ? Money.digits(Decimal(string: t) ?? 0) : nil
    }
}

private extension Character { var isASCIIDigitChar: Bool { ("0"..."9").contains(self) } }

private enum WF: Hashable { case a, b, c, d, e }

private struct FieldSheet: View {
    let app: AppModel
    let key: String
    @State private var v: String
    @FocusState private var focus: WF?
    init(app: AppModel, key: String) {
        self.app = app; self.key = key
        let f = field(key), raw = f.get(AppSettings.shared.workshop)
        _v = State(initialValue: f.kind == .mm10 ? tenths(Int(raw) ?? 0, AppSettings.shared.lang == .en) : raw)
    }
    var body: some View {
        let s = AppSettings.shared, f = field(key), parsed = parseField(f.kind, v, f.key)
        let unit: String = { switch f.kind { case .mm, .mm10: return "mm"; case .pct: return "%"; case .money: return Money.cur(s.currency) } }()
        func save() {
            guard let parsed else { return }
            var w = s.workshop; f.set(&w, parsed); s.setWorkshopRules(w)
            app.sheet = nil; app.say("wk.saved")
        }
        return GlassSheet(tr(f.label), onClose: { app.sheet = nil }) {
            GField(label: tr(f.label), value: $v, placeholder: "0", error: tr("wk.bad"), showError: parsed == nil && !v.isEmpty, focus: $focus, me: .a,
                   submit: .done, onSubmit: save, labelRight: unit, number: f.kind != .mm10, decimal: f.kind == .mm10, id: "wk.value")
        } footer: {
            GBtn(tr("common.save"), enabled: parsed != nil) { save() }.accessibilityIdentifier("wk.save")
        }
        .onAppear { focus = .a }
    }
}

private let SWATCHES = ["#F5F5F2", "#FFFFFF", "#CDBFAE", "#E8E4DC", "#B08D6E", "#7A5A40", "#4B4F58", "#1E293B"]

private struct MatSheet: View {
    let app: AppModel
    let id: String?
    @State private var name: String
    @State private var kind: String
    @State private var t: String
    @State private var l: String
    @State private var w: String
    @State private var price: String
    @State private var grain: Bool
    @State private var rgb: String
    @FocusState private var focus: WF?
    init(app: AppModel, id: String?) {
        self.app = app; self.id = id
        let e = id.flatMap { x in AppSettings.shared.mats.first { $0.id == x } }
        _name = State(initialValue: e?.name ?? ""); _kind = State(initialValue: e?.kind ?? "board"); _t = State(initialValue: String(e?.t ?? 16))
        _l = State(initialValue: String(e?.l ?? 2800)); _w = State(initialValue: String(e?.w ?? 2070)); _price = State(initialValue: e?.price ?? "")
        _grain = State(initialValue: e?.grain ?? false); _rgb = State(initialValue: e?.rgb ?? "#F5F5F2")
    }
    var body: some View {
        let s = AppSettings.shared
        let edit = id.flatMap { x in s.mats.first { $0.id == x } }
        let band = kind == "band"
        let ti = Int(t), li = Int(l), wi = Int(w)
        let ok = !name.trimmingCharacters(in: .whitespaces).isEmpty && (ti ?? 0) > 0 &&
            (band || ((300...6000).contains(li ?? 0) && (300...3000).contains(wi ?? 0))) && (price.isEmpty || price.allSatisfy(\.isASCIIDigitChar))
        func save() {
            guard ok, let ti else { return }
            let m = Mat(edit?.id ?? uid(), kind, name.trimmingCharacters(in: .whitespaces), ti, l: band ? 0 : li!, w: band ? 0 : wi!, price: price,
                        grain: grain && kind == "board", rgb: rgb, preset: edit?.preset ?? false)
            s.setMatList(edit != nil ? s.mats.map { $0.id == m.id ? m : $0 } : s.mats + [m])
            app.sheet = nil; app.say("wk.saved")
        }
        return GlassSheet(edit?.name ?? tr("mt.addMat"), onClose: { app.sheet = nil }) {
            GField(label: tr("mt.name"), value: $name, placeholder: "LDSP 16 · …", focus: $focus, me: .a, id: "mt.name")
            if edit == nil {
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("mt.kind"), ui(15, 700))
                    Seg(items: [("board", tr("mt.board")), ("back", tr("mt.backK"))], cur: kind) { kind = $0 }
                }
            }
            HStack(alignment: .top, spacing: 10) {
                GField(label: tr("mt.t"), value: $t, placeholder: "16", focus: $focus, me: .b, labelRight: band ? "0,1" + U_MM : tr("u.mm"), number: true)
                GField(label: tr("mt.price"), value: $price, placeholder: "0", focus: $focus, me: .c,
                       labelRight: tr(band || kind == "worktop" || kind == "splash" ? "mt.perM" : "mt.perSheet"), number: true, id: "mt.price")
            }
            if !band {
                HStack(alignment: .top, spacing: 10) {
                    GField(label: tr("mt.l"), value: $l, placeholder: "2800", focus: $focus, me: .d, labelRight: tr("u.mm"), number: true)
                    GField(label: tr("mt.w"), value: $w, placeholder: "2070", focus: $focus, me: .e, labelRight: tr("u.mm"), number: true)
                }
            }
            if kind == "board" {
                HStack { T(tr("mt.grain"), ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading); GSwitch(on: grain) }
                    .frame(minHeight: 52).pressable(0.99) { grain.toggle() }
                    .accessibilityValue(grain ? "1" : "0").accessibilityAddTraits(.isToggle).accessibilityIdentifier("mt.grain")
            }
            if !band {
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("mt.color"), ui(15, 700))
                    HStack(spacing: 8) {
                        ForEach(SWATCHES, id: \.self) { c in
                            Circle().fill(matColor(c))
                                .overlay(Circle().strokeBorder(c == rgb ? G.cobalt : G.ink.opacity(0.2), lineWidth: c == rgb ? 3 : 1))
                                .frame(width: 32, height: 32)
                                .pressable(0.95, label: c) { rgb = c }
                                .accessibilityAddTraits(c == rgb ? .isSelected : [])
                        }
                    }
                }
            }
            if edit?.preset == true { T(tr("mt.presetNote"), ui(12.5, 400, G.ink2, lh: 1.4)) }
        } footer: {
            HStack(spacing: 8) {
                if let edit, !edit.preset {
                    GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 44, corner: 16, fontSize: 15) {
                        s.setMatList(s.mats.filter { $0.id != edit.id }); app.sheet = nil
                    }
                }
                GBtn(tr("common.save"), enabled: ok, height: 44, corner: 16, fontSize: 15) { save() }.accessibilityIdentifier("mt.save")
            }
        }
        .onChange(of: t) { _, v in let f = v.filter(\.isASCIIDigitChar); if f != v { t = f } }
        .onChange(of: l) { _, v in let f = v.filter(\.isASCIIDigitChar); if f != v { l = f } }
        .onChange(of: w) { _, v in let f = v.filter(\.isASCIIDigitChar); if f != v { w = f } }
        .onChange(of: price) { _, v in let f = v.filter(\.isASCIIDigitChar); if f != v { price = f } }
    }
}

private let HW_KINDS = ["hingeSoft", "hinge", "runner", "handle", "leg", "pin", "rail", "railEnd", "confirmat", "hanger", "lift"]

private struct HwSheet: View {
    let app: AppModel
    let id: String?
    @State private var name: String
    @State private var kind: String
    @State private var price: String
    @FocusState private var focus: WF?
    init(app: AppModel, id: String?) {
        self.app = app; self.id = id
        let e = id.flatMap { x in AppSettings.shared.hws.first { $0.id == x } }
        _name = State(initialValue: e?.name ?? ""); _kind = State(initialValue: e?.kind ?? "handle"); _price = State(initialValue: e?.price ?? "")
    }
    var body: some View {
        let s = AppSettings.shared
        let edit = id.flatMap { x in s.hws.first { $0.id == x } }
        let ok = !name.trimmingCharacters(in: .whitespaces).isEmpty
        func save() {
            guard ok else { return }
            let h = Hw(edit?.id ?? uid(), kind, name.trimmingCharacters(in: .whitespaces), price, edit?.preset ?? false)
            // the cost counts the last item of each kind: a new one of a kind takes over from the preset
            s.setHwList(edit != nil ? s.hws.map { $0.id == h.id ? h : $0 } : s.hws + [h])
            app.sheet = nil; app.say("wk.saved")
        }
        return GlassSheet(edit?.name ?? tr("mt.addHw"), onClose: { app.sheet = nil }) {
            GField(label: tr("mt.name"), value: $name, placeholder: "GTV, Blum, Boyard…", focus: $focus, me: .a, id: "mt.name")
            GField(label: tr("mt.price"), value: $price, placeholder: "0", focus: $focus, me: .b, submit: .done,
                   labelRight: tr(perKey(kind)), number: true, id: "mt.price")
            if edit == nil {
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("mt.hwKind"), ui(15, 700))
                    let pairs = stride(from: 0, to: HW_KINDS.count, by: 2).map { Array(HW_KINDS[$0..<min($0 + 2, HW_KINDS.count)]) }
                    ForEach(pairs, id: \.self) { pair in
                        HStack(spacing: 8) {
                            ForEach(pair, id: \.self) { k in
                                let on = k == kind, shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                                T(tr("hk." + k), ui(13, on ? 700 : 500, on ? G.cobalt2 : G.ink), lines: 1)
                                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.6)))
                                    .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: 1))
                                    .pressable(0.98) { kind = k }
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                    .accessibilityIdentifier("hk." + k)
                            }
                            if pair.count == 1 { Spacer().frame(maxWidth: .infinity) }
                        }
                    }
                }
            }
            if edit?.preset == true { T(tr("mt.presetNote"), ui(12.5, 400, G.ink2, lh: 1.4)) }
        } footer: {
            HStack(spacing: 8) {
                if let edit, !edit.preset {
                    GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 44, corner: 16, fontSize: 15) {
                        s.setHwList(s.hws.filter { $0.id != edit.id }); app.sheet = nil
                    }
                }
                GBtn(tr("common.save"), enabled: ok, height: 44, corner: 16, fontSize: 15) { save() }.accessibilityIdentifier("mt.save")
            }
        }
        .onChange(of: price) { _, v in let f = v.filter(\.isASCIIDigitChar); if f != v { price = f } }
    }
}
