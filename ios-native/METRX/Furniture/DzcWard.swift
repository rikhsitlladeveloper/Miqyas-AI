import SwiftUI
import UIKit

/*
 * Designer C for every cabinet on the wardrobe's engine (founder-approved 27 Oct 2026): wardrobes and kupe, gorka and
 * stenka, vitrina, komod and the bedroom's, bathroom and kids' cabinets. The box's front fills the screen; a tap
 * selects a section, a second tap one of its doors; a section's right edge dragged sets its width (its neighbour taking
 * the difference); held 0.4 s it lifts and moves among the others, dropped on the red zone it is deleted. The slider and
 * the options rows are the kitchen's (DzcKit.swift); the older steps (sizes, place, doors, inside, materials) stay in
 * "Batafsil" (WardrobeScreens.swift DzcWardMore).
 */

/// What the wardrobe designer works with: the piece, its box being designed, the checks.
struct DzcWCtx {
    let p: Project
    let f: Furniture
    let m: Module
    let room: Room
    let cx: WardCtx
    let ws: Workshop
    let mats: [Mat]
    let d3: Bool
    let step: Int
    let mod: String?
    var scene: String { "w:" + f.id + ":" + m.id + (d3 ? ":3d" : "") }
    var issues: [FCheck] { (cx.found + drawerRule(f, ws, mats)).filter { $0.level == "err" || $0.level == "warn" } }
    var sec: Int { let s = DzcState.shared.sec; return s >= 0 && s < m.sections.count ? s : -1 }
    /// Each section's left edge from the box's left, and the box's width.
    var starts: [Int] { var a: [Int] = []; var x = 0; for s in m.sections { a.append(x); x += s.w }; return a }
}

struct DzcWard: View {
    let app: AppModel
    let c: DzcWCtx
    var body: some View {
        let st = DzcState.shared, kit = KitOps.shared
        let pid = c.p.id, fid = c.f.id, step = c.step, mod = c.mod
        VStack(spacing: 0) {
            DzcWBoxBar(app: app, c: c)
            ZStack(alignment: .top) {
                if c.d3 {
                    Furniture3DPane(app: app, p: c.p, room: c.room, onPick: { key in DzcWOps.pick3D(c, key) })
                } else {
                    DzcWardCanvas(app: app, c: c)
                }
                DzcWCaption(c: c).padding(.top, 6)
                if st.teachOn { DzcTeach { st.teachOn = false } }
            }
            .frame(maxHeight: .infinity)
            DzcWBottom(app: app, c: c)
            DesignerBar(app: app, p: c.p, f: c.f) {
                DzcMiddle(canRedo: kit.canRedo(fid), d3: c.d3, onRedo: { kit.redo(pid, fid); Haptic.tick() }) { v in
                    Haptic.tick()
                    app.setTop(.wardrobe(pid: pid, fid: fid, step: step, sec: max(0, st.sec), d3: v, mod: mod))
                }
            }
        }
    }
}

