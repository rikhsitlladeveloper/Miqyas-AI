package uz.metrx.app.plumb

import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.elec.centreOf
import uz.metrx.app.elec.inside
import uz.metrx.app.elec.nearestWall
import uz.metrx.app.tiles.TRoomGeo
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import uz.metrx.app.tiles.area
import uz.metrx.app.tiles.roomGeo
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.roundToInt

/*
 * A room as the fixtures see it, the room kits and placing: a kit's fixtures stood against the walls at their usual
 * spots, clear of the doors, the windows, the door's swing, the riser and each other; a fixture dragged along its wall
 * snaps to the corners and its neighbours, its outlets go with it; loose outlets snap to the usual heights.
 */

/** Water and drain points on the walls, as the furniture marks them. */
val SITE_WATER = setOf("cold", "hot", "sewer")

/**
 * One room for the plumber: a measured room, or one typed by size ([free], drawn as a plain box with a door). [g] its
 * walls and floor (plan mm), [kind] what room it is, [pr] its settings.
 */
class PCtx(val id: String, val room: Room, val g: TRoomGeo, val kind: String, val pr: PlRoom, val free: PlFree? = null) {
    val H get() = g.H.toInt()
    val doors get() = room.openings.filter { it.type == "door" }
    val entry: Opening? get() = doors.firstOrNull { it.id == pr.door } ?: doors.firstOrNull()
    fun wall(id: String?) = id?.let { g.wall(it) }
    /** The floor's area, m². */
    val areaM2 get() = abs(area(g.floor)) / 1e6
}

/** The made-up room of a room typed by size: [f]'s box with a door on wall A and a window on wall C. */
fun freeRoom(f: PlFree) = Room("free:${f.id}", "", f.name, dims = mapOf("A" to Dim(f.L), "B" to Dim(f.W), "H" to Dim(f.H), "T" to Dim(120, "default")),
    openings = listOf(Opening("fd", "door", "A", 800, minOf(2100, f.H - 200), 250)), floorColor = "#DDE2E8")

/** Room [rid] of order [p], ready for fixtures (null: not measured yet). */
fun ctxOf(p: Project, rid: String, snap: Boolean): PCtx? {
    if (rid.startsWith("free:")) return p.plumb.free.firstOrNull { "free:${it.id}" == rid }?.let { freeCtx(it) }
    val r = p.rooms.firstOrNull { it.id == rid } ?: return null
    val g = roomGeo(r, snap, emptyList()) ?: return null
    val pr = p.plumb.room(rid)
    val kind = pr.kind.ifEmpty { guessKind(p.floors.firstOrNull { it.id == r.floorId }?.type, r.name) }
    return PCtx(rid, r, g, kind, pr)
}

fun freeCtx(f: PlFree): PCtx? {
    val r = freeRoom(f)
    val g = roomGeo(r, true, emptyList()) ?: return null
    return PCtx(r.id, r, g, f.kind, PlRoom(r.id, f.kind, link = f.link, ufh = f.ufh), f)
}

/** Every room of the order that fixtures can be in: the measured ones in order, then the typed ones. */
fun ctxs(p: Project, snap: Boolean): List<PCtx> = p.rooms.mapNotNull { ctxOf(p, it.id, snap) } + p.plumb.free.mapNotNull { freeCtx(it) }

/** The fixtures of a room: placed ones, or a typed room's made from its counts. */
fun fixesIn(p: Project, c: PCtx): List<PlFix> = if (c.free != null) freeFixes(c.free, c) else p.plumb.fixes.filter { it.roomId == c.id }

/** One outlet where it is: a fixture's ([fix] its id, [usual] its usual height) or a loose one. */
class APt(val id: String, val t: String, val roomId: String, val wall: String, val off: Int, val h: Int, val d: Int, val fix: String?, val usual: Int?, val tol: Int)

/** The outlets of a room: its fixtures' and the loose ones. */
fun pointsIn(p: Project, c: PCtx, fs: List<PlFix> = fixesIn(p, c)): List<APt> =
    fs.flatMap { f -> fixPoints(f) } + (if (c.free != null) emptyList() else p.plumb.points.filter { it.roomId == c.id }.map { APt(it.id, it.t, it.roomId, it.wall, it.off, it.h, it.d, null, null, 0) })

