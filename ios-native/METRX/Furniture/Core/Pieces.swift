import Foundation

/*
 * The gallery's later models (decided 22 Oct 2026; Android furniture/Pieces.kt): pieces made of several boxes on the
 * wardrobe's engine and the board-built items (Items.swift). A stenka is pieces side by side on one wall (shelves hung
 * over them), a corner wardrobe or desk two arms on two walls, a vitrina and a washing-machine column one box on
 * another, a loft bed its frame with a desk or a wardrobe under it, a dressing table its drawers with a mirror over
 * them. packPiece keeps the boxes where they belong after every change. Pure Swift, unit-tested (PiecesTests).
 */

/// Pieces with their own short designer (Items.swift) instead of the wardrobe designer.
let ITEM_TYPES: Set<String> = ["bed", "bunk", "loft", "dining", "coffee", "bar", "mirrorP"]
/// Pieces of several boxes on the wardrobe's engine.
let PIECE_TYPES: Set<String> = ["stenka", "cornerW", "cornerDesk", "vitrina", "washer"]
/// Pieces on two walls round a corner: the first wall's run ends in the corner, the second starts past its depth.
let CORNER_TYPES: Set<String> = ["cornerW", "cornerDesk"]
/// One box standing on another.
let STACK_TYPES: Set<String> = ["vitrina", "washer"]

/// A bed's kinds, a table's legs, in the order their steps offer them.
let BED_KINDS = ["legs", "drawers", "lift"]
let LEG_KINDS = ["board", "metal4", "frame"]
let UNDER_KINDS = ["desk", "ward", "open"]

/// A box of a piece: a cabinet on the wardrobe's engine or an item.
func isBox(_ m: Module) -> Bool { m.type == "wardrobe" || ITEM_MODS.contains(m.type) }

func boxes(_ f: Furniture) -> [Module] { f.modules.filter { isBox($0) } }

/// A piece with the short designer (a bed, a table, the bar counter, a mirror panel).
func isItemPiece(_ f: Furniture) -> Bool { f.kind == "wardrobe" && ITEM_TYPES.contains(f.type) }

/// A box that hangs on the wall (or stands on another box): no legs, its bottom above the floor.
func hung(_ m: Module) -> Bool { !m.legs && m.elev > 0 }

/// How high a box reaches from the floor.
func topOf(_ m: Module, _ ws: Workshop) -> Int { ITEM_MODS.contains(m.type) ? itemTop(m, ws) : m.elev + outerH(m, ws) }

/// The first wall a piece stands on (its main box's when it has none).
private func firstWall(_ f: Furniture) -> String? { f.walls.first ?? wardOfF(f)?.wall }

/// The boxes standing on the piece's first wall (all but a corner piece's second arm; a hung one when nothing stands).
func firstRun(_ f: Furniture) -> [Module] {
    let w0 = firstWall(f)
    let on = boxes(f).filter { $0.wall == w0 }
    let standing = on.filter { !hung($0) }
    return standing.isEmpty ? on : standing
}

/// Where the piece starts on its first wall and how long it is there.
func runStart(_ f: Furniture) -> Int { firstRun(f).map(\.x).min() ?? 0 }
func runLen(_ f: Furniture) -> Int {
    let r = firstRun(f)
    guard let a = r.map(\.x).min(), let b = r.map({ $0.x + $0.w }).max() else { return 0 }
    return b - a
}

/// The piece moved along its first wall so it starts at x.
func shiftRun(_ f: Furniture, _ x: Int) -> Furniture {
    let d = x - runStart(f)
    if d == 0 { return f }
    let w0 = firstWall(f)
    var g = f
    g.modules = f.modules.map { m in
        guard isBox(m) && m.wall == w0 else { return m }
        var n = m; n.x += d
        return n
    }
    return g
}

/// Moisture-resistant board for a bathroom's carcass and fronts.
let MR_BOARD = "ldsp16mr"
func bathMats() -> FMats { FMats(carcass: MR_BOARD, front: MR_BOARD) }

/// The sections unlocked, to be spread again over a new width.
private func unlocked(_ ss: [Section]) -> [Section] { ss.map { var s = $0; s.lock = false; return s } }

