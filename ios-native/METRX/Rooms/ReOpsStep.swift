import SwiftUI
import UIKit

/*
 * The room-shape flow's "Eshik, deraza va nuqtalar" step, redesigned (room-editor mockup v2, approved 28 Oct 2026;
 * scrOps, opsCard, drawOps, coach): the plan takes the full height, under it the A · B · C · D wall chips and the icon
 * row in the trade's order. An icon is dragged onto a wall (it glows green), or tapped and then a wall or a chip, or a
 * wall is tapped and then an icon: its ghost goes on the wall and the floating style window opens, then its sizes one
 * per step. A hand shows how until the first item is placed ("?" plays it again). The selected item gets a floating
 * card above the icon row (its distances, a small front view with edges to drag, Turi, O‘lcham, O‘chirish, ✕ and ⌄),
 * and the plan moves up so it stays in sight; "N ta belgi" lists them all. Items slide along their wall with magnets.
 */

/// The flow's room as its shape and sizes make it so far, with this step's items on it (kept within their walls).
func rshWorkRoom(_ d: RshDraft) -> Room {
    let spec = specOf(d)
    let vs = (0..<rshAsks(d).count).map { d.vals[$0] }
    var r = shapeToRoom(spec, vs, height: d.height, id: "rsh-" + d.key, floorId: "", name: d.name, diagonal: d.diag,
                        angleSnap: AppSettings.shared.angleSnap)?.room ?? Room(id: "rsh-" + d.key, floorId: "", name: d.name)
    r.openings = d.wOps
    r.points = d.wPts
    reClampItems(&r)
    return r
}

/// The openings step's room: read from the draft, the items written back to it.
func rshWorkHost(_ d: RshDraft) -> ReHost {
    let industry = Store.shared.get(d.pid)?.industry ?? "build"
    return ReHost(pid: d.pid, industry: industry, room: { rshWorkRoom(d) }, put: { r in d.wOps = r.openings; d.wPts = r.points })
}

/// The draft's items as the summary's plan draws them (doors, windows, water, sewer and gas on the shape's walls).
func rshOpsForPlan(_ d: RshDraft) -> [ShapeOpening] {
    let spec = specOf(d)
    let vs = (0..<rshAsks(d).count).map { d.vals[$0] }
    guard let made = shapeToRoom(spec, vs, height: d.height, id: "x", floorId: "x", name: "x") else { return [] }
    var out: [ShapeOpening] = []
    for o in d.wOps {
        guard let j = made.wallIds.firstIndex(of: o.wall) else { continue }
        let L = made.lens[j]
        let dist = made.flipped[j] ? L - o.off - o.w : o.off
        out.append(ShapeOpening(o.type == "door" ? .door : .window, j, max(0, dist), o.w, o.h, o.sill))
    }
    for x in d.wPts {
        let k: OpKind? = x.t == "cold" || x.t == "hot" ? .water : x.t == "sewer" ? .sewer : x.t == "gas" ? .gas : nil
        guard let k, let j = made.wallIds.firstIndex(of: x.wall) else { continue }
        let L = made.lens[j]
        out.append(ShapeOpening(k, j, max(0, made.flipped[j] ? L - x.off : x.off)))
    }
    return out
}

