package uz.metrx.app.ui.projects

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.polyGeo
import uz.metrx.app.geo.ready3D
import uz.metrx.app.geo.shoelace
import uz.metrx.app.geo.v3Fit
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.editor.ShotPill
import uz.metrx.app.ui.glass.drawAurora
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.Manrope
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.three.Cam3D
import uz.metrx.app.ui.three.Labels3D
import uz.metrx.app.ui.three.Lbl3D
import uz.metrx.app.ui.three.RoomLbl3D
import uz.metrx.app.ui.three.Scene3D
import uz.metrx.app.ui.three.go
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * The Workspaces tab seen as plans side by side (prototype roomsTab view '2d') or in 3D (view '3d', one workspace at a time,
 * ux module's rows of rooms and zoom-to-room names).
 */

/** List | 2D | 3D (prototype .seg.wide). */
@Composable
fun ViewSeg(cur: String, onPick: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        listOf("list" to tr("view.list"), "2d" to "2D", "3d" to "3D").forEach { (k, l) ->
            val on = k == cur
            val shape = RoundedCornerShape(9.dp)
            Box(
                Modifier.weight(1f).let { if (on) it.dropShadow(shape, Shadow(3.dp, Color(0x24101828), offset = DpOffset(0.dp, 1.dp))) else it }
                    .height(44.dp).clip(shape).background(if (on) G.glass(.55f) else Color.Transparent)
                    .clickable(role = Role.Tab) { onPick(k) }.padding(horizontal = 6.dp),
                contentAlignment = Alignment.Center
            ) { Text(l, style = ui(14f, if (on) 600 else 500, if (on) G.ink else G.ink2), maxLines = 1) }
        }
    }
}

/** A small info line (prototype .note). */
@Composable
fun NoteLine(text: String, modifier: Modifier = Modifier) {
    Row(modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MIcon("info", G.ink2, 18.dp, 2f)
        Text(text, style = ui(13f, 400, G.ink2, 1.4f), modifier = Modifier.weight(1f))
    }
}

/** Every workspace with its rooms' plans at one scale (prototype view2d). */
@Composable
fun Plans2D(p: Project, lang: Lang) {
    val app = LocalApp.current
    // a furniture order in the furniture maker’s own unit (mm by default), as its rooms are measured
    val unit = if (p.isFurniture) app.settings.furnUnit else app.settings.unit; val en = lang == Lang.EN; val snap = app.settings.angleSnap
    val maxDim = p.rooms.maxOfOrNull { max(it.dim("A").v ?: 4000, it.dim("B").v ?: 3000) } ?: 4000
    val sc = 120f / maxDim
    Column {
        p.floors.forEach { f ->
            val rs = p.rooms.filter { it.floorId == f.id }
            val sum = rs.sumOf { areas(it, snap)?.floor ?: 0L }
            Row(Modifier.fillMaxWidth().padding(top = 14.dp, bottom = 6.dp), verticalAlignment = Alignment.Bottom) {
                Text(floorName(f, lang), style = ui(15f, 700), modifier = Modifier.weight(1f))
                Text(tr("pr.floorSum", "n" to rs.size, "a" to fmtArea(sum, en)), style = ui(13f, 400, G.ink2))
            }
            if (rs.isEmpty()) Text(tr("pr.emptyFloor"), style = ui(13.5f, 400, G.ink2), modifier = Modifier.padding(vertical = 4.dp))
            else BoxWithConstraints(Modifier.fillMaxWidth()) {
                val cols = max(1, ((maxWidth.value + 10) / 150).toInt()); val cw = (maxWidth - 10.dp * (cols - 1)) / cols
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    rs.chunked(cols).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
                            row.forEach { r ->
                                val shape = RoundedCornerShape(14.dp)
                                Box(
                                    Modifier.width(cw).dropShadow(shape, Shadow(28.dp, G.shade.copy(alpha = .12f), offset = DpOffset(0.dp, 12.dp)))
                                        .clip(shape).background(Color.White).topHighlight(.95f, 1.5.dp).border(1.dp, Color.White.copy(alpha = .8f), shape)
                                        .clickable(role = Role.Button) { app.push(Route.Editor(p.id, r.id)) }.padding(6.dp),
                                    contentAlignment = Alignment.Center
                                ) { MiniPlan(r, sc, dn(r.name, lang), unit, en, snap, cw - 12.dp) }
                            }
                        }
                    }
                }
            }
        }
        NoteLine(tr("v2d.note"))
    }
}

