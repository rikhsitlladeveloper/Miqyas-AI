package uz.metrx.app.ui.win

import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.drawText
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.geo.V3
import uz.metrx.app.tiles.V2
import uz.metrx.app.ui.elec.PlanMap
import uz.metrx.app.ui.elec.rgbC
import uz.metrx.app.ui.tiles.TCam
import uz.metrx.app.win.DOOR_FRAME
import uz.metrx.app.win.GLASS_RGB
import uz.metrx.app.win.Obst
import uz.metrx.app.win.Placed
import uz.metrx.app.win.Sweep
import uz.metrx.app.win.W_KINDS
import uz.metrx.app.win.WBox
import uz.metrx.app.win.WCtx
import uz.metrx.app.win.WinItem
import uz.metrx.app.win.colourRgb
import uz.metrx.app.win.frameDepth
import uz.metrx.app.win.newItem
import uz.metrx.app.win.productBoxes
import uz.metrx.app.win.revealOf
import uz.metrx.app.win.sashF
import uz.metrx.app.win.sashesOf
import uz.metrx.app.win.sillFor
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/*
 * The windows-and-doors drawings: a product seen straight on from inside (the elevation) with its sashes, the opening
 * symbols (the triangle's tip on the hinge side; a tilt's tip at the bottom, dashed; a slider's arrow), its handles and
 * its sizes; the product in a piece of wall in perspective (the gallery's cards and the designer's 3D), drawn from the
 * same boxes as the room's 3D; and the room from above with the products, their swings and what stands in the way.
 */

val W_INK = Color(0xFF1E293B)
val W_THIN = Color(0xFF64748B)
private val W_GLASS = Color(0xFFDCEBFA)
private val W_PANEL = Color(0xFFE5E7EB)
private val W_SEL = Color(0xFF2E5BFF)
private val W_WARN = Color(0xFFDC2626)
private val W_DIM = Color(0xFF475569)

/** A product straight on, fitted into a box: mm across from its left and up from its bottom → pixels. */
class ElevMap(val w: Double, val h: Double, box: Rect, margin: Float, bottom: Float = margin, left: Float = margin) {
    val k = min((box.width - left - margin) / w, (box.height - margin - bottom) / h).toFloat()
    val x0 = box.left + left + (box.width - left - margin - (w * k).toFloat()) / 2
    val yB = box.top + margin + (h * k).toFloat()
    fun x(a: Double) = x0 + (a * k).toFloat()
    fun y(z: Double) = yB - (z * k).toFloat()
    fun at(a: Double, z: Double) = Offset(x(a), y(z))
    fun back(o: Offset) = V2(((o.x - x0) / k).toDouble(), ((yB - o.y) / k).toDouble())
}

/** A dimension line from [a] to [b] with its ticks, its text [t] beside it ([side] above or left of it). */
fun DrawScope.dimLine(a: Offset, b: Offset, t: TextLayoutResult?, vertical: Boolean, ink: Color = W_DIM) {
    drawLine(ink, a, b, 1f)
    val tk = 4f
    if (vertical) { drawLine(ink, Offset(a.x - tk, a.y), Offset(a.x + tk, a.y), 1f); drawLine(ink, Offset(b.x - tk, b.y), Offset(b.x + tk, b.y), 1f) }
    else { drawLine(ink, Offset(a.x, a.y - tk), Offset(a.x, a.y + tk), 1f); drawLine(ink, Offset(b.x, b.y - tk), Offset(b.x, b.y + tk), 1f) }
    if (t == null) return
    if (vertical) {
        val my = (a.y + b.y) / 2
        drawText(t, topLeft = Offset(a.x + 4f, my - t.size.height / 2f))
    } else {
        val mx = (a.x + b.x) / 2
        if (t.size.width < kotlin.math.abs(b.x - a.x) + 30) drawText(t, topLeft = Offset(mx - t.size.width / 2f, a.y - t.size.height - 1f))
    }
}

/**
 * Product [it] straight on from inside in map [m]: the frame and mullions in its inside colour, glass, panels, the
 * opening sashes' own profile, symbols and handles; [sel] a sash ringed (column, row), [bad] in red. [label] makes the
 * sizes' texts: the whole width and height outside, each column's width over it, each sash's size inside it.
 */
