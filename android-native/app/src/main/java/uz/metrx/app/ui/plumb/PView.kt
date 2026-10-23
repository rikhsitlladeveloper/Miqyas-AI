package uz.metrx.app.ui.plumb

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
import uz.metrx.app.elec.nearestWall
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.walls
import uz.metrx.app.plumb.APt
import uz.metrx.app.plumb.FIX_CATS
import uz.metrx.app.plumb.PCtx
import uz.metrx.app.plumb.PRoutes
import uz.metrx.app.plumb.PRun
import uz.metrx.app.plumb.PWarn
import uz.metrx.app.plumb.PlFix
import uz.metrx.app.plumb.PlRiser
import uz.metrx.app.plumb.PlumbCalc
import uz.metrx.app.plumb.RISER_D
import uz.metrx.app.plumb.SITE_WATER
import uz.metrx.app.plumb.calcOf
import uz.metrx.app.plumb.fixD
import uz.metrx.app.plumb.fixTop
import uz.metrx.app.plumb.fixType
import uz.metrx.app.plumb.fixW
import uz.metrx.app.plumb.fixZ0
import uz.metrx.app.plumb.fixesIn
import uz.metrx.app.plumb.kindRgb
import uz.metrx.app.plumb.plumbParts
import uz.metrx.app.plumb.pointsIn
import uz.metrx.app.plumb.riserIn
import uz.metrx.app.plumb.snapFix
import uz.metrx.app.plumb.snapFixPlan
import uz.metrx.app.plumb.snapPoint
import uz.metrx.app.plumb.snapRiser
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.editor.ShotPill
import uz.metrx.app.ui.elec.Kv
import uz.metrx.app.ui.elec.PlanMap
import uz.metrx.app.ui.elec.WallMap
import uz.metrx.app.ui.elec.rgbC
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

/*
 * A room's plumbing: the room in 3D with its fixtures at their true size, the riser, the cold, hot, drain and heating
 * pipes in their colours and the underfloor loops; the room from above (fixtures and the riser dragged onto and along
 * the walls); or a wall straight on (fixtures, outlets and the riser dragged along it, the outlets with their heights).
 * Under it the warnings, the fixtures, the outlets, the riser, the heating and, in the advanced app, what it all takes.
 */

/** Every pipe in room [rid]: the water and heating trunks and the drains' pieces there. */
fun runsIn(rt: PRoutes, rid: String): List<PRun> = rt.inRoom(rid) + rt.drains.flatMap { it.runs }.filter { it.roomId == rid }

/** The room with its fixtures and pipes in 3D, worked out away from the screen's thread. */
@Composable
fun rememberPlumbShell(p: Project, r: Room, snap: Boolean): Shell3D {
    // the room's own water and drain marks, once taken in, are drawn as the plumber's outlets
    val seen = p.plumb.room(r.id).seen
    val room = remember(r, seen) { r.copy(points = r.points.filter { it.t !in SITE_WATER || it.id !in seen }) }
    val base = remember(room, snap) { buildShell(listOf(room), true, snap) }
    val shell by produceState(base, base, p.plumb, p.rooms) {
        value = withContext(Dispatchers.Default) { runCatching { plumbShell(p, r.id, room, base, snap) }.getOrDefault(base) }
    }
    return shell
}

private fun plumbShell(p: Project, rid: String, room: Room, base: Shell3D, snap: Boolean): Shell3D {
    val calc = calcOf(p, snap)
    val c = calc.ctxs.firstOrNull { it.id == rid } ?: return base
    val w0 = walls(room, snap).firstOrNull() ?: return base
    val b = base.bases[w0.id] ?: return base
    val dx = b.ox - w0.p0.x / 1000; val dz = b.oz - w0.p0.y / 1000
    val fs = fixesIn(p, c)
    return base.plus(plumbParts(c, fs, pointsIn(p, c, fs), calc.routes.riser, runsIn(calc.routes, rid), calc.routes.loops.firstOrNull { it.roomId == rid }, dx, dz), emptyList())
}

