package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.furniture.BED_KINDS
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.LEG_KINDS
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Opt
import uz.metrx.app.furniture.UNDER_KINDS
import uz.metrx.app.furniture.itemGet
import uz.metrx.app.furniture.itemRange
import uz.metrx.app.furniture.itemSet
import uz.metrx.app.furniture.itemSized
import uz.metrx.app.furniture.packPiece
import uz.metrx.app.furniture.wardOfF
import uz.metrx.app.furniture.withUnder
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.editor.roomGrid
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * The short designer of a bed, a bunk or loft bed, a table, the bar counter and the hallway's mirror panel (decided
 * 22 Oct 2026): the piece in 3D, its sizes and its few options; materials, the room and (Advanced) the cost as the
 * wardrobe's. The rules are in furniture/Items.kt and Pieces.kt.
 */

/** Changes box [mid] of piece [fid] (on the designer's undo list), its outer size following its options. */
private fun App.item(p: Project, f: Furniture, mid: String, fn: (Module) -> Module) {
    val ws = settings.workshop
    kit.change(this, p.id, f.id) { x ->
        val room = if (x.roomId == null) null else roomOf(p, x)
        packPiece(x.copy(modules = x.modules.map { if (it.id == mid) itemSized(fn(it), ws) else it }),
            room?.let { r -> wallLen(r, settings.angleSnap, x.walls.firstOrNull() ?: "") }, mid, ws)
    }
}

/** A size's label in the item designer. */
private fun sizeLabel(m: Module, key: String) = when (key) {
    "w" -> if (m.type == "mirror") "fz.mirW" else "wd.w"
    "h" -> when (m.type) { "mirror" -> "fz.mirH"; "bed" -> "fb.h"; else -> "fz.wH" }
    "d" -> if (m.type == "bar") "fb.barD" else "wd.d"
    "e" -> "fz.elev"
    else -> "fb.$key"
}

@Composable
fun ItemScreen(rt: Route.Wardrobe, p: Project, f: Furniture) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val kit = app.kit
    val m = wardOfF(f) ?: return
    val ws = app.settings.workshop; val mats = app.settings.mats
    val room = roomOf(p, f)
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GlassIconButton("back", tr("nt.back"), { app.pop() })
                Column(Modifier.weight(1f)) {
                    Text(dn(f.name, lang), style = ui(19f, 800, G.ink, 1.2f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(pieceLine(f, ws), style = ui(12f, 400, G.ink2), maxLines = 1)
                }
                GlassIconButton("undo", tr("common.undo"), { kit.undo(app, p.id, f.id) }, tint = if (kit.canUndo(f.id)) G.ink else G.ink3.copy(alpha = .45f))
                GlassIconButton("redo", tr("common.redo"), { kit.redo(app, p.id, f.id) }, tint = if (kit.canRedo(f.id)) G.ink else G.ink3.copy(alpha = .45f))
                GlassIconButton("more", tr("common.menu"), { app.sheet = Sheet.FMenu(p.id, f.id) })
            }
            if (room == null) {
                Text(tr("kt.roomLost"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.padding(24.dp))
                return@Column
            }
            Row(Modifier.padding(start = 16.dp, end = 16.dp, bottom = 10.dp)) {
                Seg(listOf("p" to tr("it.piece"), "r" to tr("it.inRoom")), if (rt.d3) "r" else "p") { app.setTop(rt.copy(d3 = it == "r")) }
            }
            if (rt.d3) { Furniture3D(p, room); return@Column }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                val scene = remember(f, ws, mats) { pieceScene(f, ws, mats) }
                Box(Modifier.fillMaxWidth().aspectRatio(1f / .8f).clip(RoundedCornerShape(22.dp)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                    PieceView(scene, null, null, Modifier.fillMaxSize())
                    Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                }
                Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    ItemOptions(p, f, m)
                }
                Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (f.roomId == null) FreeBanner(p, f)
                    else {
                        Text(tr("it.where"), style = ui(15.5f, 800))
                        Text(tr(if (uz.metrx.app.furniture.canStandFree(f)) "it.whereFree" else "it.whereWall"), style = ui(12.5f, 400, G.ink2, 1.4f))
                        GBtn(tr("fz.move"), { app.push(Route.FPlace(p.id, f.id, room.id)) }, Btn.SECONDARY, icon = "room", height = 44.dp, corner = 14.dp, fontSize = 14f)
                    }
                }
                Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    MatStep(p, f, mats)
                }
                CostCard(p, f, ws, mats)
            }
        }
    }
}

