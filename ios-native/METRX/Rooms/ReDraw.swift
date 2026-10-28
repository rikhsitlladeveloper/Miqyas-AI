import SwiftUI

/*
 * The room editor v2's drawings (room-editor mockup v2, approved 28 Oct 2026: planSvg, itemPlan, doorLeaf, frontSvg,
 * frontItem, opArt, ptArt, styleThumb, pkDraw, isoSvg): the plan with the walls drawn outward at their thickness, the
 * doors by style, the windows and the points; one wall seen from inside; the styles' front drawings; the size step's
 * big drawing with the asked edge in blue; the simple 3D. Drawn into SwiftUI canvases in screen points.
 */

/// The drawings' colours (the mockup's tokens, light and dark).
enum RD {
    static var paper: Color { pc(0xFFF7F8FC, 0xFF161C30) }
    static var wallc: Color { pc(0xFF3F475C, 0xFFA3ACC4) }
    static var ink: Color { pc(0xFF0F172A, 0xFFE8ECF7) }
    static var ink2: Color { pc(0xFF475569, 0xFFA9B2C8) }
    static var ink3: Color { pc(0xFF94A3B8, 0xFF69738E) }
    static var blue: Color { pc(0xFF3550E0, 0xFF5B74FF) }
    static var blueSoft: Color { planDark ? Color(argb: 0x335B74FF) : Color(argb: 0x1C3550E0) }
    static var green: Color { pc(0xFF16A34A, 0xFF34D399) }
    static var issue: Color { pc(0xFFE11D48, 0xFFFB7185) }
    static var elev: Color { pc(0xFFF7F6F3, 0xFF262D47) }
    static var doorf: Color { pc(0xFFD9C3A5, 0xFF7A6650) }
    static let glass = Color(argb: 0x7338BDF8)
    static let glassLine = Color(argb: 0xFF0284C7)
    static var isoFloor: Color { pc(0xFFE4DED5, 0xFF454B63) }
    static var isoWall: Color { pc(0xFFECE9E3, 0xFF3A4260) }
    static var isoWall2: Color { pc(0xFFDFDBD3, 0xFF323956) }
    static var isoCap: Color { pc(0xFF9A958C, 0xFF232942) }
    static func kind(_ k: String) -> Color { Color(argb: 0xFF00_0000 | reKind(k).color) }
}

/* ---------------- the plan's mapping ---------------- */

/// Plan mm → screen points: fitted into a box, then zoomed by z and panned by dx, dy.
struct ReMap: Equatable {
    var s: CGFloat = 1
    var ox: CGFloat = 0
    var oy: CGFloat = 0
    var z: CGFloat = 1
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    /// Screen points a millimetre.
    var k: CGFloat { s * z }
    func p(_ q: Pt) -> CGPoint { CGPoint(x: (ox + CGFloat(q.x) * s) * z + dx, y: (oy + CGFloat(q.y) * s) * z + dy) }
    func mm(_ c: CGPoint) -> Pt { Pt(x: Double((((c.x - dx) / z) - ox) / s), y: Double((((c.y - dy) / z) - oy) / s)) }

    /// The plan fitted into box (pad on top and bottom, padX at the sides).
    static func fit(_ g: ReRoomGeo, _ box: CGRect, pad: CGFloat, padX: CGFloat, cam: ReCam = ReCam()) -> ReMap {
        let xs = g.poly.map { CGFloat($0.x) }, ys = g.poly.map { CGFloat($0.y) }
        let mnx = xs.min() ?? 0, mxx = xs.max() ?? 1, mny = ys.min() ?? 0, mxy = ys.max() ?? 1
        let bw = max(mxx - mnx, 1), bh = max(mxy - mny, 1)
        let s = max(1e-5, min((box.width - 2 * padX) / bw, (box.height - 2 * pad) / bh))
        var m = ReMap()
        m.s = s
        m.ox = box.minX + (box.width - bw * s) / 2 - mnx * s
        m.oy = box.minY + (box.height - bh * s) / 2 - mny * s
        m.z = cam.z; m.dx = cam.dx; m.dy = cam.dy
        return m
    }
}

/// A view's zoom (1: fitted) and pan.
struct ReCam: Equatable {
    var z: CGFloat = 1
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var fit: Bool { z == 1 && dx == 0 && dy == 0 }
}

/// A wall on the screen: its ends, along (u) and into the room (n), length, thickness and whether it is seen from
/// inside the other way (its start on the right).
struct ReFrame {
    let id: String
    let a: CGPoint
    let b: CGPoint
    let u: CGPoint
    let n: CGPoint
    let L: CGFloat
    let tp: CGFloat
    let fl: Bool
    /// An inner wall's face (room-editor mockup v3): n is the side it faces, its body behind it.
    var inner = false
    var label = ""
    func at(_ t: CGFloat, _ off: CGFloat, _ k: CGFloat) -> CGPoint { a + u * (t * k) + n * off }
}

