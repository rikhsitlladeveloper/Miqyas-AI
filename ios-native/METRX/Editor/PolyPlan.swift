import SwiftUI

/* The plan of a drawn room (prototype skPlanSVG), its Shape and Diagonal modes (skDragTo, skDiagMode); Android PolyPlan. */

/// Layout of the polygon in a 360-wide viewBox: inner outline, outer offset by the wall thickness, outward normals.
struct PolyLayout {
    let VW: CGFloat = 360, M: CGFloat = 74, MY: CGFloat = 56
    let s: CGFloat, tw: CGFloat, ox: CGFloat, oy: CGFloat, VH: CGFloat
    let inner: [CGPoint], normals: [CGPoint], outer: [CGPoint]
    var n: Int { inner.count }

    init(_ verts: [Pt], _ T: Int) {
        let minX = verts.map(\.x).min() ?? 0, maxX = verts.map(\.x).max() ?? 1
        let minY = verts.map(\.y).min() ?? 0, maxY = verts.map(\.y).max() ?? 1
        let bw = max(1, CGFloat(maxX - minX)), bh = max(1, CGFloat(maxY - minY))
        let T = CGFloat(T)
        let s = min((360 - 2 * 74) / (bw + 2 * T), 240 / (bh + 2 * T))
        let tw = max(3, T * s)
        let ox = (360 - bw * s) / 2 - CGFloat(minX) * s
        let oy = 56 + tw - CGFloat(minY) * s
        self.s = s; self.tw = tw; self.ox = ox; self.oy = oy
        VH = bh * s + 2 * tw + 2 * 56
        let inner = verts.map { CGPoint(x: ox + CGFloat($0.x) * s, y: oy + CGFloat($0.y) * s) }
        let n = inner.count
        // outward normal of wall i (clockwise outline, y down)
        let normals = (0..<n).map { i -> CGPoint in let a = inner[i], b = inner[(i + 1) % n]; return norm(CGPoint(x: b.y - a.y, y: -(b.x - a.x))) }
        outer = (0..<n).map { i in
            let n1 = normals[(i - 1 + n) % n], n2 = normals[i]
            let dot = n1.dot(n2)
            return 1 + dot < 0.15 ? inner[i] + n2 * tw : inner[i] + (n1 + n2) * (tw / (1 + dot))
        }
        self.inner = inner; self.normals = normals
    }
    func p(_ v: Pt) -> CGPoint { CGPoint(x: ox + CGFloat(v.x) * s, y: oy + CGFloat(v.y) * s) }
    func mm(_ o: CGPoint) -> Pt { Pt(x: Double((o.x - ox) / s), y: Double((o.y - oy) / s)) }
}

struct PolyPlan: View {
    let pid: String
    let r: Room
    let sel: String?
    let selOp: String?

    @State private var live: [Pt]? = nil              // corners while one is dragged
    @State private var guides: ([Double], [Double]) = ([], [])
    @State private var g: Gest? = nil
    private struct Gest { var corner: Int?; var frozen: PolyLayout?; var moved = false; var cur: [Pt] = []; var far = false }

    private var ops: RoomOps { RoomOps.shared }
    private var app: AppModel { AppModel.shared }

