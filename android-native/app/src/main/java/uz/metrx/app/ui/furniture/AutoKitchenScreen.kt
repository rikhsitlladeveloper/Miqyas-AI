package uz.metrx.app.ui.furniture

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.furniture.AK_LAYOUTS
import uz.metrx.app.furniture.AkApp
import uz.metrx.app.furniture.AkCheck
import uz.metrx.app.furniture.AkPlan
import uz.metrx.app.furniture.AkSite
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.akAll
import uz.metrx.app.furniture.akLayoutOf
import uz.metrx.app.furniture.akPieces
import uz.metrx.app.furniture.akSite
import uz.metrx.app.furniture.akStart
import uz.metrx.app.furniture.akUnits
import uz.metrx.app.furniture.akWallsFor
import uz.metrx.app.furniture.priceOf
import uz.metrx.app.geo.Role as Role3
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.furniture3D
import uz.metrx.app.ui.App
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.Sheet
import uz.metrx.app.ui.components.Btn
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.num
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.three.CARD_BG
import uz.metrx.app.ui.three.Card3D
import uz.metrx.app.ui.three.CardCam
import uz.metrx.app.ui.three.Lru
import uz.metrx.app.ui.three.Quality3D
import uz.metrx.app.ui.three.Tier
import uz.metrx.app.ui.three.cardFrame
import uz.metrx.app.ui.three.cardSize
import uz.metrx.app.ui.three.digest
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/*
 * "Oshxona yasash", the auto kitchen (Joylan ideas, founder 26 Oct 2026; the approved mockup scratchpad
 * joylan-ideas/mockup.html, screen 1): in a measured room, pick the walls on its plan (their number gives the layout,
 * a wall with a door takes none), the layout, the appliances; then the six design styles, each a kitchen built for
 * this room by furniture/AutoKitchen.kt with its picture from the real 3D, its units and metres, its price (Advanced),
 * its checks and why it is built so. "Tanlash" puts it in the room; "Ortga qaytarish" takes it back.
 */

private val JSONK = Json { encodeDefaults = false }

/** The picked appliances as one saveable line: "fs,hob,1,built". */
private fun appOf(s: String): AkApp = s.split(',').let { AkApp(it.getOrElse(0) { "fs" }, it.getOrElse(1) { "hob" }, it.getOrElse(2) { "1" } == "1", it.getOrElse(3) { "built" }) }
private fun appStr(a: AkApp) = "${a.fridge},${a.oven},${if (a.dw) 1 else 0},${a.hood}"

/** A check's line in the app language: metres to 0,1, a strings key's name, the numbers as they are. */
@Composable
internal fun akText(c: AkCheck): String {
    val en = LocalLang.current == Lang.EN
    val v = HashMap<String, Any?>()
    c.vars.forEach { (k, x) ->
        when (k) {
            "m" -> { val d = ((x as Int) + 50) / 100; v["v"] = "${d / 10}${if (en) "." else ","}${d % 10}" }
            "mm" -> v["v"] = x
            "o" -> v["o"] = tr(x as String)
            else -> v[k] = x
        }
    }
    return tr(c.key, *v.toList().toTypedArray())
}

