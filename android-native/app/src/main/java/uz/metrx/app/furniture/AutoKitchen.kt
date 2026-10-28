package uz.metrx.app.furniture

import uz.metrx.app.data.Room
import uz.metrx.app.data.uid
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sign

/*
 * "Oshxona yasash", the auto kitchen (Joylan ideas, founder 26 Oct 2026; the approved mockup
 * scratchpad joylan-ideas/mockup.html gen / tryPlan / place / fitW and its checks, ported rule for rule). From a
 * measured room's walls, doors, windows and its water and gas points, the walls picked and the appliances, it builds
 * a kitchen for one design style preset: the fridge (and a tall oven or pantry) at a wall end, never under a window;
 * the sink at the water; the gas hob at the gas pipe, 300 mm clear of wall ends, tall units and windows and 0.9–2.2 m
 * from the sink; the dishwasher beside the sink; the gaps filled with 600 mm units and one odd size or a filler; the
 * corners as the app's own (a blind corner unit with a 50 mm filler, the next run past it); the wall units clear of
 * windows and tall units. Several arrangements are tried and the one with the fewest errors and warnings is kept.
 * The checks only warn. The kitchen it gives is an ordinary one (Kitchen.kt modules), so everything after it (2D, 3D,
 * parts, price, PDF) works as for one made by hand. Pure Kotlin, unit-tested (AutoKitchenTest).
 */

/** The appliances: fridge "bi" built in or "fs" free-standing; oven "hob" under the hob or "tall" in a tall unit; a dishwasher; hood "built" or "angled". */
data class AkApp(val fridge: String = "fs", val oven: String = "hob", val dw: Boolean = true, val hood: String = "built")

/** The layouts, as the chips show them: one wall, a corner (L), three walls (U), two rows on opposite walls. */
val AK_LAYOUTS = listOf("line", "L", "U", "two")

/** A wall as the generator sees it: its length, its start corner on the plan (mm, y down) and its direction. */
data class AkWall(val id: String, val len: Int, val x0: Double, val y0: Double, val ux: Double, val uy: Double) {
    /** Into the room (the plan's walls run clockwise). */
    val nx: Double get() = -uy
    val ny: Double get() = ux
    /** The plan point [t] mm along the wall and [d] mm into the room. */
    fun pt(t: Double, d: Double = 0.0) = doubleArrayOf(x0 + ux * t + nx * d, y0 + uy * t + ny * d)
}

/** A window or a door on a wall: [a]..[b] along it, [sill]..[top] up. */
data class AkOpen(val wall: String, val a: Int, val b: Int, val sill: Int, val top: Int)

/** A water or gas point: [t] mm along its wall. */
data class AkPoint(val wall: String, val t: Int)

/** The room as the generator sees it: its walls in clockwise order, windows, doors, the water and the gas. */
data class AkSite(val walls: List<AkWall>, val windows: List<AkOpen>, val doors: List<AkOpen>, val water: AkPoint?, val gas: AkPoint?, val roomId: String = "", val floorId: String = "") {
    fun wall(id: String): AkWall = walls.first { it.id == id }
    fun has(id: String) = walls.any { it.id == id }
    fun next(id: String): String = walls[(walls.indexOfFirst { it.id == id } + 1) % walls.size].id
    fun prev(id: String): String = walls[(walls.indexOfFirst { it.id == id } + walls.size - 1) % walls.size].id
    fun adjacent(a: String, b: String) = walls.size > 2 && (next(a) == b || next(b) == a)
    fun pt(p: AkPoint): DoubleArray = wall(p.wall).pt(p.t.toDouble())
    /** The walls a kitchen may stand on: those without a door. */
    val free: List<String> get() = walls.map { it.id }.filter { w -> doors.none { it.wall == w } }
}

/** A measured room as the generator sees it; [len] each wall's length (null: not known, the wall is left out). */
fun akSite(room: Room, len: (String) -> Int?, snap: Boolean = true): AkSite {
    val ws = uz.metrx.app.geo.walls(room, snap).mapNotNull { w ->
        val l = len(w.id) ?: w.len ?: return@mapNotNull null
        val dx = w.p1.x - w.p0.x; val dy = w.p1.y - w.p0.y; val d = hypot(dx, dy).takeIf { it > 1e-6 } ?: return@mapNotNull null
        AkWall(w.id, l, w.p0.x, w.p0.y, dx / d, dy / d)
    }
    // the generator lines a kitchen up along the outer walls: what is on an inner wall's face is not its
    val known = ws.map { it.id }.toSet()
    fun open(t: String) = room.openings.filter { it.type == t && it.wall in known }.map { AkOpen(it.wall, it.off, it.off + it.w, it.sill, it.sill + it.h) }
    val pts = room.points.filter { it.wall in known }
    val water = (pts.firstOrNull { it.t == "cold" } ?: pts.firstOrNull { it.t == "sewer" } ?: pts.firstOrNull { it.t == "hot" })?.let { AkPoint(it.wall, it.off) }
    val gas = pts.firstOrNull { it.t == "gas" }?.let { AkPoint(it.wall, it.off) }
    return AkSite(ws, open("window"), open("door"), water, gas, room.id, room.floorId)
}

