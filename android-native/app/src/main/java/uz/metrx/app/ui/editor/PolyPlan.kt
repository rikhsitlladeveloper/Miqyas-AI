package uz.metrx.app.ui.editor

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import uz.metrx.app.ui.furniture.drawSitePoint
import uz.metrx.app.data.Diag
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.PolyGeo
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.polyGeo
import uz.metrx.app.geo.selfIntersects
import uz.metrx.app.geo.shoelace
import uz.metrx.app.geo.snapAngle
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/* The plan of a drawn room (prototype skPlanSVG), its Shape and Diagonal modes (skDragTo, skDiagMode). */

private fun off(p: Pt) = Offset(p.x.toFloat(), p.y.toFloat())
private fun norm(o: Offset): Offset { val l = hypot(o.x, o.y); return if (l < 1e-6f) Offset(0f, 0f) else o / l }

/** Layout of the polygon in a 360-wide viewBox: inner outline, outer offset by the wall thickness, outward normals. */
internal class PolyLayout(verts: List<Pt>, T: Int) {
    val VW = 360f; val M = 74f; val MY = 56f
    val minX = verts.minOf { it.x }.toFloat(); val maxX = verts.maxOf { it.x }.toFloat()
    val minY = verts.minOf { it.y }.toFloat(); val maxY = verts.maxOf { it.y }.toFloat()
    val bw = max(1f, maxX - minX); val bh = max(1f, maxY - minY)
    val s = min((VW - 2 * M) / (bw + 2 * T), 240f / (bh + 2 * T))
    val tw = max(3f, T * s)
    val ox = (VW - bw * s) / 2f - minX * s
    val oy = MY + tw - minY * s
    val VH = bh * s + 2 * tw + 2 * MY
    fun p(v: Pt) = Offset(ox + v.x.toFloat() * s, oy + v.y.toFloat() * s)
    fun mm(o: Offset) = Pt(((o.x - ox) / s).toDouble(), ((o.y - oy) / s).toDouble())
    val inner = verts.map { p(it) }
    val n = inner.size
    /** Outward normal of wall i (clockwise outline, y down). */
    val normals = (0 until n).map { i -> val a = inner[i]; val b = inner[(i + 1) % n]; norm(Offset(b.y - a.y, -(b.x - a.x))) }
    val outer = (0 until n).map { i ->
        val n1 = normals[(i - 1 + n) % n]; val n2 = normals[i]
        val dot = n1.x * n2.x + n1.y * n2.y
        if (1 + dot < .15f) inner[i] + n2 * tw else inner[i] + (n1 + n2) * (tw / (1 + dot))
    }
}

