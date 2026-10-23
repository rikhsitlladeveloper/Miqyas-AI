import SwiftUI
import UIKit

/*
 * A plumber's pages in the customer's PDF (Android report/PlumbPages.kt): the pipe system, the fixtures room by room,
 * the legend of symbols and pipe colours, the heating; then each room from above with its fixtures, riser, pipes and
 * underfloor loops, and each wall with its fixtures and outlets at their heights. Pipe lengths only in the advanced
 * app's PDF (with the estimate); prices stay in the estimate pages.
 */

private let PP_FRAME = 0xC3CEDF

extension Doc {
    func plumbPages(_ e: PlumbOrder) {
        // worked out with every room (the riser's room may be left out of the report); only the report's rooms are drawn
        var p = Project(id: "snap", name: sn.name)
        p.rooms = (sn.rooms + sn.calcRooms).map(\.room)
        p.industry = "plumb"
        p.plumb = e
        let calc = plumbCalcOf(p, sn.snap)
        let hasWork = calc.ctxs.contains { c in !fixesIn(p, c).isEmpty || !pointsIn(p, c).isEmpty || c.pr.ufh }
        if !hasWork { return }
        var names: [String: String] = [:]
        for c in calc.ctxs { names[c.id] = ppRoomName(c) }
        // on the page in hand when it has room (no near-empty first page)
        ensure(260)
        h2(t("sx.r.title"))
        let rs = calc.routes.riser
        var sys = t("sx.r.system", ["s": t("sx.sys." + e.water), "r": t("sx.run." + e.run), "h": t("sx.run." + e.hrun)])
        if let rs { sys += " " + t("sx.r.riser", ["r": names[rs.roomId] ?? "", "w": rs.wall]) }
        para(a(sys, ui(9.5, 400)), top: 2, bottom: 6)
        ppFixTable(p, calc, names)
        if sn.pdf.estimate { ppLenTable(calc) }
        ppLegend(p, calc)
        ppHeat(p, calc, names)
        if !calc.warns.isEmpty { fn(t("sx.r.warn", ["n": calc.warns.count])) }
        fn(t("sx.r.note"))
        // each room: from above, then the walls with fixtures or outlets
        for c in calc.ctxs where ppDrawn(c) { ppRoomPage(p, c, calc, names[c.id] ?? "") }
    }

    /// A room the report draws: one typed by size, or a room ticked for the report.
    private func ppDrawn(_ c: PCtx) -> Bool { c.free != nil || sn.rooms.contains { $0.room.id == c.id } }

    private func ppD1(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return en ? s : s.replacingOccurrences(of: ".", with: ",")
    }

    private func ppRoomName(_ c: PCtx) -> String {
        if let f = c.free { return f.name.trimmingCharacters(in: .whitespaces).isEmpty ? t("sx.k." + f.kind) : f.name }
        guard let sr = (sn.rooms + sn.calcRooms).first(where: { $0.room.id == c.id }) else { return "" }
        return sr.floorLabel.trimmingCharacters(in: .whitespaces).isEmpty ? dn(sr.room.name, l) : sr.floorLabel
    }

    /// The fixtures room by room (with the pipe in each room in the advanced app's PDF).
    private func ppFixTable(_ p: Project, _ calc: PlumbCalc, _ names: [String: String]) {
        let withLen = sn.pdf.estimate
        var head: [Cell] = [th(t("sx.r.room")), th(t("sx.fixes")), th(t("sx.points"), right: true)]
        if withLen { head.append(th(t("sx.r.pipe"), right: true)) }
        var rows: [[Cell]] = [head]
        for c in calc.ctxs {
            let fs = fixesIn(p, c)
            let pts = pointsIn(p, c, fs)
            if (fs.isEmpty && pts.isEmpty && !c.pr.ufh) || !ppDrawn(c) { continue }
            var what: [String] = []
            for ty in FIX_TYPES {
                let n = fs.filter { $0.t == ty.id }.count
                if n > 0 { what.append((n > 1 ? "\(n) × " : "") + t("sx.t." + ty.id)) }
            }
            if c.pr.ufh { what.append(t("sx.s.ufh")) }
            let joined = what.joined(separator: ", ")
            var row: [Cell] = [cell(names[c.id] ?? ""), cell(joined.isEmpty ? "—" : joined), rcell("\(pts.count)")]
            if withLen {
                let m = runsIn(calc.routes, c.id).reduce(0.0) { $0 + $1.len } / 1000
                row.append(rcell(ppD1(m) + " " + t("u.m")))
            }
            rows.append(row)
        }
        table(rows, head: 1)
    }

