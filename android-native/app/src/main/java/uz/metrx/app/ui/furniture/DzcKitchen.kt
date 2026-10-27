package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.uid
import uz.metrx.app.furniture.END_ID
import uz.metrx.app.furniture.FCheck
import uz.metrx.app.furniture.Fronts
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.H_SNAPS
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.Insert
import uz.metrx.app.furniture.K_WALL_H
import uz.metrx.app.furniture.KExtras
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Planned
import uz.metrx.app.furniture.Run
import uz.metrx.app.furniture.SK
import uz.metrx.app.furniture.Slot
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.allowedW
import uz.metrx.app.furniture.applyRow
import uz.metrx.app.furniture.autoFill
import uz.metrx.app.furniture.boardFor
import uz.metrx.app.furniture.candidates
import uz.metrx.app.furniture.checks
import uz.metrx.app.furniture.clearOwnFronts
import uz.metrx.app.furniture.closeGap
import uz.metrx.app.furniture.colourOf
import uz.metrx.app.furniture.copyRight
import uz.metrx.app.furniture.curType
import uz.metrx.app.furniture.deleteToGap
import uz.metrx.app.furniture.fillOf
import uz.metrx.app.furniture.frontOf
import uz.metrx.app.furniture.handleFronts
import uz.metrx.app.furniture.handleType
import uz.metrx.app.furniture.hasHandle
import uz.metrx.app.furniture.insertAt
import uz.metrx.app.furniture.intoGap
import uz.metrx.app.furniture.isUpper
import uz.metrx.app.furniture.kHingeRight
import uz.metrx.app.furniture.kRow
import uz.metrx.app.furniture.kindOf
import uz.metrx.app.furniture.maxW
import uz.metrx.app.furniture.moveBy
import uz.metrx.app.furniture.moveOrder
import uz.metrx.app.furniture.pack
import uz.metrx.app.furniture.resize
import uz.metrx.app.furniture.retype
import uz.metrx.app.furniture.rowMods
import uz.metrx.app.furniture.slotKind
import uz.metrx.app.furniture.slotOf
import uz.metrx.app.furniture.snapHeight
import uz.metrx.app.furniture.snapWidth
import uz.metrx.app.furniture.template
import uz.metrx.app.furniture.typeable
import uz.metrx.app.furniture.wallElev
import uz.metrx.app.furniture.withGlassDoors
import uz.metrx.app.furniture.withHandle
import uz.metrx.app.furniture.withHandleType
import uz.metrx.app.furniture.withHinge
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withPreset
import uz.metrx.app.furniture.worktopTop
import uz.metrx.app.furniture.wsOf
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.editor.AMBER
import uz.metrx.app.ui.editor.COB
import uz.metrx.app.ui.editor.GREY_LINE
import uz.metrx.app.ui.editor.RED
import uz.metrx.app.ui.editor.roomGrid
import uz.metrx.app.ui.glass.glassCard
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
 * Designer C v2 for kitchens (approved 27 Oct 2026): each wall's front view to scale, edited on the drawing; the tools
 * slider and its options underneath; Qo‘shish's full catalogue dragged up onto the wall; checks with a one-tap fix next
 * to the module. The rules are furniture/RowEdit.kt and DesignEdit.kt; the drawing is drawRun (KitchenScreens.kt).
 */

/* ---------------- the catalogue ---------------- */

/** A tile of Qo‘shish: category, the library kind, its width, the fronts it has (null: the kind's own), the upper row. */
data class KTile(val cat: String, val kind: String, val w: Int, val fronts: Fronts? = null, val upper: Boolean = false, val label: String = kind)

/** The categories, in the mockup's order. */
val K_CATS = listOf("door", "drawer", "tech", "corner", "tall", "open", "wall", "filler")

/** Every tile, from the app's own module types and their widths. */
val K_TILES: List<KTile> = buildList {
    listOf(300, 400, 450).forEach { add(KTile("door", "base", it, Fronts("door", 1), label = "door1")) }
    listOf(500, 600, 800, 900).forEach { add(KTile("door", "base", it, Fronts("door", 2), label = "door2")) }
    listOf(400, 450, 600, 800).forEach { add(KTile("drawer", "drawers", it, Fronts("drawer", 3), label = "drawer3")) }
    listOf(400, 600).forEach { add(KTile("drawer", "drawers", it, Fronts("drawer", 2), label = "drawer2")) }
    listOf(600, 800).forEach { add(KTile("tech", "sink", it)) }
    add(KTile("tech", "hob", 600))
    listOf(450, 600).forEach { add(KTile("tech", "dishwasher", it)) }
    add(KTile("tech", "fridge", 600)); add(KTile("tech", "oven", 600)); add(KTile("tech", "fridgeB", 600))
    listOf(600, 900).forEach { add(KTile("tech", "hood", it, upper = true)) }
    add(KTile("tech", "micro", 600, upper = true))
    listOf(600, 900).forEach { add(KTile("corner", "base", it, Fronts("panel", 1), label = "corner")) }
    add(KTile("corner", "wall", 600, Fronts("panel", 1), upper = true, label = "cornerUp"))
    listOf(400, 450, 600).forEach { add(KTile("tall", "pantry", it)) }
    listOf(300, 450).forEach { add(KTile("open", "base", it, Fronts("open", 0), label = "openLow")) }
    listOf(300, 600).forEach { add(KTile("open", "open", it, upper = true)) }
    listOf(450, 600).forEach { add(KTile("open", "vitrina", it, upper = true)) }
    listOf(300, 400, 450, 500, 600, 800, 900).forEach { add(KTile("wall", "wall", it, upper = true)) }
    listOf(50, 100).forEach { add(KTile("filler", "fillerLow", it)) }
    add(KTile("filler", "fillerUp", 50, upper = true))
    add(KTile("filler", "spaceLow", 600)); add(KTile("filler", "spaceUp", 600, upper = true))
}

/** The module a tile puts on [wall]. */
fun tileModule(t: KTile, ws: Workshop, wall: String, w: Int = t.w): Module {
    val m = template(t.kind, ws, wall, w)
    val withF = t.fronts?.let { fr -> m.copy(fronts = fr, inserts = if (fr.kind == "drawer") emptyList() else m.inserts.ifEmpty { listOf(Insert("shelf", qty = 2)) }) } ?: m
    return if (t.kind == "vitrina") withGlassDoors(withF, true) else withF
}

/** A tile's slot in its row. */
fun tileSlot(t: KTile, m: Module) = slotOf(m)

/** An appliance's tile cannot be narrower to fit a gap. */
fun tileFixed(t: KTile) = allowedW(template(t.kind, uz.metrx.app.furniture.Workshop(), "A", t.w)) != null || t.kind.startsWith("filler")

/* ---------------- the editor's context ---------------- */

/** What a finger is doing on the drawing. */
sealed interface KDrag {
    data class Resize(val id: String, val upper: Boolean, val row0: List<Slot>, val i: Int, val x0: Int, val w0: Int, val mx: Int, val cands: List<Int>,
                      val nw: Int, val res: uz.metrx.app.furniture.Resized?, val maxHit: Boolean) : KDrag
    data class Height(val id: String, val h0: Int, val top: Int, val nh: Int) : KDrag
    data class Move(val id: String, val upper: Boolean, val row0: List<Slot>, val from: Int, val grab: Int, val ghost: Int, val order: List<Slot>, val at: Int, val overDel: Boolean) : KDrag
}

/** A Qo‘shish tile carried over the drawing: the finger in root px, its plan for the row under it. */
data class KTileDrag(val t: KTile, val root: Offset, val over: Boolean, val plan: Planned?, val u: Int = 0)

/** The kitchen editor's controller: the current piece, view and drags; the gestures read it. */
internal class KitCtl {
    var drag by mutableStateOf<KDrag?>(null)
    var press by mutableStateOf<Offset?>(null)
    var tile by mutableStateOf<KTileDrag?>(null)
    var panel = Rect.Zero
    var canvas = Rect.Zero
    lateinit var app: App
    lateinit var p: Project
    lateinit var f: Furniture
    lateinit var run: Run
    lateinit var runs: List<Run>
    lateinit var ws: Workshop
    lateinit var st: DzcState
    lateinit var lay: KLay
    lateinit var view: DzcView
    var density = 1f
    var room: Room? = null

    fun mmX(p: Offset) = lay.mmX(view.v(p).x)
    fun mmY(p: Offset) = lay.mmY(view.v(p).y)
    fun sx(mm: Int) = view.sx(lay.x(mm))
    fun sy(mm: Int) = view.sy(lay.y(mm))
    val mods get() = f.modules.filter { it.wall == run.wall }
    fun rowStart(upper: Boolean) = if (upper) run.upStart else run.lowStart
    fun module(id: String?) = f.modules.firstOrNull { it.id == id }
    val selM get() = module(st.sel?.id)

    /** The module under [p], the upper row first. */
    fun hitMod(p: Offset): Module? {
        val x = mmX(p); val y = mmY(p)
        val tol = 14 / lay.s
        return mods.sortedByDescending { if (isUpper(it)) 1 else 0 }.firstOrNull { m ->
            x >= m.x && x <= m.x + m.w && y >= (if (!isUpper(m) && m.elev < 300) -60f else m.elev - tol) && y <= m.elev + m.h + tol
        }
    }

    /** The free end of a row under [p] ("#end:<row>"). */
    fun hitEnd(p: Offset): String? {
        val L = run.len ?: return null
        val x = mmX(p); val y = mmY(p)
        listOf(false, true).forEach { up ->
            val e = rowStart(up) + fillOf(f, run, up).used
            if (e < L && x >= e && x <= L) {
                val ws2 = wsOf(f, ws)
                val y0 = if (up) wallElev(ws2) else 0; val y1 = if (up) wallElev(ws2) + K_WALL_H else worktopTop(ws2)
                if (y >= y0 - 20 && y <= y1 + 20 && (up || run.wall != ISLAND)) return endId(up)
            }
        }
        return null
    }

    /** The front of [m] under [p] (its index), null: none. */
    fun hitFront(m: Module, p: Offset): Int? {
        val one = m.copy(x = 0, elev = 0)
        val x = mmX(p) - m.x; val y = mmY(p) - m.elev
        return unitFrontBoxes(one, wsOf(f, ws)).indexOfFirst { b -> x >= b.x0 - 3 && x <= b.x1 + 3 && y >= b.y0 - 3 && y <= b.y1 + 3 }.takeIf { it >= 0 }
    }

