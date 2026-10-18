import SwiftUI

/*
 * Furniture makers, Stage 1a part 1 (design/furniture/FURNITURE_PLAN.md, sections 3 and 4; Android ui/furniture/Orders.kt):
 * the industry picker, the furniture Home, order rows, the order's stages and its payments.
 */

private let BUILD_ICON = "M6 8h28v24H6z M6 20h12v12 M24 8v10h10"
private let FURN_ICON = "M4 6h32v9H4z M4 22h32v14H4z M3 20h34 M20 6v9 M15 22v14 M27 22v14"
private let RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
let SHEET_ICON = "M3 3h18v18H3z M3 12h11v9 M14 3v9 M14 8h7"
private let ARROW = "M7 17L17 7M9 7h8v8"

private var en: Bool { AppSettings.shared.lang == .en }

/// Money of a project in its currency, "12 500 000 so‘m".
func orderMoneyStr(_ p: Project, _ v: Decimal) -> String { Money.str(v, p.precision, en) + " " + Money.cur(p.currency) }

/* ---------------- the industry picker (first run, after sign-in) ---------------- */

struct IndustryScreen: View {
    let app: AppModel
    let onBack: () -> Void
    let onPick: (String) -> Void
    @State private var pick: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                GlassIconButton("back", tr("nt.back"), onBack)
                LogoTile(size: 30, corner: 9)
                Text("METRX").font(.custom("PlusJakartaSans-Bold", size: 16)).foregroundColor(G.ink).tracking(16 * 0.32)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T(tr("ind.title"), ui(30, 800, G.ink, lh: 1.15, ls: -0.02)).accessibilityAddTraits(.isHeader)
                    T(tr("ind.lead"), ui(15, 400, G.ink2, lh: 1.45)).padding(.bottom, 8)
                    IndustryCard(icon: BUILD_ICON, title: tr("ind.build"), sub: tr("ind.buildS"), on: pick == "build") { pick = "build" }
                        .accessibilityIdentifier("ind.build")
                    IndustryCard(icon: FURN_ICON, title: tr("ind.furn"), sub: tr("ind.furnS"), on: pick == "furniture") { pick = "furniture" }
                        .accessibilityIdentifier("ind.furn")
                    T(tr("ind.soon"), ui(13, 700, G.ink2)).padding(.top, 8)
                    ForEach([["ind.tiler", "ind.elec"], ["ind.plumb", "ind.win"]], id: \.self) { pair in
                        HStack(spacing: 8) {
                            ForEach(pair, id: \.self) { k in
                                let name = tr(k)
                                HStack(spacing: 6) {
                                    T(name, ui(13.5, 600, G.ink3), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                                    T(tr("ind.soon"), ui(10.5, 700, G.ink2), lines: 1).padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(G.ink3.opacity(0.14)))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.glass(0.25)))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(G.ink3.opacity(0.35), lineWidth: 1))
                                .pressable(0.98) { app.say("ind.soonToast", ["n": name], kind: .info) }
                            }
                        }
                    }
                }
                .padding(.top, 22)
            }
            GBtn(tr("ind.go"), enabled: pick != nil) { if let k = pick { onPick(k) } }.padding(.top, 12).accessibilityIdentifier("ind.go")
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
    }
}

