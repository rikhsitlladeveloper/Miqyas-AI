package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.width
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
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
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
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
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.FMats
import uz.metrx.app.furniture.Fronts
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Insert
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.PLINTH
import uz.metrx.app.furniture.Section
import uz.metrx.app.furniture.W_GAP_SIDE
import uz.metrx.app.furniture.W_GAP_TOP
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.blockH
import uz.metrx.app.furniture.frontSizes
import uz.metrx.app.furniture.hingesFor
import uz.metrx.app.furniture.nextPos
import uz.metrx.app.furniture.outerH
import uz.metrx.app.furniture.placeOn
import uz.metrx.app.furniture.splitSections
import uz.metrx.app.furniture.spreadShelves
import uz.metrx.app.furniture.wardBase
import uz.metrx.app.furniture.wardInnerH
import uz.metrx.app.furniture.wardrobeChecks
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.AMBER
import uz.metrx.app.ui.editor.COB
import uz.metrx.app.ui.editor.GREY_LINE
import uz.metrx.app.ui.editor.INK
import uz.metrx.app.ui.editor.INK3
import uz.metrx.app.ui.editor.RED
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.editor.roomGrid
import uz.metrx.app.ui.editor.text
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.PlexCond
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.ui.zIndex
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.ui.semantics.contentDescription
import kotlin.math.roundToInt
import androidx.compose.runtime.remember
import kotlin.math.max
import kotlin.math.min

/*
 * Furniture makers, Stage 1a part 5 (furniture plan section 8; design canvas screen 11): the wardrobe designer in five
 * steps (place, sizes, doors, inside, material) over its front drawing. Hinged doors or open; sliding doors are 1b.
 * The rules are in furniture/Wardrobe.kt.
 */

internal fun wardOf(f: Furniture): Module? = f.modules.firstOrNull { it.type == "wardrobe" }

/** The box the designer works on: the one picked (a stenka's piece, a corner wardrobe's arm), else the first. */
internal fun App.curWard(f: Furniture): Module? = f.modules.firstOrNull { it.id == kit.sel && it.type == "wardrobe" } ?: wardOf(f)

/** Changes the wardrobe (the picked box of a piece of several) of furniture [fid] (on the designer's undo list). */
private fun App.ward(pid: String, fid: String, fn: (Module) -> Module) =
    kit.change(this, pid, fid) { x ->
        val cur = curWard(x) ?: return@change x
        val room = if (x.roomId == null) null else store.get(pid)?.let { roomOf(it, x) }
        val many = uz.metrx.app.furniture.boxes(x).size > 1
        val y = x.copy(modules = x.modules.map { if (it.id == cur.id) fn(it).let { m ->
            // the side panels follow where it stands: an end in the room has one, a sliding wardrobe uses the wall it meets
            // without a room there are no walls to meet: its side panels stay as they are (a free-standing kupe keeps both)
            if (many || room == null) m else uz.metrx.app.furniture.withSides(m, wallLen(room, settings.angleSnap, m.wall ?: ""), x.pose != null)
        } else it })
        // the other boxes make room: a stenka's pieces side by side, a corner's arms, a box on another
        uz.metrx.app.furniture.packPiece(y, room?.let { r -> wallLen(r, settings.angleSnap, x.walls.firstOrNull() ?: "") }, cur.id, settings.workshop)
    }

internal fun App.changeSec(pid: String, fid: String, i: Int, fn: (Section) -> Section) =
    // new doors: the doors chosen without a handle before are other doors now (Handles.kt)
    ward(pid, fid) { m -> m.copy(sections = m.sections.mapIndexed { k, s -> if (k == i) uz.metrx.app.furniture.frontsChanged(s, fn(s)) else s }) }

/** A new insert of [kind] in section [i], where it fits best. */
private fun App.addInsert(pid: String, fid: String, m: Module, i: Int, kind: String) {
    val t = settings.workshop.t
    val s = m.sections.getOrNull(i) ?: return
    val x = Insert(kind, pos = nextPos(kind, s, wardInnerH(m, t), t), h = blockH(Insert(kind)))
    changeSec(pid, fid, i) { it.copy(inserts = (it.inserts + x).sortedBy { y -> y.pos }) }
    say("kt.added", "m" to t("wi.$kind"))
}

private fun wardRoomH(room: Room?): Int? = room?.dim("H")?.let { it.v ?: it.pending?.mm }

/** The wall's length, the room's height and what is wrong. */
private class WardCtx(p: Project, f: Furniture, m: Module, ws: Workshop, snap: Boolean) {
    val room = roomOf(p, f)
    val wallL = room?.let { wallLen(it, snap, m.wall ?: "") }
    val roomH = wardRoomH(room)
    val found = wardrobeChecks(m, wallL, roomH, ws, room?.openings ?: emptyList(), room?.points ?: emptyList()).let { c ->
        // a piece of several boxes (a stenka) is checked as a whole too: its run along the wall, not only the box picked
        val w0 = f.walls.firstOrNull()
        val runL = if (room != null && w0 != null && f.type !in uz.metrx.app.furniture.CORNER_TYPES && uz.metrx.app.furniture.boxes(f).size > 1) wallLen(room, snap, w0) else null
        val over = runL?.let { uz.metrx.app.furniture.runStart(f) + uz.metrx.app.furniture.runLen(f) - it } ?: 0
        if (over > 0 && c.none { it.key == "wc.wide" }) c + uz.metrx.app.furniture.FCheck("err", "wc.wide", mapOf("v" to over), m.id) else c
    }
    /** Section number (from 1) → its worst finding. */
    val bad: Map<Int, String> = HashMap<Int, String>().apply {
        found.forEach { c -> (c.vars["s"] as? Int)?.let { n -> if (c.level == "err" || this[n] == null) this[n] = c.level } }
    }
}

/* ---------------- the drawing ---------------- */

/**
 * The wardrobe's front, its left edge at [ox] mm (0: drawn on its wall): the carcass, plinth or legs, sections,
 * inserts (unless the doors are shown), doors, problem outlines and the selected section. [edge]: the piece opens by its
 * edge (Handles.kt opensByEdge), so a front without a handle shows no push mark.
 */
