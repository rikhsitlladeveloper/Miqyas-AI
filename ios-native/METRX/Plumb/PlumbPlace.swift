import Foundation

/*
 * A room as the fixtures see it, the room kits and placing (Android plumb/Place.kt): a kit's fixtures stood against the
 * walls at their usual spots, clear of the doors, the windows, the door's swing, the riser and each other; a fixture
 * dragged along its wall snaps to the corners and its neighbours, its outlets go with it; loose outlets snap to the
 * usual heights.
 */

/// Water and drain points on the walls, as the furniture marks them.
let SITE_WATER: Set<String> = ["cold", "hot", "sewer"]

/// One room for the plumber: a measured room, or one typed by size (free, drawn as a plain box with a door). g its walls
/// and floor (plan mm), kind what room it is, pr its settings.
struct PCtx {
    let id: String
    let room: Room
    let g: TRoomGeo
    let kind: String
    let pr: PlRoom
    var free: PlFree? = nil

    var H: Int { tInt(g.H) }
    var doors: [Opening] { room.openings.filter { $0.type == "door" } }
    var entry: Opening? {
        let ds = doors
        return ds.first { $0.id == pr.door } ?? ds.first
    }
    func wall(_ id: String?) -> TWall? {
        guard let id else { return nil }
        return g.wall(id)
    }
    /// The floor's area, m².
    var areaM2: Double { abs(polyArea(g.floor)) / 1e6 }
}

/// The made-up room of a room typed by size: f's box with a door on wall A.
func pFreeRoom(_ f: PlFree) -> Room {
    var r = Room(id: "free:" + f.id, floorId: "", name: f.name)
    r.dims = ["A": Dim(v: f.L), "B": Dim(v: f.W), "H": Dim(v: f.H), "T": Dim(v: 120, src: "default")]
    r.openings = [Opening(id: "fd", type: "door", wall: "A", w: 800, h: min(2100, f.H - 200), off: 250)]
    r.floorColor = "#DDE2E8"
    return r
}

/// Room rid of order p, ready for fixtures (nil: not measured yet).
func pCtxOf(_ p: Project, _ rid: String, _ snap: Bool) -> PCtx? {
    if rid.hasPrefix("free:") {
        guard let f = p.plumb.free.first(where: { "free:" + $0.id == rid }) else { return nil }
        return pFreeCtx(f)
    }
    guard let r = p.rooms.first(where: { $0.id == rid }), let g = roomGeo(r, snap, []) else { return nil }
    let pr = p.plumb.room(rid)
    let kind = pr.kind.isEmpty ? pGuessKind(p.floors.first { $0.id == r.floorId }?.type, r.name) : pr.kind
    return PCtx(id: rid, room: r, g: g, kind: kind, pr: pr)
}

func pFreeCtx(_ f: PlFree) -> PCtx? {
    let r = pFreeRoom(f)
    guard let g = roomGeo(r, true, []) else { return nil }
    let pr = PlRoom(roomId: r.id, kind: f.kind, link: f.link, ufh: f.ufh)
    return PCtx(id: r.id, room: r, g: g, kind: f.kind, pr: pr, free: pWithKit(f))
}

/// A typed room saved before it kept its kit's choices (no towel rail, hand basin or cabin kept): those its kit has.
/// The same room when they are kept, or it has no kit.
func pWithKit(_ f: PlFree) -> PlFree {
    guard let k = pkitOf(f.kit) else { return f }
    if f.kept || f.tr > 0 || f.small || f.cabin { return f }
    let d = pFreeOf(k, k.opts, f.id, f.name, f.L, f.W, f.H)
    var out = f
    out.tr = d.tr
    out.small = d.small && f.basin > 0
    out.cabin = d.cabin && f.shower > 0
    return out
}

/// Every room of the order that fixtures can be in: the measured ones in order, then the typed ones.
func pCtxs(_ p: Project, _ snap: Bool) -> [PCtx] {
    p.rooms.compactMap { pCtxOf(p, $0.id, snap) } + p.plumb.free.compactMap { pFreeCtx($0) }
}

/// The fixtures of a room: placed ones, or a typed room's made from its counts.
func fixesIn(_ p: Project, _ c: PCtx) -> [PlFix] {
    if let f = c.free { return freeFixes(f, c) }
    return p.plumb.fixes.filter { $0.roomId == c.id }
}

/// One outlet where it is: a fixture's (fix its id, usual its usual height) or a loose one.
struct APt: Equatable {
    let id: String, t: String, roomId: String, wall: String, off: Int, h: Int, d: Int, fix: String?, usual: Int?, tol: Int
}