/** The layout picked walls give: one wall a line, two next to each other an L, two apart two rows, three a U (null: they do not make one). */
fun akLayoutOf(site: AkSite, walls: List<String>): String? = when (walls.size) {
    1 -> "line"
    2 -> if (site.adjacent(walls[0], walls[1])) "L" else "two"
    3 -> if (akChain(site, walls) != null) "U" else null
    else -> null
}

/** Three or two walls one after another round the room, in that order (null: they are not). */
fun akChain(site: AkSite, walls: List<String>): List<String>? {
    val set = walls.toSet()
    val s = walls.firstOrNull { site.prev(it) !in set } ?: return null
    val path = arrayListOf(s)
    while (path.size < walls.size && site.next(path.last()) in set && site.next(path.last()) !in path) path += site.next(path.last())
    return if (path.size == walls.size) path else null
}

/** The walls for a layout chip, starting from those picked [cur]: the longest that fit it, with the picked ones first (null: the room has none). */
fun akWallsFor(site: AkSite, layout: String, cur: List<String>): List<String>? {
    val free = site.free
    fun len(ws: List<String>) = ws.sumOf { site.wall(it).len }
    fun score(ws: List<String>) = ws.count { it in cur } * 100_000 + len(ws)
    val options: List<List<String>> = when (layout) {
        "line" -> free.map { listOf(it) }
        "L" -> free.filter { site.next(it) in free && site.next(it) != it }.map { listOf(it, site.next(it)) }
        "U" -> free.filter { val b = site.next(it); val c = site.next(b); b in free && c in free && c != it && site.walls.size >= 3 }.map { listOf(it, site.next(it), site.next(site.next(it))) }
        else -> free.flatMap { a -> free.filter { b -> b != a && !site.adjacent(a, b) }.map { b -> listOf(a, b) } }.distinctBy { it.toSet() }
    }
    if (layout == "L" && cur.size == 2 && site.adjacent(cur[0], cur[1]) && cur.all { it in free }) return akChain(site, cur)
    return options.maxByOrNull(::score)
}

/* ---------------- the design styles' own plans (mockup PRESETS[].plan) ---------------- */

/** A preset's kitchen plan: its wall units ("mix" a vitrina and an open shelf, "glass2" two vitrinas, "shelf" two open shelves, "flap" lift-ups), a pantry's width, drawers everywhere, LED. */
data class AkPlanOf(val up: String = "", val pantry: Int = 0, val drawers: Boolean = false, val led: Boolean = false)

/** Each of the six DESIGN_PRESETS' plans, as the mockup has them. */
val AK_PLANS = mapOf(
    "twotone" to AkPlanOf(up = "mix"),
    "gloss" to AkPlanOf(up = "flap"),
    "gola" to AkPlanOf(pantry = 450, drawers = true),
    "neo" to AkPlanOf(up = "glass2"),
    "wood" to AkPlanOf(up = "shelf"),
    "dark" to AkPlanOf(pantry = 600, led = true)
)

/* ---------------- the plan ---------------- */

/**
 * One unit of the plan, [a]..[b] mm along its wall. Lower row kinds: fridgeFS, fridgeBI, ovenT, pantry, sink, hob,
 * hobOven, dw, doors, drawers, bottle, filler, cornerS (past the corner: the run before's blind unit and a filler),
 * cornerE (a filler and the blind corner unit). Upper row: doors, glass, shelf, hood, space, cornerS, cornerE.
 */
data class AkSpan(val k: String, val a: Int, val b: Int) { val w: Int get() = b - a }

/** A wall's run of the plan: its lower and upper rows, from its start to its end, nothing missing, nothing overlapping. */
data class AkRun(val wall: String, val len: Int, val cs: Boolean, val ce: Boolean, val low: List<AkSpan>, val up: List<AkSpan>, val angled: AkSpan? = null)

/** A finding: [level] ok, warn or err; [key] its text (strings ak.ck.*, shared with the iPhone); [vars] "m" metres (mm, shown to 0,1 m as {v}), "mm" (shown as {v}), "o" a strings key, "n" a list of sizes, "f" the fillers. */
data class AkCheck(val level: String, val key: String, val vars: Map<String, Any> = emptyMap())

