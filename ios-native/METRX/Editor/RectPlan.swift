import SwiftUI

/* The plan of a rectangular room, as the prototype's planSVG restyled by glass.css (.gs-room); Android RectPlan. */

/// One wall as drawn: its inner face from a to b, outward normal n, screen side 0 top, 1 right, 2 bottom, 3 left.
struct SideWall { let id: String; let key: String; let corner: Int; let side: Int; let a: CGPoint; let b: CGPoint; let n: CGPoint; let realLen: Int }

/// Where everything sits, in the prototype's 360-wide viewBox.
struct RectLayout {
    let VW: CGFloat = 360
    let MY: CGFloat = 68
    let T: Int, L: Int, W: Int, rot: Int
    let s: CGFloat, tw: CGFloat, ox: CGFloat, oy: CGFloat, VH: CGFloat
    let inner: CGRect
    let walls: [SideWall]

    init(_ r: Room) {
        T = r.dim("T").v ?? 200
        let a = r.dim("A"), b = r.dim("B")
        let la = a.v ?? a.pending?.mm, lb = b.v ?? b.pending?.mm
        L = la ?? lb.map { kround(Double($0) * 1.25) } ?? 5000
        W = lb ?? la.map { kround(Double($0) * 0.8) } ?? 4000
        rot = r.rot % 4
        let SW = CGFloat(rot % 2 == 0 ? L : W), SH = CGFloat(rot % 2 == 0 ? W : L)
        s = min((VW - 176) / (SW + 2 * CGFloat(T)), 210 / (SH + 2 * CGFloat(T)))
        tw = max(3, CGFloat(T) * s)
        let iw = SW * s, ih = SH * s
        ox = (VW - iw) / 2; oy = MY + tw
        VH = ih + 2 * tw + 2 * MY
        inner = CGRect(x: ox, y: oy, width: iw, height: ih)
        let corners = [CGPoint(x: ox, y: oy), CGPoint(x: ox + iw, y: oy), CGPoint(x: ox + iw, y: oy + ih), CGPoint(x: ox, y: oy + ih)]
        let normals = [CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)]
        let rot = rot, L = L, W = W
        // walls A–D in order; wall i sits on side (i + rot) % 4
        walls = ["A", "B", "C", "D"].enumerated().map { i, id in
            let side = (i + rot) % 4
            return SideWall(id: id, key: i % 2 == 0 ? "A" : "B", corner: i + 1, side: side, a: corners[side], b: corners[(side + 1) % 4], n: normals[side], realLen: i % 2 == 0 ? L : W)
        }
    }
    func wall(_ id: String) -> SideWall { walls.first { $0.id == id } ?? walls[0] }
    func onSide(_ side: Int) -> SideWall { walls.first { $0.side == side }! }
    func pillCenter(_ w: SideWall) -> CGPoint { mid(w.a, w.b) + w.n * (tw + 42) }
}

/// The plan canvas: draws the room fitted into the box, handles taps (walls, dimension pills, doors and windows) and
/// drags of doors and windows along their wall (prototype openings.js drag, plan part).
struct RectPlan: View {
    let r: Room
    let sel: String?
    let selOp: String?
    let label: String
    let issueOf: (Opening) -> Bool
    let onWall: (String) -> Void
    let onOpening: (String) -> Void
    let onDragEnd: (Opening, Int) -> Void
    let tipText: (Opening, Int) -> String

    @State private var live: (id: String, off: Int)? = nil
    @State private var finger = CGPoint.zero
    @State private var g: Gest? = nil

    private struct Gest { let hit: PlanHit?; let op: Opening?; var dragging = false; var lastOff = 0 }

