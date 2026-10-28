package uz.metrx.app.ui.plumb

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
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.plumb.FIX_CATS
import uz.metrx.app.plumb.FIX_TYPES
import uz.metrx.app.plumb.FixPt
import uz.metrx.app.plumb.KINDS
import uz.metrx.app.plumb.PCount
import uz.metrx.app.plumb.PKit
import uz.metrx.app.plumb.POpts
import uz.metrx.app.plumb.PT_KINDS
import uz.metrx.app.plumb.PlFix
import uz.metrx.app.plumb.PlFree
import uz.metrx.app.plumb.PlPoint
import uz.metrx.app.plumb.PlRoom
import uz.metrx.app.plumb.PlumbCalc
import uz.metrx.app.plumb.PlumbOrder
import uz.metrx.app.plumb.RUNS
import uz.metrx.app.plumb.WATERS
import uz.metrx.app.plumb.calcOf
import uz.metrx.app.plumb.ctxOf
import uz.metrx.app.plumb.defaultRiser
import uz.metrx.app.plumb.exitDoor
import uz.metrx.app.plumb.fixType
import uz.metrx.app.plumb.fixW
import uz.metrx.app.plumb.fromSitePoints
import uz.metrx.app.plumb.newFix
import uz.metrx.app.plumb.pkitOf
import uz.metrx.app.plumb.placeFix
import uz.metrx.app.plumb.placeKit
import uz.metrx.app.plumb.placeRadiators
import uz.metrx.app.plumb.plumbRows
import uz.metrx.app.plumb.resizeFix
import uz.metrx.app.plumb.riserIn
import uz.metrx.app.plumb.usualPtH
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
import uz.metrx.app.ui.elec.Stepper
import uz.metrx.app.ui.elec.rgbC
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
 * The plumber's own app (22 Oct 2026, built like the electrician's): the Home with new orders, an order's rooms with
 * their fixtures, the next step, and in the advanced app the pipe, fittings, valves and labour going into the estimate.
 */

private const val RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private const val ARROW = "M7 17L17 7M9 7h8v8"
/** A tap with its drop. */
const val TAP = "M4 7h9a3 3 0 0 1 3 3v2 M8 7V4 M5 4h6 M16 15.5c0 0-2 2.6-2 4a2 2 0 0 0 4 0c0-1.4-2-4-2-4z"

/* ---------------- changing the order ---------------- */

fun App.updatePlumb(pid: String, f: (PlumbOrder) -> PlumbOrder) = store.update(pid) { it.copy(plumb = f(it.plumb)) }

fun App.updatePRoom(pid: String, rid: String, f: (PlRoom) -> PlRoom) =
    updatePlumb(pid) { e -> e.copy(rooms = e.rooms.filter { it.roomId != rid } + f(e.room(rid))) }

fun App.updateFix(pid: String, fid: String, f: (PlFix) -> PlFix) = updatePlumb(pid) { e -> e.copy(fixes = e.fixes.map { if (it.id == fid) f(it) else it }) }

fun App.updatePt(pid: String, id: String, f: (PlPoint) -> PlPoint) = updatePlumb(pid) { e -> e.copy(points = e.points.map { if (it.id == id) f(it) else it }) }

/** The plumber's room kinds (strings keys sx.k.*). */
fun kindKey(k: String) = "sx.k.$k"

/** A workspace with a rectangular room in it, named [name], of [kind]; returns the room's id. */
fun App.addPlumbRoom(pid: String, kind: String, name: String): String {
    val now = System.currentTimeMillis()
    val wt = when (kind) { "kitchen" -> "kitchen"; "bath", "wc" -> "bath"; else -> "room" }
    val w = Workspace(uid(), name, type = wt, created = now)
    val r = Room(uid(), w.id, name, created = now)
    store.update(pid) { it.copy(floors = it.floors + w, rooms = it.rooms + r, plumb = it.plumb.copy(rooms = it.plumb.rooms + PlRoom(r.id, kind))) }
    return r.id
}

/** Takes the room's cold, hot and drain marked on its walls in as outlets (once each). */
fun App.takeInPlumbPoints(pid: String, rid: String) {
    val p = store.get(pid) ?: return
    val c = ctxOf(p, rid, settings.angleSnap) ?: return
    val got = fromSitePoints(c, ::uid)
    if (got.isEmpty()) return
    store.update(pid) { pr ->
        val er = pr.plumb.room(rid)
        pr.copy(plumb = pr.plumb.copy(points = pr.plumb.points + got, rooms = pr.plumb.rooms.filter { it.roomId != rid } + er.copy(seen = (er.seen + got.mapNotNull { it.from }).distinct())))
    }
}

/**
 * Puts kit [k] with choices [o] into measured room [rid]: the riser goes in first when there is none (here, when this is
 * a bathroom or toilet or there is none), the manifold with underfloor heating. Returns how many fixtures.
 */
fun App.applyPKit(pid: String, rid: String, k: PKit, o: POpts): Int {
    takeInPlumbPoints(pid, rid)
    val p = store.get(pid) ?: return 0
    val c = ctxOf(p, rid, settings.angleSnap) ?: return 0
    val have = p.plumb.fixes.filter { it.roomId == rid }
    var riser = uz.metrx.app.plumb.liveRiser(p)
    if (riser == null && k.kind != "heat") {
        val wet = p.rooms.any { r -> r.id != rid && ctxOf(p, r.id, settings.angleSnap)?.kind.let { it == "bath" || it == "wc" } }
        if (c.kind == "bath" || c.kind == "wc" || !wet) riser = riserIn(c, have)
    }
    val fs = ArrayList(placeKit(k, c, have, riser, ::uid, o))
    if (o.ufh && p.plumb.fixes.none { it.t == "manif" }) placeFix("manif", c, have + fs, riser, uid())?.let { fs += it }
    store.update(pid) { pr ->
        val er = pr.plumb.room(rid)
        var e = pr.plumb.copy(fixes = pr.plumb.fixes + fs, riser = riser ?: uz.metrx.app.plumb.liveRiser(pr),
            rooms = pr.plumb.rooms.filter { it.roomId != rid } + er.copy(kind = er.kind.ifEmpty { if (k.kind == "heat") c.kind else k.kind }, kits = er.kits + k.id,
                ufh = er.ufh || o.ufh, step = if (o.ufh) o.step else er.step))
        // a riser of its own only when there is water or a drain to bring (radiators and underfloor heating alone need none)
        if (e.riser == null && uz.metrx.app.plumb.needsRiser(pr.copy(plumb = e))) defaultRiser(pr.copy(plumb = e), settings.angleSnap)?.let { e = e.copy(riser = it) }
        pr.copy(plumb = e)
    }
    return fs.size
}

