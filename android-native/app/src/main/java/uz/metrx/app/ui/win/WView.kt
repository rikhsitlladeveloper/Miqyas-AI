package uz.metrx.app.ui.win

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.View3D
import uz.metrx.app.data.ViewFiles
import uz.metrx.app.data.dn
import uz.metrx.app.data.uid
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.editor.ShotPill
import uz.metrx.app.ui.elec.PlanMap
import uz.metrx.app.ui.furniture.openRoom
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.three.Cam3D
import uz.metrx.app.ui.three.Labels3D
import uz.metrx.app.ui.three.Lbl3D
import uz.metrx.app.ui.three.Scene3D
import uz.metrx.app.ui.three.Shot3D
import uz.metrx.app.win.WCtx
import uz.metrx.app.win.WWarn
import uz.metrx.app.win.countItems
import uz.metrx.app.win.ctxOf
import uz.metrx.app.win.frameDepth
import uz.metrx.app.win.itemCost
import uz.metrx.app.win.itemsIn
import uz.metrx.app.win.obstaclesIn
import uz.metrx.app.win.placedIn
import uz.metrx.app.win.revealOf
import uz.metrx.app.win.sashSweeps
import uz.metrx.app.win.winParts

/*
 * A room's windows and doors: the room in 3D with each product fitted in its opening (frame, sashes, glass, handles, the
 * sill and the drip), or from above with where the sashes and leaves sweep and what stands in their way. Under it the
 * warnings, the room's openings each with its product (or a button to fill it), and in the advanced app what they take.
 */

/** The room with its products in 3D, worked out away from the screen's thread; the filled openings get no standard window. */
@Composable
fun rememberWinShell(p: Project, r: Room, snap: Boolean): Shell3D {
    val filled = remember(p.win, r.id) { p.win.items.filter { it.roomId == r.id && it.inRoom }.mapNotNull { it.opening }.toSet() }
    val base = remember(r, snap, filled) { buildShell(listOf(r), true, snap, bare = filled) }
    val shell by produceState(base, base, p.win, p.rooms) {
        value = withContext(Dispatchers.Default) { runCatching { winShell(p, r, base, snap) }.getOrDefault(base) }
    }
    return shell
}

private fun winShell(p: Project, r: Room, base: Shell3D, snap: Boolean): Shell3D {
    val c = ctxOf(p, r.id, snap) ?: return base
    val w0 = walls(r, snap).firstOrNull() ?: return base
    val b = base.bases[w0.id] ?: return base
    val dx = b.ox - w0.p0.x / 1000; val dz = b.oz - w0.p0.y / 1000
    return base.plus(winParts(c, placedIn(p, c), dx, dz), emptyList())
}

/** A warning's words: its values read in the language ("~key" a strings key, decimals with a comma). */
@Composable
fun warnText(w: WWarn): String {
    val en = LocalLang.current == Lang.EN
    val vars = w.vars.map { (k, v) ->
        val s = v.toString()
        k to (if (s.startsWith("~")) tr(s.drop(1)) else if (!en) s.replace('.', ',') else s)
    }.toTypedArray()
    return tr(w.key, *vars)
}

@Composable
fun WViewScreen(rt: Route.WView) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    val snap = app.settings.angleSnap
    val free = rt.rid.startsWith("free:")
    LaunchedEffect(p.rooms) { app.refitWin(p.id) }
    val calc = rememberWCalc(p)
    val c = calc.ctxs.firstOrNull { it.id == rt.rid }
    val room = if (free) null else p.rooms.firstOrNull { it.id == rt.rid }
    val title = c?.free?.let { itemTitle(it) } ?: roomName(p, rt.rid)
    var mode by rememberSaveable(rt) { mutableStateOf("3d") }
    val warns = calc.warns.filter { it.roomId == rt.rid }
    val bad = warns.mapNotNull { it.target }.toSet()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val viewH = maxHeight * .46f
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(title, eyebrow = dn(p.name, lang))
                if (room != null) GlassIconButton("edit", tr("common.edit"), { app.openRoom(p.id, room.id) })
            }
            if (c == null) {
                Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(tr("dw.needMeasure"), style = ui(16f, 700, G.ink, 1.35f), textAlign = TextAlign.Center)
                    if (room != null) GBtn(tr("ns.measureB"), { app.openRoom(p.id, room.id) }, fill = false)
                }
                return@Column
            }
            Box(Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 6.dp)) {
                Seg(listOf("3d" to "3D", "plan" to tr("ed.plan")), mode) { mode = it }
            }
            Box(Modifier.fillMaxWidth().height(viewH)) {
                if (mode == "plan") PlanView(p, c, bad) else Room3D(p, c, room, snap)
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (warns.isNotEmpty()) Warnings(p, warns)
                Openings(p, c, bad)
                if (!free) Row(Modifier.fillMaxWidth().height(54.dp).dashedGlass(20.dp).pressable({ app.push(Route.WGallery(p.id, c.id)) }, .98f),
                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                    MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("dw.addItem"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
                }
                if (app.settings.advanced) {
                    val list = itemsIn(p, c).map { it to revealOf(c.tOf(c.opening(it.opening)?.wall), frameDepth(it)) }
                    if (list.isNotEmpty()) WCountCard(tr("dw.roomCount"), countItems(list), list.sumOf { (it, r) -> itemCost(it, r, app.settings.trade.win) })
                }
            }
        }
    }
}

