import SwiftUI
import UIKit

/*
 * The report's A4 pages (prototype reportPages0, the .a4 styles and the workspace module's extra pages; Android
 * report/Pages.kt), laid out in CSS pixels of a 595 × 842 page. Each page is a list of drawing steps on a
 * GraphicsContext, so one drawing serves the preview (a picture) and the PDF (vector, one point per pixel). Text is
 * measured and drawn by the same engine (TextKit), so what was measured is what is drawn. Where the prototype would run
 * off the bottom of a page, the content continues on a new page with the same header (and the table's heading row).
 */

let PAGE_W: CGFloat = 595
let PAGE_H: CGFloat = 842
let PX: CGFloat = 38
let PY: CGFloat = 36
let CW = PAGE_W - 2 * PX
let LIMIT = PAGE_H - PY - 6

private let INK = UIColor(red: 0x0E / 255, green: 0x1C / 255, blue: 0x36 / 255, alpha: 1)
private let INK3 = UIColor(red: 0x3E / 255, green: 0x4A / 255, blue: 0x61 / 255, alpha: 1)
private let GREY = UIColor(red: 0x5F / 255, green: 0x6B / 255, blue: 0x82 / 255, alpha: 1)
private let PROV = UIColor(red: 0x9A / 255, green: 0x4D / 255, blue: 0x00 / 255, alpha: 1)
private let WMK = UIColor(red: 0x1C / 255, green: 0x4B / 255, blue: 0xD1 / 255, alpha: 0x12 / 255)
private let RULE = Color(argb: 0xFF9AA8BF)
private let TH_BG = Color(argb: 0xFFF3F6FA)
private let FIG = Color(argb: 0xFFC3CEDF)
private let NOTE_RULE = Color(argb: 0xFFDCE4F0)
private let LOGO = Color(argb: 0xFF374FDD)
private let NBSP = "\u{00A0}"

typealias DrawStep = (GraphicsContext) -> Void

/// One page: its drawing in page pixels.
struct RPage { let steps: [DrawStep]; func draw(_ ctx: GraphicsContext) { for s in steps { s(ctx) } } }

/// For an issued quote: its number and when it was issued.
struct QuoteMeta { let no: Int; let ts: Ms }

/// Draws attributed text into rect with UIKit, inside a SwiftUI drawing.
func drawText(_ ctx: GraphicsContext, _ s: NSAttributedString, _ rect: CGRect) {
    ctx.withCGContext { cg in
        UIGraphicsPushContext(cg)
        s.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        UIGraphicsPopContext()
    }
}

/// A text style of the page: the face (report language), size, weight, colour, italic, alignment.
struct Sty {
    var font: UIFont
    var color: UIColor = INK
    var italic = false
    var align: NSTextAlignment = .left
    var tracking: CGFloat = 0
    var lineHeight: CGFloat
}

final class Cell {
    let paras: [NSAttributedString]
    let span: Int, right: Bool, th: Bool, dbl: Bool
    init(_ paras: [NSAttributedString], span: Int = 1, right: Bool = false, th: Bool = false, dbl: Bool = false) {
        self.paras = paras; self.span = span; self.right = right; self.th = th; self.dbl = dbl
    }
}

/// The report's layout engine; the furniture documents (FurniturePages.swift) use it too.
final class Doc {
    let sn: Snap, draft: Bool, meta: QuoteMeta?, image: (String) -> UIImage?, now: Ms
    let l: Lang, en: Bool, unit: LenUnit
    var pages: [[DrawStep]] = []
    var y: CGFloat = 0
    var pend: CGFloat = 0
    /// Furniture documents: another title for the draft and the issued one, and a line under it instead of the date.
    var draftTitle = "r.draft", quoteTitle = "r.quote"
    var subLine: String? = nil
    /// Furniture orders name the maker's side "Ustaxona".
    var makerKey = "rpt.builder"

    init(_ sn: Snap, _ draft: Bool, _ meta: QuoteMeta?, _ image: @escaping (String) -> UIImage?, _ now: Ms) {
        self.sn = sn; self.draft = draft; self.meta = meta; self.image = image; self.now = now
        l = Lang.of(sn.lang); en = l == .en; unit = sn.unit == "cm" ? .cm : .m
    }

    func t(_ k: String, _ v: [String: Any]? = nil) -> String { Strings.t(k, l, v) }
    func mUnit() -> String { t(unit == .cm ? "u.cm" : "u.m") }
    func len(_ mm: Int?) -> String { Geo.fmtLen(mm, unit, en) }
    func money(_ v: Decimal) -> String { Money.str(v, sn.precision, en).replacingOccurrences(of: " ", with: NBSP) }

