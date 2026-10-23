package uz.metrx.app.ui.tiles

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.geo.walls
import uz.metrx.app.tiles.TFix
import uz.metrx.app.tiles.TileCount
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.TileRoom
import uz.metrx.app.tiles.countOrder
import uz.metrx.app.tiles.tileRows
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassHeader
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.furniture.CallButton
import uz.metrx.app.ui.furniture.Chip
import uz.metrx.app.ui.furniture.measuredRoom
import uz.metrx.app.ui.furniture.openRoom
import uz.metrx.app.ui.furniture.parseMm
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.glass.topHighlight
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.icons.PathIcon
import uz.metrx.app.ui.main.MainNav
import uz.metrx.app.ui.main.NAV_SPACE
import uz.metrx.app.ui.main.Tab
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.Theme
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui

/*
 * The tiler's own app (22 Oct 2026, built like the furniture maker's): the Home with new orders, an order's rooms with
 * their tile layouts, the next step, and in the advanced app the counted tiles going into the estimate.
 */

private const val RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private const val ARROW = "M7 17L17 7M9 7h8v8"
const val TILE_ICON = "M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z"

/* ---------------- names ---------------- */

/** "Pol · Archa" — where a layout goes and its pattern. */
@Composable
fun layoutTitle(l: TileLayout): String = tr(placeKey(l)) + " · " + tr("tl.p.${l.pattern}")

/** Where a layout goes, in words: the floor, the walls, a backsplash, a typed surface. */
fun placeKey(l: TileLayout): String {
    l.panel?.takeIf { l.roomId == null }?.let { return "tl.pk.${it.kind}" }
    val ids = l.surfs.map { it.id }
    return when {
        ids.isEmpty() -> "tl.pl.${l.place}"
        ids.all { it == "floor" } -> "tl.pk.floor"
        "floor" in ids -> "tl.su.both"
        l.surfs.all { it.mode == "band" } -> "tl.pk.apron"
        else -> "tl.su.walls"
    }
}

/** "300 × 600 · 2 mm" — the tile and the joint. */
@Composable
fun layoutSub(l: TileLayout): String = "${l.a} × ${l.b} · " + tr("tl.jointV", "n" to l.joint) + (if (l.rot != 0) " · ${l.rot}°" else "")

/* ---------------- rooms made behind the scenes ---------------- */

/** The rooms a tiler adds (string keys): a bathroom first. */
val T_ROOMS = listOf("bath", "toilet", "kitchen", "hall", "living", "balcony", "other")

fun roomKey(t: String) = when (t) { "toilet" -> "tl.r.toilet"; "balcony" -> "tl.r.balcony"; else -> "fr.$t" }

/** A workspace with a rectangular room in it, named [name]; returns the room's id. */
fun App.addTileRoom(pid: String, type: String, name: String): String {
    val now = System.currentTimeMillis()
    val wt = when (type) { "bath", "toilet" -> "bath"; "kitchen" -> "kitchen"; "balcony" -> "balcony"; else -> "room" }
    val w = Workspace(uid(), name, type = wt, created = now)
    val r = Room(uid(), w.id, name, created = now)
    store.update(pid) { it.copy(floors = it.floors + w, rooms = it.rooms + r) }
    return r.id
}

/** A room's extras, made when first needed. */
fun tileRoomOf(p: Project, rid: String) = p.troom.firstOrNull { it.roomId == rid } ?: TileRoom(rid)

fun App.updateTileRoom(pid: String, rid: String, f: (TileRoom) -> TileRoom) {
    store.update(pid) { p -> val cur = tileRoomOf(p, rid); p.copy(troom = p.troom.filter { it.roomId != rid } + f(cur)) }
}

fun App.updateLayout(pid: String, lid: String, f: (TileLayout) -> TileLayout) {
    store.update(pid) { p -> p.copy(tiles = p.tiles.map { if (it.id == lid) f(it) else it }) }
}

/* ---------------- Home ---------------- */

