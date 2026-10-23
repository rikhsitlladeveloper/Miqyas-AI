import SwiftUI
import UIKit

/*
 * The part labels' pages (bazis ideas, 23 Oct 2026; Furniture/Core/FurnLabels.swift; Android report/LabelPages.kt): an
 * A4 sheet of 3 × 8 stickers, 70 × 37 mm, edge to edge as the usual sticker sheets are. Each one: the part and its
 * number, its finished size, a small drawing of the part with its banded edges, the material, the piece and module,
 * the order; the QR code with the part's id when asked for.
 */

private let L_INK = Color(argb: 0xFF0E1C36)
private let L_GREY = Color(argb: 0xFF5F6B82)
private let L_GREYU = UIColor(red: 0x5F / 255, green: 0x6B / 255, blue: 0x82 / 255, alpha: 1)
private let L_CUT = Color(argb: 0xFFDCE4F0)
private let L_GLYPH = Color(argb: 0xFFF3F6FA)

/// A text on a sticker: one line, cut short with "…" when longer than its width; where it goes.
private struct LText { let s: NSAttributedString; let rect: CGRect }

/// A sticker's drawing, its texts measured first (outside the page's drawing).
private struct Sticker {
    let lb: PartLabel, page: Int, x: CGFloat, y: CGFloat
    let texts: [LText]
    let code: QrCode?
    let glyph: CGPoint
}

/// A board's name in the labels' language: the app's own preset by its strings key; a name the workshop typed stays.
private func labelMatName(_ d: Doc, _ mats: [Mat], _ id: String) -> String {
    guard let m = mats.first(where: { $0.id == id }) else { return id }
    if MAT_PRESETS.contains(where: { $0.id == m.id && $0.name == m.name }) && Strings.has("mp." + m.id) { return d.t("mp." + m.id) }
    return m.name
}

/// The stickers of the order in sn (order its id, for the QR codes); qr with a QR code each.
func labelPagesOf(_ sn: Snap, _ ws: Workshop, _ mats: [Mat], _ order: String, _ qr: Bool, now: Ms = nowMs()) -> [RPage] {
    let d = Doc(sn, false, nil, { _ in nil }, now)
    let labels = labelsOf(labelled(sn.furniture), ws)
    if labels.isEmpty { return [] }
    let cw = PAGE_W / CGFloat(LABEL_COLS), rh = PAGE_H / CGFloat(LABEL_ROWS)
    // the order and its customer (once, when the order is named after them)
    let name = dn(sn.name, d.l)
    let cust = sn.customer.trimmingCharacters(in: .whitespaces)
    let orderLine = [name, (!cust.isEmpty && !name.contains(cust)) ? cust : ""].filter { !$0.isEmpty }.joined(separator: " · ")
    func one(_ s: String, _ st: Sty, _ w: CGFloat) -> (NSAttributedString, CGSize) {
        let m = NSMutableAttributedString(attributedString: d.a(s, st))
        m.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: m.length)) { v, r, _ in
            let ps = ((v as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            ps.lineBreakMode = .byTruncatingTail
            m.addAttribute(.paragraphStyle, value: ps, range: r)
        }
        let full = d.measure(m)
        let size = CGSize(width: min(full.width, max(1, w)), height: full.height)
        return (m, size)
    }
    func greyed(_ st: Sty) -> Sty { var x = st; x.color = L_GREYU; return x }
    let pad: CGFloat = 8
    let qs: CGFloat = qr ? 50 : 0
    var stickers: [Sticker] = []
    for (i, lb) in labels.enumerated() {
        let slot = labelSlot(i)
        let x = CGFloat(slot.col) * cw, y = CGFloat(slot.row) * rh
        let tw: CGFloat = cw - 2 * pad - (qr ? qs + 6 : 0)
        var t: [LText] = []
        let (nm, nmS) = one(d.t(lb.key) + (lb.grain ? " ↕" : ""), d.ui(9, 700), tw - 28)
        t.append(LText(s: nm, rect: CGRect(x: x + pad, y: y + pad, width: nmS.width, height: nmS.height)))
        let (no, noS) = one("№\(lb.n)", d.num(9, 700), 40)
        t.append(LText(s: no, rect: CGRect(x: x + pad + tw - noS.width, y: y + pad, width: noS.width + 1, height: noS.height)))
        let (sz, szS) = one("\(lb.L) × \(lb.W)", d.num(15, 700), tw - 16)
        t.append(LText(s: sz, rect: CGRect(x: x + pad, y: y + pad + 15, width: szS.width + 1, height: szS.height)))
        let (mm, mmS) = one(d.t("u.mm"), greyed(d.ui(7.5, 500)), 30)
        t.append(LText(s: mm, rect: CGRect(x: x + pad + szS.width + 3, y: y + pad + 22, width: mmS.width + 1, height: mmS.height)))
        // the material and the piece beside the part's drawing
        let (mt, mtS) = one(dn(labelMatName(d, mats, lb.mat), d.l), d.ui(7.5, 500), tw - 48)
        t.append(LText(s: mt, rect: CGRect(x: x + pad, y: y + pad + 40, width: mtS.width, height: mtS.height)))
        let pieceText = dn(lb.piece, d.l) + (lb.mod.isEmpty ? "" : " · " + lb.mod)
        let (pc, pcS) = one(pieceText, d.ui(7.5, 600), tw - 48)
        t.append(LText(s: pc, rect: CGRect(x: x + pad, y: y + pad + 52, width: pcS.width, height: pcS.height)))
        let (ol, olS) = one(orderLine, greyed(d.ui(7, 400)), tw)
        t.append(LText(s: ol, rect: CGRect(x: x + pad, y: y + pad + 64, width: olS.width, height: olS.height)))
        let code: QrCode? = qr ? qrOf(labelId(order, lb.n)) : nil
        if code != nil {
            let (idT, idS) = one(labelId(order, lb.n), d.num(5.5, 500), qs + 8)
            t.append(LText(s: idT, rect: CGRect(x: x + cw - pad - qs, y: y + pad + qs + 1, width: idS.width, height: idS.height)))
        }
        stickers.append(Sticker(lb: lb, page: slot.page, x: x, y: y, texts: t, code: code, glyph: CGPoint(x: x + pad + tw - 40, y: y + pad + 41)))
    }
    let pages = labelPages(labels.count)
    var out: [RPage] = []
    for pg in 0..<pages {
        let list = stickers.filter { $0.page == pg }
        let step: DrawStep = { ctx in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: PAGE_W, height: PAGE_H)), with: .color(.white))
            for s in list { drawSticker(ctx, s, cw, rh, pad, qs) }
        }
        out.append(RPage(steps: [step]))
    }
    return out
}

