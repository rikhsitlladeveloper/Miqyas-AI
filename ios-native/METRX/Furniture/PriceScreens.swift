import SwiftUI

/*
 * Furniture orders, Stage 1a part 7 (furniture plan sections 6.4–6.7 and 10; design canvas screens 14–17; Android
 * ui/furniture/PriceScreens.kt): the Narx tab (cost, how the customer price is worked out, profit, lead time), the parts
 * and sheet layout screen, and the way to the two documents. Everything here is the maker's only.
 */

private let DARK = Color(argb: 0xFF0E1C36)
private let STRIP = Color(argb: 0xFFB7C3D9)

private func money(_ p: Project, _ v: Decimal) -> String { Money.str(v, p.precision, AppSettings.shared.lang == .en) }
private func digits(_ s: String) -> Decimal { Decimal(string: s.replacingOccurrences(of: " ", with: "")) ?? 0 }

func qtyStr(_ q: Double, _ en: Bool) -> String {
    if q == q.rounded(.down) { return "\(Int(q))" }
    let s = String(format: "%.1f", q)
    return en ? s : s.replacingOccurrences(of: ".", with: ",")
}

/// "LDSP 16 · Oq · 9 list × 620 000", "Kesish · 18 list × 45 000", "O‘rnatish".
private func lineText(_ p: Project, _ l: CostLine) -> String {
    let s = AppSettings.shared
    let name: String
    switch l.group {
    case "mat": name = s.mats.first { $0.id == l.key }?.name ?? l.key
    case "hw": name = s.hws.first { $0.id == l.key }?.name ?? tr("hk." + l.key)
    default: name = tr(l.key)
    }
    if l.unit == "order" { return name }
    return name + " · " + qtyStr(l.qty, s.lang == .en) + " " + tr("fu." + l.unit) + " × " + (l.missing ? tr("mt.noPrice") : money(p, l.price))
}

