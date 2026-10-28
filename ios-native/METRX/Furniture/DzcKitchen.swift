import SwiftUI
import UIKit

/*
 * Designer C for kitchens (founder-approved 27 Oct 2026; design/designer-c/mockup.html): the wall seen from inside the
 * room filling the screen, edited on the picture (a tap selects a unit, a second tap a front; its right edge dragged to
 * a snap width, a wall unit's bottom edge to a height; held 0.4 s it lifts and moves along its row, dropped on the red
 * zone it is deleted), the Canva-style tool slider under it changing with the selection, each tool's options in its
 * place, and Undo/Redo · 2D/3D · "Narxni ko‘rish" at the bottom. The rules are Furniture/Core/DzcRules.swift; the
 * shared parts DzcKit.swift.
 */

/// What the kitchen designer works with on one wall.
struct DzcKCtx {
    let p: Project
    let f: Furniture
    let room: Room
    let runs: [Run]
    let run: Run
    let ws: Workshop
    let mats: [Mat]
    let found: [FCheck]
    let bad: [String: String]
    let d3: Bool
    var sel: Module? { f.modules.first { $0.id == KitOps.shared.sel } }
    var scene: String { "k:" + f.id + ":" + run.wall + (d3 ? ":3d" : "") }
    func avail(_ m: Module) -> Int? { runs.first { $0.wall == m.wall }.flatMap { fillOf(f, $0, isUpper(m)).avail } }
    func availRow(_ wall: String, _ upper: Bool) -> Int? { runs.first { $0.wall == wall }.flatMap { fillOf(f, $0, upper).avail } }
    func start(_ upper: Bool) -> Int { upper ? run.upStart : run.lowStart }
    /// The problems worth a badge and a callout (errors and warnings).
    var issues: [FCheck] { found.filter { $0.level == "err" || $0.level == "warn" } }
}

/// The drawing as it would be: a gesture's or a dragged tile's preview, the tile's new unit, where a tile cannot go.
struct DzcShown {
    var f: Furniture
    var newId: String? = nil
    var failX: Int? = nil
    var failWhy = ""
    var failVars: [String: Int] = [:]
    /// The dragged tile goes into an empty space (else between two units).
    var intoSpace = false
}

/* ---------------- the pane ---------------- */

/// The kitchen designer under its head: the walls, the drawing (or the 3D), the slider or a tool's options, the bar.
struct DzcKitchen: View {
    let app: AppModel
    let c: DzcKCtx
    var body: some View {
        let st = DzcState.shared, kit = KitOps.shared
        let pid = c.p.id, fid = c.f.id, wall = c.run.wall
        VStack(spacing: 0) {
            DzcWallBar(app: app, c: c)
            ZStack(alignment: .top) {
                if c.d3 {
                    Furniture3DPane(app: app, p: c.p, room: c.room, onPick: { keys in DzcKOps.pick3D(c, keys) }, hiKeys: DzcKOps.hiKeys3D(c))
                } else {
                    DzcKitchenCanvas(app: app, c: c)
                    if !c.f.modules.contains(where: { $0.wall == c.run.wall }) && c.run.wall != ISLAND { DzcEmptyWall(app: app, c: c) }
                }
                DzcKCaption(app: app, c: c).padding(.top, 6)
                if st.teachOn { DzcTeach { st.teachOn = false } }
            }
            .frame(maxHeight: .infinity)
            DzcKBottom(app: app, c: c)
            DesignerBar(app: app, p: c.p, f: c.f) {
                DzcMiddle(canRedo: kit.canRedo(fid), d3: c.d3, onRedo: { kit.redo(pid, fid); Haptic.tick() }) { v in
                    Haptic.tick()
                    let w = c.sel?.wall ?? wall
                    app.setTop(.kitchen(pid: pid, fid: fid, wall: w, d3: v))
                }
            }
        }
    }
}

/// The walls' chips (a red dot on one with a problem) and "?" for the gesture hint.
private struct DzcWallBar: View {
    let app: AppModel
    let c: DzcKCtx
    var body: some View {
        let pid = c.p.id, fid = c.f.id, d3 = c.d3
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(c.runs, id: \.wall) { r in
                        let on = r.wall == c.run.wall
                        let bad = c.issues.contains { ck in c.f.modules.first { $0.id == ck.mid }?.wall == r.wall }
                        HStack(spacing: 5) {
                            T(runName(c.f, r), ui(13.5, 700, on ? G.solid : G.ink), lines: 1)
                            if bad { Circle().fill(G.err).frame(width: 7, height: 7) }
                        }
                        .padding(.horizontal, 14).frame(minHeight: 38)
                        .background(Capsule().fill(on ? G.ink : G.glass(0.6)))
                        .overlay(Capsule().strokeBorder(on ? G.ink : G.rim, lineWidth: 1))
                        .pressable(0.97) {
                            if on { return }
                            KitOps.shared.sel = nil; DzcState.shared.front = nil
                            if DzcState.shared.tool != "add" { DzcState.shared.tool = nil }
                            app.setTop(.kitchen(pid: pid, fid: fid, wall: r.wall, d3: d3))
                        }
                        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("kt.wall." + r.wall)
                    }
                }
                .padding(.leading, 12)
            }
            T("?", ui(17, 800, G.cobalt2), align: .center)
                .frame(width: 40, height: 40)
                .background(Circle().fill(G.cobalt.opacity(0.1)))
                .pressable(0.95, label: tr("dzc.help")) { DzcState.shared.startTeach() }
                .accessibilityIdentifier("dzc.help")
                .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
    }
}

/// An empty wall: fill it in one go, as before.
private struct DzcEmptyWall: View {
    let app: AppModel
    let c: DzcKCtx
    var body: some View {
        let s = AppSettings.shared, snap = s.angleSnap, room = c.room, wall = c.run.wall, ws = c.ws
        let f = c.f, pid = c.p.id
        VStack(alignment: .leading, spacing: 10) {
            T(tr("kt.emptyT", ["w": wall]), ui(16, 800))
            T(tr("kt.emptyB"), ui(13.5, 400, G.ink2, lh: 1.45))
            GBtn(tr("kt.auto"), icon: "plus") {
                let before = f.modules.count
                let n = KitOps.shared.change(pid, f.id) { x in autoFill(x, kRuns(x, room, snap).filter { x.modules.isEmpty || $0.wall == wall }, ws, room.openings, room.points) }
                app.say("kt.autoDone", ["n": (n?.modules.count ?? before) - before])
            }
            .accessibilityIdentifier("kt.auto")
        }
        .padding(16)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.85))
        .padding(.horizontal, 16).padding(.top, 70)
    }
}

/// The caption over the drawing.
private struct DzcKCaption: View {
    let app: AppModel
    let c: DzcKCtx
    var body: some View {
        let st = DzcState.shared, kit = KitOps.shared
        let d3 = c.d3 ? " · 3D" : ""
        if st.multi {
            let n = st.ticks.count
            DzcCaption(title: n > 0 ? tr("dzc.marked", ["n": n]) : tr("dzc.t.multi"), sub: tr("dzc.markHint") + d3, dark: true, onUp: {}) {
                st.multi = false; st.ticks = []; st.tool = nil
            }
        } else if let m = c.sel, st.live?.kind != "move" {
            if let fk = st.front, let fr = handleFronts(m).first(where: { $0.key == fk }) {
                DzcCaption(title: frontName(m, fr), sub: d3.isEmpty ? "" : "3D", up: modName(m), onUp: { st.front = nil; st.tool = nil }) { DzcKOps.deselect() }
            } else {
                let row = tr(isUpper(m) ? "dzc.rowUp" : "dzc.rowLow")
                let wall = m.wall == ISLAND ? runName(c.f, c.run) : tr("kt.wallN", ["w": m.wall ?? ""])
                DzcCaption(title: modName(m) + " mm", sub: wall + " · " + row + d3, onUp: {}) { DzcKOps.deselect() }
            }
        } else if c.run.wall != ISLAND && !measured(c.room, AppSettings.shared.angleSnap, c.run.wall) && !c.d3 {
            T(tr("kt.noLen", ["w": c.run.wall]), ui(12, 600, G.amberInk, lh: 1.3), lines: 2)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.amberWash))
                .padding(.horizontal, 16)
                .allowsHitTesting(false)
        }
    }
}

/* ---------------- the drawing ---------------- */

struct DzcKitchenCanvas: View {
    let app: AppModel
    let c: DzcKCtx
    var body: some View {
        let st = DzcState.shared
        let shown = DzcKOps.shown(c)
        let lay = KLay(runLen(shown.f, c.run), roomH(c.room), 360, true, runExt(shown.f, c.run))
        GeometryReader { geo in
            let cam = st.cams[c.scene] ?? DzcCam()
            let map = DzcMap(lay, geo.size, cam, top: 58, bottom: 6)
            let _ = DzcKOps.note(map, c.scene)
            ZStack(alignment: .topLeading) {
                // while a unit is lifted the others slide aside, frame by frame
                TimelineView(.animation(minimumInterval: nil, paused: st.live?.kind != "move")) { _ in
                    Canvas { ctx, _ in DzcKDraw.all(ctx, map, c, shown) }
                }
                .allowsHitTesting(false)
                DzcTouch(act: DzcKOps.actions(app, c, map))
                DzcKA11y(c: c, f: shown.f, map: map)
                DzcKBubbles(app: app, c: c, f: shown.f, map: map, size: geo.size)
                DzcKCallouts(app: app, c: c, map: map, size: geo.size)
                DzcKTileGhost(sh: shown)
                if !cam.fit {
                    DzcZoomPill(pct: Int((cam.z * 100).rounded())) { st.cams[c.scene] = DzcCam(); Haptic.tick() }
                        .position(x: geo.size.width / 2, y: geo.size.height - 24)
                }
            }
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { DzcState.shared.canvasFrame = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { _, r in DzcState.shared.canvasFrame = r }
        })
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dzc.canvas")
    }
}