/// A piece of several boxes: a chip each (the one being designed on); "?" for the gesture hint.
private struct DzcWBoxBar: View {
    let app: AppModel
    let c: DzcWCtx
    var body: some View {
        let ms = c.f.modules.filter { $0.type == "wardrobe" }
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if ms.count > 1 {
                        ForEach(Array(ms.enumerated()), id: \.element.id) { i, b in
                            let on = b.id == c.m.id
                            T("\(i + 1) · " + tr(boxRole(c.f, b)) + " \(b.w)", ui(13, 700, on ? G.solid : G.ink), lines: 1)
                                .padding(.horizontal, 12).frame(minHeight: 38)
                                .background(Capsule().fill(on ? G.ink : G.glass(0.6)))
                                .overlay(Capsule().strokeBorder(on ? G.ink : G.rim, lineWidth: 1))
                                .pressable(0.97) {
                                    let st = DzcState.shared
                                    KitOps.shared.sel = b.id; KitOps.shared.tick += 1
                                    st.sec = -1; st.front = nil; st.ticks = []
                                    if st.tool != "boxes" { st.tool = nil }
                                }
                                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                                .accessibilityIdentifier("pc.box\(i + 1)")
                        }
                    } else {
                        T(tr("dzc.secsN", ["n": c.m.sections.count, "w": c.m.w]), ui(13, 700, G.ink2), lines: 1)
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

private struct DzcWCaption: View {
    let c: DzcWCtx
    var body: some View {
        let st = DzcState.shared
        let d3 = c.d3 ? " · 3D" : ""
        if st.multi {
            let n = st.ticks.count
            DzcCaption(title: n > 0 ? tr("dzc.markedS", ["n": n]) : tr("dzc.t.multi"), sub: tr("dzc.markHintS") + d3, dark: true, onUp: {}) {
                st.multi = false; st.ticks = []; st.tool = nil
            }
        } else if c.sec >= 0, st.live?.kind != "move" {
            let i = c.sec, s = c.m.sections[i]
            if let fk = st.front, let fr = handleFronts(c.m).first(where: { $0.key == fk }) {
                DzcCaption(title: frontName(c.m, fr), sub: d3.isEmpty ? "" : "3D", up: tr("dzc.secN", ["n": i + 1]), onUp: { st.front = nil; st.tool = nil }) { DzcWOps.deselect() }
            } else {
                DzcCaption(title: tr("dzc.secN", ["n": i + 1]) + " · \(s.w) mm", sub: tr(boxRole(c.f, c.m)) + d3, onUp: {}) { DzcWOps.deselect() }
            }
        }
    }
}

/* ---------------- the drawing ---------------- */

struct DzcWardCanvas: View {
    let app: AppModel
    let c: DzcWCtx
    var body: some View {
        let st = DzcState.shared
        let shown = st.live?.preview.flatMap { pv in pv.modules.first { $0.id == c.m.id } } ?? c.m
        let lay = KLay(shown.w, outerH(shown, c.ws), 360, true)
        GeometryReader { geo in
            let cam = st.cams[c.scene] ?? DzcCam()
            let map = DzcMap(lay, geo.size, cam, top: 58, bottom: 6)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in DzcWDraw.all(ctx, map, c, shown) }
                    .allowsHitTesting(false)
                DzcTouch(act: DzcWOps.actions(app, c, map))
                DzcWA11y(c: c, m: shown, map: map)
                DzcWBubble(app: app, c: c, m: shown, map: map, size: geo.size)
                if !cam.fit {
                    DzcZoomPill(pct: Int((cam.z * 100).rounded())) { st.cams[c.scene] = DzcCam(); Haptic.tick() }
                        .position(x: geo.size.width / 2, y: geo.size.height - 24)
                }
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dzc.canvas")
    }
}

private struct DzcWA11y: View {
    let c: DzcWCtx
    let m: Module
    let map: DzcMap
    var body: some View {
        let starts = DzcWOps.starts(m)
        ForEach(Array(m.sections.enumerated()), id: \.offset) { i, s in
            let l = map.sx(starts[i]), r = map.sx(starts[i] + s.w), t = map.sy(outerH(m, c.ws)), b = map.sy(0)
            Rectangle().fill(Color.black.opacity(0.001))
                .frame(width: max(4, r - l), height: max(4, b - t))
                .position(x: (l + r) / 2, y: (t + b) / 2)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel(tr("dzc.secN", ["n": i + 1]) + " \(s.w)")
                .accessibilityAddTraits(c.sec == i ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("dzc.s\(i)")
        }
    }
}

/// The selected section's mm bubble (tap: type the width).
private struct DzcWBubble: View {
    let app: AppModel
    let c: DzcWCtx
    let m: Module
    let map: DzcMap
    let size: CGSize
    var body: some View {
        let st = DzcState.shared
        let i = c.sec
        if i >= 0, i < m.sections.count, !st.multi, st.front == nil, st.live?.kind != "move", m.sections.count > 1 {
            let lv = st.live
            let live = lv?.kind == "resize"
            let starts = DzcWOps.starts(m)
            let s = m.sections[i]
            let bx = min(size.width - 50, max(50, map.sx(starts[i] + s.w / 2)))
            let pid = c.p.id, fid = c.f.id, mid = m.id
            DzcBubble(text: (live && lv?.maxHit == true ? tr("dzc.max") + " " : "") + "\(s.w) mm", live: live, kbd: !live, warn: live && lv?.maxHit == true, id: "dzc.bubble") {
                app.sheet = .dzcNum(pid: pid, fid: fid, mid: mid, key: "w", sec: i)
            }
            .position(x: bx, y: map.sy(-150))
            if live, let j = lv?.takerSec, j >= 0, j < m.sections.count {
                T(tr("dzc.secN", ["n": j + 1]) + " \(lv?.tw0 ?? 0) → \(lv?.tw1 ?? 0)", num(12, 800, G.amberInk), lines: 1)
                    .padding(.horizontal, 9).frame(minHeight: 26)
                    .background(Capsule().fill(G.amberWash))
                    .overlay(Capsule().strokeBorder(G.amberInk.opacity(0.5), lineWidth: 1))
                    .position(x: min(size.width - 60, max(60, map.sx(starts[j] + m.sections[j].w / 2))), y: map.sy(outerH(m, c.ws) / 2))
                    .allowsHitTesting(false)
            }
        }
    }
}

enum DzcWDraw {
    static func rgb(_ mats: [Mat], _ id: String, _ fallback: String) -> Int { rgbOf(mats.first { $0.id == id }?.rgb ?? fallback) }

    static func all(_ ctx: GraphicsContext, _ map: DzcMap, _ c: DzcWCtx, _ m0: Module) {
        let st = DzcState.shared
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy); g.scaleBy(x: map.k, y: map.k)
        var m = m0
        m.elev = 0
        let front = rgb(c.mats, frontOf(c.f, m0), "#CDBFAE"), carcass = rgb(c.mats, c.f.mats.carcass, "#F5F5F2")
        let open = st.inside || (st.peek && c.sec >= 0) || (st.multi && st.tool == "in")
        g.line(PC.ink, CGPoint(x: map.lay.x0 - 10, y: map.lay.yF), CGPoint(x: map.lay.x(m.w) + 10, y: map.lay.yF), 2)
        drawWard(g, map.lay, m, m.x, c.ws, carcass, front, -1, !open, c.cx.bad, labels: true, edge: opensByEdge(c.f))
        let starts = DzcWOps.starts(m)
        wardDims(g, map.lay, starts + [m.w], m.w, outerH(m, c.ws), 0)
        let top = map.sy(outerH(m, c.ws)), bot = map.sy(0)
        // the dragged width's neighbour: amber
        if let lv = st.live, lv.kind == "resize", lv.takerSec >= 0, lv.takerSec < m.sections.count {
            let j = lv.takerSec
            let r = CGRect(x: map.sx(starts[j]), y: top, width: CGFloat(m.sections[j].w) * map.pxPerMm, height: bot - top)
            ctx.fill(Path(r), with: .color(PC.amber.opacity(0.16)))
            ctx.stroke(Path(r), with: .color(PC.amber), lineWidth: 2)
        }
        if st.multi {
            for (i, s) in m.sections.enumerated() {
                let on = st.ticks.contains("s\(i)")
                let l = map.sx(starts[i])
                if on {
                    let r = CGRect(x: l, y: top, width: CGFloat(s.w) * map.pxPerMm, height: bot - top)
                    ctx.fill(Path(r), with: .color(PC.cob.opacity(0.14))); ctx.stroke(Path(r), with: .color(PC.cob), lineWidth: 2)
                }
                let disc = Path(ellipseIn: CGRect(x: l + 5, y: top + 5, width: 20, height: 20))
                ctx.fill(disc, with: .color(on ? PC.cob : PC.white)); ctx.stroke(disc, with: .color(PC.cob), lineWidth: 1.6)
            }
            return
        }
        if let lv = st.live, lv.kind == "move", lv.sec >= 0, lv.slot >= 0, lv.slot < m.sections.count {
            // the lifted section: its new place dashed, its outline under the finger
            let s = m.sections[lv.slot]
            let slot = CGRect(x: map.sx(starts[lv.slot]), y: top, width: CGFloat(s.w) * map.pxPerMm, height: bot - top)
            ctx.fill(Path(slot), with: .color(PC.cob.opacity(0.12)))
            ctx.stroke(Path(slot), with: .color(PC.cob), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            let gr = CGRect(x: map.sx(lv.gx), y: top - 14, width: CGFloat(s.w) * map.pxPerMm, height: bot - top)
            ctx.fill(Path(roundedRect: gr.offsetBy(dx: 6, dy: 8), cornerRadius: 4), with: .color(Color.black.opacity(0.12)))
            ctx.stroke(Path(roundedRect: gr, cornerRadius: 4), with: .color(lv.overDel ? PC.red : PC.cob), lineWidth: 3)
            return
        }
        let i = c.sec
        guard i >= 0, i < m.sections.count else { return }
        let s = m.sections[i]
        let l = map.sx(starts[i]), r = map.sx(starts[i] + s.w)
        ctx.stroke(Path(CGRect(x: l - 1, y: top - 1, width: r - l + 2, height: bot - top + 2)), with: .color(PC.cob), style: StrokeStyle(lineWidth: 2.6, dash: st.front == nil ? [] : [5, 4]))
        if let fk = st.front, let fb = wardFrontBoxes(m, c.ws).first(where: { $0.f.key == fk }) {
            let fr = CGRect(x: map.sx(fb.x0 - m.x), y: map.sy(fb.y1), width: CGFloat(fb.x1 - fb.x0) * map.pxPerMm, height: CGFloat(fb.y1 - fb.y0) * map.pxPerMm)
            ctx.fill(Path(fr), with: .color(PC.cob.opacity(0.16)))
            ctx.stroke(Path(fr), with: .color(PC.cob), lineWidth: 2.4)
            return
        }
        if let lv = st.live, lv.kind == "resize" {
            for v in lv.cands {
                let x = map.sx(starts[i] + v), on = v == s.w
                ctx.line(on ? PC.cob : PC.ink3, CGPoint(x: x, y: bot + 3), CGPoint(x: x, y: bot + (on ? 14 : 9)), on ? 2 : 1.2)
            }
        }
        if i < m.sections.count - 1 { DzcKDraw.handle(ctx, CGRect(x: r - 7, y: (top + bot) / 2 - 22, width: 14, height: 44), vertical: true) }
    }
}

/* ---------------- what the touches and tools do ---------------- */

enum DzcWOps {
    static func starts(_ m: Module) -> [Int] { var a: [Int] = []; var x = 0; for s in m.sections { a.append(x); x += s.w }; return a }

    /// The section under point pt (-1 none).
    static func hit(_ c: DzcWCtx, _ map: DzcMap, _ pt: CGPoint) -> Int {
        let u = map.mmX(pt.x), z = map.mmY(pt.y)
        if z < -280 || z > outerH(c.m, c.ws) + 60 { return -1 }
        var x = 0
        for (i, s) in c.m.sections.enumerated() {
            if u >= x && u < x + s.w { return i }
            x += s.w
        }
        return -1
    }

    static func hitFront(_ c: DzcWCtx, _ map: DzcMap, _ i: Int, _ pt: CGPoint) -> String? {
        var b = c.m
        b.elev = 0
        let u = map.mmX(pt.x) + c.m.x, z = map.mmY(pt.y)
        let fb = wardFrontBoxes(b, c.ws).first(where: { $0.f.sec == i && u >= $0.x0 - 4 && u <= $0.x1 + 4 && z >= $0.y0 - 4 && z <= $0.y1 + 4 })
        return fb?.f.key
    }

    static func deselect() {
        let st = DzcState.shared
        st.sec = -1; st.front = nil; st.peek = false; st.scope = "one"
        if let t = st.tool, !["secs", "decor", "handle", "checks", "plinth", "doorType", "boxes"].contains(t) { st.tool = nil }
    }

    static func select(_ c: DzcWCtx, _ i: Int) {
        let st = DzcState.shared
        st.sec = i; st.front = nil; st.scope = "one"
        st.peek = st.tool == "in"
        let ids = tools(c, i).map(\.id)
        if let t = st.tool, !ids.contains(t) { st.tool = nil; st.peek = false }
        if !st.taught { st.startTeach() }
    }

    static func actions(_ app: AppModel, _ c: DzcWCtx, _ map: DzcMap) -> DzcTouchActions {
        var a = DzcTouchActions()
        a.tap = { pt in tap(c, map, pt) }
        a.panBegan = { pt in panBegan(c, map, pt) }
        a.panMoved = { pt, tr in panMoved(c, map, pt, tr) }
        a.panEnded = { cancel in panEnded(app, c, cancel) }
        a.longBegan = { pt in longBegan(c, map, pt) }
        a.longMoved = { pt, win in longMoved(c, map, pt, win) }
        a.longEnded = { _, cancel in longEnded(app, c, cancel) }
        a.pinch = { state, scale, pt in DzcWOps.pinch(c, map, state, scale, pt) }
        return a
    }

    static func tap(_ c: DzcWCtx, _ map: DzcMap, _ pt: CGPoint) {
        let st = DzcState.shared
        if st.teachOn { st.teachOn = false; return }
        let now = Date()
        if let lt = st.lastTap, now.timeIntervalSince(lt.t) < 0.32, hypot(lt.p.x - pt.x, lt.p.y - pt.y) < 26 {
            st.lastTap = nil
            withAnimation(.easeOut(duration: 0.22)) { st.cams[c.scene] = DzcCam() }
            return
        }
        st.lastTap = (now, pt)
        let i = hit(c, map, pt)
        if i < 0 { if st.sec >= 0 || st.tool != nil { deselect() }; return }
        if st.multi {
            let k = "s\(i)"
            if st.ticks.contains(k) { st.ticks.remove(k) } else { st.ticks.insert(k) }
            Haptic.tick()
            return
        }
        if c.sec == i {
            if !st.peek && !st.inside && c.m.slide == nil, let k = hitFront(c, map, i, pt) {
                st.front = st.front == k ? nil : k
                st.scope = "one"
                if let t = st.tool, !tools(c, i).map(\.id).contains(t) { st.tool = nil }
            }
            return
        }
        select(c, i)
    }

    static func panBegan(_ c: DzcWCtx, _ map: DzcMap, _ pt: CGPoint) {
        let st = DzcState.shared
        if st.live?.kind == "pinch" || st.live?.kind == "move" { return }
        let i = c.sec
        if !st.multi && st.front == nil && i >= 0 && i < c.m.sections.count - 1 {
            let r = map.sx(c.starts[i] + c.m.sections[i].w), mid = (map.sy(outerH(c.m, c.ws)) + map.sy(0)) / 2
            if abs(pt.x - r) < 24 && abs(pt.y - mid) < 36 {
                var lv = DzcLive(kind: "resize", mid: c.m.id, sec: i)
                lv.w = c.m.sections[i].w
                st.live = lv
                return
            }
        }
        var lv = DzcLive(kind: "pan")
        lv.cam0 = st.cams[c.scene] ?? DzcCam()
        st.live = lv
    }

    /// The piece with box m changed to n (the preview).
    static func with(_ f: Furniture, _ n: Module) -> Furniture {
        var g = f
        g.modules = f.modules.map { $0.id == n.id ? n : $0 }
        return g
    }

    static func panMoved(_ c: DzcWCtx, _ map: DzcMap, _ pt: CGPoint, _ tr: CGSize) {
        let st = DzcState.shared
        guard var lv = st.live else { return }
        switch lv.kind {
        case "resize":
            let i = lv.sec
            guard i >= 0, i < c.m.sections.count else { return }
            let raw = map.mmX(pt.x) - c.starts[i]
            let mx = dzcSecMax(c.m, i)
            var cands = DZC_SNAP.filter { $0 >= 300 && $0 <= mx }
            if !cands.contains(mx) && mx <= 1200 { cands.append(mx) }
            if !cands.contains(c.m.sections[i].w) { cands.append(c.m.sections[i].w) }
            cands.sort()
            let nw = dzcSnapW(raw, cands, fine: map.fine, lo: DZC_SEC_MIN, hi: mx)
            let hit = raw > mx + 60
            if hit && !lv.maxHit { Haptic.warn() }
            lv.maxHit = hit; lv.cands = cands
            let r = dzcSecResize(c.m, i, nw)
            if r.ok {
                lv.w = nw
                lv.preview = with(c.f, r.m)
                lv.takerSec = r.taker; lv.tw0 = c.m.sections[max(0, r.taker)].w; lv.tw1 = r.w1
            }
            st.live = lv
        case "pan":
            var cam = lv.cam0
            cam.dx += tr.width; cam.dy += tr.height
            st.cams[c.scene] = cam
        default: break
        }
    }

    static func panEnded(_ app: AppModel, _ c: DzcWCtx, _ cancel: Bool) {
        let st = DzcState.shared
        guard let lv = st.live else { return }
        if lv.kind == "resize" {
            st.live = nil
            if !cancel && lv.sec >= 0 && lv.sec < c.m.sections.count && lv.w != c.m.sections[lv.sec].w { dzcCommitSecW(app, c.p, c.f, c.m.id, lv.sec, lv.w) }
        } else if lv.kind == "pan" {
            st.live = nil
        }
    }

    static func longBegan(_ c: DzcWCtx, _ map: DzcMap, _ pt: CGPoint) {
        let st = DzcState.shared
        if st.multi || c.m.sections.count < 2 || st.live?.kind == "pinch" || st.live?.kind == "resize" { return }
        let i = hit(c, map, pt)
        guard i >= 0 else { return }
        st.sec = i; st.front = nil; st.tool = nil; st.peek = false
        var lv = DzcLive(kind: "move", mid: c.m.id, sec: i)
        lv.gx = c.starts[i]; lv.grab = map.mmX(pt.x) - c.starts[i]; lv.slot = i; lv.slot0 = i
        lv.preview = c.f
        st.live = lv
        Haptic.tick()
    }

    static func longMoved(_ c: DzcWCtx, _ map: DzcMap, _ pt: CGPoint, _ win: CGPoint) {
        let st = DzcState.shared
        guard var lv = st.live, lv.kind == "move" else { return }
        lv.gx = map.mmX(pt.x) - lv.grab
        let slot = dzcSecSlot(c.m, lv.sec, gx: lv.gx)
        if slot != lv.slot {
            lv.slot = slot
            lv.preview = with(c.f, dzcSecMove(c.m, lv.sec, to: slot))
        }
        let over = st.delFrame.insetBy(dx: -8, dy: -16).contains(win)
        if over && !lv.overDel { Haptic.warn() }
        lv.overDel = over
        st.live = lv
    }

    static func longEnded(_ app: AppModel, _ c: DzcWCtx, _ cancel: Bool) {
        let st = DzcState.shared
        guard let lv = st.live, lv.kind == "move" else { return }
        st.live = nil
        if cancel { return }
        Haptic.tick()
        let pid = c.p.id, fid = c.f.id, i = lv.sec
        if lv.overDel {
            guard dzcSecDelete(c.m, i) != nil else { dzcWarn(app, "dzc.lastSec"); return }
            dzcWardChange(pid, fid) { dzcSecDelete($0, i) ?? $0 }
            st.sec = -1; st.tool = nil
            app.say("dzc.secDeleted", ["n": i + 1], action: "common.undo") { KitOps.shared.undo(pid, fid); Haptic.tick() }
        } else if lv.slot != lv.slot0 {
            let to = lv.slot
            dzcWardChange(pid, fid) { dzcSecMove($0, i, to: to) }
            st.sec = to
            app.say("dzc.secMoved", ["n": i + 1, "v": to + 1, "a": to + 1], action: "common.undo") { KitOps.shared.undo(pid, fid); Haptic.tick() }
        }
    }

    static func pinch(_ c: DzcWCtx, _ map: DzcMap, _ state: UIGestureRecognizer.State, _ scale: CGFloat, _ pt: CGPoint) {
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

    /// A tap in the 3D on "<box id>:s<i>:<front>": that box and section, a second tap its front, a third opens it.
    static func pick3D(_ c: DzcWCtx, _ key: String) -> Bool {
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count >= 2, let b = c.f.modules.first(where: { $0.id == parts[0] && $0.type == "wardrobe" }) else { return false }
        let st = DzcState.shared
        let sk = parts[1]
        guard sk.hasPrefix("s"), let i = Int(sk.dropFirst()) else { return false }
        let fk = parts.dropFirst().joined(separator: ":")
        if b.id != c.m.id { KitOps.shared.sel = b.id; KitOps.shared.tick += 1; st.sec = i; st.front = nil; return true }
        if st.sec == i {
            if st.front == fk { return false }
            st.front = fk
            return true
        }
        select(c, i)
        return true
    }

    /* ---------------- the tools ---------------- */

    static func tl(_ id: String, _ key: String = "", icon: String = "", tone: String = "", on: Bool = false, badge: Int? = nil) -> DzcTool {
        DzcTool(id: id, label: tr("dzc.t." + (key.isEmpty ? id : key)), icon: icon, badge: badge, tone: tone, on: on)
    }

    static func tools(_ c: DzcWCtx, _ sec: Int) -> [DzcTool] {
        let st = DzcState.shared
        let m = c.m
        if st.multi {
            return [tl("type"), tl("handle"), tl("in"), tl("mdel", "del", icon: "del", tone: "red"), tl("mdone", "done", icon: "done", tone: "pri")]
        }
        guard sec >= 0, sec < m.sections.count else {
            var a = [tl("secs"), tl("size")]
            if c.f.type.isEmpty { a.append(tl("doorType", icon: "door")) }
            a += [tl("decor"), tl("handle"), tl("see", on: st.inside), tl("multi"), tl("checks", badge: c.issues.count), tl("plinth")]
            if c.f.type == "stenka" { a.append(tl("boxes")) }
            if c.f.type == "gorka" { a.append(tl("gorka")) }
            a += [tl("place"), tl("mats"), tl("more")]
            return a
        }
        let s = m.sections[sec]
        let doors = s.fronts.kind == "door" && m.slide == nil
        if let fk = st.front {
            var a = [tl("handle")]
            if fk.contains(":f") && doors && s.fronts.n == 1 { a.append(tl("hinge")) }
            if fk.contains(":f") && doors { a.append(tl("soft")) }
            a.append(tl("selUp", "selUpS"))
            return a
        }
        var a: [DzcTool] = []
        if m.sections.count > 1 { a.append(tl("width")) }
        a.append(tl("in"))
        if m.slide == nil { a.append(tl("type", icon: "door")) }
        a.append(tl("decor"))
        if !handleFronts(m).filter({ $0.sec == sec }).isEmpty { a.append(tl("handle")) }
        if doors { a.append(tl("soft")) }
        if doors && s.fronts.n == 1 { a.append(tl("hinge")) }
        a.append(tl("copy"))
        if m.sections.count > 1 { a.append(tl("move")) }
        a += [tl("more"), tl("del", icon: "del", tone: "red")]
        return a
    }

    static func toolTap(_ app: AppModel, _ c: DzcWCtx, _ id: String) {
        let st = DzcState.shared
        let pid = c.p.id, fid = c.f.id
        Haptic.tick()
        switch id {
        case "multi": st.multi = true; st.ticks = c.sec >= 0 ? ["s\(c.sec)"] : []; st.sec = -1; st.front = nil; st.tool = nil; st.peek = false
        case "mdone": st.multi = false; st.ticks = []; st.tool = nil
        case "mdel": deleteMarked(app, c)
        case "see": st.inside.toggle()
        case "copy": copy(app, c)
        case "del": delete(app, c)
        case "selUp": st.front = nil; st.tool = nil
        case "size": app.sheet = .dzcMore(pid: pid, fid: fid, tab: "size")
        case "place": app.sheet = .dzcMore(pid: pid, fid: fid, tab: "place")
        case "mats": app.sheet = .dzcMore(pid: pid, fid: fid, tab: "mats")
        case "boxes": app.sheet = .dzcMore(pid: pid, fid: fid, tab: "boxes")
        case "gorka": app.sheet = .dzcMore(pid: pid, fid: fid, tab: "gorka")
        case "more": app.sheet = .dzcMore(pid: pid, fid: fid, tab: c.sec >= 0 ? "doors" : "size")
        default:
            st.tool = id; st.scope = "one"
            st.peek = id == "in" && c.sec >= 0
        }
    }

    static func said(_ app: AppModel, _ c: DzcWCtx, _ key: String, _ vars: [String: Any] = [:]) { dzcSaid(app, c.p.id, c.f.id, key, vars) }

    /// The selected or marked sections.
    static func targets(_ c: DzcWCtx) -> [Int] {
        let st = DzcState.shared
        if st.multi { return st.ticks.compactMap { Int($0.dropFirst()) }.filter { $0 >= 0 && $0 < c.m.sections.count }.sorted() }
        return c.sec >= 0 ? [c.sec] : []
    }

    static func delete(_ app: AppModel, _ c: DzcWCtx) {
        let i = c.sec
        guard i >= 0 else { return }
        guard dzcSecDelete(c.m, i) != nil else { dzcWarn(app, "dzc.lastSec"); return }
        dzcWardChange(c.p.id, c.f.id) { dzcSecDelete($0, i) ?? $0 }
        DzcState.shared.sec = -1; DzcState.shared.tool = nil
        said(app, c, "dzc.secDeleted", ["n": i + 1])
    }

    static func deleteMarked(_ app: AppModel, _ c: DzcWCtx) {
        let ids = targets(c).sorted(by: >)
        if ids.isEmpty { dzcWarn(app, "dzc.markFirstS"); return }
        if ids.count >= c.m.sections.count { dzcWarn(app, "dzc.lastSec"); return }
        dzcWardChange(c.p.id, c.f.id) { m in ids.reduce(m) { x, i in dzcSecDelete(x, i) ?? x } }
        DzcState.shared.ticks = []
        said(app, c, "dzc.secsDeleted", ["n": ids.count])
    }

    static func copy(_ app: AppModel, _ c: DzcWCtx) {
        let i = c.sec
        guard i >= 0 else { return }
        guard let n = dzcSecCopy(c.m, i) else { dzcWarn(app, "dzc.noCopySec"); return }
        dzcWardChange(c.p.id, c.f.id) { dzcSecCopy($0, i) ?? $0 }
        DzcState.shared.sec = i + 1
        said(app, c, "dzc.secCopiedN", ["n": n.sections.count, "w": n.sections.first?.w ?? 0])
    }

    static func step(_ app: AppModel, _ c: DzcWCtx, _ d: Int) {
        let i = c.sec, j = i + d
        guard i >= 0, j >= 0, j < c.m.sections.count else { dzcWarn(app, "dzc.cantMove"); return }
        dzcWardChange(c.p.id, c.f.id) { dzcSecMove($0, i, to: j) }
        DzcState.shared.sec = j
        said(app, c, d < 0 ? "dzc.secL" : "dzc.secR", ["n": i + 1])
    }
}

/* ---------------- the bottom ---------------- */

private struct DzcWBottom: View {
    let app: AppModel
    let c: DzcWCtx
    var body: some View {
        let st = DzcState.shared
        VStack(spacing: 0) {
            if st.live?.kind == "move" {
                DzcDelZone(on: st.live?.overDel == true)
            } else if let t = st.tool {
                DzcWOptions(app: app, c: c, tool: t)
            } else {
                DzcSlider(tools: DzcWOps.tools(c, c.sec)) { id in DzcWOps.toolTap(app, c, id) }
            }
        }
        .frame(maxWidth: .infinity)
        .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) } }
        .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 1) }
        // toasts rise above the slider, not over it
        .bottomBar()
    }
}

