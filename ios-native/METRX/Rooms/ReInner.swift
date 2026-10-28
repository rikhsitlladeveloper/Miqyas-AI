import Foundation

/*
 * Inner walls from ready pieces (room-editor mockup v3, approved 28 Oct 2026: IWK, pieceGeo, innerFaces, obsSegs,
 * rayHit, iwSnap, iwSides, doorZones, iwIssues; Android geo/RoomKit.kt): straight, L, T, half (a low wall), col (a
 * column, square or round) and arch (a wall with a passage). The measured outer shape stays; a piece stands inside,
 * and each of its faces is a wall of its own (key "<piece id>:<n>", lettered after the outer walls). A piece's end
 * that comes within 300 mm of a wall stretches (or shrinks) to touch it. Pure Swift, unit-tested (InnerWallsTests).
 * Coordinates are the room's plan mm as reGeo draws it (y down).
 */

/// A ready piece: its standard length, wing, height and passage.
struct IwKind { let id: String; let len: Int; var len2 = 0; var h = 0; var op: InnerOp? = nil }

let IW_KINDS: [IwKind] = [
    IwKind(id: "straight", len: 2000), IwKind(id: "L", len: 2000, len2: 1200), IwKind(id: "T", len: 2400, len2: 1200),
    IwKind(id: "half", len: 1600, h: 1100), IwKind(id: "col", len: 400), IwKind(id: "arch", len: 2400, op: InnerOp(w: 900, h: 2100)),
]
func iwKind(_ k: String) -> IwKind { IW_KINDS.first { $0.id == k } ?? IW_KINDS[0] }
let IW_TH = [80, 100, 120, 250]
/// How near an end must come to a wall to stretch to it, mm.
let IW_MAG = 300.0
let IW_HH = [900, 1000, 1100, 1200]
let IW_OPW = [800, 900, 1200]
let IW_COL = [300, 400, 500]

/* ---------------- small vector maths on Pt ---------------- */

private func vadd(_ a: Pt, _ d: Pt, _ k: Double) -> Pt { Pt(x: a.x + d.x * k, y: a.y + d.y * k) }
private func vneg(_ a: Pt) -> Pt { Pt(x: -a.x, y: -a.y) }
private func vdot(_ a: Pt, _ b: Pt) -> Double { a.x * b.x + a.y * b.y }
private func vdist(_ a: Pt, _ b: Pt) -> Double { hypot(a.x - b.x, a.y - b.y) }

/// A direction of ang degrees (exact at the right angles).
func iwDir(_ ang: Int) -> Pt {
    let a = ((ang % 360) + 360) % 360
    switch a {
    case 0: return Pt(x: 1, y: 0)
    case 90: return Pt(x: 0, y: 1)
    case 180: return Pt(x: -1, y: 0)
    case 270: return Pt(x: 0, y: -1)
    default: let r = Double(a) * .pi / 180; return Pt(x: cos(r), y: sin(r))
    }
}

private func band(_ p0: Pt, _ p1: Pt, _ n: Pt, _ t1: Double, _ t2: Double) -> [Pt] {
    [vadd(p0, n, t1), vadd(p1, n, t1), vadd(p1, n, t2), vadd(p0, n, t2)]
}

/// One face of a piece that acts as a wall: from a to b, facing look, h high.
struct IwFace: Equatable { let a: Pt; let b: Pt; let look: Pt; let h: Int }

/// A piece in the room: its body rectangles (plan, 3D), its faces, its direction and across, its middle and ends, its
/// height and an arch's passage.
struct IwGeo {
    let R: [[Pt]]
    let F: [IwFace]
    let d: Pt
    let n: Pt
    let c: Pt
    let P0: Pt
    let P1: Pt
    let H: Int
    let gap: (Pt, Pt)?
}

