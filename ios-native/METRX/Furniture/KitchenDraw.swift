import SwiftUI
import Observation

/*
 * Furniture makers, Stage 1a part 4 (furniture plan section 7; design canvas screens 7–9; Android
 * ui/furniture/KitchenScreens.kt): the designer's state, and the drawing of one run seen from inside the room with its
 * lower and upper rows to scale. The rules are in Furniture/Core/Kitchen.swift; the screens in KitchenScreens.swift.
 */

/* ---------------- state shared by the designer and its sheets ---------------- */

/// The kitchen designer's undo history and selected unit, kept while the app runs.
@Observable
final class KitOps {
    static let shared = KitOps()
    var tick = 0
    var sel: String? = nil
    @ObservationIgnored private var back: [String: [Furniture]] = [:]
    @ObservationIgnored private var fwd: [String: [Furniture]] = [:]
    func canUndo(_ fid: String) -> Bool { !(back[fid] ?? []).isEmpty }
    func canRedo(_ fid: String) -> Bool { !(fwd[fid] ?? []).isEmpty }
    /// The piece changed outside the designer (placed, taken out, new sizes): its old versions no longer apply.
    func forget(_ fid: String) { back[fid] = nil; fwd[fid] = nil }

    /// Changes furniture fid of order pid and packs its rows again; the version before goes on the undo list.
    @discardableResult func change(_ pid: String, _ fid: String, _ f: (Furniture) -> Furniture) -> Furniture? {
        var old: Furniture? = nil, new: Furniture? = nil
        Store.shared.update(pid) { p in
            guard let i = p.furniture.firstIndex(where: { $0.id == fid }) else { return }
            old = p.furniture[i]
            let n = repack(f(p.furniture[i]), p, AppSettings.shared.angleSnap)
            p.furniture[i] = n; new = n
        }
        guard let o = old else { return nil }
        if o != new {
            var b = back[fid] ?? []; b.append(o); if b.count > 60 { b.removeFirst() }; back[fid] = b
            fwd[fid] = []
        }
        tick += 1
        return new
    }

    private func step(_ pid: String, _ fid: String, undo: Bool) {
        guard let prev = (undo ? back : fwd)[fid]?.last else { return }
        if undo { back[fid]?.removeLast() } else { fwd[fid]?.removeLast() }
        Store.shared.update(pid) { p in
            guard let i = p.furniture.firstIndex(where: { $0.id == fid }) else { return }
            if undo { fwd[fid, default: []].append(p.furniture[i]) } else { back[fid, default: []].append(p.furniture[i]) }
            p.furniture[i] = prev
        }
        if !prev.modules.contains(where: { $0.id == sel }) { sel = nil }
        tick += 1
    }
    func undo(_ pid: String, _ fid: String) { step(pid, fid, undo: true) }
    func redo(_ pid: String, _ fid: String) { step(pid, fid, undo: false) }
}

/// The piece's room: its measured one, or for furniture without a room the made-up room of its sizes (Core/Free.swift).
func roomOf(_ p: Project, _ f: Furniture) -> Room? { f.roomId == nil ? freeRoom(f) : p.rooms.first(where: { $0.id == f.roomId }) }

/// A wall's length for the kitchen: confirmed, else the reading or the drawing's estimate (the designer says so).
func wallLen(_ r: Room, _ snap: Bool, _ id: String) -> Int? {
    guard let w = Geo.walls(r, snap).first(where: { $0.id == id }) else { return nil }
    return w.len ?? wallFrame(r, w, r.openings.filter { $0.wall == w.id }).L
}

func measured(_ r: Room, _ snap: Bool, _ id: String) -> Bool { Geo.walls(r, snap).first { $0.id == id }?.len != nil }

func kRuns(_ f: Furniture, _ r: Room?, _ snap: Bool) -> [Run] { runsOf(f) { id in freeLen(f, id) ?? r.flatMap { wallLen($0, snap, id) } } }

/// Kitchens pack their rows again after a change; a wardrobe keeps its place on the wall.
func repack(_ f: Furniture, _ p: Project, _ snap: Bool) -> Furniture { f.kind != "kitchen" ? f : pack(f, kRuns(f, roomOf(p, f), snap)) }

