import SwiftUI
import UIKit

/*
 * Furniture orders' documents (furniture plan section 10; Android report/FurniturePages.kt), on the report's A4 pages:
 * the customer's quote (3D views, materials and colours, the price and terms, the front drawings; never the cost, cut
 * list or profit) and the workshop pack (sheets, cut list, sheet layouts, hardware, modules, cost and profit).
 */

private let F_INK = Color(argb: 0xFF0E1C36)
private let F_INK3 = Color(argb: 0xFF3E4A61)
private let F_INK3U = UIColor(red: 0x3E / 255, green: 0x4A / 255, blue: 0x61 / 255, alpha: 1)
private let F_RULE = Color(argb: 0xFF9AA8BF)
private let F_FIG = Color(argb: 0xFFC3CEDF)
private let SHEET_BG = Color(argb: 0xFFF3F6FA)
private let PART_BG = Color(argb: 0xFFDDE6F5)

/// A front drawing for the documents: its wall (nil for a wardrobe), its viewBox and how to draw it.
struct FrontFig { let wall: String?; let vw: CGFloat; let vh: CGFloat; let draw: (GraphicsContext) -> Void }

/// The fronts of f as the documents show them: each kitchen wall (and the island), or the wardrobe, with sizes.
func frontFigures(_ f: Furniture, _ room: Room?, _ ws0: Workshop, _ mats: [Mat]) -> [FrontFig] {
    let ws = wsOf(f, ws0)
    if f.kind == "wardrobe" {
        // each cabinet of the piece (a stenka's, a corner wardrobe's), drawn from its own bottom; a bed or a table has none
        let front = rgbOf(mats.first { $0.id == f.mats.front }?.rgb ?? "#CDBFAE"), carcass = rgbOf(mats.first { $0.id == f.mats.carcass }?.rgb ?? "#F5F5F2")
        var out: [FrontFig] = []
        // a piece opened by its edge (the mirror cabinet) shows no push mark
        let edge = opensByEdge(f)
        for box in f.modules where box.type == "wardrobe" {
            var m0 = box; m0.elev = 0
            let m = m0
            let lay = KLay(m.w, outerH(m, ws), 360, true)
            out.append(FrontFig(wall: nil, vw: lay.vw, vh: lay.vh) { c in
                Theme.shared.onPaper {
                    c.line(PC.ink, CGPoint(x: lay.x0 - 10, y: lay.yF), CGPoint(x: lay.x(m.w) + 10, y: lay.yF), 2)
                    drawWard(c, lay, m, m.x, ws, carcass, front, -1, true, [:], labels: false, edge: edge)
                    var acc = 0
                    wardDims(c, lay, [0] + m.sections.map { acc += $0.w; return acc }, m.w, outerH(m, ws), 0)
                }
            })
        }
        return out
    }
    return kRuns(f, room, true).filter { r in f.modules.contains { $0.wall == r.wall } }.map { run in
        let lay = KLay(runLen(f, run), roomH(room), 360, true, runExt(f, run))
        return FrontFig(wall: run.wall, vw: lay.vw, vh: lay.vh) { c in Theme.shared.onPaper { drawRun(c, lay, f, run, room, ws, mats, nil, [:]) } }
    }
}

private extension Doc {
    func metres(_ mm: Int) -> String { let v = (mm + 50) / 100; return "\(v / 10)\(en ? "." : ",")\(v % 10)" }

