package uz.metrx.app.ui.markup

import android.content.Context
import android.content.Intent
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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Laser
import uz.metrx.app.data.Item
import uz.metrx.app.data.MkEl
import uz.metrx.app.data.PhotoFiles
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.geo.Parsed
import uz.metrx.app.geo.dimMax
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.lenErr
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.ActionRow
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.ListBox
import uz.metrx.app.ui.editor.NumField
import uz.metrx.app.ui.editor.errText
import uz.metrx.app.ui.editor.unitName
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.theme.uiFont
import java.io.File
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random

/*
 * Free drawings and photos with dimensions (prototype workspace.js PAGES.draw / PAGES.photo and camera.js for the
 * Measure page's pictures): pen, line or dimension, arrow, text and eraser, three colours, undo and redo.
 */

/** Where a new photo goes: a project's workspace, or (no project) the Measure page's pictures. */
data class PhotoTarget(val pid: String?, val wid: String?)

/** The markup editor's choices and undo history, kept while the app runs (prototype U.mkTool, U.mkCol, U.mkW, U.mkH). */
class MarkOps(private val app: App) {
    private val tool = mutableStateMapOf<String, String>()
    private val col = mutableStateMapOf<String, String>()
    var width by mutableIntStateOf(1)
    var tick by mutableIntStateOf(0); private set
    private val undo = HashMap<String, ArrayList<List<MkEl>>>()
    private val redo = HashMap<String, ArrayList<List<MkEl>>>()
    /** A laser reading waiting in the dimension sheet, and the text it put in the field (to tell laser from typed). */
    var recv by mutableStateOf<Int?>(null)
    var laserText: String? = null
    /** Set by the app's photo pickers: opens the gallery, or the phone's camera app. */
    var launch: ((PhotoTarget, Boolean) -> Unit)? = null

    fun toolOf(it: Item): String { val ts = MK_TOOLS[it.kind] ?: MK_TOOLS.getValue("drawing"); val c = tool[it.kind]; return if (c != null && c in ts) c else ts[0] }
    fun setTool(it: Item, t: String) { tool[it.kind] = t }
    fun colorOf(it: Item) = col[it.kind] ?: if (it.kind == "photo") "red" else "ink"
    fun setColor(it: Item, c: String) { col[it.kind] = c }

    fun item(r: Route.Markup): Item? =
        if (r.pid == null) app.settings.shots.firstOrNull { it.id == r.iid }
        else app.store.get(r.pid)?.floors?.flatMap { it.items }?.firstOrNull { it.id == r.iid }

    fun wid(r: Route.Markup): String? = r.pid?.let { pid -> app.store.get(pid)?.floors?.firstOrNull { w -> w.items.any { it.id == r.iid } }?.id }

    /** The item's workspace name, or "Pictures" for the Measure page's. */
    fun place(r: Route.Markup, l: Lang): String =
        if (r.pid == null) app.t("cm.shots") else app.store.get(r.pid)?.floors?.firstOrNull { w -> w.items.any { it.id == r.iid } }?.let { floorName(it, l) } ?: ""

    fun update(r: Route.Markup, f: (Item) -> Item) {
        val now = System.currentTimeMillis()
        if (r.pid == null) app.settings.saveShots(app.settings.shots.map { if (it.id == r.iid) f(it).copy(edited = now) else it })
        else app.store.update(r.pid) { p -> p.copy(floors = p.floors.map { w -> w.copy(items = w.items.map { if (it.id == r.iid) f(it).copy(edited = now) else it }) }) }
    }

