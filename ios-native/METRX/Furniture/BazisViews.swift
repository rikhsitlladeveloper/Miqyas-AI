import SwiftUI

/*
 * Ideas taken from Bazis Mebelshchik, kept simple for a phone (23 Oct 2026, memory bazis-ideas; Android
 * ui/furniture/BazisViews.kt): a corner piece's shape as pictures and whichever sides were measured; "Change for all"
 * fronts and handles; one Check list before sending; the live price in the designers; the workshop's remnants; a part
 * of the parts list lit up in 3D. The rules are in Furniture/Core (FurnChecks, FurnSwap, Remnants, FurnLabels, Steps).
 */

private var bzEn: Bool { AppSettings.shared.lang == .en }
private let BZ_GOOD = Color(argb: 0xFF15803D)
private let BZ_DARK = Color(argb: 0xFF0E1C36)
private let BZ_STRIP = Color(argb: 0xFFB7C3D9)
private let BZ_HI = Color(argb: 0xFFF59E0B)

/* ---------------- a corner piece's shape and measured sides, as pictures ---------------- */

/// A choice drawn as small top-down pictures: a corner piece's shapes, or which of its sides were measured (sh its shape).
struct PicsAsk: View {
    let m: FModelDef
    let s: SizeStep
    let cur: Int
    let sh: Int
    let onPick: (Int) -> Void
    var body: some View {
        let rows: [[Int]] = stride(from: 0, to: s.opts.count, by: 2).map { i in Array(i..<min(i + 2, s.opts.count)) }
        VStack(alignment: .leading, spacing: 8) {
            T(tr(s.label), ui(21, 800, G.ink, lh: 1.2)).padding(.top, 4)
            T(tr(s.help), ui(13, 400, G.ink2, lh: 1.4))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(row, id: \.self) { i in
                        PicCard(m: m, key: s.key, opt: s.opts[i], i: i, sh: sh, on: i == cur) { onPick(i) }
                    }
                    if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One picture of PicsAsk: the piece from above, its name and a line about it.
private struct PicCard: View {
    let m: FModelDef
    let key: String
    let opt: String
    let i: Int
    let sh: Int
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let name = tr(opt)
        let shapePic = key == "sh"
        VStack(alignment: .leading, spacing: 6) {
            Canvas { c, size in
                if shapePic { cornerPic(c, size, m, i, -1) } else { cornerPic(c, size, m, sh, i) }
            }
            .aspectRatio(1.25, contentMode: .fit)
            .background(Color(argb: 0xFFF6F8FC))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            T(name, ui(14, 700, on ? G.cobalt2 : G.ink, lh: 1.25), lines: 2)
            T(tr(opt + ".s"), ui(12, 400, G.ink2, lh: 1.3), lines: 3)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.75)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("bz.pic." + opt)
    }
}

private let P_WALL = Color(argb: 0xFF9AA8BF)
private let P_PIECE = Color(argb: 0xFFDDE6F5)
private let P_EDGE = Color(argb: 0xFF3E4A61)
private let P_BLUE = Color(argb: 0xFF3550E0)

/// The way of measuring ms of a corner piece ("out", "in", "wall", a kitchen's "kWall", "kIn"), or "" for a shape picture.
private func measureOf(_ m: FModelDef, _ ms: Int) -> String {
    let all = measuresOf(m)
    if ms < 0 || ms >= all.count { return "" }
    let k = all[ms]
    return k.hasPrefix("bz.ms.") ? String(k.dropFirst(6)) : k
}

/// Draws a corner piece from above in a picture of size, drawn as a right-hand L and mirrored for a left one.
private struct CornerPen {
    let c: GraphicsContext
    let w: CGFloat
    let left: Bool
    func x(_ v: CGFloat) -> CGFloat { left ? w - v : v }
    func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ col: Color, stroke: Bool = false, sw: CGFloat = 1.5) {
        let a = min(x(x0), x(x1)), b = max(x(x0), x(x1))
        let r = CGRect(x: a, y: y0, width: b - a, height: y1 - y0)
        if stroke { c.stroke(Path(r), with: .color(col), lineWidth: sw) } else { c.fill(Path(r), with: .color(col)) }
    }
    func line(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ col: Color, _ sw: CGFloat, dash: Bool = false) {
        var p = Path()
        p.move(to: CGPoint(x: x(x0), y: y0)); p.addLine(to: CGPoint(x: x(x1), y: y1))
        c.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: sw, lineCap: .round, dash: dash ? [6, 5] : []))
    }
    /// A ring at (cx, cy), cx not yet mirrored.
    func ring(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ sw: CGFloat) {
        let rr = CGRect(x: x(cx) - r, y: cy - r, width: 2 * r, height: 2 * r)
        c.stroke(Path(ellipseIn: rr), with: .color(P_EDGE), lineWidth: sw)
    }
}

