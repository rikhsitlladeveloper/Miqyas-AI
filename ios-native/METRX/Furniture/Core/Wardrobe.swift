import Foundation

/*
 * Wardrobe design rules (furniture plan section 8; design canvas screen 11; Android furniture/Wardrobe.kt;
 * WardrobeTests).
 *
 * A wardrobe is one module of type "wardrobe" on a wall: Module.x from the wall's start corner, its carcass split into
 * sections. Inside each section, shelves and rails are lines at a height; drawers, pull-out racks and the lift are
 * blocks. Heights are from the section's floor (the top of the bottom panel).
 */

/// Gaps left to the walls and the ceiling when the wardrobe fills a niche.
let W_GAP_SIDE = 10
let W_GAP_TOP = 20
let W_DEPTH = 600

/// How tall an insert is: blocks have a height (Insert.h, or their usual one); shelves and rails are lines (0).
func blockH(_ x: Insert) -> Int {
    switch x.kind {
    case "drawer": return x.h > 0 ? x.h : 200
    case "trouser": return x.h > 0 ? x.h : 120
    case "shoe": return x.h > 0 ? x.h : 140
    case "lift": return x.h > 0 ? x.h : 800
    default: return 0
    }
}

/// Section widths: locked ones keep theirs; the others share what is left equally, the last one takes the remainder.
func splitSections(_ w: Int, _ secs: [Section]) -> [Section] {
    let free = secs.filter { !$0.lock }.count
    if free == 0 { return secs }
    let rest = w - secs.filter(\.lock).reduce(0) { $0 + $1.w }
    let each = rest / free
    var k = 0
    return secs.map { s in
        if s.lock { return s }
        k += 1
        var n = s; n.w = each + (k == free ? rest - each * free : 0); return n
    }
}

/// About 600 mm a section: 2400 → 4, 1200 → 2, 700 → 1.
func sectionsFor(_ w: Int) -> Int { max(1, (w + 300) / 600) }

/// A stable sort by height (Kotlin's sortedBy).
private func byPos(_ xs: [Insert]) -> [Insert] { xs.enumerated().sorted { ($0.element.pos, $0.offset) < ($1.element.pos, $1.offset) }.map(\.element) }

/// Shelves evenly between the blocks at the bottom (and above any rail) and the top.
func spreadShelves(_ s: Section, _ ih: Int, _ t: Int) -> Section {
    let n = s.inserts.filter { $0.kind == "shelf" }.count
    if n == 0 { return s }
    let others = s.inserts.filter { $0.kind != "shelf" }
    let blocks = others.filter { blockH($0) > 0 && $0.kind != "lift" }.map { $0.pos + blockH($0) }.max() ?? 0
    let rails = others.filter { $0.kind == "rail" }.map { $0.pos + 60 }.max() ?? 0
    let lo = max(blocks, rails)
    let top = others.filter { $0.kind == "lift" }.map(\.pos).min() ?? (ih - t)
    let step = (top - lo) / (n + 1)
    var out = s; out.inserts = byPos(others + (1...n).map { Insert("shelf", pos: lo + step * $0) })
    return out
}

/// Where a new insert of kind goes in a section ih high inside.
func nextPos(_ kind: String, _ s: Section, _ ih: Int, _ t: Int) -> Int {
    let ins = s.inserts
    let pos: Int
    switch kind {
    case "drawer", "trouser", "shoe": pos = ins.filter { blockH($0) > 0 && $0.kind != "lift" }.map { $0.pos + blockH($0) }.max() ?? 0
    case "rail": pos = ins.filter { $0.kind == "shelf" }.map { $0.pos - 60 }.max() ?? (ih - 80)
    case "lift": pos = ih - blockH(Insert("lift")) - 20
    default:
        // the middle of the tallest free space
        var edges = [(0, 0), (ih, ih)]
        for x in ins { edges.append((x.pos, x.pos + max(blockH(x), x.kind == "shelf" ? t : 0))) }
        let sorted = edges.enumerated().sorted { ($0.element.0, $0.offset) < ($1.element.0, $1.offset) }.map(\.element)
        var best = (0, 0)
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i].1, b = sorted[i + 1].0
            if b - a > best.1 - best.0 { best = (a, b) }
        }
        pos = (best.0 + best.1) / 2
    }
    return min(max(pos, 0), max(0, ih - max(blockH(Insert(kind)), t)))
}

/* ---------------- sliding doors (plan 1b-2) ---------------- */