internal fun DrawScope.drawWard(lay: KLay, m: Module, ox: Int, ws: Workshop, carcass: Color, front: Color, sel: Int, doors: Boolean,
                               bad: Map<Int, String>, tm: TextMeasurer?, edge: Boolean = false) {
    val t = ws.t
    val z0 = uz.metrx.app.furniture.legsOf(m, ws) + m.elev
    val base = wardBase(m)
    fun X(mm: Int) = lay.x(mm - ox)
    val l = X(m.x); val r = X(m.x + m.w); val top = lay.y(z0 + m.h); val bot = lay.y(z0)
    val onC = lineOn(carcass); val onF = lineOn(front)
    val dash = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))
    drawRect(carcass, Offset(l, top), Size(r - l, bot - top))
    if (!m.legs) drawRect(GREY_LINE.copy(alpha = .4f), Offset(l, lay.y(z0 + base)), Size(r - l, base * lay.s))
    else {
        var acc = m.x
        (listOf(m.x) + m.sections.map { s -> acc += s.w; acc }).forEach { x -> drawRect(GREY_LINE, Offset(X(x) - 1.5f, bot), Size(3f, lay.yF - bot)) }
    }
    val bottomY = lay.y(z0 + base + t)
    // a desk's knee space has no bottom: the floor shows through
    run { var a = m.x; m.sections.forEach { s -> if (!s.knee) drawLine(onC, Offset(X(a), bottomY), Offset(X(a + s.w), bottomY), 1f)
        else drawRect(uz.metrx.app.ui.editor.PLAN_W, Offset(X(a) + 1f, lay.y(z0 + m.h - t)), Size(s.w * lay.s - 2f, lay.yF - lay.y(z0 + m.h - t))); a += s.w } }
    drawLine(onC, Offset(l, lay.y(z0 + m.h - t)), Offset(r, lay.y(z0 + m.h - t)), 1f)
    var acc = m.x
    m.sections.forEachIndexed { i, s ->
        val sl = X(acc); val sr = X(acc + s.w)
        if (i > 0) drawLine(onC, Offset(sl, lay.y(z0 + base)), Offset(sl, top), 1.4f)
        val il = sl + 2f; val ir = sr - 2f
        val open = s.fronts.kind == "open"
        val slide = m.slide != null
        if (!doors || (open && !slide)) s.inserts.forEach { x ->
            val y0 = z0 + base + t + x.pos
            val h = blockH(x)
            when (x.kind) {
                "shelf" -> drawRect(onC, Offset(il, lay.y(y0 + t)), Size(ir - il, max(1.4f, t * lay.s)))
                "glass" -> drawRect(GLASS_C, Offset(il, lay.y(y0 + 6)), Size(ir - il, max(1.4f, 6 * lay.s)))
                "rail" -> drawLine(GREY_LINE, Offset(il + 3f, lay.y(y0)), Offset(ir - 3f, lay.y(y0)), 2.4f, StrokeCap.Round)
                "lift" -> {
                    drawRect(GREY_LINE, Offset(il + 3f, lay.y(y0 + h)), Size(ir - il - 6f, h * lay.s), style = Stroke(1f, pathEffect = dash))
                    drawLine(GREY_LINE, Offset(il + 5f, lay.y(y0 + 40)), Offset(ir - 5f, lay.y(y0 + 40)), 2.4f, StrokeCap.Round)
                }
                else -> {
                    val bt = lay.y(y0 + h); val bh = max(2f, h * lay.s - 1f)
                    drawRoundRect(if (x.kind == "drawer") front else GAP_FILL, Offset(il + 1.5f, bt), Size(ir - il - 3f, bh), CornerRadius(1.5f))
                    drawRoundRect(onC, Offset(il + 1.5f, bt), Size(ir - il - 3f, bh), CornerRadius(1.5f), style = Stroke(.9f))
                    when (x.kind) {
                        // a drawer (an open section's, or behind the doors) without a handle: the push mark where it would be
                        "drawer" -> { val c = (il + ir) / 2; val hy = bt + min(4f, bh / 3)
                            if (uz.metrx.app.furniture.drawerHandle(m, x)) drawLine(onF, Offset(c - 6f, hy), Offset(c + 6f, hy), 1.4f, StrokeCap.Round)
                            else if (!edge) pushMark(Offset(c, hy + 1f), onF, min(2.6f, bh / 3)) }
                        "trouser" -> for (k in 1..4) { val xx = il + (ir - il) * k / 5; drawLine(INK3, Offset(xx, bt + 2f), Offset(xx, bt + bh - 2f), .8f) }
                        "shoe" -> drawLine(INK3, Offset(il + 4f, bt + bh - 2f), Offset(ir - 4f, bt + 2f), .9f)
                    }
                }
            }
        }
        if (doors && !open && !slide) {
            val n = frontSizes(s.fronts, uz.metrx.app.furniture.frontW(s), m.h - base, ws).size
            if (n > 0) {
                val g = max(.8f, ws.gap10 / 10f * lay.s)
                val ft = top + g; val fb = lay.y(z0 + base) - g
                // a corner unit's blind part has no door (the other arm closes it)
                val fw = (sr - sl - s.blind * lay.s - g * (n + 1)) / n
                val fill = when (s.face) { "mirror" -> MIRROR_C; "glass" -> GLASS_C.copy(alpha = .45f); else -> front }
                for (j in 0 until n) {
                    val fx = sl + g + j * (fw + g)
                    drawRect(fill, Offset(fx, ft), Size(fw, fb - ft)); drawRect(onF, Offset(fx, ft), Size(fw, fb - ft), style = Stroke(.8f))
                    if (s.face == "glass") drawRect(PROFILE_C, Offset(fx, ft), Size(fw, fb - ft), style = Stroke(max(1.2f, 20 * lay.s)))
                    val hx = if (n == 2) (if (j == 0) fx + fw - 3f else fx + 3f) else (if (!uz.metrx.app.furniture.hingeRight(m, i)) fx + fw - 3f else fx + 3f)
                    // about 1 m up, but on the door of a low or hung cabinet
                    val hy = lay.y((z0 + 1000).coerceAtMost(z0 + m.h - 90).coerceAtLeast(z0 + base + 90))
                    if (uz.metrx.app.furniture.doorHandle(m, i, j)) drawLine(onF, Offset(hx, hy - 9f), Offset(hx, hy + 9f), 1.6f, StrokeCap.Round)
                    // no handle (a glass door never has one): the push latch's mark, a little in from the edge; none on a piece opened by its edge
                    else if (!edge) pushMark(Offset(if (hx > fx + fw / 2) hx - 2f else hx + 2f, hy), if (s.face == "glass") INK else onF, 2.8f)
                }
            }
        }
        // the selected section's heights, on its left
        if (i == sel && !doors && tm != null) {
            var last = Float.MAX_VALUE
            s.inserts.sortedBy { it.pos }.forEach { x ->
                val y = lay.y(z0 + base + t + x.pos)
                if (last - y >= 11f) {
                    val st = TextStyle(fontFamily = PlexCond, fontSize = 8.5.sp, color = COB)
                    val w = 6f * "${x.pos}".length + 6f
                    drawRoundRect(uz.metrx.app.ui.editor.PLAN_W.copy(alpha = .9f), Offset(sr - 3f - w, y - 6f), Size(w, 12f), CornerRadius(4f))
                    text(tm, "${x.pos}", Offset(sr - 3f - w / 2, y), st)
                    last = y
                }
            }
        }
        when (bad[i + 1]) {
            "err" -> drawRect(RED, Offset(sl + 2f, top + 2f), Size(sr - sl - 4f, bot - top - 4f), style = Stroke(1.6f, pathEffect = dash))
            "warn" -> drawRect(AMBER, Offset(sl + 2f, top + 2f), Size(sr - sl - 4f, bot - top - 4f), style = Stroke(1.4f, pathEffect = dash))
        }
        if (i == sel) drawRect(COB, Offset(sl + 1.5f, top + 1.5f), Size(sr - sl - 3f, bot - top - 3f), style = Stroke(2.6f))
        acc += s.w
    }
    if (doors) m.slide?.let { sl -> drawSlide(lay, m, sl, ox, z0 + base + t, front, ws) }
    // the ends: a side panel, or dashed where it meets a wall (built in)
    drawLine(INK, Offset(l, top), Offset(r, top), 1.4f)
    drawLine(INK, Offset(l, top), Offset(l, bot), if (m.sideL) 1.8f else 1f, pathEffect = if (m.sideL) null else dash)
    drawLine(INK, Offset(r, top), Offset(r, bot), if (m.sideR) 1.8f else 1f, pathEffect = if (m.sideR) null else dash)
}

/** Where a front without a handle is pushed open (a push latch): a small ring with a dot, in the drawings and the PDF. */
internal fun DrawScope.pushMark(c: Offset, color: Color, r: Float = 2.8f) {
    drawCircle(color, r, c, style = Stroke(.9f))
    drawCircle(color, r * .32f, c)
}

/** Mirror and lacobel glass in drawings (the 3D uses the same colours). */
internal val MIRROR_C = Color(0xFFC9D3DD)
internal val GLASS_C = Color(0xFF8FA9C4)
private val PROFILE_C = Color(0xFF9AA3AE)