/**
 * A room's plan at a common scale [s] (px per mm, prototype miniPlan and its sketch override): the walls as a solid ring,
 * doors and windows as gaps with the door's swing, the two side lengths, the name and the floor area. Shrinks to [maxW].
 */
@Composable
fun MiniPlan(r: Room, s0: Float, name: String, unit: LenUnit, en: Boolean, snap: Boolean, maxW: androidx.compose.ui.unit.Dp) {
    val tm = rememberTextMeasurer()
    val cyr = uz.metrx.app.ui.theme.LocalLang.current.cyrillic
    val m2 = tr("u.m2")
    // the floor less its columns, plus niches from the floor, as everywhere else
    val floor = uz.metrx.app.geo.areas(r, snap)?.floor
    val g = if (r.isPoly) polyGeo(r, snap) else null
    // the drawing's own size, as in the prototype's svg width/height
    val T = (r.dim("T").v ?: 200).toFloat()
    var s = s0
    val vw: Float; val vh: Float
    if (g != null) {
        val xs = g.verts.map { it.x.toFloat() }; val ys = g.verts.map { it.y.toFloat() }
        val bw = xs.max() - xs.min(); val bh = ys.max() - ys.min()
        if (max(bw, bh) * s > 170) s = 170f / max(bw, bh)
        val tw = max(2.5f, T * s); vw = bw * s + 2 * (18 + tw); vh = bh * s + 2 * (18 + tw)
    } else {
        val ok = r.dim("A").v != null && r.dim("B").v != null
        val L = if (ok) r.dim("A").v!!.toFloat() else 4000f; val W = if (ok) r.dim("B").v!!.toFloat() else 3000f
        val t = max(2.5f, T * s); vw = L * s + 2 * t + 36; vh = W * s + 2 * t + 36
    }
    val k = min(1f, maxW.value / vw)
    Canvas(Modifier.size((vw * k).dp, (vh * k).dp).semantics { contentDescription = name }) {
        val px = size.width / vw
        val u = 1f / (density * fontScale)
        scaleTo(px) { Theme.onPaper { if (g != null) polyMini(r, g, s, T, name, en, tm, cyr, u, floor, m2) else rectMini(r, s, T, name, unit, en, tm, cyr, u, floor, m2) } }
    }
}

private inline fun DrawScope.scaleTo(k: Float, crossinline block: DrawScope.() -> Unit) = scale(k, k, Offset.Zero) { block() }

private val INK = Color(0xFF0E1C36)
private val INK3 = Color(0xFF3E4A61)

private fun DrawScope.label(tm: TextMeasurer, t: String, c: Offset, st: TextStyle) {
    val m = tm.measure(t, st); drawText(m, topLeft = Offset(c.x - m.size.width / 2f, c.y - m.size.height / 2f))
}

/** Text sizes in drawing units (the canvas is scaled to the svg's own units): [u] is 1 / (density · font scale). */
private fun dimStyle(u: Float) = TextStyle(fontFamily = PlexCond, fontSize = (11f * u).sp, color = INK3)
private fun nameStyle(u: Float, cyr: Boolean) = TextStyle(fontFamily = if (cyr) Manrope else Jakarta, fontSize = (10.5f * u).sp, fontWeight = FontWeight.SemiBold, letterSpacing = .05.em, color = INK)

