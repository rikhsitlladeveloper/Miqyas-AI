import Foundation

/*
 * Kitchen design rules (furniture plan section 7; design canvas screens 7–9; Android furniture/Kitchen.kt; KitchenTests).
 *
 * A kitchen runs along one to three walls of its room (or a wall and an island). On each wall the modules form two rows:
 * the lower row (base and tall units, appliance gaps, fillers) and the upper row (wall units). Each row is packed from
 * its start: the first wall from its start corner, every next wall after the corner unit of the wall before it.
 * Elevations are seen from inside the room, x from the wall's start corner, as in the wall view.
 */

let K_BASE_H = 720
let K_BASE_D = 560
let K_TOP = 38
let K_WALL_H = 720
let K_WALL_D = 300
/// Worktop to the underside of the wall units.
let K_SPLASH = 600
/// Where the next wall's lower and upper rows start, past the corner unit of the wall before.
let K_CORNER = 600
let K_UP_CORNER = 320
let ISLAND = "island"

func worktopTop(_ ws: Workshop) -> Int { ws.legH + K_BASE_H + K_TOP }
func wallElev(_ ws: Workshop) -> Int { worktopTop(ws) + K_SPLASH }

/// The upper row: wall units, and fillers or gaps hung at wall-unit height.
func isUpper(_ m: Module) -> Bool { m.type == "wall" || ((m.type == "filler" || m.type == "gap") && m.elev >= 1000) }

/// A run of one wall: its length (nil: the island, no limit) and where the lower and upper rows may start.
struct Run: Equatable { let wall: String, len: Int?, lowStart: Int, upStart: Int }

func runsOf(_ f: Furniture, _ wallLen: (String) -> Int?) -> [Run] {
    f.walls.enumerated().map { i, w in
        if w == ISLAND { return Run(wall: w, len: nil, lowStart: 0, upStart: 0) }
        let afterWall = i > 0 && f.walls[i - 1] != ISLAND
        return Run(wall: w, len: wallLen(w), lowStart: afterWall ? K_CORNER : 0, upStart: afterWall ? K_UP_CORNER : 0)
    }
}

/// Every module's x: packed one after another along its run and row, in the order of Furniture.modules.
func pack(_ f: Furniture, _ runs: [Run]) -> Furniture {
    var next: [String: Int] = [:]
    for r in runs { next[r.wall + ":low"] = r.lowStart; next[r.wall + ":up"] = r.upStart }
    var g = f
    g.modules = f.modules.map { m in
        let k = (m.wall ?? "") + (isUpper(m) ? ":up" : ":low")
        let x = next[k] ?? 0
        next[k] = x + m.w
        var n = m; n.x = x; return n
    }
    return g
}

/// How full a row is: the modules' widths and the room it has (nil: no limit).
struct Fill: Equatable {
    let used: Int, avail: Int?
    var left: Int? { avail.map { $0 - used } }
}

func fillOf(_ f: Furniture, _ r: Run, _ upper: Bool) -> Fill {
    let used = f.modules.filter { $0.wall == r.wall && isUpper($0) == upper }.reduce(0) { $0 + $1.w }
    return Fill(used: used, avail: r.len.map { $0 - (upper ? r.upStart : r.lowStart) })
}

/* ---------------- the module library ---------------- */

/// Library kinds, by group: lower storage, upper storage, tall, appliances.
let LIB_LOW = ["base", "drawers", "sink", "hob"]
let LIB_UP = ["wall", "open", "hood", "micro"]
let LIB_TALL = ["pantry", "oven", "fridgeB"]
let LIB_APP = ["dishwasher", "fridge"]

