import SwiftUI

/*
 * The room-shape flow's plan picture (design/room-shapes/mockup.html planSvg, opSvg, shapeThumb, heightSvg; Android
 * ui/rooms/RoomPlan.kt), drawn with a SwiftUI Canvas: the room to scale, the wall being asked glowing with its "?" pill,
 * done walls with their size, derived walls dashed and "avtomat", the openings and the start corner's dot. Everything
 * is laid out in the mockup's own units (the picture is VB units wide) and scaled to the canvas.
 */

/// The picture's width in the mockup's units: strokes, pills and text keep the mockup's sizes.
private let VB: CGFloat = 330

/// How the picture is drawn, as the mockup's planSvg options.
struct PlanLook {
    /// The asked value being typed (its wall glows), and the values done so far.
    var cur: Int? = nil
    var done: Set<Int> = []
    /// What is being typed into cur, already in words ("3 400"); nil shows "?".
    var liveTxt: String? = nil
    /// The summary and the openings step: every wall with its size.
    var final = false
    /// An opening's steps: its wall picked (glowing with letter and size), and the start corner's dot.
    var sel: Int? = nil
    var corner: Int? = nil
    /// "Which wall?": the walls with their letters, a tap picks one.
    var pick = false
    var nolab = false
    var ops: [ShapeOpening] = []
    var preview: ShapeOpening? = nil
    /// The free sketch's diagonal from corner 0 to corner diagK: diagCur being asked, diagTxt its pill.
    var diagK: Int? = nil
    var diagCur = false
    var diagTxt: String? = nil
    /// The bay's sizes: their values in words by asked index.
    var dimTxt: [Int: String] = [:]
    /// A length in the flow's unit and words ("3 400" mm, "3,4" m).
    var fmt: (Double) -> String = { fmtMm($0) }
    var pad: CGFloat = 28
    /// Room kept free on the right (the picture's Ko‘zgu / Burish buttons).
    var rp: CGFloat = 0
}

/// The plan's colours, as the mockup's tokens.
private enum RC {
    static var paper: Color { Theme.shared.dark ? Color(argb: 0xFF161C30) : Color(argb: 0xFFF7F8FC) }
    static var room: Color { G.cobalt.opacity(Theme.shared.dark ? 0.2 : 0.11) }
    static var blue: Color { G.cobalt }
    static var red: Color { Theme.shared.dark ? Color(argb: 0xFFF87171) : Color(argb: 0xFFDC2626) }
    static let win = Color(argb: 0xFF38BDF8)
    static func opC(_ k: OpKind) -> Color { k == .water ? Color(argb: 0xFF0EA5E9) : k == .sewer ? Color(argb: 0xFF78716C) : Color(argb: 0xFFF59E0B) }
    static func opL(_ k: OpKind) -> String { k == .water ? "S" : k == .sewer ? "K" : "G" }
}

/// The paper colour behind the plan pictures.
var rshPaper: Color { RC.paper }

/// The glow of the wall being asked: it breathes, except in the screen tests (an endless animation keeps XCTest
/// waiting for the app to be idle) and with Reduce Motion.
private let RSH_STILL = ProcessInfo.processInfo.arguments.contains("-uiReset")

/// Fits the plan into a w × h box, as the mockup's fitter: the scale (units per mm) and the mapping.
private struct PFit {
    let s: CGFloat, ox: CGFloat, oy: CGFloat
    let spec: ShapeSpec
    init(_ pts: [Pt], _ spec: ShapeSpec, _ w: CGFloat, _ h: CGFloat, _ pad: CGFloat, _ rp: CGFloat) {
        self.spec = spec
        let q = pts.map { shownPoint($0, spec) }
        let mnx = q.map(\.x).min() ?? 0, mxx = q.map(\.x).max() ?? 1
        let mny = q.map(\.y).min() ?? 0, mxy = q.map(\.y).max() ?? 1
        let bw = max(mxx - mnx, 1), bh = max(mxy - mny, 1)
        let sx = (Double(w) - 2 * Double(pad) - Double(rp)) / bw
        let sy = (Double(h) - 2 * Double(pad)) / bh
        let sc = max(0.0001, min(sx, sy))
        s = CGFloat(sc)
        ox = CGFloat((Double(w) - Double(rp) - bw * sc) / 2 - mnx * sc)
        oy = CGFloat((Double(h) - bh * sc) / 2 - mny * sc)
    }
    func m(_ p: Pt) -> CGPoint { let q = shownPoint(p, spec); return CGPoint(x: ox + CGFloat(q.x) * s, y: oy + CGFloat(q.y) * s) }
}