/** The pieces a plan gives, named as the order's next kitchens. */
private fun App.akNames(p: Project, n: Int): List<String> {
    val k = p.furniture.count { it.kind == "kitchen" && it.type.isEmpty() }
    return (1..n).map { t("kt.nameN", "n" to k + it) }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AutoKitchenScreen(rt: Route.AutoKitchen) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val ctx = LocalContext.current
    val p = app.store.get(rt.pid) ?: return
    val room = p.rooms.firstOrNull { it.id == rt.rid } ?: return
    val s = app.settings
    val snap = s.angleSnap
    val ws = s.workshop; val mats = s.mats
    val site = remember(room.dims, room.openings, room.points, room.poly, snap) { akSite(room, { wallLen(room, snap, it) }, snap) }
    val old = rt.fid?.let { id -> p.furniture.firstOrNull { it.id == id } }
    var wallsS by rememberSaveable(rt) {
        mutableStateOf((old?.walls?.filter { site.has(it) && it in site.free }?.takeIf { it.isNotEmpty() && akLayoutOf(site, it) != null } ?: akStart(site)).joinToString(","))
    }
    val walls = wallsS.split(',').filter { it.isNotEmpty() && site.has(it) }
    val layout = akLayoutOf(site, walls) ?: "line"
    var appS by rememberSaveable(rt) { mutableStateOf(appStr(AkApp())) }
    val akApp = appOf(appS)
    // the plan shows the style of the kitchen being replaced, else the order's style, else the first
    var focus by rememberSaveable(rt) { mutableStateOf(listOfNotNull(old?.look?.preset, p.fstyle).firstOrNull { uz.metrx.app.furniture.designPreset(it) != null } ?: "twotone") }
    // what this visit put in the room: the preset and the pieces' ids (to replace them when another style is chosen)
    var placed by rememberSaveable(rt) { mutableStateOf("") }
    var placedIds by rememberSaveable(rt) { mutableStateOf(rt.fid ?: "") }
    val plans = remember(site, wallsS, layout, appS, ws) { if (walls.isEmpty()) emptyList() else akAll(site, walls, layout, akApp, ws) }
    // the six kitchens as pieces (ids fixed for the pictures, the real ids made on Tanlash)
    val pieces = remember(plans, mats) { plans.associate { (id, pl) -> id to (pl?.let { akPieces(it, site, ws, listOf("K", "K2")) } ?: emptyList()) } }
    val tier = remember(s.quality) { Quality3D.tier(ctx, s.quality) }

    fun tapWall(w: String) {
        if (w !in site.free) { app.say("ak.doorWall", kind = ToastKind.INFO); return }
        var ws2 = if (w in walls) walls - w else walls + w
        if (ws2.isEmpty()) { app.say("ak.oneWall", kind = ToastKind.INFO); return }
        if (ws2.size > 3) ws2 = ws2.takeLast(3)
        if (akLayoutOf(site, ws2) == null) { app.say("ak.noChain", kind = ToastKind.INFO); return }
        wallsS = ws2.joinToString(",")
    }

    fun choose(id: String) {
        val pl = plans.firstOrNull { it.first == id }?.second ?: return
        if (!app.once()) return
        if (placed == id) { openPlaced(app, p.id, placedIds); return }
        val now = System.currentTimeMillis()
        val before = app.store.get(p.id)?.furniture ?: return
        val prevPlaced = placed; val prevIds = placedIds
        val replace = prevIds.split(',').filter { it.isNotEmpty() }
        var made = akPieces(pl, site, ws, app.akNames(p.copy(furniture = before.filter { it.id !in replace }), if (pl.layout == "two") 2 else 1), now)
        // from the designer, or chosen again: the first piece keeps the replaced kitchen's id and name
        before.firstOrNull { it.id == replace.firstOrNull() }?.let { o -> made = listOf(made[0].copy(id = o.id, name = o.name, created = o.created)) + made.drop(1) }
        val at = before.indexOfFirst { it.id in replace }.takeIf { it >= 0 }
        app.store.update(p.id) { pr ->
            val keep = pr.furniture.filter { it.id !in replace }
            val list = if (at != null) keep.toMutableList().also { it.addAll(at.coerceIn(0, it.size), made) } else keep + made
            pr.copy(furniture = list, stage = if (pr.stage == "measure") "design" else pr.stage, want = ((pr.want ?: emptyList()) + "kitchen").distinct())
        }
        app.renameOrder(p.id)
        replace.forEach { app.kit.forget(it) }
        placed = id; placedIds = made.joinToString(",") { it.id }
        // UX upgrades §3: the toast and the bottom bar's Undo both take the kitchen back out
        app.act(app.t("ak.placedT", "n" to tr0(app, "lk.p.$id")), {
            app.store.update(p.id) { pr -> pr.copy(furniture = before) }
            made.forEach { app.kit.forget(it.id) }
            placed = prevPlaced; placedIds = prevIds
            app.say(if (prevPlaced.isEmpty()) "ak.undone" else "ak.back")
        })
    }

    // UX upgrades: the order's header (Back, the name never cut, the progress) and the bottom action bar with Undo
    Column(Modifier.fillMaxSize()) {
        val rn = p.floors.firstOrNull { it.id == room.floorId }?.let { floorName(it, lang) } ?: dn(room.name, lang)
        uz.metrx.app.ui.ux.UxTop(tr("ak.title"), { app.pop() }, eyebrow = dn(p.name, lang) + " · " + tr("ak.sub", "r" to rn,
            "a" to uz.metrx.app.geo.fmtLen(room.dim("A").v, uz.metrx.app.geo.LenUnit.M, en), "b" to uz.metrx.app.geo.fmtLen(room.dim("B").v, uz.metrx.app.geo.LenUnit.M, en)),
            sample = p.sample) { uz.metrx.app.ui.ux.ProgressRow(p, compact = true) }
        if (site.walls.size < 3) Text(tr("ak.needRoom"), style = ui(15f, 500, G.ink2, 1.45f), modifier = Modifier.weight(1f).padding(24.dp))
        else Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // what this visit placed: open it, or its prices and the client's file
            // a kitchen already in the room (the designer's): the chosen one takes its place
            if (placed.isEmpty() && rt.fid != null) Text(tr("ak.replace"), style = ui(12.5f, 500, G.amberInk, 1.4f),
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(G.amberWash).padding(12.dp))
            if (placed.isNotEmpty()) PlacedCard(p, placed, placedIds, plans.firstOrNull { it.first == placed }?.second)
            // 1. the walls
            Step(1, tr("ak.s1"), tr("ak.wallsMeta", "l" to tr("ak.l.$layout"), "n" to walls.size)) {
                val fp = plans.firstOrNull { it.first == (placed.ifEmpty { focus }) }?.second
                PlanView(site, walls, fp, Modifier.fillMaxWidth().aspectRatio(1.15f)) { tapWall(it) }
                Legend()
                Text(tr("ak.s1hint"), style = ui(12.5f, 400, G.ink2, 1.4f))
                if (fp != null) Text(tr("ak.onPlan", "n" to tr("lk.p.${fp.preset}"), "u" to akUnits(pieces[fp.preset] ?: emptyList())), style = ui(12.5f, 600, G.ink2))
            }
            // 2. the layout
            Step(2, tr("ak.s2"), null) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AK_LAYOUTS.forEach { k ->
                        val can = akWallsFor(site, k, walls) != null
                        Box(Modifier.let { if (can) it else it.background(Color.Transparent) }) {
                            Chip(tr("ak.l.$k") + if (can) "" else " ·", k == layout) {
                                if (k == layout) return@Chip
                                val w2 = akWallsFor(site, k, walls)
                                if (w2 == null) app.say("ak.noLayout", kind = ToastKind.INFO) else wallsS = w2.joinToString(",")
                            }
                        }
                    }
                }
            }
            // 3. the appliances
            Step(3, tr("ak.s3"), null) {
                AppRow(tr("ak.a.fridge"), listOf("bi" to tr("ak.a.fridge.bi"), "fs" to tr("ak.a.fridge.fs")), akApp.fridge) { appS = appStr(akApp.copy(fridge = it)) }
                AppRow(tr("ak.a.oven"), listOf("hob" to tr("ak.a.oven.hob"), "tall" to tr("ak.a.oven.tall")), akApp.oven) { appS = appStr(akApp.copy(oven = it)) }
                AppRow(tr("ak.a.dw"), listOf("1" to tr("ak.a.dw.on"), "0" to tr("ak.a.dw.off")), if (akApp.dw) "1" else "0") { appS = appStr(akApp.copy(dw = it == "1")) }
                AppRow(tr("ak.a.hood"), listOf("built" to tr("ak.a.hood.built"), "angled" to tr("ak.a.hood.angled")), akApp.hood) { appS = appStr(akApp.copy(hood = it)) }
            }
            // 4. the six styles
            Row(Modifier.padding(top = 6.dp, start = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Num(4); Text(tr("ak.s4"), style = ui(17f, 800), modifier = Modifier.weight(1f))
                if (s.advanced) Text(tr("ak.priceAdv"), style = ui(12f, 600, G.ink2))
            }
            Text(tr("ak.s4hint"), style = ui(12.5f, 400, G.ink2, 1.4f))
            plans.forEach { (id, pl) ->
                StyleCard(p, room, id, pl, pieces[id] ?: emptyList(), placed == id, tier, onFocus = { focus = id }) { choose(id) }
            }
        }
        // the next step: once a style is in the room, its design; before, the style looked at goes in
        val canPick = plans.any { it.first == focus && it.second != null }
        uz.metrx.app.ui.ux.UxBar(if (placed.isNotEmpty()) tr("ak.open3d") else tr("ux.ak.pick", "n" to tr("lk.p.$focus")), if (placed.isNotEmpty()) "cube" else "check",
            { if (placed.isNotEmpty()) openPlaced(app, p.id, placedIds) else choose(focus) }, onUndo = { app.undoLast() }, canUndo = app.undos.isNotEmpty(),
            mainEnabled = placed.isNotEmpty() || canPick)
    }
}

