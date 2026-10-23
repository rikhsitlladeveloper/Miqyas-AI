import Foundation

/*
 * The routes (Android plumb/Routes.kt). Cold water comes from the riser, hot from the water heater or gas boiler (else
 * the riser), the heating's supply and return from the gas boiler. Each kind runs along the walls at its height (or in
 * the floor), the shorter way round, dipping into the floor under the doorways, to the room's door, through it to the
 * next room and round its walls, and up or down to each outlet; one trunk a kind a room, each outlet a branch. Each
 * drain runs on its own from its outlet down to the floor and along the walls back to the riser, falling at the slope
 * its outlet's height allows. Underfloor heating is worked out as loops of LOOP_MAX at most. Lengths in mm.
 */

/// A piece of a route: from a at za to b at zb (plan mm, mm up), on wall or in the floor (nil).
struct PSeg {
    let a: V2, za: Double, b: V2, zb: Double, wall: String?
    init(_ a: V2, _ za: Double, _ b: V2, _ zb: Double, _ wall: String?) { self.a = a; self.za = za; self.b = b; self.zb = zb; self.wall = wall }
    var len: Double { hypot(hypot(b.x - a.x, b.y - a.y), zb - za) }
}

/// A kind's route in one room: its pieces to draw, its pipe there len (the trunk with the pipe between the doors and at
/// the riser, the branches drops), what is chased into the walls (chase), the corners and doorway dips it turns
/// (elbows), the trunk's diameter dia; a drain's: the stretches round the room it lies along (stretches) and its outlet
/// (target).
struct PRun {
    let kind: String
    let roomId: String
    let segs: [PSeg]
    let len: Double
    let trunk: Double
    let drops: Double
    let chase: Double
    let corners: Int
    let dips: Int
    let dia: Int
    let branches: Int
    var stretches: [(Double, Double)] = []
    var target: String? = nil
}

/// A drain from outlet pt: its pieces room by room, how far it runs to the riser (horiz), its slope (mm a metre) and
/// diameter.
struct PDrain {
    let pt: APt
    let runs: [PRun]
    let horiz: Double
    let slope: Double
    let dia: Int
    let vertical: Double
    var between = 0.0
}

/// An underfloor heating's loops in a room: its heated floor (m²), the spacing, the pipe to and from the manifold, the
/// whole pipe, how many loops.
struct PLoop {
    let roomId: String
    let area: Double
    let step: Int
    let lead: Double
    let total: Double
    let n: Int
    var each: Double { n > 0 ? total / Double(n) : 0 }
}

/// Where a kind's pipe starts: the riser, or a heater's or boiler's outlet (h its height, fix the fixture).
struct PSrc {
    let roomId: String
    let wall: String
    let off: Int
    let h: Int?
    let fix: String?
}

/// All the order's routes.
struct PRoutes {
    let runs: [PRun]
    let drains: [PDrain]
    let riser: PlRiser?
    let hot: PSrc?
    let heat: PSrc?
    let loops: [PLoop]
    func inRoom(_ rid: String) -> [PRun] { runs.filter { $0.roomId == rid } }
    func lenOf(_ kind: String) -> Double { runs.filter { $0.kind == kind }.reduce(0.0) { $0 + $1.len } }
}

/// The trunk's diameter for n outlets of a kind: 20 for a few, 25, 32 for many.
func trunkDia(_ n: Int) -> Int { n <= 4 ? 20 : n <= 12 ? 25 : 32 }

/// Water's and heating's height along the walls (or in the floor), mm.
func runZ(_ kind: String, _ run: String) -> Double {
    if run == "floor" { return Double(FLOOR_Z) }
    switch kind {
    case "cold": return Double(WATER_Z)
    case "hot": return Double(WATER_Z + KIND_DZ)
    case "hs": return Double(HEAT_Z)
    default: return Double(HEAT_Z + 50)
    }
}

/// How far off the wall a kind's pipe lies: along the walls just off them; in the floor side by side.
func pInset(_ kind: String, _ run: String) -> Double {
    if kind == "drain" { return 60 }
    if run != "floor" { return 14 }
    switch kind {
    case "cold": return 40
    case "hot": return 80
    case "hs": return 120
    default: return 160
    }
}

