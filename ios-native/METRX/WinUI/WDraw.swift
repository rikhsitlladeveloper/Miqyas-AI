import SwiftUI
import UIKit
import Observation

/*
 * The windows-and-doors drawings, shared by the screens and the PDF (Android ui/win/WDraw.kt): a product seen straight
 * on from inside (the elevation) with its sashes, the opening symbols (the triangle's tip on the hinge side; a tilt's
 * tip at the bottom, dashed; a slider's arrow), its handles and its sizes; the product in a piece of wall in
 * perspective (the gallery's cards and the designer's 3D), drawn from the same boxes as the room's 3D; and the room from
 * above with the products, their swings and what stands in the way. Drawn with Core Graphics; sizes are in points where
 * Android's are pixels.
 */

let WD_INK = 0x1E293B
let WD_THIN = 0x64748B
private let WD_GLASS = 0xDCEBFA
private let WD_PANEL = 0xE5E7EB
private let WD_SEL = 0x2E5BFF
private let WD_WARN = 0xDC2626
private let WD_DIM = 0x475569
private let WD_BG = 0xF6F8FC

/* ---------------- small helpers ---------------- */

private func wdLine(_ cg: CGContext, _ a: CGPoint, _ b: CGPoint, _ col: CGColor, _ w: CGFloat, dash: [CGFloat]? = nil, round: Bool = false) {
    cg.saveGState()
    cg.setStrokeColor(col); cg.setLineWidth(w); cg.setLineCap(round ? .round : .butt)
    if let dash { cg.setLineDash(phase: 0, lengths: dash) }
    cg.move(to: a); cg.addLine(to: b); cg.strokePath()
    cg.restoreGState()
}

private func wdFillRect(_ cg: CGContext, _ r: CGRect, _ col: CGColor) { cg.setFillColor(col); cg.fill(r) }

private func wdStrokeRect(_ cg: CGContext, _ r: CGRect, _ col: CGColor, _ w: CGFloat) {
    cg.saveGState()
    cg.setStrokeColor(col); cg.setLineWidth(w); cg.setLineDash(phase: 0, lengths: [])
    cg.stroke(r)
    cg.restoreGState()
}

func wdPoly(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    guard let f = pts.first else { return p }
    p.move(to: f)
    for q in pts.dropFirst() { p.addLine(to: q) }
    p.closeSubpath()
    return p
}

/// A colour 0xRRGGBB with each channel times k.
func wdShade(_ rgb: Int, _ k: Double) -> Int {
    let r = min(255, Int(Double((rgb >> 16) & 0xFF) * k))
    let g = min(255, Int(Double((rgb >> 8) & 0xFF) * k))
    let b = min(255, Int(Double(rgb & 0xFF) * k))
    return (r << 16) | (g << 8) | b
}

/// How light a colour is, 0…1 (a dark leaf gets light lines).
private func wdLuma(_ rgb: Int) -> Double {
    let r = Double((rgb >> 16) & 0xFF) / 255, g = Double((rgb >> 8) & 0xFF) / 255, b = Double(rgb & 0xFF) / 255
    return r * 0.3 + g * 0.59 + b * 0.11
}

/* ---------------- straight on ---------------- */