/** The options of the piece's main box, by what it is. */
@Composable
private fun ItemOptions(p: Project, f: Furniture, m: Module) {
    val app = LocalApp.current
    val o = m.opt ?: Opt()
    fun opt(fn: (Opt) -> Opt) = app.item(p, f, m.id) { it.copy(opt = fn(it.opt ?: Opt())) }
    @Composable fun size(key: String) = FValRow(tr(sizeLabel(m, key)), if (key in setOf("mirW", "mirH") && itemGet(m, key) == 0) tr("fb.none") else "${itemGet(m, key)} " + tr("u.mm")) {
        app.sheet = Sheet.IField(p.id, f.id, m.id, key)
    }
    Text(tr("it.title"), style = ui(15.5f, 800))
    when (m.type) {
        "bed" -> {
            Text(tr("fb.bt"), style = ui(14.5f, 700))
            Seg(BED_KINDS.map { it to tr("fb.bt.$it") }, o.bed) { k -> opt { it.copy(bed = k) } }
            Text(tr("fb.bt.${o.bed}.s"), style = ui(12.5f, 400, G.ink2, 1.4f))
            size("mw"); size("ml"); size("h"); size("hb")
            if (o.bed == "drawers") Toggle(tr("km.handles"), m.handles) { app.item(p, f, m.id) { it.copy(handles = !it.handles) } }
        }
        "bunk", "loft" -> {
            size("mw"); size("ml"); size("h")
            Text(tr("fb.lad"), style = ui(14.5f, 700))
            Seg(listOf("L" to tr("fb.lad.L"), "R" to tr("fb.lad.R")), o.ladder) { k -> opt { it.copy(ladder = k) } }
            if (m.type == "loft") {
                Text(tr("fb.und"), style = ui(14.5f, 700))
                Seg(UNDER_KINDS.map { it to tr("fb.und.$it") }, o.under, lines = 2) { k ->
                    if (k != o.under) app.kit.change(app, p.id, f.id) { x -> withUnder(x, k, app.settings.workshop) }
                }
                f.modules.firstOrNull { it.type == "wardrobe" }?.let { u ->
                    GBtn(tr("it.under"), { app.kit.sel = u.id; app.push(Route.Wardrobe(p.id, f.id, step = 3, mod = u.id)) }, Btn.SECONDARY, icon = "board",
                        height = 44.dp, corner = 14.dp, fontSize = 14f)
                }
            }
        }
        "table" -> {
            size("w"); size("d"); size("h")
            Text(tr("fb.lg"), style = ui(14.5f, 700))
            Seg(LEG_KINDS.map { it to tr("fb.lg.$it") }, o.legs, lines = 2) { k -> opt { it.copy(legs = k) } }
            Text(tr("fb.tp"), style = ui(14.5f, 700))
            Seg(listOf("ldsp" to tr("fb.tp.ldsp"), "wt" to tr("fb.tp.wt")), o.top, lines = 2) { k -> opt { it.copy(top = k) } }
            Toggle(tr("fb.rc"), o.round) { opt { it.copy(round = !it.round) } }
        }
        "bar" -> {
            size("w"); size("d"); size("h"); size("over")
            Text(tr("fb.tp"), style = ui(14.5f, 700))
            Seg(listOf("ldsp" to tr("fb.tp.ldsp"), "wt" to tr("fb.tp.wt")), o.top, lines = 2) { k -> opt { it.copy(top = k) } }
            Toggle(tr("fb.shelves"), o.shelves) { opt { it.copy(shelves = !it.shelves) } }
            Toggle(tr("fb.foot"), o.foot) { opt { it.copy(foot = !it.foot) } }
        }
        "hooks" -> {
            size("w"); size("h"); size("e")
            Stepper(tr("fb.hooks"), o.hooks, 0, 10) { v -> opt { it.copy(hooks = v) } }
            Toggle(tr("fb.shelf"), o.shelf) { opt { it.copy(shelf = !it.shelf) } }
            size("mirW"); size("mirH")
        }
    }
}

/** One size of an item (or of a dressing table's mirror), typed. */
@Composable
internal fun IFieldSheet(s: Sheet.IField) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val m = f.modules.firstOrNull { it.id == s.mid } ?: run { app.sheet = null; return }
    val range = itemRange(m, s.key)
    val start = itemGet(m, s.key)
    var v by rememberSaveable { mutableStateOf(start.toString()) }
    val vi = v.toIntOrNull()?.takeIf { it in range }
    val fr = remember { androidx.compose.ui.focus.FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    val title = tr(sizeLabel(m, s.key))
    fun save() {
        val x = vi ?: return
        app.item(p, f, m.id) { itemSet(it, s.key, x, app.settings.workshop) }
        app.sheet = null
    }
    GlassSheet(title, { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save, enabled = vi != null) }) {
        GField(title, v, { v = it.filter(Char::isDigit).take(4) }, "$start", number = true, labelRight = tr("u.mm"), error = tr("km.bad", "a" to range.first, "b" to range.last),
            showError = vi == null, imeAction = ImeAction.Done, onIme = ::save, focusRequester = fr)
        if (s.key == "mirW" || s.key == "mirH") Text(tr("fb.mirNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/** A piece's sizes in a line (furniture/Steps.kt sizeLine), in the app's language. */
@Composable
internal fun pieceLine(f: Furniture, ws: uz.metrx.app.furniture.Workshop): String = uz.metrx.app.furniture.sizeLine(f, ws, tr("u.mm"))

/** A small 3D picture of a piece (a bed, a stenka…) for its card, made off the main thread. */
@Composable
internal fun PieceThumb(f: Furniture, modifier: Modifier) {
    val app = LocalApp.current
    val ws = app.settings.workshop; val mats = app.settings.mats
    val dens = LocalDensity.current.density
    BoxWithConstraints(modifier, contentAlignment = Alignment.Center) {
        val wpx = (maxWidth.value * dens).toInt().coerceIn(40, 900); val hpx = (maxHeight.value * dens).toInt().coerceIn(40, 900)
        val img by produceState<ImageBitmap?>(null, f, ws, mats, wpx, hpx) {
            value = withContext(Dispatchers.Default) { runCatching { piecePicture(pieceScene(f, ws, mats), wpx, hpx, dens) }.getOrNull() }
        }
        img?.let { Image(it, null, Modifier.fillMaxSize().clip(RoundedCornerShape(10.dp)).background(G.glass(.3f)), contentScale = ContentScale.Crop) }
    }
}