private struct DzcWOptions: View {
    let app: AppModel
    let c: DzcWCtx
    let tool: String
    var body: some View {
        let st = DzcState.shared
        let back = { st.tool = nil; st.peek = false; st.scope = "one" }
        switch tool {
        case "secs": DzcWSecs(app: app, c: c, onBack: back)
        case "doorType": DzcWDoorType(app: app, c: c, onBack: back)
        case "decor": DzcWDecor(app: app, c: c, onBack: back)
        case "handle": DzcWHandle(app: app, c: c, onBack: back)
        case "soft": DzcWSoft(app: app, c: c, onBack: back)
        case "hinge": DzcWHinge(app: app, c: c, onBack: back)
        case "type": DzcWType(app: app, c: c, onBack: back)
        case "width": DzcWWidth(app: app, c: c, onBack: back)
        case "in": DzcWIn(app: app, c: c, onBack: back)
        case "plinth": DzcWPlinth(app: app, c: c, onBack: back)
        case "checks": DzcWChecks(app: app, c: c, onBack: back)
        case "move": DzcOptRow(title: tr("dzc.t.move"), sub: c.sec >= 0 ? tr("dzc.secN", ["n": c.sec + 1]) : "", onBack: back) {
            DzcOpt(label: tr("dzc.left"), glyph: "left", id: "dzc.o.left") { DzcWOps.step(app, c, -1) }
            DzcOpt(label: tr("dzc.right"), glyph: "right", id: "dzc.o.right") { DzcWOps.step(app, c, 1) }
            DzcNote(text: tr("dzc.moveHint"))
        }
        default: DzcOptRow(title: tool, onBack: back) { EmptyView() }
        }
    }
}