    var body: some View {
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en
        let lay = RectLayout(r)
        GeometryReader { geo in
            Canvas { ctx, size in
                let fit = Fit(size, lay.VW, lay.VH)
                var room = r
                if let live, let i = room.openings.firstIndex(where: { $0.id == live.id }) { room.openings[i].off = live.off }
                var c = ctx; fit.apply(&c)
                drawRectPlan(c, lay, room, sel, selOp ?? live?.id, unit, en, label, issueOf)
                if let live, let o = room.openings.first(where: { $0.id == live.id }) { dragTip(ctx, size, tipText(o, live.off), finger, issueOf(o)) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let fit = Fit(geo.size, lay.VW, lay.VH)
                if g == nil {
                    let hit = rectHit(lay, r, fit.vb(v.startLocation))
                    var op: Opening? = nil
                    if case .op(let id)? = hit { op = r.openings.first { $0.id == id } }
                    g = Gest(hit: hit, op: op, lastOff: op?.off ?? 0)
                }
                guard var st = g, let op = st.op else { return }
                let d = v.location - v.startLocation
                if !st.dragging && d.len > 7 { st.dragging = true }
                if st.dragging {
                    let w = lay.wall(op.wall), u = unitV(w.a, w.b)
                    let along = d.dot(u) / fit.k / lay.s
                    st.lastOff = snapOff(op.off + kround(Double(along)), op.w, r.dim(w.key).v != nil ? w.realLen : nil)
                    live = (op.id, st.lastOff); finger = v.location
                }
                g = st
            }.onEnded { _ in
                defer { g = nil; live = nil }
                guard let st = g else { return }
                if st.dragging, let op = st.op { onDragEnd(op, st.lastOff); return }
                switch st.hit {
                case .dim(let w)?: onWall(w)
                case .op(let id)?: onOpening(id)
                case nil: break
                }
            })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier("plan")
    }
}

private func rectHit(_ lay: RectLayout, _ r: Room, _ p: CGPoint) -> PlanHit? {
    // doors and windows first: their band reaches 150 mm past each side and 30 into the room
    for o in r.openings {
        let w = lay.wall(o.wall), u = unitV(w.a, w.b)
        let a0 = CGFloat(o.off - 150) * lay.s, a1 = CGFloat(o.off + o.w + 150) * lay.s
        let rel = p - w.a
        let along = rel.dot(u), out = rel.dot(w.n)
        if along >= a0 && along <= a1 && out >= -30 && out <= lay.tw + 6 { return .op(o.id) }
    }
    // dimension pills (top and right)
    for side in [0, 1] {
        let w = lay.onSide(side), c = lay.pillCenter(w)
        if abs(p.x - c.x) < 46 && abs(p.y - c.y) < 20 { return .dim(w.id) }
    }
    // wall bands, 12 around the wall
    for w in lay.walls {
        let u = unitV(w.a, w.b), rel = p - w.a
        let along = rel.dot(u), out = rel.dot(w.n), len = (w.b - w.a).len
        if along >= -12 && along <= len + 12 && out >= -12 && out <= lay.tw + 12 { return .dim(w.id) }
    }
    return nil
}

private func bandPath(_ w: SideWall, _ tw: CGFloat, _ pad: CGFloat) -> Path {
    let u = unitV(w.a, w.b)
    return polyPath([w.a - u * pad - w.n * pad, w.b + u * pad - w.n * pad, w.b + u * pad + w.n * (tw + pad), w.a - u * pad + w.n * (tw + pad)])
}

/// The plan drawn in viewBox units into ctx (already scaled). report: the report's plain white value boxes.
func drawRectPlan(_ ctx: GraphicsContext, _ lay: RectLayout, _ r: Room, _ sel: String?, _ selOp: String?, _ unit: LenUnit, _ en: Bool,
                  _ label: String, _ issueOf: (Opening) -> Bool, report: Bool = false) {
    let tw = lay.tw, inn = lay.inner
    let outer = inn.insetBy(dx: -tw, dy: -tw)
    // selected wall: a pale band with a blue edge, padded 5
    if let w = lay.walls.first(where: { $0.id == sel }) {
        let b = bandPath(w, tw, 5); ctx.fill(b, with: .color(PC.selBand)); ctx.stroke(b, with: .color(PC.cob), lineWidth: 1.5)
    }
    // walls: a hatched ring outside the room
    var ring = Path(); ring.addRect(outer); ring.addRect(inn)
    ctx.fill(ring, with: .color(PC.white), style: FillStyle(eoFill: true))
    var hc = ctx; hc.clip(to: ring, style: FillStyle(eoFill: true))
    var x = outer.minX - outer.height
    while x < outer.maxX + outer.height { hc.line(PC.ink, CGPoint(x: x, y: outer.maxY), CGPoint(x: x + outer.height, y: outer.minY), 1.1); x += 4 * 1.4142 }
    ctx.stroke(Path(outer), with: .color(PC.ink), lineWidth: 1.2); ctx.stroke(Path(inn), with: .color(PC.ink), lineWidth: 1.2)
    if let w = lay.walls.first(where: { $0.id == sel }) { ctx.fill(bandPath(w, tw, 0), with: .color(PC.cob)) }

    // doors and windows across the wall
    for o in r.openings { let bad = issueOf(o); drawOpening(ctx, lay, o, bad ? PC.red : o.id == selOp ? PC.cob : PC.ink, bad) }
    // columns stand inside against the wall, hatched like walls; niches are cut into the wall (dashed when above the floor)
    for f in r.features { drawFeature(ctx, lay, f) }
    // furniture orders: sockets, switches and pipes, just inside their wall (furniture plan section 5)
    for x in r.points {
        let w = lay.wall(x.wall), u = unitV(w.a, w.b)
        drawSitePoint(ctx, x, w.a + u * (CGFloat(x.off) * lay.s) - w.n * 7, 0, 6.5, 1)
    }

    // centre label: NAME and the floor area
    let a = Geo.areas(r)
    centreLabel(ctx, label, (a.map { Geo.fmtArea($0.floor, en) } ?? "?") + " m²", CGPoint(x: inn.midX, y: inn.midY))

    // wall letters (17 inside) and corner numbers
    for w in lay.walls {
        let m = mid(w.a, w.b) - w.n * 17
        let on = w.id == sel
        ctx.disc(on ? PC.cob : PC.white, 9, m); ctx.ring(on ? PC.cob : PC.ink3, 9, m, 1)
        ctx.text(w.id, m, .ui, 11, 600, on ? PC.onFill : PC.ink)
        let u = unitV(w.a, w.b)
        ctx.text("\(w.corner)", w.a - w.n * 10 + u * 10, .ui, 9.5, 400, PC.ink3)
    }

    // chain dimensions on walls with doors or windows
    for w in lay.walls {
        let ops = r.openings.filter { $0.wall == w.id }.sorted { $0.off < $1.off }
        if !ops.isEmpty { chain(ctx, lay, w, ops, unit, en) }
    }
    // overall dimensions: the walls on top and on the right
    for side in [0, 1] { overall(ctx, lay, lay.onSide(side), r, unit, en, report) }
}

private func drawOpening(_ ctx: GraphicsContext, _ lay: RectLayout, _ o: Opening, _ c: Color, _ bad: Bool) {
    let w = lay.wall(o.wall), u = unitV(w.a, w.b), s = lay.s, tw = lay.tw
    let a = w.a + u * (CGFloat(o.off) * s), b = w.a + u * (CGFloat(o.off + o.w) * s)
    let quad = polyPath([a, b, b + w.n * tw, a + w.n * tw])
    if o.type == "door" {
        ctx.fill(quad, with: .color(PC.paper))
        ctx.line(c, a, a + w.n * tw, 1.2); ctx.line(c, b, b + w.n * tw, 1.2)
        let tip = a - w.n * (CGFloat(o.w) * s)
        ctx.line(c, a, tip, 2.2, round: true)
        // the swing: an arc round the hinge from the far edge to the leaf tip
        let start = atan2((b - a).y, (b - a).x), end = atan2((tip - a).y, (tip - a).x)
        var sweep = end - start
        while sweep > .pi { sweep -= 2 * .pi }
        while sweep < -.pi { sweep += 2 * .pi }
        var arc = Path()
        arc.addArc(center: a, radius: CGFloat(o.w) * s, startAngle: .radians(start), endAngle: .radians(start + sweep), clockwise: sweep < 0)
        ctx.stroke(arc, with: .color(c), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    } else {
        ctx.fill(quad, with: .color(PC.white)); ctx.stroke(quad, with: .color(c), lineWidth: 1.2)
        ctx.line(c, a + w.n * (tw / 3), b + w.n * (tw / 3), 1); ctx.line(c, a + w.n * (2 * tw / 3), b + w.n * (2 * tw / 3), 1)
    }
    func box(_ pad: CGFloat) -> Path { polyPath([a - u * pad - w.n * pad, b + u * pad - w.n * pad, b + u * pad + w.n * (tw + pad), a - u * pad + w.n * (tw + pad)]) }
    if o.approx && !bad { ctx.stroke(box(3), with: .color(PC.amber), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])) }
    if bad { ctx.stroke(box(4), with: .color(PC.red), style: StrokeStyle(lineWidth: 2.5, dash: [4, 3])) }
}