    var body: some View {
        // the room's own snap (kept when it was drawn), also for dragging its corners
        let snap = r.poly?.snap ?? AppSettings.shared.angleSnap
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en
        let geo = Geo.polyGeo(r, snap)
        let mode = ops.polyRoom == r.id ? ops.polyMode : "plan"
        let drawVerts = mode == "shape" ? (live ?? r.poly!.verts) : geo.verts
        let lay = PolyLayout(drawVerts, r.dim("T").v ?? 200)
        let thick = r.dim("T").v ?? 200
        ZStack(alignment: .topLeading) {
            GeometryReader { gr in
                Canvas { ctx, size in
                    let fit = Fit(size, lay.VW, lay.VH)
                    var c = ctx; fit.apply(&c)
                    drawPoly(c, lay, r, geo, mode, sel, selOp, unit, en, dn(r.name), ops.diagFirst, snap: snap)
                    if mode == "shape" {
                        for x in guides.0 { let gx = lay.ox + CGFloat(x) * lay.s; c.line(PC.cob.opacity(0.75), CGPoint(x: gx, y: 0), CGPoint(x: gx, y: lay.VH), 1, dash: [6, 4]) }
                        for y in guides.1 { let gy = lay.oy + CGFloat(y) * lay.s; c.line(PC.cob.opacity(0.75), CGPoint(x: 0, y: gy), CGPoint(x: lay.VW, y: gy), 1, dash: [6, 4]) }
                        for p in lay.inner { c.disc(PC.white, 7.5, p); c.ring(PC.cob, 7.5, p, 2) }
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let fit = Fit(gr.size, lay.VW, lay.VH)
                    if g == nil {
                        var st = Gest()
                        if mode == "shape" {
                            let sp = fit.vb(v.startLocation)
                            if let ci = lay.inner.indices.min(by: { (lay.inner[$0] - sp).len < (lay.inner[$1] - sp).len }), (lay.inner[ci] - sp).len <= 22 {
                                st.corner = ci; st.frozen = PolyLayout(r.poly!.verts, thick)     // the view stays still while dragging
                                st.cur = r.poly!.verts
                            }
                        }
                        g = st
                    }
                    guard var st = g else { return }
                    if (v.location - v.startLocation).len > 10 { st.far = true }
                    if mode == "shape", let ci = st.corner, let frozen = st.frozen {
                        let orig = r.poly!.verts
                        let q = frozen.mm(fit.vb(v.location))
                        let (np, gd) = dragCorner(orig, ci, q, snap, Double(10 / frozen.s))
                        if st.moved || hypot(np.x - orig[ci].x, np.y - orig[ci].y) >= 10 {
                            st.moved = true
                            var cur = orig; cur[ci] = np
                            st.cur = cur; live = cur; guides = gd
                        }
                    }
                    g = st
                }.onEnded { v in
                    defer { g = nil; live = nil; guides = ([], []) }
                    guard let st = g else { return }
                    let fit = Fit(gr.size, lay.VW, lay.VH)
                    if mode == "shape" {
                        if st.moved {
                            if Geo.selfIntersects(st.cur) != nil || Geo.shoelace(st.cur) <= 0 { app.say("sk.crossDrag", kind: .error) }
                            else { let cur = st.cur; ops.change(pid, r.id) { $0.poly?.verts = cur } }
                        }
                        return
                    }
                    // a tap (no drag in the polygon plan, as in the prototype)
                    if st.far { return }
                    let sp = fit.vb(v.startLocation)
                    if mode == "diag" { diagTap(lay, sp); return }
                    switch polyHit(r, geo, lay, sp) {
                    case .op(let id)?: app.sheet = .openingForm(pid: pid, rid: r.id, oid: id, type: "door", wall: nil)
                    case .dim(let w)?: ops.select(pid, r.id, w)
                    case nil: break
                    }
                })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(dn(r.name)))
                .accessibilityIdentifier("plan")
            }
            .padding(.top, 56).padding(.bottom, 60)
            // Shape / Diagonal buttons, or the mode's hint with Done / Cancel
            HStack(spacing: 8) {
                if mode == "plan" {
                    ModePill(icon: "pen", label: tr("ed2.shape")) { ops.polyRoom = r.id; ops.polyMode = "shape"; ops.diagFirst = nil; app.sheet = nil }
                    ModePill(icon: "dim", label: tr("ed2.diag")) { ops.polyRoom = r.id; ops.polyMode = "diag"; ops.diagFirst = nil; app.sheet = nil }
                } else {
                    let hint = mode == "shape" ? tr("sk.editHint") : tr(ops.diagFirst == nil ? "sk.pick1" : "sk.pick2")
                    T(hint, ui(13, 500, G.ink2, lh: 1.3))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.sheet(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                    ModePill(icon: mode == "shape" ? "check" : "x", label: tr(mode == "shape" ? "common.done" : "common.cancel")) { ops.polyMode = "plan"; ops.diagFirst = nil }
                }
            }
            .padding(12)
        }
    }

