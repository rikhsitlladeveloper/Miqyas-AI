package uz.metrx.app.ui.markup

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Item
import uz.metrx.app.data.MkEl
import uz.metrx.app.data.dn
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.ui.theme.PlexCond
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * Drawings and photos with their marks (prototype workspace.js mkElSVG / mkSVG): one renderer for the markup editor,
 * the workspace cards, the Measure page's pictures and the report. Everything is drawn in the item's own units
 * (1000 wide) and fitted into the box it is given.
 */

val MK_COL = mapOf("ink" to Color(0xFF0E1C36), "cobalt" to Color(0xFF1C4BD1), "red" to Color(0xFFD92D20))
val MK_TOOLS = mapOf("drawing" to listOf("pen", "line", "text", "eraser"), "photo" to listOf("dim", "arrow", "text", "pen", "eraser"))
private val PILL_WAIT = Color(0xFFFFF1DF)
private val PILL_WAIT_INK = Color(0xFF9A4D00)
private val DOT = Color(0xFFC9D1DE)

enum class MkMode { EDIT, THUMB, REPORT }

/** What a mark needs to say its length: the unit, its name in the language and the number format. */
class MkFmt(val unit: LenUnit, val en: Boolean, val m: String, val lang: Lang, val face: FontFamily)

/** The area of a drawing that has marks, with a margin (prototype mkBBox), or null when it has none. */
fun mkBBox(it: Item): Rect? {
    var x0 = 1e9f; var y0 = 1e9f; var x1 = -1e9f; var y1 = -1e9f
    it.els.forEach { e -> e.pts.forEach { q -> x0 = min(x0, q[0]); y0 = min(y0, q[1]); x1 = max(x1, q[0]); y1 = max(y1, q[1]) } }
    if (x0 > x1) return null
    val pad = 70f; x0 -= pad; y0 -= pad; x1 += pad; y1 += pad
    val w = max(x1 - x0, 420f); val h = max(y1 - y0, 315f); val cx = (x0 + x1) / 2; val cy = (y0 + y1) / 2
    return Rect(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
}

/** The part of the item shown: all of it, or for a drawing's card and report figure the part with marks. */
fun mkViewBox(it: Item, mode: MkMode): Rect {
    if (it.kind == "drawing" && mode != MkMode.EDIT) mkBBox(it)?.let { return it }
    return Rect(0f, 0f, it.W.toFloat(), it.hh.toFloat())
}

/** Where the item's view box lands in [box]: the scale and the top-left offset ("meet", or "slice" to fill). */
fun mkFit(vb: Rect, box: Rect, slice: Boolean = false): Triple<Float, Float, Float> {
    val k = if (slice) max(box.width / vb.width, box.height / vb.height) else min(box.width / vb.width, box.height / vb.height)
    return Triple(k, box.left + (box.width - vb.width * k) / 2 - vb.left * k, box.top + (box.height - vb.height * k) / 2 - vb.top * k)
}

private fun dimText(e: MkEl, f: MkFmt) = if (e.v != null) fmtLen(e.v, f.unit, f.en) + " " + f.m else "?"

/** A line's or dimension's value pill (prototype: width txt.length × 21 + 38, height 56, rounded 28). */
fun mkPill(e: MkEl, f: MkFmt): Rect {
    val a = e.pts[0]; val b = e.pts[1]
    val dx = b[0] - a[0]; val dy = b[1] - a[1]; val l = hypot(dx, dy).takeIf { it > 0 } ?: 1f
    val nx = -dy / l; val ny = dx / l
    val txt = dimText(e, f)
    val tw = if (e.v != null) txt.length * 21f + 38f else 64f; val th = 56f
    val off = if (e.t == "line") 42f else 0f; val sg = if (ny > 0) -1f else 1f
    val mx = (a[0] + b[0]) / 2 + nx * off * sg; val my = (a[1] + b[1]) / 2 + ny * off * sg
    return Rect(mx - tw / 2, my - th / 2, mx + tw / 2, my + th / 2)
}

/** The mark whose value pill or text is at [q] (item units), for opening it with a tap. */
fun mkLabelAt(it: Item, q: Offset, f: MkFmt): MkEl? = it.els.lastOrNull { e ->
    when (e.t) {
        "text" -> { val p = e.pts[0]; kotlin.math.abs(q.x - p[0]) < max(70f, (e.txt?.length ?: 0) * 15f) && kotlin.math.abs(q.y - p[1]) < 40f }
        "line", "dim" -> mkPill(e, f).inflate(8f).contains(q)
        else -> false
    }
}

private fun segD(q: Offset, a: List<Float>, b: List<Float>): Float {
    val dx = b[0] - a[0]; val dy = b[1] - a[1]; val l2 = dx * dx + dy * dy
    val s = if (l2 > 0) (((q.x - a[0]) * dx + (q.y - a[1]) * dy) / l2).coerceIn(0f, 1f) else 0f
    return hypot(q.x - a[0] - s * dx, q.y - a[1] - s * dy)
}

/** Whether the eraser at [q] touches [e] (prototype near). */
fun mkNear(e: MkEl, q: Offset): Boolean {
    if (e.t == "text") return hypot(q.x - e.pts[0][0], q.y - e.pts[0][1]) < 70f
    val ps = if (e.pts.size > 1) e.pts else listOf(e.pts[0], e.pts[0])
    for (i in 1 until ps.size) if (segD(q, ps[i - 1], ps[i]) < 26f) return true
    return false
}

private fun polyPath(pts: List<List<Float>>): Path = Path().apply {
    val ps = if (pts.size > 1) pts else listOf(pts[0], listOf(pts[0][0] + .1f, pts[0][1]))
    ps.forEachIndexed { i, q -> if (i == 0) moveTo(q[0], q[1]) else lineTo(q[0], q[1]) }
}

/** One mark, in item units (prototype mkElSVG). */
fun DrawScope.drawMark(e: MkEl, f: MkFmt, tm: TextMeasurer, alpha: Float = 1f) {
    val c = MK_COL[e.c] ?: MK_COL.getValue("ink")
    when (e.t) {
        "pen" -> drawPath(polyPath(e.pts), c, alpha = alpha, style = Stroke(if (e.w == 2) 18f else 8f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        "text" -> {
            val lay = tm.measure(dn(e.txt ?: "", f.lang), TextStyle(fontFamily = f.face, fontSize = 50.sp, fontWeight = FontWeight.SemiBold), density = Density(1f), softWrap = false)
            val tl = Offset(e.pts[0][0] - lay.size.width / 2f, e.pts[0][1] - lay.size.height / 2f)
            drawText(lay, Color.White, tl, alpha = alpha, drawStyle = Stroke(11f, join = StrokeJoin.Round))
            drawText(lay, c, tl, alpha = alpha, drawStyle = androidx.compose.ui.graphics.drawscope.Fill)
        }
        "arrow" -> {
            val a = e.pts[0]; val b = e.pts[1]; val dx = b[0] - a[0]; val dy = b[1] - a[1]; val l = hypot(dx, dy).takeIf { it > 0 } ?: 1f
            val ux = dx / l; val uy = dy / l; val nx = -uy; val ny = ux; val s = 34f; val hx = b[0] - ux * s; val hy = b[1] - uy * s
            drawLine(c, Offset(a[0], a[1]), Offset(hx, hy), 8f, StrokeCap.Round, alpha = alpha)
            val head = Path().apply { moveTo(b[0], b[1]); lineTo(hx + nx * 16, hy + ny * 16); lineTo(hx - nx * 16, hy - ny * 16); close() }
            drawPath(head, c, alpha = alpha); drawPath(head, c, alpha = alpha, style = Stroke(4f, join = StrokeJoin.Round))
        }
        else -> {   // line (drawing) and dim (photo): a dimension line with end marks and a value pill
            val a = e.pts[0]; val b = e.pts[1]; val dx = b[0] - a[0]; val dy = b[1] - a[1]; val l = hypot(dx, dy).takeIf { it > 0 } ?: 1f
            val ux = dx / l; val uy = dy / l; val nx = -uy; val ny = ux
            val tk = if (e.t == "dim") Offset(nx * 20, ny * 20) else Offset((ux + nx) * 13, (uy + ny) * 13)
            val p = Path().apply {
                moveTo(a[0], a[1]); lineTo(b[0], b[1])
                listOf(a, b).forEach { q -> moveTo(q[0] - tk.x, q[1] - tk.y); lineTo(q[0] + tk.x, q[1] + tk.y) }
            }
            if (e.t == "dim") drawPath(p, Color.White, alpha = .85f * alpha, style = Stroke(13f, cap = StrokeCap.Round))
            drawPath(p, c, alpha = alpha, style = Stroke(if (e.t == "dim") 7f else 9f, cap = StrokeCap.Round))
            val has = e.v != null; val r = mkPill(e, f)
            drawRoundRect(if (has) Color.White else PILL_WAIT, r.topLeft, r.size, CornerRadius(28f), alpha = alpha)
            drawRoundRect(if (has) c else PILL_WAIT_INK, r.topLeft, r.size, CornerRadius(28f), alpha = alpha,
                style = Stroke(3f, pathEffect = if (has) null else PathEffect.dashPathEffect(floatArrayOf(7f, 5f))))
            val lay = tm.measure(dimText(e, f), TextStyle(fontFamily = PlexCond, fontSize = 36.sp, fontWeight = FontWeight.SemiBold), density = Density(1f), softWrap = false)
            drawText(lay, if (has) MK_COL.getValue("ink") else PILL_WAIT_INK, Offset(r.center.x - lay.size.width / 2f, r.center.y + 1f - lay.size.height / 2f), alpha = alpha, drawStyle = androidx.compose.ui.graphics.drawscope.Fill)
        }
    }
}

/**
 * The item fitted into [box]: the photo (or the white sheet, dotted while editing), then its marks. [faded] marks are
 * shown faint (the eraser's touch before it lets go); [live] draws the mark being made, in item units.
 */
fun DrawScope.drawMarkup(
    it: Item, photo: ImageBitmap?, box: Rect, f: MkFmt, tm: TextMeasurer, mode: MkMode, slice: Boolean = false,
    faded: Set<String> = emptySet(), live: (DrawScope.() -> Unit)? = null
) {
    val vb = mkViewBox(it, mode)
    val (k, ox, oy) = mkFit(vb, box, slice)
    clipRect(box.left, box.top, box.right, box.bottom) {
        withTransform({ translate(ox, oy); scale(k, k, Offset.Zero) }) {
            if (it.kind == "photo") {
                if (photo != null) drawImage(photo, IntOffset.Zero, IntSize(photo.width, photo.height), IntOffset.Zero, IntSize(it.W, it.hh))
                else drawRect(Color(0xFF161D30), Offset.Zero, Size(it.W.toFloat(), it.hh.toFloat()))
            } else {
                drawRect(Color.White, vb.topLeft, vb.size)
                if (mode == MkMode.EDIT) {
                    var y = 25f
                    while (y < it.hh) { var x = 25f; while (x < it.W) { drawCircle(DOT, 2.2f, Offset(x, y)); x += 50f }; y += 50f }
                }
            }
            it.els.forEach { e -> drawMark(e, f, tm, if (e.id in faded) .15f else 1f) }
            live?.invoke(this)
        }
    }
}

/** Screen point → item units for an item shown whole in [box] (the editor). */
fun mkToItem(it: Item, box: Rect, p: Offset): Offset {
    val (k, ox, oy) = mkFit(mkViewBox(it, MkMode.EDIT), box)
    return Offset((p.x - ox) / k, (p.y - oy) / k)
}

/** A drawing's or photo's picture for a card or the Measure page's strip ([slice]: fill the box, cropping). */
@androidx.compose.runtime.Composable
fun MarkThumb(it: Item, modifier: androidx.compose.ui.Modifier, slice: Boolean = false) {
    val photo = rememberPhoto(it.src, 480)
    val tm = androidx.compose.ui.text.rememberTextMeasurer()
    val f = mkFmt()
    androidx.compose.foundation.Canvas(modifier) { drawMarkup(it, photo, Rect(Offset.Zero, size), f, tm, MkMode.THUMB, slice) }
}
