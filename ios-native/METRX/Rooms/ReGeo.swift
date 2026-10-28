import Foundation

/*
 * A room's walls as the room editor v2 draws and edits them (room-editor mockup v2, approved 28 Oct 2026): every wall
 * as a segment in plan mm (a rectangle turned by Room.rot as RectPlan shows it, a drawn room as Geo.polyGeo solves it),
 * its length and thickness, and the changes the editor makes to the room itself: a wall's length, the thickness, the
 * height, turning and mirroring, the shape, and the items (doors, windows, points) in and out of the room. Pure Swift,
 * unit-tested (RoomEditorTests).
 */

/// One wall: id, its ends in plan mm (y down, clockwise), its length, thickness, and whether it follows other walls
/// (a rectangle's C and D, a drawn room's computed walls).
struct ReWall: Equatable {
    let id: String
    let a: Pt
    let b: Pt
    let len: Int
    let t: Int
    let auto: Bool
    /// An inner wall's face (room-editor mockup v3): id is its key "<piece>:<n>", label its letter after the outer
    /// walls, look the side it faces, h its height (a half wall's).
    var label = ""
    var inner = false
    var look: Pt? = nil
    var h = 0
}

/// The room's plan: its walls in order (the outer ones, then the inner walls' faces), its corners and its height.
struct ReRoomGeo: Equatable {
    let walls: [ReWall]
    let poly: [Pt]
    let H: Int
    /// The inner walls' bodies (room-editor mockup v3): to draw them, hit them and stand furniture clear of them.
    var bodies: [ReBody] = []
    /// The outer walls (the room's shape), without the inner faces.
    var outer: [ReWall] { walls.filter { !$0.inner } }
    /// What a wall is called: its letter ("A", or "E" for an inner face).
    func label(_ id: String) -> String { wall(id).map { $0.label.isEmpty ? $0.id : $0.label } ?? id }
    /// A wall's height: an inner face its own (a half wall), else the room's.
    func hOf(_ id: String) -> Int { wall(id).map { $0.h > 0 ? $0.h : H } ?? H }
    func wall(_ id: String) -> ReWall? { walls.first { $0.id == id } }
    func index(_ id: String) -> Int? { walls.firstIndex { $0.id == id } }
    var lens: [String: Int] { Dictionary(walls.map { ($0.id, $0.len) }, uniquingKeysWith: { a, _ in a }) }
    func len(_ id: String) -> Int { wall(id)?.len ?? 0 }
    /// The walls before and after wall id (its corners' neighbours).
    func prev(_ id: String) -> String { let o = outer; guard let i = o.firstIndex(where: { $0.id == id }), !o.isEmpty else { return "—" }; return o[(i - 1 + o.count) % o.count].id }
    func next(_ id: String) -> String { let o = outer; guard let i = o.firstIndex(where: { $0.id == id }), !o.isEmpty else { return "—" }; return o[(i + 1) % o.count].id }
    /// The floor area, mm², and the perimeter, mm.
    var area: Double {
        var s = 0.0
        for i in poly.indices { let p = poly[i], q = poly[(i + 1) % poly.count]; s += p.x * q.y - q.x * p.y }
        return abs(s) / 2
    }
    var perimeter: Int { outer.reduce(0) { $0 + $1.len } }
}

/// An inner wall piece as drawn: its id and kind, its body rectangles, an arch's passage (its two ends) and its height.
struct ReBody: Equatable {
    let pid: String
    let k: String
    let R: [[Pt]]
    var gap: [Pt]? = nil
    var th = 100
    var n = Pt(x: 0, y: 1)
    var h = 0
    var oph = 0
}

/// The room's height, mm (2 700 until measured).
func reHeight(_ r: Room) -> Int { r.dim("H").v ?? 2700 }

