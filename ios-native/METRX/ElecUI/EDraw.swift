import SwiftUI
import UIKit

/*
 * The electrician's drawings, shared by the screen and the PDF (Android ui/elec/EDraw.kt): a symbol for every device
 * type, the room from above with its devices and coloured routes, and a wall seen straight on with its devices, their
 * heights and the routes on it. Everything is drawn with Core Graphics from millimetres through a mapping (y down, as on
 * Android), so one drawing serves any size; sizes are in points where Android's are in pixels or dp.
 */

let E_INK_RGB = 0x0E1C36
private let E_WALL_RGB = 0x0E1C36
private let E_FLOOR_RGB = 0xF1F4F8
private let E_DOOR_RGB = 0x2E5BFF
private let E_WIN_RGB = 0x9DB8E8
private let E_WATER_RGB = 0x2563EB
private let E_GAS_RGB = 0xEAB308
private let E_WARN_RGB = 0xDC2626

/// A colour for Core Graphics from 0xRRGGBB.
func eCG(_ rgb: Int, _ a: Double = 1) -> CGColor { tileCG(rgb, a) }

/// A colour for SwiftUI from 0xRRGGBB.
func eColor(_ rgb: Int, _ a: Double = 1) -> Color { Color(uiColor: uiColor(rgb, a)) }

/* ---------------- small drawing helpers ---------------- */

private func eFillCircle(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ col: CGColor) {
    cg.setFillColor(col)
    cg.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
}

private func eStrokeCircle(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ col: CGColor, _ w: CGFloat) {
    cg.setStrokeColor(col); cg.setLineWidth(w)
    cg.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
}

private func eLine(_ cg: CGContext, _ a: CGPoint, _ b: CGPoint, _ col: CGColor, _ w: CGFloat, round: Bool = false, dash: [CGFloat]? = nil) {
    cg.saveGState()
    cg.setStrokeColor(col); cg.setLineWidth(w); cg.setLineCap(round ? .round : .butt)
    if let dash { cg.setLineDash(phase: 0, lengths: dash) }
    cg.move(to: a); cg.addLine(to: b); cg.strokePath()
    cg.restoreGState()
}

/// An arc round c of radius r from start degrees for sweep degrees (clockwise on the screen, as Compose's drawArc).
private func eArc(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ start: Double, _ sweep: Double, _ col: CGColor, _ w: CGFloat, dash: [CGFloat]? = nil) {
    let n = 24
    cg.saveGState()
    cg.setStrokeColor(col); cg.setLineWidth(w); cg.setLineCap(.butt)
    if let dash { cg.setLineDash(phase: 0, lengths: dash) }
    for i in 0...n {
        let a = (start + sweep * Double(i) / Double(n)) * Double.pi / 180
        let p = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
        if i == 0 { cg.move(to: p) } else { cg.addLine(to: p) }
    }
    cg.strokePath()
    cg.restoreGState()
}

private func ePoly(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    guard let f = pts.first else { return p }
    p.move(to: f)
    for q in pts.dropFirst() { p.addLine(to: q) }
    p.closeSubpath()
    return p
}

/// Draws attributed text with its top left at p.
func eText(_ cg: CGContext, _ s: NSAttributedString, _ p: CGPoint) {
    UIGraphicsPushContext(cg)
    s.draw(at: p)
    UIGraphicsPopContext()
}

/* ---------------- the symbols ---------------- */