private fun DrawScope.rectMini(r: Room, s: Float, T: Float, name: String, unit: LenUnit, en: Boolean, tm: TextMeasurer, cyr: Boolean, u: Float, floor: Long?, m2: String) {
    val ok = r.dim("A").v != null && r.dim("B").v != null
    val L = if (ok) r.dim("A").v!!.toFloat() else 4000f; val W = if (ok) r.dim("B").v!!.toFloat() else 3000f
    val t = max(2.5f, T * s); val iw = L * s; val ih = W * s
    val x0 = 18 + t; val y0 = 18 + t; val x1 = x0 + iw; val y1 = y0 + ih
    if (ok) {
        val ring = Path().apply {
            fillType = PathFillType.EvenOdd
            moveTo(x0 - t, y0 - t); lineTo(x1 + t, y0 - t); lineTo(x1 + t, y1 + t); lineTo(x0 - t, y1 + t); close()
            moveTo(x0, y0); lineTo(x0, y1); lineTo(x1, y1); lineTo(x1, y0); close()
        }
        drawPath(ring, INK)
        val wl = mapOf("A" to (Offset(x0, y0) to Offset(1f, 0f)), "B" to (Offset(x1, y0) to Offset(0f, 1f)), "C" to (Offset(x1, y1) to Offset(-1f, 0f)), "D" to (Offset(x0, y1) to Offset(0f, -1f)))
        r.openings.forEach { o ->
            val (st, d) = wl[o.wall] ?: return@forEach
            val n = Offset(-d.y, d.x)
            val p0 = st + d * (o.off * s); val p1 = st + d * ((o.off + o.w) * s); val q0 = p0 - n * t; val q1 = p1 - n * t
            val quad = Path().apply { moveTo(p0.x, p0.y); lineTo(p1.x, p1.y); lineTo(q1.x, q1.y); lineTo(q0.x, q0.y); close() }
            drawPath(quad, Color.White)
            if (o.type == "door") {
                val rr = o.w * s
                drawLine(INK, p0, p0 + n * rr, 1.4f)
                // the swing: from the far jamb round to the leaf's tip, dashed (svg arc, sweep flag 1)
                val start = Math.toDegrees(kotlin.math.atan2(d.y.toDouble(), d.x.toDouble())).toFloat()
                drawArc(INK, start, 90f, false, Offset(p0.x - rr, p0.y - rr), androidx.compose.ui.geometry.Size(2 * rr, 2 * rr),
                    style = Stroke(.8f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 2f))))
            } else {
                drawPath(quad, INK, style = Stroke(.8f))
                drawLine(INK, (p0 + q0) / 2f, (p1 + q1) / 2f, .8f)
            }
        }
        // svg text sits on its baseline; these are centred, so they move up by about a third of the size
        label(tm, fmtLen(L.toInt(), unit, en), Offset((x0 + x1) / 2, y0 - t - 5 - 4), dimStyle(u))
        val lc = Offset(x0 - t - 5 - 4, (y0 + y1) / 2)
        rotate(-90f, lc) { label(tm, fmtLen(W.toInt(), unit, en), lc, dimStyle(u)) }
    } else {
        drawRect(Color(0xFF5F6B82), Offset(x0, y0), androidx.compose.ui.geometry.Size(iw, ih), style = Stroke(1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))))
    }
    val cx = (x0 + x1) / 2; val cy = (y0 + y1) / 2
    label(tm, name.uppercase(), Offset(cx, cy - 2 - 4), nameStyle(u, cyr))
    label(tm, (if (ok && floor != null) fmtArea(floor, en) else "?") + " " + m2, Offset(cx, cy + 11 - 4), dimStyle(u))
}

