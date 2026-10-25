import Foundation

/*
 * Board-built furniture that is not a cabinet (decided 22 Oct 2026; Android furniture/Items.kt): beds (plain on legs,
 * drawers under, a lift-up base over a storage box), bunk and loft beds, tables (dining, coffee), the bar counter, the
 * hallway's mirror panel with hooks, and the mirror over a dressing table. Each is one module with a few options (ItemOpt);
 * its boards (itemBoards) make both its parts and its 3D, so the cut list and the picture always agree. Pure Swift,
 * unit-tested (PiecesTests). The sizes and the construction are defaults for the founder's makers to check.
 */

/// The module types of these pieces (Module.type).
let ITEM_MODS: Set<String> = ["bed", "bunk", "loft", "table", "bar", "hooks", "mirror"]

/// The ladder of a bunk or loft bed stands this far out from the frame's front.
let LADDER_D = 60

/// A bed's mattress lies this far below the top of its frame (the frame holds it).
let BED_SINK = 60

/// One board of a piece, or something only the 3D shows: its part (key, strings fp.*; "" not a part) and role
/// (carcass, front; or for the picture only: top, mattress, lamel, metal, mirror, white); where it is, a0..a1 across,
/// y0..y1 up from the floor, n0..n1 out from the back, mm. lift: it rises with a lift-up base; round: a table top's
/// corner radius.
struct Board: Equatable {
    let key: String, role: String
    let a0: Int, a1: Int, y0: Int, y1: Int, n0: Int, n1: Int
    var lift = false
    var round = 0
    init(_ key: String, _ role: String, _ a0: Int, _ a1: Int, _ y0: Int, _ y1: Int, _ n0: Int, _ n1: Int, lift: Bool = false, round: Int = 0) {
        self.key = key; self.role = role; self.a0 = a0; self.a1 = a1; self.y0 = y0; self.y1 = y1; self.n0 = n0; self.n1 = n1
        self.lift = lift; self.round = round
    }
}

/// A drawer under a bed: on its left (side -1) or right (+1) side, n0..n1 along the bed, y0..y1 up; its box depth deep.
struct BedDrawer: Equatable { let side: Int, n0: Int, n1: Int, y0: Int, y1: Int, depth: Int }

/// A bed's drawers: two a side (one when short), both sides from a 1400 mattress, else the right one.
func bedDrawers(_ m: Module, _ ws: Workshop) -> [BedDrawer] {
    guard let o = m.opt, m.type == "bed", o.bed == "drawers" else { return [] }
    let t = ws.t
    let sides: [Int] = o.mw >= 1400 ? [-1, 1] : [1]
    let n = o.ml >= 1800 ? 2 : 1
    let len = m.d - 2 * t
    let fw = (len - (n + 1) * 3) / n
    let y1 = m.h - 90 - 3
    let depth = sides.count == 2 ? m.w / 2 - t - t / 2 - 20 : m.w - 2 * t - 40
    var out: [BedDrawer] = []
    for s in sides {
        for i in 0..<n {
            let n0 = t + 3 + i * (fw + 3)
            out.append(BedDrawer(side: s, n0: n0, n1: n0 + fw, y0: 40, y1: y1, depth: depth))
        }
    }
    return out
}

/// A loft or bunk bed's upper platform (the top of its slats), mm from the floor.
func upperDeck(_ m: Module) -> Int { m.type == "loft" ? m.h - 450 : m.h - 500 }

/// The front of a bunk or loft bed's frame (its ladder stands in front of it).
func frameD(_ m: Module) -> Int { m.type == "bunk" || m.type == "loft" ? m.d - LADDER_D : m.d }

/// A table's or bar counter's top: 38 of worktop board, or the front board (twice, glued, on a dining table or a bar).
func topT(_ m: Module, _ ws: Workshop) -> Int {
    let o = m.opt ?? ItemOpt()
    return o.top == "wt" ? 38 : ws.t * (m.h >= 650 ? 2 : 1)
}

