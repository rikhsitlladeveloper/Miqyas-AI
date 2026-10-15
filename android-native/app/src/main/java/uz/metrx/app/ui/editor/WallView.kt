package uz.metrx.app.ui.editor

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Wall
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.shoelace
import uz.metrx.app.geo.wallStats
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sign

/* One wall seen from inside the room (prototype PAGES.wallView, wvElevSVG, openings.js drag in the wall view). */

private val DOOR_FILL get() = pc(0xFFE2E6EC, 0xFF283044)

/** Length and height used to draw a wall: confirmed or computed, else a received reading, else a placeholder. */
internal data class WallFrame(val L: Int, val H: Int, val lenKnown: Boolean, val hKnown: Boolean, val lenSt: String, val hSt: String, val provisional: Boolean)

internal fun wallFrame(r: Room, w: Wall, ops: List<Opening>): WallFrame {
    val d = r.dim(w.dimKey); val h = r.dim("H")
    val ext = ops.maxOfOrNull { it.off + it.w } ?: 0
    val hTop = ops.maxOfOrNull { it.sill + it.h } ?: 0
    val geoLen = hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y).roundToInt()
    val L = w.len ?: d.pending?.mm ?: max(if (geoLen > 0) geoLen else 4000, ext + 600)
    val H = h.v ?: h.pending?.mm ?: max(2700, hTop + 300)
    val lenSt = if (w.len != null && d.pending == null) "conf" else if (d.pending != null) "recv" else "unset"
    return WallFrame(L, H, w.len != null, h.v != null, lenSt, h.status, (w.len == null && d.pending != null) || (h.v == null && h.pending != null))
}

/** Where the elevation sits in its 360-wide viewBox (prototype: margins L52 R24 T30, height budget 170). */
internal class ElevLayout(fr: WallFrame, ops: List<Opening>) {
    val VW = 360f
    val chainH = if (ops.isNotEmpty()) 30f else 0f
    val ext = ops.maxOfOrNull { it.off + it.w } ?: 0
    val hTop = ops.maxOfOrNull { it.sill + it.h } ?: 0
    val Lx = max(fr.L, ext); val Hx = max(fr.H, hTop)
    val s = min(284f / Lx, 170f / Hx)
    val x0 = 52f + (284f - fr.L * s) / 2f
    val yFloor = 30f + Hx * s
    val yT = yFloor - fr.H * s
    val VH = yFloor + chainH + 50f
    fun x(mm: Int) = x0 + mm * s
    fun y(mm: Int) = yFloor - mm * s
}

