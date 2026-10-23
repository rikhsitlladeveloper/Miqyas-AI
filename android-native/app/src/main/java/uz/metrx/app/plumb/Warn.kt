package uz.metrx.app.plumb

import uz.metrx.app.data.Project
import kotlin.math.abs

/*
 * The rules (like the electrician's el.w.* list): a drain laid too flat for its diameter, a 50 drain too long to the
 * riser, a toilet too far from it, an outlet at the wrong height for its fixture, a fixture in a door's way or off its
 * wall, no riser placed, no hot water, heating with no boiler.
 */

/** One warning: strings key [key] (sx.w.*), the room and the fixture or outlet it is about, the values in its words. */
data class PWarn(val key: String, val roomId: String?, val target: String?, val vars: Map<String, Any> = emptyMap())

private fun cm1(mm: Double) = String.format(java.util.Locale.ROOT, "%.1f", mm / 10)
private fun m1(mm: Double) = String.format(java.util.Locale.ROOT, "%.1f", mm / 1000)

/** The warnings of room [c]'s fixtures [fs] and outlets [pts]. */
fun fixWarnings(c: PCtx, fs: List<PlFix>, pts: List<APt>): List<PWarn> {
    val out = ArrayList<PWarn>()
    for (f in fs) {
        val w = c.wall(f.wall)
        if (w == null || f.off - fixW(f) / 2.0 < -1 || f.off + fixW(f) / 2.0 > w.len + 1) { out += PWarn("sx.w.out", c.id, f.id, mapOf("w" to f.wall)); continue }
        if (blocksDoor(c, f)) out += PWarn("sx.w.door", c.id, f.id)
    }
    for (q in pts) {
        val u = q.usual ?: continue
        if (abs(q.h - u) > q.tol) out += PWarn("sx.w.height", c.id, q.fix ?: q.id, mapOf("k" to "~sx.o.${q.t}", "h" to cm1(q.h.toDouble()), "u" to cm1(u.toDouble())))
    }
    return out
}

/** Every warning of the order: its rooms' fixtures, its drains, the riser, the hot water and the heating's boiler. */
fun warningsOf(p: Project, cs: List<PCtx>, rt: PRoutes): List<PWarn> {
    val out = ArrayList<PWarn>()
    val all = ArrayList<APt>()
    cs.forEach { c -> val fs = fixesIn(p, c); val pts = pointsIn(p, c, fs); all += pts; out += fixWarnings(c, fs, pts)
        // a typed room too small for what it was given
        c.free?.let { f -> freeMissing(f, fs).forEach { (t, n) -> out += PWarn("sx.w.noFit", c.id, null, mapOf("t" to "~sx.t.$t", "n" to n)) } }
    }
    val fixType = cs.flatMap { fixesIn(p, it) }.associate { it.id to it.t }
    for (d in rt.drains) {
        val who = d.pt.fix ?: d.pt.id
        if (d.horiz > 0 && d.slope + 1e-6 < minSlope(d.dia))
            out += PWarn("sx.w.slope", d.pt.roomId, who, mapOf("s" to cm1(d.slope), "m" to cm1(minSlope(d.dia).toDouble()), "d" to d.dia))
        val wc = d.pt.fix?.let { fixType[it] } == "wc"
        if (wc && d.horiz > p.plumb.wcMax) out += PWarn("sx.w.wcFar", d.pt.roomId, who, mapOf("m" to m1(d.horiz), "x" to m1(p.plumb.wcMax.toDouble())))
        else if (d.dia < 100 && d.horiz > p.plumb.drainMax) out += PWarn("sx.w.long", d.pt.roomId, who, mapOf("m" to m1(d.horiz), "x" to m1(p.plumb.drainMax.toDouble())))
    }
    // heating alone (radiators, underfloor) needs no riser: only water or a drain does
    if (rt.riser == null && all.any { it.t == "cold" || it.t == "drain" }) out += PWarn("sx.w.noRiser", null, null)
    if (rt.riser != null && rt.hot == null && all.any { it.t == "hot" }) out += PWarn("sx.w.noHot", null, null)
    if (rt.heat == null && (all.any { it.t == "hs" || it.t == "hr" } || cs.any { it.pr.ufh })) out += PWarn("sx.w.noBoiler", null, null)
    return out
}

/** The order's riser while its room is there (a riser left on a deleted room counts as none). */
fun liveRiser(p: Project): PlRiser? = p.plumb.riser?.takeIf { r -> p.rooms.any { it.id == r.roomId } }

/** Whether order [p] has water or a drain to bring (a cold or drain outlet): a heating-only order needs no riser. */
fun needsRiser(p: Project): Boolean =
    p.plumb.fixes.any { f -> fixPoints(f).any { it.t == "cold" || it.t == "drain" } } || p.plumb.points.any { it.t == "cold" || it.t == "drain" } ||
        p.plumb.free.any { it.wc + it.basin + it.bath + it.shower + it.sink + it.wm + it.dw + it.wh + it.gb > 0 }
