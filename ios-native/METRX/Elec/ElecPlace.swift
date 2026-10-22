import Foundation

/*
 * A room as the devices see it, the room kits, and placing (Android elec/Place.kt): a kit's points put on the walls and
 * ceiling at their usual spots, clear of the doors, windows, the door's swing and the water and gas; a device dragged on
 * its wall snaps to the usual heights and lines and is kept off the doors and windows.
 */

/// Water and gas on the walls: what sockets keep away from.
let WATER_T: Set<String> = ["cold", "hot", "sewer"]
let GAS_T: Set<String> = ["gas", "meter"]
let WATER_MM = 600
let GAS_MM = 500

/// One room for the electrician: a measured room, or one typed by size (free, drawn as a plain box with a door). g its
/// walls and floor (plan mm), kind what room it is, er its settings, entry the door the cables come in by.
struct ECtx {
    let id: String
    let room: Room
    let g: TRoomGeo
    let kind: String
    let er: ElecRoom
    var free: ElecFree? = nil

    var H: Int { tInt(g.H) }
    var doors: [Opening] { room.openings.filter { $0.type == "door" } }
    var entry: Opening? {
        let ds = doors
        return ds.first { $0.id == er.door } ?? ds.first
    }
    func wall(_ id: String?) -> TWall? {
        guard let id else { return nil }
        return g.wall(id)
    }
    /// Water and gas points on the walls.
    var wet: [SitePoint] { room.points.filter { WATER_T.contains($0.t) || GAS_T.contains($0.t) } }
    /// The plan point of a device's centre (a wall device: on the wall's face).
    func planOf(_ d: ElecDev) -> V2 {
        let c = V2(Double(d.cx), Double(d.cy))
        if d.onCeiling { return c }
        return wall(d.wall)?.at(Double(d.off)) ?? c
    }
    func planOf(_ x: SitePoint) -> V2? { wall(x.wall)?.at(Double(x.off)) }
}

/// The made-up room of a room typed by size: f's box with a door on wall A.
func eFreeRoom(_ f: ElecFree) -> Room {
    var r = Room(id: "free:" + f.id, floorId: "", name: f.name)
    r.dims = ["A": Dim(v: f.L), "B": Dim(v: f.W), "H": Dim(v: f.H), "T": Dim(v: 120, src: "default")]
    r.openings = [Opening(id: "fd", type: "door", wall: "A", w: 900, h: min(2100, f.H - 200), off: 300)]
    r.floorColor = "#DDE2E8"
    return r
}

/// Room rid of order p, ready for devices (nil: not measured yet); its kind guessed when not set (guessKind).
func ctxOf(_ p: Project, _ rid: String, _ snap: Bool) -> ECtx? {
    if rid.hasPrefix("free:") {
        guard let f = p.elec.free.first(where: { "free:" + $0.id == rid }) else { return nil }
        return freeCtx(f)
    }
    guard let r = p.rooms.first(where: { $0.id == rid }), let g = roomGeo(r, snap, []) else { return nil }
    let er = p.elec.room(rid)
    let kind = er.kind.isEmpty ? guessKind(p.floors.first { $0.id == r.floorId }?.type, r.name) : er.kind
    return ECtx(id: rid, room: r, g: g, kind: kind, er: er)
}

func freeCtx(_ f: ElecFree) -> ECtx? {
    let r = eFreeRoom(f)
    guard let g = roomGeo(r, true, []) else { return nil }
    return ECtx(id: r.id, room: r, g: g, kind: f.kind, er: ElecRoom(roomId: r.id, kind: f.kind, link: f.link), free: f)
}

/// Every room of the order that devices can be in: the measured ones in order, then the typed ones.
func ctxs(_ p: Project, _ snap: Bool) -> [ECtx] {
    p.rooms.compactMap { ctxOf(p, $0.id, snap) } + p.elec.free.compactMap { freeCtx($0) }
}

/// The devices of a room: placed ones, or a typed room's made from its counts.
func devsIn(_ p: Project, _ c: ECtx) -> [ElecDev] {
    if let f = c.free { return freeDevs(f, c) }
    return p.elec.devs.filter { $0.roomId == c.id }
}

/* ---------------- walls: what is in the way ---------------- */

/// Something on a wall a device must not overlap: a0…a1 along it, b0…b1 up, mm.
struct EBlock {
    let a0: Double, a1: Double, b0: Double, b1: Double
    init(_ a0: Double, _ a1: Double, _ b0: Double, _ b1: Double) { self.a0 = a0; self.a1 = a1; self.b0 = b0; self.b1 = b1 }
    func hits(_ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double) -> Bool { x0 < a1 && a0 < x1 && y0 < b1 && b0 < y1 }
}

