package uz.metrx.app.ui.rooms

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.geo.styleId
import uz.metrx.app.geo.thickOf
import uz.metrx.app.geo.topOf
import uz.metrx.app.geo.z0Of
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.Theme
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/*
 * The room editor v2's drawings (ports of the mockup's planSvg, frontSvg, opArt, ptArt, pkDraw and isoSvg): the plan
 * with thick walls, the doors by style, windows and points; one wall seen from inside; the style cards' front views;
 * the size step's big drawing with the asked edge in blue; a simple isometric 3D that can be tapped. Sizes are the
 * mockup's px times [u] (the density), so a drawing reads the same on every phone.
 */

/** The drawings' colours (the mockup's tokens, light and dark). */
object RP {
    val dark get() = Theme.dark
    val paper get() = if (dark) Color(0xFF161C30) else Color(0xFFF7F8FC)
    val room get() = G.cobalt.copy(alpha = if (dark) .2f else .11f)
    val wallc get() = if (dark) Color(0xFFA3ACC4) else Color(0xFF3F475C)
    val doorf get() = if (dark) Color(0xFF7A6650) else Color(0xFFD9C3A5)
    val elev get() = if (dark) Color(0xFF262D47) else Color(0xFFF7F6F3)
    val isoWall get() = if (dark) Color(0xFF3A4260) else Color(0xFFECE9E3)
    val isoWall2 get() = if (dark) Color(0xFF323956) else Color(0xFFDFDBD3)
    val isoFloor get() = if (dark) Color(0xFF454B63) else Color(0xFFE4DED5)
    val isoCap get() = if (dark) Color(0xFF232942) else Color(0xFF9A958C)
    val issue get() = if (dark) Color(0xFFFB7185) else Color(0xFFE11D48)
    val red get() = if (dark) Color(0xFFF87171) else Color(0xFFDC2626)
    val green get() = if (dark) Color(0xFF34D399) else Color(0xFF16A34A)
    val winFill = Color(0x7338BDF8)
    val winLine = Color(0xFF0284C7)
}

private val pathCache = HashMap<String, Path>()
private fun svgPath(d: String): Path = pathCache.getOrPut(d) { PathParser().parsePathString(d).toPath() }

private fun lerp(a: Offset, b: Offset, t: Float) = Offset(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
private fun mid(a: Offset, b: Offset) = lerp(a, b, .5f)
fun segD(p: Offset, a: Offset, b: Offset): Pair<Float, Float> {
    val dx = b.x - a.x; val dy = b.y - a.y; val l2 = dx * dx + dy * dy
    val t = if (l2 > 0f) (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2).coerceIn(0f, 1f) else 0f
    return hypot(p.x - (a.x + dx * t), p.y - (a.y + dy * t)) to t * sqrt(l2)
}

fun pip(p: Offset, poly: List<Offset>): Boolean {
    var c = false; var j = poly.size - 1
    for (i in poly.indices) {
        val a = poly[i]; val b = poly[j]
        if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) c = !c
        j = i
    }
    return c
}

private fun polyPath(pts: List<Offset>) = Path().apply { pts.forEachIndexed { i, p -> if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y) }; close() }

private fun DrawScope.ln(a: Offset, b: Offset, c: Color, w: Float, dash: FloatArray? = null, cap: StrokeCap = StrokeCap.Butt) =
    drawLine(c, a, b, w, cap, if (dash != null) PathEffect.dashPathEffect(dash) else null)

/** A quarter (or any) arc around [c] from [from] to [to], the short way. */
private fun DrawScope.arc(from: Offset, to: Offset, c: Offset, rad: Float, col: Color, w: Float, dash: FloatArray?) {
    val a0 = atan2(from.y - c.y, from.x - c.x); val a1 = atan2(to.y - c.y, to.x - c.x)
    var sw = a1 - a0
    while (sw > PI) sw -= (2 * PI).toFloat(); while (sw < -PI) sw += (2 * PI).toFloat()
    drawArc(col, Math.toDegrees(a0.toDouble()).toFloat(), Math.toDegrees(sw.toDouble()).toFloat(), false, Offset(c.x - rad, c.y - rad), Size(2 * rad, 2 * rad),
        style = Stroke(w, pathEffect = if (dash != null) PathEffect.dashPathEffect(dash) else null))
}

/* ---------------- the plan ---------------- */

/** One wall on the screen: its ends, along [u], inward normal [n], its length (px and mm), its thickness (px). */
class Frame(val id: String, val a: Offset, val b: Offset, val u: Offset, val n: Offset, val lpx: Float, val L: Int, val tp: Float)

/** The plan fitted in a box: [k] px per mm, the walls as [frames], the inside [poly] and the walls' outside [outer]. */
class PlanFit(val k: Float, val frames: List<Frame>, val poly: List<Offset>, val outer: List<Offset>) {
    fun frame(id: String) = frames.firstOrNull { it.id == id }
    /** The point [t] mm along wall [f], [off] px inward. */
    fun at(f: Frame, t: Double, off: Float) = Offset(f.a.x + f.u.x * (t * k).toFloat() + f.n.x * off, f.a.y + f.u.y * (t * k).toFloat() + f.n.y * off)
}

/** A plan point turned [rot] quarter turns (the mockup's tf, as the room's Burish). */
fun turn(p: Pt, rot: Int): Pt { var x = p.x; var y = p.y; repeat(((rot % 4) + 4) % 4) { val t = x; x = -y; y = t }; return Pt(x, y) }

private fun lineX(p: Offset, u: Offset, q: Offset, v: Offset): Offset {
    val den = u.x * v.y - u.y * v.x
    if (abs(den) < 1e-6f) return q
    val t = ((q.x - p.x) * v.y - (q.y - p.y) * v.x) / den
    return Offset(p.x + u.x * t, p.y + u.y * t)
}

/**
 * The plan of [r] (its walls [ws]) fitted into [box] with [pad] px round it ([padX] at the sides for the pills), zoomed
 * and panned by [z] (z, ox, oy).
 */
fun planFit(r: Room, ws: List<RW>, box: Rect, pad: Float, padX: Float, z: Float = 1f, ox: Float = 0f, oy: Float = 0f): PlanFit? {
    if (ws.size < 3) return null
    val pts = ws.map { turn(it.a, r.rot) }
    val mnx = pts.minOf { it.x }; val mxx = pts.maxOf { it.x }; val mny = pts.minOf { it.y }; val mxy = pts.maxOf { it.y }
    val bw = max(mxx - mnx, 1.0); val bh = max(mxy - mny, 1.0)
    val s = max(1e-5, min((box.width - 2 * padX) / bw, (box.height - 2 * pad) / bh))
    val x0 = box.left + (box.width - bw * s) / 2 - mnx * s; val y0 = box.top + (box.height - bh * s) / 2 - mny * s
    val M = { p: Pt -> val q = turn(p, r.rot); Offset(((x0 + q.x * s) * z + ox).toFloat(), ((y0 + q.y * s) * z + oy).toFloat()) }
    val k = (s * z).toFloat()
    val poly = ws.map { M(it.a) }
    val frames = ws.mapIndexed { i, w ->
        val a = poly[i]; val b = M(w.b)
        val dx = b.x - a.x; val dy = b.y - a.y; val l = max(hypot(dx, dy), 1e-3f)
        val u = Offset(dx / l, dy / l); var n = Offset(-u.y, u.x)
        val m = Offset((a.x + b.x) / 2 + n.x * l * .02f, (a.y + b.y) / 2 + n.y * l * .02f)
        if (!pip(m, poly)) n = Offset(-n.x, -n.y)
        Frame(w.id, a, b, u, n, l, w.L, max(3f, thickOf(r, w.id) * k))
    }
    val oo = frames.map { f -> Offset(f.a.x - f.n.x * f.tp, f.a.y - f.n.y * f.tp) }
    val nfr = frames.size
    val outer = frames.indices.map { i -> val j = (i - 1 + nfr) % nfr; lineX(oo[j], frames[j].u, oo[i], frames[i].u) }
    return PlanFit(k, frames, poly, outer)
}

/** What a tap can hit on the plan: an opening's two faces and middle, a point's marker. */
class ItemRec(val id: String, val op: Boolean, val f: Frame, val p0: Offset, val p1: Offset, val q0: Offset, val q1: Offset, val c: Offset, val w0: Offset)

fun planRec(fit: PlanFit, it: Any, small: Boolean, u: Float): ItemRec? = when (it) {
    is Opening -> fit.frame(it.wall)?.let { f ->
        val p0 = fit.at(f, it.off.toDouble(), 0f); val p1 = fit.at(f, (it.off + it.w).toDouble(), 0f)
        val q0 = fit.at(f, it.off.toDouble(), -f.tp); val q1 = fit.at(f, (it.off + it.w).toDouble(), -f.tp)
        ItemRec(it.id, true, f, p0, p1, q0, q1, mid(mid(p0, p1), mid(q0, q1)), p0)
    }
    is SitePoint -> fit.frame(it.wall)?.let { f ->
        val w0 = fit.at(f, it.off.toDouble(), 0f); val c = fit.at(f, it.off.toDouble(), (if (small) 13f else 15f) * u)
        ItemRec(it.id, false, f, w0, w0, w0, w0, c, w0)
    }
    else -> null
}

