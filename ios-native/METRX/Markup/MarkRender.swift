import SwiftUI
import UIKit

/*
 * Drawings and photos with their marks (prototype workspace.js mkElSVG / mkSVG; Android ui/markup/MarkRender.kt): one
 * renderer for the markup editor, the workspace cards, the Measure page's pictures and the report. Everything is drawn
 * in the item's own units (1000 wide) and fitted into the box it is given.
 */

let MK_COL: [String: Color] = ["ink": Color(argb: 0xFF0E1C36), "cobalt": Color(argb: 0xFF1C4BD1), "red": Color(argb: 0xFFD92D20)]
let MK_TOOLS: [String: [String]] = ["drawing": ["pen", "line", "text", "eraser"], "photo": ["dim", "arrow", "text", "pen", "eraser"]]
private let PILL_WAIT = Color(argb: 0xFFFFF1DF)
private let PILL_WAIT_INK = Color(argb: 0xFF9A4D00)
private let DOT = Color(argb: 0xFFC9D1DE)

enum MkMode { case edit, thumb, report }

/// What a mark needs to say its length: the unit, its name in the language and the number format.
struct MkFmt {
    let unit: LenUnit, en: Bool, m: String, lang: Lang
    static func current(_ l: Lang = AppSettings.shared.lang) -> MkFmt {
        MkFmt(unit: AppSettings.shared.unit, en: l == .en, m: Strings.t(AppSettings.shared.unit == .cm ? "u.cm" : "u.m", l), lang: l)
    }
}

private func pt(_ p: [Double]) -> CGPoint { CGPoint(x: p.count > 0 ? p[0] : 0, y: p.count > 1 ? p[1] : 0) }

/// The area of a drawing that has marks, with a margin (prototype mkBBox), or nil when it has none.
func mkBBox(_ it: Item) -> CGRect? {
    var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
    for e in it.els { for q in e.pts where q.count > 1 { x0 = min(x0, q[0]); y0 = min(y0, q[1]); x1 = max(x1, q[0]); y1 = max(y1, q[1]) } }
    if x0 > x1 { return nil }
    let pad = 70.0
    x0 -= pad; y0 -= pad; x1 += pad; y1 += pad
    let w = max(x1 - x0, 420), h = max(y1 - y0, 315), cx = (x0 + x1) / 2, cy = (y0 + y1) / 2
    return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
}

/// The part of the item shown: all of it, or for a drawing's card and report figure the part with marks.
func mkViewBox(_ it: Item, _ mode: MkMode) -> CGRect {
    if it.kind == "drawing" && mode != .edit, let b = mkBBox(it) { return b }
    return CGRect(x: 0, y: 0, width: CGFloat(it.W), height: CGFloat(it.hh))
}

/// Where the item's view box lands in box: the scale and the top-left offset ("meet", or "slice" to fill).
func mkFit(_ vb: CGRect, _ box: CGRect, slice: Bool = false) -> (CGFloat, CGFloat, CGFloat) {
    let k = slice ? max(box.width / vb.width, box.height / vb.height) : min(box.width / vb.width, box.height / vb.height)
    return (k, box.minX + (box.width - vb.width * k) / 2 - vb.minX * k, box.minY + (box.height - vb.height * k) / 2 - vb.minY * k)
}

private func dimText(_ e: MkEl, _ f: MkFmt) -> String { e.v.map { Geo.fmtLen($0, f.unit, f.en) + " " + f.m } ?? "?" }

/// A line's or dimension's value pill (prototype: width txt.length × 21 + 38, height 56, rounded 28).
func mkPill(_ e: MkEl, _ f: MkFmt) -> CGRect {
    let a = pt(e.pts[0]), b = pt(e.pts.count > 1 ? e.pts[1] : e.pts[0])
    let dx = b.x - a.x, dy = b.y - a.y, l0 = hypot(dx, dy), l = l0 > 0 ? l0 : 1
    let nx = -dy / l, ny = dx / l
    let txt = dimText(e, f)
    let tw: CGFloat = e.v != nil ? CGFloat(txt.count) * 21 + 38 : 64, th: CGFloat = 56
    let off: CGFloat = e.t == "line" ? 42 : 0, sg: CGFloat = ny > 0 ? -1 : 1
    let mx = (a.x + b.x) / 2 + nx * off * sg, my = (a.y + b.y) / 2 + ny * off * sg
    return CGRect(x: mx - tw / 2, y: my - th / 2, width: tw, height: th)
}