func iwGeo(_ p: InnerWall, _ rh: Int) -> IwGeo {
    let d = iwDir(p.ang), n = Pt(x: -d.y, y: d.x), c = Pt(x: Double(p.x), y: Double(p.y))
    let t = Double(p.th) / 2, L = Double(p.len)
    let P0 = vadd(c, d, -L / 2), P1 = vadd(c, d, L / 2)
    let H = p.k == "half" ? (p.h > 0 ? p.h : 1100) : rh
    var R: [[Pt]] = [], F: [IwFace] = []
    var gap: (Pt, Pt)? = nil
    func face(_ a: Pt, _ b: Pt, _ look: Pt) { if vdist(a, b) >= 50 { F.append(IwFace(a: a, b: b, look: look, h: H)) } }
    if p.k == "col" {
        let s = L / 2
        if p.round {
            R.append((0..<20).map { i in let an = Double(i) / 20 * .pi * 2; return Pt(x: c.x + cos(an) * s, y: c.y + sin(an) * s) })
        } else {
            R.append([Pt(x: c.x - s, y: c.y - s), Pt(x: c.x + s, y: c.y - s), Pt(x: c.x + s, y: c.y + s), Pt(x: c.x - s, y: c.y + s)])
        }
        return IwGeo(R: R, F: F, d: d, n: n, c: c, P0: P0, P1: P1, H: H, gap: nil)
    }
    if p.k == "arch", let op = p.op {
        let w = min(Double(op.w), L - 200)
        let g0 = vadd(c, d, -w / 2), g1 = vadd(c, d, w / 2)
        gap = (g0, g1)
        R.append(band(P0, g0, n, t, -t)); R.append(band(g1, P1, n, t, -t))
    } else { R.append(band(P0, P1, n, t, -t)) }
    let L2 = Double(p.len2)
    if p.k == "L" {
        let e = vadd(P1, d, -2 * t)
        R.append([vadd(e, n, t), vadd(P1, n, t), vadd(P1, n, t + L2), vadd(e, n, t + L2)])
        face(vadd(P0, n, t), vadd(e, n, t), n)
        face(vadd(P1, n, -t), vadd(P0, n, -t), vneg(n))
        face(vadd(P1, n, -t), vadd(P1, n, t + L2), d)
        face(vadd(e, n, t + L2), vadd(e, n, t), vneg(d))
    } else if p.k == "T" {
        let l = vadd(c, d, -t), rr = vadd(c, d, t)
        R.append([vadd(l, n, t), vadd(rr, n, t), vadd(rr, n, t + L2), vadd(l, n, t + L2)])
        face(vadd(P0, n, t), vadd(l, n, t), n)
        face(vadd(rr, n, t), vadd(P1, n, t), n)
        face(vadd(P1, n, -t), vadd(P0, n, -t), vneg(n))
        face(vadd(rr, n, t), vadd(rr, n, t + L2), d)
        face(vadd(l, n, t + L2), vadd(l, n, t), vneg(d))
    } else {
        face(vadd(P0, n, t), vadd(P1, n, t), n)
        face(vadd(P1, n, -t), vadd(P0, n, -t), vneg(n))
    }
    return IwGeo(R: R, F: F, d: d, n: n, c: c, P0: P0, P1: P1, H: H, gap: gap)
}

/// Every piece's faces in order: the piece, the face's key "<id>:<n>", its ends, its side and height.
struct IwFaceRef: Equatable { let key: String; let pid: String; let face: IwFace; let th: Int; let k: String }

func iwFaces(_ r: Room) -> [IwFaceRef] {
    let rh = reHeight(r)
    var out: [IwFaceRef] = []
    for p in r.inner {
        for (j, f) in iwGeo(p, rh).F.enumerated() { out.append(IwFaceRef(key: p.id + ":" + String(j), pid: p.id, face: f, th: p.th, k: p.k)) }
    }
    return out
}

/// The piece a face key belongs to, or nil (an outer wall).
func iwPieceOf(_ wall: String) -> String? {
    guard let i = wall.firstIndex(of: ":") else { return nil }
    return String(wall[..<i])
}

/* ---------------- what a ray meets ---------------- */

/// A segment something can stop at, and what it is ("o<wall id>" an outer wall, "p<id>" a piece, "f<id>" furniture).
struct IwSeg { let a: Pt; let b: Pt; let ref: String }

func iwPolySegs(_ P: [Pt], _ ref: String) -> [IwSeg] { P.indices.map { IwSeg(a: P[$0], b: P[($0 + 1) % P.count], ref: ref) } }

/// The outer walls and the pieces (except exP), plus extra polygons (furniture).
func iwObstacles(_ r: Room, _ outer: [ReWall], exP: String? = nil, extra: [(String, [Pt])] = []) -> [IwSeg] {
    var out = outer.map { IwSeg(a: $0.a, b: $0.b, ref: "o" + $0.id) }
    let rh = reHeight(r)
    for p in r.inner where p.id != exP { for R in iwGeo(p, rh).R { out += iwPolySegs(R, "p" + p.id) } }
    for (ref, P) in extra { out += iwPolySegs(P, ref) }
    return out
}

