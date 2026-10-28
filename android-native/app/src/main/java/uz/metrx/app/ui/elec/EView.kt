package uz.metrx.app.ui.elec

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.View3D
import uz.metrx.app.data.ViewFiles
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.elec.CATS
import uz.metrx.app.elec.CRun
import uz.metrx.app.elec.Circuit
import uz.metrx.app.elec.ECtx
import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecPanel
import uz.metrx.app.elec.EWarn
import uz.metrx.app.elec.cableName
import uz.metrx.app.elec.calcOf
import uz.metrx.app.elec.ctxOf
import uz.metrx.app.elec.devType
import uz.metrx.app.elec.devsIn
import uz.metrx.app.elec.elecParts
import uz.metrx.app.elec.freeRoom
import uz.metrx.app.elec.kitOf
import uz.metrx.app.elec.snapCeil
import uz.metrx.app.elec.snapPanel
import uz.metrx.app.elec.snapWall
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.editor.ShotPill
import uz.metrx.app.ui.furniture.Chip
import uz.metrx.app.ui.furniture.openRoom
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.three.Cam3D
import uz.metrx.app.ui.three.Labels3D
import uz.metrx.app.ui.three.Lbl3D
import uz.metrx.app.ui.three.Scene3D
import uz.metrx.app.ui.three.Shot3D
import kotlin.math.hypot

/*
 * A room's electrics: the room in 3D with its devices at their true places and the circuits' cable in colour, the room
 * from above (lights dragged on the ceiling), or a wall straight on (devices and the panel dragged along it, snapping to
 * the usual heights); under it the warnings, the circuits, the devices and, in the advanced app, what it all takes.
 */

/** The room with its devices and routes in 3D, worked out away from the screen's thread. */
@Composable
fun rememberElecShell(p: Project, r: Room, snap: Boolean): Shell3D {
    // the room's own sockets and switches are drawn as the electrician's devices
    val room = remember(r) { r.copy(points = r.points.filter { it.t != "socket" && it.t != "switch" }) }
    val base = remember(room, snap) { buildShell(listOf(room), true, snap) }
    val shell by produceState(base, base, p.elec, p.rooms) {
        value = withContext(Dispatchers.Default) { runCatching { elecShell(p, r.id, room, base, snap) }.getOrDefault(base) }
    }
    return shell
}

private fun elecShell(p: Project, rid: String, room: Room, base: Shell3D, snap: Boolean): Shell3D {
    val calc = calcOf(p, snap)
    val c = calc.ctxs.firstOrNull { it.id == rid } ?: return base
    val w0 = walls(room, snap).firstOrNull() ?: return base
    val b = base.bases[w0.id] ?: return base
    val dx = b.ox - w0.p0.x / 1000; val dz = b.oz - w0.p0.y / 1000
    val byDev = calc.circuits.flatMap { cc -> cc.devs.map { it.id to cc } }.toMap()
    return base.plus(elecParts(c, devsIn(p, c), calc.routes.panel, calc.routes.inRoom(rid), dx, dz) { byDev[it] }, emptyList())
}

