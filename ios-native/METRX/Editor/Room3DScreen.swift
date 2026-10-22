import SwiftUI

/// The room's 3D page (prototype PAGES.editor with mode '3d' and the ux module's report button on the picture);
/// Android Room3DScreen.
struct Room3DScreen: View {
    let app: AppModel
    let p: Project
    let r: Room
    @State private var cam = Cam3D()
    @State private var shot = Shot3D()
    /// A picture is being taken: a second tap does nothing.
    @State private var taking = false
    /// A furniture order's doors and drawers, opening and shutting.
    @State private var mo = DoorMotion()
    /// The room's walls and floor, built once while the room stays the same (doors moving rebuild only the furniture).
    @State private var f3 = Furn3DCache()
    /// A tiler's order: its layouts' tiles in the room, worked out away from the screen's thread.
    @State private var tb = TileShellBox()
    /// An electrician's order: its devices and routes in the room, worked out away from the screen's thread.
    @State private var eb = ElecShellBox()
    /// A plumber's order: its fixtures and pipes in the room, worked out away from the screen's thread.
    @State private var pb = PlumbShellBox()
    /// A windows-and-doors order: its products fitted in the room's openings, worked out away from the screen's thread.
    @State private var wb = WinShellBox()
    private var ops: RoomOps { RoomOps.shared }

    /// A trade's order in its room: a tiler's tiles, an electrician's devices and routes; nil for the rest.
    private func tradeShell(_ p: Project, _ r: Room, _ base: Shell3D, _ snap: Bool) -> (Shell3D, String)? {
        if p.isTiler { return tb.shell(p, r, base, snap) }
        if p.isElec { return eb.shell(p, r, snap) }
        if p.isPlumb { return pb.shell(p, r, snap) }
        if p.isWin { return wb.shell(p, r, snap) }
        return nil
    }

    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let w = p.floors.first { $0.id == r.floorId }
        let _ = ops.histTick
        VStack(spacing: 0) {
            // bar: back, name and workspace, undo and redo
            HStack(spacing: 2) {
                GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).padding(.trailing, 2).accessibilityIdentifier("back")
                VStack(alignment: .leading, spacing: 0) {
                    T(dn(r.name), ui(17, 700, G.ink, lh: 1.2), lines: 1)
                    if let w { T(floorName(w), ui(12.5, 400, G.ink2, lh: 1.2), lines: 1) }
                }
                .padding(.leading, 2).frame(maxWidth: .infinity, alignment: .leading)
                GlassIconButton("undo", tr("common.undo")) { if ops.canUndo(r.id) { ops.undo(p.id, r.id) } }.opacity(ops.canUndo(r.id) ? 1 : 0.4)
                Color.clear.frame(width: 8, height: 1)
                GlassIconButton("redo", "redo") { if ops.canRedo(r.id) { ops.redo(p.id, r.id) } }.opacity(ops.canRedo(r.id) ? 1 : 0.4)
            }
            .padding(.leading, 8).padding(.trailing, 12).frame(height: 64)
            // sub-bar: Plan | 3D, the laser
            HStack {
                ModeSeg(cur: "3d") { if $0 == "plan" { ops.mode(p.id, r.id, "plan") } }
                Spacer()
                LaserButton { app.sheet = .device }.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            if !Geo.ready3D(r, snap) {
                VStack(spacing: 14) {
                    T(tr(r.isPoly ? "sk.need3d" : "3d.need"), ui(17, 700, G.ink, lh: 1.35), align: .center)
                    GBtn(tr("ed.plan"), kind: .secondary, fill: false) { ops.mode(p.id, r.id, "plan") }
                }
                .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let base = f3.base(r, snap)
                // a furniture order's furniture stands in its room; a tap opens a door or a drawer
                let fur: (Shell3D, Furn3D, String)? = p.isFurniture ? furnShell(p, r, base, mo.prog, snap, cache: f3) : nil
                // a tiler's order: every tile of the room's layouts at its place; an electrician's: its devices and routes
                let tiled: (Shell3D, String)? = tradeShell(p, r, base, snap)
                let shell = fur?.0 ?? tiled?.0 ?? base
                Scene3D(shell: shell, key: fur?.2 ?? tiled?.1 ?? shellKey([r], snap), baseKey: fur == nil ? nil : f3.key, cam: cam, shot: shot, points: shell.labels.map(\.p),
                        label: { AnyView(Lbl3D(text: shell.labels[$0].text)) },
                        onTap: fur.map { f in { pt in
                            let (e, d) = cam.ray(pt.x, pt.y)
                            if let k = f.1.pick(e, d) { mo.toggle(k) }
                        } }) {
                    ShotPill(icon: "camera", label: tr("3d.save")) { save() }
                        .accessibilityIdentifier("3d.save")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 10).padding(.trailing, 10)
                }
                Controls3D(r: r, cam: cam,
                           onColor: { wall, c in
                               Store.shared.update(p.id) { pp in
                                   if let i = pp.rooms.firstIndex(where: { $0.id == r.id }) { if wall { pp.rooms[i].wallColor = c } else { pp.rooms[i].floorColor = c } }
                               }
                           },
                           onDelete: { v in
                               Store.shared.update(p.id) { pp in if let i = pp.rooms.firstIndex(where: { $0.id == r.id }) { pp.rooms[i].views.removeAll { $0.id == v.id } } }
                               ViewFiles.delete(v.img); app.say("3d.deleted")
                           })
            }
        }
        .onDisappear { mo.stop() }
    }

    private func save() {
        let pid = p.id, rid = r.id
        // at most 4 views: counted on the room as saved now, not as this screen last drew it
        func full() -> Bool { (RoomOps.shared.room(pid, rid)?.views.count ?? 4) >= 4 }
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

/// What the 3D picture is built from: when it changes, the scene is rebuilt.
func shellKey(_ rooms: [Room], _ snap: Bool, _ names: [String] = []) -> String {
    rooms.map { "\($0.id)|\($0.dims)|\($0.openings)|\($0.points)|\(String(describing: $0.poly))|\($0.wallColor)|\($0.floorColor)" }.joined(separator: "/") + "\(snap)\(names)"
}

/// Plan | 3D (prototype .subbar .seg).
struct ModeSeg: View {
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        HStack(spacing: 2) {
            ForEach([("plan", tr("ed.plan")), ("3d", "3D")], id: \.0) { k, l in
                let on = k == cur
                T(l, ui(14, on ? 600 : 500, on ? G.ink : G.ink2), lines: 1)
                    .padding(.horizontal, 16).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? G.glass(0.55) : .clear))
                    .boxShadow(on ? Color(argb: 0x24101828) : .clear, blur: 3, y: 1)
                    .pressable(0.97) { onPick(k) }
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("mode." + k)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
    }
}