/** A fixture's outlets on its wall. */
fun fixPoints(f: PlFix): List<APt> {
    val ty = fixType(f.t)
    val usual = defaultPts(f.t, fixW(f))
    return f.pts.mapIndexed { i, q -> APt("${f.id}:$i", q.t, f.roomId, f.wall, f.off + q.dx, q.h, q.d, f.id, usual.getOrNull(i)?.h, ty.tol) }
}

/* ---------------- footprints ---------------- */

/** A fixture's place on the plan: its four corners, [grow] mm larger all round. */
fun fixPoly(c: PCtx, f: PlFix, grow: Double = 0.0): List<V2>? {
    val w = c.wall(f.wall) ?: return null
    return boxPoly(w, f.off.toDouble(), fixW(f).toDouble(), fixD(f).toDouble(), grow)
}

fun boxPoly(w: TWall, x: Double, fw: Double, fd: Double, grow: Double = 0.0): List<V2> {
    val a0 = x - fw / 2 - grow; val a1 = x + fw / 2 + grow
    return listOf(w.at(a0, -grow), w.at(a1, -grow), w.at(a1, fd + grow), w.at(a0, fd + grow))
}

/** The floor a door sweeps as it opens into the room (its hinge at its start): the square round its quarter circle. */
fun swingPoly(c: PCtx, o: Opening): List<V2>? {
    val w = c.wall(o.wall) ?: return null
    return listOf(w.at(o.off.toDouble()), w.at((o.off + o.w).toDouble()), w.at((o.off + o.w).toDouble(), o.w.toDouble()), w.at(o.off.toDouble(), o.w.toDouble()))
}

/** The riser's box on the plan. */
fun riserPoly(c: PCtx, r: PlRiser, grow: Double = 0.0): List<V2>? = c.wall(r.wall)?.let { boxPoly(it, r.off.toDouble(), RISER_W.toDouble(), RISER_D.toDouble(), grow) }

/** Whether convex polygons [a] and [b] overlap (separating axes; touching is not overlapping). */
fun convexHit(a: List<V2>, b: List<V2>): Boolean {
    for (poly in listOf(a, b)) for (i in poly.indices) {
        val p = poly[i]; val q = poly[(i + 1) % poly.size]
        val n = V2(-(q.y - p.y), q.x - p.x)
        val ra = a.map { it.dot(n) }; val rb = b.map { it.dot(n) }
        if (ra.max() <= rb.min() + 1e-6 || rb.max() <= ra.min() + 1e-6) return false
    }
    return true
}

/** Whether fixture [f] stands in the way of one of the room's doors as it opens. */
fun blocksDoor(c: PCtx, f: PlFix): Boolean {
    val fp = fixPoly(c, f) ?: return false
    return c.doors.any { o -> swingPoly(c, o)?.let { convexHit(fp, it) } == true || (o.wall == f.wall && f.off + fixW(f) / 2.0 > o.off && f.off - fixW(f) / 2.0 < o.off + o.w) }
}

/**
 * Whether a fixture of type [t], [fw] wide, centred [x] along wall [w] fits: inside the wall and the room, off its doors
 * and the windows it would reach, out of every door's swing, clear of the riser, the columns and the fixtures [others]
 * at its height ([opt] a basin's cabinet).
 */