@Composable
fun EViewScreen(rt: Route.EView) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val snap = app.settings.angleSnap
    val free = rt.rid.startsWith("free:")
    LaunchedEffect(rt.rid) { if (!free) { app.takeInPoints(p.id, rt.rid); app.applyPending(p.id) } }
    val calc = rememberCalc(p)
    val c = calc.ctxs.firstOrNull { it.id == rt.rid }
    val room = if (free) null else p.rooms.firstOrNull { it.id == rt.rid }
    val title = c?.free?.let { dn(it.name, lang).ifBlank { tr(kindKey(it.kind)) } } ?: room?.let { r -> p.floors.firstOrNull { it.id == r.floorId }?.let { floorName(it, lang) } ?: dn(r.name, lang) } ?: ""
    var mode by rememberSaveable(rt) { mutableStateOf("3d") }
    var wall by rememberSaveable(rt) { mutableStateOf(c?.g?.walls?.firstOrNull()?.id ?: "A") }
    val ds = c?.let { devsIn(p, it) } ?: emptyList()
    val byDev = remember(calc) { calc.circuits.flatMap { cc -> cc.devs.map { it.id to cc } }.toMap() }
    val runs = calc.routes.inRoom(rt.rid)
    val warns = calc.warns.filter { it.roomId == rt.rid || (it.roomId == null && it.devId == null && it.key != "el.w.noPanel") }
    val bad = warns.mapNotNull { it.devId }.toSet()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val viewH = maxHeight * .46f
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(title, eyebrow = dn(p.name, lang))
                if (room != null) GlassIconButton("edit", tr("common.edit"), { app.openRoom(p.id, room.id) })
                if (c != null && !free) { Spacer(Modifier.width(8.dp)); GlassIconButton("sliders", tr("el.roomSet"), { app.sheet = Sheet.ERoomSet(p.id, c.id) }) }
                if (c != null && free) { Spacer(Modifier.width(8.dp)); GlassIconButton("sliders", tr("el.freeEdit"), { app.sheet = Sheet.EFree(p.id, c.free!!.id) }) }
            }
            if (c == null) {
                Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(tr("tl.needMeasure"), style = ui(16f, 700, G.ink, 1.35f), textAlign = TextAlign.Center)
                    if (room != null) GBtn(tr("ns.measureB"), { app.openRoom(p.id, room.id) }, fill = false)
                }
                return@Column
            }
            Box(Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 6.dp)) {
                Seg(listOf("3d" to "3D", "plan" to tr("ed.plan"), "wall" to tr("el.wallV")), mode) { mode = it }
            }
            Box(Modifier.fillMaxWidth().height(viewH)) {
                when (mode) {
                    "plan" -> PlanView(p, c, ds, calc.routes.panel, runs, byDev, bad, free)
                    "wall" -> WallView(p, c, wall, ds, calc.routes.panel, runs, byDev, bad, free)
                    else -> Room3D(p, c, room, snap)
                }
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (mode == "wall") Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    (c.g.walls + c.g.inner).forEach { w -> Chip(tr("tl.wallN", "w" to w.id) + " · " + fmtLen(w.len.toInt(), LenUnit.M, en), w.id == wall) { wall = w.id } }
                }
                if (warns.isNotEmpty()) Warnings(p, c, warns, byDev)
                if (runs.isNotEmpty()) Circuits(calc, runs)
                if (free) FreeCard(p, c) else Devices(p, c, ds, byDev, bad, if (mode == "wall") wall else null)
                if (!free) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.weight(1f).height(54.dp).dashedGlass(20.dp).pressable({ app.sheet = Sheet.EDev(p.id, c.id, null, if (mode == "wall") wall else null) }, .98f),
                        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                        MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("el.addDev"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
                    }
                    Row(Modifier.weight(1f).height(54.dp).dashedGlass(20.dp).pressable({ app.push(Route.EGallery(p.id, c.id)) }, .98f),
                        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                        MIcon("layers", G.cobalt2, 20.dp, 2f); Text(tr("el.addKit"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
                    }
                }
                if (!free) PanelCard(p, c, calc.routes.panel)
                if (app.settings.advanced) ECountCard(calc.count)
            }
        }
    }
}

@Composable
private fun Room3D(p: Project, c: ECtx, room: Room?, snap: Boolean) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val r = room ?: remember(c.free) { freeRoom(c.free!!) }
    val shell = rememberElecShell(p, r, snap)
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

/* ---------------- from above ---------------- */

