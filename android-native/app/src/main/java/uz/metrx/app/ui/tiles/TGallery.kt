package uz.metrx.app.ui.tiles

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.walls
import uz.metrx.app.tiles.APRON_H0
import uz.metrx.app.tiles.APRON_H1
import uz.metrx.app.tiles.LOOKS
import uz.metrx.app.tiles.PLACES
import uz.metrx.app.tiles.T_MODELS
import uz.metrx.app.tiles.TILE_SIZES
import uz.metrx.app.tiles.TModel
import uz.metrx.app.tiles.TPanel
import uz.metrx.app.tiles.TSurf
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.layoutOf
import uz.metrx.app.tiles.tModel
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.furniture.Chip
import uz.metrx.app.ui.furniture.measuredRoom
import uz.metrx.app.ui.furniture.parseMm
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * Choosing a layout (22 Oct 2026): the gallery of layouts grouped by place, each card drawn by the app; then one
 * question a screen (the tile, the joint, where it starts, the second tile, the look, which room, which surfaces), the
 * layout shown on a corner of a room all along.
 */

private val JS = Json { ignoreUnknownKeys = true; encodeDefaults = true }

/** The gallery group a room's layouts start with: a bathroom's, a kitchen's backsplashes, else the floors. */
private fun placeFor(p: Project, rid: String?): String? {
    val r = rid?.let { id -> p.rooms.firstOrNull { it.id == id } } ?: return null
    return when (p.floors.firstOrNull { it.id == r.floorId }?.type) { "bath" -> "bath"; "kitchen" -> "apron"; else -> "floor" }
}

@Composable
private fun cardTitle(m: TModel) = if (m.accent) tr("tl.accentT") else tr("tl.p.${m.pattern}")

@Composable
private fun cardSub(m: TModel) = "${m.a} × ${m.b} · " + tr("tl.lk.${m.look}") + if (m.pattern == "chess" || m.pattern == "border" || m.accent) " + " + tr("tl.lk.${m.look2}") else ""

@Composable
fun TGalleryScreen(rt: Route.TGallery) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val room = rt.rid?.let { id -> p.rooms.firstOrNull { it.id == id } }
    val first = placeFor(p, rt.rid)
    val groups = PLACES.map { pl -> pl to T_MODELS.filter { it.place == pl } }.let { gs -> if (first == null) gs else gs.sortedBy { if (it.first == first) 0 else 1 } }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val tops = remember { mutableStateMapOf<String, Int>() }
    val dens = LocalDensity.current.density
    LaunchedEffect(Unit) { TilePics.make((200 * dens).toInt(), (170 * dens).toInt(), dens) }
    val cur = if (scroll.maxValue > 0 && scroll.value >= scroll.maxValue - 4) groups.last().first
        else groups.lastOrNull { (tops[it.first] ?: Int.MAX_VALUE) <= scroll.value + 60 }?.first ?: groups.first().first
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        PageBar(frosted = true) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
            Spacer(Modifier.width(6.dp))
            BarTitle(tr("tl.galT"), eyebrow = dn(p.name, lang))
        }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            groups.forEach { (g, _) ->
                val on = g == cur
                Text(tr("tl.pl.$g"), style = ui(14f, 700, if (on) G.solid else G.ink), maxLines = 1,
                    modifier = Modifier.heightIn(min = 40.dp).clip(CircleShape).background(if (on) G.ink else G.glass(.55f)).semantics { selected = on }
                        .clickable(role = Role.Tab) { scope.launch { scroll.animateScrollTo(tops[g] ?: 0) } }.padding(horizontal = 16.dp, vertical = 10.dp))
            }
        }
        Column(Modifier.weight(1f).verticalScroll(scroll).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (room != null) {
                val f = { mm: Int? -> fmtLen(mm, LenUnit.M, en) }
                Text(tr("tl.forRoom", "r" to (p.floors.firstOrNull { it.id == room.floorId }?.let { floorName(it, lang) } ?: dn(room.name, lang)),
                    "a" to f(room.dim("A").v), "b" to f(room.dim("B").v), "h" to f(room.dim("H").v)), style = ui(13.5f, 400, G.ink2, 1.4f))
            } else Text(tr("tl.galB"), style = ui(13.5f, 400, G.ink2, 1.4f))
            groups.forEach { (g, ms) ->
                Row(Modifier.padding(top = 8.dp, start = 2.dp).onGloballyPositioned { tops[g] = it.positionInParent().y.toInt() }, verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("tl.pl.$g"), style = ui(17f, 800))
                    Text("${ms.size}", style = ui(12.5f, 500, G.ink3))
                }
                ms.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { m -> ModelCard(m, Modifier.weight(1f).fillMaxHeight(), wide = row.size == 1) { app.push(Route.TSteps(p.id, m.id, rid = rt.rid)) } }
                    }
                }
            }
            if (rt.fromNew) Text(tr("fz.needL"), style = ui(14.5f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp)
                .clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { app.pop() }.padding(horizontal = 16.dp, vertical = 12.dp))
        }
    }
}