/// A corner piece from above, its main wall at the top: shape sh (its corner on the right or left, the corner
/// wardrobe's door or open shelves); ms ≥ 0 marks in blue the sides measured that way (arms along the walls, the
/// fronts, the walls themselves).
private func cornerPic(_ c: GraphicsContext, _ size: CGSize, _ m: FModelDef, _ sh: Int, _ ms: Int) {
    let w = size.width, h = size.height
    let left = shapeLeft(m.type, sh)
    let kitchen = m.kind == "kitchen"
    let desk = m.type == "cornerDesk"
    let pad = w * 0.1
    let wallT = w * 0.03
    let depth = h * (kitchen ? 0.2 : 0.24)
    let pen = CornerPen(c: c, w: w, left: left)
    let top = pad, cornerX = w - pad
    // the walls: the main one along the top, the side one down the right
    pen.rect(pad * 0.4, top - wallT, cornerX + wallT, top, P_WALL)
    pen.rect(cornerX, top - wallT, cornerX + wallT, h - pad * 0.4, P_WALL)
    // the arms: as the engine builds them, on the right the main arm runs into the corner, on the left the side arm does
    let a0 = pad * 1.3, bEnd = h - pad * 1.2
    if !left {
        pen.rect(a0, top, cornerX, top + depth, P_PIECE); pen.rect(a0, top, cornerX, top + depth, P_EDGE, stroke: true)
        pen.rect(cornerX - depth, top + depth, cornerX, bEnd, P_PIECE); pen.rect(cornerX - depth, top + depth, cornerX, bEnd, P_EDGE, stroke: true)
    } else {
        pen.rect(a0, top, cornerX - depth, top + depth, P_PIECE); pen.rect(a0, top, cornerX - depth, top + depth, P_EDGE, stroke: true)
        pen.rect(cornerX - depth, top, cornerX, bEnd, P_PIECE); pen.rect(cornerX - depth, top, cornerX, bEnd, P_EDGE, stroke: true)
    }
    if kitchen { kitchenMarks(pen, left, a0, top, cornerX, depth, bEnd) }
    else if desk {
        // the chair in the inner corner
        pen.ring(cornerX - depth * 1.75, top + depth * 1.75, depth * 0.34, 1.4)
    } else if shapeOpen(m.type, sh) {
        // open shelves: their edges seen from above
        for k in 1...3 {
            let q = 0.25 * CGFloat(k)
            if !left { pen.line(cornerX - depth * 2.3, top + depth * q, cornerX - depth - 3, top + depth * q, P_EDGE, 1) }
            else { pen.line(cornerX - depth * q, top + depth + 3, cornerX - depth * q, top + depth * 2.3, P_EDGE, 1) }
        }
    } else {
        doorSwing(c, pen, left, top, cornerX, depth)
    }
    measuredMarks(pen, measureOf(m, ms), a0, top, cornerX, depth, bEnd, pad, wallT, h)
}

/// The sink on the first run, the hob on the next (an L with its corner on the left starts on the side wall).
private func kitchenMarks(_ pen: CornerPen, _ left: Bool, _ a0: CGFloat, _ top: CGFloat, _ cornerX: CGFloat, _ depth: CGFloat, _ bEnd: CGFloat) {
    let sx = a0 + (cornerX - depth - a0) * 0.45
    let hy = top + depth + (bEnd - top - depth) * 0.5
    func sink(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) {
        pen.rect(x0, y0, x1, y1, .white); pen.rect(x0, y0, x1, y1, P_EDGE, stroke: true, sw: 1.2)
    }
    func hob(_ cx: CGFloat, _ cy: CGFloat) {
        for dy in [-0.22, 0.22] as [CGFloat] {
            for dx in [-0.2, 0.2] as [CGFloat] { pen.ring(cx + dx * depth, cy + dy * depth * 1.4, depth * 0.12, 1.2) }
        }
    }
    if !left { sink(sx, top + depth * 0.25, sx + depth * 0.9, top + depth * 0.8); hob(cornerX - depth / 2, hy) }
    else { sink(cornerX - depth * 0.8, hy - depth * 0.45, cornerX - depth * 0.2, hy + depth * 0.45); hob(sx + depth * 0.45, top + depth / 2) }
}

