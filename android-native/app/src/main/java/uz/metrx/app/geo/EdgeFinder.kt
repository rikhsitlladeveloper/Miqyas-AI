package uz.metrx.app.geo

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sign
import kotlin.math.sin
import kotlin.math.sqrt

/*
 * Photo edge measuring (part 2): the straight edges and corners of a photo, found on the phone and offline, so a
 * measuring line's ends can snap onto a table's, door's or cabinet's edges. Our own small finder (no OpenCV), the same
 * steps as the approved mockup (design/camera/edge-measure-mockup.html) and, later, the iPhone app:
 * blur → gradients → thin edges → keep strong ones → group pixels of one direction into straight segments → join
 * the pieces of one edge → corners where two edges end together → the best rectangle of four edges.
 * It works on a small grey copy of the photo (about 420 px on the long side); results are in the item's units.
 */

/** A straight edge from (x1, y1) to (x2, y2). */
data class ESeg(val x1: Float, val y1: Float, val x2: Float, val y2: Float) {
    val len get() = hypot(x2 - x1, y2 - y1)
    val ang get() = atan2(y2 - y1, x2 - x1)
}

/** A corner where edges [a] and [b] end together. */
data class ECorner(val x: Float, val y: Float, val a: Int, val b: Int)

/** Four corners in order, and the edges along its sides: side i runs from pts[i] to pts[i+1] along segs[i]. */
data class ERect(val pts: List<Pair<Float, Float>>, val segs: List<Int>)

data class PhotoEdges(val segs: List<ESeg>, val corners: List<ECorner>, val rect: ERect?) {
    companion object { val NONE = PhotoEdges(emptyList(), emptyList(), null) }
}

object EdgeFinder {
    /** The long side of the grey copy the finder works on. */
    const val WORK = 420

