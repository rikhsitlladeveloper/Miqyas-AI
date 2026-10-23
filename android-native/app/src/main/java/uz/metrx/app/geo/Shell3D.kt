package uz.metrx.app.geo

import uz.metrx.app.data.Room
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/*
 * The 3D shell of rooms, in metres (prototype build3D, opModel3D, the sketch module's polygon walls and the
 * ux module's rows of rooms). Pure geometry: the faces, the wall edges, the labels and where the camera may go.
 * ui/three draws it. x runs along wall A, z away from it (the plan's y), y up.
 */

data class V3(val x: Double, val y: Double, val z: Double) {
    operator fun plus(o: V3) = V3(x + o.x, y + o.y, z + o.z)
    operator fun minus(o: V3) = V3(x - o.x, y - o.y, z - o.z)
    operator fun times(k: Double) = V3(x * k, y * k, z * k)
    fun dot(o: V3) = x * o.x + y * o.y + z * o.z
    fun len() = sqrt(x * x + y * y + z * z)
    fun unit(): V3 { val l = len(); return if (l == 0.0) this else this * (1 / l) }
}

/** What a piece is, which decides what happens to it when its wall faces the camera and is cut away. */
enum class Role { WALL, OPENING, GLASS, FLOOR, FURN }

/**
 * A wall's own frame in the scene, metres: its start corner on the inside face ([ox], [oz]), the direction along it
 * ([ux], [uz]) and the one into the room ([nx], [nz]), its length. Furniture is placed in it.
 */
class WallBasis(val ox: Double, val oz: Double, val ux: Double, val uz: Double, val nx: Double, val nz: Double, val len: Double) {
    /** The scene point [a] along the wall, [y] up and [n] into the room, all in metres. */
    fun at(a: Double, y: Double, n: Double) = V3(ox + ux * a + nx * n, y, oz + uz * a + nz * n)
    /** A direction [da] along and [dn] into the room. */
    fun dir(da: Double, dn: Double) = V3(ux * da + nx * dn, 0.0, uz * da + nz * dn)
}

/** A flat face: a convex polygon ([tris] null, drawn as a fan) or a triangulated polygon (the floor of a drawn room). */
class Face(val n: V3, val pts: List<V3>, val tris: List<Int>? = null)

/** Faces with one colour and opacity, belonging to one wall of one room ([group]); floors and loose glass have no wall. [tile]: a tiler's tiles. */
class Part(val group: Int, val wall: String?, val role: Role, val rgb: Int, val op: Float, val tile: Boolean = false,
           /** A worktop: its top is lit like a stone surface and its outline drawn light, so a dark one shows its thickness. */
           val slab: Boolean = false) { val faces = ArrayList<Face>() }

/** A wall's outline as line segments (pairs of points), like the prototype's EdgesGeometry lines. */
class Edges(val group: Int, val wall: String, val rgb: Int = WALL_INK) { val segs = ArrayList<V3>() }

/** A room in the scene: its middle and the outward direction of each wall, for the cut-away. */
class Group(val cx: Double, val cz: Double, val normals: Map<String, Pair<Double, Double>>)

/** A label over the scene: a wall letter (single room) or a room name. */
class Label(val text: String, val p: V3)

/** A room's place when several rooms are shown: its name is a button that zooms to it. */
class Room3(val id: String, val name: String, val cx: Double, val cz: Double, val w: Double, val d: Double, val h: Double)

class Bounds(val x0: Double, val x1: Double, val z0: Double, val z1: Double)

class Shell3D(
    val parts: List<Part>,
    val edges: List<Edges>,
    val groups: List<Group>,
    val labels: List<Label>,
    val rooms3: List<Room3>?,
    /** Overall size (prototype T3.dims L, W, H). */
    val L: Double, val W: Double, val H: Double,
    val tgt: V3, val r: Double,
    /** Set for several rooms (the view turns to its standard angle); null keeps the current angle. */
    val theta: Double?, val phi: Double?,
    val bounds: Bounds, val rMin: Double,
    /** Width, depth, height, factor for the start distance, factor for the furthest distance (prototype T3.fit). */
    val fit: DoubleArray,
    val gridSize: Double, val gridDiv: Int, val gridCx: Double, val gridCz: Double,
    /** Towards the directional light. */
    val light: V3,
    val far: Double,
    /** One room only: each wall's frame, for the furniture of a furniture order. */
    val bases: Map<String, WallBasis> = emptyMap()
) {
    /** The same scene with more parts and outlines (the furniture). */
    fun plus(more: List<Part>, moreEdges: List<Edges>) = Shell3D(parts + more, edges + moreEdges, groups, labels, rooms3, L, W, H, tgt, r, theta, phi, bounds, rMin, fit,
        gridSize, gridDiv, gridCx, gridCz, light, far, bases)

    /**
     * Only the floor: furniture without a room, drawn without walls (the walls' frames stay for placing it). With no
     * walls, nothing faces the camera, so no furniture goes see-through.
     */
    /** The floor alone (furniture without a room); [th] the camera's start angle round it. */
    fun floorOnly(th: Double? = theta) = Shell3D(parts.filter { it.role == Role.FLOOR }, emptyList(), groups.map { Group(it.cx, it.cz, emptyMap()) }, emptyList(), rooms3, L, W, H, tgt, r, th, phi, bounds, rMin, fit,
        gridSize, gridDiv, gridCx, gridCz, light, far, bases)
}

