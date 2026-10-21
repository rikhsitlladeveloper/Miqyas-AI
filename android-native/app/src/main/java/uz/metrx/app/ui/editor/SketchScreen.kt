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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.uid
import uz.metrx.app.geo.PAD_H
import uz.metrx.app.geo.PAD_W
import uz.metrx.app.geo.SketchResult
import uz.metrx.app.geo.polyDims
import uz.metrx.app.geo.polyWallIds
import uz.metrx.app.geo.processSketch
import uz.metrx.app.geo.selfIntersects
import uz.metrx.app.geo.sketchToMm
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.Jakarta
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.roundToInt

/** Drawing a room's outline: one stroke, or corner taps (prototype PAGES.sketch). */
@Composable
fun SketchScreen(rt: Route.Sketch) {
    val app = LocalApp.current
    val tm = rememberTextMeasurer()
    var tapMode by remember { mutableStateOf(false) }
    val stroke = remember { mutableStateListOf<Pt>() }                   // the live finger path, pad units
    var raw by remember { mutableStateOf<List<Pt>?>(null) }
    val taps = remember { mutableStateListOf<Pt>() }
    var tapClosed by remember { mutableStateOf(false) }
    var forceClosed by remember { mutableStateOf(false) }
    val snap = app.settings.angleSnap
    val res: SketchResult? = when {
        tapMode && taps.isNotEmpty() -> processSketch(taps.toList(), true, tapClosed, snap)
        !tapMode && raw != null -> processSketch(raw!!, false, false, snap).let { r ->
            if (forceClosed && r.err == "open" && r.verts.size >= 3) {
                val v = r.verts
                selfIntersects(v)?.let { SketchResult(v, true, "cross", it) } ?: SketchResult(uz.metrx.app.geo.orient(v), true, null)
            } else r
        }
        else -> null
    }
    fun clear() { stroke.clear(); raw = null; taps.clear(); tapClosed = false; forceClosed = false }
    fun create() {
        val r = res ?: return
        if (r.err != null || !r.closed) return
        val mm = sketchToMm(r.verts)
        if (mm.size < 3 || selfIntersects(mm) != null) { app.say("sk.cross", kind = ToastKind.ERROR); return }
        val room = Room(uid(), rt.wid, rt.name, template = "poly", shape = "poly", dims = polyDims(mm.size), poly = Poly(mm, template = "sketch"), created = System.currentTimeMillis())
        app.store.update(rt.pid) { it.copy(rooms = it.rooms + room) }
        app.replaceTop(Route.Editor(rt.pid, room.id))
        app.say("sk.created", "n" to uz.metrx.app.data.dn(room.name, app.settings.lang))
    }
    Column(Modifier.fillMaxSize().roomGrid().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GlassIconButton("x", tr("common.close"), { app.pop() })
            Column(Modifier.weight(1f)) {
                Text(tr("sk.title"), style = ui(20f, 800)); Text(rt.name, style = ui(12f, 400, G.ink2))
            }
        }
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f)) { Seg(listOf("d" to tr("sk.draw"), "t" to tr("sk.tap")), if (tapMode) "t" else "d") { tapMode = it == "t"; clear() } }
            if (tapMode && taps.isNotEmpty() && !tapClosed) Box(Modifier.clip(CircleShape).background(G.glass(.7f)).clickable(role = Role.Button) { taps.removeAt(taps.lastIndex); tapClosed = false }.padding(10.dp)) {
                uz.metrx.app.ui.icons.MIcon("undo", G.ink, 20.dp, 2f)
            }
            Text("90°/45°", style = ui(13.5f, 700, if (snap) Color.White else G.ink),
                modifier = Modifier.heightIn(min = 44.dp).clip(CircleShape).background(if (snap) G.cobalt else G.idle(.7f))
                    .border(1.dp, if (snap) G.cobalt else G.idleRim, CircleShape).clickable(role = Role.Switch) { app.settings.setSnap(!snap) }.padding(horizontal = 14.dp, vertical = 12.dp))
        }
        // the pad
        Box(Modifier.weight(1f).fillMaxWidth().padding(16.dp).clip(RoundedCornerShape(22.dp)).background(G.glass(.5f)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
            Canvas(Modifier.fillMaxSize().pointerInput(tapMode, tapClosed) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    val k = min(size.width / PAD_W, size.height / PAD_H)
                    val dx = (size.width - PAD_W * k) / 2f; val dy = (size.height - PAD_H * k) / 2f
                    fun pad(p: Offset) = Pt((((p.x - dx) / k) * 10).roundToInt() / 10.0, (((p.y - dy) / k) * 10).roundToInt() / 10.0)
                    if (!tapMode) {
                        stroke.clear(); raw = null; forceClosed = false
                        stroke += pad(down.position)
                        while (true) {
                            val ev = awaitPointerEvent()
                            val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                            if (!ch.pressed) break
                            ch.consume()
                            val q = pad(ch.position); val l = stroke.last()
                            if (hypot(q.x - l.x, q.y - l.y) >= 1.5) stroke += q
                        }
                        raw = stroke.map { Pt(it.x.roundToInt().toDouble(), it.y.roundToInt().toDouble()) }
                        stroke.clear()
                    } else {
                        var moved = false
                        while (true) {
                            val ev = awaitPointerEvent()
                            val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                            if (!ch.pressed) break
                            if (hypot(ch.position.x - down.position.x, ch.position.y - down.position.y) > 10.dp.toPx()) moved = true
                        }
                        if (!moved && !tapClosed) {
                            val q = pad(down.position)
                            if (taps.size >= 3 && hypot(q.x - taps[0].x, q.y - taps[0].y) <= 22) tapClosed = true
                            else taps += Pt(q.x.roundToInt().toDouble(), q.y.roundToInt().toDouble())
                        }
                    }
                }
            }) {
                val k = min(size.width / PAD_W, size.height / PAD_H)
                val dx = (size.width - PAD_W * k) / 2f; val dy = (size.height - PAD_H * k) / 2f
                withTransform({ translate(dx, dy); scale(k, k, pivot = Offset.Zero) }) {
                    fun o(p: Pt) = Offset(p.x.toFloat(), p.y.toFloat())
                    // the finger stroke: live in blue, finished in grey
                    if (stroke.size > 1) drawPath(Path().apply { moveTo(stroke[0].x.toFloat(), stroke[0].y.toFloat()); stroke.drop(1).forEach { lineTo(it.x.toFloat(), it.y.toFloat()) } }, COB, style = Stroke(3f, cap = StrokeCap.Round, join = StrokeJoin.Round))
                    raw?.takeIf { it.size > 1 && !tapMode }?.let { rw -> drawPath(Path().apply { moveTo(o(rw[0]).x, o(rw[0]).y); rw.drop(1).forEach { lineTo(o(it).x, o(it).y) } }, pc(0xFF9AA8BF, 0xFF5E6A82), style = Stroke(2f, cap = StrokeCap.Round)) }
                    if (tapMode && taps.size >= 3 && !tapClosed) drawCircle(COB, 14f, o(taps[0]), style = Stroke(1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f))))
                    val r = res ?: return@withTransform
                    val v = r.verts
                    if (v.size < 2) return@withTransform
                    val path = Path().apply { moveTo(o(v[0]).x, o(v[0]).y); v.drop(1).forEach { lineTo(o(it).x, o(it).y) }; if (r.closed) close() }
                    val crossing = r.err == "cross"
                    if (r.closed && r.err == null) drawPath(path, COB_WASH)
                    drawPath(path, if (crossing) RED else INK, style = Stroke(3f, join = StrokeJoin.Round, pathEffect = if (crossing) PathEffect.dashPathEffect(floatArrayOf(7f, 5f)) else null))
                    if (r.closed && r.err == null) {
                        val ids = polyWallIds(v.size)
                        val sgn = 1f
                        v.indices.forEach { i ->
                            val a = o(v[i]); val b = o(v[(i + 1) % v.size])
                            drawCircle(PLAN_W, 4.5f, a); drawCircle(INK, 4.5f, a, style = Stroke(1.2f))
                            val d = b - a; val l = hypot(d.x, d.y).coerceAtLeast(1f)
                            val inward = Offset(-d.y / l, d.x / l) * sgn
                            val c = (a + b) / 2f + inward * 14f
                            drawCircle(PLAN_W, 9f, c); drawCircle(INK3, 9f, c, style = Stroke(1f))
                            text(tm, ids[i], c, TextStyle(fontFamily = Jakarta, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = INK))
                        }
                    } else if (!r.closed) {
                        drawLine(AMBER, o(v.last()), o(v.first()), 1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 4f)))
                        drawCircle(COB, 8f, o(v.first())); drawCircle(PLAN_W, 3f, o(v.first()))
                        drawCircle(PLAN_W, 8f, o(v.last())); drawCircle(COB, 8f, o(v.last()), style = Stroke(2f))
                    }
                    r.cross?.let { x -> drawCircle(RED, 11f, o(x)); drawLine(ON_FILL, o(x) + Offset(-4f, -4f), o(x) + Offset(4f, 4f), 2f); drawLine(ON_FILL, o(x) + Offset(4f, -4f), o(x) + Offset(-4f, 4f), 2f) }
                }
            }
        }
        // the message line
        val r = res
        val (msg, kind) = when {
            r == null -> tr(if (tapMode) "sk.tapHint" else "sk.drawHint") to "hint"
            r.err == "open" -> tr("sk.open") to "warn"
            r.err != null -> tr("sk.${r.err}") to (if (r.err == "cross") "err" else "warn")
            else -> tr("sk.ready", "n" to r.verts.size) to "ok"
        }
        Row(Modifier.padding(horizontal = 16.dp).fillMaxWidth().clip(RoundedCornerShape(14.dp))
            .background(when (kind) { "err" -> G.errWash; "warn" -> G.amberWash; "ok" -> G.green.copy(alpha = .1f); else -> G.glass(.6f) }).padding(12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(msg, style = ui(13.5f, 500, when (kind) { "err" -> G.err; "warn" -> AMBER; "ok" -> OK_GREEN; else -> G.ink2 }, 1.35f), modifier = Modifier.weight(1f))
            if (r?.err == "open" && r.verts.size >= 3 && !tapMode) Text(tr("sk.close"), style = ui(14f, 700, G.cobalt), modifier = Modifier.clickable(role = Role.Button) { forceClosed = true }.padding(6.dp))
        }
        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("sk.redraw"), ::clear, Btn.SECONDARY, enabled = raw != null || taps.isNotEmpty(), modifier = Modifier.weight(1f))
            GBtn(tr("nr.create"), ::create, enabled = r != null && r.closed && r.err == null, modifier = Modifier.weight(1f))
        }
    }
}

