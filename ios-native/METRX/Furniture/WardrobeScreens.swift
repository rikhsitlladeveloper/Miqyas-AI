import SwiftUI

/*
 * Furniture makers, Stage 1a part 5 (furniture plan section 8; design canvas screen 11; Android
 * ui/furniture/WardrobeScreens.kt): the wardrobe designer in five steps (place, sizes, doors, inside, material) over
 * its front drawing. Hinged doors, open, or sliding doors over the whole front (1b-2). The rules are in
 * Furniture/Core/Wardrobe.swift.
 */

func wardOf(_ f: Furniture) -> Module? { f.modules.first { $0.type == "wardrobe" } }

/// Changes the wardrobe of furniture fid (on the designer's undo list).
private func ward(_ pid: String, _ fid: String, _ fn: @escaping (Module) -> Module) {
    KitOps.shared.change(pid, fid) { x in var y = x; y.modules = y.modules.map { $0.type == "wardrobe" ? fn($0) : $0 }; return y }
}

private func changeSec(_ pid: String, _ fid: String, _ i: Int, _ fn: @escaping (Section) -> Section) {
    ward(pid, fid) { m in var n = m; n.sections = m.sections.enumerated().map { k, s in k == i ? fn(s) : s }; return n }
}

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
private struct WardCtx {
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
        found = wardrobeChecks(m, wallL, roomH, ws, room?.openings ?? [], room?.points ?? [])
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
/// (unless the doors are shown), doors, problem outlines and the selected section.
func drawWard(_ c: GraphicsContext, _ lay: KLay, _ m: Module, _ ox: Int, _ ws: Workshop, _ carcassRgb: Int, _ frontRgb: Int, _ sel: Int, _ doors: Bool,
              _ bad: [Int: String], labels: Bool) {
    let t = ws.t, z0 = m.legs ? ws.legH : 0, base = wardBase(m)
    func X(_ mm: Int) -> CGFloat { lay.x(mm - ox) }
    let l = X(m.x), r = X(m.x + m.w), top = lay.y(z0 + m.h), bot = lay.y(z0)
    let carcass = opaque(carcassRgb), front = opaque(frontRgb), onC = lineOn(carcassRgb), onF = lineOn(frontRgb)
    c.fill(rect(l, top, r - l, bot - top), with: .color(carcass))
    if !m.legs { c.fill(rect(l, lay.y(PLINTH), r - l, CGFloat(PLINTH) * lay.s), with: .color(PC.greyLine.opacity(0.4))) }
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
                case "rail": c.line(PC.greyLine, CGPoint(x: il + 3, y: lay.y(y0)), CGPoint(x: ir - 3, y: lay.y(y0)), 2.4, round: true)
                case "lift":
                    c.stroke(rect(il + 3, lay.y(y0 + h), ir - il - 6, CGFloat(h) * lay.s), with: .color(PC.greyLine), style: StrokeStyle(lineWidth: 1, dash: DASH))
                    c.line(PC.greyLine, CGPoint(x: il + 5, y: lay.y(y0 + 40)), CGPoint(x: ir - 5, y: lay.y(y0 + 40)), 2.4, round: true)
                default:
                    let bt = lay.y(y0 + h), bh = max(2, CGFloat(h) * lay.s - 1)
                    let box = Path(roundedRect: CGRect(x: il + 1.5, y: bt, width: ir - il - 3, height: bh), cornerRadius: 1.5)
                    c.fill(box, with: .color(x.kind == "drawer" ? front : GAP_FILL)); c.stroke(box, with: .color(onC), lineWidth: 0.9)
                    switch x.kind {
                    case "drawer": let cx = (il + ir) / 2, y = bt + min(4, bh / 3); c.line(onF, CGPoint(x: cx - 6, y: y), CGPoint(x: cx + 6, y: y), 1.4, round: true)
                    case "trouser": for k in 1...4 { let xx = il + (ir - il) * CGFloat(k) / 5; c.line(PC.ink3, CGPoint(x: xx, y: bt + 2), CGPoint(x: xx, y: bt + bh - 2), 0.8) }
                    case "shoe": c.line(PC.ink3, CGPoint(x: il + 4, y: bt + bh - 2), CGPoint(x: ir - 4, y: bt + 2), 0.9)
                    default: break
                    }
                }
            }
        }
        if doors && !open && !slide {
            let n = frontSizes(s.fronts, s.w, m.h - base, ws).count
            if n > 0 {
                let g = max(0.8, CGFloat(ws.gap10) / 10 * lay.s)
                let ft = top + g, fb = lay.y(z0 + base) - g
                let fw = (sr - sl - g * CGFloat(n + 1)) / CGFloat(n)
                for j in 0..<n {
                    let fx = sl + g + CGFloat(j) * (fw + g)
                    c.fill(rect(fx, ft, fw, fb - ft), with: .color(front)); c.stroke(rect(fx, ft, fw, fb - ft), with: .color(onF), lineWidth: 0.8)
                    if m.handles {
                        let hx = n == 2 ? (j == 0 ? fx + fw - 3 : fx + 3) : (i % 2 == 0 ? fx + fw - 3 : fx + 3)
                        let hy = lay.y(z0 + 1000)
                        c.line(onF, CGPoint(x: hx, y: hy - 9), CGPoint(x: hx, y: hy + 9), 1.6, round: true)
                    }
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
    var body: some View {
        let onWall = step == 1
        let doors = step == 1 || step == 3 || step == 5
        let ox = onWall ? 0 : m.x
        let L = onWall ? max(cx.wallL ?? (m.x + m.w + W_GAP_SIDE), m.x + m.w) : m.w
        let H = onWall ? max(cx.roomH ?? 2700, outerH(m, ws)) : outerH(m, ws)
        let lay = KLay(L, H, 360, true)
        let front = rgbOf(mats.first { $0.id == f.mats.front }?.rgb ?? "#CDBFAE"), carcass = rgbOf(mats.first { $0.id == f.mats.carcass }?.rgb ?? "#F5F5F2")
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        GeometryReader { geo in
            Canvas { ctx, size in
                var c = ctx; let k = size.width / lay.vw; c.scaleBy(x: k, y: k)
                if onWall { drawWallFace(c, lay, cx.room, m.wall ?? "") }
                c.line(PC.ink, CGPoint(x: lay.x0 - 10, y: lay.yF), CGPoint(x: lay.x(L) + 10, y: lay.yF), 2)
                drawWard(c, lay, m, ox, ws, carcass, front, (step == 3 && m.slide == nil) || step == 4 ? sel : -1, doors, cx.bad, labels: true)
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
    }
}

/// A small picture for the workspace card.
struct WardThumb: View {
    let f: Furniture
    var body: some View {
        let s = AppSettings.shared
        Canvas { ctx, size in
            guard let m = wardOf(f) else { return }
            let ws = s.workshop
            let front = rgbOf(s.mats.first { $0.id == f.mats.front }?.rgb ?? "#CDBFAE"), carcass = rgbOf(s.mats.first { $0.id == f.mats.carcass }?.rgb ?? "#F5F5F2")
            let lay = KLay(m.w, outerH(m, ws), 200, false)
            let k = min(size.width / lay.vw, size.height / lay.vh)
            var c = ctx
            c.translateBy(x: (size.width - lay.vw * k) / 2, y: (size.height - lay.vh * k) / 2); c.scaleBy(x: k, y: k)
            c.line(PC.ink, CGPoint(x: lay.x0 - 6, y: lay.yF), CGPoint(x: lay.x(m.w) + 6, y: lay.yF), 2)
            drawWard(c, lay, m, m.x, ws, carcass, front, -1, true, [:], labels: false)
        }
    }
}

/* ---------------- the designer ---------------- */

struct WardrobeScreen: View {
    let app: AppModel
    let pid: String, fid: String, step: Int, sec: Int
    var d3 = false
    var body: some View {
        let kit = KitOps.shared
        let _ = kit.tick
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = wardOf(f) {
            let s = AppSettings.shared, ws = s.workshop, mats = s.mats
            let cx = WardCtx(p, f, m, ws, s.angleSnap)
            let sel = min(max(sec, 0), max(0, m.sections.count - 1))
            let pick = { (i: Int) in app.setTop(.wardrobe(pid: pid, fid: fid, step: step, sec: i)) }
            ZStack {
                RoomGrid().ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                        VStack(alignment: .leading, spacing: 0) {
                            T(dn(f.name), ui(19, 800, G.ink, lh: 1.2), lines: 1)
                            T(tr("wd.sub", ["w": m.w, "h": outerH(m, ws), "d": m.d, "n": m.sections.count]), ui(12, 400, G.ink2), lines: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        GlassIconButton("undo", tr("common.undo"), tint: kit.canUndo(f.id) ? G.ink : PC.offIcon) { kit.undo(p.id, f.id) }.accessibilityIdentifier("kt.undo")
                        GlassIconButton("redo", "redo", tint: kit.canRedo(f.id) ? G.ink : PC.offIcon) { kit.redo(p.id, f.id) }
                        GlassIconButton("more", "menu") { app.sheet = .fMenu(pid: p.id, fid: f.id) }.accessibilityIdentifier("kt.menu")
                    }
                    .padding(.horizontal, 16).frame(height: 64)
                    if let room = cx.room {
                        HStack { DimSeg(d3: d3) { app.setTop(.wardrobe(pid: pid, fid: fid, step: step, sec: sel, d3: $0)) }; Spacer() }
                            .padding(.horizontal, 16).padding(.bottom, 10)
                        if d3 { Furniture3DPane(app: app, p: p, room: room) } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Steps(cur: step) { app.setTop(.wardrobe(pid: pid, fid: fid, step: $0, sec: sel)) }
                                WardDrawing(m: m, f: f, cx: cx, ws: ws, mats: mats, step: step, sel: sel, onSec: pick)
                                VStack(alignment: .leading, spacing: 10) {
                                    switch step {
                                    case 1: PlaceStep(app: app, p: p, f: f, m: m, cx: cx)
                                    case 2: SizeStep(app: app, p: p, f: f, m: m)
                                    case 3: DoorStep(app: app, p: p, f: f, m: m, sel: sel, onSec: pick)
                                    case 4: InsideStep(app: app, p: p, f: f, m: m, sel: sel, onSec: pick)
                                    default: MatStep(app: app, p: p, f: f)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
                                ChecksCard(f: f, found: cx.found) { _ in }
                                CostCard(p: p, f: f)
                            }
                            .padding(.horizontal, 16).padding(.bottom, 28)
                        }
                        }
                    } else {
                        T(tr("kt.roomLost"), ui(15, 500, G.ink2, lh: 1.45)).padding(24)
                        Spacer()
                    }
                }
            }
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

private struct WValRow: View {
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

/// Whether the wardrobe fills its wall as a niche.
private func isFull(_ m: Module, _ wallL: Int?) -> Bool { wallL != nil && m.x == W_GAP_SIDE && m.w == wallL! - 2 * W_GAP_SIDE }

private struct PlaceStep: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    let cx: WardCtx
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if f.roomId == nil { return AnyView(FreeBanner(app: app, p: p, f: f)) }
        if let room = cx.room {
            let full = isFull(m, cx.wallL)
            let hNew = cx.roomH.map { min(3000, max(1200, $0 - W_GAP_TOP)) } ?? m.h
            func moveTo(_ wall: String, _ len: Int?, _ whole: Bool) {
                guard let L = len else { return }
                let pl: (x: Int, w: Int, builtIn: Bool)
                if whole { pl = (W_GAP_SIDE, L - 2 * W_GAP_SIDE, true) }
                else {
                    let q = placeOn(L, wall, room.openings, hNew)
                    // the whole wall is free: a free-standing wardrobe 600 shorter
                    pl = q.builtIn ? (W_GAP_SIDE, max(600, L - 2 * W_GAP_SIDE - 600), false) : q
                }
                // a wardrobe in a niche goes up to the ceiling; a TV unit or a dresser keeps its own height
                ward(p.id, f.id) { mm in
                    var n = mm; n.wall = wall; n.x = pl.x; n.w = pl.w; if whole && f.type.isEmpty { n.h = hNew }; n.sideL = !pl.builtIn; n.sideR = !pl.builtIn
                    n.sections = splitSections(pl.w, mm.sections.map { var s = $0; s.lock = false; return s })
                    return n
                }
                Store.shared.update(p.id) { pr in if let i = pr.furniture.firstIndex(where: { $0.id == f.id }) { pr.furniture[i].walls = [wall] } }
            }
            return AnyView(VStack(alignment: .leading, spacing: 10) {
                T(tr("wd.place", ["w": m.wall ?? ""]), ui(15.5, 800))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Geo.walls(room, snap), id: \.id) { w in
                            let len = wallLen(room, snap, w.id)
                            FChip(label: tr("kt.wallN", ["w": w.id]) + (len.map { " · \($0)" } ?? ""), on: w.id == m.wall) {
                                if w.id != m.wall { moveTo(w.id, len, placeOn(len ?? 0, w.id, room.openings, hNew).builtIn) }
                            }
                            .accessibilityIdentifier("wd.wall." + w.id)
                        }
                    }
                }
                Seg(items: [("full", tr("wd.full")), ("part", tr("wd.part"))], cur: full ? "full" : "part") { k in if (k == "full") != full { moveTo(m.wall ?? "", cx.wallL, k == "full") } }
                Seg(items: [("built", tr("wd.built")), ("free", tr("wd.free"))], cur: !m.sideL && !m.sideR ? "built" : "free") { k in
                    ward(p.id, f.id) { mm in var n = mm; n.sideL = k != "built"; n.sideR = k != "built"; return n }
                }
                if full, let wallL = cx.wallL {
                    T(cx.roomH != nil ? tr("wd.niche", ["l": wallL, "h": cx.roomH!, "w": m.w, "hh": m.h]) : tr("wd.nicheNoH", ["l": wallL, "w": m.w]), ui(13, 400, G.ink2, lh: 1.45))
                } else {
                    WValRow(label: tr("wd.x"), value: "\(m.x) mm", id: "wd.x") { app.sheet = .wField(pid: p.id, fid: f.id, key: "x", sec: 0) }
                    WValRow(label: tr("wd.w"), value: "\(m.w) mm", id: "wd.w") { app.sheet = .wField(pid: p.id, fid: f.id, key: "w", sec: 0) }
                }
                if !measured(room, snap, m.wall ?? "") { T(tr("kt.noLen", ["w": m.wall ?? ""]), ui(12.5, 500, G.amberInk, lh: 1.4)) }
            })
        }
        return AnyView(EmptyView())
    }
}

private struct SizeStep: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let ws = AppSettings.shared.workshop
        VStack(alignment: .leading, spacing: 10) {
            T(tr("wd.sizes"), ui(15.5, 800))
            WValRow(label: tr("wd.w"), value: "\(m.w) mm", id: "wd.w") { app.sheet = .wField(pid: p.id, fid: f.id, key: "w", sec: 0) }
            WValRow(label: tr("wd.h"), value: "\(m.h) mm", id: "wd.h") { app.sheet = .wField(pid: p.id, fid: f.id, key: "h", sec: 0) }
            WValRow(label: tr("wd.d"), value: "\(m.d) mm", id: "wd.d") { app.sheet = .wField(pid: p.id, fid: f.id, key: "d", sec: 0) }
            T(tr("wd.base"), ui(14.5, 700))
            Seg(items: [("plinth", tr("wd.plinth")), ("legs", tr("wd.legs"))], cur: m.legs ? "legs" : "plinth") { k in ward(p.id, f.id) { mm in var n = mm; n.legs = k == "legs"; return n } }
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
            let carcass = AppSettings.shared.mats.first { $0.id == f.mats.carcass }?.name ?? f.mats.carcass
            T(tr("wd.sizeNote", ["d": m.d, "b": m.legs ? tr("wd.legs") : tr("wd.plinth"), "m": carcass]), ui(12.5, 400, G.ink2, lh: 1.4))
        }
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
                if let sl = m.slide { SlideDoors(p: p, f: f, m: m, sl: sl, ws: ws) } else {
                    T(tr("wd.doors", ["s": sel + 1]), ui(15.5, 800))
                    SecChips(m: m, sel: sel, onPick: onSec)
                    Seg(items: [("2", tr("wd.d2")), ("1", tr("wd.d1")), ("0", tr("wd.d0"))], cur: cur) { k in changeSec(p.id, f.id, sel) { x in var n = x; n.fronts = fr(k); return n } }
                    HStack(spacing: 8) {
                        Spacer()
                        GBtn(tr("wd.all"), kind: .secondary, height: 40, corner: 14, fontSize: 14, fill: false) {
                            ward(p.id, f.id) { mm in
                                var n = mm
                                n.sections = mm.sections.map { x in var y = x; y.fronts = cur == "0" ? fr("0") : Fronts("door", cur == "2" && x.w >= 400 ? 2 : 1); return y }
                                return n
                            }
                        }
                        .accessibilityIdentifier("wd.all")
                    }
                    FToggle(label: tr("km.handles") + (!m.handles ? " · " + tr("wd.push") : ""), on: m.handles, id: "wd.handles") { ward(p.id, f.id) { x in var n = x; n.handles.toggle(); return n } }
                    FToggle(label: tr("km.soft"), on: m.soft, id: "wd.soft") { ward(p.id, f.id) { x in var n = x; n.soft.toggle(); return n } }
                    if let dh = frontSizes(Fronts("door", 1), s.w, m.h - wardBase(m), ws).first?.0 {
                        T(tr("wd.hinges", ["v": dh, "n": hingesFor(dh)]) + " " + tr("wd.tapSec"), ui(12.5, 400, G.ink2, lh: 1.4))
                    }
                }
            }
        }
    }
}

