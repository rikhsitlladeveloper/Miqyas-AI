import Foundation

/*
 * What an order costs the workshop (furniture plan section 6.7; Android furniture/Costing.kt): sheets to buy (from the
 * sheet layout), banding by the metre, hardware, and labour. Money is whole numbers of the smallest unit; nothing is
 * rounded but the metres of banding and rail, which are bought whole (up), and the worktop's metres × price.
 */

/// One cost line: group mat, hw or lab; key a material or hardware id, or a labour strings key; qty how many of unit.
struct CostLine: Equatable { let group: String, key: String, qty: Double, unit: String, price: Decimal, amount: Decimal, missing: Bool }

struct Cost: Equatable {
    let lines: [CostLine], layouts: [MatLayout], rows: [CutRow]
    func sum(_ g: String) -> Decimal { lines.filter { $0.group == g }.reduce(0) { $0 + $1.amount } }
    var total: Decimal { lines.reduce(0) { $0 + $1.amount } }
    /// Lines that have no price yet in the workshop's lists.
    var missing: Int { lines.filter(\.missing).count }
}

/// A whole price as typed in the lists ("620000"); nil when empty or not a whole number.
private func money(_ s: String?) -> Decimal? {
    guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty, t.range(of: "^-?\\d+$", options: .regularExpression) != nil else { return nil }
    return Decimal(string: t)
}

/// Whole metres, rounded up.
private func metres(_ m: Double) -> Double { (m - 1e-9).rounded(.up) }

private func roundHalfUp(_ x: Decimal) -> Decimal { var a = x, r = Decimal(); NSDecimalRound(&r, &a, 0, .plain); return r }

/// Square metres for mm2 mm², rounded up to 0,01 m².
private func costAreaM2(_ mm2: Int) -> Double { (Double(mm2) / 10000 - 1e-9).rounded(.up) / 100 }

/// p × q (q in hundredths), rounded half up.
private func byQty(_ p: Decimal?, _ q: Double) -> Decimal { roundHalfUp((p ?? 0) * (Decimal(string: String(format: "%.2f", q)) ?? 0)) }

/// A backsplash board's running length and area, kitchens added up (Kotlin's id → (board, mm, mm²)).
private struct SplashSum { let mat: Mat?; var mm: Int; var mm2: Int }

