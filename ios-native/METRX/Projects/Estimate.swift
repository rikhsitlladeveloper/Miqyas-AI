import SwiftUI
import UIKit

/*
 * The Smeta tab (prototype glass.js stages 4–6; Android ui/projects/Estimate.kt): area tiles, the materials and labour
 * cards, an empty state with quick adds, the floating total, and the row sheet with suggestions, units, "take from the
 * rooms", +10 % spare and drafts.
 */

private let P_RCPT = "M6 3h12v18l-3-2-3 2-3-2-3 2z M9 8h6 M9 12h6 M9 16h3"
private let P_PLAN = "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z M3 12h9V3 M12 12v9"
private let P_FLOOR = "M3 9l9-5 9 5-9 5z M3 15l9 5 9-5"
private var AMBER: Color { Theme.shared.dark ? G.amberInk : Color(argb: 0xFF9A5800) }
private var COB_DARK: Color { Theme.shared.dark ? G.cobalt2 : Color(argb: 0xFF1E36B0) }

/// Material suggestions' units (prototype GS_MAT_UNITS) and the unit chips (GS_UNITS).
private let SUG_UNITS = ["@u.m2", "@u.l", "@u.bag", "@u.l", "@u.m2", "@u.m2"]
private let UNITS = ["u.pcs", "u.m2", "u.m", "u.kg", "u.l", "u.bag", "u.can", "u.set"]

/// The project's net wall and floor areas in mm², from the rooms that have them (prototype gsAreas).
struct PjAreas { var w: Int64 = 0, f: Int64 = 0, nw = 0, nf = 0 }

func pjAreas(_ p: Project, _ snap: Bool) -> PjAreas {
    var a = PjAreas()
    for r in p.rooms {
        guard let x = Geo.areas(r, snap) else { continue }
        a.f += x.floor; a.nf += 1
        if let n = x.net { a.w += n; a.nw += 1 }
    }
    return a
}

/// The shared glass surface of the Smeta cards.
private extension View {
    func gsCard(_ r: CGFloat, shadow: CGFloat = 28, a: Double = 0.12, dy: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        return background(shape.fill(G.glass(0.45)))
            .topHighlight(shape, 0.95)
            .overlay(shape.strokeBorder(G.rim, lineWidth: 0.67))
            .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(a), blur: shadow, y: dy))
    }
}

