import SwiftUI
import Observation

/*
 * A room's tiles (Android ui/tiles/TView.kt): the room in 3D with every tile of its layouts at its true place (or its
 * plan from above, where the floor's start point is dragged and the tray and bath are marked), the layouts under it, the
 * extras, and in the advanced app what it all takes. A layout without a room shows its typed surface the same way.
 */

private var en: Bool { AppSettings.shared.lang == .en }

/// The room's 3D with its layouts' tiles, worked out away from the screen's thread: until it is ready the room shows as
/// it was (without tiles the first time).
@Observable final class TileShellBox {
    private(set) var made: (Shell3D, String)? = nil
    @ObservationIgnored private var want = ""

    /// The shell to show for room r of order p and the key it is drawn by; starts working out a new one when they changed.
    func shell(_ p: Project, _ r: Room, _ base: Shell3D, _ snap: Bool) -> (Shell3D, String) {
        let ls = p.tiles.filter { $0.roomId == r.id }
        let fixes = tileRoomOf(p, r.id).fixes
        if ls.isEmpty && fixes.isEmpty { return (base, shellKey([r], snap)) }
        let k = shellKey([r], snap) + "|tiles|\(ls)|\(fixes)|\(p.tiles.count)|\(floorLayout(p.tiles, r.id)?.id ?? "")"
        if k != want {
            want = k
            let all = p.tiles
            DispatchQueue.global(qos: .userInitiated).async {
                let s = tileShell(r, base, snap, ls, fixes, all)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.want == k else { return }
                    self.made = (s, k)
                }
            }
        }
        if let m = made, m.1 == k { return m }
        return made ?? (base, shellKey([r], snap))
    }
}

/// The room's scene with the tiles of layouts ls, its tray and bath.
func tileShell(_ r: Room, _ base: Shell3D, _ snap: Bool, _ ls: [TileLayout], _ fixes: [TFix], _ all: [TileLayout]) -> Shell3D {
    if ls.isEmpty && fixes.isEmpty { return base }
    guard let w0 = Geo.walls(r, snap).first, let b = base.bases[w0.id] else { return base }
    // where the plan's corner is in the scene
    guard let g = roomGeo(r, snap, fixes, b.ox - w0.p0.x / 1000, b.oz - w0.p0.y / 1000) else { return base }
    return base.plus(tileParts(ls, g, all), [])
}

struct TViewScreen: View {
    let app: AppModel
    let pid: String
    let rid: String?
    let lid: String?
    @State private var mode = "3d"
    @State private var sel: String? = nil