fun DrawScope.drawElevation(it: WinItem, m: ElevMap, sel: Pair<Int, Int>? = null, bad: Boolean = false, label: ((String) -> TextLayoutResult)? = null,
                            small: ((String) -> TextLayoutResult)? = null, stroke: Float = 1.5f) {
    val W = it.w.toDouble(); val H = it.h.toDouble()
    val cin = rgbC(colourRgb(it.colIn))
    val edge = if (bad) W_WARN else W_INK
    val tl = m.at(0.0, H); val sz = Size((W * m.k).toFloat(), (H * m.k).toFloat())
    drawRect(cin, tl, sz)
    if (it.isDoor) drawDoorFace(it, m, cin, stroke)
    else {
        val S = sashF(it.profile).toDouble()
        sashesOf(it).forEach { s ->
            val c = s.r
            val ctl = m.at(c.x0, c.y1); val csz = Size((c.w * m.k).toFloat(), (c.h * m.k).toFloat())
            when {
                s.t == "panel" -> {
                    drawRect(W_PANEL, ctl, csz)
                    clipRect(ctl.x, ctl.y, ctl.x + csz.width, ctl.y + csz.height) {
                        var d = -csz.height
                        while (d < csz.width) { drawLine(W_THIN.copy(alpha = .35f), Offset(ctl.x + d, ctl.y + csz.height), Offset(ctl.x + d + csz.height, ctl.y), 1f); d += 9f }
                    }
                    drawRect(edge, ctl, csz, style = Stroke(stroke * .6f))
                }
                s.opens -> {
                    // the sash's own profile round its glass
                    drawRect(edge, ctl, csz, style = Stroke(stroke * .6f))
                    val g0 = m.at(c.x0 + S, c.y1 - S); val gs = Size(((c.w - 2 * S) * m.k).toFloat().coerceAtLeast(1f), ((c.h - 2 * S) * m.k).toFloat().coerceAtLeast(1f))
                    drawRect(W_GLASS, g0, gs); drawRect(edge, g0, gs, style = Stroke(stroke * .5f))
                    sashSymbol(s.t, s.cell.hinge, Rect(g0, gs), it.handles, stroke)
                }
                else -> { drawRect(W_GLASS, ctl, csz); drawRect(edge, ctl, csz, style = Stroke(stroke * .6f)) }
            }
            if (sel != null && sel.first == s.col && sel.second == s.row) drawRect(W_SEL, Offset(ctl.x - 2f, ctl.y - 2f), Size(csz.width + 4f, csz.height + 4f), style = Stroke(3f))
            if (small != null) {
                val t = small("${Math.round(c.w)} × ${Math.round(c.h)}")
                if (t.size.width < csz.width - 4 && t.size.height < csz.height - 4) drawText(t, topLeft = Offset(ctl.x + (csz.width - t.size.width) / 2, ctl.y + csz.height - t.size.height - 3f))
            }
        }
    }
    drawRect(edge, tl, sz, style = Stroke(stroke))
    if (label == null) return
    // the sizes: the width under it, the height to its right, each column's width over it
    val gapPx = 10f
    dimLine(Offset(m.x(0.0), m.y(0.0) + gapPx + 12f), Offset(m.x(W), m.y(0.0) + gapPx + 12f), null, false)
    label("${it.w}").let { t -> drawText(t, topLeft = Offset((m.x(0.0) + m.x(W)) / 2 - t.size.width / 2f, m.y(0.0) + gapPx + 14f)) }
    dimLine(Offset(m.x(W) + gapPx, m.y(H)), Offset(m.x(W) + gapPx, m.y(0.0)), label("${it.h}"), true)
    if (it.cols.size > 1) {
        var a = 0.0
        val y = m.y(H) - 8f
        it.cols.forEach { c -> dimLine(Offset(m.x(a), y), Offset(m.x(a + c.w), y), label("${c.w}"), false); a += c.w }
    }
}