/** The item under [p] (px), or null. */
fun hitPlan(recs: List<ItemRec>, p: Offset, u: Float): String? {
    var best: Pair<Float, String>? = null
    for (x in recs) {
        val d = if (x.op) min(min(segD(p, x.p0, x.p1).first, segD(p, x.q0, x.q1).first), segD(p, mid(x.p0, x.q0), mid(x.p1, x.q1)).first) + 4 * u
        else hypot(p.x - x.c.x, p.y - x.c.y)
        if (d > (if (x.op) 18f else 17f) * u) continue
        if (best == null || d < best.first) best = d to x.id
    }
    return best?.second
}

/** The wall near [p] (px) within [maxd] px — from inside, or from outside past its thickness — and how far along it, mm. */
fun nearWall(fit: PlanFit, p: Offset, maxd: Float): Pair<Frame, Double>? {
    var best: Triple<Float, Frame, Float>? = null
    for (f in fit.frames) {
        val (d0, t) = segD(p, f.a, f.b)
        val side = (p.x - f.a.x) * f.n.x + (p.y - f.a.y) * f.n.y
        val d = if (side < 0) max(0f, d0 - f.tp) else d0
        if (d < maxd && (best == null || d < best.first)) best = Triple(d, f, t)
    }
    return best?.let { it.second to (it.third / fit.k).toDouble() }
}

/** What the plan shows besides the room: the selection, the drop wall lit green, the armed dashes, the ghost, the magnet, the sizes. */
class PlanLook2(
    val selItem: String? = null, val selWall: String? = null, val hl: String? = null, val arm: Boolean = false, val ghost: Any? = null,
    val magMid: String? = null, val lens: Boolean = true, val chain: Boolean = false, val areaText: String? = null, val small: Boolean = true,
    val bad: Set<String> = emptySet(), val dimGhost: Boolean = false
)

private fun txtStyle(sz: Float, col: Color, w: FontWeight = FontWeight.ExtraBold) = TextStyle(fontFamily = Jakarta, fontSize = sz.sp, fontWeight = w, color = col)

/** A rounded label: blue ("cur") or paper with a grey rim, kept inside the canvas. */
fun DrawScope.labelPill(tm: TextMeasurer, x0: Float, y0: Float, t: String, cur: Boolean, u: Float) {
    val lay = tm.measure(t, txtStyle(10.5f, if (cur) Color.White else G.ink))
    val w = lay.size.width + 14 * u; val h = 20 * u
    val x = x0.coerceIn(w / 2 + 2 * u, max(w / 2 + 2 * u, size.width - w / 2 - 2 * u)); val y = y0.coerceIn(h / 2 + 2 * u, max(h / 2 + 2 * u, size.height - h / 2 - 2 * u))
    val tl = Offset(x - w / 2, y - h / 2)
    drawRoundRect(if (cur) G.cobalt else RP.paper, tl, Size(w, h), CornerRadius(h / 2))
    drawRoundRect(if (cur) G.cobalt else G.ink2, tl, Size(w, h), CornerRadius(h / 2), style = Stroke(1f * u))
    drawText(lay, topLeft = Offset(x - lay.size.width / 2f, y - lay.size.height / 2f))
}

/** A kind's glyph (white strokes) centred on [c], [sz] px. */
fun DrawScope.glyph(kind: String, c: Offset, sz: Float, col: Color = Color.White, w: Float = 2.6f) {
    val d = KIND_ICONS[kind] ?: return
    val k = sz / 24f
    translate(c.x - sz / 2, c.y - sz / 2) { scale(k, k, Offset.Zero) { drawPath(svgPath(d), col, style = Stroke(w, cap = StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round)) } }
}

/** The plan: room, thick walls, items, labels. Returns nothing; hit tests use [planRec]. */
fun DrawScope.drawPlanV2(r: Room, fit: PlanFit, look: PlanLook2, tm: TextMeasurer, u: Float, lenOf: (String) -> String) {
    val fr = fit.frames
    drawPath(polyPath(fit.poly), RP.room)
    val band = Path().apply { fillType = PathFillType.EvenOdd; addPath(polyPath(fit.outer)); addPath(polyPath(fit.poly)) }
    drawPath(band, RP.wallc.copy(alpha = .82f))
    look.selWall?.let { id -> val i = fr.indexOfFirst { it.id == id }; if (i >= 0) {
        val q = listOf(fr[i].a, fr[i].b, fit.outer[(i + 1) % fr.size], fit.outer[i])
        drawPath(polyPath(q), G.cobalt.copy(alpha = .55f)); drawPath(polyPath(q), G.cobalt, style = Stroke(2f * u))
    } }
    fr.forEach { ln(it.a, it.b, G.ink2, 1.4f * u) }
    if (look.arm) fr.forEach { ln(it.a, it.b, G.cobalt, 3.5f * u, floatArrayOf(2 * u, 6 * u), StrokeCap.Round) }
    look.hl?.let { id -> fit.frame(id)?.let { f -> ln(f.a, f.b, RP.green.copy(alpha = .3f), 20f * u, cap = StrokeCap.Round); ln(f.a, f.b, RP.green, 5f * u, cap = StrokeCap.Round) } }
    if (look.areaText != null) {
        val ce = Offset(fit.poly.sumOf { it.x.toDouble() }.toFloat() / fit.poly.size, fit.poly.sumOf { it.y.toDouble() }.toFloat() / fit.poly.size)
        val lay = tm.measure(look.areaText, txtStyle(12f, G.ink2)); drawText(lay, topLeft = Offset(ce.x - lay.size.width / 2f, ce.y - lay.size.height / 2f))
    }
    r.openings.forEach { drawItemPlan(fit, it, look, u, prev = false) }
    r.points.forEach { drawItemPlan(fit, it, look, u, prev = false) }
    look.ghost?.let { drawItemPlan(fit, it, look, u, prev = true) }
    look.magMid?.let { wid -> fit.frame(wid)?.let { f -> val cm = mid(f.a, f.b); ln(cm - f.n * (f.tp + 6 * u), cm + f.n * (40 * u), RP.green, 1.8f * u, floatArrayOf(4 * u, 3 * u)) } }
    if (look.chain) fr.forEach { chainDim(r, fit, it, tm, u) }
    fr.forEach { f ->
        val off = f.tp + 12 * u
        val m = mid(f.a, f.b) - f.n * off
        labelPill(tm, m.x, m.y, if (look.lens) f.id + " · " + lenOf(f.id) else f.id, f.id == look.selWall || f.id == look.hl, u)
    }
}

private fun DrawScope.chainDim(r: Room, fit: PlanFit, f: Frame, tm: TextMeasurer, u: Float) {
    val ps = ArrayList<Int>(); ps += 0; ps += f.L
    r.openings.filter { it.wall == f.id }.forEach { ps += it.off; ps += it.off + it.w }
    r.points.filter { it.wall == f.id }.forEach { ps += it.off }
    val pts = ps.sorted().fold(ArrayList<Int>()) { acc, v -> if (acc.isEmpty() || v - acc.last() > 1) acc.add(v); acc }
    if (pts.size < 3) return
    val o = 30 * u
    val c = G.ink3
    ln(fit.at(f, 0.0, o), fit.at(f, f.L.toDouble(), o), c, 1f * u)
    pts.forEach { t -> ln(fit.at(f, t.toDouble(), o - 4 * u), fit.at(f, t.toDouble(), o + 4 * u), c, 1f * u) }
    for (j in 1 until pts.size) {
        val d = pts[j] - pts[j - 1]
        if (d * fit.k < 26 * u) continue
        val m = fit.at(f, (pts[j] + pts[j - 1]) / 2.0, o + 9 * u)
        val lay = tm.measure(mm(d), txtStyle(9f, G.ink2, FontWeight.Bold)); drawText(lay, topLeft = Offset(m.x - lay.size.width / 2f, m.y - lay.size.height / 2f))
    }
}