/// A bed's boards.
private func bedBoards(_ m: Module, _ ws: Workshop, _ out: inout [Board]) {
    let t = ws.t, o = m.opt ?? ItemOpt()
    let W = m.w, D = m.d, H = m.h
    let hb = max(o.hb, H + 100)
    let yb = o.bed == "legs" ? max(0, H - 260) : 0
    let yp = H - BED_SINK
    out.append(Board("fp.headboard", "front", 0, W, 0, hb, 0, t))
    out.append(Board("fp.footboard", "front", 0, W, yb, H, D - t, D))
    let dr = bedDrawers(m, ws)
    for s in [-1, 1] {
        let a0 = s < 0 ? 0 : W - t
        // over drawers the side is a strip along the top; else a whole board
        if dr.contains(where: { $0.side == s }) { out.append(Board("fp.sideRail", "front", a0, a0 + t, H - 90, H, t, D - t)) }
        else { out.append(Board("fp.bedSide", "front", a0, a0 + t, yb, H, t, D - t)) }
    }
    // a spine down the middle of a wide bed carries the slats (and parts the drawers or the box)
    if o.mw >= 1400 { out.append(Board("fp.spine", "carcass", W / 2 - t / 2, W / 2 + t - t / 2, yb, yp - 50, t, D - t)) }
    // the drawers run between cross boards; a one-sided row has a board behind it
    var sidesSeen: [Int] = []
    for d in dr where !sidesSeen.contains(d.side) { sidesSeen.append(d.side) }
    for s in sidesSeen {
        let row = dr.filter { $0.side == s }
        let a0 = s < 0 ? t : W - t - row[0].depth - 20
        for i in 0..<(row.count - 1) {
            let c = row[i].n1 + 1
            out.append(Board("fp.dCase", "carcass", a0, a0 + row[0].depth + 20, 0, yp - 50, c - t / 2, c + t - t / 2))
        }
    }
    if !dr.isEmpty && o.mw < 1400 {
        let b1 = W - t - dr[0].depth - 20
        out.append(Board("fp.dBack", "carcass", b1 - t, b1, 0, yp - 50, t, D - t))
    }
    if o.bed == "lift" { out.append(Board("fp.boxBottom", "carcass", t, W - t, 30, 30 + t, t, D - t)) }
    if o.bed == "legs" {
        // metal legs at the foot and halfway along; the headboard stands on the floor
        for n in [D - t - 60, D / 2 - 20] {
            for a in [t + 10, W - t - 50] { out.append(Board("", "metal", a, a + 40, 0, yb, n, n + 40)) }
        }
        if o.mw >= 1400 { out.append(Board("", "metal", W / 2 - 20, W / 2 + 20, 0, yb, D / 2 - 20, D / 2 + 20)) }
    }
    // what the picture shows on it: the slats (they rise with a lift-up base), the mattress, pillows
    let lift = o.bed == "lift"
    out.append(Board("", "lamel", t + 4, W - t - 4, yp - 30, yp, t + 4, D - t - 4, lift: lift))
    out.append(Board("", "mattress", t + 6, W - t - 6, yp, yp + 200, t + 6, D - t - 6, lift: lift))
    let two = o.mw >= 1200
    let pw = two ? (W - 2 * t - 60) / 2 : W - 2 * t - 60
    for i in (two ? [0, 1] : [0]) {
        let a0 = t + 20 + i * (pw + 20)
        out.append(Board("", "white", a0, a0 + pw, yp + 200, yp + 320, t + 40, t + 400, lift: lift))
    }
}