private struct IndustryCard: View {
    let icon: String
    let title: String
    let sub: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        HStack(spacing: 14) {
            PathIcon(icon, G.cobalt, 40, 2, viewBox: 40).frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) { T(title, ui(19, 800)); T(sub, ui(13.5, 400, G.ink2, lh: 1.4)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            if on { MIcon("check", .white, 14, 3).frame(width: 26, height: 26).background(Circle().fill(G.cobalt)) }
        }
        .padding(16)
        .glassCard(shape)
        .overlay(on ? shape.strokeBorder(G.cobalt, lineWidth: 2.5) : nil)
        .pressable(0.99, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/* ---------------- Home for a furniture maker ---------------- */

struct FurnitureHome: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        let first = s.builderName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let lines = tr("fo.lines").split(separator: "|").map(String.init)
        let orders = Store.shared.projects.filter(\.isFurniture)
        let (debt, nDebt) = owed(orders)
        VStack(spacing: 0) {
            GlassHeader { app.sheet = .device }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        T(first.isEmpty ? tr("hm.hi0") : tr("hm.hi", ["n": first]), ui(34, 800, G.ink, lh: 1.1, ls: -0.02)).accessibilityAddTraits(.isHeader)
                        T(lines.isEmpty ? "" : lines[s.visit % lines.count], ui(17, 500, G.slate, lh: 1.35)).frame(maxWidth: 320, alignment: .leading)
                    }
                    .padding(.top, 18).padding(.bottom, 8)
                    let big = RoundedRectangle(cornerRadius: 30, style: .continuous)
                    HStack(spacing: 14) {
                        MIcon("plus", .white, 26, 2.4).frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.cobalt))
                            .boxShadow(G.cobalt.opacity(0.4), blur: 22, y: 10)
                        VStack(alignment: .leading, spacing: 2) { T(tr("fo.new"), ui(22, 800, G.ink, lh: 1.15, ls: -0.01)); T(tr("fo.newS"), ui(14, 400, G.ink2)) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        PathIcon(ARROW, G.ink, 20, 2.2)
                    }
                    .padding(18)
                    .glassCard(big, shadowBlur: 36, shadowY: 16, shadowAlpha: 0.15)
                    .pressable(0.985) { app.push(.newProject(editId: nil)) }
                    .accessibilityElement(children: .combine).accessibilityIdentifier("home.new")
                    HStack(spacing: 12) {
                        Tile(icon: RULER, title: tr("gl.meas"), sub: tr("gl.measS")) { app.push(.measure(calc: false)) }.accessibilityIdentifier("home.measure")
                        Tile(icon: SHEET_ICON, title: tr("fo.sheets"), sub: tr("fo.sheetsS")) { MeasureCalc.shared.tool = "sheet"; app.push(.measure(calc: true)) }
                            .accessibilityIdentifier("home.sheets")
                    }
                    if nDebt > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                T(tr("fo.owed"), ui(12.5, 600, G.ink2))
                                Text(Money.str(debt, 0, en) + " " + Money.cur(s.currency)).st(num(21, 800))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            T(tr("fo.owedN", ["n": nDebt]), ui(12.5, 400, G.ink2)).frame(maxWidth: 120, alignment: .trailing)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .glassCard(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    HStack {
                        T(tr("fo.recent"), ui(17, 800)).frame(maxWidth: .infinity, alignment: .leading)
                        if !orders.isEmpty { T(tr("fo.all"), ui(13.5, 700, G.cobalt2)).padding(.horizontal, 6).padding(.vertical, 8).pressable(0.97) { app.selectTab(.projects) } }
                    }
                    .padding(.top, 6)
                    if orders.isEmpty { T(tr("fo.noOrders"), ui(14, 400, G.ink2, lh: 1.45)) }
                    ForEach(orders.prefix(3)) { p in OrderLine(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                }
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24 + NAV_SPACE)
            }
        }
    }
}

private struct Tile: View {
    let icon: String
    let title: String
    let sub: String
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PathIcon(icon, G.cobalt, 24, 2)
            Spacer(minLength: 18)
            T(title, ui(17, 700)); T(sub, ui(12.5, 400, G.ink2))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
    }
}