const val FOV_HALF = PI / 9      // half of the 40° camera
const val WALL_INK = 0x0E1C36

/** A worktop's outline: light, so the edges of a dark worktop stand out against it. */
const val SLAB_LINE = 0xC4CCD8

/** A worktop's top face: its colour a little lighter, as a lit stone surface, against its darker front edge. */
fun slabTop(rgb: Int): Int {
    var out = 0
    for (k in 0..2) { val c = (rgb shr (16 - 8 * k)) and 255; out = (out shl 8) or (c + (255 - c) * .2).roundToInt().coerceIn(0, 255) }
    return out
}
private const val FIN = 0xC5CBD4
private const val GLASS = 0x9DB8E8
private const val HANDLE = 0x6F7782
private const val SILL = 0xF5F5F2

/**
 * How far the camera stands to show a w × d × h block (prototype v3Fit); [aspect] is width / height of the picture.
 */
fun v3Fit(w: Double, d: Double, h: Double, aspect: Double): Double {
    val hh = atan(tan(FOV_HALF) * aspect)
    return max(3.5, 0.5 * sqrt(w * w + d * d + h * h) / sin(min(FOV_HALF, hh)) * 0.9)
}

/* ---------------- building one or several rooms side by side (prototype build3D and its sketch override) ---------------- */

private class Builder {
    val parts = ArrayList<Part>(); val edges = ArrayList<Edges>(); val groups = ArrayList<Group>(); val labels = ArrayList<Label>()
    val bases = HashMap<String, WallBasis>()
    fun part(group: Int, wall: String?, role: Role, rgb: Int, op: Float = 1f) = Part(group, wall, role, rgb, op).also { parts += it }
    fun edgesOf(group: Int, wall: String) = edges.firstOrNull { it.group == group && it.wall == wall } ?: Edges(group, wall).also { edges += it }
}

private fun boxFaces(p: Part, x0: Double, x1: Double, y0: Double, y1: Double, z0: Double, z1: Double) {
    val f = p.faces
    f += Face(V3(1.0, 0.0, 0.0), listOf(V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1), V3(x1, y0, z1)))
    f += Face(V3(-1.0, 0.0, 0.0), listOf(V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0)))
    f += Face(V3(0.0, 1.0, 0.0), listOf(V3(x0, y1, z0), V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0)))
    f += Face(V3(0.0, -1.0, 0.0), listOf(V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)))
    f += Face(V3(0.0, 0.0, 1.0), listOf(V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1)))
    f += Face(V3(0.0, 0.0, -1.0), listOf(V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0), V3(x1, y0, z0)))
}

private fun boxEdges(e: Edges, x0: Double, x1: Double, y0: Double, y1: Double, z0: Double, z1: Double) {
    val c = listOf(V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1), V3(x0, y1, z0), V3(x1, y1, z0), V3(x1, y1, z1), V3(x0, y1, z1))
    for ((a, b) in listOf(0 to 1, 1 to 2, 2 to 3, 3 to 0, 4 to 5, 5 to 6, 6 to 7, 7 to 4, 0 to 4, 1 to 5, 2 to 6, 3 to 7)) { e.segs += c[a]; e.segs += c[b] }
}

/** Pieces of wall around the openings: [from, to, bottom, top] along a wall (prototype pieces()). */
internal fun pieces(a0: Double, a1: Double, ops: List<DoubleArray>, H: Double): List<DoubleArray> {
    val out = ArrayList<DoubleArray>(); var cur = a0
    ops.sortedBy { it[0] }.forEach { o ->
        if (o[0] > cur) out += doubleArrayOf(cur, o[0], 0.0, H)
        if (o[2] > 0) out += doubleArrayOf(o[0], o[1], 0.0, o[2])
        if (o[2] + o[3] < H) out += doubleArrayOf(o[0], o[1], o[2] + o[3], H)
        cur = max(cur, o[1])
    }
    if (cur < a1) out += doubleArrayOf(cur, a1, 0.0, H)
    return out
}