    /** Remembers the marks before a change (prototype mkSnap: at most 60 steps). */
    fun snap(it: Item) {
        val u = undo.getOrPut(it.id) { ArrayList() }; u.add(it.els); if (u.size > 60) u.removeAt(0)
        redo[it.id] = ArrayList(); tick++
    }
    fun change(r: Route.Markup, f: (List<MkEl>) -> List<MkEl>) { val it = item(r) ?: return; snap(it); update(r) { x -> x.copy(els = f(x.els)) } }
    fun canUndo(id: String) = undo[id]?.isNotEmpty() == true
    fun canRedo(id: String) = redo[id]?.isNotEmpty() == true
    fun undo(r: Route.Markup) {
        val it = item(r) ?: return; val u = undo[it.id] ?: return; if (u.isEmpty()) return
        redo.getOrPut(it.id) { ArrayList() }.add(it.els); val prev = u.removeAt(u.lastIndex); update(r) { x -> x.copy(els = prev) }; tick++
    }
    fun redo(r: Route.Markup) {
        val it = item(r) ?: return; val rd = redo[it.id] ?: return; if (rd.isEmpty()) return
        undo.getOrPut(it.id) { ArrayList() }.add(it.els); val next = rd.removeAt(rd.lastIndex); update(r) { x -> x.copy(els = next) }; tick++
    }

    /** A new free drawing in a workspace (prototype addFree), opened right away. */
    fun newDrawing(pid: String, wid: String) {
        val now = System.currentTimeMillis()
        val n = (app.store.get(pid)?.floors?.firstOrNull { it.id == wid }?.items?.count { it.kind == "drawing" } ?: 0) + 1
        val it = Item(uid(), "drawing", app.t("it.drawing", "n" to n), created = now, edited = now, W = 1000, H = 1300)
        app.store.update(pid) { p -> p.copy(floors = p.floors.map { w -> if (w.id == wid) w.copy(items = w.items + it) else w }) }
        app.sheet = null; app.push(Route.Markup(pid, it.id))
    }

    /** A photo saved as [src] ([w] × [h] px) becomes an item there and opens; [els] are the live camera's line. */
    fun addPhoto(t: PhotoTarget, id: String, src: String, w: Int, h: Int, els: List<MkEl> = emptyList()): Item {
        val now = System.currentTimeMillis()
        val hh = (1000f * h / w).roundToInt()
        return if (t.pid == null || t.wid == null) {
            val it = Item(id, "photo", app.t("cm.shotN", "n" to app.settings.shots.size + 1), created = now, edited = now, els = els, src = src, W = 1000, H = hh, rep = false)
            app.settings.saveShots(listOf(it) + app.settings.shots); it
        } else {
            val n = (app.store.get(t.pid)?.floors?.firstOrNull { it.id == t.wid }?.items?.count { it.kind == "photo" } ?: 0) + 1
            val it = Item(id, "photo", app.t("it.photo", "n" to n), created = now, edited = now, els = els, src = src, W = 1000, H = hh)
            app.store.update(t.pid) { p -> p.copy(floors = p.floors.map { w2 -> if (w2.id == t.wid) w2.copy(items = w2.items + it) else w2 }) }; it
        }
    }
}

/** The photo file of an item, decoded once for the screen. */
@Composable
fun rememberPhoto(src: String?, maxW: Int = 1400): ImageBitmap? {
    val ctx = LocalContext.current
    val v by produceState<ImageBitmap?>(null, src) { value = if (src == null) null else withContext(Dispatchers.IO) { PhotoFiles.load(ctx, src, maxW)?.asImageBitmap() } }
    return v
}

@Composable
fun mkFmt(lang: Lang = LocalLang.current): MkFmt {
    val app = LocalApp.current
    return MkFmt(app.settings.unit, lang == Lang.EN, app.unitName(), lang, uiFont())
}

private class Live {
    var pen by mutableStateOf<List<List<Float>>?>(null)
    var line by mutableStateOf<Pair<List<Float>, List<Float>>?>(null)
    var faded by mutableStateOf<Set<String>>(emptySet())
}

