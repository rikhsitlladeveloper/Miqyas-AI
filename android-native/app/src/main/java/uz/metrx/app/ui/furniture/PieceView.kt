package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.sp
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.K_BASE_D
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.freeRoom
import uz.metrx.app.furniture.isUpper
import uz.metrx.app.furniture.outerH
import uz.metrx.app.furniture.wardOfF
import uz.metrx.app.furniture.worktopTop
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.furniture3D
import uz.metrx.app.geo.rgbOf
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.tan

/*
 * A piece of furniture drawn in 3D for the gallery's cards and the size steps (gallery v5, 21 Oct 2026): the designer's
 * own boards (geo/furniture3D) on the floor of the piece's made-up room, the walls it stands on behind it, flat-shaded
 * and drawn back to front. A size step tints the run it asks about and draws that size as a blue dimension line.
 */

/** A face to draw: its corners, outward normal, colour and opacity, and what it belongs to (a wall id, "floor" or "wall"). */
class SFace(val pts: List<V3>, val n: V3, val rgb: Int, val op: Float, val tag: String?)

/** A size shown on the piece: from [a] to [b], with end ticks along [tick]. */
class DimLine(val a: V3, val b: V3, val tick: V3)

/** One board: its six faces, as furniture3D makes them for each box, with its corners and face planes for the drawing order. */
class SBox(val faces: List<SFace>) {
    /** The eight corners, x y z one after another (the first two faces hold them all). */
    val pts = DoubleArray(24).also { a -> (faces[0].pts + faces[1].pts).forEachIndexed { i, q -> a[3 * i] = q.x; a[3 * i + 1] = q.y; a[3 * i + 2] = q.z } }
    /** Each face's plane: its outward normal and n·p, four numbers a face. */
    val planes = DoubleArray(24).also { a -> faces.forEachIndexed { i, f -> a[4 * i] = f.n.x; a[4 * i + 1] = f.n.y; a[4 * i + 2] = f.n.z; a[4 * i + 3] = f.n.dot(f.pts[0]) } }
}

/**
 * The faces of a piece ([env]: floor and walls, drawn first; [furn]: the boards), its middle and size for the camera,
 * the dimension line of each step key and what each step tints ([tint]: a wall id, ISLAND or "wall").
 */
class PieceScene(val env: List<SFace>, val furn: List<SBox>, val center: V3, val radius: Double, val dims: Map<String, DimLine>, val tint: Map<String, String>, val az0: Double,
    /** The middle and size with the dimension lines in, for a step that shows one. */
    val dimCenter: V3 = center, val dimRadius: Double = radius,
    /** The corners of the boards' bounds, and of the bounds with the dimension lines in: what the camera fits in. */
    val ext: List<V3> = emptyList(), val dimExt: List<V3> = ext)

private fun corners(x0: Double, y0: Double, z0: Double, x1: Double, y1: Double, z1: Double) =
    listOf(x0, x1).flatMap { x -> listOf(y0, y1).flatMap { y -> listOf(V3(x, y, z0), V3(x, y, z1)) } }

private val UP = V3(0.0, 1.0, 0.0)
private const val WALL_RGB = 0xEEF1F7
private const val FLOOR_RGB = 0xE3E8F0
private const val HI_RGB = 0x9FB2FF
private val BLUE = Color(0xFF3550E0)