/** Kits chosen for rooms before they were measured go in once the rooms are. */
fun App.applyPPending(pid: String) {
    val p = store.get(pid) ?: return
    p.plumb.rooms.filter { it.pend.isNotEmpty() }.forEach { er ->
        val r = p.rooms.firstOrNull { it.id == er.roomId } ?: return@forEach
        if (!uz.metrx.app.geo.ready3D(r, settings.angleSnap)) return@forEach
        val picks = er.pend
        updatePRoom(pid, er.roomId) { it.copy(pend = emptyList()) }
        picks.forEach { kp -> pkitOf(kp.kit)?.let { k -> applyPKit(pid, er.roomId, k, kp.o) } }
        say("el.pendDone", "r" to dn(r.name, settings.lang))
    }
}

/** The order's routes, counts and warnings, worked out again only when the order changes. */
@Composable
fun rememberPCalc(p: Project): PlumbCalc {
    val s = LocalApp.current.settings
    return remember(p.plumb, p.rooms, p.floors, s.angleSnap) { calcOf(p, s.angleSnap) }
}

/* ---------------- names ---------------- */

/** "Vanna · Unitaz · 2 radiator" — fixtures by type. */
@Composable
fun fixSummary(fs: List<PlFix>): String {
    val parts = FIX_TYPES.mapNotNull { t -> fs.count { it.t == t.id }.takeIf { it > 0 }?.let { n -> if (n == 1) tr("sx.t.${t.id}") else "$n × " + tr("sx.t.${t.id}") } }
    return parts.joinToString(" · ").ifEmpty { tr("sx.noFix") }
}

/* ---------------- Home ---------------- */

@Composable
fun PlumbHome(nav: MainNav) {
    val app = LocalApp.current
    val s = app.settings
    val first = s.builderName.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
    val lines = tr("sx.lines").split('|')
    val orders = app.store.projects.filter { it.isPlumb }.sortedByDescending { it.created }
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
                    Text(tr("sx.newS"), style = ui(14f, 400, G.ink2))
                }
                PathIcon(ARROW, G.ink, 20.dp, 2.2f)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                HomeTile(RULER, tr("gl.meas"), tr("gl.measS"), nav::measure, Modifier.weight(1f))
                HomeTile(TAP, tr("el.gal"), tr("sx.galS"), { nav.newProject() }, Modifier.weight(1f))
            }
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("fo.recent"), style = ui(17f, 800), modifier = Modifier.weight(1f))
                if (orders.isNotEmpty()) Text(tr("fo.all"), style = ui(13.5f, 700, G.cobalt2),
                    modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { app.selectTab(Tab.PROJECTS) }.padding(horizontal = 6.dp, vertical = 8.dp))
            }
            if (orders.isEmpty()) Text(tr("fo.noOrders"), style = ui(14f, 400, G.ink2, 1.45f))
            orders.take(3).forEach { p -> POrderRow(p) { app.push(Route.Project(p.id)) } }
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

