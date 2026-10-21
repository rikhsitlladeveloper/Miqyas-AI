package uz.metrx.app.furniture

import uz.metrx.app.data.Room
import uz.metrx.app.geo.walls
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/*
 * Placing furniture by dragging it on the room's plan: the walls seen from above, where each piece stands on the
 * floor or hangs on a wall, and what it gets in the way of (another piece, a door's swing, a window).
 */

/** A point or a direction on the room's plan, mm. */
data class PlanPt(val x: Double, val y: Double) {
    operator fun plus(o: PlanPt) = PlanPt(x + o.x, y + o.y)
    operator fun minus(o: PlanPt) = PlanPt(x - o.x, y - o.y)
    operator fun times(k: Double) = PlanPt(x * k, y * k)
    infix fun dot(o: PlanPt) = x * o.x + y * o.y
}

/** A wall on the plan: from [p0] to [p1], [u] along it, [n] into the room, [len] mm. */
class PlanWall(val id: String, val p0: PlanPt, val p1: PlanPt, val u: PlanPt, val n: PlanPt, val len: Double) {
    fun at(a: Double, d: Double) = p0 + u * a + n * d
    fun along(q: PlanPt) = (q - p0) dot u
    /** How far [q] is from the wall itself (not its line). */
    fun dist(q: PlanPt): Double { val c = at(along(q).coerceIn(0.0, len), 0.0); return hypot(q.x - c.x, q.y - c.y) }
}

/** The room's walls on the plan, each with its into-the-room side. */
fun planWalls(r: Room, snap: Boolean): List<PlanWall> {
    val ws = walls(r, snap)
    val poly = ws.map { PlanPt(it.p0.x, it.p0.y) }
    return ws.map { w ->
        val p0 = PlanPt(w.p0.x, w.p0.y); val p1 = PlanPt(w.p1.x, w.p1.y)
        val l = hypot(p1.x - p0.x, p1.y - p0.y).coerceAtLeast(1.0)
        val u = PlanPt((p1.x - p0.x) / l, (p1.y - p0.y) / l)
        val n = PlanPt(-u.y, u.x).let { if (inside(poly, p0 + u * (l / 2) + it * 20.0)) it else it * -1.0 }
        PlanWall(w.id, p0, p1, u, n, l)
    }
}

/** Whether [q] is inside the polygon [poly]. */
fun inside(poly: List<PlanPt>, q: PlanPt): Boolean {
    var c = false
    for (i in poly.indices) {
        val a = poly[i]; val b = poly[(i + 1) % poly.size]
        if ((a.y > q.y) != (b.y > q.y) && q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x) c = !c
    }
    return c
}

/** Where a piece stands on the plan: [o] its back's left end, [u] along its back, [n] out of its front. */
data class Frame(val o: PlanPt, val u: PlanPt, val n: PlanPt)

/** The plan frame of [p] (the same turn as the 3D's poseBasis). */
fun frameOf(walls: List<PlanWall>, p: Pose): Frame? {
    val w = walls.firstOrNull { it.id == p.ref } ?: return null
    val r = Math.toRadians(p.deg.toDouble()); val c = cos(r); val s = sin(r)
    return Frame(w.at(p.a.toDouble(), p.n.toDouble()), w.u * c + w.n * s, w.n * c - w.u * s)
}

/** The pose of frame [fr] measured from wall [ref], to the millimetre and the degree. */
fun poseOf(walls: List<PlanWall>, ref: String, fr: Frame): Pose {
    val w = walls.first { it.id == ref }
    val d = fr.o - w.p0
    val deg = Math.toDegrees(atan2(fr.u dot w.n, fr.u dot w.u)).roundToInt()
    return Pose(ref, (d dot w.u).roundToInt(), (d dot w.n).roundToInt(), (deg % 360 + 360) % 360)
}

/** [fr] turned by [delta] degrees about the middle of a [w] × [d] box. */
fun turned(fr: Frame, w: Double, d: Double, delta: Int): Frame {
    val r = Math.toRadians(delta.toDouble()); val c = cos(r); val s = sin(r)
    val u = fr.u * c + fr.n * s; val n = fr.n * c - fr.u * s
    val mid = fr.o + fr.u * (w / 2) + fr.n * (d / 2)
    return Frame(mid - u * (w / 2) - n * (d / 2), u, n)
}

/**
 * What a piece covers: the box [pts] from [lo] to [hi] mm above the floor; on [wall] from [a0] to [a1] along it, or
 * free ([wall] null); [floor] it stands on the floor (wall units hang); [island] it is the kitchen's island.
 */
class Foot(val pts: List<PlanPt>, val lo: Int, val hi: Int, val wall: String?, val a0: Double, val a1: Double, val floor: Boolean, val island: Boolean = false)

private fun box(fr: Frame, a0: Double, a1: Double, d: Double) =
    listOf(fr.o + fr.u * a0, fr.o + fr.u * a1, fr.o + fr.u * a1 + fr.n * d, fr.o + fr.u * a0 + fr.n * d)

private fun wallFrame(w: PlanWall) = Frame(w.p0, w.u, w.n)

/** The frame of a piece's main part: a wardrobe or cabinet where it stands, a kitchen's first side from where it starts. */
fun mainFrame(f: Furniture, walls: List<PlanWall>): Frame? {
    if (f.kind == "wardrobe") {
        f.pose?.let { return frameOf(walls, it) }
        val m = wardOfF(f) ?: return null
        return walls.firstOrNull { it.id == m.wall }?.let { w -> Frame(w.at(m.x.toDouble(), 0.0), w.u, w.n) }
    }
    val w = walls.firstOrNull { it.id == f.walls.firstOrNull { id -> id != ISLAND } } ?: return null
    return Frame(w.at(leadOf(f).toDouble(), 0.0), w.u, w.n)
}

