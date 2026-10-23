import Foundation

/*
 * Deleting a room (or the workspace it is in) takes its trades' data with it: the tile layouts and tiling extras laid in
 * it, the electrician's devices and room settings (and the panel when it was on its wall), the plumber's fixtures,
 * outlets and room settings (and the riser), and the windows and doors filling its openings stay but without a room.
 * What was taken is kept so Undo puts it back. Android data/RoomsGone.kt; unit-tested (RoomsGoneTests).
 */

/// What deleting rooms took out of an order's trade data, kept for Undo; win the products as they were in the room.
struct TradesGone: Equatable {
    var tiles: [TileLayout] = []
    var troom: [TileRoom] = []
    var edevs: [ElecDev] = []
    var erooms: [ElecRoom] = []
    var panel: ElecPanel? = nil
    var pfixes: [PlFix] = []
    var ppoints: [PlPoint] = []
    var prooms: [PlRoom] = []
    var riser: PlRiser? = nil
    var win: [WinItem] = []
}

/// Project p with rooms rids gone from its trades' data (the rooms themselves are left to the caller), and what was taken.
func tradesOut(_ p: Project, _ rids: Set<String>) -> (Project, TradesGone) {
    let e = p.elec
    let pl = p.plumb
    var g = TradesGone()
    g.tiles = p.tiles.filter { $0.roomId.map { rids.contains($0) } ?? false }
    g.troom = p.troom.filter { rids.contains($0.roomId) }
    g.edevs = e.devs.filter { rids.contains($0.roomId) }
    g.erooms = e.rooms.filter { rids.contains($0.roomId) }
    g.panel = e.panel.flatMap { rids.contains($0.roomId) ? $0 : nil }
    g.pfixes = pl.fixes.filter { rids.contains($0.roomId) }
    g.ppoints = pl.points.filter { rids.contains($0.roomId) }
    g.prooms = pl.rooms.filter { rids.contains($0.roomId) }
    g.riser = pl.riser.flatMap { rids.contains($0.roomId) ? $0 : nil }
    g.win = p.win.items.filter { $0.roomId.map { rids.contains($0) } ?? false }

    var q = p
    q.tiles = p.tiles.filter { !($0.roomId.map { rids.contains($0) } ?? false) }
    q.troom = p.troom.filter { !rids.contains($0.roomId) }
    q.elec.devs = e.devs.filter { !rids.contains($0.roomId) }
    q.elec.rooms = e.rooms.filter { !rids.contains($0.roomId) }
    if g.panel != nil { q.elec.panel = nil }
    q.plumb.fixes = pl.fixes.filter { !rids.contains($0.roomId) }
    q.plumb.points = pl.points.filter { !rids.contains($0.roomId) }
    q.plumb.rooms = pl.rooms.filter { !rids.contains($0.roomId) }
    if g.riser != nil { q.plumb.riser = nil }
    // a window or door stays in the order without a room: its size as it was, in a wall as thick as the room's
    let rooms = p.rooms
    q.win.items = p.win.items.map { it in
        guard let rid = it.roomId, rids.contains(rid) else { return it }
        var x = it
        x.freeT = rooms.first { $0.id == rid }?.dim("T").v ?? it.freeT
        x.roomId = nil; x.opening = nil; x.fit = false
        return x
    }
    return (q, g)
}

/// Puts back what was taken: items still there are kept, the gone ones (by id) added.
private func goneBack<T>(_ now: [T], _ gone: [T], _ id: (T) -> String) -> [T] {
    let have = Set(now.map(id))
    return now + gone.filter { !have.contains(id($0)) }
}

/// What tradesOut took, put back (Undo): what is still there is kept; the panel and riser only where none was set since.
func tradesBack(_ p: Project, _ g: TradesGone) -> Project {
    var q = p
    q.tiles = goneBack(p.tiles, g.tiles) { $0.id }
    q.troom = goneBack(p.troom, g.troom) { $0.roomId }
    q.elec.devs = goneBack(p.elec.devs, g.edevs) { $0.id }
    q.elec.rooms = goneBack(p.elec.rooms, g.erooms) { $0.roomId }
    q.elec.panel = p.elec.panel ?? g.panel
    q.plumb.fixes = goneBack(p.plumb.fixes, g.pfixes) { $0.id }
    q.plumb.points = goneBack(p.plumb.points, g.ppoints) { $0.id }
    q.plumb.rooms = goneBack(p.plumb.rooms, g.prooms) { $0.roomId }
    q.plumb.riser = p.plumb.riser ?? g.riser
    var wins: [String: WinItem] = [:]
    for w in g.win { wins[w.id] = w }
    q.win.items = p.win.items.map { wins[$0.id] ?? $0 }
    return q
}

/// An older order's trade data on rooms that are gone (deleted before deleting took it along): taken out, windows kept without a room.
func withoutOrphans(_ p: Project) -> Project {
    var used: [String] = p.tiles.compactMap { $0.roomId }
    used += p.troom.map { $0.roomId }
    used += p.elec.devs.map { $0.roomId }
    used += p.elec.rooms.map { $0.roomId }
    if let r = p.elec.panel?.roomId { used.append(r) }
    if let r = p.plumb.riser?.roomId { used.append(r) }
    used += p.plumb.fixes.map { $0.roomId }
    used += p.plumb.points.map { $0.roomId }
    used += p.plumb.rooms.map { $0.roomId }
    used += p.win.items.compactMap { $0.roomId }
    // a room typed by size ("free:<id>") is not a drawn room
    let have = Set(p.rooms.map { $0.id })
    let gone = Set(used.filter { !$0.hasPrefix("free:") && !have.contains($0) })
    return gone.isEmpty ? p : tradesOut(p, gone).0
}
