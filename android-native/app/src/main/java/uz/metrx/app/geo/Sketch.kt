package uz.metrx.app.geo

import uz.metrx.app.data.Pt
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

/*
 * Turning a finger stroke or tapped corners into a room outline (prototype skProcess, skClean, skSnapPoly).
 * Works in sketch-pad units: the pad is 360 × 440 units and 1 unit = 25 mm (9 × 11 m).
 */

const val PAD_W = 360f
const val PAD_H = 440f
const val PAD_MM = 25.0

data class SketchResult(val verts: List<Pt>, val closed: Boolean, val err: String?, val cross: Pt? = null)

private fun d(a: Pt, b: Pt) = hypot(a.x - b.x, a.y - b.y)

/** Ramer–Douglas–Peucker simplification of an open polyline. */
fun rdp(p: List<Pt>, eps: Double): List<Pt> {
    if (p.size < 3) return p
    val a = p.first(); val b = p.last()
    var idx = -1; var best = 0.0
    val len = d(a, b)
    for (i in 1 until p.size - 1) {
        val q = p[i]
        val dist = if (len < 1e-9) d(q, a) else abs((b.x - a.x) * (a.y - q.y) - (a.x - q.x) * (b.y - a.y)) / len
        if (dist > best) { best = dist; idx = i }
    }
    if (best <= eps || idx < 0) return listOf(a, b)
    val l = rdp(p.subList(0, idx + 1), eps); val r = rdp(p.subList(idx, p.size), eps)
    return l.dropLast(1) + r
}

private fun turn(a: Pt, b: Pt, c: Pt): Double {
    val a1 = atan2(b.y - a.y, b.x - a.x); val a2 = atan2(c.y - b.y, c.x - b.x)
    var t = a2 - a1; while (t > PI) t -= 2 * PI; while (t < -PI) t += 2 * PI
    return abs(t)
}

/** Merges the shortest too-short edge and removes nearly straight corners until nothing changes (prototype skClean). */
fun clean(v0: List<Pt>, closed: Boolean, minLen: Double): List<Pt> {
    var v = v0.toMutableList()
    var changed = true
    while (changed && v.size > 2) {
        changed = false
        val n = v.size
        val edges = if (closed) n else n - 1
        var si = -1; var sl = Double.MAX_VALUE
        for (i in 0 until edges) { val l = d(v[i], v[(i + 1) % n]); if (l < sl) { sl = l; si = i } }
        if (si >= 0 && sl < minLen && v.size > (if (closed) 3 else 2)) {
            val j = (si + 1) % n
            if (!closed && si == 0) v.removeAt(1)
            else if (!closed && j == n - 1) v.removeAt(n - 2)
            else {
                val m = Pt((v[si].x + v[j].x) / 2, (v[si].y + v[j].y) / 2)
                v[si] = m; v.removeAt(j)
            }
            changed = true; continue
        }
        val range = if (closed) 0 until n else 1 until n - 1
        for (i in range) {
            val a = v[(i - 1 + n) % n]; val b = v[i]; val c = v[(i + 1) % n]
            if (turn(a, b, c) < .21) { v.removeAt(i); changed = true; break }
        }
    }
    return v
}

