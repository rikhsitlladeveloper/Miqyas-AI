import SwiftUI

/*
 * The room from above for placing a piece (Android ui/furniture/RoomPlace.kt): the piece where it stands, the room's
 * other furniture, its doors and windows; one finger drags the piece.
 */

/// What a drag moves: a piece along the walls, a corner kitchen into another corner, or a piece that may stand anywhere.
private enum PDrag { case slide, corner, free }

/// Where the finger took hold: the island or the main part, ga along it and gn out from its back.
private struct Grab { let island: Bool; let ga: Double; let gn: Double }

/// g where it stands, the others grey. A drag moves g along the walls (onSlide: the wall and the distance from its
/// start), a corner kitchen into another corner (onCorner: its first wall), a desk anywhere (onPose; near a wall it snaps
/// back on it), the island anywhere (onIsland). red: it gets in the way of something.
struct PlacePlan: View {
    let room: Room
    let walls: [PlanWall]
    let g: Furniture
    let others: [Furniture]
    let ws: Workshop
    let red: Bool
    let label: String
    let onSlide: (String, Int) -> Void
    let onCorner: (String) -> Void
    let onPose: (Pose) -> Void
    let onIsland: (Pose) -> Void
    @State private var grab: Grab? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        GeometryReader { geo in
            let size = geo.size
            let x0 = walls.map(\.p0.x).min() ?? 0, y0 = walls.map(\.p0.y).min() ?? 0
            let spanX = max((walls.map(\.p0.x).max() ?? 1) - x0, 1), spanY = max((walls.map(\.p0.y).max() ?? 1) - y0, 1)
            // the plan fitted into the box with room for the wall letters
            let k = max(min((size.width - 56) / spanX, (size.height - 56) / spanY), 1e-6)
            let ox = (size.width - spanX * k) / 2, oy = (size.height - spanY * k) / 2
            let scr = { (q: PlanPt) in CGPoint(x: ox + (q.x - x0) * k, y: oy + (q.y - y0) * k) }
            let plan = { (p: CGPoint) in PlanPt(x0 + (p.x - ox) / k, y0 + (p.y - oy) / k) }
            Canvas { ctx, _ in
                guard !walls.isEmpty else { return }
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(argb: 0xFFEFF3FA)))
                var outline = Path()
                for (i, w) in walls.enumerated() { let a = scr(w.p0); if i == 0 { outline.move(to: a) } else { outline.addLine(to: a) } }
                outline.closeSubpath()
                ctx.fill(outline, with: .color(.white))
                // a piece's box: filled when it stands on the floor, outlined when it hangs; the one being placed with a heavier front
                func foot(_ ft: Foot, _ c: Color, _ me: Bool) {
                    let pts = ft.pts.map(scr)
                    var pp = Path(); pp.move(to: pts[0]); pts.dropFirst().forEach { pp.addLine(to: $0) }; pp.closeSubpath()
                    if ft.floor { ctx.fill(pp, with: .color(c.opacity(me ? 0.28 : 0.22))) }
                    ctx.stroke(pp, with: .color(c), style: StrokeStyle(lineWidth: me ? 2.5 : 1.5, dash: ft.floor ? [] : [7, 5]))
                    if me && ft.floor { var fr = Path(); fr.move(to: pts[2]); fr.addLine(to: pts[3]); ctx.stroke(fr, with: .color(c), lineWidth: 5) }
                }
                for o in others { for ft in footsOf(o, walls, ws) { foot(ft, Color(argb: 0xFF94A3B8), false) } }
                // doors with their swing, windows in light blue
                for op in room.openings {
                    guard let w = walls.first(where: { $0.id == op.wall }) else { continue }
                    let a = scr(w.at(Double(op.off), 0)), b = scr(w.at(Double(op.off + op.w), 0))
                    var seg = Path(); seg.move(to: a); seg.addLine(to: b)
                    if op.type == "door" {
                        ctx.stroke(seg, with: .color(.white), lineWidth: 7)
                        let r = Double(op.w) * k
                        let start = atan2(w.u.y, w.u.x), sweep = (w.u.x * w.n.y - w.u.y * w.n.x > 0 ? 1.0 : -1.0) * .pi / 2
                        var arc = Path(); arc.move(to: a)
                        arc.addArc(center: a, radius: r, startAngle: .radians(start), endAngle: .radians(start + sweep), clockwise: sweep < 0)
                        arc.closeSubpath()
                        ctx.fill(arc, with: .color(Color(argb: 0xFF94A3B8).opacity(0.12)))
                        ctx.stroke(arc, with: .color(Color(argb: 0xFF94A3B8)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    } else { ctx.stroke(seg, with: .color(Color(argb: 0xFF7DD3FC)), lineWidth: 7) }
                }
                ctx.stroke(outline, with: .color(Color(argb: 0xFF0F172A)), lineWidth: 5)
                for w in walls {
                    let c = scr(w.at(w.len / 2, 0))
                    ctx.draw(Text(w.id).font(.system(size: 12)).foregroundColor(Color(argb: 0xFF475569)), at: CGPoint(x: c.x - w.n.x * 13, y: c.y - w.n.y * 13))
                }
                for ft in footsOf(g, walls, ws) { foot(ft, red ? Color(argb: 0xFFDC2626) : Color(argb: 0xFF3550E0), true) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4).onChanged { v in
                if grab == nil {
                    let q = plan(v.startLocation)
                    let isl = footsOf(g, walls, ws).first { $0.island }
                    let onIsl = isl.map { near($0, q) } ?? false
                    if let fr = onIsl ? islandPoseIn(g, walls).flatMap({ frameOf(walls, $0) }) : mainFrame(g, walls) {
                        grab = Grab(island: onIsl, ga: (q - fr.o).dot(fr.u), gn: (q - fr.o).dot(fr.n))
                    }
                }
                guard let gr = grab else { return }
                move(gr, plan(v.location))
            }.onEnded { _ in grab = nil })
        }
        .aspectRatio(1.2, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityIdentifier("fz.plan")
    }

