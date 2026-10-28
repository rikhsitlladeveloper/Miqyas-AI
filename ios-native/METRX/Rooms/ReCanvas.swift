import SwiftUI
import UIKit

/*
 * The room editor v2's drawing with its touches (room-editor mockup v2, approved 28 Oct 2026; vDown, vMove, vUp,
 * startSlide, doSlide, doEdge, dropTarget): the plan, one wall from inside, or the simple 3D. A tap selects a wall or
 * an item (or places the armed icon); dragging an item slides it along its wall with magnets at the corners and the
 * middle (at once in the openings step, after a 0,4 s hold in the editor, where a quick drag pans, two fingers zoom
 * and a double tap fits); an opening's edges on the front view resize it. An icon dragged from the row shows its
 * ghost on the nearest wall, which glows green.
 */

/// How the drawing is laid out in a size: the plan's mapping, its walls, the front view of a wall.
struct ReLayout {
    let g: ReRoomGeo
    let size: CGSize
    let map: ReMap
    let frames: [ReFrame]
    func frame(_ id: String) -> ReFrame? { frames.first { $0.id == id } }

    /// mode "ops": the openings step's card (pan: moved up for the floating card); "editor": below the caption.
    static func plan(_ g: ReRoomGeo, _ size: CGSize, ops: Bool, cam: ReCam) -> ReLayout {
        let box = ops ? CGRect(x: 0, y: 0, width: size.width, height: size.height) : CGRect(x: 0, y: 46, width: size.width, height: max(40, size.height - 52))
        let m = ReMap.fit(g, box, pad: ops ? 26 : 36, padX: ops ? 40 : 62, cam: cam)
        return ReLayout(g: g, size: size, map: m, frames: reFrames(g, m))
    }
}

/// The front view of wall id in size (the editor's big one, or the floating card's small one).
func reFrontOf(_ g: ReRoomGeo, _ id: String, _ size: CGSize, small: Bool, cam: ReCam) -> ReFront? {
    guard let w = g.wall(id) else { return nil }
    let lay = ReLayout.plan(g, CGSize(width: 400, height: 400), ops: true, cam: ReCam())
    let fl = lay.frame(id)?.fl ?? false
    let box = small ? CGRect(origin: .zero, size: size) : CGRect(x: 0, y: 46, width: size.width, height: max(40, size.height - 46 - 54))
    return ReFront.of(w, fl: fl, rh: g.hOf(id), box: box, small: small, cam: cam)
}

