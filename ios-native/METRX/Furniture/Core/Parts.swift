import Foundation

/*
 * The parts generator (furniture plan section 6.3; Android furniture/Parts.kt): every board of a module with its
 * finished size, banding and material role. The expected sizes are in furniture-cases.json, shared with Android.
 *
 * Construction (section 6.2): sides stand on the bottom; base units have two 100 mm rails instead of a top; wall, tall
 * and wardrobe carcasses have a top and a bottom between the sides; the back is nailed on 2 mm in from each edge (or
 * sits in 8 mm grooves); fronts leave a gap between them and at the outer edges. A wardrobe on a plinth has its
 * bottom on the plinth; doors, dividers and backs start from it.
 */

/// Banding on a part's two long edges and two short edges: 0 none, 1 thin, 2 thick.
struct Bands: Equatable, Hashable {
    var l1 = 0, l2 = 0, s1 = 0, s2 = 0
    var any: Bool { l1 + l2 + s1 + s2 > 0 }
}

/// One kind of part: key its name's strings key, mod the module it belongs to, role carcass, front or back; L × W
/// the finished size, L the longer side (along the grain for fronts); qty how many.
struct FPart: Equatable, Hashable {
    var key: String, mod: String, role: String
    var L: Int, W: Int, qty: Int
    var bands = Bands()
    var grain = false
}

/// A part from two sizes and the banding of the edges that run along each: normalised so L is the longer one.
func part(_ key: String, _ mod: String, _ role: String, _ a: Int, _ b: Int, _ qty: Int, _ ea: (Int, Int) = (0, 0), _ eb: (Int, Int) = (0, 0), grain: Bool = false) -> FPart {
    grain || a >= b ? FPart(key: key, mod: mod, role: role, L: a, W: b, qty: qty, bands: Bands(l1: ea.0, l2: ea.1, s1: eb.0, s2: eb.1), grain: grain)
                    : FPart(key: key, mod: mod, role: role, L: b, W: a, qty: qty, bands: Bands(l1: eb.0, l2: eb.1, s1: ea.0, s2: ea.1), grain: grain)
}

private let RAIL = 100
/// The plinth under a wardrobe without legs: the bottom panel sits on it, the sides go down to the floor.
let PLINTH = 80
let THICK = (2, 0)
let ALL = (2, 2)
let THIN = 1

/// Where a wardrobe's inside starts: the plinth, or nothing on legs.
func wardBase(_ m: Module) -> Int { m.legs ? 0 : (m.base ?? PLINTH) }

/// How high a wardrobe's legs lift it: its own, or the workshop's; none on a plinth.
func legsOf(_ m: Module, _ ws: Workshop) -> Int { m.legs ? (m.base ?? ws.legH) : 0 }

/// Section i's width between its side or dividers (a divider takes half of t from each side, a missing side nothing).
func wardInner(_ m: Module, _ secs: [Section], _ i: Int, _ t: Int) -> Int {
    let s = secs[i]
    let left = i == 0 ? (m.sideL ? t * 10 : 0) : t * 5
    let right = i == secs.count - 1 ? (m.sideR ? t * 10 : 0) : t * 5
    return (s.w * 10 - left - right) / 10
}

/// A wardrobe section's inside height: between the bottom and the top panels.
func wardInnerH(_ m: Module, _ t: Int) -> Int { m.h - wardBase(m) - 2 * t }

/// The runner length for a box d deep: 50 mm steps, 300 to 600.
func runnerLen(_ d: Int) -> Int { min(600, max(300, (d - 10) / 50 * 50)) }

/// Hinges on a door by its height (furniture plan section 6.6): up to 900 → 2, 1600 → 3, 2000 → 4, more → 5.
func hingesFor(_ h: Int) -> Int { h <= 900 ? 2 : h <= 1600 ? 3 : h <= 2000 ? 4 : 5 }