/* ---------------- keeping the boxes in place ---------------- */

/// The piece's boxes where they belong: a corner piece's arms in the corner of a first wall lenA long (nil: from its
/// start), a stenka's pieces side by side, a box on another one, a loft bed's under-part, a dressing table's mirror.
/// changed: the box just changed (it leads a stacked pair).
func packPiece(_ f: Furniture, _ lenA: Int? = nil, changed: String? = nil, ws: Workshop = Workshop()) -> Furniture {
    if f.kind != "wardrobe" { return f }
    if CORNER_TYPES.contains(f.type) { return cornerFit(f, lenA) }
    if f.type == "stenka" { return stenkaPack(f) }
    if STACK_TYPES.contains(f.type) { return stackPack(f, changed, ws) }
    if f.type == "loft" { return loftPack(f, ws) }
    if f.modules.contains(where: { $0.type == "mirror" }) { return mirrorPack(f, ws) }
    return f
}

/// A corner piece's first arm ends in the corner (or starts where it starts), the second starts past the first's depth.
func cornerFit(_ f: Furniture, _ lenA: Int?) -> Furniture {
    guard f.walls.count >= 2 else { return f }
    let wa = f.walls[0], wb = f.walls[1]
    let a = f.modules.filter { isBox($0) && $0.wall == wa }
    let b = f.modules.filter { isBox($0) && $0.wall == wb }
    let total = a.reduce(0) { $0 + $1.w }
    var x: Int
    if let lenA { x = lenA - W_GAP_SIDE - total } else { x = a.map(\.x).min() ?? W_GAP_SIDE }
    var xs: [String: Int] = [:]
    for m in a { xs[m.id] = x; x += m.w }
    var y = a.last?.d ?? W_DEPTH
    for m in b { xs[m.id] = y; y += m.w }
    // the corner unit's blind part is as wide as the second arm is deep
    let bd = b.first?.d
    let pos = xs
    var g = f
    g.modules = f.modules.map { m in
        var n = m
        if let v = pos[m.id] { n.x = v }
        if let bd, n.sections.contains(where: { $0.blind > 0 }) {
            n.sections = n.sections.map { s in
                var t = s
                if s.blind > 0 { t.blind = min(bd, s.w - 200) }
                return t
            }
        }
        return n
    }
    return g
}

/// A stenka: the floor pieces side by side in their order; each hung shelf centred over the floor piece before it.
func stenkaPack(_ f: Furniture) -> Furniture {
    let bs = boxes(f)
    if bs.isEmpty { return f }
    let floor = bs.filter { !hung($0) }
    var x = floor.map(\.x).min() ?? W_GAP_SIDE
    var xs: [String: Int] = [:]
    for m in floor { xs[m.id] = x; x += m.w }
    var under: Module? = floor.first
    for m in bs {
        if !hung(m) { under = m }
        else if let u = under, let ux = xs[u.id] { xs[m.id] = ux + (u.w - m.w) / 2 }
    }
    let pos = xs
    var g = f
    g.modules = f.modules.map { m in
        guard let v = pos[m.id] else { return m }
        var n = m; n.x = v
        return n
    }
    return g
}

/// A box on another: the upper one as wide as the lower and on it; the one just changed leads.
func stackPack(_ f: Furniture, _ changed: String?, _ ws: Workshop) -> Furniture {
    let bs = f.modules.filter { $0.type == "wardrobe" }
    if bs.count < 2 { return f }
    let lo = bs[0], up = bs[1]
    let lead = changed == up.id ? up : lo
    func fit(_ m: Module) -> Module {
        var n = m; n.x = lead.x
        if m.w != lead.w { n.w = lead.w; n.sections = splitSections(lead.w, unlocked(m.sections)) }
        return n
    }
    let nlo = fit(lo)
    var nup = fit(up); nup.elev = topOf(nlo, ws)
    let top = nup
    var g = f
    g.modules = f.modules.map { m in
        if m.id == lo.id { return nlo }
        if m.id == up.id { return top }
        return m
    }
    return g
}