    /* ---------- text ---------- */

    /// The report's faces follow the report's language (Manrope for Cyrillic), numbers IBM Plex Sans Condensed.
    private func face(_ weight: Int, num: Bool) -> String {
        let w = max(400, min(800, weight / 100 * 100))
        let names = [400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold", 800: "ExtraBold"]
        if num { return "IBMPlexSansCond-" + names[min(w, 700)]! }
        return (l.cyrillic ? "Manrope-" : "PlusJakartaSans-") + names[w]!
    }
    func ui(_ size: CGFloat, _ weight: Int = 400, _ color: UIColor = INK, italic: Bool = false, align: NSTextAlignment = .left) -> Sty {
        Sty(font: UIFont(name: face(weight, num: false), size: size) ?? .systemFont(ofSize: size), color: color, italic: italic, align: align, lineHeight: size * 1.35)
    }
    func num(_ size: CGFloat, _ weight: Int = 400, align: NSTextAlignment = .left) -> Sty {
        Sty(font: UIFont(name: face(weight, num: true), size: size) ?? .systemFont(ofSize: size), align: align, lineHeight: size * 1.35)
    }

    func attrs(_ st: Sty, align: NSTextAlignment? = nil) -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.minimumLineHeight = st.lineHeight; ps.maximumLineHeight = st.lineHeight
        ps.alignment = align ?? st.align
        ps.lineBreakMode = .byWordWrapping
        var a: [NSAttributedString.Key: Any] = [.font: st.font, .foregroundColor: st.color, .paragraphStyle: ps,
                                                .baselineOffset: (st.lineHeight - st.font.lineHeight) / 4]
        if st.italic { a[.obliqueness] = 0.18 }
        if st.tracking != 0 { a[.kern] = st.tracking }
        return a
    }
    func a(_ s: String, _ st: Sty) -> NSAttributedString { NSAttributedString(string: s, attributes: attrs(st)) }

