package uz.metrx.app.ui.furniture

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uz.metrx.app.core.Lang
import uz.metrx.app.core.shortMoney
import uz.metrx.app.data.Project
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.furniture.F_MODELS
import uz.metrx.app.furniture.FModelDef
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.Pose
import uz.metrx.app.furniture.K_CORNER
import uz.metrx.app.furniture.W_DEPTH
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.fitIssues
import uz.metrx.app.furniture.fitTo
import uz.metrx.app.furniture.freeLen
import uz.metrx.app.furniture.freeRunMm
import uz.metrx.app.furniture.newFreeKitchen
import uz.metrx.app.furniture.newFreeWardrobe
import uz.metrx.app.furniture.placeWalls
import uz.metrx.app.furniture.placed
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.furniture.runEnd
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.sidesOf
import uz.metrx.app.furniture.takenOut
import uz.metrx.app.furniture.roomKitchen
import uz.metrx.app.furniture.roomCabinet
import uz.metrx.app.furniture.resized
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.fmtField
import uz.metrx.app.furniture.wardOfF
import uz.metrx.app.geo.stepKeys
import uz.metrx.app.geo.walls
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.GlassSheet
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.dashedGlass
import uz.metrx.app.ui.editor.Seg
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * Furniture without a room (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html v4): after the
 * three-field new order, "Nima kerak?"; for each piece the room or only its sizes; a gallery of ready models with 3D
 * pictures; the sizes; later "Xonaga qo‘yish" into a measured room, and "Xonadan chiqarish" back out. The rules are in
 * furniture/Free.kt.
 */

/* ---------------- the order's name and what is still wanted ---------------- */

/** While the order's name follows its furniture: "Oshxona — Akmal", "Shkaf — Akmal", "Oshxona va shkaf — Akmal". */
fun App.renameOrder(pid: String) {
    store.update(pid) { p ->
        if (!p.autoName) p else {
            val ks = (p.furniture.map { uz.metrx.app.furniture.kindKey(it) } + (p.want ?: emptyList())).toSet()
            val what = when {
                ks.isEmpty() -> null
                ks == setOf("kitchen", "wardrobe") -> t("fo.both")
                ks == setOf("wardrobe") -> t("kt.wardrobe")
                ks == setOf("kitchen") -> t("kt.kitchen")
                else -> t("fz.furn")
            }
            p.copy(name = what?.let { it + " — " + p.customer } ?: p.customer)
        }
    }
}

/** A room every wall and the height of which are confirmed. */
fun measuredRoom(r: uz.metrx.app.data.Room, snap: Boolean) = stepKeys(r, snap).all { r.dim(it).status == "conf" }

/** Takes the piece out of its room: its sizes from what stands on the walls now. */
fun App.takeOut(pid: String, fid: String) {
    val p = store.get(pid) ?: return
    val f = p.furniture.firstOrNull { it.id == fid } ?: return
    val room = roomOf(p, f)
    val snap = settings.angleSnap
    val g = takenOut(f, { id -> room?.let { wallLen(it, snap, id) } }, room?.dim("H")?.v)
    store.update(pid) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == fid) g else it }) }
    kit.forget(fid); kit.sel = null; kit.tick++
    say("fz.outDone", "n" to dn(f.name, settings.lang))
}

/** The order's furniture with the pieces of these rooms taken out (the rooms are going away). */
fun App.outOfRooms(p: uz.metrx.app.data.Project, rids: Set<String>): List<Furniture> = p.furniture.map { f ->
    val room = p.rooms.firstOrNull { it.id == f.roomId }
    if (f.roomId == null || f.roomId !in rids || room == null) f
    else takenOut(f, { id -> wallLen(room, settings.angleSnap, id) }, room.dim("H").v)
}

internal fun App.designer(pid: String, f: Furniture, step: Int = 1): Route =
    if (f.kind == "wardrobe") Route.Wardrobe(pid, f.id, step = step) else Route.Kitchen(pid, f.id)

