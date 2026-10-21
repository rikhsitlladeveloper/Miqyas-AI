package uz.metrx.app.ui.furniture

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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.curSuffix
import uz.metrx.app.core.moneyStr
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.uid
import uz.metrx.app.furniture.FCheck
import uz.metrx.app.furniture.Fronts
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.Insert
import uz.metrx.app.furniture.K_TOP
import uz.metrx.app.furniture.K_WALL_H
import uz.metrx.app.furniture.LIB_APP
import uz.metrx.app.furniture.LIB_LOW
import uz.metrx.app.furniture.LIB_TALL
import uz.metrx.app.furniture.LIB_UP
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Run
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.autoFill
import uz.metrx.app.furniture.K_CORNER
import uz.metrx.app.furniture.checks
import uz.metrx.app.furniture.costOf
import uz.metrx.app.furniture.fillOf
import uz.metrx.app.furniture.frontSizes
import uz.metrx.app.furniture.hardwareOf
import uz.metrx.app.furniture.isUpper
import uz.metrx.app.furniture.kindOf
import uz.metrx.app.furniture.pack
import uz.metrx.app.furniture.partsOf
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.template
import uz.metrx.app.furniture.wallElev
import uz.metrx.app.furniture.worktopRuns
import uz.metrx.app.furniture.worktopTop
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.AMBER
import uz.metrx.app.ui.editor.COB
import uz.metrx.app.ui.editor.GREY_LINE
import uz.metrx.app.ui.editor.INK
import uz.metrx.app.ui.editor.INK3
import uz.metrx.app.ui.editor.PLAN_W
import uz.metrx.app.ui.editor.RED
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.editor.pc
import uz.metrx.app.ui.editor.roomGrid
import uz.metrx.app.ui.editor.text
import uz.metrx.app.ui.editor.wallFrame
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/*
 * Furniture makers, Stage 1a part 4 (furniture plan section 7; design canvas screens 7–9): new furniture in a
 * workspace, the kitchen designer (each wall seen from inside the room, its lower and upper rows to scale, the fit
 * checks), the unit library and a unit's settings. The rules are in furniture/Kitchen.kt.
 */

/* ---------------- state shared by the designer and its sheets ---------------- */

/** The kitchen designer's undo history and selected unit, kept while the app runs. */
class KitOps {
    var tick by mutableIntStateOf(0)
    var sel by mutableStateOf<String?>(null)
    private val back = HashMap<String, ArrayList<Furniture>>()
    private val fwd = HashMap<String, ArrayList<Furniture>>()
    fun canUndo(fid: String) = back[fid]?.isNotEmpty() == true
    fun canRedo(fid: String) = fwd[fid]?.isNotEmpty() == true
    /** The piece changed outside the designer (placed, taken out, new sizes): its old versions no longer apply. */
    fun forget(fid: String) { back.remove(fid); fwd.remove(fid) }

    /** Changes furniture [fid] of order [pid] and packs its rows again; the version before goes on the undo list. */
    fun change(app: App, pid: String, fid: String, f: (Furniture) -> Furniture): Furniture? {
        var old: Furniture? = null; var new: Furniture? = null
        app.store.update(pid) { p ->
            p.copy(furniture = p.furniture.map { x -> if (x.id != fid) x else repack(f(x), p, app.settings.angleSnap).also { old = x; new = it } })
        }
        val o = old ?: return null
        if (o != new) { back.getOrPut(fid) { ArrayList() }.let { it.add(o); if (it.size > 60) it.removeAt(0) }; fwd[fid]?.clear() }
        tick++
        return new
    }

    private fun step(app: App, pid: String, fid: String, from: HashMap<String, ArrayList<Furniture>>, to: HashMap<String, ArrayList<Furniture>>) {
        val prev = from[fid]?.removeLastOrNull() ?: return
        app.store.update(pid) { p -> p.copy(furniture = p.furniture.map { x -> if (x.id != fid) x else { to.getOrPut(fid) { ArrayList() }.add(x); prev } }) }
        if (prev.modules.none { it.id == sel }) sel = null
        tick++
    }
    fun undo(app: App, pid: String, fid: String) = step(app, pid, fid, back, fwd)
    fun redo(app: App, pid: String, fid: String) = step(app, pid, fid, fwd, back)
}

/** The piece's room: its measured one, or for furniture without a room the made-up room of its sizes (Free.kt). */
internal fun roomOf(p: Project, f: Furniture): Room? = if (f.roomId == null) uz.metrx.app.furniture.freeRoom(f) else p.rooms.firstOrNull { it.id == f.roomId }

/** A wall's length for the kitchen: confirmed, else the reading or the drawing's estimate (the designer says so). */
internal fun wallLen(r: Room, snap: Boolean, id: String): Int? {
    val w = walls(r, snap).firstOrNull { it.id == id } ?: return null
    return w.len ?: wallFrame(r, w, r.openings.filter { it.wall == w.id }).L
}

internal fun measured(r: Room, snap: Boolean, id: String) = walls(r, snap).firstOrNull { it.id == id }?.len != null

internal fun kRuns(f: Furniture, r: Room?, snap: Boolean): List<Run> = runsOf(f) { id -> uz.metrx.app.furniture.freeLen(f, id) ?: r?.let { wallLen(it, snap, id) } }

/** Kitchens pack their rows again after a change; a wardrobe keeps its place on the wall. */
internal fun repack(f: Furniture, p: Project, snap: Boolean): Furniture = if (f.kind != "kitchen") f else pack(f, kRuns(f, roomOf(p, f), snap))

internal fun lineOn(c: Color) = if (c.luminance() > .4f) Color(0xFF3E4A61) else Color(0xFFD5DBE5)

internal fun hex(s: String, fallback: Color = Color(0xFFF5F5F2)) = runCatching { Color(android.graphics.Color.parseColor(s)) }.getOrDefault(fallback)

@Composable
internal fun modName(m: Module) = tr("kn." + kindOf(m)) + " " + m.w

private fun App.modName(m: Module) = t("kn." + kindOf(m)) + " " + m.w

/** "720 × 560 · 2 eshik · Polkalar 1". */
@Composable
private fun modSub(m: Module): String {
    val out = arrayListOf("${m.h} × ${m.d}")
    when (m.fronts.kind) {
        "door" -> out += tr(if (m.fronts.n >= 2) "km.f2" else "km.f1")
        "drawer" -> out += tr("km.fd") + " " + m.fronts.n
    }
    m.inserts.filter { it.kind == "shelf" }.sumOf { it.qty }.let { if (it > 0) out += tr("km.shelves") + " " + it }
    return out.joinToString(" · ")
}

/** A wall's chip: "Devor A · 3400", or the island. */
@Composable
internal fun runName(f: Furniture, r: Run, withLen: Boolean = true): String =
    if (r.wall == ISLAND) tr(if (f.layout == "P") "kt.peninsula" else "kt.island")
    else (if (f.roomId == null) tr("fz.sideN", "n" to f.walls.indexOf(r.wall) + 1) else tr("kt.wallN", "w" to r.wall)) + if (withLen && r.len != null) " · ${r.len}" else ""

// the running metres the price counts (runMm): no tall units, no fridge or empty gaps
private fun runMetres(f: Furniture, en: Boolean): String {
    val v = (uz.metrx.app.furniture.runMm(f) + 50) / 100
    return "${v / 10}${if (en) "." else ","}${v % 10}"
}

/* ---------------- the drawing: one run seen from inside the room ---------------- */