/** A string in the app language outside a composable. */
private fun tr0(app: App, k: String) = app.t(k)

/** Opens what this visit placed: the kitchen designer's 3D. */
private fun openPlaced(app: App, pid: String, ids: String) {
    val id = ids.split(',').firstOrNull { it.isNotEmpty() } ?: return
    app.kit.sel = null
    app.push(Route.Kitchen(pid, id, d3 = true))
}

@Composable
private fun Num(n: Int) {
    Box(Modifier.size(26.dp).clip(CircleShape).background(G.cobalt), contentAlignment = Alignment.Center) { Text("$n", style = ui(13f, 800, Color.White)) }
}

@Composable
private fun Step(n: Int, title: String, meta: String?, body: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().glassCard(RoundedCornerShape(22.dp), fill = G.glass(.6f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Num(n); Text(title, style = ui(16f, 800), modifier = Modifier.weight(1f))
            if (meta != null) Text(meta, style = ui(12.5f, 600, G.ink2), maxLines = 1)
        }
        body()
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AppRow(label: String, opts: List<Pair<String, String>>, cur: String, onPick: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, style = ui(13f, 600, G.ink2))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            opts.forEach { (k, l) -> Chip(l, k == cur) { if (k != cur) onPick(k) } }
        }
    }
}

/* ---------------- the room's plan ---------------- */