/// A loft bed: the desk or wardrobe under it at the end away from the ladder, under its platform, inside its frame.
func loftPack(_ f: Furniture, _ ws: Workshop) -> Furniture {
    guard let bed = f.modules.first(where: { $0.type == "loft" }) else { return f }
    let t = ws.t
    let o = bed.opt ?? ItemOpt()
    var g = f
    g.modules = f.modules.map { m in
        guard m.type == "wardrobe" else { return m }
        let w = min(m.w, bed.w - 2 * t - 10), d = min(m.d, frameD(bed) - 2 * t)
        let room = upperDeck(bed) - 160 - (m.legs ? legsOf(m, ws) : 0)
        let h = min(m.h, room)
        let x = o.ladder == "R" ? bed.x + t + 5 : bed.x + bed.w - t - 5 - w
        var n = m
        n.x = x; n.w = w; n.d = d; n.h = h; n.wall = bed.wall
        if w != m.w { n.sections = splitSections(w, unlocked(m.sections)) }
        return n
    }
    return g
}

/// A dressing table's mirror: centred over the table, at least 50 over its top.
func mirrorPack(_ f: Furniture, _ ws: Workshop) -> Furniture {
    guard let cab = f.modules.first(where: { $0.type == "wardrobe" }) else { return f }
    let top = topOf(cab, ws)
    var g = f
    g.modules = f.modules.map { m in
        guard m.type == "mirror" else { return m }
        var n = m
        n.x = cab.x + (cab.w - m.w) / 2; n.wall = cab.wall; n.elev = max(m.elev, top + 50)
        return n
    }
    return g
}

/* ---------------- the newer models ---------------- */

/// A tall cabinet of a stenka: one door, five shelves, on a plinth.
private func tallCab(_ ws: Workshop, _ wall: String, _ x: Int, _ w: Int, _ h: Int, _ d: Int) -> Module {
    var m = cabinetTemplate("bookcase", ws, wall, x, w, h, d)
    let fr = Fronts("door", w >= 700 ? 2 : 1)
    m.sections = m.sections.map { var s = $0; s.fronts = fr; return s }
    return m
}

/// A shelf hung over a stenka's low piece: open boxes about 600 wide.
private func hungShelf(_ ws: Workshop, _ wall: String, _ x: Int, _ w: Int, _ elev: Int) -> Module {
    var m = cabinetTemplate("shelfW", ws, wall, x, w, 350, 280)
    m.elev = elev
    m.sections = splitSections(w, Array(repeating: Section(0, fronts: Fronts("open", 0)), count: sectionsFor(w)))
    return m
}

/// A piece a stenka can take more of: a tall cabinet, a low one, a TV unit, a hung shelf.
let STENKA_PARTS = ["tall", "low", "tv", "shelf"]

/// A new box of kind k for stenka f, as high as its talls and as deep as it is.
func stenkaPart(_ f: Furniture, _ k: String, _ ws: Workshop) -> Module {
    let wall = f.walls.first ?? "A"
    let floor = boxes(f).filter { !hung($0) }
    let h = floor.map { outerH($0, ws) }.filter { $0 >= 1400 }.max() ?? 2200
    let d = floor.map(\.d).max() ?? 400
    switch k {
    case "low": return cabinetTemplate("sideboard", ws, wall, 0, 800, 850, d)
    case "tv": return cabinetTemplate("tv", ws, wall, 0, 1200, 500, max(d, 400))
    case "shelf": return hungShelf(ws, wall, 0, 1000, 1450)
    default: return tallCab(ws, wall, 0, 600, h, d)
    }
}

/// A stenka w wide: a tall cabinet at each end, a low TV unit between them, shelves hung over it.
private func stenka(_ ws: Workshop, _ w: Int, _ h: Int, _ d: Int) -> [Module] {
    let tw = w >= 2400 ? 600 : max(400, w / 5)
    let tv = w - 2 * tw
    let x0 = W_GAP_SIDE
    var out: [Module] = []
    out.append(tallCab(ws, "A", x0, tw, h, d))
    if tv >= 600 {
        out.append(cabinetTemplate("tv", ws, "A", x0 + tw, tv, 500, max(d, 400)))
        out.append(hungShelf(ws, "A", x0 + tw + 100, max(600, tv - 200), min(1450, h - 350 - 100)))
    }
    out.append(tallCab(ws, "A", x0 + tw + max(0, tv), tw, h, d))
    return out
}