/// A device's symbol centred at c, r its half size: sockets round, switches with a key, lights crossed, low-voltage
/// triangles; col its circuit's colour.
func devSymbol(_ cg: CGContext, _ t: String, _ c: CGPoint, _ r: CGFloat, _ col: CGColor, _ ink0: CGColor? = nil, _ fill0: CGColor? = nil) {
    let ink = ink0 ?? eCG(E_INK_RGB)
    let fill = fill0 ?? eCG(0xFFFFFF)
    let sw = max(1, r * 0.16)
    func pt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: c.x + r * dx, y: c.y + r * dy) }
    func ring(_ cc: CGPoint, _ rr: CGFloat) { eFillCircle(cg, cc, rr, fill); eStrokeCircle(cg, cc, rr, ink, sw) }
    func square(_ rr: CGFloat) {
        let rect = CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr)
        cg.setFillColor(fill); cg.fill(rect)
        cg.setStrokeColor(ink); cg.setLineWidth(sw); cg.stroke(rect)
    }
    func dots() { eFillCircle(cg, pt(-0.38, 0), r * 0.17, ink); eFillCircle(cg, pt(0.38, 0), r * 0.17, ink) }
    func line(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat? = nil) { eLine(cg, a, b, ink, w ?? sw, round: true) }
    func mark() { eFillCircle(cg, pt(0.78, -0.78), r * 0.28, col) }
    switch t {
    case "s1":
        ring(c, r); dots(); mark()
    case "s2":
        ring(pt(-0.45, 0), r * 0.8); ring(pt(0.45, 0), r * 0.8)
        eFillCircle(cg, pt(-0.45, 0), r * 0.13, ink); eFillCircle(cg, pt(0.45, 0), r * 0.13, ink); mark()
    case "sw":
        ring(c, r); dots(); eArc(cg, c, r * 1.25, 200, 140, ink, sw); mark()
    case "su":
        ring(c, r)
        cg.setStrokeColor(ink); cg.setLineWidth(sw); cg.stroke(CGRect(x: c.x - r * 0.42, y: c.y - r * 0.2, width: r * 0.84, height: r * 0.4))
        mark()
    case "pst":
        square(r); line(pt(-0.6, -0.6), pt(0.6, 0.6)); line(pt(-0.6, 0.6), pt(0.6, -0.6)); mark()
    case "pov":
        square(r); line(pt(-0.6, 0), pt(0.6, 0)); line(pt(-0.6, -0.4), pt(0.6, -0.4)); mark()
    case "pac":
        square(r)
        for i in 0..<3 {
            let a = Double.pi * Double(i) / 3
            let cx = CGFloat(cos(a)) * 0.65, sy = CGFloat(sin(a)) * 0.65
            line(pt(-cx, -sy), pt(cx, sy))
        }
        mark()
    case "pwh":
        square(r)
        let p = CGMutablePath()
        p.move(to: pt(0, -0.6)); p.addLine(to: pt(0.45, 0.2)); p.addQuadCurve(to: pt(-0.45, 0.2), control: pt(0, 0.9)); p.closeSubpath()
        cg.addPath(p); cg.setStrokeColor(ink); cg.setLineWidth(sw); cg.strokePath()
        mark()
    case "k1", "k2", "kp", "kd":
        eFillCircle(cg, c, r * 0.62, fill); eStrokeCircle(cg, c, r * 0.62, ink, sw); eFillCircle(cg, c, r * 0.2, ink)
        let tip = pt(1.05, -1.05)
        line(c, tip)
        if t == "k2" { line(pt(0.25, 0.1), pt(1.25, -0.8)) }
        if t == "kp" { line(c, pt(-1.05, 1.05)) }
        if t == "kd" { eArc(cg, c, r * 0.95, -90, 90, ink, sw) }
        line(tip, CGPoint(x: tip.x + r * 0.3, y: tip.y + r * 0.3))
        eFillCircle(cg, pt(-0.8, -0.8), r * 0.24, col)
    case "lc", "lch", "lw":
        if t == "lch" { eFillCircle(cg, c, r * 1.2, fill); eStrokeCircle(cg, c, r * 1.2, ink, sw) }
        ring(c, r)
        line(pt(-0.7, -0.7), pt(0.7, 0.7)); line(pt(-0.7, 0.7), pt(0.7, -0.7))
        if t == "lw" { line(pt(-1.2, 1.15), pt(1.2, 1.15), sw * 1.6) }
        eFillCircle(cg, pt(0.9, -0.9), r * 0.25, col)
    case "ls":
        eFillCircle(cg, c, r * 0.7, fill); eStrokeCircle(cg, c, r * 0.7, ink, sw); eFillCircle(cg, c, r * 0.38, col)
    case "led":
        eLine(cg, pt(-1.3, 0), pt(1.3, 0), col, r * 0.5, dash: [r * 0.5, r * 0.3])
    case "tv", "lan", "int", "cam", "bell":
        let tri = ePoly([pt(0, -1), pt(1, 0.8), pt(-1, 0.8)])
        cg.addPath(tri); cg.setFillColor(fill); cg.fillPath()
        cg.addPath(tri); cg.setStrokeColor(ink); cg.setLineWidth(sw); cg.strokePath()
        switch t {
        case "tv":
            cg.setStrokeColor(ink); cg.setLineWidth(sw * 0.8); cg.stroke(CGRect(x: c.x - r * 0.38, y: c.y, width: r * 0.76, height: r * 0.5))
        case "lan":
            eFillCircle(cg, pt(-0.3, 0.35), r * 0.13, ink); eFillCircle(cg, pt(0.3, 0.35), r * 0.13, ink)
        case "int":
            line(pt(-0.35, 0.1), pt(0.35, 0.1)); line(pt(-0.35, 0.45), pt(0.35, 0.45))
        case "cam":
            eFillCircle(cg, pt(0, 0.3), r * 0.22, ink)
        default:
            eArc(cg, pt(0, 0.3), r * 0.35, 180, 180, ink, sw)
        }
    case "jb":
        square(r * 0.8); line(pt(-0.8, 0.8), pt(0.8, -0.8))
    case "panel":
        let rect = CGRect(x: c.x - r * 1.1, y: c.y - r * 0.8, width: r * 2.2, height: r * 1.6)
        cg.setFillColor(fill); cg.fill(rect)
        cg.addPath(ePoly([pt(-1.1, 0.8), pt(1.1, -0.8), pt(1.1, 0.8)])); cg.setFillColor(ink); cg.fillPath()
        cg.setStrokeColor(ink); cg.setLineWidth(sw); cg.stroke(rect)
    default:
        ring(c, r)
    }
}