/// A product straight on, fitted into a box: mm across from its left and up from its bottom → points.
struct WElevMap {
    let w: Double, h: Double, k: Double, x0: Double, yB: Double
    init(_ w: Double, _ h: Double, _ box: CGRect, _ margin: CGFloat, _ bottom: CGFloat? = nil, _ left: CGFloat? = nil) {
        let mg = Double(margin), bt = Double(bottom ?? margin), lf = Double(left ?? margin)
        let bw = Double(box.width), bh = Double(box.height)
        self.w = max(w, 1); self.h = max(h, 1)
        let kk = min((bw - lf - mg) / self.w, (bh - mg - bt) / self.h)
        k = max(kk, 1e-6)
        x0 = Double(box.minX) + lf + (bw - lf - mg - self.w * k) / 2
        yB = Double(box.minY) + mg + self.h * k
    }
    func x(_ a: Double) -> CGFloat { CGFloat(x0 + a * k) }
    func y(_ z: Double) -> CGFloat { CGFloat(yB - z * k) }
    func at(_ a: Double, _ z: Double) -> CGPoint { CGPoint(x: x(a), y: y(z)) }
    func back(_ o: CGPoint) -> V2 { V2((Double(o.x) - x0) / k, (yB - Double(o.y)) / k) }
    /// The rectangle x0…x1, y0…y1 (mm) in points.
    func rect(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> CGRect {
        let tl = at(ax, by)
        return CGRect(x: tl.x, y: tl.y, width: CGFloat((bx - ax) * k), height: CGFloat((by - ay) * k))
    }
}

/// A dimension line from a to b with its ticks, its text t beside it (right of a vertical one, over a level one).
func wdDimLine(_ cg: CGContext, _ a: CGPoint, _ b: CGPoint, _ t: NSAttributedString?, _ vertical: Bool) {
    let ink = eCG(WD_DIM)
    wdLine(cg, a, b, ink, 1)
    let tk: CGFloat = 4
    if vertical {
        wdLine(cg, CGPoint(x: a.x - tk, y: a.y), CGPoint(x: a.x + tk, y: a.y), ink, 1)
        wdLine(cg, CGPoint(x: b.x - tk, y: b.y), CGPoint(x: b.x + tk, y: b.y), ink, 1)
    } else {
        wdLine(cg, CGPoint(x: a.x, y: a.y - tk), CGPoint(x: a.x, y: a.y + tk), ink, 1)
        wdLine(cg, CGPoint(x: b.x, y: b.y - tk), CGPoint(x: b.x, y: b.y + tk), ink, 1)
    }
    guard let t else { return }
    let sz = t.size()
    if vertical {
        let my = (a.y + b.y) / 2
        eText(cg, t, CGPoint(x: a.x + 4, y: my - sz.height / 2))
    } else {
        let mx = (a.x + b.x) / 2
        if sz.width < abs(b.x - a.x) + 30 { eText(cg, t, CGPoint(x: mx - sz.width / 2, y: a.y - sz.height - 1)) }
    }
}

private func wdArrow(_ cg: CGContext, _ from: CGPoint, _ to: CGPoint, _ stroke: CGFloat, _ ink: CGColor) {
    wdLine(cg, from, to, ink, stroke * 0.8)
    let dx = to.x - from.x, dy = to.y - from.y
    let l = max(hypot(dx, dy), 1)
    let ux = dx / l, uy = dy / l
    let nx = -uy, ny = ux
    let h: CGFloat = 9
    wdLine(cg, to, CGPoint(x: to.x - ux * h + nx * h * 0.6, y: to.y - uy * h + ny * h * 0.6), ink, stroke * 0.8)
    wdLine(cg, to, CGPoint(x: to.x - ux * h - nx * h * 0.6, y: to.y - uy * h - ny * h * 0.6), ink, stroke * 0.8)
}

/// A sash's symbol in its glass g: lines from the handle side's corners to the hinge side's middle; a tilt's from the
/// top corners to the bottom middle (dashed); a slider's arrow; the handle.
func wdSashSymbol(_ cg: CGContext, _ t: String, _ hinge: String, _ g: CGRect, _ handles: Bool, _ stroke: CGFloat) {
    let ink = eCG(WD_INK)
    let left = hinge != "R"
    let w = stroke * 0.7
    if t == "turn" || t == "tt" {
        let tip = CGPoint(x: left ? g.minX : g.maxX, y: g.midY)
        let far = left ? g.maxX : g.minX
        wdLine(cg, CGPoint(x: far, y: g.minY), tip, ink, w)
        wdLine(cg, CGPoint(x: far, y: g.maxY), tip, ink, w)
    }
    if t == "tilt" || t == "tt" {
        let tip = CGPoint(x: g.midX, y: g.maxY)
        wdLine(cg, CGPoint(x: g.minX, y: g.minY), tip, ink, w, dash: [7, 5])
        wdLine(cg, CGPoint(x: g.maxX, y: g.minY), tip, ink, w, dash: [7, 5])
    }
    if t == "slide" {
        let y = g.midY
        let a = CGPoint(x: g.minX + g.width * 0.2, y: y), b = CGPoint(x: g.maxX - g.width * 0.2, y: y)
        wdArrow(cg, left ? b : a, left ? a : b, stroke, ink)
    }
    if !handles { return }
    // the handle: on the side away from the hinges, a tilt's at the top, a slider's on its closing edge
    let hs = max(3, min(g.width, g.height) * 0.05)
    cg.setFillColor(ink)
    switch t {
    case "tilt":
        let at = CGPoint(x: g.midX, y: g.minY + hs * 1.5)
        cg.fill(CGRect(x: at.x - hs * 1.6, y: at.y - hs * 0.4, width: hs * 3.2, height: hs * 0.8))
    case "slide":
        let at = CGPoint(x: left ? g.maxX - hs : g.minX + hs, y: g.midY)
        cg.fill(CGRect(x: at.x - hs * 0.4, y: at.y - hs * 1.6, width: hs * 0.8, height: hs * 3.2))
    default:
        let at = CGPoint(x: left ? g.maxX - hs * 1.2 : g.minX + hs * 1.2, y: g.midY)
        cg.fill(CGRect(x: at.x - hs * 0.4, y: at.y - hs * 1.6, width: hs * 0.8, height: hs * 3.2))
    }
}

/// A door's face: its frame, the leaf (glass for a glass door), the handle and how it opens.
private func wdDoorFace(_ cg: CGContext, _ it: WinItem, _ m: WElevMap, _ cin: Int, _ stroke: CGFloat) {
    let W = Double(it.w), H = Double(it.h), F = Double(W_DOOR_FRAME)
    let leaf = m.rect(F, 10, W - F, H - F)
    let leafRgb: Int = it.kind == "dgl" ? WD_GLASS : wdShade(cin, 0.93)
    wdFillRect(cg, leaf, eCG(leafRgb))
    wdStrokeRect(cg, leaf, eCG(WD_INK), stroke * 0.6)
    let left = it.hinge != "R"
    let dark = it.kind != "dgl" && wdLuma(cin) < 0.45
    if it.kind == "dsl" {
        let y = leaf.midY
        let a = CGPoint(x: leaf.minX + leaf.width * 0.25, y: y), b = CGPoint(x: leaf.maxX - leaf.width * 0.25, y: y)
        wdArrow(cg, left ? b : a, left ? a : b, stroke, eCG(WD_INK))
    } else {
        // the tip on the hinge side, dashed when it opens away from the viewer
        let tip = CGPoint(x: left ? leaf.minX : leaf.maxX, y: leaf.midY)
        let far = left ? leaf.maxX : leaf.minX
        let dash: [CGFloat]? = it.swing == "out" ? [7, 5] : nil
        // on a dark leaf the lines are light
        let ink: CGColor = dark ? eCG(0xFFFFFF, 0.9) : eCG(WD_INK)
        wdLine(cg, CGPoint(x: far, y: leaf.minY), tip, ink, stroke * 0.7, dash: dash)
        wdLine(cg, CGPoint(x: far, y: leaf.maxY), tip, ink, stroke * 0.7, dash: dash)
    }
    if it.handles {
        let hx = left ? m.x(W - F - 70) : m.x(F + 70)
        let hy = m.y(1000)
        let u = CGFloat(m.k)
        let hInk: CGColor = dark ? eCG(0xD1D5DB) : eCG(WD_INK)
        cg.setFillColor(hInk)
        cg.fill(CGRect(x: hx - 15 * u, y: hy - 60 * u, width: 30 * u, height: 120 * u))
        let dir: CGFloat = left ? -1 : 1
        wdLine(cg, CGPoint(x: hx, y: hy), CGPoint(x: hx + dir * 110 * u, y: hy), hInk, max(1, 22 * u), round: true)
    }
}

/// One sash of a window straight on: its glass, panel or own profile with its symbol; ringed when chosen; its size.
private func wdSash(_ cg: CGContext, _ it: WinItem, _ s: WSash, _ m: WElevMap, _ edge: CGColor, _ sel: (Int, Int)?, _ small: ((String) -> NSAttributedString)?, _ stroke: CGFloat) {
    let c = s.r
    let cr = m.rect(c.x0, c.y0, c.x1, c.y1)
    let S = Double(wSashF(it.profile))
    if s.t == "panel" {
        wdFillRect(cg, cr, eCG(WD_PANEL))
        cg.saveGState()
        cg.clip(to: cr)
        var d = -cr.height
        while d < cr.width {
            wdLine(cg, CGPoint(x: cr.minX + d, y: cr.maxY), CGPoint(x: cr.minX + d + cr.height, y: cr.minY), eCG(WD_THIN, 0.35), 1)
            d += 9
        }
        cg.restoreGState()
        wdStrokeRect(cg, cr, edge, stroke * 0.6)
    } else if s.opens {
        // the sash's own profile round its glass
        wdStrokeRect(cg, cr, edge, stroke * 0.6)
        let gx0 = m.x(c.x0 + S), gy0 = m.y(c.y1 - S)
        let gw = max(CGFloat((c.w - 2 * S) * m.k), 1), gh = max(CGFloat((c.h - 2 * S) * m.k), 1)
        let g = CGRect(x: gx0, y: gy0, width: gw, height: gh)
        wdFillRect(cg, g, eCG(WD_GLASS))
        wdStrokeRect(cg, g, edge, stroke * 0.5)
        wdSashSymbol(cg, s.t, s.cell.hinge, g, it.handles, stroke)
    } else {
        wdFillRect(cg, cr, eCG(WD_GLASS))
        wdStrokeRect(cg, cr, edge, stroke * 0.6)
    }
    if let sel, sel.0 == s.col, sel.1 == s.row {
        wdStrokeRect(cg, cr.insetBy(dx: -2, dy: -2), eCG(WD_SEL), 3)
    }
    if let small {
        let t = small("\(tInt(eMathRoundP(c.w))) × \(tInt(eMathRoundP(c.h)))")
        let sz = t.size()
        if sz.width < cr.width - 4 && sz.height < cr.height - 4 {
            eText(cg, t, CGPoint(x: cr.minX + (cr.width - sz.width) / 2, y: cr.maxY - sz.height - 3))
        }
    }
}

/// Product it straight on from inside in map m: the frame and mullions in its inside colour, glass, panels, the opening
/// sashes' own profile, symbols and handles; sel a sash ringed (column, row), bad in red. label makes the sizes' texts:
/// the whole width and height outside, each column's width over it; small each sash's size inside it.
func drawWinElevation(_ cg: CGContext, _ it: WinItem, _ m: WElevMap, sel: (Int, Int)? = nil, bad: Bool = false,
                      label: ((String) -> NSAttributedString)? = nil, small: ((String) -> NSAttributedString)? = nil, stroke: CGFloat = 1.5) {
    let W = Double(it.w), H = Double(it.h)
    let cin = wColourRgb(it.colIn)
    let edge = eCG(bad ? WD_WARN : WD_INK)
    let whole = m.rect(0, 0, W, H)
    wdFillRect(cg, whole, eCG(cin))
    if it.isDoor {
        wdDoorFace(cg, it, m, cin, stroke)
    } else {
        for s in wSashesOf(it) { wdSash(cg, it, s, m, edge, sel, small, stroke) }
    }
    wdStrokeRect(cg, whole, edge, stroke)
    guard let label else { return }
    // the sizes: the width under it, the height to its right, each column's width over it
    let gapPx: CGFloat = 10
    let by = m.y(0) + gapPx + 12
    wdDimLine(cg, CGPoint(x: m.x(0), y: by), CGPoint(x: m.x(W), y: by), nil, false)
    let wt = label("\(it.w)")
    let wsz = wt.size()
    eText(cg, wt, CGPoint(x: (m.x(0) + m.x(W)) / 2 - wsz.width / 2, y: m.y(0) + gapPx + 14))
    wdDimLine(cg, CGPoint(x: m.x(W) + gapPx, y: m.y(H)), CGPoint(x: m.x(W) + gapPx, y: m.y(0)), label("\(it.h)"), true)
    if it.cols.count > 1 {
        var a = 0.0
        let y = m.y(H) - 8
        for c in it.cols {
            let cw = Double(c.w)
            wdDimLine(cg, CGPoint(x: m.x(a), y: y), CGPoint(x: m.x(a + cw), y: y), label("\(c.w)"), false)
            a += cw
        }
    }
}

/* ---------------- in perspective ---------------- */

/// How a product is shown in a piece of wall: t the wall's thickness, floor it stands on the floor.
struct WPicSpec {
    let it: WinItem
    let t: Int
    let floor: Bool
}

/// One face of a box in the picture: its corners, the way it faces, how dark.
private struct WDFace {
    let pts: [V3]
    let n: V3
    let shade: Double
}

/// Product s.it in a piece of wall, seen from inside a little from the side (az turns the view): the wall's face round
/// the opening, the reveals, the product's boxes; what sticks out of the wall (the sill, handles) last.
func drawProductPic(_ cg: CGContext, _ size: CGSize, _ s: WPicSpec, _ az: Double = 0) {
    cg.saveGState(); defer { cg.restoreGState() }
    cg.setFillColor(eCG(WD_BG)); cg.fill(CGRect(origin: .zero, size: size))
    guard size.width > 1, size.height > 1 else { return }
    let it = s.it
    let W = Double(it.w), H = Double(it.h), g = Double(it.gap), T = Double(s.t)
    let bot: Double = s.floor ? 0 : -g
    let top = H + g
    let ext = max(W, H)
    let side = max(250.0, ext * 0.14)
    let wl = -g - side, wr = W + g + side
    let wb: Double = s.floor ? 0 : bot - side
    let wt = top + max(200.0, ext * 0.1)
    func v(_ a: Double, _ d: Double, _ z: Double) -> V3 { V3(a / 1000, z / 1000, d / 1000) }
    let tgt = v(W / 2, 0, (wb + wt) / 2)
    let ang = 0.55 + az
    let dist = (max(wr - wl, wt - wb) / 1000) * 1.05
    let eye = V3(tgt.x + dist * sin(ang), tgt.y + dist * 0.18, tgt.z + dist * cos(ang))
    let cam = TCam(eye, tgt, Double(size.width), Double(size.height), 0.55)
    func quad(_ pts: [V3], _ col: CGColor, _ line: CGColor? = nil) {
        var o: [CGPoint] = []
        for q in pts {
            guard let p = cam.p(q) else { return }
            o.append(p)
        }
        let path = wdPoly(o)
        cg.addPath(path); cg.setFillColor(col); cg.fillPath()
        if let line { cg.addPath(path); cg.setStrokeColor(line); cg.setLineWidth(0.8); cg.strokePath() }
    }
    let wallC = eCG(0xECEFF3), revealC = eCG(0xDCE1E8)
    // the floor in front of a door
    if s.floor { quad([v(wl, 0, 0), v(wr, 0, 0), v(wr, 2200, 0), v(wl, 2200, 0)], eCG(0xE2E6EC)) }
    // the sky through the opening, then its reveals
    quad([v(-g, -T, bot), v(W + g, -T, bot), v(W + g, -T, top), v(-g, -T, top)], eCG(0xCFE3F8))
    quad([v(-g, -T, bot), v(-g, 0, bot), v(-g, 0, top), v(-g, -T, top)], revealC)
    quad([v(W + g, -T, bot), v(W + g, 0, bot), v(W + g, 0, top), v(W + g, -T, top)], revealC)
    quad([v(-g, -T, top), v(W + g, -T, top), v(W + g, 0, top), v(-g, 0, top)], eCG(0xC9D0DA))
    if !s.floor { quad([v(-g, -T, bot), v(W + g, -T, bot), v(W + g, 0, bot), v(-g, 0, bot)], eCG(0xE6EAF0)) }
    let boxes = wProductBoxes(it, s.t, s.floor)
    func drawBox(_ b: WBox) {
        let faces: [WDFace] = [
            WDFace(pts: [v(b.a0, b.d1, b.z0), v(b.a1, b.d1, b.z0), v(b.a1, b.d1, b.z1), v(b.a0, b.d1, b.z1)], n: V3(0, 0, 1), shade: 1),
            WDFace(pts: [v(b.a0, b.d0, b.z1), v(b.a1, b.d0, b.z1), v(b.a1, b.d1, b.z1), v(b.a0, b.d1, b.z1)], n: V3(0, 1, 0), shade: 0.95),
            WDFace(pts: [v(b.a0, b.d0, b.z0), v(b.a1, b.d0, b.z0), v(b.a1, b.d1, b.z0), v(b.a0, b.d1, b.z0)], n: V3(0, -1, 0), shade: 0.7),
            WDFace(pts: [v(b.a0, b.d0, b.z0), v(b.a0, b.d1, b.z0), v(b.a0, b.d1, b.z1), v(b.a0, b.d0, b.z1)], n: V3(-1, 0, 0), shade: 0.82),
            WDFace(pts: [v(b.a1, b.d0, b.z0), v(b.a1, b.d1, b.z0), v(b.a1, b.d1, b.z1), v(b.a1, b.d0, b.z1)], n: V3(1, 0, 0), shade: 0.82)
        ]
        for f in faces {
            var cx = 0.0, cy = 0.0, cz = 0.0
            for q in f.pts { cx += q.x; cy += q.y; cz += q.z }
            cx /= 4; cy /= 4; cz /= 4
            let facing = (eye.x - cx) * f.n.x + (eye.y - cy) * f.n.y + (eye.z - cz) * f.n.z
            if facing <= 0 { continue }
            let col = eCG(wdShade(b.rgb, f.shade), b.op)
            quad(f.pts, col, b.glass ? nil : eCG(0x101828, 0.2))
        }
    }
    func far(_ b: WBox) -> Double {
        let cx = (b.a0 + b.a1) / 2000, cy = (b.z0 + b.z1) / 2000, cz = (b.d0 + b.d1) / 2000
        return (eye.x - cx) * (eye.x - cx) + (eye.y - cy) * (eye.y - cy) + (eye.z - cz) * (eye.z - cz)
    }
    // in the wall first (glass last among them, so the frame shows through it), then the wall's face, then what stands out of it
    let inWall = boxes.filter { $0.d1 <= 1 }
    for b in eSortedBy(inWall.filter { !$0.glass }, { -far($0) }) { drawBox(b) }
    for b in eSortedBy(inWall.filter { $0.glass }, { -far($0) }) { drawBox(b) }
    quad([v(wl, 0, wb), v(-g, 0, wb), v(-g, 0, wt), v(wl, 0, wt)], wallC)
    quad([v(W + g, 0, wb), v(wr, 0, wb), v(wr, 0, wt), v(W + g, 0, wt)], wallC)
    quad([v(-g, 0, top), v(W + g, 0, top), v(W + g, 0, wt), v(-g, 0, wt)], wallC)
    if !s.floor { quad([v(-g, 0, wb), v(W + g, 0, wb), v(W + g, 0, bot), v(-g, 0, bot)], wallC) }
    for b in eSortedBy(boxes.filter { $0.d1 > 1 }, { -far($0) }) { drawBox(b) }
}

/// The sample of a gallery type: its usual size in a 300 wall, a window with its sill and drip.
func wSamplePic(_ kind: String) -> WPicSpec {
    let k = wkind(kind)
    let floor = k.isDoor || k.id == "balc" || k.id == "pano"
    var it = wNewItem("s-" + kind, k)
    if !k.isDoor && !floor {
        it.sill = wSillFor(wRevealOf(300, wFrameDepth(it)))
        it.drip = true
    }
    return WPicSpec(it: it, t: 300, floor: floor)
}

/// A picture as a still image.
func wPicture(_ s: WPicSpec, _ size: CGSize, _ az: Double = 0) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat.preferred()
    fmt.opaque = true
    return UIGraphicsImageRenderer(size: size, format: fmt).image { c in drawProductPic(c.cgContext, size, s, az) }
}