/** A door's leaf by its style and swing (the mockup's doorLeaf). */
private fun DrawScope.doorLeaf(style: String, sw: String, f: Frame, p0: Offset, p1: Offset, q0: Offset, q1: Offset, wpx: Float, u: Float, ink: Color) {
    val nn = f.n
    val inw = !sw.startsWith("out"); val hl = !sw.endsWith("R")
    val h = if (inw) (if (hl) p0 else p1) else (if (hl) q0 else q1)
    val j = if (inw) (if (hl) p1 else p0) else (if (hl) q1 else q0)
    val d = if (inw) nn else Offset(-nn.x, -nn.y)
    val dash = floatArrayOf(3 * u, 3 * u)
    when (style) {
        "arch" -> { ln(p0, p1, G.ink3, 1.4f * u, floatArrayOf(5 * u, 4 * u)); ln(q0, q1, G.ink3, 1.4f * u, floatArrayOf(5 * u, 4 * u)) }
        "slide" -> { val o1 = nn * (4 * u); val o2 = nn * (8 * u); ln(p0 + o1, lerp(p0, p1, .6f) + o1, ink, 2f * u, cap = StrokeCap.Round); ln(lerp(p0, p1, .4f) + o2, p1 + o2, ink, 2f * u, cap = StrokeCap.Round) }
        "double" -> { val hw = wpx / 2; val m2 = mid(h, j); val e1 = h + d * hw; val e2 = j + d * hw
            ln(h, e1, ink, 2f * u, cap = StrokeCap.Round); arc(m2, e1, h, hw, G.ink3, 1.2f * u, dash); ln(j, e2, ink, 2f * u, cap = StrokeCap.Round); arc(m2, e2, j, hw, G.ink3, 1.2f * u, dash) }
        "fold" -> { val zp = (0..4).map { k -> val q = lerp(p0, p1, k / 4f); if (k % 2 == 1) q + d * min(9 * u, wpx / 5) else q }
            for (k in 0 until 4) ln(zp[k], zp[k + 1], ink, 2f * u, cap = StrokeCap.Round) }
        else -> { val e = h + d * wpx; ln(h, e, if (style == "glass") RP.winLine else ink, 2f * u, cap = StrokeCap.Round); arc(j, e, h, wpx, G.ink3, 1.2f * u, dash) }
    }
}

private fun DrawScope.drawItemPlan(fit: PlanFit, it: Any, look: PlanLook2, u: Float, prev: Boolean) {
    val a = if (prev) .62f else 1f
    val ink = G.ink.copy(alpha = a)
    when (it) {
        is Opening -> {
            val f = fit.frame(it.wall) ?: return
            val k = fit.k
            fun P(t: Int, off: Float) = fit.at(f, t.toDouble(), off)
            val p0 = P(it.off, 0f); val p1 = P(it.off + it.w, 0f); val q0 = P(it.off, -f.tp); val q1 = P(it.off + it.w, -f.tp)
            val st = styleId(it)
            if (st == "balcony") {
                val dA = it.off; val wA = it.off + it.dw; val wB = it.off + it.w
                val wp0 = P(wA, 0f); val wp1 = P(wB, 0f); val wq0 = P(wA, -f.tp); val wq1 = P(wB, -f.tp)
                drawPath(polyPath(listOf(wp0, wp1, wq1, wq0)), RP.winFill.copy(alpha = .45f * a))
                ln(wp0, wp1, RP.winLine.copy(alpha = a), 1.4f * u); ln(wq0, wq1, RP.winLine.copy(alpha = a), 1.4f * u); ln(mid(wp0, wq0), mid(wp1, wq1), RP.winLine.copy(alpha = a), 1.4f * u)
                val dp0 = P(dA, 0f); val dp1 = P(dA + it.dw, 0f); val dq0 = P(dA, -f.tp); val dq1 = P(dA + it.dw, -f.tp)
                drawPath(polyPath(listOf(dp0, dp1, dq1, dq0)), RP.paper)
                ln(dp0, dq0, G.ink2, 1.6f * u); ln(dp1, dq1, G.ink2, 1.6f * u)
                doorLeaf("single", if (it.type == "door") it.sw.ifEmpty { "inL" } else "inL", f, dp0, dp1, dq0, dq1, it.dw * k, u, ink)
            } else if (it.type == "window") {
                val nm = when (st) { "triple", "pano" -> 3; "single" -> 1; else -> 2 }
                drawPath(polyPath(listOf(p0, p1, q1, q0)), RP.winFill.copy(alpha = (if (st == "pano") .65f else .45f) * a))
                ln(p0, p1, RP.winLine.copy(alpha = a), 1.4f * u); ln(q0, q1, RP.winLine.copy(alpha = a), 1.4f * u); ln(mid(p0, q0), mid(p1, q1), RP.winLine.copy(alpha = a), 1.4f * u)
                for (m in 1 until nm) ln(lerp(p0, p1, m / nm.toFloat()), lerp(q0, q1, m / nm.toFloat()), RP.winLine.copy(alpha = a), 1.4f * u)
            } else {
                drawPath(polyPath(listOf(p0, p1, q1, q0)), RP.paper)
                ln(p0, q0, G.ink2, 1.6f * u); ln(p1, q1, G.ink2, 1.6f * u)
                doorLeaf(st, it.sw.ifEmpty { "inL" }, f, p0, p1, q0, q1, it.w * k, u, ink)
            }
            val box = listOf(P(it.off, 5 * u), P(it.off + it.w, 5 * u), P(it.off + it.w, -f.tp - 5 * u), P(it.off, -f.tp - 5 * u))
            if (!prev && look.selItem == it.id) drawPath(polyPath(box), G.cobalt, style = Stroke(2.6f * u))
            else if (!prev && it.id in look.bad) drawPath(polyPath(box), RP.issue, style = Stroke(2.2f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u))))
        }
        is SitePoint -> {
            val f = fit.frame(it.wall) ?: return
            val w0 = fit.at(f, it.off.toDouble(), 0f); val c = fit.at(f, it.off.toDouble(), (if (look.small) 13f else 15f) * u)
            val rr = (if (look.small) 8.5f else 10f) * u
            ln(w0, c, G.ink3.copy(alpha = a), 1.2f * u)
            drawCircle(kindColor(it.t).copy(alpha = a), rr, c); drawCircle(RP.paper, rr, c, style = Stroke(2f * u))
            glyph(it.t, c, rr * 1.3f, Color.White.copy(alpha = a), 2.6f)
            if (!prev && look.selItem == it.id) drawCircle(G.cobalt, rr + 4 * u, c, style = Stroke(2.6f * u))
            else if (!prev && it.id in look.bad) drawCircle(RP.issue, rr + 3.5f * u, c, style = Stroke(2.2f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u))))
        }
    }
}

/* ---------------- the front view: one wall from inside ---------------- */

/** One wall seen from inside, fitted in a box: [X] mm along it → px, [Z] mm height → px, and back ([T], [Hh]). */
class FrontFit(val wall: String, val L: Int, val rh: Int, val k: Float, val small: Boolean, private val x0: Float, private val y0: Float, private val s: Float,
               private val z: Float, private val ox: Float, private val oy: Float) {
    fun X(t: Double) = ((x0 + t * s) * z + ox).toFloat()
    fun Z(h: Double) = ((y0 + (rh - h) * s) * z + oy).toFloat()
    fun T(x: Float): Double = (((x - ox) / z - x0) / s).toDouble()
    fun Hh(y: Float): Double = (rh - ((y - oy) / z - y0) / s).toDouble()
}

fun frontFit(wall: String, L: Int, rh: Int, box: Rect, small: Boolean, zz: Float = 1f, ox: Float = 0f, oy: Float = 0f, u: Float): FrontFit {
    val pl = (if (small) 12f else 22f) * u; val pt = (if (small) 16f else 30f) * u; val pb = (if (small) 26f else 44f) * u
    val s = max(1e-5f, min((box.width - 2 * pl) / max(L, 1), (box.height - pt - pb) / max(rh, 1)))
    val x0 = box.left + (box.width - L * s) / 2; val y0 = box.top + pt + ((box.height - pt - pb) - rh * s) / 2
    return FrontFit(wall, L, rh, s * zz, small, x0, y0, s, zz, ox, oy)
}

/** What a tap can hit in the front view: an opening's box, a point's marker; the selected opening's edge handles. */
class FrontRec(val id: String, val op: Boolean, val box: Rect, val c: Offset)
class Handle(val e: String, val c: Offset)

fun frontRecs(r: Room, ff: FrontFit, u: Float): List<FrontRec> {
    val out = ArrayList<FrontRec>()
    r.openings.filter { it.wall == ff.wall }.forEach { o ->
        val xl = ff.X(o.off.toDouble()); val xr = ff.X((o.off + o.w).toDouble())
        out += FrontRec(o.id, true, Rect(min(xl, xr), ff.Z(topOf(o).toDouble()), max(xl, xr), ff.Z(z0Of(o).toDouble())), Offset((xl + xr) / 2, (ff.Z(topOf(o).toDouble()) + ff.Z(z0Of(o).toDouble())) / 2))
    }
    r.points.filter { it.wall == ff.wall }.forEach { p -> val c = Offset(ff.X(p.off.toDouble()), ff.Z(p.h.toDouble())); out += FrontRec(p.id, false, Rect(c, 1f), c) }
    return out
}

fun frontHandles(o: Opening, ff: FrontFit): List<Handle> {
    val xl = min(ff.X(o.off.toDouble()), ff.X((o.off + o.w).toDouble())); val xr = max(ff.X(o.off.toDouble()), ff.X((o.off + o.w).toDouble()))
    val yt = ff.Z(topOf(o).toDouble()); val yb = ff.Z(z0Of(o).toDouble()); val ym = (yt + yb) / 2; val xc = (xl + xr) / 2
    val st = styleId(o)
    val hs = arrayListOf(Handle("l", Offset(xl, ym)), Handle("r", Offset(xr, ym)), Handle("t", Offset(xc, yt)))
    if (o.type == "window" && st != "pano" && st != "balcony") hs += Handle("b", Offset(xc, yb))
    return hs
}

