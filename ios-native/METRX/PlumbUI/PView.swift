import SwiftUI
import UIKit

/*
 * A room's plumbing (Android ui/plumb/PView.kt): the room in 3D with its fixtures at their true size, the riser, the
 * cold, hot, drain and heating pipes in their colours and the underfloor loops; the room from above (fixtures and the
 * riser dragged onto and along the walls); or a wall straight on (fixtures, outlets and the riser dragged along it, the
 * outlets with their heights). Under it the warnings, the fixtures, the outlets, the riser, the heating and, in the
 * advanced app, what it all takes.
 */

private var pvEn: Bool { AppSettings.shared.lang == .en }

private func pvD1(_ v: Double) -> String { Num.fixed(v, 1, AppSettings.shared.lang) }

struct PViewScreen: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var mode = "3d"
    @State private var wall: String? = nil
    @State private var layerS: [String] = P_LAYERS

    var body: some View {
        if let p = Store.shared.get(pid) {
            let free = rid.hasPrefix("free:")
            let calc = PlumbCalcCache.shared.of(p)
            let c = calc.ctxs.first { $0.id == rid }
            let room: Room? = free ? nil : p.rooms.first { $0.id == rid }
            GeometryReader { geo in
                VStack(spacing: 0) {
                    bar(p, c, room, free)
                    if let c { content(p, c, room, calc, free, geo.size.height) } else { needMeasure(p, room) }
                }
            }
            .onAppear {
                if !free { takeInPlumbPoints(pid, rid); applyPPending(app, pid) }
            }
        }
    }

    private func title(_ p: Project, _ c: PCtx?, _ room: Room?) -> String {
        if let f = c?.free { let nm = dn(f.name); return nm.trimmingCharacters(in: .whitespaces).isEmpty ? tr(pKindKey(f.kind)) : nm }
        if let room { return pRoomName(p, room) }
        return ""
    }

    private func bar(_ p: Project, _ c: PCtx?, _ room: Room?, _ free: Bool) -> some View {
        HStack(spacing: 6) {
            GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
            BarTitle(title: title(p, c, room), eyebrow: dn(p.name)).frame(maxWidth: .infinity, alignment: .leading)
            if let room { GlassIconButton("edit", tr("common.edit")) { openRoom(app, p.id, room.id) } }
            if let c, !free {
                GlassIconButton("sliders", tr("el.roomSet")) { app.sheet = .pRoomSet(pid: p.id, rid: c.id) }.padding(.leading, 2)
            }
            if let f = c?.free {
                GlassIconButton("sliders", tr("el.freeEdit")) { app.sheet = .pFree(pid: p.id, fid: f.id) }.padding(.leading, 2)
            }
        }
        .padding(.trailing, 12).frame(minHeight: 64)
        .background(barTint.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
    }

    private func needMeasure(_ p: Project, _ room: Room?) -> some View {
        VStack(spacing: 14) {
            T(tr("tl.needMeasure"), ui(16, 700, G.ink, lh: 1.35), align: .center)
            if let room { GBtn(tr("ns.measureB"), fill: false) { openRoom(app, p.id, room.id) } }
        }
        .padding(24).frame(maxWidth: .infinity)
    }

    @ViewBuilder private func content(_ p: Project, _ c: PCtx, _ room: Room?, _ calc: PlumbCalc, _ free: Bool, _ h: CGFloat) -> some View {
        let wid = wall ?? c.g.walls.first?.id ?? "A"
        let fs = fixesIn(p, c)
        let pts = pointsIn(p, c, fs)
        let runs = runsIn(calc.routes, rid)
        let warns = calc.warns.filter { $0.roomId == rid || $0.roomId == nil }
        let bad = Set(warns.compactMap(\.target))
        let layers = Set(layerS)
        let rs = calc.routes.riser
        let loop = calc.routes.loops.first { $0.roomId == c.id }
        Seg(items: [("3d", "3D"), ("plan", tr("ed.plan")), ("wall", tr("el.wallV"))], cur: mode) { mode = $0 }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        Group {
            switch mode {
            case "plan": PVPlanView(app: app, p: p, c: c, fs: fs, pts: pts, rs: rs, runs: runs, loop: loop, layers: layers, bad: bad, locked: free)
            case "wall": PVWallView(app: app, p: p, c: c, wid: wid, fs: fs, pts: pts, rs: rs, runs: runs, layers: layers, bad: bad, locked: free)
            default: PVRoom3D(app: app, p: p, c: c, room: room)
            }
        }
        .frame(height: max(160, h * 0.46))
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if mode == "wall" { wallChips(c, wid) }
                if mode != "3d" { layerChips() }
                PVLegend(kinds: Set(runs.map(\.kind) + pts.map(\.t)), loops: calc.routes.loops.contains { $0.roomId == c.id && $0.n > 0 })
                if !warns.isEmpty { PVWarnings(app: app, p: p, c: c, ws: warns) }
                if free { PVFreeCard(app: app, p: p, c: c) }
                else { PVFixtures(app: app, p: p, c: c, fs: fs, pts: pts, bad: bad, wall: mode == "wall" ? wid : nil) }
                if !free { addButtons(p, c, wid) }
                if !free { PVRiserCard(app: app, p: p, c: c, rs: rs) }
                PVHeatCard(p: p, c: c, calc: calc)
                if AppSettings.shared.advanced {
                    PVRoomCount(c: c, runs: runs, calc: calc)
                    PCountCard(p: p, c: calc.count)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 28)
        }
    }

    @ViewBuilder private func addButtons(_ p: Project, _ c: PCtx, _ wid: String) -> some View {
        let onWall: String? = mode == "wall" ? wid : nil
        let ptWall: String = mode == "wall" ? wid : (c.g.walls.first?.id ?? "A")
        HStack(spacing: 8) {
            dashed("plus", tr("sx.addFix"), "pv.addFix") { app.sheet = .pFix(pid: p.id, rid: c.id, fid: nil, wall: onWall) }
            dashed("layers", tr("el.addKit"), "pv.addKit") { app.push(.pGallery(pid: p.id, rid: c.id)) }
        }
        T(tr("sx.addPt"), ui(14, 700, G.cobalt2)).padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .pressable(0.97) { app.sheet = .pPoint(pid: p.id, rid: c.id, ptId: nil, wall: ptWall) }
            .accessibilityAddTraits(.isButton).accessibilityIdentifier("pv.addPt")
    }

    private func wallChips(_ c: PCtx, _ wid: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(c.g.walls.map(\.id), id: \.self) { id in
                    let len = c.g.wall(id)?.len ?? 0
                    FChip(label: tr("tl.wallN", ["w": id]) + " · " + Geo.fmtLen(tInt(len), .m, pvEn), on: id == wid) { wall = id }
                }
            }
        }
    }

    private func layerChips() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(P_LAYERS, id: \.self) { k in
                    FChip(label: tr("sx.l." + k), on: layerS.contains(k)) { toggleLayer(k) }
                }
            }
        }
    }

    private func toggleLayer(_ k: String) {
        let cur = layerS
        if cur.contains(k) { layerS = cur.filter { $0 != k } }
        else { layerS = P_LAYERS.filter { cur.contains($0) || $0 == k } }
    }

    private func dashed(_ icon: String, _ label: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) { MIcon(icon, G.cobalt2, 20, 2.2); T(label, ui(15, 700, G.cobalt2), lines: 1) }
            .frame(maxWidth: .infinity).frame(height: 54)
            .dashedGlass(20)
            .pressable(0.98, action)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(id)
    }
}

