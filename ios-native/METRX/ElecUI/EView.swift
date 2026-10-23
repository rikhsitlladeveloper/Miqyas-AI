import SwiftUI
import UIKit
import Observation

/*
 * A room's electrics (Android ui/elec/EView.kt): the room in 3D with its devices at their true places and the circuits'
 * cable in colour, the room from above (lights dragged on the ceiling), or a wall straight on (devices and the panel
 * dragged along it, snapping to the usual heights); under it the warnings, the circuits, the devices and, in the advanced
 * app, what it all takes.
 */

private var en: Bool { AppSettings.shared.lang == .en }

/// The room's 3D with its devices and routes, worked out away from the screen's thread: until it is ready the room shows
/// as it was (without devices the first time).
@Observable final class ElecShellBox {
    private(set) var made: (Shell3D, String)? = nil
    @ObservationIgnored private var want = ""
    @ObservationIgnored private var baseRoom: Room? = nil
    @ObservationIgnored private var baseSnap = true
    @ObservationIgnored private var baseShell: Shell3D? = nil

    /// The room as drawn: its own sockets and switches are drawn as the electrician's devices.
    static func shown(_ r: Room) -> Room {
        var x = r
        x.points = r.points.filter { $0.t != "socket" && $0.t != "switch" }
        return x
    }

    /// The room's walls and floor, built again only when the room changes.
    func base(_ r: Room, _ snap: Bool) -> Shell3D {
        let room = ElecShellBox.shown(r)
        if let b = baseShell, baseRoom == room, baseSnap == snap { return b }
        let b = buildShell([room], single: true, snap: snap)
        baseRoom = room; baseSnap = snap; baseShell = b
        return b
    }

    /// The shell to show for room r of order p and the key it is drawn by; starts working out a new one when they changed.
    func shell(_ p: Project, _ r: Room, _ snap: Bool) -> (Shell3D, String) {
        let room = ElecShellBox.shown(r)
        let b = base(r, snap)
        let k0 = shellKey([room], snap)
        let k = k0 + "|elec|\(p.elec)|" + shellKey(p.rooms, snap)
        if k != want {
            want = k
            let pp = p, rid = r.id
            DispatchQueue.global(qos: .userInitiated).async {
                let s = elecShell(pp, rid, room, b, snap)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.want == k else { return }
                    self.made = (s, k)
                }
            }
        }
        if let m = made, m.1 == k { return m }
        return made ?? (b, k0)
    }
}

/// The room's scene with its devices, the panel and the routes.
func elecShell(_ p: Project, _ rid: String, _ room: Room, _ base: Shell3D, _ snap: Bool) -> Shell3D {
    let calc = calcOf(p, snap)
    guard let c = calc.ctxs.first(where: { $0.id == rid }) else { return base }
    guard let w0 = Geo.walls(room, snap).first, let b = base.bases[w0.id] else { return base }
    let dx = b.ox - w0.p0.x / 1000, dz = b.oz - w0.p0.y / 1000
    let byDev = circuitByDev(calc)
    let parts = elecParts(c, devsIn(p, c), calc.routes.panel, calc.routes.inRoom(rid), dx, dz) { byDev[$0] }
    return base.plus(parts, [])
}