/// How far from o along dir the first segment is met (t; .infinity none) and which.
func iwRay(_ o: Pt, _ dir: Pt, _ segs: [IwSeg]) -> (t: Double, ref: String?) {
    var best = Double.infinity, ref: String? = nil
    for sg in segs {
        let ex = sg.b.x - sg.a.x, ey = sg.b.y - sg.a.y, den = dir.x * ey - dir.y * ex
        if abs(den) < 1e-9 { continue }
        let wx = sg.a.x - o.x, wy = sg.a.y - o.y
        let t = (wx * ey - wy * ex) / den, u = (wx * dir.y - wy * dir.x) / den
        if t > 0.5 && u >= -1e-6 && u <= 1 + 1e-6 && t < best { best = t; ref = sg.ref }
    }
    return (best, ref)
}

func iwInside(_ q: Pt, _ poly: [Pt]) -> Bool {
    var c = false
    var j = poly.count - 1
    for i in poly.indices {
        let a = poly[i], b = poly[j]
        if (a.y > q.y) != (b.y > q.y) && q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
        j = i
    }
    return c
}

/* ---------------- smart snap ---------------- */

/// p with its ends stretched (or shrunk) to the walls within 300 mm, and its L or T wing too; stretched: it changed;
/// hits: the walls and pieces it now touches (refs).
func iwSnap(_ r: Room, _ outer: [ReWall], _ poly: [Pt], _ p0: InnerWall) -> (p: InnerWall, stretched: Bool, hits: [String]) {
    var p = p0, str = false, hits: [String] = []
    if p.k == "col" { return (p, false, []) }
    let segs = iwObstacles(r, outer, exP: p.id), d = iwDir(p.ang)
    var c = Pt(x: Double(p.x), y: Double(p.y))
    guard iwInside(c, poly) else { return (p, false, []) }
    let L2 = Double(p.len) / 2
    let hp = iwRay(c, d, segs), hm = iwRay(c, vneg(d), segs)
    var ep = L2, em = L2
    if hp.t.isFinite && hp.t - L2 <= IW_MAG { if abs(hp.t - L2) > 1 { str = true }; ep = hp.t; if let x = hp.ref { hits.append(x) } }
    if hm.t.isFinite && hm.t - L2 <= IW_MAG { if abs(hm.t - L2) > 1 { str = true }; em = hm.t; if let x = hm.ref { hits.append(x) } }
    if ep + em >= 300 {
        c = vadd(c, d, (ep - em) / 2)
        p.len = Int((ep + em).rounded()); p.x = Int(c.x.rounded()); p.y = Int(c.y.rounded())
    }
    if p.k == "L" || p.k == "T" {
        let n = Pt(x: -d.y, y: d.x), t = Double(p.th) / 2
        let mid = Pt(x: Double(p.x), y: Double(p.y))
        let b = p.k == "L" ? vadd(vadd(mid, d, Double(p.len) / 2), d, -t) : mid
        let ha = iwRay(b, n, segs), end = t + Double(p.len2)
        if ha.t.isFinite && ha.t - end <= IW_MAG {
            if abs(ha.t - end) > 1 { str = true }
            p.len2 = max(300, Int((ha.t - t).rounded()))
            if let x = ha.ref { hits.append(x) }
        }
    }
    return (p, str, hits)
}

/// The gaps from a piece to the nearest wall: S1 / S0 across it, E1 / E0 past its ends (a column all four): the gap,
/// where its line starts and ends, and the direction it is measured in.
struct IwGap: Equatable { let gap: Int; let a: Pt; let b: Pt; let dir: Pt }

