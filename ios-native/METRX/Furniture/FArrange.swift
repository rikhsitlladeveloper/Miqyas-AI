import SwiftUI
import UIKit

/*
 * "Mebel joylash" (room-editor mockup v3 scrPlace, drawPlace, placeCard, fPills, startF / doF / doFR): the room from
 * above (outer and inner walls, doors, windows) with the order's pieces in it as boxes. Tap one to select it. A free
 * piece is dragged (its sides stick flush to a wall or a piece within 60 mm), turned by its ring in 15° steps or by
 * "Burish 90°", and its four distances are pills to type; "Devorga yopishtirish" puts it on the nearest wall. A piece on
 * a wall slides along it ("Erkin qilish" frees it). Red: no room (overlap, an inner wall, a door, through a wall);
 * yellow: a passage under 700 mm, with its dimension line. Every change has Undo.
 */

@Observable final class FArrState {
    static var map: [String: FArrState] = [:]
    static func of(_ k: String) -> FArrState { if let s = map[k] { return s }; let s = FArrState(); map[k] = s; return s }
    var sel: String? = nil
    var past: [(fs: [Furniture], msg: String)] = []
    var future: [(fs: [Furniture], msg: String)] = []
    /// The piece being dragged or turned, as it is now.
    var preview: Furniture? = nil
    /// "move", "rot" or "slide"; the piece when it began; where the finger took it (plan mm).
    var mode = ""
    var base: Furniture? = nil
    var grab = PlanPt(0, 0)
    var magnet = false
    var rot: Int? = nil
    var cardMin = false
    var cam = ReCam()
}

/// The order's pieces in room rid.
private func fpRoomPieces(_ p: Project, _ rid: String) -> [Furniture] { p.furniture.filter { $0.roomId == rid } }

struct FArrangeScreen: View {
    let app: AppModel
    let pid: String
    let rid: String