/// The stretch behind a door when it stands open (its hinge side, as wide as the door): no switch there.
func swingBlock(_ o: Opening) -> EBlock { EBlock(Double(o.off) - Double(o.w), Double(o.off), 0, Double(o.h)) }

/// What is in the way of a device of type t on wall: the doors and windows with their frames, the columns and niches;
/// for a switch the door's swing; for a socket the water (WATER_MM) and gas (GAS_MM); the other devices devs and the
/// panel. skip a device being moved.
func blocksOn(_ c: ECtx, _ wall: String, _ t: String, _ devs: [ElecDev], _ panel: ElecPanel? = nil, skip: String? = nil, openingsOnly: Bool = false) -> [EBlock] {
    var out: [EBlock] = []
    for o in c.room.openings where o.wall == wall {
        let a0 = Double(o.off), ow = Double(o.w), oh = Double(o.h), s = Double(o.sill)
        if o.type == "door" { out.append(EBlock(a0 - 120, a0 + ow + 120, -1, oh + 80)) }
        else { out.append(EBlock(a0 - 100, a0 + ow + 100, s - 100, s + oh + 100)) }
    }
    if c.g.rect {
        for f in c.room.features where f.wall == wall {
            let a0 = Double(f.off), fw = Double(f.w)
            if f.type == "column" { out.append(EBlock(a0 - 50, a0 + fw + 50, -1, c.g.H + 1)) }
            else {
                let top = f.h > 0 ? f.sill + f.h : c.H
                out.append(EBlock(a0 - 50, a0 + fw + 50, Double(f.sill) - 50, Double(top) + 50))
            }
        }
    }
    if openingsOnly { return out }
    let ty = devType(t)
    if ty.cat == "sw" {
        for o in c.room.openings where o.wall == wall && o.type == "door" { out.append(swingBlock(o)) }
    }
    if ty.cat == "sock" {
        for x in c.wet where x.wall == wall {
            let r = Double(WATER_T.contains(x.t) ? WATER_MM : GAS_MM)
            out.append(EBlock(Double(x.off) - r, Double(x.off) + r, Double(x.h) - r, Double(x.h) + r))
        }
    }
    for d in devs where d.wall == wall && d.id != skip {
        let (dw, dh) = devSize(d)
        let hw = Double(dw) / 2, hh = Double(dh) / 2
        out.append(EBlock(Double(d.off) - hw - 60, Double(d.off) + hw + 60, Double(d.h) - hh - 60, Double(d.h) + hh + 60))
    }
    if let panel, panel.roomId == c.id, panel.wall == wall {
        let (pw, ph) = panelSize(0)
        let hw = Double(pw) / 2, hh = Double(ph) / 2
        out.append(EBlock(Double(panel.off) - hw - 100, Double(panel.off) + hw + 100, Double(panel.h) - hh - 100, Double(panel.h) + hh + 100))
    }
    return out
}

/// The free spot nearest prefer along wall w for a dw × dh device centred h up, mm, clear of blocks and 100 from the
/// corners; nil when the wall has none.
func spotOn(_ w: TWall, _ prefer: Double, _ h: Int, _ dw: Int, _ dh: Int, _ blocks: [EBlock]) -> Int? {
    let half = Double(dw) / 2
    let lo = half + 100, hi = w.len - half - 100
    if hi < lo { return nil }
    let p0 = eClamp(prefer, lo, hi)
    let y0 = Double(h) - Double(dh) / 2, y1 = Double(h) + Double(dh) / 2
    func free(_ x: Double) -> Bool { !blocks.contains { $0.hits(x - half, x + half, y0, y1) } }
    var k = 0
    while Double(k) * 10 <= w.len {
        let step = Double(k * 10)
        let a = p0 + step
        if a <= hi && free(a) { return eRound(a) }
        let b = p0 - step
        if k > 0 && b >= lo && free(b) { return eRound(b) }
        k += 1
    }
    return nil
}

/* ---------------- choosing the walls ---------------- */

private func eHasType(_ c: ECtx, _ w: TWall, _ type: String) -> Bool { c.room.openings.contains { $0.wall == w.id && $0.type == type } }

/// The room's main wall (beds, TVs): long, without a door, best without a window.
func mainWall(_ c: ECtx) -> TWall {
    eMaxBy(c.g.walls) { w in
        let door: Double = eHasType(c, w, "door") ? 5000 : 0
        let win: Double = eHasType(c, w, "window") ? 1500 : 0
        return w.len - door - win
    } ?? c.g.walls[0]
}