private func drawFeature(_ ctx: GraphicsContext, _ lay: RectLayout, _ f: Feature) {
    let w = lay.wall(f.wall), u = unitV(w.a, w.b), s = lay.s
    let a = w.a + u * (CGFloat(f.off) * s), b = w.a + u * (CGFloat(f.off + f.w) * s)
    let depth = CGFloat(f.d) * s * (f.type == "column" ? -1 : 1)
    let quad = polyPath([a, b, b + w.n * depth, a + w.n * depth])
    if f.type == "column" {
        ctx.fill(quad, with: .color(PC.white))
        var hc = ctx; hc.clip(to: quad)
        let bx = quad.boundingRect
        var x = bx.minX - bx.height
        while x < bx.maxX + bx.height { hc.line(PC.ink, CGPoint(x: x, y: bx.maxY), CGPoint(x: x + bx.height, y: bx.minY), 1.1); x += 4 * 1.4142 }
        ctx.stroke(quad, with: .color(PC.ink), lineWidth: 1.2)
    } else {
        ctx.fill(quad, with: .color(PC.paper))
        ctx.stroke(quad, with: .color(PC.ink), style: StrokeStyle(lineWidth: 1.1, dash: f.sill > 0 ? [3, 3] : []))
    }
}

private func chain(_ ctx: GraphicsContext, _ lay: RectLayout, _ w: SideWall, _ ops: [Opening], _ unit: LenUnit, _ en: Bool) {
    let u = unitV(w.a, w.b), s = lay.s
    let off = lay.tw + 18
    let cuts = Array(Set(([0] + ops.flatMap { [$0.off, $0.off + $0.w] } + [w.realLen]).map { min(max($0, 0), max(w.realLen, $0)) })).sorted()
    ctx.line(PC.ink3, w.a + w.n * off, w.a + u * (CGFloat(cuts.last!) * s) + w.n * off, 0.9)
    for c in cuts { let p = w.a + u * (CGFloat(c) * s) + w.n * off; ctx.line(PC.ink3, p - (u + w.n) * 3, p + (u + w.n) * 3, 1.2) }
    for i in 0..<(cuts.count - 1) {
        let m = CGFloat(cuts[i] + cuts[i + 1]) / 2
        let p = w.a + u * (m * s) + w.n * (lay.tw + 9)
        let t = Geo.fmtLen(cuts[i + 1] - cuts[i], unit, en)
        if w.side % 2 == 1 {
            var rc = ctx; rc.translateBy(x: p.x, y: p.y); rc.rotate(by: .degrees(-90)); rc.text(t, .zero, .num, 11.5, 400, PC.ink3)
        } else { ctx.text(t, p, .num, 11.5, 400, PC.ink3) }
    }
}

