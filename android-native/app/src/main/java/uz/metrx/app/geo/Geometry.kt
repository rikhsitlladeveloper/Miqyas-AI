package uz.metrx.app.geo

import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.roundToLong
import kotlin.math.sin

/*
 * Room geometry and the rules for typed values, ported from the prototype (core areas/roomWalls/openingIssue/parseDec,
 * sketch skGeo/skSolve). Pure Kotlin, no Android, so it is unit-tested (see GeometryTest).
 * All lengths are millimetres (Int), areas mm² (Long). Plan y points down; corners and walls run clockwise.
 */

/** Limits of a typed dimension, mm (prototype DIM_MAX); a room is at most 6 m high. */
val DIM_MAX = mapOf("A" to 100_000, "B" to 100_000, "H" to 6_000, "T" to 2_000)
fun dimMax(k: String) = DIM_MAX[k] ?: 100_000

/** The least a room's measurement may be, mm: a rectangle's side 0,5 m, the height 1,8 m (a drawn room's walls may be short). */
fun dimMin(k: String, poly: Boolean) = when { k == "H" -> 1_800; !poly && (k == "A" || k == "B") -> 500; else -> 0 }

/** What keeps a reading [mm] off measurement [k], as a typed value: ("err.min", the least) or ("err.max", the most); null when it fits. */
fun readingLimit(k: String, mm: Int, poly: Boolean): Pair<String, Int>? {
    val min = dimMin(k, poly); val max = dimMax(k)
    return if (mm in 1 until min) "err.min" to min else if (mm > max) "err.max" to max else null
}

/** A height above this is unusual: said under the field (it may be right: a hall, a loft). */
const val H_TALL = 4_500

/* ---------------- units and number formats ---------------- */

/** Metres, centimetres, or millimetres (furniture makers, UX upgrades §5: "3400", no decimals). */
enum class LenUnit { M, CM, MM }

/** Comma decimals, except English (point). */
fun decMark(english: Boolean) = if (english) '.' else ','

/** Length as the prototype's fmtLen: metres with 2 decimals (3 when the mm need it), or centimetres with 0 or 1. */
fun fmtLen(mm: Int?, unit: LenUnit = LenUnit.M, english: Boolean = false, full: Boolean = false): String {
    if (mm == null) return "?"
    if (unit == LenUnit.MM) return mm.toString()
    val s = if (unit == LenUnit.CM) "%.${if (full || mm % 10 != 0) 1 else 0}f".format(java.util.Locale.ROOT, mm / 10.0)
            else "%.${if (full) 3 else if (mm % 10 != 0) 3 else 2}f".format(java.util.Locale.ROOT, mm / 1000.0)
    return s.replace('.', decMark(english))
}

/** Area mm² as m² with 2 decimals. */
fun fmtArea(mm2: Long?, english: Boolean = false): String =
    if (mm2 == null) "?" else "%.2f".format(java.util.Locale.ROOT, mm2 / 1e6).replace('.', decMark(english))

/** A value to put back into a field: as shown, with all decimals when the mm need them (prototype fm()). */
fun fmtField(mm: Int, unit: LenUnit, english: Boolean) = fmtLen(mm, unit, english, full = mm % 10 != 0)

/* ---------------- typed values (prototype parseDec / lenErr) ---------------- */

sealed interface Parsed {
    data class Ok(val value: Long) : Parsed
    data class Err(val key: String, val vars: Map<String, Any?> = emptyMap()) : Parsed
}

/**
 * Parses "4,255", "4.255", "04.250", "4 255", ".5"; rejects "4.2.1", "1e3", "-1". Returns the value scaled by 10^maxDec
 * (so with the unit's decimals it is millimetres), at most Int.MAX_VALUE, so a huge number stays huge and never wraps.
 */
fun parseDec(str: String?, maxDec: Int): Parsed {
    val s = (str ?: "").replace(Regex("[\\s\\u00A0\\u202F]"), "")
    if (s.isEmpty()) return Parsed.Err("err.empty")
    if (!Regex("^-?\\d*([.,]\\d*)?$").matches(s) || Regex("^-?[.,]?$").matches(s)) return Parsed.Err("err.format")
    if (s.startsWith("-")) return Parsed.Err("err.negative")
    val parts = s.replace(',', '.').split('.')
    val i = parts[0]; val f = parts.getOrElse(1) { "" }
    if (f.length > maxDec) return Parsed.Err("err.precision", mapOf("n" to maxDec))
    val v = ((i.ifEmpty { "0" }) + f.padEnd(maxDec, '0')).toBigInteger()
    return Parsed.Ok(if (v > Int.MAX_VALUE.toBigInteger()) Int.MAX_VALUE.toLong() else v.toLong())
}

