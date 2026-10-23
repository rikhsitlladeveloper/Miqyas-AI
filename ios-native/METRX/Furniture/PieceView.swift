import SwiftUI
import UIKit

/*
 * A piece of furniture drawn in 3D for the gallery's cards and the size steps (gallery v5, 21 Oct 2026; Android
 * ui/furniture/PieceView.kt and Gallery.kt PiecePics): the designer's own boards (Geo/Furniture3D) on the floor of the
 * piece's made-up room, the walls it stands on behind it, flat-shaded and drawn back to front with Core Graphics. A size
 * step tints the run it asks about and draws that size as a blue dimension line. Core Graphics' y grows downward here,
 * as Compose's does, so the projection is the Android one.
 */

/// A face to draw: its corners, outward normal, colour and opacity, and what it belongs to (a wall id, "floor" or "wall").
struct SFace { let pts: [V3]; let n: V3; let rgb: Int; let op: Double; let tag: String?; var slab: Bool = false }

/// A size shown on the piece: from a to b, with end ticks along tick.
struct DimLine { let a: V3; let b: V3; let tick: V3 }

/// One board: its six faces, as furniture3D makes them for each box, with its corners and face planes for the drawing
/// order.
struct SBox {
    let faces: [SFace]
    /// The eight corners, x y z one after another (the first two faces hold them all).
    let pts: [Double]
    /// Each face's plane: its outward normal and n·p, four numbers a face.
    let planes: [Double]
    init(_ faces: [SFace]) {
        self.faces = faces
        pts = (faces[0].pts + faces[1].pts).flatMap { [$0.x, $0.y, $0.z] }
        planes = faces.flatMap { [$0.n.x, $0.n.y, $0.n.z, $0.n.dot($0.pts[0])] }
    }
}

/// The faces of a piece (env: floor and walls, drawn first; furn: the boards), its middle and size for the camera, the
/// dimension line of each step key and what each step tints (tint: a wall id, ISLAND or "wall").
final class PieceScene {
    let env: [SFace], furn: [SBox]
    let center: V3, radius: Double
    let dims: [String: DimLine], tint: [String: String]
    let az0: Double
    /// The middle and size with the dimension lines in, for a step that shows one.
    let dimCenter: V3, dimRadius: Double
    /// The corners of the boards' bounds, and of the bounds with the dimension lines in: what the camera fits in.
    let ext: [V3], dimExt: [V3]
    /// The boards' draw order for the last 3° step of turning it (and picture size): worked out again only past the step.
    private var orderKey: [Int] = []
    private var orderBoxes: [SBox] = []
    private let orderLock = NSLock()
    func cachedOrder(_ key: [Int], _ make: () -> [SBox]) -> [SBox] {
        orderLock.lock(); defer { orderLock.unlock() }
        if key == orderKey { return orderBoxes }
        let o = make()
        orderKey = key; orderBoxes = o
        return o
    }
    init(_ env: [SFace], _ furn: [SBox], _ center: V3, _ radius: Double, _ dims: [String: DimLine], _ tint: [String: String], _ az0: Double,
         dimCenter: V3? = nil, dimRadius: Double? = nil, ext: [V3] = [], dimExt: [V3]? = nil) {
        self.env = env; self.furn = furn; self.center = center; self.radius = radius; self.dims = dims; self.tint = tint; self.az0 = az0
        self.dimCenter = dimCenter ?? center; self.dimRadius = dimRadius ?? radius
        self.ext = ext; self.dimExt = dimExt ?? ext
    }
}

private func pvCorners(_ x0: Double, _ y0: Double, _ z0: Double, _ x1: Double, _ y1: Double, _ z1: Double) -> [V3] {
    [x0, x1].flatMap { x in [y0, y1].flatMap { y in [V3(x, y, z0), V3(x, y, z1)] } }
}

private let PV_UP = V3(0, 1, 0)
private let PV_WALL = 0xEEF1F7
private let PV_FLOOR = 0xE3E8F0
private let PV_HI = 0x9FB2FF
private let PV_BLUE = 0x3550E0
private let PV_BG = 0xF6F8FC
private let PV_EDGE = 0x1E293B

