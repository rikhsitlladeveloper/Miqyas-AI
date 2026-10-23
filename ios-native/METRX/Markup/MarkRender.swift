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

/// A photo's dimensions get letters in the order they were drawn (A, B, C …), shown on their pills.
func mkLetters(_ it: Item) -> [String: String] {
    var r: [String: String] = [:]
    for (i, e) in it.els.filter({ $0.t == "dim" }).enumerated() { r[e.id] = i < 26 ? String(Character(UnicodeScalar(UInt8(65 + i)))) : "A\(i - 25)" }
    return r
}

/// A line's or dimension's value pill (prototype: width txt.length × 21 + 38, height 56, rounded 28), with room for its
/// letter. While the editor is zoomed in by zoom, pills and lines keep their size on the screen.
func mkPill(_ e: MkEl, _ f: MkFmt, zoom: CGFloat = 1, letter: String? = nil) -> CGRect {
    let a = pt(e.pts[0]), b = pt(e.pts.count > 1 ? e.pts[1] : e.pts[0])
    let dx = b.x - a.x, dy = b.y - a.y, l0 = hypot(dx, dy), l = l0 > 0 ? l0 : 1
    let nx = -dy / l, ny = dx / l
    let txt = dimText(e, f)
    let tw: CGFloat = ((e.v != nil ? CGFloat(txt.count) * 21 + 38 : 64) + (letter.map { CGFloat($0.count) * 21 + 21 } ?? 0)) / zoom
    let th: CGFloat = 56 / zoom
    let off: CGFloat = (e.t == "line" ? 42 : 0) / zoom, sg: CGFloat = ny > 0 ? -1 : 1
    let mx = (a.x + b.x) / 2 + nx * off * sg, my = (a.y + b.y) / 2 + ny * off * sg
    return CGRect(x: mx - tw / 2, y: my - th / 2, width: tw, height: th)
}

/// The mark whose value pill or text is at q (item units), for opening it with a tap.
func mkLabelAt(_ it: Item, _ q: CGPoint, _ f: MkFmt, zoom: CGFloat = 1) -> MkEl? {
    let letters = mkLetters(it)
    return it.els.last { e in
        switch e.t {
        case "text": let p = pt(e.pts[0]); return abs(q.x - p.x) < max(70, CGFloat(e.txt?.count ?? 0) * 15) && abs(q.y - p.y) < 40
        case "line", "dim": return mkPill(e, f, zoom: zoom, letter: letters[e.id]).insetBy(dx: -8 / zoom, dy: -8 / zoom).contains(q)
        default: return false
        }
    }
}

/// The end of a line, dimension or arrow within tol of q (item units): the mark and which end (0 or 1).
func mkEndAt(_ it: Item, _ q: CGPoint, _ tol: CGFloat) -> (MkEl, Int)? {
    var best: (MkEl, Int)? = nil, bd = tol
    for e in it.els where e.t == "line" || e.t == "dim" || e.t == "arrow" {
        for (i, p) in e.pts.enumerated() { let d = hypot(q.x - pt(p).x, q.y - pt(p).y); if d <= bd { bd = d; best = (e, i) } }
    }
    return best
}

/* ---------- zoom and the loupe (photo edge measuring, part 1) ---------- */

let MK_ZOOM_MAX: CGFloat = 4

/// The editor's photo box at zoom z (1–4) moved by pan: the whole-photo box scaled about the view's centre.
func mkZoomBox(_ box: CGRect, _ z: CGFloat, _ pan: CGPoint) -> CGRect {
    CGRect(x: box.midX - box.width * z / 2 + pan.x, y: box.midY - box.height * z / 2 + pan.y, width: box.width * z, height: box.height * z)
}

/// pan limited so the zoomed photo never shows a gap where it could fill the view.
func mkClampPan(_ it: Item, _ box: CGRect, _ z: CGFloat, _ pan: CGPoint) -> CGPoint {
    let k = mkFit(mkViewBox(it, .edit), box).0
    let mx = max(0, (CGFloat(it.W) * k * z - box.width) / 2), my = max(0, (CGFloat(it.hh) * k * z - box.height) / 2)
    return CGPoint(x: min(max(pan.x, -mx), mx), y: min(max(pan.y, -my), my))
}