fun pieceScene(f: Furniture, ws: Workshop, mats: List<Mat>): PieceScene {
    val room = freeRoom(f)
    val shell = buildShell(listOf(room), true, true)
    val b = shell.bases
    val fur = furniture3D(listOf(f), b, ws, { id -> rgbOf(mats.firstOrNull { it.id == id }?.rgb ?: "#F5F5F2") }, emptySet())
    // every box of furniture3D adds its six faces to its part one after another
    val furn = fur.parts.flatMap { p -> p.faces.chunked(6).filter { it.size == 6 }.map { b -> SBox(b.map { SFace(it.pts, it.n, p.rgb, p.op, p.wall) }) } }
    val env = ArrayList<SFace>()
    shell.parts.filter { it.role == Role.FLOOR }.forEach { p -> p.faces.forEach { env += SFace(it.pts, it.n, FLOOR_RGB, 1f, "floor") } }
    val H = (room.dim("H").v ?: 2700) / 1000.0
    val onWalls = f.walls.filter { it != ISLAND }
    onWalls.forEach { w -> b[w]?.let { bas -> env += SFace(listOf(bas.at(0.0, 0.0, 0.0), bas.at(bas.len, 0.0, 0.0), bas.at(bas.len, H, 0.0), bas.at(0.0, H, 0.0)), V3(bas.nx, 0.0, bas.nz), WALL_RGB, .95f, "wall") } }
    // the middle and size of the boards alone
    var x0 = Double.MAX_VALUE; var y0 = Double.MAX_VALUE; var z0 = Double.MAX_VALUE; var x1 = -Double.MAX_VALUE; var y1 = -Double.MAX_VALUE; var z1 = -Double.MAX_VALUE
    furn.forEach { bx -> (bx.faces[0].pts + bx.faces[1].pts).forEach { q -> x0 = min(x0, q.x); y0 = min(y0, q.y); z0 = min(z0, q.z); x1 = max(x1, q.x); y1 = max(y1, q.y); z1 = max(z1, q.z) } }
    if (furn.isEmpty()) { x0 = 0.0; y0 = 0.0; z0 = 0.0; x1 = 1.0; y1 = 1.0; z1 = 1.0 }
    val dims = HashMap<String, DimLine>(); val tint = HashMap<String, String>()
    if (f.kind == "kitchen") {
        val y = (worktopTop(uz.metrx.app.furniture.wsOf(f, ws)) + 30) / 1000.0
        onWalls.forEachIndexed { i, w ->
            val bas = b[w] ?: return@forEachIndexed
            val l = (f.free?.sides?.getOrNull(i) ?: (bas.len * 1000).toInt()) / 1000.0
            dims["s$i"] = DimLine(bas.at(0.0, y, .68), bas.at(l, y, .68), UP); tint["s$i"] = w
        }
        // the island (or peninsula) where furniture3D puts it: its length past its seating side
        val w0 = onWalls.firstOrNull()?.let { b[it] }
        val isl = f.modules.filter { it.wall == ISLAND && !isUpper(it) }.sumOf { it.w } / 1000.0
        if (w0 != null && isl > 0) {
            val ip = uz.metrx.app.furniture.islandPose(f, (w0.len * 1000).toInt())
            val ib = uz.metrx.app.geo.poseBasis(b[ip.ref] ?: w0, ip, isl)
            dims["isl"] = DimLine(ib.at(0.0, y, -.40), ib.at(isl, y, -.40), UP); tint["isl"] = ISLAND
        }
        if (w0 != null) { dims["h"] = DimLine(w0.at(0.0, 0.0, .04), w0.at(0.0, H, .04), w0.dir(1.0, 0.0)); tint["h"] = "wall" }
    } else wardOfF(f)?.let { m ->
        val bas = b[f.walls.firstOrNull() ?: "A"] ?: b["A"] ?: return@let
        // the run on the first wall (a stenka's pieces, a corner piece's first arm), its depth and its top
        val bs = uz.metrx.app.furniture.boxes(f)
        val run = uz.metrx.app.furniture.firstRun(f).ifEmpty { listOf(m) }
        val xa = run.minOf { it.x } / 1000.0; val w = (run.maxOf { it.x + it.w } - run.minOf { it.x }) / 1000.0
        val d = run.maxOf { it.d } / 1000.0
        val h = bs.maxOf { uz.metrx.app.furniture.topOf(it, ws) } / 1000.0
        // a hung cabinet's (or a mirror panel's) height is its own, from its bottom
        val lo = if (f.type in uz.metrx.app.furniture.HUNG_TYPES || f.type == "mirrorP") m.elev / 1000.0 else 0.0
        dims["w"] = DimLine(bas.at(xa, lo + .02, d + .2), bas.at(xa + w, lo + .02, d + .2), UP)
        dims["h"] = DimLine(bas.at(xa + w + .15, lo, d), bas.at(xa + w + .15, h, d), bas.dir(1.0, 0.0))
        dims["d"] = DimLine(bas.at(xa + w + .08, h + .08, 0.0), bas.at(xa + w + .08, h + .08, d), UP)
        if (lo > 0) dims["e"] = DimLine(bas.at(xa + w + .15, 0.0, d), bas.at(xa + w + .15, lo, d), bas.dir(1.0, 0.0))
        // a corner piece's second arm, from the corner
        f.walls.getOrNull(1)?.let { wb -> b[wb]?.let { bb ->
            val on = bs.filter { it.wall == wb }
            if (on.isNotEmpty()) { val db = on.maxOf { it.d } / 1000.0; dims["w2"] = DimLine(bb.at(0.0, .02, db + .2), bb.at(on.maxOf { it.x + it.w } / 1000.0, .02, db + .2), UP) }
        } }
        val o = m.opt
        when (m.type) {
            "bed" -> {
                val W = m.w / 1000.0; val D = m.d / 1000.0; val H = m.h / 1000.0
                dims["mw"] = DimLine(bas.at(xa, H + .05, D + .12), bas.at(xa + W, H + .05, D + .12), UP)
                dims["ml"] = DimLine(bas.at(xa + W + .12, H + .05, 0.0), bas.at(xa + W + .12, H + .05, D), UP)
                dims["h"] = DimLine(bas.at(xa + W + .12, 0.0, D), bas.at(xa + W + .12, H, D), bas.dir(1.0, 0.0))
                dims["hb"] = DimLine(bas.at(xa - .12, 0.0, .02), bas.at(xa - .12, (o?.hb ?: 1000) / 1000.0, .02), bas.dir(1.0, 0.0))
            }
            "bunk", "loft" -> {
                val W = m.w / 1000.0; val D = m.d / 1000.0; val H = m.h / 1000.0
                dims["ml"] = DimLine(bas.at(xa, .02, D + .15), bas.at(xa + W, .02, D + .15), UP)
                dims["mw"] = DimLine(bas.at(xa + W + .1, H + .05, 0.0), bas.at(xa + W + .1, H + .05, D - uz.metrx.app.furniture.LADDER_D / 1000.0), UP)
            }
        }
        // a dressing table's mirror
        f.modules.firstOrNull { it.type == "mirror" }?.let { r ->
            val x0 = r.x / 1000.0; val x1 = (r.x + r.w) / 1000.0; val e = r.elev / 1000.0; val t = (r.elev + r.h) / 1000.0
            dims["rw"] = DimLine(bas.at(x0, t + .06, .03), bas.at(x1, t + .06, .03), UP)
            dims["rh"] = DimLine(bas.at(x1 + .08, e, .03), bas.at(x1 + .08, t, .03), bas.dir(1.0, 0.0))
        }
    }
    val center = V3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    val radius = max(.45, V3(x1 - x0, y1 - y0, z1 - z0).len() / 2)
    val ext = corners(x0, y0, z0, x1, y1, z1)
    // a step's camera takes in the dimension lines too, so a size in front of the piece stays in the picture
    dims.values.forEach { d -> listOf(d.a, d.b).forEach { q -> x0 = min(x0, q.x); y0 = min(y0, q.y); z0 = min(z0, q.z); x1 = max(x1, q.x); y1 = max(y1, q.y); z1 = max(z1, q.z) } }
    val dimCenter = V3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    val dimRadius = max(.45, V3(x1 - x0, y1 - y0, z1 - z0).len() / 2)
    // an L turns into the right-hand wall: seen from the left so both runs show from inside
    val az0 = when (f.layout.takeIf { f.kind == "kitchen" } ?: "L".takeIf { f.type in uz.metrx.app.furniture.CORNER_TYPES }) { "L" -> -.6; "U" -> .15; null -> .55; else -> .6 }
    return PieceScene(env, furn, center, radius, dims, tint, az0, dimCenter, dimRadius, ext, corners(x0, y0, z0, x1, y1, z1))
}