/// The piece's scene; bare without its doors and fronts ("See inside"), hi a part lit up (parts list → 3D).
func pieceScene(_ f: Furniture, _ ws: Workshop, _ mats: [Mat], bare: Bool = false, hi: PartHi? = nil) -> PieceScene {
    let room = freeRoom(f)
    let shell = buildShell([room], single: true, snap: true)
    let b = shell.bases
    let fur = furniture3D([f], b, ws, { id in rgbOf(mats.first { $0.id == id }?.rgb ?? "#F5F5F2") }, [], bare: bare, hi: hi)
    // every box of furniture3D adds its six faces to its part one after another
    let furn: [SBox] = fur.parts.flatMap { p in
        stride(from: 0, to: p.faces.count - 5, by: 6).map { k in SBox(p.faces[k..<k + 6].map { SFace(pts: $0.pts, n: $0.n, rgb: p.rgb, op: p.op, tag: p.wall, slab: p.slab) }) }
    }
    var env: [SFace] = []
    for p in shell.parts where p.role == .floor { for fc in p.faces { env.append(SFace(pts: fc.pts, n: fc.n, rgb: PV_FLOOR, op: 1, tag: "floor")) } }
    let H = Double(room.dim("H").v ?? 2700) / 1000
    let onWalls = f.walls.filter { $0 != ISLAND }
    for w in onWalls {
        guard let bas = b[w] else { continue }
        env.append(SFace(pts: [bas.at(0, 0, 0), bas.at(bas.len, 0, 0), bas.at(bas.len, H, 0), bas.at(0, H, 0)], n: V3(bas.nx, 0, bas.nz), rgb: PV_WALL, op: 0.95, tag: "wall"))
    }
    // the middle and size of the boards alone
    var x0 = Double.greatestFiniteMagnitude, y0 = Double.greatestFiniteMagnitude, z0 = Double.greatestFiniteMagnitude
    var x1 = -Double.greatestFiniteMagnitude, y1 = -Double.greatestFiniteMagnitude, z1 = -Double.greatestFiniteMagnitude
    func take(_ q: V3) { x0 = min(x0, q.x); y0 = min(y0, q.y); z0 = min(z0, q.z); x1 = max(x1, q.x); y1 = max(y1, q.y); z1 = max(z1, q.z) }
    for bx in furn { for q in bx.faces[0].pts + bx.faces[1].pts { take(q) } }
    if furn.isEmpty { x0 = 0; y0 = 0; z0 = 0; x1 = 1; y1 = 1; z1 = 1 }
    var dims: [String: DimLine] = [:], tint: [String: String] = [:]
    if f.kind == "kitchen" {
        let y = Double(worktopTop(wsOf(f, ws)) + 30) / 1000
        for (i, w) in onWalls.enumerated() {
            guard let bas = b[w] else { continue }
            let sides = f.free?.sides ?? []
            let l = Double(i < sides.count ? sides[i] : Int(bas.len * 1000)) / 1000
            let k = "s\(sideNo(f, i) - 1)"
            dims[k] = DimLine(a: bas.at(0, y, 0.68), b: bas.at(l, y, 0.68), tick: PV_UP); tint[k] = w
        }
        // the island (or peninsula) where furniture3D puts it: its length past its seating side
        let w0 = onWalls.first.flatMap { b[$0] }
        let isl = Double(f.modules.filter { $0.wall == ISLAND && !isUpper($0) }.reduce(0) { $0 + $1.w }) / 1000
        if let w0, isl > 0 {
            let ip = islandPose(f, Int((w0.len * 1000).rounded()))
            let ib = poseBasis(b[ip.ref] ?? w0, ip, isl)
            dims["isl"] = DimLine(a: ib.at(0, y, -0.40), b: ib.at(isl, y, -0.40), tick: PV_UP); tint["isl"] = ISLAND
        }
        if let w0 { dims["h"] = DimLine(a: w0.at(0, 0, 0.04), b: w0.at(0, H, 0.04), tick: w0.dir(1, 0)); tint["h"] = "wall" }
    } else if let m = wardOfF(f), let bas = b[f.walls.first ?? "A"] ?? b["A"] {
        pieceDims(f, m, ws, b, bas, &dims)
    }
    // a corner piece measured along its fronts or its walls shows the arm (or side) being asked
    for (k, of) in [("ai", "w"), ("la", "w"), ("bi", "w2"), ("lb", "w2"), ("f0", "s0"), ("f1", "s1")] {
        if let dl = dims[of] { dims[k] = dl }
        if let tn = tint[of] { tint[k] = tn }
    }
    let center = V3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    let radius = max(0.45, V3(x1 - x0, y1 - y0, z1 - z0).len / 2)
    let ext = pvCorners(x0, y0, z0, x1, y1, z1)
    // a step's camera takes in the dimension lines too, so a size in front of the piece stays in the picture
    for d in dims.values { take(d.a); take(d.b) }
    let dimCenter = V3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    let dimRadius = max(0.45, V3(x1 - x0, y1 - y0, z1 - z0).len / 2)
    // an L turns into the right-hand wall: seen from the left so both runs show from inside
    // one with its corner on the left (made-up walls D, A) is seen from the right
    let left = f.walls.first == "D" && f.layout != "U"
    let az0: Double
    if f.kind != "kitchen" { az0 = CORNER_TYPES.contains(f.type) ? (left ? 0.6 : -0.6) : 0.55 }
    else { az0 = f.layout == "L" ? (left ? 0.6 : -0.6) : f.layout == "U" ? 0.15 : 0.6 }
    return PieceScene(env, furn, center, radius, dims, tint, az0, dimCenter: dimCenter, dimRadius: dimRadius, ext: ext, dimExt: pvCorners(x0, y0, z0, x1, y1, z1))
}

