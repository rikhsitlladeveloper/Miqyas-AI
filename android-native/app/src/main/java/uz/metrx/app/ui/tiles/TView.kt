package uz.metrx.app.ui.tiles

import uz.metrx.app.data.putBack
import androidx.compose.foundation.Canvas
import uz.metrx.app.ui.components.switchState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
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
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
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
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.ready3D
import uz.metrx.app.geo.walls
import uz.metrx.app.tiles.Laid
import uz.metrx.app.tiles.TRoomGeo
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.V2
import uz.metrx.app.tiles.countLayout
import uz.metrx.app.tiles.floorLayout
import uz.metrx.app.tiles.floorStart
import uz.metrx.app.tiles.footprint
import uz.metrx.app.tiles.layRoom
import uz.metrx.app.tiles.panelScene
import uz.metrx.app.tiles.roomGeo
import uz.metrx.app.tiles.tileParts
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.editor.ModeSeg
import uz.metrx.app.ui.editor.ShotPill
import uz.metrx.app.ui.furniture.Chip
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
import kotlin.math.max
import kotlin.math.min

/*
 * A room's tiles: the room in 3D with every tile of its layouts at its true place (or its plan from above, where the
 * floor's start point is dragged and the tray and bath are marked), the layouts under it, the extras, and in the
 * advanced app what it all takes. A layout without a room shows its typed surface the same way.
 */

/** The room's 3D with its layouts' tiles, worked out away from the screen's thread. */
@Composable
fun rememberTileShell(p: Project, r: Room, base: Shell3D, snap: Boolean): Shell3D {
    val ls = p.tiles.filter { it.roomId == r.id }
    val fixes = tileRoomOf(p, r.id).fixes
    val shell by produceState(base, base, ls, fixes, p.tiles) {
        value = withContext(Dispatchers.Default) { runCatching { tileShell(r, base, snap, ls, fixes, p.tiles) }.getOrDefault(base) }
    }
    return shell
}

private fun tileShell(r: Room, base: Shell3D, snap: Boolean, ls: List<TileLayout>, fixes: List<uz.metrx.app.tiles.TFix>, all: List<TileLayout>): Shell3D {
    if (ls.isEmpty() && fixes.isEmpty()) return base
    val w0 = walls(r, snap).firstOrNull() ?: return base
    val b = base.bases[w0.id] ?: return base
    // where the plan's corner is in the scene
    val g = roomGeo(r, snap, fixes, b.ox - w0.p0.x / 1000, b.oz - w0.p0.y / 1000) ?: return base
    return base.plus(tileParts(ls, g, all), emptyList())
}

@Composable
fun TViewScreen(rt: Route.TView) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    val snap = app.settings.angleSnap
    val room = rt.rid?.let { id -> p.rooms.firstOrNull { it.id == id } }
    val panel = if (rt.rid == null) p.tiles.firstOrNull { it.id == rt.lid } else null
    if (room == null && panel == null) return
    var mode by rememberSaveable(rt) { mutableStateOf("3d") }
    val ls = if (room != null) p.tiles.filter { it.roomId == room.id } else listOfNotNull(panel)
    var sel by rememberSaveable(rt) { mutableStateOf(rt.lid ?: ls.firstOrNull()?.id) }
    val title = room?.let { r -> p.floors.firstOrNull { it.id == r.floorId }?.let { floorName(it, lang) } ?: dn(r.name, lang) } ?: tr(placeKey(panel!!))
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val viewH = maxHeight * .48f
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(title, eyebrow = dn(p.name, lang))
                if (room != null && ready3D(room, snap)) {
                    // the room itself: its sizes, doors and windows
                    GlassIconButton("edit", tr("common.edit"), { app.openRoom(p.id, room.id) })
                    Spacer(Modifier.width(8.dp))
                    ModeSeg(mode) { mode = it }
                }
            }
            Box(Modifier.fillMaxWidth().height(viewH)) {
                when {
                    room != null && !ready3D(room, snap) -> Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
                        Text(tr("tl.needMeasure"), style = ui(16f, 700, G.ink, 1.35f), textAlign = TextAlign.Center)
                        GBtn(tr("ns.measureB"), { app.openRoom(p.id, room.id) }, fill = false)
                    }
                    room != null && mode == "plan" -> RoomPlan(p, room, ls, ls.firstOrNull { it.id == sel }, snap)
                    room != null -> Room3D(p, room, snap)
                    else -> Panel3D(panel!!)
                }
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ls.forEach { l -> LayoutCard(p, l, l.id == sel) { sel = l.id } }
                if (room != null) {
                    Row(Modifier.fillMaxWidth().height(54.dp).dashedGlass(20.dp).pressable({ app.push(Route.TGallery(p.id, room.id)) }, .98f),
                        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                        MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("tl.addLayout"), style = ui(15f, 700, G.cobalt2))
                    }
                    Extras(p, room, ls)
                    if (app.settings.advanced) CountCard(rememberCount(p, room.id), tr("tl.countRoom"))
                } else if (app.settings.advanced && panel != null) {
                    // the trade's adhesive a m², as the order's count uses it
                    val glue = uz.metrx.app.tiles.glueBaseOf(app.settings.trade.glueKg)
                    val c = remember(panel, snap, glue) { countLayout(p, panel, snap, glue) }
                    CountCard(c, tr("tl.countT")) { app.sheet = Sheet.TCount(p.id, panel.id) }
                }
            }
        }
    }
}

