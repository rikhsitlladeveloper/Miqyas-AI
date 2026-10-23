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

/// The cost of fs with this workshop's settings and lists. order adds installation and delivery once (an order with
/// furniture in it). The store's remnants rems are cut first: only the new sheets are bought.
func costOf(_ fs: [Furniture], _ ws: Workshop, _ mats: [Mat], _ hws: [Hw], order: Bool = true, rems: [Remnant] = []) -> Cost {
    let rows = cutList(fs, ws)
    let lays = layouts(rows, mats, ws, rems)
    var lines: [CostLine] = []
    func mat(_ id: String) -> Mat? { mats.first { $0.id == id } }
    for l in lays {
        // a part longer than the sheet is not left out of the price: a sheet of its own each (bought longer or joined)
        let p = money(mat(l.mat)?.price), n = l.sheets.count + l.unplaced.count
        lines.append(CostLine(group: "mat", key: l.mat, qty: Double(n), unit: "sheet", price: p ?? 0, amount: (p ?? 0) * Decimal(n), missing: p == nil))
    }
    // kitchens: the worktop as one simple item by the running metre (plan section 7; joints and cut-outs in Stage 1b)
    var wtMm = fs.filter { $0.kind == "kitchen" }.reduce(0) { $0 + worktopRuns($1).values.reduce(0, +) }
    // a table's or bar counter's top of worktop board
    for f in fs { for m in f.modules { wtMm += itemWorktopMm(m) } }
    if wtMm > 0 {
        let p = money(mat("wt38")?.price)
        lines.append(CostLine(group: "mat", key: "wt38", qty: Double(wtMm) / 1000, unit: "m", price: p ?? 0,
                              amount: roundHalfUp((p ?? 0) * Decimal(wtMm) / 1000), missing: p == nil))
    }
    // the backsplash panel, by the running metre like the worktop
    let spMm = fs.filter { $0.kind == "kitchen" && ($0.kx?.splash ?? 0) > 0 }.reduce(0) { $0 + splashMm($1) }
    if spMm > 0 {
        let sp = mats.first { $0.kind == "splash" }
        let p = money(sp?.price)
        lines.append(CostLine(group: "mat", key: sp?.id ?? "splash6", qty: Double(spMm) / 1000, unit: "m", price: p ?? 0,
                              amount: roundHalfUp((p ?? 0) * Decimal(spMm) / 1000), missing: p == nil))
    }
    let (thick, thin) = bandMetres(rows)
    for (id, m) in [("band2", thick), ("band04", thin)] where m > 0 {
        let q = metres(m), p = money(mat(id)?.price)
        lines.append(CostLine(group: "mat", key: id, qty: q, unit: "m", price: p ?? 0, amount: (p ?? 0) * Decimal(Int(q)), missing: p == nil))
    }
    // handles of a kind chosen for a piece ("Change for all") are priced at that item, the rest at the usual one
    var counts: [HwCount] = hardware(fs, ws).pairs.map { HwCount(kind: $0.0, hw: usualHw(hws, $0.0), n: $0.1) }
    let usualHandle = usualHw(hws, "handle")
    for f in fs {
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
