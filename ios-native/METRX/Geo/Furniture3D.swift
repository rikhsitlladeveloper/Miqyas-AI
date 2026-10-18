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

/// The furniture fs of a room whose walls are bases. rgb gives a material's colour; open holds the keys of open doors
/// and drawers.
func furniture3D(_ fs: [Furniture], _ bases: [String: WallBasis], _ ws: Workshop, _ rgb: (String) -> Int, _ open: Set<String>) -> Furn3D {
    let st = FStore()
    for f in fs {
        let colors = ["carcass": rgb(f.mats.carcass), "front": rgb(f.mats.front), "back": rgb(f.mats.back), "top": rgb("wt38"),
                      "metal": METAL, "dark": DARK, "handle": HANDLE, "white": WHITE]
        let B = FBuilder(ws, colors, st, open)
        let lens = { (id: String) in bases[id].map { Int(($0.len * 1000).rounded(.towardZero)) } }
        // the island (or peninsula) stands 900 mm out from the front of the first wall's units, its fronts facing them
        let island: WallBasis? = f.walls.first { $0 != ISLAND }.flatMap { bases[$0] }.map { w in
            let r = runsOf(f, lens).first { $0.wall == ISLAND }
            let len = r.map { fillOf(f, $0, false).used } ?? 0
            let s = (w.len - Double(len) / 1000) / 2
            let back = Double(K_BASE_D + 900 + K_BASE_D) / 1000
            let o = w.at(s + Double(len) / 1000, 0, back)
            return WallBasis(ox: o.x, oz: o.z, ux: -w.ux, uz: -w.uz, nx: -w.nx, nz: -w.nz, len: Double(len) / 1000)
        }
        for m in f.modules {
            guard let b = m.wall == ISLAND ? island : bases[m.wall ?? ""] else { continue }
            B.wall = m.wall
            if m.type == "wardrobe" { B.wardrobe(b, m) } else { B.kitchenUnit(b, m) }
        }
        // the worktop over the lower row of each wall (and over the corner it turns into)
        if f.kind == "kitchen" {
            let wt = worktopTop(ws)
            for r in runsOf(f, lens) {
                guard let b = r.wall == ISLAND ? island : bases[r.wall] else { continue }
                B.wall = r.wall
                let low = f.modules.filter { $0.wall == r.wall && !isUpper($0) && ($0.type == "base" || $0.type == "filler" || $0.app == "dishwasher") }
                for m in low { B.box(b, B.p("top"), m.x, m.x + m.w, wt - K_TOP, wt, 0, 600, true) }
                if r.lowStart > 0 && !low.isEmpty { B.box(b, B.p("top"), 0, r.lowStart, wt - K_TOP, wt, 0, 600, true) }
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
    let ws: Workshop, colors: [String: Int], st: FStore, open: Set<String>
    /// The wall being furnished: the furniture on a wall that faces the camera goes see-through with it (an island's
    /// never does).
    var wall: String? = nil
    let t: Int, g: Double, edge: Double
    init(_ ws: Workshop, _ colors: [String: Int], _ st: FStore, _ open: Set<String>) {
        self.ws = ws; self.colors = colors; self.st = st; self.open = open
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
        let e = Edges3(0, w); st.edges[w] = e; st.edgeOrder.append(w); return e
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
        let th = open.contains(key) ? OPEN_DEG * .pi / 180 : 0
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
        let out = open.contains(key) ? dd * 0.75 : 0
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
        case "filler": box(w, front, x0, x1, y0, y1, dd - 20, dd, true); return
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
        box(w, p("back"), x0 + 2, x1 - 2, y0 + 2, y1 - 2, 0, 3)
        let shelves = m.inserts.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty }
        if m.fronts.kind != "drawer" && shelves > 0 {
            for k in 1...shelves { let y = y0 + (d(m.h) - T) * Double(k) / Double(shelves + 1); box(w, carcass, x0 + T, x1 - T, y, y + T, 20, dd - 20, true) }
        }
        // a plinth under base and tall units on legs
        if m.legs && m.type != "wall" && y0 > 0 { box(w, metal, x0, x1, 0, y0 - 2, dd - 70, dd - 54) }
        // fronts
        let fs = frontSizes(m.fronts, m.w, m.h, ws)
        switch m.fronts.kind {
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
            box(w, metal, cx - d(m.w) * 0.36, cx + d(m.w) * 0.36, wt - 1, wt + 1, 80, 520)
            box(w, metal, cx - 15, cx + 15, wt, wt + 300, 40, 70); box(w, metal, cx - 12, cx + 12, wt + 280, wt + 300, 70, 260)
        case "hob":
            box(w, dark, cx - 290, cx + 290, wt, wt + 6, 40, 560)
            for (dx, dn) in [(-140.0, 160.0), (140.0, 160.0), (-140.0, 420.0), (140.0, 420.0)] { box(w, metal, cx + dx - 45, cx + dx + 45, wt + 6, wt + 9, dn - 45, dn + 45) }
        case "oven": box(w, dark, x0 + edge + 20, x1 - edge - 20, 800, 1380, dd + T, dd + T + 2)
        case "micro": box(w, dark, x0 + T + 10, x0 + d(m.w) * 0.72, y0 + 60, y1 - 60, 40, dd - 10, true)
        case "hood": box(w, metal, x0 + 10, x1 - 10, y0 - 60, y0, 30, dd + 40, true)
        default: break
        }
    }

    /// A wardrobe: sides (none at a wall), top and bottom, plinth, dividers, backs, inside, doors.
    func wardrobe(_ w: WallBasis, _ m: Module) {
        let x0 = d(m.x), x1 = x0 + d(m.w), dd = d(m.d), T = d(t)
        let z0 = m.legs ? d(ws.legH) : 0
        let base = d(wardBase(m))
        let yb = z0 + base, yt = z0 + d(m.h)
        let sl = m.sideL ? T : 0, sr = m.sideR ? T : 0
        let carcass = p("carcass"), metal = p("metal")
        if m.sideL { box(w, carcass, x0, x0 + T, z0, yt, 0, dd, true) }
        if m.sideR { box(w, carcass, x1 - T, x1, z0, yt, 0, dd, true) }
        box(w, carcass, x0 + sl, x1 - sr, yb, yb + T, 0, dd, true)
        box(w, carcass, x0 + sl, x1 - sr, yt - T, yt, 0, dd, true)
        if !m.legs { box(w, carcass, x0 + sl, x1 - sr, 0, d(PLINTH), dd - 60, dd - 44, true) }
        var acc = x0
        let secs = m.sections
        for (i, s) in secs.enumerated() {
            let a0 = acc, a1 = acc + d(s.w)
            if i > 0 { box(w, carcass, a0 - T / 2, a0 + T / 2, yb + T, yt - T, 0, dd, true) }
            let iw = d(wardInner(m, secs, i, t))
            let il = i == 0 ? a0 + sl : a0 + T / 2
            box(w, p("back"), a0 + 2, a1 - 2, yb + 2, yt - 2, 0, 3)
            let floor = yb + T
            for x in s.inserts {
                let y = floor + d(x.pos)
                switch x.kind {
                case "shelf": box(w, carcass, il, il + iw, y, y + T, 0, dd - 20, true)
                case "rail": box(w, metal, il + 5, il + iw - 5, y - 12, y + 12, dd / 2 - 12, dd / 2 + 12)
                case "lift":
                    box(w, metal, il + 20, il + iw - 20, y + 30, y + 54, dd / 2 - 12, dd / 2 + 12)
                    box(w, metal, il + 5, il + 25, y + 54, y + d(blockH(x)), dd / 2 - 15, dd / 2 + 15)
                case "drawer": drawer(w, "\(m.id):s\(i):d\(x.pos)", il + 4, iw - 8, y, d(blockH(x)), dd - 40 - T, dd - 60, m.handles, carcass)
                default:
                    // trouser and shoe racks: a frame that pulls out
                    let key = "\(m.id):s\(i):r\(x.pos)"
                    st.keys.append(key)
                    let out = open.contains(key) ? dd * 0.7 : 0
                    let h = d(blockH(x))
                    let o = w.at((il + 13) / 1000, y / 1000, (20 + out) / 1000)
                    let bx = Obb(o: o, a: w.dir((iw - 26) / 1000, 0), b: V3(0, h / 1000, 0), c: w.dir(0, (dd - 60) / 1000))
                    obbEdges(edges, bx); st.picks.append(Pick(key: key, box: bx))
                    box(w, metal, il + 13, il + iw - 13, y, y + 10, 20 + out, dd - 40 + out)
                    for k in 1...4 {
                        let yy = x.kind == "shoe" ? y + h * Double(k) / 5 : y + h - 12
                        let nn = 20 + out + (dd - 60) * Double(k) / 5
                        box(w, metal, il + 13, il + iw - 13, yy, yy + 8, nn - 6, nn)
                    }
                }
            }
            // the section's doors over its width, from the bottom panel up
            let fs = frontSizes(s.fronts, s.w, m.h - wardBase(m), ws)
            if s.fronts.kind == "door" {
                for (j, (fh, fw)) in fs.enumerated() {
                    let a = a0 + edge + Double(j) * (d(fw) + g)
                    let right = fs.count == 2 ? j == 1 : i % 2 == 1
                    door(w, "\(m.id):s\(i):f\(j)", right ? a + d(fw) : a, dd, yb + edge, d(fh), d(fw), right ? -1 : 1, m.handles,
                         min(max(1000 - yb, 150), d(fh) - 150))
                }
            }
            acc = a1
        }
    }
}