@Composable
private fun ModelCard(m: TModel, modifier: Modifier, wide: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    val name = cardTitle(m)
    val pic: @Composable (Modifier) -> Unit = { pm ->
        Box(pm.aspectRatio(200f / 170f).clip(RoundedCornerShape(14.dp)).background(Color(0xFFF6F8FC)), contentAlignment = Alignment.Center) {
            val img = TilePics.pics[m.id]
            if (img != null) Image(img, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) else Text("3D…", style = ui(11f, 600, G.ink3))
        }
    }
    val words: @Composable () -> Unit = {
        Column(Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(name, style = ui(14.5f, 800, G.ink), maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(cardSub(m), style = ui(12f, 500, G.ink2, 1.3f), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
    val mod = modifier.clip(shape).glassCard(shape, fill = G.glass(.62f)).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = name }.padding(8.dp)
    if (wide) Row(mod, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        pic(Modifier.weight(1f)); Box(Modifier.weight(1f)) { words() }
    } else Column(mod, verticalArrangement = Arrangement.spacedBy(6.dp)) { pic(Modifier.fillMaxWidth()); words() }
}

/* ---------------- the steps ---------------- */

/** The surfaces a new layout covers in room [r]: the floor, every wall (with the baths' fronts), or a backsplash band. */
fun defaultSurfs(l: TileLayout, r: Room?, p: Project, snap: Boolean): List<TSurf> {
    if (r == null) return emptyList()
    val m = tModel(l.model)
    val ws = walls(r, snap)
    return when (m?.surf ?: if (l.place == "floor") "floor" else "walls") {
        "floor" -> listOf(TSurf("floor"))
        "apron" -> listOf(TSurf(ws.first().id, "band", APRON_H0, APRON_H1))
        else -> ws.mapIndexed { i, w -> TSurf(w.id, alt = l.accent && i == 0) } +
            (if (l.place == "bath") tileRoomOf(p, r.id).fixes.filter { it.type == "bath" }.map { TSurf("bath:${it.id}") } else emptyList())
    }
}

/** A new layout's panel for a surface without a room, by its place. */
private fun panelFor(place: String) = when (place) { "floor" -> TPanel("floor", 3000, 2000); "apron" -> TPanel("apron", 2400, 600); else -> TPanel("wall", 2500, 2400) }

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TStepsScreen(rt: Route.TSteps) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val p = app.store.get(rt.pid) ?: return
    val snap = app.settings.angleSnap
    val edit = rt.lid?.let { id -> p.tiles.firstOrNull { it.id == id } }
    val m = tModel(rt.model)
    if (edit == null && m == null) return
    val start = remember(rt) {
        edit ?: layoutOf(m!!, uid(), System.currentTimeMillis()).let { l ->
            val r = rt.rid?.let { id -> p.rooms.firstOrNull { it.id == id } }
            l.copy(roomId = r?.id, surfs = defaultSurfs(l, r, p, snap))
        }
    }
    var js by rememberSaveable(rt) { mutableStateOf(JS.encodeToString(TileLayout.serializer(), start)) }
    val d = remember(js) { JS.decodeFromString(TileLayout.serializer(), js) }
    fun set(f: (TileLayout) -> TileLayout) { js = JS.encodeToString(TileLayout.serializer(), f(d)) }
    val steps = remember(d.pattern, d.place) {
        buildList {
            add("size"); add("joint"); add("start")
            if (d.pattern == "chess" || d.pattern == "border" || d.place != "floor") add("second")
            add("look")
            if (rt.lid == null && rt.rid == null) add("where")
            add("surf")
        }
    }
    val n = steps.size
    var at by rememberSaveable(rt) { mutableIntStateOf(0) }
    val step = steps[at.coerceIn(0, n - 1)]
    val room = d.roomId?.let { id -> p.rooms.firstOrNull { it.id == id } }
    val pv = remember(js) { previewOf(d) }
    val surfOk = if (d.roomId != null) d.surfs.isNotEmpty() else (d.panel?.let { it.a > 0 && it.b > 0 } == true)
    fun ok(s: String) = when (s) { "size" -> d.a in 20..3000 && d.b in 20..3000; "where" -> d.roomId != null || d.panel != null; "surf" -> surfOk; else -> true }
    fun prev() { if (at > 0) at -= 1 else app.pop() }
    BackHandler { prev() }
    fun save() {
        if (!steps.all { ok(it) } || !app.once()) return
        // the short side first, whatever was typed
        val l = d.copy(a = minOf(d.a, d.b), b = maxOf(d.a, d.b), panel = if (d.roomId == null) d.panel else null)
        if (edit != null) {
            app.updateLayout(p.id, l.id) { l }
            app.pop(); app.say("tl.saved")
        } else {
            app.store.update(p.id) { pr -> pr.copy(tiles = pr.tiles + l, stage = pr.stage) }
            app.popTo { it is Route.Project && it.id == p.id }
            app.push(Route.TView(p.id, l.roomId, l.id))
            app.say("tl.added", "n" to app.t(placeKey(l)))
        }
    }
    val imeOn = WindowInsets.isImeVisible
    val footer: @Composable (Modifier) -> Unit = { mm ->
        FloatingFooter(mm) {
            if (at < n - 1) GBtn(tr("common.next"), { if (ok(step)) at += 1 }, enabled = ok(step))
            else GBtn(tr("common.save"), ::save, enabled = steps.all { ok(it) })
        }
    }
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), ::prev, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(tr("tl.p.${d.pattern}"), eyebrow = tr("tl.stepN", "i" to at + 1, "n" to n))
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = if (imeOn) 16.dp else 120.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.align(Alignment.CenterHorizontally), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (0 until n).forEach { i ->
                        Box(Modifier.size(if (i == at) 22.dp else 8.dp, 8.dp).clip(CircleShape).background(when { i == at -> G.cobalt; i < at -> G.cobalt.copy(alpha = .45f); else -> G.ink.copy(alpha = .15f) }))
                    }
                }
                if (step != "where" && step != "surf") Box(Modifier.fillMaxWidth().aspectRatio(if (imeOn) 2.1f else 1.25f).clip(RoundedCornerShape(22.dp)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                    PreviewView(pv, Modifier.fillMaxSize())
                    Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                }
                when (step) {
                    "size" -> SizeStep(d) { v -> set(v) }
                    "joint" -> Ask(tr("tl.s.joint"), tr("tl.s.jointH")) {
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            (1..5).forEach { j -> Chip(tr("tl.jointV", "n" to j), d.joint == j) { set { it.copy(joint = j) } } }
                        }
                    }
                    "start" -> Ask(tr("tl.s.start"), tr("tl.s.startH")) {
                        listOf("center", "corner", "door").forEach { k -> Option(tr("tl.st.$k"), tr("tl.st.${k}S"), d.start == k) { set { it.copy(start = k, ox = 0, oy = 0) } } }
                        Text(tr("tl.s.rot"), style = ui(15f, 700), modifier = Modifier.padding(top = 6.dp))
                        Seg(listOf("0" to "0°", "90" to "90°", "45" to "45°"), d.rot.toString()) { v -> set { it.copy(rot = v.toInt()) } }
                    }
                    "second" -> SecondStep(d) { v -> set(v) }
                    "look" -> Ask(tr("tl.s.look"), tr("tl.s.lookH")) { LookGrid(d.look) { id -> set { it.copy(look = id) } } }
                    "where" -> WhereStep(p, d, lang, snap) { v -> set(v); if (v(d).roomId != null || v(d).panel != null) at += 1 }
                    "surf" -> if (d.roomId != null && room != null) SurfStep(p, room, d, snap) { v -> set(v) } else PanelStep(d) { v -> set(v) }
                }
            }
            if (imeOn) footer(Modifier)
        }
        if (!imeOn) footer(Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun Ask(title: String, help: String, body: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = ui(21f, 800, G.ink, 1.2f), modifier = Modifier.padding(top = 4.dp))
        Text(help, style = ui(13f, 400, G.ink2, 1.4f))
        body()
    }
}