fun unitDecimals(unit: LenUnit) = when (unit) { LenUnit.CM -> 1; LenUnit.MM -> 0; else -> 3 }

/** A typed length in mm, or the error (key + values) to show. [max] in mm; [zeroOk] for an offset or a sill. */
fun lenErr(str: String?, max: Int, unit: LenUnit, english: Boolean, zeroOk: Boolean = false, min: Int = 0): Parsed {
    val r = parseDec(str, unitDecimals(unit))
    if (r is Parsed.Err) return r
    val mm = (r as Parsed.Ok).value
    if (mm == 0L && !zeroOk) return Parsed.Err("err.zero")
    if (mm in 1 until min) {
        val m = fmtLen(min, unit, english).replace(Regex("[.,]0+$"), "")
        return Parsed.Err("err.min", mapOf("min" to m + " " + (when (unit) { LenUnit.CM -> "@u.cm"; LenUnit.MM -> "@u.mm"; else -> "@u.m" })))
    }
    if (mm > max) {
        val m = fmtLen(max, unit, english).replace(Regex("[.,]0+$"), "")
        return Parsed.Err("err.max", mapOf("max" to m + " " + (when (unit) { LenUnit.CM -> "@u.cm"; LenUnit.MM -> "@u.mm"; else -> "@u.m" })))
    }
    return Parsed.Ok(mm)
}

/* ---------------- walls ---------------- */

/** One wall, clockwise; [dimKey] holds its length; [derived] walls (rect C and D) copy A and B. */
data class Wall(val id: String, val corner: Int, val len: Int?, val dimKey: String, val derived: Boolean, val p0: Pt, val p1: Pt, val status: String = "")

/** The walls of a room (prototype roomWalls). Rect: A,B measured; C = A, D = B. Polygon: from the solved shape. */
fun walls(r: Room, angleSnap: Boolean = true): List<Wall> {
    if (r.isPoly) return polyGeo(r, angleSnap).walls
    val a = r.dim("A"); val b = r.dim("B")
    val L = (a.v ?: a.pending?.mm ?: 5000).toDouble(); val W = (b.v ?: b.pending?.mm ?: 4000).toDouble()
    return listOf(
        Wall("A", 1, a.v, "A", false, Pt(0.0, 0.0), Pt(L, 0.0)),
        Wall("B", 2, b.v, "B", false, Pt(L, 0.0), Pt(L, W)),
        Wall("C", 3, a.v, "A", true, Pt(L, W), Pt(0.0, W)),
        Wall("D", 4, b.v, "B", true, Pt(0.0, W), Pt(0.0, 0.0))
    )
}

fun wallLen(r: Room, id: String, snap: Boolean = true) = walls(r, snap).firstOrNull { it.id == id }?.len
fun wallCorner(r: Room, id: String, snap: Boolean = true) = walls(r, snap).firstOrNull { it.id == id }?.corner ?: 1

/** The measurements the builder takes, in order (prototype hmDimKeys): the non-derived walls, then the height. */
fun stepKeys(r: Room, snap: Boolean = true): List<String> = walls(r, snap).filter { !it.derived }.map { it.dimKey }.distinct() + "H"

/* ---------------- areas ---------------- */

data class Areas(val floor: Long, val perim: Long, val gross: Long?, val open: Long?, val net: Long?)