fun hitFront(recs: List<FrontRec>, p: Offset, u: Float): String? {
    var best: Pair<Float, String>? = null
    for (q in recs) {
        val d = if (q.op) { if (p.x >= q.box.left - 6 * u && p.x <= q.box.right + 6 * u && p.y >= q.box.top - 6 * u && p.y <= q.box.bottom + 6 * u) 10f else continue }
        else { val dd = hypot(p.x - q.c.x, p.y - q.c.y); if (dd > 17 * u) continue; dd }
        if (best == null || d < best.first) best = d to q.id
    }
    return best?.second
}

/** The front view: the wall, the floor, the neighbours' letters, the items by style, the selected one with its handles. */
fun DrawScope.drawFront(r: Room, ff: FrontFit, selItem: String?, selWall: Boolean, ghost: Any?, bad: Set<String>, nb: Pair<String, String>, caption: String?, tm: TextMeasurer, u: Float) {
    val xa = min(ff.X(0.0), ff.X(ff.L.toDouble())); val xb = max(ff.X(0.0), ff.X(ff.L.toDouble())); val yt = ff.Z(ff.rh.toDouble()); val yf = ff.Z(0.0)
    drawRect(RP.elev, Offset(xa, yt), Size(xb - xa, yf - yt))
    drawRect(if (selWall) G.cobalt else G.ink3, Offset(xa, yt), Size(xb - xa, yf - yt), style = Stroke((if (selWall) 2.6f else 1.2f) * u))
    ln(Offset(xa - 10 * u, yf), Offset(xb + 10 * u, yf), G.ink2, 2f * u)
    val ls = txtStyle(10.5f, G.ink3, FontWeight.Bold)
    tm.measure("‹ " + nb.first, ls).let { drawText(it, topLeft = Offset(xa + 3 * u, yt - 5 * u - it.size.height)) }
    tm.measure(nb.second + " ›", ls).let { drawText(it, topLeft = Offset(xb - 3 * u - it.size.width, yt - 5 * u - it.size.height)) }
    if (caption != null) tm.measure(caption, txtStyle(11f, G.ink2, FontWeight.Bold)).let { drawText(it, topLeft = Offset((xa + xb) / 2 - it.size.width / 2, yf + 26 * u)) }
    fun item(it: Any, prev: Boolean) {
        val al = if (prev) .62f else 1f
        when (it) {
            is Opening -> {
                if (it.wall != ff.wall) return
                val x1 = ff.X(it.off.toDouble()); val x2 = ff.X((it.off + it.w).toDouble())
                val A = opArt(this, it.type, styleId(it), it.w, it.h, it.sill, it.dw, it.wh, it.sw, min(x1, x2), ff.k, { z -> ff.Z(z) }, u, al)
                if (!prev && selItem == it.id) {
                    drawRect(G.cobalt, Offset(A.xl - 2 * u, A.yt - 2 * u), Size(A.xr - A.xl + 4 * u, A.yb - A.yt + 4 * u), style = Stroke(2.6f * u))
                    frontHandles(it, ff).forEach { h ->
                        val vert = h.e == "l" || h.e == "r"
                        val w = (if (vert) (if (ff.small) 8f else 10f) else (if (ff.small) 22f else 28f)) * u
                        val hh = (if (vert) (if (ff.small) 22f else 28f) else (if (ff.small) 8f else 10f)) * u
                        drawRoundRect(Color.White, Offset(h.c.x - w / 2, h.c.y - hh / 2), Size(w, hh), CornerRadius(3 * u))
                        drawRoundRect(Color(0xFF3550E0), Offset(h.c.x - w / 2, h.c.y - hh / 2), Size(w, hh), CornerRadius(3 * u), style = Stroke(2f * u))
                    }
                } else if (!prev && it.id in bad) drawRect(RP.issue, Offset(A.xl - 3 * u, A.yt - 3 * u), Size(A.xr - A.xl + 6 * u, A.yb - A.yt + 6 * u), style = Stroke(2.2f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u))))
            }
            is SitePoint -> {
                if (it.wall != ff.wall) return
                val x = ff.X(it.off.toDouble()); val y = ff.Z(it.h.toDouble()); val rr = (if (ff.small) 7f else 10f) * u
                ln(Offset(x, y + rr), Offset(x, yf), G.ink3.copy(alpha = al), 1f * u, floatArrayOf(4 * u, 3 * u))
                drawCircle(kindColor(it.t).copy(alpha = al), rr, Offset(x, y)); drawCircle(RP.paper, rr, Offset(x, y), style = Stroke(2f * u))
                glyph(it.t, Offset(x, y), rr * 1.3f, Color.White.copy(alpha = al))
                if (!prev && selItem == it.id) drawCircle(G.cobalt, rr + 4 * u, Offset(x, y), style = Stroke(2.6f * u))
                else if (!prev && it.id in bad) drawCircle(RP.issue, rr + 3.5f * u, Offset(x, y), style = Stroke(2.2f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u))))
            }
        }
    }
    r.openings.forEach { item(it, false) }; r.points.forEach { item(it, false) }
    ghost?.let { item(it, true) }
}

/* ---------------- the styles' front drawings (opArt, ptArt) ---------------- */

/** Where an opening's drawing went: its box, the balcony door's right edge [dx] and window top/bottom. */
class Art(val xl: Float, val xr: Float, val yt: Float, val yb: Float, val dx: Float = 0f, val wyt: Float = 0f, val wyb: Float = 0f)

/**
 * An opening's front drawing (the mockup's opArt): a [kind] door or window of [style], [w] × [h] mm (its [sill], the
 * balcony's door part [dw] and window height [wh]) with its left edge at [xl] px, [k] px per mm, [Z] height → px.
 */
