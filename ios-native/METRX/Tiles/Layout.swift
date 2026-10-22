import Foundation

/*
 * Laying the tiles (Android tiles/Layout.kt): each surface a layout covers (the floor, a wall or a band of it, a column's
 * faces, a niche's back, a bath's front) as an outline with holes in its own millimetres, and every tile of the pattern
 * clipped to it. A piece is whole or cut; the doors, windows, columns, niches, trays and baths are holes the tiles are
 * cut round.
 */

/// A point or a direction on a surface, mm.
struct V2: Equatable {
    var x: Double, y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static func + (a: V2, b: V2) -> V2 { V2(a.x + b.x, a.y + b.y) }
    static func - (a: V2, b: V2) -> V2 { V2(a.x - b.x, a.y - b.y) }
    static func * (a: V2, k: Double) -> V2 { V2(a.x * k, a.y * k) }
    func dot(_ o: V2) -> Double { x * o.x + y * o.y }
    func cross(_ o: V2) -> Double { x * o.y - y * o.x }
}

/// Kotlin's Math.floorMod: the remainder that is never negative.
func tFloorMod(_ a: Int, _ n: Int) -> Int { let r = a % n; return r < 0 ? r + n : r }

/// A double as a whole number, never trapping (a huge or broken value stays in range).
func tInt(_ v: Double) -> Int { v.isFinite ? Int(min(max(v, -1e15), 1e15)) : 0 }

/* ---------------- polygons ---------------- */

/// The signed area (shoelace); positive for the room's own corner order (clockwise on the plan, y down).
func polyArea(_ p: [V2]) -> Double {
    if p.isEmpty { return 0 }
    var s = 0.0
    let n = p.count
    for i in 0..<n { let a = p[i], b = p[(i + 1) % n]; s += a.x * b.y - b.x * a.y }
    return s / 2
}

private func signOf(_ v: Double) -> Double { v > 0 ? 1 : v < 0 ? -1 : 0 }

/// p cut by the line a→b: the side where s · (b − a) × (q − a) ≥ 0 stays. p may be concave; the area stays right.
func clipHalf(_ p: [V2], _ a: V2, _ b: V2, _ s: Double) -> [V2] {
    if p.count < 3 { return [] }
    var out: [V2] = []
    out.reserveCapacity(p.count + 2)
    let d = b - a
    let n = p.count
    for i in 0..<n {
        let c = p[i], nx = p[(i + 1) % n]
        let fc = s * d.cross(c - a), fn = s * d.cross(nx - a)
        if fc >= 0 { out.append(c) }
        if (fc >= 0) != (fn >= 0) {
            let t = fc / (fc - fn)
            out.append(c + (nx - c) * t)
        }
    }
    return out.count < 3 ? [] : out
}

/// p inside the convex polygon k.
func clipConvex(_ p: [V2], _ k: [V2]) -> [V2] {
    let s = signOf(polyArea(k))
    if s == 0 { return [] }
    var r = p
    let n = k.count
    for i in 0..<n {
        r = clipHalf(r, k[i], k[(i + 1) % n], s)
        if r.isEmpty { return r }
    }
    return r
}

/// p less the convex hole h, as convex pieces when p is convex: one piece beyond each of the hole's edges.
func polySubtract(_ p: [V2], _ h: [V2]) -> [[V2]] {
    let s = signOf(polyArea(h))
    if s == 0 { return [p] }
    var out: [[V2]] = []
    var rest = p
    let n = h.count
    for i in 0..<n {
        let a = h[i], b = h[(i + 1) % n]
        let o = clipHalf(rest, a, b, -s)
        if o.count >= 3 && abs(polyArea(o)) > 1.0 { out.append(o) }
        rest = clipHalf(rest, a, b, s)
        if rest.isEmpty { break }
    }
    return out
}

struct Box2 {
    let x0: Double, y0: Double, x1: Double, y1: Double
    func hits(_ o: Box2) -> Bool { x0 < o.x1 && o.x0 < x1 && y0 < o.y1 && o.y0 < y1 }
}

func tBoxOf(_ p: [V2]) -> Box2 {
    var x0 = Double.greatestFiniteMagnitude, y0 = Double.greatestFiniteMagnitude
    var x1 = -Double.greatestFiniteMagnitude, y1 = -Double.greatestFiniteMagnitude
    for q in p { x0 = min(x0, q.x); y0 = min(y0, q.y); x1 = max(x1, q.x); y1 = max(y1, q.y) }
    return Box2(x0: x0, y0: y0, x1: x1, y1: y1)
}