/// The Narx tab of a furniture order.
struct FPriceTab: View {
    let app: AppModel
    let p: Project
    @State private var open = "mat"
    var body: some View {
        let s = AppSettings.shared, lang = s.lang, en = lang == .en
        let fs = p.furniture.filter { !$0.modules.isEmpty }
        if fs.isEmpty {
            VStack(spacing: 10) {
                MIcon("coin", G.cobalt, 26, 2).frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.12)))
                T(tr("fp.empty"), ui(15, 500, G.ink2, lh: 1.45), align: .center)
            }
            .padding(24).frame(maxWidth: .infinity)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            .padding(.horizontal, 16).padding(.top, 14)
        } else {
            let fp = p.fprice
            let pr = priceOf(fs, fp, s.workshop, s.mats, s.hws)
            let cost = pr.cost, cur = Money.cur(p.currency)
            let pct = fp.pct ?? s.workshop.margin
            VStack(alignment: .leading, spacing: 12) {
                // the cost, by group
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("fp.cost"), ui(12.5, 600, G.ink2))
                    T(money(p, cost.total) + " " + cur, num(26, 800)).accessibilityIdentifier("fp.costV")
                    T(fs.map { dn($0.name) }.joined(separator: " + ") + " · " + tr("fp.onlyYou"), ui(12.5, 400, G.ink2), lines: 2)
                    ForEach([("mat", "fw.g.mat"), ("hw", "fw.g.hw"), ("lab", "fw.g.lab")], id: \.0) { g, k in
                        let on = open == g
                        Hairline()
                        HStack {
                            T((on ? "▾ " : "▸ ") + tr(k), ui(15, 700)).frame(maxWidth: .infinity, alignment: .leading)
                            T(money(p, cost.sum(g)), num(15, 700))
                        }
                        .frame(minHeight: 44).pressable(0.99) { open = on ? "" : g }
                        .accessibilityIdentifier("fp.g." + g)
                        if on {
                            ForEach(Array(cost.lines.filter { $0.group == g }.enumerated()), id: \.offset) { _, l in
                                HStack(alignment: .top, spacing: 8) {
                                    T(lineText(p, l), ui(13, 400, l.missing ? G.amberInk : G.ink2, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                                    T(money(p, l.amount), num(13.5, 600))
                                }
                                .padding(.leading, 14)
                            }
                        }
                    }
                    if cost.missing > 0 {
                        HStack(spacing: 8) {
                            MIcon("alert", G.amberInk, 18, 2)
                            T(tr("kt.noPrice", ["n": cost.missing]), ui(13.5, 500, G.amberInk)).frame(maxWidth: .infinity, alignment: .leading)
                            T(tr("fp.setPrices"), ui(13.5, 700, G.amberInk))
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
                        .pressable(0.99) { app.push(.materials) }
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
                // how the customer price is worked out
                VStack(alignment: .leading, spacing: 10) {
                    T(tr("fp.how"), ui(15, 800))
                    Seg(items: [("margin", tr("fpm.margin")), ("run", tr("fpm.run")), ("fixed", tr("fpm.fixed"))], cur: fp.mode) { m in set { $0.mode = m } }
                    if fp.mode == "fixed" {
                        PriceRow(label: tr("fp.fixed"), value: fp.fixed.isEmpty ? "—" : money(p, digits(fp.fixed)) + " " + cur, id: "fp.fixed") { app.sheet = .fPriceField(pid: p.id, key: "fixed") }
                        T(tr("fp.howFixed"), ui(12.5, 400, G.ink2, lh: 1.4))
                    } else {
                        FStepper(label: tr("fp.margin"), v: pct, lo: 0, hi: 300, id: "fp.pct") { v in set { $0.pct = v } }
                        if fp.mode == "run" {
                            PriceRow(label: tr("fp.rRun"), value: money(p, digits(fp.rRun)) + " " + cur, id: "fp.rRun") { app.sheet = .fPriceField(pid: p.id, key: "rRun") }
                            PriceRow(label: tr("fp.rTall"), value: fp.rTall.isEmpty ? "—" : money(p, digits(fp.rTall)) + " " + cur, id: "fp.rTall") { app.sheet = .fPriceField(pid: p.id, key: "rTall") }
                        }
                        ForEach(Array(pr.lines.enumerated()), id: \.offset) { _, ln in
                            let f = fs.first { $0.id == ln.key }
                            let how: String = ln.key == "deliver" ? tr("fd.deliver") + ": " + tr("fp.plusPct", ["p": pct])
                                : f.map { f in fp.mode == "run" && f.kind == "kitchen"
                                    ? dn(f.name) + ": " + metres1(runMm(f), en) + " " + tr("kt.pm") + " × " + money(p, digits(fp.rRun))
                                    : dn(f.name) + ": " + tr("fp.plusPct", ["p": pct]) } ?? ln.key
                            HStack(alignment: .top, spacing: 8) {
                                T(how, ui(12.5, 400, G.ink2, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                                T(money(p, ln.amount), num(13, 600, G.ink2))
                            }
                        }
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
                // the customer price and the profit
                let neg = pr.profit < 0, pc = pr.profitPct10
                VStack(alignment: .leading, spacing: 4) {
                    T(tr("fp.price"), ui(12.5, 400, STRIP))
                    T(money(p, pr.price) + " " + cur, num(26, 800, .white), lines: 1).accessibilityIdentifier("fp.priceV")
                    HStack {
                        T(tr("fw.profit"), ui(13, 400, STRIP)).frame(maxWidth: .infinity, alignment: .leading)
                        T(money(p, pr.profit) + " · \(pc / 10)\(en ? "." : ",")\(abs(pc % 10)) %", num(15, 700, neg ? Color(argb: 0xFFFCA5A5) : Color(argb: 0xFF86EFAC)))
                    }
                    .padding(.top, 6)
                    if neg { T(tr("fp.loss"), ui(12.5, 600, Color(argb: 0xFFFCA5A5))) }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DARK))
                PriceRow(label: tr("fp.days"), value: tr("fd.days", ["d": fp.days, "i": fp.inst]), id: "fp.days") { app.sheet = .fPriceField(pid: p.id, key: "days") }
                GBtn(tr("fc.title"), kind: .secondary, icon: "board", height: 48, corner: 16, fontSize: 15) { app.push(.fCut(pid: p.id)) }.accessibilityIdentifier("fp.cut")
                HStack(spacing: 10) {
                    GBtn(tr("fw.btn"), kind: .secondary, icon: "doc", height: 52, corner: 16, fontSize: 15) { app.push(.fPack(pid: p.id)) }.accessibilityIdentifier("fp.pack")
                    GBtn(tr("fd.btn"), icon: "share", height: 52, corner: 16, fontSize: 15) { app.push(.report(pid: p.id, no: nil)) }.accessibilityIdentifier("fp.quote")
                }
                T(tr("fp.docsNote"), ui(12.5, 400, G.ink2, lh: 1.4))
            }
            .padding(.horizontal, 16).padding(.top, 12)
        }
    }

    private func set(_ f: (inout FPrice) -> Void) { Store.shared.update(p.id) { f(&$0.fprice) } }
}

private struct PriceRow: View {
    let label: String, value: String, id: String
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 6) {
            T(label, ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading)
            T(value, num(15, 700), lines: 1); MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 14).frame(minHeight: 50)
        .background(shape.fill(G.glass(0.6))).overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.99, action)
        .accessibilityIdentifier(id)
    }
}

/* ---------------- sheets ---------------- */

struct PriceSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool { if case .fPriceField = s { return true }; return false }
    var body: some View {
        if case .fPriceField(let pid, let key) = sheet { PriceFieldSheet(app: app, pid: pid, key: key) }
    }
}