private val C_SINK = Color(0xFF4F8FE8)
private val C_HOB = Color(0xFFF08A3C)
private val C_FRIDGE = Color(0xFF2BB3A3)
private val C_TALL = Color(0xFF7C8DB5)
private val C_DW = Color(0xFF9B6DDB)
private val C_UNIT = Color(0xFFDCE2EC)
private val C_WATER = Color(0xFF2F80ED)
private val C_GAS = Color(0xFFE5A50A)

private fun colourOf(k: String): Color = when (k) {
    "sink" -> C_SINK; "hob", "hobOven" -> C_HOB; "fridgeFS", "fridgeBI" -> C_FRIDGE; "ovenT", "pantry" -> C_TALL; "dw" -> C_DW; else -> C_UNIT
}

@Composable
private fun Legend() {
    @OptIn(ExperimentalLayoutApi::class)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        listOf(C_SINK to "ak.leg.sink", C_HOB to "ak.leg.hob", C_FRIDGE to "ak.leg.fridge", C_TALL to "ak.leg.tall", C_DW to "ak.leg.dw").forEach { (c, k) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Box(Modifier.size(10.dp).clip(RoundedCornerShape(3.dp)).background(c)); Text(tr(k), style = ui(11.5f, 600, G.ink2))
            }
        }
    }
}

/**
 * The room from above: its walls (the picked ones blue, a wall with a door grey), windows, doors, the water and the
 * gas, and the units of the plan [plan]; a tap on a wall picks it or leaves it.
 */