/** A warning's words: its values read in the language ("~key" a strings key, decimals with a comma). */
@Composable
fun warnText(w: PWarn): String {
    val en = LocalLang.current == Lang.EN
    val vars = w.vars.map { (k, v) ->
        val s = v.toString()
        k to (if (s.startsWith("~")) tr(s.drop(1)) else if (!en) s.replace('.', ',') else s)
    }.toTypedArray()
    return tr(w.key, *vars)
}

@Composable
fun PViewScreen(rt: Route.PView) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val snap = app.settings.angleSnap
    val free = rt.rid.startsWith("free:")
    LaunchedEffect(rt.rid) { if (!free) { app.takeInPlumbPoints(p.id, rt.rid); app.applyPPending(p.id) } }
    val calc = rememberPCalc(p)
    val c = calc.ctxs.firstOrNull { it.id == rt.rid }
    val room = if (free) null else p.rooms.firstOrNull { it.id == rt.rid }
    val title = c?.free?.let { dn(it.name, lang).ifBlank { tr(kindKey(it.kind)) } } ?: room?.let { r -> p.floors.firstOrNull { it.id == r.floorId }?.let { floorName(it, lang) } ?: dn(r.name, lang) } ?: ""
    var mode by rememberSaveable(rt) { mutableStateOf("3d") }
    var wall by rememberSaveable(rt) { mutableStateOf(c?.g?.walls?.firstOrNull()?.id ?: "A") }
    var layerS by rememberSaveable(rt) { mutableStateOf(LAYERS.joinToString(",")) }
    val layers = layerS.split(',').filter { it.isNotEmpty() }
    val fs = c?.let { fixesIn(p, it) } ?: emptyList()
    val pts = c?.let { pointsIn(p, it, fs) } ?: emptyList()
    val runs = runsIn(calc.routes, rt.rid)
    val warns = calc.warns.filter { it.roomId == rt.rid || it.roomId == null }
    val bad = warns.mapNotNull { it.target }.toSet()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val viewH = maxHeight * .46f
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(title, eyebrow = dn(p.name, lang))
                if (room != null) GlassIconButton("edit", tr("common.edit"), { app.openRoom(p.id, room.id) })
                if (c != null && !free) { Spacer(Modifier.width(8.dp)); GlassIconButton("sliders", tr("el.roomSet"), { app.sheet = Sheet.PRoomSet(p.id, c.id) }) }
                if (c != null && free) { Spacer(Modifier.width(8.dp)); GlassIconButton("sliders", tr("el.freeEdit"), { app.sheet = Sheet.PFree(p.id, c.free!!.id) }) }
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
                    "plan" -> PlanView(p, c, fs, pts, calc.routes.riser, runs, calc, layers.toSet(), bad, free)
                    "wall" -> WallView(p, c, wall, fs, pts, calc.routes.riser, runs, layers.toSet(), bad, free)
                    else -> Room3D(p, c, room, snap)
                }
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (mode == "wall") Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    c.g.walls.forEach { w -> Chip(tr("tl.wallN", "w" to w.id) + " · " + fmtLen(w.len.toInt(), LenUnit.M, en), w.id == wall) { wall = w.id } }
                }
                if (mode != "3d") Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    LAYERS.forEach { k -> Chip(tr("sx.l.$k"), k in layers) { layerS = (if (k in layers) layers - k else LAYERS.filter { it in layers || it == k }).joinToString(",") } }
                }
                Legend(runs.map { it.kind }.toSet() + pts.map { it.t }, calc.routes.loops.any { it.roomId == c.id && it.n > 0 })
                if (warns.isNotEmpty()) Warnings(p, c, warns)
                if (free) FreeCard(p, c) else Fixtures(p, c, fs, pts, bad, if (mode == "wall") wall else null)
                if (!free) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.weight(1f).height(54.dp).dashedGlass(20.dp).pressable({ app.sheet = Sheet.PFix(p.id, c.id, null, if (mode == "wall") wall else null) }, .98f),
                        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                        MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("sx.addFix"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
                    }
                    Row(Modifier.weight(1f).height(54.dp).dashedGlass(20.dp).pressable({ app.push(Route.PGallery(p.id, c.id)) }, .98f),
                        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                        MIcon("layers", G.cobalt2, 20.dp, 2f); Text(tr("el.addKit"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
                    }
                }
                if (!free) Text(tr("sx.addPt"), style = ui(14f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).clip(RoundedCornerShape(12.dp))
                    .clickable(role = Role.Button) { app.sheet = Sheet.PPoint(p.id, c.id, null, if (mode == "wall") wall else c.g.walls.first().id) }.padding(horizontal = 14.dp, vertical = 10.dp))
                if (!free) RiserCard(p, c, calc.routes.riser)
                HeatCard(p, c, calc)
                if (app.settings.advanced) PRoomCount(c, runs, calc)
                if (app.settings.advanced) PCountCard(p, calc.count)
            }
        }
    }
}