@Composable
fun WallViewScreen(rt: Route.WallView) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val ops = app.ops
    val p = app.store.get(rt.pid) ?: return
    val r = p.rooms.firstOrNull { it.id == rt.rid } ?: return
    val snap = app.settings.angleSnap
    val ws = walls(r, snap)
    val i = ws.indexOfFirst { it.id == rt.wall }.coerceAtLeast(0)
    val w = ws[i]
    val unit = app.settings.unit; val en = app.english()
    val wallOps = r.openings.filter { it.wall == w.id }.sortedBy { it.off }
    val fr = wallFrame(r, w, wallOps)
    @Suppress("UNUSED_VARIABLE") val tick = ops.histTick
    val slide = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    fun go(step: Int) {
        if (ws.size < 2) return
        val n = ws[(i + step + ws.size) % ws.size]
        app.stack[app.stack.lastIndex] = rt.copy(wall = n.id)
        app.sheet = null
        scope.launch { slide.snapTo(28f * step); slide.animateTo(0f, tween(220)) }
    }
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(tr("wv.title", "w" to w.id), style = ui(20f, 800, G.ink, 1.2f), maxLines = 1)
                    Text(dn(r.name, lang), style = ui(12f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                GlassIconButton("undo", tr("common.undo"), { ops.undo(p.id, r.id) }, tint = if (ops.canUndo(r.id)) G.ink else OFF_ICON)
                GlassIconButton("redo", "redo", { ops.redo(p.id, r.id) }, tint = if (ops.canRedo(r.id)) G.ink else OFF_ICON)
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // pager: previous, the dots, next, and the small room map that leads back to the plan
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GlassIconButton("back", tr("wv.prev"), { go(-1) }, tint = if (ws.size > 1) G.ink else OFF_ICON)
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                        ws.forEachIndexed { k, _ -> Box(Modifier.size(if (k == i) 12.dp else 7.dp).clip(CircleShape).background(if (k == i) G.cobalt else G.ink.copy(alpha = .2f))) }
                    }
                    GlassIconButton("chev", tr("wv.next"), { go(1) }, tint = if (ws.size > 1) G.ink else OFF_ICON)
                    Locator(r, ws, i) { app.pop() }
                }
                Text(tr("wv.inside"), style = ui(12.5f, 400, G.ink2))
                Box(Modifier.fillMaxWidth().offset(x = slide.value.dp).alpha(1f - abs(slide.value) / 28f * .65f)) {
                    Elevation(r, w, wallOps, fr, unit, en, onSwipe = ::go,
                        onOpening = { id -> app.sheet = Sheet.OpeningForm(p.id, r.id, id) },
                        onLength = {
                            when {
                                w.derived && !r.isPoly -> { app.say("wv.derived", "w" to w.id, "s" to w.dimKey, kind = ToastKind.INFO); ops.focus(r.id, w.dimKey); app.pop() }
                                else -> { ops.focus(r.id, w.dimKey); app.pop() }
                            }
                        },
                        onHeight = { ops.focus(r.id, "H"); app.pop() },
                        onDragEnd = { o, off, sill -> ops.moveOpening(p.id, r.id, o, off, sill) })
                }
                wallOps.filter { ops.issue(r, it) != null }.forEach { o ->
                    val iss = ops.issue(r, o)!!
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.errWash).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        MIcon("alert", G.err, 18.dp, 2f)
                        Text(app.t(iss.key, *iss.vars.toList().toTypedArray()), style = ui(13.5f, 500, G.err, 1.35f), modifier = Modifier.weight(1f))
                        Text(tr("ed.fix"), style = ui(14f, 700, G.err), modifier = Modifier.clickable(role = Role.Button) { app.sheet = Sheet.OpeningForm(p.id, r.id, o.id) }.padding(6.dp))
                    }
                }
                if (wallOps.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    MIcon("info", G.ink2, 16.dp, 2f)
                    Text(tr(if (wallOps.any { it.type == "window" }) "op.dragHintW" else "op.dragHint"), style = ui(13f, 400, G.ink2, 1.4f))
                }
                Stats(r, w, wallOps, fr, en)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("wv.openings"), style = ui(15.5f, 600)); uz.metrx.app.ui.components.CountPill(wallOps.size)
                }
                if (wallOps.isEmpty()) Text(tr("wv.none"), style = ui(13.5f, 400, G.ink2))
                else Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    wallOps.forEach { o ->
                        Column(Modifier.width(152.dp).glassCard(RoundedCornerShape(18.dp), fill = G.glass(.55f)).clickable { app.sheet = Sheet.OpeningForm(p.id, r.id, o.id) }.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { MIcon(o.type, G.cobalt, 18.dp, 2f); Text(ops.opName(o), style = ui(14.5f, 700)) }
                            Text(fmtLen(o.w, unit, en) + " × " + fmtLen(o.h, unit, en) + " " + app.unitName(), style = num(14f, 600))
                            Text(tr("wv.off", "c" to w.corner, "v" to (if (o.offDrag) "≈ " else "") + fmtLen(o.off, unit, en) + " " + app.unitName()), style = ui(12.5f, 400, if (o.offDrag) AMBER else G.ink2))
                            if (o.type == "window") Text(tr("wv.sill", "v" to (if (o.sillDrag) "≈ " else "") + fmtLen(o.sill, unit, en) + " " + app.unitName()), style = ui(12.5f, 400, if (o.sillDrag) AMBER else G.ink2))
                            if (ops.issue(r, o) != null) Text(tr("room.bad"), style = ui(12.5f, 600, G.err))
                        }
                    }
                }
                Row(
                    Modifier.heightIn(min = 48.dp).clip(CircleShape).background(G.cobalt).pressable({ app.sheet = Sheet.WallAdd(p.id, r.id, w.id) }, .97f).padding(horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) { MIcon("plus", Color.White, 18.dp, 2.4f); Text(tr("wv.add"), style = ui(15f, 700, Color.White)) }
            }
        }
    }
}