extension ReState {
    /// An icon dragged from the row to pt (the page's "re" space): its ghost on the nearest wall within 90 points (on the
    /// front view: on the wall where the finger is, a point at the height it is held).
    func dragTile(_ kind: String, _ pt: CGPoint, _ h: ReHost, ops: Bool, pan: CGFloat = 0) {
        tileKind = kind; tilePt = pt; arm = nil
        guard let r = h.room(), canvas.contains(pt) else { ghost = nil; mag = nil; return }
        let g = reGeo(r)
        let p = CGPoint(x: pt.x - canvas.minX, y: pt.y - canvas.minY)
        if !ops && view == "3d" { ghost = nil; return }
        if !ops && view == "front", let fv = reFrontOf(g, fw, canvas.size, small: false, cam: cam("front")) {
            let inWall = p.x >= min(fv.X(0), fv.X(fv.L)) && p.x <= max(fv.X(0), fv.X(fv.L)) && p.y >= fv.Z(fv.rh) && p.y <= fv.Z(0)
            guard inWall else { ghost = nil; mag = nil; return }
            var it = reNewItem(kind, wall: fw, centre: Int(fv.T(p.x).rounded()), wallL: g.len(fw), roomH: g.H)
            let m = reMagnet(it.along, g.len(fw), Double(it.dist), Double(fv.k))
            it.dist = m.v
            if !it.isOpening { it.ph = reSnapH(kind, Double(fv.Hh(p.y)), Double(fv.k), g.H) }
            ghost = it; mag = m.mag
            return
        }
        let lay = ReLayout.plan(g, canvas.size, ops: ops, cam: ops ? ReCam(z: 1, dx: 0, dy: pan) : cam("plan"))
        guard let w = reNearWall(lay.frames, p, 90) else { ghost = nil; mag = nil; return }
        let L = g.len(w.id)
        var it = reNewItem(kind, wall: w.id, centre: Int((w.t / lay.map.k).rounded()), wallL: L, roomH: g.H)
        let m = reMagnet(it.along, L, Double(it.dist), Double(lay.map.k))
        it.dist = m.v
        ghost = it; mag = m.mag
    }

    /// The icon let go: on a wall it goes there and the style window opens; elsewhere a word to bring it nearer.
    func dropTile(_ kind: String, _ pt: CGPoint?, _ app: AppModel, _ h: ReHost, front: Bool = false) {
        tileKind = nil
        let gh = ghost
        ghost = nil; mag = nil
        guard pt != nil else { return }
        if view == "3d" && !front { app.toast = ToastMsg(text: tr("re.no3dDrag"), kind: .info); return }
        guard let it = gh else { warn(app, tr("re.dropFar")); return }
        placeAt(kind, wall: it.wall, centre: it.isOpening ? it.dist + it.w / 2 : it.dist, how: "drag", ph: it.isOpening || !front ? nil : it.ph, app, h)
    }
}

/// The step itself.
struct ReOpsStep: View {
    let app: AppModel
    let d: RshDraft
    let back: () -> Void
    let done: () -> Void