private func same(_ a: V2, _ b: V2) -> Bool { abs(a.x - b.x) < 1e-6 && abs(a.y - b.y) < 1e-6 }

/// Whether p is convex (straight runs allowed).
func isConvex(_ p: [V2]) -> Bool {
    var sg = 0.0
    let n = p.count
    for i in 0..<n {
        let a = p[i], b = p[(i + 1) % n], c = p[(i + 2) % n]
        let cr = (b - a).cross(c - b)
        if abs(cr) < 1e-6 { continue }
        if sg == 0 { sg = signOf(cr) } else if signOf(cr) != sg { return false }
    }
    return true
}

/// A polygon as convex pieces: itself when convex, else its triangles joined back while they stay convex.
func convexParts(_ p: [V2]) -> [[V2]] {
    if p.count < 3 { return [] }
    if isConvex(p) { return [p] }
    let idx = earClip(p.map { ($0.x, $0.y) })
    var parts: [[V2]] = []
    var t = 0
    while t + 2 < idx.count { parts.append([p[idx[t]], p[idx[t + 1]], p[idx[t + 2]]]); t += 3 }
    var merged = true
    while merged {
        merged = false
        outer: for i in parts.indices {
            for j in (i + 1)..<parts.count {
                guard let m = joinPolys(parts[i], parts[j]) else { continue }
                if !isConvex(m) { continue }
                parts[i] = m; parts.remove(at: j); merged = true
                break outer
            }
        }
    }
    return parts
}

/// Two polygons with an edge in common as one, or nil.
private func joinPolys(_ a: [V2], _ b: [V2]) -> [V2]? {
    let na = a.count, nb = b.count
    if na < 3 || nb < 3 { return nil }
    for i in 0..<na {
        let u = a[i], v = a[(i + 1) % na]
        for j in 0..<nb {
            let bu = b[j], bv = b[(j + 1) % nb]
            let back = same(bu, v) && same(bv, u), fwd = same(bu, u) && same(bv, v)
            if !back && !fwd { continue }
            var out: [V2] = []
            for k in 0..<na { out.append(a[(i + 1 + k) % na]) }          // v … u
            if back { for k in 2..<nb { out.append(b[(j + k) % nb]) } }  // after u … before v
            else { for k in 1..<(nb - 1) { out.append(b[(j - k + 2 * nb) % nb]) } }
            return out
        }
    }
    return nil
}

/* ---------------- the room as surfaces ---------------- */

/// Where a surface is in the 3D scene: o in metres, u and v its axes, n the way it faces.
struct TFrame {
    let o: V3, u: V3, v: V3, n: V3
    init(_ o: V3, _ u: V3, _ v: V3, _ n: V3) { self.o = o; self.u = u; self.v = v; self.n = n }
    /// The scene point of surface point (a, b) mm, off metres in front of it.
    func at(_ a: Double, _ b: Double, _ off: Double = 0) -> V3 {
        let x = o.x + (u.x * a + v.x * b) / 1000 + n.x * off
        let y = o.y + (u.y * a + v.y * b) / 1000 + n.y * off
        let z = o.z + (u.z * a + v.z * b) / 1000 + n.z * off
        return V3(x, y, z)
    }
}

/// A wall on the plan, mm: from p0 along t, nIn into the room.
struct TWall {
    let id: String, p0: V2, t: V2, nIn: V2, len: Double
    func at(_ a: Double, _ d: Double = 0) -> V2 { p0 + t * a + nIn * d }
}

/// A measured room as the tiles see it: its walls, its floor outline (plan mm), its height, its tray and bath, and where
/// the plan's corner is in the 3D scene (dx, dz metres).
struct TRoomGeo {
    let room: Room, walls: [TWall], floor: [V2], H: Double, fixes: [TFix], dx: Double, dz: Double, rect: Bool
    func wall(_ id: String) -> TWall? { walls.first { $0.id == id } }
    func scene(_ q: V2, _ y: Double = 0) -> V3 { V3(q.x / 1000 + dx, y, q.y / 1000 + dz) }
    func wallFrame(_ w: TWall, _ depth: Double = 0) -> TFrame {
        let o = scene(w.p0 + w.nIn * depth)
        return TFrame(o, V3(w.t.x, 0, w.t.y), V3(0, 1, 0), V3(w.nIn.x, 0, w.nIn.y))
    }
    var floorFrame: TFrame { TFrame(V3(dx, 0, dz), V3(1, 0, 0), V3(0, 0, 1), V3(0, 1, 0)) }
}