/// The corner door and its swing, from shut (along the opening) to open (into the room), about the hinge.
private func doorSwing(_ c: GraphicsContext, _ pen: CornerPen, _ left: Bool, _ top: CGFloat, _ cornerX: CGFloat, _ depth: CGFloat) {
    let r = depth * 1.3
    let hx = cornerX - depth * (left ? 1 : 2.3), hy = top + depth
    if !left { pen.line(hx, hy, hx, hy + r, P_EDGE, 1.2, dash: true) } else { pen.line(hx, hy, hx - r, hy, P_EDGE, 1.2, dash: true) }
    // a quarter circle from the hinge's right to below it (as Compose's drawArc from 0° to 90°)
    let cx = pen.x(hx)
    var arc = Path()
    for k in 0...24 {
        let a = Double(k) / 24 * Double.pi / 2
        let pt = CGPoint(x: cx + r * CGFloat(cos(a)), y: hy + r * CGFloat(sin(a)))
        if k == 0 { arc.move(to: pt) } else { arc.addLine(to: pt) }
    }
    c.stroke(arc, with: .color(P_EDGE), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
}

/// The sides measured one way, in blue.
private func measuredMarks(_ pen: CornerPen, _ how: String, _ a0: CGFloat, _ top: CGFloat, _ cornerX: CGFloat, _ depth: CGFloat, _ bEnd: CGFloat,
                           _ pad: CGFloat, _ wallT: CGFloat, _ h: CGFloat) {
    let sw: CGFloat = 2.2
    switch how {
    case "out", "kWall":
        pen.line(a0, top + sw, cornerX, top + sw, P_BLUE, sw); pen.line(cornerX - sw, top, cornerX - sw, bEnd, P_BLUE, sw)
    case "in", "kIn":
        pen.line(a0, top + depth, cornerX - depth, top + depth, P_BLUE, sw); pen.line(cornerX - depth, top + depth, cornerX - depth, bEnd, P_BLUE, sw)
    case "wall":
        pen.line(pad * 0.4, top - wallT - sw, cornerX + wallT, top - wallT - sw, P_BLUE, sw)
        pen.line(cornerX + wallT + sw, top - wallT, cornerX + wallT + sw, h - pad * 0.4, P_BLUE, sw)
    default: break
    }
}

/// On the summary: the sides worked out from the ones typed, each marked as such (red when out of what the piece can be).
struct DerivedCard: View {
    let rows: [(String, String, Bool)]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            T(tr("bz.derived"), ui(13.5, 800, G.cobalt2))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 8) {
                    T(r.0, ui(13.5, 500, r.2 ? G.err : G.ink)).frame(maxWidth: .infinity, alignment: .leading)
                    T(r.1, num(15, 700, r.2 ? G.err : G.ink), lines: 1)
                    T(tr("bz.calc"), ui(11.5, 700, G.cobalt2)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.glass(0.8)))
                }
            }
            if rows.contains(where: { $0.2 }) { T(tr("bz.derivedBad"), ui(12.5, 600, G.err, lh: 1.35)) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.blueWash))
        .accessibilityIdentifier("bz.derived")
    }
}

/* ---------------- the live price in the designers (Advanced) ---------------- */

/// A slim bar under a designer: what this piece costs the customer now, and the workshop; it follows every change.
struct LivePrice: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let s = AppSettings.shared
        if s.advanced && !f.modules.isEmpty {
            // a fixed order price has no price a piece: the piece by the margin
            let pr = priceOf([f], byMargin(p.fprice), s.workshop, s.mats, s.hws)
            let price = pr.lines.first { $0.key == f.id }?.amount ?? pr.price
            // the piece's own cost: no installation or delivery (those are the order's, once)
            let cost = costOf([f], wsOf(f, s.workshop), s.mats, s.hws, order: false).total
            HStack(spacing: 10) {
                MIcon("coin", BZ_STRIP, 18, 2)
                T(tr("bz.live"), ui(12.5, 500, BZ_STRIP), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                T(shortMoney(price), num(16, 800, .white), lines: 1)
                T(tr("bz.liveCost", ["v": shortMoney(cost)]), ui(11.5, 500, BZ_STRIP), lines: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BZ_DARK))
            .pressable(0.98) { app.push(.project(id: p.id, tab: "price")) }
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("bz.live")
        }
    }

    private func byMargin(_ fp: FPrice) -> FPrice {
        var x = fp
        if x.mode == "fixed" { x.mode = "margin" }
        return x
    }

    private func shortMoney(_ v: Decimal) -> String {
        let (a, u) = Money.short(p, v, bzEn, tr("pl.mln"))
        return a + " " + (u ?? Money.cur(p.currency))
    }
}

