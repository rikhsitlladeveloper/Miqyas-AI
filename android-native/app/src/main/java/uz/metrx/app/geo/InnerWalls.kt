package uz.metrx.app.geo

import uz.metrx.app.data.InnerWall
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.uid
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/*
 * Inner walls (founder-approved mockup v3, design/room-editor/mockup.html, 28 Oct 2026): partitions put inside the
 * measured outer shape from ready pieces — a straight wall, an L, a T, a low (half) wall, a column and a wall with an
 * arch. The room stays one room. Each piece's faces act as walls, lettered after the outer walls: doors, windows and
 * points go on them, furniture stands against them, the trades count them. Ports of the mockup's IWK, pieceGeo,
 * innerFaces, iwSnap, iwSides, doorZones, iwIssues and syncFaces. Pure Kotlin, unit-tested (InnerWallsTest).
 * Plan coordinates are the outer walls' (mm, y down, walls clockwise).
 */

/** A point or a direction on the plan, mm. */
data class V2(val x: Double, val y: Double) {
    operator fun plus(o: V2) = V2(x + o.x, y + o.y)
    operator fun minus(o: V2) = V2(x - o.x, y - o.y)
    operator fun times(k: Double) = V2(x * k, y * k)
    operator fun unaryMinus() = V2(-x, -y)
    infix fun dot(o: V2) = x * o.x + y * o.y
    fun len() = hypot(x, y)
    fun unit(): V2 { val l = len(); return if (l < 1e-12) this else V2(x / l, y / l) }
}

fun Pt.v() = V2(x, y)
fun V2.pt() = Pt(x, y)
private fun mid(a: V2, b: V2) = V2((a.x + b.x) / 2, (a.y + b.y) / 2)
private fun dist(a: V2, b: V2) = hypot(a.x - b.x, a.y - b.y)

/* ---------------- the ready pieces ---------------- */

/** A ready piece's standard sizes (Tasdiqlash: To‘g‘ri 2 000; L 2 000 + 1 200; T 2 400 + 1 200; Yarim 1 600, h 1 100; Ustun 400; Arka 2 400, o‘tish 900 × 2 100). */
data class IwKind(val k: String, val len: Int, val len2: Int = 0, val h: Int = 0, val opW: Int = 0, val opH: Int = 0)

/** The "Devor qo‘shish" window's cards, in order. */
val IW_KINDS = listOf("straight", "L", "T", "half", "col", "arch")
val IWK: Map<String, IwKind> = mapOf(
    "straight" to IwKind("straight", 2000),
    "L" to IwKind("L", 2000, 1200),
    "T" to IwKind("T", 2400, 1200),
    "half" to IwKind("half", 1600, h = 1100),
    "col" to IwKind("col", 400),
    "arch" to IwKind("arch", 2400, opW = 900, opH = 2100)
)

/** An end that comes this close to a wall stretches (or shrinks) to touch it, mm. */
const val IW_MAG = 300
/** The thickness chips (standard 100), a half wall's heights, an arch's passage widths, a column's sizes. */
val IW_TH = listOf(80, 100, 120, 250)
val IW_HH = listOf(900, 1000, 1100, 1200)
val IW_OPW = listOf(800, 900, 1200)
val IW_COL = listOf(300, 400, 500)

/** A direction [a] degrees from the plan's x (exact at the quarter turns). */
fun dirOf(a: Int): V2 = when (((a % 360) + 360) % 360) {
    0 -> V2(1.0, 0.0); 90 -> V2(0.0, 1.0); 180 -> V2(-1.0, 0.0); 270 -> V2(0.0, -1.0)
    else -> { val r = a * PI / 180; V2(cos(r), sin(r)) }
}

/** A band along p0 → p1 between [t1] and [t2] off it along [n]. */
fun band(p0: V2, p1: V2, n: V2, t1: Double, t2: Double) = listOf(p0 + n * t1, p1 + n * t1, p1 + n * t2, p0 + n * t2)

/** One face of a piece: from [a] to [b], facing [look], [h] mm high. */
class PFace(val a: V2, val b: V2, val look: V2, val h: Int)

/**
 * A piece in plan coordinates: [R] its body (convex parts, for the plan, the checks and 3D), [F] its faces that act as
 * walls, its direction [d] and side [n], centre [c], ends [P0] and [P1], height [H], an arch's passage [gap].
 */
class PieceGeo(val R: List<List<V2>>, val F: List<PFace>, val d: V2, val n: V2, val c: V2, val P0: V2, val P1: V2, val H: Int, val gap: Pair<V2, V2>?)