    var body: some View {
        if let p = Store.shared.get(pid) {
            let snap = AppSettings.shared.angleSnap
            let room = rid.flatMap { id in p.rooms.first { $0.id == id } }
            let panel: TileLayout? = rid == nil ? p.tiles.first(where: { $0.id == lid }) : nil
            if room != nil || panel != nil {
                let ls = room.map { r in p.tiles.filter { $0.roomId == r.id } } ?? (panel.map { [$0] } ?? [])
                let cur = sel ?? lid ?? ls.first?.id
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        bar(p, room, panel, snap)
                        picture(p, room, panel, ls, cur, snap).frame(height: geo.size.height * 0.48)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(ls) { l in TLayoutCard(app: app, p: p, l: l, on: l.id == cur) { sel = l.id } }
                                below(p, room, panel)
                            }
                            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 28)
                        }
                    }
                }
            }
        }
    }

    private func bar(_ p: Project, _ room: Room?, _ panel: TileLayout?, _ snap: Bool) -> some View {
        let title: String
        if let r = room { title = p.floors.first { $0.id == r.floorId }.map { floorName($0) } ?? dn(r.name) }
        else { title = panel.map { tr(placeKey($0)) } ?? "" }
        return HStack(spacing: 6) {
            GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
            BarTitle(title: title, eyebrow: dn(p.name)).frame(maxWidth: .infinity, alignment: .leading)
            if let room, Geo.ready3D(room, snap) {
                // the room itself: its sizes, doors and windows
                GlassIconButton("edit", tr("common.edit")) { openRoom(app, p.id, room.id) }
                ModeSeg(cur: mode) { mode = $0 }
            }
        }
        .padding(.trailing, 12).frame(minHeight: 64)
        .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
    }

    @ViewBuilder private func picture(_ p: Project, _ room: Room?, _ panel: TileLayout?, _ ls: [TileLayout], _ cur: String?, _ snap: Bool) -> some View {
        if let room, !Geo.ready3D(room, snap) {
            VStack(spacing: 14) {
                T(tr("tl.needMeasure"), ui(16, 700, G.ink, lh: 1.35), align: .center)
                GBtn(tr("ns.measureB"), fill: false) { openRoom(app, p.id, room.id) }
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let room, mode == "plan" {
            TRoomPlan(app: app, p: p, r: room, ls: ls, sel0: ls.first { $0.id == cur }, snap: snap)
        } else if let room {
            TRoom3D(app: app, p: p, r: room)
        } else if let panel {
            TPanel3D(l: panel)
        }
    }

    @ViewBuilder private func below(_ p: Project, _ room: Room?, _ panel: TileLayout?) -> some View {
        let adv = AppSettings.shared.advanced
        if let room {
            HStack(spacing: 8) { MIcon("plus", G.cobalt2, 20, 2.2); T(tr("tl.addLayout"), ui(15, 700, G.cobalt2)) }
                .frame(maxWidth: .infinity).frame(height: 54)
                .dashedGlass(20)
                .pressable(0.98) { app.push(.tGallery(pid: p.id, rid: room.id)) }
                .accessibilityIdentifier("tv.addLayout")
            TExtras(app: app, p: p, r: room, ls: p.tiles.filter { $0.roomId == room.id })
            if adv { CountCard(c: TileCountCache.shared.of(p, room.id), title: tr("tl.countRoom")) }
        } else if adv, let panel {
            CountCard(c: countLayout(p, panel, AppSettings.shared.angleSnap, tileGlueBase()), title: tr("tl.countT")) { app.sheet = .tCount(pid: p.id, lid: panel.id) }
        }
    }
}

/// The room in 3D with its tiles, the picture's buttons over it.
private struct TRoom3D: View {
    let app: AppModel
    let p: Project
    let r: Room
    @State private var cam = Cam3D()
    @State private var shot = Shot3D()
    @State private var taking = false
    @State private var f3 = Furn3DCache()
    @State private var tb = TileShellBox()
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let base = f3.base(r, snap)
        let (shell, key) = tb.shell(p, r, base, snap)
        Scene3D(shell: shell, key: key, cam: cam, shot: shot, points: shell.labels.map(\.p), label: { AnyView(Lbl3D(text: shell.labels[$0].text)) }) {
            ShotPill(icon: "camera", label: tr("3d.save")) { save() }
                .accessibilityIdentifier("3d.save")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10).padding(.trailing, 10)
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
        let pid = p.id, rid = r.id
        func full() -> Bool { (Store.shared.get(pid)?.rooms.first { $0.id == rid }?.views.count ?? 4) >= 4 }
        if taking { return }
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

/// A layout without a room: its typed surface in 3D.
private struct TPanel3D: View {
    let l: TileLayout
    @State private var cam = Cam3D()
    @State private var cache = TPanelCache()
    var body: some View {
        if let shell = cache.get(l) {
            Scene3D(shell: shell, key: "panel|\(l)", cam: cam) { EmptyView() }
        } else {
            T(tr("tl.s.panelH"), ui(14, 500, G.ink2)).padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// A typed surface's 3D, built again only when its layout changes.
private final class TPanelCache {
    private var l: TileLayout? = nil
    private var s: Shell3D? = nil
    func get(_ x: TileLayout) -> Shell3D? {
        if let l, l == x { return s }
        l = x; s = panelScene(x)
        return s
    }
}

/* ---------------- the plan from above ---------------- */

/// The floor pieces of the room's floor layouts, laid again only when they change.
private final class TPlanCache {
    private var key: [TileLayout] = []
    private var room: Room? = nil
    private var out: [(TileLayout, Laid)] = []
    func get(_ floors: [TileLayout], _ g: TRoomGeo) -> [(TileLayout, Laid)] {
        if floors == key && room == g.room { return out }
        key = floors; room = g.room
        out = floors.map { l in (l, planFloorOnly(layRoom(l, g, nil, drawInset(l)))) }
        return out
    }
}

/// Only the floor's pieces of a laid layout (the plan shows the floor).
private func planFloorOnly(_ l: Laid) -> Laid {
    let keep = Set(l.surfs.indices.filter { l.surfs[$0].kind == "floor" })
    let surfs: [Surf] = l.surfs.enumerated().map { i, s in
        keep.contains(i) ? s : Surf(key: s.key, kind: s.kind, wall: s.wall, outline: [], holes: [], frame: s.frame, alt: s.alt)
    }
    return Laid(surfs: surfs, pieces: l.pieces.filter { keep.contains($0.s) }, tooMany: l.tooMany)
}

/// The plan's scale and offset for a room's floor in a box of size.
private struct PlanFit {
    let k: Double, cx: Double, cy: Double, x0: Double, y0: Double
    init(_ floor: [V2], _ size: CGSize) {
        let bx = tBoxOf(floor)
        let m = 28.0
        let w = max(1, bx.x1 - bx.x0), h = max(1, bx.y1 - bx.y0)
        let kk = max(1e-6, min((Double(size.width) - 2 * m) / w, (Double(size.height) - 2 * m) / h))
        k = kk
        cx = (Double(size.width) - w * kk) / 2; cy = (Double(size.height) - h * kk) / 2
        x0 = bx.x0; y0 = bx.y0
    }
    func at(_ q: V2) -> CGPoint { CGPoint(x: cx + (q.x - x0) * k, y: cy + (q.y - y0) * k) }
}

/// The room from above: its floor's tiles, the tray and bath, and the floor's start point to drag.
private struct TRoomPlan: View {
    let app: AppModel
    let p: Project
    let r: Room
    let ls: [TileLayout]
    let sel0: TileLayout?
    let snap: Bool
    @State private var drag: (Int, Int)? = nil
    @State private var from: (Int, Int)? = nil
    @State private var cache = TPlanCache()

    var body: some View {
        let fixes = tileRoomOf(p, r.id).fixes
        if let g = roomGeo(r, snap, fixes) {
            // the start point being dragged: the floor layout picked, or the room's first one
            let picked: TileLayout? = sel0.flatMap { (l: TileLayout) -> TileLayout? in l.surfs.contains(where: { $0.id == "floor" }) ? l : nil }
            let fl = picked ?? floorLayout(ls, r.id)
            let live: TileLayout? = fl.map { (l: TileLayout) -> TileLayout in
                guard let dr = drag else { return l }
                var x = l; x.ox = dr.0; x.oy = dr.1; return x
            }
            let floors = ls.filter { l in l.surfs.contains { $0.id == "floor" } }.map { l in l.id == live?.id ? live! : l }
            let laid = cache.get(floors, g)
            GeometryReader { geo in
                let fit = PlanFit(g.floor, geo.size)
                ZStack {
                    Canvas { ctx, size in drawPlan(ctx, size, g, laid, fixes, live, fit) }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 2).onChanged { v in
                            guard let fl else { return }
                            let st = from ?? drag ?? (fl.ox, fl.oy)
                            if from == nil { from = st }
                            let nx = Double(st.0) + Double(v.translation.width) / fit.k
                            let ny = Double(st.1) + Double(v.translation.height) / fit.k
                            drag = (Int((nx / 10).rounded()) * 10, Int((ny / 10).rounded()) * 10)
                        }.onEnded { _ in
                            if let fl, let dr = drag { updateLayout(p.id, fl.id) { $0.ox = dr.0; $0.oy = dr.1 } }
                            drag = nil; from = nil
                        })
                    T(fl != nil ? tr("tl.dragStart") : tr("tl.planNoFloor"), ui(11.5, 600, G.ink3))
                        .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).allowsHitTesting(false)
                    if let fl, fl.ox != 0 || fl.oy != 0 {
                        T(tr("tl.startReset"), ui(12.5, 700, G.cobalt2)).padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.sheet(0.7)))
                            .pressable(0.97) { updateLayout(p.id, fl.id) { $0.ox = 0; $0.oy = 0 } }
                            .padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
            }
            .background(Color(argb: 0xFFF6F8FC))
        }
    }

    private func drawPlan(_ ctx: GraphicsContext, _ size: CGSize, _ g: TRoomGeo, _ laid: [(TileLayout, Laid)], _ fixes: [TFix], _ live: TileLayout?, _ fit: PlanFit) {
        let outline = Path { pth in
            let o = g.floor.map { fit.at($0) }
            if let f = o.first { pth.move(to: f); for q in o.dropFirst() { pth.addLine(to: q) }; pth.closeSubpath() }
        }
        ctx.fill(outline, with: .color(Color(argb: 0xFFE9EDF3)))
        ctx.withCGContext { cg in
            for (l, ld) in laid { drawLaid(cg, ld, l, { _ in { q in fit.at(q) } }, ld.pieces.count < 500, outline: true) }
        }
        ctx.stroke(outline, with: .color(Color(argb: 0xFF0E1C36)), style: StrokeStyle(lineWidth: 5, lineJoin: .miter))
        // doors and windows on the walls
        for o in r.openings {
            guard let w = g.wall(o.wall) else { continue }
            let a = fit.at(w.at(Double(o.off))), b = fit.at(w.at(Double(o.off + o.w)))
            let seg = Path { pth in pth.move(to: a); pth.addLine(to: b) }
            if o.type == "door" {
                ctx.stroke(seg, with: .color(Color(argb: 0xFFF6F8FC)), lineWidth: 7)
                ctx.stroke(seg, with: .color(G.cobalt), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            } else {
                ctx.stroke(seg, with: .color(Color(argb: 0xFF9DB8E8)), lineWidth: 5)
            }
        }
        // the tray and the bath
        for f in fixes {
            guard let fp = footprint(g, f) else { continue }
            let o = fp.map { fit.at($0) }
            let box = Path { pth in pth.move(to: o[0]); for q in o.dropFirst() { pth.addLine(to: q) }; pth.closeSubpath() }
            ctx.fill(box, with: .color(.white))
            ctx.stroke(box, with: .color(Color(argb: 0xFF64748B)), lineWidth: 1.5)
            var cx: CGFloat = 0, cy: CGFloat = 0
            for q in o { cx += q.x; cy += q.y }
            let label = Text(tr(f.type == "bath" ? "tl.bath" : "tl.tray")).font(.system(size: 11, weight: .bold)).foregroundColor(Color(argb: 0xFF334155))
            ctx.draw(label, at: CGPoint(x: cx / 4, y: cy / 4))
        }
        // the floor's start point
        if let live {
            let s = fit.at(floorStart(live, g))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 18, y: s.y - 18, width: 36, height: 36)), with: .color(G.cobalt.opacity(0.22)))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 7, y: s.y - 7, width: 14, height: 14)), with: .color(G.cobalt))
            let cross = Path { pth in
                pth.move(to: CGPoint(x: s.x - 4, y: s.y)); pth.addLine(to: CGPoint(x: s.x + 4, y: s.y))
                pth.move(to: CGPoint(x: s.x, y: s.y - 4)); pth.addLine(to: CGPoint(x: s.x, y: s.y + 4))
            }
            ctx.stroke(cross, with: .color(.white), lineWidth: 1.5)
        }
    }
}