/** Sliding doors over the front: the back track's doors first, the front track's over them, each in its profile frame. */
private fun DrawScope.drawSlide(lay: KLay, m: Module, sl: uz.metrx.app.furniture.Slide, ox: Int, y0: Int, front: Color, ws: Workshop) {
    val n = sl.n.coerceIn(2, 4)
    val (dw, dh) = uz.metrx.app.furniture.slideDoor(m, ws.t)
    val step = dw - uz.metrx.app.furniture.SLIDE_OV
    val ax = m.x + (if (m.sideL) ws.t else 0)
    val y = y0 + uz.metrx.app.furniture.SLIDE_CLEAR / 2
    val fw = max(1.2f, uz.metrx.app.furniture.SLIDE_FRAME_W * lay.s)
    (0 until n).sortedBy { it % 2 }.forEach { j ->
        val l = lay.x(ax + j * step - ox); val w = dw * lay.s
        val t = lay.y(y + dh); val h = dh * lay.s
        val fill = when (sl.panel(j)) { "mirror" -> MIRROR_C; "glass" -> GLASS_C; else -> front }
        drawRect(PROFILE_C, Offset(l, t), Size(w, h))
        drawRect(fill, Offset(l + fw, t + fw * 1.6f), Size(w - 2 * fw, h - 3.2f * fw))
        if (sl.panel(j) == "mirror") for (k in 0..1) {
            val sx = l + w * (.25f + .3f * k)
            drawLine(Color.White.copy(alpha = .7f), Offset(sx, t + h * .2f), Offset(sx + w * .18f, t + h * .05f), 1.2f)
        }
        drawRect(INK, Offset(l, t), Size(w, h), style = Stroke(.9f))
    }
}

/** Widths under the floor and the height at the left; [cuts] in mm from the drawing's start. */
internal fun DrawScope.wardDims(lay: KLay, cuts: List<Int>, total: Int, h: Int, hx: Int, tm: TextMeasurer) {
    val st = TextStyle(fontFamily = PlexCond, fontSize = 10.sp, color = INK3)
    val y = lay.yF + 12f
    drawLine(INK3, Offset(lay.x(cuts.first()), y), Offset(lay.x(cuts.last()), y), .8f)
    cuts.forEach { c -> val x = lay.x(c); drawLine(INK3, Offset(x - 2.5f, y + 2.5f), Offset(x + 2.5f, y - 2.5f), 1.1f) }
    for (k in 0 until cuts.size - 1) {
        val a = lay.x(cuts[k]); val b = lay.x(cuts[k + 1]); val t = "${cuts[k + 1] - cuts[k]}"
        if (cuts[k + 1] - cuts[k] <= 0) continue
        val narrow = (b - a) < 6.5f * t.length
        text(tm, t, Offset((a + b) / 2f, y + if (narrow && k % 2 == 1) 19f else 9f), st)
    }
    val ly = lay.yF + 40f
    val a = lay.x(cuts.first()); val b = lay.x(cuts.last())
    drawLine(INK, Offset(a, ly), Offset(b, ly), 1f)
    listOf(a, b).forEach { x -> drawLine(INK, Offset(x - 4f, ly + 4f), Offset(x + 4f, ly - 4f), 1.5f) }
    val pw = 9f * "$total".length + 16f
    drawRoundRect(uz.metrx.app.ui.editor.PLAN_W, Offset((a + b) / 2 - pw / 2, ly - 10f), Size(pw, 20f), CornerRadius(10f))
    drawRoundRect(INK3, Offset((a + b) / 2 - pw / 2, ly - 10f), Size(pw, 20f), CornerRadius(10f), style = Stroke(1f))
    text(tm, "$total", Offset((a + b) / 2, ly), TextStyle(fontFamily = PlexCond, fontSize = 12.sp, color = INK))
    // the height
    val x = lay.x(hx) - 9f
    drawLine(INK3, Offset(x, lay.y(h)), Offset(x, lay.yF), .8f)
    listOf(lay.y(h), lay.yF).forEach { yy -> drawLine(INK3, Offset(x - 2.5f, yy + 2.5f), Offset(x + 2.5f, yy - 2.5f), 1.1f) }
    rotate(-90f, Offset(x - 7f, (lay.y(h) + lay.yF) / 2)) { text(tm, "$h", Offset(x - 7f, (lay.y(h) + lay.yF) / 2), st) }
}

@Composable
private fun WardDrawing(m: Module, f: Furniture, cx: WardCtx, ws: Workshop, mats: List<Mat>, step: Int, sel: Int, onSec: (Int) -> Unit,
                        onFront: ((uz.metrx.app.furniture.HFront) -> Unit)? = null) {
    val tm = rememberTextMeasurer()
    val onWall = step == 1
    val doors = step == 1 || step == 3 || step == 5
    val ox = if (onWall) 0 else m.x
    val L = if (onWall) max(cx.wallL ?: (m.x + m.w + W_GAP_SIDE), m.x + m.w) else m.w
    val H = if (onWall) max(cx.roomH ?: 2700, uz.metrx.app.furniture.topOf(m, ws)) else outerH(m, ws)
    val lay = KLay(L, H, 360f, true)
    val front = hex(mats.firstOrNull { it.id == f.mats.front }?.rgb ?: "#CDBFAE")
    val carcass = hex(mats.firstOrNull { it.id == f.mats.carcass }?.rgb ?: "#F5F5F2")
    val edge = uz.metrx.app.furniture.opensByEdge(f)
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(G.glass(.55f)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
        Canvas(Modifier.fillMaxWidth().aspectRatio(lay.vw / lay.vh).pointerInput(m, step) {
            detectTapGestures { pos ->
                val k = size.width / lay.vw
                val mm = ((pos.x / k - lay.x0) / lay.s).toInt() + ox
                var acc = m.x
                m.sections.forEachIndexed { i, s -> if (mm >= acc && mm < acc + s.w) onSec(i); acc += s.w }
            }
        }) {
            val k = size.width / lay.vw
            withTransform({ scale(k, k, pivot = Offset.Zero) }) {
                if (onWall) drawWallFace(lay, cx.room, m.wall ?: "")
                drawLine(INK, Offset(lay.x0 - 10f, lay.yF), Offset(lay.x(L) + 10f, lay.yF), 2f)
                // on its wall the piece's other boxes stand beside it; alone, a hung box is drawn from its own bottom
                if (onWall) f.modules.filter { it.type == "wardrobe" && it.id != m.id && it.wall == m.wall }.forEach { o -> drawWard(lay, o, ox, ws, carcass, front, -1, true, emptyMap(), null, edge) }
                drawWard(lay, if (onWall) m else m.copy(elev = 0), ox, ws, carcass, front, if ((step == 3 && m.slide == null) || step == 4) sel else -1, doors, cx.bad, tm, edge)
                if (onWall) cx.room?.points?.filter { it.wall == m.wall }?.forEach { p -> drawSitePoint(p, Offset(lay.x(p.off), lay.y(p.h)), lay.s, 6f) }
                if (onWall) wardDims(lay, listOf(0, m.x, m.x + m.w, L).distinct().sorted(), L, outerH(m, ws), m.x, tm)
                else {
                    var acc = 0
                    wardDims(lay, listOf(0) + m.sections.map { s -> acc += s.w; acc }, m.w, outerH(m, ws), 0, tm)
                }
            }
        }
        // the doors step: each door and open drawer is tapped to give it a handle or take it away (the ones behind the doors: InnerDrawers)
        if (onFront != null && !onWall && m.slide == null) m.copy(elev = 0).let { b -> FrontTargets(lay, ox, b, wardFrontBoxes(b, ws), onFront, edge) }
    }
}