private struct InsideStep: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    let sel: Int
    let onSec: (Int) -> Void
    var body: some View {
        let ws = AppSettings.shared.workshop
        if sel < m.sections.count {
            let s = m.sections[sel]
            VStack(alignment: .leading, spacing: 10) {
                T(tr("wd.inside", ["s": sel + 1]), ui(15.5, 800))
                SecChips(m: m, sel: sel, onPick: onSec)
                if s.inserts.isEmpty { T(tr("wd.empty"), ui(13, 400, G.ink2, lh: 1.4)) }
                let rows = s.inserts.enumerated().sorted { ($0.element.pos, $1.offset) > ($1.element.pos, $0.offset) }
                ForEach(rows, id: \.offset) { i, x in
                    HStack(spacing: 8) {
                        T(tr("wi." + x.kind), ui(14, 700)).frame(maxWidth: .infinity, alignment: .leading)
                        T(blockH(x) > 0 ? tr("wi.atH", ["v": x.pos, "h": blockH(x)]) : tr("wi.at", ["v": x.pos]), num(13.5, 600, G.ink2))
                        MIcon("x", G.ink3, 16, 2).frame(width: 40, height: 40).pressable(0.95, label: tr("common.delete")) {
                            changeSec(p.id, f.id, sel) { y in var n = y; n.inserts.remove(at: i); return n }
                            app.say("kt.deleted", ["m": tr("wi." + x.kind)], action: "common.undo") { KitOps.shared.undo(p.id, f.id) }
                        }
                    }
                    .padding(.horizontal, 4).frame(minHeight: 44)
                    .pressable(0.99) { app.sheet = .wInsert(pid: p.id, fid: f.id, sec: sel, idx: i) }
                    .accessibilityIdentifier("wd.ins.\(x.kind).\(i)")
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
            }
        }
    }
}