/// The plan of room r.
func reGeo(_ r: Room, _ snap: Bool = AppSettings.shared.angleSnap) -> ReRoomGeo {
    let H = reHeight(r)
    if r.isPoly {
        let g = Geo.polyGeo(r, snap)
        let walls = g.walls.map { w -> ReWall in
            let l = w.len ?? kround(hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y))
            return ReWall(id: w.id, a: w.p0, b: w.p1, len: l, t: r.thickOf(w.id), auto: w.derived || r.dim(w.id).v == nil)
        }
        return reWithFaces(r, ReRoomGeo(walls: walls, poly: g.verts, H: H))
    }
    let a = r.dim("A"), b = r.dim("B")
    let la = a.v ?? a.pending?.mm, lb = b.v ?? b.pending?.mm
    let L = la ?? lb.map { kround(Double($0) * 1.25) } ?? 5000
    let W = lb ?? la.map { kround(Double($0) * 0.8) } ?? 4000
    let rot = ((r.rot % 4) + 4) % 4
    let SW = Double(rot % 2 == 0 ? L : W), SH = Double(rot % 2 == 0 ? W : L)
    let c = [Pt(x: 0, y: 0), Pt(x: SW, y: 0), Pt(x: SW, y: SH), Pt(x: 0, y: SH)]
    let walls = ["A", "B", "C", "D"].enumerated().map { i, id -> ReWall in
        let side = (i + rot) % 4
        return ReWall(id: id, a: c[side], b: c[(side + 1) % 4], len: i % 2 == 0 ? L : W, t: r.thickOf(id), auto: i >= 2)
    }
    return reWithFaces(r, ReRoomGeo(walls: walls, poly: c, H: H))
}

/// g with the inner walls' faces after its outer walls (room-editor mockup v3): lettered on from the outer walls, by
/// piece in the order added, each piece's front, back, then its wing's faces.
func reWithFaces(_ r: Room, _ g: ReRoomGeo) -> ReRoomGeo {
    guard !r.inner.isEmpty else { return g }
    let faces = iwFaces(r)
    let n = g.walls.count
    let letters = Geo.polyWallIds(n + faces.count)
    var walls = g.walls
    for (j, f) in faces.enumerated() {
        let L = kround(hypot(f.face.b.x - f.face.a.x, f.face.b.y - f.face.a.y))
        let lab = n + j < letters.count ? letters[n + j] : "W" + String(j + 1)
        ReLabels.set(f.key, lab)
        walls.append(ReWall(id: f.key, a: f.face.a, b: f.face.b, len: L, t: f.th, auto: false, label: lab, inner: true, look: f.face.look,
                            h: f.face.h == g.H ? 0 : f.face.h))
    }
    let bodies = r.inner.map { p -> ReBody in
        let G = iwGeo(p, g.H)
        return ReBody(pid: p.id, k: p.k, R: G.R, gap: G.gap.map { [$0.0, $0.1] }, th: p.th, n: G.n, h: G.H, oph: p.op?.h ?? 0)
    }
    return ReRoomGeo(walls: walls, poly: g.poly, H: g.H, bodies: bodies)
}

/// The letters of the inner faces last drawn, by face key (a piece id is unique, so rooms never clash): what the
/// texts call a wall, with no room at hand.
enum ReLabels {
    private static var map: [String: String] = [:]
    private static let lock = NSLock()
    static func set(_ key: String, _ v: String) { lock.lock(); map[key] = v; lock.unlock() }
    static func get(_ key: String) -> String? { lock.lock(); defer { lock.unlock() }; return map[key] }
}

/// What a wall is called in words: an outer wall its letter, an inner face the letter it was given.
func reWL(_ id: String) -> String { iwPieceOf(id) == nil ? id : (ReLabels.get(id) ?? id) }

/// Wall A's start, along and into the room (for moving the inner walls with a turn or a mirror).
func reWallAFrame(_ g: ReRoomGeo) -> (a: Pt, u: Pt, n: Pt)? {
    guard let w = g.outer.first, g.poly.count >= 3 else { return nil }
    let L = max(1e-6, hypot(w.b.x - w.a.x, w.b.y - w.a.y))
    let u = Pt(x: (w.b.x - w.a.x) / L, y: (w.b.y - w.a.y) / L)
    var n = Pt(x: -u.y, y: u.x)
    let probe = Pt(x: (w.a.x + w.b.x) / 2 + n.x * 20, y: (w.a.y + w.b.y) / 2 + n.y * 20)
    if !iwInside(probe, g.poly) { n = Pt(x: -n.x, y: -n.y) }
    return (w.a, u, n)
}

/* ---------------- the items in and out of the room ---------------- */

/// The room's doors, windows and points as items.
func reItems(_ r: Room) -> [ReItem] { r.openings.map { reItem($0) } + r.points.map { reItem($0) } }

/// The item with this id.
func reFind(_ r: Room, _ id: String) -> ReItem? {
    if let o = r.openings.first(where: { $0.id == id }) { return reItem(o) }
    if let x = r.points.first(where: { $0.id == id }) { return reItem(x) }
    return nil
}