internal val CORNER_FILL get() = pc(0xFFE7E5E4, 0xFF2A3042)
internal val GAP_FILL get() = pc(0xFFF1F5F9, 0xFF2B3346)
private val GLASS_DARK get() = pc(0xFF1E293B, 0xFF0B1220)
private val OPEN_FILL get() = pc(0xFFE2E6EC, 0xFF283044)

/** Where a run sits in a viewBox [vw] wide: [L] × [H] mm, with room for sizes under it when [dims]. */
internal class KLay(val L: Int, val H: Int, val vw: Float, val dims: Boolean, ext: Int = L) {
    val padX = if (dims) 18f else 6f
    val top = if (dims) 28f else 8f
    /** Units past the wall's end still show (in red), so the drawing takes the longer of the two. */
    val span = max(L, ext)
    val s = min((vw - 2 * padX) / span, (if (dims) 230f else 118f) / H)
    val x0 = padX + ((vw - 2 * padX) - span * s) / 2f
    val yF = top + H * s
    val vh = yF + if (dims) 56f else 10f
    fun x(mm: Int) = x0 + mm * s
    fun y(mm: Int) = yF - mm * s
}

/** Where the run's rows end, mm from its start. */
internal fun runExt(f: Furniture, r: Run): Int = max(fillOf(f, r, false).used + r.lowStart, fillOf(f, r, true).used + r.upStart)

internal fun runLen(f: Furniture, r: Run): Int = r.len ?: max(1200, max(fillOf(f, r, false).used + r.lowStart, fillOf(f, r, true).used + r.upStart))

internal fun roomH(room: Room?): Int = room?.dim("H")?.let { it.v ?: it.pending?.mm } ?: 2700

/** A wall seen from inside the room: its face, doors and windows. */
internal fun DrawScope.drawWallFace(lay: KLay, room: Room?, wall: String) {
    val x0 = lay.x0; val x1 = lay.x(lay.L); val yF = lay.yF; val yT = lay.y(lay.H)
    drawRect(PLAN_W, Offset(x0, yT), Size(x1 - x0, yF - yT))
    drawRect(INK, Offset(x0, yT), Size(x1 - x0, yF - yT), style = Stroke(1.2f))
    room?.openings?.filter { it.wall == wall }?.forEach { o ->
        val l = lay.x(o.off); val t = lay.y(o.sill + o.h)
        drawRect(OPEN_FILL, Offset(l, t), Size(o.w * lay.s, o.h * lay.s))
        drawRect(INK3, Offset(l, t), Size(o.w * lay.s, o.h * lay.s), style = Stroke(1f))
        if (o.type == "window") drawLine(INK3, Offset(l + o.w * lay.s / 2, t), Offset(l + o.w * lay.s / 2, lay.y(o.sill)), .8f)
    }
}

/** The run's units (lower row under the upper), the worktop, openings, site points, the selection and problems. */
internal fun DrawScope.drawRun(
    lay: KLay, f: Furniture, run: Run, room: Room?, ws: Workshop, mats: List<Mat>, sel: String?, bad: Map<String, String>, tm: TextMeasurer?
) {
    val x0 = lay.x0; val x1 = lay.x(lay.L); val yF = lay.yF; val yT = lay.y(lay.H)
    val island = run.wall == ISLAND
    if (!island) drawWallFace(lay, room, run.wall)
    drawLine(INK, Offset(x0 - 10f, yF), Offset(x1 + 10f, yF), 2f)
    val dash = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))
    // the corner unit of the wall before reaches into this wall's start
    if (run.lowStart > 0) {
        val t = lay.y(worktopTop(ws))
        drawRect(CORNER_FILL, Offset(x0, t), Size(run.lowStart * lay.s, yF - t))
        drawRect(GREY_LINE, Offset(x0, t), Size(run.lowStart * lay.s, yF - t), style = Stroke(.8f, pathEffect = dash))
    }
    if (run.upStart > 0 && !island) {
        val t = lay.y(wallElev(ws) + K_WALL_H)
        drawRect(CORNER_FILL, Offset(x0, t), Size(run.upStart * lay.s, K_WALL_H * lay.s))
        drawRect(GREY_LINE, Offset(x0, t), Size(run.upStart * lay.s, K_WALL_H * lay.s), style = Stroke(.8f, pathEffect = dash))
    }
    val front = hex(mats.firstOrNull { it.id == f.mats.front }?.rgb ?: "#CDBFAE")
    val carcass = hex(mats.firstOrNull { it.id == f.mats.carcass }?.rgb ?: "#F5F5F2")
    val wtCol = hex(mats.firstOrNull { it.id == "wt38" }?.rgb ?: "#4B4F58", Color(0xFF4B4F58))
    val mods = f.modules.filter { it.wall == run.wall }.sortedBy { if (isUpper(it)) 1 else 0 }
    val g = max(.8f, ws.gap10 / 10f * lay.s)
    mods.forEach { m -> drawUnit(lay, m, ws, front, carcass, g) }
    // the worktop over the lower row, and over the corner zone it turns into
    val wt = worktopTop(ws)
    val tops = mods.filter { !isUpper(it) && (it.type == "base" || it.type == "filler" || it.app == "dishwasher") }.map { it.x to it.x + it.w }.toMutableList()
    if (run.lowStart > 0 && tops.isNotEmpty()) tops += 0 to run.lowStart
    tops.forEach { (a, b) -> drawRect(wtCol, Offset(lay.x(a), lay.y(wt)), Size((b - a) * lay.s, max(1.5f, K_TOP * lay.s))) }
    // extras (plan 1b-1): the backsplash over the worktop, the cornice on the wall units, the LED strip under them
    val kx = f.kx
    if (kx != null && !island) {
        val spCol = hex(mats.firstOrNull { it.kind == "splash" }?.rgb ?: "#E8E2D8")
        if (kx.splash > 0) tops.forEach { (a, b) ->
            drawRect(spCol, Offset(lay.x(a), lay.y(wt + kx.splash)), Size((b - a) * lay.s, kx.splash * lay.s))
            drawRect(GREY_LINE, Offset(lay.x(a), lay.y(wt + kx.splash)), Size((b - a) * lay.s, kx.splash * lay.s), style = Stroke(.6f))
        }
        mods.filter { it.type == "wall" }.forEach { m ->
            if (kx.cornice) drawRect(front, Offset(lay.x(m.x), lay.y(m.elev + m.h + 60)), Size(m.w * lay.s, 60 * lay.s))
            if (kx.led) drawLine(Color(0xFFF2C94C), Offset(lay.x(m.x) + 1f, lay.y(m.elev) + 1f), Offset(lay.x(m.x + m.w) - 1f, lay.y(m.elev) + 1f), 1.6f)
        }
    }
    mods.forEach { m -> appliance(lay, m, ws) }
    room?.points?.filter { it.wall == run.wall && !island }?.forEach { p -> drawSitePoint(p, Offset(lay.x(p.off), lay.y(p.h)), lay.s, if (lay.dims) 6f else 3f) }
    mods.forEach { m ->
        val l = lay.x(m.x); val t = lay.y(m.elev + m.h); val w = m.w * lay.s; val h = m.h * lay.s
        when (bad[m.id]) {
            "err" -> drawRect(RED, Offset(l - 2f, t - 2f), Size(w + 4f, h + 4f), style = Stroke(1.6f, pathEffect = dash))
            "warn" -> drawRect(AMBER, Offset(l - 2f, t - 2f), Size(w + 4f, h + 4f), style = Stroke(1.4f, pathEffect = dash))
        }
        if (m.id == sel) drawRect(COB, Offset(l - 2.5f, t - 2.5f), Size(w + 5f, h + 5f), style = Stroke(3f))
    }
    // past the wall's end: red
    val ext = runExt(f, run)
    if (run.len != null && ext > run.len) {
        drawRect(RED.copy(alpha = .14f), Offset(x1, yT), Size((ext - run.len) * lay.s, yF - yT))
        drawLine(RED, Offset(x1, yT - 6f), Offset(x1, yF + 6f), 1.6f, pathEffect = dash)
    }
    if (lay.dims && tm != null) dims(lay, f, run, ws, tm)
}

