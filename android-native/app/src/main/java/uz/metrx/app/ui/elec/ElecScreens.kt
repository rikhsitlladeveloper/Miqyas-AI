package uz.metrx.app.ui.elec

import uz.metrx.app.ui.rooms.RshSheetGo
import uz.metrx.app.ui.rooms.RshSheetSub
import uz.metrx.app.ui.rooms.RshTypeLabel
import uz.metrx.app.data.putBack
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
import androidx.compose.foundation.shape.CircleShape
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
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.elec.CATS
import uz.metrx.app.elec.DEV_TYPES
import uz.metrx.app.elec.ECount
import uz.metrx.app.elec.ElecCalc
import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecFree
import uz.metrx.app.elec.ElecOrder
import uz.metrx.app.elec.ElecRoom
import uz.metrx.app.elec.KINDS
import uz.metrx.app.elec.Kit
import uz.metrx.app.elec.KitOpts
import uz.metrx.app.elec.KitPick
import uz.metrx.app.elec.METHODS
import uz.metrx.app.elec.calcOf
import uz.metrx.app.elec.cableName
import uz.metrx.app.elec.centreOf
import uz.metrx.app.elec.ctxOf
import uz.metrx.app.elec.defaultPanel
import uz.metrx.app.elec.devType
import uz.metrx.app.elec.elecRows
import uz.metrx.app.elec.exitDoor
import uz.metrx.app.elec.fromSitePoints
import uz.metrx.app.elec.kitOf
import uz.metrx.app.elec.placeKit
import uz.metrx.app.elec.spotOn
import uz.metrx.app.elec.blocksOn
import uz.metrx.app.elec.usualH
import uz.metrx.app.elec.watts
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtField
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
import uz.metrx.app.ui.rooms.startRoomShape
import uz.metrx.app.ui.tiles.drawTileRoom

/*
 * The electrician's own app (22 Oct 2026, built like the tiler's): the Home with new orders, an order's rooms with
 * their devices, the next step, and in the advanced app the cable, breakers and labour going into the estimate.
 */

private const val RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private const val ARROW = "M7 17L17 7M9 7h8v8"
const val BOLT = "M13 2L4 14h7l-1 8 9-12h-7l1-8z"

/* ---------------- changing the order ---------------- */

fun App.updateElec(pid: String, f: (ElecOrder) -> ElecOrder) = store.update(pid) { it.copy(elec = f(it.elec)) }

fun App.updateERoom(pid: String, rid: String, f: (ElecRoom) -> ElecRoom) =
    updateElec(pid) { e -> e.copy(rooms = e.rooms.filter { it.roomId != rid } + f(e.room(rid))) }

fun App.updateDev(pid: String, did: String, f: (ElecDev) -> ElecDev) = updateElec(pid) { e -> e.copy(devs = e.devs.map { if (it.id == did) f(it) else it }) }

/** The rooms an electrician adds (strings keys el.k.*): a kitchen first. */
fun kindKey(k: String) = "el.k.$k"

/** A workspace with a rectangular room in it, named [name], of [kind]; returns the room's id. */
fun App.addElecRoom(pid: String, kind: String, name: String): String {
    val now = System.currentTimeMillis()
    val wt = when (kind) { "kitchen" -> "kitchen"; "bath" -> "bath"; else -> "room" }
    val w = Workspace(uid(), name, type = wt, created = now)
    val r = Room(uid(), w.id, name, created = now)
    store.update(pid) { it.copy(floors = it.floors + w, rooms = it.rooms + r, elec = it.elec.copy(rooms = it.elec.rooms + ElecRoom(r.id, kind))) }
    return r.id
}

/** Takes the room's sockets and switches marked on its walls in as devices (once each). */
fun App.takeInPoints(pid: String, rid: String) {
    val p = store.get(pid) ?: return
    val c = ctxOf(p, rid, settings.angleSnap) ?: return
    val got = fromSitePoints(c, ::uid)
    if (got.isEmpty()) return
    store.update(pid) { pr ->
        val er = pr.elec.room(rid)
        pr.copy(elec = pr.elec.copy(devs = pr.elec.devs + got, rooms = pr.elec.rooms.filter { it.roomId != rid } + er.copy(seen = (er.seen + got.mapNotNull { it.from }).distinct())))
    }
}

/** Puts kit [k] with choices [o] into measured room [rid]; the panel goes in the hallway when there is none yet. Returns how many points. */
fun App.applyKit(pid: String, rid: String, k: Kit, o: KitOpts): Int {
    takeInPoints(pid, rid)
    val p = store.get(pid) ?: return 0
    val c = ctxOf(p, rid, settings.angleSnap) ?: return 0
    val ds = placeKit(k, c, p.elec.devs.filter { it.roomId == rid }, ::uid, o, uz.metrx.app.elec.livePanel(p))
    store.update(pid) { pr ->
        val er = pr.elec.room(rid)
        var e = pr.elec.copy(devs = pr.elec.devs + ds, rooms = pr.elec.rooms.filter { it.roomId != rid } + er.copy(kind = er.kind.ifEmpty { c.kind }, kits = er.kits + k.id))
        if (uz.metrx.app.elec.livePanel(pr.copy(elec = e)) == null) defaultPanel(pr.copy(elec = e), settings.angleSnap)?.let { e = e.copy(panel = it) }
        pr.copy(stage = pr.stage, elec = e)
    }
    return ds.size
}

/** Kits chosen for rooms before they were measured go in once the rooms are. */
fun App.applyPending(pid: String) {
    val p = store.get(pid) ?: return
    p.elec.rooms.filter { it.pend.isNotEmpty() }.forEach { er ->
        val r = p.rooms.firstOrNull { it.id == er.roomId } ?: return@forEach
        if (!uz.metrx.app.geo.ready3D(r, settings.angleSnap)) return@forEach
        val picks = er.pend
        updateERoom(pid, er.roomId) { it.copy(pend = emptyList()) }
        picks.forEach { kp -> kitOf(kp.kit)?.let { k -> applyKit(pid, er.roomId, k, KitOpts(kp.light, kp.led, kp.ac, kp.low)) } }
        say("el.pendDone", "r" to dn(r.name, settings.lang))
    }
}

