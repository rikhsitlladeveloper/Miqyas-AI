package uz.metrx.app.elec

import uz.metrx.app.data.Project
import kotlin.math.hypot

/*
 * Safety warnings (like the furniture's fz.* list): a socket too near water or gas, a switch behind a door when it
 * opens, a socket in a bathroom's splash zone, a device on a door or window, a circuit with too many points or too much
 * load for its breaker, and no panel placed.
 */

/** One warning: strings key [key] (el.w.*), the room and device it is about, the values in its words. */
data class EWarn(val key: String, val roomId: String?, val devId: String?, val vars: Map<String, Any> = emptyMap())

/** The distance between a device and a site point in room [c], mm (along the floor and up). */
fun distTo(c: ECtx, d: ElecDev, x: uz.metrx.app.data.SitePoint): Double? {
    val q = c.planOf(x) ?: return null
    val a = c.planOf(d)
    val z = if (d.onCeiling) c.g.H else d.h.toDouble()
    return hypot(hypot(a.x - q.x, a.y - q.y), z - x.h)
}

/** The warnings of room [c]'s devices [ds]. */
fun devWarnings(c: ECtx, ds: List<ElecDev>): List<EWarn> {
    val out = ArrayList<EWarn>()
    for (d in ds) {
        val ty = devType(d.t)
        val w = c.wall(d.wall)
        if (!d.onCeiling && w == null) continue
        if (w != null && (d.off > w.len || d.h > c.g.H)) { out += EWarn("el.w.out", c.id, d.id, mapOf("w" to w.id)); continue }
        val sockish = ty.cat == "sock"
        // the water heater's own socket goes high beside the heater, made for it: not a splash-zone socket
        if (c.kind == "bath" && sockish && d.t == "pwh") Unit
        else if (c.kind == "bath" && sockish) {
            val wet = c.wet.filter { it.t in WATER }.mapNotNull { distTo(c, d, it) }.minOrNull()
            if (d.t != "sw" || (wet != null && wet < WATER_MM)) out += EWarn("el.w.splash", c.id, d.id)
        } else if (sockish) {
            val wet = c.wet.filter { it.t in WATER }.mapNotNull { distTo(c, d, it) }.minOrNull()
            if (wet != null && wet < WATER_MM) out += EWarn("el.w.water", c.id, d.id, mapOf("cm" to (wet / 10).toInt()))
        }
        if (sockish || ty.cat == "sw") {
            val gas = c.wet.filter { it.t in GAS }.mapNotNull { distTo(c, d, it) }.minOrNull()
            if (gas != null && gas < GAS_MM) out += EWarn("el.w.gas", c.id, d.id, mapOf("cm" to (gas / 10).toInt()))
        }
        if (w == null) continue
        val (dw, dh) = devSize(d)
        val doors = c.room.openings.filter { it.wall == w.id && it.type == "door" }
        if (ty.cat == "sw" && doors.any { o -> d.off > o.off - o.w && d.off < o.off && d.h < o.h }) out += EWarn("el.w.door", c.id, d.id)
        if (c.room.openings.any { o -> o.wall == w.id && d.off + dw / 2.0 > o.off && d.off - dw / 2.0 < o.off + o.w && d.h + dh / 2.0 > o.sill && d.h - dh / 2.0 < o.sill + o.h })
            out += EWarn("el.w.open", c.id, d.id)
    }
    return out
}

/** Every warning of the order: its rooms' devices, its circuits, the panel. */
fun warningsOf(p: Project, cs: List<ECtx>, circuits: List<Circuit>): List<EWarn> {
    val out = ArrayList<EWarn>()
    cs.forEach { c -> out += devWarnings(c, devsIn(p, c)) }
    circuits.forEach { cc ->
        val d = cc.def
        if (cc.group != "low" && cc.points > d.maxPts) out += EWarn("el.w.points", cc.rooms.singleOrNull(), null, mapOf("g" to cc.no, "n" to cc.points, "m" to d.maxPts))
        if (d.amps > 0 && cc.load > d.amps * 230) out += EWarn("el.w.load", cc.rooms.singleOrNull(), null,
            mapOf("g" to cc.no, "kw" to String.format(java.util.Locale.ROOT, "%.1f", cc.load / 1000.0), "a" to d.amps))
    }
    if (livePanel(p) == null && p.elec.devs.isNotEmpty()) out += EWarn("el.w.noPanel", null, null)
    return out
}

/** The order's panel while its room is there (a panel left on a deleted room counts as none). */
fun livePanel(p: Project): ElecPanel? = p.elec.panel?.takeIf { pn -> p.rooms.any { it.id == pn.roomId } }