private fun cross(a: V3, b: V3) = V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)

/** A camera round the piece: [az] turns it from the scene's own angle, the piece filling the picture. */
private class PCam(s: PieceScene, w: Float, h: Float, az: Double, withDims: Boolean) {
    private val half = 16.0 * Math.PI / 180
    val e: V3; private val r: V3; private val u: V3; private val f: V3; private val foc: Double; private val cx = w / 2f; private val cy = h / 2f
    init {
        val fit = min(half, atan(tan(half) * w / h))
        val c = if (withDims) s.dimCenter else s.center
        val a = s.az0 + az; val el = .5
        val back = V3(sin(a) * cos(el), sin(el), cos(a) * cos(el))
        f = back * -1.0; r = cross(f, UP).unit(); u = cross(r, f)
        // near enough that every corner of the bounds is in the picture with a little room round it (a tall piece's
        // top and bottom too), else round its bounding sphere
        val tv = tan(half); val th = tv * w / h
        val ext = if (withDims) s.dimExt else s.ext
        fun fitAt(m: V3) = ext.maxOf { q -> val v = q - m; 1.08 * max(kotlin.math.abs(v.dot(r)) / th, kotlin.math.abs(v.dot(u)) / tv) - v.dot(f) }
        var m = c
        // the bounds' picture centred: the camera slides across until it is
        if (ext.isNotEmpty()) repeat(3) {
            val dist = fitAt(m)
            var lx = Double.MAX_VALUE; var hx = -Double.MAX_VALUE; var ly = Double.MAX_VALUE; var hy = -Double.MAX_VALUE
            ext.forEach { q -> val v = q - m; val z = dist + v.dot(f); lx = min(lx, v.dot(r) / z); hx = max(hx, v.dot(r) / z); ly = min(ly, v.dot(u) / z); hy = max(hy, v.dot(u) / z) }
            m = m + r * ((lx + hx) / 2 * dist) + u * ((ly + hy) / 2 * dist)
        }
        val dist = if (ext.isEmpty()) (if (withDims) s.dimRadius else s.radius) / sin(fit) else fitAt(m)
        e = m + back * dist
        foc = (h / 2) / tan(half)
    }
    fun p(q: V3): Offset? {
        val d = q - e; val z = d.dot(f)
        if (z < .05) return null
        return Offset((cx + d.dot(r) / z * foc).toFloat(), (cy - d.dot(u) / z * foc).toFloat())
    }
    fun depth(q: V3) = (q - e).dot(f)
}