struct EViewScreen: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var mode = "3d"
    @State private var wall: String? = nil

    var body: some View {
        if let p = Store.shared.get(pid) {
            let free = rid.hasPrefix("free:")
            let calc = ElecCalcCache.shared.of(p)
            let c = calc.ctxs.first { $0.id == rid }
            let room: Room? = free ? nil : p.rooms.first { $0.id == rid }
            GeometryReader { geo in
                VStack(spacing: 0) {
                    bar(p, c, room, free)
                    if let c { content(p, c, room, calc, free, geo.size.height) } else { needMeasure(p, room) }
                }
            }
            .onAppear {
                if !free { takeInPoints(pid, rid); applyPending(app, pid) }
            }
        }
    }

    private func title(_ p: Project, _ c: ECtx?, _ room: Room?) -> String {
        if let f = c?.free { let nm = dn(f.name); return nm.trimmingCharacters(in: .whitespaces).isEmpty ? tr(eKindKey(f.kind)) : nm }
        if let room { return eRoomName(p, room) }
        return ""
    }

    private func bar(_ p: Project, _ c: ECtx?, _ room: Room?, _ free: Bool) -> some View {
        HStack(spacing: 6) {
            GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
            BarTitle(title: title(p, c, room), eyebrow: dn(p.name)).frame(maxWidth: .infinity, alignment: .leading)
            if let room { GlassIconButton("edit", tr("common.edit")) { openRoom(app, p.id, room.id) } }
            if let c, !free {
                GlassIconButton("sliders", tr("el.roomSet")) { app.sheet = .eRoomSet(pid: p.id, rid: c.id) }.padding(.leading, 2)
            }
            if let f = c?.free {
                GlassIconButton("sliders", tr("el.freeEdit")) { app.sheet = .eFree(pid: p.id, fid: f.id) }.padding(.leading, 2)
            }
        }
        .padding(.trailing, 12).frame(minHeight: 64)
        .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
    }

    private func needMeasure(_ p: Project, _ room: Room?) -> some View {
        VStack(spacing: 14) {
            T(tr("tl.needMeasure"), ui(16, 700, G.ink, lh: 1.35), align: .center)
            if let room { GBtn(tr("ns.measureB"), fill: false) { openRoom(app, p.id, room.id) } }
        }
        .padding(24).frame(maxWidth: .infinity)
    }

    @ViewBuilder private func content(_ p: Project, _ c: ECtx, _ room: Room?, _ calc: ElecCalc, _ free: Bool, _ h: CGFloat) -> some View {
        let wid = wall ?? c.g.walls.first?.id ?? "A"
        let ds = devsIn(p, c)
        let byDev = circuitByDev(calc)
        let runs = calc.routes.inRoom(rid)
        let warns = calc.warns.filter { $0.roomId == rid || ($0.roomId == nil && $0.devId == nil && $0.key != "el.w.noPanel") }
        let bad = Set(warns.compactMap(\.devId))
        let pn = calc.routes.panel
        Seg(items: [("3d", "3D"), ("plan", tr("ed.plan")), ("wall", tr("el.wallV"))], cur: mode) { mode = $0 }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        Group {
            switch mode {
            case "plan": EPlanView(app: app, p: p, c: c, ds: ds, pn: pn, runs: runs, byDev: byDev, bad: bad, locked: free)
            case "wall": EWallView(app: app, p: p, c: c, wid: wid, ds: ds, pn: pn, runs: runs, byDev: byDev, bad: bad, locked: free)
            default: ERoom3D(app: app, p: p, c: c, room: room)
            }
        }
        .frame(height: max(160, h * 0.46))
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if mode == "wall" { wallChips(c, wid) }
                if !warns.isEmpty { EWarnings(app: app, p: p, c: c, ws: warns) }
                if !runs.isEmpty { ECircuitsCard(calc: calc, runs: runs) }
                if free { EFreeCard(app: app, p: p, c: c) }
                else { EDevicesCard(app: app, p: p, c: c, ds: ds, byDev: byDev, bad: bad, wall: mode == "wall" ? wid : nil) }
                if !free {
                    HStack(spacing: 8) {
                        dashed("plus", tr("el.addDev"), "ev.addDev") { app.sheet = .eDev(pid: p.id, rid: c.id, did: nil, wall: mode == "wall" ? wid : nil) }
                        dashed("layers", tr("el.addKit"), "ev.addKit") { app.push(.eGallery(pid: p.id, rid: c.id)) }
                    }
                    EPanelCard(app: app, p: p, c: c, pn: pn)
                }
                if AppSettings.shared.advanced { ECountCard(c: calc.count) }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 28)
        }
    }

    private func wallChips(_ c: ECtx, _ wid: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(c.g.walls.map(\.id), id: \.self) { id in
                    let len = c.g.wall(id)?.len ?? 0
                    FChip(label: tr("tl.wallN", ["w": id]) + " · " + Geo.fmtLen(tInt(len), .m, en), on: id == wid) { wall = id }
                }
            }
        }
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