/// The room ready for tiles, or nil until it can be drawn in 3D (its sizes and height known).
func roomGeo(_ r: Room, _ snap: Bool, _ fixes: [TFix], _ dx: Double = 0, _ dz: Double = 0) -> TRoomGeo? {
    if !Geo.ready3D(r, snap) { return nil }
    guard let H = r.dim("H").v else { return nil }
    var ws: [TWall] = []
    for w in Geo.walls(r, snap) {
        let p0 = V2(w.p0.x, w.p0.y)
        let d = V2(w.p1.x, w.p1.y) - p0
        let l = hypot(d.x, d.y)
        let t = l > 0 ? d * (1 / l) : V2(1, 0)
        ws.append(TWall(id: w.id, p0: p0, t: t, nIn: V2(-t.y, t.x), len: l))
    }
    if ws.count < 3 || ws.contains(where: { $0.len <= 0 }) { return nil }
    return TRoomGeo(room: r, walls: ws, floor: ws.map(\.p0), H: Double(H), fixes: fixes, dx: dx, dz: dz, rect: !r.isPoly)
}

/// A tray's or bath's place on the plan: its four corners.
func footprint(_ g: TRoomGeo, _ f: TFix) -> [V2]? {
    guard let w = g.wall(f.wall) else { return nil }
    let a0 = Double(f.off), a1 = Double(f.off + f.w), d = Double(f.d)
    return [w.at(a0), w.at(a1), w.at(a1, d), w.at(a0, d)]
}

/// The stretch of wall w a tray or bath stands against, mm along it, or nil when it does not touch it.
func coverOn(_ g: TRoomGeo, _ w: TWall, _ f: TFix) -> (Double, Double)? {
    guard let fp = footprint(g, f) else { return nil }
    let on = fp.filter { q in abs((q - w.p0).dot(w.nIn)) < 3.0 }.map { q in (q - w.p0).dot(w.t) }
    if on.count < 2 { return nil }
    let a = max(0.0, on.min()!), b = min(w.len, on.max()!)
    return b - a > 1 ? (a, b) : nil
}

/// A column's footprint on the plan (rectangular rooms: columns and niches are drawn in 3D there only).
private func colFoot(_ g: TRoomGeo, _ f: Feature) -> [V2]? {
    guard let w = g.wall(f.wall) else { return nil }
    let a0 = Double(f.off), a1 = Double(f.off + f.w), d = Double(f.d)
    return [w.at(a0), w.at(a1), w.at(a1, d), w.at(a0, d)]
}

func tRect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> [V2] { [V2(x0, y0), V2(x1, y0), V2(x1, y1), V2(x0, y1)] }

/// One surface to tile: its outline and holes in its own mm (u along, v up; the floor in plan mm), its frame in the
/// scene, the wall it belongs to (the floor none), kind floor, wall, col, niche, bath or panel, alt the second tile on
/// it. lo, hi the band of a wall it covers (bottom, top); len its length along.
struct Surf {
    let key: String, kind: String, wall: String?, outline: [V2], holes: [[V2]], frame: TFrame, alt: Bool
    var lo = 0.0, hi = 0.0, len = 0.0
}

/// A wall surface's tiled band, bottom to top, mm.
func zoneOf(_ s: TSurf, _ H: Double) -> (Double, Double) {
    switch s.mode {
    case "to": return (0, min(H, max(Double(s.h1), 1)))
    case "band": return (min(max(Double(s.h0), 0), H), min(max(Double(s.h1), 0), H))
    default: return (0, H)
    }
}

