import SwiftUI
import Observation

/*
 * The plumber's app's changes to an order and the things its screens share (Android ui/plumb/PlumbScreens.kt and
 * PView.kt): updating the order, a room or a fixture; taking a room's water marks in; putting a kit in; the kits chosen
 * before a room was measured; the routes, counts and warnings worked out once per change; the room's 3D with its
 * fixtures and pipes; the names and a warning's words.
 */

/// A tap with its drop (the plumber's icon).
let TAP = "M4 7h9a3 3 0 0 1 3 3v2 M8 7V4 M5 4h6 M16 15.5c0 0-2 2.6-2 4a2 2 0 0 0 4 0c0-1.4-2-4-2-4z"

/* ---------------- changing the order ---------------- */

func updatePlumb(_ pid: String, _ f: (inout PlumbOrder) -> Void) {
    Store.shared.update(pid) { p in f(&p.plumb) }
}

func updatePRoom(_ pid: String, _ rid: String, _ f: (inout PlRoom) -> Void) {
    updatePlumb(pid) { e in
        var cur = e.room(rid)
        f(&cur)
        e.rooms = e.rooms.filter { $0.roomId != rid } + [cur]
    }
}

func updateFix(_ pid: String, _ fid: String, _ f: (inout PlFix) -> Void) {
    updatePlumb(pid) { e in
        if let i = e.fixes.firstIndex(where: { $0.id == fid }) { f(&e.fixes[i]) }
    }
}

func updatePt(_ pid: String, _ id: String, _ f: (inout PlPoint) -> Void) {
    updatePlumb(pid) { e in
        if let i = e.points.firstIndex(where: { $0.id == id }) { f(&e.points[i]) }
    }
}

/// The plumber's room kinds (strings keys sx.k.*).
func pKindKey(_ k: String) -> String { "sx.k." + k }

/// The strings once each, in their order.
private func pUniq(_ xs: [String]) -> [String] {
    var seen = Set<String>()
    return xs.filter { seen.insert($0).inserted }
}

/// A workspace with a rectangular room in it, named name, of kind; returns the room's id.
@discardableResult func addPlumbRoom(_ pid: String, _ kind: String, _ name: String) -> String {
    let now = nowMs()
    let wt: String
    switch kind {
    case "kitchen": wt = "kitchen"
    case "bath", "wc": wt = "bath"
    default: wt = "room"
    }
    let w = Workspace(id: uid(), name: name, type: wt, created: now)
    let r = Room(id: uid(), floorId: w.id, name: name, created: now)
    Store.shared.update(pid) { p in
        p.floors.append(w); p.rooms.append(r)
        p.plumb.rooms.append(PlRoom(roomId: r.id, kind: kind))
    }
    return r.id
}

/// Takes the room's cold, hot and drain marked on its walls in as outlets (once each).
func takeInPlumbPoints(_ pid: String, _ rid: String) {
    guard let p = Store.shared.get(pid), let c = pCtxOf(p, rid, AppSettings.shared.angleSnap) else { return }
    let got = pFromSitePoints(c, { uid() })
    if got.isEmpty { return }
    Store.shared.update(pid) { pr in
        var er = pr.plumb.room(rid)
        er.seen = pUniq(er.seen + got.compactMap(\.from))
        pr.plumb.points += got
        pr.plumb.rooms = pr.plumb.rooms.filter { $0.roomId != rid } + [er]
    }
}