/// Zoom and pan after a pinch step: zoomBy about centroid plus the fingers' move; the new zoom and pan.
func mkPinch(_ it: Item, _ box: CGRect, _ z: CGFloat, _ pan: CGPoint, _ zoomBy: CGFloat, _ centroid: CGPoint, _ move: CGPoint) -> (CGFloat, CGPoint) {
    let nz = min(max(z * zoomBy, 1), MK_ZOOM_MAX)
    let c = CGPoint(x: centroid.x - box.midX, y: centroid.y - box.midY)
    // the photo point under the fingers stays under them
    let np = CGPoint(x: c.x + move.x - (c.x - pan.x) * (nz / z), y: c.y + move.y - (c.y - pan.y) * (nz / z))
    return (nz, mkClampPan(it, box, nz, np))
}

/// Where the loupe's centre goes for a finger at s in a view of size: above the finger, or below it near the top.
func mkLoupeAt(_ s: CGPoint, _ size: CGSize, _ r: CGFloat, _ gap: CGFloat) -> CGPoint {
    let y = s.y - gap - 2 * r < 0 ? s.y + gap + r : s.y - gap - r
    return CGPoint(x: min(max(s.x, r), max(r, size.width - r)), y: y)
}

/// The photo box that shows the point at s of view in the loupe centred at l, mag times larger.
func mkLoupeBox(_ view: CGRect, _ s: CGPoint, _ l: CGPoint, _ mag: CGFloat) -> CGRect {
    CGRect(x: l.x + (view.minX - s.x) * mag, y: l.y + (view.minY - s.y) * mag, width: view.width * mag, height: view.height * mag)
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

/// One mark, in item units (prototype mkElSVG); lines, arrows and pills are drawn zoom times thinner while zoomed.
func drawMark(_ ctx: GraphicsContext, _ e: MkEl, _ f: MkFmt, alpha: Double = 1, zoom z: CGFloat = 1, letter: String? = nil) {
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
        // a long label wraps to stay inside the picture (1000 units wide), centred where it was put
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let room: CGFloat = min(980, max(300, 2 * min(p.x, 1000 - p.x) - 20))
        let outline = NSAttributedString(string: s, attributes: [.font: font, .strokeColor: UIColor.white.withAlphaComponent(alpha), .strokeWidth: 22, .paragraphStyle: para])
        let fill = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: UIColor(c), .paragraphStyle: para])
        let one = outline.size()
        let box = one.width + 4 <= room ? one : outline.boundingRect(with: CGSize(width: room, height: .greatestFiniteMagnitude),
                                                                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
        let w = min(room, ceil(box.width) + 4)
        // the centre moves in as well, so a label near an edge stays whole in the picture
        let hw = w / 2
        let cx: CGFloat = hw * 2 >= 980 ? 500 : min(max(p.x, 10 + hw), 990 - hw)
        let r = CGRect(x: cx - hw, y: p.y - ceil(box.height) / 2, width: w, height: ceil(box.height))
        drawText(ctx, outline, r); drawText(ctx, fill, r)
    case "arrow":
        guard e.pts.count > 1 else { return }
        let a = pt(e.pts[0]), b = pt(e.pts[1]), dx = b.x - a.x, dy = b.y - a.y, l0 = hypot(dx, dy), l = l0 > 0 ? l0 : 1
        let ux = dx / l, uy = dy / l, nx = -uy, ny = ux, s: CGFloat = 34 / z, hx = b.x - ux * s, hy = b.y - uy * s, hw: CGFloat = 16 / z
        ctx.stroke(linePath(a, CGPoint(x: hx, y: hy)), with: .color(c), style: StrokeStyle(lineWidth: 8 / z, lineCap: .round))
        let head = polyPath([b, CGPoint(x: hx + nx * hw, y: hy + ny * hw), CGPoint(x: hx - nx * hw, y: hy - ny * hw)])
        ctx.fill(head, with: .color(c)); ctx.stroke(head, with: .color(c), style: StrokeStyle(lineWidth: 4 / z, lineJoin: .round))
    default:
        // line (drawing) and dim (photo): a dimension line with end marks and a value pill
        guard e.pts.count > 1 else { return }
        let a = pt(e.pts[0]), b = pt(e.pts[1]), dx = b.x - a.x, dy = b.y - a.y, l0 = hypot(dx, dy), l = l0 > 0 ? l0 : 1
        let ux = dx / l, uy = dy / l, nx = -uy, ny = ux
        let tk = e.t == "dim" ? CGPoint(x: nx * 20 / z, y: ny * 20 / z) : CGPoint(x: (ux + nx) * 13 / z, y: (uy + ny) * 13 / z)
        var p = Path()
        p.move(to: a); p.addLine(to: b)
        for q in [a, b] { p.move(to: q - tk); p.addLine(to: q + tk) }
        if e.t == "dim" { ctx.stroke(p, with: .color(Color.white.opacity(0.85 * alpha)), style: StrokeStyle(lineWidth: 13 / z, lineCap: .round)) }
        ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: (e.t == "dim" ? 7 : 9) / z, lineCap: .round))
        let has = e.v != nil, r = mkPill(e, f, zoom: z, letter: letter)
        let pill = Path(roundedRect: r, cornerRadius: 28 / z)
        ctx.fill(pill, with: .color((has ? Color.white : PILL_WAIT).opacity(alpha)))
        ctx.stroke(pill, with: .color(has ? c : PILL_WAIT_INK.opacity(alpha)), style: StrokeStyle(lineWidth: 3 / z, dash: has ? [] : [7 / z, 5 / z]))
        let font = UIFont(name: "IBMPlexSansCond-SemiBold", size: 36 / z) ?? .systemFont(ofSize: 36 / z, weight: .semibold)
        let t = NSAttributedString(string: dimText(e, f), attributes: [.font: font, .foregroundColor: UIColor(has ? MK_COL["ink"]! : PILL_WAIT_INK).withAlphaComponent(alpha)])
        // the letter in the line's colour, then the value
        let lf = UIFont(name: "IBMPlexSansCond-Bold", size: 36 / z) ?? .systemFont(ofSize: 36 / z, weight: .bold)
        let lt = letter.map { NSAttributedString(string: $0, attributes: [.font: lf, .foregroundColor: UIColor(c)]) }
        let sz = t.size(), lsz = lt?.size() ?? .zero, gap: CGFloat = lt != nil ? 12 / z : 0
        let x0 = r.midX - (lsz.width + gap + sz.width) / 2
        if let lt { drawText(ctx, lt, CGRect(x: x0, y: r.midY + 1 / z - lsz.height / 2, width: lsz.width + 2, height: lsz.height)) }
        drawText(ctx, t, CGRect(x: x0 + lsz.width + gap, y: r.midY + 1 / z - sz.height / 2, width: sz.width + 2, height: sz.height))
    }
}

/// The item fitted into box: the photo (or the white sheet, dotted while editing), then its marks. faded marks are shown
/// faint (the eraser's touch before it lets go); live draws the mark being made, in item units.
func drawMarkup(_ ctx: GraphicsContext, _ it: Item, _ photo: UIImage?, _ box: CGRect, _ f: MkFmt, _ mode: MkMode, slice: Bool = false,
                faded: Set<String> = [], hidden: Set<String> = [], zoom: CGFloat = 1,
                under: ((GraphicsContext) -> Void)? = nil, live: ((GraphicsContext) -> Void)? = nil) {
    let letters = mkLetters(it)
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
    under?(c)   // the photo's edges, between the picture and the marks
    for e in it.els where !hidden.contains(e.id) { drawMark(c, e, f, alpha: faded.contains(e.id) ? 0.15 : 1, zoom: zoom, letter: letters[e.id]) }
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