    /// "Oshxona 1 (L, 5,4 pog. m): korpus, fasadlar, stoleshnitsa, furnitura" or "Shkaf 1 (2400 × 2500, 4 bo‘lim, 7 eshik)".
    func pieceText(_ f: Furniture, _ ws: Workshop?) -> String {
        let name = dn(f.name, l)
        // a wall-hung piece: its box's size, and its height off the floor on a line of its own (founder 29 Oct 2026)
        let floor: String = floorElev(f).map { "\n" + t("fz.offFloor", ["v": $0, "u": t("u.mm")]) } ?? ""
        // a bed, a table, a stenka, a corner piece…: its own sizes (the first box alone would tell the wrong ones)
        if f.kind == "wardrobe" && (isItemPiece(f) || boxes(f).count > 1) {
            let s = sizeLine(f, ws ?? Workshop(), t("u.mm"))
            return (s.isEmpty ? name : name + " (" + s + ")") + floor
        }
        if f.kind == "wardrobe" {
            guard let m = wardOf(f) else { return name }
            let doors = m.sections.reduce(0) { $0 + ($1.fronts.kind == "door" ? $1.fronts.n : 0) }
            let h: Int = ws.map { outerH(m, $0) } ?? m.h
            return t("fd.lineWb", ["n": name, "w": m.w, "h": h, "g": m.d, "s": m.sections.count, "d": doors]) + floor
        }
        return t("fd.lineK", ["n": name, "l": t("kt.l" + f.layout), "v": metres(runMm(f))])
    }

    /// Pieces' own 3D pictures two by two, each with its name over it; titled: the views' heading first (no saved view
    /// printed one).
    func pieceShots(_ items: [(String, UIImage)], titled: Bool) {
        if items.isEmpty { return }
        if titled { h2(t("r.views")) }
        space(0)
        let w = (CW - 8) / 2
        var i = 0
        while i < items.count {
            let pair = Array(items[i..<min(items.count, i + 2)])
            let caps: [NSAttributedString] = pair.map { a($0.0, ui(9.5, 600)) }
            let capH: CGFloat = caps.map { measure($0, w).height }.max() ?? 0
            let imgH: CGFloat = pair.map { w * $0.1.size.height / max(1, $0.1.size.width) }.max() ?? 0
            let h = capH + 3 + imgH + 1.5
            if y + h > LIMIT { newPage(); space(0) }
            let top = y
            for (k, it) in pair.enumerated() {
                let x = PX + CGFloat(k) * (w + 8)
                let cap = caps[k], img = it.1
                let ih = w * img.size.height / max(1, img.size.width)
                draw { ctx in
                    drawText(ctx, cap, CGRect(x: x, y: top, width: w, height: capH))
                    let r = CGRect(x: x, y: top + capH + 3, width: w, height: ih)
                    ctx.draw(Image(uiImage: img), in: r.insetBy(dx: 0.75, dy: 0.75))
                    ctx.stroke(Path(r.insetBy(dx: 0.375, dy: 0.375)), with: .color(F_FIG), lineWidth: 0.75)
                }
            }
            y += h + 8
            i += 2
        }
        pend = 0
    }

    func figure(_ title: String, _ vw: CGFloat, _ vh: CGFloat, _ fig: @escaping (GraphicsContext) -> Void) {
        // two figures a page: at most 300 high, centred
        let fw = min(CW, 300 * vw / vh), h = fw * vh / vw, fx = PX + (CW - fw) / 2
        let cap = a(title, ui(10, 600)), cS = measure(cap, CW)
        space(10)
        if y + cS.height + 4 + h > LIMIT { newPage(); space(10) }
        let top = y
        draw { ctx in
            drawText(ctx, cap, CGRect(x: PX, y: top, width: CW, height: cS.height))
            let ft = top + cS.height + 4
            ctx.fill(Path(CGRect(x: fx, y: ft, width: fw, height: h)), with: .color(.white))
            var c = ctx
            c.clip(to: Path(CGRect(x: fx, y: ft, width: fw, height: h)))
            c.translateBy(x: fx, y: ft); c.scaleBy(x: fw / vw, y: fw / vw)
            fig(c)
            ctx.stroke(Path(CGRect(x: fx + 0.375, y: ft + 0.375, width: fw - 0.75, height: h - 0.75)), with: .color(F_FIG), lineWidth: 0.75)
        }
        y += cS.height + 4 + h; after(10)
    }