/// The surfaces layout l covers in room g.
func surfacesOf(_ l: TileLayout, _ g: TRoomGeo) -> [Surf] {
    var out: [Surf] = []
    let r = g.room
    for s in l.surfs {
        if s.id == "floor" {
            var holes: [[V2]] = []
            if g.rect { for f in r.features where f.type == "column" { if let fp = colFoot(g, f) { holes.append(fp) } } }
            for f in g.fixes { if let fp = footprint(g, f) { holes.append(fp) } }
            out.append(Surf(key: "floor", kind: "floor", wall: nil, outline: g.floor, holes: holes, frame: g.floorFrame, alt: s.alt))
            continue
        }
        if s.id.hasPrefix("bath:") {
            let fid = String(s.id.dropFirst(5))
            guard let f = g.fixes.first(where: { $0.id == fid }), let w = g.wall(f.wall) else { continue }
            out.append(Surf(key: s.id, kind: "bath", wall: w.id, outline: tRect(Double(f.off), 0, Double(f.off + f.w), Double(f.h)), holes: [],
                            frame: g.wallFrame(w, Double(f.d)), alt: s.alt, lo: 0, hi: Double(f.h), len: w.len))
            continue
        }
        guard let w = g.wall(s.id) else { continue }
        let (lo, hi) = zoneOf(s, g.H)
        if hi - lo < 1 { continue }
        var holes: [[V2]] = []
        for o in r.openings where o.wall == w.id {
            holes.append(tRect(Double(o.off), Double(o.sill), Double(o.off + o.w), Double(o.sill + o.h)))
        }
        for f in g.fixes { if let c = coverOn(g, w, f) { holes.append(tRect(c.0, -1, c.1, Double(f.h))) } }
        let frame = g.wallFrame(w)
        if g.rect {
            for f in r.features where f.wall == w.id {
                let a0 = Double(f.off), a1 = Double(f.off + f.w), d = Double(f.d)
                if f.type == "column" {
                    holes.append(tRect(a0, -1, a1, g.H + 1))
                    out.append(Surf(key: "\(w.id):c:\(f.id):f", kind: "col", wall: w.id, outline: tRect(a0, lo, a1, hi), holes: [], frame: g.wallFrame(w, d),
                                    alt: s.alt, lo: lo, hi: hi, len: w.len))
                    // the sides: u runs from the wall into the room
                    let sideL = TFrame(g.scene(w.at(a0)), V3(w.nIn.x, 0, w.nIn.y), V3(0, 1, 0), V3(-w.t.x, 0, -w.t.y))
                    let sideR = TFrame(g.scene(w.at(a1)), V3(w.nIn.x, 0, w.nIn.y), V3(0, 1, 0), V3(w.t.x, 0, w.t.y))
                    out.append(Surf(key: "\(w.id):c:\(f.id):l", kind: "col", wall: w.id, outline: tRect(0, lo, d, hi), holes: [], frame: sideL, alt: s.alt, lo: lo, hi: hi, len: d))
                    out.append(Surf(key: "\(w.id):c:\(f.id):r", kind: "col", wall: w.id, outline: tRect(0, lo, d, hi), holes: [], frame: sideR, alt: s.alt, lo: lo, hi: hi, len: d))
                } else {
                    let sill = Double(f.sill)
                    let nh = min(f.h > 0 ? Double(f.h) : g.H - sill, g.H - sill)
                    holes.append(tRect(a0, sill, a1, sill + nh))
                    let b0 = max(lo, sill), b1 = min(hi, sill + nh)
                    let thick = Double(r.dim("T").v ?? 200)
                    if b1 - b0 > 1 {
                        out.append(Surf(key: "\(w.id):n:\(f.id)", kind: "niche", wall: w.id, outline: tRect(a0, b0, a1, b1), holes: [],
                                        frame: g.wallFrame(w, -min(d, thick - 10)), alt: s.alt, lo: b0, hi: b1, len: w.len))
                    }
                }
            }
        }
        out.append(Surf(key: w.id, kind: "wall", wall: w.id, outline: tRect(0, lo, w.len, hi), holes: holes, frame: frame, alt: s.alt, lo: lo, hi: hi, len: w.len))
    }
    return out
}

/// A layout without a room: one surface, its frame given by the scene that shows it.
func panelSurf(_ l: TileLayout, _ frame: TFrame) -> Surf? {
    guard let p = l.panel else { return nil }
    if p.a <= 0 || p.b <= 0 { return nil }
    let floor = p.kind == "floor"
    return Surf(key: "panel", kind: floor ? "floor" : "panel", wall: floor ? nil : "A", outline: tRect(0, 0, Double(p.a), Double(p.b)), holes: [], frame: frame,
                alt: false, lo: 0, hi: Double(p.b), len: Double(p.a))
}

/* ---------------- the pattern ---------------- */

/// How tiles go on a region: the pattern's origin o (surface mm) and angle ang (radians), the tile a × b (long side b
/// along the pattern), the joint j; kind straight, brick2, brick3 or herring; chess alternate tiles in the second look;
/// prod what the tiles are: 0 the main tile, 1 the second look, 2 the border strip's tile.
struct TSpec {
    let o: V2, ang: Double, a: Double, b: Double, j: Double, kind: String, chess: Bool, prod: Int
}

