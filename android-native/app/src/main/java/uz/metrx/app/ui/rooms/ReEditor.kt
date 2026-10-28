package uz.metrx.app.ui.rooms

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Laser
import uz.metrx.app.data.dn
import uz.metrx.app.geo.DOOR_H
import uz.metrx.app.geo.DOOR_W
import uz.metrx.app.geo.POINT_HS
import uz.metrx.app.geo.POINT_KINDS
import uz.metrx.app.geo.SILLS
import uz.metrx.app.geo.THICKS
import uz.metrx.app.geo.THRESHOLDS
import uz.metrx.app.geo.WIN_H
import uz.metrx.app.geo.WIN_W
import uz.metrx.app.geo.distsOf
import uz.metrx.app.geo.styleId
import uz.metrx.app.geo.styleOf
import uz.metrx.app.geo.thickOf
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.furniture.OptChip
import uz.metrx.app.ui.furniture.OptNote
import uz.metrx.app.ui.furniture.OptRow
import uz.metrx.app.ui.furniture.ZoomPill
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.ux.Hap
import uz.metrx.app.ui.ux.UxBar
import uz.metrx.app.ui.ux.UxTop
import kotlin.random.Random

/*
 * One room editor for every trade (room editor v2, task 5–7): the plan, the selected wall's front view or a simple
 * 3D you can tap, and under it a Canva slider whose tools follow the selection — nothing: Qo‘shish, Shakl, Balandlik,
 * Burish, O‘lchamlar, Tekshiruv, 3D (and Qo‘shimcha: the old editor's own tools); a wall: Uzunlik, Lazer, Eshik,
 * Deraza, Nuqta, Qalinlik, Burchak; a door or window: Eni, Balandligi, Tokcha, Surish, Turi, Ochilish tomoni, Nusxa,
 * O‘chirish; a point: Turi, Balandligi, Surish, O‘chirish. A tool's options take the slider's place, with ←.
 */

/** A tool of the slider: [key], name, mockup icon, a badge (Tekshiruv), red (O‘chirish), on (3D). */
private data class ETool(val key: String, val label: String, val icon: String, val badge: Int? = null, val red: Boolean = false, val on: Boolean = false, val kind: String? = null)

/** The editor's session for room [rid] of order [pid]. */
fun App.edSession(pid: String, rid: String): ReSession {
    val key = "ed:$pid:$rid"
    return ReSessions.get(key) ?: ReSession(key, store.get(pid)?.let { tradeOf(it) } ?: "build", false, pid, rid,
        { store.get(pid)?.rooms?.firstOrNull { it.id == rid } },
        { r -> store.update(pid) { p ->
            // furniture against an inner wall follows its face when the letters move (a piece deleted, the shape changed)
            val old = p.rooms.firstOrNull { it.id == rid }
            p.copy(rooms = p.rooms.map { if (it.id == rid) r else it },
                furniture = if (old != null && (old.inner.isNotEmpty() || r.inner.isNotEmpty())) uz.metrx.app.furniture.refaced(p.furniture, old, r, settings.angleSnap) else p.furniture)
        } }).also { ReSessions.put(it) }
}