    /// The same text set to another alignment (a cell's right-aligned numbers).
    func aligned(_ s: NSAttributedString, _ al: NSTextAlignment) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: s)
        m.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: m.length)) { v, r, _ in
            let ps = ((v as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            ps.alignment = al
            m.addAttribute(.paragraphStyle, value: ps, range: r)
        }
        return m
    }

    func measure(_ s: NSAttributedString, _ w: CGFloat? = nil) -> CGSize {
        let r = s.boundingRect(with: CGSize(width: w ?? 10_000, height: 100_000), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return CGSize(width: ceil(r.width), height: ceil(r.height))
    }

    func draw(_ step: @escaping DrawStep) { pages[pages.count - 1].append(step) }
    func text(_ s: NSAttributedString, _ rect: CGRect) { draw { drawText($0, s, rect) } }

    /// Vertical margins collapse as in CSS: the larger of the previous bottom and this top.
    func space(_ top: CGFloat) { y += max(pend, top); pend = 0 }
    func after(_ bottom: CGFloat) { pend = bottom }
    func fits(_ h: CGFloat) -> Bool { y + max(pend, 0) + h <= LIMIT }

    /// A new page with the header (prototype .rh): the mark and METRX on the left, title and date on the right.
    func newPage() {
        pages.append([])
        let title = a(t(draft ? draftTitle : quoteTitle), ui(18, 600))
        let date = a(subLine ?? (draft ? t("r.draftDate", ["d": fmtDate(now)]) : t("r.no", ["n": meta!.no, "d": fmtDate(meta!.ts)])), ui(10, 400, INK3))
        var wst = num(14, 700); wst.tracking = 14 * 0.14; wst.lineHeight = 18.2
        let wm = a("METRX", wst)
        let h1 = measure(title), sm = measure(date), wmS = measure(wm)
        let rh = max(18.2, h1.height + sm.height)
        draw { ctx in
            ctx.fill(Path(roundedRect: CGRect(x: PX, y: PY, width: 18, height: 18), cornerRadius: 18 * 15 / 64), with: .color(LOGO))
            drawLogoMark(ctx, tile: LOGO, box: 18, origin: CGPoint(x: PX, y: PY))
        }
        text(wm, CGRect(x: PX + 24, y: PY + (18 - wmS.height) / 2, width: wmS.width + 2, height: wmS.height))
        text(title, CGRect(x: PX + CW - h1.width, y: PY, width: h1.width + 1, height: h1.height))
        text(date, CGRect(x: PX + CW - sm.width, y: PY + h1.height, width: sm.width + 1, height: sm.height))
        draw { $0.line(Color(uiColor: INK), CGPoint(x: PX, y: PY + rh + 8.75), CGPoint(x: PX + CW, y: PY + rh + 8.75), 1.5) }
        y = PY + rh + 8 + 1.5; pend = 12
    }

    func ensure(_ h: CGFloat) { if !fits(h) { newPage() } }

    func h2(_ s: String) {
        let r = a(s, ui(12, 600)), sz = measure(r, CW)
        space(12); let top = y; text(r, CGRect(x: PX, y: top, width: CW, height: sz.height)); y += sz.height; after(4)
    }

    func para(_ s: NSAttributedString, top: CGFloat, bottom: CGFloat, x: CGFloat = PX, w: CGFloat = CW) {
        let sz = measure(s, w)
        space(top); if y + sz.height > LIMIT { newPage(); space(top) }
        let at = y; text(s, CGRect(x: x, y: at, width: w, height: sz.height)); y += sz.height; after(bottom)
    }
    func fn(_ s: String) { para(a(s, ui(8.5, 400, INK3)), top: 4, bottom: 8.5) }

    /* ---------- tables (border-collapse, 0.75 px rules, cells padded 3 × 5, auto column widths as in a browser) ---------- */

    private func cellWidth(_ c: Cell) -> (CGFloat, CGFloat) {
        var mx: CGFloat = 0, mn: CGFloat = 0
        for s in c.paras {
            mx = max(mx, measure(s).width)
            let str = s.string as NSString
            var start = 0
            // the widest word, keeping its own styles
            for (i, ch) in (s.string + " ").utf16.enumerated() where ch == 32 || ch == 10 {
                if i > start { mn = max(mn, measure(s.attributedSubstring(from: NSRange(location: start, length: min(i, str.length) - start))).width) }
                start = i + 1
            }
        }
        return (mn + 10, mx + 10)
    }

    private func widths(_ rows: [[Cell]], _ w: CGFloat, _ fixed: [CGFloat]?) -> [CGFloat] {
        if let fixed { return fixed }
        let n = rows.map { $0.reduce(0) { $0 + $1.span } }.max() ?? 1
        var mn = [CGFloat](repeating: 0, count: n), mx = [CGFloat](repeating: 0, count: n)
        for r in rows {
            var c = 0
            for cell in r {
                if cell.span == 1 { let (a, b) = cellWidth(cell); mn[c] = max(mn[c], a); mx[c] = max(mx[c], b) }
                c += cell.span
            }
        }
        let sMax = mx.reduce(0, +), sMin = mn.reduce(0, +)
        return (0..<n).map { i in
            if sMax <= w { return sMax == 0 ? w / CGFloat(n) : mx[i] + (w - sMax) * mx[i] / sMax }
            if sMin >= w { return mn[i] }
            return mn[i] + (w - sMin) * (mx[i] - mn[i]) / max(1e-3, sMax - sMin)
        }
    }

    private func cellHeight(_ c: Cell, _ w: CGFloat) -> CGFloat {
        c.paras.reduce(0) { $0 + measure(c.right ? aligned($1, .right) : $1, w - 10).height } + 6
    }

    private func rowHeights(_ rows: [[Cell]], _ cw: [CGFloat]) -> [CGFloat] {
        rows.map { r in
            var c = 0
            return r.map { cell -> CGFloat in
                let w = cw[c..<(c + cell.span)].reduce(0, +); c += cell.span
                return cellHeight(cell, w)
            }.max() ?? 0
        }
    }

    /// A table at x across w; rows that would run off the page continue on the next one, after the head rows again.
    @discardableResult
    func table(_ rows: [[Cell]], x: CGFloat = PX, w: CGFloat = CW, fixed: [CGFloat]? = nil, head: Int = 0, top: CGFloat = 6, bottom: CGFloat = 10, breakable: Bool = true) -> CGFloat {
        let cw = widths(rows, w, fixed)
        let hs = rowHeights(rows, cw)
        space(top)
        let start = y
        for (i, r) in rows.enumerated() {
            if breakable && i >= head && y + hs[i] > LIMIT && y > PY + 60 {
                newPage(); space(top)
                for k in 0..<head { drawRow(rows[k], hs[k], cw, x) }
            }
            drawRow(r, hs[i], cw, x)
        }
        after(bottom)
        return y - start
    }

    func tableHeight(_ rows: [[Cell]], _ w: CGFloat) -> CGFloat { rowHeights(rows, widths(rows, w, nil)).reduce(0, +) }

    private func drawRow(_ r: [Cell], _ h: CGFloat, _ cw: [CGFloat], _ x0: CGFloat) {
        let top = y
        var x = x0, c = 0
        for cell in r {
            let w = cw[c..<(c + cell.span)].reduce(0, +); c += cell.span
            let paras = cell.paras.map { cell.right ? aligned($0, .right) : $0 }
            let hs = paras.map { measure($0, w - 10).height }
            let cx = x, th = cell.th, dbl = cell.dbl
            draw { ctx in
                let rect = CGRect(x: cx, y: top, width: w, height: h)
                if th { ctx.fill(Path(rect), with: .color(TH_BG)) }
                ctx.stroke(Path(rect), with: .color(RULE), lineWidth: 0.75)
                var ty = top + 3
                for (s, sh) in zip(paras, hs) { drawText(ctx, s, CGRect(x: cx + 5, y: ty, width: w - 10, height: sh)); ty += sh }
                if dbl {
                    ctx.line(Color(uiColor: INK), CGPoint(x: cx, y: top + h - 0.5), CGPoint(x: cx + w, y: top + h - 0.5), 1)
                    ctx.line(Color(uiColor: INK), CGPoint(x: cx, y: top + h + 1.5), CGPoint(x: cx + w, y: top + h + 1.5), 1)
                }
            }
            x += w
        }
        y += h
    }

    func cell(_ s: String, _ st: Sty? = nil, span: Int = 1) -> Cell { Cell([a(s, st ?? ui(10))], span: span) }
    func rcell(_ s: NSAttributedString) -> Cell { Cell([s], right: true) }
    func rcell(_ s: String, _ st: Sty? = nil) -> Cell { Cell([a(s, st ?? num(10))], right: true) }
    func th(_ s: String, right: Bool = false) -> Cell { Cell([a(s, ui(9, 600))], right: right, th: true) }

    /* ---------- the parts of the report ---------- */

    /// Builder and customer, then the project with its address and location (prototype .tb).
    func parties() {
        let lab = ui(8.5, 400, INK3), v = ui(10)
        func party(_ k: String, _ name: String, _ phone: String) -> Cell {
            let n = dn(name, l).trimmingCharacters(in: .whitespaces)
            return Cell([a(t(k), lab), a((n.isEmpty ? "—" : n) + "\n" + Phone.format(phone), v)])
        }
        let proj = NSMutableAttributedString(attributedString: a(dn(sn.name, l) + (sn.address.trimmingCharacters(in: .whitespaces).isEmpty ? "" : ", " + dn(sn.address, l)), v))
        if let loc = sn.location {
            proj.append(a("\n", v)); proj.append(a(t("pr.location") + ":", ui(8.5, 400, INK3)))
            proj.append(a(String(format: " %.5f, %.5f", loc.lat, loc.lng), v))
        }
        table([[party(makerKey, sn.builderName, sn.builderPhone), party("rpt.customer", sn.customer, sn.phone)],
               [Cell([a(t("r.project"), lab), proj], span: 2)]], fixed: [CW / 2, CW / 2], breakable: false)
    }

    private func provAttr(_ s: String) -> NSAttributedString { a(" (" + s + ")", ui(10, 400, PROV, italic: true)) }
    private func withProv(_ r: Room, _ k: String?, _ main: String) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: a(main, num(10)))
        if let k, r.dim(k).v == nil { m.append(provAttr(t("r.prov"))) }
        return m
    }

    private func roomRows(_ r: Room) -> [[Cell]] {
        var rows: [[Cell]] = []
        let m = mUnit()
        func v(_ mm: Int?, _ k: String?) -> NSAttributedString { withProv(r, k, (len(mm) + " " + m).replacingOccurrences(of: " ", with: NBSP)) }
        if r.isPoly {
            let g = Geo.polyGeo(r, sn.snap)
            for w in g.walls {
                let main = (len(w.len) + " " + m).replacingOccurrences(of: " ", with: NBSP)
                let s = NSMutableAttributedString(attributedString: a(main, num(10)))
                if w.derived || g.computed.contains(w.id) { s.append(provAttr(t("sk.calc"))) } else if r.dim(w.id).v == nil { s.append(provAttr(t("r.prov"))) }
                rows.append([cell(t("op.wall") + " " + w.id), rcell(s)])
            }
            for d in r.poly?.diags ?? [] { rows.append([cell(t("sk.diagName", ["d": d.id]) + ", \(d.a + 1)–\(d.b + 1)"), rcell(v(r.dim(d.id).v, d.id))]) }
        } else {
            rows.append([cell(t("r.len")), rcell(v(r.dim("A").v, "A"))])
            rows.append([cell(t("r.wid")), rcell(v(r.dim("B").v, "B"))])
        }
        rows.append([cell(t("r.h")), rcell(v(r.dim("H").v, "H"))])
        let ar = Geo.areas(r, sn.snap), m2 = t("u.m2")
        if let ar {
            rows.append([cell(t("rp.floorArea")), rcell(Geo.fmtArea(ar.floor, en) + NBSP + m2)])
            rows.append([cell(t("rp.perim")), rcell((len(Int(ar.perim)) + " " + m).replacingOccurrences(of: " ", with: NBSP))])
            if let net = ar.net {
                rows.append([cell(t("rp.gross")), rcell(Geo.fmtArea(ar.gross ?? 0, en) + NBSP + m2)])
                rows.append([cell(t("rp.openings")), rcell(Geo.fmtArea(ar.open ?? 0, en) + NBSP + m2)])
                rows.append([cell(t("rp.net"), ui(10, 700)), rcell(Geo.fmtArea(net, en) + NBSP + m2, num(10, 700))])
            }
        }
        for o in r.openings {
            // the line says "m": its sizes are in metres whatever the length unit
            let en = en
            let lm = { (mm: Int) in Geo.fmtLen(mm, .m, en) }
            rows.append([cell(t("r.op", ["o": t(o.type == "door" ? "op.door" : "op.window"), "w": o.wall, "wd": lm(o.w), "h": lm(o.h),
                                         "off": (o.offDrag ? "≈ " : "") + lm(o.off), "s": o.type == "window" ? t("r.sill", ["s": lm(o.sill)]) : ""]), span: 2)])
        }
        if ar?.net != nil, let H = r.dim("H").v, let ar {
            let vol = String(format: "%.2f", Double(ar.floor) * Double(H) / 1e9)
            rows.append([cell(t("ri.volume")), rcell((en ? vol : vol.replacingOccurrences(of: ".", with: ",")) + NBSP + t("u.m") + "³")])
        }
        return rows
    }

    /// "1. Mehmonxona, 1-qavat", the plan (270 px wide, framed) beside the measurements (prototype roomBlock).
    func roomBlock(_ r: Room, _ i: Int, _ floorLabel: String) {
        let pf = sn.pdf
        if !pf.plan && !pf.dims { return }
        let planH = pf.plan ? reportPlanHeight(r, snap: sn.snap) * 0.75 + 1.5 : 0
        let rows = pf.dims ? roomRows(r) : []
        let tx = pf.plan ? PX + 271.5 + 14 : PX, tw = PX + CW - tx
        // the block's height before drawing it, to move the whole room to the next page when it does not fit
        let tableH = pf.dims ? tableHeight(rows, tw) + 16 : 0
        let titleS = t("r.room", ["i": i, "n": dn(r.name, l), "f": floorLabel])
        let titleH = measure(a(titleS, ui(12, 600)), CW).height
        if !fits(12 + titleH + 4 + max(planH, tableH)) { newPage() }
        h2(titleS)
        space(0)
        let top = y
        if pf.plan {
            let label = dn(r.name, l), un = unit, e = en, snap = sn.snap
            draw { ctx in
                var c = ctx
                c.translateBy(x: PX + 0.75, y: top + 0.75); c.scaleBy(x: 0.75, y: 0.75)
                drawReportPlan(c, r, un, e, label, snap: snap)
                ctx.stroke(Path(CGRect(x: PX + 0.375, y: top + 0.375, width: 270.75, height: planH - 0.75)), with: .color(FIG), lineWidth: 0.75)
            }
        }
        if pf.dims { y = top; pend = 0; table(rows, x: tx, w: tw, breakable: false) }
        y = max(top + planH, pf.dims ? y + 10 : top); pend = 0
    }

    /// Drawings and photos chosen for the report, two a page (prototype extraPages, figures): each in a light frame the
    /// page's width and at most 292 high, with its name, workspace and caption under it; photos add a footnote.
    func figurePages() {
        let figs = sn.extras.filter { $0.kind != "note" }
        if figs.isEmpty { return }
        let f = MkFmt(unit: unit, en: en, m: mUnit(), lang: l)
        var i = 0
        while i < figs.count {
            let two = Array(figs[i..<min(figs.count, i + 2)])
            newPage(); h2(t("r.extras")); space(0)
            for x in two {
                let it = x.asItem()
                let vb = mkViewBox(it, .report)
                let fh = min(CW * vb.height / vb.width, 292) + 2
                let cap = NSMutableAttributedString(attributedString: a(dn(x.name, l), ui(9.5, 700, INK3)))
                cap.append(a(", " + x.ws + (x.caption.trimmingCharacters(in: .whitespaces).isEmpty ? "" : ". " + dn(x.caption, l)), ui(9.5, 400, INK3)))
                let cS = measure(cap, CW)
                space(0)
                let top = y
                let photo = x.src.flatMap { image($0) }
                draw { ctx in
                    ctx.fill(Path(CGRect(x: PX, y: top, width: CW, height: fh)), with: .color(.white))
                    Theme.shared.onPaper { drawMarkup(ctx, it, photo, CGRect(x: PX + 1, y: top + 1, width: CW - 2, height: fh - 2), f, .report) }
                    ctx.stroke(Path(CGRect(x: PX + 0.5, y: top + 0.5, width: CW - 1, height: fh - 1)), with: .color(FIG), lineWidth: 1)
                    drawText(ctx, cap, CGRect(x: PX, y: top + fh + 4, width: CW, height: cS.height))
                }
                y += fh + 4 + cS.height; after(12)
            }
            if two.contains(where: { $0.kind == "photo" }) { fn(t("r.photoNote")) }
            i += 2
        }
    }

    /// Notes chosen for the report (prototype extraPages, notes part).
    func notesPages() {
        let notes = sn.extras.filter { $0.kind == "note" }
        if notes.isEmpty { return }
        newPage(); h2(t("r.notesH"))
        for n in notes {
            let nm = dn(n.name, l).trimmingCharacters(in: .whitespaces)
            let head = NSMutableAttributedString(attributedString: a(nm.isEmpty ? t("it.untitled") : nm, ui(10, 700)))
            head.append(a(" " + n.ws, ui(10, 400, GREY)))
            let hS = measure(head, CW)
            let text = dn(n.text, l)
            let p = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : a(text, ui(10))
            let pS = p.map { measure($0, CW) }
            let ul = n.checks.isEmpty ? nil : a(n.checks.map { ($0.done ? "☑ " : "☐ ") + dn($0.text, l) }.joined(separator: "\n"), ui(10))
            let uS = ul.map { measure($0, CW) }
            let h = hS.height + (pS.map { 3 + $0.height } ?? 0) + (uS.map { 4 + $0.height } ?? 0) + 8 + 1
            space(0); if y + h > LIMIT { newPage(); h2(t("r.notesH")); space(0) }
            let top = y
            draw { ctx in
                var yy = top
                drawText(ctx, head, CGRect(x: PX, y: yy, width: CW, height: hS.height)); yy += hS.height
                if let p, let pS { yy += 3; drawText(ctx, p, CGRect(x: PX, y: yy, width: CW, height: pS.height)); yy += pS.height }
                if let ul, let uS { yy += 4; drawText(ctx, ul, CGRect(x: PX, y: yy, width: CW, height: uS.height)); yy += uS.height }
                ctx.line(NOTE_RULE, CGPoint(x: PX, y: yy + 8.5), CGPoint(x: PX + CW, y: yy + 8.5), 1)
            }
            y += h; after(10)
        }
    }

    /// 3D views two by two (prototype .views), at most four.
    func views() {
        let vs = sn.rooms.flatMap(\.room.views).prefix(4).compactMap { image($0.img) }
        if vs.isEmpty { return }
        h2(t("r.views"))
        space(0)
        let w = (CW - 8) / 2
        var i = 0
        while i < vs.count {
            let pair = Array(vs[i..<min(vs.count, i + 2)])
            let h = (pair.map { w * $0.size.height / max(1, $0.size.width) }.max() ?? 0) + 1.5
            if y + h > LIMIT { newPage(); space(0) }
            let top = y
            for (k, img) in pair.enumerated() {
                let x = PX + CGFloat(k) * (w + 8), ih = w * img.size.height / max(1, img.size.width)
                draw { ctx in
                    ctx.draw(Image(uiImage: img), in: CGRect(x: x + 0.75, y: top + 0.75, width: w - 1.5, height: ih - 1.5))
                    ctx.stroke(Path(CGRect(x: x + 0.375, y: top + 0.375, width: w - 0.75, height: ih - 0.75)), with: .color(FIG), lineWidth: 0.75)
                }
            }
            y += h + 8
            i += 2
        }
        pend = 0
    }

    /// Materials, labour and the grand total (prototype estimate page).
    func estimate(_ e: Estimate) {
        var m: Decimal = 0, lb: Decimal = 0
        for x in e.materials { m += Money.line(x.qty, x.price, sn.precision) }
        for x in e.labor { if let v = Money.parse(x.amount, sn.precision).value { lb += v } }
        h2(t("r.mat"))
        var mr: [[Cell]] = [[th(t("r.c.no")), th(t("r.c.name")), th(t("r.c.unit")), th(t("r.c.qty"), right: true), th(t("r.c.price"), right: true), th(t("r.c.sum"), right: true)]]
        for (j, x) in e.materials.enumerated() {
            mr.append([cell("\(j + 1)"), cell(dn(x.name, l)), cell(dn(x.unit, l)), rcell(Money.num(x.qty, en).replacingOccurrences(of: " ", with: NBSP)),
                       rcell(money(Money.parse(x.price, sn.precision).value ?? 0)), rcell(money(Money.line(x.qty, x.price, sn.precision)))])
        }
        mr.append([cell(t("r.total"), ui(10, 700), span: 5), rcell(money(m), num(10, 700))])
        table(mr, head: 1)
        h2(t("r.lab"))
        var lr: [[Cell]] = [[th(t("r.c.no")), th(t("r.c.name")), th(t("r.c.sum"), right: true)]]
        for (j, x) in e.labor.enumerated() { lr.append([cell("\(j + 1)"), cell(dn(x.name, l)), rcell(money(Money.parse(x.amount, sn.precision).value ?? 0))]) }
        lr.append([cell(t("r.total"), ui(10, 700), span: 2), rcell(money(lb), num(10, 700))])
        table(lr, head: 1)
        ensure(30)
        table([[cell(t("r.grand"), ui(11, 700)), Cell([a(money(m + lb) + NBSP + Money.cur(sn.currency, l), num(11, 700))], right: true, dbl: true)]], breakable: false)
    }

    /// Builder's and customer's signature lines (prototype .sig).
    func signatures() {
        let w = (CW - 30) / 2
        let sa = a(t("r.sigB"), ui(9, 400, INK3)), sb = a(t("r.sigC"), ui(9, 400, INK3))
        let ha = measure(sa, w).height, hb = measure(sb, w).height
        let h = 0.75 + 3 + max(ha, hb)
        space(22); if y + h > LIMIT { newPage(); space(22) }
        let top = y
        draw { ctx in
            ctx.line(Color(uiColor: INK), CGPoint(x: PX, y: top + 0.375), CGPoint(x: PX + w, y: top + 0.375), 0.75)
            drawText(ctx, sa, CGRect(x: PX, y: top + 3.75, width: w, height: ha))
            ctx.line(Color(uiColor: INK), CGPoint(x: PX + w + 30, y: top + 0.375), CGPoint(x: PX + CW, y: top + 0.375), 0.75)
            drawText(ctx, sb, CGRect(x: PX + w + 30, y: top + 3.75, width: w, height: hb))
        }
        y += h; after(0)
    }

    /// The page number and the project's name at the bottom, and the DRAFT mark across a draft (prototype .pf, .wmk).
    func finish() -> [RPage] {
        let n = pages.count
        let name = dn(sn.name, l)
        var mst = num(86, 700); mst.color = WMK; mst.tracking = 8.6; mst.lineHeight = 100
        let mark = a(t("r.mark"), mst), mS = measure(mark)
        return pages.enumerated().map { i, steps in
            let left = a(name, ui(8.5, 400, GREY)), lS = measure(left, CW / 2)
            let right = a(t("r.page", ["i": i + 1, "n": n]), ui(8.5, 400, GREY)), rS = measure(right)
            let draft = self.draft
            var all: [DrawStep] = [{ ctx in
                ctx.fill(Path(CGRect(x: 0, y: 0, width: PAGE_W, height: PAGE_H)), with: .color(.white))
                if draft {
                    var c = ctx
                    c.translateBy(x: PAGE_W / 2, y: PAGE_H * 0.46); c.rotate(by: .degrees(-30))
                    drawText(c, mark, CGRect(x: -mS.width / 2, y: -mS.height / 2, width: mS.width + 2, height: mS.height))
                }
            }]
            all += steps
            all.append { ctx in
                let fy = PAGE_H - 20 - lS.height
                drawText(ctx, left, CGRect(x: PX, y: fy, width: CW / 2, height: lS.height))
                drawText(ctx, right, CGRect(x: PAGE_W - PX - rS.width, y: fy, width: rS.width + 1, height: rS.height))
            }
            return RPage(steps: all)
        }
    }
}