struct EstimateTab: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let en = AppSettings.shared.lang == .en
        let mats = p.estimate.materials, labs = p.estimate.labor
        let tt = Money.totals(p)
        VStack(alignment: .leading, spacing: 12) {
            Stats(app: app, p: p)
            // after a quote: is the draft still the same as the last one issued? (prototype es.same / es.changed)
            if let q = p.quotes.last {
                let same = sameAsQuote(snapshotOf(p), q.fp)
                QuoteBanner(same: same, text: tr(same ? "es.same" : "es.changed", ["n": q.no]))
            }
            if p.isTiler { TilesCard(app: app, p: p) } else if p.isElec { ElecCard(app: app, p: p) } else if p.isPlumb { PlumbCard(app: app, p: p) } else if p.isWin { WinCard(app: app, p: p) } else if isTrade(p.industry) { TradeCard(app: app, p: p) }
            if mats.isEmpty && labs.isEmpty { EmptyEstimate(app: app, p: p) }
            else {
                RowsCard(title: tr("es.mat"), n: mats.count, total: Money.of(tt.m, p), addKey: "gs.addMat",
                         draft: AppSettings.shared.rowDrafts[p.id + "|mat|new"] != nil, onAdd: { app.sheet = .row(pid: p.id, kind: "mat") }) {
                    if mats.isEmpty { None(text: tr("gs.noMat")) }
                    ForEach(mats) { m in
                        let bad = m.qty.trimmingCharacters(in: .whitespaces).isEmpty || m.price.trimmingCharacters(in: .whitespaces).isEmpty
                        LineRow(name: dn(m.name).isEmpty ? "—" : dn(m.name),
                                sub: bad ? tr("gs.miss") : "\(Money.num(m.qty, en)) \(dn(m.unit)) × \(Money.of(Money.parse(m.price, p.precision).value ?? 0, p))",
                                bad: bad, sum: bad ? "—" : Money.of(Money.line(m.qty, m.price, p.precision), p)) { app.sheet = .row(pid: p.id, kind: "mat", id: m.id) }
                    }
                }
                RowsCard(title: tr("es.lab"), n: labs.count, total: Money.of(tt.l, p), addKey: "gs.addLab",
                         draft: AppSettings.shared.rowDrafts[p.id + "|lab|new"] != nil, onAdd: { app.sheet = .row(pid: p.id, kind: "lab") }) {
                    if labs.isEmpty { None(text: tr("gs.noLab")) }
                    ForEach(labs) { l in
                        let bad = l.amount.trimmingCharacters(in: .whitespaces).isEmpty
                        LineRow(name: dn(l.name).isEmpty ? "—" : dn(l.name), sub: tr(bad ? "gs.missL" : "es.lump"), bad: bad,
                                sum: bad ? "—" : Money.of(Money.parse(l.amount, p.precision).value ?? 0, p)) { app.sheet = .row(pid: p.id, kind: "lab", id: l.id) }
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    MIcon("info", G.ink2, 18, 2)
                    T(tr("es.note"), ui(13, 400, G.ink2, lh: 1.45)).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 24)
    }
}

/// Whether the draft matches the last issued quote.
struct QuoteBanner: View {
    let same: Bool
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            MIcon(same ? "check" : "info", same ? (Theme.shared.dark ? G.green : Color(argb: 0xFF15803D)) : AMBER, 18, 2.2)
            T(text, ui(13.5, 500, G.ink, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(same ? Color(argb: 0x1F16A34A) : G.amberWash))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(same ? Color(argb: 0x3316A34A) : Color(argb: 0x33EA8C00), lineWidth: 1))
        .accessibilityIdentifier("es.quoteBanner")
    }
}

/// Net walls, floor (both open the areas by room) and the currency (prototype gsStats).
private struct Stats: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let a = pjAreas(p, AppSettings.shared.angleSnap), en = AppSettings.shared.lang == .en
        HStack(spacing: 8) {
            StatTile(icon: AnyView(MIcon("walls", G.cobalt, 16, 2)), label: tr("gs.wallNet"), value: a.nw > 0 ? Geo.fmtArea(a.w, en) : nil) { app.sheet = .areas(pid: p.id) }
                .accessibilityIdentifier("es.walls")
            StatTile(icon: AnyView(PathIcon(P_FLOOR, G.cobalt, 16, 2)), label: tr("gs.floor"), value: a.nf > 0 ? Geo.fmtArea(a.f, en) : nil) { app.sheet = .areas(pid: p.id) }
            VStack(alignment: .leading, spacing: 0) {
                T(tr("gs.cur"), ui(12, 600, G.ink2), lines: 1)
                Spacer(minLength: 6)
                T(p.currency, ui(18, 800), lines: 1)
            }
            .padding(.leading, 12).padding(.trailing, 14).padding(.top, 11).padding(.bottom, 10)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .gsCard(20, shadow: 20, a: 0.08, dy: 8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct StatTile: View {
    let icon: AnyView
    let label: String
    let value: String?
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) { icon; T(label, ui(12, 600, G.ink2, lh: 1.4)) }.padding(.trailing, 14)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                // a long area gets smaller and gives way first, so "m²" always shows
                Text(value ?? "—").st(ui(18, 800)).lineLimit(1).minimumScaleFactor(0.7)
                if value != nil { T(tr("u.m2"), ui(12, 600, G.ink2), lines: 1).fixedSize().layoutPriority(1) }
            }
        }
        .padding(.horizontal, 12).padding(.top, 11).padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) { MIcon("chev", Color(argb: 0xFF94A3B8), 14, 2.2).padding(.top, 11).padding(.trailing, 12) }
        .gsCard(20, shadow: 20, a: 0.08, dy: 8)
        .pressable(0.98, action)
    }
}