/// The outlets of a room: its fixtures' and the loose ones.
func pointsIn(_ p: Project, _ c: PCtx, _ fs0: [PlFix]? = nil) -> [APt] {
    let fs = fs0 ?? fixesIn(p, c)
    var out: [APt] = []
    for f in fs { out += fixPoints(f) }
    if c.free != nil { return out }
    for q in p.plumb.points where q.roomId == c.id {
        out.append(APt(id: q.id, t: q.t, roomId: q.roomId, wall: q.wall, off: q.off, h: q.h, d: q.d, fix: nil, usual: nil, tol: 0))
    }
    return out
}

/// A fixture's outlets on its wall.
func fixPoints(_ f: PlFix) -> [APt] {
    let ty = fixType(f.t)
    let usual = defaultPts(f.t, fixW(f))
    var out: [APt] = []
    for (i, q) in f.pts.enumerated() {
        let u: Int? = i < usual.count ? usual[i].h : nil
        out.append(APt(id: "\(f.id):\(i)", t: q.t, roomId: f.roomId, wall: f.wall, off: f.off + q.dx, h: q.h, d: q.d, fix: f.id, usual: u, tol: ty.tol))
    }
    return out
}

/* ---------------- footprints ---------------- */

/// A fixture's place on the plan: its four corners, grow mm larger all round.
func fixPoly(_ c: PCtx, _ f: PlFix, _ grow: Double = 0) -> [V2]? {
    guard let w = c.wall(f.wall) else { return nil }
    return boxPoly(w, Double(f.off), Double(fixW(f)), Double(fixD(f)), grow)
}

func boxPoly(_ w: TWall, _ x: Double, _ fw: Double, _ fd: Double, _ grow: Double = 0) -> [V2] {
    let a0 = x - fw / 2 - grow
    let a1 = x + fw / 2 + grow
    return [w.at(a0, -grow), w.at(a1, -grow), w.at(a1, fd + grow), w.at(a0, fd + grow)]
}

/// The floor a door sweeps as it opens into the room (its hinge at its start): the square round its quarter circle.
func swingPoly(_ c: PCtx, _ o: Opening) -> [V2]? {
    guard let w = c.wall(o.wall) else { return nil }
    let a0 = Double(o.off), a1 = Double(o.off + o.w), d = Double(o.w)
    return [w.at(a0), w.at(a1), w.at(a1, d), w.at(a0, d)]
}

/// The riser's box on the plan.
func riserPoly(_ c: PCtx, _ r: PlRiser, _ grow: Double = 0) -> [V2]? {
    guard let w = c.wall(r.wall) else { return nil }
    return boxPoly(w, Double(r.off), Double(RISER_W), Double(RISER_D), grow)
}

/// Whether convex polygons a and b overlap (separating axes; touching is not overlapping).
func convexHit(_ a: [V2], _ b: [V2]) -> Bool {
    if a.isEmpty || b.isEmpty { return false }
    for poly in [a, b] {
        let n = poly.count
        for i in 0..<n {
            let p = poly[i], q = poly[(i + 1) % n]
            let nv = V2(-(q.y - p.y), q.x - p.x)
            let ra = a.map { $0.dot(nv) }, rb = b.map { $0.dot(nv) }
            let raMax = ra.max()!, raMin = ra.min()!, rbMax = rb.max()!, rbMin = rb.min()!
            if raMax <= rbMin + 1e-6 || rbMax <= raMin + 1e-6 { return false }
        }
    }
    return true
}

/// Whether fixture f stands in the way of one of the room's doors as it opens.
func blocksDoor(_ c: PCtx, _ f: PlFix) -> Bool {
    guard let fpoly = fixPoly(c, f) else { return false }
    let half = Double(fixW(f)) / 2
    for o in c.doors {
        if let sp = swingPoly(c, o), convexHit(fpoly, sp) { return true }
        if o.wall == f.wall && Double(f.off) + half > Double(o.off) && Double(f.off) - half < Double(o.off + o.w) { return true }
    }
    return false
}