private struct OrderLine: View {
    let p: Project
    let action: () -> Void
    var body: some View {
        let m = orderMoney(p)
        let leftPart: String? = { if let l = m.left, l > 0, fStage(p) >= 3 { return tr("fo.leftV", ["v": orderMoneyStr(p, l)]) }; return nil }()
        let sub = [dn(p.customer).isEmpty ? nil : dn(p.customer), leftPart].compactMap { $0 }.joined(separator: " · ")
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                T(dn(p.name), ui(15, 700), lines: 1)
                if !sub.isEmpty { T(sub, ui(12.5, 400, G.ink2), lines: 1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FStageChip(stage: p.stage)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
    }
}

/// A furniture order's stage as a coloured chip.
struct FStageChip: View {
    let stage: String
    var body: some View {
        let (bg, fg): (Color, Color) = stage == "measure" || stage == "production" ? (G.amberWash, G.amberInk)
            : stage == "installed" || stage == "paid" ? (Color(argb: 0x2416A34A), Theme.shared.dark ? G.green : Color(argb: 0xFF15803D))
            : (G.cobalt.opacity(0.12), G.cobalt2)
        T(tr("fs." + stage), ui(12, 600, fg), lines: 1).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(bg))
    }
}

/// One order in the Orders list: name and stage, customer, the 7 stages as a bar, the price and what is left.
struct OrderRow: View {
    let p: Project
    let action: () -> Void
    var body: some View {
        let m = orderMoney(p)
        let k = fStage(p)
        let sub = [dn(p.customer), dn(p.address)].filter { !$0.isEmpty }.joined(separator: " · ")
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) { T(dn(p.name), ui(15.5, 700), lines: 1).frame(maxWidth: .infinity, alignment: .leading); FStageChip(stage: p.stage) }
            if !sub.isEmpty { T(sub, ui(12.5, 400, G.ink2), lines: 1) }
            HStack(spacing: 4) {
                ForEach(0..<F_STAGES.count, id: \.self) { i in RoundedRectangle(cornerRadius: 3).fill(i <= k ? G.cobalt : G.ink.opacity(0.12)).frame(height: 5) }
            }
            HStack {
                T(m.agreed.map { orderMoneyStr(p, $0) } ?? "\(k + 1)/\(F_STAGES.count)", ui(12.5, 400, G.ink2)).frame(maxWidth: .infinity, alignment: .leading)
                if let left = m.left, k >= 3 {
                    T(left == 0 ? tr("fs.paid") : tr("fo.leftV", ["v": orderMoneyStr(p, left)]), ui(12.5, 700, left == 0 ? G.green : G.amberInk))
                }
            }
        }
        .padding(14)
        .glassCard(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The order page's three numbers: stage, agreed price, paid.
struct FNums: View {
    let p: Project
    var body: some View {
        let m = orderMoney(p)
        let a = m.agreed.map { Money.short(p, $0, en, tr("pl.mln")) } ?? ("—", nil)
        let pd = Money.short(p, m.paid, en, tr("pl.mln"))
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 12) {
                cell(tr("fo.stage"), "\(fStage(p) + 1)/\(F_STAGES.count)", nil)
                cell(tr("fo.agreed"), a.0, a.1)
                cell(tr("fo.paid"), pd.0, pd.1)
            }
            .padding(.horizontal, 4).padding(.top, 10)
        }
        .padding(.top, 11)
    }
    private func cell(_ label: String, _ value: String, _ unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            T(label, ui(11.5, 400, G.ink2), lines: 1)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(value).st(num(17, 800)).lineLimit(1)
                if let unit { Text(" " + unit).st(ui(10.5, 600, G.ink2)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Price and Quotes tabs of an order arrive with the furniture core: they say so.
struct FLater: View {
    var body: some View {
        VStack(spacing: 10) {
            PathIcon(SHEET_ICON, G.cobalt, 26, 2).frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.12)))
            T(tr("fo.later"), ui(15, 600, G.ink2, lh: 1.4), align: .center).frame(maxWidth: 300)
        }
        .padding(24).frame(maxWidth: .infinity)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        .padding(.horizontal, 16).padding(.top, 14)
    }
}

/* ---------------- Details tab: stages and payments ---------------- */

struct FurnitureInfo: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let m = orderMoney(p)
        let k = fStage(p)
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                T(tr("fo.stage"), ui(15, 800)).padding(.bottom, 4)
                ForEach(Array(F_STAGES.enumerated()), id: \.offset) { i, st in
                    let done = i < k, cur = i == k
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(done ? G.cobalt : cur ? G.solid : .clear)
                            Circle().strokeBorder(done || cur ? G.cobalt : G.ink3.opacity(0.35), lineWidth: 2)
                            if done { MIcon("check", .white, 13, 3) } else { T("\(i + 1)", ui(12, 800, cur ? G.cobalt2 : G.ink3)) }
                        }
                        .frame(width: 26, height: 26)
                        T(tr("fs." + st), ui(14.5, cur ? 800 : 600, i > k ? G.ink3 : G.ink)).frame(maxWidth: .infinity, alignment: .leading)
                        if st == "approved" && k >= 3, let a = m.agreed { T(orderMoneyStr(p, a), ui(12.5, 400, G.ink2)) }
                    }
                    .frame(minHeight: 36)
                }
                if k == 2 {
                    GBtn(tr("fo.next", ["s": tr("fs.approved")])) { app.sheet = .fApprove(pid: p.id) }.padding(.top, 8).accessibilityIdentifier("fo.next")
                } else if k < 5 {
                    GBtn(tr("fo.next", ["s": tr("fs." + F_STAGES[k + 1])])) {
                        let q = Store.shared.update(p.id) { $0 = nextStage($0) }
                        if q?.stage == "paid" { app.say("fs.paid") }
                    }
                    .padding(.top, 8).accessibilityIdentifier("fo.next")
                } else if k == 5 {
                    T(tr("fo.payLeft"), ui(13, 400, G.ink2, lh: 1.4)).padding(.top, 6)
                }
                if k > 0 {
                    T(tr("fo.prev"), ui(13.5, 600, G.cobalt2)).padding(.horizontal, 10).padding(.vertical, 12).frame(minHeight: 44)
                        .pressable(0.97) { Store.shared.update(p.id) { $0 = prevStage($0) } }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    T(tr("fo.pays"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                    if k >= 3, let left = m.left, left > 0 {
                        GBtn(tr("fo.addPay"), kind: .secondary, icon: "plus", height: 40, corner: 14, fontSize: 14, fill: false) { app.sheet = .fPay(pid: p.id) }
                            .accessibilityIdentifier("fo.addPay")
                    }
                }
                if let a = m.agreed {
                    HStack(spacing: 12) {
                        money(tr("fo.agreed"), a); money(tr("fo.paid"), m.paid); money(tr("fo.left"), m.left ?? 0)
                    }
                }
                if p.payments.isEmpty { T(tr("fo.noPays"), ui(13, 400, G.ink2, lh: 1.4)) }
                ForEach(p.payments.reversed()) { pay in
                    Hairline()
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            T(pay.pre ? tr("fo.pre") : (pay.note.isEmpty ? tr("fo.pay") : pay.note), ui(14, 700), lines: 1)
                            T(fmtDate(pay.ts), ui(12, 400, G.ink2))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("+" + orderMoneyStr(p, Decimal(string: pay.amount) ?? 0)).st(num(14.5, 800, G.green))
                        MIcon("x", G.ink3, 16, 2).frame(width: 40, height: 40).pressable(0.95, label: tr("common.delete")) {
                            let before = p
                            Store.shared.update(p.id) { $0 = removePayment($0, pay.id) }
                            app.say("fo.payDel", action: "common.undo") { Store.shared.update(p.id) { $0 = before } }
                        }
                    }
                    .frame(minHeight: 48)
                }
            }
            .padding(14)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }
    private func money(_ label: String, _ v: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 2) { T(label, ui(11.5, 400, G.ink2), lines: 1); Text(Money.str(v, p.precision, en)).st(num(17, 800)).lineLimit(1).minimumScaleFactor(0.7) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/* ---------------- sheets ---------------- */

struct FurnitureSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .industry, .fApprove, .fPay, .pointForm: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .industry: IndustrySheet(app: app)
        case .fApprove(let pid): ApproveSheet(app: app, pid: pid)
        case .fPay(let pid): PaySheet(app: app, pid: pid)
        case .pointForm(let pid, let rid, let wall, let id): PointSheet(app: app, pid: pid, rid: rid, wall0: wall, id: id)
        default: EmptyView()
        }
    }
}