/// Every point the fit must take in: the corners, the bay's guides, an open sketch's end.
private func fitPoints(_ g: ShapeGeo) -> [Pt] {
    var all = g.corners
    for d in g.guides { all.append(d.a); all.append(d.b) }
    return all
}

/// Twice the signed area: which side of a wall is inside.
private func area2(_ v: [CGPoint]) -> CGFloat {
    var a: CGFloat = 0
    for i in v.indices { let p = v[i], q = v[(i + 1) % v.count]; a += p.x * q.y - q.x * p.y }
    return a
}

/// A wall's state in the picture, as the mockup's eState.
private func eState(_ e: ShapeWall, _ i: Int, _ o: PlanLook) -> String {
    if e.bad { return "bad" }
    if o.pick { return "pick" }
    if let sel = o.sel { return i == sel ? "cur" : e.ask == nil ? "auto" : "done" }
    if o.final { return e.ask == nil ? "auto" : "done" }
    guard let a = e.ask else { return "auto" }
    if o.cur == a { return "cur" }
    if o.done.contains(a) { return "done" }
    return "todo"
}

private struct PillAt { let x: CGFloat, y: CGFloat, nx: CGFloat, ny: CGFloat; let t: String; let st: String }

private func pillW(_ t: String, _ st: String) -> CGFloat { max(24, CGFloat(t.count) * (st == "auto" ? 5.6 : 6.6) + 14) }

/// The box a pill takes, as pill clamps it inside the picture.
private func pillRect(_ x0: CGFloat, _ y0: CGFloat, _ t: String, _ st: String, _ W: CGFloat, _ H: CGFloat) -> CGRect {
    let w = pillW(t, st)
    let x = min(max(x0, w / 2 + 2), max(w / 2 + 2, W - w / 2 - 2))
    let y = min(max(y0, 12), max(12, H - 12))
    return CGRect(x: x - w / 2, y: y - 10, width: w, height: 20)
}

private func stroke(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ c: Color, _ w: CGFloat, dash: [CGFloat]? = nil) {
    ctx.stroke(linePath(a, b), with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, dash: dash ?? []))
}

/// A size pill: a rounded box with the words, kept inside the picture (the mockup's pill).
private func drawPill(_ ctx: GraphicsContext, _ r: CGRect, _ t: String, _ st: String) {
    let fill: Color = st == "cur" ? RC.blue : st == "pick" ? RC.room : RC.paper
    let edge: Color = st == "cur" || st == "pick" ? RC.blue : st == "done" ? G.ink2 : st == "bad" ? RC.red : G.ink3
    let path = Path(roundedRect: r, cornerRadius: 10)
    ctx.fill(path, with: .color(fill))
    ctx.stroke(path, with: .color(edge), style: StrokeStyle(lineWidth: 1, dash: st == "auto" ? [3, 2] : []))
    let col: Color = st == "cur" ? .white : st == "todo" || st == "auto" ? G.ink3 : st == "bad" ? RC.red : st == "pick" ? RC.blue : G.ink
    let weight = st == "todo" || st == "auto" ? 700 : 800
    ctx.text(t, CGPoint(x: r.midX, y: r.midY), .ui, st == "auto" ? 10 : 11, weight, col, italic: st == "auto")
}

