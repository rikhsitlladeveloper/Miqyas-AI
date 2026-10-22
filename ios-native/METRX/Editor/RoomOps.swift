import Foundation
import Observation

/// What the room editor changes, and its undo history (prototype applyDim, edLaser, edConfirm, saveOpening, pushHist…),
/// ported from the Android app's RoomOps. History is per room, at most 40 steps, in memory only (as in the prototype);
/// a new change clears redo.
@Observable
final class RoomOps {
    static let shared = RoomOps()

    /// The measurement the step card shows, when the builder picked one (prototype U.edFocus / edFocusRid).
    var focusKey: String? = nil
    var focusRoom: String? = nil
    /// "Measuring again" for this room:key (prototype U.edRe).
    var again: String? = nil
    var panelOpen = false
    /// The room the panel state belongs to: another room starts with the list closed.
    @ObservationIgnored var panelRoom: String? = nil
    var tipSeen = false
    /// A drawn room's plan mode: "plan", "shape" (move corners) or "diag" (pick two corners), and which room it is for.
    var polyMode = "plan"
    var polyRoom: String? = nil
    var diagFirst: Int? = nil
    @ObservationIgnored private var simCount = 0

    // the name is not in it: a rename has no history, so Undo must not take it back
    private struct Snap { let dims: [String: Dim]; let openings: [Opening]; let poly: Poly?; let rot: Int; let points: [SitePoint]; let features: [Feature] }
    @ObservationIgnored private var undoH: [String: [Snap]] = [:]
    @ObservationIgnored private var redoH: [String: [Snap]] = [:]
    private(set) var histTick = 0

    private var app: AppModel { AppModel.shared }
    private var s: AppSettings { AppSettings.shared }
    var snap: Bool { s.angleSnap }
    var unit: LenUnit { s.unit }
    var en: Bool { s.lang == .en }

    /// Plan ↔ 3D on the same page (prototype A.mode): the sheet closes and the drawn room's shape / diagonal modes end.
    func mode(_ pid: String, _ rid: String, _ m: String) {
        app.sheet = nil; polyMode = "plan"; diagFirst = nil
        app.setTop(.editor(pid: pid, rid: rid, mode: m))
    }

    private func snapOf(_ r: Room) -> Snap { Snap(dims: r.dims, openings: r.openings, poly: r.poly, rot: r.rot, points: r.points, features: r.features) }
    // a laser reading waiting on a value is not history: one that came after the snapshot stays
    private func restore(_ r: inout Room, _ s: Snap) {
        let now = r.dims
        r.dims = s.dims.reduce(into: [String: Dim]()) { out, e in var d = e.value; d.pending = now[e.key]?.pending ?? d.pending; out[e.key] = d }
        r.openings = s.openings; r.poly = s.poly; r.rot = s.rot; r.points = s.points; r.features = s.features
    }

    func canUndo(_ rid: String) -> Bool { _ = histTick; return !(undoH[rid] ?? []).isEmpty }
    func canRedo(_ rid: String) -> Bool { _ = histTick; return !(redoH[rid] ?? []).isEmpty }

    func room(_ pid: String, _ rid: String) -> Room? { Store.shared.get(pid)?.rooms.first { $0.id == rid } }

    private func put(_ pid: String, _ rid: String, _ f: (inout Room) -> Void) {
        Store.shared.update(pid) { p in if let i = p.rooms.firstIndex(where: { $0.id == rid }) { f(&p.rooms[i]) } }
    }

    /// Changes one room; hist records the state before the change for Undo.
    func change(_ pid: String, _ rid: String, hist: Bool = true, _ f: (inout Room) -> Void) {
        guard let before = room(pid, rid) else { return }
        if hist {
            var u = undoH[rid] ?? []
            u.append(snapOf(before)); while u.count > 40 { u.removeFirst() }
            undoH[rid] = u; redoH[rid] = []; histTick += 1
        }
        put(pid, rid, f)
    }

    func undo(_ pid: String, _ rid: String) {
        guard let r = room(pid, rid), let s = undoH[rid]?.popLast() else { return }
        redoH[rid, default: []].append(snapOf(r)); histTick += 1
        put(pid, rid) { restore(&$0, s) }
        app.sheet = nil
        app.say("ed.undone")
    }

    func redo(_ pid: String, _ rid: String) {
        guard let r = room(pid, rid), let s = redoH[rid]?.popLast() else { return }
        undoH[rid, default: []].append(snapOf(r)); histTick += 1
        put(pid, rid) { restore(&$0, s) }
        app.sheet = nil
    }