/// A bunk or loft bed's boards.
private func bunkBoards(_ m: Module, _ ws: Workshop, _ out: inout [Board]) {
    let t = ws.t, o = m.opt ?? ItemOpt()
    let W = m.w, D = m.d, H = m.h
    let fd = frameD(m)
    let yu = upperDeck(m)
    let right = o.ladder == "R"
    out.append(Board("fp.bedSide", "front", 0, t, 0, H, 0, fd))
    out.append(Board("fp.bedSide", "front", W - t, W, 0, H, 0, fd))
    // the upper level: a high guard along the wall, the front rail, and a guard over it but at the ladder
    out.append(Board("fp.guard", "front", t, W - t, yu - 120, H - 60, 0, t))
    out.append(Board("fp.bedRail", "front", t, W - t, yu - 120, yu + 150, fd - t, fd))
    let open = 550
    if right { out.append(Board("fp.guard", "front", t, W - t - open, yu + 150, yu + 330, fd - t, fd)) }
    else { out.append(Board("fp.guard", "front", t + open, W - t, yu + 150, yu + 330, fd - t, fd)) }
    out.append(Board("", "lamel", t + 4, W - t - 4, yu - 30, yu, t + 4, fd - t - 4))
    out.append(Board("", "mattress", t + 6, W - t - 6, yu, yu + 180, t + 6, fd - t - 6))
    let pa0 = t + (right ? 30 : W - 2 * t - 530)
    let pa1 = t + (right ? 530 : W - 2 * t - 30)
    out.append(Board("", "white", pa0, pa1, yu + 180, yu + 290, t + 40, fd - t - 40))
    if m.type == "bunk" {
        let yl = 300
        out.append(Board("fp.bedRail", "front", t, W - t, 120, yl + 150, 0, t))
        out.append(Board("fp.bedRail", "front", t, W - t, 120, yl + 150, fd - t, fd))
        out.append(Board("", "lamel", t + 4, W - t - 4, yl - 30, yl, t + 4, fd - t - 4))
        out.append(Board("", "mattress", t + 6, W - t - 6, yl, yl + 180, t + 6, fd - t - 6))
        out.append(Board("", "white", t + 30, t + 530, yl + 180, yl + 290, t + 40, fd - t - 40))
    } else { out.append(Board("fp.bedRail", "front", t, W - t, 100, 250, 0, t)) }
    // the ladder at one end of the front: two stringers and its rungs
    let la0 = right ? W - t - 30 - 420 : t + 30
    let la1 = la0 + 420
    let top = yu + 330
    out.append(Board("fp.ladder", "front", la0, la0 + t, 0, top, fd, D))
    out.append(Board("fp.ladder", "front", la1 - t, la1, 0, top, fd, D))
    var y = 260
    while y < yu - 40 { out.append(Board("fp.rung", "front", la0 + t, la1 - t, y, y + t, fd, D)); y += 260 }
}

/// A table's boards (and its metal legs or frame).
private func tableBoards(_ m: Module, _ ws: Workshop, _ out: inout [Board]) {
    let t = ws.t, o = m.opt ?? ItemOpt()
    let W = m.w, D = m.d, H = m.h
    let tt = topT(m, ws)
    let wt = o.top == "wt"
    let r = o.round ? min(120, min(W, D) / 4) : 0
    let key = o.round ? "fp.topR" : "fp.top"
    if wt { out.append(Board("", "top", 0, W, H - tt, H, 0, D, round: r)) }
    else { for k in 0..<(tt / t) { out.append(Board(key, "front", 0, W, H - tt + k * t, H - tt + (k + 1) * t, 0, D, round: r)) } }
    let y1 = H - tt
    switch o.legs {
    case "metal4":
        // a frame of strips under the top, a straight metal leg in each corner
        out.append(Board("fp.apron", "carcass", 70, W - 70, y1 - 80, y1, 70, 70 + t))
        out.append(Board("fp.apron", "carcass", 70, W - 70, y1 - 80, y1, D - 70 - t, D - 70))
        out.append(Board("fp.apron", "carcass", 70, 70 + t, y1 - 80, y1, 70 + t, D - 70 - t))
        out.append(Board("fp.apron", "carcass", W - 70 - t, W - 70, y1 - 80, y1, 70 + t, D - 70 - t))
        for a in [30, W - 70] { for n in [30, D - 70] { out.append(Board("", "metal", a, a + 40, 0, y1, n, n + 40)) } }
    case "frame":
        for a in [50, W - 90] {
            // a U of square tube at each end: two posts, the foot and the top bar
            for n in [50, D - 90] { out.append(Board("", "metal", a, a + 40, 30, y1 - 30, n, n + 40)) }
            out.append(Board("", "metal", a, a + 40, 0, 30, 30, D - 30))
            out.append(Board("", "metal", a, a + 40, y1 - 30, y1, 50, D - 50))
        }
    default:
        out.append(Board("fp.tLeg", "front", 60, 60 + t, 0, y1, 50, D - 50))
        out.append(Board("fp.tLeg", "front", W - 60 - t, W - 60, 0, y1, 50, D - 50))
        // a dining table's legs are held by a board under the top; a coffee table's by a shelf low down
        if H >= 650 { out.append(Board("fp.apron", "front", 60 + t, W - 60 - t, y1 - 150, y1, D / 2 - t / 2, D / 2 + t - t / 2)) }
        else { out.append(Board("fp.shelf", "front", 60 + t, W - 60 - t, 100, 100 + t, 50, D - 50)) }
    }
}

