import SwiftUI
import Observation

/*
 * The windows-and-doors app's changes to an order and the things its screens share (Android ui/win/WinScreens.kt and
 * WView.kt): updating the order or a product; a new room; products refitted when their opening was measured again;
 * the rooms, counts and warnings worked out once per change; the names; a warning's words; the estimate's lines; the
 * room's 3D with its products in the openings.
 */

/// A window with its cross (the windows-and-doors icon).
let W_WINDOW_ICON = "M4 3h16v18H4z M12 3v18 M4 12h16"

/* ---------------- changing the order ---------------- */

func updateWin(_ pid: String, _ f: (inout WinOrder) -> Void) {
    Store.shared.update(pid) { p in f(&p.win) }
}

func updateWinItem(_ pid: String, _ iid: String, _ f: (WinItem) -> WinItem) {
    updateWin(pid) { e in
        if let i = e.items.firstIndex(where: { $0.id == iid }) { e.items[i] = f(e.items[i]) }
    }
}

/// A workspace with a rectangular room in it named name; returns the room's id.
@discardableResult func addWinRoom(_ pid: String, _ name: String) -> String {
    let now = nowMs()
    let w = Workspace(id: uid(), name: name, type: "room", created: now)
    let r = Room(id: uid(), floorId: w.id, name: name, created: now)
    Store.shared.update(pid) { p in
        p.floors.append(w); p.rooms.append(r)
    }
    return r.id
}

/// Products that follow their openings are refitted when an opening was measured again (the gap kept).
func refitWin(_ pid: String) {
    guard let p = Store.shared.get(pid) else { return }
    var changed: [String: WinItem] = [:]
    for it in p.win.items where it.fit && it.inRoom {
        guard let o = p.rooms.first(where: { $0.id == it.roomId })?.openings.first(where: { $0.id == it.opening }) else { continue }
        let s = wSizeFor(o.w, o.h, o.type, it.gap)
        if s.0 == it.w && s.1 == it.h { continue }
        changed[it.id] = wRefit(it, o.w, o.h, o.type)
    }
    if changed.isEmpty { return }
    updateWin(pid) { e in e.items = e.items.map { changed[$0.id] ?? $0 } }
}

/// The order's rooms, counts and warnings, worked out again only when the order changes.
final class WinCalcCache {
    static let shared = WinCalcCache()
    private struct In: Equatable {
        let win: WinOrder; let rooms: [Room]; let floors: [Workspace]; let plumb: PlumbOrder; let furniture: [Furniture]; let snap: Bool
    }
    private var memo: [String: (In, WinCalc)] = [:]
    func of(_ p: Project) -> WinCalc {
        let i = In(win: p.win, rooms: p.rooms, floors: p.floors, plumb: p.plumb, furniture: p.furniture, snap: AppSettings.shared.angleSnap)
        if let m = memo[p.id], m.0 == i { return m.1 }
        let c = winCalcOf(p, i.snap)
        if memo.count > 40 { memo = [:] }
        memo[p.id] = (i, c)
        return c
    }
}

/* ---------------- names ---------------- */

/// A product's name: its type ("3 tabaqali deraza"), or the name typed for one without a room.
func wItemTitle(_ it: WinItem) -> String {
    it.name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("dw.k." + it.kind) : it.name
}

/// "1260 × 1360" — a product's size, mm.
func wSizeText(_ w: Int, _ h: Int) -> String { "\(w) × \(h)" }

/// An opening's name in its room: "Deraza 2", "Eshik 1" (numbered by kind in the room's order).
func wOpeningKey(_ r: Room, _ o: Opening) -> (String, Int) {
    let same = r.openings.filter { $0.type == o.type }
    let n = (same.firstIndex { $0.id == o.id } ?? -1) + 1
    return (o.type == "door" ? "dw.opD" : "dw.opW", n)
}

func wOpeningName(_ r: Room, _ o: Opening) -> String {
    let k = wOpeningKey(r, o)
    return tr(k.0, ["n": k.1])
}

/// "2 deraza · 1 eshik" — the products by group.
func wSummary(_ items: [WinItem]) -> String {
    let d = items.filter(\.isDoor).reduce(0) { $0 + $1.qty }
    let w = items.filter { !$0.isDoor }.reduce(0) { $0 + $1.qty }
    var parts: [String] = []
    if w > 0 { parts.append(tr("dw.nWin", ["n": w])) }
    if d > 0 { parts.append(tr("dw.nDoor", ["n": d])) }
    return parts.isEmpty ? tr("dw.none") : parts.joined(separator: " · ")
}