/// Each unit of the wall as an element for VoiceOver and the screen tests ("dzc.m.low0", "dzc.m.up2"); the touches
/// pass through to the drawing.
private struct DzcKA11y: View {
    let c: DzcKCtx
    let f: Furniture
    let map: DzcMap
    var body: some View {
        let low = dzcRowMods(f, DzcRow(wall: c.run.wall, upper: false)), up = dzcRowMods(f, DzcRow(wall: c.run.wall, upper: true))
        let items: [(String, Module)] = low.enumerated().map { ("low\($0.offset)", $0.element) } + up.enumerated().map { ("up\($0.offset)", $0.element) }
        ForEach(items, id: \.0) { key, m in
            let l = map.sx(m.x), r = map.sx(m.x + m.w)
            let t = map.sy(m.elev + m.h), b = map.sy(isUpper(m) ? m.elev : 0)
            Rectangle().fill(Color.black.opacity(0.001))
                .frame(width: max(4, r - l), height: max(4, b - t))
                .position(x: (l + r) / 2, y: (t + b) / 2)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel(modName(m))
                .accessibilityAddTraits(KitOps.shared.sel == m.id ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("dzc.m." + key)
        }
    }
}

/// The selected unit's mm bubble (tap: type the width), a wall unit's height bubble, and while a width is dragged
/// the amber line of whoever takes the difference.
private struct DzcKBubbles: View {
    let app: AppModel
    let c: DzcKCtx
    let f: Furniture
    let map: DzcMap
    let size: CGSize
    var body: some View {
        let st = DzcState.shared
        if let m = f.modules.first(where: { $0.id == KitOps.shared.sel && $0.wall == c.run.wall }), !st.multi, st.front == nil, st.live?.kind != "move", !dzcSpace(m) {
            let lv = st.live
            let live = lv?.kind == "resize" && lv?.mid == m.id
            // kept inside the drawing however near its edge the unit is (DzcPin)
            let bx = map.sx(m.x + m.w / 2)
            let by = isUpper(m) ? map.sy(m.elev + m.h) - 20 : map.sy(-150)
            let label = (live && lv?.maxHit == true ? tr("dzc.max") + " " : "") + "\(m.w) mm"
            let pid = c.p.id, fid = c.f.id, mid = m.id
            DzcPin(x: bx, y: by) {
                DzcBubble(text: label, live: live, kbd: !live, warn: live && lv?.maxHit == true, id: "dzc.bubble") {
                    app.sheet = .dzcNum(pid: pid, fid: fid, mid: mid, key: "w", sec: -1)
                }
            }
            if m.type == "wall" && m.app != "hood" {
                let hl = lv?.kind == "height" && lv?.mid == m.id
                DzcPin(x: bx, y: map.sy(m.elev) + 26) {
                    DzcBubble(text: "h \(m.h)", live: hl, kbd: false, small: true, id: "dzc.bubbleH") {
                        app.sheet = .dzcNum(pid: pid, fid: fid, mid: mid, key: "h", sec: -1)
                    }
                }
            }
            if live, let t = lv?.taker, let tm = f.modules.first(where: { $0.id == t }) {
                DzcPin(x: map.sx(tm.x + tm.w / 2), y: isUpper(tm) ? map.sy(tm.elev + tm.h / 2) : map.sy(450)) {
                    DzcAmberLabel(text: tr("kn." + kindOf(tm)) + " \(lv?.tw0 ?? 0) → \(max(0, lv?.tw1 ?? 0))", left: lv?.tleft == true)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// A tile dragged over the wall: under the finger, its name and where it would go (green), or why not (red).
private struct DzcKTileGhost: View {
    let sh: DzcShown
    var body: some View {
        let st = DzcState.shared
        if let td = st.tile {
            let fr = st.canvasFrame
            if fr.contains(td.pt) {
                let ok = sh.failX == nil && sh.newId != nil
                let why = sh.failX != nil ? tr(sh.failWhy, sh.failVars) : tr(sh.intoSpace ? "dzc.toSpace" : "dzc.toBetween")
                VStack(alignment: .leading, spacing: 1) {
                    T(dzcTileName(td.tile) + " \(td.tile.w)", ui(13, 800, .white), lines: 1)
                    T(why, ui(11.5, 600, .white.opacity(0.92), lh: 1.25), lines: 3)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: 220, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ok ? PC.okGreen : sh.failX != nil ? PC.red : G.ink))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                .position(x: min(fr.width - 110, max(110, td.pt.x - fr.minX)), y: max(30, td.pt.y - fr.minY - 54))
                .allowsHitTesting(false)
            }
        }
    }
}

/// The mm bubble: live while dragged, the keyboard mark when it can be tapped.
struct DzcBubble: View {
    let text: String
    var live = false
    var kbd = true
    var warn = false
    var small = false
    var id = ""
    let action: () -> Void
    var body: some View {
        let bg: Color = warn ? G.err : live ? G.cobalt : G.sheet(0.95)
        let fg: Color = live || warn ? .white : G.ink
        HStack(spacing: 5) {
            T(text, num(small ? 12 : 13.5, 800, fg), lines: 1)
            if kbd { DzcIcon(d: DZC_ICON["kbd"]!, color: fg.opacity(0.7), size: 15) }
        }
        .padding(.horizontal, small ? 9 : 11).frame(minHeight: small ? 30 : 36)
        .background(Capsule().fill(bg))
        .overlay(Capsule().strokeBorder(live ? .clear : G.cobalt.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .pressable(0.96, action)
        .accessibilityIdentifier(id)
    }
}

/// The checks on the drawing: a callout with "Tuzatish" by the unit (one or two at a time), else a small "!".
private struct DzcKCallouts: View {
    let app: AppModel
    let c: DzcKCtx
    let map: DzcMap
    let size: CGSize
    var body: some View {
        let st = DzcState.shared
        let here = c.issues.filter { ck in ck.mid != nil && c.f.modules.first { $0.id == ck.mid }?.wall == c.run.wall }
        let sel = KitOps.shared.sel
        let open = st.live == nil && !st.callMin && st.tool == nil && !st.multi
        let two = Array(here.filter { open && (sel == nil || sel == $0.mid) }.prefix(2))
        // two callouts only when they do not cover each other (the second was 8 pt under the first); else the first,
        // the other stays a "!"
        let full = two.count == 2 && !dzcApart(two, c, map, size) ? [two[0]] : two
        if st.live == nil && !c.d3 {
            ForEach(Array(here.enumerated()), id: \.offset) { i, ck in
                if let m = c.f.modules.first(where: { $0.id == ck.mid }) {
                    if full.contains(where: { $0.key == ck.key && $0.mid == ck.mid }) {
                        DzcCallout(app: app, c: c, ck: ck, m: m)
                            .frame(width: min(250, size.width - 24))
                            .position(x: min(size.width - 130, max(130, map.sx(m.x + m.w / 2))), y: dzcCalloutY(m, map, size, i))
                    } else {
                        T("!", ui(13, 900, .white), align: .center).frame(width: 24, height: 24)
                            .background(Circle().fill(ck.level == "err" ? G.err : G.amberInk))
                            .pressable(0.95, label: checkText(ck, c.f)) { st.callMin = false; st.tool = nil; st.multi = false; KitOps.shared.sel = m.id }
                            .position(x: map.sx(m.x + m.w) - 10, y: map.sy(m.elev + m.h) + 12)
                            .accessibilityIdentifier("dzc.badge")
                    }
                }
            }
        }
    }
}

/// Whether the two checks' callouts (250 wide, about 100 high) stand clear of each other.
private func dzcApart(_ two: [FCheck], _ c: DzcKCtx, _ map: DzcMap, _ size: CGSize) -> Bool {
    let ms = two.compactMap { ck in c.f.modules.first { $0.id == ck.mid } }
    guard ms.count == 2 else { return true }
    let x = ms.map { min(size.width - 130, max(130, map.sx($0.x + $0.w / 2))) }
    let y = ms.enumerated().map { dzcCalloutY($0.element, map, size, $0.offset) }
    return abs(x[0] - x[1]) > min(250, size.width - 24) + 8 || abs(y[0] - y[1]) > 110
}

private func dzcCalloutY(_ m: Module, _ map: DzcMap, _ size: CGSize, _ i: Int) -> CGFloat {
    let y = isUpper(m) ? map.sy(m.elev) + 52 : map.sy(m.elev + m.h) - 52
    return min(size.height - 50, max(60, y + CGFloat(i) * 8))
}

private struct DzcCallout: View {
    let app: AppModel
    let c: DzcKCtx
    let ck: FCheck
    let m: Module
    var body: some View {
        let fix = dzcFix(c.f, ck, c.runs, c.room.openings, ws: c.ws)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let tone: Color = ck.level == "err" ? G.err : G.amberInk
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                DzcIcon(d: DZC_ICON["checks"]!, color: tone, size: 16)
                T(checkText(ck, c.f), ui(12.5, 700, tone, lh: 1.3), lines: 3)
            }
            HStack(spacing: 6) {
                if fix != nil {
                    T(tr("dzc.fix"), ui(13, 800, .white), lines: 1)
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background(Capsule().fill(tone))
                        .pressable(0.97) { DzcKOps.fix(app, c, ck) }
                        .accessibilityIdentifier("dzc.fix")
                }
                Spacer(minLength: 0)
                DzcIcon(d: DZC_ICON["x"]!, color: G.ink2, size: 14)
                    .frame(width: 36, height: 36)
                    .pressable(0.95, label: tr("dzc.smaller")) { DzcState.shared.callMin = true }
            }
        }
        .padding(10)
        .background(shape.fill(ck.level == "err" ? G.errWash : G.amberWash))
        .overlay(shape.strokeBorder(tone.opacity(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
    }
}

/* ---------------- drawing ---------------- */

enum DzcKDraw {
    static func rgb(_ mats: [Mat], _ id: String, _ fallback: String) -> Int { rgbOf(mats.first { $0.id == id }?.rgb ?? fallback) }

    static func all(_ ctx: GraphicsContext, _ map: DzcMap, _ c: DzcKCtx, _ sh: DzcShown) {
        let st = DzcState.shared
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy); g.scaleBy(x: map.k, y: map.k)
        var f = sh.f
        var ghost: Module? = nil
        slide(&f, c)
        if let lv = st.live, lv.kind == "move", let i = f.modules.firstIndex(where: { $0.id == lv.mid }) {
            ghost = f.modules[i]
            var slot = f.modules[i]
            slot.type = "gap"; slot.app = "slot"; slot.fronts = Fronts("open", 0)
            f.modules[i] = slot
        }
        drawRun(g, map.lay, f, c.run, c.room, c.ws, c.mats, nil, c.bad, open: DzcKOps.openSet(c))
        spaces(ctx, map, f, c)
        taker(ctx, map, f, c)
        selection(ctx, map, f, c)
        if st.multi { ticks(ctx, map, f, c) }
        if let ghost, let lv = st.live { lifted(g, ctx, map, c, ghost, lv) }
        if let id = sh.newId, let m = f.modules.first(where: { $0.id == id }) {
            let r = CGRect(x: map.sx(m.x), y: map.sy(m.elev + m.h), width: CGFloat(m.w) * map.pxPerMm, height: CGFloat(m.h) * map.pxPerMm)
            ctx.fill(Path(r), with: .color(PC.okGreen.opacity(0.18)))
            ctx.stroke(Path(r), with: .color(PC.okGreen), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
        if let x = sh.failX {
            ctx.line(PC.red, CGPoint(x: map.sx(x), y: map.sy(2300)), CGPoint(x: map.sx(x), y: map.sy(0)), 3, dash: [6, 4])
        }
    }

    /// A lifted unit's row: each unit drawn a third of the way nearer its new place each frame.
    static func slide(_ f: inout Furniture, _ c: DzcKCtx) {
        let st = DzcState.shared
        guard st.live?.kind == "move" else {
            if !st.disp.isEmpty { st.disp = [:] }
            return
        }
        for i in f.modules.indices where f.modules[i].wall == c.run.wall {
            let id = f.modules[i].id, t = CGFloat(f.modules[i].x)
            let d0 = st.disp[id] ?? t
            let d1 = abs(t - d0) < 2 ? t : d0 + (t - d0) * 0.3
            st.disp[id] = d1
            f.modules[i].x = Int(d1.rounded())
        }
    }

    /// The empty spaces' "+".
    static func spaces(_ ctx: GraphicsContext, _ map: DzcMap, _ f: Furniture, _ c: DzcKCtx) {
        let sel = KitOps.shared.sel
        for m in f.modules where m.wall == c.run.wall && dzcSpace(m) {
            let w = CGFloat(m.w) * map.pxPerMm
            if w < 26 { continue }
            let cx = map.sx(m.x) + w / 2, cy = map.sy(m.elev + m.h / 2)
            let on = sel == m.id
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 12, y: cy - 12, width: 24, height: 24)), with: .color(on ? PC.cob : PC.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - 12, y: cy - 12, width: 24, height: 24)), with: .color(PC.cob), lineWidth: 1.6)
            ctx.line(on ? PC.white : PC.cob, CGPoint(x: cx - 5, y: cy), CGPoint(x: cx + 5, y: cy), 2, round: true)
            ctx.line(on ? PC.white : PC.cob, CGPoint(x: cx, y: cy - 5), CGPoint(x: cx, y: cy + 5), 2, round: true)
            if w > 44 { ctx.text("\(m.w)", CGPoint(x: cx, y: cy + 22), .num, 11, 600, PC.ink3) }
        }
    }

    /// Whoever takes a dragged width's difference: amber.
    static func taker(_ ctx: GraphicsContext, _ map: DzcMap, _ f: Furniture, _ c: DzcKCtx) {
        guard let lv = DzcState.shared.live, lv.kind == "resize", let t = lv.taker, let m = f.modules.first(where: { $0.id == t }) else { return }
        let r = CGRect(x: map.sx(m.x), y: map.sy(m.elev + m.h), width: CGFloat(m.w) * map.pxPerMm, height: CGFloat(m.h) * map.pxPerMm)
        ctx.fill(Path(r), with: .color(PC.amber.opacity(0.18)))
        ctx.stroke(Path(r), with: .color(PC.amber), lineWidth: 2)
    }

    static func selection(_ ctx: GraphicsContext, _ map: DzcMap, _ f: Furniture, _ c: DzcKCtx) {
        let st = DzcState.shared
        guard !st.multi, st.live?.kind != "move", let m = f.modules.first(where: { $0.id == KitOps.shared.sel && $0.wall == c.run.wall }) else { return }
        let l = map.sx(m.x), r = map.sx(m.x + m.w), t = map.sy(m.elev + m.h), b = map.sy(m.elev)
        let box = CGRect(x: l - 2, y: t - 2, width: r - l + 4, height: b - t + 4)
        ctx.stroke(Path(box), with: .color(PC.cob), style: StrokeStyle(lineWidth: 2.6, dash: st.front == nil ? [] : [5, 4]))
        if let fk = st.front, let fb = unitFrontBoxes(m, c.ws).first(where: { $0.f.key == fk }) {
            let fr = CGRect(x: map.sx(m.x + fb.x0), y: map.sy(m.elev + fb.y1), width: CGFloat(fb.x1 - fb.x0) * map.pxPerMm, height: CGFloat(fb.y1 - fb.y0) * map.pxPerMm)
            ctx.fill(Path(fr), with: .color(PC.cob.opacity(0.16)))
            ctx.stroke(Path(fr), with: .color(PC.cob), lineWidth: 2.4)
            return
        }
        // the wall unit's guides: the lower units' edges near it
        if isUpper(m) {
            for u in f.modules where u.wall == m.wall && !isUpper(u) && !dzcSpace(u) {
                for e in [u.x, u.x + u.w] where e >= m.x - 60 && e <= m.x + m.w + 60 {
                    let ok = e == m.x || e == m.x + m.w
                    ctx.line(ok ? PC.okGreen : PC.cob.opacity(0.5), CGPoint(x: map.sx(e), y: map.sy(u.elev + u.h)), CGPoint(x: map.sx(e), y: b), 1, dash: [3, 3])
                }
            }
        }
        if let lv = st.live, lv.kind == "resize", lv.mid == m.id {
            for v in lv.cands {
                let x = map.sx(m.x + v), on = v == m.w
                ctx.line(on ? PC.cob : PC.ink3, CGPoint(x: x, y: map.sy(0) + 3), CGPoint(x: x, y: map.sy(0) + (on ? 14 : 9)), on ? 2 : 1.2)
            }
        }
        if DzcKOps.resizable(m) {
            let hy = (t + b) / 2
            handle(ctx, CGRect(x: r - 7, y: hy - 22, width: 14, height: 44), vertical: true)
        }
        if m.type == "wall" && m.app != "hood" {
            handle(ctx, CGRect(x: (l + r) / 2 - 22, y: b - 7, width: 44, height: 14), vertical: false)
        }
    }

    static func handle(_ ctx: GraphicsContext, _ r: CGRect, vertical: Bool) {
        let p = Path(roundedRect: r, cornerRadius: 7)
        ctx.fill(p, with: .color(PC.cob))
        ctx.stroke(p, with: .color(PC.white), lineWidth: 1.5)
        let cx = r.midX, cy = r.midY
        if vertical {
            for dx: CGFloat in [-2, 2] { ctx.line(PC.white, CGPoint(x: cx + dx, y: cy - 8), CGPoint(x: cx + dx, y: cy + 8), 1.4, round: true) }
        } else {
            for dy: CGFloat in [-2, 2] { ctx.line(PC.white, CGPoint(x: cx - 8, y: cy + dy), CGPoint(x: cx + 8, y: cy + dy), 1.4, round: true) }
        }
    }

    /// Belgilash: a tick circle on each unit, filled on the marked ones.
    static func ticks(_ ctx: GraphicsContext, _ map: DzcMap, _ f: Furniture, _ c: DzcKCtx) {
        let st = DzcState.shared
        for m in f.modules where m.wall == c.run.wall && !dzcSpace(m) {
            let on = st.ticks.contains(m.id)
            let l = map.sx(m.x), t = map.sy(m.elev + m.h)
            if on {
                let r = CGRect(x: l, y: t, width: CGFloat(m.w) * map.pxPerMm, height: CGFloat(m.h) * map.pxPerMm)
                ctx.fill(Path(r), with: .color(PC.cob.opacity(0.14)))
                ctx.stroke(Path(r), with: .color(PC.cob), lineWidth: 2)
            }
            let cx = l + min(12, CGFloat(m.w) * map.pxPerMm / 2), cy = t + 12
            let disc = Path(ellipseIn: CGRect(x: cx - 9, y: cy - 9, width: 18, height: 18))
            ctx.fill(disc, with: .color(on ? PC.cob : PC.white))
            ctx.stroke(disc, with: .color(PC.cob), lineWidth: 1.6)
            if on {
                var p = Path(); p.move(to: CGPoint(x: cx - 4, y: cy)); p.addLine(to: CGPoint(x: cx - 1, y: cy + 3)); p.addLine(to: CGPoint(x: cx + 4.5, y: cy - 3.5))
                ctx.stroke(p, with: .color(PC.white), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// The lifted unit under the finger: its shadow, the unit raised, outlined blue (red over the delete zone).
    static func lifted(_ g: GraphicsContext, _ ctx: GraphicsContext, _ map: DzcMap, _ c: DzcKCtx, _ m0: Module, _ lv: DzcLive) {
        var m = m0
        m.x = lv.gx
        let sh = CGRect(x: map.sx(m.x) + 6, y: map.sy(m.elev + m.h) + 8, width: CGFloat(m.w) * map.pxPerMm, height: CGFloat(m.h) * map.pxPerMm)
        ctx.fill(Path(roundedRect: sh, cornerRadius: 4), with: .color(Color.black.opacity(0.16)))
        m.elev += 60
        let front = rgb(c.mats, frontOf(c.f, m0), "#CDBFAE"), carcass = rgb(c.mats, c.f.mats.carcass, "#F5F5F2")
        let gap = max(0.8, CGFloat(c.ws.gap10) / 10 * map.lay.s)
        drawUnit(g, map.lay, m, c.ws, front, carcass, gap)
        let r = CGRect(x: map.sx(m.x), y: map.sy(m.elev + m.h), width: CGFloat(m.w) * map.pxPerMm, height: CGFloat(m.h) * map.pxPerMm)
        ctx.stroke(Path(r), with: .color(lv.overDel ? PC.red : PC.cob), lineWidth: 3)
    }
}

/* ---------------- what the touches and tools do ---------------- */

enum DzcKOps {
    static func note(_ map: DzcMap, _ scene: String) -> Bool {
        DzcState.shared.map = map
        DzcState.shared.mapScene = scene
        return true
    }

    /// The units drawn open: all of them ("Ichini ko‘rish"), the selected one ("Ichki"), the marked ones.
    static func openSet(_ c: DzcKCtx) -> Set<String> {
        let st = DzcState.shared
        if st.inside { return Set(c.f.modules.map(\.id)) }
        if st.multi && st.tool == "in" { return st.ticks }
        if st.peek, let id = KitOps.shared.sel { return [id] }
        return []
    }

    static func resizable(_ m: Module) -> Bool { !dzcSpace(m) && m.type != "filler" }

    static func movable(_ m: Module) -> Bool { !dzcSpace(m) && !dzcPinned(m) }

    /// The drawing as it would be: a gesture's preview, a tile dragged over the wall.
    static func shown(_ c: DzcKCtx) -> DzcShown {
        let st = DzcState.shared
        if let pv = st.live?.preview { return DzcShown(f: pv) }
        guard let td = st.tile, !c.d3, let map = st.map, st.mapScene == c.scene else { return DzcShown(f: c.f) }
        let fr = st.canvasFrame
        guard fr.contains(td.pt), td.pt.y < fr.maxY - 10 else { return DzcShown(f: c.f) }
        if td.tile.upper && c.run.wall == ISLAND { return DzcShown(f: c.f, failX: map.mmX(td.pt.x - fr.minX), failWhy: "dzc.noUp") }
        let u = map.mmX(td.pt.x - fr.minX)
        let key = DzcRow(wall: c.run.wall, upper: td.tile.upper)
        let plan = dzcPlanAt(dzcRowMods(c.f, key), td.tile, u: u, start: c.start(td.tile.upper), avail: c.availRow(c.run.wall, td.tile.upper), ws: c.ws, wall: c.run.wall)
        if !plan.ok { return DzcShown(f: c.f, failX: u, failWhy: plan.why, failVars: plan.vars) }
        return DzcShown(f: pack(dzcWithRow(c.f, key, plan.row), c.runs), newId: plan.id, intoSpace: plan.space != nil)
    }

    /// The unit under point pt: the upper row first (it hangs over tall units), then the lower row with its legs and sizes.
    static func hit(_ c: DzcKCtx, _ map: DzcMap, _ pt: CGPoint) -> Module? {
        let u = map.mmX(pt.x), z = map.mmY(pt.y)
        let mods = c.f.modules.filter { $0.wall == c.run.wall }
        if let m = mods.first(where: { isUpper($0) && u >= $0.x && u <= $0.x + $0.w && z >= $0.elev - 30 && z <= $0.elev + $0.h + 80 }) { return m }
        return mods.first { !isUpper($0) && u >= $0.x && u <= $0.x + $0.w && z >= -280 && z <= $0.elev + $0.h + 40 }
    }

    /// The front of m under point pt.
    static func hitFront(_ c: DzcKCtx, _ map: DzcMap, _ m: Module, _ pt: CGPoint) -> String? {
        let u = map.mmX(pt.x) - m.x, z = map.mmY(pt.y) - m.elev
        let b = unitFrontBoxes(m, c.ws).first(where: { u >= $0.x0 - 4 && u <= $0.x1 + 4 && z >= $0.y0 - 4 && z <= $0.y1 + 4 })
        return b?.f.key
    }

    static func deselect() {
        let st = DzcState.shared
        KitOps.shared.sel = nil
        st.front = nil; st.peek = false; st.scope = "one"
        if let t = st.tool, !["add", "style", "decor", "handle", "checks", "plinth"].contains(t) { st.tool = nil }
    }

    /// m selected: its front none, the scope back to "Faqat shu", a tool that does not suit it closed; the hint the
    /// first time.
    static func select(_ c: DzcKCtx, _ m: Module) {
        let st = DzcState.shared
        KitOps.shared.sel = m.id
        st.front = nil; st.scope = "one"
        st.peek = st.tool == "in"
        let ids = tools(c, m).map(\.id)
        if let t = st.tool, !ids.contains(t), !(t == "add" && dzcSpace(m)) { st.tool = nil; st.peek = false }
        if !st.taught && !dzcSpace(m) { st.startTeach() }
    }

    static func actions(_ app: AppModel, _ c: DzcKCtx, _ map: DzcMap) -> DzcTouchActions {
        var a = DzcTouchActions()
        a.tap = { pt in tap(c, map, pt) }
        a.panBegan = { pt in panBegan(c, map, pt) }
        a.panMoved = { pt, tr in panMoved(c, map, pt, tr) }
        a.panEnded = { cancel in panEnded(app, c, cancel) }
        a.longBegan = { pt in longBegan(c, map, pt) }
        a.longMoved = { pt, win in longMoved(c, map, pt, win) }
        a.longEnded = { _, cancel in longEnded(app, c, cancel) }
        a.pinch = { state, scale, pt in pinch(c, map, state, scale, pt) }
        return a
    }

    static func tap(_ c: DzcKCtx, _ map: DzcMap, _ pt: CGPoint) {
        let st = DzcState.shared, kit = KitOps.shared
        if st.teachOn { st.teachOn = false; return }
        let now = Date()
        if let lt = st.lastTap, now.timeIntervalSince(lt.t) < 0.32, hypot(lt.p.x - pt.x, lt.p.y - pt.y) < 26 {
            st.lastTap = nil
            withAnimation(.easeOut(duration: 0.22)) { st.cams[c.scene] = DzcCam() }
            return
        }
        st.lastTap = (now, pt)
        guard let m = hit(c, map, pt) else {
            if kit.sel != nil || st.tool != nil { deselect() }
            return
        }
        if st.multi {
            if dzcSpace(m) { return }
            if st.ticks.contains(m.id) { st.ticks.remove(m.id) } else { st.ticks.insert(m.id) }
            Haptic.tick()
            return
        }
        if kit.sel == m.id {
            if !st.peek && !st.inside, let k = hitFront(c, map, m, pt) {
                st.front = st.front == k ? nil : k
                st.scope = "one"
                if let t = st.tool, !tools(c, m).map(\.id).contains(t) { st.tool = nil }
            }
            return
        }
        select(c, m)
    }

    static func panBegan(_ c: DzcKCtx, _ map: DzcMap, _ pt: CGPoint) {
        let st = DzcState.shared
        if st.live?.kind == "pinch" || st.live?.kind == "move" { return }
        if !st.multi && st.front == nil, let m = c.f.modules.first(where: { $0.id == KitOps.shared.sel && $0.wall == c.run.wall }) {
            let l = map.sx(m.x), r = map.sx(m.x + m.w), t = map.sy(m.elev + m.h), b = map.sy(m.elev)
            if resizable(m) && abs(pt.x - r) < 24 && abs(pt.y - (t + b) / 2) < 36 {
                var lv = DzcLive(kind: "resize", mid: m.id)
                lv.w = m.w
                st.live = lv
                return
            }
            if m.type == "wall" && m.app != "hood" && abs(pt.x - (l + r) / 2) < 32 && abs(pt.y - b) < 22 {
                var lv = DzcLive(kind: "height", mid: m.id)
                lv.h = m.h
                st.live = lv
                return
            }
        }
        var lv = DzcLive(kind: "pan")
        lv.cam0 = st.cams[c.scene] ?? DzcCam()
        st.live = lv
    }

    static func panMoved(_ c: DzcKCtx, _ map: DzcMap, _ pt: CGPoint, _ tr: CGSize) {
        let st = DzcState.shared
        guard var lv = st.live else { return }
        switch lv.kind {
        case "resize":
            guard let m = c.f.modules.first(where: { $0.id == lv.mid }) else { return }
            let raw = map.mmX(pt.x) - m.x
            let avail = c.avail(m)
            let mx = dzcMaxW(c.f, m.id, avail: avail)
            let cands = dzcCandidates(m, mx)
            let nw = dzcSnapW(raw, cands, fine: map.fine && !dzcFixedW(m), lo: dzcLowW(m), hi: mx)
            let hit = raw > mx + 60
            if hit && !lv.maxHit { Haptic.warn() }
            lv.maxHit = hit; lv.cands = cands
            if nw != lv.w || lv.preview == nil {
                let r = dzcResize(c.f, m.id, nw, avail: avail, ws: c.ws)
                if r.ok {
                    lv.w = nw
                    lv.preview = pack(r.f, c.runs)
                    lv.taker = r.taker; lv.tw0 = r.w0; lv.tw1 = r.w1; lv.tleft = r.left
                }
            }
            st.live = lv
        case "height":
            guard let m = c.f.modules.first(where: { $0.id == lv.mid }) else { return }
            let raw = m.elev + m.h - map.mmY(pt.y)
            let nh = dzcNearest(raw, DZC_HSNAP)
            if nh != lv.h || lv.preview == nil {
                lv.h = nh
                lv.preview = dzcHeight(c.f, m.id, nh)
                st.live = lv
            }
        case "pan":
            var cam = lv.cam0
            cam.dx += tr.width; cam.dy += tr.height
            st.cams[c.scene] = cam
        default: break
        }
    }

    static func panEnded(_ app: AppModel, _ c: DzcKCtx, _ cancel: Bool) {
        let st = DzcState.shared
        guard let lv = st.live else { return }
        switch lv.kind {
        case "resize":
            st.live = nil
            if !cancel, let m = c.f.modules.first(where: { $0.id == lv.mid }), lv.w != m.w { dzcCommitW(app, c.p, c.f, m.id, lv.w) }
        case "height":
            st.live = nil
            if !cancel { dzcCommitHeight(app, c.p, c.f, lv.mid, lv.h) }
        case "pan": st.live = nil
        default: break
        }
    }

    static func longBegan(_ c: DzcKCtx, _ map: DzcMap, _ pt: CGPoint) {
        let st = DzcState.shared
        if st.multi || st.live?.kind == "pinch" || st.live?.kind == "resize" || st.live?.kind == "height" { return }
        guard let m = hit(c, map, pt), movable(m) else { return }
        let row = dzcRowMods(c.f, dzcRowKey(m))
        guard let i = row.firstIndex(where: { $0.id == m.id }) else { return }
        KitOps.shared.sel = m.id
        st.front = nil; st.tool = nil; st.peek = false
        var lv = DzcLive(kind: "move", mid: m.id)
        lv.gx = m.x; lv.grab = map.mmX(pt.x) - m.x; lv.slot = i; lv.slot0 = i
        lv.preview = c.f
        st.live = lv
        Haptic.tick()
    }

    static func longMoved(_ c: DzcKCtx, _ map: DzcMap, _ pt: CGPoint, _ win: CGPoint) {
        let st = DzcState.shared
        guard var lv = st.live, lv.kind == "move", let m = c.f.modules.first(where: { $0.id == lv.mid }) else { return }
        lv.gx = map.mmX(pt.x) - lv.grab
        let row = dzcRowMods(c.f, dzcRowKey(m))
        let slot = dzcDropSlot(row, m.id, start: c.start(isUpper(m)), gx: lv.gx)
        if slot != lv.slot {
            lv.slot = slot
            lv.preview = pack(dzcMove(c.f, m.id, to: slot, ws: c.ws).f, c.runs)
        }
        let over = st.delFrame.insetBy(dx: -8, dy: -16).contains(win)
        if over && !lv.overDel { Haptic.warn() }
        lv.overDel = over
        st.live = lv
    }

    static func longEnded(_ app: AppModel, _ c: DzcKCtx, _ cancel: Bool) {
        let st = DzcState.shared
        guard let lv = st.live, lv.kind == "move" else { return }
        st.live = nil
        guard !cancel, let m = c.f.modules.first(where: { $0.id == lv.mid }) else { return }
        let pid = c.p.id, fid = c.f.id, ws = c.ws
        Haptic.tick()
        if lv.overDel {
            KitOps.shared.change(pid, fid) { dzcDelete($0, m.id, ws: ws).f }
            KitOps.shared.sel = nil; st.tool = nil
            app.say("dzc.deleted", ["m": modName(m), "v": dzcGapLeft(c.f, m, ws), "w": m.w], action: "common.undo") { KitOps.shared.undo(pid, fid); Haptic.tick() }
        } else if lv.slot != lv.slot0 {
            KitOps.shared.change(pid, fid) { dzcMove($0, m.id, to: lv.slot, ws: ws).f }
            app.say("dzc.moved", ["m": modName(m), "n": lv.slot + 1], action: "common.undo") { KitOps.shared.undo(pid, fid); Haptic.tick() }
        }
    }

    static func pinch(_ c: DzcKCtx, _ map: DzcMap, _ state: UIGestureRecognizer.State, _ scale: CGFloat, _ pt: CGPoint) {
        let st = DzcState.shared
        switch state {
        case .began:
            var lv = DzcLive(kind: "pinch")
            lv.cam0 = st.cams[c.scene] ?? DzcCam(); lv.c0 = pt
            st.live = lv
        case .changed:
            guard let lv = st.live, lv.kind == "pinch" else { return }
            st.cams[c.scene] = dzcPinched(lv.cam0, scale, lv.c0, pt, map)
        default:
            if st.live?.kind == "pinch" { st.live = nil }
        }
    }

    /// A tap in the 3D (its hits, the nearest first): on a front "<unit id>:<front>" its unit is selected, a second tap
    /// its front, a third opens it; on a unit's carcass "<unit id>:body" (an open shelf, a filler) the unit. Marking
    /// (Belgilash): the unit is ticked or unticked.
    static func pick3D(_ c: DzcKCtx, _ keys: [String]) -> Bool {
        guard let key = keys.first, let colon = key.firstIndex(of: ":") else { return false }
        let mid = String(key[..<colon]), fk = String(key[key.index(after: colon)...])
        guard let m = c.f.modules.first(where: { $0.id == mid }) else { return false }
        let st = DzcState.shared, kit = KitOps.shared
        if st.multi {
            if st.ticks.contains(m.id) { st.ticks.remove(m.id) } else { st.ticks.insert(m.id) }
            Haptic.tick()
            return true
        }
        let body = isBodyPick(key)
        if kit.sel == mid {
            // its carcass again: back to the whole unit
            if body { if st.front != nil { st.front = nil; st.tool = nil }; return true }
            if st.front == fk { return false }
            st.front = fk; st.scope = "one"
            if let t = st.tool, !tools(c, m).map(\.id).contains(t) { st.tool = nil }
            return true
        }
        select(c, m)
        return true
    }

    /// What the 3D outlines in amber: the selected unit, or its selected front; the marked units.
    static func hiKeys3D(_ c: DzcKCtx) -> [String] {
        let st = DzcState.shared
        if st.multi { return st.ticks.sorted().map { $0 + ":body" } }
        guard let m = c.sel else { return [] }
        if let fk = st.front { return [m.id + ":" + fk] }
        return [m.id + ":body"]
    }

    /* ---------------- the tools ---------------- */

    static func tl(_ id: String, _ key: String = "", icon: String = "", tone: String = "", on: Bool = false, badge: Int? = nil) -> DzcTool {
        DzcTool(id: id, label: tr("dzc.t." + (key.isEmpty ? id : key)), icon: icon, badge: badge, tone: tone, on: on)
    }

    /// The slider's tools for the selection (most used first, as the founder ordered them).
    static func tools(_ c: DzcKCtx, _ sel: Module?) -> [DzcTool] {
        let st = DzcState.shared
        if st.multi {
            return [tl("decor"), tl("handle"), tl("type"), tl("in"), tl("mdel", "del", icon: "del", tone: "red"), tl("mdone", "done", icon: "done", tone: "pri")]
        }
        guard let m = sel else {
            return [tl("add"), tl("style"), tl("decor"), tl("handle"), tl("multi"), tl("see", on: st.inside), tl("checks", badge: c.issues.count), tl("plinth"), tl("more")]
        }
        if let fk = st.front {
            var a = [tl("handle")]
            let fr = handleFronts(m).first(where: { $0.key == fk })
            let door = fr.map { !$0.drawer } ?? false
            if door && m.fronts.kind == "door" && m.type != "gap" { a.append(tl("hinge")) }
            if door { a.append(tl("soft")) }
            a.append(tl("selUp"))
            return a
        }
        if dzcSpace(m) { return [tl("add"), tl("closeGap")] }
        if m.type == "filler" { return [tl("width"), tl("decor"), tl("move"), tl("del", icon: "del", tone: "red")] }
        let hasF = !handleFronts(m).isEmpty
        let doors = m.fronts.kind == "door" && m.type != "gap"
        let single = doors
        if isUpper(m) {
            if m.app == "hood" { return [tl("width"), tl("align"), tl("copy"), tl("move"), tl("del", icon: "del", tone: "red")] }
            var a = [tl("type"), tl("width"), tl("height"), tl("align"), tl("decor")]
            if hasF { a.append(tl("handle")) }
            a += [tl("in"), tl("copy"), tl("move"), tl("depth")]
            if doors { a.append(tl("soft")) }
            if single { a.append(tl("hinge")) }
            a += [tl("setup"), tl("del", icon: "del", tone: "red")]
            return a
        }
        var a: [DzcTool] = []
        let pinned = dzcPinned(m)
        if !pinned && m.type != "tall" && m.type != "gap" { a.append(tl("type")) }
        a += [tl("width"), tl("decor")]
        if hasF { a.append(tl("handle")) }
        if m.type != "gap" && m.app != "hob" { a.append(tl("in")) }
        if !pinned { a.append(tl("copy")) }
        if movable(m) { a.append(tl("move")) }
        if m.type != "gap" { a.append(tl("depth")) }
        a.append(tl("plinth"))
        if doors || m.fronts.kind == "drawer" { a.append(tl("soft")) }
        if single { a.append(tl("hinge")) }
        a += [tl("setup"), tl("del", icon: "del", tone: "red")]
        return a
    }

    static func toolTap(_ app: AppModel, _ c: DzcKCtx, _ id: String) {
        let st = DzcState.shared, kit = KitOps.shared
        Haptic.tick()
        switch id {
        case "multi":
            st.multi = true
            if let m = c.sel, !dzcSpace(m) { st.ticks = [m.id] } else { st.ticks = [] }
            kit.sel = nil; st.front = nil; st.tool = nil; st.peek = false
        case "mdone": st.multi = false; st.ticks = []; st.tool = nil
        case "mdel": deleteMarked(app, c)
        case "see": st.inside.toggle()
        case "align": align(app, c)
        case "copy": copy(app, c)
        case "del": delete(app, c)
        case "closeGap": closeGap(app, c)
        case "selUp": st.front = nil; st.tool = nil
        case "setup": if let m = c.sel { app.sheet = .fModule(pid: c.p.id, fid: c.f.id, mid: m.id) }
        case "more": app.sheet = .dzcMore(pid: c.p.id, fid: c.f.id, tab: "k")
        default:
            st.tool = id; st.scope = "one"
            st.peek = id == "in" && c.sel != nil
        }
    }

    /* ---------------- the actions ---------------- */

    static func change(_ c: DzcKCtx, _ fn: (Furniture) -> Furniture) { KitOps.shared.change(c.p.id, c.f.id, fn) }

    static func said(_ app: AppModel, _ c: DzcKCtx, _ key: String, _ vars: [String: Any] = [:]) { dzcSaid(app, c.p.id, c.f.id, key, vars) }

    static func delete(_ app: AppModel, _ c: DzcKCtx) {
        guard let m = c.sel else { return }
        let ws = c.ws
        change(c) { dzcDelete($0, m.id, ws: ws).f }
        KitOps.shared.sel = nil; DzcState.shared.tool = nil
        said(app, c, "dzc.deleted", ["m": modName(m), "v": dzcGapLeft(c.f, m, ws), "w": m.w])
    }

    static func deleteMarked(_ app: AppModel, _ c: DzcKCtx) {
        let st = DzcState.shared
        let ids = st.ticks
        if ids.isEmpty { dzcWarn(app, "dzc.markFirst"); return }
        let ws = c.ws
        change(c) { x in ids.reduce(x) { g, id in dzcDelete(g, id, ws: ws).f } }
        st.ticks = []
        said(app, c, "dzc.mDeleted", ["n": ids.count])
    }

    static func closeGap(_ app: AppModel, _ c: DzcKCtx) {
        guard let m = c.sel else { return }
        let avail = c.avail(m), ws = c.ws
        let r = dzcCloseGap(c.f, m.id, avail: avail, ws: ws)
        if !r.ok { dzcWarn(app, r.why, r.vars); return }
        change(c) { dzcCloseGap($0, m.id, avail: avail, ws: ws).f }
        KitOps.shared.sel = nil; DzcState.shared.tool = nil
        if let t = r.taker { said(app, c, "dzc.closedTo", ["t": dzcTakerName(c.f, t), "a": r.w0, "b": r.w1]) }
        // a new filler or space at the row's end, or (an island) the row just shorter
        else if r.newId != nil { said(app, c, "dzc.closed", ["v": m.w]) } else { said(app, c, "dzc.closed0") }
    }

    static func copy(_ app: AppModel, _ c: DzcKCtx) {
        guard let m = c.sel else { return }
        let avail = c.avail(m), ws = c.ws
        let r = dzcCopy(c.f, m.id, avail: avail, ws: ws)
        if !r.ok { dzcWarn(app, r.why, r.vars); return }
        guard let nid = r.newId else { return }
        // the copy made again on the saved piece, with the same new id
        change(c) { dzcCopy($0, m.id, avail: avail, ws: ws, id: nid).f }
        KitOps.shared.sel = nid
        said(app, c, "dzc.copied", ["m": modName(m)])
    }

    static func align(_ app: AppModel, _ c: DzcKCtx) {
        guard let m = c.sel else { return }
        let ws = c.ws
        let r = dzcAlign(c.f, m.id, ws: ws)
        if !r.ok { if r.why == "dzc.alreadyAligned" { app.say(r.why) } else { dzcWarn(app, r.why) }; return }
        change(c) { dzcAlign($0, m.id, ws: ws).f }
        said(app, c, "dzc.alignedTo", ["m": tr("kn." + kindOf(m)), "a": r.w0, "b": r.w1])
    }

    static func step(_ app: AppModel, _ c: DzcKCtx, _ d: Int) {
        guard let m = c.sel else { return }
        let ws = c.ws
        guard dzcStep(c.f, m.id, d, ws: ws) != nil else { dzcWarn(app, "dzc.cantMove"); return }
        change(c) { dzcStep($0, m.id, d, ws: ws)?.f ?? $0 }
        said(app, c, d < 0 ? "dzc.movedL" : "dzc.movedR", ["m": modName(m)])
    }

    static func fix(_ app: AppModel, _ c: DzcKCtx, _ ck: FCheck) {
        let runs = c.runs, ops = c.room.openings, ws = c.ws
        guard let r = dzcFix(c.f, ck, runs, ops, ws: ws) else { return }
        let before = checkText(ck, c.f)
        change(c) { x in dzcFix(x, ck, runs, ops, ws: ws)?.f ?? x }
        if let id = ck.mid, r.f.modules.contains(where: { $0.id == id }) { KitOps.shared.sel = id }
        said(app, c, "dzc.fixed", ["m": before])
    }

    /// A tile tapped: into the selected space or the first one it fits, else the wall's free end.
    static func tileTap(_ app: AppModel, _ c: DzcKCtx, _ t: DzcTile) {
        let res = dzcTapPlan(c.f, c.runs, cur: c.run.wall, sel: KitOps.shared.sel, t, ws: c.ws)
        if !res.plan.ok { dzcWarn(app, res.plan.why, res.plan.vars); return }
        apply(app, c, res.wall, t, res.plan)
    }

    /// A tile dropped at screen point pt: where its preview showed it.
    static func tileDrop(_ app: AppModel, _ c: DzcKCtx, _ t: DzcTile, _ pt: CGPoint) {
        let st = DzcState.shared
        let fr = st.canvasFrame
        guard let map = st.map, fr.contains(pt), !c.d3 else { return }
        if t.upper && c.run.wall == ISLAND { dzcWarn(app, "dzc.noUp"); return }
        let u = map.mmX(pt.x - fr.minX)
        let key = DzcRow(wall: c.run.wall, upper: t.upper)
        let plan = dzcPlanAt(dzcRowMods(c.f, key), t, u: u, start: c.start(t.upper), avail: c.availRow(c.run.wall, t.upper), ws: c.ws, wall: c.run.wall)
        if !plan.ok { dzcWarn(app, plan.why, plan.vars); return }
        apply(app, c, c.run.wall, t, plan)
    }

    static func apply(_ app: AppModel, _ c: DzcKCtx, _ wall: String, _ t: DzcTile, _ plan: DzcPlan) {
        let key = DzcRow(wall: wall, upper: t.upper)
        let row = plan.row
        change(c) { dzcWithRow($0, key, row) }
        KitOps.shared.sel = plan.id
        DzcState.shared.front = nil
        Haptic.tick()
        if wall != c.run.wall { AppModel.shared.setTop(.kitchen(pid: c.p.id, fid: c.f.id, wall: wall, d3: c.d3)) }
        let name = dzcTileName(t) + " \(plan.w)"
        app.say(plan.space != nil ? "dzc.addedGap" : "dzc.added", ["m": name], action: "common.undo") { KitOps.shared.undo(c.p.id, c.f.id); Haptic.tick() }
    }
}

/// A tile's name: the library kind's, a blind corner's and an open lower unit's own.
func dzcTileName(_ t: DzcTile) -> String {
    switch t.kind {
    case "corner": return tr("dzc.k.corner")
    case "openLow": return tr("dzc.k.openLow")
    default: return tr("kn." + t.kind)
    }
}

/* ---------------- the bottom: slider, options, delete zone ---------------- */

private struct DzcKBottom: View {
    let app: AppModel
    let c: DzcKCtx
    var body: some View {
        let st = DzcState.shared
        VStack(spacing: 0) {
            if st.live?.kind == "move" {
                DzcDelZone(on: st.live?.overDel == true)
            } else if let t = st.tool {
                DzcKOptions(app: app, c: c, tool: t)
            } else {
                DzcSlider(tools: DzcKOps.tools(c, c.sel)) { id in DzcKOps.toolTap(app, c, id) }
            }
        }
        .frame(maxWidth: .infinity)
        .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) } }
        .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 1) }
        // toasts rise above the slider, not over it
        .bottomBar()
    }
}

/// The open tool's options row.
private struct DzcKOptions: View {
    let app: AppModel
    let c: DzcKCtx
    let tool: String
    var body: some View {
        let st = DzcState.shared
        let back = { st.tool = nil; st.peek = false; st.scope = "one" }
        switch tool {
        case "add": DzcKAdd(app: app, c: c, onBack: back)
        case "style": DzcKStyle(app: app, c: c, onBack: back)
        case "decor": DzcKDecor(app: app, c: c, onBack: back)
        case "handle": DzcKHandle(app: app, c: c, onBack: back)
        case "soft": DzcKSoft(app: app, c: c, onBack: back)
        case "hinge": DzcKHinge(app: app, c: c, onBack: back)
        case "type": DzcKType(app: app, c: c, onBack: back)
        case "width": DzcKWidth(app: app, c: c, onBack: back)
        case "height": DzcKHeight(app: app, c: c, onBack: back)
        case "in": DzcKIn(app: app, c: c, onBack: back)
        case "move": DzcOptRow(title: tr("dzc.t.move"), sub: c.sel.map(modName) ?? "", onBack: back) {
            DzcOpt(label: tr("dzc.left"), glyph: "left", id: "dzc.o.left") { DzcKOps.step(app, c, -1) }
            DzcOpt(label: tr("dzc.right"), glyph: "right", id: "dzc.o.right") { DzcKOps.step(app, c, 1) }
            DzcNote(text: tr("dzc.moveHint"))
        }
        case "depth": DzcKDepth(app: app, c: c, onBack: back)
        case "plinth": DzcKPlinth(app: app, c: c, onBack: back)
        case "checks": DzcKChecks(app: app, c: c, onBack: back)
        default: DzcOptRow(title: tool, onBack: back) { EmptyView() }
        }
    }
}

/// Qo‘shish: the whole catalogue by category; a tile dragged up onto the wall goes where its preview shows, a tapped
/// one into the first space it fits.
private struct DzcKAdd: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let st = DzcState.shared
        let sub = c.sel.map { dzcSpace($0) ? tr("dzc.addGap") : tr("dzc.addHint") } ?? tr("dzc.addHint")
        VStack(spacing: 0) {
            DzcOptRow(title: tr("dzc.t.add"), sub: sub, onBack: onBack) {
                ForEach(DZC_CATS, id: \.self) { k in
                    let n = DZC_TILES.filter { $0.cat == k }.count
                    DzcOpt(label: tr("dzc.cat." + k) + " · \(n)", on: st.cat == k, id: "dzc.cat." + k) { st.cat = k }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DZC_TILES.filter { $0.cat == st.cat }, id: \.self) { t in DzcKTileView(app: app, c: c, t: t) }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
        }
    }
}

private struct DzcKTileView: View {
    let app: AppModel
    let c: DzcKCtx
    let t: DzcTile
    var body: some View {
        let st = DzcState.shared
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let tile = t, ctx = c
        let drag = LongPressGesture(minimumDuration: 0.12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { v in
                if case .second(true, let d?) = v {
                    if ctx.d3 { return }
                    st.tile = DzcTileDrag(tile: tile, pt: d.location)
                }
            }
            .onEnded { v in
                let pt = st.tile?.pt
                st.tile = nil
                if case .second(true, let d?) = v, let pt, abs(d.translation.height) > 20 || abs(d.translation.width) > 20 {
                    DzcKOps.tileDrop(app, ctx, tile, pt)
                } else if case .second(true, _) = v, ctx.d3 {
                    DzcKOps.tileTap(app, ctx, tile)
                }
            }
        VStack(spacing: 2) {
            if let d = DZC_GLYPH[t.kind] { DzcIcon(d: d, color: G.ink, size: 26, box: 26, stroke: 1.6) }
            // two short lines, not "Tortmali mo…"
            T(dzcTileName(t), ui(10.5, 700, lh: 1.1), align: .center, lines: 2).minimumScaleFactor(0.85)
            T("\(t.w)" + (t.upper ? " · " + tr("dzc.up") : ""), num(10.5, 600, G.ink2), lines: 1)
        }
        .frame(width: 78, height: 78)
        .background(shape.fill(t.upper ? G.cobalt.opacity(0.06) : G.glass(0.7)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture { DzcKOps.tileTap(app, ctx, tile) }
        .simultaneousGesture(drag)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dzcTileName(t) + " \(t.w)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("dzc.tile.\(t.kind).\(t.w)")
        .overlay { if let td = st.tile, td.tile == t { shape.strokeBorder(G.cobalt, lineWidth: 2) } }
    }
}

/// Uslub: the six design styles (fronts and handles of the whole kitchen).
private struct DzcKStyle: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let cur = presetOf(c.f), ws = c.ws, pid = c.p.id, fid = c.f.id
        DzcOptRow(title: tr("dzc.t.style"), sub: tr("dzc.styleSub"), onBack: onBack) {
            ForEach(DESIGN_PRESETS, id: \.id) { d in
                let on = d.id == cur
                VStack(spacing: 3) {
                    PresetPicture(p: d).frame(width: 74, height: 40).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    T(tr("lk.p." + d.id), ui(11, on ? 800 : 600, on ? G.cobalt2 : G.ink), lines: 1)
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? G.cobalt.opacity(0.1) : .clear))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
                .pressable(0.97) {
                    KitOps.shared.change(pid, fid) { x in
                        var y = withPreset(x, d.id, ws: ws)
                        y.modules = y.modules.map { m in var n = m; n.front = nil; return n }
                        return y
                    }
                    dzcSaid(app, pid, fid, "lk.applied", ["n": tr("lk.p." + d.id)])
                }
                .accessibilityIdentifier("dzc.style." + d.id)
            }
        }
    }
}

/// A front colour the fronts take (the design card's): its key, colour, a wood's grain.
struct DzcFrontSw: Hashable {
    let key: String
    let rgb: String
    let wood: Bool
}

let DZC_FRONTS: [DzcFrontSw] = LOOK_COLOURS.map { DzcFrontSw(key: $0.key, rgb: $0.rgb, wood: false) } + LOOK_WOODS.map { DzcFrontSw(key: $0.key, rgb: $0.rgb, wood: true) }

func dzcFrontName(_ k: String) -> String { LOOK_WOODS.contains { $0.key == k } ? tr("lk.w." + k) : tr("lk.c." + k) }

/// The board a colour key gives this piece (its finish and its fronts' style).
func dzcBoard(_ f: Furniture, _ key: String) -> String {
    let l = f.look ?? PieceLook()
    let finish = l.finish.isEmpty ? (f.mats.front.hasPrefix("ag_") ? "gloss" : "matte") : l.finish
    return boardFor(key, finish, l.style)
}

/// Fasad: one unit, its row, the whole kitchen.
private struct DzcKDecor: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let st = DzcState.shared
        let sel = c.sel
        let cur = colourOf(frontOf(c.f, sel))
        let scopes: [(String, String)] = sel != nil && !st.multi ? [("one", tr("dzc.sc.one")), ("row", tr("dzc.sc.row")), ("all", tr("dzc.sc.allK"))] : []
        let sub = st.multi ? tr("dzc.nMarked", ["n": st.ticks.count]) : sel == nil ? tr("dzc.wholeK") : ""
        DzcOptRow(title: tr("dzc.t.decor"), sub: sub, scopes: scopes, onBack: onBack) {
            ForEach(DZC_FRONTS, id: \.self) { s in
                DzcSwatch(rgb: s.rgb, label: dzcFrontName(s.key), wood: s.wood, on: !st.multi && cur == s.key, id: "dzc.sw." + s.key) { set(s.key) }
            }
        }
    }