@Composable
private fun PlanView(site: AkSite, walls: List<String>, plan: AkPlan?, modifier: Modifier, onWall: (String) -> Unit) {
    val tm = rememberTextMeasurer()
    val wLabel = tr("ak.water"); val gLabel = tr("ak.gas")
    val stOn = ui(11f, 800, G.cobalt); val stOff = ui(11f, 800, G.ink3); val stW = ui(10.5f, 800, C_WATER); val stG = ui(10.5f, 800, C_GAS)
    val xs = site.walls.flatMap { w -> listOf(w.x0, w.pt(w.len.toDouble())[0]) }; val ys = site.walls.flatMap { w -> listOf(w.y0, w.pt(w.len.toDouble())[1]) }
    val bx0 = xs.min(); val bx1 = xs.max(); val by0 = ys.min(); val by1 = ys.max()
    var frame by remember { mutableStateOf(floatArrayOf(1f, 0f, 0f)) }   // scale, x0, y0 (px per mm, offset)
    Canvas(modifier.clip(RoundedCornerShape(16.dp)).background(Color(0xFFF4F6FA)).semantics { contentDescription = "plan" }.pointerInput(site, walls) {
        detectTapGestures { o ->
            val (k, ox, oy) = frame.let { Triple(it[0], it[1], it[2]) }
            val mx = (o.x - ox) / k; val my = (o.y - oy) / k
            val hit = site.walls.minByOrNull { w -> segDist(mx.toDouble(), my.toDouble(), w) }
            if (hit != null && segDist(mx.toDouble(), my.toDouble(), hit) < 700) onWall(hit.id)
        }
    }) {
        val pad = 34.dp.toPx()
        val k = min((size.width - 2 * pad) / (bx1 - bx0).toFloat(), (size.height - 2 * pad) / (by1 - by0).toFloat())
        val ox = (size.width - (bx1 - bx0).toFloat() * k) / 2 - bx0.toFloat() * k
        val oy = (size.height - (by1 - by0).toFloat() * k) / 2 - by0.toFloat() * k
        if (frame[0] != k || frame[1] != ox || frame[2] != oy) frame = floatArrayOf(k, ox, oy)
        fun P(q: DoubleArray) = Offset(ox + q[0].toFloat() * k, oy + q[1].toFloat() * k)
        // the floor
        val floor = Path().apply { site.walls.forEachIndexed { i, w -> val q = P(doubleArrayOf(w.x0, w.y0)); if (i == 0) moveTo(q.x, q.y) else lineTo(q.x, q.y) }; close() }
        drawPath(floor, Color.White)
        // the units
        plan?.runs?.forEach { r ->
            val w = site.wall(r.wall)
            r.low.forEach { sp ->
                if (sp.k == "cornerS" || sp.k == "filler") return@forEach
                val a = sp.a.toDouble(); val b = sp.b.toDouble()
                val path = Path().apply { listOf(w.pt(a, 0.0), w.pt(b, 0.0), w.pt(b, 600.0), w.pt(a, 600.0)).forEachIndexed { i, q -> val o = P(q); if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) }; close() }
                drawPath(path, colourOf(sp.k).copy(alpha = if (colourOf(sp.k) == C_UNIT) 1f else .85f))
                drawPath(path, Color(0xFF9AA8BF), style = Stroke(1.dp.toPx()))
                if (sp.k == "sink") { val c = P(w.pt((a + b) / 2, 300.0)); drawCircle(Color.White.copy(alpha = .8f), 140f * k, c) }
                if (sp.k == "hob" || sp.k == "hobOven") listOf(-150.0 to 150.0, 150.0 to 150.0, -150.0 to 430.0, 150.0 to 430.0).forEach { (dx, dn) -> drawCircle(Color.White.copy(alpha = .85f), 70f * k, P(w.pt((a + b) / 2 + dx, dn)), style = Stroke(1.5.dp.toPx())) }
            }
        }
        // the walls: picked blue, with a door grey, the rest ink
        site.walls.forEach { w ->
            val col = when { w.id in walls -> G.cobalt; w.id !in site.free -> Color(0xFFB8C0CC); else -> Color(0xFF3E4A61) }
            drawLine(col, P(w.pt(0.0, -60.0)), P(w.pt(w.len.toDouble(), -60.0)), if (w.id in walls) 7.dp.toPx() else 5.dp.toPx(), StrokeCap.Square)
            val lab = tm.measure(w.id, if (w.id in walls) stOn else stOff)
            val c = P(w.pt(w.len / 2.0, -330.0))
            drawText(lab, topLeft = Offset(c.x - lab.size.width / 2, c.y - lab.size.height / 2))
        }
        site.windows.forEach { o -> val w = site.wall(o.wall); drawLine(Color(0xFF7CC4F0), P(w.pt(o.a.toDouble(), -60.0)), P(w.pt(o.b.toDouble(), -60.0)), 4.dp.toPx()) }
        site.doors.forEach { o ->
            val w = site.wall(o.wall)
            drawLine(Color(0xFFF4F6FA), P(w.pt(o.a.toDouble(), -60.0)), P(w.pt(o.b.toDouble(), -60.0)), 6.dp.toPx())
            drawLine(Color(0xFF3E4A61), P(w.pt(o.b.toDouble(), 0.0)), P(w.pt(o.b.toDouble(), (o.b - o.a).toDouble())), 1.5.dp.toPx())
            arcPath(this, w, o.a.toDouble(), o.b.toDouble(), ::P)
        }
        fun dot(q: DoubleArray, c: Color, label: String) {
            val o = P(q); drawCircle(Color.White, 7.dp.toPx(), o); drawCircle(c, 5.dp.toPx(), o)
            val t = tm.measure(label, if (c == C_WATER) stW else stG); drawText(t, topLeft = Offset(o.x + 8.dp.toPx(), o.y - t.size.height - 2.dp.toPx()))
        }
        site.water?.let { dot(site.pt(it), C_WATER, wLabel) }
        site.gas?.let { dot(site.pt(it), C_GAS, gLabel) }
    }
}

