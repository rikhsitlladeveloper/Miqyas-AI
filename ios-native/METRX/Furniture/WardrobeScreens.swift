import SwiftUI

/*
 * Furniture makers, Stage 1a part 5 (furniture plan section 8; design canvas screen 11; Android
 * ui/furniture/WardrobeScreens.kt): the wardrobe designer in five steps (place, sizes, doors, inside, material) over
 * its front drawing. Hinged doors, open, or sliding doors over the whole front (1b-2). The rules are in
 * Furniture/Core/Wardrobe.swift.
 */

func wardOf(_ f: Furniture) -> Module? { f.modules.first { $0.type == "wardrobe" } }

/// The designer's header line (Android WardrobeScreens.kt wardHeadSub): a gorka as a whole (its width, height, deepest
/// box and towers), another piece of several boxes (a stenka, a corner piece, a box on another) by its whole size as on
/// its card, any other cabinet the size and sections of box m.
func wardHeadSub(_ f: Furniture, _ m: Module, _ ws: Workshop) -> String {
    if let r = gorkaRoles(f) {
        let v = gorkaVals(f, ws)
        let w: Int = v["w"] ?? 0, h: Int = v["h"] ?? 0, d: Int = v["d"] ?? 0
        return tr("gk.sub", ["w": w, "h": h, "d": d, "n": r.ups.count])
    }
    if PIECE_TYPES.contains(f.type) && boxes(f).count > 1 { return pieceLine(f, ws) }
    return tr("wd.sub", ["w": m.w, "h": outerH(m, ws), "d": m.d, "n": m.sections.count])
}

/// The box the designer works on: the one picked (a stenka's piece, a corner wardrobe's arm), else the first.
func curWard(_ f: Furniture) -> Module? {
    let sel = KitOps.shared.sel
    return f.modules.first { $0.id == sel && $0.type == "wardrobe" } ?? wardOf(f)
}

/// Changes the wardrobe (the picked box of a piece of several) of furniture fid (on the designer's undo list).
private func ward(_ pid: String, _ fid: String, _ fn: @escaping (Module) -> Module) {
    let snap = AppSettings.shared.angleSnap, ws = AppSettings.shared.workshop
    KitOps.shared.change(pid, fid) { x in
        guard let cur = curWard(x) else { return x }
        let room: Room? = x.roomId == nil ? nil : Store.shared.get(pid).flatMap { roomOf($0, x) }
        let free = x.pose != nil
        let many = boxes(x).count > 1
        var y = x
        y.modules = x.modules.map { mod in
            guard mod.id == cur.id else { return mod }
            let m = fn(mod)
            // without a room there are no walls to meet: a kupe has a side panel at each end, another wardrobe keeps its own
            if many { return m }
            guard let room else { return kupeSides(x, m, nil) }
            // the side panels follow where it stands: an end in the room has one, a sliding wardrobe uses the wall it meets
            return withSides(m, wallLen(room, snap, m.wall ?? ""), free: free)
        }
        // the other boxes make room: a stenka's pieces side by side, a corner's arms, a box on another
        let lenA = room.flatMap { wallLen($0, snap, x.walls.first ?? "") }
        return packPiece(y, lenA, changed: cur.id, ws: ws)
    }
}

private func changeSec(_ pid: String, _ fid: String, _ i: Int, _ fn: @escaping (Section) -> Section) {
    // new doors: the doors chosen without a handle before are other doors now (HandleRules.swift)
    ward(pid, fid) { m in var n = m; n.sections = m.sections.enumerated().map { k, s in k == i ? frontsChanged(s, fn(s)) : s }; return n }
}

/// Designer C (DzcWard.swift): the box being designed changed, as the steps change it.
func dzcWardChange(_ pid: String, _ fid: String, _ fn: @escaping (Module) -> Module) { ward(pid, fid, fn) }

/// Designer C: section i of the box being designed changed.
func dzcSecChange(_ pid: String, _ fid: String, _ i: Int, _ fn: @escaping (Section) -> Section) { changeSec(pid, fid, i, fn) }

private func sortedByPos(_ xs: [Insert]) -> [Insert] { xs.enumerated().sorted { ($0.element.pos, $0.offset) < ($1.element.pos, $1.offset) }.map(\.element) }

/// A new insert of kind in section i, where it fits best.
private func addInsert(_ app: AppModel, _ pid: String, _ fid: String, _ m: Module, _ i: Int, _ kind: String) {
    let t = AppSettings.shared.workshop.t
    guard i < m.sections.count else { return }
    let x = Insert(kind, pos: nextPos(kind, m.sections[i], wardInnerH(m, t), t), h: blockH(Insert(kind)))
    changeSec(pid, fid, i) { s in var n = s; n.inserts = sortedByPos(s.inserts + [x]); return n }
    app.say("kt.added", ["m": tr("wi." + kind)])
}

private func wardRoomH(_ room: Room?) -> Int? { room.flatMap { $0.dim("H").v ?? $0.dim("H").pending?.mm } }

/// The wall's length, the room's height and what is wrong.
struct WardCtx {
    let room: Room?
    let wallL: Int?
    let roomH: Int?
    let found: [FCheck]
    /// Section number (from 1) → its worst finding.
    let bad: [Int: String]
    init(_ p: Project, _ f: Furniture, _ m: Module, _ ws: Workshop, _ snap: Bool) {
        room = roomOf(p, f)
        wallL = room.flatMap { wallLen($0, snap, m.wall ?? "") }
        roomH = wardRoomH(room)
        var c = wardrobeChecks(m, wallL, roomH, ws, room?.openings ?? [], room?.points ?? [])
        // a piece of several boxes (a stenka) is checked as a whole too: its run along the wall, not only the box picked
        if let room, let w0 = f.walls.first, !CORNER_TYPES.contains(f.type), boxes(f).count > 1, let runL = wallLen(room, snap, w0) {
            let over = runStart(f) + runLen(f) - runL
            if over > 0 && !c.contains(where: { $0.key == "wc.wide" }) { c.append(FCheck(level: "err", key: "wc.wide", vars: ["v": over], mid: m.id)) }
        }
        found = c
        var b: [Int: String] = [:]
        for c in found { if let n = c.vars["s"]?.base as? Int, c.level == "err" || b[n] == nil { b[n] = c.level } }
        bad = b
    }
}

/* ---------------- the drawing ---------------- */

private let DASH: [CGFloat] = [4, 3]
private var GAP_FILL: Color { pc(0xFFF1F5F9, 0xFF2B3346) }
private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(CGRect(x: x, y: y, width: w, height: h)) }
private func opaque(_ rgb: Int) -> Color { Color(argb: 0xFF00_0000 | UInt32(rgb)) }