    private func set(_ key: String) {
        let st = DzcState.shared
        let board = dzcBoard(c.f, key)
        let name = dzcFrontName(key)
        if st.multi {
            let ids = st.ticks
            if ids.isEmpty { dzcWarn(app, "dzc.markFirst"); return }
            DzcKOps.change(c) { withLook(dzcFrontOne($0, ids, board)) { $0 } }
            DzcKOps.said(app, c, "dzc.decorN", ["c": name, "d": name, "n": ids.count])
            return
        }
        guard let m = c.sel, st.scope != "all" else {
            DzcKOps.change(c) { withLook(dzcFrontAll($0, board)) { $0 } }
            DzcKOps.said(app, c, "dzc.decorAll", ["c": name, "d": name])
            return
        }
        if st.scope == "row" {
            let up = isUpper(m)
            DzcKOps.change(c) { withLook(dzcFrontRow($0, upper: up, board)) { $0 } }
            DzcKOps.said(app, c, up ? "dzc.decorRowUp" : "dzc.decorRowLow", ["c": name])
            return
        }
        DzcKOps.change(c) { withLook(dzcFrontOne($0, [m.id], board)) { $0 } }
        DzcKOps.said(app, c, "dzc.decorOne", ["c": name, "d": name, "m": modName(m)])
    }
}

/// Tutqich: a front or a unit with a handle or a push latch ("Faqat shu"); the handle type of the whole kitchen
/// ("Hammasiga", or nothing selected).
private struct DzcKHandle: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let st = DzcState.shared
        let sel = c.sel
        let scopes: [(String, String)] = sel != nil && !st.multi ? [("one", tr("dzc.sc.one")), ("all", tr("dzc.sc.all"))] : []
        let whole = (sel == nil && !st.multi) || st.scope == "all"
        // what the options change follows the scope: "Faqat shu" this front or this unit, "Hammasiga" the whole kitchen
        let sub = whole ? tr("dzc.wholeK") : st.multi ? tr("dzc.nMarked", ["n": st.ticks.count]) : dzcOnlySub(sel, st.front, tr("dzc.onlyM"))
        DzcOptRow(title: tr("dzc.t.handle"), sub: sub, scopes: scopes, onBack: onBack) {
            if whole {
                let cur = handleType(c.f)
                ForEach(["bar", "long", "knob", "gola", "push"], id: \.self) { k in
                    DzcOpt(label: tr("lk.h." + k), glyph: "h-" + k, on: cur == k, id: "dzc.h." + k) { setType(k) }
                }
            } else {
                let on = currentOn()
                DzcOpt(label: tr("dzc.hOn"), glyph: "h-on", on: on == true, id: "dzc.h.on") { setOne(true) }
                DzcOpt(label: tr("dzc.hOff"), glyph: "h-off", on: on == false, id: "dzc.h.off") { setOne(false) }
            }
        }
    }

    private func currentOn() -> Bool? {
        let st = DzcState.shared
        guard !st.multi, let m = c.sel else { return nil }
        if let fk = st.front { return hasHandle(m, fk) }
        let fr = handleFronts(m)
        if fr.allSatisfy({ hasHandle(m, $0.key) }) { return true }
        if fr.allSatisfy({ !hasHandle(m, $0.key) }) { return false }
        return nil
    }

    private func setType(_ k: String) {
        DzcKOps.change(c) { withLook(withHandleType($0, k)) { $0 } }
        DzcKOps.said(app, c, "dzc.handleAll", ["h": tr("lk.h." + k)])
    }

    private func setOne(_ on: Bool) {
        let st = DzcState.shared
        if st.multi {
            let ids = st.ticks
            if ids.isEmpty { dzcWarn(app, "dzc.markFirst"); return }
            DzcKOps.change(c) { x in var y = x; y.modules = x.modules.map { ids.contains($0.id) ? allHandles($0, on) : $0 }; return y }
            DzcKOps.said(app, c, on ? "dzc.hOnN" : "dzc.hOffN", ["n": ids.count])
            return
        }
        guard let m = c.sel else { return }
        if let fk = st.front {
            let name = handleFronts(m).first { $0.key == fk }.map { frontName(m, $0) } ?? ""
            DzcKOps.change(c) { x in var y = x; y.modules = x.modules.map { $0.id == m.id ? withHandle($0, fk, on) : $0 }; return y }
            DzcKOps.said(app, c, on ? "dzc.hOnOne" : "dzc.hOffOne", ["m": name])
            return
        }
        DzcKOps.change(c) { x in var y = x; y.modules = x.modules.map { $0.id == m.id ? allHandles($0, on) : $0 }; return y }
        DzcKOps.said(app, c, on ? "dzc.hOnOne" : "dzc.hOffOne", ["m": modName(m)])
    }
}