    fun endId(upper: Boolean) = "#end:" + (if (upper) "up" else "low")
}

/** The id of a row's free end, and back. */
fun isEndSel(id: String?) = id?.startsWith("#end:") == true
fun endUpper(id: String) = id.endsWith(":up")

/* ---------------- the screen ---------------- */

@Composable
fun KitchenScreen(rt: Route.Kitchen) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val kit = app.kit
    @Suppress("UNUSED_VARIABLE") val tick = kit.tick
    val p = app.store.get(rt.pid) ?: return
    val f = p.furniture.firstOrNull { it.id == rt.fid } ?: return
    val snap = app.settings.angleSnap
    val room = roomOf(p, f)
    val runs = kRuns(f, room, snap)
    val run = runs.firstOrNull { it.wall == rt.wall } ?: runs.firstOrNull()
    val ws = wsOf(f, app.settings.workshop); val mats = app.settings.mats
    val st = app.dzc(f.id)
    val en = lang == Lang.EN
    val found = checks(f, runs, ws, room?.openings ?: emptyList(), room?.points ?: emptyList()) +
        remember(f, ws, mats) { uz.metrx.app.furniture.boardIssues(f, ws, mats).map { FCheck(it.level, it.key, it.vars, it.mid) } }
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize()) {
            uz.metrx.app.ui.ux.DesignerTop(p, f, freeSub(f, en)) { st.teach = true }
            if (room == null || run == null) Text(tr("kt.roomLost"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.weight(1f).padding(24.dp))
            else Box(Modifier.weight(1f).fillMaxWidth()) {
                KitchenEditor(rt, p, f, room, runs, run, ws, st, found)
            }
            uz.metrx.app.ui.ux.DesignerBar(p, f, rt.d3) { app.setTop(rt.copy(d3 = it)) }
        }
    }
}

@Composable
private fun KitchenEditor(rt: Route.Kitchen, p: Project, f: Furniture, room: Room, runs: List<Run>, run: Run, ws: Workshop, st: DzcState, found: List<FCheck>) {
    val app = LocalApp.current
    val mats = app.settings.mats
    val ctl = remember { KitCtl() }
    val d = LocalDensity.current
    val tm = rememberTextMeasurer()
    var panelH by remember { mutableIntStateOf(0) }
    ctl.app = app; ctl.p = p; ctl.f = f; ctl.run = run; ctl.runs = runs; ctl.ws = app.settings.workshop; ctl.st = st; ctl.room = room; ctl.density = d.density
    // a selection on another wall, or gone
    val sel = st.sel
    if (sel != null && !isEndSel(sel.id) && f.modules.none { it.id == sel.id && it.wall == run.wall }) st.clear()
    val bad = HashMap<String, String>().apply { found.forEach { c -> c.mid?.let { id -> if (c.level == "err" || (c.level == "warn" && this[id] != "err")) this[id] = c.level } } }
    val issues = found.filter { it.level != "ok" }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wPx = constraints.maxWidth.toFloat(); val hPx = constraints.maxHeight.toFloat()
        val topPx = with(d) { 100.dp.toPx() }
        val lay = KLay(runLen(f, run), roomH(room), 360f, true, runExt(f, run), st.z, st.px, st.py)
        val view = dzcFit(lay.vw, lay.vh, wPx, hPx, topPx, panelH + with(d) { 10.dp.toPx() })
        ctl.lay = lay; ctl.view = view
        if (rt.d3) DzcKitchen3D(p, room, f, st, ctl) { id, fr -> kPick(ctl, id, fr) }
        else {
            val shown = kShown(ctl)
            Canvas(Modifier.fillMaxSize().onGloballyPositioned { ctl.canvas = it.boundsInRoot() }.pointerInput(Unit) { dzcGestures(KitGestures(ctl)) }) {
                withTransform({ translate(view.ox, view.oy); scale(view.u, view.u, pivot = Offset.Zero) }) {
                    val fsel = st.sel?.takeIf { it.front == null && !st.multi && ctl.drag !is KDrag.Move }?.id
                    drawRun(lay, shown, run, room, ws, mats, fsel, if (ctl.drag == null) bad else emptyMap(), tm)
                    kOverlay(ctl, shown, bad)
                }
            }
            PressRing(ctl.press)
            kBubbles(ctl, found)
        }
        // the walls, then the caption
        WallChips(rt, f, runs, run, found, room)
        Box(Modifier.fillMaxWidth().padding(top = 44.dp)) { KCaption(ctl) }
        if (f.modules.none { it.wall == run.wall } && run.wall != ISLAND && !rt.d3) EmptyWall(p, f, room, run, ws)
        if (!st.fit && !rt.d3) ZoomPill(st.z, with(d) { (panelH + 14).toDp() }) { st.fitNow() }
        DzcPanel({ ctl.panel = it }, { panelH = it }) {
            when {
                ctl.drag is KDrag.Move -> DelZone((ctl.drag as KDrag.Move).overDel)
                st.strip != null -> KitOptions(ctl, st.strip!!, found)
                else -> ToolSlider(kitTools(ctl, issues.size)) { k -> kTool(ctl, k) }
            }
        }
        ctl.tile?.let { t -> TileGhost(ctl, t) }
        if (st.teach) TeachHint { st.teach = false }
    }
}

/** The wall chips over the drawing ("A · 3400"), a red dot on a wall with a problem. */
@Composable
private fun WallChips(rt: Route.Kitchen, f: Furniture, runs: List<Run>, run: Run, found: List<FCheck>, room: Room) {
    val app = LocalApp.current
    val st = app.dzc(f.id)
    val snap = app.settings.angleSnap
    Row(Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        runs.forEach { r ->
            val on = r.wall == run.wall
            val dot = found.any { c -> c.level == "err" && c.mid != null && f.modules.any { it.id == c.mid && it.wall == r.wall } } ||
                found.any { c -> c.level == "err" && c.vars["w"] == r.wall }
            Row(Modifier.heightIn(min = 36.dp).clip(CircleShape).background(if (on) G.ink else G.sheet(.85f)).border(1.dp, if (on) G.ink else G.rim, CircleShape)
                .semantics { selected = on }.clickable(role = Role.Tab) { if (!on) { app.setTop(rt.copy(wall = r.wall)); st.clear(); st.fitNow() } }
                .padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(runName(f, r), style = ui(13f, 700, if (on) G.solid else G.ink), maxLines = 1)
                if (dot) Box(Modifier.size(7.dp).clip(CircleShape).background(G.err))
                if (r.wall != ISLAND && !measured(room, snap, r.wall)) Text("~", style = ui(13f, 800, G.amberInk))
            }
        }
    }
}

/** An empty wall: the automatic fill, as before. */
@Composable
private fun EmptyWall(p: Project, f: Furniture, room: Room, run: Run, ws: Workshop) {
    val app = LocalApp.current
    val snap = app.settings.angleSnap
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.padding(24.dp).widthIn(max = 360.dp).glassCard(RoundedCornerShape(22.dp), fill = G.glass(.85f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(tr("kt.emptyT", "w" to run.wall), style = ui(16f, 800))
            Text(tr("kt.emptyB"), style = ui(13.5f, 400, G.ink2, 1.45f))
            GBtn(tr("kt.auto"), {
                val before = f.modules.size
                val n = app.kit.change(app, p.id, f.id) { x -> autoFill(x, kRuns(x, room, snap).filter { x.modules.isEmpty() || it.wall == run.wall }, ws, room.openings, room.points) }
                app.say("kt.autoDone", "n" to ((n?.modules?.size ?: before) - before))
            }, icon = "plus")
        }
    }
}

/* ---------------- what is drawn ---------------- */

/** The piece as drawn now: a drag's or a tile's preview, the doors opened by "Ichini ko‘rish", the modules sliding. */
private fun kShown(c: KitCtl): Furniture {
    val f = c.f
    val runs = c.runs
    var g: Furniture = when (val dr = c.drag) {
        is KDrag.Resize -> dr.res?.takeIf { it.ok }?.let { pack(applyRow(f, c.run.wall, dr.upper, it.row, c.ws), runs) } ?: f
        is KDrag.Height -> f.copy(modules = f.modules.map { if (it.id == dr.id) it.copy(h = dr.nh, elev = dr.top - dr.nh) else it })
        is KDrag.Move -> pack(applyRow(f, c.run.wall, dr.upper, dr.order, c.ws), runs).let { x -> x.copy(modules = x.modules.filter { it.id != dr.id }) }
        null -> f
    }
    c.tile?.plan?.takeIf { it.ok && c.tile?.over == true }?.let { pl ->
        val t = c.tile!!.t
        val nm = tileModule(t, c.ws, c.run.wall, pl.w).copy(id = pl.id ?: "new")
        g = pack(applyRow(f, c.run.wall, t.upper, pl.row, c.ws, mapOf(nm.id to nm)), runs)
    }
    val open = { m: Module -> (c.st.inside || c.st.peek == m.id) && m.fronts.kind == "door" && m.type != "gap" }
    if (c.st.inside || c.st.peek != null) g = g.copy(modules = g.modules.map { if (open(it)) it.copy(fronts = Fronts("open", 0)) else it })
    return g
}

