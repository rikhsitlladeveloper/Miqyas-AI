package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.shortMoney
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.furniture.F_MODELS
import uz.metrx.app.furniture.FModelDef
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.K_CORNER
import uz.metrx.app.furniture.W_DEPTH
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.fitIssues
import uz.metrx.app.furniture.fitTo
import uz.metrx.app.furniture.freeLen
import uz.metrx.app.furniture.freeRunMm
import uz.metrx.app.furniture.newFreeKitchen
import uz.metrx.app.furniture.newFreeWardrobe
import uz.metrx.app.furniture.placeWalls
import uz.metrx.app.furniture.placed
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.furniture.runEnd
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.sidesOf
import uz.metrx.app.furniture.takenOut
import uz.metrx.app.furniture.wardOfF
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * Furniture without a room (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html v4): after the
 * three-field new order, "Nima kerak?"; for each piece the room or only its sizes; a gallery of ready models with 3D
 * pictures; the sizes; later "Xonaga qo‘yish" into a measured room, and "Xonadan chiqarish" back out. The rules are in
 * furniture/Free.kt.
 */

/* ---------------- the order's name and what is still wanted ---------------- */

/** While the order's name follows its furniture: "Oshxona — Akmal", "Shkaf — Akmal", "Oshxona va shkaf — Akmal". */
fun App.renameOrder(pid: String) {
    store.update(pid) { p ->
        if (!p.autoName) p else {
            val ks = (p.furniture.map { uz.metrx.app.furniture.kindKey(it) } + (p.want ?: emptyList())).toSet()
            val what = when {
                ks.isEmpty() -> null
                ks == setOf("kitchen", "wardrobe") -> t("fo.both")
                ks == setOf("wardrobe") -> t("kt.wardrobe")
                ks == setOf("kitchen") -> t("kt.kitchen")
                else -> t("fz.furn")
            }
            p.copy(name = what?.let { it + " — " + p.customer } ?: p.customer)
        }
    }
}

/** A room every wall and the height of which are confirmed. */
fun measuredRoom(r: uz.metrx.app.data.Room, snap: Boolean) = stepKeys(r, snap).all { r.dim(it).status == "conf" }

/** Takes the piece out of its room: its sizes from what stands on the walls now. */
fun App.takeOut(pid: String, fid: String) {
    val p = store.get(pid) ?: return
    val f = p.furniture.firstOrNull { it.id == fid } ?: return
    val room = roomOf(p, f)
    val snap = settings.angleSnap
    val g = takenOut(f, { id -> room?.let { wallLen(it, snap, id) } }, room?.dim("H")?.v)
    store.update(pid) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == fid) g else it }) }
    kit.sel = null; kit.tick++
    say("fz.outDone", "n" to dn(f.name, settings.lang))
}

internal fun App.designer(pid: String, f: Furniture, step: Int = 1): Route =
    if (f.kind == "wardrobe") Route.Wardrobe(pid, f.id, step = step) else Route.Kitchen(pid, f.id)

/* ---------------- the page frame ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun FPage(eyebrow: String, title: String, back: () -> Unit, footer: (@Composable ColumnScope.() -> Unit)? = null, body: @Composable ColumnScope.() -> Unit) {
    val imeOn = WindowInsets.isImeVisible
    val foot: @Composable (Modifier) -> Unit = { m -> if (footer != null) FloatingFooter(m) { footer() } }
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), back, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(title, eyebrow = eyebrow)
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = if (footer != null && !imeOn) 120.dp else 28.dp)
                    .let { if (footer == null) it.navigationBarsPadding() else it },
                verticalArrangement = Arrangement.spacedBy(12.dp), content = body
            )
            if (imeOn) foot(Modifier)
        }
        if (!imeOn) foot(Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun ChoiceRow(icon: String, title: String, sub: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(22.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 78.dp).clip(shape).glassCard(shape, fill = G.glass(.62f)).clickable(role = Role.Button, onClick = onClick)
        .padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(46.dp).clip(RoundedCornerShape(14.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { MIcon(icon, G.cobalt, 24.dp, 2f) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = ui(16.5f, 800))
            Text(sub, style = ui(13f, 400, G.ink2, 1.35f))
        }
        MIcon("chev", G.ink3, 16.dp, 2f)
    }
}

/* ---------------- "Nima kerak?" ---------------- */

@Composable
fun FNeedScreen(rt: Route.FNeed) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    fun pick(k: String) {
        if (k == "later") { app.pop(); return }
        val ks = if (k == "both") listOf("kitchen", "wardrobe") else listOf(k)
        app.store.update(p.id) { it.copy(want = ((it.want ?: emptyList()) + ks).distinct()) }
        app.renameOrder(p.id)
        app.replaceTop(Route.FHow(p.id, ks[0]))
    }
    FPage(dn(p.name, lang), tr("fo.what"), { app.pop() }) {
        ChoiceRow("kitchen", tr("kt.kitchen"), tr("fz.needKs")) { pick("kitchen") }
        ChoiceRow("board", tr("kt.wardrobe"), tr("fz.needWs")) { pick("wardrobe") }
        ChoiceRow("layers", tr("fz.needB"), tr("fz.needBs")) { pick("both") }
        ChoiceRow("box", tr("fz.needO"), tr("fz.needOs")) { pick("other") }
        ChoiceRow("clock", tr("fz.needL"), tr("fz.needLs")) { pick("later") }
    }
}

/* ---------------- the room, or only the sizes ---------------- */

