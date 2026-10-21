import SwiftUI
import Observation

/*
 * Furniture in 3D, Stage 1a part 6 (furniture plan section 9; Android ui/furniture/Furniture3DView.kt): the order's
 * furniture in its measured room on the existing 3D page and engine. A tap on a door or drawer opens it; "Hammasini
 * ochish" and "Yopish" do all of them.
 */

/// Doors and drawers opening and shutting, about 0.3 s each: target what should be open, prog how far each one is (0
/// to 1). Shutting a door slides in what was pulled out behind it first; opening one leaves its drawers shut.
@Observable final class DoorMotion {
    private(set) var target: Set<String> = []
    private(set) var prog: [String: Double] = [:]
    @ObservationIgnored private var job: Task<Void, Never>? = nil

    @MainActor func toggle(_ k: String) {
        if target.contains(k) {
            let inner = doorInner(k, target)
            var t = target; t.remove(k); t.subtract(inner); target = t
        } else { target.insert(k) }
        run()
    }
    @MainActor func openAll(_ keys: [String]) { target = Set(keys); run() }
    @MainActor func closeAll() { target = []; run() }

    /// Moves everything towards target; a new target stops the old run where it is and starts from there.
    @MainActor private func run() {
        job?.cancel()
        let to = target
        job = Task { @MainActor [weak self] in
            guard let self else { return }
            // what shuts: the drawers first, then the doors; what opens: the doors first, then the drawers
            let shut = self.prog.keys.filter { !to.contains($0) }
            await self.move(shut.filter { !isDoorKey($0) }, 0)
            await self.move(shut.filter { isDoorKey($0) }, 0)
            let opening = Array(to.filter { (self.prog[$0] ?? 0) < 1 })
            await self.move(opening.filter { isDoorKey($0) }, 1)
            await self.move(opening.filter { !isDoorKey($0) }, 1)
        }
    }

    /// keys from where they are to `to` over 0.3 s, eased in and out.
    @MainActor private func move(_ keys: [String], _ to: Double) async {
        if keys.isEmpty || Task.isCancelled { return }
        var from: [String: Double] = [:]
        for k in keys { from[k] = prog[k] ?? 0 }
        let t0 = Date()
        while true {
            if Task.isCancelled { return }
            let e = min(1, max(0, Date().timeIntervalSince(t0) / 0.3))
            let s = e * e * (3 - 2 * e)
            var next = prog
            for k in keys { let a = from[k] ?? 0; next[k] = a + (to - a) * s }
            prog = next
            if e >= 1 { break }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        var done = prog
        for k in keys { if to == 0 { done.removeValue(forKey: k) } else { done[k] = 1 } }
        prog = done
    }
}

/// A door's key (a hinged door "…:f1" or a sliding one "…:slide0"), not a drawer's or a rack's.
private func isDoorKey(_ k: String) -> Bool {
    let last = k.lastIndex(of: ":").map { String(k[k.index(after: $0)...]) } ?? k
    return last.hasPrefix("f") || last.hasPrefix("slide")
}

/// What stands behind door among keys: the drawers and racks of its section (a sliding door: of its wardrobe).
private func doorInner(_ door: String, _ keys: Set<String>) -> Set<String> {
    if !isDoorKey(door) { return [] }
    let pre = (door.lastIndex(of: ":").map { String(door[..<$0]) } ?? door) + ":"
    return keys.filter { $0.hasPrefix(pre) && !isDoorKey($0) }
}

/// The room's scene with this order's furniture in it, each door and drawer as far open as amt says (0 to 1), what can
/// be opened, and the key the scene is rebuilt by (the camera stays where it is when only doors move: the furniture has
/// as many parts open as closed).
func furnShell(_ p: Project, _ room: Room, _ base: Shell3D, _ amt: [String: Double], _ snap: Bool) -> (Shell3D, Furn3D, String) {
    let s = AppSettings.shared, ws = s.workshop, mats = s.mats
    let fs = p.furniture.filter { $0.roomId == room.id || ($0.roomId == nil && FREE_ROOM + $0.id == room.id) }
    let fur = furniture3D(fs, base.bases, ws, { id in rgbOf(mats.first { $0.id == id }?.rgb ?? "#F5F5F2") }, [], amt: { k in amt[k] ?? 0 })
    var moving: [String] = []
    for k in amt.keys.sorted() { moving.append(k + "=" + String(Int(((amt[k] ?? 0) * 1000).rounded()))) }
    let key = shellKey([room], snap) + "|\(fs)|\(ws)|\(mats.map(\.rgb))|" + moving.joined(separator: ",")
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
    /// Its doors and drawers, opening and shutting.
    @State private var mo = DoorMotion()
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
            let (shell, fur, key) = furnShell(p, room, free ? built.floorOnly() : built, mo.prog, snap)
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
                    GBtn(tr("f3.openAll"), kind: .secondary, height: 44, corner: 12, fontSize: 14) { mo.openAll(fur.keys) }.accessibilityIdentifier("f3.openAll")
                    GBtn(tr("f3.close"), kind: .secondary, enabled: !mo.target.isEmpty, height: 44, corner: 12, fontSize: 14) { mo.closeAll() }.accessibilityIdentifier("f3.close")
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
        if let k = fur.pick(e, d) { mo.toggle(k) }
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