    var body: some View {
        let st = FArrState.of(rid)
        let kp = ReState.of("fp:" + rid)
        let s = AppSettings.shared, snap = s.angleSnap, ws = s.workshop
        if let p = Store.shared.get(pid), let room = p.rooms.first(where: { $0.id == rid }) {
            let geo = fpGeo(room, snap)
            let g = geo.g
            let walls = planWalls(room, snap)
            let fs = fpRoomPieces(p, rid).map { f in st.preview?.id == f.id ? st.preview! : f }
            let pieces = fs.compactMap { fpPiece($0, walls, ws) }
            let chk = fpCheck(geo.room, g, pieces)
            ZStack {
                VStack(spacing: 0) {
                    UXTop {
                        UXTopBar(title: tr("fp.placeT"), sub: dn(room.name) + " · " + tr("fp.sub", ["n": fs.count]), back: { st.sel = nil; app.pop() }) { EmptyView() }
                    }
                    ZStack(alignment: .bottom) {
                        GeometryReader { gg in
                            let size = gg.size
                            let cardH: CGFloat = st.sel == nil ? 0 : (st.cardMin ? 70 : 220)
                            let m = ReMap.fit(g, CGRect(x: 0, y: 0, width: size.width, height: max(60, size.height - cardH)), pad: 30, padX: 40, cam: st.cam)
                            ZStack(alignment: .topLeading) {
                                Canvas { ctx, sz in
                                    var look = RePlanLook()
                                    look.small = true; look.showLen = true
                                    reDrawPlan(ctx, sz, g, reItems(geo.room), m, look, lenTxt: reLen)
                                    fpDraw(ctx, pieces, chk, m, sel: st.sel)
                                }
                                DzcTouch(act: acts(st, m, g, walls, pieces, fs, room, ws))
                                pills(st, kp, m, g, walls, pieces, fs, room, ws, chk, size)
                                if fs.isEmpty {
                                    T(tr("fp.none"), ui(13, 700, G.ink2), lines: 2).padding(.horizontal, 14).frame(minHeight: 34)
                                        .background(Capsule().fill(G.sheet(0.94))).frame(maxWidth: .infinity).padding(.top, 10)
                                        .allowsHitTesting(false)
                                }
                            }
                            .clipped()
                        }
                        .background(RD.paper)
                        if let id = st.sel, let f = fs.first(where: { $0.id == id }), let pc = pieces.first(where: { $0.id == id }) {
                            card(st, f, pc, chk, walls, room, ws, pieces, g).padding(.horizontal, 10).padding(.bottom, 8)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    bottom(st, p, room)
                }
                ReKpOverlay(app: app, st: kp)
            }
            .coordinateSpace(name: "re")
        } else {
            Color.clear.onAppear { app.pop() }
        }
    }

    /* ---------------- changes with Undo ---------------- */

    private func save(_ st: FArrState, _ f: Furniture, _ msg: String, _ warn: String? = nil) {
        guard let p = Store.shared.get(pid), let old = p.furniture.first(where: { $0.id == f.id }), old != f else { return }
        st.past.append((fpRoomPieces(p, rid), msg)); st.future = []
        Store.shared.update(pid) { pr in pr.furniture = pr.furniture.map { $0.id == f.id ? f : $0 } }
        KitOps.shared.forget(f.id); KitOps.shared.tick += 1
        if let warn { Haptic.warn(); app.toast = ToastMsg(text: msg + " · " + warn, kind: .error, action: tr("ux.undo"), onAction: { undo(st) }) }
        else { Haptic.confirm(); app.toast = ToastMsg(text: msg, kind: .ok, action: tr("ux.undo"), onAction: { undo(st) }) }
    }

    private func put(_ fs: [Furniture]) {
        Store.shared.update(pid) { pr in pr.furniture = pr.furniture.map { f in fs.first { $0.id == f.id } ?? f } }
        for f in fs { KitOps.shared.forget(f.id) }
        KitOps.shared.tick += 1
    }

    private func undo(_ st: FArrState) {
        guard let e = st.past.popLast(), let p = Store.shared.get(pid) else { return }
        st.future.append((fpRoomPieces(p, rid), e.msg)); put(e.fs); Haptic.tick()
        app.toast = ToastMsg(text: tr("re.undone", ["m": e.msg]), kind: .info)
    }
    private func redo(_ st: FArrState) {
        guard let e = st.future.popLast(), let p = Store.shared.get(pid) else { return }
        st.past.append((fpRoomPieces(p, rid), e.msg)); put(e.fs); Haptic.tick()
        app.toast = ToastMsg(text: tr("re.redone", ["m": e.msg]), kind: .info)
    }

    /// What the check says about piece id after a change (red first), in words; nil when it is fine.
    private func checkWords(_ id: String, _ f: Furniture) -> String? {
        guard let p = Store.shared.get(pid), let room = p.rooms.first(where: { $0.id == rid }) else { return nil }
        let s = AppSettings.shared, walls = planWalls(room, s.angleSnap)
        let geo = fpGeo(room, s.angleSnap)
        let pcs = fpRoomPieces(p, rid).map { $0.id == id ? f : $0 }.compactMap { fpPiece($0, walls, s.workshop) }
        let c = fpCheck(geo.room, geo.g, pcs)
        if let r = c.red[id] { return tr(r.key, r.vars) }
        if let y = c.yel[id], let m = y.map(\.gap).min() { return tr("fp.narrow", ["v": reLen(m)]) }
        return nil
    }

    private func moved(_ st: FArrState, _ f: Furniture, _ msg: String) { save(st, f, msg, checkWords(f.id, f)) }

    /* ---------------- touches ---------------- */

    private func hit(_ pieces: [FpPiece], _ m: ReMap, _ p: CGPoint) -> String? {
        for pc in pieces.reversed() {
            for P in pc.foots {
                let q = P.map { m.p(Pt(x: $0.x, y: $0.y)) }
                if rePip(p, q) { return pc.id }
                for i in q.indices where reSegD(p, q[i], q[(i + 1) % q.count]).d < 6 { return pc.id }
            }
        }
        return nil
    }

    /// The ring that turns the selected free piece: beyond its front, 26 points out.
    private func ringAt(_ pc: FpPiece, _ m: ReMap) -> CGPoint {
        let fe = pc.c + pc.ay * (pc.d / 2) + pc.ax * (pc.w * 0.32)
        let e = m.p(Pt(x: fe.x, y: fe.y)), q = m.p(Pt(x: fe.x + pc.ay.x * 100, y: fe.y + pc.ay.y * 100))
        let l = max(1e-6, (q - e).len)
        return e + (q - e) * (26 / l)
    }

    private func acts(_ st: FArrState, _ m: ReMap, _ g: ReRoomGeo, _ walls: [PlanWall], _ pieces: [FpPiece], _ fs: [Furniture], _ room: Room, _ ws: Workshop) -> DzcTouchActions {
        var a = DzcTouchActions()
        a.tap = { p in
            if let id = hit(pieces, m, p) { st.sel = id; st.cardMin = false; Haptic.tick() } else { st.sel = nil }
        }
        func begin(_ p: CGPoint) -> Bool {
            if let id = st.sel, let pc = pieces.first(where: { $0.id == id }), let f = fs.first(where: { $0.id == id }) {
                if pc.free && (ringAt(pc, m) - p).len < 22 { st.mode = "rot"; st.base = f; Haptic.tick(); return true }
                if hit(pieces, m, p) == id, !pc.kitchen {
                    let q = m.mm(p)
                    st.mode = pc.free ? "move" : "slide"; st.base = f; st.grab = PlanPt(q.x, q.y); Haptic.tick(); return true
                }
            }
            return false
        }
        a.panBegan = { p in
            if !begin(p) { st.mode = "pan"; st.grab = PlanPt(Double(st.cam.dx), Double(st.cam.dy)) }
        }
        a.panMoved = { p, t in
            if st.mode == "pan" { var c = st.cam; c.dx = CGFloat(st.grab.x) + t.width; c.dy = CGFloat(st.grab.y) + t.height; st.cam = c; return }
            drag(st, m, g, walls, pieces, room, ws, p)
        }
        a.panEnded = { cancel in end(st, cancel, walls, room) }
        a.longBegan = { p in
            if let id = hit(pieces, m, p) { st.sel = id }
            _ = begin(p)
        }
        a.longMoved = { p, _ in drag(st, m, g, walls, pieces, room, ws, p) }
        a.longEnded = { _, cancel in end(st, cancel, walls, room) }
        return a
    }

    private func drag(_ st: FArrState, _ m: ReMap, _ g: ReRoomGeo, _ walls: [PlanWall], _ pieces: [FpPiece], _ room: Room, _ ws: Workshop, _ p: CGPoint) {
        guard let b = st.base, let pc0 = fpPiece(b, walls, ws) else { return }
        let q = m.mm(p), qq = PlanPt(q.x, q.y)
        switch st.mode {
        case "move":
            let r = fpMove(b, pc0, pc0.c + (qq - st.grab), walls, g, pieces.filter { $0.id != b.id })
            st.preview = r.f; st.magnet = r.magnet
        case "rot":
            let v = qq - pc0.c
            let cr = pc0.ax.x * pc0.ay.y - pc0.ax.y * pc0.ay.x
            let ang = atan2(v.y, v.x) * 180 / .pi + (cr >= 0 ? -90 : 90)
            let sn = ((Int((ang / Double(FP_ROT)).rounded()) * FP_ROT) % 360 + 360) % 360
            if sn != st.rot { Haptic.tick() }
            st.rot = sn
            st.preview = fpTurn(b, pc0, walls, sn)
        case "slide":
            guard let wid = pc0.wall, let w = walls.first(where: { $0.id == wid }) else { return }
            let d = (qq - st.grab).dot(w.u)
            let off0 = runStart(b)
            let hi = max(0, (Int(w.len) - runLen(b)) / 10)
            let off = min(max(Int(((Double(off0) + d) / 10).rounded()), 0), hi) * 10
            st.preview = fpSlide(b, room, wid, off, ws)
        default: break
        }
    }

    private func end(_ st: FArrState, _ cancel: Bool, _ walls: [PlanWall], _ room: Room) {
        let mode = st.mode, pv = st.preview, mg = st.magnet
        st.mode = ""; st.preview = nil; st.base = nil; st.magnet = false; st.rot = nil
        guard !cancel, let f = pv, mode != "pan" else { return }
        let ws = AppSettings.shared.workshop
        guard let pc = fpPiece(f, walls, ws) else { return }
        switch mode {
        case "rot": moved(st, f, tr("fp.m.turned", ["n": dn(f.name), "a": fpAngle(pc)]))
        case "slide":
            let L = walls.first { $0.id == pc.wall }?.len ?? 0
            let a = runStart(f)
            moved(st, f, tr("fp.m.slid", ["n": dn(f.name), "w": reWL(pc.wall ?? ""), "l": reLen(a), "r": reLen(max(0, Int(L) - a - runLen(f)))]))
        default: moved(st, f, tr("fp.m.moved", ["n": dn(f.name)]) + (mg ? " · " + tr("fp.m.flush") : ""))
        }
    }

    /* ---------------- the pills ---------------- */

    @ViewBuilder private func pills(_ st: FArrState, _ kp: ReState, _ m: ReMap, _ g: ReRoomGeo, _ walls: [PlanWall], _ pieces: [FpPiece], _ fs: [Furniture],
                                    _ room: Room, _ ws: Workshop, _ chk: FpCheck, _ size: CGSize) -> some View {
        // the narrow passages' labels
        ForEach(Array(chk.yel.values.flatMap { $0 }.enumerated()), id: \.offset) { _, y in
            let c = mid(m.p(y.a), m.p(y.b))
            T(tr("fp.pass", ["v": reLen(y.gap)]), ui(11, 800, G.amberInk), lines: 1).padding(.horizontal, 8).frame(height: 22)
                .background(Capsule().fill(G.amberWash))
                .position(x: min(size.width - 70, max(70, c.x)), y: min(size.height - 12, max(12, c.y)))
                .allowsHitTesting(false)
        }
        if st.mode.isEmpty, let id = st.sel, let pc = pieces.first(where: { $0.id == id }), let f = fs.first(where: { $0.id == id }) {
            if pc.free {
                ForEach(Array(fpGaps(pc, g, pieces).enumerated()), id: \.offset) { k, x in
                    if let x, x.gap > 2 {
                        let c = mid(m.p(x.a), m.p(x.b))
                        pill(reLen(x.gap), c, size, amber: x.gap < FP_PASS, id: "fp.gap\(k)") {
                            kp.openKp(tr("fp.kpGap"), cur: x.gap, lo: 0, hi: SHAPE_WALL_MAX) { v in
                                let sh = Double(x.gap - v)
                                let r = fpPoseAt(pc, walls, f.pose?.ref ?? "A", c: pc.c + PlanPt(x.dir.x, x.dir.y) * sh, ang: fpAngle(pc))
                                var nf = f; nf.pose = r
                                moved(st, nf, tr("fp.m.gap", ["n": dn(f.name), "v": reLen(v)]))
                            }
                        }
                    }
                }
                let ring = ringAt(pc, m)
                MIcon("redo", .white, 15, 2.2).frame(width: 30, height: 30).background(Circle().fill(G.cobalt))
                    .position(x: ring.x, y: ring.y).allowsHitTesting(false).accessibilityIdentifier("fp.ring")
            } else if let wid = pc.wall, let w = walls.first(where: { $0.id == wid }), !pc.kitchen {
                let a = runStart(f), L = Int(w.len), r = max(0, L - a - runLen(f))
                let pa = w.at(Double(a) / 2, 120), pb = w.at(Double(a + runLen(f)) + Double(r) / 2, 120)
                if a > 5 {
                    pill(reLen(a), m.p(Pt(x: pa.x, y: pa.y)), size, id: "fp.dl") {
                        kp.openKp(tr("fp.kpL"), cur: a, lo: 0, hi: L) { v in moved(st, fpSlide(f, room, wid, v, ws), tr("fp.m.gap", ["n": dn(f.name), "v": reLen(v)])) }
                    }
                }
                if r > 5 {
                    pill(reLen(r), m.p(Pt(x: pb.x, y: pb.y)), size, id: "fp.dr") {
                        kp.openKp(tr("fp.kpR"), cur: r, lo: 0, hi: L) { v in moved(st, fpSlide(f, room, wid, L - runLen(f) - v, ws), tr("fp.m.gap", ["n": dn(f.name), "v": reLen(v)])) }
                    }
                }
            }
        }
        if let r = st.rot, let id = st.sel, let pc = pieces.first(where: { $0.id == id }) {
            let ring = ringAt(pc, m)
            T("\(r)°", num(12, 800, .white), lines: 1).padding(.horizontal, 8).frame(height: 24).background(Capsule().fill(G.cobalt))
                .position(x: ring.x, y: max(12, ring.y - 28)).allowsHitTesting(false)
        }
        if st.magnet {
            T(tr("fp.mag"), ui(11.5, 800, .white), lines: 1).padding(.horizontal, 10).frame(height: 26).background(Capsule().fill(RD.green))
                .frame(maxWidth: .infinity).padding(.top, 8).allowsHitTesting(false)
        }
    }

    private func pill(_ t: String, _ c: CGPoint, _ size: CGSize, amber: Bool = false, id: String, _ a: @escaping () -> Void) -> some View {
        T(t, num(12, 800, amber ? G.amberInk : G.cobalt2), lines: 1).padding(.horizontal, 9).frame(minWidth: 44, minHeight: 28)
            .background(Capsule().fill(amber ? G.amberWash : G.solid))
            .overlay(Capsule().strokeBorder((amber ? G.amberInk : G.cobalt).opacity(0.5), lineWidth: 1))
            .contentShape(Capsule())
            .pressable(0.95, label: t) { Haptic.tick(); a() }
            .accessibilityIdentifier(id)
            .position(x: min(size.width - 26, max(26, c.x)), y: min(size.height - 14, max(14, c.y)))
    }

    /* ---------------- the card and the bottom ---------------- */

    private func card(_ st: FArrState, _ f: Furniture, _ pc: FpPiece, _ chk: FpCheck, _ walls: [PlanWall], _ room: Room, _ ws: Workshop, _ pieces: [FpPiece], _ g: ReRoomGeo) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let wher = pc.free ? tr("fp.free", ["a": fpAngle(pc)]) : pc.wall.map { tr("fp.onWall", ["w": reWL($0)]) } ?? ""
        let sz = reLen(Int(pc.w.rounded())) + " × " + reLen(Int(pc.d.rounded())) + U_MM
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PathIcon("M4 11h16v6H4zM6 17v2M18 17v2M6 11V8h12v3", .white, 18, 2).frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(argb: 0xFFB7895B)))
                VStack(alignment: .leading, spacing: 1) {
                    T(dn(f.name), ui(14, 800), lines: 1)
                    T(sz + " · " + wher, num(12, 500, G.ink2), lines: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                xb(st.cardMin ? "M6 15l6-6 6 6" : "M6 9l6 6 6-6", "fp.cardMin") { st.cardMin.toggle() }
                xb("M6 6l12 12M18 6L6 18", "fp.desel") { st.sel = nil }
            }
            if !st.cardMin {
                if let r = chk.red[f.id] {
                    HStack(spacing: 6) { MIcon("alert", RD.issue, 15, 2); T(tr("fp.noRoom") + " " + tr(r.key, r.vars), ui(12, 700, RD.issue), lines: 2) }
                        .accessibilityIdentifier("fp.red")
                } else if let y = chk.yel[f.id], let mn = y.map(\.gap).min() {
                    HStack(spacing: 6) { MIcon("alert", G.amberInk, 15, 2); T(tr("fp.narrowL", ["v": reLen(mn)]), ui(12, 700, G.amberInk), lines: 2) }
                        .accessibilityIdentifier("fp.yel")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if pc.free {
                            act(RE_IC["rot"] ?? "", tr("fp.rot90"), "fp.rot90") { moved(st, fpTurn(f, pc, walls, fpAngle(pc) + 90), tr("fp.m.turned", ["n": dn(f.name), "a": (fpAngle(pc) + 90) % 360])) }
                            act(IW_IC, tr("fp.stick"), "fp.stick") {
                                if let s = fpStick(f, pc, room, walls, ws) { moved(st, s.f, tr("fp.m.stuck", ["n": dn(f.name), "w": reWL(s.wall)])) }
                                else { Haptic.warn(); app.toast = ToastMsg(text: tr("fp.noWall"), kind: .error) }
                            }
                        } else if canBeFree(f) {
                            act("M12 3v18M3 12h18", tr("fp.toFree"), "fp.toFree") { moved(st, fpToFree(f, walls), tr("fp.m.freed", ["n": dn(f.name)])) }
                        }
                        if f.kind == "kitchen" {
                            act(RE_IC["move"] ?? "", tr("fp.place"), "fp.placeK") { app.push(.fPlace(pid: pid, fid: f.id, rid: rid)) }
                        }
                        act(RE_IC["type"] ?? "", tr("fp.design"), "fp.design") { app.push(designer(pid, f)) }
                    }
                }
            }
        }
        .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 8)
        .background(shape.fill(G.solid))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 17, y: 10)
    }

    private func xb(_ d: String, _ id: String, _ a: @escaping () -> Void) -> some View {
        PathIcon(d, G.ink2, 17, 2).frame(width: 38, height: 38)
            .background(Circle().fill(G.ink.opacity(0.06)))
            .pressable(0.95, label: id == "fp.desel" ? tr("re.desel") : tr("re.cardMin")) { Haptic.tick(); a() }
            .accessibilityIdentifier(id)
    }
    private func act(_ icon: String, _ t: String, _ id: String, _ a: @escaping () -> Void) -> some View {
        HStack(spacing: 6) { PathIcon(icon, G.ink, 17, 2); T(t, ui(12.5, 700), lines: 1) }
            .padding(.horizontal, 11).frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(G.ink.opacity(0.06)))
            .pressable(0.96, label: t) { Haptic.tick(); a() }
            .accessibilityIdentifier(id)
    }

    private func bottom(_ st: FArrState, _ p: Project, _ room: Room) -> some View {
        HStack(spacing: 8) {
            hist("undo", on: !st.past.isEmpty, id: "fp.undo") { undo(st) }
            hist("redo", on: !st.future.isEmpty, id: "fp.redo") { redo(st) }
            GBtn(tr("fp.add"), kind: .secondary, icon: "plus", height: 54, fontSize: 14) { app.push(.fGallery(pid: pid, rid: rid)) }
                .frame(maxWidth: 130)
                .accessibilityIdentifier("fp.add")
            GBtn(tr("fp.done"), height: 54) { st.sel = nil; app.pop() }
                .accessibilityIdentifier("fp.done")
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) }.ignoresSafeArea(edges: .bottom) }
        .bottomBar()
    }

    private func hist(_ icon: String, on: Bool, id: String, _ a: @escaping () -> Void) -> some View {
        MIcon(icon, on ? G.ink : G.ink3.opacity(0.5), 20, 2.2)
            .frame(width: 46, height: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
            .pressable(0.95, label: tr(icon == "undo" ? "ux.undo" : "re.redo")) { if on { a() } }
            .accessibilityIdentifier(id)
    }
}