    /**
     * PhotoEdges of a grey image [g] ([w] × [h], 0–255), given back in units where the whole image is [outW] × [outH].
     */
    fun find(g: FloatArray, w: Int, h: Int, outW: Float, outH: Float): PhotoEdges {
        val n = w * h
        if (w < 8 || h < 8 || g.size < n) return PhotoEdges.NONE
        // 5-tap blur, both directions
        val k = floatArrayOf(1f, 4f, 6f, 4f, 1f)
        val tmp = FloatArray(n); val bl = FloatArray(n)
        for (y in 0 until h) for (x in 0 until w) {
            var s = 0f; for (j in -2..2) s += k[j + 2] * g[y * w + (x + j).coerceIn(0, w - 1)]; tmp[y * w + x] = s / 16f
        }
        for (y in 0 until h) for (x in 0 until w) {
            var s = 0f; for (j in -2..2) s += k[j + 2] * tmp[(y + j).coerceIn(0, h - 1) * w + x]; bl[y * w + x] = s / 16f
        }
        // gradients
        val gx = FloatArray(n); val gy = FloatArray(n); val mg = FloatArray(n)
        for (y in 1 until h - 1) for (x in 1 until w - 1) {
            val i = y * w + x
            val a = bl[i - w - 1]; val b = bl[i - w]; val c = bl[i - w + 1]; val d = bl[i - 1]; val f = bl[i + 1]
            val gg = bl[i + w - 1]; val hh = bl[i + w]; val ii = bl[i + w + 1]
            val X = (c + 2 * f + ii) - (a + 2 * d + gg); val Y = (gg + 2 * hh + ii) - (a + 2 * b + c)
            gx[i] = X; gy[i] = Y; mg[i] = hypot(X, Y)
        }
        // thin to one pixel
        val nm = FloatArray(n); var vals = FloatArray(1024); var nv = 0
        for (y in 1 until h - 1) for (x in 1 until w - 1) {
            val i = y * w + x; val m = mg[i]; if (m < 8f) continue
            val dx = (gx[i] / m).roundToInt(); val dy = (gy[i] / m).roundToInt()
            if (m >= mg[i + dy * w + dx] && m >= mg[i - dy * w - dx]) {
                nm[i] = m; if (nv == vals.size) vals = vals.copyOf(nv * 2); vals[nv++] = m
            }
        }
        if (nv == 0) return PhotoEdges.NONE
        vals = vals.copyOf(nv); vals.sort()
        // the bar follows the photo's strongest edges, so a white frame on a light wall still counts next to a dark door
        val hi = max(40f, vals[((nv - 1) * .98f).toInt()] * .18f); val lo = hi * .45f
        val edge = BooleanArray(n); val st = IntArray(n); var sp = 0
        val nb = intArrayOf(-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1)
        for (i in 0 until n) if (nm[i] >= hi) { edge[i] = true; st[sp++] = i }
        while (sp > 0) { val i = st[--sp]; for (o in nb) { val j = i + o; if (j in 0 until n && !edge[j] && nm[j] >= lo) { edge[j] = true; st[sp++] = j } } }

        // group edge pixels of one direction and fit straight segments
        val idx = (0 until n).filter { edge[it] }.sortedByDescending { mg[it] }
        val used = BooleanArray(n)
        fun ang(i: Int) = atan2(gy[i], gx[i])
        val tol = (PI / 8).toFloat(); val minLen = max(w, h) * .05f
        val raw = ArrayList<ESeg>()
        val reg = IntArray(n)
        for (s0 in idx) {
            if (used[s0]) continue
            used[s0] = true; var rn = 0; reg[rn++] = s0
            var cs = cos(2 * ang(s0)); var sn = sin(2 * ang(s0))
            var q = 0
            while (q < rn) {
                val i = reg[q++]
                for (o in nb) {
                    val j = i + o; if (j < 0 || j >= n || used[j] || !edge[j]) continue
                    val m = atan2(sn, cs) / 2
                    var df = abs(ang(j) - m) % PI.toFloat(); df = min(df, PI.toFloat() - df)
                    if (df < tol) { used[j] = true; reg[rn++] = j; cs += cos(2 * ang(j)); sn += sin(2 * ang(j)) }
                }
            }
            if (rn < 10) continue
            var mx = 0f; var my = 0f
            for (t in 0 until rn) { mx += reg[t] % w; my += reg[t] / w }
            mx /= rn; my /= rn
            var sxx = 0f; var syy = 0f; var sxy = 0f
            for (t in 0 until rn) { val x = reg[t] % w - mx; val y = reg[t] / w - my; sxx += x * x; syy += y * y; sxy += x * y }
            sxx /= rn; syy /= rn; sxy /= rn
            val tr = sxx + syy; val dt = sxx * syy - sxy * sxy; val disc = sqrt(max(0f, tr * tr / 4 - dt))
            val l1 = tr / 2 + disc; val l2 = tr / 2 - disc
            if (sqrt(max(0f, l2)) > 1.6f) continue          // too thick to be one straight edge
            var ux = sxy; var uy = l1 - sxx
            if (abs(ux) + abs(uy) < 1e-6f) { if (sxx >= syy) { ux = 1f; uy = 0f } else { ux = 0f; uy = 1f } }
            val ul = hypot(ux, uy); ux /= ul; uy /= ul
            var t0 = 1e9f; var t1 = -1e9f
            for (t in 0 until rn) { val p = (reg[t] % w - mx) * ux + (reg[t] / w - my) * uy; if (p < t0) t0 = p; if (p > t1) t1 = p }
            val len = t1 - t0
            if (len < minLen || rn / len < .6f) continue
            raw += ESeg(mx + ux * t0, my + uy * t0, mx + ux * t1, my + uy * t1)
        }

        // join pieces of one edge (broken by a cup, a leg or a shadow)
        val gapT = max(w, h) * .1f
        var merged = true
        while (merged) {
            merged = false
            outer@ for (i in raw.indices) for (j in i + 1 until raw.size) {
                val a = raw[i]; val b = raw[j]
                var da = abs(a.ang - b.ang) % PI.toFloat(); da = min(da, PI.toFloat() - da); if (da > .07f) continue
                val la = a.len; val ux = (a.x2 - a.x1) / la; val uy = (a.y2 - a.y1) / la
                fun dist(x: Float, y: Float) = abs((x - a.x1) * uy - (y - a.y1) * ux)
                if (dist(b.x1, b.y1) > 3f || dist(b.x2, b.y2) > 3f) continue
                fun p(x: Float, y: Float) = (x - a.x1) * ux + (y - a.y1) * uy
                val tb0 = min(p(b.x1, b.y1), p(b.x2, b.y2)); val tb1 = max(p(b.x1, b.y1), p(b.x2, b.y2))
                if (tb0 > la + gapT || tb1 < -gapT) continue
                val t0 = min(0f, tb0); val t1 = max(la, tb1)
                raw[i] = ESeg(a.x1 + ux * t0, a.y1 + uy * t0, a.x1 + ux * t1, a.y1 + uy * t1); raw.removeAt(j)
                merged = true; break@outer
            }
        }
        val sx = outW / w; val sy = outH / h
        val all = raw.sortedByDescending { it.len }.take(60).map { ESeg(it.x1 * sx, it.y1 * sy, it.x2 * sx, it.y2 * sy) }
        val W = outW; val H = outH
        val tolC = max(W, H) * .03f

        // corners: two edges meeting at their ends
        fun joins(segs: List<ESeg>): Pair<List<ECorner>, List<Map<Int, ECorner>>> {
            val corners = ArrayList<ECorner>()
            val adj = List(segs.size) { HashMap<Int, ECorner>() }
            for (i in segs.indices) for (j in i + 1 until segs.size) {
                val a = segs[i]; val b = segs[j]
                var da = abs(a.ang - b.ang) % PI.toFloat(); da = min(da, PI.toFloat() - da); if (da < .44f) continue
                val d1x = a.x2 - a.x1; val d1y = a.y2 - a.y1; val d2x = b.x2 - b.x1; val d2y = b.y2 - b.y1
                val den = d1x * d2y - d1y * d2x; if (abs(den) < 1e-6f) continue
                val t = ((b.x1 - a.x1) * d2y - (b.y1 - a.y1) * d2x) / den
                val px = a.x1 + t * d1x; val py = a.y1 + t * d1y
                if (px < -tolC || py < -tolC || px > W + tolC || py > H + tolC) continue
                fun near(s: ESeg) = min(hypot(px - s.x1, py - s.y1), hypot(px - s.x2, py - s.y2))
                val c = ECorner(px, py, i, j); val na = near(a); val nbb = near(b)
                // for the rectangle a side may stop short of its corner (hidden by a leg or a shadow)
                if (na <= max(tolC, a.len) && nbb <= max(tolC, b.len)) { adj[i][j] = c; adj[j][i] = c }
                if (na > tolC || nbb > tolC) continue
                if (corners.none { hypot(it.x - px, it.y - py) < tolC / 2 }) corners += c
            }
            return corners to adj
        }
        // short strokes that meet no other edge are mostly texture (a rug's pattern, wood grain): left out
        val c0 = joins(all).first
        val segs = all.filterIndexed { i, s -> s.len >= max(W, H) * .09f || c0.any { it.a == i || it.b == i } }.take(50)
        val (corners, adj) = joins(segs)

        // the best rectangle: four edges joined end to end, every side mostly seen
        var rect: ERect? = null; var best = 0f
        for (i in segs.indices) for ((j, c1) in adj[i]) {
            if (j <= i) continue
            for ((kk, c2) in adj[j]) {
                if (kk <= i) continue
                for ((l, c3) in adj[kk]) {
                    if (l <= i || l == j) continue
                    val c0 = adj[l][i] ?: continue
                    val q = listOf(c0, c1, c2, c3)
                    var sg = 0f; var ok = true
                    for (m in 0 until 4) {
                        val p = q[m]; val r = q[(m + 1) % 4]; val s = q[(m + 2) % 4]
                        val cr = sign((r.x - p.x) * (s.y - r.y) - (r.y - p.y) * (s.x - r.x))
                        if (cr == 0f || (sg != 0f && cr != sg)) { ok = false; break }; sg = cr
                    }
                    if (!ok) continue
                    var ar = 0f; for (m in 0 until 4) { val p = q[m]; val r = q[(m + 1) % 4]; ar += p.x * r.y - r.x * p.y }
                    ar = abs(ar / 2); if (ar < W * H * .03f) continue
                    val sides = listOf(i, j, kk, l)
                    val cov = sides.mapIndexed { m, sgi -> min(1f, segs[sgi].len / max(1f, hypot(q[(m + 1) % 4].x - q[m].x, q[(m + 1) % 4].y - q[m].y))) }.min()
                    if (cov < .45f) continue
                    val score = ar * cov
                    if (score > best) { best = score; rect = ERect(q.map { it.x to it.y }, sides) }
                }
            }
        }
        return PhotoEdges(segs, corners, rect)
    }

