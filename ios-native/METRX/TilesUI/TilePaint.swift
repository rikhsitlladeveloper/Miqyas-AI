import SwiftUI
import UIKit
import Observation

/*
 * The tiles drawn by the app itself (no photos; Android ui/tiles/TilePaint.kt): a tile's look (a colour, or a drawn
 * marble, wood or concrete), the gallery's cards and the steps' picture (a sample corner of a room in perspective, with
 * the real pattern on it), and the swatches. Drawn with Core Graphics, y down as on Android; sizes are in points where
 * Android's are in dp.
 */

func tileCG(_ rgb: Int, _ a: Double = 1) -> CGColor { uiColor(rgb, a).cgColor }

/// A tiny repeatable random number in [0, 1) from a seed (Android's 32-bit arithmetic, wrapping as Kotlin's Int does).
private func rnd(_ seed: Int, _ k: Int) -> Double {
    var x = Int32(truncatingIfNeeded: seed) &* 374761393 &+ Int32(truncatingIfNeeded: k) &* 668265263
    x = (x ^ Int32(bitPattern: UInt32(bitPattern: x) >> 13)) &* 1274126177
    let y = x ^ Int32(bitPattern: UInt32(bitPattern: x) >> 16)
    return Double(Int(y) & 0xFFFFFF) / 16777216
}

private func pathOf(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    if pts.isEmpty { return p }
    p.move(to: pts[0])
    for i in 1..<pts.count { p.addLine(to: pts[i]) }
    p.closeSubpath()
    return p
}

/// The texture of one tile: at maps the tile's own coordinates (s along its long side, t across, both 0…1) to the
/// screen. Marble veins, wood grain or concrete specks; a plain colour has none.
private func tileTexture(_ cg: CGContext, _ look: TileLook, _ seed: Int, _ at: (Double, Double) -> CGPoint?, _ px: CGFloat) {
    switch look.kind {
    case "m":
        let vc = tileCG(look.vein, 0.5)
        for k in 0..<2 {
            let path = CGMutablePath()
            let t0 = rnd(seed, 10 + k), t1 = rnd(seed, 20 + k)
            for i in 0...8 {
                let s = Double(i) / 8
                let wob = (rnd(seed, 30 + i + 9 * k) - 0.5) * 0.12
                let t = t0 + (t1 - t0) * s + wob
                guard let o = at(s, min(max(t, 0), 1)) else { return }
                if i == 0 { path.move(to: o) } else { path.addLine(to: o) }
            }
            cg.addPath(path)
            cg.setStrokeColor(vc); cg.setLineWidth(k == 0 ? 1.4 * px : 0.8 * px); cg.setLineCap(.round)
            cg.strokePath()
        }
    case "w":
        let gc = tileCG(scaleRgb(look.rgb, 0.78), 0.38)
        for k in 0..<5 {
            let path = CGMutablePath()
            let tb = (Double(k) + 0.5) / 5 + (rnd(seed, 40 + k) - 0.5) * 0.1
            let ph = rnd(seed, 50 + k) * 6.28
            for i in 0...10 {
                let s = Double(i) / 10
                let t = tb + 0.03 * sin(ph + s * 9)
                guard let o = at(s, min(max(t, 0), 1)) else { return }
                if i == 0 { path.move(to: o) } else { path.addLine(to: o) }
            }
            cg.addPath(path)
            cg.setStrokeColor(gc); cg.setLineWidth(0.8 * px); cg.setLineCap(.butt)
            cg.strokePath()
        }
    case "k":
        for k in 0..<9 {
            guard let o = at(rnd(seed, 60 + k), rnd(seed, 70 + k)) else { return }
            let r = CGFloat(0.6 + rnd(seed, 80 + k)) * px
            cg.setFillColor(tileCG(scaleRgb(look.rgb, k % 3 == 0 ? 1.15 : 0.8), 0.55))
            cg.fillEllipse(in: CGRect(x: o.x - r, y: o.y - r, width: 2 * r, height: 2 * r))
        }
    default: break
    }
}