@Composable
fun FHowScreen(rt: Route.FHow) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    FPage(dn(p.name, lang), tr("fz.howT", "k" to tr(when (rt.kind) { "kitchen" -> "kt.kitchen"; "other" -> "fz.furn"; else -> "kt.wardrobe" })), { app.pop() }) {
        ChoiceRow("room", tr("fz.howRoom"), tr("fz.howRoomS")) { app.pop(); app.sheet = Sheet.FNewRoom(p.id, rt.kind) }
        ChoiceRow("ruler", tr("fz.howSize"), tr("fz.howSizeS")) { app.replaceTop(Route.FModels(p.id, rt.kind)) }
    }
}

/* ---------------- the gallery ---------------- */

@Composable
fun FModelsScreen(rt: Route.FModels) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    val list = uz.metrx.app.furniture.modelsOf(rt.kind)
    FPage(dn(p.name, lang), tr(when (rt.kind) { "kitchen" -> "fz.modelsK"; "other" -> "fz.modelsO"; else -> "fz.modelsW" }), { app.pop() }) {
        Text(tr("fz.modelsNote"), style = ui(14f, 400, G.ink2, 1.4f))
        list.groupBy { it.group }.forEach { (g, ms) ->
            if (g.isNotEmpty()) Text(tr("kt.$g"), style = ui(16f, 800), modifier = Modifier.padding(top = 6.dp))
            ms.chunked(2).forEach { row ->
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { m -> ModelCard(m, Modifier.weight(1f).fillMaxHeight(), wide = row.size == 1) { pickModel(app, p.id, m) } }
                }
            }
        }
    }
}

private fun pickModel(app: App, pid: String, m: FModelDef) {
    app.push(Route.FSizes(pid, m.kind, m.id))
}