/* ---------------- the one Check list ---------------- */

/// Every problem of the order's pieces: the board rules, how each fits its room, doors that hit, the designers' checks.
func orderIssues(_ p: Project) -> [OrderIssue] {
    let s = AppSettings.shared
    let ws = s.workshop, snap = s.angleSnap
    return orderChecks(p.furniture, ws, s.mats) { f in roomIssues(p, f, ws, snap) }
}

/// What a piece's room adds to the Check list: its fit on its walls, what it is in the way of, its designer's checks.
private func roomIssues(_ p: Project, _ f: Furniture, _ ws: Workshop, _ snap: Bool) -> [OrderIssue] {
    var out: [OrderIssue] = []
    guard let room = roomOf(p, f) else { return out }
    let fws = wsOf(f, ws)
    let inRoom = f.roomId != nil
    let len: (String) -> Int? = { id in inRoom ? wallLen(room, snap, id) : (freeLen(f, id) ?? wallLen(room, snap, id)) }
    let roomH = room.dim("H").v
    if inRoom {
        // how it fits its walls (kept although too big: still said), and what it is in the way of
        let off: Int? = f.kind == "wardrobe" ? runStart(f) : nil
        for it in fitIssues(f, f.walls, len, roomH, ws, off: off) {
            out.append(OrderIssue(f.id, "err", it.key, it.vars.mapValues { AnyHashable($0) }))
        }
        let pw = planWalls(room, snap)
        let others = p.furniture.filter { $0.roomId == room.id && $0.id != f.id }
        for it in placeWarnings(f, others, room, pw, ws) {
            let level = it.key == "fz.doorsHit" || it.key == "fz.hitPiece" ? "err" : "warn"
            out.append(OrderIssue(f.id, level, it.key, it.vars.mapValues { AnyHashable($0) }))
        }
    }
    // the designers' own checks (the board rules and the fit are said above)
    let skip: Set<String> = ["wc.sheet", "wc.shelfWide", "wc.wide", "wc.high"]
    var found: [FCheck] = []
    if f.kind == "kitchen" {
        found = checks(f, kRuns(f, room, snap), fws, room.openings, room.points)
    } else {
        for m in f.modules where m.type == "wardrobe" {
            let wl: Int? = inRoom ? m.wall.flatMap { len($0) } : nil
            found += wardrobeChecks(m, wl, inRoom ? roomH : nil, fws, room.openings, room.points)
        }
    }
    for c in found where (c.level == "err" || c.level == "warn") && !skip.contains(c.key) {
        out.append(OrderIssue(f.id, c.level, c.key, c.vars, c.mid))
    }
    return out
}

/// A problem in words: the board rules', a fit issue's (Free.swift, Placing.swift) or a designer check's.
func orderIssueText(_ i: OrderIssue, _ f: Furniture) -> String {
    let m: Module? = i.mid.flatMap { id in f.modules.first { $0.id == id } }
    if i.key.hasPrefix("bz.ck.") {
        var v: [String: Any] = i.vars.mapValues { $0.base }
        if let pk = i.vars["p"]?.base as? String { v["p"] = tr(pk) }
        let many = (m?.sections.count ?? 0) > 1
        let sec: String? = many ? tr("bz.secN", ["n": i.vars["s"]?.base ?? 1]) : nil
        if let m {
            // a piece of several boxes names the box; one box, its section (or the piece itself)
            if m.type == "wardrobe" && boxes(f).count > 1 { v["m"] = tr(boxRole(f, m)) + (sec.map { ", " + $0 } ?? "") }
            else if m.type == "wardrobe" { v["m"] = sec ?? dn(f.name) }
            else { v["m"] = modName(m) }
        } else { v["m"] = dn(f.name) }
        return tr(i.key, v)
    }
    if i.key.hasPrefix("fz.") {
        let sv: [String: String] = i.vars.mapValues { "\($0.base)" }
        return issueText(FitIssue(key: i.key, vars: sv))
    }
    return checkText(FCheck(level: i.level, key: i.key, vars: i.vars, mid: i.mid), f)
}