/** Floor, perimeter, wall areas from confirmed values only (prototype areas()); null until the floor is known. */
fun areas(r: Room, snap: Boolean = true): Areas? {
    val H = r.dim("H").v
    val floor: Long; val perim: Long
    if (r.isPoly) {
        val g = polyGeo(r, snap)
        if (!g.solved) return null
        floor = abs(shoelace(g.verts)).roundToLong()
        perim = g.walls.sumOf { (it.len ?: 0).toLong() }
    } else {
        val L = r.dim("A").v ?: return null; val W = r.dim("B").v ?: return null
        floor = L.toLong() * W; perim = 2L * (L + W)
    }
    // columns take floor and add their two sides to the walls; a niche from the floor adds floor and its sides
    val fx = r.features
    val floorF = floor - fx.filter { it.type == "column" }.sumOf { it.w.toLong() * it.d } + fx.filter { it.type == "niche" && it.sill == 0 }.sumOf { it.w.toLong() * it.d }
    val ws = if (fx.any { it.type == "column" }) walls(r, snap) else emptyList()
    // a column's side flush with a corner is no wall: it covers that much of the next wall instead (-d, not +d)
    fun colSides(f: uz.metrx.app.data.Feature): Long {
        val len = ws.firstOrNull { it.id == f.wall }?.len
        return ((if (f.off <= 0) -1 else 1) + (if (len != null && f.off + f.w >= len) -1 else 1)).toLong() * f.d
    }
    val perimF = perim + fx.sumOf { if (it.type == "column") colSides(it) else if (it.sill == 0) 2L * it.d else 0L }
    if (H == null) return Areas(floorF, perimF, null, null, null)
    val extra = fx.sumOf { f ->
        if (f.type == "column") colSides(f) * H
        else {
            // a niche the room's height no longer reaches has nothing inside (and never a negative area)
            val nh = (if (f.h > 0) f.h else H - f.sill).coerceAtMost(H - f.sill).coerceAtLeast(0).toLong()
            if (nh == 0L) 0L
            else 2L * f.d * nh + (if (f.sill > 0) f.w.toLong() * f.d else 0L) + (if (f.sill + nh < H) f.w.toLong() * f.d else 0L)
        }
    }
    val gross = perim * H + extra
    val open = r.openings.sumOf { it.w.toLong() * it.h }
    return Areas(floorF, perimF, gross, open, gross - open)
}

/** What is wrong with a column or niche [f] in room [r]: off the wall's end, too deep or sticking out too far. Null when it fits. */
fun featureIssue(r: Room, f: uz.metrx.app.data.Feature, snap: Boolean = true): String? {
    val ws = walls(r, snap)
    val L = ws.firstOrNull { it.id == f.wall }?.len ?: return "ft.needWall"
    if (f.w <= 0 || f.d <= 0) return "ft.size"
    if (f.off + f.w > L) return "ft.exceeds"
    if (f.type == "niche" && f.d > 1000) return "ft.deep"
    // a column sticks out into the room: at most 2 m, and less than the room's shorter side
    if (f.type == "column" && (f.d > 2000 || ws.mapNotNull { it.len }.minOrNull()?.let { f.d >= it } == true)) return "ft.colDeep"
    val H = r.dim("H").v
    if (f.type == "niche" && H != null && f.sill + (if (f.h > 0) f.h else 0) > H) return "ft.tall"
    return null
}

data class WallStats(val gross: Long?, val open: Long, val net: Long?)

/** One wall's areas (prototype wvWallStats). */
fun wallStats(len: Int?, H: Int?, ops: List<Opening>): WallStats {
    val open = ops.sumOf { it.w.toLong() * it.h }
    if (len == null || H == null) return WallStats(null, open, null)
    val g = len.toLong() * H
    return WallStats(g, open, g - open)
}

/* ---------------- doors and windows (prototype openingIssue) ---------------- */

data class Issue(val field: String, val key: String, val vars: Map<String, Any?>)

/** The first problem with [o] in room [r], or null. [kindName] is the localised "Eshik"/"Deraza". */
fun openingIssue(r: Room, o: Opening, kindName: String, unit: LenUnit, english: Boolean, snap: Boolean = true): Issue? {
    val w = walls(r, snap).firstOrNull { it.id == o.wall }
    val L = w?.len ?: return Issue("wall", "op.needWall", mapOf("w" to if (w?.derived == true) w.dimKey else o.wall))
    if (o.off + o.w > L) return Issue("w", "op.exceeds", mapOf("o" to kindName, "x" to fmtLen(o.off + o.w - L, LenUnit.M, english)))
    val H = r.dim("H").v
    // a door has no sill: only its height can give way
    if (H != null && o.sill + o.h > H) return Issue("h", if (o.type == "door") "op.tooTallDoor" else "op.tooTall", mapOf("o" to kindName, "x" to fmtLen(o.sill + o.h - H, LenUnit.M, english)))
    for (x in r.openings) if (x.id != o.id && x.wall == o.wall && o.off < x.off + x.w && x.off < o.off + o.w)
        return Issue("off", "op.overlap", mapOf("o" to kindName))
    return null
}

