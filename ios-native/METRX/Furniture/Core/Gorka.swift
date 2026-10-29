import Foundation

/*
 * The guest room's gorka and the big dining table (modern 3D part 6a; founder's decisions of 25 Oct 2026, the approved
 * mockup's buildGorka; design/furniture/uz-market-research.md: OLX gorkas 270–300 wide × 210 tall with stepped depths,
 * shown with a table for 10–12; Android furniture/Gorka.kt, the same rules and numbers).
 *
 * The gorka is a piece of several boxes on the wardrobe's engine, so its parts, cut list, hardware, price and 3D come
 * from the same rules as a vitrina's: a lit glass tower at each end (a box with a drawer, a box with a glass door and
 * glass shelves on it), a floating TV base with drawers between them, a bridge of doors over the niche, and the TV
 * panel (TV_PANEL, a board item) on the wall between. Its modules always go in this order: the first tower's two
 * boxes, the base, the bridge (if any), the panel, the second tower's boxes (if any); gorkaRoles reads them back.
 *
 * The big table is the dining table's module ("table") laid for ItemOpt.seats people: a 38 mm stone-look or wood top,
 * two panel legs or metal legs; its chairs are drawn round it (chairPlaces) but not priced (the furniture core has no
 * accessories). Pure Swift, unit-tested (GorkaTests). The sizes are defaults for the founder's makers to check.
 */

/// The TV panel's module type (Items.swift ITEM_MODS).
let TV_PANEL = "tvpanel"

/// The TV sizes the gorka's step offers, inches.
let GK_TVS = [55, 65, 75, 85]

/// The TV panel's facing: a stone-look slab, wood slats, moulded MDF.
let GK_PANELS = ["stone", "slats", "mould"]

/// What each facing is bought as (Hardware.swift AREA_KINDS, by the m²).
func panelKind(_ panel: String) -> String { panel == "slats" ? "tvSlats" : panel == "mould" ? "tvMould" : "tvStone" }

let GK_TOWER_D = 400
let GK_BASE_D = 450
let GK_BRIDGE_D = 300
let GK_BRIDGE_H = 300
/// A tower's lower box (its drawer) and the plinth under it.
let GK_LOW_H = 500
let GK_PLINTH = 60
/// The floating TV base: its bottom above the floor and its height.
let GK_BASE_ELEV = 220
let GK_BASE_H = 400
/// The panel stands this far in from each tower; it stops this far under the bridge.
let GK_PANEL_IN = 80
let GK_PANEL_GAP = 20
/// The TV niche is at least this wide.
let GK_NICHE_MIN = 900
/// The facing over the panel's board (a stone slab, slats, mouldings), mm.
let GK_FACING = 22

/// v held to lo…hi (Kotlin's coerceIn).
private func gkClamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }

/// A TV's width and height for its diagonal in inches (16:9), mm.
func tvSize(_ inch: Int) -> (Int, Int) {
    (Int((Double(inch) * 25.4 * 0.8716).rounded()), Int((Double(inch) * 25.4 * 0.4903).rounded()))
}

/// A gorka's options: overall width w and height h, a tower's width tw, the TV tv (inches), towers 2 or 1, the bridge
/// over the niche, the panel's facing, glass doors on the towers (else board doors).
struct GkOpts: Equatable {
    var w = 3000, h = 2100, tw = 500, tv = 65, towers = 2
    var bridge = true
    var panel = "stone"
    var glass = true
}

/// A tower's width held so the niche stays at least GK_NICHE_MIN wide.
func towerW(_ o: GkOpts) -> Int { max(300, min(gkClamp(o.tw, 300, 800), (o.w - GK_NICHE_MIN) / gkClamp(o.towers, 1, 2))) }

/// One drawer filling an open section ih high inside, g from its bottom and top (as the doors' gap).
private func gkFill(_ ih: Int, _ g: Int) -> [Insert] { [Insert("drawer", pos: g, h: ih - 2 * g)] }