/// Lines on a board follow the board, not the theme: dark on light boards, light on dark ones.
func lineOn(_ rgb: Int) -> Color {
    let r = Double((rgb >> 16) & 0xFF) / 255, g = Double((rgb >> 8) & 0xFF) / 255, b = Double(rgb & 0xFF) / 255
    func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) > 0.4 ? Color(argb: 0xFF3E4A61) : Color(argb: 0xFFD5DBE5)
}

func modName(_ m: Module) -> String { tr("kn." + kindOf(m)) + " \(m.w)" }

/// "720 × 560 · 2 eshik · Polkalar 1".
func modSub(_ m: Module) -> String {
    var out = ["\(m.h) × \(m.d)"]
    switch m.fronts.kind {
    case "door": out.append(tr(m.fronts.n >= 2 ? "km.f2" : "km.f1"))
    case "drawer": out.append(tr("km.fd") + " \(m.fronts.n)")
    default: break
    }
    let q = m.inserts.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty }
    if q > 0 { out.append(tr("km.shelves") + " \(q)") }
    return out.joined(separator: " · ")
}

/// A wall's chip: "Devor A · 3400", or the island; furniture without a room has sides ("1-tomon").
func runName(_ f: Furniture, _ r: Run, withLen: Bool = true) -> String {
    if r.wall == ISLAND { return tr(f.layout == "P" ? "kt.peninsula" : "kt.island") }
    let name = f.roomId == nil ? tr("fz.sideN", ["n": sideNo(f, f.walls.firstIndex(of: r.wall) ?? -1)]) : tr("kt.wallN", ["w": r.wall])
    return name + (withLen && r.len != nil ? " · \(r.len!)" : "")
}

/// Metres with one decimal ("3,4").
func metres1(_ mm: Int, _ en: Bool) -> String { let v = (mm + 50) / 100; return "\(v / 10)\(en ? "." : ",")\(v % 10)" }

// the running metres the price counts (runMm): no tall units, no fridge or empty gaps
func runMetres(_ f: Furniture, _ en: Bool) -> String { metres1(runMm(f), en) }

/* ---------------- the drawing: one run seen from inside the room ---------------- */

private var CORNER_FILL: Color { pc(0xFFE7E5E4, 0xFF2A3042) }
private var GAP_FILL: Color { pc(0xFFF1F5F9, 0xFF2B3346) }
private var GLASS_DARK: Color { pc(0xFF1E293B, 0xFF0B1220) }
private var OPEN_FILL: Color { pc(0xFFE2E6EC, 0xFF283044) }
private let DASH: [CGFloat] = [4, 3]

/// Where a run sits in a viewBox vw wide: L × H mm, with room for sizes under it when dims.
struct KLay {
    let L: Int, H: Int, vw: CGFloat, dims: Bool
    let padX: CGFloat, top: CGFloat, span: Int, s: CGFloat, x0: CGFloat, yF: CGFloat, vh: CGFloat
    init(_ L: Int, _ H: Int, _ vw: CGFloat, _ dims: Bool, _ ext: Int? = nil) {
        self.L = L; self.H = H; self.vw = vw; self.dims = dims
        padX = dims ? 18 : 6; top = dims ? 28 : 8
        // units past the wall's end still show (in red), so the drawing takes the longer of the two
        span = max(L, ext ?? L)
        s = min((vw - 2 * padX) / CGFloat(span), (dims ? 230 : 118) / CGFloat(H))
        x0 = padX + ((vw - 2 * padX) - CGFloat(span) * s) / 2
        yF = top + CGFloat(H) * s
        vh = yF + (dims ? 56 : 10)
    }
    func x(_ mm: Int) -> CGFloat { x0 + CGFloat(mm) * s }
    func y(_ mm: Int) -> CGFloat { yF - CGFloat(mm) * s }
}

/// Where the run's rows end, mm from its start.
func runExt(_ f: Furniture, _ r: Run) -> Int { max(fillOf(f, r, false).used + r.lowStart, fillOf(f, r, true).used + r.upStart) }

func runLen(_ f: Furniture, _ r: Run) -> Int { r.len ?? max(1200, runExt(f, r)) }

func roomH(_ room: Room?) -> Int { room.flatMap { $0.dim("H").v ?? $0.dim("H").pending?.mm } ?? 2700 }

private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(CGRect(x: x, y: y, width: w, height: h)) }