/// The cost of fs with this workshop's settings and lists. order adds installation and delivery once (an order with
/// furniture in it). The store's remnants rems are cut first: only the new sheets are bought.
func costOf(_ fs: [Furniture], _ ws: Workshop, _ mats: [Mat], _ hws: [Hw], order: Bool = true, rems: [Remnant] = []) -> Cost {
    let rows = cutList(fs, ws)
    let lays = layouts(rows, mats, ws, rems)
    var lines: [CostLine] = []
    func mat(_ id: String) -> Mat? { mats.first { $0.id == id } }
    for l in lays {
        let mt = mat(l.mat)
        // a board bought by the m² (a decor's fronts, DecorPresets.swift): the area of its parts, finished sizes, to 0,01 m²
        if mt?.byArea == true {
            let mm2 = rows.filter { $0.mat == l.mat }.reduce(0) { $0 + $1.p.L * $1.p.W * $1.p.qty }
            if mm2 <= 0 { continue }
            let q = costAreaM2(mm2), p = money(mt?.price)
            lines.append(CostLine(group: "mat", key: l.mat, qty: q, unit: "m2", price: p ?? 0, amount: byQty(p, q), missing: p == nil))
            continue
        }
        // a part longer than the sheet is not left out of the price: a sheet of its own each (bought longer or joined)
        let p = money(mt?.price), n = l.sheets.count + l.unplaced.count
        // every part of this board on remnants: no sheet bought, no line (and no "price missing" for it)
        if n == 0 { continue }
        lines.append(CostLine(group: "mat", key: l.mat, qty: Double(n), unit: "sheet", price: p ?? 0, amount: (p ?? 0) * Decimal(n), missing: p == nil))
    }
    // kitchens: the worktop as one simple item by the running metre (plan section 7; joints and cut-outs in Stage 1b);
    // each piece its own worktop (PieceLook.swift; "wt38" before 25 Oct 2026)
    var wtIds: [String] = [], wtMm: [String: Int] = [:]
    for f in fs {
        // a table's or bar counter's top of worktop board
        let mm = (f.kind == "kitchen" ? worktopRuns(f).values.reduce(0, +) : 0) + f.modules.reduce(0) { $0 + itemWorktopMm($1) }
        if mm <= 0 { continue }
        let id = worktopOf(f)
        if wtMm[id] == nil { wtIds.append(id) }
        wtMm[id, default: 0] += mm
    }
    for id in wtIds {
        let mm = wtMm[id] ?? 0, p = money(mat(id)?.price)
        lines.append(CostLine(group: "mat", key: id, qty: Double(mm) / 1000, unit: "m", price: p ?? 0,
                              amount: roundHalfUp((p ?? 0) * Decimal(mm) / 1000), missing: p == nil))
    }
    // the backsplash, by the running metre like the worktop, or by its area (skinali, tile); each kitchen its own
    var spIds: [String] = [], sp: [String: SplashSum] = [:]
    for f in fs where f.kind == "kitchen" && (f.kx?.splash ?? 0) > 0 {
        let m = splashOf(f, mats), mm = splashMm(f)
        if mm <= 0 { continue }
        let id = m?.id ?? "splash6"
        if sp[id] == nil { spIds.append(id); sp[id] = SplashSum(mat: m, mm: 0, mm2: 0) }
        sp[id]?.mm += mm; sp[id]?.mm2 += mm * (f.kx?.splash ?? 0)
    }
    for id in spIds {
        guard let e = sp[id] else { continue }
        let p = money(e.mat?.price)
        if e.mat?.byArea == true {
            let q = costAreaM2(e.mm2)
            lines.append(CostLine(group: "mat", key: id, qty: q, unit: "m2", price: p ?? 0, amount: byQty(p, q), missing: p == nil))
        } else {
            lines.append(CostLine(group: "mat", key: id, qty: Double(e.mm) / 1000, unit: "m", price: p ?? 0,
                                  amount: roundHalfUp((p ?? 0) * Decimal(e.mm) / 1000), missing: p == nil))
        }
    }
    let (thick, thin) = bandMetres(rows)
    for (id, m) in [("band2", thick), ("band04", thin)] where m > 0 {
        let q = metres(m), p = money(mat(id)?.price)
        lines.append(CostLine(group: "mat", key: id, qty: q, unit: "m", price: p ?? 0, amount: (p ?? 0) * Decimal(Int(q)), missing: p == nil))
    }
    // handles of a kind chosen for a piece ("Change for all") are priced at that item, the rest at the usual one
    var counts: [HwCount] = hardware(fs, ws).pairs.map { HwCount(kind: $0.0, hw: usualHw(hws, $0.0), n: $0.1) }
    let usualHandle = usualHw(hws, "handle")
    func bump(_ hw: Hw?, _ n: Int) {
        if let oi = counts.firstIndex(where: { $0.kind == "handle" && $0.hw == hw }) { counts[oi].n += n }
        else { counts.append(HwCount(kind: "handle", hw: hw, n: n)) }
    }
    for f in fs {
        // long verticals (PieceLook.swift): each handle by its front's height
        if f.handle == LONG_V {
            guard let ui = counts.firstIndex(where: { $0.kind == "handle" && $0.hw == usualHandle }) else { continue }
            let n = min(hardware([f], ws)["handle"] ?? 0, counts[ui].n)
            if n <= 0 { continue }
            var ids = Array(longHandleIds(f, ws).prefix(n))
            while ids.count < n { ids.append("handleLong") }
            counts[ui].n -= n
            for id in ids { bump(hws.first { $0.id == id && $0.kind == "handle" } ?? usualHandle, 1) }
            continue
        }
        guard let own = hws.first(where: { $0.id == f.handle && $0.kind == "handle" }) else { continue }
        guard let ui = counts.firstIndex(where: { $0.kind == "handle" && $0.hw == usualHandle }) else { continue }
        let n = min(hardware([f], ws)["handle"] ?? 0, counts[ui].n)
        if n <= 0 || own == usualHandle { continue }
        counts[ui].n -= n
        if let oi = counts.firstIndex(where: { $0.kind == "handle" && $0.hw == own }) { counts[oi].n += n }
        else { counts.append(HwCount(kind: "handle", hw: own, n: n)) }
    }
    for c in counts where c.n > 0 {
        let k = c.kind, v = c.n, hw = c.hw
        let p = money(hw?.price)
        // rails and profiles by the whole metre, mirror and glass by the m² (to 0,01), the rest by the piece
        let area = AREA_KINDS.contains(k)
        let q = METRE_KINDS.contains(k) ? metres(Double(v) / 1000) : area ? (Double(v) / 10000 - 1e-9).rounded(.up) / 100 : Double(v)
        let amount = area ? roundHalfUp((p ?? 0) * Decimal(string: String(format: "%.2f", q))!) : (p ?? 0) * Decimal(Int(q.rounded(.up)))
        lines.append(CostLine(group: "hw", key: hw?.id ?? k, qty: q, unit: hwUnit(k), price: p ?? 0, amount: amount, missing: p == nil))
    }
    // cutting a remnant is as much work as a sheet
    let sheets = lays.reduce(0) { $0 + $1.sheets.count + $1.unplaced.count + $1.rems.count }
    let modules = fs.reduce(0) { a, f in a + f.modules.reduce(0) { $0 + ($1.type == "wardrobe" ? max(1, $1.sections.count) : 1) } }
    func lab(_ key: String, _ q: Double, _ unit: String, _ rate: String) {
        let r = money(rate) ?? 0
        if q > 0 { lines.append(CostLine(group: "lab", key: key, qty: q, unit: unit, price: r, amount: r * Decimal(Int(q.rounded())), missing: false)) }
    }
    lab("fc.cut", Double(sheets), "sheet", ws.rCut)
    lab("fc.band", metres(thick + thin), "m", ws.rBand)
    lab("fc.asm", Double(modules), "module", ws.rAsm)
    if order && fs.contains(where: { !$0.modules.isEmpty }) { lab("fc.install", 1, "order", ws.rInstall); lab("fc.deliver", 1, "order", ws.rDeliver) }
    return Cost(lines: lines, layouts: lays, rows: rows)
}

/// A hardware kind's count priced at one item (Kotlin's map keyed by kind and item, in the order first seen).
private struct HwCount { let kind: String; let hw: Hw?; var n: Int }

/// The item a hardware kind is priced at: the last of the kind (the workshop's own item added after the preset takes
/// over), but not one of the extra handle kinds offered for "Change for all".
func usualHw(_ hws: [Hw], _ kind: String) -> Hw? { hws.last { $0.kind == kind && !HANDLE_MORE.contains($0.id) } }

/// The customer price from the cost with the workshop's margin, rounded half up.
func withMargin(_ cost: Decimal, _ pct: Int) -> Decimal { roundHalfUp(cost * Decimal(100 + pct) / 100) }
