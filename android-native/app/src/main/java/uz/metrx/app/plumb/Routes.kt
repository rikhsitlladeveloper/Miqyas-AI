package uz.metrx.app.plumb

import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.elec.Perim
import uz.metrx.app.elec.cover
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * The routes. Cold water comes from the riser, hot from the water heater or gas boiler (else the riser), the heating's
 * supply and return from the gas boiler. Each kind runs along the walls at its height (or in the floor), the shorter way
 * round, dipping into the floor under the doorways, to the room's door, through it to the next room and round its walls,
 * and up or down to each outlet; one trunk a kind a room, each outlet a branch. Each drain runs on its own from its outlet
 * down to the floor and along the walls back to the riser, falling at the slope its outlet's height allows. Underfloor
 * heating is worked out as loops of [LOOP_MAX] at most. Lengths in mm.
 */

/** A piece of a route: from [a] at [za] to [b] at [zb] (plan mm, mm up), on wall [wall] or in the floor (null). */
class PSeg(val a: V2, val za: Double, val b: V2, val zb: Double, val wall: String?) {
    val len get() = hypot(hypot(b.x - a.x, b.y - a.y), zb - za)
}

/**
 * A kind's route in one room: its pieces to draw, its pipe there [len] (the trunk with the pipe between the doors and at
 * the riser, the branches [drops]), what is chased into the walls ([chase]), the corners and doorway dips it turns
 * (elbows), the trunk's diameter [dia]; a drain's: the stretches round the room it lies along ([stretches]) and its outlet ([target]).
 */
class PRun(val kind: String, val roomId: String, val segs: List<PSeg>, val len: Double, val trunk: Double, val drops: Double, val chase: Double,
           val corners: Int, val dips: Int, val dia: Int, val branches: Int, val stretches: List<Pair<Double, Double>> = emptyList(), val target: String? = null)

/** A drain from outlet [pt]: its pieces room by room, how far it runs to the riser ([horiz]), its [slope] (mm a metre) and diameter. */
class PDrain(val pt: APt, val runs: List<PRun>, val horiz: Double, val slope: Double, val dia: Int, val vertical: Double, val between: Double = 0.0)

/** An underfloor heating's loops in a room: its heated floor (m²), the spacing, the pipe to and from the manifold, the whole pipe, how many loops. */
class PLoop(val roomId: String, val area: Double, val step: Int, val lead: Double, val total: Double, val n: Int) {
    val each get() = if (n > 0) total / n else 0.0
}

/** Where a kind's pipe starts: the riser, or a heater's or boiler's outlet ([h] its height, [fix] the fixture). */
class Src(val roomId: String, val wall: String, val off: Int, val h: Int?, val fix: String?)

/** All the order's routes. */
class PRoutes(val runs: List<PRun>, val drains: List<PDrain>, val riser: PlRiser?, val hot: Src?, val heat: Src?, val loops: List<PLoop>) {
    fun inRoom(rid: String) = runs.filter { it.roomId == rid }
    fun lenOf(kind: String) = runs.filter { it.kind == kind }.sumOf { it.len }
}

/** The trunk's diameter for [n] outlets of a kind: 20 for a few, 25, 32 for many. */
fun trunkDia(n: Int) = when { n <= 4 -> 20; n <= 12 -> 25; else -> 32 }

/** Water's and heating's height along the walls (or in the floor), mm. */
fun runZ(kind: String, run: String): Double = when {
    run == "floor" -> FLOOR_Z.toDouble()
    kind == "cold" -> WATER_Z.toDouble()
    kind == "hot" -> (WATER_Z + KIND_DZ).toDouble()
    kind == "hs" -> HEAT_Z.toDouble()
    else -> (HEAT_Z + 50).toDouble()
}

/** How far off the wall a kind's pipe lies: along the walls just off them; in the floor side by side. */
fun inset(kind: String, run: String): Double = if (kind == "drain") 60.0 else if (run != "floor") 14.0 else when (kind) { "cold" -> 40.0; "hot" -> 80.0; "hs" -> 120.0; else -> 160.0 }

