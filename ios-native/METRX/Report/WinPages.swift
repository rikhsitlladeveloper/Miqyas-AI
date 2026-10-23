import SwiftUI
import UIKit

/*
 * A windows-and-doors maker's pages in the customer's PDF (Android report/WinPages.kt): a summary table of every
 * product (its room and opening, its size, how many, and in the advanced app its price), then each product drawn from
 * inside with its overall and sash sizes, its sash split and opening symbols, and its make: profile, glass, colours,
 * extras, room and opening. Prices only with the estimate (the advanced app); the parts' lines stay in the estimate
 * pages.
 */

private let WP_FRAME = 0xC3CEDF

extension Doc {
    func winPages(_ e: WinOrder) {
        let items = e.items
        if items.isEmpty { return }
        let withPrice = sn.pdf.estimate && !sn.winPrice.isEmpty
        // on the page in hand when it has room (no near-empty first page)
        ensure(260)
        h2(t("dw.r.title"))
        var head: [Cell] = [th("№"), th(t("dw.r.item")), th(t("dw.r.where")), th(t("dw.r.size"), right: true), th(t("dw.r.qty"), right: true)]
        if withPrice { head.append(th(t("dw.r.price"), right: true)) }
        var rows: [[Cell]] = [head]
        for (i, it) in items.enumerated() {
            var row: [Cell] = [rcell("\(i + 1)"), cell(wpTitle(it)), cell(wpWhere(it)), rcell("\(it.w) × \(it.h)"), rcell("\(it.qty)")]
            if withPrice { row.append(rcell(wpPrice(it.id) ?? "—")) }
            rows.append(row)
        }
        table(rows, head: 1)
        // each product's price on its own (rounded up per product); the order's total is the estimate's
        if withPrice { fn(t("dw.r.priceNote")) }
        fn(t("dw.r.note"))
        // each product: its drawing from inside on the left, what it is made of on the right
        for (i, it) in items.enumerated() { wpItem(i, it, withPrice) }
    }

    private func wpTitle(_ it: WinItem) -> String {
        it.name.trimmingCharacters(in: .whitespaces).isEmpty ? t("dw.k." + it.kind) : it.name
    }

    private func wpPrice(_ id: String) -> String? {
        guard let v = sn.winPrice[id] else { return nil }
        var d = Decimal(v)
        let n = min(max(sn.precision, 0), 4)
        for _ in 0..<n { d *= 10 }
        return money(d) + " " + sn.currency
    }

    private func wpWhere(_ it: WinItem) -> String {
        if !it.inRoom { return t("dw.noRoom") }
        // every room (a window in a room left out of the report still has its room and opening)
        let all = sn.rooms + sn.calcRooms
        guard let sr = all.first(where: { $0.room.id == it.roomId }) else { return t("dw.noRoom") }
        let r = sr.room
        let name = tradeRoomName(sr, all, l)
        guard let o = r.openings.first(where: { $0.id == it.opening }) else { return name }
        let k = wOpeningKey(r, o)
        return name + " · " + t(k.0, ["n": k.1]) + " · " + t("tl.wallN", ["w": o.wall])
    }