/// The drawing: plan, front or 3D of the host's room, with its touches.
struct ReCanvas: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    /// The openings step (no zoom, items slide at once) or the editor.
    let ops: Bool
    /// The openings step's plan moved up so the selected item stays above the floating card.
    var pan: CGFloat = 0
    @State private var lastTap: (Date, CGPoint)? = nil

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if let r = st.shown(h) {
                let g = reGeo(r)
                let items = reItems(r)
                let iss = Set(reRoomIssues(r, g).map(\.id))
                let view = ops ? "plan" : st.view
                ZStack(alignment: .topLeading) {
                    if view == "3d" {
                        let parts = reIsoParts(size, g, items, cam: st.cam("3d"), top: 46, sel: st.sel, issues: iss)
                        Canvas { ctx, _ in reDrawIso(ctx, parts) }
                        DzcTouch(act: isoActs(parts, size))
                    } else if view == "front", let fv = reFrontOf(g, st.fw, size, small: false, cam: st.cam("front")) {
                        Canvas { ctx, sz in
                            reDrawFront(ctx, sz, fv, items, sel: st.selItem, wallSel: st.selWall == st.fw, ghost: st.ghost, left: g.prev(st.fw), right: g.next(st.fw),
                                        caption: tr("re.frontCap", ["w": reWL(st.fw), "l": reLen(g.len(st.fw)), "h": reLen(g.hOf(st.fw))]), issues: iss, small: false)
                        }
                        DzcTouch(act: frontActs(fv, g, size))
                        ReFrontBubbles(app: app, st: st, h: h, fv: fv, g: g, small: false)
                    } else {
                        let lay = ReLayout.plan(g, size, ops: ops, cam: ops ? ReCam(z: 1, dx: 0, dy: pan) : st.cam("plan"))
                        let lk = planLook(g, iss)
                        Canvas { ctx, sz in reDrawPlan(ctx, sz, g, items, lay.map, lk, lenTxt: reLen) }
                        DzcTouch(act: planActs(lay))
                        RePlanBubbles(app: app, st: st, h: h, lay: lay, items: items, ghost: st.ghost)
                        ReIwBubbles(app: app, st: st, h: h, lay: lay)
                    }
                }
                .clipped()
            }
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { st.canvas = g.frame(in: .named("re")) }
                .onChange(of: g.frame(in: .named("re"))) { _, f in st.canvas = f }
        })
    }

    private func planLook(_ g: ReRoomGeo, _ iss: Set<String>) -> RePlanLook {
        var look = RePlanLook()
        look.selWall = st.selWall; look.selItem = st.selItem; look.arm = st.arm != nil
        look.hl = st.ghost?.wall ?? (st.pk?.mode == "new" ? st.pk?.wall : nil)
        look.ghost = st.ghost ?? (st.pk?.mode == "new" ? st.pkItem(h) : nil)
        look.mag = st.mag; look.small = ops; look.issues = iss
        look.showLen = st.dimLen; look.chain = !ops && st.dimChain
        look.areaTxt = !ops && st.dimArea ? reAreaLine(g) : nil
        look.selPiece = st.selPiece; look.newPiece = st.newPiece; look.glow = st.iwGlow
        if let id = st.selPiece, let r = st.shown(h), let p = r.inner.first(where: { $0.id == id }) { look.gaps = Array(iwSides(r, g.outer, p).values) }
        return look
    }

    /* ---------------- the plan's touches ---------------- */

    private func planActs(_ lay: ReLayout) -> DzcTouchActions {
        var a = DzcTouchActions()
        a.tap = { p in planTap(lay, p) }
        a.panBegan = { p in
            guard let r = h.room() else { return }
            if ops, let id = reHitItem(hits(lay, r), p) { beginSlide(id, lay, p, r) }
            // an inner wall: dragged at once in the openings step, or when already selected in the editor
            else if let pid = reHitBody(lay.g, lay.map, p), ops || st.selPiece == pid { st.iwDragBegin(pid, lay.map.mm(p), h) }
            else if !ops { st.live = ReLive(mode: "pan", cam0: st.cam("plan")) }
        }
        a.panMoved = { p, t in
            guard let lv = st.live else { return }
            if lv.mode == "iw" { st.iwDragMove(lay.map.mm(p)); return }
            if lv.mode == "slide" { slide(lay, p) }
            else if lv.mode == "pan" { var c = lv.cam0; c.dx += t.width; c.dy += t.height; st.cams["plan"] = c }
        }
        a.panEnded = { cancel in endLive(cancel) }
        a.longBegan = { p in
            guard let r = h.room() else { return }
            guard let id = reHitItem(hits(lay, r), p) else {
                // a held inner wall is lifted (the editor: 0,4 s, like the items)
                if let pid = reHitBody(lay.g, lay.map, p) { st.iwDragBegin(pid, lay.map.mm(p), h); st.live?.longPress = true }
                return
            }
            beginSlide(id, lay, p, r)
            st.live?.longPress = true
        }
        a.longMoved = { p, _ in
            if st.live?.mode == "iw" { st.iwDragMove(lay.map.mm(p)) }
            else if st.live?.mode == "slide" { slide(lay, p) }
        }
        a.longEnded = { _, cancel in endLive(cancel) }
        a.pinch = { state, scale, c in pinch(state, scale, c, "plan") }
        return a
    }

    private func hits(_ lay: ReLayout, _ r: Room) -> [ReHit] {
        reItems(r).compactMap { it in lay.frame(it.wall).map { rePlanHit(it, $0, lay.map.k, small: ops) } }
    }

    private func planTap(_ lay: ReLayout, _ p: CGPoint) {
        guard let r = h.room() else { return }
        if !ops, let lt = lastTap, Date().timeIntervalSince(lt.0) < 0.32, (lt.1 - p).len < 26 { lastTap = nil; st.cams["plan"] = ReCam(); Haptic.tick(); return }
        lastTap = (Date(), p)
        if let k = st.arm {
            if let w = reNearWall(lay.frames, p, 44) {
                let L = lay.g.len(w.id)
                let it = reNewItem(k, wall: w.id, centre: Int((w.t / lay.map.k).rounded()), wallL: L, roomH: lay.g.H)
                let m = reMagnet(it.along, L, Double(it.dist), Double(lay.map.k))
                st.placeAt(k, wall: w.id, centre: m.v + it.along / 2, how: "tap", app, h)
            } else { st.warn(app, tr("re.tapWall")) }
            return
        }
        if let id = reHitItem(hits(lay, r), p) { st.select(id, h); return }
        if let pid = reHitBody(lay.g, lay.map, p) { st.iwTap(pid, lay.map.mm(p), h); return }
        if let w = reNearWall(lay.frames.filter { !$0.inner }, p, 24) { st.selectWall(w.id, h, toggle: ops); return }
        st.deselect()
    }

    private func beginSlide(_ id: String, _ lay: ReLayout, _ p: CGPoint, _ r: Room) {
        guard let it = reFind(r, id), let f = lay.frame(it.wall) else { return }
        let t = reSegD(p, f.a, f.b).t / lay.map.k
        st.sel = .item(id); st.arm = nil; st.fw = it.wall
        st.live = ReLive(mode: "slide", id: id, snap: r, grab: t - CGFloat(it.dist))
        if let s = st.strip, !reToolIds(st, h).contains(s) { st.strip = nil }
        Haptic.tick()
    }

    private func slide(_ lay: ReLayout, _ p: CGPoint) {
        guard let lv = st.live, let base = lv.snap, var it = reFind(base, lv.id), let f = lay.frame(it.wall) else { return }
        let raw = Double(reSegD(p, f.a, f.b).t / lay.map.k - lv.grab)
        let m = reMagnet(it.along, lay.g.len(it.wall), raw, Double(lay.map.k))
        it.dist = m.v
        var r = base
        rePut(&r, it)
        st.preview = r
        st.mag = m.mag
        st.live?.changed = true
    }

    /// The drag ended: the slide or the edge is kept with its message and Undo; a cancelled one goes back.
    private func endLive(_ cancel: Bool) {
        guard let lv = st.live else { return }
        if lv.mode == "iw" { st.iwDragEnd(cancel, app, h); return }
        st.live = nil
        let pv = st.preview
        st.preview = nil
        st.mag = nil
        guard lv.mode == "slide" || lv.mode == "edge", !cancel, lv.changed, let r = pv, let it = reFind(r, lv.id) else { return }
        let L = reGeo(r).len(it.wall)
        let d = reDists(it, L)
        let msg: String
        if lv.mode == "edge" {
            msg = lv.edge == "t" ? tr("re.m.h", ["n": reKindName(it.kind), "v": reLen(it.h)])
                : lv.edge == "b" ? tr("re.m.sillH", ["s": reLen(it.sill), "h": reLen(it.h)])
                : tr("re.m.w", ["n": reKindName(it.kind), "v": reLen(it.w)])
        } else {
            msg = tr("re.m.moved2", ["n": reKindName(it.kind), "l": reLen(d.l), "r": reLen(d.r)]) + (it.isOpening ? "" : " · " + tr("re.phV", ["v": reLen(it.ph)]))
        }
        st.commit(app, h, msg) { rePut(&$0, it); return nil }
    }

    private func pinch(_ state: UIGestureRecognizer.State, _ scale: CGFloat, _ c: CGPoint, _ v: String) {
        guard !ops else { return }
        switch state {
        case .began:
            if st.live?.mode == "slide" { st.preview = nil; st.mag = nil }
            st.live = ReLive(mode: "pinch", cam0: st.cam(v))
            st.live?.grab = c.x; st.live?.hgrab = c.y
        case .changed:
            guard let lv = st.live, lv.mode == "pinch" else { return }
            let c0 = CGPoint(x: lv.grab, y: lv.hgrab)
            let z1 = min(6, max(0.6, lv.cam0.z * scale))
            var cam = ReCam()
            cam.z = z1
            cam.dx = c.x - (c0.x - lv.cam0.dx) * (z1 / lv.cam0.z)
            cam.dy = c.y - (c0.y - lv.cam0.dy) * (z1 / lv.cam0.z)
            st.cams[v] = cam
        default:
            if st.live?.mode == "pinch" { st.live = nil }
        }
    }

    /* ---------------- the front view's touches ---------------- */

    private func frontActs(_ fv: ReFront, _ g: ReRoomGeo, _ size: CGSize) -> DzcTouchActions {
        var a = DzcTouchActions()
        a.tap = { p in
            guard let r = h.room() else { return }
            if let lt = lastTap, Date().timeIntervalSince(lt.0) < 0.32, (lt.1 - p).len < 26 { lastTap = nil; st.cams["front"] = ReCam(); return }
            lastTap = (Date(), p)
            let inWall = p.x >= min(fv.X(0), fv.X(fv.L)) - 6 && p.x <= max(fv.X(0), fv.X(fv.L)) + 6 && p.y >= fv.Z(fv.rh) - 6 && p.y <= fv.Z(0) + 6
            if let k = st.arm {
                if inWall {
                    let ph = reKind(k).isOpening ? nil : reSnapH(k, Double(fv.Hh(p.y)), Double(fv.k), g.H)
                    st.placeAt(k, wall: fv.id, centre: Int(fv.T(p.x).rounded()), how: "tap", ph: ph, app, h)
                } else { st.warn(app, tr("re.tapWall")) }
                return
            }
            if let id = reFrontHitItem(reFrontHits(fv, reItems(r), sel: st.selItem), p) { st.select(id, h); return }
            if inWall { st.selectWall(fv.id, h); return }
            st.deselect()
        }
        a.panBegan = { p in
            guard let r = h.room() else { return }
            if beginFrontDrag(fv, r, p, long: false) { return }
            st.live = ReLive(mode: "pan", cam0: st.cam("front"))
        }
        a.panMoved = { p, t in
            guard let lv = st.live else { return }
            if lv.mode == "pan" { var c = lv.cam0; c.dx += t.width; c.dy += t.height; st.cams["front"] = c }
            else { frontDrag(fv, g, p) }
        }
        a.panEnded = { endLive($0) }
        a.longBegan = { p in if let r = h.room() { _ = beginFrontDrag(fv, r, p, long: true) } }
        a.longMoved = { p, _ in if st.live?.mode == "slide" || st.live?.mode == "edge" { frontDrag(fv, g, p) } }
        a.longEnded = { _, c in endLive(c) }
        a.pinch = { s, k, c in pinch(s, k, c, "front") }
        return a
    }

    /// An edge handle of the selected opening, or (held) an item to slide; true when a drag began.
    private func beginFrontDrag(_ fv: ReFront, _ r: Room, _ p: CGPoint, long: Bool) -> Bool {
        let hs = reFrontHits(fv, reItems(r), sel: st.selItem)
        if let sid = st.selItem, let hit = hs.first(where: { $0.id == sid }) {
            for hd in hit.handles where (hd.1 - p).len < 19 {
                st.live = ReLive(mode: "edge", id: sid, edge: hd.0, snap: r)
                Haptic.tick()
                return true
            }
        }
        guard long, let id = reFrontHitItem(hs, p), let it = reFind(r, id) else { return false }
        st.sel = .item(id); st.arm = nil
        st.live = ReLive(mode: "slide", id: id, snap: r, grab: fv.T(p.x) - CGFloat(it.dist), hgrab: it.isOpening ? 0 : fv.Hh(p.y) - CGFloat(it.ph))
        Haptic.tick()
        return true
    }

    private func frontDrag(_ fv: ReFront, _ g: ReRoomGeo, _ p: CGPoint) {
        guard let lv = st.live, let base = lv.snap, var it = reFind(base, lv.id) else { return }
        let L = g.len(it.wall)
        if lv.mode == "edge" {
            it = reEdge(it, lv.edge, t: Double(fv.T(p.x)), hz: Double(fv.Hh(p.y)), L: L, rh: g.H, k: Double(fv.k), fl: fv.fl)
        } else {
            let m = reMagnet(it.along, L, Double(fv.T(p.x) - lv.grab), Double(fv.k))
            it.dist = m.v
            st.mag = m.mag
            if !it.isOpening { it.ph = reSnapH(it.kind, Double(fv.Hh(p.y) - lv.hgrab), Double(fv.k), g.H) }
        }
        var r = base
        rePut(&r, it)
        st.preview = r
        st.live?.changed = true
    }

    /* ---------------- the 3D's touches ---------------- */

    private func isoActs(_ parts: [ReIsoPart], _ size: CGSize) -> DzcTouchActions {
        var a = DzcTouchActions()
        a.tap = { p in
            guard let r = h.room() else { return }
            if let lt = lastTap, Date().timeIntervalSince(lt.0) < 0.32, (lt.1 - p).len < 26 { lastTap = nil; st.cams["3d"] = ReCam(); return }
            lastTap = (Date(), p)
            let hit = reIsoHit(parts, p)
            if let k = st.arm {
                if let hit, hit.hasPrefix("w:") {
                    let w = String(hit.dropFirst(2))
                    st.placeAt(k, wall: w, centre: reGeo(r).len(w) / 2, how: "tap", app, h)
                } else { st.warn(app, tr("re.tapWall")) }
                return
            }
            guard let hit else { st.deselect(); return }
            if hit.hasPrefix("p:") { st.selectPiece(String(hit.dropFirst(2)), h); return }
            if hit.hasPrefix("i:") { st.select(String(hit.dropFirst(2)), h) } else { st.selectWall(String(hit.dropFirst(2)), h) }
        }
        a.panBegan = { _ in st.live = ReLive(mode: "pan", cam0: st.cam("3d")) }
        a.panMoved = { _, t in if let lv = st.live, lv.mode == "pan" { var c = lv.cam0; c.dx += t.width; c.dy += t.height; st.cams["3d"] = c } }
        a.panEnded = { _ in st.live = nil }
        a.pinch = { s, k, c in pinch(s, k, c, "3d") }
        return a
    }
}