/// Whether a fixture of type t, fw wide, centred x along wall w fits: inside the wall and the room, off its doors and
/// the windows it would reach, out of every door's swing, clear of the riser, the columns and the fixtures others at its
/// height (opt a basin's cabinet).
func pFits(_ c: PCtx, _ t: String, _ w: TWall, _ x: Double, _ fw: Int, _ others: [PlFix], _ riser: PlRiser?, _ opt: String = "") -> Bool {
    let ty = fixType(t)
    let fd = Double(ty.d)
    let hw = Double(fw) / 2
    if x - hw < 10 || x + hw > w.len - 10 { return false }
    let fpoly = boxPoly(w, x, Double(fw), fd)
    var sx = 0.0, sy = 0.0
    for q in fpoly { sx += q.x; sy += q.y }
    let mid = V2(sx / 4, sy / 4)
    for q in fpoly {
        let l = max(hypot(mid.x - q.x, mid.y - q.y), 1.0)
        let inner = q + (mid - q) * (2.0 / l)
        if !eInside(c.g.floor, inner) { return false }
    }
    let z0 = opt == "cab" ? 0 : ty.z0
    let z1 = ty.h
    // the wall's own doors, and its windows where the fixture reaches up to them (a radiator stays under the sill)
    for o in c.room.openings where o.wall == w.id {
        let over = x + hw > Double(o.off) - 50 && x - hw < Double(o.off + o.w) + 50
        if !over { continue }
        if o.type == "door" { return false }
        if z1 > o.sill - 20 && z0 < o.sill + o.h { return false }
    }
    if c.g.rect {
        for f in c.room.features where f.wall == w.id {
            if x + hw > Double(f.off) - 20 && x - hw < Double(f.off + f.w) + 20 { return false }
        }
    }
    for o in c.doors {
        guard let sp = swingPoly(c, o) else { continue }
        if convexHit(fpoly, sp) { return false }
    }
    if let riser, riser.roomId == c.id, let rp = riserPoly(c, riser, 20) {
        if convexHit(fpoly, rp) { return false }
    }
    for f in others {
        let oz0 = fixZ0(f), oz1 = fixTop(f)
        // only a heater or a towel rail may hang over another fixture (a water heater over the washer); a basin never over the bath
        let hangs = ty.cat == "heater" || t == "tr" || fixType(f.t).cat == "heater" || f.t == "tr"
        if hangs && (z1 <= oz0 || oz1 <= z0) { continue }
        guard let op = fixPoly(c, f, 30) else { continue }
        if convexHit(fpoly, op) { return false }
    }
    return true
}

/// The free spot nearest prefer along wall w for a fixture of type t, fw wide; nil when the wall has none. Whole
/// centimetres.
func fixSpot(_ c: PCtx, _ t: String, _ w: TWall, _ prefer: Double, _ fw: Int, _ others: [PlFix], _ riser: PlRiser?, _ opt: String = "") -> Int? {
    let lo = Double(fw) / 2 + 10
    let hi = w.len - Double(fw) / 2 - 10
    if hi < lo { return nil }
    let r10 = eMathRoundP(eClamp(prefer, lo, hi) / 10.0) * 10.0
    let p0 = eClamp(r10, lo, hi)
    var k = 0
    while Double(k) * 10.0 <= w.len {
        let step = Double(k * 10)
        let a = p0 + step
        if a <= hi && pFits(c, t, w, a, fw, others, riser, opt) { return eRound(a) }
        let b = p0 - step
        if k > 0 && b >= lo && pFits(c, t, w, b, fw, others, riser, opt) { return eRound(b) }
        k += 1
    }
    return nil
}

/// Kotlin's Math.round on a double: halves go up.
func eMathRoundP(_ v: Double) -> Double { (v + 0.5).rounded(.down) }

/* ---------------- choosing the walls ---------------- */

private func pHasDoor(_ c: PCtx, _ w: TWall) -> Bool { c.room.openings.contains { $0.wall == w.id && $0.type == "door" } }
private func pMid(_ w: TWall) -> V2 { w.at(w.len / 2) }

/// The wall the water is on: the one with most water and drain marked on it, else the riser's, else a long one without
/// a door.
func wetWall(_ c: PCtx, _ riser: PlRiser?) -> TWall {
    let wet = c.room.points.filter { SITE_WATER.contains($0.t) }
    if !wet.isEmpty {
        return eMaxBy(c.g.walls) { w in Double(wet.filter { $0.wall == w.id }.count) * 100_000.0 + w.len } ?? c.g.walls[0]
    }
    if let riser, riser.roomId == c.id, let rw = c.wall(riser.wall) { return rw }
    return eMaxBy(c.g.walls) { w in w.len - (pHasDoor(c, w) ? 5000 : 0) } ?? c.g.walls[0]
}

/// The wall furthest from the room's door (a bath stands across it).
func farWall(_ c: PCtx) -> TWall {
    let longest = eMaxBy(c.g.walls) { $0.len } ?? c.g.walls[0]
    guard let e = c.entry, let ew = c.wall(e.wall) else { return longest }
    let dp = ew.at(Double(e.off) + Double(e.w) / 2)
    let rest = c.g.walls.filter { $0.id != ew.id }
    return eMaxBy(rest) { w in
        let m = pMid(w)
        return hypot(m.x - dp.x, m.y - dp.y)
    } ?? ew
}