@Composable
fun TilerHome(nav: MainNav) {
    val app = LocalApp.current
    val s = app.settings
    val first = s.builderName.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
    val lines = tr("tl.lines").split('|')
    val orders = app.store.projects.filter { it.isTiler }.sortedByDescending { it.created }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        GlassHeader(nav::laser)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 24.dp + NAV_SPACE).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.padding(top = 18.dp, bottom = 8.dp)) {
                Text(if (first.isNotEmpty()) tr("hm.hi", "n" to first) else tr("hm.hi0"), style = ui(34f, 800, G.ink, 1.1f, -.02f))
                Text(lines[s.visit % lines.size], style = ui(17f, 500, G.slate, 1.35f), modifier = Modifier.padding(top = 8.dp).widthIn(max = 320.dp))
            }
            val big = RoundedCornerShape(30.dp)
            Row(Modifier.fillMaxWidth().glassCard(big, shadowRadius = 36.dp, shadowY = 16.dp, shadowAlpha = .15f).pressable(nav::newProject).padding(18.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(56.dp).dropShadow(RoundedCornerShape(20.dp), Shadow(22.dp, G.cobalt.copy(alpha = .4f), offset = DpOffset(0.dp, 10.dp)))
                    .clip(RoundedCornerShape(20.dp)).background(G.cobalt).topHighlight(.45f), contentAlignment = Alignment.Center) { MIcon("plus", Color.White, 26.dp, 2.4f) }
                Column(Modifier.weight(1f)) {
                    Text(tr("fo.new"), style = ui(22f, 800, G.ink, 1.15f, -.01f))
                    Text(tr("tl.newS"), style = ui(14f, 400, G.ink2))
                }
                PathIcon(ARROW, G.ink, 20.dp, 2.2f)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Tile(RULER, tr("gl.meas"), tr("gl.measS"), nav::measure, Modifier.weight(1f))
                Tile(TILE_ICON, tr("tl.gal"), tr("tl.galS"), {
                    // the gallery needs an order: a new one, as on the big card
                    nav.newProject()
                }, Modifier.weight(1f))
            }
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("fo.recent"), style = ui(17f, 800), modifier = Modifier.weight(1f))
                if (orders.isNotEmpty()) Text(tr("fo.all"), style = ui(13.5f, 700, G.cobalt2),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.selectTab(Tab.PROJECTS) }.padding(horizontal = 6.dp, vertical = 8.dp))
            }
            if (orders.isEmpty()) Text(tr("fo.noOrders"), style = ui(14f, 400, G.ink2, 1.45f))
            orders.take(3).forEach { p -> TOrderRow(p) { app.push(Route.Project(p.id)) } }
        }
    }
}

@Composable
private fun Tile(icon: String, title: String, sub: String, onClick: () -> Unit, modifier: Modifier) {
    Column(modifier.heightIn(min = 112.dp).glassCard(RoundedCornerShape(26.dp)).pressable(onClick).padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
        PathIcon(icon, G.cobalt, 24.dp, 2f)
        Spacer(Modifier.height(18.dp))
        Text(title, style = ui(17f, 700)); Text(sub, style = ui(12.5f, 400, G.ink2))
    }
}