fun fits(c: PCtx, t: String, w: TWall, x: Double, fw: Int, others: List<PlFix>, riser: PlRiser?, opt: String = ""): Boolean {
    val ty = fixType(t)
    val fd = ty.d.toDouble()
    if (x - fw / 2.0 < 10 || x + fw / 2.0 > w.len - 10) return false
    val fp = boxPoly(w, x, fw.toDouble(), fd)
    val mid = V2(fp.sumOf { it.x } / 4, fp.sumOf { it.y } / 4)
    if (fp.any { q -> !inside(c.g.floor, q + (mid - q) * (2.0 / hypot(mid.x - q.x, mid.y - q.y).coerceAtLeast(1.0))) }) return false
    val z0 = if (opt == "cab") 0 else ty.z0; val z1 = ty.h
    // the wall's own doors, and its windows where the fixture reaches up to them (a radiator stays under the sill)
    for (o in c.room.openings.filter { it.wall == w.id }) {
        val over = x + fw / 2.0 > o.off - 50 && x - fw / 2.0 < o.off + o.w + 50
        if (!over) continue
        if (o.type == "door") return false
        if (z1 > o.sill - 20 && z0 < o.sill + o.h) return false
    }
    if (c.g.rect) for (f in c.room.features.filter { it.wall == w.id }) if (x + fw / 2.0 > f.off - 20 && x - fw / 2.0 < f.off + f.w + 20) return false
    for (o in c.doors) { val sp = swingPoly(c, o) ?: continue; if (convexHit(fp, sp)) return false }
    if (riser != null && riser.roomId == c.id) riserPoly(c, riser, 20.0)?.let { if (convexHit(fp, it)) return false }
    for (f in others) {
        val oz0 = fixZ0(f); val oz1 = fixTop(f)
        // only a heater or a towel rail may hang over another fixture (a water heater over the washer); a basin never over the bath
        val hangs = ty.cat == "heater" || t == "tr" || fixType(f.t).cat == "heater" || f.t == "tr"
        if (hangs && (z1 <= oz0 || oz1 <= z0)) continue
        val op = fixPoly(c, f, 30.0) ?: continue
        if (convexHit(fp, op)) return false
    }
    return true
}

/** The free spot nearest [prefer] along wall [w] for a fixture of type [t], [fw] wide; null when the wall has none. Whole centimetres. */
fun fixSpot(c: PCtx, t: String, w: TWall, prefer: Double, fw: Int, others: List<PlFix>, riser: PlRiser?, opt: String = ""): Int? {
    val lo = fw / 2.0 + 10; val hi = w.len - fw / 2.0 - 10
    if (hi < lo) return null
    val p0 = (Math.round(prefer.coerceIn(lo, hi) / 10.0) * 10.0).coerceIn(lo, hi)
    var k = 0
    while (k * 10.0 <= w.len) {
        val a = p0 + k * 10; if (a <= hi && fits(c, t, w, a, fw, others, riser, opt)) return a.roundToInt()
        val b = p0 - k * 10; if (k > 0 && b >= lo && fits(c, t, w, b, fw, others, riser, opt)) return b.roundToInt()
        k++
    }
    return null
}

/* ---------------- choosing the walls ---------------- */

private fun hasDoor(c: PCtx, w: TWall) = c.room.openings.any { it.wall == w.id && it.type == "door" }
private fun mid(w: TWall) = w.at(w.len / 2)

/** The wall the water is on: the one with most water and drain marked on it, else the riser's, else a long one without a door. */
fun wetWall(c: PCtx, riser: PlRiser?): TWall {
    val wet = c.room.points.filter { it.t in SITE_WATER }
    if (wet.isNotEmpty()) return c.g.walls.maxBy { w -> wet.count { it.wall == w.id } * 100_000.0 + w.len }
    if (riser != null && riser.roomId == c.id) c.wall(riser.wall)?.let { return it }
    return c.g.walls.maxBy { w -> w.len - (if (hasDoor(c, w)) 5000 else 0) }
}

/** The wall furthest from the room's door (a bath stands across it). */
fun farWall(c: PCtx): TWall {
    val e = c.entry ?: return c.g.walls.maxBy { it.len }
    val ew = c.wall(e.wall) ?: return c.g.walls.maxBy { it.len }
    val dp = ew.at(e.off + e.w / 2.0)
    return c.g.walls.filter { it.id != ew.id }.maxByOrNull { w -> hypot(mid(w).x - dp.x, mid(w).y - dp.y) } ?: ew
}

/** The walls to try for a fixture, the preferred one first. */
private fun order(c: PCtx, first: TWall?, vararg more: TWall?): List<TWall> =
    (listOfNotNull(first) + more.filterNotNull() + c.g.walls.filter { !hasDoor(c, it) }.sortedByDescending { it.len } + c.g.walls.sortedByDescending { it.len }).distinctBy { it.id }