/// The gallery's pictures, made once from the app's own drawing of each type, away from the main thread.
@Observable final class WinPics {
    static let shared = WinPics()
    private(set) var pics: [String: UIImage] = [:]
    @ObservationIgnored private var job: Task<Void, Never>? = nil

    @MainActor
    func make() {
        if job != nil { return }
        let ids = W_KINDS.map(\.id).filter { pics[$0] == nil }
        if ids.isEmpty { return }
        job = Task { @MainActor [weak self] in
            for id in ids {
                if Task.isCancelled { return }
                let img = await Task.detached(priority: .utility) { () -> UIImage? in
                    wPicture(wSamplePic(id), CGSize(width: 200, height: 170))
                }.value
                guard let self, !Task.isCancelled else { return }
                if let img { self.pics[id] = img }
            }
            self?.job = nil
        }
    }
}

/// A product live in its piece of wall: a sideways drag turns it a little.
struct WPicView: View {
    let spec: WPicSpec
    var lo = -0.9
    var hi = 0.5
    @Environment(\.displayScale) private var scale
    @State private var az = 0.0
    /// The turn when this drag began; 0 the drag is not decided yet, 1 it turns the view, 2 it is a scroll.
    @State private var from = 0.0
    @State private var mode = 0

    var body: some View {
        Canvas { ctx, size in
            let s = self.spec, a = self.az
            ctx.withCGContext { cg in drawProductPic(cg, size, s, a) }
        }
        .contentShape(Rectangle())
        // only a mostly sideways drag turns it, so the page still scrolls over the picture
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { v in
            if mode == 0 { mode = abs(v.translation.width) > abs(v.translation.height) ? 1 : 2; from = az }
            if mode == 1 { az = min(hi, max(lo, from - Double(v.translation.width * scale) / 400)) }
        }.onEnded { _ in mode = 0 })
    }
}