/** How high a piece stands in a room [rh] mm high: a half wall its own height, the rest to the ceiling. */
fun pieceH(p: InnerWall, rh: Int) = if (p.k == "half") (if (p.h > 0) p.h else 1100) else rh

/**
 * The mockup's pieceGeo: the body and the faces (straight, half, arch: front and back; L: 4; T: 5; a column none).
 * Every face runs left to right as seen standing in front of it (its side [PFace.look] is to the left of its run on the
 * plan, as the outer walls'), so a door's distance and a cabinet's boxes read the same way on every wall.
 */
fun pieceGeo(p: InnerWall, rh: Int): PieceGeo {
    val d = dirOf(p.ang); val n = V2(-d.y, d.x); val c = V2(p.x.toDouble(), p.y.toDouble()); val t = p.th / 2.0; val L = p.len.toDouble()
    val P0 = c + d * (-L / 2); val P1 = c + d * (L / 2); val H = pieceH(p, rh)
    val R = ArrayList<List<V2>>(); val F = ArrayList<PFace>(); var gap: Pair<V2, V2>? = null
    fun face(a: V2, b: V2, look: V2) { if (dist(a, b) >= 50) F += PFace(a, b, look, H) }
    if (p.k == "col") {
        val s = L / 2
        if (p.round) R += (0 until 20).map { i -> val an = i / 20.0 * PI * 2; V2(c.x + cos(an) * s, c.y + sin(an) * s) }
        else R += listOf(V2(c.x - s, c.y - s), V2(c.x + s, c.y - s), V2(c.x + s, c.y + s), V2(c.x - s, c.y + s))
        return PieceGeo(R, F, d, n, c, P0, P1, H, null)
    }
    if (p.k == "arch") {
        val w = min(p.opW.toDouble(), L - 200).coerceAtLeast(0.0)
        val g0 = c + d * (-w / 2); val g1 = c + d * (w / 2)
        gap = g0 to g1
        R += band(P0, g0, n, t, -t); R += band(g1, P1, n, t, -t)
    } else R += band(P0, P1, n, t, -t)
    val l2 = p.len2.toDouble()
    when (p.k) {
        "L" -> if (!p.mir) {
            val e = P1 + d * (-2 * t)
            R += listOf(e + n * t, P1 + n * t, P1 + n * (t + l2), e + n * (t + l2))
            face(P0 + n * t, e + n * t, n); face(P1 + n * (-t), P0 + n * (-t), -n); face(P1 + n * (t + l2), P1 + n * (-t), d); face(e + n * t, e + n * (t + l2), -d)
        } else {
            // the arm at the start: an L seen in a mirror
            val e = P0 + d * (2 * t)
            R += listOf(P0 + n * t, e + n * t, e + n * (t + l2), P0 + n * (t + l2))
            face(e + n * t, P1 + n * t, n); face(P1 + n * (-t), P0 + n * (-t), -n); face(P0 + n * (-t), P0 + n * (t + l2), -d); face(e + n * (t + l2), e + n * t, d)
        }
        "T" -> {
            val l = c + d * (-t); val rr = c + d * t
            R += listOf(l + n * t, rr + n * t, rr + n * (t + l2), l + n * (t + l2))
            face(P0 + n * t, l + n * t, n); face(rr + n * t, P1 + n * t, n); face(P1 + n * (-t), P0 + n * (-t), -n); face(rr + n * (t + l2), rr + n * t, d); face(l + n * t, l + n * (t + l2), -d)
        }
        else -> { face(P0 + n * t, P1 + n * t, n); face(P1 + n * (-t), P0 + n * (-t), -n) }
    }
    return PieceGeo(R, F, d, n, c, P0, P1, H, gap)
}

/** A new piece of kind [k] centred on [c] in a room [rh] mm high: the standard sizes, thickness 100 (a column 400 × 400). */
fun newPiece(k: String, c: V2, rh: Int, id: String = "w" + uid()): InnerWall {
    val D = IWK[k] ?: IWK.getValue("straight")
    return InnerWall(id, k, c.x.roundToInt(), c.y.roundToInt(), 0, D.len, D.len2, if (k == "col") 400 else 100,
        if (k == "half") D.h else 0, false, if (k == "arch") uz.metrx.app.data.IwOp(D.opW, min(D.opH, rh - 100)) else null)
}

/* ---------------- faces as walls ---------------- */

/** The wall letter at index [i]: the polygon letters (no H, I, O, T, X), then A2, B2…. */
fun wallLetter(i: Int): String { val n = SK_LETTERS.length; return if (i < n) SK_LETTERS[i].toString() else SK_LETTERS[i % n].toString() + (i / n + 1) }