/** The door of room [sc] a pipe to room [away] leaves by: the one set for it, else the room's last door. */
fun exitDoor(sc: PCtx, away: PCtx): Opening? = sc.ways.firstOrNull { it.id == away.pr.pdoor } ?: sc.ways.lastOrNull()

/** The way round the walls from [from] to [to] (lengths round the room), clockwise or not, as pieces in the order walked. */
fun walk(per: Perim, from: Double, to: Double, cw: Boolean): List<Triple<TWall, Double, Double>> {
    val P = per.P
    if (P <= 0) return emptyList()
    return if (cw) per.pieces(from, ((to - from) % P + P) % P)
    else per.pieces(to, ((from - to) % P + P) % P).reversed().map { (w, a0, a1) -> Triple(w, a1, a0) }
}

/** The shorter way round from [from] to [to]: clockwise?, how far. */
fun shorter(P: Double, from: Double, to: Double): Pair<Boolean, Double> {
    val d = ((to - from) % P + P) % P
    return if (d <= P - d) true to d else false to (P - d)
}

/* ---------------- water and heating ---------------- */

/** Builds a route's pieces from stations: a station at the same spot and another height is a riser or drop. */
private class Path {
    val segs = ArrayList<PSeg>()
    private var last: Triple<V2, Double, String?>? = null
    fun to(p: V2, z: Double, wall: String?) {
        val l = last
        if (l != null && (hypot(l.first.x - p.x, l.first.y - p.y) > .5 || abs(l.second - z) > .5)) segs += PSeg(l.first, l.second, p, z, wall ?: l.third)
        last = Triple(p, z, wall)
    }
    fun jump(p: V2, z: Double, wall: String?) { last = Triple(p, z, wall) }
}

/**
 * The run along walk [pieces] at height [z], [ins] off the wall, from height [z0]: under the doorways it dips into the
 * floor when [dip] (it runs along the walls). Adds the pieces to [path]; returns the length (with the ups and downs),
 * the length on the wall (chased), the dips under doors.
 */
private fun along(c: PCtx, pieces: List<Triple<TWall, Double, Double>>, z: Double, z0: Double, ins: Double, path: Path, dip: Boolean): Triple<Double, Double, Int> {
    var len = 0.0; var onWall = 0.0; var dips = 0
    var cur = z0
    for ((w, from, to) in pieces) {
        val lo = min(from, to); val hi = max(from, to)
        val cuts = if (!dip) emptyList() else c.room.openings.filter { it.wall == w.id && it.type == "door" }
            .map { (it.off - 60.0) to (it.off + it.w + 60.0) }.filter { it.second > lo && it.first < hi }
        val br = (listOf(lo, hi) + cuts.flatMap { listOf(it.first, it.second) }.filter { it > lo && it < hi }).distinct().sorted().let { if (from > to) it.reversed() else it }
        for (i in 0 until br.size - 1) {
            val a = br[i]; val b = br[i + 1]; val m = (a + b) / 2
            val low = cuts.any { m > it.first && m < it.second }
            val zz = if (low) FLOOR_Z.toDouble() else z
            if (abs(zz - cur) > .5) { len += abs(zz - cur); if (zz < cur) dips++ }
            path.to(w.at(a, ins), zz, w.id); path.to(w.at(b, ins), zz, w.id)
            len += abs(b - a)
            if (!low) onWall += abs(b - a)
            cur = zz
        }
    }
    return Triple(len, onWall, dips)
}

/**
 * Kind [kind]'s route in room [c] to its outlets [ts]: from [src] when it is in this room (on to the doors [exits] other
 * rooms' pipe leaves by), else from the room's door, plus [link] for the pipe between the doors. [run] along the walls
 * or in the floor; [dia] the trunk's diameter.
 */
