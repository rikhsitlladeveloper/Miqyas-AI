import SwiftUI

/// "Room hops", option B "Line + read hold" from the founder's launch-motion artifact (MxXnmrubuGSLppMi2zwRf1,
/// m8.html + room.js + common.js), redrawn natively like the Android app. The laser dot lands in a corner and hops
/// round the room, resting a moment on each landing; each landing snaps a neon wall with its length and adds one word
/// to "O‘lchang. Chizing. Hisoblang." (the newest bright, earlier ones dimmed), the third shows the area; the whole
/// line brightens and the walls glow softly while it is read; the room folds into the M, the dot lands in the V and
/// swells into blue, and the blue contracts into the logo tile, which docks where the next screen's header logo sits.
/// 3.4 s; a tap skips to the end.
///
/// Everything is drawn in the artifact's 390 × 844 design stage, scaled to fit, from one clock t (s).
struct RoomHops: View {
    /// Where the 38 pt header tile of the next screen is, in points from the top-left of the screen.
    let dockTo: CGRect
    let onDone: () -> Void
    @State private var start = Date()
    @State private var skipped = false
    @State private var finished = false
    @State private var tl = HopsTimeline()
    @Environment(\.accessibilityReduceMotion) private var reduced

    var body: some View {
        TimelineView(.animation(paused: finished)) { ctx in
            let t = skipped || reduced ? HopsTimeline.END : min(HopsTimeline.END, ctx.date.timeIntervalSince(start))
            Canvas { g, size in tl.draw(g, size, t, dockTo) }
                .onChange(of: t >= HopsTimeline.END) { _, done in if done { finish() } }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { skipped = true; finish() }
        .accessibilityLabel("METRX")
        .onAppear {
            start = Date()
            if reduced { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { finish() } }
            else { DispatchQueue.main.asyncAfter(deadline: .now() + HopsTimeline.END + 0.05) { finish() } }
        }
    }

    private func finish() { if !finished { finished = true; onDone() } }
}

private let NEON = Gradient(stops: [.init(color: Color(argb: 0xFF5B7BFF), location: 0), .init(color: Color(argb: 0xFF3FD8F2), location: 0.55), .init(color: Color(argb: 0xFFB07CFF), location: 1)])
private let COBALT = Color(argb: 0xFF3550E0)
private let PAPER = Color(argb: 0xFFEEF1F8)

final class HopsTimeline {
    // option B's timing (m8.html): landings, hop lengths, the fold; the tail after the fold always takes 1.30 s
    static let LA = 0.22, LB = 0.58, LD = 1.14, LE = 1.68
    static let HB = 0.22, HD = 0.24, HE = 0.22
    static let F = 2.10, BRIGHT = 1.98
    static let WIPE = F + 0.34, CN = WIPE + 0.30, DOCK = CN + 0.46
    static let END = DOCK + 0.2

    // ---- geometry of the artifact, in stage px ----
    private let S: CGFloat = 3.42
    private let A0 = CGPoint(x: 80, y: 480), B0 = CGPoint(x: 80, y: 330), C0 = CGPoint(x: 195, y: 330)
    private let D0 = CGPoint(x: 310, y: 330), E0 = CGPoint(x: 310, y: 480)
    private let u: CGFloat = 1.375
    private lazy var A1 = logo(15 * u, 47 * u)
    private lazy var B1 = logo(15 * u, 19 * u)
    private lazy var C1 = logo(32 * u, 38 * u)
    private lazy var D1 = logo(49 * u, 19 * u)
    private lazy var E1 = logo(49 * u, 47 * u)
    /// The M of the logo, mapped from the 88 px logo box (centre 44, 45.375) onto the stage at scale S around (195, 405).
    private func logo(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 195 + (x - 44) * S, y: 405 + (y - 45.375) * S) }
    private var CST: CGPoint { C1 }

