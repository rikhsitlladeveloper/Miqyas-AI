import Foundation

/*
 * A finished room shape (RoomShapes.swift) as the app's real Room, so the room editor, the 3D view, the furniture and
 * the trades take it as they take a room made today (BUILD_SPEC §2). Pure Swift, unit-tested (RoomShapesTests). The
 * same rules as the Android app's geo/ShapeRoom.kt:
 *
 * - To‘rtburchak is the app's plain rectangle: shape "rect", dims A and B, the turn in Room.rot (wall i sits on side
 *   (i + rot) % 4, as RectPlan draws it). Nothing downstream changes.
 * - Every other shape is a drawn room (shape "poly"): its corners as shown (mirror and turn applied), clockwise, wall A
 *   on the shape's wall A, moved so the smallest x and y are 0. Mirroring reverses the walk, so the other letters run
 *   the other way round: ShapeRoom.wallIds says which room wall each shape wall became, flipped that it runs backwards.
 *   The room's letters are the editor's (Geo.polyWallIds: they skip H, so the bay's wall H is the room's J).
 * - Walls are confirmed measurements (Dim(v, "manual"), like a typed one), so the editor does not ask for them again.
 *   Up to two worked-out walls that are not parallel are left empty for the editor's solver, which shows them as
 *   computed (status "calc"), as the mockup's "avtomat"; those that are not whole mm (the cut, the bay's 45° sides)
 *   first, so every stored length is exact. The rest (the bay's front and its remaining wall) are stored measured.
 *   A free sketch's walls are the real corner distances after its closing gap is spread, so the room closes.
 * - Poly.snap only when every wall is at a 45° step (a cut corner at another angle or a tilted sketch keeps its own).
 * - The height is a confirmed H; the optional diagonal is the drawn room's diagonal X1 from corner A.
 * - Doors and windows become Openings, water, sewer and gas become SitePoints ("cold", "sewer", "gas"), measured from
 *   the room wall's own start corner (clockwise), so a flipped wall's distance is turned round (L − dist − w for a door
 *   or window, L − dist for a pipe).
 */

/// A shape made into a room. wallIds: the room wall id of each shape wall (index = shape wall); flipped: whether that
/// room wall runs the other way (its start corner is the shape wall's end); lens: each shape wall's length in the room, mm.
struct ShapeRoom: Equatable {
    var room: Room
    let wallIds: [String]
    let flipped: [Bool]
    let lens: [Int]

    /// The room wall id of shape wall shapeWall.
    func roomWall(_ shapeWall: Int) -> String { wallIds[shapeWall] }

    /// The room with op added: a door or window as an Opening (its near edge op.dist from the dot corner), water, sewer
    /// or gas as a SitePoint at its default height and size (Data/SitePoints.swift pointDefaults).
    func withOpening(_ op: ShapeOpening, id: String = uid()) -> ShapeRoom {
        guard op.wall >= 0, op.wall < wallIds.count else { return self }
        let wall = wallIds[op.wall], L = lens[op.wall], flip = flipped[op.wall]
        var r = room
        if op.kind.isOpening {
            let off = max(0, flip ? L - op.dist - op.w : op.dist)
            placeOpening(&r, type: op.kind.id, wall: wall, off: off, w: op.w, h: op.h, sill: op.kind == .window ? op.sill : 0, id: id)
        } else {
            let off = min(max(0, flip ? L - op.dist : op.dist), L)
            placeSitePoint(&r, kind: op.kind, wall: wall, off: off, id: id)
        }
        var out = self
        out.room = r
        return out
    }
}

/// Adds a door or window to room r on its wall `wall`, off mm from that wall's start corner (clockwise) to the near
/// edge; a door has no sill. Returns the opening.
@discardableResult
func placeOpening(_ r: inout Room, type: String, wall: String, off: Int, w: Int, h: Int, sill: Int = 0, id: String = uid()) -> Opening {
    let isDoor = type == "door"
    let o = Opening(id: id, type: isDoor ? "door" : "window", wall: wall, w: w, h: h, off: off, sill: isDoor ? 0 : sill)
    r.openings.append(o)
    return o
}

/// Adds a pipe to room r on its wall `wall`, off mm from that wall's start corner to the pipe, at the type's usual
/// height and size (pointDefaults), where the auto kitchen finds it. Returns the point.
@discardableResult
func placeSitePoint(_ r: inout Room, kind: OpKind, wall: String, off: Int, id: String = uid()) -> SitePoint {
    let t = kind.roomType
    let d = pointDefaults(t)
    let p = SitePoint(id: id, t: t, wall: wall, off: off, h: d.h, d: d.d, mh: d.mh, src: "manual")
    r.points.append(p)
    return p
}

