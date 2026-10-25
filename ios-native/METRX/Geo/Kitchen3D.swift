import Foundation

/*
 * The modern kitchen in 3D ("modern furniture 3D" part 3, 25 Oct 2026; the approved mockup's buildKitchen, b.front,
 * b.bar, b.knob, b.handle, b.glassDoor, mats()): front styles (flat, shaker, fluted), real handles where the mockup
 * puts them, the Gola profile, the worktop of its decor with a soft front edge and a real sink cut-out with its basin
 * and tap, a LED strip with its glow on the wall, a hidden plinth or metal legs, a cornice or a row of units up to the
 * ceiling, glass doors in their frames (fluted glass), a waterfall island, nicer hob, oven, microwave and hood.
 * Round parts are prisms (12 sides, 8 on a weak phone); a weak phone skips the glow; the 2D drawings (PieceView,
 * detail .flat) get boxes only, six faces each, as before. Sizes come in millimetres (the wall's frame) or metres (a
 * front's own frame, FFrame), as the builder in Furniture3D.swift uses them.
 */

/* ---------------- rules (plain, unit-tested: Kitchen3DTests) ---------------- */

/// Where a door's handle goes: near the top of a base unit's door, near the bottom of a wall unit's, its middle at an
/// exact height above the door's bottom (a tall door's, at about 1 m from the floor), mm.
enum HPlace: Equatable { case top, bottom, at(Double) }

/// A handle on a front, mm from the front's bottom corner on its hinge side (x across towards the opening edge, y up):
/// its middle, the bar's length (0 a knob) and whether it stands upright.
struct HandleSpot: Equatable { let x: Double, y: Double, len: Double, vert: Bool }

/// The bar's length in mm that a handle of hardware id takes on a hinged door (door) or a drawer or flap, h mm tall:
/// the usual skoba 168 long (holes 128); long verticals (LONG_V) 1024 on doors from 1400, 640 from 700, else 320 (a
/// drawer 320), as PieceLook.swift longHandleIds prices them; a long handle chosen by its size that size; 0 a knob.
func handleBarLen(_ id: String, door: Bool, h: Double) -> Double {
    switch id {
    case "handleKnob": return 0
    case LONG_V: return !door ? 320 : h >= 1400 ? 1024 : h >= 700 ? 640 : 320
    case "handle1024": return 1024
    case "handle640": return 640
    case "handleLong": return 320
    default: return 168
    }
}

/// v kept within lo…hi (their middle when the room is too small).
private func k3Clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { lo > hi ? (lo + hi) / 2 : min(max(v, lo), hi) }

/// Where a handle of hardware id goes on a front w × h mm (mockup b.handle): kind "door" (hinged), "drawer" or "flap"
/// (a front lifting up, its handle at the bottom). A door's bar stands upright 34 mm in from its opening edge, 45 mm from
/// its top (place .top) or bottom (.bottom), never longer than the door less 80; a knob 42 in and 70 from the top or
/// bottom. A drawer's bar lies across its middle 50 mm under its top (a flap's 45 over its bottom), no longer than the
/// drawer less 80; a knob in its middle 60 from the top. nil: a front too small for it.
func handleSpot(_ id: String, _ kind: String, _ w: Double, _ h: Double, _ place: HPlace = .top) -> HandleSpot? {
    let e = 42.0
    let len0 = handleBarLen(id, door: kind == "door", h: h)
    if len0 == 0 {
        if kind != "door" { return HandleSpot(x: w / 2, y: kind == "flap" ? min(60, h / 2) : h - min(60, h / 2), len: 0, vert: false) }
        let y: Double
        switch place {
        case .top: y = h - 70
        case .bottom: y = 70
        case .at(let v): y = v
        }
        return HandleSpot(x: w > 2 * e ? w - e : w / 2, y: k3Clamp(y, 70, h - 70), len: 0, vert: false)
    }
    if kind != "door" {
        let L = min(len0, w - 80)
        guard L >= 40 else { return nil }
        return HandleSpot(x: w / 2, y: kind == "flap" ? min(45, h / 2) : h - min(50, h / 2), len: L, vert: false)
    }
    let L = min(len0, h - 80)
    guard L >= 40 else { return nil }
    let lo = 45 + L / 2, hi = h - 45 - L / 2
    let y: Double
    switch place {
    case .top: y = hi
    case .bottom: y = lo
    case .at(let v): y = k3Clamp(v, lo, hi)
    }
    return HandleSpot(x: w > 2 * e ? w - e * 0.8 : w / 2, y: y, len: L, vert: true)
}

