package uz.metrx.app.ui.editor

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import uz.metrx.app.ui.furniture.drawSitePoint
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.Theme
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/* The plan of a rectangular room, as the prototype's planSVG (core) restyled by glass.css (.gs-room). */

/*
 * The plan's colours. In the editor they follow the dark theme (a light drawing on the dark blueprint); on paper (the
 * report's plans, run inside Theme.onPaper) they keep their light values.
 */
internal val planDark get() = Theme.dark && !Theme.paper
internal fun pc(light: Long, dark: Long) = Color(if (planDark) dark else light)

internal val INK get() = pc(0xFF0E1C36, 0xFFE2E8F2)
internal val INK3 get() = pc(0xFF3E4A61, 0xFFAEB8CB)
internal val GREY_LINE get() = pc(0xFF5F6B82, 0xFF8792A8)
internal val COB get() = pc(0xFF1C4BD1, 0xFF8C9CFF)
internal val AMBER get() = pc(0xFF9A4D00, 0xFFFFB45C)
internal val RED get() = pc(0xFFB42318, 0xFFFF8A80)
internal val PAPER get() = pc(0xFFF3F6FA, 0xFF141A28)
internal val SEL_BAND get() = pc(0xFFE7EEFD, 0xFF1C2546)
internal val OK_GREEN get() = pc(0xFF15803D, 0xFF4ADE80)
/** The plan's white: the wall ring under its hatching, windows, letter discs, corner handles. */
internal val PLAN_W get() = pc(0xFFFFFFFF, 0xFF1A2134)
/** Letters and marks on a COB or RED fill (a selected wall's letter, the crossing mark). */
internal val ON_FILL get() = pc(0xFFFFFFFF, 0xFF0B0E16)
/** The pale blue inside a room being reshaped or a closed sketch. */
internal val COB_WASH get() = pc(0x121C4BD1, 0x1F8C9CFF)
/** The value in a dimension pill. */
internal val PILL_INK get() = pc(0xFF0F172A, 0xFFE8ECF4)
/** A dimension pill's glass and edge: white glass, or smoky glass dense enough that the dimension line doesn't show through. */
internal fun pillFill(a: Float) = if (planDark) Color(0xFF1C2333).copy(alpha = minOf(1f, a + .12f)) else Color.White.copy(alpha = a)
internal fun pillEdge(a: Float) = if (planDark) Color.White.copy(alpha = .18f) else Color.White.copy(alpha = a)
/** A disabled icon (undo with nothing to undo). */
internal val OFF_ICON get() = if (Theme.dark) Color(0xFF5A6377) else Color(0xFF94A3B8)
internal val UNIT1 = Density(1f, 1f)

/** One wall as drawn: its inner face from [a] to [b], outward normal [n], screen side 0 top, 1 right, 2 bottom, 3 left. */
internal data class SideWall(val id: String, val key: String, val corner: Int, val side: Int, val a: Offset, val b: Offset, val n: Offset, val realLen: Int)

/** Where everything sits, in the prototype's 360-wide viewBox. */
internal class RectLayout(r: Room) {
    val VW = 360f
    val MY = 68f
    val T: Int = r.dim("T").v ?: 200
    val L: Int; val W: Int
    init {
        val a = r.dim("A"); val b = r.dim("B")
        val la = a.v ?: a.pending?.mm; val lb = b.v ?: b.pending?.mm
        L = when { la != null -> la; lb != null -> (lb * 1.25).roundToInt(); else -> 5000 }
        W = when { lb != null -> lb; la != null -> (la * .8).roundToInt(); else -> 4000 }
    }
    val rot = r.rot % 4
    private val SW = if (rot % 2 == 0) L else W
    private val SH = if (rot % 2 == 0) W else L
    val s: Float = min((VW - 176f) / (SW + 2 * T), 210f / (SH + 2 * T))
    val tw: Float = max(3f, T * s)
    val iw = SW * s; val ih = SH * s
    val ox = (VW - iw) / 2f; val oy = MY + tw
    val VH = ih + 2 * tw + 2 * MY
    val inner = Rect(ox, oy, ox + iw, oy + ih)

    private val corners = listOf(Offset(ox, oy), Offset(ox + iw, oy), Offset(ox + iw, oy + ih), Offset(ox, oy + ih))
    private val normals = listOf(Offset(0f, -1f), Offset(1f, 0f), Offset(0f, 1f), Offset(-1f, 0f))