@Composable
private fun PlanView(p: Project, c: ECtx, ds: List<ElecDev>, pn: ElecPanel?, runs: List<CRun>, byDev: Map<String, Circuit>, bad: Set<String>, locked: Boolean) {
    val app = LocalApp.current
    val dens = androidx.compose.ui.platform.LocalDensity.current.density
    var drag by remember(c.id) { mutableStateOf<Triple<String, Int, Int>?>(null) }
    val cur by rememberUpdatedState(ds)
    val shown = drag?.let { (id, x, y) -> ds.map { if (it.id == id) it.copy(cx = x, cy = y) else it } } ?: ds
    fun mapOf(w: Float, h: Float) = PlanMap(c, Rect(0f, 0f, w, h), 26 * dens)
    Box(Modifier.fillMaxSize().background(Color(0xFFF6F8FC))) {
        Canvas(Modifier.fillMaxSize().pointerInput(c.id, locked) {
            detectTapGestures { pos ->
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                val hit = cur.minByOrNull { d -> (m.at(c.planOf(d)) - pos).getDistance() }?.takeIf { d -> (m.at(c.planOf(d)) - pos).getDistance() < 28 * dens }
                if (hit != null && !locked) app.sheet = Sheet.EDev(p.id, c.id, hit.id)
            }
        }.pointerInput(c.id, locked) {
            if (locked) return@pointerInput
            var grab: ElecDev? = null; var at = Offset.Zero
            detectDragGestures(onDragStart = { pos ->
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                grab = cur.filter { it.onCeiling }.minByOrNull { d -> (m.at(c.planOf(d)) - pos).getDistance() }?.takeIf { d -> (m.at(c.planOf(d)) - pos).getDistance() < 34 * dens }
                at = pos
            }, onDragEnd = {
                val d = drag; val g = grab
                if (d != null && g != null) app.updateDev(p.id, g.id) { it.copy(cx = d.second, cy = d.third) }
                drag = null; grab = null
            }, onDragCancel = { drag = null; grab = null }) { ch, dd ->
                val g = grab ?: return@detectDragGestures
                ch.consume(); at += dd
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                val q = m.back(at)
                val (x, y) = snapCeil(c, q.x, q.y)
                drag = Triple(g.id, x, y)
            }
        }) {
            val m = mapOf(size.width, size.height)
            drawElecPlan(c, m, shown, pn, runs, { byDev[it] }, 9 * dens, sel = drag?.first, bad = bad)
        }
        Text(tr(if (locked) "el.planFree" else "el.planDrag"), style = ui(11.5f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomStart).padding(10.dp))
    }
}

/* ---------------- a wall straight on ---------------- */

@Composable
private fun WallView(p: Project, c: ECtx, wid: String, ds: List<ElecDev>, pn: ElecPanel?, runs: List<CRun>, byDev: Map<String, Circuit>, bad: Set<String>, locked: Boolean) {
    val app = LocalApp.current
    val w = c.wall(wid) ?: c.g.walls.first()
    val dens = androidx.compose.ui.platform.LocalDensity.current.density
    val tm = rememberTextMeasurer()
    val en = LocalLang.current == Lang.EN
    // the device (or "panel") being dragged and where it would land, mm
    var drag by remember(c.id, w.id) { mutableStateOf<Triple<String, Int, Int>?>(null) }
    val cur by rememberUpdatedState(ds); val curPn by rememberUpdatedState(pn)
    val st = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFF334155))
    fun mapOf(wd: Float, ht: Float) = WallMap(w.len, c.g.H, Rect(0f, 0f, wd, ht), 18 * dens, 22 * dens)
    Box(Modifier.fillMaxSize().background(Color(0xFFF6F8FC))) {
        Canvas(Modifier.fillMaxSize().pointerInput(c.id, w.id, locked) {
            detectTapGestures { pos ->
                if (locked) return@detectTapGestures
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                val hit = cur.filter { it.wall == w.id }.minByOrNull { (m.at(it.off.toDouble(), it.h.toDouble()) - pos).getDistance() }
                    ?.takeIf { (m.at(it.off.toDouble(), it.h.toDouble()) - pos).getDistance() < 30 * dens }
                if (hit != null) app.sheet = Sheet.EDev(p.id, c.id, hit.id)
            }
        }.pointerInput(c.id, w.id, locked) {
            if (locked) return@pointerInput
            var grab: String? = null; var at = Offset.Zero
            detectDragGestures(onDragStart = { pos ->
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                val near = cur.filter { it.wall == w.id }.minByOrNull { (m.at(it.off.toDouble(), it.h.toDouble()) - pos).getDistance() }
                    ?.takeIf { (m.at(it.off.toDouble(), it.h.toDouble()) - pos).getDistance() < 34 * dens }
                val pnHit = curPn?.takeIf { it.roomId == c.id && it.wall == w.id && (m.at(it.off.toDouble(), it.h.toDouble()) - pos).getDistance() < 40 * dens }
                grab = near?.id ?: pnHit?.let { "panel" }
                at = pos
            }, onDragEnd = {
                val d = drag
                if (d != null) {
                    if (d.first == "panel") app.updateElec(p.id) { e -> e.copy(panel = e.panel?.copy(off = d.second, h = d.third)) }
                    else app.updateDev(p.id, d.first) { it.copy(off = d.second, h = d.third) }
                }
                drag = null; grab = null
            }, onDragCancel = { drag = null; grab = null }) { ch, dd ->
                val g = grab ?: return@detectDragGestures
                ch.consume(); at += dd
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                val rawOff = ((at.x - m.x0) / m.k).toInt(); val rawH = ((m.yF - at.y) / m.k).toInt()
                drag = if (g == "panel") curPn?.let { snapPanel(c, it, rawOff, rawH) }?.let { Triple("panel", it.off, it.h) }
                    else cur.firstOrNull { it.id == g }?.let { d -> snapWall(c, d, rawOff, rawH, cur).let { (x, h) -> Triple(g, x, h) } }
            }
        }) {
            val m = mapOf(size.width, size.height)
            val d = drag
            val shownDs = d?.takeIf { it.first != "panel" }?.let { (id, x, h) -> cur.map { if (it.id == id) it.copy(off = x, h = h) else it } } ?: cur
            val shownPn = d?.takeIf { it.first == "panel" }?.let { (_, x, h) -> curPn?.copy(off = x, h = h) } ?: curPn
            drawElecWall(c, w, m, shownDs, shownPn, if (d == null) runs else emptyList(), { byDev[it] }, { s -> tm.measure(fmtLen(s.toIntOrNull(), LenUnit.M, en), st) },
                sel = d?.first, bad = bad, minR = 11 * dens)
        }
        Text(tr(if (locked) "el.planFree" else "el.wallDrag"), style = ui(11.5f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomStart).padding(start = 10.dp, bottom = 2.dp))
    }
}

