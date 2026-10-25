import Foundation

/*
 * The 3D shell of rooms, in metres (prototype build3D, opModel3D, the sketch module's polygon walls and the ux module's
 * rows of rooms), ported from the Android app's geo/Shell3D.kt. Pure geometry: the faces, the wall edges, the labels and
 * where the camera may go. Three/Scene3D.swift draws it. x runs along wall A, z away from it (the plan's y), y up.
 */

struct V3: Equatable {
    var x: Double, y: Double, z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    static func + (a: V3, b: V3) -> V3 { V3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: V3, b: V3) -> V3 { V3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (a: V3, k: Double) -> V3 { V3(a.x * k, a.y * k, a.z * k) }
    func dot(_ o: V3) -> Double { x * o.x + y * o.y + z * o.z }
    var len: Double { (x * x + y * y + z * z).squareRoot() }
    var unit: V3 { let l = len; return l == 0 ? self : self * (1 / l) }
    func cross(_ b: V3) -> V3 { V3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
}

/// What a piece is, which decides what happens to it when its wall faces the camera and is cut away.
enum Role3 { case wall, opening, glass, floor, furn }

/// A wall's own frame in the scene, metres: its start corner on the inside face (ox, oz), the direction along it (ux, uz)
/// and the one into the room (nx, nz), its length. Furniture is placed in it.
struct WallBasis: Equatable {
    let ox: Double, oz: Double, ux: Double, uz: Double, nx: Double, nz: Double, len: Double
    /// The scene point a along the wall, y up and n into the room, all in metres.
    func at(_ a: Double, _ y: Double, _ n: Double) -> V3 { V3(ox + ux * a + nx * n, y, oz + uz * a + nz * n) }
    /// A direction da along and dn into the room.
    func dir(_ da: Double, _ dn: Double) -> V3 { V3(ux * da + nx * dn, 0, uz * da + nz * dn) }
}

/// A flat face: a convex polygon (tris nil, drawn as a fan) or a triangulated polygon (the floor of a drawn room).
/// grain: the direction its picture's grain runs (a board's long side, Geo/Look.swift boxGrains); nil the world's.
struct Face3 { let n: V3; let pts: [V3]; var tris: [Int]? = nil; var grain: V3? = nil }

/// Faces with one colour and opacity, belonging to one wall of one room (group); floors and loose glass have no wall.
/// tile: a tiler's tiles (Tiles/Mesh.swift).
final class Part3 {
    let group: Int, wall: String?, role: Role3, rgb: Int, op: Double
    let tile: Bool
    /// A worktop: its top is lit like a stone surface and its outline drawn light, so a dark one shows its thickness.
    let slab: Bool
    /// How it looks in the lit 3D (Geo/Look.swift); nil: worked out from its role and colour (roleLook).
    let look: Look?
    var faces: [Face3] = []
    init(_ group: Int, _ wall: String?, _ role: Role3, _ rgb: Int, _ op: Double, tile: Bool = false, slab: Bool = false, look: Look? = nil) {
        self.group = group; self.wall = wall; self.role = role; self.rgb = rgb; self.op = op; self.tile = tile; self.slab = slab; self.look = look
    }
}

/// A wall's outline as line segments (pairs of points), like the prototype's EdgesGeometry lines.
final class Edges3 {
    let group: Int, wall: String
    let rgb: Int
    var segs: [V3] = []
    init(_ group: Int, _ wall: String, rgb: Int = WALL_INK) { self.group = group; self.wall = wall; self.rgb = rgb }
}

/// A room in the scene: its middle and the outward direction of each wall, for the cut-away.
struct Group3 { let cx: Double; let cz: Double; let normals: [String: (Double, Double)] }

/// A label over the scene: a wall letter (single room) or a room name.
struct Label3 { let text: String; let p: V3 }

/// A room's place when several rooms are shown: its name is a button that zooms to it.
struct Room3 { let id: String; let name: String; let cx: Double; let cz: Double; let w: Double; let d: Double; let h: Double }

struct Bounds3 { let x0: Double; let x1: Double; let z0: Double; let z1: Double }

struct Shell3D {
    let parts: [Part3]
    let edges: [Edges3]
    let groups: [Group3]
    let labels: [Label3]
    let rooms3: [Room3]?
    /// Overall size (prototype T3.dims L, W, H).
    let L: Double, W: Double, H: Double
    let tgt: V3, r: Double
    /// Set for several rooms (the view turns to its standard angle); nil keeps the current angle.
    let theta: Double?, phi: Double?
    let bounds: Bounds3, rMin: Double
    /// Width, depth, height, factor for the start distance, factor for the furthest distance (prototype T3.fit).
    let fit: [Double]
    let gridSize: Double, gridDiv: Int, gridCx: Double, gridCz: Double
    /// Towards the directional light.
    let light: V3
    let far: Double
    /// One room only: each wall's frame, for the furniture of a furniture order.
    var bases: [String: WallBasis] = [:]

    /// The same scene with more parts and outlines (the furniture).
    func plus(_ more: [Part3], _ moreEdges: [Edges3]) -> Shell3D {
        var s = Shell3D(parts: parts + more, edges: edges + moreEdges, groups: groups, labels: labels, rooms3: rooms3, L: L, W: W, H: H, tgt: tgt, r: r,
                        theta: theta, phi: phi, bounds: bounds, rMin: rMin, fit: fit, gridSize: gridSize, gridDiv: gridDiv, gridCx: gridCx, gridCz: gridCz,
                        light: light, far: far)
        s.bases = bases
        return s
    }

    /// Only the floor: furniture without a room, drawn without walls (the walls' frames stay for placing it). With no
    /// walls, nothing faces the camera, so no furniture goes see-through.
    /// th: the camera's start angle round it (nil: the usual one).
    func floorOnly(_ th: Double? = nil) -> Shell3D {
        var s = Shell3D(parts: parts.filter { $0.role == .floor }, edges: [], groups: groups.map { Group3(cx: $0.cx, cz: $0.cz, normals: [:]) }, labels: [],
                        rooms3: rooms3, L: L, W: W, H: H, tgt: tgt, r: r, theta: th ?? theta, phi: phi, bounds: bounds, rMin: rMin, fit: fit,
                        gridSize: gridSize, gridDiv: gridDiv, gridCx: gridCx, gridCz: gridCz, light: light, far: far)
        s.bases = bases
        return s
    }
}

let FOV_HALF = Double.pi / 9      // half of the 40° camera
let WALL_INK = 0x0E1C36

/// A worktop's outline: light, so the edges of a dark worktop stand out against it.
let SLAB_LINE = 0xC4CCD8

/// A worktop's top face: its colour a little lighter, as a lit stone surface, against its darker front edge.
func slabTop(_ rgb: Int) -> Int {
    var out = 0
    for k in 0..<3 {
        let c = (rgb >> (16 - 8 * k)) & 255
        let v = Int((Double(c) + Double(255 - c) * 0.2).rounded())
        out = (out << 8) | min(max(v, 0), 255)
    }
    return out
}
private let FIN = 0xC5CBD4
private let GLASS = 0x9DB8E8
private let HANDLE = 0x6F7782
private let SILL = 0xF5F5F2

/// How far the camera stands to show a w × d × h block (prototype v3Fit); aspect is width / height of the picture.
func v3Fit(_ w: Double, _ d: Double, _ h: Double, _ aspect: Double) -> Double {
    let hh = atan(tan(FOV_HALF) * aspect)
    return max(3.5, 0.5 * (w * w + d * d + h * h).squareRoot() / sin(min(FOV_HALF, hh)) * 0.9)
}

/* ---------------- building one or several rooms side by side (prototype build3D and its sketch override) ---------------- */

private final class Builder3 {
    var parts: [Part3] = [], edges: [Edges3] = [], groups: [Group3] = [], labels: [Label3] = []
    var bases: [String: WallBasis] = [:]
    func part(_ group: Int, _ wall: String?, _ role: Role3, _ rgb: Int, _ op: Double = 1) -> Part3 { let p = Part3(group, wall, role, rgb, op); parts.append(p); return p }
    func edgesOf(_ group: Int, _ wall: String) -> Edges3 {
        if let e = edges.first(where: { $0.group == group && $0.wall == wall }) { return e }
        let e = Edges3(group, wall); edges.append(e); return e
    }
}

private func boxFaces(_ p: Part3, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) {
    p.faces.append(Face3(n: V3(1, 0, 0), pts: [V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1), V3(x1, y0, z1)]))
    p.faces.append(Face3(n: V3(-1, 0, 0), pts: [V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0)]))
    p.faces.append(Face3(n: V3(0, 1, 0), pts: [V3(x0, y1, z0), V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0)]))
    p.faces.append(Face3(n: V3(0, -1, 0), pts: [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)]))
    p.faces.append(Face3(n: V3(0, 0, 1), pts: [V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1)]))
    p.faces.append(Face3(n: V3(0, 0, -1), pts: [V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0), V3(x1, y0, z0)]))
}

