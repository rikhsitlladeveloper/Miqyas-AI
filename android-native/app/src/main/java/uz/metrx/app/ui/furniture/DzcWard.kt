package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Fronts
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.SK
import uz.metrx.app.furniture.SecFill
import uz.metrx.app.furniture.Section
import uz.metrx.app.furniture.Slot
import uz.metrx.app.furniture.W_SNAPS
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.boardFor
import uz.metrx.app.furniture.candidates
import uz.metrx.app.furniture.clearOwnFronts
import uz.metrx.app.furniture.colourOf
import uz.metrx.app.furniture.equalSplit
import uz.metrx.app.furniture.frontOf
import uz.metrx.app.furniture.handleFronts
import uz.metrx.app.furniture.handleType
import uz.metrx.app.furniture.hasHandle
import uz.metrx.app.furniture.hingeRight
import uz.metrx.app.furniture.legsOf
import uz.metrx.app.furniture.maxW
import uz.metrx.app.furniture.moveOrder
import uz.metrx.app.furniture.outerH
import uz.metrx.app.furniture.resize
import uz.metrx.app.furniture.secCopy
import uz.metrx.app.furniture.secDelete
import uz.metrx.app.furniture.secFill
import uz.metrx.app.furniture.secFrontOf
import uz.metrx.app.furniture.secType
import uz.metrx.app.furniture.snapWidth
import uz.metrx.app.furniture.softAll
import uz.metrx.app.furniture.softOf
import uz.metrx.app.furniture.wardBase
import uz.metrx.app.furniture.wardInnerH
import uz.metrx.app.furniture.withFill
import uz.metrx.app.furniture.withHandle
import uz.metrx.app.furniture.withHandleType
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withSecCount
import uz.metrx.app.furniture.withSecOrder
import uz.metrx.app.furniture.withSecType
import uz.metrx.app.furniture.withSecWidths
import uz.metrx.app.furniture.withSoft
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.editor.AMBER
import uz.metrx.app.ui.editor.COB
import uz.metrx.app.ui.editor.RED
import uz.metrx.app.ui.editor.roomGrid
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * Designer C v2 for every cabinet on the wardrobe engine (wardrobe and kupe, gorka and stenka, vitrina, komod, bathroom
 * and kids' pieces, approved 27 Oct 2026): the box's front, its sections edited on the drawing (tap, a second tap a door,
 * the edge dragged, held to move, the red zone deletes), the same slider and options. A piece of several boxes picks
 * its box over the drawing, as a kitchen its wall. The rules: Wardrobe.kt, RowEdit.kt, DesignEdit.kt.
 */

/** Sections' widths snap from 300 (the founder's snaps). */
private val SEC_SNAPS = W_SNAPS.filter { it >= 300 }

private fun secSlots(m: Module) = m.sections.mapIndexed { i, s -> Slot("$i", s.w, SK.MOD, SEC_SNAPS) }

/** What a finger is doing on a wardrobe's drawing. */
sealed interface WDrag {
    data class Resize(val i: Int, val row0: List<Slot>, val w0: Int, val mx: Int, val cands: List<Int>, val nw: Int, val res: uz.metrx.app.furniture.Resized?, val x0: Int) : WDrag
    data class Move(val from: Int, val grab: Int, val ghost: Int, val order: List<Slot>, val at: Int, val overDel: Boolean) : WDrag
}

internal class WardCtl {
    var drag by mutableStateOf<WDrag?>(null)
    var press by mutableStateOf<Offset?>(null)
    var panel = Rect.Zero
    var canvas = Rect.Zero
    lateinit var app: App
    lateinit var p: Project
    private val fS = mutableStateOf<Furniture?>(null)
    var f: Furniture get() = fS.value!!; set(v) { fS.value = v }
    private val mS = mutableStateOf<Module?>(null)
    var m: Module get() = mS.value!!; set(v) { mS.value = v }
    lateinit var ws: Workshop
    lateinit var st: DzcState
    private val layS = mutableStateOf<KLay?>(null)
    var lay: KLay get() = layS.value!!; set(v) { layS.value = v }
    private val viewS = mutableStateOf<DzcView?>(null)
    var view: DzcView get() = viewS.value!!; set(v) { viewS.value = v }
    var density = 1f

    fun mmX(p: Offset) = lay.mmX(view.v(p).x)
    fun mmY(p: Offset) = lay.mmY(view.v(p).y)
    fun sx(mm: Int) = view.sx(lay.x(mm))
    fun sy(mm: Int) = view.sy(lay.y(mm))
    /** Where section [i] starts, mm from the box's left. */
    fun secX(i: Int) = m.sections.take(i).sumOf { it.w }
    fun secAt(p: Offset): Int? {
        val x = mmX(p); val y = mmY(p)
        if (y < -80 || y > outerH(m, ws) + 60) return null
        var a = 0
        m.sections.forEachIndexed { i, s -> if (x >= a && x < a + s.w) return i; a += s.w }
        return null
    }
    val selSec get() = st.sel?.id?.removePrefix("s")?.toIntOrNull()?.takeIf { it in m.sections.indices }
    /** The fronts of section [i] on the drawing, left to right (drawers top down). */
    fun fronts(i: Int) = wardFrontBoxes(m.copy(x = 0, elev = 0), ws).filter { it.f.sec == i }
    fun frontAt(i: Int, p: Offset): Int? {
        val x = mmX(p); val y = mmY(p)
        return fronts(i).indexOfFirst { b -> x >= b.x0 - 3 && x <= b.x1 + 3 && y >= b.y0 - 3 && y <= b.y1 + 3 }.takeIf { it >= 0 }
    }
}

/* ---------------- the screen ---------------- */

@Composable
fun WardrobeScreen(rt: Route.Wardrobe) {
    val app = LocalApp.current
    val kit = app.kit
    @Suppress("UNUSED_VARIABLE") val tick = kit.tick
    val p = app.store.get(rt.pid) ?: return
    val f = p.furniture.firstOrNull { it.id == rt.fid } ?: return
    // a bed, a table, a bar counter or a mirror panel: its short designer, with the same slider
    if (uz.metrx.app.furniture.isItemPiece(f) && rt.mod == null) { ItemScreen(rt, p, f); return }
    val m = rt.mod?.let { id -> f.modules.firstOrNull { it.id == id && it.type == "wardrobe" } } ?: app.curWard(f) ?: return
    val ws = app.settings.workshop
    val cx = WardCtx(p, f, m, ws, app.settings.angleSnap)
    val st = app.dzc(f.id)
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize()) {
            uz.metrx.app.ui.ux.DesignerTop(p, f, wardHeadSub(f, m, ws)) { st.teach = true }
            val room = cx.room
            if (room == null) Text(tr("kt.roomLost"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.weight(1f).padding(24.dp))
            else Box(Modifier.weight(1f).fillMaxWidth()) { WardEditor(rt, p, f, m, room, cx, st) }
            uz.metrx.app.ui.ux.DesignerBar(p, f, rt.d3) { app.setTop(rt.copy(d3 = it)) }
        }
    }
}

