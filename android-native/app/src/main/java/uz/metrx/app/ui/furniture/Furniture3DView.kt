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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.withFrameNanos
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

/**
 * Doors and drawers opening and shutting, about 0.3 s each: [target] what should be open, [prog] how far each one is.
 * Shutting a door slides in what was pulled out behind it first; opening one leaves its drawers shut.
 */
class DoorMotion {
    var target by mutableStateOf(setOf<String>())
    /** "See inside" (bazis ideas, 23 Oct 2026): every door, drawer front and sliding door hidden. */
    var bare by mutableStateOf(false)
    val prog = mutableStateMapOf<String, Float>()
    fun toggle(k: String) { target = if (k in target) target - k - inner(k, target) else target + k }
    fun openAll(keys: Collection<String>) { target = keys.toSet() }
    fun closeAll() { target = emptySet() }
}

/** A door's key (a hinged door "…:f1" or a sliding one "…:slide0"), not a drawer's or a rack's. */
private fun isDoor(k: String) = k.substringAfterLast(':').let { it.startsWith("f") || it.startsWith("slide") }

/** What stands behind door [door] among [keys]: the drawers and racks of its section (a sliding door: of its wardrobe). */
private fun inner(door: String, keys: Collection<String>): Set<String> {
    if (!isDoor(door)) return emptySet()
    val pre = door.substringBeforeLast(':') + ":"
    return keys.filter { it.startsWith(pre) && !isDoor(it) }.toSet()
}

@Composable
fun rememberDoorMotion(id: String): DoorMotion {
    val mo = remember(id) { DoorMotion() }
    val target = mo.target
    LaunchedEffect(mo, target) {
        suspend fun move(keys: List<String>, to: Float) {
            if (keys.isEmpty()) return
            val from = keys.associateWith { mo.prog[it] ?: 0f }
            val t0 = withFrameNanos { it }
            var last = 0L
            while (true) {
                val now = withFrameNanos { it }
                val e = ((now - t0) / 300_000_000f).coerceIn(0f, 1f)
                // each step rebuilds the room's scene: about 25 a second is smooth enough and keeps it light
                if (e < 1f && now - last < 40_000_000L) continue
                last = now
                val k = e * e * (3 - 2 * e)
                keys.forEach { mo.prog[it] = from.getValue(it) + (to - from.getValue(it)) * k }
                if (e >= 1f) break
            }
            keys.forEach { if (to == 0f) mo.prog.remove(it) else mo.prog[it] = 1f }
        }
        // what shuts: the drawers first, then the doors; what opens: the doors first, then the drawers
        val shut = mo.prog.keys.filter { it !in target }
        move(shut.filter { !isDoor(it) }, 0f)
        move(shut.filter { isDoor(it) }, 0f)
        val opening = target.filter { (mo.prog[it] ?: 0f) < 1f }
        move(opening.filter { isDoor(it) }, 1f)
        move(opening.filter { !isDoor(it) }, 1f)
    }
    return mo
}

/** The room's scene with this order's furniture in it, each door and drawer as far open as [mo] says; what can be opened. */
@Composable
fun rememberFurnShell(p: Project, room: Room, base: Shell3D, mo: DoorMotion): Pair<Shell3D, Furn3D> {
    val app = LocalApp.current
    val ws = app.settings.workshop; val mats = app.settings.mats
    val fs = p.furniture.filter { it.roomId == room.id || (it.roomId == null && uz.metrx.app.furniture.FREE_ROOM + it.id == room.id) }
    val amt = mo.prog.toMap()
    val bare = mo.bare
    // the light tier draws no glow and fewer small details (modern 3D part 3)
    val ctx = LocalContext.current
    val light = remember(app.settings.quality) { uz.metrx.app.ui.three.Quality3D.tier(ctx, app.settings.quality) == uz.metrx.app.ui.three.Tier.LOW }
    val ceil = room.dim("H").v
    val fur = remember(base, fs, amt, ws, mats, bare, light, ceil) {
        furniture3D(fs, base.bases, ws, matRgb(mats), emptySet(), amt = { k -> (amt[k] ?: 0f).toDouble() }, bare = bare, look = matLook(mats),
            mats = mats, light = light, ceil = ceil)
    }
    val shell = remember(base, fur) { base.plus(fur.parts, fur.edges) }
    return shell to fur
}

/** A material id's colour for the 3D (the workshop's list; an id not in it a light board). */
private fun matOf(mats: List<uz.metrx.app.furniture.Mat>, id: String) =
    mats.firstOrNull { it.id == id } ?: uz.metrx.app.furniture.MAT_PRESETS.firstOrNull { it.id == id }