@Composable
fun MarkupScreen(r: Route.Markup) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val ops = app.mk
    val it = ops.item(r) ?: return
    @Suppress("UNUSED_VARIABLE") val tick = ops.tick
    val ph = it.kind == "photo"
    val tool = ops.toolOf(it); val col = ops.colorOf(it)
    val photo = rememberPhoto(it.src)
    val tm = rememberTextMeasurer()
    val fmt = mkFmt()
    val live = remember { Live() }
    val cur by rememberUpdatedState(it)
    val density = androidx.compose.ui.platform.LocalDensity.current.density
    Column(Modifier.fillMaxSize().background(G.paper).statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GlassIconButton("back", tr("nt.back"), { app.pop() })
            Column(Modifier.weight(1f)) {
                Text(dn(it.name, lang), style = ui(18f, 800, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(ops.place(r, lang), style = ui(12f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            GlassIconButton("undo", tr("common.undo"), { ops.undo(r) }, Modifier.alpha(if (ops.canUndo(it.id)) 1f else .4f), iconSize = 20.dp)
            GlassIconButton("redo", "redo", { ops.redo(r) }, Modifier.alpha(if (ops.canRedo(it.id)) 1f else .4f), iconSize = 20.dp)
            if (r.pid == null) GlassIconButton("share", tr("cm.share"), { shareShot(app, it) }, iconSize = 20.dp)
            GlassIconButton("more", "menu", { app.sheet = if (r.pid == null) Sheet.ShotMenu else Sheet.ItemMenu(r.pid, ops.wid(r) ?: "", it.id) }, iconSize = 20.dp)
        }
        Box(Modifier.weight(1f).fillMaxWidth().background(if (ph) Color(0xFF0E1C36) else G.stage).padding(10.dp)) {
            Canvas(Modifier.fillMaxSize().pointerInput(it.id) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    if (app.sheet != null) return@awaitEachGesture
                    val item = cur
                    val box = Rect(0f, 0f, size.width.toFloat(), size.height.toFloat())
                    fun q(p: Offset): Offset { val o = mkToItem(item, box, p); return Offset(o.x.coerceIn(4f, item.W - 4f), o.y.coerceIn(4f, item.hh - 4f)) }
                    fun r1(v: Float) = (v * 10).roundToInt() / 10f
                    val t = ops.toolOf(item); val c = ops.colorOf(item)
                    val p0 = q(down.position)
                    val lab = if (t != "eraser" && t != "pen") mkLabelAt(item, p0, fmt) else null

                    var moved = 0f
                    val pts = ArrayList<List<Float>>().apply { add(listOf(r1(p0.x), r1(p0.y))) }
                    var b = p0
                    val hit = HashSet<String>()
                    var lastQ = p0
                    fun erase(x: Offset) { item.els.forEach { e -> if (e.id !in hit && mkNear(e, x)) hit.add(e.id) }; live.faded = hit.toSet() }
                    when (t) { "pen" -> live.pen = pts.toList(); "eraser" -> erase(p0) }
                    var ended = false
                    try {
                        while (true) {
                            val ev = awaitPointerEvent()
                            val ch = ev.changes.firstOrNull { x -> x.id == down.id } ?: break
                            if (!ch.pressed) { ended = true; break }
                            ch.consume()
                            moved = maxOf(moved, (ch.position - down.position).getDistance())

                            if (lab != null || t == "text") continue
                            val qq = q(ch.position)
                            when (t) {
                                "pen" -> { val l = pts.last(); if (hypot(qq.x - l[0], qq.y - l[1]) > 4f) { pts.add(listOf(r1(qq.x), r1(qq.y))); live.pen = pts.toList() } }
                                "line", "dim", "arrow" -> { b = snapAngle(p0, qq, app.settings.angleSnap); live.line = listOf(p0.x, p0.y) to listOf(b.x, b.y) }
                                "eraser" -> { val n = maxOf(1, (hypot(qq.x - lastQ.x, qq.y - lastQ.y) / 12f).toInt()); for (i in 1..n) erase(lastQ + (qq - lastQ) * (i / n.toFloat())); lastQ = qq }
                            }
                        }
                    } finally {
                        live.pen = null; live.line = null; live.faded = emptySet()
                    }
                    if (!ended) return@awaitEachGesture
                    val tap = moved < 12f * density
                    when {
                        lab != null -> if (tap) { if (lab.t == "text") openText(app, lab, null) else openDim(app, lab) }
                        t == "text" -> if (tap) openText(app, null, p0)
                        t == "pen" -> ops.change(r) { it + MkEl(uid(), "pen", pts.toList(), c, ops.width) }
                        t == "eraser" -> if (hit.isNotEmpty()) ops.change(r) { it.filter { e -> e.id !in hit } }
                        else -> if (hypot(b.x - p0.x, b.y - p0.y) >= 30f) {
                            val el = MkEl(uid(), t, listOf(listOf(r1(p0.x), r1(p0.y)), listOf(r1(b.x), r1(b.y))), c)
                            ops.change(r) { it + el }
                            if (t != "arrow") openDim(app, el)
                        }
                    }
                                }
            }) {
                val box = Rect(Offset.Zero, size)
                drawMarkup(it, photo, box, fmt, tm, MkMode.EDIT, faded = live.faded) {
                    val cc = MK_COL[col] ?: MK_COL.getValue("ink")
                    live.pen?.let { ps ->
                        val path = Path().apply { (if (ps.size > 1) ps else listOf(ps[0], listOf(ps[0][0] + .1f, ps[0][1]))).forEachIndexed { i, q -> if (i == 0) moveTo(q[0], q[1]) else lineTo(q[0], q[1]) } }
                        drawPath(path, cc, style = Stroke(if (ops.width == 2) 18f else 8f, cap = StrokeCap.Round, join = StrokeJoin.Round))
                    }
                    live.line?.let { (a, b) -> drawLine(cc, Offset(a[0], a[1]), Offset(b[0], b[1]), 7f, StrokeCap.Round, PathEffect.dashPathEffect(floatArrayOf(14f, 10f))) }
                }
            }
        }
        if (ph) Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).background(G.sheet(.8f)).drawBehind { drawLine(G.ink.copy(alpha = .08f), Offset.Zero, Offset(size.width, 0f), 1.dp.toPx()) }
            .clickable { app.sheet = Sheet.MkCaption }.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("edit", G.ink2, 18.dp, 2f)
            Text(if (it.caption.isNotBlank()) dn(it.caption, lang) else tr("mk.addCaption"), style = ui(14f, 400, if (it.caption.isNotBlank()) G.ink else G.ink3), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        }
        // colours, pen width and what the tool does (prototype .mk-opts)
        Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).background(G.sheet(.8f)).drawBehind { drawLine(G.ink.copy(alpha = .08f), Offset.Zero, Offset(size.width, 0f), 1.dp.toPx()) }
            .padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (tool != "eraser") {
                listOf("ink", "cobalt", "red").forEach { k ->
                    val on = col == k; val cc = MK_COL.getValue(k)
                    Box(Modifier.size(44.dp).drawBehind {
                        val rr = 17.dp.toPx()
                        if (on) drawCircle(cc, rr + 4.dp.toPx()) else drawCircle(G.ink.copy(alpha = .15f), rr + 3.dp.toPx())
                        drawCircle(G.solid, rr + 2.dp.toPx()); drawCircle(cc, rr)
                    }.clip(CircleShape).clickable(role = Role.RadioButton) { ops.setColor(it, k) }, contentAlignment = Alignment.Center) {
                        if (on) MIcon("check", Color.White, 16.dp, 2.6f)
                    }
                }
                if (tool == "pen") Row(Modifier.clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp)) {
                    listOf(1 to "mk.thin", 2 to "mk.thick").forEach { (k, l) ->
                        val on = ops.width == k
                        Box(Modifier.heightIn(min = 38.dp).clip(RoundedCornerShape(9.dp)).background(if (on) G.solid else Color.Transparent).clickable { ops.width = k }.padding(horizontal = 10.dp), contentAlignment = Alignment.Center) {
                            Text(tr(l), style = ui(13f, if (on) 600 else 500, if (on) G.ink else G.ink2))
                        }
                    }
                }
            }
            Text(tr("mk.h.$tool"), style = ui(12f, 400, G.ink3, 1.3f), modifier = Modifier.weight(1f), maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
        MkTools(it, tool)
    }
}