/// The room in 3D with its fixtures and pipes, the picture's buttons over it.
private struct PVRoom3D: View {
    let app: AppModel
    let p: Project
    let c: PCtx
    let room: Room?
    @State private var cam = Cam3D()
    @State private var shot = Shot3D()
    @State private var taking = false
    @State private var pb = PlumbShellBox()
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let r = room ?? c.room
        let made = pb.shell(p, r, snap)
        let shell = made.0
        Scene3D(shell: shell, key: made.1, cam: cam, shot: shot, points: shell.labels.map(\.p), label: { AnyView(Lbl3D(text: shell.labels[$0].text)) }) {
            if room != nil {
                ShotPill(icon: "camera", label: tr("3d.save")) { save() }
                    .accessibilityIdentifier("3d.save")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 10).padding(.trailing, 10)
            }
            HStack(spacing: 8) {
                ForEach([("3d.top", true), ("3d.corner", false)], id: \.0) { k, top in
                    T(tr(k), ui(13, 700), lines: 1).padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.sheet(0.7)))
                        .pressable(0.97) { cam.preset(top: top) }
                        .accessibilityIdentifier(k)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(10)
        }
    }

    /// "Add to report": at most 4 views a room, counted in the store; a second tap while a picture is taken does nothing.
    private func save() {
        guard let r = room else { return }
        let pid = p.id, rid = r.id
        func full() -> Bool { (Store.shared.get(pid)?.rooms.first { $0.id == rid }?.views.count ?? 4) >= 4 }
        if taking { return }
        // a double tap takes one picture, not two alike
        if !app.once() { return }
        if full() { app.say("3d.max", kind: .error); return }
        taking = true
        shot.take { img in
            DispatchQueue.main.async {
                taking = false
                if full() { app.say("3d.max", kind: .error); return }
                let id = uid()
                guard let img, let file = ViewFiles.save(id, img) else { app.say("3d.fail", kind: .error); return }
                Store.shared.update(pid) { pp in
                    if let i = pp.rooms.firstIndex(where: { $0.id == rid }), pp.rooms[i].views.count < 4 { pp.rooms[i].views.append(View3D(id: id, img: file, ts: nowMs())) }
                }
                app.say("3d.saved")
            }
        }
    }
}