private func boxEdges(_ e: Edges3, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) {
    let c = [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1), V3(x0, y1, z0), V3(x1, y1, z0), V3(x1, y1, z1), V3(x0, y1, z1)]
    for (a, b) in [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)] { e.segs.append(c[a]); e.segs.append(c[b]) }
}

/// Pieces of wall around the openings: [from, to, bottom, top] along a wall (prototype pieces()). An opening is
/// [from, to, sill, height, door 1/0].
func wallPieces(_ a0: Double, _ a1: Double, _ ops: [[Double]], _ H: Double) -> [[Double]] {
    var out: [[Double]] = []
    var cur = a0
    for o in ops.sorted(by: { $0[0] < $1[0] }) {
        if o[0] > cur { out.append([cur, o[0], 0, H]) }
        if o[2] > 0 { out.append([o[0], o[1], 0, o[2]]) }
        if o[2] + o[3] < H { out.append([o[0], o[1], o[2] + o[3], H]) }
        cur = max(cur, o[1])
    }
    if cur < a1 { out.append([cur, a1, 0, H]) }
    return out
}

/// A rectangular room at x offset ox (prototype build3D, one room). Returns its extent: along x, along z, height.
private func rectRoom(_ b: Builder3, _ room: Room, _ gi: Int, _ ox: Double, _ single: Bool, _ name: String, _ bare: Set<String> = []) -> [Double] {
    let L = Double(room.dim("A").v!) / 1000, W = Double(room.dim("B").v!) / 1000, H = Double(room.dim("H").v!) / 1000
    let T = Double(room.dim("T").v ?? 200) / 1000
    let X = { (x: Double) in x + ox + T }
    let wallRgb = rgbOf(room.wallColor)
    func box(_ w: String, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double, _ p: Part3) {
        if x1 - x0 < 1e-4 || y1 - y0 < 1e-4 || z1 - z0 < 1e-4 { return }
        boxFaces(p, X(x0), X(x1), y0, y1, z0, z1)
        if p.role == .wall { boxEdges(b.edgesOf(gi, w), X(x0), X(x1), y0, y1, z0, z1) }
    }
    func opsOn(_ w: String) -> [[Double]] {
        room.openings.filter { $0.wall == w }.map { o in
            let off = Double(o.off) / 1000, wd = Double(o.w) / 1000
            let ab: (Double, Double) = w == "A" || w == "B" ? (off, off + wd) : w == "C" ? (L - off - wd, L - off) : (W - off - wd, W - off)
            let door: Double = o.type == "door" ? 1 : 0
            let filled: Double = bare.contains(o.id) ? 1 : 0
            return [ab.0, ab.1, Double(o.sill) / 1000, Double(o.h) / 1000, door, filled]
        }
    }
    // niches: cut out of the wall like an opening [a, b, sill, height, 2] and closed at their depth
    func nichesOn(_ w: String) -> [[Double]] {
        room.features.filter { $0.wall == w && $0.type == "niche" }.map { f in
            let off = Double(f.off) / 1000, wd = Double(f.w) / 1000
            let ab: (Double, Double) = w == "A" || w == "B" ? (off, off + wd) : w == "C" ? (L - off - wd, L - off) : (W - off - wd, W - off)
            let sill = Double(f.sill) / 1000, nh = min(f.h > 0 ? Double(f.h) / 1000 : H - sill, H - sill)
            return [ab.0, ab.1, sill, nh, 2, min(Double(f.d) / 1000, T - 0.01)]
        }
    }
    for w in ["A", "C", "B", "D"] {
        let p = b.part(gi, w, .wall, wallRgb)
        let niches = nichesOn(w)
        let ops = opsOn(w) + niches
        switch w {
        case "A": for pc in wallPieces(-T, L + T, ops, H) { box(w, pc[0], pc[1], pc[2], pc[3], -T, 0, p) }
        case "C": for pc in wallPieces(-T, L + T, ops, H) { box(w, pc[0], pc[1], pc[2], pc[3], W, W + T, p) }
        case "B": for pc in wallPieces(0, W, ops, H) { box(w, L, L + T, pc[2], pc[3], pc[0], pc[1], p) }
        default: for pc in wallPieces(0, W, ops, H) { box(w, -T, 0, pc[2], pc[3], pc[0], pc[1], p) }
        }
        // an opening a windows-and-doors maker filled has the product drawn in it instead (bare)
        for o in ops where o[4] != 2 && !(o.count > 5 && o[5] == 1) { openingModel(b, gi, w, o, T, L, W, X) }
        // the niche's back, its depth into the wall
        for n in niches {
            let dd = n[5]
            switch w {
            case "A": box(w, n[0], n[1], n[2], n[2] + n[3], -T, -dd, p)
            case "C": box(w, n[0], n[1], n[2], n[2] + n[3], W + dd, W + T, p)
            case "B": box(w, L + dd, L + T, n[2], n[2] + n[3], n[0], n[1], p)
            default: box(w, -T, -dd, n[2], n[2] + n[3], n[0], n[1], p)
            }
        }
        // columns: full-height boxes against the wall's inside face
        for f in room.features where f.wall == w && f.type == "column" {
            let off = Double(f.off) / 1000, wd = Double(f.w) / 1000, dd = Double(f.d) / 1000
            switch w {
            case "A": box(w, off, off + wd, 0, H, 0, dd, p)
            case "C": box(w, L - off - wd, L - off, 0, H, W - dd, W, p)
            case "B": box(w, L - dd, L, 0, H, off, off + wd, p)
            default: box(w, 0, dd, 0, H, W - off - wd, W - off, p)
            }
        }
    }
    for x in room.points { pointModel(b, gi, x, L, W, X) }
    if gi == 0 {
        b.bases["A"] = WallBasis(ox: X(0), oz: 0, ux: 1, uz: 0, nx: 0, nz: 1, len: L); b.bases["B"] = WallBasis(ox: X(L), oz: 0, ux: 0, uz: 1, nx: -1, nz: 0, len: W)
        b.bases["C"] = WallBasis(ox: X(L), oz: W, ux: -1, uz: 0, nx: 0, nz: -1, len: L); b.bases["D"] = WallBasis(ox: X(0), oz: W, ux: 0, uz: -1, nx: 1, nz: 0, len: W)
    }
    let fl = b.part(gi, nil, .floor, rgbOf(room.floorColor))
    fl.faces.append(Face3(n: V3(0, 1, 0), pts: [V3(X(0), 0.001, 0), V3(X(0), 0.001, W), V3(X(L), 0.001, W), V3(X(L), 0.001, 0)]))
    b.groups.append(Group3(cx: X(L / 2), cz: W / 2, normals: ["A": (0, -1), "B": (1, 0), "C": (0, 1), "D": (-1, 0)]))
    if single {
        b.labels.append(Label3(text: "A", p: V3(X(L / 2), H + 0.25, -T / 2))); b.labels.append(Label3(text: "B", p: V3(X(L + T / 2), H + 0.25, W / 2)))
        b.labels.append(Label3(text: "C", p: V3(X(L / 2), H + 0.25, W + T / 2))); b.labels.append(Label3(text: "D", p: V3(X(-T / 2), H + 0.25, W / 2)))
    } else { b.labels.append(Label3(text: name, p: V3(X(L / 2), H + 0.45, W / 2))) }
    return [L + 2 * T, W, H]
}

