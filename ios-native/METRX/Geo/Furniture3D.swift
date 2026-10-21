import Foundation

/*
 * Furniture in the room's 3D scene (furniture plan section 9; Android geo/Furniture3D.kt): every board a box in its
 * material's colour, on its wall's frame (WallBasis). Doors swing open about 100°, drawers pull out; Furn3D.picks are
 * what a tap can open. Plain colours until Stage 3. Sizes come in millimetres and go out in metres.
 */

/// A box with corner o and edges a, b, c (perpendicular, not necessarily unit length).
struct Obb {
    let o: V3, a: V3, b: V3, c: V3
    func corners() -> [V3] { [o, o + a, o + a + c, o + c, o + b, o + a + b, o + a + b + c, o + b + c] }

    /// Where a ray from e along d first enters the box (its distance), or nil.
    func hit(_ e: V3, _ d: V3) -> Double? {
        var t0 = 0.0, t1 = Double.greatestFiniteMagnitude
        for ax in [a, b, c] {
            let l2 = ax.dot(ax); if l2 < 1e-12 { return nil }
            // the box is 0..1 along each edge: (p - o)·ax / |ax|²
            let p = (e - o).dot(ax) / l2, v = d.dot(ax) / l2
            if abs(v) < 1e-12 { if p < 0 || p > 1 { return nil }; continue }
            var ta = (0 - p) / v, tb = (1 - p) / v
            if ta > tb { swap(&ta, &tb) }
            t0 = max(t0, ta); t1 = min(t1, tb); if t0 > t1 { return nil }
        }
        return t0
    }
}

/// Something a tap opens: a door or a drawer (key), where it is now.
struct Pick { let key: String; let box: Obb }

struct Furn3D {
    let parts: [Part3], edges: [Edges3], picks: [Pick], keys: [String]

    /// The door or drawer a ray meets first.
    func pick(_ e: V3, _ d: V3) -> String? {
        var best: (String, Double)? = nil
        for pk in picks { if let t = pk.box.hit(e, d), best == nil || t < best!.1 { best = (pk.key, t) } }
        return best?.0
    }
}

private let METAL = 0xC5CBD4
private let DARK = 0x1E293B
private let HANDLE = 0x4B5563
private let WHITE = 0xE8EAEE
private let OPEN_DEG = 100.0
private let MIRROR = 0xC9D3DD
private let GLASS_P = 0x8FA9C4

/// The faces of a box, each facing out.
private func obbFaces(_ p: Part3, _ x: Obb) {
    let ctr = x.o + (x.a + x.b + x.c) * 0.5
    func face(_ q: [V3]) {
        let fc = V3(q.reduce(0) { $0 + $1.x } / 4, q.reduce(0) { $0 + $1.y } / 4, q.reduce(0) { $0 + $1.z } / 4)
        var n = (q[1] - q[0]).cross(q[3] - q[0]).unit
        if n.dot(fc - ctr) < 0 { n = n * -1 }
        p.faces.append(Face3(n: n, pts: q))
    }
    let o = x.o, a = x.a, b = x.b, c = x.c
    face([o, o + a, o + a + b, o + b]); face([o + c, o + c + a, o + c + a + b, o + c + b])
    face([o, o + c, o + c + b, o + b]); face([o + a, o + a + c, o + a + c + b, o + a + b])
    face([o, o + a, o + a + c, o + c]); face([o + b, o + b + a, o + b + a + c, o + b + c])
}

private func obbEdges(_ e: Edges3, _ x: Obb) {
    let k = x.corners()
    for (i, j) in [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)] { e.segs.append(k[i]); e.segs.append(k[j]) }
}

/// The frame of a piece standing at p (Pose: along and out from wall p.ref, turned): len m long.
func poseBasis(_ w: WallBasis, _ p: Pose, _ len: Double) -> WallBasis {
    let o = w.at(Double(p.a) / 1000, 0, Double(p.n) / 1000)
    let r = Double(p.deg) * .pi / 180, c = cos(r), s = sin(r)
    // turned about the vertical: along u·c + n·s, into the room n·c − u·s
    return WallBasis(ox: o.x, oz: o.z, ux: w.ux * c + w.nx * s, uz: w.uz * c + w.nz * s, nx: w.nx * c - w.ux * s, nz: w.nz * c - w.uz * s, len: len)
}