/* ---------------- kits ---------------- */

/** A room kit of the gallery: what a room of [kind] usually gets. */
class PKit(val id: String, val kind: String, val opts: POpts, val main: List<String>)

val PKITS = listOf(
    PKit("bt.bath", "bath", POpts(bath = "bath", wm = true), listOf("bath", "cab", "wm", "tr")),
    PKit("bt.shower", "bath", POpts(bath = "sh", wm = true), listOf("bath", "cab", "wm", "tr")),
    PKit("bt.cabin", "bath", POpts(bath = "cab", wm = false), listOf("bath", "cab", "wm", "tr")),
    PKit("wc.std", "wc", POpts(basin = false), listOf("basin")),
    PKit("wc.basin", "wc", POpts(basin = true), listOf("basin")),
    PKit("kt.std", "kitchen", POpts(dw = true), listOf("dw")),
    PKit("kt.sink", "kitchen", POpts(dw = false), listOf("dw")),
    PKit("ut.gas", "util", POpts(heater = "gb", wm = false), listOf("heater", "wm")),
    PKit("ut.wh", "util", POpts(heater = "wh", wm = true), listOf("heater", "wm")),
    PKit("ht.rad", "heat", POpts(rad = true), emptyList()),
    PKit("ht.ufh", "heat", POpts(ufh = true), listOf("step"))
)

fun pkitOf(id: String) = PKITS.firstOrNull { it.id == id }

/** The fixture types a kit puts in with choices [o], in the order they are placed. */
fun kitTypes(k: PKit, o: POpts): List<String> = buildList {
    when (k.kind) {
        "bath" -> { add(o.bath.ifEmpty { "bath" }); add("wc"); add("bs"); if (o.wm) add("wm"); if (o.tr) add("tr") }
        "wc" -> { add("wc"); if (o.basin) add("bsm") }
        "kitchen" -> { add("sink"); if (o.dw) add("dw") }
        "util" -> { add(if (o.heater == "wh") "wh" else "gb"); if (o.wm) add("wm") }
    }
}

/** A fixture of type [t] for room [c] centred [x] on wall [w]. */
fun newFix(id: String, t: String, c: PCtx, w: TWall, x: Int, kit: String = "", opt: String = "", width: Int = 0) =
    PlFix(id, t, c.id, w.id, x, width, opt, defaultPts(t, width), kit)

/**
 * Where a fixture of type [t] goes in room [c] among the fixtures [have]: the bath and shower across the far wall into
 * a corner, the toilet beside the riser, the basin and washer on the wet wall, the dishwasher beside the sink, a heater
 * on the wet wall up high, a towel rail on a free wall. Null when there is no room for it.
 */