/** A door's swing on the plan, a quarter circle from its far edge. */
private fun arcPath(d: DrawScope, w: uz.metrx.app.furniture.AkWall, a: Double, b: Double, P: (DoubleArray) -> Offset) {
    val r = b - a
    val path = Path()
    for (i in 0..16) {
        val t = Math.PI / 2 * i / 16
        val q = P(w.pt(b - r * kotlin.math.cos(t), r * kotlin.math.sin(t)))
        if (i == 0) path.moveTo(q.x, q.y) else path.lineTo(q.x, q.y)
    }
    d.drawPath(path, Color(0xFF9AA8BF), style = Stroke(1.2f * d.density))
}

/** How far plan point [x], [y] is from wall [w]'s line between its ends, mm. */
private fun segDist(x: Double, y: Double, w: uz.metrx.app.furniture.AkWall): Double {
    val dx = x - w.x0; val dy = y - w.y0
    val t = (dx * w.ux + dy * w.uy).coerceIn(0.0, w.len.toDouble())
    val px = w.x0 + w.ux * t; val py = w.y0 + w.uy * t
    return hypot(x - px, y - py)
}

/* ---------------- the style cards ---------------- */

@Composable
private fun StyleCard(p: Project, room: Room, id: String, plan: AkPlan?, fs: List<Furniture>, on: Boolean, tier: Tier, onFocus: () -> Unit, onChoose: () -> Unit) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val s = app.settings
    val shape = RoundedCornerShape(22.dp)
    var why by rememberSaveable(id) { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().glassCard(shape, fill = G.glass(.62f)).let { if (on) it.border(2.dp, G.cobalt, shape) else it }.padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.fillMaxWidth().aspectRatio(4f / 3f).clip(RoundedCornerShape(16.dp)).background(Color(0xFF000000.toInt() or CARD_BG)).clickable(role = Role.Button, onClick = onFocus)) {
            if (plan != null) AkPic(room, fs, Modifier.fillMaxSize(), tier)
        }
        Column(Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(tr("lk.p.$id"), style = ui(16f, 800), modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (on) Text(tr("ak.on"), style = ui(11.5f, 800, Color.White), modifier = Modifier.clip(RoundedCornerShape(99.dp)).background(G.cobalt).padding(horizontal = 8.dp, vertical = 2.dp))
            }
            Text(tr("lk.p.$id.d"), style = ui(12.5f, 400, G.ink2, 1.35f))
            if (plan == null) {
                Text(tr("ak.noFit"), style = ui(13f, 600, G.amberInk, 1.4f))
                return@Column
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val pm = (plan.runMm + 50) / 100
                Text(tr("ak.meta", "n" to akUnits(fs), "m" to "${pm / 10}${if (en) "." else ","}${pm % 10}"), style = num(13f, 600, G.ink2), modifier = Modifier.weight(1f))
                if (s.advanced) {
                    val price by produceState<java.math.BigInteger?>(null, fs, s.workshop, s.mats, s.hws, p.fprice) {
                        value = null
                        value = withContext(Dispatchers.Default) { runCatching { priceOf(fs, p.fprice, s.workshop, s.mats, s.hws).lines.filter { l -> fs.any { it.id == l.key } }.fold(java.math.BigInteger.ZERO) { a, l -> a + l.amount } }.getOrNull() }
                    }
                    price?.let { v ->
                        val (t, u) = uz.metrx.app.core.shortMoney(p, v, en, tr("pl.mln"))
                        Text(tr("ak.price", "v" to t + (u?.let { " $it" } ?: "")), style = num(14f, 800))
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.size(9.dp).clip(CircleShape).background(if (plan.err > 0) G.err else if (plan.warn > 0) G.amberInk else G.green))
                Text(tr("ak.errWarn", "e" to plan.err, "w" to plan.warn), style = ui(12.5f, 600, G.ink2))
            }
            Text((if (why) "▾ " else "▸ ") + tr("ak.why"), style = ui(13.5f, 700, G.cobalt2),
                modifier = Modifier.fillMaxWidth().heightIn(min = 40.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { why = !why; if (why) onFocus() }.padding(vertical = 10.dp))
            if (why) {
                Text(tr("ak.lead") + if (plan.noPantry) " " + tr("ak.leadNoP") else "", style = ui(12.5f, 400, G.ink2, 1.4f))
                plan.checks.forEach { c ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
                        val col = when (c.level) { "err" -> G.err; "warn" -> G.amberInk; else -> G.green }
                        Text(when (c.level) { "err" -> "✕"; "warn" -> "!"; else -> "✓" }, style = ui(12.5f, 800, col), modifier = Modifier.width(14.dp))
                        Text(akText(c), style = ui(12.5f, 400, G.ink, 1.35f), modifier = Modifier.weight(1f))
                    }
                }
            }
        }
        GBtn(if (on) tr("ak.placed") else tr("ak.pick"), onChoose, if (on) Btn.SECONDARY else Btn.PRIMARY, icon = if (on) "cube" else "check", height = 48.dp, corner = 16.dp, fontSize = 15f)
    }
}