@Composable
fun PolyPlan(r: Room, sel: String?, selOp: String?, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val ops = app.ops
    val lang = LocalLang.current
    // the room's own snap (kept when it was drawn), also for dragging its corners
    val snap = r.poly?.snap ?: app.settings.angleSnap
    val unit = app.settings.unit; val en = app.english()
    val tm = rememberTextMeasurer()
    val m2 = uz.metrx.app.ui.theme.tr("u.m2")
    val g = polyGeo(r, snap)
    val mode = if (ops.polyRoom == r.id) ops.polyMode else "plan"
    var live by remember { mutableStateOf<List<Pt>?>(null) }         // corners while one is dragged
    var guides by remember { mutableStateOf<Pair<List<Float>, List<Float>>>(emptyList<Float>() to emptyList()) }
    val pid = app.store.projects.firstOrNull { pr -> pr.rooms.any { it.id == r.id } }?.id ?: return
    val shapeVerts = live ?: r.poly!!.verts
    val drawVerts = if (mode == "shape") shapeVerts else g.verts
    val lay = PolyLayout(drawVerts, r.dim("T").v ?: 200)
    Box(modifier) {
        Canvas(Modifier.fillMaxSize().padding(top = 56.dp, bottom = 60.dp).pointerInput(r, mode, snap) {
            awaitEachGesture {
                val down = awaitFirstDown()
                val k = min(size.width / lay.VW, size.height / lay.VH)
                val dx = (size.width - lay.VW * k) / 2f; val dy = (size.height - lay.VH * k) / 2f
                fun vb(p: Offset) = Offset((p.x - dx) / k, (p.y - dy) / k)
                val sp = vb(down.position)
                if (mode == "shape") {
                    val ci = lay.inner.indices.minByOrNull { hypot(lay.inner[it].x - sp.x, lay.inner[it].y - sp.y) }
                    if (ci == null || hypot(lay.inner[ci].x - sp.x, lay.inner[ci].y - sp.y) > 22f) return@awaitEachGesture
                    val orig = r.poly!!.verts
                    val frozen = PolyLayout(orig, r.dim("T").v ?: 200)       // the view stays still while dragging
                    var moved = false; var cur = orig
                    while (true) {
                        val ev = awaitPointerEvent()
                        val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                        if (!ch.pressed) break
                        ch.consume()
                        val q = frozen.mm(vb(ch.position))
                        val (np, gd) = dragCorner(orig, ci, q, snap, 10f / frozen.s)
                        if (!moved && hypot(np.x - orig[ci].x, np.y - orig[ci].y) < 10) continue
                        moved = true
                        cur = orig.toMutableList().apply { this[ci] = np }
                        live = cur; guides = gd
                    }
                    live = null; guides = emptyList<Float>() to emptyList()
                    if (moved) {
                        if (selfIntersects(cur) != null || shoelace(cur) <= 0) app.say("sk.crossDrag", kind = ToastKind.ERROR)
                        else ops.change(pid, r.id) { it.copy(poly = it.poly!!.copy(verts = cur)) }
                    }
                    return@awaitEachGesture
                }
                // a tap (no drag in the polygon plan, as in the prototype)
                var up = true
                while (true) {
                    val ev = awaitPointerEvent()
                    val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                    if (!ch.pressed) break
                    if (hypot(ch.position.x - down.position.x, ch.position.y - down.position.y) > 10.dp.toPx()) up = false
                }
                if (!up) return@awaitEachGesture
                if (mode == "diag") { diagTap(app, pid, r, lay, sp); return@awaitEachGesture }
                polyHit(r, g, lay, sp)?.let { h ->
                    when (h) {
                        is PlanHit.Op -> app.sheet = Sheet.OpeningForm(pid, r.id, h.id)
                        is PlanHit.Dim -> ops.select(pid, r.id, h.wall)
                    }
                }
            }
        }) {
            val k = min(size.width / lay.VW, size.height / lay.VH)
            val dx = (size.width - lay.VW * k) / 2f; val dy = (size.height - lay.VH * k) / 2f
            withTransform({ translate(dx, dy); scale(k, k, pivot = Offset.Zero) }) {
                drawPoly(lay, r, g, mode, sel, selOp, unit, en, dn(r.name, lang), tm, ops.diagFirst, snap = snap, m2 = m2)
                if (mode == "shape") {
                    guides.first.forEach { x -> val gx = lay.ox + x * lay.s; drawLine(COB.copy(alpha = .75f), Offset(gx, 0f), Offset(gx, lay.VH), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))) }
                    guides.second.forEach { y -> val gy = lay.oy + y * lay.s; drawLine(COB.copy(alpha = .75f), Offset(0f, gy), Offset(lay.VW, gy), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))) }
                    lay.inner.forEach { c -> drawCircle(PLAN_W, 7.5f, c); drawCircle(COB, 7.5f, c, style = Stroke(2f)) }
                }
            }
        }
        // Shape / Diagonal buttons, or the mode's hint with Done / Cancel
        Row(Modifier.align(Alignment.TopStart).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            when (mode) {
                "plan" -> {
                    ModePill("pen", tr("ed2.shape")) { ops.polyRoom = r.id; ops.polyMode = "shape"; ops.diagFirst = null; app.sheet = null }
                    ModePill("dim", tr("ed2.diag")) { ops.polyRoom = r.id; ops.polyMode = "diag"; ops.diagFirst = null; app.sheet = null }
                }
                else -> {
                    val hint = if (mode == "shape") tr("sk.editHint") else tr(if (ops.diagFirst == null) "sk.pick1" else "sk.pick2")
                    Row(Modifier.weight(1f, fill = false).clip(RoundedCornerShape(16.dp)).background(G.sheet(.85f)).border(1.dp, G.rim, RoundedCornerShape(16.dp)).padding(horizontal = 12.dp, vertical = 8.dp)) {
                        Text(hint, style = ui(13f, 500, G.ink2, 1.3f))
                    }
                    ModePill(if (mode == "shape") "check" else "x", tr(if (mode == "shape") "common.done" else "common.cancel")) { ops.polyMode = "plan"; ops.diagFirst = null }
                }
            }
        }
    }
}