private fun DrawScope.drawUnit(lay: KLay, m: Module, ws: Workshop, front: Color, carcass: Color, g: Float) {
    val l = lay.x(m.x); val r = lay.x(m.x + m.w); val t = lay.y(m.elev + m.h); val b = lay.y(m.elev)
    val w = r - l; val h = b - t
    // lines on a board follow the board, not the theme: dark on light boards, light on dark ones
    val onF = lineOn(front); val onC = lineOn(carcass)
    val dash = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))
    // legs: a plinth strip under base and tall units
    if (m.legs && m.elev > 0 && m.type != "wall") {
        drawRect(GREY_LINE.copy(alpha = .35f), Offset(l + 2f, b), Size(w - 4f, lay.yF - b))
    }
    when (m.type) {
        "gap" -> when (m.app) {
            "fridge" -> {
                drawRoundRect(GAP_FILL, Offset(l + 1f, t), Size(w - 2f, h), CornerRadius(3f))
                drawRoundRect(INK3, Offset(l + 1f, t), Size(w - 2f, h), CornerRadius(3f), style = Stroke(1f))
                val split = lay.y(m.elev + (m.h * .64f).toInt())
                drawLine(INK3, Offset(l + 1f, split), Offset(r - 1f, split), .9f)
                drawLine(INK3, Offset(l + w * .14f, t + h * .06f), Offset(l + w * .14f, t + h * .18f), 1.6f, StrokeCap.Round)
                drawLine(INK3, Offset(l + w * .14f, split + h * .05f), Offset(l + w * .14f, split + h * .2f), 1.6f, StrokeCap.Round)
            }
            "dishwasher" -> {
                drawRect(front, Offset(l + g / 2, t + g / 2), Size(w - g, h - g))
                drawRect(onF, Offset(l + g / 2, t + g / 2), Size(w - g, h - g), style = Stroke(.8f))
                drawLine(onF, Offset(l + w * .3f, t + h * .1f), Offset(r - w * .3f, t + h * .1f), 1.4f, StrokeCap.Round)
            }
            else -> drawRect(GREY_LINE, Offset(l + 1f, t + 1f), Size(w - 2f, h - 2f), style = Stroke(1f, pathEffect = dash))
        }
        "filler" -> { drawRect(front, Offset(l, t), Size(w, h)); drawRect(onF, Offset(l, t), Size(w, h), style = Stroke(.8f)) }
        else -> {
            drawRect(carcass, Offset(l, t), Size(w, h))
            val fs = frontSizes(m.fronts, m.w, m.h, ws)
            val n = fs.size
            if (n == 0) {
                // open: the shelves show
                val q = m.inserts.filter { it.kind == "shelf" }.sumOf { it.qty }
                for (i in 1..q) { val y = t + h * i / (q + 1); drawLine(onC, Offset(l + 3f, y), Offset(r - 3f, y), 1f) }
                drawRect(onC, Offset(l, t), Size(w, h), style = Stroke(1f))
            } else if (m.fronts.kind == "door") {
                val fw = (w - g * (n + 1)) / n
                for (i in 0 until n) {
                    val fl = l + g + i * (fw + g)
                    drawRect(front, Offset(fl, t + g), Size(fw, h - 2 * g)); drawRect(onF, Offset(fl, t + g), Size(fw, h - 2 * g), style = Stroke(.8f))
                    if (m.handles) {
                        // the handle on the opening edge: right of a single door, the middle of a pair
                        val hx = if (n == 1 || i == 0) fl + fw - max(2.5f, fw * .1f) else fl + max(2.5f, fw * .1f)
                        val hy = if (m.type == "wall") t + h * .82f else t + h * .14f
                        val len = min(10f, h * .18f)
                        drawLine(onF, Offset(hx, hy - len / 2), Offset(hx, hy + len / 2), 1.4f, StrokeCap.Round)
                    }
                }
            } else {
                // drawers and appliance panels, one above the other
                val fh = (h - g * (n + 1)) / n
                for (i in 0 until n) {
                    val ft = t + g + i * (fh + g)
                    drawRect(front, Offset(l + g, ft), Size(w - 2 * g, fh)); drawRect(onF, Offset(l + g, ft), Size(w - 2 * g, fh), style = Stroke(.8f))
                    if (m.handles && m.fronts.kind == "drawer") {
                        val len = min(14f, w * .3f)
                        drawLine(onF, Offset(l + w / 2 - len / 2, ft + min(5f, fh * .22f)), Offset(l + w / 2 + len / 2, ft + min(5f, fh * .22f)), 1.4f, StrokeCap.Round)
                    }
                }
            }
        }
    }
}

/** What shows the appliance: the tap over a sink, the hob's line, an oven's or a microwave's glass. */
private fun DrawScope.appliance(lay: KLay, m: Module, ws: Workshop) {
    val l = lay.x(m.x); val r = lay.x(m.x + m.w); val cx = (l + r) / 2
    val wt = lay.y(worktopTop(ws))
    when (m.app) {
        "sink" -> {
            val p = Path().apply { moveTo(cx, wt); lineTo(cx, lay.y(worktopTop(ws) + 260)); relativeQuadraticTo(0f, -4f, 4f, -4f); lineTo(cx + 130 * lay.s, lay.y(worktopTop(ws) + 260) - 4f); relativeLineTo(0f, 3f) }
            drawPath(p, INK3, style = Stroke(1.5f, cap = StrokeCap.Round))
        }
        "hob" -> drawLine(GLASS_DARK, Offset(l + (r - l) * .1f, wt - 1.2f), Offset(r - (r - l) * .1f, wt - 1.2f), 2.4f)
        "oven" -> {
            val t = lay.y(m.elev + 1380); val b = lay.y(m.elev + 800)
            drawRoundRect(GLASS_DARK.copy(alpha = .85f), Offset(l + (r - l) * .12f, t), Size((r - l) * .76f, b - t), CornerRadius(2f))
        }
        "micro" -> {
            val t = lay.y(m.elev + m.h); val h = m.h * lay.s
            drawRoundRect(GLASS_DARK.copy(alpha = .85f), Offset(l + (r - l) * .1f, t + h * .18f), Size((r - l) * .62f, h * .64f), CornerRadius(2f))
        }
        "hood" -> {
            val b = lay.y(m.elev)
            drawLine(INK3, Offset(l + (r - l) * .08f, b + 1.5f), Offset(r - (r - l) * .08f, b + 1.5f), 1.6f)
        }
    }
}