@Composable
private fun Room3D(p: Project, c: PCtx, room: Room?, snap: Boolean) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val r = room ?: c.room
    val shell = rememberPlumbShell(p, r, snap)
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

/** What is being dragged: a fixture's or outlet's id or "riser", the wall it lands on, along it, (an outlet's) height. */
private data class Drag(val id: String, val wall: String, val off: Int, val h: Int = 0)

/** The fixtures, outlets and riser as they would be with [d] dropped. */
private fun moved(d: Drag?, fs: List<PlFix>, pts: List<APt>, rs: PlRiser?): Triple<List<PlFix>, List<APt>, PlRiser?> {
    if (d == null) return Triple(fs, pts, rs)
    if (d.id == "riser") return Triple(fs, pts, rs?.copy(wall = d.wall, off = d.off))
    val f = fs.firstOrNull { it.id == d.id }
    if (f != null) {
        val g = f.copy(wall = d.wall, off = d.off)
        return Triple(fs.map { if (it.id == d.id) g else it }, pts.filter { it.fix != f.id } + uz.metrx.app.plumb.fixPoints(g), rs)
    }
    return Triple(fs, pts.map { if (it.id == d.id && it.fix == null) APt(it.id, it.t, it.roomId, d.wall, d.off, d.h, it.d, null, null, 0) else it }, rs)
}

/** Saves a drag. */
private fun uz.metrx.app.ui.App.dropDrag(pid: String, d: Drag) {
    when {
        d.id == "riser" -> updatePlumb(pid) { e -> e.copy(riser = e.riser?.copy(wall = d.wall, off = d.off)) }
        store.get(pid)?.plumb?.fixes?.any { it.id == d.id } == true -> updateFix(pid, d.id) { it.copy(wall = d.wall, off = d.off) }
        else -> updatePt(pid, d.id) { it.copy(wall = d.wall, off = d.off, h = d.h) }
    }
}