    /// Diagonal mode: tap two corners that are not neighbours; tap a diagonal's pill to remove it.
    private func diagTap(_ lay: PolyLayout, _ p: CGPoint) {
        let poly = r.poly!
        for d in poly.diags {
            let c = mid(lay.inner[d.a], lay.inner[d.b])
            if abs(p.x - c.x) < 36 && abs(p.y - c.y) < 16 {
                ops.change(pid, r.id) { $0.poly?.diags.removeAll { $0.id == d.id }; $0.dims.removeValue(forKey: d.id) }
                app.say("sk.diagDel", ["d": d.id], action: "common.undo") { [pid, rid = r.id] in RoomOps.shared.undo(pid, rid) }
                return
            }
        }
        guard let ci = lay.inner.indices.min(by: { (lay.inner[$0] - p).len < (lay.inner[$1] - p).len }), (lay.inner[ci] - p).len <= 22 else { return }
        guard let first = ops.diagFirst else { ops.diagFirst = ci; return }
        if first == ci { ops.diagFirst = nil; return }
        let n = lay.n
        if abs(first - ci) == 1 || abs(first - ci) == n - 1 { app.say("sk.diagAdj", kind: .info); return }
        let a = min(first, ci), b = max(first, ci)
        if poly.diags.contains(where: { $0.a == a && $0.b == b }) { app.say("sk.diagDup", kind: .info); ops.polyMode = "plan"; ops.diagFirst = nil; return }
        var k = 1; while poly.diags.contains(where: { $0.id == "X\(k)" }) { k += 1 }
        let id = "X\(k)"
        ops.change(pid, r.id) { $0.poly?.diags.append(Diag(id: id, a: a, b: b)); $0.dims[id] = Dim() }
        ops.polyMode = "plan"; ops.diagFirst = nil
        app.say("sk.diagAdded", ["d": id, "a": a + 1, "b": b + 1])
        ops.focus(r.id, id)
    }
}

private struct ModePill: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 6) { MIcon(icon, G.cobalt, 16, 2.2); T(label, ui(13.5, 700), lines: 1) }
            .padding(.horizontal, 12).frame(minHeight: 40)
            .glassBlur(Capsule(), tint: G.sheet(0.6))
            .overlay(Capsule().strokeBorder(G.rim, lineWidth: 1))
            .pressable(0.96, action)
    }
}

/// Where a dragged corner goes (prototype skDragTo): the walls from the neighbours snap to 45° within 8°, else the corner
/// lines up with another corner within 10 pt; 10 mm steps. Returns the guides through aligned corners.
private func dragCorner(_ v: [Pt], _ i: Int, _ q: Pt, _ snap: Bool, _ tolMm: Double) -> (Pt, ([Double], [Double])) {
    let n = v.count, prev = v[(i - 1 + n) % n], next = v[(i + 1) % n]
    var p = q
    var snapped = false
    if snap {
        func ray(_ o: Pt) -> (Double, Bool) { let a = atan2(q.y - o.y, q.x - o.x); let sa = Geo.snapAngle(a); return (sa, abs(a - sa) < 0.14) }
        let r1 = ray(prev), r2 = ray(next)
        if r1.1 && r2.1 {
            let d1x = cos(r1.0), d1y = sin(r1.0), d2x = cos(r2.0), d2y = sin(r2.0)
            let det = d1x * (-d2y) - d1y * (-d2x)
            if abs(det) > 1e-6 {
                let t = ((next.x - prev.x) * (-d2y) - (next.y - prev.y) * (-d2x)) / det
                let sd = (d1x * (next.y - prev.y) - d1y * (next.x - prev.x)) / det
                if t > 0 && sd > 0 { p = Pt(x: prev.x + t * d1x, y: prev.y + t * d1y); snapped = true }
            }
        }
        if !snapped && (r1.1 || r2.1) {
            let o = r1.1 ? prev : next, a = r1.1 ? r1.0 : r2.0
            let ux = cos(a), uy = sin(a), t = (q.x - o.x) * ux + (q.y - o.y) * uy
            p = Pt(x: o.x + t * ux, y: o.y + t * uy); snapped = true
        }
    }
    let others = v.enumerated().filter { $0.offset != i }.map(\.element)
    if !snapped {
        if let bx = others.min(by: { abs($0.x - q.x) < abs($1.x - q.x) }), abs(bx.x - q.x) < tolMm { p.x = bx.x }
        if let by = others.min(by: { abs($0.y - q.y) < abs($1.y - q.y) }), abs(by.y - q.y) < tolMm { p.y = by.y }
    }
    p = Pt(x: Double(kround(p.x / 10) * 10), y: Double(kround(p.y / 10) * 10))
    return (p, (others.filter { abs($0.x - p.x) <= 1 }.map(\.x), others.filter { abs($0.y - p.y) <= 1 }.map(\.y)))
}

