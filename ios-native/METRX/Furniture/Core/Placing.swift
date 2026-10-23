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
    // a NaN or an endless value (a degenerate frame) would crash Int(...): it counts as 0
    func whole(_ v: Double) -> Int { v.isFinite ? Int(v.rounded()) : 0 }
    let deg = whole(atan2(fr.u.dot(w.n), fr.u.dot(w.u)) * 180 / .pi)
    return Pose(ref, whole(d.dot(w.u)), whole(d.dot(w.n)), (deg % 360 + 360) % 360)
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
        // a piece of several boxes from where its run starts
        let x = boxes(f).count > 1 ? runStart(f) : m.x
        return Frame(o: w.at(Double(x), 0), u: w.u, n: w.n)
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
func footsOf(_ f: Furniture, _ walls: [PlanWall], _ ws0: Workshop) -> [Foot] {
    let ws = wsOf(f, ws0)
    var out: [Foot] = []
    if f.kind == "wardrobe" {
        guard let main = wardOfF(f) else { return out }
        // every box: one standing free moves with the main one, the others on their walls; a hung one off the floor
        for m in boxes(f) {
            let lo = hung(m) ? m.elev : 0
            let hi = topOf(m, ws)
            let floor = !hung(m)
            if let p = f.pose {
                if let fr = frameOf(walls, p) {
                    let a0 = Double(m.x - main.x)
                    out.append(Foot(pts: box(fr, a0, a0 + Double(m.w), Double(m.d)), lo: lo, hi: hi, wall: nil, a0: 0, a1: 0, floor: floor))
                }
            } else if let w = walls.first(where: { $0.id == m.wall }) {
                let a0 = Double(m.x), a1 = Double(m.x + m.w)
                out.append(Foot(pts: box(wallFrame(w), a0, a1, Double(m.d)), lo: lo, hi: hi, wall: w.id, a0: a0, a1: a1, floor: floor))
            }
        }
        return out
    }
    for id in f.walls where id != ISLAND {
        guard let w = walls.first(where: { $0.id == id }) else { continue }
        // empty stretches (before a corner kitchen, over a window) take no room; a dishwasher is under the worktop
        let ms = f.modules.filter { m in
            guard m.wall == id else { return false }
            return m.type != "gap" || m.app == "dishwasher" || m.app == "fridge"
        }
        func row(_ sel: [Module], _ d: Int, _ lo: Int, _ hi: Int, _ floor: Bool) {
            guard let a0 = sel.map(\.x).min(), let a1 = sel.map({ $0.x + $0.w }).max() else { return }
            out.append(Foot(pts: box(wallFrame(w), Double(a0), Double(a1), Double(d)), lo: lo, hi: hi, wall: id, a0: Double(a0), a1: Double(a1), floor: floor))
        }
        // the lower row under its worktop, 600 deep; tall units and a free-standing fridge their own
        row(ms.filter { !isUpper($0) && $0.type != "tall" && $0.app != "fridge" }, 600, 0, worktopTop(ws), true)
        for t in ms where t.type == "tall" || t.app == "fridge" { row([t], t.d, 0, t.elev + t.h, true) }
        let up = ms.filter { isUpper($0) }
        if !up.isEmpty { row(up, up.map(\.d).max() ?? 350, up.map(\.elev).min() ?? 0, up.map { $0.elev + $0.h }.max() ?? 0, false) }
    }
    if let p = islandPoseIn(f, walls), let fr = frameOf(walls, p) {
        // its worktop covers its cabinets and its finished back
        let l = Double(islandLen(f)), bk = Double(PEN_BACK)
        out.append(Foot(pts: [fr.o - fr.n * bk, fr.o + fr.u * l - fr.n * bk, fr.o + fr.u * l + fr.n * 600, fr.o + fr.n * 600],
                        lo: 0, hi: worktopTop(ws), wall: nil, a0: 0, a1: 0, floor: true, island: true))
    }
    return out
}

/// What a hinged door needs beside its hinge to open: its own thickness swinging past the hinge, and the handle there.
let HINGE_CLEAR = 50