fun matRgb(mats: List<uz.metrx.app.furniture.Mat>): (String) -> Int = { id -> rgbOf(matOf(mats, id)?.rgb ?: "#F5F5F2") }

/** How a material id looks in the lit 3D: the 3D screens, the gallery cards (Cards.kt) and the size steps' colours. */
fun matLook(mats: List<uz.metrx.app.furniture.Mat>): (String) -> uz.metrx.app.geo.Look =
    { id -> matOf(mats, id).let { m -> uz.metrx.app.geo.Looks.of(m?.kind ?: "board", rgbOf(m?.rgb ?: "#F5F5F2"), m?.tex, m?.finish?.takeIf { it == "gloss" || it == "satin" } ?: "matte") } }

/** The door or drawer under pixel [x], [y], nearest the eye. */
fun Furn3D.pick(cam: Cam3D, x: Float, y: Float): String? {
    val (e, d) = cam.ray(x, y)
    return picks.mapNotNull { pk -> pk.box.hit(e, d)?.let { pk.key to it } }.minByOrNull { it.second }?.first
}

/** The same, for callers outside this package. */
fun pickOf(f: Furn3D, cam: Cam3D, at: androidx.compose.ui.geometry.Offset): String? = f.pick(cam, at.x, at.y)

/** The "See inside" pill over a 3D picture: hides every door and drawer front, a second tap brings them back. */
@Composable
fun InsidePill(on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    ShotPill(if (on) "door" else "box", tr(if (on) "bz.doorsBack" else "bz.inside"), modifier, onClick)
}

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
    val mo = rememberDoorMotion(room.id)
    // furniture without a room stands on a floor of its size, no walls round it
    val free = uz.metrx.app.furniture.isFreeRoom(room)
    // a room-less corner piece with its corner on the left (made-up walls D, A) is seen from the right
    val left = free && p.furniture.any { uz.metrx.app.furniture.FREE_ROOM + it.id == room.id && it.walls.firstOrNull() == "D" && it.layout != "U" }
    val base = remember(room.dims, room.openings, room.poly, room.points, room.wallColor, room.floorColor, snap, left) {
        buildShell(listOf(room), true, snap).let { if (free) it.floorOnly(if (left) Math.PI / 2 - .75 else it.theta) else it } }
    val (shell, fur) = rememberFurnShell(p, room, base, mo)
    val cam = remember(room.id) { Cam3D() }
    val shot = remember { Shot3D() }
    var taking by remember { mutableStateOf(false) }
    Box(Modifier.weight(1f).fillMaxWidth()) {
        Scene3D(shell, cam, Modifier.fillMaxSize(), shot, onTap = { pos -> fur.pick(cam, pos.x, pos.y)?.let { k -> mo.toggle(k) } }) {
            // a picture for the customer shows the doors: no saving while seeing inside
            if (!free && !mo.bare) ShotPill("camera", tr("3d.save"), Modifier.align(Alignment.TopEnd).padding(top = 10.dp, end = 10.dp)) {
                // a second tap while a picture is being taken does nothing; the limit is read from the store, not this page
                fun full() = (app.store.get(p.id)?.rooms?.firstOrNull { it.id == room.id }?.views?.size ?: 0) >= 4
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
                        app.store.update(p.id) { pp -> pp.copy(rooms = pp.rooms.map { if (it.id == room.id) it.copy(views = it.views + View3D(id, img, System.currentTimeMillis())) else it }) }
                        app.say("3d.saved")
                    }
                }
            }
            InsidePill(mo.bare, Modifier.align(Alignment.TopStart).padding(top = 10.dp, start = 10.dp)) { mo.bare = !mo.bare }
            Text(tr(if (mo.bare) "bz.insideHint" else "f3.hint"), style = ui(12.5f, 600, G.ink2), modifier = Modifier.align(Alignment.BottomStart).padding(12.dp)
                .clip(RoundedCornerShape(10.dp)).background(G.sheet(.7f)).padding(horizontal = 10.dp, vertical = 6.dp))
        }
    }
    Column(Modifier.fillMaxWidth().background(G.glass(.55f)).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GBtn(tr("f3.openAll"), { mo.openAll(fur.keys) }, Btn.SECONDARY, enabled = !mo.bare, height = 44.dp, corner = 12.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("f3.close"), { mo.closeAll() }, Btn.SECONDARY, enabled = mo.target.isNotEmpty(), height = 44.dp, corner = 12.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf("3d.top" to true, "3d.corner" to false).forEach { (k, top) ->
                GBtn(tr(k), { cam.preset(top) }, Btn.SECONDARY, height = 44.dp, corner = 12.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            }
        }
        if (room.views.isNotEmpty()) Text(tr("3d.inRep", "n" to room.views.size), style = ui(13f, 400, G.ink2))
    }
}
