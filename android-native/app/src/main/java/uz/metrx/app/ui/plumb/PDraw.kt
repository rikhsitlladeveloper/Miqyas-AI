package uz.metrx.app.ui.plumb

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.drawText
import uz.metrx.app.plumb.APt
import uz.metrx.app.plumb.PCtx
import uz.metrx.app.plumb.PLoop
import uz.metrx.app.plumb.PRun
import uz.metrx.app.plumb.PlFix
import uz.metrx.app.plumb.PlRiser
import uz.metrx.app.plumb.RISER_D
import uz.metrx.app.plumb.RISER_W
import uz.metrx.app.plumb.UFH_RGB
import uz.metrx.app.plumb.fixD
import uz.metrx.app.plumb.fixTop
import uz.metrx.app.plumb.fixW
import uz.metrx.app.plumb.fixZ0
import uz.metrx.app.plumb.kindRgb
import uz.metrx.app.plumb.snake
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import uz.metrx.app.ui.elec.PlanMap
import uz.metrx.app.ui.elec.WallMap
import uz.metrx.app.ui.elec.rgbC
import kotlin.math.max

/*
 * The plumber's drawings, shared by the screen and the PDF: a top-view symbol for every fixture, the room from above with
 * its fixtures, the riser, the pipes in their colours and the underfloor loops, and a wall seen straight on with its
 * fixtures, outlets and their heights and the pipes on it. Drawn from millimetres through the electrician's mappings.
 */

val P_INK = Color(0xFF0E1C36)
private val P_FLOOR = Color(0xFFF1F4F8)
private val P_DOOR = Color(0xFF2E5BFF)
private val P_WIN = Color(0xFF9DB8E8)
private val P_WARN = Color(0xFFDC2626)

/** The layers the views show: water (cold and hot), drains, heating (supply, return, the floor's loops). */
val LAYERS = listOf("water", "drain", "heat")
fun layerOf(kind: String) = when (kind) { "cold", "hot" -> "water"; "drain" -> "drain"; else -> "heat" }

