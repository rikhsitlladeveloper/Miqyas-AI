package uz.metrx.app.ui.furniture

import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.geo.PartHi
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.ready3D
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.editor.ShotPill
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.three.Cam3D
import uz.metrx.app.ui.three.Scene3D

/*
 * Designer C v2's 3D (founder, 27 Oct 2026): the room with its furniture; a tap selects a module (a second tap on the
 * same one its door or drawer) and the slider below works as in 2D; nothing is dragged in 3D. The selection lights up
 * amber. "Ichini ko‘rish" opens every door, "Ichki" the selected module's.
 */

/** A picked front's key ("mid:f1", "mid:s2:f0", "mid:s2:d120", "mid:slide1") as the module id, the section and the front's index. */
data class Picked(val mid: String, val sec: Int?, val front: Int?)

fun parsePick(key: String): Picked {
    val parts = key.split(':')
    val mid = parts.first()
    var sec: Int? = null; var front: Int? = null
    parts.drop(1).forEach { p ->
        when {
            p.startsWith("s") && p.drop(1).toIntOrNull() != null && !p.startsWith("slide") -> sec = p.drop(1).toInt()
            p.startsWith("f") -> front = p.drop(1).toIntOrNull()
        }
    }
    return Picked(mid, sec, front)
}

/**
 * The room in 3D for a designer: [hi] what lights up ("pieceId|module" or "pieceId|module/section"), [open] the fronts
 * to open (null: every one), a tap's front key to [onKey] (null: nothing hit).
 */
@Composable
fun DzcScene3D(p: Project, room: Room, f: Furniture, hi: Set<String>, open: ((String) -> Boolean)?, inside: Boolean, bottomPad: androidx.compose.ui.unit.Dp, onKey: (String?) -> Unit) {
    val app = LocalApp.current
    val snap = app.settings.angleSnap
    if (!ready3D(room, snap)) {
        Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
            Text(tr(if (room.isPoly) "sk.need3d" else "3d.need"), style = ui(17f, 700, G.ink, 1.35f), textAlign = TextAlign.Center)
        }
        return
    }
    val mo = rememberDoorMotion(room.id)
    val free = uz.metrx.app.furniture.isFreeRoom(room)
    val left = free && p.furniture.any { uz.metrx.app.furniture.FREE_ROOM + it.id == room.id && it.walls.firstOrNull() == "D" && it.layout != "U" }
    val base = remember(room.dims, room.openings, room.poly, room.points, room.wallColor, room.floorColor, snap, left) {
        buildShell(listOf(room), true, snap).let { if (free) it.floorOnly(if (left) Math.PI / 2 - .75 else it.theta) else it } }
    val h = if (hi.isEmpty()) null else PartHi("dzc", uz.metrx.app.geo.HI_FRONT_BACK, hi)
    val (shell, fur) = rememberFurnShell(p, room, base, mo, h)
    val cam = remember(room.id) { Cam3D() }
    LaunchedEffect(inside, open, fur) {
        if (inside) mo.openAll(fur.keys) else if (open != null) mo.openAll(fur.keys.filter(open)) else mo.closeAll()
    }
    Box(Modifier.fillMaxSize()) {
        Scene3D(shell, cam, Modifier.fillMaxSize(), null, open = mo.amt, onTap = { pos -> onKey(fur.pickKey(cam, pos.x, pos.y, mo.amt)) }) {
            Row(Modifier.align(Alignment.TopEnd).padding(top = 104.dp, end = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ShotPill("cube", tr("3d.corner"), Modifier) { cam.preset(false) }
                ShotPill("room", tr("3d.top"), Modifier) { cam.preset(true) }
            }
            Text(tr("dzc.tap3d"), style = ui(12f, 600, G.ink2), modifier = Modifier.align(Alignment.TopStart).padding(start = 12.dp, top = 160.dp)
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp)).background(G.sheet(.7f)).padding(horizontal = 10.dp, vertical = 6.dp))
        }
    }
    @Suppress("UNUSED_VARIABLE") val ctx = LocalContext.current
}


/** The kitchen's 3D: its selection lit, a tap picks a module or (again) its front. */
@Composable
internal fun DzcKitchen3D(p: Project, room: Room, f: Furniture, st: DzcState, c: KitCtl, onPick: (String, Int?) -> Unit) {
    val sel = st.sel
    val hiSet = if (st.multi) st.ticks.mapNotNull { id -> f.modules.firstOrNull { it.id == id }?.let { "${f.id}|${it.label.ifEmpty { it.id }}" } }.toSet()
        else sel?.let { s -> f.modules.firstOrNull { it.id == s.id }?.let { setOf("${f.id}|${it.label.ifEmpty { it.id }}") } } ?: emptySet()
    val peek = st.peek
    val d = androidx.compose.ui.platform.LocalDensity.current
    DzcScene3D(p, room, f, hiSet, peek?.let { id -> { k: String -> k.startsWith("$id:") } }, st.inside, 100.dp) { key ->
        if (key == null) { if (!st.multi) st.clear(); return@DzcScene3D }
        val pk = parsePick(key)
        val m = f.modules.firstOrNull { it.id == pk.mid } ?: return@DzcScene3D
        if (st.multi) { st.ticks = if (m.id in st.ticks) st.ticks - m.id else st.ticks + m.id; return@DzcScene3D }
        // a module on another wall: that wall in 2D too
        if (m.wall != c.run.wall) { val rt = c.app.top; if (rt is uz.metrx.app.ui.Route.Kitchen) c.app.setTop(rt.copy(wall = m.wall)); st.clear() }
        onPick(m.id, pk.front)
    }
    @Suppress("UNUSED_VARIABLE") val u = d
}