func rePip(_ p: CGPoint, _ poly: [CGPoint]) -> Bool {
    var c = false
    var j = poly.count - 1
    for i in poly.indices {
        let a = poly[i], b = poly[j]
        if (a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
        j = i
    }
    return c
}

func reFrames(_ g: ReRoomGeo, _ m: ReMap) -> [ReFrame] {
    let poly = g.poly.map { m.p($0) }
    return g.walls.map { w in
        let a = m.p(w.a), b = m.p(w.b)
        let u = unitV(a, b)
        var n = CGPoint(x: -u.y, y: u.x)
        let L = (b - a).len
        if let lk = w.look {
            // an inner face looks away from its piece (the map only scales and moves, so directions stay)
            n = CGPoint(x: CGFloat(lk.x), y: CGFloat(lk.y))
        } else {
            let probe = mid(a, b) + n * max(2, L * 0.02)
            if !rePip(probe, poly) { n = -n }
        }
        let fl = (u.x * n.y - u.y * n.x) < 0
        return ReFrame(id: w.id, a: a, b: b, u: u, n: n, L: L, tp: max(3, CGFloat(w.t) * m.k), fl: fl, inner: w.inner, label: w.label.isEmpty ? w.id : w.label)
    }
}

/// Where each item is on the plan, for taps: a door's or window's two faces, a point's marker.
struct ReHit {
    let id: String
    let op: Bool
    var p0 = CGPoint.zero, p1 = CGPoint.zero, q0 = CGPoint.zero, q1 = CGPoint.zero
    var c = CGPoint.zero
    var w0 = CGPoint.zero
}

func rePlanHit(_ it: ReItem, _ f: ReFrame, _ k: CGFloat, small: Bool) -> ReHit {
    if it.isOpening {
        return ReHit(id: it.id, op: true, p0: f.at(CGFloat(it.dist), 0, k), p1: f.at(CGFloat(it.dist + it.w), 0, k),
                     q0: f.at(CGFloat(it.dist), -f.tp, k), q1: f.at(CGFloat(it.dist + it.w), -f.tp, k))
    }
    return ReHit(id: it.id, op: false, c: f.at(CGFloat(it.dist), small ? 13 : 15, k), w0: f.at(CGFloat(it.dist), 0, k))
}

/// Distance from p to segment ab, and how far along it (points).
func reSegD(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> (d: CGFloat, t: CGFloat) {
    let d = b - a, L2 = d.x * d.x + d.y * d.y
    let t = L2 > 0 ? max(0, min(1, ((p.x - a.x) * d.x + (p.y - a.y) * d.y) / L2)) : 0
    let q = a + d * t
    return ((p - q).len, t * sqrt(L2))
}

/// The item under p on the plan, or nil.
func reHitItem(_ hits: [ReHit], _ p: CGPoint) -> String? {
    var best: (d: CGFloat, id: String)? = nil
    for x in hits {
        var d: CGFloat
        if x.op {
            d = min(reSegD(p, x.p0, x.p1).d, reSegD(p, x.q0, x.q1).d, reSegD(p, mid(x.p0, x.q0), mid(x.p1, x.q1)).d) + 4
            if d > 20 { continue }
        } else {
            d = (p - x.c).len
            if d > 19 { continue }
        }
        if best == nil || d < best!.d { best = (d, x.id) }
    }
    return best?.id
}

/// The wall nearest to p within maxd points (the outer side counts from the wall's outer face): its id and how far
/// along it, points.
func reNearWall(_ fr: [ReFrame], _ p: CGPoint, _ maxd: CGFloat) -> (id: String, t: CGFloat)? {
    var best: (d: CGFloat, id: String, t: CGFloat)? = nil
    for f in fr {
        let s = reSegD(p, f.a, f.b)
        var d = s.d
        let side = (p - f.a).dot(f.n)
        if side < 0 { d = max(0, d - f.tp) }
        if d < maxd && (best == nil || d < best!.d) { best = (d, f.id, s.t) }
    }
    return best.map { ($0.id, $0.t) }
}

/* ---------------- drawing helpers ---------------- */

extension GraphicsContext {
    func poly(_ pts: [CGPoint], fill: Color? = nil, stroke: Color? = nil, _ w: CGFloat = 1, dash: [CGFloat] = []) {
        let p = polyPath(pts)
        if let fill { self.fill(p, with: .color(fill)) }
        if let stroke { self.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: w, lineJoin: .round, dash: dash)) }
    }
    func box(_ r: CGRect, fill: Color? = nil, stroke: Color? = nil, _ w: CGFloat = 1, rx: CGFloat = 0, dash: [CGFloat] = []) {
        let p = rx > 0 ? Path(roundedRect: r, cornerRadius: rx) : Path(r)
        if let fill { self.fill(p, with: .color(fill)) }
        if let stroke { self.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: w, dash: dash)) }
    }
    /// A 24 × 24 icon of the mockup drawn white (or color) centred on c, size points across.
    func glyph(_ icon: String, _ c: CGPoint, _ size: CGFloat, _ color: Color = .white, _ w: CGFloat = 2.6) {
        var cc = self
        cc.translateBy(x: c.x - size / 2, y: c.y - size / 2)
        cc.scaleBy(x: size / 24, y: size / 24)
        cc.stroke(SVGPath.path(icon), with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }
    /// A pill with text at c: "cur" blue with white text, else paper with a grey rim.
    func pill(_ t: String, _ c0: CGPoint, cur: Bool, bounds: CGSize) {
        let w = max(24, CGFloat(t.count) * 6.6 + 14)
        let c = CGPoint(x: max(w / 2 + 2, min(bounds.width - w / 2 - 2, c0.x)), y: max(12, min(bounds.height - 12, c0.y)))
        let r = CGRect(x: c.x - w / 2, y: c.y - 10, width: w, height: 20)
        box(r, fill: cur ? RD.blue : RD.paper, stroke: cur ? RD.blue : RD.ink3, 1, rx: 10)
        text(t, c, .num, 11, 800, cur ? .white : RD.ink)
    }
    /// An arc around centre from point a to point b (the shorter way), dashed grey: a door's swing.
    func swingArc(_ centre: CGPoint, _ a: CGPoint, _ b: CGPoint) {
        let r = (a - centre).len
        guard r > 0.5 else { return }
        let a0 = atan2(a.y - centre.y, a.x - centre.x), a1 = atan2(b.y - centre.y, b.x - centre.x)
        var d = a1 - a0
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        var p = Path()
        for i in 0...14 {
            let t = a0 + d * CGFloat(i) / 14
            let q = CGPoint(x: centre.x + cos(t) * r, y: centre.y + sin(t) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        stroke(p, with: .color(RD.ink3), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
    }
}

/* ---------------- the plan ---------------- */

/// What a plan shows besides the room: the selection, the wall glowing for a drop, the armed icon (every wall dashed),
/// a ghost item, the magnet, and the dimension options.
struct RePlanLook {
    var selWall: String? = nil
    var selItem: String? = nil
    var hl: String? = nil
    var arm = false
    var ghost: ReItem? = nil
    var mag: String? = nil
    var showLen = true
    var chain = false
    var areaTxt: String? = nil
    var small = false
    var issues: Set<String> = []
    /// Inner walls (room-editor mockup v3): the selected piece, a new one (dashed), the pieces and walls a dragged
    /// piece touches (green: "p<id>", "o<wall>"), the selected piece's gap lines.
    var selPiece: String? = nil
    var newPiece: String? = nil
    var glow: Set<String> = []
    var gaps: [IwGap] = []
}

/// Draws the plan of g with items on the screen mapping m; returns nothing (hits come from rePlanHits).
func reDrawPlan(_ ctx: GraphicsContext, _ size: CGSize, _ g: ReRoomGeo, _ items: [ReItem], _ m: ReMap, _ look: RePlanLook, lenTxt: (Int) -> String) {
    let all = reFrames(g, m)
    // the band is the outer walls; inner faces are drawn as their pieces' bodies
    let fr = all.filter { !$0.inner }
    let n = fr.count
    guard n >= 3 else { return }
    let poly = g.poly.map { m.p($0) }
    ctx.poly(poly, fill: RD.blueSoft)
    // the walls drawn outward at their thickness, joined at mitres
    let oo = fr.map { $0.a - $0.n * $0.tp }
    func lineX(_ p: CGPoint, _ u: CGPoint, _ q: CGPoint, _ v: CGPoint) -> CGPoint {
        let den = u.x * v.y - u.y * v.x
        if abs(den) < 1e-9 { return q }
        let t = ((q.x - p.x) * v.y - (q.y - p.y) * v.x) / den
        return p + u * t
    }
    let outer = (0..<n).map { i -> CGPoint in let j = (i - 1 + n) % n; return lineX(oo[j], fr[j].u, oo[i], fr[i].u) }
    var band = polyPath(outer)
    band.addPath(polyPath(poly))
    ctx.fill(band, with: .color(RD.wallc.opacity(0.82)), style: FillStyle(eoFill: true))
    if let sw = look.selWall, let i = fr.firstIndex(where: { $0.id == sw }) {
        ctx.poly([fr[i].a, fr[i].b, outer[(i + 1) % n], outer[i]], fill: RD.blue.opacity(0.55), stroke: RD.blue, 2)
    }
    for f in fr { ctx.line(RD.ink2, f.a, f.b, 1.4) }
    for f in fr where look.glow.contains("o" + f.id) {
        ctx.line(RD.green.opacity(0.3), f.a, f.b, 16, round: true)
        ctx.line(RD.green, f.a, f.b, 4, round: true)
    }
    reDrawBodies(ctx, g, m, look)
    if let sw = look.selWall, let f = all.first(where: { $0.id == sw && $0.inner }) {
        ctx.line(RD.blue.opacity(0.35), f.a, f.b, 12, round: true)
        ctx.line(RD.blue, f.a, f.b, 3.5, round: true)
    }
    if look.arm { for f in all { ctx.line(RD.blue, f.a, f.b, 3.5, dash: [2, 6], round: true) } }
    if let h = look.hl, let f = all.first(where: { $0.id == h }) {
        ctx.line(RD.green.opacity(0.3), f.a, f.b, 20, round: true)
        ctx.line(RD.green, f.a, f.b, 5, round: true)
    }
    for it in items { if let f = all.first(where: { $0.id == it.wall }) { reDrawPlanItem(ctx, it, f, m.k, look, ghost: false) } }
    if let gh = look.ghost, let f = all.first(where: { $0.id == gh.wall }) {
        var c = ctx
        c.opacity = 0.62
        reDrawPlanItem(c, gh, f, m.k, look, ghost: true)
        if look.mag == "mid" {
            let cm = mid(f.a, f.b)
            ctx.line(RD.green, cm - f.n * (f.tp + 6), cm + f.n * 40, 1.8, dash: [4, 3])
        }
    }
    if look.chain { for f in fr { reChain(ctx, f, items, g.len(f.id), m.k, lenTxt) } }
    if let a = look.areaTxt {
        var c = CGPoint.zero
        for p in poly { c = c + p / CGFloat(poly.count) }
        ctx.text(a, c, .ui, 13, 800, RD.ink2)
    }
    for (i, f) in fr.enumerated() {
        let off = f.tp + 12
        let c = mid(f.a, f.b) - f.n * off
        let t = look.showLen ? f.id + " · " + lenTxt(g.walls[i].len) : f.id
        ctx.pill(t, c, cur: f.id == look.selWall || f.id == look.hl, bounds: size)
    }
    // an inner face's letter in front of it, when its piece or the face is in use
    for f in all where f.inner {
        let pid = iwPieceOf(f.id)
        let on = f.id == look.selWall || f.id == look.hl
        guard on || look.arm || (pid != nil && pid == look.selPiece) || look.ghost?.wall == f.id else { continue }
        ctx.pill(f.label, mid(f.a, f.b) + f.n * 13, cur: on, bounds: size)
    }
    for gp in look.gaps {
        let a = m.p(gp.a), b = m.p(gp.b)
        let L = (b - a).len
        guard gp.gap > 1, L >= 6 else { continue }
        let u = (b - a) / L, q = CGPoint(x: -u.y * 5, y: u.x * 5)
        ctx.line(RD.blue, a, b, 1.3, dash: [4, 3])
        ctx.line(RD.blue, a + q, a - q, 1.3); ctx.line(RD.blue, b + q, b - q, 1.3)
    }
}

/// The inner walls' bodies on the plan (mockup innerPlan): a full wall dark, a half wall lighter, an arch's passage as
/// two thin lines; the selected piece blue (a new one dashed), one with a problem red, one a dragged piece touches green.
func reDrawBodies(_ ctx: GraphicsContext, _ g: ReRoomGeo, _ m: ReMap, _ look: RePlanLook) {
    for b in g.bodies {
        let polys = b.R.map { $0.map { m.p($0) } }
        let on = b.pid == look.selPiece
        if look.glow.contains("p" + b.pid) { for q in polys { ctx.poly(q, fill: RD.green.opacity(0.35), stroke: RD.green, 5) } }
        for q in polys { ctx.poly(q, fill: b.k == "half" ? RD.wallc.opacity(0.45) : RD.wallc.opacity(0.88), stroke: RD.wallc, 1) }
        if let gp = b.gap, gp.count == 2 {
            let t = CGFloat(b.th) / 2 * m.k, n = CGPoint(x: CGFloat(b.n.x), y: CGFloat(b.n.y))
            let a0 = m.p(gp[0]), a1 = m.p(gp[1])
            ctx.line(RD.wallc, a0 + n * t, a1 + n * t, 1.2, dash: [3, 3])
            ctx.line(RD.wallc, a0 - n * t, a1 - n * t, 1.2, dash: [3, 3])
        }
        if on {
            for q in polys {
                if b.pid == look.newPiece { ctx.poly(q, stroke: RD.blue, 2.2, dash: [5, 4]) } else { ctx.poly(q, stroke: RD.blue, 2.4) }
            }
        } else if look.issues.contains(b.pid) {
            for q in polys { ctx.poly(q, fill: RD.issue.opacity(0.25), stroke: RD.issue, 2) }
        }
    }
}

/// The piece under p on the plan (inside a body, or within 9 points of one).
func reHitBody(_ g: ReRoomGeo, _ m: ReMap, _ p: CGPoint) -> String? {
    var best: (d: CGFloat, id: String)? = nil
    for b in g.bodies {
        var d = CGFloat.infinity
        for R in b.R {
            let q = R.map { m.p($0) }
            if rePip(p, q) { d = 0; break }
            for i in q.indices { d = min(d, reSegD(p, q[i], q[(i + 1) % q.count]).d) }
        }
        if d < 9 && (best == nil || d < best!.d) { best = (d, b.pid) }
    }
    return best?.id
}

/// One item on the plan (mockup itemPlan).
func reDrawPlanItem(_ ctx: GraphicsContext, _ it: ReItem, _ f: ReFrame, _ k: CGFloat, _ look: RePlanLook, ghost: Bool) {
    let sel = !ghost && look.selItem == it.id
    let bad = !ghost && look.issues.contains(it.id)
    let tp = f.tp
    func P(_ t: Int, _ off: CGFloat) -> CGPoint { f.at(CGFloat(t), off, k) }
    if it.isOpening {
        let p0 = P(it.dist, 0), p1 = P(it.dist + it.w, 0), q0 = P(it.dist, -tp), q1 = P(it.dist + it.w, -tp)
        if it.isBalcony {
            // the door part is at the wall's start corner (Opening.dw), the window after it
            let dA = it.dist
            let wA = it.dist + it.dw, wB = it.dist + it.w
            let wp0 = P(wA, 0), wp1 = P(wB, 0), wq0 = P(wA, -tp), wq1 = P(wB, -tp)
            ctx.poly([wp0, wp1, wq1, wq0], fill: RD.glass)
            ctx.line(RD.glassLine, wp0, wp1, 1.4); ctx.line(RD.glassLine, wq0, wq1, 1.4); ctx.line(RD.glassLine, mid(wp0, wq0), mid(wp1, wq1), 1.4)
            let dp0 = P(dA, 0), dp1 = P(dA + it.dw, 0), dq0 = P(dA, -tp), dq1 = P(dA + it.dw, -tp)
            ctx.poly([dp0, dp1, dq1, dq0], fill: RD.paper)
            ctx.line(RD.ink2, dp0, dq0, 1.6); ctx.line(RD.ink2, dp1, dq1, 1.6)
            reDoorLeaf(ctx, sw: it.kind == "door" && !it.sw.isEmpty ? it.sw : "inL", style: "single", f, dp0, dp1, dq0, dq1, CGFloat(it.dw) * k)
        } else if it.kind == "window" {
            let nm = it.style == "triple" || it.style == "pano" ? 3 : it.style == "single" ? 1 : 2
            ctx.poly([p0, p1, q1, q0], fill: it.style == "pano" ? Color(argb: 0xA638BDF8) : RD.glass)
            ctx.line(RD.glassLine, p0, p1, 1.4); ctx.line(RD.glassLine, q0, q1, 1.4); ctx.line(RD.glassLine, mid(p0, q0), mid(p1, q1), 1.4)
            if nm > 1 { for j in 1..<nm { let t = CGFloat(j) / CGFloat(nm); ctx.line(RD.glassLine, p0 + (p1 - p0) * t, q0 + (q1 - q0) * t, 1.4) } }
        } else {
            ctx.poly([p0, p1, q1, q0], fill: RD.paper)
            ctx.line(RD.ink2, p0, q0, 1.6); ctx.line(RD.ink2, p1, q1, 1.6)
            reDoorLeaf(ctx, sw: it.sw.isEmpty ? "inL" : it.sw, style: it.style, f, p0, p1, q0, q1, CGFloat(it.w) * k)
        }
        let bx = [P(it.dist, 5), P(it.dist + it.w, 5), P(it.dist + it.w, -tp - 5), P(it.dist, -tp - 5)]
        if sel { ctx.poly(bx, stroke: RD.blue, 2.6) } else if bad { ctx.poly(bx, stroke: RD.issue, 2.2, dash: [4, 3]) }
        return
    }
    let w0 = P(it.dist, 0), cc = P(it.dist, look.small ? 13 : 15), rr: CGFloat = look.small ? 8.5 : 10
    ctx.line(RD.ink3, w0, cc, 1.2)
    ctx.disc(RD.kind(it.kind), rr, cc)
    ctx.ring(RD.paper, rr, cc, 2)
    ctx.glyph(reKind(it.kind).icon, cc, rr * 1.3)
    if sel { ctx.ring(RD.blue, rr + 4, cc, 2.6) } else if bad { ctx.ring(RD.issue, rr + 3.5, cc, 2.2, dash: [4, 3]) }
}

/// A door's leaf by style (mockup doorLeaf): sw where it is hung and which way it opens.
func reDoorLeaf(_ ctx: GraphicsContext, sw: String, style: String, _ f: ReFrame, _ p0: CGPoint, _ p1: CGPoint, _ q0: CGPoint, _ q1: CGPoint, _ wpx: CGFloat) {
    let nn = f.n
    let inw = sw.hasPrefix("in"), hl = sw.hasSuffix("L")
    let Lp = f.fl ? p1 : p0, Rp = f.fl ? p0 : p1, Lq = f.fl ? q1 : q0, Rq = f.fl ? q0 : q1
    let H = inw ? (hl ? Lp : Rp) : (hl ? Lq : Rq)
    let J = inw ? (hl ? Rp : Lp) : (hl ? Rq : Lq)
    let d = inw ? nn : -nn
    switch style {
    case "arch":
        ctx.line(RD.ink3, p0, p1, 1.4, dash: [5, 4]); ctx.line(RD.ink3, q0, q1, 1.4, dash: [5, 4])
    case "slide":
        let o1 = nn * 4, o2 = nn * 8
        ctx.line(RD.ink, p0 + o1, p0 + (p1 - p0) * 0.6 + o1, 2, round: true)
        ctx.line(RD.ink, p0 + (p1 - p0) * 0.4 + o2, p1 + o2, 2, round: true)
    case "double":
        let hw = wpx / 2, M2 = mid(H, J)
        let E1 = H + d * hw, E2 = J + d * hw
        ctx.line(RD.ink, H, E1, 2, round: true); ctx.swingArc(H, M2, E1)
        ctx.line(RD.ink, J, E2, 2, round: true); ctx.swingArc(J, M2, E2)
    case "fold":
        var pts: [CGPoint] = []
        for j in 0...4 { let q = p0 + (p1 - p0) * (CGFloat(j) / 4); pts.append(j % 2 == 1 ? q + d * min(9, wpx / 5) : q) }
        ctx.stroke(polyPath(pts, close: false), with: .color(RD.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    default:
        let E = H + d * wpx
        ctx.line(style == "glass" ? RD.glassLine : RD.ink, H, E, 2, round: true)
        ctx.swingArc(H, J, E)
    }
}

/// The chain of sizes along wall f: from corner to each door, window and point and on (mockup chainDim).
private func reChain(_ ctx: GraphicsContext, _ f: ReFrame, _ items: [ReItem], _ L: Int, _ k: CGFloat, _ lenTxt: (Int) -> String) {
    var pts = [0, L]
    for it in items where it.wall == f.id { pts.append(it.dist); if it.isOpening { pts.append(it.dist + it.w) } }
    let sorted = pts.sorted()
    var cuts: [Int] = []
    for v in sorted where cuts.last.map({ v - $0 > 1 }) ?? true { cuts.append(v) }
    guard cuts.count >= 3 else { return }
    let o: CGFloat = 30
    ctx.line(RD.ink3, f.at(0, o, k), f.at(CGFloat(L), o, k), 1)
    for t in cuts { ctx.line(RD.ink3, f.at(CGFloat(t), o - 4, k), f.at(CGFloat(t), o + 4, k), 1) }
    for j in 1..<cuts.count {
        let d = cuts[j] - cuts[j - 1]
        if CGFloat(d) * k < 26 { continue }
        ctx.text(lenTxt(d), f.at(CGFloat(cuts[j] + cuts[j - 1]) / 2, o + 9, k), .num, 9.5, 700, RD.ink2)
    }
}

/* ---------------- one wall from inside ---------------- */

/// Wall wi seen from inside, fitted into box: x along it (its start on the right when fl), z up from the floor.
struct ReFront {
    let id: String
    let L: CGFloat
    let rh: CGFloat
    let fl: Bool
    let s: CGFloat
    let x0: CGFloat
    let y0: CGFloat
    let cam: ReCam
    var k: CGFloat { s * cam.z }
    func X(_ t: CGFloat) -> CGFloat { let tt = fl ? L - t : t; return (x0 + tt * s) * cam.z + cam.dx }
    func Z(_ h: CGFloat) -> CGFloat { (y0 + (rh - h) * s) * cam.z + cam.dy }
    func T(_ x: CGFloat) -> CGFloat { let tt = ((x - cam.dx) / cam.z - x0) / s; return fl ? L - tt : tt }
    func Hh(_ y: CGFloat) -> CGFloat { rh - ((y - cam.dy) / cam.z - y0) / s }
    static func of(_ wall: ReWall, fl: Bool, rh: Int, box: CGRect, small: Bool, cam: ReCam = ReCam()) -> ReFront {
        let L = CGFloat(max(wall.len, 1)), h = CGFloat(rh)
        let pl: CGFloat = small ? 12 : 22, pt: CGFloat = small ? 16 : 30, pb: CGFloat = small ? 26 : 44
        let s = max(1e-5, min((box.width - 2 * pl) / L, (box.height - pt - pb) / h))
        return ReFront(id: wall.id, L: L, rh: h, fl: fl, s: s, x0: box.minX + (box.width - L * s) / 2, y0: box.minY + pt + ((box.height - pt - pb) - h * s) / 2, cam: cam)
    }
}

/// An item's box on the front view and its edge handles (l, r, t and b for a window with a sill).
struct ReFrontHit {
    let id: String
    let op: Bool
    var r = CGRect.zero
    var c = CGPoint.zero
    var handles: [(String, CGPoint)] = []
}

func reFrontHits(_ fv: ReFront, _ items: [ReItem], sel: String?) -> [ReFrontHit] {
    items.filter { $0.wall == fv.id }.map { it in
        if it.isOpening {
            let x1 = fv.X(CGFloat(it.dist)), x2 = fv.X(CGFloat(it.dist + it.w))
            let xl = min(x1, x2), xr = max(x1, x2)
            let yt = fv.Z(CGFloat(it.top)), yb = fv.Z(CGFloat(it.z0))
            var h = ReFrontHit(id: it.id, op: true, r: CGRect(x: xl, y: yt, width: xr - xl, height: yb - yt))
            if sel == it.id {
                let ym = (yt + yb) / 2, xc = (xl + xr) / 2
                h.handles = [("l", CGPoint(x: xl, y: ym)), ("r", CGPoint(x: xr, y: ym)), ("t", CGPoint(x: xc, y: yt))]
                if it.kind == "window" && it.style != "pano" && !it.isBalcony { h.handles.append(("b", CGPoint(x: xc, y: yb))) }
            }
            return h
        }
        return ReFrontHit(id: it.id, op: false, c: CGPoint(x: fv.X(CGFloat(it.dist)), y: fv.Z(CGFloat(it.ph))))
    }
}

/// Draws the wall from inside with its items (mockup frontSvg): the neighbours' letters at its corners, a caption under it.
func reDrawFront(_ ctx: GraphicsContext, _ size: CGSize, _ fv: ReFront, _ items: [ReItem], sel: String?, wallSel: Bool, ghost: ReItem?,
                 left: String, right: String, caption: String?, issues: Set<String>, small: Bool) {
    let xa = min(fv.X(0), fv.X(fv.L)), xb = max(fv.X(0), fv.X(fv.L)), yt = fv.Z(fv.rh), yf = fv.Z(0)
    ctx.box(CGRect(x: xa, y: yt, width: xb - xa, height: yf - yt), fill: RD.elev, stroke: wallSel ? RD.blue : RD.ink3, wallSel ? 2.6 : 1.2)
    ctx.line(RD.ink2, CGPoint(x: xa - 10, y: yf), CGPoint(x: xb + 10, y: yf), 2)
    ctx.text("‹ " + left, CGPoint(x: xa + 12, y: yt - 8), .ui, 10.5, 700, RD.ink3)
    ctx.text(right + " ›", CGPoint(x: xb - 12, y: yt - 8), .ui, 10.5, 700, RD.ink3)
    if let caption { ctx.text(caption, CGPoint(x: (xa + xb) / 2, y: yf + 30), .ui, 11, 700, RD.ink2) }
    var all = items.filter { $0.wall == fv.id }.map { ($0, false) }
    if let g = ghost, g.wall == fv.id { all.append((g, true)) }
    for (it, gh) in all {
        var c = ctx
        if gh { c.opacity = 0.62 }
        let isSel = !gh && sel == it.id, bad = !gh && issues.contains(it.id)
        if it.isOpening {
            let x1 = fv.X(CGFloat(it.dist)), x2 = fv.X(CGFloat(it.dist + it.w))
            let xl = min(x1, x2)
            let art = reOpArt(c, it, xl, fv.k, doorRight: fv.fl) { fv.Z($0) }
            let rr = CGRect(x: art.xl, y: art.yt, width: art.xr - art.xl, height: art.yb - art.yt)
            if bad && !isSel { c.box(rr.insetBy(dx: -3, dy: -3), stroke: RD.issue, 2.2, dash: [4, 3]) }
            if isSel {
                c.box(rr.insetBy(dx: -2, dy: -2), stroke: RD.blue, 2.6)
                for h in reFrontHits(fv, [it], sel: it.id).first?.handles ?? [] {
                    let vert = h.0 == "l" || h.0 == "r"
                    let w: CGFloat = vert ? (small ? 8 : 10) : (small ? 22 : 28), hh: CGFloat = vert ? (small ? 22 : 28) : (small ? 8 : 10)
                    c.box(CGRect(x: h.1.x - w / 2, y: h.1.y - hh / 2, width: w, height: hh), fill: .white, stroke: RD.blue, 2, rx: 3)
                }
            }
        } else {
            let x = fv.X(CGFloat(it.dist)), y = fv.Z(CGFloat(it.ph)), rr: CGFloat = small ? 7 : 10
            c.line(RD.ink3, CGPoint(x: x, y: y + rr), CGPoint(x: x, y: yf), 1, dash: [4, 3])
            c.disc(RD.kind(it.kind), rr, CGPoint(x: x, y: y))
            c.ring(RD.paper, rr, CGPoint(x: x, y: y), 2)
            c.glyph(reKind(it.kind).icon, CGPoint(x: x, y: y), rr * 1.3)
            if isSel { c.ring(RD.blue, rr + 4, CGPoint(x: x, y: y), 2.6) } else if bad { c.ring(RD.issue, rr + 3.5, CGPoint(x: x, y: y), 2.2, dash: [4, 3]) }
        }
    }
}

/* ---------------- the styles' front drawings (mockup opArt, ptArt) ---------------- */

/// Where a drawn door or window is: its sides and top and bottom, and a balcony's door / window split.
struct ReArt { var xl: CGFloat; var xr: CGFloat; var yt: CGFloat; var yb: CGFloat; var dx: CGFloat? = nil; var wyt: CGFloat? = nil; var wyb: CGFloat? = nil }

/// A door or window of item it drawn from its left x xl at k points a mm, heights through Z.
@discardableResult
func reOpArt(_ ctx: GraphicsContext, _ it: ReItem, _ xl: CGFloat, _ k: CGFloat, doorRight: Bool = false, _ Z: @escaping (CGFloat) -> CGFloat) -> ReArt {
    let xr = xl + CGFloat(it.w) * k
    let hs0 = String((it.sw.isEmpty ? "L" : it.sw).suffix(1))
    let yb0 = Z(0)
    func knob(_ x: CGFloat, _ y: CGFloat) { ctx.disc(RD.ink2, min(3.2, max(1.4, k * 30)), CGPoint(x: x, y: y)) }
    func swg(_ x0: CGFloat, _ x1: CGFloat, _ yt: CGFloat, _ yb: CGFloat, _ hs: String) {
        var p = Path()
        if hs == "T" { p.move(to: CGPoint(x: x0, y: yb)); p.addLine(to: CGPoint(x: (x0 + x1) / 2, y: yt)); p.addLine(to: CGPoint(x: x1, y: yb)) }
        else {
            let hx = hs == "L" ? x0 : x1, fx = hs == "L" ? x1 : x0
            p.move(to: CGPoint(x: fx, y: yt)); p.addLine(to: CGPoint(x: hx, y: (yt + yb) / 2)); p.addLine(to: CGPoint(x: fx, y: yb))
        }
        ctx.stroke(p, with: .color(RD.ink3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }
    func door(_ x0: CGFloat, _ x1: CGFloat, _ hh: CGFloat, _ dt: String, _ hs: String) {
        let yt = Z(hh), yb = yb0, wd = x1 - x0, hg = yb - yt, ky = Z(min(1000, hh * 0.47))
        if dt == "arch" {
            let rr = min(wd / 2, hg * 0.3)
            var p = Path()
            p.move(to: CGPoint(x: x0, y: yb)); p.addLine(to: CGPoint(x: x0, y: yt + rr))
            p.addQuadCurve(to: CGPoint(x: x1, y: yt + rr), control: CGPoint(x: (x0 + x1) / 2, y: yt - rr * 0.95))
            p.addLine(to: CGPoint(x: x1, y: yb))
            ctx.fill(p, with: .color(RD.paper)); ctx.stroke(p, with: .color(RD.ink2), lineWidth: 1.6)
            return
        }
        if dt == "slide" {
            let pw = wd * 0.56
            ctx.line(RD.ink2, CGPoint(x: x0 - 2, y: yt - 2), CGPoint(x: x1 + 2, y: yt - 2), 2.6, round: true)
            ctx.box(CGRect(x: x0, y: yt, width: pw, height: hg), fill: RD.doorf, stroke: RD.ink2, 1.3)
            ctx.box(CGRect(x: x1 - pw, y: yt, width: pw, height: hg), fill: RD.doorf, stroke: RD.ink2, 1.3)
            ctx.box(CGRect(x: x1 - pw, y: yt, width: pw, height: hg), fill: Color.black.opacity(0.07))
            knob(x0 + pw * 0.14, ky); knob(x1 - pw * 0.14, ky)
            return
        }
        ctx.box(CGRect(x: x0, y: yt, width: wd, height: hg), fill: RD.doorf, stroke: RD.ink2, 1.3)
        if dt == "double" {
            let xm = x0 + wd / 2
            ctx.line(RD.ink2, CGPoint(x: xm, y: yt), CGPoint(x: xm, y: yb), 1.2)
            swg(x0, xm, yt, yb, "L"); swg(xm, x1, yt, yb, "R"); knob(xm - wd * 0.05, ky); knob(xm + wd * 0.05, ky)
            return
        }
        if dt == "fold" {
            for i in 1..<4 { let x = x0 + wd * CGFloat(i) / 4; ctx.line(RD.ink2, CGPoint(x: x, y: yt), CGPoint(x: x, y: yb), 1.2) }
            var z = Path()
            for j in 0...8 {
                let q = CGPoint(x: x0 + wd * CGFloat(j) / 8, y: yt + hg * (j % 2 == 1 ? 0.09 : 0.03))
                if j == 0 { z.move(to: q) } else { z.addLine(to: q) }
            }
            ctx.stroke(z, with: .color(RD.ink2), lineWidth: 1.1)
            knob(x1 - wd * 0.07, ky)
            return
        }
        if dt == "glass" { ctx.box(CGRect(x: x0 + wd * 0.17, y: yt + hg * 0.07, width: wd * 0.66, height: hg * 0.8), fill: RD.glass, stroke: RD.glassLine, 1, rx: 2) }
        swg(x0, x1, yt, yb, hs)
        knob(hs == "L" ? x1 - wd * 0.1 : x0 + wd * 0.1, ky)
    }
    func win(_ x0: CGFloat, _ x1: CGFloat, _ z0: CGFloat, _ hh: CGFloat, _ wt: String, _ hs: String) {
        let yt = Z(z0 + hh), yb = Z(z0), wd = x1 - x0, hg = yb - yt
        let n = wt == "single" ? 1 : (wt == "triple" || wt == "pano") ? 3 : 2
        ctx.box(CGRect(x: x0, y: yt, width: wd, height: hg), fill: RD.glass, stroke: RD.glassLine, 1.6)
        if n > 1 { for i in 1..<n { let x = x0 + wd * CGFloat(i) / CGFloat(n); ctx.line(RD.glassLine, CGPoint(x: x, y: yt), CGPoint(x: x, y: yb), 1.2) } }
        if wt == "fort" {
            let xm = x0 + wd / 2, yv = yt + hg * 0.3
            ctx.line(RD.glassLine, CGPoint(x: xm, y: yv), CGPoint(x: x1, y: yv), 1.2)
            swg(xm, x1, yt, yv, "T"); swg(x0, xm, yt, yb, "L")
        } else if wt == "triple" { swg(x0, x0 + wd / 3, yt, yb, "L"); swg(x1 - wd / 3, x1, yt, yb, "R") }
        else if wt != "pano" { swg(x0, n == 1 ? x1 : x0 + wd / 2, yt, yb, n == 1 ? hs : "L") }
        if z0 > 0 { ctx.line(RD.ink2, CGPoint(x: x0 - 3, y: yb + 1), CGPoint(x: x1 + 3, y: yb + 1), 2.6, round: true) }
    }
    if it.isBalcony {
        // the door part is at the wall's start corner: on the right when the wall is seen the other way
        let dx = doorRight ? xr - CGFloat(it.dw) * k : xl + CGFloat(it.dw) * k
        if doorRight {
            door(dx, xr, CGFloat(it.h), "single", "R")
            win(xl, dx, CGFloat(it.h - it.wh), CGFloat(it.wh), "double", "L")
        } else {
            door(xl, dx, CGFloat(it.h), "single", "L")
            win(dx, xr, CGFloat(it.h - it.wh), CGFloat(it.wh), "double", "L")
        }
        return ReArt(xl: xl, xr: xr, yt: Z(CGFloat(it.h)), yb: yb0, dx: dx, wyt: Z(CGFloat(it.h)), wyb: Z(CGFloat(it.h - it.wh)))
    }
    if it.kind == "door" {
        door(xl, xr, CGFloat(it.h), it.style, hs0)
        return ReArt(xl: xl, xr: xr, yt: Z(CGFloat(it.h)), yb: yb0)
    }
    let z0 = CGFloat(it.style == "pano" ? 0 : it.sill)
    win(xl, xr, z0, CGFloat(it.h), it.style, hs0)
    return ReArt(xl: xl, xr: xr, yt: Z(z0 + CGFloat(it.h)), yb: Z(z0))
}

/// A point of kind / style drawn centred on c at u points a unit (mockup ptArt); pw a radiator's or AC's width in
/// points (nil: the style's look), pwmm its width in mm, sh: points a mm for the drawn heights. Returns its size.
@discardableResult
func rePtArt(_ ctx: GraphicsContext, _ k: String, _ t: String, _ c: CGPoint, _ u: CGFloat, pw: CGFloat? = nil, pwmm: Int = 640, sh: CGFloat? = nil) -> CGSize {
    let cx = c.x, cy = c.y
    let ppF = Color(argb: 0xFFF8FAFC), ppS = Color(argb: 0xFF64748B), dark = Color(argb: 0xFF334155), grey = Color(argb: 0xFF94A3B8)
    let pm = Color(argb: 0xFFCBD5E1), gas = Color(argb: 0xFFF59E0B), gasS = Color(argb: 0xFFB45309), red = Color(argb: 0xFFDC2626)
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ f: Color?, _ s: Color?, _ lw: CGFloat = 1.2, _ rx: CGFloat = 0) {
        ctx.box(CGRect(x: x, y: y, width: max(0, w), height: max(0, h)), fill: f, stroke: s, lw, rx: rx)
    }
    func C(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ f: Color?, _ s: Color?, _ lw: CGFloat = 1.2) {
        if let f { ctx.disc(f, max(0, r), CGPoint(x: x, y: y)) }
        if let s { ctx.ring(s, max(0, r), CGPoint(x: x, y: y), lw) }
    }
    func L(_ a: CGPoint, _ b: CGPoint, _ col: Color, _ lw: CGFloat = 1) { ctx.line(col, a, b, lw, round: true) }
    let kc = RD.kind(k)
    var w: CGFloat = 0, h: CGFloat = 0
    switch k {
    case "socket":
        let n = t == "two" || t == "usb" ? 2 : t == "three" ? 3 : 1
        let P = (t == "power" ? 30 : 24) * u
        w = CGFloat(n) * P; h = P
        let x0 = cx - w / 2, y0 = cy - h / 2
        R(x0, y0, w, h, ppF, ppS, 1.2, 4 * u)
        for i in 0..<n {
            let px = x0 + P * CGFloat(i) + P / 2
            if i > 0 { L(CGPoint(x: x0 + P * CGFloat(i), y: y0 + 3 * u), CGPoint(x: x0 + P * CGFloat(i), y: y0 + h - 3 * u), grey) }
            if t == "usb" && i == 1 { R(px - 4 * u, cy - 6 * u, 8 * u, 3.4 * u, dark, nil, 1, 0.8 * u); R(px - 4 * u, cy + 2.6 * u, 8 * u, 3.4 * u, dark, nil, 1, 0.8 * u); continue }
            if t == "power" {
                C(px, cy - 2.5 * u, 9.5 * u, nil, grey); C(px - 3.8 * u, cy - u, 1.7 * u, dark, nil); C(px + 3.8 * u, cy - u, 1.7 * u, dark, nil); C(px, cy - 6.5 * u, 1.7 * u, dark, nil)
                ctx.text("32A", CGPoint(x: px, y: cy + 9.5 * u), .num, max(4, 4.6 * u), 800, dark)
            } else { C(px, cy, 8.5 * u, nil, grey); C(px - 3.3 * u, cy, 1.5 * u, dark, nil); C(px + 3.3 * u, cy, 1.5 * u, dark, nil) }
        }
    case "switch":
        let n2 = t == "k2" ? 2 : t == "k3" ? 3 : 1
        let iw = 18 * u, ix = cx - iw / 2, iy = cy - iw / 2, kw = iw / CGFloat(n2)
        w = 26 * u; h = 26 * u
        R(cx - w / 2, cy - h / 2, w, h, ppF, ppS, 1.2, 4 * u)
        for i in 0..<n2 {
            R(ix + CGFloat(i) * kw + 0.6 * u, iy, kw - 1.2 * u, iw, Color(argb: 0xFFEEF2F7), grey, 1, 1.5 * u)
            if t != "pass" { L(CGPoint(x: ix + CGFloat(i) * kw + kw / 2, y: iy + 3 * u), CGPoint(x: ix + CGFloat(i) * kw + kw / 2, y: iy + 5.5 * u), ppS, 1.2) }
        }
        if t == "pass" {
            ctx.poly([CGPoint(x: cx, y: cy - 7 * u), CGPoint(x: cx - 3 * u, y: cy - 3 * u), CGPoint(x: cx + 3 * u, y: cy - 3 * u)], fill: ppS)
            ctx.poly([CGPoint(x: cx, y: cy + 7 * u), CGPoint(x: cx - 3 * u, y: cy + 3 * u), CGPoint(x: cx + 3 * u, y: cy + 3 * u)], fill: ppS)
        }
    case "rad":
        w = pw ?? (t == "towel" ? 38 : t == "steel" ? 64 : 52) * u
        h = sh.map { (t == "towel" ? 800 : 500) * $0 } ?? (t == "towel" ? 56 : 36) * u
        let x0 = cx - w / 2, y0 = cy - h / 2
        if t == "towel" {
            let bt: CGFloat = 3
            R(x0, y0, bt, h, pm, ppS, 1, 1.5); R(x0 + w - bt, y0, bt, h, pm, ppS, 1, 1.5)
            for i in 1...5 { R(x0, y0 + h * CGFloat(i) / 6 - bt / 2, w, bt, pm, ppS, 1, 1.5) }
        } else if t == "steel" {
            R(x0, y0, w, h, Color(argb: 0xFFF1F5F9), ppS, 1.1, 2)
            for i in 1..<6 { L(CGPoint(x: x0 + 3, y: y0 + h * CGFloat(i) / 6), CGPoint(x: x0 + w - 3, y: y0 + h * CGFloat(i) / 6), grey) }
        } else {
            let ns = max(4, min(14, Int((Double(pwmm) / (t == "cast" ? 93 : 80)).rounded())))
            let sw2 = w / CGFloat(ns)
            for i in 0..<ns {
                R(x0 + CGFloat(i) * sw2 + 0.5, y0, sw2 - 1, h, t == "cast" ? pm : Color(argb: 0xFFF1F5F9), t == "cast" ? Color(argb: 0xFF475569) : ppS, 1.1, t == "cast" ? min(sw2 / 2.2, h / 4) : 1.5)
            }
            L(CGPoint(x: x0, y: y0 + h * 0.16), CGPoint(x: x0 + w, y: y0 + h * 0.16), grey)
            L(CGPoint(x: x0, y: y0 + h * 0.84), CGPoint(x: x0 + w, y: y0 + h * 0.84), grey)
        }
    case "cold", "hot":
        if t == "mix" {
            let d2 = 15 * u
            w = d2 * 2 + 12 * u; h = 14 * u
            R(cx - d2, cy - 1.6 * u, 2 * d2, 3.2 * u, pm, ppS, 1, 1.6 * u)
            C(cx - d2, cy, 5.5 * u, RD.kind("hot"), .white, 1.4); C(cx + d2, cy, 5.5 * u, RD.kind("cold"), .white, 1.4)
            C(cx - d2, cy, 2 * u, dark, nil); C(cx + d2, cy, 2 * u, dark, nil)
        } else if t == "wm" {
            w = 26 * u; h = 26 * u
            R(cx - 2.6 * u, cy + 3 * u, 5.2 * u, 9 * u, pm, ppS, 1, u)
            C(cx, cy, 6 * u, kc, .white, 1.4); R(cx, cy - 2 * u, 13 * u, 4 * u, red, nil, 1, 2 * u); C(cx, cy, 2 * u, dark, nil)
        } else {
            w = 18 * u; h = 18 * u
            var hx: [CGPoint] = []
            for i in 0..<6 { let an = CGFloat.pi / 3 * CGFloat(i) + CGFloat.pi / 6; hx.append(CGPoint(x: cx + cos(an) * 8 * u, y: cy + sin(an) * 8 * u)) }
            ctx.poly(hx, fill: grey, stroke: Color(argb: 0xFF475569), 1)
            C(cx, cy, 5 * u, kc, .white, 1.4); C(cx, cy, 2 * u, dark, nil)
        }
    case "sewer":
        let rs = (t == "d110" ? 14 : 7) * u
        w = 2 * rs + 5 * u; h = w
        C(cx, cy, rs + 2.5 * u, ppF, ppS); C(cx, cy, rs, kc, .white, 1.4); C(cx, cy, rs * 0.55, dark, nil)
    case "gas":
        let th = (t == "g25" ? 9 : t == "g20" ? 7 : 5) * u
        w = 56 * u; h = th + 14 * u
        R(cx - w / 2, cy - th / 2, w, th, gas, gasS, 1, th / 2)
        R(cx - 4 * u, cy - th / 2 - 2.5 * u, 8 * u, th + 5 * u, grey, Color(argb: 0xFF475569), 1, 1.5 * u)
        R(cx - 1.5 * u, cy - th / 2 - 11 * u, 3 * u, 9 * u, red, nil, 1, 1.5 * u)
    case "meter":
        let bw = (t == "g4" ? 34 : t == "smart" ? 30 : 26) * u, bh = (t == "g4" ? 38 : t == "smart" ? 36 : 30) * u
        w = bw; h = bh + 8 * u
        let x0 = cx - bw / 2, y0 = cy - bh / 2 + 4 * u
        R(cx - bw / 3 - 1.5 * u, y0 - 8 * u, 3 * u, 9 * u, gas, gasS, 1); R(cx + bw / 3 - 1.5 * u, y0 - 8 * u, 3 * u, 9 * u, gas, gasS, 1)
        R(x0, y0, bw, bh, Color(argb: 0xFFE2E8F0), Color(argb: 0xFF475569), 1.2, 3 * u)
        R(x0 + bw * 0.16, y0 + bh * 0.18, bw * 0.68, bh * 0.24, Color(argb: 0xFF0F172A), nil, 1, 1.5 * u)
        if t == "smart" { R(x0 + bw * 0.3, y0 + bh * 0.62, bw * 0.4, 2.6 * u, dark, nil, 1, u); C(x0 + bw * 0.8, y0 + bh * 0.84, 1.8 * u, Color(argb: 0xFF3B82F6), nil) }
        else { C(cx, y0 + bh * 0.7, 4 * u, nil, grey) }
    case "boiler":
        let bw2 = (t == "dual" ? 34 : 28) * u, bh2 = 42 * u
        w = bw2; h = bh2 + 12 * u
        let x0 = cx - bw2 / 2, y0 = cy - bh2 / 2 + 5 * u
        if t == "open" { R(cx - 5 * u, y0 - 11 * u, 10 * u, 11 * u, pm, ppS, 1) }
        else if t == "turbo" { R(cx - 3.5 * u, y0 - 6 * u, 7 * u, 6 * u, pm, ppS, 1); R(cx - 3.5 * u, y0 - 11 * u, 20 * u, 6 * u, pm, ppS, 1, 3 * u) }
        R(x0, y0, bw2, bh2, ppF, ppS, 1.2, 4 * u)
        if t == "dual" {
            R(x0 + bw2 * 0.2, y0 + bh2 * 0.18, bw2 * 0.6, bh2 * 0.2, Color(argb: 0xFF0F172A), nil, 1, 1.5 * u)
            for i in 0..<4 { R(x0 + bw2 * (0.2 + 0.2 * CGFloat(i)) - 1.5 * u, y0 + bh2, 3 * u, 6 * u, gas, gasS, 1) }
        } else { C(cx, y0 + bh2 * 0.62, 5 * u, Color(argb: 0xFFF97316), nil); R(x0 + bw2 * 0.3, y0 + bh2 * 0.18, bw2 * 0.4, 3 * u, dark, nil, 1, u) }
    case "ac":
        w = pw ?? (t == "b18" ? 72 : t == "b12" ? 62 : t == "b9" ? 58 : 52) * u
        h = sh.map { max(14, 290 * $0) } ?? 20 * u
        let x0 = cx - w / 2, y0 = cy - h / 2
        R(x0, y0, w, h, ppF, ppS, 1.2, h * 0.3)
        L(CGPoint(x: x0 + w * 0.08, y: y0 + h * 0.74), CGPoint(x: x0 + w * 0.92, y: y0 + h * 0.74), grey)
        C(x0 + w * 0.86, y0 + h * 0.34, max(1.4, 1.6 * u), Color(argb: 0xFF3B82F6), nil)
    case "vent":
        if t == "sq" {
            w = 26 * u; h = w
            R(cx - w / 2, cy - h / 2, w, h, ppF, ppS, 1.2, 2 * u)
            for i in 1..<6 { L(CGPoint(x: cx - w / 2 + 4 * u, y: cy - h / 2 + h * CGFloat(i) / 6), CGPoint(x: cx + w / 2 - 4 * u, y: cy - h / 2 + h * CGFloat(i) / 6), grey) }
        } else {
            let rv = (t == "r125" ? 13 : 11) * u
            w = 2 * rv + 4 * u; h = w
            R(cx - w / 2, cy - h / 2, w, h, ppF, ppS, 1.2, 3 * u); C(cx, cy, rv, nil, grey)
            if t == "fan" {
                for i in 0..<3 {
                    let a0 = CGFloat(i) * 2.094, a1 = a0 + 0.9, R2 = rv * 0.85
                    ctx.poly([c, CGPoint(x: cx + cos(a0) * R2, y: cy + sin(a0) * R2), CGPoint(x: cx + cos((a0 + a1) / 2) * R2, y: cy + sin((a0 + a1) / 2) * R2), CGPoint(x: cx + cos(a1) * R2, y: cy + sin(a1) * R2)], fill: pm, stroke: ppS, 1)
                }
                C(cx, cy, 2 * u, dark, nil)
            } else {
                for i in -1...1 {
                    let yy = cy + CGFloat(i) * rv * 0.45, hw = sqrt(rv * rv - pow(CGFloat(i) * rv * 0.45, 2)) * 0.85
                    L(CGPoint(x: cx - hw, y: yy), CGPoint(x: cx + hw, y: yy), grey)
                }
            }
        }
    case "panel":
        let rows = t == "m24" ? 2 : t == "m36" ? 3 : 1, cols = t == "m6" ? 6 : 12
        let mw = 3.2 * u, mh = 8 * u
        w = CGFloat(cols) * mw + 10 * u; h = CGFloat(rows) * (mh + 5 * u) + 9 * u
        let x0 = cx - w / 2, y0 = cy - h / 2
        R(x0, y0, w, h, ppF, ppS, 1.2, 2.5 * u)
        for ri in 0..<rows {
            let yr = y0 + 6 * u + CGFloat(ri) * (mh + 5 * u)
            L(CGPoint(x: x0 + 3 * u, y: yr + mh + 1.6 * u), CGPoint(x: x0 + w - 3 * u, y: yr + mh + 1.6 * u), grey)
            for ci in 0..<cols { R(x0 + 5 * u + CGFloat(ci) * mw + 0.3 * u, yr, mw - 0.6 * u, mh, Color(argb: 0xFFE2E8F0), ppS, 0.8, 0.6 * u) }
        }
    default:
        w = 20 * u; h = w
        C(cx, cy, 10 * u, kc, nil)
    }
    return CGSize(width: w, height: h)
}

/// A style card's picture (mockup styleThumb): a door or window at its standard size on the floor line, or the point.
struct ReStyleThumb: View {
    let kind: String
    let style: String
    let roomH: Int
    var body: some View {
        Canvas { ctx, sz in
            let W = sz.width, H = sz.height
            let v = reStd(kind, style, roomH)
            if kind == "door" || kind == "window" {
                var it = ReItem(id: "t", kind: kind, style: style, wall: "", dist: 0)
                it = reApply(it, style, v, wallL: 1_000_000, centre: 0)
                it.sw = kind == "door" ? "inL" : "L"
                let top = CGFloat(max(it.top, 1)), s = min((W - 28) / CGFloat(max(it.w, 1)), (H - 12) / top)
                let xl = (W - CGFloat(it.w) * s) / 2
                ctx.line(RD.ink2, CGPoint(x: 6, y: H - 6), CGPoint(x: W - 6, y: H - 6), 2)
                reOpArt(ctx, it, xl, s) { H - 6 - $0 * s }
            } else {
                let pwmm = v["pw"] ?? 640
                rePtArt(ctx, kind, style, CGPoint(x: W / 2, y: H / 2), 1.25 * min(1.2, H / 78), pw: v["pw"].map { CGFloat($0) * 0.085 }, pwmm: pwmm, sh: 0.085)
            }
        }
    }
}

/// The size step's big drawing (mockup pkDraw): the wall up to the ceiling, the item at its sizes, the asked edge in
/// thick blue with arrows and its value; bad: the item framed red.
struct ReSizeArt: View {
    let it: ReItem
    let field: String
    let roomH: Int
    let bad: Bool
    let fmt: (Int) -> String
    var body: some View {
        Canvas { ctx, sz in
            let W = sz.width, H = sz.height, rh = CGFloat(roomH), pt: CGFloat = 24, pb: CGFloat = 14
            func wall(_ Z: (CGFloat) -> CGFloat) {
                ctx.box(CGRect(x: 8, y: Z(rh), width: W - 16, height: Z(0) - Z(rh)), fill: RD.elev, stroke: RD.ink3, 1.2)
                ctx.line(RD.ink3, CGPoint(x: 8, y: Z(rh)), CGPoint(x: W - 8, y: Z(rh)), 1.2, dash: [5, 4])
                ctx.text(tr("re.ceil", ["v": fmt(roomH)]), CGPoint(x: 50, y: Z(rh) - 8), .ui, 10.5, 700, RD.ink3)
                ctx.line(RD.ink2, CGPoint(x: 4, y: Z(0)), CGPoint(x: W - 4, y: Z(0)), 2)
            }
            func lab(_ x: CGFloat, _ y: CGFloat, _ t: String) {
                let w = CGFloat(t.count) * 7 + 14
                let cx = max(w / 2 + 2, min(W - w / 2 - 2, x))
                ctx.box(CGRect(x: cx - w / 2, y: y - 10, width: w, height: 20), fill: RD.blue, rx: 10)
                ctx.text(t, CGPoint(x: cx, y: y), .num, 12, 800, .white)
            }
            func dimH(_ a: CGFloat, _ b: CGFloat, _ y: CGFloat, _ t: String) {
                let x1 = min(a, b), x2 = max(a, b)
                ctx.line(RD.blue, CGPoint(x: x1, y: y), CGPoint(x: x2, y: y), 1.6)
                ctx.line(RD.blue, CGPoint(x: x1, y: y - 6), CGPoint(x: x1, y: y + 6), 1.6); ctx.line(RD.blue, CGPoint(x: x2, y: y - 6), CGPoint(x: x2, y: y + 6), 1.6)
                ctx.poly([CGPoint(x: x1, y: y), CGPoint(x: x1 + 6, y: y - 3.5), CGPoint(x: x1 + 6, y: y + 3.5)], fill: RD.blue)
                ctx.poly([CGPoint(x: x2, y: y), CGPoint(x: x2 - 6, y: y - 3.5), CGPoint(x: x2 - 6, y: y + 3.5)], fill: RD.blue)
                lab((x1 + x2) / 2, y, t)
            }
            func dimV(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat, _ t: String) {
                let y1 = min(a, b), y2 = max(a, b)
                ctx.line(RD.blue, CGPoint(x: x, y: y1), CGPoint(x: x, y: y2), 1.6)
                ctx.line(RD.blue, CGPoint(x: x - 6, y: y1), CGPoint(x: x + 6, y: y1), 1.6); ctx.line(RD.blue, CGPoint(x: x - 6, y: y2), CGPoint(x: x + 6, y: y2), 1.6)
                ctx.poly([CGPoint(x: x, y: y1), CGPoint(x: x - 3.5, y: y1 + 6), CGPoint(x: x + 3.5, y: y1 + 6)], fill: RD.blue)
                ctx.poly([CGPoint(x: x, y: y2), CGPoint(x: x - 3.5, y: y2 - 6), CGPoint(x: x + 3.5, y: y2 - 6)], fill: RD.blue)
                lab(x, (y1 + y2) / 2, t)
            }
            func edge(_ a: CGPoint, _ b: CGPoint) { ctx.line(RD.blue, a, b, 4.5, round: true) }
            if it.isOpening {
                let s = min((W - 110) / CGFloat(max(it.w, 600)), (H - pt - pb) / rh)
                let Z: (CGFloat) -> CGFloat = { H - pb - $0 * s }
                let xl = (W - CGFloat(it.w) * s) / 2
                wall(Z)
                let A = reOpArt(ctx, it, xl, s, Z)
                if bad { ctx.box(CGRect(x: A.xl - 4, y: A.yt - 4, width: A.xr - A.xl + 8, height: A.yb - A.yt + 8), stroke: Color(argb: 0xFFDC2626), 2.2, rx: 3, dash: [5, 3]) }
                switch field {
                case "w": edge(CGPoint(x: A.xl, y: A.yt), CGPoint(x: A.xr, y: A.yt)); dimH(A.xl, A.xr, A.yt - 13, fmt(it.w))
                case "h":
                    if it.isBalcony { edge(CGPoint(x: A.xl, y: A.yt), CGPoint(x: A.xl, y: A.yb)); dimV(A.xl - 16, A.yt, A.yb, fmt(it.h)) }
                    else { edge(CGPoint(x: A.xr, y: A.yt), CGPoint(x: A.xr, y: A.yb)); dimV(A.xr + 16, A.yt, A.yb, fmt(it.h)) }
                case "sill": edge(CGPoint(x: A.xl, y: A.yb), CGPoint(x: A.xr, y: A.yb)); dimV(A.xr + 16, A.yb, Z(0), fmt(it.sill))
                case "dw": let dx = A.dx ?? A.xr; edge(CGPoint(x: A.xl, y: A.yt), CGPoint(x: dx, y: A.yt)); dimH(A.xl, dx, A.yt - 13, fmt(it.dw))
                case "ww": let dx = A.dx ?? A.xl, wy = A.wyt ?? A.yt; edge(CGPoint(x: dx, y: wy), CGPoint(x: A.xr, y: wy)); dimH(dx, A.xr, wy - 13, fmt(it.w - it.dw))
                case "wh": let wt = A.wyt ?? A.yt, wb = A.wyb ?? A.yb; edge(CGPoint(x: A.xr, y: wt), CGPoint(x: A.xr, y: wb)); dimV(A.xr + 16, wt, wb, fmt(it.wh))
                default: break
                }
            } else {
                let s2 = min((W - 80) / 2000, (H - pt - pb) / rh)
                let Z2: (CGFloat) -> CGFloat = { H - pb - $0 * s2 }
                let cx = W / 2, cy = Z2(CGFloat(it.ph)), ex = s2 * 1.8
                wall(Z2)
                let pwPt: CGFloat? = it.pw > 0 ? CGFloat(it.pw) * ex : nil
                // the dashed line down to the floor first, then the point over it
                ctx.line(RD.ink3, CGPoint(x: cx, y: cy), CGPoint(x: cx, y: Z2(0)), 1, dash: [4, 3])
                let G = rePtArt(ctx, it.kind, it.style, CGPoint(x: cx, y: cy), 1.5, pw: pwPt, pwmm: max(it.pw, 200), sh: ex)
                if bad { ctx.box(CGRect(x: cx - G.width / 2 - 4, y: cy - G.height / 2 - 4, width: G.width + 8, height: G.height + 8), stroke: Color(argb: 0xFFDC2626), 2.2, rx: 3, dash: [5, 3]) }
                if field == "ph" {
                    ctx.line(RD.blue, CGPoint(x: cx - G.width / 2 - 6, y: cy), CGPoint(x: cx + G.width / 2 + 6, y: cy), 1.6)
                    dimV(cx + G.width / 2 + 22, cy, Z2(0), fmt(it.ph))
                } else if field == "pw" {
                    edge(CGPoint(x: cx - G.width / 2, y: cy - G.height / 2), CGPoint(x: cx + G.width / 2, y: cy - G.height / 2))
                    dimH(cx - G.width / 2, cx + G.width / 2, cy - G.height / 2 - 13, fmt(it.pw))
                }
            }
        }
    }
}