/// The worktop's (or a bathroom's sink) wall: the one with most water on it, else a long one without a door.
func workWall(_ c: ECtx) -> TWall {
    let wet = c.room.points.filter { WATER_T.contains($0.t) }
    if !wet.isEmpty {
        return eMaxBy(c.g.walls) { w in Double(wet.filter { $0.wall == w.id }.count) * 100_000 + w.len } ?? c.g.walls[0]
    }
    return eMaxBy(c.g.walls) { w in
        let door: Double = eHasType(c, w, "door") ? 5000 : 0
        let win: Double = eHasType(c, w, "window") ? 300 : 0
        return w.len - door - win
    } ?? c.g.walls[0]
}

/// A wall with a window (a desk stands at it), else the main wall.
func windowWall(_ c: ECtx) -> TWall { eMaxBy(c.g.walls.filter { eHasType(c, $0, "window") }) { $0.len } ?? mainWall(c) }

/// The water point on wall w (a sink), along it.
private func waterOn(_ c: ECtx, _ w: TWall) -> Int? { c.room.points.first { $0.wall == w.id && WATER_T.contains($0.t) }?.off }

/* ---------------- kits ---------------- */

/// One point of a kit: type t placed by rule at (n of them), at height h (nil: the usual), dx from the rule's spot.
struct KItem: Equatable {
    let t: String
    let at: String
    var n = 1
    var h: Int? = nil
    var dx = 0
}

/// A room kit of the gallery: the points a room of kind usually gets.
struct ElecKit {
    let id: String
    let kind: String
    let items: [KItem]
}

private func ki(_ t: String, _ at: String, _ n: Int = 1, h: Int? = nil, dx: Int = 0) -> KItem { KItem(t: t, at: at, n: n, h: h, dx: dx) }

let KITS: [ElecKit] = [
    ElecKit(id: "kt.std", kind: "kitchen", items: [ki("k2", "door"), ki("lc", "ceil"), ki("led", "under"), ki("s2", "work", 3, h: 1100), ki("pst", "stove"),
                                                   ki("pov", "oven"), ki("s1", "fridge"), ki("s1", "hood", h: 2000), ki("s1", "dw"), ki("jb", "box")]),
    ElecKit(id: "kt.spots", kind: "kitchen", items: [ki("k2", "door"), ki("ls", "spots"), ki("led", "under"), ki("s2", "work", 4, h: 1100), ki("pst", "stove"),
                                                     ki("s1", "fridge"), ki("s1", "hood", h: 2000), ki("jb", "box")]),
    ElecKit(id: "kt.small", kind: "kitchen", items: [ki("k1", "door"), ki("lc", "ceil"), ki("s2", "work", 2, h: 1100), ki("s1", "fridge"), ki("s1", "hood", h: 2000),
                                                     ki("jb", "box")]),
    ElecKit(id: "bt.std", kind: "bath", items: [ki("k2", "door"), ki("ls", "spots"), ki("lw", "mirror"), ki("sw", "mirrorS"), ki("pwh", "wh"), ki("sw", "wm", h: 1000),
                                                ki("jb", "box")]),
    ElecKit(id: "bt.small", kind: "bath", items: [ki("k1", "door"), ki("lc", "ceil"), ki("sw", "mirrorS"), ki("sw", "wm", h: 1000), ki("jb", "box")]),
    ElecKit(id: "bd.std", kind: "bed", items: [ki("k1", "door"), ki("lch", "ceil"), ki("s2", "bed", 2, h: 700), ki("lw", "bed", 2, h: 1300), ki("s1", "corner", 2),
                                               ki("pac", "ac"), ki("jb", "box")]),
    ElecKit(id: "bd.kids", kind: "bed", items: [ki("k1", "door"), ki("lc", "ceil"), ki("s1", "corner", 3), ki("s2", "desk", dx: 0), ki("lan", "desk", dx: 250),
                                                ki("jb", "box")]),
    ElecKit(id: "lv.tv", kind: "living", items: [ki("k2", "door"), ki("lch", "ceil"), ki("tv", "tv", dx: -180), ki("s2", "tv", dx: 180), ki("lan", "tv", dx: -380),
                                                 ki("led", "cove"), ki("s1", "corner", 3), ki("pac", "ac"), ki("jb", "box")]),
    ElecKit(id: "lv.spots", kind: "living", items: [ki("kd", "door"), ki("ls", "spots"), ki("tv", "tv", dx: -180), ki("s2", "tv", dx: 180), ki("s1", "corner", 2),
                                                    ki("lw", "pair", 2), ki("pac", "ac"), ki("jb", "box")]),
    ElecKit(id: "hl.std", kind: "hall", items: [ki("kp", "door"), ki("lc", "row", 2), ki("s1", "doorIn"), ki("int", "door2"), ki("bell", "door3"), ki("jb", "box")]),
    ElecKit(id: "hl.spots", kind: "hall", items: [ki("k1", "door"), ki("ls", "row", 4), ki("s1", "doorIn"), ki("int", "door2"), ki("cam", "cam"), ki("jb", "box")]),
    ElecKit(id: "of.std", kind: "office", items: [ki("k1", "door"), ki("lc", "ceil"), ki("s2", "desk", dx: -200), ki("s2", "desk", dx: 200), ki("lan", "desk", dx: 450),
                                                  ki("su", "desk", dx: -450), ki("s1", "corner", 2), ki("pac", "ac"), ki("jb", "box")])
]