/** Straight lines snap to every 45° when angle snapping is on (prototype snap). */
private fun snapAngle(a: Offset, b: Offset, on: Boolean): Offset {
    if (!on) return b
    val dx = b.x - a.x; val dy = b.y - a.y; val l = hypot(dx, dy); val ang = atan2(dy, dx); val st = (Math.PI / 4).toFloat()
    val k = (ang / st).roundToInt() * st
    return if (kotlin.math.abs(ang - k) < .14f) Offset(a.x + cos(k) * l, a.y + sin(k) * l) else b
}

private fun openDim(app: App, e: MkEl) {
    app.mk.recv = null; app.mk.laserText = if (e.src == "laser" && e.v != null) fmtLen(e.v, app.settings.unit, app.settings.lang == Lang.EN, full = true) else null
    app.sheet = Sheet.MkDim(e.id)
}
private fun openText(app: App, e: MkEl?, p: Offset?) { app.sheet = Sheet.MkText(e?.id, p?.x ?: 0f, p?.y ?: 0f) }

@Composable
private fun MkTools(it: Item, tool: String) {
    val app = LocalApp.current
    val haze = LocalHaze.current
    val shape = RoundedCornerShape(33.dp)
    Row(
        Modifier.padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 12.dp).fillMaxWidth().height(66.dp)
            .dropShadow(shape, Shadow(30.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, (-10).dp)))
            .clip(shape).glassBlur(haze, G.sheet(.5f), 28.dp).topHighlight(.95f).border(1.dp, G.rim, shape).padding(6.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        (MK_TOOLS[it.kind] ?: emptyList()).forEach { k ->
            val on = tool == k; val bubble = RoundedCornerShape(27.dp)
            Column(
                Modifier.weight(1f).fillMaxHeight().let { m -> if (on) m.dropShadow(bubble, Shadow(12.dp, G.shade.copy(alpha = .12f), offset = DpOffset(0.dp, 4.dp))) else m }
                    .clip(bubble).background(if (on) G.glass(.9f) else Color.Transparent).clickable(role = Role.Tab) { app.mk.setTool(it, k) },
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically)
            ) {
                MIcon(k, if (on) G.cobalt2 else G.slate, 22.dp, 2f)
                Text(tr("mk.$k"), style = ui(11f, if (on) 700 else 600, if (on) G.cobalt2 else G.slate), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun MarkupSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.MkDim -> DimSheet(s)
        is Sheet.MkText -> TextSheet(s)
        Sheet.MkCaption -> CaptionSheet()
        Sheet.ShotMenu -> ShotMenuSheet()
        Sheet.ShotDel -> ShotDelSheet()
        Sheet.ShotTo -> ShotToSheet()
        Sheet.CameraPick -> CameraPickSheet()
        else -> return false
    }
    return true
}

private fun App.mkRoute() = top as? Route.Markup

/** A line's length (prototype SHEETS.mkDim): from the laser when it is connected, or typed. */
@Composable
private fun DimSheet(s: Sheet.MkDim) {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    val r = app.mkRoute() ?: run { app.sheet = null; return }
    val it = app.mk.item(r) ?: run { app.sheet = null; return }
    val e = it.els.firstOrNull { x -> x.id == s.eid } ?: run { app.sheet = null; return }
    var v by rememberSaveable(s.eid) { mutableStateOf(if (e.v != null) fmtLen(e.v, app.settings.unit, en, full = true) else "") }
    var tried by remember { mutableStateOf(false) }
    val parsed = lenErr(v, dimMax("A"), app.settings.unit, en)
    val focus = remember { FocusRequester() }
    val on = app.settings.laser == Laser.CONNECTED
    LaunchedEffect(Unit) { if (!on) { kotlinx.coroutines.delay(300); runCatching { focus.requestFocus() } } }
    fun save() {
        val ok = parsed as? Parsed.Ok
        if (v.isBlank() || ok == null) { tried = true; return }
        val src = if (app.mk.laserText != null && app.mk.laserText == v.trim()) "laser" else "manual"
        app.mk.change(r) { els -> els.map { x -> if (x.id == e.id) x.copy(v = ok.value.toInt(), src = src) else x } }
        app.sheet = null
    }
    GlassSheet(tr("mk.dimT"), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("mk.later"), { app.sheet = null }, Btn.SECONDARY, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), { save() }, enabled = v.isNotBlank() && parsed is Parsed.Ok, modifier = Modifier.weight(1f))
        }
    }) {
        val recv = app.mk.recv
        when {
            !on -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("btoff", G.ink2, 18.dp, 2f); Text(tr("mk.noLaser"), style = ui(13.5f, 400, G.ink2, 1.4f), modifier = Modifier.weight(1f)) }
            recv != null -> Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(G.amberWash).drawBehind { drawRect(G.amberInk, size = Size(3.dp.toPx(), size.height)) }
                .padding(start = 12.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MIcon("laser", G.amberInk, 18.dp, 2f)
                Text(tr("mk.recv", "v" to "") + fmtLen(recv, app.settings.unit, en, full = true) + " " + app.unitName(), style = ui(14f, 600), modifier = Modifier.weight(1f))
                GBtn(tr("mk.use"), { val t = fmtLen(recv, app.settings.unit, en, full = true); v = t; app.mk.laserText = t; app.mk.recv = null }, fill = false, height = 44.dp, fontSize = 14f)
            }
            else -> GBtn(tr("mk.laser"), {
                val base = e.v ?: (800 + Random.nextInt(3401))
                app.mk.recv = maxOf(50, base + ((Random.nextFloat() - .5f) * (if (e.v != null) 6 else 40)).roundToInt())
            }, Btn.SECONDARY, icon = "laser")
        }
        NumField(tr("mk.value"), v, { v = it }, app.unitName(), if (v.isBlank()) null else errText(parsed), tried || v.isNotBlank(), imeAction = ImeAction.Done, onIme = { save() }, focusRequester = focus)
        if (it.kind == "photo") Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("info", G.ink2, 18.dp, 2f); Text(tr("mk.photoNote"), style = ui(13f, 400, G.ink2, 1.4f), modifier = Modifier.weight(1f)) }
        Row(Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).clickable { app.mk.change(r) { els -> els.filter { x -> x.id != e.id } }; app.sheet = null }.padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            MIcon("trash", G.err, 18.dp, 2f); Text(tr("mk.delLine"), style = ui(15f, 600, G.err))
        }
    }
}