/** A small picture for the workspace card. */
@Composable
fun WardThumb(p: Project, f: Furniture, modifier: Modifier) {
    val app = LocalApp.current
    if (uz.metrx.app.furniture.isItemPiece(f) || uz.metrx.app.furniture.boxes(f).size > 1) { PieceThumb(f, modifier); return }
    val m = wardOf(f) ?: return
    val ws = app.settings.workshop; val mats = app.settings.mats
    val front = hex(mats.firstOrNull { it.id == f.mats.front }?.rgb ?: "#CDBFAE")
    val carcass = hex(mats.firstOrNull { it.id == f.mats.carcass }?.rgb ?: "#F5F5F2")
    Canvas(modifier) {
        val lay = KLay(m.w, outerH(m, ws), 200f, false)
        val k = min(size.width / lay.vw, size.height / lay.vh)
        withTransform({ translate((size.width - lay.vw * k) / 2f, (size.height - lay.vh * k) / 2f); scale(k, k, pivot = Offset.Zero) }) {
            drawLine(INK, Offset(lay.x0 - 6f, lay.yF), Offset(lay.x(m.w) + 6f, lay.yF), 2f)
            drawWard(lay, m, m.x, ws, carcass, front, -1, true, emptyMap(), null, uz.metrx.app.furniture.opensByEdge(f))
        }
    }
}

/* ---------------- the designer ---------------- */

@Composable
fun WardrobeScreen(rt: Route.Wardrobe) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val kit = app.kit
    @Suppress("UNUSED_VARIABLE") val tick = kit.tick
    val p = app.store.get(rt.pid) ?: return
    val f = p.furniture.firstOrNull { it.id == rt.fid } ?: return
    // a bed, a table, a bar counter or a mirror panel has its own short designer
    if (uz.metrx.app.furniture.isItemPiece(f) && rt.mod == null) { ItemScreen(rt, p, f); return }
    val m = rt.mod?.let { id -> f.modules.firstOrNull { it.id == id && it.type == "wardrobe" } } ?: app.curWard(f) ?: return
    val ws = app.settings.workshop; val mats = app.settings.mats
    val cx = WardCtx(p, f, m, ws, app.settings.angleSnap)
    val sel = rt.sec.coerceIn(0, max(0, m.sections.lastIndex))
    fun pickSec(i: Int) = app.setTop(rt.copy(sec = i))
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(dn(f.name, lang), style = ui(19f, 800, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(tr("wd.sub", "w" to m.w, "h" to outerH(m, ws), "d" to m.d, "n" to m.sections.size), style = ui(12f, 400, G.ink2), maxLines = 1)
                }
                GlassIconButton("undo", tr("common.undo"), { kit.undo(app, p.id, f.id) }, tint = if (kit.canUndo(f.id)) G.ink else G.ink3.copy(alpha = .45f))
                GlassIconButton("redo", tr("common.redo"), { kit.redo(app, p.id, f.id) }, tint = if (kit.canRedo(f.id)) G.ink else G.ink3.copy(alpha = .45f))
                GlassIconButton("more", tr("common.menu"), { app.sheet = Sheet.FMenu(p.id, f.id) })
            }
            val room = cx.room
            if (room == null) {
                Text(tr("kt.roomLost"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.padding(24.dp))
                return@Column
            }
            Row(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 10.dp)) { DimSeg(rt.d3) { app.setTop(rt.copy(d3 = it)) } }
            if (rt.d3) { Furniture3D(p, room); return@Column }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Steps(rt.step) { app.setTop(rt.copy(step = it)) }
                if (f.modules.count { it.type == "wardrobe" } > 1 || f.type == "stenka") BoxPicker(p, f, m) { app.setTop(rt.copy(sec = 0)) }
                WardDrawing(m, f, cx, ws, mats, rt.step, sel, ::pickSec, if (rt.step != 3) null else { fr ->
                    if (fr.sec >= 0 && fr.sec != sel) pickSec(fr.sec)
                    app.ward(p.id, f.id) { uz.metrx.app.furniture.toggleHandle(it, fr.key) }
                })
                Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    when (rt.step) {
                        1 -> PlaceStep(p, f, m, cx, ws)
                        2 -> SizeStep(p, f, m, ws)
                        3 -> DoorStep(p, f, m, sel, ws, ::pickSec)
                        4 -> InsideStep(p, f, m, sel, ws, ::pickSec)
                        else -> MatStep(p, f, mats)
                    }
                }
                // with the Check list's drawer rule (its sheet and shelf rules are the designer's own)
                ChecksCard(f, cx.found + remember(f, ws, mats) { uz.metrx.app.furniture.boardIssues(f, ws, mats).filter { it.key == "bz.ck.drawer" }
                    .map { uz.metrx.app.furniture.FCheck(it.level, it.key, it.vars, it.mid) } }) { }
                CostCard(p, f, ws, mats)
            }
            LivePrice(p, f)
        }
    }
}

/**
 * The boxes of a piece of several (a stenka's pieces, a corner wardrobe's arms, a vitrina's halves): which one the
 * steps below change. A stenka's pieces can be added, moved along and taken away.
 */