/** The order's circuits, routes, counts and warnings, worked out again only when the order changes. */
@Composable
fun rememberCalc(p: Project): ElecCalc {
    val s = LocalApp.current.settings
    return remember(p.elec, p.rooms, p.floors, s.angleSnap) { calcOf(p, s.angleSnap) }
}

/* ---------------- names ---------------- */

/** "6 rozetka · 2 vyklyuchatel · 3 chiroq" — a room's devices by kind. */
@Composable
fun devSummary(ds: List<ElecDev>): String {
    val parts = CATS.mapNotNull { c -> ds.count { devType(it.t).cat == c }.takeIf { it > 0 }?.let { n -> tr("el.cn.$c", "n" to n) } }
    return parts.joinToString(" · ").ifEmpty { tr("el.noDevs") }
}

/* ---------------- Home ---------------- */

@Composable
fun ElecHome(nav: MainNav) {
    val app = LocalApp.current
    val s = app.settings
    val first = s.builderName.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
    val lines = tr("el.lines").split('|')
    val orders = app.store.projects.filter { it.isElec }.sortedByDescending { it.created }
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
                    Text(tr("el.newS"), style = ui(14f, 400, G.ink2))
                }
                PathIcon(ARROW, G.ink, 20.dp, 2.2f)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                HomeTile(RULER, tr("gl.meas"), tr("gl.measS"), nav::measure, Modifier.weight(1f))
                HomeTile(BOLT, tr("el.gal"), tr("el.galS"), { nav.newProject() }, Modifier.weight(1f))
            }
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("fo.recent"), style = ui(17f, 800), modifier = Modifier.weight(1f))
                if (orders.isNotEmpty()) Text(tr("fo.all"), style = ui(13.5f, 700, G.cobalt2),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.selectTab(Tab.PROJECTS) }.padding(horizontal = 6.dp, vertical = 8.dp))
            }
            if (orders.isEmpty()) Text(tr("fo.noOrders"), style = ui(14f, 400, G.ink2, 1.45f))
            orders.take(3).forEach { p -> EOrderRow(p) { app.push(Route.Project(p.id)) } }
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