/** A door's face: its frame, the leaf (glass for a glass door), the handle and how it opens. */
private fun DrawScope.drawDoorFace(it: WinItem, m: ElevMap, cin: Color, stroke: Float) {
    val W = it.w.toDouble(); val H = it.h.toDouble(); val F = DOOR_FRAME.toDouble()
    val l0 = m.at(F, H - F); val ls = Size(((W - 2 * F) * m.k).toFloat(), ((H - F - 10) * m.k).toFloat())
    val leaf = Rect(l0, ls)
    drawRect(if (it.kind == "dgl") W_GLASS else cin.copy(alpha = 1f).let { c -> Color(c.red * .93f, c.green * .93f, c.blue * .93f) }, l0, ls)
    drawRect(W_INK, l0, ls, style = Stroke(stroke * .6f))
    val left = it.hinge != "R"
    if (it.kind == "dsl") {
        val y = leaf.center.y
        val a = Offset(leaf.left + leaf.width * .25f, y); val b = Offset(leaf.right - leaf.width * .25f, y)
        arrow(if (left) b else a, if (left) a else b, stroke)
    } else {
        // the tip on the hinge side, dashed when it opens away from the viewer
        val tip = Offset(if (left) leaf.left else leaf.right, leaf.center.y)
        val far = if (left) leaf.right else leaf.left
        val pe = if (it.swing == "out") PathEffect.dashPathEffect(floatArrayOf(7f, 5f)) else null
        // on a dark leaf the lines are light
        val ink = if (it.kind != "dgl" && cin.red * .3f + cin.green * .59f + cin.blue * .11f < .45f) Color(0xE6FFFFFF) else W_INK
        drawLine(ink, Offset(far, leaf.top), tip, stroke * .7f, pathEffect = pe); drawLine(ink, Offset(far, leaf.bottom), tip, stroke * .7f, pathEffect = pe)
    }
    if (it.handles) {
        val hx = if (left) m.x(W - F - 70) else m.x(F + 70)
        val hy = m.y(1000.0)
        val u = m.k
        val hInk = if (it.kind != "dgl" && cin.red * .3f + cin.green * .59f + cin.blue * .11f < .45f) Color(0xFFD1D5DB) else W_INK
        drawRect(hInk, Offset(hx - 15 * u, hy - 60 * u), Size(30 * u, 120 * u))
        drawLine(hInk, Offset(hx, hy), Offset(hx + (if (left) -1 else 1) * 110 * u, hy), maxOf(1f, 22 * u), StrokeCap.Round)
    }
}

private fun DrawScope.arrow(from: Offset, to: Offset, stroke: Float) {
    drawLine(W_INK, from, to, stroke * .8f)
    val d = (to - from); val l = d.getDistance().coerceAtLeast(1f); val u = Offset(d.x / l, d.y / l); val n = Offset(-u.y, u.x)
    val h = 9f
    drawLine(W_INK, to, to - u * h + n * (h * .6f), stroke * .8f); drawLine(W_INK, to, to - u * h - n * (h * .6f), stroke * .8f)
}

/** A sash's symbol in its glass [g]: lines from the handle side's corners to the hinge side's middle; a tilt's from the top corners to the bottom middle (dashed). */
fun DrawScope.sashSymbol(t: String, hinge: String, g: Rect, handles: Boolean, stroke: Float) {
    val left = hinge != "R"
    val w = stroke * .7f
    if (t == "turn" || t == "tt") {
        val tip = Offset(if (left) g.left else g.right, g.center.y); val far = if (left) g.right else g.left
        drawLine(W_INK, Offset(far, g.top), tip, w); drawLine(W_INK, Offset(far, g.bottom), tip, w)
    }
    if (t == "tilt" || t == "tt") {
        val pe = PathEffect.dashPathEffect(floatArrayOf(7f, 5f))
        val tip = Offset(g.center.x, g.bottom)
        drawLine(W_INK, Offset(g.left, g.top), tip, w, pathEffect = pe); drawLine(W_INK, Offset(g.right, g.top), tip, w, pathEffect = pe)
    }
    if (t == "slide") {
        val y = g.center.y; val a = Offset(g.left + g.width * .2f, y); val b = Offset(g.right - g.width * .2f, y)
        arrow(if (left) b else a, if (left) a else b, stroke)
    }
    if (!handles) return
    // the handle: on the side away from the hinges, a tilt's at the top, a slider's on its closing edge
    val hs = max(3f, min(g.width, g.height) * .05f)
    val at = when (t) {
        "tilt" -> Offset(g.center.x, g.top + hs * 1.5f)
        "slide" -> Offset(if (left) g.right - hs else g.left + hs, g.center.y)
        else -> Offset(if (left) g.right - hs * 1.2f else g.left + hs * 1.2f, g.center.y)
    }
    if (t == "tilt") drawRect(W_INK, Offset(at.x - hs * 1.6f, at.y - hs * .4f), Size(hs * 3.2f, hs * .8f))
    else drawRect(W_INK, Offset(at.x - hs * .4f, at.y - hs * 1.6f), Size(hs * .8f, hs * 3.2f))
}