fun supplyRun(c: PCtx, kind: String, ts: List<APt>, src: Src?, exits: List<Opening>, run: String, link: Double, dia: Int): PRun {
    val per = Perim(c.g.walls, c.g.inner)
    val z = runZ(kind, run); val ins = inset(kind, run)
    val path = Path()
    var trunk = 0.0; var chase = 0.0; var corners = 0; var dips = 0
    val sw: TWall; val sa: Double; val z0: Double
    if (src != null && src.roomId == c.id) {
        sw = c.wall(src.wall) ?: c.g.walls.first(); sa = src.off.toDouble()
        val p0 = sw.at(sa, ins)
        if (src.h != null) {
            // down (or up) from the heater's outlet to the run
            path.jump(p0, src.h.toDouble(), sw.id); path.to(p0, z, sw.id)
            trunk += abs(src.h - z); chase += abs(src.h - z)
        } else { path.jump(p0, z, sw.id); trunk += RISER_TAIL }
        z0 = z
    } else {
        val e = c.entry
        sw = e?.let { c.wall(it.wall) } ?: c.g.walls.first(); sa = e?.let { it.off + it.w / 2.0 } ?: 0.0
        // through the doorway in the floor
        z0 = if (e != null && run != "floor") FLOOR_Z.toDouble() else z
        path.jump(sw.at(sa, ins), z0, sw.id)
        trunk += link
    }
    val e = per.s(sw.id, sa)
    val targets = ts.map { per.s(it.wall, it.off.toDouble()) } + exits.map { per.s(it.wall, it.off + it.w / 2.0) }
    val (cw, ccw) = cover(per.P, e, targets)
    val dip = run != "floor"
    if (cw > 0) {
        val pcs = per.pieces(e, cw); corners += max(0, pcs.size - 1)
        val (l, ch, d) = along(c, pcs, z, z0, ins, path, dip); trunk += l; chase += ch; dips += d
    }
    if (ccw > 0) {
        path.jump(sw.at(sa, ins), z0, sw.id)
        val pcs = walk(per, e, e - ccw, false); corners += max(0, pcs.size - 1)
        val (l, ch, d) = along(c, pcs, z, z0, ins, path, dip); trunk += l; chase += ch; dips += d
    }
    // each outlet: straight up or down the wall from the run; one on an inner partition first across to it and along it
    var drops = 0.0
    ts.forEach { t ->
        val w = c.wall(t.wall) ?: return@forEach
        val q = w.at(t.off.toDouble(), ins)
        per.spur(w.id, t.off.toDouble())?.let { sp -> path.jump(sp.at, z, null); path.to(sp.end, z, null); path.to(q, z, w.id); drops += sp.len }
        path.jump(q, z, w.id); path.to(q, t.h.toDouble(), w.id)
        drops += abs(t.h - z)
    }
    chase += drops
    if (run == "floor") chase = drops
    return PRun(kind, c.id, path.segs, trunk + drops, trunk, drops, chase, corners, dips, dia, ts.size)
}

/** Where a kind's pipe starts in order [p]: cold at the riser, hot at the heater (else the riser if it brings hot), heating at the boiler. */
fun sourceOf(p: Project, kind: String, fixes: List<PlFix>): Src? {
    val rs = p.plumb.riser
    fun ofFix(f: PlFix, k: String) = fixPoints(f).firstOrNull { it.t == k }?.let { Src(f.roomId, f.wall, it.off, it.h, f.id) }
    return when (kind) {
        "cold" -> rs?.let { Src(it.roomId, it.wall, it.off, null, null) }
        "hot" -> (fixes.firstOrNull { it.t == "gb" } ?: fixes.firstOrNull { it.t == "wh" })?.let { ofFix(it, "hot") }
            ?: rs?.takeIf { it.hot }?.let { Src(it.roomId, it.wall, it.off, null, null) }
        else -> fixes.firstOrNull { it.t == "gb" }?.let { ofFix(it, kind) }
    }
}

/* ---------------- drains ---------------- */

/** The slope a drain of [dia] is laid at, and the least the rules allow, mm a metre. */
fun slopeFor(dia: Int) = if (dia >= 100) SLOPE_110 else SLOPE_50
fun minSlope(dia: Int) = if (dia >= 100) MIN_110 else MIN_50

/**
 * The drain from outlet [pt] in room [c]: down to the floor, along the walls the shorter way to the riser ([rc] its room)
 * or to the room's door, the pipe between the doors ([link]) and on in the riser's room from its door. It starts as high
 * as the slope needs (no higher than the outlet) and falls to [DRAIN_IN] at the riser.
 */