/// The mark whose value pill or text is at q (item units), for opening it with a tap.
func mkLabelAt(_ it: Item, _ q: CGPoint, _ f: MkFmt) -> MkEl? {
    it.els.last { e in
        switch e.t {
        case "text": let p = pt(e.pts[0]); return abs(q.x - p.x) < max(70, CGFloat(e.txt?.count ?? 0) * 15) && abs(q.y - p.y) < 40
        case "line", "dim": return mkPill(e, f).insetBy(dx: -8, dy: -8).contains(q)
        default: return false
        }
    }
}

private func segD(_ q: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y, l2 = dx * dx + dy * dy
    let s = l2 > 0 ? min(max(((q.x - a.x) * dx + (q.y - a.y) * dy) / l2, 0), 1) : 0
    return hypot(q.x - a.x - s * dx, q.y - a.y - s * dy)
}

/// Whether the eraser at q touches e (prototype near).
func mkNear(_ e: MkEl, _ q: CGPoint) -> Bool {
    if e.t == "text" { return hypot(q.x - pt(e.pts[0]).x, q.y - pt(e.pts[0]).y) < 70 }
    let ps = e.pts.count > 1 ? e.pts.map(pt) : [pt(e.pts[0]), pt(e.pts[0])]
    for i in 1..<ps.count where segD(q, ps[i - 1], ps[i]) < 26 { return true }
    return false
}

func mkPolyPath(_ pts: [CGPoint]) -> Path {
    var p = Path()
    let ps = pts.count > 1 ? pts : [pts[0], CGPoint(x: pts[0].x + 0.1, y: pts[0].y)]
    p.move(to: ps[0]); for q in ps.dropFirst() { p.addLine(to: q) }
    return p
}

private func face(_ l: Lang, _ w: Int) -> String {
    let names = [400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold", 800: "ExtraBold"]
    return (l.cyrillic ? "Manrope-" : "PlusJakartaSans-") + names[w]!
}

/// One mark, in item units (prototype mkElSVG).
func drawMark(_ ctx: GraphicsContext, _ e: MkEl, _ f: MkFmt, alpha: Double = 1) {
    let c = (MK_COL[e.c] ?? MK_COL["ink"]!).opacity(alpha)
    guard !e.pts.isEmpty else { return }
    switch e.t {
    case "pen":
        ctx.stroke(mkPolyPath(e.pts.map(pt)), with: .color(c), style: StrokeStyle(lineWidth: e.w == 2 ? 18 : 8, lineCap: .round, lineJoin: .round))
    case "text":
        // white outline under the letters, then the letters (prototype paint-order stroke)
        let s = dn(e.txt ?? "", f.lang)
        let font = UIFont(name: face(f.lang, 600), size: 50) ?? .systemFont(ofSize: 50, weight: .semibold)
        let p = pt(e.pts[0])
        let outline = NSAttributedString(string: s, attributes: [.font: font, .strokeColor: UIColor.white.withAlphaComponent(alpha), .strokeWidth: 22])
        let fill = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: UIColor(c)])
        let sz = outline.size()
        let r = CGRect(x: p.x - sz.width / 2, y: p.y - sz.height / 2, width: sz.width + 4, height: sz.height)
        drawText(ctx, outline, r); drawText(ctx, fill, r)
    case "arrow":
        guard e.pts.count > 1 else { return }
        let a = pt(e.pts[0]), b = pt(e.pts[1]), dx = b.x - a.x, dy = b.y - a.y, l0 = hypot(dx, dy), l = l0 > 0 ? l0 : 1
        let ux = dx / l, uy = dy / l, nx = -uy, ny = ux, s: CGFloat = 34, hx = b.x - ux * s, hy = b.y - uy * s
        ctx.stroke(linePath(a, CGPoint(x: hx, y: hy)), with: .color(c), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        let head = polyPath([b, CGPoint(x: hx + nx * 16, y: hy + ny * 16), CGPoint(x: hx - nx * 16, y: hy - ny * 16)])
        ctx.fill(head, with: .color(c)); ctx.stroke(head, with: .color(c), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
    default:
        // line (drawing) and dim (photo): a dimension line with end marks and a value pill
        guard e.pts.count > 1 else { return }
        let a = pt(e.pts[0]), b = pt(e.pts[1]), dx = b.x - a.x, dy = b.y - a.y, l0 = hypot(dx, dy), l = l0 > 0 ? l0 : 1
        let ux = dx / l, uy = dy / l, nx = -uy, ny = ux
        let tk = e.t == "dim" ? CGPoint(x: nx * 20, y: ny * 20) : CGPoint(x: (ux + nx) * 13, y: (uy + ny) * 13)
        var p = Path()
        p.move(to: a); p.addLine(to: b)
        for q in [a, b] { p.move(to: q - tk); p.addLine(to: q + tk) }
        if e.t == "dim" { ctx.stroke(p, with: .color(Color.white.opacity(0.85 * alpha)), style: StrokeStyle(lineWidth: 13, lineCap: .round)) }
        ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: e.t == "dim" ? 7 : 9, lineCap: .round))
        let has = e.v != nil, r = mkPill(e, f)
        let pill = Path(roundedRect: r, cornerRadius: 28)
        ctx.fill(pill, with: .color((has ? Color.white : PILL_WAIT).opacity(alpha)))
        ctx.stroke(pill, with: .color(has ? c : PILL_WAIT_INK.opacity(alpha)), style: StrokeStyle(lineWidth: 3, dash: has ? [] : [7, 5]))
        let font = UIFont(name: "IBMPlexSansCond-SemiBold", size: 36) ?? .systemFont(ofSize: 36, weight: .semibold)
        let t = NSAttributedString(string: dimText(e, f), attributes: [.font: font, .foregroundColor: UIColor(has ? MK_COL["ink"]! : PILL_WAIT_INK).withAlphaComponent(alpha)])
        let sz = t.size()
        drawText(ctx, t, CGRect(x: r.midX - sz.width / 2, y: r.midY + 1 - sz.height / 2, width: sz.width + 2, height: sz.height))
    }
}

