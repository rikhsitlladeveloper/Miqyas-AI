package uz.metrx.app.ui.editor

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.fmtArea
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.geo.wallCorner
import uz.metrx.app.geo.wallStats
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.LaserButton
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.glass.glassBlur
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/** The blueprint grid behind the room page (glass.css .page.gs-room: 23 px lines, offset 8). */
fun Modifier.roomGrid(): Modifier = drawBehind {
    val step = 23.dp.toPx(); val o = 8.dp.toPx(); val c = G.cobalt.copy(alpha = if (Theme.dark) .10f else .06f)
    var x = o; while (x < size.width) { drawLine(c, Offset(x, 0f), Offset(x, size.height), 1.dp.toPx()); x += step }
    var y = o; while (y < size.height) { drawLine(c, Offset(0f, y), Offset(size.width, y), 1.dp.toPx()); y += step }
}

/** The room editor (prototype editor.js "ed2" page with the glass room look). */
@Composable
fun EditorScreen(r0: Route.Editor) {
    if (r0.mode == "3d") { Room3DScreen(r0); return }
    val app = LocalApp.current
    val lang = LocalLang.current
    val ops = app.ops
    val p = app.store.get(r0.pid) ?: return
    val r = p.rooms.firstOrNull { it.id == r0.rid } ?: return
    val w = p.floors.firstOrNull { it.id == r.floorId }
    val unit = app.settings.unit; val en = app.english()
    @Suppress("UNUSED_VARIABLE") val tick = ops.histTick
    val f = ops.focusOf(r)
    val sel = (app.sheet as? Sheet.Measure)?.k ?: f.k
    val selOp = (app.sheet as? Sheet.OpeningForm)?.oid
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(dn(r.name, lang), style = ui(20f, 800, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(dn(p.name, lang) + (if (w != null) " › " + floorName(w, lang) else ""), style = ui(12f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Box(Modifier.size(44.dp)) { LaserButton { app.sheet = Sheet.Device } }
                GlassIconButton("more", "menu", { app.sheet = Sheet.RoomInfo(p.id, r.id) })
            }
            Box(Modifier.weight(1f).fillMaxWidth()) {
                if (r.isPoly) PolyPlan(r, sel, selOp, Modifier.fillMaxSize())
                else RectPlan(
                    r, sel, selOp, unit, en, dn(r.name, lang),
                    issueOf = { o -> ops.issue(r, o) != null },
                    onWall = { wl -> ops.select(p.id, r.id, wl) },
                    onOpening = { id -> app.sheet = Sheet.OpeningForm(p.id, r.id, id) },
                    onDragEnd = { o, off -> ops.moveOpening(p.id, r.id, o, off, o.sill) },
                    tipText = { o, off -> app.t("wv.off", "c" to wallCorner(r, o.wall), "v" to fmtLen(off, unit, en) + " " + app.unitName()) },
                    modifier = Modifier.fillMaxSize().padding(bottom = 60.dp)
                )
                // the readings tray (bottom left) and undo / redo (bottom right) float over the plan
                GlassPill(Modifier.align(Alignment.BottomStart).padding(start = 12.dp, bottom = 12.dp)) {
                    Row(Modifier.clickable(role = Role.Button) { app.sheet = Sheet.Tray(p.id, r.id) }.padding(start = 14.dp, end = 8.dp).fillMaxHeight(),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        MIcon("laser", G.cobalt, 20.dp, 2f)
                        Text(tr("tr.btn"), style = ui(15f, 700))
                        Text(app.settings.readings.count { it.used == null }.toString(), style = ui(13f, 800, Color.White), modifier = Modifier.clip(RoundedCornerShape(13.dp)).background(G.cobalt).padding(horizontal = 9.dp, vertical = 4.dp))
                    }
                }
                GlassPill(Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = 12.dp)) {
                    Row(Modifier.padding(horizontal = 4.dp).fillMaxHeight(), verticalAlignment = Alignment.CenterVertically) {
                        HistBtn("undo", ops.canUndo(r.id)) { ops.undo(p.id, r.id) }
                        Box(Modifier.width(1.dp).height(20.dp).background(G.ink.copy(alpha = .12f)))
                        HistBtn("redo", ops.canRedo(r.id)) { ops.redo(p.id, r.id) }
                    }
                }
            }
            StepPanel(p.id, r, f)
            Tools(p.id, r)
        }
        if (!ops.tipSeen && !app.settings.editorTipOff && app.sheet == null) EditorTip()
    }
}