/// The walls to try for a fixture, the preferred one first.
private func pOrder(_ c: PCtx, _ first: TWall?, _ more: [TWall?] = []) -> [TWall] {
    var all: [TWall] = []
    if let first { all.append(first) }
    for m in more { if let m { all.append(m) } }
    all += eSortedBy(c.g.walls.filter { !pHasDoor(c, $0) }) { -$0.len }
    all += eSortedBy(c.g.walls) { -$0.len }
    var seen = Set<String>()
    var out: [TWall] = []
    for w in all where seen.insert(w.id).inserted { out.append(w) }
    return out
}

/* ---------------- kits ---------------- */

/// A room kit of the gallery: what a room of kind usually gets; main the choices its steps ask.
struct PKit {
    let id: String
    let kind: String
    let opts: POpts
    let main: [String]
}

private func pk(_ id: String, _ kind: String, _ o: POpts, _ main: [String]) -> PKit { PKit(id: id, kind: kind, opts: o, main: main) }

private func po(bath: String = "bath", wm: Bool = true, dw: Bool = true, basin: Bool = true, heater: String = "gb", rad: Bool = false, ufh: Bool = false) -> POpts {
    var o = POpts()
    o.bath = bath; o.wm = wm; o.dw = dw; o.basin = basin; o.heater = heater; o.rad = rad; o.ufh = ufh
    return o
}

let PKITS: [PKit] = [
    pk("bt.bath", "bath", po(bath: "bath", wm: true), ["bath", "cab", "wm", "tr"]),
    pk("bt.shower", "bath", po(bath: "sh", wm: true), ["bath", "cab", "wm", "tr"]),
    pk("bt.cabin", "bath", po(bath: "cab", wm: false), ["bath", "cab", "wm", "tr"]),
    pk("wc.std", "wc", po(basin: false), ["basin"]),
    pk("wc.basin", "wc", po(basin: true), ["basin"]),
    pk("kt.std", "kitchen", po(dw: true), ["dw"]),
    pk("kt.sink", "kitchen", po(dw: false), ["dw"]),
    pk("ut.gas", "util", po(wm: false, heater: "gb"), ["heater", "wm"]),
    pk("ut.wh", "util", po(wm: true, heater: "wh"), ["heater", "wm"]),
    pk("ht.rad", "heat", po(rad: true), []),
    pk("ht.ufh", "heat", po(ufh: true), ["step"])
]

func pkitOf(_ id: String) -> PKit? { PKITS.first { $0.id == id } }

/// The fixture types a kit puts in with choices o, in the order they are placed.
func kitTypes(_ k: PKit, _ o: POpts) -> [String] {
    var out: [String] = []
    switch k.kind {
    case "bath":
        out.append(o.bath.isEmpty ? "bath" : o.bath); out.append("wc"); out.append("bs")
        if o.wm { out.append("wm") }
        if o.tr { out.append("tr") }
    case "wc":
        out.append("wc")
        if o.basin { out.append("bsm") }
    case "kitchen":
        out.append("sink")
        if o.dw { out.append("dw") }
    case "util":
        out.append(o.heater == "wh" ? "wh" : "gb")
        if o.wm { out.append("wm") }
    default: break
    }
    return out
}

/// A fixture of type t for room c centred x on wall w.
func newFix(_ id: String, _ t: String, _ c: PCtx, _ w: TWall, _ x: Int, kit: String = "", opt: String = "", width: Int = 0) -> PlFix {
    PlFix(id: id, t: t, roomId: c.id, wall: w.id, off: x, w: width, opt: opt, pts: defaultPts(t, width), kit: kit)
}