/// One sticker: its light cutting line, its texts, the part's drawing with its banded edges, the QR code.
private func drawSticker(_ ctx: GraphicsContext, _ s: Sticker, _ cw: CGFloat, _ rh: CGFloat, _ pad: CGFloat, _ qs: CGFloat) {
    // the cutting line round the sticker, light (a sticker sheet is cut already; on plain paper it guides the scissors)
    ctx.stroke(Path(CGRect(x: s.x, y: s.y, width: cw, height: rh)), with: .color(L_CUT), lineWidth: 0.5)
    for t in s.texts { drawText(ctx, t.s, t.rect) }
    // the part, drawn small: a thick edge banded thick, a thin line thin, a dashed one not banded
    let gw: CGFloat = 40, gh: CGFloat = 22
    let g = s.glyph
    ctx.fill(Path(CGRect(x: g.x, y: g.y, width: gw, height: gh)), with: .color(L_GLYPH))
    func edge(_ code: Int, _ a: CGPoint, _ b: CGPoint) {
        if code == 0 { ctx.line(L_GREY.opacity(0.5), a, b, 0.6, dash: [2, 2]) }
        else { ctx.line(L_INK, a, b, code == 2 ? 2.4 : 0.9) }
    }
    let bd = s.lb.bands
    edge(bd.l1, g, CGPoint(x: g.x + gw, y: g.y))
    edge(bd.l2, CGPoint(x: g.x, y: g.y + gh), CGPoint(x: g.x + gw, y: g.y + gh))
    edge(bd.s1, g, CGPoint(x: g.x, y: g.y + gh))
    edge(bd.s2, CGPoint(x: g.x + gw, y: g.y), CGPoint(x: g.x + gw, y: g.y + gh))
    guard let q = s.code else { return }
    let m: CGFloat = qs / CGFloat(q.size + 2)
    let ox = s.x + cw - pad - qs + m, oy = s.y + pad + m
    var dark = Path()
    for r in 0..<q.size {
        for c in 0..<q.size where q[r, c] {
            dark.addRect(CGRect(x: ox + CGFloat(c) * m, y: oy + CGFloat(r) * m, width: m + 0.05, height: m + 0.05))
        }
    }
    ctx.fill(dark, with: .color(L_INK))
}