private val LIGHT = V3(.35, .85, .45).unit()

private fun mix(a: Int, b: Int, k: Float): Int {
    fun c(s: Int) = (((a shr s) and 0xFF) * (1 - k) + ((b shr s) and 0xFF) * k).toInt().coerceIn(0, 255)
    return (c(16) shl 16) or (c(8) shl 8) or c(0)
}

private fun shade(rgb: Int, n: V3, op: Float, env: Boolean = false): Color {
    // the floor and the walls stay light: they are only there to stand the piece in its place
    val k = if (env) (.93 + .07 * max(0.0, n.dot(LIGHT))).toFloat() else (.66 + .34 * max(0.0, n.dot(LIGHT))).toFloat()
    fun c(s: Int) = (((rgb shr s) and 0xFF) * k).toInt().coerceIn(0, 255)
    return Color(c(16), c(8), c(0), (op * 255).toInt().coerceIn(0, 255))
}

/** Whether every corner of [q] is on the outer side of face [i] of [b]. */
private fun outside(b: SBox, i: Int, q: SBox): Boolean {
    val p = b.planes; val nx = p[4 * i]; val ny = p[4 * i + 1]; val nz = p[4 * i + 2]; val d = p[4 * i + 3] - 1e-6
    for (k in 0 until 8) if (nx * q.pts[3 * k] + ny * q.pts[3 * k + 1] + nz * q.pts[3 * k + 2] < d) return false
    return true
}

/**
 * 1 when [a] goes before [b] (only [b] can hide [a]), -1 the other way, 0 when either may go first (neither hides the
 * other) or no face plane of either parts them. A face plane with one box beyond it and the camera on that side says the
 * other box cannot hide it.
 */