    /// Carcass, fronts, worktop and handles as colour swatches with their names.
    /// A board's or the handle's name in the report's language: the app's own preset ("LDSP 16 · Oq", "Tutqich skoba 128")
    /// by its strings key; a name the workshop typed or changed stays as typed.
    func presetName(_ id: String?, _ name: String) -> String {
        if let m = MAT_PRESETS.first(where: { $0.id == id && $0.name == name }), Strings.has("mp." + m.id) { return t("mp." + m.id) }
        if let h = HW_PRESETS.first(where: { ($0.id == id || id == nil) && $0.name == name }), Strings.has("hp." + h.id) { return t("hp." + h.id) }
        return name
    }

    func materials(_ sn: Snap) {
        var entries: [(String, String, String?)] = []   // role label, name, colour
        func mat(_ id: String) -> Mat? { sn.fmats.first { $0.id == id } }
        for (role, get) in [("carcass", { (f: Furniture) in f.mats.carcass }), ("front", { (f: Furniture) in f.mats.front })] {
            var ids: [String] = []
            for f in sn.furniture where !ids.contains(get(f)) { ids.append(get(f)) }
            for id in ids {
                let who = ids.count > 1 ? " (" + sn.furniture.filter { get($0) == id }.map { dn($0.name, l) }.joined(separator: ", ") + ")" : ""
                let shown = mat(id).map { presetName($0.id, $0.name) } ?? id
                entries.append((t("wd." + role) + who, shown, mat(id)?.rgb))
            }
        }
        // a two-tone kitchen's upper fronts; each kitchen's worktop and backsplash (PieceLook.swift)
        var ups: [String] = [], tops: [String] = [], splashes: [String] = []
        for f in sn.furniture {
            if isTwoTone(f), let up = f.mats.frontUp, !ups.contains(up) { ups.append(up) }
            if f.kind == "kitchen", !tops.contains(worktopOf(f)) { tops.append(worktopOf(f)) }
            if (f.kx?.splash ?? 0) > 0, let sp = f.mats.splash, !splashes.contains(sp) { splashes.append(sp) }
        }
        for id in ups { entries.append((t("lk.upFront"), mat(id).map { presetName($0.id, $0.name) } ?? id, mat(id)?.rgb)) }
        for id in tops { if let w = mat(id) { entries.append((t("mt.wtK"), presetName(w.id, w.name), w.rgb)) } }
        for id in splashes { if let w = mat(id) { entries.append((t("mt.splashK"), presetName(w.id, w.name), w.rgb)) } }
        if !sn.fhandles.trimmingCharacters(in: .whitespaces).isEmpty && sn.furniture.contains(where: { hasHandles($0) }) {
            entries.append((t("hk.handle"), presetName(nil, sn.fhandles), nil))
        }
        if entries.isEmpty { return }
        h2(t("fd.mats"))
        // the swatch in a narrow first column
        let rows = entries.map { e in [cell(""), cell(e.0, ui(10, 600)), cell(dn(e.1, l))] }
        space(6)
        let top = y
        table(rows, fixed: [28, (CW - 28) * 0.42, (CW - 28) * 0.58], top: 0, breakable: false)
        let rowH = measure(a(" ", ui(10))).height + 6
        // each row as tall as the table made it (a long list of pieces wraps), the swatch by its first line
        let wRole = (CW - 28) * 0.42, wName = (CW - 28) * 0.58
        var yy = top
        for e in entries {
            let at = yy
            if let rgb = e.2 {
                draw { ctx in
                    let r = CGRect(x: PX + 6, y: at + (rowH - 11) / 2, width: 16, height: 11)
                    ctx.fill(Path(r), with: .color(matColor(rgb))); ctx.stroke(Path(r), with: .color(F_RULE), lineWidth: 0.75)
                }
            }
            let roleH: CGFloat = measure(a(e.0, ui(10, 600)), wRole - 10).height
            let nameH: CGFloat = measure(a(dn(e.1, l), ui(10)), wName - 10).height
            yy += max(rowH, max(roleH, nameH) + 6)
        }
    }