/// The door of room sc a pipe to room away leaves by: the one set for it, else the room's last door.
func pExitDoor(_ sc: PCtx, _ away: PCtx) -> Opening? {
    let ds = sc.doors
    return ds.first { $0.id == away.pr.pdoor } ?? ds.last
}

/// The way round the walls from from to to (lengths round the room), clockwise or not, as pieces in the order walked.
func pWalk(_ per: Perim, _ from: Double, _ to: Double, _ cw: Bool) -> [(TWall, Double, Double)] {
    let P = per.P
    if P <= 0 { return [] }
    if cw { return per.pieces(from, eMod(eMod(to - from, P) + P, P)) }
    let back = per.pieces(to, eMod(eMod(from - to, P) + P, P))
    return back.reversed().map { pc in (pc.0, pc.2, pc.1) }
}

/// The shorter way round from from to to: clockwise?, how far.
func pShorter(_ P: Double, _ from: Double, _ to: Double) -> (Bool, Double) {
    let d = eMod(eMod(to - from, P) + P, P)
    return d <= P - d ? (true, d) : (false, P - d)
}

/* ---------------- water and heating ---------------- */

/// Builds a route's pieces from stations: a station at the same spot and another height is a riser or drop.
final class PPath {
    var segs: [PSeg] = []
    private var lastP: V2? = nil
    private var lastZ = 0.0
    private var lastW: String? = nil
    func to(_ p: V2, _ z: Double, _ wall: String?) {
        if let lp = lastP {
            let far = hypot(lp.x - p.x, lp.y - p.y) > 0.5 || abs(lastZ - z) > 0.5
            if far { segs.append(PSeg(lp, lastZ, p, z, wall ?? lastW)) }
        }
        lastP = p; lastZ = z; lastW = wall
    }
    func jump(_ p: V2, _ z: Double, _ wall: String?) { lastP = p; lastZ = z; lastW = wall }
}

/// The run along walk pieces at height z, ins off the wall, from height z0: under the doorways it dips into the floor
/// when dip (it runs along the walls). Adds the pieces to path; returns the length (with the ups and downs), the length
/// on the wall (chased), the dips under doors.
private func pAlong(_ c: PCtx, _ pieces: [(TWall, Double, Double)], _ z: Double, _ z0: Double, _ ins: Double, _ path: PPath, _ dip: Bool) -> (Double, Double, Int) {
    var len = 0.0, onWall = 0.0
    var dips = 0
    var cur = z0
    let fz = Double(FLOOR_Z)
    for pc in pieces {
        let w = pc.0, from = pc.1, to = pc.2
        let lo = min(from, to), hi = max(from, to)
        var cuts: [(Double, Double)] = []
        if dip {
            for o in c.room.openings where o.wall == w.id && o.type == "door" {
                let a = Double(o.off) - 60.0, b = Double(o.off + o.w) + 60.0
                if b > lo && a < hi { cuts.append((a, b)) }
            }
        }
        var marks: [Double] = [lo, hi]
        for ct in cuts {
            if ct.0 > lo && ct.0 < hi { marks.append(ct.0) }
            if ct.1 > lo && ct.1 < hi { marks.append(ct.1) }
        }
        var uniq: [Double] = []
        for m in marks where !uniq.contains(m) { uniq.append(m) }
        var br = uniq.sorted()
        if from > to { br.reverse() }
        if br.count < 2 { continue }
        for i in 0..<(br.count - 1) {
            let a = br[i], b = br[i + 1]
            let m = (a + b) / 2
            let low = cuts.contains { m > $0.0 && m < $0.1 }
            let zz = low ? fz : z
            if abs(zz - cur) > 0.5 {
                len += abs(zz - cur)
                if zz < cur { dips += 1 }
            }
            path.to(w.at(a, ins), zz, w.id)
            path.to(w.at(b, ins), zz, w.id)
            len += abs(b - a)
            if !low { onWall += abs(b - a) }
            cur = zz
        }
    }
    return (len, onWall, dips)
}