fun placeFix(t: String, c: PCtx, have: List<PlFix>, riser: PlRiser?, id: String, kit: String = "", opt: String = ""): PlFix? {
    val ty = fixType(t)
    val fw = ty.w
    val wet = wetWall(c, riser)
    val far = farWall(c)
    val rw = riser?.takeIf { it.roomId == c.id }?.let { c.wall(it.wall) }
    val door = c.entry?.let { e -> c.wall(e.wall)?.at(e.off + e.w / 2.0) }
    fun awayCorner(w: TWall): Double {
        // the end of the wall further from the door
        if (door == null) return fw / 2.0 + 10
        val s = w.at(0.0); val e = w.at(w.len)
        return if (hypot(s.x - door.x, s.y - door.y) >= hypot(e.x - door.x, e.y - door.y)) fw / 2.0 + 10 else w.len - fw / 2.0 - 10
    }
    val tries: List<Pair<TWall, Double>> = when (t) {
        "bath", "sh", "cab" -> order(c, far, wet).map { it to awayCorner(it) }
        "wc" -> if (rw != null) order(c, rw, wet).map { w -> w to (if (w.id == rw.id) riser!!.off + (if (riser.off < w.len / 2) 1 else -1) * (RISER_W / 2.0 + fw / 2.0 + 120) else awayCorner(w)) }
            else order(c, wet).map { it to awayCorner(it) }
        "bs", "bsm" -> order(c, wet).map { it to it.len / 2 }
        "wm" -> order(c, wet).map { it to it.len - fw / 2.0 - 10 }
        "sink" -> order(c, wet).map { w -> w to (c.room.points.firstOrNull { it.wall == w.id && it.t in SITE_WATER }?.off?.toDouble() ?: (w.len * .4)) }
        "dw" -> { val s = have.firstOrNull { it.t == "sink" }; val sw = s?.let { c.wall(it.wall) }
            order(c, sw, wet).map { w -> w to (if (s != null && w.id == s.wall) s.off + fixW(s) / 2.0 + 20 + fw / 2.0 else w.len / 2) } }
        "wh", "gb" -> order(c, wet).map { it to it.len - fw / 2.0 - 150 }
        "tr" -> order(c, null, *c.g.walls.filter { w -> have.none { it.wall == w.id && fixType(it.t).cat == "wet" } }.toTypedArray()).map { it to it.len / 2 }
        "manif" -> { val e = c.entry; val ew = e?.let { c.wall(it.wall) }; order(c, ew).map { w -> w to (if (e != null && w.id == e.wall) e.off + e.w + 200.0 + fw / 2 else w.len / 2) } }
        else -> order(c, wet).map { it to it.len / 2 }
    }
    for ((w, prefer) in tries) {
        val x = fixSpot(c, t, w, prefer, fw, have, riser, opt) ?: continue
        return newFix(id, t, c, w, x, kit, opt)
    }
    return null
}

/** Radiators under the windows of room [c] (else on its longest wall without a door), sized by the floor: [W_M2] a m². */
fun placeRadiators(c: PCtx, have: List<PlFix>, riser: PlRiser?, id: () -> String, kit: String = ""): List<PlFix> {
    val out = ArrayList<PlFix>()
    val wins = c.room.openings.filter { it.type == "window" && c.wall(it.wall) != null }
    val secs = radSections(c.areaM2)
    if (wins.isEmpty()) {
        val w = c.g.walls.filter { !hasDoor(c, it) }.maxByOrNull { it.len } ?: c.g.walls.maxBy { it.len }
        val rw = radWidth(secs)
        fixSpot(c, "rad", w, w.len / 2, rw, have, riser)?.let { out += newFix(id(), "rad", c, w, it, kit, width = rw) }
        return out
    }
    val each = ceil(secs / wins.size.toDouble()).toInt().coerceAtLeast(3)
    for (o in wins) {
        val w = c.wall(o.wall)!!
        val rw = radWidth(each).coerceAtMost(maxOf(400, o.w + 200))
        fixSpot(c, "rad", w, o.off + o.w / 2.0, rw, have + out, riser)?.let { out += newFix(id(), "rad", c, w, it, kit, width = rw) }
    }
    return out
}

/** Radiator sections for a room of [m2] m²: [W_M2] W a m², [SEC_W] W a section, 3 at least. */
fun radSections(m2: Double) = max(3, ceil(m2 * W_M2 / SEC_W - 1e-9).toInt())
fun radWidth(sections: Int) = sections * SEC_MM

/** A radiator's heat, W, from its width. */
fun radWatts(f: PlFix) = fixW(f) / SEC_MM * SEC_W

/**
 * The fixtures of kit [k] (with choices [o]) placed in room [c] among those it has ([have]): each at its usual spot,
 * clear of what is in the way. [id] makes the new ids. The underfloor heating is the room's setting, not a fixture.
 */