    /** Walls A–D in order; wall i sits on side (i + rot) % 4. */
    val walls: List<SideWall> = listOf("A", "B", "C", "D").mapIndexed { i, id ->
        val side = (i + rot) % 4
        SideWall(id, if (i % 2 == 0) "A" else "B", i + 1, side, corners[side], corners[(side + 1) % 4], normals[side], if (i % 2 == 0) L else W)
    }
    fun wall(id: String) = walls.first { it.id == id }
    fun onSide(side: Int) = walls.first { it.side == side }
}

private fun unitV(a: Offset, b: Offset): Offset { val d = b - a; val l = hypot(d.x, d.y); return if (l == 0f) Offset(1f, 0f) else Offset(d.x / l, d.y / l) }

/** Dimension pill sizes: 26 high, 16 + 8 per character (+15 with an icon), as in the prototype. */
internal fun pillW(text: String, icon: Boolean) = 16f + 8f * text.length + if (icon) 15f else 0f

/** Something tappable in the plan, in viewBox units. */
internal sealed interface PlanHit {
    data class Dim(val wall: String) : PlanHit
    data class Op(val id: String) : PlanHit
}

/**
 * The plan canvas: draws the room fitted into the box, handles taps (walls, dimension pills, doors and windows)
 * and drags of doors and windows along their wall (prototype openings.js drag, plan part).
 */
@Composable
fun RectPlan(
    r: Room, sel: String?, selOp: String?, unit: LenUnit, english: Boolean, label: String,
    issueOf: (Opening) -> Boolean,
    onWall: (String) -> Unit, onOpening: (String) -> Unit,
    onDragEnd: (Opening, Int) -> Unit, tipText: (Opening, Int) -> String,
    modifier: Modifier = Modifier
) {
    val tm = rememberTextMeasurer()
    var drag by remember { mutableStateOf<Pair<String, Int>?>(null) }      // opening id, live offset
    var finger by remember { mutableStateOf(Offset.Zero) }
    val lay = RectLayout(r)
    Canvas(modifier.pointerInput(r, unit) {
        awaitEachGesture {
            val down = awaitFirstDown()
            val k = min(size.width / lay.VW, size.height / lay.VH)
            val dx = (size.width - lay.VW * k) / 2f; val dy = (size.height - lay.VH * k) / 2f
            fun toVb(p: Offset) = Offset((p.x - dx) / k, (p.y - dy) / k)
            val start = down.position
            val hit = hitTest(lay, r, toVb(start))
            val op = (hit as? PlanHit.Op)?.let { h -> r.openings.firstOrNull { it.id == h.id } }
            var dragging = false
            var lastOff = op?.off ?: 0
            while (true) {
                val ev = awaitPointerEvent()
                val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                if (!ch.pressed) break
                val d = ch.position - start
                if (op != null && !dragging && hypot(d.x, d.y) > 7.dp.toPx()) dragging = true
                if (dragging && op != null) {
                    ch.consume()
                    val w = lay.wall(op.wall); val u = unitV(w.a, w.b)
                    val along = (d.x * u.x + d.y * u.y) / k / lay.s
                    lastOff = snapOff(op.off + along.roundToInt(), op.w, w.realLen.takeIf { r.dim(w.key).v != null })
                    drag = op.id to lastOff; finger = ch.position
                }
            }
            if (dragging && op != null) { drag = null; onDragEnd(op, lastOff) }
            else when (hit) {
                is PlanHit.Dim -> onWall(hit.wall)
                is PlanHit.Op -> onOpening(hit.id)
                null -> {}
            }
        }
    }) {
        val k = min(size.width / lay.VW, size.height / lay.VH)
        val dx = (size.width - lay.VW * k) / 2f; val dy = (size.height - lay.VH * k) / 2f
        val live = drag
        val room = if (live == null) r else r.copy(openings = r.openings.map { if (it.id == live.first) it.copy(off = live.second) else it })
        withTransform({ translate(dx, dy); scale(k, k, pivot = Offset.Zero) }) {
            drawRectPlan(lay, room, sel, selOp ?: live?.first, unit, english, label, issueOf, tm)
        }
        if (live != null) {
            val o = room.openings.firstOrNull { it.id == live.first }
            if (o != null) dragTip(tm, tipText(o, live.second), finger, issueOf(o))
        }
    }
}

private val Int.dp get() = androidx.compose.ui.unit.Dp(this.toFloat())