/// Kind kind's route in room c to its outlets ts: from src when it is in this room (on to the doors exits other rooms'
/// pipe leaves by), else from the room's door, plus link for the pipe between the doors. run along the walls or in the
/// floor; dia the trunk's diameter.
func supplyRun(_ c: PCtx, _ kind: String, _ ts: [APt], _ src: PSrc?, _ exits: [Opening], _ run: String, _ link: Double, _ dia: Int) -> PRun {
    let per = Perim(c.g.walls)
    let z = runZ(kind, run)
    let ins = pInset(kind, run)
    let path = PPath()
    var trunk = 0.0, chase = 0.0
    var corners = 0, dips = 0
    var sw: TWall
    var sa: Double
    var z0: Double
    if let src, src.roomId == c.id {
        sw = c.wall(src.wall) ?? c.g.walls[0]
        sa = Double(src.off)
        let p0 = sw.at(sa, ins)
        if let h = src.h {
            // down (or up) from the heater's outlet to the run
            path.jump(p0, Double(h), sw.id)
            path.to(p0, z, sw.id)
            trunk += abs(Double(h) - z)
            chase += abs(Double(h) - z)
        } else {
            path.jump(p0, z, sw.id)
            trunk += Double(RISER_TAIL)
        }
        z0 = z
    } else {
        let e = c.entry
        sw = e.flatMap { c.wall($0.wall) } ?? c.g.walls[0]
        sa = e.map { Double($0.off) + Double($0.w) / 2 } ?? 0
        // through the doorway in the floor
        z0 = e != nil && run != "floor" ? Double(FLOOR_Z) : z
        path.jump(sw.at(sa, ins), z0, sw.id)
        trunk += link
    }
    let e = per.s(sw.id, sa)
    var targets: [Double] = []
    for t in ts { targets.append(per.s(t.wall, Double(t.off))) }
    for o in exits { targets.append(per.s(o.wall, Double(o.off) + Double(o.w) / 2)) }
    let cv = eCover(per.P, e, targets)
    let cw = cv.0, ccw = cv.1
    let dip = run != "floor"
    if cw > 0 {
        let pcs = per.pieces(e, cw)
        corners += max(0, pcs.count - 1)
        let r = pAlong(c, pcs, z, z0, ins, path, dip)
        trunk += r.0; chase += r.1; dips += r.2
    }
    if ccw > 0 {
        path.jump(sw.at(sa, ins), z0, sw.id)
        let pcs = pWalk(per, e, e - ccw, false)
        corners += max(0, pcs.count - 1)
        let r = pAlong(c, pcs, z, z0, ins, path, dip)
        trunk += r.0; chase += r.1; dips += r.2
    }
    // each outlet: straight up or down the wall from the run
    var drops = 0.0
    for t in ts {
        guard let w = c.wall(t.wall) else { continue }
        let q = w.at(Double(t.off), ins)
        path.jump(q, z, w.id)
        path.to(q, Double(t.h), w.id)
        drops += abs(Double(t.h) - z)
    }
    chase += drops
    if run == "floor" { chase = drops }
    return PRun(kind: kind, roomId: c.id, segs: path.segs, len: trunk + drops, trunk: trunk, drops: drops, chase: chase,
                corners: corners, dips: dips, dia: dia, branches: ts.count)
}

/// Where a kind's pipe starts in order p: cold at the riser, hot at the heater (else the riser if it brings hot),
/// heating at the boiler.
func sourceOf(_ p: Project, _ kind: String, _ fixes: [PlFix]) -> PSrc? {
    let rs = p.plumb.riser
    func ofFix(_ f: PlFix, _ k: String) -> PSrc? {
        guard let q = fixPoints(f).first(where: { $0.t == k }) else { return nil }
        return PSrc(roomId: f.roomId, wall: f.wall, off: q.off, h: q.h, fix: f.id)
    }
    func atRiser(_ r: PlRiser) -> PSrc { PSrc(roomId: r.roomId, wall: r.wall, off: r.off, h: nil, fix: nil) }
    switch kind {
    case "cold":
        return rs.map(atRiser)
    case "hot":
        if let f = fixes.first(where: { $0.t == "gb" }) ?? fixes.first(where: { $0.t == "wh" }), let s = ofFix(f, "hot") { return s }
        if let r = rs, r.hot { return atRiser(r) }
        return nil
    default:
        guard let f = fixes.first(where: { $0.t == "gb" }) else { return nil }
        return ofFix(f, kind)
    }
}