/** One choice as a card with a line under it. */
@Composable
private fun Option(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(shape).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.75f))
        .border(if (on) 2.dp else 1.dp, if (on) G.cobalt else G.rim, shape).semantics { selected = on }
        .clickable(role = Role.RadioButton, onClick = onClick).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(20.dp).clip(CircleShape).border(2.dp, if (on) G.cobalt else G.ink3, CircleShape), contentAlignment = Alignment.Center) {
            if (on) Box(Modifier.size(10.dp).clip(CircleShape).background(G.cobalt))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(15f, 700, if (on) G.cobalt2 else G.ink))
            Text(sub, style = ui(12.5f, 400, G.ink2, 1.35f))
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SizeStep(d: TileLayout, set: ((TileLayout) -> TileLayout) -> Unit) {
    val listed = TILE_SIZES.any { (a, b) -> (d.a == a && d.b == b) || (d.a == b && d.b == a) }
    var custom by rememberSaveable { mutableStateOf(!listed) }
    Ask(tr("tl.s.size"), tr("tl.s.sizeH")) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            TILE_SIZES.forEach { (a, b) -> Chip("$a × $b", !custom && d.a == a && d.b == b) { custom = false; set { it.copy(a = a, b = b) } } }
            Chip(tr("tl.custom"), custom) { custom = true }
        }
        if (custom) {
            var ta by rememberSaveable { mutableStateOf(d.a.toString()) }
            var tb by rememberSaveable { mutableStateOf(d.b.toString()) }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                val ea = ta.toIntOrNull()?.takeIf { it in 20..3000 } == null; val eb = tb.toIntOrNull()?.takeIf { it in 20..3000 } == null
                GField(tr("tl.side1"), ta, { v -> ta = v.filter { it.isDigit() }.take(4); ta.toIntOrNull()?.takeIf { it in 20..3000 }?.let { x -> set { it.copy(a = x) } } }, "300",
                    number = true, labelRight = "mm", error = if (ea) tr("tl.sizeErr") else null, showError = true, modifier = Modifier.weight(1f))
                GField(tr("tl.side2"), tb, { v -> tb = v.filter { it.isDigit() }.take(4); tb.toIntOrNull()?.takeIf { it in 20..3000 }?.let { x -> set { it.copy(b = x) } } }, "600",
                    number = true, labelRight = "mm", error = if (eb) tr("tl.sizeErr") else null, showError = true, modifier = Modifier.weight(1f))
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SecondStep(d: TileLayout, set: ((TileLayout) -> TileLayout) -> Unit) {
    val needs = d.pattern == "chess" || d.pattern == "border"
    Ask(tr(if (needs) "tl.s.second" else "tl.s.accent"), tr(when (d.pattern) { "chess" -> "tl.s.secondC"; "border" -> if (d.place == "floor") "tl.s.secondB" else "tl.s.secondF"; else -> "tl.s.accentH" })) {
        if (!needs) Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.75f)).clickable(role = Role.Switch) { set { it.copy(accent = !it.accent) } }
            .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(tr("tl.accentOn"), style = ui(15f, 700), modifier = Modifier.weight(1f)); GSwitch(d.accent)
        }
        if (d.pattern == "border") {
            Text(tr("tl.s.strip"), style = ui(15f, 700))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(0 to 0, 100 to 300, 200 to 600, 200 to 200, 300 to 600).forEach { (a, b) ->
                    Chip(if (a == 0) tr("tl.sameTile") else "$a × $b", d.a2 == a && d.b2 == b) { set { it.copy(a2 = a, b2 = b) } }
                }
            }
            if (d.place != "floor") {
                Text(tr("tl.s.bandAt"), style = ui(15f, 700))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(900, 1200, 1500, 1800).forEach { h -> Chip(fmtLen(h, LenUnit.M, LocalLang.current == Lang.EN) + " m", d.band == h) { set { it.copy(band = h) } } }
                }
            }
        }
        if (needs || d.accent) { Text(tr("tl.s.look2"), style = ui(15f, 700)); LookGrid(d.look2) { id -> set { it.copy(look2 = id) } } }
    }
}