/// Whether f's left and right ends (along its wall) have a door hinged right at them. A kitchen's run ends may.
func hingedEnds(_ f: Furniture) -> (Bool, Bool) {
    if f.kind != "wardrobe" { return (true, true) }
    // the boxes standing at the run's two ends (a corner piece's right end is its second arm's)
    let ms = f.modules.filter { $0.type == "wardrobe" && !hung($0) }
    let wl = f.walls.first, wr = f.walls.last
    let l = ms.filter { $0.wall == (wl ?? $0.wall) }.min(by: { $0.x < $1.x })
    let r = ms.filter { $0.wall == (wr ?? $0.wall) }.max(by: { $0.x + $0.w < $1.x + $1.w })
    func at(_ m: Module?, _ right: Bool) -> Bool {
        guard let m, m.slide == nil, !m.sections.isEmpty else { return false }
        let i = right ? m.sections.count - 1 : 0
        let s = m.sections[i]
        return s.fronts.kind == "door" && (s.fronts.n >= 2 || hingeRight(m, i) == right)
    }
    return (at(l, false), at(r, true))
}

/// How far from the corner a cabinet stands at its left (or right) end: 50 where a door hinges there, else 10.
func cornerGap(_ f: Furniture, right: Bool = false) -> Int {
    guard f.kind == "wardrobe" else { return W_GAP_SIDE }
    let ends = hingedEnds(f)
    return (right ? ends.1 : ends.0) ? HINGE_CLEAR : W_GAP_SIDE
}

/// A box in fr from a0 to a1 along and n0 to n1 out.
private func quad(_ fr: Frame, _ a0: Double, _ a1: Double, _ n0: Double, _ n1: Double) -> [PlanPt] {
    [fr.o + fr.u * a0 + fr.n * n0, fr.o + fr.u * a1 + fr.n * n0, fr.o + fr.u * a1 + fr.n * n1, fr.o + fr.u * a0 + fr.n * n1]
}