/// No rows yet: a card with Material / Labour and the quick adds (prototype .gs-empty, .gs-quick).
private struct EmptyEstimate: View {
    let app: AppModel
    let p: Project
    var body: some View {
        VStack(spacing: 0) {
            PathIcon(P_RCPT, G.cobalt, 30, 1.8).frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(G.cobalt.opacity(0.12)))
            T(tr("gs.empty"), ui(20, 800, G.ink, lh: 1.4), align: .center).padding(.top, 14)
            T(tr("gs.emptyB"), ui(14, 400, G.ink2, lh: 1.45), align: .center).padding(.top, 6)
            HStack(spacing: 10) {
                GBtn(tr("gs.mat"), icon: "plus", height: 52, corner: 26, fontSize: 15) { app.sheet = .row(pid: p.id, kind: "mat") }.accessibilityIdentifier("es.addMat")
                GBtn(tr("gs.lab"), kind: .secondary, icon: "plus", height: 52, corner: 26, fontSize: 15) { app.sheet = .row(pid: p.id, kind: "lab") }.accessibilityIdentifier("es.addLab")
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .gsCard(28)
        T(tr("gs.quick"), ui(13, 700, G.ink2)).padding(.leading, 4).padding(.top, 6)
        let sm = tr("gs.sMat").components(separatedBy: "|"), sl = tr("gs.sLab").components(separatedBy: "|")
        FlowLayout(spacing: 8) {
            ForEach(Array(sm.prefix(4).enumerated()), id: \.offset) { i, n in Quick(n: n) { app.sheet = .row(pid: p.id, kind: "mat", name: n, unit: SUG_UNITS[i]) } }
            ForEach(Array(sl.prefix(2).enumerated()), id: \.offset) { _, n in Quick(n: n) { app.sheet = .row(pid: p.id, kind: "lab", name: n) } }
        }
    }
}

private struct Quick: View {
    let n: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 6) { MIcon("plus", G.cobalt, 14, 2.4); T(n, ui(14, 600), lines: 1) }
            .padding(.leading, 10).padding(.trailing, 14).frame(height: 40)
            .background(Capsule().fill(G.glass(0.5)))
            .overlay(Capsule().strokeBorder(G.rim, lineWidth: 1))
            .pressable(0.97, action)
            .accessibilityIdentifier("es.quick")
    }
}

private struct Rule: View { var body: some View { Rectangle().fill(G.rim).frame(height: 0.67) } }

private struct RowsCard<Content: View>: View {
    let title: String
    let n: Int
    let total: String
    let addKey: String
    let draft: Bool
    let onAdd: () -> Void
    @ViewBuilder let rows: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                T(title, ui(16, 800), lines: 1)
                T("· \(n)", ui(16, 600, G.ink2))
                Spacer()
                T(total, ui(14, 800), lines: 1)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
            rows
            VStack(spacing: 0) {
                Rule()
                HStack(spacing: 8) {
                    MIcon("plus", G.cobalt2, 18, 2.2)
                    T(tr(addKey), ui(15, 700, G.cobalt2), lines: 1)
                    if draft {
                        T(tr("gs.dTag"), ui(11, 700, AMBER)).padding(.horizontal, 7).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 8).fill(G.amberWash))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).frame(height: 48)
                .background(G.cobalt.opacity(0.06))
                .pressable(0.99, onAdd)
                .accessibilityIdentifier(addKey)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .gsCard(26)
    }
}

private struct None: View {
    let text: String
    var body: some View {
        VStack(spacing: 0) { Rule(); T(text, ui(13.5, 400, G.ink2)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 14) }
    }
}

private struct LineRow: View {
    let name: String
    let sub: String
    let bad: Bool
    let sum: String
    let action: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Rule()
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    T(name, ui(15, 700), lines: 2)
                    T(sub, ui(12, bad ? 600 : 400, bad ? AMBER : G.ink2, lh: 1.4), lines: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                T(sum, ui(15, 800), lines: 1)
                MIcon("chev", G.ink2, 18, 2.2)
            }
            .padding(.leading, 16).padding(.trailing, 12).padding(.vertical, 10).frame(minHeight: 60)
            .pressable(0.99, action)
            .accessibilityIdentifier("es.row")
        }
    }
}