/// The pieces on the plan: wood-coloured boxes with their front edge, red or yellow when the check says so, their
/// names when there is room, the selected one outlined, the narrow passages' dimension lines.
func fpDraw(_ ctx: GraphicsContext, _ pieces: [FpPiece], _ chk: FpCheck, _ m: ReMap, sel: String?) {
    let wood = Color(argb: 0xFFD8B48A), woodLine = Color(argb: 0xFF8A6238)
    for pc in pieces {
        let red = chk.red[pc.id] != nil, yel = chk.yel[pc.id] != nil
        for P in pc.foots {
            let q = P.map { m.p(Pt(x: $0.x, y: $0.y)) }
            ctx.poly(q, fill: red ? RD.issue.opacity(0.35) : yel ? Color(argb: 0x66F59E0B) : wood.opacity(0.85), stroke: red ? RD.issue : yel ? G.amberInk : woodLine, red || yel ? 2 : 1.2)
        }
        // the front edge
        let f0 = pc.c + pc.ay * (pc.d / 2) - pc.ax * (pc.w / 2), f1 = pc.c + pc.ay * (pc.d / 2) + pc.ax * (pc.w / 2)
        ctx.line(woodLine, m.p(Pt(x: f0.x, y: f0.y)), m.p(Pt(x: f1.x, y: f1.y)), 2.4)
        let wpx = CGFloat(pc.w) * m.k, dpx = CGFloat(pc.d) * m.k
        if min(wpx, dpx) > 16 && max(wpx, dpx) > CGFloat(pc.name.count) * 5.6 + 8 {
            ctx.text(dn(pc.name), m.p(Pt(x: pc.c.x, y: pc.c.y)), .ui, 10.5, 700, RD.ink)
        }
        if pc.id == sel {
            for P in pc.foots { ctx.poly(P.map { m.p(Pt(x: $0.x, y: $0.y)) }, stroke: RD.blue, 2.6) }
            if pc.free {
                let fe = pc.c + pc.ay * (pc.d / 2) + pc.ax * (pc.w * 0.32)
                let e = m.p(Pt(x: fe.x, y: fe.y)), q = m.p(Pt(x: fe.x + pc.ay.x * 100, y: fe.y + pc.ay.y * 100))
                let l = max(1e-6, (q - e).len)
                ctx.line(RD.blue, e, e + (q - e) * (26 / l), 1.6)
            }
        }
    }
    for y in chk.yel.values.flatMap({ $0 }) {
        let a = m.p(y.a), b = m.p(y.b)
        let L = max(1e-6, (b - a).len), u = (b - a) / L, q = CGPoint(x: -u.y * 5, y: u.x * 5)
        ctx.line(G.amberInk, a, b, 1.4, dash: [4, 3])
        ctx.line(G.amberInk, a + q, a - q, 1.4); ctx.line(G.amberInk, b + q, b - q, 1.4)
    }
}