/** A rectangular room at x offset [ox] (prototype build3D, one room). Returns its extent along x. */
private fun rectRoom(b: Builder, room: Room, gi: Int, ox: Double, single: Boolean, name: String, bare: Set<String> = emptySet()): DoubleArray {
    val L = room.dim("A").v!! / 1000.0; val W = room.dim("B").v!! / 1000.0; val H = room.dim("H").v!! / 1000.0
    val T = (room.dim("T").v ?: 200) / 1000.0
    fun X(x: Double) = x + ox + T
    val wallRgb = rgbOf(room.wallColor)
    fun box(w: String, x0: Double, x1: Double, y0: Double, y1: Double, z0: Double, z1: Double, p: Part) {
        if (x1 - x0 < 1e-4 || y1 - y0 < 1e-4 || z1 - z0 < 1e-4) return
        boxFaces(p, X(x0), X(x1), y0, y1, z0, z1)
        if (p.role == Role.WALL) boxEdges(b.edgesOf(gi, w), X(x0), X(x1), y0, y1, z0, z1)
    }
    fun opsOn(w: String) = room.openings.filter { it.wall == w }.map { o ->
        val off = o.off / 1000.0; val wd = o.w / 1000.0
        val (a, bb) = when (w) { "A", "B" -> off to off + wd; "C" -> L - off - wd to L - off; else -> W - off - wd to W - off }
        doubleArrayOf(a, bb, o.sill / 1000.0, o.h / 1000.0, if (o.type == "door") 1.0 else 0.0, if (o.id in bare) 1.0 else 0.0)
    }
    // niches: cut out of the wall like an opening [a, b, sill, height, 2] and closed at their depth
    fun nichesOn(w: String) = room.features.filter { it.wall == w && it.type == "niche" }.map { f ->
        val off = f.off / 1000.0; val wd = f.w / 1000.0
        val (a, bb) = when (w) { "A", "B" -> off to off + wd; "C" -> L - off - wd to L - off; else -> W - off - wd to W - off }
        val sill = f.sill / 1000.0; val nh = (if (f.h > 0) f.h / 1000.0 else H - sill).coerceAtMost(H - sill)
        doubleArrayOf(a, bb, sill, nh, 2.0, minOf(f.d / 1000.0, T - .01))
    }
    for (w in listOf("A", "C", "B", "D")) {
        val p = b.part(gi, w, Role.WALL, wallRgb)
        val niches = nichesOn(w)
        val ops = opsOn(w) + niches
        when (w) {
            "A" -> pieces(-T, L + T, ops, H).forEach { box(w, it[0], it[1], it[2], it[3], -T, 0.0, p) }
            "C" -> pieces(-T, L + T, ops, H).forEach { box(w, it[0], it[1], it[2], it[3], W, W + T, p) }
            "B" -> pieces(0.0, W, ops, H).forEach { box(w, L, L + T, it[2], it[3], it[0], it[1], p) }
            else -> pieces(0.0, W, ops, H).forEach { box(w, -T, 0.0, it[2], it[3], it[0], it[1], p) }
        }
        // an opening a windows-and-doors maker filled has the product drawn in it instead ([bare])
        ops.filter { it[4] != 2.0 && it[5] != 1.0 }.forEach { openingModel(b, gi, w, it, T, L, W, ::X) }
        // the niche's back, its depth into the wall
        niches.forEach { n ->
            val dd = n[5]
            when (w) {
                "A" -> box(w, n[0], n[1], n[2], n[2] + n[3], -T, -dd, p)
                "C" -> box(w, n[0], n[1], n[2], n[2] + n[3], W + dd, W + T, p)
                "B" -> box(w, L + dd, L + T, n[2], n[2] + n[3], n[0], n[1], p)
                else -> box(w, -T, -dd, n[2], n[2] + n[3], n[0], n[1], p)
            }
        }
        // columns: full-height boxes against the wall's inside face
        room.features.filter { it.wall == w && it.type == "column" }.forEach { f ->
            val off = f.off / 1000.0; val wd = f.w / 1000.0; val dd = f.d / 1000.0
            when (w) {
                "A" -> box(w, off, off + wd, 0.0, H, 0.0, dd, p)
                "C" -> box(w, L - off - wd, L - off, 0.0, H, W - dd, W, p)
                "B" -> box(w, L - dd, L, 0.0, H, off, off + wd, p)
                else -> box(w, 0.0, dd, 0.0, H, W - off - wd, W - off, p)
            }
        }
    }
    room.points.forEach { pointModel(b, gi, it, L, W, ::X) }
    if (gi == 0) {
        b.bases["A"] = WallBasis(X(0.0), 0.0, 1.0, 0.0, 0.0, 1.0, L); b.bases["B"] = WallBasis(X(L), 0.0, 0.0, 1.0, -1.0, 0.0, W)
        b.bases["C"] = WallBasis(X(L), W, -1.0, 0.0, 0.0, -1.0, L); b.bases["D"] = WallBasis(X(0.0), W, 0.0, -1.0, 1.0, 0.0, W)
    }
    val fl = b.part(gi, null, Role.FLOOR, rgbOf(room.floorColor))
    fl.faces += Face(V3(0.0, 1.0, 0.0), listOf(V3(X(0.0), .001, 0.0), V3(X(0.0), .001, W), V3(X(L), .001, W), V3(X(L), .001, 0.0)))
    b.groups += Group(X(L / 2), W / 2, mapOf("A" to (0.0 to -1.0), "B" to (1.0 to 0.0), "C" to (0.0 to 1.0), "D" to (-1.0 to 0.0)))
    if (single) {
        b.labels += Label("A", V3(X(L / 2), H + .25, -T / 2)); b.labels += Label("B", V3(X(L + T / 2), H + .25, W / 2))
        b.labels += Label("C", V3(X(L / 2), H + .25, W + T / 2)); b.labels += Label("D", V3(X(-T / 2), H + .25, W / 2))
    } else b.labels += Label(name, V3(X(L / 2), H + .45, W / 2))
    return doubleArrayOf(L + 2 * T, W, H)
}