/** An inner face as a wall: letter [id], [key] "<piece>:<j>", piece [pid] of kind [pk], [a] → [b] facing [look], [h] high, [th] the piece's thickness. */
data class InFace(val id: String, val key: String, val pid: String, val pk: String, val a: V2, val b: V2, val look: V2, val h: Int, val th: Int) {
    val len: Int get() = dist(a, b).roundToInt()
    val u: V2 get() = (b - a).unit()
}

fun roomHOf(r: Room) = r.dim("H").v ?: 2700

/** Every inner face of [r], lettered after its outer walls, in the pieces' order (front, back, then the arm's faces). */
fun innerFaces(r: Room, snap: Boolean = true): List<InFace> {
    if (r.inner.isEmpty()) return emptyList()
    val n0 = walls(r, snap).size; val rh = roomHOf(r)
    val out = ArrayList<InFace>()
    r.inner.forEach { p -> pieceGeo(p, rh).F.forEachIndexed { j, f -> out += InFace(wallLetter(n0 + out.size), "${p.id}:$j", p.id, p.k, f.a, f.b, f.look, f.h, p.th) } }
    return out
}

/** The outer walls and the inner faces (a face's [Wall.dimKey] is its key, [Wall.status] "inner"). */
fun allWalls(r: Room, snap: Boolean = true): List<Wall> = walls(r, snap) + innerFaces(r, snap).map { f -> Wall(f.id, 0, f.len, f.key, true, f.a.pt(), f.b.pt(), "inner") }

/** Whether wall [id] of [r] is an inner face. */
fun isInnerWall(r: Room, id: String, snap: Boolean = true) = r.inner.isNotEmpty() && walls(r, snap).none { it.id == id } && innerFaces(r, snap).any { it.id == id }

/** A wall's height: an inner face its piece's (a half wall 1 100), an outer wall the room's. */
fun wallHOf(r: Room, id: String, snap: Boolean = true): Int = if (r.inner.isEmpty()) roomHOf(r) else innerFaces(r, snap).firstOrNull { it.id == id }?.h ?: roomHOf(r)

/**
 * The mockup's syncFaces: items on inner faces keep their face by key, so deleting a piece or changing the outer shape
 * re-letters them; an item whose face is gone goes too. An item on a face letter without a key yet takes that face's key.
 * Items on outer walls (or walls not known) stay as they are.
 */
fun syncFaces(r: Room, snap: Boolean = true): Room {
    val outer = walls(r, snap).map { it.id }.toSet()
    val fs = innerFaces(r, snap)
    if (fs.isEmpty() && r.openings.none { it.fk.isNotEmpty() } && r.points.none { it.fk.isNotEmpty() }) return r
    val byKey = fs.associateBy { it.key }; val byId = fs.associateBy { it.id }
    // null: the item goes; else its wall and key
    fun fix(wall: String, fk: String): Pair<String, String>? = when {
        fk.isNotEmpty() -> byKey[fk]?.let { it.id to fk }
        wall in outer -> wall to ""
        else -> byId[wall]?.let { it.id to it.key } ?: (wall to "")
    }
    val ops = r.openings.mapNotNull { o -> fix(o.wall, o.fk)?.let { (w, k) -> if (w == o.wall && k == o.fk) o else o.copy(wall = w, fk = k) } }
    val pts = r.points.mapNotNull { p -> fix(p.wall, p.fk)?.let { (w, k) -> if (w == p.wall && k == p.fk) p else p.copy(wall = w, fk = k) } }
    return if (ops == r.openings && pts == r.points) r else r.copy(openings = ops, points = pts)
}

/**
 * The room as it is saved (the same as the iPhone's): a door, window or point on an inner face names the face's key
 * ("<piece>:<n>") as its wall. In the app it keeps the face's letter in [Opening.wall] (every screen shows that) and the
 * key in [Opening.fk].
 */
fun roomToDisk(r: Room): Room {
    if (r.openings.none { it.fk.isNotEmpty() } && r.points.none { it.fk.isNotEmpty() }) return r
    return r.copy(openings = r.openings.map { if (it.fk.isNotEmpty()) it.copy(wall = it.fk, fk = "") else it },
        points = r.points.map { if (it.fk.isNotEmpty()) it.copy(wall = it.fk, fk = "") else it })
}

/** A saved room back in the app: an item whose wall is a face's key gets that face's letter (and keeps the key). */
fun roomFromDisk(r: Room, snap: Boolean = true): Room {
    if (r.openings.none { ':' in it.wall } && r.points.none { ':' in it.wall }) return r
    return syncFaces(r.copy(openings = r.openings.map { if (':' in it.wall) it.copy(fk = it.wall) else it },
        points = r.points.map { if (':' in it.wall) it.copy(fk = it.wall) else it }), snap)
}