@Composable
private fun WardEditor(rt: Route.Wardrobe, p: Project, f: Furniture, m: Module, room: Room, cx: WardCtx, st: DzcState) {
    val app = LocalApp.current
    val mats = app.settings.mats
    val ws = app.settings.workshop
    val c = remember { WardCtl() }
    val d = LocalDensity.current
    val tm = rememberTextMeasurer()
    var panelH by remember { mutableIntStateOf(0) }
    c.app = app; c.p = p; c.f = f; c.m = m; c.ws = ws; c.st = st; c.density = d.density
    if (st.sel != null && c.selSec == null) st.clear()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wPx = constraints.maxWidth.toFloat(); val hPx = constraints.maxHeight.toFloat()
        val many = f.modules.count { it.type == "wardrobe" } > 1 || f.type == "stenka"
        val topPx = with(d) { (if (many) 100.dp else 56.dp).toPx() }
        val lay = KLay(m.w, outerH(m, ws), 360f, true, m.w, st.z, st.px, st.py)
        val view = dzcFit(lay.vw, lay.vh, wPx, hPx, topPx, max(panelH.toFloat(), with(d) { 172.dp.toPx() }) + with(d) { 10.dp.toPx() })
        c.lay = lay; c.view = view
        if (rt.d3) DzcWard3D(p, room, f, c)
        else {
            val shown = wShown(c)
            val front = boardColor(mats, f.mats.front); val carcass = boardColor(mats, f.mats.carcass, "#F5F5F2")
            val open = when { st.inside -> m.sections.indices.toSet(); st.peek != null -> setOfNotNull(st.peek?.removePrefix("s")?.toIntOrNull()); else -> emptySet() }
            Canvas(Modifier.fillMaxSize().onGloballyPositioned { c.canvas = it.boundsInRoot() }.pointerInput(Unit) { dzcGestures(WardGestures(c)) }) {
                withTransform({ translate(view.ox, view.oy); scale(view.u, view.u, pivot = androidx.compose.ui.geometry.Offset.Zero) }) {
                    drawLine(uz.metrx.app.ui.editor.INK, Offset(lay.x0 - 10f, lay.yF), Offset(lay.x(m.w) + 10f, lay.yF), 2f)
                    val sel = if (st.sel?.front == null && !st.multi && c.drag !is WDrag.Move) c.selSec ?: -1 else -1
                    drawWard(lay, shown.copy(x = 0, elev = 0), 0, ws, carcass, front, sel, !st.inside, if (c.drag == null) cx.bad else emptyMap(), tm,
                        uz.metrx.app.furniture.opensByEdge(f), { id -> boardColor(mats, id) }, open)
                    var acc = 0
                    wardDims(lay, listOf(0) + shown.sections.map { s -> acc += s.w; acc }, shown.w, outerH(shown, ws), 0, tm)
                    wOverlay(c, shown)
                }
            }
            PressRing(c.press)
            wBubbles(c, shown)
        }
        if (many) BoxChips(p, f, m)
        Box(Modifier.fillMaxWidth().padding(top = if (many) 44.dp else 0.dp)) { WCaption(c) }
        if (!st.fit && !rt.d3) ZoomPill(st.z, with(d) { (panelH + 14).toDp() }) { st.fitNow() }
        DzcPanel({ c.panel = it }, { panelH = it }) {
            when {
                c.drag is WDrag.Move -> DelZone((c.drag as WDrag.Move).overDel)
                st.strip != null -> WardOptions(c, cx, st.strip!!)
                else -> ToolSlider(wardTools(c, cx.found.count { it.level != "ok" })) { k -> wTool(c, k) }
            }
        }
        if (st.teach) TeachHint { st.teach = false }
    }
}

/** A piece of several boxes: which one the drawing shows ("1 · Shkaf 1200"). */
@Composable
private fun BoxChips(p: Project, f: Furniture, cur: Module) {
    val app = LocalApp.current
    val st = app.dzc(f.id)
    FadeRow(f.modules.size, Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 6.dp)) {
        f.modules.filter { it.type == "wardrobe" }.forEachIndexed { i, b ->
            val on = b.id == cur.id
            Row(Modifier.padding(end = 6.dp).heightIn(min = 36.dp).clip(CircleShape).background(if (on) G.ink else G.sheet(.85f)).border(1.dp, if (on) G.ink else G.rim, CircleShape)
                .semantics { selected = on }.clickable(role = Role.Tab) { if (!on) { app.kit.sel = b.id; app.kit.tick++; st.clear(); st.fitNow() } }.padding(horizontal = 12.dp),
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                Text("${i + 1} · " + tr(uz.metrx.app.furniture.boxRole(f, b)) + " ${b.w}", style = ui(13f, 700, if (on) G.solid else G.ink), maxLines = 1)
            }
        }
    }
}