/// The plan picture of g (as its spec turns and mirrors it). letters names the walls; onPick gets a wall's index when
/// look.pick is on and a wall is tapped (each wall is also a button, for VoiceOver and the screen tests).
struct PlanPic: View {
    let g: ShapeGeo
    let look: PlanLook
    let letters: [String]
    var onPick: ((Int) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduced

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / VB
            let H = k > 0 ? geo.size.height / k : 1
            ZStack(alignment: .topLeading) {
                if RSH_STILL || reduced {
                    canvas(0.32, k, H)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        canvas(0.32 + 0.1 * sin(t * 2 * .pi / 1.3), k, H)
                    }
                }
                if look.pick, let onPick, g.corners.count >= 2 { pickButtons(k, H, onPick) }
            }
        }
        .accessibilityElement(children: look.pick ? .contain : .ignore)
        .accessibilityIdentifier("rsh.plan")
    }

    private func canvas(_ glow: Double, _ k: CGFloat, _ H: CGFloat) -> some View {
        Canvas { ctx, _ in
            var c = ctx
            c.scaleBy(x: k, y: k)
            drawPlan(c, H, glow)
        }
    }

    /// One button a wall, at its middle, for picking it.
    private func pickButtons(_ k: CGFloat, _ H: CGFloat, _ pick: @escaping (Int) -> Void) -> some View {
        let f = PFit(fitPoints(g), g.spec, VB, H, look.pad, look.rp)
        return ForEach(Array(g.walls.enumerated()), id: \.offset) { i, e in
            let a = f.m(e.from), b = f.m(e.to)
            let len = hypot(b.x - a.x, b.y - a.y) * k
            let w = max(44, len * 0.7)
            Rectangle().fill(Color.white.opacity(0.001))
                .frame(width: w, height: 44)
                .rotationEffect(.radians(atan2(Double(b.y - a.y), Double(b.x - a.x))))
                .position(x: (a.x + b.x) / 2 * k, y: (a.y + b.y) / 2 * k)
                .onTapGesture { pick(i) }
                .accessibilityElement()
                .accessibilityLabel(Text(reTr("rsh.wall", ["w": i < letters.count ? letters[i] : "?"])))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("rsh.wall." + (i < letters.count ? letters[i] : "\(i)"))
        }
    }

    private func letter(_ i: Int) -> String { i >= 0 && i < letters.count ? letters[i] : "?" }

    private func drawPlan(_ ctx: GraphicsContext, _ H: CGFloat, _ glow: Double) {
        let o = look
        guard g.corners.count >= 2 else { return }
        let W = VB
        let f = PFit(fitPoints(g), g.spec, W, H, o.pad, o.rp)
        let poly = g.corners.map { f.m($0) }
        let sg: CGFloat = area2(poly) >= 0 ? 1 : -1
        let cen = CGPoint(x: poly.map(\.x).reduce(0, +) / CGFloat(poly.count), y: poly.map(\.y).reduce(0, +) / CGFloat(poly.count))
        ctx.fill(polyPath(poly), with: .color(g.gap == nil ? RC.room : RC.room.opacity(0.6)))
        var labels: [PillAt] = []
        for (i, e) in g.walls.enumerated() {
            let a = f.m(e.from), b = f.m(e.to)
            let st = eState(e, i, o)
            if st == "cur" { stroke(ctx, a, b, RC.blue.opacity(glow), 16) }
            switch st {
            case "todo": stroke(ctx, a, b, G.ink3, 2.5)
            case "auto": stroke(ctx, a, b, G.ink3, 2, dash: [6, 5])
            case "bad": stroke(ctx, a, b, RC.red, 2.5, dash: [6, 5])
            case "cur": stroke(ctx, a, b, RC.blue, 5)
            case "pick": stroke(ctx, a, b, RC.blue.opacity(0.9), 3.5, dash: [2, 6])
            default: stroke(ctx, a, b, G.ink2, 3)
            }
            let dx = b.x - a.x, dy = b.y - a.y
            let L = max(1, hypot(dx, dy))
            let nx = sg * dy / L, ny = -sg * dx / L
            let off: CGFloat = st == "cur" ? 17 : 14
            if !o.nolab && !(st == "auto" && !o.final && o.sel == nil && L < 52) {
                let t: String
                if st == "pick" { t = letter(i) }
                else if st == "bad" { t = (e.len < 0 ? "−" : "") + o.fmt(abs(e.len)) }
                else if o.sel != nil { t = st == "cur" ? letter(i) + " · " + o.fmt(e.len) : o.fmt(e.len) }
                else if o.final { t = o.fmt(e.len) }
                else if st == "cur" { t = o.liveTxt ?? "?" }
                else if st == "done" { t = o.fmt(e.len) }
                else if st == "todo" { t = letter(i) }
                else { t = reTr("rsh.auto") }
                labels.append(PillAt(x: (a.x + b.x) / 2 + nx * off, y: (a.y + b.y) / 2 + ny * off, nx: nx, ny: ny, t: t, st: st))
            }
        }
        for it in o.ops { drawOp(ctx, it, f, sg, false) }
        if let pv = o.preview { drawOp(ctx, pv, f, sg, true) }
        for d in g.guides {
            let a = f.m(d.a), b = f.m(d.b)
            let st: String = o.final || o.sel != nil ? "done" : o.cur == d.ask ? "cur" : o.done.contains(d.ask) ? "done" : "todo"
            if st == "cur" { stroke(ctx, a, b, RC.blue.opacity(glow), 16) }
            switch st {
            case "cur": stroke(ctx, a, b, RC.blue, 3)
            case "done": stroke(ctx, a, b, G.ink2, 1.5, dash: [4, 4])
            default: stroke(ctx, a, b, G.ink3, 1.5, dash: [4, 4])
            }
            if !o.nolab {
                let isW = d.ask == 3
                let mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2
                let dx = b.x - a.x, dy = b.y - a.y
                let L = max(1, hypot(dx, dy))
                var nx = -dy / L, ny = dx / L
                if isW && nx * (cen.x - mx) + ny * (cen.y - my) < 0 { nx = -nx; ny = -ny }
                let t: String
                if st == "cur" { t = o.liveTxt ?? "?" }
                else if st == "todo" { t = tr(isW ? "rsh.dimW" : "rsh.dimD") }
                else { t = o.dimTxt[d.ask] ?? o.fmt(Double(d.ask < g.values.count ? g.values[d.ask] : 0)) }
                let kk: CGFloat = isW ? 13 : 26
                labels.append(PillAt(x: mx + nx * kk, y: my + ny * kk, nx: nx, ny: ny, t: t, st: st))
            }
        }
        if let dk = o.diagK, dk < g.corners.count {
            let a = f.m(g.corners[0]), b = f.m(g.corners[dk])
            if o.diagCur { stroke(ctx, a, b, RC.blue.opacity(glow), 16); stroke(ctx, a, b, RC.blue, 3) }
            else { stroke(ctx, a, b, G.ink3, 1.5, dash: [5, 5]) }
            if !o.nolab, let t = o.diagTxt { labels.append(PillAt(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, nx: 0, ny: 0, t: t, st: o.diagCur ? "cur" : "done")) }
        }
        if let gl = g.gap, let last = g.corners.last, let first = g.corners.first {
            let ga = f.m(last), gb = f.m(first)
            stroke(ctx, ga, gb, RC.red, 2.5, dash: [3, 4])
            if !o.nolab { labels.append(PillAt(x: (ga.x + gb.x) / 2, y: (ga.y + gb.y) / 2, nx: 0, ny: 0, t: reTr("rsh.gap") + " " + o.fmt(gl), st: "bad")) }
        }
        if let c = o.corner, c < g.walls.count {
            let p = f.m(g.walls[c].from)
            ctx.disc(RC.blue, 6.5, p); ctx.ring(RC.paper, 6.5, p, 2.5)
        }
        // pills of short walls meeting at a corner would sit on each other: the asked one stays put, the others step
        // further out from their wall (then along it) until they are clear
        var placed: [CGRect] = []
        // nearest first, so a letter stays by its own wall (an L's "C" was pushed far above its wall)
        let tries: [(CGFloat, CGFloat)] = [(0, 0), (0, 18), (0, -18), (12, 0), (12, 18), (12, -18), (0, 36), (0, -36), (24, 0), (36, 0), (12, 30), (12, -30)]
        for l in labels.sorted(by: { ($0.st == "cur" ? 0 : 1) < ($1.st == "cur" ? 0 : 1) }) {
            let tx = -l.ny, ty = l.nx
            var best = pillRect(l.x, l.y, l.t, l.st, W, H)
            for (n, t) in tries {
                let r = pillRect(l.x + l.nx * n + tx * t, l.y + l.ny * n + ty * t, l.t, l.st, W, H)
                if !placed.contains(where: { $0.intersects(r) }) { best = r; break }
            }
            placed.append(best)
            drawPill(ctx, best, l.t, l.st)
        }
    }

    /// An opening or a site point, as the mockup's opSvg: the door's gap, leaf and swing, the window's blue glass, a
    /// lettered dot.
    private func drawOp(_ ctx: GraphicsContext, _ it: ShapeOpening, _ f: PFit, _ sg: CGFloat, _ prev: Bool) {
        guard it.wall >= 0, it.wall < g.walls.count else { return }
        let e = g.walls[it.wall]
        let a = f.m(e.from), b = f.m(e.to)
        let dx = b.x - a.x, dy = b.y - a.y
        let L = max(1, hypot(dx, dy))
        let ux = dx / L, uy = dy / L
        let nx = -sg * dy / L, ny = sg * dx / L
        let al: Double = prev ? 0.6 : 1
        let dd = CGFloat(it.dist) * f.s, w = CGFloat(it.w) * f.s
        let p0 = CGPoint(x: a.x + ux * dd, y: a.y + uy * dd), p1 = CGPoint(x: a.x + ux * (dd + w), y: a.y + uy * (dd + w))
        if it.kind.isOpening && it.w <= 0 {
            ctx.disc(RC.blue.opacity(al), 5, p0); ctx.ring(RC.paper.opacity(al), 5, p0, 2.5); return
        }
        switch it.kind {
        case .door:
            let tip = CGPoint(x: p0.x + nx * w, y: p0.y + ny * w)
            stroke(ctx, p0, p1, RC.paper.opacity(al), 7)
            stroke(ctx, p0, tip, G.ink.opacity(al), 2)
            // the swing: a quarter circle from the door's far end to the leaf's tip, around its hinge
            let a0 = atan2(Double(p1.y - p0.y), Double(p1.x - p0.x))
            let a1 = atan2(Double(tip.y - p0.y), Double(tip.x - p0.x))
            var da = a1 - a0
            while da > .pi { da -= 2 * .pi }
            while da < -.pi { da += 2 * .pi }
            var path = Path()
            for s in 0...16 {
                let an = a0 + da * Double(s) / 16
                let q = CGPoint(x: p0.x + w * CGFloat(cos(an)), y: p0.y + w * CGFloat(sin(an)))
                if s == 0 { path.move(to: q) } else { path.addLine(to: q) }
            }
            ctx.stroke(path, with: .color(G.ink3.opacity(al)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        case .window:
            stroke(ctx, p0, p1, RC.win.opacity(al), 6); stroke(ctx, p0, p1, RC.paper.opacity(al), 1.6)
        default:
            let q = CGPoint(x: p0.x + nx * 11, y: p0.y + ny * 11)
            ctx.disc(RC.opC(it.kind).opacity(al), 8.5, q); ctx.ring(RC.paper.opacity(al), 8.5, q, 2)
            ctx.text(RC.opL(it.kind), q, .ui, 10, 800, Color.white.opacity(al))
        }
    }
}

/* ---------------- the shape cards' pictures ---------------- */

/// A shape card's picture: the outline with its usual sizes (blue when chosen), the bay's mouth dashed; the free sketch
/// a hand-drawn outline with its corners and a pen.
struct ShapeThumb: View {
    let shape: RoomShape
    var mir = false
    var rot = 0
    var sel = false
    var body: some View {
        Canvas { ctx, size in
            let sc = min(size.width / 160, size.height / 100)
            var c = ctx
            c.translateBy(x: (size.width - 160 * sc) / 2, y: (size.height - 100 * sc) / 2)
            c.scaleBy(x: sc, y: sc)
            let line: Color = sel ? RC.blue : G.ink
            if shape == .free {
                let p = SVGPath.path("M40 24C62 21 96 25 118 22C121 36 119 44 121 55C110 56 101 53 92 56C93 65 95 72 95 80C75 79 56 82 38 79C37 60 41 42 40 24Z")
                c.fill(p, with: .color(RC.room))
                c.stroke(p, with: .color(line), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                for (x, y) in [(40.0, 24.0), (118, 22), (121, 55), (92, 56), (95, 80), (38, 79)] { c.disc(RC.blue, 3.5, CGPoint(x: x, y: y)) }
                var pc = c
                pc.translateBy(x: 124, y: 62); pc.rotate(by: .degrees(10))
                pc.stroke(SVGPath.path("M0 22l4-1L17 8l-3-3L1 18z"), with: .color(RC.blue), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                return
            }
            let spec = ShapeSpec(shape, mirror: mir, turns: rot)
            let g = shapeGeometry(spec, [])
            let f = PFit(g.corners, spec, 160, 100, 14, 0)
            let q = g.corners.map { f.m($0) }
            guard q.count >= 3 else { return }
            let path = polyPath(q)
            c.fill(path, with: .color(RC.room))
            c.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
            if shape == .bay, let mouth = g.guides.first { stroke(c, f.m(mouth.a), f.m(mouth.b), G.ink3, 1.5, dash: [4, 3]) }
        }
        .accessibilityHidden(true)
    }
}

/// The height step's picture: a wall with a door and a window, the height glowing on the right with its pill.
struct HeightPic: View {
    let txt: String
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width / VB, size.height / 198)
            var c = ctx
            c.translateBy(x: (size.width - VB * k) / 2, y: (size.height - 198 * k) / 2)
            c.scaleBy(x: k, y: k)
            c.fill(Path(CGRect(x: 60, y: 26, width: 190, height: 132)), with: .color(RC.room))
            stroke(c, CGPoint(x: 44, y: 158), CGPoint(x: 262, y: 158), G.ink2, 3)
            stroke(c, CGPoint(x: 44, y: 26), CGPoint(x: 262, y: 26), G.ink3, 2.5)
            c.stroke(Path(CGRect(x: 88, y: 72, width: 44, height: 86)), with: .color(G.ink3), lineWidth: 1.5)
            c.stroke(Path(CGRect(x: 168, y: 62, width: 58, height: 46)), with: .color(G.ink3), lineWidth: 1.5)
            stroke(c, CGPoint(x: 197, y: 62), CGPoint(x: 197, y: 108), G.ink3, 1.3)
            stroke(c, CGPoint(x: 290, y: 28), CGPoint(x: 290, y: 156), RC.blue.opacity(0.3), 16)
            stroke(c, CGPoint(x: 290, y: 28), CGPoint(x: 290, y: 156), RC.blue, 5)
            stroke(c, CGPoint(x: 282, y: 26), CGPoint(x: 298, y: 26), RC.blue, 5)
            stroke(c, CGPoint(x: 282, y: 158), CGPoint(x: 298, y: 158), RC.blue, 5)
            drawPill(c, pillRect(290, 92, txt, "cur", VB, 198), txt, "cur")
            c.text(reTr("rsh.ceil"), CGPoint(x: 155, y: 16), .ui, 11, 700, G.ink3)
            c.text(reTr("rsh.floor"), CGPoint(x: 155, y: 172), .ui, 11, 700, G.ink3)
        }
        .accessibilityHidden(true)
    }
}