/** A text mark: new at the tapped point, or changed (prototype SHEETS.mkText). Empty text removes it. */
@Composable
private fun TextSheet(s: Sheet.MkText) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val r = app.mkRoute() ?: run { app.sheet = null; return }
    val it = app.mk.item(r) ?: run { app.sheet = null; return }
    val e = s.eid?.let { id -> it.els.firstOrNull { x -> x.id == id } }
    var v by rememberSaveable(s.eid) { mutableStateOf(e?.txt?.let { dn(it, lang) } ?: "") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(300); runCatching { focus.requestFocus() } }
    fun save() {
        val t = v.trim()
        if (e != null) app.mk.change(r) { els -> if (t.isEmpty()) els.filter { x -> x.id != e.id } else els.map { x -> if (x.id == e.id) x.copy(txt = if (dn(x.txt ?: "", lang) == t) x.txt else t) else x } }
        else if (t.isNotEmpty()) app.mk.change(r) { els -> els + MkEl(uid(), "text", listOf(listOf(s.x, s.y)), app.mk.colorOf(it), txt = t) }
        app.sheet = null
    }
    GlassSheet(tr("mk.textT"), { app.sheet = null }, footer = { GBtn(tr("common.save"), { save() }) }) {
        GField(tr("mk.textT"), v, { v = it }, placeholder = tr("mk.textPh"), imeAction = ImeAction.Done, onIme = { save() }, focusRequester = focus)
        if (e != null) Row(Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).clickable { app.mk.change(r) { els -> els.filter { x -> x.id != e.id } }; app.sheet = null }.padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            MIcon("trash", G.err, 18.dp, 2f); Text(tr("mk.delText"), style = ui(15f, 600, G.err))
        }
    }
}