/// Bo‘limlar: how many sections, each the same width.
private struct DzcWSecs: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let m = c.m, ws = c.ws
        DzcOptRow(title: tr("dzc.t.secs"), sub: tr("dzc.secsSub"), onBack: onBack) {
            ForEach(1...8, id: \.self) { n in
                DzcOpt(label: tr("dzc.nPcs", ["n": n]) + " · \(m.w / n)", on: m.sections.count == n, id: "dzc.secs.\(n)") {
                    if n == m.sections.count { return }
                    dzcWardChange(c.p.id, c.f.id) { dzcSecCount($0, n, ws) }
                    DzcState.shared.sec = -1
                    DzcWOps.said(app, c, "dzc.secsTo", ["a": m.sections.count, "b": n])
                }
            }
        }
    }
}

/// Eshik turi: hinged doors on each section or sliding doors over the whole front (a wardrobe's), how many sliding ones.
private struct DzcWDoorType: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let m = c.m, t = c.ws.t
        DzcOptRow(title: tr("dzc.t.doorType"), sub: "", onBack: onBack) {
            DzcOpt(label: tr("wd.hingedT"), glyph: "hinged", on: m.slide == nil, id: "dzc.dt.hinged") { set(false) }
            DzcOpt(label: tr("wd.slideT"), glyph: "slide", on: m.slide != nil, id: "dzc.dt.slide") { set(true) }
            if let sl = m.slide {
                DzcStepper(label: tr("wd.slideN"), v: sl.n, lo: 2, hi: 4, id: "dzc.dt.n") { v in
                    dzcWardChange(c.p.id, c.f.id) { x in var o = x; var y = sl; y.n = v; o.slide = y; return o }
                    DzcWOps.said(app, c, "ux.changed")
                }
            }
        }
        .id(t)
    }
    private func set(_ slide: Bool) {
        if (c.m.slide != nil) == slide { return }
        let t = c.ws.t
        dzcWardChange(c.p.id, c.f.id) { x in var n = x; n.slide = slide ? Slide(slideDoorsFor(slideOpening(x, t).0)) : nil; return n }
        DzcWOps.said(app, c, "ux.changed")
    }
}