/** The units' widths under the floor (and over the upper row), and the run's length. */
private fun DrawScope.dims(lay: KLay, f: Furniture, run: Run, ws: Workshop, tm: TextMeasurer) {
    val st = TextStyle(fontFamily = PlexCond, fontSize = 10.sp, color = INK3)
    fun chain(cuts: List<Int>, y: Float, below: Boolean) {
        if (cuts.size < 2) return
        drawLine(INK3, Offset(lay.x(cuts.first()), y), Offset(lay.x(cuts.last()), y), .8f)
        cuts.forEach { c -> val x = lay.x(c); drawLine(INK3, Offset(x - 2.5f, y + 2.5f), Offset(x + 2.5f, y - 2.5f), 1.1f) }
        for (k in 0 until cuts.size - 1) {
            val a = lay.x(cuts[k]); val b = lay.x(cuts[k + 1]); val t = "${cuts[k + 1] - cuts[k]}"
            val narrow = (b - a) < 6.5f * t.length
            val dy = if (below) (if (narrow && k % 2 == 1) 19f else 9f) else (if (narrow && k % 2 == 1) -19f else -9f)
            text(tm, t, Offset((a + b) / 2f, y + dy), st)
        }
    }
    val low = f.modules.filter { it.wall == run.wall && !isUpper(it) }
    if (low.isNotEmpty()) chain((listOf(run.lowStart) + low.map { it.x + it.w }).distinct().sorted().let { if (run.lowStart > 0) listOf(0) + it else it }, lay.yF + 12f, true)
    val up = f.modules.filter { it.wall == run.wall && isUpper(it) }
    if (up.isNotEmpty()) {
        val y = lay.y(up.maxOf { it.elev + it.h }) - 8f
        chain((listOf(run.upStart) + up.map { it.x + it.w }).distinct().sorted(), y, false)
    }
    // the whole length
    val y = lay.yF + 40f
    drawLine(INK, Offset(lay.x0, y), Offset(lay.x(lay.L), y), 1f)
    listOf(lay.x0, lay.x(lay.L)).forEach { x -> drawLine(INK, Offset(x - 4f, y + 4f), Offset(x + 4f, y - 4f), 1.5f) }
    val t = "${lay.L}"
    val pw = 9f * t.length + 16f
    drawRoundRect(PLAN_W, Offset((lay.x0 + lay.x(lay.L)) / 2 - pw / 2, y - 10f), Size(pw, 20f), CornerRadius(10f))
    drawRoundRect(INK3, Offset((lay.x0 + lay.x(lay.L)) / 2 - pw / 2, y - 10f), Size(pw, 20f), CornerRadius(10f), style = Stroke(1f))
    text(tm, t, Offset((lay.x0 + lay.x(lay.L)) / 2, y), TextStyle(fontFamily = PlexCond, fontSize = 12.sp, color = INK))
}

/** A small picture of the first run (workspace cards). */
@Composable
fun KitchenThumb(p: Project, f: Furniture, modifier: Modifier) {
    val app = LocalApp.current
    val room = roomOf(p, f)
    val runs = kRuns(f, room, app.settings.angleSnap)
    val run = runs.firstOrNull() ?: return
    val ws = app.settings.workshop; val mats = app.settings.mats
    Canvas(modifier) {
        val lay = KLay(runLen(f, run), roomH(room), 200f, false, runExt(f, run))
        val k = min(size.width / lay.vw, size.height / lay.vh)
        withTransform({ translate((size.width - lay.vw * k) / 2f, (size.height - lay.vh * k) / 2f); scale(k, k, pivot = Offset.Zero) }) {
            drawRun(lay, f, run, room, ws, mats, null, emptyMap(), null)
        }
    }
}

/* ---------------- the designer ---------------- */

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
    val ws = app.settings.workshop; val mats = app.settings.mats
    val en = lang == Lang.EN
    val found = checks(f, runs, ws, room?.openings ?: emptyList(), room?.points ?: emptyList())
    val bad = HashMap<String, String>().apply { found.forEach { c -> c.mid?.let { id -> if (c.level == "err" || (c.level == "warn" && this[id] != "err")) this[id] = c.level } } }
    val sel = f.modules.firstOrNull { it.id == kit.sel && it.wall == run?.wall }
    fun go(step: Int) {
        if (runs.size < 2 || run == null) return
        val i = runs.indexOf(run)
        app.setTop(rt.copy(wall = runs[(i + step + runs.size) % runs.size].wall)); kit.sel = null
    }
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(dn(f.name, lang), style = ui(19f, 800, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(tr("kt.sub", "n" to f.modules.size, "v" to runMetres(f, en)), style = ui(12f, 400, G.ink2), maxLines = 1)
                }
                GlassIconButton("undo", tr("common.undo"), { kit.undo(app, p.id, f.id) }, tint = if (kit.canUndo(f.id)) G.ink else G.ink3.copy(alpha = .45f))
                GlassIconButton("redo", "redo", { kit.redo(app, p.id, f.id) }, tint = if (kit.canRedo(f.id)) G.ink else G.ink3.copy(alpha = .45f))
                GlassIconButton("more", "menu", { app.sheet = Sheet.FMenu(p.id, f.id) })
            }
            if (room == null || run == null) {
                Text(tr("kt.roomLost"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.padding(24.dp))
                return@Column
            }
            Row(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 10.dp)) { DimSeg(rt.d3) { app.setTop(rt.copy(d3 = it)) } }
            if (rt.d3) { Furniture3D(p, room); return@Column }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    runs.forEach { r ->
                        val on = r.wall == run.wall
                        Text(runName(f, r), style = ui(14f, 700, if (on) G.solid else G.ink), maxLines = 1,
                            modifier = Modifier.heightIn(min = 40.dp).clip(CircleShape).background(if (on) G.ink else G.idle(.6f)).border(1.dp, if (on) G.ink else G.idleRim, CircleShape)
                                .semantics { selected = on }.clickable(role = Role.Tab) { app.setTop(rt.copy(wall = r.wall)); kit.sel = null }
                                .padding(horizontal = 16.dp, vertical = 10.dp))
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FillPill(tr("kt.low"), fillOf(f, run, false), Modifier.weight(1f))
                    if (run.wall != ISLAND) FillPill(tr("kt.up"), fillOf(f, run, true), Modifier.weight(1f))
                }
                if (f.roomId == null) FreeBanner(p, f)
                if (run.wall != ISLAND && !measured(room, snap, run.wall))
                    Text(tr("kt.noLen", "w" to run.wall), style = ui(13f, 500, G.amberInk, 1.4f),
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp))
                if (run.wall == ISLAND) Text(tr("kt.islandNote"), style = ui(13f, 400, G.ink2, 1.4f))
                Elevation(f, run, room, ws, mats, sel?.id, bad, onPick = { id -> kit.sel = if (kit.sel == id) null else id }, onSwipe = ::go)
                val empty = f.modules.none { it.wall == run.wall }
                if (empty && run.wall != ISLAND) Column(
                    Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(tr("kt.emptyT", "w" to run.wall), style = ui(16f, 800))
                    Text(tr("kt.emptyB"), style = ui(13.5f, 400, G.ink2, 1.45f))
                    GBtn(tr("kt.auto"), {
                        val before = f.modules.size
                        // a new kitchen fills on every wall at once; later only the empty wall shown
                        val n = kit.change(app, p.id, f.id) { x -> autoFill(x, kRuns(x, room, snap).filter { x.modules.isEmpty() || it.wall == run.wall }, ws, room.openings, room.points) }
                        app.say("kt.autoDone", "n" to ((n?.modules?.size ?: before) - before))
                    }, icon = "plus")
                } else Text(tr("kt.hint"), style = ui(12.5f, 400, G.ink2))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("module" to "kt.module", "appl" to "kt.appl", "space" to "kt.space").forEach { (g, k) ->
                        GBtn(tr(k), { app.sheet = Sheet.FLibrary(p.id, f.id, run.wall, g) }, Btn.SECONDARY, icon = if (g == "module") "plus" else null,
                            height = 46.dp, corner = 16.dp, fontSize = 14.5f, modifier = Modifier.weight(1f))
                    }
                }
                if (sel != null) SelCard(p, f, sel, run)
                ChecksCard(f, found) { id -> f.modules.firstOrNull { it.id == id }?.let { m -> if (m.wall != run.wall) app.setTop(rt.copy(wall = m.wall)); kit.sel = m.id } }
                ExtrasCard(p, f)
                CostCard(p, f, ws, mats)
            }
        }
    }
}

