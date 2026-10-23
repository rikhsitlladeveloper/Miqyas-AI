import SwiftUI
import UIKit

/*
 * A tiler's pages in the customer's PDF (like the electrician's and the plumber's; Android report/TilePages.kt): the
 * layouts in a table (where, the pattern, the tile and its joint, the look), then each tiled room from above with the
 * floor's tiles and each tiled wall from the front with its tiles round the doors and windows. Prices stay in the
 * estimate pages.
 */

private let TP_FRAME = 0xC3CEDF
private let TP_WALL_INK = 0x3E4A61

extension Doc {
    /// A layout in words for the PDF: where and the pattern; the tile, its joint and look.
    private func tpLine(_ x: TileLayout) -> String { t(placeKey(x)) + " · " + t("tl.p." + x.pattern) }
    private func tpTile(_ x: TileLayout) -> String {
        "\(x.a) × \(x.b) " + t("u.mm") + " · " + t("tl.jointV", ["n": x.joint]) + (x.rot != 0 ? " · \(x.rot)°" : "")
    }
    private func tpLook(_ x: TileLayout) -> String { t("tl.lk." + x.look) + (x.usesSecond ? " + " + t("tl.lk." + x.look2) : "") }

    func tilePages(_ ls: [TileLayout], _ troom: [TileRoom]) {
        if ls.isEmpty { return }
        var names: [String: String] = [:]
        for sr in sn.rooms { names[sr.room.id] = tradeRoomName(sr, sn.rooms, l) }
        // the layouts of the report's rooms and those typed by size
        let shown = ls.filter { x in x.roomId.map { names[$0] != nil } ?? true }
        if shown.isEmpty { return }
        ensure(200)
        h2(t("tl.r.title"))
        var rows: [[Cell]] = [[th(t("tl.r.where")), th(t("tl.r.layout")), th(t("tl.r.tile")), th(t("tl.r.look"))]]
        for x in shown {
            let whereS = x.roomId.flatMap { names[$0] } ?? t("tl.r.typed")
            rows.append([cell(whereS), cell(tpLine(x)), cell(tpTile(x)), cell(tpLook(x))])
        }
        table(rows, head: 1)
        fn(t("tl.r.note"))
        // each tiled room: the floor from above, then the tiled walls from the front
        for sr in sn.rooms { tpRoom(sr.room, ls, troom, names[sr.room.id] ?? dn(sr.room.name, l)) }
    }

    private func tpRoom(_ r: Room, _ ls: [TileLayout], _ troom: [TileRoom], _ name: String) {
        let mine = ls.filter { $0.roomId == r.id }
        if mine.isEmpty { return }
        let fixes = troom.first { $0.roomId == r.id }?.fixes ?? []
        guard let g = roomGeo(r, sn.snap, fixes) else { return }
        let fl = floorLayout(ls, r.id)
        let laid: [(TileLayout, Laid)] = mine.map { ($0, layRoom($0, g, fl)) }
        newPage()
        h2(t("tl.r.room", ["r": name]))
        // the plan, fitted in the page's width
        let xs = g.floor.map(\.x), ys = g.floor.map(\.y)
        let x0 = xs.min() ?? 0, y0 = ys.min() ?? 0
        let bw = max((xs.max() ?? 0) - x0, 1), bh = max((ys.max() ?? 0) - y0, 1)
        let ph: CGFloat = 250, pad: CGFloat = 16
        let kx = Double(CW - 2 * pad) / bw, ky = Double(ph - 2 * pad) / bh
        let k = min(kx, ky)
        let ox = Double(PX) + (Double(CW) - bw * k) / 2
        space(0)
        let top = y
        let oy = Double(top) + (Double(ph) - bh * k) / 2
        let plan: (V2) -> CGPoint = { v in CGPoint(x: ox + (v.x - x0) * k, y: oy + (v.y - y0) * k) }
        let letterSt = attrs(ui(8, 700, uiColor(TP_WALL_INK)))
        let letters: [(TWall, NSAttributedString)] = g.walls.map { w in (w, NSAttributedString(string: w.id, attributes: letterSt)) }
        let letterS = letters.map { measure($0.1) }
        draw { ctx in
            ctx.withCGContext { cg in
                let box = CGRect(x: PX, y: top, width: CW, height: ph)
                cg.setFillColor(eCG(0xFFFFFF)); cg.fill(box)
                let onPlan: (V2) -> CGPoint? = { q in plan(q) }
                let off: (V2) -> CGPoint? = { _ in nil }
                for (lt, ld) in laid {
                    drawLaidCapped(cg, ld, lt, { s in s.kind == "floor" ? onPlan : off }, outline: true)
                }
                let path = CGMutablePath()
                for (i, v) in g.floor.enumerated() {
                    if i == 0 { path.move(to: plan(v)) } else { path.addLine(to: plan(v)) }
                }
                path.closeSubpath()
                cg.addPath(path); cg.setStrokeColor(eCG(TP_WALL_INK)); cg.setLineWidth(1.2); cg.strokePath()
                cg.setStrokeColor(eCG(TP_FRAME)); cg.setLineWidth(0.75); cg.stroke(box.insetBy(dx: 0.5, dy: 0.5))
            }
            // wall letters by each wall's middle, inside the plan
            for i in letters.indices {
                let (w, m) = letters[i]
                let o = plan(w.at(w.len / 2, 9.0 / max(k, 0.001)))
                let s = letterS[i]
                drawText(ctx, m, CGRect(x: o.x - s.width / 2, y: o.y - s.height / 2, width: s.width + 1, height: s.height))
            }
        }
        y += ph; after(8)
        // the walls with tiles on them, two a row
        let walls = g.walls.filter { w in laid.contains { pair in pair.1.surfs.contains { $0.wall == w.id && $0.kind != "floor" } } }
        var i = 0
        while i < walls.count {
            let two = Array(walls[i..<min(i + 2, walls.count)])
            i += 2
            tpWalls(r, g, two, laid)
        }
    }