/* ---------------- drains ---------------- */

/// The slope a drain of dia is laid at, and the least the rules allow, mm a metre.
func slopeFor(_ dia: Int) -> Int { dia >= 100 ? SLOPE_110 : SLOPE_50 }
func minSlope(_ dia: Int) -> Int { dia >= 100 ? MIN_110 : MIN_50 }

/// One leg of a drain: in a room, along its walls.
private struct PLeg {
    let ctx: PCtx
    let per: Perim
    let pieces: [(TWall, Double, Double)]
    let len: Double
    let pre: Double
}

/// The drain from outlet pt in room c: down to the floor, along the walls the shorter way to the riser (rc its room) or
/// to the room's door, the pipe between the doors (link) and on in the riser's room from its door. It starts as high as
/// the slope needs (no higher than the outlet) and falls to DRAIN_IN at the riser.
func drainOf(_ pt: APt, _ c: PCtx, _ rc: PCtx?, _ rs: PlRiser?, _ link: Double) -> PDrain {
    let dia = drainD(pt.d)
    let ins = pInset("drain", "")
    let per = Perim(c.g.walls)
    let sp = per.s(pt.wall, Double(pt.off))
    // the legs: in this room to the riser or the door; then (after the pipe between the doors) in the riser's room
    var legs: [PLeg] = []
    var between = 0.0
    if let rs, rc != nil, rs.roomId == c.id {
        let tp = per.s(rs.wall, Double(rs.off))
        let sh = pShorter(per.P, sp, tp)
        legs.append(PLeg(ctx: c, per: per, pieces: pWalk(per, sp, tp, sh.0), len: sh.1, pre: 0))
    } else {
        if let e = c.entry {
            let te = per.s(e.wall, Double(e.off) + Double(e.w) / 2)
            let sh = pShorter(per.P, sp, te)
            legs.append(PLeg(ctx: c, per: per, pieces: pWalk(per, sp, te, sh.0), len: sh.1, pre: 0))
        }
        between = link
        if let rs, let rc, let x = pExitDoor(rc, c) {
            let rp = Perim(rc.g.walls)
            let a = rp.s(x.wall, Double(x.off) + Double(x.w) / 2)
            let b = rp.s(rs.wall, Double(rs.off))
            let sh = pShorter(rp.P, a, b)
            legs.append(PLeg(ctx: rc, per: rp, pieces: pWalk(rp, a, b, sh.0), len: sh.1, pre: between))
        }
    }
    let horiz = legs.reduce(0.0) { $0 + $1.len } + between
    let want = slopeFor(dia)
    let ph = Double(pt.h)
    let din = Double(DRAIN_IN)
    var z0 = ph
    if horiz > 0 {
        let need = din + Double(want) * horiz / 1000
        z0 = max(min(ph, din), min(ph, need))
    }
    let slope = horiz <= 0 ? Double(want) : max(0.0, (z0 - din) / horiz * 1000)
    let vertical = max(0.0, ph - z0)
    var runs: [PRun] = []
    var s = 0.0
    for (i, leg) in legs.enumerated() {
        s += leg.pre
        let path = PPath()
        var st: [(Double, Double)] = []
        let withDrop = i == 0 && leg.ctx.id == c.id
        if withDrop {
            if let w = c.wall(pt.wall) {
                let q = w.at(Double(pt.off), ins)
                path.jump(q, ph, w.id)
                path.to(q, z0, w.id)
            }
        } else if let f = leg.pieces.first {
            path.jump(f.0.at(f.1, ins), z0 - slope * s / 1000, f.0.id)
        }
        for pc in leg.pieces {
            let w = pc.0, a = pc.1, b = pc.2
            let step = abs(b - a)
            let za = z0 - slope * s / 1000
            let zb = z0 - slope * (s + step) / 1000
            path.to(w.at(a, ins), za, w.id)
            path.to(w.at(b, ins), zb, w.id)
            let s0 = leg.per.s(w.id, min(a, b))
            st.append((s0, s0 + step))
            s += step
        }
        let v = withDrop ? vertical : 0
        runs.append(PRun(kind: "drain", roomId: leg.ctx.id, segs: path.segs, len: leg.len + v, trunk: leg.len, drops: v, chase: 0,
                         corners: max(0, leg.pieces.count - 1), dips: 0, dia: dia, branches: 1, stretches: st, target: pt.id))
    }
    if !legs.contains(where: { $0.ctx.id == c.id }) && vertical > 0, let w = c.wall(pt.wall) {
        let q = w.at(Double(pt.off), ins)
        let seg = PSeg(q, ph, q, z0, w.id)
        runs.append(PRun(kind: "drain", roomId: c.id, segs: [seg], len: vertical, trunk: 0, drops: vertical, chase: 0,
                         corners: 0, dips: 0, dia: dia, branches: 1, stretches: [], target: pt.id))
    }
    return PDrain(pt: pt, runs: runs, horiz: horiz, slope: slope, dia: dia, vertical: vertical, between: between)
}