/** The looks: colours, then the drawn marbles, woods and concretes. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun LookGrid(cur: String, onPick: (String) -> Unit) {
    listOf("c", "m", "w", "k").forEach { kind ->
        Text(tr("tl.lkk.$kind"), style = ui(13.5f, 700, G.ink2), modifier = Modifier.padding(top = 4.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            LOOKS.filter { it.kind == kind }.forEach { lk ->
                val on = lk.id == cur
                Column(Modifier.width(72.dp).clip(RoundedCornerShape(14.dp)).semantics { selected = on }.clickable(role = Role.RadioButton) { onPick(lk.id) }.padding(2.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)).border(if (on) 3.dp else 1.dp, if (on) G.cobalt else G.rim, RoundedCornerShape(12.dp)).padding(if (on) 3.dp else 0.dp)) {
                        LookSwatch(lk.id, Modifier.fillMaxSize().clip(RoundedCornerShape(9.dp)))
                    }
                    Text(tr("tl.lk.${lk.id}"), style = ui(11.5f, if (on) 700 else 500, if (on) G.cobalt2 else G.ink2, 1.15f), maxLines = 2, overflow = TextOverflow.Ellipsis,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                }
            }
        }
    }
}

/** Which room the layout goes in, a new room, or none (typed sizes). */
@Composable
private fun WhereStep(p: Project, d: TileLayout, lang: Lang, snap: Boolean, set: ((TileLayout) -> TileLayout) -> Unit) {
    val app = LocalApp.current
    val en = lang == Lang.EN
    Ask(tr("fq.title"), tr("tl.s.whereH")) {
        p.rooms.forEach { r ->
            val w = p.floors.firstOrNull { it.id == r.floorId }
            val on = d.roomId == r.id
            val ready = measuredRoom(r, snap)
            Option(w?.let { floorName(it, lang) } ?: dn(r.name, lang), if (ready && !r.isPoly) fmtLen(r.dim("A").v, LenUnit.M, en) + " × " + fmtLen(r.dim("B").v, LenUnit.M, en) + " m"
                else tr(if (ready) "tl.measured" else "fo.notMeasured"), on) {
                set { it.copy(roomId = r.id, panel = null, surfs = defaultSurfs(it, r, p, snap)) }
            }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(16.dp)).dashedGlass(16.dp).clickable(role = Role.Button) {
            if (!app.once()) return@clickable
            val type = when (d.place) { "bath" -> "bath"; "apron" -> "kitchen"; else -> "living" }
            val base = app.t(roomKey(type)); val k = p.floors.count { it.name.startsWith(base) }
            val rid = app.addTileRoom(p.id, type, if (k > 0) "$base ${k + 1}" else base)
            val r = app.store.get(p.id)?.rooms?.firstOrNull { it.id == rid }
            set { it.copy(roomId = rid, panel = null, surfs = defaultSurfs(it, r, p, snap)) }
        }.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MIcon("plus", G.cobalt2, 22.dp, 2.2f)
            Column(Modifier.weight(1f)) {
                Text(tr("fz.newRoom"), style = ui(15f, 700, G.cobalt2))
                Text(tr("tl.s.newRoomS"), style = ui(12.5f, 400, G.ink2))
            }
        }
        Option(tr("tl.s.noRoom"), tr("tl.s.noRoomS"), d.roomId == null && d.panel != null) { set { it.copy(roomId = null, surfs = emptyList(), panel = it.panel ?: panelFor(it.place)) } }
    }
}