/* ---------------- under the picture ---------------- */

@Composable
private fun Warnings(p: Project, c: ECtx, ws: List<EWarn>, byDev: Map<String, Circuit>) {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(G.amberWash).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", G.amberInk, 18.dp, 2f); Text(tr("el.warnN", "n" to ws.size), style = ui(15f, 800, G.amberInk))
        }
        ws.forEach { w ->
            val d = w.devId?.let { id -> p.elec.devs.firstOrNull { it.id == id } }
            val vars = w.vars.map { (k, v) -> k to (if (k == "kw" && !en) v.toString().replace('.', ',') else v) }.toTypedArray()
            val who = d?.let { tr("el.t.${it.t}") + (it.wall?.let { x -> " · " + tr("tl.wallN", "w" to x) } ?: "") }
            Text((if (who != null) "$who: " else "") + tr(w.key, *vars), style = ui(13f, 500, G.ink, 1.35f),
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).clickable(enabled = d != null) { if (d != null) app.sheet = Sheet.EDev(p.id, c.id, d.id) }.padding(vertical = 2.dp))
        }
    }
}

@Composable
private fun Circuits(calc: uz.metrx.app.elec.ElecCalc, runs: List<CRun>) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val cs = runs.map { it.circuit }.distinctBy { it.no }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("el.circuits"), style = ui(15f, 800))
        cs.forEach { cc ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(14.dp).clip(CircleShape).background(rgbC(cc.rgb)))
                Column(Modifier.weight(1f)) {
                    Text(tr("el.grpN", "n" to cc.no, "g" to tr("el.g.${cc.group}")), style = ui(14f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text((if (cc.amps > 0) tr("el.brkV", "a" to cc.amps) + " · " else "") + cableName(cc.cable).let { if (lang == Lang.EN) it else it.replace('.', ',') } +
                        (if (cc.rcd) " · " + tr("el.rcdS") else "") + " · " + tr("el.ptsV", "n" to cc.devs.size), style = ui(12.5f, 400, G.ink2), maxLines = 2)
                }
                if (app.settings.advanced) Text(uz.metrx.app.core.Num.fixed(calc.routes.cableOf(cc) / 1000, 1, lang) + " " + tr("u.m"), style = num(13.5f, 700))
            }
        }
        Text(tr("el.m.${calc.routes.method}S"), style = ui(12f, 400, G.ink3, 1.35f))
    }
}