/* ---------------- dragging ---------------- */

/// What is being dragged: a fixture's or outlet's id or "riser", the wall it lands on, along it, (an outlet's) height.
private struct PVDrag: Equatable {
    let id: String
    let wall: String
    let off: Int
    var h = 0
}

private func pvDist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

/// The fixtures, outlets and riser as they would be with d dropped.
private func pvMoved(_ d: PVDrag?, _ fs: [PlFix], _ pts: [APt], _ rs: PlRiser?) -> ([PlFix], [APt], PlRiser?) {
    guard let d else { return (fs, pts, rs) }
    if d.id == "riser" {
        var r = rs
        r?.wall = d.wall; r?.off = d.off
        return (fs, pts, r)
    }
    if let f = fs.first(where: { $0.id == d.id }) {
        let g = moveFix(f, d.wall, d.off)
        let nfs = fs.map { $0.id == d.id ? g : $0 }
        let npts = pts.filter { $0.fix != f.id } + fixPoints(g)
        return (nfs, npts, rs)
    }
    let npts = pts.map { (q: APt) -> APt in
        if q.id != d.id || q.fix != nil { return q }
        return APt(id: q.id, t: q.t, roomId: q.roomId, wall: d.wall, off: d.off, h: d.h, d: q.d, fix: nil, usual: nil, tol: 0)
    }
    return (fs, npts, rs)
}

/// Saves a drag.
private func pvDropDrag(_ pid: String, _ d: PVDrag) {
    if d.id == "riser" {
        updatePlumb(pid) { e in e.riser?.wall = d.wall; e.riser?.off = d.off }
    } else if Store.shared.get(pid)?.plumb.fixes.contains(where: { $0.id == d.id }) == true {
        updateFix(pid, d.id) { $0.wall = d.wall; $0.off = d.off }
    } else {
        updatePt(pid, d.id) { $0.wall = d.wall; $0.off = d.off; $0.h = d.h }
    }
}

/// Opens what was tapped: the riser's pipe system, a fixture, a loose outlet.
private func pvOpen(_ app: AppModel, _ pid: String, _ rid: String, _ hit: String, _ fs: [PlFix]) {
    if hit == "riser" { app.sheet = .pSystem(pid: pid) }
    else if fs.contains(where: { $0.id == hit }) { app.sheet = .pFix(pid: pid, rid: rid, fid: hit) }
    else { app.sheet = .pPoint(pid: pid, rid: rid, ptId: hit) }
}

/* ---------------- from above ---------------- */