/* Furniture orders' site points: small boxes on the wall's inside face, in the colours of the plan (furniture plan section 5). */
private let PT_RGB: [String: Int] = ["socket": 0xF1F5F9, "switch": 0xE2E8F0, "cold": 0x2563EB, "hot": 0xDC2626, "sewer": 0x64748B, "gas": 0xEAB308, "meter": 0xCA8A04]
private func ptDepth(_ t: String) -> Double { t == "socket" || t == "switch" ? 0.012 : t == "meter" ? 0.12 : 0.05 }

/// A site point in a rectangular room: centred off along its wall and h up, standing out of the wall's inside face.
private func pointModel(_ b: Builder3, _ gi: Int, _ x: SitePoint, _ L: Double, _ W: Double, _ X: (Double) -> Double) {
    let sz = pointSize(x); let sw = Double(sz.w) / 2000, sh = Double(sz.h) / 2000
    let dep = ptDepth(x.t), c = Double(x.off) / 1000, y = Double(x.h) / 1000
    let m = b.part(gi, x.wall, .opening, PT_RGB[x.t] ?? 0x64748B)
    switch x.wall {
    case "A": boxFaces(m, X(c - sw), X(c + sw), y - sh, y + sh, 0, dep)
    case "B": boxFaces(m, X(L - dep), X(L), y - sh, y + sh, c - sw, c + sw)
    case "C": boxFaces(m, X(L - c - sw), X(L - c + sw), y - sh, y + sh, W - dep, W)
    case "D": boxFaces(m, X(0), X(dep), y - sh, y + sh, W - c - sw, W - c + sw)
    default: break
    }
}

