import Foundation

/*
 * The cut list (furniture plan section 6.4; Android furniture/CutList.kt): an order's parts by material, equal parts
 * added up, with the size to cut (the finished size less the thick banding on each banded edge) and the banding to buy.
 */

/// One cut list line: p the part (finished size), cutL × cutW what the saw cuts, mat the material id.
struct CutRow: Equatable { let p: FPart, mat: String, cutL: Int, cutW: Int }

/// Which material a role uses in a piece of furniture; upper fronts take a two-tone kitchen's upper board (FMats.frontUp).
func matFor(_ role: String, _ m: FMats, _ upper: Bool = false) -> String {
    role == "front" ? (upper ? m.frontUp ?? m.front : m.front) : role == "back" ? m.back : m.carcass
}

/// A piece's parts, each with whether it goes with the upper fronts (isUpperFront; the upper end panels too).
func partsWithUpper(_ f: Furniture, _ ws: Workshop) -> [(FPart, Bool)] {
    let fws = wsOf(f, ws)
    var out: [(FPart, Bool)] = []
    for m in f.modules {
        let up = isUpperFront(f, m)
        for p in partsOf(m, fws) { out.append((p, up)) }
    }
    for p in extrasParts(f, ws) { out.append((p, p.key == "fp.endUp")) }
    return out
}

private struct RowKey: Hashable { let mat: String; let p: FPart }

/// Every part of an order's furniture, equal ones (same part, size, banding and material) on one line.
func cutList(_ fs: [Furniture], _ ws: Workshop) -> [CutRow] {
    // in the order they first come, as Kotlin's LinkedHashMap keeps them
    var order: [RowKey] = []; var count: [RowKey: Int] = [:]
    for f in fs {
        // the upper end panels go with the upper fronts
        for (p, up) in partsWithUpper(f, ws) {
            var q = p; q.mod = ""; q.qty = 0
            let k = RowKey(mat: matFor(p.role, f.mats, up), p: q)
            if count[k] == nil { order.append(k) }
            count[k, default: 0] += p.qty
        }
    }
    let off = ws.bandOff ? ws.band10 : 0
    func less(_ a: Int, _ e1: Int, _ e2: Int) -> Int { (a * 10 - (e1 == 2 ? off : 0) - (e2 == 2 ? off : 0)) / 10 }
    let rows: [CutRow] = order.map { k in
        var p = k.p; p.qty = count[k]!
        // thick banding on the short edges shortens the length; on the long edges it narrows the width
        return CutRow(p: p, mat: k.mat, cutL: less(p.L, p.bands.s1, p.bands.s2), cutW: less(p.W, p.bands.l1, p.bands.l2))
    }
    // a stable sort: by material, then the longest and widest first
    return rows.enumerated().sorted { a, b in
        let x = a.element, y = b.element
        if x.mat != y.mat { return x.mat < y.mat }
        if x.p.L != y.p.L { return x.p.L > y.p.L }
        if x.p.W != y.p.W { return x.p.W > y.p.W }
        return a.offset < b.offset
    }.map(\.element)
}

/// Banding to buy, metres of thick and of thin: every banded edge plus 30 mm for trimming.
func bandMetres(_ rows: [CutRow]) -> (thick: Double, thin: Double) {
    var thick = 0, thin = 0
    for r in rows {
        let b = r.p.bands
        func add(_ code: Int, _ len: Int) { let mm = (len + 30) * r.p.qty; if code == 2 { thick += mm } else if code == 1 { thin += mm } }
        add(b.l1, r.p.L); add(b.l2, r.p.L); add(b.s1, r.p.W); add(b.s2, r.p.W)
    }
    return (Double(thick) / 1000, Double(thin) / 1000)
}
