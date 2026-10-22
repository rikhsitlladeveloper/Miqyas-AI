import SwiftUI
import UIKit

/*
 * The plumber's drawings, shared by the screen and the PDF (Android ui/plumb/PDraw.kt): a top-view symbol for every
 * fixture, the room from above with its fixtures, the riser, the pipes in their colours and the underfloor loops, and a
 * wall seen straight on with its fixtures, outlets and their heights and the pipes on it. Drawn with Core Graphics from
 * millimetres through the electrician's mappings (EPlanMap, EWallMap); sizes are in points where Android's are pixels.
 */

let P_INK_RGB = 0x0E1C36
private let PD_FLOOR = 0xF1F4F8
private let PD_DOOR = 0x2E5BFF
private let PD_WIN = 0x9DB8E8
private let PD_WARN = 0xDC2626

/// The layers the views show: water (cold and hot), drains, heating (supply, return, the floor's loops).
let P_LAYERS = ["water", "drain", "heat"]
func layerOf(_ kind: String) -> String {
    switch kind {
    case "cold", "hot": return "water"
    case "drain": return "drain"
    default: return "heat"
    }
}

/* ---------------- small drawing helpers ---------------- */

private func pdFill(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ col: CGColor) {
    cg.setFillColor(col)
    cg.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
}

private func pdRing(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ col: CGColor, _ w: CGFloat) {
    cg.setStrokeColor(col); cg.setLineWidth(w)
    cg.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
}

private func pdLine(_ cg: CGContext, _ a: CGPoint, _ b: CGPoint, _ col: CGColor, _ w: CGFloat, round: Bool = false, dash: [CGFloat]? = nil) {
    cg.saveGState()
    cg.setStrokeColor(col); cg.setLineWidth(w); cg.setLineCap(round ? .round : .butt)
    if let dash { cg.setLineDash(phase: 0, lengths: dash) }
    cg.move(to: a); cg.addLine(to: b); cg.strokePath()
    cg.restoreGState()
}

