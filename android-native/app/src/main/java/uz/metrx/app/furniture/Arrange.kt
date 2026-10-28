package uz.metrx.app.furniture

import uz.metrx.app.data.Room
import uz.metrx.app.geo.Seg
import uz.metrx.app.geo.V2
import uz.metrx.app.geo.doorZones
import uz.metrx.app.geo.pieceGeo
import uz.metrx.app.geo.polySegs
import uz.metrx.app.geo.rayHit
import uz.metrx.app.geo.roomCen
import uz.metrx.app.geo.roomHOf
import uz.metrx.app.geo.sat
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/*
 * "Mebel joylash" (founder-approved mockup v3, 28 Oct 2026): any piece stands with its back on a wall (it slides along
 * it with magnets and moves to another wall brought within 0,5 m) or free in the room (a centre and a turn: dragged,
 * turned in 15° steps, stuck flush within 60 mm of a wall or another piece). Ports of the mockup's FD, fGeo, fIssues,
 * placeWall, fFlush and fGaps on the furniture core's own boxes (Placing.kt footsOf). Pure Kotlin (ArrangeTest).
 */

/** A free piece sticks flush to a wall or another piece within this, mm; a passage under [F_PASS] is narrow; up to [F_TOUCH] counts as touching. */
const val F_FLUSH = 60
const val F_PASS = 700
const val F_TOUCH = 25
/** The rotate handle's step, degrees. */
const val F_ROT = 15
/** A wall piece brought this close to another wall moves onto it, mm (and this far from its own). */
const val F_SWITCH = 500
const val F_LEAVE = 700

fun PlanPt.v() = V2(x, y)
fun V2.pp() = PlanPt(x, y)

/** The plan's direction [deg] from x, and the side that is the front (local y). */
fun axisOf(deg: Double) = PlanPt(cos(Math.toRadians(deg)), sin(Math.toRadians(deg)))
fun frontOf(u: PlanPt) = PlanPt(-u.y, u.x)

/**
 * A piece as one box on the plan: its back's left end [o], [u] along its back, [n] out of its front, [w] × [d] mm.
 * The run of a cabinet (all its boxes), a kitchen's first side, an island.
 */
class Body(val o: PlanPt, val u: PlanPt, val n: PlanPt, val w: Double, val d: Double) {
    val c: PlanPt get() = o + u * (w / 2) + n * (d / 2)
    val P: List<PlanPt> get() = listOf(o, o + u * w, o + u * w + n * d, o + n * d)
    /** Its turn on the plan, degrees 0–359. */
    val ang: Int get() = ((Math.toDegrees(atan2(u.y, u.x)).roundToInt() % 360) + 360) % 360
    fun inset(k: Double) = listOf(o + u * k + n * k, o + u * (w - k) + n * k, o + u * (w - k) + n * (d - k), o + u * k + n * (d - k))
}

/** The box round [pts] in the frame [fr]. */
private fun bodyIn(fr: Frame, pts: List<PlanPt>): Body? {
    if (pts.isEmpty()) return null
    val a = pts.map { (it - fr.o) dot fr.u }; val n = pts.map { (it - fr.o) dot fr.n }
    return Body(fr.o + fr.u * a.min() + fr.n * n.min(), fr.u, fr.n, a.max() - a.min(), n.max() - n.min())
}

/** The frame a free piece's pose is measured in: its main box's back-left end (Placing.kt footsOf). */
fun poseFrame(f: Furniture, walls: List<PlanWall>): Frame? {
    if (f.kind != "wardrobe") return null
    f.pose?.let { return frameOf(walls, it) }
    val m = wardOfF(f) ?: return null
    val w = walls.firstOrNull { it.id == m.wall } ?: return null
    return Frame(w.at(m.x.toDouble(), 0.0), w.u, w.n)
}