fun placeKit(k: PKit, c: PCtx, have: List<PlFix>, riser: PlRiser?, id: () -> String, o: POpts = k.opts): List<PlFix> {
    val types = kitTypes(k, o)
    fun put(order: List<String>): List<PlFix> {
        val got = ArrayList<PlFix>()
        order.forEachIndexed { i, t -> placeFix(t, c, have + got, riser, "~$i", k.id, if (t == "bs" && o.cab) "cab" else "")?.let { got += it } }
        return got
    }
    var best = put(types)
    // the toilet wants the riser (its 110 drain short): tried first too, kept when it puts everything in and lands nearer
    val rs = riser?.takeIf { it.roomId == c.id }
    if (rs != null && "wc" in types && types.first() != "wc") {
        val alt = put(listOf("wc") + types.filter { it != "wc" })
        fun d(fs: List<PlFix>) = fs.firstOrNull { it.t == "wc" }?.let { wcToRiser(c, it, rs) } ?: Double.MAX_VALUE
        if (alt.size > best.size || (alt.size == best.size && d(alt) + 1 < d(best))) best = alt
    }
    val out = ArrayList(best.sortedBy { f -> types.indexOf(f.t) }.map { it.copy(id = id()) })
    if (o.rad && (have + out).none { it.t == "rad" }) out += placeRadiators(c, have + out, riser, id, k.id)
    return out
}

/** How far along the walls toilet [f] is from riser [rs] in its room, mm. */
fun wcToRiser(c: PCtx, f: PlFix, rs: PlRiser): Double {
    val per = uz.metrx.app.elec.Perim(c.g.walls)
    return shorter(per.P, per.s(f.wall, f.off.toDouble()), per.s(rs.wall, rs.off.toDouble())).second
}

/* ---------------- the riser ---------------- */

/** The riser put in room [c]: in a corner of its wet wall, clear of the doors; else any corner. */
fun riserIn(c: PCtx, fixes: List<PlFix> = emptyList()): PlRiser {
    val wet = wetWall(c, null)
    val walls = listOf(wet) + c.g.walls.filter { it.id != wet.id && !hasDoor(c, it) } + c.g.walls
    for (w in walls.distinctBy { it.id }) for (x in listOf(RISER_W / 2.0 + 10, w.len - RISER_W / 2.0 - 10)) {
        if (riserFits(c, w, x, fixes)) return PlRiser(c.id, w.id, x.roundToInt())
    }
    return PlRiser(c.id, wet.id, (RISER_W / 2 + 10))
}

private fun riserFits(c: PCtx, w: TWall, x: Double, fixes: List<PlFix>): Boolean {
    if (x - RISER_W / 2.0 < 0 || x + RISER_W / 2.0 > w.len) return false
    if (c.room.openings.any { o -> o.wall == w.id && x + RISER_W / 2.0 > o.off - 50 && x - RISER_W / 2.0 < o.off + o.w + 50 && (o.type == "door" || o.sill < 2000) }) return false
    val fp = boxPoly(w, x, RISER_W.toDouble(), RISER_D.toDouble())
    if (c.doors.any { o -> swingPoly(c, o)?.let { convexHit(fp, it) } == true }) return false
    return fixes.none { f -> f.roomId == c.id && fixPoly(c, f, 20.0)?.let { convexHit(fp, it) } == true }
}

/** Where the riser goes by default: a bathroom or toilet (the one with most fixtures), else the room with most fixtures. */
fun defaultRiser(p: Project, snap: Boolean): PlRiser? {
    val cs = p.rooms.mapNotNull { ctxOf(p, it.id, snap) }
    fun n(c: PCtx) = p.plumb.fixes.count { it.roomId == c.id }
    val c = cs.filter { it.kind == "bath" || it.kind == "wc" }.maxByOrNull { n(it) } ?: cs.maxByOrNull { n(it) } ?: return null
    return riserIn(c, p.plumb.fixes)
}

/** Dragging the riser: along its wall in whole centimetres, into a corner when near one. */
fun snapRiser(c: PCtx, r: PlRiser, wall: String, rawOff: Int): PlRiser {
    val w = c.wall(wall) ?: return r
    val lo = RISER_W / 2.0 + 10; val hi = max(lo, w.len - RISER_W / 2.0 - 10)
    val x0 = ((rawOff + 5) / 10 * 10).toDouble()
    val x = when { abs(x0 - lo) <= 150 -> lo; abs(x0 - hi) <= 150 -> hi; else -> x0 }.coerceIn(lo, hi)
    return r.copy(wall = w.id, off = x.roundToInt())
}