/// Where a fixture of type t goes in room c among the fixtures have: the bath and shower across the far wall into a
/// corner, the toilet beside the riser, the basin and washer on the wet wall, the dishwasher beside the sink, a heater on
/// the wet wall up high, a towel rail on a free wall. nil when there is no room for it.
func placeFix(_ t: String, _ c: PCtx, _ have: [PlFix], _ riser: PlRiser?, _ id: String, kit: String = "", opt: String = "") -> PlFix? {
    let ty = fixType(t)
    let fw = ty.w
    let hw = Double(fw) / 2
    let wet = wetWall(c, riser)
    let far = farWall(c)
    let rs: PlRiser? = (riser != nil && riser!.roomId == c.id) ? riser : nil
    let rw: TWall? = rs.flatMap { c.wall($0.wall) }
    let door: V2? = c.entry.flatMap { e in c.wall(e.wall)?.at(Double(e.off) + Double(e.w) / 2) }
    func awayCorner(_ w: TWall) -> Double {
        // the end of the wall further from the door
        guard let door else { return hw + 10 }
        let s = w.at(0), e = w.at(w.len)
        let ds = hypot(s.x - door.x, s.y - door.y), de = hypot(e.x - door.x, e.y - door.y)
        return ds >= de ? hw + 10 : w.len - hw - 10
    }
    var tries: [(TWall, Double)] = []
    switch t {
    case "bath", "sh", "cab":
        tries = pOrder(c, far, [wet]).map { ($0, awayCorner($0)) }
    case "wc":
        if let rw, let rs {
            let side: Double = Double(rs.off) < rw.len / 2 ? 1 : -1
            let gap = Double(RISER_W) / 2 + hw + 120
            tries = pOrder(c, rw, [wet]).map { w in (w, w.id == rw.id ? Double(rs.off) + side * gap : awayCorner(w)) }
        } else {
            tries = pOrder(c, wet).map { ($0, awayCorner($0)) }
        }
    case "bs", "bsm":
        tries = pOrder(c, wet).map { ($0, $0.len / 2) }
    case "wm":
        tries = pOrder(c, wet).map { ($0, $0.len - hw - 10) }
    case "sink":
        tries = pOrder(c, wet).map { w in
            let at = c.room.points.first { $0.wall == w.id && SITE_WATER.contains($0.t) }
            return (w, at.map { Double($0.off) } ?? w.len * 0.4)
        }
    case "dw":
        let s = have.first { $0.t == "sink" }
        let sw: TWall? = s.flatMap { c.wall($0.wall) }
        tries = pOrder(c, sw, [wet]).map { w in
            if let s, w.id == s.wall { return (w, Double(s.off) + Double(fixW(s)) / 2 + 20 + hw) }
            return (w, w.len / 2)
        }
    case "wh", "gb":
        tries = pOrder(c, wet).map { ($0, $0.len - hw - 150) }
    case "tr":
        let free = c.g.walls.filter { w in !have.contains { $0.wall == w.id && fixType($0.t).cat == "wet" } }
        tries = pOrder(c, nil, free.map { Optional($0) }).map { ($0, $0.len / 2) }
    case "manif":
        let e = c.entry
        let ew: TWall? = e.flatMap { c.wall($0.wall) }
        tries = pOrder(c, ew).map { w in
            // Kotlin's fw / 2 here is a whole number
            if let e, w.id == e.wall { return (w, Double(e.off + e.w) + 200.0 + Double(fw / 2)) }
            return (w, w.len / 2)
        }
    default:
        tries = pOrder(c, wet).map { ($0, $0.len / 2) }
    }
    for (w, prefer) in tries {
        guard let x = fixSpot(c, t, w, prefer, fw, have, riser, opt) else { continue }
        return newFix(id, t, c, w, x, kit: kit, opt: opt)
    }
    return nil
}

/// Radiators under the windows of room c (else on its longest wall without a door), sized by the floor: W_M2 a m².
func placeRadiators(_ c: PCtx, _ have: [PlFix], _ riser: PlRiser?, _ id: @escaping () -> String, _ kit: String = "") -> [PlFix] {
    var out: [PlFix] = []
    let wins = c.room.openings.filter { $0.type == "window" && c.wall($0.wall) != nil }
    let secs = radSections(c.areaM2)
    if wins.isEmpty {
        let w = eMaxBy(c.g.walls.filter { !pHasDoor(c, $0) }) { $0.len } ?? (eMaxBy(c.g.walls) { $0.len } ?? c.g.walls[0])
        let rw = radWidth(secs)
        if let x = fixSpot(c, "rad", w, w.len / 2, rw, have, riser) { out.append(newFix(id(), "rad", c, w, x, kit: kit, width: rw)) }
        return out
    }
    let each = max(3, tInt((Double(secs) / Double(wins.count)).rounded(.up)))
    for o in wins {
        guard let w = c.wall(o.wall) else { continue }
        let rw = min(radWidth(each), max(400, o.w + 200))
        let prefer = Double(o.off) + Double(o.w) / 2
        if let x = fixSpot(c, "rad", w, prefer, rw, have + out, riser) { out.append(newFix(id(), "rad", c, w, x, kit: kit, width: rw)) }
    }
    return out
}

/// Radiator sections for a room of m2 m²: W_M2 W a m², SEC_W W a section, 3 at least.
func radSections(_ m2: Double) -> Int {
    let v = m2 * Double(W_M2) / Double(SEC_W) - 1e-9
    return max(3, tInt(v.rounded(.up)))
}
func radWidth(_ sections: Int) -> Int { sections * SEC_MM }

/// A radiator's heat, W, from its width.
func radWatts(_ f: PlFix) -> Int { fixW(f) / SEC_MM * SEC_W }

