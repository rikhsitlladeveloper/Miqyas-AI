import Foundation

/*
 * The customer price of a furniture order (furniture plan section 6.7; Android furniture/Pricing.kt): the cost plus a
 * margin, kitchens by the running metre, or a price typed by hand. The cost is always worked out; the profit is the
 * maker's only.
 */

/// How the order is priced: mode "margin" (cost + pct %, the workshop's margin when nil), "run" (kitchens: the lower
/// row's running metres × rRun plus tall units × rTall; other furniture by the margin) or "fixed" (fixed). days to make
/// it and inst to install it, working days, for the customer's PDF.
struct FPrice: Codable, Equatable {
    var mode = "margin"
    var pct: Int? = nil
    var rRun = "4400000"
    var rTall = ""
    var fixed = ""
    var days = 18
    var inst = 1
    init() {}
    init(mode: String = "margin", pct: Int? = nil, rRun: String = "4400000", rTall: String = "", fixed: String = "", days: Int = 18, inst: Int = 1) {
        self.mode = mode; self.pct = pct; self.rRun = rRun; self.rTall = rTall; self.fixed = fixed; self.days = days; self.inst = inst
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        mode = c.v(.mode, "margin"); pct = c.v(.pct, nil); rRun = c.v(.rRun, "4400000"); rTall = c.v(.rTall, ""); fixed = c.v(.fixed, "")
        days = c.v(.days, 18); inst = c.v(.inst, 1)
    }
}

/// One line of the customer's price: key a furniture id, or "deliver" for delivery and installation.
struct PriceLine: Equatable { let key: String; let amount: Decimal }

/// The order's cost, the customer price (its lines; none when fixed), and the profit.
struct Priced {
    let cost: Cost, price: Decimal, lines: [PriceLine]
    var profit: Decimal { price - cost.total }
    /// Profit as tenths of a percent of the price (231 = 23,1 %).
    var profitPct10: Int {
        if price == 0 { return 0 }
        var x = profit * 1000 / price, r = Decimal()
        NSDecimalRound(&r, &x, 0, .plain)
        return NSDecimalNumber(decimal: r).intValue
    }
}

private func money(_ s: String) -> Decimal? {
    let t = s.replacingOccurrences(of: " ", with: "")
    guard !t.isEmpty, t.range(of: "^-?\\d+$", options: .regularExpression) != nil else { return nil }
    return Decimal(string: t)
}

private func roundHalfUp(_ x: Decimal) -> Decimal { var a = x, r = Decimal(); NSDecimalRound(&r, &a, 0, .plain); return r }

/// Running metres of a kitchen's lower rows, in millimetres.
func runMm(_ f: Furniture) -> Int { f.modules.filter { !isUpper($0) && $0.type != "tall" && !($0.type == "gap" && $0.app == "fridge") }.reduce(0) { $0 + $1.w } }

func priceOf(_ fs: [Furniture], _ fp: FPrice, _ ws: Workshop, _ mats: [Mat], _ hws: [Hw]) -> Priced {
    let cost = costOf(fs, ws, mats, hws)
    let pct = fp.pct ?? ws.margin
    let built = fs.filter { !$0.modules.isEmpty }
    // delivery and installation once an order, with the margin
    let orderLab = cost.lines.filter { $0.group == "lab" && ($0.key == "fc.install" || $0.key == "fc.deliver") }.reduce(Decimal(0)) { $0 + $1.amount }
    if fp.mode == "fixed" { return Priced(cost: cost, price: money(fp.fixed) ?? 0, lines: []) }
    var lines: [PriceLine] = built.map { f in
        if fp.mode == "run" && f.kind == "kitchen" {
            let run = roundHalfUp((money(fp.rRun) ?? 0) * Decimal(runMm(f)) / 1000)
            let talls = f.modules.filter { $0.type == "tall" }.count
            return PriceLine(key: f.id, amount: run + (money(fp.rTall) ?? 0) * Decimal(talls))
        }
        return PriceLine(key: f.id, amount: withMargin(costOf([f], ws, mats, hws, order: false).total, pct))
    }
    if orderLab > 0 { lines.append(PriceLine(key: "deliver", amount: withMargin(orderLab, pct))) }
    return Priced(cost: cost, price: lines.reduce(Decimal(0)) { $0 + $1.amount }, lines: lines)
}