/* ---------------- the page frame ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
internal fun FPage(eyebrow: String, title: String, back: () -> Unit, footer: (@Composable ColumnScope.() -> Unit)? = null, body: @Composable ColumnScope.() -> Unit) {
    val imeOn = WindowInsets.isImeVisible
    val foot: @Composable (Modifier) -> Unit = { m -> if (footer != null) FloatingFooter(m) { footer() } }
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), back, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(title, eyebrow = eyebrow)
            }
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = if (footer != null && !imeOn) 120.dp else 28.dp)
                    .let { if (footer == null) it.navigationBarsPadding() else it },
                verticalArrangement = Arrangement.spacedBy(12.dp), content = body
            )
            if (imeOn) foot(Modifier)
        }
        if (!imeOn) foot(Modifier.align(Alignment.BottomCenter))
    }
}

/* ---------------- on the designers and the order: room-less pieces ---------------- */

/** On a room-less piece's designer: it has no room yet, and the way into one. */
@Composable
fun FreeBanner(p: Project, f: Furniture) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(G.cobalt.copy(alpha = .08f)).border(1.dp, G.cobalt.copy(alpha = .25f), RoundedCornerShape(16.dp))
        .padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(tr("fz.banner"), style = ui(13.5f, 500, G.ink, 1.4f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GBtn(tr("fz.toRoom"), { app.sheet = Sheet.FPickRoom(p.id, f.id) }, icon = "room", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("fz.sizesBtn"), { app.push(Route.FSteps(p.id, uz.metrx.app.furniture.modelOf(f).id, f.id)) }, Btn.SECONDARY,
                icon = "ruler", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        }
    }
}

/** A room-less piece's line: its model, sizes and running metres. */
@Composable
fun freeSub(f: Furniture, en: Boolean): String {
    val fu = LocalApp.current.settings.furnUnit
    fun m(v: Int) = uz.metrx.app.geo.fmtLen(v, fu, en)
    if (f.kind == "wardrobe") {
        val w = wardOfF(f) ?: return ""
        // the height as asked: a cabinet's with its legs
        val v = uz.metrx.app.furniture.valsOf(f, LocalApp.current.settings.workshop)
        val h = v["h"] ?: w.h
        val sizes = when {
            "mw" in v -> m(v.getValue("mw")) + " × " + m(v["ml"] ?: 0) + " " + unitWord(fu)
            "w2" in v -> m(v.getValue("w")) + " + " + m(v.getValue("w2")) + " × " + m(h) + " " + unitWord(fu)
            else -> m(v["w"] ?: w.w) + " × " + m(h) + " × " + m(v["d"] ?: w.d) + " " + unitWord(fu)
        }
        // a sliding wardrobe is named by the doors it has now, not by the model it started from ("Kupe, 3 eshik" → 4)
        val label = w.slide?.let { tr("fz.slideNow", "n" to it.n) } ?: f.model.takeIf { it.isNotEmpty() }?.let { tr(if (f.type.isNotEmpty()) "ft.$it" else "fz.m.$it") }
        return listOfNotNull(label, sizes).joinToString(" · ")
    }
    // the typed sizes only while the piece has no room (put in one, they are its old ones); the running metres are the
    // units' (what the price counts, Pricing.runMm), the typed sizes' only before there are units
    val fs = f.free?.takeIf { f.roomId == null }
    val run = if (f.modules.isNotEmpty()) uz.metrx.app.furniture.runMm(f) else fs?.let { freeRunMm(f.layout, it.sides, it.island) } ?: 0
    return listOfNotNull(tr(if (f.model.isNotEmpty()) "fz.m.${f.model}" else "kt.l${f.layout}"),
        fs?.let { (it.sides + listOfNotNull(it.island.takeIf { i -> i > 0 })).joinToString(" + ") { v -> m(v) } + " " + unitWord(fu) },
        pogM(run, en) + " " + tr("kt.pm")).joinToString(" · ")
}