/* ---------------- in perspective ---------------- */

/** How a product is shown in a piece of wall: [t] the wall's thickness, [floor] it stands on the floor. */
class PicSpec(val it: WinItem, val t: Int, val floor: Boolean)

/**
 * Product [s.it] in a piece of wall, seen from inside a little from the side ([az] turns the view): the wall's face round
 * the opening, the reveals, the product's boxes; what sticks out of the wall (the sill, handles) last.
 */
fun DrawScope.drawProductPic(s: PicSpec, az: Float = 0f, bg: Color = Color(0xFFF6F8FC)) {
    drawRect(bg)
    val it = s.it
    val W = it.w.toDouble(); val H = it.h.toDouble(); val g = it.gap.toDouble(); val T = s.t.toDouble()
    val bot = if (s.floor) 0.0 else -g; val top = H + g
    val ext = max(W, H)
    val wl = -g - max(250.0, ext * .14); val wr = W + g + max(250.0, ext * .14)
    val wb = if (s.floor) 0.0 else bot - max(250.0, ext * .14); val wt = top + max(200.0, ext * .1)
    fun v(a: Double, d: Double, z: Double) = V3(a / 1000, z / 1000, d / 1000)
    val tgt = v(W / 2, 0.0, (wb + wt) / 2)
    val a = .55 + az
    val dist = (max(wr - wl, wt - wb) / 1000) * 1.05
    val eye = V3(tgt.x + dist * sin(a), tgt.y + dist * .18, tgt.z + dist * cos(a))
    val cam = TCam(eye, tgt, size.width, size.height, .55)
    fun quad(pts: List<V3>, col: Color, line: Color? = null) {
        val o = pts.map { cam.p(it) ?: return }
        val path = Path().apply { moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        drawPath(path, col); if (line != null) drawPath(path, line, style = Stroke(.8f))
    }
    val wallC = Color(0xFFECEFF3); val revealC = Color(0xFFDCE1E8)
    // the floor in front of a door
    if (s.floor) quad(listOf(v(wl, 0.0, 0.0), v(wr, 0.0, 0.0), v(wr, 2200.0, 0.0), v(wl, 2200.0, 0.0)), Color(0xFFE2E6EC))
    // the sky through the opening, then its reveals
    quad(listOf(v(-g, -T, bot), v(W + g, -T, bot), v(W + g, -T, top), v(-g, -T, top)), Color(0xFFCFE3F8))
    quad(listOf(v(-g, -T, bot), v(-g, 0.0, bot), v(-g, 0.0, top), v(-g, -T, top)), revealC)
    quad(listOf(v(W + g, -T, bot), v(W + g, 0.0, bot), v(W + g, 0.0, top), v(W + g, -T, top)), revealC)
    quad(listOf(v(-g, -T, top), v(W + g, -T, top), v(W + g, 0.0, top), v(-g, 0.0, top)), Color(0xFFC9D0DA))
    if (!s.floor) quad(listOf(v(-g, -T, bot), v(W + g, -T, bot), v(W + g, 0.0, bot), v(-g, 0.0, bot)), Color(0xFFE6EAF0))
    val boxes = productBoxes(it, s.t, s.floor)
    fun drawBox(b: WBox) {
        fun p(aa: Double, dd: Double, zz: Double) = v(aa, dd, zz)
        val faces = listOf(
            Triple(listOf(p(b.a0, b.d1, b.z0), p(b.a1, b.d1, b.z0), p(b.a1, b.d1, b.z1), p(b.a0, b.d1, b.z1)), V3(0.0, 0.0, 1.0), 1f),
            Triple(listOf(p(b.a0, b.d0, b.z1), p(b.a1, b.d0, b.z1), p(b.a1, b.d1, b.z1), p(b.a0, b.d1, b.z1)), V3(0.0, 1.0, 0.0), .95f),
            Triple(listOf(p(b.a0, b.d0, b.z0), p(b.a1, b.d0, b.z0), p(b.a1, b.d1, b.z0), p(b.a0, b.d1, b.z0)), V3(0.0, -1.0, 0.0), .7f),
            Triple(listOf(p(b.a0, b.d0, b.z0), p(b.a0, b.d1, b.z0), p(b.a0, b.d1, b.z1), p(b.a0, b.d0, b.z1)), V3(-1.0, 0.0, 0.0), .82f),
            Triple(listOf(p(b.a1, b.d0, b.z0), p(b.a1, b.d1, b.z0), p(b.a1, b.d1, b.z1), p(b.a1, b.d0, b.z1)), V3(1.0, 0.0, 0.0), .82f))
        faces.forEach { (pts, n, shade) ->
            val cx = pts.sumOf { q -> q.x } / 4; val cy = pts.sumOf { q -> q.y } / 4; val cz = pts.sumOf { q -> q.z } / 4
            if ((eye.x - cx) * n.x + (eye.y - cy) * n.y + (eye.z - cz) * n.z <= 0) return@forEach
            val col = rgbC(b.rgb, b.op).let { c -> Color(c.red * shade, c.green * shade, c.blue * shade, c.alpha) }
            quad(pts, col, if (b.glass) null else Color(0x33101828))
        }
    }
    fun far(b: WBox): Double { val cx = (b.a0 + b.a1) / 2000; val cy = (b.z0 + b.z1) / 2000; val cz = (b.d0 + b.d1) / 2000
        return (eye.x - cx) * (eye.x - cx) + (eye.y - cy) * (eye.y - cy) + (eye.z - cz) * (eye.z - cz) }
    // in the wall first (glass last among them, so the frame shows through it), then the wall's face, then what stands out of it
    val inWall = boxes.filter { it.d1 <= 1 }
    inWall.filter { !it.glass }.sortedByDescending(::far).forEach(::drawBox)
    inWall.filter { it.glass }.sortedByDescending(::far).forEach(::drawBox)
    quad(listOf(v(wl, 0.0, wb), v(-g, 0.0, wb), v(-g, 0.0, wt), v(wl, 0.0, wt)), wallC)
    quad(listOf(v(W + g, 0.0, wb), v(wr, 0.0, wb), v(wr, 0.0, wt), v(W + g, 0.0, wt)), wallC)
    quad(listOf(v(-g, 0.0, top), v(W + g, 0.0, top), v(W + g, 0.0, wt), v(-g, 0.0, wt)), wallC)
    if (!s.floor) quad(listOf(v(-g, 0.0, wb), v(W + g, 0.0, wb), v(W + g, 0.0, bot), v(-g, 0.0, bot)), wallC)
    boxes.filter { it.d1 > 1 }.sortedByDescending(::far).forEach(::drawBox)
}

/** The sample of a gallery type: its usual size in a 300 wall, a window with its sill and drip. */
fun samplePic(kind: String): PicSpec {
    val k = W_KINDS.first { it.id == kind }
    val floor = k.isDoor || k.id == "balc" || k.id == "pano"
    var it = newItem("s-$kind", k)
    if (!k.isDoor && !floor) it = it.copy(sill = sillFor(revealOf(300, frameDepth(it))), drip = true)
    return PicSpec(it, 300, floor)
}

/** A picture as a still image. */
fun picture(s: PicSpec, w: Int, h: Int, density: Float, az: Float = 0f): ImageBitmap {
    val img = ImageBitmap(w, h)
    CanvasDrawScope().draw(Density(density), LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(img), Size(w.toFloat(), h.toFloat())) { drawProductPic(s, az) }
    return img
}

/** The gallery's pictures, made once from the app's own drawing of each type. */
object WinPics {
    val pics = mutableStateMapOf<String, ImageBitmap>()
    suspend fun make(w: Int, h: Int, density: Float) {
        for (k in W_KINDS) {
            if (pics[k.id] != null) continue
            val img = withContext(Dispatchers.Default) { runCatching { picture(samplePic(k.id), w, h, density) }.getOrNull() }
            if (img != null) pics[k.id] = img
        }
    }
}

/* ---------------- from above ---------------- */

private val P_FLOOR = Color(0xFFF1F4F8)
private val P_WALL = Color(0xFF334155)

/**
 * Room [c] from above: the floor and walls, the openings (an empty door with its usual swing), the products in theirs
 * ([sel] in blue, [bad] in red), where the sashes and leaves sweep, and what stands in the room ([obs], grey).
 */
fun DrawScope.drawWinPlan(c: WCtx, m: PlanMap, pls: List<Placed>, sweeps: List<Sweep>, obs: List<Obst>, sym: Float, sel: String? = null, bad: Set<String> = emptySet()) {
    val f = c.g.floor
    val out = Path().apply { val o = f.map { m.at(it) }; moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
    drawPath(out, P_FLOOR)
    obs.forEach { ob ->
        val o = ob.poly.map { m.at(it) }
        val path = Path().apply { moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        drawPath(path, Color(0x33475569)); drawPath(path, Color(0x99475569), style = Stroke(1f))
    }
    sweeps.forEach { sw ->
        val o = sw.poly.map { m.at(it) }
        val path = Path().apply { moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        val col = if (sw.item in bad) W_WARN else W_SEL
        drawPath(path, col.copy(alpha = .08f)); drawPath(path, col.copy(alpha = .55f), style = Stroke(1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))))
    }
    drawPath(out, P_WALL, style = Stroke(max(2f, sym * .45f)))
    val filled = pls.map { it.o.id }.toSet()
    c.room.openings.forEach { o ->
        val w = c.wall(o.wall) ?: return@forEach
        val a = m.at(w.at(o.off.toDouble())); val b = m.at(w.at((o.off + o.w).toDouble()))
        drawLine(P_FLOOR, a, b, max(3f, sym * .6f))
        if (o.id !in filled) drawLine(if (o.type == "door") Color(0xFF94A3B8) else Color(0xFF7FA6E0), a, b, max(1.5f, sym * .25f), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f)))
    }
    pls.forEach { pl ->
        val w = pl.w
        val col = when { pl.it.id in bad -> W_WARN; pl.it.id == sel -> W_SEL; else -> W_INK }
        val d0 = -pl.r.toDouble(); val d1 = d0 - pl.depth
        val q = listOf(w.at(pl.a0, d0), w.at(pl.a0 + pl.it.w, d0), w.at(pl.a0 + pl.it.w, d1), w.at(pl.a0, d1)).map { m.at(it) }
        val path = Path().apply { moveTo(q[0].x, q[0].y); q.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        drawPath(path, if (pl.it.isDoor) rgbC(colourRgb(pl.it.colIn)) else rgbC(GLASS_RGB)); drawPath(path, col, style = Stroke(max(1.5f, sym * .22f)))
        if (pl.it.sill > 0 && !pl.it.isDoor) {
            val s = listOf(w.at(pl.a0 - 50, d0), w.at(pl.a0 + pl.it.w + 50, d0), w.at(pl.a0 + pl.it.w + 50, pl.it.sill + d0), w.at(pl.a0 - 50, pl.it.sill + d0)).map { m.at(it) }
            val sp = Path().apply { moveTo(s[0].x, s[0].y); s.drop(1).forEach { lineTo(it.x, it.y) }; close() }
            drawPath(sp, Color.White); drawPath(sp, col.copy(alpha = .6f), style = Stroke(1f))
        }
    }
}