fun opArt(ds: DrawScope, kind: String, style: String, w: Int, h: Int, sill: Int, dw: Int, wh: Int, sw: String, xl: Float, k: Float, Z: (Double) -> Float, u: Float, al: Float = 1f): Art = with(ds) {
    val xr = xl + w * k
    val hs0 = sw.ifEmpty { "L" }.takeLast(1)
    val yb0 = Z(0.0)
    val doorF = RP.doorf.copy(alpha = al); val ink2 = G.ink2.copy(alpha = al); val ink3 = G.ink3.copy(alpha = al)
    fun knob(x: Float, y: Float) = drawCircle(ink2, (k * 30).coerceIn(1.4f * u, 3.2f * u), Offset(x, y))
    fun swg(x0: Float, x1: Float, yt: Float, yb: Float, hs: String) {
        val pth = Path()
        if (hs == "T") { pth.moveTo(x0, yb); pth.lineTo((x0 + x1) / 2, yt); pth.lineTo(x1, yb) }
        else { val hx = if (hs == "L") x0 else x1; val fx = if (hs == "L") x1 else x0; pth.moveTo(fx, yt); pth.lineTo(hx, (yt + yb) / 2); pth.lineTo(fx, yb) }
        drawPath(pth, ink3, style = Stroke(1f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4 * u, 3 * u))))
    }
    fun rect(x: Float, y: Float, ww: Float, hh: Float, fill: Color, line: Color, lw: Float) { drawRect(fill, Offset(x, y), Size(max(0f, ww), max(0f, hh))); drawRect(line, Offset(x, y), Size(max(0f, ww), max(0f, hh)), style = Stroke(lw)) }
    fun door(x0: Float, x1: Float, hh: Int, dt: String, hs: String) {
        val yt = Z(hh.toDouble()); val yb = yb0; val wd = x1 - x0; val hg = yb - yt; val ky = Z(min(1000.0, hh * .47))
        when (dt) {
            "arch" -> { val rr = min(wd / 2, hg * .3f); val pth = Path().apply { moveTo(x0, yb); lineTo(x0, yt + rr); arcTo(Rect(x0, yt, x1, yt + 2 * rr), 180f, 180f, false); lineTo(x1, yb) }
                drawPath(pth, RP.paper); drawPath(pth, ink2, style = Stroke(1.6f * u)) }
            "slide" -> { val pw = wd * .56f; ln(Offset(x0 - 2 * u, yt - 2 * u), Offset(x1 + 2 * u, yt - 2 * u), ink2, 2.6f * u, cap = StrokeCap.Round)
                rect(x0, yt, pw, hg, doorF, ink2, 1.3f * u); rect(x1 - pw, yt, pw, hg, doorF, ink2, 1.3f * u); drawRect(Color(0x12000000), Offset(x1 - pw, yt), Size(pw, hg))
                knob(x0 + pw * .14f, ky); knob(x1 - pw * .14f, ky)
                ln(Offset(x0 + wd * .34f, yt + hg * .28f), Offset(x0 + wd * .66f, yt + hg * .28f), ink3, 1f * u, floatArrayOf(4 * u, 3 * u)) }
            "double" -> { rect(x0, yt, wd, hg, doorF, ink2, 1.3f * u); val xm = x0 + wd / 2; ln(Offset(xm, yt), Offset(xm, yb), ink2, 1.2f * u)
                swg(x0, xm, yt, yb, "L"); swg(xm, x1, yt, yb, "R"); knob(xm - wd * .05f, ky); knob(xm + wd * .05f, ky) }
            "fold" -> { rect(x0, yt, wd, hg, doorF, ink2, 1.3f * u); for (i in 1 until 4) ln(Offset(x0 + wd * i / 4, yt), Offset(x0 + wd * i / 4, yb), ink2, 1.2f * u)
                val pth = Path(); for (j in 0..8) { val x = x0 + wd * j / 8; val y = yt + hg * (if (j % 2 == 1) .09f else .03f); if (j == 0) pth.moveTo(x, y) else pth.lineTo(x, y) }
                drawPath(pth, ink2, style = Stroke(1.1f * u)); knob(x1 - wd * .07f, ky) }
            else -> { rect(x0, yt, wd, hg, doorF, ink2, 1.3f * u)
                if (dt == "glass") { drawRoundRect(RP.winFill.copy(alpha = .38f * al / .45f), Offset(x0 + wd * .17f, yt + hg * .07f), Size(wd * .66f, hg * .8f), CornerRadius(2 * u))
                    drawRoundRect(RP.winLine.copy(alpha = al), Offset(x0 + wd * .17f, yt + hg * .07f), Size(wd * .66f, hg * .8f), CornerRadius(2 * u), style = Stroke(1f * u)) }
                swg(x0, x1, yt, yb, hs); knob(if (hs == "L") x1 - wd * .1f else x0 + wd * .1f, ky) }
        }
    }
    fun win(x0: Float, x1: Float, z0: Int, hh: Int, wt: String, hs: String) {
        val yt = Z((z0 + hh).toDouble()); val yb = Z(z0.toDouble()); val wd = x1 - x0; val hg = yb - yt
        val n = when (wt) { "single" -> 1; "triple", "pano" -> 3; else -> 2 }
        rect(x0, yt, wd, hg, RP.winFill.copy(alpha = .35f * al / .45f), RP.winLine.copy(alpha = al), 1.6f * u)
        for (i in 1 until n) ln(Offset(x0 + wd * i / n, yt), Offset(x0 + wd * i / n, yb), RP.winLine.copy(alpha = al), 1.2f * u)
        when (wt) {
            "fort" -> { val xm = x0 + wd / 2; val yv = yt + hg * .3f; ln(Offset(xm, yv), Offset(x1, yv), RP.winLine.copy(alpha = al), 1.2f * u); swg(xm, x1, yt, yv, "T"); swg(x0, xm, yt, yb, "L") }
            "triple" -> { swg(x0, x0 + wd / 3, yt, yb, "L"); swg(x1 - wd / 3, x1, yt, yb, "R") }
            "pano" -> {}
            else -> swg(x0, if (n == 1) x1 else x0 + wd / 2, yt, yb, if (n == 1) hs else "L")
        }
        if (z0 > 0) ln(Offset(x0 - 3 * u, yb + 1 * u), Offset(x1 + 3 * u, yb + 1 * u), ink2, 2.6f * u, cap = StrokeCap.Round)
    }
    if (style == "balcony") {
        val dx = xl + dw * k
        door(xl, dx, h, "single", "L"); win(dx, xr, h - wh, wh, "double", "L")
        return Art(xl, xr, Z(h.toDouble()), yb0, dx, Z(h.toDouble()), Z((h - wh).toDouble()))
    }
    if (kind == "door") { door(xl, xr, h, style, hs0); return Art(xl, xr, Z(h.toDouble()), yb0) }
    val z0 = if (style == "pano") 0 else sill
    win(xl, xr, z0, h, style, hs0)
    return Art(xl, xr, Z((z0 + h).toDouble()), Z(z0.toDouble()))
}

/** The box a point's drawing takes. */
class PtArt(val w: Float, val h: Float)

/**
 * A point's front drawing by style (the mockup's ptArt), centred on [cx], [cy]; [s] mm → px for the radiator's and the
 * air conditioner's real width [pwMm] (0: the card's own size).
 */