private struct PVPlanView: View {
    let app: AppModel
    let p: Project
    let c: PCtx
    let fs: [PlFix]
    let pts: [APt]
    let rs: PlRiser?
    let runs: [PRun]
    let loop: PLoop?
    let layers: Set<String>
    let bad: Set<String>
    let locked: Bool
    @State private var drag: PVDrag? = nil
    @State private var grab: String? = nil
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            let m = EPlanMap(c.g.floor, CGRect(origin: .zero, size: geo.size), 26)
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, _ in draw(ctx, m) }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in changed(v, m) }.onEnded { v in ended(v, m) })
                T(tr(locked ? "el.planFree" : "sx.planDrag"), ui(11.5, 600, G.ink3)).padding(10).allowsHitTesting(false)
            }
        }
        .background(Color(argb: 0xFFF6F8FC))
    }

    private func draw(_ ctx: GraphicsContext, _ m: EPlanMap) {
        let shown = pvMoved(drag, fs, pts, rs)
        let sf = shown.0, sp = shown.1, sr = shown.2
        let rr: [PRun] = drag == nil ? runs : []
        let sel = drag?.id
        let c = self.c, loop = self.loop, layers = self.layers, bad = self.bad
        ctx.withCGContext { cg in
            drawPlumbPlan(cg, c, m, sf, sp, sr, rr, loop, 9, layers: layers, sel: sel, bad: bad)
        }
    }

    /// The nearest thing to pos: a loose outlet, the riser, a fixture.
    private func hit(_ m: EPlanMap, _ pos: CGPoint, _ reach: CGFloat) -> String? {
        var best: String? = nil
        var bd = CGFloat.greatestFiniteMagnitude
        func consider(_ id: String, _ d: CGFloat) { if d < bd { bd = d; best = id } }
        for q in pts where q.fix == nil {
            guard let w = c.wall(q.wall) else { continue }
            consider(q.id, pvDist(m.at(w.at(Double(q.off), 30)), pos) - 6)
        }
        if let r = rs, r.roomId == c.id, let w = c.wall(r.wall) {
            consider("riser", pvDist(m.at(w.at(Double(r.off), Double(RISER_D) / 2)), pos))
        }
        for f in fs {
            guard let w = c.wall(f.wall) else { continue }
            let at = m.at(w.at(Double(f.off), Double(fixD(f)) / 2))
            let half = CGFloat(Double(min(fixW(f), fixD(f))) / 2 * m.k)
            consider(f.id, pvDist(at, pos) - min(half, 24))
        }
        return bd < reach ? best : nil
    }

    private func changed(_ v: DragGesture.Value, _ m: EPlanMap) {
        if locked { return }
        if !started {
            started = true
            grab = hit(m, v.startLocation, 34)
        }
        guard let g = grab, hypot(v.translation.width, v.translation.height) > 4 else { return }
        let q = m.back(v.location)
        if g == "riser" {
            guard let r = rs else { return }
            let nw = nearestWall(c.g.walls, q)
            let s = snapRiser(c, r, nw.0.id, tInt(nw.1))
            drag = PVDrag(id: "riser", wall: s.wall, off: s.off)
        } else if let f = fs.first(where: { $0.id == g }) {
            let s = snapFixPlan(c, f, q, fs, rs)
            drag = PVDrag(id: g, wall: s.0, off: s.1)
        } else if let pt = pts.first(where: { $0.id == g }) {
            let nw = nearestWall(c.g.walls, q)
            let lp = PlPoint(id: pt.id, t: pt.t, roomId: c.id, wall: nw.0.id, off: pt.off, h: pt.h)
            let s = snapPoint(c, lp, tInt(nw.1), pt.h)
            drag = PVDrag(id: g, wall: nw.0.id, off: s.0, h: s.1)
        }
    }

    private func ended(_ v: DragGesture.Value, _ m: EPlanMap) {
        let moved = hypot(v.translation.width, v.translation.height) > 4
        let d = drag
        drag = nil; grab = nil; started = false
        if locked { return }
        if !moved {
            if let h = hit(m, v.startLocation, 28) { pvOpen(app, p.id, c.id, h, fs) }
            return
        }
        if let d { pvDropDrag(p.id, d) }
    }
}

/* ---------------- a wall straight on ---------------- */

private struct PVWallView: View {
    let app: AppModel
    let p: Project
    let c: PCtx
    let wid: String
    let fs: [PlFix]
    let pts: [APt]
    let rs: PlRiser?
    let runs: [PRun]
    let layers: Set<String>
    let bad: Set<String>
    let locked: Bool
    @State private var drag: PVDrag? = nil
    @State private var grab: String? = nil
    @State private var started = false

