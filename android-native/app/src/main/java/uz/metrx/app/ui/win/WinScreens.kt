package uz.metrx.app.ui.win

import androidx.compose.foundation.background
import uz.metrx.app.ui.components.switchState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GSwitch
import uz.metrx.app.ui.components.GlassHeader
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.Hairline
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.components.pressable
import uz.metrx.app.ui.elec.Kv
import uz.metrx.app.ui.furniture.CallButton
import uz.metrx.app.ui.furniture.Chip
import uz.metrx.app.ui.furniture.openRoom
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
import uz.metrx.app.ui.tiles.drawTileRoom
import uz.metrx.app.win.GAP_MAX
import uz.metrx.app.win.GAP_MIN
import uz.metrx.app.win.PROFILES
import uz.metrx.app.win.WCount
import uz.metrx.app.win.WSys
import uz.metrx.app.win.WinCalc
import uz.metrx.app.win.WinItem
import uz.metrx.app.win.WinOrder
import uz.metrx.app.win.WinPrices
import uz.metrx.app.win.calcOf
import uz.metrx.app.win.ctxOf
import uz.metrx.app.win.fillsType
import uz.metrx.app.win.refit
import uz.metrx.app.win.sizeFor
import uz.metrx.app.win.winRows

/*
 * The windows-and-doors maker's own app (22 Oct 2026, built like the plumber's): the Home with new orders, an order's
 * rooms with their openings and the products filling them, the next step, and in the advanced app the parts and labour
 * going into the estimate, priced from a list per profile system.
 */

private const val RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private const val ARROW = "M7 17L17 7M9 7h8v8"
/** A window with its cross. */
const val WINDOW = "M4 3h16v18H4z M12 3v18 M4 12h16"

/* ---------------- changing the order ---------------- */

fun App.updateWin(pid: String, f: (WinOrder) -> WinOrder) = store.update(pid) { it.copy(win = f(it.win)) }

fun App.updateItem(pid: String, iid: String, f: (WinItem) -> WinItem) = updateWin(pid) { e -> e.copy(items = e.items.map { if (it.id == iid) f(it) else it }) }

/** A workspace with a rectangular room in it named [name]; returns the room's id. */
fun App.addWinRoom(pid: String, name: String): String {
    val now = System.currentTimeMillis()
    val w = Workspace(uid(), name, type = "room", created = now)
    val r = Room(uid(), w.id, name, created = now)
    store.update(pid) { it.copy(floors = it.floors + w, rooms = it.rooms + r) }
    return r.id
}

/** Products that follow their openings are refitted when an opening was measured again (the gap kept). */
fun App.refitWin(pid: String) {
    val p = store.get(pid) ?: return
    val changed = p.win.items.mapNotNull { it0 ->
        if (!it0.fit || !it0.inRoom) return@mapNotNull null
        val o = p.rooms.firstOrNull { it.id == it0.roomId }?.openings?.firstOrNull { it.id == it0.opening } ?: return@mapNotNull null
        val (w, h) = sizeFor(o.w, o.h, o.type, it0.gap)
        if (w == it0.w && h == it0.h) null else it0.id to refit(it0, o.w, o.h, o.type)
    }.toMap()
    if (changed.isEmpty()) return
    updateWin(pid) { e -> e.copy(items = e.items.map { changed[it.id] ?: it }) }
}

/** The order's rooms, counts and warnings, worked out again only when the order changes. */
@Composable
fun rememberWCalc(p: Project): WinCalc {
    val s = LocalApp.current.settings
    return remember(p.win, p.rooms, p.floors, p.plumb, p.furniture, s.angleSnap) { calcOf(p, s.angleSnap) }
}

/* ---------------- names ---------------- */

/** A product's name: its type ("3 tabaqali deraza"), or the name typed for one without a room. */
@Composable
fun itemTitle(it: WinItem) = it.name.ifBlank { tr("dw.k.${it.kind}") }

/** "1260 × 1360" — a product's size, mm. */
fun sizeText(w: Int, h: Int) = "$w × $h"