/** The letters of the inner faces by key (for moving furniture that stands against them when letters change). */
fun faceLetters(r: Room, snap: Boolean = true): Map<String, String> = innerFaces(r, snap).associate { it.key to it.id }

/* ---------------- frames, overlap, rays ---------------- */

/** A wall on the plan with its inward side: an outer wall ([face] null) or an inner face (its [face]). */
class WFrame(val id: String, val a: V2, val b: V2, val u: V2, val n: V2, val L: Double, val face: InFace? = null) {
    fun at(t: Double, off: Double = 0.0) = a + u * t + n * off
}

/** Whether [q] is inside the polygon [poly]. */
fun pip(q: V2, poly: List<V2>): Boolean {
    var c = false; var j = poly.size - 1
    for (i in poly.indices) {
        val a = poly[i]; val b = poly[j]
        if ((a.y > q.y) != (b.y > q.y) && q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x) c = !c
        j = i
    }
    return c
}

/** The outer walls (inward normals) and the inner faces (facing their side). */
fun wallFrames(r: Room, snap: Boolean = true): List<WFrame> {
    val ws = walls(r, snap)
    val poly = ws.map { it.p0.v() }
    val out = ws.map { w ->
        val a = w.p0.v(); val b = w.p1.v(); val l = max(dist(a, b), 1e-6); val u = (b - a) * (1 / l)
        var n = V2(-u.y, u.x)
        if (!pip(mid(a, b) + n * max(5.0, l * .02), poly)) n = -n
        WFrame(w.id, a, b, u, n, l)
    }.toMutableList()
    innerFaces(r, snap).forEach { f -> val l = max(dist(f.a, f.b), 1e-6); out += WFrame(f.id, f.a, f.b, (f.b - f.a) * (1 / l), f.look, l, f) }
    return out
}

private fun proj(A: List<V2>, ax: V2): Pair<Double, Double> { var mn = Double.MAX_VALUE; var mx = -Double.MAX_VALUE; A.forEach { val v = it dot ax; if (v < mn) mn = v; if (v > mx) mx = v }; return mn to mx }

/** Convex overlap (separating axes) with a [tol] mm tolerance, so touching is not overlapping. */
fun sat(A: List<V2>, B: List<V2>, tol: Double = 2.0): Boolean {
    for (Q in listOf(A, B)) for (i in Q.indices) {
        val a = Q[i]; val b = Q[(i + 1) % Q.size]
        val ax = V2(b.y - a.y, a.x - b.x); val l = ax.len(); if (l < 1e-9) continue
        val n = ax * (1 / l)
        val p1 = proj(A, n); val p2 = proj(B, n)
        if (p1.second <= p2.first + tol || p2.second <= p1.first + tol) return false
    }
    return true
}

/** An obstacle's side: [ref] "o:<wall>" an outer wall, "p:<piece>" an inner wall, "f:<id>" a piece of furniture. */
class Seg(val a: V2, val b: V2, val ref: String)

/** The nearest obstacle from [o] along [dir]: its distance (∞ when none) and its ref. */
fun rayHit(o: V2, dir: V2, segs: List<Seg>): Pair<Double, String?> {
    var best = Double.POSITIVE_INFINITY; var ref: String? = null
    for (sg in segs) {
        val ex = sg.b.x - sg.a.x; val ey = sg.b.y - sg.a.y
        val den = dir.x * ey - dir.y * ex
        if (abs(den) < 1e-9) continue
        val wx = sg.a.x - o.x; val wy = sg.a.y - o.y
        val t = (wx * ey - wy * ex) / den; val u = (wx * dir.y - wy * dir.x) / den
        if (t > .5 && u >= -1e-6 && u <= 1 + 1e-6 && t < best) { best = t; ref = sg.ref }
    }
    return best to ref
}

fun polySegs(P: List<V2>, ref: String, out: MutableList<Seg>) { for (i in P.indices) out += Seg(P[i], P[(i + 1) % P.size], ref) }

/** The outer walls, the inner walls' bodies (but [exP]) and [polys] (furniture, but [exF]) as obstacle sides. */
fun obsSegs(r: Room, snap: Boolean = true, exP: String? = null, polys: Map<String, List<V2>> = emptyMap(), exF: String? = null): List<Seg> {
    val out = ArrayList<Seg>()
    walls(r, snap).forEach { w -> out += Seg(w.p0.v(), w.p1.v(), "o:" + w.id) }
    val rh = roomHOf(r)
    r.inner.forEach { p -> if (p.id != exP) pieceGeo(p, rh).R.forEach { polySegs(it, "p:" + p.id, out) } }
    polys.forEach { (id, P) -> if (id != exF) polySegs(P, "f:$id", out) }
    return out
}

