import Foundation

/*
 * Placing furniture by dragging it on the room's plan (Android furniture/Placing.kt): the walls seen from above, where
 * each piece stands on the floor or hangs on a wall, and what it gets in the way of (another piece, a door's swing, a window).
 */

/// A point or a direction on the room's plan, mm.
struct PlanPt: Equatable {
    var x: Double, y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static func + (a: PlanPt, b: PlanPt) -> PlanPt { PlanPt(a.x + b.x, a.y + b.y) }
    static func - (a: PlanPt, b: PlanPt) -> PlanPt { PlanPt(a.x - b.x, a.y - b.y) }
    static func * (a: PlanPt, k: Double) -> PlanPt { PlanPt(a.x * k, a.y * k) }
    func dot(_ o: PlanPt) -> Double { x * o.x + y * o.y }
}

/// A wall on the plan: from p0 to p1, u along it, n into the room, len mm.
struct PlanWall {
    let id: String, p0: PlanPt, p1: PlanPt, u: PlanPt, n: PlanPt, len: Double
    func at(_ a: Double, _ d: Double) -> PlanPt { p0 + u * a + n * d }
    func along(_ q: PlanPt) -> Double { (q - p0).dot(u) }
    /// How far q is from the wall itself (not its line).
    func dist(_ q: PlanPt) -> Double { let c = at(min(max(along(q), 0), len), 0); return hypot(q.x - c.x, q.y - c.y) }
}

/// The room's walls on the plan, each with its into-the-room side.
func planWalls(_ r: Room, _ snap: Bool) -> [PlanWall] {
    let ws = Geo.walls(r, snap)
    let poly = ws.map { PlanPt($0.p0.x, $0.p0.y) }
    return ws.map { w in
        let p0 = PlanPt(w.p0.x, w.p0.y), p1 = PlanPt(w.p1.x, w.p1.y)
        let l = max(1, hypot(p1.x - p0.x, p1.y - p0.y))
        let u = PlanPt((p1.x - p0.x) / l, (p1.y - p0.y) / l)
        let n0 = PlanPt(-u.y, u.x)
        let n = inside(poly, p0 + u * (l / 2) + n0 * 20) ? n0 : n0 * -1
        return PlanWall(id: w.id, p0: p0, p1: p1, u: u, n: n, len: l)
    }
}

/// Whether q is inside the polygon poly.
func inside(_ poly: [PlanPt], _ q: PlanPt) -> Bool {
    var c = false
    for i in poly.indices {
        let a = poly[i], b = poly[(i + 1) % poly.count]
        if (a.y > q.y) != (b.y > q.y) && q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
    }
    return c
}

/// Where a piece stands on the plan: o its back's left end, u along its back, n out of its front.
struct Frame { var o: PlanPt, u: PlanPt, n: PlanPt }

/// The plan frame of p (the same turn as the 3D's poseBasis).
func frameOf(_ walls: [PlanWall], _ p: Pose) -> Frame? {
    guard let w = walls.first(where: { $0.id == p.ref }) else { return nil }
    let r = Double(p.deg) * .pi / 180, c = cos(r), s = sin(r)
    return Frame(o: w.at(Double(p.a), Double(p.n)), u: w.u * c + w.n * s, n: w.n * c - w.u * s)
}

/// The pose of frame fr measured from wall ref, to the millimetre and the degree.
func poseOf(_ walls: [PlanWall], _ ref: String, _ fr: Frame) -> Pose {
    guard let w = walls.first(where: { $0.id == ref }) else { return Pose(ref, 0, 0) }
    let d = fr.o - w.p0
    let deg = Int((atan2(fr.u.dot(w.n), fr.u.dot(w.u)) * 180 / .pi).rounded())
    return Pose(ref, Int(d.dot(w.u).rounded()), Int(d.dot(w.n).rounded()), (deg % 360 + 360) % 360)
}