private func polyHit(_ r: Room, _ g: Geo.PolyGeo, _ lay: PolyLayout, _ p: CGPoint) -> PlanHit? {
    for o in r.openings {
        guard let i = g.walls.firstIndex(where: { $0.id == o.wall }) else { continue }
        let a = lay.inner[i], b = lay.inner[(i + 1) % lay.n]
        let u = norm(b - a), drawn = (b - a).len, real = g.walls[i].len ?? Int(drawn / lay.s)
        let kk = drawn / CGFloat(max(1, real))
        let rel = p - a, along = rel.dot(u), out = rel.dot(lay.normals[i])
        if along >= CGFloat(o.off - 150) * kk && along <= CGFloat(o.off + o.w + 150) * kk && out >= -30 && out <= lay.tw + 6 { return .op(o.id) }
    }
    // a diagonal's pill opens its card again
    for d in r.poly?.diags ?? [] where d.a < lay.n && d.b < lay.n {
        let c = mid(lay.inner[d.a], lay.inner[d.b])
        if abs(p.x - c.x) < 36 && abs(p.y - c.y) < 16 { return .dim(d.id) }
    }
    for i in 0..<lay.n {
        let c = mid(lay.inner[i], lay.inner[(i + 1) % lay.n]) + lay.normals[i] * (lay.tw + 30)
        if abs(p.x - c.x) < 40 && abs(p.y - c.y) < 18 { return .dim(g.walls[i].id) }
    }
    for i in 0..<lay.n {
        let a = lay.inner[i], b = lay.inner[(i + 1) % lay.n]
        let u = norm(b - a), len = (b - a).len
        let rel = p - a, along = rel.dot(u), out = rel.dot(lay.normals[i])
        if along >= -12 && along <= len + 12 && out >= -12 && out <= lay.tw + 12 { return .dim(g.walls[i].id) }
    }
    return nil
}

/// A drawn room's plan for the report, in the 360-wide units; returns its height.
func drawReportPoly(_ ctx: GraphicsContext, _ r: Room, _ unit: LenUnit, _ en: Bool, _ label: String, snap: Bool,
                    labelMode: String = "both", m2: String = "m²") -> CGFloat {
    let g = Geo.polyGeo(r, snap), lay = PolyLayout(g.verts, r.dim("T").v ?? 200)
    Theme.shared.onPaper { drawPoly(ctx, lay, r, g, "plan", nil, nil, unit, en, label, nil, snap: snap, report: true, m2: m2, labelMode: labelMode) }
    return lay.VH
}

func reportPolyHeight(_ r: Room, snap: Bool) -> CGFloat { PolyLayout(Geo.polyGeo(r, snap).verts, r.dim("T").v ?? 200).VH }