/** Over the drawing (viewBox units): the "+" gaps and free ends, the absorbing neighbour, a front's outline, the handles, the move's ghost, ticks. */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.kOverlay(c: KitCtl, g: Furniture, bad: Map<String, String>) {
    val lay = c.lay; val run = c.run; val st = c.st
    val ws2 = wsOf(c.f, c.ws)
    val line = GREY_LINE
    val selId = st.sel?.id
    // the gaps and the rows' free ends
    g.modules.filter { it.wall == run.wall && slotKind(it) == SK.GAP }.forEach { m ->
        plusGap(lay.x(m.x), lay.y(m.elev + m.h), lay.x(m.x + m.w), lay.y(m.elev), selId == m.id && !st.multi, c.tile?.plan?.into == m.id, line, COB)
    }
    run.len?.let { L ->
        listOf(false, true).forEach { up ->
            if (up && run.wall == ISLAND) return@forEach
            val e = c.rowStart(up) + fillOf(g, run, up).used
            if (e < L - 5) {
                val y0 = if (up) wallElev(ws2) else 0; val y1 = if (up) wallElev(ws2) + K_WALL_H else worktopTop(ws2) - 40
                plusGap(lay.x(e), lay.y(y1), lay.x(L), lay.y(y0), selId == c.endId(up), c.tile?.plan?.into == END_ID && c.tile?.t?.upper == up, line, COB)
            }
        }
    }
    // the neighbour taking up the difference, in amber
    (c.drag as? KDrag.Resize)?.res?.aid?.let { aid -> g.modules.firstOrNull { it.id == aid }?.let { a ->
        drawRect(AMBER.copy(alpha = .22f), Offset(lay.x(a.x), lay.y(a.elev + a.h)), Size(a.w * lay.s, a.h * lay.s))
        drawRect(AMBER, Offset(lay.x(a.x), lay.y(a.elev + a.h)), Size(a.w * lay.s, a.h * lay.s), style = Stroke(1.6f))
    } }
    val m = g.modules.firstOrNull { it.id == selId && it.wall == run.wall }
    if (m != null && !st.multi && c.drag !is KDrag.Move) {
        val l = lay.x(m.x); val r = lay.x(m.x + m.w); val t = lay.y(m.elev + m.h); val b = lay.y(m.elev)
        // a selected front: the module dashed, the front solid
        val fi = st.sel?.front
        if (fi != null) {
            drawRect(COB, Offset(l - 2f, t - 2f), Size(r - l + 4f, b - t + 4f), style = Stroke(1.4f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 4f))))
            unitFrontBoxes(m.copy(x = 0, elev = 0), ws2).getOrNull(fi)?.let { fb ->
                drawRect(COB, Offset(lay.x(m.x + fb.x0) - 1f, lay.y(m.elev + fb.y1) - 1f), Size((fb.x1 - fb.x0) * lay.s + 2f, (fb.y1 - fb.y0) * lay.s + 2f), style = Stroke(3f))
            }
        }
        // the doors' hinge sides, dashed: the way each one opens
        if (m.fronts.kind == "door" && m.type != "gap") {
            val n = m.fronts.n.coerceAtLeast(1); val fw = (r - l) / n
            for (j in 0 until n) {
                val a = l + j * fw; val z = a + fw
                val right = kHingeRight(m, j, n)
                val path = androidx.compose.ui.graphics.Path().apply {
                    if (right) { moveTo(a + 2f, t + 2f); lineTo(z - 2f, (t + b) / 2); lineTo(a + 2f, b - 2f) } else { moveTo(z - 2f, t + 2f); lineTo(a + 2f, (t + b) / 2); lineTo(z - 2f, b - 2f) }
                }
                drawPath(path, COB.copy(alpha = .55f), style = Stroke(1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f))))
            }
        }
        if (fi == null) {
            // the right-edge handle, and a wall unit's bottom-edge one
            if (slotKind(m) != SK.GAP && slotKind(m) != SK.FILLER) {
                val hy = (t + b) / 2
                drawRoundRect(COB, Offset(r - 4f, hy - 13f), Size(8f, 26f), CornerRadius(4f))
                drawLine(Color.White, Offset(r - 1.2f, hy - 5f), Offset(r - 1.2f, hy + 5f), 1f); drawLine(Color.White, Offset(r + 1.2f, hy - 5f), Offset(r + 1.2f, hy + 5f), 1f)
            }
            if (m.type == "wall" && m.app != "hood") {
                val hx = (l + r) / 2
                drawRoundRect(COB, Offset(hx - 13f, b - 4f), Size(26f, 8f), CornerRadius(4f))
                drawLine(Color.White, Offset(hx - 5f, b - 1.2f), Offset(hx + 5f, b - 1.2f), 1f); drawLine(Color.White, Offset(hx - 5f, b + 1.2f), Offset(hx + 5f, b + 1.2f), 1f)
            }
        }
        // a wall unit's guides: the edges of the units under it
        if (isUpper(m)) g.modules.filter { it.wall == run.wall && !isUpper(it) && slotKind(it) != SK.GAP }.flatMap { listOf(it.x, it.x + it.w) }.distinct()
            .filter { it >= m.x - 80 && it <= m.x + m.w + 80 }.forEach { e ->
                val ok = abs(e - m.x) < 2 || abs(e - m.x - m.w) < 2
                drawLine(if (ok) Color(0xFF16A34A) else COB.copy(alpha = .5f), Offset(lay.x(e), lay.y(worktopTop(ws2))), Offset(lay.x(e), b), 1f,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 3f)))
            }
    }
    // the snap ticks under the floor while the edge is dragged
    (c.drag as? KDrag.Resize)?.let { dr ->
        val x0 = g.modules.firstOrNull { it.id == dr.id }?.x ?: dr.x0
        dr.cands.forEach { v -> val on = v == dr.nw; val tx = lay.x(x0 + v); drawLine(if (on) COB else GREY_LINE, Offset(tx, lay.yF + 2f), Offset(tx, lay.yF + if (on) 9f else 6f), if (on) 2f else 1f) }
    }
    // the move: the slot it will land in, and the module carried above it
    (c.drag as? KDrag.Move)?.let { dr ->
        val mv = c.f.modules.firstOrNull { it.id == dr.id } ?: return@let
        val packed = pack(applyRow(c.f, run.wall, dr.upper, dr.order, c.ws), c.runs).modules.firstOrNull { it.id == dr.id }
        if (packed != null) drawRoundRect(COB.copy(alpha = .1f), Offset(lay.x(packed.x) + 1f, lay.y(packed.elev + packed.h) + 1f), Size(packed.w * lay.s - 2f, packed.h * lay.s - 2f), CornerRadius(3f))
        val lift = 60
        val ghost = mv.copy(x = dr.ghost, elev = mv.elev + lift)
        drawRect(Color.Black.copy(alpha = .12f), Offset(lay.x(ghost.x) + 4f, lay.y(ghost.elev + ghost.h) + 6f), Size(ghost.w * lay.s, ghost.h * lay.s))
        val mats = c.app.settings.mats
        val front = boardColor(mats, frontOf(c.f, mv)); val carcass = boardColor(mats, c.f.mats.carcass, "#F5F5F2")
        drawUnit(lay, ghost, ws2, front, carcass, max(.8f, ws2.gap10 / 10f * lay.s))
        drawRect(if (dr.overDel) RED else COB, Offset(lay.x(ghost.x) - 1.5f, lay.y(ghost.elev + ghost.h) - 1.5f), Size(ghost.w * lay.s + 3f, ghost.h * lay.s + 3f), style = Stroke(2.6f))
    }
    // Belgilash: a tick on each module
    if (st.multi) g.modules.filter { it.wall == run.wall && slotKind(it) != SK.GAP }.forEach { mm ->
        val on = mm.id in st.ticks
        val cx = lay.x(mm.x) + min(9f, mm.w * lay.s / 2); val cy = lay.y(mm.elev + mm.h) + 9f
        if (on) drawRect(COB, Offset(lay.x(mm.x) - 1.5f, lay.y(mm.elev + mm.h) - 1.5f), Size(mm.w * lay.s + 3f, mm.h * lay.s + 3f), style = Stroke(2.4f))
        drawCircle(if (on) COB else Color.White, 6.5f, Offset(cx, cy)); drawCircle(COB, 6.5f, Offset(cx, cy), style = Stroke(1.2f))
        if (on) { drawLine(Color.White, Offset(cx - 3f, cy), Offset(cx - .8f, cy + 2.4f), 1.4f); drawLine(Color.White, Offset(cx - .8f, cy + 2.4f), Offset(cx + 3.2f, cy - 2.4f), 1.4f) }
    }
    // a tile that does not fit: a red line where it would go
    c.tile?.takeIf { it.over && it.plan?.ok == false }?.let { tdr ->
        val x = lay.x(c.rowStart(tdr.t.upper) + tdr.u)
        val y0 = if (tdr.t.upper) wallElev(ws2) else 0; val y1 = if (tdr.t.upper) wallElev(ws2) + K_WALL_H else worktopTop(ws2)
        drawLine(RED, Offset(x, lay.y(y1)), Offset(x, lay.y(y0)), 2.4f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 3f)))
    }
    @Suppress("UNUSED_VARIABLE") val unused = bad
}

/** The live width (and height) bubbles, the absorbing neighbour's, and the checks' callouts. */
@Composable
private fun androidx.compose.foundation.layout.BoxScope.kBubbles(c: KitCtl, found: List<FCheck>) {
    val app = c.app; val st = c.st
    val g = kShown(c)
    val m = g.modules.firstOrNull { it.id == st.sel?.id && it.wall == c.run.wall }
    val d = LocalDensity.current
    val dr = c.drag
    if (m != null && !st.multi && st.sel?.front == null && dr !is KDrag.Move && slotKind(m) != SK.GAP) {
        val live = dr is KDrag.Resize && dr.id == m.id
        val bx = c.sx(m.x + m.w / 2)
        val by = if (isUpper(m)) c.sy(m.elev + m.h) - with(d) { 44.dp.toPx() } else c.sy(0) + with(d) { 6.dp.toPx() }
        val maxHit = live && (dr as KDrag.Resize).maxHit
        Bubble((if (maxHit) tr("dzc.max") + " " else "") + "${m.w} " + tr("u.mm"), bx, by, live = live, warn = maxHit) {
            app.sheet = Sheet.DzcNum(c.p.id, c.f.id, m.id, "w")
        }
        if (m.type == "wall" && m.app != "hood") {
            val hl = dr is KDrag.Height && dr.id == m.id
            Bubble("h ${m.h}", bx, c.sy(m.elev) + with(d) { 8.dp.toPx() }, live = hl) { app.sheet = Sheet.DzcNum(c.p.id, c.f.id, m.id, "h") }
        }
        (dr as? KDrag.Resize)?.res?.takeIf { it.aid != null && it.aid != END_ID }?.let { r ->
            g.modules.firstOrNull { it.id == r.aid }?.let { a -> Bubble("${shortName(app, a)} ${r.aw0} → ${r.aw1}", c.sx(a.x + a.w / 2), c.sy(a.elev + a.h / 2), amber = true) }
        }
        (dr as? KDrag.Resize)?.res?.takeIf { it.aid == END_ID }?.let { r ->
            Bubble(tr("dzc.endGap") + " ${r.aw0} → ${r.aw1}", c.sx(c.rowStart(isUpper(m)) + fillOf(g, c.run, isUpper(m)).used + max(0, r.aw1) / 2), c.sy(m.elev + m.h / 2), amber = true)
        }
    }
    // the checks in context: a callout with its fix under the module, folded to "!" while working elsewhere
    if (dr == null && c.tile == null) found.filter { it.level != "ok" && it.mid != null }.distinctBy { it.mid }.forEach { q ->
        val qm = c.f.modules.firstOrNull { it.id == q.mid && it.wall == c.run.wall } ?: return@forEach
        val open = !st.cmin && st.strip == null && !st.multi && (st.sel == null || st.sel?.id == qm.id)
        if (!open) Badge(c.sx(qm.x + qm.w) - with(d) { 26.dp.toPx() }, c.sy(qm.elev + qm.h) + with(d) { 2.dp.toPx() }) { st.cmin = false; st.strip = null; st.multi = false }
        else {
            val fix = kFixOf(c, q, qm)
            Callout(checkText(q, c.f), fix?.first, c.sx(qm.x + qm.w / 2), c.sy(qm.elev) + with(d) { 6.dp.toPx() }, c.canvas.width, { fix?.second?.invoke() }) { st.cmin = true }
        }
        return@forEach
    }
}