/// The wardrobe's front, its left edge at ox mm (0: drawn on its wall): the carcass, plinth or legs, sections, inserts
/// (unless the doors are shown), doors, problem outlines and the selected section. edge: the piece opens by its edge
/// (HandleRules.swift opensByEdge), so a front without a handle shows no push mark.
func drawWard(_ c: GraphicsContext, _ lay: KLay, _ m: Module, _ ox: Int, _ ws: Workshop, _ carcassRgb: Int, _ frontRgb: Int, _ sel: Int, _ doors: Bool,
              _ bad: [Int: String], labels: Bool, edge: Bool = false) {
    let t = ws.t, z0 = legsOf(m, ws) + m.elev, base = wardBase(m)
    func X(_ mm: Int) -> CGFloat { lay.x(mm - ox) }
    let l = X(m.x), r = X(m.x + m.w), top = lay.y(z0 + m.h), bot = lay.y(z0)
    let carcass = opaque(carcassRgb), front = opaque(frontRgb), onC = lineOn(carcassRgb), onF = lineOn(frontRgb)
    c.fill(rect(l, top, r - l, bot - top), with: .color(carcass))
    if !m.legs { c.fill(rect(l, lay.y(z0 + base), r - l, CGFloat(base) * lay.s), with: .color(PC.greyLine.opacity(0.4))) }
    else {
        var acc = m.x
        for x in [m.x] + m.sections.map({ acc += $0.w; return acc }) { c.fill(rect(X(x) - 1.5, bot, 3, lay.yF - bot), with: .color(PC.greyLine)) }
    }
    let bottomY = lay.y(z0 + base + t)
    // a desk's knee space has no bottom: the floor shows through
    var ka = m.x
    for s in m.sections {
        if !s.knee { c.line(onC, CGPoint(x: X(ka), y: bottomY), CGPoint(x: X(ka + s.w), y: bottomY), 1) }
        else { let ky = lay.y(z0 + m.h - t); c.fill(rect(X(ka) + 1, ky, CGFloat(s.w) * lay.s - 2, lay.yF - ky), with: .color(PC.white)) }
        ka += s.w
    }
    c.line(onC, CGPoint(x: l, y: lay.y(z0 + m.h - t)), CGPoint(x: r, y: lay.y(z0 + m.h - t)), 1)
    var acc = m.x
    for (i, s) in m.sections.enumerated() {
        let sl = X(acc), sr = X(acc + s.w)
        if i > 0 { c.line(onC, CGPoint(x: sl, y: lay.y(z0 + base)), CGPoint(x: sl, y: top), 1.4) }
        let il = sl + 2, ir = sr - 2
        let open = s.fronts.kind == "open"
        let slide = m.slide != nil
        if !doors || (open && !slide) {
            for x in s.inserts {
                let y0 = z0 + base + t + x.pos, h = blockH(x)
                switch x.kind {
                case "shelf": c.fill(rect(il, lay.y(y0 + t), ir - il, max(1.4, CGFloat(t) * lay.s)), with: .color(onC))
                case "glass": c.fill(rect(il, lay.y(y0 + 6), ir - il, max(1.4, 6 * lay.s)), with: .color(GLASS_C))
                case "rail": c.line(PC.greyLine, CGPoint(x: il + 3, y: lay.y(y0)), CGPoint(x: ir - 3, y: lay.y(y0)), 2.4, round: true)
                case "lift":
                    c.stroke(rect(il + 3, lay.y(y0 + h), ir - il - 6, CGFloat(h) * lay.s), with: .color(PC.greyLine), style: StrokeStyle(lineWidth: 1, dash: DASH))
                    c.line(PC.greyLine, CGPoint(x: il + 5, y: lay.y(y0 + 40)), CGPoint(x: ir - 5, y: lay.y(y0 + 40)), 2.4, round: true)
                default:
                    let bt = lay.y(y0 + h), bh = max(2, CGFloat(h) * lay.s - 1)
                    let box = Path(roundedRect: CGRect(x: il + 1.5, y: bt, width: ir - il - 3, height: bh), cornerRadius: 1.5)
                    c.fill(box, with: .color(x.kind == "drawer" ? front : GAP_FILL)); c.stroke(box, with: .color(onC), lineWidth: 0.9)
                    switch x.kind {
                    case "drawer":
                        // a drawer (an open section's, or behind the doors) without a handle: the push mark where it would be
                        let cx = (il + ir) / 2, y = bt + min(4, bh / 3)
                        if drawerHandle(m, x) { c.line(onF, CGPoint(x: cx - 6, y: y), CGPoint(x: cx + 6, y: y), 1.4, round: true) }
                        else if !edge { pushMark(c, CGPoint(x: cx, y: y + 1), onF, min(2.6, bh / 3)) }
                    case "trouser": for k in 1...4 { let xx = il + (ir - il) * CGFloat(k) / 5; c.line(PC.ink3, CGPoint(x: xx, y: bt + 2), CGPoint(x: xx, y: bt + bh - 2), 0.8) }
                    case "shoe": c.line(PC.ink3, CGPoint(x: il + 4, y: bt + bh - 2), CGPoint(x: ir - 4, y: bt + 2), 0.9)
                    default: break
                    }
                }
            }
        }
        if doors && !open && !slide {
            let n = frontSizes(s.fronts, frontW(s), m.h - base, ws).count
            if n > 0 {
                let g = max(0.8, CGFloat(ws.gap10) / 10 * lay.s)
                let ft = top + g, fb = lay.y(z0 + base) - g
                // a corner unit's blind part has no door (the other arm closes it)
                let blind = CGFloat(s.blind) * lay.s
                let fw = (sr - sl - blind - g * CGFloat(n + 1)) / CGFloat(n)
                let fill: Color = s.face == "mirror" ? MIRROR_C : s.face == "glass" ? GLASS_C.opacity(0.45) : front
                for j in 0..<n {
                    let fx = sl + g + CGFloat(j) * (fw + g)
                    c.fill(rect(fx, ft, fw, fb - ft), with: .color(fill)); c.stroke(rect(fx, ft, fw, fb - ft), with: .color(onF), lineWidth: 0.8)
                    if s.face == "glass" { c.stroke(rect(fx, ft, fw, fb - ft), with: .color(PROFILE_C), lineWidth: max(1.2, 20 * lay.s)) }
                    let hx = n == 2 ? (j == 0 ? fx + fw - 3 : fx + 3) : (!hingeRight(m, i) ? fx + fw - 3 : fx + 3)
                    // about 1 m up, but on the door of a low or hung cabinet
                    let hmm = max(min(z0 + 1000, z0 + m.h - 90), z0 + base + 90)
                    let hy = lay.y(hmm)
                    if doorHandle(m, i, j) { c.line(onF, CGPoint(x: hx, y: hy - 9), CGPoint(x: hx, y: hy + 9), 1.6, round: true) }
                    // no handle (a glass door never has one): the push latch's mark, a little in from the edge; none on a
                    // piece opened by its edge
                    else if !edge { pushMark(c, CGPoint(x: hx > fx + fw / 2 ? hx - 2 : hx + 2, y: hy), s.face == "glass" ? PC.ink : onF, 2.8) }
                }
            }
        }
        // the selected section's heights, on its right edge
        if i == sel && !doors && labels {
            var last = CGFloat.greatestFiniteMagnitude
            for x in sortedByPos(s.inserts) {
                let y = lay.y(z0 + base + t + x.pos)
                if last - y >= 11 {
                    let w = 6 * CGFloat("\(x.pos)".count) + 6
                    c.fill(Path(roundedRect: CGRect(x: sr - 3 - w, y: y - 6, width: w, height: 12), cornerRadius: 4), with: .color(PC.white.opacity(0.9)))
                    c.text("\(x.pos)", CGPoint(x: sr - 3 - w / 2, y: y), .num, 8.5, 600, PC.cob)
                    last = y
                }
            }
        }
        switch bad[i + 1] {
        case "err": c.stroke(rect(sl + 2, top + 2, sr - sl - 4, bot - top - 4), with: .color(PC.red), style: StrokeStyle(lineWidth: 1.6, dash: DASH))
        case "warn": c.stroke(rect(sl + 2, top + 2, sr - sl - 4, bot - top - 4), with: .color(PC.amber), style: StrokeStyle(lineWidth: 1.4, dash: DASH))
        default: break
        }
        if i == sel { c.stroke(rect(sl + 1.5, top + 1.5, sr - sl - 3, bot - top - 3), with: .color(PC.cob), lineWidth: 2.6) }
        acc += s.w
    }
    if doors, let sd = m.slide { drawSlide(c, lay, m, sd, ox, z0 + base + t, front, ws) }
    // the ends: a side panel, or dashed where it meets a wall (built in)
    c.line(PC.ink, CGPoint(x: l, y: top), CGPoint(x: r, y: top), 1.4)
    c.line(PC.ink, CGPoint(x: l, y: top), CGPoint(x: l, y: bot), m.sideL ? 1.8 : 1, dash: m.sideL ? nil : DASH)
    c.line(PC.ink, CGPoint(x: r, y: top), CGPoint(x: r, y: bot), m.sideR ? 1.8 : 1, dash: m.sideR ? nil : DASH)
}

/// Mirror and lacobel glass in drawings (the 3D uses the same colours).
let MIRROR_C = Color(argb: 0xFFC9D3DD)
let GLASS_C = Color(argb: 0xFF8FA9C4)
private let PROFILE_C = Color(argb: 0xFF9AA3AE)

/// Sliding doors over the front: the back track's doors first, the front track's over them, each in its profile frame.
private func drawSlide(_ c: GraphicsContext, _ lay: KLay, _ m: Module, _ sl: Slide, _ ox: Int, _ y0: Int, _ front: Color, _ ws: Workshop) {
    let n = min(4, max(2, sl.n))
    let (dw, dh) = slideDoor(m, ws.t)
    let step = dw - SLIDE_OV
    let ax = m.x + (m.sideL ? ws.t : 0)
    let y = y0 + SLIDE_CLEAR / 2
    let fw = max(1.2, CGFloat(SLIDE_FRAME_W) * lay.s)
    for j in (0..<n).filter({ $0 % 2 == 0 }) + (0..<n).filter({ $0 % 2 == 1 }) {
        let l = lay.x(ax + j * step - ox), w = CGFloat(dw) * lay.s
        let t = lay.y(y + dh), h = CGFloat(dh) * lay.s
        let fill = sl.panel(j) == "mirror" ? MIRROR_C : sl.panel(j) == "glass" ? GLASS_C : front
        c.fill(rect(l, t, w, h), with: .color(PROFILE_C))
        c.fill(rect(l + fw, t + fw * 1.6, w - 2 * fw, h - 3.2 * fw), with: .color(fill))
        if sl.panel(j) == "mirror" {
            for k in 0...1 {
                let sx = l + w * (0.25 + 0.3 * CGFloat(k))
                c.line(Color.white.opacity(0.7), CGPoint(x: sx, y: t + h * 0.2), CGPoint(x: sx + w * 0.18, y: t + h * 0.05), 1.2)
            }
        }
        c.stroke(rect(l, t, w, h), with: .color(PC.ink), lineWidth: 0.9)
    }
}