/// One tile on a surface: its pieces (convex polygons, surface mm), its area, the whole tile's area, which tile it is, its
/// cut piece's size along and across the tile (pw × ph, mm), whether that piece is about a rectangle, and the tile's
/// drawn corners c (c0 → c1 along its long side when not vert) for its texture. s is the surface index.
struct TPiece {
    let polys: [[V2]], area: Double, full: Double, prod: Int, pw: Double, ph: Double, rectish: Bool
    let c: [V2], vert: Bool, seed: Int, s: Int
    var cut: Bool { area < full * 0.995 }
}

/// Rotating by an angle (its cosine c and sine s) about nothing.
private func tRot(_ p: V2, _ c: Double, _ s: Double) -> V2 { V2(p.x * c - p.y * s, p.x * s + p.y * c) }

/// A tile of the pattern in its own frame: corner, size along x and y, its row and column, standing up (herringbone).
private struct PatTile { let x: Double, y: Double, w: Double, h: Double, i: Int, k: Int, vert: Bool }

/// Most tiles worked out for one region: a 10 mm mosaic on a big floor would otherwise take seconds.
let MAX_TILES = 60_000

/// The pattern's tiles that may touch the box x0…x1, y0…y1 (pattern frame); nil: too many.
private func tilesIn(_ sp: TSpec, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> [PatTile]? {
    let a = sp.a, b = sp.b, j = sp.j
    var out: [PatTile] = []
    if sp.kind == "herring" {
        // a staircase of a lying tile and a standing one, repeated by (S, S) and (L, −L)
        let L = b + j, S = a + j
        let kMin = tInt(floor((x0 + y0) / (2 * S))) - 2, kMax = tInt(ceil((x1 + y1) / (2 * S))) + 2
        let mMin = tInt(floor((x0 - y1) / (2 * L))) - 2, mMax = tInt(ceil((x1 - y0) / (2 * L))) + 2
        if Double(kMax - kMin) * Double(mMax - mMin) * 2 > Double(MAX_TILES * 4) { return nil }
        if kMax < kMin || mMax < mMin { return out }
        for k in kMin...kMax {
            for m in mMin...mMax {
                let hx = Double(k) * S + Double(m) * L
                let hy = Double(k) * S - Double(m) * L
                if hx < x1 && hx + b > x0 && hy < y1 && hy + a > y0 { out.append(PatTile(x: hx, y: hy, w: b, h: a, i: k, k: m, vert: false)) }
                let vy = hy + S
                if hx < x1 && hx + a > x0 && vy < y1 && vy + b > y0 { out.append(PatTile(x: hx, y: vy, w: a, h: b, i: k, k: m, vert: true)) }
                if out.count > MAX_TILES { return nil }
            }
        }
    } else {
        let pw = b + j, ph = a + j
        let kMin = tInt(floor(y0 / ph)) - 1, kMax = tInt(ceil(y1 / ph)) + 1
        let across = (x1 - x0) / pw + 3
        if Double(kMax - kMin) * across > Double(MAX_TILES) { return nil }
        if kMax < kMin { return out }
        for k in kMin...kMax {
            var shift = 0.0
            if sp.kind == "brick2" { shift = Double(tFloorMod(k, 2)) * pw / 2 }
            else if sp.kind == "brick3" { shift = Double(tFloorMod(k, 3)) * pw / 3 }
            let iMin = tInt(floor((x0 - shift) / pw)) - 1, iMax = tInt(ceil((x1 - shift) / pw)) + 1
            if iMax < iMin { continue }
            for i in iMin...iMax { out.append(PatTile(x: Double(i) * pw + shift, y: Double(k) * ph, w: b, h: a, i: i, k: k, vert: false)) }
        }
    }
    return out
}

/// The tiles of sp on the region (any polygon) less holes (convex), as pieces of surface si; inset shrinks each tile
/// before it is cut (the drawing's joints, so a 2 mm joint still shows). nil: too many tiles.
func layTiles(_ region: [V2], _ holes: [[V2]], _ sp: TSpec, _ si: Int, _ inset: Double = 0) -> [TPiece]? {
    if region.count < 3 { return [] }
    let parts: [([V2], Box2)] = convexParts(region).map { ($0, tBoxOf($0)) }
    let hb: [([V2], Box2)] = holes.map { ($0, tBoxOf($0)) }
    let rb = tBoxOf(region)
    let c = cos(sp.ang), s = sin(sp.ang)
    // the region's box in the pattern's frame
    let corners: [V2] = [V2(rb.x0, rb.y0), V2(rb.x1, rb.y0), V2(rb.x1, rb.y1), V2(rb.x0, rb.y1)].map { tRot($0 - sp.o, c, -s) }
    let cb = tBoxOf(corners)
    guard let tiles = tilesIn(sp, cb.x0, cb.y0, cb.x1, cb.y1) else { return nil }
    var out: [TPiece] = []
    for t in tiles {
        let e = min(inset, min(t.w, t.h) / 4)
        let q0: [V2] = [V2(t.x + e, t.y + e), V2(t.x + t.w - e, t.y + e), V2(t.x + t.w - e, t.y + t.h - e), V2(t.x + e, t.y + t.h - e)]
        let q = q0.map { sp.o + tRot($0, c, s) }
        let qb = tBoxOf(q)
        if !qb.hits(rb) { continue }
        var polys: [[V2]] = []
        for (pp, pb) in parts {
            if !qb.hits(pb) { continue }
            let inP = clipConvex(q, pp)
            if inP.count < 3 { continue }
            var cur: [[V2]] = [inP]
            for (h, b) in hb {
                if !qb.hits(b) { continue }
                cur = cur.flatMap { polySubtract($0, h) }
                if cur.isEmpty { break }
            }
            polys += cur
        }
        if polys.isEmpty { continue }
        var ar = 0.0
        for pl in polys { ar += abs(polyArea(pl)) }
        if ar < 4.0 { continue }
        // the piece's size in the tile's own frame (long side first)
        var lx0 = Double.greatestFiniteMagnitude, ly0 = Double.greatestFiniteMagnitude
        var lx1 = -Double.greatestFiniteMagnitude, ly1 = -Double.greatestFiniteMagnitude
        for pl in polys {
            for v in pl {
                let p = tRot(v - sp.o, c, -s)
                lx0 = min(lx0, p.x - t.x); ly0 = min(ly0, p.y - t.y); lx1 = max(lx1, p.x - t.x); ly1 = max(ly1, p.y - t.y)
            }
        }
        let ex = min(max(lx1 - lx0, 0), t.w), ey = min(max(ly1 - ly0, 0), t.h)
        let pw = t.vert ? ey : ex, ph = t.vert ? ex : ey
        let full = (t.w - 2 * e) * (t.h - 2 * e)
        let prod = sp.chess && tFloorMod(t.i + t.k, 2) == 1 ? 1 : sp.prod
        let rectish = ar / max(1.0, ex * ey) > 0.97
        let seed = 31 &* t.i &+ 17 &* t.k &+ (t.vert ? 7 : 0)
        out.append(TPiece(polys: polys, area: ar, full: full, prod: prod, pw: pw, ph: ph, rectish: rectish, c: q, vert: t.vert, seed: seed, s: si))
    }
    return out
}

/// The tiles' angle of a layout: its turn, and the pattern's own (a diagonal 45°, a herringbone's staircase −45°).
func angleOf(_ l: TileLayout) -> Double {
    let own = l.pattern == "diagonal" ? 45 : l.pattern == "herring" ? -45 : 0
    return Double(l.rot + own) * Double.pi / 180
}

private func tKindOf(_ l: TileLayout) -> String {
    switch l.pattern { case "brick2", "brick3", "herring": return l.pattern; default: return "straight" }
}

/// How far a tile of a × b at angle ang reaches along the unit direction d.
private func tReach(_ a: Double, _ b: Double, _ ang: Double, _ d: V2) -> Double {
    let c = cos(ang), s = sin(ang)
    return abs(V2(c, s).dot(d)) * b + abs(V2(-s, c).dot(d)) * a
}

/// The pattern origin that puts the middle of a tile at mid.
private func originAt(_ mid: V2, _ a: Double, _ b: Double, _ ang: Double) -> V2 { mid - tRot(V2(b / 2, a / 2), cos(ang), sin(ang)) }

/// The middle of the floor's first tile: the room's middle, its first corner or the door, moved by hand.
func floorStart(_ l: TileLayout, _ g: TRoomGeo) -> V2 {
    let a = Double(l.a), b = Double(l.b), ang = angleOf(l), j = Double(l.joint)
    var door: (TWall, Double)? = nil
    if let o = g.room.openings.first(where: { $0.type == "door" }), let w = g.wall(o.wall) { door = (w, Double(o.off) + Double(o.w) / 2) }
    let mid: V2
    if l.start == "corner" {
        let w = g.walls[0]
        mid = w.p0 + w.t * ((tReach(a, b, ang, w.t) + j) / 2) + w.nIn * ((tReach(a, b, ang, w.nIn) + j) / 2)
    } else if l.start == "door", let dr = door {
        let w = dr.0, u = dr.1
        mid = w.at(u) + w.nIn * ((tReach(a, b, ang, w.nIn) + j) / 2)
    } else {
        mid = tCentroid(g.floor)
    }
    return mid + V2(Double(l.ox), Double(l.oy))
}

func tCentroid(_ v: [V2]) -> V2 {
    if v.isEmpty { return V2(0, 0) }
    var ar = 0.0, cx = 0.0, cy = 0.0
    let n = v.count
    for i in 0..<n {
        let p = v[i], q = v[(i + 1) % n]
        let cr = p.x * q.y - q.x * p.y
        ar += cr; cx += (p.x + q.x) * cr; cy += (p.y + q.y) * cr
    }
    if abs(ar) < 1e-9 {
        var sx = 0.0, sy = 0.0
        for p in v { sx += p.x; sy += p.y }
        return V2(sx / Double(n), sy / Double(n))
    }
    return V2(cx / (3 * ar), cy / (3 * ar))
}

/// The middle, along a wall, of its first tile: the wall's middle, its start corner, the door's edge, or in line with
/// the floor's tiles.
private func wallStartU(_ l: TileLayout, _ g: TRoomGeo?, _ wallId: String?, _ len: Double, _ floorMid: V2?) -> Double {
    let a = Double(l.a), b = Double(l.b), ang = angleOf(l)
    let along = tReach(a, b, ang, V2(1, 0))
    let w: TWall? = wallId.flatMap { id in g?.wall(id) }
    if l.align, let w, let floorMid { return (floorMid - w.p0).dot(w.t) }
    switch l.start {
    case "corner": return along / 2
    case "door":
        if let o = g?.room.openings.first(where: { $0.wall == wallId && $0.type == "door" }) { return Double(o.off) + along / 2 }
        return len / 2
    default: return len / 2
    }
}

/// Every piece of a layout on its surfaces; a surface whose tiles are too many to work out has none (tooMany lists them).
struct Laid {
    let surfs: [Surf]
    let pieces: [TPiece]
    let tooMany: Set<Int>
}

/// Every piece of layout l on surfs; floorMid the room's floor tile middle the walls line up with (nil: none); inset
/// see layTiles.
func layAll(_ l: TileLayout, _ surfs: [Surf], _ g: TRoomGeo?, _ floorMid: V2?, _ inset: Double = 0) -> Laid {
    var out: [TPiece] = []
    var many = Set<Int>()
    let a = Double(l.a), b = Double(l.b), j = Double(l.joint), ang = angleOf(l), kind = tKindOf(l)
    let chess = l.pattern == "chess"
    var straight = l
    straight.pattern = "straight"
    let angS = angleOf(straight)
    let sa = Double(l.sa), sb = Double(l.sb)
    for (si, s) in surfs.enumerated() {
        let prod = s.alt ? 1 : 0
        func add(_ region: [V2], _ sp: TSpec) {
            if let ps = layTiles(region, s.holes, sp, si, inset) { out += ps } else { many.insert(si) }
        }
        if s.kind == "floor" {
            let mid: V2
            if let g, s.key == "floor" { mid = floorStart(l, g) }
            else if s.key == "panel" { mid = panelMid(l, s) }
            else { mid = tCentroid(s.outline) }
            if l.pattern == "border" {
                // a strip of the second tile round the edge, mitred at the corners; the field inside it
                let bw = sa + j
                let inner = insetPoly(s.outline, bw)
                let n = s.outline.count
                for i in 0..<n {
                    let p0 = s.outline[i], p1 = s.outline[(i + 1) % n]
                    let d = p1 - p0
                    let ln = hypot(d.x, d.y)
                    if ln < 1 { continue }
                    let band = [p0, p1, inner[(i + 1) % n], inner[i]]
                    add(band, TSpec(o: p0, ang: atan2(d.y, d.x), a: sa, b: sb, j: j, kind: "straight", chess: false, prod: 2))
                }
                add(inner, TSpec(o: originAt(mid, a, b, angS), ang: angS, a: a, b: b, j: j, kind: "straight", chess: false, prod: prod))
            } else {
                add(s.outline, TSpec(o: originAt(mid, a, b, ang), ang: ang, a: a, b: b, j: j, kind: kind, chess: chess, prod: prod))
            }
        } else {
            let lo = s.lo
            let side = s.kind == "col" && (s.key.hasSuffix(":l") || s.key.hasSuffix(":r"))
            let u = side ? tReach(a, b, ang, V2(1, 0)) / 2 : wallStartU(l, g, s.wall, s.len, floorMid)
            let v = lo + tReach(a, b, ang, V2(0, 1)) / 2
            if l.pattern == "border" && s.kind != "col" {
                let b0 = min(max(Double(l.band), s.lo), s.hi)
                let b1 = min(b0 + sa, s.hi)
                let bx = tBoxOf(s.outline)
                let sp = TSpec(o: originAt(V2(u, v), a, b, 0), ang: 0, a: a, b: b, j: j, kind: "straight", chess: false, prod: prod)
                if b0 - bx.y0 > 1 { add(tRect(bx.x0, bx.y0, bx.x1, b0 - j / 2), sp) }
                if bx.y1 - b1 > 1 {
                    let o2 = originAt(V2(u, b1 + j / 2 + a / 2), a, b, 0)
                    add(tRect(bx.x0, b1 + j / 2, bx.x1, bx.y1), TSpec(o: o2, ang: 0, a: a, b: b, j: j, kind: "straight", chess: false, prod: prod))
                }
                if b1 - b0 > 1 {
                    let o3 = originAt(V2(u, (b0 + b1) / 2), sa, sb, 0)
                    add(tRect(bx.x0, b0, bx.x1, b1), TSpec(o: o3, ang: 0, a: sa, b: sb, j: j, kind: "straight", chess: false, prod: 2))
                }
            } else {
                add(s.outline, TSpec(o: originAt(V2(u, v), a, b, ang), ang: ang, a: a, b: b, j: j, kind: kind, chess: chess, prod: prod))
            }
        }
    }
    return Laid(surfs: surfs, pieces: out, tooMany: many)
}

/// A typed floor's first tile: its middle, or its first corner.
private func panelMid(_ l: TileLayout, _ s: Surf) -> V2 {
    let a = Double(l.a), b = Double(l.b), ang = angleOf(l), j = Double(l.joint)
    let c = l.start == "corner" ? V2((tReach(a, b, ang, V2(1, 0)) + j) / 2, (tReach(a, b, ang, V2(0, 1)) + j) / 2) : tCentroid(s.outline)
    return c + V2(Double(l.ox), Double(l.oy))
}

/// The polygon p (the room's corner order) moved in by d on every side, mitred.
func insetPoly(_ p: [V2], _ d: Double) -> [V2] {
    let n = p.count
    if n == 0 { return [] }
    var nin: [V2] = []
    for i in 0..<n {
        let q = p[(i + 1) % n] - p[i]
        let l0 = hypot(q.x, q.y), l = l0 > 0 ? l0 : 1
        nin.append(V2(-q.y / l, q.x / l))
    }
    let sg = polyArea(p) >= 0 ? 1.0 : -1.0
    var out: [V2] = []
    for i in 0..<n {
        let a = nin[(i - 1 + n) % n] * sg, b = nin[i] * sg
        let k = 1 + a.dot(b)
        out.append(k < 0.15 ? p[i] + b * d : p[i] + (a + b) * (d / k))
    }
    return out
}

/// The pieces of a layout in a room: its surfaces, then the tiles; the walls line up with the room's floor layout floorOf.
func layRoom(_ l: TileLayout, _ g: TRoomGeo, _ floorOf: TileLayout?, _ inset: Double = 0) -> Laid {
    var fm: V2? = nil
    if let f = floorOf, f.surfs.contains(where: { $0.id == "floor" }) {
        let deg = angleOf(f) * 180 / Double.pi
        if abs(deg.truncatingRemainder(dividingBy: 90)) < 1e-6 { fm = floorStart(f, g) }
    }
    return layAll(l, surfacesOf(l, g), g, fm, inset)
}

/// The room's floor layout the walls line up with: the first one that covers the floor.
func floorLayout(_ ls: [TileLayout], _ roomId: String) -> TileLayout? {
    ls.first { $0.roomId == roomId && $0.surfs.contains { s in s.id == "floor" } }
}