@Composable
private fun CaptionSheet() {
    val app = LocalApp.current
    val lang = LocalLang.current
    val r = app.mkRoute() ?: run { app.sheet = null; return }
    val it = app.mk.item(r) ?: run { app.sheet = null; return }
    var v by rememberSaveable { mutableStateOf(dn(it.caption, lang)) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(300); runCatching { focus.requestFocus() } }
    fun save() { val t = v.trim(); app.mk.update(r) { x -> x.copy(caption = if (dn(x.caption, lang) == t) x.caption else t) }; app.sheet = null }
    GlassSheet(tr("mk.caption"), { app.sheet = null }, footer = { GBtn(tr("common.save"), { save() }) }) {
        GField(tr("mk.caption"), v, { v = it }, placeholder = tr("mk.captionPh"), imeAction = ImeAction.Done, onIme = { save() }, focusRequester = focus)
    }
}

/* ---------------- the Measure page's pictures ---------------- */

/** "Kamera" on the Measure page: the live camera, or a photo to draw on (prototype SHEETS.camPick). */
@Composable
private fun CameraPickSheet() {
    val app = LocalApp.current
    GlassSheet(tr("cm.pickT"), { app.sheet = null }) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(bottom = 6.dp)) {
            uz.metrx.app.ui.projects.BigRow("laser", "cm.live", "cm.liveD") { app.sheet = null; app.push(Route.LiveCam) }
            uz.metrx.app.ui.projects.BigRow("camera", "cm.photo", "cm.photoD") { app.sheet = null; app.mk.launch?.invoke(PhotoTarget(null, null), true) }
        }
    }
}