/* ---------------- the room from above ---------------- */

/// How the room from above maps into a box: plan mm → points, the room fitted and centred with margin round it.
struct EPlanMap {
    let x0: Double, y0: Double, k: Double, ox: Double, oy: Double
    init(_ c: ECtx, _ box: CGRect, _ margin: CGFloat) { self.init(c.g.floor, box, margin) }

    /// Floor outline f fitted into box (a plumber's room uses it too).
    init(_ f: [V2], _ box: CGRect, _ margin: CGFloat) {
        let b = tBoxOf(f)
        x0 = b.x0; y0 = b.y0
        let w = max(1, b.x1 - b.x0), h = max(1, b.y1 - b.y0)
        let m = Double(margin)
        let kk = max(1e-6, min((Double(box.width) - 2 * m) / w, (Double(box.height) - 2 * m) / h))
        k = kk
        ox = Double(box.minX) + (Double(box.width) - w * kk) / 2
        oy = Double(box.minY) + (Double(box.height) - h * kk) / 2
    }
    func at(_ q: V2) -> CGPoint { CGPoint(x: ox + (q.x - x0) * k, y: oy + (q.y - y0) * k) }
    func back(_ o: CGPoint) -> V2 { V2((Double(o.x) - ox) / k + x0, (Double(o.y) - oy) / k + y0) }
}

