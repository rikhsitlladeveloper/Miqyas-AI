import SwiftUI

/*
 * What the room plans share (Android ui/editor/PlanCanvas.kt): the plan's colours, text drawn centred in viewBox units,
 * the dimension pills, the drag tooltip, the blueprint grid and offset snapping.
 *
 * In the editor the colours follow the dark theme (a light drawing on the dark blueprint); on paper (report plans and
 * card thumbnails, drawn inside Theme.onPaper) they keep their light values.
 */
var planDark: Bool { Theme.shared.dark }
func pc(_ light: UInt32, _ dark: UInt32) -> Color { Color(argb: planDark ? dark : light) }

enum PC {
    static var ink: Color { pc(0xFF0E1C36, 0xFFE2E8F2) }
    static var ink3: Color { pc(0xFF3E4A61, 0xFFAEB8CB) }
    static var greyLine: Color { pc(0xFF5F6B82, 0xFF8792A8) }
    static var cob: Color { pc(0xFF1C4BD1, 0xFF8C9CFF) }
    static var amber: Color { pc(0xFF9A4D00, 0xFFFFB45C) }
    static var red: Color { pc(0xFFB42318, 0xFFFF8A80) }
    static var paper: Color { pc(0xFFF3F6FA, 0xFF141A28) }
    static var selBand: Color { pc(0xFFE7EEFD, 0xFF1C2546) }
    static var okGreen: Color { pc(0xFF15803D, 0xFF4ADE80) }
    /// The plan's white: the wall ring under its hatching, windows, letter discs, corner handles.
    static var white: Color { pc(0xFFFFFFFF, 0xFF1A2134) }
    /// Letters and marks on a cobalt or red fill.
    static var onFill: Color { pc(0xFFFFFFFF, 0xFF0B0E16) }
    /// The pale blue inside a room being reshaped or a closed sketch.
    static var cobWash: Color { pc(0x121C4BD1, 0x1F8C9CFF) }
    static var pillInk: Color { pc(0xFF0F172A, 0xFFE8ECF4) }
    static func pillFill(_ a: Double) -> Color { planDark ? Color(argb: 0xFF1C2333).opacity(min(1, a + 0.12)) : Color.white.opacity(a) }
    static func pillEdge(_ a: Double) -> Color { planDark ? Color.white.opacity(0.18) : Color.white.opacity(a) }
    /// A disabled icon (undo with nothing to undo).
    static var offIcon: Color { Theme.shared.dark ? Color(argb: 0xFF5A6377) : Color(argb: 0xFF94A3B8) }
}

/* ---------------- small vector maths ---------------- */

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    static func / (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x / k, y: a.y / k) }
    static prefix func - (a: CGPoint) -> CGPoint { CGPoint(x: -a.x, y: -a.y) }
    var len: CGFloat { hypot(x, y) }
    func dot(_ b: CGPoint) -> CGFloat { x * b.x + y * b.y }
    init(_ p: Pt) { self.init(x: p.x, y: p.y) }
}

func unitV(_ a: CGPoint, _ b: CGPoint) -> CGPoint { let d = b - a; let l = d.len; return l == 0 ? CGPoint(x: 1, y: 0) : d / l }
func norm(_ o: CGPoint) -> CGPoint { let l = o.len; return l < 1e-6 ? .zero : o / l }
func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { (a + b) / 2 }

func polyPath(_ pts: [CGPoint], close: Bool = true) -> Path {
    var p = Path()
    guard let f = pts.first else { return p }
    p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
    if close { p.closeSubpath() }
    return p
}

func linePath(_ a: CGPoint, _ b: CGPoint) -> Path { var p = Path(); p.move(to: a); p.addLine(to: b); return p }

extension GraphicsContext {
    func line(_ c: Color, _ a: CGPoint, _ b: CGPoint, _ w: CGFloat, dash: [CGFloat]? = nil, round: Bool = false) {
        stroke(linePath(a, b), with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: round ? .round : .butt, dash: dash ?? []))
    }
    func disc(_ c: Color, _ r: CGFloat, _ at: CGPoint) { fill(Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: 2 * r, height: 2 * r)), with: .color(c)) }
    func ring(_ c: Color, _ r: CGFloat, _ at: CGPoint, _ w: CGFloat, dash: [CGFloat]? = nil) {
        stroke(Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: 2 * r, height: 2 * r)), with: .color(c), style: StrokeStyle(lineWidth: w, dash: dash ?? []))
    }
    /// Text centred on c. Sizes are in the context's units (viewBox units inside a scaled plan), fixed against Dynamic Type.
    func text(_ s: String, _ c: CGPoint, _ face: Face, _ size: CGFloat, _ weight: Int, _ color: Color, italic: Bool = false, tracking: CGFloat = 0) {
        var t = Text(s).font(.custom(fontName(face, weight), fixedSize: size)).foregroundColor(color).tracking(tracking * size)
        if italic { t = t.italic() }
        draw(t, at: c, anchor: .center)
    }
    /// A check mark like the prototype's pill tick, starting at x.
    func tick(_ x: CGFloat, _ y: CGFloat, _ c: Color, _ w: CGFloat) {
        var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + 3, y: y + 3)); p.addLine(to: CGPoint(x: x + 8.5, y: y - 2.5))
        stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }
    /// The little clock of a reading that waits.
    func clock(_ cc: CGPoint, _ c: Color) {
        ring(c, 5, cc, 1.6)
        line(c, cc, cc + CGPoint(x: 0, y: -3), 1.6, round: true); line(c, cc, cc + CGPoint(x: 2.2, y: 1.2), 1.6, round: true)
    }
    /// The "!" in a circle of a conflicting value.
    func bang(_ cc: CGPoint, _ c: Color) {
        ring(c, 5.5, cc, 1.6)
        line(c, cc + CGPoint(x: 0, y: -2.5), cc + CGPoint(x: 0, y: 0.8), 1.6); disc(c, 0.9, cc + CGPoint(x: 0, y: 2.6))
    }
}

