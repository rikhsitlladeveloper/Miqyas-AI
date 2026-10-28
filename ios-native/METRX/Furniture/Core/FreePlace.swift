import Foundation

/*
 * "Mebel joylash" (room-editor mockup v3, approved 28 Oct 2026: FD, fGeo, fIssues, fGaps, fFlush, fToFree, fStickTo):
 * the room's pieces seen from above, any cabinet-engine piece against a wall or free in the room. A free piece is the
 * order's Pose (as the island and the desks already were, so older orders read as before): its main frame from a wall,
 * turned any number of degrees. Red: it overlaps another piece, an inner wall, a door's swing or doorway, or goes
 * through a wall; yellow: a passage under 700 mm to a wall or another piece. Pure Swift, unit-tested (FreePlaceTests).
 * Coordinates are the plan's (Geo.walls, planWalls); the inner walls are brought into them from the editor's plan.
 */

let FP_PASS = 700
let FP_FLUSH = 60.0
let FP_ROT = 15

/// Any piece on the cabinet engine can stand free (a bed, a table, a wardrobe…) except the corner pieces; a kitchen stays
/// on its walls (its island moves in its own place screen).
func canBeFree(_ f: Furniture) -> Bool { f.kind == "wardrobe" && !CORNER_TYPES.contains(f.type) }

/// The room as Mebel joylash draws it: its walls in planWalls' millimetres, the inner walls brought there from the
/// editor's plan (a rectangle there is turned by Room.rot), their faces after the outer walls.
func fpGeo(_ r: Room, _ snap: Bool) -> (g: ReRoomGeo, room: Room) {
    let ws = Geo.walls(r, snap)
    let walls = ws.map { w in ReWall(id: w.id, a: w.p0, b: w.p1, len: w.len ?? kround(hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y)), t: r.thickOf(w.id), auto: false) }
    let base = ReRoomGeo(walls: walls, poly: ws.map(\.p0), H: reHeight(r))
    var x = r
    if !r.inner.isEmpty, let f0 = reWallAFrame(reGeo(r, snap)), let f1 = reWallAFrame(base) { iwRemap(&x, from: f0, to: f1) }
    return (reWithFaces(x, base), x)
}

/// A piece on the plan: its floor boxes, and its main box (centre c, along its back ax, out of its front ay, w × d,
/// from the main frame's o by a0 along and b0 out); free: it stands by its pose; wall: the wall it stands on.
struct FpPiece {
    let id: String
    let name: String
    let foots: [[PlanPt]]
    let c: PlanPt
    let ax: PlanPt
    let ay: PlanPt
    let w: Double
    let d: Double
    let a0: Double
    let b0: Double
    let free: Bool
    let wall: String?
    let kitchen: Bool
}

func fpPiece(_ f: Furniture, _ walls: [PlanWall], _ ws: Workshop) -> FpPiece? {
    let foots = footsOf(f, walls, ws).filter { $0.floor && $0.pts.count >= 3 }
    guard !foots.isEmpty, let fr = mainFrame(f, walls) else { return nil }
    let pts = foots.flatMap(\.pts)
    let us = pts.map { ($0 - fr.o).dot(fr.u) }, ns = pts.map { ($0 - fr.o).dot(fr.n) }
    let a0 = us.min()!, a1 = us.max()!, b0 = ns.min()!, b1 = ns.max()!
    let c = fr.o + fr.u * ((a0 + a1) / 2) + fr.n * ((b0 + b1) / 2)
    return FpPiece(id: f.id, name: f.name, foots: foots.map(\.pts), c: c, ax: fr.u, ay: fr.n, w: a1 - a0, d: b1 - b0, a0: a0, b0: b0,
                   free: f.pose != nil && f.kind == "wardrobe", wall: f.pose == nil ? (f.kind == "wardrobe" ? wardOfF(f)?.wall : f.walls.first { $0 != ISLAND }) : nil,
                   kitchen: f.kind == "kitchen")
}

/// The piece's angle on the plan, degrees 0 – 359 (its back's direction).
func fpAngle(_ p: FpPiece) -> Int { ((Int((atan2(p.ax.y, p.ax.x) * 180 / .pi).rounded()) % 360) + 360) % 360 }

private func pp(_ q: Pt) -> PlanPt { PlanPt(q.x, q.y) }
private func ptOf(_ q: PlanPt) -> Pt { Pt(x: q.x, y: q.y) }

/// A box shrunk by k mm on every side (so touching is not overlapping).
func fpInset(_ P: [PlanPt], _ k: Double) -> [PlanPt] {
    guard P.count == 4 else { return P }
    let c = PlanPt((P[0].x + P[2].x) / 2, (P[0].y + P[2].y) / 2)
    return P.map { q in
        let v = q - c, l = hypot(v.x, v.y)
        // a corner moves in along both sides: k·√2 along the diagonal of a right-angled box
        return l < 1e-9 ? q : q - v * (min(l * 0.9, k * 1.4142) / l)
    }
}