/** The kitchen built for one preset: its runs, checks, score and the things the cards show. */
class AkPlan(
    val preset: String, val layout: String, val walls: List<String>, val runs: List<AkRun>, val app: AkApp,
    val checks: List<AkCheck>, val err: Int, val warn: Int, val score: Double,
    /** How many arrangements were tried. */
    val tried: Int,
    /** The preset's pantry did not fit. */
    val noPantry: Boolean,
    /** The sink and the hob: their wall and place. */
    val sink: Pair<String, AkSpan>, val hob: Pair<String, AkSpan>
) {
    /** The kitchen's length along its walls (each run past a corner from 600), mm: the mockup's running metres. */
    val runMm: Int get() = runs.sumOf { it.len - if (it.cs) K_CORNER else 0 }
}

/* the corners as the app builds them (Kitchen.kt autoFill): the run that turns ends with a 50 filler and a 600 blind
   unit; the next starts past the first one's depth (600) with a 50 filler; its wall units from 320, a filler first */
private const val CORNER_END = CORNER_FILLER + 600
private const val CORNER_START = K_CORNER + CORNER_FILLER
private const val UP_START = K_UP_CORNER + CORNER_FILLER
private const val UP_END = 600

private val STD_W = setOf(150, 200, 300, 400, 450, 500, 600, 800, 900)
private val TALL_K = setOf("fridgeBI", "fridgeFS", "ovenT", "pantry")

private class Itm(val k: String, val a: Double, val b: Double, val tall: Boolean = false)
private class Gap(val a: Double, val b: Double, val hl: Boolean, val hr: Boolean)
private class Rn(val w: AkWall, val cs: Boolean, val ce: Boolean) {
    val L = w.len.toDouble()
    val lo = if (cs) CORNER_START.toDouble() else 0.0
    val hi = if (ce) L - CORNER_END else L
    val items = ArrayList<Itm>()
    val base = ArrayList<Itm>()
    val ups = ArrayList<Itm>()
    var angled: Itm? = null
}
private class Best(val ri: Int, val a: Double, val b: Double, val cost: Double)
private class End(val ri: Int, val side: Int)

private fun dist(a: DoubleArray, b: DoubleArray) = hypot(a[0] - b[0], a[1] - b[1])
private fun badGap(x: Double) = (x > 100 && x < 150) || (x > 200 && x < 300)
private fun pt(r: Rn, t: Double, d: Double = 0.0) = r.w.pt(t, d)

private fun pathRuns(site: AkSite, walls: List<String>, layout: String): List<Rn> {
    if (layout == "two") return walls.map { Rn(site.wall(it), false, false) }
    val path = akChain(site, walls) ?: walls
    return path.mapIndexed { i, w -> Rn(site.wall(w), i > 0, i < path.size - 1) }
}

private fun freeGaps(r: Rn): List<Gap> {
    val it = r.items.sortedBy { it.a }
    val g = ArrayList<Gap>()
    var cur = r.lo; var hl = !r.cs
    for (x in it) {
        if (x.a > cur + .5) g += Gap(cur, x.a, hl, x.tall)
        if (x.b > cur) { cur = x.b; hl = x.tall }
    }
    if (r.hi > cur + .5) g += Gap(cur, r.hi, hl, !r.ce)
    return g
}

/** [a]..[b] less the zones [zs]. */
private fun subtract(a: Double, b: Double, zs: List<Pair<Double, Double>>): List<Pair<Double, Double>> {
    var out = listOf(a to b)
    for ((za, zb) in zs) {
        val n = ArrayList<Pair<Double, Double>>()
        for ((x, y) in out) {
            if (zb <= x || za >= y) { n += x to y; continue }
            if (za > x) n += x to za
            if (zb < y) n += zb to y
        }
        out = n
    }
    return out
}

/** A unit [w] wide as near [target] as it goes, in a free gap, keeping what is left beside it usable (mockup place). */
private fun place(runs: List<Rn>, w: Double, target: DoubleArray, margin: Double = 0.0,
                  zones: (Rn, Int) -> List<Pair<Double, Double>> = { _, _ -> emptyList() },
                  extra: ((Rn, Int, Double) -> Double)? = null): Best? {
    var best: Best? = null
    runs.forEachIndexed { ri, r ->
        val proj = (target[0] - r.w.x0) * r.w.ux + (target[1] - r.w.y0) * r.w.uy
        val zs = zones(r, ri)
        for (g in freeGaps(r)) {
            val a0 = g.a + if (g.hl) margin else 0.0; val b0 = g.b - if (g.hr) margin else 0.0
            for ((sa, sb) in subtract(a0, b0, zs)) {
                if (sb - sa < w - .5) continue
                val c0 = proj.coerceIn(sa + w / 2, max(sa + w / 2, sb - w / 2))
                val l = c0 - w / 2 - g.a; val rr = g.b - c0 - w / 2
                val cands = arrayListOf(c0, sa + w / 2, sb - w / 2)
                if (l > 0) cands += listOf(c0 - l, c0 + 300 - l, c0 + 150 - l, c0 + 200 - l)
                if (rr > 0) cands += listOf(c0 + rr, c0 - (300 - rr), c0 - (150 - rr), c0 - (200 - rr))
                for (c1 in cands) {
                    val c = Math.round((c1 - w / 2) / 10) * 10 + w / 2
                    if (c - w / 2 < sa - .5 || c + w / 2 > sb + .5) continue
                    val lg = c - w / 2 - g.a; val rg = g.b - c - w / 2
                    val cost = dist(pt(r, c), target) + ((if (badGap(lg)) 1 else 0) + (if (badGap(rg)) 1 else 0)) * 5000.0 + (extra?.invoke(r, ri, c) ?: 0.0)
                    if (best == null || cost < best!!.cost) best = Best(ri, c - w / 2, c + w / 2, cost)
                }
            }
        }
    }
    return best
}