/// The fixtures of kit k (with choices o) placed in room c among those it has (have): each at its usual spot, clear of
/// what is in the way. id makes the new ids. The underfloor heating is the room's setting, not a fixture.
func pPlaceKit(_ k: PKit, _ c: PCtx, _ have: [PlFix], _ riser: PlRiser?, _ id: @escaping () -> String, _ o0: POpts? = nil) -> [PlFix] {
    let o = o0 ?? k.opts
    let types = kitTypes(k, o)
    func put(_ order: [String]) -> [PlFix] {
        var got: [PlFix] = []
        for (i, t) in order.enumerated() {
            let opt = t == "bs" && o.cab ? "cab" : ""
            if let f = placeFix(t, c, have + got, riser, "~\(i)", kit: k.id, opt: opt) { got.append(f) }
        }
        return got
    }
    var best = put(types)
    // the toilet wants the riser (its 110 drain short): tried first too, kept when it puts everything in and lands nearer
    let rs: PlRiser? = (riser != nil && riser!.roomId == c.id) ? riser : nil
    if let rs, types.contains("wc"), types.first != "wc" {
        let alt = put(["wc"] + types.filter { $0 != "wc" })
        func d(_ fs: [PlFix]) -> Double {
            guard let f = fs.first(where: { $0.t == "wc" }) else { return Double.greatestFiniteMagnitude }
            return wcToRiser(c, f, rs)
        }
        if alt.count > best.count || (alt.count == best.count && d(alt) + 1 < d(best)) { best = alt }
    }
    let sorted = eSortedBy(best) { f in Double(types.firstIndex(of: f.t) ?? -1) }
    var out: [PlFix] = []
    for f in sorted {
        var g = f
        g.id = id()
        out.append(g)
    }
    if o.rad && !(have + out).contains(where: { $0.t == "rad" }) { out += placeRadiators(c, have + out, riser, id, k.id) }
    return out
}

/// How far along the walls toilet f is from riser rs in its room, mm.
func wcToRiser(_ c: PCtx, _ f: PlFix, _ rs: PlRiser) -> Double {
    let per = Perim(c.g.walls)
    return pShorter(per.P, per.s(f.wall, Double(f.off)), per.s(rs.wall, Double(rs.off))).1
}

/* ---------------- the riser ---------------- */

/// The riser put in room c: in a corner of its wet wall, clear of the doors; else any corner.
func riserIn(_ c: PCtx, _ fixes: [PlFix] = []) -> PlRiser {
    let wet = wetWall(c, nil)
    let walls = [wet] + c.g.walls.filter { $0.id != wet.id && !pHasDoor(c, $0) } + c.g.walls
    var seen = Set<String>()
    let rw2 = Double(RISER_W) / 2
    for w in walls where seen.insert(w.id).inserted {
        for x in [rw2 + 10, w.len - rw2 - 10] {
            if riserFits(c, w, x, fixes) { return PlRiser(roomId: c.id, wall: w.id, off: eRound(x)) }
        }
    }
    return PlRiser(roomId: c.id, wall: wet.id, off: RISER_W / 2 + 10)
}

private func riserFits(_ c: PCtx, _ w: TWall, _ x: Double, _ fixes: [PlFix]) -> Bool {
    let rw2 = Double(RISER_W) / 2
    if x - rw2 < 0 || x + rw2 > w.len { return false }
    for o in c.room.openings where o.wall == w.id {
        let over = x + rw2 > Double(o.off) - 50 && x - rw2 < Double(o.off + o.w) + 50
        if over && (o.type == "door" || o.sill < 2000) { return false }
    }
    let fpoly = boxPoly(w, x, Double(RISER_W), Double(RISER_D))
    for o in c.doors {
        if let sp = swingPoly(c, o), convexHit(fpoly, sp) { return false }
    }
    for f in fixes where f.roomId == c.id {
        if let fp = fixPoly(c, f, 20), convexHit(fpoly, fp) { return false }
    }
    return true
}

/// Where the riser goes by default: a bathroom or toilet (the one with most fixtures), else the room with most fixtures.
func defaultRiser(_ p: Project, _ snap: Bool) -> PlRiser? {
    let cs = p.rooms.compactMap { pCtxOf(p, $0.id, snap) }
    func n(_ c: PCtx) -> Double { Double(p.plumb.fixes.filter { $0.roomId == c.id }.count) }
    let wet = cs.filter { $0.kind == "bath" || $0.kind == "wc" }
    guard let c = eMaxBy(wet, n) ?? eMaxBy(cs, n) else { return nil }
    return riserIn(c, p.plumb.fixes)
}

/// Dragging the riser: along its wall in whole centimetres, into a corner when near one.
func snapRiser(_ c: PCtx, _ r: PlRiser, _ wall: String, _ rawOff: Int) -> PlRiser {
    guard let w = c.wall(wall) else { return r }
    let lo = Double(RISER_W) / 2 + 10
    let hi = max(lo, w.len - Double(RISER_W) / 2 - 10)
    let x0 = Double((rawOff + 5) / 10 * 10)
    var x = x0
    if abs(x0 - lo) <= 150 { x = lo } else if abs(x0 - hi) <= 150 { x = hi }
    x = eClamp(x, lo, hi)
    var out = r
    out.wall = w.id; out.off = eRound(x)
    return out
}

