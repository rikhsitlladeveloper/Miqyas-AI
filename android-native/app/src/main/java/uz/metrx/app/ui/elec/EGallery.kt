package uz.metrx.app.ui.elec

import androidx.activity.compose.BackHandler
import uz.metrx.app.ui.components.switchState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
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
import androidx.compose.runtime.mutableFloatStateOf
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.Workspace
import uz.metrx.app.data.dn
import uz.metrx.app.data.floorName
import uz.metrx.app.data.uid
import uz.metrx.app.elec.ECtx
import uz.metrx.app.elec.ElecCalc
import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecOrder
import uz.metrx.app.elec.ElecRoom
import uz.metrx.app.elec.KINDS
import uz.metrx.app.elec.KITS
import uz.metrx.app.elec.Kit
import uz.metrx.app.elec.KitOpts
import uz.metrx.app.elec.calcOf
import uz.metrx.app.elec.ctxOf
import uz.metrx.app.elec.defaultOpts
import uz.metrx.app.elec.devSize
import uz.metrx.app.elec.devType
import uz.metrx.app.elec.freeOf
import uz.metrx.app.elec.kitOf
import uz.metrx.app.elec.placeKit
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.ready3D
import uz.metrx.app.tiles.V2
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
import uz.metrx.app.ui.furniture.measuredRoom
import uz.metrx.app.ui.furniture.openRoom
import uz.metrx.app.ui.furniture.parseMm
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.icons.MIcon
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.tiles.TCam
import kotlin.math.cos
import kotlin.math.sin

/*
 * Choosing a room kit (22 Oct 2026): the gallery of kits grouped by room, each card drawn by the app from the kit put in
 * a sample room; then a few questions (the main light, the extras, which room), the kit shown in the sample room all
 * along.
 */

/** The sample room a kit of [kind] is shown in: the door on wall D near the eye, the sink's water on wall A for a kitchen or bathroom. */
private fun sampleRoom(kind: String): Room {
    val (L, W, H) = when (kind) { "bath" -> Triple(2600, 2200, 2600); "hall" -> Triple(3800, 1800, 2700); else -> Triple(4200, 3400, 2700) }
    val ops = buildList {
        add(Opening("d", "door", "D", 800, 2100, 250))
        if (kind == "hall") add(Opening("d2", "door", "B", 800, 2100, 500))
        if (kind == "office") add(Opening("w", "window", "A", 1400, 1400, L - 1900, 900)) else if (kind != "bath" && kind != "hall") add(Opening("w", "window", "C", 1400, 1400, 1400, 900))
    }
    val pts = when (kind) { "kitchen" -> listOf(SitePoint("c", "cold", "A", (L * .38).toInt(), 550)); "bath" -> listOf(SitePoint("c", "cold", "A", 700, 600)); else -> emptyList() }
    return Room("sample", "sw", "", dims = mapOf("A" to Dim(L), "B" to Dim(W), "H" to Dim(H), "T" to Dim(120, "default")), openings = ops, points = pts)
}

/** A kit in its sample room: the room, its devices placed, their circuits and routes from the door. */
class KPreview(val c: ECtx, val devs: List<ElecDev>, val calc: ElecCalc)

fun kitPreview(k: Kit, o: KitOpts): KPreview? {
    val r = sampleRoom(k.kind)
    val p0 = Project("sample", "", floors = listOf(Workspace("sw", "", if (k.kind == "kitchen") "kitchen" else if (k.kind == "bath") "bath" else "room")), rooms = listOf(r),
        industry = "elec", elec = ElecOrder(rooms = listOf(ElecRoom("sample", k.kind))))
    val c = ctxOf(p0, "sample", true) ?: return null
    var n = 0
    val ds = placeKit(k, c, emptyList(), { "s${n++}" }, o)
    val p = p0.copy(elec = p0.elec.copy(devs = ds))
    return KPreview(ctxOf(p, "sample", true)!!, ds, calcOf(p, true))
}

private const val P_WALL = 0xEEF1F5
private const val P_FLOOR = 0xE2E6EC