/// A wall-hung box's height off the floor, at the right of a drawing whose floor is lay's: from the floor up to the
/// box's bottom lift mm over it, dashed, its value turned along it.
func liftDims(_ c: GraphicsContext, _ lay: KLay, _ w: Int, _ lift: Int) {
    let x = lay.x(w) + 9, y0 = lay.yF, y1 = lay.y(lift)
    c.line(PC.ink3, CGPoint(x: lay.x0, y: y1), CGPoint(x: x + 3, y: y1), 0.6, dash: [3, 3])
    c.line(PC.ink3, CGPoint(x: x, y: y1), CGPoint(x: x, y: y0), 0.8)
    for yy in [y1, y0] { c.line(PC.ink3, CGPoint(x: x - 2.5, y: yy + 2.5), CGPoint(x: x + 2.5, y: yy - 2.5), 1.1) }
    var r = c
    r.translateBy(x: x + 7, y: (y0 + y1) / 2); r.rotate(by: .degrees(-90))
    r.text("\(lift)", .zero, .num, 10, 500, PC.ink3)
}

/// Widths under the floor and the height at the left; cuts in mm from the drawing's start.
func wardDims(_ c: GraphicsContext, _ lay: KLay, _ cuts: [Int], _ total: Int, _ h: Int, _ hx: Int) {
    guard let first = cuts.first, let lastCut = cuts.last else { return }
    let y = lay.yF + 12
    c.line(PC.ink3, CGPoint(x: lay.x(first), y: y), CGPoint(x: lay.x(lastCut), y: y), 0.8)
    for k in cuts { let x = lay.x(k); c.line(PC.ink3, CGPoint(x: x - 2.5, y: y + 2.5), CGPoint(x: x + 2.5, y: y - 2.5), 1.1) }
    for k in 0..<max(0, cuts.count - 1) where cuts[k + 1] - cuts[k] > 0 {
        let a = lay.x(cuts[k]), b = lay.x(cuts[k + 1]), t = "\(cuts[k + 1] - cuts[k])"
        let narrow = (b - a) < 6.5 * CGFloat(t.count)
        c.text(t, CGPoint(x: (a + b) / 2, y: y + (narrow && k % 2 == 1 ? 19 : 9)), .num, 10, 500, PC.ink3)
    }
    let ly = lay.yF + 40, a = lay.x(first), b = lay.x(lastCut)
    c.line(PC.ink, CGPoint(x: a, y: ly), CGPoint(x: b, y: ly), 1)
    for x in [a, b] { c.line(PC.ink, CGPoint(x: x - 4, y: ly + 4), CGPoint(x: x + 4, y: ly - 4), 1.5) }
    let pw = 9 * CGFloat("\(total)".count) + 16
    let pill = Path(roundedRect: CGRect(x: (a + b) / 2 - pw / 2, y: ly - 10, width: pw, height: 20), cornerRadius: 10)
    c.fill(pill, with: .color(PC.white)); c.stroke(pill, with: .color(PC.ink3), lineWidth: 1)
    c.text("\(total)", CGPoint(x: (a + b) / 2, y: ly), .num, 12, 600, PC.ink)
    // the height
    let x = lay.x(hx) - 9
    c.line(PC.ink3, CGPoint(x: x, y: lay.y(h)), CGPoint(x: x, y: lay.yF), 0.8)
    for yy in [lay.y(h), lay.yF] { c.line(PC.ink3, CGPoint(x: x - 2.5, y: yy + 2.5), CGPoint(x: x + 2.5, y: yy - 2.5), 1.1) }
    var r = c
    r.translateBy(x: x - 7, y: (lay.y(h) + lay.yF) / 2); r.rotate(by: .degrees(-90))
    r.text("\(h)", .zero, .num, 10, 500, PC.ink3)
}