/// A cabinet-like piece's dimension lines on its first wall bas (walls b): the run there (a stenka's pieces, a corner
/// piece's first arm), its depth and its top; a hung one's height above the floor, a corner piece's second arm, a bed's
/// mattress and headboard, a dressing table's mirror.
private func pieceDims(_ f: Furniture, _ m: Module, _ ws: Workshop, _ b: [String: WallBasis], _ bas: WallBasis, _ dims: inout [String: DimLine]) {
    let bs = boxes(f)
    let run0 = firstRun(f)
    let run = run0.isEmpty ? [m] : run0
    let rx0: Int = run.map(\.x).min() ?? m.x
    let rx1: Int = run.map { $0.x + $0.w }.max() ?? (m.x + m.w)
    let xa = Double(rx0) / 1000, w = Double(rx1 - rx0) / 1000
    let d = Double(run.map(\.d).max() ?? m.d) / 1000
    let h = Double(bs.map { topOf($0, ws) }.max() ?? outerH(m, ws)) / 1000
    // a hung cabinet's (or a mirror panel's) height is its own, from its bottom
    let lo: Double = HUNG_TYPES.contains(f.type) || f.type == "mirrorP" ? Double(m.elev) / 1000 : 0
    let side = bas.dir(1, 0)
    dims["w"] = DimLine(a: bas.at(xa, lo + 0.02, d + 0.2), b: bas.at(xa + w, lo + 0.02, d + 0.2), tick: PV_UP)
    dims["h"] = DimLine(a: bas.at(xa + w + 0.15, lo, d), b: bas.at(xa + w + 0.15, h, d), tick: side)
    dims["d"] = DimLine(a: bas.at(xa + w + 0.08, h + 0.08, 0), b: bas.at(xa + w + 0.08, h + 0.08, d), tick: PV_UP)
    if lo > 0 { dims["e"] = DimLine(a: bas.at(xa + w + 0.15, 0, d), b: bas.at(xa + w + 0.15, lo, d), tick: side) }
    // a corner piece's second arm, from the corner
    if f.walls.count > 1, let bb = b[f.walls[1]] {
        let wb = f.walls[1]
        let on = bs.filter { $0.wall == wb }
        if let dm = on.map(\.d).max(), let end = on.map({ $0.x + $0.w }).max() {
            let db = Double(dm) / 1000
            dims["w2"] = DimLine(a: bb.at(0, 0.02, db + 0.2), b: bb.at(Double(end) / 1000, 0.02, db + 0.2), tick: PV_UP)
        }
    }
    let W = Double(m.w) / 1000, D = Double(m.d) / 1000, H = Double(m.h) / 1000
    switch m.type {
    case "bed":
        let hb = Double(m.opt?.hb ?? 1000) / 1000
        dims["mw"] = DimLine(a: bas.at(xa, H + 0.05, D + 0.12), b: bas.at(xa + W, H + 0.05, D + 0.12), tick: PV_UP)
        dims["ml"] = DimLine(a: bas.at(xa + W + 0.12, H + 0.05, 0), b: bas.at(xa + W + 0.12, H + 0.05, D), tick: PV_UP)
        dims["h"] = DimLine(a: bas.at(xa + W + 0.12, 0, D), b: bas.at(xa + W + 0.12, H, D), tick: side)
        dims["hb"] = DimLine(a: bas.at(xa - 0.12, 0, 0.02), b: bas.at(xa - 0.12, hb, 0.02), tick: side)
    case "bunk", "loft":
        let fd = D - Double(LADDER_D) / 1000
        dims["ml"] = DimLine(a: bas.at(xa, 0.02, D + 0.15), b: bas.at(xa + W, 0.02, D + 0.15), tick: PV_UP)
        dims["mw"] = DimLine(a: bas.at(xa + W + 0.1, H + 0.05, 0), b: bas.at(xa + W + 0.1, H + 0.05, fd), tick: PV_UP)
    default: break
    }
    // a dressing table's mirror
    if let r = f.modules.first(where: { $0.type == "mirror" }) {
        let x0 = Double(r.x) / 1000, x1 = Double(r.x + r.w) / 1000, e = Double(r.elev) / 1000, t = Double(r.elev + r.h) / 1000
        dims["rw"] = DimLine(a: bas.at(x0, t + 0.06, 0.03), b: bas.at(x1, t + 0.06, 0.03), tick: PV_UP)
        dims["rh"] = DimLine(a: bas.at(x1 + 0.08, e, 0.03), b: bas.at(x1 + 0.08, t, 0.03), tick: side)
    }
}