private fun DrawScope.polyMini(r: Room, g: uz.metrx.app.geo.PolyGeo, s: Float, T: Float, name: String, en: Boolean, tm: TextMeasurer, cyr: Boolean, u: Float, floor: Long?, m2: String) {
    val v = g.verts; val minX = v.minOf { it.x }.toFloat(); val minY = v.minOf { it.y }.toFloat()
    val tw = max(2.5f, T * s); val ox = 18 + tw - minX * s; val oy = 18 + tw - minY * s
    val ip = v.map { Offset(ox + it.x.toFloat() * s, oy + it.y.toFloat() * s) }
    val n = ip.size
    val uu = v.indices.map { i -> val a = v[i]; val b = v[(i + 1) % n]; val l = hypot(b.x - a.x, b.y - a.y).takeIf { it > 0 } ?: 1.0; Offset(((b.x - a.x) / l).toFloat(), ((b.y - a.y) / l).toFloat()) }
    val no = uu.map { Offset(it.y, -it.x) }
    val op = ip.mapIndexed { i, p -> val a = no[(i - 1 + n) % n]; val b = no[i]; val d = 1 + a.x * b.x + a.y * b.y; if (d < .15f) p + b * tw else p + (a + b) * (tw / d) }
    if (g.solved) {
        val ring = Path().apply {
            fillType = PathFillType.EvenOdd
            moveTo(op[0].x, op[0].y); op.drop(1).forEach { lineTo(it.x, it.y) }; close()
            moveTo(ip[0].x, ip[0].y); ip.drop(1).forEach { lineTo(it.x, it.y) }; close()
        }
        drawPath(ring, INK)
        val ids = g.walls.map { it.id }
        r.openings.forEach { o ->
            val i = ids.indexOf(o.wall); if (i < 0) return@forEach
            val d = uu[i]; val q = no[i]
            val p0 = ip[i] + d * (o.off * s); val p1 = ip[i] + d * ((o.off + o.w) * s); val q0 = p0 + q * tw; val q1 = p1 + q * tw
            val quad = Path().apply { moveTo(p0.x, p0.y); lineTo(p1.x, p1.y); lineTo(q1.x, q1.y); lineTo(q0.x, q0.y); close() }
            drawPath(quad, Color.White)
            if (o.type == "window") drawPath(quad, INK, style = Stroke(.8f))
            else drawLine(INK, p0, p0 - q * (o.w * s), 1.4f)
        }
    } else {
        val path = Path().apply { moveTo(ip[0].x, ip[0].y); ip.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        drawPath(path, Color(0xFF5F6B82), style = Stroke(1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))))
    }
    val lp = labelPt(v.map { it.x to it.y })
    val c = Offset(ox + lp.first.toFloat() * s, oy + lp.second.toFloat() * s)
    label(tm, name.uppercase(), Offset(c.x, c.y - 2 - 4), nameStyle(u, cyr))
    label(tm, (if (g.solved && floor != null) fmtArea(floor, en) else "?") + " " + m2, Offset(c.x, c.y + 11 - 4), dimStyle(u))
}

/** Where a drawn room's name goes: the centroid, or the middle of the widest run across it (prototype skLabelPt). */
internal fun labelPt(v: List<Pair<Double, Double>>): Pair<Double, Double> {
    var a = 0.0; var cx = 0.0; var cy = 0.0
    v.forEachIndexed { i, p -> val q = v[(i + 1) % v.size]; val c = p.first * q.second - q.first * p.second; a += c; cx += (p.first + q.first) * c; cy += (p.second + q.second) * c }
    val c = if (abs(a) < 1e-9) v.sumOf { it.first } / v.size to v.sumOf { it.second } / v.size else cx / (3 * a) to cy / (3 * a)
    var inside = false; var j = v.size - 1
    for (i in v.indices) { val pa = v[i]; val pb = v[j]; if ((pa.second > c.second) != (pb.second > c.second) && c.first < (pb.first - pa.first) * (c.second - pa.second) / (pb.second - pa.second) + pa.first) inside = !inside; j = i }
    if (inside) return c
    val y = c.second; val xs = ArrayList<Double>()
    v.forEachIndexed { i, pa -> val pb = v[(i + 1) % v.size]; if ((pa.second > y) != (pb.second > y)) xs += pa.first + (y - pa.second) * (pb.first - pa.first) / (pb.second - pa.second) }
    xs.sort(); var best: Pair<Double, Double>? = null; var bw = -1.0
    var i = 0; while (i + 1 < xs.size) { if (xs[i + 1] - xs[i] > bw) { bw = xs[i + 1] - xs[i]; best = (xs[i] + xs[i + 1]) / 2 to y }; i += 2 }
    return best ?: v[0]
}