private enum PF: Hashable { case a, b }

private struct PriceFieldSheet: View {
    let app: AppModel
    let pid: String, key: String
    @State private var a: String
    @State private var b: String
    @FocusState private var focus: PF?
    init(app: AppModel, pid: String, key: String) {
        self.app = app; self.pid = pid; self.key = key
        let fp = Store.shared.get(pid)?.fprice ?? FPrice()
        _a = State(initialValue: key == "fixed" ? fp.fixed : key == "rRun" ? fp.rRun : key == "rTall" ? fp.rTall : String(fp.days))
        _b = State(initialValue: String(fp.inst))
    }
    var body: some View {
        if let p = Store.shared.get(pid) {
            let isMoney = key != "days"
            let ai = a.replacingOccurrences(of: " ", with: "")
            let ok = isMoney ? (ai.isEmpty || ai.allSatisfy(\.isNumber)) : ((1...365).contains(Int(ai) ?? -1) && (0...60).contains(Int(b) ?? -1))
            let title = key == "fixed" ? tr("fp.fixed") : key == "rRun" ? tr("fp.rRun") : key == "rTall" ? tr("fp.rTall") : tr("fp.days")
            let save = {
                guard ok else { return }
                Store.shared.update(p.id) { pr in
                    switch key {
                    case "fixed": pr.fprice.fixed = ai
                    case "rRun": pr.fprice.rRun = ai
                    case "rTall": pr.fprice.rTall = ai
                    default: pr.fprice.days = Int(ai) ?? 18; pr.fprice.inst = Int(b) ?? 1
                    }
                }
                app.sheet = nil
            }
            GlassSheet(title, onClose: { app.sheet = nil }) {
                if isMoney {
                    GField(label: title, value: $a, placeholder: "0", focus: $focus, me: .a, submit: .done, onSubmit: save, labelRight: Money.cur(p.currency), number: true, id: "pf.value")
                } else {
                    GField(label: tr("fp.daysMake"), value: $a, placeholder: "18", error: tr("km.bad", ["a": 1, "b": 365]), showError: !ok && !a.isEmpty, focus: $focus, me: .a,
                           submit: .next, onSubmit: { focus = .b }, labelRight: tr("fp.wd"), number: true, id: "pf.value")
                    GField(label: tr("fp.daysInst"), value: $b, placeholder: "1", focus: $focus, me: .b, submit: .done, onSubmit: save, labelRight: tr("fp.wd"), number: true, id: "pf.inst")
                }
                T(tr(key == "rRun" ? "fp.rRunNote" : key == "rTall" ? "fp.rTallNote" : key == "fixed" ? "fp.howFixed" : "fp.daysNote"), ui(12.5, 400, G.ink2, lh: 1.4))
            } footer: {
                GBtn(tr("common.save"), enabled: ok) { save() }.accessibilityIdentifier("pf.save")
            }
            .onChange(of: a) { _, v in let t = String(v.filter(\.isNumber).prefix(isMoney ? 12 : 3)); if t != v { a = t } }
            .onChange(of: b) { _, v in let t = String(v.filter(\.isNumber).prefix(2)); if t != v { b = t } }
        }
    }
}