/// A wall seen from inside the room: its face, doors and windows.
func drawWallFace(_ c: GraphicsContext, _ lay: KLay, _ room: Room?, _ wall: String) {
    let x0 = lay.x0, x1 = lay.x(lay.L), yF = lay.yF, yT = lay.y(lay.H)
    c.fill(rect(x0, yT, x1 - x0, yF - yT), with: .color(PC.white))
    c.stroke(rect(x0, yT, x1 - x0, yF - yT), with: .color(PC.ink), lineWidth: 1.2)
    for o in room?.openings ?? [] where o.wall == wall {
        let l = lay.x(o.off), t = lay.y(o.sill + o.h), w = CGFloat(o.w) * lay.s, h = CGFloat(o.h) * lay.s
        c.fill(rect(l, t, w, h), with: .color(OPEN_FILL))
        c.stroke(rect(l, t, w, h), with: .color(PC.ink3), lineWidth: 1)
        if o.type == "window" { c.line(PC.ink3, CGPoint(x: l + w / 2, y: t), CGPoint(x: l + w / 2, y: lay.y(o.sill)), 0.8) }
    }
}

private func matRgb(_ mats: [Mat], _ id: String, _ fallback: String) -> Int { rgbOf(mats.first { $0.id == id }?.rgb ?? fallback) }

/// The run's units (lower row under the upper), the worktop, openings, site points, the selection and problems.
func drawRun(_ c: GraphicsContext, _ lay: KLay, _ f: Furniture, _ run: Run, _ room: Room?, _ ws: Workshop, _ mats: [Mat], _ sel: String?, _ bad: [String: String]) {
    let x0 = lay.x0, x1 = lay.x(lay.L), yF = lay.yF, yT = lay.y(lay.H)
    let island = run.wall == ISLAND
    if !island { drawWallFace(c, lay, room, run.wall) }
    c.line(PC.ink, CGPoint(x: x0 - 10, y: yF), CGPoint(x: x1 + 10, y: yF), 2)
    // the corner unit of the wall before reaches into this wall's start
    if run.lowStart > 0 {
        let t = lay.y(worktopTop(ws)), r = rect(x0, t, CGFloat(run.lowStart) * lay.s, yF - t)
        c.fill(r, with: .color(CORNER_FILL)); c.stroke(r, with: .color(PC.greyLine), style: StrokeStyle(lineWidth: 0.8, dash: DASH))
    }
    if run.upStart > 0 && !island {
        let t = lay.y(wallElev(ws) + K_WALL_H), r = rect(x0, t, CGFloat(run.upStart) * lay.s, CGFloat(K_WALL_H) * lay.s)
        c.fill(r, with: .color(CORNER_FILL)); c.stroke(r, with: .color(PC.greyLine), style: StrokeStyle(lineWidth: 0.8, dash: DASH))
    }
    let front = matRgb(mats, f.mats.front, "#CDBFAE"), carcass = matRgb(mats, f.mats.carcass, "#F5F5F2"), wt = matRgb(mats, "wt38", "#4B4F58")
    let mods = f.modules.enumerated().filter { $0.element.wall == run.wall }
        .sorted { (isUpper($0.element) ? 1 : 0, $0.offset) < (isUpper($1.element) ? 1 : 0, $1.offset) }.map(\.element)
    let g = max(0.8, CGFloat(ws.gap10) / 10 * lay.s)
    for m in mods { drawUnit(c, lay, m, ws, front, carcass, g) }
    // the worktop over the lower row, and over the corner zone it turns into
    var tops = mods.filter { !isUpper($0) && ($0.type == "base" || $0.type == "filler" || $0.app == "dishwasher") }.map { ($0.x, $0.x + $0.w) }
    if run.lowStart > 0 && !tops.isEmpty { tops.append((0, run.lowStart)) }
    let wtY = lay.y(worktopTop(ws))
    for (a, b) in tops { c.fill(rect(lay.x(a), wtY, CGFloat(b - a) * lay.s, max(1.5, CGFloat(K_TOP) * lay.s)), with: .color(Color(argb: 0xFF00_0000 | UInt32(wt)))) }
    // extras (plan 1b-1): the backsplash over the worktop, the cornice on the wall units, the LED strip under them
    if let kx = f.kx, !island {
        let sp = Color(argb: 0xFF00_0000 | UInt32(rgbOf(mats.first { $0.kind == "splash" }?.rgb ?? "#E8E2D8")))
        if kx.splash > 0 {
            for (a, b) in tops {
                let r = rect(lay.x(a), lay.y(worktopTop(ws) + kx.splash), CGFloat(b - a) * lay.s, CGFloat(kx.splash) * lay.s)
                c.fill(r, with: .color(sp)); c.stroke(r, with: .color(PC.greyLine), lineWidth: 0.6)
            }
        }
        for m in mods where m.type == "wall" {
            if kx.cornice { c.fill(rect(lay.x(m.x), lay.y(m.elev + m.h + 60), CGFloat(m.w) * lay.s, 60 * lay.s), with: .color(Color(argb: 0xFF00_0000 | UInt32(front)))) }
            if kx.led { c.line(Color(argb: 0xFFF2C94C), CGPoint(x: lay.x(m.x) + 1, y: lay.y(m.elev) + 1), CGPoint(x: lay.x(m.x + m.w) - 1, y: lay.y(m.elev) + 1), 1.6) }
        }
    }
    for m in mods { appliance(c, lay, m, ws) }
    if !island { for p in room?.points ?? [] where p.wall == run.wall { drawSitePoint(c, p, CGPoint(x: lay.x(p.off), y: lay.y(p.h)), lay.s, lay.dims ? 6 : 3) } }
    for m in mods {
        let l = lay.x(m.x), t = lay.y(m.elev + m.h), w = CGFloat(m.w) * lay.s, h = CGFloat(m.h) * lay.s
        switch bad[m.id] {
        case "err": c.stroke(rect(l - 2, t - 2, w + 4, h + 4), with: .color(PC.red), style: StrokeStyle(lineWidth: 1.6, dash: DASH))
        case "warn": c.stroke(rect(l - 2, t - 2, w + 4, h + 4), with: .color(PC.amber), style: StrokeStyle(lineWidth: 1.4, dash: DASH))
        default: break
        }
        if m.id == sel { c.stroke(rect(l - 2.5, t - 2.5, w + 5, h + 5), with: .color(PC.cob), lineWidth: 3) }
    }
    // past the wall's end: red
    let ext = runExt(f, run)
    if let len = run.len, ext > len {
        c.fill(rect(x1, yT, CGFloat(ext - len) * lay.s, yF - yT), with: .color(PC.red.opacity(0.14)))
        c.line(PC.red, CGPoint(x: x1, y: yT - 6), CGPoint(x: x1, y: yF + 6), 1.6, dash: DASH)
    }
    if lay.dims { dims(c, lay, f, run) }
}

