import SwiftUI
import UIKit

/*
 * An electrician's pages in the customer's PDF (Android report/ElecPages.kt): how the cable runs, the circuits with
 * their breakers, the legend of symbols, then each room from above with its routes and each wall with its points and
 * their heights. Prices stay in the estimate pages, which only the advanced app prints.
 */

private let E_FRAME = 0xC3CEDF

extension Doc {
    func elecPages(_ e: ElecOrder) {
        // worked out with every room (the circuits and cable stay the same when a room is left out); only the report's rooms are drawn
        var p = Project(id: "snap", name: sn.name)
        p.rooms = (sn.rooms + sn.calcRooms).map(\.room)
        p.industry = "elec"
        p.elec = e
        let calc = calcOf(p, sn.snap)
        if !calc.ctxs.contains(where: { !devsIn(p, $0).isEmpty }) { return }
        let shown = Set(sn.rooms.map(\.room.id))
        let byDev = circuitByDev(calc)
        let isEn = en
        let dec = { (s: String) -> String in isEn ? s : s.replacingOccurrences(of: ".", with: ",") }
        // on the page in hand when it has room (no near-empty first page)
        ensure(260)
        h2(t("el.r.title"))
        para(a(t("el.r.method", ["m": t("el.m." + e.method)]) + " " + t("el.m." + e.method + "S"), ui(9.5, 400)), top: 2, bottom: 6)
        // the circuits
        let withLen = sn.pdf.estimate
        var names: [String: String] = [:]
        for c in calc.ctxs { names[c.id] = roomName(c) }
        var head: [Cell] = [th(t("r.c.no")), th(t("el.r.group")), th(t("el.r.brk")), th(t("el.r.cable")), th(t("el.r.rooms"))]
        if withLen { head.append(th(t("el.r.len"), right: true)) }
        var rows: [[Cell]] = [head]
        for cc in calc.circuits {
            let brk = cc.amps > 0 ? t("el.brkV", ["a": cc.amps]) + (cc.rcd ? ", " + t("el.rcdS") : "") : "—"
            let cab = dec(cc.cable == "utp" ? "UTP" : "VVG " + cableName(cc.cable))
            let inRooms = cc.rooms.compactMap { names[$0] }.joined(separator: ", ")
            var row: [Cell] = [cell("\(cc.no)"), cell(t("el.g." + cc.group)), cell(brk), cell(cab), cell(inRooms)]
            if withLen { row.append(rcell(dec(String(format: "%.1f", calc.routes.cableOf(cc) / 1000)) + " " + t("u.m"))) }
            rows.append(row)
        }
        table(rows, head: 1)
        if withLen { fn(t("el.r.lenNote")) }
        legend(p, calc)
        fn(t("el.r.note"))
        // each room: from above, then its walls
        for c in calc.ctxs where c.free != nil || shown.contains(c.id) { roomPage(p, c, calc, byDev, names[c.id] ?? "") }
    }

    private func roomName(_ c: ECtx) -> String {
        if let f = c.free {
            let nm = dn(f.name, l)
            return nm.trimmingCharacters(in: .whitespaces).isEmpty ? t("el.k." + f.kind) : nm
        }
        let all = sn.rooms + sn.calcRooms
        guard let sr = all.first(where: { $0.room.id == c.id }) else { return "" }
        return tradeRoomName(sr, all, l)
    }

