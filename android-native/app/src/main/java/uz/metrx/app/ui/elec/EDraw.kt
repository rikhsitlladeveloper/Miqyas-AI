package uz.metrx.app.ui.elec

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.drawText
import uz.metrx.app.elec.CRun
import uz.metrx.app.elec.Circuit
import uz.metrx.app.elec.ECtx
import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecPanel
import uz.metrx.app.elec.GAS
import uz.metrx.app.elec.WATER
import uz.metrx.app.elec.ZONE_DOWN
import uz.metrx.app.elec.devSize
import uz.metrx.app.elec.devType
import uz.metrx.app.elec.panelSize
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/*
 * The electrician's drawings, shared by the screen and the PDF: a symbol for every device type, the room from above
 * with its devices and coloured routes, and a wall seen straight on with its devices, their heights and the routes on
 * it. Everything is drawn from millimetres through a mapping, so one drawing serves any size.
 */

val E_INK = Color(0xFF0E1C36)
private val E_WALL = Color(0xFF0E1C36)
private val E_FLOOR = Color(0xFFF1F4F8)
private val E_DOOR = Color(0xFF2E5BFF)
private val E_WIN = Color(0xFF9DB8E8)
private val E_WATER = Color(0xFF2563EB)
private val E_GAS = Color(0xFFEAB308)
private val E_WARN = Color(0xFFDC2626)

fun rgbC(rgb: Int, a: Float = 1f) = Color(((rgb shr 16) and 255) / 255f, ((rgb shr 8) and 255) / 255f, (rgb and 255) / 255f, a)