    private func wpItem(_ i: Int, _ it: WinItem, _ withPrice: Bool) {
        let bw = CW * 0.56, bh: CGFloat = 210
        let cap = a("\(i + 1). " + wpTitle(it), ui(10.5, 700))
        let capS = measure(cap, CW)
        let spec = a(wpSpec(it, withPrice ? wpPrice(it.id) : nil), ui(8.5, 400))
        let specW = CW - bw - 16
        let specS = measure(spec, specW)
        let need = capS.height + 4 + max(bh, specS.height)
        ensure(need + 6); space(8)
        let top = y
        let lAttrs = attrs(ui(6.5, 600)), sAttrs = attrs(ui(5.5, 500))
        let label: (String) -> NSAttributedString = { s in NSAttributedString(string: s, attributes: lAttrs) }
        let small: (String) -> NSAttributedString = { s in NSAttributedString(string: s, attributes: sAttrs) }
        draw { ctx in
            drawText(ctx, cap, CGRect(x: PX, y: top, width: CW, height: capS.height))
            let bt = top + capS.height + 4
            ctx.withCGContext { cg in
                let box = CGRect(x: PX, y: bt, width: bw, height: bh)
                cg.setFillColor(eCG(0xFFFFFF)); cg.fill(box)
                let m = WElevMap(Double(it.w), Double(it.h), box, 18, 34, 6)
                drawWinElevation(cg, it, m, label: label, small: small, stroke: 1)
                cg.setStrokeColor(eCG(WP_FRAME)); cg.setLineWidth(0.75); cg.stroke(box.insetBy(dx: 0.5, dy: 0.5))
            }
            drawText(ctx, spec, CGRect(x: PX + bw + 16, y: bt, width: specW, height: specS.height))
        }
        y += need; after(10)
    }

    /// What product it is made of, line by line, in the report's language.
    private func wpSpec(_ it: WinItem, _ price: String?) -> String {
        var lines: [String] = []
        lines.append(t("dw.r.at", ["w": wpWhere(it)]))
        if it.inRoom, let rid = it.roomId {
            var p = Project(id: "s", name: "")
            p.rooms = (sn.rooms + sn.calcRooms).map(\.room)
            if let c = wCtxOf(p, rid, sn.snap), let pl = wPlaced(c, it) {
                lines.append(t("dw.r.op", ["s": "\(pl.o.w) × \(pl.o.h)", "g": it.gap]))
            }
        }
        let qty: String = !it.inRoom && it.qty > 1 ? " · " + t("dw.qtyN", ["n": it.qty]) : ""
        lines.append(t("dw.r.sizeL", ["s": "\(it.w) × \(it.h)"]) + qty)
        if it.isDoor {
            let sliding = it.kind == "dsl"
            let swing: String = sliding ? "" : " · " + t("dw.swing." + it.swing)
            lines.append(t(sliding ? "dw.slide" + it.hinge : "dw.hinge" + it.hinge) + swing)
            lines.append(t("dw.colDoor") + ": " + t("dw.col." + it.colIn))
        } else {
            let ch: String = it.profile == "alu" ? t(it.chambers >= 3 ? "dw.alu.warm" : "dw.alu.cold") : t("dw.chN", ["n": it.chambers])
            lines.append(t("dw.p." + it.profile) + ", " + ch)
            lines.append(t("dw.g.\(it.glass)"))
            lines.append(t("dw.colIn") + ": " + t("dw.col." + it.colIn) + " · " + t("dw.colOut") + ": " + t("dw.col." + it.colOut))
            for (i, s) in wSashesOf(it).enumerated() {
                var h = ""
                if s.t == "turn" || s.t == "tt" { h = " (" + t("dw.hinge" + s.cell.hinge) + ")" }
                else if s.t == "slide" { h = " (" + t("dw.slide" + s.cell.hinge) + ")" }
                let size = "\(tInt(eMathRoundP(s.r.w))) × \(tInt(eMathRoundP(s.r.h)))"
                lines.append(t("dw.sashN", ["n": i + 1]) + ": " + t("dw.t." + s.t) + h + ", " + size)
            }
            var ex: [String] = []
            if it.sill > 0 { ex.append(t("dw.x.sill") + " \(it.sill) " + t("dw.mm")) }
            if it.drip { ex.append(t("dw.x.drip")) }
            if it.reveals { ex.append(t("dw.x.reveals")) }
            if it.net { ex.append(t("dw.x.net")) }
            if it.handles { ex.append(t("dw.x.handles")) }
            if !ex.isEmpty { lines.append(t("dw.extras") + ": " + ex.joined(separator: ", ")) }
        }
        if let price { lines.append(t("dw.r.price") + ": " + price) }
        return lines.joined(separator: "\n")
    }
}