/// A camera round the piece: az turns it from the scene's own angle, the piece filling the picture.
private struct PCam {
    let e: V3, r: V3, u: V3, f: V3, foc: Double, cx: Double, cy: Double
    init(_ s: PieceScene, _ w: Double, _ h: Double, _ az: Double, _ withDims: Bool) {
        let half = 16.0 * Double.pi / 180
        let fit = min(half, atan(tan(half) * w / h))
        let c = withDims ? s.dimCenter : s.center
        let a = s.az0 + az, el = 0.5
        let back = V3(sin(a) * cos(el), sin(el), cos(a) * cos(el))
        let fw = back * -1, rt = fw.cross(PV_UP).unit, up = rt.cross(fw)
        // near enough that every corner of the bounds is in the picture with a little room round it (a tall piece's
        // top and bottom too), else round its bounding sphere
        let tv = tan(half), th = tv * w / h
        let ext = withDims ? s.dimExt : s.ext
        func fitAt(_ m: V3) -> Double { ext.map { q in let v = q - m; return 1.08 * max(abs(v.dot(rt)) / th, abs(v.dot(up)) / tv) - v.dot(fw) }.max() ?? 0 }
        var m = c
        // the bounds' picture centred: the camera slides across until it is
        if !ext.isEmpty {
            for _ in 0..<3 {
                let dist = fitAt(m)
                var lx = Double.greatestFiniteMagnitude, hx = -Double.greatestFiniteMagnitude, ly = Double.greatestFiniteMagnitude, hy = -Double.greatestFiniteMagnitude
                for q in ext {
                    let v = q - m, z = dist + v.dot(fw)
                    lx = min(lx, v.dot(rt) / z); hx = max(hx, v.dot(rt) / z); ly = min(ly, v.dot(up) / z); hy = max(hy, v.dot(up) / z)
                }
                m = m + rt * ((lx + hx) / 2 * dist) + up * ((ly + hy) / 2 * dist)
            }
        }
        let dist = ext.isEmpty ? (withDims ? s.dimRadius : s.radius) / sin(fit) : fitAt(m)
        e = m + back * dist; f = fw; r = rt; u = up
        foc = (h / 2) / tan(half); cx = w / 2; cy = h / 2
    }
    func p(_ q: V3) -> CGPoint? {
        let d = q - e, z = d.dot(f)
        if z < 0.05 { return nil }
        return CGPoint(x: cx + d.dot(r) / z * foc, y: cy - d.dot(u) / z * foc)
    }
    func depth(_ q: V3) -> Double { (q - e).dot(f) }
}