    var body: some View {
        let w = c.wall(wid) ?? c.g.walls[0]
        GeometryReader { geo in
            let m = EWallMap(w.len, c.g.H, CGRect(origin: .zero, size: geo.size), 18, 22)
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, _ in draw(ctx, w, m) }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in changed(v, w, m) }.onEnded { v in ended(v, w, m) })
                T(tr(locked ? "el.planFree" : "sx.wallDrag"), ui(11.5, 600, G.ink3)).padding(.leading, 10).padding(.bottom, 2).allowsHitTesting(false)
            }
        }
        .background(Color(argb: 0xFFF6F8FC))
        .id(w.id)
    }

    private func draw(_ ctx: GraphicsContext, _ w: TWall, _ m: EWallMap) {
        let shown = pvMoved(drag, fs, pts, rs)
        let sf = shown.0, sp = shown.1, sr = shown.2
        let rr: [PRun] = drag == nil ? runs : []
        let sel = drag?.id
        let c = self.c, layers = self.layers, bad = self.bad
        let riserWord = tr("sx.riser")
        let isEn = pvEn
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: uiColor(0x334155)]
        let label: (String) -> NSAttributedString = { s in
            let text = s == "riser" ? riserWord : Geo.fmtLen(Int(s), .m, isEn)
            return NSAttributedString(string: text, attributes: attrs)
        }
        ctx.withCGContext { cg in
            drawPlumbWall(cg, c, w, m, sf, sp, sr, rr, label, layers: layers, sel: sel, bad: bad, minR: 7)
        }
    }

    /// The nearest thing to pos on this wall: a loose outlet, the riser, a fixture.
    private func hit(_ w: TWall, _ m: EWallMap, _ pos: CGPoint, _ reach: CGFloat) -> String? {
        var best: String? = nil
        var bd = CGFloat.greatestFiniteMagnitude
        func consider(_ id: String, _ d: CGFloat) { if d < bd { bd = d; best = id } }
        for q in pts where q.fix == nil && q.wall == w.id {
            consider(q.id, pvDist(m.at(Double(q.off), Double(q.h)), pos) - 6)
        }
        if let r = rs, r.roomId == c.id, r.wall == w.id {
            let x = m.x(Double(r.off))
            if pos.y >= m.y(c.g.H) && pos.y <= m.y(0) { consider("riser", abs(pos.x - x)) }
        }
        for f in fs where f.wall == w.id {
            let half = Double(fixW(f)) / 2
            let x0 = m.x(Double(f.off) - half), x1 = m.x(Double(f.off) + half)
            let y0 = m.y(Double(fixTop(f))), y1 = m.y(Double(fixZ0(f)))
            let dx: CGFloat = max(0, x0 - pos.x, pos.x - x1)
            let dy: CGFloat = max(0, y0 - pos.y, pos.y - y1)
            consider(f.id, hypot(dx, dy) + 2)
        }
        return bd < reach ? best : nil
    }

    private func changed(_ v: DragGesture.Value, _ w: TWall, _ m: EWallMap) {
        if locked { return }
        if !started {
            started = true
            grab = hit(w, m, v.startLocation, 34)
        }
        guard let g = grab, hypot(v.translation.width, v.translation.height) > 4 else { return }
        let rawOff = tInt((Double(v.location.x) - m.x0) / m.k)
        let rawH = tInt((m.yF - Double(v.location.y)) / m.k)
        if g == "riser" {
            guard let r = rs else { return }
            let s = snapRiser(c, r, w.id, rawOff)
            drag = PVDrag(id: "riser", wall: s.wall, off: s.off)
        } else if let f = fs.first(where: { $0.id == g }) {
            if let x = snapFix(c, f, w.id, rawOff, fs, rs) { drag = PVDrag(id: g, wall: w.id, off: x) }
            else { drag = PVDrag(id: g, wall: f.wall, off: f.off) }
        } else if let pt = pts.first(where: { $0.id == g }) {
            let lp = PlPoint(id: pt.id, t: pt.t, roomId: c.id, wall: w.id, off: pt.off, h: pt.h)
            let s = snapPoint(c, lp, rawOff, rawH)
            drag = PVDrag(id: g, wall: w.id, off: s.0, h: s.1)
        }
    }

    private func ended(_ v: DragGesture.Value, _ w: TWall, _ m: EWallMap) {
        let moved = hypot(v.translation.width, v.translation.height) > 4
        let d = drag
        drag = nil; grab = nil; started = false
        if locked { return }
        if !moved {
            if let h = hit(w, m, v.startLocation, 26) { pvOpen(app, p.id, c.id, h, fs) }
            return
        }
        if let d { pvDropDrag(p.id, d) }
    }
}