/// A bar counter's boards.
private func barBoards(_ m: Module, _ ws: Workshop, _ out: inout [Board]) {
    let t = ws.t, o = m.opt ?? ItemOpt()
    let W = m.w, D = m.d, H = m.h
    let tt = topT(m, ws)
    let db = max(250, D - o.over)
    let y1 = H - tt
    out.append(Board("fp.side", "front", 0, t, 0, y1, 0, db))
    out.append(Board("fp.side", "front", W - t, W, 0, y1, 0, db))
    out.append(Board("fp.barFront", "front", t, W - t, 0, y1, db - t, db))
    out.append(Board("fp.plinth", "carcass", t, W - t, 0, 60, 30, 30 + t))
    out.append(Board("fp.bottom", "carcass", t, W - t, 60, 60 + t, 0, db - t))
    let mid = W > 1200
    if mid { out.append(Board("fp.divider", "carcass", W / 2 - t / 2, W / 2 + t - t / 2, 60 + t, y1, 0, db - t)) }
    if o.shelves {
        for k in 1...2 {
            let y = 60 + t + k * (y1 - 60 - t) / 3
            if mid {
                out.append(Board("fp.shelf", "carcass", t, W / 2 - t / 2, y, y + t, 20, db - t - 2))
                out.append(Board("fp.shelf", "carcass", W / 2 + t - t / 2, W - t, y, y + t, 20, db - t - 2))
            } else { out.append(Board("fp.shelf", "carcass", t, W - t, y, y + t, 20, db - t - 2)) }
        }
    }
    if o.top == "wt" { out.append(Board("", "top", 0, W, y1, H, 0, D)) }
    else { for k in 0..<(tt / t) { out.append(Board("fp.top", "front", 0, W, y1 + k * t, y1 + (k + 1) * t, 0, D)) } }
    if o.foot {
        out.append(Board("", "metal", 40, W - 40, 230, 262, db + 110, db + 142))
        for a in [80, W - 112] { out.append(Board("", "metal", a, a + 32, 238, 254, db, db + 110)) }
    }
}

/// A mirror panel's boards: the panel, its mirror, hooks and hat shelf.
private func hooksBoards(_ m: Module, _ ws: Workshop, _ out: inout [Board]) {
    let t = ws.t, o = m.opt ?? ItemOpt()
    let W = m.w, H = m.h, E = m.elev
    out.append(Board("fp.panel", "front", 0, W, E, E + H, 0, t))
    var mirR = 0
    var mirB = E + H
    if o.mirW > 0 && o.mirH > 0 {
        let mw = min(o.mirW, W - 160), mh = min(o.mirH, H - 200)
        out.append(Board("", "mirror", 80, 80 + mw, E + H - 120 - mh, E + H - 120, t, t + 4))
        mirR = 80 + mw
        mirB = E + H - 120 - mh
    }
    // the hooks in a row beside the mirror, a little under the top; no room beside it: across the panel under it
    let n = min(12, max(0, o.hooks))
    if n > 0 {
        let spread = n > 1 ? 40 * (n - 1) : 0
        let beside = mirR + 100 + spread <= W - 80
        let a0 = beside ? mirR + 100 : 80
        let a1 = W - 80
        let y = (beside || mirR == 0) ? E + H - 260 : max(E + 80, mirB - 100)
        for i in 0..<n {
            let a = n == 1 ? (a0 + a1) / 2 : a0 + (a1 - a0) * i / (n - 1)
            out.append(Board("", "metal", a - 8, a + 8, y - 60, y + 10, t, t + 60))
        }
    }
    if o.shelf {
        out.append(Board("fp.shelf", "front", 0, W, E + H, E + H + t, 0, 250))
        for a in [60, W - 76] { out.append(Board("", "metal", a, a + 16, E + H - 120, E + H, t, 200)) }
    }
}