@Composable
private fun ModelCard(m: FModelDef, modifier: Modifier, wide: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    val name = tr("fz.m.${m.id}")
    val body: @Composable (Modifier) -> Unit = { pm ->
        Box(pm.clip(RoundedCornerShape(14.dp))) {
            ModelPic(m, m.sides, m.island, m.w, m.h, m.d, Modifier.fillMaxWidth())
        }
    }
    val text: @Composable () -> Unit = {
        Column(Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(name, style = ui(14.5f, 800, G.ink), maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(tr("fz.s.${m.id}"), style = ui(12f, 500, G.ink2, 1.3f), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
    val mod = modifier.clip(shape).glassCard(shape, fill = G.glass(.62f)).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = name }.padding(8.dp)
    // the last card of an odd row takes the whole width, its picture beside the words
    if (wide) Row(mod, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        body(Modifier.weight(1f)); Box(Modifier.weight(1f)) { text() }
    } else Column(mod, verticalArrangement = Arrangement.spacedBy(6.dp)) { body(Modifier.fillMaxWidth()); text() }
}

/* ---------------- the 3D picture of a model (the mockup's iso sketch) ---------------- */

private val PIC_BG = Color(0xFFF6F8FC)
private val FLOOR = Color(0xFFE8ECF3); private val FLOOR_LN = Color(0xFFC9D1DE)
private val WALL_F = Color(0x0D3550E0); private val WALL_F2 = Color(0x0A3550E0); private val WALL_LN = Color(0x2E3550E0)
private val LO = Color(0xFFD9E2EF); private val SI = Color(0xFFC9D5E6); private val TOP = Color(0xFF4B4F58); private val UP = Color(0xFFE4EAF3); private val LN = Color(0xFF7A8BA6)
private val DARK = Color(0xFF333333)
private val WD = Color(0xFFE8E0D3); private val WD_OPEN = Color(0xFFF3EEE6); private val WD_LN = Color(0xFF8C7A62)

private fun iso(x: Float, y: Float, z: Float) = Offset(130f + (x - y) * .62f, 150f + (x + y) * .33f - z)

private fun DrawScope.poly(pts: List<Offset>, fill: Color, line: Color, dashed: Boolean = false) {
    val path = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { lineTo(it.x, it.y) }; close() }
    drawPath(path, fill)
    drawPath(path, line, style = Stroke(1f, pathEffect = if (dashed) PathEffect.dashPathEffect(floatArrayOf(4f, 3f)) else null))
}

/** A box seen from the front-right: its front, right side and top, as the mockup draws them. */
private fun DrawScope.box(x: Float, y: Float, w: Float, d: Float, h: Float, fill: Color, line: Color, z0: Float = 0f) {
    val p = listOf(iso(x, y, z0), iso(x + w, y, z0), iso(x + w, y + d, z0), iso(x, y + d, z0),
        iso(x, y, z0 + h), iso(x + w, y, z0 + h), iso(x + w, y + d, z0 + h), iso(x, y + d, z0 + h))
    poly(listOf(p[3], p[2], p[6], p[7]), fill, line); poly(listOf(p[1], p[2], p[6], p[5]), fill, line); poly(listOf(p[4], p[5], p[6], p[7]), fill, line)
}

private fun DrawScope.vline(x: Float, y: Float, z0: Float, z1: Float, c: Color, w: Float = 1f) = drawLine(c, iso(x, y, z0), iso(x, y, z1), w)

/** The model drawn as a small 3D sketch on a floor with faint walls, sized to fill a 260 × 230 picture. */
@Composable
fun ModelPic(m: FModelDef, sides: List<Int>, island: Int, w: Int, h: Int, d: Int, modifier: Modifier) {
    Canvas(modifier.aspectRatio(260f / 230f).background(PIC_BG)) {
        val k0 = size.width / 260f
        withTransform({ scale(k0, k0, pivot = Offset.Zero) }) { drawModel(m, sides, island, w, h, d) }
    }
}

private fun DrawScope.drawModel(m: FModelDef, sides: List<Int>, island: Int, ww: Int, hh: Int, dd: Int) {
    if (m.type.isNotEmpty()) { drawCabinet(m.type, max(ww, 300), max(hh, 300), max(dd, 250)); return }
    val kit = m.kind == "kitchen"; val L = m.layout
    fun side(i: Int) = sides.getOrElse(i) { 600 }.coerceAtLeast(600).toFloat()
    val main = if (kit) (if (L == "U") side(1) else side(0)) else max(ww, 300).toFloat()
    val turns = kit && L != "I"
    val k = min(.05f, (if (kit) 140f else 105f) / (if (turns) main + 900f else main))
    val deep = if (kit) when (L) { "L" -> side(1); "U" -> max(side(0), side(2)); "P" -> max(island, 600).toFloat(); "O" -> 2400f; else -> 600f } else max(dd, 300).toFloat()
    val W = main * k + 30f; val D = max(deep * k + 30f, 90f); val H = (if (kit) max(hh, 2000) else max(hh + 150, 2500)) * k
    poly(listOf(iso(0f, 0f, 0f), iso(W, 0f, 0f), iso(W, D, 0f), iso(0f, D, 0f)), FLOOR, FLOOR_LN)
    poly(listOf(iso(0f, 0f, 0f), iso(W, 0f, 0f), iso(W, 0f, H), iso(0f, 0f, H)), WALL_F, WALL_LN, dashed = true)
    if (kit && (L == "L" || L == "U")) poly(listOf(iso(0f, 0f, 0f), iso(0f, D, 0f), iso(0f, D, H), iso(0f, 0f, H)), WALL_F2, WALL_LN, dashed = true)
    if (kit) {
        val d = 600 * k; val lo = 870 * k; val up0 = 1450 * k; val up = 720 * k; val ud = 350 * k; val t = 40 * k
        fun run(x: Float, y: Float, w: Float, uppers: Boolean) { box(x, y, w, d, lo, LO, LN); box(x, y, w, d, t, TOP, DARK, lo); if (uppers) box(x, y, w, ud, up, UP, LN, up0) }
        fun leg(x: Float, y: Float, len: Float, uppers: Boolean) { box(x, y, d, len, lo, SI, LN); box(x, y, d, len, t, TOP, DARK, lo); if (uppers) box(x, y, ud, len, up, UP, LN, up0) }
        val a = main * k
        if (L == "L") leg(0f, d, side(1) * k - d, true)
        if (L == "U") leg(0f, d, side(0) * k - d, true)
        run(0f, 0f, a, true)
        val n = max(1, (main / 600f).roundToInt()); for (i in 1 until n) vline(a * i / n, d, 0f, lo, LN)
        if (L == "U") leg(a - d, d, side(2) * k - d, false)
        if (L == "P") leg(a - d, d, max(island, 600) * k - d, false)
        if (L == "O") { val il = max(island, 600) * k; box((a - il) / 2, d + 900 * k, il, 900 * k, lo, LO, LN); box((a - il) / 2, d + 900 * k, il, 900 * k, t, TOP, DARK, lo) }
    } else {
        val w = ww * k; val dp = dd * k; val h = hh * k
        box(0f, 0f, w, dp, h, if (m.doors == "open") WD_OPEN else WD, WD_LN)
        when (m.doors) {
            "open" -> for (i in 1 until 5) { val z = h * i / 5; drawLine(WD_LN, iso(0f, dp, z), iso(w, dp, z), 1.6f) }
            "slide" -> { val n = max(2, m.n); val pw = w / n; for (i in 0 until n) box(i * pw, dp + (if (i % 2 == 1) 2 else 0) * k * 30, pw, k * 20, h * .98f, if (i % 2 == 1) Color(0xFFDCD2C2) else Color(0xFFEDE6DA), WD_LN) }
            else -> {
                val n = if (m.n > 0) m.n else max(2, (ww / 600f).roundToInt())
                for (i in 1 until n) vline(w * i / n, dp, 0f, h, WD_LN)
                for (i in 0 until n) { val x = w * (i + if (i % 2 == 1) .12f else .88f) / n; drawLine(DARK, iso(x, dp, h * .45f), iso(x, dp, h * .55f), 2f, StrokeCap.Round) }
            }
        }
    }
}

/** A Stage 2 type's picture: its template's carcass, sections, drawers, shelves and doors, as an iso sketch. */
private fun DrawScope.drawCabinet(type: String, ww: Int, hh: Int, dd: Int) {
    val cab = uz.metrx.app.furniture.cabinetTemplate(type, uz.metrx.app.furniture.Workshop(), "A", 0, ww, hh, dd)
    val k = min(.06f, 110f / max(ww, hh))
    val w = ww * k; val dp = dd * k; val h = hh * k
    val z0 = if (cab.legs) 100 * k else 0f
    poly(listOf(iso(-10f, -10f, 0f), iso(w + 30f, -10f, 0f), iso(w + 30f, dp + 60f, 0f), iso(-10f, dp + 60f, 0f)), FLOOR, FLOOR_LN)
    poly(listOf(iso(-10f, -10f, 0f), iso(w + 30f, -10f, 0f), iso(w + 30f, -10f, max(h + 40f, 120f)), iso(-10f, -10f, max(h + 40f, 120f))), WALL_F, WALL_LN, dashed = true)
    if (cab.legs) { listOf(4f, w - 6f).forEach { x -> box(x, dp - 6f, 2f, 2f, z0, DARK, DARK) } }
    val t = 16 * k
    var a = 0f
    cab.sections.forEachIndexed { i, s ->
        val sw = s.w * k
        if (s.knee) {
            // the knee space: the top over it, a side down to the floor at its far end
            box(a, 0f, sw, dp, t, WD, WD_LN, z0 + h - t)
        } else {
            box(a, 0f, sw, dp, h, if (s.fronts.kind == "open") WD_OPEN else WD, WD_LN, z0)
            val ih = h - 2 * t
            s.inserts.forEach { x ->
                val y = z0 + t + x.pos * k
                when (x.kind) {
                    "shelf" -> drawLine(WD_LN, iso(a + 1f, dp, y), iso(a + sw - 1f, dp, y), 1.2f)
                    "drawer" -> { val top = y + x.h * k; drawLine(WD_LN, iso(a + 1f, dp, top), iso(a + sw - 1f, dp, top), 1.2f)
                        drawLine(DARK, iso(a + sw * .42f, dp, y + x.h * k * .6f), iso(a + sw * .58f, dp, y + x.h * k * .6f), 1.8f, StrokeCap.Round) }
                    "rail" -> drawLine(DARK, iso(a + 2f, dp * .5f, y), iso(a + sw - 2f, dp * .5f, y), 1.4f)
                }
            }
            if (s.fronts.kind == "door") {
                val n = s.fronts.n
                for (j in 1 until n) vline(a + sw * j / n, dp, z0, z0 + h, WD_LN)
                for (j in 0 until n) { val x = a + sw * (j + if (j % 2 == 1) .12f else .88f) / n; drawLine(DARK, iso(x, dp, z0 + ih * .45f), iso(x, dp, z0 + ih * .6f), 2f, StrokeCap.Round) }
            }
        }
        if (i > 0) vline(a, dp, if (s.knee || cab.sections[i - 1].knee) 0f else z0, z0 + h, WD_LN)
        a += sw
    }
    // a desk's far side stands on the floor
    if (cab.sections.lastOrNull()?.knee == true) box(w - t, 0f, t, dp, z0 + h - t, WD, WD_LN, 0f)
}

/* ---------------- the sizes ---------------- */

/** The labels of a layout's sides, in run order. */
private fun sideKeys(layout: String): List<String> = when (layout) {
    "L" -> listOf("fz.w1", "fz.w2")
    "U" -> listOf("fz.uL", "fz.uM", "fz.uR")
    "O", "P" -> listOf("fz.pW")
    else -> listOf("fz.len")
}

@Composable
fun FSizesScreen(rt: Route.FSizes) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val m = fModel(rt.model) ?: fModel(if (rt.kind == "kitchen") "L" else "h2")!!
    val cabinet = m.type.isNotEmpty()
    val edit = rt.fid?.let { id -> p.furniture.firstOrNull { it.id == id } }
    val kit = rt.kind == "kitchen"
    val L = edit?.layout ?: m.layout
    val n = sidesOf(L)
    // what the fields start from: the piece being changed, or the model's usual sizes
    val start = edit?.free
    var sides by rememberSaveable(rt) { mutableStateOf((start?.sides ?: m.sides).take(n).map { it.toString() }.let { s -> s + List(n - s.size) { "" } }) }
    var island by rememberSaveable(rt) { mutableStateOf(((start?.island ?: m.island).takeIf { it > 0 } ?: 0).let { if (it > 0) it.toString() else "" }) }
    var ceil by rememberSaveable(rt) { mutableStateOf((start?.h ?: m.h).toString()) }
    var w by rememberSaveable(rt) { mutableStateOf(m.w.toString()) }
    var h by rememberSaveable(rt) { mutableStateOf(m.h.toString()) }
    var d by rememberSaveable(rt) { mutableStateOf(m.d.toString()) }
    var built by rememberSaveable(rt) { mutableStateOf(m.built) }
    var tried by rememberSaveable(rt) { mutableStateOf(false) }
    fun v(s: String) = s.filter { it.isDigit() }.take(5).toIntOrNull() ?: 0
    val hasIsland = L == "O" || L == "P"
    val sideErr = if (kit && sides.any { v(it) < 600 }) tr("fz.min600") else null
    val islErr = if (kit && hasIsland && v(island) < 600) tr("fz.min600") else null
    val wErr = if (!kit && !cabinet && (v(w) < 400 || v(h) < 1200)) tr("fz.minW")
        else if (cabinet && (v(w) < 300 || v(h) < 300 || v(d) < 250)) tr("fz.minC") else null
    val ok = sideErr == null && islErr == null && wErr == null

    fun create() {
        tried = true
        if (!ok) return
        val now = System.currentTimeMillis()
        val ws = app.settings.workshop
        if (edit != null) {
            // new sizes for a room-less kitchen: the units that no longer fit are cut, the rest stays
            val nf = edit.copy(free = uz.metrx.app.furniture.FreeSize(sides.map(::v), if (hasIsland) v(island) else 0, v(ceil).takeIf { it > 0 } ?: 2700))
            val g = fitTo(nf, nf.walls, { id -> freeLen(nf, id) }, null, ws)
            app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == edit.id) g else it }) }
            app.kit.tick++; app.pop(); app.say("fz.saved"); return
        }
        val count = p.furniture.count { if (cabinet) it.type == m.type else it.kind == rt.kind && it.type.isEmpty() } + 1
        val f = if (cabinet) uz.metrx.app.furniture.newFreeCabinet(app.t("ft.${m.type}") + " $count", m.type, v(w), v(h), v(d), ws, now)
            else if (kit) newFreeKitchen(app.t("kt.nameN", "n" to count), m.id, L, sides.map(::v), if (hasIsland) v(island) else 0, v(ceil).takeIf { it > 0 } ?: 2700, ws, now)
            else newFreeWardrobe(app.t("wd.nameN", "n" to count), m.id, v(w), v(h), v(d).takeIf { it >= 200 } ?: W_DEPTH, built, m.doors, ws, now, m.n)
        val moved = p.stage == "measure"
        app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture + f, stage = if (pr.stage == "measure") "design" else pr.stage,
            want = ((pr.want ?: emptyList()) + (if (cabinet) "other" else rt.kind)).distinct()) }
        app.renameOrder(p.id)
        app.kit.sel = null
        app.popTo { it is Route.Project && it.id == p.id }
        app.push(app.designer(p.id, f, step = 2))
        app.say(if (moved) "fz.createdS" else "fz.created", "n" to dn(f.name, lang), "s" to app.t("fs.design"))
    }

    FPage(dn(p.name, lang), tr(if (kit) "fz.sizesK" else if (cabinet) "fz.sizesO" else "fz.sizesW"), { app.pop() },
        footer = { GBtn(tr(if (edit != null) "common.save" else "kt.start"), ::create, enabled = !tried || ok) }) {
        // the chosen model, with a way back to the gallery
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).glassCard(RoundedCornerShape(18.dp), fill = G.glass(.62f)).padding(8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.width(96.dp).clip(RoundedCornerShape(12.dp))) {
                ModelPic(m, sides.map(::v), v(island), v(w), v(h), v(d), Modifier.fillMaxWidth())
            }
            Column(Modifier.weight(1f)) {
                Text(tr("fz.m.${m.id}"), style = ui(15.5f, 800), maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(tr("fz.s.${m.id}"), style = ui(12.5f, 400, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
            if (edit == null) GBtn(tr("fz.change"), { app.pop() }, Btn.SECONDARY, height = 40.dp, corner = 12.dp, fontSize = 13.5f, fill = false)
        }
        if (kit) {
            sideKeys(L).forEachIndexed { i, key ->
                GField(tr(key), sides.getOrElse(i) { "" }, { s -> sides = sides.toMutableList().also { it[i] = s.filter { c -> c.isDigit() }.take(5) } }, "2000",
                    number = true, labelRight = "mm", error = if (v(sides.getOrElse(i) { "" }) < 600) sideErr else null, showError = tried)
            }
            if (hasIsland) GField(tr(if (L == "P") "fz.pP" else "fz.isl"), island, { island = it.filter { c -> c.isDigit() }.take(5) }, "1800",
                number = true, labelRight = "mm", error = islErr, showError = tried)
            GField(tr("fz.ceil"), ceil, { ceil = it.filter { c -> c.isDigit() }.take(5) }, "2700", number = true, labelRight = "mm", imeAction = ImeAction.Done)
            // the running metres, as the price counts them
            val vs = sides.map(::v); val corners = n - 1
            val total = freeRunMm(L, vs, v(island))
            val t = (max(0, total) + 50) / 100
            Text(vs.joinToString(" + ") + (if (hasIsland) " + " + tr(if (L == "P") "kt.peninsula" else "kt.island").lowercase() + " " + v(island) else "") +
                (if (corners > 0) " − ${corners * K_CORNER} " + tr("kt.cornerCut") else "") + " → ${t / 10}${if (en) "." else ","}${t % 10} " + tr("kt.pm"), style = num(15f, 700))
        } else {
            GField(tr("wd.w"), w, { w = it.filter { c -> c.isDigit() }.take(5) }, "2400", number = true, labelRight = "mm", error = wErr, showError = tried)
            GField(tr("fz.wH"), h, { h = it.filter { c -> c.isDigit() }.take(5) }, "2600", number = true, labelRight = "mm")
            GField(tr("wd.d"), d, { d = it.filter { c -> c.isDigit() }.take(4) }, "600", number = true, labelRight = "mm", imeAction = ImeAction.Done)
            if (!cabinet) {
                Text(tr("fz.type"), style = ui(15f, 700))
                Seg(listOf("built" to tr("wd.built"), "free" to tr("wd.free")), if (built) "built" else "free") { built = it == "built" }
            }
            // as the wardrobe is made: about 600 a section, two doors on a section 600 or wider
            val secs = uz.metrx.app.furniture.sectionsFor(v(w).coerceAtLeast(400))
            if (m.doors == "door") Text(tr("fz.doorsH", "n" to secs * (if (v(w) / secs >= 600) 2 else 1)), style = ui(13f, 400, G.ink2, 1.4f))
            if (m.doors == "slide") Text(tr("fz.doorsS", "n" to m.n), style = ui(13f, 400, G.ink2, 1.4f))
        }
        if (edit == null) Text(tr("fz.noRoomNote"), style = ui(13f, 400, G.ink2, 1.4f))
    }
}

/* ---------------- on the designers and the order: room-less pieces ---------------- */

/** On a room-less piece's designer: it has no room yet, and the way into one. */
@Composable
fun FreeBanner(p: Project, f: Furniture) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .08f)).border(1.dp, G.cobalt.copy(alpha = .25f), RoundedCornerShape(16.dp))
        .padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(tr("fz.banner"), style = ui(13.5f, 500, G.ink, 1.4f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("fz.toRoom"), { app.sheet = Sheet.FPickRoom(p.id, f.id) }, icon = "room", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            if (f.kind == "kitchen") GBtn(tr("fz.sizesBtn"), { app.push(Route.FSizes(p.id, f.kind, f.model.ifEmpty { f.layout }, f.id)) }, Btn.SECONDARY,
                icon = "ruler", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        }
    }
}