/// Fasad: this box (a piece of several) or the whole piece.
private struct DzcWDecor: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let many = c.f.modules.filter { $0.type == "wardrobe" }.count > 1
        let cur = colourOf(frontOf(c.f, c.m))
        DzcOptRow(title: tr("dzc.t.decor"), sub: many ? "" : tr("dzc.wholeP"), scopes: many ? [("one", tr("dzc.sc.box")), ("all", tr("dzc.sc.all"))] : [], onBack: onBack) {
            ForEach(DZC_FRONTS, id: \.self) { s in
                DzcSwatch(rgb: s.rgb, label: dzcFrontName(s.key), wood: s.wood, on: cur == s.key, id: "dzc.sw." + s.key) { set(s.key, many) }
            }
        }
    }
    private func set(_ key: String, _ many: Bool) {
        let board = dzcBoard(c.f, key), name = dzcFrontName(key), mid = c.m.id
        if many && DzcState.shared.scope == "one" {
            KitOps.shared.change(c.p.id, c.f.id) { withLook(dzcFrontOne($0, [mid], board)) { $0 } }
            DzcWOps.said(app, c, "dzc.decorOne", ["c": name, "d": name, "m": tr(boxRole(c.f, c.m))])
        } else {
            KitOps.shared.change(c.p.id, c.f.id) { withLook(dzcFrontAll($0, board)) { $0 } }
            DzcWOps.said(app, c, "dzc.decorAll", ["c": name, "d": name])
        }
    }
}