/** An opening's name in its room: "Deraza 2", "Eshik 1" (numbered by kind in the room's order). */
fun openingKey(r: Room, o: Opening): Pair<String, Int> {
    val same = r.openings.filter { it.type == o.type }
    return (if (o.type == "door") "dw.opD" else "dw.opW") to same.indexOfFirst { it.id == o.id } + 1
}

@Composable
fun openingName(r: Room, o: Opening): String { val (k, n) = openingKey(r, o); return tr(k, "n" to n) }

/** "2 deraza · 1 eshik" — the products by group. */
@Composable
fun winSummary(items: List<WinItem>): String {
    val d = items.filter { it.isDoor }.sumOf { it.qty }; val w = items.filter { !it.isDoor }.sumOf { it.qty }
    return listOfNotNull(if (w > 0) tr("dw.nWin", "n" to w) else null, if (d > 0) tr("dw.nDoor", "n" to d) else null).joinToString(" · ").ifEmpty { tr("dw.none") }
}

/** A room's name: its workspace's, else its own. */
@Composable
fun roomName(p: Project, rid: String?): String {
    val lang = LocalLang.current
    val r = p.rooms.firstOrNull { it.id == rid } ?: return ""
    return p.floors.firstOrNull { it.id == r.floorId }?.let { floorName(it, lang) } ?: dn(r.name, lang)
}

/* ---------------- Home ---------------- */

@Composable
fun WinHome(nav: MainNav) {
    val app = LocalApp.current
    val s = app.settings
    val first = s.builderName.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
    val lines = tr("dw.lines").split('|')
    val orders = app.store.projects.filter { it.isWin }.sortedByDescending { it.created }
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
                    Text(tr("dw.newS"), style = ui(14f, 400, G.ink2))
                }
                PathIcon(ARROW, G.ink, 20.dp, 2.2f)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                HomeTile(RULER, tr("gl.meas"), tr("gl.measS"), nav::measure, Modifier.weight(1f))
                HomeTile(WINDOW, tr("dw.gal"), tr("dw.galS"), { nav.newProject() }, Modifier.weight(1f))
            }
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("fo.recent"), style = ui(17f, 800), modifier = Modifier.weight(1f))
                if (orders.isNotEmpty()) Text(tr("fo.all"), style = ui(13.5f, 700, G.cobalt2),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.selectTab(Tab.PROJECTS) }.padding(horizontal = 6.dp, vertical = 8.dp))
            }
            if (orders.isEmpty()) Text(tr("fo.noOrders"), style = ui(14f, 400, G.ink2, 1.45f))
            orders.take(3).forEach { p -> WOrderRow(p) { app.push(Route.Project(p.id)) } }
        }
    }
}

@Composable
private fun HomeTile(icon: String, title: String, sub: String, onClick: () -> Unit, modifier: Modifier) {
    Column(modifier.heightIn(min = 112.dp).glassCard(RoundedCornerShape(26.dp)).pressable(onClick).padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
        PathIcon(icon, G.cobalt, 24.dp, 2f)
        Spacer(Modifier.height(18.dp))
        Text(title, style = ui(17f, 700)); Text(sub, style = ui(12.5f, 400, G.ink2))
    }
}