    // ---- the laser dot: x, y = contact point; sx, sy = squash and stretch about the contact point ----
    private let dotX = Track(80), dotY = Track(220), dotO = Track(0), dotSX = Track(1), dotSY = Track(1)
    private func land(_ t: Double, wide: Bool = false) {
        dotSX.to(t, 0.05, wide ? 1.7 : 1.45, Ease.p1Out); dotSY.to(t, 0.05, wide ? 0.5 : 0.62, Ease.p1Out)
        dotSX.to(t + 0.05, 0.1, 1, Ease.backOut(3)); dotSY.to(t + 0.05, 0.1, 1, Ease.backOut(3))
    }
    private func hop(_ t: Double, _ to: CGPoint, _ apex: Double, _ dur: Double) {
        dotSX.to(t - 0.06, 0.06, 1.25, Ease.p1Out); dotSY.to(t - 0.06, 0.06, 0.72, Ease.p1Out)
        dotX.to(t, dur, Double(to.x), Ease.p1InOut)
        dotY.to(t, dur * 0.45, apex, Ease.p2Out); dotY.to(t + dur * 0.45, dur * 0.55, Double(to.y), Ease.p2In)
        dotSX.to(t, dur * 0.25, 0.8, Ease.p1Out); dotSY.to(t, dur * 0.25, 1.3, Ease.p1Out)
        dotSX.to(t + dur * 0.25, dur * 0.25, 1, Ease.sineInOut); dotSY.to(t + dur * 0.25, dur * 0.25, 1, Ease.sineInOut)
        dotSX.to(t + dur * 0.62, dur * 0.3, 0.82, Ease.p1In); dotSY.to(t + dur * 0.62, dur * 0.3, 1.25, Ease.p1In)
    }

    // ---- walls: how much of the room outline is drawn, then the fold into the M ----
    private let wallDraw = Track(0), wallOn = Track(0), fold = Track(0), planO = Track(1)
    private let floorA = Track(0), floorB = Track(0), floorO = Track(0)
    private func snap(_ to: Double, _ t: Double) { wallOn.set(t, 1); wallDraw.to(t, 0.12, to, Ease.p3Out) }
    private let dotScale: [Character: Track] = ["A": Track(0), "B": Track(0), "C": Track(0), "D": Track(0), "E": Track(0)]
    private func mark(_ k: Character, _ t: Double) { dotScale[k]!.to(t, 0.18, 1, Ease.backOut(3)) }
    private lazy var rings: [(CGPoint, Double)] = [(A0, Self.LA), (B0, Self.LB), (D0, Self.LD), (E0, Self.LE)]
    /// The walls' middle glow layer (.wl.g1), which breathes during the read hold.
    private let glowG1 = Track(0.38)

    // ---- dimension lines, labels, area ----
    private let dmL = Track(0), dmT = Track(0), dtL = Track(0), dtT = Track(0), dimsO = Track(1)
    private let areaO = Track(0), areaS = Track(0.6)

    // ---- the tagline: one line built word by word (room.css #tagline) ----
    private let words = ["O‘lchang.", "Chizing.", "Hisoblang."]
    private let wordO = [Track(0), Track(0), Track(0)], wordY = [Track(0), Track(0), Track(0)]
    private let taglineO = Track(1)
    private func wordIn(_ i: Int, _ t: Double) {
        wordO[i].fromTo(t, 0.18, 0, 1, Ease.p3Out); wordY[i].fromTo(t, 0.18, 8, 0, Ease.p3Out)
        for j in 0..<i { wordO[j].to(t, 0.2, 0.6, Ease.p1Out) }   // the newest word brightest
    }

    // ---- the blue: wipe, logo, tile, lockup, dock ----
    private let flipSolid = Track(0), logoO = Track(0)
    private lazy var logoK = Track(Double(S))
    private lazy var logoY = Track(Double(-17 - 1.375 * S))
    private let tileO = Track(0), tileK = Track(1), shadowO = Track(0), shadowY = Track(-4)
    private let light = Track(0)        // 0: blueprint, 1: the light paper and aurora
    private let lockupX = Track(1)      // fraction of the centring shift still applied
    private let dock = Track(0)