@Composable
private fun GlassPill(modifier: Modifier, content: @Composable () -> Unit) {
    val haze = LocalHaze.current
    val shape = RoundedCornerShape(22.dp)
    Box(modifier.height(44.dp).dropShadow(shape, Shadow(20.dp, G.shade.copy(alpha = .12f), offset = DpOffset(0.dp, 8.dp)))
        .clip(shape).glassBlur(haze, G.sheet(.55f), 22.dp).topHighlight(1f, 1.dp).border(1.dp, G.rim, shape)) { content() }
}

@Composable
private fun HistBtn(icon: String, on: Boolean, onClick: () -> Unit) {
    Box(Modifier.size(44.dp, 42.dp).clickable(enabled = on, role = Role.Button, onClick = onClick), contentAlignment = Alignment.Center) {
        MIcon(icon, if (on) G.ink else OFF_ICON, 20.dp, 2f)
    }
}

/* ---------------- the bottom panel: the step card, and the full list when opened ---------------- */

@Composable
private fun StepPanel(pid: String, r: Room, f: RoomOps.Focus) {
    val app = LocalApp.current
    val ops = app.ops
    val haze = LocalHaze.current
    val shape = RoundedCornerShape(30.dp)
    var drag by remember { mutableFloatStateOf(0f) }
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        Column(
            Modifier.padding(start = 12.dp, end = 12.dp, bottom = 10.dp).fillMaxWidth()
                .dropShadow(shape, Shadow(30.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, (-10).dp)))
                .clip(shape).glassBlur(haze, G.sheet(.55f), 28.dp).topHighlight(.95f).border(1.dp, G.rim, shape)
                .animateContentSize(tween(280))
        ) {
            // the grab handle: tap to open or close, or pull
            Box(
                Modifier.fillMaxWidth().height(30.dp).clickable(role = Role.Button) { ops.panelOpen = !ops.panelOpen }
                    .pointerInput(Unit) {
                        detectVerticalDragGestures(onDragEnd = {
                            if (drag < -56f) ops.panelOpen = true else if (drag > 56f) ops.panelOpen = false
                            drag = 0f
                        }) { _, dy -> drag += dy }
                    },
                contentAlignment = Alignment.Center
            ) { Box(Modifier.size(48.dp, 5.dp).clip(RoundedCornerShape(3.dp)).background(if (Theme.dark) Color(0xFF3A4256) else Color(0xFFC3CAD8))) }
            Column(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 14.dp)) {
                if (r.isPoly) PolyHint(pid, r)
                StepCard(pid, r, f)
                if (ops.panelOpen) {
                    Column(Modifier.heightIn(max = 380.dp).verticalScroll(rememberScrollState()).padding(top = 12.dp)) {
                        Hairline()
                        FullList(pid, r, f)
                    }
                }
            }
        }
    }
}