private struct WardDrawing: View {
    let m: Module, f: Furniture, cx: WardCtx, ws: Workshop, mats: [Mat], step: Int, sel: Int
    let onSec: (Int) -> Void
    /// The doors step: each door and open drawer is tapped to give it a handle or take it away (nil: no targets; the
    /// drawers behind the doors: InnerDrawers).
    var onFront: ((HFront) -> Void)? = nil
    var body: some View {
        let onWall = step == 1
        let doors = step == 1 || step == 3 || step == 5
        let ox = onWall ? 0 : m.x
        let L = onWall ? max(cx.wallL ?? (m.x + m.w + W_GAP_SIDE), m.x + m.w) : m.w
        let H = onWall ? max(cx.roomH ?? 2700, topOf(m, ws)) : outerH(m, ws)
        let lay = KLay(L, H, 360, true)
        let front = rgbOf(mats.first { $0.id == f.mats.front }?.rgb ?? "#CDBFAE"), carcass = rgbOf(mats.first { $0.id == f.mats.carcass }?.rgb ?? "#F5F5F2")
        let edge = opensByEdge(f)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        GeometryReader { geo in
            Canvas { ctx, size in
                var c = ctx; let k = size.width / lay.vw; c.scaleBy(x: k, y: k)
                if onWall { drawWallFace(c, lay, cx.room, m.wall ?? "") }
                c.line(PC.ink, CGPoint(x: lay.x0 - 10, y: lay.yF), CGPoint(x: lay.x(L) + 10, y: lay.yF), 2)
                // on its wall the piece's other boxes stand beside it; alone, a hung box is drawn from its own bottom
                if onWall {
                    for o in f.modules where o.type == "wardrobe" && o.id != m.id && o.wall == m.wall {
                        drawWard(c, lay, o, ox, ws, carcass, front, -1, true, [:], labels: false, edge: edge)
                    }
                }
                var shown = m
                if !onWall { shown.elev = 0 }
                drawWard(c, lay, shown, ox, ws, carcass, front, (step == 3 && m.slide == nil) || step == 4 ? sel : -1, doors, cx.bad, labels: true, edge: edge)
                if onWall {
                    for p in cx.room?.points ?? [] where p.wall == m.wall { drawSitePoint(c, p, CGPoint(x: lay.x(p.off), y: lay.y(p.h)), lay.s, 6) }
                    wardDims(c, lay, Array(Set([0, m.x, m.x + m.w, L])).sorted(), L, outerH(m, ws), m.x)
                } else {
                    var acc = 0
                    wardDims(c, lay, [0] + m.sections.map { acc += $0.w; return acc }, m.w, outerH(m, ws), 0)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { pos in
                let k = geo.size.width / lay.vw
                let mm = Int((pos.x / k - lay.x0) / lay.s) + ox
                var acc = m.x
                for (i, s) in m.sections.enumerated() { if mm >= acc && mm < acc + s.w { onSec(i) }; acc += s.w }
            }
        }
        .aspectRatio(lay.vw / lay.vh, contentMode: .fit)
        .background(shape.fill(G.glass(0.55)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .clipShape(shape)
        .accessibilityElement()
        .accessibilityLabel(tr("kt.wardrobe"))
        .accessibilityIdentifier("wd.drawing")
        // over the drawing's own element, so each front is one for VoiceOver and the tests
        .overlay { targets(lay, ox, onWall) }
    }

    @ViewBuilder private func targets(_ lay: KLay, _ ox: Int, _ onWall: Bool) -> some View {
        if let onFront = self.onFront, !onWall, m.slide == nil {
            let b = atFloor(m)
            FrontTargets(lay: lay, ox: ox, m: b, boxes: wardFrontBoxes(b, ws), onTap: onFront, edge: opensByEdge(f))
        }
    }
}

/// The box drawn from its own bottom (as the designer's drawing shows it off its wall).
private func atFloor(_ m: Module) -> Module { var n = m; n.elev = 0; return n }

/// A small picture for the workspace card.
struct WardThumb: View {
    let f: Furniture
    var body: some View {
        if isItemPiece(f) || boxes(f).count > 1 { PieceThumb(f: f) } else { frontPic }
    }
    private var frontPic: some View {
        let s = AppSettings.shared
        return Canvas { ctx, size in
            guard let m = wardOf(f) else { return }
            let ws = s.workshop
            let front = rgbOf(s.mats.first { $0.id == f.mats.front }?.rgb ?? "#CDBFAE"), carcass = rgbOf(s.mats.first { $0.id == f.mats.carcass }?.rgb ?? "#F5F5F2")
            let lay = KLay(m.w, outerH(m, ws), 200, false)
            let k = min(size.width / lay.vw, size.height / lay.vh)
            var c = ctx
            c.translateBy(x: (size.width - lay.vw * k) / 2, y: (size.height - lay.vh * k) / 2); c.scaleBy(x: k, y: k)
            c.line(PC.ink, CGPoint(x: lay.x0 - 6, y: lay.yF), CGPoint(x: lay.x(m.w) + 6, y: lay.yF), 2)
            drawWard(c, lay, m, m.x, ws, carcass, front, -1, true, [:], labels: false, edge: opensByEdge(f))
        }
    }
}

/* ---------------- the designer ---------------- */

struct WardrobeScreen: View {
    let app: AppModel
    let pid: String, fid: String, step: Int, sec: Int
    var d3 = false
    /// A loft bed's desk or cabinet under it, designed here; nil: the piece's own designer.
    var mod: String? = nil
    var body: some View {
        let kit = KitOps.shared
        let _ = kit.tick
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            // a bed, a table, a bar counter or a mirror panel has its own short designer
            if isItemPiece(f) && mod == nil { ItemScreen(app: app, p: p, f: f, d3: d3) }
            else if let m = boxOf(f) { designer(p, f, m) }
        }
    }

    /// The doors step's tap on a front: its section picked, its handle the other way (25 Oct 2026).
    private func frontTap(_ sel: Int, _ pick: @escaping (Int) -> Void) -> ((HFront) -> Void)? {
        guard step == 3 else { return nil }
        let pid = self.pid, fid = self.fid
        return { fr in
            if fr.sec >= 0 && fr.sec != sel { pick(fr.sec) }
            ward(pid, fid) { toggleHandle($0, fr.key) }
            // a handle changed on the drawing: a toast with Undo (UX upgrades section 3)
            Haptic.tick()
            AppModel.shared.say("ux.chHandle", action: "common.undo") { KitOps.shared.undo(pid, fid); Haptic.tick() }
        }
    }

    private func boxOf(_ f: Furniture) -> Module? {
        if let id = self.mod, let b = f.modules.first(where: { $0.id == id && $0.type == "wardrobe" }) { return b }
        return curWard(f)
    }

    @ViewBuilder private func designer(_ p: Project, _ f: Furniture, _ m: Module) -> some View {
        let s = AppSettings.shared, ws = s.workshop, mats = s.mats
        let cx = WardCtx(p, f, m, ws, s.angleSnap)
        ZStack {
            RoomGrid().ignoresSafeArea()
            VStack(spacing: 0) {
                // the UX upgrades' bars: the name and the compact progress on top; Designer C's drawing, slider and
                // options; Undo/Redo, 2D/3D and "Narxni ko‘rish" below (the older steps are in "Batafsil")
                DesignerHead(app: app, p: p, f: f, sub: wardHeadSub(f, m, ws), sub2: floorLineText(f, .mm))
                if let room = cx.room {
                    DzcWard(app: app, c: DzcWCtx(p: p, f: f, m: m, room: room, cx: cx, ws: ws, mats: mats, d3: d3, step: step, mod: mod))
                } else {
                    T(tr("kt.roomLost"), ui(15, 500, G.ink2, lh: 1.45)).padding(24)
                    Spacer()
                }
            }
        }
        .onAppear { DzcState.shared.enter(f.id) }
    }
}

/// The Check list's drawer rule for the wardrobe designer (Furniture/Core/FurnChecks.swift boardIssues).
func drawerRule(_ f: Furniture, _ ws: Workshop, _ mats: [Mat]) -> [FCheck] {
    boardIssues(f, ws, mats).filter { $0.key == "bz.ck.drawer" }.map { FCheck(level: $0.level, key: $0.key, vars: $0.vars, mid: $0.mid) }
}

/// The boxes of a piece of several (a stenka's pieces, a corner wardrobe's arms, a vitrina's halves): which one the steps
/// below change. A stenka's pieces can be added, moved along and taken away.
private struct BoxPicker: View {
    let app: AppModel
    let p: Project, f: Furniture, cur: Module
    let onPick: () -> Void

    /// A stenka's boxes changed, then packed side by side again.
    private func edit(_ fn: @escaping ([Module]) -> [Module]) {
        let s = AppSettings.shared, ws = s.workshop, snap = s.angleSnap, proj = p
        KitOps.shared.change(proj.id, f.id) { x in
            let room: Room? = x.roomId == nil ? nil : roomOf(proj, x)
            var y = x; y.modules = fn(x.modules)
            return packPiece(y, room.flatMap { wallLen($0, snap, x.walls.first ?? "") }, ws: ws)
        }
    }

    private func add(_ k: String) {
        let nb = stenkaPart(f, k, AppSettings.shared.workshop)
        let id = cur.id
        // a shelf hangs over a low piece, so it goes in next to one (never over a tall cabinet)
        edit { l in
            var o = l
            let i = l.firstIndex { $0.id == id } ?? -1
            let at0 = k == "shelf" ? stenkaShelfAt(l, i) : (i < 0 ? l.count : i + 1)
            o.insert(nb, at: min(max(at0, 0), o.count))
            return o
        }
        KitOps.shared.sel = nb.id
        app.say("kt.added", ["m": tr("pc.add." + k)])
    }

    /// Along the wall: before or after the next piece in the list.
    private func move(_ dlt: Int) {
        let id = cur.id
        edit { l in
            guard let i = l.firstIndex(where: { $0.id == id }) else { return l }
            let j = i + dlt
            if j < 0 || j >= l.count { return l }
            var o = l
            let b = o.remove(at: i)
            o.insert(b, at: j)
            return o
        }
    }

    private func remove(_ n: Int) {
        // the last floor piece stays: the shelves hang over it
        if !canDropBox(f, cur) { return }
        let id = cur.id, role = tr(boxRole(f, cur)), pid = p.id, fid = f.id
        edit { l in l.filter { $0.id != id } }
        KitOps.shared.sel = nil
        app.say("kt.deleted", ["m": role], action: "common.undo") { KitOps.shared.undo(pid, fid) }
    }

    var body: some View {
        let ms = f.modules.filter { $0.type == "wardrobe" }
        VStack(alignment: .leading, spacing: 8) {
            T(tr("pc.title"), ui(14.5, 800))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(ms.enumerated()), id: \.element.id) { i, b in
                        FChip(label: "\(i + 1) · " + tr(boxRole(f, b)) + " \(b.w)", on: b.id == cur.id) {
                            KitOps.shared.sel = b.id; KitOps.shared.tick += 1; onPick()
                        }
                        .accessibilityIdentifier("pc.box\(i + 1)")
                    }
                }
            }
            if f.type == "stenka" { stenkaTools(ms.count) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: G.glass(0.6))
    }

    @ViewBuilder private func stenkaTools(_ n: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(STENKA_PARTS, id: \.self) { k in
                    FChip(label: "+ " + tr("pc.add." + k), on: false) { add(k) }.accessibilityIdentifier("pc.add." + k)
                }
            }
        }
        HStack(spacing: 8) {
            GBtn(tr("pc.left"), kind: .secondary, icon: "undo", height: 42, corner: 14, fontSize: 14) { move(-1) }.accessibilityIdentifier("pc.left")
            GBtn(tr("pc.right"), kind: .secondary, icon: "redo", height: 42, corner: 14, fontSize: 14) { move(1) }.accessibilityIdentifier("pc.right")
            GBtn(tr("common.delete"), kind: .danger, icon: "trash", enabled: canDropBox(f, cur), height: 42, corner: 14, fontSize: 14) { remove(n) }.accessibilityIdentifier("pc.delete")
        }
    }
}

private struct Steps: View {
    let cur: Int
    let onPick: (Int) -> Void
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                let on = i == cur
                VStack(spacing: 0) {
                    T("\(i)", ui(12.5, 800, on ? G.ink : G.ink2))
                    T(tr("wd.s\(i)"), ui(10.5, 700, on ? G.ink : G.ink2), lines: 1)
                }
                .padding(.vertical, 4).padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? G.glass(0.95) : .clear))
                .pressable(0.97) { onPick(i) }
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("wd.step\(i)")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
    }
}

/// A value row (the wardrobe's steps and the item designer).
struct WValRow: View {
    let label: String, value: String, id: String
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 6) {
            T(label, ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading)
            T(value, num(15, 700)); MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 14).frame(minHeight: 48)
        .background(shape.fill(G.glass(0.6))).overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.99, action)
        .accessibilityIdentifier(id)
    }
}

private struct SecChips: View {
    let m: Module, sel: Int
    let onPick: (Int) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(m.sections.enumerated()), id: \.offset) { i, s in FChip(label: "\(i + 1) · \(s.w)", on: i == sel) { onPick(i) }.accessibilityIdentifier("wd.sec\(i + 1)") }
            }
        }
    }
}