/// Draws the pieces of laid for layout l; map puts a surface's point on the screen (nil: behind the eye). textures
/// draws the looks' veins and grain on tiles bigger than a few points.
func drawLaid(_ cg: CGContext, _ laid: Laid, _ l: TileLayout, _ map: (Surf) -> ((V2) -> CGPoint?), _ textures: Bool, _ cutK: Double = 0.3, outline: Bool = false) {
    var bySurf: [Int: [TPiece]] = [:]
    for pc in laid.pieces { bySurf[pc.s, default: []].append(pc) }
    let px: CGFloat = 1
    for (si, s) in laid.surfs.enumerated() {
        let m = map(s)
        let main = lookFor(l, s.alt ? 1 : 0)
        let grout = tileCG(groutOf(main.rgb))
        // the joints: the surface less its holes, in the grout's colour
        for poly in backingOf(s) {
            let pts = poly.compactMap { m($0) }
            if pts.count != poly.count || pts.count < 3 { continue }
            cg.addPath(pathOf(pts)); cg.setFillColor(grout); cg.fillPath()
        }
        for pc in bySurf[si] ?? [] { drawPieceT(cg, pc, l, m, textures, px, cutK, outline ? grout : nil) }
    }
}

private func drawPieceT(_ cg: CGContext, _ pc: TPiece, _ l: TileLayout, _ m: @escaping (V2) -> CGPoint?, _ textures: Bool, _ px: CGFloat, _ cutK: Double, _ line: CGColor?) {
    let lk = lookFor(l, pc.prod)
    let rgb = pc.cut && cutK > 0 ? cutRgb(lk.rgb, cutK) : toneOf(lk, pc.seed)
    var paths: [CGPath] = []
    for poly in pc.polys {
        let pts = poly.compactMap { m($0) }
        if pts.count != poly.count { return }
        paths.append(pathOf(pts))
    }
    let fill = tileCG(rgb)
    for p in paths { cg.addPath(p); cg.setFillColor(fill); cg.fillPath() }
    // small pictures: the joints as thin lines, or a 2 mm joint would vanish
    if let line { for p in paths { cg.addPath(p); cg.setStrokeColor(line); cg.setLineWidth(0.6 * px); cg.strokePath() } }
    if !textures || lk.kind == "c" || pc.c.count < 4 { return }
    let c = pc.c
    let along = pc.vert ? c[3] - c[0] : c[1] - c[0]
    let across = pc.vert ? c[1] - c[0] : c[3] - c[0]
    guard let o0 = m(c[0]), let o1 = m(c[0] + along) else { return }
    if hypot(o1.x - o0.x, o1.y - o0.y) < 9 * px { return }
    let at = { (s: Double, t: Double) -> CGPoint? in m(c[0] + along * s + across * t) }
    if pc.cut {
        for p in paths {
            cg.saveGState(); cg.addPath(p); cg.clip()
            tileTexture(cg, lk, pc.seed, at, px)
            cg.restoreGState()
        }
    } else {
        tileTexture(cg, lk, pc.seed, at, px)
    }
}

/* ---------------- a sample corner of a room in perspective ---------------- */

/// A camera looking into the sample room's corner from beyond its open side.
struct TCam {
    let e: V3, f: V3, r: V3, u: V3, w: Double, h: Double, foc: Double
    init(_ eye: V3, _ tgt: V3, _ w: Double, _ h: Double, _ half: Double = 0.5) {
        let ff = (tgt - eye).unit
        let rr = ff.cross(V3(0, 1, 0)).unit
        e = eye; f = ff; r = rr; u = rr.cross(ff)
        self.w = w; self.h = h
        foc = (h / 2) / tan(half)
    }
    func p(_ q: V3) -> CGPoint? {
        let d = q - e
        let z = d.dot(f)
        if z < 0.05 { return nil }
        return CGPoint(x: w / 2 + d.dot(r) / z * foc, y: h / 2 - d.dot(u) / z * foc)
    }
}

