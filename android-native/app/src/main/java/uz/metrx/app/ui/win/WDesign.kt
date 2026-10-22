package uz.metrx.app.ui.win

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.data.dn
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.elec.Stepper
import uz.metrx.app.ui.elec.rgbC
import uz.metrx.app.ui.furniture.Chip
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.win.COLOURS
import uz.metrx.app.win.GAP_MAX
import uz.metrx.app.win.GAP_MIN
import uz.metrx.app.win.GLASSES
import uz.metrx.app.win.PROFILES
import uz.metrx.app.win.SASH_TYPES
import uz.metrx.app.win.SILL_OVER_MAX
import uz.metrx.app.win.WBar
import uz.metrx.app.win.WinItem
import uz.metrx.app.win.barsOf
import uz.metrx.app.win.chambersOf
import uz.metrx.app.win.colourRgb
import uz.metrx.app.win.countItems
import uz.metrx.app.win.ctxOf
import uz.metrx.app.win.freeCtx
import uz.metrx.app.win.frameDepth
import uz.metrx.app.win.itemCost
import uz.metrx.app.win.mergeAt
import uz.metrx.app.win.moveMullion
import uz.metrx.app.win.moveTransom
import uz.metrx.app.win.placed
import uz.metrx.app.win.refit
import uz.metrx.app.win.resized
import uz.metrx.app.win.revealOf
import uz.metrx.app.win.sashesOf
import uz.metrx.app.win.setCell
import uz.metrx.app.win.setColW
import uz.metrx.app.win.setRowH
import uz.metrx.app.win.sillFor
import uz.metrx.app.win.sizeFor
import uz.metrx.app.win.splitCol
import uz.metrx.app.win.splitRow
import kotlin.math.abs

/*
 * A product's designer (22 Oct 2026): its drawing from inside, a sash tapped to choose it and the mullions dragged to
 * move them (or their positions typed); each sash's way of opening and hinge side; its size (from its opening less the
 * gap, or typed); the profile, glass and colours; the extras; a door's hinge side and swing. The same product in a piece
 * of wall in 3D, and in its room. Every change is saved at once.
 */

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun WDesignScreen(rt: Route.WDesign) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    val it0 = p.win.item(rt.iid) ?: return
    val snap = app.settings.angleSnap
    LaunchedEffect(p.rooms) { app.refitWin(p.id) }
    val c = remember(p.rooms, it0) { if (it0.inRoom) ctxOf(p, it0.roomId!!, snap) else freeCtx(it0) }
    val pl = remember(c, it0) { c?.let { placed(it, it0) } }
    val T = c?.T ?: it0.freeT
    val R = revealOf(T, frameDepth(it0))
    val floor = pl?.doorOpening ?: (it0.isDoor || it0.kind == "balc")
    val calc = rememberWCalc(p)
    val warns = calc.warns.filter { it.target == it0.id }
    var mode by rememberSaveable(rt) { mutableStateOf("draw") }
    var selC by rememberSaveable(rt) { mutableIntStateOf(0) }
    var selR by rememberSaveable(rt) { mutableIntStateOf(0) }
    if (selC >= it0.cols.size) selC = 0
    if (selR >= (it0.cols.getOrNull(selC)?.rows?.size ?: 1)) selR = 0
    var drag by remember { mutableStateOf<WinItem?>(null) }
    val shown = drag ?: it0
    fun upd(f: (WinItem) -> WinItem) = app.updateItem(p.id, it0.id, f)
    val where = if (it0.inRoom) roomName(p, it0.roomId) + (pl?.let { " · " + openingName(c!!.room, it.o) } ?: "") else tr("dw.noRoom")
    BoxWithConstraints(Modifier.fillMaxSize().imePadding()) {
        val viewH = maxHeight * .42f
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(itemTitle(it0), eyebrow = where)
                GlassIconButton("cube", tr("dw.inRoom"), { app.push(Route.WView(p.id, if (it0.inRoom) it0.roomId!! else "free:" + it0.id)) })
            }
            Box(Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 6.dp)) {
                Seg(listOf("draw" to tr("dw.draw"), "3d" to "3D"), mode) { mode = it }
            }
            Box(Modifier.fillMaxWidth().height(viewH).padding(horizontal = 16.dp).clip(RoundedCornerShape(22.dp)).background(Color(0xFFF6F8FC)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                if (mode == "3d") {
                    var az by remember { mutableFloatStateOf(0f) }
                    Canvas(Modifier.fillMaxSize().pointerInput(Unit) { detectHorizontalDragGestures { ch, dx -> ch.consume(); az = (az - dx / 400f).coerceIn(-1.1f, .7f) } }) {
                        drawProductPic(PicSpec(shown, T, floor), az)
                    }
                    Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                } else Elevation(shown, if (shown.isDoor) null else selC to selR, warns.isNotEmpty(),
                    onPick = { ci, ri -> selC = ci; selR = ri },
                    onDrag = { drag = it }, onDrop = { d -> drag = null; if (d != null) upd { d } })
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (warns.isNotEmpty()) Warnings(p, warns, open = false)
                if (!it0.isDoor) SashCard(it0, selC, selR, { ci, ri -> selC = ci; selR = ri }, ::upd)
                SizeCard(p.id, it0, if (it0.inRoom) pl?.o else null, selC)
                if (it0.isDoor) DoorCard(it0, ::upd) else ProfileCard(it0, ::upd)
                if (!it0.isDoor) ExtrasCard(it0, R, floor, ::upd)
                if (app.settings.advanced) WCountCard(tr("dw.itemCount"), countItems(listOf(it0 to R)), itemCost(it0, R, app.settings.trade.win))
                GBtn(tr("dw.inRoom"), { app.push(Route.WView(p.id, if (it0.inRoom) it0.roomId!! else "free:" + it0.id)) }, Btn.SECONDARY, icon = "cube", height = 46.dp, fontSize = 14.5f)
                GBtn(tr("common.delete"), {
                    val before = app.store.get(p.id) ?: return@GBtn
                    app.updateWin(p.id) { e -> e.copy(items = e.items.filter { it.id != it0.id }) }
                    app.pop()
                    app.say("dw.deleted", action = "common.undo", onAction = { app.store.update(p.id) { before } })
                }, Btn.DANGER, icon = "trash", height = 46.dp, fontSize = 14.5f)
            }
        }
    }
}