/** A tiler's order in a list: its name, who, its layouts; the call button. */
@Composable
fun TOrderRow(p: Project, onClick: () -> Unit) {
    val lang = LocalLang.current
    Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp)).pressable(onClick).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp))) {
            val l = p.tiles.firstOrNull()
            if (l != null) LookSwatch(l.look, Modifier.fillMaxSize()) else Box(Modifier.fillMaxSize().background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(TILE_ICON, G.cobalt, 22.dp, 2f) }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(dn(p.name, lang), style = ui(15f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
            val sub = if (p.tiles.isEmpty()) tr("tl.noLayouts") else p.tiles.map { layoutTitle(it) }.distinct().joinToString(", ")
            Text(sub, style = ui(12.5f, 500, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        CallButton(p)
    }
}

/* ---------------- the order's rooms and their layouts ---------------- */

@Composable
fun TRoomsTab(p: Project, lang: Lang, route: Route.Project) {
    val app = LocalApp.current
    val s = app.settings
    val en = lang == Lang.EN
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (p.floors.isEmpty() && p.tiles.isEmpty()) Text(tr("tl.empty"), style = ui(14.5f, 400, G.ink2), textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(22.dp))
        // every room of each workspace (an older project may have several in one), a workspace without one once
        p.floors.flatMap { w -> p.rooms.filter { it.floorId == w.id }.ifEmpty { listOf(null) }.map { w to it } }.forEach { (w, room) ->
            val several = p.rooms.count { it.floorId == w.id } > 1
            val measured = room != null && measuredRoom(room, s.angleSnap)
            val ls = if (room == null) emptyList() else p.tiles.filter { it.roomId == room.id }
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable { if (room != null) (if (measured) app.push(Route.TView(p.id, room.id)) else app.openRoom(p.id, room.id)) else app.push(Route.Space(p.id, w.id)) },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(64.dp, 52.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = if (Theme.dark) .1f else .8f)), contentAlignment = Alignment.Center) {
                        if (room != null) uz.metrx.app.editorThumb(room, Modifier.fillMaxSize().padding(4.dp)) else MIcon("room", G.cobalt, 24.dp, 2f)
                    }
                    Column(Modifier.weight(1f)) {
                        Text(floorName(w, lang) + (if (several && room != null) " · " + dn(room.name, lang) else ""), style = ui(16f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        val a = room?.dim("A")?.v; val b = room?.dim("B")?.v; val h = room?.dim("H")?.v
                        Text(if (measured && a != null && b != null && room?.isPoly != true) fmtLen(a, LenUnit.M, en) + " × " + fmtLen(b, LenUnit.M, en) + " " + tr("u.m") + (h?.let { " · h " + fmtLen(it, LenUnit.M, en) } ?: "")
                            else if (measured) tr("tl.measured") else tr(if (room != null) "fo.notMeasured" else "fo.notDrawn"), style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (measured) Text("3D", style = ui(13f, 800, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(G.cobalt.copy(alpha = .1f)).padding(horizontal = 10.dp, vertical = 6.dp))
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
                ls.forEach { l -> LayoutLine(l) { app.push(Route.TView(p.id, l.roomId, l.id)) } }
                when {
                    room == null -> TodoRow(tr("fo.drawRoom")) { app.drawTileRoom(p.id, w, lang) }
                    !measured -> TodoRow(tr("ns.measureT")) { app.openRoom(p.id, room.id) }
                    else -> TodoRow(tr("tl.addLayout")) { app.push(Route.TGallery(p.id, room.id)) }
                }
                val n = w.items.size
                if (n > 0 || room != null) Text(tr("fo.photos") + if (n > 0) " · $n" else "", style = ui(13f, 600, G.cobalt2),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.push(Route.Space(p.id, w.id)) }.padding(horizontal = 4.dp, vertical = 6.dp))
            }
        }
        // layouts typed by their sizes, without a room
        val loose = p.tiles.filter { it.roomId == null }
        if (loose.isNotEmpty()) Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(tr("tl.noRoomT"), style = ui(16f, 700))
            loose.forEach { l -> LayoutLine(l) { app.push(Route.TView(p.id, null, l.id)) } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.push(Route.TGallery(p.id)) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("tl.addLayout"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.sheet = Sheet.TNewRoom(p.id) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("room", G.cobalt2, 20.dp, 2f); Text(tr("fo.addRoom"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
        }
        if (p.rooms.isNotEmpty() && route.view == "list") GBtn(tr("pj.v2d"), { app.setTop(route.copy(view = "2d")) }, Btn.SECONDARY, icon = "room", height = 46.dp, fontSize = 14.5f)
    }
}

/** One layout under its room: the tile's swatch, where and how, the tile and joint. */
@Composable
fun LayoutLine(l: TileLayout, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable(onClick = onClick).padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        LookSwatch(l.look, Modifier.size(34.dp).clip(RoundedCornerShape(8.dp)))
        Column(Modifier.weight(1f)) {
            Text(layoutTitle(l), style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(layoutSub(l), style = num(12.5f, 500, G.ink2), maxLines = 1)
        }
        MIcon("chev", G.ink3, 16.dp, 2f)
    }
}

@Composable
private fun TodoRow(label: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).dashedGlass(14.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MIcon("plus", G.cobalt2, 18.dp, 2.2f)
        Text(label, style = ui(14.5f, 700, G.cobalt2))
    }
}

/** Draws the first room of a workspace that has none yet. */
fun App.drawTileRoom(pid: String, w: Workspace, lang: Lang) {
    // a second tap does not add a second room
    store.get(pid)?.rooms?.firstOrNull { it.floorId == w.id }?.let { openRoom(pid, it.id); return }
    if (!once()) return
    val r = Room(uid(), w.id, floorName(w, lang), created = System.currentTimeMillis())
    store.update(pid) { it.copy(rooms = it.rooms + r) }
    openRoom(pid, r.id)
}

/* ---------------- the next step ---------------- */

/** What to do now with a tiler's order, and the one button that does it. */
@Composable
fun TNextStep(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val rooms = uz.metrx.app.data.roomsByWorkspace(p)
    val undrawn = p.floors.firstOrNull { w -> p.rooms.none { it.floorId == w.id } }
    val unmeasured = rooms.firstOrNull { (_, r) -> stepKeys(r, s.angleSnap).any { r.dim(it).status != "conf" } }
    val bare = rooms.firstOrNull { (_, r) -> p.tiles.none { it.roomId == r.id } }
    val made = uz.metrx.app.trades.madeBy(p, "tl.e.")
    data class Step(val title: String, val sub: String?, val button: String, val go: () -> Unit)
    val step: Step? = when {
        p.floors.isEmpty() && p.tiles.isEmpty() -> Step(tr("tl.ns.pickT"), tr("tl.ns.pickS"), tr("ns.needB")) { app.push(Route.TGallery(p.id)) }
        undrawn != null -> Step(tr("ns.measureT"), floorName(undrawn, lang), tr("fo.drawRoom")) { app.drawTileRoom(p.id, undrawn, lang) }
        unmeasured != null -> Step(tr("ns.measureT"), tr("ns.measureS", "r" to floorName(unmeasured.first, lang)), tr("ns.measureB")) { app.openRoom(p.id, unmeasured.second.id) }
        bare != null -> Step(tr("tl.ns.roomT", "r" to floorName(bare.first, lang)), tr("tl.ns.roomS"), tr("ns.needB")) { app.push(Route.TGallery(p.id, bare.second.id)) }
        p.tiles.isEmpty() -> Step(tr("tl.ns.pickT"), tr("tl.ns.pickS"), tr("ns.needB")) { app.push(Route.TGallery(p.id)) }
        !s.advanced -> Step(tr("ns.shareT"), tr("ns.shareS"), tr("ns.shareB")) { app.push(Route.Report(p.id)) }
        !made -> Step(tr("tl.ns.estT"), tr("tl.ns.estS"), tr("trc.apply")) { app.applyTiles(p); app.setProjectTab("estimate") }
        p.quotes.isEmpty() -> Step(tr("ns.quoteT"), null, tr("ns.quoteB")) { app.sheet = Sheet.Issue(p.id) }
        else -> null
    }
    if (step == null) return
    Row(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(if (Theme.dark) G.blueWash else Color(0xFF0F1626))
        .padding(start = 16.dp, end = 10.dp, top = 12.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tr("ns.label"), style = ui(11.5f, 600, Color.White.copy(alpha = .62f)))
            Text(step.title, style = ui(15.5f, 800, Color.White, 1.25f), maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (step.sub != null) Text(step.sub, style = ui(12.5f, 500, Color.White.copy(alpha = .75f)), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        Text(step.button, style = ui(14f, 800, Color(0xFF0F1626)), maxLines = 2, textAlign = TextAlign.Center,
            modifier = Modifier.heightIn(min = 46.dp).widthIn(max = 150.dp).clip(RoundedCornerShape(15.dp)).background(Color.White)
                .clickable(role = Role.Button, onClick = step.go).padding(horizontal = 14.dp, vertical = 13.dp))
    }
}

/* ---------------- the advanced app: counts and the estimate ---------------- */

/** The order's counted tiles, worked out again only when the order or the settings change. */
@Composable
fun rememberCount(p: Project, roomId: String? = null): TileCount {
    val s = LocalApp.current.settings
    val glue = uz.metrx.app.tiles.glueBaseOf(s.trade.glueKg)
    // worked out off the main thread (a mosaic is many thousand tiles) and kept: the last count shows until the new one is ready
    val key = listOf(p.tiles, p.troom, p.rooms, s.angleSnap, glue, roomId)
    val st = androidx.compose.runtime.produceState(countCache[key] ?: TileCount(), key) {
        value = countCache[key] ?: kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) { countOrder(p, s.angleSnap, glue, roomId, roomId == null) }
            .also { countCache[key] = it }
    }
    return countCache[key] ?: st.value
}

/** The counts worked out lately, by what they were worked out from. */
private val countCache: MutableMap<List<Any?>, TileCount> = java.util.Collections.synchronizedMap(object : LinkedHashMap<List<Any?>, TileCount>(16, .75f, true) {
    override fun removeEldestEntry(eldest: MutableMap.MutableEntry<List<Any?>, TileCount>?) = size > 24
})

/** The order page's three numbers in the advanced app: tiled area, boxes, the estimate. */
@Composable
fun TNums(p: Project) {
    val app = LocalApp.current
    if (!app.settings.advanced) return
    val lang = LocalLang.current
    val c = rememberCount(p)
    Column(Modifier.padding(top = 11.dp)) {
        Hairline()
        Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Cell(tr("tl.area"), uz.metrx.app.core.Num.fixed(c.m2, 1, lang), tr("u.m2"), Modifier.weight(1f))
            Cell(tr("tl.boxes"), "${c.boxes}", null, Modifier.weight(1f))
            val (est, u) = uz.metrx.app.core.shortMoney(p, uz.metrx.app.core.totals(p).g, lang == Lang.EN, tr("pl.mln"))
            Cell(tr("pl.est"), est, u, Modifier.weight(1f))
        }
    }
}

@Composable
private fun Cell(label: String, value: String, unit: String?, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = ui(11.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, style = num(17f, 800), maxLines = 1)
            if (unit != null) Text(" $unit", style = ui(10.5f, 600, G.ink2), modifier = Modifier.padding(bottom = 2.dp))
        }
    }
}

/**
 * Puts the counted tiles into the order's estimate, in place of the calculator's lines made before; lines typed by
 * hand stay. Names and units are stored as keys, so they follow the app's and the report's language.
 */
fun App.applyTiles(p: Project) {
    val r = tileRows(p, settings.trade, settings.angleSnap) { k, v -> if (k.startsWith("tu.")) "@u." + k.removePrefix("tu.") else uz.metrx.app.data.keyName(k, v) }
    store.update(p.id) { pr ->
        pr.copy(stage = if (pr.stage == "measure") "estimate" else pr.stage, estimate = pr.estimate.copy(
            materials = pr.estimate.materials.filter { !it.id.startsWith("t-") } + r.mats.map { it.copy(id = "t-" + uid()) },
            labor = pr.estimate.labor.filter { !it.id.startsWith("t-") } + r.labor.map { it.copy(id = "t-" + uid()) }))
    }
    say("trc.done", "n" to r.mats.size + r.labor.size)
}

/** The estimate tab's card: what the layouts take, and the button that puts it into the estimate. */
@Composable
fun TilesCard(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val c = rememberCount(p)
    val made = uz.metrx.app.trades.madeBy(p, "tl.e.")
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("tl.cardT"), style = ui(16f, 800))
        Text(tr("trc.tiler", "a" to uz.metrx.app.core.Num.fixed(c.m2, 1, lang), "b" to c.boxes), style = num(14.5f, 700))
        Text(tr("tl.cardB"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (p.tiles.isEmpty()) Text(tr("tl.noLayouts"), style = ui(13f, 500, G.amberInk, 1.4f))
        // a surface of too many tiles to count is not in these numbers: said before they go into the estimate
        if (c.tooMany) Text(tr("tl.tooMany"), style = ui(12.5f, 600, G.amberInk, 1.4f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr(if (made) "trc.update" else "trc.apply"), { app.applyTiles(p); if (c.tooMany) app.say("tl.tooMany", kind = uz.metrx.app.ui.components.ToastKind.INFO) }, enabled = c.m2 > 0, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("tl.prices"), { app.sheet = Sheet.TPrices(p.id) }, Btn.SECONDARY, icon = "sliders", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }
}

/** What a room's or an order's layouts take, line by line (the advanced app). */
@Composable
fun CountCard(c: TileCount, title: String, onLayout: (() -> Unit)? = null) {
    val lang = LocalLang.current
    fun d1(v: Double) = uz.metrx.app.core.Num.fixed(v, 1, lang)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = ui(15f, 800), modifier = Modifier.weight(1f))
            Text(d1(c.m2) + " " + tr("u.m2"), style = num(14f, 700))
        }
        if (c.tooMany) Text(tr("tl.tooMany"), style = ui(12.5f, 500, G.amberInk, 1.35f))
        c.needs.forEach { n ->
            Hairline()
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LookSwatch(n.look, Modifier.size(30.dp).clip(RoundedCornerShape(7.dp)))
                Column(Modifier.weight(1f)) {
                    Text("${n.a} × ${n.b} · " + tr("tl.lk.${n.look}"), style = ui(13.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(tr("tl.cnt", "w" to n.whole, "c" to n.cut, "r" to n.reused) + (if (n.skirtTiles > 0) " · " + tr("tl.cntSk", "n" to n.skirtTiles) else ""), style = ui(12f, 400, G.ink2, 1.35f))
                    // layouts of this tile with different spares: no single % to show
                    Text(if (n.spare >= 0) tr("tl.cntSpare", "t" to n.tiles + n.skirtTiles, "p" to n.spare, "s" to n.withSpare)
                        else tr("tl.cntSpareMix", "t" to n.tiles + n.skirtTiles, "s" to n.withSpare), style = ui(12f, 400, G.ink2, 1.35f))
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(tr("tl.boxN", "n" to n.boxes), style = num(14f, 800))
                    if (n.perBox > 0) Text(tr("tl.perBox", "n" to n.perBox), style = ui(11f, 400, G.ink3))
                }
            }
        }
        Hairline()
        Kv(tr("tl.e.glue0"), tr("tl.bagsV", "n" to c.glueBags, "k" to d1(c.glueKg)))
        Kv(tr("tl.e.grout0"), d1(c.groutKg) + " " + tr("u.kg"))
        if (c.skirtM > 0) Kv(tr("tl.skirt"), d1(c.skirtM) + " " + tr("u.m"))
        if (c.profileM > 0) Kv(tr("tl.prof"), d1(c.profileM) + " " + tr("u.m"))
        if (c.wpM2 > 0) Kv(tr("tl.wp"), d1(c.wpM2) + " " + tr("u.m2"))
        if (onLayout != null) Text(tr("tl.countSet"), style = ui(13.5f, 700, G.cobalt2),
            modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button, onClick = onLayout).padding(vertical = 6.dp, horizontal = 2.dp))
    }
}

@Composable
private fun Kv(k: String, v: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(k, style = ui(13f, 500, G.ink2), modifier = Modifier.weight(1f))
        Text(v, style = num(13.5f, 700))
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun TileSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.TNewRoom -> NewRoomSheet(s.pid)
        is Sheet.TFixForm -> FixSheet(s)
        is Sheet.TCount -> CountSheet(s.pid, s.lid)
        is Sheet.TPrices -> PricesSheet(s.pid)
        else -> return false
    }
    return true
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun NewRoomSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    fun nameFor(t: String): String = uz.metrx.app.data.nextName(p, roomKey(t), app.settings.lang)
    var type by rememberSaveable { mutableStateOf(if (p.floors.none { it.type == "bath" }) "bath" else "kitchen") }
    var name by rememberSaveable { mutableStateOf(nameFor(type)) }
    fun create() {
        if (name.isBlank() || !app.once()) return
        // a suggested name is kept as its key, so it follows the language
        val rid = app.addTileRoom(pid, type, uz.metrx.app.data.suggestedName(name, roomKey(type), app.settings.lang))
        app.sheet = null
        app.openRoom(pid, rid)
    }
    GlassSheet(tr("fo.addRoom"), { app.sheet = null }, footer = { GBtn(tr("fo.drawRoom"), ::create, enabled = name.isNotBlank()) }) {
        Text(tr("fr.type"), style = ui(15f, 700))
        androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            T_ROOMS.forEach { t -> Chip(tr(roomKey(t)), t == type) { type = t; name = nameFor(t) } }
        }
        GField(tr("fr.name"), name, { name = it.take(uz.metrx.app.ui.editor.NAME_MAX) }, tr(roomKey(type)), error = if (name.isBlank()) tr("nr.nameReq") else null, showError = true, imeAction = ImeAction.Done, onIme = ::create)
    }
}