/* ---------------- parts and sheet layout ---------------- */

/// Banding on a part's edges, drawn: a thick edge is a thick line, a thin one a thin line (design canvas screen 15).
private struct BandGlyph: View {
    let r: CutRow
    var body: some View {
        Canvas { c, size in
            let pad: CGFloat = 3, w = size.width - 2 * pad, h = size.height - 2 * pad, b = r.p.bands
            c.fill(Path(CGRect(x: pad, y: pad, width: w, height: h)), with: .color(G.ink.opacity(0.08)))
            func edge(_ code: Int, _ a: CGPoint, _ e: CGPoint) {
                if code == 0 { c.line(G.ink3.opacity(0.35), a, e, 1, dash: [3, 3]) } else { c.line(G.ink, a, e, code == 2 ? 3 : 1.2) }
            }
            edge(b.l1, CGPoint(x: pad, y: pad), CGPoint(x: pad + w, y: pad)); edge(b.l2, CGPoint(x: pad, y: pad + h), CGPoint(x: pad + w, y: pad + h))
            edge(b.s1, CGPoint(x: pad, y: pad), CGPoint(x: pad, y: pad + h)); edge(b.s2, CGPoint(x: pad + w, y: pad), CGPoint(x: pad + w, y: pad + h))
        }
        .frame(width: 34, height: 20)
    }
}