    /// The legend: every symbol used and the panel, then the circuits' colours.
    private func legend(_ p: Project, _ calc: ElecCalc) {
        var all: [ElecDev] = []
        for c in calc.ctxs { all += devsIn(p, c) }
        let types = legendTypes(all) + ["panel"]
        h2(t("el.r.legend"))
        let colW = CW / 3
        var i = 0
        while i < types.count {
            let row = Array(types[i..<min(i + 3, types.count)])
            i += 3
            ensure(16); space(0)
            let top = y
            let labels = row.map { k in a(k == "panel" ? t("el.panel") : t("el.t." + k), ui(8.5, 400)) }
            let sizes = labels.map { measure($0, colW - 22) }
            let h = max(14, sizes.map(\.height).max() ?? 0)
            draw { ctx in
                ctx.withCGContext { cg in
                    for (j, k) in row.enumerated() {
                        let x = PX + CGFloat(j) * colW
                        devSymbol(cg, k, CGPoint(x: x + 8, y: top + h / 2), 5, eCG(0x2563EB), eCG(E_INK_RGB))
                    }
                }
                for (j, lb) in labels.enumerated() {
                    let x = PX + CGFloat(j) * colW
                    drawText(ctx, lb, CGRect(x: x + 20, y: top + (h - sizes[j].height) / 2, width: colW - 22, height: sizes[j].height))
                }
            }
            y += h + 3
        }
        ensure(16); space(0)
        let gTop = y
        var gl: [String] = []
        for cc in calc.circuits where !gl.contains(cc.group) { gl.append(cc.group) }
        let gLab = gl.map { a(t("el.g." + $0), ui(8.5, 400)) }
        let gSize = gLab.map { measure($0) }
        draw { ctx in
            var x = PX
            for (j, g) in gl.enumerated() {
                let col = Color(uiColor: uiColor(groupDef(g).rgb))
                ctx.line(col, CGPoint(x: x, y: gTop + 7), CGPoint(x: x + 14, y: gTop + 7), 2.5)
                drawText(ctx, gLab[j], CGRect(x: x + 18, y: gTop + 7 - gSize[j].height / 2, width: gSize[j].width + 1, height: gSize[j].height))
                x += 18 + gSize[j].width + 12
            }
        }
        y += 16; after(6)
    }

    /// A room from above with its routes, then each wall with points on it.
    private func roomPage(_ p: Project, _ c: ECtx, _ calc: ElecCalc, _ byDev: [String: Circuit], _ name: String) {
        let ds = devsIn(p, c)
        let runs = calc.routes.inRoom(c.id)
        if ds.isEmpty && runs.isEmpty { return }
        let pn = calc.routes.panel
        newPage()
        h2(t("el.r.room", ["r": name]))
        space(0)
        let ph: CGFloat = 250
        let top = y
        draw { ctx in
            ctx.withCGContext { cg in
                let box = CGRect(x: PX, y: top, width: CW, height: ph)
                cg.setFillColor(eCG(0xFFFFFF)); cg.fill(box)
                drawElecPlan(cg, c, EPlanMap(c, box, 16), ds, pn, runs, { byDev[$0] }, 5.5)
                cg.setStrokeColor(eCG(E_FRAME)); cg.setLineWidth(0.75); cg.stroke(box.insetBy(dx: 0.5, dy: 0.5))
            }
        }
        y += ph; after(8)
        let ws = c.g.walls.filter { w in ds.contains { $0.wall == w.id } || (pn.map { $0.roomId == c.id && $0.wall == w.id } ?? false) }
        let bw = (CW - 10) / 2, bh: CGFloat = 150
        let lst = ui(6.5, 600)
        let lAttrs = attrs(lst)
        let u = unit, isEn = en
        let label: (String) -> NSAttributedString = { s in NSAttributedString(string: Geo.fmtLen(Int(s), u, isEn), attributes: lAttrs) }
        var i = 0
        while i < ws.count {
            let two = Array(ws[i..<min(i + 2, ws.count)])
            i += 2
            let caps = two.map { w in a(t("tl.wallN", ["w": w.id]) + " · " + len(tInt(w.len)) + " " + mUnit(), ui(9, 600)) }
            let capS = caps.map { measure($0) }
            let need = (capS.map(\.height).max() ?? 0) + 3 + bh
            ensure(need + 6); space(0)
            let t0 = y
            draw { ctx in
                for (j, w) in two.enumerated() {
                    let x = PX + CGFloat(j) * (bw + 10)
                    drawText(ctx, caps[j], CGRect(x: x, y: t0, width: capS[j].width + 1, height: capS[j].height))
                    let bt = t0 + capS[j].height + 3
                    ctx.withCGContext { cg in
                        let box = CGRect(x: x, y: bt, width: bw, height: bh)
                        cg.setFillColor(eCG(0xFFFFFF)); cg.fill(box)
                        drawElecWall(cg, c, w, EWallMap(w.len, c.g.H, box, 10, 12), ds, pn, runs, { byDev[$0] }, label)
                        cg.setStrokeColor(eCG(E_FRAME)); cg.setLineWidth(0.75); cg.stroke(box.insetBy(dx: 0.5, dy: 0.5))
                    }
                }
            }
            y += need; after(10)
        }
    }
}