/// Tutqich: a door or a section with a handle or a push latch ("Faqat shu"); the type of the whole piece.
private struct DzcWHandle: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let st = DzcState.shared
        let has = c.sec >= 0 && !st.multi
        let whole = (!has && !st.multi) || st.scope == "all"
        DzcOptRow(title: tr("dzc.t.handle"), sub: whole ? tr("dzc.wholeP") : tr("dzc.typeWhole"), scopes: has ? [("one", tr("dzc.sc.one")), ("all", tr("dzc.sc.all"))] : [], onBack: onBack) {
            if whole {
                let cur = handleType(c.f)
                ForEach(["bar", "long", "knob", "push"], id: \.self) { k in
                    DzcOpt(label: tr("lk.h." + k), glyph: "h-" + k, on: cur == k, id: "dzc.h." + k) {
                        KitOps.shared.change(c.p.id, c.f.id) { withLook(withHandleType($0, k)) { $0 } }
                        DzcWOps.said(app, c, "dzc.handleAll", ["h": tr("lk.h." + k)])
                    }
                }
            } else {
                DzcOpt(label: tr("dzc.hOn"), glyph: "h-on", id: "dzc.h.on") { set(true) }
                DzcOpt(label: tr("dzc.hOff"), glyph: "h-off", id: "dzc.h.off") { set(false) }
            }
        }
    }
    private func set(_ on: Bool) {
        let st = DzcState.shared
        let keys: [String]
        if let fk = st.front, !st.multi { keys = [fk] }
        else {
            let secs = Set(DzcWOps.targets(c))
            keys = handleFronts(c.m).filter { secs.contains($0.sec) }.map(\.key)
        }
        if keys.isEmpty { dzcWarn(app, "dzc.markFirstS"); return }
        dzcWardChange(c.p.id, c.f.id) { m in keys.reduce(m) { x, k in withHandle(x, k, on) } }
        DzcWOps.said(app, c, on ? "dzc.hOnN" : "dzc.hOffN", ["n": keys.count])
    }
}