@Composable
private fun tools(s: ReSession): List<ETool> {
    val app = LocalApp.current
    val r = s.room ?: return emptyList()
    val o = s.selOp; val p = s.selPt
    val pc = s.selPieceOnly
    return when {
        s.sel == null -> listOf(ETool("add", tr("re.t.add"), "plus"), ETool("inner", tr("iw.add"), "iw"), ETool("shape", tr("re.t.shape"), "shape"), ETool("rh", tr("re.t.rh"), "height"),
            ETool("rot", tr("re.t.rot"), "rotate"), ETool("dims", tr("re.t.dims"), "ruler"), ETool("checks", tr("re.t.checks"), "warn", badge = app.issuesOf(r).size),
            ETool("v3d", "3D", "cube", on = s.view == "3d")) + (if (s.trade == "furniture") listOf(ETool("fplace", tr("fp.pl.title"), "sofa")) else emptyList()) + ETool("more", tr("re.t.more"), "list")
        // an inner wall: Uzunlik, Qalinlik, Balandlik (a half wall), O‘tish (an arch), Shakli (a column) or 90° burish and Yuzalar, Nusxa, O‘chirish
        pc != null -> listOfNotNull(ETool("iwLen", tr(if (pc.k == "col") "iw.t.size" else "re.t.len"), "ruler"),
            if (pc.k != "col") ETool("iwTh", tr("iw.th"), "thick") else null, if (pc.k == "half") ETool("iwH", tr("re.t.rh"), "height") else null,
            if (pc.k == "arch") ETool("iwOp", tr("iw.t.op"), "width") else null, if (pc.k == "col") ETool("iwShape", tr("iw.shape"), "shape") else null,
            if (pc.k != "col") ETool("iwRot", tr("iw.t.rot90"), "rotate") else null, if (pc.k != "col") ETool("iwFace", tr("iw.faces"), "room") else null,
            ETool("iwCopy", tr("re.t.copy"), "copy"), ETool("iwDel", tr("re.t.del"), "trash", red = true))
        // an inner wall's face: like a wall, its thickness is the piece's; "Butun devor" selects the piece
        s.selWall != null && app.isInner(r, s.selWall!!) -> listOf(ETool("addDoor", tr("re.k.door"), "door", kind = "door"), ETool("addWin", tr("re.k.window"), "window", kind = "window"),
            ETool("pt", tr("re.t.pt"), "point"), ETool("iwTh", tr("iw.th"), "thick"), ETool("iwOf", tr("iw.whole"), "iw"))
        s.selWall != null -> listOf(ETool("len", tr("re.t.len"), "ruler"), ETool("laser", tr("re.laser"), "laser"), ETool("addDoor", tr("re.k.door"), "door", kind = "door"),
            ETool("addWin", tr("re.k.window"), "window", kind = "window"), ETool("pt", tr("re.t.pt"), "point"), ETool("thick", tr("re.t.thick"), "thick"), ETool("corner", tr("re.t.corner"), "corner"))
        o != null -> listOfNotNull(ETool("w", tr("re.f.w"), "width"), ETool("h", tr("re.t.h"), "height"),
            if (styleId(o) != "pano" && styleId(o) != "balcony") ETool("sill", tr("re.f.sill"), "sill") else null,
            ETool("move", tr("re.t.move"), "move"), ETool("type", tr("re.t.type"), "grid"), if (styleId(o) != "arch") ETool("swing", tr("re.t.swing"), "hinge") else null,
            ETool("copy", tr("re.t.copy"), "copy"), ETool("del", tr("re.t.del"), "trash", red = true))
        p != null -> listOf(ETool("ptype", tr("re.t.type"), "grid"), ETool("ph", tr("re.t.h"), "height"), ETool("move", tr("re.t.move"), "move"), ETool("del", tr("re.t.del"), "trash", red = true))
        else -> emptyList()
    }
}

@Composable
private fun ToolBtn(t: ETool, onClick: () -> Unit) {
    val fg = when { t.red -> G.err; t.on -> G.cobalt2; else -> G.ink }
    Box(Modifier.width(70.dp).heightIn(min = 62.dp).clip(RoundedCornerShape(16.dp)).background(if (t.on) G.cobalt.copy(alpha = .12f) else Color.Transparent)
        .semantics { contentDescription = t.label; selected = t.on }.clickable(role = Role.Button, onClick = onClick).padding(vertical = 6.dp, horizontal = 2.dp),
        contentAlignment = Alignment.TopCenter) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (t.kind != null) KindIcon(t.kind, 24.dp) else ReIcon(t.icon, if (t.red) G.err else if (t.on) G.cobalt2 else G.ink2, 24.dp)
            Text(t.label, style = ui(11f, 700, fg, 1.1f), textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 66.dp))
        }
        if (t.badge != null) Box(Modifier.align(Alignment.TopEnd).padding(end = 12.dp).size(18.dp).clip(CircleShape).background(if (t.badge > 0) RP.issue else G.green),
            contentAlignment = Alignment.Center) { Text(if (t.badge > 0) "${t.badge}" else "✓", style = ui(10.5f, 800, Color.White)) }
    }
}

