import Foundation

/*
 * Three price options for the customer (Joylan ideas, approved 26 Oct 2026; the mockup's tierO and priceOf; Android
 * furniture/PriceTiers.kt): the same drawing in three sets of materials, each priced by the usual Costing.
 *  - Ekonom: LDSP fronts (a wood decor stays), flat fronts, a bar for a Gola or a knob, chrome for gold and brass, the
 *    plain 38 mm HPL worktop (a wood one stays), the MDF wall panel behind the worktop, ordinary hinges, no LED or cornice;
 *  - Standart: as designed;
 *  - Premium: acrylic (a gloss design) or MDF enamel fronts, a stone worktop (quartz) and the same stone behind it,
 *    soft-close hardware, LED under the wall units.
 * Only in Advanced. The PDF shows all three when the order asks for it (Project.tri); the prices go into the quote as
 * price lines pt.eko, pt.std and pt.pre (Snap.flines), so a quote keeps them as they were. Plain Swift (PriceTiersTests).
 */

/// The tiers, in the order they are shown.
let PRICE_TIERS = ["eko", "std", "pre"]

/// The colour of a plain board (one that is not a decor) as the tiers see it.
private let TIER_PLAIN: [String: String] = ["ldsp16w": "white", "ldsp16mr": "white", "mdf18": "white", "ldsp16k": "cashmere", "ldsp18a": "graphite"]

/// The Ekonom front of board id: a wood decor as it is, a colour as the nearest LDSP (white, cashmere or anthracite);
/// another board stays.
func ekoBoard(_ id: String) -> String {
    if id.hasPrefix("wd_") { return id }
    guard let c = colourOf(id) ?? (id == "mdf18" ? "white" : nil) else { return id }
    switch c {
    case "cashmere": return "ldsp16k"
    case "graphite", "black", "navy", "olive": return "ldsp18a"
    default: return "ldsp16w"
    }
}

/// The Premium front of board id: a wood decor as it is, a colour as acrylic gloss (gloss) or MDF enamel.
func preBoard(_ id: String, gloss: Bool) -> String {
    if id.hasPrefix("wd_") { return id }
    guard let c = colourOf(id) ?? TIER_PLAIN[id] else { return id }
    return (gloss ? "ag_" : "en_") + c
}

/// Every box of f with soft-close hinges (on) or ordinary ones, a wardrobe's sections too.
private func tierSoft(_ f: Furniture, _ on: Bool) -> Furniture {
    var g = f
    g.modules = f.modules.map { m in
        var x = m
        x.soft = on
        x.sections = m.sections.map { s in var y = s; if y.soft != nil { y.soft = on }; return y }
        return x
    }
    return g
}

/// f in the materials of tier ("eko", "std", "pre"); the same boxes, sizes and places.
func tierFurniture(_ f: Furniture, _ tier: String) -> Furniture {
    if tier == "std" || f.modules.isEmpty { return f }
    let kitchen = f.kind == "kitchen"
    var g = f
    if tier == "eko" {
        g.mats.front = ekoBoard(f.mats.front)
        g.mats.frontUp = f.mats.frontUp.map(ekoBoard)
        if var l = f.look {
            l.preset = ""; l.style = "flat"
            if l.hcol == "gold" || l.hcol == "brass" { l.hcol = "chrome" }
            if l.crown == "cornice" { l.crown = "" }
            l.led = false; l.legs = false; l.fglass = false; l.waterfall = false
            g.look = l
        }
        let ht = handleType(f)
        if ht == "gola" || ht == "knob" { g = withHandleType(g, "bar") }
        if kitchen {
            g.mats.top = worktopKind(worktopOf(f)) == "wood" ? worktopOf(f) : "wt38"
            if (f.kx?.splash ?? 0) > 0 { g.mats.splash = "splash6" }
            if var k = g.kx { k.led = false; k.cornice = false; g.kx = k }
        }
        return tierSoft(g, false)
    }
    // Premium
    let gloss = f.look?.finish == "gloss" || f.mats.front.hasPrefix("ag_")
    g.mats.front = preBoard(f.mats.front, gloss: gloss)
    g.mats.frontUp = f.mats.frontUp.map { preBoard($0, gloss: gloss) }
    var l = f.look ?? PieceLook()
    l.preset = ""
    l.finish = gloss ? "gloss" : "matte"
    g.look = l
    if kitchen {
        let d = worktopDecor(worktopOf(f))
        let stone = d == "marble" || d == "onyx" || d == "dark" ? d : "onyx"
        let top = worktopFor("slim", stone)
        g.mats.top = top
        var k = g.kx ?? KExtras()
        if k.splash == 0 { k.splash = K_SPLASH }
        k.led = true
        g.kx = k
        g.mats.splash = top
    }
    return tierSoft(g, true)
}