/** Offset snapping while dragging (prototype snapOff): 10 mm steps, the wall centre within 60, each end within 40. */
fun snapOff(off: Int, w: Int, L: Int?): Int {
    var o = (off / 10.0).roundToInt() * 10
    if (L == null) return max(0, o)
    val mx = max(0, L - w); val mid = ((L - w) / 2.0 / 10).roundToInt() * 10
    if (abs(o - mid) < 60) o = mid
    if (o < 40) o = 0
    if (mx - o < 40) o = mx
    return o.coerceIn(0, mx)
}

private fun hitTest(lay: RectLayout, r: Room, p: Offset): PlanHit? {
    // doors and windows first: their band reaches 150 mm past each side and 30 px into the room
    for (o in r.openings) {
        val w = lay.wall(o.wall); val u = unitV(w.a, w.b)
        val a0 = (o.off - 150) * lay.s; val a1 = (o.off + o.w + 150) * lay.s
        val rel = p - w.a
        val along = rel.x * u.x + rel.y * u.y
        val out = rel.x * w.n.x + rel.y * w.n.y
        if (along in a0..a1 && out in -30f..lay.tw + 6f) return PlanHit.Op(o.id)
    }
    // dimension pills (top and right)
    listOf(0, 1).forEach { side ->
        val w = lay.onSide(side)
        val c = pillCenter(lay, w)
        if (abs(p.x - c.x) < 46 && abs(p.y - c.y) < 20) return PlanHit.Dim(w.id)
    }
    // wall bands, 12 px around the wall
    for (w in lay.walls) {
        val u = unitV(w.a, w.b); val rel = p - w.a
        val along = rel.x * u.x + rel.y * u.y
        val out = rel.x * w.n.x + rel.y * w.n.y
        val len = hypot(w.b.x - w.a.x, w.b.y - w.a.y)
        if (along in -12f..len + 12f && out in -12f..lay.tw + 12f) return PlanHit.Dim(w.id)
    }
    return null
}

private fun pillCenter(lay: RectLayout, w: SideWall): Offset {
    val mid = Offset((w.a.x + w.b.x) / 2f, (w.a.y + w.b.y) / 2f)
    return mid + w.n * (lay.tw + 42f)
}

private fun DrawScope.drawRectPlan(lay: RectLayout, r: Room, sel: String?, selOp: String?, unit: LenUnit, english: Boolean, label: String,
                                   issueOf: (Opening) -> Boolean, tm: TextMeasurer, report: Boolean = false) {
    val tw = lay.tw; val inn = lay.inner
    val outer = Rect(inn.left - tw, inn.top - tw, inn.right + tw, inn.bottom + tw)
    // selected wall: a pale band with a blue edge, padded 5
    lay.walls.firstOrNull { it.id == sel }?.let { w -> drawWallBand(w, tw, 5f, SEL_BAND, COB) }
    // walls: a hatched ring outside the room
    val ring = Path().apply { addRect(outer); addRect(inn); fillType = androidx.compose.ui.graphics.PathFillType.EvenOdd }
    drawPath(ring, PLAN_W)
    clipPath(ring) {
        var x = outer.left - outer.height
        while (x < outer.right + outer.height) { drawLine(INK, Offset(x, outer.bottom), Offset(x + outer.height, outer.top), 1.1f); x += 4f * 1.4142f }
    }
    drawRect(INK, outer.topLeft, outer.size, style = Stroke(1.2f)); drawRect(INK, inn.topLeft, inn.size, style = Stroke(1.2f))
    lay.walls.firstOrNull { it.id == sel }?.let { w -> drawWallBand(w, tw, 0f, COB, null) }

    // doors and windows across the wall
    r.openings.forEach { o -> drawOpening(lay, o, if (issueOf(o)) RED else if (o.id == selOp) COB else INK, issueOf(o)) }
    // furniture orders: sockets, switches and pipes, just inside their wall (furniture plan section 5)
    r.points.forEach { x ->
        val w = lay.wall(x.wall); val u = unitV(w.a, w.b)
        drawSitePoint(x, w.a + u * (x.off * lay.s) - w.n * 7f, 0f, 6.5f, 1f)
    }

    // centre label: NAME and the floor area
    val a = areas(r)
    val cx = inn.center.x; val cy = inn.center.y
    centreLabel(tm, label, (if (a != null) fmtArea(a.floor, english) else "?") + " m²", Offset(cx, cy))

    // wall letters (17 px inside) and corner numbers
    lay.walls.forEach { w ->
        val mid = Offset((w.a.x + w.b.x) / 2f, (w.a.y + w.b.y) / 2f) - w.n * 17f
        val on = w.id == sel
        drawCircle(if (on) COB else PLAN_W, 9f, mid)
        drawCircle(if (on) COB else INK3, 9f, mid, style = Stroke(1f))
        text(tm, w.id, mid, TextStyle(fontFamily = Jakarta, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (on) ON_FILL else INK))
        val u = unitV(w.a, w.b)
        val c = w.a - w.n * 10f + u * 10f
        text(tm, "${w.corner}", c, TextStyle(fontFamily = Jakarta, fontSize = 9.5.sp, color = INK3))
    }

    // chain dimensions on walls with doors or windows
    lay.walls.forEach { w -> val ops = r.openings.filter { it.wall == w.id }.sortedBy { it.off }; if (ops.isNotEmpty()) chain(lay, w, ops, unit, english, tm) }

    // overall dimensions: the walls on top and on the right
    listOf(0, 1).forEach { side -> overall(lay, lay.onSide(side), r, unit, english, tm, report) }
}