private struct PlaceStep: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    let cx: WardCtx
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if f.roomId == nil { return AnyView(FreeBanner(app: app, p: p, f: f)) }
        if let room = cx.room, boxes(f).count > 1 {
            return AnyView(VStack(alignment: .leading, spacing: 10) {
                T(tr("pc.placeNote"), ui(13, 400, G.ink2, lh: 1.4))
                GBtn(tr("fz.move"), kind: .secondary, icon: "room", height: 44, corner: 14, fontSize: 14) { app.push(.fPlace(pid: p.id, fid: f.id, rid: room.id)) }
                    .accessibilityIdentifier("wd.move")
            })
        }
        if let room = cx.room {
            // to another wall: its width kept where it fits, at the wall's longest stretch clear of doors and windows
            func moveTo(_ wall: String, _ len: Int?) {
                guard let L = len else { return }
                let pl = placeOn(L, wall, room.openings, m.h)
                // a short wall never makes it narrower than 300 (or than it is)
                let w = max(min(m.w, 300), min(m.w, L - 2 * W_GAP_SIDE))
                let x = pl.w >= w ? pl.x : W_GAP_SIDE
                ward(p.id, f.id) { mm in
                    var n = mm; n.wall = wall; n.x = x; n.w = w
                    if w != mm.w { n.sections = splitSections(w, mm.sections.map { var s = $0; s.lock = false; return s }) }
                    return n
                }
                Store.shared.update(p.id) { pr in
                    if let i = pr.furniture.firstIndex(where: { $0.id == f.id }) { pr.furniture[i].walls = [wall]; pr.furniture[i].pose = nil }
                }
            }
            return AnyView(VStack(alignment: .leading, spacing: 10) {
                T(tr("wd.place", ["w": m.wall ?? ""]), ui(15.5, 800))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Geo.walls(room, snap), id: \.id) { w in
                            let len = wallLen(room, snap, w.id)
                            FChip(label: tr("kt.wallN", ["w": w.id]) + (len.map { " · " + Geo.fmtLen($0, AppSettings.shared.unit, AppSettings.shared.lang == .en) + " " + unitWord(AppSettings.shared.unit) } ?? ""), on: w.id == m.wall) {
                                if w.id != m.wall { moveTo(w.id, len) }
                            }
                            .accessibilityIdentifier("wd.wall." + w.id)
                        }
                    }
                }
                WValRow(label: tr("wd.x"), value: "\(m.x)" + U_MM, id: "wd.x") { app.sheet = .wField(pid: p.id, fid: f.id, key: "x", sec: 0) }
                WValRow(label: tr("wd.w"), value: "\(m.w)" + U_MM, id: "wd.w") { app.sheet = .wField(pid: p.id, fid: f.id, key: "w", sec: 0) }
                // the room's plan, to drag it where it should stand
                GBtn(tr("fz.move"), kind: .secondary, icon: "room", height: 44, corner: 14, fontSize: 14) { app.push(.fPlace(pid: p.id, fid: f.id, rid: room.id)) }
                    .accessibilityIdentifier("wd.move")
                if !measured(room, snap, m.wall ?? "") { T(tr("kt.noLen", ["w": m.wall ?? ""]), ui(12.5, 500, G.amberInk, lh: 1.4)) }
            })
        }
        return AnyView(EmptyView())
    }
}

private struct WardSizeStep: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let ws = AppSettings.shared.workshop
        VStack(alignment: .leading, spacing: 10) {
            T(tr("wd.sizes"), ui(15.5, 800))
            WValRow(label: tr("wd.w"), value: "\(m.w)" + U_MM, id: "wd.w") { app.sheet = .wField(pid: p.id, fid: f.id, key: "w", sec: 0) }
            WValRow(label: tr("wd.h"), value: "\(m.h)" + U_MM, id: "wd.h") { app.sheet = .wField(pid: p.id, fid: f.id, key: "h", sec: 0) }
            WValRow(label: tr("wd.d"), value: "\(m.d)" + U_MM, id: "wd.d") { app.sheet = .wField(pid: p.id, fid: f.id, key: "d", sec: 0) }
            T(tr("wd.base"), ui(14.5, 700))
            WardBase(app: app, p: p, f: f, m: m)
            FStepper(label: tr("wd.secCount"), v: m.sections.count, lo: 1, hi: 8, id: "wd.secs") { n in
                ward(p.id, f.id) { mm in
                    let ih = wardInnerH(mm, ws.t)
                    var secs = n > mm.sections.count
                        ? mm.sections + (0..<(n - mm.sections.count)).map { _ in spreadShelves(Section(0, inserts: Array(repeating: Insert("shelf"), count: 5)), ih, ws.t) }
                        : Array(mm.sections.prefix(n))
                    if secs.allSatisfy(\.lock) { secs = secs.map { var s = $0; s.lock = false; return s } }
                    var out = mm
                    // only the new sections get doors; the others keep theirs
                    out.sections = splitSections(mm.w, secs).enumerated().map { i, s in
                        if i < mm.sections.count { return s }
                        var x = s; x.fronts = Fronts("door", s.w >= 600 ? 2 : 1); return x
                    }
                    return out
                }
            }
            let rows = stride(from: 0, to: m.sections.count, by: 4).map { Array($0..<min($0 + 4, m.sections.count)) }
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { i in
                        let s = m.sections[i], shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                        VStack(alignment: .leading, spacing: 0) {
                            T("\(s.w)", num(15, 800))
                            T(tr(s.lock ? "wd.lock" : "wd.eq"), ui(10.5, 600, s.lock ? G.cobalt2 : G.ink2), lines: 1)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(shape.fill(G.glass(0.8))).overlay(shape.strokeBorder(G.rim, lineWidth: 1))
                        .pressable(0.98) { app.sheet = .wField(pid: p.id, fid: f.id, key: "secW", sec: i) }
                        .accessibilityIdentifier("wd.secW\(i + 1)")
                    }
                    ForEach(0..<(4 - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
            // a dressing table's mirror on the wall over it
            if let r = f.modules.first(where: { $0.type == "mirror" }) {
                T(tr("pc.mirror"), ui(14.5, 700))
                WValRow(label: tr("fz.mirW"), value: "\(r.w)" + U_MM, id: "pc.mirW") { app.sheet = .iField(pid: p.id, fid: f.id, mid: r.id, key: "w") }
                WValRow(label: tr("fz.mirH"), value: "\(r.h)" + U_MM, id: "pc.mirH") { app.sheet = .iField(pid: p.id, fid: f.id, mid: r.id, key: "h") }
                WValRow(label: tr("fz.elev"), value: "\(r.elev)" + U_MM, id: "pc.mirE") { app.sheet = .iField(pid: p.id, fid: f.id, mid: r.id, key: "e") }
            }
            let carcass = AppSettings.shared.mats.first { $0.id == f.mats.carcass }?.name ?? f.mats.carcass
            T(tr("wd.sizeNote", ["d": m.d, "b": m.legs ? tr("wd.legs") : tr("wd.plinth"), "m": carcass]), ui(12.5, 400, G.ink2, lh: 1.4))
        }
    }
}

/// Plinth or legs, each with its height; the whole height stays, the carcass gives way. A cabinet can hang on the wall (a
/// stacked box stands on the one under it).
private struct WardBase: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let ws = AppSettings.shared.workshop
        let isHung = hung(m)
        let stacked = STACK_TYPES.contains(f.type) && isHung
        let cur = isHung ? "wall" : m.legs ? "legs" : "plinth"
        let hang: [(String, String)] = f.type.isEmpty ? [] : [("wall", tr("wd.hang"))]
        let items: [(String, String)] = [("plinth", tr("wd.plinth")), ("legs", tr("wd.legs"))] + hang
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            if !stacked {
                Seg(items: items, cur: cur) { k in
                    if k != cur { ward(pid, fid) { mm in WardBase.based(mm, k, ws) } }
                }
            }
            if isHung && !stacked {
                WValRow(label: tr("fz.elev"), value: "\(m.elev)" + U_MM, id: "wd.elev") { app.sheet = .wField(pid: pid, fid: fid, key: "e", sec: 0) }
            } else if !isHung {
                let baseV = m.legs ? legsOf(m, ws) : wardBase(m)
                WValRow(label: tr(m.legs ? "wd.legsH" : "wd.plinthH"), value: "\(baseV)" + U_MM, id: "wd.base") { app.sheet = .wField(pid: pid, fid: fid, key: "base", sec: 0) }
            }
        }
    }

    /// The box standing as k says: hung on the wall, or on legs or a plinth with its whole height kept.
    static func based(_ mm: Module, _ k: String, _ ws: Workshop) -> Module {
        var n = mm
        if k == "wall" {
            // on the wall its top stays where it was: lifted by its plinth or legs, the carcass that much lower
            let e = max(100, legsOf(mm, ws) + wardBase(mm))
            n.legs = false; n.base = 0; n.elev = e; n.h = max(300, outerH(mm, ws) - e)
            return n
        }
        let legs = k == "legs" ? ws.legH : 0
        // back on the floor: what it was lifted by (at most a plinth's or the legs' height) comes back, so a round trip keeps its height
        let lift = min(mm.elev, max(100, PLINTH, ws.legH))
        let whole = hung(mm) ? mm.h + lift : outerH(mm, ws)
        n.legs = k == "legs"; n.base = nil; n.elev = 0; n.h = max(300, whole - legs)
        return n
    }
}

/// Sliding doors: how many, what each one is filled with, and their sizes.
private struct SlideDoors: View {
    let p: Project, f: Furniture, m: Module
    let sl: Slide
    let ws: Workshop
    var body: some View {
        let n = min(4, max(2, sl.n))
        let (dw, dh) = slideDoor(m, ws.t)
        let (pw, ph) = slidePanel(m, ws.t)
        VStack(alignment: .leading, spacing: 10) {
            FStepper(label: tr("wd.slideN"), v: n, lo: 2, hi: 4, id: "wd.slideN") { v in ward(p.id, f.id) { mm in var o = mm; var x = sl; x.n = v; o.slide = x; return o } }
            ForEach(0..<n, id: \.self) { i in
                HStack(spacing: 6) {
                    T(tr("wd.slideI", ["n": i + 1]), ui(14, 600), lines: 1).frame(width: 76, alignment: .leading)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["ldsp", "mirror", "glass"], id: \.self) { k in
                                FChip(label: tr("wd.fill." + k), on: sl.panel(i) == k) {
                                    ward(p.id, f.id) { mm in var o = mm; o.slide = Slide(sl.n, (0..<n).map { j in j == i ? k : sl.panel(j) }); return o }
                                }
                                .accessibilityIdentifier("wd.fill\(i + 1).\(k)")
                            }
                        }
                    }
                }
            }
            T(tr("wd.slideSize", ["w": dw, "h": dh, "pw": pw, "ph": ph]), num(14, 700))
            T(tr("wd.slideNote", ["d": SLIDE_D]), ui(12.5, 400, G.ink2, lh: 1.4))
        }
    }
}

