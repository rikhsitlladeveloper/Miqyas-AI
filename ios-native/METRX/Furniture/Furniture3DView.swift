import SwiftUI

/*
 * Furniture in 3D, Stage 1a part 6 (furniture plan section 9; Android ui/furniture/Furniture3DView.kt): the order's
 * furniture in its measured room on the existing 3D page and engine. A tap on a door or drawer opens it; "Hammasini
 * ochish" and "Yopish" do all of them.
 */

/// The room's scene with this order's furniture in it, what can be opened, and the key the scene is rebuilt by (the
/// camera stays where it is when only doors open: the furniture has as many parts open as closed).
func furnShell(_ p: Project, _ room: Room, _ base: Shell3D, _ open: Set<String>, _ snap: Bool) -> (Shell3D, Furn3D, String) {
    let s = AppSettings.shared, ws = s.workshop, mats = s.mats
    let fs = p.furniture.filter { $0.roomId == room.id || ($0.roomId == nil && FREE_ROOM + $0.id == room.id) }
    let fur = furniture3D(fs, base.bases, ws, { id in rgbOf(mats.first { $0.id == id }?.rgb ?? "#F5F5F2") }, open)
    let key = shellKey([room], snap) + "|\(fs)|\(ws)|\(mats.map(\.rgb))|" + open.sorted().joined(separator: ",")
    return (base.plus(fur.parts, fur.edges), fur, key)
}

/// The 2D | 3D switch of the kitchen and wardrobe designers.
struct DimSeg: View {
    let d3: Bool
    let onPick: (Bool) -> Void
    var body: some View {
        HStack(spacing: 2) {
            ForEach([(false, "2D"), (true, "3D")], id: \.0) { k, l in
                let on = k == d3
                T(l, ui(14, on ? 700 : 500, on ? G.ink : G.ink2))
                    .padding(.horizontal, 18).frame(minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? G.glass(0.9) : .clear))
                    .pressable(0.97) { onPick(k) }
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("dim." + l)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
    }
}

/// The designers' 3D: the whole room with all its furniture, doors that open, views for the report.
struct Furniture3DPane: View {
    let app: AppModel
    let p: Project
    let room: Room
    @State private var open: Set<String> = []
    @State private var cam = Cam3D()
    @State private var shot = Shot3D()
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if !Geo.ready3D(room, snap) {
            T(tr(room.isPoly ? "sk.need3d" : "3d.need"), ui(17, 700, G.ink, lh: 1.35), align: .center)
                .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // furniture without a room stands on a floor of its size, no walls round it
            let free = isFreeRoom(room)
            let built = buildShell([room], single: true, snap: snap)
            let (shell, fur, key) = furnShell(p, room, free ? built.floorOnly() : built, open, snap)
            Scene3D(shell: shell, key: key, cam: cam, shot: shot, points: shell.labels.map(\.p), label: { AnyView(Lbl3D(text: shell.labels[$0].text)) },
                    onTap: { pt in toggle(fur, pt) }) {
                if !free {
                    ShotPill(icon: "camera", label: tr("3d.save")) { save3DView(app, p.id, room, shot) }
                        .accessibilityIdentifier("3d.save")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 10).padding(.trailing, 10)
                }
                T(tr("f3.hint"), ui(12.5, 600, G.ink2)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.sheet(0.7)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(12)
                    .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    GBtn(tr("f3.openAll"), kind: .secondary, height: 44, corner: 12, fontSize: 14) { open = Set(fur.keys) }.accessibilityIdentifier("f3.openAll")
                    GBtn(tr("f3.close"), kind: .secondary, enabled: !open.isEmpty, height: 44, corner: 12, fontSize: 14) { open = [] }.accessibilityIdentifier("f3.close")
                }
                HStack(spacing: 10) {
                    ForEach([("3d.top", true), ("3d.corner", false)], id: \.0) { k, top in
                        GBtn(tr(k), kind: .secondary, height: 44, corner: 12, fontSize: 14) { cam.preset(top: top) }.accessibilityIdentifier(k)
                    }
                }
                if !room.views.isEmpty { T(tr("3d.inRep", ["n": room.views.count]), ui(13, 400, G.ink2)) }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(G.glass(0.55))
        }
    }

    private func toggle(_ fur: Furn3D, _ pt: CGPoint) {
        let (e, d) = cam.ray(pt.x, pt.y)
        if let k = fur.pick(e, d) { if open.contains(k) { open.remove(k) } else { open.insert(k) } }
    }
}

/// "Add to report" on a 3D picture: at most 4 views a room.
func save3DView(_ app: AppModel, _ pid: String, _ room: Room, _ shot: Shot3D) {
    if room.views.count >= 4 { app.say("3d.max", kind: .error); return }
    let rid = room.id
    shot.take { img in
        DispatchQueue.main.async {
            let id = uid()
            guard let img, let file = ViewFiles.save(id, img) else { app.say("3d.fail", kind: .error); return }
            Store.shared.update(pid) { pp in if let i = pp.rooms.firstIndex(where: { $0.id == rid }) { pp.rooms[i].views.append(View3D(id: id, img: file, ts: nowMs())) } }
            app.say("3d.saved")
        }
    }
}