/** Draws the kit in its sample room's far corner, seen from inside the room; [az] turns the view a little. */
fun DrawScope.drawKitPreview(pv: KPreview, az: Float = 0f) {
    drawRect(Color(0xFFF6F8FC))
    val c = pv.c; val g = c.g
    val L = g.walls[0].len / 1000; val W = g.walls[1].len / 1000; val H = g.H / 1000
    val a = .78 + az
    val tgt = V3(L * .3, H * .45, W * .3)
    val dist = kotlin.math.hypot(L, W) * .78
    val eye = V3(tgt.x + dist * cos(a), H * .62, tgt.z + dist * sin(a))
    val cam = TCam(eye, tgt, size.width, size.height, .58)
    fun sc(q: V2, z: Double) = V3(q.x / 1000, z / 1000, q.y / 1000)
    fun quad(pts: List<V3>, col: Color, stroke: Color? = null) {
        val o = pts.map { cam.p(it) ?: return }
        val path = Path().apply { moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        drawPath(path, col); if (stroke != null) drawPath(path, stroke, style = Stroke(1f))
    }
    quad(g.floor.map { sc(it, g.H) }, rgbC(0xF8FAFC))
    quad(g.floor.map { sc(it, 0.0) }, rgbC(P_FLOOR))
    listOf("A", "D").forEach { id ->
        val w = g.wall(id) ?: return@forEach
        quad(listOf(sc(w.at(0.0), 0.0), sc(w.at(w.len), 0.0), sc(w.at(w.len), g.H), sc(w.at(0.0), g.H)), rgbC(if (id == "A") P_WALL else 0xE6EAF0))
        c.room.openings.filter { it.wall == id }.forEach { o ->
            val pts = listOf(sc(w.at(o.off.toDouble(), 2.0), o.sill.toDouble()), sc(w.at((o.off + o.w).toDouble(), 2.0), o.sill.toDouble()),
                sc(w.at((o.off + o.w).toDouble(), 2.0), (o.sill + o.h).toDouble()), sc(w.at(o.off.toDouble(), 2.0), (o.sill + o.h).toDouble()))
            quad(pts, if (o.type == "door") Color(0xFFD9DEE6) else Color(0xFFCFE0F7), Color(0xFF9AA8BF))
        }
        c.room.points.filter { it.wall == id }.forEach { x ->
            cam.p(sc(w.at(x.off.toDouble(), 3.0), x.h.toDouble()))?.let { drawCircle(Color(0xFF2563EB), 3.5f * density, it) }
        }
    }
    // the corner's line
    g.wall("A")?.let { w -> val p0 = cam.p(sc(w.at(0.0), 0.0)); val p1 = cam.p(sc(w.at(0.0), g.H)); if (p0 != null && p1 != null) drawLine(Color(0x33101828), p0, p1, density) }
    val vis = setOf("A", "D")
    // the routes in their circuits' colours
    pv.calc.routes.runs.forEach { r ->
        val col = rgbC(r.circuit.rgb)
        r.segs.forEach { s -> if (s.wall == null || s.wall in vis) { val p0 = cam.p(sc(s.a, s.za)); val p1 = cam.p(sc(s.b, s.zb)); if (p0 != null && p1 != null) drawLine(col, p0, p1, 1.6f * density, StrokeCap.Round) } }
    }
    val circ = pv.calc.circuits.flatMap { cc -> cc.devs.map { it.id to cc } }.toMap()
    pv.devs.forEach { d ->
        val col = circ[d.id]?.let { rgbC(it.rgb) } ?: Color(0xFF94A3B8)
        if (d.onCeiling) {
            val q = V2(d.cx.toDouble(), d.cy.toDouble()); val r = devType(d.t).dw / 2.0
            val ring = (0 until 12).map { i -> val t = 2 * Math.PI * i / 12; sc(V2(q.x + r * cos(t), q.y + r * sin(t)), g.H - 5) }
            quad(ring, rgbC(0xFDE68A), Color(0xFF6B7280))
            return@forEach
        }
        if (d.wall !in vis) return@forEach
        val w = c.wall(d.wall) ?: return@forEach
        val (dw, dh) = devSize(d)
        val a0 = d.off - dw / 2.0; val a1 = d.off + dw / 2.0; val b0 = d.h - dh / 2.0; val b1 = d.h + dh / 2.0
        if (d.t == "led") { val p0 = cam.p(sc(w.at(a0, 4.0), d.h.toDouble())); val p1 = cam.p(sc(w.at(a1, 4.0), d.h.toDouble())); if (p0 != null && p1 != null) drawLine(rgbC(0xFACC15), p0, p1, 3f * density); return@forEach }
        // drawn a little bigger than true so the plates read on a card
        val k = 1.5; val m = (d.off.toDouble()); val hm = d.h.toDouble()
        val pts = listOf(sc(w.at(m - (m - a0) * k, 5.0), hm - (hm - b0) * k), sc(w.at(m + (a1 - m) * k, 5.0), hm - (hm - b0) * k),
            sc(w.at(m + (a1 - m) * k, 5.0), hm + (b1 - hm) * k), sc(w.at(m - (m - a0) * k, 5.0), hm + (b1 - hm) * k))
        quad(pts, if (devType(d.t).cat == "box") rgbC(0x94A3B8) else Color.White, Color(0xFF475569))
        cam.p(sc(w.at(m, 6.0), hm))?.let { drawCircle(col, 2.2f * density, it) }
    }
}

/** A kit's picture as a still image (the gallery's cards). */
fun kitPicture(k: Kit, w: Int, h: Int, density: Float): ImageBitmap? {
    val pv = kitPreview(k, defaultOpts(k)) ?: return null
    val img = ImageBitmap(w, h)
    CanvasDrawScope().draw(Density(density), LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(img), Size(w.toFloat(), h.toFloat())) { drawKitPreview(pv) }
    return img
}

/** The gallery's pictures, made once from the app's own drawing of each kit. */
object ElecPics {
    val pics = mutableStateMapOf<String, ImageBitmap>()
    suspend fun make(w: Int, h: Int, density: Float) {
        for (k in KITS) {
            if (pics[k.id] != null) continue
            val img = withContext(Dispatchers.Default) { runCatching { kitPicture(k, w, h, density) }.getOrNull() }
            if (img != null) pics[k.id] = img
        }
    }
}

/* ---------------- the gallery ---------------- */

@Composable
fun EGalleryScreen(rt: Route.EGallery) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val room = rt.rid?.let { id -> p.rooms.firstOrNull { it.id == id } }
    val first = room?.let { r -> ctxOf(p, r.id, app.settings.angleSnap)?.kind ?: p.elec.room(r.id).kind.ifEmpty { uz.metrx.app.elec.guessKind(p.floors.firstOrNull { it.id == r.floorId }?.type, r.name) } }
    val kinds = KINDS.filter { k -> KITS.any { it.kind == k } }.let { ks -> if (first == null) ks else ks.sortedBy { if (it == first) 0 else 1 } }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val tops = remember { mutableStateMapOf<String, Int>() }
    val dens = LocalDensity.current.density
    LaunchedEffect(Unit) { ElecPics.make((200 * dens).toInt(), (170 * dens).toInt(), dens) }
    val cur = if (scroll.maxValue > 0 && scroll.value >= scroll.maxValue - 4) kinds.last()
        else kinds.lastOrNull { (tops[it] ?: Int.MAX_VALUE) <= scroll.value + 60 } ?: kinds.first()
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        PageBar(frosted = true) {
            GlassIconButton("back", tr("nt.back"), { app.pop() }, Modifier.padding(start = 6.dp))
            Spacer(Modifier.width(6.dp))
            BarTitle(tr("el.galT"), eyebrow = dn(p.name, lang))
        }
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            kinds.forEach { g ->
                val on = g == cur
                Text(tr(kindKey(g)), style = ui(14f, 700, if (on) G.solid else G.ink), maxLines = 1,
                    modifier = Modifier.heightIn(min = 40.dp).clip(CircleShape).background(if (on) G.ink else G.glass(.55f)).semantics { selected = on }
                        .clickable(role = Role.Tab) { scope.launch { scroll.animateScrollTo(tops[g] ?: 0) } }.padding(horizontal = 16.dp, vertical = 10.dp))
            }
        }
        Column(Modifier.weight(1f).verticalScroll(scroll).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (room != null) {
                val f = { mm: Int? -> fmtLen(mm, LenUnit.M, en) }
                Text(tr("tl.forRoom", "r" to (p.floors.firstOrNull { it.id == room.floorId }?.let { floorName(it, lang) } ?: dn(room.name, lang)),
                    "a" to f(room.dim("A").v), "b" to f(room.dim("B").v), "h" to f(room.dim("H").v)), style = ui(13.5f, 400, G.ink2, 1.4f))
            } else Text(tr("el.galB"), style = ui(13.5f, 400, G.ink2, 1.4f))
            kinds.forEach { g ->
                val ks = KITS.filter { it.kind == g }
                Row(Modifier.padding(top = 8.dp, start = 2.dp).onGloballyPositioned { tops[g] = it.positionInParent().y.toInt() }, verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr(kindKey(g)), style = ui(17f, 800))
                    Text("${ks.size}", style = ui(12.5f, 500, G.ink3))
                }
                ks.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { k -> KitCard(k, Modifier.weight(1f).fillMaxHeight(), wide = row.size == 1) { app.push(Route.ESteps(p.id, k.id, rt.rid)) } }
                    }
                }
            }
            if (rt.fromNew) Text(tr("fz.needL"), style = ui(14.5f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp)
                .clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { app.pop() }.padding(horizontal = 16.dp, vertical = 12.dp))
        }
    }
}