/** The drawing: a tap picks a sash, a mullion or transom is dragged along. */
@Composable
private fun Elevation(it: WinItem, sel: Pair<Int, Int>?, bad: Boolean, onPick: (Int, Int) -> Unit, onDrag: (WinItem?) -> Unit, onDrop: (WinItem?) -> Unit) {
    val dens = LocalDensity.current.density
    val tm = rememberTextMeasurer()
    val big = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color(0xFF334155))
    val small = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Medium, color = Color(0xFF475569))
    val cur by rememberUpdatedState(it)
    fun map(w: Float, h: Float) = ElevMap(cur.w.toDouble(), cur.h.toDouble(), Rect(0f, 0f, w, h), 30 * dens, 36 * dens, 12 * dens)
    Box(Modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize().semantics { contentDescription = "drawing" }.pointerInput(Unit) {
            detectTapGestures { pos ->
                val m = map(size.width.toFloat(), size.height.toFloat())
                val q = m.back(pos)
                sashesOf(cur).firstOrNull { s -> q.x in s.r.x0..s.r.x1 && q.y in s.r.y0..s.r.y1 }?.let { s -> onPick(s.col, s.row) }
            }
        }.pointerInput(Unit) {
            var grab: WBar? = null; var start: WinItem? = null; var at = androidx.compose.ui.geometry.Offset.Zero
            detectDragGestures(onDragStart = { pos ->
                val m = map(size.width.toFloat(), size.height.toFloat())
                val q = m.back(pos); val reach = 22 * dens / m.k
                grab = barsOf(cur).filter { b ->
                    if (b.vertical) abs(q.x - b.x0) < reach && q.y in b.y0..b.y1 else abs(q.y - b.y0) < reach && q.x in b.x0..b.x1
                }.minByOrNull { b -> if (b.vertical) abs(q.x - b.x0) else abs(q.y - b.y0) }
                start = cur; at = pos
            }, onDragEnd = { onDrop(if (grab != null) cur else null); grab = null }, onDragCancel = { onDrop(null); grab = null }) { ch, dd ->
                val b = grab ?: return@detectDragGestures
                val s0 = start ?: return@detectDragGestures
                ch.consume(); at += dd
                val m = map(size.width.toFloat(), size.height.toFloat())
                val q = m.back(at)
                val snap5 = { v: Double -> (Math.round(v / 5.0) * 5).toInt() }
                onDrag(if (b.vertical) moveMullion(s0, b.col, snap5(q.x)) else moveTransom(s0, b.col, b.row, snap5(s0.h - q.y)))
            }
        }) {
            val m = map(size.width, size.height)
            drawElevation(it, m, sel, bad, { s -> tm.measure(s, big) }, { s -> tm.measure(s, small) }, 1.6f)
        }
        Text(tr(if (it.isDoor) "dw.drawDoor" else "dw.drawHint"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomStart).padding(start = 10.dp, bottom = 4.dp))
    }
}