private struct IndustrySheet: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        GlassSheet(tr("ind.row"), onClose: { app.sheet = nil }) {
            ForEach([("build", "ind.build", "ind.buildS"), ("furniture", "ind.furn", "ind.furnS")], id: \.0) { k, t, sub in
                Opt(title: tr(t), on: s.industry == k, sub: tr(sub)) {
                    s.setIndustryKind(k); app.sheet = nil
                    if k == "furniture" && MeasureCalc.shared.tool == "brick" { MeasureCalc.shared.tool = "sheet" }
                    if k == "build" && MeasureCalc.shared.tool == "sheet" { MeasureCalc.shared.tool = "area" }
                    app.say("ind.set", ["n": tr(t)])
                }
            }
        }
    }
}

/// Typed money: nil with the error key when it is not a positive whole amount in the project's precision.
private func parseMoney(_ text: String, _ precision: Int) -> (Decimal?, String?) {
    switch Money.parse(text, precision) {
    case .ok(let v): return v > 0 ? (v, nil) : (nil, "fo.needPrice")
    case .empty: return (nil, "fo.needPrice")
    default: return (nil, "err.whole")
    }
}

private enum MF: Hashable { case a, b }

private struct ApproveSheet: View {
    let app: AppModel
    let pid: String
    @State private var price: String
    @State private var pre = ""
    @State private var preTouched = false
    @State private var tried = false
    @FocusState private var focus: MF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        _price = State(initialValue: Store.shared.get(pid)?.agreed ?? "")
    }
    var body: some View {
        if let p = Store.shared.get(pid) {
            let (pv, pErr) = parseMoney(price, p.precision)
            // the prepayment follows the price until it is typed: half of it
            let preText = preTouched ? pre : pv.map { Money.digits(halfOf($0)) } ?? ""
            let (rv0, rErr0): (Decimal?, String?) = preText.isEmpty ? (0, nil) : parseMoney(preText, p.precision)
            let rErr = rErr0 ?? ((pv != nil && rv0 != nil && rv0! > pv!) ? "fo.preBig" : nil)
            let ok = pv != nil && rErr == nil
            GlassSheet(tr("fo.approveT"), onClose: { app.sheet = nil }) {
                T(tr("fo.approveB"), ui(14, 400, G.ink2, lh: 1.45))
                GField(label: tr("fo.agreed"), value: $price, placeholder: "0", error: pErr.map { tr($0) }, showError: tried || !price.isEmpty, focus: $focus, me: .a,
                       labelRight: Money.cur(p.currency), number: true)
                GField(label: tr("fo.pre"), value: Binding(get: { preText }, set: { pre = $0.filter { $0.isNumber }; preTouched = true }), placeholder: "0", optional: true,
                       error: rErr.map { tr($0) }, showError: true, focus: $focus, me: .b, submit: .done, number: true)
                if let pv, let rv = rv0, rv > 0, rErr == nil {
                    T(tr("fo.prePct", ["p": NSDecimalNumber(decimal: rv * 100 / pv).intValue]), ui(13, 400, G.ink2))
                }
            } footer: {
                GBtn(tr("fo.approve"), enabled: !tried || ok) {
                    tried = true
                    guard ok, let pv else { return }
                    Store.shared.update(pid) { $0 = approve($0, pv, rv0 ?? 0, nowMs()) }
                    app.sheet = nil; app.say("fo.approvedT")
                }
                .accessibilityIdentifier("fo.approve")
            }
            .onChange(of: price) { _, v in let f = v.filter { $0.isNumber || $0 == " " }; if f != v { price = f } }
        }
    }
}