/** Running metres of [mm] to one decimal ("5,4"; English "5.4"), as every card, the designer and the price show them. */
fun pogM(mm: Int, en: Boolean): String { val t = (max(0, mm) + 50) / 100; return "${t / 10}${if (en) "." else ","}${t % 10}" }

/** "Xonasiz mebel": the order's pieces without a room, each with its price and "Xonaga qo‘yish". */
@Composable
fun FreeCard(p: Project, lang: Lang) {
    val app = LocalApp.current
    val s = app.settings
    val en = lang == Lang.EN
    val free = p.furniture.filter { it.roomId == null }
    if (free.isEmpty()) return
    val priced = remember(p.furniture, p.fprice, s.workshop, s.mats, s.hws) { priceOf(p.furniture.filter { it.modules.isNotEmpty() }, p.fprice, s.workshop, s.mats, s.hws) }
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.55f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(64.dp, 52.dp).clip(RoundedCornerShape(12.dp)).background(G.cobalt.copy(alpha = .08f)), contentAlignment = Alignment.Center) { MIcon("ruler", G.cobalt, 24.dp, 2f) }
            Column(Modifier.weight(1f)) {
                Text(tr("fz.free"), style = ui(16f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(tr("fz.freeS"), style = ui(12.5f, 400, G.ink2), maxLines = 1)
            }
        }
        free.forEach { f ->
            PieceRow(p, f, freeSub(f, en), priced.lines.firstOrNull { it.key == f.id }?.amount, lang) { app.kit.sel = null; app.push(app.designer(p.id, f)) }
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).dashedGlass(14.dp).clickable(role = Role.Button) { app.sheet = Sheet.FPickRoom(p.id, f.id) }.padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MIcon("plus", G.cobalt2, 18.dp, 2.2f)
                Text(tr("fz.toRoom"), style = ui(14.5f, 700, G.cobalt2))
            }
        }
    }
}

/**
 * A piece in the order's Mebel tab, as the mockup's furniture card: its own 3D picture, the name, the sizes, the
 * style and the price (simple mode grey "≈ … mln", Advanced the exact one). [badge] sits after the name.
 */
@Composable
internal fun PieceRow(p: Project, f: Furniture, sub: String, amount: java.math.BigInteger?, lang: Lang, badge: (@Composable () -> Unit)? = null, onClick: () -> Unit) {
    val s = LocalApp.current.settings
    val en = lang == Lang.EN
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.glass(.75f)).clickable(onClick = onClick)
        .padding(horizontal = 10.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        PiecePic(f, Modifier.size(84.dp, 64.dp).clip(RoundedCornerShape(10.dp)).background(Color(0xFF000000.toInt() or uz.metrx.app.ui.three.CARD_BG)))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(dn(f.name, lang), style = ui(14.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                badge?.invoke()
            }
            if (sub.isNotBlank()) Text(sub, style = num(12.5f, 500, G.ink2), maxLines = 2, overflow = TextOverflow.Ellipsis)
            val style = f.look?.preset.orEmpty()
            if (style.isNotEmpty()) Text(tr("lk.p.$style"), style = ui(12.5f, 400, G.ink2), maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (amount != null && amount.signum() > 0) {
                val (v, u) = shortMoney(p, amount, en, tr("pl.mln"))
                val w = v + (u?.let { " $it" } ?: "")
                if (s.advanced) Text(w, style = num(14f, 700)) else Text(tr("ux.approxShort", "v" to w), style = num(13f, 600, G.ink3))
            }
        }
        MIcon("chev", G.ink3, 16.dp, 2f)
    }
}

/* ---------------- which room ---------------- */

@Composable
fun FreeSheet(s: Sheet): Boolean {
    when (s) {
        is Sheet.FPickRoom -> PickRoomSheet(s)
        else -> return false
    }
    return true
}