    /* ---------------- measuring ---------------- */

    func dimLabel(_ k: String) -> String {
        k == "H" ? tr("ed.Hs") : k == "T" ? tr("ed.T") : k.hasPrefix("X") ? tr("sk.diagName", ["d": k]) : tr("op.wall") + " " + k
    }

    /// Shows this measurement in the step card (prototype openMeasure, editor.js override).
    func focus(_ rid: String, _ k: String) { focusRoom = rid; focusKey = k; panelOpen = false; app.sheet = nil }

    /// A wall tapped in the plan. Rect C and D copy A and B, so they measure their source.
    func select(_ pid: String, _ rid: String, _ wall: String) {
        guard let r = room(pid, rid) else { return }
        let w = Geo.walls(r, snap).first { $0.id == wall }
        if let w, w.derived, !r.isPoly { app.say("ed.derived", ["w": wall, "s": w.dimKey], kind: .info); focus(rid, w.dimKey); return }
        if let w, r.isPoly, w.status == "calc" { app.say("sk.computedTap", ["w": wall, "v": Geo.fmtLen(w.len, .m, en)], kind: .info) }
        focus(rid, w?.dimKey ?? wall)
    }

    /// A simulated laser reading (prototype simTarget + edLaser): every third one is 2 mm off, like a real laser.
    func laser(_ pid: String, _ rid: String, _ k: String) {
        guard let r = room(pid, rid) else { return }
        let target = simTarget(r, k)
        simCount += 1
        let mm = simCount % 3 == 0 ? target + 2 : target
        change(pid, rid, hist: false) { $0.dims[k] = Dim(v: $0.dim(k).v, src: $0.dim(k).src, pending: Pending(mm: mm, src: "sim")) }
        focusRoom = rid; focusKey = k
    }