private struct DzcWSoft: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let i = max(0, c.sec)
        let on = softOf(c.m, i)
        DzcOptRow(title: tr("dzc.t.soft"), sub: tr("dzc.softSub"), scopes: [("one", tr("dzc.sc.one")), ("all", tr("dzc.sc.all"))], onBack: onBack) {
            DzcOpt(label: tr("dzc.on"), glyph: "soft", on: on, id: "dzc.soft.on") { set(true) }
            DzcOpt(label: tr("dzc.off"), glyph: "x", on: !on, id: "dzc.soft.off") { set(false) }
        }
    }
    private func set(_ on: Bool) {
        let i = c.sec
        if DzcState.shared.scope == "all" {
            KitOps.shared.change(c.p.id, c.f.id) { x in var y = x; y.modules = x.modules.map { $0.type == "wardrobe" ? softAll($0, on) : $0 }; return y }
            DzcWOps.said(app, c, on ? "dzc.softOn" : "dzc.softOff", ["m": tr("dzc.everywhere")])
            return
        }
        guard i >= 0 else { return }
        dzcWardChange(c.p.id, c.f.id) { withSoft($0, i, on) }
        DzcWOps.said(app, c, on ? "dzc.softOn" : "dzc.softOff", ["m": tr("dzc.secN", ["n": i + 1])])
    }
}

private struct DzcWHinge: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let i = max(0, c.sec)
        let cur = hingeRight(c.m, i) ? "R" : "L"
        DzcOptRow(title: tr("dzc.t.hinge"), sub: tr("dzc.secN", ["n": i + 1]), onBack: onBack) {
            DzcOpt(label: tr("dzc.sideL"), glyph: "hg-L", on: cur == "L", id: "dzc.hinge.L") { set("L") }
            DzcOpt(label: tr("dzc.sideR"), glyph: "hg-R", on: cur == "R", id: "dzc.hinge.R") { set("R") }
        }
    }
    private func set(_ h: String) {
        let i = c.sec
        guard i >= 0 else { return }
        dzcSecChange(c.p.id, c.f.id, i) { s in var n = s; n.hinge = h; return n }
        DzcWOps.said(app, c, h == "L" ? "dzc.hingeL" : "dzc.hingeR", ["m": tr("dzc.secN", ["n": i + 1])])
    }
}

/// Turi: a section's doors — two, one, open, mirrored, glass.
private struct DzcWType: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let ts = DzcWOps.targets(c)
        let cur = ts.count == 1 ? dzcSecType(c.m.sections[ts[0]]) : ""
        DzcOptRow(title: tr("dzc.t.type"), sub: ts.count > 1 ? tr("dzc.nMarkedS", ["n": ts.count]) : "", onBack: onBack) {
            ForEach(["d2", "d1", "open", "mirror", "glass"], id: \.self) { k in
                DzcOpt(label: tr("dzc.sty." + k), glyph: k == "open" ? "sopen" : k, on: cur == k, id: "dzc.sty." + k) { set(k, ts) }
            }
        }
    }
    private func set(_ k: String, _ ts: [Int]) {
        if ts.isEmpty { dzcWarn(app, "dzc.markFirstS"); return }
        dzcWardChange(c.p.id, c.f.id) { m in
            var n = m
            n.sections = m.sections.enumerated().map { i, s in ts.contains(i) ? dzcSecRetype(s, k) : s }
            return n
        }
        DzcWOps.said(app, c, "dzc.typed", ["t": tr("dzc.sty." + k), "n": ts.count])
    }
}

private struct DzcWWidth: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let i = c.sec
        if i >= 0 {
            let s = c.m.sections[i], mx = dzcSecMax(c.m, i)
            let list = DZC_SNAP.filter { $0 >= 300 && $0 <= mx }
            let pid = c.p.id, fid = c.f.id, mid = c.m.id
            DzcOptRow(title: tr("dzc.t.width"), sub: tr("dzc.wSub", ["v": s.w, "m": mx]), onBack: onBack) {
                ForEach(list, id: \.self) { v in
                    DzcOpt(label: "\(v)", on: s.w == v, id: "dzc.w.\(v)") { dzcCommitSecW(app, c.p, c.f, mid, i, v) }
                }
                DzcOpt(label: tr("dzc.type"), glyph: "kbd", id: "dzc.w.kbd") { app.sheet = .dzcNum(pid: pid, fid: fid, mid: mid, key: "w", sec: i) }
            }
        }
    }
}