@Composable
private fun PickRoomSheet(s: Sheet.FPickRoom) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(s.pid) ?: run { app.sheet = null; return }
    val f = p.furniture.firstOrNull { it.id == s.fid } ?: run { app.sheet = null; return }
    val snap = app.settings.angleSnap
    val rooms = p.rooms.filter { measuredRoom(it, snap) }
    fun m(v: Int?) = v?.let { uz.metrx.app.geo.fmtLen(it, app.settings.furnUnit, en) } ?: "?"
    GlassSheet(tr("fz.pickT", "n" to dn(f.name, lang)), { app.sheet = null }) {
        if (rooms.isEmpty()) Text(tr("fz.noMeasured"), style = ui(14f, 400, G.ink2, 1.45f))
        rooms.forEach { r ->
            val w = p.floors.firstOrNull { it.id == r.floorId }
            Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(14.dp)).background(G.ink.copy(alpha = .05f))
                .clickable(role = Role.Button) { app.sheet = null; app.push(Route.FPlace(p.id, f.id, r.id)) }.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MIcon(if (w?.type == "kitchen") "kitchen" else "room", G.cobalt, 22.dp, 2f)
                Column(Modifier.weight(1f)) {
                    Text(w?.let { floorName(it, lang) } ?: dn(r.name, lang), style = ui(15.5f, 700), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(uz.metrx.app.geo.roomSize(r, app.settings.angleSnap).let { m(it?.first) + " × " + m(it?.second) } + " " + unitWord(app.settings.furnUnit) + " · h " + m(r.dim("H").v), style = num(12.5f, 500, G.ink2), maxLines = 1)
                }
                MIcon("chev", G.ink3, 16.dp, 2f)
            }
        }
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).dashedGlass(14.dp).clickable(role = Role.Button) { app.sheet = Sheet.FNewRoom(p.id, f.kind, f.id) }.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("plus", G.cobalt2, 18.dp, 2.2f)
            Text(tr("fz.newRoom"), style = ui(15f, 700, G.cobalt2))
        }
    }
}

/* ---------------- into the room ---------------- */

/** A new piece's name: "Oshxona 2", "Shkaf 3", "Komod 1" (counted by kind, or by type for the other pieces). */
internal fun App.pieceName(p: uz.metrx.app.data.Project, m: FModelDef): String {
    val n = p.furniture.count { if (m.type.isNotEmpty()) it.type == m.type else it.kind == m.kind && it.type.isEmpty() } + 1
    return when { m.type.isNotEmpty() -> t("ft.${m.type}") + " $n"; m.kind == "kitchen" -> t("kt.nameN", "n" to n); else -> t("wd.nameN", "n" to n) }
}

/** Adds a new piece to the order: the stage moves on from measuring, what they want grows, the name follows. */
internal fun App.addPiece(pid: String, f0: Furniture) {
    // a new piece starts in the order's design style (Look.kt)
    val st = store.get(pid)?.fstyle.orEmpty()
    val f = if (f0.look == null && st.isNotEmpty()) uz.metrx.app.furniture.withPreset(f0, st, fresh = true, ws = settings.workshop) else f0
    store.update(pid) { pr -> pr.copy(furniture = pr.furniture + f, stage = if (pr.stage == "measure") "design" else pr.stage,
        want = ((pr.want ?: emptyList()) + uz.metrx.app.furniture.kindKey(f)).distinct()) }
    renameOrder(pid)
}