/* ---------------- statuses and the next step ---------------- */

/** How many of the room's measurements are not confirmed (prototype unconfCount). */
fun unconfCount(r: Room, snap: Boolean = true): Int {
    if (!r.isPoly) return listOf("A", "B", "H").count { r.dim(it).status != "conf" }
    val g = polyGeo(r, snap)
    return g.walls.count { it.status != "conf" && it.status != "calc" } + (if (r.dim("H").status != "conf") 1 else 0) +
        g.diagStatus.values.count { it == "recv" || it == "unset" || it == "warn" }
}

/** Every measurement confirmed, no reading waiting, and no door or window problem. */
fun allConfirmed(r: Room, issues: Int, snap: Boolean = true) = stepKeys(r, snap).all { r.dim(it).status == "conf" } && issues == 0

/** A, B and H known (pending ignored): enough for 3D (prototype room3DReady). */
fun ready3D(r: Room, snap: Boolean = true) = if (r.isPoly) polyGeo(r, snap).solved && r.dim("H").v != null
    else r.dim("A").v != null && r.dim("B").v != null && r.dim("H").v != null

/* ---------------- polygons: the solver (prototype skGeo / skSolve) ---------------- */

const val SK_LETTERS = "ABCDEFGJKLMNPQRSUVWYZ"
const val SK_TOL = 20.0
private const val EPS = 1e-6

fun polyWallIds(n: Int) = SK_LETTERS.take(n).map { it.toString() }

data class PolyGeo(
    val verts: List<Pt>,               // solved corners, or the sketch's when not solved
    val walls: List<Wall>,
    val solved: Boolean,
    val err: String? = null,           // closure, negative, cross
    val conflict: List<String> = emptyList(),
    val either: List<String> = emptyList(),
    val measure: List<String> = emptyList(),
    val some: Int = 0,
    val computed: List<String> = emptyList(),
    val diagStatus: Map<String, String> = emptyMap(),
    val diagLen: Map<String, Int> = emptyMap(),
    val gap: Int = 0                   // how far the measured walls miss closing, mm (err closure)
)

fun snapAngle(a: Double): Double { val st = PI / 4; return (a / st).roundToInt() * st }

private data class Solve(val status: String, val len: List<Double?>, val err: String? = null, val errVec: Pair<Double, Double>? = null,
                         val either: List<Int> = emptyList(), val measure: List<Int> = emptyList(), val keep: List<Int> = emptyList(), val some: Int = 0)

private fun solve(dirs: List<Double>, lens: List<Double?>): Solve {
    val n = dirs.size
    val ux = dirs.map { cos(it) }; val uy = dirs.map { sin(it) }
    var kx = 0.0; var ky = 0.0
    val unk = ArrayList<Int>()
    for (i in 0 until n) { val l = lens[i]; if (l == null) unk += i else { kx += l * ux[i]; ky += l * uy[i] } }
    val out = lens.toMutableList()
    when (unk.size) {
        0 -> return if (hypot(kx, ky) > SK_TOL) Solve("conflict", out, "closure", kx to ky) else Solve("solved", out)
        1 -> {
            val k = unk[0]
            val l = -(kx * ux[k] + ky * uy[k])
            val ex = kx + l * ux[k]; val ey = ky + l * uy[k]
            if (hypot(ex, ey) > SK_TOL) return Solve("conflict", out, "closure", ex to ey)
            if (l <= SK_TOL) return Solve("conflict", out, "negative", kx to ky)
            out[k] = l.roundToInt().toDouble(); return Solve("solved", out)
        }
        2 -> {
            val a = unk[0]; val b = unk[1]
            val det = ux[a] * uy[b] - uy[a] * ux[b]
            if (abs(det) > EPS) {
                val la = (-kx * uy[b] + ky * ux[b]) / det
                val lb = (kx * uy[a] - ky * ux[a]) / det
                if (la <= SK_TOL || lb <= SK_TOL) return Solve("conflict", out, "negative", kx to ky)
                out[a] = la.roundToInt().toDouble(); out[b] = lb.roundToInt().toDouble(); return Solve("solved", out)
            }
            val perp = abs(kx * -uy[a] + ky * ux[a])
            return if (perp > SK_TOL) Solve("conflict", out, "closure", kx to ky) else Solve("unresolved", out, either = listOf(a, b))
        }
        else -> {
            for (i in unk.indices.reversed()) for (j in (i - 1) downTo 0) {
                val a = unk[j]; val b = unk[i]
                if (abs(ux[a] * uy[b] - uy[a] * ux[b]) > EPS) return Solve("unresolved", out, measure = unk.filter { it != a && it != b }, keep = listOf(a, b))
            }
            return Solve("unresolved", out, measure = unk, some = unk.size - 1)
        }
    }
}