@Composable
private fun IconChip(label: String, icon: String?, on: Boolean = false, red: Boolean = false, onClick: () -> Unit) {
    val fg = when { red -> RP.issue; on -> G.cobalt2; else -> G.ink }
    Row(Modifier.padding(horizontal = 2.dp).heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp)).background(if (on) G.cobalt.copy(alpha = .12f) else chipBg)
        .border(if (on || red) 2.dp else 0.dp, if (on) G.cobalt else if (red) RP.issue else Color.Transparent, RoundedCornerShape(14.dp))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        if (icon != null) ReIcon(icon, fg, 19.dp)
        Text(label, style = ui(13f, 700, fg, 1.15f), maxLines = 2, modifier = Modifier.widthIn(max = 220.dp))
    }
}

/** The room's main next step in its trade: the furniture gallery, the tiles, the wiring, the pipes, the products, the estimate. */
private fun App.edMain(pid: String, rid: String) {
    val p = store.get(pid) ?: return
    haptic(Hap.TICK)
    when (tradeOf(p)) {
        "furniture" -> push(Route.FGallery(pid, rid))
        "tiler" -> push(if (p.tiles.any { it.roomId == rid }) Route.TView(pid, rid) else Route.TGallery(pid, rid))
        "elec" -> push(Route.EView(pid, rid))
        "plumb" -> push(Route.PView(pid, rid))
        "win" -> push(Route.WView(pid, rid))
        else -> { popTo { it is Route.Project && it.id == pid }; if (top is Route.Project) setProjectTab("estimate") else push(Route.Project(pid, "estimate")) }
    }
}

/** Lazer on the selected wall: its reading becomes the wall's length (an automatic wall only compares). */
private fun App.wallLaser(s: ReSession, scope: kotlinx.coroutines.CoroutineScope) {
    val id = s.selWall ?: return
    val r = s.room ?: return
    val L = wallL(r, id)
    val take = { mm: Int ->
        val rr = s.room
        if (rr != null && !wallEditable(rr, id)) { haptic(Hap.CONFIRM); toast = uz.metrx.app.ui.components.ToastMsg(t("re.laserAuto", "v" to mm(mm), "l" to mm(L), "d" to mm(kotlin.math.abs(mm - L)))) }
        else setWallLen(s, id, mm, t("re.laserPre"))
    }
    if (laser.isReal) { laser.await { take(it) }; return }
    // no laser (made-up values only with the debug simulator): the radar
    if (!laser.simOn) { push(Route.LaserRadar); return }
    val rd = settings.readings.lastOrNull { it.used == null && it.src != "manual" }
    if (rd != null) { settings.markReadingUsed(rd.id, t("re.wall", "w" to id)); take(rd.mm); return }
    take(L + Random.nextInt(-12, 13))
}