/// A door or window in a rectangular room's wall (prototype opModel3D, the one standard style and finish).
private func openingModel(_ b: Builder3, _ gi: Int, _ w: String, _ ar: [Double], _ T: Double, _ L: Double, _ W: Double, _ X: (Double) -> Double) {
    let a = ar[0], bb = ar[1], v0 = ar[2], hh = ar[3], door = ar[4] == 1
    func M(_ rgb: Int, _ op: Double = 1) -> Part3 { b.part(gi, w, .opening, rgb, op) }
    let mF = M(FIN), mG = M(GLASS, 0.45), mH = M(HANDLE), mLeaf = M(FIN)
    func box(_ u0: Double, _ u1: Double, _ y0: Double, _ y1: Double, _ n0: Double, _ n1: Double, _ m: Part3) {
        if u1 - u0 < 1e-4 || y1 - y0 < 1e-4 || n1 - n0 < 1e-4 { return }
        if w == "A" || w == "C" {
            let zc = w == "A" ? -(n0 + n1) / 2 : W + (n0 + n1) / 2, hz = (n1 - n0) / 2
            boxFaces(m, X(u0), X(u1), y0, y1, zc - hz, zc + hz)
        } else {
            let xc = w == "B" ? L + (n0 + n1) / 2 : -(n0 + n1) / 2, hx = (n1 - n0) / 2
            boxFaces(m, X(xc - hx), X(xc + hx), y0, y1, u0, u1)
        }
    }
    let top = v0 + hh, fw = 0.055
    if door {
        let f0 = 0.01, f1 = min(T - 0.01, 0.12)
        box(a, a + fw, 0, top, f0, f1, mF); box(bb - fw, bb, 0, top, f0, f1, mF); box(a, bb, top - fw, top, f0, f1, mF)
        let l0 = 0.03, l1 = 0.07, la = a + fw, lb = bb - fw, lt = top - fw
        box(la, lb, 0, lt, l0, l1, mLeaf)
        let hu = lb - 0.09
        box(hu, hu + 0.03, 0.98, 1.02, -0.03, l0, mH)
    } else {
        let f0 = max(0.01, T * 0.3), f1 = min(T - 0.01, f0 + 0.07)
        box(a, a + fw, v0, top, f0, f1, mF); box(bb - fw, bb, v0, top, f0, f1, mF); box(a, bb, top - fw, top, f0, f1, mF); box(a, bb, v0, v0 + fw, f0, f1, mF)
        let n = 2, ia = a + fw, ib = bb - fw, iy0 = v0 + fw, iy1 = top - fw, sw = (ib - ia) / Double(n), sb = 0.045, gm = (f0 + f1) / 2
        for k in 0..<n {
            let s0 = ia + Double(k) * sw, s1 = s0 + sw
            box(s0, s0 + sb, iy0, iy1, f0 + 0.01, f1 - 0.01, mF); box(s1 - sb, s1, iy0, iy1, f0 + 0.01, f1 - 0.01, mF)
            box(s0, s1, iy0, iy0 + sb, f0 + 0.01, f1 - 0.01, mF); box(s0, s1, iy1 - sb, iy1, f0 + 0.01, f1 - 0.01, mF)
            box(s0 + sb, s1 - sb, iy0 + sb, iy1 - sb, gm - 0.004, gm + 0.004, mG)
            if k == 0 { box(s1 - sb - 0.03, s1 - sb - 0.01, iy0 + (iy1 - iy0) * 0.48, iy0 + (iy1 - iy0) * 0.58, f0 - 0.02, f0 + 0.01, mH) }
        }
        if v0 > 0.05 { box(a - 0.05, bb + 0.05, v0 - 0.03, v0, -0.1, f0, M(SILL)) }
    }
}