/** What this visit put in the room: the style, its units, checks; open it in 3D, its three prices, the client's file. */
@Composable
private fun PlacedCard(p: Project, id: String, ids: String, plan: AkPlan?) {
    val app = LocalApp.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(G.cobalt.copy(alpha = .1f)).border(1.dp, G.cobalt.copy(alpha = .35f), RoundedCornerShape(22.dp)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MIcon("check", G.cobalt2, 20.dp, 2.4f)
            Text(tr("ak.placedT", "n" to tr("lk.p.$id")), style = ui(15f, 800, G.cobalt2), modifier = Modifier.weight(1f))
        }
        if (plan != null) Text(tr("ak.errWarn", "e" to plan.err, "w" to plan.warn), style = ui(12.5f, 600, G.ink2))
        GBtn(tr("ak.open3d"), { openPlaced(app, p.id, ids) }, icon = "cube", height = 48.dp, corner = 16.dp, fontSize = 15f)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (app.settings.advanced) GBtn(tr("ak.tiers"), { app.popTo { it is Route.Project && it.id == p.id }; app.setProjectTab("price") }, Btn.SECONDARY, icon = "coin",
                height = 46.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
            GBtn(tr("ak.share"), { app.sheet = Sheet.Share3D(p.id, ids.split(',').firstOrNull()) }, Btn.SECONDARY, icon = "share",
                height = 46.dp, corner = 14.dp, fontSize = 14f, modifier = Modifier.weight(1f))
        }
    }
}

/* ---------------- the cards' pictures: the real 3D of each kitchen in its room ---------------- */

private object AkCards {
    val mem = Lru<String, ImageBitmap>(minOf(32L shl 20, Runtime.getRuntime().maxMemory() / 10)) { it.width.toLong() * it.height * 4 }
    val failed = HashSet<String>()
    val lock = Mutex()
}