/// What a ray from the piece meets: the outer walls, the inner walls and the other pieces' floor boxes.
func fpSegs(_ g: ReRoomGeo, _ pieces: [FpPiece], ex: String) -> [IwSeg] {
    var out = g.outer.map { IwSeg(a: $0.a, b: $0.b, ref: "o" + $0.id) }
    for b in g.bodies { for R in b.R { out += iwPolySegs(R, "p" + b.pid) } }
    for p in pieces where p.id != ex { for P in p.foots { out += iwPolySegs(P.map(ptOf), "f" + p.id) } }
    return out
}

/// The four gaps of a piece along its own axes (right, left, front, back) to what is there: the gap, its line, the direction.
func fpGaps(_ p: FpPiece, _ g: ReRoomGeo, _ pieces: [FpPiece]) -> [IwGap?] {
    let segs = fpSegs(g, pieces, ex: p.id)
    let c = ptOf(p.c)
    return [(p.ax, p.w / 2), (p.ax * -1, p.w / 2), (p.ay, p.d / 2), (p.ay * -1, p.d / 2)].map { dir, half -> IwGap? in
        let d = ptOf(dir)
        let h = iwRay(c, d, segs)
        guard h.t.isFinite else { return nil }
        return IwGap(gap: Int((h.t - half).rounded()), a: Pt(x: c.x + d.x * half, y: c.y + d.y * half), b: Pt(x: c.x + d.x * h.t, y: c.y + d.y * h.t), dir: d)
    }
}

/// Red (why, as a key and its words) and yellow (the narrow passages) for each piece.
struct FpCheck { var red: [String: (key: String, vars: [String: String])] = [:]; var yel: [String: [IwGap]] = [:] }

func fpCheck(_ room: Room, _ g: ReRoomGeo, _ pieces: [FpPiece]) -> FpCheck {
    var out = FpCheck()
    let zones = iwDoorZones(room, iwZoneWalls(g))
    let poly = g.poly
    for p in pieces {
        var why: (String, [String: String])? = nil
        for P0 in p.foots where why == nil {
            let P = fpInset(P0, 6).map(ptOf)
            if let o = pieces.first(where: { o in o.id != p.id && o.foots.contains { iwSat(P, $0.map(ptOf)) } }) { why = ("fp.r.over", ["n": dn(o.name)]); break }
            if let z = zones.first(where: { iwSat(P, $0.poly) }) { why = (z.swing ? "fp.r.swing" : "fp.r.block", ["w": reWL(z.wall)]); break }
            if let b = g.bodies.first(where: { b in b.R.contains { iwSat(P, $0) } }) { why = ("fp.r.iw", ["n": iwName(b.k).lowercased()]); break }
            if P.contains(where: { !iwInside($0, poly) }) || g.outer.contains(where: { w in P.indices.contains { fpCross(P[$0], P[($0 + 1) % P.count], w.a, w.b) } }) {
                why = ("fp.r.out", [:]); break
            }
        }
        if let why { out.red[p.id] = (why.0, why.1); continue }
        // a passage under 700 mm beside it, checked across its middle and 40 % to each side
        guard !p.kitchen else { continue }
        let segs = fpSegs(g, pieces, ex: p.id)
        var lines: [IwGap] = []
        for (dir, half, side, sh) in [(p.ax, p.w / 2, p.ay, p.d / 2), (p.ax * -1, p.w / 2, p.ay, p.d / 2), (p.ay, p.d / 2, p.ax, p.w / 2), (p.ay * -1, p.d / 2, p.ax, p.w / 2)] {
            var best: IwGap? = nil
            for o in [-0.4, 0, 0.4] {
                let org = p.c + side * (sh * 2 * o)
                let h = iwRay(ptOf(org), ptOf(dir), segs)
                guard h.t.isFinite else { continue }
                let gap = Int((h.t - half).rounded())
                if best == nil || gap < best!.gap {
                    best = IwGap(gap: gap, a: ptOf(org + dir * half), b: ptOf(org + dir * h.t), dir: ptOf(dir))
                }
            }
            if let b = best, b.gap > 25, b.gap < FP_PASS { lines.append(b) }
        }
        if !lines.isEmpty { out.yel[p.id] = lines }
    }
    return out
}