/// Puts kit k with choices o into measured room rid: the riser goes in first when there is none (here, when this is a
/// bathroom or toilet or there is none), the manifold with underfloor heating. Returns how many fixtures.
@discardableResult func applyPKit(_ pid: String, _ rid: String, _ k: PKit, _ o: POpts) -> Int {
    takeInPlumbPoints(pid, rid)
    let snap = AppSettings.shared.angleSnap
    guard let p = Store.shared.get(pid), let c = pCtxOf(p, rid, snap) else { return 0 }
    let have = p.plumb.fixes.filter { $0.roomId == rid }
    // a riser left on a deleted room counts as none
    var riser = liveRiser(p)
    if riser == nil && k.kind != "heat" {
        let wet = p.rooms.contains { r in
            guard r.id != rid, let k2 = pCtxOf(p, r.id, snap)?.kind else { return false }
            return k2 == "bath" || k2 == "wc"
        }
        if c.kind == "bath" || c.kind == "wc" || !wet { riser = riserIn(c, have) }
    }
    var fs = pPlaceKit(k, c, have, riser, { uid() }, o)
    if o.ufh && !p.plumb.fixes.contains(where: { $0.t == "manif" }) {
        if let m = placeFix("manif", c, have + fs, riser, uid()) { fs.append(m) }
    }
    let kind = c.kind
    let placedRiser = riser
    Store.shared.update(pid) { pr in
        var er = pr.plumb.room(rid)
        if er.kind.isEmpty { er.kind = k.kind == "heat" ? kind : k.kind }
        er.kits.append(k.id)
        er.ufh = er.ufh || o.ufh
        if o.ufh { er.step = o.step }
        pr.plumb.fixes += fs
        if let placedRiser, liveRiser(pr) == nil { pr.plumb.riser = placedRiser }
        pr.plumb.rooms = pr.plumb.rooms.filter { $0.roomId != rid } + [er]
        // a riser of its own only when there is water or a drain to bring (radiators and underfloor heating alone need none)
        if liveRiser(pr) == nil && needsRiser(pr), let d = defaultRiser(pr, snap) { pr.plumb.riser = d }
    }
    return fs.count
}

/// Kits chosen for rooms before they were measured go in once the rooms are.
func applyPPending(_ app: AppModel, _ pid: String) {
    guard let p = Store.shared.get(pid) else { return }
    let snap = AppSettings.shared.angleSnap
    for er in p.plumb.rooms where !er.pend.isEmpty {
        guard let r = p.rooms.first(where: { $0.id == er.roomId }), Geo.ready3D(r, snap) else { continue }
        let picks = er.pend
        updatePRoom(pid, er.roomId) { $0.pend = [] }
        for kp in picks {
            if let k = pkitOf(kp.kit) { applyPKit(pid, er.roomId, k, kp.o) }
        }
        app.say("el.pendDone", ["r": dn(r.name)])
    }
}

/// The order's routes, counts and warnings, worked out again only when the order changes.
final class PlumbCalcCache {
    static let shared = PlumbCalcCache()
    private struct In: Equatable { let plumb: PlumbOrder; let rooms: [Room]; let floors: [Workspace]; let snap: Bool }
    private var memo: [String: (In, PlumbCalc)] = [:]
    func of(_ p: Project) -> PlumbCalc {
        let i = In(plumb: p.plumb, rooms: p.rooms, floors: p.floors, snap: AppSettings.shared.angleSnap)
        if let m = memo[p.id], m.0 == i { return m.1 }
        let c = plumbCalcOf(p, i.snap)
        if memo.count > 40 { memo = [:] }
        memo[p.id] = (i, c)
        return c
    }
}

/* ---------------- names ---------------- */

/// "Vanna · Unitaz · 2 × Radiator" — fixtures by type.
func fixSummary(_ fs: [PlFix]) -> String {
    var parts: [String] = []
    for t in FIX_TYPES {
        let n = fs.filter { $0.t == t.id }.count
        if n == 1 { parts.append(tr("sx.t." + t.id)) } else if n > 1 { parts.append("\(n) × " + tr("sx.t." + t.id)) }
    }
    return parts.isEmpty ? tr("sx.noFix") : parts.joined(separator: " · ")
}

/// How many fixtures a room typed by size has.
func freeCount(_ f: PlFree) -> Int {
    let a = f.wc + f.basin + f.bath + f.shower + f.sink
    let b = f.wm + f.dw + f.wh + f.gb + f.rad + f.tr
    return a + b
}

/// A room's name in the order: its workspace's, or its own.
func pRoomName(_ p: Project, _ r: Room) -> String { p.floors.first { $0.id == r.floorId }.map { floorName($0) } ?? dn(r.name) }

/// A warning's words: its values read in the language ("~key" a strings key, decimals with a comma).
func warnText(_ w: PWarn) -> String {
    let en = AppSettings.shared.lang == .en
    var vars: [String: Any] = [:]
    for (k, v) in w.vars {
        if v.hasPrefix("~") { vars[k] = tr(String(v.dropFirst())) }
        else { vars[k] = en ? v : v.replacingOccurrences(of: ".", with: ",") }
    }
    return tr(w.key, vars)
}