private func drawPoly(_ ctx: GraphicsContext, _ lay: PolyLayout, _ r: Room, _ g: Geo.PolyGeo, _ mode: String, _ sel: String?, _ selOp: String?,
                      _ unit: LenUnit, _ en: Bool, _ label: String, _ diagFirst: Int?, snap: Bool, report: Bool = false,
                      m2: String = tr("u.m2"), labelMode: String? = nil) {
    let n = lay.n
    guard n >= 3, g.walls.count == n else { return }
    let inner = polyPath(lay.inner), outer = polyPath(lay.outer)
    var ring = Path(); ring.addPath(outer); ring.addPath(inner)
    let solved = g.solved || mode == "shape"
    if mode == "shape" { ctx.fill(inner, with: .color(PC.cobWash)) }
    func band(_ i: Int) -> Path { polyPath([lay.inner[i], lay.inner[(i + 1) % n], lay.outer[(i + 1) % n], lay.outer[i]]) }
    let si = mode == "plan" ? g.walls.firstIndex { $0.id == sel } : nil
    // the selected wall: a pale band
    if let i = si { ctx.fill(band(i), with: .color(PC.selBand)); ctx.stroke(band(i), with: .color(PC.cob), lineWidth: 6) }
    if solved {
        ctx.fill(ring, with: .color(PC.white), style: FillStyle(eoFill: true))
        var hc = ctx; hc.clip(to: ring, style: FillStyle(eoFill: true))
        var x = -lay.VH
        while x < lay.VW + lay.VH { hc.line(PC.ink, CGPoint(x: x, y: lay.VH), CGPoint(x: x + lay.VH, y: 0), 1.1); x += 5.66 }
        ctx.stroke(outer, with: .color(PC.ink), lineWidth: 1.2); ctx.stroke(inner, with: .color(PC.ink), lineWidth: 1.2)
    } else {
        ctx.stroke(inner, with: .color(PC.greyLine), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }
    if let i = si { ctx.fill(band(i), with: .color(PC.cob)) }
    // doors and windows along their wall, placed in proportion
    if mode == "plan" {
        for o in r.openings.flatMap({ $0.drawnParts }) {
            guard let i = g.walls.firstIndex(where: { $0.id == o.wall }) else { continue }
            let a = lay.inner[i], b = lay.inner[(i + 1) % n], u = norm(b - a), nn = lay.normals[i]
            let drawn = (b - a).len, real = g.walls[i].len ?? max(1, Int(drawn / lay.s)), kk = drawn / CGFloat(max(1, real))
            let p0 = a + u * (CGFloat(o.off) * kk), p1 = a + u * (CGFloat(o.off + o.w) * kk)
            let c = o.id == selOp ? PC.cob : PC.ink
            let quad = polyPath([p0, p1, p1 + nn * lay.tw, p0 + nn * lay.tw])
            if o.type == "door" {
                ctx.fill(quad, with: .color(PC.paper))
                ctx.line(c, p0, p0 - nn * (CGFloat(o.w) * kk), 2.2, round: true)
                ctx.line(c, p0, p0 + nn * lay.tw, 1.2); ctx.line(c, p1, p1 + nn * lay.tw, 1.2)
            } else {
                ctx.fill(quad, with: .color(PC.white)); ctx.stroke(quad, with: .color(c), lineWidth: 1.2)
                ctx.line(c, p0 + nn * (lay.tw / 3), p1 + nn * (lay.tw / 3), 1); ctx.line(c, p0 + nn * (2 * lay.tw / 3), p1 + nn * (2 * lay.tw / 3), 1)
            }
        }
    }
    // furniture orders: sockets, switches and pipes, just inside their wall
    if mode == "plan" {
        for x in r.points {
            guard let i = g.walls.firstIndex(where: { $0.id == x.wall }) else { continue }
            let a = lay.inner[i], b = lay.inner[(i + 1) % n], u = norm(b - a)
            let drawn = (b - a).len, real = g.walls[i].len ?? max(1, Int(drawn / lay.s)), kk = drawn / CGFloat(max(1, real))
            drawSitePoint(ctx, x, a + u * (CGFloat(x.off) * kk) - lay.normals[i] * 7, 0, 6.5, 1)
        }
    }
    // name and floor area in the middle
    let a = Geo.areas(r, snap)
    let cx = lay.inner.map(\.x).reduce(0, +) / CGFloat(n), cy = lay.inner.map(\.y).reduce(0, +) / CGFloat(n)
    centreLabel(ctx, label, (a.map { Geo.fmtArea($0.floor, en) } ?? "?") + " " + m2, CGPoint(x: cx, y: cy), mode: labelMode)
    // wall letters and corner numbers
    for i in 0..<n {
        let m = mid(lay.inner[i], lay.inner[(i + 1) % n]) - lay.normals[i] * 17
        let on = mode == "plan" && g.walls[i].id == sel
        ctx.disc(on ? PC.cob : PC.white, 9, m); ctx.ring(on ? PC.cob : PC.ink3, 9, m, 1)
        ctx.text(g.walls[i].id, m, .ui, 11, 600, on ? PC.onFill : PC.ink)
        let bis = norm(lay.normals[(i - 1 + n) % n] + lay.normals[i])
        let cp = lay.inner[i] - bis * 12
        let dg = mode == "diag"
        if dg { ctx.disc(diagFirst == i ? PC.cob : PC.white, 11, cp); ctx.ring(PC.cob, 11, cp, 1.5) }
        ctx.text("\(i + 1)", cp, .ui, dg ? 11 : 9.5, dg ? 700 : 400, dg && diagFirst == i ? PC.onFill : PC.ink3)
    }
    // a dimension per wall, parallel to it, with a status pill; a pill that would cover another moves further out
    var placed: [CGRect] = []
    if mode != "shape" {
        for i in 0..<n {
            let w = g.walls[i], wa = lay.inner[i], wb = lay.inner[(i + 1) % n], nn = lay.normals[i]
            let d = r.dim(w.id)
            let txt: String, st: String
            switch w.status {
            case "conf": txt = Geo.fmtLen(d.v, unit, en); st = "conf"
            case "recv": txt = Geo.fmtLen(d.pending?.mm, unit, en, full: true); st = "recv"
            case "calc": txt = "=" + Geo.fmtLen(w.len, unit, en); st = "calc"
            case "bad": txt = "[" + Geo.fmtLen(d.v, unit, en) + "]"; st = "bad"
            case "unres": txt = "[?]"; st = "unres"
            default: txt = "?"; st = "unset"
            }
            let pw = pillW(txt, st != "unset" && st != "calc")
            var o = lay.tw + 30
            func boxAt(_ o: CGFloat) -> (CGPoint, CGRect) { let c = mid(wa, wb) + nn * o; return (c, CGRect(x: c.x - pw / 2 - 4, y: c.y - 17, width: pw + 8, height: 34)) }
            var (c, box) = boxAt(o)
            var tries = 0
            while tries < 3 && placed.contains(where: { $0.intersects(box) }) { o += 30; (c, box) = boxAt(o); tries += 1 }
            placed.append(box)
            let lc = w.status == "conf" ? PC.ink : w.status == "recv" ? PC.amber : w.status == "bad" ? PC.red : w.status == "calc" ? PC.cob : PC.greyLine
            ctx.line(lc, wa + nn * o, wb + nn * o, 1.1, dash: w.status == "conf" ? nil : [5, 4])
            ctx.line(lc.opacity(0.5), wa + nn * (lay.tw + 3), wa + nn * (o + 4), 0.8); ctx.line(lc.opacity(0.5), wb + nn * (lay.tw + 3), wb + nn * (o + 4), 0.8)
            polyPill(ctx, txt, c, st, report)
        }
        // diagonals: a dotted line with its pill
        for dg in r.poly?.diags ?? [] where dg.a < n && dg.b < n {
            let pa = lay.inner[dg.a], pb = lay.inner[dg.b]
            ctx.line(PC.ink3, pa, pb, 1, dash: [2, 4])
            let d = r.dim(dg.id)
            let st = g.diagStatus[dg.id] ?? "unset"
            let txt = st == "recv" ? Geo.fmtLen(d.pending?.mm, unit, en, full: true) : st == "unset" ? "?" : st == "warn" ? "[" + Geo.fmtLen(d.v, unit, en) + "]" : Geo.fmtLen(d.v, unit, en)
            polyPill(ctx, txt, mid(pa, pb), st == "ok" || st == "conf" ? "conf" : st == "warn" ? "unres" : st, report)
        }
    }
}

/// A glass pill with the value and its status mark (prototype skPill restyled by glass).
private func polyPill(_ ctx: GraphicsContext, _ t: String, _ c: CGPoint, _ st: String, _ report: Bool) {
    let pw = pillW(t, st != "unset" && st != "calc")
    let rect = CGRect(x: c.x - pw / 2, y: c.y - 13, width: pw, height: 26)
    if report && st == "conf" {
        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white))
        ctx.text(t, CGPoint(x: c.x - 7, y: c.y), .num, 15, 600, PC.ink)
        ctx.tick(rect.maxX - 14, c.y, PC.ink, 1.8)
        return
    }
    let fill: Color, edge: Color
    switch st {
    case "calc": fill = pc(0xFFE7EEFD, 0xFF1C2546); edge = PC.cob
    case "bad": fill = pc(0xFFFDEDEB, 0xFF3A1B1B); edge = PC.red
    case "unres": fill = pc(0xFFFFF1DF, 0xFF33260F); edge = PC.amber
    default: fill = PC.pillFill(0.85); edge = PC.pillEdge(1)
    }
    let pill = Path(roundedRect: rect, cornerRadius: 13)
    ctx.fill(pill, with: .color(fill))
    ctx.stroke(pill, with: .color(edge), style: StrokeStyle(lineWidth: st == "bad" ? 1.8 : 1.2, dash: st == "calc" || st == "unset" ? [3, 2] : []))
    let tc = st == "calc" ? PC.cob : st == "bad" ? PC.red : st == "unres" ? PC.amber : PC.pillInk
    let tx = st == "conf" ? c.x - 7 : ["recv", "bad", "unres"].contains(st) ? c.x + 7 : c.x
    ctx.text(t, CGPoint(x: tx, y: c.y), .ui, 15, 800, tc, italic: st == "calc")
    switch st {
    case "conf": ctx.tick(rect.maxX - 14, c.y, PC.okGreen, 2.4)
    case "recv": ctx.clock(CGPoint(x: rect.minX + 12, y: c.y), PC.amber)
    case "bad", "unres": ctx.bang(CGPoint(x: rect.minX + 12, y: c.y), tc)
    default: break
    }
}