/// The room in 3D with its devices and routes, the picture's buttons over it.
private struct ERoom3D: View {
    let app: AppModel
    let p: Project
    let c: ECtx
    let room: Room?
    @State private var cam = Cam3D()
    @State private var shot = Shot3D()
    @State private var taking = false
    @State private var eb = ElecShellBox()
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let r = room ?? c.room
        let made = eb.shell(p, r, snap)
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

/// A device or the panel being dragged and where it would land, mm (a ceiling device: plan x, y; a wall one: off, h).
private struct EDrag: Equatable {
    let id: String
    let a: Int
    let b: Int
}

private func eDistTo(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

/* ---------------- from above ---------------- */

private struct EPlanView: View {
    let app: AppModel
    let p: Project
    let c: ECtx
    let ds: [ElecDev]
    let pn: ElecPanel?
    let runs: [CRun]
    let byDev: [String: Circuit]
    let bad: Set<String>
    let locked: Bool
    @State private var drag: EDrag? = nil
    @State private var grab: String? = nil
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            let m = EPlanMap(c, CGRect(origin: .zero, size: geo.size), 26)
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, _ in draw(ctx, m) }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in changed(v, m) }.onEnded { v in ended(v, m) })
                T(tr(locked ? "el.planFree" : "el.planDrag"), ui(11.5, 600, G.ink3)).padding(10).allowsHitTesting(false)
            }
        }
        .background(Color(argb: 0xFFF6F8FC))
    }

    private func shown() -> [ElecDev] {
        guard let d = drag else { return ds }
        return ds.map { (x: ElecDev) -> ElecDev in
            if x.id != d.id { return x }
            var y = x; y.cx = d.a; y.cy = d.b
            return y
        }
    }

    private func draw(_ ctx: GraphicsContext, _ m: EPlanMap) {
        let list = shown(), sel = drag?.id
        ctx.withCGContext { cg in
            drawElecPlan(cg, c, m, list, pn, runs, { byDev[$0] }, 9, sel: sel, bad: bad)
        }
    }

    private func nearest(_ xs: [ElecDev], _ pos: CGPoint, _ m: EPlanMap, _ lim: CGFloat) -> ElecDev? {
        guard let b = eMinBy(xs, { Double(eDistTo(m.at(c.planOf($0)), pos)) }) else { return nil }
        return eDistTo(m.at(c.planOf(b)), pos) < lim ? b : nil
    }

    private func changed(_ v: DragGesture.Value, _ m: EPlanMap) {
        if locked { return }
        if !started {
            started = true
            grab = nearest(ds.filter(\.onCeiling), v.startLocation, m, 34)?.id
        }
        guard let g = grab, hypot(v.translation.width, v.translation.height) > 4 else { return }
        let q = m.back(v.location)
        let s = snapCeil(c, q.x, q.y)
        drag = EDrag(id: g, a: s.0, b: s.1)
    }

    private func ended(_ v: DragGesture.Value, _ m: EPlanMap) {
        let moved = hypot(v.translation.width, v.translation.height) > 4
        let d = drag
        drag = nil; grab = nil; started = false
        if locked { return }
        if !moved {
            if let hit = nearest(ds, v.startLocation, m, 28) { app.sheet = .eDev(pid: p.id, rid: c.id, did: hit.id) }
            return
        }
        if let d { updateDev(p.id, d.id) { $0.cx = d.a; $0.cy = d.b } }
    }
}

/* ---------------- a wall straight on ---------------- */