fun drainOf(pt: APt, c: PCtx, rc: PCtx?, rs: PlRiser?, link: Double): PDrain {
    val dia = drainD(pt.d)
    val ins = inset("drain", "")
    val per = Perim(c.g.walls, c.g.inner)
    val sp = per.s(pt.wall, pt.off.toDouble())
    // an outlet on an inner partition: along it and across to the outer wall first, on the floor
    val spur = per.spur(pt.wall, pt.off.toDouble())
    // the legs: in this room to the riser or the door; then (after the pipe between the doors) in the riser's room
    class Leg(val ctx: PCtx, val per: Perim, val pieces: List<Triple<TWall, Double, Double>>, val len: Double, val pre: Double)
    val legs = ArrayList<Leg>()
    var between = 0.0
    if (rs != null && rc != null && rs.roomId == c.id) {
        val tp = per.s(rs.wall, rs.off.toDouble()); val (cw, d) = shorter(per.P, sp, tp)
        legs += Leg(c, per, walk(per, sp, tp, cw), d, 0.0)
    } else {
        c.entry?.let { e -> val te = per.s(e.wall, e.off + e.w / 2.0); val (cw, d) = shorter(per.P, sp, te); legs += Leg(c, per, walk(per, sp, te, cw), d, 0.0) }
        between = link
        if (rs != null && rc != null) exitDoor(rc, c)?.let { x ->
            val rp = Perim(rc.g.walls)
            val a = rp.s(x.wall, x.off + x.w / 2.0); val b = rp.s(rs.wall, rs.off.toDouble())
            val (cw, d) = shorter(rp.P, a, b); legs += Leg(rc, rp, walk(rp, a, b, cw), d, between)
        }
    }
    val horiz = legs.sumOf { it.len } + between + (spur?.len ?: 0.0)
    val want = slopeFor(dia)
    val z0 = if (horiz <= 0) pt.h.toDouble() else max(min(pt.h.toDouble(), DRAIN_IN.toDouble()), min(pt.h.toDouble(), DRAIN_IN + want * horiz / 1000))
    val slope = if (horiz <= 0) want.toDouble() else max(0.0, (z0 - DRAIN_IN) / horiz * 1000)
    val vertical = max(0.0, pt.h - z0)
    val runs = ArrayList<PRun>()
    var s = spur?.len ?: 0.0
    legs.forEachIndexed { i, leg ->
        s += leg.pre
        val path = Path()
        val st = ArrayList<Pair<Double, Double>>()
        val withDrop = i == 0 && leg.ctx.id == c.id
        if (withDrop) c.wall(pt.wall)?.let { w -> val q = w.at(pt.off.toDouble(), ins); path.jump(q, pt.h.toDouble(), w.id); path.to(q, z0, w.id)
            spur?.let { sp -> path.to(sp.end, z0 - slope * abs(pt.off - (sp.end - w.p0).dot(w.t)) / 1000, null); path.to(sp.at, z0 - slope * sp.len / 1000, null) } }
        else leg.pieces.firstOrNull()?.let { (w, a, _) -> path.jump(w.at(a, ins), z0 - slope * s / 1000, w.id) }
        leg.pieces.forEach { (w, a, b) ->
            val za = z0 - slope * s / 1000; val zb = z0 - slope * (s + abs(b - a)) / 1000
            path.to(w.at(a, ins), za, w.id); path.to(w.at(b, ins), zb, w.id)
            val s0 = leg.per.s(w.id, min(a, b)); st += s0 to s0 + abs(b - a)
            s += abs(b - a)
        }
        val v = if (withDrop) vertical + (spur?.len ?: 0.0) else 0.0
        runs += PRun("drain", leg.ctx.id, path.segs, leg.len + v, leg.len, v, 0.0, max(0, leg.pieces.size - 1), 0, dia, 1, st, pt.id)
    }
    if (legs.none { it.ctx.id == c.id } && vertical > 0) c.wall(pt.wall)?.let { w ->
        val q = w.at(pt.off.toDouble(), ins)
        runs += PRun("drain", c.id, listOf(PSeg(q, pt.h.toDouble(), q, z0, w.id)), vertical, 0.0, vertical, 0.0, 0, 0, dia, 1, emptyList(), pt.id)
    }
    return PDrain(pt, runs, horiz, slope, dia, vertical, between)
}