@Composable
private fun CardBox(title: String, sub: String? = null, body: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = ui(15f, 800), modifier = Modifier.weight(1f))
            if (sub != null) Text(sub, style = ui(12.5f, 500, G.ink2))
        }
        body()
    }
}

@Composable
private fun SwitchLine(title: String, sub: String?, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 54.dp).clip(RoundedCornerShape(14.dp)).background(G.glass(.7f)).clickable(role = Role.Switch, onClick = onClick)
        .padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(14.5f, 700))
            if (sub != null) Text(sub, style = ui(12f, 400, G.ink2, 1.3f))
        }
        GSwitch(on)
    }
}

/** The chosen sash: how it opens, its hinge side; a mullion or transom added or taken away. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SashCard(it: WinItem, ci: Int, ri: Int, onSel: (Int, Int) -> Unit, upd: ((WinItem) -> WinItem) -> Unit) {
    val ss = sashesOf(it)
    val idx = ss.indexOfFirst { s -> s.col == ci && s.row == ri }.coerceAtLeast(0)
    val s = ss.getOrNull(idx) ?: return
    CardBox(tr("dw.sashN", "n" to idx + 1), "${Math.round(s.r.w)} × ${Math.round(s.r.h)}") {
        if (ss.size > 1) Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ss.forEachIndexed { i, x -> Chip("${i + 1}", i == idx) { onSel(x.col, x.row) } }
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SASH_TYPES.forEach { t -> Chip(tr("dw.t.$t"), s.t == t) { upd { w -> setCell(w, ci, ri) { c -> c.copy(t = t) } } } }
        }
        if (s.t == "turn" || s.t == "tt" || s.t == "slide") FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("L", "R").forEach { h -> Chip(tr(if (s.t == "slide") "dw.slide$h" else "dw.hinge$h"), s.cell.hinge == h) { upd { w -> setCell(w, ci, ri) { c -> c.copy(hinge = h) } } } }
        }
        Text(tr("dw.tS.${s.t}"), style = ui(12.5f, 400, G.ink2, 1.35f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("dw.addV"), { upd { w -> splitCol(w, ci) } }, Btn.SECONDARY, height = 42.dp, corner = 14.dp, fontSize = 13.5f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("dw.addH"), { upd { w -> splitRow(w, ci, ri) } }, Btn.SECONDARY, height = 42.dp, corner = 14.dp, fontSize = 13.5f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("dw.merge"), { upd { w -> mergeAt(w, ci, ri) }; onSel(0, 0) }, Btn.SECONDARY, enabled = ss.size > 1, height = 42.dp, corner = 14.dp, fontSize = 13.5f, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }
}

/** The size: from the opening less the gap (or typed by hand), a product without a room's count and name, the mullions' and transoms' places. */
@Composable
private fun SizeCard(pid: String, it: WinItem, o: uz.metrx.app.data.Opening?, ci: Int) {
    val app = LocalApp.current
    val mm = tr("dw.mm")
    val key = it.hashCode()
    var tw by rememberSaveable(key) { mutableStateOf("${it.w}") }
    var th by rememberSaveable(key) { mutableStateOf("${it.h}") }
    var tg by rememberSaveable(key) { mutableStateOf("${it.gap}") }
    var tName by rememberSaveable(key) { mutableStateOf(it.name) }
    var tT by rememberSaveable(key) { mutableStateOf("${it.freeT}") }
    var cols by rememberSaveable(key) { mutableStateOf(it.cols.map { c -> "${c.w}" }) }
    var rows by rememberSaveable(key, ci) { mutableStateOf<List<String>>(it.cols.getOrNull(ci)?.rows?.map { r -> "${r.h}" } ?: emptyList()) }
    val W = tw.toIntOrNull(); val H = th.toIntOrNull(); val g = tg.toIntOrNull()
    val ok = W != null && H != null && W in 300..8000 && H in 300..4000 && (g == null || g in GAP_MIN..GAP_MAX)
    fun apply() {
        if (!ok) return
        app.updateItem(pid, it.id) { x ->
            var y = x
            if (o != null && g != null && g != x.gap) { y = y.copy(gap = g); if (y.fit) y = refit(y, o.w, o.h, o.type) }
            if (W != y.w || H != y.h) y = resized(y, W!!, H!!).copy(fit = o == null || (W to H) == sizeFor(o.w, o.h, o.type, y.gap))
            if (!x.inRoom) y = y.copy(name = tName.trim(), freeT = (tT.toIntOrNull() ?: x.freeT).coerceIn(80, 800))
            cols.dropLast(1).forEachIndexed { i, s -> s.toIntOrNull()?.let { v -> if (v != y.cols.getOrNull(i)?.w) y = setColW(y, i, v) } }
            rows.dropLast(1).forEachIndexed { j, s -> s.toIntOrNull()?.let { v -> if (v != y.cols.getOrNull(ci)?.rows?.getOrNull(j)?.h) y = setRowH(y, ci, j, v) } }
            y
        }
        app.say("common.save")
    }
    CardBox(tr("dw.size"), sizeText(it.w, it.h)) {
        if (o != null) {
            Text(tr("dw.fromOp", "s" to sizeText(o.w, o.h)) + if (it.fit) "" else " · " + tr("dw.byHand"), style = ui(12.5f, 400, G.ink2, 1.35f))
            GField(tr("dw.gapEach"), tg, { v -> tg = v.filter { ch -> ch.isDigit() }.take(2) }, "20", number = true, labelRight = mm)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GField(tr("tl.pbW"), tw, { v -> tw = v.filter { ch -> ch.isDigit() }.take(4) }, "1300", number = true, labelRight = mm, modifier = Modifier.weight(1f))
            GField(tr("tl.pbH"), th, { v -> th = v.filter { ch -> ch.isDigit() }.take(4) }, "1400", number = true, labelRight = mm, modifier = Modifier.weight(1f))
        }
        if (it.cols.size > 1) {
            Text(tr("dw.colsT"), style = ui(13.5f, 700))
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                cols.forEachIndexed { i, s ->
                    GField(tr("dw.colN", "n" to i + 1), s, { v -> cols = cols.toMutableList().also { l -> l[i] = v.filter { ch -> ch.isDigit() }.take(4) } }, "650", number = true,
                        modifier = Modifier.width(96.dp))
                }
            }
        }
        if (rows.size > 1) {
            Text(tr("dw.rowsT", "n" to ci + 1), style = ui(13.5f, 700))
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                rows.forEachIndexed { j, s ->
                    GField(tr("dw.rowN", "n" to j + 1), s, { v -> rows = rows.toMutableList().also { l -> l[j] = v.filter { ch -> ch.isDigit() }.take(4) } }, "450", number = true,
                        modifier = Modifier.width(96.dp))
                }
            }
        }
        if (it.cols.size > 1 || rows.size > 1) Text(tr("dw.lastTakes"), style = ui(12f, 400, G.ink3, 1.3f))
        if (!it.inRoom) {
            GField(tr("fr.name"), tName, { tName = it }, tr("dw.k.${it.kind}"), optional = true)
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("dw.qty"), style = ui(15f, 600), modifier = Modifier.weight(1f))
                Stepper(it.qty) { v -> app.updateItem(pid, it.id) { x -> x.copy(qty = v.coerceIn(1, 99)) } }
            }
            GField(tr("dw.wallT"), tT, { v -> tT = v.filter { ch -> ch.isDigit() }.take(3) }, "300", number = true, labelRight = mm)
        }
        if (!ok) Text(tr("dw.sizeErr"), style = ui(13f, 500, G.err))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("dw.apply"), ::apply, enabled = ok, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            if (o != null && !it.fit) GBtn(tr("dw.refit"), { app.updateItem(pid, it.id) { x -> refit(x, o.w, o.h, o.type).copy(fit = true) } }, Btn.SECONDARY,
                height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }
}