/** The small room outline: the current wall in blue and an arrow showing which way we look (prototype wv mini locator). */
@Composable
private fun Locator(r: Room, ws: List<Wall>, i: Int, onTap: () -> Unit) {
    Canvas(Modifier.size(72.dp, 54.dp).clip(RoundedCornerShape(12.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(12.dp)).clickable(role = Role.Button, onClick = onTap)) {
        val pad = 8.dp.toPx()
        val pts = ws.map { Offset(it.p0.x.toFloat(), it.p0.y.toFloat()) }
        val minX = pts.minOf { it.x }; val maxX = pts.maxOf { it.x }; val minY = pts.minOf { it.y }; val maxY = pts.maxOf { it.y }
        val s = min((size.width - 2 * pad) / max(1f, maxX - minX), (size.height - 2 * pad) / max(1f, maxY - minY))
        val ox = (size.width - (maxX - minX) * s) / 2f - minX * s; val oy = (size.height - (maxY - minY) * s) / 2f - minY * s
        fun m(p: Offset) = Offset(ox + p.x * s, oy + p.y * s)
        val path = Path().apply { val a = m(pts[0]); moveTo(a.x, a.y); pts.drop(1).forEach { val b = m(it); lineTo(b.x, b.y) }; close() }
        drawPath(path, GREY_LINE, style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f))))
        val w = ws[i]
        val a = m(Offset(w.p0.x.toFloat(), w.p0.y.toFloat())); val b = m(Offset(w.p1.x.toFloat(), w.p1.y.toFloat()))
        drawLine(COB, a, b, 3.2f, StrokeCap.Round)
        // inside is to the right of a clockwise wall (y down)
        val d = b - a; val len = hypot(d.x, d.y).coerceAtLeast(1f)
        val sgn = if (shoelace(ws.map { it.p0 }) >= 0) 1f else -1f
        val nIn = Offset(-d.y / len, d.x / len) * sgn
        val mid = (a + b) / 2f
        val tip = mid + nIn * 3.5f.dp.toPx(); val base = mid + nIn * 10.dp.toPx()
        val u = Offset(d.x / len, d.y / len) * 4.dp.toPx()
        drawPath(Path().apply { moveTo(tip.x, tip.y); lineTo(base.x + u.x, base.y + u.y); lineTo(base.x - u.x, base.y - u.y); close() }, COB)
    }
}

@Composable
private fun Stats(r: Room, w: Wall, ops: List<Opening>, fr: WallFrame, en: Boolean) {
    val st = wallStats(if (fr.lenKnown) fr.L else r.dim(w.dimKey).pending?.mm, r.dim("H").v ?: r.dim("H").pending?.mm, ops)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row {
            StatCell(tr("wv.gross"), st.gross?.let { fmtArea(it, en) + " m²" } ?: "—", Modifier.weight(1f))
            StatCell(tr("rp.openings"), if (ops.isEmpty()) "—" else fmtArea(st.open, en) + " m²", Modifier.weight(1f))
            StatCell(tr("wv.net"), st.net?.let { fmtArea(it, en) + " m²" } ?: "—", Modifier.weight(1f), bold = true)
        }
        if (st.gross == null) Text(tr("wv.missing"), style = ui(12.5f, 400, G.ink2))
        else if (fr.provisional) Text(tr("wv.prov"), style = ui(12.5f, 500, AMBER))
    }
}