/// A Gola kitchen's lower fronts end this far under their unit's top (the channel's opening), mm.
let GOLA_DROP = 34.0
/// The Gola channel's height, mm, set 2 mm behind the fronts' back face and 28 deep.
let GOLA_H = 52.0

/// The cornice's three layers over the wall units, bottom up: each one's height and how far it stands out past the
/// units' front, mm (mockup cornice(): 22 + 36 + 18).
let CORNICE_LAYERS: [(h: Double, out: Double)] = [(22, 10), (36, 26), (18, 38)]

/// The height of the row of units over a unit whose top is top mm up, to a ceiling ceil mm high (4 mm short of it);
/// 0 when no row fits (under 100 mm).
func ceilRowH(_ top: Int, _ ceil: Int) -> Int {
    let h = ceil - 4 - top
    return h >= 100 ? h : 0
}

/// The sink's cut-out in the worktop over sink unit m: along the run (a0, a1) and out from the wall (n0, n1), mm; 60 %
/// of the unit wide (at least 300, 60 mm short of each side), 380 deep from 100 off the wall (mockup: 480 × 380 in an
/// 800 unit; as Android).
func sinkHole(_ m: Module) -> (a0: Double, a1: Double, n0: Double, n1: Double) {
    let w = min(max(300, Double(m.w) * 0.6), Double(m.w) - 120), c = Double(m.x) + Double(m.w) / 2
    return (c - w / 2, c + w / 2, 100, 480)
}

/// The profile of a round-fronted reed w wide and d deep (a fluted front's strip, fluted glass): flat at the back, half
/// round at the front; x across, y out, metres.
private func k3Reed(_ w: Double, _ d: Double) -> [(Double, Double)] {
    var p: [(Double, Double)] = [(0, 0), (w, 0)]
    for k in 0...4 { let t = Double(k) * .pi / 4; p.append((w / 2 + w / 2 * cos(t), d / 2 + d / 2 * sin(t))) }
    return p
}

/// A knob's turned profile (radius, distance out from the front), metres: a rose, a stem, a flattened ball (mockup b.knob).
private let K3_KNOB: [(Double, Double)] = [(0, 0), (0.011, 0), (0.011, 0.004), (0.006, 0.006), (0.006, 0.014), (0.011, 0.017),
                                           (0.0145, 0.024), (0.013, 0.031), (0.008, 0.035), (0, 0.036)]

/// A front's own frame, metres: o its back bottom corner on the hinge side (a drawer's left), e across it towards the
/// opening edge, u up, n out of its face.
struct FFrame {
    let o: V3, e: V3, u: V3, n: V3
    func at(_ a: Double, _ y: Double, _ z: Double) -> V3 { o + e * a + u * y + n * z }
}

/* ---------------- shapes ---------------- */

extension FBuilder {
    /// Round parts, fluted reeds, a worktop's soft edge: not in the 2D drawings.
    var fancy: Bool { detail != .flat }
    /// Sides of a round part.
    var sides: Int { detail == .high ? 12 : 8 }