@Composable
private fun PlanView(p: Project, c: PCtx, fs: List<PlFix>, pts: List<APt>, rs: PlRiser?, runs: List<PRun>, calc: PlumbCalc, layers: Set<String>, bad: Set<String>, locked: Boolean) {
    val app = LocalApp.current
    val dens = androidx.compose.ui.platform.LocalDensity.current.density
    var drag by remember(c.id) { mutableStateOf<Drag?>(null) }
    val curF by rememberUpdatedState(fs); val curP by rememberUpdatedState(pts); val curR by rememberUpdatedState(rs)
    fun mapOf(w: Float, h: Float) = PlanMap(c.g.floor, Rect(0f, 0f, w, h), 26 * dens)
    fun fixAt(m: PlanMap, f: PlFix) = c.wall(f.wall)?.let { m.at(it.at(f.off.toDouble(), fixD(f) / 2.0)) }
    fun ptAt(m: PlanMap, q: APt) = c.wall(q.wall)?.let { m.at(it.at(q.off.toDouble(), 30.0)) }
    fun riserAt(m: PlanMap, r: PlRiser) = r.takeIf { it.roomId == c.id }?.let { c.wall(it.wall) }?.let { m.at(it.at(r.off.toDouble(), RISER_D / 2.0)) }
    /** The nearest thing to [pos]: a loose outlet, the riser, a fixture. */
    fun hitAt(m: PlanMap, pos: Offset, reach: Float): String? {
        val cands = ArrayList<Pair<String, Float>>()
        curP.filter { it.fix == null }.forEach { q -> ptAt(m, q)?.let { cands += q.id to (it - pos).getDistance() - 6 * dens } }
        curR?.let { r -> riserAt(m, r)?.let { cands += "riser" to (it - pos).getDistance() } }
        curF.forEach { f -> fixAt(m, f)?.let { cands += f.id to (it - pos).getDistance() - (minOf(fixW(f), fixD(f)) / 2.0 * m.k).toFloat().coerceAtMost(24 * dens) } }
        return cands.minByOrNull { it.second }?.takeIf { it.second < reach }?.first
    }
    Box(Modifier.fillMaxSize().background(Color(0xFFF6F8FC))) {
        Canvas(Modifier.fillMaxSize().pointerInput(c.id, locked) {
            detectTapGestures { pos ->
                if (locked) return@detectTapGestures
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                when (val hit = hitAt(m, pos, 28 * dens)) {
                    null -> {}
                    "riser" -> app.sheet = Sheet.PSystem(p.id)
                    else -> if (curF.any { it.id == hit }) app.sheet = Sheet.PFix(p.id, c.id, hit) else app.sheet = Sheet.PPoint(p.id, c.id, hit)
                }
            }
        }.pointerInput(c.id, locked) {
            if (locked) return@pointerInput
            var grab: String? = null; var at = Offset.Zero
            detectDragGestures(onDragStart = { pos ->
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                grab = hitAt(m, pos, 34 * dens); at = pos
            }, onDragEnd = {
                drag?.let { app.dropDrag(p.id, it) }
                drag = null; grab = null
            }, onDragCancel = { drag = null; grab = null }) { ch, dd ->
                val g = grab ?: return@detectDragGestures
                ch.consume(); at += dd
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                val q = m.back(at)
                drag = when {
                    g == "riser" -> curR?.let { r -> val (w, a, _) = nearestWall(c.g.walls, q); snapRiser(c, r, w.id, a.toInt()).let { Drag("riser", it.wall, it.off) } }
                    curF.any { it.id == g } -> curF.first { it.id == g }.let { f -> val (wid, x) = snapFixPlan(c, f, q, curF, curR); Drag(g, wid, x) }
                    else -> curP.firstOrNull { it.id == g }?.let { pt ->
                        val (w, a, _) = nearestWall(c.g.walls, q)
                        val (x, h) = snapPoint(c, uz.metrx.app.plumb.PlPoint(pt.id, pt.t, c.id, w.id, pt.off, pt.h), a.toInt(), pt.h)
                        Drag(g, w.id, x, h)
                    }
                }
            }
        }) {
            val m = mapOf(size.width, size.height)
            val (sf, sp, sr) = moved(drag, curF, curP, curR)
            drawPlumbPlan(c, m, sf, sp, sr, if (drag == null) runs else emptyList(), calc.routes.loops.firstOrNull { it.roomId == c.id }, 9 * dens, layers,
                sel = drag?.id, bad = bad)
        }
        Text(tr(if (locked) "el.planFree" else "sx.planDrag"), style = ui(11.5f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomStart).padding(10.dp))
    }
}

/* ---------------- a wall straight on ---------------- */