    private func move(_ gr: Grab, _ q: PlanPt) {
        let f = g
        if gr.island {
            guard let p = islandPoseIn(f, walls), let fr = frameOf(walls, p) else { return }
            onIsland(poseOf(walls, p.ref, Frame(o: q - fr.u * gr.ga - fr.n * gr.gn, u: fr.u, n: fr.n)))
            return
        }
        let sides = f.walls.filter { $0 != ISLAND }.count
        let mode: PDrag = f.kind == "kitchen" && sides > 1 ? .corner : canStandFree(f) ? .free : .slide
        switch mode {
        case .corner:
            // an L goes into the corner nearest the finger; a U takes the wall nearest it as its back wall
            if sides == 2 { if let w = walls.min(by: { d2($0.p1, q) < d2($1.p1, q) }) { onCorner(w.id) } }
            else if let i = walls.indices.min(by: { walls[$0].dist(q) < walls[$1].dist(q) }) { onCorner(walls[(i - 1 + walls.count) % walls.count].id) }
        case .slide:
            guard let w = walls.min(by: { $0.dist(q) < $1.dist(q) }) else { return }
            onSlide(w.id, slideX(f, w, w.along(q) - gr.ga))
        case .free:
            guard let fr = mainFrame(f, walls), let m = wardOfF(f) else { return }
            let o = q - fr.u * gr.ga - fr.n * gr.gn
            // its back near a wall: back on that wall; else where the finger is, turned as it was
            let mid = o + fr.u * (Double(m.w) / 2)
            if let w = walls.min(by: { $0.dist(mid) < $1.dist(mid) }), w.dist(mid) < 250 { onSlide(w.id, slideX(f, w, w.along(mid) - Double(m.w) / 2)) }
            else { onPose(poseOf(walls, f.pose?.ref ?? walls[0].id, Frame(o: o, u: fr.u, n: fr.n))) }
        }
    }

    /// The distance from w's start for a piece dragged to a: kept on the wall, snapped into a corner near one, to 10 mm.
    private func slideX(_ f: Furniture, _ w: PlanWall, _ a: Double) -> Int {
        let first = f.kind == "kitchen" ? f.walls.first { $0 != ISLAND } : wardOfF(f)?.wall
        let feet = footsOf(f, walls, ws).filter { $0.wall != nil && $0.wall == first }
        let len = f.kind == "wardrobe" ? Double(wardOfF(f)?.w ?? 0) : (feet.isEmpty ? 0 : feet.map(\.a1).max()! - feet.map(\.a0).min()!)
        let gap = f.kind == "wardrobe" ? Double(W_GAP_SIDE) : 0
        let hi = max(gap, w.len - len - gap)
        var x = min(max(a, gap), hi)
        if abs(x - gap) < 150 { x = gap }
        if abs(x - hi) < 150 { x = hi }
        let r = Int((x / 10).rounded()) * 10
        return abs(Double(r) - gap) < 10 ? Int(gap) : r
    }
}

private func d2(_ a: PlanPt, _ b: PlanPt) -> Double { (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) }

/// Whether q is on (or within 150 mm of) box ft.
private func near(_ ft: Foot, _ q: PlanPt) -> Bool {
    if inside(ft.pts, q) { return true }
    return ft.pts.indices.contains { i in
        let a = ft.pts[i], b = ft.pts[(i + 1) % ft.pts.count], e = b - a
        let t = min(max((q - a).dot(e) / max(e.dot(e), 1e-9), 0), 1)
        return d2(a + e * t, q) < 150 * 150
    }
}