    /// A flat convex face pts facing away from inner, its picture's grain along grain (else its first edge), laid in it.
    func face(_ part: Part3, _ pts: [V3], _ inner: V3, _ grain: V3? = nil) {
        guard pts.count >= 3 else { return }
        // Newell's normal: right for any flat polygon, whatever its winding
        var nx = 0.0, ny = 0.0, nz = 0.0
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            nx += (a.y - b.y) * (a.z + b.z); ny += (a.z - b.z) * (a.x + b.x); nz += (a.x - b.x) * (a.y + b.y)
        }
        var n = V3(nx, ny, nz)
        if n.len < 1e-14 { return }
        n = n.unit
        let c = pts.reduce(V3(0, 0, 0), +) * (1 / Double(pts.count))
        if n.dot(c - inner) < 0 { n = n * -1 }
        var g = grain ?? (pts[1] - pts[0])
        g = g - n * g.dot(n)
        if g.len < 1e-9 { let e = pts[1] - pts[0]; g = e - n * e.dot(n) }
        if g.len < 1e-12 { return }
        part.faces.append(Face3(n: n, pts: pts, grain: g.unit))
    }

    /// A round rod from a to b (metres), radius r at a and r2 at b (a tapering leg), of n sides.
    func tube(_ part: Part3, _ a: V3, _ b: V3, _ r: Double, _ r2: Double? = nil, n: Int? = nil) {
        let ax = b - a, L = ax.len
        guard L > 1e-6, r > 0 else { return }
        let d = ax * (1 / L)
        let ref = abs(d.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)
        let x = d.cross(ref).unit, y = d.cross(x).unit
        let k = n ?? sides, rb = r2 ?? r
        let mid = a + ax * 0.5
        var ra: [V3] = [], rt: [V3] = []
        for i in 0..<k {
            let t = (Double(i) + 0.5) / Double(k) * 2 * .pi
            let c = x * cos(t) + y * sin(t)
            ra.append(a + c * r); rt.append(b + c * rb)
        }
        for i in 0..<k { let j = (i + 1) % k; face(part, [ra[i], ra[j], rt[j], rt[i]], mid, rt[i] - ra[i]) }
        face(part, ra, mid, x); face(part, rt, mid, x)
    }

    /// A turned part round the axis from c along d (unit, metres): its profile (radius, distance along d) from the
    /// axis at the bottom out, up the side and back in at the top; n sides (nil: sides).
    func lathe(_ part: Part3, _ c: V3, _ d: V3, _ prof: [(Double, Double)], n: Int? = nil) {
        let ref = abs(d.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)
        let x = d.cross(ref).unit, y = d.cross(x).unit
        let k = n ?? sides
        func pt(_ i: Int, _ j: Int) -> V3 {
            let t = Double(j % k) / Double(k) * 2 * .pi
            return c + d * prof[i].1 + (x * cos(t) + y * sin(t)) * prof[i].0
        }
        for i in 0..<(prof.count - 1) {
            let (r0, h0) = prof[i], (r1, h1) = prof[i + 1]
            for j in 0..<k {
                let tm = (Double(j) + 0.5) / Double(k) * 2 * .pi
                let rad = x * cos(tm) + y * sin(tm)
                // outward in the profile's plane (it runs round anticlockwise): (dh, -dr)
                let out = rad * (h1 - h0) + d * (r0 - r1)
                let pm = c + d * ((h0 + h1) / 2) + rad * ((r0 + r1) / 2)
                let q: [V3]
                if r0 < 1e-9 { q = [pt(i, j), pt(i + 1, j), pt(i + 1, j + 1)] }
                else if r1 < 1e-9 { q = [pt(i, j), pt(i, j + 1), pt(i + 1, j)] }
                else { q = [pt(i, j), pt(i, j + 1), pt(i + 1, j + 1), pt(i + 1, j)] }
                face(part, q, pm - out)
            }
        }
    }

    /// A bar of convex cross-section prof (x along ex, y along ey from o; metres) running along ax: a fluted reed, a
    /// worktop with its soft front edge.
    func extrude(_ part: Part3, _ o: V3, _ ex: V3, _ ey: V3, _ ax: V3, _ prof: [(Double, Double)]) {
        let a = prof.map { o + ex * $0.0 + ey * $0.1 }, b = a.map { $0 + ax }
        let c = a.reduce(V3(0, 0, 0), +) * (1 / Double(a.count)) + ax * 0.5
        for i in 0..<a.count { let j = (i + 1) % a.count; face(part, [a[i], a[j], b[j], b[i]], c, ax) }
        face(part, a, c, ex); face(part, b, c, ex)
    }

    /// A box in a front's frame: a along e, y up, z out from o, sizes da × dy × dz, metres.
    func fbox(_ part: Part3, _ f: FFrame, _ a: Double, _ y: Double, _ z: Double, _ da: Double, _ dy: Double, _ dz: Double, _ line: Bool = false) {
        if da < 1e-5 || dy < 1e-5 || dz < 1e-5 { return }
        obb(part, Obb(o: f.at(a, y, z), a: f.e * da, b: f.u * dy, c: f.n * dz), line)
    }

    /// A flat ring on a level face (a hob's cooking zone): its middle c, outer radius r and width wd, metres.
    func ring(_ part: Part3, _ w: WallBasis, _ c: V3, _ r: Double, _ wd: Double) {
        let k = sides * 2
        let below = c - V3(0, 0.01, 0)
        for i in 0..<k {
            let t0 = Double(i) / Double(k) * 2 * .pi, t1 = Double(i + 1) / Double(k) * 2 * .pi
            let d0 = w.dir(cos(t0), sin(t0)), d1 = w.dir(cos(t1), sin(t1))
            face(part, [c + d0 * r, c + d1 * r, c + d1 * (r - wd), c + d0 * (r - wd)], below, d1 - d0)
        }
    }

    /* ---------------- fronts and handles ---------------- */

    /// A front's body in frame f, W × H metres, T thick, as the piece's style says (mockup b.front): flat; shaker, a frame
    /// of rails 4 mm proud round a sunk panel with a bead; fluted, upright half-round reeds on a thin board. One outline
    /// round it. How far its face stands out of the frame (the handles go there).
    @discardableResult
    func frontBody(_ part: Part3, _ f: FFrame, _ W: Double, _ H: Double, _ T: Double) -> Double {
        let st = fancy ? style : "flat"
        if st == "shaker" && W > 0.14 && H > 0.12 {
            let rw = min(0.068, W * 0.2, H * 0.22), t2 = T + 0.004
            fbox(part, f, 0, 0, 0, rw, H, t2); fbox(part, f, W - rw, 0, 0, rw, H, t2)
            fbox(part, f, rw, 0, 0, W - 2 * rw, rw, t2); fbox(part, f, rw, H - rw, 0, W - 2 * rw, rw, t2)
            fbox(part, f, rw, rw, 0, W - 2 * rw, H - 2 * rw, T - 0.006)
            let bd = 0.011, ix = rw + 0.006, iy = rw + 0.006, iw = W - 2 * rw - 0.012, ih = H - 2 * rw - 0.012, zz = T - 0.006
            if iw > 0.04 && ih > 0.04 {
                fbox(part, f, ix, iy, zz, bd, ih, 0.007); fbox(part, f, ix + iw - bd, iy, zz, bd, ih, 0.007)
                fbox(part, f, ix + bd, iy, zz, iw - 2 * bd, bd, 0.007); fbox(part, f, ix + bd, iy + ih - bd, zz, iw - 2 * bd, bd, 0.007)
            }
            obbEdges(edges, Obb(o: f.o, a: f.e * W, b: f.u * H, c: f.n * t2))
            return t2
        }
        if st == "fluted" && W > 0.1 {
            fbox(part, f, 0, 0, 0, W, H, 0.01)
            let n = max(3, Int((W / 0.03).rounded())), sw = W / Double(n)
            for i in 0..<n {
                let x0 = sw * Double(i) + 0.00075, rw = sw - 0.0015
                if detail == .high { extrude(part, f.at(x0, 0.0015, 0.01), f.e, f.n, f.u * (H - 0.003), k3Reed(rw, 0.012)) }
                else { fbox(part, f, x0, 0.0015, 0.01, rw, H - 0.003, 0.012) }
            }
            obbEdges(edges, Obb(o: f.o, a: f.e * W, b: f.u * H, c: f.n * 0.022))
            return 0.022
        }
        fbox(part, f, 0, 0, 0, W, H, T, true)
        return T
    }

    /// A glass door in frame f, W × H metres (mockup b.glassDoor): a 20 mm frame in the handle colour (aluminium with
    /// none), or a 55 mm one of the front board for the neoclassic (shaker) style, round a clear pane, or fluted glass.
    /// How far its face stands out.
    func glassDoor(_ f: FFrame, _ W: Double, _ H: Double, _ front: Part3) -> Double {
        let sh = fancy && style == "shaker", fw = sh ? 0.055 : 0.02, fd = 0.02
        let fm = sh ? front : p("frame")
        fbox(fm, f, 0, 0, 0, fw, H, fd, true); fbox(fm, f, W - fw, 0, 0, fw, H, fd, true)
        fbox(fm, f, fw, 0, 0, W - 2 * fw, fw, fd, true); fbox(fm, f, fw, H - fw, 0, W - 2 * fw, fw, fd, true)
        let gw = W - 2 * fw, gh = H - 2 * fw
        if fancy && fglass && gw > 0.03 && gh > 0.03 {
            let n = max(2, Int((gw / 0.022).rounded())), sw = gw / Double(n), fg = p("fglass")
            for i in 0..<n {
                let x0 = fw + sw * Double(i) + 0.0004, rw = sw - 0.0008
                if detail == .high { extrude(fg, f.at(x0, fw, 0.0055), f.e, f.n, f.u * gh, k3Reed(rw, 0.007)) }
                else { fbox(fg, f, x0, fw, 0.0055, rw, gh, 0.007) }
            }
        } else {
            fbox(p("clear"), f, fw, fw, 0.007, gw, gh, 0.004)
        }
        return fd
    }

    /// A bar handle on two standoffs (mockup b.bar): its middle at (a, y) of frame f on the face zf out, L long, upright
    /// or across; part its look (the handles' by default). In the 2D drawings a plain box.
    func bar(_ f: FFrame, _ a: Double, _ y: Double, _ zf: Double, _ L: Double, _ vert: Bool, _ part: Part3? = nil) {
        let h = part ?? p("handle")
        if !fancy {
            if vert { fbox(h, f, a - 0.006, y - L / 2, zf, 0.012, L, 0.025) } else { fbox(h, f, a - L / 2, y - 0.006, zf, L, 0.012, 0.025) }
            return
        }
        let c = max(0.05, L - 0.04), so = 0.024, hb = 0.011
        for s in [-1.0, 1.0] {
            let q = vert ? f.at(a, y + s * c / 2, zf) : f.at(a + s * c / 2, y, zf)
            tube(h, q, q + f.n * so, 0.0042)
        }
        let mid = f.at(a, y, zf + so + hb / 2), dir = vert ? f.u : f.e
        tube(h, mid - dir * (L / 2), mid + dir * (L / 2), hb / 2, n: 8)
    }

    /// A round knob at (a, y) of frame f on the face zf out (mockup b.knob).
    func knob(_ f: FFrame, _ a: Double, _ y: Double, _ zf: Double) {
        let h = p("handle")
        if !fancy { fbox(h, f, a - 0.012, y - 0.012, zf, 0.024, 0.024, 0.022); return }
        lathe(h, f.at(a, y, zf), f.n, K3_KNOB)
    }

    /// The handle of a front W × H metres in frame f, its face zf out: kind "door", "drawer" or "flap", a door's at
    /// place (handleSpot). None with a Gola profile or push latches.
    func handle(_ f: FFrame, _ W: Double, _ H: Double, _ zf: Double, _ kind: String, _ place: HPlace) {
        if htype == "gola" || htype == "push" { return }
        let id = htype == "knob" ? "handleKnob" : htype == "long" ? hid : ""
        guard let s = handleSpot(id, kind, W * 1000, H * 1000, place) else { return }
        if s.len == 0 { knob(f, s.x / 1000, s.y / 1000, zf) } else { bar(f, s.x / 1000, s.y / 1000, zf, s.len / 1000, s.vert) }
    }

    /// A front that does not open (an appliance's panel, a lift-up front of the row to the ceiling): its body from
    /// (a0, y0) along the wall, fw × fh, its back at n, mm; its handle of kind when handles.
    func staticFront(_ w: WallBasis, _ part: Part3, _ a0: Double, _ y0: Double, _ fw: Double, _ fh: Double, _ n: Double, _ handles: Bool = false,
                     _ kind: String = "flap", _ place: HPlace = .bottom) {
        let fr = FFrame(o: w.at(a0 / 1000, y0 / 1000, n / 1000), e: w.dir(1, 0), u: V3(0, 1, 0), n: w.dir(0, 1))
        let zf = frontBody(part, fr, fw / 1000, fh / 1000, Double(t) / 1000)
        if handles { handle(fr, fw / 1000, fh / 1000, zf, kind, place) }
    }

    /* ---------------- the kitchen's parts ---------------- */

    /// A base or tall unit's feet: visible metal legs (an extra; four to a unit, tapering down, mockup legs()), else the
    /// hidden plinth of the lower fronts' board, 50 mm behind them.
    func feet(_ w: WallBasis, _ x0: Double, _ x1: Double, _ y0: Double, _ dd: Double) {
        if legsMetal {
            let lg = p("legs")
            for a in [x0 + 50, x1 - 50] {
                for n in [70.0, dd - 60] {
                    if fancy { tube(lg, w.at(a / 1000, 0, n / 1000), w.at(a / 1000, (y0 - 1) / 1000, n / 1000), 0.013, 0.016) }
                    else { box(w, lg, a - 13, a + 13, 0, y0 - 1, n - 13, n + 13) }
                }
            }
        } else {
            box(w, p("plinth"), x0, x1, 0, y0 - 2, dd - 66, dd - 50, true)
        }
    }

    /// A Gola channel along a base unit x0…x1 whose fronts' space ends at top, behind the fronts (dd their back), mm.
    func golaRail(_ w: WallBasis, _ x0: Double, _ x1: Double, _ top: Double, _ dd: Double) {
        box(w, p("gola"), x0, x1, top - GOLA_H, top, dd - 30, dd - 2)
    }

    /// A worktop a0…a1 along the wall, n0…n1 out, its top at top and th thick (mm), of look "top": the decor slab with a
    /// soft front edge (rounded 5 mm, 3 on a slim one) and a real cut-out at each sink hole (a0, a1, n0, n1). One
    /// outline round it all.
    func worktop(_ w: WallBasis, _ a0: Double, _ a1: Double, _ n0: Double, _ n1: Double, _ top: Double, _ th: Double,
                 _ holes: [(a0: Double, a1: Double, n0: Double, n1: Double)]) {
        let tp = p("top"), y0 = top - th
        guard a1 - a0 > 0.1 else { return }
        obbEdges(slabEdges, Obb(o: w.at(a0 / 1000, y0 / 1000, n0 / 1000), a: w.dir((a1 - a0) / 1000, 0), b: V3(0, th / 1000, 0), c: w.dir(0, (n1 - n0) / 1000)))
        if !fancy { box(w, tp, a0, a1, y0, top, n0, n1); return }
        var a = a0
        for h in holes.filter({ $0.a1 > a0 && $0.a0 < a1 }).sorted(by: { $0.a0 < $1.a0 }) {
            let h0 = max(a, h.a0), h1 = min(a1, h.a1)
            guard h1 > h0 else { continue }
            slab(w, tp, a, h0, n0, n1, y0, th)
            box(w, tp, h0, h1, y0, top, n0, h.n0)
            slab(w, tp, h0, h1, h.n1, n1, y0, th)
            a = h1
        }
        slab(w, tp, a, a1, n0, n1, y0, th)
    }

    /// A slab a0…a1 along the wall, n0…n1 out, from y0 up th (mm), its front edge (at n1) rounded.
    private func slab(_ w: WallBasis, _ part: Part3, _ a0: Double, _ a1: Double, _ n0: Double, _ n1: Double, _ y0: Double, _ th: Double) {
        guard a1 - a0 > 0.1, n1 - n0 > 12 else { return }
        let r = th > 30 ? 5.0 : 3.0, top = y0 + th
        var prof: [(Double, Double)] = [(n0, y0)]
        for k in 0...3 { let t = -Double.pi / 2 + Double(k) * .pi / 6; prof.append((n1 - r + r * cos(t), y0 + r + r * sin(t))) }
        for k in 0...3 { let t = Double(k) * .pi / 6; prof.append((n1 - r + r * cos(t), top - r + r * sin(t))) }
        prof.append((n0, top))
        extrude(part, w.at(a0 / 1000, 0, 0), w.dir(0, 1), V3(0, 1, 0), w.dir((a1 - a0) / 1000, 0), prof.map { ($0.0 / 1000, $0.1 / 1000) })
    }

    /// A sink unit's basin under its cut-out (190 deep), its drain and the tap behind it (mockup).
    func sink(_ w: WallBasis, _ m: Module) {
        let h = sinkHole(m), top = wtTop, dep = 190.0, wl = 8.0, s = p("sinkIn")
        box(w, s, h.a0, h.a1, top - dep - 10, top - dep, h.n0, h.n1)
        box(w, s, h.a0, h.a1, top - dep, top - 1, h.n0, h.n0 + wl); box(w, s, h.a0, h.a1, top - dep, top - 1, h.n1 - wl, h.n1)
        box(w, s, h.a0, h.a0 + wl, top - dep, top - 1, h.n0 + wl, h.n1 - wl); box(w, s, h.a1 - wl, h.a1, top - dep, top - 1, h.n0 + wl, h.n1 - wl)
        let cx = (h.a0 + h.a1) / 2, cn = (h.n0 + h.n1) / 2
        tube(p("steel"), w.at(cx / 1000, (top - dep) / 1000, cn / 1000), w.at(cx / 1000, (top - dep + 5) / 1000, cn / 1000), 0.035)
        faucet(w, cx, h.n0 - 40, top)
    }

    /// A tap at a along the wall and n out, on a worktop whose top is at top (mm): its base, the pipe up, an arch over to
    /// the front, the spout down, the lever on its side.
    func faucet(_ w: WallBasis, _ a: Double, _ n: Double, _ top: Double) {
        let f = p("faucet")
        func q(_ y: Double, _ nn: Double) -> V3 { w.at(a / 1000, y / 1000, nn / 1000) }
        tube(f, q(top, n), q(top + 40, n), 0.024)
        tube(f, q(top + 40, n), q(top + 320, n), 0.012)
        let R = 85.0, k = detail == .high ? 8 : 5
        var prev = q(top + 320, n)
        for i in 1...k {
            let t = Double(i) / Double(k) * .pi
            let cur = q(top + 320 + R * sin(t), n + R - R * cos(t))
            tube(f, prev, cur, 0.012)
            prev = cur
        }
        tube(f, q(top + 320, n + 2 * R), q(top + 262, n + 2 * R), 0.012)
        box(w, f, a + 40, a + 100, top + 120, top + 132, n - 10, n + 2)
    }

    /// A hob of black glass in the worktop round cx, with its four cooking zones and the touch controls.
    func hob(_ w: WallBasis, _ cx: Double) {
        let top = wtTop
        box(w, p("bglass"), cx - 290, cx + 290, top, top + 6, 40, 560, true)
        let z = p("zone"), y = (top + 6.4) / 1000
        for (dx, dn, r) in [(-140.0, 165.0, 95.0), (140.0, 165.0, 80.0), (-140.0, 410.0, 80.0), (140.0, 410.0, 105.0)] {
            ring(z, w, w.at((cx + dx) / 1000, y, dn / 1000), r / 1000, 0.006)
            ring(z, w, w.at((cx + dx) / 1000, y, dn / 1000), r * 0.55 / 1000, 0.004)
        }
        box(w, z, cx - 70, cx + 70, top + 6, top + 6.5, 518, 540)
    }

    /// A built-in oven x0…x1 × y0…y1 in its niche, its front at dd (mm; mockup tall()): black glass, the window, the
    /// steel control strip with two knobs and the display, a long steel bar.
    func oven(_ w: WallBasis, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ dd: Double) {
        let fw = x1 - x0, h = y1 - y0, st = p("steel")
        box(w, p("bglass"), x0, x1, y0, y1, dd, dd + 24, true)
        box(w, p("ovenWin"), x0 + 35, x1 - 35, y0 + 60, y0 + 60 + h * 0.52, dd + 24, dd + 25.2)
        box(w, st, x0, x1, y1 - 75, y1, dd + 24, dd + 27)
        for kx in [x0 + 60, x1 - 60] { tube(st, w.at(kx / 1000, (y1 - 37) / 1000, (dd + 27) / 1000), w.at(kx / 1000, (y1 - 37) / 1000, (dd + 45) / 1000), 0.017) }
        box(w, p("display"), x0 + fw / 2 - 55, x0 + fw / 2 + 55, y1 - 52, y1 - 22, dd + 27, dd + 28)
        let fr = FFrame(o: w.at(x0 / 1000, y0 / 1000, dd / 1000), e: w.dir(1, 0), u: V3(0, 1, 0), n: w.dir(0, 1))
        bar(fr, fw / 2000, (h - 120) / 1000, 0.024, (fw - 90) / 1000, false, st)
    }

    /// A microwave in the bottom of an open wall unit x0… (mw wide, its bottom at y0, dd deep; mm): black glass with its
    /// window and display.
    func micro(_ w: WallBasis, _ x0: Double, _ y0: Double, _ mw: Double, _ dd: Double) {
        let T = Double(t), a0 = x0 + T + 10, a1 = x0 + mw * 0.72, ya = y0 + T, yb = y0 + T + 290
        guard a1 - a0 > 100 else { return }
        box(w, p("bglass"), a0, a1, ya, yb, 40, dd - 10, true)
        let bw = a1 - a0
        box(w, p("ovenWin"), a0 + 30, a0 + 30 + bw * 0.6, ya + 45, yb - 45, dd - 10, dd - 8.8)
        box(w, p("display"), a0 + bw * 0.76, min(a1 - 15, a0 + bw * 0.76 + 60), yb - 80, yb - 58, dd - 10, dd - 9)
    }

    /// A hood's visor under its cabinet x0…x1 whose bottom is y0 (mm): steel with a black glass front, two lamps under it.
    func hood(_ w: WallBasis, _ x0: Double, _ x1: Double, _ y0: Double, _ dd: Double) {
        box(w, p("steel"), x0 + 10, x1 - 10, y0 - 80, y0, 20, dd + 30, true)
        box(w, p("bglass"), x0 + 10, x1 - 10, y0 - 80, y0, dd + 30, dd + 36)
        let lamp = p(ledOn ? "led" : "white")
        for a in [x0 + (x1 - x0) * 0.3, x0 + (x1 - x0) * 0.7] {
            tube(lamp, w.at(a / 1000, (y0 - 84) / 1000, dd * 0.5 / 1000), w.at(a / 1000, (y0 - 80) / 1000, dd * 0.5 / 1000), 0.026)
        }
    }

    /// One wall's units ms (sorted along it) in stretches that touch end to end and agree by same.
    func stretches(_ ms: [Module], _ same: (Module, Module) -> Bool) -> [[Module]] {
        var out: [[Module]] = []
        for m in ms.sorted(by: { $0.x < $1.x }) {
            if let l = out.last?.last, abs(l.x + l.w - m.x) <= 2, same(l, m) { out[out.count - 1].append(m) } else { out.append([m]) }
        }
        return out
    }

    /// The LED under a stretch of wall units a0…a1 whose bottom is at y and depth d (mm): a glowing strip near their
    /// front edge and, on a strong phone, its light on the wall under them (three faint planes, brightest at the top,
    /// down to no lower than low; mockup glow); n0 the wall's face there (the backsplash's front).
    func ledUnder(_ w: WallBasis, _ a0: Double, _ a1: Double, _ y: Double, _ d: Double, _ n0: Double, _ low: Double) {
        guard a1 - a0 > 40 else { return }
        box(w, p("led"), a0 + 10, a1 - 10, y - 8, y, d - 50, d - 36)
        guard detail == .high else { return }
        let g = p("glow"), H = min(340, y - 8 - low)
        guard H > 40 else { return }
        let A0 = (a0 + 5) / 1000, A1 = (a1 - 5) / 1000, y1 = (y - 8) / 1000
        for (k, f) in [1.0, 0.62, 0.3].enumerated() {
            let n = (n0 + 0.6 + Double(k)) / 1000, y0 = (y - 8 - H * f) / 1000
            face(g, [w.at(A0, y0, n), w.at(A1, y0, n), w.at(A1, y1, n), w.at(A0, y1, n)], w.at((A0 + A1) / 2, (y0 + y1) / 2, n - 0.01), w.dir(1, 0))
        }
    }

    /// The cornice's three layers (CORNICE_LAYERS) over each stretch of one wall's wall and tall units ms with the same
    /// top and depth, in the upper fronts' board (mockup cornice()).
    func cornice(_ w: WallBasis, _ ms: [Module]) {
        for s in stretches(ms, { $0.elev + $0.h == $1.elev + $1.h && $0.d == $1.d }) {
            guard let f0 = s.first, let f1 = s.last else { continue }
            var y = Double(f0.elev + f0.h)
            for l in CORNICE_LAYERS {
                box(w, p("frontUp"), Double(f0.x), Double(f1.x + f1.w), y, y + l.h, 0, Double(f0.d) + l.out, true)
                y += l.h
            }
        }
    }

    /// A row of units up to the ceiling over one wall's wall and tall units ms (mockup crown "ceiling"): over each, a box
    /// in its fronts' colour and a lift-up front with its handle at the bottom; isUp whether a unit takes the upper fronts.
    func ceilingRow(_ w: WallBasis, _ ms: [Module], _ isUp: (Module) -> Bool) {
        for m in ms {
            let top = m.elev + m.h, hh = ceilRowH(top, ceilH)
            guard hh > 0 else { continue }
            let pu = p(isUp(m) ? "frontUp" : "front")
            let x0 = Double(m.x), x1 = x0 + Double(m.w), y0 = Double(top), dd = Double(m.d)
            box(w, pu, x0, x1, y0, y0 + Double(hh), 0, dd, true)
            if !bare { staticFront(w, pu, x0 + edge, y0 + g / 2, Double(m.w) - 2 * edge, Double(hh) - g, dd, m.handles) }
        }
    }
}