/// A tower's two boxes at x: the lower one with its drawer, the upper one with its door and shelves, hinged on hinge.
private func gkTower(_ ws: Workshop, _ x: Int, _ tw: Int, _ h: Int, _ glass: Bool, _ hinge: String) -> [Module] {
    let g = ws.gap10 / 10
    var lo = Module(id: uid(), type: "wardrobe", w: tw, h: GK_LOW_H, d: GK_TOWER_D, x: x, wall: "A", legs: false, base: GK_PLINTH)
    lo.sections = [Section(tw, fronts: Fronts("open", 0), inserts: gkFill(wardInnerH(lo, ws.t), g))]
    var up = Module(id: uid(), type: "wardrobe", w: tw, h: max(600, h - GK_LOW_H), d: GK_TOWER_D, x: x, wall: "A", elev: GK_LOW_H, legs: false, base: 0)
    let ih = wardInnerH(up, ws.t)
    let shelves = Array(repeating: Insert("shelf"), count: max(2, ih / 450))
    var s = spreadShelves(Section(tw, fronts: Fronts("door", 1), inserts: shelves, hinge: hinge, face: glass ? "glass" : ""), ih, ws.t)
    if glass { s.inserts = s.inserts.map { var x = $0; x.kind = "glass"; return x } }
    up.sections = [s]
    return [lo, up]
}

/// The widest door the bridge gets by default, mm (Wardrobe.swift wardrobeChecks "wc.doorWide" warns above it).
let GK_DOOR_MAX = 600

/// The fewest doors for a bridge nw wide that keep each door GK_DOOR_MAX or narrower: each door's width as the parts and
/// the checks work it out (its section's share of the box, the carcass sides included, less the edge gaps), at least 2
/// (founder 29 Oct 2026: a 3000 gorka's 2000 bridge had 3 doors of 663, flagged heavy; now 4 of 497). New pieces only.
func gkBridgeDoors(_ nw: Int, _ ws: Workshop) -> Int {
    for n in 2...12 {
        let secs = splitSections(nw, Array(repeating: Section(0, fronts: Fronts("door", 1)), count: n))
        let widest = secs.flatMap { frontSizes($0.fronts, frontW($0), GK_BRIDGE_H, ws).map(\.1) }.max() ?? 0
        if widest <= GK_DOOR_MAX { return n }
    }
    return 12
}

/// The gorka's boxes for o, from the wall's start (W_GAP_SIDE).
func gorkaBoxes(_ ws: Workshop, _ o: GkOpts) -> [Module] {
    let n = gkClamp(o.towers, 1, 2)
    let tw = towerW(o)
    let nw = max(GK_NICHE_MIN, o.w - n * tw)
    let h = max(o.h, 1800)
    let x0 = W_GAP_SIDE
    let g = ws.gap10 / 10
    let secs = nw >= 1500 ? 3 : 2
    var base = Module(id: uid(), type: "wardrobe", w: nw, h: GK_BASE_H, d: GK_BASE_D, x: x0 + tw, wall: "A", elev: GK_BASE_ELEV, legs: false, base: 0)
    let drawer = Section(0, fronts: Fronts("open", 0), inserts: gkFill(wardInnerH(base, ws.t), g))
    base.sections = splitSections(nw, Array(repeating: drawer, count: secs))
    var out = gkTower(ws, x0, tw, h, o.glass, "R")
    out.append(base)
    if o.bridge {
        // as many doors as keep each one 600 or narrower (the designer's own "heavy door" check), not the base's drawers' count
        let doors = splitSections(nw, Array(repeating: Section(0, fronts: Fronts("door", 1)), count: gkBridgeDoors(nw, ws)))
        out.append(Module(id: uid(), type: "wardrobe", w: nw, h: GK_BRIDGE_H, d: GK_BRIDGE_D, x: x0 + tw, wall: "A", elev: h - GK_BRIDGE_H, sections: doors,
                          legs: false, base: 0))
    }
    let pe = GK_BASE_ELEV + GK_BASE_H
    let pn = GK_PANELS.contains(o.panel) ? o.panel : "stone"
    out.append(itemModule(TV_PANEL, ws, "A", x0 + tw + GK_PANEL_IN, nw - 2 * GK_PANEL_IN, h - GK_BRIDGE_H - GK_PANEL_GAP - pe, 0, ItemOpt(panel: pn, tv: o.tv), elev: pe))
    if n == 2 { out += gkTower(ws, x0 + tw + nw, tw, h, o.glass, "L") }
    return out
}

/// The option at index i of list, or fallback when out of range.
private func gkAt<T>(_ list: [T], _ i: Int, _ fallback: T) -> T { i >= 0 && i < list.count ? list[i] : fallback }

/// The gorka's options from its step values (the steps' and its designer's keys, Pieces.swift newPiece).
func gkOpts(_ v: (String) -> Int) -> GkOpts {
    GkOpts(w: v("w"), h: v("h"), tw: v("tw"), tv: gkAt(GK_TVS, v("tv"), 65), towers: v("one") == 1 ? 1 : 2, bridge: v("nobr") != 1,
           panel: gkAt(GK_PANELS, v("pn"), "stone"), glass: v("solid") != 1)
}