/** The box as drawn now: a drag's preview. */
private fun wShown(c: WardCtl): Module = when (val dr = c.drag) {
    is WDrag.Resize -> dr.res?.takeIf { it.ok }?.let { r -> withSecWidths(c.m, r.row.map { it.w }) } ?: c.m
    is WDrag.Move -> withSecOrder(c.m, dr.order.map { it.id.toInt() })
    null -> c.m
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.wOverlay(c: WardCtl, m: Module) {
    val lay = c.lay; val st = c.st
    val z0 = legsOf(m, c.ws); val top = z0 + m.h
    val sel = c.selSec
    (c.drag as? WDrag.Resize)?.res?.aid?.toIntOrNull()?.let { a ->
        val x = m.sections.take(a).sumOf { it.w }; val w = m.sections[a].w
        drawRect(AMBER.copy(alpha = .2f), Offset(lay.x(x), lay.y(top)), Size(w * lay.s, m.h * lay.s)); drawRect(AMBER, Offset(lay.x(x), lay.y(top)), Size(w * lay.s, m.h * lay.s), style = Stroke(1.6f))
    }
    if (sel != null && !st.multi && c.drag !is WDrag.Move) {
        val x = m.sections.take(sel).sumOf { it.w }; val w = m.sections[sel].w
        val fi = st.sel?.front
        if (fi != null) {
            drawRect(COB, Offset(lay.x(x) - 1f, lay.y(top) - 1f), Size(w * lay.s + 2f, m.h * lay.s + 2f), style = Stroke(1.4f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))))
            c.fronts(sel).getOrNull(fi)?.let { b -> drawRect(COB, Offset(lay.x(b.x0) - 1f, lay.y(b.y1) - 1f), Size((b.x1 - b.x0) * lay.s + 2f, (b.y1 - b.y0) * lay.s + 2f), style = Stroke(3f)) }
        } else if (sel < m.sections.lastIndex) {
            val hx = lay.x(x + w); val hy = lay.y(z0 + m.h / 2)
            drawRoundRect(COB, Offset(hx - 4f, hy - 13f), Size(8f, 26f), CornerRadius(4f))
            drawLine(Color.White, Offset(hx - 1.2f, hy - 5f), Offset(hx - 1.2f, hy + 5f), 1f); drawLine(Color.White, Offset(hx + 1.2f, hy - 5f), Offset(hx + 1.2f, hy + 5f), 1f)
        }
    }
    (c.drag as? WDrag.Resize)?.let { dr -> dr.cands.forEach { v -> val on = v == dr.nw; val tx = lay.x(dr.x0 + v); drawLine(if (on) COB else uz.metrx.app.ui.editor.GREY_LINE, Offset(tx, lay.yF + 2f), Offset(tx, lay.yF + if (on) 9f else 6f), if (on) 2f else 1f) } }
    (c.drag as? WDrag.Move)?.let { dr ->
        val s = c.m.sections[dr.from]
        val at = dr.order.take(dr.at).sumOf { it.w }
        drawRect(COB.copy(alpha = .12f), Offset(lay.x(at), lay.y(top)), Size(s.w * lay.s, m.h * lay.s))
        drawRect(Color.Black.copy(alpha = .1f), Offset(lay.x(dr.ghost) + 4f, lay.y(top) + 2f), Size(s.w * lay.s, m.h * lay.s))
        drawRect(COB.copy(alpha = .25f), Offset(lay.x(dr.ghost), lay.y(top) - 6f), Size(s.w * lay.s, m.h * lay.s))
        drawRect(if (dr.overDel) RED else COB, Offset(lay.x(dr.ghost), lay.y(top) - 6f), Size(s.w * lay.s, m.h * lay.s), style = Stroke(2.6f))
    }
    if (st.multi) m.sections.forEachIndexed { i, s ->
        val x = m.sections.take(i).sumOf { it.w }
        val on = "s$i" in st.ticks
        val cx = lay.x(x) + 10f; val cy = lay.y(top) + 10f
        if (on) drawRect(COB, Offset(lay.x(x) - 1.5f, lay.y(top) - 1.5f), Size(s.w * lay.s + 3f, m.h * lay.s + 3f), style = Stroke(2.4f))
        drawCircle(if (on) COB else Color.White, 7f, Offset(cx, cy)); drawCircle(COB, 7f, Offset(cx, cy), style = Stroke(1.2f))
        if (on) { drawLine(Color.White, Offset(cx - 3f, cy), Offset(cx - .8f, cy + 2.4f), 1.4f); drawLine(Color.White, Offset(cx - .8f, cy + 2.4f), Offset(cx + 3.2f, cy - 2.4f), 1.4f) }
    }
}

@Composable
private fun androidx.compose.foundation.layout.BoxScope.wBubbles(c: WardCtl, m: Module) {
    val st = c.st
    val sel = c.selSec ?: return
    if (st.multi || st.sel?.front != null || c.drag is WDrag.Move) return
    val d = LocalDensity.current
    val x = m.sections.take(sel).sumOf { it.w }; val w = m.sections[sel].w
    val live = c.drag is WDrag.Resize
    Bubble("${w} " + tr("u.mm"), c.sx(x + w / 2), c.sy(0) + with(d) { 6.dp.toPx() }, live = live) { c.app.sheet = Sheet.DzcNum(c.p.id, c.f.id, c.m.id, "w", sel) }
    (c.drag as? WDrag.Resize)?.res?.aid?.toIntOrNull()?.let { a ->
        val ax = m.sections.take(a).sumOf { it.w }; val aw = m.sections[a].w
        Bubble(tr("dzc.secN", "n" to a + 1) + " ${c.m.sections[a].w} → $aw", c.sx(ax + aw / 2), c.sy(1300), amber = true)
    }
}

@Composable
private fun WCaption(c: WardCtl) {
    val st = c.st
    Box(Modifier.fillMaxWidth()) {
        if (st.multi) { DzcCaption(tr("dzc.multiN", "n" to st.ticks.size), tr("dzc.multiTapS"), { st.multi = false; st.ticks = emptySet(); st.strip = null }, multi = true); return@Box }
        val i = c.selSec ?: return@Box
        val s = c.m.sections[i]
        val fi = st.sel?.front
        val secName = tr("dzc.secN", "n" to i + 1)
        if (fi != null) DzcCaption(c.fronts(i).getOrNull(fi)?.let { frontName(c.m, it.f) } ?: tr("dzc.front"), "", { st.clear() }, up = secName, onUp = { st.sel = DSel("s$i"); st.strip = null })
        else DzcCaption("$secName · ${s.w} " + tr("u.mm"), tr(uz.metrx.app.furniture.boxRole(c.f, c.m)), { st.clear() })
    }
}

/* ---------------- gestures ---------------- */