/** A room-less piece's line: its model, sizes and running metres. */
@Composable
fun freeSub(f: Furniture, en: Boolean): String {
    fun m(v: Int) = uz.metrx.app.geo.fmtLen(v, uz.metrx.app.geo.LenUnit.M, en)
    if (f.kind == "wardrobe") {
        val w = wardOfF(f) ?: return ""
        return listOfNotNull(f.model.takeIf { it.isNotEmpty() }?.let { tr(if (f.type.isNotEmpty()) "ft.$it" else "fz.m.$it") }, m(w.w) + " × " + m(w.h) + " × " + m(w.d) + " m").joinToString(" · ")
    }
    val fs = f.free
    val run = fs?.let { freeRunMm(f.layout, it.sides, it.island) } ?: uz.metrx.app.furniture.runMm(f)
    val t = (max(0, run) + 50) / 100
    return listOfNotNull(tr(if (f.model.isNotEmpty()) "fz.m.${f.model}" else "kt.l${f.layout}"),
        fs?.let { it.sides.joinToString(" + ") + if (it.island > 0) " + " + it.island else "" },
        "${t / 10}${if (en) "." else ","}${t % 10} " + tr("kt.pm")).joinToString(" · ")
}

/** "Xonasiz mebel": the order's pieces without a room, each with its price and "Xonaga qo‘yish". */
@Composable
fun FreeCard(p: Project, lang: Lang) {
    val app = LocalApp.current
    val s = app.settings
    val en = lang == Lang.EN
    val free = p.furniture.filter { it.roomId == null }
    if (free.isEmpty()) return
    val priced = remember(p.furniture, p.fprice, s.workshop, s.mats, s.hws) { priceOf(p.furniture.filter { it.modules.isNotEmpty() }, p.fprice, s.workshop, s.mats, s.hws) }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(64.dp, 52.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .08f)), contentAlignment = Alignment.Center) { MIcon("ruler", G.cobalt, 24.dp, 2f) }
            Column(Modifier.weight(1f)) {
                Text(tr("fz.free"), style = ui(16f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(tr("fz.freeS"), style = ui(12.5f, 400, G.ink2), maxLines = 1)
            }
        }
        free.forEach { f ->
            val ward = f.kind == "wardrobe"
            val amount = priced.lines.firstOrNull { it.key == f.id }?.amount
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable { app.kit.sel = null; app.push(app.designer(p.id, f)) }
                .padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MIcon(if (ward) "board" else "kitchen", G.ink3, 18.dp, 2f)
                Column(Modifier.weight(1f)) {
                    Text(dn(f.name, lang), style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(freeSub(f, en), style = num(12.5f, 500, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
                if (amount != null && amount.signum() > 0) {
                    val (v, u) = shortMoney(p, amount, en, tr("pl.mln"))
                    Text(v + (u?.let { " $it" } ?: ""), style = num(14f, 700))
                }
                MIcon("chev", G.ink3, 16.dp, 2f)
            }
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).dashedGlass(14.dp).clickable(role = Role.Button) { app.sheet = Sheet.FPickRoom(p.id, f.id) }.padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MIcon("plus", G.cobalt2, 18.dp, 2.2f)
                Text(tr("fz.toRoom"), style = ui(14.5f, 700, G.cobalt2))
            }
        }
    }
}