/// The furniture fs of a room whose walls are bases. rgb gives a material's colour; open holds the keys of open doors
/// and drawers, or amt says how far each one is open, 0 to 1 (moving between the two while it opens or shuts).
func furniture3D(_ fs: [Furniture], _ bases: [String: WallBasis], _ ws: Workshop, _ rgb: (String) -> Int, _ open: Set<String>,
                 amt: ((String) -> Double)? = nil) -> Furn3D {
    let how: (String) -> Double = amt ?? { k in open.contains(k) ? 1 : 0 }
    let st = FStore()
    for f in fs {
        let colors = ["carcass": rgb(f.mats.carcass), "front": rgb(f.mats.front), "back": rgb(f.mats.back), "top": rgb("wt38"),
                      "mirror": MIRROR, "glass": GLASS_P, "splash": rgb("splash6"),
                      "metal": METAL, "dark": DARK, "handle": HANDLE, "white": WHITE]
        let fws = wsOf(f, ws)
        let B = FBuilder(fws, colors, st, how)
        let lens = { (id: String) in bases[id].map { Int(($0.len * 1000).rounded(.towardZero)) } }
        // the island (or peninsula) stands where it was dragged, else 900 mm out from the front of the first wall's
        // units, its fronts facing them
        let island: WallBasis? = f.walls.first { $0 != ISLAND }.flatMap { bases[$0] }.map { w in
            let r = runsOf(f, lens).first { $0.wall == ISLAND }
            let len = r.map { fillOf(f, $0, false).used } ?? 0
            let p = f.kind == "kitchen" ? f.pose ?? islandPose(f, Int((w.len * 1000).rounded())) : islandPose(f, Int((w.len * 1000).rounded()))
            return poseBasis(bases[p.ref] ?? w, p, Double(len) / 1000)
        }
        for m in f.modules {
            // a piece standing free (a desk in the middle of the room) has its own frame, its box from its start
            let free: WallBasis? = f.kind == "wardrobe" && m.type == "wardrobe" ? f.pose.flatMap { p in bases[p.ref].map { poseBasis($0, p, Double(m.w) / 1000) } } : nil
            guard let b = free ?? (m.wall == ISLAND ? island : bases[m.wall ?? ""]) else { continue }
            B.wall = m.wall
            if m.type == "wardrobe" {
                var mm = m; if free != nil { mm.x = 0 }
                B.wardrobe(b, mm)
                // a bathroom vanity carries its basin and tap on top
                if f.type == "vanity" { B.basin(b, mm) }
            } else { B.kitchenUnit(b, m) }
        }
        // the worktop over the lower row of each wall (and over the corner it turns into)
        if f.kind == "kitchen" {
            let wt = worktopTop(fws)
            for r in runsOf(f, lens) {
                guard let b = r.wall == ISLAND ? island : bases[r.wall] else { continue }
                B.wall = r.wall
                let low = f.modules.filter { $0.wall == r.wall && !isUpper($0) && ($0.type == "base" || $0.type == "filler" || $0.app == "dishwasher") }.sorted { $0.x < $1.x }
                let isl = r.wall == ISLAND
                // one worktop over each stretch of touching units, no joint every unit; the corner square is the first
                // side's. An island's is 900+ deep: it reaches 300 past its back for sitting at, and its back is finished.
                let n0 = isl ? -318 : 0
                var a0 = -1, a1 = -1
                func piece() {
                    guard a1 > a0 else { return }
                    B.box(b, B.p("top"), a0, a1, wt - K_TOP, wt, n0, 600, true)
                    if isl { B.box(b, B.p("front"), a0, a1, 0, wt - K_TOP, -18, 0, true) }
                }
                for m in low { if a0 >= 0 && m.x <= a1 + 1 { a1 = max(a1, m.x + m.w) } else { piece(); a0 = m.x; a1 = m.x + m.w } }
                piece()
                // end panels where a row ends in the open room (not against a wall): the lower row's, the wall units'
                if let kx0 = f.kx, let lo = low.first?.x, let hi = low.map({ $0.x + $0.w }).max() {
                    let wl: Int? = isl ? nil : Int((b.len * 1000).rounded())
                    let ends: [(Int, Bool)] = isl ? [(lo, f.layout != "P"), (hi, true)] : [(lo, lo > 20), (hi, wl.map { hi < $0 - 20 } ?? false)]
                    if kx0.ends > 0 { for (a, open) in ends where open { B.box(b, B.p("front"), a == lo ? a - 18 : a, a == lo ? a : a + 18, 0, wt - K_TOP, 0, 600, true) } }
                    let up = f.modules.filter { $0.wall == r.wall && $0.type == "wall" }
                    if kx0.endsUp > 0, let wl, let u0 = up.map(\.x).min(), let u1 = up.map({ $0.x + $0.w }).max() {
                        let y0 = up.map(\.elev).min() ?? 0, y1 = up.map { $0.elev + $0.h }.max() ?? 0, dd = up.map(\.d).max() ?? 300
                        if u0 > 20 { B.box(b, B.p("front"), u0 - 18, u0, y0, y1, 0, dd, true) }
                        if u1 < wl - 20 { B.box(b, B.p("front"), u1, u1 + 18, y0, y1, 0, dd, true) }
                    }
                }
                // extras: the backsplash panel on the wall over the worktop, the cornice on the wall units
                if let kx = f.kx, r.wall != ISLAND {
                    let a0 = r.lowStart > 0 ? 0 : low.map(\.x).min() ?? 0
                    let a1 = low.map { $0.x + $0.w }.max() ?? 0
                    if kx.splash > 0 && a1 > a0 { B.box(b, B.p("splash"), a0, a1, wt, wt + kx.splash, 0, 6, true) }
                    if kx.cornice {
                        for m in f.modules where m.wall == r.wall && m.type == "wall" {
                            B.box(b, B.p("front"), m.x, m.x + m.w, m.elev + m.h, m.elev + m.h + 60, 0, m.d + 30, true)
                        }
                    }
                }
            }
        }
    }
    return Furn3D(parts: st.order.map { st.parts[$0]! }, edges: st.edgeOrder.map { st.edges[$0]! }, picks: st.picks, keys: st.keys)
}