/// The sample room the gallery and the steps show a layout in: laid its tiles, which walls stand, and a bath or worktop.
struct TPreview {
    let l: TileLayout, g: TRoomGeo, laid: Laid, floorTiled: Bool, bath: TFix?, counter: Bool
}

private let SAMPLE: Room = {
    var r = Room(id: "sample", floorId: "", name: "")
    r.dims = ["A": Dim(v: 3200), "B": Dim(v: 2600), "H": Dim(v: 2400), "T": Dim(v: 120, src: "default")]
    return r
}()

/// The surfaces a layout of its place shows in the sample room: the floor, the two far walls, the backsplash band, the
/// bath's front.
func sampleSurfs(_ l: TileLayout) -> [TSurf] {
    let m = tModel(l.model)
    let surf: String
    if l.place == "floor" { surf = "floor" }
    else if l.place == "apron" { surf = "apron" }
    else if m?.surf == "floor" { surf = "floor" }
    else if !l.surfs.isEmpty && l.surfs.allSatisfy({ $0.id == "floor" }) { surf = "floor" }
    else { surf = "walls" }
    switch surf {
    case "floor": return [TSurf(id: "floor")]
    case "apron": return [TSurf(id: "A", mode: "band", h0: APRON_H0, h1: APRON_H1)]
    default:
        var out = [TSurf(id: "A"), TSurf(id: "D", alt: l.accent)]
        if l.place == "bath" { out.append(TSurf(id: "bath:b")) }
        return out
    }
}

func previewOf(_ l0: TileLayout) -> TPreview? {
    let bath: TFix? = l0.place == "bath" ? TFix(id: "b", type: "bath", wall: "A", off: 0, w: 1700, d: 700, h: 560) : nil
    guard let g = roomGeo(SAMPLE, true, bath.map { [$0] } ?? []) else { return nil }
    var l = l0
    l.surfs = sampleSurfs(l0); l.roomId = "sample"; l.ox = 0; l.oy = 0; l.align = false
    let laid = layAll(l, surfacesOf(l, g), g, nil, drawInset(l))
    return TPreview(l: l, g: g, laid: laid, floorTiled: l.surfs.contains { $0.id == "floor" }, bath: bath, counter: l0.place == "apron")
}

private let WALL_RGB = 0xEEF0F3
private let FLOOR_RGB = 0xE2E6EC
private let PREVIEW_BG = 0xF6F8FC

private func quad(_ cg: CGContext, _ cam: TCam, _ pts: [V3], _ rgb: Int) {
    var o: [CGPoint] = []
    for q in pts { guard let s = cam.p(q) else { return }; o.append(s) }
    cg.addPath(pathOf(o)); cg.setFillColor(tileCG(rgb)); cg.fillPath()
}