/** A gap's units (mockup fitW): 600s and one odd size up to 900 at the end; under 150, one filler (negative). */
internal fun akFit(len0: Int): List<Int> {
    val len = len0
    if (len <= 0) return emptyList()
    if (len < 150) return listOf(-len)
    val out = ArrayList<Int>()
    var rem = len
    while (rem > 900) { out += 600; rem -= 600 }
    out += rem
    return out
}

private fun windowsOn(site: AkSite, r: Rn) = site.windows.filter { it.wall == r.w.id }

/**
 * The kitchen of [preset] on [walls] in [layout] with appliances [app] (mockup gen): every arrangement with the tall
 * units at each free wall end (with and without the preset's pantry) is tried and the best kept. Null when the walls
 * are too short for the tall units.
 */
fun akPlan(site: AkSite, walls: List<String>, layout: String, app: AkApp, preset: String, ws: Workshop = Workshop()): AkPlan? {
    if (walls.isEmpty() || walls.any { !site.has(it) }) return null
    val pp = AK_PLANS[preset] ?: AkPlanOf()
    val r0 = pathRuns(site, walls, layout)
    val ends = ArrayList<End>()
    r0.forEachIndexed { i, r -> if (!r.cs) ends += End(i, 0); if (!r.ce) ends += End(i, 1) }
    var best: AkPlan? = null; var tried = 0
    for (e in ends) for (withP in if (pp.pantry > 0) listOf(true, false) else listOf(false)) {
        val p = tryPlan(site, walls, layout, app, preset, pp, ws, e, withP, false)
        tried++
        if (p != null && (best == null || p.score < best.score)) best = p
    }
    if (best == null) best = ends.firstOrNull()?.let { tryPlan(site, walls, layout, app, preset, pp, ws, it, false, true) }
    return best?.let { AkPlan(it.preset, it.layout, it.walls, it.runs, it.app, it.checks, it.err, it.warn, it.score, tried, it.noPantry, it.sink, it.hob) }
}