func kitOf(_ id: String) -> ElecKit? { KITS.first { $0.id == id } }

/// A kit's choices (the steps): the main light ("lc", "lch", "ls"; "" as the kit has), an LED strip, AC power, the
/// low-voltage points.
struct KitOpts: Equatable {
    var light = ""
    var led = true
    var ac = true
    var low = true
}

func defaultOpts(_ k: ElecKit) -> KitOpts {
    KitOpts(light: "", led: k.items.contains { $0.t == "led" }, ac: k.items.contains { $0.t == "pac" }, low: k.items.contains { devType($0.t).cat == "low" })
}

/// The kit's points with the choices made.
func kitItems(_ k: ElecKit, _ o: KitOpts) -> [KItem] {
    var items = k.items
    if !o.light.isEmpty {
        items = items.map { i -> KItem in
            if !devType(i.t).ceil { return i }
            if o.light == "ls" && i.at == "ceil" { return KItem(t: "ls", at: "spots") }
            if o.light == "ls" { return KItem(t: "ls", at: i.at, n: max(i.n, 3)) }
            if i.at == "spots" { return KItem(t: o.light, at: "ceil") }
            return KItem(t: o.light, at: i.at, n: i.at == "row" ? min(i.n, 2) : i.n)
        }
    }
    if !o.led { items = items.filter { $0.t != "led" } }
    else if !items.contains(where: { $0.t == "led" }) { items.append(KItem(t: "led", at: k.kind == "kitchen" ? "under" : "cove")) }
    if !o.ac { items = items.filter { $0.t != "pac" } }
    else if !items.contains(where: { $0.t == "pac" }) && k.kind != "bath" && k.kind != "hall" { items.append(KItem(t: "pac", at: "ac")) }
    if !o.low { items = items.filter { devType($0.t).cat != "low" } }
    return items
}

/// Spots over the ceiling: a grid about 1,1 m apart, 0,5 m and more from the walls, inside the room.
func spotGrid(_ c: ECtx) -> [V2] {
    let f = c.g.floor
    let b = tBoxOf(f)
    let nx = eClampI(eRound((b.x1 - b.x0 - 600) / 1100), 1, 6)
    let ny = eClampI(eRound((b.y1 - b.y0 - 600) / 1100), 1, 6)
    var out: [V2] = []
    for i in 0..<nx {
        for k in 0..<ny {
            let qx = b.x0 + (b.x1 - b.x0) * (Double(i) + 0.5) / Double(nx)
            let qy = b.y0 + (b.y1 - b.y0) * (Double(k) + 0.5) / Double(ny)
            let q = V2(qx, qy)
            if eInside(f, q) { out.append(q) }
        }
    }
    return out
}

/// Lights in a row along the room's longer side.
func rowOf(_ c: ECtx, _ n: Int) -> [V2] {
    let f = c.g.floor
    let b = tBoxOf(f)
    let along = b.x1 - b.x0 >= b.y1 - b.y0
    var out: [V2] = []
    for i in 0..<max(n, 0) {
        let t = (Double(i) + 0.5) / Double(n)
        let q = along ? V2(b.x0 + (b.x1 - b.x0) * t, (b.y0 + b.y1) / 2) : V2((b.x0 + b.x1) / 2, b.y0 + (b.y1 - b.y0) * t)
        if eInside(f, q) { out.append(q) }
    }
    return out.isEmpty ? [centreOf(c)] : out
}

/// The middle of the room's floor (its centroid; inside it).
func centreOf(_ c: ECtx) -> V2 { centreOf(c.g.floor) }