/// The fronts of an opening w × h wide: doors side by side, drawers and appliance panels one above the other; sizes
/// (height, width) in whole mm.
func frontSizes(_ f: Fronts, _ w: Int, _ h: Int, _ ws: Workshop) -> [(Int, Int)] {
    if f.kind == "open" || f.n <= 0 { return [] }
    let n = f.n
    if f.kind == "drawer" || f.kind == "panel" {
        let each = (h * 10 - 2 * ws.edge10 - (n - 1) * ws.gap10) / n / 10
        return Array(repeating: (each, (w * 10 - 2 * ws.edge10) / 10), count: n)
    }
    let each = (w * 10 - 2 * ws.edge10 - (n - 1) * ws.gap10) / n / 10
    return Array(repeating: ((h * 10 - 2 * ws.edge10) / 10, each), count: n)
}

/// A drawer's box behind a front fh high in an opening iw wide (between the sides) and d deep: sides, front and back, bottom.
func drawerBox(_ mod: String, _ iw: Int, _ d: Int, _ fh: Int, _ t: Int) -> [FPart] {
    let rl = runnerLen(d)
    let bh = min(150, max(80, fh - 40))
    let inner = iw - 26                       // 13 mm runner clearance each side
    return [
        part("fp.dSide", mod, "carcass", rl, bh, 2, (THIN, 0)),
        part("fp.dFront", mod, "carcass", inner - 2 * t, bh - 10, 2, (THIN, 0)),
        part("fp.dBottom", mod, "back", inner, rl - 2, 1)
    ]
}

private func backPanel(_ mod: String, _ w: Int, _ h: Int, _ ws: Workshop) -> FPart {
    ws.back == "groove" ? part("fp.back", mod, "back", h - 2 * ws.t + 16, w - 2 * ws.t + 16, 1) : part("fp.back", mod, "back", h - 4, w - 4, 1)
}

/// Fronts: doors and panels with the grain upright (length = height), drawer faces with it across (length = width); glass doors are bought, not cut.
private func fronts(_ mod: String, _ f: Fronts, _ w: Int, _ h: Int, _ ws: Workshop, _ face: String = "") -> [FPart] {
    if face == "glass" && f.kind == "door" { return [] }
    // equal sizes counted, in the order they first come (Kotlin's groupingBy)
    var order: [[Int]] = []; var count: [[Int]: Int] = [:]
    for (a, b) in frontSizes(f, w, h, ws) { let k = [a, b]; if count[k] == nil { order.append(k) }; count[k, default: 0] += 1 }
    return order.map { sz in
        let n = count[sz]!
        return f.kind == "drawer" ? part("fp.dFace", mod, "front", sz[1], sz[0], n, ALL, ALL, grain: true)
                                  : part(f.kind == "panel" ? "fp.panel" : "fp.door", mod, "front", sz[0], sz[1], n, ALL, ALL, grain: true)
    }
}