private struct EWallView: View {
    let app: AppModel
    let p: Project
    let c: ECtx
    let wid: String
    let ds: [ElecDev]
    let pn: ElecPanel?
    let runs: [CRun]
    let byDev: [String: Circuit]
    let bad: Set<String>
    let locked: Bool
    @State private var drag: EDrag? = nil
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
                T(tr(locked ? "el.planFree" : "el.wallDrag"), ui(11.5, 600, G.ink3)).padding(.leading, 10).padding(.bottom, 2).allowsHitTesting(false)
            }
        }
        .background(Color(argb: 0xFFF6F8FC))
        .id(w.id)
    }

    private func draw(_ ctx: GraphicsContext, _ w: TWall, _ m: EWallMap) {
        let d = drag
        var shownDs = ds
        var shownPn = pn
        if let d {
            if d.id == "panel" { shownPn?.off = d.a; shownPn?.h = d.b }
            else {
                shownDs = ds.map { (x: ElecDev) -> ElecDev in
                    if x.id != d.id { return x }
                    var y = x
                    y.off = d.a; y.h = d.b
                    return y
                }
            }
        }
        let rs = d == nil ? runs : []
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: uiColor(0x334155)]
        let label: (String) -> NSAttributedString = { s in NSAttributedString(string: Geo.fmtLen(Int(s), .m, en), attributes: attrs) }
        let list = shownDs, panel = shownPn, sel = d?.id
        ctx.withCGContext { cg in
            drawElecWall(cg, c, w, m, list, panel, rs, { byDev[$0] }, label, sel: sel, bad: bad, minR: 11)
        }
    }

    private func onWall(_ w: TWall) -> [ElecDev] { ds.filter { $0.wall == w.id } }

    private func nearest(_ xs: [ElecDev], _ pos: CGPoint, _ m: EWallMap, _ lim: CGFloat) -> ElecDev? {
        guard let b = eMinBy(xs, { Double(eDistTo(m.at(Double($0.off), Double($0.h)), pos)) }) else { return nil }
        return eDistTo(m.at(Double(b.off), Double(b.h)), pos) < lim ? b : nil
    }

    private func changed(_ v: DragGesture.Value, _ w: TWall, _ m: EWallMap) {
        if locked { return }
        if !started {
            started = true
            let pos = v.startLocation
            let near = nearest(onWall(w), pos, m, 34)
            var pnHit = false
            if let pn, pn.roomId == c.id, pn.wall == w.id, eDistTo(m.at(Double(pn.off), Double(pn.h)), pos) < 40 { pnHit = true }
            grab = near?.id ?? (pnHit ? "panel" : nil)
        }
        guard let g = grab, hypot(v.translation.width, v.translation.height) > 4 else { return }
        let rawOff = tInt((Double(v.location.x) - m.x0) / m.k)
        let rawH = tInt((m.yF - Double(v.location.y)) / m.k)
        if g == "panel" {
            guard let pn else { return }
            let s = snapPanel(c, pn, rawOff, rawH)
            drag = EDrag(id: "panel", a: s.off, b: s.h)
        } else if let d = ds.first(where: { $0.id == g }) {
            let s = snapWall(c, d, rawOff, rawH, ds)
            drag = EDrag(id: g, a: s.0, b: s.1)
        }
    }

    private func ended(_ v: DragGesture.Value, _ w: TWall, _ m: EWallMap) {
        let moved = hypot(v.translation.width, v.translation.height) > 4
        let d = drag
        drag = nil; grab = nil; started = false
        if locked { return }
        if !moved {
            if let hit = nearest(onWall(w), v.startLocation, m, 30) { app.sheet = .eDev(pid: p.id, rid: c.id, did: hit.id) }
            return
        }
        guard let d else { return }
        if d.id == "panel" { updateElec(p.id) { e in e.panel?.off = d.a; e.panel?.h = d.b } }
        else { updateDev(p.id, d.id) { $0.off = d.a; $0.h = d.b } }
    }
}

/* ---------------- under the picture ---------------- */