/// fr turned by delta degrees about the middle of a w × d box.
func turned(_ fr: Frame, _ w: Double, _ d: Double, _ delta: Int) -> Frame {
    let r = Double(delta) * .pi / 180, c = cos(r), s = sin(r)
    let u = fr.u * c + fr.n * s, n = fr.n * c - fr.u * s
    let mid = fr.o + fr.u * (w / 2) + fr.n * (d / 2)
    return Frame(o: mid - u * (w / 2) - n * (d / 2), u: u, n: n)
}

/// What a piece covers: the box pts from lo to hi mm above the floor; on wall from a0 to a1 along it, or free (wall nil);
/// floor it stands on the floor (wall units hang); island it is the kitchen's island.
struct Foot { let pts: [PlanPt]; let lo: Int; let hi: Int; let wall: String?; let a0: Double; let a1: Double; let floor: Bool; var island = false }

private func box(_ fr: Frame, _ a0: Double, _ a1: Double, _ d: Double) -> [PlanPt] {
    [fr.o + fr.u * a0, fr.o + fr.u * a1, fr.o + fr.u * a1 + fr.n * d, fr.o + fr.u * a0 + fr.n * d]
}

private func wallFrame(_ w: PlanWall) -> Frame { Frame(o: w.p0, u: w.u, n: w.n) }

/// The frame of a piece's main part: a wardrobe or cabinet where it stands, a kitchen's first side from where it starts.
func mainFrame(_ f: Furniture, _ walls: [PlanWall]) -> Frame? {
    if f.kind == "wardrobe" {
        if let p = f.pose { return frameOf(walls, p) }
        guard let m = wardOfF(f), let w = walls.first(where: { $0.id == m.wall }) else { return nil }
        return Frame(o: w.at(Double(m.x), 0), u: w.u, n: w.n)
    }
    guard let w = walls.first(where: { $0.id == f.walls.first { $0 != ISLAND } }) else { return nil }
    return Frame(o: w.at(Double(leadOf(f)), 0), u: w.u, n: w.n)
}

/// The island's pose: where it was dragged, else its usual place in front of the first side.
func islandPoseIn(_ f: Furniture, _ walls: [PlanWall]) -> Pose? {
    guard f.walls.contains(ISLAND) else { return nil }
    if let p = f.pose { return p }
    return walls.first { $0.id == f.walls.first { $0 != ISLAND } }.map { islandPose(f, Int($0.len.rounded())) }
}

/// Everything f covers in the room: a cabinet's box, a kitchen's lower row, tall units and wall units on each side, its island.
func footsOf(_ f: Furniture, _ walls: [PlanWall], _ ws: Workshop) -> [Foot] {
    var out: [Foot] = []
    if f.kind == "wardrobe" {
        guard let m = wardOfF(f) else { return out }
        let hi = outerH(m, ws)
        if let p = f.pose {
            if let fr = frameOf(walls, p) { out.append(Foot(pts: box(fr, 0, Double(m.w), Double(m.d)), lo: 0, hi: hi, wall: nil, a0: 0, a1: 0, floor: true)) }
        } else if let w = walls.first(where: { $0.id == m.wall }) {
            let a0 = Double(m.x), a1 = Double(m.x + m.w)
            out.append(Foot(pts: box(wallFrame(w), a0, a1, Double(m.d)), lo: 0, hi: hi, wall: w.id, a0: a0, a1: a1, floor: true))
        }
        return out
    }
    for id in f.walls where id != ISLAND {
        guard let w = walls.first(where: { $0.id == id }) else { continue }
        let ms = f.modules.filter { $0.wall == id && !($0.type == "gap" && $0.app == "space") }
        func row(_ sel: [Module], _ d: Int, _ lo: Int, _ hi: Int, _ floor: Bool) {
            guard let a0 = sel.map(\.x).min(), let a1 = sel.map({ $0.x + $0.w }).max() else { return }
            out.append(Foot(pts: box(wallFrame(w), Double(a0), Double(a1), Double(d)), lo: lo, hi: hi, wall: id, a0: Double(a0), a1: Double(a1), floor: floor))
        }
        // the lower row under its worktop, 600 deep
        row(ms.filter { !isUpper($0) && $0.type != "tall" }, 600, 0, worktopTop(ws), true)
        for t in ms where t.type == "tall" { row([t], t.d, 0, t.elev + t.h, true) }
        let up = ms.filter { isUpper($0) }
        if !up.isEmpty { row(up, up.map(\.d).max() ?? 350, up.map(\.elev).min() ?? 0, up.map { $0.elev + $0.h }.max() ?? 0, false) }
    }
    if let p = islandPoseIn(f, walls), let fr = frameOf(walls, p) {
        // its worktop reaches 318 mm past its back, for sitting at
        let l = Double(islandLen(f))
        out.append(Foot(pts: [fr.o - fr.n * 318, fr.o + fr.u * l - fr.n * 318, fr.o + fr.u * l + fr.n * 600, fr.o + fr.n * 600],
                        lo: 0, hi: worktopTop(ws), wall: nil, a0: 0, a1: 0, floor: true, island: true))
    }
    return out
}