/** A module's short name: "Moyka", "To‘ldiruvchi". */
private fun shortName(app: App, m: Module) = app.t("kn." + kindOf(m))

/** A check's one-tap fix: its words and what it does (null: none). */
@Composable
private fun kFixOf(c: KitCtl, q: FCheck, m: Module): Pair<String, () -> Unit>? {
    val app = c.app
    val room = c.room
    return when (q.key) {
        "kc.window" -> {
            val o = room?.openings?.filter { it.wall == m.wall && it.type == "window" }?.firstOrNull { it.off < m.x + m.w && it.off + it.w > m.x }
            val fw = o?.let { it.off - m.x } ?: 0
            if (fw >= 150) tr("dzc.fixTo", "v" to fw) to { kSetWidth(c, m, fw, app.t("dzc.fixed")) }
            else tr("dzc.fixDel") to { kDelete(c, m, app.t("dzc.fixed")) }
        }
        "kc.tallUp", "kc.door" -> tr("dzc.fixDel") to { kDelete(c, m, app.t("dzc.fixed")) }
        else -> null
    }
}

/** The caption: what is selected and where, Belgilash's count. */
@Composable
private fun KCaption(c: KitCtl) {
    val st = c.st
    Box(Modifier.fillMaxWidth()) {
        if (st.multi) { DzcCaption(tr("dzc.multiN", "n" to st.ticks.size), tr("dzc.multiTap"), { st.multi = false; st.ticks = emptySet(); st.strip = null }, multi = true); return@Box }
        val id = st.sel?.id ?: return@Box
        if (isEndSel(id)) { DzcCaption(tr("dzc.endGap"), runName(c.f, c.run) + " · " + tr(if (endUpper(id)) "dzc.rowUp" else "dzc.rowLow"), { st.clear() }); return@Box }
        val m = c.module(id) ?: return@Box
        val where = runName(c.f, c.run, false) + " · " + tr(if (isUpper(m)) "dzc.rowUp" else "dzc.rowLow")
        val fi = st.sel?.front
        if (fi != null) DzcCaption(kFrontName(m, fi), "", { st.clear() }, up = modName(m), onUp = { st.sel = DSel(m.id); st.strip = null })
        else DzcCaption(modName(m) + " " + tr("u.mm"), where, { st.clear() })
    }
}

/** A front's name: "2-eshik", "1-tortma". */
@Composable
private fun kFrontName(m: Module, i: Int): String {
    val fr = handleFronts(m).filter { it.sec < 0 }.getOrNull(i) ?: return tr("dzc.front")
    return frontName(m, fr)
}

/** The tile carried: its words under the finger, green where it fits, red with the reason. */
@Composable
private fun TileGhost(c: KitCtl, t: KTileDrag) {
    val app = c.app
    val d = LocalDensity.current
    val local = t.root - Offset(c.canvas.left, c.canvas.top)
    val ok = t.plan?.ok == true
    val txt = when {
        !t.over -> tr("dzc.dragUp")
        ok && t.plan?.into != null -> tr("dzc.intoGap")
        ok -> tr("dzc.between")
        else -> planWhy(app, t.plan, t.t)
    }
    Column(Modifier.offset { IntOffset((local.x - with(d) { 90.dp.toPx() }).roundToInt(), (local.y - with(d) { 90.dp.toPx() }).roundToInt()) }.width(180.dp)
        .clip(RoundedCornerShape(14.dp)).background(if (!t.over) G.solid else if (ok) Color(0xFF16A34A) else G.err).padding(10.dp)) {
        Text(tr("dzc.tile.${t.t.label}") + " " + t.t.w, style = ui(13.5f, 800, if (t.over) Color.White else G.ink), maxLines = 1)
        Text(txt, style = ui(12f, 600, if (t.over) Color.White else G.ink2, 1.25f), maxLines = 3, overflow = TextOverflow.Ellipsis)
    }
}

/** A tile's name key (kn.*): the library kind's, or the open lower unit's, the corner's. */
fun tileKey(t: KTile) = when (t.label) { "door1", "door2" -> "base"; "drawer3", "drawer2" -> "drawers"; "corner", "cornerUp" -> "corner"; "openLow" -> "openLow"; else -> t.kind }

/** Why a plan cannot be: a gap too small, no room on the wall. */
private fun planWhy(app: App, pl: Planned?, t: KTile): String = when (pl?.why) {
    "gapSmall" -> app.t("dzc.whyGap", "g" to pl.free, "w" to t.w)
    "noRoom" -> app.t("dzc.whyRoom", "g" to pl.free, "w" to t.w)
    else -> app.t("dzc.whyNo")
}

/* ---------------- gestures ---------------- */

private class KitGestures(val c: KitCtl) : DzcGestures {
    private val st get() = c.st
    private fun dp(v: Float) = v * c.density

    override fun handleAt(p: Offset): String? {
        if (st.multi) return null
        val m = c.selM ?: return null
        if (st.sel?.front != null || m.wall != c.run.wall) return null
        val k = slotKind(m)
        if (k != SK.GAP && k != SK.FILLER) {
            val hx = c.sx(m.x + m.w); val hy = c.sy(m.elev + m.h / 2)
            if (abs(p.x - hx) < dp(22f) && abs(p.y - hy) < dp(34f)) return "w"
        }
        if (m.type == "wall" && m.app != "hood") {
            val hx = c.sx(m.x + m.w / 2); val hy = c.sy(m.elev)
            if (abs(p.x - hx) < dp(34f) && abs(p.y - hy) < dp(20f)) return "h"
        }
        return null
    }

    override fun liftable(p: Offset) = !st.multi && c.hitMod(p)?.let { uz.metrx.app.furniture.movable(it) } == true

    override fun tap(p: Offset) {
        val now = android.os.SystemClock.uptimeMillis()
        val (t0, x0, y0) = st.lastTap
        if (now - t0 < 320 && abs(p.x - x0) < dp(26f) && abs(p.y - y0) < dp(26f)) { st.lastTap = Triple(0L, 0f, 0f); doubleTap(); return }
        st.lastTap = Triple(now, p.x, p.y)
        val m = c.hitMod(p)
        if (st.multi) { if (m != null && slotKind(m) != SK.GAP) st.ticks = if (m.id in st.ticks) st.ticks - m.id else st.ticks + m.id; return }
        if (m == null) {
            val e = c.hitEnd(p)
            if (e != null) kPick(c, e, null) else st.clear()
            return
        }
        kPick(c, m.id, c.hitFront(m, p))
    }

    override fun doubleTap() { st.fitNow() }
    override fun pressStart(p: Offset) { c.press = p }
    override fun pressEnd() { c.press = null }

    override fun lift(p: Offset) {
        c.press = null
        val m = c.hitMod(p) ?: return
        val up = isUpper(m)
        val row = kRow(c.f, c.run, up)
        val from = row.indexOfFirst { it.id == m.id }
        if (from < 0) return
        st.sel = DSel(m.id); st.strip = null; st.peek = null
        c.app.haptic(Hap.TICK)
        val grab = (c.mmX(p) - m.x).roundToInt()
        c.drag = KDrag.Move(m.id, up, row, from, grab, m.x, row, from, false)
    }

    override fun moveTo(p: Offset) {
        val dr = c.drag as? KDrag.Move ?: return
        val m = c.module(dr.id) ?: return
        val ghost = (c.mmX(p) - dr.grab).roundToInt()
        val centre = ghost + m.w / 2.0 - c.rowStart(dr.upper)
        val (order, at) = moveOrder(dr.row0, dr.from, centre)
        val root = p + Offset(c.canvas.left, c.canvas.top)
        val over = c.panel.hits(root, dp(10f))
        if (over && !dr.overDel) c.app.haptic(Hap.WARN)
        c.drag = dr.copy(ghost = ghost, order = order, at = at, overDel = over)
    }

    override fun drop(cancel: Boolean) {
        val dr = c.drag as? KDrag.Move ?: return
        c.drag = null
        if (cancel) return
        val m = c.module(dr.id) ?: return
        val app = c.app
        if (dr.overDel) { kDelete(c, m, null); return }
        if (dr.order.map { it.id } == dr.row0.map { it.id }) { app.haptic(Hap.TICK); return }
        app.kit.change(app, c.p.id, c.f.id) { x -> applyRow(x, c.run.wall, dr.upper, dr.order, c.ws) }
        app.dzcDone(c.p.id, c.f.id, app.t("dzc.moved", "m" to app.modName(m), "n" to dr.at + 1))
    }

    override fun handleStart(kind: String, p: Offset) {
        val m = c.selM ?: return
        if (kind == "h") { c.drag = KDrag.Height(m.id, m.h, m.elev + m.h, m.h); return }
        val up = isUpper(m)
        val row = kRow(c.f, c.run, up)
        val i = row.indexOfFirst { it.id == m.id }
        if (i < 0) return
        val mx = maxW(row, i)
        c.drag = KDrag.Resize(m.id, up, row, i, m.x, m.w, mx, candidates(row[i], mx), m.w, null, false)
    }

    override fun handleTo(p: Offset) {
        when (val dr = c.drag) {
            is KDrag.Resize -> {
                val s = dr.row0[dr.i]
                val raw = (c.mmX(p) - dr.x0).toDouble()
                val nw = snapWidth(raw, dr.cands, st.fine, s.allowed == null, 150, dr.mx, dr.w0)
                val hit = raw > dr.mx + 60
                if (hit && !dr.maxHit) c.app.haptic(Hap.WARN)
                val res = if (nw == dr.w0) null else resize(dr.row0, dr.i, nw)
                c.drag = dr.copy(nw = nw, res = res, maxHit = hit)
            }
            is KDrag.Height -> c.drag = dr.copy(nh = snapHeight((dr.top - c.mmY(p)).toDouble()))
            else -> {}
        }
    }

