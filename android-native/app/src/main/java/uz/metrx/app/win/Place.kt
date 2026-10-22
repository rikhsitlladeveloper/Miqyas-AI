package uz.metrx.app.win

import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.tiles.TRoomGeo
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import uz.metrx.app.tiles.roomGeo
import kotlin.math.max

/*
 * Rooms as the windows-and-doors maker sees them: a measured room's openings with the products filling them, or a
 * product without a room shown in a made-up wall. A product stands centred in its opening, its frame in the middle of
 * the wall's thickness; seen from inside, x along it runs the same way as along the wall. From that: where its opening
 * sashes and a door's leaf sweep into the room, and what stands there (a plumber's radiator or fixture, the furniture).
 */

/** One room: a measured one, or the made-up wall of a product without a room ([free]). [T] the wall's thickness, mm. */
class WCtx(val id: String, val room: Room, val g: TRoomGeo, val T: Int, val free: WinItem? = null) {
    fun wall(id: String?) = id?.let { g.wall(it) }
    fun opening(id: String?) = room.openings.firstOrNull { it.id == id }
}

/** The made-up room of a product without a room: a wall [FREE_T] (or its own) thick with the opening it fits, a sill at 850 for a window. */
fun freeRoom(it: WinItem): Room {
    val door = it.isDoor || it.kind == "balc" || it.h >= DOOR_SASH_H
    val ow = it.w + 2 * it.gap; val oh = it.h + (if (door) it.gap else 2 * it.gap)
    val sill = if (door) 0 else 850
    val L = max(2600, ow + 1800); val H = max(2700, sill + oh + 300)
    return Room("free:${it.id}", "", it.name, dims = mapOf("A" to Dim(L), "B" to Dim(3000), "H" to Dim(H), "T" to Dim(it.freeT.coerceIn(80, 800), "default")),
        openings = listOf(Opening("fo", if (door) "door" else "window", "A", ow, oh, (L - ow) / 2, sill)), wallColor = "#ECE8E1", floorColor = "#DDE2E8")
}

/** Room [rid] of order [p] (or "free:<id>" a product without a room), null until it is measured. */
fun ctxOf(p: Project, rid: String, snap: Boolean): WCtx? {
    if (rid.startsWith("free:")) return p.win.items.firstOrNull { "free:${it.id}" == rid }?.let { freeCtx(it) }
    val r = p.rooms.firstOrNull { it.id == rid } ?: return null
    val g = roomGeo(r, snap, emptyList()) ?: return null
    return WCtx(rid, r, g, r.dim("T").v ?: 200)
}

fun freeCtx(it: WinItem): WCtx? {
    val r = freeRoom(it)
    val g = roomGeo(r, true, emptyList()) ?: return null
    return WCtx(r.id, r, g, r.dim("T").v ?: FREE_T, it)
}

/** Every measured room of the order, then each product without a room. */
fun ctxs(p: Project, snap: Boolean): List<WCtx> = p.rooms.mapNotNull { ctxOf(p, it.id, snap) } + p.win.items.filter { !it.inRoom }.mapNotNull { freeCtx(it) }

/** The products of room [c]. */
fun itemsIn(p: Project, c: WCtx): List<WinItem> = if (c.free != null) listOf(c.free) else p.win.items.filter { it.roomId == c.id }

/** A product where it stands: its opening [o] on wall [w], its left edge [a0] along the wall, its bottom [z0], the reveal [r] inside its frame. */
class Placed(val it: WinItem, val o: Opening, val w: TWall, val a0: Double, val z0: Double, val T: Int) {
    val depth get() = frameDepth(it)
    val r get() = revealOf(T, depth)
    /** The frame's inside face, mm into the room (negative: in the wall). */
    val dIn get() = -r.toDouble()
    val dOut get() = -(r + depth).toDouble()
    val doorOpening get() = o.type == "door"
}

/** Product [it] in room [c], or null when its opening is gone. */
fun placed(c: WCtx, it: WinItem): Placed? {
    val o = if (c.free != null) c.room.openings.firstOrNull() else c.opening(it.opening)
    o ?: return null
    val w = c.wall(o.wall) ?: return null
    val a0 = o.off + (o.w - it.w) / 2.0
    val z0 = o.sill + (if (o.type == "door") 0.0 else (o.h - it.h) / 2.0)
    return Placed(it, o, w, a0, z0, c.T)
}

fun placedIn(p: Project, c: WCtx): List<Placed> = itemsIn(p, c).mapNotNull { placed(c, it) }

/** A new product of type [k] filling opening [o] of room [c]: its size the opening's less [gap] each side; a window's sill and drip. */
fun fillOpening(id: String, k: WKind, c: WCtx, o: Opening, gap: Int): WinItem {
    val (w, h) = sizeFor(o.w, o.h, o.type, gap)
    val it = newItem(id, k, w, h, gap, c.id, o.id)
    if (k.isDoor) return it
    val r = revealOf(c.T, frameDepth(it))
    return if (o.type == "window" && o.sill > 0) it.copy(sill = sillFor(r), drip = true) else it.copy(drip = o.type == "window")
}

/** The openings of room [c] a type [kind] can fill. */
fun openingsFor(c: WCtx, kind: String): List<Opening> = c.room.openings.filter { fillsType(kind, it.type) }