private fun before(a: SBox, b: SBox, e: V3): Int {
    var aFirst = false; var bFirst = false
    for (i in 0 until 6) if (outside(a, i, b)) { if (a.faces[i].n.dot(e) > a.planes[4 * i + 3]) aFirst = true else bFirst = true }
    for (i in 0 until 6) if (outside(b, i, a)) { if (b.faces[i].n.dot(e) > b.planes[4 * i + 3]) bFirst = true else aFirst = true }
    return if (aFirst == bFirst) 0 else if (aFirst) 1 else -1
}

/**
 * The boards back to front. Sorting faces by their middles shows a shelf through its door and hides a handle behind
 * it, so whole boxes go in order: of two whose pictures overlap, the one beyond a face plane of the other, from the
 * camera, goes first; the rest (and any loop) by their distance.
 */
private fun drawOrder(bs: List<SBox>, cam: PCam): List<SBox> {
    val n = bs.size
    val rect = Array(n) { i ->
        var x0 = Float.MAX_VALUE; var y0 = Float.MAX_VALUE; var x1 = -Float.MAX_VALUE; var y1 = -Float.MAX_VALUE
        val p = bs[i].pts
        for (k in 0 until 8) {
            // a corner behind the camera: it may overlap anything
            val o = cam.p(V3(p[3 * k], p[3 * k + 1], p[3 * k + 2])) ?: return@Array floatArrayOf(-Float.MAX_VALUE, -Float.MAX_VALUE, Float.MAX_VALUE, Float.MAX_VALUE)
            x0 = min(x0, o.x); y0 = min(y0, o.y); x1 = max(x1, o.x); y1 = max(y1, o.y)
        }
        floatArrayOf(x0, y0, x1, y1)
    }
    val dist = DoubleArray(n) { i -> val p = bs[i].pts; (0 until 8).sumOf { k -> cam.depth(V3(p[3 * k], p[3 * k + 1], p[3 * k + 2])) } / 8 }
    val after = Array(n) { ArrayList<Int>() }; val need = IntArray(n)
    for (i in 0 until n) for (j in i + 1 until n) {
        val a = rect[i]; val b = rect[j]
        if (a[0] >= b[2] || b[0] >= a[2] || a[1] >= b[3] || b[1] >= a[3]) continue
        when (before(bs[i], bs[j], cam.e)) { 1 -> { after[i] += j; need[j]++ }; -1 -> { after[j] += i; need[i]++ } }
    }
    val ready = java.util.PriorityQueue<Int>(n.coerceAtLeast(1), compareByDescending { dist[it] })
    for (i in 0 until n) if (need[i] == 0) ready += i
    val done = BooleanArray(n); val out = ArrayList<SBox>(n)
    while (out.size < n) {
        // a loop (boxes that cut into each other): the farthest one left goes next
        val k = ready.poll() ?: (0 until n).filter { !done[it] }.maxBy { dist[it] }
        if (done[k]) continue
        done[k] = true; out += bs[k]
        for (j in after[k]) if (--need[j] == 0 && !done[j]) ready += j
    }
    return out
}

/** Each scene's box order for the last 3° step of turning it: worked out again only when it turns past the step. */
private val orderCache = java.util.WeakHashMap<PieceScene, Pair<Int, List<SBox>>>()