fun ptArt(ds: DrawScope, kind: String, style: String, cx: Float, cy: Float, uu: Float, pwMm: Int = 0, s: Float = 0f): PtArt = with(ds) {
    val pp = Color(0xFFF8FAFC); val ppl = Color(0xFF64748B); val ppc = Color(0xFF94A3B8); val phl = Color(0xFF334155)
    fun rr(x: Float, y: Float, w: Float, h: Float, fill: Color, line: Color?, rad: Float = 0f, lw: Float = 1.2f) {
        drawRoundRect(fill, Offset(x, y), Size(max(0f, w), max(0f, h)), CornerRadius(rad))
        if (line != null) drawRoundRect(line, Offset(x, y), Size(max(0f, w), max(0f, h)), CornerRadius(rad), style = Stroke(lw))
    }
    fun cc(x: Float, y: Float, r: Float, fill: Color?, line: Color? = null, lw: Float = 1.2f) { if (fill != null) drawCircle(fill, max(0f, r), Offset(x, y)); if (line != null) drawCircle(line, max(0f, r), Offset(x, y), style = Stroke(lw)) }
    fun l2(a: Offset, b: Offset, c: Color, w: Float = 1f) = drawLine(c, a, b, w, StrokeCap.Round)
    val c = kindColor(kind)
    var w = 0f; var h = 0f
    when (kind) {
        "socket" -> { val n = when (style) { "two", "usb" -> 2; "three" -> 3; else -> 1 }; val P = (if (style == "power") 30f else 24f) * uu; w = n * P; h = P
            val x0 = cx - w / 2; val y0 = cy - h / 2; rr(x0, y0, w, h, pp, ppl, 4 * uu)
            for (i in 0 until n) { val px = x0 + P * i + P / 2
                if (i > 0) l2(Offset(x0 + P * i, y0 + 3 * uu), Offset(x0 + P * i, y0 + h - 3 * uu), ppc)
                if (style == "usb" && i == 1) { rr(px - 4 * uu, cy - 6 * uu, 8 * uu, 3.4f * uu, phl, null, .8f * uu); rr(px - 4 * uu, cy + 2.6f * uu, 8 * uu, 3.4f * uu, phl, null, .8f * uu); continue }
                if (style == "power") { cc(px, cy - 2.5f * uu, 9.5f * uu, null, ppc); cc(px - 3.8f * uu, cy - 1 * uu, 1.7f * uu, phl); cc(px + 3.8f * uu, cy - 1 * uu, 1.7f * uu, phl); cc(px, cy - 6.5f * uu, 1.7f * uu, phl) }
                else { cc(px, cy, 8.5f * uu, null, ppc); cc(px - 3.3f * uu, cy, 1.5f * uu, phl); cc(px + 3.3f * uu, cy, 1.5f * uu, phl) } } }
        "switch" -> { val n2 = when (style) { "k2" -> 2; "k3" -> 3; else -> 1 }; val iw = 18 * uu; val ix = cx - iw / 2; val iy = cy - iw / 2; val kw = iw / n2; w = 26 * uu; h = w
            rr(cx - w / 2, cy - h / 2, w, h, pp, ppl, 4 * uu)
            for (i in 0 until n2) { rr(ix + i * kw + .6f * uu, iy, kw - 1.2f * uu, iw, Color(0xFFEEF2F7), ppc, 1.5f * uu); if (style != "pass") l2(Offset(ix + i * kw + kw / 2, iy + 3 * uu), Offset(ix + i * kw + kw / 2, iy + 5.5f * uu), ppl, 1.2f * uu) }
            if (style == "pass") { val t1 = Path().apply { moveTo(cx, cy - 7 * uu); lineTo(cx - 3 * uu, cy - 3 * uu); lineTo(cx + 3 * uu, cy - 3 * uu); close(); moveTo(cx, cy + 7 * uu); lineTo(cx - 3 * uu, cy + 3 * uu); lineTo(cx + 3 * uu, cy + 3 * uu); close() }; drawPath(t1, ppl) } }
        "rad" -> { w = if (pwMm > 0 && s > 0) pwMm * s else (when (style) { "towel" -> 38f; "steel" -> 64f; else -> 52f }) * uu
            h = if (s > 0) (if (style == "towel") 800 else 500) * s else (if (style == "towel") 56f else 36f) * uu
            val x0 = cx - w / 2; val y0 = cy - h / 2
            when (style) {
                "towel" -> { val bt = 3 * uu; rr(x0, y0, bt, h, Color(0xFFCBD5E1), ppl, 1.5f * uu, 1f); rr(x0 + w - bt, y0, bt, h, Color(0xFFCBD5E1), ppl, 1.5f * uu, 1f); for (i in 1..5) rr(x0, y0 + h * i / 6 - bt / 2, w, bt, Color(0xFFCBD5E1), ppl, 1.5f * uu, 1f) }
                "steel" -> { rr(x0, y0, w, h, Color(0xFFF1F5F9), ppl, 2 * uu, 1.1f); for (i in 1 until 6) l2(Offset(x0 + 3 * uu, y0 + h * i / 6), Offset(x0 + w - 3 * uu, y0 + h * i / 6), ppc) }
                else -> { val ns = ((if (pwMm > 0) pwMm else 640) / (if (style == "cast") 93.0 else 80.0)).roundToInt().coerceIn(4, 14); val sw2 = w / ns
                    for (i in 0 until ns) rr(x0 + i * sw2 + .5f, y0, sw2 - 1, h, if (style == "cast") Color(0xFFCBD5E1) else Color(0xFFF1F5F9), if (style == "cast") Color(0xFF475569) else ppl, if (style == "cast") min(sw2 / 2.2f, h / 4) else 1.5f * uu, 1.1f)
                    l2(Offset(x0, y0 + h * .16f), Offset(x0 + w, y0 + h * .16f), ppc); l2(Offset(x0, y0 + h * .84f), Offset(x0 + w, y0 + h * .84f), ppc) }
            } }
        "cold", "hot" -> when (style) {
            "mix" -> { val d2 = 15 * uu; w = d2 * 2 + 12 * uu; h = 14 * uu; rr(cx - d2, cy - 1.6f * uu, 2 * d2, 3.2f * uu, Color(0xFFCBD5E1), ppl, 1.6f * uu, 1f)
                cc(cx - d2, cy, 5.5f * uu, kindColor("hot"), Color.White, 1.4f); cc(cx + d2, cy, 5.5f * uu, kindColor("cold"), Color.White, 1.4f); cc(cx - d2, cy, 2 * uu, phl); cc(cx + d2, cy, 2 * uu, phl) }
            "wm" -> { w = 26 * uu; h = w; rr(cx - 2.6f * uu, cy + 3 * uu, 5.2f * uu, 9 * uu, Color(0xFFCBD5E1), ppl, 1 * uu, 1f); cc(cx, cy, 6 * uu, c, Color.White, 1.4f); rr(cx, cy - 2 * uu, 13 * uu, 4 * uu, Color(0xFFDC2626), null, 2 * uu); cc(cx, cy, 2 * uu, phl) }
            else -> { w = 18 * uu; h = w; val hx = Path(); for (i in 0 until 6) { val an = PI / 3 * i + PI / 6; val x = cx + cos(an).toFloat() * 8 * uu; val y = cy + sin(an).toFloat() * 8 * uu; if (i == 0) hx.moveTo(x, y) else hx.lineTo(x, y) }; hx.close()
                drawPath(hx, Color(0xFF94A3B8)); drawPath(hx, Color(0xFF475569), style = Stroke(1f)); cc(cx, cy, 5 * uu, c, Color.White, 1.4f); cc(cx, cy, 2 * uu, phl) }
        }
        "sewer" -> { val rs = (if (style == "d110") 14f else 7f) * uu; w = 2 * rs + 5 * uu; h = w; cc(cx, cy, rs + 2.5f * uu, pp, ppl); cc(cx, cy, rs, c, Color.White, 1.4f); cc(cx, cy, rs * .55f, phl) }
        "gas" -> { val th = (when (style) { "g25" -> 9f; "g20" -> 7f; else -> 5f }) * uu; w = 56 * uu; h = th + 14 * uu
            rr(cx - w / 2, cy - th / 2, w, th, Color(0xFFF59E0B), Color(0xFFB45309), th / 2, 1f); rr(cx - 4 * uu, cy - th / 2 - 2.5f * uu, 8 * uu, th + 5 * uu, Color(0xFF94A3B8), Color(0xFF475569), 1.5f * uu, 1f)
            rr(cx - 1.5f * uu, cy - th / 2 - 11 * uu, 3 * uu, 9 * uu, Color(0xFFDC2626), null, 1.5f * uu) }
        "meter" -> { val bw = (when (style) { "g4" -> 34f; "smart" -> 30f; else -> 26f }) * uu; val bh = (when (style) { "g4" -> 38f; "smart" -> 36f; else -> 30f }) * uu; w = bw; h = bh + 8 * uu
            val x0 = cx - bw / 2; val y0 = cy - bh / 2 + 4 * uu
            rr(cx - bw / 3 - 1.5f * uu, y0 - 8 * uu, 3 * uu, 9 * uu, Color(0xFFF59E0B), Color(0xFFB45309), 0f, 1f); rr(cx + bw / 3 - 1.5f * uu, y0 - 8 * uu, 3 * uu, 9 * uu, Color(0xFFF59E0B), Color(0xFFB45309), 0f, 1f)
            rr(x0, y0, bw, bh, Color(0xFFE2E8F0), Color(0xFF475569), 3 * uu); rr(x0 + bw * .16f, y0 + bh * .18f, bw * .68f, bh * .24f, Color(0xFF0F172A), null, 1.5f * uu)
            for (i in 1 until 5) l2(Offset(x0 + bw * .16f + bw * .68f * i / 5, y0 + bh * .18f), Offset(x0 + bw * .16f + bw * .68f * i / 5, y0 + bh * .42f), ppc)
            if (style == "smart") { rr(x0 + bw * .3f, y0 + bh * .62f, bw * .4f, 2.6f * uu, phl, null, 1 * uu); cc(x0 + bw * .8f, y0 + bh * .84f, 1.8f * uu, Color(0xFF3B82F6)) } else cc(cx, y0 + bh * .7f, 4 * uu, null, ppc) }
        "boiler" -> { val bw2 = (if (style == "dual") 34f else 28f) * uu; val bh2 = 42 * uu; w = bw2; h = bh2 + 12 * uu; val x0 = cx - bw2 / 2; val y0 = cy - bh2 / 2 + 5 * uu
            if (style == "open") rr(cx - 5 * uu, y0 - 11 * uu, 10 * uu, 11 * uu, Color(0xFFCBD5E1), ppl, 0f, 1f) else if (style == "turbo") { rr(cx - 3.5f * uu, y0 - 6 * uu, 7 * uu, 6 * uu, Color(0xFFCBD5E1), ppl, 0f, 1f); rr(cx - 3.5f * uu, y0 - 11 * uu, 20 * uu, 6 * uu, Color(0xFFCBD5E1), ppl, 3 * uu, 1f) }
            rr(x0, y0, bw2, bh2, pp, ppl, 4 * uu)
            if (style == "dual") { rr(x0 + bw2 * .2f, y0 + bh2 * .18f, bw2 * .6f, bh2 * .2f, Color(0xFF0F172A), null, 1.5f * uu); for (i in 0 until 4) rr(x0 + bw2 * (.2f + .2f * i) - 1.5f * uu, y0 + bh2, 3 * uu, 6 * uu, Color(0xFFF59E0B), Color(0xFFB45309), 0f, 1f) }
            else { cc(cx, y0 + bh2 * .62f, 5 * uu, Color(0xFFF97316)); rr(x0 + bw2 * .3f, y0 + bh2 * .18f, bw2 * .4f, 3 * uu, phl, null, 1 * uu) } }
        "ac" -> { w = if (pwMm > 0 && s > 0) pwMm * s else (when (style) { "b18" -> 72f; "b12" -> 62f; "b9" -> 58f; else -> 52f }) * uu; h = if (s > 0) max(14f * uu, 290 * s) else 20 * uu
            val x0 = cx - w / 2; val y0 = cy - h / 2; rr(x0, y0, w, h, pp, ppl, h * .3f); l2(Offset(x0 + w * .08f, y0 + h * .74f), Offset(x0 + w * .92f, y0 + h * .74f), ppc); cc(x0 + w * .86f, y0 + h * .34f, max(1.4f, 1.6f * uu), Color(0xFF3B82F6)) }
        "vent" -> if (style == "sq") { w = 26 * uu; h = w; rr(cx - w / 2, cy - h / 2, w, h, pp, ppl, 2 * uu); for (i in 1 until 6) l2(Offset(cx - w / 2 + 4 * uu, cy - h / 2 + h * i / 6), Offset(cx + w / 2 - 4 * uu, cy - h / 2 + h * i / 6), ppc) }
            else { val rv = (if (style == "r125") 13f else 11f) * uu; w = 2 * rv + 4 * uu; h = w; rr(cx - w / 2, cy - h / 2, w, h, pp, ppl, 3 * uu); cc(cx, cy, rv, null, ppc)
                if (style == "fan") { for (i in 0 until 3) { val a0 = i * 2.094; val a1 = a0 + .9; val R2 = rv * .85f
                    val pth = Path().apply { moveTo(cx, cy); lineTo(cx + cos(a0).toFloat() * R2, cy + sin(a0).toFloat() * R2); lineTo(cx + cos(a1).toFloat() * R2, cy + sin(a1).toFloat() * R2); close() }
                    drawPath(pth, Color(0xFFCBD5E1)); drawPath(pth, ppl, style = Stroke(1f)) }; cc(cx, cy, 2 * uu, phl) }
                else for (i in -1..1) { val yy = cy + i * rv * .45f; val hw = sqrt(rv * rv - (i * rv * .45f) * (i * rv * .45f)) * .85f; l2(Offset(cx - hw, yy), Offset(cx + hw, yy), ppc) } }
        "panel" -> { val rows = when (style) { "m24" -> 2; "m36" -> 3; else -> 1 }; val cols = if (style == "m6") 6 else 12; val mw = 3.2f * uu; val mh = 8 * uu
            w = cols * mw + 10 * uu; h = rows * (mh + 5 * uu) + 9 * uu; val x0 = cx - w / 2; val y0 = cy - h / 2; rr(x0, y0, w, h, pp, ppl, 2.5f * uu)
            for (ri in 0 until rows) { val yr = y0 + 6 * uu + ri * (mh + 5 * uu); l2(Offset(x0 + 3 * uu, yr + mh + 1.6f * uu), Offset(x0 + w - 3 * uu, yr + mh + 1.6f * uu), ppc)
                for (ci in 0 until cols) rr(x0 + 5 * uu + ci * mw + .3f * uu, yr, mw - .6f * uu, mh, Color(0xFFE2E8F0), ppl, .6f * uu, .8f) } }
    }
    PtArt(w, h)
}