/** The kitchen's extras (plan 1b-1): worktop corners and cut-outs, backsplash, plinth, cornice, LED, end panels. */
@Composable
private fun ExtrasCard(p: Project, f: Furniture) {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    val x = f.kx ?: uz.metrx.app.furniture.KExtras()
    fun set(fn: (uz.metrx.app.furniture.KExtras) -> uz.metrx.app.furniture.KExtras) { app.kit.change(app, p.id, f.id) { it.copy(kx = fn(it.kx ?: uz.metrx.app.furniture.KExtras())) } }
    fun m(mm: Int) = "%.1f".format(java.util.Locale.ROOT, mm / 1000.0).replace('.', if (en) '.' else ',')
    val joints = uz.metrx.app.furniture.worktopJoints(f)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("kx.title"), style = ui(16f, 800))
        if (joints > 0) {
            Text(tr("kx.joint", "n" to joints), style = ui(14f, 600))
            Seg(listOf("butt" to tr("kx.butt"), "mitre" to tr("kx.mitre")), x.joint) { k -> set { it.copy(joint = k) } }
        }
        Toggle(tr("kx.cutouts", "n" to f.modules.count { it.app == "sink" || it.app == "hob" }), x.cutouts) { set { it.copy(cutouts = !it.cutouts) } }
        Text(tr("kx.splash"), style = ui(14.5f, 500))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(0, 500, 600, 700).forEach { h -> Chip(if (h == 0) tr("kx.none") else "$h", x.splash == h) { set { it.copy(splash = h) } } }
        }
        Toggle(tr("kx.plinth") + " · " + m(uz.metrx.app.furniture.plinthMm(f)) + " m", x.plinth) { set { it.copy(plinth = !it.plinth) } }
        val wu = uz.metrx.app.furniture.wallUnitsMm(f)
        Toggle(tr("kx.cornice") + " · " + m(wu) + " m", x.cornice) { set { it.copy(cornice = !it.cornice) } }
        Toggle(tr("kx.led") + " · " + m(wu) + " m", x.led) { set { it.copy(led = !it.led) } }
        Stepper(tr("kx.ends"), x.ends, 0, 8) { v -> set { it.copy(ends = v) } }
        Stepper(tr("kx.endsUp"), x.endsUp, 0, 8) { v -> set { it.copy(endsUp = v) } }
        Text(tr("kx.note"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

@Composable
private fun FillPill(label: String, fl: uz.metrx.app.furniture.Fill, modifier: Modifier) {
    val left = fl.left
    val (txt, c) = when {
        left == null -> "${fl.used}" to G.ink2
        left < 0 -> tr("kt.overV", "v" to -left) to G.err
        left == 0 -> tr("kt.full") to (if (Theme.dark) G.green else Color(0xFF15803D))
        else -> tr("kt.freeV", "v" to left) to G.amberInk
    }
    Column(modifier.clip(RoundedCornerShape(16.dp)).background(G.glass(.5f)).border(1.dp, if (left != null && left < 0) G.err.copy(alpha = .6f) else G.rim, RoundedCornerShape(16.dp))
        .padding(horizontal = 12.dp, vertical = 8.dp)) {
        Text(label, style = ui(11.5f, 500, G.ink2), maxLines = 1)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(if (fl.avail != null) "${fl.used} / ${fl.avail}" else "${fl.used}", style = num(15f, 700), maxLines = 1)
            if (fl.avail != null) Text(txt, style = ui(12f, 700, c), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(bottom = 1.dp))
        }
    }
}

@Composable
private fun Elevation(f: Furniture, run: Run, room: Room, ws: Workshop, mats: List<Mat>, sel: String?, bad: Map<String, String>, onPick: (String) -> Unit, onSwipe: (Int) -> Unit) {
    val tm = rememberTextMeasurer()
    val lay = KLay(runLen(f, run), roomH(room), 360f, true, runExt(f, run))
    val mods = f.modules.filter { it.wall == run.wall }
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(G.glass(.55f)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
        Canvas(Modifier.fillMaxWidth().aspectRatio(lay.vw / lay.vh).pointerInput(f, run) {
            awaitEachGesture {
                val down = awaitFirstDown()
                val k = size.width / lay.vw
                val start = down.position
                var swiped = false
                while (true) {
                    val ev = awaitPointerEvent()
                    val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                    if (!ch.pressed) break
                    val d = ch.position - start
                    if (!swiped && abs(d.x) >= 48.dp.toPx() && abs(d.x) >= 1.5f * abs(d.y)) { swiped = true; onSwipe(if (d.x < 0) 1 else -1) }
                }
                if (!swiped) {
                    val px = start.x / k; val py = start.y / k
                    // the upper row first (it is drawn over tall units), then the lower row with its plinth
                    val hit = mods.sortedByDescending { if (isUpper(it)) 1 else 0 }.firstOrNull { m ->
                        px in lay.x(m.x)..lay.x(m.x + m.w) && py in lay.y(m.elev + m.h)..(if (!isUpper(m) && m.elev < 300) lay.yF else lay.y(m.elev))
                    }
                    if (hit != null) onPick(hit.id)
                }
            }
        }) {
            val k = size.width / lay.vw
            withTransform({ scale(k, k, pivot = Offset.Zero) }) { drawRun(lay, f, run, room, ws, mats, sel, bad, tm) }
        }
    }
}

@Composable
private fun SelCard(p: Project, f: Furniture, m: Module, run: Run) {
    val app = LocalApp.current
    val kit = app.kit
    val row = f.modules.filter { it.wall == m.wall && isUpper(it) == isUpper(m) }
    val i = row.indexOfFirst { it.id == m.id }
    fun move(step: Int) {
        val other = row.getOrNull(i + step) ?: return
        kit.change(app, p.id, f.id) { x ->
            val a = x.modules.indexOfFirst { it.id == m.id }; val b = x.modules.indexOfFirst { it.id == other.id }
            x.copy(modules = x.modules.toMutableList().also { l -> val t = l[a]; l[a] = l[b]; l[b] = t })
        }
    }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.7f)).border(2.dp, G.cobalt.copy(alpha = .55f), RoundedCornerShape(22.dp)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f)) {
                Text(modName(m), style = ui(16f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(modSub(m), style = ui(12.5f, 400, G.ink2), maxLines = 2)
            }
            Box(Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button) {
                val name = app.modName(m)
                kit.change(app, p.id, f.id) { x -> x.copy(modules = x.modules.filter { it.id != m.id }) }
                kit.sel = null
                app.say("kt.deleted", "m" to name, action = "common.undo", onAction = { kit.undo(app, p.id, f.id) })
            }, contentAlignment = Alignment.Center) { MIcon("trash", G.err, 20.dp, 2f) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("kt.left"), { move(-1) }, Btn.SECONDARY, icon = "back", enabled = i > 0, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("kt.right"), { move(1) }, Btn.SECONDARY, icon = "chev", enabled = i < row.lastIndex, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("kt.setup"), { app.sheet = Sheet.FModule(p.id, f.id, m.id) }, icon = "sliders", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1.2f))
        }
    }
}