/// The middle of floor outline f (its centroid; inside it).
func centreOf(_ f: [V2]) -> V2 {
    let n = f.count
    var a = 0.0, cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0
    for i in 0..<n {
        let p = f[i], q = f[(i + 1) % n]
        let k = p.x * q.y - q.x * p.y
        a += k; cx += (p.x + q.x) * k; cy += (p.y + q.y) * k
        sx += p.x; sy += p.y
    }
    let avg = V2(sx / Double(max(n, 1)), sy / Double(max(n, 1)))
    let m = abs(a) < 1e-6 ? avg : V2(cx / (3 * a), cy / (3 * a))
    return eInside(f, m) ? m : avg
}

/// Whether plan point q is inside the floor f (even-odd).
func eInside(_ f: [V2], _ q: V2) -> Bool {
    var c = false
    let n = f.count
    for i in 0..<n {
        let a = f[i], b = f[(i + 1) % n]
        if (a.y > q.y) != (b.y > q.y) {
            let xs = (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x
            if q.x < xs { c = !c }
        }
    }
    return c
}

/// The points of kit k (with choices o0, nil: its defaults) placed in room c among the devices it already has (have):
/// each at its usual height, the spot its rule picks, moved along the wall clear of what is in the way. id makes the
/// new ids.
func placeKit(_ k: ElecKit, _ c: ECtx, _ have: [ElecDev], _ id: @escaping () -> String, _ o0: KitOpts? = nil, _ panel: ElecPanel? = nil) -> [ElecDev] {
    let o = o0 ?? defaultOpts(k)
    var out: [ElecDev] = []
    let H = c.H
    let entry = c.entry
    let dw0: TWall = entry.flatMap { c.wall($0.wall) } ?? c.g.walls[0]
    let main = mainWall(c), work = workWall(c), win = windowWall(c)
    var others = c.g.walls.filter { $0.id != main.id && $0.id != dw0.id }
    if others.isEmpty { others = c.g.walls.filter { $0.id != main.id } }
    if others.isEmpty { others = c.g.walls }
    var corner = 0
    let sinkX: Double? = waterOn(c, work).map { Double($0) }
    // the stove: away from the sink, else at the worktop's far part
    var stoveX = work.len * 0.7
    if let s = sinkX { stoveX = s + 1200 < work.len - 300 ? s + 1200 : max(400, s - 1200) }

    func put(_ t: String, _ w: TWall, _ prefer: Double, _ h: Int, _ len: Int = 0) {
        let ty = devType(t)
        if t == "led" {
            // a strip goes on the longest stretch of the wall clear of its doors and windows at its height
            guard let st = freeStretch(c, w, h) else { return }
            let a = st.0, b = st.1
            let l = min(len, tInt(b - a - 100))
            if l < 300 { return }
            let ld = Double(len)
            let x: Double = b - a >= ld + 100 ? eClamp(prefer, a + ld / 2 + 50, b - ld / 2 - 50) : (a + b) / 2
            out.append(ElecDev(id: id(), t: t, roomId: c.id, wall: w.id, off: eRound(x), h: h, len: l, kit: k.id))
            return
        }
        guard let x = spotOn(w, prefer, h, ty.dw, ty.dh, blocksOn(c, w.id, t, have + out, panel)) else { return }
        out.append(ElecDev(id: id(), t: t, roomId: c.id, wall: w.id, off: x, h: h, kit: k.id))
    }
    func onCeil(_ t: String, _ q: V2) {
        out.append(ElecDev(id: id(), t: t, roomId: c.id, wall: nil, cx: eRound(q.x), cy: eRound(q.y), kit: k.id))
    }

    let doorEnd: Double = entry.map { Double($0.off + $0.w) } ?? 300
    for item in kitItems(k, o) {
        let ty = devType(item.t)
        let h = item.h ?? usualH(item.t, H, c.kind)
        let n = item.n
        let hw = Double(ty.dw) / 2
        let dx = Double(item.dx)
        switch item.at {
        case "door": put(item.t, dw0, doorEnd + 150 + hw, h)
        case "door2": put(item.t, dw0, doorEnd + 420 + hw, h)
        case "door3": put(item.t, dw0, doorEnd + 650 + hw, h)
        case "doorIn": put(item.t, dw0, doorEnd + 450, h)
        case "cam": put(item.t, dw0, doorEnd + 700, h)
        case "box":
            let at: Double = entry.map { Double($0.off) + Double($0.w) / 2 } ?? 400
            put(item.t, dw0, at, absH(-ZONE_DOWN, H))
        case "main":
            for i in 0..<max(n, 0) { put(item.t, main, main.len * Double(i + 1) / Double(n + 1), h) }
        case "bed":
            for s in [-1.0, 1.0].prefix(max(n, 0)) { put(item.t, main, main.len / 2 + s * 1050 + dx, h) }
        case "pair":
            for s in [-1.0, 1.0].prefix(max(n, 0)) { let w = others[0]; put(item.t, w, w.len / 2 + s * 800, h) }
        case "tv": put(item.t, main, main.len / 2 + dx, h)
        case "desk": put(item.t, win, win.len / 3 + dx, h)
        case "corner":
            for _ in 0..<max(n, 0) {
                let w = others[(corner / 2) % others.count]
                put(item.t, w, corner % 2 == 0 ? 400 : w.len - 400, h)
                corner += 1
            }
        case "work":
            for i in 0..<max(n, 0) { put(item.t, work, work.len * Double(i + 1) / Double(n + 1), h) }
        case "stove": put(item.t, work, stoveX, h)
        case "oven": put(item.t, work, stoveX + 350, h)
        case "hood": put(item.t, work, stoveX, h)
        case "fridge":
            var fx = work.len - 350
            if let s = sinkX, s > work.len / 2 { fx = 350 }
            put(item.t, work, fx, h)
        case "dw": put(item.t, work, (sinkX ?? work.len / 2) + 650, h)
        case "ac": put(item.t, main, main.len - 450, h)
        case "wh": put(item.t, work, (sinkX ?? (work.len - 500)) + 700, h)
        case "mirror": put(item.t, work, sinkX ?? (work.len / 2), h)
        case "mirrorS": put(item.t, work, (sinkX ?? (work.len / 2)) + 650, h)
        case "wm":
            let w = others.first { $0.id != work.id } ?? work
            put(item.t, w, w.len - 450, h)
        case "cove": put("led", main, main.len / 2, absH(-60, H), max(tInt(main.len - 300), 300))
        case "under":
            let l = max(tInt(min(work.len - 400, 2400)), 300)
            put("led", work, work.len / 2, 1450, l)
        case "ceil": onCeil(item.t, centreOf(c))
        case "spots": for q in spotGrid(c) { onCeil(item.t, q) }
        case "row": for q in rowOf(c, n) { onCeil(item.t, q) }
        default: break
        }
    }
    return out
}

/// The longest stretch of wall w at height h clear of its doors and windows (with their frames), mm along it.
func freeStretch(_ c: ECtx, _ w: TWall, _ h: Int) -> (Double, Double)? {
    let hd = Double(h)
    let bl = blocksOn(c, w.id, "led", [], openingsOnly: true).filter { $0.b0 <= hd && $0.b1 >= hd }
    let cuts = eSortedBy(bl.map { ($0.a0, $0.a1) }) { $0.0 }
    var out: [(Double, Double)] = []
    var cur = 50.0
    for cut in cuts {
        if cut.0 > cur { out.append((cur, cut.0)) }
        cur = max(cur, cut.1)
    }
    if w.len - 50 > cur { out.append((cur, w.len - 50)) }
    return eMaxBy(out) { $0.1 - $0.0 }
}

/* ---------------- a room typed by size ---------------- */

/// A typed room's devices from its counts: switches by the door, sockets round the walls, lights over the ceiling.
func freeDevs(_ f: ElecFree, _ c: ECtx) -> [ElecDev] {
    var out: [ElecDev] = []
    var n = 0
    func nid() -> String { let s = "f:\(f.id):\(n)"; n += 1; return s }
    guard let a = c.g.wall("A") else { return [] }
    let dEnd = Double(c.entry.map { $0.off + $0.w } ?? 300)
    for i in 0..<eClampI(f.sw, 0, 20) {
        if let x = spotOn(a, dEnd + 200 + Double(i) * 180, 900, 86, 86, blocksOn(c, "A", "k1", out)) {
            out.append(ElecDev(id: nid(), t: "k1", roomId: c.id, wall: "A", off: x, h: 900))
        }
    }
    let ws = c.g.walls.filter { $0.id != "A" } + [a]
    var k = 0
    for _ in 0..<eClampI(f.sock, 0, 60) {
        let w = ws[k % ws.count]
        let slot = k / ws.count
        k += 1
        let prefer = w.len * Double(slot % 3 + 1) / 4
        if let x = spotOn(w, prefer, 300, 86, 86, blocksOn(c, w.id, "s1", out)) {
            out.append(ElecDev(id: nid(), t: "s1", roomId: c.id, wall: w.id, off: x, h: 300))
        }
    }
    let hp = absH(-300, c.H)
    for i in 0..<eClampI(f.power, 0, 10) {
        let w = ws[(i + 1) % ws.count]
        if let x = spotOn(w, w.len - 400, hp, 86, 86, blocksOn(c, w.id, "pac", out)) {
            out.append(ElecDev(id: nid(), t: "pac", roomId: c.id, wall: w.id, off: x, h: hp))
        }
    }
    let all = c.g.walls
    for i in 0..<eClampI(f.low, 0, 20) {
        let w = all[(2 + i) % all.count]
        if let x = spotOn(w, w.len / 2 + Double(i) * 200, 300, 86, 86, blocksOn(c, w.id, "lan", out)) {
            out.append(ElecDev(id: nid(), t: "lan", roomId: c.id, wall: w.id, off: x, h: 300))
        }
    }
    let lights = eClampI(f.light, 0, 40)
    let pts = lights <= 1 ? [centreOf(c)] : rowOf(c, lights)
    for q in pts.prefix(lights) {
        out.append(ElecDev(id: nid(), t: lights <= 1 ? "lc" : "ls", roomId: c.id, wall: nil, cx: eRound(q.x), cy: eRound(q.y)))
    }
    return out
}

/// A kit's counts for a room typed by size: sockets, switches, lights, low-voltage and power points.
func freeOf(_ k: ElecKit, _ o: KitOpts, _ id: String, _ name: String, _ L: Int, _ W: Int, _ H: Int) -> ElecFree {
    let items = kitItems(k, o)
    func cnt(_ f: (KItem) -> Bool) -> Int {
        var s = 0
        for it in items where f(it) { s += it.at == "spots" ? 4 : it.n }
        return s
    }
    var e = ElecFree(id: id, name: name, kind: k.kind, L: L, W: W, H: H)
    e.sock = cnt { devType($0.t).cat == "sock" && devType($0.t).group == "sock" }
    e.sw = cnt { devType($0.t).cat == "sw" }
    e.light = cnt { devType($0.t).ceil }
    e.low = cnt { devType($0.t).cat == "low" }
    e.power = cnt { devType($0.t).cat == "sock" && devType($0.t).group != "sock" }
    e.kit = k.id
    return e
}

/* ---------------- moving a device ---------------- */

/// Where a device dragged to (rawOff, rawH) on its wall lands: snapped heights and lines, clear of the doors and windows.
func snapWall(_ c: ECtx, _ d: ElecDev, _ rawOff: Int, _ rawH: Int, _ devs: [ElecDev]) -> (Int, Int) {
    guard let w = c.wall(d.wall) else { return (rawOff, rawH) }
    let (dw, dh) = devSize(d)
    let H = c.H
    let hs = snapHeights(H) + [usualH(d.t, H, c.kind)]
    // off the usual heights a device moves in whole centimetres
    let nh = eMinBy(hs) { Double(abs($0 - rawH)) }
    var h0 = (rawH + 5) / 10 * 10
    if let nh, abs(nh - rawH) <= 80 { h0 = nh }
    let h = eClampI(h0, dh / 2 + 30, max(dh / 2 + 30, H - dh / 2 - 30))
    // Kotlin's dw / 2 here is a whole number
    let hwInt = Double(dw / 2)
    var xs: [Double] = []
    for o in c.room.openings where o.wall == w.id {
        xs.append(Double(o.off + o.w) + 150 + hwInt)
        xs.append(Double(o.off) - 150 - hwInt)
    }
    for x in devs where x.wall == w.id && x.id != d.id && x.t != "led" { xs.append(Double(x.off)) }
    xs.append(300 + hwInt)
    xs.append(w.len - 300 - hwInt)
    let rx = Double(rawOff)
    let nx = eMinBy(xs) { abs($0 - rx) }
    var x00 = Double((rawOff + 5) / 10 * 10)
    if let nx, abs(nx - rx) <= 60 { x00 = nx }
    let half = Double(dw) / 2
    let x0 = eClamp(x00, half + 50, max(half + 50, w.len - half - 50))
    let bl = blocksOn(c, w.id, d.t, [], openingsOnly: true)
    let hh = Double(h), vh = Double(dh) / 2
    let clear = !bl.contains { $0.hits(x0 - half, x0 + half, hh - vh, hh + vh) }
    let x = clear ? eRound(x0) : (spotOn(w, x0, h, dw, dh, bl) ?? eRound(x0))
    return (x, h)
}

/// Where a ceiling device dragged to plan point (x, y) lands: on the room's middle lines when near them, inside the room.
func snapCeil(_ c: ECtx, _ x: Double, _ y: Double) -> (Int, Int) {
    let m = centreOf(c)
    let sx = abs(x - m.x) <= 80 ? m.x : x
    let sy = abs(y - m.y) <= 80 ? m.y : y
    let f = c.g.floor
    let b = tBoxOf(f)
    let q = V2(eClamp(sx, b.x0 + 100, b.x1 - 100), eClamp(sy, b.y0 + 100, b.y1 - 100))
    return eInside(f, q) ? (eRound(q.x), eRound(q.y)) : (eRound(m.x), eRound(m.y))
}

/* ---------------- the panel ---------------- */

/// The panel's box for modules (0: a 24-module one), mm wide × high.
func panelSize(_ modules: Int) -> (Int, Int) {
    if modules >= 1 && modules <= 12 { return (260, 300) }
    if (modules >= 13 && modules <= 24) || modules == 0 { return (320, 420) }
    if modules >= 25 && modules <= 36 { return (320, 560) }
    return (320, 700)
}

/// Where the panel goes by default: the hallway (or the room with most doors), on the entrance door's wall beside it.
func defaultPanel(_ p: Project, _ snap: Bool) -> ElecPanel? {
    let cs = p.rooms.compactMap { ctxOf(p, $0.id, snap) }
    guard let c = cs.first(where: { $0.kind == "hall" }) ?? eMaxBy(cs, { Double($0.doors.count) }) else { return nil }
    return panelIn(c, p.elec.devs.filter { $0.roomId == c.id })
}

/// The panel put in room c: beside its first door (the entrance), clear of the devices there.
func panelIn(_ c: ECtx, _ devs: [ElecDev]) -> ElecPanel {
    let e = c.doors.first
    let w = e.flatMap { c.wall($0.wall) } ?? mainWall(c)
    let (pw, ph) = panelSize(0)
    let bl = blocksOn(c, w.id, "jb", devs)
    let pref: Double = e.map { Double($0.off + $0.w) + 700 } ?? (w.len / 2)
    let x = spotOn(w, pref, PANEL_H, pw, ph, bl) ?? spotOn(w, w.len / 2, PANEL_H, pw, ph, []) ?? eRound(w.len / 2)
    return ElecPanel(roomId: c.id, wall: w.id, off: x, h: PANEL_H, entry: e?.id)
}

/// Dragging the panel along its wall: the usual heights, clear of doors and windows.
func snapPanel(_ c: ECtx, _ pn: ElecPanel, _ rawOff: Int, _ rawH: Int) -> ElecPanel {
    guard let w = c.wall(pn.wall) else { return pn }
    let (pw, ph) = panelSize(0)
    let nh = eMinBy([PANEL_H, 1500, 1700, 1800]) { Double(abs($0 - rawH)) }
    var h0 = (rawH + 5) / 10 * 10
    if let nh, abs(nh - rawH) <= 80 { h0 = nh }
    let h = eClampI(h0, ph / 2 + 300, max(ph / 2 + 300, c.H - ph / 2 - 50))
    let half = Double(pw) / 2
    let x0 = eClamp(Double((rawOff + 5) / 10 * 10), half + 50, max(half + 50, w.len - half - 50))
    let bl = blocksOn(c, w.id, "jb", [], openingsOnly: true)
    let x = spotOn(w, x0, h, pw, ph, bl) ?? eRound(x0)
    var out = pn
    out.off = x; out.h = h
    return out
}

/// Nearest distance from plan point q to the walls: the wall, how far along it, how far away.
func nearestWall(_ c: ECtx, _ q: V2) -> (TWall, Double, Double) { nearestWall(c.g.walls, q) }

/// Nearest distance from plan point q to walls ws: the wall, how far along it, how far away.
func nearestWall(_ ws: [TWall], _ q: V2) -> (TWall, Double, Double) {
    var best = (ws[0], 0.0, Double.greatestFiniteMagnitude)
    var first = true
    for w in ws {
        let a = eClamp((q - w.p0).dot(w.t), 0, w.len)
        let p = w.at(a)
        let d = hypot(q.x - p.x, q.y - p.y)
        if first || d < best.2 { best = (w, a, d); first = false }
    }
    return best
}

/// The site points of a room taken in as devices: its sockets as single sockets and switches as single switches.
func fromSitePoints(_ c: ECtx, _ id: () -> String) -> [ElecDev] {
    var out: [ElecDev] = []
    for x in c.room.points where (x.t == "socket" || x.t == "switch") && !c.er.seen.contains(x.id) {
        if c.wall(x.wall) == nil { continue }
        out.append(ElecDev(id: id(), t: x.t == "socket" ? "s1" : "k1", roomId: c.id, wall: x.wall, off: x.off, h: min(max(x.h, 60), c.H - 60), from: x.id))
    }
    return out
}