typealias P2 = (Double, Double)

private func area2(_ q: [P2]) -> Double {
    var s = 0.0
    for i in q.indices { let a = q[i], c = q[(i + 1) % q.count]; s += a.0 * c.1 - c.0 * a.1 }
    return s / 2
}

/// A prism over the plan polygon q (x, z pairs) between heights y0 and y1: caps and sides, each side facing outward.
private func prism(_ p: Part3, _ e: Edges3?, _ q: [P2], _ y0: Double, _ y1: Double) {
    if y1 - y0 < 1e-4 || abs(area2(q)) < 1e-7 { return }
    let cx = q.map(\.0).reduce(0, +) / Double(q.count), cz = q.map(\.1).reduce(0, +) / Double(q.count)
    p.faces.append(Face3(n: V3(0, 1, 0), pts: q.map { V3($0.0, y1, $0.1) }))
    p.faces.append(Face3(n: V3(0, -1, 0), pts: q.map { V3($0.0, y0, $0.1) }))
    for i in q.indices {
        let a = q[i], c = q[(i + 1) % q.count]
        let dx = c.0 - a.0, dz = c.1 - a.1, l = hypot(dx, dz)
        if l < 1e-9 { continue }
        var nx = dz / l, nz = -dx / l
        if ((a.0 + c.0) / 2 - cx) * nx + ((a.1 + c.1) / 2 - cz) * nz < 0 { nx = -nx; nz = -nz }
        p.faces.append(Face3(n: V3(nx, 0, nz), pts: [V3(a.0, y0, a.1), V3(c.0, y0, c.1), V3(c.0, y1, c.1), V3(a.0, y1, a.1)]))
        if let e {
            e.segs.append(V3(a.0, y0, a.1)); e.segs.append(V3(c.0, y0, c.1))
            e.segs.append(V3(a.0, y1, a.1)); e.segs.append(V3(c.0, y1, c.1))
            e.segs.append(V3(a.0, y0, a.1)); e.segs.append(V3(a.0, y1, a.1))
        }
    }
}

/// Outer corners: each wall pushed out by w along its normal, joined at a mitre (prototype skMiter).
func miter(_ ip: [P2], _ no: [P2], _ w: Double) -> [P2] {
    let n = ip.count
    return ip.enumerated().map { i, p in
        let a = no[(i - 1 + n) % n], b = no[i], d = 1 + a.0 * b.0 + a.1 * b.1
        return d < 0.15 ? (p.0 + b.0 * w, p.1 + b.1 * w) : (p.0 + (a.0 + b.0) * w / d, p.1 + (a.1 + b.1) * w / d)
    }
}