@Composable
private fun Room3D(p: Project, c: WCtx, room: Room?, snap: Boolean) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val r = room ?: c.room
    val shell = rememberWinShell(p, r, snap)
    val cam = remember(r.id) { Cam3D() }
    val shot = remember { Shot3D() }
    var taking by remember { mutableStateOf(false) }
    Scene3D(shell, cam, Modifier.fillMaxSize(), shot) {
        Labels3D(cam, shell.labels.map { it.p }) { i -> Lbl3D(shell.labels[i].text) }
        if (room != null) ShotPill("camera", tr("3d.save"), Modifier.align(Alignment.TopEnd).padding(top = 10.dp, end = 10.dp)) {
            fun full() = (app.store.get(p.id)?.rooms?.firstOrNull { it.id == r.id }?.views?.size ?: 4) >= 4
            if (taking) return@ShotPill
            // a double tap takes one picture, not two alike
            if (!app.once()) return@ShotPill
            if (full()) { app.say("3d.max", kind = ToastKind.ERROR); return@ShotPill }
            taking = true
            shot.take { bmp ->
                taking = false
                if (full()) { app.say("3d.max", kind = ToastKind.ERROR); return@take }
                val id = uid()
                val img = bmp?.let { ViewFiles.save(ctx, id, it) }
                if (img == null) app.say("3d.fail", kind = ToastKind.ERROR)
                else {
                    app.store.update(p.id) { pp -> pp.copy(rooms = pp.rooms.map { if (it.id == r.id && it.views.size < 4) it.copy(views = it.views + View3D(id, img, System.currentTimeMillis())) else it }) }
                    app.say("3d.saved")
                }
            }
        }
        Row(Modifier.align(Alignment.BottomStart).padding(10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("3d.top" to true, "3d.corner" to false).forEach { (k, top) ->
                Text(tr(k), style = ui(13f, 700), maxLines = 1, modifier = Modifier.clip(RoundedCornerShape(14.dp)).background(G.sheet(.7f))
                    .clickable(role = Role.Button) { cam.preset(top) }.padding(horizontal = 12.dp, vertical = 9.dp))
            }
        }
    }
}

/** The room from above: a tap on a product opens it. */
@Composable
private fun PlanView(p: Project, c: WCtx, bad: Set<String>) {
    val app = LocalApp.current
    val snap = app.settings.angleSnap
    val dens = androidx.compose.ui.platform.LocalDensity.current.density
    val pls = remember(p.win, c) { placedIn(p, c) }
    val obs = remember(p.plumb, p.furniture, c) { obstaclesIn(p, c, snap) }
    val sweeps = remember(pls) { pls.flatMap { sashSweeps(it) } }
    val cur by rememberUpdatedState(pls)
    Box(Modifier.fillMaxSize().background(Color(0xFFF6F8FC))) {
        Canvas(Modifier.fillMaxSize().pointerInput(c.id) {
            detectTapGestures { pos ->
                val m = PlanMap(c.g.floor, Rect(0f, 0f, size.width.toFloat(), size.height.toFloat()), 26 * dens)
                val hit = cur.minByOrNull { pl -> (m.at(pl.w.at(pl.a0 + pl.it.w / 2.0, -pl.r.toDouble())) - pos).getDistance() }
                if (hit != null && (m.at(hit.w.at(hit.a0 + hit.it.w / 2.0, -hit.r.toDouble())) - pos).getDistance() < 40 * dens) app.push(Route.WDesign(p.id, hit.it.id))
            }
        }) {
            drawWinPlan(c, PlanMap(c.g.floor, Rect(0f, 0f, size.width, size.height), 26 * dens), pls, sweeps, obs, 9 * dens, bad = bad)
        }
        Text(tr("dw.planHint"), style = ui(11.5f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomStart).padding(10.dp))
    }
}