/// A room's name: its workspace's, else its own.
func wRoomName(_ p: Project, _ rid: String?) -> String {
    guard let r = p.rooms.first(where: { $0.id == rid }) else { return "" }
    if let w = p.floors.first(where: { $0.id == r.floorId }) { return floorName(w) }
    return dn(r.name)
}

/// A warning's words: its values read in the language ("~key" a strings key, decimals with a comma).
func wWarnText(_ w: WWarn) -> String {
    let en = AppSettings.shared.lang == .en
    var vars: [String: Any] = [:]
    for (k, v) in w.vars {
        if v.hasPrefix("~") { vars[k] = tr(String(v.dropFirst())) }
        else { vars[k] = en ? v : v.replacingOccurrences(of: ".", with: ",") }
    }
    return tr(w.key, vars)
}

/// Whether order p has an opening of room rid that type kind could fill.
func wCanFill(_ p: Project, _ rid: String, _ kind: String) -> Bool {
    p.rooms.first { $0.id == rid }?.openings.contains { wFillsType(kind, $0.type) } == true
}

/* ---------------- the estimate ---------------- */

/// Puts the counted parts and labour into the order's estimate in place of the calculator's lines; typed lines stay.
/// Names and units are stored as keys, so they follow the app's and the report's language.
func applyWinRows(_ app: AppModel, _ p: Project) {
    let r = winRows(p, AppSettings.shared.trade.win) { k, v in k.hasPrefix("tu.") ? "@u." + String(k.dropFirst(3)) : keyName(k, v) }
    Store.shared.update(p.id) { pr in
        if pr.stage == "measure" { pr.stage = "estimate" }
        pr.estimate.materials = pr.estimate.materials.filter { !$0.id.hasPrefix("t-") } + r.mats.map { var x = $0; x.id = "t-" + uid(); return x }
        pr.estimate.labor = pr.estimate.labor.filter { !$0.id.hasPrefix("t-") } + r.labor.map { var x = $0; x.id = "t-" + uid(); return x }
    }
    app.say("trc.done", ["n": r.mats.count + r.labor.count])
}

/* ---------------- the room in 3D ---------------- */

/// The room's 3D with its products in the openings, worked out away from the screen's thread; the filled openings get
/// no standard window or door. Until it is ready the room shows as it was.
@Observable final class WinShellBox {
    private(set) var made: (Shell3D, String)? = nil
    @ObservationIgnored private var want = ""
    @ObservationIgnored private var baseRoom: Room? = nil
    @ObservationIgnored private var baseSnap = true
    @ObservationIgnored private var baseBare: Set<String> = []
    @ObservationIgnored private var baseShell: Shell3D? = nil

    /// The room's walls and floor without the filled openings' standard models, built again only when they change.
    func base(_ room: Room, _ snap: Bool, _ bare: Set<String>) -> Shell3D {
        if let b = baseShell, baseRoom == room, baseSnap == snap, baseBare == bare { return b }
        let b = buildShell([room], single: true, snap: snap, bare: bare)
        baseRoom = room; baseSnap = snap; baseBare = bare; baseShell = b
        return b
    }

    /// The shell to show for room r of order p and the key it is drawn by; starts working out a new one when they changed.
    func shell(_ p: Project, _ r: Room, _ snap: Bool) -> (Shell3D, String) {
        var bare = Set<String>()
        for it in p.win.items where it.roomId == r.id && it.inRoom {
            if let o = it.opening { bare.insert(o) }
        }
        let b = base(r, snap, bare)
        let k0 = shellKey([r], snap) + "|bare|" + bare.sorted().joined(separator: ",")
        let k = k0 + "|win|\(p.win)|" + shellKey(p.rooms, snap)
        if k != want {
            want = k
            let pp = p, room = r
            DispatchQueue.global(qos: .userInitiated).async {
                let s = winShell(pp, room, b, snap)
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

/// The room's scene with its products fitted in their openings.
func winShell(_ p: Project, _ room: Room, _ base: Shell3D, _ snap: Bool) -> Shell3D {
    guard let c = wCtxOf(p, room.id, snap) else { return base }
    guard let w0 = Geo.walls(room, snap).first, let b = base.bases[w0.id] else { return base }
    let dx = b.ox - w0.p0.x / 1000, dz = b.oz - w0.p0.y / 1000
    return base.plus(winParts(c, wPlacedIn(p, c), dx, dz), [])
}