/* ---------------- under the picture ---------------- */

private struct TLayoutCard: View {
    let app: AppModel
    let p: Project
    let l: TileLayout
    let on: Bool
    let onPick: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let looks = layoutSub(l) + " · " + tr("tl.lk." + l.look) + (l.usesSecond ? " + " + tr("tl.lk." + l.look2) : "")
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                LookSwatch(id: l.look).frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    T(layoutTitle(l), ui(15.5, 800), lines: 1)
                    T(looks, ui(12.5, 500, G.ink2), lines: 2)
                    T(surfText(l), ui(12, 400, G.ink3), lines: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onPick)
            HStack(spacing: 8) {
                GBtn(tr("fz.change"), kind: .secondary, icon: "edit", height: 42, corner: 14, fontSize: 14) { app.push(.tSteps(pid: p.id, model: l.model, lid: l.id)) }
                    .accessibilityIdentifier("tv.change")
                if AppSettings.shared.advanced {
                    GBtn(tr("tl.countB"), kind: .secondary, icon: "sliders", height: 42, corner: 14, fontSize: 14) { app.sheet = .tCount(pid: p.id, lid: l.id) }
                        .accessibilityIdentifier("tv.count")
                }
                MIcon("trash", G.ink2, 18, 2).frame(width: 42, height: 42).background(Circle().fill(G.ink.opacity(0.06)))
                    .pressable(0.95, label: tr("common.delete")) { delete() }
                    .accessibilityIdentifier("tv.delete")
            }
        }
        .padding(12)
        .glassCard(shape, fill: G.glass(on ? 0.8 : 0.55))
        .overlay(on ? shape.strokeBorder(G.cobalt, lineWidth: 2) : nil)
    }

    private func delete() {
        guard let before = Store.shared.get(p.id) else { return }
        let id = l.id, pid = p.id
        Store.shared.update(pid) { pr in pr.tiles.removeAll { $0.id == id } }
        if l.roomId == nil { app.pop() }
        app.say("tl.deleted", action: "common.undo") { Store.shared.update(pid) { $0 = before } }
    }
}