/**
 * A room's plan for the report (prototype planSVG with report:true), in the prototype's 360-wide units: returns the
 * drawing's height. Rectangle and drawn rooms alike; dimension values in plain white boxes.
 */
fun DrawScope.drawReportPlan(r: Room, unit: LenUnit, english: Boolean, label: String, tm: TextMeasurer, snap: Boolean): Float =
    Theme.onPaper {
        if (r.isPoly) drawReportPoly(r, unit, english, label, tm, snap)
        else { val lay = RectLayout(r); drawRectPlan(lay, r, null, null, unit, english, label, { false }, tm, report = true); lay.VH }
    }

/** The height of a room's plan drawing in the 360-wide units. */
fun reportPlanHeight(r: Room, snap: Boolean): Float = if (r.isPoly) reportPolyHeight(r, snap) else RectLayout(r).VH

private fun DrawScope.drawWallBand(w: SideWall, tw: Float, pad: Float, fill: Color, edge: Color?) {
    val u = unitV(w.a, w.b)
    val p1 = w.a - u * pad - w.n * pad; val p2 = w.b + u * pad - w.n * pad
    val p3 = w.b + u * pad + w.n * (tw + pad); val p4 = w.a - u * pad + w.n * (tw + pad)
    val path = Path().apply { moveTo(p1.x, p1.y); lineTo(p2.x, p2.y); lineTo(p3.x, p3.y); lineTo(p4.x, p4.y); close() }
    drawPath(path, fill)
    if (edge != null) drawPath(path, edge, style = Stroke(1.5f))
}

private fun DrawScope.drawOpening(lay: RectLayout, o: Opening, c: Color, bad: Boolean) {
    val w = lay.wall(o.wall); val u = unitV(w.a, w.b); val s = lay.s; val tw = lay.tw
    val a = w.a + u * (o.off * s); val b = w.a + u * ((o.off + o.w) * s)
    val quad = Path().apply { moveTo(a.x, a.y); lineTo(b.x, b.y); val b2 = b + w.n * tw; val a2 = a + w.n * tw; lineTo(b2.x, b2.y); lineTo(a2.x, a2.y); close() }
    if (o.type == "door") {
        drawPath(quad, PAPER)
        drawLine(c, a, a + w.n * tw, 1.2f); drawLine(c, b, b + w.n * tw, 1.2f)
        val tip = a - w.n * (o.w * s)
        drawLine(c, a, tip, 2.2f, StrokeCap.Round)
        // the swing: an arc round the hinge from the far edge to the leaf tip
        val rad = o.w * s
        val startAng = Math.toDegrees(kotlin.math.atan2((b - a).y.toDouble(), (b - a).x.toDouble())).toFloat()
        val endAng = Math.toDegrees(kotlin.math.atan2((tip - a).y.toDouble(), (tip - a).x.toDouble())).toFloat()
        var sweep = endAng - startAng; while (sweep > 180) sweep -= 360f; while (sweep < -180) sweep += 360f
        drawArc(c, startAng, sweep, false, Offset(a.x - rad, a.y - rad), Size(2 * rad, 2 * rad), style = Stroke(1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f))))
    } else {
        drawPath(quad, PLAN_W)
        drawPath(quad, c, style = Stroke(1.2f))
        drawLine(c, a + w.n * (tw / 3), b + w.n * (tw / 3), 1f); drawLine(c, a + w.n * (2 * tw / 3), b + w.n * (2 * tw / 3), 1f)
    }
    if (o.approx && !bad) {
        val pad = 3f; val box = Path().apply {
            val p1 = a - u * pad - w.n * pad; val p2 = b + u * pad - w.n * pad; val p3 = b + u * pad + w.n * (tw + pad); val p4 = a - u * pad + w.n * (tw + pad)
            moveTo(p1.x, p1.y); lineTo(p2.x, p2.y); lineTo(p3.x, p3.y); lineTo(p4.x, p4.y); close() }
        drawPath(box, AMBER, style = Stroke(1.4f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))))
    }
    if (bad) {
        val pad = 4f; val box = Path().apply {
            val p1 = a - u * pad - w.n * pad; val p2 = b + u * pad - w.n * pad; val p3 = b + u * pad + w.n * (tw + pad); val p4 = a - u * pad + w.n * (tw + pad)
            moveTo(p1.x, p1.y); lineTo(p2.x, p2.y); lineTo(p3.x, p3.y); lineTo(p4.x, p4.y); close() }
        drawPath(box, RED, style = Stroke(2.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))))
    }
}