/** The island's pose: where it was dragged, else its usual place in front of the first side. */
fun islandPoseIn(f: Furniture, walls: List<PlanWall>): Pose? {
    if (ISLAND !in f.walls) return null
    f.pose?.let { return it }
    return walls.firstOrNull { it.id == f.walls.firstOrNull { id -> id != ISLAND } }?.let { islandPose(f, it.len.roundToInt()) }
}

/** Everything [f] covers in the room: a cabinet's box, a kitchen's lower row, tall units and wall units on each side, its island. */
fun footsOf(f: Furniture, walls: List<PlanWall>, ws0: Workshop): List<Foot> {
    val ws = wsOf(f, ws0)
    val out = ArrayList<Foot>()
    if (f.kind == "wardrobe") {
        val m = wardOfF(f) ?: return out
        val hi = outerH(m, ws)
        val p = f.pose
        if (p != null) frameOf(walls, p)?.let { out += Foot(box(it, 0.0, m.w.toDouble(), m.d.toDouble()), 0, hi, null, 0.0, 0.0, true) }
        else walls.firstOrNull { it.id == m.wall }?.let { w ->
            val a0 = m.x.toDouble(); val a1 = (m.x + m.w).toDouble()
            out += Foot(box(wallFrame(w), a0, a1, m.d.toDouble()), 0, hi, w.id, a0, a1, true)
        }
        return out
    }
    f.walls.filter { it != ISLAND }.forEach { id ->
        val w = walls.firstOrNull { it.id == id } ?: return@forEach
        // empty stretches (before a corner kitchen, over a window) take no room; a dishwasher is under the worktop
        val ms = f.modules.filter { it.wall == id && !(it.type == "gap" && it.app != "dishwasher" && it.app != "fridge") }
        fun row(sel: List<Module>, d: Int, lo: Int, hi: Int, floor: Boolean) {
            if (sel.isEmpty()) return
            val a0 = sel.minOf { it.x }.toDouble(); val a1 = sel.maxOf { it.x + it.w }.toDouble()
            out += Foot(box(wallFrame(w), a0, a1, d.toDouble()), lo, hi, id, a0, a1, floor)
        }
        // the lower row under its worktop, 600 deep; tall units and a free-standing fridge their own
        row(ms.filter { !isUpper(it) && it.type != "tall" && it.app != "fridge" }, 600, 0, worktopTop(ws), true)
        ms.filter { it.type == "tall" || it.app == "fridge" }.forEach { row(listOf(it), it.d, 0, it.elev + it.h, true) }
        val up = ms.filter { isUpper(it) }
        if (up.isNotEmpty()) row(up, up.maxOf { it.d }, up.minOf { it.elev }, up.maxOf { it.elev + it.h }, false)
    }
    islandPoseIn(f, walls)?.let { frameOf(walls, it) }?.let { fr ->
        // its worktop reaches 318 mm past its back, for sitting at
        val l = islandLen(f).toDouble()
        out += Foot(listOf(fr.o - fr.n * 318.0, fr.o + fr.u * l - fr.n * 318.0, fr.o + fr.u * l + fr.n * 600.0, fr.o + fr.n * 600.0), 0, worktopTop(ws), null, 0.0, 0.0, true, island = true)
    }
    return out
}

/** Whether two convex boxes overlap by more than a few millimetres (pieces side by side only touch). */
fun overlaps(a: List<PlanPt>, b: List<PlanPt>, eps: Double = 5.0): Boolean {
    for (poly in listOf(a, b)) for (i in poly.indices) {
        val e = poly[(i + 1) % poly.size] - poly[i]
        val ax = PlanPt(-e.y, e.x).let { val l = hypot(it.x, it.y); if (l < 1e-9) return@let null else it * (1 / l) } ?: continue
        val pa = a.map { it dot ax }; val pb = b.map { it dot ax }
        if (min(pa.max(), pb.max()) - max(pa.min(), pb.min()) <= eps) return false
    }
    return true
}

/**
 * What [f] gets in the way of where it stands: out of the room, on another piece of [others], in a door's swing, in
 * front of a window. It may stay there; the plan shows it red and says why.
 */
fun placeWarnings(f: Furniture, others: List<Furniture>, room: Room, walls: List<PlanWall>, ws: Workshop): List<FitIssue> {
    val mine = footsOf(f, walls, ws)
    val out = ArrayList<FitIssue>()
    val poly = walls.map { it.p0 }
    if (mine.any { ft -> ft.wall == null && ft.pts.any { q -> !inside(poly, q) && walls.minOf { it.dist(q) } > 5 } })
        out += FitIssue("fz.outside", mapOf("n" to f.name))
    others.forEach { o ->
        val theirs = footsOf(o, walls, ws)
        if (mine.any { a -> theirs.any { b -> a.lo < b.hi && b.lo < a.hi && overlaps(a.pts, b.pts) } }) out += FitIssue("fz.hitPiece", mapOf("n" to o.name))
    }
    room.openings.forEach { op ->
        val w = walls.firstOrNull { it.id == op.wall } ?: return@forEach
        val a0 = op.off.toDouble(); val a1 = (op.off + op.w).toDouble()
        val hit = if (op.type == "door") box(wallFrame(w), a0, a1, op.w.toDouble()).let { swing -> mine.any { it.floor && overlaps(it.pts, swing) } }
            else mine.any { it.wall == op.wall && min(it.a1, a1) - max(it.a0, a0) > 20 && it.hi > op.sill + 20 && it.lo < op.sill + op.h }
        if (hit) out += FitIssue(if (op.type == "door") "fz.hitDoor" else "fz.hitWin", mapOf("w" to op.wall))
    }
    return out.distinct()
}