@Composable
internal fun checkText(c: FCheck, f: Furniture): String {
    val m = c.mid?.let { id -> f.modules.firstOrNull { it.id == id } }
    val vars = LinkedHashMap<String, Any?>(c.vars)
    if (m != null) vars["m"] = modName(m)
    if (c.key == "kc.socket") vars["t"] = tr("pt." + c.vars["t"])
    val key = if (c.key == "kc.sinkFar" && ((c.vars["v"] as? Int) ?: 0) < 0) "kc.sinkWall" else c.key
    return tr(key, *vars.toList().toTypedArray())
}

@Composable
internal fun ChecksCard(f: Furniture, found: List<FCheck>, onModule: (String) -> Unit) {
    if (f.modules.isEmpty()) return
    val ok = if (Theme.dark) G.green else Color(0xFF15803D)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("kt.checks"), style = ui(15f, 800))
        val list = found.sortedBy { when (it.level) { "err" -> 0; "warn" -> 1; else -> 2 } }
        if (list.none { it.level != "ok" }) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("check", ok, 18.dp, 2.4f); Text(tr("kt.allOk"), style = ui(13.5f, 500, ok, 1.4f))
        }
        list.forEach { c ->
            val (bg, fg, icon) = when (c.level) {
                "err" -> Triple(G.errWash, G.err, "alert")
                "warn" -> Triple(G.amberWash, G.amberInk, "alert")
                else -> Triple(Color(0x2416A34A), ok, "check")
            }
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(bg).let { if (c.mid != null) it.clickable(role = Role.Button) { onModule(c.mid) } else it }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MIcon(icon, fg, 18.dp, 2f)
                Text(checkText(c, f), style = ui(13.5f, 500, fg, 1.35f), modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
internal fun CostCard(p: Project, f: Furniture, ws: Workshop, mats: List<Mat>) {
    val app = LocalApp.current
    if (f.modules.isEmpty() || !app.settings.advanced) return
    val lang = LocalLang.current
    val hws = app.settings.hws
    val cost = remember(f, ws, mats, hws) { costOf(listOf(f), ws, mats, hws, order = false) }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(tr("kt.cost"), style = ui(14.5f, 700), modifier = Modifier.weight(1f))
            Text(moneyStr(cost.total, p.precision, lang == Lang.EN) + " " + curSuffix(p.currency, lang), style = num(17f, 800))
        }
        Text(tr(if (f.kind == "kitchen") "kt.costNote" else "wd.costNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (cost.missing > 0) Text(tr("kt.noPrice", "n" to cost.missing), style = ui(12.5f, 600, G.amberInk))
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun KitchenSheet(s: Sheet): Boolean = when (s) {
    is Sheet.FMenu -> { FMenuSheet(s); true }
    is Sheet.FRename -> { FRenameSheet(s); true }
    is Sheet.FModule -> { ModuleSheet(s); true }
    is Sheet.FLibrary -> { LibrarySheet(s); true }
    else -> false
}

/** A label under a tile's icon: a one-word name shrinks to stay whole on one line (no "Mehmonxon-a"), longer ones take two. */
@Composable
internal fun TileLabel(s: String, style: androidx.compose.ui.text.TextStyle) =
    androidx.compose.foundation.text.BasicText(s, style = style.copy(textAlign = androidx.compose.ui.text.style.TextAlign.Center), maxLines = if (' ' in s.trim()) 2 else 1,
        autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 8.sp, maxFontSize = style.fontSize, stepSize = .5.sp))

@Composable
internal fun Chip(label: String, on: Boolean, onClick: () -> Unit) {
    Text(label, style = ui(14f, 700, if (on) G.cobalt2 else G.ink), maxLines = 1,
        modifier = Modifier.heightIn(min = 44.dp).clip(CircleShape).background(if (on) G.cobalt.copy(alpha = .1f) else G.idle(.5f))
            .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.idleRim, CircleShape).semantics { selected = on }
            .clickable(role = Role.RadioButton, onClick = onClick).padding(horizontal = 16.dp, vertical = 11.dp))
}

@Composable
private fun FMenuSheet(s: Sheet.FMenu) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    GlassSheet(dn(f.name, lang), { app.sheet = null }) {
        MenuRow("edit", tr("kt.rename"), G.ink) { app.sheet = Sheet.FRename(p.id, f.id) }
        MenuRow("layers", tr("wd.mats"), G.ink) { app.sheet = Sheet.FMats(p.id, f.id) }
        if (f.roomId == null) {
            MenuRow("room", tr("fz.toRoom"), G.ink) { app.sheet = Sheet.FPickRoom(p.id, f.id) }
            MenuRow("ruler", tr("fz.editSizes"), G.ink) { app.sheet = null; app.push(Route.FSteps(p.id, uz.metrx.app.furniture.modelOf(f).id, f.id)) }
        } else MenuRow("room", tr("fz.takeOut"), G.ink) { app.sheet = null; app.takeOut(p.id, f.id) }
        MenuRow("trash", tr("kt.del"), G.err) {
            val i = p.furniture.indexOfFirst { it.id == f.id }
            app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.filter { it.id != f.id }) }
            app.sheet = null; app.dropMissing()
            app.say("kt.deleted", "m" to dn(f.name, lang), action = "common.undo", onAction = {
                app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.toMutableList().also { it.add(i.coerceIn(0, it.size), f) }) }
            })
        }
    }
}

@Composable
internal fun MenuRow(icon: String, label: String, color: Color, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .05f)).pressable(onClick, .98f).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MIcon(icon, color, 20.dp, 2f); Text(label, style = ui(15.5f, 600, color), modifier = Modifier.weight(1f))
    }
}

@Composable
private fun FRenameSheet(s: Sheet.FRename) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    var name by rememberSaveable { mutableStateOf(dn(f.name, lang)) }
    fun save() {
        if (name.isBlank()) return
        app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == f.id) it.copy(name = name.trim()) else it }) }
        app.sheet = null
    }
    GlassSheet(tr("kt.rename"), { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save, enabled = name.isNotBlank()) }) {
        GField(tr("kt.name"), name, { name = it }, tr("kt.kitchen"), imeAction = ImeAction.Done, onIme = ::save)
    }
}

/* ---------------- the library ---------------- */