/* ---------------- moving ---------------- */

/**
 * Where fixture [f] dragged to [rawOff] along wall [wall] lands: into a corner or beside a neighbour when near (80 mm),
 * else in whole centimetres; moved to the nearest free spot when it would stand in the way; null when the wall has none.
 */
fun snapFix(c: PCtx, f: PlFix, wall: String, rawOff: Int, others: List<PlFix>, riser: PlRiser?): Int? {
    val w = c.wall(wall) ?: return null
    val fw = fixW(f)
    val xs = ArrayList<Double>()
    xs += fw / 2.0 + 10; xs += w.len - fw / 2.0 - 10
    others.filter { it.wall == w.id && it.id != f.id }.forEach { o -> xs += o.off + fixW(o) / 2.0 + 30 + fw / 2.0; xs += o.off - fixW(o) / 2.0 - 30 - fw / 2.0 }
    if (riser != null && riser.roomId == c.id && riser.wall == w.id) { xs += riser.off + RISER_W / 2.0 + 20 + fw / 2.0; xs += riser.off - RISER_W / 2.0 - 20 - fw / 2.0 }
    c.room.openings.filter { it.wall == w.id }.forEach { o -> xs += o.off + o.w + 50.0 + fw / 2; xs += o.off - 50.0 - fw / 2 }
    val lo = fw / 2.0 + 10; val hi = max(lo, w.len - fw / 2.0 - 10)
    val x0 = (xs.minByOrNull { abs(it - rawOff) }?.takeIf { abs(it - rawOff) <= 80 } ?: ((rawOff + 5) / 10 * 10).toDouble()).coerceIn(lo, hi)
    val rest = others.filter { it.id != f.id }
    if (fits(c, f.t, w, x0, fw, rest, riser, f.opt)) return x0.roundToInt()
    return fixSpot(c, f.t, w, x0, fw, rest, riser, f.opt)
}

/** A fixture dragged on the plan to [q]: onto the nearest wall, along it as [snapFix] has it; where it was when that wall has no room. */
fun snapFixPlan(c: PCtx, f: PlFix, q: V2, others: List<PlFix>, riser: PlRiser?): Pair<String, Int> {
    val (w, a, _) = nearestWall(c.g.walls, q)
    return snapFix(c, f, w.id, a.roundToInt(), others, riser)?.let { w.id to it } ?: (f.wall to f.off)
}

/** Where loose outlet [pt] dragged to ([rawOff], [rawH]) on its wall lands: the usual heights when near (60 mm), whole centimetres, on the wall. */
fun snapPoint(c: PCtx, pt: PlPoint, rawOff: Int, rawH: Int): Pair<Int, Int> {
    val w = c.wall(pt.wall) ?: return rawOff to rawH
    val h = (SNAP_H.minByOrNull { abs(it - rawH) }?.takeIf { abs(it - rawH) <= 60 } ?: ((rawH + 5) / 10 * 10)).coerceIn(30, max(30, c.H - 50))
    val x = ((rawOff + 5) / 10 * 10).coerceIn(30, max(30, w.len.toInt() - 30))
    return x to h
}

/** Fixture [f] moved to wall [wall] at [off]: its outlets go with it. */
fun moveFix(f: PlFix, wall: String, off: Int) = f.copy(wall = wall, off = off)

/** Fixture [f] made [w] wide (a radiator): its outlets at its ends again. */
fun resizeFix(f: PlFix, w: Int) = if (f.t == "rad") f.copy(w = w, pts = radPts(w)) else f.copy(w = w)

/* ---------------- a room typed by size ---------------- */

