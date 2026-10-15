import SwiftUI

/*
 * The Workspaces tab seen as plans side by side (prototype roomsTab view '2d') or in 3D (view '3d', one workspace at a
 * time, the ux module's rows of rooms and zoom-to-room names); Android ProjectViews.kt.
 */

/// List | 2D | 3D (prototype .seg.wide).
struct ViewSeg: View {
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        HStack(spacing: 2) {
            ForEach([("list", tr("view.list")), ("2d", "2D"), ("3d", "3D")], id: \.0) { k, l in
                let on = k == cur
                T(l, ui(14, on ? 600 : 500, on ? G.ink : G.ink2), lines: 1)
                    .padding(.horizontal, 6).frame(maxWidth: .infinity).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? G.glass(0.55) : .clear))
                    .boxShadow(on ? Color(argb: 0x24101828) : .clear, blur: 3, y: 1)
                    .pressable(0.97) { onPick(k) }
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("view." + k)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
        .padding(.bottom, 10)
    }
}

/// A small info line (prototype .note).
struct NoteLine: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            MIcon("info", G.ink2, 18, 2)
            T(text, ui(13, 400, G.ink2, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 10)
    }
}

/// Every workspace with its rooms' plans at one scale (prototype view2d).
struct Plans2D: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap
        let maxDim = p.rooms.map { max($0.dim("A").v ?? 4000, $0.dim("B").v ?? 3000) }.max() ?? 4000
        let sc = 120 / CGFloat(maxDim)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(p.floors) { f in
                let rs = p.rooms.filter { $0.floorId == f.id }
                let sum = rs.reduce(Int64(0)) { $0 + (Geo.areas($1, snap)?.floor ?? 0) }
                HStack(alignment: .lastTextBaseline) {
                    T(floorName(f), ui(15, 700)).frame(maxWidth: .infinity, alignment: .leading)
                    T(tr("pr.floorSum", ["n": rs.count, "a": Geo.fmtArea(sum, en)]), ui(13, 400, G.ink2))
                }
                .padding(.top, 14).padding(.bottom, 6)
                if rs.isEmpty { T(tr("pr.emptyFloor"), ui(13.5, 400, G.ink2)).padding(.vertical, 4) }
                else {
                    GeometryReader { g in
                        let cols = max(1, Int((g.size.width + 10) / 150)), cw = (g.size.width - 10 * CGFloat(cols - 1)) / CGFloat(cols)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(0..<((rs.count + cols - 1) / cols), id: \.self) { row in
                                HStack(alignment: .top, spacing: 10) {
                                    ForEach(rs[(row * cols)..<min(rs.count, row * cols + cols)]) { r in
                                        MiniPlan(r: r, s0: sc, name: dn(r.name), maxW: cw - 12)
                                            .padding(6).frame(width: cw)
                                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                                            .boxShadow(G.shade.opacity(0.12), blur: 28, y: 12)
                                            .pressable(0.98) { app.push(.editor(pid: p.id, rid: r.id, mode: "plan")) }
                                            .accessibilityIdentifier("v2d.room")
                                    }
                                }
                            }
                        }
                        .background(GeometryReader { Color.clear.preference(key: GridH.self, value: $0.size.height) })
                    }
                    .modifier(FitHeight())
                }
            }
            NoteLine(text: tr("v2d.note"))
        }
    }
}

/// A GeometryReader as tall as what it holds.
private struct GridH: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct FitHeight: ViewModifier {
    @State private var h: CGFloat = 10
    func body(content: Content) -> some View { content.frame(height: h).onPreferenceChange(GridH.self) { if $0 > 0 { h = $0 } } }
}

private let INK2D = Color(argb: 0xFF0E1C36)
private let INK3_2D = Color(argb: 0xFF3E4A61)

/// A room's plan at a common scale s0 (pt per mm, prototype miniPlan and its sketch override): the walls as a solid ring,
/// doors and windows as gaps with the door's swing, the two side lengths, the name and the floor area. Shrinks to maxW.
struct MiniPlan: View {
    let r: Room
    let s0: CGFloat
    let name: String
    let maxW: CGFloat