/// The item under p on the front view.
func reFrontHitItem(_ hs: [ReFrontHit], _ p: CGPoint) -> String? {
    var best: (d: CGFloat, id: String)? = nil
    for q in hs {
        var d: CGFloat
        if q.op {
            guard q.r.insetBy(dx: -6, dy: -6).contains(p) else { continue }
            d = 10
        } else {
            d = (p - q.c).len
            if d > 19 { continue }
        }
        if best == nil || d < best!.d { best = (d, q.id) }
    }
    return best?.id
}

/// A point's height dragged on the front view: its kind's usual heights stick within 12 points (150 mm at most), else
/// to 10 mm, within the room.
func reSnapH(_ kind: String, _ hz: Double, _ k: Double, _ rh: Int) -> Int {
    let th = min(150, 12 / max(k, 1e-6))
    var best: Int? = nil
    for v in reKind(kind).hs where abs(hz - Double(v)) < th && (best == nil || abs(hz - Double(v)) < abs(hz - Double(best!))) { best = v }
    return best ?? reClamp(reR10(Int(hz.rounded())), 0, rh)
}

/// An opening's edge dragged on the front view (mockup doEdge): l or r change the width (the other side stays), t the
/// height, b a window's sill (its top stays); the usual sizes stick, else 10 mm. fl: the wall is seen the other way.
func reEdge(_ it0: ReItem, _ e: String, t: Double, hz: Double, L: Int, rh: Int, k: Double, fl: Bool) -> ReItem {
    var it = it0
    let cw = it.kind == "door" ? [700, 800, 900] : [1200, 1500, 1800]
    let ch = it.kind == "door" ? [2000, 2100, 2200] : [1200, 1400, 1500]
    let thr = min(60, max(20, 14 / max(k, 1e-6)))
    func snap(_ v: Double, _ list: [Int]) -> Int {
        var b: Int? = nil
        for x in list where abs(v - Double(x)) < thr && (b == nil || abs(v - Double(x)) < abs(v - Double(b!))) { b = x }
        return b ?? reR10(Int(v.rounded()))
    }
    if e == "l" || e == "r" {
        let low = (e == "l") != fl
        let t0 = Double(it.dist), t1 = Double(it.dist + it.w)
        if low {
            let w = reClamp(snap(t1 - min(max(t, 0), t1 - 300), cw), 300, Int(t1))
            it.w = w; it.dist = Int(t1) - w
        } else {
            let w2 = reClamp(snap(min(max(t, t0 + 300), Double(L)) - t0, cw), 300, max(300, L - Int(t0)))
            it.w = w2
        }
        if it.isBalcony && it.w < it.dw + 300 {
            let mn = it.dw + 300
            if low { it.dist = it.dist + it.w - mn }
            it.w = mn
        }
    } else if e == "t" {
        let z0 = it.z0
        it.h = reClamp(snap(hz - Double(z0), ch), 300, max(300, rh - z0))
        if it.isBalcony { it.h = max(it.h, it.wh + 100) }
    } else if e == "b" {
        let top = it.sill + it.h
        let ns = reClamp(snap(min(max(hz, 0), Double(top - 300)), [800, 900]), 0, max(0, top - 300))
        it.sill = ns; it.h = top - ns
    }
    return it
}