private struct PaySheet: View {
    let app: AppModel
    let pid: String
    @State private var amount: String
    @State private var note = ""
    @FocusState private var focus: MF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        _amount = State(initialValue: Store.shared.get(pid).flatMap { orderMoney($0).left }.map { Money.digits($0) } ?? "")
    }
    var body: some View {
        if let p = Store.shared.get(pid) {
            let left = orderMoney(p).left
            let (av, aErr0) = parseMoney(amount, p.precision)
            let aErr = aErr0 ?? ((av != nil && left != nil && av! > left!) ? "fo.tooMuch" : nil)
            GlassSheet(tr("fo.addPay"), onClose: { app.sheet = nil }) {
                if let left { T(tr("fo.leftV", ["v": orderMoneyStr(p, left)]), ui(14, 600, G.ink2)) }
                GField(label: tr("fo.amount"), value: $amount, placeholder: "0", error: aErr.map { tr($0) }, showError: !amount.isEmpty, focus: $focus, me: .a,
                       labelRight: Money.cur(p.currency), number: true)
                GField(label: tr("fo.note"), value: $note, optional: true, focus: $focus, me: .b, submit: .done)
            } footer: {
                GBtn(tr("common.save"), enabled: aErr == nil) {
                    guard aErr == nil, let av else { return }
                    let q = Store.shared.update(pid) { $0 = addPayment($0, av, note, nowMs()) }
                    app.sheet = nil
                    app.say(q?.stage == "paid" ? "fs.paid" : "fo.payAdded")
                }
                .accessibilityIdentifier("fo.paySave")
            }
            .onChange(of: amount) { _, v in let f = v.filter { $0.isNumber || $0 == " " }; if f != v { amount = f } }
        }
    }
}
