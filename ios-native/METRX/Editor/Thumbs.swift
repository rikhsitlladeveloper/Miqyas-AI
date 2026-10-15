import SwiftUI

/// A room's small plan (prototype miniPlan / thumbSVG): the walls as a solid ring once measured (dashed while not), doors
/// and windows as gaps, and on bigger thumbnails the name, the floor area and the two side lengths. Drawn on paper: the
/// light colours stay in the dark theme.
struct RoomThumb: View {
    let r: Room
    var label: String? = nil
    var detailed = false

    var body: some View {
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap
        let label = label ?? dn(r.name)
        Canvas { ctx, size in
            let pad: CGFloat = detailed ? 22 : 6
            let outline: [CGPoint], solid: Bool
            if r.isPoly {
                let g = Geo.polyGeo(r, snap)
                outline = g.verts.map { CGPoint($0) }; solid = g.solved
            } else {
                let a = r.dim("A"), b = r.dim("B")
                let L = CGFloat(a.v ?? a.pending?.mm ?? 5000), W = CGFloat(b.v ?? b.pending?.mm ?? 4000)
                outline = [.zero, CGPoint(x: L, y: 0), CGPoint(x: L, y: W), CGPoint(x: 0, y: W)]
                solid = a.v != nil && b.v != nil
            }
            guard outline.count >= 3 else { return }
            let minX = outline.map(\.x).min()!, maxX = outline.map(\.x).max()!, minY = outline.map(\.y).min()!, maxY = outline.map(\.y).max()!
            let bw = max(1, maxX - minX), bh = max(1, maxY - minY)
            let s = min((size.width - 2 * pad) / bw, (size.height - 2 * pad) / bh)
            let ox = (size.width - bw * s) / 2 - minX * s, oy = (size.height - bh * s) / 2 - minY * s
            let pts = outline.map { CGPoint(x: ox + $0.x * s, y: oy + $0.y * s) }
            let path = polyPath(pts)
            let ink = Color(argb: 0xFF0E1C36)
            ctx.fill(path, with: .color(.white))
            if solid { ctx.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: max(2, detailed ? 2.6 : 1.6), lineJoin: .miter)) }
            else { ctx.stroke(path, with: .color(Color(argb: 0xFF5F6B82)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
            // doors and windows as gaps in the wall (rectangle rooms)
            if !r.isPoly && solid {
                for o in r.openings {
                    guard let i = ["A", "B", "C", "D"].firstIndex(of: o.wall) else { continue }
                    let a = pts[i], b = pts[(i + 1) % 4], d = b - a
                    if d.len == 0 { continue }
                    let u = d / d.len
                    let p0 = a + u * (CGFloat(o.off) * s), p1 = a + u * (CGFloat(o.off + o.w) * s)
                    ctx.line(.white, p0, p1, 3.4)
                    if o.type == "window" { ctx.line(ink, p0, p1, 0.8) }
                }
            }
            guard detailed else { return }
            let ar = Geo.areas(r, snap)
            let cx = (pts.map(\.x).min()! + pts.map(\.x).max()!) / 2, cy = (pts.map(\.y).min()! + pts.map(\.y).max()!) / 2
            ctx.draw(Text(label.uppercased()).font(.custom(fontName(.ui, 700), fixedSize: 8.5)).tracking(0.5).foregroundColor(ink), at: CGPoint(x: cx, y: cy), anchor: .bottom)
            ctx.draw(Text((ar.map { Geo.fmtArea($0.floor, en) } ?? "?") + " m²").font(.custom(fontName(.num, 400), fixedSize: 9)).foregroundColor(Color(argb: 0xFF3E4A61)),
                     at: CGPoint(x: cx, y: cy), anchor: .top)
            if !r.isPoly {
                let st = { (s: String) in Text(s).font(.custom(fontName(.num, 400), fixedSize: 8.5)).foregroundColor(Color(argb: 0xFF3E4A61)) }
                ctx.draw(st(Geo.fmtLen(r.dim("A").v, unit, en)), at: CGPoint(x: cx, y: pts[0].y - 3), anchor: .bottom)
                var rc = ctx; rc.translateBy(x: pts[0].x - 10, y: cy); rc.rotate(by: .degrees(-90))
                rc.draw(st(Geo.fmtLen(r.dim("B").v, unit, en)), at: .zero, anchor: .center)
            }
        }
        .accessibilityHidden(true)
    }
}