func iwSides(_ r: Room, _ outer: [ReWall], _ p: InnerWall) -> [String: IwGap] {
    let G = iwGeo(p, reHeight(r)), segs = iwObstacles(r, outer, exP: p.id), d = G.d, n = G.n, t = Double(p.th) / 2
    var res: [String: IwGap] = [:]
    if p.k == "col" {
        let s = Double(p.len) / 2
        for (dir, key) in [(d, "E1"), (vneg(d), "E0"), (n, "S1"), (vneg(n), "S0")] {
            let h = iwRay(G.c, dir, segs)
            if h.t.isFinite { res[key] = IwGap(gap: Int((h.t - s).rounded()), a: vadd(G.c, dir, s), b: vadd(G.c, dir, h.t), dir: dir) }
        }
        return res
    }
    let o1 = p.k == "T" ? vadd(G.c, d, -Double(p.len) / 4) : G.c
    for (dir, key, org) in [(n, "S1", o1), (vneg(n), "S0", G.c)] {
        let h = iwRay(org, dir, segs)
        if h.t.isFinite { res[key] = IwGap(gap: Int((h.t - t).rounded()), a: vadd(org, dir, t), b: vadd(org, dir, h.t), dir: dir) }
    }
    for (dir, key) in [(d, "E1"), (vneg(d), "E0")] {
        let h = iwRay(G.c, dir, segs)
        if h.t.isFinite {
            let gp = Int((h.t - Double(p.len) / 2).rounded())
            if gp > 5 { res[key] = IwGap(gap: gp, a: vadd(G.c, dir, Double(p.len) / 2), b: vadd(G.c, dir, h.t), dir: dir) }
        }
    }
    return res
}

/// A new piece of kind k in the middle c, shrunk so it does not stretch to the walls at once (mockup iwPick).
func iwNew(_ k: String, _ c: Pt, _ r: Room, _ outer: [ReWall], id: String = uid()) -> InnerWall {
    let D = iwKind(k)
    var p = InnerWall(id: id, k: k, x: Int(c.x.rounded()), y: Int(c.y.rounded()), len: D.len, len2: D.len2, th: k == "col" ? 400 : 100, h: D.h)
    if k == "arch", let op = D.op { p.op = InnerOp(w: op.w, h: min(op.h, reHeight(r) - 100)) }
    if k != "col" {
        let segs = iwObstacles(r, outer).filter { $0.ref.hasPrefix("o") }
        let tot = iwRay(c, Pt(x: 1, y: 0), segs).t + iwRay(c, Pt(x: -1, y: 0), segs).t
        let mx = tot - 2 * (IW_MAG + 60)
        if tot.isFinite && Double(p.len) > mx { p.len = max(600, Int((mx / 10).rounded()) * 10) }
        if p.len2 > 0 {
            let up = iwRay(c, Pt(x: 0, y: 1), segs).t, m2 = up - Double(p.th) / 2 - IW_MAG - 60
            if up.isFinite && Double(p.len2) > m2 { p.len2 = max(300, Int((m2 / 10).rounded()) * 10) }
        }
    }
    return p
}

/* ---------------- overlaps and door zones ---------------- */

/// Two convex polygons overlap (separating axes, 2 mm so touching is not overlapping).
func iwSat(_ A: [Pt], _ B: [Pt]) -> Bool {
    func proj(_ P: [Pt], _ nx: Double, _ ny: Double) -> (Double, Double) {
        var mn = Double.infinity, mx = -Double.infinity
        for q in P { let v = q.x * nx + q.y * ny; mn = min(mn, v); mx = max(mx, v) }
        return (mn, mx)
    }
    for Q in [A, B] {
        for i in Q.indices {
            let a = Q[i], b = Q[(i + 1) % Q.count]
            var nx = b.y - a.y, ny = a.x - b.x
            let l = hypot(nx, ny)
            if l < 1e-9 { continue }
            nx /= l; ny /= l
            let p1 = proj(A, nx, ny), p2 = proj(B, nx, ny)
            if p1.1 <= p2.0 + 2 || p2.1 <= p1.0 + 2 { return false }
        }
    }
    return true
}

/// The space a door needs (mockup doorZones): its swing when it opens inward, else at least 300 mm in front of the
/// doorway; a door in an inner wall that opens away also needs the other side. walls: every wall and face by id with
/// its into-the-room side.
struct IwZone { let id: String; let wall: String; let swing: Bool; let pid: String?; let poly: [Pt] }