/* ---------------- which room ---------------- */

@Composable
fun FreeSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.FPickRoom -> PickRoomSheet(s)
        else -> return false
    }
    return true
}

@Composable
private fun PickRoomSheet(s: Sheet.FPickRoom) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val snap = app.settings.angleSnap
    val rooms = p.rooms.filter { measuredRoom(it, snap) }
    fun m(v: Int?) = v?.let { uz.metrx.app.geo.fmtLen(it, uz.metrx.app.geo.LenUnit.M, en) } ?: "?"
    GlassSheet(tr("fz.pickT", "n" to dn(f.name, lang)), { app.sheet = null }) {
        if (rooms.isEmpty()) Text(tr("fz.noMeasured"), style = ui(14f, 400, G.ink2, 1.45f))
        rooms.forEach { r ->
            val w = p.floors.firstOrNull { it.id == r.floorId }
            Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .05f))
                .clickable(role = Role.Button) { app.sheet = null; app.push(Route.FPlace(p.id, f.id, r.id)) }.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MIcon(if (w?.type == "kitchen") "kitchen" else "room", G.cobalt, 22.dp, 2f)
                Column(Modifier.weight(1f)) {
                    Text(w?.let { floorName(it, lang) } ?: dn(r.name, lang), style = ui(15.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(m(r.dim("A").v) + " × " + m(r.dim("B").v) + " m · h " + m(r.dim("H").v), style = num(12.5f, 500, G.ink2), maxLines = 1)
                }
                MIcon("chev", G.ink3, 16.dp, 2f)
            }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).dashedGlass(14.dp).clickable(role = Role.Button) { app.sheet = Sheet.FNewRoom(p.id, f.kind, f.id) }.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("plus", G.cobalt2, 18.dp, 2.2f)
            Text(tr("fz.newRoom"), style = ui(15f, 700, G.cobalt2))
        }
    }
}