    var body: some View {
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap
        let g = r.isPoly ? Geo.polyGeo(r, snap) : nil
        let T = CGFloat(r.dim("T").v ?? 200)
        // the drawing's own size, as in the prototype's svg width/height
        let box: (CGFloat, CGFloat, CGFloat) = {
            var s = s0
            if let g {
                let xs = g.verts.map { CGFloat($0.x) }, ys = g.verts.map { CGFloat($0.y) }
                let bw = xs.max()! - xs.min()!, bh = ys.max()! - ys.min()!
                if max(bw, bh) * s > 170 { s = 170 / max(bw, bh) }
                let tw = max(2.5, T * s)
                return (s, bw * s + 2 * (18 + tw), bh * s + 2 * (18 + tw))
            }
            let ok = r.dim("A").v != nil && r.dim("B").v != nil
            let L = ok ? CGFloat(r.dim("A").v!) : 4000, W = ok ? CGFloat(r.dim("B").v!) : 3000
            let t = max(2.5, T * s)
            return (s, L * s + 2 * t + 36, W * s + 2 * t + 36)
        }()
        let s = box.0, vw = box.1, vh = box.2
        let k = min(1, maxW / vw)
        Canvas { ctx, size in
            var c = ctx
            let px = size.width / vw
            c.scaleBy(x: px, y: px)
            if let g { polyMini(c, g, s, T, en) } else { rectMini(c, s, T, unit, en) }
        }
        .frame(width: vw * k, height: vh * k)
        .accessibilityLabel(Text(name))
    }

    private func label(_ c: GraphicsContext, _ t: String, _ p: CGPoint, name: Bool) {
        if name { c.text(t, p, .ui, 10.5, 600, INK2D, tracking: 0.05) } else { c.text(t, p, .num, 11, 400, INK3_2D) }
    }