@Composable
private fun StepCard(pid: String, r: Room, f: RoomOps.Focus) {
    val app = LocalApp.current
    val ops = app.ops
    val unit = app.settings.unit; val en = app.english()
    val m = app.unitName()
    val k = f.k
    val keys = stepKeys(r, app.settings.angleSnap)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        when (f.kind) {
            "ok" -> {
                val a = areas(r, app.settings.angleSnap)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(42.dp).clip(CircleShape).background(G.green.copy(alpha = .14f)), contentAlignment = Alignment.Center) { MIcon("check", OK_GREEN, 22.dp, 2.4f) }
                    Column(Modifier.weight(1f)) {
                        Text(tr("ed2.done"), style = ui(16f, 800), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (a != null) Text(if (a.net != null) tr("ed2.sum", "f" to fmtArea(a.floor, en), "w" to fmtArea(a.net, en)) else tr("ed2.sumNoH", "f" to fmtArea(a.floor, en)), style = ui(12.5f, 400, G.ink2))
                    }
                    AllPill()
                }
                // a furniture order's room is ready: the next step is its kitchen or wardrobe, for this room
                val pr = app.store.get(pid)
                val addFurn = pr?.isFurniture == true && pr.furniture.none { it.roomId == r.id || it.ws == r.floorId }
                // measured for a room-less piece: it goes in now
                val waiting = app.placeAfter?.takeIf { it.first == r.id }?.let { pa -> pr?.furniture?.firstOrNull { it.id == pa.second && it.roomId == null } }
                if (pr != null && waiting != null) {
                    uz.metrx.app.ui.components.GBtn(tr("fz.placeN", "n" to uz.metrx.app.data.dn(waiting.name, app.settings.lang)), {
                        app.placeAfter = null; app.replaceTop(Route.FPlace(pid, waiting.id, r.id))
                    }, icon = if (waiting.kind == "kitchen") "kitchen" else "board", height = 50.dp, fontSize = 15.5f)
                } else if (pr != null && addFurn) {
                    val kind = uz.metrx.app.ui.furniture.roomKind(pr.floors.firstOrNull { it.id == r.floorId })
                    uz.metrx.app.ui.components.GBtn(tr(if (kind == "kitchen") "fo.addK" else "fo.addW"), { app.push(Route.FGallery(pid, r.id)) },
                        icon = if (kind == "kitchen") "kitchen" else "board", height = 50.dp, fontSize = 15.5f)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CardBtn(tr("ed.tb.walls"), "walls", false, Modifier.weight(1f)) { app.push(Route.WallView(pid, r.id, walls(r, app.settings.angleSnap).first().id)) }
                    // with the furniture button above, 3D steps back so there is one main button
                    CardBtn(tr("gs.3d"), "cube", !addFurn, Modifier.weight(1f)) { ops.mode(pid, r.id, "3d") }
                }
                return@Column
            }
            "bad" -> {
                val o = f.issue!!; val iss = ops.issue(r, o)
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.errWash).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    MIcon("alert", G.err, 20.dp, 2f)
                    Text(iss?.let { app.t(it.key, *it.vars.toList().toTypedArray()) } ?: "", style = ui(13.5f, 500, G.err, 1.35f), modifier = Modifier.weight(1f))
                    Text(tr("ed.fix"), style = ui(14f, 700, G.err), modifier = Modifier.clickable(role = Role.Button) { app.sheet = Sheet.OpeningForm(pid, r.id, o.id) }.padding(8.dp))
                }
            }
            else -> {
                val d = r.dim(k!!)
                val name = ops.dimLabel(k)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Column(Modifier.weight(1f)) {
                        val small = when (f.kind) {
                            "recv" -> tr(if (d.pending?.from == "quick") "ed2.fromQuick" else "ed2.fromLaser", "w" to name)
                            "again" -> tr("ed2.re", "w" to name)
                            "conf" -> name + ", " + tr("src.${d.src ?: "manual"}")
                            else -> tr("ed2.next", "w" to name)
                        }
                        Text(small, style = ui(13f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        val (vtxt, vcol) = when (f.kind) {
                            "recv" -> fmtLen(d.pending!!.mm, unit, en, full = true) to AMBER
                            "conf" -> fmtLen(d.v, unit, en) to G.ink
                            else -> "?" to G.ink3
                        }
                        Row(verticalAlignment = Alignment.Bottom) {
                            Text(vtxt, style = num(34f, 600, vcol, -.01f))
                            Spacer(Modifier.width(3.dp))
                            Text(m, style = num(13f, 500, G.ink2), modifier = Modifier.padding(bottom = 6.dp))
                        }
                    }
                    when (f.kind) {
                        "recv" -> StatusPill(tr("ed2.unconf"), G.amberWash, AMBER, "clock")
                        "conf" -> StatusPill(tr("ed2.confirmed"), if (Theme.dark) G.greenWash else Color(0xFFE6F4EF), if (Theme.dark) G.green else Color(0xFF0B7A5A), "check")
                        "again" -> Row(Modifier.clip(CircleShape).background(G.ink.copy(alpha = .06f)).clickable(role = Role.Button) { ops.cancelAgain() }.padding(horizontal = 10.dp, vertical = 5.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) { MIcon("x", G.ink2, 14.dp, 2f); Text(tr("common.cancel"), style = ui(12.5f, 600, G.ink2)) }
                        else -> StatusPill(tr("ed2.notMeasured"), G.ink.copy(alpha = .06f), G.ink2, null)
                    }
                }
                if (f.kind == "again") Text(tr("ed2.cur", "v" to fmtLen(d.v, unit, en)), style = ui(13f, 400, G.ink2))
                if (f.kind == "unset" || f.kind == "again") {
                    if (ops.laserOn) Text(tr("ed2.pressLaser"), style = ui(13f, 400, G.ink2))
                    else Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        MIcon("btoff", G.ink2, 16.dp, 2f); Text(tr("ed2.noLaser"), style = ui(13f, 400, G.ink2))
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    when (f.kind) {
                        "recv" -> {
                            CardBtn(tr("ed2.again"), "laser", false, Modifier.weight(1f)) { ops.againReading(pid, r.id, k) }
                            CardBtn(tr("ed2.confirm"), "check", true, Modifier.weight(1f)) { ops.confirm(pid, r.id, k) }
                        }
                        "conf" -> {
                            CardBtn(tr("ed2.edit"), "edit", false, Modifier.weight(1f)) { app.sheet = Sheet.Measure(pid, r.id, k) }
                            CardBtn(tr("ed2.remeasure"), "laser", true, Modifier.weight(1f)) { ops.remeasure(pid, r.id, k) }
                        }
                        else -> {
                            CardBtn(tr("ed2.manual"), "kbd", false, Modifier.weight(1f)) { app.sheet = Sheet.Measure(pid, r.id, k) }
                            if (ops.laserOn) CardBtn(tr("ed2.getLaser"), "laser", true, Modifier.weight(1f)) { ops.laser(pid, r.id, k) }
                            else CardBtn(tr("ed2.dev"), "bt", true, Modifier.weight(1f)) { app.sheet = Sheet.Device }
                        }
                    }
                }
            }
        }
        // the footer: what comes next and the button that opens the full list
        val open = keys.filter { r.dim(it).status != "conf" && it != k }
        Row(Modifier.fillMaxWidth().heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                when { open.isNotEmpty() -> tr("ed2.left", "w" to ops.dimLabel(open[0]), "n" to open.size); f.kind == "unset" || f.kind == "recv" -> tr("ed2.last"); else -> "" },
                style = ui(13f, 400, G.ink2), modifier = Modifier.weight(1f), maxLines = 2, overflow = TextOverflow.Ellipsis
            )
            AllPill()
        }
    }
}