@Composable
private fun ModePill(icon: String, label: String, onClick: () -> Unit) {
    val haze = LocalHaze.current
    Row(Modifier.heightIn(min = 40.dp).clip(CircleShape).glassBlur(haze, G.sheet(.6f), 22.dp).border(1.dp, G.rim, CircleShape)
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        MIcon(icon, G.cobalt, 16.dp, 2.2f); Text(label, style = ui(13.5f, 700))
    }
}

/**
 * Where a dragged corner goes (prototype skDragTo): the walls from the neighbours snap to 45° within 8°,
 * else the corner lines up with another corner within 10 px; 10 mm steps. Returns the guides through aligned corners.
 */
private fun dragCorner(v: List<Pt>, i: Int, q: Pt, snap: Boolean, tolMm: Float): Pair<Pt, Pair<List<Float>, List<Float>>> {
    val n = v.size; val prev = v[(i - 1 + n) % n]; val next = v[(i + 1) % n]
    var p = q
    var snapped = false
    if (snap) {
        fun ray(o: Pt): Pair<Double, Boolean> { val a = atan2(q.y - o.y, q.x - o.x); val sa = snapAngle(a); return sa to (abs(a - sa) < .14) }
        val (a1, s1) = ray(prev); val (a2, s2) = ray(next)
        if (s1 && s2) {
            val d1x = cos(a1); val d1y = sin(a1); val d2x = cos(a2); val d2y = sin(a2)
            val det = d1x * (-d2y) - d1y * (-d2x)
            if (abs(det) > 1e-6) {
                val t = ((next.x - prev.x) * (-d2y) - (next.y - prev.y) * (-d2x)) / det
                val sd = ((d1x * (next.y - prev.y) - d1y * (next.x - prev.x)) / det)
                if (t > 0 && sd > 0) { p = Pt(prev.x + t * d1x, prev.y + t * d1y); snapped = true }
            }
        }
        if (!snapped && (s1 || s2)) {
            val (o, a) = if (s1) prev to a1 else next to a2
            val ux = cos(a); val uy = sin(a); val t = (q.x - o.x) * ux + (q.y - o.y) * uy
            p = Pt(o.x + t * ux, o.y + t * uy); snapped = true
        }
    }
    if (!snapped) {
        val others = v.filterIndexed { k, _ -> k != i }
        others.minByOrNull { abs(it.x - q.x) }?.let { if (abs(it.x - q.x) < tolMm) p = p.copy(x = it.x) }
        others.minByOrNull { abs(it.y - q.y) }?.let { if (abs(it.y - q.y) < tolMm) p = p.copy(y = it.y) }
    }
    p = Pt((p.x / 10).roundToInt() * 10.0, (p.y / 10).roundToInt() * 10.0)
    val others = v.filterIndexed { k, _ -> k != i }
    return p to (others.filter { abs(it.x - p.x) <= 1 }.map { it.x.toFloat() } to others.filter { abs(it.y - p.y) <= 1 }.map { it.y.toFloat() })
}