/** The piece's box: a cabinet's run (every box on the floor, else every box), a kitchen's first side's lower row. */
fun bodyOf(f: Furniture, walls: List<PlanWall>, ws: Workshop): Body? {
    val feet = footsOf(f, walls, ws).filter { !it.island }
    if (f.kind == "wardrobe") {
        val fr = poseFrame(f, walls) ?: return null
        val sel = feet.filter { it.floor }.ifEmpty { feet }
        return bodyIn(fr, sel.flatMap { it.pts })
    }
    val first = f.walls.firstOrNull { it != ISLAND } ?: return null
    val w = walls.firstOrNull { it.id == first } ?: return null
    val row = feet.filter { it.wall == first && it.floor }.ifEmpty { feet.filter { it.wall == first } }
    return bodyIn(Frame(w.p0, w.u, w.n), row.flatMap { it.pts })
}

/** A kitchen's island as a box (its worktop with the finished back), with the frame its pose is in. */
fun islandBody(f: Furniture, walls: List<PlanWall>, ws: Workshop): Pair<Body, Frame>? {
    val p = islandPoseIn(f, walls) ?: return null
    val fr = frameOf(walls, p) ?: return null
    val ft = footsOf(f, walls, ws).firstOrNull { it.island } ?: return null
    return (bodyIn(fr, ft.pts) ?: return null) to fr
}

/** Whether the piece stands free (a pose), not with its back on a wall. */
fun isFree(f: Furniture) = f.kind == "wardrobe" && f.pose != null

/**
 * The pose that puts the piece's box [b0] (in its frame [fr0]) with its centre on [c], turned [deg] on the plan;
 * measured from wall [ref].
 */
fun poseAt(walls: List<PlanWall>, ref: String, b0: Body, fr0: Frame, c: PlanPt, deg: Double): Pose {
    val la = (fr0.o - b0.o) dot b0.u; val ln = (fr0.o - b0.o) dot b0.n
    val u = axisOf(deg); val n = frontOf(u)
    // the frame keeps its handedness: a room drawn the other way round has its front on the other side
    val n2 = if ((fr0.n dot frontOf(fr0.u)) < 0) n * -1.0 else n
    val o = c - u * (b0.w / 2) - n2 * (b0.d / 2) + u * la + n2 * ln
    return poseOf(walls, ref, Frame(o, u, n2))
}

/* ---------------- the checks ---------------- */

/** Why a piece is red: [key] its words (fp.r.*), the names in [vars]. */
data class FRed(val key: String, val vars: Map<String, Any> = emptyMap())

/** A narrow passage: [gap] mm from [p0] (the piece) to [p1]. */
data class FYel(val gap: Int, val p0: PlanPt, val p1: PlanPt)

/** The checks of every piece by id: red ones with why, yellow ones with their narrow passages. */
class FChecks(val red: Map<String, FRed>, val yel: Map<String, List<FYel>>)

/** The obstacles' sides: the outer walls, the inner walls' bodies, [feet] (but those of [ex]). */
fun planSegs(room: Room, walls: List<PlanWall>, feet: Map<String, List<Foot>>, ex: String?, snap: Boolean): List<Seg> {
    val out = ArrayList<Seg>()
    walls.filter { !it.inner }.forEach { out += Seg(it.p0.v(), it.p1.v(), "o:" + it.id) }
    val rh = roomHOf(room)
    room.inner.forEach { p -> pieceGeo(p, rh).R.forEach { polySegs(it, "p:" + p.id, out) } }
    feet.forEach { (id, fs) -> if (id != ex) fs.filter { it.floor }.forEach { polySegs(it.pts.map { q -> q.v() }, "f:$id", out) } }
    return out
}