/* ---------------- into the room ---------------- */

@Composable
fun FPlaceScreen(rt: Route.FPlace) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    val f0 = p.furniture.firstOrNull { it.id == rt.fid } ?: return
    val room = p.rooms.firstOrNull { it.id == rt.rid } ?: return
    val snap = app.settings.angleSnap
    val ws = app.settings.workshop
    val wl = walls(room, snap)
    val ids = wl.map { it.id }
    val taken = p.furniture.filter { it.roomId == room.id && it.id != f0.id }.flatMap { it.walls }
    var first by rememberSaveable { mutableStateOf(ids.firstOrNull { it !in taken } ?: ids.first()) }
    var off by rememberSaveable { mutableStateOf("") }          // a wardrobe's distance from the corner; "" = in the corner
    var keep by rememberSaveable { mutableStateOf(false) }
    var fitted by remember { mutableStateOf<Furniture?>(null) }
    val ward = f0.kind == "wardrobe"
    val offMm = off.filter { it.isDigit() }.toIntOrNull()?.takeIf { it > 0 }
    val f = fitted ?: f0
    val on = placeWalls(f, ids, first)
    val len = { id: String -> wallLen(room, snap, id) }
    val roomH = room.dim("H").v
    val issues = fitIssues(f, on, len, roomH, ws, offMm)
    val floor = p.floors.firstOrNull { it.id == room.floorId }
    val roomName = floor?.let { floorName(it, lang) } ?: dn(room.name, lang)
    fun reset() { fitted = null; keep = false }

    fun place() {
        if (issues.isNotEmpty() && !keep) { app.say("fz.pickFirst", kind = ToastKind.ERROR); return }
        val g = placed(f, on, room.id, room.floorId, offMm, keep = issues.isNotEmpty(), len = len)
        app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == f0.id) g else it }, stage = if (pr.stage == "measure") "design" else pr.stage) }
        app.kit.sel = null; app.kit.tick++
        app.replaceTop(app.designer(p.id, g))
        app.say("fz.placed", "n" to dn(f0.name, lang), "r" to roomName)
    }

    FPage(dn(f0.name, lang) + " → " + roomName, tr("fz.toRoom"), { app.pop() },
        footer = { GBtn(tr("fz.placeHere"), ::place, enabled = issues.isEmpty() || keep) }) {
        PlacePlan(room, f, on, offMm, snap)
        Text(tr(if (ward) "fz.wallQ" else "fz.first"), style = ui(15f, 700))
        androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            wl.forEach { w -> Chip(tr("kt.wallN", "w" to w.id) + (len(w.id)?.let { " · $it" } ?: ""), w.id == first) { if (w.id != first) { first = w.id; reset() } } }
        }
        if (!ward && on.count { it != ISLAND } > 1) Text(tr("fz.nextWalls", "w" to on.drop(1).filter { it != ISLAND }.joinToString(", ")), style = ui(13f, 400, G.ink2, 1.4f))
        if (on.any { it in taken }) Text(tr("kt.wallTaken", "w" to on.first { it in taken }, "n" to dn(p.furniture.first { it.roomId == room.id && it.id != f0.id && on.any { w -> w in it.walls } }.name, lang)),
            style = ui(12.5f, 500, G.amberInk, 1.4f))
        if (ward) {
            Text(tr("fz.offset"), style = ui(15f, 700))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Chip(tr("fz.corner"), offMm == null) { off = ""; reset() }
                GField(null, off, { off = it.filter { c -> c.isDigit() }.take(5); reset() }, "0", number = true, labelRight = "mm", imeAction = ImeAction.Done, modifier = Modifier.weight(1f))
            }
        }
        if (issues.isNotEmpty()) {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(if (keep) G.amberWash else G.errWash).padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    MIcon("alert", if (keep) G.amberInk else G.err, 18.dp, 2f)
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        issues.forEach { i -> Text(app.t(i.key, *i.vars.map { (k, v) -> k to (if (k == "n") dn(v.toString(), lang) else v) }.toTypedArray()), style = ui(13.5f, 600, if (keep) G.amberInk else G.err, 1.35f)) }
                    }
                }
                if (keep) Text(tr("fz.kept"), style = ui(12.5f, 500, G.amberInk, 1.35f))
            }
            val heightOnly = issues.all { it.key == "fz.high" }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GBtn(tr(if (heightOnly) "fz.fitH" else "fz.fit"), {
                    fitted = fitTo(placed(f, on, room.id, room.floorId, offMm), on, len, roomH, ws, offMm); keep = false; app.say("fz.fitted")
                }, Btn.SECONDARY, height = 46.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
                GBtn(tr("fz.keep"), { keep = true }, if (keep) Btn.PRIMARY else Btn.SECONDARY, height = 46.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
            }
        }
    }
}