private fun polyHit(r: Room, g: PolyGeo, lay: PolyLayout, p: Offset): PlanHit? {
    for (o in r.openings) {
        val i = g.walls.indexOfFirst { it.id == o.wall }; if (i < 0) continue
        val a = lay.inner[i]; val b = lay.inner[(i + 1) % lay.n]
        val u = norm(b - a); val drawn = hypot(b.x - a.x, b.y - a.y); val real = g.walls[i].len ?: (drawn / lay.s).toInt()
        val kk = drawn / max(1, real)
        val rel = p - a; val along = rel.x * u.x + rel.y * u.y; val out = rel.x * lay.normals[i].x + rel.y * lay.normals[i].y
        if (along in (o.off - 150) * kk..(o.off + o.w + 150) * kk && out in -30f..lay.tw + 6f) return PlanHit.Op(o.id)
    }
    // a diagonal's pill opens its card again
    r.poly!!.diags.forEach { d ->
        val c = (lay.inner[d.a] + lay.inner[d.b]) / 2f
        if (abs(p.x - c.x) < 36 && abs(p.y - c.y) < 16) return PlanHit.Dim(d.id)
    }
    for (i in 0 until lay.n) {
        val a = lay.inner[i]; val b = lay.inner[(i + 1) % lay.n]
        val c = (a + b) / 2f + lay.normals[i] * (lay.tw + 30f)
        if (abs(p.x - c.x) < 40 && abs(p.y - c.y) < 18) return PlanHit.Dim(g.walls[i].id)
    }
    for (i in 0 until lay.n) {
        val a = lay.inner[i]; val b = lay.inner[(i + 1) % lay.n]
        val u = norm(b - a); val len = hypot(b.x - a.x, b.y - a.y)
        val rel = p - a; val along = rel.x * u.x + rel.y * u.y; val out = rel.x * lay.normals[i].x + rel.y * lay.normals[i].y
        if (along in -12f..len + 12f && out in -12f..lay.tw + 12f) return PlanHit.Dim(g.walls[i].id)
    }
    return null
}

/** Diagonal mode: tap two corners that are not neighbours; tap a diagonal's pill to remove it. */
private fun diagTap(app: uz.metrx.app.ui.App, pid: String, r: Room, lay: PolyLayout, p: Offset) {
    val ops = app.ops
    r.poly!!.diags.forEach { d ->
        val c = (lay.inner[d.a] + lay.inner[d.b]) / 2f
        if (abs(p.x - c.x) < 36 && abs(p.y - c.y) < 16) {
            ops.change(pid, r.id) { it.copy(poly = it.poly!!.copy(diags = it.poly.diags.filter { x -> x.id != d.id }), dims = it.dims - d.id) }
            app.say("sk.diagDel", "d" to d.id, action = "common.undo") { ops.undo(pid, r.id) }
            return
        }
    }
    val ci = lay.inner.indices.minByOrNull { hypot(lay.inner[it].x - p.x, lay.inner[it].y - p.y) } ?: return
    if (hypot(lay.inner[ci].x - p.x, lay.inner[ci].y - p.y) > 22f) return
    val first = ops.diagFirst
    if (first == null) { ops.diagFirst = ci; return }
    if (first == ci) { ops.diagFirst = null; return }
    val n = lay.n
    if (abs(first - ci) == 1 || abs(first - ci) == n - 1) { app.say("sk.diagAdj", kind = ToastKind.INFO); return }
    val a = min(first, ci); val b = max(first, ci)
    if (r.poly.diags.any { it.a == a && it.b == b }) { app.say("sk.diagDup", kind = ToastKind.INFO); ops.polyMode = "plan"; ops.diagFirst = null; return }
    var k = 1; while (r.poly.diags.any { it.id == "X$k" }) k++
    val id = "X$k"
    ops.change(pid, r.id) { it.copy(poly = it.poly!!.copy(diags = it.poly.diags + Diag(id, a, b)), dims = it.dims + (id to Dim())) }
    ops.polyMode = "plan"; ops.diagFirst = null
    app.say("sk.diagAdded", "d" to id, "a" to a + 1, "b" to b + 1)
    ops.focus(r.id, id)
}