/// Ichki: a rail, shelves and drawers of the selected (or marked) sections, more inside parts, empty, spread evenly.
private struct DzcWIn: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let ts = DzcWOps.targets(c)
        let first = ts.first.map { c.m.sections[$0] }
        let rail: Bool = first.map { s in s.inserts.contains(where: { $0.kind == "rail" }) } ?? false
        let sh: Int = first.map { s in s.inserts.filter { $0.kind == "shelf" }.count } ?? 0
        let dr: Int = first.map { s in s.inserts.filter { $0.kind == "drawer" }.count } ?? 0
        let sub: String = ts.count > 1 ? tr("dzc.nMarkedS", ["n": ts.count]) : (ts.first.map { tr("dzc.secN", ["n": $0 + 1]) } ?? tr("dzc.markFirstS"))
        let pid = c.p.id, fid = c.f.id
        DzcOptRow(title: tr("dzc.t.in"), sub: sub, onBack: onBack) {
            DzcOpt(label: tr("wi.rail") + (rail ? " ✓" : " +"), glyph: "rail", on: rail, id: "dzc.in.rail") { toggleRail(ts, rail) }
            DzcStepper(label: tr("dzc.shelves"), v: sh, lo: 0, hi: 8, id: "dzc.in.shelf") { n in setCount(ts, "shelf", n) }
            DzcStepper(label: tr("dzc.drawers"), v: dr, lo: 0, hi: 5, id: "dzc.in.drawer") { n in setCount(ts, "drawer", n) }
            if ts.count == 1, let i = ts.first {
                DzcOpt(label: tr("wd.more"), glyph: "add", id: "dzc.in.more") { app.sheet = .wMore(pid: pid, fid: fid, sec: i) }
                DzcOpt(label: tr("dzc.inList"), glyph: "in", id: "dzc.in.list") { app.sheet = .dzcMore(pid: pid, fid: fid, tab: "inside") }
            }
            DzcOpt(label: tr("wd.spread"), glyph: "in", id: "dzc.in.spread") { spread(ts) }
            DzcOpt(label: tr("dzc.empty"), glyph: "x", id: "dzc.in.clear") { clear(ts) }
        }
    }

    private func toggleRail(_ ts: [Int], _ on: Bool) {
        if ts.isEmpty { dzcWarn(app, "dzc.markFirstS"); return }
        let t = c.ws.t
        dzcWardChange(c.p.id, c.f.id) { m in
            var n = m
            let ih = wardInnerH(m, t)
            for i in ts where i < n.sections.count {
                if on { n.sections[i].inserts.removeAll { $0.kind == "rail" } }
                else { n.sections[i].inserts.append(Insert("rail", pos: nextPos("rail", n.sections[i], ih, t))) }
            }
            return n
        }
        DzcWOps.said(app, c, on ? "dzc.railOff" : "dzc.railOn")
    }

    private func setCount(_ ts: [Int], _ kind: String, _ q: Int) {
        if ts.isEmpty { dzcWarn(app, "dzc.markFirstS"); return }
        let t = c.ws.t
        dzcWardChange(c.p.id, c.f.id) { m in
            var n = m
            let ih = wardInnerH(m, t)
            for i in ts where i < n.sections.count {
                var s = n.sections[i]
                var have = s.inserts.filter { $0.kind == kind }.count
                while have > q, let k = s.inserts.lastIndex(where: { $0.kind == kind }) { s.inserts.remove(at: k); have -= 1 }
                while have < q {
                    s.inserts.append(Insert(kind, pos: nextPos(kind, s, ih, t), h: blockH(Insert(kind))))
                    have += 1
                }
                if kind == "shelf" { s = spreadShelves(s, ih, t) }
                n.sections[i] = s
            }
            return n
        }
        DzcWOps.said(app, c, kind == "shelf" ? "dzc.shelvesN" : "dzc.drawersN", ["n": q])
    }

    private func spread(_ ts: [Int]) {
        if ts.isEmpty { dzcWarn(app, "dzc.markFirstS"); return }
        let t = c.ws.t
        dzcWardChange(c.p.id, c.f.id) { m in
            var n = m
            let ih = wardInnerH(m, t)
            for i in ts where i < n.sections.count { n.sections[i] = spreadShelves(n.sections[i], ih, t) }
            return n
        }
        DzcWOps.said(app, c, "ux.changed")
    }

    private func clear(_ ts: [Int]) {
        if ts.isEmpty { dzcWarn(app, "dzc.markFirstS"); return }
        dzcWardChange(c.p.id, c.f.id) { m in
            var n = m
            for i in ts where i < n.sections.count { n.sections[i].inserts = [] }
            return n
        }
        DzcWOps.said(app, c, "dzc.emptied", ["n": ts.count])
    }
}

/// Tsokol/oyoq: a plinth or legs and their height (the whole height stays).
private struct DzcWPlinth: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let m = c.m
        let kind = m.legs ? "legs" : "plinth"
        let h = m.legs ? legsOf(m, c.ws) : wardBase(m)
        let list = [60, 80, 100, 120, 150]
        if hung(m) {
            DzcOptRow(title: tr("dzc.t.plinth"), sub: tr("dzc.hung"), onBack: onBack) {
                DzcOpt(label: tr("dzc.hungMore"), glyph: "size", id: "dzc.base.hung") { app.sheet = .dzcMore(pid: c.p.id, fid: c.f.id, tab: "size") }
            }
        } else {
            DzcOptRow(title: tr("dzc.t.plinth"), sub: "\(h) mm", onBack: onBack) {
                DzcOpt(label: tr("dzc.base.plinth"), glyph: "plinth", on: kind == "plinth", id: "dzc.base.plinth") { set("plinth", h) }
                DzcOpt(label: tr("dzc.base.legs"), glyph: "legs", on: kind == "legs", id: "dzc.base.legs") { set("legs", m.legs ? h : c.ws.legH) }
                ForEach(list, id: \.self) { v in
                    DzcOpt(label: "\(v)", on: h == v, id: "dzc.base.\(v)") { set(kind, v) }
                }
            }
        }
    }
    private func set(_ k: String, _ h: Int) {
        let ws = c.ws
        dzcWardChange(c.p.id, c.f.id) { dzcWardBase($0, k, h, ws) }
        DzcWOps.said(app, c, "dzc.based", ["b": tr("dzc.base." + k), "v": h])
    }
}

private struct DzcWChecks: View {
    let app: AppModel
    let c: DzcWCtx
    let onBack: () -> Void
    var body: some View {
        let list = c.issues
        DzcOptRow(title: tr("dzc.t.checks"), sub: list.isEmpty ? tr("dzc.allOk") : tr("dzc.nIssues", ["n": list.count]), onBack: onBack) {
            if list.isEmpty { DzcOpt(label: tr("kt.allOk"), glyph: "done", id: "dzc.ck.ok") {} }
            ForEach(Array(list.enumerated()), id: \.offset) { i, ck in
                DzcOpt(label: checkText(ck, c.f), glyph: "checks", tone: ck.level == "err" ? "red" : "", id: "dzc.ck.\(i)") {
                    if let n = ck.vars["s"]?.base as? Int, n >= 1, n <= c.m.sections.count {
                        let st = DzcState.shared
                        st.tool = nil; st.sec = n - 1; st.front = nil
                    }
                }
                .frame(maxWidth: 280)
            }
        }
    }
}