    /** The grey value of an ARGB pixel. */
    fun grey(argb: Int): Float = .299f * ((argb shr 16) and 255) + .587f * ((argb shr 8) and 255) + .114f * (argb and 255)
}

/**
 * The two sides of a found rectangle to measure (part 3): the ones meeting at its corner nearest the photo's bottom
 * left, the more level one first (a table's length, a door's width), then the other (depth or height).
 */
fun rectSides(r: ERect): List<Pair<Pair<Float, Float>, Pair<Float, Float>>> {
    val p = r.pts; val n = p.size
    val i = p.indices.maxByOrNull { p[it].second - p[it].first } ?: return emptyList()
    val c = p[i]; val s1 = c to p[(i + 1) % n]; val s2 = c to p[(i + n - 1) % n]
    fun level(s: Pair<Pair<Float, Float>, Pair<Float, Float>>) = abs(s.second.first - s.first.first) / max(1e-3f, hypot(s.second.first - s.first.first, s.second.second - s.first.second))
    return if (level(s1) >= level(s2)) listOf(s1, s2) else listOf(s2, s1)
}

/* ---------------- snapping a line's end onto the edges ---------------- */

/** What a line's end is stuck to: a corner (edges [a] and [b]) or an edge ([a], b = -1). */
data class ESnap(val corner: Boolean, val a: Int, val b: Int = -1) {
    val segs get() = if (b >= 0) listOf(a, b) else listOf(a)
}