/// Yumshoq yopilish: this unit, or every unit with doors.
private struct DzcKSoft: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let on = c.sel?.soft ?? true
        DzcOptRow(title: tr("dzc.t.soft"), sub: tr("dzc.softSub"), scopes: [("one", tr("dzc.sc.one")), ("all", tr("dzc.sc.all"))], onBack: onBack) {
            DzcOpt(label: tr("dzc.on"), glyph: "soft", on: on, id: "dzc.soft.on") { set(true) }
            DzcOpt(label: tr("dzc.off"), glyph: "x", on: !on, id: "dzc.soft.off") { set(false) }
        }
    }
    private func set(_ on: Bool) {
        guard let m = c.sel else { return }
        let all = DzcState.shared.scope == "all"
        DzcKOps.change(c) { x in
            var y = x
            y.modules = x.modules.map { u in
                guard u.id == m.id || (all && (u.fronts.kind == "door" || u.fronts.kind == "drawer")) else { return u }
                var n = u; n.soft = on; return n
            }
            return y
        }
        DzcKOps.said(app, c, on ? "dzc.softOn" : "dzc.softOff", ["m": all ? tr("dzc.everywhere") : modName(m)])
    }
}

/// Ochilish tomoni: the selected door, or every door of the unit, hinged on its left or its right.
private struct DzcKHinge: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let j = door()
        let cur = Self.side(c.sel, j)
        let sub = Self.what(c.sel, j)
        DzcOptRow(title: tr("dzc.t.hinge"), sub: sub, onBack: onBack) {
            DzcOpt(label: tr("dzc.sideL"), glyph: "hg-L", on: cur == "L", id: "dzc.hinge.L") { set("L") }
            DzcOpt(label: tr("dzc.sideR"), glyph: "hg-R", on: cur == "R", id: "dzc.hinge.R") { set("R") }
        }
    }
    /// The side the door (j; -1 every door) hinges on: "L", "R", or "" when the doors differ.
    private static func side(_ m: Module?, _ j: Int) -> String {
        guard let m else { return "" }
        let n = max(1, m.fronts.n)
        if j >= 0 { return kHingeRight(m, j, n) ? "R" : "L" }
        let all = (0..<n).map { kHingeRight(m, $0, n) }
        if all.allSatisfy({ $0 }) { return "R" }
        if all.allSatisfy({ !$0 }) { return "L" }
        return ""
    }
    private static func what(_ m: Module?, _ j: Int) -> String {
        guard let m else { return "" }
        if j < 0 { return tr("dzc.allDoorsOf", ["m": modName(m)]) }
        let fr = handleFronts(m).first(where: { $0.key == "f\(j)" })
        return fr.map { frontName(m, $0) } ?? ""
    }
    /// The selected door's number, -1 the whole unit.
    private func door() -> Int {
        guard let fk = DzcState.shared.front, fk.hasPrefix("f") else { return -1 }
        return Int(fk.dropFirst()) ?? -1
    }
    private func set(_ h: String) {
        guard let m = c.sel else { return }
        let j = door()
        DzcKOps.change(c) { x in var y = x; y.modules = x.modules.map { $0.id == m.id ? withHinge($0, j, h) : $0 }; return y }
        DzcKOps.said(app, c, h == "L" ? "dzc.hingeL" : "dzc.hingeR", ["m": modName(m)])
    }
}