@Composable
private fun BoxPicker(p: Project, f: Furniture, cur: Module, onPick: () -> Unit) {
    val app = LocalApp.current
    val ws = app.settings.workshop
    val ms = f.modules.filter { it.type == "wardrobe" }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(18.dp), fill = G.glass(.6f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("pc.title"), style = ui(14.5f, 800))
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ms.forEachIndexed { i, b -> Chip("${i + 1} · " + tr(uz.metrx.app.furniture.boxRole(f, b)) + " ${b.w}", b.id == cur.id) { app.kit.sel = b.id; app.kit.tick++; onPick() } }
        }
        if (f.type == "stenka") {
            fun edit(fn: (List<Module>) -> List<Module>) = app.kit.change(app, p.id, f.id) { x ->
                val room = if (x.roomId == null) null else roomOf(p, x)
                uz.metrx.app.furniture.packPiece(x.copy(modules = fn(x.modules)), room?.let { r -> wallLen(r, app.settings.angleSnap, x.walls.firstOrNull() ?: "") }, ws = ws)
            }
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                uz.metrx.app.furniture.STENKA_PARTS.forEach { k ->
                    Chip("+ " + tr("pc.add.$k"), false) {
                        val nb = uz.metrx.app.furniture.stenkaPart(f, k, ws)
                        // a shelf hangs over a low piece, so it goes in next to one (never over a tall cabinet)
                        edit { l -> val i = l.indexOfFirst { it.id == cur.id }
                            val at = if (k == "shelf") uz.metrx.app.furniture.stenkaShelfAt(l, i) else if (i < 0) l.size else i + 1
                            l.toMutableList().apply { add(at.coerceIn(0, size), nb) } }
                        app.kit.sel = nb.id; app.say("kt.added", "m" to app.t("pc.add.$k"))
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                // along the wall: before or after the next piece in the list
                listOf(-1 to "pc.left", 1 to "pc.right").forEach { (dlt, k) ->
                    GBtn(tr(k), { edit { l -> val i = l.indexOfFirst { it.id == cur.id }; val j = i + dlt
                        if (i < 0 || j !in l.indices) l else l.toMutableList().apply { add(j, removeAt(i)) } } },
                        Btn.SECONDARY, icon = if (dlt < 0) "undo" else "redo", height = 42.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
                }
                // the last floor piece stays: the shelves hang over it
                val canDrop = uz.metrx.app.furniture.canDropBox(f, cur)
                GBtn(tr("common.delete"), {
                    if (!canDrop) return@GBtn
                    edit { l -> l.filter { it.id != cur.id } }
                    app.kit.sel = null
                    app.say("kt.deleted", "m" to app.t(uz.metrx.app.furniture.boxRole(f, cur)), action = "common.undo", onAction = { app.kit.undo(app, p.id, f.id) })
                }, Btn.DANGER, icon = "trash", enabled = canDrop, height = 42.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun Steps(cur: Int, onPick: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .06f)).padding(4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        (1..5).forEach { i ->
            val on = i == cur
            Column(Modifier.weight(1f).heightIn(min = 48.dp).clip(RoundedCornerShape(12.dp)).background(if (on) G.glass(.95f) else Color.Transparent)
                .semantics { selected = on }.clickable(role = Role.Tab) { onPick(i) }.padding(vertical = 4.dp, horizontal = 2.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Text("$i", style = ui(12.5f, 800, if (on) G.ink else G.ink2))
                Text(tr("wd.s$i"), style = ui(10.5f, 700, if (on) G.ink else G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** A value row for the other furniture screens (the item designer). */
@Composable
internal fun FValRow(label: String, value: String, onClick: () -> Unit) = ValRow(label, value, onClick)

@Composable
private fun ValRow(label: String, value: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(14.dp))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = ui(14.5f, 500), modifier = Modifier.weight(1f))
        Text(value, style = num(15f, 700)); Spacer(Modifier.size(6.dp)); MIcon("chev", G.ink3, 16.dp, 2f)
    }
}

@Composable
private fun SecChips(m: Module, sel: Int, onPick: (Int) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        m.sections.forEachIndexed { i, s -> Chip("${i + 1} · ${s.w}", i == sel) { onPick(i) } }
    }
}

@Composable
private fun PlaceStep(p: Project, f: Furniture, m: Module, cx: WardCtx, ws: Workshop) {
    val app = LocalApp.current
    val snap = app.settings.angleSnap
    if (f.roomId == null) { FreeBanner(p, f); return }
    val room = cx.room ?: return
    if (uz.metrx.app.furniture.boxes(f).size > 1) {
        Text(tr("pc.placeNote"), style = ui(13f, 400, G.ink2, 1.4f))
        GBtn(tr("fz.move"), { app.push(Route.FPlace(p.id, f.id, room.id)) }, Btn.SECONDARY, icon = "room", height = 44.dp, corner = 14.dp, fontSize = 14f)
        return
    }
    // to another wall: its width kept where it fits, at the wall's longest stretch clear of doors and windows
    fun moveTo(wall: String, len: Int?) {
        val L = len ?: return
        val (sx, sw, _) = placeOn(L, wall, room.openings, m.h)
        val w = min(m.w, L - 2 * W_GAP_SIDE)
        val x = if (sw >= w) sx else W_GAP_SIDE
        app.ward(p.id, f.id) { mm -> mm.copy(wall = wall, x = x, w = w, sections = if (w != mm.w) splitSections(w, mm.sections.map { it.copy(lock = false) }) else mm.sections) }
        app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == f.id) it.copy(walls = listOf(wall), pose = null) else it }) }
    }
    Text(tr("wd.place", "w" to (m.wall ?: "")), style = ui(15.5f, 800))
    // the row opens scrolled to the wardrobe's wall, so wall C or D is not hidden past the edge
    val wallsSc = rememberScrollState()
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var shown by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(false) }
    Row(Modifier.horizontalScroll(wallsSc), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        walls(room, snap).forEach { w ->
            val len = wallLen(room, snap, w.id)
            Box(Modifier.onGloballyPositioned { c -> if (!shown && w.id == m.wall) { shown = true; val x = c.positionInParent().x.toInt(); if (x > 0) scope.launch { wallsSc.scrollTo(x) } } }) {
                Chip(tr("kt.wallN", "w" to w.id) + (len?.let { " · " + uz.metrx.app.geo.fmtLen(it, app.settings.unit, app.settings.lang == uz.metrx.app.core.Lang.EN) + " " + unitWord(app.settings.unit) } ?: ""), w.id == m.wall) { if (w.id != m.wall) moveTo(w.id, len) }
            }
        }
    }
    ValRow(tr("wd.x"), "${m.x} " + tr("u.mm")) { app.sheet = Sheet.WField(p.id, f.id, "x") }
    ValRow(tr("wd.w"), "${m.w} " + tr("u.mm")) { app.sheet = Sheet.WField(p.id, f.id, "w") }
    // the room's plan, to drag it where it should stand
    GBtn(tr("fz.move"), { app.push(Route.FPlace(p.id, f.id, room.id)) }, Btn.SECONDARY, icon = "room", height = 44.dp, corner = 14.dp, fontSize = 14f)
    if (!measured(room, snap, m.wall ?: "")) Text(tr("kt.noLen", "w" to (m.wall ?: "")), style = ui(12.5f, 500, G.amberInk, 1.4f))
}

@Composable
private fun SizeStep(p: Project, f: Furniture, m: Module, ws: Workshop) {
    val app = LocalApp.current
    Text(tr("wd.sizes"), style = ui(15.5f, 800))
    ValRow(tr("wd.w"), "${m.w} " + tr("u.mm")) { app.sheet = Sheet.WField(p.id, f.id, "w") }
    ValRow(tr("wd.h"), "${m.h} " + tr("u.mm")) { app.sheet = Sheet.WField(p.id, f.id, "h") }
    ValRow(tr("wd.d"), "${m.d} " + tr("u.mm")) { app.sheet = Sheet.WField(p.id, f.id, "d") }
    Text(tr("wd.base"), style = ui(14.5f, 700))
    // plinth or legs, each with its height; the whole height stays, the carcass gives way. A cabinet can hang on the wall
    // (a stacked box stands on the one under it)
    val hung = uz.metrx.app.furniture.hung(m)
    val stacked = f.type in uz.metrx.app.furniture.STACK_TYPES && hung
    val cur = when { hung -> "wall"; m.legs -> "legs"; else -> "plinth" }
    if (!stacked) Seg(listOf("plinth" to tr("wd.plinth"), "legs" to tr("wd.legs")) + (if (f.type.isNotEmpty()) listOf("wall" to tr("wd.hang")) else emptyList()), cur) { k ->
        if (k != cur) app.ward(p.id, f.id) { mm ->
            when (k) {
                // on the wall its top stays where it was: lifted by its plinth or legs, the carcass that much lower
                "wall" -> {
                    val e = maxOf(100, uz.metrx.app.furniture.legsOf(mm, ws) + wardBase(mm))
                    mm.copy(legs = false, base = 0, elev = e, h = (outerH(mm, ws) - e).coerceAtLeast(300))
                }
                else -> {
                    val legs = if (k == "legs") ws.legH else 0
                    // back on the floor: what it was lifted by (at most a plinth's or the legs' height) comes back, so a round trip keeps its height
                    val whole = if (uz.metrx.app.furniture.hung(mm)) mm.h + minOf(mm.elev, maxOf(100, PLINTH, ws.legH)) else outerH(mm, ws)
                    mm.copy(legs = k == "legs", base = null, elev = 0, h = (whole - legs).coerceAtLeast(300))
                }
            }
        }
    }
    if (hung && !stacked) ValRow(tr("fz.elev"), "${m.elev} " + tr("u.mm")) { app.sheet = Sheet.WField(p.id, f.id, "e") }
    else if (!hung) ValRow(tr(if (m.legs) "wd.legsH" else "wd.plinthH"), "${if (m.legs) uz.metrx.app.furniture.legsOf(m, ws) else wardBase(m)} " + tr("u.mm")) { app.sheet = Sheet.WField(p.id, f.id, "base") }
    // a dressing table's mirror on the wall over it
    f.modules.firstOrNull { it.type == "mirror" }?.let { r ->
        Text(tr("pc.mirror"), style = ui(14.5f, 700))
        ValRow(tr("fz.mirW"), "${r.w} " + tr("u.mm")) { app.sheet = Sheet.IField(p.id, f.id, r.id, "w") }
        ValRow(tr("fz.mirH"), "${r.h} " + tr("u.mm")) { app.sheet = Sheet.IField(p.id, f.id, r.id, "h") }
        ValRow(tr("fz.elev"), "${r.elev} " + tr("u.mm")) { app.sheet = Sheet.IField(p.id, f.id, r.id, "e") }
    }
    Stepper(tr("wd.secCount"), m.sections.size, 1, 8) { n ->
        app.ward(p.id, f.id) { mm ->
            val ih = wardInnerH(mm, ws.t)
            val secs = if (n > mm.sections.size) mm.sections + List(n - mm.sections.size) { spreadShelves(Section(0, inserts = List(5) { Insert("shelf") }), ih, ws.t) }
            else mm.sections.take(n)
            val split = splitSections(mm.w, secs.let { s -> if (s.all { it.lock }) s.map { it.copy(lock = false) } else s })
            mm.copy(sections = split.mapIndexed { i, s -> if (i < mm.sections.size) s else s.copy(fronts = Fronts("door", if (s.w >= 600) 2 else 1)) })
        }
    }
    m.sections.chunked(4).forEachIndexed { row, chunk ->
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            chunk.forEachIndexed { k, s ->
                val i = row * 4 + k
                Column(Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(G.glass(.8f)).border(1.dp, G.rim, RoundedCornerShape(12.dp))
                    .clickable(role = Role.Button) { app.sheet = Sheet.WField(p.id, f.id, "secW", i) }.padding(horizontal = 8.dp, vertical = 6.dp)) {
                    Text("${s.w}", style = num(15f, 800))
                    Text(tr(if (s.lock) "wd.lock" else "wd.eq"), style = ui(10.5f, 600, if (s.lock) G.cobalt2 else G.ink2), maxLines = 1)
                }
            }
            repeat(4 - chunk.size) { Spacer(Modifier.weight(1f)) }
        }
    }
    val carcass = app.settings.mats.firstOrNull { it.id == f.mats.carcass }?.name ?: f.mats.carcass
    Text(tr("wd.sizeNote", "d" to m.d, "b" to (if (m.legs) tr("wd.legs") else tr("wd.plinth")), "m" to carcass), style = ui(12.5f, 400, G.ink2, 1.4f))
}