/** A style card's picture: the style's standard front view on a strip of floor. */
fun DrawScope.styleThumb(kind: String, style: String, std: Map<String, Int>, u: Float) {
    val W = size.width; val H = size.height
    if (kind == "door" || kind == "window") {
        val bal = style == "balcony"
        val w = if (bal) (std["dw"] ?: 700) + (std["ww"] ?: 1200) else std["w"] ?: 800
        val hh = std["h"] ?: 2100
        val sill = if (kind == "window" && !bal && style != "pano") std["sill"] ?: 900 else 0
        val top = if (bal) hh else sill + hh
        val s = min((W - 28 * u) / w, (H - 12 * u) / top)
        val Z = { z: Double -> (H - 6 * u - z * s).toFloat() }
        val xl = (W - w * s) / 2
        ln(Offset(6 * u, Z(0.0)), Offset(W - 6 * u, Z(0.0)), G.ink2, 2f * u)
        opArt(this, kind, style, w, hh, sill, std["dw"] ?: 0, std["wh"] ?: 0, if (kind == "door") "inL" else "L", xl, s, Z, u)
    } else {
        val pw = std["pw"] ?: 0
        val s = .085f * u * (W / (140 * u))
        ptArt(this, kind, style, W / 2, H / 2, 1.25f * u * (W / (140 * u)), pw, if (pw > 0) s else 0f)
    }
}

private fun DrawScope.dimLab(tm: TextMeasurer, x: Float, y: Float, t: String, u: Float) {
    val lay = tm.measure(t, txtStyle(12f, Color.White))
    val w = lay.size.width + 14 * u; val h = 20 * u
    val xx = x.coerceIn(w / 2 + 2 * u, size.width - w / 2 - 2 * u)
    drawRoundRect(G.cobalt, Offset(xx - w / 2, y - h / 2), Size(w, h), CornerRadius(h / 2))
    drawText(lay, topLeft = Offset(xx - lay.size.width / 2f, y - lay.size.height / 2f))
}

private fun DrawScope.dimH(tm: TextMeasurer, x1: Float, x2: Float, y: Float, t: String, u: Float) {
    val a = min(x1, x2); val b = max(x1, x2); val c = G.cobalt
    ln(Offset(a, y), Offset(b, y), c, 1.6f * u); ln(Offset(a, y - 6 * u), Offset(a, y + 6 * u), c, 1.6f * u); ln(Offset(b, y - 6 * u), Offset(b, y + 6 * u), c, 1.6f * u)
    drawPath(Path().apply { moveTo(a, y); lineTo(a + 6 * u, y - 3.5f * u); lineTo(a + 6 * u, y + 3.5f * u); close(); moveTo(b, y); lineTo(b - 6 * u, y - 3.5f * u); lineTo(b - 6 * u, y + 3.5f * u); close() }, c)
    dimLab(tm, (a + b) / 2, y, t, u)
}

private fun DrawScope.dimV(tm: TextMeasurer, x: Float, y1: Float, y2: Float, t: String, u: Float) {
    val a = min(y1, y2); val b = max(y1, y2); val c = G.cobalt
    ln(Offset(x, a), Offset(x, b), c, 1.6f * u); ln(Offset(x - 6 * u, a), Offset(x + 6 * u, a), c, 1.6f * u); ln(Offset(x - 6 * u, b), Offset(x + 6 * u, b), c, 1.6f * u)
    drawPath(Path().apply { moveTo(x, a); lineTo(x - 3.5f * u, a + 6 * u); lineTo(x + 3.5f * u, a + 6 * u); close(); moveTo(x, b); lineTo(x - 3.5f * u, b - 6 * u); lineTo(x + 3.5f * u, b - 6 * u); close() }, c)
    dimLab(tm, x, (a + b) / 2, t, u)
}

/**
 * The size step's big drawing (the mockup's pkDraw): the style on a wall up to the ceiling, the edge being asked [f] in
 * blue with arrows and its value, a red dashed box when it is wrong.
 */
fun DrawScope.pkDraw(kind: String, style: String, v: Map<String, Int>, f: String, rh: Int, bad: Boolean, ceilWord: String, tm: TextMeasurer, u: Float) {
    val W = size.width; val H = size.height; val pt = 24 * u; val pb = 14 * u
    fun wall(Z: (Double) -> Float) {
        drawRect(RP.elev, Offset(8 * u, Z(rh.toDouble())), Size(W - 16 * u, Z(0.0) - Z(rh.toDouble())))
        drawRect(G.ink3, Offset(8 * u, Z(rh.toDouble())), Size(W - 16 * u, Z(0.0) - Z(rh.toDouble())), style = Stroke(1.2f * u))
        ln(Offset(8 * u, Z(rh.toDouble())), Offset(W - 8 * u, Z(rh.toDouble())), G.ink3, 1.2f * u, floatArrayOf(5 * u, 4 * u))
        tm.measure("$ceilWord ${mm(rh)}", txtStyle(10.5f, G.ink3, FontWeight.Bold)).let { drawText(it, topLeft = Offset(14 * u, Z(rh.toDouble()) - 6 * u - it.size.height)) }
        ln(Offset(4 * u, Z(0.0)), Offset(W - 4 * u, Z(0.0)), G.ink2, 2f * u)
    }
    val pe = { a: Offset, b: Offset -> ln(a, b, G.cobalt, 4.5f * u, cap = StrokeCap.Round) }
    if (kind == "door" || kind == "window") {
        val bal = style == "balcony"
        val w = if (bal) (v["dw"] ?: 0) + (v["ww"] ?: 0) else v["w"] ?: 0
        val hh = v["h"] ?: 0
        val sill = if (kind == "window" && !bal && style != "pano") v["sill"] ?: 0 else 0
        val s = min((W - 110 * u) / max(w, 600), (H - pt - pb) / max(rh, 1))
        val Z = { z: Double -> (H - pb - z * s).toFloat() }
        val xl = (W - w * s) / 2
        wall(Z)
        val A = opArt(this, kind, style, w, hh, sill, v["dw"] ?: 0, v["wh"] ?: 0, if (kind == "door") "inL" else "L", xl, s, Z, u)
        if (bad) drawRoundRect(RP.red, Offset(A.xl - 4 * u, A.yt - 4 * u), Size(A.xr - A.xl + 8 * u, A.yb - A.yt + 8 * u), CornerRadius(3 * u), style = Stroke(2.2f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5 * u, 3 * u))))
        when (f) {
            "w" -> { pe(Offset(A.xl, A.yt), Offset(A.xr, A.yt)); dimH(tm, A.xl, A.xr, A.yt - 13 * u, mm(v["w"] ?: 0), u) }
            "h" -> if (bal) { pe(Offset(A.xl, A.yt), Offset(A.xl, A.yb)); dimV(tm, A.xl - 16 * u, A.yt, A.yb, mm(hh), u) } else { pe(Offset(A.xr, A.yt), Offset(A.xr, A.yb)); dimV(tm, A.xr + 16 * u, A.yt, A.yb, mm(hh), u) }
            "sill" -> { pe(Offset(A.xl, A.yb), Offset(A.xr, A.yb)); dimV(tm, A.xr + 16 * u, A.yb, Z(0.0), mm(sill), u) }
            "dw" -> { pe(Offset(A.xl, A.yt), Offset(A.dx, A.yt)); dimH(tm, A.xl, A.dx, A.yt - 13 * u, mm(v["dw"] ?: 0), u) }
            "ww" -> { pe(Offset(A.dx, A.wyt), Offset(A.xr, A.wyt)); dimH(tm, A.dx, A.xr, A.wyt - 13 * u, mm(v["ww"] ?: 0), u) }
            "wh" -> { pe(Offset(A.xr, A.wyt), Offset(A.xr, A.wyb)); dimV(tm, A.xr + 16 * u, A.wyt, A.wyb, mm(v["wh"] ?: 0), u) }
        }
    } else {
        val s2 = min((W - 80 * u) / 2000f, (H - pt - pb) / max(rh, 1))
        val Z2 = { z: Double -> (H - pb - z * s2).toFloat() }
        val cx = W / 2; val ph = v["ph"] ?: 0; val cy = Z2(ph.toDouble()); val ex = s2 * 1.8f
        wall(Z2)
        val pw = v["pw"] ?: 0
        val g = ptArt(this, kind, style, cx, cy, 1.5f * u, pw, if (pw > 0) ex else 0f)
        ln(Offset(cx, cy + g.h / 2), Offset(cx, Z2(0.0)), G.ink3, 1f * u, floatArrayOf(4 * u, 3 * u))
        if (bad) drawRoundRect(RP.red, Offset(cx - g.w / 2 - 4 * u, cy - g.h / 2 - 4 * u), Size(g.w + 8 * u, g.h + 8 * u), CornerRadius(3 * u), style = Stroke(2.2f * u, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5 * u, 3 * u))))
        if (f == "ph") { ln(Offset(cx - g.w / 2 - 6 * u, cy), Offset(cx + g.w / 2 + 6 * u, cy), G.cobalt, 1.6f * u); dimV(tm, cx + g.w / 2 + 22 * u, cy, Z2(0.0), mm(ph), u) }
        else if (f == "pw") { pe(Offset(cx - g.w / 2, cy - g.h / 2), Offset(cx + g.w / 2, cy - g.h / 2)); dimH(tm, cx - g.w / 2, cx + g.w / 2, cy - g.h / 2 - 13 * u, mm(pw), u) }
    }
}