/// Below the picture: From above / From the corner, wall and floor colours, the views in the report (prototype .ctl3d).
private struct Controls3D: View {
    let r: Room
    let cam: Cam3D
    let onColor: (Bool, String) -> Void
    let onDelete: (View3D) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach([("3d.top", true), ("3d.corner", false)], id: \.0) { k, top in
                    T(tr(k), ui(14, 700), lines: 1).frame(maxWidth: .infinity).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
                        .pressable(0.98) { cam.preset(top: top) }
                        .accessibilityIdentifier(k)
                }
            }
            Swatches(label: tr("3d.walls"), colors: WALL_COLORS, cur: r.wallColor, id: "wc") { onColor(true, $0) }
            Swatches(label: tr("3d.floor"), colors: FLOOR_COLORS, cur: r.floorColor, id: "fc") { onColor(false, $0) }
            if !r.views.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    T(tr("3d.inRep", ["n": r.views.count]), ui(13, 400, G.ink2))
                    HStack(spacing: 14) { ForEach(r.views) { v in ViewThumb(v: v) { onDelete(v) } } }.padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(G.glass(0.55))
        .overlay(alignment: .top) { Rectangle().fill(G.hi(0.8)).frame(height: 0.67) }
    }
}

private struct Swatches: View {
    let label: String
    let colors: [String]
    let cur: String
    let id: String
    let onPick: (String) -> Void
    var body: some View {
        HStack(spacing: 8) {
            T(label, ui(13.5, 400, G.ink2), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(colors.enumerated()), id: \.offset) { i, c in
                let on = c.caseInsensitiveCompare(cur) == .orderedSame
                RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: uiColor(rgbOf(c))))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(G.rim, lineWidth: 0.67))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(on ? G.cobalt : .clear, lineWidth: 2).padding(-4))
                    .pressable(0.95, label: label + " \(i + 1)") { onPick(c) }
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("\(id).\(i)")
            }
        }
    }
}

/// A view in the report: 64 × 48 with a round × to take it out (ux .v3-th).
private struct ViewThumb: View {
    let v: View3D
    let onDelete: () -> Void
    @State private var img: UIImage? = nil
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img { Image(uiImage: img).resizable().scaledToFill() } else { Color.clear }
            }
            .frame(width: 64, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
            MIcon("x", G.solid, 13, 2.4).frame(width: 26, height: 26).background(Circle().fill(G.ink))
                .offset(x: 9, y: -9)
                .pressable(0.92, label: tr("3d.del"), onDelete)
        }
        .frame(width: 64, height: 48)
        .onAppear { if img == nil { let f = v.img; DispatchQueue.global().async { let i = ViewFiles.load(f, maxW: 128); DispatchQueue.main.async { img = i } } } }
        .accessibilityIdentifier("3d.view")
    }
}