@Composable
private fun WallView(p: Project, c: PCtx, wid: String, fs: List<PlFix>, pts: List<APt>, rs: PlRiser?, runs: List<PRun>, layers: Set<String>, bad: Set<String>, locked: Boolean) {
    val app = LocalApp.current
    val w = c.wall(wid) ?: c.g.walls.first()
    val dens = androidx.compose.ui.platform.LocalDensity.current.density
    val tm = rememberTextMeasurer()
    val en = LocalLang.current == Lang.EN
    val riserWord = tr("sx.riser")
    var drag by remember(c.id, w.id) { mutableStateOf<Drag?>(null) }
    val curF by rememberUpdatedState(fs); val curP by rememberUpdatedState(pts); val curR by rememberUpdatedState(rs)
    val st = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFF334155))
    fun mapOf(wd: Float, ht: Float) = WallMap(w.len, c.g.H, Rect(0f, 0f, wd, ht), 18 * dens, 22 * dens)
    fun hitAt(m: WallMap, pos: Offset, reach: Float): String? {
        val cands = ArrayList<Pair<String, Float>>()
        curP.filter { it.fix == null && it.wall == w.id }.forEach { q -> cands += q.id to (m.at(q.off.toDouble(), q.h.toDouble()) - pos).getDistance() - 6 * dens }
        curR?.takeIf { it.roomId == c.id && it.wall == w.id }?.let { r -> val x = m.x(r.off.toDouble()); if (pos.y in m.y(c.g.H)..m.y(0.0)) cands += "riser" to kotlin.math.abs(pos.x - x) }
        curF.filter { it.wall == w.id }.forEach { f ->
            val x0 = m.x(f.off - fixW(f) / 2.0); val x1 = m.x(f.off + fixW(f) / 2.0); val y0 = m.y(fixTop(f).toDouble()); val y1 = m.y(fixZ0(f).toDouble())
            val dx = maxOf(0f, x0 - pos.x, pos.x - x1); val dy = maxOf(0f, y0 - pos.y, pos.y - y1)
            cands += f.id to kotlin.math.hypot(dx, dy) + 2 * dens
        }
        return cands.minByOrNull { it.second }?.takeIf { it.second < reach }?.first
    }
    Box(Modifier.fillMaxSize().background(Color(0xFFF6F8FC))) {
        Canvas(Modifier.fillMaxSize().pointerInput(c.id, w.id, locked) {
            detectTapGestures { pos ->
                if (locked) return@detectTapGestures
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                when (val hit = hitAt(m, pos, 26 * dens)) {
                    null -> {}
                    "riser" -> app.sheet = Sheet.PSystem(p.id)
                    else -> if (curF.any { it.id == hit }) app.sheet = Sheet.PFix(p.id, c.id, hit) else app.sheet = Sheet.PPoint(p.id, c.id, hit)
                }
            }
        }.pointerInput(c.id, w.id, locked) {
            if (locked) return@pointerInput
            var grab: String? = null; var at = Offset.Zero
            detectDragGestures(onDragStart = { pos ->
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                grab = hitAt(m, pos, 34 * dens); at = pos
            }, onDragEnd = {
                drag?.let { app.dropDrag(p.id, it) }
                drag = null; grab = null
            }, onDragCancel = { drag = null; grab = null }) { ch, dd ->
                val g = grab ?: return@detectDragGestures
                ch.consume(); at += dd
                val m = mapOf(size.width.toFloat(), size.height.toFloat())
                val rawOff = ((at.x - m.x0) / m.k).toInt(); val rawH = ((m.yF - at.y) / m.k).toInt()
                drag = when {
                    g == "riser" -> curR?.let { snapRiser(c, it, w.id, rawOff) }?.let { Drag("riser", it.wall, it.off) }
                    curF.any { it.id == g } -> curF.first { it.id == g }.let { f -> snapFix(c, f, w.id, rawOff, curF, curR)?.let { Drag(g, w.id, it) } ?: Drag(g, f.wall, f.off) }
                    else -> curP.firstOrNull { it.id == g }?.let { pt ->
                        val (x, h) = snapPoint(c, uz.metrx.app.plumb.PlPoint(pt.id, pt.t, c.id, w.id, pt.off, pt.h), rawOff, rawH)
                        Drag(g, w.id, x, h)
                    }
                }
            }
        }) {
            val m = mapOf(size.width, size.height)
            val (sf, sp, sr) = moved(drag, curF, curP, curR)
            drawPlumbWall(c, w, m, sf, sp, sr, if (drag == null) runs else emptyList(),
                { s -> tm.measure(if (s == "riser") riserWord else fmtLen(s.toIntOrNull(), LenUnit.M, en), st) }, layers, sel = drag?.id, bad = bad, minR = 7 * dens)
        }
        Text(tr(if (locked) "el.planFree" else "sx.wallDrag"), style = ui(11.5f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomStart).padding(start = 10.dp, bottom = 2.dp))
    }
}