/// What a layout covers, in words: "Pol, devor A, B (1,5 m gacha)".
private func surfText(_ l: TileLayout) -> String {
    if l.roomId == nil, let pn = l.panel { return Geo.fmtLen(pn.a, .m, en) + " × " + Geo.fmtLen(pn.b, .m, en) + " m" }
    let parts: [String] = l.surfs.map { s in
        var t: String
        if s.id == "floor" { t = tr("tl.pk.floor") }
        else if s.id.hasPrefix("bath:") { t = tr("tl.bathFront") }
        else if s.mode == "to" { t = tr("tl.wallN", ["w": s.id]) + " " + tr("tl.toV", ["h": Geo.fmtLen(s.h1, .m, en)]) }
        else if s.mode == "band" { t = tr("tl.wallN", ["w": s.id]) + " " + Geo.fmtLen(s.h0, .m, en) + "–" + Geo.fmtLen(s.h1, .m, en) }
        else { t = tr("tl.wallN", ["w": s.id]) }
        if s.alt { t += " ★" }
        return t
    }
    return parts.isEmpty ? tr("tl.s.surfNone") : parts.joined(separator: ", ")
}

/// The room's extras: skirting, corner profiles, joints in line, waterproofing, the tray and the bath.
private struct TExtras: View {
    let app: AppModel
    let p: Project
    let r: Room
    let ls: [TileLayout]
    var body: some View {
        let floors = ls.filter { l in l.surfs.contains { $0.id == "floor" } }
        let wallsL = ls.filter { l in l.surfs.contains { $0.id != "floor" && !$0.id.hasPrefix("bath:") } }
        let tr0 = tileRoomOf(p, r.id)
        VStack(alignment: .leading, spacing: 0) {
            T(tr("tl.extras"), ui(15, 800)).padding(.horizontal, 14).padding(.vertical, 8)
            if !floors.isEmpty { skirting(floors) }
            if !wallsL.isEmpty {
                let prof = wallsL.contains { $0.profiles }
                TSwRow(title: tr("tl.prof"), sub: tr("tl.profS"), on: prof) { all(wallsL) { $0.profiles = !prof } }
                if !floors.isEmpty {
                    let al = wallsL.allSatisfy { $0.align }
                    TSwRow(title: tr("tl.align"), sub: tr("tl.alignS"), on: al) { all(wallsL) { $0.align = !al } }
                }
            }
            TSwRow(title: tr("tl.wp"), sub: tr("tl.wpS", ["h": tr0.wpUp]), on: tr0.wp) { updateTileRoom(p.id, r.id) { $0.wp.toggle() } }
            if tr0.wp { shower(tr0) }
            Hairline()
            ForEach(tr0.fixes) { f in fixRow(f) }
            HStack(spacing: 8) {
                GBtn(tr("tl.addTray"), kind: .secondary, icon: "plus", height: 42, corner: 14, fontSize: 13.5, lines: 2) { app.sheet = .tFixForm(pid: p.id, rid: r.id, fid: nil, type: "tray") }
                    .accessibilityIdentifier("tv.addTray")
                GBtn(tr("tl.addBath"), kind: .secondary, icon: "plus", height: 42, corner: 14, fontSize: 13.5, lines: 2) { app.sheet = .tFixForm(pid: p.id, rid: r.id, fid: nil, type: "bath") }
                    .accessibilityIdentifier("tv.addBath")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }

    /// Changes every one of these layouts of the order.
    private func all(_ of: [TileLayout], _ f: @escaping (inout TileLayout) -> Void) {
        let ids = Set(of.map(\.id))
        Store.shared.update(p.id) { pr in for i in pr.tiles.indices where ids.contains(pr.tiles[i].id) { f(&pr.tiles[i]) } }
    }

    @ViewBuilder private func skirting(_ floors: [TileLayout]) -> some View {
        let on = floors.contains { $0.skirt > 0 }
        TSwRow(title: tr("tl.skirt"), sub: tr("tl.skirtS"), on: on) { all(floors) { $0.skirt = on ? 0 : 100 } }
        if on {
            FlowLayout(spacing: 8) {
                ForEach([80, 100, 120], id: \.self) { h in FChip(label: "\(h) mm", on: floors.first?.skirt == h) { all(floors) { $0.skirt = h } } }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
        }
    }

    @ViewBuilder private func shower(_ tr0: TileRoom) -> some View {
        T(tr("tl.showerH"), ui(13, 600, G.ink2)).padding(.horizontal, 14)
        FlowLayout(spacing: 8) {
            ForEach([1800, 2000, 2200], id: \.self) { h in
                FChip(label: Geo.fmtLen(h, .m, en) + " m", on: tr0.showerH == h) { updateTileRoom(p.id, r.id) { $0.showerH = h } }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }

    private func fixRow(_ f: TFix) -> some View {
        HStack(spacing: 10) {
            MIcon(f.type == "bath" ? "bath" : "layers", G.ink2, 20, 2)
            VStack(alignment: .leading, spacing: 1) {
                T(tr(f.type == "bath" ? "tl.bath" : "tl.tray"), ui(14.5, 700))
                T(tr("tl.wallN", ["w": f.wall]) + " · \(f.w) × \(f.d) × \(f.h)", ui(12.5, 400, G.ink2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 14).frame(minHeight: 52)
        .contentShape(Rectangle())
        .pressable(0.99) { app.sheet = .tFixForm(pid: p.id, rid: r.id, fid: f.id, type: f.type) }
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
    }
}

/// A switch row of the extras: a title, a line under it, the switch.
private struct TSwRow: View {
    let title: String
    let sub: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 600))
                T(sub, ui(12, 400, G.ink2, lh: 1.3))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GSwitch(on: on)
        }
        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 56)
        .contentShape(Rectangle())
        .pressable(0.99, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}