/// The boards of an item module, in its own frame (its back's left end at 0, 0, 0).
func itemBoards(_ m: Module, _ ws: Workshop) -> [Board] {
    var out: [Board] = []
    switch m.type {
    case "bed": bedBoards(m, ws, &out)
    case "bunk", "loft": bunkBoards(m, ws, &out)
    case "table": tableBoards(m, ws, &out)
    case "bar": barBoards(m, ws, &out)
    case "hooks": hooksBoards(m, ws, &out)
    case "mirror": out.append(Board("", "mirror", 0, m.w, m.elev, m.elev + m.h, 0, 5))
    default: break
    }
    return out
}

/// The parts of an item module: its boards, each by its two larger sizes (seen boards banded all round), and a bed's drawers.
func itemParts(_ m: Module, _ ws: Workshop) -> [FPart] {
    let id = m.label.isEmpty ? m.id : m.label
    var out: [FPart] = []
    for b in itemBoards(m, ws) where !b.key.isEmpty && (b.role == "carcass" || b.role == "front") {
        let s = [b.a1 - b.a0, b.y1 - b.y0, b.n1 - b.n0].sorted(by: >)
        if b.role == "front" { out.append(part(b.key, id, "front", s[0], s[1], 1, ALL, ALL)) }
        else { out.append(part(b.key, id, "carcass", s[0], s[1], 1, THICK)) }
    }
    for d in bedDrawers(m, ws) {
        out.append(part("fp.dFace", id, "front", d.n1 - d.n0, d.y1 - d.y0, 1, ALL, ALL, grain: true))
        out += drawerBox(id, d.n1 - d.n0, d.depth, d.y1 - d.y0, ws.t)
    }
    return mergeParts(out)
}

/// An item module's hardware.
func itemHardware(_ m: Module, _ ws: Workshop, _ add: (String, Int) -> Void) {
    let o = m.opt ?? ItemOpt()
    switch m.type {
    case "bed":
        add("confirmat", o.mw >= 1400 ? 24 : 16)
        if o.bed == "lift" { add("bedLift", 1) } else { add("bedBase", 1) }
        if o.bed == "legs" { add("leg", 4 + (o.mw >= 1400 ? 1 : 0)) }
        let ds = bedDrawers(m, ws)
        // each drawer with its handle, or a push latch (HandleRules.swift)
        add("runner", ds.count); for i in ds.indices { add(hasHandle(m, "bd\(i)") ? "handle" : "push", 1) }
    case "bunk": add("bedBase", 2); add("confirmat", 36)
    case "loft": add("bedBase", 1); add("confirmat", 28)
    case "table":
        add("confirmat", 8)
        if o.legs == "metal4" { add("tableLeg", 4) } else if o.legs == "frame" { add("tableFrame", 1) }
    case "bar":
        add("confirmat", 20)
        if o.shelves { add("pin", 4 * (m.w > 1200 ? 4 : 2)) }
        if o.foot { add("barRail", m.w - 80) }
    case "hooks":
        add("hanger", 2); add("hook", min(12, max(0, o.hooks)))
        if o.mirW > 0 && o.mirH > 0 { add("mirror", min(o.mirW, m.w - 160) * min(o.mirH, m.h - 200)); add("clip", 4) }
        if o.shelf { add("confirmat", 4) }
    case "mirror": add("mirror", m.w * m.h); add("clip", 4)
    default: break
    }
}

