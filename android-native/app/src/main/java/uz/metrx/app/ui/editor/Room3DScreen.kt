package uz.metrx.app.ui.editor

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.data.Room
import uz.metrx.app.data.View3D
import uz.metrx.app.data.ViewFiles
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.geo.FLOOR_COLORS
import uz.metrx.app.geo.WALL_COLORS
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.ready3D
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.LaserButton
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.pressable
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

/** The room's 3D page (prototype PAGES.editor with mode '3d' and the ux module's report button on the picture). */
@Composable
fun Room3DScreen(r0: Route.Editor) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val ctx = LocalContext.current
    val ops = app.ops
    val p = app.store.get(r0.pid) ?: return
    val r = p.rooms.firstOrNull { it.id == r0.rid } ?: return
    val w = p.floors.firstOrNull { it.id == r.floorId }
    val snap = app.settings.angleSnap
    @Suppress("UNUSED_VARIABLE") val tick = ops.histTick
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        // bar: back, name and workspace, undo and redo
        Row(Modifier.fillMaxWidth().height(64.dp).padding(start = 8.dp, end = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp, end = 2.dp))
            Column(Modifier.weight(1f).padding(start = 2.dp)) {
                Text(dn(r.name, lang), style = ui(17f, 700, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (w != null) Text(floorName(w, lang), style = ui(12.5f, 400, G.ink2, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            HistIb("undo", tr("common.undo"), ops.canUndo(r.id)) { ops.undo(p.id, r.id) }
            Box(Modifier.width(8.dp))
            HistIb("redo", tr("common.redo"), ops.canRedo(r.id)) { ops.redo(p.id, r.id) }
        }
        // sub-bar: Plan | 3D, the laser
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            ModeSeg("3d") { if (it == "plan") ops.mode(p.id, r.id, "plan") }
            Box(Modifier.weight(1f))
            Box(Modifier.size(44.dp)) { LaserButton { app.openLaser() } }
        }
        if (!ready3D(r, snap)) {
            Column(Modifier.weight(1f).fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
                Text(tr(if (r.isPoly) "sk.need3d" else "3d.need"), style = ui(17f, 700, G.ink, 1.35f), textAlign = TextAlign.Center)
                GBtn(tr("ed.plan"), { ops.mode(p.id, r.id, "plan") }, Btn.SECONDARY, fill = false)
            }
            return@Column
        }
        val base = remember(r.dims, r.openings, r.poly, r.points, r.features, r.wallColor, r.floorColor, r.inner, snap) { buildShell(listOf(r), true, snap) }
        // a furniture order's furniture stands in its room; a tap opens a door or a drawer
        val mo = uz.metrx.app.ui.furniture.rememberDoorMotion(r.id)
        val (shell, fur) = if (p.isFurniture) uz.metrx.app.ui.furniture.rememberFurnShell(p, r, base, mo)
            else if (p.isTiler) uz.metrx.app.ui.tiles.rememberTileShell(p, r, base, snap) to null
            else if (p.isElec) uz.metrx.app.ui.elec.rememberElecShell(p, r, snap) to null
            else if (p.isPlumb) uz.metrx.app.ui.plumb.rememberPlumbShell(p, r, snap) to null
            else if (p.isWin) uz.metrx.app.ui.win.rememberWinShell(p, r, snap) to null else base to null
        val cam = remember(r.id) { Cam3D() }
        val shot = remember { Shot3D() }
        var taking by remember { mutableStateOf(false) }   // a second tap while a picture is being taken does nothing
        Box(Modifier.weight(1f).fillMaxWidth()) {
            Scene3D(shell, cam, Modifier.fillMaxSize(), shot, open = if (fur != null) mo.amt else null, onTap = fur?.let { fr -> { pos: Offset ->
                uz.metrx.app.ui.furniture.pickOf(fr, cam, pos, mo)?.let { k -> mo.toggle(k) }
            } }) {
                Labels3D(cam, shell.labels.map { it.p }) { i -> Lbl3D(shell.labels[i].text) }
                // a furniture order's room: hide every door to see inside
                if (fur != null) uz.metrx.app.ui.furniture.InsidePill(mo.bare, Modifier.align(Alignment.TopStart).padding(top = 10.dp, start = 10.dp)) { mo.bare = !mo.bare }
                ShotPill("camera", tr("3d.save"), Modifier.align(Alignment.TopEnd).padding(top = 10.dp, end = 10.dp)) {
                    // at most 4 views: counted on the room as saved now, not as this screen last drew it
                    fun full() = (ops.room(p.id, r.id)?.views?.size ?: 4) >= 4
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
            }
        }
        Controls3D(r, cam,
            onColor = { wall, c -> app.store.update(p.id) { pp -> pp.copy(rooms = pp.rooms.map { if (it.id == r.id) (if (wall) it.copy(wallColor = c) else it.copy(floorColor = c)) else it }) } },
            onDelete = { v ->
                app.store.update(p.id) { pp -> pp.copy(rooms = pp.rooms.map { if (it.id == r.id) it.copy(views = it.views.filter { x -> x.id != v.id }) else it }) }
                ViewFiles.delete(ctx, v.img); app.say("3d.deleted")
            })
    }
}

@Composable
private fun HistIb(icon: String, label: String, on: Boolean, onClick: () -> Unit) {
    GlassIconButton(icon, label, { if (on) onClick() }, Modifier.alpha(if (on) 1f else .4f))
}

/** Plan | 3D (prototype .subbar .seg). */
@Composable
internal fun ModeSeg(cur: String, onPick: (String) -> Unit) {
    Row(Modifier.clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        listOf("plan" to tr("ed.plan"), "3d" to "3D").forEach { (k, l) ->
            val on = k == cur
            val shape = RoundedCornerShape(9.dp)
            Box(
                Modifier.let { if (on) it.dropShadow(shape, Shadow(3.dp, Color(0x24101828), offset = DpOffset(0.dp, 1.dp))) else it }
                    .height(44.dp).clip(shape).background(if (on) G.glass(.55f) else Color.Transparent)
                    .clickable(role = Role.Tab) { onPick(k) }.padding(horizontal = 16.dp),
                contentAlignment = Alignment.Center
            ) { Text(l, style = ui(14f, if (on) 600 else 500, if (on) G.ink else G.ink2), maxLines = 1) }
        }
    }
}

/** The round white pill on the picture: "Add to report" (ux .v3-shot) and "All" (.v3-all). */
@Composable
internal fun ShotPill(icon: String, label: String, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(21.dp)
    Row(
        modifier.dropShadow(shape, Shadow(10.dp, Color(0x24101828), offset = DpOffset(0.dp, 2.dp))).height(42.dp).clip(shape)
            .background(G.sheet(.55f)).pressable(onClick, .97f)
            .padding(start = 12.dp, end = 15.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        MIcon(icon, G.cobalt, 18.dp, 2f)
        Text(label, style = ui(13.5f, 700), maxLines = 1)
    }
}

/** Below the picture: From above / From the corner, wall and floor colours, the views in the report (prototype .ctl3d). */
@Composable
private fun Controls3D(r: Room, cam: Cam3D, onColor: (Boolean, String) -> Unit, onDelete: (View3D) -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(G.glass(.55f)).drawWithContent {
            drawContent(); drawLine(G.hi(.8f), Offset(0f, 0f), Offset(size.width, 0f), .67.dp.toPx())
        }.padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf("3d.top" to true, "3d.corner" to false).forEach { (k, top) ->
                Box(
                    Modifier.weight(1f).height(44.dp).clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).pressable({ cam.preset(top) }, .98f),
                    contentAlignment = Alignment.Center
                ) { Text(tr(k), style = ui(14f, 700), maxLines = 1) }
            }
        }
        Swatches(tr("3d.walls"), WALL_COLORS, r.wallColor) { onColor(true, it) }
        Swatches(tr("3d.floor"), FLOOR_COLORS, r.floorColor) { onColor(false, it) }
        if (r.views.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("3d.inRep", "n" to r.views.size), style = ui(13f, 400, G.ink2))
            Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) { r.views.forEach { v -> ViewThumb(v) { onDelete(v) } } }
        }
    }
}