/** A point after snapping, and what it is stuck to (null: free). */
data class ESnapped(val x: Float, val y: Float, val snap: ESnap?)

/**
 * The point at (x, y) moved onto a corner within [rCorner] (corners win), else onto the nearest edge within [rEdge];
 * all in the same units as the edges. Free when nothing is near.
 */
fun edgeSnap(e: PhotoEdges, x: Float, y: Float, rCorner: Float, rEdge: Float): ESnapped {
    var bc: ECorner? = null; var bd = rCorner
    for (c in e.corners) { val d = hypot(c.x - x, c.y - y); if (d <= bd) { bd = d; bc = c } }
    bc?.let { return ESnapped(it.x, it.y, ESnap(true, it.a, it.b)) }
    var bs = -1; var be = rEdge; var qx = 0f; var qy = 0f
    e.segs.forEachIndexed { i, s ->
        val dx = s.x2 - s.x1; val dy = s.y2 - s.y1; val l2 = dx * dx + dy * dy; if (l2 <= 0f) return@forEachIndexed
        val t = (((x - s.x1) * dx + (y - s.y1) * dy) / l2).coerceIn(0f, 1f)
        val px = s.x1 + t * dx; val py = s.y1 + t * dy; val d = hypot(px - x, py - y)
        if (d <= be) { be = d; bs = i; qx = px; qy = py }
    }
    return if (bs >= 0) ESnapped(qx, qy, ESnap(false, bs)) else ESnapped(x, y, null)
}

/** The edge both ends are stuck to, or null. */
fun sharedEdge(a: ESnap?, b: ESnap?): Int? = if (a == null || b == null) null else a.segs.firstOrNull { it in b.segs }

/** Both ends on one edge: the line lies exactly along it (each end moved straight onto the edge's line). */
fun lockAlong(e: PhotoEdges, a: ESnapped, b: ESnapped): Pair<ESnapped, ESnapped> {
    val s = sharedEdge(a.snap, b.snap)?.let { e.segs.getOrNull(it) } ?: return a to b
    val dx = s.x2 - s.x1; val dy = s.y2 - s.y1; val l2 = dx * dx + dy * dy; if (l2 <= 0f) return a to b
    fun on(p: ESnapped): ESnapped { val t = ((p.x - s.x1) * dx + (p.y - s.y1) * dy) / l2; return p.copy(x = s.x1 + t * dx, y = s.y1 + t * dy) }
    return on(a) to on(b)
}