/// A corner unit d + 400 wide: a door beside its blind part (the other arm closes it), a rail and a shelf inside.
private func cornerUnit(_ ws: Workshop, _ x: Int, _ h: Int, _ d: Int) -> Module {
    let cw = d + 400
    var base = Module(id: uid(), type: "wardrobe", w: cw, h: h, d: d, x: x, wall: "A", legs: false)
    let ih = wardInnerH(base, ws.t)
    let rail = min(ih - 420, 1800 - wardBase(base) - ws.t)
    base.sections = [Section(cw, fronts: Fronts("door", 1), inserts: [Insert("rail", pos: rail), Insert("shelf", pos: rail + 70)], hinge: "L", blind: d)]
    return base
}

/// A corner wardrobe w along the first wall and w2 along the second (each with the corner's depth in it).
private func cornerWard(_ ws: Workshop, _ w: Int, _ w2: Int, _ h: Int, _ d: Int) -> [Module] {
    let cw = d + 400
    var out: [Module] = []
    let aw = w - cw
    if aw >= 300 { out.append(wardrobeTemplate(ws, "A", W_GAP_SIDE, aw, h, builtIn: false, d: d)) }
    out.append(cornerUnit(ws, W_GAP_SIDE + max(0, aw), h, d))
    let bw = w2 - d
    if bw >= 300 { out.append(wardrobeTemplate(ws, "B", d, bw, h, builtIn: false, d: d)) }
    return out
}

/// A corner desk: a desk along each wall, the knee space going round the corner (the second arm has no side there).
private func cornerDesk(_ ws: Workshop, _ w: Int, _ w2: Int, _ h: Int, _ d: Int) -> [Module] {
    let a = cabinetTemplate("desk", ws, "A", W_GAP_SIDE, w, h, d)
    var b = cabinetTemplate("desk", ws, "B", d, max(450, w2 - d), h, d)
    b.sections = Array(b.sections.reversed())
    b.sideL = false
    return [a, b]
}

/// A vitrina: a board cabinet below, glass doors in their frames over glass shelves above, an LED strip in its top.
private func vitrina(_ ws: Workshop, _ w: Int, _ h: Int, _ d: Int) -> [Module] {
    let n = w >= 600 ? 2 : 1
    var lo = Module(id: uid(), type: "wardrobe", w: w, h: 850, d: d, x: W_GAP_SIDE, wall: "A", legs: false)
    lo.sections = [spreadShelves(Section(w, fronts: Fronts("door", n), inserts: [Insert("shelf")]), wardInnerH(lo, ws.t), ws.t)]
    var up = Module(id: uid(), type: "wardrobe", w: w, h: max(400, h - 850), d: d, x: W_GAP_SIDE, wall: "A", elev: 850, legs: false, base: 0, led: true)
    let shelves = Array(repeating: Insert("shelf"), count: 3)
    var s = spreadShelves(Section(w, fronts: Fronts("door", n), inserts: shelves, face: "glass"), wardInnerH(up, ws.t), ws.t)
    s.inserts = s.inserts.map { var x = $0; x.kind = "glass"; return x }
    up.sections = [s]
    return [lo, up]
}

/// A washing-machine column: an open niche for the machine (no bottom, no back), a cabinet with doors over it.
private func washer(_ ws: Workshop, _ w: Int, _ h: Int, _ d: Int) -> [Module] {
    let lo = Module(id: uid(), type: "wardrobe", w: w, h: 900, d: d, x: W_GAP_SIDE, wall: "A", sections: [Section(w, fronts: Fronts("open", 0), knee: true)],
                    legs: false, base: 0)
    var up = Module(id: uid(), type: "wardrobe", w: w, h: max(400, h - 900), d: d, x: W_GAP_SIDE, wall: "A", elev: 900, legs: false, base: 0)
    let shelves = Array(repeating: Insert("shelf"), count: 2)
    up.sections = [spreadShelves(Section(w, fronts: Fronts("door", w >= 600 ? 2 : 1), inserts: shelves), wardInnerH(up, ws.t), ws.t)]
    return [lo, up]
}