/* ---------------- moving ---------------- */

/// Where fixture f dragged to rawOff along wall wall lands: into a corner or beside a neighbour when near (80 mm), else
/// in whole centimetres; moved to the nearest free spot when it would stand in the way; nil when the wall has none.
func snapFix(_ c: PCtx, _ f: PlFix, _ wall: String, _ rawOff: Int, _ others: [PlFix], _ riser: PlRiser?) -> Int? {
    guard let w = c.wall(wall) else { return nil }
    let fw = fixW(f)
    let hw = Double(fw) / 2
    var xs: [Double] = [hw + 10, w.len - hw - 10]
    for o in others where o.wall == w.id && o.id != f.id {
        let oh = Double(fixW(o)) / 2
        xs.append(Double(o.off) + oh + 30 + hw)
        xs.append(Double(o.off) - oh - 30 - hw)
    }
    if let riser, riser.roomId == c.id, riser.wall == w.id {
        let rh = Double(RISER_W) / 2
        xs.append(Double(riser.off) + rh + 20 + hw)
        xs.append(Double(riser.off) - rh - 20 - hw)
    }
    // Kotlin's fw / 2 here is a whole number
    let hwInt = Double(fw / 2)
    for o in c.room.openings where o.wall == w.id {
        xs.append(Double(o.off + o.w) + 50.0 + hwInt)
        xs.append(Double(o.off) - 50.0 - hwInt)
    }
    let lo = hw + 10
    let hi = max(lo, w.len - hw - 10)
    let raw = Double(rawOff)
    var x00 = Double((rawOff + 5) / 10 * 10)
    if let nx = eMinBy(xs, { abs($0 - raw) }), abs(nx - raw) <= 80 { x00 = nx }
    let x0 = eClamp(x00, lo, hi)
    let rest = others.filter { $0.id != f.id }
    if pFits(c, f.t, w, x0, fw, rest, riser, f.opt) { return eRound(x0) }
    return fixSpot(c, f.t, w, x0, fw, rest, riser, f.opt)
}

/// A fixture dragged on the plan to q: onto the nearest wall, along it as snapFix has it; where it was when that wall
/// has no room.
func snapFixPlan(_ c: PCtx, _ f: PlFix, _ q: V2, _ others: [PlFix], _ riser: PlRiser?) -> (String, Int) {
    let nw = nearestWall(c.g.walls, q)
    let w = nw.0
    if let x = snapFix(c, f, w.id, eRound(nw.1), others, riser) { return (w.id, x) }
    return (f.wall, f.off)
}

/// Where loose outlet pt dragged to (rawOff, rawH) on its wall lands: the usual heights when near (60 mm), whole
/// centimetres, on the wall.
func snapPoint(_ c: PCtx, _ pt: PlPoint, _ rawOff: Int, _ rawH: Int) -> (Int, Int) {
    guard let w = c.wall(pt.wall) else { return (rawOff, rawH) }
    var h0 = (rawH + 5) / 10 * 10
    if let nh = eMinBy(SNAP_H, { Double(abs($0 - rawH)) }), abs(nh - rawH) <= 60 { h0 = nh }
    let h = eClampI(h0, 30, max(30, c.H - 50))
    let x = eClampI((rawOff + 5) / 10 * 10, 30, max(30, tInt(w.len) - 30))
    return (x, h)
}

/// Fixture f moved to wall wall at off: its outlets go with it.
func moveFix(_ f: PlFix, _ wall: String, _ off: Int) -> PlFix {
    var g = f
    g.wall = wall; g.off = off
    return g
}

/// Fixture f made w wide (a radiator): its outlets at its ends again.
func resizeFix(_ f: PlFix, _ w: Int) -> PlFix {
    var g = f
    g.w = w
    if f.t == "rad" { g.pts = radPts(w) }
    return g
}

/* ---------------- a room typed by size ---------------- */