/// The openings step's picture buttons (the mockup's OP icons, 40 × 40).
struct OpIcon: View {
    let kind: OpKind
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 40
            var c = ctx
            c.scaleBy(x: k, y: k)
            let s = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            func p(_ d: String) -> Path { SVGPath.path(d) }
            switch kind {
            case .door:
                c.stroke(Path(roundedRect: CGRect(x: 11, y: 5, width: 18, height: 29), cornerRadius: 1.5), with: .color(color), style: s)
                c.disc(color, 1.4, CGPoint(x: 25, y: 20))
                c.stroke(p("M5 34h30"), with: .color(color), style: s)
            case .window:
                let r = Path(roundedRect: CGRect(x: 6, y: 8, width: 28, height: 22), cornerRadius: 1.5)
                c.fill(r, with: .color(RC.win.opacity(0.22)))
                c.stroke(r, with: .color(color), style: s)
                c.stroke(p("M20 8v22M6 19h28M4 34h32"), with: .color(color), style: s)
            case .water:
                c.stroke(p("M6 15h17a6 6 0 016 6v3"), with: .color(color), style: s)
                c.stroke(p("M15 15V9M10 9h10"), with: .color(color), style: s)
                let drop = p("M29 29c0 2.2-1.5 3.5-3.2 3.5S22.6 31.2 22.6 29c0-2.6 3.2-5.6 3.2-5.6s3.2 3 3.2 5.6z")
                c.fill(drop, with: .color(RC.opC(.water))); c.stroke(drop, with: .color(RC.opC(.water)), style: s)
            case .sewer:
                c.stroke(Path(ellipseIn: CGRect(x: 7, y: 7, width: 26, height: 26)), with: .color(color), style: s)
                c.stroke(p("M12 15h16M10 20h20M12 25h16"), with: .color(color), style: s)
            case .gas:
                c.stroke(p("M5 33h30M10 33V24h20v9"), with: .color(color), style: s)
                let fl = p("M20 4c3 3.6 5.2 6.3 5.2 9.2a5.2 5.2 0 01-10.4 0c0-1.7.8-3.1 1.9-4.2.2 1.7 1 2.6 2.1 2.6 0-2.7.6-4.9 1.2-7.6z")
                c.fill(fl, with: .color(RC.opC(.gas))); c.stroke(fl, with: .color(RC.opC(.gas)), style: s)
            }
        }
        .accessibilityHidden(true)
    }
}