    /// The price: a line a piece of furniture, delivery and installation, the total, the prepayment, the rest and the time.
    func priceBlock(_ sn: Snap) {
        // the price stays on one page with its total and terms
        // the three price options' lines are their own block (TierPages.swift)
        let lines = sn.flines.filter { !isTierLine($0) }
        ensure(40 + CGFloat(max(lines.count, sn.furniture.count) + 5) * 17 + 50)
        h2(t("fd.price"))
        let total = Decimal(string: sn.ftotal) ?? 0
        var rows: [[Cell]] = []
        if lines.isEmpty { for f in sn.furniture { rows.append([cell(pieceText(f, sn.fws), span: 2)]) } }
        for ln in lines {
            let f = sn.furniture.first { $0.id == ln.key }
            let text = ln.key == "deliver" ? t("fd.deliver") : f.map { pieceText($0, sn.fws) } ?? ln.key
            rows.append([cell(text), rcell(money(Decimal(string: ln.amount) ?? 0))])
        }
        table(rows, fixed: [CW * 0.72, CW * 0.28])
        fn(t("fd.priceNote"))
        ensure(90)
        var x = total * Decimal(sn.fprepay) / 100, pre = Decimal()
        NSDecimalRound(&pre, &x, 0, .plain)
        let cur = Money.cur(sn.currency, l)
        table([
            [cell(t("fd.total"), ui(11, 700)), Cell([a(money(total) + " " + cur, num(11, 700))], right: true, dbl: true)],
            [cell(t("fd.prepay", ["p": sn.fprepay])), rcell(money(pre))],
            [cell(t("fd.onInstall")), rcell(money(total - pre))],
            [cell(t("fd.time")), rcell(t("fd.days", ["d": sn.fdays, "i": sn.finst]), ui(10, 600, align: .right))]
        ], fixed: [CW * 0.6, CW * 0.4], breakable: false)
        fn(t("fd.valid"))
    }