private func overall(_ ctx: GraphicsContext, _ lay: RectLayout, _ w: SideWall, _ r: Room, _ unit: LenUnit, _ en: Bool, _ report: Bool) {
    let d = r.dim(w.key), st = d.status
    let lc = st == "conf" ? PC.ink : st == "recv" ? PC.amber : PC.greyLine
    let dash: [CGFloat]? = st == "conf" ? nil : [5, 4]
    let off = lay.tw + 42
    let a = w.a + w.n * off, b = w.b + w.n * off
    // extension lines from the wall to past the dimension line
    ctx.line(lc, w.a + w.n * (lay.tw + 3), w.a + w.n * (off + 5), 0.9)
    ctx.line(lc, w.b + w.n * (lay.tw + 3), w.b + w.n * (off + 5), 0.9)
    ctx.line(lc, a, b, 1.1, dash: dash)
    let u = unitV(w.a, w.b), diag = (u + w.n) * 4
    for p in [a, b] { ctx.line(lc, p - diag, p + diag, 1.6) }
    // the pill: white glass, the value, a check when confirmed or a clock while a reading waits
    let txt = st == "recv" ? Geo.fmtLen(d.pending!.mm, unit, en, full: true) : st == "conf" ? Geo.fmtLen(d.v, unit, en) : "?"
    let pw = pillW(txt, st != "unset")
    let c = lay.pillCenter(w)
    let rect = CGRect(x: c.x - pw / 2, y: c.y - 13, width: pw, height: 26)
    if report {
        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white))
        ctx.text(txt, CGPoint(x: st == "conf" ? c.x - 7 : c.x, y: c.y), .num, 15, 600, PC.ink)
        if st == "conf" { ctx.tick(rect.maxX - 14, c.y, PC.ink, 1.8) }
        return
    }
    var sh = ctx
    sh.addFilter(.blur(radius: 3))
    sh.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 4), cornerRadius: 13), with: .color(planDark ? Color.black.opacity(0.35) : Color(argb: 0x241E286E)))
    let pill = Path(roundedRect: rect, cornerRadius: 13)
    ctx.fill(pill, with: .color(PC.pillFill(0.78)))
    ctx.stroke(pill, with: .color(PC.pillEdge(0.95)), lineWidth: 1.2)
    let tx = st == "conf" ? c.x - 7 : st == "recv" ? c.x + 7 : c.x
    ctx.text(txt, CGPoint(x: tx, y: c.y), .ui, 15, 800, PC.pillInk)
    if st == "conf" { ctx.tick(rect.maxX - 14, c.y, PC.okGreen, 2.4) }
    else if st == "recv" { ctx.clock(CGPoint(x: rect.minX + 12, y: c.y), PC.amber) }
}

/// A room's plan for the report (prototype planSVG with report:true), in the prototype's 360-wide units, on paper:
/// rectangle and drawn rooms alike, the values in plain white boxes.
func drawReportPlan(_ ctx: GraphicsContext, _ r: Room, _ unit: LenUnit, _ en: Bool, _ label: String) {
    Theme.shared.onPaper {
        if r.isPoly { _ = drawReportPoly(ctx, r, unit, en, label, snap: true) }
        else { drawRectPlan(ctx, RectLayout(r), r, nil, nil, unit, en, label, { _ in false }, report: true) }
    }
}

/// The height of a room's plan drawing in the 360-wide units.
func reportPlanHeight(_ r: Room, snap: Bool) -> CGFloat { r.isPoly ? reportPolyHeight(r, snap: snap) : RectLayout(r).VH }