/** The room from above with the piece's place: each side along its wall (red past the wall's end), the wardrobe at its distance. */
@Composable
private fun PlacePlan(room: uz.metrx.app.data.Room, f: Furniture, on: List<String>, off: Int?, snap: Boolean) {
    val tm = rememberTextMeasurer()
    val wl = walls(room, snap)
    val runs = runsOf(f) { null }
    Canvas(Modifier.fillMaxWidth().aspectRatio(1.5f).clip(RoundedCornerShape(18.dp)).background(G.glass(.6f)).border(1.dp, G.rim, RoundedCornerShape(18.dp))) {
        val xs = wl.flatMap { listOf(it.p0.x, it.p1.x) }; val ys = wl.flatMap { listOf(it.p0.y, it.p1.y) }
        val x0 = xs.min(); val y0 = ys.min(); val spanX = (xs.max() - x0).coerceAtLeast(1.0); val spanY = (ys.max() - y0).coerceAtLeast(1.0)
        val pad = 34f
        val k = min((size.width - 2 * pad) / spanX, (size.height - 2 * pad) / spanY).toFloat()
        val ox = (size.width - spanX.toFloat() * k) / 2f; val oy = (size.height - spanY.toFloat() * k) / 2f
        fun P(x: Double, y: Double) = Offset(ox + ((x - x0) * k).toFloat(), oy + ((y - y0) * k).toFloat())
        val path = Path().apply { wl.forEachIndexed { i, w -> val a = P(w.p0.x, w.p0.y); if (i == 0) moveTo(a.x, a.y) else lineTo(a.x, a.y) }; close() }
        drawPath(path, Color(0xFFF3F6FB))
        drawPath(path, Color(0xFF0F172A), style = Stroke(5f))
        val style = TextStyle(fontSize = 12.sp, color = Color(0xFF475569))
        wl.forEach { w ->
            val dx = w.p1.x - w.p0.x; val dy = w.p1.y - w.p0.y; val l = kotlin.math.hypot(dx, dy).coerceAtLeast(1.0)
            val ux = dx / l; val uy = dy / l; val nx = -uy; val ny = ux              // into the room
            val mid = P(w.p0.x + dx / 2, w.p0.y + dy / 2)
            val lab = tm.measure(w.id, style)
            val lp = Offset(mid.x - (nx * 20).toFloat() - lab.size.width / 2f, mid.y - (ny * 20).toFloat() - lab.size.height / 2f)
            drawText(lab, topLeft = lp)
            // the piece along this wall
            fun bar(a: Double, b: Double, depth: Double, over: Boolean) {
                val q = listOf(P(w.p0.x + ux * a, w.p0.y + uy * a), P(w.p0.x + ux * b, w.p0.y + uy * b),
                    P(w.p0.x + ux * b + nx * depth, w.p0.y + uy * b + ny * depth), P(w.p0.x + ux * a + nx * depth, w.p0.y + uy * a + ny * depth))
                val pp = Path().apply { moveTo(q[0].x, q[0].y); q.drop(1).forEach { lineTo(it.x, it.y) }; close() }
                val c = if (over) Color(0xFFDC2626) else Color(0xFF3550E0)
                drawPath(pp, c.copy(alpha = .22f)); drawPath(pp, c, style = Stroke(2f))
            }
            val i = on.indexOf(w.id)
            if (i >= 0) {
                if (f.kind == "wardrobe") {
                    val m = wardOfF(f) ?: return@forEach
                    val a = (off ?: uz.metrx.app.furniture.W_GAP_SIDE).toDouble()
                    bar(a, a + m.w, m.d.toDouble(), a + m.w > l + 1)
                } else {
                    val r = runs.getOrNull(i) ?: return@forEach
                    val need = f.free?.sides?.getOrNull(i)?.takeIf { f.roomId == null }?.let { max(it, runEnd(f, r)) } ?: runEnd(f, r)
                    // a corner kitchen's first side ends in the corner
                    val a = if (i == 0 && on.count { it != ISLAND } > 1) max(0.0, l - need) else 0.0
                    bar(a, a + need, 600.0, need > l + 1)
                }
            }
        }
        // the island or peninsula, 900 out in front of the first side
        if (ISLAND in on && f.kind == "kitchen") {
            val w = wl.firstOrNull { it.id == on[0] }
            val isl = f.modules.filter { it.wall == ISLAND && !uz.metrx.app.furniture.isUpper(it) }.sumOf { it.w }
            if (w != null && isl > 0) {
                val dx = w.p1.x - w.p0.x; val dy = w.p1.y - w.p0.y; val l = kotlin.math.hypot(dx, dy).coerceAtLeast(1.0)
                val ux = dx / l; val uy = dy / l; val nx = -uy; val ny = ux
                val a = (l - isl) / 2; val b = a + isl; val d0 = 1500.0; val d1 = 2100.0
                val q = listOf(P(w.p0.x + ux * a + nx * d0, w.p0.y + uy * a + ny * d0), P(w.p0.x + ux * b + nx * d0, w.p0.y + uy * b + ny * d0),
                    P(w.p0.x + ux * b + nx * d1, w.p0.y + uy * b + ny * d1), P(w.p0.x + ux * a + nx * d1, w.p0.y + uy * a + ny * d1))
                val pp = Path().apply { moveTo(q[0].x, q[0].y); q.drop(1).forEach { lineTo(it.x, it.y) }; close() }
                drawPath(pp, Color(0xFF3550E0).copy(alpha = .22f)); drawPath(pp, Color(0xFF3550E0), style = Stroke(2f))
            }
        }
    }
}