/// What goes under a loft bed: a desk, a two-door cabinet, or nothing.
func loftUnder(_ k: String, _ ws: Workshop, _ bed: Module) -> Module? {
    let w = min(k == "desk" ? 1200 : 1000, bed.w - 2 * ws.t - 10)
    let d = min(600, frameD(bed) - 2 * ws.t)
    switch k {
    case "desk": return cabinetTemplate("desk", ws, bed.wall ?? "A", bed.x, w, 750, d)
    case "ward":
        let h = upperDeck(bed) - 160
        var m0 = Module(id: uid(), type: "wardrobe", w: w, h: h, d: d, x: bed.x, wall: bed.wall, legs: false)
        let ih = wardInnerH(m0, ws.t)
        let sec = Section(0, fronts: Fronts("door", 1), inserts: Array(repeating: Insert("shelf"), count: 3))
        m0.sections = splitSections(w, [sec, sec]).map { spreadShelves($0, ih, ws.t) }
        return m0
    default: return nil
    }
}

/// A loft bed with k under it.
func withUnder(_ f: Furniture, _ k: String, _ ws: Workshop) -> Furniture {
    guard let bed = f.modules.first(where: { $0.type == "loft" }) else { return f }
    var o = bed.opt ?? ItemOpt(); o.under = k
    var nb = bed; nb.opt = o
    var g = f
    g.modules = [nb]
    if let u = loftUnder(k, ws, nb) { g.modules.append(u) }
    return loftPack(g, ws)
}

/// The option at index i of list (its first when out of range).
private func optAt(_ i: Int, _ list: [String]) -> String { i >= 0 && i < list.count ? list[i] : list[0] }

/// One cabinet of a newer type: hung ones from their height above the floor, a vanity or a tall one on legs or on the wall.
private func oneCabinet(_ type: String, _ v: (String) -> Int, _ ws: Workshop) -> [Module] {
    let x = W_GAP_SIDE
    var m = cabinetTemplate(type, ws, "A", x, v("w"), v("h"), v("d"))
    if HUNG_TYPES.contains(type) { m.elev = v("e") }
    if MOUNT_TYPES.contains(type) && v("mt") == 1 { m.legs = false; m.base = 0; m.elev = 300; m.h = max(300, v("h") - 300) }
    var out = [m]
    if type == "vanity" {
        out.append(Module(id: uid(), type: "mirror", w: v("rw"), h: v("rh"), d: 5, x: x, wall: "A", elev: topOf(m, ws) + 250,
                          fronts: Fronts("open", 0), legs: false, base: 0))
    }
    return out
}

/// The step values a model's piece is built from: v a key's value (its usual one when not typed).
func newPiece(_ type: String, _ v: (String) -> Int, _ ws: Workshop, _ name: String, now: Ms = 0) -> Furniture {
    let x = W_GAP_SIDE
    var walls = ["A"]
    let mods: [Module]
    switch type {
    case "bed":
        let o = ItemOpt(bed: optAt(v("bt"), BED_KINDS), mw: v("mw"), ml: v("ml"), hb: v("hb"))
        mods = [itemModule("bed", ws, "A", x, 0, v("h"), 0, o)]
    case "bunk":
        let o = ItemOpt(mw: v("mw"), ml: v("ml"), ladder: optAt(v("lad"), ["L", "R"]))
        mods = [itemModule("bunk", ws, "A", x, 0, v("h"), 0, o)]
    case "loft":
        let o = ItemOpt(mw: v("mw"), ml: v("ml"), ladder: optAt(v("lad"), ["L", "R"]), under: optAt(v("und"), UNDER_KINDS))
        let bed = itemModule("loft", ws, "A", x, 0, v("h"), 0, o)
        var l = [bed]
        if let u = loftUnder(o.under, ws, bed) { l.append(u) }
        mods = l
    case "dining", "coffee":
        let o = ItemOpt(legs: optAt(v("lg"), LEG_KINDS), top: v("tp") == 1 ? "wt" : "ldsp", round: v("rc") == 1)
        mods = [itemModule("table", ws, "A", x, v("w"), v("h"), v("d"), o)]
    case "bar": mods = [itemModule("bar", ws, "A", x, v("w"), v("h"), v("d"), ItemOpt(top: "wt"))]
    case "mirrorP": mods = [itemModule("hooks", ws, "A", x, v("w"), v("h"), 0, ItemOpt(hooks: 4, shelf: true, mirW: 450, mirH: 1000), elev: 300)]
    case "stenka": mods = stenka(ws, v("w"), v("h"), v("d"))
    case "cornerW": walls = ["A", "B"]; mods = cornerWard(ws, v("w"), v("w2"), v("h"), v("d"))
    case "cornerDesk": walls = ["A", "B"]; mods = cornerDesk(ws, v("w"), v("w2"), v("h"), v("d"))
    case "vitrina": mods = vitrina(ws, v("w"), v("h"), v("d"))
    case "washer": mods = washer(ws, v("w"), v("h"), v("d"))
    default: mods = oneCabinet(type, v, ws)
    }
    let f = Furniture(id: uid(), kind: "wardrobe", name: name, roomId: nil, walls: walls, modules: mods, mats: BATH_TYPES.contains(type) ? bathMats() : FMats(),
                      created: now, model: type, type: type)
    return packPiece(f, nil, ws: ws)
}