/// The floating total over the tab bar (prototype .footer.gs-tot); none while the estimate is empty.
struct EstimateTotal: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let tt = Money.totals(p)
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    T(tr("es.grand"), ui(13, 400, G.ink2))
                    T(tr("gs.split", ["m": Money.of(tt.m, p), "l": Money.of(tt.l, p)]), ui(12, 400, G.ink2, lh: 1.35))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(Money.of(tt.g, p)).st(ui(24, 800)).lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("es.grand")
                    T(" " + Money.cur(p.currency), ui(14, 700))
                }
            }
            .padding(.horizontal, 6)
            GBtn(tr("es.preview"), icon: "doc", height: 54, corner: 27, fontSize: 16) { app.push(.report(pid: p.id, no: nil)) }.accessibilityIdentifier("es.preview")
        }
        .padding(14)
        .glassBlur(shape, tint: G.sheet(0.6))
        .topHighlight(shape, 0.95)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 0.67))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.1), blur: 30, y: -10))
        .padding(.horizontal, 12).padding(.bottom, 12)
    }
}

/* ---------------- sheets ---------------- */

struct EstimateSheet: View {
    let app: AppModel
    let sheet: Sheet
    var body: some View {
        switch sheet {
        case .areas(let pid): AreasSheet(app: app, pid: pid)
        case .row(let pid, let kind, let id, let name, let unit):
            RowSheet(app: app, pid: pid, kind0: kind, rid: id, name0: name, unit0: unit).id("\(pid)|\(kind)|\(id ?? "")|\(name ?? "")")
        default: EmptyView()
        }
    }
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .areas, .row: return true; default: return false }
    }
}

/// The rooms' floor, perimeter and net walls, for reference only (prototype SHEETS.areas).
private struct AreasSheet: View {
    let app: AppModel
    let pid: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            let en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap, unit = AppSettings.shared.unit
            GlassSheet(tr("es.areas"), onClose: { app.sheet = nil }) {
                if p.rooms.isEmpty { T(tr("pr.emptyTitle"), ui(14, 400, G.ink2)) }
                ForEach(p.rooms) { r in
                    let a = Geo.areas(r, snap)
                    VStack(alignment: .leading, spacing: 6) {
                        T(dn(r.name), ui(15, 700))
                        if let a {
                            VStack(spacing: 0) {
                                kv(tr("rp.floorArea"), Geo.fmtArea(a.floor, en) + " " + tr("u.m2"))
                                Hairline(); kv(tr("rp.perim"), Geo.fmtLen(Int(a.perim), unit, en) + " " + unitName())
                                if let n = a.net { Hairline(); kv(tr("rp.net"), Geo.fmtArea(n, en) + " " + tr("u.m2")) }
                            }
                            .padding(.horizontal, 14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.6)))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                        } else { T(tr("rp.missing"), ui(13.5, 400, G.ink2)) }
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    MIcon("info", G.ink2, 18, 2)
                    T(tr("es.areasNote") + " " + tr("rp.conv"), ui(13, 400, G.ink2, lh: 1.45))
                }
            } footer: {
                GBtn(tr("common.close"), kind: .secondary) { app.sheet = nil }
            }
        }
    }
    private func kv(_ k: String, _ v: String) -> some View {
        HStack { T(k, ui(14, 400, G.ink2)).frame(maxWidth: .infinity, alignment: .leading); T(v, num(15, 700)) }.padding(.vertical, 12)
    }
}

/// What a typed number is wrong with, in words (prototype msg()); nil when fine or empty.
private func decErr(_ d: Dec) -> String? {
    switch d {
    case .ok, .empty: return nil
    case .format: return tr("err.format")
    case .negative: return tr("err.negative")
    case .precision(let n): return n > 0 ? tr("err.precision", ["n": n]) : tr("err.whole")
    }
}

private enum RF: Hashable { case name, qty, price, amount }

/// A new or existing estimate row (prototype SHEETS.row, glass "Yangi material"), keeping a draft when left unsaved.
private struct RowSheet: View {
    let app: AppModel
    let pid: String
    let kind0: String
    let rid: String?
    let name0: String?
    let unit0: String?
    @State private var kind = "mat"
    @State private var initForm: [String: String] = [:]
    @State private var form: [String: String] = [:]
    @State private var restored = false
    @State private var touched: Set<String> = []
    @State private var tried = false
    /// Saved or deleted: nothing to keep.
    @State private var closing = false
    @State private var loaded = false
    @FocusState private var focus: RF?