/// Turi: a lower unit's or an upper one's types (marked units: the lower ones).
private struct DzcKType: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let st = DzcState.shared
        let sel = c.sel
        let up = !st.multi && sel.map(isUpper) == true
        let list = up ? DZC_TYPES_UP : DZC_TYPES_LOW
        let cur = st.multi ? "" : sel.map(dzcTypeOf) ?? ""
        let sub = st.multi ? tr("dzc.nMarked", ["n": st.ticks.count]) + " · " + tr("dzc.lowOnly") : sel.map(modName) ?? ""
        DzcOptRow(title: tr("dzc.t.type"), sub: sub, onBack: onBack) {
            ForEach(list, id: \.self) { k in
                DzcOpt(label: tr("dzc.ty." + k), glyph: k, on: cur == k, id: "dzc.ty." + k) { set(k) }
            }
        }
    }
    private func set(_ k: String) {
        let st = DzcState.shared, ws = c.ws
        var ids: [String] = []
        if st.multi {
            for m in c.f.modules where st.ticks.contains(m.id) && !isUpper(m) && !dzcSpace(m) {
                if m.type == "filler" || m.type == "tall" || dzcPinned(m) { continue }
                ids.append(m.id)
            }
        } else if let m = c.sel {
            ids = [m.id]
        }
        if ids.isEmpty { dzcWarn(app, "dzc.markLow"); return }
        var bad = 0
        for id in ids { if let m = c.f.modules.first(where: { $0.id == id }), dzcRetype(m, k, ws: ws) == nil { bad += 1 } }
        if bad == ids.count { dzcWarn(app, "dzc.typeW", ["t": tr("dzc.ty." + k)]); return }
        DzcKOps.change(c) { x in
            var y = x
            y.modules = x.modules.map { m in ids.contains(m.id) ? (dzcRetype(m, k, ws: ws) ?? m) : m }
            return y
        }
        DzcKOps.said(app, c, "dzc.typed", ["t": tr("dzc.ty." + k), "n": ids.count - bad])
    }
}