/** A device's symbol centred at [c], [r] its half size in pixels: sockets round, switches with a key, lights crossed, low-voltage triangles. */
fun DrawScope.devSymbol(t: String, c: Offset, r: Float, col: Color, ink: Color = E_INK, fill: Color = Color.White) {
    val sw = max(1f, r * .16f)
    fun ring(cc: Offset = c, rr: Float = r) { drawCircle(fill, rr, cc); drawCircle(ink, rr, cc, style = Stroke(sw)) }
    fun square(rr: Float = r) { drawRect(fill, Offset(c.x - rr, c.y - rr), Size(2 * rr, 2 * rr)); drawRect(ink, Offset(c.x - rr, c.y - rr), Size(2 * rr, 2 * rr), style = Stroke(sw)) }
    fun dots() { drawCircle(ink, r * .17f, Offset(c.x - r * .38f, c.y)); drawCircle(ink, r * .17f, Offset(c.x + r * .38f, c.y)) }
    fun line(a: Offset, b: Offset, w: Float = sw) = drawLine(ink, a, b, w, StrokeCap.Round)
    fun mark() = drawCircle(col, r * .28f, Offset(c.x + r * .78f, c.y - r * .78f))
    when (t) {
        "s1" -> { ring(); dots(); mark() }
        "s2" -> { ring(Offset(c.x - r * .45f, c.y), r * .8f); ring(Offset(c.x + r * .45f, c.y), r * .8f)
            drawCircle(ink, r * .13f, Offset(c.x - r * .45f, c.y)); drawCircle(ink, r * .13f, Offset(c.x + r * .45f, c.y)); mark() }
        "sw" -> { ring(); dots(); drawArc(ink, 200f, 140f, false, Offset(c.x - r * 1.25f, c.y - r * 1.25f), Size(2.5f * r, 2.5f * r), style = Stroke(sw)); mark() }
        "su" -> { ring(); drawRect(ink, Offset(c.x - r * .42f, c.y - r * .2f), Size(r * .84f, r * .4f), style = Stroke(sw)); mark() }
        "pst" -> { square(); line(Offset(c.x - r * .6f, c.y - r * .6f), Offset(c.x + r * .6f, c.y + r * .6f)); line(Offset(c.x - r * .6f, c.y + r * .6f), Offset(c.x + r * .6f, c.y - r * .6f)); mark() }
        "pov" -> { square(); line(Offset(c.x - r * .6f, c.y), Offset(c.x + r * .6f, c.y)); line(Offset(c.x - r * .6f, c.y - r * .4f), Offset(c.x + r * .6f, c.y - r * .4f)); mark() }
        "pac" -> { square(); repeat(3) { i -> val a = PI * i / 3; line(Offset(c.x - r * .65f * cos(a).toFloat(), c.y - r * .65f * sin(a).toFloat()), Offset(c.x + r * .65f * cos(a).toFloat(), c.y + r * .65f * sin(a).toFloat())) }; mark() }
        "pwh" -> { square(); val p = Path().apply { moveTo(c.x, c.y - r * .6f); lineTo(c.x + r * .45f, c.y + r * .2f); quadraticTo(c.x, c.y + r * .9f, c.x - r * .45f, c.y + r * .2f); close() }; drawPath(p, ink, style = Stroke(sw)); mark() }
        "k1", "k2", "kp", "kd" -> {
            drawCircle(fill, r * .62f, c); drawCircle(ink, r * .62f, c, style = Stroke(sw)); drawCircle(ink, r * .2f, c)
            val tip = Offset(c.x + r * 1.05f, c.y - r * 1.05f)
            line(c, tip)
            if (t == "k2") line(Offset(c.x + r * .25f, c.y + r * .1f), Offset(c.x + r * 1.25f, c.y - r * .8f))
            if (t == "kp") line(c, Offset(c.x - r * 1.05f, c.y + r * 1.05f))
            if (t == "kd") drawArc(ink, -90f, 90f, false, Offset(c.x - r * .95f, c.y - r * .95f), Size(1.9f * r, 1.9f * r), style = Stroke(sw))
            line(tip, Offset(tip.x + r * .3f, tip.y + r * .3f))
            drawCircle(col, r * .24f, Offset(c.x - r * .8f, c.y - r * .8f))
        }
        "lc", "lch", "lw" -> {
            if (t == "lch") { drawCircle(fill, r * 1.2f, c); drawCircle(ink, r * 1.2f, c, style = Stroke(sw)) }
            ring(); val k = r * .7f
            line(Offset(c.x - k, c.y - k), Offset(c.x + k, c.y + k)); line(Offset(c.x - k, c.y + k), Offset(c.x + k, c.y - k))
            if (t == "lw") line(Offset(c.x - r * 1.2f, c.y + r * 1.15f), Offset(c.x + r * 1.2f, c.y + r * 1.15f), sw * 1.6f)
            drawCircle(col, r * .25f, Offset(c.x + r * .9f, c.y - r * .9f))
        }
        "ls" -> { drawCircle(fill, r * .7f, c); drawCircle(ink, r * .7f, c, style = Stroke(sw)); drawCircle(col, r * .38f, c) }
        "led" -> drawLine(col, Offset(c.x - r * 1.3f, c.y), Offset(c.x + r * 1.3f, c.y), r * .5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(r * .5f, r * .3f)))
        "tv", "lan", "int", "cam", "bell" -> {
            val p = Path().apply { moveTo(c.x, c.y - r); lineTo(c.x + r, c.y + r * .8f); lineTo(c.x - r, c.y + r * .8f); close() }
            drawPath(p, fill); drawPath(p, ink, style = Stroke(sw))
            when (t) {
                "tv" -> drawRect(ink, Offset(c.x - r * .38f, c.y), Size(r * .76f, r * .5f), style = Stroke(sw * .8f))
                "lan" -> { drawCircle(ink, r * .13f, Offset(c.x - r * .3f, c.y + r * .35f)); drawCircle(ink, r * .13f, Offset(c.x + r * .3f, c.y + r * .35f)) }
                "int" -> { line(Offset(c.x - r * .35f, c.y + r * .1f), Offset(c.x + r * .35f, c.y + r * .1f)); line(Offset(c.x - r * .35f, c.y + r * .45f), Offset(c.x + r * .35f, c.y + r * .45f)) }
                "cam" -> drawCircle(ink, r * .22f, Offset(c.x, c.y + r * .3f))
                else -> drawArc(ink, 180f, 180f, false, Offset(c.x - r * .35f, c.y - r * .05f), Size(r * .7f, r * .7f), style = Stroke(sw))
            }
        }
        "jb" -> { square(r * .8f); line(Offset(c.x - r * .8f, c.y + r * .8f), Offset(c.x + r * .8f, c.y - r * .8f)) }
        "panel" -> {
            drawRect(fill, Offset(c.x - r * 1.1f, c.y - r * .8f), Size(r * 2.2f, r * 1.6f))
            val p = Path().apply { moveTo(c.x - r * 1.1f, c.y + r * .8f); lineTo(c.x + r * 1.1f, c.y - r * .8f); lineTo(c.x + r * 1.1f, c.y + r * .8f); close() }
            drawPath(p, ink)
            drawRect(ink, Offset(c.x - r * 1.1f, c.y - r * .8f), Size(r * 2.2f, r * 1.6f), style = Stroke(sw))
        }
        else -> ring()
    }
}