    private var st: AppSettings { AppSettings.shared }
    private var en: Bool { st.lang == .en }
    private var mat: Bool { kind == "mat" }
    private func key(_ k: String) -> String { pid + "|" + k + "|" + (rid ?? "new") }
    private func f(_ k: String) -> String { form[k] ?? "" }
    private func bind(_ k: String) -> Binding<String> { Binding(get: { form[k] ?? "" }, set: { form[k] = $0 }) }
    private func blank(_ k: String) -> Bool { f(k).trimmingCharacters(in: .whitespaces).isEmpty }
    /// The +10 % spare is for m² only: another unit turns it off (its chip is gone, so it could not be seen).
    private func setUnit(_ u: String) { form["eunit"] = u; if u != "@u.m2" { form["ereserve"] = "" } }

    private func initial(_ p: Project, _ k: String) -> [String: String] {
        let x = rid.flatMap { id in (k == "mat" ? p.estimate.materials : p.estimate.labor).first { $0.id == id } }
        if k == "mat" {
            return ["ename": x.map { dn($0.name) } ?? name0 ?? "", "eunit": x?.unit ?? unit0 ?? "@u.pcs",
                    "eqty": x.map { en ? $0.qty : $0.qty.replacingOccurrences(of: ".", with: ",") } ?? "", "eprice": x?.price ?? "", "ereserve": ""]
        }
        return ["ename": x.map { dn($0.name) } ?? name0 ?? "", "eamount": x?.amount ?? ""]
    }

    /// Something typed that a save would keep.
    private var dirty: Bool {
        let typed = ["ename", "eqty", "eprice", "eamount"].contains { !blank($0) }
        return form != initForm && (typed || rid != nil)
    }