    /// Two tiled walls side by side, each from the front with its tiles, doors and windows.
    private func tpWalls(_ r: Room, _ g: TRoomGeo, _ two: [TWall], _ laid: [(TileLayout, Laid)]) {
        let ew = (CW - 10) / 2, eh: CGFloat = 150
        let caps = two.map { w in a(t("tl.wallN", ["w": w.id]) + " · " + len(tInt(w.len)) + " " + mUnit(), ui(9, 600)) }
        let capS = caps.map { measure($0) }
        let need = (capS.map(\.height).max() ?? 0) + 3 + eh
        ensure(need + 6); space(0)
        let t0 = y
        let H = g.H
        draw { ctx in
            for (j, w) in two.enumerated() {
                let x = PX + CGFloat(j) * (ew + 10)
                drawText(ctx, caps[j], CGRect(x: x, y: t0, width: capS[j].width + 1, height: capS[j].height))
                let bt = t0 + capS[j].height + 3
                ctx.withCGContext { cg in
                    let box = CGRect(x: x, y: bt, width: ew, height: eh)
                    cg.setFillColor(eCG(0xFFFFFF)); cg.fill(box)
                    let kk = min(Double(ew - 20) / max(w.len, 1), Double(eh - 20) / max(H, 1))
                    let ex = Double(x) + (Double(ew) - w.len * kk) / 2
                    let eb = Double(bt) + Double(eh) - (Double(eh) - H * kk) / 2
                    let elev: (V2) -> CGPoint? = { v in CGPoint(x: ex + v.x * kk, y: eb - v.y * kk) }
                    // the wall's own surfaces: the wall less its openings, a bath's front, a niche's back, a column's face
                    let on: (Surf) -> Bool = { s in
                        s.wall == w.id && (s.kind == "wall" || s.kind == "bath" || s.kind == "niche" || (s.kind == "col" && s.key.hasSuffix(":f")))
                    }
                    let off: (V2) -> CGPoint? = { _ in nil }
                    for (lt, ld) in laid { drawLaidCapped(cg, ld, lt, { s in on(s) ? elev : off }, outline: true) }
                    cg.setStrokeColor(eCG(TP_WALL_INK)); cg.setLineWidth(1)
                    cg.stroke(CGRect(x: ex, y: eb - H * kk, width: w.len * kk, height: H * kk))
                    // the doors and windows, outlined
                    cg.setLineWidth(0.8)
                    for o in r.openings where o.wall == w.id {
                        let top = Double(o.sill + o.h)
                        cg.stroke(CGRect(x: ex + Double(o.off) * kk, y: eb - top * kk, width: Double(o.w) * kk, height: Double(o.h) * kk))
                    }
                    cg.setStrokeColor(eCG(TP_FRAME)); cg.setLineWidth(0.75); cg.stroke(box.insetBy(dx: 0.5, dy: 0.5))
                }
            }
        }
        y += need; after(10)
    }
}