/* Furniture orders' site points: small boxes on the wall's inside face, in the colours of the plan (furniture plan section 5). */
private val PT_RGB = mapOf("socket" to 0xF1F5F9, "switch" to 0xE2E8F0, "cold" to 0x2563EB, "hot" to 0xDC2626, "sewer" to 0x64748B, "gas" to 0xEAB308, "meter" to 0xCA8A04)
private fun ptDepth(t: String) = when (t) { "socket", "switch" -> .012; "meter" -> .12; else -> .05 }

/** A site point in a rectangular room: centred [off] along its wall and [h] up, standing out of the wall's inside face. */
private fun pointModel(b: Builder, gi: Int, x: uz.metrx.app.data.SitePoint, L: Double, W: Double, X: (Double) -> Double) {
    val (wmm, hmm) = uz.metrx.app.data.pointSize(x); val sw = wmm / 2000.0; val sh = hmm / 2000.0
    val dep = ptDepth(x.t); val c = x.off / 1000.0; val y = x.h / 1000.0
    val m = b.part(gi, x.wall, Role.OPENING, PT_RGB[x.t] ?: 0x64748B)
    when (x.wall) {
        "A" -> boxFaces(m, X(c - sw), X(c + sw), y - sh, y + sh, 0.0, dep)
        "B" -> boxFaces(m, X(L - dep), X(L), y - sh, y + sh, c - sw, c + sw)
        "C" -> boxFaces(m, X(L - c - sw), X(L - c + sw), y - sh, y + sh, W - dep, W)
        "D" -> boxFaces(m, X(0.0), X(dep), y - sh, y + sh, W - c - sw, W - c + sw)
    }
}