private let PV_LIGHT = V3(0.35, 0.85, 0.45).unit

private func pvMix(_ a: Int, _ b: Int, _ k: Double) -> Int {
    func c(_ s: Int) -> Int { min(255, max(0, Int(Double((a >> s) & 0xFF) * (1 - k) + Double((b >> s) & 0xFF) * k))) }
    return (c(16) << 16) | (c(8) << 8) | c(0)
}

private func pvColor(_ cg: CGContext, fill: Bool, _ rgb: Int, _ alpha: Double = 1) {
    let r = CGFloat((rgb >> 16) & 0xFF) / 255, g = CGFloat((rgb >> 8) & 0xFF) / 255, b = CGFloat(rgb & 0xFF) / 255
    if fill { cg.setFillColor(red: r, green: g, blue: b, alpha: CGFloat(alpha)) } else { cg.setStrokeColor(red: r, green: g, blue: b, alpha: CGFloat(alpha)) }
}

/// The face's colour lit from LIGHT, with its opacity (0…255 steps, as Android).
private func pvShade(_ rgb: Int, _ n: V3, _ op: Double, env: Bool) -> (Int, Double) {
    // the floor and the walls stay light: they are only there to stand the piece in its place
    let k = env ? 0.93 + 0.07 * max(0, n.dot(PV_LIGHT)) : 0.66 + 0.34 * max(0, n.dot(PV_LIGHT))
    func c(_ s: Int) -> Int { min(255, max(0, Int(Double((rgb >> s) & 0xFF) * k))) }
    return ((c(16) << 16) | (c(8) << 8) | c(0), Double(min(255, max(0, Int(op * 255)))) / 255)
}

private func pvLine(_ cg: CGContext, _ a: CGPoint, _ b: CGPoint, _ w: CGFloat) {
    cg.setLineWidth(w); cg.setLineCap(.round)
    cg.move(to: a); cg.addLine(to: b); cg.strokePath()
}

/// Whether every corner of q is on the outer side of face i of b.
private func pvOutside(_ b: SBox, _ i: Int, _ q: SBox) -> Bool {
    let nx = b.planes[4 * i], ny = b.planes[4 * i + 1], nz = b.planes[4 * i + 2], dd = b.planes[4 * i + 3] - 1e-6
    for k in 0..<8 where nx * q.pts[3 * k] + ny * q.pts[3 * k + 1] + nz * q.pts[3 * k + 2] < dd { return false }
    return true
}