/** Draws the piece: walls facing the camera and the floor first, then the boards back to front; [hi] a step key to show. */
fun DrawScope.drawPiece(s: PieceScene, hi: String?, az: Float, label: String? = null, tm: TextMeasurer? = null) {
    drawRect(Color(0xFFF6F8FC))
    val cam = PCam(s, size.width, size.height, az.toDouble(), hi != null && s.dims.containsKey(hi))
    val tintTag = hi?.let { s.tint[it] }
    val edge = Color(0x401E293B)
    fun face(fc: SFace, faceOut: Boolean) {
        val pts = fc.pts.map { cam.p(it) ?: return }
        if (faceOut) {
            val c = V3(fc.pts.sumOf { it.x } / fc.pts.size, fc.pts.sumOf { it.y } / fc.pts.size, fc.pts.sumOf { it.z } / fc.pts.size)
            if (fc.n.dot(cam.e - c) <= 0) return
        }
        val path = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        val rgb = if (tintTag != null && fc.tag == tintTag) mix(fc.rgb, HI_RGB, .55f) else fc.rgb
        drawPath(path, shade(rgb, fc.n, fc.op, fc.tag == "floor" || fc.tag == "wall"))
        if (fc.tag != "floor") drawPath(path, edge, style = Stroke(1f))
    }
    s.env.forEach { face(it, it.tag == "wall") }
    val step = Math.round(az * 60 / Math.PI).toInt() * 2 + if (hi != null && s.dims.containsKey(hi)) 1 else 0
    val order = synchronized(orderCache) { orderCache[s]?.takeIf { it.first == step }?.second } ?: drawOrder(s.furn, cam).also { o -> synchronized(orderCache) { orderCache[s] = step to o } }
    order.forEach { bx -> bx.faces.forEach { face(it, true) } }
    val d = hi?.let { s.dims[it] } ?: return
    val a = cam.p(d.a) ?: return; val b = cam.p(d.b) ?: return
    val t0 = cam.p(d.a + d.tick * .09); val t1 = cam.p(d.a - d.tick * .09); val t2 = cam.p(d.b + d.tick * .09); val t3 = cam.p(d.b - d.tick * .09)
    val w = 3.2f * density
    drawLine(BLUE, a, b, w, StrokeCap.Round)
    if (t0 != null && t1 != null) drawLine(BLUE, t0, t1, w * .8f, StrokeCap.Round)
    if (t2 != null && t3 != null) drawLine(BLUE, t2, t3, w * .8f, StrokeCap.Round)
    // arrowheads at both ends
    val dx = b.x - a.x; val dy = b.y - a.y; val l = kotlin.math.hypot(dx, dy)
    if (l > 1f) {
        val ux = dx / l; val uy = dy / l; val ah = min(11f * density, l / 3)
        fun head(p: Offset, sx: Float) {
            val bx = p.x - ux * ah * sx; val by = p.y - uy * ah * sx
            drawPath(Path().apply { moveTo(p.x, p.y); lineTo(bx - uy * ah * .45f, by + ux * ah * .45f); lineTo(bx + uy * ah * .45f, by - ux * ah * .45f); close() }, BLUE)
        }
        head(b, 1f); head(a, -1f)
    }
    if (label != null && tm != null) {
        val empty = label == "?"
        val lay = tm.measure(label, TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Bold, color = if (empty) BLUE else Color.White))
        val mid = Offset((a.x + b.x) / 2, (a.y + b.y) / 2)
        val pw = lay.size.width + 18 * density; val ph = lay.size.height + 8 * density
        val tl = Offset(mid.x - pw / 2, mid.y - ph / 2)
        drawRoundRect(if (empty) Color.White else BLUE, tl, Size(pw, ph), CornerRadius(9 * density))
        if (empty) drawRoundRect(BLUE, tl, Size(pw, ph), CornerRadius(9 * density), style = Stroke(2 * density))
        drawText(lay, topLeft = Offset(mid.x - lay.size.width / 2f, mid.y - lay.size.height / 2f))
    }
}

/** The piece as a still picture [w] × [h] pixels (the gallery's cards). */
fun piecePicture(s: PieceScene, w: Int, h: Int, density: Float): ImageBitmap {
    val img = ImageBitmap(w, h)
    CanvasDrawScope().draw(Density(density), LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(img), Size(w.toFloat(), h.toFloat())) { drawPiece(s, null, 0f) }
    return img
}

/** The piece live: a drag turns it; [hi] the step being asked and [label] its value (or "?"). */
@Composable
fun PieceView(s: PieceScene, hi: String?, label: String?, modifier: Modifier) {
    var az by remember { mutableFloatStateOf(0f) }
    val tm = rememberTextMeasurer()
    Canvas(modifier.pointerInput(Unit) { detectHorizontalDragGestures { ch, dx -> ch.consume(); az = (az + dx / 320f).coerceIn(-1.1f, 1.1f) } }) {
        drawPiece(s, hi, az, label, tm)
    }
}
