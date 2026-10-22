package uz.metrx.app.elec

import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * Circuits and cable routes. The devices go into groups (lighting, the rooms' sockets, the kitchen's, the bathroom's,
 * the stove, oven, air conditioners and water heaters on lines of their own, low-voltage), one breaker a group. Each
 * group's cable runs from the panel: up to the horizontal run [ZONE_DOWN] under the ceiling, along the walls the
 * shorter way to the room's doorway, through the wall over the door to the next room, along its walls, and straight
 * down to each device (chased, or in a surface channel); or in corrugated pipe over the ceiling and down to each
 * device. Lengths in mm.
 */

/** One circuit: its number on the panel, its group, its devices and the rooms they are in. */
class Circuit(val no: Int, val group: String, val devs: List<ElecDev>, val rooms: List<String>) {
    val def get() = groupDef(group)
    val amps get() = def.amps
    val cable get() = def.cable
    val rcd get() = def.rcd
    val rgb get() = def.rgb
    /** Its load, W: every device's power. */
    val load get() = devs.sumOf { watts(it) }
    /** Its points: the lights of a lighting circuit (its switches are not), else every device. */
    val points get() = if (group == "light") devs.count { devType(it.t).cat == "light" } else devs.size
}

/** A lighting circuit takes rooms while it stays under this many lights and this load (W). */
const val LIGHT_PTS = 20
const val LIGHT_W = 1800

/** The order's circuits, numbered as on the panel: lighting, sockets room by room, the kitchens, the bathrooms, the lines of their own, then low-voltage. */
fun circuitsOf(p: Project, cs: List<ECtx>): List<Circuit> {
    val per = cs.map { c -> c to devsIn(p, c) }
    val out = ArrayList<Circuit>()
    fun add(g: String, ds: List<ElecDev>) { if (ds.isNotEmpty()) out += Circuit(out.size + 1, g, ds, ds.map { it.roomId }.distinct()) }
    // lighting: room after room into one circuit while it stays small enough
    var cur = ArrayList<ElecDev>()
    per.forEach { (c, ds) ->
        val mine = ds.filter { groupOf(it, c.kind) == "light" }
        if (mine.isEmpty()) return@forEach
        val pts = mine.count { devType(it.t).cat == "light" }; val w = mine.sumOf { watts(it) }
        val cp = cur.count { devType(it.t).cat == "light" }; val cw = cur.sumOf { watts(it) }
        if (cur.isNotEmpty() && (cp + pts > LIGHT_PTS || cw + w > LIGHT_W)) { add("light", cur); cur = ArrayList() }
        cur.addAll(mine)
    }
    add("light", cur)
    for (g in listOf("sock", "kitch", "bath")) per.forEach { (c, ds) -> add(g, ds.filter { groupOf(it, c.kind) == g }) }
    for (g in listOf("stove", "oven", "ac", "wh", "own")) per.forEach { (c, ds) -> ds.filter { groupOf(it, c.kind) == g }.forEach { add(g, listOf(it)) } }
    add("low", per.flatMap { (c, ds) -> ds.filter { groupOf(it, c.kind) == "low" } })
    return out
}

/* ---------------- the walls as one loop ---------------- */

/** A room's walls end to end: a point on them as one length round the room from wall 1's start corner. */
class Perim(val c: ECtx) {
    private val ws = c.g.walls
    private val st = DoubleArray(ws.size).also { a -> var s = 0.0; ws.forEachIndexed { i, w -> a[i] = s; s += w.len } }
    val P = ws.sumOf { it.len }
    fun s(wall: String, a: Double): Double { val i = ws.indexOfFirst { it.id == wall }.coerceAtLeast(0); return st[i] + a.coerceIn(0.0, ws[i].len) }
    private fun idx(s: Double): Int { var i = ws.size - 1; while (i > 0 && st[i] > s) i--; return i }
    /** The pieces (wall, from, to along it) of the way [d] mm on from [s0], clockwise. */
    fun pieces(s0: Double, d: Double): List<Triple<TWall, Double, Double>> {
        val out = ArrayList<Triple<TWall, Double, Double>>()
        var s = ((s0 % P) + P) % P; var left = d
        var guard = 0
        while (left > 1e-6 && guard++ < 4 * ws.size + 4) {
            val i = idx(s); val w = ws[i]; val a = s - st[i]
            val step = min(left, w.len - a)
            if (step > 1e-6) out += Triple(w, a, a + step)
            left -= step; s = (st[i] + w.len) % P
            if (step <= 1e-6 && w.len - a <= 1e-6) s = st[(i + 1) % ws.size]
        }
        return out
    }
}

/**
 * The shortest way round the walls from [e] that reaches every point [ts] (lengths round the room): clockwise as far
 * as [cw] and back the other way as far as [ccw]. It never goes round twice.
 */