/** A drawn room's plan for the report; returns its height in the 360-wide units. */
internal fun DrawScope.drawReportPoly(r: Room, unit: LenUnit, en: Boolean, label: String, tm: TextMeasurer, snap: Boolean, labelMode: String = "both", m2: String = "m²"): Float {
    val g = polyGeo(r, snap); val lay = PolyLayout(g.verts, r.dim("T").v ?: 200)
    Theme.onPaper { drawPoly(lay, r, g, "plan", null, null, unit, en, label, tm, null, report = true, snap = snap, m2 = m2, labelMode = labelMode) }
    return lay.VH
}

internal fun reportPolyHeight(r: Room, snap: Boolean): Float { val g = polyGeo(r, snap); return PolyLayout(g.verts, r.dim("T").v ?: 200).VH }

private fun DrawScope.drawPoly(lay: PolyLayout, r: Room, g: PolyGeo, mode: String, sel: String?, selOp: String?, unit: LenUnit, en: Boolean, label: String, tm: TextMeasurer, diagFirst: Int?, report: Boolean = false, snap: Boolean = true, m2: String = "m²", labelMode: String = PlanLabel.mode) {
    val n = lay.n
    val inner = Path().apply { moveTo(lay.inner[0].x, lay.inner[0].y); lay.inner.drop(1).forEach { lineTo(it.x, it.y) }; close() }
    val outer = Path().apply { moveTo(lay.outer[0].x, lay.outer[0].y); lay.outer.drop(1).forEach { lineTo(it.x, it.y) }; close() }
    val ring = Path().apply { addPath(outer); addPath(inner); fillType = PathFillType.EvenOdd }
    val solved = g.solved || mode == "shape"
    if (mode == "shape") drawPath(inner, COB_WASH)
    // the selected wall: a pale band
    if (mode == "plan") g.walls.indexOfFirst { it.id == sel }.takeIf { it >= 0 }?.let { i ->
        val band = Path().apply { val a = lay.inner[i]; val b = lay.inner[(i + 1) % n]; val c = lay.outer[(i + 1) % n]; val d = lay.outer[i]; moveTo(a.x, a.y); lineTo(b.x, b.y); lineTo(c.x, c.y); lineTo(d.x, d.y); close() }
        drawPath(band, SEL_BAND); drawPath(band, COB, style = Stroke(6f))
    }
    if (solved) {
        drawPath(ring, PLAN_W)
        clipPath(ring) {
            val b = Rect(0f, 0f, lay.VW, lay.VH); var x = -b.height
            while (x < b.width + b.height) { drawLine(INK, Offset(x, b.bottom), Offset(x + b.height, b.top), 1.1f); x += 5.66f }
        }
        drawPath(outer, INK, style = Stroke(1.2f)); drawPath(inner, INK, style = Stroke(1.2f))
    } else {
        drawPath(inner, GREY_LINE, style = Stroke(1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))))
    }
    if (mode == "plan") g.walls.indexOfFirst { it.id == sel }.takeIf { it >= 0 }?.let { i ->
        val wall = Path().apply { val a = lay.inner[i]; val b = lay.inner[(i + 1) % n]; val c = lay.outer[(i + 1) % n]; val d = lay.outer[i]; moveTo(a.x, a.y); lineTo(b.x, b.y); lineTo(c.x, c.y); lineTo(d.x, d.y); close() }
        drawPath(wall, COB)
    }
    // doors and windows along their wall, placed in proportion
    if (mode == "plan") r.openings.forEach { o ->
        val i = g.walls.indexOfFirst { it.id == o.wall }; if (i < 0) return@forEach
        val a = lay.inner[i]; val b = lay.inner[(i + 1) % n]; val u = norm(b - a); val nn = lay.normals[i]
        val drawn = hypot(b.x - a.x, b.y - a.y); val real = g.walls[i].len ?: max(1, (drawn / lay.s).toInt()); val kk = drawn / max(1, real)
        val p0 = a + u * (o.off * kk); val p1 = a + u * ((o.off + o.w) * kk)
        val c = if (o.id == selOp) COB else INK
        val quad = Path().apply { moveTo(p0.x, p0.y); lineTo(p1.x, p1.y); val q1 = p1 + nn * lay.tw; val q0 = p0 + nn * lay.tw; lineTo(q1.x, q1.y); lineTo(q0.x, q0.y); close() }
        if (o.type == "door") {
            drawPath(quad, PAPER)
            val tip = p0 - nn * (o.w * kk)
            drawLine(c, p0, tip, 2.2f, StrokeCap.Round)
            drawLine(c, p0, p0 + nn * lay.tw, 1.2f); drawLine(c, p1, p1 + nn * lay.tw, 1.2f)
        } else {
            drawPath(quad, PLAN_W); drawPath(quad, c, style = Stroke(1.2f))
            drawLine(c, p0 + nn * (lay.tw / 3), p1 + nn * (lay.tw / 3), 1f); drawLine(c, p0 + nn * (2 * lay.tw / 3), p1 + nn * (2 * lay.tw / 3), 1f)
        }
    }
    // furniture orders: sockets, switches and pipes, just inside their wall
    if (mode == "plan") r.points.forEach { x ->
        val i = g.walls.indexOfFirst { it.id == x.wall }; if (i < 0) return@forEach
        val a = lay.inner[i]; val b = lay.inner[(i + 1) % n]; val u = norm(b - a)
        val drawn = hypot(b.x - a.x, b.y - a.y); val real = g.walls[i].len ?: max(1, (drawn / lay.s).toInt()); val kk = drawn / max(1, real)
        drawSitePoint(x, a + u * (x.off * kk) - lay.normals[i] * 7f, 0f, 6.5f, 1f)
    }
    // name and floor area in the middle
    val a = areas(r, snap)
    val cx = lay.inner.map { it.x }.average().toFloat(); val cy = lay.inner.map { it.y }.average().toFloat()
    centreLabel(tm, label, (if (a != null) fmtArea(a.floor, en) else "?") + " " + m2, Offset(cx, cy), labelMode)
    // wall letters and corner numbers
    for (i in 0 until n) {
        val wa = lay.inner[i]; val wb = lay.inner[(i + 1) % n]
        val mid = (wa + wb) / 2f - lay.normals[i] * 17f
        val on = mode == "plan" && g.walls[i].id == sel
        drawCircle(if (on) COB else PLAN_W, 9f, mid); drawCircle(if (on) COB else INK3, 9f, mid, style = Stroke(1f))
        text(tm, g.walls[i].id, mid, TextStyle(fontFamily = Jakarta, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (on) ON_FILL else INK))
        val bis = norm(lay.normals[(i - 1 + n) % n] + lay.normals[i])
        val cp = lay.inner[i] - bis * 12f
        val dg = mode == "diag"
        if (dg) { drawCircle(if (diagFirst == i) COB else PLAN_W, 11f, cp); drawCircle(COB, 11f, cp, style = Stroke(1.5f)) }
        text(tm, "${i + 1}", cp, TextStyle(fontFamily = Jakarta, fontSize = if (dg) 11.sp else 9.5.sp, fontWeight = if (dg) FontWeight.Bold else FontWeight.Normal, color = if (dg && diagFirst == i) ON_FILL else INK3))
    }
    // a dimension per wall, parallel to it, with a status pill; a pill that would cover another moves further out
    val placed = ArrayList<Rect>()
    if (mode != "shape") for (i in 0 until n) {
        val w = g.walls[i]; val wa = lay.inner[i]; val wb = lay.inner[(i + 1) % n]; val nn = lay.normals[i]
        val conf = w.status == "conf"
        val d = r.dim(w.id)
        val (txt, st) = when (w.status) {
            "conf" -> fmtLen(d.v, unit, en) to "conf"
            "recv" -> fmtLen(d.pending!!.mm, unit, en, true) to "recv"
            "calc" -> "=" + fmtLen(w.len, unit, en) to "calc"
            "bad" -> "[" + fmtLen(d.v, unit, en) + "]" to "bad"
            "unres" -> "[?]" to "unres"
            else -> "?" to "unset"
        }
        val pw = pillW(txt, st != "unset" && st != "calc")
        var o = lay.tw + 30f
        var c = (wa + wb) / 2f + nn * o
        var box = Rect(c.x - pw / 2 - 4, c.y - 17f, c.x + pw / 2 + 4, c.y + 17f)
        var tries = 0
        while (tries < 3 && placed.any { it.overlaps(box) }) { o += 30f; c = (wa + wb) / 2f + nn * o; box = Rect(c.x - pw / 2 - 4, c.y - 17f, c.x + pw / 2 + 4, c.y + 17f); tries++ }
        placed += box
        val lc = when (w.status) { "conf" -> INK; "recv" -> AMBER; "bad" -> RED; "calc" -> COB; else -> GREY_LINE }
        drawLine(lc, wa + nn * o, wb + nn * o, 1.1f, pathEffect = if (conf) null else PathEffect.dashPathEffect(floatArrayOf(5f, 4f)))
        drawLine(lc.copy(alpha = .5f), wa + nn * (lay.tw + 3f), wa + nn * (o + 4f), .8f); drawLine(lc.copy(alpha = .5f), wb + nn * (lay.tw + 3f), wb + nn * (o + 4f), .8f)
        pill(tm, txt, c, st, report)
    }
    // diagonals: a dotted line with its pill
    if (mode != "shape") r.poly!!.diags.forEach { dg ->
        val pa = lay.inner[dg.a]; val pb = lay.inner[dg.b]
        drawLine(INK3, pa, pb, 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 4f)))
        val d = r.dim(dg.id)
        val st = g.diagStatus[dg.id] ?: "unset"
        val txt = when (st) { "recv" -> fmtLen(d.pending!!.mm, unit, en, true); "unset" -> "?"; "warn" -> "[" + fmtLen(d.v, unit, en) + "]"; else -> fmtLen(d.v, unit, en) }
        pill(tm, txt, (pa + pb) / 2f, when (st) { "ok", "conf" -> "conf"; "warn" -> "unres"; else -> st }, report)
    }
}