    var body: some View {
        let st = ReState.of(d.key)
        let h = rshWorkHost(d)
        let r = st.shown(h) ?? rshWorkRoom(d)
        let g = reGeo(r)
        let items = reItems(r)
        ZStack {
            VStack(spacing: 0) {
                UXTop {
                    UXTopBar(title: tr("re.opsT"), sub: tr("re.opsSub", ["n": dn(d.name)]), back: back) {
                        T("?", ui(20, 800, G.cobalt2), align: .center)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(G.glass(0.6)))
                            .overlay(Circle().strokeBorder(G.rim, lineWidth: 1))
                            .pressable(0.95, label: tr("re.coachA")) { st.coachRuns = 2; st.coachT0 = Date(); st.deselect(); Haptic.tick() }
                            .accessibilityIdentifier("re.help")
                    }
                }
                ZStack(alignment: .bottom) {
                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            ReCanvas(app: app, st: st, h: h, ops: true, pan: opsPan(st, h, g, items))
                            if !items.isEmpty && st.pk == nil {
                                HStack(spacing: 6) {
                                    PathIcon("M9 6h12M9 12h12M9 18h12M4 6h.01M4 12h.01M4 18h.01", G.cobalt, 16, 2)
                                    T(tr("re.nItems", ["n": items.count]), ui(12.5, 800), lines: 1)
                                }
                                .padding(.horizontal, 12).frame(height: 32)
                                .background(Capsule().fill(G.sheet(0.94)))
                                .overlay(Capsule().strokeBorder(G.rim, lineWidth: 1))
                                .pressable(0.96) { st.list = true }
                                .padding(10)
                                .accessibilityIdentifier("re.list")
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(RD.paper))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                        ReWallChips(g: g, sel: st.selWall, hl: st.ghost?.wall ?? (st.pk?.mode == "new" ? st.pk?.wall : nil), armed: st.arm != nil) { w in
                            if let k = st.arm { st.placeAt(k, wall: w, centre: g.len(w) / 2, how: "chip", app, h) } else { st.selectWall(w, h, toggle: true) }
                        }
                    }
                    .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
                    ReOpsCard(app: app, st: st, h: h, g: g, items: items)
                        .padding(.horizontal, 10).padding(.bottom, 52)
                }
                .frame(maxHeight: .infinity)
                // the icon row
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        T(tr("re.tilesT"), ui(12.5, 800), lines: 1)
                        T(tr("re.tilesS"), ui(11.5, 600, G.ink2), lines: 1).minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 14).padding(.top, 6)
                    ReTileRow(st: st, groups: reGroups(h.industry), tap: { st.tileTap($0, app, h) },
                              drag: { k, p in st.dragTile(k, p, h, ops: true, pan: st.pan) },
                              drop: { k, p in st.dropTile(k, p, app, h) })
                }
                .background(Rectangle().fill(G.sheet(0.97)).ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 1) }
                // undo, redo, Tayyor
                HStack(spacing: 8) {
                    histBtn("undo", on: !st.past.isEmpty, id: "re.undo") { st.undo(app, h) }
                    histBtn("redo", on: !st.future.isEmpty, id: "re.redo") { st.redo(app, h) }
                    GBtn(tr(items.isEmpty ? "rsh.skip" : "rsh.ready"), height: 54) { Haptic.tick(); st.reset(); done() }
                        .accessibilityIdentifier("rsh.opsDone")
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) }.ignoresSafeArea(edges: .bottom) }
                .bottomBar()
            }
            coach(st, g, items)
            if let k = st.tileKind {
                let line = st.ghost.map { gh in tr("re.dragTo", ["w": gh.wall]) + " · " + reLen(reDists(gh, g.len(gh.wall)).l) + " | " + reLen(reDists(gh, g.len(gh.wall)).r) } ?? tr("re.dragNear")
                ReDragChip(kind: k, line: line, ok: st.ghost != nil)
                    .position(x: st.tilePt.x, y: st.tilePt.y - 56)
            }
            ReListSheet(st: st, h: h)
            RePickWindow(app: app, st: st, h: h)
            ReKpOverlay(app: app, st: st)
        }
        .coordinateSpace(name: "re")
        .animation(.easeOut(duration: 0.18), value: st.pk != nil)
    }

    private func histBtn(_ icon: String, on: Bool, id: String, _ a: @escaping () -> Void) -> some View {
        MIcon(icon, on ? G.ink : G.ink3.opacity(0.5), 20, 2.2)
            .frame(width: 48, height: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
            .pressable(0.95, label: tr(icon == "undo" ? "ux.undo" : "re.redo")) { if on { a() } }
            .accessibilityIdentifier(id)
    }

    /// The plan moved up so the selected item stays above the floating card (held still while a finger drags).
    private func opsPan(_ st: ReState, _ h: ReHost, _ g: ReRoomGeo, _ items: [ReItem]) -> CGFloat {
        guard let id = st.selItem, st.pk == nil, let it = items.first(where: { $0.id == id }), st.canvas.height > 0 else { return 0 }
        if st.live != nil { return st.pan }
        let lay = ReLayout.plan(g, st.canvas.size, ops: true, cam: ReCam())
        guard let f = lay.frame(it.wall) else { return 0 }
        let hit = rePlanHit(it, f, lay.map.k, small: true)
        let yb = it.isOpening ? max(hit.p0.y, hit.p1.y, hit.q0.y, hit.q1.y) : hit.c.y + 10
        let yc = it.isOpening ? (hit.p0.y + hit.p1.y + hit.q0.y + hit.q1.y) / 4 : hit.c.y
        // the card covers the plan's lower part (with the wall chips under it)
        let cardH: CGFloat = st.cardMin ? 60 : 250
        let lim = st.canvas.height - cardH - 12
        var pan: CGFloat = 0
        if yb > lim { pan = (min(0, max(lim - yb, lim / 2 - yc))).rounded() }
        DispatchQueue.main.async { if st.pan != pan { st.pan = pan } }
        return pan
    }

    @ViewBuilder private func coach(_ st: ReState, _ g: ReRoomGeo, _ items: [ReItem]) -> some View {
        let first = reGroups(rshWorkHost(d).industry).first?.first ?? "door"
        let show = st.pk == nil && st.sel == nil && st.arm == nil && st.tileKind == nil && !st.list && st.kp == nil
            && (st.coachRuns > 0 || (items.isEmpty && !st.coachStop)) && st.canvas.width > 0 && st.tile0.width > 0
        if show, let w = g.walls.first {
            let lay = ReLayout.plan(g, st.canvas.size, ops: true, cam: ReCam())
            if let f = lay.frame(w.id) {
                let o = st.canvas.origin
                let a = f.a + o, b = f.b + o
                let to = mid(a, b) + CGPoint(x: 0, y: 4)
                let from = CGPoint(x: st.tile0.midX, y: st.tile0.midY - 4)
                ReCoach(kind: first, from: from, to: to, a: a, b: b, caption: CGPoint(x: st.canvas.midX, y: st.canvas.maxY - 22))
                    .task(id: st.coachRuns) {
                        // "?" plays it twice (two turns of 3,6 s), then it stops again
                        guard st.coachRuns > 0 else { return }
                        try? await Task.sleep(nanoseconds: 7_300_000_000)
                        st.coachRuns = 0
                    }
            }
        }
    }
}