private func eDistPt(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

/// The room from above: the floor, the walls, the doors with their swing, the windows, the water and gas, the routes in
/// their circuits' colours, the panel and every device (sel ringed, bad in red). sym the symbols' half size.
func drawElecPlan(_ cg: CGContext, _ c: ECtx, _ m: EPlanMap, _ ds: [ElecDev], _ pn: ElecPanel?, _ runs: [CRun], _ circuitOf: (String) -> Circuit?,
                  _ sym: CGFloat, sel: String? = nil, bad: Set<String> = [], routes: Bool = true) {
    let outline = ePoly(c.g.floor.map { m.at($0) })
    cg.addPath(outline); cg.setFillColor(eCG(E_FLOOR_RGB)); cg.fillPath()
    cg.saveGState()
    cg.addPath(outline); cg.setStrokeColor(eCG(E_WALL_RGB)); cg.setLineWidth(max(2, sym * 0.45)); cg.setLineJoin(.miter); cg.strokePath()
    cg.restoreGState()
    // the routes over the walls' line: a run along a wall is drawn just inside it, each circuit a little further in
    if routes {
        for (k, r) in runs.enumerated() {
            let col = eCG(r.circuit.rgb)
            let inset = Double(sym) * (0.55 + 0.3 * Double(k % 5)) / m.k
            for g in r.segs {
                let n = c.wall(g.wall)?.nIn
                let a = m.at(n.map { g.a + $0 * inset } ?? g.a)
                let b = m.at(n.map { g.b + $0 * inset } ?? g.b)
                if eDistPt(a, b) > 0.5 { eLine(cg, a, b, col, max(1.2, sym * 0.22), round: true) }
            }
        }
    }
    for o in c.room.openings {
        guard let w = c.wall(o.wall) else { continue }
        let a = m.at(w.at(Double(o.off))), b = m.at(w.at(Double(o.off + o.w)))
        if o.type == "door" {
            eLine(cg, a, b, eCG(E_FLOOR_RGB), max(3, sym * 0.6))
            // the leaf open into the room, hinged at the door's near edge
            let tip = m.at(w.at(Double(o.off), Double(o.w)))
            eLine(cg, a, tip, eCG(E_DOOR_RGB), max(1.2, sym * 0.2))
            let rad = eDistPt(tip, a)
            let st = atan2(Double(b.y - a.y), Double(b.x - a.x)) * 180 / Double.pi
            let en = atan2(Double(tip.y - a.y), Double(tip.x - a.x)) * 180 / Double.pi
            var sweep = en - st
            while sweep > 180 { sweep -= 360 }
            while sweep < -180 { sweep += 360 }
            eArc(cg, a, rad, st, sweep, eCG(E_DOOR_RGB), max(1, sym * 0.12), dash: [4, 3])
        } else {
            eLine(cg, a, b, eCG(E_WIN_RGB), max(3, sym * 0.55))
        }
    }
    for x in c.room.points where WATER_T.contains(x.t) || GAS_T.contains(x.t) {
        guard let w = c.wall(x.wall) else { continue }
        eFillCircle(cg, m.at(w.at(Double(x.off), 60)), sym * 0.45, eCG(WATER_T.contains(x.t) ? E_WATER_RGB : E_GAS_RGB))
    }
    if let pn, pn.roomId == c.id, let w = c.wall(pn.wall) {
        let at = m.at(w.at(Double(pn.off), 130))
        devSymbol(cg, "panel", at, sym * 1.1, eCG(E_INK_RGB))
        if sel == "panel" { eStrokeCircle(cg, at, sym * 1.9, eCG(E_DOOR_RGB), 2) }
    }
    // wall devices close together along a wall step into the room one after another, so each symbol shows
    var placed: [(String, Double)] = []
    for d in eSortedBy(ds, { Double($0.h) }) {
        let col = circuitOf(d.id).map { eCG($0.rgb) } ?? eCG(0x94A3B8)
        let ink = eCG(bad.contains(d.id) ? E_WARN_RGB : E_INK_RGB)
        var at: CGPoint? = nil
        if d.onCeiling {
            at = m.at(V2(Double(d.cx), Double(d.cy)))
        } else if let w = c.wall(d.wall) {
            if d.t == "led" {
                let l = Double(devSize(d).0)
                eLine(cg, m.at(w.at(Double(d.off) - l / 2, 70)), m.at(w.at(Double(d.off) + l / 2, 70)), col, max(2, sym * 0.4))
            } else {
                let lim = 2.2 * Double(sym) / m.k
                let near = placed.filter { $0.0 == w.id && abs($0.1 - Double(d.off)) < lim }.count
                placed.append((w.id, Double(d.off)))
                let into = Double(sym) * (1.6 + 1.9 * Double(near)) / m.k
                at = m.at(w.at(Double(d.off), into))
            }
        }
        if let at {
            devSymbol(cg, d.t, at, d.t == "ls" ? sym * 0.8 : sym, col, ink)
            if d.id == sel { eStrokeCircle(cg, at, sym * 1.7, eCG(E_DOOR_RGB), 2) }
        }
    }
}

/* ---------------- a wall straight on ---------------- */

/// A wall seen straight on, fitted into a box: along-the-wall mm and height mm → points.
struct EWallMap {
    let len: Double, H: Double, k: Double, x0: Double, yF: Double
    init(_ len: Double, _ H: Double, _ box: CGRect, _ margin: CGFloat, _ bottom: CGFloat? = nil) {
        self.len = len; self.H = H
        let m = Double(margin), bt = Double(bottom ?? margin)
        let kk = max(1e-6, min((Double(box.width) - 2 * m) / max(len, 1), (Double(box.height) - m - bt) / max(H, 1)))
        k = kk
        x0 = Double(box.minX) + (Double(box.width) - len * kk) / 2
        yF = Double(box.minY) + m + H * kk
    }
    func x(_ a: Double) -> CGFloat { CGFloat(x0 + a * k) }
    func y(_ h: Double) -> CGFloat { CGFloat(yF - h * k) }
    func at(_ a: Double, _ h: Double) -> CGPoint { CGPoint(x: x(a), y: y(h)) }
}

/// Wall w of room c straight on: its doors and windows, water and gas, the cable run under the ceiling (dashed), the
/// routes on it, the panel and the devices, each with its height when label is given (sel ringed, bad in red).
func drawElecWall(_ cg: CGContext, _ c: ECtx, _ w: TWall, _ m: EWallMap, _ ds: [ElecDev], _ pn: ElecPanel?, _ runs: [CRun], _ circuitOf: (String) -> Circuit?,
                  _ label: ((String) -> NSAttributedString)?, sel: String? = nil, bad: Set<String> = [], drag: (String, CGPoint)? = nil, minR: CGFloat = 6) {
    let H = c.g.H
    let k = CGFloat(m.k)
    let wallRect = CGRect(x: m.x(0), y: m.y(H), width: CGFloat(w.len) * k, height: CGFloat(H) * k)
    cg.setFillColor(eCG(0xF7F9FC)); cg.fill(wallRect)
    cg.setStrokeColor(eCG(E_WALL_RGB)); cg.setLineWidth(2); cg.stroke(wallRect)
    // the run under the ceiling
    let zy = m.y(H - Double(ZONE_DOWN))
    eLine(cg, CGPoint(x: m.x(0), y: zy), CGPoint(x: m.x(w.len), y: zy), eCG(0x3E4A61, 0x55 / 255.0), 1, dash: [6, 5])
    for o in c.room.openings where o.wall == w.id {
        let tl = m.at(Double(o.off), Double(o.sill + o.h))
        let rect = CGRect(x: tl.x, y: tl.y, width: CGFloat(o.w) * k, height: CGFloat(o.h) * k)
        if o.type == "door" {
            cg.setFillColor(eCG(0xFFFFFF)); cg.fill(rect)
            cg.setStrokeColor(eCG(E_DOOR_RGB)); cg.setLineWidth(1.5); cg.stroke(rect)
            // the side it opens to: the hinge edge thick, and where the open door stands (no switch there)
            eLine(cg, m.at(Double(o.off), 0), m.at(Double(o.off), Double(o.h)), eCG(E_DOOR_RGB), 3)
            let back = m.at(max(0, Double(o.off - o.w)), Double(o.h))
            cg.setFillColor(eCG(E_DOOR_RGB, 0x14 / 255.0))
            cg.fill(CGRect(x: back.x, y: back.y, width: m.x(Double(o.off)) - back.x, height: CGFloat(o.h) * k))
        } else {
            cg.setFillColor(eCG(0xE5EEFB)); cg.fill(rect)
            cg.setStrokeColor(eCG(E_WIN_RGB)); cg.setLineWidth(1.5); cg.stroke(rect)
        }
    }
    for x in c.room.points where x.wall == w.id && (WATER_T.contains(x.t) || GAS_T.contains(x.t)) {
        eFillCircle(cg, m.at(Double(x.off), Double(x.h)), max(3, 40 * k), eCG(WATER_T.contains(x.t) ? E_WATER_RGB : E_GAS_RGB))
    }
    for r in runs {
        let col = eCG(r.circuit.rgb)
        for g in r.segs where g.wall == w.id {
            let a = (g.a - w.p0).dot(w.t), b = (g.b - w.p0).dot(w.t)
            eLine(cg, m.at(a, g.za), m.at(b, g.zb), col, max(1.5, 22 * k), round: true)
        }
    }
    let r0 = max(minR, 55 * k)
    if let pn, pn.roomId == c.id, pn.wall == w.id {
        let (pw, ph) = panelSize(0)
        let at: CGPoint = (drag != nil && drag!.0 == "panel") ? drag!.1 : m.at(Double(pn.off), Double(pn.h))
        let bw = CGFloat(pw) * k, bh = CGFloat(ph) * k
        let box = CGRect(x: at.x - bw / 2, y: at.y - bh / 2, width: bw, height: bh)
        cg.setFillColor(eCG(0xCBD5E1)); cg.fill(box)
        cg.setStrokeColor(eCG(E_INK_RGB)); cg.setLineWidth(1.5); cg.stroke(box)
        devSymbol(cg, "panel", at, r0 * 0.8, eCG(E_INK_RGB))
        if sel == "panel" { cg.setStrokeColor(eCG(E_DOOR_RGB)); cg.setLineWidth(2); cg.stroke(box.insetBy(dx: -4, dy: -4)) }
        if let label {
            let t = label("\(pn.h)")
            eText(cg, t, CGPoint(x: at.x + bw / 2 + 3, y: at.y - t.size().height / 2))
        }
    }
    // the heights: beside the device where neither another height nor a device's symbol is, else left out (as the plumber's)
    var symbols: [CGRect] = []
    for d in ds where d.wall == w.id && d.t != "led" {
        let a: CGPoint = (drag != nil && drag!.0 == d.id) ? drag!.1 : m.at(Double(d.off), Double(d.h))
        symbols.append(CGRect(x: a.x - r0, y: a.y - r0, width: 2 * r0, height: 2 * r0))
    }
    var taken: [CGRect] = []
    for d in ds.filter({ $0.wall == w.id }).sorted(by: { $0.off < $1.off }) {
        let col = circuitOf(d.id).map { eCG($0.rgb) } ?? eCG(0x94A3B8)
        let ink = eCG(bad.contains(d.id) ? E_WARN_RGB : E_INK_RGB)
        let dragged: CGPoint? = (drag != nil && drag!.0 == d.id) ? drag!.1 : nil
        let at = dragged ?? m.at(Double(d.off), Double(d.h))
        if d.t == "led" {
            let l = CGFloat(devSize(d).0) * k
            eLine(cg, CGPoint(x: at.x - l / 2, y: at.y), CGPoint(x: at.x + l / 2, y: at.y), col, max(3, 30 * k))
            if d.id == sel { cg.setStrokeColor(eCG(E_DOOR_RGB)); cg.setLineWidth(2); cg.stroke(CGRect(x: at.x - l / 2 - 4, y: at.y - 8, width: l + 8, height: 16)) }
            continue
        }
        // its height: a thin line down to the floor and the number
        if let label {
            eLine(cg, CGPoint(x: at.x, y: at.y + r0), CGPoint(x: at.x, y: m.y(0)), eCG(0x3E4A61, 0x55 / 255.0), 1, dash: [3, 3])
            let hh = dragged.map { tInt((m.yF - Double($0.y)) / m.k) } ?? d.h
            let t = label("\(hh)")
            let sz = t.size()
            let own = CGRect(x: at.x - r0, y: at.y - r0, width: 2 * r0, height: 2 * r0)
            let spots: [CGPoint] = [CGPoint(x: at.x + r0 * 0.9, y: at.y + r0 * 0.3), CGPoint(x: at.x - r0 * 0.9 - sz.width, y: at.y + r0 * 0.3),
                                    CGPoint(x: at.x + r0 * 0.9, y: at.y - r0 * 0.3 - sz.height), CGPoint(x: at.x - r0 * 0.9 - sz.width, y: at.y - r0 * 0.3 - sz.height)]
            let free = spots.map { CGRect(origin: $0, size: sz) }.first { r in
                !taken.contains { $0.intersects(r) } && !symbols.contains { $0 != own && $0.intersects(r) }
            }
            if let free { taken.append(free); eText(cg, t, free.origin) }
        }
        devSymbol(cg, d.t, at, r0, col, ink)
        if d.id == sel { eStrokeCircle(cg, at, r0 * 1.7, eCG(E_DOOR_RGB), 2) }
    }
    // the floor line
    eLine(cg, CGPoint(x: m.x(0) - 6, y: m.y(0)), CGPoint(x: m.x(w.len) + 6, y: m.y(0)), eCG(E_WALL_RGB), 3)
}

/// The types shown, in the legend's order.
func legendTypes(_ ds: [ElecDev]) -> [String] { DEV_TYPES.map(\.id).filter { t in ds.contains { $0.t == t } } }

/// A device type's symbol as a small view (the lists and sheets).
struct DevSymbolView: View {
    let t: String
    let rgb: Int
    var ink: Int = E_INK_RGB
    var k: CGFloat = 3.4
    var body: some View {
        Canvas { ctx, size in
            let t = self.t, rgb = self.rgb, ink = self.ink, k = self.k
            ctx.withCGContext { cg in
                devSymbol(cg, t, CGPoint(x: size.width / 2, y: size.height / 2), min(size.width, size.height) / k, eCG(rgb), eCG(ink))
            }
        }
        .allowsHitTesting(false)
    }
}