/// Where f's doors and drawers sweep when they open, in front of it: a door as far out as it is wide and, past its
/// hinge, its own thickness; a drawer as far as it pulls out.
func swingsOf(_ f: Furniture, _ walls: [PlanWall], _ ws0: Workshop) -> [Foot] {
    let ws = wsOf(f, ws0)
    var out: [Foot] = []
    // a kitchen's units stand unit to unit with their own hinges, so only a cabinet's door is held to its thickness past the hinge
    let past: Double = f.kind == "wardrobe" ? 20 : 0
    func door(_ fr: Frame, _ a0: Double, _ a1: Double, _ d: Double, _ hingeR: Bool, _ lo: Int, _ hi: Int) -> Foot {
        let b0 = a0 - (hingeR ? 0 : past), b1 = a1 + (hingeR ? past : 0)
        return Foot(pts: quad(fr, b0, b1, d, d + (a1 - a0)), lo: lo, hi: hi, wall: nil, a0: a0, a1: a1, floor: true)
    }
    func drawer(_ fr: Frame, _ a0: Double, _ a1: Double, _ d: Double, _ lo: Int, _ hi: Int) -> Foot {
        Foot(pts: quad(fr, a0, a1, d, d + d * 0.75), lo: lo, hi: hi, wall: nil, a0: a0, a1: a1, floor: true)
    }
    if f.kind == "wardrobe" {
        guard let main = wardOfF(f) else { return out }
        let p = f.pose
        // each box's frame: where the main one stands free, else its own wall at its start
        func frame(_ m: Module) -> Frame? {
            if let p {
                guard let fr = frameOf(walls, p) else { return nil }
                return Frame(o: fr.o + fr.u * Double(m.x - main.x), u: fr.u, n: fr.n)
            }
            guard let w = walls.first(where: { $0.id == m.wall }) else { return nil }
            return Frame(o: w.at(Double(m.x), 0), u: w.u, n: w.n)
        }
        for m in f.modules {
            guard let fr = frame(m) else { continue }
            if m.type == "bed" {
                // a bed's drawers pull out sideways from its long sides
                for d in bedDrawers(m, ws) {
                    let reach = Double(d.depth) * 0.75
                    let a0 = d.side < 0 ? -reach : Double(m.w)
                    let a1 = d.side < 0 ? 0.0 : Double(m.w) + reach
                    out.append(Foot(pts: quad(fr, a0, a1, Double(d.n0), Double(d.n1)), lo: d.y0, hi: d.y1, wall: nil, a0: 0, a1: 0, floor: true))
                }
            }
            if m.type != "wardrobe" || m.slide != nil { continue }
            let z = legsOf(m, ws) + m.elev
            let lo = z + wardBase(m), hi = z + m.h
            let d = Double(m.d)
            var a = 0.0
            for (i, s) in m.sections.enumerated() {
                let n = max(1, s.fronts.n), dw = Double(frontW(s)) / Double(n)
                if s.fronts.kind == "door" {
                    for j in 0..<n {
                        let right = n == 2 ? j == 1 : hingeRight(m, i)
                        out.append(door(fr, a + Double(j) * dw, a + Double(j + 1) * dw, d, right, lo, hi))
                    }
                } else if s.fronts.kind == "drawer" {
                    out.append(drawer(fr, a, a + Double(frontW(s)), d, lo, hi))
                }
                a += Double(s.w)
            }
        }
        return out
    }
    // a kitchen: each unit's doors (a single one hinged on its left, a pair on the outer edges) or drawers
    func unit(_ fr: Frame, _ m: Module) {
        let n = max(1, m.fronts.n), dw = Double(m.w) / Double(n)
        let a0 = Double(m.x), d = Double(m.d)
        if m.fronts.kind == "door" {
            for j in 0..<n { out.append(door(fr, a0 + Double(j) * dw, a0 + Double(j + 1) * dw, d, n == 2 && j == 1, m.elev, m.elev + m.h)) }
        } else if m.fronts.kind == "drawer" {
            out.append(drawer(fr, a0, a0 + Double(m.w), d, m.elev, m.elev + m.h))
        }
    }
    for id in f.walls where id != ISLAND {
        guard let w = walls.first(where: { $0.id == id }) else { continue }
        for m in f.modules where m.wall == id && m.type != "gap" && m.type != "filler" { unit(wallFrame(w), m) }
    }
    if let p = islandPoseIn(f, walls), let fr = frameOf(walls, p) {
        for m in f.modules where m.wall == ISLAND && m.type != "gap" && m.type != "filler" { unit(fr, m) }
    }
    return out
}

/// The strip in front of a piece where its doors and handles stand out (40 mm), the height of the piece.
private func frontBand(_ ft: Foot) -> Foot {
    let p = ft.pts
    let e = p[3] - p[0]
    let out = e * (40.0 / max(hypot(e.x, e.y), 1e-9))
    return Foot(pts: [p[3], p[2], p[2] + out, p[3] + out], lo: ft.lo, hi: ft.hi, wall: ft.wall, a0: ft.a0, a1: ft.a1, floor: ft.floor)
}

/// Whether any of the swings sw meets any of feet at a height both reach.
private func swingHits(_ sw: [Foot], _ feet: [Foot]) -> Bool {
    sw.contains { a in feet.contains { b in a.lo < b.hi && b.lo < a.hi && overlaps(a.pts, b.pts) } }
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
    // doors and drawers that hit something when they open: another piece or its fronts, or the room's walls
    let mySw = swingsOf(f, walls, ws)
    let myFronts = mine + mine.map(frontBand)
    for o in others {
        let theirs = footsOf(o, walls, ws)
        let theirFronts = theirs + theirs.map(frontBand)
        if swingHits(mySw, theirFronts) || swingHits(swingsOf(o, walls, ws), myFronts) { out.append(FitIssue(key: "fz.doorsHit", vars: ["n": o.name])) }
    }
    if mySw.contains(where: { ft in ft.pts.contains { q in !inside(poly, q) && (walls.map { $0.dist(q) }.min() ?? 0) > 5 } }) {
        out.append(FitIssue(key: "fz.doorRoom", vars: ["n": f.name]))
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