/// The index of k in list, 0 when it is not there.
private func indexIn(_ list: [String], _ k: String) -> Int { list.firstIndex(of: k) ?? 0 }

/// One cabinet's step values: its width, depth and height as asked, its height above the floor, how it stands, its mirror.
private func cabinetVals(_ f: Furniture, _ main: Module, _ ws: Workshop) -> [String: Int] {
    var out: [String: Int] = ["w": main.w, "d": main.d]
    if HUNG_TYPES.contains(f.type) { out["h"] = main.h; out["e"] = main.elev }
    else if MOUNT_TYPES.contains(f.type) { out["h"] = topOf(main, ws); out["mt"] = hung(main) ? 1 : 0 }
    else { out["h"] = outerH(main, ws) }
    if let r = f.modules.first(where: { $0.type == "mirror" }) { out["rw"] = r.w; out["rh"] = r.h }
    return out
}

/// A newer model's piece as step values (Steps.swift valsOf).
func pieceVals(_ f: Furniture, _ ws: Workshop) -> [String: Int] {
    guard let main = wardOfF(f) else { return [:] }
    let o = main.opt ?? ItemOpt()
    let bs = boxes(f)
    switch f.type {
    case "bed": return ["bt": indexIn(BED_KINDS, o.bed), "mw": o.mw, "ml": o.ml, "h": main.h, "hb": o.hb]
    case "bunk": return ["mw": o.mw, "ml": o.ml, "h": main.h, "lad": o.ladder == "L" ? 0 : 1]
    case "loft": return ["mw": o.mw, "ml": o.ml, "h": main.h, "lad": o.ladder == "L" ? 0 : 1, "und": indexIn(UNDER_KINDS, o.under)]
    case "dining", "coffee":
        return ["w": main.w, "d": main.d, "h": main.h, "lg": indexIn(LEG_KINDS, o.legs), "tp": o.top == "wt" ? 1 : 0, "rc": o.round ? 1 : 0]
    case "bar": return ["w": main.w, "h": main.h, "d": main.d]
    case "mirrorP": return ["w": main.w, "h": main.h]
    case "stenka":
        let fl = bs.filter { !hung($0) }
        let top: Int = fl.map { topOf($0, ws) }.max() ?? 0
        let deep: Int = fl.map(\.d).max() ?? 0
        return ["w": runLen(f), "h": top, "d": deep]
    case "cornerW", "cornerDesk":
        let w0: String? = f.walls.first
        let w1: String? = f.walls.count > 1 ? f.walls[1] : nil
        let a = bs.filter { $0.wall == w0 }, b = bs.filter { $0.wall == w1 }
        let d = a.last?.d ?? main.d
        let wa: Int = a.reduce(0) { $0 + $1.w }
        let wb: Int = b.reduce(0) { $0 + $1.w }
        let top: Int = bs.map { topOf($0, ws) }.max() ?? 0
        return ["w": wa, "w2": d + wb, "h": top, "d": d]
    case "vitrina", "washer":
        let top: Int = bs.map { topOf($0, ws) }.max() ?? 0
        return ["w": main.w, "h": top, "d": main.d]
    default: return cabinetVals(f, main, ws)
    }
}