@Composable
private fun LibrarySheet(s: Sheet.FLibrary) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val room = roomOf(p, f)
    val run = kRuns(f, room, app.settings.angleSnap).firstOrNull { it.wall == s.wall } ?: run { app.sheet = null; return }
    val ws = app.settings.workshop
    val island = run.wall == ISLAND
    var group by rememberSaveable { mutableStateOf("low") }
    val lowLeft = fillOf(f, run, false).left
    val upLeft = fillOf(f, run, true).left
    // a new unit goes after the selected one of its row, else at the row's end
    val after = f.modules.firstOrNull { it.id == app.kit.sel && it.wall == run.wall }
    fun add(kind: String, w: Int? = null) {
        val m = template(kind, ws, run.wall, w)
        val n = app.kit.change(app, p.id, f.id) { x ->
            val i = after?.let { a -> x.modules.indexOfFirst { it.id == a.id } } ?: -1
            if (i >= 0 && isUpper(x.modules[i]) == isUpper(m)) x.copy(modules = x.modules.toMutableList().also { it.add(i + 1, m) }) else x.copy(modules = x.modules + m)
        }
        app.kit.sel = m.id
        app.sheet = null
        n?.modules?.firstOrNull { it.id == m.id }?.let { app.say("kt.added", "m" to app.modName(it)) }
    }
    val title = when (s.group) { "appl" -> "kt.applT"; "space" -> "kt.spaceT"; else -> "kt.libT" }
    GlassSheet(tr(title), { app.sheet = null }) {
        @Composable fun note(upper: Boolean) {
            val left = if (upper) upLeft else lowLeft
            if (after != null && isUpper(after) == upper) Text(tr("kt.afterSel", "m" to modName(after)), style = ui(13f, 600, G.cobalt2, 1.4f))
            if (left != null) Text(if (left > 0) tr("kt.toEnd", "w" to run.wall, "v" to left) else tr("kt.toEndFull", "w" to run.wall),
                style = ui(13f, 500, if (left > 0) G.ink2 else G.amberInk, 1.4f))
        }
        when (s.group) {
            "space" -> {
                val upper = !island
                val free = listOfNotNull(lowLeft, if (upper) upLeft else null).firstOrNull { it > 0 }
                var w by rememberSaveable { mutableStateOf((free ?: 50).coerceIn(10, 600).toString()) }
                val wi = w.toIntOrNull()
                val ok = wi != null && wi in 10..1200
                GField(tr("kt.spW"), w, { w = it.filter(Char::isDigit).take(4) }, "50", number = true, labelRight = "mm", error = tr("km.bad", "a" to 10, "b" to 1200), showError = !ok && w.isNotEmpty())
                if (lowLeft != null) Text(tr("kt.spLeft", "v" to lowLeft) + if (upper && upLeft != null) " · " + tr("kt.up") + ": $upLeft" else "", style = ui(13f, 400, G.ink2))
                LibRow("fillerLow", ws, wi) { if (ok) add("fillerLow", wi) }
                LibRow("spaceLow", ws, wi) { if (ok) add("spaceLow", wi) }
                if (upper) LibRow("fillerUp", ws, wi) { if (ok) add("fillerUp", wi) }
                if (upper) LibRow("spaceUp", ws, wi) { if (ok) add("spaceUp", wi) }
            }
            "appl" -> {
                note(false)
                (listOf("sink", "hob", "dishwasher", "fridge") + LIB_TALL.filter { it != "pantry" } + if (island) emptyList() else listOf("hood", "micro"))
                    .forEach { k -> LibRow(k, ws, null) { add(k) } }
            }
            else -> {
                Seg(listOf("low" to tr("kt.gLow")) + (if (island) emptyList() else listOf("up" to tr("kt.gUp"))) + listOf("tall" to tr("kt.gTall")), group) { group = it }
                note(group == "up")
                val kinds = when (group) { "up" -> LIB_UP.filter { it != "hood" && it != "micro" }; "tall" -> listOf("pantry"); else -> LIB_LOW.filter { it != "sink" && it != "hob" } }
                val widths = if (group == "tall") listOf(400, 450, 600) else listOf(300, 400, 450, 500, 600, 800, 900)
                kinds.forEach { k ->
                    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .05f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            LibGlyph(k, ws)
                            Column(Modifier.weight(1f)) { Text(tr("kn.$k"), style = ui(15f, 700)); Text(tr("kd.$k"), style = ui(12.5f, 400, G.ink2)) }
                        }
                        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            widths.forEach { w ->
                                Text("$w", style = num(14f, 700, G.cobalt2), modifier = Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(12.dp)).background(G.glass(.8f))
                                    .border(1.dp, G.rim, RoundedCornerShape(12.dp)).clickable(role = Role.Button) { add(k, w) }.padding(horizontal = 14.dp, vertical = 10.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LibRow(kind: String, ws: Workshop, w: Int?, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 64.dp).clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .05f)).pressable(onClick, .98f).padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        LibGlyph(kind, ws)
        Column(Modifier.weight(1f)) {
            Text(tr("kn.$kind"), style = ui(15f, 700))
            val m = template(kind, ws, "A", w)
            Text(tr("kd.$kind") + " · ${m.w} × ${m.h}", style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        MIcon("plus", G.cobalt2, 20.dp, 2.4f)
    }
}

/** The unit drawn small, as it looks on the wall. */
@Composable
private fun LibGlyph(kind: String, ws: Workshop) {
    val app = LocalApp.current
    val mats = app.settings.mats
    Canvas(Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(12.dp)).padding(6.dp)) {
        val m = template(kind, ws, "A").copy(x = 0)
        val lift = if (isUpper(m)) m.elev else 0
        val H = max(m.h + m.elev - lift + if (m.app == "sink") 300 else 0, 800)
        val lay = KLay(max(m.w, 600), H, 100f, false)
        val k = min(size.width / lay.vw, size.height / lay.vh)
        val one = m.copy(elev = m.elev - lift, x = (lay.L - m.w) / 2)
        withTransform({ translate((size.width - lay.vw * k) / 2f, (size.height - lay.vh * k) / 2f); scale(k, k, pivot = Offset.Zero) }) {
            val front = hex(mats.firstOrNull { it.id == "ldsp16k" }?.rgb ?: "#CDBFAE")
            drawUnit(lay, one, ws, front, hex("#F5F5F2"), max(.8f, ws.gap10 / 10f * lay.s))
            appliance(lay, one, ws)
        }
    }
}

/* ---------------- a unit's settings ---------------- */

@Composable
private fun ModuleSheet(s: Sheet.FModule) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val m = f.modules.firstOrNull { it.id == s.mid } ?: run { app.sheet = null; return }
    val ws = app.settings.workshop
    val run = kRuns(f, roomOf(p, f), app.settings.angleSnap).firstOrNull { it.wall == m.wall }
    val boxed = m.type == "base" || m.type == "wall" || m.type == "tall"
    // an appliance's panels (a built-in fridge) stay as they are
    val frontsEditable = boxed && m.fronts.kind != "panel"
    var w by rememberSaveable { mutableStateOf(m.w.toString()) }
    var h by rememberSaveable { mutableStateOf(m.h.toString()) }
    var d by rememberSaveable { mutableStateOf(m.d.toString()) }
    var fr by rememberSaveable { mutableStateOf(when { m.fronts.kind == "drawer" -> "d"; m.fronts.kind == "open" -> "o"; m.fronts.kind == "panel" -> "p"; m.fronts.n >= 2 -> "2"; else -> "1" }) }
    var drawers by rememberSaveable { mutableIntStateOf(if (m.fronts.kind == "drawer") m.fronts.n else 3) }
    var shelves by rememberSaveable { mutableIntStateOf(m.inserts.filter { it.kind == "shelf" }.sumOf { it.qty }) }
    var soft by rememberSaveable { mutableStateOf(m.soft) }
    var handles by rememberSaveable { mutableStateOf(m.handles) }
    val wMin = if (m.type == "filler" || m.type == "gap") 10 else 150
    val (hMin, hMax) = when (m.type) { "wall" -> 200 to 1200; "tall" -> 1200 to 2500; "filler" -> 100 to 2500; "gap" -> 300 to 2200; else -> 300 to 900 }
    val wi = w.toIntOrNull()?.takeIf { it in wMin..1200 }
    val hi = h.toIntOrNull()?.takeIf { it in hMin..hMax }
    val di = d.toIntOrNull()?.takeIf { it in 16..800 }
    val fronts = when (fr) { "d" -> Fronts("drawer", drawers); "o" -> Fronts("open", 0); "2" -> Fronts("door", 2); "1" -> Fronts("door", 1); else -> m.fronts }
    val inserts = m.inserts.filter { it.kind != "shelf" } + if (fr != "d" && shelves > 0 && boxed) listOf(Insert("shelf", qty = shelves)) else emptyList()
    val next = m.copy(w = wi ?: m.w, h = hi ?: m.h, d = di ?: m.d, fronts = fronts, inserts = inserts, soft = soft, handles = handles)
    val ok = wi != null && hi != null && di != null
    GlassSheet(modName(m), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("common.delete"), {
                val name = app.modName(m)
                app.kit.change(app, p.id, f.id) { x -> x.copy(modules = x.modules.filter { it.id != m.id }) }
                app.kit.sel = null; app.sheet = null
                app.say("kt.deleted", "m" to name, action = "common.undo", onAction = { app.kit.undo(app, p.id, f.id) })
            }, Btn.DANGER, icon = "trash", height = 48.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), {
                if (!ok) return@GBtn
                app.kit.change(app, p.id, f.id) { x -> x.copy(modules = x.modules.map { if (it.id == m.id) next.copy(x = it.x) else it }) }
                app.sheet = null; app.say("km.saved", "m" to app.modName(next))
            }, enabled = ok, height = 48.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1.4f))
        }
    }) {
        val type = tr(when { m.type == "gap" -> "km.tGap"; m.type == "filler" -> "km.tFiller"; m.type == "tall" -> "km.tTall"; isUpper(m) -> "km.tUp"; else -> "km.tLow" })
        Text(if (m.wall == ISLAND) tr("km.whereI", "t" to type, "x" to m.x) else tr("km.where", "t" to type, "w" to (m.wall ?: ""), "x" to m.x), style = ui(13f, 400, G.ink2))
        // width: the usual sizes, or typed
        val presets = if (m.type == "filler") listOf(20, 30, 50, 80, 100, 150) else listOf(300, 400, 450, 500, 600, 800, 900, 1000)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            presets.forEach { v -> Chip("$v", wi == v) { w = v.toString() } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GField(tr("km.w"), w, { w = it.filter(Char::isDigit).take(4) }, "600", number = true, labelRight = "mm", error = tr("km.bad", "a" to wMin, "b" to 1200), showError = wi == null, modifier = Modifier.weight(1f))
            GField(tr("km.h"), h, { h = it.filter(Char::isDigit).take(4) }, "720", number = true, labelRight = "mm", error = tr("km.bad", "a" to hMin, "b" to hMax), showError = hi == null, modifier = Modifier.weight(1f))
            GField(tr("km.d"), d, { d = it.filter(Char::isDigit).take(3) }, "560", number = true, labelRight = "mm", error = tr("km.bad", "a" to 16, "b" to 800), showError = di == null,
                imeAction = ImeAction.Done, modifier = Modifier.weight(1f))
        }
        if (run != null && wi != null) {
            val fl = fillOf(f, run, isUpper(m))
            val avail = fl.avail
            if (avail != null) {
                val used = fl.used - m.w + wi
                val (t, c) = when {
                    used > avail -> tr("km.fitOver", "w" to run.wall, "v" to used - avail) to G.err
                    used == avail -> tr("km.fitFull", "w" to run.wall, "u" to used, "a" to avail) to (if (Theme.dark) G.green else Color(0xFF15803D))
                    else -> tr("km.fitFree", "w" to run.wall, "v" to avail - used) to G.amberInk
                }
                Text(t, style = ui(13f, 600, c, 1.4f))
            }
        }
        if (frontsEditable) {
            Text(tr("km.fronts"), style = ui(15f, 700))
            Seg(listOf("1" to tr("km.f1"), "2" to tr("km.f2"), "d" to tr("km.fd"), "o" to tr("km.fo")), fr) { fr = it }
            if (fr == "d") Stepper(tr("km.drawers"), drawers, 2, 5) { drawers = it }
            else Stepper(tr("km.shelves"), shelves, 0, 8) { shelves = it }
            if (fr != "o") {
                Toggle(tr("km.handles"), handles) { handles = !handles }
                if (fr != "d") Toggle(tr("km.soft"), soft) { soft = !soft }
            }
        }
        // what the workshop will cut and fit for it
        val parts = partsOf(next, ws)
        Hairline()
        Text(tr("km.parts"), style = ui(15f, 700))
        if (parts.isEmpty()) Text(tr("km.noParts"), style = ui(13f, 400, G.ink2, 1.4f))
        parts.forEach { pt ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(tr(pt.key), style = ui(13.5f, 500), modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("${pt.L} × ${pt.W} × ${pt.qty}", style = num(13.5f, 700))
            }
        }
        val hw = hardwareOf(next, ws)
        if (hw.isNotEmpty()) Text(tr("km.hw", "v" to hw.entries.joinToString(", ") { (k, v) -> app.t("hk.$k") + " × " + uz.metrx.app.furniture.hwAmount(k, v, app.settings.lang == Lang.EN) }),
            style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

@Composable
internal fun Stepper(label: String, v: Int, lo: Int, hi: Int, onValue: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = ui(14.5f, 500), modifier = Modifier.weight(1f))
        StepBtn("−", v > lo) { onValue(v - 1) }
        Text("$v", style = num(17f, 700), modifier = Modifier.width(28.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        StepBtn("+", v < hi) { onValue(v + 1) }
    }
}

@Composable
private fun StepBtn(t: String, on: Boolean, onClick: () -> Unit) {
    Box(Modifier.size(44.dp).clip(CircleShape).background(G.ink.copy(alpha = if (on) .07f else .03f)).clickable(enabled = on, role = Role.Button, onClick = onClick), contentAlignment = Alignment.Center) {
        Text(t, style = ui(20f, 600, if (on) G.ink else G.ink3))
    }
}

@Composable
internal fun Toggle(label: String, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Switch, onClick = onClick), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = ui(14.5f, 500), modifier = Modifier.weight(1f)); GSwitch(on)
    }
}