/// "8,8 m² · perimetr 12 000" (the editor's O‘lchamlar → Maydon).
func reAreaLine(_ g: ReRoomGeo) -> String {
    let s = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), g.area / 1e6)
    let a = AppSettings.shared.lang == .en ? s : s.replacingOccurrences(of: ".", with: ",")
    return tr("re.areaLine", ["a": a, "p": reLen(g.perimeter)])
}

/* ---------------- the distance bubbles ---------------- */

/// The selected item's two live distances on the plan (to both corners; a tap types one), the ghost's while it is
/// dragged, and the magnet's word.
struct RePlanBubbles: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    let lay: ReLayout
    let items: [ReItem]
    let ghost: ReItem?
    var body: some View {
        let sel = st.pk == nil ? items.first { $0.id == st.selItem } : nil
        ZStack(alignment: .topLeading) {
            if let it = sel ?? ghost, let f = lay.frame(it.wall) {
                let live = sel != nil
                let L = lay.g.len(it.wall)
                let d = reDists(it, L)
                let o: CGFloat = 22
                let s0 = f.at(CGFloat(it.dist), 0, lay.map.k), s1 = f.at(CGFloat(it.dist + it.along), 0, lay.map.k)
                let A = f.a + f.n * o, B = f.b + f.n * o, S0 = s0 + f.n * o, S1 = s1 + f.n * o
                Canvas { ctx, _ in
                    ctx.line(RD.blue, A, S0, 1.3); ctx.line(RD.blue, S1, B, 1.3)
                    for q in [A, S0, S1, B] { ctx.line(RD.blue, q - f.n * 5, q + f.n * 5, 1.6) }
                }
                .allowsHitTesting(false)
                bubble(mid(A, S0), reLen(d.l), live, id: "re.dl") { kpDist(it, "dl", L) }
                bubble(mid(S1, B), reLen(d.r), live, id: "re.dr") { kpDist(it, "dr", L) }
                if let m = st.mag {
                    let mp = (it.isOpening ? mid(s0, s1) : f.at(CGFloat(it.dist), 15, lay.map.k)) + f.n * (it.isOpening ? 46 : 40)
                    T(tr("re.mag." + m), ui(11, 800, .white), lines: 1).padding(.horizontal, 8).frame(height: 22)
                        .background(Capsule().fill(G.green))
                        .position(clampPt(mp, 30, 12))
                        .allowsHitTesting(false)
                }
            }
        }
    }
    private func clampPt(_ p: CGPoint, _ mx: CGFloat, _ my: CGFloat) -> CGPoint {
        CGPoint(x: min(max(p.x, mx), lay.size.width - mx), y: min(max(p.y, my), lay.size.height - my))
    }
    @ViewBuilder private func bubble(_ p: CGPoint, _ t: String, _ live: Bool, id: String, _ tap: @escaping () -> Void) -> some View {
        let c = clampPt(p, 24, 14)
        if live {
            T(t, num(12.5, 800, .white), lines: 1).padding(.horizontal, 10).frame(height: 30)
                .background(Capsule().fill(st.mag != nil ? G.green : G.cobalt))
                .shadow(color: G.cobalt.opacity(0.35), radius: 6, y: 4)
                .pressable(0.95, tap)
                .position(c)
                .accessibilityIdentifier(id)
        } else {
            T(t, num(11.5, 800, .white), lines: 1).padding(.horizontal, 8).frame(height: 24)
                .background(Capsule().fill(G.cobalt.opacity(0.85)))
                .position(c)
                .allowsHitTesting(false)
        }
    }
    private func kpDist(_ it: ReItem, _ which: String, _ L: Int) {
        let g = lay.g
        let corner = which == "dl" ? g.prev(it.wall) : g.next(it.wall)
        let d = reDists(it, L)
        st.openKp(tr(it.isOpening ? "re.kpDistE" : "re.kpDistC", ["n": reKindName(it.kind), "c": corner]), cur: which == "dl" ? d.l : d.r, lo: 0, hi: max(0, L - it.along)) { v in
            st.setDist(which, v, app, h)
        }
    }
}