/// Opens the piece of problem i where it can be put right: its module picked, a wardrobe's section's inside.
func openIssue(_ app: AppModel, _ p: Project, _ i: OrderIssue) {
    guard let f = p.furniture.first(where: { $0.id == i.fid }) else { return }
    let kit = KitOps.shared
    kit.sel = i.mid
    let sec = max(0, ((i.vars["s"]?.base as? Int) ?? 1) - 1)
    if f.kind == "kitchen" {
        let wall: String? = i.mid.flatMap { id in f.modules.first { $0.id == id }?.wall }
        app.push(.kitchen(pid: p.id, fid: f.id, wall: wall))
    } else if i.key == "bz.ck.shelf" || i.key == "bz.ck.drawer" {
        app.push(.wardrobe(pid: p.id, fid: f.id, step: 4, sec: sec))
    } else {
        app.push(.wardrobe(pid: p.id, fid: f.id, step: 1, sec: 0))
    }
    kit.tick += 1
}

/// On the order's Rooms tab: how many problems the Check list has (or that all is well), a tap opens it.
struct CheckCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        if p.furniture.contains(where: { !$0.modules.isEmpty }) {
            let issues = orderIssues(p)
            let errs = issues.filter { $0.level == "err" }.count
            let bg: Color = errs > 0 ? G.errWash : !issues.isEmpty ? G.amberWash : G.greenWash
            let fg: Color = errs > 0 ? G.err : !issues.isEmpty ? G.amberInk : BZ_GOOD
            HStack(spacing: 10) {
                MIcon(issues.isEmpty ? "check" : "alert", fg, 20, 2.2)
                VStack(alignment: .leading, spacing: 1) {
                    T(tr("bz.check"), ui(15, 800, fg))
                    T(issues.isEmpty ? tr("bz.checkOk") : tr("bz.checkN", ["n": issues.count]), ui(12.5, 500, fg, lh: 1.3))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MIcon("chev", fg, 16, 2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(bg))
            .pressable(0.98) { app.push(.fCheck(pid: p.id)) }
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("bz.checkCard")
        }
    }
}

/// The order's one Check list: every piece's problems, each opening its piece; then sending the design.
struct CheckScreen: View {
    let app: AppModel
    let pid: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            let s = AppSettings.shared
            let issues = orderIssues(p)
            let anyErr = issues.contains { $0.level == "err" }
            FPage(eyebrow: dn(p.name), title: tr("bz.check"), back: { app.pop() }) {
                T(tr("bz.checkB", ["v": shelfSpanMax(s.workshop.t), "t": s.workshop.t]), ui(13, 400, G.ink2, lh: 1.4))
                if issues.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        MIcon("check", BZ_GOOD, 20, 2.4)
                        T(tr("bz.checkOkL"), ui(14, 600, BZ_GOOD, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.greenWash))
                }
                ForEach(p.furniture.filter { f in issues.contains { $0.fid == f.id } }) { f in
                    CheckPiece(app: app, p: p, f: f, issues: issues.filter { $0.fid == f.id })
                }
            } footer: {
                GBtn(tr(anyErr ? "bz.sendAnyway" : "ns.shareB"), kind: anyErr ? .secondary : .primary, icon: "share") { app.push(.report(pid: p.id, no: nil)) }
                    .accessibilityIdentifier("bz.send")
            }
        }
    }
}

/// One piece's problems on the Check list.
private struct CheckPiece: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    let issues: [OrderIssue]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            T(dn(f.name), ui(15.5, 800), lines: 1)
            ForEach(Array(issues.enumerated()), id: \.offset) { _, i in
                let err = i.level == "err"
                let fg: Color = err ? G.err : G.amberInk
                HStack(spacing: 8) {
                    MIcon("alert", fg, 18, 2)
                    T(orderIssueText(i, f), ui(13.5, 500, fg, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                    MIcon("chev", fg, 14, 2)
                }
                .padding(12).frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(err ? G.errWash : G.amberWash))
                .pressable(0.99) { openIssue(app, p, i) }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("bz.issue." + i.level)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }
}

/* ---------------- Change for all: fronts and handles ---------------- */

/// A board's name: a preset's in the app language (the workshop's own as typed).
private func bzMatName(_ m: Mat) -> String {
    if MAT_PRESETS.contains(where: { $0.id == m.id && $0.name == m.name }) && Strings.has("mp." + m.id) { return tr("mp." + m.id) }
    return m.name
}

/// A hardware item's name: a preset's in the app language.
private func bzHwName(_ h: Hw) -> String {
    if HW_PRESETS.contains(where: { $0.id == h.id && $0.name == h.name }) && Strings.has("hp." + h.id) { return tr("hp." + h.id) }
    return h.name
}