/// The boxes of a gorka by what they are: its towers' lower and upper boxes (first tower first), the base, the bridge, the panel.
struct GkRoles {
    let lows: [Module], ups: [Module]
    let base: Module?, bridge: Module?, panel: Module?
    var towerTop: Int { ups.map { $0.elev + $0.h }.max() ?? bridge.map { $0.elev + $0.h } ?? 2100 }
}

/// The gorka's boxes by their place in its list: 3 cabinets one tower and no bridge, 4 one tower and a bridge, 5 two
/// towers and no bridge, 6 two towers and a bridge. nil for a piece that is not a gorka (or whose boxes are not so).
func gorkaRoles(_ f: Furniture) -> GkRoles? {
    guard f.type == "gorka" else { return nil }
    let c = f.modules.filter { $0.type == "wardrobe" }
    guard (3...6).contains(c.count) else { return nil }
    let two = c.count >= 5, br = c.count % 2 == 0
    let lows = two ? [c[0], c[c.count - 2]] : [c[0]]
    let ups = two ? [c[1], c[c.count - 1]] : [c[1]]
    return GkRoles(lows: lows, ups: ups, base: c[2], bridge: br ? c[3] : nil, panel: f.modules.first { $0.type == TV_PANEL })
}

/// m w wide: its sections spread again when it changed.
private func gkWiden(_ m: Module, _ w: Int) -> Module {
    if m.w == w { return m }
    var n = m
    n.w = w
    n.sections = splitSections(w, m.sections.map { var s = $0; s.lock = false; return s })
    return n
}

/// A gorka's boxes where they belong after a change: each tower's upper box as wide as its lower one and on it (the one
/// just changed leads), the base and the bridge between the towers (as wide as each other: the bridge leads when it
/// changed), the bridge's top level with the towers', the panel between them over the base.
func gorkaPack(_ f: Furniture, _ changed: String?, _ ws: Workshop) -> Furniture {
    guard let r = gorkaRoles(f), let base = r.base else { return f }
    var nx: [String: Module] = [:]
    var x = r.lows[0].x
    func towerAt(_ i: Int) {
        let lo = r.lows[i], up = r.ups[i]
        let w = changed == up.id ? up.w : lo.w
        var l2 = gkWiden(lo, w); l2.x = x
        nx[lo.id] = l2
        var u2 = gkWiden(up, w); u2.x = x; u2.elev = topOf(l2, ws); u2.wall = lo.wall
        nx[up.id] = u2
        x += w
    }
    towerAt(0)
    let nw: Int
    if let b = r.bridge, changed == b.id { nw = b.w } else { nw = base.w }
    let bx = x
    var b2 = gkWiden(base, nw); b2.x = bx
    nx[base.id] = b2
    x += nw
    if r.lows.count > 1 { towerAt(1) }
    let top = r.ups.map { u -> Int in let m = nx[u.id] ?? u; return m.elev + m.h }.max() ?? 0
    if let b = r.bridge {
        var n = gkWiden(b, nw)
        n.x = bx; n.elev = max(base.elev + base.h + 300, top - b.h); n.wall = base.wall
        nx[b.id] = n
    }
    if let p = r.panel {
        let pe = base.elev + base.h
        let under: Int = r.bridge.flatMap { nx[$0.id]?.elev } ?? (top - GK_BRIDGE_H)
        let pt = under - GK_PANEL_GAP
        var n = p
        n.x = bx + GK_PANEL_IN; n.w = max(200, nw - 2 * GK_PANEL_IN); n.elev = pe; n.h = max(200, pt - pe); n.wall = base.wall
        nx[p.id] = n
    }
    let pos = nx
    var g = f
    g.modules = f.modules.map { pos[$0.id] ?? $0 }
    return g
}

/// A gorka's step values (and its designer's), read back from its boxes.
func gorkaVals(_ f: Furniture, _ ws: Workshop) -> [String: Int] {
    guard let r = gorkaRoles(f) else { return [:] }
    let c = f.modules.filter { $0.type == "wardrobe" }
    let o = r.panel?.opt ?? ItemOpt()
    let x0 = c.map(\.x).min() ?? 0
    let x1 = c.map { $0.x + $0.w }.max() ?? 0
    let h: Int = c.map { topOf($0, ws) }.max() ?? 2100
    let d: Int = c.map(\.d).max() ?? 0
    return [
        "w": x1 - x0, "h": h, "tw": r.lows[0].w,
        "tv": GK_TVS.firstIndex(of: o.tv) ?? 1,
        "d": d,
        "one": r.lows.count == 1 ? 1 : 0,
        "nobr": r.bridge == nil ? 1 : 0,
        "pn": GK_PANELS.firstIndex(of: o.panel) ?? 0,
        "solid": gorkaGlass(f) ? 0 : 1
    ]
}