private struct MatStep: View {
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
        switch s { case .wField, .wInsert, .wMore: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .wField(let pid, let fid, let key, let sec): WFieldSheet(app: app, pid: pid, fid: fid, key: key, sec: sec)
        case .wInsert(let pid, let fid, let sec, let idx): WInsertSheet(app: app, pid: pid, fid: fid, sec: sec, idx: idx)
        case .wMore(let pid, let fid, let sec): WMoreSheet(app: app, pid: pid, fid: fid, sec: sec)
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
        let m = Store.shared.get(pid)?.furniture.first { $0.id == fid }.flatMap(wardOf)
        let start: Int = { switch key { case "h": return m?.h ?? 0; case "d": return m?.d ?? 0; case "x": return m?.x ?? 0
                                        case "secW": return m.flatMap { sec < $0.sections.count ? $0.sections[sec].w : nil } ?? 0; default: return m?.w ?? 0 } }()
        _v = State(initialValue: String(start))
    }
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = wardOf(f) {
            let wallL = roomOf(p, f).flatMap { wallLen($0, AppSettings.shared.angleSnap, m.wall ?? "") }
            let n = m.sections.count
            let secLock = sec < n && m.sections[sec].lock
            let range: ClosedRange<Int> = key == "h" ? 600...3000 : key == "d" ? 250...900 : key == "x" ? 0...max(0, (wallL ?? 10000) - 300)
                : key == "secW" ? 150...max(150, m.w - 150 * (n - 1)) : 300...6000
            let vi = Int(v).flatMap { range.contains($0) ? $0 : nil }
            let title = key == "h" ? tr("wd.h") : key == "d" ? tr("wd.d") : key == "x" ? tr("wd.x") : key == "secW" ? tr("wd.secT", ["n": sec + 1]) : tr("wd.w")
            let save = {
                guard let x = vi else { return }
                ward(p.id, f.id) { mm in
                    var out = mm
                    switch key {
                    case "h": out.h = x
                    case "d": out.d = x
                    case "x": out.x = x
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
                       submit: .done, onSubmit: save, labelRight: "mm", number: true, id: "wf.value")
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
        let m = Store.shared.get(pid)?.furniture.first { $0.id == fid }.flatMap(wardOf)
        let x = m.flatMap { sec < $0.sections.count && idx < $0.sections[sec].inserts.count ? $0.sections[sec].inserts[idx] : nil }
        _pos = State(initialValue: String(x?.pos ?? 0)); _h = State(initialValue: String(x.map(blockH) ?? 0))
    }
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = wardOf(f),
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
                       submit: block ? .next : .done, onSubmit: { if block { focus = .b } else { save() } }, labelRight: "mm", number: true, id: "wi.pos")
                if block {
                    GField(label: tr("wd.bh"), value: $h, placeholder: "200", error: tr("km.bad", ["a": 60, "b": 1200]), showError: hi == nil, focus: $focus, me: .b,
                           submit: .done, onSubmit: save, labelRight: "mm", number: true, id: "wi.h")
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
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = wardOf(f) {
            GlassSheet(tr("wd.moreT"), onClose: { app.sheet = nil }) {
                VStack(spacing: 8) {
                    ForEach(["trouser", "shoe", "lift"], id: \.self) { k in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                T(tr("wi." + k), ui(15, 700))
                                T(tr("wid." + k) + " · \(blockH(Insert(k))) mm", ui(12.5, 400, G.ink2))
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