/// The fronts' board and the handles of every piece of the order, in one tap each; Undo puts them back.
struct SwapSheet: View {
    let app: AppModel
    let pid: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            let st = AppSettings.shared
            let fs = p.furniture.filter { !$0.modules.isEmpty }
            let cur = commonFront(fs)
            let ch = commonHandle(fs)
            let usual = usualHw(st.hws, "handle")
            GlassSheet(tr("bz.swap"), onClose: { app.sheet = nil }) {
                T(tr("bz.swapB", ["n": fs.count]), ui(13, 400, G.ink2, lh: 1.4))
                T(tr("bz.front"), ui(15, 800))
                ForEach(st.mats.filter { $0.kind == "board" }) { mt in
                    let on = mt.id == cur
                    let name = bzMatName(mt)
                    SwapRow(name: name, on: on, id: "bz.front." + mt.id, glyph: { swatch(mt) }) {
                        if !on { apply(p, fs.count, "bz.swapFront", name) { swapAll($0, front: mt.id) } }
                    }
                }
                Hairline()
                T(tr("bz.handle"), ui(15, 800))
                // the usual handle, the others of the list, and none (push to open)
                ForEach(handleOpts(st.hws, usual), id: \.0) { id, name in
                    let on = ch == id || (id == "" && ch == usual?.id)
                    SwapRow(name: name, on: on, id: "bz.handle." + (id.isEmpty ? "usual" : id), glyph: { handleGlyph(id) }) {
                        if !on { apply(p, fs.count, "bz.swapHandle", name) { swapAll($0, handle: id) } }
                    }
                }
            }
        }
    }

    private func handleOpts(_ hws: [Hw], _ usual: Hw?) -> [(String, String)] {
        var out: [(String, String)] = []
        if let usual { out.append(("", bzHwName(usual))) }
        for h in hws where h.kind == "handle" && h.id != usual?.id { out.append((h.id, bzHwName(h))) }
        out.append((NO_HANDLES, tr("bz.noHandle")))
        return out
    }

    private func swatch(_ mt: Mat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous).fill(matColor(mt.rgb))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
            .frame(width: 26, height: 26)
    }

    private func handleGlyph(_ id: String) -> some View {
        let k: CGFloat
        switch id {
        case NO_HANDLES: k = 0
        case "handleKnob": k = 0.18
        case "handleLong": k = 0.9
        default: k = 0.5
        }
        return Canvas { c, size in
            let door = CGRect(x: size.width * 0.2, y: 0, width: size.width * 0.6, height: size.height)
            c.stroke(Path(roundedRect: door, cornerRadius: 2), with: .color(G.ink2), lineWidth: 1.5)
            let l = k * size.width
            if l > 0 {
                var bar = Path()
                bar.move(to: CGPoint(x: size.width * 0.66, y: (size.height - l) / 2))
                bar.addLine(to: CGPoint(x: size.width * 0.66, y: (size.height + l) / 2))
                c.stroke(bar, with: .color(G.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .frame(width: 26, height: 26)
    }

    /// Changes every piece of the order with fn, says so with Undo (the pieces as they were come back).
    private func apply(_ p: Project, _ n: Int, _ say: String, _ name: String, _ fn: @escaping ([Furniture]) -> [Furniture]) {
        let before = p.furniture
        let id = p.id
        Store.shared.update(id) { $0.furniture = fn($0.furniture) }
        for f in before { KitOps.shared.forget(f.id) }
        KitOps.shared.tick += 1
        app.say(say, ["n": n, "m": name], action: "common.undo") {
            Store.shared.update(id) { $0.furniture = before }
            KitOps.shared.tick += 1
        }
    }
}

/// One choice of the "Change for all" sheet: its picture, its name, a tick when it is what all the pieces have.
private struct SwapRow<Glyph: View>: View {
    let name: String
    let on: Bool
    let id: String
    @ViewBuilder let glyph: () -> Glyph
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 10) {
            glyph()
            T(name, ui(14.5, on ? 700 : 500, on ? G.cobalt2 : G.ink), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
            if on { MIcon("check", G.cobalt, 18, 2.4) }
        }
        .padding(.horizontal, 12).frame(minHeight: 52)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.7)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(id)
    }
}

/// The Rooms tab's "Change for all" button: the fronts and the handles of every piece.
struct SwapButton: View {
    let app: AppModel
    let p: Project
    var body: some View {
        if p.furniture.contains(where: { !$0.modules.isEmpty }) {
            GBtn(tr("bz.swap"), kind: .secondary, icon: "layers", height: 48, fontSize: 15) { app.sheet = .fSwap(pid: p.id) }
                .accessibilityIdentifier("bz.swap")
        }
    }
}

/* ---------------- remnants (Advanced) ---------------- */

/// The remnants order p's cut list uses first (none in the simple app).
func remsOf(_ p: Project) -> [Remnant] {
    let s = AppSettings.shared
    if !s.advanced { return [] }
    return remnantsFor(s.remnants, p.id, p.cutAt > 0, live: { Store.shared.get($0) != nil })
}

/// The workshop's remnants: by material, their sizes and where they came from; each can be thrown away.
struct RemnantsScreen: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        if !s.advanced { Color.clear.onAppear { app.dropAdvanced() } } else {
            let all = s.remnants
            let mats = matOrder(all)
            FPage(eyebrow: tr("wk.title"), title: tr("bz.remList"), back: { app.pop() }) {
                T(tr("bz.remB", ["v": s.workshop.remMin]), ui(13, 400, G.ink2, lh: 1.4))
                if all.isEmpty {
                    T(tr("bz.remNone"), ui(14, 500, G.ink2, lh: 1.45)).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
                }
                ForEach(mats, id: \.self) { mat in
                    RemnantGroup(app: app, mat: mat, list: all.filter { $0.mat == mat })
                }
            }
        }
    }
}