func iwDoorZones(_ r: Room, _ walls: [(id: String, a: Pt, u: Pt, n: Pt, th: Int, inner: Bool)]) -> [IwZone] {
    var out: [IwZone] = []
    for o in r.openings where o.type == "door" {
        guard let f = walls.first(where: { $0.id == o.wall }) else { continue }
        let st = reStyle("door", o.style).id
        let dw = st == "balcony" ? o.dw : o.w
        let leaf = st == "double" ? o.w / 2 : dw
        let swing = st != "arch" && st != "slide" && (o.sw.isEmpty || o.sw.hasPrefix("in"))
        let D = Double(swing ? max(leaf, 300) : 300)
        let p0 = vadd(f.a, f.u, Double(o.off)), p1 = vadd(f.a, f.u, Double(o.off + dw))
        let pid = f.inner ? iwPieceOf(f.id) : nil
        out.append(IwZone(id: o.id, wall: o.wall, swing: swing, pid: pid, poly: band(p0, p1, f.n, 1, D)))
        if f.inner && !swing && st != "slide" {
            let th = Double(f.th)
            out.append(IwZone(id: o.id, wall: o.wall, swing: st != "arch", pid: pid, poly: band(p0, p1, f.n, -th - 1, -th - Double(max(st == "arch" ? 300 : leaf, 300)))))
        }
    }
    return out
}

/// The pieces that fall into a door's swing or block a doorway (mockup iwIssues): the piece id and whether it was the
/// swing, with the door's wall.
func iwIssues(_ r: Room, _ zones: [IwZone]) -> [(pid: String, swing: Bool, wall: String)] {
    var out: [(pid: String, swing: Bool, wall: String)] = []
    let rh = reHeight(r)
    for p in r.inner {
        let R = iwGeo(p, rh).R
        var seen = Set<String>()
        for z in zones where z.pid != p.id && !seen.contains(z.id) {
            if R.contains(where: { iwSat($0, z.poly) }) { seen.insert(z.id); out.append((p.id, z.swing, z.wall)) }
        }
    }
    return out
}

/* ---------------- the room turned or mirrored: the pieces go with it ---------------- */

/// Every piece moved as the room's wall A moved (from a0 along u0 with n0 into the room, to a1, u1, n1): a turn or a mirror.
func iwRemap(_ r: inout Room, from w0: (a: Pt, u: Pt, n: Pt), to w1: (a: Pt, u: Pt, n: Pt)) {
    func map(_ q: Pt) -> Pt {
        let dx = q.x - w0.a.x, dy = q.y - w0.a.y
        let s = dx * w0.u.x + dy * w0.u.y, t = dx * w0.n.x + dy * w0.n.y
        return Pt(x: w1.a.x + w1.u.x * s + w1.n.x * t, y: w1.a.y + w1.u.y * s + w1.n.y * t)
    }
    r.inner = r.inner.map { p in
        var x = p
        let c = map(Pt(x: Double(p.x), y: Double(p.y)))
        let d = iwDir(p.ang)
        let s = d.x * w0.u.x + d.y * w0.u.y, t = d.x * w0.n.x + d.y * w0.n.y
        let nd = Pt(x: w1.u.x * s + w1.n.x * t, y: w1.u.y * s + w1.n.y * t)
        x.x = Int(c.x.rounded()); x.y = Int(c.y.rounded())
        let a = Int((atan2(nd.y, nd.x) * 180 / .pi / 90).rounded()) * 90
        x.ang = ((a % 360) + 360) % 360
        return x
    }
}

/* ---------------- what the trades count ---------------- */

/// The floor the inner walls stand on and the wall area of all their faces (both sides, a wing's too, a column's
/// sides), mm²: an arch's passage is left out of both its faces.
func iwAreas(_ r: Room, _ rh: Int) -> (floor: Int64, wall: Int64) {
    var fl = 0.0, wl = 0.0
    for p in r.inner {
        let G = iwGeo(p, rh)
        for R in G.R {
            var s = 0.0
            for i in R.indices { let a = R[i], b = R[(i + 1) % R.count]; s += a.x * b.y - b.x * a.y }
            fl += abs(s) / 2
        }
        if p.k == "col" {
            let per = p.round ? Double.pi * Double(p.len) : 4 * Double(p.len)
            wl += per * Double(G.H)
            continue
        }
        for f in G.F { wl += hypot(f.b.x - f.a.x, f.b.y - f.a.y) * Double(f.h) }
        if p.k == "arch", let op = p.op { wl -= 2 * Double(min(op.w, p.len - 200)) * Double(min(op.h, G.H)) }
    }
    return (Int64(fl.rounded()), Int64(max(0, wl).rounded()))
}