/** A door or window in a rectangular room's wall (prototype opModel3D, the one standard style and finish). */
private fun openingModel(b: Builder, gi: Int, w: String, ar: DoubleArray, T: Double, L: Double, W: Double, X: (Double) -> Double) {
    val a = ar[0]; val bb = ar[1]; val v0 = ar[2]; val hh = ar[3]; val door = ar[4] == 1.0
    fun M(rgb: Int, op: Float = 1f) = b.part(gi, w, Role.OPENING, rgb, op)
    val mF = M(FIN); val mG = M(GLASS, .45f); val mH = M(HANDLE); val mLeaf = M(FIN)
    fun box(u0: Double, u1: Double, y0: Double, y1: Double, n0: Double, n1: Double, m: Part) {
        if (u1 - u0 < 1e-4 || y1 - y0 < 1e-4 || n1 - n0 < 1e-4) return
        if (w == "A" || w == "C") {
            val zc = if (w == "A") -(n0 + n1) / 2 else W + (n0 + n1) / 2; val hz = (n1 - n0) / 2
            boxFaces(m, X(u0), X(u1), y0, y1, zc - hz, zc + hz)
        } else {
            val xc = if (w == "B") L + (n0 + n1) / 2 else -(n0 + n1) / 2; val hx = (n1 - n0) / 2
            boxFaces(m, X(xc - hx), X(xc + hx), y0, y1, u0, u1)
        }
    }
    val top = v0 + hh; val fw = .055
    if (door) {
        val f0 = .01; val f1 = min(T - .01, .12)
        box(a, a + fw, 0.0, top, f0, f1, mF); box(bb - fw, bb, 0.0, top, f0, f1, mF); box(a, bb, top - fw, top, f0, f1, mF)
        val l0 = .03; val l1 = .07; val la = a + fw; val lb = bb - fw; val lt = top - fw
        box(la, lb, 0.0, lt, l0, l1, mLeaf)
        val hu = lb - .09
        box(hu, hu + .03, .98, 1.02, -.03, l0, mH)
    } else {
        val f0 = max(.01, T * .3); val f1 = min(T - .01, f0 + .07)
        box(a, a + fw, v0, top, f0, f1, mF); box(bb - fw, bb, v0, top, f0, f1, mF); box(a, bb, top - fw, top, f0, f1, mF); box(a, bb, v0, v0 + fw, f0, f1, mF)
        val n = 2; val ia = a + fw; val ib = bb - fw; val iy0 = v0 + fw; val iy1 = top - fw; val sw = (ib - ia) / n; val sb = .045; val gm = (f0 + f1) / 2
        for (k in 0 until n) {
            val s0 = ia + k * sw; val s1 = s0 + sw
            box(s0, s0 + sb, iy0, iy1, f0 + .01, f1 - .01, mF); box(s1 - sb, s1, iy0, iy1, f0 + .01, f1 - .01, mF)
            box(s0, s1, iy0, iy0 + sb, f0 + .01, f1 - .01, mF); box(s0, s1, iy1 - sb, iy1, f0 + .01, f1 - .01, mF)
            box(s0 + sb, s1 - sb, iy0 + sb, iy1 - sb, gm - .004, gm + .004, mG)
            if (k == 0) box(s1 - sb - .03, s1 - sb - .01, iy0 + (iy1 - iy0) * .48, iy0 + (iy1 - iy0) * .58, f0 - .02, f0 + .01, mH)
        }
        if (v0 > .05) box(a - .05, bb + .05, v0 - .03, v0, -.1, f0, M(SILL))
    }
}

/** A prism over the plan polygon [q] (x, z pairs) between heights [y0] and [y1]: caps and sides, each side facing outward. */
private fun prism(p: Part, e: Edges?, q: List<Pair<Double, Double>>, y0: Double, y1: Double) {
    if (y1 - y0 < 1e-4 || abs(area2(q)) < 1e-7) return
    val cx = q.sumOf { it.first } / q.size; val cz = q.sumOf { it.second } / q.size
    p.faces += Face(V3(0.0, 1.0, 0.0), q.map { V3(it.first, y1, it.second) })
    p.faces += Face(V3(0.0, -1.0, 0.0), q.map { V3(it.first, y0, it.second) })
    for (i in q.indices) {
        val a = q[i]; val c = q[(i + 1) % q.size]
        val dx = c.first - a.first; val dz = c.second - a.second; val l = hypot(dx, dz); if (l < 1e-9) continue
        var nx = dz / l; var nz = -dx / l
        if (((a.first + c.first) / 2 - cx) * nx + ((a.second + c.second) / 2 - cz) * nz < 0) { nx = -nx; nz = -nz }
        p.faces += Face(V3(nx, 0.0, nz), listOf(V3(a.first, y0, a.second), V3(c.first, y0, c.second), V3(c.first, y1, c.second), V3(a.first, y1, a.second)))
        if (e != null) {
            e.segs += V3(a.first, y0, a.second); e.segs += V3(c.first, y0, c.second)
            e.segs += V3(a.first, y1, a.second); e.segs += V3(c.first, y1, c.second)
            e.segs += V3(a.first, y0, a.second); e.segs += V3(a.first, y1, a.second)
        }
    }
}

private fun area2(q: List<Pair<Double, Double>>): Double { var s = 0.0; for (i in q.indices) { val a = q[i]; val c = q[(i + 1) % q.size]; s += a.first * c.second - c.first * a.second }; return s / 2 }

/** Outer corners: each wall pushed out by [w] along its normal, joined at a mitre (prototype skMiter). */
internal fun miter(ip: List<Pair<Double, Double>>, no: List<Pair<Double, Double>>, w: Double): List<Pair<Double, Double>> {
    val n = ip.size
    return ip.mapIndexed { i, p ->
        val a = no[(i - 1 + n) % n]; val b = no[i]; val d = 1 + a.first * b.first + a.second * b.second
        if (d < .15) p.first + b.first * w to p.second + b.second * w
        else p.first + (a.first + b.first) * w / d to p.second + (a.second + b.second) * w / d
    }
}