/// Whether the gorka's towers have glass doors.
func gorkaGlass(_ f: Furniture) -> Bool { gorkaRoles(f)?.ups.contains { u in u.sections.contains { $0.face == "glass" } } == true }

/// The gorka with glass doors (and glass shelves) in its towers, or board doors over board shelves; its sizes as they are.
func withGorkaGlass(_ f: Furniture, _ glass: Bool) -> Furniture {
    guard let r = gorkaRoles(f) else { return f }
    let ids = Set(r.ups.map(\.id))
    var g = f
    g.modules = f.modules.map { m in
        guard ids.contains(m.id) else { return m }
        var n = m
        n.sections = m.sections.map { s in
            var t = s
            t.face = glass ? "glass" : ""
            t.inserts = s.inserts.map { x in
                var y = x
                if glass && x.kind == "shelf" { y.kind = "glass" } else if !glass && x.kind == "glass" { y.kind = "shelf" }
                return y
            }
            return t
        }
        return n
    }
    return g
}

/// The gorka with its TV panel's facing panel or TV tv (inches) changed.
func withGorkaPanel(_ f: Furniture, panel: String? = nil, tv: Int? = nil) -> Furniture {
    var g = f
    g.modules = f.modules.map { m in
        guard m.type == TV_PANEL else { return m }
        var o = m.opt ?? ItemOpt()
        if let panel { o.panel = panel }
        if let tv { o.tv = tv }
        var n = m; n.opt = o
        return n
    }
    return g
}

/// Whether the TV fits its panel: the TV's width at most the panel's less 40 mm.
func tvFits(_ f: Furniture) -> Bool {
    guard let p = gorkaRoles(f)?.panel else { return true }
    let tv = p.opt?.tv ?? 0
    return tvSize(tv > 0 ? tv : 65).0 <= p.w - 40
}

/// The gorka's LED strips, mm (the 3D draws the same, Geo/GorkaScene3D.swift): up each side of a tower's glass box,
/// under the floating base and under the bridge.
func gorkaLedMm(_ f: Furniture, _ ws: Workshop) -> Int {
    guard let r = gorkaRoles(f) else { return 0 }
    return r.ups.reduce(0) { $0 + 2 * wardInnerH($1, ws.t) } + (r.base.map { $0.w - 80 } ?? 0) + (r.bridge.map { $0.w - 60 } ?? 0)
}

/// The gorka's cornice (a neoclassic one): along the top of each tower and of the bridge, mm.
func gorkaCorniceMm(_ f: Furniture) -> Int {
    guard let r = gorkaRoles(f) else { return 0 }
    return r.ups.reduce(0) { $0 + $1.w } + (r.bridge?.w ?? 0)
}

/// The gorka's own hardware (kinds counted like the modules', metre kinds in mm): its LED strips with one driver for
/// every 5 m when the look has LED, the cornice when the look has one. The panel's facing is the panel's (Items.swift).
func gorkaHardware(_ f: Furniture, _ ws: Workshop) -> Counts {
    var out = Counts()
    guard f.type == "gorka" else { return out }
    if f.look?.led == true {
        let mm = gorkaLedMm(f, ws)
        if mm > 0 { out.add("led", mm); out.add("ledPsu", (mm + 4999) / 5000) }
    }
    if f.look?.crown == "cornice" { out.add("cornice", gorkaCorniceMm(f)) }
    return out
}

/// What a gorka's box is called in its designer (strings key).
func gorkaRole(_ f: Furniture, _ m: Module) -> String? {
    guard let r = gorkaRoles(f) else { return nil }
    if r.lows.contains(where: { $0.id == m.id }) { return "gk.box.low" }
    if r.ups.contains(where: { $0.id == m.id }) { return "gk.box.tower" }
    if m.id == r.base?.id { return "gk.box.base" }
    if m.id == r.bridge?.id { return "gk.box.bridge" }
    return nil
}

/* ---------------- the TV panel ---------------- */