/// An item with new step values: its sizes and its other options kept.
private func itemResized(_ f: Furniture, _ main: Module, _ v: [String: Int], _ ws: Workshop) -> Furniture {
    var m = main
    for k in ["w", "h", "d", "mw", "ml", "hb"] { if let x = v[k] { m = itemSet(m, k, x, ws) } }
    var o = m.opt ?? ItemOpt()
    if let i = v["bt"], i >= 0, i < BED_KINDS.count { o.bed = BED_KINDS[i] }
    if let i = v["lad"] { o.ladder = i == 0 ? "L" : "R" }
    if let i = v["lg"], i >= 0, i < LEG_KINDS.count { o.legs = LEG_KINDS[i] }
    if let i = v["tp"] { o.top = i == 1 ? "wt" : "ldsp" }
    if let i = v["rc"] { o.round = i == 1 }
    m.opt = o
    let nm = itemSized(m, ws)
    var out = f
    out.modules = f.modules.map { $0.id == main.id ? nm : $0 }
    return out
}

/// A newer model's piece with new step values: an item keeps its other options, a cabinet its sections (spread again
/// over a new width); the pieces of several boxes are built again from their sizes.
func pieceResized(_ f: Furniture, _ v: [String: Int], _ ws: Workshop) -> Furniture {
    guard let main = wardOfF(f) else { return f }
    let cur = pieceVals(f, ws)
    func g(_ k: String) -> Int { v[k] ?? cur[k] ?? 0 }
    if PIECE_TYPES.contains(f.type) || f.type == "loft" {
        let n = newPiece(f.type, g, ws, f.name, now: f.created)
        var r = onWalls(n, f.walls.isEmpty ? n.walls : f.walls)
        r.id = f.id; r.roomId = f.roomId; r.ws = f.ws; r.mats = f.mats; r.keep = f.keep; r.pose = f.pose; r.model = f.model
        return CORNER_TYPES.contains(f.type) ? r : shiftRun(r, runStart(f))
    }
    if ITEM_TYPES.contains(f.type) { return itemResized(f, main, v, ws) }
    // one cabinet: as the older types, with its height above the floor, how it stands and its mirror
    var m = main
    let w = g("w"), d = g("d")
    if w != m.w { m.sections = splitSections(w, unlocked(m.sections)) }
    m.w = w; m.d = d
    if HUNG_TYPES.contains(f.type) {
        m.h = g("h"); m.elev = g("e")
    } else if MOUNT_TYPES.contains(f.type) {
        if g("mt") == 1 {
            let e = hung(m) ? m.elev : 300
            m.legs = false; m.base = 0; m.elev = e; m.h = max(300, g("h") - e)
        } else {
            m.legs = true; m.base = nil; m.elev = 0; m.h = max(300, g("h") - ws.legH)
        }
    } else {
        m.h = g("h") - legsOf(m, ws)
    }
    let nm = m
    var out = f
    out.modules = f.modules.map { x in
        if x.id == main.id { return nm }
        if x.type == "mirror" { var r = x; r.w = v["rw"] ?? x.w; r.h = v["rh"] ?? x.h; return r }
        return x
    }
    return packPiece(out, ws: ws)
}

/// What a box of a piece is called in the designer (strings key): a stenka's tall or low piece or shelf, a corner's arms, a stack's halves.
func boxRole(_ f: Furniture, _ m: Module) -> String {
    if CORNER_TYPES.contains(f.type) {
        let w1: String? = f.walls.count > 1 ? f.walls[1] : nil
        if m.wall == w1 { return "pc.armB" }
        if m.sections.contains(where: { $0.blind > 0 }) { return "pc.corner" }
        return "pc.armA"
    }
    if STACK_TYPES.contains(f.type) { return hung(m) ? "pc.upper" : "pc.lower" }
    if f.type == "loft" && m.type == "wardrobe" { return "pc.under" }
    if hung(m) { return "pc.shelf" }
    return m.h >= 1200 ? "pc.tall" : "pc.low"
}