/// How far one sliding door overlaps the next, mm.
let SLIDE_OV = 30
/// The depth the two tracks take in front of the shelves, mm: shelves, dividers and drawers are this much shallower.
let SLIDE_D = 100
/// The profile frame round a door's filling: each side, and top plus bottom together, mm.
let SLIDE_FRAME_W = 20
let SLIDE_FRAME_H = 70
/// Room for the rollers and the top track: a door is this much lower than the opening, mm.
let SLIDE_CLEAR = 40

/// Doors for a front w wide: 2 up to 1600, 3 up to 2600, then 4.
func slideDoorsFor(_ w: Int) -> Int { w <= 1600 ? 2 : w <= 2600 ? 3 : 4 }

/// The opening the doors close: between the sides (or the walls) and between the bottom and top panels.
func slideOpening(_ m: Module, _ t: Int) -> (Int, Int) { (m.w - (m.sideL ? t : 0) - (m.sideR ? t : 0), m.h - wardBase(m) - 2 * t) }

/// One sliding door, width × height: the opening shared out with the overlaps, less the clearance.
func slideDoor(_ m: Module, _ t: Int) -> (Int, Int) {
    let n = min(4, max(2, m.slide?.n ?? 2))
    let (ow, oh) = slideOpening(m, t)
    return ((ow + (n - 1) * SLIDE_OV) / n, oh - SLIDE_CLEAR)
}

/// A door's filling inside its frame, width × height.
func slidePanel(_ m: Module, _ t: Int) -> (Int, Int) { let (w, h) = slideDoor(m, t); return (w - 2 * SLIDE_FRAME_W, h - SLIDE_FRAME_H) }

/// How deep a sliding wardrobe's shelves, dividers and drawers are.
func innerD(_ m: Module) -> Int { m.slide != nil ? m.d - SLIDE_D : m.d }

/// A new wardrobe w × h on wall at x: built in (no sides at the walls) or free-standing, on a plinth.
func wardrobeTemplate(_ ws: Workshop, _ wall: String, _ x: Int, _ w: Int, _ h: Int, builtIn: Bool, d: Int = W_DEPTH) -> Module {
    let n = sectionsFor(w)
    var base = Module(id: uid(), type: "wardrobe", w: w, h: h, d: d, x: x, wall: wall, legs: false, sideL: !builtIn, sideR: !builtIn)
    let ih = wardInnerH(base, ws.t)
    base.sections = splitSections(w, Array(repeating: Section(0), count: n)).enumerated().map { i, s in
        var n = s; n.fronts = Fronts("door", s.w >= 600 ? 2 : 1)
        if i % 2 == 0 { n.inserts = [Insert("rail", pos: ih - 420), Insert("shelf", pos: ih - 350)]; return n }
        n.inserts = Array(repeating: Insert("shelf"), count: 5)
        return spreadShelves(n, ih, ws.t)
    }
    return base
}

/// The whole height from the floor: on legs the carcass is Workshop.legH up.
func outerH(_ m: Module, _ ws: Workshop) -> Int { m.h + (m.legs ? ws.legH : 0) }