/** A fixture's top view drawn in its own frame: [lp] maps (mm along the wall from its centre, mm into the room) to pixels. */
private fun DrawScope.drawFixTop(t: String, fw: Double, fd: Double, lp: (Double, Double) -> Offset, ink: Color, sw: Float, cab: Boolean) {
    fun poly(vararg q: Pair<Double, Double>, fill: Color? = null, w: Float = sw) {
        val o = q.map { lp(it.first, it.second) }
        val p = Path().apply { moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        if (fill != null) drawPath(p, fill)
        drawPath(p, ink, style = Stroke(w))
    }
    fun oval(a: Double, d: Double, ra: Double, rd: Double, fill: Color? = null) {
        val q = (0 until 16).map { i -> val k = 2 * Math.PI * i / 16; (a + ra * kotlin.math.cos(k)) to (d + rd * kotlin.math.sin(k)) }
        poly(*q.toTypedArray(), fill = fill)
    }
    val h = fw / 2
    poly(-h to 0.0, h to 0.0, h to fd, -h to fd, fill = Color.White)
    when (t) {
        "wc" -> { poly(-h to 0.0, h to 0.0, h to 170.0, -h to 170.0); oval(0.0, 400.0, 160.0, 220.0) }
        "bs", "bsm" -> { oval(0.0, fd * .55, fw * .36, fd * .32); if (cab) poly(-h + 10 to fd - 20, h - 10 to fd - 20) }
        "bath" -> { poly(-h + 70 to 70.0, h - 70 to 70.0, h - 70 to fd - 70, -h + 70 to fd - 70); oval(-h + 200, fd / 2, 30.0, 30.0) }
        "sh", "cab" -> { poly(-h to 0.0, h to fd); poly(h to 0.0, -h to fd); oval(0.0, fd / 2, 40.0, 40.0, Color.White); if (t == "cab") poly(-h to fd - 8, h to fd - 8) }
        "sink" -> { poly(-250.0 to 100.0, 250.0 to 100.0, 250.0 to fd - 100, -250.0 to fd - 100); oval(0.0, fd / 2, 30.0, 30.0) }
        "wm" -> oval(0.0, fd / 2, fw * .33, fd * .33)
        "dw" -> { poly(-h + 60 to fd - 60, h - 60 to fd - 60); poly(-h + 60 to fd - 120, h - 60 to fd - 120) }
        "wh" -> oval(0.0, fd / 2, fw * .42, fd * .42)
        "gb" -> poly(-60.0 to fd * .3, 0.0 to fd * .8, 60.0 to fd * .3)
        "rad" -> { var a = -h + 80; while (a < h - 1) { poly(a to 10.0, a to fd); a += 80 } }
        "tr" -> { poly(-h to 60.0, h to 60.0) }
        "manif" -> { var a = -h + 60; while (a < h - 1) { oval(a, fd / 2, 18.0, 18.0); a += 80 } }
    }
}

/** A fixture's symbol for the lists and the legend: its top view fitted into a square [r] half wide at [c]. */
fun DrawScope.fixSymbol(t: String, c: Offset, r: Float, ink: Color = P_INK) {
    val ty = uz.metrx.app.plumb.fixType(t)
    val fw = ty.w.toDouble(); val fd = ty.d.toDouble()
    val k = (2 * r / max(fw, fd)).toFloat()
    drawFixTop(t, fw, fd, { a, d -> Offset(c.x + (a * k).toFloat(), c.y - (fd / 2 * k).toFloat() + (d * k).toFloat()) }, ink, max(1f, r * .1f), false)
}

/** An outlet's symbol: a dot in its kind's colour ([d] a drain's diameter makes it larger). */
fun DrawScope.ptSymbol(t: String, c: Offset, r: Float, ring: Color = Color.White) {
    drawCircle(rgbC(kindRgb(t)), r, c)
    drawCircle(ring, r, c, style = Stroke(max(1f, r * .3f)))
}

/** The riser's symbol: its box with the drain stack and the water pipes. */
fun DrawScope.riserSymbol(c: Offset, r: Float, hot: Boolean = true) {
    drawRect(Color.White, Offset(c.x - r, c.y - r), Size(2 * r, 2 * r))
    drawRect(P_INK, Offset(c.x - r, c.y - r), Size(2 * r, 2 * r), style = Stroke(max(1f, r * .15f)))
    drawCircle(rgbC(kindRgb("drain")), r * .45f, Offset(c.x - r * .3f, c.y))
    drawCircle(rgbC(kindRgb("cold")), r * .22f, Offset(c.x + r * .45f, c.y - r * .35f))
    if (hot) drawCircle(rgbC(kindRgb("hot")), r * .22f, Offset(c.x + r * .45f, c.y + r * .35f))
}

/** Where along wall [w] plan point [q] is, mm. */
private fun alongOf(w: TWall, q: V2) = (q - w.p0).dot(w.t)

/**
 * The room from above: the floor, the walls, the doors with their swing, the windows, the underfloor loops, the pipes in
 * their colours, the fixtures, the outlets and the riser ([sel] ringed, [bad] in red). [layers] the kinds shown; [sym]
 * the symbols' size.
 */
fun DrawScope.drawPlumbPlan(c: PCtx, m: PlanMap, fs: List<PlFix>, pts: List<APt>, rs: PlRiser?, runs: List<PRun>, loop: PLoop?, sym: Float,
                            layers: Set<String> = LAYERS.toSet(), sel: String? = null, bad: Set<String> = emptySet()) {
    val f = c.g.floor
    val out = Path().apply { val o = f.map { m.at(it) }; moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
    drawPath(out, P_FLOOR)
    if (loop != null && "heat" in layers) for (k in 0 until loop.n) snake(c, loop.step, k, loop.n).forEach { (a, b) ->
        drawLine(rgbC(UFH_RGB, if (k % 2 == 0) .9f else .6f), m.at(a), m.at(b), max(1f, sym * .14f))
    }
    drawPath(out, P_INK, style = Stroke(max(2f, sym * .45f), join = androidx.compose.ui.graphics.StrokeJoin.Miter))
    c.room.openings.forEach { o ->
        val w = c.wall(o.wall) ?: return@forEach
        val a = m.at(w.at(o.off.toDouble())); val b = m.at(w.at((o.off + o.w).toDouble()))
        if (o.type == "door") {
            drawLine(P_FLOOR, a, b, max(3f, sym * .6f))
            val tip = m.at(w.at(o.off.toDouble(), o.w.toDouble()))
            drawLine(P_DOOR, a, tip, max(1.2f, sym * .2f))
            val rad = (tip - a).getDistance()
            val st = Math.toDegrees(kotlin.math.atan2((b - a).y.toDouble(), (b - a).x.toDouble())).toFloat()
            val en = Math.toDegrees(kotlin.math.atan2((tip - a).y.toDouble(), (tip - a).x.toDouble())).toFloat()
            var sweep = en - st; while (sweep > 180) sweep -= 360f; while (sweep < -180) sweep += 360f
            drawArc(P_DOOR, st, sweep, false, Offset(a.x - rad, a.y - rad), Size(2 * rad, 2 * rad), style = Stroke(max(1f, sym * .12f), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))))
        } else drawLine(P_WIN, a, b, max(3f, sym * .55f))
    }
    // the fixtures: wall-hung ones over floor ones
    fs.sortedBy { fixZ0(it) }.forEach { fx ->
        val w = c.wall(fx.wall) ?: return@forEach
        val x = fx.off.toDouble()
        val ink = if (fx.id in bad) P_WARN else P_INK
        drawFixTop(fx.t, fixW(fx).toDouble(), fixD(fx).toDouble(), { a, d -> m.at(w.at(x + a, d)) }, ink, max(1f, sym * .14f), fx.opt == "cab")
        if (fx.id == sel) {
            val q = listOf(m.at(w.at(x - fixW(fx) / 2.0 - 40, -40.0)), m.at(w.at(x + fixW(fx) / 2.0 + 40, -40.0)), m.at(w.at(x + fixW(fx) / 2.0 + 40, fixD(fx) + 40.0)), m.at(w.at(x - fixW(fx) / 2.0 - 40, fixD(fx) + 40.0)))
            val p = Path().apply { moveTo(q[0].x, q[0].y); q.drop(1).forEach { lineTo(it.x, it.y) }; close() }
            drawPath(p, P_DOOR, style = Stroke(2.5f))
        }
    }
    // the pipes over the fixtures, each kind its own lane in from the wall so they read side by side: drains wide and grey
    // under the water, heating on top
    runs.sortedBy { when (it.kind) { "drain" -> 0; "cold" -> 1; "hot" -> 2; else -> 3 } }.forEach { r ->
        if (layerOf(r.kind) !in layers) return@forEach
        val col = rgbC(kindRgb(r.kind))
        val wpx = if (r.kind == "drain") max(1.6f, (r.dia * m.k).coerceAtMost(sym * .6f)) else max(1.2f, sym * .2f)
        val lane = (sym * when (r.kind) { "drain" -> .55f; "cold" -> .6f; "hot" -> .95f; "hs" -> 1.3f; else -> 1.65f } / m.k).toDouble()
        r.segs.forEach { g ->
            // pieces along a wall go in by their lane (minus how far the route already is off the wall); in the floor as they are
            val n = c.wall(g.wall)?.nIn
            val inA = n?.let { (g.a - (c.wall(g.wall)!!.p0)).dot(it) } ?: 0.0
            val sh = if (n != null && inA < 200) n * max(0.0, lane - inA) else null
            val a = m.at(if (sh != null) g.a + sh else g.a); val b = m.at(if (sh != null) g.b + sh else g.b)
            if ((a - b).getDistance() > .5f) drawLine(col.copy(alpha = .9f), a, b, wpx, StrokeCap.Round)
        }
    }
    pts.filter { layerOf(it.t) in layers }.forEach { q ->
        val w = c.wall(q.wall) ?: return@forEach
        ptSymbol(q.t, m.at(w.at(q.off.toDouble(), 30.0)), max(2.5f, sym * .32f))
        if (q.fix == null && q.id == sel) drawCircle(P_DOOR, sym * .9f, m.at(w.at(q.off.toDouble(), 30.0)), style = Stroke(2f))
    }
    if (rs != null && rs.roomId == c.id) c.wall(rs.wall)?.let { w ->
        val at = m.at(w.at(rs.off.toDouble(), RISER_D / 2.0))
        riserSymbol(at, max(sym * .8f, (RISER_W / 2.0 * m.k).toFloat()), rs.hot)
        if (sel == "riser") drawCircle(P_DOOR, sym * 1.8f, at, style = Stroke(2.5f))
    }
}