/// What the builders of all pieces share: parts one per wall and colour (so opening a door does not change how many
/// there are), outlines one per wall, picks and keys.
private final class FStore {
    struct K: Hashable { let wall: String?; let rgb: Int }
    var parts: [K: Part3] = [:], order: [K] = []
    var edges: [String: Edges3] = [:], edgeOrder: [String] = []
    var picks: [Pick] = [], keys: [String] = []
}

private func d(_ v: Int) -> Double { Double(v) }

/// Builds the boards of one piece of furniture on a wall frame; lengths in mm.
private final class FBuilder {
    let ws: Workshop, colors: [String: Int], st: FStore, how: (String) -> Double
    /// The wall being furnished: the furniture's parts are kept per wall (it stays solid when its wall goes see-through).
    var wall: String? = nil
    let t: Int, g: Double, edge: Double
    init(_ ws: Workshop, _ colors: [String: Int], _ st: FStore, _ how: @escaping (String) -> Double) {
        self.ws = ws; self.colors = colors; self.st = st; self.how = how
        t = ws.t; g = Double(ws.gap10) / 10; edge = Double(ws.edge10) / 10
    }

    func p(_ k: String) -> Part3 {
        let c = colors[k]!, w = wall == ISLAND ? nil : wall
        let key = FStore.K(wall: w, rgb: c)
        if let x = st.parts[key] { return x }
        let x = Part3(0, w, .furn, c, 1); st.parts[key] = x; st.order.append(key); return x
    }
    var edges: Edges3 {
        let w = wall == ISLAND ? "island" : (wall ?? "island")
        if let e = st.edges[w] { return e }
        // named apart from the wall's own outline, so it does not fade with a see-through wall
        let e = Edges3(0, "furn " + w); st.edges[w] = e; st.edgeOrder.append(w); return e
    }