private fun DrawScope.chain(lay: RectLayout, w: SideWall, ops: List<Opening>, unit: LenUnit, english: Boolean, tm: TextMeasurer) {
    val u = unitV(w.a, w.b); val s = lay.s
    val off = lay.tw + 18f
    val cuts = (listOf(0) + ops.flatMap { listOf(it.off, it.off + it.w) } + w.realLen).map { it.coerceIn(0, max(w.realLen, it)) }.distinct().sorted()
    val base = w.a + w.n * off
    val endPt = w.a + u * (cuts.last() * s) + w.n * off
    drawLine(INK3, base, endPt, .9f)
    cuts.forEach { c -> val p = w.a + u * (c * s) + w.n * off; drawLine(INK3, p - (u + w.n) * 3f, p + (u + w.n) * 3f, 1.2f) }
    val st = TextStyle(fontFamily = PlexCond, fontSize = 11.5.sp, color = INK3)
    for (i in 0 until cuts.size - 1) {
        val mid = (cuts[i] + cuts[i + 1]) / 2f
        val p = w.a + u * (mid * s) + w.n * (lay.tw + 9f)
        val t = fmtLen(cuts[i + 1] - cuts[i], unit, english)
        if (w.side % 2 == 1) rotate(-90f, p) { text(tm, t, p, st) } else text(tm, t, p, st)
    }
}