/// The report's pages for sn: the parties and the first room, two rooms a page after that, the notes, then the views,
/// the estimate, the notes to the customer and the signatures. A draft says so in its title and across every page.
func reportPages(_ sn: Snap, draft: Bool, meta: QuoteMeta?, image: @escaping (String) -> UIImage?, now: Ms = nowMs(), design: Bool = false) -> [RPage] {
    // design: a tiler's simple app shares the design: dated, no draft mark (its snapshot has no estimate)
    let d = Doc(sn, draft && !design, meta, image, now)
    if design { d.quoteTitle = "rpt.design"; d.subLine = fmtDate(now) }
    let rooms = sn.rooms
    d.newPage(); d.parties()
    // with the plans and the measurements both off the rooms print nothing: no empty pages for them
    let roomsOn = sn.pdf.plan || sn.pdf.dims
    if roomsOn {
        if let first = rooms.first { d.roomBlock(first.room, 1, first.floorLabel) }
        d.fn(d.t("r.geoNote"))
        var i = 1
        while i < rooms.count {
            d.newPage()
            d.roomBlock(rooms[i].room, i + 1, rooms[i].floorLabel)
            if i + 1 < rooms.count { d.roomBlock(rooms[i + 1].room, i + 2, rooms[i + 1].floorLabel) }
            i += 2
        }
    }
    // an electrician's order: the wiring plan, the walls with their points and the legend
    if let e = sn.elec, !e.empty { d.elecPages(e) }
    // a plumber's order: the pipe plan with the fixtures, the walls with their outlets, the heating and the legend
    if let e = sn.plumb, !e.empty { d.plumbPages(e) }
    // a windows-and-doors order: the summary table, then each product's drawing from inside with its sizes and make
    if let e = sn.win, !e.empty { d.winPages(e) }
    d.figurePages()
    d.notesPages()
    // the first page holding only the parties has room for the rest
    if roomsOn || d.pages.count > 1 { d.newPage() }
    if sn.pdf.views { d.views() }
    if sn.pdf.estimate { d.estimate(sn.estimate) }
    if !sn.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { d.h2(d.t("rpt.notes")); d.para(d.a(sn.notes, d.ui(10)), top: 10, bottom: 10) }
    // the notes on quantities and money are the estimate's
    if sn.pdf.estimate { d.fn(d.t("r.qtyNote")); d.fn(d.t("r.moneyNote", ["c": sn.currency])) }
    if sn.pdf.sign { d.signatures() }
    return d.finish()
}