/// A new module of kind on wall, w wide (its usual width when nil).
func template(_ kind: String, _ ws: Workshop, _ wall: String, _ w: Int? = nil) -> Module {
    let low = ws.legH, up = wallElev(ws)
    func base(_ width: Int, _ f: Fronts, _ ins: [Insert], _ app: String = "") -> Module {
        Module(id: uid(), type: "base", w: width, h: K_BASE_H, d: K_BASE_D, wall: wall, elev: low, fronts: f, inserts: ins, app: app)
    }
    func wallU(_ width: Int, _ h: Int, _ el: Int, _ f: Fronts, _ ins: [Insert], _ app: String = "") -> Module {
        Module(id: uid(), type: "wall", w: width, h: h, d: K_WALL_D, wall: wall, elev: el, fronts: f, inserts: ins, legs: false, app: app)
    }
    // tall units end level with the wall units' tops
    func tall(_ width: Int, _ f: Fronts, _ ins: [Insert], _ app: String = "") -> Module {
        Module(id: uid(), type: "tall", w: width, h: up + K_WALL_H - low, d: K_BASE_D, wall: wall, elev: low, fronts: f, inserts: ins, app: app)
    }
    func plain(_ type: String, _ width: Int, _ h: Int, _ d: Int, _ el: Int, _ f: Fronts, _ app: String = "") -> Module {
        Module(id: uid(), type: type, w: width, h: h, d: d, wall: wall, elev: el, fronts: f, legs: false, app: app)
    }
    func doors(_ width: Int) -> Fronts { Fronts("door", width >= 500 ? 2 : 1) }
    switch kind {
    case "drawers": return base(w ?? 600, Fronts("drawer", 3), [])
    case "sink": let x = w ?? 800; return base(x, doors(x), [], "sink")
    case "hob": return base(w ?? 600, Fronts("drawer", 3), [], "hob")
    case "wall": let x = w ?? 600; return wallU(x, K_WALL_H, up, doors(x), [Insert("shelf", qty: 2)])
    case "open": return wallU(w ?? 600, K_WALL_H, up, Fronts("open", 0), [Insert("shelf", qty: 1)])
    // the hood's cabinet ends level with the wall units, its visor 750 over the worktop
    case "hood": return wallU(w ?? 600, K_SPLASH + K_WALL_H - 750, worktopTop(ws) + 750, Fronts("door", 1), [], "hood")
    // the microwave's niche at the bottom of a wall unit of the usual height, a shelf over it
    case "micro": return wallU(w ?? 600, K_WALL_H, up, Fronts("open", 0), [Insert("shelf", qty: 1)], "micro")
    case "pantry": let x = w ?? 600; return tall(x, doors(x), [Insert("shelf", qty: 5)])
    case "oven": return tall(w ?? 600, Fronts("door", 1), [Insert("shelf", qty: 2)], "oven")
    case "fridgeB": return tall(w ?? 600, Fronts("panel", 2), [], "fridgeB")
    case "dishwasher": return plain("gap", w ?? 600, K_BASE_H, K_BASE_D, low, Fronts("panel", 1), "dishwasher")
    case "fridge": return plain("gap", w ?? 600, 2000, 650, 0, Fronts("open", 0), "fridge")
    case "fillerLow": return plain("filler", w ?? 50, K_BASE_H, 20, low, Fronts("open", 0))
    case "fillerUp": return plain("filler", w ?? 50, K_WALL_H, 20, up, Fronts("open", 0))
    case "spaceUp": return plain("gap", w ?? 600, K_WALL_H, K_WALL_D, up, Fronts("open", 0))
    // an empty stretch of the lower row: no boards, no worktop, not in the running metres
    case "spaceLow": return plain("gap", w ?? 600, K_BASE_H, K_BASE_D, low, Fronts("open", 0), "space")
    default: let x = w ?? 600; return base(x, doors(x), [Insert("shelf", qty: 1)])
    }
}

/// The library kind a module was made from, for its name.
func kindOf(_ m: Module) -> String {
    if m.app == "space" { return "spaceLow" }
    if !m.app.isEmpty { return m.app }
    if m.type == "base" && m.fronts.kind == "drawer" { return "drawers" }
    if m.type == "wall" && m.fronts.kind == "open" { return "open" }
    if m.type == "tall" { return "pantry" }
    if m.type == "filler" { return isUpper(m) ? "fillerUp" : "fillerLow" }
    if m.type == "gap" { return "spaceUp" }
    return m.type
}

/// Fills the empty rows of every wall: 600 mm units, the last one narrower (from 300) or a filler; the unit over the
/// cold water becomes the sink and the one at the gas pipe the hob. Upper units over a window leave a space.
func autoFill(_ f: Furniture, _ runs: [Run], _ ws: Workshop, _ openings: [Opening], _ points: [SitePoint]) -> Furniture {
    var added: [Module] = []
    func slots(_ avail: Int) -> [Int] {
        let n = max(0, avail / 600), rem = avail - n * 600
        return Array(repeating: 600, count: n) + (rem > 0 ? [rem] : [])
    }
    for r in runs where r.wall != ISLAND && r.len != nil {
        let hasLow = f.modules.contains { $0.wall == r.wall && !isUpper($0) }
        let hasUp = f.modules.contains { $0.wall == r.wall && isUpper($0) }
        if !hasLow {
            var x = r.lowStart
            let water = points.first { $0.wall == r.wall && ($0.t == "cold" || $0.t == "sewer") }
            let gas = points.first { $0.wall == r.wall && $0.t == "gas" }
            var sink = false, hob = false
            for w in slots(r.len! - r.lowStart) {
                func inside(_ p: SitePoint?) -> Bool { guard let p else { return false }; return p.off >= x && p.off < x + w }
                if w < 300 { added.append(template("fillerLow", ws, r.wall, w)) }
                else if !sink && inside(water) { sink = true; added.append(template("sink", ws, r.wall, w)) }
                else if !hob && inside(gas) { hob = true; added.append(template("hob", ws, r.wall, w)) }
                else { added.append(template("base", ws, r.wall, w)) }
                x += w
            }
        }
        if !hasUp {
            var x = r.upStart
            let up0 = wallElev(ws), up1 = up0 + K_WALL_H
            for w in slots(r.len! - r.upStart) {
                let window = openings.contains { o in
                    o.wall == r.wall && o.type == "window" && o.off < x + w && o.off + o.w > x && o.sill < up1 && o.sill + o.h > up0
                }
                added.append(template(window ? "spaceUp" : w < 300 ? "fillerUp" : "wall", ws, r.wall, w))
                x += w
            }
        }
    }
    var g = f; g.modules = f.modules + added
    return pack(g, runs)
}