/** An electrician's order in a list: its name, its devices; the call button. */
@Composable
fun EOrderRow(p: Project, onClick: () -> Unit) {
    val lang = LocalLang.current
    Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp)).pressable(onClick).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(BOLT, G.cobalt, 22.dp, 2f) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(dn(p.name, lang), style = ui(15f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
            val sub = listOfNotNull(p.elec.devs.takeIf { it.isNotEmpty() }?.let { devSummary(it) }, p.elec.free.takeIf { it.isNotEmpty() }?.let { tr("el.freeN", "n" to it.size) })
                .joinToString(" · ").ifEmpty { tr("el.noDevs") }
            Text(sub, style = ui(12.5f, 500, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
            uz.metrx.app.ui.loc.OrderLocRow(p, Modifier.padding(top = 4.dp))
        }
        CallButton(p)
    }
}

/* ---------------- the order's rooms ---------------- */

@Composable
fun ERoomsTab(p: Project, lang: Lang, route: Route.Project) {
    val app = LocalApp.current
    val s = app.settings
    val en = lang == Lang.EN
    // kits chosen before a room was measured go in now that it is
    LaunchedEffect(p.rooms) { p.rooms.forEach { app.takeInPoints(p.id, it.id) }; app.applyPending(p.id) }
    val calc = rememberCalc(p)
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (p.floors.isEmpty() && p.elec.free.isEmpty()) Text(tr("el.empty"), style = ui(14.5f, 400, G.ink2), textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(22.dp))
        if (calc.ctxs.isNotEmpty()) OrderCard(p, calc)
        // every room of each workspace (an older project may have several in one), a workspace without one once
        p.floors.flatMap { w -> p.rooms.filter { it.floorId == w.id }.ifEmpty { listOf(null) }.map { w to it } }.forEach { (w, room) ->
            val several = p.rooms.count { it.floorId == w.id } > 1
            val measured = room != null && measuredRoom(room, s.angleSnap)
            val ready = room != null && uz.metrx.app.geo.ready3D(room, s.angleSnap)
            val ds = if (room == null) emptyList() else p.elec.devs.filter { it.roomId == room.id }
            val er = room?.let { p.elec.room(it.id) }
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable { if (room != null) (if (ready) app.push(Route.EView(p.id, room.id)) else app.openRoom(p.id, room.id)) else app.push(Route.Space(p.id, w.id)) },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(64.dp, 52.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = if (Theme.dark) .1f else .8f)), contentAlignment = Alignment.Center) {
                        if (room != null) uz.metrx.app.editorThumb(room, Modifier.fillMaxSize().padding(4.dp)) else MIcon("room", G.cobalt, 24.dp, 2f)
                    }
                    Column(Modifier.weight(1f)) {
                        Text(floorName(w, lang) + (if (several && room != null) " · " + dn(room.name, lang) else ""), style = ui(16f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        val sz = room?.let { uz.metrx.app.geo.roomSize(it, app.settings.angleSnap) }; val a = sz?.first; val b = sz?.second; val h = room?.dim("H")?.v
                        Text(if (ready && a != null && b != null) fmtLen(a, LenUnit.M, en) + " × " + fmtLen(b, LenUnit.M, en) + " " + tr("u.m") + (h?.let { " · h " + fmtLen(it, LenUnit.M, en) } ?: "")
                            else if (ready) tr("tl.measured") else tr(if (room != null) "fo.notMeasured" else "fo.notDrawn"), style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (ready) Text("3D", style = ui(13f, 800, G.cobalt2), modifier = Modifier.clip(RoundedCornerShape(10.dp)).background(G.cobalt.copy(alpha = .1f)).padding(horizontal = 10.dp, vertical = 6.dp))
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
                if (ds.isNotEmpty()) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable { app.push(Route.EView(p.id, room!!.id)) }
                    .padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(34.dp).clip(RoundedCornerShape(8.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(BOLT, G.cobalt, 18.dp, 2f) }
                    Column(Modifier.weight(1f)) {
                        Text(devSummary(ds), style = ui(14f, 700), maxLines = 2, overflow = TextOverflow.Ellipsis)
                        val ws = calc.warns.count { it.roomId == room!!.id }
                        if (ws > 0) Text(tr("el.warnN", "n" to ws), style = ui(12.5f, 600, G.amberInk))
                        else if (calc.routes.panel?.roomId == room!!.id) Text(tr("el.panelHere"), style = ui(12.5f, 500, G.ink2))
                    }
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
                if (er != null && er.pend.isNotEmpty()) Text(tr("el.pending", "k" to er.pend.joinToString(", ") { app.t("el.kit.${it.kit}") }), style = ui(12.5f, 500, G.amberInk, 1.35f))
                when {
                    room == null -> TodoRow(tr("fo.drawRoom")) { app.drawTileRoom(p.id, w, lang) }
                    !ready -> TodoRow(tr("ns.measureT")) { app.openRoom(p.id, room.id) }
                    else -> TodoRow(tr("el.addKit")) { app.push(Route.EGallery(p.id, room.id)) }
                }
            }
        }
        // rooms typed by size, without a plan
        if (p.elec.free.isNotEmpty()) Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("el.freeT"), style = ui(16f, 700))
            p.elec.free.forEach { f ->
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable { app.push(Route.EView(p.id, "free:" + f.id)) }
                    .padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(34.dp).clip(RoundedCornerShape(8.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { MIcon("cube", G.cobalt, 18.dp, 2f) }
                    Column(Modifier.weight(1f)) {
                        Text(uz.metrx.app.data.dn(f.name, lang).ifBlank { tr(kindKey(f.kind)) }, style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(fmtLen(f.L, LenUnit.M, en) + " × " + fmtLen(f.W, LenUnit.M, en) + " " + tr("u.m") + " · " + tr("el.freeCnt", "s" to f.sock + f.power, "k" to f.sw, "l" to f.light + f.lamps.size), style = ui(12.5f, 500, G.ink2), maxLines = 1)
                    }
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.push(Route.EGallery(p.id)) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("el.addKit"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.sheet = Sheet.ENewRoom(p.id) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("room", G.cobalt2, 20.dp, 2f); Text(tr("fo.addRoom"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
        }
        Text(tr("el.addFree"), style = ui(14f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).clip(RoundedCornerShape(12.dp))
            .clickable(role = Role.Button) { app.sheet = Sheet.EFree(p.id, null) }.padding(horizontal = 14.dp, vertical = 10.dp))
        if (p.rooms.isNotEmpty() && route.view == "list") GBtn(tr("pj.v2d"), { app.setTop(route.copy(view = "2d")) }, Btn.SECONDARY, icon = "room", height = 46.dp, fontSize = 14.5f)
    }
}

/** The order's panel, how its cable runs and its warnings. */
@Composable
private fun OrderCard(p: Project, calc: ElecCalc) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val pn = uz.metrx.app.elec.livePanel(p)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(vertical = 4.dp)) {
        val pr = pn?.let { x -> p.rooms.firstOrNull { it.id == x.roomId } }
        Line("box", tr("el.panel"), if (pn != null && pr != null) (p.floors.firstOrNull { it.id == pr.floorId }?.let { floorName(it, lang) } ?: dn(pr.name, lang)) + " · " + tr("tl.wallN", "w" to pn.wall)
            else tr("el.panelNone")) {
            if (pn != null) app.push(Route.EView(p.id, pn.roomId)) else {
                val d = defaultPanel(p, app.settings.angleSnap)
                if (d != null) { app.updateElec(p.id) { it.copy(panel = d) }; app.push(Route.EView(p.id, d.roomId)); app.say("el.panelSet") } else app.say("el.panelNeed")
            }
        }
        Hairline()
        Line("layers", tr("el.method"), tr("el.m.${p.elec.method}")) { app.sheet = Sheet.EMethod(p.id) }
        // the circuits (how many breakers) are the advanced app's
        if (calc.circuits.isNotEmpty() && app.settings.advanced) { Hairline(); Line("sliders", tr("el.circuits"), tr("el.circN", "n" to calc.circuits.count { it.amps > 0 }) + if (calc.count.rcds > 0 && app.settings.advanced) " · " + tr("el.rcdN", "n" to calc.count.rcds) else "") {
            calc.ctxs.firstOrNull { c -> calc.routes.inRoom(c.id).isNotEmpty() }?.let { app.push(Route.EView(p.id, it.id)) } } }
        if (calc.warns.isNotEmpty()) {
            Hairline()
            Line("alert", tr("el.warnN", "n" to calc.warns.size), null, warn = true) {
                calc.warns.firstOrNull { it.roomId != null }?.roomId?.let { app.push(Route.EView(p.id, it)) }
            }
        }
    }
}

@Composable
private fun Line(icon: String, title: String, sub: String?, warn: Boolean = false, onClick: () -> Unit) {
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
fun ENextStep(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val rooms = uz.metrx.app.data.roomsByWorkspace(p)
    val undrawn = p.floors.firstOrNull { w -> p.rooms.none { it.floorId == w.id } }
    val unmeasured = rooms.firstOrNull { (_, r) -> stepKeys(r, s.angleSnap).any { r.dim(it).status != "conf" } }
    val bare = rooms.firstOrNull { (_, r) -> p.elec.devs.none { it.roomId == r.id } && p.elec.room(r.id).pend.isEmpty() }
    val made = uz.metrx.app.trades.madeBy(p, "el.e.")
    data class Step(val title: String, val sub: String?, val button: String, val go: () -> Unit)
    val step: Step? = when {
        p.floors.isEmpty() && p.elec.free.isEmpty() -> Step(tr("el.ns.pickT"), tr("el.ns.pickS"), tr("ns.needB")) { app.push(Route.EGallery(p.id)) }
        undrawn != null -> Step(tr("ns.measureT"), floorName(undrawn, lang), tr("fo.drawRoom")) { app.drawTileRoom(p.id, undrawn, lang) }
        unmeasured != null -> Step(tr("ns.measureT"), tr("ns.measureS", "r" to floorName(unmeasured.first, lang)), tr("ns.measureB")) { app.openRoom(p.id, unmeasured.second.id) }
        bare != null -> Step(tr("el.ns.roomT", "r" to floorName(bare.first, lang)), tr("el.ns.roomS"), tr("ns.needB")) { app.push(Route.EGallery(p.id, bare.second.id)) }
        uz.metrx.app.elec.livePanel(p) == null && p.elec.devs.isNotEmpty() -> Step(tr("el.ns.panelT"), tr("el.ns.panelS"), tr("el.ns.panelB")) {
            defaultPanel(p, s.angleSnap)?.let { d -> app.updateElec(p.id) { it.copy(panel = d) }; app.push(Route.EView(p.id, d.roomId)) }
        }
        !s.advanced -> Step(tr("ns.shareT"), tr("el.ns.shareS"), tr("ns.shareB")) { app.push(Route.Report(p.id)) }
        !made -> Step(tr("el.ns.estT"), tr("el.ns.estS"), tr("trc.apply")) { app.applyElecRows(p); app.setProjectTab("estimate") }
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

/** The order page's three numbers in the advanced app: points, cable, the estimate. */
@Composable
fun ENums(p: Project) {
    val app = LocalApp.current
    if (!app.settings.advanced) return
    val lang = LocalLang.current
    val c = rememberCalc(p).count
    Column(Modifier.padding(top = 11.dp)) {
        Hairline()
        Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Cell(tr("el.points"), "${c.points}", null, Modifier.weight(1f))
            Cell(tr("el.cable"), uz.metrx.app.core.Num.fixed(c.cableM, 0, lang), tr("u.m"), Modifier.weight(1f))
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

/** Puts the counted cable, devices and labour into the order's estimate in place of the calculator's lines; typed lines stay. */
fun App.applyElecRows(p: Project) {
    val r = elecRows(p, settings.trade, settings.angleSnap) { k, v -> if (k.startsWith("tu.")) "@u." + k.removePrefix("tu.") else uz.metrx.app.data.keyName(k, v) }
    store.update(p.id) { pr ->
        pr.copy(stage = if (pr.stage == "measure") "estimate" else pr.stage, estimate = pr.estimate.copy(
            materials = pr.estimate.materials.filter { !it.id.startsWith("t-") } + r.mats.map { it.copy(id = "t-" + uid()) },
            labor = pr.estimate.labor.filter { !it.id.startsWith("t-") } + r.labor.map { it.copy(id = "t-" + uid()) }))
    }
    say("trc.done", "n" to r.mats.size + r.labor.size)
}

/** The estimate tab's card (in place of the old calculator's): what the devices and routes take, and the button that puts it in. */
@Composable
fun ElecCard(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val c = rememberCalc(p).count
    val made = uz.metrx.app.trades.madeBy(p, "el.e.")
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("el.cardT"), style = ui(16f, 800))
        Text(tr("trc.elec", "n" to c.points, "m" to uz.metrx.app.core.Num.fixed(c.cableM, 1, lang)), style = num(14.5f, 700))
        Text(tr("el.cardB"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (c.points == 0) Text(tr("el.noDevs"), style = ui(13f, 500, G.amberInk, 1.4f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr(if (made) "trc.update" else "trc.apply"), { app.applyElecRows(p) }, enabled = c.points > 0, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("tl.prices"), { app.sheet = Sheet.EPrices(p.id) }, Btn.SECONDARY, icon = "sliders", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }
}

/** What the order takes, line by line (the advanced app). */
@Composable
fun ECountCard(c: ECount) {
    val lang = LocalLang.current
    fun d1(v: Double) = uz.metrx.app.core.Num.fixed(v, 1, lang)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("el.countT"), style = ui(15f, 800))
        c.cables.forEach { n ->
            Kv(tr("el.cab", "c" to cableName(n.type).let { if (lang == Lang.EN) it else it.replace('.', ',') }),
                // a short run by the metre, a long one in whole coils (as the estimate buys it)
                if (n.coils == 0 || n.withSpare < uz.metrx.app.elec.COIL_FROM) tr("el.cabVm", "m" to d1(n.m), "s" to d1(n.withSpare))
                else tr("el.cabV", "m" to d1(n.m), "s" to d1(n.withSpare), "n" to n.coils))
        }
        if (c.breakers.isNotEmpty()) {
            Hairline()
            Kv(tr("el.brk"), c.breakers.entries.joinToString(", ") { "${it.key} A × ${it.value}" })
            if (c.rcds > 0) Kv(tr("el.rcd"), "× ${c.rcds}")
            Kv(tr("el.panelSize"), tr("el.modV", "n" to c.panelModules, "u" to c.modules))
        }
        Hairline()
        Kv(tr("el.boxes"), "${c.boxes}")
        Kv(tr("el.jboxes"), "${c.jboxes}")
        if (c.chaseM > 0) Kv(tr("el.m.chase"), d1(c.chaseM) + " " + tr("u.m"))
        if (c.gofraM > 0) Kv(tr("el.m.gofra"), d1(c.gofraM) + " " + tr("u.m"))
        if (c.channelM > 0) Kv(tr("el.m.channel"), d1(c.channelM) + " " + tr("u.m"))
        Kv(tr("el.points"), "${c.points}")
    }
}

@Composable
internal fun Kv(k: String, v: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(k, style = ui(13f, 500, G.ink2), modifier = Modifier.weight(1f))
        Text(v, style = num(13.5f, 700), textAlign = TextAlign.End)
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun ElecSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.ENewRoom -> NewRoomSheet(s.pid)
        is Sheet.EDev -> DevSheet(s)
        is Sheet.ERoomSet -> RoomSetSheet(s.pid, s.rid)
        is Sheet.EMethod -> MethodSheet(s.pid)
        is Sheet.EPrices -> PricesSheet(s.pid)
        is Sheet.EFree -> FreeSheet(s.pid, s.fid)
        else -> return false
    }
    return true
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun NewRoomSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    fun nameFor(k: String): String = uz.metrx.app.data.nextName(p, kindKey(k), app.settings.lang)
    var kind by rememberSaveable { mutableStateOf(if (p.floors.isEmpty()) "hall" else "kitchen") }
    var name by rememberSaveable { mutableStateOf(nameFor(kind)) }
    fun create() {
        if (name.isBlank() || !app.once()) return
        // a suggested name is kept as its key, so it follows the language
        app.sheet = null
        app.startRoomShape(pid, "elec", kind, uz.metrx.app.data.suggestedName(name, kindKey(kind), app.settings.lang))
    }
    GlassSheet(tr("fo.addRoom"), { app.sheet = null }, footer = { RshSheetGo(name.isNotBlank(), ::create) }) {
        RshSheetSub(p)
        RshTypeLabel()
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            KINDS.forEach { k -> Chip(tr(kindKey(k)), k == kind) { kind = k; name = nameFor(k) } }
        }
        GField(tr("fr.name"), name, { name = it.take(uz.metrx.app.ui.editor.NAME_MAX) }, tr(kindKey(kind)), error = if (name.isBlank()) tr("nr.nameReq") else null, showError = true, imeAction = ImeAction.Done, onIme = ::create)
    }
}

/** A device: a new one (its type, then it goes on the wall shown), or one placed (its type, wall, place, height, power, own line). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DevSheet(s: Sheet.EDev) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val c = ctxOf(p, s.rid, app.settings.angleSnap) ?: run { app.sheet = null; return }
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    val old = s.did?.let { id -> p.elec.devs.firstOrNull { it.id == id } }
    if (old == null) {
        // a new device: pick its type
        var cat by rememberSaveable { mutableStateOf("sock") }
        GlassSheet(tr("el.addDev"), { app.sheet = null }) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                CATS.forEach { k -> Chip(tr("el.cat.$k"), k == cat) { cat = k } }
            }
            DEV_TYPES.filter { it.cat == cat }.forEach { ty ->
                Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).clickable(role = Role.Button) {
                    if (!app.once()) return@clickable
                    val d = newDev(c, p, ty.id, s.wall)
                    if (d == null) { app.say("el.noSpace"); return@clickable }
                    app.updateElec(p.id) { it.copy(devs = it.devs + d) }
                    app.sheet = null; app.say("el.devAdded", "n" to app.t("el.t.${ty.id}"))
                }.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    androidx.compose.foundation.Canvas(Modifier.size(36.dp)) { devSymbol(ty.id, center, size.minDimension / 3.2f, rgbC(uz.metrx.app.elec.groupDef(ty.group.ifEmpty { "low" }).rgb)) }
                    Column(Modifier.weight(1f)) {
                        Text(tr("el.t.${ty.id}"), style = ui(15f, 700))
                        Text(if (ty.ceil) tr("el.onCeil") else tr("el.atH", "h" to fmtLen(usualH(ty.id, c.H, c.kind), LenUnit.M, en)), style = ui(12.5f, 400, G.ink2))
                    }
                }
            }
        }
        return
    }
    val ty = devType(old.t)
    var t by rememberSaveable { mutableStateOf(old.t) }
    var wall by rememberSaveable { mutableStateOf(old.wall) }
    var tOff by rememberSaveable { mutableStateOf(fmtField(if (old.onCeiling) old.cx else old.off, unit, en)) }
    var tH by rememberSaveable { mutableStateOf(fmtField(if (old.onCeiling) old.cy else old.h, unit, en)) }
    var tLen by rememberSaveable { mutableStateOf(if (old.len > 0) fmtField(old.len, unit, en) else "") }
    var tW by rememberSaveable { mutableStateOf(if (old.w > 0) old.w.toString() else "") }
    var own by rememberSaveable { mutableStateOf(old.own) }
    val vOff = if (tOff.isBlank()) null else (uz.metrx.app.geo.parseDec(tOff, uz.metrx.app.geo.unitDecimals(unit)) as? uz.metrx.app.geo.Parsed.Ok)?.value?.toInt()
    val vH = parseMm(tH, unit); val vLen = if (old.t == "led") parseMm(tLen, unit) else 0
    val wl = c.wall(wall)?.len
    val err = when {
        vOff == null || vH == null || vLen == null -> tr("tl.fixErr")
        !old.onCeiling && wl != null && vOff > wl -> tr("pt.offBig", "v" to fmtLen(wl.toInt(), unit, en) + " " + tr(uz.metrx.app.ui.rooms.unitKeyOf(unit)))
        !old.onCeiling && vH > c.H -> tr("pt.hBig", "v" to fmtLen(c.H, unit, en) + " " + tr(uz.metrx.app.ui.rooms.unitKeyOf(unit)))
        else -> null
    }
    fun save() {
        if (err != null || !app.once()) return
        app.updateDev(p.id, old.id) { d -> d.copy(t = t, wall = if (d.onCeiling) null else wall, off = if (d.onCeiling) d.off else vOff!!, h = if (d.onCeiling) d.h else vH!!,
            cx = if (d.onCeiling) vOff!! else d.cx, cy = if (d.onCeiling) vH!! else d.cy, len = vLen ?: d.len, w = tW.toIntOrNull() ?: 0, own = own && ty.cat == "sock") }
        app.sheet = null; app.say("common.save")
    }
    GlassSheet(tr("el.t.${old.t}"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), ::save, enabled = err == null)
        GBtn(tr("common.delete"), {
            val devs = app.store.get(p.id)?.elec?.devs ?: return@GBtn
            val at = devs.indexOfFirst { it.id == old.id }; val gone = devs.getOrNull(at) ?: return@GBtn
            app.updateElec(p.id) { e -> e.copy(devs = e.devs.filter { it.id != old.id }) }
            app.sheet = null
            // Undo puts back only this device, where it was
            app.say("el.devDel", action = "common.undo", onAction = { app.updateElec(p.id) { e -> if (e.devs.any { it.id == gone.id }) e else e.copy(devs = e.devs.putBack(gone, at)) } })
        }, Btn.SECONDARY)
    }) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            DEV_TYPES.filter { it.cat == ty.cat && it.ceil == ty.ceil && (it.id == "led") == (old.t == "led") }.forEach { x -> Chip(tr("el.t.${x.id}"), x.id == t) { t = x.id } }
        }
        if (!old.onCeiling) {
            Text(tr("tl.fixWall"), style = ui(15f, 700))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                (c.g.walls + c.g.inner).forEach { w -> Chip(tr("tl.wallN", "w" to w.id), w.id == wall) { wall = w.id } }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GField(tr(if (old.onCeiling) "el.f.x" else "el.f.off"), tOff, { v -> tOff = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) }, "0", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            GField(tr(if (old.onCeiling) "el.f.y" else "el.f.h"), tH, { v -> tH = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) }, "0", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
        }
        if (old.t == "led") GField(tr("el.f.len"), tLen, { v -> tLen = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) }, "2", decimal = true, labelRight = uw)
        if (ty.cat != "low" && ty.cat != "box") GField(tr("el.f.w"), tW, { v -> tW = v.filter { ch -> ch.isDigit() }.take(5) }, "${watts(old.copy(w = 0))}", number = true, labelRight = "W")
        if (ty.cat == "sock") Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).switchState(own).clickable(role = Role.Switch) { own = !own }
            .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(tr("el.own"), style = ui(15f, 700)); Text(tr("el.ownS"), style = ui(12f, 400, G.ink2, 1.3f)) }
            GSwitch(own)
        }
        if (!old.onCeiling) Text(tr("el.dragHint"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (err != null) Text(err, style = ui(13f, 500, G.err))
    }
}

/** A new device of type [t] in room [c]: on wall [wall] (or the main one) at its usual height, clear of what is there; a light in the middle. */
fun newDev(c: uz.metrx.app.elec.ECtx, p: Project, t: String, wall: String?): ElecDev? {
    val ty = devType(t)
    if (ty.ceil) { val m = centreOf(c); return ElecDev(uid(), t, c.id, null, cx = m.x.toInt() + 150, cy = m.y.toInt()) }
    val have = p.elec.devs.filter { it.roomId == c.id }
    val h = usualH(t, c.H, c.kind)
    val ws = (listOfNotNull(c.wall(wall)) + c.g.walls).distinct()
    for (w in ws) {
        if (t == "led") { val l = (w.len - 400).coerceIn(300.0, 2000.0).toInt(); return ElecDev(uid(), t, c.id, w.id, (w.len / 2).toInt(), h, len = l) }
        val x = spotOn(w, w.len / 2, h, ty.dw, ty.dh, blocksOn(c, w.id, t, have, uz.metrx.app.elec.livePanel(p))) ?: continue
        return ElecDev(uid(), t, c.id, w.id, x, h)
    }
    return null
}

/** A room's settings: what room it is, the door its cable comes in by, the panel's room's door it leaves by and the cable between them. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun RoomSetSheet(pid: String, rid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val c = ctxOf(p, rid, app.settings.angleSnap) ?: run { app.sheet = null; return }
    val er = p.elec.room(rid)
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val pn = uz.metrx.app.elec.livePanel(p)
    val pc = pn?.let { ctxOf(p, it.roomId, app.settings.angleSnap) }
    var tLink by rememberSaveable { mutableStateOf(fmtField(er.link, unit, en)) }
    GlassSheet(tr("el.roomSet"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), { parseMm(tLink, unit)?.let { v -> app.updateERoom(pid, rid) { it.copy(link = v.coerceAtMost(100_000)) } }; app.sheet = null; app.say("common.save") })
    }) {
        Text(tr("fr.type"), style = ui(15f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            KINDS.forEach { k -> Chip(tr(kindKey(k)), k == c.kind) { app.updateERoom(pid, rid) { it.copy(kind = k) } } }
        }
        if (c.doors.size > 1) {
            Text(tr("el.door"), style = ui(15f, 700))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                c.doors.forEachIndexed { i, o -> Chip(tr("el.doorN", "i" to i + 1, "w" to o.wall), c.entry?.id == o.id) { app.updateERoom(pid, rid) { it.copy(door = o.id) } } }
            }
        }
        if (pn != null && pc != null && pn.roomId != rid) {
            if (pc.doors.size > 1) {
                Text(tr("el.pdoor", "r" to dn(pc.room.name, app.settings.lang)), style = ui(15f, 700))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val cur = exitDoor(pc, pn, er)
                    pc.doors.forEachIndexed { i, o -> Chip(tr("el.doorN", "i" to i + 1, "w" to o.wall), cur?.id == o.id) { app.updateERoom(pid, rid) { it.copy(pdoor = o.id) } } }
                }
            }
            GField(tr("el.link"), tLink, { v -> tLink = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(7) }, "1", decimal = true, labelRight = tr(if (unit == LenUnit.CM) "u.cm" else "u.m"))
            Text(tr("el.linkS"), style = ui(12.5f, 400, G.ink2, 1.4f))
        }
        if (pn?.roomId != rid) GBtn(tr("el.panelMove"), {
            val d = uz.metrx.app.elec.panelIn(c, p.elec.devs.filter { it.roomId == rid })
            app.updateElec(pid) { it.copy(panel = d) }; app.sheet = null; app.say("el.panelSet")
        }, Btn.SECONDARY, icon = "box")
        GBtn(tr("el.marks"), { app.sheet = null; app.push(Route.WallView(pid, rid, c.g.walls.first().id)) }, Btn.SECONDARY, icon = "pin")
        if (p.elec.devs.any { it.roomId == rid }) GBtn(tr("el.clear"), {
            val before = app.store.get(pid)?.elec ?: return@GBtn
            val devs = before.devs.filter { it.roomId == rid }; val kits = before.room(rid).kits
            app.updateElec(pid) { e -> e.copy(devs = e.devs.filter { it.roomId != rid }, rooms = e.rooms.map { if (it.roomId == rid) it.copy(kits = emptyList()) else it }) }
            // Undo puts back only this room's devices and kits
            app.sheet = null; app.say("el.cleared", action = "common.undo", onAction = { app.updateElec(pid) { e ->
                e.copy(devs = e.devs + devs.filter { d -> e.devs.none { it.id == d.id } }, rooms = e.rooms.map { if (it.roomId == rid) it.copy(kits = kits) else it }) } })
        }, Btn.DANGER)
    }
}

/** How the cable runs in the order: in wall chases, in corrugated pipe over the ceiling, or in a surface channel; the spare. */
@Composable
private fun MethodSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    GlassSheet(tr("el.method"), { app.sheet = null }) {
        METHODS.forEach { m ->
            val on = p.elec.method == m
            val shape = RoundedCornerShape(16.dp)
            Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(shape).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.75f))
                .clickable(role = Role.RadioButton) { app.updateElec(pid) { it.copy(method = m) } }.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(20.dp).clip(CircleShape).background(if (on) G.cobalt else G.ink.copy(alpha = .12f)), contentAlignment = Alignment.Center) { if (on) Box(Modifier.size(8.dp).clip(CircleShape).background(Color.White)) }
                Column(Modifier.weight(1f)) {
                    Text(tr("el.m.$m"), style = ui(15f, 700, if (on) G.cobalt2 else G.ink))
                    Text(tr("el.m.${m}S"), style = ui(12.5f, 400, G.ink2, 1.35f))
                }
            }
        }
        if (app.settings.advanced) {
            Text(tr("el.spare"), style = ui(15f, 700))
            @OptIn(ExperimentalLayoutApi::class)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(5, 10, 15, 20).forEach { v -> Chip("$v %", (p.elec.spare ?: uz.metrx.app.elec.CABLE_SPARE) == v) { app.updateElec(pid) { it.copy(spare = v) } } }
            }
        }
    }
}

/** The electrician's prices, one set for all orders: cable, devices, boxes, breakers, the panel and the labour. */
@Composable
private fun PricesSheet(pid: String?) {
    val app = LocalApp.current
    val t0 = app.settings.trade
    class F(val key: String, val unit: String, val get: (uz.metrx.app.trades.TradeSet) -> String, val set: (uz.metrx.app.trades.TradeSet, String) -> uz.metrx.app.trades.TradeSet)
    val fs = listOf(
        F("pCab15", "/m", { it.pCab15 }, { t, v -> t.copy(pCab15 = v) }),
        F("pCable", "/m", { it.pCable }, { t, v -> t.copy(pCable = v) }),
        F("pCab6", "/m", { it.pCab6 }, { t, v -> t.copy(pCab6 = v) }),
        F("pUtp", "/m", { it.pUtp }, { t, v -> t.copy(pUtp = v) }),
        F("pSocket", "", { it.pSocket }, { t, v -> t.copy(pSocket = v) }),
        F("pSwitch", "", { it.pSwitch }, { t, v -> t.copy(pSwitch = v) }),
        F("pLight", "", { it.pLight }, { t, v -> t.copy(pLight = v) }),
        F("pLow", "", { it.pLow }, { t, v -> t.copy(pLow = v) }),
        F("pBox", "", { it.pBox }, { t, v -> t.copy(pBox = v) }),
        F("pJBox", "", { it.pJBox }, { t, v -> t.copy(pJBox = v) }),
        F("pBreaker", "", { it.pBreaker }, { t, v -> t.copy(pBreaker = v) }),
        F("pRcd", "", { it.pRcd }, { t, v -> t.copy(pRcd = v) }),
        F("pMain", "", { it.pMain }, { t, v -> t.copy(pMain = v) }),
        F("pPanelM", "", { it.pPanelM }, { t, v -> t.copy(pPanelM = v) }),
        F("pConduit", "/m", { it.pConduit }, { t, v -> t.copy(pConduit = v) }),
        F("pChan", "/m", { it.pChan }, { t, v -> t.copy(pChan = v) }),
        F("lPoint", "", { it.lPoint }, { t, v -> t.copy(lPoint = v) }),
        F("lChase", "/m", { it.lChase }, { t, v -> t.copy(lChase = v) }),
        F("lMetre", "/m", { it.lMetre }, { t, v -> t.copy(lMetre = v) }),
        F("lPanel", "", { it.lPanel }, { t, v -> t.copy(lPanel = v) }))
    var texts by rememberSaveable { mutableStateOf(fs.map { it.get(t0) }) }
    fun save() {
        val t = fs.foldIndexed(t0) { i, acc, f -> texts[i].trim().let { v -> if (v.isEmpty()) acc else f.set(acc, v) } }
        app.settings.setTradeSet(t); app.sheet = null
        pid?.let { id -> app.store.get(id)?.takeIf { pr -> uz.metrx.app.trades.madeBy(pr, "el.e.") }?.let { app.applyElecRows(it) } } ?: app.say("common.save")
    }
    GlassSheet(tr("tl.prices"), { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save) }) {
        fs.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { f ->
                    val i = fs.indexOf(f)
                    GField(tr("el.p.${f.key}"), texts[i], { v -> texts = texts.toMutableList().also { it[i] = v.filter { c -> c.isDigit() }.take(12) } }, "0",
                        number = true, labelRight = f.unit.ifEmpty { null }?.let { uz.metrx.app.ui.projects.unitText(it) }, modifier = Modifier.weight(1f))
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        Text(tr("el.pricesNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/** A room typed by size: its name and kind, length, width and height, and how many points of each kind. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FreeSheet(pid: String, fid: String?) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    val old = fid?.let { id -> p.elec.free.firstOrNull { it.id == id } }
    val start = old ?: ElecFree(uid(), "@" + kindKey("bed"), "bed")
    var kind by rememberSaveable { mutableStateOf(start.kind) }
    // a kind's own name is kept as its key, so it follows the language
    var name by rememberSaveable { mutableStateOf(uz.metrx.app.data.dn(start.name, app.settings.lang)) }
    fun keptName() = name.trim().let { t -> if (t == uz.metrx.app.data.dn(start.name, app.settings.lang)) start.name else if (t == app.t(kindKey(kind))) "@" + kindKey(kind) else t }
    var tl by rememberSaveable { mutableStateOf(fmtField(start.L, unit, en)) }
    var tw by rememberSaveable { mutableStateOf(fmtField(start.W, unit, en)) }
    var th by rememberSaveable { mutableStateOf(fmtField(start.H, unit, en)) }
    var tk by rememberSaveable { mutableStateOf(fmtField(start.link, unit, en)) }
    var cnt by rememberSaveable { mutableStateOf(listOf(start.sock, start.sw, start.light, start.low, start.power)) }
    val L = parseMm(tl, unit); val W = parseMm(tw, unit); val H = parseMm(th, unit); val K = parseMm(tk, unit)
    val ok = L != null && W != null && H != null && K != null && L in 1000..30000 && W in 1000..30000 && H in 2000..6000
    fun save() {
        if (!ok || !app.once()) return
        val f = start.copy(name = keptName(), kind = kind, L = L!!, W = W!!, H = H!!, link = K!!, sock = cnt[0], sw = cnt[1], light = cnt[2], low = cnt[3], power = cnt[4])
        app.updateElec(pid) { e -> e.copy(free = if (old != null) e.free.map { if (it.id == f.id) f else it } else e.free + f) }
        app.sheet = null
        if (old == null) app.push(Route.EView(pid, "free:" + f.id))
        app.say("common.save")
    }
    GlassSheet(tr(if (old == null) "el.addFree" else "el.freeEdit"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), ::save, enabled = ok)
        if (old != null) GBtn(tr("common.delete"), {
            app.updateElec(pid) { e -> e.copy(free = e.free.filter { it.id != old.id }) }
            app.sheet = null; app.popTo { it is Route.Project && it.id == pid }; app.say("el.freeDel")
        }, Btn.SECONDARY)
    }) {
        Text(tr("el.freeB"), style = ui(13f, 400, G.ink2, 1.4f))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            KINDS.forEach { k -> Chip(tr(kindKey(k)), k == kind) { if (name.isBlank() || name == app.t(kindKey(kind))) name = app.t(kindKey(k)); kind = k } }
        }
        GField(tr("fr.name"), name, { name = it.take(uz.metrx.app.ui.editor.NAME_MAX) }, tr(kindKey(kind)))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GField(tr("tl.pa"), tl, { v -> tl = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "4", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            GField(tr("tl.pbW"), tw, { v -> tw = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "3", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            GField(tr("tl.pbH"), th, { v -> th = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2,7", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
        }
        listOf("sock", "sw", "light", "low", "power").forEachIndexed { i, k ->
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("el.fc.$k"), style = ui(15f, 600), modifier = Modifier.weight(1f))
                Stepper(cnt[i]) { v -> cnt = cnt.toMutableList().also { it[i] = v.coerceIn(0, 40) } }
            }
        }
        GField(tr("el.link"), tk, { v -> tk = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "4", decimal = true, labelRight = uw)
        if (!ok) Text(tr("el.freeErr"), style = ui(13f, 500, G.err))
    }
}

@Composable
internal fun Stepper(v: Int, onSet: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.size(44.dp).clip(CircleShape).background(G.ink.copy(alpha = .06f)).clickable(role = Role.Button, onClickLabel = "−") { onSet(v - 1) }, contentAlignment = Alignment.Center) { Text("−", style = ui(20f, 700)) }
        Text("$v", style = num(17f, 800), modifier = Modifier.widthIn(min = 28.dp), textAlign = TextAlign.Center)
        Box(Modifier.size(44.dp).clip(CircleShape).background(G.ink.copy(alpha = .06f)).clickable(role = Role.Button, onClickLabel = "+") { onSet(v + 1) }, contentAlignment = Alignment.Center) { MIcon("plus", G.ink, 18.dp, 2.2f) }
    }
}

/** A kit pick for a room not measured yet. */
fun pickOf(k: Kit, o: KitOpts) = KitPick(k.id, o.light, o.led, o.ac, o.low)