private fun DrawScope.overall(lay: RectLayout, w: SideWall, r: Room, unit: LenUnit, english: Boolean, tm: TextMeasurer, report: Boolean = false) {
    val d = r.dim(w.key)
    val st = d.status
    val lineC = when (st) { "conf" -> INK; "recv" -> AMBER; else -> GREY_LINE }
    val dash = if (st == "conf") null else PathEffect.dashPathEffect(floatArrayOf(5f, 4f))
    val off = lay.tw + 42f
    val a = w.a + w.n * off; val b = w.b + w.n * off
    // extension lines from the wall to past the dimension line
    drawLine(lineC, w.a + w.n * (lay.tw + 3f), w.a + w.n * (off + 5f), .9f)
    drawLine(lineC, w.b + w.n * (lay.tw + 3f), w.b + w.n * (off + 5f), .9f)
    drawLine(lineC, a, b, 1.1f, pathEffect = dash)
    val u = unitV(w.a, w.b); val diag = (u + w.n) * 4f
    listOf(a, b).forEach { p -> drawLine(lineC, p - diag, p + diag, 1.6f) }
    // the pill: white glass, value, a check when confirmed or a clock while a reading waits
    val txt = when (st) { "recv" -> fmtLen(d.pending!!.mm, unit, english, full = true); "conf" -> fmtLen(d.v, unit, english); else -> "?" }
    val icon = st != "unset"
    val pw = pillW(txt, icon)
    val c = pillCenter(lay, w)
    val rect = Rect(c.x - pw / 2, c.y - 13f, c.x + pw / 2, c.y + 13f)
    if (report) {
        // the report's box: white, square-ish corners, the value in the condensed face and a dark check
        drawRoundRect(Color.White, rect.topLeft, rect.size, CornerRadius(3f))
        text(tm, txt, Offset(if (st == "conf") c.x - 7f else c.x, c.y), TextStyle(fontFamily = PlexCond, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = INK))
        if (st == "conf") { val x = rect.right - 14f; drawPath(Path().apply { moveTo(x, c.y); relativeLineTo(3f, 3f); relativeLineTo(5.5f, -5.5f) }, INK, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)) }
        return
    }
    drawIntoCanvas { cv ->
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            color = if (planDark) android.graphics.Color.argb(90, 0, 0, 0) else android.graphics.Color.argb(36, 30, 40, 110)
            maskFilter = android.graphics.BlurMaskFilter(6f, android.graphics.BlurMaskFilter.Blur.NORMAL)
        }
        cv.nativeCanvas.drawRoundRect(rect.left, rect.top + 4f, rect.right, rect.bottom + 4f, 13f, 13f, paint)
    }
    drawRoundRect(pillFill(.78f), rect.topLeft, rect.size, CornerRadius(13f))
    drawRoundRect(pillEdge(.95f), rect.topLeft, rect.size, CornerRadius(13f), style = Stroke(1.2f))
    val textX = when (st) { "conf" -> c.x - 7f; "recv" -> c.x + 7f; else -> c.x }
    text(tm, txt, Offset(textX, c.y), TextStyle(fontFamily = Jakarta, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = PILL_INK))
    if (st == "conf") {
        val x = rect.right - 14f
        drawPath(Path().apply { moveTo(x, c.y); relativeLineTo(3f, 3f); relativeLineTo(5.5f, -5.5f) }, OK_GREEN, style = Stroke(2.4f, cap = StrokeCap.Round, join = StrokeJoin.Round))
    } else if (st == "recv") {
        val cc = Offset(rect.left + 12f, c.y)
        drawCircle(AMBER, 5f, cc, style = Stroke(1.6f))
        drawLine(AMBER, cc, cc + Offset(0f, -3f), 1.6f, StrokeCap.Round); drawLine(AMBER, cc, cc + Offset(2.2f, 1.2f), 1.6f, StrokeCap.Round)
    }
}

/** What the middle of a room shows (Profile → Xona yorlig‘i): "both", "name", "area" or "none". Set from Settings. */
object PlanLabel { var mode by androidx.compose.runtime.mutableStateOf("both") }

/** The room's name and floor area in its middle, as chosen in Profile (prototype roomLabel). */
internal fun DrawScope.centreLabel(tm: TextMeasurer, name: String, area: String, c: Offset) {
    val m = PlanLabel.mode
    val nm = m == "both" || m == "name"; val ar = m == "both" || m == "area"
    val nameSt = TextStyle(fontFamily = Jakarta, fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold, letterSpacing = .06.em, color = INK3)
    val areaSt = TextStyle(fontFamily = PlexCond, fontSize = 12.5.sp, color = INK3)
    when {
        nm && ar -> { text(tm, name.uppercase(), Offset(c.x, c.y - 7f), nameSt); text(tm, area, Offset(c.x, c.y + 8f), areaSt) }
        nm -> text(tm, name.uppercase(), c, nameSt)
        ar -> text(tm, area, c, areaSt)
    }
}

/** Text centred on [c], measured at density 1 so sizes are viewBox units. */
internal fun DrawScope.text(tm: TextMeasurer, s: String, c: Offset, style: TextStyle) {
    val r = tm.measure(s, style, density = UNIT1)
    drawText(r, topLeft = Offset(c.x - r.size.width / 2f, c.y - r.size.height / 2f))
}

/** The dark tooltip above the finger while dragging (prototype .dg-tip). Drawn in screen pixels. */
internal fun DrawScope.dragTip(tm: TextMeasurer, s: String, finger: Offset, bad: Boolean) {
    val r = tm.measure(s, TextStyle(fontFamily = Jakarta, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White))
    val pad = 10.dp.toPx(); val w = r.size.width + 2 * pad; val h = r.size.height + 12.dp.toPx()
    val left = (finger.x - w / 2).coerceIn(4f, size.width - w - 4f)
    val top = (finger.y - 18.dp.toPx() - h - 40.dp.toPx()).coerceAtLeast(4f)
    drawRoundRect(if (bad) pc(0xFFB42318, 0xFFC8372A) else pc(0xF20F1626, 0xF22A3247), Offset(left, top), Size(w, h), CornerRadius(h / 2))
    drawText(r, topLeft = Offset(left + pad, top + 6.dp.toPx()))
}