/// The selected item's sizes on the front view, as bubbles (a tap types one): width, height, sill, and in the big
/// view the distances to both corners.
struct ReFrontBubbles: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    let fv: ReFront
    let g: ReRoomGeo
    let small: Bool
    var body: some View {
        if let r = h.room(), let id = st.selItem, let it = reFind(r, id), it.wall == fv.id, st.live == nil {
            let yf = fv.Z(0)
            ZStack(alignment: .topLeading) {
                if it.isOpening {
                    let x1 = fv.X(CGFloat(it.dist)), x2 = fv.X(CGFloat(it.dist + it.w))
                    let xl = min(x1, x2), xr = max(x1, x2), yt = fv.Z(CGFloat(it.top)), yb = fv.Z(CGFloat(it.z0))
                    let off: CGFloat = small ? 46 : 54
                    let hx = xr + off > fv.X(fv.fl ? 0 : fv.L) + 40 ? xl - off : xr + off
                    bub(CGPoint(x: (xl + xr) / 2, y: small ? yf + 12 : yt - 22), tr("re.bW", ["v": reLen(it.w)]), "re.fw") { kp(it, "w") }
                    bub(CGPoint(x: hx, y: (yt + yb) / 2), tr("re.bH", ["v": reLen(it.h)]), "re.fh") { kp(it, "h") }
                    if it.kind == "window" && it.style != "pano" && !it.isBalcony {
                        bub(CGPoint(x: hx == xr + off ? xl - off : xr + off, y: (yb + yf) / 2), tr("re.bS", ["v": reLen(it.sill)]), "re.fs") { kp(it, "sill") }
                    }
                } else {
                    let x = fv.X(CGFloat(it.dist)), y = fv.Z(CGFloat(it.ph))
                    bub(CGPoint(x: x + (small ? 40 : 46), y: y), tr("re.phV", ["v": reLen(it.ph)]), "re.fph") { kp(it, "ph") }
                }
            }
        }
    }
    private func bub(_ p: CGPoint, _ t: String, _ id: String, _ tap: @escaping () -> Void) -> some View {
        T(t, num(small ? 11.5 : 12.5, 800, .white), lines: 1).padding(.horizontal, small ? 8 : 10).frame(height: small ? 24 : 30)
            .background(Capsule().fill(G.cobalt))
            .pressable(0.95, tap)
            .position(p)
            .accessibilityIdentifier(id)
    }
    private func kp(_ it: ReItem, _ key: String) {
        let L = g.len(it.wall)
        switch key {
        case "w": st.openKp(tr("re.kpW", ["n": reKindName(it.kind)]), cur: it.w, lo: 300, hi: L) { st.setSize("w", $0, app, h) }
        case "h": st.openKp(tr("re.kpH", ["n": reKindName(it.kind)]), cur: it.h, lo: 300, hi: g.H - it.z0) { st.setSize("h", $0, app, h) }
        case "sill": st.openKp(tr("re.kpSill"), cur: it.sill, lo: 0, hi: g.H - it.h) { st.setSize("sill", $0, app, h) }
        default: st.openKp(tr("re.kpPh", ["n": reKindName(it.kind)]), cur: it.ph, lo: 0, hi: g.H) { st.setSize("ph", $0, app, h) }
        }
    }
}