private fun centroid(v: List<Pair<Double, Double>>): Pair<Double, Double> {
    var a = 0.0; var cx = 0.0; var cy = 0.0
    v.forEachIndexed { i, p -> val q = v[(i + 1) % v.size]; val c = p.first * q.second - q.first * p.second; a += c; cx += (p.first + q.first) * c; cy += (p.second + q.second) * c }
    return if (abs(a) < 1e-12) v.sumOf { it.first } / v.size to v.sumOf { it.second } / v.size else cx / (3 * a) to cy / (3 * a)
}

/** Triangles of a simple polygon by ear clipping (the floor of a drawn room may be L-shaped). */
internal fun earClip(v: List<Pair<Double, Double>>): List<Int> {
    val n = v.size; if (n < 3) return emptyList()
    val ccw = area2(v) > 0
    val idx = (0 until n).toMutableList(); val out = ArrayList<Int>()
    fun cross(a: Pair<Double, Double>, b: Pair<Double, Double>, c: Pair<Double, Double>) = (b.first - a.first) * (c.second - a.second) - (b.second - a.second) * (c.first - a.first)
    fun inside(p: Pair<Double, Double>, a: Pair<Double, Double>, b: Pair<Double, Double>, c: Pair<Double, Double>): Boolean {
        val d1 = cross(a, b, p); val d2 = cross(b, c, p); val d3 = cross(c, a, p)
        return if (ccw) d1 >= -1e-12 && d2 >= -1e-12 && d3 >= -1e-12 else d1 <= 1e-12 && d2 <= 1e-12 && d3 <= 1e-12
    }
    var guard = 0
    while (idx.size > 3 && guard++ < 10 * n) {
        var cut = false
        for (k in idx.indices) {
            val i0 = idx[(k - 1 + idx.size) % idx.size]; val i1 = idx[k]; val i2 = idx[(k + 1) % idx.size]
            val c = cross(v[i0], v[i1], v[i2]); if (if (ccw) c <= 1e-12 else c >= -1e-12) continue
            if (idx.any { it != i0 && it != i1 && it != i2 && inside(v[it], v[i0], v[i1], v[i2]) }) continue
            out += i0; out += i1; out += i2; idx.removeAt(k); cut = true; break
        }
        if (!cut) break
    }
    if (idx.size == 3) { out += idx[0]; out += idx[1]; out += idx[2] }
    return out
}

/** A drawn room (prototype sketch build3D): each wall extruded along the solved polygon, windows as glass, the floor as the polygon. */
private fun polyRoom(b: Builder, room: Room, gi: Int, ox: Double, single: Boolean, name: String, snap: Boolean, bare: Set<String> = emptySet()): DoubleArray {
    val H = room.dim("H").v!! / 1000.0; val T = (room.dim("T").v ?: 200) / 1000.0
    val ws = walls(room, snap); val n = ws.size
    val ip = ws.map { it.p0.x / 1000.0 to it.p0.y / 1000.0 }
    val uu = ip.mapIndexed { i, p -> val q = ip[(i + 1) % n]; val l = hypot(q.first - p.first, q.second - p.second).takeIf { it > 0 } ?: 1.0; Triple((q.first - p.first) / l, (q.second - p.second) / l, l) }
    val no = uu.map { it.second to -it.first }
    val op = miter(ip, no, T)
    val minX = op.minOf { it.first }; val maxX = op.maxOf { it.first }; val minZ = op.minOf { it.second }; val maxZ = op.maxOf { it.second }
    fun X(x: Double) = x - minX + ox
    fun Z(z: Double) = z - minZ
    fun pt(p: Pair<Double, Double>) = X(p.first) to Z(p.second)
    val wallRgb = rgbOf(room.wallColor)
    val normals = LinkedHashMap<String, Pair<Double, Double>>()
    ws.forEachIndexed { i, w ->
        val a = ip[i]; val c = ip[(i + 1) % n]; val u = uu[i]; val len = u.third; val q = no[i]
        fun at(d: Double) = a.first + u.first * d to a.second + u.second * d
        fun off(p: Pair<Double, Double>, k: Double) = p.first + q.first * k to p.second + q.second * k
        val ops = room.openings.filter { it.wall == w.id }.map { o -> doubleArrayOf(o.off / 1000.0, (o.off + o.w) / 1000.0, o.sill / 1000.0, o.h / 1000.0, if (o.type == "door") 1.0 else 0.0, if (o.id in bare) 1.0 else 0.0) }
        val p = b.part(gi, w.id, Role.WALL, wallRgb); val e = b.edgesOf(gi, w.id)
        pieces(0.0, len, ops, H).forEach { pc ->
            val s0 = max(0.0, pc[0]); val s1 = min(len, pc[1]); if (s1 - s0 < 1e-4) return@forEach
            val i0 = if (s0 < 1e-6) a else at(s0); val o0 = if (s0 < 1e-6) op[i] else off(at(s0), T)
            val i1 = if (s1 > len - 1e-6) c else at(s1); val o1 = if (s1 > len - 1e-6) op[(i + 1) % n] else off(at(s1), T)
            prism(p, e, listOf(pt(i0), pt(i1), pt(o1), pt(o0)), pc[2], pc[3])
        }
        ops.filter { it[4] == 0.0 && it[5] != 1.0 }.forEach { o ->
            val g = b.part(gi, null, Role.GLASS, GLASS, .5f)
            prism(g, null, listOf(pt(off(at(o[0]), T / 2 - .01)), pt(off(at(o[1]), T / 2 - .01)), pt(off(at(o[1]), T / 2 + .01)), pt(off(at(o[0]), T / 2 + .01))), o[2], o[2] + o[3])
        }
        // site points of a furniture order, standing out of this wall's inside face
        room.points.filter { it.wall == w.id }.forEach { x ->
            val (wmm, hmm) = uz.metrx.app.data.pointSize(x); val s2 = wmm / 2000.0; val sh = hmm / 2000.0
            val dep = ptDepth(x.t); val c = x.off / 1000.0; val y = x.h / 1000.0
            val m = b.part(gi, w.id, Role.OPENING, PT_RGB[x.t] ?: 0x64748B)
            prism(m, null, listOf(pt(off(at(c - s2), -dep)), pt(off(at(c + s2), -dep)), pt(at(c + s2)), pt(at(c - s2))), y - sh, y + sh)
        }
        normals[w.id] = q
        if (gi == 0) { val o = pt(a); b.bases[w.id] = WallBasis(o.first, o.second, u.first, u.second, -q.first, -q.second, len) }
        if (single) { val md = at(len / 2); b.labels += Label(w.id, V3(X(md.first + q.first * T / 2), H + .25, Z(md.second + q.second * T / 2))) }
    }
    val fl = b.part(gi, null, Role.FLOOR, rgbOf(room.floorColor))
    val fp = ip.map { pt(it) }
    fl.faces += Face(V3(0.0, 1.0, 0.0), fp.map { V3(it.first, .001, it.second) }, earClip(fp))
    val cc = centroid(ip)
    b.groups += Group(X(cc.first), Z(cc.second), normals)
    if (!single) b.labels += Label(name, V3(X(cc.first), H + .45, Z(cc.second)))
    return doubleArrayOf(maxX - minX, maxZ - minZ, H)
}