/** The room's outline. */
fun outline(r: Room, snap: Boolean = true): List<V2> = walls(r, snap).map { it.p0.v() }

/* ---------------- smart snap, the live gaps ---------------- */

/** What a snap did: the piece now, the outer walls and pieces it touches (they glow green), whether it stretched. */
data class IwSnap(val p: InnerWall, val outer: List<String>, val pieces: List<String>, val str: Boolean)

/**
 * The mockup's iwSnap: an end within [IW_MAG] of a wall (outer or inner) stretches or shrinks to touch it; an L's or a
 * T's arm the same. A column does not stretch; a piece whose centre is outside the room is left as it is.
 */
fun iwSnap(r: Room, p0: InnerWall, snap: Boolean = true): IwSnap {
    if (p0.k == "col") return IwSnap(p0, emptyList(), emptyList(), false)
    val segs = obsSegs(r, snap, exP = p0.id)
    var c = V2(p0.x.toDouble(), p0.y.toDouble())
    if (!pip(c, outline(r, snap))) return IwSnap(p0, emptyList(), emptyList(), false)
    val o = ArrayList<String>(); val pc = ArrayList<String>(); var str = false
    fun hit(ref: String?) { if (ref == null) return; if (ref.startsWith("o:")) o += ref.substring(2) else if (ref.startsWith("p:")) pc += ref.substring(2) }
    val d = dirOf(p0.ang); val L2 = p0.len / 2.0
    val hp = rayHit(c, d, segs); val hm = rayHit(c, -d, segs)
    var ep = L2; var em = L2
    if (hp.first.isFinite() && hp.first - L2 <= IW_MAG) { if (abs(hp.first - L2) > 1) str = true; ep = hp.first; hit(hp.second) }
    if (hm.first.isFinite() && hm.first - L2 <= IW_MAG) { if (abs(hm.first - L2) > 1) str = true; em = hm.first; hit(hm.second) }
    var p = p0
    if (ep + em >= 300) { c = c + d * ((ep - em) / 2); p = p.copy(len = (ep + em).roundToInt(), x = c.x.roundToInt(), y = c.y.roundToInt()) }
    if (p.k == "L" || p.k == "T") {
        val n = V2(-d.y, d.x); val t = p.th / 2.0
        val pc0 = V2(p.x.toDouble(), p.y.toDouble())
        val b = if (p.k == "L") (if (p.mir) pc0 + d * (-p.len / 2.0) + d * t else pc0 + d * (p.len / 2.0) + d * (-t)) else pc0
        val ha = rayHit(b, n, segs); val end = t + p.len2
        if (ha.first.isFinite() && ha.first - end <= IW_MAG) { if (abs(ha.first - end) > 1) str = true; p = p.copy(len2 = max(300, (ha.first - t).roundToInt())); hit(ha.second) }
    }
    return IwSnap(p, o, pc, str)
}

/** A live gap: [gap] mm from [a] (the piece) to [b] (the wall), along [dir]. */
data class IwSide(val gap: Int, val a: V2, val b: V2, val dir: V2)

/** The mockup's iwSides: S1 / S0 across (the n side and the other), E1 / E0 past the ends; a column on all four sides. */
fun iwSides(r: Room, p: InnerWall, snap: Boolean = true): Map<String, IwSide> {
    val G = pieceGeo(p, roomHOf(r)); val segs = obsSegs(r, snap, exP = p.id); val d = G.d; val n = G.n; val t = p.th / 2.0
    val res = LinkedHashMap<String, IwSide>()
    if (p.k == "col") {
        val s = p.len / 2.0
        listOf(d to "E1", -d to "E0", n to "S1", -n to "S0").forEach { (dv, k) -> val h = rayHit(G.c, dv, segs); if (h.first.isFinite()) res[k] = IwSide((h.first - s).roundToInt(), G.c + dv * s, G.c + dv * h.first, dv) }
        return res
    }
    val o1 = if (p.k == "T") G.c + d * (-p.len / 4.0) else G.c
    listOf(Triple(n, "S1", o1), Triple(-n, "S0", G.c)).forEach { (dv, k, org) -> val h = rayHit(org, dv, segs); if (h.first.isFinite()) res[k] = IwSide((h.first - t).roundToInt(), org + dv * t, org + dv * h.first, dv) }
    listOf(d to "E1", -d to "E0").forEach { (dv, k) -> val h = rayHit(G.c, dv, segs)
        if (h.first.isFinite()) { val gp = (h.first - p.len / 2.0).roundToInt(); if (gp > 5) res[k] = IwSide(gp, G.c + dv * (p.len / 2.0), G.c + dv * h.first, dv) } }
    return res
}