/** Which of the room's surfaces the layout covers: the floor, each wall in full, up to a height or as a band, a bath's front. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SurfStep(p: Project, r: Room, d: TileLayout, snap: Boolean, set: ((TileLayout) -> TileLayout) -> Unit) {
    val app = LocalApp.current
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    fun toggle(id: String, mk: () -> TSurf) = set { l -> if (l.surfs.any { it.id == id }) l.copy(surfs = l.surfs.filter { it.id != id }) else l.copy(surfs = l.surfs + mk()) }
    fun change(s: TSurf) = set { l -> l.copy(surfs = l.surfs.map { if (it.id == s.id) s else it }) }
    Ask(tr("tl.s.surf"), tr("tl.s.surfH")) {
        Check(tr("tl.pk.floor"), null, d.surfs.any { it.id == "floor" }) { toggle("floor") { TSurf("floor") } }
        walls(r, snap).forEach { w ->
            val s = d.surfs.firstOrNull { it.id == w.id }
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.glass(.6f)).padding(bottom = if (s != null) 10.dp else 0.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Check(tr("tl.wallN", "w" to w.id), w.len?.let { fmtLen(it, LenUnit.M, en) + " m" }, s != null) { toggle(w.id) { TSurf(w.id) } }
                if (s != null) Column(Modifier.padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Seg(listOf("full" to tr("tl.m.full"), "to" to tr("tl.m.to"), "band" to tr("tl.m.band")), s.mode) { m ->
                        change(when (m) { "to" -> s.copy(mode = "to", h0 = 0, h1 = if (s.h1 > 0) s.h1 else 1500); "band" -> s.copy(mode = "band", h0 = if (s.h0 > 0) s.h0 else APRON_H0, h1 = if (s.h1 > s.h0 && s.h1 > 0) s.h1 else APRON_H1); else -> s.copy(mode = "full") })
                    }
                    if (s.mode != "full") Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (s.mode == "band") HeightField(tr("tl.h0"), s.h0, unit, en, uw, "${w.id}0", Modifier.weight(1f)) { v -> change(s.copy(h0 = v)) }
                        HeightField(tr(if (s.mode == "band") "tl.h1b" else "tl.h1"), s.h1, unit, en, uw, "${w.id}1", Modifier.weight(1f)) { v -> change(s.copy(h1 = v)) }
                    }
                    if (d.accent) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable(role = Role.Switch) { change(s.copy(alt = !s.alt)) }.padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically) { Text(tr("tl.accentWall"), style = ui(14f, 600), modifier = Modifier.weight(1f)); GSwitch(s.alt) }
                }
            }
        }
        tileRoomOf(p, r.id).fixes.filter { it.type == "bath" }.forEach { f ->
            Check(tr("tl.bathFront"), tr("tl.wallN", "w" to f.wall), d.surfs.any { it.id == "bath:${f.id}" }) { toggle("bath:${f.id}") { TSurf("bath:${f.id}") } }
        }
        if (d.surfs.isEmpty()) Text(tr("tl.s.surfNone"), style = ui(13f, 500, G.err))
    }
}

/** A height typed in the app's unit; the layout takes it once it reads as a length. */
@Composable
private fun HeightField(label: String, mm: Int, unit: LenUnit, en: Boolean, uw: String, key: String, modifier: Modifier, onMm: (Int) -> Unit) {
    var t by rememberSaveable(key) { mutableStateOf(if (mm > 0) fmtField(mm, unit, en) else "") }
    val v = parseMm(t, unit)
    GField(label, t, { s -> t = s.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7); parseMm(t, unit)?.takeIf { it <= 20_000 }?.let(onMm) }, "1,5",
        decimal = true, labelRight = uw, error = if (v == null) tr("tl.sizeErr") else null, showError = t.isNotEmpty(), modifier = modifier)
}

