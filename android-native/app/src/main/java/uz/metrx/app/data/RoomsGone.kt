package uz.metrx.app.data

import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecPanel
import uz.metrx.app.elec.ElecRoom
import uz.metrx.app.plumb.PlFix
import uz.metrx.app.plumb.PlPoint
import uz.metrx.app.plumb.PlRiser
import uz.metrx.app.plumb.PlRoom
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.TileRoom
import uz.metrx.app.win.WinItem

/*
 * Deleting a room (or the workspace it is in) takes its trades' data with it: the tile layouts and tiling extras laid in
 * it, the electrician's devices and room settings (and the panel when it was on its wall), the plumber's fixtures,
 * outlets and room settings (and the riser), and the windows and doors filling its openings stay but without a room.
 * What was taken is kept so Undo puts it back. Pure Kotlin, unit-tested (OrdersTest).
 */

/** What deleting rooms took out of an order's trade data, kept for Undo; [win] the products as they were in the room. */
data class TradesGone(
    val tiles: List<TileLayout> = emptyList(), val troom: List<TileRoom> = emptyList(),
    val edevs: List<ElecDev> = emptyList(), val erooms: List<ElecRoom> = emptyList(), val panel: ElecPanel? = null,
    val pfixes: List<PlFix> = emptyList(), val ppoints: List<PlPoint> = emptyList(), val prooms: List<PlRoom> = emptyList(), val riser: PlRiser? = null,
    val win: List<WinItem> = emptyList()
)

/** Project [p] with rooms [rids] gone from its trades' data (the rooms themselves are left to the caller), and what was taken. */
fun tradesOut(p: Project, rids: Set<String>): Pair<Project, TradesGone> {
    val e = p.elec; val pl = p.plumb
    val g = TradesGone(
        tiles = p.tiles.filter { it.roomId in rids }, troom = p.troom.filter { it.roomId in rids },
        edevs = e.devs.filter { it.roomId in rids }, erooms = e.rooms.filter { it.roomId in rids }, panel = e.panel?.takeIf { it.roomId in rids },
        pfixes = pl.fixes.filter { it.roomId in rids }, ppoints = pl.points.filter { it.roomId in rids }, prooms = pl.rooms.filter { it.roomId in rids },
        riser = pl.riser?.takeIf { it.roomId in rids },
        win = p.win.items.filter { it.roomId in rids }
    )
    // a window or door stays in the order without a room: its size as it was, in a wall as thick as the room's
    fun free(it: WinItem): WinItem {
        val t = p.rooms.firstOrNull { r -> r.id == it.roomId }?.dim("T")?.v ?: it.freeT
        return it.copy(roomId = null, opening = null, fit = false, freeT = t)
    }
    val q = p.copy(
        tiles = p.tiles.filter { it.roomId !in rids }, troom = p.troom.filter { it.roomId !in rids },
        elec = e.copy(devs = e.devs.filter { it.roomId !in rids }, rooms = e.rooms.filter { it.roomId !in rids }, panel = if (g.panel != null) null else e.panel),
        plumb = pl.copy(fixes = pl.fixes.filter { it.roomId !in rids }, points = pl.points.filter { it.roomId !in rids }, rooms = pl.rooms.filter { it.roomId !in rids },
            riser = if (g.riser != null) null else pl.riser),
        win = p.win.copy(items = p.win.items.map { if (it.roomId in rids) free(it) else it })
    )
    return q to g
}

/** What [tradesOut] took, put back (Undo): what is still there is kept; the panel and riser only where none was set since. */
fun tradesBack(p: Project, g: TradesGone): Project {
    fun <T> back(now: List<T>, gone: List<T>, id: (T) -> String): List<T> = now + gone.filter { x -> now.none { id(it) == id(x) } }
    val e = p.elec; val pl = p.plumb
    val wins = g.win.associateBy { it.id }
    return p.copy(
        tiles = back(p.tiles, g.tiles) { it.id }, troom = back(p.troom, g.troom) { it.roomId },
        elec = e.copy(devs = back(e.devs, g.edevs) { it.id }, rooms = back(e.rooms, g.erooms) { it.roomId }, panel = e.panel ?: g.panel),
        plumb = pl.copy(fixes = back(pl.fixes, g.pfixes) { it.id }, points = back(pl.points, g.ppoints) { it.id }, rooms = back(pl.rooms, g.prooms) { it.roomId },
            riser = pl.riser ?: g.riser),
        win = p.win.copy(items = p.win.items.map { wins[it.id] ?: it })
    )
}

/** An older order's trade data on rooms that are gone (deleted before deleting took it along): taken out, windows kept without a room. */
fun withoutOrphans(p: Project): Project {
    val used = p.tiles.mapNotNull { it.roomId } + p.troom.map { it.roomId } + p.elec.devs.map { it.roomId } + p.elec.rooms.map { it.roomId } +
        listOfNotNull(p.elec.panel?.roomId, p.plumb.riser?.roomId) + p.plumb.fixes.map { it.roomId } + p.plumb.points.map { it.roomId } +
        p.plumb.rooms.map { it.roomId } + p.win.items.mapNotNull { it.roomId }
    // a room typed by size ("free:<id>") is not a drawn room
    val gone = used.filter { !it.startsWith("free:") }.toSet() - p.rooms.map { it.id }.toSet()
    return if (gone.isEmpty()) p else tradesOut(p, gone).first
}