@Composable
fun RoomEditorScreen(pid: String, rid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: return
    val s = app.edSession(pid, rid)
    val r = s.room ?: return
    val geo = remember { ReGeo() }
    val scope = rememberCoroutineScope()
    var rootOrigin by remember { mutableStateOf(Offset.Zero) }
    var capH by remember { mutableStateOf(0f) }
    val lang = app.settings.lang
    BackHandler {
        when {
            s.kp != null -> s.kp = null
            s.iwWin -> s.iwWin = false
            s.pk != null -> s.pk = null
            s.strip != null -> s.strip = null
            s.sel != null || s.arm != null -> deselect(s)
            else -> app.pop()
        }
    }
    // a real laser reading while a wall is selected measures it
    if (s.selWall != null && s.pk == null && s.kp == null) uz.metrx.app.laser.LaserSink { mm -> s.selWall?.let { app.setWallLen(s, it, mm, app.t("re.laserPre")) }; true }
    Box(Modifier.fillMaxSize().onGloballyPositioned { rootOrigin = it.positionInRoot() }) {
        Column(Modifier.fillMaxSize()) {
            UxTop(dn(r.name, lang), { app.pop() }, eyebrow = dn(p.customer, lang).ifBlank { dn(p.name, lang) } + " · " + tr("sd.tr." + tradeOf(p)), right = {
                if (s.view == "3d") Text("3D", style = ui(13f, 700, G.ink3), modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp))
                else Row(Modifier.clip(RoundedCornerShape(14.dp)).background(chipBg).padding(3.dp)) {
                    listOf("plan" to tr("re.plan"), "front" to tr("re.wall", "w" to s.fw)).forEach { (k, l) ->
                        val on = s.view == k
                        Text(l, style = ui(13f, 700, if (on) G.ink else G.ink2), maxLines = 1, modifier = Modifier.heightIn(min = 38.dp).clip(RoundedCornerShape(11.dp))
                            .background(if (on) G.solid else Color.Transparent).clickable(role = Role.Tab) { s.view = k; s.last2d = k; app.haptic(Hap.TICK) }.padding(horizontal = 11.dp, vertical = 9.dp))
                    }
                }
            })
            Box(Modifier.weight(1f).fillMaxWidth()) {
                val d = LocalDensity.current
                ReCanvas(s, geo, Modifier.fillMaxSize(), top = capH + 12 * d.density, overlay = {
                    val z = s.zooms[s.view]!!
                    if (z.moved) ZoomPill(z.z, if (s.view == "front") 56.dp else 10.dp) { z.reset() }
                    if (s.view == "front") Row(Modifier.align(Alignment.BottomCenter).padding(bottom = 8.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        reAll(r, app.reSnap()).forEach { w ->
                            val on = w.id == s.fw
                            Text(w.id, style = ui(13f, 800, if (on) Color.White else G.ink), textAlign = TextAlign.Center, modifier = Modifier.widthIn(min = 44.dp).heightIn(min = 40.dp)
                                .clip(RoundedCornerShape(13.dp)).background(if (on) G.cobalt else G.solid).border(1.dp, G.rim, RoundedCornerShape(13.dp))
                                .clickable(role = Role.Button) { s.fw = w.id; s.zooms["front"]!!.reset(); if (s.selWall != null) s.sel = ReSel.Wall(w.id) }.padding(vertical = 10.dp))
                        }
                    }
                    if (s.view == "3d") Row(Modifier.align(Alignment.BottomCenter).padding(start = 12.dp, end = 12.dp, bottom = 10.dp).clip(RoundedCornerShape(15.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(15.dp))
                        .padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        ReIcon("info", G.cobalt, 16.dp); Text(tr("re.isoHint"), style = ui(12f, 700, G.ink2, 1.25f), maxLines = 2, modifier = Modifier.weight(1f, false))
                    }
                    val arm = s.arm
                    if (arm != null) Row(Modifier.align(Alignment.BottomCenter).padding(start = 10.dp, end = 10.dp, bottom = if (s.view == "front") 56.dp else 8.dp).fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp)).background(G.cobalt).padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        KindIcon(arm, 18.dp, Color.White)
                        Text(tr("re.armBar", "n" to app.kindName(arm)), style = ui(12.5f, 700, Color.White), modifier = Modifier.weight(1f))
                        Box(Modifier.size(34.dp).clip(CircleShape).background(Color.White.copy(alpha = .2f)).clickable(role = Role.Button) { s.arm = null }, contentAlignment = Alignment.Center) {
                            ReIcon("close", Color.White, 16.dp)
                        }
                    }
                })
                Caption(s, Modifier.align(Alignment.TopStart).padding(start = 10.dp, end = 10.dp, top = 6.dp).onSizeChanged { capH = it.height.toFloat() })
            }
            Column(Modifier.fillMaxWidth().then(uz.metrx.app.ui.ux.barSpotModifier()).background(G.sheet(.97f))) {
                val st = s.strip
                if (st == null) Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 6.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    tools(s).forEach { t -> ToolBtn(t) { onTool(app, s, t.key, scope) } }
                } else Options(s, st, geo, scope)
            }
            UxBar(tr("re.main." + tradeOf(p)), null, { app.edMain(pid, rid) }, { s.undo(app) }, s.canUndo, { s.redo(app) }, s.canRedo, seg = {
                uz.metrx.app.ui.ux.Seg2D3D(s.view == "3d") { d3 -> s.view = if (d3) "3d" else s.last2d; app.haptic(Hap.TICK) }
            })
        }
        GhostTag(s, rootOrigin)
        PickWindow(s)
        IwWindow(s)
        KeypadOverlay(s)
    }
}