@Composable
private fun ShotMenuSheet() {
    val app = LocalApp.current
    val lang = LocalLang.current
    val r = app.mkRoute() ?: run { app.sheet = null; return }
    val it = app.mk.item(r) ?: run { app.sheet = null; return }
    GlassSheet(dn(it.name, lang), { app.sheet = null }) {
        ListBox {
            ActionRow("share", tr("cm.share"), { app.sheet = null; shareShot(app, it) })
            Hairline()
            ActionRow("layers", tr("cm.toProj"), { app.sheet = Sheet.ShotTo })
            Hairline()
            ActionRow("trash", tr("cm.del"), { app.sheet = Sheet.ShotDel }, danger = true)
        }
    }
}

@Composable
private fun ShotDelSheet() {
    val app = LocalApp.current
    val r = app.mkRoute() ?: run { app.sheet = null; return }
    GlassSheet(tr("cm.delQ"), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("common.cancel"), { app.sheet = null }, Btn.SECONDARY, modifier = Modifier.weight(1f))
            GBtn(tr("cm.del"), {
                app.settings.saveShots(app.settings.shots.filter { x -> x.id != r.iid })
                app.sheet = null; app.pop(); app.say("cm.deleted")
            }, Btn.DANGER, icon = "trash", modifier = Modifier.weight(1f))
        }
    }) { Text(tr("cm.delB"), style = ui(15f, 400, G.ink2, 1.45f)) }
}

