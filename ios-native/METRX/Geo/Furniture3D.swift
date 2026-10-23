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
/// A door with a wall, another piece or a door beside its hinge stops at a right angle, not swinging into it.
private let SHUT_DEG = 90.0
private let MIRROR = 0xC9D3DD
private let GLASS_P = 0x8FA9C4
/// A vitrina's clear glass, seen through; a bed's mattress and slats; an LED strip's light.
private let CLEAR = 0xBFD8E8
private let MATTRESS = 0xF1F3F6
private let LAMEL = 0xD9C29A
private let LED = 0xFFF3C4

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

/// A door handle's middle at v above the bottom of a door fh tall, kept 150 from its ends (the middle of a short door).
private func handleAt(_ v: Double, _ fh: Double) -> Double {
    let lo = min(150, fh / 2), hi = max(fh / 2, fh - 150)
    return min(max(v, lo), hi)
}

/// The frame of a piece standing at p (Pose: along and out from wall p.ref, turned): len m long.
func poseBasis(_ w: WallBasis, _ p: Pose, _ len: Double) -> WallBasis {
    let o = w.at(Double(p.a) / 1000, 0, Double(p.n) / 1000)
    let r = Double(p.deg) * .pi / 180, c = cos(r), s = sin(r)
    // turned about the vertical: along u·c + n·s, into the room n·c − u·s
    return WallBasis(ox: o.x, oz: o.z, ux: w.ux * c + w.nx * s, uz: w.uz * c + w.nz * s, nx: w.nx * c - w.ux * s, nz: w.nz * c - w.uz * s, len: len)
}

/// What to light up (parts list → 3D, bazis ideas 23 Oct 2026): boards of role `role` named key (Parts.swift) in the
/// modules or sections mods, each "pieceId|module" as Parts.swift names them (a section "id/2").
struct PartHi: Equatable {
    let key: String, role: String, mods: Set<String>
    init(_ key: String, _ role: String, _ mods: Set<String>) { self.key = key; self.role = role; self.mods = mods }
}

/// The part names the 3D knows its boards by; the others light up every board of their role in their module.
private let PART_TAGGED: Set<String> = ["fp.side", "fp.top", "fp.bottom", "fp.divider", "fp.shelf", "fp.back", "fp.door", "fp.dFace", "fp.rail", "fp.plinth",
                                        "fp.panel", "fp.filler", "fp.slidePanel", "fp.dSide", "fp.dFront", "fp.dBottom"]
private let HI_PART = 0xF59E0B

/// A handle's length along its door or drawer, mm: the piece's handle type (a knob, a long bar, the usual 128 skoba).
func handleLen(_ id: String) -> Int {
    switch id {
    case "handleKnob": return 24
    case "handleLong": return 320
    default: return 128
    }
}