fun buildVerts(dirs: List<Double>, len: List<Double>, start: Pt): List<Pt> {
    val v = ArrayList<Pt>(dirs.size); var x = start.x; var y = start.y
    for (i in dirs.indices) { v += Pt(x, y); x += len[i] * cos(dirs[i]); y += len[i] * sin(dirs[i]) }
    return v
}

fun shoelace(v: List<Pt>): Double { var s = 0.0; for (i in v.indices) { val a = v[i]; val b = v[(i + 1) % v.size]; s += a.x * b.y - b.x * a.y }; return s / 2 }

// the report is drawn on a background thread while the screens read it too
private val geoCache = java.util.concurrent.ConcurrentHashMap<String, Pair<Any, PolyGeo>>()

/**
 * Solves a drawn room from its measured walls (prototype skGeo). Cached on the room's shape, dims and snap. The room's
 * own snap (Poly.snap) wins; [angleSnap] is only for a room that has none (an old quote's rooms: the quote's snap).
 */
fun polyGeo(r: Room, angleSnap: Boolean = true): PolyGeo {
    val snap = r.poly?.snap ?: angleSnap
    val key = Triple(snap, r.poly, r.dims)
    geoCache[r.id]?.let { (k, g) -> if (k == key) return g }
    val g = computePolyGeo(r, snap)
    if (geoCache.size > 200) geoCache.clear()
    geoCache[r.id] = key to g
    return g
}

private fun computePolyGeo(r: Room, angleSnap: Boolean): PolyGeo {
    val V = r.poly!!.verts; val n = V.size
    val ids = polyWallIds(n)
    val dirs = (0 until n).map { i -> val a = V[i]; val b = V[(i + 1) % n]; atan2(b.y - a.y, b.x - a.x).let { if (angleSnap) snapAngle(it) else it } }
    val lens = ids.map { r.dim(it).v?.toDouble() }
    val s = solve(dirs, lens)
    var solved = s.status == "solved"
    var err = s.err
    val computed = if (solved) ids.indices.filter { lens[it] == null }.map { ids[it] } else emptyList()
    var conflict = emptyList<String>()
    var verts = V
    if (s.status == "conflict" && s.errVec != null) {
        val (ex, ey) = s.errVec; val m = hypot(ex, ey).takeIf { it > EPS } ?: 1.0
        conflict = ids.indices.filter { lens[it] != null && abs(cos(dirs[it]) * ex / m + sin(dirs[it]) * ey / m) > .05 }.map { ids[it] }
    }
    if (solved) {
        val built = buildVerts(dirs, s.len.map { it!! }, V[0])
        if (selfIntersects(built) != null) {
            solved = false; err = "cross"
            conflict = computed.ifEmpty { ids.filterIndexed { i, _ -> lens[i] != null } }
        } else verts = built
    }
    val either = s.either.map { ids[it] }
    val walls = ids.mapIndexed { i, id ->
        val d = r.dim(id)
        val st = when {
            d.pending != null -> "recv"
            d.v != null && id in conflict -> "bad"
            d.v != null -> "conf"
            solved && id in computed -> "calc"
            id in either -> "unres"
            else -> "unset"
        }
        val len = d.v ?: if (solved) s.len[i]?.roundToInt() else null
        Wall(id, i + 1, len, id, id in computed && solved, verts[i], verts[(i + 1) % n], st)
    }
    val diagStatus = HashMap<String, String>(); val diagLen = HashMap<String, Int>()
    r.poly.diags.forEach { dg ->
        val d = r.dim(dg.id)
        val st = when {
            d.pending != null -> "recv"
            d.v == null -> "unset"
            !solved -> "conf"
            else -> { val dist = hypot(verts[dg.a].x - verts[dg.b].x, verts[dg.a].y - verts[dg.b].y).roundToInt(); diagLen[dg.id] = dist; if (abs(d.v - dist) <= SK_TOL) "ok" else "warn" }
        }
        diagStatus[dg.id] = st
    }
    val gap = if (s.err == "closure" && s.errVec != null) hypot(s.errVec.first, s.errVec.second).roundToInt() else 0
    return PolyGeo(verts, walls, solved, if (solved) null else err, conflict, either, s.measure.map { ids[it] }, s.some, if (solved) computed else emptyList(), diagStatus, diagLen, gap)
}