    var body: some View {
        if let p = Store.shared.get(pid) {
            let nameErr = blank("ename") ? tr("re.nameReq") : nil
            let q: Dec = mat ? Money.parse(f("eqty"), 3) : .empty
            let pr = Money.parse(mat ? f("eprice") : f("eamount"), p.precision)
            // a sensible most: a million of a unit, a price or a labour line of a trillion (a longer number is a slip and breaks the layout)
            let qBig = mat && (q.value ?? 0) > Decimal(1_000_000)
            let pBig = (pr.value ?? 0) > Decimal(1_000_000_000_000)
            let qErr: String? = mat ? (qBig ? tr("err.most", ["max": "1 000 000"]) : decErr(q)) : nil
            let pErr: String? = pBig ? tr("err.most", ["max": "1 000 000 000 000"]) : decErr(pr)
            let reserve = f("ereserve") == "1" && f("eunit") == "@u.m2"
            let qShown: String? = mat && q.value != nil ? Money.num(reserve ? Money.withSpare(f("eqty")) : Money.canon(f("eqty")), en) : nil
            let lt: Decimal? = mat ? (q.value != nil && pr.value != nil ? Money.line(reserve ? Money.withSpare(f("eqty")) : f("eqty"), f("eprice"), p.precision) : nil) : pr.value
            let formula = mat ? "\(qShown ?? "?") \(dn(f("eunit"))) × \(pr.value.map { Money.of($0, p) } ?? "?") \(Money.cur(p.currency))" + (reserve ? " · " + tr("gs.withRes") : "")
                : tr("gs.agreed")
            let bad = nameErr != nil || qErr != nil || pErr != nil
            GlassSheet(rid != nil ? tr("gs.edit") : tr(mat ? "re.newMat" : "re.newLab"), onClose: { app.sheet = nil }) {
                if restored {
                    HStack(spacing: 8) {
                        MIcon("info", G.cobalt, 18, 2)
                        T(tr("gs.dBack"), ui(13.5, 600)).frame(maxWidth: .infinity, alignment: .leading)
                        T(tr("gs.dClear"), ui(13.5, 700, G.cobalt2)).padding(.horizontal, 10).padding(.vertical, 8)
                            .pressable(0.96) { st.setDraft(key(kind), nil); form = initForm; restored = false; touched = []; tried = false }
                            .accessibilityIdentifier("gs.dClear")
                    }
                    .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.cobalt.opacity(0.08)))
                }
                if rid == nil { KindSeg(cur: kind) { switchKind(p, $0) } }
                VStack(alignment: .leading, spacing: 8) {
                    GField(label: tr("gs.name"), value: bind("ename"), placeholder: tr(mat ? "gs.phMat" : "gs.phLab"), error: nameErr,
                           showError: tried || touched.contains("ename"), focus: $focus, me: .name, submit: .next,
                           onSubmit: { focus = mat ? .qty : .amount })
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(tr(mat ? "gs.sMat" : "gs.sLab").components(separatedBy: "|").enumerated()), id: \.offset) { i, n in
                                T(n, ui(13, 600, G.cobalt2), lines: 1).padding(.horizontal, 12).frame(height: 34)
                                    .background(Capsule().fill(G.cobalt.opacity(0.07)))
                                    .overlay(Capsule().strokeBorder(G.cobalt.opacity(0.2), lineWidth: 0.67))
                                    .pressable(0.97) { form["ename"] = n; if mat { setUnit(i < SUG_UNITS.count ? SUG_UNITS[i] : f("eunit")) } }
                            }
                        }
                    }
                }
                if mat {
                    VStack(alignment: .leading, spacing: 6) {
                        T(tr("gs.unit"), ui(15, 700))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(UNITS, id: \.self) { u in
                                    let on = f("eunit") == "@" + u
                                    T(tr(u), ui(14, on ? 700 : 600, on ? .white : G.ink), lines: 1).padding(.horizontal, 16).frame(height: 40)
                                        .background(Capsule().fill(on ? G.cobalt : G.glass(0.85)))
                                        .overlay(Capsule().strokeBorder(on ? G.cobalt : G.ink.opacity(0.1), lineWidth: 0.67))
                                        .boxShadow(on ? G.cobalt.opacity(0.3) : .clear, blur: 14, y: 6)
                                        .pressable(0.97) { setUnit("@" + u) }
                                        .accessibilityAddTraits(on ? .isSelected : [])
                                        .accessibilityIdentifier("unit." + u)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.vertical, -8)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        NumField(label: tr("gs.qty"), value: bind("eqty"), suffix: dn(f("eunit")), error: qErr, showError: tried || touched.contains("eqty"), focus: $focus, me: .qty, id: "gs.qty")
                        NumField(label: tr("gs.price"), value: bind("eprice"), suffix: Money.cur(p.currency), error: pErr, showError: tried || touched.contains("eprice"), focus: $focus, me: .price, id: "gs.price")
                    }
                    let ga = pjAreas(p, st.angleSnap)
                    if f("eunit") == "@u.m2" && (ga.nw > 0 || ga.nf > 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            T(tr("gs.fromRoom"), ui(15, 700))
                            FlowLayout(spacing: 6) {
                                if ga.nw > 0 { FromChip(label: tr("gs.wall") + " " + Geo.fmtArea(ga.w, en)) { form["eqty"] = area(ga.w); touched.insert("eqty") }.accessibilityIdentifier("gs.fromWall") }
                                if ga.nf > 0 { FromChip(label: tr("gs.floor") + " " + Geo.fmtArea(ga.f, en)) { form["eqty"] = area(ga.f); touched.insert("eqty") } }
                                ReserveChip(on: reserve) { form["ereserve"] = reserve ? "" : "1" }
                            }
                        }
                    }
                } else {
                    NumField(label: tr("gs.sum"), value: bind("eamount"), suffix: Money.cur(p.currency), error: pErr, showError: tried || touched.contains("eamount"), focus: $focus, me: .amount, id: "gs.sum")
                }
                // the line total, worked out as it is typed
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        T(tr("gs.line"), ui(13, 700, G.slate))
                        T(formula, ui(12, 400, G.ink2, lh: 1.35))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(lt.map { Money.of($0, p, withCur: true) } ?? "—").st(ui(20, 800, COB_DARK)).lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("gs.lineTotal")
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.cobalt.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(G.cobalt.opacity(0.16), lineWidth: 0.67))
                T(tr("gs.later"), ui(12, 400, G.ink2))
                if pErr == nil, let v = pr.value, v == 0 {
                    HStack(alignment: .top, spacing: 8) { MIcon("info", G.cobalt, 18, 2); T(tr("re.zero"), ui(13.5, 500)).frame(maxWidth: .infinity, alignment: .leading) }
                        .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.cobalt.opacity(0.08)))
                }
            } footer: {
                HStack(spacing: 10) {
                    if rid != nil {
                        MIcon("trash", Theme.shared.dark ? G.err : Color(argb: 0xFFB91C1C), 20, 2).frame(width: 54, height: 54)
                            .background(Circle().fill(Theme.shared.dark ? G.errWash : Color(argb: 0xB3FEE2E2)))
                            .overlay(Circle().strokeBorder(Color(argb: 0x40DC2626), lineWidth: 0.67))
                            .pressable(0.95, label: tr("gs.del")) { delete(p) }
                            .accessibilityIdentifier("gs.del")
                    } else {
                        GBtn(tr("gs.again"), kind: .secondary, height: 54, corner: 27, fontSize: 15) { save(p, again: true, bad) }.opacity(bad ? 0.5 : 1)
                            .accessibilityIdentifier("gs.again")
                    }
                    GBtn(tr("common.save"), height: 54, corner: 27, fontSize: 15) { save(p, again: false, bad) }.opacity(bad ? 0.5 : 1)
                        .accessibilityIdentifier("gs.save")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                kind = kind0
                initForm = initial(p, kind0)
                // a suggestion button opens a fresh sheet; otherwise a kept draft comes back
                if name0 == nil, let dr = st.rowDrafts[key(kind0)] { form = dr; restored = true } else { form = initForm }
                // a new row starts with the cursor in its name (prototype setFocus('ename'))
                if rid == nil && name0 == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .name } }
            }
            .onChange(of: focus) { was, _ in
                switch was {
                case .name?: touched.insert("ename")
                case .qty?: touched.insert("eqty")
                case .price?: touched.insert("eprice")
                case .amount?: touched.insert("eamount")
                default: break
                }
            }
            // leaving the sheet (×, outside, another tab) keeps what was typed; going to the background keeps it too
            .onDisappear {
                guard !closing else { return }
                if dirty { st.setDraft(key(kind), form); app.say("gs.dKept", kind: .info) }
                else if st.rowDrafts[key(kind)] != nil { st.setDraft(key(kind), nil) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                if !closing && dirty { st.setDraft(key(kind), form) }
            }
        }
    }

    private func area(_ mm2: Int64) -> String {
        // mm² to m², 2 decimals half up, trailing zeros dropped
        var v = Decimal(mm2) / 1_000_000, r = Decimal()
        NSDecimalRound(&r, &v, 2, .plain)
        let s = NSDecimalNumber(decimal: r).stringValue
        return en ? s : s.replacingOccurrences(of: ".", with: ",")
    }

    private func switchKind(_ p: Project, _ k: String) {
        guard k != kind else { return }
        let name = f("ename")
        if dirty { st.setDraft(key(kind), form) }
        kind = k
        var i = initial(p, k); i["ename"] = name
        initForm = i
        if let dr = st.rowDrafts[key(k)] { form = dr; restored = true } else { form = i; restored = false }
        touched = []; tried = false
    }

    private func save(_ p: Project, again: Bool, _ bad: Bool) {
        if bad { tried = true; return }
        let reserve = f("ereserve") == "1" && f("eunit") == "@u.m2"
        let qty = blank("eqty") ? "" : Money.canon(reserve ? Money.withSpare(f("eqty")) : f("eqty"))
        let old = rid.flatMap { id in (mat ? p.estimate.materials : p.estimate.labor).first { $0.id == id } }
        // a calculator line changed by hand becomes the maker's own ("t-" lines are replaced on "Smetani yangilash")
        let id = rid.map { $0.hasPrefix("t-") && form != initForm ? uid() : $0 } ?? uid()
        // an untouched name keeps its key, so it still follows the language
        let typed = f("ename").trimmingCharacters(in: .whitespaces)
        let name = old.map { typed == dn($0.name) ? $0.name : typed } ?? typed
        let row = mat ? Row(id: id, name: name, unit: f("eunit"), qty: qty, price: blank("eprice") ? "" : Money.canon(f("eprice")))
            : Row(id: id, name: name, amount: blank("eamount") ? "" : Money.canon(f("eamount")))
        let m = mat, existing = rid
        Store.shared.update(p.id) { pp in
            if pp.stage == "measure" { pp.stage = "estimate" }
            func put(_ list: inout [Row]) { if let existing, let i = list.firstIndex(where: { $0.id == existing }) { list[i] = row } else { list.append(row) } }
            if m { put(&pp.estimate.materials) } else { put(&pp.estimate.labor) }
        }
        st.setDraft(key(kind), nil)
        if rid != nil { app.say("op.saved", ["o": dn(row.name)]) } else { app.say("re.added") }
        if again {
            // a fresh sheet for the next row of the same kind, without the suggested name and unit
            var i = initial(p, kind)
            if name0 != nil || unit0 != nil { i["ename"] = ""; if mat { i["eunit"] = "@u.pcs" } }
            initForm = i; form = initForm; restored = false; touched = []; tried = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focus = .name }
        } else { closing = true; app.sheet = nil }
    }

    private func delete(_ p: Project) {
        closing = true
        st.setDraft(key(kind), nil)
        let m = mat, id = rid
        guard let gone = (m ? p.estimate.materials : p.estimate.labor).first(where: { $0.id == id }) else { app.sheet = nil; return }
        let idx = (m ? p.estimate.materials : p.estimate.labor).firstIndex { $0.id == id } ?? 0
        Store.shared.update(p.id) { pp in if m { pp.estimate.materials.removeAll { $0.id == id } } else { pp.estimate.labor.removeAll { $0.id == id } } }
        app.sheet = nil
        // Undo puts the row back where it was
        let pid = p.id
        app.say("re.deleted", action: "common.undo") {
            Store.shared.update(pid) { pp in
                func back(_ list: inout [Row]) { if !list.contains(where: { $0.id == gone.id }) { list.insert(gone, at: min(idx, list.count)) } }
                if m { back(&pp.estimate.materials) } else { back(&pp.estimate.labor) }
            }
        }
    }
}