    private func rectMini(_ c: GraphicsContext, _ s: CGFloat, _ T: CGFloat, _ unit: LenUnit, _ en: Bool) {
        let ok = r.dim("A").v != nil && r.dim("B").v != nil
        let L = ok ? CGFloat(r.dim("A").v!) : 4000, W = ok ? CGFloat(r.dim("B").v!) : 3000
        let t = max(2.5, T * s), iw = L * s, ih = W * s
        let x0 = 18 + t, y0 = 18 + t, x1 = x0 + iw, y1 = y0 + ih
        if ok {
            var ring = Path(CGRect(x: x0 - t, y: y0 - t, width: iw + 2 * t, height: ih + 2 * t)); ring.addRect(CGRect(x: x0, y: y0, width: iw, height: ih))
            c.fill(ring, with: .color(INK2D), style: FillStyle(eoFill: true))
            let wl: [String: (CGPoint, CGPoint)] = ["A": (CGPoint(x: x0, y: y0), CGPoint(x: 1, y: 0)), "B": (CGPoint(x: x1, y: y0), CGPoint(x: 0, y: 1)),
                                                    "C": (CGPoint(x: x1, y: y1), CGPoint(x: -1, y: 0)), "D": (CGPoint(x: x0, y: y1), CGPoint(x: 0, y: -1))]
            for o in r.openings {
                guard let sd = wl[o.wall] else { continue }
                let st = sd.0, d = sd.1, n = CGPoint(x: -d.y, y: d.x)
                let p0 = st + d * (CGFloat(o.off) * s), p1 = st + d * (CGFloat(o.off + o.w) * s), q0 = p0 - n * t, q1 = p1 - n * t
                let quad = polyPath([p0, p1, q1, q0])
                c.fill(quad, with: .color(.white))
                if o.type == "door" {
                    let rr = CGFloat(o.w) * s
                    c.line(INK2D, p0, p0 + n * rr, 1.4)
                    // the swing: from the far jamb round to the leaf's tip, dashed (svg arc, sweep flag 1)
                    let start = atan2(d.y, d.x)
                    var arc = Path()
                    arc.addArc(center: p0, radius: rr, startAngle: .radians(start), endAngle: .radians(start + .pi / 2), clockwise: false)
                    c.stroke(arc, with: .color(INK2D), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                } else {
                    c.stroke(quad, with: .color(INK2D), lineWidth: 0.8)
                    c.line(INK2D, mid(p0, q0), mid(p1, q1), 0.8)
                }
            }
            label(c, Geo.fmtLen(Int(L), unit, en), CGPoint(x: (x0 + x1) / 2, y: y0 - t - 9), name: false)
            var rc = c; rc.translateBy(x: x0 - t - 9, y: (y0 + y1) / 2); rc.rotate(by: .degrees(-90))
            label(rc, Geo.fmtLen(Int(W), unit, en), .zero, name: false)
        } else {
            c.stroke(Path(CGRect(x: x0, y: y0, width: iw, height: ih)), with: .color(Color(argb: 0xFF5F6B82)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
        let cx = (x0 + x1) / 2, cy = (y0 + y1) / 2
        label(c, name.uppercased(), CGPoint(x: cx, y: cy - 6), name: true)
        label(c, (ok ? Geo.fmtArea(Int64(L) * Int64(W), en) : "?") + " m²", CGPoint(x: cx, y: cy + 7), name: false)
    }

    private func polyMini(_ c: GraphicsContext, _ g: Geo.PolyGeo, _ s: CGFloat, _ T: CGFloat, _ en: Bool) {
        let v = g.verts
        let minX = CGFloat(v.map(\.x).min()!), minY = CGFloat(v.map(\.y).min()!)
        let tw = max(2.5, T * s), ox = 18 + tw - minX * s, oy = 18 + tw - minY * s
        let ip = v.map { CGPoint(x: ox + CGFloat($0.x) * s, y: oy + CGFloat($0.y) * s) }
        let n = ip.count
        let uu: [CGPoint] = v.indices.map { i in
            let a = v[i], b = v[(i + 1) % n], l0 = hypot(b.x - a.x, b.y - a.y), l = l0 > 0 ? l0 : 1
            return CGPoint(x: (b.x - a.x) / l, y: (b.y - a.y) / l)
        }
        let no = uu.map { CGPoint(x: $0.y, y: -$0.x) }
        let op: [CGPoint] = ip.enumerated().map { i, p in
            let a = no[(i - 1 + n) % n], b = no[i], d = 1 + a.x * b.x + a.y * b.y
            return d < 0.15 ? p + b * tw : p + (a + b) * (tw / d)
        }
        if g.solved {
            var ring = polyPath(op); ring.addPath(polyPath(ip))
            c.fill(ring, with: .color(INK2D), style: FillStyle(eoFill: true))
            let ids = g.walls.map(\.id)
            for o in r.openings {
                guard let i = ids.firstIndex(of: o.wall) else { continue }
                let d = uu[i], q = no[i]
                let p0 = ip[i] + d * (CGFloat(o.off) * s), p1 = ip[i] + d * (CGFloat(o.off + o.w) * s), q0 = p0 + q * tw, q1 = p1 + q * tw
                let quad = polyPath([p0, p1, q1, q0])
                c.fill(quad, with: .color(.white))
                if o.type == "window" { c.stroke(quad, with: .color(INK2D), lineWidth: 0.8) }
                else { c.line(INK2D, p0, p0 - q * (CGFloat(o.w) * s), 1.4) }
            }
        } else {
            c.stroke(polyPath(ip), with: .color(Color(argb: 0xFF5F6B82)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
        let lp = labelPt(v.map { ($0.x, $0.y) })
        let cp = CGPoint(x: ox + CGFloat(lp.0) * s, y: oy + CGFloat(lp.1) * s)
        label(c, name.uppercased(), CGPoint(x: cp.x, y: cp.y - 6), name: true)
        label(c, (g.solved ? Geo.fmtArea(Int64(abs(Geo.shoelace(v))), en) : "?") + " m²", CGPoint(x: cp.x, y: cp.y + 7), name: false)
    }
}

/// Where a drawn room's name goes: the centroid, or the middle of the widest run across it (prototype skLabelPt).
func labelPt(_ v: [(Double, Double)]) -> (Double, Double) {
    var a = 0.0, cx = 0.0, cy = 0.0
    for i in v.indices { let p = v[i], q = v[(i + 1) % v.count]; let c = p.0 * q.1 - q.0 * p.1; a += c; cx += (p.0 + q.0) * c; cy += (p.1 + q.1) * c }
    let c = abs(a) < 1e-9 ? (v.map(\.0).reduce(0, +) / Double(v.count), v.map(\.1).reduce(0, +) / Double(v.count)) : (cx / (3 * a), cy / (3 * a))
    var inside = false
    var j = v.count - 1
    for i in v.indices {
        let pa = v[i], pb = v[j]
        if (pa.1 > c.1) != (pb.1 > c.1) && c.0 < (pb.0 - pa.0) * (c.1 - pa.1) / (pb.1 - pa.1) + pa.0 { inside.toggle() }
        j = i
    }
    if inside { return c }
    let y = c.1
    var xs: [Double] = []
    for i in v.indices { let pa = v[i], pb = v[(i + 1) % v.count]; if (pa.1 > y) != (pb.1 > y) { xs.append(pa.0 + (y - pa.1) * (pb.0 - pa.0) / (pb.1 - pa.1)) } }
    xs.sort()
    var best: (Double, Double)? = nil
    var bw = -1.0
    var i = 0
    while i + 1 < xs.count { if xs[i + 1] - xs[i] > bw { bw = xs[i + 1] - xs[i]; best = ((xs[i] + xs[i + 1]) / 2, y) }; i += 2 }
    return best ?? v[0]
}

/// One workspace's measured rooms in 3D (prototype view '3d').
struct Project3D: View {
    let app: AppModel
    let p: Project
    let floor: String?
    @State private var cam = Cam3D()

    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let fid = floor.flatMap { id in p.floors.contains { $0.id == id } ? id : nil } ?? p.floors.first?.id
        let rs = p.rooms.filter { $0.floorId == fid && Geo.ready3D($0, snap) }
        VStack(alignment: .leading, spacing: 0) {
            if p.floors.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(p.floors) { f in
                            let on = f.id == fid
                            T(floorName(f), ui(14, 600, on ? .white : G.ink), lines: 1)
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? G.cobalt : G.glass(0.55)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? G.cobalt : G.rim, lineWidth: 1))
                                .pressable(0.97) { app.setProjectView("3d", floor: f.id) }
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            if rs.isEmpty { T(tr("v3d.none"), ui(13.5, 400, G.ink2)).padding(.vertical, 6) }
            else {
                let names = rs.map { dn($0.name) }
                let shell = buildShell(rs, single: false, snap: snap) { dn($0.name) }
                let r3 = shell.rooms3
                Scene3D(shell: shell, key: shellKey(rs, snap, names), cam: cam,
                        points: r3.map { $0.map { V3($0.cx, $0.h + 0.45, $0.cz) } } ?? shell.labels.map(\.p),
                        label: { i in
                            if let r3 {
                                let x = r3[i]
                                return AnyView(RoomLbl3D(text: x.name, on: cam.focus == x.id) {
                                    if cam.focus == x.id { all(shell) }
                                    else { cam.focus = x.id; cam.go(V3(x.cx, x.h * 0.3, x.cz), min(cam.rMax ?? 99, v3Fit(x.w, x.d, x.h, cam.aspect) * 1.6)) }
                                })
                            }
                            return AnyView(Lbl3D(text: shell.labels[i].text))
                        }) {
                    if r3 != nil {
                        ShotPill(icon: "room", label: tr("3d.all")) { all(shell) }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 10).padding(.bottom, 10)
                            .accessibilityIdentifier("3d.all")
                    }
                }
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            NoteLine(text: tr("v3d.note", ["n": rs.count]))
        }
    }

    private func all(_ shell: Shell3D) {
        cam.focus = nil
        cam.go(V3(shell.L / 2, shell.H * 0.3, shell.W / 2), cam.rFit ?? cam.r, .pi / 2 + 0.45, 0.9)
    }
}