/* ---------------- polygons: shape checks ---------------- */

private fun cross(ax: Double, ay: Double, bx: Double, by: Double) = ax * by - ay * bx

/** Whether segments p1p2 and p3p4 meet (touching included). */
private fun segHit(p1: Pt, p2: Pt, p3: Pt, p4: Pt): Pt? {
    val d1x = p2.x - p1.x; val d1y = p2.y - p1.y; val d2x = p4.x - p3.x; val d2y = p4.y - p3.y
    val den = cross(d1x, d1y, d2x, d2y)
    if (abs(den) < EPS) {
        // collinear overlap
        if (abs(cross(p3.x - p1.x, p3.y - p1.y, d1x, d1y)) > EPS) return null
        val len2 = d1x * d1x + d1y * d1y; if (len2 < EPS) return null
        val t3 = ((p3.x - p1.x) * d1x + (p3.y - p1.y) * d1y) / len2
        val t4 = ((p4.x - p1.x) * d1x + (p4.y - p1.y) * d1y) / len2
        return if (max(t3, t4) >= 0 && min(t3, t4) <= 1) Pt(p3.x, p3.y) else null
    }
    val t = cross(p3.x - p1.x, p3.y - p1.y, d2x, d2y) / den
    val u = cross(p3.x - p1.x, p3.y - p1.y, d1x, d1y) / den
    return if (t in -EPS..1 + EPS && u in -EPS..1 + EPS) Pt(p1.x + t * d1x, p1.y + t * d1y) else null
}

/** The point where a closed outline crosses itself, or null (prototype skSelfX). */
fun selfIntersects(v: List<Pt>): Pt? {
    val n = v.size
    for (i in 0 until n) { val a = v[i]; val b = v[(i + 1) % n]; if (hypot(b.x - a.x, b.y - a.y) < EPS) return a }
    for (i in 0 until n) for (j in i + 1 until n) {
        val adj = j == i + 1 || (i == 0 && j == n - 1)
        val a1 = v[i]; val a2 = v[(i + 1) % n]; val b1 = v[j]; val b2 = v[(j + 1) % n]
        if (adj) {
            // a wall folding back on the next one
            val shared = if (j == i + 1) a2 else a1
            val other1 = if (j == i + 1) a1 else a2; val other2 = if (j == i + 1) b2 else b1
            val c = cross(other1.x - shared.x, other1.y - shared.y, other2.x - shared.x, other2.y - shared.y)
            val dot = (other1.x - shared.x) * (other2.x - shared.x) + (other1.y - shared.y) * (other2.y - shared.y)
            if (abs(c) < EPS && dot > 0) return shared
            continue
        }
        segHit(a1, a2, b1, b2)?.let { return it }
    }
    return null
}

/** Clockwise on screen (y down), first corner the top-most, then left-most (prototype skOrient). */
fun orient(v: List<Pt>): List<Pt> {
    var p = v
    if (shoelace(p) < 0) p = p.reversed()
    val minY = p.minOf { it.y }; val maxY = p.maxOf { it.y }
    val tol = 0.01 * (maxY - minY) + EPS
    val start = p.indices.filter { p[it].y <= minY + tol }.minBy { p[it].x }
    return p.drop(start) + p.take(start)
}

/** The L-shaped template: 6 walls A–F (prototype SK_LSHAPE). */
val L_SHAPE = listOf(Pt(0.0, 0.0), Pt(3000.0, 0.0), Pt(3000.0, 1500.0), Pt(6000.0, 1500.0), Pt(6000.0, 5000.0), Pt(0.0, 5000.0))

/** A new drawn room with one empty measurement per wall (prototype skMakeRoom). */
fun polyDims(n: Int): Map<String, Dim> = polyWallIds(n).associateWith { Dim() } + mapOf("H" to Dim(), "T" to Dim(200, "default"))