/** Sliding doors: how many, what each one is filled with, and their sizes. */
@Composable
private fun SlideDoors(p: Project, f: Furniture, m: Module, sl: uz.metrx.app.furniture.Slide, ws: Workshop) {
    val app = LocalApp.current
    val n = sl.n.coerceIn(2, 4)
    Stepper(tr("wd.slideN"), n, 2, 4) { v -> app.ward(p.id, f.id) { mm -> mm.copy(slide = sl.copy(n = v)) } }
    (0 until n).forEach { i ->
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("wd.slideI", "n" to i + 1), style = ui(14f, 600), modifier = Modifier.width(76.dp), maxLines = 1)
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("ldsp", "mirror", "glass").forEach { k ->
                    Chip(tr("wd.fill.$k"), sl.panel(i) == k) {
                        app.ward(p.id, f.id) { mm -> mm.copy(slide = sl.copy(panels = List(n) { j -> if (j == i) k else sl.panel(j) })) }
                    }
                }
            }
        }
    }
    val (dw, dh) = uz.metrx.app.furniture.slideDoor(m, ws.t)
    val (pw, ph) = uz.metrx.app.furniture.slidePanel(m, ws.t)
    Text(tr("wd.slideSize", "w" to dw, "h" to dh, "pw" to pw, "ph" to ph), style = num(14f, 700))
    Text(tr("wd.slideNote", "d" to uz.metrx.app.furniture.SLIDE_D), style = ui(12.5f, 400, G.ink2, 1.4f))
}

@Composable
private fun DoorStep(p: Project, f: Furniture, m: Module, sel: Int, ws: Workshop, onSec: (Int) -> Unit) {
    val app = LocalApp.current
    val s = m.sections.getOrNull(sel) ?: return
    // hinged doors on each section, or sliding doors over the whole front (plan 1b-2)
    // sliding doors are for wardrobes; the other cabinets have hinged doors or none
    if (f.type.isEmpty()) Seg(listOf("hinged" to tr("wd.hingedT"), "slide" to tr("wd.slideT")), if (m.slide == null) "hinged" else "slide") { k ->
        if ((k == "slide") != (m.slide != null)) app.ward(p.id, f.id) { mm ->
            mm.copy(slide = if (k == "slide") uz.metrx.app.furniture.Slide(uz.metrx.app.furniture.slideDoorsFor(uz.metrx.app.furniture.slideOpening(mm, ws.t).first)) else null)
        }
    }
    m.slide?.let { sl ->
        SlideDoors(p, f, m, sl, ws)
        // the drawers behind the sliding doors: their handles one by one, or all of the box at once
        HandleButtons(listOf(m), { app.ward(p.id, f.id) { uz.metrx.app.furniture.allHandles(it, true) } }, { app.ward(p.id, f.id) { uz.metrx.app.furniture.allHandles(it, false) } })
        InnerDrawers(m) { fr -> app.ward(p.id, f.id) { uz.metrx.app.furniture.toggleHandle(it, fr.key) } }
        return
    }
    Text(tr("wd.doors", "s" to sel + 1), style = ui(15.5f, 800))
    SecChips(m, sel, onSec)
    val cur = when { s.fronts.kind == "open" -> "0"; s.fronts.n >= 2 -> "2"; else -> "1" }
    fun fr(k: String) = when (k) { "0" -> Fronts("open", 0); "2" -> Fronts("door", 2); else -> Fronts("door", 1) }
    Seg(listOf("2" to tr("wd.d2"), "1" to tr("wd.d1"), "0" to tr("wd.d0")), cur) { k -> app.changeSec(p.id, f.id, sel) { it.copy(fronts = fr(k)) } }
    // what the doors are: the front board, a mirror on it, or glass in an aluminium frame
    if (cur != "0") Seg(listOf("" to tr("wd.face.ldsp"), "mirror" to tr("wd.face.mirror"), "glass" to tr("wd.face.glass")), s.face) { k -> app.changeSec(p.id, f.id, sel) { it.copy(face = k) } }
    // one door: which way it opens, its handle on the other edge
    if (cur == "1") {
        Seg(listOf("L" to tr("wd.openL"), "R" to tr("wd.openR")), if (uz.metrx.app.furniture.hingeRight(m, sel)) "R" else "L") { k -> app.changeSec(p.id, f.id, sel) { it.copy(hinge = k) } }
        Text(tr("wd.openNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Spacer(Modifier.weight(1f))
        GBtn(tr("wd.all"), { app.ward(p.id, f.id) { mm -> mm.copy(sections = mm.sections.map { uz.metrx.app.furniture.frontsChanged(it, it.copy(fronts = if (cur == "0") fr("0") else Fronts("door", if (cur == "2" && it.w >= 400) 2 else 1))) }) } },
            Btn.SECONDARY, height = 40.dp, corner = 14.dp, fontSize = 14f, fill = false)
    }
    // handles: each door and drawer on its own (tapped on the drawing), or all of the box at once (25 Oct 2026)
    val edge = uz.metrx.app.furniture.opensByEdge(f)
    HandleButtons(listOf(m), { app.ward(p.id, f.id) { uz.metrx.app.furniture.allHandles(it, true) } }, { app.ward(p.id, f.id) { uz.metrx.app.furniture.allHandles(it, false) } }, edge)
    if (uz.metrx.app.furniture.handleFronts(m).any { !it.inner }) Text(tr(if (edge) "hd.tapE" else "hd.tap"), style = ui(12.5f, 400, G.ink2, 1.4f))
    // the drawers behind the doors are hidden on the picture: a chip each (25 Oct 2026)
    InnerDrawers(m) { fr -> app.ward(p.id, f.id) { uz.metrx.app.furniture.toggleHandle(it, fr.key) } }
    // soft close: this section's doors; "Hammasiga" gives every section of the piece the same
    if (cur != "0") {
        val soft = uz.metrx.app.furniture.softOf(m, sel)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f)) { Toggle(tr("km.soft") + " · " + tr("hd.secN", "s" to sel + 1), soft) { app.ward(p.id, f.id) { uz.metrx.app.furniture.withSoft(it, sel, !soft) } } }
            GBtn(tr("hd.all"), {
                app.kit.change(app, p.id, f.id) { x -> x.copy(modules = x.modules.map { if (it.type == "wardrobe") uz.metrx.app.furniture.softAll(it, soft) else it }) }
                app.say("hd.softAll", "v" to app.t(if (soft) "hd.yes" else "hd.no"))
            }, Btn.SECONDARY, height = 40.dp, corner = 14.dp, fontSize = 14f, fill = false)
        }
    }
    val dh = frontSizes(Fronts("door", 1), s.w, m.h - wardBase(m), ws).firstOrNull()?.first
    // how many hinges: workshop detail, the advanced app only
    if (dh != null) Text((if (app.settings.advanced) tr("wd.hinges", "v" to dh, "n" to hingesFor(dh)) + " " else "") + tr("wd.tapSec"), style = ui(12.5f, 400, G.ink2, 1.4f))
}