/** A shower tray or a bath: which wall, where along it, its size. */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun FixSheet(s: Sheet.TFixForm) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val r = p.rooms.firstOrNull { it.id == s.rid } ?: run { app.sheet = null; return }
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val tr0 = tileRoomOf(p, r.id)
    val old = s.fid?.let { id -> tr0.fixes.firstOrNull { it.id == id } }
    val ws = walls(r, app.settings.angleSnap)
    val start = old ?: (if (s.type == "bath") TFix(uid(), "bath", "A", 0, 1700, 700, 560) else TFix(uid(), "tray", "A", 0, 900, 900, 150)).let { f ->
        // a new one goes against the first wall it fits on without a door in the way
        val w = ws.firstOrNull { w -> (w.len ?: 0) >= f.w && r.openings.none { o -> o.wall == w.id && o.type == "door" && o.off < f.w } } ?: ws.firstOrNull()
        f.copy(wall = w?.id ?: "A")
    }
    var wall by rememberSaveable { mutableStateOf(start.wall) }
    val keys = listOf("off", "w", "d", "h")
    var texts by rememberSaveable { mutableStateOf(listOf(start.off, start.w, start.d, start.h).map { fmtField(it, unit, en) }) }
    // the offset may be 0 (in the corner); the sizes may not
    val vals = texts.mapIndexed { i, t -> if (i == 0) (if (t.isBlank()) 0 else (uz.metrx.app.geo.parseDec(t, uz.metrx.app.geo.unitDecimals(unit)) as? uz.metrx.app.geo.Parsed.Ok)?.value?.toInt()) else parseMm(t, unit) }
    val len = ws.firstOrNull { it.id == wall }?.len
    val err = when {
        vals.any { it == null } -> tr("tl.fixErr")
        len != null && vals[0]!! + vals[1]!! > len -> tr("tl.fixLong")
        else -> null
    }
    fun save() {
        if (err != null || !app.once()) return
        val f = start.copy(wall = wall, off = vals[0]!!, w = vals[1]!!, d = vals[2]!!, h = vals[3]!!)
        app.updateTileRoom(p.id, r.id) { t -> t.copy(fixes = t.fixes.filter { it.id != f.id } + f) }
        // a new bath: its front goes into the room's wall layouts that cover its wall
        if (old == null && f.type == "bath") app.store.update(p.id) { pr -> pr.copy(tiles = pr.tiles.map { l ->
            if (l.roomId == r.id && l.surfs.any { it.id == f.wall }) l.copy(surfs = l.surfs + uz.metrx.app.tiles.TSurf("bath:${f.id}")) else l }) }
        app.sheet = null; app.say("tl.fixSaved")
    }
    GlassSheet(tr(if (start.type == "bath") "tl.bath" else "tl.tray"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), ::save, enabled = err == null)
        if (old != null) GBtn(tr("common.delete"), {
            app.updateTileRoom(p.id, r.id) { t -> t.copy(fixes = t.fixes.filter { it.id != old.id }) }
            app.store.update(p.id) { pr -> pr.copy(tiles = pr.tiles.map { l -> l.copy(surfs = l.surfs.filter { it.id != "bath:${old.id}" }) }) }
            app.sheet = null; app.say("tl.fixDel")
        }, Btn.SECONDARY)
    }) {
        Text(tr("tl.fixB"), style = ui(13.5f, 400, G.ink2, 1.4f))
        Text(tr("tl.fixWall"), style = ui(15f, 700))
        androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            ws.forEach { w -> Chip(tr("tl.wallN", "w" to w.id), w.id == wall) { wall = w.id } }
        }
        val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
        keys.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { k ->
                    val i = keys.indexOf(k)
                    GField(tr("tl.fix.$k"), texts[i], { v -> texts = texts.toMutableList().also { it[i] = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(8) } }, "0",
                        decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
                }
            }
        }
        if (err != null) Text(err, style = ui(13f, 500, G.err))
    }
}