struct CutScreen: View {
    let app: AppModel
    let pid: String
    @State private var tab = "l"
    @State private var mat = ""
    @State private var sheet = 0
    var body: some View {
        let s = AppSettings.shared
        if let p = Store.shared.get(pid) {
            let fs = p.furniture.filter { !$0.modules.isEmpty }
            let cost = costOf(fs, s.workshop, s.mats, s.hws)
            let lay = cost.layouts.first { $0.mat == mat } ?? cost.layouts.first
            let idx = cost.rows.enumerated().filter { $0.element.mat == lay?.mat }
            let number: [Int: Int] = Dictionary(uniqueKeysWithValues: idx.enumerated().map { ($0.element.offset, $0.offset + 1) })
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                    VStack(alignment: .leading, spacing: 0) {
                        T(tr("fc.title"), ui(19, 800), lines: 1)
                        T(tr("fc.sub", ["n": cost.rows.reduce(0) { $0 + $1.p.qty }, "s": cost.layouts.reduce(0) { $0 + $1.sheets.count }]), ui(12, 400, G.ink2), lines: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16).frame(height: 64)
                if let lay {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Seg(items: [("l", tr("fc.parts")), ("s", tr("fc.sheets"))], cur: tab) { tab = $0 }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(cost.layouts, id: \.mat) { l in
                                        FChip(label: (s.mats.first { $0.id == l.mat }?.name ?? l.mat) + " · \(l.sheets.count)", on: l.mat == lay.mat) { mat = l.mat; sheet = 0 }
                                            .accessibilityIdentifier("fc.mat." + l.mat)
                                    }
                                }
                            }
                            if tab == "l" { partsList(idx, number) } else { sheetView(lay, number, s.workshop, s.mats) }
                            GBtn(tr("fw.btn"), kind: .secondary, icon: "doc", height: 48, corner: 16, fontSize: 15) { app.push(.fPack(pid: p.id)) }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    }
                } else {
                    T(tr("fp.empty"), ui(15, 500, G.ink2, lh: 1.45)).padding(24)
                    Spacer()
                }
            }
        }
    }

    private func partsList(_ idx: [EnumeratedSequence<[CutRow]>.Element], _ number: [Int: Int]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                T("№", ui(11.5, 700, G.ink2)).frame(width: 24, alignment: .leading)
                T(tr("fw.c.part"), ui(11.5, 700, G.ink2)).frame(maxWidth: .infinity, alignment: .leading)
                T(tr("fw.c.size"), ui(11.5, 700, G.ink2))
                // narrow columns: the heading shrinks rather than being cut off with a large text size
                T(tr("fw.c.qty"), ui(11.5, 700, G.ink2), lines: 1).minimumScaleFactor(0.7).frame(width: 34, alignment: .leading)
                T(tr("fw.c.band"), ui(11.5, 700, G.ink2), lines: 1).minimumScaleFactor(0.7).frame(width: 52, alignment: .leading)
            }
            .padding(.bottom, 4)
            ForEach(idx, id: \.offset) { i, r in
                Hairline()
                HStack(spacing: 8) {
                    T("\(number[i] ?? 0)", num(13, 700, G.ink2)).frame(width: 24, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        T(tr(r.p.key) + (r.p.grain ? " ↕" : ""), ui(13.5, 600), lines: 1)
                        if r.cutL != r.p.L || r.cutW != r.p.W { T(tr("wk.cut", ["v": "\(r.cutL) × \(r.cutW)"]), ui(11.5, 400, G.ink2)) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    T("\(r.p.L) × \(r.p.W)", num(13.5, 700))
                    T("× \(r.p.qty)", num(13, 600, G.ink2), lines: 1).frame(width: 34, alignment: .leading)
                    BandGlyph(r: r).frame(width: 52, alignment: .leading)
                }
                .frame(minHeight: 40)
            }
            T(tr("fc.bandNote"), ui(12, 400, G.ink2, lh: 1.4)).padding(.top, 6)
        }
        .padding(12)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }

    @ViewBuilder private func sheetView(_ lay: MatLayout, _ number: [Int: Int], _ ws: Workshop, _ mats: [Mat]) -> some View {
        let n = lay.sheets.count, i = min(max(sheet, 0), max(0, n - 1))
        HStack(spacing: 8) {
            GlassIconButton("back", tr("rp2.prev"), tint: i > 0 ? G.ink : PC.offIcon) { if i > 0 { sheet = i - 1 } }.accessibilityIdentifier("fc.prev")
            T(tr("fc.sheetN", ["i": i + 1, "n": n, "l": lay.sheetL, "w": lay.sheetW]), ui(14, 700), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
            T(tr("fc.waste", ["v": Int(lay.waste * 100)]), ui(12.5, 600, G.ink2))
            GlassIconButton("chev", tr("rp2.next"), tint: i < n - 1 ? G.ink : PC.offIcon) { if i < n - 1 { sheet = i + 1 } }.accessibilityIdentifier("fc.next")
        }
        if i < n {
            let sp = lay.sheets[i]
            Canvas { c, size in
                let k = size.width / CGFloat(lay.sheetL), tr0 = CGFloat(ws.trim) * k
                for pl in sp.placed {
                    let r = CGRect(x: tr0 + CGFloat(pl.x) * k, y: tr0 + CGFloat(pl.y) * k, width: CGFloat(pl.w) * k, height: CGFloat(pl.h) * k)
                    c.fill(Path(r), with: .color(Color(argb: 0xFFDDE6F5))); c.stroke(Path(r), with: .color(Color(argb: 0xFF3E4A61)), lineWidth: 1)
                    let fsz = min(13, min(r.width, r.height) * 0.42)
                    if fsz >= 6 { c.text("\(number[pl.row] ?? 0)", CGPoint(x: r.midX, y: r.midY), .num, fsz, 700, Color(argb: 0xFF0E1C36)) }
                }
            }
            .aspectRatio(CGFloat(lay.sheetL) / CGFloat(lay.sheetW), contentMode: .fit)
            .background(Color(argb: 0xFFF3F6FA))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(G.ink, lineWidth: 1))
            .accessibilityIdentifier("fc.sheet")
        }
        T(tr("fw.sheetNote", ["l": lay.sheetL, "w": lay.sheetW, "k": ws.kerf, "t": ws.trim]), ui(12.5, 400, G.ink2, lh: 1.4))
        if !lay.unplaced.isEmpty {
            T(tr("fw.unplaced", ["m": mats.first { $0.id == lay.mat }?.name ?? lay.mat, "n": lay.unplaced.count]), ui(13, 600, G.err, lh: 1.4))
        }
    }
}