/* ---------------- underfloor heating ---------------- */

/// The floor heated in room c: its area less what stands on it (bath, tray, toilet, cabinets, machines), m².
func heatedArea(_ c: PCtx, _ fs: [PlFix]) -> Double {
    var taken = 0.0
    for f in fs where fixZ0(f) == 0 && fixType(f.t).cat != "heat" { taken += Double(fixW(f)) * Double(fixD(f)) }
    return max(0.0, c.areaM2 - taken / 1e6)
}

/// Room c's underfloor loops at c's spacing: the pipe over its heated floor, the pipe to and from the manifold (mf its
/// room and outlet; in another room: along its walls to the door and the pipe between the doors), split into loops of
/// LOOP_MAX at most.
func loopOf(_ c: PCtx, _ fs: [PlFix], _ mc: PCtx?, _ mf: APt?) -> PLoop {
    let step = eClampI(c.pr.step, 50, 400)
    let a = heatedArea(c, fs)
    let field = a * 1e6 / Double(step)
    var lead = 0.0
    if let mc, let mf {
        if mc.id == c.id {
            let m = pCentre(c)
            let q = pPlanOf(c, mf.wall, mf.off) ?? m
            lead = 2 * (hypot(q.x - m.x, q.y - m.y) + Double(mf.h))
        } else {
            let x = pExitDoor(mc, c)
            let per = Perim(mc.g.walls)
            var d = 0.0
            if let x { d = pShorter(per.P, per.s(mf.wall, Double(mf.off)), per.s(x.wall, Double(x.off) + Double(x.w) / 2)).1 }
            lead = 2 * (d + Double(c.pr.link) + Double(mf.h))
        }
    } else {
        lead = 2.0 * Double(c.free?.link ?? c.pr.link)
    }
    let total = field + lead
    let n = total <= 0 ? 0 : tInt((total / Double(LOOP_MAX) - 1e-9).rounded(.up))
    return PLoop(roomId: c.id, area: a, step: step, lead: lead, total: total, n: n)
}

/// The serpentine of a loop over room c's floor, for drawing: lines across step apart, inside the floor, k of n loops'
/// strip.
func pSnake(_ c: PCtx, _ step: Int, _ k: Int = 0, _ n: Int = 1) -> [(V2, V2)] {
    let f = c.g.floor
    let b = tBoxOf(f)
    let x0 = b.x0 + 150, x1 = b.x1 - 150
    let y0 = b.y0 + 150, y1 = b.y1 - 150
    if x1 <= x0 || y1 <= y0 { return [] }
    let nn = Double(max(n, 1))
    let sy0 = y0 + (y1 - y0) * Double(k) / nn
    let sy1 = y0 + (y1 - y0) * Double(k + 1) / nn
    var out: [(V2, V2)] = []
    var y = sy0
    var prev: V2? = nil
    var right = true
    let st = Double(eClampI(step, 50, 400))
    while y <= sy1 + 1e-6 {
        let xs = pScan(f, y).filter { $0.1 - $0.0 > 200 }
        if let seg = eMaxBy(xs, { $0.1 - $0.0 }) {
            let a = V2(max(seg.0 + 150, x0), y)
            let bq = V2(min(seg.1 - 150, x1), y)
            let s = right ? a : bq
            let e = right ? bq : a
            if let pv = prev { out.append((pv, s)) }
            out.append((s, e))
            prev = e
            right = !right
        }
        y += st
    }
    return out
}