private fun tryPlan(site: AkSite, walls: List<String>, layout: String, app: AkApp, preset: String, pp: AkPlanOf, ws: Workshop,
                    e: End, withP: Boolean, noWin: Boolean): AkPlan? {
    val runs = pathRuns(site, walls, layout)
    var relax = 0
    /* 1. the fridge (and a tall oven, the pantry) at a wall end, never under a window */
    val tl = arrayListOf((if (app.fridge == "bi") "fridgeBI" else "fridgeFS") to 600.0)
    if (app.oven == "tall") tl += "ovenT" to 600.0
    if (withP) tl += "pantry" to pp.pantry.toDouble()
    val fr = runs[e.ri]
    val tw = tl.sumOf { it.second }
    if (tw > fr.hi - fr.lo - 300) return null
    var t = if (e.side == 0) fr.lo else fr.hi
    for ((k, w) in tl) {
        val a = if (e.side == 0) t else t - w; val b = a + w
        if (!noWin && windowsOn(site, fr).any { a < it.b && b > it.a }) return null
        fr.items += Itm(k, a, b, true)
        t = if (e.side == 0) b else a
    }
    val blkA = fr.items.minOf { it.a }; val blkB = fr.items.maxOf { it.b }
    val land = { _: Rn, ri: Int -> if (ri == e.ri) listOf(blkA - 400 to blkB + 400) else emptyList() }
    /* 2. the sink at the water point (no water marked: under a window of the kitchen, else the middle of its first wall) */
    val water = site.water?.let { site.pt(it) }
    val waterT = water ?: runs.firstNotNullOfOrNull { r -> windowsOn(site, r).firstOrNull()?.let { pt(r, (it.a + it.b) / 2.0) } } ?: pt(runs[0], runs[0].L / 2)
    /* 3. the gas hob at the gas pipe: 300 mm from wall ends, tall units and windows, 0.9–2.2 m from the sink */
    val gas = site.gas?.let { site.pt(it) }
    val winZ = { rr: Rn -> windowsOn(site, rr).map { it.a - 300.0 to it.b + 300.0 } }
    // the sink as the mockup places it, and the next easier place only when the hob then has none (a short wall)
    var found: Pair<Best, Best>? = null
    for (si in 0..2) {
        val s = when (si) { 0 -> place(runs, 800.0, waterT, zones = land); 1 -> place(runs, 800.0, waterT); else -> place(runs, 600.0, waterT) } ?: continue
        val sr0 = runs[s.ri]
        val sink = Itm("sink", s.a, s.b)
        sr0.items += sink
        val sc0 = (s.a + s.b) / 2; val sP0 = pt(sr0, sc0, 300.0)
        val gasT = gas ?: sP0
        val extra = { rr: Rn, _: Int, c: Double -> val d = dist(pt(rr, c, 300.0), sP0); if (d < 900) 4000.0 else if (d > 2200) (d - 2200) * 3 else 0.0 }
        var hRelax = 0
        val h = place(runs, 600.0, gasT, 300.0, { rr, ri -> winZ(rr) + (if (ri == s.ri) listOf(sc0 - 600 to sc0 + 600) else emptyList()) + land(rr, ri) }, extra)
            ?: run { hRelax = 1; place(runs, 600.0, gasT, 300.0, { rr, _ -> winZ(rr) }, extra) }
            ?: run { hRelax = 3; place(runs, 600.0, gasT, extra = extra) }
        if (h == null) { sr0.items -= sink; continue }
        relax += si + hRelax
        found = s to h
        break
    }
    val (s, h) = found ?: return null
    val sr = runs[s.ri]
    val sc = (s.a + s.b) / 2; val sP = pt(sr, sc, 300.0)
    val hr = runs[h.ri]
    val hobK = if (app.oven == "hob") "hobOven" else "hob"
    hr.items += Itm(hobK, h.a, h.b)
    val hc = (h.a + h.b) / 2; val hP = pt(hr, hc, 300.0)
    /* 4. the dishwasher beside the sink */
    var dwPlaced = false; var dwNext = false
    if (app.dw) {
        var bd: Triple<Double, Double, Double>? = null
        for (w in listOf(600.0, 450.0)) for (side in listOf(1, -1)) {
            val a = if (side > 0) s.b else s.a - w; val b = a + w
            val g = freeGaps(sr).firstOrNull { a >= it.a - .5 && b <= it.b + .5 } ?: continue
            var cost = ((if (badGap(a - g.a)) 1 else 0) + (if (badGap(g.b - b)) 1 else 0)) * 5000.0 + if (w == 600.0) 0.0 else 30.0
            if (h.ri == s.ri && sign(hc - sc).toInt() == side) cost += 40
            if (bd == null || cost < bd.third) bd = Triple(a, b, cost)
        }
        if (bd != null && bd.third < 5000) { sr.items += Itm("dw", bd.first, bd.second); dwPlaced = true; dwNext = true }
        else {
            val d6 = place(runs, 600.0, pt(sr, sc)); val d4 = place(runs, 450.0, pt(sr, sc))
            val d = if (d6 != null && (d4 == null || d6.cost <= d4.cost + 30)) d6 else d4
            if (d != null) { runs[d.ri].items += Itm("dw", d.a, d.b); dwPlaced = true }
        }
    }
    /* 5. the gaps filled with units fitted to the wall; the corners as the app's */
    for (r in runs) {
        r.base.clear(); r.base += r.items
        if (r.ce) r.base += Itm("cornerE", r.hi, r.L)
        if (r.cs) r.base += Itm("cornerS", 0.0, r.lo)
        val hb = r.items.firstOrNull { it.k == hobK }
        for (g in freeGaps(r)) {
            val wsz = akFit(Math.round(g.b - g.a).toInt()).toMutableList()
            val hobL = hb != null && abs(hb.b - g.a) < 1; val hobR = hb != null && abs(hb.a - g.b) < 1
            if (hobR || (!hobL && g.hl && !g.hr && r.items.none { it.tall && abs(it.b - g.a) < 1 })) wsz.reverse()
            var x = g.a
            for (w in wsz) {
                if (w < 0) { r.base += Itm("filler", x, x - w); x -= w; continue }
                val a = x; val b = x + w
                val tH = hb != null && (abs(hb.b - a) < 1 || abs(hb.a - b) < 1)
                val tT = r.items.any { q -> q.tall && (abs(q.b - a) < 1 || abs(q.a - b) < 1) }
                r.base += Itm(if (w <= 200) "bottle" else if (tH || (pp.drawers && w >= 400) || (tT && w in 400..600)) "drawers" else "doors", a, b)
                x = b
            }
        }
        r.base.sortBy { it.a }
    }
    /* 6. the wall units: not over a window or a tall unit; the hood over the hob */
    val up0 = wallElev(ws); val up1 = up0 + K_WALL_H
    runs.forEachIndexed { ri, r ->
        r.ups.clear(); r.angled = null
        val upLo = if (r.cs) UP_START.toDouble() else 0.0; val upHi = if (r.ce) r.L - UP_END else r.L
        val bl = ArrayList<Pair<Double, Double>>()
        for (x in r.items) if (x.tall) bl += x.a to x.b
        val wins = windowsOn(site, r).filter { it.sill < up1 && it.top > up0 }
        wins.forEach { bl += it.a - 50.0 to it.b + 50.0 }
        if (ri == h.ri) {
            val uw = wins.any { h.a < it.b + 50 && h.b > it.a - 50 }
            if (!uw) { if (app.hood == "built") r.ups += Itm("hood", h.a, h.b) else r.angled = Itm("angled", h.a, h.b); bl += h.a to h.b }
        }
        for ((a, b) in subtract(upLo, upHi, bl)) {
            if (b - a < 250) continue
            var x = a
            for (w in akFit(Math.round(b - a).toInt())) { if (w < 0) continue; r.ups += Itm("doors", x, x + w); x += w }
        }
        r.ups.sortBy { it.a }
    }
    val hobW = pt(hr, hc)
    val pool = runs.flatMap { r -> r.ups.filter { it.k == "doors" }.map { u -> Triple(r, u, dist(pt(r, (u.a + u.b) / 2), hobW)) } }.sortedByDescending { it.third }.toMutableList()
    fun setK(r: Rn, u: Itm, k: String) { val i = r.ups.indexOf(u); if (i >= 0) r.ups[i] = Itm(k, u.a, u.b) }
    fun wOf(u: Itm) = u.b - u.a
    when (pp.up) {
        // lift-up doors are drawn as the app's hinged doors (it has no flap front for a kitchen wall unit)
        "flap" -> {}
        "mix" -> {
            pool.firstOrNull { wOf(it.second) >= 500 }?.let { (r, u, _) -> setK(r, u, "glass"); pool.removeAll { it.second === u } }
            pool.firstOrNull { wOf(it.second) <= 450 }?.let { (r, u, _) -> setK(r, u, "shelf") }
        }
        "glass2" -> pool.filter { wOf(it.second) >= 400 }.take(2).forEach { (r, u, _) -> setK(r, u, "glass") }
        "shelf" -> pool.filter { wOf(it.second) <= 800 }.take(2).forEach { (r, u, _) -> setK(r, u, "shelf") }
    }
    /* 7. the checks (warnings only) */
    val checks = ArrayList<AkCheck>(); var err = 0; var warn = 0
    fun add(st: String, key: String, vararg v: Pair<String, Any>) { checks += AkCheck(st, key, v.toMap()); if (st == "warn") warn++; if (st == "err") err++ }
    val dSH = dist(sP, hP)
    add(if (dSH in 900.0..2200.0) "ok" else "warn", when { dSH < 900 -> "ak.ck.shNear"; dSH > 2200 -> "ak.ck.shFar"; else -> "ak.ck.sh" }, "m" to dSH.roundToInt())
    class Obs(val x: Double, val n: String)
    val obs = ArrayList<Obs>()
    if (!hr.cs) obs += Obs(0.0, "ak.o.wall"); if (!hr.ce) obs += Obs(hr.L, "ak.o.wall")
    for (x in hr.items) if (x.tall) { val n = if (x.k.startsWith("fridge")) "ak.o.fridge" else "ak.o.tall"; obs += Obs(x.a, n); obs += Obs(x.b, n) }
    var underWin = false
    for (wn in windowsOn(site, hr)) { if (h.a < wn.b && h.b > wn.a) underWin = true; obs += Obs(wn.a.toDouble(), "ak.o.win"); obs += Obs(wn.b.toDouble(), "ak.o.win") }
    var cl = 1e9; var cn = ""
    for (o in obs) { val d = if (o.x <= h.a + .5) h.a - o.x else if (o.x >= h.b - .5) o.x - h.b else -1.0; if (d >= 0 && d < cl) { cl = d; cn = o.n } }
    when {
        underWin -> add("err", "ak.ck.hobWin")
        cl >= 300 -> if (cl < 1e8) add("ok", "ak.ck.hobClear", "mm" to cl.roundToInt(), "o" to cn) else add("ok", "ak.ck.hobFree")
        else -> add("warn", "ak.ck.hobTight", "mm" to cl.roundToInt(), "o" to cn)
    }
    val f = fr.items.first { it.k.startsWith("fridge") }
    val inner = if (e.side == 0) f.b else f.a
    val seq = if (e.side == 0) fr.base else fr.base.reversed()
    var nb: Itm? = null
    for (x in seq) {
        val touch = if (e.side == 0) x.a >= inner - 1 else x.b <= inner + 1
        if (!touch || x === f || (x.a == f.a && x.b == f.b)) continue
        if (x.k == "filler") continue
        nb = x; break
    }
    when {
        nb == null -> add("warn", "ak.ck.frNone")
        nb.k in TALL_K -> add("warn", "ak.ck.frTall", "o" to if (nb.k == "ovenT") "ak.o.oven" else "ak.o.tall")
        nb.k == "sink" || nb.k == hobK -> add("warn", "ak.ck.frNext", "o" to if (nb.k == "sink") "ak.o.sink" else "ak.o.hob")
        else -> { val w = if (nb.k.startsWith("corner")) 600 else (nb.b - nb.a).roundToInt(); if (w >= 400) add("ok", "ak.ck.frOk", "mm" to w) else add("warn", "ak.ck.frShort", "mm" to w) }
    }
    val dW = water?.let { dist(pt(sr, sc), it) }
    if (dW != null) add(if (dW <= 1000) "ok" else "warn", if (dW < 150) "ak.ck.wOn" else if (dW > 1000) "ak.ck.wFar" else "ak.ck.wNear", "m" to dW.roundToInt())
    else add("warn", "ak.ck.noWater")
    val dG = gas?.let { dist(pt(hr, hc), it) }
    if (dG != null) when {
        dG <= 1500 -> add("ok", "ak.ck.gOk", "m" to dG.roundToInt())
        dG <= 2000 -> add("warn", "ak.ck.gHose", "m" to dG.roundToInt())
        else -> add("err", "ak.ck.gFar", "m" to dG.roundToInt())
    }
    else add("warn", "ak.ck.noGas")
    val ns = sortedSetOf<Int>(compareByDescending { it }); val fl = ArrayList<Int>()
    for (r in runs) {
        for (x in r.base) { val w = (x.b - x.a).roundToInt(); if (x.k == "filler") fl += w else if (!x.k.startsWith("corner") && w !in STD_W) ns += w }
        for (u in r.ups) { val w = (u.b - u.a).roundToInt(); if (w !in STD_W) ns += w }
    }
    val fs = fl.joinToString(", ")
    when {
        ns.isNotEmpty() && fl.isNotEmpty() -> add("ok", "ak.ck.fitF", "n" to ns.joinToString(", "), "f" to fs)
        ns.isNotEmpty() -> add("ok", "ak.ck.fit", "n" to ns.joinToString(", "))
        fl.isNotEmpty() -> add("ok", "ak.ck.fitStdF", "f" to fs)
        else -> add("ok", "ak.ck.fitStd")
    }
    val frWin = runs.any { r -> r.items.any { x -> x.tall && windowsOn(site, r).any { x.a < it.b && x.b > it.a } } }
    if (frWin) add("warn", "ak.ck.frWin") else add("ok", "ak.ck.frEnd")
    if (app.dw) { if (!dwPlaced) add("warn", "ak.ck.dwNone") else if (!dwNext) add("warn", "ak.ck.dwFar") else add("ok", "ak.ck.dwOk") }
    /* 8. the score: the fewest errors and warnings, then the fewest relaxed rules, then the shortest pipes and the fridge nearest the door */
    val door = site.doors.firstOrNull()?.let { site.wall(it.wall).pt((it.a + it.b) / 2.0) }
    val fD = door?.let { dist(pt(fr, (f.a + f.b) / 2), it) } ?: 0.0
    val noP = pp.pantry > 0 && !withP
    val score = err * 1000.0 + warn * 100 + relax * 40 + (if (noP) 150 else 0) + (dG ?: 0.0) / 50 + (dW ?: 0.0) / 50 + fD / 400
    val out = runs.map { r ->
        fun span(x: Itm) = AkSpan(x.k, Math.round(x.a).toInt(), Math.round(x.b).toInt())
        // the upper row from its start to its end: the units, and spaces where none goes (tall units, windows, a slanted hood)
        val upLo = if (r.cs) UP_START else 0; val upHi = if (r.ce) r.w.len - UP_END else r.w.len
        val ups = ArrayList<AkSpan>()
        if (r.cs) ups += AkSpan("cornerS", 0, upLo)
        var x = upLo
        for (u in r.ups) { val s0 = span(u); if (s0.a > x) ups += AkSpan("space", x, s0.a); ups += s0; x = s0.b }
        if (upHi > x) ups += AkSpan("space", x, upHi)
        if (r.ce) {
            val win = windowsOn(site, r).any { it.sill < up1 && it.top > up0 && it.b > upHi && it.a < r.w.len }
            ups += AkSpan(if (win) "space" else "cornerE", upHi, r.w.len)
        }
        AkRun(r.w.id, r.w.len, r.cs, r.ce, r.base.map(::span), ups, r.angled?.let(::span))
    }
    return AkPlan(preset, layout, runs.map { it.w.id }, out, app, checks, err, warn, score, 0, noP,
        sr.w.id to AkSpan("sink", Math.round(s.a).toInt(), Math.round(s.b).toInt()), hr.w.id to AkSpan(hobK, Math.round(h.a).toInt(), Math.round(h.b).toInt()))
}