/// The room for a finished shape: values as asked (asks), mirror and turn from spec, height mm, an optional free-sketch
/// diagonal and the added openings. Nil when the shape does not close (shapeGeometry's error). angleSnap is Poly.snap
/// for a drawn room whose walls are all at 45° steps. src: the walls' source ("manual"; the laser's when measured so).
func shapeToRoom(_ spec: ShapeSpec, _ values: [Int?], height: Int, id: String, floorId: String, name: String, created: Ms = 0,
                 diagonal: Int? = nil, openings: [ShapeOpening] = [], angleSnap: Bool = true, src: String = "manual") -> ShapeRoom? {
    let g = shapeGeometry(spec, values)
    guard g.ok else { return nil }
    let P = g.cornersShown
    let n = P.count
    guard n >= 3, n == g.walls.count else { return nil }
    // clockwise on screen; mirroring made it anticlockwise: walk the other way, still starting with wall A
    let rev = polygonArea(P) < 0
    func roomOf(_ j: Int) -> Int { rev ? (n - j) % n : j }                 // shape wall j -> room wall
    func cornerOf(_ i: Int) -> Int { rev ? ((1 - i) % n + n) % n : i }     // shape corner i -> room corner (and back)
    let V0: [Pt] = rev ? (0..<n).map { k in P[cornerOf(k)] } : P
    let mx = V0.map(\.x).min() ?? 0, my = V0.map(\.y).min() ?? 0
    let V: [Pt] = V0.map { Pt(x: shapeClean($0.x - mx), y: shapeClean($0.y - my)) }
    let lens: [Int] = (0..<n).map { k in
        let a = V[k], b = V[(k + 1) % n]
        return kround(hypot(b.x - a.x, b.y - a.y))
    }
    let shapeLens: [Int] = (0..<n).map { j in lens[roomOf(j)] }
    let flipped = [Bool](repeating: rev, count: n)

    var room = Room(id: id, floorId: floorId, name: name, created: created)
    let wallIds: [String]
    if spec.shape == .rect {
        // the rectangle's wall A sits on side rot: 0 top (→), 1 right (↓), 2 bottom (←), 3 left (↑)
        let a = V[0], b = V[1]
        let rot: Int
        if b.x - a.x > 0.5 { rot = 0 } else if b.y - a.y > 0.5 { rot = 1 } else if a.x - b.x > 0.5 { rot = 2 } else { rot = 3 }
        room.rot = rot
        room.dims = ["A": Dim(v: lens[0], src: src), "B": Dim(v: lens[1], src: src), "H": Dim(v: height, src: src), "T": Dim(v: 200, src: "default")]
        let ids = ["A", "B", "C", "D"]
        wallIds = (0..<n).map { j in ids[roomOf(j) % 4] }
    } else {
        let ids = Geo.polyWallIds(n)
        guard ids.count == n else { return nil }
        // the worked-out walls the editor's solver can still find (at most two, not parallel) stay empty: shown computed.
        // Those that are not whole mm (the cut, the bay's 45° sides) first, so every stored length is exact; then from
        // the last. A very short one is stored instead: the solver takes 20 mm or less as negative.
        let derived = stride(from: n - 1, through: 0, by: -1).filter { g.walls[$0].derived && g.walls[$0].len > 50 }
        let order = derived.filter { !shapeWhole(g.walls[$0].len) } + derived.filter { shapeWhole(g.walls[$0].len) }
        var left: [Int] = []
        for j in order {
            if left.count == 2 { break }
            let k = roomOf(j)
            if left.isEmpty || !shapeParallel(V, left[0], k) { left.append(k) }
        }
        var dims: [String: Dim] = [:]
        for k in 0..<n { dims[ids[k]] = left.contains(k) ? Dim() : Dim(v: lens[k], src: src) }
        dims["H"] = Dim(v: height, src: src)
        dims["T"] = Dim(v: 200, src: "default")
        var diags: [Diag] = []
        if let dg = diagonal {
            let a0 = cornerOf(0), b0 = cornerOf(diagonalCorner(spec) % n)
            let a = min(a0, b0), b = max(a0, b0)
            let adjacent = b - a <= 1 || (a == 0 && b == n - 1)
            if !adjacent {
                diags.append(Diag(id: "X1", a: a, b: b))
                dims["X1"] = Dim(v: dg, src: src)
            }
        }
        var snap = angleSnap
        for k in 0..<n {
            let a = V[k], b = V[(k + 1) % n]
            if !shapeOnStep(atan2(b.y - a.y, b.x - a.x)) { snap = false }
        }
        room.template = "poly"
        room.shape = "poly"
        room.dims = dims
        room.poly = Poly(verts: V, diags: diags, template: "rsh." + spec.shape.id, snap: snap)
        wallIds = (0..<n).map { j in ids[roomOf(j)] }
    }
    var out = ShapeRoom(room: room, wallIds: wallIds, flipped: flipped, lens: shapeLens)
    for op in openings { out = out.withOpening(op) }
    return out
}

/// Rounds away float dust (−0, 2599.9999999), keeping real fractions (a free sketch's spread corners).
private func shapeClean(_ x: Double) -> Double {
    let r = x.rounded()
    return abs(x - r) < 1e-6 ? r + 0.0 : x
}

private func shapeWhole(_ x: Double) -> Bool { abs(x - x.rounded()) < 1e-6 }

private func shapeOnStep(_ a: Double) -> Bool {
    let k = a / (Double.pi / 4)
    return abs(k - k.rounded()) < 1e-6
}

private func shapeParallel(_ V: [Pt], _ i: Int, _ j: Int) -> Bool {
    let n = V.count
    let ax = V[(i + 1) % n].x - V[i].x, ay = V[(i + 1) % n].y - V[i].y
    let bx = V[(j + 1) % n].x - V[j].x, by = V[(j + 1) % n].y - V[j].y
    let cross = ax * by - ay * bx
    let la = hypot(ax, ay), lb = hypot(bx, by)
    return abs(cross) <= 1e-6 * la * lb
}
