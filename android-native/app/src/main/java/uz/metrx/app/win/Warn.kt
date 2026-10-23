package uz.metrx.app.win

import uz.metrx.app.data.Project

/*
 * The rules (like the plumber's sx.w.* list): a sash too narrow, wide, high, big or heavy for the way it opens; a
 * turning sash or a door's leaf sweeping into a radiator, a fixture or the furniture, or into another door's swing; a
 * product bigger than its opening; a sill sticking out of the reveal; a product whose opening was taken away.
 */

/** One warning: strings key [key] (dw.w.*), the room and product it is about, the values in its words ("~key" a strings key). */
data class WWarn(val key: String, val roomId: String?, val target: String?, val vars: Map<String, Any> = emptyMap())

/** How big a sash that opens may be: its width, height, area (m²) and weight (kg). */
class SashLim(val minW: Int, val maxW: Int, val maxH: Int, val maxArea: Double, val maxKg: Double)

/**
 * The limits of a sash that opens [t] in [profile]; a door's sash ([door], one at least [DOOR_SASH_H] high) has its own:
 * turning 900 × 1600 (a door's 1000 × 2400), tilt-and-turn the same and at most 1,3 m² (a door's 2,4), a tilting
 * fanlight 1600 × 1000 and 40 kg, a sliding sash 1500 wide in PVC and 2000 in aluminium, 2400 high.
 */
fun limOf(t: String, profile: String, door: Boolean): SashLim? = when (t) {
    "turn" -> if (door) SashLim(400, 1000, 2400, 2.4, 90.0) else SashLim(350, 900, 1600, 1.6, 60.0)
    "tt" -> if (door) SashLim(400, 1000, 2400, 2.4, 100.0) else SashLim(350, 900, 1600, 1.3, 70.0)
    "tilt" -> SashLim(350, 1600, 1000, 1.6, 40.0)
    "slide" -> SashLim(400, if (profile == "alu") 2000 else 1500, 2400, 3.6, if (profile == "alu") 150.0 else 100.0)
    else -> null
}

private fun cm(mm: Double) = Math.round(mm / 10).toString()
private fun d2(v: Double) = String.format(java.util.Locale.ROOT, "%.2f", v)
private fun d0(v: Double) = Math.round(v).toString()

/** The warnings of product [it]'s sashes (in room [roomId]). */
fun sashWarnings(it: WinItem, roomId: String?): List<WWarn> {
    if (it.isDoor) return emptyList()
    val out = ArrayList<WWarn>()
    sashesOf(it).forEachIndexed { i, s ->
        val lim = limOf(s.t, it.profile, s.r.h >= DOOR_SASH_H) ?: return@forEachIndexed
        val v = mapOf("n" to i + 1, "k" to "~dw.t.${s.t}")
        when {
            s.r.w < lim.minW -> out += WWarn("dw.w.narrow", roomId, it.id, v + mapOf("v" to cm(s.r.w), "x" to cm(lim.minW.toDouble())))
            s.r.w > lim.maxW -> out += WWarn("dw.w.wide", roomId, it.id, v + mapOf("v" to cm(s.r.w), "x" to cm(lim.maxW.toDouble())))
        }
        if (s.r.h > lim.maxH) out += WWarn("dw.w.high", roomId, it.id, v + mapOf("v" to cm(s.r.h), "x" to cm(lim.maxH.toDouble())))
        else if (s.r.w <= lim.maxW && s.r.area > lim.maxArea) out += WWarn("dw.w.area", roomId, it.id, v + mapOf("v" to d2(s.r.area), "x" to d2(lim.maxArea)))
        val kg = sashKg(it, s)
        if (kg > lim.maxKg) out += WWarn("dw.w.heavy", roomId, it.id, v + mapOf("v" to d0(kg), "x" to d0(lim.maxKg)))
    }
    return out
}

/** The warnings of placed product [pl] in room [c] with what stands there [obs] and the other doors' swings [doors]. */
fun placedWarnings(c: WCtx, pl: Placed, obs: List<Obst>, doors: List<Sweep>): List<WWarn> {
    val it = pl.it; val o = pl.o
    val out = ArrayList<WWarn>()
    // the opening was made a door (or a window) after the product went in: it is the wrong kind for it now
    if (!fillsType(it.kind, o.type)) out += WWarn("dw.w.type", c.id, it.id, mapOf("k" to "~dw.k.${it.kind}", "o" to "~" + (if (o.type == "door") "op.door" else "op.window")))
    if (it.w > o.w || it.h > o.h) out += WWarn("dw.w.big", c.id, it.id, mapOf("w" to cm(it.w.toDouble()), "h" to cm(it.h.toDouble()), "a" to cm(o.w.toDouble()), "b" to cm(o.h.toDouble())))
    if (!it.isDoor && it.sill > 0 && it.sill > pl.r + SILL_OVER_MAX)
        out += WWarn("dw.w.sill", c.id, it.id, mapOf("s" to cm(it.sill.toDouble()), "r" to cm(pl.r.toDouble()), "m" to cm((it.sill - pl.r).toDouble())))
    out += sashWarnings(it, c.id)
    for (sw in sashSweeps(pl)) {
        val door = it.isDoor
        obs.firstOrNull { ob -> ob.z1 > sw.z0 + 1 && ob.z0 < sw.z1 - 1 && hit(sw.poly, ob.poly) }?.let { ob ->
            out += WWarn(if (door) "dw.w.swing" else "dw.w.blocked", c.id, it.id, mapOf("o" to "~" + ob.what, "n" to sw.sash + 1))
        }
        if (door) doors.firstOrNull { d -> d.item != it.id && hit(sw.poly, d.poly) }?.let { _ -> out += WWarn("dw.w.doors", c.id, it.id) }
    }
    return out
}

/** Every warning of the order: each room's products, and the products without a room. */
fun warningsOf(p: Project, cs: List<WCtx>, snap: Boolean): List<WWarn> {
    val out = ArrayList<WWarn>()
    for (c in cs) {
        val items = itemsIn(p, c)
        val pls = items.mapNotNull { placed(c, it) }
        items.filter { i -> pls.none { it.it.id == i.id } }.forEach { out += WWarn("dw.w.gone", c.id, it.id) }
        val obs = obstaclesIn(p, c, snap)
        // the doors' swings: the products', and the doors not filled yet as they usually open
        val filled = pls.map { it.o.id }.toSet()
        val doors = pls.mapNotNull { doorSweep(it) } + c.room.openings.filter { it.type == "door" && it.id !in filled }.mapNotNull { openSwing(c, it) }
        pls.forEach { out += placedWarnings(c, it, obs, doors) }
    }
    // products whose room is gone or not measured: the sashes still have their rules
    val seen = cs.map { it.id }.toSet()
    p.win.items.filter { it.inRoom && it.roomId !in seen }.forEach { out += sashWarnings(it, it.roomId) }
    return out
}