/** A plumber's order in a list: its name, its fixtures; the call button. */
@Composable
fun POrderRow(p: Project, onClick: () -> Unit) {
    val lang = LocalLang.current
    Row(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp)).pressable(onClick).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(TAP, G.cobalt, 22.dp, 2f) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(dn(p.name, lang), style = ui(15f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
            val sub = if (p.plumb.fixes.isEmpty() && p.plumb.free.isEmpty()) tr("sx.noFix") else fixSummary(p.plumb.fixes.filter { it.t != "manif" }) +
                if (p.plumb.free.isNotEmpty()) " · " + tr("el.freeN", "n" to p.plumb.free.size) else ""
            Text(sub, style = ui(12.5f, 500, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
            uz.metrx.app.ui.loc.OrderLocRow(p, Modifier.padding(top = 4.dp))
        }
        CallButton(p)
    }
}

/* ---------------- the order's rooms ---------------- */

@Composable
fun PRoomsTab(p: Project, lang: Lang, route: Route.Project) {
    val app = LocalApp.current
    val s = app.settings
    val en = lang == Lang.EN
    // the rooms' water and drain marks are taken in as outlets here too (not only when a room's page opens), so the
    // order's counts, its next step and the PDF have them
    LaunchedEffect(p.rooms) { p.rooms.forEach { app.takeInPlumbPoints(p.id, it.id) }; app.applyPPending(p.id) }
    val calc = rememberPCalc(p)
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (p.floors.isEmpty() && p.plumb.free.isEmpty()) Text(tr("sx.empty"), style = ui(14.5f, 400, G.ink2), textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(22.dp))
        if (calc.ctxs.isNotEmpty()) OrderCard(p, calc)
        // every room of each workspace (an older project may have several in one), a workspace without one once
        p.floors.flatMap { w -> p.rooms.filter { it.floorId == w.id }.ifEmpty { listOf(null) }.map { w to it } }.forEach { (w, room) ->
            val several = p.rooms.count { it.floorId == w.id } > 1
            val ready = room != null && uz.metrx.app.geo.ready3D(room, s.angleSnap)
            val fs = if (room == null) emptyList() else p.plumb.fixes.filter { it.roomId == room.id }
            val er = room?.let { p.plumb.room(it.id) }
            Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable { if (room != null) (if (ready) app.push(Route.PView(p.id, room.id)) else app.openRoom(p.id, room.id)) else app.push(Route.Space(p.id, w.id)) },
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
                if (fs.isNotEmpty() || er?.ufh == true) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable { app.push(Route.PView(p.id, room!!.id)) }
                    .padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(34.dp).clip(RoundedCornerShape(8.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { PathIcon(TAP, G.cobalt, 18.dp, 2f) }
                    Column(Modifier.weight(1f)) {
                        Text(fixSummary(fs).let { if (er?.ufh == true) (if (fs.isEmpty()) "" else "$it · ") + tr("sx.s.ufh") else it }, style = ui(14f, 700), maxLines = 2, overflow = TextOverflow.Ellipsis)
                        val ws = calc.warns.count { it.roomId == room!!.id }
                        if (ws > 0) Text(tr("el.warnN", "n" to ws), style = ui(12.5f, 600, G.amberInk))
                        else if (calc.routes.riser?.roomId == room!!.id) Text(tr("sx.riserHere"), style = ui(12.5f, 500, G.ink2))
                    }
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
                if (er != null && er.pend.isNotEmpty()) Text(tr("el.pending", "k" to er.pend.joinToString(", ") { app.t("sx.kit.${it.kit}") }), style = ui(12.5f, 500, G.amberInk, 1.35f))
                when {
                    room == null -> TodoRow(tr("fo.drawRoom")) { app.drawTileRoom(p.id, w, lang) }
                    !ready -> TodoRow(tr("ns.measureT")) { app.openRoom(p.id, room.id) }
                    else -> TodoRow(tr("el.addKit")) { app.push(Route.PGallery(p.id, room.id)) }
                }
            }
        }
        if (p.plumb.free.isNotEmpty()) Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("el.freeT"), style = ui(16f, 700))
            p.plumb.free.forEach { f ->
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable { app.push(Route.PView(p.id, "free:" + f.id)) }
                    .padding(horizontal = 10.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(34.dp).clip(RoundedCornerShape(8.dp)).background(G.cobalt.copy(alpha = .1f)), contentAlignment = Alignment.Center) { MIcon("cube", G.cobalt, 18.dp, 2f) }
                    Column(Modifier.weight(1f)) {
                        Text(uz.metrx.app.data.dn(f.name, lang).ifBlank { tr(kindKey(f.kind)) }, style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(fmtLen(f.L, LenUnit.M, en) + " × " + fmtLen(f.W, LenUnit.M, en) + " " + tr("u.m") + " · " + tr("sx.freeCnt", "n" to freeCount(f), "m" to fmtLen(f.link, LenUnit.M, en)), style = ui(12.5f, 500, G.ink2), maxLines = 1)
                    }
                    MIcon("chev", G.ink3, 16.dp, 2f)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.push(Route.PGallery(p.id)) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("plus", G.cobalt2, 20.dp, 2.2f); Text(tr("el.addKit"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
            Row(Modifier.weight(1f).height(56.dp).dashedGlass(20.dp).pressable({ app.sheet = Sheet.PNewRoom(p.id) }, .98f),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                MIcon("room", G.cobalt2, 20.dp, 2f); Text(tr("fo.addRoom"), style = ui(15f, 700, G.cobalt2), maxLines = 1)
            }
        }
        Text(tr("el.addFree"), style = ui(14f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).clip(RoundedCornerShape(12.dp))
            .clickable(role = Role.Button) { app.sheet = Sheet.PFree(p.id, null) }.padding(horizontal = 14.dp, vertical = 10.dp))
        if (p.rooms.isNotEmpty() && route.view == "list") GBtn(tr("pj.v2d"), { app.setTop(route.copy(view = "2d")) }, Btn.SECONDARY, icon = "room", height = 46.dp, fontSize = 14.5f)
    }
}

/** How many fixtures a room typed by size has. */
fun freeCount(f: PlFree) = f.wc + f.basin + f.bath + f.shower + f.sink + f.wm + f.dw + f.wh + f.gb + f.rad + f.tr

/** The order's riser, its pipe system and its warnings. */
@Composable
private fun OrderCard(p: Project, calc: PlumbCalc) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val rs = uz.metrx.app.plumb.liveRiser(p)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(vertical = 4.dp)) {
        val rr = rs?.let { x -> p.rooms.firstOrNull { it.id == x.roomId } }
        Line("box", tr("sx.riser"), if (rs != null && rr != null) (p.floors.firstOrNull { it.id == rr.floorId }?.let { floorName(it, lang) } ?: dn(rr.name, lang)) + " · " + tr("tl.wallN", "w" to rs.wall)
            else tr("el.panelNone")) {
            if (rs != null) app.push(Route.PView(p.id, rs.roomId)) else {
                val d = defaultRiser(p, app.settings.angleSnap)
                if (d != null) { app.updatePlumb(p.id) { it.copy(riser = d) }; app.push(Route.PView(p.id, d.roomId)); app.say("sx.riserSet") } else app.say("el.panelNeed")
            }
        }
        Hairline()
        Line("layers", tr("sx.system"), tr("sx.sys.${p.plumb.water}") + " · " + tr("sx.run.${p.plumb.run}")) { app.sheet = Sheet.PSystem(p.id) }
        if (calc.warns.isNotEmpty()) {
            Hairline()
            Line("alert", tr("el.warnN", "n" to calc.warns.size), null, warn = true) {
                (calc.warns.firstOrNull { it.roomId != null }?.roomId ?: rs?.roomId ?: calc.ctxs.firstOrNull()?.id)?.let { app.push(Route.PView(p.id, it)) }
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
fun PNextStep(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val s = app.settings
    val rooms = uz.metrx.app.data.roomsByWorkspace(p)
    val undrawn = p.floors.firstOrNull { w -> p.rooms.none { it.floorId == w.id } }
    val unmeasured = rooms.firstOrNull { (_, r) -> stepKeys(r, s.angleSnap).any { r.dim(it).status != "conf" } }
    val bare = rooms.firstOrNull { (_, r) -> p.plumb.fixes.none { it.roomId == r.id } && p.plumb.room(r.id).pend.isEmpty() && !p.plumb.room(r.id).ufh &&
        p.plumb.room(r.id).kind.ifEmpty { ctxOf(p, r.id, s.angleSnap)?.kind ?: "" } in setOf("bath", "wc", "kitchen", "util") }
    val made = uz.metrx.app.trades.madeBy(p, "sx.e.")
    // a typed-room-only order has no wall for a riser: it is not asked for one
    val riser = uz.metrx.app.plumb.riserToPlace(p, s.angleSnap)
    data class Step(val title: String, val sub: String?, val button: String, val go: () -> Unit)
    val step: Step? = when {
        p.floors.isEmpty() && p.plumb.free.isEmpty() -> Step(tr("sx.ns.pickT"), tr("sx.ns.pickS"), tr("ns.needB")) { app.push(Route.PGallery(p.id)) }
        undrawn != null -> Step(tr("ns.measureT"), floorName(undrawn, lang), tr("fo.drawRoom")) { app.drawTileRoom(p.id, undrawn, lang) }
        unmeasured != null -> Step(tr("ns.measureT"), tr("ns.measureS", "r" to floorName(unmeasured.first, lang)), tr("ns.measureB")) { app.openRoom(p.id, unmeasured.second.id) }
        bare != null -> Step(tr("sx.ns.roomT", "r" to floorName(bare.first, lang)), tr("sx.ns.roomS"), tr("ns.needB")) { app.push(Route.PGallery(p.id, bare.second.id)) }
        riser != null -> Step(tr("sx.ns.riserT"), tr("sx.ns.riserS"), tr("el.ns.panelB")) {
            app.updatePlumb(p.id) { it.copy(riser = riser) }; app.push(Route.PView(p.id, riser.roomId))
        }
        !s.advanced -> Step(tr("ns.shareT"), tr("sx.ns.shareS"), tr("ns.shareB")) { app.push(Route.Report(p.id)) }
        !made -> Step(tr("el.ns.estT"), tr("sx.ns.estS"), tr("trc.apply")) { app.applyPlumbRows(p); app.setProjectTab("estimate") }
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

/** The order page's three numbers in the advanced app: outlets, pipe, the estimate. */
@Composable
fun PNums(p: Project) {
    val app = LocalApp.current
    if (!app.settings.advanced) return
    val lang = LocalLang.current
    val c = rememberPCalc(p).count
    Column(Modifier.padding(top = 11.dp)) {
        Hairline()
        Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Cell(tr("sx.points"), "${c.points}", null, Modifier.weight(1f))
            Cell(tr("sx.pipe"), uz.metrx.app.core.Num.fixed(c.pipeM, 0, lang), tr("u.m"), Modifier.weight(1f))
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

/** Puts the counted pipe, fittings, valves and labour into the order's estimate in place of the calculator's lines; typed lines stay. */
fun App.applyPlumbRows(p: Project) {
    val r = plumbRows(p, settings.trade, settings.angleSnap) { k, v -> if (k.startsWith("tu.")) "@u." + k.removePrefix("tu.") else uz.metrx.app.data.keyName(k, v) }
    store.update(p.id) { pr ->
        pr.copy(stage = if (pr.stage == "measure") "estimate" else pr.stage, estimate = pr.estimate.copy(
            materials = pr.estimate.materials.filter { !it.id.startsWith("t-") } + r.mats.map { it.copy(id = "t-" + uid()) },
            labor = pr.estimate.labor.filter { !it.id.startsWith("t-") } + r.labor.map { it.copy(id = "t-" + uid()) }))
    }
    say("trc.done", "n" to r.mats.size + r.labor.size)
}

/** The estimate tab's card (in place of the old calculator's): what the fixtures and routes take, and the button that puts it in. */
@Composable
fun PlumbCard(p: Project) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val c = rememberPCalc(p).count
    val made = uz.metrx.app.trades.madeBy(p, "sx.e.")
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("sx.cardT"), style = ui(16f, 800))
        Text(tr("trc.plumb", "n" to c.points, "m" to uz.metrx.app.core.Num.fixed(c.pipeM, 1, lang)), style = num(14.5f, 700))
        Text(tr("sx.cardB"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (c.points == 0) Text(tr("sx.noFix"), style = ui(13f, 500, G.amberInk, 1.4f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr(if (made) "trc.update" else "trc.apply"), { app.applyPlumbRows(p) }, enabled = c.points > 0 || c.ufhM > 0, height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
            GBtn(tr("tl.prices"), { app.sheet = Sheet.PPrices(p.id) }, Btn.SECONDARY, icon = "sliders", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
        }
    }
}

/** What the order takes, line by line (the advanced app). */
@Composable
fun PCountCard(p: Project, c: PCount) {
    val lang = LocalLang.current
    fun d1(v: Double) = uz.metrx.app.core.Num.fixed(v, 1, lang)
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(20.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(tr("el.countT"), style = ui(15f, 800))
        c.pipes.forEach { n ->
            val what = when (n.kind) { "ufh" -> tr("sx.c.ufh"); "heat" -> tr("sx.c.heat", "d" to n.dia); else -> tr("sx.c.water", "s" to tr("sx.sys.${p.plumb.water}"), "d" to n.dia) }
            Kv(what, tr(when (n.unit) { "stick" -> "sx.c.sticks"; "m" -> "sx.c.metres"; else -> "sx.c.coils" }, "m" to d1(n.m), "s" to d1(n.withSpare), "n" to n.pieces))
        }
        if (c.drain50 > 0 || c.drain110 > 0) {
            Hairline()
            if (c.drain110 > 0) Kv(tr("sx.c.drain", "d" to 110), d1(c.drain110) + " " + tr("u.m") + " · " + tr("sx.c.bends", "n" to c.bends110, "t" to c.tees110))
            if (c.drain50 > 0) Kv(tr("sx.c.drain", "d" to 50), d1(c.drain50) + " " + tr("u.m") + " · " + tr("sx.c.bends", "n" to c.bends50, "t" to c.tees50))
        }
        Hairline()
        Kv(tr("sx.e.elbow"), "${c.elbows}"); Kv(tr("sx.e.tee"), "${c.tees}")
        if (c.couplings > 0) Kv(tr("sx.e.coup"), "${c.couplings}")
        Kv(tr("sx.e.plate"), "${c.plates}"); Kv(tr("sx.e.ball"), "${c.balls}")
        if (c.meters > 0) Kv(tr("sx.c.riser"), tr("sx.c.riserV", "n" to c.meters))
        if (c.manifolds > 0) Kv(tr("sx.t.manif"), tr("sx.c.loops", "n" to c.loops, "m" to d1(c.ufhM)))
        if (c.chaseM > 0) Kv(tr("sx.c.chase"), d1(c.chaseM) + " " + tr("u.m"))
        Kv(tr("sx.points"), "${c.points}")
    }
}

/* ---------------- sheets ---------------- */

@Composable
fun PlumbSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.PNewRoom -> NewRoomSheet(s.pid)
        is Sheet.PFix -> FixSheet(s)
        is Sheet.PPoint -> PointSheet(s)
        is Sheet.PRoomSet -> RoomSetSheet(s.pid, s.rid)
        is Sheet.PSystem -> SystemSheet(s.pid)
        is Sheet.PPrices -> PricesSheet(s.pid)
        is Sheet.PFree -> FreeSheet(s.pid, s.fid)
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
    var kind by rememberSaveable { mutableStateOf("bath") }
    var name by rememberSaveable { mutableStateOf(nameFor(kind)) }
    fun create() {
        if (name.isBlank() || !app.once()) return
        // a suggested name is kept as its key, so it follows the language
        app.sheet = null
        app.startRoomShape(pid, "plumb", kind, uz.metrx.app.data.suggestedName(name, kindKey(kind), app.settings.lang))
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

/** A fixture: a new one (its type, then it goes on the wall shown), or one placed (its wall, place, width, cabinet, its outlets' heights). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FixSheet(s: Sheet.PFix) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val c = ctxOf(p, s.rid, app.settings.angleSnap) ?: run { app.sheet = null; return }
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    val old = s.fid?.let { id -> p.plumb.fixes.firstOrNull { it.id == id } }
    if (old == null) {
        var cat by rememberSaveable { mutableStateOf("wet") }
        GlassSheet(tr("sx.addFix"), { app.sheet = null }) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                FIX_CATS.forEach { k -> Chip(tr("sx.cat.$k"), k == cat) { cat = k } }
            }
            FIX_TYPES.filter { it.cat == cat }.forEach { ty ->
                Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).clickable(role = Role.Button) {
                    if (!app.once()) return@clickable
                    val have = p.plumb.fixes.filter { it.roomId == c.id }
                    val f = if (ty.id == "rad") placeRadiators(c, have, uz.metrx.app.plumb.liveRiser(p), ::uid).firstOrNull()
                        else s.wall?.let { wid -> c.wall(wid)?.let { w -> uz.metrx.app.plumb.fixSpot(c, ty.id, w, w.len / 2, ty.w, have, uz.metrx.app.plumb.liveRiser(p))?.let { x -> newFix(uid(), ty.id, c, w, x) } } }
                            ?: placeFix(ty.id, c, have, uz.metrx.app.plumb.liveRiser(p), uid())
                    if (f == null) { app.say("el.noSpace"); return@clickable }
                    app.updatePlumb(p.id) { it.copy(fixes = it.fixes + f) }
                    app.sheet = null; app.say("el.devAdded", "n" to app.t("sx.t.${ty.id}"))
                }.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    androidx.compose.foundation.Canvas(Modifier.size(36.dp)) { fixSymbol(ty.id, center, size.minDimension / 2.4f) }
                    Column(Modifier.weight(1f)) {
                        Text(tr("sx.t.${ty.id}"), style = ui(15f, 700))
                        Text(fmtLen(ty.w, LenUnit.M, en) + " × " + fmtLen(ty.d, LenUnit.M, en) + " " + tr("u.m"), style = ui(12.5f, 400, G.ink2))
                    }
                }
            }
        }
        return
    }
    val ty = fixType(old.t)
    var wall by rememberSaveable { mutableStateOf(old.wall) }
    var tOff by rememberSaveable { mutableStateOf(fmtField(old.off, unit, en)) }
    var tW by rememberSaveable { mutableStateOf(fmtField(fixW(old), unit, en)) }
    var cab by rememberSaveable { mutableStateOf(old.opt == "cab") }
    var hs by rememberSaveable { mutableStateOf(old.pts.map { fmtField(it.h, unit, en) }) }
    val vOff = parseMm(tOff, unit); val vW = parseMm(tW, unit)
    val vH = hs.map { parseMm(it, unit) }
    val wl = c.wall(wall)?.len
    val err = when {
        vOff == null || vW == null || vH.any { it == null } -> tr("tl.fixErr")
        // a radiator of two sections at least (and no wider than its wall)
        old.t == "rad" && (vW < 2 * uz.metrx.app.plumb.SEC_MM || (wl != null && vW > wl)) -> tr("sx.radMin", "a" to 2 * uz.metrx.app.plumb.SEC_MM)
        wl != null && vOff > wl -> tr("pt.offBig", "v" to fmtLen(wl.toInt(), unit, en) + " " + tr(uz.metrx.app.ui.rooms.unitKeyOf(unit)))
        vH.any { it!! > c.H } -> tr("pt.hBig", "v" to fmtLen(c.H, unit, en) + " " + tr(uz.metrx.app.ui.rooms.unitKeyOf(unit)))
        else -> null
    }
    fun save() {
        if (err != null || !app.once()) return
        app.updateFix(p.id, old.id) { f ->
            var g = f.copy(wall = wall, off = vOff!!, opt = if ((f.t == "bs" || f.t == "bsm") && cab) "cab" else "")
            if (f.t == "rad" && vW != fixW(f)) g = resizeFix(g, vW!!)
            else g = g.copy(pts = g.pts.mapIndexed { i, q -> q.copy(h = vH.getOrNull(i) ?: q.h) })
            g
        }
        app.sheet = null; app.say("common.save")
    }
    GlassSheet(tr("sx.t.${old.t}"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), ::save, enabled = err == null)
        GBtn(tr("common.delete"), {
            val fixes = app.store.get(p.id)?.plumb?.fixes ?: return@GBtn
            val at = fixes.indexOfFirst { it.id == old.id }; val gone = fixes.getOrNull(at) ?: return@GBtn
            app.updatePlumb(p.id) { e -> e.copy(fixes = e.fixes.filter { it.id != old.id }) }
            app.sheet = null
            // Undo puts back only this fixture, where it was
            app.say("sx.fixDel", action = "common.undo", onAction = { app.updatePlumb(p.id) { e -> if (e.fixes.any { it.id == gone.id }) e else e.copy(fixes = e.fixes.putBack(gone, at)) } })
        }, Btn.SECONDARY)
    }) {
        Text(tr("tl.fixWall"), style = ui(15f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            (c.g.walls + c.g.inner).forEach { w -> Chip(tr("tl.wallN", "w" to w.id), w.id == wall) { wall = w.id } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GField(tr("sx.f.off"), tOff, { v -> tOff = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) }, "1", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            if (old.t == "rad") GField(tr("sx.f.w"), tW, { v -> tW = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) }, "0,6", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
        }
        if (old.t == "rad") Text(tr("sx.radW", "w" to uz.metrx.app.plumb.radWatts(old), "n" to uz.metrx.app.plumb.radSections(c.areaM2) * uz.metrx.app.plumb.SEC_W), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (old.t == "bs" || old.t == "bsm") Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).switchState(cab).clickable(role = Role.Switch) { cab = !cab }
            .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(tr("sx.s.vanity"), style = ui(15f, 700)); Text(tr("sx.s.vanityS"), style = ui(12f, 400, G.ink2, 1.3f)) }
            GSwitch(cab)
        }
        if (old.t != "rad" && old.pts.isNotEmpty()) {
            Text(tr("sx.outlets"), style = ui(15f, 700))
            old.pts.forEachIndexed { i, q ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    androidx.compose.foundation.Canvas(Modifier.size(20.dp)) { ptSymbol(q.t, center, size.minDimension / 3f) }
                    Text(tr("sx.o.${q.t}") + (if (q.d > 0) " ${q.d}" else ""), style = ui(14f, 600), modifier = Modifier.weight(1f))
                    GField(tr("el.f.h"), hs[i], { v -> hs = hs.toMutableList().also { it[i] = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) } }, "${q.h}", decimal = true, labelRight = uw, modifier = Modifier.widthIn(max = 150.dp))
                }
            }
            Text(tr("sx.usualH", "h" to ty.pts.joinToString(", ") { app.t("sx.o.${it.t}") + " " + fmtLen(it.h, LenUnit.M, en) }), style = ui(12.5f, 400, G.ink2, 1.4f))
        }
        Text(tr("sx.dragHint"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (err != null) Text(err, style = ui(13f, 500, G.err))
    }
}

/** A loose outlet: a new one (its kind, on the wall shown) or one placed (kind, wall, place, height, a drain's diameter). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PointSheet(s: Sheet.PPoint) {
    val app = LocalApp.current
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val c = ctxOf(p, s.rid, app.settings.angleSnap) ?: run { app.sheet = null; return }
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    val old = s.ptId?.let { id -> p.plumb.points.firstOrNull { it.id == id } }
    if (old == null) {
        GlassSheet(tr("sx.addPt"), { app.sheet = null }) {
            PT_KINDS.forEach { k ->
                Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).clickable(role = Role.Button) {
                    if (!app.once()) return@clickable
                    val w = c.wall(s.wall) ?: c.g.walls.first()
                    val q = PlPoint(uid(), k, c.id, w.id, (w.len / 2).toInt(), usualPtH(k), if (k == "drain") 50 else 0)
                    app.updatePlumb(p.id) { it.copy(points = it.points + q) }
                    app.sheet = null; app.say("el.devAdded", "n" to app.t("sx.o.$k"))
                }.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    androidx.compose.foundation.Canvas(Modifier.size(28.dp)) { ptSymbol(k, center, size.minDimension / 3f) }
                    Column(Modifier.weight(1f)) {
                        Text(tr("sx.o.$k"), style = ui(15f, 700))
                        Text(tr("el.atH", "h" to fmtLen(usualPtH(k), LenUnit.M, en)), style = ui(12.5f, 400, G.ink2))
                    }
                }
            }
        }
        return
    }
    var t by rememberSaveable { mutableStateOf(old.t) }
    var wall by rememberSaveable { mutableStateOf(old.wall) }
    var tOff by rememberSaveable { mutableStateOf(fmtField(old.off, unit, en)) }
    var tH by rememberSaveable { mutableStateOf(fmtField(old.h, unit, en)) }
    var d by rememberSaveable { mutableStateOf(if (old.d >= 100) 110 else 50) }
    val vOff = parseMm(tOff, unit); val vH = parseMm(tH, unit)
    val wl = c.wall(wall)?.len
    val err = when {
        vOff == null || vH == null -> tr("tl.fixErr")
        wl != null && vOff > wl -> tr("pt.offBig", "v" to fmtLen(wl.toInt(), unit, en) + " " + tr(uz.metrx.app.ui.rooms.unitKeyOf(unit)))
        vH > c.H -> tr("pt.hBig", "v" to fmtLen(c.H, unit, en) + " " + tr(uz.metrx.app.ui.rooms.unitKeyOf(unit)))
        else -> null
    }
    GlassSheet(tr("sx.o.${old.t}"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), {
            if (err != null || !app.once()) return@GBtn
            app.updatePt(p.id, old.id) { it.copy(t = t, wall = wall, off = vOff!!, h = vH!!, d = if (t == "drain") d else 0) }
            app.sheet = null; app.say("common.save")
        }, enabled = err == null)
        GBtn(tr("common.delete"), {
            val pts = app.store.get(p.id)?.plumb?.points ?: return@GBtn
            val at = pts.indexOfFirst { it.id == old.id }; val gone = pts.getOrNull(at) ?: return@GBtn
            app.updatePlumb(p.id) { e -> e.copy(points = e.points.filter { it.id != old.id }) }
            app.sheet = null
            // Undo puts back only this outlet, where it was
            app.say("el.devDel", action = "common.undo", onAction = { app.updatePlumb(p.id) { e -> if (e.points.any { it.id == gone.id }) e else e.copy(points = e.points.putBack(gone, at)) } })
        }, Btn.SECONDARY)
    }) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            PT_KINDS.forEach { k -> Chip(tr("sx.o.$k"), k == t) { t = k } }
        }
        if (t == "drain") FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(50, 110).forEach { v -> Chip("Ø $v", d == v) { d = v } }
        }
        Text(tr("tl.fixWall"), style = ui(15f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            (c.g.walls + c.g.inner).forEach { w -> Chip(tr("tl.wallN", "w" to w.id), w.id == wall) { wall = w.id } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GField(tr("el.f.off"), tOff, { v -> tOff = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) }, "0", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            GField(tr("el.f.h"), tH, { v -> tH = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(8) }, "0", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
        }
        if (old.from != null) Text(tr("sx.fromMark"), style = ui(12.5f, 400, G.ink2, 1.4f))
        Text(tr("sx.ptDrag"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (err != null) Text(err, style = ui(13f, 500, G.err))
    }
}

/** A room's settings: what room it is, its doors and the pipe between them, its underfloor heating, its radiators, the riser here. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun RoomSetSheet(pid: String, rid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val c = ctxOf(p, rid, app.settings.angleSnap) ?: run { app.sheet = null; return }
    val er = p.plumb.room(rid)
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val rs = uz.metrx.app.plumb.liveRiser(p)
    val rc = rs?.let { ctxOf(p, it.roomId, app.settings.angleSnap) }
    var tLink by rememberSaveable { mutableStateOf(fmtField(er.link, unit, en)) }
    GlassSheet(tr("el.roomSet"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), { parseMm(tLink, unit)?.let { v -> app.updatePRoom(pid, rid) { it.copy(link = v.coerceAtMost(100_000)) } }; app.sheet = null; app.say("common.save") })
    }) {
        Text(tr("fr.type"), style = ui(15f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            KINDS.forEach { k -> Chip(tr(kindKey(k)), k == c.kind) { app.updatePRoom(pid, rid) { it.copy(kind = k) } } }
        }
        if (c.ways.size > 1) {
            Text(tr("sx.door"), style = ui(15f, 700))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                c.ways.forEachIndexed { i, o -> Chip(tr("el.doorN", "i" to i + 1, "w" to o.wall), c.entry?.id == o.id) { app.updatePRoom(pid, rid) { it.copy(door = o.id) } } }
            }
        }
        if (rs != null && rc != null && rs.roomId != rid) {
            if (rc.ways.size > 1) {
                Text(tr("sx.pdoor", "r" to dn(rc.room.name, app.settings.lang)), style = ui(15f, 700))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val cur = exitDoor(rc, c)
                    rc.ways.forEachIndexed { i, o -> Chip(tr("el.doorN", "i" to i + 1, "w" to o.wall), cur?.id == o.id) { app.updatePRoom(pid, rid) { it.copy(pdoor = o.id) } } }
                }
            }
            GField(tr("sx.link"), tLink, { v -> tLink = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(7) }, "1", decimal = true, labelRight = tr(if (unit == LenUnit.CM) "u.cm" else "u.m"))
            Text(tr("sx.linkS"), style = ui(12.5f, 400, G.ink2, 1.4f))
        }
        // the heating
        Text(tr("sx.s.heat"), style = ui(15f, 700))
        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).switchState(er.ufh).clickable(role = Role.Switch) {
            val on = !er.ufh
            app.updatePRoom(pid, rid) { it.copy(ufh = on) }
            if (on && p.plumb.fixes.none { it.t == "manif" }) placeFix("manif", c, p.plumb.fixes.filter { it.roomId == rid }, rs, uid())?.let { m -> app.updatePlumb(pid) { it.copy(fixes = it.fixes + m) } }
        }.padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(tr("sx.s.ufh"), style = ui(15f, 700)); Text(tr("sx.s.ufhS"), style = ui(12f, 400, G.ink2, 1.3f)) }
            GSwitch(er.ufh)
        }
        if (er.ufh) FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(100, 150, 200).forEach { v -> Chip(tr("sx.s.stepV", "n" to v / 10), er.step == v) { app.updatePRoom(pid, rid) { it.copy(step = v) } } }
        }
        if (p.plumb.fixes.none { it.roomId == rid && it.t == "rad" }) GBtn(tr("sx.radPut"), {
            val got = placeRadiators(c, p.plumb.fixes.filter { it.roomId == rid }, rs, ::uid)
            if (got.isEmpty()) app.say("el.noSpace") else { app.updatePlumb(pid) { it.copy(fixes = it.fixes + got) }; app.sheet = null; app.say("sx.radDone", "n" to got.size) }
        }, Btn.SECONDARY, icon = "plus")
        if (rs?.roomId != rid) GBtn(tr("sx.riserMove"), {
            val d = riserIn(c, p.plumb.fixes)
            app.updatePlumb(pid) { it.copy(riser = d.copy(hot = rs?.hot ?: true)) }; app.sheet = null; app.say("sx.riserSet")
        }, Btn.SECONDARY, icon = "box")
        GBtn(tr("sx.marks"), { app.sheet = null; app.push(Route.WallView(pid, rid, c.g.walls.first().id)) }, Btn.SECONDARY, icon = "pin")
        if (p.plumb.fixes.any { it.roomId == rid } || p.plumb.points.any { it.roomId == rid }) GBtn(tr("sx.clear"), {
            val before = app.store.get(pid)?.plumb ?: return@GBtn
            val fixes = before.fixes.filter { it.roomId == rid }; val pts = before.points.filter { it.roomId == rid && it.from == null }
            val kits = before.room(rid).kits; val ufh = before.room(rid).ufh
            app.updatePlumb(pid) { e -> e.copy(fixes = e.fixes.filter { it.roomId != rid }, points = e.points.filter { it.roomId != rid || it.from != null },
                rooms = e.rooms.map { if (it.roomId == rid) it.copy(kits = emptyList(), ufh = false) else it }) }
            // Undo puts back only this room's fixtures, outlets, kits and underfloor heating
            app.sheet = null; app.say("el.cleared", action = "common.undo", onAction = { app.updatePlumb(pid) { e ->
                e.copy(fixes = e.fixes + fixes.filter { f -> e.fixes.none { it.id == f.id } }, points = e.points + pts.filter { q -> e.points.none { it.id == q.id } },
                    rooms = e.rooms.map { if (it.roomId == rid) it.copy(kits = kits, ufh = ufh) else it }) } })
        }, Btn.DANGER)
    }
}

/** The order's pipe: the water system, how the water and the heating run, the riser's hot water, the rules' limits, the spare. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SystemSheet(pid: String) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val pl = p.plumb
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    var tWc by rememberSaveable { mutableStateOf(fmtField(pl.wcMax, unit, en)) }
    var tDr by rememberSaveable { mutableStateOf(fmtField(pl.drainMax, unit, en)) }
    GlassSheet(tr("sx.system"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), {
            val a = parseMm(tWc, unit); val b = parseMm(tDr, unit)
            app.updatePlumb(pid) { it.copy(wcMax = (a ?: it.wcMax).coerceIn(200, 20000), drainMax = (b ?: it.drainMax).coerceIn(500, 50000)) }
            app.sheet = null; app.say("common.save")
        })
    }) {
        WATERS.forEach { w ->
            Radio(tr("sx.sys.$w"), tr("sx.sys.${w}S"), pl.water == w) { app.updatePlumb(pid) { it.copy(water = w) } }
        }
        Text(tr("sx.runT"), style = ui(15f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            RUNS.forEach { r -> Chip(tr("sx.run.$r"), pl.run == r) { app.updatePlumb(pid) { it.copy(run = r) } } }
        }
        Text(tr("sx.hrunT"), style = ui(15f, 700))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            RUNS.forEach { r -> Chip(tr("sx.run.$r"), pl.hrun == r) { app.updatePlumb(pid) { it.copy(hrun = r) } } }
        }
        if (pl.riser != null) Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f))
            .switchState(pl.riser.hot).clickable(role = Role.Switch) { app.updatePlumb(pid) { o -> o.copy(riser = o.riser?.let { r -> r.copy(hot = !r.hot) }) } }.padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(tr("sx.riserHot"), style = ui(15f, 700)); Text(tr("sx.riserHotS"), style = ui(12f, 400, G.ink2, 1.3f)) }
            GSwitch(pl.riser.hot)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            GField(tr("sx.wcMax"), tWc, { v -> tWc = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(7) }, "1", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            GField(tr("sx.drainMax"), tDr, { v -> tDr = v.filter { ch -> ch.isDigit() || ch == ',' || ch == '.' }.take(7) }, "3", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
        }
        Text(tr("sx.rulesS"), style = ui(12.5f, 400, G.ink2, 1.4f))
        if (app.settings.advanced) {
            Text(tr("sx.spare"), style = ui(15f, 700))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(5, 10, 15, 20).forEach { v -> Chip("$v %", (pl.spare ?: uz.metrx.app.plumb.PIPE_SPARE) == v) { app.updatePlumb(pid) { it.copy(spare = v) } } }
            }
        }
    }
}

@Composable
private fun Radio(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(shape).background(if (on) G.cobalt.copy(alpha = .1f) else G.glass(.75f))
        .clickable(role = Role.RadioButton, onClick = onClick).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(20.dp).clip(CircleShape).background(if (on) G.cobalt else G.ink.copy(alpha = .12f)), contentAlignment = Alignment.Center) { if (on) Box(Modifier.size(8.dp).clip(CircleShape).background(Color.White)) }
        Column(Modifier.weight(1f)) {
            Text(title, style = ui(15f, 700, if (on) G.cobalt2 else G.ink))
            Text(sub, style = ui(12.5f, 400, G.ink2, 1.35f))
        }
    }
}

/** The plumber's prices, one set for all orders: pipe, drains, fittings, valves, meters and the labour. */
@Composable
private fun PricesSheet(pid: String?) {
    val app = LocalApp.current
    val t0 = app.settings.trade
    class F(val key: String, val unit: String, val get: (uz.metrx.app.trades.TradeSet) -> String, val set: (uz.metrx.app.trades.TradeSet, String) -> uz.metrx.app.trades.TradeSet)
    val fs = listOf(
        F("pX20", "/m", { it.pX20 }, { t, v -> t.copy(pX20 = v) }),
        F("pX25", "/m", { it.pX25 }, { t, v -> t.copy(pX25 = v) }),
        F("pX32", "/m", { it.pX32 }, { t, v -> t.copy(pX32 = v) }),
        F("pHeat", "/m", { it.pHeat }, { t, v -> t.copy(pHeat = v) }),
        F("pUfh", "/m", { it.pUfh }, { t, v -> t.copy(pUfh = v) }),
        F("pD50", "/m", { it.pD50 }, { t, v -> t.copy(pD50 = v) }),
        F("pD110", "/m", { it.pD110 }, { t, v -> t.copy(pD110 = v) }),
        F("pDBend", "", { it.pDBend }, { t, v -> t.copy(pDBend = v) }),
        F("pDTee", "", { it.pDTee }, { t, v -> t.copy(pDTee = v) }),
        F("pElbow", "", { it.pElbow }, { t, v -> t.copy(pElbow = v) }),
        F("pTee", "", { it.pTee }, { t, v -> t.copy(pTee = v) }),
        F("pCoup", "", { it.pCoup }, { t, v -> t.copy(pCoup = v) }),
        F("pPlate", "", { it.pPlate }, { t, v -> t.copy(pPlate = v) }),
        F("pBall", "", { it.pBall }, { t, v -> t.copy(pBall = v) }),
        F("pMainV", "", { it.pMainV }, { t, v -> t.copy(pMainV = v) }),
        F("pMeter", "", { it.pMeter }, { t, v -> t.copy(pMeter = v) }),
        F("pFilter", "", { it.pFilter }, { t, v -> t.copy(pFilter = v) }),
        F("pManif", "", { it.pManif }, { t, v -> t.copy(pManif = v) }),
        F("lPPt", "", { it.lPPt }, { t, v -> t.copy(lPPt = v) }),
        F("lPFix", "", { it.lPFix }, { t, v -> t.copy(lPFix = v) }),
        F("lPM", "/m", { it.lPM }, { t, v -> t.copy(lPM = v) }),
        F("lPRad", "", { it.lPRad }, { t, v -> t.copy(lPRad = v) }),
        F("lPChase", "/m", { it.lPChase }, { t, v -> t.copy(lPChase = v) }))
    var texts by rememberSaveable { mutableStateOf(fs.map { it.get(t0) }) }
    fun save() {
        val t = fs.foldIndexed(t0) { i, acc, f -> texts[i].trim().let { v -> if (v.isEmpty()) acc else f.set(acc, v) } }
        app.settings.setTradeSet(t); app.sheet = null
        pid?.let { id -> app.store.get(id)?.takeIf { pr -> uz.metrx.app.trades.madeBy(pr, "sx.e.") }?.let { app.applyPlumbRows(it) } } ?: app.say("common.save")
    }
    GlassSheet(tr("tl.prices"), { app.sheet = null }, footer = { GBtn(tr("common.save"), ::save) }) {
        fs.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { f ->
                    val i = fs.indexOf(f)
                    GField(tr("sx.p.${f.key}"), texts[i], { v -> texts = texts.toMutableList().also { it[i] = v.filter { c -> c.isDigit() }.take(12) } }, "0",
                        number = true, labelRight = f.unit.ifEmpty { null }?.let { uz.metrx.app.ui.projects.unitText(it) }, modifier = Modifier.weight(1f))
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        Text(tr("sx.pricesNote"), style = ui(12.5f, 400, G.ink2, 1.4f))
    }
}

/** A switch line of the typed room's sheet. */
@Composable
private fun FreeSwitch(label: String, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).background(G.glass(.55f)).switchState(on).clickable(role = Role.Switch, onClick = onClick)
        .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = ui(14f, 600, G.ink2), modifier = Modifier.weight(1f)); GSwitch(on)
    }
}

/** A room typed by size: its name and kind, length, width and height, how many of each fixture, the heating and the pipe to the riser. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FreeSheet(pid: String, fid: String?) {
    val app = LocalApp.current
    val p = app.store.get(pid) ?: run { app.sheet = null; return }
    val en = app.settings.lang == Lang.EN
    val unit = app.settings.unit
    val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
    val old = fid?.let { id -> p.plumb.free.firstOrNull { it.id == id } }
    val start = old ?: PlFree(uid(), "@" + kindKey("bath"), "bath")
    var kind by rememberSaveable { mutableStateOf(start.kind) }
    // a kind's own name is kept as its key, so it follows the language
    var name by rememberSaveable { mutableStateOf(uz.metrx.app.data.dn(start.name, app.settings.lang)) }
    fun keptName() = name.trim().let { t -> if (t == uz.metrx.app.data.dn(start.name, app.settings.lang)) start.name else if (t == app.t(kindKey(kind))) "@" + kindKey(kind) else t }
    var tl by rememberSaveable { mutableStateOf(fmtField(start.L, unit, en)) }
    var tw by rememberSaveable { mutableStateOf(fmtField(start.W, unit, en)) }
    var th by rememberSaveable { mutableStateOf(fmtField(start.H, unit, en)) }
    var tk by rememberSaveable { mutableStateOf(fmtField(start.link, unit, en)) }
    // an older room shows the choices its kit made (towel rail, hand basin, cabin)
    val kit0 = uz.metrx.app.plumb.withKit(start)
    var cnt by rememberSaveable { mutableStateOf(listOf(start.wc, start.basin, start.bath, start.shower, start.sink, start.wm, start.dw, start.wh, start.gb, start.rad, kit0.tr)) }
    var ufh by rememberSaveable { mutableStateOf(start.ufh) }
    var small by rememberSaveable { mutableStateOf(kit0.small) }
    var cabin by rememberSaveable { mutableStateOf(kit0.cabin) }
    val L = parseMm(tl, unit); val W = parseMm(tw, unit); val H = parseMm(th, unit); val K = parseMm(tk, unit)
    val ok = L != null && W != null && H != null && K != null && L in 800..30000 && W in 800..30000 && H in 2000..6000
    fun save() {
        if (!ok || !app.once()) return
        val f = start.copy(name = keptName(), kind = kind, L = L!!, W = W!!, H = H!!, link = K!!, wc = cnt[0], basin = cnt[1], bath = cnt[2], shower = cnt[3], sink = cnt[4],
            wm = cnt[5], dw = cnt[6], wh = cnt[7], gb = cnt[8], rad = cnt[9], ufh = ufh, tr = cnt[10], small = small, cabin = cabin, kept = true)
        app.updatePlumb(pid) { e -> e.copy(free = if (old != null) e.free.map { if (it.id == f.id) f else it } else e.free + f) }
        app.sheet = null
        if (old == null) app.push(Route.PView(pid, "free:" + f.id))
        app.say("common.save")
    }
    GlassSheet(tr(if (old == null) "el.addFree" else "el.freeEdit"), { app.sheet = null }, footer = {
        GBtn(tr("common.save"), ::save, enabled = ok)
        if (old != null) GBtn(tr("common.delete"), {
            app.updatePlumb(pid) { e -> e.copy(free = e.free.filter { it.id != old.id }) }
            app.sheet = null; app.popTo { it is Route.Project && it.id == pid }; app.say("el.freeDel")
        }, Btn.SECONDARY)
    }) {
        Text(tr("sx.freeB"), style = ui(13f, 400, G.ink2, 1.4f))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            KINDS.forEach { k -> Chip(tr(kindKey(k)), k == kind) { if (name.isBlank() || name == app.t(kindKey(kind))) name = app.t(kindKey(k)); kind = k } }
        }
        GField(tr("fr.name"), name, { name = it.take(uz.metrx.app.ui.editor.NAME_MAX) }, tr(kindKey(kind)))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GField(tr("tl.pa"), tl, { v -> tl = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2,5", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            GField(tr("tl.pbW"), tw, { v -> tw = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
            GField(tr("tl.pbH"), th, { v -> th = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2,7", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
        }
        listOf("wc", "bs", "bath", "sh", "sink", "wm", "dw", "wh", "gb", "rad", "tr").forEachIndexed { i, k ->
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(tr("sx.t.$k"), style = ui(15f, 600), modifier = Modifier.weight(1f))
                Stepper(cnt[i]) { v -> cnt = cnt.toMutableList().also { it[i] = v.coerceIn(0, 6) } }
            }
            // the basins as hand basins (cold only), the showers as cabins
            if (k == "bs" && cnt[1] > 0) FreeSwitch(tr("sx.t.bsm"), small) { small = !small }
            if (k == "sh" && cnt[3] > 0) FreeSwitch(tr("sx.t.cab"), cabin) { cabin = !cabin }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.7f)).switchState(ufh).clickable(role = Role.Switch) { ufh = !ufh }
            .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(tr("sx.s.ufh"), style = ui(15f, 700), modifier = Modifier.weight(1f)); GSwitch(ufh)
        }
        GField(tr("sx.freeLink"), tk, { v -> tk = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "3", decimal = true, labelRight = uw)
        if (!ok) Text(tr("sx.freeErr"), style = ui(13f, 500, G.err))
    }
}