/* ---------------- the kitchen it gives ---------------- */

/** The app's layout letter for a plan's runs: one wall I, two L, three U (two rows are two one-wall kitchens). */
private fun appLayout(n: Int) = when (n) { 2 -> "L"; 3 -> "U"; else -> "I" }

/** A run's modules, lower row then upper row, from its start to its end in the order the designer packs them. */
private fun modulesOf(r: AkRun, ws: Workshop): List<Module> {
    val w = r.wall
    val out = ArrayList<Module>()
    for (s in r.low) out += when (s.k) {
        "fridgeFS" -> listOf(template("fridge", ws, w, s.w))
        "fridgeBI" -> listOf(template("fridgeB", ws, w, s.w))
        "ovenT" -> listOf(template("oven", ws, w, s.w))
        "pantry" -> listOf(template("pantry", ws, w, s.w))
        "sink" -> listOf(template("sink", ws, w, s.w))
        // the oven under the hob: the app's hob unit (its oven is not drawn on its own)
        "hob", "hobOven" -> listOf(template("hob", ws, w, s.w))
        "dw" -> listOf(template("dishwasher", ws, w, s.w))
        "drawers" -> listOf(template("drawers", ws, w, s.w))
        "filler" -> listOf(template("fillerLow", ws, w, s.w))
        // past the corner: the run before's blind unit stands in 0..600; a 50 filler, then this run's units
        "cornerS" -> listOf(template("fillerLow", ws, w, s.w - K_CORNER))
        // the run that turns: a 50 filler and the blind corner unit (a panel, no door) behind the next run's first
        "cornerE" -> listOf(template("fillerLow", ws, w, CORNER_FILLER), template("base", ws, w, s.w - CORNER_FILLER).copy(fronts = Fronts("panel", 1)))
        else -> listOf(template("base", ws, w, s.w))
    }
    for (s in r.up) out += when (s.k) {
        "cornerS" -> listOf(template("fillerUp", ws, w, s.w - K_UP_CORNER))
        "cornerE" -> listOf(template("wall", ws, w, s.w).copy(fronts = Fronts("panel", 1)))
        "glass" -> listOf(template("vitrina", ws, w, s.w))
        "shelf" -> listOf(template("open", ws, w, s.w))
        "hood" -> listOf(template("hood", ws, w, s.w))
        "space" -> listOf(template("spaceUp", ws, w, s.w))
        else -> listOf(template("wall", ws, w, s.w))
    }
    return out
}