    func bandText(_ r: CutRow) -> String {
        let b = r.p.bands, all = [b.l1, b.l2, b.s1, b.s2]
        let thick = all.filter { $0 == 2 }.count, thin = all.filter { $0 == 1 }.count
        let parts = [thick > 0 ? "2 mm × \(thick)" : nil, thin > 0 ? (en ? "0.4" : "0,4") + " × \(thin)" : nil].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    func modText(_ m: Module) -> String { m.type == "wardrobe" ? t("kn.wardrobe") : t("kn." + kindOf(m)) }

    func frontText(_ m: Module) -> String {
        if m.type == "wardrobe" { return t("fw.secs", ["n": m.sections.count, "d": m.sections.reduce(0) { $0 + ($1.fronts.kind == "door" ? $1.fronts.n : 0) }]) }
        switch m.fronts.kind {
        case "door": return t(m.fronts.n >= 2 ? "km.f2" : "km.f1")
        case "drawer": return t("km.fd") + " \(m.fronts.n)"
        case "panel": return t("fp.panel")
        default: return "—"
        }
    }

    /// Two sheets a page: the trimmed area, the parts with their cut list numbers.
    func sheets(_ lay: MatLayout, _ number: [Int: Int], _ name: String, _ ws: Workshop) {
        // the remnants used first (their own size, no trim), then the new sheets
        let boards: [SheetPlan] = lay.rems + lay.sheets
        for (bi, s) in boards.enumerated() {
            let rem = s.rem != nil
            let bl = s.rem?.L ?? lay.sheetL, bw = s.rem?.W ?? lay.sheetW
            let i = bi - lay.rems.count
            // small enough for two sheets a page; a remnant at the sheets' scale
            let w0 = min(CW, 296 * CGFloat(lay.sheetL) / CGFloat(lay.sheetW)), k = w0 / CGFloat(lay.sheetL)
            let w = CGFloat(bl) * k, h = CGFloat(bw) * k
            let capText = rem ? t("bz.remBoard", ["m": dn(name, l), "l": bl, "w": bw])
                : t("fw.sheet", ["m": dn(name, l), "i": i + 1, "n": lay.sheets.count, "w": Int(lay.waste * 100)])
            let cap = a(capText, ui(10, 600)), cS = measure(cap, CW)
            space(10)
            if y + cS.height + 4 + h + 14 > LIMIT { newPage(); space(10) }
            let top = y + cS.height + 4
            let labels: [(Placed, NSAttributedString, CGSize)] = s.placed.map { pl in
                let sz = max(6, min(11, min(CGFloat(pl.w), CGFloat(pl.h)) * k * 0.45))
                let lr = a("\(number[pl.row] ?? 0)", num(sz, 700))
                return (pl, lr, measure(lr))
            }
            let note = a(t("fw.sheetNote", ["l": lay.sheetL, "w": lay.sheetW, "k": ws.kerf, "t": ws.trim]), ui(8.5, 400, F_INK3U)), nS = measure(note, CW)
            let tr0: CGFloat = rem ? 0 : CGFloat(ws.trim) * k
            draw { ctx in
                drawText(ctx, cap, CGRect(x: PX, y: top - cS.height - 4, width: CW, height: cS.height))
                let sheet = CGRect(x: PX, y: top, width: w, height: h)
                ctx.fill(Path(sheet), with: .color(SHEET_BG)); ctx.stroke(Path(sheet), with: .color(F_INK), lineWidth: 1)
                for (pl, lr, ls) in labels {
                    let r = CGRect(x: PX + tr0 + CGFloat(pl.x) * k, y: top + tr0 + CGFloat(pl.y) * k, width: CGFloat(pl.w) * k, height: CGFloat(pl.h) * k)
                    ctx.fill(Path(r), with: .color(PART_BG)); ctx.stroke(Path(r), with: .color(F_INK3), lineWidth: 0.6)
                    if ls.width < r.width - 2 && ls.height < r.height - 1 {
                        drawText(ctx, lr, CGRect(x: r.midX - ls.width / 2, y: r.midY - ls.height / 2, width: ls.width + 1, height: ls.height))
                    }
                }
                drawText(ctx, note, CGRect(x: PX, y: top + h + 3, width: CW, height: nS.height))
            }
            y = top + h + 3 + nS.height; after(8)
        }
    }
}

/* ---------------- the customer's quote ---------------- */

/// shot: a piece's own 3D picture (Report/PdfShots.swift; the ones made so far by default).
func furniturePages(_ sn: Snap, draft: Bool, meta: QuoteMeta?, image: @escaping (String) -> UIImage?, now: Ms = nowMs(), prices: Bool = true,
                    shot: ((Furniture) -> UIImage?)? = nil) -> [RPage] {
    // without prices (the simple app) it is the design: dated, no draft mark, no price block
    let d = Doc(sn, draft && prices, meta, image, now)
    d.draftTitle = "fd.draft"; d.quoteTitle = prices ? "fd.quote" : "rpt.design"; d.makerKey = "fd.maker"
    if !prices { d.subLine = fmtDate(now) }
    d.newPage(); d.parties()
    if sn.pdf.views {
        d.views()
        // each piece without a saved view of its room: its own 3D picture, after the saved views (founder 29 Oct 2026)
        let get = shot ?? { PdfShots.shared.image($0, sn) }
        let items: [(String, UIImage)] = pdfShotPieces(sn).compactMap { f in get(f).map { (dn(f.name, d.l), $0) } }
        let saved = sn.rooms.contains { !$0.room.views.isEmpty }
        d.pieceShots(items, titled: !saved)
    }
    d.materials(sn)
    if prices { d.priceBlock(sn); d.tierBlock(sn) }
    // the front drawings, one per wall or wardrobe
    let ws = sn.fws ?? Workshop()
    let figs = sn.furniture.flatMap { f in frontFigures(f, sn.rooms.first { $0.room.id == f.roomId }?.room, ws, sn.fmats).map { (f, $0) } }
    if !figs.isEmpty {
        d.newPage(); d.h2(d.t("fd.fronts"))
        for (f, fig) in figs {
            let side: String
            switch fig.wall {
            case nil: side = ""
            case ISLAND?: side = " · " + d.t(f.layout == "P" ? "kt.peninsula" : "kt.island")
            default: side = " · " + d.t("kt.wallN", ["w": fig.wall!])
            }
            d.figure(dn(f.name, d.l) + side, fig.vw, fig.vh, fig.draw)
        }
        d.fn(d.t("fd.frontNote"))
    }
    return d.finish()
}

/* ---------------- the workshop pack ---------------- */

/// Readable labels for the modules: each wall's units A1, A2… (lower row first), the island O1…, wardrobes Sh1.
func labelled(_ fs: [Furniture]) -> [Furniture] {
    var ward = 0
    return fs.map { f in
        var g = f
        if f.kind == "wardrobe" { g.modules = f.modules.map { m in ward += 1; var n = m; n.label = "Sh\(ward)"; return n }; return g }
        var n: [String: Int] = [:], labels: [String: String] = [:]
        let order = f.modules.enumerated().sorted { (isUpper($0.element) ? 1 : 0, $0.offset) < (isUpper($1.element) ? 1 : 0, $1.offset) }.map(\.element)
        for m in order {
            let w = m.wall == ISLAND ? "O" : (m.wall ?? "?")
            let k = (n[w] ?? 0) + 1; n[w] = k; labels[m.id] = "\(w)\(k)"
        }
        g.modules = f.modules.map { var x = $0; x.label = labels[$0.id] ?? $0.label; return x }
        return g
    }
}

private func fmtQty(_ d: Doc, _ q: Double) -> String {
    if q == q.rounded(.down) { return "\(Int(q))" }
    let s = String(format: "%.1f", q)
    return d.en ? s : s.replacingOccurrences(of: ".", with: ",")
}

/// The pack: summary, cut list a material, the sheets, hardware, modules, cost and profit. Not for the customer.
func workshopPages(_ sn: Snap, _ ws: Workshop, _ mats: [Mat], _ hws: [Hw], _ pr: Priced, _ mode: String, now: Ms = nowMs(), rems: [Remnant] = []) -> [RPage] {
    let d = Doc(sn, false, nil, { _ in nil }, now)
    d.quoteTitle = "fw.title"
    d.subLine = d.t("fw.sub", ["d": fmtDate(now)])
    let fs = labelled(sn.furniture)
    let cost = costOf(fs, ws, mats, hws, rems: rems)
    func matName(_ id: String) -> String { mats.first { $0.id == id }.map { d.presetName($0.id, $0.name) } ?? id }
    d.newPage()
    d.para(d.a(dn(sn.name, d.l) + " · " + fs.map { dn($0.name, d.l) }.joined(separator: " + "), d.ui(11, 600)), top: 0, bottom: 4)
    d.para(d.a(d.t("fw.inside"), d.ui(9, 700, F_INK3U)), top: 0, bottom: 8)
    // 1. what to buy
    d.h2(d.t("fw.summary"))
    var sum: [[Cell]] = [[d.th(d.t("fw.c.mat")), d.th(d.t("fw.c.sheets"), right: true), d.th(d.t("fw.c.parts"), right: true), d.th(d.t("fw.c.waste"), right: true)]]
    for lay in cost.layouts {
        let parts = cost.rows.filter { $0.mat == lay.mat }.reduce(0) { $0 + $1.p.qty }
        sum.append([d.cell(dn(matName(lay.mat), d.l)), d.rcell("\(lay.sheets.count)"), d.rcell("\(parts)"), d.rcell("\(Int(lay.waste * 100)) %")])
    }
    for ln in cost.lines where ln.group == "mat" && ln.unit == "m" {
        sum.append([d.cell(dn(matName(ln.key), d.l)), d.rcell(fmtQty(d, ln.qty) + " " + d.t("u.m")), d.cell(""), d.cell("")])
    }
    d.table(sum, head: 1)
    for lay in cost.layouts where !lay.unplaced.isEmpty { d.fn(d.t("fw.unplaced", ["m": matName(lay.mat), "n": lay.unplaced.count])) }
    // 2. the cut list, a material at a time
    var mats0: [String] = []
    for r in cost.rows where !mats0.contains(r.mat) { mats0.append(r.mat) }
    var number: [Int: Int] = [:]
    for mat in mats0 { var k = 0; for (i, r) in cost.rows.enumerated() where r.mat == mat { k += 1; number[i] = k } }
    for mat in mats0 {
        let list = cost.rows.enumerated().filter { $0.element.mat == mat }
        d.h2(d.t("fw.cut", ["m": dn(matName(mat), d.l), "n": list.reduce(0) { $0 + $1.element.p.qty }]))
        var rows: [[Cell]] = [[d.th("№"), d.th(d.t("fw.c.part")), d.th(d.t("fw.c.size"), right: true), d.th(d.t("fw.c.cut"), right: true), d.th(d.t("fw.c.qty"), right: true), d.th(d.t("fw.c.band"))]]
        for (i, r) in list {
            rows.append([d.cell("\(number[i] ?? 0)"), d.cell(d.t(r.p.key) + (r.p.grain ? " ↕" : "")), d.rcell("\(r.p.L) × \(r.p.W)"), d.rcell("\(r.cutL) × \(r.cutW)"),
                         d.rcell("\(r.p.qty)"), d.cell(d.bandText(r), d.num(9.5))])
        }
        d.table(rows, head: 1)
    }
    d.fn(d.t("fw.cutNote", ["b": "\(ws.band10 / 10)\(d.en ? "." : ",")\(ws.band10 % 10)"]))
    // 3. the sheets
    for lay in cost.layouts { d.sheets(lay, number, matName(lay.mat), ws) }
    // 4. hardware
    d.newPage(); d.h2(d.t("fw.hw"))
    var hr: [[Cell]] = [[d.th(d.t("fw.c.name")), d.th(d.t("fw.c.qty"), right: true), d.th(d.t("fw.c.price"), right: true), d.th(d.t("fw.c.sum"), right: true)]]
    for ln in cost.lines where ln.group == "hw" {
        let hw = hws.first { $0.id == ln.key }
        let unitW = ln.unit == "m" ? " " + d.t("u.m") : ln.unit == "m2" ? " " + d.t("u.m2") : ""
        hr.append([d.cell(hw.map { d.presetName($0.id, $0.name) } ?? d.t("hk." + ln.key)), d.rcell(fmtQty(d, ln.qty) + unitW),
                   d.rcell(ln.missing ? "—" : d.money(ln.price)), d.rcell(d.money(ln.amount))])
    }
    hr.append([d.cell(d.t("r.total"), d.ui(10, 700), span: 3), d.rcell(d.money(cost.sum("hw")), d.num(10, 700))])
    d.table(hr, head: 1)
    // 5. the modules and their sizes
    d.h2(d.t("fw.mods"))
    var mr: [[Cell]] = [[d.th("№"), d.th(d.t("fw.c.name")), d.th(d.t("fw.c.wxhxd"), right: true), d.th(d.t("fw.c.fronts"))]]
    for f in fs { for m in f.modules { mr.append([d.cell(m.label), d.cell(d.modText(m)), d.rcell("\(m.w) × \(m.h) × \(m.d)"), d.cell(d.frontText(m))]) } }
    d.table(mr, head: 1)
    // 6. cost, price, profit
    d.ensure(140); d.h2(d.t("fw.cost"))
    var cr: [[Cell]] = [("mat", "fw.g.mat"), ("hw", "fw.g.hw"), ("lab", "fw.g.lab")].map { g, k in [d.cell(d.t(k)), d.rcell(d.money(cost.sum(g)))] }
    cr.append([d.cell(d.t("fw.costT"), d.ui(10, 700)), d.rcell(d.money(pr.cost.total), d.num(10, 700))])
    cr.append([d.cell(d.t("fw.priceT", ["m": d.t("fpm." + mode)])), d.rcell(d.money(pr.price), d.num(10, 700))])
    let pct = pr.profitPct10
    cr.append([d.cell(d.t("fw.profit")), d.rcell(d.money(pr.profit) + " · " + "\(pct / 10)\(d.en ? "." : ",")\(abs(pct % 10)) %", d.num(10, 700))])
    d.table(cr, fixed: [CW * 0.6, CW * 0.4], breakable: false)
    if cost.missing > 0 { d.fn(d.t("kt.noPrice", ["n": cost.missing])) }
    return d.finish()
}