    override fun handleEnd(cancel: Boolean) {
        val dr = c.drag; c.drag = null
        if (cancel || dr == null) return
        val app = c.app
        when (dr) {
            is KDrag.Resize -> {
                val r = dr.res ?: return
                if (!r.ok) return
                val m = c.module(dr.id) ?: return
                app.kit.change(app, c.p.id, c.f.id) { x -> applyRow(x, c.run.wall, dr.upper, r.row, c.ws) }
                app.dzcDone(c.p.id, c.f.id, widthMsg(app, c, m, dr.w0, dr.nw, r))
            }
            is KDrag.Height -> {
                if (dr.nh == dr.h0) return
                val m = c.module(dr.id) ?: return
                kSetHeight(c, m, dr.nh)
            }
            else -> {}
        }
    }

    override fun pan(d: Offset) { st.px += d.x / c.view.u; st.py += d.y / c.view.u }
    override fun zoom(c0: Offset, f: Float) { st.zoomAt(c.view, c0, f) }
}

/** "Moyka: 600 → 450 mm · To‘ldiruvchi 50 → 200". */
private fun widthMsg(app: App, c: KitCtl, m: Module, w0: Int, w1: Int, r: uz.metrx.app.furniture.Resized): String {
    val who = when (r.aid) {
        null -> ""
        END_ID -> " · " + app.t("dzc.endGap") + " ${r.aw0} → ${r.aw1}"
        else -> c.module(r.aid)?.let { a -> " · " + shortName(app, a) + " ${r.aw0} → ${r.aw1}" + if (slotKind(a) == SK.FILLER && r.aw1 >= 150) " (" + app.t("dzc.nowGap") + ")" else "" } ?: ""
    }
    return shortName(app, m) + ": $w0 → $w1 " + app.t("u.mm") + who
}

/* ---------------- selection ---------------- */

/** A tap on module [id] (or a row's free end): selects it; a second tap on a front selects that door or drawer. */
internal fun kPick(c: KitCtl, id: String, front: Int?) {
    val st = c.st
    val m = c.module(id)
    val cur = st.sel
    if (cur != null && cur.id == id && m != null) {
        if (front != null && handleFronts(m).any { it.sec < 0 } && st.peek != id && !st.inside) {
            st.sel = DSel(id, if (cur.front == front) null else front); st.scope = "one"
            if (st.strip != null && kitTools(c, 0).none { it.key == st.strip }) st.strip = null
        }
        return
    }
    val keepAdd = st.strip == "add" && (m == null || slotKind(m) == SK.GAP)
    st.pick(DSel(id))
    if (!keepAdd && st.strip != null && (st.strip in setOf("add", "checks", "style", "more") || kitTools(c, 0).none { it.key == st.strip })) st.strip = null
    if (st.peek != null) st.peek = if (st.strip == "in") id else null
    if (m != null && slotKind(m) != SK.GAP) c.app.dzcFirstPick(st)
}

/* ---------------- the tools ---------------- */

/** The slider's tools for what is selected (the mockup's lists, most used first). */
internal fun kitTools(c: KitCtl, nIssues: Int): List<DTool> {
    val app = c.app; val st = c.st
    fun t(k: String, icon: String, badge: Int? = null, red: Boolean = false, pri: Boolean = false, on: Boolean = false) = DTool(k, app.t("dzc.tool.$k"), icon, badge, red, pri, on)
    if (st.multi) return listOf(t("decor", "palette"), t("handle", "handle"), t("type", "grid"), t("mdel", "trash", red = true), t("mdone", "chk", pri = true))
    val sel = st.sel
    if (sel == null) return listOfNotNull(t("add", "plus"), t("style", "style"), t("decor", "palette"), t("handle", "handle"), t("multi", "tick"),
        t("see", "eye", on = st.inside), t("checks", "warn", badge = nIssues), t("plinth", "plinth"),
        if (c.f.roomId != null && c.f.free == null) t("auto", "kitchen") else null, t("more", "sliders"))
    if (isEndSel(sel.id)) return listOf(t("add", "plus"))
    val m = c.module(sel.id) ?: return emptyList()
    val k = slotKind(m)
    val fronts = handleFronts(m).any { it.sec < 0 }
    val doors = m.fronts.kind == "door" && m.type != "gap"
    if (sel.front != null) return listOfNotNull(t("handle", "handle"), if (doors) t("hinge", "hinge") else null, t("soft", "soft"), t("selUp", "up"))
    if (k == SK.GAP) return listOf(t("add", "plus"), t("closeGap", "closeg"))
    if (k == SK.FILLER) return listOf(t("width", "ruler"), t("decor", "palette"), t("move", "move"), t("del", "trash", red = true))
    val del = t("del", "trash", red = true)
    if (isUpper(m)) {
        if (m.app == "hood") return listOf(t("width", "ruler"), t("align", "align"), t("copy", "copy"), t("move", "move"), del)
        return listOfNotNull(if (typeable(m)) t("type", "grid") else null, t("width", "ruler"), t("height", "height"), t("align", "align"), t("decor", "palette"),
            if (fronts) t("handle", "handle") else null, if (m.fronts.kind != "panel") t("in", "shelves") else null, t("copy", "copy"),
            if (k != SK.CORNER) t("move", "move") else null, t("depth", "depth"), if (fronts) t("soft", "soft") else null, if (doors) t("hinge", "hinge") else null,
            t("detail", "sliders"), del)
    }
    if (m.app == "fridge") return listOf(t("width", "ruler"), t("move", "move"), del)
    return listOfNotNull(if (typeable(m)) t("type", "grid") else null, t("width", "ruler"), if (m.type != "gap") t("decor", "palette") else t("decor", "palette"),
        if (fronts) t("handle", "handle") else null, if (m.app != "hob" && m.type != "gap" && m.fronts.kind != "panel") t("in", "shelves") else null,
        if (k != SK.CORNER) t("copy", "copy") else null, if (uz.metrx.app.furniture.movable(m)) t("move", "move") else null,
        if (m.type != "gap") t("depth", "depth") else null, t("plinth", "plinth"), if (fronts) t("soft", "soft") else null, if (doors) t("hinge", "hinge") else null,
        t("detail", "sliders"), del)
}

/** A tool tapped: an action at once, or its options in the slider's place. */
internal fun kTool(c: KitCtl, k: String) {
    val st = c.st; val app = c.app
    val m = c.selM
    when (k) {
        "multi" -> { st.multi = true; st.ticks = setOfNotNull(m?.id?.takeIf { slotKind(m) != SK.GAP }); st.sel = null; st.strip = null; st.peek = null }
        "mdone" -> { st.multi = false; st.ticks = emptySet(); st.strip = null }
        "mdel" -> kDeleteMany(c)
        "see" -> { st.inside = !st.inside; app.haptic(Hap.TICK) }
        "align" -> m?.let { kAlign(c, it) }
        "copy" -> m?.let { kCopy(c, it) }
        "del" -> m?.let { kDelete(c, it, null) }
        "closeGap" -> m?.let { kCloseGap(c, it) }
        "selUp" -> st.sel = st.sel?.copy(front = null)
        "detail" -> m?.let { app.sheet = Sheet.FModule(c.p.id, c.f.id, it.id) }
        "more" -> app.sheet = Sheet.DzcMore(c.p.id, c.f.id, "kitchen")
        "auto" -> c.f.roomId?.let { app.push(Route.AutoKitchen(c.p.id, it, c.f.id)) }
        else -> { st.strip = k; st.scope = "one"; st.peek = null; if (k == "in" && m != null) st.peek = m.id }
    }
}

/* ---------------- the actions ---------------- */

/** The row of [m] as slots and its index. */
private fun rowOf(c: KitCtl, m: Module): Pair<List<Slot>, Int> { val row = kRow(c.f, c.run, isUpper(m)); return row to row.indexOfFirst { it.id == m.id } }

private fun change(c: KitCtl, fn: (Furniture) -> Furniture) = c.app.kit.change(c.app, c.p.id, c.f.id, fn)

internal fun kSetWidth(c: KitCtl, m: Module, nw: Int, why: String? = null) {
    val app = c.app
    val (row, i) = rowOf(c, m)
    if (i < 0 || nw == m.w) return
    val r = resize(row, i, nw)
    if (!r.ok) { app.dzcWarn(when (r.why) { "min" -> app.t("dzc.minW", "v" to r.limit); "max" -> app.t("dzc.maxW", "v" to r.limit); else -> app.t("dzc.noAbsorb") }); return }
    change(c) { x -> applyRow(x, c.run.wall, isUpper(m), r.row, c.ws) }
    app.dzcDone(c.p.id, c.f.id, (why?.let { "$it · " } ?: "") + widthMsg(app, c, m, m.w, nw, r))
}