@Composable
private fun Check(title: String, sub: String?, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(if (on) G.cobalt.copy(alpha = .08f) else G.glass(.6f))
        .semantics { selected = on }.clickable(role = Role.Checkbox, onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(24.dp).clip(RoundedCornerShape(7.dp)).background(if (on) G.cobalt else Color.Transparent).border(2.dp, if (on) G.cobalt else G.ink3, RoundedCornerShape(7.dp)),
            contentAlignment = Alignment.Center) { if (on) MIcon("check", Color.White, 14.dp, 3f) }
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(15f, 700))
            if (sub != null) Text(sub, style = num(12.5f, 500, G.ink2))
        }
    }
}

/** A surface without a room: a floor, a wall or a backsplash, and its two sizes. */
@Composable
private fun PanelStep(d: TileLayout, set: ((TileLayout) -> TileLayout) -> Unit) {
    val app = LocalApp.current
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    val pn = d.panel ?: panelFor(d.place)
    Ask(tr("tl.s.panel"), tr("tl.s.panelH")) {
        Seg(listOf("floor" to tr("tl.pk.floor"), "wall" to tr("tl.pk.wall"), "apron" to tr("tl.pk.apron")), pn.kind) { k -> set { it.copy(panel = panelFor(k).copy(a = pn.a)) } }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HeightField(tr("tl.pa"), pn.a, unit, en, uw, "pa" + pn.kind, Modifier.weight(1f)) { v -> set { it.copy(panel = pn.copy(a = v)) } }
            HeightField(tr(if (pn.kind == "floor") "tl.pbW" else "tl.pbH"), pn.b, unit, en, uw, "pb" + pn.kind, Modifier.weight(1f)) { v -> set { it.copy(panel = pn.copy(b = v)) } }
        }
    }
}