private class WardGestures(val c: WardCtl) : DzcGestures {
    private val st get() = c.st
    private fun dp(v: Float) = v * c.density
    override fun handleAt(p: Offset): String? {
        if (st.multi || st.sel?.front != null) return null
        val i = c.selSec ?: return null
        if (i >= c.m.sections.lastIndex) return null
        val hx = c.sx(c.secX(i) + c.m.sections[i].w); val hy = c.sy(legsOf(c.m, c.ws) + c.m.h / 2)
        return if (abs(p.x - hx) < dp(22f) && abs(p.y - hy) < dp(34f)) "w" else null
    }
    override fun liftable(p: Offset) = !st.multi && c.m.sections.size > 1 && c.secAt(p) != null
    override fun tap(p: Offset) {
        val now = android.os.SystemClock.uptimeMillis()
        val (t0, x0, y0) = st.lastTap
        if (now - t0 < 320 && abs(p.x - x0) < dp(26f) && abs(p.y - y0) < dp(26f)) { st.lastTap = Triple(0L, 0f, 0f); doubleTap(); return }
        st.lastTap = Triple(now, p.x, p.y)
        val i = c.secAt(p)
        if (st.multi) { if (i != null) st.ticks = "s$i".let { k -> if (k in st.ticks) st.ticks - k else st.ticks + k }; return }
        if (i == null) { st.clear(); return }
        wPick(c, i, c.frontAt(i, p))
    }
    override fun doubleTap() { st.fitNow() }
    override fun pressStart(p: Offset) { c.press = p }
    override fun pressEnd() { c.press = null }
    override fun lift(p: Offset) {
        c.press = null
        val i = c.secAt(p) ?: return
        st.sel = DSel("s$i"); st.strip = null; st.peek = null
        c.app.haptic(Hap.TICK)
        val row = secSlots(c.m)
        c.drag = WDrag.Move(i, (c.mmX(p) - c.secX(i)).roundToInt(), c.secX(i), row, i, false)
    }
    override fun moveTo(p: Offset) {
        val dr = c.drag as? WDrag.Move ?: return
        val ghost = (c.mmX(p) - dr.grab).roundToInt()
        val (order, at) = moveOrder(secSlots(c.m), dr.from, ghost + c.m.sections[dr.from].w / 2.0)
        val over = c.panel.hits(p + Offset(c.canvas.left, c.canvas.top), dp(10f))
        if (over && !dr.overDel) c.app.haptic(Hap.WARN)
        c.drag = dr.copy(ghost = ghost, order = order, at = at, overDel = over)
    }
    override fun drop(cancel: Boolean) {
        val dr = c.drag as? WDrag.Move ?: return
        c.drag = null
        if (cancel) return
        if (dr.overDel) { wDelete(c, dr.from); return }
        val ord = dr.order.map { it.id.toInt() }
        if (ord == c.m.sections.indices.toList()) { c.app.haptic(Hap.TICK); return }
        c.app.ward(c.p.id, c.f.id) { withSecOrder(it, ord) }
        st.sel = DSel("s${dr.at}")
        c.app.dzcDone(c.p.id, c.f.id, c.app.t("dzc.secMoved", "n" to dr.from + 1, "a" to dr.at + 1))
    }
    override fun handleStart(kind: String, p: Offset) {
        val i = c.selSec ?: return
        val row = secSlots(c.m)
        val mx = maxW(row, i, secs = true)
        c.drag = WDrag.Resize(i, row, c.m.sections[i].w, mx, candidates(row[i], mx), c.m.sections[i].w, null, c.secX(i))
    }
    override fun handleTo(p: Offset) {
        val dr = c.drag as? WDrag.Resize ?: return
        val raw = (c.mmX(p) - dr.x0).toDouble()
        val nw = snapWidth(raw, dr.cands, st.fine, true, 150, dr.mx, dr.w0)
        c.drag = dr.copy(nw = nw, res = if (nw == dr.w0) null else resize(dr.row0, dr.i, nw, secs = true))
    }
    override fun handleEnd(cancel: Boolean) {
        val dr = c.drag as? WDrag.Resize ?: return
        c.drag = null
        if (cancel) return
        val r = dr.res?.takeIf { it.ok } ?: return
        c.app.ward(c.p.id, c.f.id) { withSecWidths(it, r.row.map { s -> s.w }) }
        c.app.dzcDone(c.p.id, c.f.id, c.app.t("dzc.secW", "n" to dr.i + 1, "a" to dr.w0, "b" to dr.nw) + (r.aid?.toIntOrNull()?.let { " · " + c.app.t("dzc.secN", "n" to it + 1) + " ${r.aw0} → ${r.aw1}" } ?: ""))
    }
    override fun pan(d: Offset) { st.px += d.x / c.view.u; st.py += d.y / c.view.u }
    override fun zoom(c0: Offset, f: Float) { st.zoomAt(c.view, c0, f) }
}

internal fun wPick(c: WardCtl, i: Int, front: Int?) {
    val st = c.st
    val cur = st.sel
    if (cur != null && cur.id == "s$i") {
        if (front != null && st.peek != "s$i" && !st.inside) { st.sel = DSel("s$i", if (cur.front == front) null else front); st.scope = "one"; if (st.strip != null && wardTools(c, 0).none { it.key == st.strip }) st.strip = null }
        return
    }
    st.pick(DSel("s$i"))
    if (st.strip != null && (st.strip in setOf("secs", "checks", "more", "size", "doors", "base", "parts") || wardTools(c, 0).none { it.key == st.strip })) st.strip = null
    if (st.peek != null) st.peek = if (st.strip == "in") "s$i" else null
    c.app.dzcFirstPick(st)
}

/* ---------------- the tools ---------------- */

internal fun wardTools(c: WardCtl, nIssues: Int): List<DTool> {
    val app = c.app; val st = c.st; val m = c.m; val f = c.f
    fun t(k: String, icon: String, badge: Int? = null, red: Boolean = false, pri: Boolean = false, on: Boolean = false) = DTool(k, app.t("dzc.tool.$k"), icon, badge, red, pri, on)
    val kupe = m.slide != null
    if (st.multi) return listOfNotNull(t("decor", "palette"), if (!kupe) t("handle", "handle") else null, if (!kupe) t("type", "doorT") else null, t("in", "shelves"),
        t("mdel", "trash", red = true), t("mdone", "chk", pri = true))
    val i = c.selSec
    if (i == null) return listOfNotNull(t("secs", "cols"), t("decor", "palette"), if (!kupe) t("handle", "handle") else null, t("see", "eye", on = st.inside),
        t("multi", "tick"), t("checks", "warn", badge = nIssues), t("size", "ruler"), if (f.type.isEmpty()) t("doors", "doorT") else null, t("base", "plinth"),
        if (f.modules.count { it.type == "wardrobe" } > 1 || f.type == "stenka") t("parts", "grid") else null, if (f.roomId != null) t("place", "room") else null, t("more", "sliders"))
    val s = m.sections[i]
    val doors = !kupe && s.fronts.kind == "door"
    if (st.sel?.front != null) {
        val fb = c.fronts(i).getOrNull(st.sel!!.front!!)
        return listOfNotNull(t("handle", "handle"), if (fb?.f?.drawer == false && s.fronts.n == 1) t("hinge", "hinge") else null, if (doors) t("soft", "soft") else null, t("selUp", "up"))
    }
    return listOfNotNull(if (m.sections.size > 1) t("width", "ruler") else null, t("in", "shelves"), t("decor", "palette"), if (!kupe) t("handle", "handle") else null,
        if (!kupe) t("type", "doorT") else null, t("copy", "copy"), if (doors) t("soft", "soft") else null, if (doors && s.fronts.n == 1) t("hinge", "hinge") else null,
        t("detail", "sliders"), if (m.sections.size > 1) t("del", "trash", red = true) else null)
}