/// The floating card above the icon row (mockup opsCard): the selected item (full, or folded to one line), the
/// selected wall, or the armed icon.
struct ReOpsCard: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    let g: ReRoomGeo
    let items: [ReItem]
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Group {
            if st.pk == nil, let id = st.selItem, let it = items.first(where: { $0.id == id }) {
                itemCard(it)
            } else if let k = st.arm {
                oneLine(AnyView(ReBadge(kind: k, size: 32)), tr("re.armT", ["n": reKindName(k)]), tr("re.armS")) { st.arm = nil }
            } else if let w = st.selWall, st.pk == nil {
                let n = items.filter { $0.wall == w }.count
                oneLine(AnyView(PathIcon(SD_ROOM_IC, .white, 18, 2).frame(width: 32, height: 32).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.cobalt))),
                        tr("re.wallCard", ["w": w, "l": reLen(g.len(w)), "v": reLen(g.len(w)), "n": n]), tr("re.wallCardS")) { st.deselect() }
            }
        }
        .background(shape.fill(G.solid))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 17, y: 10)
    }

    private func xBtn(_ icon: String, _ label: String, _ id: String, _ a: @escaping () -> Void) -> some View {
        let d = icon == "down" ? "M6 9l6 6 6-6" : icon == "selUp" ? "M6 15l6-6 6 6" : "M6 6l12 12M18 6L6 18"
        return PathIcon(d, G.ink2, 17, 2).frame(width: 38, height: 38)
            .background(Circle().fill(G.ink.opacity(0.06)))
            .pressable(0.95, label: label, a)
            .accessibilityIdentifier(id)
    }

    private func oneLine(_ badge: AnyView, _ t: String, _ s: String, _ x: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            badge
            VStack(alignment: .leading, spacing: 1) {
                T(t, ui(14, 800), lines: 1)
                T(s, ui(12, 500, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            xBtn("x", tr("common.cancel"), "re.cardX", x)
        }
        .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 6)
    }

    @ViewBuilder private func itemCard(_ it: ReItem) -> some View {
        let L = g.len(it.wall)
        let d = reDists(it, L)
        let iss = reIssues(items, lens: g.lens, roomH: g.H).first { $0.id == it.id }
        if st.cardMin {
            HStack(spacing: 10) {
                ReBadge(kind: it.kind, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    T(reItemName(it), ui(14, 800), lines: 1)
                    T(reSizeLine(it) + " · " + reLen(d.l) + " | " + reLen(d.r), num(12, 500, G.ink2), lines: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                xBtn("selUp", tr("re.cardOpen"), "re.cardMin") { st.cardMin = false; Haptic.tick() }
                xBtn("x", tr("re.desel"), "re.desel") { st.deselect() }
            }
            .padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ReBadge(kind: it.kind)
                    VStack(alignment: .leading, spacing: 1) {
                        T(reItemName(it), ui(14, 800), lines: 1)
                        T(reSizeLine(it) + " " + unitWord(AppSettings.shared.unit), num(12, 500, G.ink2), lines: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    xBtn("down", tr("re.cardFold"), "re.cardMin") { st.cardMin = true; Haptic.tick() }
                    xBtn("x", tr("re.desel"), "re.desel") { st.deselect() }
                }
                HStack(spacing: 6) {
                    T(g.prev(it.wall) + " ←", ui(12, 700, G.ink2), lines: 1)
                    distChip(reLen(d.l), "re.cdl") { kp(it, "dl", L) }
                    T(tr("re.wallX", ["w": it.wall]) + " · " + reLen(L), ui(11.5, 700, G.ink3), align: .center, lines: 1).frame(maxWidth: .infinity)
                    distChip(reLen(d.r), "re.cdr") { kp(it, "dr", L) }
                    T("→ " + g.next(it.wall), ui(12, 700, G.ink2), lines: 1)
                }
                ReMiniFront(app: app, st: st, h: h, g: g, it: it)
                    .frame(height: 104)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(RD.paper))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if let iss {
                    HStack(alignment: .top, spacing: 8) { MIcon("alert", G.amberInk, 17, 2); T(reIssueText(iss), ui(12.5, 600, G.ink, lh: 1.3)).frame(maxWidth: .infinity, alignment: .leading) }
                        .padding(8).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.amberWash))
                }
                HStack(spacing: 6) {
                    cardBtn(DZC_ICON["type"]!, tr("re.type"), "re.cType") { st.pickFor("retype", h) }
                    cardBtn(DZC_ICON["width"]!, tr("re.size"), "re.cSize") { st.pickFor("resize", h) }
                    cardBtn(DZC_ICON["del"]!, tr("common.delete"), "re.cDel", red: true) { st.delSel(app, h) }
                }
            }
            .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 10)
        }
    }

    private func distChip(_ t: String, _ id: String, _ a: @escaping () -> Void) -> some View {
        T(t, num(13, 800), lines: 1).padding(.horizontal, 10).frame(minHeight: 34)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
            .pressable(0.96, a)
            .accessibilityIdentifier(id)
    }

    private func cardBtn(_ icon: String, _ label: String, _ id: String, red: Bool = false, _ a: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            PathIcon(icon, red ? G.err : G.cobalt2, 16, 2)
            T(label, ui(13, 800, red ? G.err : G.cobalt2), lines: 1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(red ? G.errWash : G.cobalt.opacity(0.11)))
        .pressable(0.97, a)
        .accessibilityIdentifier(id)
    }

    private func kp(_ it: ReItem, _ which: String, _ L: Int) {
        let corner = which == "dl" ? g.prev(it.wall) : g.next(it.wall)
        let d = reDists(it, L)
        st.openKp(tr(it.isOpening ? "re.kpDistE" : "re.kpDistC", ["n": reKindName(it.kind), "c": corner]), cur: which == "dl" ? d.l : d.r, lo: 0, hi: max(0, L - it.along)) { v in
            st.setDist(which, v, app, h)
        }
    }
}