    private func simTarget(_ r: Room, _ k: String) -> Int {
        if k == "H" { return Int.random(in: 2500...3200) }
        if k == "T" { return 200 }
        if r.isPoly && k.hasPrefix("X") {
            let g = Geo.polyGeo(r, snap)
            guard let d = r.poly!.diags.first(where: { $0.id == k }) else { return 3000 }
            return max(10, Int(hypot(g.verts[d.a].x - g.verts[d.b].x, g.verts[d.a].y - g.verts[d.b].y) / 10) * 10)
        }
        if r.isPoly {
            guard let w = Geo.walls(r, snap).first(where: { $0.id == k }) else { return 3000 }
            return max(10, Int(hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y) / 10) * 10)
        }
        return Int.random(in: 2400...6400)
    }

    /// The tray's laser button: a simulated reading near one of the room's still-needed lengths (prototype trayLaser).
    func trayReading(_ pid: String, _ rid: String) {
        guard let r = room(pid, rid) else { return }
        let pool = Geo.stepKeys(r, snap).map { simTarget(r, $0) }
        let n = s.readings.count
        s.addReading(pool[n % max(1, pool.count)] + ((n % 3) - 1) * 2, "sim")
    }

    /// Puts a reading on a wall or the height, waiting for confirmation (prototype trayAssign).
    func assignReading(_ pid: String, _ rid: String, _ id: String, _ k: String) {
        guard let x = s.readings.first(where: { $0.id == id }) else { return }
        // the same limit as a typed value (a 3 m reading is not a wall's thickness)
        let lim = Geo.dimMax(k)
        if x.mm > lim {
            let m = Geo.fmtLen(lim, s.unit, en).replacingOccurrences(of: "[.,]0+$", with: "", options: .regularExpression)
            app.say("err.max", ["max": m + " " + unitName()], kind: .error); return
        }
        change(pid, rid, hist: false) { $0.dims[k] = Dim(v: $0.dim(k).v, src: $0.dim(k).src, pending: Pending(mm: x.mm, src: x.src, from: "quick")) }
        s.markReadingUsed(id, dimLabel(k))
        focus(rid, k)
    }

    /// Confirms a value (prototype applyDim): history, the value, the toast with Undo; the card moves on by itself.
    func apply(_ pid: String, _ rid: String, _ k: String, _ mm: Int, _ src: String) {
        change(pid, rid) { $0.dims[k] = Dim(v: mm, src: src) }
        if focusKey == k { focusKey = nil }
        if again == "\(rid):\(k)" { again = nil }
        app.sheet = nil
        app.say("ms.confirmed", ["d": dimLabel(k), "v": Geo.fmtLen(mm, unit, en, full: true) + " " + unitName()], action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    func confirm(_ pid: String, _ rid: String, _ k: String) { if let p = room(pid, rid)?.dim(k).pending { apply(pid, rid, k, p.mm, p.src) } }

    /// Throws the reading away; with a confirmed value the card says "measuring again".
    func againReading(_ pid: String, _ rid: String, _ k: String) {
        guard let r = room(pid, rid) else { return }
        change(pid, rid, hist: false) { $0.dims[k]?.pending = nil }
        again = r.dim(k).v != nil ? "\(rid):\(k)" : nil
        focusRoom = rid; focusKey = k
    }

    func remeasure(_ pid: String, _ rid: String, _ k: String) {
        change(pid, rid, hist: false) { $0.dims[k]?.pending = nil }
        focusRoom = rid; focusKey = k; again = "\(rid):\(k)"
    }

    func cancelAgain() { again = nil }

    /* ---------------- doors and windows ---------------- */

    func opName(_ o: Opening) -> String { tr(o.type == "door" ? "op.door" : "op.window") }

    func issue(_ r: Room, _ o: Opening) -> Geo.Issue? { Geo.openingIssue(r, o, opName(o), unit, en, snap) }

    func saveOpening(_ pid: String, _ rid: String, _ o: Opening, isNew: Bool) {
        // saving from the sheet confirms a dragged (approximate) position
        var clean = o; clean.offDrag = false; clean.sillDrag = false; if o.type == "door" { clean.sill = 0 }
        change(pid, rid) { r in if isNew { r.openings.append(clean) } else if let i = r.openings.firstIndex(where: { $0.id == o.id }) { r.openings[i] = clean } }
        app.sheet = nil
        app.say(isNew ? "op.added" : "op.saved", ["o": opName(o)], action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    func deleteOpening(_ pid: String, _ rid: String, _ o: Opening) {
        change(pid, rid) { $0.openings.removeAll { $0.id == o.id } }
        app.sheet = nil
        app.say("op.deleted", ["o": opName(o)], action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    /* ---------------- columns and niches ---------------- */

    func saveFeature(_ pid: String, _ rid: String, _ f: Feature, isNew: Bool) {
        change(pid, rid) { r in if isNew { r.features.append(f) } else if let i = r.features.firstIndex(where: { $0.id == f.id }) { r.features[i] = f } }
        app.sheet = nil
        app.say("ft.saved", action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    func deleteFeature(_ pid: String, _ rid: String, _ f: Feature) {
        change(pid, rid) { $0.features.removeAll { $0.id == f.id } }
        app.sheet = nil
        app.say("op.deleted", ["o": tr("ft." + f.type)], action: "common.undo") { [pid, rid] in RoomOps.shared.undo(pid, rid) }
    }

    /* ---------------- site points (furniture orders) ---------------- */

    func pointName(_ t: String) -> String { tr("pt." + t) }

    func savePoint(_ pid: String, _ rid: String, _ x: SitePoint, isNew: Bool) {
        change(pid, rid) { r in if isNew { r.points.append(x) } else if let i = r.points.firstIndex(where: { $0.id == x.id }) { r.points[i] = x } }
        app.sheet = nil
        app.say(isNew ? "pt.added" : "pt.saved", ["o": pointName(x.t)], action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    func deletePoint(_ pid: String, _ rid: String, _ x: SitePoint) {
        change(pid, rid) { $0.points.removeAll { $0.id == x.id } }
        app.sheet = nil
        app.say("pt.deleted", ["o": pointName(x.t)], action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    /// The end of a drag: a position that doesn't fit goes back; a good one is kept and marked approximate.
    func moveOpening(_ pid: String, _ rid: String, _ o: Opening, _ off: Int, _ sill: Int) {
        guard let r = room(pid, rid), off != o.off || sill != o.sill else { return }
        var moved = o; moved.off = off; moved.sill = sill
        if issue(r, moved) != nil { app.say("op.dragBack", ["o": opName(o)], kind: .error); return }
        change(pid, rid) { rr in
            if let i = rr.openings.firstIndex(where: { $0.id == o.id }) {
                let was = rr.openings[i]
                moved.offDrag = was.offDrag || off != o.off; moved.sillDrag = was.sillDrag || sill != o.sill
                rr.openings[i] = moved
            }
        }
        app.say("op.moved", ["o": opName(o)], action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    /* ---------------- the room ---------------- */

    func rotate(_ pid: String, _ rid: String) {
        change(pid, rid) { $0.rot = ($0.rot + 1) % 4 }
        app.sheet = nil
        app.say("ri.rotated", kind: .info, action: "common.undo") { [weak self] in self?.undo(pid, rid) }
    }

    func rename(_ pid: String, _ rid: String, _ name: String) { change(pid, rid, hist: false) { $0.name = name.trimmingCharacters(in: .whitespaces) }; app.sheet = nil }

    /// Deletes the room at once and offers Undo (prototype deleteRoomEd); leaves the editor for the workspace.
    func deleteRoom(_ pid: String, _ rid: String) {
        guard let p = Store.shared.get(pid), let idx = p.rooms.firstIndex(where: { $0.id == rid }) else { return }
        let r = p.rooms[idx]
        let pieces = p.furniture.filter { $0.roomId == rid }
        let inReport = p.reportRooms[rid]   // left out of the report: Undo keeps it out
        Store.shared.update(pid) { $0.furniture = outOfRooms($0, [rid]); $0.rooms.removeAll { $0.id == rid }; $0.reportRooms.removeValue(forKey: rid) }
        app.sheet = nil
        app.popTo { r in
            switch r { case .editor, .wallView: return false; default: return true }
        }
        app.dropMissing()   // the room's pages in the other tabs' stacks go too
        app.say("room.deleted", ["n": dn(r.name)], action: "common.undo") {
            Store.shared.update(pid) { pr in
                pr.rooms.insert(r, at: min(idx, pr.rooms.count)); pr.furniture = pr.furniture.map { f in pieces.first { $0.id == f.id } ?? f }
                if let inReport { pr.reportRooms[rid] = inReport }
            }
        }
    }

    /// The card the editor shows (prototype ed2Focus): the picked measurement, a reading waiting, the next unmeasured
    /// one, a problem, or done.
    struct Focus { let kind: String; var k: String? = nil; var issue: Opening? = nil; var ft: Feature? = nil }

    /// Every measurement of the room: its walls and height, then a drawn room's diagonals.
    func measureKeys(_ r: Room) -> [String] { Geo.stepKeys(r, snap) + (r.poly?.diags.map { $0.id } ?? []) }

    func focusOf(_ r: Room) -> Focus {
        let keys = measureKeys(r)
        if let fk = focusKey, focusRoom == r.id, r.dims[fk] != nil {
            let st = r.dim(fk).status
            return Focus(kind: st == "conf" && again == "\(r.id):\(fk)" ? "again" : st, k: fk)
        }
        if let k = keys.first(where: { r.dim($0).status == "recv" }) { return Focus(kind: "recv", k: k) }
        if let k = keys.first(where: { r.dim($0).status == "unset" }) { return Focus(kind: "unset", k: k) }
        if let o = r.openings.first(where: { issue(r, $0) != nil }) { return Focus(kind: "bad", issue: o) }
        // a column or niche that no longer fits (the wall or the height changed after it was added)
        if let x = r.features.first(where: { Geo.featureIssue(r, $0, snap) != nil }) { return Focus(kind: "badFt", ft: x) }
        return Focus(kind: "ok")
    }

    /// The next thing to do in a room (prototype hmNext): a reading to confirm, a value to measure, a problem, or done.
    struct Next { let cls: String; let icon: String; let text: String }

    func next(_ r: Room) -> Next {
        let keys = Geo.stepKeys(r, snap)
        if let k = keys.first(where: { r.dim($0).status == "recv" }) { return Next(cls: "recv", icon: "clock", text: tr("hm.next.recv", ["w": dimLabel(k)])) }
        if let k = keys.first(where: { r.dim($0).status == "unset" }) { return Next(cls: "unset", icon: "dim", text: tr("hm.next.unset", ["w": dimLabel(k)])) }
        if r.openings.contains(where: { issue(r, $0) != nil }) { return Next(cls: "bad", icon: "alert", text: tr("hm.next.bad")) }
        let a = Geo.areas(r, snap)
        let text: String
        if let net = a?.net { text = tr("ws.netWall", ["v": Geo.fmtArea(net, en)]) }
        else if let a { text = Geo.fmtArea(a.floor, en) + " " + tr("u.m2") }
        else { text = tr("hm.next.ok") }
        return Next(cls: "ok", icon: "check", text: text)
    }

    var laserOn: Bool { s.laser == .connected }
}

/// "m" or "sm" in the current language.
func unitName() -> String { tr(AppSettings.shared.unit == .cm ? "u.cm" : "u.m") }
