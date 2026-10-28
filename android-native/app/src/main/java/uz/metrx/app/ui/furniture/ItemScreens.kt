package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.mutableIntStateOf
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
import androidx.compose.foundation.horizontalScroll
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
internal fun App.item(p: Project, f: Furniture, mid: String, fn: (Module) -> Module) {
    val ws = settings.workshop
    kit.change(this, p.id, f.id) { x ->
        val room = if (x.roomId == null) null else roomOf(p, x)
        packPiece(x.copy(modules = x.modules.map { if (it.id == mid) itemSized(fn(it), ws) else it }),
            room?.let { r -> wallLen(r, settings.angleSnap, x.walls.firstOrNull() ?: "") }, mid, ws)
    }
}

/** A size's label in the item designer. */
internal fun sizeLabel(m: Module, key: String) = when (key) {
    "w" -> if (m.type == "mirror") "fz.mirW" else "wd.w"
    "h" -> when (m.type) { "mirror" -> "fz.mirH"; "bed" -> "fb.h"; else -> "fz.wH" }
    "d" -> if (m.type == "bar") "fb.barD" else "wd.d"
    "e" -> "fz.elev"
    else -> "fb.$key"
}

/**
 * The short designer (Designer C v2: the same slider, Undo and 2D/3D): the piece drawn, its tools underneath (sizes,
 * type, handles, colour, inside, where, materials, more).
 */
@Composable
fun ItemScreen(rt: Route.Wardrobe, p: Project, f: Furniture) {
    val app = LocalApp.current
    val m = wardOfF(f) ?: return
    val ws = app.settings.workshop; val mats = app.settings.mats
    val room = roomOf(p, f)
    val st = app.dzc(f.id)
    Box(Modifier.fillMaxSize().roomGrid()) {
        Column(Modifier.fillMaxSize()) {
            uz.metrx.app.ui.ux.DesignerTop(p, f, pieceLine(f, ws)) { st.teach = true }
            if (room == null) {
                Text(tr("kt.roomLost"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.weight(1f).padding(24.dp))
            } else Box(Modifier.weight(1f).fillMaxWidth()) {
                var panelH by remember { mutableStateOf(0) }
                val d = LocalDensity.current
                if (rt.d3) DzcScene3D(p, room, f, emptySet(), null, st.inside, 100.dp) { }
                else {
                    val scene = remember(f, ws, mats, st.inside) { pieceScene(f, ws, mats, st.inside) }
                    Box(Modifier.fillMaxSize().padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = with(d) { panelH.toDp() } + 16.dp)) {
                        PieceView(scene, null, null, Modifier.fillMaxSize())
                        Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                    }
                }
                DzcPanel({ }, { panelH = it }) {
                    val k = st.strip
                    if (k != null) ItemToolOptions(p, f, m, k) { st.strip = null }
                    else ToolSlider(itemTools(app, f, m, st)) { key -> itemTool(app, p, f, m, st, key) }
                }
            }
            uz.metrx.app.ui.ux.DesignerBar(p, f, rt.d3) { app.setTop(rt.copy(d3 = it)) }
        }
        // "?" (Designer C v2 fix): the short designer's own hint, the tools, turning it in 3D, zooming
        if (st.teach) TeachHint(item = true) { st.teach = false }
    }
}

/** The sizes the piece's main box is typed by. */
private fun itemSizes(m: Module): List<String> = when (m.type) {
    "bed" -> listOf("mw", "ml", "h", "hb")
    "bunk", "loft" -> listOf("mw", "ml", "h")
    "bar" -> listOf("w", "d", "h", "over")
    "hooks" -> listOf("w", "h", "e", "mirW", "mirH")
    else -> listOf("w", "d", "h")
}

private fun itemTools(app: App, f: Furniture, m: Module, st: DzcState): List<DTool> {
    fun t(k: String, icon: String, on: Boolean = false) = DTool(k, app.t("dzc.tool.$k"), icon, on = on)
    val big = (m.opt?.seats ?: 0) > 0
    val drawers = uz.metrx.app.furniture.handleFronts(m).isNotEmpty()
    val inside = f.modules.any { b -> b.sections.any { it.fronts.kind != "open" } || b.opt?.bed == "drawers" }
    return listOfNotNull(if (!big) t("size", "ruler") else null, if (!big && m.type != "mirror") t("type", "grid") else null, if (drawers) t("handle", "handle") else null,
        t("decor", "palette"), if (inside) t("see", "eye", st.inside) else null, if (f.roomId != null) t("place", "room") else null, t("mats", "layers"), t("more", "sliders"))
}

private fun itemTool(app: App, p: Project, f: Furniture, m: Module, st: DzcState, k: String) {
    when (k) {
        "see" -> { st.inside = !st.inside; app.haptic(uz.metrx.app.ui.ux.Hap.TICK) }
        "place" -> f.roomId?.let { app.push(Route.FPlace(p.id, f.id, it)) }
        "mats" -> app.sheet = Sheet.FMats(p.id, f.id)
        "more" -> app.sheet = Sheet.DzcMore(p.id, f.id, "item")
        else -> st.strip = k
    }
}