internal fun wTool(c: WardCtl, k: String) {
    val st = c.st; val app = c.app
    val i = c.selSec
    when (k) {
        "multi" -> { st.multi = true; st.ticks = setOfNotNull(i?.let { "s$it" }); st.sel = null; st.strip = null; st.peek = null }
        "mdone" -> { st.multi = false; st.ticks = emptySet(); st.strip = null }
        "mdel" -> wDeleteMany(c)
        "see" -> { st.inside = !st.inside; app.haptic(Hap.TICK) }
        "copy" -> i?.let { wCopy(c, it) }
        "del" -> i?.let { wDelete(c, it) }
        "selUp" -> st.sel = st.sel?.copy(front = null)
        "detail" -> i?.let { app.sheet = Sheet.DzcMore(c.p.id, c.f.id, "inside:$it") }
        "more" -> app.sheet = Sheet.DzcMore(c.p.id, c.f.id, "ward")
        "place" -> app.sheet = Sheet.DzcMore(c.p.id, c.f.id, "place")
        else -> { st.strip = k; st.scope = "one"; st.peek = null; if (k == "in" && i != null) st.peek = "s$i" }
    }
}

/* ---------------- the actions ---------------- */

private fun wTargets(c: WardCtl): List<Int> = if (c.st.multi) c.st.ticks.mapNotNull { it.removePrefix("s").toIntOrNull() }.filter { it in c.m.sections.indices }.sorted() else listOfNotNull(c.selSec)

private fun wDelete(c: WardCtl, i: Int) {
    val app = c.app
    val ws = secDelete(c.m.sections.map { it.w }, i)
    if (ws == null) { app.dzcWarn(app.t("dzc.secLast")); return }
    app.ward(c.p.id, c.f.id) { m -> m.copy(sections = m.sections.filterIndexed { k, _ -> k != i }).let { x -> withSecWidths(x, ws) } }
    c.st.clear()
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.secDeleted", "n" to i + 1))
}

private fun wDeleteMany(c: WardCtl) {
    val app = c.app
    val ids = wTargets(c)
    if (ids.isEmpty()) { app.dzcWarn(app.t("dzc.tickFirst")); return }
    if (ids.size >= c.m.sections.size) { app.dzcWarn(app.t("dzc.secLast")); return }
    app.ward(c.p.id, c.f.id) { m ->
        var x = m
        ids.sortedDescending().forEach { i -> val w = secDelete(x.sections.map { it.w }, i) ?: return@forEach; x = withSecWidths(x.copy(sections = x.sections.filterIndexed { k, _ -> k != i }), w) }
        x
    }
    c.st.ticks = emptySet()
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.secDeletedN", "n" to ids.size))
}

private fun wCopy(c: WardCtl, i: Int) {
    val app = c.app
    val ws = secCopy(c.m.sections.map { it.w }, i)
    if (ws == null) { app.dzcWarn(app.t("dzc.secMax")); return }
    app.ward(c.p.id, c.f.id) { m -> m.copy(sections = m.sections.toMutableList().apply { add(i + 1, this[i]) }.mapIndexed { k, s -> s.copy(w = ws[k], lock = false) }) }
    c.st.sel = DSel("s${i + 1}")
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.secCopied", "n" to i + 1, "c" to ws.size, "w" to ws.first()))
}

private fun wSetCount(c: WardCtl, n: Int) {
    val app = c.app
    if (n == c.m.sections.size) return
    val o = c.m.sections.size
    app.ward(c.p.id, c.f.id) { withSecCount(it, n, app.settings.workshop) }
    c.st.clear()
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.secCount", "a" to o, "b" to n))
}

private fun wSetDecor(c: WardCtl, colour: String) {
    val app = c.app; val st = c.st
    val f = c.f
    val l = f.look
    val finish = l?.finish?.ifEmpty { null } ?: if (f.mats.front.startsWith("ag_")) "gloss" else "matte"
    val b = boardFor(colour, finish, l?.style ?: "flat")
    val name = frontName(app, colour)
    val ids = wTargets(c)
    if ((st.multi || (ids.isNotEmpty() && st.scope == "one")) && ids.isNotEmpty()) {
        app.ward(c.p.id, c.f.id) { m -> m.copy(sections = m.sections.mapIndexed { k, s -> if (k in ids) s.copy(front = b) else s }) }
        app.dzcDone(c.p.id, c.f.id, if (ids.size > 1) app.t("dzc.decorN", "d" to name, "n" to ids.size) else app.t("dzc.decorSec", "d" to name, "n" to ids.first() + 1))
        return
    }
    if (st.multi) { app.dzcWarn(app.t("dzc.tickFirst")); return }
    app.kit.change(app, c.p.id, c.f.id) { x -> clearOwnFronts(withLook(x) { it }).let { y -> y.copy(mats = y.mats.copy(front = b, frontUp = if (y.mats.frontUp != null) b else null)) } }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.decorAllW", "d" to name))
}

private fun wSetHandle(c: WardCtl, type: String) {
    val app = c.app; val st = c.st
    val ids = wTargets(c)
    val fi = st.sel?.front
    val name = app.t("dzc.h.$type")
    if ((st.multi || st.scope == "one") && ids.isNotEmpty()) {
        app.kit.change(app, c.p.id, c.f.id) { x ->
            val y = if (type != "push" && handleType(x) != type) withHandleType(x, type) else x
            y.copy(modules = y.modules.map { mm -> if (mm.id != c.m.id) mm else {
                val keys = handleFronts(mm).filter { it.sec in ids && !it.glass }.let { fr -> if (fi != null && !st.multi) c.fronts(ids.first()).getOrNull(fi)?.let { b -> listOf(b.f) } ?: emptyList() else fr }.map { it.key }
                keys.fold(mm) { a, k -> withHandle(a, k, type != "push") }
            } })
        }
        app.dzcDone(c.p.id, c.f.id, (if (fi != null) app.t("dzc.handleFrontW", "h" to name) else app.t("dzc.handleSec", "h" to name, "n" to ids.size)) +
            if (type != "push" && handleType(c.f) != type) " · " + app.t("dzc.handleTypeAll") else "")
        return
    }
    app.kit.change(app, c.p.id, c.f.id) { x -> withLook(withHandleType(x, type)) { it } }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.handleAllW", "h" to name))
}