/// Kenglik: the snap widths that fit (a filler's own) and "Yozish".
private struct DzcKWidth: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        if let m = c.sel {
            let mx = dzcMaxW(c.f, m.id, avail: c.avail(m))
            let list = m.type == "filler" ? [20, 30, 50, 80, 100].filter { $0 <= mx } : dzcCandidates(m, mx)
            let pid = c.p.id, fid = c.f.id
            DzcOptRow(title: tr("dzc.t.width"), sub: tr("dzc.wSub", ["v": m.w, "m": mx]), onBack: onBack) {
                ForEach(list, id: \.self) { v in
                    DzcOpt(label: "\(v)", on: m.w == v, id: "dzc.w.\(v)") { dzcCommitW(app, c.p, c.f, m.id, v) }
                }
                DzcOpt(label: tr("dzc.type"), glyph: "kbd", id: "dzc.w.kbd") { app.sheet = .dzcNum(pid: pid, fid: fid, mid: m.id, key: "w", sec: -1) }
            }
        }
    }
}

/// Balandlik: a wall unit's heights, its top kept.
private struct DzcKHeight: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        if let m = c.sel {
            let pid = c.p.id, fid = c.f.id
            DzcOptRow(title: tr("dzc.t.height"), sub: tr("dzc.hSub", ["v": m.h]), onBack: onBack) {
                ForEach(DZC_HSNAP, id: \.self) { v in
                    DzcOpt(label: "\(v)", on: m.h == v, id: "dzc.h.\(v)") { dzcCommitHeight(app, c.p, c.f, m.id, v) }
                }
                DzcOpt(label: tr("dzc.type"), glyph: "kbd", id: "dzc.h.kbd") { app.sheet = .dzcNum(pid: pid, fid: fid, mid: m.id, key: "h", sec: -1) }
            }
        }
    }
}