/** The room's middle: its box's centre when inside, else its centroid, else 600 mm in from wall A's middle. */
fun roomCen(r: Room, snap: Boolean = true): V2 {
    val P = outline(r, snap)
    if (P.isEmpty()) return V2(0.0, 0.0)
    val c = V2((P.minOf { it.x } + P.maxOf { it.x }) / 2, (P.minOf { it.y } + P.maxOf { it.y }) / 2)
    if (pip(c, P)) return c
    var A = 0.0; var cx = 0.0; var cy = 0.0
    for (i in P.indices) { val p = P[i]; val q = P[(i + 1) % P.size]; val k = p.x * q.y - q.x * p.y; A += k; cx += (p.x + q.x) * k; cy += (p.y + q.y) * k }
    if (abs(A) > 1e-6) { val g = V2(cx / (3 * A), cy / (3 * A)); if (pip(g, P)) return g }
    val f = wallFrames(r, snap).first()
    return mid(f.a, f.b) + f.n * 600.0
}

/**
 * A new piece from the window (the mockup's iwPick): in the room's middle, level (0°), shorter than the room so it does
 * not stretch at once (300 mm magnet + 60 mm clear at both ends), its arm short enough too.
 */
fun iwPlace(r: Room, k: String, snap: Boolean = true, id: String = "w" + uid()): InnerWall {
    val c = roomCen(r, snap); val rh = roomHOf(r)
    var p = newPiece(k, c, rh, id)
    if (k != "col") {
        val segs = obsSegs(r, snap).filter { it.ref.startsWith("o:") }
        val tot = rayHit(c, V2(1.0, 0.0), segs).first + rayHit(c, V2(-1.0, 0.0), segs).first
        val mx = tot - 2 * (IW_MAG + 60)
        if (tot.isFinite() && p.len > mx) p = p.copy(len = max(600, (mx / 10).roundToInt() * 10))
        if (p.len2 > 0) {
            val up = rayHit(c, V2(0.0, 1.0), segs).first; val m2 = up - p.th / 2.0 - IW_MAG - 60
            if (up.isFinite() && p.len2 > m2) p = p.copy(len2 = max(300, (m2 / 10).roundToInt() * 10))
        }
    }
    return p
}

/** "Uzunlik": the new length [v], the piece's start end kept where it is (a column keeps its centre). */
fun iwWithLen(p: InnerWall, v: Int): InnerWall {
    if (p.k == "col") return p.copy(len = v)
    val d = dirOf(p.ang); val c = V2(p.x.toDouble(), p.y.toDouble()) + d * (-p.len / 2.0) + d * (v / 2.0)
    return p.copy(len = v, x = c.x.roundToInt(), y = c.y.roundToInt())
}

/** A gap pill typed: the piece moved so that side [k] is [v] mm from its wall; null when there is no such gap. */
fun iwMoveGap(r: Room, p: InnerWall, k: String, v: Int, snap: Boolean = true): InnerWall? {
    val s = iwSides(r, p, snap)[k] ?: return null
    if (s.gap == v) return null
    val sh = (s.gap - v).toDouble()
    return p.copy(x = (p.x + s.dir.x * sh).roundToInt(), y = (p.y + s.dir.y * sh).roundToInt())
}

/** "90° burish": a quarter turn, then the snap (it may stretch to the walls it now points at). */
fun iwRotated(r: Room, p: InnerWall, snap: Boolean = true): IwSnap = iwSnap(r, p.copy(ang = (p.ang + 90) % 360), snap)

/** "Nusxa": a copy 600 mm beside it (a column its size + 400), on the first side that is in the room; null when none. */
fun iwCopyOf(r: Room, p: InnerWall, snap: Boolean = true, id: String = "w" + uid()): InnerWall? {
    val G = pieceGeo(p, roomHOf(r)); val P = outline(r, snap)
    val off = if (p.k == "col") p.len + 400.0 else 600.0
    val at = listOf(G.n, -G.n, G.d, -G.d).map { G.c + it * off }.firstOrNull { pip(it, P) } ?: return null
    return p.copy(id = id, x = at.x.roundToInt(), y = at.y.roundToInt())
}

/** The faces' indices of piece [pid] among all walls (outer first). */
fun pieceFaceIds(r: Room, pid: String, snap: Boolean = true): List<String> = innerFaces(r, snap).filter { it.pid == pid }.map { it.id }