/** A kit's contents in words, from the kit put in its sample room. */
private val kitDevs = HashMap<String, List<ElecDev>>()

@Composable
private fun KitCard(k: Kit, modifier: Modifier, wide: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    val name = tr("el.kit.${k.id}")
    val ds = remember(k.id) { kitDevs.getOrPut(k.id) { kitPreview(k, defaultOpts(k))?.devs ?: emptyList() } }
    val sub = devSummary(ds)
    val pic: @Composable (Modifier) -> Unit = { pm ->
        Box(pm.aspectRatio(200f / 170f).clip(RoundedCornerShape(14.dp)).background(Color(0xFFF6F8FC)), contentAlignment = Alignment.Center) {
            val img = ElecPics.pics[k.id]
            if (img != null) Image(img, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) else Text("3D…", style = ui(11f, 600, G.ink3))
        }
    }
    val words: @Composable () -> Unit = {
        Column(Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(name, style = ui(14.5f, 800, G.ink), maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(sub, style = ui(12f, 500, G.ink2, 1.3f), maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
    }
    val mod = modifier.clip(shape).glassCard(shape, fill = G.glass(.62f)).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = name }.padding(8.dp)
    if (wide) Row(mod, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        pic(Modifier.weight(1f)); Box(Modifier.weight(1f)) { words() }
    } else Column(mod, verticalArrangement = Arrangement.spacedBy(6.dp)) { pic(Modifier.fillMaxWidth()); words() }
}

/* ---------------- the steps ---------------- */

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun EStepsScreen(rt: Route.ESteps) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val k = kitOf(rt.kit) ?: return
    val d0 = defaultOpts(k)
    var light by rememberSaveable(rt) { mutableStateOf(d0.light) }
    var led by rememberSaveable(rt) { mutableStateOf(d0.led) }
    var ac by rememberSaveable(rt) { mutableStateOf(d0.ac) }
    var low by rememberSaveable(rt) { mutableStateOf(d0.low) }
    // where: a room's id, "new" (a new room) or "free" (typed by size)
    var where by rememberSaveable(rt) { mutableStateOf(rt.rid ?: "") }
    val unit = app.settings.unit
    var tl by rememberSaveable(rt) { mutableStateOf(fmtField(4000, unit, en)) }
    var tw by rememberSaveable(rt) { mutableStateOf(fmtField(3000, unit, en)) }
    var th by rememberSaveable(rt) { mutableStateOf(fmtField(2700, unit, en)) }
    val o = KitOpts(light, led, ac, low)
    val steps = buildList { add("light"); add("extras"); if (rt.rid == null) add("where") }
    val n = steps.size
    var at by rememberSaveable(rt) { mutableIntStateOf(0) }
    val step = steps[at.coerceIn(0, n - 1)]
    val pv = remember(light, led, ac, low) { kitPreview(k, o) }
    val sizes = listOf(parseMm(tl, unit), parseMm(tw, unit), parseMm(th, unit))
    val freeOk = sizes.all { it != null } && sizes[0]!! in 1000..30000 && sizes[1]!! in 1000..30000 && sizes[2]!! in 2000..6000
    fun ok(s: String) = s != "where" || (where.isNotEmpty() && (where != "free" || freeOk))
    fun prev() { if (at > 0) at -= 1 else app.pop() }
    BackHandler { prev() }
    fun save() {
        if (!steps.all { ok(it) } || !app.once()) return
        val kitName = app.t("el.kit.${k.id}")
        when (where) {
            "free" -> {
                val f = freeOf(k, o, uid(), app.t(kindKey(k.kind)), sizes[0]!!, sizes[1]!!, sizes[2]!!)
                app.updateElec(p.id) { it.copy(free = it.free + f) }
                app.popTo { it is Route.Project && it.id == p.id }
                app.push(Route.EView(p.id, "free:" + f.id)); app.say("el.kitAdded", "n" to kitName)
            }
            "new" -> {
                // the suggested name kept as its key, so it follows the language
                val rid = app.addElecRoom(p.id, k.kind, uz.metrx.app.data.suggestedName(uz.metrx.app.data.nextName(p, kindKey(k.kind), app.settings.lang), kindKey(k.kind), app.settings.lang))
                app.updateERoom(p.id, rid) { it.copy(pend = it.pend + pickOf(k, o)) }
                app.popTo { it is Route.Project && it.id == p.id }
                app.openRoom(p.id, rid); app.say("el.kitPend")
            }
            else -> {
                val r = p.rooms.firstOrNull { it.id == where } ?: return
                app.popTo { it is Route.Project && it.id == p.id }
                if (ready3D(r, app.settings.angleSnap)) {
                    val want = uz.metrx.app.elec.ctxOf(p, r.id, app.settings.angleSnap)?.let { uz.metrx.app.elec.kitWanted(k, it, o) } ?: 0
                    val got = app.applyKit(p.id, r.id, k, o)
                    // fewer than the kit has: the room had no clear place for the rest (doors, windows, water)
                    app.push(Route.EView(p.id, r.id)); if (got < want) app.say("el.kitFewer", "n" to got, "m" to want, kind = uz.metrx.app.ui.components.ToastKind.INFO) else app.say("el.kitPlaced", "n" to got)
                } else {
                    app.updateERoom(p.id, r.id) { it.copy(pend = it.pend + pickOf(k, o)) }
                    app.say("el.kitPend")
                }
            }
        }
    }
    // with the keyboard up the footer goes under the fields (not over them), so the one typed in stays in sight
    val imeOn = androidx.compose.foundation.layout.WindowInsets.isImeVisible
    Box(Modifier.fillMaxSize().imePadding()) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            PageBar(frosted = true) {
                GlassIconButton("back", tr("nt.back"), ::prev, Modifier.padding(start = 6.dp))
                Spacer(Modifier.width(6.dp))
                BarTitle(tr("el.kit.${k.id}"), eyebrow = tr("tl.stepN", "i" to at + 1, "n" to n))
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = if (imeOn) 16.dp else 168.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.align(Alignment.CenterHorizontally), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (0 until n).forEach { i -> Box(Modifier.size(if (i == at) 22.dp else 8.dp, 8.dp).clip(CircleShape).background(when { i == at -> G.cobalt; i < at -> G.cobalt.copy(alpha = .45f); else -> G.ink.copy(alpha = .15f) })) }
                }
                if (pv != null && step != "where") Box(Modifier.fillMaxWidth().aspectRatio(1.25f).clip(RoundedCornerShape(22.dp)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                    var az by remember { mutableFloatStateOf(0f) }
                    Canvas(Modifier.fillMaxSize().pointerInput(Unit) { detectHorizontalDragGestures { ch, dx -> ch.consume(); az = (az - dx / 400f).coerceIn(-.45f, .45f) } }) { drawKitPreview(pv, az) }
                    Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                }
                if (pv != null && step != "where") Text(devSummary(pv.devs), style = ui(13f, 600, G.ink2, 1.35f))
                when (step) {
                    "light" -> Ask(tr("el.s.light"), tr("el.s.lightH")) {
                        listOf("" to "el.s.asKit", "lc" to "el.t.lc", "lch" to "el.t.lch", "ls" to "el.s.spots").forEach { (v, key) ->
                            Option(tr(key), if (v == "") tr("el.s.asKitS") else tr("el.s.${v}S"), light == v) { light = v }
                        }
                    }
                    "extras" -> Ask(tr("el.s.extras"), tr("el.s.extrasH")) {
                        Toggle(tr("el.s.led"), tr("el.s.ledS"), led) { led = !led }
                        if (k.kind != "bath" && k.kind != "hall") Toggle(tr("el.s.ac"), tr("el.s.acS"), ac) { ac = !ac }
                        Toggle(tr("el.s.low"), tr("el.s.lowS"), low) { low = !low }
                    }
                    "where" -> Ask(tr("fq.title"), tr("el.s.whereH")) {
                        p.rooms.forEach { r ->
                            val w = p.floors.firstOrNull { it.id == r.floorId }
                            val ready = measuredRoom(r, app.settings.angleSnap)
                            Option(w?.let { floorName(it, lang) } ?: dn(r.name, lang), if (ready && !r.isPoly) fmtLen(r.dim("A").v, LenUnit.M, en) + " × " + fmtLen(r.dim("B").v, LenUnit.M, en) + " " + tr("u.m")
                                else tr(if (ready) "tl.measured" else "el.s.later"), where == r.id) { where = r.id }
                        }
                        Option(tr("fz.newRoom"), tr("el.s.newS", "k" to tr(kindKey(k.kind))), where == "new") { where = "new" }
                        Option(tr("tl.s.noRoom"), tr("el.s.freeS"), where == "free") { where = "free" }
                        if (where == "free") Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
                            GField(tr("tl.pa"), tl, { v -> tl = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "4", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
                            GField(tr("tl.pbW"), tw, { v -> tw = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "3", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
                            GField(tr("tl.pbH"), th, { v -> th = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2,7", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
            if (imeOn) FloatingFooter(Modifier) {
            if (at < n - 1) GBtn(tr("common.next"), { if (ok(step)) at += 1 }, enabled = ok(step))
            else GBtn(tr(if (where == "" || where == "free" || p.rooms.firstOrNull { it.id == where }?.let { ready3D(it, app.settings.angleSnap) } == true) "el.s.put" else "el.s.putLater"), ::save, enabled = steps.all { ok(it) })
            }
        }
        if (!imeOn) FloatingFooter(Modifier.align(Alignment.BottomCenter)) {
            if (at < n - 1) GBtn(tr("common.next"), { if (ok(step)) at += 1 }, enabled = ok(step))
            else GBtn(tr(if (where == "" || where == "free" || p.rooms.firstOrNull { it.id == where }?.let { ready3D(it, app.settings.angleSnap) } == true) "el.s.put" else "el.s.putLater"), ::save, enabled = steps.all { ok(it) })
        }
    }
}

@Composable
internal fun Ask(title: String, help: String, body: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = ui(21f, 800, G.ink, 1.2f), modifier = Modifier.padding(top = 4.dp))
        Text(help, style = ui(13f, 400, G.ink2, 1.4f))
        body()
    }
}

@Composable
internal fun Option(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
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

@Composable
internal fun Toggle(title: String, sub: String, on: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(16.dp)).background(G.glass(.75f)).switchState(on).clickable(role = Role.Switch, onClick = onClick)
        .padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f)) { Text(title, style = ui(15f, 700)); Text(sub, style = ui(12.5f, 400, G.ink2, 1.3f)) }
        GSwitch(on)
    }
}