/** The caption over the canvas: the room, the selected wall, or the selected item (with ✕). */
@Composable
private fun Caption(s: ReSession, modifier: Modifier) {
    val app = LocalApp.current
    val r = s.room ?: return
    if (s.arm != null) { Box(modifier); return }
    val o = s.selOp; val p = s.selPt; val w = s.selWall; val pc = s.selPieceOnly
    val (b, sub) = when {
        pc != null -> (app.iwName(pc.k) + if (s.ghostId == pc.id) " · " + app.t("iw.new") else "") to app.iwSize(r, pc)
        w != null && app.isInner(r, w) -> tr("re.wallCap", "w" to app.wLab(r, w), "l" to mm(app.wallL(r, w))) to tr("re.wallCapSub", "t" to (s.selPiece?.th ?: 100), "n" to (r.openings.count { it.wall == w } + r.points.count { it.wall == w }))
        o != null -> { val d = distsOf(o, app.wallL(r, o.wall)); (app.kindName(o.type) + " · " + app.styleName(o.type, styleId(o))) to
            (app.sizeLine(o) + " · " + o.wall + " · " + mm(d.left) + " | " + mm(d.right)) }
        p != null -> { val d = distsOf(p, app.wallL(r, p.wall)); (app.kindName(p.t) + " · " + app.styleName(p.t, styleId(p))) to (app.sizeLine(p) + " · " + p.wall + " · " + mm(d.left) + " | " + mm(d.right)) }
        w != null -> tr("re.wallCap", "w" to w, "l" to mm(app.wallL(r, w))) to tr("re.wallCapSub", "t" to thickOf(r, w), "n" to (r.openings.count { it.wall == w } + r.points.count { it.wall == w }))
        else -> uz.metrx.app.data.dn(r.name, app.settings.lang) to (app.t(shapeKey(shapeIdOf(r))) + " · " + app.areaLine(r).substringBefore(" ·") + " · h " + mm(roomH(r)))
    }
    Row(modifier.heightIn(min = 34.dp).clip(RoundedCornerShape(18.dp)).background(G.solid).border(1.dp, G.rim, RoundedCornerShape(18.dp))
        .padding(start = 12.dp, end = if (s.sel != null) 4.dp else 12.dp, top = 3.dp, bottom = 3.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(b, style = ui(13f, 800), maxLines = 1)
        Text(sub, style = ui(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, false))
        if (s.sel != null) Box(Modifier.size(30.dp).clip(CircleShape).background(chipBg).clickable(role = Role.Button) { deselect(s) }.semantics { contentDescription = app.t("re.desel") },
            contentAlignment = Alignment.Center) { ReIcon("close", G.ink, 15.dp) }
    }
}

private fun onTool(app: App, s: ReSession, k: String, scope: kotlinx.coroutines.CoroutineScope) {
    val r = s.room ?: return
    app.haptic(Hap.TICK)
    when (k) {
        "v3d" -> s.view = if (s.view == "3d") s.last2d else "3d"
        "laser" -> app.wallLaser(s, scope)
        "addDoor", "addWin" -> { val w = s.selWall ?: return; app.placeAt(s, if (k == "addDoor") "door" else "window", w, app.wallL(r, w) / 2.0, "chip") }
        "copy" -> app.dupSel(s)
        "del" -> app.delSel(s)
        "inner" -> { s.iwWin = true; s.arm = null }
        "fplace" -> s.rid?.let { app.push(Route.FArrange(s.pid, it)) }
        "iwLen" -> app.openKp(s, "iwLen")
        "iwRot" -> app.iwRotate(s)
        "iwCopy" -> app.iwCopy(s)
        "iwDel" -> app.iwDel(s)
        "iwOf" -> s.selPiece?.let { selectPiece(app, s, it.id) }
        "type", "ptype" -> app.pkOpenFor(s, "retype")
        else -> { s.strip = k; s.arm = null }
    }
}

@Composable
private fun Options(s: ReSession, k: String, geo: ReGeo, scope: kotlinx.coroutines.CoroutineScope) {
    val app = LocalApp.current
    val r = s.room ?: return
    val o = s.selOp; val p = s.selPt; val w = s.selWall
    val back = { s.strip = null; s.arm = null }
    fun row(title: String, sub: String, content: @Composable RowScope.() -> Unit) = @Composable { OptRow(title, sub, back, key = k, content = content) }
    val content: @Composable () -> Unit = when (k) {
        "add" -> { { IconOpts(tr("re.t.add"), tr("re.iconsSub"), back) { IconRow(s, geo, modifier = Modifier.weight(1f), iw = true) } } }
        "iwTh", "iwH", "iwOp", "iwShape", "iwFace" -> { { PieceOptions(s, k, back) } }
        "pt" -> { { IconOpts(tr("re.t.pt"), tr("re.ptSub", "w" to (w ?: "")), back) { IconRow(s, geo, only = POINT_KINDS, modifier = Modifier.weight(1f)) } } }
        "shape" -> row(tr("re.t.shape"), tr("re.shapeNow", "n" to app.t(shapeKey(shapeIdOf(r))))) {
            SHAPES.forEach { sh ->
                val on = shapeIdOf(r) == sh
                Row(Modifier.padding(horizontal = 2.dp).heightIn(min = 52.dp).clip(RoundedCornerShape(14.dp)).background(if (on) G.cobalt.copy(alpha = .12f) else chipBg)
                    .border(if (on) 2.dp else 0.dp, if (on) G.cobalt else Color.Transparent, RoundedCornerShape(14.dp)).clickable(role = Role.Button) { app.changeShape(s, sh) }
                    .padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    Box(Modifier.size(40.dp, 28.dp).clip(RoundedCornerShape(7.dp)).background(RP.paper)) { ShapeThumb(sh, false, 0, on, Modifier.fillMaxSize()) }
                    Text(tr("rsh.s.$sh"), style = ui(13f, 700, if (on) G.cobalt2 else G.ink), maxLines = 1)
                }
            }
        }
        "rh" -> row(tr("re.t.rh"), tr("re.rhSub", "v" to mm(roomH(r)))) {
            roomHeights(r).forEach { v -> OptChip(mm(v), roomH(r) == v) { app.setRoomH(s, v) } }
            IconChip(tr("re.type"), "kbd") { app.openKp(s, "rh") }
        }
        "rot" -> row(tr("re.t.rot"), tr("re.rotSub")) {
            IconChip(tr("re.rot90L"), "rotL") { app.rotateRoom(s, -1) }
            IconChip(tr("re.rot90R"), "rotate") { app.rotateRoom(s, 1) }
            IconChip(tr("re.mirror"), "mirror") { app.mirrorIt(s) }
        }
        "dims" -> row(tr("re.t.dims"), tr("re.dimsSub")) {
            IconChip(tr("re.dimLen"), "ruler", s.dLen) { s.dLen = !s.dLen }
            IconChip(tr("re.dimChain"), "width", s.dChain) { s.dChain = !s.dChain }
            IconChip(tr("re.dimArea"), "shape", s.dArea) { s.dArea = !s.dArea }
        }
        "checks" -> { val q = app.issuesOf(r)
            row(tr("re.t.checks"), if (q.isEmpty()) tr("re.checksOk") else tr("re.checksN", "n" to q.size)) {
                if (q.isEmpty()) Row(Modifier.padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    ReIcon("chk", G.green, 19.dp); Text(tr("re.noIssues"), style = ui(13f, 700, G.green)) }
                else q.forEach { x -> IconChip(app.issueText(x), "warn", red = true) { if (s.view == "3d") s.view = "plan"; s.strip = null; selectItem(app, s, x.id) } }
            } }
        "more" -> row(tr("re.t.more"), tr("re.moreSub")) {
            val pid = s.pid; val rid = s.rid ?: return@row
            IconChip(tr("re.m.feat"), "shape") { app.sheet = Sheet.FeatureForm(pid, rid, null) }
            IconChip(tr("re.m.tray"), "laser") { app.sheet = Sheet.Tray(pid, rid) }
            IconChip(tr("re.m.walls"), "eye") { app.push(Route.WallView(pid, rid, s.fw)) }
            IconChip(tr("re.m.real3d"), "cube") { app.push(Route.Editor(pid, rid, "3d")) }
            IconChip(tr("re.m.info"), "info") { app.sheet = Sheet.RoomInfo(pid, rid) }
            IconChip(tr("re.m.old"), "room") { app.push(Route.Editor(pid, rid, "old")) }
        }
        "len" -> { val id = w ?: return; val L = app.wallL(r, id)
            if (app.wallEditable(r, id)) row(tr("re.t.len"), tr("re.lenSub", "w" to id, "v" to mm(L))) {
                listOf(-100, -10).forEach { dv -> OptChip((if (dv < 0) "−" else "+") + kotlin.math.abs(dv), false) { app.setWallLen(s, id, L + dv) } }
                Text(mm(L) + " mm", style = ui(13.5f, 800, G.cobalt2), modifier = Modifier.padding(horizontal = 10.dp))
                listOf(10, 100).forEach { dv -> OptChip("+$dv", false) { app.setWallLen(s, id, L + dv) } }
                IconChip(tr("re.type"), "kbd") { app.openKp(s, "wl") }
            } else row(tr("re.t.len"), tr("re.lenAuto", "w" to id, "v" to mm(L))) { OptNote(tr("re.lenAutoNote")) } }
        "thick" -> { val id = w ?: return
            row(tr("re.t.thick"), tr("re.thickSub", "w" to id, "v" to thickOf(r, id))) {
                THICKS.forEach { v -> OptChip("$v mm", thickOf(r, id) == v) { app.setThick(s, id, v) } }
                IconChip(tr("re.type"), "kbd") { app.openKp(s, "thick") }
            } }
        "corner" -> { val id = w ?: return; val ws = reWalls(r, app.reSnap()); val i = ws.indexOfFirst { it.id == id }; val n = ws.size
            row(tr("re.t.corner"), tr("re.cornerSub", "w" to id)) {
                if (i >= 0) {
                    Text(tr("re.cornerWith", "w" to ws[(i - 1 + n) % n].id, "a" to cornerAngle(ws, i)), style = ui(13f, 700), modifier = Modifier.padding(horizontal = 8.dp))
                    Text(tr("re.cornerWith", "w" to ws[(i + 1) % n].id, "a" to cornerAngle(ws, (i + 1) % n)), style = ui(13f, 700), modifier = Modifier.padding(horizontal = 8.dp))
                }
                IconChip(tr("re.diagBtn"), "ruler") { app.openKp(s, "diag") }
                OptNote(tr("re.cornerNote"))
            } }
        "w" -> { val oo = o ?: return; val cw = styleOf(oo.type, styleId(oo)).cw ?: if (oo.type == "door") DOOR_W else WIN_W
            row(tr("re.f.w"), tr("re.wSub", "n" to app.kindName(oo.type), "v" to mm(oo.w))) {
                cw.forEach { v -> OptChip(mm(v), oo.w == v) { app.setW(s, v) } }; IconChip(tr("re.type"), "kbd") { app.openKp(s, "w") }
            } }
        "h" -> { if (o != null) row(tr("re.t.h"), tr("re.hSub", "n" to app.kindName(o.type), "v" to mm(o.h))) {
                (if (o.type == "door" || styleId(o) == "balcony") DOOR_H else WIN_H).forEach { v -> OptChip(mm(v), o.h == v) { app.setH(s, v) } }; IconChip(tr("re.type"), "kbd") { app.openKp(s, "h") }
            } else if (p != null) row(tr("re.t.h"), tr("re.phSub", "n" to app.kindName(p.t), "v" to mm(p.h))) {
                (POINT_HS[p.t] ?: emptyList()).sorted().forEach { v -> OptChip(mm(v), p.h == v) { app.setPh(s, v) } }; IconChip(tr("re.type"), "kbd") { app.openKp(s, "ph") }
            } else return }
        "ph" -> { val pp = p ?: return
            row(tr("re.t.h"), tr("re.phSub", "n" to app.kindName(pp.t), "v" to mm(pp.h))) {
                (POINT_HS[pp.t] ?: emptyList()).sorted().forEach { v -> OptChip(mm(v), pp.h == v) { app.setPh(s, v) } }; IconChip(tr("re.type"), "kbd") { app.openKp(s, "ph") }
            } }
        "sill" -> { val oo = o ?: return
            if (oo.type == "window") row(tr("re.f.sill"), tr("re.sillSub", "v" to mm(oo.sill))) {
                SILLS.forEach { v -> OptChip(mm(v), oo.sill == v) { app.setSill(s, v) } }; IconChip(tr("re.type"), "kbd") { app.openKp(s, "sill") }
            } else row(tr("re.thrT"), tr("re.thrSub", "v" to oo.thr)) {
                THRESHOLDS.forEach { v -> OptChip("$v mm", oo.thr == v) { if (oo.thr != v) app.setOp(s, app.t("re.thrCh", "v" to v)) { it.copy(thr = v) } } }
            } }
        "move" -> { val wall = o?.wall ?: p?.wall ?: return; val L = app.wallL(r, wall); val d = if (o != null) distsOf(o, L) else distsOf(p!!, L)
            row(tr("re.t.move"), tr("re.moveSub", "a" to mm(d.left), "b" to mm(d.right))) {
                IconChip("100", "left") { app.moveSel(s, "-100") }; IconChip("10", "left") { app.moveSel(s, "-10") }
                IconChip("10", "right") { app.moveSel(s, "10") }; IconChip("100", "right") { app.moveSel(s, "100") }
                Box(Modifier.width(1.dp).height(34.dp).background(G.ink.copy(alpha = .1f)))
                OptChip(tr("re.mvS"), false) { app.moveSel(s, "s") }; OptChip(tr("re.mvC"), false) { app.moveSel(s, "c") }; OptChip(tr("re.mvE"), false) { app.moveSel(s, "e") }
            } }
        "swing" -> { val oo = o ?: return
            val opts = if (oo.type == "door") listOf("inL", "inR", "outL", "outR") else listOf("L", "R", "T")
            val cur = oo.sw.ifEmpty { if (oo.type == "door") "inL" else "L" }
            row(tr("re.t.swing"), tr("re.swingSub")) {
                opts.forEach { x -> IconChip(tr("re.sw.$x"), "hinge", cur == x) { if (cur != x) app.setOp(s, app.t("re.swCh", "n" to app.kindName(oo.type), "v" to app.t("re.sw.$x").lowercase())) { it.copy(sw = x) } } }
            } }
        else -> { {} }
    }
    content()
}

/** An option row whose content scrolls by itself (the icon row): the title, ← and the icons. */
@Composable
private fun IconOpts(title: String, sub: String, onBack: () -> Unit, content: @Composable RowScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 4.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = ui(14f, 800), maxLines = 1)
            Text(sub, style = ui(12f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        }
        Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.padding(start = 6.dp).size(48.dp).clip(CircleShape).background(chipBg).semantics { contentDescription = "←" }
                .clickable(role = Role.Button, onClick = onBack), contentAlignment = Alignment.Center) { ReIcon("back", G.ink, 22.dp, 2.2f) }
            content()
        }
    }
}