/// Material | Labour for a new row (prototype .gs-seg).
private struct KindSeg: View {
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        HStack(spacing: 2) {
            ForEach([("mat", tr("gs.mat")), ("lab", tr("gs.lab"))], id: \.0) { k, l in
                let on = k == cur
                T(l, ui(14, on ? 700 : 600, on ? G.ink : G.ink2), lines: 1).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(on ? G.glass(0.95) : .clear))
                    .boxShadow(on ? Color(argb: 0x24101828) : .clear, blur: 3, y: 1)
                    .pressable(0.98) { onPick(k) }
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("kind." + k)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
    }
}

private struct FromChip: View {
    let label: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 6) { PathIcon(P_PLAN, G.cobalt, 16, 2.2); T(label, ui(13, 600), lines: 1) }
            .padding(.horizontal, 12).frame(height: 38)
            .background(Capsule().fill(G.glass(0.8)))
            .overlay(Capsule().strokeBorder(G.rim, lineWidth: 0.67))
            .boxShadow(G.shade.opacity(0.06), blur: 8, y: 2)
            .pressable(0.97, action)
    }
}

private struct ReserveChip: View {
    let on: Bool
    let action: () -> Void
    var body: some View {
        HStack(spacing: 5) {
            if on { MIcon("check", G.cobalt, 14, 2.6) }
            T(tr("gs.reserve"), ui(13, 700, on ? G.cobalt2 : G.slate), lines: 1)
        }
        .padding(.horizontal, 12).frame(height: 38)
        .background(Capsule().fill(on ? G.cobalt.opacity(0.1) : G.glass(0.8)))
        .overlay(Capsule().strokeBorder(on ? G.cobalt : G.ink.opacity(0.2), style: StrokeStyle(lineWidth: on ? 1.5 : 0.67, dash: on ? [] : [4, 3])))
        .pressable(0.97, action)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("gs.reserve")
    }
}