/// What is wrong with wardrobe m on its wall (wallL long, the room roomH high), with the wall's openings and points.
/// Section findings carry "s", the section's number from 1.
func wardrobeChecks(_ m: Module, _ wallL: Int?, _ roomH: Int?, _ ws: Workshop, _ openings: [Opening], _ points: [SitePoint]) -> [FCheck] {
    var out: [FCheck] = []
    let t = ws.t, H = outerH(m, ws)
    if let wallL, m.x + m.w > wallL { out.append(FCheck(level: "err", key: "wc.wide", vars: ["v": m.x + m.w - wallL], mid: m.id)) }
    if let roomH, H > roomH { out.append(FCheck(level: "err", key: "wc.high", vars: ["v": H - roomH], mid: m.id)) }
    let sum = m.sections.reduce(0) { $0 + $1.w }
    if !m.sections.isEmpty && sum != m.w { out.append(FCheck(level: "err", key: "wc.sum", vars: ["v": sum, "w": m.w], mid: m.id)) }
    for o in openings where o.wall == m.wall && o.off < m.x + m.w && o.off + o.w > m.x && o.sill < H {
        out.append(FCheck(level: o.type == "door" ? "err" : "warn", key: o.type == "door" ? "kc.door" : "kc.window", mid: m.id))
    }
    for p in points where p.wall == m.wall {
        let (pw, ph) = pointSize(p)
        guard p.off + pw / 2 > m.x && p.off - pw / 2 < m.x + m.w && p.h - ph / 2 < H else { continue }
        switch p.t {
        case "meter": out.append(FCheck(level: "err", key: "kc.meter", mid: m.id))
        case "socket", "switch": out.append(FCheck(level: "warn", key: "kc.socket", vars: ["o": p.off, "h": p.h, "t": p.t], mid: m.id))
        default: break
        }
    }
    let ih = wardInnerH(m, t)
    // sliding doors: a door wider than 1100 or narrower than 500 runs badly
    if let sl = m.slide {
        let (dw, _) = slideDoor(m, t)
        if dw > 1100 { out.append(FCheck(level: "warn", key: "wc.slideWide", vars: ["v": dw, "n": sl.n], mid: m.id)) }
        if dw < 500 { out.append(FCheck(level: "warn", key: "wc.slideNarrow", vars: ["v": dw, "n": sl.n], mid: m.id)) }
        if m.d < 450 + SLIDE_D { out.append(FCheck(level: "warn", key: "wc.slideShallow", vars: ["v": m.d - SLIDE_D], mid: m.id)) }
    }
    for (i, s) in m.sections.enumerated() {
        let n = i + 1
        let iw = wardInner(m, m.sections, i, t)
        if iw > 1000 && s.inserts.contains(where: { $0.kind == "shelf" }) { out.append(FCheck(level: "warn", key: "wc.shelfWide", vars: ["s": n, "v": iw], mid: m.id)) }
        if m.slide == nil, s.fronts.kind == "door", let fw = frontSizes(s.fronts, s.w, m.h - wardBase(m), ws).map(\.1).max(), fw > 600 {
            out.append(FCheck(level: "warn", key: "wc.doorWide", vars: ["s": n, "v": fw], mid: m.id))
        }
        // inside: everything within the section, blocks apart, room under the rails to hang clothes
        let spans = s.inserts.enumerated().map { (k, x) in (k: k, x: x, a: x.pos, b: x.pos + max(blockH(x), x.kind == "shelf" ? t : 0)) }
        if spans.contains(where: { $0.a < 0 || $0.b > ih }) { out.append(FCheck(level: "err", key: "wc.out", vars: ["s": n], mid: m.id)) }
        let blocks = spans.filter { blockH($0.x) > 0 }
        if spans.contains(where: { a in blocks.contains { b in a.k != b.k && a.a < b.b && b.a < a.b } }) {
            out.append(FCheck(level: "err", key: "wc.overlap", vars: ["s": n], mid: m.id))
        }
        for r in spans where r.x.kind == "rail" {
            let below = spans.filter { $0.k != r.k && $0.b <= r.x.pos }.map(\.b).max() ?? 0
            if r.x.pos - below < 900 { out.append(FCheck(level: "warn", key: "wc.hang", vars: ["s": n, "v": r.x.pos - below], mid: m.id)) }
        }
    }
    return out
}

/// The longest stretch of a wall len long that is clear of its doors (and of windows lower than h): start and length.
func freeSpan(_ len: Int, _ wall: String, _ openings: [Opening], _ h: Int) -> (Int, Int) {
    let blocks = openings.filter { $0.wall == wall && ($0.type == "door" || $0.sill < h) }.map { ($0.off, $0.off + $0.w) }
        .enumerated().sorted { ($0.element.0, $0.offset) < ($1.element.0, $1.offset) }.map(\.element)
    var best = (0, 0), at = 0
    for (a, b) in blocks + [(len, len)] { if a - at > best.1 { best = (at, a - at) }; at = max(at, b) }
    return best
}

/// Where a new wardrobe goes on a wall len long: the whole wall as a niche (built in, 10 mm from each wall), or the
/// longest stretch clear of doors and windows (free-standing, 10 mm from a wall, 50 mm from an opening).
func placeOn(_ len: Int, _ wall: String, _ openings: [Opening], _ h: Int) -> (x: Int, w: Int, builtIn: Bool) {
    let (a, n) = freeSpan(len, wall, openings, h)
    if a == 0 && n == len { return (W_GAP_SIDE, len - 2 * W_GAP_SIDE, true) }
    let g0 = a == 0 ? W_GAP_SIDE : 50, g1 = a + n == len ? W_GAP_SIDE : 50
    return (a + g0, max(300, n - g0 - g1), false)
}