/* ---------------- underfloor heating ---------------- */

/** The floor heated in room [c]: its area less what stands on it (bath, tray, toilet, cabinets, machines), m². */
fun heatedArea(c: PCtx, fs: List<PlFix>): Double {
    val taken = fs.filter { fixZ0(it) == 0 && fixType(it.t).cat != "heat" }.sumOf { fixW(it).toDouble() * fixD(it) } / 1e6
    return max(0.0, c.areaM2 - taken)
}

/**
 * Room [c]'s underfloor loops at [c]'s spacing: the pipe over its heated floor, the pipe to and from the manifold
 * ([mf] its room and outlet; in another room: along its walls to the door and the pipe between the doors), split
 * into loops of [LOOP_MAX] at most.
 */
fun loopOf(c: PCtx, fs: List<PlFix>, mc: PCtx?, mf: APt?): PLoop {
    val step = c.pr.step.coerceIn(50, 400)
    val a = heatedArea(c, fs)
    val field = a * 1e6 / step
    val lead = when {
        mc == null || mf == null -> 2.0 * (c.free?.link ?: c.pr.link)
        mc.id == c.id -> { val q = planOf(c, mf.wall, mf.off) ?: centre(c); val m = centre(c); 2 * (hypot(q.x - m.x, q.y - m.y) + mf.h) }
        else -> {
            val x = exitDoor(mc, c)
            val per = Perim(mc.g.walls, mc.g.inner)
            val d = if (x == null) 0.0 else shorter(per.P, per.s(mf.wall, mf.off.toDouble()), per.s(x.wall, x.off + x.w / 2.0)).second + (per.spur(mf.wall, mf.off.toDouble())?.len ?: 0.0)
            2 * (d + c.pr.link + mf.h)
        }
    }
    val total = field + lead
    val n = if (total <= 0) 0 else ceil(total / LOOP_MAX - 1e-9).toInt()
    return PLoop(c.id, a, step, lead, total, n)
}

/** The serpentine of a loop over room [c]'s floor, for drawing: lines across [step] apart, inside the floor, [k] of [n] loops' strip. */
fun snake(c: PCtx, step: Int, k: Int = 0, n: Int = 1): List<Pair<V2, V2>> {
    val f = c.g.floor
    val x0 = f.minOf { it.x } + 150; val x1 = f.maxOf { it.x } - 150
    val y0 = f.minOf { it.y } + 150; val y1 = f.maxOf { it.y } - 150
    if (x1 <= x0 || y1 <= y0) return emptyList()
    val sy0 = y0 + (y1 - y0) * k / n; val sy1 = y0 + (y1 - y0) * (k + 1) / n
    val out = ArrayList<Pair<V2, V2>>()
    var y = sy0; var prev: V2? = null; var right = true
    val st = step.coerceIn(50, 400).toDouble()
    // no pipe under an inner partition (geo/InnerWalls.kt): its body, 100 mm round it, is left out of each line
    val rh = uz.metrx.app.geo.roomHOf(c.room)
    val bodies = c.room.inner.flatMap { p -> uz.metrx.app.geo.pieceGeo(p, rh).R.map { b -> b.map { V2(it.x, it.y) } } }
    while (y <= sy1 + 1e-6) {
        var xs = scan(f, y)
        bodies.forEach { b ->
            val ys = b.map { it.y }
            if (y < ys.min() - 100 || y > ys.max() + 100) return@forEach
            val bx0 = b.minOf { it.x } - 100; val bx1 = b.maxOf { it.x } + 100
            xs = xs.flatMap { (s0, s1) -> listOf(s0 to min(s1, bx0), max(s0, bx1) to s1).filter { it.second > it.first } }
        }
        xs = xs.filter { it.second - it.first > 200 }
        val seg = xs.maxByOrNull { it.second - it.first }
        if (seg != null) {
            val a = V2(max(seg.first + 150, x0), y); val b = V2(min(seg.second - 150, x1), y)
            val (s, e) = if (right) a to b else b to a
            prev?.let { out += it to s }
            out += s to e; prev = e; right = !right
        }
        y += st
    }
    return out
}