private struct DoorStep: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    let sel: Int
    let onSec: (Int) -> Void
    var body: some View {
        let ws = AppSettings.shared.workshop
        if sel < m.sections.count {
            let s = m.sections[sel]
            let cur = s.fronts.kind == "open" ? "0" : s.fronts.n >= 2 ? "2" : "1"
            let fr = { (k: String) -> Fronts in k == "0" ? Fronts("open", 0) : k == "2" ? Fronts("door", 2) : Fronts("door", 1) }
            VStack(alignment: .leading, spacing: 10) {
                // hinged doors on each section, or sliding doors over the whole front (plan 1b-2)
                // sliding doors are for wardrobes; the other cabinets have hinged doors or none
                if f.type.isEmpty {
                    Seg(items: [("hinged", tr("wd.hingedT")), ("slide", tr("wd.slideT"))], cur: m.slide == nil ? "hinged" : "slide") { k in
                        if (k == "slide") != (m.slide != nil) {
                            ward(p.id, f.id) { mm in var n = mm; n.slide = k == "slide" ? Slide(slideDoorsFor(slideOpening(mm, ws.t).0)) : nil; return n }
                        }
                    }
                }
                if let sl = m.slide {
                    SlideDoors(p: p, f: f, m: m, sl: sl, ws: ws)
                    // the drawers behind the sliding doors: their handles one by one, or all of the box at once
                    SlideDrawerHandles(pid: p.id, fid: f.id, m: m)
                } else {
                    T(tr("wd.doors", ["s": sel + 1]), ui(15.5, 800))
                    SecChips(m: m, sel: sel, onPick: onSec)
                    Seg(items: [("2", tr("wd.d2")), ("1", tr("wd.d1")), ("0", tr("wd.d0"))], cur: cur) { k in changeSec(p.id, f.id, sel) { x in var n = x; n.fronts = fr(k); return n } }
                    // what the doors are: the front board, a mirror on it, or glass in an aluminium frame
                    if cur != "0" {
                        Seg(items: [("", tr("wd.face.ldsp")), ("mirror", tr("wd.face.mirror")), ("glass", tr("wd.face.glass"))], cur: s.face) { k in
                            changeSec(p.id, f.id, sel) { x in var n = x; n.face = k; return n }
                        }
                    }
                    // one door: which way it opens, its handle on the other edge
                    if cur == "1" {
                        Seg(items: [("L", tr("wd.openL")), ("R", tr("wd.openR"))], cur: hingeRight(m, sel) ? "R" : "L") { k in
                            changeSec(p.id, f.id, sel) { x in var n = x; n.hinge = k; return n }
                        }
                        T(tr("wd.openNote"), ui(12.5, 400, G.ink2, lh: 1.4))
                    }
                    HStack(spacing: 8) {
                        Spacer()
                        GBtn(tr("wd.all"), kind: .secondary, height: 40, corner: 14, fontSize: 14, fill: false) {
                            ward(p.id, f.id) { mm in
                                var n = mm
                                n.sections = mm.sections.map { x in
                                    var y = x; y.fronts = cur == "0" ? fr("0") : Fronts("door", cur == "2" && x.w >= 400 ? 2 : 1)
                                    return frontsChanged(x, y)
                                }
                                return n
                            }
                        }
                        .accessibilityIdentifier("wd.all")
                    }
                    // handles: each door and drawer on its own (tapped on the drawing), or all of the box at once; soft
                    // close per section (25 Oct 2026)
                    DoorHandles(app: app, pid: p.id, fid: f.id, m: m, sel: sel, cur: cur, edge: opensByEdge(f))
                    if let dh = frontSizes(Fronts("door", 1), s.w, m.h - wardBase(m), ws).first?.0 {
                        // how many hinges: workshop detail, the advanced app only
                        let hinges = AppSettings.shared.advanced ? tr("wd.hinges", ["v": dh, "n": hingesFor(dh)]) + " " : ""
                        T(hinges + tr("wd.tapSec"), ui(12.5, 400, G.ink2, lh: 1.4))
                    }
                }
            }
        }
    }
}

/// The doors step's handles ("Tutqichlar": the count, "Hammasiga" / "Hech biriga") and the section's soft close with
/// its own "Hammasiga" for every section of the piece.
private struct DoorHandles: View {
    let app: AppModel
    let pid: String, fid: String
    let m: Module
    let sel: Int
    let cur: String
    /// The piece opens by its edge (opensByEdge): the fronts without a handle need no push latch.
    let edge: Bool
    var body: some View {
        let pid = self.pid, fid = self.fid
        VStack(alignment: .leading, spacing: 10) {
            HandleButtons(ms: [m], onAll: { ward(pid, fid) { allHandles($0, true) } }, onNone: { ward(pid, fid) { allHandles($0, false) } }, edge: edge)
            if handleFronts(m).contains(where: { !$0.inner }) { T(tr(edge ? "hd.tapE" : "hd.tap"), ui(12.5, 400, G.ink2, lh: 1.4)) }
            // the drawers behind the doors are hidden on the picture: a chip each (25 Oct 2026)
            InnerDrawers(m: m) { fr in ward(pid, fid) { toggleHandle($0, fr.key) } }
            if cur != "0" { softRow }
        }
    }

    private var softRow: some View {
        let soft = softOf(m, sel), i = sel
        let pid = self.pid, fid = self.fid
        return HStack(spacing: 8) {
            FToggle(label: tr("km.soft") + " · " + tr("hd.secN", ["s": i + 1]), on: soft, id: "wd.soft") { ward(pid, fid) { withSoft($0, i, !soft) } }
                .frame(maxWidth: .infinity)
            GBtn(tr("hd.all"), kind: .secondary, height: 40, corner: 14, fontSize: 14, fill: false) { self.softEverywhere(soft) }
                .accessibilityIdentifier("hd.softAll")
        }
    }

    /// Every section of every box of the piece closing as the one picked.
    private func softEverywhere(_ on: Bool) {
        KitOps.shared.change(pid, fid) { x in
            var y = x
            y.modules = x.modules.map { $0.type == "wardrobe" ? softAll($0, on) : $0 }
            return y
        }
        app.say("hd.softAll", ["v": tr(on ? "hd.yes" : "hd.no")])
    }
}

/// The sliding doors step's handles: the drawers behind the doors, one by one or all of the box at once.
private struct SlideDrawerHandles: View {
    let pid: String, fid: String
    let m: Module
    var body: some View {
        let pid = self.pid, fid = self.fid
        VStack(alignment: .leading, spacing: 10) {
            HandleButtons(ms: [m], onAll: { ward(pid, fid) { allHandles($0, true) } }, onNone: { ward(pid, fid) { allHandles($0, false) } })
            InnerDrawers(m: m) { fr in ward(pid, fid) { toggleHandle($0, fr.key) } }
        }
    }
}

/// A row of a section's inside list: r its place from the top, idx the insert's index in the section.
private struct InsRow: Identifiable { let id: Int; let r: Int; let x: Insert }

/// A row's height and the space under it: how far a drag moves a row by one place.
private let INS_ROW_H: CGFloat = 48
private let INS_PITCH: CGFloat = 52