/// Whether two convex boxes overlap by more than a few millimetres (pieces side by side only touch).
func overlaps(_ a: [PlanPt], _ b: [PlanPt], _ eps: Double = 5) -> Bool {
    for poly in [a, b] {
        for i in poly.indices {
            let e = poly[(i + 1) % poly.count] - poly[i]
            let l = hypot(e.x, e.y)
            if l < 1e-9 { continue }
            let ax = PlanPt(-e.y / l, e.x / l)
            let pa = a.map { $0.dot(ax) }, pb = b.map { $0.dot(ax) }
            if min(pa.max()!, pb.max()!) - max(pa.min()!, pb.min()!) <= eps { return false }
        }
    }
    return true
}

/// What f gets in the way of where it stands: out of the room, on another piece of others, in a door's swing, in front
/// of a window. It may stay there; the plan shows it red and says why.
func placeWarnings(_ f: Furniture, _ others: [Furniture], _ room: Room, _ walls: [PlanWall], _ ws: Workshop) -> [FitIssue] {
    let mine = footsOf(f, walls, ws)
    var out: [FitIssue] = []
    let poly = walls.map(\.p0)
    if mine.contains(where: { ft in ft.wall == nil && ft.pts.contains { q in !inside(poly, q) && (walls.map { $0.dist(q) }.min() ?? 0) > 5 } }) {
        out.append(FitIssue(key: "fz.outside", vars: ["n": f.name]))
    }
    for o in others {
        let theirs = footsOf(o, walls, ws)
        if mine.contains(where: { a in theirs.contains { b in a.lo < b.hi && b.lo < a.hi && overlaps(a.pts, b.pts) } }) { out.append(FitIssue(key: "fz.hitPiece", vars: ["n": o.name])) }
    }
    for op in room.openings {
        guard let w = walls.first(where: { $0.id == op.wall }) else { continue }
        let a0 = Double(op.off), a1 = Double(op.off + op.w)
        let hit: Bool
        if op.type == "door" {
            let swing = box(wallFrame(w), a0, a1, Double(op.w))
            hit = mine.contains { $0.floor && overlaps($0.pts, swing) }
        } else {
            hit = mine.contains { $0.wall == op.wall && min($0.a1, a1) - max($0.a0, a0) > 20 && $0.hi > op.sill + 20 && $0.lo < op.sill + op.h }
        }
        if hit { out.append(FitIssue(key: op.type == "door" ? "fz.hitDoor" : "fz.hitWin", vars: ["w": op.wall])) }
    }
    var seen = Set<String>()
    return out.filter { seen.insert($0.key + ($0.vars["n"] ?? "") + ($0.vars["w"] ?? "")).inserted }
}