internal fun kSetHeight(c: KitCtl, m: Module, nh: Int) {
    val app = c.app
    if (nh == m.h) return
    // its top stays where it is
    val top = m.elev + m.h
    change(c) { x -> x.copy(modules = x.modules.map { if (it.id == m.id) it.copy(h = nh, elev = top - nh) else it }) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.heightMsg", "m" to app.modName(m), "a" to m.h, "b" to nh))
}

private fun kAlign(c: KitCtl, m: Module) {
    val app = c.app
    val cx = m.x + m.w / 2
    val b = c.f.modules.firstOrNull { it.wall == m.wall && !isUpper(it) && slotKind(it) != SK.GAP && cx >= it.x && cx < it.x + it.w }
    if (b == null) { app.dzcWarn(app.t("dzc.alignNone")); return }
    if (b.x == m.x && b.w == m.w) { app.say("dzc.alignAlready", "m" to app.modName(b)); return }
    val (row, i) = rowOf(c, m)
    val out = uz.metrx.app.furniture.alignTo(row, i, b.x - c.run.upStart, b.w)
    if (out == null) { app.dzcWarn(app.t("dzc.alignNo")); return }
    change(c) { x -> applyRow(x, c.run.wall, true, out, c.ws) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.aligned", "m" to app.modName(m), "b" to app.modName(b)))
}

private fun kCopy(c: KitCtl, m: Module) {
    val app = c.app
    val (row, i) = rowOf(c, m)
    val nid = uid()
    val p = copyRight(row, i, nid)
    if (!p.ok) { app.dzcWarn(app.t("dzc.copyNo", "g" to p.free, "w" to m.w)); return }
    val cp = m.copy(id = nid, label = "")
    change(c) { x -> applyRow(x, c.run.wall, isUpper(m), p.row, c.ws, mapOf(nid to cp)) }
    c.st.sel = DSel(nid)
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.copied", "m" to app.modName(m)) + took(app, c, p))
}

/** " · To‘ldiruvchi −50, Bo‘sh joy −400". */
private fun took(app: App, c: KitCtl, p: Planned): String = if (p.took.isEmpty()) "" else " · " + p.took.joinToString(", ") { (id, v) ->
    (if (id == END_ID) app.t("dzc.endGap") else c.module(id)?.let { shortName(app, it) } ?: app.t("dzc.gap")) + " −$v"
}

internal fun kDelete(c: KitCtl, m: Module, why: String?) {
    val app = c.app
    val (row, i) = rowOf(c, m)
    if (i < 0) return
    val out = deleteToGap(row, i)
    change(c) { x -> applyRow(x, c.run.wall, isUpper(m), out, c.ws) }
    c.st.clear()
    app.dzcDone(c.p.id, c.f.id, (why?.let { "$it · " } ?: "") + app.t("dzc.deleted", "m" to app.modName(m), "w" to m.w))
}

private fun kDeleteMany(c: KitCtl) {
    val app = c.app; val st = c.st
    val ids = st.ticks.filter { id -> c.module(id) != null }
    if (ids.isEmpty()) { app.dzcWarn(app.t("dzc.tickFirst")); return }
    change(c) { x ->
        var y = x
        ids.forEach { id ->
            val m = y.modules.firstOrNull { it.id == id } ?: return@forEach
            val r = c.runs.firstOrNull { it.wall == m.wall } ?: return@forEach
            val row = kRow(y, r, isUpper(m)); val i = row.indexOfFirst { it.id == id }
            if (i >= 0) y = pack(applyRow(y, m.wall ?: "", isUpper(m), deleteToGap(row, i), c.ws), c.runs)
        }
        y
    }
    st.ticks = emptySet()
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.deletedN", "n" to ids.size))
}

private fun kCloseGap(c: KitCtl, m: Module) {
    val app = c.app
    val (row, i) = rowOf(c, m)
    val p = closeGap(row, i, uid())
    if (!p.ok) { app.dzcWarn(app.t("dzc.closeEnd")); return }
    change(c) { x -> applyRow(x, c.run.wall, isUpper(m), p.row, c.ws) }
    c.st.clear()
    val grew = p.grew
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.closed") + if (grew != null) " · " + (if (grew.first == END_ID) app.t("dzc.endGap") else app.t("dzc.endGrows")) + " → ${grew.second} " + app.t("u.mm") else "")
}

private fun kMoveBy(c: KitCtl, m: Module, d: Int) {
    val app = c.app
    val (row, i) = rowOf(c, m)
    val out = moveBy(row, i, d)
    if (out == null) { app.dzcWarn(app.t("dzc.moveNo")); return }
    change(c) { x -> applyRow(x, c.run.wall, isUpper(m), out, c.ws) }
    app.dzcDone(c.p.id, c.f.id, app.t(if (d < 0) "dzc.movedL" else "dzc.movedR", "m" to app.modName(m)))
}

/** What Belgilash or the selection applies to. */
private fun targets(c: KitCtl): List<Module> = if (c.st.multi) c.st.ticks.mapNotNull { c.module(it) } else listOfNotNull(c.selM)

private fun kSetType(c: KitCtl, key: String) {
    val app = c.app
    val ws2 = wsOf(c.f, c.ws)
    val ts = targets(c).filter { typeable(it) && (key in uz.metrx.app.furniture.WALL_TYPES) == (it.type == "wall") }
    if (ts.isEmpty()) { app.dzcWarn(app.t(if (c.st.multi) "dzc.typeLow" else "dzc.typeNo")); return }
    val made = ts.associate { it.id to retype(it, key, ws2) }
    if (made.values.all { it == null }) { app.dzcWarn(app.t("dzc.typeDw")); return }
    change(c) { x -> x.copy(modules = x.modules.map { m -> made[m.id] ?: m }) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.typed", "t" to app.t("dzc.t.$key")) + if (ts.size > 1) " · " + app.t("dzc.nMods", "n" to ts.size) else "")
}

private fun kSetDecor(c: KitCtl, colour: String) {
    val app = c.app; val st = c.st
    val f = c.f
    val l = f.look
    val finish = l?.finish?.ifEmpty { null } ?: if (f.mats.front.startsWith("ag_")) "gloss" else "matte"
    val b = boardFor(colour, finish, l?.style ?: "flat")
    val name = frontName(app, colour)
    val m = c.selM
    when {
        st.multi -> {
            val ids = st.ticks
            if (ids.isEmpty()) { app.dzcWarn(app.t("dzc.tickFirst")); return }
            change(c) { x -> x.copy(modules = x.modules.map { if (it.id in ids) it.copy(front = b) else it }) }
            app.dzcDone(c.p.id, c.f.id, app.t("dzc.decorN", "d" to name, "n" to ids.size))
        }
        m == null || st.scope == "all" -> {
            change(c) { x -> clearOwnFronts(withLook(x) { it }).let { y -> y.copy(mats = y.mats.copy(front = b, frontUp = null)) } }
            app.dzcDone(c.p.id, c.f.id, app.t("dzc.decorAll", "d" to name))
        }
        st.scope == "row" -> {
            val up = isUpper(m)
            change(c) { x ->
                val y = withLook(x) { it }
                val mats = if (up) y.mats.copy(frontUp = b) else y.mats.copy(front = b, frontUp = y.mats.frontUp ?: y.mats.front)
                y.copy(mats = mats, modules = y.modules.map { if (isUpper(it) == up) it.copy(front = null) else it })
            }
            app.dzcDone(c.p.id, c.f.id, app.t(if (up) "dzc.decorUp" else "dzc.decorLow", "d" to name))
        }
        else -> {
            change(c) { x -> x.copy(modules = x.modules.map { if (it.id == m.id) it.copy(front = b) else it }) }
            app.dzcDone(c.p.id, c.f.id, app.t("dzc.decorOne", "d" to name, "m" to app.modName(m)))
        }
    }
}

/** A colour's or wood's name. */
fun frontName(app: App, k: String) = if (LOOK_WOOD_KEYS.contains(k)) app.t("lk.w.$k") else app.t("lk.c.$k")
private val LOOK_WOOD_KEYS = uz.metrx.app.furniture.LOOK_WOODS.map { it.key }.toSet()

/** The handle's choices: bar, long, knob, gola (kitchens), none; the type is the whole piece's, "none" can be one front's. */
private fun kSetHandle(c: KitCtl, type: String) {
    val app = c.app; val st = c.st
    val m = c.selM
    val fi = st.sel?.front
    val name = app.t("dzc.h.$type")
    val one = !st.multi && m != null && st.scope != "all"
    if (st.multi || one) {
        val ts = targets(c)
        if (ts.isEmpty()) { app.dzcWarn(app.t("dzc.tickFirst")); return }
        change(c) { x ->
            // a type for one front: that front gets a handle, every handle of the piece that type
            var y = if (type != "push" && handleType(x) != type) withHandleType(x, type) else x
            y = y.copy(modules = y.modules.map { mm ->
                if (ts.none { it.id == mm.id }) mm
                else {
                    val keys = handleFronts(mm).filter { it.sec < 0 }.let { fr -> if (fi != null && !st.multi) listOfNotNull(fr.getOrNull(fi)) else fr }.map { it.key }
                    keys.fold(mm) { a, k -> withHandle(a, k, type != "push") }
                }
            })
            y
        }
        app.dzcDone(c.p.id, c.f.id, when {
            st.multi -> app.t("dzc.handleN", "h" to name, "n" to ts.size)
            fi != null -> app.t("dzc.handleFront", "h" to name, "f" to kFrontNameT(app, m!!, fi))
            else -> app.t("dzc.handleOne", "h" to name, "m" to app.modName(m!!))
        } + if (type != "push" && handleType(c.f) != type) " · " + app.t("dzc.handleTypeAll") else "")
        return
    }
    change(c) { x -> withLook(withHandleType(x, type)) { it } }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.handleAll", "h" to name))
}

private fun kFrontNameT(app: App, m: Module, i: Int): String {
    val fr = handleFronts(m).filter { it.sec < 0 }
    val f = fr.getOrNull(i) ?: return app.t("dzc.front")
    return app.t(if (f.drawer) "hd.uDrawer" else "hd.uDoor", "n" to i + 1)
}

private fun kSetHinge(c: KitCtl, side: String) {
    val app = c.app
    val m = c.selM ?: return
    val fi = c.st.sel?.front
    change(c) { x -> x.copy(modules = x.modules.map { if (it.id == m.id) withHinge(it, fi ?: -1, side) else it }) }
    app.dzcDone(c.p.id, c.f.id, app.t(if (side == "L") "dzc.hingeL" else "dzc.hingeR", "m" to (if (fi != null) kFrontNameT(app, m, fi) else app.modName(m))))
}

private fun kSetSoft(c: KitCtl, on: Boolean) {
    val app = c.app
    val m = c.selM ?: return
    val all = c.st.scope == "all"
    change(c) { x -> x.copy(modules = x.modules.map { if (all || it.id == m.id) it.copy(soft = on) else it }) }
    app.dzcDone(c.p.id, c.f.id, app.t(if (on) "dzc.softOn" else "dzc.softOff") + " · " + (if (all) app.t("dzc.toAll") else app.modName(m)))
}

private fun kSetDepth(c: KitCtl, v: Int) {
    val app = c.app
    val m = c.selM ?: return
    val up = isUpper(m)
    val row = c.st.scope == "row"
    change(c) { x -> x.copy(modules = x.modules.map { if ((it.id == m.id || (row && isUpper(it) == up && it.type == m.type)) && it.type != "filler" && it.type != "gap") it.copy(d = v) else it }) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.depthMsg", "v" to v) + " · " + (if (row) app.t(if (up) "dzc.rowUpAll" else "dzc.rowLowAll") else app.modName(m)))
}

/** The kitchen's base: a plinth, adjustable legs (the plinth off) or metal legs; and the legs' height, the units following. */
private fun kSetBase(c: KitCtl, kind: String?, h: Int?) {
    val app = c.app
    val now = wsOf(c.f, c.ws).legH
    change(c) { x ->
        var y = x
        if (kind != null) {
            val kx = y.kx ?: KExtras()
            y = withLook(y) { it.copy(legs = kind == "metal") }.copy(kx = kx.copy(plinth = kind == "plinth"))
        }
        if (h != null && h != now) y = y.copy(baseH = h, modules = y.modules.map { if (it.app == "fridge" || it.elev == 0) it else it.copy(elev = it.elev + (h - now)) })
        y
    }
    val k = kind ?: baseKind(c.f)
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.baseMsg", "t" to app.t("dzc.base.$k"), "v" to (h ?: now)))
}

fun baseKind(f: Furniture) = when { f.look?.legs == true -> "metal"; f.kx?.plinth == true -> "plinth"; else -> "legs" }

private fun kSetStyle(c: KitCtl, id: String) {
    val app = c.app
    change(c) { x -> clearOwnFronts(withPreset(x, id, ws = app.settings.workshop)) }
    app.dzcDone(c.p.id, c.f.id, app.t("lk.applied", "n" to app.t("lk.p.$id")))
}

private fun kShelves(c: KitCtl, d: Int) {
    val app = c.app
    val ts = targets(c).filter { it.fronts.kind != "drawer" && it.type != "gap" && it.type != "filler" }
    if (ts.isEmpty()) return
    val cur = ts.first().inserts.filter { it.kind == "shelf" || it.kind == "glass" }.sumOf { it.qty }
    val n = (cur + d).coerceIn(0, 6)
    change(c) { x -> x.copy(modules = x.modules.map { m -> if (ts.none { it.id == m.id }) m else {
        val k = if (uz.metrx.app.furniture.glassDoors(m)) "glass" else "shelf"
        m.copy(inserts = m.inserts.filter { it.kind != "shelf" && it.kind != "glass" } + if (n > 0) listOf(Insert(k, qty = n)) else emptyList())
    } }) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.shelvesMsg", "n" to n))
}

private fun kDrawers(c: KitCtl, d: Int) {
    val app = c.app
    val m = c.selM ?: return
    val n = (m.fronts.n + d).coerceIn(2, 5)
    if (n == m.fronts.n) return
    change(c) { x -> x.copy(modules = x.modules.map { if (it.id == m.id) uz.metrx.app.furniture.frontsChanged(it, it.copy(fronts = Fronts("drawer", n))) else it }) }
    app.dzcDone(c.p.id, c.f.id, app.t("dzc.drawersMsg", "n" to n))
}

/** A tile tapped: into the selected gap, else the first gap (or free end) that fits on this wall, then the others. */
private fun kTileTap(c: KitCtl, t: KTile) {
    val app = c.app
    val sel = c.st.sel
    val walls = listOf(c.run) + c.runs.filter { it.wall != c.run.wall }
    for (r in walls) {
        if (t.upper && r.wall == ISLAND) continue
        val row = kRow(c.f, r, t.upper)
        val pref = row.indexOfFirst { s -> sel != null && r.wall == c.run.wall && (s.id == sel.id || (isEndSel(sel.id) && s.kind == SK.END && endUpper(sel.id) == t.upper)) }
        val order = (if (pref >= 0) listOf(pref) else emptyList()) + row.indices.filter { it != pref }
        for (i in order) {
            val s = row[i]
            if (s.kind != SK.GAP && s.kind != SK.END) continue
            val m = tileModule(t, c.ws, r.wall)
            val pl = intoGap(row, i, slotOf(m), tileFixed(t))
            if (!pl.ok) continue
            kApplyTile(c, r, t, pl)
            return
        }
    }
    app.dzcWarn(app.t("dzc.noGap"))
}

private fun kApplyTile(c: KitCtl, r: Run, t: KTile, pl: Planned) {
    val app = c.app
    val m = tileModule(t, c.ws, r.wall, pl.w).copy(id = pl.id ?: uid())
    change(c) { x -> applyRow(x, r.wall, t.upper, pl.row, c.ws, mapOf(m.id to m)) }
    if (r.wall != c.run.wall) { val rt = app.top; if (rt is Route.Kitchen) app.setTop(rt.copy(wall = r.wall)) }
    c.st.sel = DSel(m.id)
    app.haptic(Hap.CONFIRM)
    app.dzcDone(c.p.id, c.f.id, app.t(if (pl.into != null) "dzc.putGap" else "dzc.putBetween", "m" to app.modName(m)) + (if (pl.adapted) " · " + app.t("dzc.adapted", "w" to t.w) else "") + took(app, c, pl))
}

/* ---------------- the options ---------------- */

@Composable
private fun KitOptions(c: KitCtl, k: String, found: List<FCheck>) {
    val app = c.app; val st = c.st
    val m = c.selM
    val back = { st.strip = null; st.peek = null; st.scope = "one" }
    val fi = st.sel?.front
    val scopeTxt = when { st.multi -> if (st.ticks.isEmpty()) tr("dzc.tickFirst") else tr("dzc.nTicked", "n" to st.ticks.size); m == null -> tr("dzc.wholeK"); fi != null -> tr("dzc.onlyF", "f" to kFrontName(m, fi)); else -> tr("dzc.onlyM") }
    when (k) {
        "add" -> AddOptions(c, back)
        "type" -> {
            val up = !st.multi && m?.type == "wall"
            val cur = if (st.multi) null else m?.let(::curType)
            OptRow(tr("dzc.tool.type"), scopeTxt + if (st.multi) " · " + tr("dzc.lowOnly") else "", back) {
                (if (up) uz.metrx.app.furniture.WALL_TYPES else uz.metrx.app.furniture.BASE_TYPES).forEach { key ->
                    OptChip(tr("dzc.t.$key"), cur == key, glyph = key) { kSetType(c, key) }
                }
            }
        }
        "width" -> m?.let { mm ->
            val (row, i) = rowOf(c, mm)
            if (i < 0) return@let
            val mx = maxW(row, i)
            OptRow(tr("dzc.tool.width"), tr("dzc.widthSub", "v" to mm.w, "m" to mx), back) {
                (if (mm.type == "filler") listOf(20, 30, 50, 80, 100).filter { it <= mx } else candidates(row[i], mx)).forEach { v -> OptChip("$v", v == mm.w) { kSetWidth(c, mm, v) } }
                OptChip(tr("dzc.write"), false) { app.sheet = Sheet.DzcNum(c.p.id, c.f.id, mm.id, "w") }
            }
        }
        "height" -> m?.let { mm ->
            OptRow(tr("dzc.tool.height"), tr("dzc.heightSub", "v" to mm.h), back) {
                H_SNAPS.forEach { v -> OptChip("$v", v == mm.h) { kSetHeight(c, mm, v) } }
                OptChip(tr("dzc.write"), false) { app.sheet = Sheet.DzcNum(c.p.id, c.f.id, mm.id, "h") }
            }
        }
        "decor" -> {
            val cur = if (st.multi) null else m?.let { colourOf(frontOf(c.f, it)) } ?: colourOf(c.f.mats.front)
            val scope: (@Composable () -> Unit)? = if (st.multi || m == null) null else { { ScopeSeg(listOf("one" to tr("dzc.s.one"), "row" to tr("dzc.s.row"), "all" to tr("dzc.s.allK")), st.scope) { st.scope = it } } }
            OptRow(tr("dzc.tool.decor"), if (scope == null) scopeTxt else "", back, scope) {
                FRONT_KEYS.forEach { (key, rgb, _) -> OptChip(frontName(app, key), cur == key, swatch = hex(rgb)) { kSetDecor(c, key) } }
            }
        }
        "handle" -> {
            val type = handleType(c.f)
            val curOne = if (m != null && !st.multi) {
                val keys = handleFronts(m).filter { it.sec < 0 }.let { fr -> if (fi != null) listOfNotNull(fr.getOrNull(fi)) else fr }
                if (keys.isNotEmpty() && keys.none { hasHandle(m, it.key) }) "push" else type
            } else type
            val scope: (@Composable () -> Unit)? = if (st.multi || m == null) null else { { ScopeSeg(listOf("one" to tr("dzc.s.one"), "all" to tr("dzc.s.all")), st.scope) { st.scope = it } } }
            OptRow(tr("dzc.tool.handle"), if (scope == null) scopeTxt else tr("dzc.handleNote"), back, scope) {
                listOf("bar", "long", "knob", "gola", "push").forEach { h -> OptChip(tr("dzc.h.$h"), curOne == h, glyph = "h-$h") { kSetHandle(c, h) } }
            }
        }
        "hinge" -> m?.let { mm ->
            val n = mm.fronts.n.coerceAtLeast(1)
            val right = kHingeRight(mm, fi ?: 0, n)
            OptRow(tr("dzc.tool.hinge"), if (fi != null) kFrontName(mm, fi) else tr("dzc.allDoors"), back) {
                OptChip(tr("dzc.hL"), !right, glyph = "hg-L") { kSetHinge(c, "L") }
                OptChip(tr("dzc.hR"), right, glyph = "hg-R") { kSetHinge(c, "R") }
            }
        }
        "soft" -> m?.let { mm ->
            OptRow(tr("dzc.tool.soft"), if (fi != null) tr("dzc.softMod") else "", back, { ScopeSeg(listOf("one" to tr("dzc.s.one"), "all" to tr("dzc.s.all")), st.scope) { st.scope = it } }) {
                OptChip(tr("dzc.on"), mm.soft, glyph = null) { kSetSoft(c, true) }
                OptChip(tr("dzc.off"), !mm.soft) { kSetSoft(c, false) }
                OptNote(tr("dzc.softNote"))
            }
        }
        "in" -> {
            val mm = if (st.multi) targets(c).firstOrNull() else m
            if (mm == null) { OptRow(tr("dzc.tool.in"), tr("dzc.tickFirst"), back) {}; return }
            if (mm.fronts.kind == "drawer" && !st.multi) OptRow(tr("dzc.tool.in"), tr("dzc.drawersOpen", "m" to modName(mm)), back) {
                OptStepper(tr("dzc.drawers"), mm.fronts.n, 2, 5) { v -> kDrawers(c, v - mm.fronts.n) }
            } else OptRow(tr("dzc.tool.in"), scopeTxt + " · " + tr("dzc.doorOpen"), back) {
                val n = mm.inserts.filter { it.kind == "shelf" || it.kind == "glass" }.sumOf { it.qty }
                OptStepper(tr("dzc.shelves"), n, 0, 6) { v -> kShelves(c, v - n) }
                OptChip(tr(if (st.peek != null) "dzc.closeDoor" else "dzc.openDoor"), st.peek != null, glyph = null) { st.peek = if (st.peek != null) null else mm.id }
            }
        }
        "move" -> m?.let { mm ->
            OptRow(tr("dzc.tool.move"), modName(mm), back) {
                OptChip("← " + tr("dzc.left"), false) { kMoveBy(c, mm, -1) }
                OptChip(tr("dzc.right") + " →", false) { kMoveBy(c, mm, 1) }
                OptNote(tr("dzc.moveNote"))
            }
        }
        "depth" -> m?.let { mm ->
            val opts = if (isUpper(mm)) listOf(280, 300, 320, 350) else if (mm.type == "tall") listOf(450, 560, 600, 650) else listOf(300, 450, 560, 600)
            OptRow(tr("dzc.tool.depth"), tr("dzc.depthSub", "v" to mm.d), back, { ScopeSeg(listOf("one" to tr("dzc.s.one"), "row" to tr("dzc.s.row")), st.scope) { st.scope = it } }) {
                opts.forEach { v -> OptChip("$v " + tr("u.mm"), v == mm.d) { kSetDepth(c, v) } }
            }
        }
        "plinth" -> {
            val bk = baseKind(c.f)
            val h = wsOf(c.f, c.ws).legH
            OptRow(tr("dzc.tool.plinth"), tr("dzc.plinthSub", "t" to tr("dzc.base.$bk"), "v" to h), back) {
                listOf("plinth", "legs", "metal").forEach { k2 -> OptChip(tr("dzc.base.$k2"), bk == k2, glyph = k2) { kSetBase(c, k2, null) } }
                val hs = listOf(80, 100, 120, 150)
                val i = hs.indexOf(h).let { if (it < 0) hs.indexOfFirst { v -> v >= h }.coerceAtLeast(0) else it }
                OptStepper(tr("dzc.heightMm"), h, hs.first(), hs.last()) { v -> val j = if (v > h) (i + 1).coerceAtMost(hs.lastIndex) else (i - 1).coerceAtLeast(0); kSetBase(c, null, if (hs[i] != h) hs[i] else hs[j]) }
            }
        }
        "style" -> OptRow(tr("dzc.tool.style"), tr("dzc.styleSub"), back) {
            uz.metrx.app.furniture.DESIGN_PRESETS.forEach { ps -> OptChip(tr("lk.p.${ps.id}"), uz.metrx.app.furniture.presetOf(c.f) == ps.id, swatch = hex(lookRgb(ps.low))) { kSetStyle(c, ps.id) } }
        }
        "checks" -> {
            val q = found.filter { it.level != "ok" }
            OptRow(tr("dzc.tool.checks"), if (q.isEmpty()) tr("dzc.allOk") else tr("dzc.nIssues", "n" to q.size), back) {
                if (q.isEmpty()) OptChip(tr("kt.allOk"), true, glyph = null) {}
                q.forEach { x -> OptChip(checkText(x, c.f), false, red = x.level == "err") {
                    val mm = x.mid?.let { id -> c.f.modules.firstOrNull { it.id == id } } ?: return@OptChip
                    if (mm.wall != c.run.wall) { val rt = app.top; if (rt is Route.Kitchen) app.setTop(rt.copy(wall = mm.wall)) }
                    st.sel = DSel(mm.id); st.strip = null; st.cmin = false
                } }
            }
        }
        else -> { st.strip = null }
    }
}

private fun lookRgb(k: String) = uz.metrx.app.furniture.LOOK_COLOURS.firstOrNull { it.key == k }?.rgb ?: uz.metrx.app.furniture.LOOK_WOODS.firstOrNull { it.key == k }?.rgb ?: "#CCCCCC"

/** Qo‘shish: the categories, then the tiles; a tile dragged up onto the wall, or tapped into the first gap. */
@Composable
private fun AddOptions(c: KitCtl, back: () -> Unit) {
    val st = c.st
    val gapSel = st.sel?.let { s -> isEndSel(s.id) || c.module(s.id)?.let { slotKind(it) == SK.GAP } == true } == true
    Column(Modifier.fillMaxWidth()) {
        OptRow(tr("dzc.tool.add"), tr(if (gapSel) "dzc.addSubGap" else "dzc.addSub"), back, key = "cats") {
            K_CATS.forEach { cat -> OptChip(tr("dzc.cat.$cat") + " " + K_TILES.count { it.cat == cat && (!it.upper || c.run.wall != ISLAND) }, st.cat == cat) { st.cat = cat } }
        }
        FadeRow("tiles:" + st.cat, Modifier.fillMaxWidth().padding(start = 6.dp, bottom = 6.dp)) {
            K_TILES.filter { it.cat == st.cat && (!it.upper || c.run.wall != ISLAND) }.forEach { t -> Tile(c, t) }
        }
    }
}

/** One tile: the unit drawn small with its width; dragged up it goes onto the wall, tapped into a gap. */
@Composable
private fun Tile(c: KitCtl, t: KTile) {
    val app = c.app
    var origin by remember { mutableStateOf(Offset.Zero) }
    val ws = c.ws
    Column(Modifier.padding(horizontal = 3.dp).width(84.dp).clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .05f))
        .onGloballyPositioned { origin = it.boundsInRoot().topLeft }
        .pointerInput(t) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                var dragging = false
                while (true) {
                    val ev = awaitPointerEvent()
                    val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                    val dlt = ch.position - down.position
                    if (!ch.pressed) {
                        if (dragging) kTileEnd(c) else if (dlt.getDistance() < viewConfiguration.touchSlop) kTileTap(c, t)
                        break
                    }
                    if (!dragging) {
                        if (-dlt.y > viewConfiguration.touchSlop && abs(dlt.y) > abs(dlt.x)) {
                            if (app.top.let { it is Route.Kitchen && it.d3 }) { app.say("dzc.drag2d"); break }
                            dragging = true
                        } else if (abs(dlt.x) > viewConfiguration.touchSlop) break
                    }
                    if (dragging) { ch.consume(); kTileMove(c, t, origin + ch.position) }
                }
                if (dragging && c.tile != null) kTileEnd(c, cancel = true)
            }
        }.padding(6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        ModGlyph(tileModule(t, ws, "A"), ws)
        Text(tr("dzc.tile.${t.label}"), style = ui(11.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text("${t.w}" + if (t.upper) " · " + tr("dzc.up") else "", style = ui(11f, 600, G.ink2), maxLines = 1)
    }
}

private fun kTileMove(c: KitCtl, t: KTile, root: Offset) {
    val local = root - Offset(c.canvas.left, c.canvas.top)
    val over = c.canvas.hits(root) && root.y < c.panel.top
    if (!over) { c.tile = KTileDrag(t, root, false, null); return }
    if (t.upper && c.run.wall == ISLAND) { c.tile = KTileDrag(t, root, false, null); return }
    val u = (c.mmX(local) - c.rowStart(t.upper)).roundToInt()
    val m = tileModule(t, c.ws, c.run.wall)
    val pl = insertAt(kRow(c.f, c.run, t.upper), u, slotOf(m), tileFixed(t))
    c.tile = KTileDrag(t, root, true, pl, u)
}

private fun kTileEnd(c: KitCtl, cancel: Boolean = false) {
    val d = c.tile ?: return
    c.tile = null
    if (cancel || !d.over) return
    val pl = d.plan ?: return
    if (!pl.ok) { c.app.dzcWarn(planWhy(c.app, pl, d.t)); return }
    kApplyTile(c, c.run, d.t, pl)
}

/** A module drawn small, as it looks on the wall (the tiles of Qo‘shish). */
@Composable
internal fun ModGlyph(m0: Module, ws: Workshop) {
    val mats = LocalApp.current.settings.mats
    Canvas(Modifier.size(52.dp).clip(RoundedCornerShape(10.dp)).background(G.solid).padding(5.dp)) {
        val lift = if (isUpper(m0)) m0.elev else 0
        val H = max(m0.h + m0.elev - lift + if (m0.app == "sink") 300 else 0, 800)
        val lay = KLay(max(m0.w, 600), H, 100f, false)
        val k = min(size.width / lay.vw, size.height / lay.vh)
        val one = m0.copy(elev = m0.elev - lift, x = (lay.L - m0.w) / 2)
        withTransform({ translate((size.width - lay.vw * k) / 2f, (size.height - lay.vh * k) / 2f); scale(k, k, pivot = Offset.Zero) }) {
            val front = boardColor(mats, "ldsp16k")
            drawUnit(lay, one, ws, front, hex("#F5F5F2"), max(.8f, ws.gap10 / 10f * lay.s))
            appliance(lay, one, ws)
        }
    }
}

/* ---------------- the number sheet ---------------- */

/** The bubble's typed width or height of kitchen module [s.mid]. */
@Composable
fun KitNumSheet(s: Sheet.DzcNum) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val m = f.modules.firstOrNull { it.id == s.mid } ?: run { app.sheet = null; return }
    val room = roomOf(p, f)
    val runs = kRuns(f, room, app.settings.angleSnap)
    val run = runs.firstOrNull { it.wall == m.wall } ?: run { app.sheet = null; return }
    val c = KitCtl().also { it.app = app; it.p = p; it.f = f; it.run = run; it.runs = runs; it.ws = app.settings.workshop; it.st = app.dzc(f.id); it.room = room }
    if (s.field == "h") {
        DzcNumSheet(tr("dzc.tool.height") + " · " + modName(m), m.h, 200, 1200, onClose = { app.sheet = null }) { v -> app.sheet = null; kSetHeight(c, m, v) }
        return
    }
    val row = kRow(f, run, isUpper(m)); val i = row.indexOfFirst { it.id == m.id }
    val mx = if (i >= 0) maxW(row, i) else m.w
    val lo = if (m.type == "filler") 10 else 150
    val allowed = allowedW(m)?.takeIf { m.type != "filler" }
    DzcNumSheet(tr("dzc.tool.width") + " · " + modName(m), m.w, lo, max(lo, mx), allowed?.let { tr("dzc.allowedW", "v" to it.joinToString(", ")) }, onClose = { app.sheet = null }) { v ->
        if (allowed != null && v !in allowed) { app.dzcWarn(app.t("dzc.allowedW", "v" to allowed.joinToString(", "))); return@DzcNumSheet }
        app.sheet = null; kSetWidth(c, m, v)
    }
}

@Suppress("unused") private fun keep(x: Rect) = x