private func centroid(_ v: [P2]) -> P2 {
    var a = 0.0, cx = 0.0, cy = 0.0
    for i in v.indices { let p = v[i], q = v[(i + 1) % v.count]; let c = p.0 * q.1 - q.0 * p.1; a += c; cx += (p.0 + q.0) * c; cy += (p.1 + q.1) * c }
    if abs(a) < 1e-12 { return (v.map(\.0).reduce(0, +) / Double(v.count), v.map(\.1).reduce(0, +) / Double(v.count)) }
    return (cx / (3 * a), cy / (3 * a))
}

/// Triangles of a simple polygon by ear clipping (the floor of a drawn room may be L-shaped).
func earClip(_ v: [P2]) -> [Int] {
    let n = v.count
    if n < 3 { return [] }
    let ccw = area2(v) > 0
    var idx = Array(0..<n)
    var out: [Int] = []
    func cross(_ a: P2, _ b: P2, _ c: P2) -> Double { (b.0 - a.0) * (c.1 - a.1) - (b.1 - a.1) * (c.0 - a.0) }
    func inside(_ p: P2, _ a: P2, _ b: P2, _ c: P2) -> Bool {
        let d1 = cross(a, b, p), d2 = cross(b, c, p), d3 = cross(c, a, p)
        return ccw ? d1 >= -1e-12 && d2 >= -1e-12 && d3 >= -1e-12 : d1 <= 1e-12 && d2 <= 1e-12 && d3 <= 1e-12
    }
    var guardN = 0
    while idx.count > 3 && guardN < 10 * n {
        guardN += 1
        var cut = false
        for k in idx.indices {
            let i0 = idx[(k - 1 + idx.count) % idx.count], i1 = idx[k], i2 = idx[(k + 1) % idx.count]
            let c = cross(v[i0], v[i1], v[i2])
            if ccw ? c <= 1e-12 : c >= -1e-12 { continue }
            if idx.contains(where: { $0 != i0 && $0 != i1 && $0 != i2 && inside(v[$0], v[i0], v[i1], v[i2]) }) { continue }
            out += [i0, i1, i2]; idx.remove(at: k); cut = true; break
        }
        if !cut { break }
    }
    if idx.count == 3 { out += idx }
    return out
}

/// A drawn room (prototype sketch build3D): each wall extruded along the solved polygon, windows as glass, the floor as the polygon.
private func polyRoom(_ b: Builder3, _ room: Room, _ gi: Int, _ ox: Double, _ single: Bool, _ name: String, _ snap: Bool, _ bare: Set<String> = []) -> [Double] {
    let H = Double(room.dim("H").v!) / 1000, T = Double(room.dim("T").v ?? 200) / 1000
    let ws = Geo.walls(room, snap), n = ws.count
    let ip: [P2] = ws.map { ($0.p0.x / 1000, $0.p0.y / 1000) }
    let uu: [(Double, Double, Double)] = ip.enumerated().map { i, p in
        let q = ip[(i + 1) % n]; let l0 = hypot(q.0 - p.0, q.1 - p.1); let l = l0 > 0 ? l0 : 1
        return ((q.0 - p.0) / l, (q.1 - p.1) / l, l)
    }
    let no: [P2] = uu.map { ($0.1, -$0.0) }
    let op = miter(ip, no, T)
    let minX = op.map(\.0).min()!, maxX = op.map(\.0).max()!, minZ = op.map(\.1).min()!, maxZ = op.map(\.1).max()!
    let X = { (x: Double) in x - minX + ox }
    let Z = { (z: Double) in z - minZ }
    let pt = { (p: P2) -> P2 in (X(p.0), Z(p.1)) }
    let wallRgb = rgbOf(room.wallColor)
    var normals: [String: (Double, Double)] = [:]
    for (i, w) in ws.enumerated() {
        let a = ip[i], c = ip[(i + 1) % n], u = uu[i], len = u.2, q = no[i]
        let at = { (d: Double) -> P2 in (a.0 + u.0 * d, a.1 + u.1 * d) }
        let off = { (p: P2, k: Double) -> P2 in (p.0 + q.0 * k, p.1 + q.1 * k) }
        let ops: [[Double]] = room.openings.filter { $0.wall == w.id }.map { o -> [Double] in
            let door: Double = o.type == "door" ? 1 : 0
            let filled: Double = bare.contains(o.id) ? 1 : 0
            return [Double(o.off) / 1000, Double(o.off + o.w) / 1000, Double(o.sill) / 1000, Double(o.h) / 1000, door, filled]
        }
        let p = b.part(gi, w.id, .wall, wallRgb), e = b.edgesOf(gi, w.id)
        for pc in wallPieces(0, len, ops, H) {
            let s0 = max(0, pc[0]), s1 = min(len, pc[1])
            if s1 - s0 < 1e-4 { continue }
            let i0 = s0 < 1e-6 ? a : at(s0), o0 = s0 < 1e-6 ? op[i] : off(at(s0), T)
            let i1 = s1 > len - 1e-6 ? c : at(s1), o1 = s1 > len - 1e-6 ? op[(i + 1) % n] : off(at(s1), T)
            prism(p, e, [pt(i0), pt(i1), pt(o1), pt(o0)], pc[2], pc[3])
        }
        for o in ops where o[4] == 0 && o[5] != 1 {
            let g = b.part(gi, nil, .glass, GLASS, 0.5)
            prism(g, nil, [pt(off(at(o[0]), T / 2 - 0.01)), pt(off(at(o[1]), T / 2 - 0.01)), pt(off(at(o[1]), T / 2 + 0.01)), pt(off(at(o[0]), T / 2 + 0.01))], o[2], o[2] + o[3])
        }
        // site points of a furniture order, standing out of this wall's inside face
        for x in room.points where x.wall == w.id {
            let sz = pointSize(x); let s2 = Double(sz.w) / 2000, sh = Double(sz.h) / 2000
            let dep = ptDepth(x.t), c0 = Double(x.off) / 1000, y = Double(x.h) / 1000
            let m = b.part(gi, w.id, .opening, PT_RGB[x.t] ?? 0x64748B)
            prism(m, nil, [pt(off(at(c0 - s2), -dep)), pt(off(at(c0 + s2), -dep)), pt(at(c0 + s2)), pt(at(c0 - s2))], y - sh, y + sh)
        }
        normals[w.id] = q
        if gi == 0 { let o = pt(a); b.bases[w.id] = WallBasis(ox: o.0, oz: o.1, ux: u.0, uz: u.1, nx: -q.0, nz: -q.1, len: len) }
        if single { let md = at(len / 2); b.labels.append(Label3(text: w.id, p: V3(X(md.0 + q.0 * T / 2), H + 0.25, Z(md.1 + q.1 * T / 2)))) }
    }
    let fl = b.part(gi, nil, .floor, rgbOf(room.floorColor))
    let fp = ip.map(pt)
    fl.faces.append(Face3(n: V3(0, 1, 0), pts: fp.map { V3($0.0, 0.001, $0.1) }, tris: earClip(fp)))
    let cc = centroid(ip)
    b.groups.append(Group3(cx: X(cc.0), cz: Z(cc.1), normals: normals))
    if !single { b.labels.append(Label3(text: name, p: V3(X(cc.0), H + 0.45, Z(cc.1)))) }
    return [maxX - minX, maxZ - minZ, H]
}