/* ---------------- in the workspace ---------------- */

/** The workspace's furniture as cards: a small picture of the first wall, the name, units and layout. */
@Composable
fun FurnitureCard(p: Project, f: Furniture, modifier: Modifier) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val shape = RoundedCornerShape(16.dp)
    Box(modifier.height(uz.metrx.app.ui.projects.cardHeight()).glassCard(shape, shadowRadius = 24.dp, shadowY = 10.dp, shadowAlpha = .1f)) {
        val ward = f.kind == "wardrobe"
        Column(Modifier.fillMaxSize().clickable { app.kit.sel = null; app.push(if (ward) Route.Wardrobe(p.id, f.id) else Route.Kitchen(p.id, f.id)) }) {
            Box(Modifier.fillMaxWidth().height(129.dp).background(PLAN_W)) {
                if (ward) WardThumb(p, f, Modifier.fillMaxSize().padding(8.dp)) else KitchenThumb(p, f, Modifier.fillMaxSize().padding(8.dp))
            }
            Column(Modifier.fillMaxWidth().padding(start = 10.dp, end = 42.dp, top = 8.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    MIcon(if (ward) "board" else "kitchen", G.ink3, 15.dp, 2f); Text(if (f.type.isNotEmpty()) tr("ft." + f.type) else tr(if (ward) "kt.wardrobe" else "kt.kitchen"), style = ui(12f, 400, G.ink3), maxLines = 1)
                }
                Text(dn(f.name, lang), style = ui(14.5f, 600, G.ink, 1.25f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                val wm = wardOf(f)
                Text(if (ward && wm != null) tr("wd.card", "w" to wm.w, "h" to uz.metrx.app.furniture.outerH(wm, app.settings.workshop), "n" to wm.sections.size)
                    else tr("kt.card", "n" to f.modules.size, "l" to tr("kt.l" + f.layout)), style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Box(Modifier.align(Alignment.BottomEnd).padding(bottom = 4.dp).size(44.dp).clip(CircleShape).clickable(role = Role.Button) { app.sheet = Sheet.FMenu(p.id, f.id) },
            contentAlignment = Alignment.Center) { MIcon("more", G.ink, 18.dp, 2f) }
    }
}