/** The room's lit scene with [fs] in it: its floor and the walls they stand on, as a card shows them, and the camera. */
internal fun roomCard(room: Room, fs: List<Furniture>, ws: Workshop, mats: List<Mat>, snap: Boolean, w: Int, h: Int, light: Boolean): Pair<Shell3D, CardCam> {
    val b = buildShell(listOf(room), true, snap)
    val fur = furniture3D(fs, b.bases, ws, matRgb(mats), emptySet(), look = matLook(mats), mats = mats, light = light, ceil = room.dim("H").v)
    val on = fs.flatMap { it.walls }.toSet()
    val keep = b.parts.filter { it.role == Role3.FLOOR || (it.role != Role3.FURN && it.wall in on) }
    val shell = Shell3D(keep, emptyList(), b.groups, emptyList(), null, b.L, b.W, b.H, b.tgt, b.r, b.theta, b.phi, b.bounds, b.rMin, b.fit,
        b.gridSize, b.gridDiv, b.gridCx, b.gridCz, b.light, b.far, b.bases).plus(fur.parts, fur.edges)
    var x0 = Double.MAX_VALUE; var y0 = Double.MAX_VALUE; var z0 = Double.MAX_VALUE; var x1 = -Double.MAX_VALUE; var y1 = -Double.MAX_VALUE; var z1 = -Double.MAX_VALUE
    fur.parts.forEach { pt -> pt.faces.forEach { f -> f.pts.forEach { q -> x0 = min(x0, q.x); y0 = min(y0, q.y); z0 = min(z0, q.z); x1 = max(x1, q.x); y1 = max(y1, q.y); z1 = max(z1, q.z) } } }
    if (x0 > x1) { x0 = 0.0; y0 = 0.0; z0 = 0.0; x1 = 1.0; y1 = 1.0; z1 = 1.0 }
    val ext = listOf(x0, x1).flatMap { x -> listOf(y0, y1).flatMap { y -> listOf(V3(x, y, z0), V3(x, y, z1)) } }
    // from inside the room, facing the walls the kitchen is on (a one-wall kitchen a little from the side)
    var nx = 0.0; var nz = 0.0
    on.forEach { id -> b.bases[id]?.let { nx += it.nx; nz += it.nz } }
    if (hypot(nx, nz) < .1) { nx = 0.0; nz = 1.0 }
    val az = atan2(nx, nz) + if (on.size == 1) .38 else 0.0
    val fr = cardFrame(ext, ext, az, CARD_EL, w.toDouble() / h, CARD_HALF)
    return shell to CardCam(fr.eye, fr.at, 2 * CARD_HALF * 180 / Math.PI)
}

/** A kitchen's picture in its room from the real 3D (kept in memory by everything it depends on); its plan if the 3D gives none. */
@Composable
private fun AkPic(room: Room, fs: List<Furniture>, modifier: Modifier, tier: Tier) {
    val app = LocalApp.current
    val ctx = LocalContext.current
    val ws = app.settings.workshop; val mats = app.settings.mats; val snap = app.settings.angleSnap
    val key = remember(room, fs, mats, ws, tier) {
        digest(JSONK.encodeToString(kotlinx.serialization.builtins.ListSerializer(Furniture.serializer()), fs.map { it.copy(id = "", modules = it.modules.mapIndexed { i, m -> m.copy(id = "$i") }) }) +
            "|" + room.dims + room.openings + room.poly + "|" + matsLine(mats, ws) + "|" + tier)
    }
    val img by produceState(AkCards.mem[key], key) {
        // another kitchen (other walls or appliances): its own picture, never the one before
        value = AkCards.mem[key]
        if (value != null || key in AkCards.failed) return@produceState
        value = akRender(ctx, room, fs, ws, mats, snap, tier).also { if (it != null) AkCards.mem.put(key, it) else AkCards.failed += key }
    }
    Box(modifier) {
        val i = img
        when {
            i != null -> Image(i, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            key in AkCards.failed -> Box(Modifier.fillMaxSize().background(Color(0xFFF4F6FA)), contentAlignment = Alignment.Center) { MIcon("kitchen", G.ink3, 36.dp, 2f) }
            else -> Shimmer(Modifier.fillMaxSize())
        }
    }
}

private suspend fun akRender(ctx: Context, room: Room, fs: List<Furniture>, ws: Workshop, mats: List<Mat>, snap: Boolean, tier: Tier): ImageBitmap? = AkCards.lock.withLock {
    runCatching {
        val (w, h) = cardSize(tier)
        val (shell, cam) = withContext(Dispatchers.Default) { roomCard(room, fs, ws, mats, snap, w, h, tier == Tier.LOW) }
        Card3D.render(ctx, shell, cam, w, h, tier)?.asImageBitmap()
    }.getOrNull()
}
