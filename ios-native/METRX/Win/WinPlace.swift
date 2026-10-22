import Foundation

/*
 * Rooms as the windows-and-doors maker sees them (Android win/Place.kt): a measured room's openings with the products
 * filling them, or a product without a room shown in a made-up wall. A product stands centred in its opening, its frame
 * in the middle of the wall's thickness; seen from inside, x along it runs the same way as along the wall. From that:
 * where its opening sashes and a door's leaf sweep into the room, and what stands there (a plumber's radiator or
 * fixture, the furniture).
 */

/// One room: a measured one, or the made-up wall of a product without a room (free). T the wall's thickness, mm.
struct WCtx {
    let id: String
    let room: Room
    let g: TRoomGeo
    let T: Int
    var free: WinItem? = nil

    func wall(_ id: String?) -> TWall? {
        guard let id else { return nil }
        return g.wall(id)
    }
    func opening(_ id: String?) -> Opening? { room.openings.first { $0.id == id } }
}

/// The made-up room of a product without a room: a wall W_FREE_T (or its own) thick with the opening it fits, a sill at
/// 850 for a window.
func wFreeRoom(_ it: WinItem) -> Room {
    let door = it.isDoor || it.kind == "balc" || it.h >= W_DOOR_SASH_H
    let ow = it.w + 2 * it.gap
    let oh = it.h + (door ? it.gap : 2 * it.gap)
    let sill = door ? 0 : 850
    let L = max(2600, ow + 1800)
    let H = max(2700, sill + oh + 300)
    let t = min(max(it.freeT, 80), 800)
    var r = Room(id: "free:" + it.id, floorId: "", name: it.name)
    r.dims = ["A": Dim(v: L), "B": Dim(v: 3000), "H": Dim(v: H), "T": Dim(v: t, src: "default")]
    r.openings = [Opening(id: "fo", type: door ? "door" : "window", wall: "A", w: ow, h: oh, off: (L - ow) / 2, sill: sill)]
    r.wallColor = "#ECE8E1"
    r.floorColor = "#DDE2E8"
    return r
}

/// Room rid of order p (or "free:<id>" a product without a room), nil until it is measured.
func wCtxOf(_ p: Project, _ rid: String, _ snap: Bool) -> WCtx? {
    if rid.hasPrefix("free:") {
        guard let it = p.win.items.first(where: { "free:" + $0.id == rid }) else { return nil }
        return wFreeCtx(it)
    }
    guard let r = p.rooms.first(where: { $0.id == rid }), let g = roomGeo(r, snap, []) else { return nil }
    return WCtx(id: rid, room: r, g: g, T: r.dim("T").v ?? 200)
}

func wFreeCtx(_ it: WinItem) -> WCtx? {
    let r = wFreeRoom(it)
    guard let g = roomGeo(r, true, []) else { return nil }
    return WCtx(id: r.id, room: r, g: g, T: r.dim("T").v ?? W_FREE_T, free: it)
}

/// Every measured room of the order, then each product without a room.
func wCtxs(_ p: Project, _ snap: Bool) -> [WCtx] {
    var out: [WCtx] = p.rooms.compactMap { wCtxOf(p, $0.id, snap) }
    for it in p.win.items where !it.inRoom {
        if let c = wFreeCtx(it) { out.append(c) }
    }
    return out
}

/// The products of room c.
func wItemsIn(_ p: Project, _ c: WCtx) -> [WinItem] {
    if let f = c.free { return [f] }
    return p.win.items.filter { $0.roomId == c.id }
}

/// A product where it stands: its opening o on wall w, its left edge a0 along the wall, its bottom z0, the reveal r
/// inside its frame.
struct WPlaced {
    let it: WinItem
    let o: Opening
    let w: TWall
    let a0: Double
    let z0: Double
    let T: Int
    var depth: Int { wFrameDepth(it) }
    var r: Int { wRevealOf(T, depth) }
    /// The frame's inside face, mm into the room (negative: in the wall).
    var dIn: Double { -Double(r) }
    var dOut: Double { -Double(r + depth) }
    var doorOpening: Bool { o.type == "door" }
}

/// Product it in room c, or nil when its opening is gone.
func wPlaced(_ c: WCtx, _ it: WinItem) -> WPlaced? {
    let o0: Opening? = c.free != nil ? c.room.openings.first : c.opening(it.opening)
    guard let o = o0, let w = c.wall(o.wall) else { return nil }
    let a0 = Double(o.off) + Double(o.w - it.w) / 2.0
    let lift: Double = o.type == "door" ? 0 : Double(o.h - it.h) / 2.0
    let z0 = Double(o.sill) + lift
    return WPlaced(it: it, o: o, w: w, a0: a0, z0: z0, T: c.T)
}

func wPlacedIn(_ p: Project, _ c: WCtx) -> [WPlaced] { wItemsIn(p, c).compactMap { wPlaced(c, $0) } }