/// A tier's price for the customer and what it costs the workshop.
struct TierPrice: Equatable {
    let tier: String
    let price: Decimal
    let cost: Decimal
}

private func tierHalfUp(_ x: Decimal) -> Decimal { var a = x, r = Decimal(); NSDecimalRound(&r, &a, 0, .plain); return r }

/// The three prices of fs: Standart is the order's price; the others the same way from their own cost (cost plus the
/// margin), or, when the order is priced by the running metre or by hand, Standart's price in proportion to their cost.
func tierPrices(_ fs: [Furniture], _ fp: FPrice, _ ws: Workshop, _ mats: [Mat], _ hws: [Hw], _ rems: [Remnant] = []) -> [TierPrice] {
    let built = fs.filter { !$0.modules.isEmpty }
    let std = priceOf(built, fp, ws, mats, hws, rems)
    var out: [TierPrice] = []
    for t in PRICE_TIERS {
        if t == "std" { out.append(TierPrice(tier: t, price: std.price, cost: std.cost.total)); continue }
        let tf = built.map { tierFurniture($0, t) }
        if fp.mode == "margin" {
            let p = priceOf(tf, fp, ws, mats, hws, rems)
            out.append(TierPrice(tier: t, price: p.price, cost: p.cost.total))
            continue
        }
        let c = costOf(tf, ws, mats, hws, rems: rems).total
        let base = std.cost.total
        let price = base > 0 ? tierHalfUp(std.price * c / base) : std.price
        out.append(TierPrice(tier: t, price: price, cost: c))
    }
    return out
}

/// The quote's price lines of the three tiers (keys pt.eko, pt.std, pt.pre), amounts as digits.
func tierLines(_ ps: [TierPrice]) -> [SnapLine] { ps.map { SnapLine(key: "pt." + $0.tier, amount: Money.digits($0.price)) } }

/// Whether a quote's price line is one of the tiers'.
func isTierLine(_ l: SnapLine) -> Bool { l.key.hasPrefix("pt.") }

/// A tier's difference from Standart, whole percent (Standart itself 0).
func tierPct(_ v: Decimal, _ std: Decimal) -> Int {
    guard std > 0 else { return 0 }
    let x = NSDecimalNumber(decimal: (v - std) * 100 / std).doubleValue
    return Int(x.rounded())
}

/// What a tier is made of, as the card and the PDF list it: the fronts' board, the worktop's, the backsplash's (ids;
/// nil for a piece without one) of the first piece of fs; the hardware's strings key; LED.
struct TierMats: Equatable {
    let front: String?
    let top: String?
    let splash: String?
    let hw: String
    let led: Bool
}

func tierMats(_ fs: [Furniture], _ tier: String) -> TierMats {
    let built = fs.filter { !$0.modules.isEmpty }
    let first = built.first { $0.kind == "kitchen" } ?? built.first
    guard let f0 = first else { return TierMats(front: nil, top: nil, splash: nil, hw: "pt.hw." + tier, led: false) }
    let f = tierFurniture(f0, tier)
    let kitchen = f.kind == "kitchen"
    let splash: String? = kitchen && (f.kx?.splash ?? 0) > 0 ? (f.mats.splash ?? "splash6") : nil
    return TierMats(front: f.mats.front, top: kitchen ? worktopOf(f) : nil, splash: splash, hw: "pt.hw." + tier, led: f.kx?.led == true)
}