/* ---------------- under the picture ---------------- */

/** The pipes' colours in this room, the underfloor loops' too. */
@Composable
private fun Legend(kinds: Set<String>, loops: Boolean) {
    val ks = listOf("cold", "hot", "drain", "hs", "hr").filter { it in kinds }
    if (ks.isEmpty() && !loops) return
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        ks.forEach { k ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Box(Modifier.size(width = 16.dp, height = if (k == "drain") 6.dp else 4.dp).clip(RoundedCornerShape(2.dp)).background(rgbC(kindRgb(k))))
                Text(tr("sx.o.$k"), style = ui(12f, 600, G.ink2), maxLines = 1)
            }
        }
        if (loops) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Box(Modifier.size(width = 16.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(rgbC(uz.metrx.app.plumb.UFH_RGB)))
            Text(tr("sx.s.ufh"), style = ui(12f, 600, G.ink2), maxLines = 1)
        }
    }
}

@Composable
private fun Warnings(p: Project, c: PCtx, ws: List<PWarn>) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(G.amberWash).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("alert", G.amberInk, 18.dp, 2f); Text(tr("el.warnN", "n" to ws.size), style = ui(15f, 800, G.amberInk))
        }
        ws.forEach { w ->
            val f = w.target?.let { id -> p.plumb.fixes.firstOrNull { it.id == id } }
            val pt = if (f == null) w.target?.let { id -> p.plumb.points.firstOrNull { it.id == id } } else null
            val who = f?.let { tr("sx.t.${it.t}") + " · " + tr("tl.wallN", "w" to it.wall) } ?: pt?.let { tr("sx.o.${it.t}") + " · " + tr("tl.wallN", "w" to it.wall) }
                ?: if (c.free != null && w.target != null) fixesIn(p, c).firstOrNull { it.id == w.target }?.let { tr("sx.t.${it.t}") } else null
            Text((if (who != null) "$who: " else "") + warnText(w), style = ui(13f, 500, G.ink, 1.35f),
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).clickable(enabled = f != null || pt != null) {
                    if (f != null) app.sheet = Sheet.PFix(p.id, f.roomId, f.id) else if (pt != null) app.sheet = Sheet.PPoint(p.id, pt.roomId, pt.id)
                }.padding(vertical = 2.dp))
        }
    }
}