/** An arch wall's passage on face [wall]: from [t0] to [t1] mm along it, [h] high; null for any other wall. */
fun archGap(r: Room, wall: String, snap: Boolean = true): Triple<Double, Double, Int>? {
    if (r.inner.none { it.k == "arch" }) return null
    val f = innerFaces(r, snap).firstOrNull { it.id == wall } ?: return null
    val p = r.inner.firstOrNull { it.id == f.pid && it.k == "arch" } ?: return null
    val w = min(p.opW.toDouble(), p.len - 200.0).coerceAtLeast(0.0); val L = f.len.toDouble()
    return Triple((L - w) / 2, (L + w) / 2, p.opH)
}

/* ---------------- doors' room, the Tekshiruv ---------------- */

/** The room a door needs: [id] the door, on [wall]; [sw] a leaf swings there; [pid] the piece it is in (inner faces); [poly] the zone. */
class DoorZone(val id: String, val wall: String, val sw: Boolean, val pid: String?, val poly: List<V2>)

/**
 * The mockup's doorZones: in front of every door, its leaf's width deep when it opens inwards (a double door half its
 * width), else 300 mm (sliding, arch, outwards). A door in an inner wall that does not open towards its face's side
 * (outwards, arch) also needs the other side.
 */
fun doorZones(r: Room, snap: Boolean = true, fr: List<WFrame> = wallFrames(r, snap)): List<DoorZone> {
    val out = ArrayList<DoorZone>()
    val byId = fr.associateBy { it.id }
    r.openings.forEach { o ->
        if (o.type != "door") return@forEach
        val f = byId[o.wall] ?: return@forEach
        val st = styleId(o)
        val dw = if (o.balcony) o.dw else o.w
        val leaf = if (st == "double") o.w / 2 else dw
        val swing = st != "arch" && st != "slide" && o.sw.ifEmpty { "inL" }.startsWith("in")
        val D = if (swing) max(leaf, 300) else 300
        val p0 = f.at(o.off.toDouble()); val p1 = f.at((o.off + dw).toDouble())
        out += DoorZone(o.id, o.wall, swing, f.face?.pid, band(p0, p1, f.n, 1.0, D.toDouble()))
        if (f.face != null && !swing && st != "slide") {
            val th = f.face.th.toDouble()
            out += DoorZone(o.id, o.wall, st != "arch", f.face.pid, band(p0, p1, f.n, -th - 1, -th - max(if (st == "arch") 300 else leaf, 300)))
        }
    }
    return out
}

/** The inner walls' problems: a piece in a door's swing ("iw.i.swing") or in front of a doorway ("iw.i.block"); k its kind, w the door's wall. */
fun iwIssues(r: Room, snap: Boolean = true): List<ReIssue> {
    if (r.inner.isEmpty()) return emptyList()
    val zones = doorZones(r, snap); val rh = roomHOf(r)
    val out = ArrayList<ReIssue>()
    r.inner.forEach { p ->
        val R = pieceGeo(p, rh).R; val seen = HashSet<String>()
        zones.forEach { z ->
            if (z.pid == p.id || z.id in seen) return@forEach
            if (R.any { sat(it, z.poly) }) { seen += z.id; out += ReIssue(p.id, if (z.sw) "iw.i.swing" else "iw.i.block", mapOf("k" to p.k, "w" to z.wall)) }
        }
    }
    return out
}

/* ---------------- areas for the trades ---------------- */

/** A convex (or simple) polygon's area, mm². */
fun polyArea(P: List<V2>): Double { var a = 0.0; for (i in P.indices) { val p = P[i]; val q = P[(i + 1) % P.size]; a += p.x * q.y - q.x * p.y }; return abs(a) / 2 }

/**
 * What the inner walls add to a room's areas: [floor] the floor they stand on (taken off), [len] their faces' length
 * (skirting, cable runs), [gross] their faces' area (both sides, a column all round, an arch's passage taken off),
 * [open] the doors and windows in them (twice: they go through both sides), [part] the partitions themselves, one side
 * (for bricks or boards), less their openings.
 */
data class InnerAreas(val floor: Long, val len: Long, val gross: Long, val open: Long, val part: Long)