private struct InsideStep: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    let sel: Int
    let onSec: (Int) -> Void
    /// The row being dragged by its handle (-1: none) and how far it has moved.
    @State private var dragI = -1
    @State private var dragDy: CGFloat = 0

    /// The list from the top down (the highest first; equal heights in the section's order).
    private func rowsOf(_ s: Section) -> [InsRow] {
        let sorted = s.inserts.enumerated().sorted { ($0.element.pos, $1.offset) > ($1.element.pos, $0.offset) }
        var out: [InsRow] = []
        for (r, e) in sorted.enumerated() { out.append(InsRow(id: e.offset, r: r, x: e.element)) }
        return out
    }

    /// Row from dropped dy lower: moved to its new place, then they all spread evenly over the section. It reads the
    /// section as it is when the drag ends (an edit, an undo or a first reorder may have changed it).
    private func drop(_ from: Int, _ dy: CGFloat, _ ws: Workshop) {
        guard from >= 0, dy.isFinite else { return }
        let ih = wardInnerH(m, ws.t), t = ws.t
        let step = Int((dy / INS_PITCH).rounded())
        changeSec(p.id, f.id, sel) { y in
            let now = rowsOf(y)
            guard from < now.count else { return y }
            let to = min(max(from + step, 0), now.count - 1)
            if to == from { return y }
            var order = now.map(\.x)
            let moved = order.remove(at: from)
            order.insert(moved, at: to)
            let spread = respaced(Array(order.reversed()), ih, t)
            var n = y; n.inserts = sortedByPos(spread); return n
        }
    }

    var body: some View {
        let ws = AppSettings.shared.workshop
        if sel < m.sections.count {
            let s = m.sections[sel]
            VStack(alignment: .leading, spacing: 10) {
                T(tr("wd.inside", ["s": sel + 1]), ui(15.5, 800))
                SecChips(m: m, sel: sel, onPick: onSec)
                if s.inserts.isEmpty { T(tr("wd.empty"), ui(13, 400, G.ink2, lh: 1.4)) }
                else if s.inserts.count > 1 { T(tr("wd.dragNote"), ui(12.5, 400, G.ink2, lh: 1.4)) }
                // a row's handle drags it to another place, then they all spread evenly over the section
                let rows = rowsOf(s)
                VStack(spacing: INS_PITCH - INS_ROW_H) {
                    ForEach(rows) { row in insRow(rows, row, ws) }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([("shelf", "wd.addShelf"), ("drawer", "wd.addDrawer"), ("rail", "wd.addRail")], id: \.0) { k, t in
                            FChip(label: tr(t), on: false) { addInsert(app, p.id, f.id, m, sel, k) }.accessibilityIdentifier("wd.add." + k)
                        }
                        FChip(label: tr("wd.more"), on: false) { app.sheet = .wMore(pid: p.id, fid: f.id, sec: sel) }.accessibilityIdentifier("wd.more")
                    }
                }
                if s.inserts.filter({ $0.kind == "shelf" }).count > 1 {
                    GBtn(tr("wd.spread"), kind: .secondary, height: 42, corner: 14, fontSize: 14) {
                        changeSec(p.id, f.id, sel) { spreadShelves($0, wardInnerH(m, ws.t), ws.t) }
                    }
                    .accessibilityIdentifier("wd.spread")
                }
                // the strip runs along the whole box's top, not the section picked above: it says so (25 Oct 2026)
                FToggle(label: tr("wd.ledAll"), on: m.led, id: "wd.led") { ward(p.id, f.id) { x in var n = x; n.led.toggle(); return n } }
            }
            .onChange(of: sel) { _, _ in dragI = -1; dragDy = 0 }
        }
    }

    private func insRow(_ rows: [InsRow], _ row: InsRow, _ ws: Workshop) -> some View {
        let i = row.id, x = row.x, r = row.r
        let dragged = r == dragI
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        // measured on the screen, not in the grip's own space (which moves with the row): the row keeps up with the finger
        let drag = DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in dragI = r; dragDy = v.translation.height }
            .onEnded { v in drop(r, v.translation.height, ws); dragI = -1; dragDy = 0 }
        return HStack(spacing: 8) {
            if rows.count > 1 {
                MIcon("grip", G.ink3, 20, 2).frame(width: 40, height: 40).contentShape(Rectangle())
                    .highPriorityGesture(drag)
                    .accessibilityLabel(tr("wd.drag"))
            }
            T(tr("wi." + x.kind), ui(14, 700)).frame(maxWidth: .infinity, alignment: .leading)
            T(blockH(x) > 0 ? tr("wi.atH", ["v": x.pos, "h": blockH(x)]) : tr("wi.at", ["v": x.pos]), num(13.5, 600, G.ink2))
            MIcon("x", G.ink3, 16, 2).frame(width: 40, height: 40).pressable(0.95, label: tr("common.delete")) {
                // the insert itself at the tap (the list may have changed since it was drawn)
                changeSec(p.id, f.id, sel) { y in
                    var n = y
                    let k: Int?
                    if i < y.inserts.count && y.inserts[i] == x { k = i } else { k = y.inserts.firstIndex(of: x) }
                    if let k { n.inserts.remove(at: k) }
                    return n
                }
                app.say("kt.deleted", ["m": tr("wi." + x.kind)], action: "common.undo") { KitOps.shared.undo(p.id, f.id) }
            }
        }
        .padding(.horizontal, 4).frame(height: INS_ROW_H)
        .background(shape.fill(dragged ? G.glass(0.95) : Color.clear))
        .pressable(0.99) { app.sheet = .wInsert(pid: p.id, fid: f.id, sec: sel, idx: i) }
        .accessibilityIdentifier("wd.ins.\(x.kind).\(i)")
        .offset(y: dragged ? dragDy : 0)
        .zIndex(dragged ? 1 : 0)
    }
}

struct MatStep: View {
    let app: AppModel
    let p: Project, f: Furniture
    var body: some View {
        let mats = AppSettings.shared.mats
        VStack(alignment: .leading, spacing: 4) {
            T(tr("wd.mats"), ui(15.5, 800)).padding(.bottom, 6)
            ForEach([("carcass", f.mats.carcass), ("front", f.mats.front), ("back", f.mats.back)], id: \.0) { role, id in
                let mt = mats.first { $0.id == id }, tile = RoundedRectangle(cornerRadius: 8, style: .continuous)
                HStack(spacing: 10) {
                    tile.fill(matColor(mt?.rgb ?? "#FFFFFF")).overlay(tile.strokeBorder(G.ink.opacity(0.2), lineWidth: 1)).frame(width: 28, height: 28)
                    T(tr("wd." + role), ui(14.5, 700)).frame(maxWidth: .infinity, alignment: .leading)
                    T(mt?.name ?? id, ui(13.5, 400, G.ink2), lines: 1)
                    MIcon("chev", G.ink3, 16, 2)
                }
                .padding(.horizontal, 4).frame(minHeight: 52)
                .pressable(0.99) { app.sheet = .fMats(pid: p.id, fid: f.id) }
                .accessibilityIdentifier("wd.mat." + role)
            }
        }
    }
}

/* ---------------- sheets ---------------- */

struct WardrobeSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .wField, .wInsert, .wMore, .iField: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .wField(let pid, let fid, let key, let sec): WFieldSheet(app: app, pid: pid, fid: fid, key: key, sec: sec)
        case .wInsert(let pid, let fid, let sec, let idx): WInsertSheet(app: app, pid: pid, fid: fid, sec: sec, idx: idx)
        case .wMore(let pid, let fid, let sec): WMoreSheet(app: app, pid: pid, fid: fid, sec: sec)
        case .iField(let pid, let fid, let mid, let key): IFieldSheet(app: app, pid: pid, fid: fid, mid: mid, key: key)
        default: EmptyView()
        }
    }
}

private enum WF2: Hashable { case a, b }

private struct WFieldSheet: View {
    let app: AppModel
    let pid: String, fid: String, key: String, sec: Int
    @State private var v: String
    @FocusState private var focus: WF2?
    init(app: AppModel, pid: String, fid: String, key: String, sec: Int) {
        self.app = app; self.pid = pid; self.fid = fid; self.key = key; self.sec = sec
        let m = Store.shared.get(pid)?.furniture.first { $0.id == fid }.flatMap(curWard)
        let ws = AppSettings.shared.workshop
        let start: Int = { switch key { case "h": return m?.h ?? 0; case "e": return m?.elev ?? 0; case "d": return m?.d ?? 0; case "x": return m?.x ?? 0
                                        case "base": return m.map { $0.legs ? legsOf($0, ws) : wardBase($0) } ?? 0
                                        case "secW": return m.flatMap { sec < $0.sections.count ? $0.sections[sec].w : nil } ?? 0; default: return m?.w ?? 0 } }()
        _v = State(initialValue: String(start))
    }
    // a section can grow until each of the others keeps 150 (locked ones their width, one of them gives way if all are)
    private func secRange(_ m: Module, _ sec: Int) -> ClosedRange<Int> {
        if m.sections.count == 1 { return m.w...m.w }
        let o = m.sections.enumerated().filter { $0.offset != sec }.map(\.element)
        let locked = o.filter(\.lock)
        let give = locked.count == o.count ? (locked.last?.w ?? 150) - 150 : 0
        return 150...max(150, m.w - locked.reduce(0) { $0 + $1.w } - 150 * (o.count - locked.count) + give)
    }
    private func rangeOf(_ m: Module, _ wallL: Int?, _ typed: Bool) -> ClosedRange<Int> {
        switch key {
        case "h": return typed ? 150...3000 : 600...3000
        case "e": return 50...2400
        case "d": return 250...900
        case "x": return 0...max(0, (wallL ?? 10000) - 300)
        case "base": return m.legs ? 50...250 : 50...200
        case "secW": return secRange(m, sec)
        default: return 300...6000
        }
    }
    private func titleOf(_ m: Module) -> String {
        switch key {
        case "h": return tr("wd.h")
        case "d": return tr("wd.d")
        case "x": return tr("wd.x")
        case "e": return tr("fz.elev")
        case "base": return tr(m.legs ? "wd.legsH" : "wd.plinthH")
        case "secW": return tr("wd.secT", ["n": sec + 1])
        default: return tr("wd.w")
        }
    }
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = curWard(f) {
            let wallL = roomOf(p, f).flatMap { wallLen($0, AppSettings.shared.angleSnap, m.wall ?? "") }
            let n = m.sections.count
            let secLock = sec < n && m.sections[sec].lock
            let ws = AppSettings.shared.workshop
            let range: ClosedRange<Int> = rangeOf(m, wallL, !f.type.isEmpty)
            let vi = Int(v).flatMap { range.contains($0) ? $0 : nil }
            let title = titleOf(m)
            let save = {
                guard let x = vi else { return }
                ward(p.id, f.id) { mm in
                    var out = mm
                    switch key {
                    case "h": out.h = x
                    case "e": out.elev = x
                    case "d": out.d = x
                    case "x": out.x = x
                    // the whole height stays: taller legs, a shorter carcass (a plinth is inside the carcass)
                    case "base":
                        if mm.legs { out.h = max(300, mm.h - (x - legsOf(mm, ws))) }
                        out.base = x
                    case "secW":
                        var secs = mm.sections.enumerated().map { i, s in i == sec ? { var y = s; y.w = x; y.lock = true; return y }() : s }
                        // someone has to give way: the last other section takes what is left
                        if secs.allSatisfy(\.lock) && secs.count > 1 { secs[sec == secs.count - 1 ? secs.count - 2 : secs.count - 1].lock = false }
                        out.sections = splitSections(mm.w, secs)
                    default:
                        out.w = x
                        out.sections = splitSections(x, mm.sections.allSatisfy(\.lock) ? mm.sections.map { var s = $0; s.lock = false; return s } : mm.sections)
                    }
                    return out
                }
                app.sheet = nil
            }
            GlassSheet(title, onClose: { app.sheet = nil }) {
                GField(label: title, value: $v, placeholder: v, error: tr("km.bad", ["a": range.lowerBound, "b": range.upperBound]), showError: vi == nil, focus: $focus, me: .a,
                       submit: .done, onSubmit: save, labelRight: tr("u.mm"), number: true, id: "wf.value")
                if key == "secW" {
                    T(tr("wd.secNote"), ui(12.5, 400, G.ink2, lh: 1.4))
                    if secLock {
                        GBtn(tr("wd.unlock"), kind: .secondary, height: 44, corner: 14, fontSize: 14.5) {
                            ward(p.id, f.id) { mm in var o = mm; o.sections = splitSections(mm.w, mm.sections.enumerated().map { i, s in var y = s; if i == sec { y.lock = false }; return y }); return o }
                            app.sheet = nil
                        }
                        .accessibilityIdentifier("wf.unlock")
                    }
                }
                if key == "x", let wallL { T(tr("wd.xNote", ["v": wallL - m.w - (vi ?? m.x)]), ui(12.5, 400, G.ink2, lh: 1.4)) }
            } footer: {
                GBtn(tr("common.save"), enabled: vi != nil) { save() }.accessibilityIdentifier("wf.save")
            }
            .onChange(of: v) { _, x in let t = String(x.filter(\.isNumber).prefix(4)); if t != x { v = t } }
            // the keyboard comes up with the sheet
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .a } }
        }
    }
}