/// The card's small front view: the item's wall from inside, its edges dragged to resize it (a point dragged up or
/// down), and its sizes as bubbles to type.
struct ReMiniFront: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    let g: ReRoomGeo
    let it: ReItem
    var body: some View {
        GeometryReader { geo in
            if let r = st.shown(h), let fv = reFrontOf(g, it.wall, geo.size, small: true, cam: ReCam()) {
                let items = reItems(r)
                let iss = Set(reIssues(items, lens: g.lens, roomH: g.H).map(\.id))
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, sz in
                        reDrawFront(ctx, sz, fv, items, sel: st.selItem, wallSel: false, ghost: nil, left: g.prev(it.wall), right: g.next(it.wall), caption: nil, issues: iss, small: true)
                    }
                    DzcTouch(act: acts(fv))
                    ReFrontBubbles(app: app, st: st, h: h, fv: fv, g: g, small: true)
                }
            }
        }
    }

    private func acts(_ fv: ReFront) -> DzcTouchActions {
        var a = DzcTouchActions()
        a.tap = { p in
            guard let r = h.room(), let id = reFrontHitItem(reFrontHits(fv, reItems(r), sel: st.selItem), p) else { return }
            st.select(id, h)
        }
        a.panBegan = { p in
            guard let r = h.room(), let sid = st.selItem, let cur = reFind(r, sid) else { return }
            let hs = reFrontHits(fv, reItems(r), sel: sid)
            if let hit = hs.first(where: { $0.id == sid }) {
                for hd in hit.handles where (hd.1 - p).len < 16 { st.live = ReLive(mode: "edge", id: sid, edge: hd.0, snap: r); Haptic.tick(); return }
            }
            if !cur.isOpening, reFrontHitItem(hs, p) == sid {
                st.live = ReLive(mode: "slide", id: sid, snap: r, grab: fv.T(p.x) - CGFloat(cur.dist), hgrab: fv.Hh(p.y) - CGFloat(cur.ph))
            }
        }
        a.panMoved = { p, _ in
            guard let lv = st.live, let base = lv.snap, var x = reFind(base, lv.id) else { return }
            let L = g.len(x.wall)
            if lv.mode == "edge" { x = reEdge(x, lv.edge, t: Double(fv.T(p.x)), hz: Double(fv.Hh(p.y)), L: L, rh: g.H, k: Double(fv.k), fl: fv.fl) }
            else if lv.mode == "slide" {
                x.dist = reMagnet(0, L, Double(fv.T(p.x) - lv.grab), Double(fv.k)).v
                x.ph = reSnapH(x.kind, Double(fv.Hh(p.y) - lv.hgrab), Double(fv.k), g.H)
            } else { return }
            var rr = base
            rePut(&rr, x)
            st.preview = rr
            st.live?.changed = true
        }
        a.panEnded = { cancel in
            guard let lv = st.live else { return }
            st.live = nil
            let pv = st.preview
            st.preview = nil
            guard !cancel, lv.changed, let r = pv, let x = reFind(r, lv.id) else { return }
            let msg = lv.mode == "slide" ? tr("re.m.h", ["n": reKindName(x.kind), "v": reLen(x.ph)])
                : lv.edge == "t" ? tr("re.m.h", ["n": reKindName(x.kind), "v": reLen(x.h)])
                : lv.edge == "b" ? tr("re.m.sillH", ["s": reLen(x.sill), "h": reLen(x.h)]) : tr("re.m.w", ["n": reKindName(x.kind), "v": reLen(x.w)])
            st.commit(app, h, msg) { rePut(&$0, x); return nil }
        }
        return a
    }
}