@Composable
private fun Devices(p: Project, c: ECtx, ds: List<ElecDev>, byDev: Map<String, Circuit>, bad: Set<String>, wall: String?) {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    val list = if (wall != null) ds.filter { it.wall == wall } else ds
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(vertical = 6.dp)) {
        Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(if (wall != null) tr("el.onWall", "w" to wall) else tr("el.devs"), style = ui(15f, 800), modifier = Modifier.weight(1f))
            if (list.isNotEmpty()) Text(devSummary(list), style = ui(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1.4f), textAlign = TextAlign.End)
        }
        if (list.isEmpty()) Text(tr("el.noDevs"), style = ui(13.5f, 400, G.ink2), modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp))
        CATS.forEach { cat ->
            list.filter { devType(it.t).cat == cat }.sortedWith(compareBy({ it.wall ?: "~" }, { it.off })).forEach { d ->
                Row(Modifier.fillMaxWidth().heightIn(min = 50.dp).clickable { app.sheet = Sheet.EDev(p.id, c.id, d.id) }.padding(horizontal = 14.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    val col = byDev[d.id]?.let { rgbC(it.rgb) } ?: Color(0xFF94A3B8)
                    Canvas(Modifier.size(30.dp)) { devSymbol(d.t, center, size.minDimension / 3.4f, col, if (d.id in bad) Color(0xFFDC2626) else E_INK) }
                    Column(Modifier.weight(1f)) {
                        Text(tr("el.t.${d.t}") + (if (d.own) " · " + tr("el.ownShort") else ""), style = ui(14f, 700, if (d.id in bad) G.amberInk else G.ink), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(if (d.onCeiling) tr("el.onCeil") else tr("tl.wallN", "w" to (d.wall ?: "")) + " · " + tr("el.atH", "h" to fmtLen(d.h, LenUnit.M, en)) +
                            (if (d.t == "led") " · " + fmtLen(d.len, LenUnit.M, en) + " " + tr("u.m") else ""), style = ui(12f, 400, G.ink2), maxLines = 1)
                    }
                    byDev[d.id]?.let { Text("№${it.no}", style = num(12.5f, 700, G.ink2)) }
                    MIcon("chev", G.ink3, 14.dp, 2f)
                }
            }
        }
    }
}

/** A room typed by size: what it has, and the button that changes it. */
@Composable
private fun FreeCard(p: Project, c: ECtx) {
    val app = LocalApp.current
    val f = c.free ?: return
    val en = LocalLang.current == Lang.EN
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("el.freeT"), style = ui(15f, 800))
        Kv(tr("el.size"), fmtLen(f.L, LenUnit.M, en) + " × " + fmtLen(f.W, LenUnit.M, en) + " × " + fmtLen(f.H, LenUnit.M, en) + " " + tr("u.m"))
        listOf("sock" to f.sock, "sw" to f.sw, "light" to f.light, "low" to f.low, "power" to f.power).filter { it.second > 0 }.forEach { (k, n) -> Kv(tr("el.fc.$k"), "$n") }
        Kv(tr("el.link"), fmtLen(f.link, LenUnit.M, en) + " " + tr("u.m"))
        Text(tr("el.freeNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
        GBtn(tr("fz.change"), { app.sheet = Sheet.EFree(p.id, f.id) }, Btn.SECONDARY, icon = "edit", height = 44.dp, corner = 14.dp, fontSize = 14f)
    }
}

/** The panel: here (drag it on the wall view), or another room's, with the button that brings it here. */
@Composable
private fun PanelCard(p: Project, c: ECtx, pn: ElecPanel?) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Canvas(Modifier.size(30.dp)) { devSymbol("panel", center, size.minDimension / 3.4f, E_INK) }
            Column(Modifier.weight(1f)) {
                Text(tr("el.panel"), style = ui(15f, 800))
                Text(when {
                    pn == null -> tr("el.panelNone")
                    pn.roomId == c.id -> tr("el.panelAt", "w" to pn.wall, "h" to fmtLen(pn.h, LenUnit.M, en))
                    else -> tr("el.panelIn", "r" to (p.rooms.firstOrNull { it.id == pn.roomId }?.let { r -> p.floors.firstOrNull { it.id == r.floorId }?.let { floorName(it, lang) } ?: dn(r.name, lang) } ?: ""))
                }, style = ui(12.5f, 400, G.ink2, 1.35f))
            }
        }
        if (pn?.roomId != c.id) GBtn(tr("el.panelMove"), {
            val d = uz.metrx.app.elec.panelIn(c, p.elec.devs.filter { it.roomId == c.id })
            app.updateElec(p.id) { it.copy(panel = d) }; app.say("el.panelSet")
        }, Btn.SECONDARY, icon = "box", height = 44.dp, corner = 14.dp, fontSize = 14f)
        else Text(tr("el.panelDrag"), style = ui(12.5f, 400, G.ink2, 1.35f))
    }
}