@Composable
fun FPlaceScreen(rt: Route.FPlace) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val room = p.rooms.firstOrNull { it.id == rt.rid } ?: return
    val snap = app.settings.angleSnap
    val ws = app.settings.workshop
    val unit = app.settings.furnUnit
    val wl = walls(room, snap)
    // a piece on one wall may stand against an inner wall's face too (geo/InnerWalls.kt); corner pieces and kitchens round the outer walls
    val wlAll = uz.metrx.app.geo.allWalls(room, snap)
    val ids0 = wl.map { it.id }
    val ids = wlAll.map { it.id }
    val len = { id: String -> wallLen(room, snap, id) }
    val roomH = room.dim("H").v
    // the piece: one of the order's, or a new one of a model (its typed sizes, or the room's own when vals is null)
    val model = rt.model?.let { fModel(it) }
    val known = rt.fid == null && rt.vals == null && model != null
    val existing = rt.fid?.let { id -> p.furniture.firstOrNull { it.id == id } }
    if (existing == null && model == null) return
    val name = remember(rt) { existing?.name ?: app.pieceName(p, model!!) }
    val typed = remember(rt) { decodeVals(rt.vals) }
    // a piece standing free in the room (a bed, a table) takes no wall
    val taken = p.furniture.filter { it.roomId == room.id && it.id != rt.fid && (it.pose == null || it.kind == "kitchen") }.flatMap { it.walls }.filter { it != ISLAND }
    // a piece already in this room starts where it stands
    val here = existing?.takeIf { it.roomId == room.id }
    var first by rememberSaveable { mutableStateOf(here?.walls?.firstOrNull { it != ISLAND && it in ids } ?: ids.firstOrNull { it !in taken } ?: ids.first()) }
    var off by rememberSaveable { mutableStateOf(here?.takeIf { it.kind == "wardrobe" }?.let { uz.metrx.app.furniture.runStart(it) }?.takeIf { it != uz.metrx.app.furniture.cornerGap(here) }?.toString() ?: "") }   // a wardrobe's distance from the corner; "" = in the corner
    var start by rememberSaveable { mutableStateOf(here?.let { uz.metrx.app.furniture.leadOf(it) }?.takeIf { here.walls.count { w -> w != ISLAND } == 1 } ?: 0) }   // a one-wall kitchen's
    var poseS by rememberSaveable { mutableStateOf(here?.pose?.let { "${it.ref},${it.a},${it.n},${it.deg}" } ?: "") }   // dragged off the walls: a desk, the island
    val pose = poseS.split(',').takeIf { it.size == 4 }?.let { Pose(it[0], it[1].toInt(), it[2].toInt(), it[3].toInt()) }
    fun setPose(v: Pose?) { poseS = v?.let { "${it.ref},${it.a},${it.n},${it.deg}" } ?: "" }
    var wTxt by rememberSaveable { mutableStateOf("") }         // a new cabinet's width in a known room; "" = as made
    var keep by rememberSaveable { mutableStateOf(false) }
    // the fitted piece survives turning the phone (kept as its JSON)
    var fittedJ by rememberSaveable { mutableStateOf("") }
    val fitted: Furniture? = remember(fittedJ) { fittedJ.takeIf { it.isNotEmpty() }?.let { runCatching { kotlinx.serialization.json.Json.decodeFromString(Furniture.serializer(), it) }.getOrNull() } }
    fun setFitted(v: Furniture?) { fittedJ = v?.let { kotlinx.serialization.json.Json.encodeToString(Furniture.serializer(), it) } ?: "" }
    val base: Furniture = remember(rt, first, wTxt) {
        when {
            existing != null -> uz.metrx.app.furniture.withoutLead(existing, len)
            known && model!!.kind == "kitchen" -> roomKitchen(model, ids0, first, len, roomH, ws, name, System.currentTimeMillis())
            known -> roomCabinet(model!!, len(first), roomH, ws, name, System.currentTimeMillis()).let { c ->
                parseMm(wTxt, unit)?.let { w -> resized(c, mapOf("w" to w.coerceIn(300, 6000)), ws) } ?: c }
            else -> pieceOf(model!!, typed, ws, name, System.currentTimeMillis())
        }
    }
    // a corner piece goes into a corner like a corner kitchen; the other cabinets stand along one wall
    val corner = base.type in uz.metrx.app.furniture.CORNER_TYPES
    val ward = base.kind == "wardrobe" && !corner
    val offMm = off.filter { it.isDigit() }.toIntOrNull()?.takeIf { it > 0 }
    val f = fitted ?: base
    val single = f.kind != "kitchen" && f.type !in uz.metrx.app.furniture.CORNER_TYPES
    val on = placeWalls(f, if (single) ids else ids0, first)
    // the room's depth in front of a wall, once every wall is measured (a piece deeper than that goes through the wall opposite)
    val deep: (String) -> Int? = { id -> walls(room, snap).takeIf { ws0 -> ws0.all { it.len != null } }?.let { ws0 ->
        ws0.firstOrNull { it.id == id }?.let { w -> uz.metrx.app.furniture.depthFrom(w.p0, w.p1, ws0.map { it.p0 }) } } }
    val issues = fitIssues(f.copy(pose = pose?.takeIf { uz.metrx.app.furniture.canBeFree(f) }), on, len, roomH, ws, offMm, start, deep)
    // where it would stand, and what it would be in the way of there
    val pw = remember(room, snap) { uz.metrx.app.furniture.planWalls(room, snap) }
    val others = p.furniture.filter { it.roomId == room.id && it.id != rt.fid }
    val g = placed(f, on, room.id, room.floorId, offMm, keep = issues.isNotEmpty(), len = len, ws = ws, start = start, pose = pose)
    val warns = uz.metrx.app.furniture.placeWarnings(g, others, room, pw, ws)
    val floor = p.floors.firstOrNull { it.id == room.floorId }
    val roomName = floor?.let { floorName(it, lang) } ?: dn(room.name, lang)
    fun reset() { setFitted(null); keep = false }

    fun place() {
        if (issues.isNotEmpty() && !keep) { app.say("fz.pickFirst", kind = ToastKind.ERROR); return }
        if (!app.once()) return
        if (existing != null) app.store.update(p.id) { pr -> pr.copy(furniture = pr.furniture.map { if (it.id == g.id) g else it }, stage = if (pr.stage == "measure") "design" else pr.stage) }
        else app.addPiece(p.id, g)
        app.kit.forget(g.id); app.kit.sel = null; app.kit.tick++
        app.popTo { it is Route.Project && it.id == p.id }
        app.push(app.designer(p.id, g, step = if (existing == null) 2 else 1))
        app.say("fz.placed", "n" to dn(g.name, lang), "r" to roomName)
    }

    // a new piece in the room: asked once where it goes (28 Oct 2026) — against a wall, or free in the room's middle
    var asked by rememberSaveable(rt) { mutableStateOf(here != null || !uz.metrx.app.furniture.canBeFree(base)) }
    Box(Modifier.fillMaxSize()) {
        FPage(dn(f.name, lang) + " → " + roomName, tr("fz.toRoom"), { app.pop() },
            footer = { GBtn(tr("fz.placeHere"), ::place, enabled = issues.isEmpty() || keep) }) {
            PlacePlan(room, pw, g, others, ws, warns.isNotEmpty() || issues.isNotEmpty(), tr("fz.planLabel"),
                onSlide = { w, x ->
                    if (w != first) { first = w; reset() }
                    if (ward) off = if (x == uz.metrx.app.furniture.cornerGap(f)) "" else x.toString() else start = x
                    if (ward) setPose(null)
                },
                onCorner = { w -> if (w != first) { first = w; setPose(null); reset() } },
                onPose = { setPose(it) }, onIsland = { setPose(it) })
            // a piece standing free: dragged anywhere, and the wall chips below stick it back to a wall (none of them is "on")
            val freeNow = ward && pose != null
            Text(tr(if (freeNow) "fz.dragHintFree" else "fz.dragHint"), style = ui(12.5f, 400, G.ink2, 1.4f))
            // a desk or the island turns, 15° a tap, about its middle
            val turnable = uz.metrx.app.furniture.canStandFree(f) || (pose != null && uz.metrx.app.furniture.canBeFree(f)) || ISLAND in f.walls
            if (turnable) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(-15 to "fz.turnL", 15 to "fz.turnR").forEach { (d, k) ->
                    GBtn(tr(k), {
                        if (ISLAND in f.walls) uz.metrx.app.furniture.islandPoseIn(g, pw)?.let { ip -> uz.metrx.app.furniture.frameOf(pw, ip) }?.let { fr ->
                            setPose(uz.metrx.app.furniture.poseOf(pw, first, uz.metrx.app.furniture.turned(fr, uz.metrx.app.furniture.islandLen(g).toDouble(), 600.0, d)))
                        } else wardOfF(g)?.let { m -> uz.metrx.app.furniture.mainFrame(g, pw)?.let { fr ->
                            setPose(uz.metrx.app.furniture.poseOf(pw, pose?.ref ?: first, uz.metrx.app.furniture.turned(fr, m.w.toDouble(), m.d.toDouble(), d)))
                        } }
                    }, Btn.SECONDARY, icon = if (d < 0) "undo" else "redo", height = 44.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
                }
            }
            if (warns.isNotEmpty()) Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                warns.forEach { i -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { MIcon("alert", G.amberInk, 16.dp, 2f); Text(issueText(app, i, lang), style = ui(13f, 600, G.amberInk, 1.35f)) } }
            }
            Text(tr(if (freeNow) "fz.wallQFree" else if (ward) "fz.wallQ" else "fz.first"), style = ui(15f, 700))
            androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                (if (single) wlAll else wl).forEach { w -> Chip(tr("kt.wallN", "w" to w.id) + (len(w.id)?.let { " · " + fmtLen(it, unit, en) + " " + unitWord(unit) } ?: ""), w.id == first && !freeNow) { if (w.id != first || freeNow) { first = w.id; start = 0; setPose(null); reset() } } }
            }
            if (!ward && on.count { it != ISLAND } > 1) Text(tr("fz.nextWalls", "w" to on.drop(1).filter { it != ISLAND }.joinToString(", ")), style = ui(13f, 400, G.ink2, 1.4f))
            // a kitchen for a measured room takes its walls whole
            if (known && base.kind == "kitchen") Text(tr("fq.whole", "v" to (f.free?.sides ?: emptyList()).joinToString(" + ") { fmtLen(it, unit, en) } + " " + unitWord(unit),
                "h" to fmtLen(roomH, unit, en) + " " + unitWord(unit)), style = ui(13f, 400, G.ink2, 1.4f))
            if (on.any { it in taken }) Text(tr("kt.wallTaken", "w" to on.first { it in taken }, "n" to dn(p.furniture.first { it.roomId == room.id && it.id != rt.fid && (it.pose == null || it.kind == "kitchen") && on.any { w -> w != ISLAND && w in it.walls } }.name, lang)),
                style = ui(12.5f, 500, G.amberInk, 1.4f))
            if (ward) {
                if (known && model != null && model.type !in uz.metrx.app.furniture.ITEM_TYPES) GField(tr("wd.w"), wTxt, { wTxt = it.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(6); reset() }, wardOfF(base)?.let { fmtField(it.w, unit, en) } ?: "",
                    labelRight = unitWord(unit))
                // standing free it has no distance from a corner
                if (pose == null) Text(tr("fz.offset"), style = ui(15f, 700))
                if (pose == null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Chip(tr("fz.corner"), offMm == null) { off = ""; setPose(null); reset() }
                    GField(null, off, { off = it.filter { c -> c.isDigit() }.take(5); reset() }, "0", number = true, labelRight = tr("u.mm"), imeAction = ImeAction.Done, modifier = Modifier.weight(1f))
                }
            }
            if (issues.isNotEmpty()) {
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(if (keep) G.amberWash else G.errWash).padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        MIcon("alert", if (keep) G.amberInk else G.err, 18.dp, 2f)
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            issues.forEach { i -> Text(issueText(app, i, lang), style = ui(13.5f, 600, if (keep) G.amberInk else G.err, 1.35f)) }
                        }
                    }
                    if (keep) Text(tr("fz.kept"), style = ui(12.5f, 500, G.amberInk, 1.35f))
                }
                val heightOnly = issues.all { it.key == "fz.high" }
                // a distance from the corner that leaves no room for a cabinet comes back to where 300 mm still fit
                val fwl = on.firstOrNull()?.let(len)
                val fo = if (ward && offMm != null && fwl != null && offMm > fwl - 300 - uz.metrx.app.furniture.W_GAP_SIDE) (fwl - 300 - uz.metrx.app.furniture.W_GAP_SIDE).takeIf { it > 0 } else offMm
                val fitTry = fitTo(placed(f, on, room.id, room.floorId, fo, ws = ws), on, len, roomH, ws, fo)
                // fitting that changes nothing (a bed longer than the wall, a corner unit alone, too deep) is not offered
                val canFit = fitIssues(fitTry.copy(pose = null), on, len, roomH, ws, fo, start, deep) != fitIssues(f.copy(pose = null), on, len, roomH, ws, offMm, start, deep)
                if (!canFit) Text(tr(if (uz.metrx.app.furniture.canStandFree(f)) "fz.noFitFree" else "fz.noFit"), style = ui(12.5f, 500, G.ink2, 1.4f))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (canFit) GBtn(tr(if (heightOnly) "fz.fitH" else "fz.fit"), {
                        if (fo != offMm) off = fo?.toString() ?: ""
                        setFitted(fitTry); keep = false; app.say("fz.fitted")
                    }, Btn.SECONDARY, height = 46.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
                    GBtn(tr("fz.keep"), { keep = true }, if (keep) Btn.PRIMARY else Btn.SECONDARY, height = 46.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f), maxLines = 2)
                }
            }
        }
        if (!asked) WhereAsk(dn(f.name, lang), uz.metrx.app.furniture.bodyOf(g, pw, ws)?.let { uz.metrx.app.ui.rooms.mm(it.w.roundToInt()) + " × " + uz.metrx.app.ui.rooms.mm(it.d.roundToInt()) } ?: "", { app.pop() }) { wall ->
            asked = true
            val b0 = uz.metrx.app.furniture.bodyOf(g, pw, ws)
            val fr0 = uz.metrx.app.furniture.poseFrame(g, pw)
            if (b0 == null || fr0 == null) return@WhereAsk
            if (wall) {
                // the nearest wall to the room's middle with a free stretch, from its middle outwards
                val spot = uz.metrx.app.furniture.placeWall(room, pw, b0.w, b0.d, others, ws, snap) ?: return@WhereAsk
                if (spot.wall != first) first = spot.wall
                off = spot.t.toString(); setPose(null); reset()
                app.say("fp.pl.toWall", "n" to dn(f.name, lang), "w" to spot.wall, "a" to uz.metrx.app.ui.rooms.mm(spot.t))
            } else {
                val c = uz.metrx.app.geo.roomCen(room, snap)
                setPose(uz.metrx.app.furniture.poseAt(pw, pw.first { !it.inner }.id, b0, fr0, uz.metrx.app.furniture.PlanPt(c.x, c.y), 0.0))
                app.say("fp.pl.toMid", "n" to dn(f.name, lang))
            }
        }
    }
}

/** A fit issue in words, the piece's name in the app language. */
internal fun issueText(app: App, i: uz.metrx.app.furniture.FitIssue, lang: Lang): String =
    app.t(i.key, *i.vars.map { (k, v) -> k to (if (k == "n") dn(v.toString(), lang) else v) }.toTypedArray())