/** A typed room's fixtures from its counts, placed as a kit would. */
fun freeFixes(f: PlFree, c: PCtx): List<PlFix> {
    val out = ArrayList<PlFix>()
    var n = 0
    fun id() = "f:${f.id}:${n++}"
    // a small typed room: what does not fit clear of its made-up door's swing still goes in (the door is only a guess);
    // what is bigger than the room stays out ([freeMissing] says so)
    val bare = PCtx(c.id, c.room.copy(openings = emptyList()), c.g, c.kind, c.pr, c.free)
    fun put(t: String, k: Int) = repeat(k.coerceIn(0, 6)) { (placeFix(t, c, out, null, id()) ?: placeFix(t, bare, out, null, id()))?.let { out += it } }
    put("bath", f.bath); put(if (f.cabin) "cab" else "sh", f.shower); put("wc", f.wc); put(if (f.small) "bsm" else "bs", f.basin); put("sink", f.sink); put("wm", f.wm); put("dw", f.dw)
    put("wh", f.wh); put("gb", f.gb); put("tr", f.tr)
    if (f.rad > 0) {
        val w = c.wall("C") ?: c.g.walls.last()
        val secs = ceil(radSections(c.areaM2) / f.rad.toDouble()).toInt().coerceAtLeast(3)
        repeat(f.rad.coerceIn(0, 6)) { i ->
            val rw = radWidth(secs)
            fixSpot(c, "rad", w, w.len * (i + 1) / (f.rad + 1), rw, out, null)?.let { out += newFix(id(), "rad", c, w, it, width = rw) }
        }
    }
    if (f.ufh && out.none { it.t == "manif" }) placeFix("manif", c, out, null, id())?.let { out += it }
    return out
}

/** What a typed room's counts ask for that does not fit in it (type → how many), e.g. a 1,7 m bath in a 1,2 m room. */
fun freeMissing(f: PlFree, placed: List<PlFix>): Map<String, Int> {
    val want = linkedMapOf("bath" to f.bath, (if (f.cabin) "cab" else "sh") to f.shower, "wc" to f.wc, (if (f.small) "bsm" else "bs") to f.basin, "sink" to f.sink,
        "wm" to f.wm, "dw" to f.dw, "wh" to f.wh, "gb" to f.gb, "tr" to f.tr)
    return want.mapValues { (t, n) -> n.coerceIn(0, 6) - placed.count { it.t == t } }.filterValues { it > 0 }
}

/** A kit's counts for a room typed by size. */
fun freeOf(k: PKit, o: POpts, id: String, name: String, L: Int, W: Int, H: Int): PlFree {
    val ts = kitTypes(k, o)
    fun cnt(vararg t: String) = ts.count { it in t }
    return PlFree(id, name, if (k.kind == "heat") "room" else k.kind, L, W, H, wc = cnt("wc"), basin = cnt("bs", "bsm"), bath = cnt("bath"), shower = cnt("sh", "cab"),
        sink = cnt("sink"), wm = cnt("wm"), dw = cnt("dw"), wh = cnt("wh"), gb = cnt("gb"), rad = if (o.rad) 1 else 0, ufh = o.ufh, kit = k.id,
        // what the kit chose stays: a towel rail, a hand basin (cold only), a shower cabin
        tr = cnt("tr"), small = cnt("bsm") > 0 && cnt("bs") == 0, cabin = cnt("cab") > 0 && cnt("sh") == 0)
}

/* ---------------- the room's own marks ---------------- */

/** The room's water and drain marked on its walls taken in as loose outlets (once each): cold, hot, and a drain 50 or 110. */
fun fromSitePoints(c: PCtx, id: () -> String): List<PlPoint> = c.room.points.filter { it.t in SITE_WATER && it.id !in c.pr.seen }.mapNotNull { x ->
    if (c.wall(x.wall) == null) null
    else PlPoint(id(), if (x.t == "sewer") "drain" else x.t, c.id, x.wall, x.off, x.h.coerceIn(30, max(30, c.H - 50)), if (x.t == "sewer") drainD(x.d) else 0, from = x.id)
}

/** The plan point of an outlet on its wall's face. */
fun planOf(c: PCtx, wall: String, off: Int): V2? = c.wall(wall)?.at(off.toDouble())

/** The middle of a room's floor. */
fun centre(c: PCtx) = centreOf(c.g.floor)

/** The site point types a plumber's 3D draws as its own outlets (the room's marks are taken in). */
fun isWater(x: SitePoint) = x.t in SITE_WATER