/** Rounds every wall to 45°, joins walls that point the same way and closes the outline by least squares (prototype skSnapPoly). */
fun snapPoly(v: List<Pt>, closed: Boolean): List<Pt>? {
    val n = v.size
    val edges = if (closed) n else n - 1
    if (edges < 1) return null
    val dirs = ArrayList<Double>(); val lens = ArrayList<Double>()
    for (i in 0 until edges) {
        val a = v[i]; val b = v[(i + 1) % n]
        dirs += snapAngle(atan2(b.y - a.y, b.x - a.x)); lens += d(a, b)
    }
    // merge consecutive edges with the same direction; opposite ones cancel
    val md = ArrayList<Double>(); val ml = ArrayList<Double>()
    for (i in dirs.indices) {
        if (md.isNotEmpty()) {
            val diff = abs(((dirs[i] - md.last()) % (2 * PI) + 3 * PI) % (2 * PI) - PI)
            if (diff < 1e-6 || abs(diff - PI) < 1e-6) {
                val same = abs(cos(dirs[i] - md.last()) - 1) < 1e-6
                val l = if (same) ml.last() + lens[i] else ml.last() - lens[i]
                if (l < 0) { md[md.lastIndex] = dirs[i]; ml[ml.lastIndex] = -l } else ml[ml.lastIndex] = l
                continue
            }
        }
        md += dirs[i]; ml += lens[i]
    }
    if (closed && md.size >= 2 && abs(cos(md.first() - md.last()) - 1) < 1e-6) { ml[0] += ml.last(); md.removeAt(md.lastIndex); ml.removeAt(ml.lastIndex) }
    if (closed && md.size < 3) return null
    val orig = ml.toList()
    if (closed) {
        var ex = 0.0; var ey = 0.0; var a = 0.0; var b = 0.0; var c = 0.0
        for (i in md.indices) { val ux = cos(md[i]); val uy = sin(md[i]); ex += ml[i] * ux; ey += ml[i] * uy; a += ux * ux; b += ux * uy; c += uy * uy }
        val det = a * c - b * b
        if (abs(det) < 1e-9) return null
        val lx = (c * ex - b * ey) / det; val ly = (a * ey - b * ex) / det
        for (i in md.indices) ml[i] = ml[i] - (cos(md[i]) * lx + sin(md[i]) * ly)
    }
    for (i in md.indices) if (ml[i] < max(.3 * orig[i], 1.0)) return null
    // rebuild: closed outlines keep their centroid, open paths their start
    var x = v[0].x; var y = v[0].y
    val out = ArrayList<Pt>()
    out += Pt(x, y)
    for (i in md.indices) { x += ml[i] * cos(md[i]); y += ml[i] * sin(md[i]); out += Pt(x, y) }
    val pts = if (closed) out.dropLast(1) else out
    if (closed) {
        val cx0 = v.sumOf { it.x } / v.size; val cy0 = v.sumOf { it.y } / v.size
        val cx1 = pts.sumOf { it.x } / pts.size; val cy1 = pts.sumOf { it.y } / pts.size
        return clean(pts.map { Pt(it.x + cx0 - cx1, it.y + cy0 - cy1) }, true, 1.0)
    }
    return clean(pts, false, 1.0)
}

/** The whole pipeline (prototype skProcess). [tap] = corners were tapped; [tapClosed] = the last tap closed the shape. */
fun processSketch(raw0: List<Pt>, tap: Boolean, tapClosed: Boolean, snap: Boolean): SketchResult {
    val raw = ArrayList<Pt>()
    raw0.forEach { if (raw.isEmpty() || d(raw.last(), it) >= .5) raw += it }
    if (raw.size < (if (tap) 2 else 5)) return SketchResult(raw, false, "short")
    val bw = raw.maxOf { it.x } - raw.minOf { it.x }; val bh = raw.maxOf { it.y } - raw.minOf { it.y }
    val Dg = hypot(bw, bh)
    var closed: Boolean
    var v: List<Pt>
    if (!tap) {
        if (Dg < 40) return SketchResult(raw, false, "short")
        val ct = max(26.0, .15 * Dg)
        closed = d(raw.last(), raw.first()) < ct
        v = rdp(raw, max(6.0, .035 * Dg))
        if (closed && v.size > 2 && d(v.last(), v.first()) < ct) v = v.dropLast(1)
    } else { closed = tapClosed; v = raw }
    v = clean(v, closed, max(if (tap) 4.0 else 10.0, .05 * Dg))
    if (closed && v.size < 3) return SketchResult(v, true, "few")
    if (snap && (closed || tap)) snapPoly(v, closed)?.let { v = it }
    if (v.size > 20) return SketchResult(v, closed, "many")
    if (closed) {
        selfIntersects(v)?.let { return SketchResult(v, true, "cross", it) }
        return SketchResult(orient(v), true, null)
    }
    return SketchResult(v, false, "open")
}

/** Pad units to millimetres on a 10 mm grid, duplicates dropped, clockwise from the top-left corner. */
fun sketchToMm(v: List<Pt>): List<Pt> {
    val mm = ArrayList<Pt>()
    v.forEach { p -> val q = Pt(((p.x * PAD_MM / 10).roundToInt() * 10).toDouble(), ((p.y * PAD_MM / 10).roundToInt() * 10).toDouble()); if (mm.isEmpty() || mm.last() != q) mm += q }
    if (mm.size > 1 && mm.first() == mm.last()) mm.removeAt(mm.lastIndex)
    return if (mm.size >= 3) orient(mm) else mm
}