@Composable
private fun Room3D(p: Project, r: Room, snap: Boolean) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val base = remember(r.dims, r.openings, r.poly, r.points, r.features, r.wallColor, r.floorColor, r.inner, snap) { buildShell(listOf(r), true, snap) }
    val shell = rememberTileShell(p, r, base, snap)
    val cam = remember(r.id) { Cam3D() }
    val shot = remember { Shot3D() }
    var taking by remember { mutableStateOf(false) }
    Scene3D(shell, cam, Modifier.fillMaxSize(), shot) {
        Labels3D(cam, shell.labels.map { it.p }) { i -> Lbl3D(shell.labels[i].text) }
        ShotPill("camera", tr("3d.save"), Modifier.align(Alignment.TopEnd).padding(top = 10.dp, end = 10.dp)) {
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

@Composable
private fun Panel3D(l: TileLayout) {
    val shell = remember(l) { panelScene(l) }
    val cam = remember(l.id) { Cam3D() }
    if (shell == null) { Text(tr("tl.s.panelH"), style = ui(14f, 500, G.ink2), modifier = Modifier.padding(24.dp)); return }
    Scene3D(shell, cam, Modifier.fillMaxSize())
}

/* ---------------- the plan from above ---------------- */

/** The room from above: its floor's tiles, the tray and bath, and the floor's start point to drag. */
@Composable
private fun RoomPlan(p: Project, r: Room, ls: List<TileLayout>, sel0: TileLayout?, snap: Boolean) {
    val app = LocalApp.current
    val fixes = tileRoomOf(p, r.id).fixes
    val g = remember(r, fixes, snap) { roomGeo(r, snap, fixes) } ?: return
    // the start point being dragged: the floor layout picked, or the room's first one
    val fl = sel0?.takeIf { l -> l.surfs.any { it.id == "floor" } } ?: floorLayout(ls, r.id)
    var drag by remember(fl?.id) { mutableStateOf<Pair<Int, Int>?>(null) }
    // the gesture reads the layout as it is now (a second drag starts where the first one left it)
    val flNow by androidx.compose.runtime.rememberUpdatedState(fl)
    // laid out once per change, not on every move of a drag: the dragged layout's tiles move with the finger until it lets go
    val floors = ls.filter { l -> l.surfs.any { it.id == "floor" } }
    val laid = remember(floors, g) { floors.map { l -> l to floorOnly(layRoom(l, g, null, uz.metrx.app.tiles.drawInset(l))) } }
    val tm = rememberTextMeasurer()
    val en = LocalLang.current == Lang.EN
    val trayW = tr("tl.tray"); val bathW = tr("tl.bath")
    Box(Modifier.fillMaxSize().background(Color(0xFFF6F8FC))) {
        Canvas(Modifier.fillMaxSize().pointerInput(fl?.id, g) {
            if (fl == null) return@pointerInput
            val bx = g.floor; val x0 = bx.minOf { it.x }; val y0 = bx.minOf { it.y }; val x1 = bx.maxOf { it.x }; val y1 = bx.maxOf { it.y }
            val m = 28.dp.toPx()
            val k = min((size.width - 2 * m) / (x1 - x0), (size.height - 2 * m) / (y1 - y0))
            var ox = 0.0; var oy = 0.0
            detectDragGestures(onDragStart = { val f0 = flNow ?: fl; ox = (drag?.first ?: f0.ox).toDouble(); oy = (drag?.second ?: f0.oy).toDouble() },
                onDragEnd = {
                    drag?.let { (x, y) -> app.updateLayout(p.id, fl.id) { it.copy(ox = x, oy = y) } }
                    drag = null
                }, onDragCancel = { drag = null }) { ch, d ->
                ch.consume()
                ox += d.x / k; oy += d.y / k
                drag = (Math.round(ox / 10) * 10).toInt() to (Math.round(oy / 10) * 10).toInt()
            }
        }) {
            val bx = g.floor; val x0 = bx.minOf { it.x }; val y0 = bx.minOf { it.y }; val x1 = bx.maxOf { it.x }; val y1 = bx.maxOf { it.y }
            val m = 28.dp.toPx()
            val k = min((size.width - 2 * m) / (x1 - x0), (size.height - 2 * m) / (y1 - y0)).toFloat()
            val cx = (size.width - (x1 - x0).toFloat() * k) / 2; val cy = (size.height - (y1 - y0).toFloat() * k) / 2
            fun at(q: V2) = Offset(cx + ((q.x - x0) * k).toFloat(), cy + ((q.y - y0) * k).toFloat())
            val outline = Path().apply { val o = bx.map { at(it) }; moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
            drawPath(outline, Color(0xFFE9EDF3))
            val dragged = drag?.let { (x, y) -> flNow?.let { f0 -> Offset(((x - f0.ox) * k).toFloat(), ((y - f0.oy) * k).toFloat()) } }
            laid.forEach { (l, ld) ->
                val move = if (l.id == fl?.id) dragged else null
                fun paint() = if (ld.pieces.size > uz.metrx.app.ui.tiles.MAX_DRAWN_2D) drawLaidCapped(ld, l, { _ -> { q -> at(q) } }, outline = true)
                    else drawLaid(ld, l, { _ -> { q -> at(q) } }, ld.pieces.size < 500, outline = true)
                if (move == null) paint() else clipPath(outline) { translate(move.x, move.y) { paint() } }
            }
            drawPath(outline, Color(0xFF0E1C36), style = Stroke(5.dp.toPx(), join = androidx.compose.ui.graphics.StrokeJoin.Miter))
            // doors and windows on the walls
            r.openings.forEach { o ->
                val w = g.wall(o.wall) ?: return@forEach
                val a = at(w.at(o.off.toDouble())); val b = at(w.at((o.off + o.w).toDouble()))
                if (o.type == "door") { drawLine(Color(0xFFF6F8FC), a, b, 7.dp.toPx()); drawLine(G.cobalt, a, b, 2.dp.toPx(), StrokeCap.Round) }
                else drawLine(Color(0xFF9DB8E8), a, b, 5.dp.toPx())
            }
            // the tray and the bath
            fixes.forEach { f ->
                val fp = footprint(g, f) ?: return@forEach
                val o = fp.map { at(it) }
                val path = Path().apply { moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
                drawPath(path, Color.White); drawPath(path, Color(0xFF64748B), style = Stroke(1.5.dp.toPx()))
                val c = Offset(o.sumOf { it.x.toDouble() }.toFloat() / 4, o.sumOf { it.y.toDouble() }.toFloat() / 4)
                val lay = tm.measure(if (f.type == "bath") bathW else trayW, TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color(0xFF334155)))
                drawText(lay, topLeft = Offset(c.x - lay.size.width / 2f, c.y - lay.size.height / 2f))
            }
            // the floor's start point
            val live = fl?.let { l -> drag?.let { (x, y) -> l.copy(ox = x, oy = y) } ?: l }
            if (live != null) {
                val s = at(floorStart(live, g))
                drawCircle(G.cobalt.copy(alpha = .22f), 18.dp.toPx(), s)
                drawCircle(G.cobalt, 7.dp.toPx(), s)
                drawLine(Color.White, Offset(s.x - 4.dp.toPx(), s.y), Offset(s.x + 4.dp.toPx(), s.y), 1.5.dp.toPx())
                drawLine(Color.White, Offset(s.x, s.y - 4.dp.toPx()), Offset(s.x, s.y + 4.dp.toPx()), 1.5.dp.toPx())
            }
        }
        Text(if (fl != null) tr("tl.dragStart") else tr("tl.planNoFloor"), style = ui(11.5f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomStart).padding(10.dp))
        if (fl != null && (fl.ox != 0 || fl.oy != 0)) Text(tr("tl.startReset"), style = ui(12.5f, 700, G.cobalt2), modifier = Modifier.align(Alignment.TopEnd).padding(8.dp)
            .clip(RoundedCornerShape(12.dp)).background(G.sheet(.7f)).clickable(role = Role.Button) { app.updateLayout(p.id, fl.id) { it.copy(ox = 0, oy = 0) } }.padding(horizontal = 12.dp, vertical = 8.dp))
    }
}

/** Only the floor's pieces of a laid layout (the plan shows the floor). */
private fun floorOnly(l: Laid): Laid {
    val keep = l.surfs.indices.filter { l.surfs[it].kind == "floor" }.toSet()
    return Laid(l.surfs, l.pieces.filter { it.s in keep }, l.tooMany).let { ld -> Laid(ld.surfs.mapIndexed { i, s -> if (i in keep) s else uz.metrx.app.tiles.Surf(s.key, s.kind, s.wall, emptyList(), emptyList(), s.frame, s.alt) }, ld.pieces, ld.tooMany) }
}

/* ---------------- under the picture ---------------- */

@Composable
private fun LayoutCard(p: Project, l: TileLayout, on: Boolean, onPick: () -> Unit) {
    val app = LocalApp.current
    val shape = RoundedCornerShape(20.dp)
    Column(Modifier.fillMaxWidth().clip(shape).glassCard(shape, fill = G.glass(if (on) .8f else .55f)).let { if (on) it.border(2.dp, G.cobalt, shape) else it }
        .clickable(onClick = onPick).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            LookSwatch(l.look, Modifier.size(46.dp).clip(RoundedCornerShape(10.dp)))
            Column(Modifier.weight(1f)) {
                Text(layoutTitle(l), style = ui(15.5f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(layoutSub(l) + " · " + tr("tl.lk.${l.look}") + if (l.usesSecond) " + " + tr("tl.lk.${l.look2}") else "", style = ui(12.5f, 500, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(surfText(p, l), style = ui(12f, 400, G.ink3), maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("fz.change"), { app.push(Route.TSteps(p.id, l.model, lid = l.id)) }, Btn.SECONDARY, icon = "edit", height = 42.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            if (app.settings.advanced) GBtn(tr("tl.countB"), { app.sheet = Sheet.TCount(p.id, l.id) }, Btn.SECONDARY, icon = "sliders", height = 42.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            Box(Modifier.size(42.dp).clip(CircleShape).background(G.ink.copy(alpha = .06f)).clickable(role = Role.Button, onClickLabel = tr("common.delete")) {
                val tiles = app.store.get(p.id)?.tiles ?: return@clickable
                // a second tap finds it gone: nothing more is deleted and no other page is left
                val at = tiles.indexOfFirst { it.id == l.id }; val gone = tiles.getOrNull(at) ?: return@clickable
                app.store.update(p.id) { pr -> pr.copy(tiles = pr.tiles.filter { it.id != l.id }) }
                if (l.roomId == null) app.pop()
                // Undo puts back only this layout, where it was
                app.say("tl.deleted", action = "common.undo", onAction = { app.store.update(p.id) { pr -> if (pr.tiles.any { it.id == gone.id }) pr else pr.copy(tiles = pr.tiles.putBack(gone, at)) } })
            }, contentAlignment = Alignment.Center) { MIcon("trash", G.ink2, 18.dp, 2f) }
        }
    }
}

/** What a layout covers, in words: "Pol, devor A, B (1,5 m gacha)". */
@Composable
private fun surfText(p: Project, l: TileLayout): String {
    val en = LocalLang.current == Lang.EN
    l.panel?.takeIf { l.roomId == null }?.let { pn -> return uz.metrx.app.geo.fmtLen(pn.a, uz.metrx.app.geo.LenUnit.M, en) + " × " + uz.metrx.app.geo.fmtLen(pn.b, uz.metrx.app.geo.LenUnit.M, en) + " " + tr("u.m") }
    return l.surfs.map { s ->
        when {
            s.id == "floor" -> tr("tl.pk.floor")
            s.id.startsWith("bath:") -> tr("tl.bathFront")
            s.mode == "to" -> tr("tl.wallN", "w" to s.id) + " " + tr("tl.toV", "h" to uz.metrx.app.geo.fmtLen(s.h1, uz.metrx.app.geo.LenUnit.M, en))
            s.mode == "band" -> tr("tl.wallN", "w" to s.id) + " " + uz.metrx.app.geo.fmtLen(s.h0, uz.metrx.app.geo.LenUnit.M, en) + "–" + uz.metrx.app.geo.fmtLen(s.h1, uz.metrx.app.geo.LenUnit.M, en)
            else -> tr("tl.wallN", "w" to s.id)
        } + if (s.alt) " ★" else ""
    }.joinToString(", ").ifEmpty { tr("tl.s.surfNone") }
}

/** The room's extras: skirting, corner profiles, joints in line, waterproofing, the tray and the bath. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Extras(p: Project, r: Room, ls: List<TileLayout>) {
    val app = LocalApp.current
    val floors = ls.filter { l -> l.surfs.any { it.id == "floor" } }
    val wallsL = ls.filter { l -> l.surfs.any { it.id != "floor" && !it.id.startsWith("bath:") } }
    val tr0 = tileRoomOf(p, r.id)
    val en = LocalLang.current == Lang.EN
    fun all(of: List<TileLayout>, f: (TileLayout) -> TileLayout) = app.store.update(p.id) { pr -> pr.copy(tiles = pr.tiles.map { l -> if (of.any { it.id == l.id }) f(l) else l }) }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.55f)).padding(vertical = 6.dp)) {
        Text(tr("tl.extras"), style = ui(15f, 800), modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp))
        if (floors.isNotEmpty()) {
            val on = floors.any { it.skirt > 0 }
            Sw(tr("tl.skirt"), tr("tl.skirtS"), on) { all(floors) { it.copy(skirt = if (on) 0 else 100) } }
            if (on) FlowRow(Modifier.padding(horizontal = 14.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(80, 100, 120).forEach { h -> Chip("$h mm", floors.first().skirt == h) { all(floors) { it.copy(skirt = h) } } }
            }
        }
        if (wallsL.isNotEmpty()) {
            Sw(tr("tl.prof"), tr("tl.profS"), wallsL.any { it.profiles }) { val on = wallsL.any { it.profiles }; all(wallsL) { it.copy(profiles = !on) } }
            if (floors.isNotEmpty()) Sw(tr("tl.align"), tr("tl.alignS"), wallsL.all { it.align }) { val on = wallsL.all { it.align }; all(wallsL) { it.copy(align = !on) } }
        }
        Sw(tr("tl.wp"), tr("tl.wpS", "h" to tr0.wpUp), tr0.wp) { app.updateTileRoom(p.id, r.id) { it.copy(wp = !it.wp) } }
        if (tr0.wp) {
            Text(tr("tl.showerH"), style = ui(13f, 600, G.ink2), modifier = Modifier.padding(horizontal = 14.dp))
            FlowRow(Modifier.padding(horizontal = 14.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(1800, 2000, 2200).forEach { h -> Chip(uz.metrx.app.geo.fmtLen(h, uz.metrx.app.geo.LenUnit.M, en) + " " + tr("u.m"), tr0.showerH == h) { app.updateTileRoom(p.id, r.id) { it.copy(showerH = h) } } }
            }
        }
        Hairline()
        tr0.fixes.forEach { f ->
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable { app.sheet = Sheet.TFixForm(p.id, r.id, f.id, f.type) }.padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MIcon(if (f.type == "bath") "bath" else "layers", G.ink2, 20.dp, 2f)
                Column(Modifier.weight(1f)) {
                    Text(tr(if (f.type == "bath") "tl.bath" else "tl.tray"), style = ui(14.5f, 700))
                    Text(tr("tl.wallN", "w" to f.wall) + " · ${f.w} × ${f.d} × ${f.h}", style = ui(12.5f, 400, G.ink2))
                }
                MIcon("chev", G.ink3, 16.dp, 2f)
            }
        }
        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("tl.addTray"), { app.sheet = Sheet.TFixForm(p.id, r.id, null, "tray") }, Btn.SECONDARY, icon = "plus", height = 42.dp, corner = 14.dp, fontSize = 13.5f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("tl.addBath"), { app.sheet = Sheet.TFixForm(p.id, r.id, null, "bath") }, Btn.SECONDARY, icon = "plus", height = 42.dp, corner = 14.dp, fontSize = 13.5f, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }
}

@Composable
private fun Sw(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).switchState(on).clickable(role = Role.Switch, onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(15f, 600))
            Text(sub, style = ui(12f, 400, G.ink2, 1.3f))
        }
        GSwitch(on)
    }
}