    func obb(_ p: Part3, _ x: Obb, _ line: Bool) { obbFaces(p, x); if line { obbEdges(edges, x) } }

    /// An upright box a0..a1 along the wall, y0..y1 up, n0..n1 out from the wall.
    func box(_ w: WallBasis, _ p: Part3, _ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double, _ n0: Double, _ n1: Double, _ line: Bool = false) {
        let A0 = a0 / 1000, A1 = a1 / 1000, Y0 = y0 / 1000, Y1 = y1 / 1000, N0 = n0 / 1000, N1 = n1 / 1000
        if A1 - A0 < 1e-4 || Y1 - Y0 < 1e-4 || N1 - N0 < 1e-4 { return }
        obb(p, Obb(o: w.at(A0, Y0, N0), a: w.dir(A1 - A0, 0), b: V3(0, Y1 - Y0, 0), c: w.dir(0, N1 - N0)), line)
    }
    func box(_ w: WallBasis, _ p: Part3, _ a0: Int, _ a1: Int, _ y0: Int, _ y1: Int, _ n0: Int, _ n1: Int, _ line: Bool = false) {
        box(w, p, d(a0), d(a1), d(y0), d(y1), d(n0), d(n1), line)
    }

    /// A door hinged at ha (the back corner of its hinge edge), fw wide, opening to the right (s +1) or left (-1); its
    /// handle's middle hy above the door's bottom.
    func door(_ w: WallBasis, _ key: String, _ ha: Double, _ n: Double, _ y0: Double, _ h: Double, _ fw: Double, _ s: Double, _ handles: Bool, _ hy: Double, _ part: Part3? = nil) {
        st.keys.append(key)
        let th = OPEN_DEG * .pi / 180 * how(key)
        let e = w.dir(s * cos(th), sin(th)), tn = w.dir(-s * sin(th), cos(th))
        let o = w.at(ha / 1000, y0 / 1000, n / 1000)
        let x = Obb(o: o, a: e * (fw / 1000), b: V3(0, h / 1000, 0), c: tn * (Double(t) / 1000))
        obb(part ?? p("front"), x, true); st.picks.append(Pick(key: key, box: x))
        if handles {
            let ho = o + e * ((fw - 40) / 1000) + tn * (Double(t) / 1000) + V3(0, (hy - 64) / 1000, 0)
            obb(p("handle"), Obb(o: ho, a: e * 0.012, b: V3(0, 0.128, 0), c: tn * 0.025), false)
        }
    }

    /// A drawer front (and its box, out when open): a0 along, y0 up, the front's back face at n.
    func drawer(_ w: WallBasis, _ key: String, _ a0: Double, _ fw: Double, _ y0: Double, _ fh: Double, _ n: Double, _ dd: Double, _ handles: Bool, _ part: Part3? = nil) {
        st.keys.append(key)
        let out = dd * 0.75 * how(key)
        let nn = n + out
        let o = w.at(a0 / 1000, y0 / 1000, nn / 1000)
        let x = Obb(o: o, a: w.dir(fw / 1000, 0), b: V3(0, fh / 1000, 0), c: w.dir(0, Double(t) / 1000))
        obb(part ?? p("front"), x, true); st.picks.append(Pick(key: key, box: x))
        if out > 0 {
            let bh = max(60, min(fh - 40, 150)), bx0 = a0 + 26, bx1 = a0 + fw - 26, by = y0 + 20
            let c = p("carcass")
            box(w, c, bx0, bx1, by, by + 12, nn - dd + 40, nn)
            box(w, c, bx0, bx0 + 12, by, by + bh, nn - dd + 40, nn); box(w, c, bx1 - 12, bx1, by, by + bh, nn - dd + 40, nn)
            box(w, c, bx0, bx1, by, by + bh, nn - dd + 40, nn - dd + 52)
        }
        if handles {
            let hc = a0 + fw / 2
            obb(p("handle"), Obb(o: w.at((hc - 64) / 1000, (y0 + fh - min(40, fh / 3)) / 1000, (nn + Double(t)) / 1000), a: w.dir(0.128, 0), b: V3(0, 0.012, 0), c: w.dir(0, 0.025)), false)
        }
    }