fun innerAreas(r: Room, snap: Boolean = true, upTo: Int? = null): InnerAreas {
    if (r.inner.isEmpty()) return InnerAreas(0, 0, 0, 0, 0)
    val rh = roomHOf(r)
    var floor = 0.0; var len = 0.0; var gross = 0.0; var part = 0.0
    r.inner.forEach { p ->
        val G = pieceGeo(p, rh)
        G.R.forEach { floor += polyArea(it) }
        val H = min(G.H, upTo ?: G.H).toDouble()
        if (p.k == "col") { val per = if (p.round) PI * p.len else 4.0 * p.len; len += per; gross += per * H; return@forEach }
        G.F.forEach { f -> len += dist(f.a, f.b); gross += dist(f.a, f.b) * H }
        val gapA = if (p.k == "arch") min(p.opW.toDouble(), p.len - 200.0).coerceAtLeast(0.0) * min(p.opH.toDouble(), H) else 0.0
        gross -= 2 * gapA
        part += (p.len + (if (p.k == "L" || p.k == "T") p.len2 else 0)) * G.H.toDouble() - (if (p.k == "arch") min(p.opW.toDouble(), p.len - 200.0).coerceAtLeast(0.0) * p.opH else 0.0)
    }
    val keys = innerFaces(r, snap).map { it.key }.toSet()
    val inOps = r.openings.filter { it.fk in keys }
    val open = inOps.sumOf { o -> if (upTo == null) o.area.toDouble() else o.w.toDouble() * max(0, min(z0Of(o) + o.h, upTo) - z0Of(o)) }
    part -= inOps.sumOf { it.area.toDouble() }
    return InnerAreas(floor.roundToInt().toLong(), len.roundToInt().toLong(), gross.roundToInt().toLong(), (2 * open).roundToInt().toLong(), max(0.0, part).roundToInt().toLong())
}

/** [r] with only the items on its outer walls, for the older drawings and tools that know only those (a rectangle's A–D). */
fun outerItems(r: Room, snap: Boolean = true): Room {
    if (r.openings.none { it.fk.isNotEmpty() } && r.points.none { it.fk.isNotEmpty() }) return r
    val ids = walls(r, snap).map { it.id }.toSet()
    return r.copy(openings = r.openings.filter { it.wall in ids }, points = r.points.filter { it.wall in ids })
}

/** The points on inner faces (sockets, taps…), counted by the trades like the outer walls' ones. */
fun innerPoints(r: Room, snap: Boolean = true): List<SitePoint> { val keys = innerFaces(r, snap).map { it.key }.toSet(); return r.points.filter { it.fk in keys } }
fun innerOpenings(r: Room, snap: Boolean = true): List<Opening> { val keys = innerFaces(r, snap).map { it.key }.toSet(); return r.openings.filter { it.fk in keys } }

/* ---------------- mirroring ---------------- */

/**
 * The inner walls of [r] mirrored with the room (Burish → Ko‘zgu): [M] takes a plan point to its mirrored place, [Md]
 * a direction. Each piece's centre and turn follow, an L's arm goes to its other end; items on faces stay on their face
 * (its key), measured from the other end. Returns the pieces and the room's items.
 */
fun mirrorInner(r: Room, M: (V2) -> V2, Md: (V2) -> V2): Triple<List<InnerWall>, List<Opening>, List<SitePoint>> {
    if (r.inner.isEmpty()) return Triple(r.inner, r.openings, r.points)
    val rh = roomHOf(r)
    val pieces = r.inner.map { p ->
        val d = dirOf(p.ang); val d2 = -Md(d)
        val ang = ((Math.toDegrees(kotlin.math.atan2(d2.y, d2.x)).roundToInt() % 360) + 360) % 360
        val c = M(V2(p.x.toDouble(), p.y.toDouble()))
        p.copy(x = c.x.roundToInt(), y = c.y.roundToInt(), ang = ang, mir = if (p.k == "L") !p.mir else p.mir)
    }
    // each old face's mirrored segment is a new face reversed: match them by their ends
    val newF = HashMap<String, Pair<String, Double>>()   // old key → new key, length
    r.inner.forEachIndexed { i, p ->
        val og = pieceGeo(p, rh).F; val ng = pieceGeo(pieces[i], rh).F
        og.forEachIndexed { j, f ->
            val a = M(f.a); val b = M(f.b)
            val k = ng.indices.minByOrNull { q -> dist(ng[q].a, b) + dist(ng[q].b, a) } ?: return@forEachIndexed
            if (dist(ng[k].a, b) + dist(ng[k].b, a) < 5) newF["${p.id}:$j"] = "${p.id}:$k" to dist(f.a, f.b)
        }
    }
    val ops = r.openings.map { o -> val m = newF[o.fk] ?: return@map o; o.copy(fk = m.first, off = (m.second.roundToInt() - o.off - o.w).coerceAtLeast(0), sw = mirrorSwing(o.sw)) }
    val pts = r.points.map { q -> val m = newF[q.fk] ?: return@map q; q.copy(fk = m.first, off = (m.second.roundToInt() - q.off).coerceAtLeast(0)) }
    return Triple(pieces, ops, pts)
}