/// Draws a sample room's corner with the layout on it; az turns the view a little (a drag).
func drawPreview(_ cg: CGContext, _ size: CGSize, _ pv: TPreview, _ az: Double = 0, textures: Bool = true, cutK: Double = 0.15) {
    cg.saveGState(); defer { cg.restoreGState() }
    cg.setFillColor(tileCG(PREVIEW_BG)); cg.fill(CGRect(origin: .zero, size: size))
    guard size.width > 1, size.height > 1 else { return }
    let g = pv.g
    let L = 3.2 + 0.12, W = 2.6, H = 2.4
    let a = 0.78 + az
    let dist = 5.2
    let low = pv.l.place == "floor" || pv.floorTiled
    let tgt = V3(L * 0.42, low ? 0.2 : H * 0.42, W * 0.4)
    let eye = V3(tgt.x + dist * cos(a) * 0.95, tgt.y + (pv.floorTiled ? 3.4 : 1.5), tgt.z + dist * sin(a) * 0.95)
    let cam = TCam(eye, tgt, Double(size.width), Double(size.height), pv.floorTiled ? 0.37 : 0.41)
    let fl = g.floorFrame
    // the floor, and the far walls A and D
    quad(cg, cam, g.floor.map { fl.at($0.x, $0.y) }, FLOOR_RGB)
    for id in ["A", "D"] {
        guard let w = g.wall(id) else { continue }
        let fr = g.wallFrame(w)
        quad(cg, cam, [fr.at(0, 0), fr.at(w.len, 0), fr.at(w.len, g.H), fr.at(0, g.H)], id == "A" ? WALL_RGB : scaleRgb(WALL_RGB, 0.96))
    }
    drawLaid(cg, pv.laid, pv.l, { s in { q in cam.p(s.frame.at(q.x, q.y, 0.002)) } }, textures, cutK, outline: true)
    // the corner's line
    if let w = g.wall("A") {
        let fr = g.wallFrame(w)
        if let p0 = cam.p(fr.at(0, 0)), let p1 = cam.p(fr.at(0, g.H)) {
            cg.move(to: p0); cg.addLine(to: p1)
            cg.setStrokeColor(tileCG(0x101828, 0.2)); cg.setLineWidth(1); cg.strokePath()
        }
    }
    drawBox(cg, cam, eye, pv, textures, cutK)
}

/// A bath, or the worktop and the units under it, with a bath's tiled front over it.
private func drawBox(_ cg: CGContext, _ cam: TCam, _ eye: V3, _ pv: TPreview, _ textures: Bool, _ cutK: Double) {
    let g = pv.g
    var fp: [V2]? = nil
    var h = 0.0
    if let f = pv.bath, let foot = footprint(g, f) { fp = foot; h = Double(f.h) }
    else if pv.counter, let w = g.wall("A") { fp = [w.at(0), w.at(w.len), w.at(w.len, 600), w.at(0, 600)]; h = Double(APRON_H0) - 40 }
    guard let foot = fp else { return }
    let sc = foot.map { g.scene($0) }
    let top = sc.map { V3($0.x, h / 1000, $0.z) }
    var cx = 0.0, cz = 0.0
    for q in sc { cx += q.x; cz += q.z }
    cx /= 4; cz /= 4
    for i in 0..<sc.count {
        let p = sc[i], q = sc[(i + 1) % sc.count]
        var nx = q.z - p.z, nz = -(q.x - p.x)
        if ((p.x + q.x) / 2 - cx) * nx + ((p.z + q.z) / 2 - cz) * nz < 0 { nx = -nx; nz = -nz }
        if nx * (eye.x - p.x) + nz * (eye.z - p.z) <= 0 { continue }
        // the bath's front is tiled (its tiles are drawn on it below)
        quad(cg, cam, [p, q, V3(q.x, h / 1000, q.z), V3(p.x, h / 1000, p.z)], pv.counter ? 0xE9E7E2 : 0xF4F4F1)
    }
    quad(cg, cam, top, pv.counter ? 0x8E7962 : 0xFBFBFA)
    if pv.counter { quad(cg, cam, top.map { V3($0.x, h / 1000 + 0.04, $0.z) }, 0x9C8670) }
    // a bath's front panel with its tiles, again over the box
    guard let front = pv.laid.surfs.firstIndex(where: { $0.kind == "bath" }) else { return }
    let s = pv.laid.surfs[front]
    let pcs = pv.laid.pieces.filter { $0.s == front }.map { TPiece(polys: $0.polys, area: $0.area, full: $0.full, prod: $0.prod, pw: $0.pw, ph: $0.ph, rectish: $0.rectish,
                                                                   c: $0.c, vert: $0.vert, seed: $0.seed, s: 0) }
    let sub = Laid(surfs: [s], pieces: pcs, tooMany: [])
    drawLaid(cg, sub, pv.l, { ss in { q in cam.p(ss.frame.at(q.x, q.y, 0.003)) } }, textures, cutK, outline: true)
}