@Composable
private fun StatCell(label: String, v: String, modifier: Modifier, bold: Boolean = false) {
    Column(modifier) { Text(label, style = ui(11.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis); Text(v, style = num(16f, if (bold) 800 else 600)) }
}

/* ---------------- the elevation: drawing, taps and dragging ---------------- */

private data class Drag(val id: String, val off: Int, val sill: Int, val snapTag: String?)

@Composable
private fun Elevation(
    r: Room, w: Wall, ops: List<Opening>, fr: WallFrame, unit: LenUnit, en: Boolean,
    onSwipe: (Int) -> Unit, onOpening: (String) -> Unit, onLength: () -> Unit, onHeight: () -> Unit,
    onDragEnd: (Opening, Int, Int) -> Unit
) {
    val app = LocalApp.current
    val issueOf: (Opening) -> Boolean = { o -> app.ops.issue(r, o) != null }
    val tm = rememberTextMeasurer()
    var drag by remember { mutableStateOf<Drag?>(null) }
    var finger by remember { mutableStateOf(Offset.Zero) }
    val live = drag
    val shown = if (live == null) ops else ops.map { if (it.id == live.id) it.copy(off = live.off, sill = live.sill) else it }
    val lay = ElevLayout(fr, shown)
    val st = app.settings
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(G.glass(.55f)).border(1.dp, G.rim, RoundedCornerShape(22.dp)).roomGrid()) {
        Canvas(Modifier.fillMaxWidth().aspectRatio(lay.VW / lay.VH).pointerInput(r, w.id, fr) {
            awaitEachGesture {
                val down = awaitFirstDown()
                val k = size.width / lay.VW
                fun vb(p: Offset) = Offset(p.x / k, p.y / k)
                val start = down.position; val sp = vb(start)
                val laySnap = ElevLayout(fr, ops)
                val hitOp = ops.lastOrNull { o ->
                    val x0 = laySnap.x(o.off) - 4; val x1 = laySnap.x(o.off + o.w) + 4
                    val y0 = laySnap.y(o.sill + o.h) - 4; val y1 = laySnap.y(o.sill) + 4
                    sp.x in x0..x1 && sp.y in y0..y1
                }
                var dragging = false; var axis: Char? = null
                var cur: Drag? = null; var swiped = false
                val mmPerPx = 1f / k / laySnap.s
                while (true) {
                    val ev = awaitPointerEvent()
                    val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                    if (!ch.pressed) break
                    val d = ch.position - start
                    if (hitOp != null) {
                        if (!dragging && hypot(d.x, d.y) > 7.dp.toPx()) {
                            dragging = true
                            if (hitOp.type == "window") axis = when { abs(d.y) > 1.4f * abs(d.x) -> 'v'; abs(d.x) > 1.4f * abs(d.y) -> 'h'; else -> null }
                        }
                        if (dragging) {
                            ch.consume()
                            val slack = 14.dp.toPx()
                            fun sl(v: Float, on: Boolean) = if (on) sign(v) * max(0f, abs(v) - slack) else v
                            val dx = if (hitOp.type == "door") d.x else sl(d.x, axis == 'v')
                            val off = snapOff(hitOp.off + (dx * mmPerPx).roundToInt(), hitOp.w, if (fr.lenKnown) fr.L else null)
                            var sill = hitOp.sill; var tag: String? = null
                            if (hitOp.type == "window") {
                                val dy = sl(d.y, axis == 'h')
                                val raw = hitOp.sill - (dy * mmPerPx).roundToInt()
                                val (sv, t) = snapSill(raw, hitOp, ops, st.winSill, if (fr.hKnown) fr.H else null)
                                sill = sv; tag = t
                            }
                            cur = Drag(hitOp.id, off, sill, tag); drag = cur; finger = ch.position
                        }
                    } else if (!swiped && abs(d.x) >= 48.dp.toPx() && abs(d.x) >= 1.5f * abs(d.y)) {
                        swiped = true; onSwipe(if (d.x < 0) 1 else -1)
                    }
                }
                drag = null
                val c = cur
                if (dragging && hitOp != null && c != null) onDragEnd(hitOp, c.off, c.sill)
                else if (!swiped) {
                    if (hitOp != null) onOpening(hitOp.id)
                    else {
                        val ly = laySnap
                        if (abs(sp.y - (ly.yFloor + ly.chainH + 30f)) < 20f) onLength()
                        else if (abs(sp.x - (ly.x0 - 26f)) < 20f && sp.y in ly.yT..ly.yFloor) onHeight()
                    }
                }
            }
        }) {
            val k = size.width / lay.VW
            withTransform({ scale(k, k, pivot = Offset.Zero) }) { drawElevation(lay, r, w, shown, fr, unit, en, live, tm, issueOf) }
            if (live != null) {
                val o = shown.first { it.id == live.id }
                val bad = app.ops.issue(r, o) != null
                val t = app.t("wv.off", "c" to w.corner, "v" to fmtLen(o.off, unit, en) + " " + app.unitName()) +
                    if (o.type == "window") "\n" + app.t("wv.sill", "v" to fmtLen(o.sill, unit, en) + " " + app.unitName()) else ""
                dragTip(tm, t, finger, bad)
            }
        }
    }
}