/* ---------------- from above ---------------- */

private let WD_FLOOR = 0xF1F4F8
private let WD_WALL = 0x334155

/// Room c from above: the floor and walls, the openings (an empty door with its usual swing), the products in theirs
/// (sel in blue, bad in red), where the sashes and leaves sweep, and what stands in the room (obs, grey).
func drawWinPlan(_ cg: CGContext, _ c: WCtx, _ m: EPlanMap, _ pls: [WPlaced], _ sweeps: [WSweep], _ obs: [WObst], _ sym: CGFloat,
                 sel: String? = nil, bad: Set<String> = []) {
    let out = wdPoly(c.g.floor.map { m.at($0) })
    cg.addPath(out); cg.setFillColor(eCG(WD_FLOOR)); cg.fillPath()
    for ob in obs where ob.poly.count >= 3 {
        let path = wdPoly(ob.poly.map { m.at($0) })
        cg.addPath(path); cg.setFillColor(eCG(0x475569, 0.2)); cg.fillPath()
        cg.addPath(path); cg.setStrokeColor(eCG(0x475569, 0.6)); cg.setLineWidth(1); cg.strokePath()
    }
    for sw in sweeps where sw.poly.count >= 3 {
        let path = wdPoly(sw.poly.map { m.at($0) })
        let rgb = bad.contains(sw.item) ? WD_WARN : WD_SEL
        cg.addPath(path); cg.setFillColor(eCG(rgb, 0.08)); cg.fillPath()
        cg.saveGState()
        cg.setLineDash(phase: 0, lengths: [5, 4])
        cg.addPath(path); cg.setStrokeColor(eCG(rgb, 0.55)); cg.setLineWidth(1); cg.strokePath()
        cg.restoreGState()
    }
    cg.saveGState()
    cg.addPath(out); cg.setStrokeColor(eCG(WD_WALL)); cg.setLineWidth(max(2, sym * 0.45)); cg.setLineJoin(.miter); cg.strokePath()
    cg.restoreGState()
    let filled = Set(pls.map(\.o.id))
    for o in c.room.openings {
        guard let w = c.wall(o.wall) else { continue }
        let a = m.at(w.at(Double(o.off))), b = m.at(w.at(Double(o.off + o.w)))
        wdLine(cg, a, b, eCG(WD_FLOOR), max(3, sym * 0.6))
        if !filled.contains(o.id) {
            let rgb = o.type == "door" ? 0x94A3B8 : 0x7FA6E0
            wdLine(cg, a, b, eCG(rgb), max(1.5, sym * 0.25), dash: [4, 3])
        }
    }
    for pl in pls {
        let w = pl.w
        let rgb: Int = bad.contains(pl.it.id) ? WD_WARN : (pl.it.id == sel ? WD_SEL : WD_INK)
        let d0 = -Double(pl.r), d1 = d0 - Double(pl.depth)
        let iw = Double(pl.it.w)
        let q = [w.at(pl.a0, d0), w.at(pl.a0 + iw, d0), w.at(pl.a0 + iw, d1), w.at(pl.a0, d1)].map { m.at($0) }
        let path = wdPoly(q)
        let fill = pl.it.isDoor ? wColourRgb(pl.it.colIn) : W_GLASS_RGB
        cg.addPath(path); cg.setFillColor(eCG(fill)); cg.fillPath()
        cg.addPath(path); cg.setStrokeColor(eCG(rgb)); cg.setLineWidth(max(1.5, sym * 0.22)); cg.strokePath()
        if pl.it.sill > 0 && !pl.it.isDoor {
            let sd = Double(pl.it.sill) + d0
            let sp = wdPoly([w.at(pl.a0 - 50, d0), w.at(pl.a0 + iw + 50, d0), w.at(pl.a0 + iw + 50, sd), w.at(pl.a0 - 50, sd)].map { m.at($0) })
            cg.addPath(sp); cg.setFillColor(eCG(0xFFFFFF)); cg.fillPath()
            cg.addPath(sp); cg.setStrokeColor(eCG(rgb, 0.6)); cg.setLineWidth(1); cg.strokePath()
        }
    }
}