/// Ichki: the shelves (the door opened to show them) or a drawer unit's drawers.
private struct DzcKIn: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let st = DzcState.shared
        let m: Module? = c.sel ?? (c.f.modules.first(where: { st.ticks.contains($0.id) }))
        if let m {
            let ids: Set<String> = st.multi ? st.ticks : [m.id]
            if m.fronts.kind == "drawer" && !st.multi {
                DzcOptRow(title: tr("dzc.t.in"), sub: modName(m), onBack: onBack) {
                    DzcStepper(label: tr("dzc.drawers"), v: m.fronts.n, lo: 2, hi: 5, id: "dzc.in.dr") { n in
                        DzcKOps.change(c) { x in var y = x; y.modules = x.modules.map { $0.id == m.id ? dzcDrawers($0, n) : $0 }; return y }
                        DzcKOps.said(app, c, "dzc.drawersN", ["n": n])
                    }
                }
            } else {
                let q = dzcShelfCount(m)
                DzcOptRow(title: tr("dzc.t.in"), sub: st.multi ? tr("dzc.nMarked", ["n": ids.count]) : tr("dzc.doorOpen"), onBack: onBack) {
                    DzcStepper(label: tr("dzc.shelves"), v: q, lo: 0, hi: 6, id: "dzc.in.sh") { n in
                        DzcKOps.change(c) { x in var y = x; y.modules = x.modules.map { ids.contains($0.id) && $0.fronts.kind != "drawer" ? dzcShelves($0, n) : $0 }; return y }
                        DzcKOps.said(app, c, "dzc.shelvesN", ["n": n])
                    }
                    if !st.multi {
                        DzcOpt(label: tr(st.peek ? "dzc.doorClose" : "dzc.doorOpenB"), glyph: "see", on: st.peek, id: "dzc.in.peek") { st.peek.toggle() }
                    }
                }
            }
        }
    }
}