/** How the room from above maps into a box: plan mm → pixels, the room fitted and centred with [margin] round it. */
class PlanMap(private val f: List<V2>, box: Rect, margin: Float) {
    constructor(c: ECtx, box: Rect, margin: Float) : this(c.g.floor, box, margin)
    private val x0 = f.minOf { it.x }; private val y0 = f.minOf { it.y }
    private val x1 = f.maxOf { it.x }; private val y1 = f.maxOf { it.y }
    val k = min((box.width - 2 * margin) / (x1 - x0), (box.height - 2 * margin) / (y1 - y0)).toFloat()
    private val ox = box.left + (box.width - ((x1 - x0) * k).toFloat()) / 2; private val oy = box.top + (box.height - ((y1 - y0) * k).toFloat()) / 2
    fun at(q: V2) = Offset(ox + ((q.x - x0) * k).toFloat(), oy + ((q.y - y0) * k).toFloat())
    fun back(o: Offset) = V2((o.x - ox) / k + x0, (o.y - oy) / k + y0)
}

/**
 * The room from above: the floor, the walls, the doors with their swing, the windows, the water and gas, the routes in
 * their circuits' colours, the panel and every device ([sel] ringed, [bad] in red). [sym] the symbols' half size.
 */
fun DrawScope.drawElecPlan(c: ECtx, m: PlanMap, ds: List<ElecDev>, pn: ElecPanel?, runs: List<CRun>, circuitOf: (String) -> Circuit?, sym: Float,
                           sel: String? = null, bad: Set<String> = emptySet(), routes: Boolean = true) {
    val f = c.g.floor
    val out = Path().apply { val o = f.map { m.at(it) }; moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
    drawPath(out, E_FLOOR)
    drawPath(out, E_WALL, style = Stroke(max(2f, sym * .45f), join = androidx.compose.ui.graphics.StrokeJoin.Miter))
    // the routes over the walls' line: a run along a wall is drawn just inside it, each circuit a little further in
    if (routes) runs.forEachIndexed { k, r ->
        val col = rgbC(r.circuit.rgb)
        val inset = (sym * (.55f + .3f * (k % 5)) / m.k).toDouble()
        r.segs.forEach { g ->
            val n = c.wall(g.wall)?.nIn
            val a = m.at(if (n != null) g.a + n * inset else g.a); val b = m.at(if (n != null) g.b + n * inset else g.b)
            if ((a - b).getDistance() > .5f) drawLine(col, a, b, max(1.2f, sym * .22f), StrokeCap.Round)
        }
    }
    c.room.openings.forEach { o ->
        val w = c.wall(o.wall) ?: return@forEach
        val a = m.at(w.at(o.off.toDouble())); val b = m.at(w.at((o.off + o.w).toDouble()))
        if (o.type == "door") {
            drawLine(E_FLOOR, a, b, max(3f, sym * .6f))
            // the leaf open into the room, hinged at the door's near edge
            val tip = m.at(w.at(o.off.toDouble(), o.w.toDouble()))
            drawLine(E_DOOR, a, tip, max(1.2f, sym * .2f))
            val rad = (tip - a).getDistance()
            val st = Math.toDegrees(kotlin.math.atan2((b - a).y.toDouble(), (b - a).x.toDouble())).toFloat()
            val en = Math.toDegrees(kotlin.math.atan2((tip - a).y.toDouble(), (tip - a).x.toDouble())).toFloat()
            var sweep = en - st; while (sweep > 180) sweep -= 360f; while (sweep < -180) sweep += 360f
            drawArc(E_DOOR, st, sweep, false, Offset(a.x - rad, a.y - rad), Size(2 * rad, 2 * rad), style = Stroke(max(1f, sym * .12f), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))))
        } else drawLine(E_WIN, a, b, max(3f, sym * .55f))
    }
    c.room.points.filter { it.t in WATER || it.t in GAS }.forEach { x ->
        val w = c.wall(x.wall) ?: return@forEach
        drawCircle(if (x.t in WATER) E_WATER else E_GAS, sym * .45f, m.at(w.at(x.off.toDouble(), 60.0)))
    }
    if (pn != null && pn.roomId == c.id) c.wall(pn.wall)?.let { w ->
        devSymbol("panel", m.at(w.at(pn.off.toDouble(), 130.0)), sym * 1.1f, E_INK)
        if (sel == "panel") drawCircle(E_DOOR, sym * 1.9f, m.at(w.at(pn.off.toDouble(), 130.0)), style = Stroke(2f))
    }
    // wall devices close together along a wall step into the room one after another, so each symbol shows
    val placed = ArrayList<Pair<String, Double>>()
    ds.sortedBy { it.h }.forEach { d ->
        val col = circuitOf(d.id)?.let { rgbC(it.rgb) } ?: Color(0xFF94A3B8)
        val ink = if (d.id in bad) E_WARN else E_INK
        val at = if (d.onCeiling) m.at(V2(d.cx.toDouble(), d.cy.toDouble())) else c.wall(d.wall)?.let { w ->
            if (d.t == "led") { val (l, _) = devSize(d); drawLine(col, m.at(w.at(d.off - l / 2.0, 70.0)), m.at(w.at(d.off + l / 2.0, 70.0)), max(2f, sym * .4f)); null }
            else {
                val near = placed.count { (wid, off) -> wid == w.id && kotlin.math.abs(off - d.off) < 2.2 * sym / m.k }
                placed += w.id to d.off.toDouble()
                m.at(w.at(d.off.toDouble(), (sym * (1.6f + 1.9f * near) / m.k).toDouble()))
            }
        }
        if (at != null) {
            devSymbol(d.t, at, if (d.t == "ls") sym * .8f else sym, col, ink)
            if (d.id == sel) drawCircle(E_DOOR, sym * 1.7f, at, style = Stroke(2f))
        }
    }
}