/// 1 when a goes before b (only b can hide a), -1 the other way, 0 when either may go first (neither hides the other) or
/// no face plane of either parts them. A face plane with one box beyond it and the camera on that side says the other
/// box cannot hide it.
private func pvBefore(_ a: SBox, _ b: SBox, _ e: V3) -> Int {
    var aFirst = false, bFirst = false
    for i in 0..<6 where pvOutside(a, i, b) { if a.faces[i].n.dot(e) > a.planes[4 * i + 3] { aFirst = true } else { bFirst = true } }
    for i in 0..<6 where pvOutside(b, i, a) { if b.faces[i].n.dot(e) > b.planes[4 * i + 3] { bFirst = true } else { aFirst = true } }
    return aFirst == bFirst ? 0 : aFirst ? 1 : -1
}

/// The boards back to front. Sorting faces by their middles shows a shelf through its door and hides a handle behind it,
/// so whole boxes go in order: of two whose pictures overlap, the one beyond a face plane of the other, from the camera,
/// goes first; the rest (and any loop) by their distance.
private func pvDrawOrder(_ bs: [SBox], _ cam: PCam) -> [SBox] {
    let n = bs.count
    let big = Double.greatestFiniteMagnitude
    let rect: [(Double, Double, Double, Double)] = bs.map { b in
        var x0 = big, y0 = big, x1 = -big, y1 = -big
        for k in 0..<8 {
            // a corner behind the camera: it may overlap anything
            guard let o = cam.p(V3(b.pts[3 * k], b.pts[3 * k + 1], b.pts[3 * k + 2])) else { return (-big, -big, big, big) }
            x0 = min(x0, Double(o.x)); y0 = min(y0, Double(o.y)); x1 = max(x1, Double(o.x)); y1 = max(y1, Double(o.y))
        }
        return (x0, y0, x1, y1)
    }
    let dist: [Double] = bs.map { b in
        var s = 0.0
        for k in 0..<8 { s += cam.depth(V3(b.pts[3 * k], b.pts[3 * k + 1], b.pts[3 * k + 2])) }
        return s / 8
    }
    var after = [[Int]](repeating: [], count: n), need = [Int](repeating: 0, count: n)
    for i in 0..<n {
        for j in (i + 1)..<max(i + 1, n) {
            let a = rect[i], b = rect[j]
            if a.0 >= b.2 || b.0 >= a.2 || a.1 >= b.3 || b.1 >= a.3 { continue }
            switch pvBefore(bs[i], bs[j], cam.e) {
            case 1: after[i].append(j); need[j] += 1
            case -1: after[j].append(i); need[i] += 1
            default: break
            }
        }
    }
    // the boxes ready to draw, nearest first: the farthest is taken from the end
    var ready = (0..<n).filter { need[$0] == 0 }.sorted { dist[$0] < dist[$1] }
    var done = [Bool](repeating: false, count: n), out: [SBox] = []
    out.reserveCapacity(n)
    while out.count < n {
        // a loop (boxes that cut into each other): the farthest one left goes next
        let k: Int
        if let r = ready.popLast() { k = r } else { k = (0..<n).filter { !done[$0] }.max { dist[$0] < dist[$1] }! }
        if done[k] { continue }
        done[k] = true; out.append(bs[k])
        for j in after[k] {
            need[j] -= 1
            if need[j] == 0 && !done[j] { ready.insert(j, at: ready.firstIndex { dist[$0] >= dist[j] } ?? ready.count) }
        }
    }
    return out
}