/// The remnants' materials in the order they first come.
private func matOrder(_ all: [Remnant]) -> [String] {
    var out: [String] = []
    for r in all where !out.contains(r.mat) { out.append(r.mat) }
    return out
}

/// One material's remnants on the store page, the biggest first.
private struct RemnantGroup: View {
    let app: AppModel
    let mat: String
    let list: [Remnant]
    var body: some View {
        let s = AppSettings.shared
        let name = s.mats.first { $0.id == mat }.map { bzMatName($0) } ?? mat
        let sorted = list.enumerated().sorted { a, b in
            let x = a.element.L * a.element.W, y = b.element.L * b.element.W
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
        VStack(alignment: .leading, spacing: 6) {
            T(name + " · \(list.count)", ui(15, 800))
            ForEach(sorted) { r in
                Hairline()
                RemnantRow(app: app, r: r)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }
}

private struct RemnantRow: View {
    let app: AppModel
    let r: Remnant
    var body: some View {
        let by: String? = r.used.isEmpty ? nil : Store.shared.get(r.used).map { dn($0.name) }
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                T("\(r.L) × \(r.W) " + tr("u.mm") + (r.grain ? " ↕" : ""), num(15, 700))
                T(words(by), ui(12, 400, by != nil ? G.amberInk : G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("trash", G.err, 20, 2).frame(width: 44, height: 44)
                .pressable(0.95, label: tr("common.delete")) {
                    let s = AppSettings.shared
                    let before = s.remnants
                    let id = r.id
                    s.setRemnantList(before.filter { $0.id != id })
                    app.say("bz.remDeleted", action: "common.undo") { AppSettings.shared.setRemnantList(before) }
                }
                .accessibilityIdentifier("bz.remDel")
        }
        .frame(minHeight: 48)
    }

    /// Where the remnant came from, and the order that took it (or that it is free).
    private func words(_ by: String?) -> String {
        var out: [String] = []
        if let from = Store.shared.get(r.src) { out.append(tr("bz.remFrom", ["o": dn(from.name)])) }
        if let by { out.append(tr("bz.remBy", ["o": by])) } else { out.append(tr("bz.remFree")) }
        return out.joined(separator: " · ")
    }
}

/// On the parts screen: the remnants this cut list uses, and saying it was cut (its offcuts kept); Undo.
struct RemnantCard: View {
    let app: AppModel
    let p: Project
    let cost: Cost
    var body: some View {
        let s = AppSettings.shared
        let remMin = s.workshop.remMin
        let used = cost.layouts.reduce(0) { $0 + $1.rems.count }
        let kept = keptCount(remMin)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                T(tr("bz.rem"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(tr("bz.remN", ["n": s.remnants.filter { $0.used.isEmpty }.count]), ui(12.5, 700, G.cobalt2)).padding(6)
                    .pressable(0.97) { app.push(.remnants) }
                    .accessibilityIdentifier("bz.remStore")
            }
            T(used > 0 ? tr("bz.remUsed", ["n": used]) : tr("bz.remUsed0"), ui(13, 500, G.ink2, lh: 1.4))
            if p.cutAt == 0 {
                T(tr("bz.remWill", ["n": kept, "v": remMin]), ui(12.5, 400, G.ink2, lh: 1.4))
                GBtn(tr("bz.cutDone"), kind: .secondary, icon: "save", height: 46, corner: 14, fontSize: 14.5, lines: 2) { done(kept) }
                    .accessibilityIdentifier("bz.cutDone")
            } else {
                T(tr("bz.cutWas", ["d": fmtDate(p.cutAt)]), ui(12.5, 600, BZ_GOOD, lh: 1.4))
                GBtn(tr("bz.cutUndo"), kind: .secondary, icon: "undo", height: 44, corner: 14, fontSize: 14) {
                    let st = AppSettings.shared
                    st.setRemnantList(cutUndone(st.remnants, p.id))
                    Store.shared.update(p.id) { $0.cutAt = 0 }
                }
                .accessibilityIdentifier("bz.cutUndo")
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }

    /// The offcuts of this cut list big enough to keep.
    private func keptCount(_ remMin: Int) -> Int {
        var n = 0
        for l in cost.layouts { for b in l.sheets + l.rems { for r in b.rest where r.l >= remMin && r.w >= remMin { n += 1 } } }
        return n
    }

    private func done(_ kept: Int) {
        guard app.once() else { return }
        let st = AppSettings.shared
        let before = st.remnants
        let pid = p.id
        let now = nowMs()
        st.setRemnantList(cutDone(before, cost.layouts, st.mats, pid, st.workshop.remMin, now) { uid() })
        Store.shared.update(pid) { $0.cutAt = now }
        app.say("bz.cutSaved", ["n": kept], action: "common.undo") {
            AppSettings.shared.setRemnantList(before)
            Store.shared.update(pid) { $0.cutAt = 0 }
        }
    }
}

/* ---------------- parts list → the part in 3D (Advanced) ---------------- */

/// The pieces and modules that have cut list line r ("pieceId|module" as Parts.swift names them), piece by piece.
func partHomes(_ fs: [Furniture], _ r: CutRow, _ ws: Workshop) -> [(String, Set<String>)] {
    var key = r.p; key.mod = ""; key.qty = 0
    var out: [(String, Set<String>)] = []
    for f in fs {
        let fws = wsOf(f, ws)
        var mods = Set<String>()
        for m in f.modules {
            for pt in partsOf(m, fws) {
                var k = pt; k.mod = ""; k.qty = 0
                if k == key && matFor(pt.role, f.mats) == r.mat { mods.insert(f.id + "|" + pt.mod) }
            }
        }
        if !mods.isEmpty { out.append((f.id, mods)) }
    }
    return out
}

/// A piece in 3D with part r lit up (inside parts with the doors hidden); fid the piece shown.
struct PartIn3D: View {
    let p: Project
    let r: CutRow
    let fid: String?
    let onPiece: (String) -> Void
    let onClose: () -> Void
    var body: some View {
        let s = AppSettings.shared
        let homes = partHomes(p.furniture, r, s.workshop)
        let ids = homes.map(\.0)
        if let f = p.furniture.first(where: { $0.id == fid && ids.contains($0.id) }) ?? p.furniture.first(where: { ids.contains($0.id) }) {
            // a piece in its room is shown on its own, taken out of the room
            let shown = f.roomId == nil ? f : takenOut(f, { _ in nil }, nil)
            let bare = r.p.role != "front"
            let mods = homes.first { $0.0 == f.id }?.1 ?? []
            let scene = pieceScene(shown, s.workshop, s.mats, bare: bare, hi: PartHi(r.p.key, r.p.role, mods))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(BZ_HI).frame(width: 12, height: 12)
                    T(tr(r.p.key) + " · \(r.p.L) × \(r.p.W) × \(r.p.qty)", ui(14, 700), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                    MIcon("x", G.ink2, 18, 2).frame(width: 40, height: 40).pressable(0.95, label: tr("common.close"), onClose)
                        .accessibilityIdentifier("bz.hiClose")
                }
                ZStack(alignment: .bottomTrailing) {
                    PieceView(scene: scene, hi: nil, label: nil)
                    T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(8).allowsHitTesting(false)
                }
                .aspectRatio(1 / 0.75, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                if homes.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(p.furniture.filter { ids.contains($0.id) }) { g in
                                FChip(label: dn(g.name), on: g.id == f.id) { onPiece(g.id) }
                            }
                        }
                    }
                }
                if bare { T(tr("bz.hiInside"), ui(12, 400, G.ink2, lh: 1.35)) }
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.7))
            .accessibilityIdentifier("bz.part3d")
        }
    }
}