@Composable
private fun Swatches(label: String, colors: List<String>, cur: String, onPick: (String) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = ui(13.5f, 400, G.ink2), modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
        colors.forEach { c ->
            val on = c.equals(cur, ignoreCase = true)
            Box(
                Modifier.size(44.dp).drawWithContent {
                    drawContent()
                    if (on) { val k = 4.dp.toPx() + 1.dp.toPx(); drawRoundRect(G.cobalt, Offset(-k + 1.dp.toPx(), -k + 1.dp.toPx()), androidx.compose.ui.geometry.Size(size.width + 2 * k - 2.dp.toPx(), size.height + 2 * k - 2.dp.toPx()),
                        androidx.compose.ui.geometry.CornerRadius(5.dp.toPx()), style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx())) }
                }.clip(RoundedCornerShape(4.dp)).background(Color(android.graphics.Color.parseColor(c))).border(.67.dp, G.rim, RoundedCornerShape(4.dp))
                    .clickable(role = Role.RadioButton) { onPick(c) }
            )
        }
    }
}

/** A view in the report: 64 × 48 with a round × to take it out (ux .v3-th). */
@Composable
private fun ViewThumb(v: View3D, onDelete: () -> Unit) {
    val ctx = LocalContext.current
    val bmp by produceState<android.graphics.Bitmap?>(null, v.img) { value = withContext(Dispatchers.IO) { ViewFiles.load(ctx, v.img, 256) } }
    Box(Modifier.size(64.dp, 48.dp)) {
        Box(Modifier.fillMaxSize().clip(RoundedCornerShape(10.dp)).border(1.dp, G.rim, RoundedCornerShape(10.dp))) {
            bmp?.let { Image(it.asImageBitmap(), null, Modifier.fillMaxSize().clip(RoundedCornerShape(9.dp)), contentScale = ContentScale.Crop) }
        }
        Box(
            Modifier.align(Alignment.TopEnd).offset(9.dp, (-9).dp).size(26.dp).clip(CircleShape).background(G.ink)
                .pressable(onDelete, .92f, label = tr("3d.del")),
            contentAlignment = Alignment.Center
        ) { MIcon("x", G.solid, 13.dp, 2.4f) }
    }
}