/** Sill snapping (prototype snapSill): 10 mm steps; the default sill, other windows' sills and other openings' heads within 50 mm. */
internal fun snapSill(raw: Int, o: Opening, all: List<Opening>, defSill: Int, H: Int?): Pair<Int, String?> {
    var v = (raw / 10.0).roundToInt() * 10
    val cands = ArrayList<Pair<Int, String>>()
    cands += defSill to "def"
    all.filter { it.id != o.id && it.wall == o.wall }.forEach { x ->
        if (x.type == "window") cands += x.sill to "sill"
        cands += (x.sill + x.h - o.h) to "top"
    }
    var tag: String? = null
    cands.filter { it.first >= 0 && abs(it.first - v) <= 50 }.minByOrNull { abs(it.first - v) }?.let { v = it.first; tag = it.second }
    v = if (H != null) v.coerceIn(0, max(0, H - o.h)) else max(0, v)
    return v to tag
}

private fun DrawScope.drawElevation(lay: ElevLayout, r: Room, w: Wall, ops: List<Opening>, fr: WallFrame, unit: LenUnit, en: Boolean, live: Drag?, tm: TextMeasurer, issueOf: (Opening) -> Boolean) {
    val x0 = lay.x0; val x1 = lay.x(fr.L); val yT = lay.yT; val yF = lay.yFloor
    // floor: a hatched band 7 high reaching 14 past each side, and the floor line
    clipRect(x0 - 14f, yF, x1 + 14f, yF + 7f) {
        var x = x0 - 14f - 7f
        while (x < x1 + 14f) { drawLine(INK, Offset(x, yF + 7f), Offset(x + 7f, yF), 1f); x += 4f }
    }
    drawLine(INK, Offset(x0 - 14f, yF), Offset(x1 + 14f, yF), 2.4f)
    // the wall face; its sides dashed while the length is not confirmed, the top while the height is not
    drawRect(PLAN_W, Offset(x0, yT), Size(x1 - x0, yF - yT))
    val dash = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))
    drawLine(INK, Offset(x0, yT), Offset(x0, yF), 1.4f, pathEffect = if (fr.lenKnown) null else dash)
    drawLine(INK, Offset(x1, yT), Offset(x1, yF), 1.4f, pathEffect = if (fr.lenKnown) null else dash)
    drawLine(INK, Offset(x0, yT), Offset(x1, yT), 1.4f, pathEffect = if (fr.hKnown) null else dash)
    // corner numbers above the wall: start on the left, end on the right
    val n = walls(r).size
    listOf(x0 to w.corner, x1 to (w.corner % n + 1)).forEach { (x, c) ->
        drawCircle(PLAN_W, 9f, Offset(x, yT - 14f)); drawCircle(INK3, 9f, Offset(x, yT - 14f), style = Stroke(1f))
        text(tm, "$c", Offset(x, yT - 14f), TextStyle(fontFamily = Jakarta, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = INK))
    }
    // guide lines while a window is dragged
    if (live != null && fr.H > 0) {
        val o = ops.first { it.id == live.id }
        if (o.type == "window") {
            fun guide(yMm: Int, on: Boolean) = drawLine(COB.copy(alpha = if (on) 1f else .6f), Offset(x0, lay.y(yMm)), Offset(x1, lay.y(yMm)), if (on) 1.6f else .9f,
                pathEffect = if (on) null else PathEffect.dashPathEffect(floatArrayOf(4f, 3f)))
            guide(o.sill, live.snapTag == "sill" || live.snapTag == "def")
            guide(o.sill + o.h, live.snapTag == "top")
            val rightRoom = x1 - lay.x(o.off + o.w) >= 46f
            val gx = if (rightRoom) lay.x(o.off + o.w) + 12f else lay.x(o.off) - 12f
            val st = TextStyle(fontFamily = PlexCond, fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold, color = COB)
            if (lay.y(0) - lay.y(o.sill) >= 2f) { drawLine(COB, Offset(gx, lay.y(0)), Offset(gx, lay.y(o.sill)), 1f); text(tm, fmtLen(o.sill, unit, en), Offset(gx + if (rightRoom) 14f else -14f, (lay.y(0) + lay.y(o.sill)) / 2f), st) }
            val top = fr.H - o.sill - o.h
            if (top > 0 && lay.y(o.sill + o.h) - lay.y(fr.H) >= 2f) { drawLine(COB, Offset(gx, lay.y(o.sill + o.h)), Offset(gx, lay.y(fr.H)), 1f); text(tm, fmtLen(top, unit, en), Offset(gx + if (rightRoom) 14f else -14f, (lay.y(o.sill + o.h) + lay.y(fr.H)) / 2f), st) }
        }
    }
    // doors and windows to scale (one universal look, one colour)
    ops.forEach { o ->
        val bad = issueOf(o)
        val c = if (bad) RED else if (live?.id == o.id) COB else INK
        val rx = lay.x(o.off); val rw = max(2f, o.w * lay.s); val ry = lay.y(o.sill + o.h); val rh = max(2f, o.h * lay.s)
        drawRect(DOOR_FILL, Offset(rx, ry), Size(rw, rh)); drawRect(c, Offset(rx, ry), Size(rw, rh), style = Stroke(1.4f))
        if (o.type == "door") {
            drawRect(c, Offset(rx + 3f, ry + 3f), Size(rw - 6f, rh - 3f), style = Stroke(.9f))
            drawCircle(c, 1.8f, Offset(rx + rw - 7f, ry + rh * .55f))
        } else {
            drawLine(c, Offset(rx + rw / 2, ry), Offset(rx + rw / 2, ry + rh), 1f)
            drawLine(c, Offset(rx - 3f, ry + rh), Offset(rx + rw + 3f, ry + rh), 2f)
        }
        if (rw > 30f && rh > 26f) text(tm, fmtLen(o.h, unit, en), Offset(rx + rw / 2, ry + rh / 2), TextStyle(fontFamily = PlexCond, fontSize = 10.sp, color = INK3))
        if (o.approx && live?.id != o.id) drawRect(AMBER, Offset(rx - 3f, ry - 3f), Size(rw + 6f, rh + 6f), style = Stroke(1.2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))))
        if (bad) drawRect(RED, Offset(rx - 3f, ry - 3f), Size(rw + 6f, rh + 6f), style = Stroke(1.6f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))))
    }
    // the chain of distances along the floor
    if (ops.isNotEmpty()) {
        val y = yF + 18f
        val cuts = (listOf(0) + ops.flatMap { listOf(it.off, it.off + it.w) } + fr.L).map { it.coerceIn(0, fr.L) }.distinct().sorted()
        drawLine(INK3, Offset(lay.x(0), y), Offset(lay.x(fr.L), y), .9f, pathEffect = if (fr.lenKnown) null else dash)
        cuts.forEach { cx -> val x = lay.x(cx); drawLine(INK3, Offset(x - 3f, y + 3f), Offset(x + 3f, y - 3f), 1.2f) }
        val st = TextStyle(fontFamily = PlexCond, fontSize = 10.5.sp, color = INK3)
        for (k in 0 until cuts.size - 1) {
            val a = lay.x(cuts[k]); val b = lay.x(cuts[k + 1])
            val last = k == cuts.size - 2
            val t = if (last && !fr.lenKnown) "?" else fmtLen(cuts[k + 1] - cuts[k], unit, en)
            val narrow = (b - a) < 8f * t.length
            text(tm, t, Offset((a + b) / 2f, if (narrow && k % 2 == 1) y + 22f else y + 10f), st)
        }
    }
    // overall length, and the height on the left
    val ly = yF + lay.chainH + 30f
    val lc = when (fr.lenSt) { "conf" -> INK; "recv" -> AMBER; else -> GREY_LINE }
    drawLine(lc, Offset(x0, ly), Offset(x1, ly), 1.1f, pathEffect = if (fr.lenSt == "conf") null else dash)
    listOf(x0, x1).forEach { x -> drawLine(lc, Offset(x - 4f, ly + 4f), Offset(x + 4f, ly - 4f), 1.6f) }
    val lenTxt = if (w.derived && !r.isPoly) "= " + w.dimKey else when (fr.lenSt) { "recv" -> fmtLen(r.dim(w.dimKey).pending!!.mm, unit, en, true); "conf" -> fmtLen(w.len, unit, en); else -> "?" }
    tag(tm, lenTxt, Offset((x0 + x1) / 2f, ly), fr.lenSt, 0f)
    val hx = x0 - 26f
    val hc = when (fr.hSt) { "conf" -> INK; "recv" -> AMBER; else -> GREY_LINE }
    drawLine(hc, Offset(hx, yT), Offset(hx, yF), 1.1f, pathEffect = if (fr.hSt == "conf") null else dash)
    listOf(yT, yF).forEach { y -> drawLine(hc, Offset(hx - 4f, y + 4f), Offset(hx + 4f, y - 4f), 1.6f) }
    val hTxt = when (fr.hSt) { "recv" -> fmtLen(r.dim("H").pending!!.mm, unit, en, true); "conf" -> fmtLen(r.dim("H").v, unit, en); else -> "?" }
    tag(tm, hTxt, Offset(hx, (yT + yF) / 2f), fr.hSt, -90f)
}