/* ---------------- the worktop ---------------- */

/// The worktop's length on each wall: over the base units, fillers and the dishwasher of the lower row.
func worktopRuns(_ f: Furniture) -> [String: Int] {
    var out: [String: Int] = [:]
    for m in f.modules where !isUpper(m) && (m.type == "base" || m.type == "filler" || m.app == "dishwasher") { out[m.wall ?? "", default: 0] += m.w }
    return out
}

/// Worktop pieces to buy: each wall's run needs its own pieces of pieceL (corners are joined).
func worktopPieces(_ f: Furniture, _ pieceL: Int) -> Int { worktopRuns(f).values.filter { $0 > 0 }.reduce(0) { $0 + ($1 + pieceL - 1) / pieceL } }

/* ---------------- fit checks ---------------- */

/// A finding about the design: level err, warn or ok; key its text; mid the module it is about.
struct FCheck: Equatable {
    let level: String, key: String
    var vars: [String: AnyHashable] = [:]
    var mid: String? = nil
}

private func overlaps(_ a0: Int, _ a1: Int, _ b0: Int, _ b1: Int) -> Bool { a0 < b1 && b0 < a1 }

/// What is wrong (or right) with the kitchen on its room's walls: openings and points of the room.
func checks(_ f: Furniture, _ runs: [Run], _ ws: Workshop, _ openings: [Opening], _ points: [SitePoint]) -> [FCheck] {
    var out: [FCheck] = []
    for r in runs {
        for up in [false, true] {
            let fl = fillOf(f, r, up)
            if let left = fl.left, left < 0 { out.append(FCheck(level: "err", key: up ? "kc.overUp" : "kc.over", vars: ["w": r.wall, "v": -left])) }
            else if !up, let left = fl.left, left > 0, fl.used > 0 { out.append(FCheck(level: "warn", key: "kc.gap", vars: ["w": r.wall, "v": left])) }
        }
    }
    let talls = f.modules.filter { $0.type == "tall" || ($0.type == "gap" && $0.app == "fridge") }
    for m in f.modules {
        let x0 = m.x, x1 = m.x + m.w, y0 = m.elev, y1 = m.elev + m.h
        for o in openings where o.wall == m.wall && overlaps(x0, x1, o.off, o.off + o.w) && overlaps(y0, y1, o.sill, o.sill + o.h) {
            out.append(FCheck(level: o.type == "door" ? "err" : "warn", key: o.type == "door" ? "kc.door" : "kc.window", mid: m.id))
        }
        for p in points where p.wall == m.wall {
            let (pw, ph) = pointSize(p)
            guard overlaps(x0, x1, p.off - pw / 2, p.off + pw / 2) && overlaps(y0, y1, p.h - ph / 2, p.h + ph / 2) else { continue }
            switch p.t {
            case "meter": out.append(FCheck(level: "err", key: "kc.meter", mid: m.id))
            case "socket", "switch": if m.type != "gap" { out.append(FCheck(level: "warn", key: "kc.socket", vars: ["o": p.off, "h": p.h, "t": p.t], mid: m.id)) }
            default: break
            }
        }
        if isUpper(m) && m.type == "wall" {
            for t in talls where t.wall == m.wall && overlaps(x0, x1, t.x, t.x + t.w) { out.append(FCheck(level: "warn", key: "kc.tallUp", mid: m.id)) }
        }
    }
    // the sink near its water and drain, the hood high enough over the hob
    for s in f.modules where s.app == "sink" {
        let c = s.x + s.w / 2
        let near = points.filter { $0.wall == s.wall && ($0.t == "cold" || $0.t == "sewer") }.map { abs($0.off - c) }.min()
        if points.contains(where: { $0.t == "cold" || $0.t == "sewer" }) {
            if let near, near <= 1000 { out.append(FCheck(level: "ok", key: "kc.sinkOk", mid: s.id)) }
            else { out.append(FCheck(level: "warn", key: "kc.sinkFar", vars: ["v": near ?? -1], mid: s.id)) }
        }
    }
    for h in f.modules where h.app == "hood" {
        let gas = points.contains { $0.wall == h.wall && $0.t == "gas" }
        let need = gas ? 750 : 650, above = h.elev - worktopTop(ws)
        if above < need { out.append(FCheck(level: "warn", key: "kc.hood", vars: ["v": above, "n": need], mid: h.id)) }
    }
    return out
}