    /// The pipe by kind (the advanced app's PDF).
    private func ppLenTable(_ calc: PlumbCalc) {
        let k = calc.count
        var lens: [[Cell]] = [[th(t("sx.r.kind")), th(t("sx.r.len"), right: true)]]
        for kind in ["cold", "hot", "hs", "hr"] {
            let v = calc.routes.lenOf(kind)
            if v > 0 { lens.append([cell(t("sx.o." + kind)), rcell(ppD1(v / 1000) + " " + t("u.m"))]) }
        }
        if k.drain110 > 0 { lens.append([cell(t("sx.c.drain", ["d": 110])), rcell(ppD1(k.drain110) + " " + t("u.m"))]) }
        if k.drain50 > 0 { lens.append([cell(t("sx.c.drain", ["d": 50])), rcell(ppD1(k.drain50) + " " + t("u.m"))]) }
        if k.ufhM > 0 { lens.append([cell(t("sx.c.ufh")), rcell(ppD1(k.ufhM) + " " + t("u.m"))]) }
        if lens.count > 1 {
            table(lens, head: 1)
            fn(t("sx.r.lenNote"))
        }
    }

    /// The legend: the fixtures, the riser, the pipes' colours.
    private func ppLegend(_ p: Project, _ calc: PlumbCalc) {
        var all: [PlFix] = []
        for c in calc.ctxs { all += fixesIn(p, c) }
        let rs = calc.routes.riser
        let hot = rs?.hot ?? true
        let types = legendFix(all) + (rs != nil ? ["riser"] : [])
        h2(t("el.r.legend"))
        let colW = CW / 3
        var i = 0
        while i < types.count {
            let row = Array(types[i..<min(i + 3, types.count)])
            i += 3
            ensure(18); space(0)
            let top = y
            let labels = row.map { k in a(k == "riser" ? t("sx.riser") : t("sx.t." + k), ui(8.5, 400)) }
            let sizes = labels.map { measure($0, colW - 24) }
            let h = max(16, sizes.map(\.height).max() ?? 0)
            draw { ctx in
                ctx.withCGContext { cg in
                    for (j, k) in row.enumerated() {
                        let x = PX + CGFloat(j) * colW
                        let at = CGPoint(x: x + 9, y: top + h / 2)
                        if k == "riser" { riserSymbol(cg, at, 6, hot) } else { fixSymbol(cg, k, at, 7) }
                    }
                }
                for (j, lb) in labels.enumerated() {
                    let x = PX + CGFloat(j) * colW
                    drawText(ctx, lb, CGRect(x: x + 22, y: top + (h - sizes[j].height) / 2, width: colW - 24, height: sizes[j].height))
                }
            }
            y += h + 3
        }
        ensure(16); space(0)
        let gTop = y
        var kinds: [String] = []
        for k in ["cold", "hot", "drain", "hs", "hr"] {
            let has = calc.routes.runs.contains { $0.kind == k } || (k == "drain" && !calc.routes.drains.isEmpty)
            if has { kinds.append(k) }
        }
        let keys = kinds.map { "sx.o." + $0 } + (calc.routes.loops.isEmpty ? [] : ["sx.s.ufh"])
        let gLab = keys.map { a(t($0), ui(8.5, 400)) }
        let gSize = gLab.map { measure($0) }
        draw { ctx in
            var x = PX
            for (j, k) in keys.enumerated() {
                let rgb = k == "sx.s.ufh" ? UFH_RGB : kindRgb(String(k.dropFirst(5)))
                let w: CGFloat = k == "sx.o.drain" ? 4 : 2.5
                ctx.line(eColor(rgb), CGPoint(x: x, y: gTop + 7), CGPoint(x: x + 14, y: gTop + 7), w)
                drawText(ctx, gLab[j], CGRect(x: x + 18, y: gTop + 7 - gSize[j].height / 2, width: gSize[j].width + 1, height: gSize[j].height))
                x += 18 + gSize[j].width + 12
            }
        }
        y += 16; after(6)
    }