/** Colour swatches: [cur] ringed. */
@Composable
private fun Swatches(cur: String, onPick: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        COLOURS.forEach { c ->
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.widthIn(min = 52.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.RadioButton) { onPick(c) }.padding(4.dp)) {
                Box(Modifier.size(34.dp).clip(CircleShape).background(rgbC(colourRgb(c))).border(if (c == cur) 3.dp else 1.dp, if (c == cur) G.cobalt else G.rim, CircleShape))
                Text(tr("dw.col.$c"), style = ui(11f, if (c == cur) 700 else 500, if (c == cur) G.cobalt2 else G.ink2), maxLines = 1)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProfileCard(it: WinItem, upd: ((WinItem) -> WinItem) -> Unit) {
    CardBox(tr("dw.profile"), tr("dw.p.${it.profile}") + " · " + tr("dw.chN", "n" to it.chambers)) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            PROFILES.forEach { pr -> Chip(tr("dw.p.$pr"), it.profile == pr) { upd { x -> if (x.profile == pr) x else x.copy(profile = pr, chambers = if (pr == "alu") 3 else 5) } } }
        }
        Text(tr("dw.chambers"), style = ui(13.5f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            chambersOf(it.profile).forEach { n -> Chip(if (it.profile == "alu") tr(if (n >= 3) "dw.alu.warm" else "dw.alu.cold") else tr("dw.chN", "n" to n), it.chambers == n) { upd { x -> x.copy(chambers = n) } } }
        }
        Text(tr("dw.glass"), style = ui(13.5f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            GLASSES.forEach { n -> Chip(tr("dw.g.$n"), it.glass == n) { upd { x -> x.copy(glass = n) } } }
        }
        Text(tr("dw.colIn"), style = ui(13.5f, 700))
        Swatches(it.colIn) { c -> upd { x -> x.copy(colIn = c) } }
        Text(tr("dw.colOut"), style = ui(13.5f, 700))
        Swatches(it.colOut) { c -> upd { x -> x.copy(colOut = c) } }
        Text(tr("dw.lamS"), style = ui(12f, 400, G.ink3, 1.3f))
    }
}

/** The extras: the sill and its depth against the reveal, the drip, the reveals, nets and handles. */
@Composable
private fun ExtrasCard(it: WinItem, r: Int, floor: Boolean, upd: ((WinItem) -> WinItem) -> Unit) {
    val app = LocalApp.current
    val mm = tr("dw.mm")
    var ts by rememberSaveable(it.sill) { mutableStateOf(if (it.sill > 0) "${it.sill}" else "${sillFor(r)}") }
    CardBox(tr("dw.extras")) {
        if (!floor) {
            SwitchLine(tr("dw.x.sill"), tr("dw.x.sillS", "r" to r), it.sill > 0) { upd { x -> x.copy(sill = if (x.sill > 0) 0 else sillFor(r)) } }
            if (it.sill > 0) Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GField(tr("dw.x.sillD"), ts, { v -> ts = v.filter { ch -> ch.isDigit() }.take(3) }, "250", number = true, labelRight = mm, modifier = Modifier.weight(1f),
                    imeAction = androidx.compose.ui.text.input.ImeAction.Done, onIme = { ts.toIntOrNull()?.takeIf { v -> v in 50..800 }?.let { v -> upd { x -> x.copy(sill = v) }; app.say("common.save") } })
                GBtn(tr("dw.apply"), { ts.toIntOrNull()?.takeIf { v -> v in 50..800 }?.let { v -> upd { x -> x.copy(sill = v) }; app.say("common.save") } }, Btn.SECONDARY,
                    height = 52.dp, corner = 14.dp, fontSize = 14f, fill = false)
            }
            if (it.sill > 0 && it.sill > r + SILL_OVER_MAX) Text(tr("dw.x.sillWarn", "m" to (it.sill - r)), style = ui(12.5f, 500, G.amberInk, 1.35f))
            SwitchLine(tr("dw.x.drip"), tr("dw.x.dripS"), it.drip) { upd { x -> x.copy(drip = !x.drip) } }
        }
        SwitchLine(tr("dw.x.reveals"), tr("dw.x.revealsS", "r" to r), it.reveals) { upd { x -> x.copy(reveals = !x.reveals) } }
        SwitchLine(tr("dw.x.net"), tr("dw.x.netS"), it.net) { upd { x -> x.copy(net = !x.net) } }
        SwitchLine(tr("dw.x.handles"), tr("dw.x.handlesS"), it.handles) { upd { x -> x.copy(handles = !x.handles) } }
    }
}

/** A door: its hinge side, which way it opens (a sliding one: which way it slides), its colour, the handle. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DoorCard(it: WinItem, upd: ((WinItem) -> WinItem) -> Unit) {
    CardBox(tr("dw.door")) {
        Text(tr(if (it.kind == "dsl") "dw.slideT" else "dw.hingeT"), style = ui(13.5f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("L", "R").forEach { h -> Chip(tr(if (it.kind == "dsl") "dw.slide$h" else "dw.hinge$h"), it.hinge == h) { upd { x -> x.copy(hinge = h) } } }
        }
        if (it.kind != "dsl") {
            Text(tr("dw.swingT"), style = ui(13.5f, 700))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("in", "out").forEach { s -> Chip(tr("dw.swing.$s"), it.swing == s) { upd { x -> x.copy(swing = s) } } }
            }
        }
        Text(tr("dw.colDoor"), style = ui(13.5f, 700))
        Swatches(it.colIn) { c -> upd { x -> x.copy(colIn = c, colOut = c) } }
        SwitchLine(tr("dw.x.handles"), null, it.handles) { upd { x -> x.copy(handles = !x.handles) } }
        Text(tr("dw.doorS"), style = ui(12f, 400, G.ink3, 1.3f))
    }
}