fun cover(P: Double, e: Double, ts: List<Double>): Pair<Double, Double> {
    if (ts.isEmpty() || P <= 0) return 0.0 to 0.0
    val r = ts.map { ((it - e) % P + P) % P }.sorted()
    var best = r.last() to 0.0
    if (P - r.first() < best.first + best.second) best = 0.0 to (P - r.first())
    for (j in 0 until r.size - 1) {
        val c = r[j] + (P - r[j + 1])
        if (c < best.first + best.second) best = r[j] to (P - r[j + 1])
    }
    return best
}

/** A piece of a cable's route: from [a] at [za] to [b] at [zb] (plan mm, mm up), on wall [wall] or over the ceiling (null). */
class Seg(val a: V2, val za: Double, val b: V2, val zb: Double, val wall: String?) {
    val len get() = hypot(hypot(b.x - a.x, b.y - a.y), zb - za)
}

/**
 * A circuit's route in one room: its pieces to draw, its cable length [len] there (with the ends and, for a room away
 * from the panel, the cable between the doors), and for counting the stretches of wall it runs along ([runs],
 * lengths round the room), the drops down to each device ([drops], by device), its run over the ceiling ([ceil]).
 */
class CRun(val circuit: Circuit, val roomId: String, val segs: List<Seg>, val len: Double, val runs: List<Pair<Double, Double>>, val drops: Map<String, Double>, val ceil: Double, val rise: Double)

/** All the order's routes: by circuit, the cable each takes ([cableOf]), and whether they reach the panel. */
class Routes(val circuits: List<Circuit>, val runs: List<CRun>, val panel: ElecPanel?, val method: String) {
    fun cableOf(c: Circuit) = runs.filter { it.circuit.no == c.no }.sumOf { it.len } + TAIL
    fun inRoom(rid: String) = runs.filter { it.roomId == rid }
}

private fun dist(a: V2, b: V2) = hypot(a.x - b.x, a.y - b.y)

/** The door of the panel's room a room's cable leaves by: the one set, else that room's last door other than the entrance. */
fun exitDoor(pc: ECtx, pn: ElecPanel, er: ElecRoom): Opening? {
    val ds = pc.doors
    ds.firstOrNull { it.id == er.pdoor }?.let { return it }
    return ds.filter { it.id != pn.entry }.lastOrNull() ?: ds.lastOrNull()
}

/** The order's routes with its panel and cable method. */
fun routesOf(p: Project, cs: List<ECtx>, circuits: List<Circuit> = circuitsOf(p, cs)): Routes {
    val pn = p.elec.panel?.takeIf { pn -> cs.any { it.id == pn.roomId } }
    val method = p.elec.method
    val byId = cs.associateBy { it.id }
    val runs = ArrayList<CRun>()
    circuits.forEach { cc ->
        val inPanel = pn?.roomId
        val away = cc.rooms.filter { it != inPanel }
        // the panel's room: its own devices, and the doors the other rooms' cables leave by
        val rooms = if (pn != null && away.isNotEmpty() && inPanel !in cc.rooms) cc.rooms + inPanel!! else cc.rooms
        rooms.forEach { rid ->
            val c = byId[rid] ?: return@forEach
            val k = runs.count { it.roomId == rid }
            val exits = if (pn != null && rid == pn.roomId) away.mapNotNull { a -> byId[a]?.let { exitDoor(c, pn, it.er) } }.distinctBy { it.id } else emptyList()
            runs += roomRun(c, cc, cc.devs.filter { it.roomId == rid }, if (pn != null && rid == pn.roomId) pn else null, exits, method, k,
                // a room typed by size is away from the panel even when no panel is placed yet
                if (pn != null && rid != pn.roomId) (c.free?.link ?: c.er.link).toDouble() else if (pn == null && c.free != null) c.free.link.toDouble() else 0.0)
        }
    }
    return Routes(circuits, runs, pn, method)
}

/**
 * Circuit [cc]'s route in room [c] to its devices [ds]: from the panel [pn] when it is in this room (and on to the
 * doors [exits] other rooms' cables leave by), else from the room's door, plus [link] for the cable between the doors.
 * [k] stacks it beside the circuits already drawn in the room.
 */