/// The item fitted into box: the photo (or the white sheet, dotted while editing), then its marks. faded marks are shown
/// faint (the eraser's touch before it lets go); live draws the mark being made, in item units.
func drawMarkup(_ ctx: GraphicsContext, _ it: Item, _ photo: UIImage?, _ box: CGRect, _ f: MkFmt, _ mode: MkMode, slice: Bool = false,
                faded: Set<String> = [], live: ((GraphicsContext) -> Void)? = nil) {
    let vb = mkViewBox(it, mode)
    let (k, ox, oy) = mkFit(vb, box, slice: slice)
    var c = ctx
    c.clip(to: Path(box))
    c.translateBy(x: ox, y: oy); c.scaleBy(x: k, y: k)
    let full = CGRect(x: 0, y: 0, width: CGFloat(it.W), height: CGFloat(it.hh))
    if it.kind == "photo" {
        if let photo { c.draw(Image(uiImage: photo), in: full) } else { c.fill(Path(full), with: .color(Color(argb: 0xFF161D30))) }
    } else {
        c.fill(Path(vb), with: .color(.white))
        if mode == .edit {
            var y: CGFloat = 25
            while y < CGFloat(it.hh) {
                var x: CGFloat = 25
                while x < CGFloat(it.W) { c.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)), with: .color(DOT)); x += 50 }
                y += 50
            }
        }
    }
    for e in it.els { drawMark(c, e, f, alpha: faded.contains(e.id) ? 0.15 : 1) }
    live?(c)
}

/// Screen point → item units for an item shown whole in box (the editor).
func mkToItem(_ it: Item, _ box: CGRect, _ p: CGPoint) -> CGPoint {
    let (k, ox, oy) = mkFit(mkViewBox(it, .edit), box)
    return CGPoint(x: (p.x - ox) / k, y: (p.y - oy) / k)
}

/// A drawing's or photo's picture for a card or the Measure page's strip (slice: fill the box, cropping).
struct MarkThumb: View {
    let it: Item
    var slice = false
    @State private var photo: UIImage? = nil
    var body: some View {
        Canvas { ctx, size in drawMarkup(ctx, it, photo, CGRect(origin: .zero, size: size), MkFmt.current(), .thumb, slice: slice) }
            .task(id: it.src) {
                guard let src = it.src else { photo = nil; return }
                photo = await Task.detached { PhotoFiles.load(src, maxW: 480) }.value
            }
            .accessibilityHidden(true)
    }
}