/* ---------------- under the picture ---------------- */

/// The pipes' colours in this room, the underfloor loops' too.
private struct PVLegend: View {
    let kinds: Set<String>
    let loops: Bool
    var body: some View {
        let ks = ["cold", "hot", "drain", "hs", "hr"].filter { kinds.contains($0) }
        if !ks.isEmpty || loops {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ks, id: \.self) { k in item(kindRgb(k), k == "drain" ? 6 : 4, tr("sx.o." + k)) }
                    if loops { item(UFH_RGB, 4, tr("sx.s.ufh")) }
                }
            }
        }
    }

    private func item(_ rgb: Int, _ h: CGFloat, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(eColor(rgb)).frame(width: 16, height: h)
            T(label, ui(12, 600, G.ink2), lines: 1)
        }
    }
}

private struct PVWarnings: View {
    let app: AppModel
    let p: Project
    let c: PCtx
    let ws: [PWarn]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { MIcon("alert", G.amberInk, 18, 2); T(tr("el.warnN", ["n": ws.count]), ui(15, 800, G.amberInk)) }
            ForEach(Array(ws.enumerated()), id: \.offset) { _, w in line(w) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.amberWash))
    }

    /// The fixture or outlet a warning is about, in words.
    private func who(_ w: PWarn, _ f: PlFix?, _ pt: PlPoint?) -> String? {
        if let f { return tr("sx.t." + f.t) + " · " + tr("tl.wallN", ["w": f.wall]) }
        if let pt { return tr("sx.o." + pt.t) + " · " + tr("tl.wallN", ["w": pt.wall]) }
        if c.free != nil, let id = w.target, let x = fixesIn(p, c).first(where: { $0.id == id }) { return tr("sx.t." + x.t) }
        return nil
    }

    @ViewBuilder private func line(_ w: PWarn) -> some View {
        let f = w.target.flatMap { id in p.plumb.fixes.first { $0.id == id } }
        let pt: PlPoint? = f == nil ? w.target.flatMap { id in p.plumb.points.first { $0.id == id } } : nil
        let lead = who(w, f, pt).map { $0 + ": " } ?? ""
        let t = T(lead + warnText(w), ui(13, 500, G.ink, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
        if let f {
            t.contentShape(Rectangle()).pressable(0.99) { app.sheet = .pFix(pid: p.id, rid: f.roomId, fid: f.id) }.accessibilityAddTraits(.isButton)
        } else if let pt {
            t.contentShape(Rectangle()).pressable(0.99) { app.sheet = .pPoint(pid: p.id, rid: pt.roomId, ptId: pt.id) }.accessibilityAddTraits(.isButton)
        } else { t }
    }
}

private struct PVFixtures: View {
    let app: AppModel
    let p: Project
    let c: PCtx
    let fs: [PlFix]
    let pts: [APt]
    let bad: Set<String>
    let wall: String?
    var body: some View {
        let list = wall.map { w in fs.filter { $0.wall == w } } ?? fs
        let loose = ordered(pts.filter { $0.fix == nil && (wall == nil || $0.wall == wall!) })
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                T(wall.map { tr("el.onWall", ["w": $0]) } ?? tr("sx.fixes"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(fixSummary(list), ui(12, 500, G.ink2), align: .trailing, lines: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            if list.isEmpty && loose.isEmpty {
                T(tr("sx.noFix"), ui(13.5, 400, G.ink2)).padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(byCat(list)) { f in fixRow(f) }
            if !loose.isEmpty {
                T(tr("sx.loose"), ui(13, 700, G.ink2)).padding(.leading, 14).padding(.top, 6)
                ForEach(loose, id: \.id) { q in ptRow(q) }
            }
        }
        .padding(.vertical, 6)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }

    /// The fixtures by group, then by wall and place along it.
    private func byCat(_ list: [PlFix]) -> [PlFix] {
        var out: [PlFix] = []
        for cat in FIX_CATS {
            let xs = list.enumerated().filter { fixType($0.element.t).cat == cat }
            let sorted = xs.sorted { a, b in
                if a.element.wall != b.element.wall { return a.element.wall < b.element.wall }
                if a.element.off != b.element.off { return a.element.off < b.element.off }
                return a.offset < b.offset
            }
            out += sorted.map(\.element)
        }
        return out
    }

    /// The loose outlets by wall and place along it.
    private func ordered(_ xs: [APt]) -> [APt] {
        let sorted = xs.enumerated().sorted { a, b in
            if a.element.wall != b.element.wall { return a.element.wall < b.element.wall }
            if a.element.off != b.element.off { return a.element.off < b.element.off }
            return a.offset < b.offset
        }
        return sorted.map(\.element)
    }

    private func fixTitle(_ f: PlFix) -> String {
        let base = tr("sx.t." + f.t)
        if f.t != "rad" { return base }
        return base + " · " + Geo.fmtLen(fixW(f), .m, pvEn) + U_M
    }

    private func fixSub(_ f: PlFix) -> String {
        let outs = f.pts.map { tr("sx.o." + $0.t) + " " + Geo.fmtLen($0.h, .m, pvEn) }.joined(separator: ", ")
        return tr("tl.wallN", ["w": f.wall]) + " · " + outs
    }

    private func fixRow(_ f: PlFix) -> some View {
        let isBad = bad.contains(f.id)
        return HStack(spacing: 10) {
            FixSymbolView(t: f.t, ink: isBad ? 0xDC2626 : P_INK_RGB, k: 2.3).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                T(fixTitle(f), ui(14, 700, isBad ? G.amberInk : G.ink), lines: 1)
                T(fixSub(f), ui(12, 400, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 14, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 4).frame(minHeight: 50)
        .contentShape(Rectangle())
        .pressable(0.99) { app.sheet = .pFix(pid: p.id, rid: c.id, fid: f.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func ptRow(_ q: APt) -> some View {
        let name = tr("sx.o." + q.t) + (q.t == "drain" ? " Ø\(drainD(q.d))" : "")
        let sub = tr("tl.wallN", ["w": q.wall]) + " · " + tr("el.atH", ["h": Geo.fmtLen(q.h, .m, pvEn)])
        return HStack(spacing: 10) {
            PtSymbolView(t: q.t, k: 4).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                T(name, ui(14, 700), lines: 1)
                T(sub, ui(12, 400, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 14, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 4).frame(minHeight: 46)
        .contentShape(Rectangle())
        .pressable(0.99) { app.sheet = .pPoint(pid: p.id, rid: c.id, ptId: q.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A room typed by size: what it has, and the button that changes it.
private struct PVFreeCard: View {
    let app: AppModel
    let p: Project
    let c: PCtx
    var body: some View {
        if let f = c.free {
            let size = Geo.fmtLen(f.L, .m, pvEn) + " × " + Geo.fmtLen(f.W, .m, pvEn) + " × " + Geo.fmtLen(f.H, .m, pvEn) + U_M
            let all: [(String, Int)] = [("wc", f.wc), (f.small ? "bsm" : "bs", f.basin), ("bath", f.bath), (f.cabin ? "cab" : "sh", f.shower), ("sink", f.sink),
                                        ("wm", f.wm), ("dw", f.dw), ("wh", f.wh), ("gb", f.gb), ("rad", f.rad), ("tr", f.tr)]
            let counts = all.filter { $0.1 > 0 }
            VStack(alignment: .leading, spacing: 6) {
                T(tr("el.freeT"), ui(15, 800))
                EKv(k: tr("el.size"), v: size)
                ForEach(counts, id: \.0) { k, n in EKv(k: tr("sx.t." + k), v: "\(n)") }
                if f.ufh { EKv(k: tr("sx.s.ufh"), v: "✓") }
                EKv(k: tr("sx.freeLink"), v: Geo.fmtLen(f.link, .m, pvEn) + U_M)
                T(tr("sx.freeNote"), ui(12.5, 400, G.ink2, lh: 1.4))
                GBtn(tr("fz.change"), kind: .secondary, icon: "edit", height: 44, corner: 14, fontSize: 14) { app.sheet = .pFree(pid: p.id, fid: f.id) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
        }
    }
}

/// The riser: here (drag it on the plan or the wall), or in another room, with the button that brings it here.
private struct PVRiserCard: View {
    let app: AppModel
    let p: Project
    let c: PCtx
    let rs: PlRiser?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RiserSymbolView(hot: rs?.hot ?? true).frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    T(tr("sx.riser"), ui(15, 800))
                    T(sub() + " · " + tr("sx.riserKit"), ui(12.5, 400, G.ink2, lh: 1.35))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if rs?.roomId != c.id {
                GBtn(tr("sx.riserMove"), kind: .secondary, icon: "box", height: 44, corner: 14, fontSize: 14) { bringHere() }
            } else {
                T(tr("sx.riserDrag"), ui(12.5, 400, G.ink2, lh: 1.35))
            }
            GBtn(tr("sx.system"), kind: .secondary, icon: "layers", height: 44, corner: 14, fontSize: 14) { app.sheet = .pSystem(pid: p.id) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }

    private func sub() -> String {
        guard let rs else { return tr("sx.riserNone") }
        if rs.roomId == c.id { return tr("sx.riserAt", ["w": rs.wall]) }
        let name = p.rooms.first { $0.id == rs.roomId }.map { pRoomName(p, $0) } ?? ""
        return tr("el.panelIn", ["r": name])
    }

    private func bringHere() {
        var d = riserIn(c, p.plumb.fixes)
        d.hot = rs?.hot ?? true
        updatePlumb(p.id) { $0.riser = d }
        app.say("sx.riserSet")
    }
}

/// The heating in this room: the radiators and their heat against the room's need, the underfloor loops.
private struct PVHeatCard: View {
    let p: Project
    let c: PCtx
    let calc: PlumbCalc
    var body: some View {
        let rads = fixesIn(p, c).filter { $0.t == "rad" }
        let loop = calc.routes.loops.first { $0.roomId == c.id }
        if !rads.isEmpty || loop != nil {
            let need = tr("sx.watts", ["w": tInt(c.areaM2 * Double(W_M2)), "a": pvD1(c.areaM2)])
            let radW = rads.reduce(0) { $0 + radWatts($1) }
            VStack(alignment: .leading, spacing: 6) {
                T(tr("sx.s.heat"), ui(15, 800))
                EKv(k: tr("sx.heatNeed"), v: need)
                if !rads.isEmpty { EKv(k: tr("sx.t.rad"), v: tr("sx.radsV", ["n": rads.count, "w": radW])) }
                if let loop { loopLines(loop) }
                if calc.routes.heat == nil { T(tr("sx.w.noBoiler"), ui(12.5, 500, G.amberInk, lh: 1.35)) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
        }
    }

    @ViewBuilder private func loopLines(_ loop: PLoop) -> some View {
        let v = tr("sx.loopV", ["n": loop.n, "s": loop.step / 10, "a": pvD1(loop.area)])
        let more = loop.n > 1 ? " × \(loop.n)" : ""
        EKv(k: tr("sx.s.ufh"), v: v)
        // the loop's length is the advanced app's (a count for buying)
        if AppSettings.shared.advanced { EKv(k: tr("sx.loopLen"), v: pvD1(loop.each / 1000) + U_M + more) }
    }
}

/// The pipe in this room by kind (the advanced app).
private struct PVRoomCount: View {
    let c: PCtx
    let runs: [PRun]
    let calc: PlumbCalc
    var body: some View {
        if !runs.isEmpty {
            let ks = ["cold", "hot", "drain", "hs", "hr"].filter { k in runs.contains { $0.kind == k } }
            let ds = calc.routes.drains.filter { $0.pt.roomId == c.id }
            VStack(alignment: .leading, spacing: 6) {
                T(tr("sx.roomPipe"), ui(15, 800))
                ForEach(ks, id: \.self) { k in row(k) }
                if !ds.isEmpty { T(slope(ds), ui(12, 400, G.ink3, lh: 1.35)) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
        }
    }

    private func slope(_ ds: [PDrain]) -> String {
        let s = ds.map(\.slope).min() ?? 0
        let m = ds.map(\.horiz).max() ?? 0
        return tr("sx.slopeV", ["s": pvD1(s / 10), "m": pvD1(m / 1000)])
    }

    private func row(_ k: String) -> some View {
        let rs = runs.filter { $0.kind == k }
        let dia = rs.map(\.dia).max() ?? 0
        let len = rs.reduce(0.0) { $0 + $1.len } / 1000
        return HStack(spacing: 10) {
            Circle().fill(eColor(kindRgb(k))).frame(width: 12, height: 12)
            T(tr("sx.o." + k) + " · Ø\(dia)", ui(14, 600)).frame(maxWidth: .infinity, alignment: .leading)
            T(pvD1(len) + U_M, num(13.5, 700))
        }
    }
}