/// Puts item it into room r (replacing the one with its id, or adding it).
func rePut(_ r: inout Room, _ it: ReItem) {
    if it.isOpening {
        if let i = r.openings.firstIndex(where: { $0.id == it.id }) { r.openings[i] = reOpening(it, r.openings[i]) }
        else { r.openings.append(reOpening(it)) }
    } else {
        if let i = r.points.firstIndex(where: { $0.id == it.id }) { r.points[i] = rePoint(it, r.points[i]) }
        else { r.points.append(rePoint(it)) }
    }
}

/// Takes item id out of room r.
func reRemove(_ r: inout Room, _ id: String) {
    r.openings.removeAll { $0.id == id }
    r.points.removeAll { $0.id == id }
}

/// Every item kept within its wall (after a wall got shorter); those on a wall that is gone are dropped.
func reClampItems(_ r: inout Room, _ snap: Bool = AppSettings.shared.angleSnap) {
    let g = reGeo(r, snap)
    r.openings = r.openings.compactMap { o in
        guard let L = g.wall(o.wall)?.len else { return nil }
        var x = o
        if x.w > L { x.w = L / 10 * 10; if x.balcony && x.dw > x.w - 300 { x.dw = max(300, x.w - 300) } }
        x.off = reClamp(x.off, 0, max(0, L - x.w))
        return x
    }
    r.points = r.points.compactMap { p in
        guard let L = g.wall(p.wall)?.len else { return nil }
        var x = p
        x.off = reClamp(x.off, 0, L)
        return x
    }
}

/* ---------------- the room's own changes ---------------- */

/// Why a wall length cannot be set: "auto" (it follows the others), "range" (300 – 999 999) or "shape" (the room would
/// not close); nil when it was set.
func reSetWallLen(_ r: inout Room, _ id: String, _ v: Int, _ snap: Bool = AppSettings.shared.angleSnap) -> String? {
    guard reWallLenOk(v) else { return "range" }
    if !r.isPoly {
        let key = id == "A" || id == "C" ? "A" : "B"
        r.dims[key] = Dim(v: v, src: "manual")
        reClampItems(&r, snap)
        return nil
    }
    let g = Geo.polyGeo(r, snap)
    if let w = g.walls.first(where: { $0.id == id }), w.derived { return "auto" }
    var t = r
    t.dims[id] = Dim(v: v, src: "manual")
    // a new room id for the solver's cache, so the check sees the new length
    var probe = t
    probe.id = t.id + "#len"
    guard Geo.polyGeo(probe, snap).solved else { return "shape" }
    r = t
    reClampItems(&r, snap)
    return nil
}

/// Wall id's own thickness.
func reSetThick(_ r: inout Room, _ id: String, _ v: Int) { r.thick[id] = v }

/// The room's height (the items above it are said by Tekshiruv, not moved).
func reSetHeight(_ r: inout Room, _ v: Int) { r.dims["H"] = Dim(v: v, src: "manual") }

/// "Burish": the plan turned 90° (dir 1 clockwise, -1 the other way). A rectangle turns Room.rot; a drawn room its corners.
func reTurn(_ r: inout Room, _ dir: Int) {
    // the inner walls turn with the room: they keep their place against wall A
    let f0 = reWallAFrame(reGeo(r))
    if !r.isPoly { r.rot = (((r.rot + (dir > 0 ? 1 : 3)) % 4) + 4) % 4 }
    else if var p = r.poly {
        let v = p.verts.map { dir > 0 ? Pt(x: -$0.y, y: $0.x) : Pt(x: $0.y, y: -$0.x) }
        let mx = v.map(\.x).min() ?? 0, my = v.map(\.y).min() ?? 0
        p.verts = v.map { Pt(x: $0.x - mx, y: $0.y - my) }
        r.poly = p
    }
    if !r.inner.isEmpty, let a = f0, let b = reWallAFrame(reGeo(r)) { iwRemap(&r, from: a, to: b) }
}