/// Whether the segments a–b and c–d cross (not just touch).
func fpCross(_ a: Pt, _ b: Pt, _ c: Pt, _ d: Pt) -> Bool {
    func s(_ p: Pt, _ q: Pt, _ r: Pt) -> Double { (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x) }
    let d1 = s(c, d, a), d2 = s(c, d, b), d3 = s(a, b, c), d4 = s(a, b, d)
    return ((d1 > 1 && d2 < -1) || (d1 < -1 && d2 > 1)) && ((d3 > 1 && d4 < -1) || (d3 < -1 && d4 > 1))
}

/* ---------------- the changes ---------------- */

/// The pose of a piece whose main box has its middle at c, its back along ax (turned ang degrees), measured from ref.
func fpPoseAt(_ p: FpPiece, _ walls: [PlanWall], _ ref: String, c: PlanPt, ang: Int) -> Pose {
    let r = Double(ang) * .pi / 180
    let u = PlanPt(cos(r), sin(r))
    // the front stays on the same side of the back as it was
    let cr = p.ax.x * p.ay.y - p.ax.y * p.ay.x
    let n = cr >= 0 ? PlanPt(-u.y, u.x) : PlanPt(u.y, -u.x)
    let o = c - u * (p.a0 + p.w / 2) - n * (p.b0 + p.d / 2)
    return poseOf(walls, ref, Frame(o: o, u: u, n: n))
}

/// Free: the piece where it stands now, by a pose from its wall (or wall A).
func fpToFree(_ f: Furniture, _ walls: [PlanWall]) -> Furniture {
    guard canBeFree(f), f.pose == nil, let fr = mainFrame(f, walls) else { return f }
    var x = f
    x.pose = poseOf(walls, wardOfF(f)?.wall ?? walls.first?.id ?? "A", fr)
    return x
}

/// Moved so its middle is at c (a free piece), its sides flush with a wall or a piece within 60 mm; magnet: it stuck.
func fpMove(_ f: Furniture, _ p: FpPiece, _ c0: PlanPt, _ walls: [PlanWall], _ g: ReRoomGeo, _ pieces: [FpPiece]) -> (f: Furniture, magnet: Bool) {
    guard let pose = f.pose else { return (f, false) }
    var c = c0, mg = false
    let moved = FpPiece(id: p.id, name: p.name, foots: p.foots.map { $0.map { $0 + (c0 - p.c) } }, c: c0, ax: p.ax, ay: p.ay, w: p.w, d: p.d, a0: p.a0, b0: p.b0,
                        free: true, wall: nil, kitchen: false)
    for x in fpGaps(moved, g, pieces) {
        guard let x, Double(x.gap) > 0.5, Double(x.gap) < FP_FLUSH else { continue }
        c = c + PlanPt(x.dir.x, x.dir.y) * Double(x.gap); mg = true
    }
    var out = f
    out.pose = fpPoseAt(p, walls, pose.ref, c: c, ang: fpAngle(p))
    return (out, mg)
}

/// Turned to ang degrees about its middle.
func fpTurn(_ f: Furniture, _ p: FpPiece, _ walls: [PlanWall], _ ang: Int) -> Furniture {
    guard let pose = f.pose else { return f }
    var out = f
    out.pose = fpPoseAt(p, walls, pose.ref, c: p.c, ang: ((ang % 360) + 360) % 360)
    return out
}

/// "Devorga yopishtirish": on the nearest wall facing it that it fits on, as near to where it stands as it can; nil when
/// none fits.
func fpStick(_ f: Furniture, _ p: FpPiece, _ room: Room, _ walls: [PlanWall], _ ws: Workshop) -> (f: Furniture, wall: String, off: Int)? {
    var best: (d: Double, w: PlanWall)? = nil
    for w in walls where w.len >= p.w {
        guard (p.c - w.p0).dot(w.n) > -5 else { continue }
        let d = w.dist(p.c)
        if best == nil || d < best!.d { best = (d, w) }
    }
    guard let w = best?.w, let rid = f.roomId else { return nil }
    let off = Int(min(max(w.along(p.c) - p.w / 2, 0), w.len - p.w).rounded())
    var x = f
    x.pose = nil
    let snap = AppSettings.shared.angleSnap
    let g = placed(x, [w.id], rid, f.ws, off: off, keep: f.keep, len: { Geo.wallLen(room, $0, snap) }, ws: ws)
    return (g, w.id, off)
}

/// A piece on a wall slid to off mm from the wall's start (kept on it).
func fpSlide(_ f: Furniture, _ room: Room, _ wall: String, _ off: Int, _ ws: Workshop) -> Furniture {
    guard let rid = f.roomId, f.kind == "wardrobe", f.pose == nil else { return f }
    let snap = AppSettings.shared.angleSnap
    return placed(f, [wall], rid, f.ws, off: max(0, off), keep: f.keep, len: { Geo.wallLen(room, $0, snap) }, ws: ws)
}