/// A new product of type k filling opening o of room c: its size the opening's less gap each side; a window's sill and
/// drip.
func wFillOpening(_ id: String, _ k: WinKind, _ c: WCtx, _ o: Opening, _ gap: Int) -> WinItem {
    let s = wSizeFor(o.w, o.h, o.type, gap)
    var it = wNewItem(id, k, s.0, s.1, gap: gap, roomId: c.id, opening: o.id)
    if k.isDoor { return it }
    let r = wRevealOf(c.T, wFrameDepth(it))
    if o.type == "window" && o.sill > 0 {
        it.sill = wSillFor(r)
        it.drip = true
    } else {
        it.drip = o.type == "window"
    }
    return it
}

/// The openings of room c a type kind can fill.
func wOpeningsFor(_ c: WCtx, _ kind: String) -> [Opening] { c.room.openings.filter { wFillsType(kind, $0.type) } }

/* ---------------- what sweeps into the room ---------------- */

/// Floor a sash or leaf sweeps into the room: poly on the plan, z0…z1 its heights, mm; item and sash what it is.
struct WSweep {
    let item: String
    let sash: Int
    let poly: [V2]
    let z0: Double
    let z1: Double
}

/// The square a leaf lw wide hinged at ah along wall w sweeps into the room (dir +1 when it opens towards growing a),
/// set back r in the wall.
private func wSweepPoly(_ w: TWall, _ ah: Double, _ lw: Double, _ dir: Int, _ r: Double) -> [V2]? {
    let reach = lw - r
    if reach <= 1 { return nil }
    let a1 = ah + Double(dir) * lw
    let lo = min(ah, a1), hi = max(ah, a1)
    return [w.at(lo, 0), w.at(hi, 0), w.at(hi, reach), w.at(lo, reach)]
}

/// Where product pl's turning sashes sweep into the room (a tilt only leans in, a slider slides); a door's leaf.
func wSashSweeps(_ pl: WPlaced) -> [WSweep] {
    let item = pl.it
    if item.isDoor {
        if let d = wDoorSweep(pl) { return [d] }
        return []
    }
    var out: [WSweep] = []
    for (i, s) in wSashesOf(item).enumerated() {
        if !W_SWINGS.contains(s.t) { continue }
        let left = s.cell.hinge != "R"
        let ah = pl.a0 + (left ? s.r.x0 : s.r.x1)
        if let poly = wSweepPoly(pl.w, ah, s.r.w, left ? 1 : -1, Double(pl.r)) {
            out.append(WSweep(item: item.id, sash: i, poly: poly, z0: pl.z0 + s.r.y0, z1: pl.z0 + s.r.y1))
        }
    }
    return out
}

/// Where a door's leaf sweeps into the room when it opens in (a sliding door or one opening out: nothing here).
func wDoorSweep(_ pl: WPlaced) -> WSweep? {
    let item = pl.it
    if !item.isDoor || item.kind == "dsl" || item.swing != "in" { return nil }
    let leaf = Double(item.w - 2 * W_DOOR_FRAME)
    let left = item.hinge != "R"
    let ah = pl.a0 + (left ? Double(W_DOOR_FRAME) : Double(item.w - W_DOOR_FRAME))
    guard let poly = wSweepPoly(pl.w, ah, leaf, left ? 1 : -1, 0) else { return nil }
    return WSweep(item: item.id, sash: -1, poly: poly, z0: pl.z0, z1: pl.z0 + Double(item.h))
}

/// An unfilled door's usual swing (hinged at its start, opening in), as the other trades draw it.
func wOpenSwing(_ c: WCtx, _ o: Opening) -> WSweep? {
    guard let w = c.wall(o.wall), let poly = wSweepPoly(w, Double(o.off), Double(o.w), 1, 0) else { return nil }
    return WSweep(item: "op:" + o.id, sash: -1, poly: poly, z0: 0, z1: Double(o.h))
}

/// Something standing in a room: what a strings key, its footprint, its heights; id the plumber's fixture or the
/// furniture.
struct WObst {
    let what: String
    let id: String
    let poly: [V2]
    let z0: Double
    let z1: Double
}

/// What stands in room c: the plumber's fixtures (radiators first of all) and the furniture's boxes, when the order has
/// them.
func wObstaclesIn(_ p: Project, _ c: WCtx, _ snap: Bool) -> [WObst] {
    if c.free != nil { return [] }
    var out: [WObst] = []
    let fixes = p.plumb.fixes.filter { $0.roomId == c.id }
    if !fixes.isEmpty, let pc = pCtxOf(p, c.id, snap) {
        for f in fixes {
            guard let poly = fixPoly(pc, f) else { continue }
            let what = f.t == "rad" || f.t == "tr" ? "dw.ob.rad" : "dw.ob.fix"
            out.append(WObst(what: what, id: f.id, poly: poly, z0: Double(fixZ0(f)), z1: Double(fixTop(f))))
        }
    }
    let fs = p.furniture.filter { $0.roomId == c.id }
    if !fs.isEmpty {
        let walls = planWalls(c.room, snap)
        if !walls.isEmpty {
            for f in fs {
                for ft in footsOf(f, walls, Workshop()) {
                    let poly = ft.pts.map { V2($0.x, $0.y) }
                    out.append(WObst(what: "dw.ob.furn", id: f.id, poly: poly, z0: Double(ft.lo), z1: Double(ft.hi)))
                }
            }
        }
    }
    return out
}