/// Where line y = y is inside polygon f: the x stretches.
func pScan(_ f: [V2], _ y: Double) -> [(Double, Double)] {
    var xs: [Double] = []
    let n = f.count
    for i in 0..<n {
        let a = f[i], b = f[(i + 1) % n]
        if (a.y > y) != (b.y > y) { xs.append(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)) }
    }
    xs.sort()
    var out: [(Double, Double)] = []
    var i = 0
    while i + 1 < xs.count { out.append((xs[i], xs[i + 1])); i += 2 }
    return out
}

/* ---------------- all of them ---------------- */

/// The order's routes: water and heating trunk by trunk, each drain, the underfloor loops.
func pRoutesOf(_ p: Project, _ cs: [PCtx]) -> PRoutes {
    var byId: [String: PCtx] = [:]
    for c in cs { byId[c.id] = c }
    var fixes: [PlFix] = []
    for c in cs { fixes += fixesIn(p, c) }
    var pts: [String: [APt]] = [:]
    for c in cs { pts[c.id] = pointsIn(p, c, fixes.filter { $0.roomId == c.id }) }
    var rs: PlRiser? = nil
    if let r = p.plumb.riser, let rcx = byId[r.roomId], rcx.free == nil { rs = r }
    let rc: PCtx? = rs.flatMap { byId[$0.roomId] }
    var runs: [PRun] = []
    let pl = p.plumb
    var withRiser = p
    withRiser.plumb.riser = rs
    var srcs: [String: PSrc] = [:]
    for kind in ["cold", "hot", "hs", "hr"] {
        var src: PSrc? = nil
        if !(rs == nil && kind == "cold"), let s = sourceOf(withRiser, kind, fixes), byId[s.roomId] != nil { src = s }
        if let src { srcs[kind] = src }
        if (kind == "hs" || kind == "hr") && src == nil { continue }
        // the source's own outlet is where the pipe starts, not one it goes to
        let srcFix = src?.fix
        var per: [String: [APt]] = [:]
        var n = 0
        for c in cs {
            let mine = (pts[c.id] ?? []).filter { $0.t == kind && (srcFix == nil || $0.fix != srcFix) }
            per[c.id] = mine
            n += mine.count
        }
        if n == 0 { continue }
        let dia = trunkDia(n)
        let away = cs.filter { c in !(per[c.id] ?? []).isEmpty && c.id != src?.roomId }
        let sc: PCtx? = src.flatMap { byId[$0.roomId] }
        let how = kind == "hs" || kind == "hr" ? pl.hrun : pl.run
        for c in cs {
            let mine = per[c.id] ?? []
            let inSrc = src != nil && c.id == src!.roomId
            if mine.isEmpty && !(inSrc && !away.isEmpty) { continue }
            var exits: [Opening] = []
            if inSrc, let sc {
                var seen = Set<String>()
                for a in away where a.free == nil {
                    if let o = pExitDoor(sc, a), seen.insert(o.id).inserted { exits.append(o) }
                }
            }
            var link = 0.0
            if !inSrc { link = src != nil ? Double(c.free?.link ?? c.pr.link) : Double(c.free?.link ?? 0) }
            runs.append(supplyRun(c, kind, mine, src, exits, how, link, dia))
        }
    }
    var drains: [PDrain] = []
    for c in cs {
        let link = rs != nil || c.free != nil ? Double(c.free?.link ?? c.pr.link) : 0.0
        for pt in (pts[c.id] ?? []) where pt.t == "drain" { drains.append(drainOf(pt, c, rc, rs, link)) }
    }
    // the underfloor heating: from the room's own manifold when it has one, else the order's first
    let mfix = fixes.first { $0.t == "manif" }
    var loops: [PLoop] = []
    for c in cs where c.pr.ufh {
        let mf: PlFix? = fixes.first { $0.t == "manif" && $0.roomId == c.id } ?? mfix
        let mc: PCtx? = mf.flatMap { byId[$0.roomId] }
        let mpt: APt? = mf.flatMap { fixPoints($0).first }
        loops.append(loopOf(c, fixes.filter { $0.roomId == c.id }, mc, mpt))
    }
    return PRoutes(runs: runs, drains: drains, riser: rs, hot: srcs["hot"], heat: srcs["hs"], loops: loops)
}