private fun wSetType(c: WardCtl, k: String) {
    val app = c.app
    val ids = wTargets(c)
    if (ids.isEmpty()) { app.dzcWarn(app.t("dzc.secFirst")); return }
    app.ward(c.p.id, c.f.id) { m -> m.copy(sections = m.sections.mapIndexed { i, s -> if (i in ids) withSecType(s, k) else s }) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.secType", "t" to app.t("dzc.st.$k")) + if (ids.size > 1) " · " + app.t("dzc.nSecs", "n" to ids.size) else "")
}

private fun wSetDoors(c: WardCtl, n: Int) {
    val app = c.app
    val i = c.selSec ?: return
    app.changeSec(c.p.id, c.f.id, i) { s -> s.copy(fronts = Fronts("door", n), face = if (s.fronts.kind == "door") s.face else "") }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.doorsN", "n" to n))
}

private fun wFill(c: WardCtl, fn: (SecFill) -> SecFill, word: String) {
    val app = c.app
    val ids = wTargets(c)
    if (ids.isEmpty()) { app.dzcWarn(app.t("dzc.secFirst")); return }
    val t = app.settings.workshop.t
    app.ward(c.p.id, c.f.id) { m -> val ih = wardInnerH(m, t); m.copy(sections = m.sections.mapIndexed { i, s -> if (i in ids) withFill(s, fn(secFill(s)), ih, t) else s }) }
    app.dzcDone(c.p.id, c.f.id, word + if (ids.size > 1) " · " + app.t("dzc.nSecs", "n" to ids.size) else " · " + app.t("dzc.secN", "n" to ids.first() + 1))
}

private fun wSetHinge(c: WardCtl, side: String) {
    val app = c.app
    val i = c.selSec ?: return
    app.changeSec(c.p.id, c.f.id, i) { it.copy(hinge = side) }
    app.dzcDone(c.p.id, c.f.id, app.t(if (side == "L") "dzc.hingeL" else "dzc.hingeR", "m" to app.t("dzc.secN", "n" to i + 1)))
}

private fun wSetSoft(c: WardCtl, on: Boolean) {
    val app = c.app
    val i = c.selSec ?: return
    if (c.st.scope == "all") app.kit.change(app, c.p.id, c.f.id) { x -> x.copy(modules = x.modules.map { if (it.type == "wardrobe") softAll(it, on) else it }) }
    else app.ward(c.p.id, c.f.id) { withSoft(it, i, on) }
    app.dzcDone(c.p.id, c.f.id, app.t(if (on) "dzc.softOn" else "dzc.softOff") + " · " + if (c.st.scope == "all") app.t("dzc.toAll") else app.t("dzc.secN", "n" to i + 1))
}

/** Plinth, legs or hung on the wall, as the old size step did it: the whole height stays. */
private fun wSetBase(c: WardCtl, k: String) {
    val app = c.app
    val ws = app.settings.workshop
    val m = c.m
    val hung = uz.metrx.app.furniture.hung(m)
    val cur = when { hung -> "wall"; m.legs -> "legs"; else -> "plinth" }
    if (k == cur) return
    app.ward(c.p.id, c.f.id) { mm ->
        when (k) {
            "wall" -> { val e = maxOf(100, legsOf(mm, ws) + wardBase(mm)); mm.copy(legs = false, base = 0, elev = e, h = (outerH(mm, ws) - e).coerceAtLeast(300)) }
            else -> {
                val legs = if (k == "legs") ws.legH else 0
                val whole = if (uz.metrx.app.furniture.hung(mm)) mm.h + minOf(mm.elev, maxOf(100, uz.metrx.app.furniture.PLINTH, ws.legH)) else outerH(mm, ws)
                mm.copy(legs = k == "legs", base = null, elev = 0, h = (whole - legs).coerceAtLeast(300))
            }
        }
    }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.wbase", "t" to app.t("dzc.wb.$k")))
}

private fun wSetBaseH(c: WardCtl, x: Int) {
    val app = c.app
    val ws = app.settings.workshop
    app.ward(c.p.id, c.f.id) { mm -> if (mm.legs) mm.copy(base = x, h = (mm.h - (x - legsOf(mm, ws))).coerceAtLeast(300)) else mm.copy(base = x) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.wbaseH", "v" to x))
}

/* ---------------- the options ---------------- */

@Composable
private fun WardOptions(c: WardCtl, cx: WardCtx, k: String) {
    val app = c.app; val st = c.st; val m = c.m; val f = c.f
    val back = { st.strip = null; st.peek = null; st.scope = "one" }
    val i = c.selSec
    val s = i?.let { m.sections[it] }
    val fi = st.sel?.front
    val scopeTxt = when { st.multi -> if (st.ticks.isEmpty()) tr("dzc.tickFirst") else tr("dzc.nTickedS", "n" to st.ticks.size); i == null -> tr("dzc.wholeW"); fi != null -> tr("dzc.onlyF", "f" to (c.fronts(i).getOrNull(fi)?.let { frontName(m, it.f) } ?: "")); else -> tr("dzc.onlyS") }
    when (k) {
        "secs" -> OptRow(tr("dzc.tool.secs"), tr("dzc.secsSub"), back) {
            (1..6).forEach { n -> OptChip("$n · ${equalSplit(m.w, n).first()}", m.sections.size == n) { wSetCount(c, n) } }
        }
        "width" -> if (i != null && s != null) {
            val row = secSlots(m); val mx = maxW(row, i, secs = true)
            OptRow(tr("dzc.tool.width"), tr("dzc.widthSubS", "v" to s.w, "m" to mx), back) {
                candidates(row[i], mx).forEach { v -> OptChip("$v", v == s.w) {
                    val r = resize(row, i, v, secs = true)
                    if (r.ok) { app.ward(c.p.id, c.f.id) { withSecWidths(it, r.row.map { x -> x.w }) }; app.dzcDone(c.p.id, c.f.id, app.t("dzc.secW", "n" to i + 1, "a" to s.w, "b" to v)) }
                } }
                OptChip(tr("dzc.write"), false) { app.sheet = Sheet.DzcNum(c.p.id, c.f.id, m.id, "w", i) }
            }
        }
        "in" -> {
            val ts = wTargets(c)
            val s0 = ts.firstOrNull()?.let { m.sections[it] }
            if (s0 == null) { OptRow(tr("dzc.tool.in"), tr("dzc.secFirst"), back) {}; return }
            val fl = secFill(s0)
            OptRow(tr("dzc.tool.in"), scopeTxt, back) {
                OptChip(tr("dzc.rail") + if (fl.rail) " ✓" else " +", fl.rail, glyph = "rail") { wFill(c, { it.copy(rail = !fl.rail) }, app.t(if (fl.rail) "dzc.railOff" else "dzc.railOn")) }
                OptStepper(tr("dzc.shelf"), fl.shelves, 0, 6) { v -> wFill(c, { it.copy(shelves = v) }, app.t("dzc.shelvesMsg", "n" to v)) }
                OptStepper(tr("dzc.drawer"), fl.drawers, 0, 4) { v -> wFill(c, { it.copy(drawers = v) }, app.t("dzc.drawersMsg", "n" to v)) }
                OptChip(tr("dzc.clear"), false) { wFill(c, { SecFill(false, 0, 0) }, app.t("dzc.cleared")) }
                if (!st.multi && i != null) OptChip(tr("dzc.tool.detail"), false) { app.sheet = Sheet.DzcMore(c.p.id, c.f.id, "inside:$i") }
            }
        }
        "decor" -> {
            val cur = if (st.multi) null else s?.let { colourOf(secFrontOf(f, m, i)) } ?: colourOf(frontOf(f, m))
            val scope: (@Composable () -> Unit)? = if (st.multi || i == null) null else { { ScopeSeg(listOf("one" to tr("dzc.s.one"), "all" to tr("dzc.s.all")), st.scope) { st.scope = it } } }
            OptRow(tr("dzc.tool.decor"), if (scope == null) scopeTxt else "", back, scope) {
                FRONT_KEYS.forEach { (key, rgb, _) -> OptChip(frontName(app, key), cur == key, swatch = hex(rgb)) { wSetDecor(c, key) } }
            }
        }
        "handle" -> {
            val type = handleType(f)
            val curOne = if (i != null && !st.multi) {
                val keys = handleFronts(m).filter { it.sec == i && !it.glass }.let { fr -> if (fi != null) c.fronts(i).getOrNull(fi)?.let { listOf(it.f) } ?: emptyList() else fr }
                if (keys.isNotEmpty() && keys.none { hasHandle(m, it.key) }) "push" else type
            } else type
            val scope: (@Composable () -> Unit)? = if (st.multi || i == null) null else { { ScopeSeg(listOf("one" to tr("dzc.s.one"), "all" to tr("dzc.s.all")), st.scope) { st.scope = it } } }
            OptRow(tr("dzc.tool.handle"), if (scope == null) scopeTxt else tr("dzc.handleNote"), back, scope) {
                listOf("bar", "long", "knob", "push").forEach { h -> OptChip(tr("dzc.h.$h"), curOne == h, glyph = "h-$h") { wSetHandle(c, h) } }
            }
        }
        "type" -> {
            val cur = if (st.multi) null else s?.let(::secType)
            OptRow(tr("dzc.tool.type"), scopeTxt, back) {
                listOf("door", "mirror", "glass", "open").forEach { t -> OptChip(tr("dzc.st.$t"), cur == t, glyph = if (t == "open") "sopen" else t) { wSetType(c, t) } }
                if (!st.multi && s != null && s.fronts.kind == "door") { OptChip(tr("dzc.d1"), s.fronts.n == 1) { wSetDoors(c, 1) }; OptChip(tr("dzc.d2"), s.fronts.n == 2) { wSetDoors(c, 2) } }
            }
        }
        "hinge" -> if (i != null) {
            val right = hingeRight(m, i)
            OptRow(tr("dzc.tool.hinge"), tr("dzc.secN", "n" to i + 1), back) {
                OptChip(tr("dzc.hL"), !right, glyph = "hg-L") { wSetHinge(c, "L") }
                OptChip(tr("dzc.hR"), right, glyph = "hg-R") { wSetHinge(c, "R") }
            }
        }
        "soft" -> if (i != null) {
            val on = softOf(m, i)
            OptRow(tr("dzc.tool.soft"), tr("dzc.secN", "n" to i + 1), back, { ScopeSeg(listOf("one" to tr("dzc.s.one"), "all" to tr("dzc.s.all")), st.scope) { st.scope = it } }) {
                OptChip(tr("dzc.on"), on) { wSetSoft(c, true) }
                OptChip(tr("dzc.off"), !on) { wSetSoft(c, false) }
                OptNote(tr("dzc.softNote"))
            }
        }
        "size" -> OptRow(tr("dzc.tool.size"), wardHeadSub(f, m, c.ws), back) {
            OptChip(tr("wd.w") + " ${m.w}", false) { app.sheet = Sheet.WField(c.p.id, c.f.id, "w") }
            OptChip(tr("wd.h") + " ${m.h}", false) { app.sheet = Sheet.WField(c.p.id, c.f.id, "h") }
            OptChip(tr("wd.d") + " ${m.d}", false) { app.sheet = Sheet.WField(c.p.id, c.f.id, "d") }
            if (uz.metrx.app.furniture.hung(m)) OptChip(tr("fz.elev") + " ${m.elev}", false) { app.sheet = Sheet.WField(c.p.id, c.f.id, "e") }
        }
        "base" -> {
            val hung = uz.metrx.app.furniture.hung(m)
            val stacked = f.type in uz.metrx.app.furniture.STACK_TYPES && hung
            val cur = when { hung -> "wall"; m.legs -> "legs"; else -> "plinth" }
            OptRow(tr("dzc.tool.base"), tr("dzc.wb.$cur"), back) {
                if (!stacked) (listOf("plinth", "legs") + if (f.type.isNotEmpty()) listOf("wall") else emptyList()).forEach { k2 ->
                    OptChip(tr("dzc.wb.$k2"), cur == k2, glyph = if (k2 == "wall") "hang" else k2) { wSetBase(c, k2) }
                }
                if (!hung) {
                    val h = if (m.legs) legsOf(m, c.ws) else wardBase(m)
                    val hs = if (m.legs) listOf(80, 100, 120, 150) else listOf(60, 80, 100, 120)
                    OptStepper(tr("dzc.heightMm"), h, hs.first(), hs.last()) { v -> val nx = if (v > h) hs.firstOrNull { it > h } ?: hs.last() else hs.lastOrNull { it < h } ?: hs.first(); wSetBaseH(c, nx) }
                } else OptChip(tr("fz.elev") + " ${m.elev}", false) { app.sheet = Sheet.WField(c.p.id, c.f.id, "e") }
            }
        }
        "doors" -> {
            val sl = m.slide
            OptRow(tr("dzc.tool.doors"), tr(if (sl == null) "wd.hingedT" else "wd.slideT"), back) {
                OptChip(tr("wd.hingedT"), sl == null) { if (sl != null) { app.ward(c.p.id, c.f.id) { it.copy(slide = null) }; app.dzcDone(c.p.id, c.f.id, app.t("wd.hingedT")) } }
                OptChip(tr("wd.slideT"), sl != null) { if (sl == null) { app.ward(c.p.id, c.f.id) { mm -> mm.copy(slide = uz.metrx.app.furniture.Slide(uz.metrx.app.furniture.slideDoorsFor(uz.metrx.app.furniture.slideOpening(mm, app.settings.workshop.t).first))) }; app.dzcDone(c.p.id, c.f.id, app.t("wd.slideT")) } }
                if (sl != null) {
                    val n = sl.n.coerceIn(2, 4)
                    OptStepper(tr("wd.slideN"), n, 2, 4) { v -> app.ward(c.p.id, c.f.id) { mm -> mm.copy(slide = sl.copy(n = v)) } }
                    (0 until n).forEach { j ->
                        val cur = sl.panel(j)
                        OptChip(tr("wd.slideI", "n" to j + 1) + ": " + tr("wd.fill.$cur"), false) {
                            val nx = listOf("ldsp", "mirror", "glass").let { l -> l[(l.indexOf(cur) + 1) % l.size] }
                            app.ward(c.p.id, c.f.id) { mm -> mm.copy(slide = sl.copy(panels = List(n) { q -> if (q == j) nx else sl.panel(q) })) }
                        }
                    }
                }
            }
        }
        "parts" -> OptRow(tr("dzc.tool.parts"), tr(uz.metrx.app.furniture.boxRole(f, m)) + " ${m.w}", back) {
            val ws = c.ws
            fun edit(fn: (List<Module>) -> List<Module>) = app.kit.change(app, c.p.id, c.f.id) { x ->
                val room = if (x.roomId == null) null else roomOf(c.p, x)
                uz.metrx.app.furniture.packPiece(x.copy(modules = fn(x.modules)), room?.let { r -> wallLen(r, app.settings.angleSnap, x.walls.firstOrNull() ?: "") }, ws = ws)
            }
            if (f.type == "stenka") {
                uz.metrx.app.furniture.STENKA_PARTS.forEach { kk -> OptChip("+ " + tr("pc.add.$kk"), false) {
                    val nb = uz.metrx.app.furniture.stenkaPart(f, kk, ws)
                    edit { l -> val ix = l.indexOfFirst { it.id == m.id }; val at = if (kk == "shelf") uz.metrx.app.furniture.stenkaShelfAt(l, ix) else if (ix < 0) l.size else ix + 1
                        l.toMutableList().apply { add(at.coerceIn(0, size), nb) } }
                    app.kit.sel = nb.id; app.dzcDone(c.p.id, c.f.id, app.t("kt.added", "m" to app.t("pc.add.$kk")))
                } }
                listOf(-1 to "pc.left", 1 to "pc.right").forEach { (dl, kk) -> OptChip(tr(kk), false) {
                    edit { l -> val ix = l.indexOfFirst { it.id == m.id }; val j = ix + dl; if (ix < 0 || j !in l.indices) l else l.toMutableList().apply { add(j, removeAt(ix)) } }
                } }
                val canDrop = uz.metrx.app.furniture.canDropBox(f, m)
                OptChip(tr("common.delete"), false, red = true, enabled = canDrop) {
                    edit { l -> l.filter { it.id != m.id } }; app.kit.sel = null
                    app.dzcDone(c.p.id, c.f.id, app.t("kt.deleted", "m" to app.t(uz.metrx.app.furniture.boxRole(f, m))))
                }
            } else OptNote(tr("dzc.partsNote"))
        }
        "checks" -> {
            val q = cx.found.filter { it.level != "ok" }
            OptRow(tr("dzc.tool.checks"), if (q.isEmpty()) tr("dzc.allOk") else tr("dzc.nIssues", "n" to q.size), back) {
                if (q.isEmpty()) OptChip(tr("kt.allOk"), true) {}
                q.forEach { x -> OptChip(checkText(x, f), false, red = x.level == "err") {
                    (x.vars["s"] as? Int)?.let { n -> if (n - 1 in m.sections.indices) { st.sel = DSel("s${n - 1}"); st.strip = null } }
                } }
            }
        }
        else -> st.strip = null
    }
}

/* ---------------- 3D ---------------- */

@Composable
private fun DzcWard3D(p: Project, room: Room, f: Furniture, c: WardCtl) {
    val st = c.st; val m = c.m
    val mod = m.label.ifEmpty { m.id }
    val hi = if (st.multi) st.ticks.mapNotNull { it.removePrefix("s").toIntOrNull() }.map { "${f.id}|$mod/${it + 1}" }.toSet()
        else c.selSec?.let { setOf("${f.id}|$mod/${it + 1}") } ?: emptySet()
    val peek = st.peek?.removePrefix("s")?.toIntOrNull()
    DzcScene3D(p, room, f, hi, peek?.let { i -> { k: String -> k.startsWith("${m.id}:s$i:") } }, st.inside, 100.dp) { key ->
        if (key == null) { if (!st.multi) st.clear(); return@DzcScene3D }
        val pk = parsePick(key)
        val box = f.modules.firstOrNull { it.id == pk.mid } ?: return@DzcScene3D
        if (box.id != m.id && box.type == "wardrobe") { c.app.kit.sel = box.id; c.app.kit.tick++; st.clear() }
        val i = pk.sec ?: return@DzcScene3D
        if (st.multi) { st.ticks = "s$i".let { k -> if (k in st.ticks) st.ticks - k else st.ticks + k }; return@DzcScene3D }
        val fr = pk.front?.let { j -> c.fronts(i).indexOfFirst { it.f.key == "s$i:f$j" }.takeIf { it >= 0 } }
        wPick(c, i, fr)
    }
}

/* ---------------- the number sheet ---------------- */

/** A section's typed width. */
@Composable
fun WardNumSheet(s: Sheet.DzcNum) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val m = f.modules.firstOrNull { it.id == s.mid } ?: run { app.sheet = null; return }
    val i = s.sec
    val sec = m.sections.getOrNull(i) ?: run { app.sheet = null; return }
    val row = secSlots(m)
    val mx = maxW(row, i, secs = true)
    DzcNumSheet(tr("dzc.secN", "n" to i + 1) + " · " + tr("dzc.tool.width"), sec.w, 150, max(150, mx), onClose = { app.sheet = null }) { v ->
        val r = resize(row, i, v, secs = true)
        if (!r.ok) { app.dzcWarn(app.t("dzc.maxW", "v" to mx)); return@DzcNumSheet }
        app.sheet = null
        app.kit.sel = m.id
        app.ward(p.id, f.id) { withSecWidths(it, r.row.map { x -> x.w }) }
        app.dzcDone(p.id, f.id, app.t("dzc.secW", "n" to i + 1, "a" to sec.w, "b" to v))
    }
}

@Suppress("unused") private val keepW = listOf(min(0, 0), abs(0))