    init() {
        typealias H = HopsTimeline
        // the laser dot falls into the first corner
        let fall = 0.20
        dotO.to(max(0, H.LA - fall - 0.02), 0.06, 1, Ease.none)
        dotSX.to(H.LA - fall, fall * 0.9, 0.8, Ease.p1In); dotSY.to(H.LA - fall, fall * 0.9, 1.3, Ease.p1In)
        dotY.to(H.LA - fall, fall, 486, Ease.p2In); land(H.LA); mark("A", H.LA)

        // three hops: each landing snaps a wall and adds a word
        hop(H.LB - H.HB, CGPoint(x: 80, y: 336), 290, H.HB); land(H.LB)                          // left wall
        snap(150.0 / 530.0, H.LB); mark("B", H.LB); wordIn(0, H.LB)
        dmL.to(H.LB + 0.10, 0.2, 1, Ease.p3Out); dtL.to(H.LB + 0.12, 0.14, 1, Ease.none)

        hop(H.LD - H.HD, CGPoint(x: 310, y: 336), 262, H.HD); land(H.LD)                         // top wall
        snap(380.0 / 530.0, H.LD); mark("D", H.LD); wordIn(1, H.LD)
        dmT.to(H.LD + 0.10, 0.2, 1, Ease.p3Out); dtT.to(H.LD + 0.12, 0.14, 1, Ease.none)

        hop(H.LE - H.HE, CGPoint(x: 310, y: 486), 300, H.HE); land(H.LE)                         // right wall, floor closes, area
        snap(1, H.LE); mark("E", H.LE); wordIn(2, H.LE)
        floorO.set(H.LE + 0.02, 1); floorB.to(H.LE + 0.02, 0.12, 1, Ease.p2Out)
        areaO.fromTo(H.LE + 0.08, 0.2, 0, 1, Ease.backOut(2.2)); areaS.fromTo(H.LE + 0.08, 0.2, 0.6, 1, Ease.backOut(2.2))

        // the read hold: the whole line back to full brightness, the walls breathe once
        for w in wordO { w.to(H.BRIGHT, 0.25, 1, Ease.p1InOut) }
        let g = (H.F - H.LE - 0.14) / 2
        glowG1.to(H.LE + 0.12, g, 0.62, Ease.sineInOut); glowG1.to(H.LE + 0.12 + g, g, 0.38, Ease.sineInOut)

        // the room folds into the M; the dot hops into the V
        dimsO.to(H.F, 0.1, 0, Ease.p1In)
        floorA.to(H.F, 0.12, 0.5, Ease.p2In); floorB.to(H.F, 0.12, 0.5, Ease.p2In); floorO.set(H.F + 0.12, 0)
        fold.to(H.F, 0.32, 1, Ease.p3InOut)
        dotScale["C"]!.to(H.F, 0.14, 1, Ease.expoOut)
        dotScale["A"]!.to(H.F, 0.32, 0, Ease.p2In); dotScale["E"]!.to(H.F, 0.32, 0, Ease.p2In)
        hop(H.F + 0.02, CGPoint(x: CST.x, y: CST.y + 6), 360, 0.30); land(H.F + 0.32, wide: true)

        // the dot swells into blue and covers everything; the drawing becomes the solid M
        dotO.set(H.WIPE, 0)
        flipSolid.set(H.WIPE + 0.28, 1)
        logoO.to(H.WIPE + 0.19, 0.08, 1, Ease.none); planO.to(H.WIPE + 0.19, 0.08, 0, Ease.none)
        taglineO.set(H.WIPE + 0.24, 0)                                                               // already under the blue

        // the blue contracts into the tile; layers swap while the screen is covered
        tileO.set(H.CN, 1); light.set(H.CN, 1); flipSolid.set(H.CN, 0)
        tileK.to(H.CN, 0.22, 0.95, Ease.expoInOut); tileK.to(H.CN + 0.22, 0.14, 1, Ease.backOut(2.5))
        logoK.to(H.CN, 0.22, 1, Ease.expoInOut); logoY.to(H.CN, 0.22, 0, Ease.expoInOut)
        shadowO.fromTo(H.CN + 0.14, 0.2, 0, 1, Ease.p2Out); shadowY.fromTo(H.CN + 0.14, 0.2, -4, 0, Ease.p2Out)
        lockupX.to(H.CN + 0.14, 0.3, 0, Ease.p3Out)
        dock.to(H.DOCK, 0.2, 1, Ease.p3Out)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ k: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k) }

    func draw(_ g: GraphicsContext, _ size: CGSize, _ t: Double, _ dockTo: CGRect) {
        let W = size.width, H = size.height
        // fit the 390 × 844 stage, like layout() in common.js
        let s = min(W / 390, H / 844, 1.25)
        let sx = (W - 390 * s) / 2, sy = (H - 844 * s) / 2
        let vb = CGRect(x: -sx / s, y: -sy / s, width: W / s, height: H / s)
        let lit = light(t) >= 1

        // ---- background ----
        if !lit {
            g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(G.blueprint))
            var e = g
            e.translateBy(x: W * 0.5, y: H * 0.46); e.scaleBy(x: 1, y: (H * 0.5) / (W * 0.7))
            let rg = Gradient(stops: [.init(color: Color(argb: 0x613550E0), location: 0), .init(color: Color(argb: 0x003550E0), location: 0.7)])
            e.fill(Path(ellipseIn: CGRect(x: -W * 0.7, y: -W * 0.7, width: W * 1.4, height: W * 1.4)), with: .radialGradient(rg, center: .zero, startRadius: 0, endRadius: W * 0.7))
            grid(g, size, Color(argb: 0x1C7A92FF))
        } else {
            g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(PAPER))
            aurora(g, size)
            grid(g, size, Color(argb: 0x0F3550E0))
        }

        var st = g
        st.translateBy(x: sx, y: sy); st.scaleBy(x: s, y: s)
        if !lit {
            if planO(t) > 0 { plan(st, t, planO(t)) }
            dims(st, t)
            tagline(st, t)
            ringsAt(st, t)
            logoOnBlue(st, t)
            dot(st, t)
            wipe(st, t, vb)
        } else {
            lockup(st, t, vb, s, sx, sy, dockTo)
        }
    }

    private func grid(_ g: GraphicsContext, _ size: CGSize, _ c: Color) {
        var p = Path()
        var x: CGFloat = 0; while x < size.width { p.addRect(CGRect(x: x, y: 0, width: 1, height: size.height)); x += 23 }
        var y: CGFloat = 0; while y < size.height { p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 23 }
        g.fill(p, with: .color(c))
    }

    /// The light end frame of the artifact (#aur in common.css, inset -8%).
    private func aurora(_ g: GraphicsContext, _ size: CGSize) {
        let w = size.width * 1.16, h = size.height * 1.16, ox = -size.width * 0.08, oy = -size.height * 0.08
        func glow(_ rx: CGFloat, _ ry: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ c: UInt32) {
            var e = g
            e.translateBy(x: ox + w * cx, y: oy + h * cy); e.scaleBy(x: 1, y: (h * ry) / (w * rx))
            let col = Color(argb: c)
            let gr = Gradient(stops: [.init(color: col, location: 0), .init(color: col.opacity(0), location: 0.7)])
            let r = w * rx
            e.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)), with: .radialGradient(gr, center: .zero, startRadius: 0, endRadius: r))
        }
        glow(0.58, 0.40, 0.06, 0.04, 0x665B7BFF); glow(0.52, 0.36, 1.04, 0.40, 0x4DB07CFF)
        glow(0.58, 0.38, -0.02, 0.82, 0x4D3FD8F2); glow(0.56, 0.38, 1.02, 1.02, 0x66FFB58A)
    }

    private func plan(_ g: GraphicsContext, _ t: Double, _ alpha: Double) {
        let k = CGFloat(fold(t))
        let pts = [lerp(A0, A1, k), lerp(B0, B1, k), lerp(C0, C1, k), lerp(D0, D1, k), lerp(E0, E1, k)]
        var room = Path(); room.move(to: pts[0]); for p in pts.dropFirst() { room.addLine(to: p) }
        let drawn = k > 0 ? 1 : wallDraw(t)
        if wallOn(t) > 0 && drawn > 0 { neon(g, room.trimmedPath(from: 0, to: CGFloat(drawn)), alpha, glowG1(t)) }
        if floorO(t) > 0 {
            let fa = floorA(t), fb = floorB(t)
            if fb > fa {
                var fp = Path(); fp.move(to: E0); fp.addLine(to: A0)
                let seg = fp.trimmedPath(from: CGFloat(fa), to: CGFloat(fb))
                var c = g; c.opacity = 0.38 * alpha
                c.stroke(seg, with: wallShading, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                var c2 = g; c2.opacity = alpha
                c2.stroke(seg, with: .color(Color(argb: 0xFFECF3FF)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
        // corner dots
        let at: [(Character, CGPoint)] = [("A", pts[0]), ("B", pts[1]), ("C", pts[2]), ("D", pts[3]), ("E", pts[4])]
        for (key, p) in at {
            let sc = CGFloat(dotScale[key]!(t)); if sc <= 0 { continue }
            let gl = Gradient(stops: [.init(color: .white, location: 0), .init(color: Color(argb: 0xE6A9ECFF), location: 0.3), .init(color: Color(argb: 0x003FD8F2), location: 1)])
            var c = g; c.opacity = 0.7 * alpha
            let r = 12 * sc
            c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .radialGradient(gl, center: p, startRadius: 0, endRadius: r))
            var c2 = g; c2.opacity = alpha
            let r2 = 3 * sc
            c2.fill(Path(ellipseIn: CGRect(x: p.x - r2, y: p.y - r2, width: 2 * r2, height: 2 * r2)), with: .color(.white))
        }
    }

    private var wallShading: GraphicsContext.Shading { .linearGradient(NEON, startPoint: CGPoint(x: A0.x, y: B0.y), endPoint: E0) }

    private func neon(_ g: GraphicsContext, _ p: Path, _ alpha: Double, _ g1: Double) {
        var a = g; a.opacity = 0.14 * alpha
        a.stroke(p, with: wallShading, style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
        var b = g; b.opacity = g1 * alpha
        b.stroke(p, with: wallShading, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        var c = g; c.opacity = alpha
        c.stroke(p, with: .color(Color(argb: 0xFFECF3FF)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }

    private let dimColor = Color(argb: 0x9EBECDFF)
    private func jakarta(_ size: CGFloat, _ w: String) -> Font { .custom("PlusJakartaSans-" + w, size: size) }

    private func dims(_ g: GraphicsContext, _ t: Double) {
        let o = dimsO(t); if o <= 0 { return }
        var c = g; c.opacity = o
        let l = dmL(t)
        if l > 0 { let h = 75 * l; var p = Path(); p.move(to: CGPoint(x: 62, y: 405 - h)); p.addLine(to: CGPoint(x: 62, y: 405 + h)); c.stroke(p, with: .color(dimColor), lineWidth: 1) }
        if dtL(t) > 0 {
            var a = g; a.opacity = dtL(t) * o
            a.stroke(SVGPath.path("M76 330H56M76 480H56M58 334L66 326M58 484L66 476"), with: .color(dimColor), lineWidth: 1)
            label(a, "3,60 m", CGPoint(x: 43, y: 405), rot: -90)
        }
        let tt = dmT(t)
        if tt > 0 { let w = 115 * tt; var p = Path(); p.move(to: CGPoint(x: 195 - w, y: 312)); p.addLine(to: CGPoint(x: 195 + w, y: 312)); c.stroke(p, with: .color(dimColor), lineWidth: 1) }
        if dtT(t) > 0 {
            var a = g; a.opacity = dtT(t) * o
            a.stroke(SVGPath.path("M80 326V306M310 326V306M76 316L84 308M306 316L314 308"), with: .color(dimColor), lineWidth: 1)
            label(a, "5,20 m", CGPoint(x: 195, y: 296), rot: 0)
        }
        let ao = min(1, max(0, areaO(t))) * o
        if ao > 0 {
            var a = g; a.opacity = ao
            a.addFilter(.shadow(color: Color(argb: 0x733FD8F2), radius: 8))
            let txt = Text("18,72").font(jakarta(26, "Bold")).foregroundColor(.white)
                + Text(" m²").font(jakarta(15, "Medium")).foregroundColor(Color(argb: 0xFFC9D4FF))
            let sc = areaS(t)
            a.translateBy(x: 195, y: 404); a.scaleBy(x: sc, y: sc)
            a.draw(a.resolve(txt), at: .zero, anchor: .center)
        }
    }

    private func label(_ g: GraphicsContext, _ text: String, _ center: CGPoint, rot: Double) {
        var c = g
        c.translateBy(x: center.x, y: center.y); c.rotate(by: .degrees(rot))
        c.draw(c.resolve(Text(text).font(jakarta(13, "Bold")).foregroundColor(Color(argb: 0xFFC9D4FF)).tracking(13 * 0.02)), at: .zero, anchor: .center)
    }

    /// The line under the room: centred on y 536 (its 28 px line box starts at 522), whole words with a space between.
    private func tagline(_ g: GraphicsContext, _ t: Double) {
        let lo = taglineO(t); if lo <= 0 { return }
        var c = g
        c.addFilter(.shadow(color: Color(argb: 0x593FD8F2), radius: 6))
        let rs = words.map { c.resolve(Text($0).font(jakarta(22, "Bold")).foregroundColor(Color(argb: 0xFFF2F6FF))) }
        let ws = rs.map { $0.measure(in: CGSize(width: 1000, height: 100)).width }
        let space = c.resolve(Text(" ").font(jakarta(22, "Bold"))).measure(in: CGSize(width: 100, height: 100)).width
        let total = ws.reduce(0, +) + space * CGFloat(ws.count - 1)
        var x = 195 - total / 2
        for i in rs.indices {
            let o = min(1, max(0, wordO[i](t) * lo))
            if o > 0 { var w = c; w.opacity = o; w.draw(rs[i], at: CGPoint(x: x, y: 536 + wordY[i](t)), anchor: .leading) }
            x += ws[i] + space
        }
    }

    private func ringsAt(_ g: GraphicsContext, _ t: Double) {
        for (p, at) in rings {
            if t < at || t > at + 0.42 { continue }
            let k = CGFloat(Ease.p2Out((t - at) / 0.42))
            var c = g; c.opacity = 0.9 * Double(1 - k)
            let sc = 0.3 + (2.4 - 0.3) * k, r = 13 * sc
            c.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(argb: 0xD978DCFF)), lineWidth: 1.5 * sc)
        }
    }

    private func dot(_ g: GraphicsContext, _ t: Double) {
        let o = dotO(t); if o <= 0 { return }
        let p = CGPoint(x: dotX(t), y: dotY(t))
        var c = g; c.opacity = o
        c.translateBy(x: p.x, y: p.y); c.scaleBy(x: dotSX(t), y: dotSY(t))
        let ctr = CGPoint(x: 0, y: -6)
        func disc(_ r: CGFloat, _ sh: GraphicsContext.Shading) { c.fill(Path(ellipseIn: CGRect(x: ctr.x - r, y: ctr.y - r, width: 2 * r, height: 2 * r)), with: sh) }
        disc(30, .radialGradient(Gradient(colors: [Color(argb: 0x735B7BFF), Color(argb: 0x005B7BFF)]), center: ctr, startRadius: 0, endRadius: 30))
        disc(14, .radialGradient(Gradient(colors: [Color(argb: 0xBF3FD8F2), Color(argb: 0x003FD8F2)]), center: ctr, startRadius: 0, endRadius: 14))
        disc(6, .color(.white))
    }

    private func wipe(_ g: GraphicsContext, _ t: Double, _ vb: CGRect) {
        if flipSolid(t) >= 1 { g.fill(Path(vb), with: .color(COBALT)); return }
        if t < Self.WIPE { return }
        let far = [CGPoint(x: vb.minX, y: vb.minY), CGPoint(x: vb.maxX, y: vb.minY), CGPoint(x: vb.minX, y: vb.maxY), CGPoint(x: vb.maxX, y: vb.maxY)]
            .map { hypot($0.x - CST.x, $0.y - CST.y) }.max()!
        let k = CGFloat(Ease.p2In(min(1, max(0, (t - Self.WIPE) / 0.28))))
        let r = 6 * (1 + ((2 * far) / 12 + 2 - 1) * k)
        g.fill(Path(ellipseIn: CGRect(x: CST.x - r, y: CST.y - r, width: 2 * r, height: 2 * r)), with: .color(COBALT))
    }

    /// The white M on the blue, at hero scale (it fades in once the circle has covered the M).
    private func logoOnBlue(_ g: GraphicsContext, _ t: Double) {
        let o = logoO(t); if o <= 0 { return }
        var c = g; c.opacity = o
        let box = 88 * CGFloat(logoK(t)), ctr = CGPoint(x: 195, y: 422 + CGFloat(logoY(t)))
        drawLogoMark(c, tile: COBALT, box: box, origin: CGPoint(x: ctr.x - box / 2, y: ctr.y - box / 2))
    }

    // ---- the light end frame: shadow, tile, logo, wordmark; then everything docks into the header ----
    private func lockup(_ g: GraphicsContext, _ t: Double, _ vb: CGRect, _ s: CGFloat, _ sx: CGFloat, _ sy: CGFloat, _ dockTo: CGRect) {
        let letters = Array("METRX").map { g.resolve(Text(String($0)).font(jakarta(34.737, "Bold")).foregroundColor(Color(argb: 0xFF0F172A))) }
        let lw = letters.map { $0.measure(in: CGSize(width: 200, height: 200)).width }
        // the last letter has no trailing spacing (common.css: #word span:last-child{letter-spacing:0})
        let ls: CGFloat = 34.737 * 0.32
        let ww = lw.reduce(0, +) + ls * CGFloat(letters.count - 1)
        let Tt: CGFloat = 88
        let gap: CGFloat = 10 * (88.0 / 38.0)
        let shift = (gap + ww) / 2
        let L = 195 - (Tt + gap + ww) / 2
        let lx = L + shift * CGFloat(lockupX(t))
        let top: CGFloat = 378

        // dock: move the whole lockup so the tile lands on the header tile (38 pt)
        let d = CGFloat(dock(t))
        let target = CGPoint(x: (dockTo.minX - sx) / s, y: (dockTo.minY - sy) / s)
        let k = 1 + ((dockTo.width / s) / Tt - 1) * d
        let ox = lx + (target.x - lx) * d, oy = top + (target.y - top) * d

        var c = g
        c.translateBy(x: ox, y: oy); c.scaleBy(x: k, y: k)
        // shadow under the tile
        let so = shadowO(t)
        if so > 0 {
            var sh = c; sh.addFilter(.blur(radius: 7.5))
            sh.fill(Path(roundedRect: CGRect(x: 8, y: 26 + shadowY(t), width: 72, height: 72), cornerRadius: 20), with: .color(Color(red: 53 / 255, green: 80 / 255, blue: 224 / 255).opacity(0.36 * so)))
        }
        // tile: starts covering the screen, contracts to 88 px with a small overshoot
        let cover = 2 * max(max(195 - vb.minX, vb.maxX - 195), max(422 - vb.minY, vb.maxY - 422)) / 88 * 1.03
        let tileScale: CGFloat
        if t < Self.CN { tileScale = cover }
        else if t < Self.CN + 0.22 { tileScale = cover + (0.95 - cover) * CGFloat(Ease.expoInOut(min(1, max(0, (t - Self.CN) / 0.22)))) }
        else { tileScale = CGFloat(tileK(t)) }
        var tc = c
        tc.translateBy(x: 44, y: 44); tc.scaleBy(x: tileScale, y: tileScale); tc.translateBy(x: -44, y: -44)
        tc.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: 88, height: 88), cornerRadius: 22, style: .continuous), with: .color(COBALT))
        let box = 88 * CGFloat(logoK(t))
        drawLogoMark(c, tile: COBALT, box: box, origin: CGPoint(x: 44 - box / 2, y: 44 + CGFloat(logoY(t)) - box / 2))
        // wordmark letters pop in one after another
        var x = Tt + gap
        for (i, r) in letters.enumerated() {
            let st = Self.CN + 0.16 + Double(i) * 0.03
            if t >= st {
                let e = Ease.backOut(2.2)(min(1, max(0, (t - st) / 0.24)))
                let sc = 0.4 + 0.6 * e
                var lc = c; lc.opacity = min(1, max(0, e))
                let bottom = CGPoint(x: x + lw[i] / 2, y: 42.77 + 17.4)
                lc.translateBy(x: bottom.x, y: bottom.y); lc.scaleBy(x: sc, y: sc)
                lc.draw(r, at: CGPoint(x: 0, y: -17.4 + 18 * (1 - e)), anchor: .center)
            }
            x += lw[i] + ls
        }
    }
}