/// The furniture fs of a room whose walls are bases. rgb gives a material's colour; open holds the keys of open doors
/// and drawers, or amt says how far each one is open, 0 to 1 (moving between the two while it opens or shuts).
/// bare: "See inside", no doors, drawer fronts or sliding doors (the drawers' boxes stay, shut); hi a part lit up.
func furniture3D(_ fs: [Furniture], _ bases: [String: WallBasis], _ ws: Workshop, _ rgb: (String) -> Int, _ open: Set<String>,
                 amt: ((String) -> Double)? = nil, bare: Bool = false, hi: PartHi? = nil) -> Furn3D {
    let how: (String) -> Double = amt ?? { k in open.contains(k) ? 1 : 0 }
    let st = FStore()
    for f in fs {
        let colors = ["carcass": rgb(f.mats.carcass), "front": rgb(f.mats.front), "back": rgb(f.mats.back), "top": rgb("wt38"),
                      "mirror": MIRROR, "glass": GLASS_P, "splash": rgb("splash6"),
                      "metal": METAL, "dark": DARK, "handle": HANDLE, "white": WHITE,
                      "clear": CLEAR, "mattress": MATTRESS, "lamel": LAMEL, "led": LED, "hi": HI_PART]
        let fws = wsOf(f, ws)
        let B = FBuilder(fws, colors, st, how)
        B.bare = bare; B.hi = hi; B.piece = f.id; B.hLen = Double(handleLen(f.handle))
        let lens = { (id: String) in bases[id].map { Int(($0.len * 1000).rounded(.towardZero)) } }
        // the island (or peninsula) stands where it was dragged, else 900 mm out from the front of the first wall's
        // units, its fronts facing them
        let island: WallBasis? = f.walls.first { $0 != ISLAND }.flatMap { bases[$0] }.map { w in
            let r = runsOf(f, lens).first { $0.wall == ISLAND }
            let len = r.map { fillOf(f, $0, false).used } ?? 0
            let p = f.kind == "kitchen" ? f.pose ?? islandPose(f, Int((w.len * 1000).rounded())) : islandPose(f, Int((w.len * 1000).rounded()))
            return poseBasis(bases[p.ref] ?? w, p, Double(len) / 1000)
        }
        let mainX: Int? = wardOfF(f)?.x
        for m in f.modules {
            // a piece standing free (a desk, a bed in the middle of the room) has its own frame from its main box's start
            let box = isBox(m)
            let free: WallBasis? = f.kind == "wardrobe" && box ? f.pose.flatMap { p in bases[p.ref].map { poseBasis($0, p, Double(m.w) / 1000) } } : nil
            guard let b = free ?? (m.wall == ISLAND ? island : bases[m.wall ?? ""]) else { continue }
            var mm = m
            if free != nil { mm.x = m.x - (mainX ?? m.x) }
            B.wall = m.wall
            B.mod = m.label.isEmpty ? m.id : m.label; B.sec = ""
            if m.type == "wardrobe" {
                // what stands past each end along its wall: the wall's corner, or another box close by (of another piece or this one)
                let L = bases[m.wall ?? ""].map { Int($0.len * 1000) }
                func near(_ at: Int) -> Bool {
                    for o in fs where o.pose == nil {
                        for x in o.modules where x.id != m.id && x.wall == m.wall {
                            if o.id == f.id && hung(x) { continue }
                            if abs(x.x + x.w - at) < 60 || abs(x.x - at) < 60 { return true }
                        }
                    }
                    return false
                }
                let edgeL = m.x > W_GAP_SIDE + 40 && !near(m.x)
                var edgeR = false
                if let L { edgeR = m.x + m.w < L - W_GAP_SIDE - 40 && !near(m.x + m.w) }
                B.freeL = free != nil || edgeL
                B.freeR = free != nil || edgeR
                B.wardrobe(b, mm)
                // a bathroom vanity carries its basin and tap on top
                if f.type == "sinkV" { B.basin(b, mm) }
            } else if ITEM_MODS.contains(m.type) { B.item(b, mm) }
            else { B.kitchenUnit(b, m) }
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
                // side's. An island's (a peninsula's) covers its cabinets and its finished back, no more.
                let n0 = isl ? -PEN_BACK : 0
                var a0 = -1, a1 = -1
                func piece() {
                    guard a1 > a0 else { return }
                    B.box(b, B.p("top"), a0, a1, wt - K_TOP, wt, n0, 600, true)
                    if isl { B.box(b, B.role("front"), a0, a1, 0, wt - K_TOP, -18, 0, true) }
                }
                for m in low { if a0 >= 0 && m.x <= a1 + 1 { a1 = max(a1, m.x + m.w) } else { piece(); a0 = m.x; a1 = m.x + m.w } }
                // a peninsula in its usual place: the side's worktop runs on over the peninsula's finished back to its outer edge
                if f.layout == "P" && f.pose == nil && r.wall == f.walls.first(where: { $0 != ISLAND }) && a1 > a0 { a1 += PEN_BACK }
                piece()
                // end panels where a row ends in the open room (not against a wall): the lower row's, the wall units'
                if let kx0 = f.kx, let lo = low.first?.x, let hi = low.map({ $0.x + $0.w }).max() {
                    let wl: Int? = isl ? nil : Int((b.len * 1000).rounded())
                    // a peninsula's side ends at the peninsula, which covers it: no end panel there
                    let penSide = f.layout == "P" && r.wall == f.walls.first { $0 != ISLAND }
                    let hiOpen = (wl.map { hi < $0 - 20 } ?? false) && !penSide
                    let ends: [(Int, Bool)] = isl ? [(lo, f.layout != "P"), (hi, true)] : [(lo, lo > 20), (hi, hiOpen)]
                    if kx0.ends > 0 { for (a, open) in ends where open { B.box(b, B.role("front"), a == lo ? a - 18 : a, a == lo ? a : a + 18, 0, wt - K_TOP, 0, 600, true) } }
                    let up = f.modules.filter { $0.wall == r.wall && $0.type == "wall" }
                    if kx0.endsUp > 0, let wl, let u0 = up.map(\.x).min(), let u1 = up.map({ $0.x + $0.w }).max() {
                        let y0 = up.map(\.elev).min() ?? 0, y1 = up.map { $0.elev + $0.h }.max() ?? 0, dd = up.map(\.d).max() ?? 300
                        if u0 > 20 { B.box(b, B.role("front"), u0 - 18, u0, y0, y1, 0, dd, true) }
                        if u1 < wl - 20 { B.box(b, B.role("front"), u1, u1 + 18, y0, y1, 0, dd, true) }
                    }
                }
                // extras: the backsplash panel on the wall over the worktop, the cornice on the wall units
                if let kx = f.kx, r.wall != ISLAND {
                    let a0 = r.lowStart > 0 ? 0 : low.map(\.x).min() ?? 0
                    let a1 = low.map { $0.x + $0.w }.max() ?? 0
                    if kx.splash > 0 && a1 > a0 { B.box(b, B.p("splash"), a0, a1, wt, wt + kx.splash, 0, 6, true) }
                    if kx.cornice {
                        for m in f.modules where m.wall == r.wall && m.type == "wall" {
                            B.box(b, B.role("front"), m.x, m.x + m.w, m.elev + m.h, m.elev + m.h + 60, 0, m.d + 30, true)
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
    /// The piece being built has nothing past its left / right end (no wall, no neighbour): a door hinged there opens wide.
    var freeL = false
    var freeR = false
    /// See inside (no fronts); what to light up; the piece and module (and section) being built, as Parts.swift names
    /// them; the handles' length.
    var bare = false
    var hi: PartHi? = nil
    var piece = "", mod = "", sec = ""
    var hLen = 128.0
    let t: Int, g: Double, edge: Double
    init(_ ws: Workshop, _ colors: [String: Int], _ st: FStore, _ how: @escaping (String) -> Double) {
        self.ws = ws; self.colors = colors; self.st = st; self.how = how
        t = ws.t; g = Double(ws.gap10) / 10; edge = Double(ws.edge10) / 10
    }

    func p(_ k: String) -> Part3 {
        let c = colors[k]!, w = wall == ISLAND ? nil : wall
        // the worktop is a part of its own (even in the fronts' colour): its top and outline are drawn as a slab
        if k == "top" {
            let tk = FStore.K(wall: "top|" + (w ?? ""), rgb: c)
            if let x = st.parts[tk] { return x }
            let x = Part3(0, w, .furn, c, 1, slab: true); st.parts[tk] = x; st.order.append(tk); return x
        }
        let key = FStore.K(wall: w, rgb: c)
        if let x = st.parts[key] { return x }
        // clear glass is seen through
        let x = Part3(0, w, .furn, c, k == "clear" ? 0.38 : 1); st.parts[key] = x; st.order.append(key); return x
    }
    /// Board k of role r (carcass, front, back) being drawn: in the highlight's colour when it is the part asked for.
    func role(_ r: String, _ k: String = "") -> Part3 {
        guard let h = hi else { return p(r) }
        let here = piece + "|" + mod
        let inMod = h.mods.contains(here) || (!sec.isEmpty && h.mods.contains(here + "/" + sec))
        let dBox = h.key == "fp.dSide" || h.key == "fp.dFront" || h.key == "fp.dBottom"
        let named = !PART_TAGGED.contains(h.key) || k == h.key || (dBox && k == "fp.dBox")
        if inMod && named && (h.role == r || dBox) { return p("hi") }
        return p(r)
    }

    var edges: Edges3 {
        let w = wall == ISLAND ? "island" : (wall ?? "island")
        if let e = st.edges[w] { return e }
        // named apart from the wall's own outline, so it does not fade with a see-through wall
        let e = Edges3(0, "furn " + w); st.edges[w] = e; st.edgeOrder.append(w); return e
    }

    /// The worktop's light outline, kept apart from the dark one of the boards.
    var slabEdges: Edges3 {
        let w = wall == ISLAND ? "island" : (wall ?? "island")
        let k = "top|" + w
        if let e = st.edges[k] { return e }
        let e = Edges3(0, "furn " + w, rgb: SLAB_LINE); st.edges[k] = e; st.edgeOrder.append(k); return e
    }

    func obb(_ p: Part3, _ x: Obb, _ line: Bool) { obbFaces(p, x); if line { obbEdges(p.slab ? slabEdges : edges, x) } }

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
    func door(_ w: WallBasis, _ key: String, _ ha: Double, _ n: Double, _ y0: Double, _ h: Double, _ fw: Double, _ s: Double, _ handles: Bool, _ hy: Double, _ part: Part3? = nil,
              deg: Double = SHUT_DEG, face: String = "") {
        // seeing inside: no doors at all
        if bare { return }
        st.keys.append(key)
        let th = deg * .pi / 180 * how(key)
        let e = w.dir(s * cos(th), sin(th)), tn = w.dir(-s * sin(th), cos(th))
        let o = w.at(ha / 1000, y0 / 1000, n / 1000)
        let T = Double(t) / 1000
        let x = Obb(o: o, a: e * (fw / 1000), b: V3(0, h / 1000, 0), c: tn * T)
        let up = V3(0, 1, 0)
        switch face {
        case "glass":
            // glass in an aluminium frame: the frame's four sides round a clear pane
            let fr = 0.02, W = fw / 1000, H = h / 1000
            let metal = p("metal")
            obb(metal, Obb(o: o, a: e * fr, b: up * H, c: tn * T), true)
            obb(metal, Obb(o: o + e * (W - fr), a: e * fr, b: up * H, c: tn * T), true)
            obb(metal, Obb(o: o + e * fr, a: e * (W - 2 * fr), b: up * fr, c: tn * T), true)
            obb(metal, Obb(o: o + e * fr + up * (H - fr), a: e * (W - 2 * fr), b: up * fr, c: tn * T), true)
            let po: V3 = o + e * fr + up * fr + tn * (T / 2 - 0.002)
            obb(p("clear"), Obb(o: po, a: e * (W - 2 * fr), b: up * (H - 2 * fr), c: tn * 0.004), false)
        case "mirror":
            // a mirror on the board door's face
            obb(part ?? role("front", "fp.door"), x, true)
            let mo: V3 = o + e * 0.005 + up * 0.005 + tn * T
            obb(p("mirror"), Obb(o: mo, a: e * (fw / 1000 - 0.01), b: up * (h / 1000 - 0.01), c: tn * 0.004), false)
        default: obb(part ?? role("front", "fp.door"), x, true)
        }
        st.picks.append(Pick(key: key, box: x))
        if handles {
            // a knob is as wide as it is long
            let hw: Double = hLen < 60 ? hLen / 1000 : 0.012
            let lift = V3(0, (hy - hLen / 2) / 1000, 0)
            let ho: V3 = o + e * ((fw - 40) / 1000) + tn * (Double(t) / 1000) + lift
            obb(p("handle"), Obb(o: ho, a: e * hw, b: V3(0, hLen / 1000, 0), c: tn * 0.025), false)
        }
    }

    /// A drawer front (and its box, out when open): a0 along, y0 up, the front's back face at n; pr the front's role.
    func drawer(_ w: WallBasis, _ key: String, _ a0: Double, _ fw: Double, _ y0: Double, _ fh: Double, _ n: Double, _ dd: Double, _ handles: Bool, _ pr: String = "front") {
        // seeing inside: the drawer's box stays (shut), its front goes
        if !bare { st.keys.append(key) }
        let out: Double = bare ? 0 : dd * 0.75 * how(key)
        let nn = n + out
        let o = w.at(a0 / 1000, y0 / 1000, nn / 1000)
        let x = Obb(o: o, a: w.dir(fw / 1000, 0), b: V3(0, fh / 1000, 0), c: w.dir(0, Double(t) / 1000))
        if !bare { obb(role(pr, "fp.dFace"), x, true); st.picks.append(Pick(key: key, box: x)) }
        if out > 0 || bare {
            let bh = max(60, min(fh - 40, 150)), bx0 = a0 + 26, bx1 = a0 + fw - 26, by = y0 + 20
            let c = role("carcass", "fp.dBox")
            box(w, c, bx0, bx1, by, by + 12, nn - dd + 40, nn)
            box(w, c, bx0, bx0 + 12, by, by + bh, nn - dd + 40, nn); box(w, c, bx1 - 12, bx1, by, by + bh, nn - dd + 40, nn)
            box(w, c, bx0, bx1, by, by + bh, nn - dd + 40, nn - dd + 52)
        }
        if handles && !bare {
            let hc = a0 + fw / 2
            let hh: Double = hLen < 60 ? hLen / 1000 : 0.012
            let at = w.at((hc - hLen / 2) / 1000, (y0 + fh - min(40, fh / 3)) / 1000, (nn + Double(t)) / 1000)
            obb(p("handle"), Obb(o: at, a: w.dir(hLen / 1000, 0), b: V3(0, hh, 0), c: w.dir(0, 0.025)), false)
        }
    }

    /// A kitchen unit: base, wall or tall carcass with its fronts; appliance spaces and fillers.
    func kitchenUnit(_ w: WallBasis, _ m: Module) {
        let x0 = d(m.x), x1 = x0 + d(m.w), y0 = d(m.elev), y1 = y0 + d(m.h), dd = d(m.d), T = d(t)
        let metal = p("metal"), handle = p("handle")
        switch m.type {
        // a strip of front board flush with the row's fronts
        case "filler": let fn = d(isUpper(m) ? K_WALL_D : K_BASE_D); box(w, role("front", "fp.filler"), x0, x1, y0, y1, fn, fn + T, true); return
        case "gap":
            switch m.app {
            case "fridge":
                box(w, p("white"), x0 + 5, x1 - 5, 0, d(m.h), 0, dd, true)
                let split = d(m.h) * 0.64
                box(w, metal, x0 + 5, x1 - 5, split - 4, split + 4, dd, dd + 2)
                box(w, handle, x0 + 30, x0 + 42, split + 120, split + 420, dd, dd + 25); box(w, handle, x0 + 30, x0 + 42, split - 420, split - 120, dd, dd + 25)
            case "dishwasher":
                box(w, metal, x0 + 3, x1 - 3, y0, y1 - 10, 0, dd - 20)
                if !bare, let (fh, fw) = frontSizes(m.fronts, m.w, m.h, ws).first {
                    let fp = role("front", m.fronts.kind == "panel" ? "fp.panel" : "fp.door")
                    box(w, fp, x0 + edge, x0 + edge + d(fw), y0 + edge, y0 + edge + d(fh), dd, dd + T, true)
                    if m.handles {
                        let mid = x0 + d(m.w) / 2
                        box(w, handle, mid - hLen / 2, mid + hLen / 2, y0 + edge + d(fh) - 46, y0 + edge + d(fh) - 34, dd + T, dd + T + 25)
                    }
                }
            default: break
            }
            return
        default: break
        }
        // the carcass: sides, bottom, top (two rails on base units), back, shelves
        let side = role("carcass", "fp.side")
        box(w, side, x0, x0 + T, y0, y1, 0, dd, true); box(w, side, x1 - T, x1, y0, y1, 0, dd, true)
        // a base unit's bottom is its own part; a wall or tall unit's top and bottom are one
        box(w, role("carcass", m.type == "base" ? "fp.bottom" : "fp.top"), x0 + T, x1 - T, y0, y0 + T, 0, dd, true)
        if m.type == "base" {
            let rail = role("carcass", "fp.rail")
            box(w, rail, x0 + T, x1 - T, y1 - T, y1, dd - 100, dd, true); box(w, rail, x0 + T, x1 - T, y1 - T, y1, 0, 100, true)
        }
        else { box(w, role("carcass", "fp.top"), x0 + T, x1 - T, y1 - T, y1, 0, dd, true) }
        // the back sits in grooves between the sides, the bottom and the top (Parts backPanel)
        box(w, role("back", "fp.back"), x0 + T, x1 - T, y0 + T, y1 - T, 0, 3)
        let shelves = m.inserts.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty }
        if m.fronts.kind != "drawer" && shelves > 0 {
            let shelf = role("carcass", "fp.shelf")
            for k in 1...shelves { let y = y0 + (d(m.h) - T) * Double(k) / Double(shelves + 1); box(w, shelf, x0 + T, x1 - T, y, y + T, 20, dd - 20, true) }
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
                let hy: Double = m.type == "wall" ? 90 : fh > 1200 ? handleAt(1000 - y0, d(fh)) : d(fh) - 90
                door(w, "\(m.id):f\(j)", right ? a + d(fw) : a, dd, y0 + edge, d(fh), d(fw), right ? -1 : 1, m.handles, hy)
            }
        case "drawer", "panel":
            var y = y1 - edge
            for (j, (fh, fw)) in fs.enumerated() {
                y -= d(fh)
                if m.fronts.kind == "drawer" { drawer(w, "\(m.id):f\(j)", x0 + edge, d(fw), y, d(fh), dd, dd, m.handles) }
                else if !bare { box(w, role("front", "fp.panel"), x0 + edge, x0 + edge + d(fw), y, y + d(fh), dd, dd + T, true) }
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
        // a wall-hung vanity's top is its height above the floor up
        let top = Double(m.elev + legsOf(m, ws) + m.h)
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
        // on legs, on a plinth, or hung (its bottom above the floor)
        let z0 = d(legsOf(m, ws)) + d(m.elev)
        let base = d(wardBase(m))
        let yb = z0 + base, yt = z0 + d(m.h)
        let sl = m.sideL ? T : 0, sr = m.sideR ? T : 0
        let metal = p("metal")
        if m.sideL { box(w, role("carcass", "fp.side"), x0, x0 + T, z0, yt, 0, dd, true) }
        if m.sideR { box(w, role("carcass", "fp.side"), x1 - T, x1, z0, yt, 0, dd, true) }
        // the bottom under every section but a desk's knee space (a wardrobe's top and bottom are one part, a desk's
        // bottoms their own)
        if !m.sections.contains(where: \.knee) { box(w, role("carcass", "fp.top"), x0 + sl, x1 - sr, yb, yb + T, 0, dd, true) }
        else {
            var a = x0
            let bottom = role("carcass", "fp.bottom")
            for s in m.sections { if !s.knee { box(w, bottom, max(a, x0 + sl), min(a + d(s.w), x1 - sr), yb, yb + T, 0, dd, true) }; a += d(s.w) }
        }
        box(w, role("carcass", "fp.top"), x0 + sl, x1 - sr, yt - T, yt, 0, dd, true)
        if !m.legs { box(w, role("carcass", "fp.plinth"), x0 + sl, x1 - sr, z0, z0 + base, dd - 60, dd - 44, true) }
        else {
            // on legs: a pair under each side and each divider, as the hardware list counts them
            // (none at an end without a side: a corner desk's second arm rests on the first there)
            var xs: [Double] = m.sideL ? [x0 + 20] : []
            var a = x0
            for s in m.sections.dropLast() { a += d(s.w); xs.append(a - 18) }
            if m.sideR { xs.append(x1 - 56) }
            for q in xs { box(w, metal, q, q + 36, 0, z0, 40, 76); box(w, metal, q, q + 36, 0, z0, dd - 76, dd - 40) }
        }
        var acc = x0
        let secs = m.sections
        for (i, s) in secs.enumerated() {
            let a0 = acc, a1 = acc + d(s.w)
            sec = ""
            if i > 0 {
                // beside a knee space the divider stands on the floor (or the legs) like a side
                let toFloor = s.knee || secs[i - 1].knee
                box(w, role("carcass", "fp.divider"), a0 - T / 2, a0 + T / 2, toFloor ? z0 : yb + T, yt - T, 0, toFloor ? dd : di, true)
            }
            sec = "\(i + 1)"
            if s.knee { acc = a1; continue }
            let iw = d(wardInner(m, secs, i, t))
            let il = i == 0 ? a0 + sl : a0 + T / 2
            // the back sits in grooves between the sides (or dividers), the bottom and the top
            box(w, role("back", "fp.back"), il, il + iw, yb + T, yt - T, 0, 3)
            let floor = yb + T
            for x in s.inserts {
                let y = floor + d(x.pos)
                switch x.kind {
                case "shelf": box(w, role("carcass", "fp.shelf"), il, il + iw, y, y + T, 3, di - 17, true)
                case "glass": box(w, p("clear"), il, il + iw, y, y + 6, 3, di - 17, true)
                case "rail": box(w, metal, il + 5, il + iw - 5, y - 12, y + 12, di / 2 - 12, di / 2 + 12)
                case "lift":
                    box(w, metal, il + 20, il + iw - 20, y + 30, y + 54, di / 2 - 12, di / 2 + 12)
                    box(w, metal, il + 5, il + 25, y + 54, y + d(blockH(x)), di / 2 - 15, di / 2 + 15)
                case "drawer":
                    // in an open section the drawer's face is seen: front board, flush with the carcass, with a handle
                    if s.fronts.kind == "open" { drawer(w, "\(m.id):s\(i):d\(x.pos)", il + 2, iw - 4, y, d(blockH(x)), di - T, di - 60, m.handles, "front") }
                    else { drawer(w, "\(m.id):s\(i):d\(x.pos)", il + 4, iw - 8, y, d(blockH(x)), di - 40 - T, di - 60, m.handles, "carcass") }
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
            let fs = frontSizes(s.fronts, frontW(s), m.h - wardBase(m), ws)
            if s.fronts.kind == "door" && m.slide == nil {
                for (j, (fh, fw)) in fs.enumerated() {
                    let a = a0 + edge + Double(j) * (d(fw) + g)
                    // a pair hinges on its outer edges; single doors pair up two by two, the last one hinged on the wardrobe's end
                    let right = fs.count == 2 ? j == 1 : hingeRight(m, i)
                    // only a hinge at the piece's free end opens wide; beside a divider, a wall or a neighbour it stops at 90°
                    let wide: Bool
                    if right { wide = i == secs.count - 1 && j == fs.count - 1 && freeR } else { wide = i == 0 && j == 0 && freeL }
                    let hd = m.handles && s.face != "glass"
                    door(w, "\(m.id):s\(i):f\(j)", right ? a + d(fw) : a, dd, yb + edge, d(fh), d(fw), right ? -1 : 1, hd,
                         handleAt(1000 - yb, d(fh)), deg: wide ? OPEN_DEG : SHUT_DEG, face: s.face)
                }
            }
            acc = a1
        }
        sec = ""
        // a vitrina's light along the inside of its top
        if m.led { box(w, p("led"), x0 + sl + 10, x1 - sr - 10, yt - T - 8, yt - T, di - 70, di - 50) }
        if let sd = m.slide { slidingDoors(w, m, sd, x0 + sl, yb + T, dd) }
    }

    /// A box b of an item, tilted th about a line across it at pivotY up and pivotN out (a lift-up bed's base rising).
    private func tilted(_ w: WallBasis, _ p: Part3, _ x0: Int, _ b: Board, _ pivotY: Double, _ pivotN: Double, _ th: Double, _ line: Bool) {
        let c = cos(th), s = sin(th)
        let dy = Double(b.y0) - pivotY, dn = Double(b.n0) - pivotN
        let oy = pivotY + dn * s + dy * c
        let on = pivotN + dn * c - dy * s
        let lb = Double(b.y1 - b.y0) / 1000, lc = Double(b.n1 - b.n0) / 1000
        let up = V3(0, 1, 0)
        let ea: V3 = w.dir(Double(b.a1 - b.a0) / 1000, 0)
        let eb: V3 = w.dir(0, -lb * s) + up * (lb * c)
        let ec: V3 = w.dir(0, lc * c) + up * (lc * s)
        obb(p, Obb(o: w.at(Double(x0 + b.a0) / 1000, oy / 1000, on / 1000), a: ea, b: eb, c: ec), line)
    }

    /// A table top's rounded corner (b.round): a cross of two boards and an octagon in each corner.
    private func roundTop(_ w: WallBasis, _ p: Part3, _ x0: Int, _ b: Board) {
        let r = b.round, a0 = x0 + b.a0, a1 = x0 + b.a1
        box(w, p, a0 + r, a1 - r, b.y0, b.y1, b.n0, b.n1, true); box(w, p, a0, a1, b.y0, b.y1, b.n0 + r, b.n1 - r, true)
        let up = V3(0, Double(b.y1 - b.y0) / 1000, 0)
        let R = Double(r) / 1000, q = R * 0.7071
        let cs: [(Int, Int)] = [(a0 + r, b.n0 + r), (a1 - r, b.n0 + r), (a0 + r, b.n1 - r), (a1 - r, b.n1 - r)]
        for (ca, cn) in cs {
            let c = w.at(Double(ca) / 1000, Double(b.y0) / 1000, Double(cn) / 1000)
            obb(p, Obb(o: c - w.dir(q, q), a: w.dir(2 * q, 0), b: up, c: w.dir(0, 2 * q)), false)
            obb(p, Obb(o: c - w.dir(R, 0), a: w.dir(R, -R), b: up, c: w.dir(R, R)), false)
        }
    }

    /// The part a board of an item is drawn in.
    private func itemPart(_ r: String, _ key: String) -> Part3 {
        switch r {
        case "carcass": return role("carcass", key)
        case "top": return p("top")
        case "metal": return p("metal")
        case "white": return p("white")
        case "mattress": return p("mattress")
        case "lamel": return p("lamel")
        case "mirror": return p("mirror")
        default: return role("front", key)
        }
    }

    /// A bed, a table, a bar counter, a mirror panel or a mirror: its boards (Items.swift); a bed's drawers pull out of
    /// its long sides and a lift-up base rises on a tap.
    func item(_ w: WallBasis, _ m: Module) {
        let x0 = m.x
        let bs = itemBoards(m, ws)
        let liftKey = "\(m.id):lift"
        let lifts = bs.contains { $0.lift }
        if lifts { st.keys.append(liftKey) }
        let th = 38.0 * .pi / 180 * (lifts ? how(liftKey) : 0)
        let pivotY = Double(m.h - BED_SINK - 30), pivotN = Double(t) + 4
        for b in bs {
            let part = itemPart(b.role, b.key)
            let line = !b.key.isEmpty || b.role == "mirror"
            if b.lift && th > 1e-6 { tilted(w, part, x0, b, pivotY, pivotN, th, line) }
            else if b.round > 0 { roundTop(w, part, x0, b) }
            else { box(w, part, x0 + b.a0, x0 + b.a1, b.y0, b.y1, b.n0, b.n1, line) }
        }
        if lifts, let b = bs.first(where: { $0.role == "mattress" }) {
            let o = w.at(Double(x0 + b.a0) / 1000, Double(b.y0) / 1000, Double(b.n0) / 1000)
            let bx = Obb(o: o, a: w.dir(Double(b.a1 - b.a0) / 1000, 0), b: V3(0, Double(b.y1 - b.y0) / 1000, 0), c: w.dir(0, Double(b.n1 - b.n0) / 1000))
            st.picks.append(Pick(key: liftKey, box: bx))
        }
        // a bed's drawers: each side's own frame, along the bed and out of that side
        for (i, dr) in bedDrawers(m, ws).enumerated() {
            let right = dr.side > 0
            let o = w.at(Double(x0 + (right ? m.w : 0)) / 1000, 0, Double(right ? m.d : 0) / 1000)
            let len = Double(m.d) / 1000
            let sb = right ? WallBasis(ox: o.x, oz: o.z, ux: -w.nx, uz: -w.nz, nx: w.ux, nz: w.uz, len: len)
                           : WallBasis(ox: o.x, oz: o.z, ux: w.nx, uz: w.nz, nx: -w.ux, nz: -w.uz, len: len)
            let a = right ? m.d - dr.n1 : dr.n0
            drawer(sb, "\(m.id):bd\(i)", Double(a), Double(dr.n1 - dr.n0), Double(dr.y0), Double(dr.y1 - dr.y0), -Double(t), Double(dr.depth), m.handles)
        }
    }

    /// Sliding doors: n in two tracks at the front, each overlapping the next; a frame of profiles round its filling
    /// (board, mirror or glass). A tapped door slides over its neighbour.
    func slidingDoors(_ w: WallBasis, _ m: Module, _ sl: Slide, _ ax: Double, _ y0: Double, _ dd: Double) {
        if bare { return }
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
            switch sl.panel(j) { case "mirror": fill = p("mirror"); case "glass": fill = p("glass"); default: fill = role("front", "fp.slidePanel") }
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