/// Worktop board a table or bar counter's top takes, running mm (bought by the metre like a kitchen's).
func itemWorktopMm(_ m: Module) -> Int { (m.type == "table" || m.type == "bar") && m.opt?.top == "wt" ? m.w : 0 }

/// How high an item reaches: a bed's headboard, a mirror panel's hat shelf.
func itemTop(_ m: Module, _ ws: Workshop) -> Int {
    switch m.type {
    case "bed": return m.elev + max(m.h, m.opt?.hb ?? 0)
    case "hooks": return m.elev + m.h + (m.opt?.shelf == true ? ws.t : 0)
    default: return m.elev + m.h
    }
}

/// The module's outer size from its options: a bed round its mattress, a bunk or loft bed along it, a mirror panel's depth.
func itemSized(_ m: Module, _ ws: Workshop) -> Module {
    guard let o = m.opt else { return m }
    let t = ws.t
    var n = m
    switch m.type {
    case "bed": n.w = o.mw + 2 * t + 10; n.d = o.ml + 2 * t + 10
    case "bunk", "loft": n.w = o.ml + 2 * t + 10; n.d = o.mw + 2 * t + 10 + LADDER_D
    case "hooks": n.d = o.shelf ? 250 : t + 60
    default: break
    }
    return n
}

/// A new item module of type on wall at x: w × h × d where they are its own (tables, the bar, panels), o its options.
func itemModule(_ type: String, _ ws: Workshop, _ wall: String, _ x: Int, _ w: Int, _ h: Int, _ d: Int, _ o: ItemOpt, elev: Int = 0) -> Module {
    itemSized(Module(id: uid(), type: type, w: w, h: h, d: d, x: x, wall: wall, elev: elev, fronts: Fronts("open", 0), legs: false, base: 0, opt: o), ws)
}

/// The usual ranges of an item's sizes in its designer, mm.
func itemRange(_ m: Module, _ key: String) -> ClosedRange<Int> {
    switch key {
    case "mw": return m.type == "bed" ? 700...2000 : 700...1000
    case "ml": return m.type == "bed" ? 1800...2200 : 1600...2100
    case "hb": return 600...1600
    case "over": return 150...450
    case "mirW", "mirH": return 0...2000
    case "e": return 0...2200
    case "h":
        switch m.type {
        case "bed": return 250...700
        case "bunk", "loft": return 1400...2200
        case "table": return 300...900
        case "bar": return 900...1250
        case "hooks": return 600...2200
        default: return 300...2200
        }
    case "d":
        switch m.type {
        case "table": return 300...1200
        case "bar": return 400...900
        default: return 5...1000
        }
    default: return m.type == "table" || m.type == "bar" ? 400...3000 : 300...2400
    }
}

/// An item module with one size changed (and its outer size following).
func itemSet(_ m: Module, _ key: String, _ v: Int, _ ws: Workshop) -> Module {
    var n = m
    var o = m.opt ?? ItemOpt()
    var opt = false
    switch key {
    case "w": n.w = v
    case "h": n.h = v
    case "d": n.d = v
    case "e": n.elev = v
    case "mw": o.mw = v; opt = true
    case "ml": o.ml = v; opt = true
    case "hb": o.hb = v; opt = true
    case "over": o.over = v; opt = true
    case "mirW": o.mirW = v; opt = true
    case "mirH": o.mirH = v; opt = true
    case "hooks": o.hooks = v; opt = true
    default: break
    }
    if opt { n.opt = o }
    return itemSized(n, ws)
}

/// What a size of an item module is now (the designer's rows).
func itemGet(_ m: Module, _ key: String) -> Int {
    let o = m.opt ?? ItemOpt()
    switch key {
    case "w": return m.w
    case "h": return m.h
    case "d": return m.d
    case "e": return m.elev
    case "mw": return o.mw
    case "ml": return o.ml
    case "hb": return o.hb
    case "over": return o.over
    case "mirW": return o.mirW
    case "mirH": return o.mirH
    case "hooks": return o.hooks
    default: return 0
    }
}