@Composable
private fun Fixtures(p: Project, c: PCtx, fs: List<PlFix>, pts: List<APt>, bad: Set<String>, wall: String?) {
    val app = LocalApp.current
    val en = LocalLang.current == Lang.EN
    val list = if (wall != null) fs.filter { it.wall == wall } else fs
    val loose = pts.filter { it.fix == null && (wall == null || it.wall == wall) }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(vertical = 6.dp)) {
        Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(if (wall != null) tr("el.onWall", "w" to wall) else tr("sx.fixes"), style = ui(15f, 800), modifier = Modifier.weight(1f))
            Text(fixSummary(list), style = ui(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1.4f), textAlign = TextAlign.End)
        }
        if (list.isEmpty() && loose.isEmpty()) Text(tr("sx.noFix"), style = ui(13.5f, 400, G.ink2), modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp))
        FIX_CATS.forEach { cat ->
            list.filter { fixType(it.t).cat == cat }.sortedWith(compareBy({ it.wall }, { it.off })).forEach { f ->
                Row(Modifier.fillMaxWidth().heightIn(min = 50.dp).clickable { app.sheet = Sheet.PFix(p.id, c.id, f.id) }.padding(horizontal = 14.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Canvas(Modifier.size(30.dp)) { fixSymbol(f.t, center, size.minDimension / 2.3f, if (f.id in bad) Color(0xFFDC2626) else P_INK) }
                    Column(Modifier.weight(1f)) {
                        Text(tr("sx.t.${f.t}") + (if (f.t == "rad") " · " + fmtLen(fixW(f), LenUnit.M, en) + " " + tr("u.m") else ""), style = ui(14f, 700, if (f.id in bad) G.amberInk else G.ink), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(tr("tl.wallN", "w" to f.wall) + " · " + f.pts.joinToString(", ") { app.t("sx.o.${it.t}") + " " + fmtLen(it.h, LenUnit.M, en) }, style = ui(12f, 400, G.ink2), maxLines = 2)
                    }
                    MIcon("chev", G.ink3, 14.dp, 2f)
                }
            }
        }
        if (loose.isNotEmpty()) {
            Text(tr("sx.loose"), style = ui(13f, 700, G.ink2), modifier = Modifier.padding(start = 14.dp, top = 6.dp))
            loose.sortedWith(compareBy({ it.wall }, { it.off })).forEach { q ->
                Row(Modifier.fillMaxWidth().heightIn(min = 46.dp).clickable { app.sheet = Sheet.PPoint(p.id, c.id, q.id) }.padding(horizontal = 14.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Canvas(Modifier.size(30.dp)) { ptSymbol(q.t, center, size.minDimension / 4f) }
                    Column(Modifier.weight(1f)) {
                        Text(tr("sx.o.${q.t}") + (if (q.t == "drain") " Ø${uz.metrx.app.plumb.drainD(q.d)}" else ""), style = ui(14f, 700), maxLines = 1)
                        Text(tr("tl.wallN", "w" to q.wall) + " · " + tr("el.atH", "h" to fmtLen(q.h, LenUnit.M, en)), style = ui(12f, 400, G.ink2), maxLines = 1)
                    }
                    MIcon("chev", G.ink3, 14.dp, 2f)
                }
            }
        }
    }
}

/** A room typed by size: what it has, and the button that changes it. */
@Composable
private fun FreeCard(p: Project, c: PCtx) {
    val app = LocalApp.current
    val f = c.free ?: return
    val en = LocalLang.current == Lang.EN
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("el.freeT"), style = ui(15f, 800))
        Kv(tr("el.size"), fmtLen(f.L, LenUnit.M, en) + " × " + fmtLen(f.W, LenUnit.M, en) + " × " + fmtLen(f.H, LenUnit.M, en) + " " + tr("u.m"))
        listOf("wc" to f.wc, (if (f.small) "bsm" else "bs") to f.basin, "bath" to f.bath, (if (f.cabin) "cab" else "sh") to f.shower, "sink" to f.sink, "wm" to f.wm, "dw" to f.dw,
            "wh" to f.wh, "gb" to f.gb, "rad" to f.rad, "tr" to f.tr)
            .filter { it.second > 0 }.forEach { (k, n) -> Kv(tr("sx.t.$k"), "$n") }
        if (f.ufh) Kv(tr("sx.s.ufh"), "✓")
        Kv(tr("sx.freeLink"), fmtLen(f.link, LenUnit.M, en) + " " + tr("u.m"))
        Text(tr("sx.freeNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
        GBtn(tr("fz.change"), { app.sheet = Sheet.PFree(p.id, f.id) }, Btn.SECONDARY, icon = "edit", height = 44.dp, corner = 14.dp, fontSize = 14f)
    }
}

/** The riser: here (drag it on the plan or the wall), or in another room, with the button that brings it here. */
@Composable
private fun RiserCard(p: Project, c: PCtx, rs: PlRiser?) {
    val app = LocalApp.current
    val lang = LocalLang.current
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Canvas(Modifier.size(30.dp)) { riserSymbol(center, size.minDimension / 2.6f, rs?.hot ?: true) }
            Column(Modifier.weight(1f)) {
                Text(tr("sx.riser"), style = ui(15f, 800))
                Text(when {
                    rs == null -> tr("sx.riserNone")
                    rs.roomId == c.id -> tr("sx.riserAt", "w" to rs.wall)
                    else -> tr("el.panelIn", "r" to (p.rooms.firstOrNull { it.id == rs.roomId }?.let { r -> p.floors.firstOrNull { it.id == r.floorId }?.let { floorName(it, lang) } ?: dn(r.name, lang) } ?: ""))
                } + " · " + tr("sx.riserKit"), style = ui(12.5f, 400, G.ink2, 1.35f))
            }
        }
        if (rs?.roomId != c.id) GBtn(tr("sx.riserMove"), {
            val d = riserIn(c, p.plumb.fixes)
            app.updatePlumb(p.id) { it.copy(riser = d.copy(hot = rs?.hot ?: true)) }; app.say("sx.riserSet")
        }, Btn.SECONDARY, icon = "box", height = 44.dp, corner = 14.dp, fontSize = 14f)
        else Text(tr("sx.riserDrag"), style = ui(12.5f, 400, G.ink2, 1.35f))
        GBtn(tr("sx.system"), { app.sheet = Sheet.PSystem(p.id) }, Btn.SECONDARY, icon = "layers", height = 44.dp, corner = 14.dp, fontSize = 14f)
    }
}