private struct EWarnings: View {
    let app: AppModel
    let p: Project
    let c: ECtx
    let ws: [EWarn]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { MIcon("alert", G.amberInk, 18, 2); T(tr("el.warnN", ["n": ws.count]), ui(15, 800, G.amberInk)) }
            ForEach(Array(ws.enumerated()), id: \.offset) { _, w in line(w) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.amberWash))
    }

    private func text(_ w: EWarn, _ d: ElecDev?) -> String {
        var vars: [String: Any] = [:]
        for (k, v) in w.vars { vars[k] = k == "kw" && !en ? v.replacingOccurrences(of: ".", with: ",") : v }
        let who: String? = d.map { x in tr("el.t." + x.t) + (x.wall.map { " · " + tr("tl.wallN", ["w": $0]) } ?? "") }
        return (who.map { $0 + ": " } ?? "") + tr(w.key, vars)
    }

    @ViewBuilder private func line(_ w: EWarn) -> some View {
        let d = w.devId.flatMap { id in p.elec.devs.first { $0.id == id } }
        let t = T(text(w, d), ui(13, 500, G.ink, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
        if let d {
            t.contentShape(Rectangle()).pressable(0.99) { app.sheet = .eDev(pid: p.id, rid: c.id, did: d.id) }.accessibilityAddTraits(.isButton)
        } else { t }
    }
}

private struct ECircuitsCard: View {
    let calc: ElecCalc
    let runs: [CRun]
    /// The circuits of these runs, once each.
    private func circuits() -> [Circuit] {
        var seen = Set<Int>()
        var out: [Circuit] = []
        for r in runs where seen.insert(r.circuit.no).inserted { out.append(r.circuit) }
        return out
    }

    var body: some View {
        let cs = circuits()
        VStack(alignment: .leading, spacing: 8) {
            T(tr("el.circuits"), ui(15, 800))
            ForEach(cs, id: \.no) { cc in row(cc) }
            T(tr("el.m." + calc.routes.method + "S"), ui(12, 400, G.ink3, lh: 1.35))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }

    private func sub(_ cc: Circuit) -> String {
        let cab = en ? cableName(cc.cable) : cableName(cc.cable).replacingOccurrences(of: ".", with: ",")
        let brk = cc.amps > 0 ? tr("el.brkV", ["a": cc.amps]) + " · " : ""
        let rcd = cc.rcd ? " · " + tr("el.rcdS") : ""
        return brk + cab + rcd + " · " + tr("el.ptsV", ["n": cc.devs.count])
    }

    private func row(_ cc: Circuit) -> some View {
        let lang = AppSettings.shared.lang
        return HStack(spacing: 10) {
            Circle().fill(eColor(cc.rgb)).frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("el.grpN", ["n": cc.no, "g": tr("el.g." + cc.group)]), ui(14, 700), lines: 1)
                T(sub(cc), ui(12.5, 400, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if AppSettings.shared.advanced { T(Num.fixed(calc.routes.cableOf(cc) / 1000, 1, lang) + U_M, num(13.5, 700)) }
        }
    }
}

private struct EDevicesCard: View {
    let app: AppModel
    let p: Project
    let c: ECtx
    let ds: [ElecDev]
    let byDev: [String: Circuit]
    let bad: Set<String>
    let wall: String?
    var body: some View {
        let list = wall.map { w in ds.filter { $0.wall == w } } ?? ds
        VStack(spacing: 0) {
            HStack {
                T(wall.map { tr("el.onWall", ["w": $0]) } ?? tr("el.devs"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(devSummary(list), ui(12, 500, G.ink2), align: .trailing, lines: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            if list.isEmpty {
                T(tr("el.noDevs"), ui(13.5, 400, G.ink2)).padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(ordered(list)) { d in row(d) }
        }
        .padding(.vertical, 6)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }

    /// The devices by kind, then by wall and place along it.
    private func ordered(_ list: [ElecDev]) -> [ElecDev] {
        var out: [ElecDev] = []
        for cat in CATS {
            let xs = list.enumerated().filter { devType($0.element.t).cat == cat }
            let sorted = xs.sorted { a, b in
                let wa = a.element.wall ?? "~", wb = b.element.wall ?? "~"
                if wa != wb { return wa < wb }
                if a.element.off != b.element.off { return a.element.off < b.element.off }
                return a.offset < b.offset
            }
            out += sorted.map(\.element)
        }
        return out
    }

    private func sub(_ d: ElecDev) -> String {
        if d.onCeiling { return tr("el.onCeil") }
        let at = tr("tl.wallN", ["w": d.wall ?? ""]) + " · " + tr("el.atH", ["h": Geo.fmtLen(d.h, .m, en)])
        return d.t == "led" ? at + " · " + Geo.fmtLen(d.len, .m, en) + U_M : at
    }

    private func row(_ d: ElecDev) -> some View {
        let isBad = bad.contains(d.id)
        let cc = byDev[d.id]
        return HStack(spacing: 10) {
            DevSymbolView(t: d.t, rgb: cc?.rgb ?? 0x94A3B8, ink: isBad ? 0xDC2626 : E_INK_RGB).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("el.t." + d.t) + (d.own ? " · " + tr("el.ownShort") : ""), ui(14, 700, isBad ? G.amberInk : G.ink), lines: 1)
                T(sub(d), ui(12, 400, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let cc { T("№\(cc.no)", num(12.5, 700, G.ink2)) }
            MIcon("chev", G.ink3, 14, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 4).frame(minHeight: 50)
        .contentShape(Rectangle())
        .pressable(0.99) { app.sheet = .eDev(pid: p.id, rid: c.id, did: d.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A room typed by size: what it has, and the button that changes it.
private struct EFreeCard: View {
    let app: AppModel
    let p: Project
    let c: ECtx
    var body: some View {
        if let f = c.free {
            let size = Geo.fmtLen(f.L, .m, en) + " × " + Geo.fmtLen(f.W, .m, en) + " × " + Geo.fmtLen(f.H, .m, en) + U_M
            let counts: [(String, Int)] = [("sock", f.sock), ("sw", f.sw), ("light", f.light), ("low", f.low), ("power", f.power)].filter { $0.1 > 0 }
            VStack(alignment: .leading, spacing: 6) {
                T(tr("el.freeT"), ui(15, 800))
                EKv(k: tr("el.size"), v: size)
                ForEach(counts, id: \.0) { k, n in EKv(k: tr("el.fc." + k), v: "\(n)") }
                EKv(k: tr("el.link"), v: Geo.fmtLen(f.link, .m, en) + U_M)
                T(tr("el.freeNote"), ui(12.5, 400, G.ink2, lh: 1.4))
                GBtn(tr("fz.change"), kind: .secondary, icon: "edit", height: 44, corner: 14, fontSize: 14) { app.sheet = .eFree(pid: p.id, fid: f.id) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
        }
    }
}

/// The panel: here (drag it on the wall view), or another room's, with the button that brings it here.
private struct EPanelCard: View {
    let app: AppModel
    let p: Project
    let c: ECtx
    let pn: ElecPanel?
    var body: some View {
        let sub: String = {
            guard let pn else { return tr("el.panelNone") }
            if pn.roomId == c.id { return tr("el.panelAt", ["w": pn.wall, "h": Geo.fmtLen(pn.h, .m, en)]) }
            let name = p.rooms.first { $0.id == pn.roomId }.map { eRoomName(p, $0) } ?? ""
            return tr("el.panelIn", ["r": name])
        }()
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                DevSymbolView(t: "panel", rgb: E_INK_RGB).frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    T(tr("el.panel"), ui(15, 800))
                    T(sub, ui(12.5, 400, G.ink2, lh: 1.35))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if pn?.roomId != c.id {
                GBtn(tr("el.panelMove"), kind: .secondary, icon: "box", height: 44, corner: 14, fontSize: 14) {
                    let d = panelIn(c, p.elec.devs.filter { $0.roomId == c.id })
                    updateElec(p.id) { $0.panel = d }
                    app.say("el.panelSet")
                }
            } else {
                T(tr("el.panelDrag"), ui(12.5, 400, G.ink2, lh: 1.35))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }
}