/** A glass pill with the value and its status mark (prototype skPill restyled by glass). */
private fun DrawScope.pill(tm: TextMeasurer, t: String, c: Offset, st: String, report: Boolean = false) {
    val icon = st != "unset" && st != "calc"
    val pw = pillW(t, icon)
    val rect = Rect(c.x - pw / 2, c.y - 13f, c.x + pw / 2, c.y + 13f)
    if (report && st == "conf") {
        drawRoundRect(Color.White, rect.topLeft, rect.size, CornerRadius(3f))
        text(tm, t, Offset(c.x - 7f, c.y), TextStyle(fontFamily = PlexCond, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = INK))
        val x = rect.right - 14f; drawPath(Path().apply { moveTo(x, c.y); relativeLineTo(3f, 3f); relativeLineTo(5.5f, -5.5f) }, INK, style = Stroke(1.8f, cap = StrokeCap.Round))
        return
    }
    val (fill, edge) = when (st) {
        "calc" -> pc(0xFFE7EEFD, 0xFF1C2546) to COB
        "bad" -> pc(0xFFFDEDEB, 0xFF3A1B1B) to RED
        "unres" -> pc(0xFFFFF1DF, 0xFF33260F) to AMBER
        else -> pillFill(.85f) to pillEdge(1f)
    }
    drawRoundRect(fill, rect.topLeft, rect.size, CornerRadius(13f))
    drawRoundRect(edge, rect.topLeft, rect.size, CornerRadius(13f), style = Stroke(if (st == "bad") 1.8f else 1.2f, pathEffect = if (st == "calc" || st == "unset") PathEffect.dashPathEffect(floatArrayOf(3f, 2f)) else null))
    val tc = when (st) { "calc" -> COB; "bad" -> RED; "unres" -> AMBER; else -> PILL_INK }
    val tx = when (st) { "conf" -> c.x - 7f; "recv", "bad", "unres" -> c.x + 7f; else -> c.x }
    text(tm, t, Offset(tx, c.y), TextStyle(fontFamily = Jakarta, fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = tc, fontStyle = if (st == "calc") FontStyle.Italic else FontStyle.Normal))
    when (st) {
        "conf" -> { val x = rect.right - 14f; drawPath(Path().apply { moveTo(x, c.y); relativeLineTo(3f, 3f); relativeLineTo(5.5f, -5.5f) }, OK_GREEN, style = Stroke(2.4f, cap = StrokeCap.Round)) }
        "recv" -> { val cc = Offset(rect.left + 12f, c.y); drawCircle(AMBER, 5f, cc, style = Stroke(1.6f)); drawLine(AMBER, cc, cc + Offset(0f, -3f), 1.6f); drawLine(AMBER, cc, cc + Offset(2.2f, 1.2f), 1.6f) }
        "bad", "unres" -> { val cc = Offset(rect.left + 12f, c.y); drawCircle(tc, 5.5f, cc, style = Stroke(1.6f)); drawLine(tc, cc + Offset(0f, -2.5f), cc + Offset(0f, .8f), 1.6f); drawCircle(tc, .9f, cc + Offset(0f, 2.6f)) }
    }
}