/** Where line y = [y] is inside polygon [f]: the x stretches. */
fun scan(f: List<V2>, y: Double): List<Pair<Double, Double>> {
    val xs = ArrayList<Double>()
    for (i in f.indices) {
        val a = f[i]; val b = f[(i + 1) % f.size]
        if ((a.y > y) != (b.y > y)) xs += a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)
    }
    xs.sort()
    return xs.chunked(2).filter { it.size == 2 }.map { it[0] to it[1] }
}

/* ---------------- all of them ---------------- */

/** The order's routes: water and heating trunk by trunk, each drain, the underfloor loops. */
fun routesOf(p: Project, cs: List<PCtx>): PRoutes {
    val byId = cs.associateBy { it.id }
    val fixes = cs.flatMap { fixesIn(p, it) }
    val pts = cs.associate { c -> c.id to pointsIn(p, c, fixes.filter { it.roomId == c.id }) }
    val rs = p.plumb.riser?.takeIf { r -> byId.containsKey(r.roomId) && byId[r.roomId]?.free == null }
    val rc = rs?.let { byId[it.roomId] }
    val runs = ArrayList<PRun>()
    val pl = p.plumb
    val srcs = HashMap<String, Src?>()
    for (kind in listOf("cold", "hot", "hs", "hr")) {
        val src = (if (rs == null && kind == "cold") null else sourceOf(p.copy(plumb = pl.copy(riser = rs)), kind, fixes))?.takeIf { byId.containsKey(it.roomId) }
        srcs[kind] = src
        if ((kind == "hs" || kind == "hr") && src == null) continue
        // the source's own outlet is where the pipe starts, not one it goes to
        val per = cs.associate { c -> c.id to pts[c.id].orEmpty().filter { it.t == kind && (src?.fix == null || it.fix != src.fix) } }
        val n = per.values.sumOf { it.size }
        if (n == 0) continue
        val dia = trunkDia(n)
        val away = cs.filter { c -> per[c.id].orEmpty().isNotEmpty() && c.id != src?.roomId }
        val sc = src?.let { byId[it.roomId] }
        cs.forEach { c ->
            val mine = per[c.id].orEmpty()
            val inSrc = src != null && c.id == src.roomId
            if (mine.isEmpty() && !(inSrc && away.isNotEmpty())) return@forEach
            val exits = if (inSrc && sc != null) away.filter { it.free == null }.mapNotNull { exitDoor(sc, it) }.distinctBy { it.id } else emptyList()
            val link = if (inSrc) 0.0 else if (src != null) (c.free?.link ?: c.pr.link).toDouble() else (c.free?.link ?: 0).toDouble()
            runs += supplyRun(c, kind, mine, src, exits, if (kind == "hs" || kind == "hr") pl.hrun else pl.run, link, dia)
        }
    }
    val drains = cs.flatMap { c ->
        pts[c.id].orEmpty().filter { it.t == "drain" }.map { pt -> drainOf(pt, c, rc, rs, if (rs != null || c.free != null) (c.free?.link ?: c.pr.link).toDouble() else 0.0) }
    }
    // the underfloor heating: from the room's own manifold when it has one, else the order's first
    val mfix = fixes.firstOrNull { it.t == "manif" }
    val loops = cs.filter { it.pr.ufh }.map { c ->
        val mf = fixes.firstOrNull { it.t == "manif" && it.roomId == c.id } ?: mfix
        loopOf(c, fixes.filter { it.roomId == c.id }, mf?.let { byId[it.roomId] }, mf?.let { fixPoints(it).firstOrNull() })
    }
    return PRoutes(runs, drains, rs, srcs["hot"], srcs["hs"], loops)
}