/** A layout's counting in the advanced app: the spare, what a box holds, the tile's price. */
@Composable
private fun CountSheet(pid: String, lid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val l = p.tiles.firstOrNull { it.id == lid } ?: run { app.sheet = null; return }
    var spare by rememberSaveable { mutableStateOf(uz.metrx.app.tiles.spareOf(l).toString()) }
    var pcs by rememberSaveable { mutableStateOf(uz.metrx.app.tiles.perBox(l).toString()) }
    var price by rememberSaveable { mutableStateOf(l.price.ifBlank { app.settings.trade.pTile }) }
    val sp = spare.toIntOrNull()?.takeIf { it in 0..50 }
    val pc = pcs.toIntOrNull()?.takeIf { it in 1..500 }
    val ok = sp != null && pc != null
    GlassSheet(tr("tl.countSet"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), {
            if (!ok) return@GBtn
            app.updateLayout(pid, lid) { it.copy(spare = sp, boxPcs = pc!!, boxM2 = "", price = price.filter { c -> c.isDigit() }) }
            app.sheet = null; app.say("common.save")
        }, enabled = ok)
    }) {
        Text(layoutTitle(l) + " · " + layoutSub(l), style = ui(14f, 600, G.ink2))
        GField(tr("tl.spare"), spare, { spare = it.filter { c -> c.isDigit() }.take(2) }, "5", number = true, labelRight = "%", error = if (sp == null) tr("tl.spareErr") else null, showError = true)
        GField(tr("tl.perBoxF"), pcs, { pcs = it.filter { c -> c.isDigit() }.take(3) }, "4", number = true, labelRight = tr("u.pcs"),
            error = if (pc == null) tr("err.zero") else null, showError = true)
        GField(tr("trf.pTile"), price, { price = it.filter { c -> c.isDigit() }.take(12) }, "0", number = true, money = true, labelRight = "/" + tr("u.m2"))
        Text(tr("tl.countNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/** The tiler's prices, one set for all orders: adhesive, grout, profiles, waterproofing and the labour. */
@Composable
private fun PricesSheet(pid: String?) {
    val app = LocalApp.current
    val t0 = app.settings.trade
    class F(val key: String, val unit: String, val get: (uz.metrx.app.trades.TradeSet) -> String, val set: (uz.metrx.app.trades.TradeSet, String) -> uz.metrx.app.trades.TradeSet)
    val fs = listOf(
        F("pTile", "/m²", { it.pTile }, { t, v -> t.copy(pTile = v) }),
        F("glueKg", "kg/m²", { it.glueKg }, { t, v -> t.copy(glueKg = v) }),
        F("pGlue", "/25 kg", { it.pGlue }, { t, v -> t.copy(pGlue = v) }),
        F("pGrout", "/kg", { it.pGrout }, { t, v -> t.copy(pGrout = v) }),
        F("pProf", "/m", { it.pProf }, { t, v -> t.copy(pProf = v) }),
        F("pWp", "/m²", { it.pWp }, { t, v -> t.copy(pWp = v) }),
        F("lTile", "/m²", { it.lTile }, { t, v -> t.copy(lTile = v) }),
        F("lSkirt", "/m", { it.lSkirt }, { t, v -> t.copy(lSkirt = v) }),
        F("lProf", "/m", { it.lProf }, { t, v -> t.copy(lProf = v) }),
        F("lWp", "/m²", { it.lWp }, { t, v -> t.copy(lWp = v) }))
    var texts by rememberSaveable { mutableStateOf(fs.map { it.get(t0) }) }
    fun save() {
        val t = fs.foldIndexed(t0) { i, acc, f -> texts[i].trim().let { v -> if (v.isEmpty()) acc else f.set(acc, v) } }
        app.settings.setTradeSet(t); app.sheet = null
        pid?.let { id -> app.store.get(id)?.takeIf { pr -> uz.metrx.app.trades.madeBy(pr, "tl.e.") }?.let { app.applyTiles(it) } } ?: app.say("common.save")
    }
    GlassSheet(tr("tl.prices"), { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save) }) {
        fs.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { f ->
                    val i = fs.indexOf(f)
                    GField(tr(if (f.key.startsWith("l") || f.key.startsWith("pP") || f.key.startsWith("pW")) "tl.f.${f.key}" else "trf.${f.key}"), texts[i],
                        { v -> texts = texts.toMutableList().also { it[i] = v.filter { c -> c.isDigit() || (f.key == "glueKg" && (c == ',' || c == '.')) }.replace(',', '.').take(12) } }, "0",
                        number = f.key != "glueKg", decimal = f.key == "glueKg", labelRight = uz.metrx.app.ui.projects.unitText(f.unit), modifier = Modifier.weight(1f))
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        Text(tr("tl.pricesNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}