/// All parts of one module.
func partsOf(_ m: Module, _ ws: Workshop) -> [FPart] {
    let t = ws.t, id = m.label.isEmpty ? m.id : m.label
    var out: [FPart] = []
    func shelves(_ iw: Int, _ d: Int, _ ins: [Insert]) {
        let n = ins.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty }
        if n > 0 { out.append(part("fp.shelf", id, "carcass", iw - 2, d - 20, n, THICK)) }
    }
    switch m.type {
    case "gap": out += fronts(id, m.fronts, m.w, m.h, ws)
    case "filler": out.append(part("fp.filler", id, "front", m.h, m.w, 1, ALL, ALL, grain: true))
    case _ where ITEM_MODS.contains(m.type): out += itemParts(m, ws)
    case "wardrobe":
        let secs = m.sections.isEmpty ? [Section(m.w)] : m.sections
        let base = wardBase(m)
        let sides = (m.sideL ? 1 : 0) + (m.sideR ? 1 : 0)
        let inW = m.w - sides * t
        if sides > 0 { out.append(part("fp.side", id, "carcass", m.h, m.d, sides, THICK)) }
        let dIn = innerD(m)
        if !secs.contains(where: \.knee) {
            out.append(part("fp.top", id, "carcass", inW, m.d, 2, THICK))
            if secs.count > 1 { out.append(part("fp.divider", id, "carcass", m.h - base - 2 * t, dIn, secs.count - 1, THICK)) }
        } else {
            // a desk: the top over everything, a bottom under each section but the knee space; a divider beside the knee
            // space goes down to the floor like a side
            out.append(part("fp.top", id, "carcass", inW, m.d, 1, THICK))
            for (i, s) in secs.enumerated() where !s.knee { out.append(part("fp.bottom", id, "carcass", wardInner(m, secs, i, t), m.d, 1, THICK)) }
            for i in 1..<max(1, secs.count) {
                let toFloor = secs[i].knee || secs[i - 1].knee
                out.append(part("fp.divider", id, "carcass", toFloor ? m.h - t : m.h - base - 2 * t, toFloor ? m.d : dIn, 1, THICK))
            }
        }
        if !m.legs && wardBase(m) > 0 { out.append(part("fp.plinth", id, "carcass", inW, wardBase(m), 1, THICK)) }
        for (i, s) in secs.enumerated() {
            let iw = wardInner(m, secs, i, t)
            let sid = "\(id)/\(i + 1)"
            if s.knee { continue }
            out.append(backPanel(sid, s.w, m.h - base, ws))
            let n = s.inserts.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty }
            if n > 0 { out.append(part("fp.shelf", sid, "carcass", iw - 2, dIn - 20, n, THICK)) }
            for dr in s.inserts where dr.kind == "drawer" {
                let fh = dr.h > 0 ? dr.h : 200
                // behind doors a drawer's face is carcass board; in an open section it is seen, so front board
                let open = s.fronts.kind == "open"
                out.append(part("fp.dFace", sid, open ? "front" : "carcass", iw - 4, fh, 1, ALL, ALL, grain: open))
                out += drawerBox(sid, iw, dIn, fh, t)
            }
            // sliding doors close the whole front; the sections have none of their own
            if m.slide == nil { out += fronts(sid, s.fronts, frontW(s), m.h - base, ws, s.face) }
        }
        // the board fillings of the sliding doors (mirror and glass are bought by the m², in the hardware list)
        if let sl = m.slide {
            let (pw, ph) = slidePanel(m, t)
            let boards = (0..<min(4, max(2, sl.n))).filter { sl.panel($0) == "ldsp" }.count
            if boards > 0 { out.append(part("fp.slidePanel", id, "front", ph, pw, boards, grain: true)) }
        }
    case "base":
        out.append(part("fp.bottom", id, "carcass", m.w, m.d, 1, THICK))
        out.append(part("fp.side", id, "carcass", m.h - t, m.d, 2, THICK))
        out.append(part("fp.rail", id, "carcass", m.w - 2 * t, RAIL, 2, (THIN, 0)))
        shelves(m.w - 2 * t, m.d, m.inserts)
        out.append(backPanel(id, m.w, m.h, ws))
        out += fronts(id, m.fronts, m.w, m.h, ws)
        if m.fronts.kind == "drawer" { for (fh, _) in frontSizes(m.fronts, m.w, m.h, ws) { out += drawerBox(id, m.w - 2 * t, m.d, fh, t) } }
    default:   // wall and tall
        out.append(part("fp.side", id, "carcass", m.h, m.d, 2, THICK))
        out.append(part("fp.top", id, "carcass", m.w - 2 * t, m.d, 2, THICK))
        shelves(m.w - 2 * t, m.d, m.inserts)
        out.append(backPanel(id, m.w, m.h, ws))
        out += fronts(id, m.fronts, m.w, m.h, ws)
        if m.fronts.kind == "drawer" { for (fh, _) in frontSizes(m.fronts, m.w, m.h, ws) { out += drawerBox(id, m.w - 2 * t, m.d, fh, t) } }
    }
    return mergeParts(out)
}

/// Equal parts of one module become one line with their counts added, in the order they first come.
func mergeParts(_ ps: [FPart]) -> [FPart] {
    var order: [FPart] = []; var count: [FPart: Int] = [:]
    for p in ps { var k = p; k.qty = 0; if count[k] == nil { order.append(k) }; count[k, default: 0] += p.qty }
    return order.map { var p = $0; p.qty = count[$0]!; return p }
}