/* ---------------- what sweeps into the room ---------------- */

/** Floor a sash or leaf sweeps into the room: [poly] on the plan, [z0]…[z1] its heights, mm; [what] the item and its sash. */
class Sweep(val item: String, val sash: Int, val poly: List<V2>, val z0: Double, val z1: Double)

/** The square a leaf [lw] wide hinged at [ah] along wall [w] sweeps into the room ([dir] +1 when it opens towards growing a), set back [r] in the wall. */
private fun sweepPoly(w: TWall, ah: Double, lw: Double, dir: Int, r: Double): List<V2>? {
    val reach = lw - r
    if (reach <= 1) return null
    val a1 = ah + dir * lw
    return listOf(w.at(minOf(ah, a1), 0.0), w.at(maxOf(ah, a1), 0.0), w.at(maxOf(ah, a1), reach), w.at(minOf(ah, a1), reach))
}

/** Where product [pl]'s turning sashes sweep into the room (a tilt only leans in, a slider slides); a door's leaf. */
fun sashSweeps(pl: Placed): List<Sweep> {
    val item = pl.it
    if (item.isDoor) return listOfNotNull(doorSweep(pl))
    return sashesOf(item).mapIndexedNotNull { i, s ->
        if (s.t !in SWINGS) return@mapIndexedNotNull null
        val left = s.cell.hinge != "R"
        val ah = pl.a0 + if (left) s.r.x0 else s.r.x1
        sweepPoly(pl.w, ah, s.r.w, if (left) 1 else -1, pl.r.toDouble())?.let { poly -> Sweep(item.id, i, poly, pl.z0 + s.r.y0, pl.z0 + s.r.y1) }
    }
}

/** Where a door's leaf sweeps into the room when it opens in (a sliding door or one opening out: nothing here). */
fun doorSweep(pl: Placed): Sweep? {
    val item = pl.it
    if (!item.isDoor || item.kind == "dsl" || item.swing != "in") return null
    val leaf = (item.w - 2 * DOOR_FRAME).toDouble()
    val left = item.hinge != "R"
    val ah = pl.a0 + if (left) DOOR_FRAME.toDouble() else (item.w - DOOR_FRAME).toDouble()
    return sweepPoly(pl.w, ah, leaf, if (left) 1 else -1, 0.0)?.let { poly -> Sweep(item.id, -1, poly, pl.z0, pl.z0 + item.h) }
}

/** An unfilled door's usual swing (hinged at its start, opening in), as the other trades draw it. */
fun openSwing(c: WCtx, o: Opening): Sweep? {
    val w = c.wall(o.wall) ?: return null
    return sweepPoly(w, o.off.toDouble(), o.w.toDouble(), 1, 0.0)?.let { poly -> Sweep("op:" + o.id, -1, poly, 0.0, o.h.toDouble()) }
}

/** Something standing in a room: [what] a strings key, its footprint, its heights; [id] the plumber's fixture or the furniture. */
class Obst(val what: String, val id: String, val poly: List<V2>, val z0: Double, val z1: Double)

/** What stands in room [c]: the plumber's fixtures (radiators first of all) and the furniture's boxes, when the order has them. */
fun obstaclesIn(p: Project, c: WCtx, snap: Boolean): List<Obst> {
    if (c.free != null) return emptyList()
    val out = ArrayList<Obst>()
    if (p.plumb.fixes.any { it.roomId == c.id }) uz.metrx.app.plumb.ctxOf(p, c.id, snap)?.let { pc ->
        p.plumb.fixes.filter { it.roomId == c.id }.forEach { f ->
            uz.metrx.app.plumb.fixPoly(pc, f)?.let { out += Obst(if (f.t == "rad" || f.t == "tr") "dw.ob.rad" else "dw.ob.fix", f.id, it, uz.metrx.app.plumb.fixZ0(f).toDouble(), uz.metrx.app.plumb.fixTop(f).toDouble()) }
        }
    }
    val fs = p.furniture.filter { it.roomId == c.id }
    if (fs.isNotEmpty()) {
        val walls = runCatching { uz.metrx.app.furniture.planWalls(c.room, snap) }.getOrNull()
        if (walls != null) fs.forEach { f ->
            runCatching { uz.metrx.app.furniture.footsOf(f, walls, uz.metrx.app.furniture.Workshop()) }.getOrDefault(emptyList()).forEach { ft ->
                out += Obst("dw.ob.furn", f.id, ft.pts.map { V2(it.x, it.y) }, ft.lo.toDouble(), ft.hi.toDouble())
            }
        }
    }
    return out
}

/** Whether convex polygons [a] and [b] overlap (touching is not overlapping). */
fun hit(a: List<V2>, b: List<V2>): Boolean {
    for (poly in listOf(a, b)) for (i in poly.indices) {
        val p = poly[i]; val q = poly[(i + 1) % poly.size]
        val n = V2(-(q.y - p.y), q.x - p.x)
        val ra = a.map { it.dot(n) }; val rb = b.map { it.dot(n) }
        if (ra.max() <= rb.min() + 1e-6 || rb.max() <= ra.min() + 1e-6) return false
    }
    return true
}