@Composable
private fun InsideStep(p: Project, f: Furniture, m: Module, sel: Int, ws: Workshop, onSec: (Int) -> Unit) {
    val app = LocalApp.current
    val s = m.sections.getOrNull(sel) ?: return
    Text(tr("wd.inside", "s" to sel + 1), style = ui(15.5f, 800))
    SecChips(m, sel, onSec)
    if (s.inserts.isEmpty()) Text(tr("wd.empty"), style = ui(13f, 400, G.ink2, 1.4f))
    else if (s.inserts.size > 1) Text(tr("wd.dragNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    // the list from the top down; a row's handle drags it to another place, then they all spread evenly over the section
    val rows = s.inserts.withIndex().sortedByDescending { it.value.pos }
    var dragI by remember(sel) { mutableIntStateOf(-1) }
    var dragDy by remember(sel) { mutableFloatStateOf(0f) }
    val pitch = with(androidx.compose.ui.platform.LocalDensity.current) { 52.dp.toPx() }
    // the drag's end reads the section as it is then (an edit, an undo or a first reorder may have changed it)
    fun drop(from: Int, dy: Float) {
        app.changeSec(p.id, f.id, sel) { sec ->
            val now = sec.inserts.sortedByDescending { it.pos }
            val to = (from + (dy / pitch).roundToInt()).coerceIn(0, now.lastIndex)
            if (from !in now.indices || to == from) return@changeSec sec
            val order = now.toMutableList().apply { add(to, removeAt(from)) }
            sec.copy(inserts = uz.metrx.app.furniture.respaced(order.reversed(), wardInnerH(m, ws.t), ws.t).sortedBy { y -> y.pos })
        }
    }
    val dropNow by androidx.compose.runtime.rememberUpdatedState(::drop)
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) { rows.forEachIndexed { r, (i, x) ->
        Row(Modifier.fillMaxWidth().height(48.dp).zIndex(if (r == dragI) 1f else 0f).graphicsLayer { translationY = if (r == dragI) dragDy else 0f }
            .clip(RoundedCornerShape(12.dp)).background(if (r == dragI) G.glass(.95f) else Color.Transparent)
            .clickable(role = Role.Button) { app.sheet = Sheet.WInsert(p.id, f.id, sel, i) }.padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (rows.size > 1) Box(Modifier.size(40.dp).pointerInput(sel, r, rows.size) {
                detectDragGestures(onDragStart = { dragI = r; dragDy = 0f }, onDragEnd = { dropNow(dragI, dragDy); dragI = -1; dragDy = 0f },
                    onDragCancel = { dragI = -1; dragDy = 0f }) { ch, d -> ch.consume(); dragDy += d.y }
            }.semantics { contentDescription = app.t("wd.drag") }, contentAlignment = Alignment.Center) { MIcon("grip", G.ink3, 20.dp, 2f) }
            Text(tr("wi.${x.kind}"), style = ui(14f, 700), modifier = Modifier.weight(1f))
            Text(if (blockH(x) > 0) tr("wi.atH", "v" to x.pos, "h" to blockH(x)) else tr("wi.at", "v" to x.pos), style = num(13.5f, 600, G.ink2))
            Box(Modifier.size(40.dp).clip(CircleShape).clickable(role = Role.Button) {
                app.changeSec(p.id, f.id, sel) { it.copy(inserts = it.inserts.filterIndexed { k, _ -> k != i }) }
                app.say("kt.deleted", "m" to app.t("wi.${x.kind}"), action = "common.undo", onAction = { app.kit.undo(app, p.id, f.id) })
            }, contentAlignment = Alignment.Center) { MIcon("x", G.ink3, 16.dp, 2f) }
        }
    } }
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        listOf("shelf" to "wd.addShelf", "drawer" to "wd.addDrawer", "rail" to "wd.addRail").forEach { (k, t) -> Chip(tr(t), false) { app.addInsert(p.id, f.id, m, sel, k) } }
        Chip(tr("wd.more"), false) { app.sheet = Sheet.WMore(p.id, f.id, sel) }
    }
    if (s.inserts.count { it.kind == "shelf" } > 1) GBtn(tr("wd.spread"), {
        app.changeSec(p.id, f.id, sel) { spreadShelves(it, wardInnerH(m, ws.t), ws.t) }
    }, Btn.SECONDARY, height = 42.dp, corner = 14.dp, fontSize = 14f)
    // the strip runs along the whole box's top, not the section picked above: it says so (25 Oct 2026)
    Toggle(tr("wd.ledAll"), m.led) { app.ward(p.id, f.id) { it.copy(led = !it.led) } }
}