/** Into a project: the picture becomes an ordinary photo of that workspace, so it can also go into the PDF. */
@Composable
private fun ShotToSheet() {
    val app = LocalApp.current
    val lang = LocalLang.current
    val r = app.mkRoute() ?: run { app.sheet = null; return }
    val rows = app.store.projects.flatMap { p -> p.floors.map { p to it } }
    GlassSheet(tr("cm.toT"), { app.sheet = null }) {
        if (rows.isEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("info", G.ink2, 18.dp, 2f); Text(tr("cm.toNone"), style = ui(14f, 400, G.ink2, 1.4f), modifier = Modifier.weight(1f)) }
        else ListBox {
            rows.forEachIndexed { i, (p, w) ->
                if (i > 0) Hairline()
                Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clickable {
                    val it = app.settings.shots.firstOrNull { x -> x.id == r.iid } ?: return@clickable
                    app.settings.saveShots(app.settings.shots.filter { x -> x.id != it.id })
                    app.store.update(p.id) { pp -> pp.copy(floors = pp.floors.map { f -> if (f.id == w.id) f.copy(items = f.items + it.copy(edited = System.currentTimeMillis(), rep = null)) else f }) }
                    app.sheet = null; app.pop(); app.say("cm.moved", "w" to floorName(w, lang))
                }.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(36.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .12f)), contentAlignment = Alignment.Center) { MIcon("layers", G.cobalt, 20.dp, 2f) }
                    Column(Modifier.weight(1f)) { Text(floorName(w, lang), style = ui(15.5f, 600)); Text(dn(p.name, lang), style = ui(13f, 400, G.ink2)) }
                    MIcon("chev", G.ink3, 18.dp, 2f)
                }
            }
        }
    }
}

/** The picture with its lines and numbers as one JPEG, through the phone's share sheet (prototype shotShare). */
fun shareShot(app: App, it: Item) {
    val ctx = app.ctx
    runCatching {
        val bmp = mkBitmap(ctx, app, it)
        val dir = File(ctx.cacheDir, "share").apply { mkdirs(); listFiles()?.forEach { f -> f.delete() } }
        val name = "METRX_" + dn(it.name, app.settings.lang).replace(Regex("[\\s,№./\\\\:*?\"<>|]+"), "_") + ".jpg"
        val f = File(dir, name)
        f.outputStream().use { o -> bmp.asAndroidBitmap().compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, o) }
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".files", f)
        val send = Intent(Intent.ACTION_SEND).apply { type = "image/jpeg"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
        ctx.startActivity(Intent.createChooser(send, dn(it.name, app.settings.lang)).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }.onFailure { app.say("cm.shareErr", kind = uz.metrx.app.ui.components.ToastKind.INFO) }
}

/** The item drawn at up to 1600 px on its long side (twice its units at most). */
private fun mkBitmap(ctx: Context, app: App, it: Item): ImageBitmap {
    val k = minOf(2f, 1600f / maxOf(it.W, it.hh))
    val w = (it.W * k).roundToInt(); val h = (it.hh * k).roundToInt()
    val img = ImageBitmap(w, h)
    val photo = it.src?.let { s -> PhotoFiles.load(ctx, s)?.asImageBitmap() }
    val tm = uz.metrx.app.report.reportMeasurer(ctx)
    val l = app.settings.lang
    val f = MkFmt(app.settings.unit, l == Lang.EN, app.unitName(), l, if (l.cyrillic) uz.metrx.app.ui.theme.Manrope else uz.metrx.app.ui.theme.Jakarta)
    CanvasDrawScope().draw(Density(1f), LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(img), Size(w.toFloat(), h.toFloat())) {
        drawRect(Color.White)
        uz.metrx.app.ui.theme.Theme.onPaper { drawMarkup(it, photo, Rect(0f, 0f, w.toFloat(), h.toFloat()), f, tm, MkMode.REPORT) }
    }
    return img
}