/** Rooms in one line (prototype build3D), as the prototype's sketch override does: any drawn room sends all rooms the polygon way. */
private fun base(rooms: List<Room>, single: Boolean, snap: Boolean, name: (Room) -> String, bare: Set<String> = emptySet()): Pair<Builder, DoubleArray> {
    val b = Builder(); var ox = 0.0; var maxW = 0.0; var maxH = 0.0; val gap = 1.2
    val poly = rooms.any { it.isPoly }
    rooms.forEachIndexed { gi, room ->
        val ext = if (poly) polyRoom(b, room, gi, ox, single, name(room), snap, bare) else rectRoom(b, room, gi, ox, single, name(room), bare)
        ox += ext[0] + gap; maxW = max(maxW, ext[1]); maxH = max(maxH, ext[2])
    }
    return b to doubleArrayOf(max(ox - gap, 1.0), maxW, maxH)
}

private fun lightTowards(span: Double, maxW: Double, maxH: Double) = V3(span * .7 + 3, maxH * 3 + 4, maxW * 1.6 + 3).unit()

/**
 * The scene for one room ([single], with wall letters) or for the rooms of a workspace (names that zoom to a room),
 * with the ux module's limits: the view's middle stays over the rooms and the zoom inside a range. Openings in [bare]
 * (filled by a windows-and-doors maker's products, drawn by its own app) get no standard window or door.
 */