fun roomRun(c: ECtx, cc: Circuit, ds: List<ElecDev>, pn: ElecPanel?, exits: List<Opening>, method: String, k: Int, link: Double): CRun {
    val H = c.g.H
    val per = Perim(c)
    val segs = ArrayList<Seg>()
    val drops = LinkedHashMap<String, Double>()
    val walls = ds.filter { !it.onCeiling }
    val lights = ds.filter { it.onCeiling }
    // where it starts: the panel's top, or the door it came in by (over the door)
    val (pw, ph) = panelSize(0)
    val startWall: TWall?; val startA: Double; var rise = 0.0
    if (pn != null) { startWall = c.wall(pn.wall); startA = pn.off.toDouble() }
    else { val e = c.entry; startWall = e?.let { c.wall(it.wall) } ?: c.g.walls.first(); startA = e?.let { it.off + it.w / 2.0 } ?: 0.0 }
    val sw = startWall ?: c.g.walls.first()
    val panelTop = pn?.let { it.h + ph / 2.0 } ?: 0.0
    var tails = TAIL.toDouble() * ds.size
    fun inw(w: TWall, a: Double) = w.at(a, 12.0)
    if (method == "gofra") {
        val z = H - 15 - 15.0 * k
        val start = inw(sw, startA)
        if (pn != null) { rise = H - panelTop; segs += Seg(start, panelTop, start, z, sw.id) }
        // over the ceiling from point to point, nearest first; each wall device straight down from above it
        val pts = ArrayList<Pair<V2, ElecDev?>>()
        walls.forEach { d -> c.wall(d.wall)?.let { w -> pts += inw(w, d.off.toDouble()) to d } }
        lights.forEach { d -> pts += V2(d.cx.toDouble(), d.cy.toDouble()) to d }
        exits.forEach { o -> c.wall(o.wall)?.let { w -> pts += inw(w, o.off + o.w / 2.0) to null } }
        var cur = start; var ceil = 0.0
        val left = pts.toMutableList()
        while (left.isNotEmpty()) {
            val n = left.minBy { dist(cur, it.first) }; left.remove(n)
            ceil += dist(cur, n.first); segs += Seg(cur, z, n.first, z, null); cur = n.first
            val d = n.second
            if (d != null && !d.onCeiling) {
                val (_, dh) = devSize(d)
                val edge = d.h + dh / 2.0
                val drop = max(0.0, H - edge); drops[d.id] = drop
                segs += Seg(n.first, z, n.first, edge, d.wall)
            }
        }
        val len = rise + ceil + drops.values.sum() + tails + link
        return CRun(cc, c.id, segs, len, emptyList(), drops, ceil, rise)
    }
    // chased or in a channel: up to the run under the ceiling, round the walls, down to each device
    val zone = H - ZONE_DOWN
    val z = zone - 25.0 * k
    if (pn != null) { rise = abs(zone - panelTop); segs += Seg(inw(sw, startA), panelTop, inw(sw, startA), z, sw.id) }
    val e = per.s(sw.id, startA)
    val ts = ArrayList<Double>()
    walls.forEach { d -> ts += per.s(d.wall!!, d.off.toDouble()) }
    exits.forEach { o -> ts += per.s(o.wall, o.off + o.w / 2.0) }
    // the lights: the cable goes up from the wall nearest to them and on over the ceiling from light to light
    var ceil = 0.0
    if (lights.isNotEmpty()) {
        val first = lights.minBy { nearestWall(c, V2(it.cx.toDouble(), it.cy.toDouble())).third }
        val (lw, la, ld) = nearestWall(c, V2(first.cx.toDouble(), first.cy.toDouble()))
        ts += per.s(lw.id, la)
        val cz = H - 12 - 12.0 * k
        val att = inw(lw, la)
        segs += Seg(att, z, att, cz, lw.id)
        ceil += (H - zone) + ld
        var cur = V2(first.cx.toDouble(), first.cy.toDouble())
        segs += Seg(att, cz, cur, cz, null)
        val left = lights.filter { it.id != first.id }.toMutableList()
        while (left.isNotEmpty()) {
            val n = left.minBy { dist(cur, V2(it.cx.toDouble(), it.cy.toDouble())) }; left.remove(n)
            val q = V2(n.cx.toDouble(), n.cy.toDouble())
            ceil += dist(cur, q); segs += Seg(cur, cz, q, cz, null); cur = q
        }
    }
    val (cw, ccw) = cover(per.P, e, ts)
    val runs = ArrayList<Pair<Double, Double>>()
    if (cw > 0) { runs += e to e + cw; per.pieces(e, cw).forEach { (w, a0, a1) -> segs += Seg(inw(w, a0), z, inw(w, a1), z, w.id) } }
    if (ccw > 0) { runs += e - ccw to e; per.pieces(e - ccw, ccw).forEach { (w, a0, a1) -> segs += Seg(inw(w, a0), z, inw(w, a1), z, w.id) } }
    walls.forEach { d ->
        val w = c.wall(d.wall) ?: return@forEach
        val (_, dh) = devSize(d)
        // a device under the run is reached from above, one over it (an LED strip at the ceiling) from below
        val edge = if (d.h + dh / 2.0 <= zone) d.h + dh / 2.0 else d.h - dh / 2.0
        drops[d.id] = abs(zone - edge)
        segs += Seg(inw(w, d.off.toDouble()), z, inw(w, d.off.toDouble()), edge, w.id)
    }
    if (ds.isEmpty() && exits.isEmpty()) tails = 0.0
    val len = rise + cw + ccw + drops.values.sum() + ceil + tails + link
    return CRun(cc, c.id, segs, len, runs, drops, ceil, rise)
}