/* ---------------- the workshop pack ---------------- */

/// The workshop pack of a furniture order (furniture plan section 10): its pages, and sharing it. Never the customer's.
struct PackScreen: View {
    let app: AppModel
    let pid: String
    @State private var pages: [RPage] = []
    @State private var images: [UIImage] = []
    @State private var page = 0
    @State private var viewer: Int? = nil
    var body: some View {
        let s = AppSettings.shared
        if let p = Store.shared.get(pid) {
            let sn = snapshotOf(p)
            let pr = priceOf(sn.furniture, p.fprice, s.workshop, s.mats, s.hws)
            let key = fingerprint(sn) + "\(s.workshop)\(s.mats)\(s.hws)\(p.fprice)"
            GeometryReader { geo in
                let w = geo.size.width - 32
                ZStack {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                            VStack(alignment: .leading, spacing: 0) {
                                T(tr("fw.title"), ui(17, 700, G.ink, lh: 1.2), lines: 1)
                                T(dn(p.name), ui(12.5, 400, G.ink2, lh: 1.2), lines: 1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, 14).padding(.trailing, 12).frame(height: 64)
                        ScrollView {
                            VStack(spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        T(tr("fw.inside"), ui(12, 700, Color(argb: 0xFFFDE2C8)))
                                        T(tr("fw.costShort", ["v": money(p, pr.cost.total) + " " + Money.cur(p.currency)]), num(16, 700, .white), lines: 1)
                                    }
                                    Spacer()
                                    T(pages.isEmpty ? "…" : tr("rp2.pages", ["n": pages.count]), ui(12.5, 400, Color(argb: 0xFFFDE2C8)))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(argb: 0xFF7A2E0E)))
                                TabView(selection: $page) {
                                    ForEach(0..<max(1, images.count), id: \.self) { i in
                                        Group { if i < images.count { Image(uiImage: images[i]).resizable() } else { Color.white } }
                                            .frame(width: w, height: w * PAGE_H / PAGE_W)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .boxShadow(Color(argb: 0x24101828), blur: 14, y: 2)
                                            .onTapGesture { if !images.isEmpty { viewer = i } }
                                            .accessibilityIdentifier("pk.page")
                                            .tag(i)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .frame(height: w * PAGE_H / PAGE_W + 20)
                                T(tr("rp2.of", ["i": page + 1, "n": max(1, pages.count)]) + " · " + tr("rp2.tapZoom"), ui(12.5, 400, G.ink2), align: .center)
                            }
                            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 120)
                        }
                    }
                    VStack {
                        Spacer()
                        FloatingFooter {
                            GBtn(tr("rpt.share"), icon: "share") {
                                guard !pages.isEmpty else { return }
                                app.say("sh.making", kind: .info)
                                if let url = pdfFile(pages, pdfName(dn(p.name), tr("fw.file"))) { presentShare(url) } else { app.say("cm.shareErr", kind: .error) }
                            }
                            .accessibilityIdentifier("pk.share")
                        }
                    }
                    if let start = viewer { PageViewer(pages: pages, start: start) { viewer = nil }.zIndex(3) }
                }
                .task(id: key + "\(Int(w))") {
                    guard w > 0 else { return }
                    let built = workshopPages(sn, s.workshop, s.mats, s.hws, pr, p.fprice.mode)
                    pages = built
                    images = built.compactMap { pageImage($0, width: w) }
                    if page >= built.count { page = max(0, built.count - 1) }
                }
            }
        }
    }
}