/// Rooms in one line (prototype build3D), as the prototype's sketch override does: any drawn room sends all rooms the polygon way.
private func base(_ rooms: [Room], _ single: Bool, _ snap: Bool, _ name: (Room) -> String, _ bare: Set<String> = []) -> (Builder3, [Double]) {
    let b = Builder3()
    var ox = 0.0, maxW = 0.0, maxH = 0.0
    let gap = 1.2
    let poly = rooms.contains { $0.isPoly }
    for (gi, room) in rooms.enumerated() {
        let ext = poly ? polyRoom(b, room, gi, ox, single, name(room), snap, bare) : rectRoom(b, room, gi, ox, single, name(room), bare)
        ox += ext[0] + gap; maxW = max(maxW, ext[1]); maxH = max(maxH, ext[2])
    }
    return (b, [max(ox - gap, 1), maxW, maxH])
}

private func lightTowards(_ span: Double, _ maxW: Double, _ maxH: Double) -> V3 { V3(span * 0.7 + 3, maxH * 3 + 4, maxW * 1.6 + 3).unit }

/// The scene for one room (single, with wall letters) or for the rooms of a workspace (names that zoom to a room), with
/// the ux module's limits: the view's middle stays over the rooms and the zoom inside a range. Openings in bare (filled by
/// a windows-and-doors maker's products, drawn by its own app) get no standard window or door.
func buildShell(_ rooms: [Room], single: Bool, snap: Bool = true, bare: Set<String> = [], name: (Room) -> String = { $0.name }) -> Shell3D {
    if single || rooms.count < 2 {
        let (b, d) = base(rooms, single, snap, name, bare)
        let span = d[0], maxW = d[1], maxH = d[2], gs = max(span, maxW) + 4
        return Shell3D(
            parts: b.parts, edges: b.edges, groups: b.groups, labels: b.labels, rooms3: nil, L: span, W: maxW, H: maxH,
            tgt: V3(span / 2, maxH * 0.3, maxW / 2), r: max(span, maxW) * (single ? 2.2 : 1.7) + 2.5,
            theta: single ? nil : .pi / 2 + 0.45, phi: single ? nil : 0.9,
            bounds: Bounds3(x0: span * 0.15, x1: span * 0.85, z0: maxW * 0.15, z1: maxW * 0.85), rMin: 2.5, fit: [span, maxW, maxH, 1.25, 1.6],
            gridSize: gs, gridDiv: kround(gs * 2), gridCx: span / 2, gridCz: maxW / 2, light: lightTowards(span, maxW, maxH), far: 300,
            bases: single ? b.bases : [:])
    }
    // several rooms stand in rows, like on a sheet of paper (ux module)
    let gap = 1.4
    struct P { let room: Room; let b: Builder3; let x0: Double; let z0: Double; let w: Double; let d: Double; let h: Double }
    let ps: [P] = rooms.map { room in
        let (b, _) = base([room], false, snap, name)
        let pts = b.parts.flatMap { $0.faces.flatMap(\.pts) }
        let x0 = pts.map(\.x).min() ?? 0, z0 = pts.map(\.z).min() ?? 0
        return P(room: room, b: b, x0: x0, z0: z0, w: (pts.map(\.x).max() ?? 0) - x0, d: (pts.map(\.z).max() ?? 0) - z0, h: pts.map(\.y).max() ?? 0)
    }
    let area = ps.reduce(0) { $0 + ($1.w + gap) * ($1.d + gap) }
    let rowW = max(ps.map(\.w).max()!, area.squareRoot() * 1.2)
    var rows: [(w: Double, d: Double, it: [P])] = []
    for p in ps {
        if let last = rows.last, last.w + gap + p.w <= rowW {
            rows[rows.count - 1].w += gap + p.w; rows[rows.count - 1].d = max(last.d, p.d); rows[rows.count - 1].it.append(p)
        } else { rows.append((p.w, p.d, [p])) }
    }
    let W = rows.map(\.w).max()!, Dp = rows.reduce(0) { $0 + $1.d } + gap * Double(rows.count - 1), H = ps.map(\.h).max()!
    var parts: [Part3] = [], edges: [Edges3] = [], groups: [Group3] = [], list: [Room3] = []
    var z = 0.0
    for row in rows {
        var x = (W - row.w) / 2
        for p in row.it {
            let gi = groups.count, dx = x - p.x0, dz = z - p.z0, mv = V3(dx, 0, dz)
            for pt in p.b.parts {
                let np = Part3(gi, pt.wall, pt.role, pt.rgb, pt.op, look: pt.look)
                np.faces = pt.faces.map { Face3(n: $0.n, pts: $0.pts.map { $0 + mv }, tris: $0.tris, grain: $0.grain) }
                parts.append(np)
            }
            for e in p.b.edges { let ne = Edges3(gi, e.wall); ne.segs = e.segs.map { $0 + mv }; edges.append(ne) }
            for g in p.b.groups { groups.append(Group3(cx: g.cx + dx, cz: g.cz + dz, normals: g.normals)) }
            list.append(Room3(id: p.room.id, name: name(p.room), cx: x + p.w / 2, cz: z + p.d / 2, w: p.w, d: p.d, h: p.h))
            x += p.w + gap
        }
        z += row.d + gap
    }
    let gs = max(W, Dp) + 4
    return Shell3D(
        parts: parts, edges: edges, groups: groups, labels: [], rooms3: list, L: W, W: Dp, H: H, tgt: V3(W / 2, H * 0.3, Dp / 2),
        r: max(W, Dp) * 1.5 + 2.5, theta: .pi / 2 + 0.45, phi: 0.9,
        bounds: Bounds3(x0: list.map(\.cx).min()!, x1: list.map(\.cx).max()!, z0: list.map(\.cz).min()!, z1: list.map(\.cz).max()!),
        rMin: 3, fit: [W, Dp, H, 1, 1.35], gridSize: gs, gridDiv: kround(gs * 2), gridCx: W / 2, gridCz: Dp / 2, light: lightTowards(W, Dp, H), far: 400)
}