@Composable
private fun ItemToolOptions(p: Project, f: Furniture, m: Module, k: String, back: () -> Unit) {
    val app = LocalApp.current
    val o = m.opt ?: Opt()
    fun opt(fn: (Opt) -> Opt) { app.item(p, f, m.id) { it.copy(opt = fn(it.opt ?: Opt())) }; app.dzcDone(p.id, f.id, app.t("ux.q.changed", "n" to dn(f.name, app.settings.lang))) }
    when (k) {
        "size" -> OptRow(tr("dzc.tool.size"), pieceLine(f, app.settings.workshop), back) {
            itemSizes(m).forEach { key -> OptChip(tr(sizeLabel(m, key)) + " " + (if (key in setOf("mirW", "mirH") && itemGet(m, key) == 0) tr("fb.none") else "${itemGet(m, key)}"), false) {
                app.sheet = Sheet.IField(p.id, f.id, m.id, key) } }
        }
        "type" -> OptRow(tr("dzc.tool.type"), "", back) {
            when (m.type) {
                "bed" -> BED_KINDS.forEach { b -> OptChip(tr("fb.bt.$b"), o.bed == b) { opt { it.copy(bed = b) } } }
                "bunk", "loft" -> {
                    listOf("L", "R").forEach { l -> OptChip(tr("fb.lad.$l"), o.ladder == l) { opt { it.copy(ladder = l) } } }
                    if (m.type == "loft") UNDER_KINDS.forEach { u -> OptChip(tr("fb.und.$u"), o.under == u) { if (u != o.under) app.kit.change(app, p.id, f.id) { x -> withUnder(x, u, app.settings.workshop) } } }
                }
                "table" -> {
                    LEG_KINDS.forEach { l -> OptChip(tr("fb.lg.$l"), o.legs == l) { opt { it.copy(legs = l) } } }
                    listOf("ldsp", "wt").forEach { t -> OptChip(tr("fb.tp.$t"), o.top == t) { opt { it.copy(top = t) } } }
                    OptChip(tr("fb.rc"), o.round) { opt { it.copy(round = !it.round) } }
                }
                "bar" -> {
                    listOf("ldsp", "wt").forEach { t -> OptChip(tr("fb.tp.$t"), o.top == t) { opt { it.copy(top = t) } } }
                    OptChip(tr("fb.shelves"), o.shelves) { opt { it.copy(shelves = !it.shelves) } }
                    OptChip(tr("fb.foot"), o.foot) { opt { it.copy(foot = !it.foot) } }
                }
                "hooks" -> {
                    OptStepper(tr("fb.hooks"), o.hooks, 0, 10) { v -> opt { it.copy(hooks = v) } }
                    OptChip(tr("fb.shelf"), o.shelf) { opt { it.copy(shelf = !it.shelf) } }
                }
                else -> OptNote(tr("dzc.partsNote"))
            }
        }
        "handle" -> OptRow(tr("dzc.tool.handle"), "", back) {
            OptChip(tr("hd.all"), false) { app.item(p, f, m.id) { uz.metrx.app.furniture.allHandles(it, true) } }
            OptChip(tr("dzc.h.push"), false) { app.item(p, f, m.id) { uz.metrx.app.furniture.allHandles(it, false) } }
            uz.metrx.app.furniture.handleFronts(m).forEach { fr ->
                val on = uz.metrx.app.furniture.hasHandle(m, fr.key)
                OptChip(frontName(m, fr) + " · " + tr(if (on) "hd.yes" else "hd.no"), on) { app.item(p, f, m.id) { uz.metrx.app.furniture.toggleHandle(it, fr.key) } }
            }
        }
        "decor" -> {
            val l = f.look
            val finish = l?.finish?.ifEmpty { null } ?: if (f.mats.front.startsWith("ag_")) "gloss" else "matte"
            val cur = uz.metrx.app.furniture.colourOf(f.mats.front)
            OptRow(tr("dzc.tool.decor"), tr("dzc.wholeW"), back) {
                FRONT_KEYS.forEach { (key, rgb, _) -> OptChip(frontName(app, key), cur == key, swatch = hex(rgb)) {
                    val b = uz.metrx.app.furniture.boardFor(key, finish, l?.style ?: "flat")
                    app.kit.change(app, p.id, f.id) { x -> uz.metrx.app.furniture.clearOwnFronts(uz.metrx.app.furniture.withLook(x) { it }).let { y -> y.copy(mats = y.mats.copy(front = b)) } }
                    app.dzcDone(p.id, f.id, app.t("dzc.decorAllW", "d" to frontName(app, key)))
                } }
            }
        }
        else -> back()
    }
}

/** The options of the piece's main box, by what it is. */
@Composable
internal fun ItemOptions(p: Project, f: Furniture, m: Module) {
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
            // the drawers' handles one by one (25 Oct 2026), or all at once
            if (o.bed == "drawers") {
                HandleButtons(listOf(m), { app.item(p, f, m.id) { uz.metrx.app.furniture.allHandles(it, true) } }, { app.item(p, f, m.id) { uz.metrx.app.furniture.allHandles(it, false) } })
                androidx.compose.foundation.layout.Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    uz.metrx.app.furniture.handleFronts(m).forEach { fr ->
                        val on = uz.metrx.app.furniture.hasHandle(m, fr.key)
                        Chip(frontName(m, fr) + " · " + tr(if (on) "hd.yes" else "hd.no"), on) { app.item(p, f, m.id) { uz.metrx.app.furniture.toggleHandle(it, fr.key) } }
                    }
                }
            }
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
        // the big dining table: its seats, legs, top and chairs (GorkaViews.kt)
        "table" -> if (o.seats > 0) BigTableOptions(p, f, m) else {
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