func drawUnit(_ c: GraphicsContext, _ lay: KLay, _ m: Module, _ ws: Workshop, _ frontRgb: Int, _ carcassRgb: Int, _ g: CGFloat) {
    let l = lay.x(m.x), r = lay.x(m.x + m.w), t = lay.y(m.elev + m.h), b = lay.y(m.elev)
    let w = r - l, h = b - t
    let front = Color(argb: 0xFF00_0000 | UInt32(frontRgb)), carcass = Color(argb: 0xFF00_0000 | UInt32(carcassRgb))
    let onF = lineOn(frontRgb), onC = lineOn(carcassRgb)
    // legs: a plinth strip under base and tall units
    if m.legs && m.elev > 0 && m.type != "wall" { c.fill(rect(l + 2, b, w - 4, lay.yF - b), with: .color(PC.greyLine.opacity(0.35))) }
    func board(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat) {
        c.fill(rect(x, y, ww, hh), with: .color(front)); c.stroke(rect(x, y, ww, hh), with: .color(onF), lineWidth: 0.8)
    }
    switch m.type {
    case "gap":
        switch m.app {
        case "fridge":
            let rr = Path(roundedRect: CGRect(x: l + 1, y: t, width: w - 2, height: h), cornerRadius: 3)
            c.fill(rr, with: .color(GAP_FILL)); c.stroke(rr, with: .color(PC.ink3), lineWidth: 1)
            let split = lay.y(m.elev + Int(Double(m.h) * 0.64))
            c.line(PC.ink3, CGPoint(x: l + 1, y: split), CGPoint(x: r - 1, y: split), 0.9)
            c.line(PC.ink3, CGPoint(x: l + w * 0.14, y: t + h * 0.06), CGPoint(x: l + w * 0.14, y: t + h * 0.18), 1.6, round: true)
            c.line(PC.ink3, CGPoint(x: l + w * 0.14, y: split + h * 0.05), CGPoint(x: l + w * 0.14, y: split + h * 0.2), 1.6, round: true)
        case "dishwasher":
            board(l + g / 2, t + g / 2, w - g, h - g)
            if hasHandle(m, "f0") { c.line(onF, CGPoint(x: l + w * 0.3, y: t + h * 0.1), CGPoint(x: r - w * 0.3, y: t + h * 0.1), 1.4, round: true) }
            else { pushMark(c, CGPoint(x: (l + r) / 2, y: t + h * 0.1), onF, min(2.4, w * 0.08)) }
        default:
            c.stroke(rect(l + 1, t + 1, w - 2, h - 2), with: .color(PC.greyLine), style: StrokeStyle(lineWidth: 1, dash: DASH))
        }
    case "filler": board(l, t, w, h)
    default:
        c.fill(rect(l, t, w, h), with: .color(carcass))
        let n = frontSizes(m.fronts, m.w, m.h, ws).count
        if n == 0 {
            // open: the shelves show
            let q = m.inserts.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty }
            if q > 0 { for i in 1...q { let y = t + h * CGFloat(i) / CGFloat(q + 1); c.line(onC, CGPoint(x: l + 3, y: y), CGPoint(x: r - 3, y: y), 1) } }
            c.stroke(rect(l, t, w, h), with: .color(onC), lineWidth: 1)
        } else if m.fronts.kind == "door" {
            let fw = (w - g * CGFloat(n + 1)) / CGFloat(n)
            for i in 0..<n {
                let fl = l + g + CGFloat(i) * (fw + g)
                board(fl, t + g, fw, h - 2 * g)
                // the handle on the opening edge: right of a single door, the middle of a pair; without one the push mark
                let hx = n == 1 || i == 0 ? fl + fw - max(2.5, fw * 0.1) : fl + max(2.5, fw * 0.1)
                let hy = m.type == "wall" ? t + h * 0.82 : t + h * 0.14
                let len = min(10, h * 0.18)
                if hasHandle(m, "f\(i)") { c.line(onF, CGPoint(x: hx, y: hy - len / 2), CGPoint(x: hx, y: hy + len / 2), 1.4, round: true) }
                else { pushMark(c, CGPoint(x: hx, y: hy), onF, min(2.4, fw * 0.12)) }
            }
        } else {
            // drawers and appliance panels, one above the other
            let fh = (h - g * CGFloat(n + 1)) / CGFloat(n)
            for i in 0..<n {
                let ft = t + g + CGFloat(i) * (fh + g)
                board(l + g, ft, w - 2 * g, fh)
                if m.fronts.kind == "drawer" {
                    let len = min(14, w * 0.3), y = ft + min(5, fh * 0.22)
                    if hasHandle(m, "f\(i)") { c.line(onF, CGPoint(x: l + w / 2 - len / 2, y: y), CGPoint(x: l + w / 2 + len / 2, y: y), 1.4, round: true) }
                    else { pushMark(c, CGPoint(x: l + w / 2, y: y + 0.5), onF, min(2.4, fh * 0.2)) }
                }
            }
        }
    }
}