@Composable
private fun AllPill() {
    val app = LocalApp.current
    val open = app.ops.panelOpen
    Row(
        Modifier.heightIn(min = 44.dp).clip(CircleShape).background(G.cobalt.copy(alpha = .12f)).clickable(role = Role.Button) { app.ops.panelOpen = !open }
            .padding(start = 9.dp, end = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        uz.metrx.app.ui.icons.PathIcon(if (open) "M6 9.5l6 6 6-6" else "M6 14.5l6-6 6 6", G.cobalt, 16.dp, 2.2f)
        Text(tr(if (open) "ed2.hide" else "ed2.all"), style = ui(13f, 600, G.cobalt))
    }
}

@Composable
private fun StatusPill(text: String, bg: Color, fg: Color, icon: String?) {
    Row(Modifier.clip(CircleShape).background(bg).padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        if (icon != null) MIcon(icon, fg, 14.dp, 2.2f)
        Text(text, style = ui(12.5f, 600, fg), maxLines = 1)
    }
}

/** The step card's buttons: 52 dp pills; the main one blue (glass.css .gs-room .ed2-acts). */
@Composable
internal fun CardBtn(label: String, icon: String, primary: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(26.dp)
    Row(
        modifier.heightIn(min = 52.dp)
            .dropShadow(shape, Shadow(if (primary) 18.dp else 16.dp, if (primary) Color(0x38374FDD) else G.shade.copy(alpha = .08f), offset = DpOffset(0.dp, if (primary) 8.dp else 6.dp)))
            .clip(shape).background(if (primary) G.cobalt else G.idle(.65f))
            .let { if (primary) it else it.topHighlight(1f, 1.dp).border(1.dp, G.rim, shape) }
            .pressable(onClick, .98f).padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically
    ) {
        MIcon(icon, if (primary) Color.White else G.cobalt, 18.dp, 2.2f)
        Text(label, style = ui(15f, 700, if (primary) Color.White else G.ink), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** The opened panel: every measurement, the wall areas table, doors and windows (prototype ed2List). */
@Composable
private fun FullList(pid: String, r: Room, f: RoomOps.Focus) {
    val app = LocalApp.current
    val ops = app.ops
    val unit = app.settings.unit; val en = app.english()
    val snap = app.settings.angleSnap
    Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Section(tr("ed2.meas")) {
            stepKeys(r, snap).forEach { k ->
                val d = r.dim(k); val st = d.status
                Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(enabled = st == "conf") { ops.focus(r.id, k) }.padding(vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    val on = f.k == k
                    Box(Modifier.size(30.dp).clip(RoundedCornerShape(9.dp)).background(if (on) G.cobalt else G.ink.copy(alpha = .06f)), contentAlignment = Alignment.Center) {
                        Text(k, style = num(13f, 700, if (on) Color.White else G.ink))
                    }
                    Column(Modifier.weight(1f)) {
                        Text(ops.dimLabel(k), style = ui(14.5f, 600))
                        Text(when (st) { "recv" -> tr("ed2.st.recv"); "unset" -> tr("ed2.notMeasured"); else -> tr("ed2.confirmed") + ", " + tr("src.${d.src ?: "manual"}") }, style = ui(12.5f, 400, G.ink2))
                    }
                    Text(when (st) { "recv" -> fmtLen(d.pending!!.mm, unit, en, true); "conf" -> fmtLen(d.v, unit, en); else -> "?" },
                        style = num(15.5f, 600, when (st) { "recv" -> AMBER; "conf" -> G.ink; else -> G.ink3 }))
                    when (st) {
                        "recv" -> SmallBtn(tr("ed2.confirm"), true) { ops.confirm(pid, r.id, k) }
                        "unset" -> SmallBtn(tr("ed2.measure"), false) { ops.focus(r.id, k) }
                        else -> MIcon("check", OK_GREEN, 18.dp, 2.4f)
                    }
                }
            }
        }
        Section(tr("ed2.walls")) {
            val H = r.dim("H").v
            if (H == null) Text(tr("ed2.needH"), style = ui(13f, 400, G.ink2), modifier = Modifier.padding(vertical = 6.dp))
            else {
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Text(tr("ed2.colWall"), style = ui(12f, 500, G.ink3), modifier = Modifier.weight(1f))
                    Text(tr("ed2.colGross"), style = ui(12f, 500, G.ink3), modifier = Modifier.width(66.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                    Text(tr("ed2.colOpen"), style = ui(12f, 500, G.ink3), modifier = Modifier.width(58.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                    Text(tr("ed2.colNet"), style = ui(12f, 500, G.ink3), modifier = Modifier.width(66.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                }
                val ws = walls(r, snap)
                val stats = ws.map { wallStats(it.len, H, r.openings.filter { o -> o.wall == it.id }) }
                ws.forEachIndexed { i, wl ->
                    val s = stats[i]
                    Hairline()
                    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                        Text(wl.id + if (wl.derived && !r.isPoly) " =" else "", style = num(14f, 600), modifier = Modifier.weight(1f))
                        Text(s.gross?.let { fmtArea(it, en) } ?: "?", style = num(14f, 500), modifier = Modifier.width(66.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                        Text(if (s.open > 0) fmtArea(s.open, en) else "—", style = num(14f, 500, G.ink2), modifier = Modifier.width(58.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                        Text(s.net?.let { fmtArea(it, en) } ?: "?", style = num(14f, 700), modifier = Modifier.width(66.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                    }
                }
                if (stats.all { it.gross != null }) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(G.ink.copy(alpha = .05f)).padding(vertical = 8.dp)) {
                    Text(tr("ed2.total"), style = ui(14f, 700), modifier = Modifier.weight(1f).padding(start = 4.dp))
                    Text(fmtArea(stats.sumOf { it.gross!! }, en), style = num(14f, 600), modifier = Modifier.width(66.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                    Text(fmtArea(stats.sumOf { it.open }, en), style = num(14f, 600, G.ink2), modifier = Modifier.width(58.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                    Text(fmtArea(stats.sumOf { it.net!! }, en), style = num(14f, 800), modifier = Modifier.width(66.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                }
            }
        }
        Section(tr("ed2.ops")) {
            r.openings.forEach { o ->
                Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable { app.sheet = Sheet.OpeningForm(pid, r.id, o.id) }.padding(vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(30.dp).clip(RoundedCornerShape(9.dp)).background(G.ink.copy(alpha = .06f)), contentAlignment = Alignment.Center) { MIcon(o.type, G.ink, 18.dp, 2f) }
                    Column(Modifier.weight(1f)) {
                        Text(ops.opName(o) + ", " + tr("op.wall") + " " + o.wall, style = ui(14.5f, 600))
                        Text(tr("wv.off", "c" to wallCorner(r, o.wall, snap), "v" to (if (o.approx) "≈ " else "") + fmtLen(o.off, unit, en) + " " + app.unitName()), style = ui(12.5f, 400, if (o.approx) AMBER else G.ink2))
                    }
                    Text(fmtLen(o.w, unit, en) + " × " + fmtLen(o.h, unit, en), style = num(15.5f, 600))
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
            }
            Row(Modifier.heightIn(min = 44.dp).clickable(role = Role.Button) { app.sheet = Sheet.AddOpening(pid, r.id) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                MIcon("plus", G.cobalt, 18.dp, 2.2f); Text(tr("ed2.add"), style = ui(14f, 600, G.cobalt))
            }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column {
        Text(title, style = ui(12f, 600, G.ink3, spacing = .05f), modifier = Modifier.padding(bottom = 4.dp))
        content()
    }
}

@Composable
private fun SmallBtn(label: String, primary: Boolean, onClick: () -> Unit) {
    Text(label, style = ui(13f, 600, if (primary) Color.White else G.ink),
        modifier = Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).background(if (primary) G.cobalt else G.ink.copy(alpha = .06f))
            .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp, vertical = 13.dp))
}

/* ---------------- the tools row: Plan, Walls, Openings, 3D ---------------- */

@Composable
private fun Tools(pid: String, r: Room) {
    val app = LocalApp.current
    val haze = LocalHaze.current
    val shape = RoundedCornerShape(33.dp)
    Row(
        Modifier.padding(start = 12.dp, end = 12.dp, bottom = 12.dp).fillMaxWidth().height(66.dp)
            .dropShadow(shape, Shadow(30.dp, G.shade.copy(alpha = .1f), offset = DpOffset(0.dp, (-10).dp)))
            .clip(shape).glassBlur(haze, G.sheet(.5f), 28.dp).topHighlight(.95f).border(1.dp, G.rim, shape).padding(6.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Tool("room", tr("ed2.plan"), true, Modifier.weight(1f)) {}
        Tool("walls", tr("ed.tb.walls"), false, Modifier.weight(1f)) { app.push(Route.WallView(pid, r.id, walls(r, app.settings.angleSnap).first().id)) }
        Tool("door", tr("ed.tb.openings"), false, Modifier.weight(1f)) { app.sheet = Sheet.AddOpening(pid, r.id) }
        Tool("cube", "3D", false, Modifier.weight(1f)) { app.ops.mode(pid, r.id, "3d") }
    }
}

@Composable
private fun Tool(icon: String, label: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val bubble = RoundedCornerShape(27.dp)
    Column(
        modifier.fillMaxHeight()
            .let { if (on) it.dropShadow(bubble, Shadow(12.dp, G.shade.copy(alpha = .12f), offset = DpOffset(0.dp, 4.dp))) else it }
            .clip(bubble).background(if (on) G.glass(.9f) else Color.Transparent).clickable(role = Role.Tab, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically)
    ) {
        MIcon(icon, if (on) G.cobalt2 else G.slate, 22.dp, 2f)
        Text(label, style = ui(11f, if (on) 700 else 600, if (on) G.cobalt2 else G.slate), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/* ---------------- the first-time tip (prototype hint.editor) ---------------- */

@Composable
private fun EditorTip() {
    val app = LocalApp.current
    var dont by remember { androidx.compose.runtime.mutableStateOf(false) }
    fun ok() { app.ops.tipSeen = true; if (dont) app.settings.hideEditorTip() }
    androidx.activity.compose.BackHandler { ok() }
    Box(Modifier.fillMaxSize().background(G.scrim).clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) {}, contentAlignment = Alignment.Center) {
        val shape = RoundedCornerShape(26.dp)
        Column(Modifier.padding(24.dp).widthIn(max = 360.dp).clip(shape).background(G.sheet(.96f)).padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(tr("hint.title"), style = ui(13f, 700, G.cobalt), modifier = Modifier.weight(1f))
                Box(Modifier.size(40.dp).clip(CircleShape).clickable(role = Role.Button) { ok() }, contentAlignment = Alignment.Center) { MIcon("x", G.ink2, 20.dp, 2f) }
            }
            // a wall with an unconfirmed reading and a finger tapping it
            Canvas(Modifier.fillMaxWidth().height(96.dp).clip(RoundedCornerShape(16.dp)).background(if (Theme.dark) Color(0xFF10141E) else Color(0xFFF1F4FB))) {
                val y = size.height * .62f
                drawLine(INK, Offset(size.width * .12f, y), Offset(size.width * .88f, y), 8.dp.toPx())
                val pill = androidx.compose.ui.geometry.Rect(size.width / 2 - 34.dp.toPx(), y - 40.dp.toPx(), size.width / 2 + 34.dp.toPx(), y - 14.dp.toPx())
                drawRoundRect(G.amberWash, pill.topLeft, pill.size, androidx.compose.ui.geometry.CornerRadius(13.dp.toPx()))
                drawRoundRect(AMBER, pill.topLeft, pill.size, androidx.compose.ui.geometry.CornerRadius(13.dp.toPx()), style = androidx.compose.ui.graphics.drawscope.Stroke(1.5.dp.toPx()))
                drawCircle(G.cobalt.copy(alpha = .25f), 16.dp.toPx(), Offset(size.width / 2 + 40.dp.toPx(), y + 4.dp.toPx()))
                drawCircle(G.cobalt, 6.dp.toPx(), Offset(size.width / 2 + 40.dp.toPx(), y + 4.dp.toPx()))
            }
            Text(tr("hint.editor.t"), style = ui(18f, 800))
            Text(tr("hint.editor.b"), style = ui(14.5f, 400, G.ink2, 1.45f))
            Row(Modifier.clickable(role = Role.Checkbox) { dont = !dont }.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MIcon(if (dont) "boxok" else "box", G.cobalt, 22.dp, 2f); Text(tr("hint.dont"), style = ui(14f, 500))
            }
            uz.metrx.app.ui.components.GBtn(tr("hint.ok"), ::ok)
        }
    }
}