private fun DrawScope.tag(tm: TextMeasurer, t: String, c: Offset, st: String, rot: Float) {
    val icon = st != "unset"
    val pw = pillW(t, icon)
    rotate(rot, c) {
        val rect = Rect(c.x - pw / 2, c.y - 13f, c.x + pw / 2, c.y + 13f)
        drawRoundRect(pillFill(.9f), rect.topLeft, rect.size, CornerRadius(13f))
        drawRoundRect(if (st == "recv") AMBER else if (st == "unset") GREY_LINE else pillEdge(1f), rect.topLeft, rect.size, CornerRadius(13f),
            style = Stroke(1.2f, pathEffect = if (st == "unset") PathEffect.dashPathEffect(floatArrayOf(3f, 2f)) else null))
        text(tm, t, Offset(c.x + if (st == "conf") -7f else if (st == "recv") 7f else 0f, c.y), TextStyle(fontFamily = Jakarta, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold, color = PILL_INK))
        if (st == "conf") {
            val x = rect.right - 14f
            drawPath(Path().apply { moveTo(x, c.y); relativeLineTo(3f, 3f); relativeLineTo(5.5f, -5.5f) }, OK_GREEN, style = Stroke(2.2f, cap = StrokeCap.Round))
        } else if (st == "recv") {
            val cc = Offset(rect.left + 12f, c.y)
            drawCircle(AMBER, 5f, cc, style = Stroke(1.6f)); drawLine(AMBER, cc, cc + Offset(0f, -3f), 1.6f); drawLine(AMBER, cc, cc + Offset(2.2f, 1.2f), 1.6f)
        }
    }
}