/// A layout's picture as a still image (the gallery's cards).
func previewPicture(_ l: TileLayout, _ size: CGSize) -> UIImage? {
    guard let pv = previewOf(l) else { return nil }
    let fmt = UIGraphicsImageRendererFormat.preferred()
    fmt.opaque = true
    return UIGraphicsImageRenderer(size: size, format: fmt).image { c in drawPreview(c.cgContext, size, pv, cutK: 0) }
}

/// The gallery's pictures, made once from the app's own drawing of each card's layout, away from the main thread.
@Observable final class TilePics {
    static let shared = TilePics()
    private(set) var pics: [String: UIImage] = [:]
    @ObservationIgnored private var job: Task<Void, Never>? = nil

    @MainActor
    func make() {
        if job != nil { return }
        let ids = T_MODELS.map(\.id).filter { pics[$0] == nil }
        if ids.isEmpty { return }
        job = Task { @MainActor [weak self] in
            for id in ids {
                if Task.isCancelled { return }
                guard let m = tModel(id) else { continue }
                let img = await Task.detached(priority: .utility) { previewPicture(layoutOf(m, m.id), CGSize(width: 200, height: 170)) }.value
                guard let self, !Task.isCancelled else { return }
                if let img { self.pics[id] = img }
            }
            self?.job = nil
        }
    }
}

/// A layout's sample-room picture, worked out again only when the layout changes.
final class TPreviewCache {
    private var l: TileLayout? = nil
    private var pv: TPreview? = nil
    func get(_ x: TileLayout) -> TPreview? {
        if let l, l == x { return pv }
        l = x; pv = previewOf(x)
        return pv
    }
}

/// The layout live in the sample room: a sideways drag turns it a little.
struct PreviewView: View {
    let pv: TPreview?
    @Environment(\.displayScale) private var scale
    @State private var az = 0.0
    /// The turn when this drag began; 0 the drag is not decided yet, 1 it turns the room, 2 it is a scroll.
    @State private var from = 0.0
    @State private var mode = 0

    var body: some View {
        Canvas { ctx, size in
            ctx.withCGContext { cg in
                if let pv { drawPreview(cg, size, pv, az) }
                else { cg.setFillColor(tileCG(PREVIEW_BG)); cg.fill(CGRect(origin: .zero, size: size)) }
            }
        }
        .contentShape(Rectangle())
        // only a mostly sideways drag turns it, so the page still scrolls over the picture
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { v in
            if mode == 0 { mode = abs(v.translation.width) > abs(v.translation.height) ? 1 : 2; from = az }
            if mode == 1 { az = min(0.55, max(-0.55, from - Double(v.translation.width * scale) / 400)) }
        }.onEnded { _ in mode = 0 })
    }
}

/// A tile's look as a swatch: four tiles with their joints.
struct LookSwatch: View {
    let id: String
    var body: some View {
        Canvas { ctx, size in
            ctx.withCGContext { cg in drawSwatch(cg, size, lookOf(id)) }
        }
        .allowsHitTesting(false)
    }
}

private func drawSwatch(_ cg: CGContext, _ size: CGSize, _ lk: TileLook) {
    cg.setFillColor(tileCG(groutOf(lk.rgb))); cg.fill(CGRect(origin: .zero, size: size))
    let gap: CGFloat = 2
    let n = 2
    let s = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
    for i in 0..<n {
        for k in 0..<n {
            let x0 = CGFloat(i) * (s + gap), y0 = CGFloat(k) * (s + gap)
            cg.setFillColor(tileCG(toneOf(lk, i * 3 + k)))
            cg.fill(CGRect(x: x0, y: y0, width: s, height: s))
            cg.saveGState(); cg.clip(to: CGRect(x: x0, y: y0, width: s, height: s))
            tileTexture(cg, lk, i * 5 + k * 11 + 3, { a, b in CGPoint(x: x0 + CGFloat(a) * s, y: y0 + CGFloat(b) * s) }, 1)
            cg.restoreGState()
        }
    }
}