/// The TV panel's boards: its board (the moulded one's is the visible MDF panel, in the fronts' board), the facing over it in the 3D.
func panelBoards(_ m: Module, _ ws: Workshop) -> [Board] {
    let o = m.opt ?? ItemOpt()
    let E = m.elev
    if o.panel == "mould" { return [Board("gk.panel", "front", 0, m.w, E, E + m.h, 0, ws.t)] }
    return [Board("gk.panelBack", "carcass", 0, m.w, E, E + m.h, 0, ws.t)]
}

/// The TV panel's hardware: its facing by the m² (a moulded panel's milling).
func panelHardware(_ m: Module, _ add: (String, Int) -> Void) { add(panelKind(m.opt?.panel ?? "stone"), m.w * m.h) }

/* ---------------- the big dining table ---------------- */

/// The big table's seats (its step's choices) and legs (two panel legs, four metal legs).
let DT_SEATS = [10, 12]
let DT_LEGS = ["board", "metal4"]

/// A chair stands this far out from the table's edge (its middle); chairs side by side are at least DT_PITCH apart.
let DT_CHAIR_OUT = 240
let DT_CHAIR_W = 440
let DT_PITCH = 500
let DT_PITCH_MAX = 620

/// A chair round the big table: its middle a along the table and n out from its back edge; face which way it looks (+n, -n, +a, -a).
struct Chair: Equatable {
    let a: Int, n: Int, face: String
}

/// How many chairs a side w long takes at most, each DT_PITCH apart.
func chairsPerSide(_ w: Int) -> Int { max(1, (w - 100) / DT_PITCH) }

/// The chairs round the big table m: one at each end, the rest shared by the two long sides, evenly from the middle,
/// DT_PITCH–DT_PITCH_MAX apart; a table too short for its seats takes fewer chairs along its sides.
func chairPlaces(_ m: Module) -> [Chair] {
    let seats = m.opt?.seats ?? 0
    guard m.type == "table", seats > 0 else { return [] }
    let n = min(max(1, (seats - 2) / 2), chairsPerSide(m.w))
    let sp = min(DT_PITCH_MAX, (m.w - 100) / n)
    var out: [Chair] = []
    for i in 0..<n {
        let a = Int((Double(m.w) / 2 + (Double(i) - Double(n - 1) / 2) * Double(sp)).rounded())
        out.append(Chair(a: a, n: -DT_CHAIR_OUT, face: "+n"))
        out.append(Chair(a: a, n: m.d + DT_CHAIR_OUT, face: "-n"))
    }
    out.append(Chair(a: -DT_CHAIR_OUT, n: m.d / 2, face: "+a"))
    out.append(Chair(a: m.w + DT_CHAIR_OUT, n: m.d / 2, face: "-a"))
    return out
}

/// How many sit at the big table as drawn.
func seatsOf(_ m: Module) -> Int { chairPlaces(m).count }

/// The big table's two panel legs (each two boards glued) set in from its ends, and the rail between them.
func bigTableLegs(_ m: Module, _ ws: Workshop, _ y1: Int) -> [Board] {
    let t = ws.t, W = m.w, D = m.d
    let ia = min(420, W / 7)
    var out: [Board] = []
    for a in [ia, W - ia - 2 * t] {
        out.append(Board("fp.tLeg", "front", a, a + t, 0, y1, 200, D - 200))
        out.append(Board("fp.tLeg", "front", a + t, a + 2 * t, 0, y1, 200, D - 200))
    }
    out.append(Board("fp.apron", "front", ia + 2 * t, W - ia - 2 * t, y1 - 150, y1, D / 2 - t / 2, D / 2 + t - t / 2))
    return out
}

/// The worktop strips a big table's top is joined from (600 deep each).
func topStrips(_ m: Module) -> Int { max(1, (m.d + 599) / 600) }

/// The big table's top: kind "stone" or "wood", keeping the decor cur where it is of that kind.
func dtTop(_ kind: String, _ cur: String?) -> String {
    let d = worktopDecor(cur)
    if kind == "wood" { return worktopFor("wood", d == "craft" || d == "halifax" ? d : "halifax") }
    return worktopFor("stone", ["marble", "onyx", "dark"].contains(d) ? d : "marble")
}

/// Whether f is the big dining table.
func isBigTable(_ f: Furniture) -> Bool { f.type == "dining12" }

/// The big table's sizes in its designer, mm (its steps' ranges).
func bigTableRange(_ key: String) -> ClosedRange<Int> {
    switch key {
    case "d": return 900...1300
    case "h": return 700...800
    default: return 1800...3600
    }
}