    /// The heating: each room's need, its radiators and its underfloor loops.
    private func ppHeat(_ p: Project, _ calc: PlumbCalc, _ names: [String: String]) {
        var anyRad = false
        for c in calc.ctxs where fixesIn(p, c).contains(where: { $0.t == "rad" }) { anyRad = true }
        if !anyRad && calc.routes.loops.isEmpty { return }
        h2(t("sx.s.heat"))
        var hr: [[Cell]] = [[th(t("sx.r.room")), th(t("sx.heatNeed"), right: true), th(t("sx.t.rad"), right: true), th(t("sx.s.ufh"))]]
        for c in calc.ctxs {
            let rr = fixesIn(p, c).filter { $0.t == "rad" }
            let lp = calc.routes.loops.first { $0.roomId == c.id }
            if (rr.isEmpty && lp == nil) || !ppDrawn(c) { continue }
            let need = "\(tInt(c.areaM2 * Double(W_M2))) W"
            let radW = rr.reduce(0) { $0 + radWatts($1) }
            let rad = rr.isEmpty ? "—" : "\(rr.count) · \(radW) W"
            var ufh = "—"
            if let lp {
                let v = t("sx.loopV", ["n": lp.n, "s": lp.step / 10, "a": ppD1(lp.area)])
                ufh = v + " · " + ppD1(lp.each / 1000) + " " + t("u.m")
            }
            hr.append([cell(names[c.id] ?? ""), rcell(need), rcell(rad), cell(ufh)])
        }
        table(hr, head: 1)
        fn(t("sx.r.heatNote"))
    }

    /// A room from above with its fixtures, riser and pipes, then each wall with fixtures or outlets on it.
    private func ppRoomPage(_ p: Project, _ c: PCtx, _ calc: PlumbCalc, _ name: String) {
        let fs = fixesIn(p, c)
        let pts = pointsIn(p, c, fs)
        let runs = runsIn(calc.routes, c.id)
        let loop = calc.routes.loops.first { $0.roomId == c.id }
        if fs.isEmpty && pts.isEmpty && runs.isEmpty && loop == nil { return }
        let rs = calc.routes.riser
        newPage()
        h2(t("sx.r.roomT", ["r": name]))
        space(0)
        let ph: CGFloat = 250
        let top = y
        draw { ctx in
            ctx.withCGContext { cg in
                let box = CGRect(x: PX, y: top, width: CW, height: ph)
                cg.setFillColor(eCG(0xFFFFFF)); cg.fill(box)
                drawPlumbPlan(cg, c, EPlanMap(c.g.floor, box, 16), fs, pts, rs, runs, loop, 5.5)
                cg.setStrokeColor(eCG(PP_FRAME)); cg.setLineWidth(0.75); cg.stroke(box.insetBy(dx: 0.5, dy: 0.5))
            }
        }
        y += ph; after(8)
        let ws = c.g.walls.filter { w in
            pts.contains { $0.wall == w.id } || fs.contains { $0.wall == w.id } || (rs.map { $0.roomId == c.id && $0.wall == w.id } ?? false)
        }
        ppWalls(c, ws, fs, pts, rs, runs)
    }

    /// The walls two by two, each straight on.
    private func ppWalls(_ c: PCtx, _ ws: [TWall], _ fs: [PlFix], _ pts: [APt], _ rs: PlRiser?, _ runs: [PRun]) {
        let bw = (CW - 10) / 2, bh: CGFloat = 150
        let lAttrs = attrs(ui(6.5, 600))
        let u = unit, isEn = en
        let riserWord = t("sx.riser")
        let label: (String) -> NSAttributedString = { s in
            let text = s == "riser" ? riserWord : Geo.fmtLen(Int(s), u, isEn)
            return NSAttributedString(string: text, attributes: lAttrs)
        }
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
                        drawPlumbWall(cg, c, w, EWallMap(w.len, c.g.H, box, 10, 12), fs, pts, rs, runs, label, minR: 3)
                        cg.setStrokeColor(eCG(PP_FRAME)); cg.setLineWidth(0.75); cg.stroke(box.insetBy(dx: 0.5, dy: 0.5))
                    }
                }
            }
            y += need; after(10)
        }
    }
}