private fun crosses(a: V2, b: V2, c: V2, d: V2): Boolean {
    fun o(p: V2, q: V2, r: V2) = (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
    val d1 = o(c, d, a); val d2 = o(c, d, b); val d3 = o(a, b, c); val d4 = o(a, b, d)
    return ((d1 > 1e-6 && d2 < -1e-6) || (d1 < -1e-6 && d2 > 1e-6)) && ((d3 > 1e-6 && d4 < -1e-6) || (d3 < -1e-6 && d4 > 1e-6))
}

/** What makes the box [P] (inset) red: another piece's feet, a door's room, an inner wall, the room's walls; null when free. */
fun redOf(room: Room, walls: List<PlanWall>, P: List<PlanPt>, lo: Int, hi: Int, floor: Boolean, others: Map<String, Pair<String, List<Foot>>>,
          zones: List<uz.metrx.app.geo.DoorZone>, snap: Boolean): FRed? {
    val q = P.map { it.v() }
    others.forEach { (_, nf) -> if (nf.second.any { b -> lo < b.hi && b.lo < hi && sat(q, b.pts.map { it.v() }) }) return FRed("fp.r.piece", mapOf("n" to nf.first)) }
    if (floor) zones.forEach { z -> if (sat(q, z.poly)) return FRed(if (z.sw) "fp.r.door" else "fp.r.doorway", mapOf("w" to z.wall)) }
    val rh = roomHOf(room)
    room.inner.forEach { p ->
        val g = pieceGeo(p, rh)
        if (lo < g.H && g.R.any { sat(q, it) }) return FRed("fp.r.iw", mapOf("k" to p.k))
    }
    val outer = walls.filter { !it.inner }
    val poly = outer.map { it.p0 }
    if (P.any { !inside(poly, it) && outer.minOf { w -> w.dist(it) } > 5 } ||
        outer.any { w -> (P.indices).any { i -> crosses(P[i].v(), P[(i + 1) % P.size].v(), w.p0.v(), w.p1.v()) } }) return FRed("fp.r.out")
    return null
}

/**
 * The mockup's fIssues: red when a piece overlaps another piece or an inner wall, stands in a door's room or goes
 * through a wall; yellow when a passage under 700 mm is left to a wall or another piece (25 mm or less: touching),
 * measured from the middle and both ends of each side.
 */
fun fIssues(room: Room, fs: List<Furniture>, walls: List<PlanWall>, ws: Workshop, snap: Boolean = true): FChecks {
    val feet = fs.associate { it.id to footsOf(it, walls, ws) }
    val zones = doorZones(room, snap)
    val red = LinkedHashMap<String, FRed>(); val yel = LinkedHashMap<String, List<FYel>>()
    fs.forEach { f ->
        val others = fs.filter { it.id != f.id }.associate { it.id to (it.name to feet[it.id].orEmpty()) }
        for (ft in feet[f.id].orEmpty()) {
            val P = inset(ft.pts, 6.0)
            redOf(room, walls, P, ft.lo, ft.hi, ft.floor, others, zones, snap)?.let { red[f.id] = it }
            if (red.containsKey(f.id)) break
        }
    }
    fs.forEach { f ->
        if (red.containsKey(f.id)) return@forEach
        val segs = planSegs(room, walls, feet, f.id, snap)
        val out = ArrayList<FYel>()
        feet[f.id].orEmpty().filter { it.floor }.forEach { ft -> out += passages(ft.pts, segs) }
        if (out.isNotEmpty()) yel[f.id] = out
    }
    return FChecks(red, yel)
}

/** A box's corners [k] mm in (a box of 4 corners; others as they are). */
fun inset(P: List<PlanPt>, k: Double): List<PlanPt> {
    if (P.size != 4) return P
    val u = (P[1] - P[0]).let { val l = hypot(it.x, it.y).coerceAtLeast(1e-9); it * (1 / l) }
    val n = (P[3] - P[0]).let { val l = hypot(it.x, it.y).coerceAtLeast(1e-9); it * (1 / l) }
    val kw = min(k, hypot(P[1].x - P[0].x, P[1].y - P[0].y) / 3); val kd = min(k, hypot(P[3].x - P[0].x, P[3].y - P[0].y) / 3)
    return listOf(P[0] + u * kw + n * kd, P[1] - u * kw + n * kd, P[2] - u * kw - n * kd, P[3] + u * kw - n * kd)
}

/** The narrow passages from the box [P] on each of its four sides (the nearest of its middle and both ends). */
fun passages(P: List<PlanPt>, segs: List<Seg>): List<FYel> {
    if (P.size != 4) return emptyList()
    val c = PlanPt((P[0].x + P[2].x) / 2, (P[0].y + P[2].y) / 2)
    val ex = P[1] - P[0]; val ey = P[3] - P[0]
    val w = hypot(ex.x, ex.y); val d = hypot(ey.x, ey.y)
    if (w < 1 || d < 1) return emptyList()
    val ax = ex * (1 / w); val ay = ey * (1 / d)
    val out = ArrayList<FYel>()
    listOf(Triple(ax, w / 2, ay to d / 2), Triple(ax * -1.0, w / 2, ay to d / 2), Triple(ay, d / 2, ax to w / 2), Triple(ay * -1.0, d / 2, ax to w / 2)).forEach { (dir, half, side) ->
        var best: FYel? = null
        listOf(-.4, 0.0, .4).forEach { o ->
            val org = c + side.first * (side.second * 2 * o)
            val h = rayHit(org.v(), dir.v(), segs)
            if (h.first.isFinite()) { val gap = (h.first - half).roundToInt(); if (best == null || gap < best!!.gap) best = FYel(gap, org + dir * half, org + dir * h.first) }
        }
        best?.let { if (it.gap > F_TOUCH && it.gap < F_PASS) out += it }
    }
    return out
}

/* ---------------- placing ---------------- */

/** "Devorga" (the mockup's placeWall): the nearest wall to the room's middle with a free stretch, tried from its middle outwards; [bad] when none was free. */
data class WallSpot(val wall: String, val t: Int, val bad: Boolean = false)

fun placeWall(room: Room, walls: List<PlanWall>, w: Double, d: Double, others: List<Furniture>, ws: Workshop, snap: Boolean = true): WallSpot? {
    val cen = roomCen(room, snap).pp()
    val feet = others.associate { it.id to (it.name to footsOf(it, walls, ws)) }
    val zones = doorZones(room, snap)
    val order = walls.filter { it.len >= w }.sortedBy { val m = it.at(it.len / 2, 0.0); hypot(m.x - cen.x, m.y - cen.y) }
    for (wl in order) {
        val hi = wl.len - w
        var s = 0.0
        while (s <= hi / 2 + 1) {
            for (t in listOf(hi / 2 + s, hi / 2 - s)) {
                if (t < 0 || t > hi) continue
                val b = Body(wl.at(t, 0.0), wl.u, wl.n, w, d)
                if (redOf(room, walls, b.inset(6.0), 0, 2000, true, feet, zones, snap) == null) return WallSpot(wl.id, (t / 10).roundToInt() * 10)
            }
            s += 50
        }
    }
    return order.firstOrNull()?.let { WallSpot(it.id, ((it.len - w) / 2 / 10).roundToInt() * 10, true) }
}

/** A free box flush with a wall or a piece it comes within [F_FLUSH] of (its four sides); returns its centre and whether it moved. */
fun fFlush(b: Body, segs: List<Seg>): Pair<PlanPt, Boolean> {
    var c = b.c; var mg = false
    listOf(b.u to b.w / 2, b.u * -1.0 to b.w / 2, b.n to b.d / 2, b.n * -1.0 to b.d / 2).forEach { (dir, half) ->
        val h = rayHit(c.v(), dir.v(), segs)
        if (h.first.isFinite()) { val gap = h.first - half; if (gap > .5 && gap < F_FLUSH) { c = c + dir * gap; mg = true } }
    }
    return c to mg
}

/** A gap pill of a free piece: along [dir] (its own axes), [gap] mm from [p0] on the piece to [p1]. */
data class FGap(val dir: PlanPt, val gap: Int, val p0: PlanPt, val p1: PlanPt)

/** The four gaps along the piece's own axes (right, left, front, back) to the nearest wall or piece; null where none. */
fun fGaps(b: Body, segs: List<Seg>): List<FGap?> =
    listOf(b.u to b.w / 2, b.u * -1.0 to b.w / 2, b.n to b.d / 2, b.n * -1.0 to b.d / 2).map { (dir, half) ->
        val h = rayHit(b.c.v(), dir.v(), segs)
        if (!h.first.isFinite()) null else FGap(dir, (h.first - half).roundToInt(), b.c + dir * half, b.c + dir * h.first)
    }

/** "Devorga yopishtirish": the nearest wall [w] mm long or more that the box faces (its side, not behind), and where along it the box's middle is. */
fun nearestWall(c: PlanPt, w: Double, walls: List<PlanWall>): Pair<PlanWall, Double>? {
    var best: Triple<Double, PlanWall, Double>? = null
    walls.forEach { wl ->
        if (wl.len < w) return@forEach
        val side = (c - wl.p0) dot wl.n
        if (side < -5) return@forEach
        val a = wl.along(c).coerceIn(0.0, wl.len)
        val dd = wl.dist(c)
        if (best == null || dd < best!!.first) best = Triple(dd, wl, a)
    }
    return best?.let { it.second to it.third }
}

/**
 * A wall piece dragged to [q] (mm): along its wall [cur] with the magnets (the corners and the middle within [thMm]),
 * or onto another wall when the finger is within [F_SWITCH] of it and [F_LEAVE] from its own. Returns the wall and the
 * distance from its start, and the magnet ("corner", "mid") that took it.
 */
fun slideOn(walls: List<PlanWall>, cur: String, q: PlanPt, grab: Double, w: Double, thMm: Double): Triple<String, Int, String?> {
    val f = walls.firstOrNull { it.id == cur }
    if (f != null) {
        val other = walls.filter { it.id != cur && it.len >= w }.minByOrNull { it.dist(q) }
        if (other != null && other.dist(q) < F_SWITCH && f.dist(q) > F_LEAVE) {
            val t = (other.along(q) - grab).coerceIn(0.0, max(0.0, other.len - w))
            return Triple(other.id, (t / 10).roundToInt() * 10, null)
        }
        val m = uz.metrx.app.geo.magnet(w.roundToInt(), f.len.roundToInt(), f.along(q) - grab, thMm)
        return Triple(cur, m.v, m.at)
    }
    return Triple(cur, 0, null)
}


/**
 * The room's furniture after its inner walls changed from [old] to [new]: a piece against an inner face follows the
 * face's new letter (its key stays); a cabinet whose face is gone stands free where it was (the mockup's syncFaces).
 */
fun refaced(fs: List<Furniture>, old: Room, new: Room, snap: Boolean = true): List<Furniture> {
    if (old.inner.isEmpty() && new.inner.isEmpty()) return fs
    val was = uz.metrx.app.geo.innerFaces(old, snap).associate { it.id to it.key }
    val now = uz.metrx.app.geo.innerFaces(new, snap).associate { it.key to it.id }
    val map = was.mapValues { (_, k) -> now[k] }
    if (map.all { (a, b) -> a == b }) return fs
    val ow = planWalls(old, snap)
    val ref = uz.metrx.app.geo.walls(old, snap).firstOrNull()?.id ?: "A"
    return fs.map { f ->
        if (f.roomId != old.id) return@map f
        val used = (f.walls + f.modules.mapNotNull { it.wall } + listOfNotNull(f.pose?.ref)).filter { it in map }
        if (used.isEmpty()) return@map f
        // its face gone: a cabinet stays where it stood, free (measured from the first outer wall); a kitchen keeps its letters (the checks say so)
        val gone = used.any { map[it] == null }
        if (gone && f.kind != "wardrobe") return@map f
        val pose = if (gone) poseFrame(f, ow)?.let { poseOf(ow.filter { !it.inner }, ref, it) } ?: return@map f else f.pose?.let { it.copy(ref = map[it.ref] ?: it.ref) }
        fun m(w: String) = if (w in map) map[w] ?: ref else w
        f.copy(walls = f.walls.map(::m), modules = f.modules.map { md -> md.wall?.let { md.copy(wall = m(it)) } ?: md }, pose = pose)
    }
}

/** How far apart two angles are, degrees (0–180). */
fun angDiff(a: Int, b: Int): Int { val d = abs(((a - b) % 360 + 360) % 360); return min(d, 360 - d) }