/// The polygon hint above the step card (prototype skHint): a conflict, a check that disagrees, or what to measure next.
struct PolyHint: View {
    let pid: String
    let r: Room
    var body: some View {
        let g = Geo.polyGeo(r, AppSettings.shared.angleSnap)
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en
        let warn = g.diagStatus.sorted { $0.key < $1.key }.first { $0.value == "warn" }
        let v: (String, Bool, String?)? = {
            if g.err == "negative" { return (tr("sk.negative", ["w": g.conflict.joined(separator: ", ")]), true, g.conflict.first) }
            if g.err == "cross" { return (tr("sk.crossSol"), true, g.conflict.first) }
            if g.err == "closure" { return (tr("sk.conflict", ["w": g.conflict.joined(separator: ", "), "e": Geo.fmtLen(g.gap, .m, en)]), true, g.conflict.first) }
            if let e = warn { return (tr("sk.diagWarn", ["d": e.key, "e": Geo.fmtLen(abs((r.dim(e.key).v ?? 0) - (g.diagLen[e.key] ?? 0)), .m, en)]), false, nil) }
            if g.either.count == 2 { return (tr("sk.needEither", ["a": g.either[0], "b": g.either[1]]), false, nil) }
            return nil
        }()
        if let v {
            let text = v.0, red = v.1, wall = v.2
            HStack(spacing: 10) {
                MIcon("alert", red ? G.err : PC.amber, 18, 2)
                T(text, ui(13.5, 500, red ? G.err : PC.amber, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                if let wall { T(tr("ms.remeasure"), ui(14, 700, G.cobalt)).padding(6).pressable(0.96) { RoomOps.shared.remeasure(pid, r.id, wall) } }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(red ? G.errWash : G.amberWash))
            .padding(.bottom, 10)
        }
    }
}