fun buildShell(rooms: List<Room>, single: Boolean, snap: Boolean = true, bare: Set<String> = emptySet(), name: (Room) -> String = { it.name }): Shell3D {
    if (single || rooms.size < 2) {
        val (b, d) = base(rooms, single, snap, name, bare)
        val span = d[0]; val maxW = d[1]; val maxH = d[2]; val gs = max(span, maxW) + 4
        return Shell3D(
            b.parts, b.edges, b.groups, b.labels, null, span, maxW, maxH,
            V3(span / 2, maxH * .3, maxW / 2), max(span, maxW) * (if (single) 2.2 else 1.7) + 2.5,
            if (single) null else PI / 2 + .45, if (single) null else .9,
            Bounds(span * .15, span * .85, maxW * .15, maxW * .85), 2.5, doubleArrayOf(span, maxW, maxH, 1.25, 1.6),
            gs, (gs * 2).roundToInt(), span / 2, maxW / 2, lightTowards(span, maxW, maxH), 300.0, if (single) b.bases else emptyMap()
        )
    }
    // several rooms stand in rows, like on a sheet of paper (ux module)
    val gap = 1.4
    class P(val room: Room, val b: Builder, val x0: Double, val z0: Double, val w: Double, val d: Double, val h: Double)
    val ps = rooms.map { room ->
        val (b, _) = base(listOf(room), false, snap, name)
        val pts = b.parts.flatMap { pt -> pt.faces.flatMap { it.pts } }
        val x0 = pts.minOf { it.x }; val z0 = pts.minOf { it.z }
        P(room, b, x0, z0, pts.maxOf { it.x } - x0, pts.maxOf { it.z } - z0, pts.maxOf { it.y })
    }
    val area = ps.sumOf { (it.w + gap) * (it.d + gap) }
    val rowW = max(ps.maxOf { it.w }, sqrt(area) * 1.2)
    class Row(var w: Double, var d: Double, val it: ArrayList<P>)
    val rows = ArrayList<Row>(); var cur: Row? = null
    ps.forEach { p -> val c = cur; if (c == null || c.w + gap + p.w > rowW) { cur = Row(p.w, p.d, arrayListOf(p)).also { rows += it } } else { c.w += gap + p.w; c.d = max(c.d, p.d); c.it += p } }
    val W = rows.maxOf { it.w }; val Dp = rows.sumOf { it.d } + gap * (rows.size - 1); val H = ps.maxOf { it.h }
    val parts = ArrayList<Part>(); val edges = ArrayList<Edges>(); val groups = ArrayList<Group>(); val list = ArrayList<Room3>()
    var z = 0.0
    rows.forEach { row ->
        var x = (W - row.w) / 2
        row.it.forEach { p ->
            val gi = groups.size; val dx = x - p.x0; val dz = z - p.z0; val mv = V3(dx, 0.0, dz)
            p.b.parts.forEach { pt -> parts += Part(gi, pt.wall, pt.role, pt.rgb, pt.op).also { np -> pt.faces.forEach { f -> np.faces += Face(f.n, f.pts.map { it + mv }, f.tris) } } }
            p.b.edges.forEach { e -> edges += Edges(gi, e.wall).also { ne -> e.segs.forEach { ne.segs += it + mv } } }
            p.b.groups.forEach { g -> groups += Group(g.cx + dx, g.cz + dz, g.normals) }
            list += Room3(p.room.id, name(p.room), x + p.w / 2, z + p.d / 2, p.w, p.d, p.h)
            x += p.w + gap
        }
        z += row.d + gap
    }
    val gs = max(W, Dp) + 4
    return Shell3D(
        parts, edges, groups, emptyList(), list, W, Dp, H, V3(W / 2, H * .3, Dp / 2), max(W, Dp) * 1.5 + 2.5, PI / 2 + .45, .9,
        Bounds(list.minOf { it.cx }, list.maxOf { it.cx }, list.minOf { it.cz }, list.maxOf { it.cz }), 3.0, doubleArrayOf(W, Dp, H, 1.0, 1.35),
        gs, (gs * 2).roundToInt(), W / 2, Dp / 2, lightTowards(W, Dp, H), 400.0
    )
}

/* ---------------- light: the prototype's Lambert material under a hemisphere, an ambient and a directional light ---------------- */

/**
 * The colour three.js (r128, no colour management) gives a Lambert face with normal [n]: the base colour times
 * ambient 0.3 + hemisphere 0.5 (white sky, #C9D3E0 ground) + directional 0.55 · max(0, n·l), clamped. sRGB numbers.
 */
fun shade(rgb: Int, n: V3, light: V3): Int {
    val w = .5 * n.y + .5; val dl = .55 * max(0.0, n.dot(light))
    val ground = intArrayOf(0xC9, 0xD3, 0xE0)
    var out = 0
    for (k in 0..2) {
        val c = (rgb shr (16 - 8 * k)) and 255
        val g = ground[k] / 255.0
        val f = .3 + .5 * (g + (1 - g) * w) + dl
        out = (out shl 8) or (c * f).roundToInt().coerceIn(0, 255)
    }
    return out
}

fun rgbOf(hex: String): Int = runCatching { hex.removePrefix("#").toInt(16) and 0xFFFFFF }.getOrDefault(0xECE8E1)

/** The swatches of the 3D page (prototype wc and fc). */
val WALL_COLORS = listOf("#ECE8E1", "#D9D4CB", "#D6E0EC", "#E6D3B3")
val FLOOR_COLORS = listOf("#C49A6C", "#8A6343", "#B9BDC2", "#A7A39C")