@Composable
internal fun Warnings(p: Project, ws: List<WWarn>, open: Boolean = true) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(G.amberWash).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", G.amberInk, 18.dp, 2f); Text(tr("el.warnN", "n" to ws.size), style = ui(15f, 800, G.amberInk))
        }
        ws.forEach { w ->
            val it0 = w.target?.let { id -> p.win.item(id) }
            val who = if (open) it0?.let { itemTitle(it) } else null
            Text(if (who != null) "$who: " + warnText(w) else warnText(w).replaceFirstChar { it.uppercase() }, style = ui(13f, 500, G.ink, 1.35f),
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).clickable(enabled = open && it0 != null) { it0?.let { app.push(Route.WDesign(p.id, it.id)) } }.padding(vertical = 2.dp))
        }
    }
}

/** The room's openings, each with its product or a button to fill it; a product without a room on its own. */
@Composable
private fun Openings(p: Project, c: WCtx, bad: Set<String>) {
    val app = LocalApp.current
    val items = itemsIn(p, c)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(vertical = 6.dp)) {
        Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(tr(if (c.free != null) "dw.item" else "dw.openings"), style = ui(15f, 800), modifier = Modifier.weight(1f))
            Text(winSummary(items), style = ui(12f, 500, G.ink2), maxLines = 1)
        }
        if (c.free != null) {
            ItemRow(p, c.free, sub = sizeText(c.free.w, c.free.h) + " · " + tr("dw.qtyN", "n" to c.free.qty), bad = c.free.id in bad)
            return@Column
        }
        if (c.room.openings.isEmpty()) Text(tr("dw.noOps"), style = ui(13.5f, 400, G.ink2), modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp))
        c.room.openings.forEach { o ->
            val it0 = items.firstOrNull { it.opening == o.id }
            val head = openingName(c.room, o) + " · " + tr("tl.wallN", "w" to o.wall) + " · " + sizeText(o.w, o.h)
            if (it0 != null) ItemRow(p, it0, sub = head + " → " + sizeText(it0.w, it0.h), bad = it0.id in bad)
            else Row(Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable { app.push(Route.WGallery(p.id, c.id, o.id)) }.padding(horizontal = 14.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(G.ink.copy(alpha = .05f)), contentAlignment = Alignment.Center) {
                    MIcon(if (o.type == "door") "door" else "window", G.ink3, 20.dp, 2f)
                }
                Column(Modifier.weight(1f)) {
                    Text(head, style = ui(14f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(tr("dw.fillOne"), style = ui(12.5f, 600, G.cobalt2))
                }
                MIcon("plus", G.cobalt2, 16.dp, 2.2f)
            }
        }
        items.filter { i -> c.room.openings.none { it.id == i.opening } }.forEach { ItemRow(p, it, sub = tr("dw.w.gone"), bad = true) }
    }
}

@Composable
private fun ItemRow(p: Project, it: uz.metrx.app.win.WinItem, sub: String, bad: Boolean) {
    val app = LocalApp.current
    Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clickable { app.push(Route.WDesign(p.id, it.id)) }.padding(horizontal = 14.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Canvas(Modifier.size(40.dp, 46.dp)) {
            val m = ElevMap(it.w.toDouble(), it.h.toDouble(), Rect(0f, 0f, size.width, size.height), 2f)
            drawElevation(it, m, bad = bad, stroke = 1f)
        }
        Column(Modifier.weight(1f)) {
            Text(itemTitle(it), style = ui(14f, 700, if (bad) G.amberInk else G.ink), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(sub, style = ui(12f, 400, G.ink2), maxLines = 2)
        }
        MIcon("chev", G.ink3, 14.dp, 2f)
    }
}
