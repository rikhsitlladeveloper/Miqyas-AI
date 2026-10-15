import SwiftUI

/// One shape of an icon: SVG path data plus the few style attributes that differ from the default stroke.
struct IconPart {
    let d: String
    var fill: String? = nil
    var stroke: String? = nil
    var strokeWidth: CGFloat? = nil
    var opacity: Double? = nil
    init(_ d: String, fill: String? = nil, stroke: String? = nil, strokeWidth: CGFloat? = nil, opacity: Double? = nil) {
        self.d = d; self.fill = fill; self.stroke = stroke; self.strokeWidth = strokeWidth; self.opacity = opacity
    }
}
struct IconDef { let w: CGFloat; let h: CGFloat; let parts: [IconPart] }

/// SVG path data → Path (M L H V C S Q T A Z, absolute and relative), like Android's PathParser.
enum SVGPath {
    private static var cache: [String: Path] = [:]

    static func path(_ d: String) -> Path {
        if let p = cache[d] { return p }
        let p = parse(d); cache[d] = p; return p
    }

    private static func isDigit(_ c: Unicode.Scalar) -> Bool { c.value >= 48 && c.value <= 57 }

    private static func tokens(_ d: String) -> [Any] {
        var out: [Any] = []
        let cs = Array(d.unicodeScalars)
        var i = 0
        while i < cs.count {
            let c = cs[i]
            if CharacterSet.letters.contains(c) && c != "e" && c != "E" { out.append(Character(c)); i += 1; continue }
            if c == "-" || c == "+" || c == "." || isDigit(c) {
                var j = i; var seenDot = false; var seenExp = false
                if cs[j] == "-" || cs[j] == "+" { j += 1 }
                while j < cs.count {
                    let x = cs[j]
                    if isDigit(x) { j += 1 }
                    else if x == "." && !seenDot && !seenExp { seenDot = true; j += 1 }
                    else if (x == "e" || x == "E") && !seenExp { seenExp = true; j += 1; if j < cs.count, cs[j] == "-" || cs[j] == "+" { j += 1 } }
                    else { break }
                }
                out.append(Double(String(String.UnicodeScalarView(cs[i..<j]))) ?? 0)
                i = j; continue
            }
            i += 1
        }
        return out
    }

    static func parse(_ d: String) -> Path {
        var p = Path()
        let t = tokens(d)
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint? = nil, lastQ: CGPoint? = nil
        func num() -> CGFloat { defer { i += 1 }; return CGFloat(i < t.count ? (t[i] as? Double ?? 0) : 0) }
        func flag() -> Bool {
            // arc flags may be written without separators ("a1 1 0 01 2 2")
            if i < t.count, let v = t[i] as? Double { i += 1; return v != 0 }
            return false
        }
        while i < t.count {
            if let c = t[i] as? Character { cmd = c; i += 1 }
            else if cmd == "M" { cmd = "L" } else if cmd == "m" { cmd = "l" }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd.uppercased() {
            case "M":
                cur = CGPoint(x: o.x + num(), y: o.y + num()); start = cur; p.move(to: cur); lastCtrl = nil; lastQ = nil
                cmd = rel ? "l" : "L"
                continue
            case "L": cur = CGPoint(x: o.x + num(), y: o.y + num()); p.addLine(to: cur); lastCtrl = nil; lastQ = nil
            case "H": cur.x = (rel ? cur.x : 0) + num(); p.addLine(to: cur); lastCtrl = nil; lastQ = nil
            case "V": cur.y = (rel ? cur.y : 0) + num(); p.addLine(to: cur); lastCtrl = nil; lastQ = nil
            case "C":
                let c1 = CGPoint(x: o.x + num(), y: o.y + num()), c2 = CGPoint(x: o.x + num(), y: o.y + num())
                cur = CGPoint(x: o.x + num(), y: o.y + num()); p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2; lastQ = nil
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: o.x + num(), y: o.y + num())
                cur = CGPoint(x: o.x + num(), y: o.y + num()); p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2; lastQ = nil
            case "Q":
                let c = CGPoint(x: o.x + num(), y: o.y + num())
                cur = CGPoint(x: o.x + num(), y: o.y + num()); p.addQuadCurve(to: cur, control: c); lastQ = c; lastCtrl = nil
            case "T":
                let c = lastQ.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                cur = CGPoint(x: o.x + num(), y: o.y + num()); p.addQuadCurve(to: cur, control: c); lastQ = c; lastCtrl = nil
            case "A":
                let rx = num(), ry = num(), rot = num(), large = flag(), sweep = flag()
                let end = CGPoint(x: o.x + num(), y: o.y + num())
                arc(&p, from: cur, to: end, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                cur = end; lastCtrl = nil; lastQ = nil
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil; lastQ = nil
            default:
                i += 1
            }
        }
        return p
    }