/* ---------------- light: the prototype's Lambert material under a hemisphere, an ambient and a directional light ---------------- */

/// The colour three.js (r128, no colour management) gives a Lambert face with normal n: the base colour times ambient 0.3
/// + hemisphere 0.5 (white sky, #C9D3E0 ground) + directional 0.55 · max(0, n·l), clamped. sRGB numbers.
func shade(_ rgb: Int, _ n: V3, _ light: V3) -> Int {
    let w = 0.5 * n.y + 0.5, dl = 0.55 * max(0, n.dot(light))
    let ground = [0xC9, 0xD3, 0xE0]
    var out = 0
    for k in 0..<3 {
        let c = (rgb >> (16 - 8 * k)) & 255
        let g = Double(ground[k]) / 255
        let f = 0.3 + 0.5 * (g + (1 - g) * w) + dl
        out = (out << 8) | min(255, max(0, kround(Double(c) * f)))
    }
    return out
}

func rgbOf(_ hex: String) -> Int { Int(hex.replacingOccurrences(of: "#", with: ""), radix: 16).map { $0 & 0xFFFFFF } ?? 0xECE8E1 }

/// The swatches of the 3D page (prototype wc and fc).
let WALL_COLORS = ["#ECE8E1", "#D9D4CB", "#D6E0EC", "#E6D3B3"]
let FLOOR_COLORS = ["#C49A6C", "#8A6343", "#B9BDC2", "#A7A39C"]