/// What shows the appliance: the tap over a sink, the hob's line, an oven's or a microwave's glass.
func appliance(_ c: GraphicsContext, _ lay: KLay, _ m: Module, _ ws: Workshop) {
    let l = lay.x(m.x), r = lay.x(m.x + m.w), cx = (l + r) / 2
    let wt = lay.y(worktopTop(ws))
    switch m.app {
    case "sink":
        let top = lay.y(worktopTop(ws) + 260)
        var p = Path()
        p.move(to: CGPoint(x: cx, y: wt)); p.addLine(to: CGPoint(x: cx, y: top))
        p.addQuadCurve(to: CGPoint(x: cx + 4, y: top - 4), control: CGPoint(x: cx, y: top - 4))
        p.addLine(to: CGPoint(x: cx + 130 * lay.s, y: top - 4)); p.addLine(to: CGPoint(x: cx + 130 * lay.s, y: top - 1))
        c.stroke(p, with: .color(PC.ink3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    case "hob":
        c.line(GLASS_DARK, CGPoint(x: l + (r - l) * 0.1, y: wt - 1.2), CGPoint(x: r - (r - l) * 0.1, y: wt - 1.2), 2.4)
    case "oven":
        let t = lay.y(m.elev + 1380), b = lay.y(m.elev + 800)
        c.fill(Path(roundedRect: CGRect(x: l + (r - l) * 0.12, y: t, width: (r - l) * 0.76, height: b - t), cornerRadius: 2), with: .color(GLASS_DARK.opacity(0.85)))
    case "micro":
        let t = lay.y(m.elev + m.h), h = CGFloat(m.h) * lay.s
        c.fill(Path(roundedRect: CGRect(x: l + (r - l) * 0.1, y: t + h * 0.18, width: (r - l) * 0.62, height: h * 0.64), cornerRadius: 2), with: .color(GLASS_DARK.opacity(0.85)))
    case "hood":
        let b = lay.y(m.elev)
        c.line(PC.ink3, CGPoint(x: l + (r - l) * 0.08, y: b + 1.5), CGPoint(x: r - (r - l) * 0.08, y: b + 1.5), 1.6)
    default: break
    }
}

/// The units' widths under the floor (and over the upper row), and the run's length.
private func dims(_ c: GraphicsContext, _ lay: KLay, _ f: Furniture, _ run: Run) {
    func chain(_ cuts: [Int], _ y: CGFloat, _ below: Bool) {
        guard cuts.count >= 2 else { return }
        c.line(PC.ink3, CGPoint(x: lay.x(cuts.first!), y: y), CGPoint(x: lay.x(cuts.last!), y: y), 0.8)
        for k in cuts { let x = lay.x(k); c.line(PC.ink3, CGPoint(x: x - 2.5, y: y + 2.5), CGPoint(x: x + 2.5, y: y - 2.5), 1.1) }
        for k in 0..<(cuts.count - 1) {
            let a = lay.x(cuts[k]), b = lay.x(cuts[k + 1]), t = "\(cuts[k + 1] - cuts[k])"
            let narrow = (b - a) < 6.5 * CGFloat(t.count)
            let dy: CGFloat = (narrow && k % 2 == 1 ? 19 : 9) * (below ? 1 : -1)
            c.text(t, CGPoint(x: (a + b) / 2, y: y + dy), .num, 10, 500, PC.ink3)
        }
    }
    func sortedUnique(_ xs: [Int]) -> [Int] { Array(Set(xs)).sorted() }
    let low = f.modules.filter { $0.wall == run.wall && !isUpper($0) }
    if !low.isEmpty {
        let cuts = sortedUnique([run.lowStart] + low.map { $0.x + $0.w })
        chain(run.lowStart > 0 ? [0] + cuts : cuts, lay.yF + 12, true)
    }
    let up = f.modules.filter { $0.wall == run.wall && isUpper($0) }
    if !up.isEmpty { chain(sortedUnique([run.upStart] + up.map { $0.x + $0.w }), lay.y(up.map { $0.elev + $0.h }.max()!) - 8, false) }
    // the whole length
    let y = lay.yF + 40, xa = lay.x0, xb = lay.x(lay.L)
    c.line(PC.ink, CGPoint(x: xa, y: y), CGPoint(x: xb, y: y), 1)
    for x in [xa, xb] { c.line(PC.ink, CGPoint(x: x - 4, y: y + 4), CGPoint(x: x + 4, y: y - 4), 1.5) }
    let t = "\(lay.L)", pw = 9 * CGFloat(t.count) + 16
    let pill = Path(roundedRect: CGRect(x: (xa + xb) / 2 - pw / 2, y: y - 10, width: pw, height: 20), cornerRadius: 10)
    c.fill(pill, with: .color(PC.white)); c.stroke(pill, with: .color(PC.ink3), lineWidth: 1)
    c.text(t, CGPoint(x: (xa + xb) / 2, y: y), .num, 12, 600, PC.ink)
}

/// A small picture of the first run (workspace cards).
struct KitchenThumb: View {
    let p: Project
    let f: Furniture
    var body: some View {
        let s = AppSettings.shared, room = roomOf(p, f), runs = kRuns(f, room, s.angleSnap)
        Canvas { ctx, size in
            guard let run = runs.first else { return }
            let lay = KLay(runLen(f, run), roomH(room), 200, false, runExt(f, run))
            let k = min(size.width / lay.vw, size.height / lay.vh)
            var c = ctx
            c.translateBy(x: (size.width - lay.vw * k) / 2, y: (size.height - lay.vh * k) / 2); c.scaleBy(x: k, y: k)
            drawRun(c, lay, f, run, room, wsOf(f, s.workshop), s.mats, nil, [:])
        }
    }
}