/* ---------------- simple 3D (isometric, tappable) ---------------- */

/** A tappable face of the 3D: an item's or a wall's polygon (drawn later = on top). */
class IsoHit(val id: String, val wall: Boolean, val poly: List<Offset>)

/** The room in simple isometric 3D (the mockup's isoSvg): back walls full height with their items, front walls low. */
fun DrawScope.drawIso(r: Room, ws: List<RW>, top: Float, z: Zoom, selItem: String?, selWall: String?, bad: Set<String>, tm: TextMeasurer, u: Float, hits: MutableList<IsoHit>) {
    hits.clear()
    val W = size.width; val H = size.height; val rh = roomH(r).toDouble()
    val P3 = ws.map { turn(it.a, r.rot) }
    fun Q(x: Double, y: Double, zz: Double) = Pair((x - y) * .866, (x + y) * .5 - zz)
    var b0 = Double.MAX_VALUE; var b1 = Double.MAX_VALUE; var b2 = -Double.MAX_VALUE; var b3 = -Double.MAX_VALUE
    P3.forEach { p -> listOf(0.0, rh).forEach { zz -> val q = Q(p.x, p.y, zz); b0 = min(b0, q.first); b1 = min(b1, q.second); b2 = max(b2, q.first); b3 = max(b3, q.second) } }
    val pad = 26 * u
    val s = min((W - 2 * pad) / (b2 - b0), (H - top - 2 * pad) / (b3 - b1))
    val ox = (W - (b2 - b0) * s) / 2 - b0 * s; val oy = top + (H - top - (b3 - b1) * s) / 2 - b1 * s
    fun S2(x: Double, y: Double, zz: Double): Offset { val q = Q(x, y, zz); return Offset(((ox + q.first * s) * z.z + z.ox).toFloat(), ((oy + q.second * s) * z.z + z.oy).toFloat()) }
    val outline = Color(0x61141828)
    fun poly(pts: List<Offset>, fill: Color, sel: Boolean = false, badP: Boolean = false) {
        val pth = polyPath(pts); drawPath(pth, fill)
        drawPath(pth, if (sel) Color(0xFF3550E0) else if (badP) RP.issue else outline, style = Stroke((if (sel) 2.6f else if (badP) 2.2f else .8f) * u))
    }
    data class W3(val i: Int, val id: String, val a: Pt, val b: Pt, val u: Pt, val n: Pt, val back: Boolean, val d: Double)
    val pr = P3.map { Offset(it.x.toFloat(), it.y.toFloat()) }
    val walls = ws.mapIndexed { i, w ->
        val a = turn(w.a, r.rot); val b = turn(w.b, r.rot); val L = max(hypot(b.x - a.x, b.y - a.y), 1e-6)
        val uu = Pt((b.x - a.x) / L, (b.y - a.y) / L); var nn = Pt(-uu.y, uu.x)
        val m = Offset(((a.x + b.x) / 2 + nn.x * 5).toFloat(), ((a.y + b.y) / 2 + nn.y * 5).toFloat())
        if (!pip(m, pr)) nn = Pt(-nn.x, -nn.y)
        W3(i, w.id, a, b, uu, nn, nn.x + nn.y > .05, a.x + b.x + a.y + b.y)
    }
    fun at(w: W3, t: Double, zz: Double, off: Double) = S2(w.a.x + w.u.x * t + w.n.x * off, w.a.y + w.u.y * t + w.n.y * off, zz)
    poly(P3.map { S2(it.x, it.y, 0.0) }, RP.isoFloor)
    fun wall3(w: W3, hh: Double, full: Boolean) {
        val t = thickOf(r, w.id).toDouble()
        val ao = Pt(w.a.x - w.n.x * t, w.a.y - w.n.y * t); val bo = Pt(w.b.x - w.n.x * t, w.b.y - w.n.y * t)
        val face = listOf(S2(w.a.x, w.a.y, 0.0), S2(w.b.x, w.b.y, 0.0), S2(w.b.x, w.b.y, hh), S2(w.a.x, w.a.y, hh))
        val ws0 = selWall == w.id
        poly(face, if (abs(w.u.x) > abs(w.u.y)) RP.isoWall else RP.isoWall2, ws0)
        poly(listOf(S2(w.a.x, w.a.y, hh), S2(w.b.x, w.b.y, hh), S2(bo.x, bo.y, hh), S2(ao.x, ao.y, hh)), RP.isoCap, ws0)
        hits += IsoHit(w.id, true, face)
        if (!full) return
        r.openings.filter { it.wall == w.id }.forEach { o ->
            val sel = selItem == o.id; val bd = o.id in bad
            if (o.balcony) {
                val d = listOf(at(w, o.off.toDouble(), 0.0, 4.0), at(w, (o.off + o.dw).toDouble(), 0.0, 4.0), at(w, (o.off + o.dw).toDouble(), o.h.toDouble(), 4.0), at(w, o.off.toDouble(), o.h.toDouble(), 4.0))
                val g = listOf(at(w, (o.off + o.dw).toDouble(), (o.h - o.wh).toDouble(), 4.0), at(w, (o.off + o.w).toDouble(), (o.h - o.wh).toDouble(), 4.0), at(w, (o.off + o.w).toDouble(), o.h.toDouble(), 4.0), at(w, (o.off + o.dw).toDouble(), o.h.toDouble(), 4.0))
                poly(d, RP.doorf, sel, bd); poly(g, Color(0x8038BDF8), sel, bd); hits += IsoHit(o.id, false, d); hits += IsoHit(o.id, false, g)
            } else {
                val z0 = z0Of(o).toDouble(); val z1 = topOf(o).toDouble()
                val q = listOf(at(w, o.off.toDouble(), z0, 4.0), at(w, (o.off + o.w).toDouble(), z0, 4.0), at(w, (o.off + o.w).toDouble(), z1, 4.0), at(w, o.off.toDouble(), z1, 4.0))
                poly(q, if (o.type == "door" && styleId(o) != "glass") RP.doorf else Color(0x8038BDF8), sel, bd); hits += IsoHit(o.id, false, q)
            }
        }
        r.points.filter { it.wall == w.id }.forEach { p ->
            val q0 = 110.0
            val q = listOf(at(w, p.off - q0, p.h - q0, 5.0), at(w, p.off + q0, p.h - q0, 5.0), at(w, p.off + q0, p.h + q0, 5.0), at(w, p.off - q0, p.h + q0, 5.0))
            poly(q, kindColor(p.t), selItem == p.id, p.id in bad); hits += IsoHit(p.id, false, q)
        }
        val tp = S2((w.a.x + w.b.x) / 2, (w.a.y + w.b.y) / 2, hh + 140)
        tm.measure(w.id, txtStyle(12f, G.ink2)).let { drawText(it, topLeft = Offset(tp.x - it.size.width / 2f, tp.y - it.size.height)) }
    }
    val order = walls.sortedBy { it.d }
    order.forEach { if (it.back) wall3(it, rh, true) }
    order.forEach { if (!it.back) wall3(it, 280.0, false) }
}

/** The face under [p], items before walls, the one drawn last first. */
fun hitIso(hits: List<IsoHit>, p: Offset): IsoHit? = hits.asReversed().firstOrNull { !it.wall && pip(p, it.poly) } ?: hits.asReversed().firstOrNull { it.wall && pip(p, it.poly) }