private struct WInsertSheet: View {
    let app: AppModel
    let pid: String, fid: String, sec: Int, idx: Int
    @State private var pos: String
    @State private var h: String
    @FocusState private var focus: WF2?
    init(app: AppModel, pid: String, fid: String, sec: Int, idx: Int) {
        self.app = app; self.pid = pid; self.fid = fid; self.sec = sec; self.idx = idx
        let m = Store.shared.get(pid)?.furniture.first { $0.id == fid }.flatMap(curWard)
        let x = m.flatMap { sec < $0.sections.count && idx < $0.sections[sec].inserts.count ? $0.sections[sec].inserts[idx] : nil }
        _pos = State(initialValue: String(x?.pos ?? 0)); _h = State(initialValue: String(x.map(blockH) ?? 0))
    }
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = curWard(f),
           sec < m.sections.count, idx < m.sections[sec].inserts.count {
            let x = m.sections[sec].inserts[idx]
            let ih = wardInnerH(m, AppSettings.shared.workshop.t)
            let block = blockH(x) > 0
            let pi = Int(pos).flatMap { (0...ih).contains($0) ? $0 : nil }
            let hi: Int? = block ? Int(h).flatMap { (60...1200).contains($0) ? $0 : nil } : 0
            let save = {
                guard let pi, let hi else { return }
                changeSec(p.id, f.id, sec) { ss in
                    var n = ss
                    n.inserts = sortedByPos(ss.inserts.enumerated().map { k, y in k == idx ? { var z = y; z.pos = pi; if block { z.h = hi }; return z }() : y })
                    return n
                }
                app.sheet = nil
            }
            GlassSheet(tr("wi." + x.kind), onClose: { app.sheet = nil }) {
                GField(label: tr("wd.pos"), value: $pos, placeholder: "0", error: tr("km.bad", ["a": 0, "b": ih]), showError: pi == nil, focus: $focus, me: .a,
                       submit: block ? .next : .done, onSubmit: { if block { focus = .b } else { save() } }, labelRight: tr("u.mm"), number: true, id: "wi.pos")
                if block {
                    GField(label: tr("wd.bh"), value: $h, placeholder: "200", error: tr("km.bad", ["a": 60, "b": 1200]), showError: hi == nil, focus: $focus, me: .b,
                           submit: .done, onSubmit: save, labelRight: tr("u.mm"), number: true, id: "wi.h")
                }
                T(tr("wd.posNote", ["v": ih]), ui(12.5, 400, G.ink2, lh: 1.4))
            } footer: {
                HStack(spacing: 8) {
                    GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 48, corner: 16, fontSize: 15) {
                        changeSec(p.id, f.id, sec) { ss in var n = ss; n.inserts.remove(at: idx); return n }
                        app.sheet = nil
                        app.say("kt.deleted", ["m": tr("wi." + x.kind)], action: "common.undo") { KitOps.shared.undo(p.id, f.id) }
                    }
                    GBtn(tr("common.save"), enabled: pi != nil && hi != nil, height: 48, corner: 16, fontSize: 15) { save() }.accessibilityIdentifier("wi.save")
                }
            }
            .onChange(of: pos) { _, v in let t = String(v.filter(\.isNumber).prefix(4)); if t != v { pos = t } }
            .onChange(of: h) { _, v in let t = String(v.filter(\.isNumber).prefix(4)); if t != v { h = t } }
        }
    }
}

private struct WMoreSheet: View {
    let app: AppModel
    let pid: String, fid: String, sec: Int
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = curWard(f) {
            GlassSheet(tr("wd.moreT"), onClose: { app.sheet = nil }) {
                VStack(spacing: 8) {
                    ForEach(["trouser", "shoe", "lift", "glass"], id: \.self) { k in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                T(tr("wi." + k), ui(15, 700))
                                T(tr("wid." + k) + (blockH(Insert(k)) > 0 ? " · \(blockH(Insert(k))) mm" : ""), ui(12.5, 400, G.ink2))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            MIcon("plus", G.cobalt2, 20, 2.4)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 60)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.05)))
                        .pressable(0.98) { app.sheet = nil; addInsert(app, p.id, f.id, m, sec, k) }
                        .accessibilityIdentifier("wm." + k)
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }
}

/* ---------------- Designer C: "Batafsil" ---------------- */

/// Designer C "Batafsil" for a cabinet: the older steps one tab at a time (sizes, place, doors, inside, materials and
/// the design), a stenka's boxes, a gorka's options, the checks and the cost.
struct DzcWardMore: View {
    let app: AppModel
    let pid: String, fid: String
    @State private var tab: String
    init(app: AppModel, pid: String, fid: String, tab: String) {
        self.app = app; self.pid = pid; self.fid = fid
        _tab = State(initialValue: tab)
    }
    var body: some View {
        let _ = KitOps.shared.tick
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = curWard(f) {
            let s = AppSettings.shared
            let cx = WardCtx(p, f, m, s.workshop, s.angleSnap)
            let sel = min(max(DzcState.shared.sec, 0), max(0, m.sections.count - 1))
            let onSec = { (i: Int) in DzcState.shared.sec = i }
            let tabs = Self.tabs(f)
            GlassSheet(tr("dzc.t.more"), onClose: { app.sheet = nil }) {
                Seg(items: tabs, cur: tab) { tab = $0 }
                switch tab {
                case "size": WardSizeStep(app: app, p: p, f: f, m: m)
                case "place": PlaceStep(app: app, p: p, f: f, m: m, cx: cx)
                case "doors": DoorStep(app: app, p: p, f: f, m: m, sel: sel, onSec: onSec)
                case "inside": InsideStep(app: app, p: p, f: f, m: m, sel: sel, onSec: onSec)
                case "boxes": BoxPicker(app: app, p: p, f: f, cur: m) {}
                case "gorka": GorkaCard(app: app, p: p, f: f)
                default:
                    MatStep(app: app, p: p, f: f)
                    DesignCard(app: app, p: p, f: f)
                }
                LivePrice(app: app, p: p, f: f)
                ChecksCard(f: f, found: cx.found + drawerRule(f, s.workshop, s.mats)) { _ in }
                CostCard(p: p, f: f)
            }
        }
    }

    private static func tabs(_ f: Furniture) -> [(String, String)] {
        var out: [(String, String)] = [("size", tr("dzc.tab.size")), ("place", tr("dzc.tab.place")), ("doors", tr("dzc.tab.doors")), ("inside", tr("dzc.tab.inside")), ("mats", tr("dzc.tab.mats"))]
        if f.type == "stenka" || boxes(f).count > 1 { out.append(("boxes", tr("dzc.tab.boxes"))) }
        if f.type == "gorka" { out.append(("gorka", tr("dzc.tab.gorka"))) }
        return out
    }
}