/// An arc round c of radius r from start degrees for sweep degrees (clockwise on the screen, as Compose's drawArc).
private func pdArc(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ start: Double, _ sweep: Double, _ col: CGColor, _ w: CGFloat, dash: [CGFloat]? = nil) {
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

private func pdPoly(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    guard let f = pts.first else { return p }
    p.move(to: f)
    for q in pts.dropFirst() { p.addLine(to: q) }
    p.closeSubpath()
    return p
}

private func pdRect(_ cg: CGContext, _ r: CGRect, fill: CGColor? = nil, stroke: CGColor? = nil, _ w: CGFloat = 1) {
    if let fill { cg.setFillColor(fill); cg.fill(r) }
    if let stroke { cg.setStrokeColor(stroke); cg.setLineWidth(w); cg.stroke(r) }
}

private func pdDist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

/* ---------------- the fixtures from above ---------------- */

/// A fixture's top view drawn in its own frame: lp maps (mm along the wall from its centre, mm into the room) to points.
private func drawFixTop(_ cg: CGContext, _ t: String, _ fw: Double, _ fd: Double, _ lp: @escaping (Double, Double) -> CGPoint, _ ink: CGColor, _ sw: CGFloat, _ cab: Bool) {
    func poly(_ q: [(Double, Double)], fill: CGColor? = nil) {
        let path = pdPoly(q.map { lp($0.0, $0.1) })
        if let fill { cg.addPath(path); cg.setFillColor(fill); cg.fillPath() }
        cg.addPath(path); cg.setStrokeColor(ink); cg.setLineWidth(sw); cg.strokePath()
    }
    func oval(_ a: Double, _ d: Double, _ ra: Double, _ rd: Double, fill: CGColor? = nil) {
        var q: [(Double, Double)] = []
        for i in 0..<16 {
            let k = 2 * Double.pi * Double(i) / 16
            q.append((a + ra * cos(k), d + rd * sin(k)))
        }
        poly(q, fill: fill)
    }
    let white = eCG(0xFFFFFF)
    let h = fw / 2
    poly([(-h, 0), (h, 0), (h, fd), (-h, fd)], fill: white)
    switch t {
    case "wc":
        poly([(-h, 0), (h, 0), (h, 170), (-h, 170)])
        oval(0, 400, 160, 220)
    case "bs", "bsm":
        oval(0, fd * 0.55, fw * 0.36, fd * 0.32)
        if cab { poly([(-h + 10, fd - 20), (h - 10, fd - 20)]) }
    case "bath":
        poly([(-h + 70, 70), (h - 70, 70), (h - 70, fd - 70), (-h + 70, fd - 70)])
        oval(-h + 200, fd / 2, 30, 30)
    case "sh", "cab":
        poly([(-h, 0), (h, fd)])
        poly([(h, 0), (-h, fd)])
        oval(0, fd / 2, 40, 40, fill: white)
        if t == "cab" { poly([(-h, fd - 8), (h, fd - 8)]) }
    case "sink":
        poly([(-250, 100), (250, 100), (250, fd - 100), (-250, fd - 100)])
        oval(0, fd / 2, 30, 30)
    case "wm":
        oval(0, fd / 2, fw * 0.33, fd * 0.33)
    case "dw":
        poly([(-h + 60, fd - 60), (h - 60, fd - 60)])
        poly([(-h + 60, fd - 120), (h - 60, fd - 120)])
    case "wh":
        oval(0, fd / 2, fw * 0.42, fd * 0.42)
    case "gb":
        poly([(-60, fd * 0.3), (0, fd * 0.8), (60, fd * 0.3)])
    case "rad":
        var a = -h + 80
        while a < h - 1 { poly([(a, 10), (a, fd)]); a += 80 }
    case "tr":
        poly([(-h, 60), (h, 60)])
    case "manif":
        var a = -h + 60
        while a < h - 1 { oval(a, fd / 2, 18, 18); a += 80 }
    default: break
    }
}

/// A fixture's symbol for the lists and the legend: its top view fitted into a square r half wide at c.
func fixSymbol(_ cg: CGContext, _ t: String, _ c: CGPoint, _ r: CGFloat, _ ink0: CGColor? = nil) {
    let ink = ink0 ?? eCG(P_INK_RGB)
    let ty = fixType(t)
    let fw = Double(ty.w), fd = Double(ty.d)
    let k = Double(2 * r) / max(fw, fd)
    let cx = Double(c.x), cy = Double(c.y)
    drawFixTop(cg, t, fw, fd, { a, d in CGPoint(x: cx + a * k, y: cy - fd / 2 * k + d * k) }, ink, max(1, r * 0.1), false)
}

/// An outlet's symbol: a dot in its kind's colour.
func ptSymbol(_ cg: CGContext, _ t: String, _ c: CGPoint, _ r: CGFloat, _ ring0: CGColor? = nil) {
    pdFill(cg, c, r, eCG(kindRgb(t)))
    pdRing(cg, c, r, ring0 ?? eCG(0xFFFFFF), max(1, r * 0.3))
}

/// The riser's symbol: its box with the drain stack and the water pipes.
func riserSymbol(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ hot: Bool = true) {
    let box = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    pdRect(cg, box, fill: eCG(0xFFFFFF), stroke: eCG(P_INK_RGB), max(1, r * 0.15))
    pdFill(cg, CGPoint(x: c.x - r * 0.3, y: c.y), r * 0.45, eCG(kindRgb("drain")))
    pdFill(cg, CGPoint(x: c.x + r * 0.45, y: c.y - r * 0.35), r * 0.22, eCG(kindRgb("cold")))
    if hot { pdFill(cg, CGPoint(x: c.x + r * 0.45, y: c.y + r * 0.35), r * 0.22, eCG(kindRgb("hot"))) }
}

/// Where along wall w plan point q is, mm.
private func alongOf(_ w: TWall, _ q: V2) -> Double { (q - w.p0).dot(w.t) }

/// Where a kind's pipes go in the plan's drawing order: drains under the water, heating on top.
private func pdOrder(_ kind: String) -> Double {
    switch kind {
    case "drain": return 0
    case "cold": return 1
    case "hot": return 2
    default: return 3
    }
}

/// How far in from the wall a kind's pipes are drawn on the plan, in symbol sizes.
private func pdLane(_ kind: String) -> Double {
    switch kind {
    case "drain": return 0.55
    case "cold": return 0.6
    case "hot": return 0.95
    case "hs": return 1.3
    default: return 1.65
    }
}

/* ---------------- the room from above ---------------- */

/// The room from above: the floor, the walls, the doors with their swing, the windows, the underfloor loops, the pipes
/// in their colours, the fixtures, the outlets and the riser (sel ringed, bad in red). layers the kinds shown; sym the
/// symbols' size.
func drawPlumbPlan(_ cg: CGContext, _ c: PCtx, _ m: EPlanMap, _ fs: [PlFix], _ pts: [APt], _ rs: PlRiser?, _ runs: [PRun], _ loop: PLoop?, _ sym: CGFloat,
                   layers: Set<String> = Set(P_LAYERS), sel: String? = nil, bad: Set<String> = []) {
    let ink = eCG(P_INK_RGB)
    let outline = pdPoly(c.g.floor.map { m.at($0) })
    cg.addPath(outline); cg.setFillColor(eCG(PD_FLOOR)); cg.fillPath()
    if let loop, layers.contains("heat"), loop.n > 0 {
        for k in 0..<loop.n {
            let col = eCG(UFH_RGB, k % 2 == 0 ? 0.9 : 0.6)
            for ab in pSnake(c, loop.step, k, loop.n) { pdLine(cg, m.at(ab.0), m.at(ab.1), col, max(1, sym * 0.14)) }
        }
    }
    cg.saveGState()
    cg.addPath(outline); cg.setStrokeColor(ink); cg.setLineWidth(max(2, sym * 0.45)); cg.setLineJoin(.miter); cg.strokePath()
    cg.restoreGState()
    for o in c.room.openings {
        guard let w = c.wall(o.wall) else { continue }
        let a = m.at(w.at(Double(o.off))), b = m.at(w.at(Double(o.off + o.w)))
        if o.type == "door" {
            pdLine(cg, a, b, eCG(PD_FLOOR), max(3, sym * 0.6))
            let tip = m.at(w.at(Double(o.off), Double(o.w)))
            pdLine(cg, a, tip, eCG(PD_DOOR), max(1.2, sym * 0.2))
            let rad = pdDist(tip, a)
            let st = atan2(Double(b.y - a.y), Double(b.x - a.x)) * 180 / Double.pi
            let en = atan2(Double(tip.y - a.y), Double(tip.x - a.x)) * 180 / Double.pi
            var sweep = en - st
            while sweep > 180 { sweep -= 360 }
            while sweep < -180 { sweep += 360 }
            pdArc(cg, a, rad, st, sweep, eCG(PD_DOOR), max(1, sym * 0.12), dash: [4, 3])
        } else {
            pdLine(cg, a, b, eCG(PD_WIN), max(3, sym * 0.55))
        }
    }
    // the fixtures: wall-hung ones over floor ones
    for fx in eSortedBy(fs, { Double(fixZ0($0)) }) {
        guard let w = c.wall(fx.wall) else { continue }
        let x = Double(fx.off)
        let fi = bad.contains(fx.id) ? eCG(PD_WARN) : ink
        let fw = Double(fixW(fx)), fd = Double(fixD(fx))
        drawFixTop(cg, fx.t, fw, fd, { a, d in m.at(w.at(x + a, d)) }, fi, max(1, sym * 0.14), fx.opt == "cab")
        if fx.id == sel {
            let q = [m.at(w.at(x - fw / 2 - 40, -40)), m.at(w.at(x + fw / 2 + 40, -40)), m.at(w.at(x + fw / 2 + 40, fd + 40)), m.at(w.at(x - fw / 2 - 40, fd + 40))]
            cg.addPath(pdPoly(q)); cg.setStrokeColor(eCG(PD_DOOR)); cg.setLineWidth(2.5); cg.strokePath()
        }
    }
    // the pipes over the fixtures, each kind its own lane in from the wall so they read side by side: drains wide and
    // grey under the water, heating on top
    for r in eSortedBy(runs, { pdOrder($0.kind) }) {
        if !layers.contains(layerOf(r.kind)) { continue }
        let col = eCG(kindRgb(r.kind), 0.9)
        let wpx: CGFloat = r.kind == "drain" ? max(1.6, min(CGFloat(Double(r.dia) * m.k), sym * 0.6)) : max(1.2, sym * 0.2)
        let lane = Double(sym) * pdLane(r.kind) / m.k
        for g in r.segs {
            // pieces along a wall go in by their lane (minus how far the route already is off the wall); in the floor as
            // they are
            var ga = g.a, gb = g.b
            if let w = c.wall(g.wall) {
                let inA = (g.a - w.p0).dot(w.nIn)
                if inA < 200 {
                    let sh = w.nIn * max(0, lane - inA)
                    ga = g.a + sh; gb = g.b + sh
                }
            }
            let a = m.at(ga), b = m.at(gb)
            if pdDist(a, b) > 0.5 { pdLine(cg, a, b, col, wpx, round: true) }
        }
    }
    for q in pts where layers.contains(layerOf(q.t)) {
        guard let w = c.wall(q.wall) else { continue }
        let at = m.at(w.at(Double(q.off), 30))
        ptSymbol(cg, q.t, at, max(2.5, sym * 0.32))
        if q.fix == nil && q.id == sel { pdRing(cg, at, sym * 0.9, eCG(PD_DOOR), 2) }
    }
    if let rs, rs.roomId == c.id, let w = c.wall(rs.wall) {
        let at = m.at(w.at(Double(rs.off), Double(RISER_D) / 2))
        riserSymbol(cg, at, max(sym * 0.8, CGFloat(Double(RISER_W) / 2 * m.k)), rs.hot)
        if sel == "riser" { pdRing(cg, at, sym * 1.8, eCG(PD_DOOR), 2.5) }
    }
}

/* ---------------- a wall straight on ---------------- */

/// Wall w of room c straight on: its doors and windows, the fixtures against it, the pipes on it, the riser, and the
/// outlets each with its height when label is given (sel ringed, bad in red).
func drawPlumbWall(_ cg: CGContext, _ c: PCtx, _ w: TWall, _ m: EWallMap, _ fs: [PlFix], _ pts: [APt], _ rs: PlRiser?, _ runs: [PRun],
                   _ label: ((String) -> NSAttributedString)?, layers: Set<String> = Set(P_LAYERS), sel: String? = nil, bad: Set<String> = [], minR: CGFloat = 5) {
    let H = c.g.H
    let k = CGFloat(m.k)
    let ink = eCG(P_INK_RGB)
    let door = eCG(PD_DOOR)
    let wallRect = CGRect(x: m.x(0), y: m.y(H), width: CGFloat(w.len) * k, height: CGFloat(H) * k)
    pdRect(cg, wallRect, fill: eCG(0xF7F9FC), stroke: ink, 2)
    for o in c.room.openings where o.wall == w.id {
        let tl = m.at(Double(o.off), Double(o.sill + o.h))
        let rect = CGRect(x: tl.x, y: tl.y, width: CGFloat(o.w) * k, height: CGFloat(o.h) * k)
        if o.type == "door" {
            pdRect(cg, rect, fill: eCG(0xFFFFFF), stroke: door, 1.5)
            pdLine(cg, m.at(Double(o.off), 0), m.at(Double(o.off), Double(o.h)), door, 3)
        } else {
            pdRect(cg, rect, fill: eCG(0xE5EEFB), stroke: eCG(PD_WIN), 1.5)
        }
    }
    // the fixtures standing against the wall, seen from the front
    for fx in eSortedBy(fs.filter { $0.wall == w.id }, { Double(fixZ0($0)) }) {
        let half = Double(fixW(fx)) / 2
        let off = Double(fx.off)
        let a0 = off - half, a1 = off + half
        let z0 = Double(fixZ0(fx)), z1 = Double(fixTop(fx))
        let fi = bad.contains(fx.id) ? eCG(PD_WARN) : ink
        let tl = m.at(a0, z1)
        let rect = CGRect(x: tl.x, y: tl.y, width: CGFloat(a1 - a0) * k, height: CGFloat(z1 - z0) * k)
        pdRect(cg, rect, fill: fx.t == "cab" ? eCG(0xBFDBFE, 0x33 / 255.0) : eCG(0xFFFFFF), stroke: fi, 1.3)
        switch fx.t {
        case "wc":
            let p = m.at(off - 190, z1)
            pdRect(cg, CGRect(x: p.x, y: p.y, width: 380 * k, height: 380 * k), stroke: fi, 1)
        case "bs", "bsm":
            if fx.opt == "cab" {
                let p = m.at(a0 + 10, z1 - 160)
                pdRect(cg, CGRect(x: p.x, y: p.y, width: CGFloat(a1 - a0 - 20) * k, height: CGFloat(z1 - 160) * k), stroke: fi, 1)
            }
        case "wm":
            pdRing(cg, m.at(off, 430), 200 * k, fi, 1.2)
        case "rad":
            var a = a0 + 80
            while a < a1 - 1 { pdLine(cg, m.at(a, z0), m.at(a, z1), fi, 0.8); a += 80 }
        case "sink":
            pdLine(cg, m.at(a0, 820), m.at(a1, 820), fi, 1)
        default: break
        }
        if fx.id == sel { pdRect(cg, rect.insetBy(dx: -4, dy: -4), stroke: door, 2.5) }
    }
    if let rs, rs.roomId == c.id, rs.wall == w.id {
        let x = Double(rs.off)
        pdLine(cg, m.at(x - 55, 0), m.at(x - 55, H), eCG(kindRgb("drain")), max(2, 110 * k))
        pdLine(cg, m.at(x + 40, 0), m.at(x + 40, H), eCG(kindRgb("cold")), max(1.5, 32 * k))
        if rs.hot { pdLine(cg, m.at(x + 100, 0), m.at(x + 100, H), eCG(kindRgb("hot")), max(1.5, 32 * k)) }
        let mp = m.at(x + 10, 860)
        pdRect(cg, CGRect(x: mp.x, y: mp.y, width: 120 * k, height: 100 * k), fill: eCG(0xE5E7EB), stroke: ink, 1)
        if sel == "riser" {
            let p = m.at(x - Double(RISER_W) / 2, H)
            pdRect(cg, CGRect(x: p.x, y: p.y, width: CGFloat(RISER_W) * k, height: CGFloat(H) * k), stroke: door, 2.5)
        }
        if let label { eText(cg, label("riser"), CGPoint(x: m.x(x + Double(RISER_W) / 2) + 3, y: m.y(H * 0.5))) }
    }
    for r in runs where layers.contains(layerOf(r.kind)) {
        let col = eCG(kindRgb(r.kind))
        let wpx: CGFloat = r.kind == "drain" ? max(2, CGFloat(r.dia) * k) : max(1.5, 24 * k)
        for g in r.segs where g.wall == w.id {
            pdLine(cg, m.at(alongOf(w, g.a), g.za), m.at(alongOf(w, g.b), g.zb), col, wpx, round: true)
        }
    }
    let r0 = max(minR, 35 * k)
    // the heights: right of the outlet, else left of it, else left out when another label (an outlet beside it) is there
    var taken: [CGRect] = []
    let shown = eSortedBy(pts.filter { $0.wall == w.id && layers.contains(layerOf($0.t)) }, { Double($0.off) })
    for q in shown {
        let at = m.at(Double(q.off), Double(q.h))
        if let label {
            pdLine(cg, CGPoint(x: at.x, y: at.y + r0), CGPoint(x: at.x, y: m.y(0)), eCG(0x3E4A61, 0x55 / 255.0), 1, dash: [3, 3])
            let t = label("\(q.h)")
            let sz = t.size()
            let top = at.y - sz.height - r0 * 0.2
            let spots = [at.x + r0 * 0.9, at.x - r0 * 0.9 - sz.width].map { x in CGRect(x: x, y: top, width: sz.width, height: sz.height) }
            if let spot = spots.first(where: { r in !taken.contains { $0.intersects(r) } }) {
                taken.append(spot)
                eText(cg, t, spot.origin)
            }
        }
        let ringCol = bad.contains(q.fix ?? q.id) ? eCG(PD_WARN) : eCG(0xFFFFFF)
        ptSymbol(cg, q.t, at, r0, ringCol)
        if q.fix == nil && q.id == sel { pdRing(cg, at, r0 * 1.8, door, 2) }
    }
    pdLine(cg, CGPoint(x: m.x(0) - 6, y: m.y(0)), CGPoint(x: m.x(w.len) + 6, y: m.y(0)), ink, 3)
}

/// The fixture types shown, in the legend's order.
func legendFix(_ fs: [PlFix]) -> [String] { FIX_TYPES.map(\.id).filter { t in fs.contains { $0.t == t } } }

/* ---------------- small views ---------------- */

/// A fixture type's symbol as a small view (the lists, sheets and legend).
struct FixSymbolView: View {
    let t: String
    var ink: Int = P_INK_RGB
    var k: CGFloat = 2.4
    var body: some View {
        Canvas { ctx, size in
            let t = self.t, ink = self.ink, k = self.k
            ctx.withCGContext { cg in
                fixSymbol(cg, t, CGPoint(x: size.width / 2, y: size.height / 2), min(size.width, size.height) / k, eCG(ink))
            }
        }
        .allowsHitTesting(false)
    }
}

/// An outlet kind's dot as a small view.
struct PtSymbolView: View {
    let t: String
    var k: CGFloat = 3
    var body: some View {
        Canvas { ctx, size in
            let t = self.t, k = self.k
            ctx.withCGContext { cg in
                ptSymbol(cg, t, CGPoint(x: size.width / 2, y: size.height / 2), min(size.width, size.height) / k, eCG(0xFFFFFF))
            }
        }
        .allowsHitTesting(false)
    }
}

/// The riser's symbol as a small view.
struct RiserSymbolView: View {
    var hot = true
    var k: CGFloat = 2.6
    var body: some View {
        Canvas { ctx, size in
            let hot = self.hot, k = self.k
            ctx.withCGContext { cg in
                riserSymbol(cg, CGPoint(x: size.width / 2, y: size.height / 2), min(size.width, size.height) / k, hot)
            }
        }
        .allowsHitTesting(false)
    }
}