/** A wall seen straight on, fitted into a box: along-the-wall mm and height mm → pixels. */
class WallMap(val len: Double, val H: Double, box: Rect, margin: Float, bottom: Float = margin) {
    val k = min((box.width - 2 * margin) / len, (box.height - margin - bottom) / H).toFloat()
    val x0 = box.left + (box.width - (len * k).toFloat()) / 2
    val yF = box.top + margin + (H * k).toFloat()
    fun x(a: Double) = x0 + (a * k).toFloat()
    fun y(h: Double) = yF - (h * k).toFloat()
    fun at(a: Double, h: Double) = Offset(x(a), y(h))
}

/**
 * Wall [w] of room [c] straight on: its doors and windows, water and gas, the cable run under the ceiling (dashed), the
 * routes on it, the panel and the devices, each with its height when [label] is given ([sel] ringed, [bad] in red).
 */
fun DrawScope.drawElecWall(c: ECtx, w: TWall, m: WallMap, ds: List<ElecDev>, pn: ElecPanel?, runs: List<CRun>, circuitOf: (String) -> Circuit?,
                           label: ((String) -> TextLayoutResult)?, sel: String? = null, bad: Set<String> = emptySet(), drag: Pair<String, Offset>? = null, minR: Float = 6f) {
    val H = c.g.H
    drawRect(Color(0xFFF7F9FC), Offset(m.x(0.0), m.y(H)), Size((w.len * m.k).toFloat(), (H * m.k).toFloat()))
    drawRect(E_WALL, Offset(m.x(0.0), m.y(H)), Size((w.len * m.k).toFloat(), (H * m.k).toFloat()), style = Stroke(2f))
    // the run under the ceiling
    val zy = m.y(H - ZONE_DOWN)
    drawLine(Color(0x553E4A61), Offset(m.x(0.0), zy), Offset(m.x(w.len), zy), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 5f)))
    c.room.openings.filter { it.wall == w.id }.forEach { o ->
        val tl = m.at(o.off.toDouble(), (o.sill + o.h).toDouble()); val sz = Size((o.w * m.k), (o.h * m.k))
        if (o.type == "door") {
            drawRect(Color.White, tl, sz); drawRect(E_DOOR, tl, sz, style = Stroke(1.5f))
            // the side it opens to: the hinge edge thick, and where the open door stands (no switch there)
            drawLine(E_DOOR, m.at(o.off.toDouble(), 0.0), m.at(o.off.toDouble(), o.h.toDouble()), 3f)
            val back = m.at(maxOf(0.0, o.off - o.w.toDouble()), o.h.toDouble())
            drawRect(Color(0x142E5BFF), back, Size(m.x(o.off.toDouble()) - back.x, (o.h * m.k)))
        } else { drawRect(Color(0xFFE5EEFB), tl, sz); drawRect(E_WIN, tl, sz, style = Stroke(1.5f)) }
    }
    c.room.points.filter { it.wall == w.id && (it.t in WATER || it.t in GAS) }.forEach { x ->
        drawCircle(if (x.t in WATER) E_WATER else E_GAS, max(3f, 40 * m.k), m.at(x.off.toDouble(), x.h.toDouble()))
    }
    runs.forEach { r ->
        val col = rgbC(r.circuit.rgb)
        r.segs.filter { it.wall == w.id }.forEach { g ->
            val a = (g.a - w.p0).dot(w.t); val b = (g.b - w.p0).dot(w.t)
            drawLine(col, m.at(a, g.za), m.at(b, g.zb), max(1.5f, 22 * m.k), StrokeCap.Round)
        }
    }
    val r0 = max(minR, 55 * m.k)
    if (pn != null && pn.roomId == c.id && pn.wall == w.id) {
        val (pw, ph) = panelSize(0)
        val at = drag?.takeIf { it.first == "panel" }?.second ?: m.at(pn.off.toDouble(), pn.h.toDouble())
        drawRect(Color(0xFFCBD5E1), Offset(at.x - pw / 2f * m.k, at.y - ph / 2f * m.k), Size(pw * m.k, ph * m.k))
        drawRect(E_INK, Offset(at.x - pw / 2f * m.k, at.y - ph / 2f * m.k), Size(pw * m.k, ph * m.k), style = Stroke(1.5f))
        devSymbol("panel", at, r0 * .8f, E_INK)
        if (sel == "panel") drawRect(E_DOOR, Offset(at.x - pw / 2f * m.k - 4, at.y - ph / 2f * m.k - 4), Size(pw * m.k + 8, ph * m.k + 8), style = Stroke(2f))
        if (label != null) { val t = label("${pn.h}"); drawText(t, topLeft = Offset(at.x + pw / 2f * m.k + 3, at.y - t.size.height / 2f)) }
    }
    // the heights: beside the device where neither another height nor a device's symbol is, else left out (as the plumber's)
    val onWall = ds.filter { it.wall == w.id && it.t != "led" }
    val symbols = onWall.map { d -> (drag?.takeIf { it.first == d.id }?.second ?: m.at(d.off.toDouble(), d.h.toDouble())).let { a ->
        androidx.compose.ui.geometry.Rect(a.x - r0, a.y - r0, a.x + r0, a.y + r0) } }
    val taken = ArrayList<androidx.compose.ui.geometry.Rect>()
    ds.filter { it.wall == w.id }.sortedBy { it.off }.forEach { d ->
        val col = circuitOf(d.id)?.let { rgbC(it.rgb) } ?: Color(0xFF94A3B8)
        val ink = if (d.id in bad) E_WARN else E_INK
        val at = drag?.takeIf { it.first == d.id }?.second ?: m.at(d.off.toDouble(), d.h.toDouble())
        if (d.t == "led") {
            val (l, _) = devSize(d)
            drawLine(col, Offset(at.x - l / 2f * m.k, at.y), Offset(at.x + l / 2f * m.k, at.y), max(3f, 30 * m.k))
            if (d.id == sel) drawRect(E_DOOR, Offset(at.x - l / 2f * m.k - 4, at.y - 8), Size(l * m.k + 8, 16f), style = Stroke(2f))
            return@forEach
        }
        // its height: a thin line down to the floor and the number
        if (label != null) {
            drawLine(Color(0x553E4A61), Offset(at.x, at.y + r0), Offset(at.x, m.y(0.0)), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f)))
            val hh = drag?.takeIf { it.first == d.id }?.let { ((m.yF - it.second.y) / m.k).toInt() } ?: d.h
            val t = label("$hh")
            val tw = t.size.width.toFloat(); val th = t.size.height.toFloat()
            val own = androidx.compose.ui.geometry.Rect(at.x - r0, at.y - r0, at.x + r0, at.y + r0)
            val spot = listOf(at.x + r0 * .9f to at.y + r0 * .3f, at.x - r0 * .9f - tw to at.y + r0 * .3f, at.x + r0 * .9f to at.y - r0 * .3f - th, at.x - r0 * .9f - tw to at.y - r0 * .3f - th)
                .map { (x, y) -> androidx.compose.ui.geometry.Rect(x, y, x + tw, y + th) }
                .firstOrNull { r -> taken.none { it.overlaps(r) } && symbols.none { it != own && it.overlaps(r) } }
            if (spot != null) { taken += spot; drawText(t, topLeft = spot.topLeft) }
        }
        devSymbol(d.t, at, r0, col, ink)
        if (d.id == sel) drawCircle(E_DOOR, r0 * 1.7f, at, style = Stroke(2f))
    }
    // the floor line
    drawLine(E_WALL, Offset(m.x(0.0) - 6, m.y(0.0)), Offset(m.x(w.len) + 6, m.y(0.0)), 3f)
}

/** The types shown, in the legend's order. */
fun legendTypes(ds: List<ElecDev>): List<String> = uz.metrx.app.elec.DEV_TYPES.map { it.id }.filter { t -> ds.any { it.t == t } }

/** Whether type [t] goes on the ceiling. */
fun ceilType(t: String) = devType(t).ceil