/// "Ko‘zgu": the room mirrored. The walk is reversed so it stays clockwise: new wall j is old wall (n − j) % n run the
/// other way, so its doors, windows and points are measured from the other corner (as ShapeRoom does).
func reMirror(_ r: inout Room) {
    let n = r.isPoly ? (r.poly?.verts.count ?? 0) : 4
    guard n >= 3 else { return }
    let ids = r.isPoly ? Geo.polyWallIds(n) : ["A", "B", "C", "D"]
    guard ids.count == n else { return }
    let g = reGeo(r)
    let f0 = reWallAFrame(g), endA = g.outer.first?.b
    defer {
        // the inner walls are mirrored with the room: what was wall A's end is its start now, measured the other way
        if !r.inner.isEmpty, let a = f0, let e = endA, let b = reWallAFrame(reGeo(r)) {
            iwRemap(&r, from: (e, Pt(x: -a.u.x, y: -a.u.y), a.n), to: b)
        }
    }
    func newId(_ old: String) -> String { guard let k = ids.firstIndex(of: old) else { return old }; return ids[(n - k) % n] }
    if r.isPoly, var p = r.poly {
        let q = p.verts.map { Pt(x: -$0.x, y: $0.y) }
        var v: [Pt] = []
        for j in 0..<n { v.append(q[((1 - j) % n + n) % n]) }
        let mx = v.map(\.x).min() ?? 0, my = v.map(\.y).min() ?? 0
        p.verts = v.map { Pt(x: $0.x - mx, y: $0.y - my) }
        p.diags = p.diags.map { d in
            let a = ((1 - d.a) % n + n) % n, b = ((1 - d.b) % n + n) % n
            return Diag(id: d.id, a: min(a, b), b: max(a, b))
        }
        r.poly = p
        var dims: [String: Dim] = [:]
        for (k, v) in r.dims { dims[ids.contains(k) ? newId(k) : k] = v }
        r.dims = dims
    }
    var th: [String: Int] = [:]
    for (k, v) in r.thick { th[newId(k)] = v }
    r.thick = th
    r.openings = r.openings.map { o in
        if iwPieceOf(o.wall) != nil { return o }
        var x = o
        let L = g.len(o.wall)
        x.wall = newId(o.wall); x.off = max(0, L - o.off - o.w)
        if x.balcony { x.sw = o.sw }   // the door part goes to the other end with the mirror: drawn from its new start
        return x
    }
    r.points = r.points.map { p in
        if iwPieceOf(p.wall) != nil { return p }
        var x = p
        let L = g.len(p.wall)
        x.wall = newId(p.wall); x.off = max(0, L - p.off)
        return x
    }
    r.features = r.features.map { f in
        var x = f
        let L = g.len(f.wall)
        x.wall = newId(f.wall); x.off = max(0, L - f.off - f.w)
        return x
    }
}

/// "Shakl": the room made shape k at its standard sizes (keeping its id, name, height and the items on walls that are
/// still there). Returns how many items were dropped, nil when the shape cannot be made (the free sketch).
func reChangeShape(_ r: inout Room, _ k: RoomShape) -> Int? {
    guard k != .free else { return nil }
    let spec = ShapeSpec(k)
    guard let made = shapeToRoom(spec, k.defaults.map { Optional($0) }, height: reHeight(r), id: r.id, floorId: r.floorId, name: r.name,
                                 created: r.created, angleSnap: AppSettings.shared.angleSnap) else { return nil }
    var x = made.room
    x.openings = r.openings; x.points = r.points; x.features = r.features
    x.wallColor = r.wallColor; x.floorColor = r.floorColor; x.views = r.views; x.template = made.room.template
    // the inner walls stay where they still stand inside the new shape
    let poly = reGeo(x).poly
    x.inner = r.inner.filter { iwInside(Pt(x: Double($0.x), y: Double($0.y)), poly) }
    if let t = r.dims["T"] { x.dims["T"] = t }
    let before = r.openings.count + r.points.count
    reClampItems(&x)
    r = x
    return before - (r.openings.count + r.points.count)
}

/// The room's shape card ("rect", "L", … from a drawn room's template "rsh.L"; "free" for a sketch).
func reShapeOf(_ r: Room) -> String {
    if !r.isPoly { return "rect" }
    let t = r.poly?.template ?? ""
    return t.hasPrefix("rsh.") ? String(t.dropFirst(4)) : "free"
}

/// The angle at wall id's start corner, degrees (inside the room), from the plan.
func reCornerAngle(_ g: ReRoomGeo, _ id: String) -> Int {
    let o = g.outer
    guard let i = o.firstIndex(where: { $0.id == id }), o.count >= 3 else { return 90 }
    let n = o.count
    let a = o[(i - 1 + n) % n], b = o[i]
    let u = (a.b.x - a.a.x, a.b.y - a.a.y), v = (b.b.x - b.a.x, b.b.y - b.a.y)
    let cr = u.0 * v.1 - u.1 * v.0, dt = u.0 * v.0 + u.1 * v.1
    let turn = atan2(cr, dt) * 180 / Double.pi
    return Int((180 - turn).rounded())
}