/// A typed room's fixtures from its counts, placed as a kit would.
func freeFixes(_ f: PlFree, _ c: PCtx) -> [PlFix] {
    var out: [PlFix] = []
    var n = 0
    func nid() -> String { let s = "f:\(f.id):\(n)"; n += 1; return s }
    // a small typed room: what does not fit clear of its made-up door's swing still goes in (the door is only a guess);
    // what is bigger than the room stays out (pFreeMissing says so)
    var bareRoom = c.room
    bareRoom.openings = []
    let bare = PCtx(id: c.id, room: bareRoom, g: c.g, kind: c.kind, pr: c.pr, free: c.free)
    func put(_ t: String, _ k: Int) {
        let times = eClampI(k, 0, 6)
        if times == 0 { return }
        for _ in 0..<times {
            let id = nid()
            if let x = placeFix(t, c, out, nil, id) { out.append(x); continue }
            let id2 = nid()
            if let x = placeFix(t, bare, out, nil, id2) { out.append(x) }
        }
    }
    put("bath", f.bath); put(f.cabin ? "cab" : "sh", f.shower); put("wc", f.wc); put(f.small ? "bsm" : "bs", f.basin); put("sink", f.sink)
    put("wm", f.wm); put("dw", f.dw)
    put("wh", f.wh); put("gb", f.gb); put("tr", f.tr)
    if f.rad > 0 {
        let w = c.wall("C") ?? c.g.walls[c.g.walls.count - 1]
        let secs = max(3, tInt((Double(radSections(c.areaM2)) / Double(f.rad)).rounded(.up)))
        let times = eClampI(f.rad, 0, 6)
        for i in 0..<times {
            let rw = radWidth(secs)
            let prefer = w.len * Double(i + 1) / Double(f.rad + 1)
            if let x = fixSpot(c, "rad", w, prefer, rw, out, nil) { out.append(newFix(nid(), "rad", c, w, x, width: rw)) }
        }
    }
    if f.ufh && !out.contains(where: { $0.t == "manif" }) {
        let id = nid()
        if let x = placeFix("manif", c, out, nil, id) { out.append(x) }
    }
    return out
}

/// A kit's counts for a room typed by size.
/// What a typed room's counts ask for that does not fit in it (type and how many), e.g. a 1,7 m bath in a 1,2 m room.
func pFreeMissing(_ f: PlFree, _ placed: [PlFix]) -> [(String, Int)] {
    let want: [(String, Int)] = [("bath", f.bath), (f.cabin ? "cab" : "sh", f.shower), ("wc", f.wc), (f.small ? "bsm" : "bs", f.basin), ("sink", f.sink),
                                 ("wm", f.wm), ("dw", f.dw), ("wh", f.wh), ("gb", f.gb), ("tr", f.tr)]
    var out: [(String, Int)] = []
    for (t, n) in want {
        let miss = eClampI(n, 0, 6) - placed.filter { $0.t == t }.count
        if miss > 0 { out.append((t, miss)) }
    }
    return out
}

func pFreeOf(_ k: PKit, _ o: POpts, _ id: String, _ name: String, _ L: Int, _ W: Int, _ H: Int) -> PlFree {
    let ts = kitTypes(k, o)
    func cnt(_ t: [String]) -> Int { ts.filter { t.contains($0) }.count }
    var f = PlFree(id: id, name: name, kind: k.kind == "heat" ? "room" : k.kind, L: L, W: W, H: H)
    f.wc = cnt(["wc"]); f.basin = cnt(["bs", "bsm"]); f.bath = cnt(["bath"]); f.shower = cnt(["sh", "cab"])
    f.sink = cnt(["sink"]); f.wm = cnt(["wm"]); f.dw = cnt(["dw"]); f.wh = cnt(["wh"]); f.gb = cnt(["gb"])
    f.rad = o.rad ? 1 : 0; f.ufh = o.ufh; f.kit = k.id
    // what the kit chose stays: a towel rail, a hand basin (cold only), a shower cabin
    f.tr = cnt(["tr"])
    f.small = cnt(["bsm"]) > 0 && cnt(["bs"]) == 0
    f.cabin = cnt(["cab"]) > 0 && cnt(["sh"]) == 0
    f.kept = true
    return f
}

/* ---------------- the room's own marks ---------------- */

/// The room's water and drain marked on its walls taken in as loose outlets (once each): cold, hot, and a drain 50 or 110.
func pFromSitePoints(_ c: PCtx, _ id: () -> String) -> [PlPoint] {
    var out: [PlPoint] = []
    for x in c.room.points where SITE_WATER.contains(x.t) && !c.pr.seen.contains(x.id) {
        if c.wall(x.wall) == nil { continue }
        let sewer = x.t == "sewer"
        let h = eClampI(x.h, 30, max(30, c.H - 50))
        out.append(PlPoint(id: id(), t: sewer ? "drain" : x.t, roomId: c.id, wall: x.wall, off: x.off, h: h, d: sewer ? drainD(x.d) : 0, from: x.id))
    }
    return out
}

/// The plan point of an outlet on its wall's face.
func pPlanOf(_ c: PCtx, _ wall: String, _ off: Int) -> V2? { c.wall(wall)?.at(Double(off)) }

/// The middle of a room's floor.
func pCentre(_ c: PCtx) -> V2 { centreOf(c.g.floor) }

/// The site point types a plumber's 3D draws as its own outlets (the room's marks are taken in).
func isWater(_ x: SitePoint) -> Bool { SITE_WATER.contains(x.t) }