/**
 * Wall [w] of room [c] straight on: its doors and windows, the fixtures against it, the pipes on it, the riser, and the
 * outlets each with its height when [label] is given ([sel] ringed, [bad] in red, [drag] one being moved).
 */
fun DrawScope.drawPlumbWall(c: PCtx, w: TWall, m: WallMap, fs: List<PlFix>, pts: List<APt>, rs: PlRiser?, runs: List<PRun>, label: ((String) -> TextLayoutResult)?,
                            layers: Set<String> = LAYERS.toSet(), sel: String? = null, bad: Set<String> = emptySet(), minR: Float = 5f) {
    val H = c.g.H
    drawRect(Color(0xFFF7F9FC), Offset(m.x(0.0), m.y(H)), Size((w.len * m.k).toFloat(), (H * m.k).toFloat()))
    drawRect(P_INK, Offset(m.x(0.0), m.y(H)), Size((w.len * m.k).toFloat(), (H * m.k).toFloat()), style = Stroke(2f))
    c.room.openings.filter { it.wall == w.id }.forEach { o ->
        val tl = m.at(o.off.toDouble(), (o.sill + o.h).toDouble()); val sz = Size((o.w * m.k), (o.h * m.k))
        if (o.type == "door") { drawRect(Color.White, tl, sz); drawRect(P_DOOR, tl, sz, style = Stroke(1.5f)); drawLine(P_DOOR, m.at(o.off.toDouble(), 0.0), m.at(o.off.toDouble(), o.h.toDouble()), 3f) }
        else { drawRect(Color(0xFFE5EEFB), tl, sz); drawRect(P_WIN, tl, sz, style = Stroke(1.5f)) }
    }
    // the fixtures standing against the wall, seen from the front
    fs.filter { it.wall == w.id }.sortedBy { fixZ0(it) }.forEach { fx ->
        val a0 = fx.off - fixW(fx) / 2.0; val a1 = fx.off + fixW(fx) / 2.0
        val z0 = fixZ0(fx).toDouble(); val z1 = fixTop(fx).toDouble()
        val ink = if (fx.id in bad) P_WARN else P_INK
        val tl = m.at(a0, z1); val sz = Size(((a1 - a0) * m.k).toFloat(), ((z1 - z0) * m.k).toFloat())
        drawRect(if (fx.t == "cab") Color(0x33BFDBFE) else Color.White, tl, sz); drawRect(ink, tl, sz, style = Stroke(1.3f))
        when (fx.t) {
            "wc" -> drawRect(ink, m.at(fx.off - 190.0, z1), Size(380 * m.k, 380 * m.k), style = Stroke(1f))
            "bs", "bsm" -> if (fx.opt == "cab") drawRect(ink, m.at(a0 + 10, z1 - 160), Size(((a1 - a0 - 20) * m.k).toFloat(), ((z1 - 160) * m.k).toFloat()), style = Stroke(1f))
            "wm" -> drawCircle(ink, 200 * m.k, m.at(fx.off.toDouble(), 430.0), style = Stroke(1.2f))
            "rad" -> { var a = a0 + 80; while (a < a1 - 1) { drawLine(ink, m.at(a, z0), m.at(a, z1), .8f); a += 80 } }
            "sink" -> drawLine(ink, m.at(a0, 820.0), m.at(a1, 820.0), 1f)
        }
        if (fx.id == sel) drawRect(P_DOOR, Offset(tl.x - 4, tl.y - 4), Size(sz.width + 8, sz.height + 8), style = Stroke(2.5f))
    }
    if (rs != null && rs.roomId == c.id && rs.wall == w.id) {
        val x = rs.off.toDouble()
        drawLine(rgbC(kindRgb("drain")), m.at(x - 55, 0.0), m.at(x - 55, H), max(2f, 110 * m.k))
        drawLine(rgbC(kindRgb("cold")), m.at(x + 40, 0.0), m.at(x + 40, H), max(1.5f, 32 * m.k))
        if (rs.hot) drawLine(rgbC(kindRgb("hot")), m.at(x + 100, 0.0), m.at(x + 100, H), max(1.5f, 32 * m.k))
        drawRect(Color(0xFFE5E7EB), m.at(x + 10, 860.0), Size(120 * m.k, 100 * m.k)); drawRect(P_INK, m.at(x + 10, 860.0), Size(120 * m.k, 100 * m.k), style = Stroke(1f))
        if (sel == "riser") drawRect(P_DOOR, m.at(x - RISER_W / 2.0, H), Size(RISER_W * m.k, (H * m.k).toFloat()), style = Stroke(2.5f))
        if (label != null) { val t = label("riser"); drawText(t, topLeft = Offset(m.x(x + RISER_W / 2.0) + 3, m.y(H * .5))) }
    }
    runs.forEach { r ->
        if (layerOf(r.kind) !in layers) return@forEach
        val col = rgbC(kindRgb(r.kind))
        val wpx = if (r.kind == "drain") max(2f, (r.dia * m.k).toFloat()) else max(1.5f, 24 * m.k)
        r.segs.filter { it.wall == w.id }.forEach { g -> drawLine(col, m.at(alongOf(w, g.a), g.za), m.at(alongOf(w, g.b), g.zb), wpx, StrokeCap.Round) }
    }
    val r0 = max(minR, 35 * m.k)
    // the heights: right of the outlet, else left of it, else left out when another label (an outlet beside it) is there
    val taken = ArrayList<androidx.compose.ui.geometry.Rect>()
    pts.filter { it.wall == w.id && layerOf(it.t) in layers }.sortedBy { it.off }.forEach { q ->
        val at = m.at(q.off.toDouble(), q.h.toDouble())
        if (label != null) {
            drawLine(Color(0x553E4A61), Offset(at.x, at.y + r0), Offset(at.x, m.y(0.0)), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f)))
            val t = label("${q.h}")
            val tw = t.size.width.toFloat(); val th = t.size.height.toFloat(); val top = at.y - th - r0 * .2f
            val spot = listOf(at.x + r0 * .9f, at.x - r0 * .9f - tw).map { x -> androidx.compose.ui.geometry.Rect(x, top, x + tw, top + th) }
                .firstOrNull { r -> taken.none { it.overlaps(r) } }
            if (spot != null) { taken += spot; drawText(t, topLeft = spot.topLeft) }
        }
        ptSymbol(q.t, at, r0, if ((q.fix ?: q.id) in bad) P_WARN else Color.White)
        if (q.fix == null && q.id == sel) drawCircle(P_DOOR, r0 * 1.8f, at, style = Stroke(2f))
    }
    drawLine(P_INK, Offset(m.x(0.0) - 6, m.y(0.0)), Offset(m.x(w.len) + 6, m.y(0.0)), 3f)
}

/** The fixture types shown, in the legend's order. */
fun legendFix(fs: List<PlFix>): List<String> = uz.metrx.app.plumb.FIX_TYPES.map { it.id }.filter { t -> fs.any { it.t == t } }