@Composable
internal fun MatStep(p: Project, f: Furniture, mats: List<Mat>) {
    val app = LocalApp.current
    Text(tr("wd.mats"), style = ui(15.5f, 800))
    listOf("carcass" to f.mats.carcass, "front" to f.mats.front, "back" to f.mats.back).forEach { (role, id) ->
        val mt = mats.firstOrNull { it.id == id }
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp)).clickable(role = Role.Button) { app.sheet = Sheet.FMats(p.id, f.id) }.padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(28.dp).clip(RoundedCornerShape(8.dp)).background(hex(mt?.rgb ?: "#FFFFFF")).border(1.dp, G.ink.copy(alpha = .2f), RoundedCornerShape(8.dp)))
            Text(tr("wd.$role"), style = ui(14.5f, 700), modifier = Modifier.weight(1f))
            Text(mt?.name ?: id, style = ui(13.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            MIcon("chev", G.ink3, 16.dp, 2f)
        }
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun WardrobeSheet(s: Sheet): Boolean = when (s) {
    is Sheet.WField -> { WFieldSheet(s); true }
    is Sheet.WInsert -> { WInsertSheet(s); true }
    is Sheet.WMore -> { WMoreSheet(s); true }
    is Sheet.FMats -> { FMatsSheet(s); true }
    is Sheet.IField -> { IFieldSheet(s); true }
    else -> false
}

@Composable
private fun WFieldSheet(s: Sheet.WField) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val m = app.curWard(f) ?: run { app.sheet = null; return }
    val wallL = roomOf(p, f)?.let { wallLen(it, app.settings.angleSnap, m.wall ?: "") }
    val n = m.sections.size
    val sec = m.sections.getOrNull(s.sec)
    val (start, range) = when (s.key) {
        "h" -> m.h to (if (f.type.isNotEmpty()) 150..3000 else 600..3000)
        "e" -> m.elev to (50..2400)
        "d" -> m.d to (250..900)
        "x" -> m.x to (0..max(0, (wallL ?: 10000) - 300))
        "base" -> (if (m.legs) uz.metrx.app.furniture.legsOf(m, app.settings.workshop) else wardBase(m)) to (if (m.legs) 50..250 else 50..200)
        // a section can grow until each of the others keeps 150 (locked ones their width, one of them gives way if all are)
        "secW" -> (sec?.w ?: 0) to if (n == 1) (m.w..m.w) else m.sections.filterIndexed { i, _ -> i != s.sec }.let { o ->
            val locked = o.filter { it.lock }; val give = if (locked.size == o.size) locked.last().w - 150 else 0
            150..max(150, m.w - locked.sumOf { it.w } - 150 * (o.size - locked.size) + give)
        }
        else -> m.w to (300..6000)
    }
    var v by rememberSaveable { mutableStateOf(start.toString()) }
    val vi = v.toIntOrNull()?.takeIf { it in range }
    // the keyboard comes up with the sheet
    val fr = remember { androidx.compose.ui.focus.FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    val title = when (s.key) { "h" -> tr("wd.h"); "d" -> tr("wd.d"); "x" -> tr("wd.x"); "e" -> tr("fz.elev"); "base" -> tr(if (m.legs) "wd.legsH" else "wd.plinthH"); "secW" -> tr("wd.secT", "n" to s.sec + 1); else -> tr("wd.w") }
    fun save() {
        val x = vi ?: return
        app.ward(p.id, f.id) { mm ->
            when (s.key) {
                "h" -> mm.copy(h = x)
                "e" -> mm.copy(elev = x)
                "d" -> mm.copy(d = x)
                "x" -> mm.copy(x = x)
                // the whole height stays: taller legs, a shorter carcass (a plinth is inside the carcass)
                "base" -> if (mm.legs) mm.copy(base = x, h = (mm.h - (x - uz.metrx.app.furniture.legsOf(mm, app.settings.workshop))).coerceAtLeast(300)) else mm.copy(base = x)
                "secW" -> {
                    var secs = mm.sections.mapIndexed { i, ss -> if (i == s.sec) ss.copy(w = x, lock = true) else ss }
                    // someone has to give way: the last other section takes what is left
                    if (secs.all { it.lock } && secs.size > 1) secs = secs.mapIndexed { i, ss -> if (i == (if (s.sec == secs.lastIndex) secs.lastIndex - 1 else secs.lastIndex)) ss.copy(lock = false) else ss }
                    mm.copy(sections = splitSections(mm.w, secs))
                }
                else -> mm.copy(w = x, sections = splitSections(x, mm.sections.let { ss -> if (ss.all { it.lock }) ss.map { it.copy(lock = false) } else ss }))
            }
        }
        app.sheet = null
    }
    GlassSheet(title, { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save, enabled = vi != null) }) {
        GField(title, v, { v = it.filter(Char::isDigit).take(4) }, "$start", number = true, labelRight = tr("u.mm"), error = tr("km.bad", "a" to range.first, "b" to range.last),
            showError = vi == null, imeAction = ImeAction.Done, onIme = ::save, focusRequester = fr)
        if (s.key == "secW") {
            Text(tr("wd.secNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
            if (sec?.lock == true) GBtn(tr("wd.unlock"), {
                app.ward(p.id, f.id) { mm -> mm.copy(sections = splitSections(mm.w, mm.sections.mapIndexed { i, ss -> if (i == s.sec) ss.copy(lock = false) else ss })) }
                app.sheet = null
            }, Btn.SECONDARY, height = 44.dp, corner = 14.dp, fontSize = 14.5f)
        }
        if (s.key == "x" && wallL != null) Text(tr("wd.xNote", "v" to wallL - m.w - (vi ?: m.x)), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

@Composable
private fun WInsertSheet(s: Sheet.WInsert) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val m = app.curWard(f) ?: run { app.sheet = null; return }
    val x = m.sections.getOrNull(s.sec)?.inserts?.getOrNull(s.idx) ?: run { app.sheet = null; return }
    val ih = wardInnerH(m, app.settings.workshop.t)
    val block = blockH(x) > 0
    var pos by rememberSaveable { mutableStateOf(x.pos.toString()) }
    var h by rememberSaveable { mutableStateOf(blockH(x).toString()) }
    val pi = pos.toIntOrNull()?.takeIf { it in 0..ih }
    val hi = if (block) h.toIntOrNull()?.takeIf { it in 60..1200 } else 0
    fun save() {
        if (pi == null || hi == null) return
        app.changeSec(p.id, f.id, s.sec) { ss -> ss.copy(inserts = ss.inserts.mapIndexed { k, y -> if (k == s.idx) y.copy(pos = pi, h = if (block) hi else y.h) else y }.sortedBy { it.pos }) }
        app.sheet = null
    }
    GlassSheet(tr("wi.${x.kind}"), { app.sheet = null }, footer = {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("common.delete"), {
                app.changeSec(p.id, f.id, s.sec) { ss -> ss.copy(inserts = ss.inserts.filterIndexed { k, _ -> k != s.idx }) }
                app.sheet = null
                app.say("kt.deleted", "m" to app.t("wi.${x.kind}"), action = "common.undo", onAction = { app.kit.undo(app, p.id, f.id) })
            }, Btn.DANGER, icon = "trash", height = 48.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1f))
            GBtn(tr("common.save"), ::save, enabled = pi != null && hi != null, height = 48.dp, corner = 16.dp, fontSize = 15f, modifier = Modifier.weight(1.4f))
        }
    }) {
        GField(tr("wd.pos"), pos, { pos = it.filter(Char::isDigit).take(4) }, "0", number = true, labelRight = tr("u.mm"), error = tr("km.bad", "a" to 0, "b" to ih),
            showError = pi == null, imeAction = if (block) ImeAction.Next else ImeAction.Done, onIme = { if (!block) save() })
        if (block) GField(tr("wd.bh"), h, { h = it.filter(Char::isDigit).take(4) }, "200", number = true, labelRight = tr("u.mm"), error = tr("km.bad", "a" to 60, "b" to 1200),
            showError = hi == null, imeAction = ImeAction.Done, onIme = ::save)
        Text(tr("wd.posNote", "v" to ih), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

@Composable
private fun WMoreSheet(s: Sheet.WMore) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val m = app.curWard(f) ?: run { app.sheet = null; return }
    GlassSheet(tr("wd.moreT"), { app.sheet = null }) {
        listOf("trouser", "shoe", "lift", "glass").forEach { k ->
            Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(16.dp)).background(G.ink.copy(alpha = .05f))
                .pressable({ app.sheet = null; app.addInsert(p.id, f.id, m, s.sec, k) }, .98f).padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(tr("wi.$k"), style = ui(15f, 700))
                    Text(tr("wid.$k") + if (blockH(Insert(k)) > 0) " · ${blockH(Insert(k))} " + tr("u.mm") else "", style = ui(12.5f, 400, G.ink2))
                }
                MIcon("plus", G.cobalt2, 20.dp, 2.4f)
            }
        }
    }
}

/** The furniture's carcass, fronts and back from the workshop's list (kitchens and wardrobes). */
@Composable
private fun FMatsSheet(s: Sheet.FMats) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val mats = app.settings.mats
    GlassSheet(tr("wd.mats"), { app.sheet = null }) {
        listOf("carcass", "front", "back").forEachIndexed { k, role ->
            if (k > 0) Hairline()
            Text(tr("wd.$role"), style = ui(15f, 800))
            val cur = when (role) { "carcass" -> f.mats.carcass; "front" -> f.mats.front; else -> f.mats.back }
            mats.filter { if (role == "back") it.kind == "back" else it.kind == "board" }.forEach { mt ->
                val on = mt.id == cur
                Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).background(if (on) G.cobalt.copy(alpha = .1f) else Color.Transparent)
                    .clickable(role = Role.RadioButton) {
                        val nm: FMats = when (role) { "carcass" -> f.mats.copy(carcass = mt.id); "front" -> f.mats.copy(front = mt.id); else -> f.mats.copy(back = mt.id) }
                        app.kit.change(app, p.id, f.id) { it.copy(mats = nm) }
                    }.padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(26.dp).clip(RoundedCornerShape(8.dp)).background(hex(mt.rgb)).border(1.dp, G.ink.copy(alpha = .2f), RoundedCornerShape(8.dp)))
                    Text(mt.name, style = ui(14.5f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink), modifier = Modifier.weight(1f))
                    if (on) MIcon("check", G.cobalt2, 18.dp, 2.4f)
                }
            }
        }
    }
}