/// 3D view pictures for the pages, at about twice their size on the page (keeps the PDF small).
func viewLoader() -> (String) -> UIImage? {
    var cache: [String: UIImage?] = [:]
    return { img in
        if let c = cache[img] { return c }
        let i = ViewFiles.load(img, maxW: img.hasPrefix("photos/") || img.contains("/ph-") ? 1000 : 520)
        cache[img] = i
        return i
    }
}

/* ---------------- pictures and the PDF ---------------- */

/// A page as a SwiftUI drawing, 595 × 842.
struct PageCanvas: View {
    let page: RPage
    var body: some View { Canvas { ctx, _ in page.draw(ctx) }.frame(width: PAGE_W, height: PAGE_H) }
}

/// One page as a picture w points wide (the preview and the zoomed viewer).
@MainActor
func pageImage(_ page: RPage, width: CGFloat) -> UIImage? {
    let r = ImageRenderer(content: PageCanvas(page: page))
    r.scale = width / PAGE_W * UIScreen.main.scale
    r.isOpaque = true
    return r.uiImage
}

/// All pages as one PDF, one point per page pixel, text and drawings as vectors.
@MainActor
func writePdf(_ pages: [RPage], to url: URL) -> Bool {
    var box = CGRect(x: 0, y: 0, width: PAGE_W, height: PAGE_H)
    try? FileManager.default.removeItem(at: url)
    guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return false }
    for pg in pages {
        ImageRenderer(content: PageCanvas(page: pg)).render { _, draw in
            pdf.beginPDFPage(nil); draw(pdf); pdf.endPDFPage()
        }
    }
    pdf.closePDF()
    return true
}

/// Writes the PDF into the app's temporary folder (only the latest one is kept there).
@MainActor
func pdfFile(_ pages: [RPage], _ fname: String) -> URL? {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pdf", isDirectory: true)
    try? FileManager.default.removeItem(at: dir)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent(fname)
    return writePdf(pages, to: url) ? url : nil
}