/// Draws the piece into a context of size points: walls facing the camera and the floor first, then the boards back to
/// front; hi a step key to show, az an extra turn in radians, label the value on the line ("?" none yet; nil no pill).
func drawPiece(_ cg: CGContext, _ size: CGSize, _ s: PieceScene, hi: String?, az: Double, label: String?) {
    cg.saveGState(); defer { cg.restoreGState() }
    pvColor(cg, fill: true, PV_BG); cg.fill(CGRect(origin: .zero, size: size))
    guard size.width > 1, size.height > 1 else { return }
    let cam = PCam(s, Double(size.width), Double(size.height), az, hi.map { s.dims[$0] != nil } ?? false)
    let tintTag = hi.flatMap { s.tint[$0] }
    // the boards' outline is one device pixel, as on Android
    let px = min(1, max(0.25, abs(cg.convertToUserSpace(CGSize(width: 1, height: 1)).width)))
    cg.setLineJoin(.round)
    func face(_ fc: SFace, _ faceOut: Bool) {
        var pts: [CGPoint] = []
        pts.reserveCapacity(fc.pts.count)
        for q in fc.pts { guard let p = cam.p(q) else { return }; pts.append(p) }
        if pts.count < 3 { return }
        if faceOut {
            let k = 1 / Double(fc.pts.count)
            let c = V3(fc.pts.reduce(0) { $0 + $1.x } * k, fc.pts.reduce(0) { $0 + $1.y } * k, fc.pts.reduce(0) { $0 + $1.z } * k)
            if fc.n.dot(cam.e - c) <= 0 { return }
        }
        let path = CGMutablePath()
        path.addLines(between: pts); path.closeSubpath()
        // a worktop's top is lit like stone and its outline drawn light, so a dark one shows its thickness
        let base = fc.slab && fc.n.y > 0.9 ? slabTop(fc.rgb) : fc.rgb
        let rgb = tintTag != nil && fc.tag == tintTag ? pvMix(base, PV_HI, 0.55) : base
        let (col, a) = pvShade(rgb, fc.n, fc.op, env: fc.tag == "floor" || fc.tag == "wall")
        pvColor(cg, fill: true, col, a)
        cg.addPath(path); cg.fillPath()
        if fc.tag != "floor" {
            if fc.slab { pvColor(cg, fill: false, SLAB_LINE, Double(0xB0) / 255); cg.setLineWidth(px * 1.4) }
            else { pvColor(cg, fill: false, PV_EDGE, Double(0x40) / 255); cg.setLineWidth(px) }
            cg.addPath(path); cg.strokePath()
        }
    }
    for fc in s.env { face(fc, fc.tag == "wall") }
    // the boards' order kept per 3° of turning: sorting them is the slow part of a frame
    let withDim = hi.map { s.dims[$0] != nil } ?? false
    let turn = az * 60 / Double.pi
    let step = (turn.isFinite ? Int(turn.rounded()) : 0) * 2 + (withDim ? 1 : 0)
    let order = s.cachedOrder([step, Int(size.width), Int(size.height)]) { pvDrawOrder(s.furn, cam) }
    for bx in order { for fc in bx.faces { face(fc, true) } }
    guard let hi, let d = s.dims[hi], let a = cam.p(d.a), let b = cam.p(d.b) else { return }
    let t0 = cam.p(d.a + d.tick * 0.09), t1 = cam.p(d.a - d.tick * 0.09), t2 = cam.p(d.b + d.tick * 0.09), t3 = cam.p(d.b - d.tick * 0.09)
    let w: CGFloat = 3.2
    pvColor(cg, fill: false, PV_BLUE); pvColor(cg, fill: true, PV_BLUE)
    pvLine(cg, a, b, w)
    if let t0, let t1 { pvLine(cg, t0, t1, w * 0.8) }
    if let t2, let t3 { pvLine(cg, t2, t3, w * 0.8) }
    // arrowheads at both ends
    let dx = b.x - a.x, dy = b.y - a.y, l = hypot(dx, dy)
    if l > 1 {
        let ux = dx / l, uy = dy / l, ah = min(11, l / 3)
        func head(_ p: CGPoint, _ sx: CGFloat) {
            let bx = p.x - ux * ah * sx, by = p.y - uy * ah * sx
            cg.move(to: p)
            cg.addLine(to: CGPoint(x: bx - uy * ah * 0.45, y: by + ux * ah * 0.45))
            cg.addLine(to: CGPoint(x: bx + uy * ah * 0.45, y: by - ux * ah * 0.45))
            cg.closePath(); cg.fillPath()
        }
        head(b, 1); head(a, -1)
    }
    guard let label else { return }
    let empty = label == "?"
    let blue = UIColor(red: CGFloat((PV_BLUE >> 16) & 0xFF) / 255, green: CGFloat((PV_BLUE >> 8) & 0xFF) / 255, blue: CGFloat(PV_BLUE & 0xFF) / 255, alpha: 1)
    let text = NSAttributedString(string: label, attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: empty ? blue : UIColor.white])
    let ts = text.size()
    let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    let pw = ts.width + 18, ph = ts.height + 8
    let pill = CGPath(roundedRect: CGRect(x: mid.x - pw / 2, y: mid.y - ph / 2, width: pw, height: ph), cornerWidth: 9, cornerHeight: 9, transform: nil)
    if empty { cg.setFillColor(UIColor.white.cgColor) } else { pvColor(cg, fill: true, PV_BLUE) }
    cg.addPath(pill); cg.fillPath()
    if empty { pvColor(cg, fill: false, PV_BLUE); cg.setLineWidth(2); cg.addPath(pill); cg.strokePath() }
    UIGraphicsPushContext(cg)
    text.draw(at: CGPoint(x: mid.x - ts.width / 2, y: mid.y - ts.height / 2))
    UIGraphicsPopContext()
}