/** A windows-and-doors order in a list: its name, its products; the call button. */
@Composable
fun WOrderRow(p: Project, onClick: () -> Unit) {
    val lang = LocalLang.current
    Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp)).pressable(onClick).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(WINDOW, G.cobalt, 22.dp, 2f) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(dn(p.name, lang), style = ui(15f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(winSummary(p.win.items), style = ui(12.5f, 500, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
            uz.metrx.app.ui.loc.OrderLocRow(p, Modifier.padding(top = 4.dp))
        }
        CallButton(p)
    }
}

/* ---------------- the order's rooms ---------------- */

@Composable
fun WRoomsTab(p: Project, lang: Lang, route: Route.Project) {
    val app = LocalApp.current
    val s = app.settings
    val en = lang == Lang.EN
    LaunchedEffect(p.rooms) { app.refitWin(p.id) }
    val calc = rememberWCalc(p)
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (p.floors.isEmpty() && p.win.items.isEmpty()) Text(tr("dw.empty"), style = ui(14.5f, 400, G.ink2), textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(22.dp))
        if (p.win.items.isNotEmpty()) OrderCard(p, calc)
        // every room of each workspace (an older project may have several in one), a workspace without one once
        p.floors.flatMap { w -> p.rooms.filter { it.floorId == w.id }.ifEmpty { listOf(null) }.map { w to it } }.forEach { (w, room) ->
            val several = p.rooms.count { it.floorId == w.id } > 1
            val ready = room != null && uz.metrx.app.geo.ready3D(room, s.angleSnap)
            val items = if (room == null) emptyList() else p.win.items.filter { it.roomId == room.id }
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable { if (room != null) (if (ready) app.push(Route.WView(p.id, room.id)) else app.openRoom(p.id, room.id)) else app.push(Route.Space(p.id, w.id)) },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(64.dp, 52.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = if (Theme.dark) .1f else .8f)), contentAlignment = Alignment.Center) {
                        if (room != null) uz.metrx.app.editorThumb(room, Modifier.fillMaxSize().padding(4.dp)) else MIcon("room", G.cobalt, 24.dp, 2f)
                    }
                    Column(Modifier.weight(1f)) {
                        Text(floorName(w, lang) + (if (several && room != null) " · " + dn(room.name, lang) else ""), style = ui(16f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        val a = room?.dim("A")?.v; val b = room?.dim("B")?.v
                        val ops = room?.openings?.size ?: 0
                        Text(if (ready && a != null && b != null && room?.isPoly != true) fmtLen(a, LenUnit.M, en) + " × " + fmtLen(b, LenUnit.M, en) + " " + tr("u.m") + " · " + tr("dw.opsN", "n" to ops)
                            else if (ready) tr("tl.measured") + " · " + tr("dw.opsN", "n" to ops) else tr(if (room != null) "fo.notMeasured" else "fo.notDrawn"), style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (ready) Text("3D", style = ui(13f, 800, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(G.cobalt.copy(alpha = .1f)).padding(horizontal = 10.dp, vertical = 6.dp))
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
                if (items.isNotEmpty()) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable { app.push(Route.WView(p.id, room!!.id)) }
                    .padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(34.dp).clip(RoundedCornerShape(8.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(WINDOW, G.cobalt, 18.dp, 2f) }
                    Column(Modifier.weight(1f)) {
                        Text(winSummary(items), style = ui(14f, 700), maxLines = 2, overflow = TextOverflow.Ellipsis)
                        val ws = calc.warns.count { it.roomId == room!!.id }
                        if (ws > 0) Text(tr("el.warnN", "n" to ws), style = ui(12.5f, 600, G.amberInk))
                        else Text(items.joinToString(", ") { app.t("dw.k.${it.kind}") }, style = ui(12.5f, 500, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
                val empty = room?.openings?.count { o -> items.none { it.opening == o.id } } ?: 0
                when {
                    room == null -> TodoRow(tr("fo.drawRoom")) { app.drawTileRoom(p.id, w, lang) }
                    !ready -> TodoRow(tr("ns.measureT")) { app.openRoom(p.id, room.id) }
                    room.openings.isEmpty() -> TodoRow(tr("dw.addOps")) { app.openRoom(p.id, room.id) }
                    empty > 0 -> TodoRow(tr("dw.fillN", "n" to empty)) { app.push(Route.WGallery(p.id, room.id)) }
                }
            }
        }
        val free = p.win.items.filter { !it.inRoom }
        if (free.isNotEmpty()) Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("dw.freeT"), style = ui(16f, 700))
            free.forEach { f ->
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable { app.push(Route.WDesign(p.id, f.id)) }
                    .padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(34.dp).clip(RoundedCornerShape(8.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(WINDOW, G.cobalt, 18.dp, 2f) }
                    Column(Modifier.weight(1f)) {
                        Text(itemTitle(f), style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(sizeText(f.w, f.h) + " · " + tr("dw.qtyN", "n" to f.qty) + if (calc.warns.any { it.target == f.id }) " · " + tr("dw.hasWarn") else "",
                            style = ui(12.5f, 500, if (calc.warns.any { it.target == f.id }) G.amberInk else G.ink2), maxLines = 1)
                    }
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.push(Route.WGallery(p.id)) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("dw.addItem"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.sheet = Sheet.WNewRoom(p.id) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("room", G.cobalt2, 20.dp, 2f); Text(tr("fo.addRoom"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
        }
        if (p.rooms.isNotEmpty() && route.view == "list") GBtn(tr("pj.v2d"), { app.setTop(route.copy(view = "2d")) }, Btn.SECONDARY, icon = "room", height = 46.dp, fontSize = 14.5f)
    }
}

/** The order's fitting gap and its warnings. */
@Composable
private fun OrderCard(p: Project, calc: WinCalc) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(vertical = 4.dp)) {
        Line("layers", tr("dw.gap"), tr("dw.gapV", "n" to p.win.gap)) { app.sheet = Sheet.WGap(p.id) }
        if (calc.warns.isNotEmpty()) {
            Hairline()
            Line("alert", tr("el.warnN", "n" to calc.warns.size), null, warn = true) {
                val w = calc.warns.first()
                val it0 = w.target?.let { id -> p.win.item(id) }
                if (it0 != null) app.push(Route.WDesign(p.id, it0.id)) else w.roomId?.let { app.push(Route.WView(p.id, it)) }
            }
        }
    }
}

@Composable
internal fun Line(icon: String, title: String, sub: String?, warn: Boolean = false, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MIcon(icon, if (warn) G.amberInk else G.ink2, 20.dp, 2f)
        Text(title, style = ui(14.5f, 700, if (warn) G.amberInk else G.ink), modifier = Modifier.weight(1f), maxLines = 2)
        if (sub != null) Text(sub, style = ui(13f, 500, G.ink2), maxLines = 2, textAlign = TextAlign.End, modifier = Modifier.widthIn(max = 190.dp))
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

/* ---------------- the next step ---------------- */

@Composable
fun WNextStep(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val rooms = uz.metrx.app.data.roomsByWorkspace(p)
    val undrawn = p.floors.firstOrNull { w -> p.rooms.none { it.floorId == w.id } }
    val unmeasured = rooms.firstOrNull { (_, r) -> stepKeys(r, s.angleSnap).any { r.dim(it).status != "conf" } }
    val noOps = rooms.firstOrNull { (_, r) -> r.openings.isEmpty() && p.win.items.none { it.roomId == r.id } }
    val unfilled = rooms.firstOrNull { (_, r) -> ctxOf(p, r.id, s.angleSnap) != null && r.openings.any { o -> p.win.items.none { it.roomId == r.id && it.opening == o.id } } }
    val made = uz.metrx.app.trades.madeBy(p, "dw.e.")
    data class Step(val title: String, val sub: String?, val button: String, val go: () -> Unit)
    val step: Step? = when {
        p.floors.isEmpty() && p.win.items.isEmpty() -> Step(tr("dw.ns.pickT"), tr("dw.ns.pickS"), tr("ns.needB")) { app.push(Route.WGallery(p.id)) }
        undrawn != null -> Step(tr("ns.measureT"), floorName(undrawn, lang), tr("fo.drawRoom")) { app.drawTileRoom(p.id, undrawn, lang) }
        unmeasured != null -> Step(tr("ns.measureT"), tr("ns.measureS", "r" to floorName(unmeasured.first, lang)), tr("ns.measureB")) { app.openRoom(p.id, unmeasured.second.id) }
        noOps != null -> Step(tr("dw.ns.opsT", "r" to floorName(noOps.first, lang)), tr("dw.ns.opsS"), tr("ns.measureB")) { app.openRoom(p.id, noOps.second.id) }
        unfilled != null -> Step(tr("dw.ns.fillT", "r" to floorName(unfilled.first, lang)), tr("dw.ns.fillS"), tr("ns.needB")) { app.push(Route.WGallery(p.id, unfilled.second.id)) }
        !s.advanced -> Step(tr("ns.shareT"), tr("dw.ns.shareS"), tr("ns.shareB")) { app.push(Route.Report(p.id)) }
        !made -> Step(tr("el.ns.estT"), tr("dw.ns.estS"), tr("trc.apply")) { app.applyWinRows(p); app.setProjectTab("estimate") }
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

/** The order page's three numbers in the advanced app: products, m² of windows, the estimate. */
@Composable
fun WNums(p: Project) {
    val app = LocalApp.current
    if (!app.settings.advanced) return
    val lang = LocalLang.current
    val c = rememberWCalc(p).count
    Column(Modifier.padding(top = 11.dp)) {
        Hairline()
        Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Cell(tr("dw.pieces"), "${c.pieces}", null, Modifier.weight(1f))
            Cell(tr("dw.area"), uz.metrx.app.core.Num.fixed(c.winM2, 1, lang), tr("tu.m2"), Modifier.weight(1f))
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

/** Puts the counted parts and labour into the order's estimate in place of the calculator's lines; typed lines stay. */
fun App.applyWinRows(p: Project) {
    val r = winRows(p, settings.trade.win) { k, v -> if (k.startsWith("tu.")) "@u." + k.removePrefix("tu.") else uz.metrx.app.data.keyName(k, v) }
    store.update(p.id) { pr ->
        pr.copy(stage = if (pr.stage == "measure") "estimate" else pr.stage, estimate = pr.estimate.copy(
            materials = pr.estimate.materials.filter { !it.id.startsWith("t-") } + r.mats.map { it.copy(id = "t-" + uid()) },
            labor = pr.estimate.labor.filter { !it.id.startsWith("t-") } + r.labor.map { it.copy(id = "t-" + uid()) }))
    }
    say("trc.done", "n" to r.mats.size + r.labor.size)
}

/** The estimate tab's card (in place of the old calculator's): what the products take, and the button that puts it in. */
@Composable
fun WinCard(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val c = rememberWCalc(p).count
    val made = uz.metrx.app.trades.madeBy(p, "dw.e.")
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("dw.cardT"), style = ui(16f, 800))
        Text(tr("dw.cardN", "n" to c.pieces, "a" to uz.metrx.app.core.Num.fixed(c.winM2, 1, lang)), style = num(14.5f, 700))
        Text(tr("dw.cardB"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (c.pieces == 0) Text(tr("dw.none"), style = ui(13f, 500, G.amberInk, 1.4f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr(if (made) "trc.update" else "trc.apply"), { app.applyWinRows(p) }, enabled = c.pieces > 0, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("tl.prices"), { app.sheet = Sheet.WPrices(p.id) }, Btn.SECONDARY, icon = "sliders", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }
}

/** What products take, line by line (the advanced app). */
@Composable
fun WCountCard(title: String, c: WCount, price: Double?) {
    val lang = LocalLang.current
    fun d1(v: Double) = uz.metrx.app.core.Num.fixed(v, 1, lang)
    fun d2(v: Double) = uz.metrx.app.core.Num.fixed(v, 2, lang)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = ui(15f, 800))
        PROFILES.forEach { s ->
            val sc = c.sys[s] ?: return@forEach
            Kv(tr("dw.c.profile", "s" to tr("dw.p.$s")), tr("dw.c.profV", "f" to d1(sc.frameM), "t" to d1(sc.sashM), "m" to d1(sc.mullM)))
            val names = sc.hw.keys.associateWith { k -> tr("dw.t.$k") }
            if (sc.hw.isNotEmpty()) Kv(tr("dw.c.hw"), sc.hw.entries.joinToString(", ") { (k, n) -> names[k] + " " + n })
        }
        if (c.glassM2 > 0) Kv(tr("dw.c.glass"), listOfNotNull(if (c.glass1 > 0) tr("dw.g.1") + " " + d2(c.glass1) else null, if (c.glass2 > 0) tr("dw.g.2") + " " + d2(c.glass2) else null).joinToString(", ") + " " + tr("u.m2"))
        if (c.panel > 0) Kv(tr("dw.t.panel"), d2(c.panel) + " " + tr("u.m2"))
        if (c.lamM > 0) Kv(tr("dw.c.lam"), d1(c.lamM) + " " + tr("u.m"))
        c.doors.forEach { (k, v) -> Kv(tr("dw.k.$k"), tr("dw.c.doorV", "n" to v.first, "a" to d2(v.second))) }
        if (c.sillM > 0) Kv(tr("dw.x.sill"), d1(c.sillM) + " " + tr("u.m"))
        if (c.dripM > 0) Kv(tr("dw.x.drip"), d1(c.dripM) + " " + tr("u.m"))
        if (c.revealM2 > 0) Kv(tr("dw.x.reveals"), d2(c.revealM2) + " " + tr("u.m2"))
        if (c.nets > 0) Kv(tr("dw.x.net"), "${c.nets}")
        if (c.handles > 0) Kv(tr("dw.x.handles"), "${c.handles}")
        if (price != null) { Hairline(); Kv(tr("dw.c.price"), uz.metrx.app.core.fmtNumStr(Math.round(price).toString(), lang == uz.metrx.app.core.Lang.EN) + " " + LocalApp.current.settings.currency) }
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun WinSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.WNewRoom -> NewRoomSheet(s.pid)
        is Sheet.WGap -> GapSheet(s.pid)
        is Sheet.WPrices -> PricesSheet(s.pid)
        else -> return false
    }
    return true
}

@Composable
private fun NewRoomSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    var name by rememberSaveable { mutableStateOf(uz.metrx.app.data.nextName(p, "dw.roomName", app.settings.lang)) }
    fun create() {
        if (name.isBlank() || !app.once()) return
        // a suggested name is kept as its key, so it follows the language
        val rid = app.addWinRoom(pid, uz.metrx.app.data.suggestedName(name, "dw.roomName", app.settings.lang))
        app.sheet = null
        app.openRoom(pid, rid)
    }
    GlassSheet(tr("fo.addRoom"), { app.sheet = null }, footer = { GBtn(tr("fo.drawRoom"), ::create, enabled = name.isNotBlank()) }) {
        GField(tr("fr.name"), name, { name = it.take(uz.metrx.app.ui.editor.NAME_MAX) }, tr("dw.roomName"), error = if (name.isBlank()) tr("nr.nameReq") else null, showError = true, imeAction = ImeAction.Done, onIme = ::create)
        Text(tr("dw.roomB"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/** The fitting gap new products get, and optionally every product that follows its opening. */
@Composable
private fun GapSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    var t by rememberSaveable { mutableStateOf("${p.win.gap}") }
    var all by rememberSaveable { mutableStateOf(true) }
    val v = t.toIntOrNull()?.takeIf { it in GAP_MIN..GAP_MAX }
    GlassSheet(tr("dw.gap"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), {
            if (v == null) return@GBtn
            app.updateWin(pid) { e -> e.copy(gap = v, items = if (!all) e.items else e.items.map { if (it.inRoom && it.fit) it.copy(gap = v) else it }) }
            app.refitWin(pid); app.sheet = null; app.say("common.save")
        }, enabled = v != null)
    }) {
        GField(tr("dw.gapEach"), t, { s -> t = s.filter { it.isDigit() }.take(2) }, "20", number = true, labelRight = tr("dw.mm"))
        Text(tr("dw.gapB"), style = ui(12.5f, 400, G.ink2, 1.4f))
        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).switchState(all).clickable(role = Role.Switch) { all = !all }
            .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(tr("dw.gapAll"), style = ui(15f, 700), modifier = Modifier.weight(1f)); GSwitch(all)
        }
        if (v == null) Text(tr("dw.gapErr", "a" to GAP_MIN, "b" to GAP_MAX), style = ui(13f, 500, G.err))
    }
}

/** The prices, one set for all orders: a list per profile system, then the glass, extras, doors and labour. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PricesSheet(pid: String?) {
    val app = LocalApp.current
    val t0 = app.settings.trade
    class F(val key: String, val unit: String, val get: (WinPrices) -> String, val set: (WinPrices, String) -> WinPrices)
    fun sysF(s: String): List<F> {
        fun g(p: WinPrices) = p.sys(s)
        fun put(p: WinPrices, v: WSys) = if (s == "alu") p.copy(alu = v) else p.copy(pvc = v)
        return listOf(
            F("frameM", "/m", { g(it).frameM }, { p, v -> put(p, g(p).copy(frameM = v)) }),
            F("sashM", "/m", { g(it).sashM }, { p, v -> put(p, g(p).copy(sashM = v)) }),
            F("mullM", "/m", { g(it).mullM }, { p, v -> put(p, g(p).copy(mullM = v)) }),
            F("hwTurn", "", { g(it).hwTurn }, { p, v -> put(p, g(p).copy(hwTurn = v)) }),
            F("hwTilt", "", { g(it).hwTilt }, { p, v -> put(p, g(p).copy(hwTilt = v)) }),
            F("hwTT", "", { g(it).hwTT }, { p, v -> put(p, g(p).copy(hwTT = v)) }),
            F("hwSlide", "", { g(it).hwSlide }, { p, v -> put(p, g(p).copy(hwSlide = v)) }),
            F("lM2", "/m²", { g(it).lM2 }, { p, v -> put(p, g(p).copy(lM2 = v)) }))
    }
    val common = listOf(
        F("glass1", "/m²", { it.glass1 }, { p, v -> p.copy(glass1 = v) }), F("glass2", "/m²", { it.glass2 }, { p, v -> p.copy(glass2 = v) }),
        F("panel", "/m²", { it.panel }, { p, v -> p.copy(panel = v) }), F("lam", "/m", { it.lam }, { p, v -> p.copy(lam = v) }),
        F("sill", "/m", { it.sill }, { p, v -> p.copy(sill = v) }), F("drip", "/m", { it.drip }, { p, v -> p.copy(drip = v) }),
        F("reveal", "/m²", { it.reveal }, { p, v -> p.copy(reveal = v) }), F("net", "", { it.net }, { p, v -> p.copy(net = v) }),
        F("handle", "", { it.handle }, { p, v -> p.copy(handle = v) }), F("hwDoor", "", { it.hwDoor }, { p, v -> p.copy(hwDoor = v) }),
        F("dInt", "/m²", { it.dInt }, { p, v -> p.copy(dInt = v) }), F("dEnt", "/m²", { it.dEnt }, { p, v -> p.copy(dEnt = v) }),
        F("dSl", "/m²", { it.dSl }, { p, v -> p.copy(dSl = v) }), F("dGl", "/m²", { it.dGl }, { p, v -> p.copy(dGl = v) }),
        F("lDoor", "", { it.lDoor }, { p, v -> p.copy(lDoor = v) }), F("lSill", "/m", { it.lSill }, { p, v -> p.copy(lSill = v) }),
        F("lReveal", "/m²", { it.lReveal }, { p, v -> p.copy(lReveal = v) }), F("lDrip", "/m", { it.lDrip }, { p, v -> p.copy(lDrip = v) }))
    val groups = listOf("pvc" to sysF("pvc"), "alu" to sysF("alu"), "common" to common)
    val all = groups.flatMap { it.second }
    var texts by rememberSaveable { mutableStateOf(all.map { it.get(t0.win) }) }
    var tab by rememberSaveable { mutableStateOf("pvc") }
    fun save() {
        val w = all.foldIndexed(t0.win) { i, acc, f -> texts[i].trim().let { v -> if (v.isEmpty()) acc else f.set(acc, v) } }
        app.settings.setTradeSet(t0.copy(win = w)); app.sheet = null
        pid?.let { id -> app.store.get(id)?.takeIf { pr -> uz.metrx.app.trades.madeBy(pr, "dw.e.") }?.let { app.applyWinRows(it) } } ?: app.say("common.save")
    }
    GlassSheet(tr("tl.prices"), { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save) }) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            groups.forEach { (k, _) -> Chip(tr(if (k == "common") "dw.p.common" else "dw.p.$k"), k == tab) { tab = k } }
        }
        Text(tr(if (tab == "common") "dw.p.commonS" else "dw.p.sysS"), style = ui(12.5f, 400, G.ink2, 1.4f))
        val fs = groups.first { it.first == tab }.second
        fs.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { f ->
                    val i = all.indexOf(f)
                    GField(tr("dw.pr.${f.key}"), texts[i], { v -> texts = texts.toMutableList().also { it[i] = v.filter { c -> c.isDigit() }.take(12) } }, "0",
                        number = true, labelRight = f.unit.ifEmpty { null }?.let { uz.metrx.app.ui.projects.unitText(it) }, modifier = Modifier.weight(1f))
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        Text(tr("dw.pricesNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/** Whether order [p] has an opening of room [rid] that type [kind] could fill. */
fun canFill(p: Project, rid: String, kind: String) = p.rooms.firstOrNull { it.id == rid }?.openings?.any { fillsType(kind, it.type) } == true