/**
 * The kitchen of [plan] as the order's furniture, in its preset's look: one piece, or two one-wall pieces for two
 * rows ([names] their names). In room [site]'s room and workspace, made at [now].
 */
fun akPieces(plan: AkPlan, site: AkSite, ws: Workshop, names: List<String>, now: Long = 0): List<Furniture> {
    val groups = if (plan.layout == "two") plan.runs.map { listOf(it) } else listOf(plan.runs)
    val pp = AK_PLANS[plan.preset] ?: AkPlanOf()
    return groups.mapIndexed { i, rs ->
        val layout = appLayout(rs.size)
        var f = Furniture(uid(), "kitchen", names.getOrElse(i) { names.lastOrNull() ?: "" }, site.roomId.ifEmpty { null }, rs.map { it.wall },
            rs.flatMap { modulesOf(it, ws) }, created = now, layout = layout, ws = site.floorId, kx = kExtrasFor(layout))
        f = pack(f, runsOf(f) { w -> rs.firstOrNull { it.wall == w }?.len })
        f = withPreset(f, plan.preset, fresh = true, ws = ws)
        if (pp.led) f = f.copy(kx = (f.kx ?: KExtras()).copy(led = true))
        f
    }
}

/** How many units a kitchen of [fs] has: its boxes and the dishwasher, not fillers, spaces or a free-standing fridge. */
fun akUnits(fs: List<Furniture>): Int = fs.sumOf { f -> f.modules.count { it.type == "base" || it.type == "wall" || it.type == "tall" || it.app == "dishwasher" } }

/** All six presets' kitchens for the same walls and appliances, in DESIGN_PRESETS' order (null where it does not fit). */
fun akAll(site: AkSite, walls: List<String>, layout: String, app: AkApp, ws: Workshop): List<Pair<String, AkPlan?>> =
    DESIGN_PRESETS.map { it.id to akPlan(site, walls, layout, app, it.id, ws) }

/** The walls a new auto kitchen starts with: the free wall with the water, or the longest free one, as a line. */
fun akStart(site: AkSite): List<String> {
    val free = site.free
    val w = site.water?.wall?.takeIf { it in free } ?: free.maxByOrNull { site.wall(it).len } ?: return emptyList()
    return listOf(w)
}