/** The heating in this room: the boiler, the radiators and their heat against the room's need, the underfloor loops. */
@Composable
private fun HeatCard(p: Project, c: PCtx, calc: PlumbCalc) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val fs = fixesIn(p, c)
    val rads = fs.filter { it.t == "rad" }
    val loop = calc.routes.loops.firstOrNull { it.roomId == c.id }
    if (rads.isEmpty() && loop == null) return
    fun d1(v: Double) = uz.metrx.app.core.Num.fixed(v, 1, lang)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("sx.s.heat"), style = ui(15f, 800))
        Kv(tr("sx.heatNeed"), tr("sx.watts", "w" to (c.areaM2 * uz.metrx.app.plumb.W_M2).toInt(), "a" to d1(c.areaM2)))
        if (rads.isNotEmpty()) Kv(tr("sx.t.rad"), tr("sx.radsV", "n" to rads.size, "w" to rads.sumOf { uz.metrx.app.plumb.radWatts(it) }))
        if (loop != null) {
            Kv(tr("sx.s.ufh"), tr("sx.loopV", "n" to loop.n, "s" to loop.step / 10, "a" to d1(loop.area)))
            // the loop's length is the advanced app's (a count for buying)
            if (app.settings.advanced) Kv(tr("sx.loopLen"), d1(loop.each / 1000) + " " + tr("u.m") + (if (loop.n > 1) " × ${loop.n}" else ""))
        }
        if (calc.routes.heat == null) Text(tr("sx.w.noBoiler"), style = ui(12.5f, 500, G.amberInk, 1.35f))
    }
}

/** The pipe in this room by kind (the advanced app). */
@Composable
private fun PRoomCount(c: PCtx, runs: List<PRun>, calc: PlumbCalc) {
    val lang = LocalLang.current
    if (runs.isEmpty()) return
    fun d1(v: Double) = uz.metrx.app.core.Num.fixed(v, 1, lang)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("sx.roomPipe"), style = ui(15f, 800))
        listOf("cold", "hot", "drain", "hs", "hr").forEach { k ->
            val rs = runs.filter { it.kind == k }
            if (rs.isEmpty()) return@forEach
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(12.dp).clip(CircleShape).background(rgbC(kindRgb(k))))
                Text(tr("sx.o.$k") + " · Ø" + rs.maxOf { it.dia }, style = ui(14f, 600), modifier = Modifier.weight(1f))
                Text(d1(rs.sumOf { it.len } / 1000) + " " + tr("u.m"), style = num(13.5f, 700))
            }
        }
        val ds = calc.routes.drains.filter { it.pt.roomId == c.id }
        if (ds.isNotEmpty()) Text(tr("sx.slopeV", "s" to d1(ds.minOf { it.slope } / 10), "m" to d1(ds.maxOf { it.horiz } / 1000)), style = ui(12f, 400, G.ink3, 1.35f))
    }
}