/** The polygon hint above the step card (prototype skHint): a conflict, a check that disagrees, or what to measure next. */
@Composable
fun PolyHint(pid: String, r: Room) {
    val app = LocalApp.current
    val g = polyGeo(r, app.settings.angleSnap)
    val unit = app.settings.unit; val en = app.english()
    val (text, red, wall) = when {
        g.err == "negative" -> Triple(tr("sk.negative", "w" to g.conflict.joinToString(", ")), true, g.conflict.firstOrNull())
        g.err == "cross" -> Triple(tr("sk.crossSol"), true, g.conflict.firstOrNull())
        g.err == "closure" -> Triple(tr("sk.conflict", "w" to g.conflict.joinToString(", "), "e" to fmtLen(g.gap, LenUnit.M, en)), true, g.conflict.firstOrNull())
        g.diagStatus.entries.firstOrNull { it.value == "warn" } != null -> {
            val e = g.diagStatus.entries.first { it.value == "warn" }
            Triple(tr("sk.diagWarn", "d" to e.key, "e" to fmtLen(abs((r.dim(e.key).v ?: 0) - (g.diagLen[e.key] ?: 0)), LenUnit.M, en)), false, null)
        }
        g.either.size == 2 -> Triple(tr("sk.needEither", "a" to g.either[0], "b" to g.either[1]), false, null)
        else -> return
    }
    Row(Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(RoundedCornerShape(14.dp)).background(if (red) G.errWash else G.amberWash).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        MIcon("alert", if (red) G.err else AMBER, 18.dp, 2f)
        Text(text, style = ui(13.5f, 500, if (red) G.err else AMBER, 1.35f), modifier = Modifier.weight(1f))
        if (wall != null) Text(tr("ms.remeasure"), style = ui(14f, 700, G.cobalt), modifier = Modifier.clickable(role = Role.Button) { app.ops.remeasure(pid, r.id, wall) }.padding(6.dp))
    }
}