/// Dimension pill sizes: 26 high, 16 + 8 per character (+15 with an icon), as in the prototype.
func pillW(_ text: String, _ icon: Bool) -> CGFloat { 16 + 8 * CGFloat(text.count) + (icon ? 15 : 0) }

/// Something tappable in a plan.
enum PlanHit { case dim(String), op(String) }

/// What the middle of a room shows (Profile → room label): the name in capitals and the floor area; mode a quote's own
/// choice (nil: Profile's).
func centreLabel(_ ctx: GraphicsContext, _ name0: String, _ area: String, _ c: CGPoint, mode: String? = nil) {
    // a long name is cut with "…", so it stays inside the plan
    let name = name0.count > 24 ? String(name0.prefix(23)).trimmingCharacters(in: .whitespaces) + "…" : name0
    let m = mode ?? AppSettings.shared.roomLabel
    let nm = m == "both" || m == "name", ar = m == "both" || m == "area"
    func n(_ at: CGPoint) { ctx.text(name.uppercased(), at, .ui, 11.5, 600, PC.ink3, tracking: 0.06) }
    func a(_ at: CGPoint) { ctx.text(area, at, .num, 12.5, 400, PC.ink3) }
    if nm && ar { n(CGPoint(x: c.x, y: c.y - 7)); a(CGPoint(x: c.x, y: c.y + 8)) }
    else if nm { n(c) } else if ar { a(c) }
}

/// The dark tooltip above the finger while dragging (prototype .dg-tip), in screen points.
func dragTip(_ ctx: GraphicsContext, _ size: CGSize, _ s: String, _ finger: CGPoint, _ bad: Bool) {
    let t = ctx.resolve(Text(s).font(.custom(fontName(.ui, 600), fixedSize: 13)).foregroundColor(.white))
    let ts = t.measure(in: CGSize(width: 300, height: 200))
    let w = ts.width + 20, h = ts.height + 12
    let left = min(max(4, finger.x - w / 2), size.width - w - 4)
    let top = max(4, finger.y - 18 - h - 40)
    let r = CGRect(x: left, y: top, width: w, height: h)
    ctx.fill(Path(roundedRect: r, cornerRadius: min(h / 2, 16)), with: .color(bad ? pc(0xFFB42318, 0xFFC8372A) : pc(0xF20F1626, 0xF22A3247)))
    ctx.draw(t, in: r.insetBy(dx: 10, dy: 6))
}

/// Offset snapping while dragging (prototype snapOff): 10 mm steps, the wall centre within 60, each end within 40.
func snapOff(_ off: Int, _ w: Int, _ L: Int?) -> Int {
    var o = kround(Double(off) / 10) * 10
    guard let L else { return max(0, o) }
    let mx = max(0, L - w), md = kround(Double(L - w) / 2 / 10) * 10
    if abs(o - md) < 60 { o = md }
    if o < 40 { o = 0 }
    if mx - o < 40 { o = mx }
    return min(max(o, 0), mx)
}

/// The blueprint grid behind the room pages (glass.css .page.gs-room: 23 pt lines, offset 8).
struct RoomGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let c = G.cobalt.opacity(Theme.shared.dark ? 0.10 : 0.06)
            var x: CGFloat = 8
            while x < size.width { ctx.line(c, CGPoint(x: x, y: 0), CGPoint(x: x, y: size.height), 1); x += 23 }
            var y: CGFloat = 8
            while y < size.height { ctx.line(c, CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y), 1); y += 23 }
        }
        .allowsHitTesting(false)
    }
}

/// Fits a viewBox of vw × vh into size: the scale and the top-left corner.
struct Fit {
    let k: CGFloat, dx: CGFloat, dy: CGFloat
    init(_ size: CGSize, _ vw: CGFloat, _ vh: CGFloat) {
        k = min(size.width / vw, size.height / vh)
        dx = (size.width - vw * k) / 2; dy = (size.height - vh * k) / 2
    }
    func vb(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - dx) / k, y: (p.y - dy) / k) }
    func apply(_ ctx: inout GraphicsContext) { ctx.translateBy(x: dx, y: dy); ctx.scaleBy(x: k, y: k) }
}

/// The error text for a parse result ("@u.m" in a value becomes the unit's name).
func errText(_ p: Parsed?) -> String? {
    guard case .err(let key, let vars)? = p else { return nil }
    var v: [String: Any] = [:]
    for (k, s) in vars { v[k] = s.replacingOccurrences(of: "@u.cm", with: tr("u.cm")).replacingOccurrences(of: "@u.m", with: tr("u.m")) }
    return tr(key, v)
}