    /// A kitchen unit: base, wall or tall carcass with its fronts; appliance spaces and fillers.
    func kitchenUnit(_ w: WallBasis, _ m: Module) {
        let x0 = d(m.x), x1 = x0 + d(m.w), y0 = d(m.elev), y1 = y0 + d(m.h), dd = d(m.d), T = d(t)
        let carcass = p("carcass"), front = p("front"), metal = p("metal"), handle = p("handle")
        switch m.type {
        // a strip of front board flush with the row's fronts
        case "filler": let fn = d(isUpper(m) ? K_WALL_D : K_BASE_D); box(w, front, x0, x1, y0, y1, fn, fn + T, true); return
        case "gap":
            switch m.app {
            case "fridge":
                box(w, p("white"), x0 + 5, x1 - 5, 0, d(m.h), 0, dd, true)
                let split = d(m.h) * 0.64
                box(w, metal, x0 + 5, x1 - 5, split - 4, split + 4, dd, dd + 2)
                box(w, handle, x0 + 30, x0 + 42, split + 120, split + 420, dd, dd + 25); box(w, handle, x0 + 30, x0 + 42, split - 420, split - 120, dd, dd + 25)
            case "dishwasher":
                box(w, metal, x0 + 3, x1 - 3, y0, y1 - 10, 0, dd - 20)
                if let (fh, fw) = frontSizes(m.fronts, m.w, m.h, ws).first {
                    box(w, front, x0 + edge, x0 + edge + d(fw), y0 + edge, y0 + edge + d(fh), dd, dd + T, true)
                    if m.handles { box(w, handle, x0 + d(m.w) / 2 - 64, x0 + d(m.w) / 2 + 64, y0 + edge + d(fh) - 46, y0 + edge + d(fh) - 34, dd + T, dd + T + 25) }
                }
            default: break
            }
            return
        default: break
        }
        // the carcass: sides, bottom, top (two rails on base units), back, shelves
        box(w, carcass, x0, x0 + T, y0, y1, 0, dd, true); box(w, carcass, x1 - T, x1, y0, y1, 0, dd, true)
        box(w, carcass, x0 + T, x1 - T, y0, y0 + T, 0, dd, true)
        if m.type == "base" { box(w, carcass, x0 + T, x1 - T, y1 - T, y1, dd - 100, dd, true); box(w, carcass, x0 + T, x1 - T, y1 - T, y1, 0, 100, true) }
        else { box(w, carcass, x0 + T, x1 - T, y1 - T, y1, 0, dd, true) }
        // the back sits in grooves between the sides, the bottom and the top (Parts backPanel)
        box(w, p("back"), x0 + T, x1 - T, y0 + T, y1 - T, 0, 3)
        let shelves = m.inserts.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty }
        if m.fronts.kind != "drawer" && shelves > 0 {
            for k in 1...shelves { let y = y0 + (d(m.h) - T) * Double(k) / Double(shelves + 1); box(w, carcass, x0 + T, x1 - T, y, y + T, 20, dd - 20, true) }
        }
        // a plinth under base and tall units on legs
        if m.legs && m.type != "wall" && y0 > 0 { box(w, metal, x0, x1, 0, y0 - 2, dd - 70, dd - 54) }
        // fronts
        let fs = frontSizes(m.fronts, m.w, m.h, ws)
        // an oven housing: the oven in its niche (800 to 1395 from the floor), a door under it and one over it
        let ovenNiche = m.app == "oven" && m.fronts.kind == "door" && fs.count == 1
        switch m.fronts.kind {
        case "door" where ovenNiche:
            let fw = d(fs[0].1), lo = 800 - g / 2 - (y0 + edge), y2 = 1395 + g / 2
            door(w, "\(m.id):f0", x0 + edge, dd, y0 + edge, lo, fw, 1, m.handles, lo - 90)
            door(w, "\(m.id):f1", x0 + edge, dd, y2, y1 - edge - y2, fw, 1, m.handles, 90)
        case "door":
            for (j, (fh, fw)) in fs.enumerated() {
                let a = x0 + edge + Double(j) * (d(fw) + g)
                // single doors hinge on the left; pairs on the outer edges
                let right = fs.count == 2 && j == 1
                // handles near the top of a low door, near the bottom of a wall unit's, at 1 m on a tall one
                let hy = m.type == "wall" ? 90 : fh > 1200 ? min(max(1000 - y0, 150), d(fh) - 150) : d(fh) - 90
                door(w, "\(m.id):f\(j)", right ? a + d(fw) : a, dd, y0 + edge, d(fh), d(fw), right ? -1 : 1, m.handles, hy)
            }
        case "drawer", "panel":
            var y = y1 - edge
            for (j, (fh, fw)) in fs.enumerated() {
                y -= d(fh)
                if m.fronts.kind == "drawer" { drawer(w, "\(m.id):f\(j)", x0 + edge, d(fw), y, d(fh), dd, dd, m.handles) }
                else { box(w, front, x0 + edge, x0 + edge + d(fw), y, y + d(fh), dd, dd + T, true) }
                y -= g
            }
        default: break
        }
        // what shows the appliance
        let cx = (x0 + x1) / 2, wt = d(worktopTop(ws)), dark = p("dark")
        switch m.app {
        case "sink":
            box(w, metal, cx - d(m.w) * 0.36, cx + d(m.w) * 0.36, wt, wt + 2, 80, 520)
            box(w, metal, cx - 15, cx + 15, wt, wt + 300, 40, 70); box(w, metal, cx - 12, cx + 12, wt + 280, wt + 300, 70, 260)
        case "hob":
            box(w, dark, cx - 290, cx + 290, wt, wt + 6, 40, 560)
            for (dx, dn) in [(-140.0, 160.0), (140.0, 160.0), (-140.0, 420.0), (140.0, 420.0)] { box(w, metal, cx + dx - 45, cx + dx + 45, wt + 6, wt + 9, dn - 45, dn + 45) }
        case "oven" where ovenNiche:
            box(w, dark, x0 + edge, x1 - edge, 800 + g / 2, 1395 - g / 2, dd, dd + T, true)
            box(w, metal, x0 + edge + 40, x1 - edge - 40, 1395 - 60, 1395 - 48, dd + T, dd + T + 25)
        case "oven": box(w, dark, x0 + edge + 20, x1 - edge - 20, 800, 1380, dd + T, dd + T + 2)
        case "micro": box(w, dark, x0 + T + 10, x0 + d(m.w) * 0.72, y0 + T, y0 + T + 290, 40, dd - 10, true)
        case "hood": box(w, metal, x0 + 10, x1 - 10, y0 - 60, y0, 30, dd + 40, true)
        default: break
        }
    }

    /// A wardrobe: sides (none at a wall), top and bottom, plinth, dividers, backs, inside, doors.
    /// A vanity's basin on its top, the tap behind it.
    func basin(_ w: WallBasis, _ m: Module) {
        let top = Double(legsOf(m, ws) + m.h)
        let mid = Double(m.x) + Double(m.w) / 2, bw = min(500, Double(m.w) - 120), bd = min(380, Double(m.d) - 80)
        guard bw >= 200, bd >= 200 else { return }
        let n0 = (Double(m.d) - bd) / 2 + 20
        let white = p("white"), metal = p("metal")
        box(w, white, mid - bw / 2, mid + bw / 2, top, top + 130, n0, n0 + bd, true)
        box(w, metal, mid - 15, mid + 15, top, top + 230, n0 - 45, n0 - 15, true)
        box(w, metal, mid - 12, mid + 12, top + 200, top + 225, n0 - 15, n0 + 90, true)
    }

    func wardrobe(_ w: WallBasis, _ m: Module) {
        let x0 = d(m.x), x1 = x0 + d(m.w), dd = d(m.d), T = d(t)
        // sliding doors take the front of the depth: the inside is shallower
        let di = d(innerD(m))
        let z0 = d(legsOf(m, ws))
        let base = d(wardBase(m))
        let yb = z0 + base, yt = z0 + d(m.h)
        let sl = m.sideL ? T : 0, sr = m.sideR ? T : 0
        let carcass = p("carcass"), metal = p("metal")
        if m.sideL { box(w, carcass, x0, x0 + T, z0, yt, 0, dd, true) }
        if m.sideR { box(w, carcass, x1 - T, x1, z0, yt, 0, dd, true) }
        // the bottom under every section but a desk's knee space
        if !m.sections.contains(where: \.knee) { box(w, carcass, x0 + sl, x1 - sr, yb, yb + T, 0, dd, true) }
        else {
            var a = x0
            for s in m.sections { if !s.knee { box(w, carcass, max(a, x0 + sl), min(a + d(s.w), x1 - sr), yb, yb + T, 0, dd, true) }; a += d(s.w) }
        }
        box(w, carcass, x0 + sl, x1 - sr, yt - T, yt, 0, dd, true)
        if !m.legs { box(w, carcass, x0 + sl, x1 - sr, 0, base, dd - 60, dd - 44, true) }
        else {
            // on legs: a pair under each side and each divider, as the hardware list counts them
            var xs = [x0 + 20], a = x0
            for s in m.sections.dropLast() { a += d(s.w); xs.append(a - 18) }
            xs.append(x1 - 56)
            for q in xs { box(w, metal, q, q + 36, 0, z0, 40, 76); box(w, metal, q, q + 36, 0, z0, dd - 76, dd - 40) }
        }
        var acc = x0
        let secs = m.sections
        for (i, s) in secs.enumerated() {
            let a0 = acc, a1 = acc + d(s.w)
            if i > 0 {
                // beside a knee space the divider stands on the floor (or the legs) like a side
                let toFloor = s.knee || secs[i - 1].knee
                box(w, carcass, a0 - T / 2, a0 + T / 2, toFloor ? z0 : yb + T, yt - T, 0, toFloor ? dd : di, true)
            }
            if s.knee { acc = a1; continue }
            let iw = d(wardInner(m, secs, i, t))
            let il = i == 0 ? a0 + sl : a0 + T / 2
            // the back sits in grooves between the sides (or dividers), the bottom and the top
            box(w, p("back"), il, il + iw, yb + T, yt - T, 0, 3)
            let floor = yb + T
            for x in s.inserts {
                let y = floor + d(x.pos)
                switch x.kind {
                case "shelf": box(w, carcass, il, il + iw, y, y + T, 3, di - 17, true)
                case "rail": box(w, metal, il + 5, il + iw - 5, y - 12, y + 12, di / 2 - 12, di / 2 + 12)
                case "lift":
                    box(w, metal, il + 20, il + iw - 20, y + 30, y + 54, di / 2 - 12, di / 2 + 12)
                    box(w, metal, il + 5, il + 25, y + 54, y + d(blockH(x)), di / 2 - 15, di / 2 + 15)
                case "drawer":
                    // in an open section the drawer's face is seen: front board, flush with the carcass, with a handle
                    if s.fronts.kind == "open" { drawer(w, "\(m.id):s\(i):d\(x.pos)", il + 2, iw - 4, y, d(blockH(x)), di - T, di - 60, m.handles, p("front")) }
                    else { drawer(w, "\(m.id):s\(i):d\(x.pos)", il + 4, iw - 8, y, d(blockH(x)), di - 40 - T, di - 60, m.handles, carcass) }
                default:
                    // trouser and shoe racks: a frame that pulls out
                    let key = "\(m.id):s\(i):r\(x.pos)"
                    st.keys.append(key)
                    // within the inside's depth: in a sliding wardrobe the doors run in front of it
                    let out = di * 0.7 * how(key)
                    let h = d(blockH(x))
                    let o = w.at((il + 13) / 1000, y / 1000, (20 + out) / 1000)
                    let bx = Obb(o: o, a: w.dir((iw - 26) / 1000, 0), b: V3(0, h / 1000, 0), c: w.dir(0, (di - 60) / 1000))
                    obbEdges(edges, bx); st.picks.append(Pick(key: key, box: bx))
                    box(w, metal, il + 13, il + iw - 13, y, y + 10, 20 + out, di - 40 + out)
                    for k in 1...4 {
                        let yy = x.kind == "shoe" ? y + h * Double(k) / 5 : y + h - 12
                        let nn = 20 + out + (di - 60) * Double(k) / 5
                        box(w, metal, il + 13, il + iw - 13, yy, yy + 8, nn - 6, nn)
                    }
                }
            }
            // the section's doors over its width, from the bottom panel up
            let fs = frontSizes(s.fronts, s.w, m.h - wardBase(m), ws)
            if s.fronts.kind == "door" && m.slide == nil {
                for (j, (fh, fw)) in fs.enumerated() {
                    let a = a0 + edge + Double(j) * (d(fw) + g)
                    // a pair hinges on its outer edges; single doors pair up two by two, the last one hinged on the wardrobe's end
                    let right = fs.count == 2 ? j == 1 : hingeRight(m, i)
                    door(w, "\(m.id):s\(i):f\(j)", right ? a + d(fw) : a, dd, yb + edge, d(fh), d(fw), right ? -1 : 1, m.handles,
                         min(max(1000 - yb, 150), d(fh) - 150))
                }
            }
            acc = a1
        }
        if let sd = m.slide { slidingDoors(w, m, sd, x0 + sl, yb + T, dd) }
    }

    /// Sliding doors: n in two tracks at the front, each overlapping the next; a frame of profiles round its filling
    /// (board, mirror or glass). A tapped door slides over its neighbour.
    func slidingDoors(_ w: WallBasis, _ m: Module, _ sl: Slide, _ ax: Double, _ y0: Double, _ dd: Double) {
        let n = min(4, max(2, sl.n))
        let (dwi, dhi) = slideDoor(m, t)
        let dw = d(dwi), dh = d(dhi)
        let step = d(dwi - SLIDE_OV)
        let metal = p("metal")
        for j in 0..<n {
            let key = "\(m.id):slide\(j)"
            st.keys.append(key)
            // a door slides one step towards the middle: the last one left, the others right
            let shift = (j == n - 1 ? -step : step) * how(key)
            let a = ax + Double(j) * step + shift
            let n0 = dd - 95 + Double(j % 2) * 45, n1 = n0 + 22
            let y = y0 + d(SLIDE_CLEAR) / 2
            let fill: Part3
            switch sl.panel(j) { case "mirror": fill = p("mirror"); case "glass": fill = p("glass"); default: fill = p("front") }
            let fw = d(SLIDE_FRAME_W), fh = d(SLIDE_FRAME_H) / 2
            box(w, fill, a + fw, a + dw - fw, y + fh, y + dh - fh, n0 + 6, n1 - 6, true)
            // the frame: two uprights, the top and the bottom
            box(w, metal, a, a + fw, y, y + dh, n0, n1, true); box(w, metal, a + dw - fw, a + dw, y, y + dh, n0, n1, true)
            box(w, metal, a + fw, a + dw - fw, y, y + fh, n0, n1, true); box(w, metal, a + fw, a + dw - fw, y + dh - fh, y + dh, n0, n1, true)
            let o = w.at(a / 1000, y / 1000, n0 / 1000)
            st.picks.append(Pick(key: key, box: Obb(o: o, a: w.dir(dw / 1000, 0), b: V3(0, dh / 1000, 0), c: w.dir(0, (n1 - n0) / 1000))))
        }
    }
}