    /// SVG elliptical arc (endpoint form) as cubic Béziers (SVG spec F.6).
    private static func arc(_ p: inout Path, from a: CGPoint, to b: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) {
        if a == b { return }
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 { p.addLine(to: b); return }
        let phi = rotation * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (a.x - b.x) / 2, dy = (a.y - b.y) / 2
        let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
        let lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lam > 1 { let s = sqrt(lam); rx *= s; ry *= s }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var co = sqrt(max(0, num / den)); if large == sweep { co = -co }
        let cx1 = co * rx * y1 / ry, cy1 = -co * ry * x1 / rx
        let cx = cp * cx1 - sp * cy1 + (a.x + b.x) / 2, cy = sp * cx1 + cp * cy1 + (a.y + b.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let d = atan2(ux * vy - uy * vx, ux * vx + uy * vy); return d
        }
        let t1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var dt = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let n = Int(ceil(abs(dt) / (.pi / 2)))
        let step = dt / CGFloat(n)
        let k = 4.0 / 3.0 * tan(step / 4)
        var t = t1
        for _ in 0..<n {
            let c1 = cos(t), s1 = sin(t), c2 = cos(t + step), s2 = sin(t + step)
            func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + cp * rx * x - sp * ry * y, y: cy + sp * rx * x + cp * ry * y) }
            p.addCurve(to: map(c2, s2), control1: map(c1 - k * s1, s1 + k * c1), control2: map(c2 + k * s2, s2 - k * c2))
            t += step
        }
    }
}

private func parseColor(_ s: String, _ current: Color) -> Color? {
    if s == "none" { return nil }
    if s == "currentColor" { return current }
    if s.hasPrefix("#") {
        var h = String(s.dropFirst())
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        return Color(argb: 0xFF000000 | (UInt32(h, radix: 16) ?? 0))
    }
    if s == "white" { return .white }
    return current
}

/// Draws a prototype icon (stroke style: round caps and joins, no fill) into a box.
func drawIcon(_ ctx: GraphicsContext, _ name: String, _ color: Color, _ strokeWidth: CGFloat, _ box: CGSize) {
    guard let def = ICONS[name] else { return }
    let k = min(box.width / def.w, box.height / def.h)
    var c = ctx
    c.scaleBy(x: k, y: k)
    for part in def.parts {
        let path = SVGPath.path(part.d)
        var cc = c
        cc.opacity = part.opacity ?? 1
        // as in the sprite's CSS: no fill unless a shape sets one; every shape is stroked in the current colour unless it says otherwise
        if let f = part.fill, let fc = parseColor(f, color) { cc.fill(path, with: .color(fc)) }
        let sc = part.stroke.map { parseColor($0, color) } ?? color
        if let sc { cc.stroke(path, with: .color(sc), style: StrokeStyle(lineWidth: part.strokeWidth ?? strokeWidth, lineCap: .round, lineJoin: .round)) }
    }
}

/// A prototype icon by name.
struct MIcon: View {
    let name: String
    let color: Color
    var size: CGFloat = 22
    var stroke: CGFloat = 2
    init(_ name: String, _ color: Color, _ size: CGFloat = 22, _ stroke: CGFloat = 2) { self.name = name; self.color = color; self.size = size; self.stroke = stroke }
    var body: some View {
        Canvas { ctx, sz in drawIcon(ctx, name, color, stroke, sz) }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// An icon from raw SVG path data in a 24 × 24 box (for the few drawings that are not in the sprite).
struct PathIcon: View {
    let d: String
    let color: Color
    var size: CGFloat = 22
    var stroke: CGFloat = 2
    var viewBox: CGFloat = 24
    init(_ d: String, _ color: Color, _ size: CGFloat = 22, _ stroke: CGFloat = 2, viewBox: CGFloat = 24) { self.d = d; self.color = color; self.size = size; self.stroke = stroke; self.viewBox = viewBox }
    var body: some View {
        Canvas { ctx, sz in
            var c = ctx; let k = min(sz.width, sz.height) / viewBox; c.scaleBy(x: k, y: k)
            c.stroke(SVGPath.path(d), with: .color(color), style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}