/// Chuqurlik: this unit or its whole row (lower or upper, every wall).
private struct DzcKDepth: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        if let m = c.sel {
            let up = isUpper(m)
            DzcOptRow(title: tr("dzc.t.depth"), sub: tr("dzc.dSub", ["v": m.d]), scopes: [("one", tr("dzc.sc.one")), ("row", tr("dzc.sc.row"))], onBack: onBack) {
                ForEach(up ? DZC_DEPTH_UP : DZC_DEPTH_LOW, id: \.self) { v in
                    DzcOpt(label: "\(v) mm", on: m.d == v, id: "dzc.d.\(v)") { set(m, v) }
                }
            }
        }
    }
    private func set(_ m: Module, _ v: Int) {
        let row = DzcState.shared.scope == "row", up = isUpper(m)
        DzcKOps.change(c) { x in
            var y = x
            y.modules = x.modules.map { u in
                let take = u.id == m.id || (row && isUpper(u) == up && (u.type == "base" || u.type == "wall" || u.type == "tall"))
                guard take else { return u }
                var n = u; n.d = v; return n
            }
            return y
        }
        DzcKOps.said(app, c, row ? (up ? "dzc.depthRowUp" : "dzc.depthRowLow") : "dzc.depthOne", ["v": v, "m": modName(m)])
    }
}

/// Tsokol/oyoq: one for the whole kitchen, with its height.
private struct DzcKPlinth: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let kind = dzcKitchenBaseKind(c.f)
        let h = wsOf(c.f, AppSettings.shared.workshop).legH
        let i = DZC_BASE_H.firstIndex(of: dzcNearest(h, DZC_BASE_H)) ?? 1
        DzcOptRow(title: tr("dzc.t.plinth"), sub: tr("dzc.wholeK") + " · \(h) mm", onBack: onBack) {
            ForEach(["plinth", "legs", "metal"], id: \.self) { k in
                DzcOpt(label: tr("dzc.base." + k), glyph: k, on: kind == k, id: "dzc.base." + k) { set(k, h) }
            }
            DzcStepper(label: tr("dzc.baseH"), v: h, lo: DZC_BASE_H.first!, hi: DZC_BASE_H.last!, id: "dzc.base.h") { v in
                let j = min(max(i + (v > h ? 1 : -1), 0), DZC_BASE_H.count - 1)
                set(kind, DZC_BASE_H[j])
            }
        }
    }
    private func set(_ k: String, _ h: Int) {
        let ws = AppSettings.shared.workshop
        DzcKOps.change(c) { dzcKitchenBase($0, k, h, ws: ws) }
        DzcKOps.said(app, c, "dzc.based", ["b": tr("dzc.base." + k), "v": h])
    }
}

/// Tekshiruv: every problem; a tap goes to its unit, "Tuzatish" fixes it.
private struct DzcKChecks: View {
    let app: AppModel
    let c: DzcKCtx
    let onBack: () -> Void
    var body: some View {
        let list = c.issues
        DzcOptRow(title: tr("dzc.t.checks"), sub: list.isEmpty ? tr("dzc.allOk") : tr("dzc.nIssues", ["n": list.count]), onBack: onBack) {
            if list.isEmpty {
                DzcOpt(label: tr("kt.allOk"), glyph: "done", id: "dzc.ck.ok") {}
            }
            ForEach(Array(list.enumerated()), id: \.offset) { i, ck in
                let fixable = dzcFix(c.f, ck, c.runs, c.room.openings, ws: c.ws) != nil
                HStack(spacing: 4) {
                    DzcOpt(label: checkText(ck, c.f), glyph: "checks", tone: ck.level == "err" ? "red" : "", id: "dzc.ck.\(i)") { go(ck) }
                        .frame(maxWidth: 260)
                    if fixable {
                        DzcOpt(label: tr("dzc.fix"), glyph: "done", on: true, id: "dzc.ck.fix\(i)") { DzcKOps.fix(app, c, ck) }
                    }
                }
            }
        }
    }
    private func go(_ ck: FCheck) {
        guard let id = ck.mid, let m = c.f.modules.first(where: { $0.id == id }) else { return }
        let st = DzcState.shared
        st.tool = nil; st.callMin = false
        KitOps.shared.sel = id
        if m.wall != c.run.wall { AppModel.shared.setTop(.kitchen(pid: c.p.id, fid: c.f.id, wall: m.wall, d3: false)) }
    }
}