/** One workspace's measured rooms in 3D (prototype view '3d'). */
@Composable
fun Project3D(p: Project, route: Route.Project, lang: Lang) {
    val app = LocalApp.current
    val snap = app.settings.angleSnap
    val fid = route.floor?.takeIf { id -> p.floors.any { it.id == id } } ?: p.floors.firstOrNull()?.id
    val rs = p.rooms.filter { it.floorId == fid && ready3D(it, snap) }
    if (p.floors.size > 1) Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        p.floors.forEach { f ->
            val on = f.id == fid
            Box(
                Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp)).background(if (on) G.cobalt else G.idle(.55f))
                    .border(1.dp, if (on) G.cobalt else G.idleRim, RoundedCornerShape(12.dp))
                    .clickable(role = Role.Tab) { app.setTop(route.copy(floor = f.id)) }.padding(horizontal = 14.dp),
                contentAlignment = Alignment.Center
            ) { Text(floorName(f, lang), style = ui(14f, 600, if (on) Color.White else G.ink), maxLines = 1) }
        }
    }
    if (rs.isEmpty()) { Text(tr("v3d.none"), style = ui(13.5f, 400, G.ink2), modifier = Modifier.padding(vertical = 6.dp)); return }
    val key = rs.map { listOf(it.id, it.name, it.dims, it.openings, it.poly, it.features, it.points, it.wallColor, it.floorColor) }
    val shell = remember(key, snap, lang) { buildShell(rs, false, snap) { dn(it.name, lang) } }
    val cam = remember(fid) { Cam3D() }
    val scope = rememberCoroutineScope()
    fun all() { cam.focus = null; cam.go(scope, V3(shell.L / 2, shell.H * .3, shell.W / 2), cam.rFit ?: cam.r, PI / 2 + .45, .9) }
    val shape = RoundedCornerShape(22.dp)
    // the 3D surface ignores rounded clipping, so the corners are painted over with the background behind them
    var pos by remember { androidx.compose.runtime.mutableStateOf(Offset.Zero) }
    val root = androidx.compose.ui.platform.LocalView.current.rootView
    Box(Modifier.fillMaxWidth().height(400.dp).onGloballyPositioned { pos = it.positionInRoot() }) {
        Scene3D(shell, cam, Modifier.fillMaxSize()) {
            val r3 = shell.rooms3
            if (r3 != null) {
                Labels3D(cam, r3.map { V3(it.cx, it.h + .45, it.cz) }) { i ->
                    val x = r3[i]
                    RoomLbl3D(x.name, cam.focus == x.id) {
                        if (cam.focus == x.id) all()
                        else { cam.focus = x.id; cam.go(scope, V3(x.cx, x.h * .3, x.cz), min(cam.rMax ?: 99.0, v3Fit(x.w, x.d, x.h, cam.aspect) * 1.6)) }
                    }
                }
                ShotPill("room", tr("3d.all"), Modifier.align(Alignment.BottomEnd).padding(end = 10.dp, bottom = 10.dp)) { all() }
            } else Labels3D(cam, shell.labels.map { it.p }) { i -> Lbl3D(shell.labels[i].text) }
        }
        Canvas(Modifier.matchParentSize()) {
            val rr = 22.dp.toPx()
            val hole = Path().apply {
                fillType = PathFillType.EvenOdd
                addRect(androidx.compose.ui.geometry.Rect(Offset.Zero, size))
                addRoundRect(androidx.compose.ui.geometry.RoundRect(0f, 0f, size.width, size.height, rr, rr))
            }
            clipPath(hole) { drawAurora(androidx.compose.ui.geometry.Size(root.width.toFloat(), root.height.toFloat()), -pos) }
        }
    }
    NoteLine(tr("v3d.note", "n" to rs.size))
}