/// The piece as a still picture of size points at the screen's scale (the gallery's cards).
func piecePicture(_ s: PieceScene, _ size: CGSize) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat.preferred()
    fmt.opaque = true
    return UIGraphicsImageRenderer(size: size, format: fmt).image { c in drawPiece(c.cgContext, size, s, hi: nil, az: 0, label: nil) }
}

/// The gallery's pictures, made once from the app's own 3D of each model at its usual size (again when the workshop or
/// the boards change). The 3D and the drawing run off the main thread; each picture shows as soon as it is ready.
@Observable final class PiecePics {
    static let shared = PiecePics()
    private(set) var pics: [String: UIImage] = [:]
    @ObservationIgnored private var madeFor: (Workshop, [Mat])? = nil
    @ObservationIgnored private var job: Task<Void, Never>? = nil

    @MainActor
    func make(_ ws: Workshop, _ mats: [Mat]) {
        if let mf = madeFor, mf.0 == ws, mf.1 == mats {
            if job != nil { return }      // already making this workshop's pictures
        } else {
            job?.cancel(); job = nil; pics = [:]; madeFor = (ws, mats)
        }
        let ids = GALLERY.flatMap { $0.1 }.filter { pics[$0] == nil }
        if ids.isEmpty { return }
        job = Task { @MainActor [weak self] in
            for id in ids {
                if Task.isCancelled { return }
                guard let m = fModel(id) else { continue }
                let img = await Task.detached(priority: .utility) {
                    piecePicture(pieceScene(pieceOf(m, [:], ws, ""), ws, mats), CGSize(width: 200, height: 170))
                }.value
                guard let self, !Task.isCancelled else { return }
                self.pics[id] = img
            }
            if !Task.isCancelled { self?.job = nil }
        }
    }
}

/// The piece live: a horizontal drag turns it (±1.1 rad); hi the step being asked and label its value (or "?").
struct PieceView: View {
    let scene: PieceScene
    let hi: String?
    let label: String?
    @Environment(\.displayScale) private var scale
    @State private var az = 0.0
    /// The turn when this drag began; 0 the drag is not decided yet, 1 it turns the piece, 2 it is a scroll.
    @State private var from = 0.0
    @State private var mode = 0

    init(scene: PieceScene, hi: String?, label: String?) { self.scene = scene; self.hi = hi; self.label = label }

    var body: some View {
        Canvas { ctx, size in
            ctx.withCGContext { cg in drawPiece(cg, size, scene, hi: hi, az: az, label: label) }
        }
        .contentShape(Rectangle())
        // only a mostly sideways drag turns it, so the page still scrolls over the picture (Android detectHorizontalDragGestures)
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { v in
            if mode == 0 { mode = abs(v.translation.width) > abs(v.translation.height) ? 1 : 2; from = az }
            if mode == 1 { az = min(1.1, max(-1.1, from + Double(v.translation.width * scale) / 320)) }
        }.onEnded { _ in mode = 0 })
    }
}