/// Every pipe in room rid: the water and heating trunks and the drains' pieces there.
func runsIn(_ rt: PRoutes, _ rid: String) -> [PRun] {
    var out = rt.inRoom(rid)
    for d in rt.drains { out += d.runs.filter { $0.roomId == rid } }
    return out
}

/* ---------------- the estimate ---------------- */

/// Puts the counted pipe, fittings, valves and labour into the order's estimate in place of the calculator's lines; typed
/// lines stay. Names and units are stored as keys, so they follow the app's and the report's language.
func applyPlumbRows(_ app: AppModel, _ p: Project) {
    let st = AppSettings.shared
    let r = plumbRows(p, st.trade, st.angleSnap) { k, v in k.hasPrefix("tu.") ? "@u." + String(k.dropFirst(3)) : keyName(k, v) }
    Store.shared.update(p.id) { pr in
        if pr.stage == "measure" { pr.stage = "estimate" }
        pr.estimate.materials = pr.estimate.materials.filter { !$0.id.hasPrefix("t-") } + r.mats.map { var x = $0; x.id = "t-" + uid(); return x }
        pr.estimate.labor = pr.estimate.labor.filter { !$0.id.hasPrefix("t-") } + r.labor.map { var x = $0; x.id = "t-" + uid(); return x }
    }
    app.say("trc.done", ["n": r.mats.count + r.labor.count])
}

/* ---------------- the room in 3D ---------------- */

/// The room's 3D with its fixtures and pipes, worked out away from the screen's thread: until it is ready the room shows
/// as it was (without fixtures the first time).
@Observable final class PlumbShellBox {
    private(set) var made: (Shell3D, String)? = nil
    @ObservationIgnored private var want = ""
    @ObservationIgnored private var baseRoom: Room? = nil
    @ObservationIgnored private var baseSnap = true
    @ObservationIgnored private var baseShell: Shell3D? = nil

    /// The room as drawn: its own water and drain marks, once taken in, are drawn as the plumber's outlets.
    static func shown(_ r: Room, _ seen: [String]) -> Room {
        var x = r
        x.points = r.points.filter { !SITE_WATER.contains($0.t) || !seen.contains($0.id) }
        return x
    }

    /// The room's walls and floor, built again only when the room changes.
    func base(_ room: Room, _ snap: Bool) -> Shell3D {
        if let b = baseShell, baseRoom == room, baseSnap == snap { return b }
        let b = buildShell([room], single: true, snap: snap)
        baseRoom = room; baseSnap = snap; baseShell = b
        return b
    }

    /// The shell to show for room r of order p and the key it is drawn by; starts working out a new one when they changed.
    func shell(_ p: Project, _ r: Room, _ snap: Bool) -> (Shell3D, String) {
        let room = PlumbShellBox.shown(r, p.plumb.room(r.id).seen)
        let b = base(room, snap)
        let k0 = shellKey([room], snap)
        let k = k0 + "|plumb|\(p.plumb)|" + shellKey(p.rooms, snap)
        if k != want {
            want = k
            let pp = p, rid = r.id
            DispatchQueue.global(qos: .userInitiated).async {
                let s = plumbShell(pp, rid, room, b, snap)
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

/// The room's scene with its fixtures, the riser, the pipes and the underfloor loops.
func plumbShell(_ p: Project, _ rid: String, _ room: Room, _ base: Shell3D, _ snap: Bool) -> Shell3D {
    let calc = plumbCalcOf(p, snap)
    guard let c = calc.ctxs.first(where: { $0.id == rid }) else { return base }
    guard let w0 = Geo.walls(room, snap).first, let b = base.bases[w0.id] else { return base }
    let dx = b.ox - w0.p0.x / 1000, dz = b.oz - w0.p0.y / 1000
    let fs = fixesIn(p, c)
    let loop = calc.routes.loops.first { $0.roomId == rid }
    let parts = plumbParts(c, fs, pointsIn(p, c, fs), calc.routes.riser, runsIn(calc.routes, rid), loop, dx, dz)
    return base.plus(parts, [])
}
