package uz.metrx.app.ui.furniture

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.View3D
import uz.metrx.app.data.ViewFiles
import uz.metrx.app.data.uid
import uz.metrx.app.geo.Furn3D
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.furniture3D
import uz.metrx.app.geo.ready3D
import uz.metrx.app.geo.rgbOf
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.editor.ShotPill
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.three.Cam3D
import uz.metrx.app.ui.three.Scene3D
import uz.metrx.app.ui.three.Shot3D

/*
 * Furniture in 3D, Stage 1a part 6 (furniture plan section 9): the order's furniture in its measured room on the
 * existing 3D page and engine. A tap on a door or drawer opens it; "Hammasini ochish" and "Yopish" do all of them.
 */

/** The room's scene with this order's furniture in it, and what can be opened. */
@Composable
fun rememberFurnShell(p: Project, room: Room, base: Shell3D, open: Set<String>): Pair<Shell3D, Furn3D> {
    val app = LocalApp.current
    val ws = app.settings.workshop; val mats = app.settings.mats
    val fs = p.furniture.filter { it.roomId == room.id || (it.roomId == null && uz.metrx.app.furniture.FREE_ROOM + it.id == room.id) }
    val fur = remember(base, fs, open, ws, mats) { furniture3D(fs, base.bases, ws, { id -> rgbOf(mats.firstOrNull { it.id == id }?.rgb ?: "#F5F5F2") }, open) }
    val shell = remember(base, fur) { base.plus(fur.parts, fur.edges) }
    return shell to fur
}

/** The door or drawer under pixel [x], [y], nearest the eye. */
fun Furn3D.pick(cam: Cam3D, x: Float, y: Float): String? {
    val (e, d) = cam.ray(x, y)
    return picks.mapNotNull { pk -> pk.box.hit(e, d)?.let { pk.key to it } }.minByOrNull { it.second }?.first
}

/** The same, for callers outside this package. */
fun pickOf(f: Furn3D, cam: Cam3D, at: androidx.compose.ui.geometry.Offset): String? = f.pick(cam, at.x, at.y)

/** The 2D | 3D switch of the kitchen and wardrobe designers. */
@Composable
fun DimSeg(d3: Boolean, onPick: (Boolean) -> Unit) {
    Row(Modifier.clip(RoundedCornerShape(12.dp)).background(G.ink.copy(alpha = .06f)).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        listOf(false to "2D", true to "3D").forEach { (k, l) ->
            val on = k == d3
            Box(Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(9.dp)).background(if (on) G.glass(.9f) else Color.Transparent)
                .semantics { selected = on }.clickable(role = Role.Tab) { onPick(k) }.padding(horizontal = 18.dp), contentAlignment = Alignment.Center) {
                Text(l, style = ui(14f, if (on) 700 else 500, if (on) G.ink else G.ink2))
            }
        }
    }
}

/** The designers' 3D: the whole room with all its furniture, doors that open, views for the report. */
@Composable
fun ColumnScope.Furniture3D(p: Project, room: Room) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val snap = app.settings.angleSnap
    if (!ready3D(room, snap)) {
        Column(Modifier.weight(1f).fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
            Text(tr(if (room.isPoly) "sk.need3d" else "3d.need"), style = ui(17f, 700, G.ink, 1.35f), textAlign = TextAlign.Center)
        }
        return
    }
    var open by remember(room.id) { mutableStateOf(setOf<String>()) }
    // furniture without a room stands on a floor of its size, no walls round it
    val free = uz.metrx.app.furniture.isFreeRoom(room)
    val base = remember(room.dims, room.openings, room.poly, room.points, room.wallColor, room.floorColor, snap) { buildShell(listOf(room), true, snap).let { if (free) it.floorOnly() else it } }
    val (shell, fur) = rememberFurnShell(p, room, base, open)
    val cam = remember(room.id) { Cam3D() }
    val shot = remember { Shot3D() }
    Box(Modifier.weight(1f).fillMaxWidth()) {
        Scene3D(shell, cam, Modifier.fillMaxSize(), shot, onTap = { pos -> fur.pick(cam, pos.x, pos.y)?.let { k -> open = if (k in open) open - k else open + k } }) {
            if (!free) ShotPill("camera", tr("3d.save"), Modifier.align(Alignment.TopEnd).padding(top = 10.dp, end = 10.dp)) {
                if (room.views.size >= 4) { app.say("3d.max", kind = ToastKind.ERROR); return@ShotPill }
                shot.take { bmp ->
                    val id = uid()
                    val img = bmp?.let { ViewFiles.save(ctx, id, it) }
                    if (img == null) app.say("3d.fail", kind = ToastKind.ERROR)
                    else {
                        app.store.update(p.id) { pp -> pp.copy(rooms = pp.rooms.map { if (it.id == room.id) it.copy(views = it.views + View3D(id, img, System.currentTimeMillis())) else it }) }
                        app.say("3d.saved")
                    }
                }
            }
            Text(tr("f3.hint"), style = ui(12.5f, 600, G.ink2), modifier = Modifier.align(Alignment.BottomStart).padding(12.dp)
                .clip(RoundedCornerShape(10.dp)).background(G.sheet(.7f)).padding(horizontal = 10.dp, vertical = 6.dp))
        }
    }
    Column(Modifier.fillMaxWidth().background(G.glass(.55f)).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GBtn(tr("f3.openAll"), { open = fur.keys.toSet() }, Btn.SECONDARY, height = 44.dp, corner = 12.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("f3.close"), { open = emptySet() }, Btn.SECONDARY, enabled = open.isNotEmpty(), height = 44.dp, corner = 12.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf("3d.top" to true, "3d.corner" to false).forEach { (k, top) ->
                GBtn(tr(k), { cam.preset(top) }, Btn.SECONDARY, height = 44.dp, corner = 12.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            }
        }
        if (room.views.isNotEmpty()) Text(tr("3d.inRep", "n" to room.views.size), style = ui(13f, 400, G.ink2))
    }
}
