package uz.metrx.app.ui.plumb

import androidx.activity.compose.BackHandler
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
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.fmtField
import uz.metrx.app.geo.fmtLen
import uz.metrx.app.geo.ready3D
import uz.metrx.app.plumb.PCtx
import uz.metrx.app.plumb.PKITS
import uz.metrx.app.plumb.PKit
import uz.metrx.app.plumb.POpts
import uz.metrx.app.plumb.PlFix
import uz.metrx.app.plumb.PlRiser
import uz.metrx.app.plumb.PlRoom
import uz.metrx.app.plumb.PlumbCalc
import uz.metrx.app.plumb.PlumbOrder
import uz.metrx.app.plumb.RISER_D
import uz.metrx.app.plumb.RISER_W
import uz.metrx.app.plumb.UFH_RGB
import uz.metrx.app.plumb.calcOf
import uz.metrx.app.plumb.ctxOf
import uz.metrx.app.plumb.fixD
import uz.metrx.app.plumb.fixTop
import uz.metrx.app.plumb.fixW
import uz.metrx.app.plumb.fixZ0
import uz.metrx.app.plumb.freeOf
import uz.metrx.app.plumb.kindRgb
import uz.metrx.app.plumb.pkitOf
import uz.metrx.app.plumb.placeFix
import uz.metrx.app.plumb.placeKit
import uz.metrx.app.plumb.snake
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import uz.metrx.app.ui.LocalApp
import uz.metrx.app.ui.Route
import uz.metrx.app.ui.components.BarTitle
import uz.metrx.app.ui.components.FloatingFooter
import uz.metrx.app.ui.components.GBtn
import uz.metrx.app.ui.components.GField
import uz.metrx.app.ui.components.GlassIconButton
import uz.metrx.app.ui.components.PageBar
import uz.metrx.app.ui.elec.Ask
import uz.metrx.app.ui.elec.Option
import uz.metrx.app.ui.elec.Toggle
import uz.metrx.app.ui.elec.rgbC
import uz.metrx.app.ui.furniture.measuredRoom
import uz.metrx.app.ui.furniture.openRoom
import uz.metrx.app.ui.furniture.parseMm
import uz.metrx.app.ui.glass.glassCard
import uz.metrx.app.ui.theme.G
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.tr
import uz.metrx.app.ui.theme.ui
import uz.metrx.app.ui.tiles.TCam
import kotlin.math.cos
import kotlin.math.sin

/*
 * Choosing a room kit (22 Oct 2026): the gallery of kits grouped by room, each card drawn by the app from the kit put in
 * a sample room seen from inside towards the corner where the riser stands; then a few questions (bath or shower, the
 * extras, the heating, which room), the kit shown in the sample room all along.
 */

/** The sample room a kit is shown in: the door on wall B out of sight, the water marked on wall A, the riser in the A/D corner. */
private fun sampleRoom(k: PKit): Pair<Room, PlRiser?> {
    val (L, W) = when (k.kind) { "bath" -> 2600 to 2000; "wc" -> 1200 to 1600; "kitchen" -> 4200 to 3400; "util" -> 2200 to 1800; else -> 4200 to 3400 }
    val ops = buildList {
        if (k.id == "ht.ufh") add(Opening("d", "door", "D", 800, 2100, 300)) else if (k.kind == "wc") add(Opening("d", "door", "C", 700, 2100, 250)) else add(Opening("d", "door", "B", 800, 2100, W - 1000))
        if (k.kind == "heat") add(Opening("w", "window", "A", 1400, 1400, L / 2 - 700, 900))
    }
    val pts = when (k.kind) {
        "wc" -> listOf(SitePoint("c", "cold", "D", 800, 550))
        "heat" -> emptyList()
        else -> listOf(SitePoint("c", "cold", "A", if (k.kind == "kitchen") 1600 else 1300, 550))
    }
    val r = Room("sample", "sw", "", dims = mapOf("A" to Dim(L), "B" to Dim(W), "H" to Dim(2700), "T" to Dim(120, "default")), openings = ops, points = pts)
    return r to (if (k.kind == "heat") null else PlRiser("sample", "A", 140))
}

/** A kit in its sample room: the room, its fixtures placed, the riser, the routes. */
class PPreview(val c: PCtx, val fixes: List<PlFix>, val riser: PlRiser?, val calc: PlumbCalc)

fun kitPreview(k: PKit, o: POpts): PPreview? {
    val (r, rs) = sampleRoom(k)
    val kind = if (k.kind == "heat") "room" else k.kind
    val p0 = Project("sample", "", floors = listOf(Workspace("sw", "", if (kind == "kitchen") "kitchen" else if (kind == "bath") "bath" else "room")), rooms = listOf(r),
        industry = "plumb", plumb = PlumbOrder(rooms = listOf(PlRoom("sample", kind, ufh = o.ufh, step = o.step)), riser = rs))
    val c = ctxOf(p0, "sample", true) ?: return null
    var n = 0
    val fs = ArrayList(placeKit(k, c, emptyList(), rs, { "s${n++}" }, o))
    if (o.ufh) placeFix("manif", c, fs, rs, "s${n++}")?.let { fs += it }
    // a boiler for the heating to come from
    if ((o.rad || o.ufh) && fs.none { it.t == "gb" }) placeFix("gb", c, fs, rs, "s${n++}")?.let { fs += it }
    val p = p0.copy(plumb = p0.plumb.copy(fixes = fs))
    return PPreview(ctxOf(p, "sample", true)!!, fs, rs, calcOf(p, true))
}

/** A box of a fixture for the pictures: [a0]…[a1] along its wall, [d0]…[d1] into the room, [z0]…[z1] up, its colour. */
private class PBox(val a0: Double, val a1: Double, val d0: Double, val d1: Double, val z0: Double, val z1: Double, val rgb: Int, val alpha: Float = 1f)

private fun boxesOf(f: PlFix): List<PBox> {
    val x = f.off.toDouble(); val h = fixW(f) / 2.0; val d = fixD(f).toDouble(); val z0 = fixZ0(f).toDouble(); val z1 = fixTop(f).toDouble()
    return when (f.t) {
        "wc" -> listOf(PBox(x - 170, x + 170, 160.0, d - 40, 0.0, 420.0, 0xF8FAFC), PBox(x - 190, x + 190, 0.0, 170.0, 420.0, z1, 0xF8FAFC))
        "bs", "bsm" -> listOfNotNull(if (f.opt == "cab") PBox(x - h + 10, x + h - 10, 20.0, d - 20, 0.0, z1 - 160, 0xE7DCCB) else null, PBox(x - h, x + h, 0.0, d, z1 - 160, z1, 0xF8FAFC))
        "sink" -> listOf(PBox(x - h, x + h, 0.0, d, 0.0, z1, 0xE7DCCB))
        "cab" -> listOf(PBox(x - h, x + h, 0.0, d, 0.0, 150.0, 0xF8FAFC), PBox(x - h, x + h, 0.0, d, 150.0, z1, 0xBFDBFE, .35f))
        else -> listOf(PBox(x - h, x + h, 0.0, d, z0, z1, 0xF8FAFC))
    }
}

/** Draws the kit in its sample room's far corner, seen from inside the room; [az] turns the view a little. */
fun DrawScope.drawKitPreview(pv: PPreview, az: Float = 0f) {
    drawRect(Color(0xFFF6F8FC))
    val c = pv.c; val g = c.g
    val L = g.walls[0].len / 1000; val W = g.walls[1].len / 1000; val H = g.H / 1000
    val a = .78 + az
    val tgt = V3(L * .32, H * .32, W * .32)
    val dist = kotlin.math.hypot(L, W) * .82
    val eye = V3(tgt.x + dist * cos(a), H * .7, tgt.z + dist * sin(a))
    val cam = TCam(eye, tgt, size.width, size.height, .6)
    fun sc(q: V2, z: Double) = V3(q.x / 1000, z / 1000, q.y / 1000)
    fun quad(pts: List<V3>, col: Color, stroke: Color? = null) {
        val o = pts.map { cam.p(it) ?: return }
        val path = Path().apply { moveTo(o[0].x, o[0].y); o.drop(1).forEach { lineTo(it.x, it.y) }; close() }
        drawPath(path, col); if (stroke != null) drawPath(path, stroke, style = Stroke(1f))
    }
    quad(g.floor.map { sc(it, 0.0) }, rgbC(0xE2E6EC))
    val vis = setOf("A", "D")
    vis.forEach { id ->
        val w = g.wall(id) ?: return@forEach
        quad(listOf(sc(w.at(0.0), 0.0), sc(w.at(w.len), 0.0), sc(w.at(w.len), g.H), sc(w.at(0.0), g.H)), rgbC(if (id == "A") 0xEEF1F5 else 0xE6EAF0))
        c.room.openings.filter { it.wall == id }.forEach { o ->
            val pts = listOf(sc(w.at(o.off.toDouble(), 2.0), o.sill.toDouble()), sc(w.at((o.off + o.w).toDouble(), 2.0), o.sill.toDouble()),
                sc(w.at((o.off + o.w).toDouble(), 2.0), (o.sill + o.h).toDouble()), sc(w.at(o.off.toDouble(), 2.0), (o.sill + o.h).toDouble()))
            quad(pts, if (o.type == "door") Color(0xFFD9DEE6) else Color(0xFFCFE0F7), Color(0xFF9AA8BF))
        }
    }
    g.wall("A")?.let { w -> val p0 = cam.p(sc(w.at(0.0), 0.0)); val p1 = cam.p(sc(w.at(0.0), g.H)); if (p0 != null && p1 != null) drawLine(Color(0x33101828), p0, p1, density) }
    // the underfloor loops, then the pipes
    pv.calc.routes.loops.firstOrNull()?.let { l -> for (k in 0 until l.n) snake(c, l.step, k, l.n).forEach { (p, q) -> val p0 = cam.p(sc(p, 5.0)); val p1 = cam.p(sc(q, 5.0)); if (p0 != null && p1 != null) drawLine(rgbC(UFH_RGB), p0, p1, density) } }
    pv.calc.routes.runs.sortedBy { if (it.kind == "drain") 0 else 1 }.forEach { r ->
        val col = rgbC(kindRgb(r.kind))
        r.segs.forEach { s -> if (s.wall == null || s.wall in vis || (s.za < 90 && s.zb < 90)) { val p0 = cam.p(sc(s.a, s.za)); val p1 = cam.p(sc(s.b, s.zb)); if (p0 != null && p1 != null) drawLine(col, p0, p1, (if (r.kind == "drain") 2.4f else 1.6f) * density, StrokeCap.Round) } }
    }
    // the riser and the fixtures as boxes, far ones first, each showing the faces turned to the eye
    class B(val w: TWall, val b: PBox)
    val boxes = ArrayList<B>()
    pv.riser?.let { r -> c.wall(r.wall)?.let { w -> boxes += B(w, PBox(r.off - RISER_W / 2.0, r.off + RISER_W / 2.0, 0.0, RISER_D.toDouble(), 0.0, g.H, 0xCBD5E1)) } }
    pv.fixes.forEach { f -> c.wall(f.wall)?.let { w -> boxesOf(f).forEach { boxes += B(w, it) } } }
    val e = V2(eye.x * 1000, eye.z * 1000)
    fun mid(x: B) = x.w.at((x.b.a0 + x.b.a1) / 2, (x.b.d0 + x.b.d1) / 2)
    boxes.sortedByDescending { x -> val m = mid(x); kotlin.math.hypot(m.x - e.x, m.y - e.y) }.forEach { bx ->
        val w = bx.w; val b = bx.b
        fun p(aa: Double, dd: Double, zz: Double) = sc(w.at(aa, dd), zz)
        val faces = listOf(
            Triple(listOf(p(b.a0, b.d0, b.z1), p(b.a1, b.d0, b.z1), p(b.a1, b.d1, b.z1), p(b.a0, b.d1, b.z1)), V3(0.0, 1.0, 0.0), 1f),
            Triple(listOf(p(b.a0, b.d1, b.z0), p(b.a1, b.d1, b.z0), p(b.a1, b.d1, b.z1), p(b.a0, b.d1, b.z1)), V3(w.nIn.x, 0.0, w.nIn.y), .9f),
            Triple(listOf(p(b.a0, b.d0, b.z0), p(b.a0, b.d1, b.z0), p(b.a0, b.d1, b.z1), p(b.a0, b.d0, b.z1)), V3(-w.t.x, 0.0, -w.t.y), .8f),
            Triple(listOf(p(b.a1, b.d0, b.z0), p(b.a1, b.d1, b.z0), p(b.a1, b.d1, b.z1), p(b.a1, b.d0, b.z1)), V3(w.t.x, 0.0, w.t.y), .8f))
        faces.forEach { (pts, n, shade) ->
            val cx = pts.sumOf { it.x } / 4; val cy = pts.sumOf { it.y } / 4; val cz = pts.sumOf { it.z } / 4
            if ((eye.x - cx) * n.x + (eye.y - cy) * n.y + (eye.z - cz) * n.z <= 0) return@forEach
            val col = rgbC(b.rgb, b.alpha).let { Color(it.red * shade, it.green * shade, it.blue * shade, it.alpha) }
            quad(pts, col, Color(0xFF64748B))
        }
    }
    // the outlets
    pv.fixes.flatMap { uz.metrx.app.plumb.fixPoints(it) }.forEach { q ->
        if (q.wall !in vis) return@forEach
        val w = c.wall(q.wall) ?: return@forEach
        cam.p(sc(w.at(q.off.toDouble(), 6.0), q.h.toDouble()))?.let { drawCircle(rgbC(kindRgb(q.t)), 2.4f * density, it) }
    }
}

/** A kit's picture as a still image (the gallery's cards). */
fun kitPicture(k: PKit, w: Int, h: Int, density: Float): ImageBitmap? {
    val pv = kitPreview(k, k.opts) ?: return null
    val img = ImageBitmap(w, h)
    CanvasDrawScope().draw(Density(density), LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(img), Size(w.toFloat(), h.toFloat())) { drawKitPreview(pv) }
    return img
}

/** The gallery's pictures, made once from the app's own drawing of each kit. */
object PlumbPics {
    val pics = mutableStateMapOf<String, ImageBitmap>()
    suspend fun make(w: Int, h: Int, density: Float) {
        for (k in PKITS) {
            if (pics[k.id] != null) continue
            val img = withContext(Dispatchers.Default) { runCatching { kitPicture(k, w, h, density) }.getOrNull() }
            if (img != null) pics[k.id] = img
        }
    }
}

/** The gallery's groups, in order. */
val PKINDS = listOf("bath", "wc", "kitchen", "util", "heat")

/* ---------------- the gallery ---------------- */

@Composable
fun PGalleryScreen(rt: Route.PGallery) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val room = rt.rid?.let { id -> p.rooms.firstOrNull { it.id == id } }
    val first = room?.let { r -> p.plumb.room(r.id).kind.ifEmpty { uz.metrx.app.plumb.guessKind(p.floors.firstOrNull { it.id == r.floorId }?.type, r.name) } }
    val kinds = PKINDS.let { ks -> if (first == null) ks else ks.sortedBy { if (it == first) 0 else 1 } }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val tops = remember { mutableStateMapOf<String, Int>() }
    val dens = LocalDensity.current.density
    LaunchedEffect(Unit) { PlumbPics.make((200 * dens).toInt(), (170 * dens).toInt(), dens) }
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
            } else Text(tr("sx.galB"), style = ui(13.5f, 400, G.ink2, 1.4f))
            kinds.forEach { g ->
                val ks = PKITS.filter { it.kind == g }
                Row(Modifier.padding(top = 8.dp, start = 2.dp).onGloballyPositioned { tops[g] = it.positionInParent().y.toInt() }, verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr(kindKey(g)), style = ui(17f, 800))
                    Text("${ks.size}", style = ui(12.5f, 500, G.ink3))
                }
                ks.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { k -> KitCard(k, Modifier.weight(1f).fillMaxHeight(), wide = row.size == 1) { app.push(Route.PSteps(p.id, k.id, rt.rid)) } }
                    }
                }
            }
            if (rt.fromNew) Text(tr("fz.needL"), style = ui(14.5f, 700, G.cobalt2), modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp)
                .clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { app.pop() }.padding(horizontal = 16.dp, vertical = 12.dp))
        }
    }
}

@Composable
private fun KitCard(k: PKit, modifier: Modifier, wide: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    val name = tr("sx.kit.${k.id}")
    val sub = tr("sx.kitS.${k.id}")
    val pic: @Composable (Modifier) -> Unit = { pm ->
        Box(pm.aspectRatio(200f / 170f).clip(RoundedCornerShape(14.dp)).background(Color(0xFFF6F8FC)), contentAlignment = Alignment.Center) {
            val img = PlumbPics.pics[k.id]
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
fun PStepsScreen(rt: Route.PSteps) {
    val app = LocalApp.current
    val lang = LocalLang.current
    val en = lang == Lang.EN
    val p = app.store.get(rt.pid) ?: return
    val k = pkitOf(rt.kit) ?: return
    val d0 = k.opts
    var bath by rememberSaveable(rt) { mutableStateOf(d0.bath) }
    var cab by rememberSaveable(rt) { mutableStateOf(d0.cab) }
    var wm by rememberSaveable(rt) { mutableStateOf(d0.wm) }
    var trl by rememberSaveable(rt) { mutableStateOf(d0.tr) }
    var dw by rememberSaveable(rt) { mutableStateOf(d0.dw) }
    var basin by rememberSaveable(rt) { mutableStateOf(d0.basin) }
    var heater by rememberSaveable(rt) { mutableStateOf(d0.heater) }
    var rad by rememberSaveable(rt) { mutableStateOf(d0.rad) }
    var ufh by rememberSaveable(rt) { mutableStateOf(d0.ufh) }
    var step by rememberSaveable(rt) { mutableIntStateOf(d0.step) }
    // where: a room's id, "new" (a new room) or "free" (typed by size)
    var where by rememberSaveable(rt) { mutableStateOf(rt.rid ?: "") }
    val unit = app.settings.unit
    var tl by rememberSaveable(rt) { mutableStateOf(fmtField(if (k.kind == "kitchen") 3500 else 2500, unit, en)) }
    var tw by rememberSaveable(rt) { mutableStateOf(fmtField(if (k.kind == "kitchen") 3000 else 2000, unit, en)) }
    var th by rememberSaveable(rt) { mutableStateOf(fmtField(2700, unit, en)) }
    val o = POpts(bath, cab, wm, trl, dw, basin, heater, rad, ufh, step)
    val steps = buildList { if (k.main.isNotEmpty()) add("main"); if (k.kind != "heat" || k.main.isEmpty()) add("heat"); if (rt.rid == null) add("where") }
    val n = steps.size
    var at by rememberSaveable(rt) { mutableIntStateOf(0) }
    val cur = steps[at.coerceIn(0, n - 1)]
    val pv = remember(o) { kitPreview(k, o) }
    val sizes = listOf(parseMm(tl, unit), parseMm(tw, unit), parseMm(th, unit))
    val freeOk = sizes.all { it != null } && sizes[0]!! in 800..30000 && sizes[1]!! in 800..30000 && sizes[2]!! in 2000..6000
    fun ok(s: String) = s != "where" || (where.isNotEmpty() && (where != "free" || freeOk))
    fun prev() { if (at > 0) at -= 1 else app.pop() }
    BackHandler { prev() }
    fun save() {
        if (!steps.all { ok(it) } || !app.once()) return
        val kitName = app.t("sx.kit.${k.id}")
        val kind = if (k.kind == "heat") "room" else k.kind
        when (where) {
            "free" -> {
                val f = freeOf(k, o, uid(), "@" + kindKey(kind), sizes[0]!!, sizes[1]!!, sizes[2]!!)
                app.updatePlumb(p.id) { it.copy(free = it.free + f) }
                app.popTo { it is Route.Project && it.id == p.id }
                app.push(Route.PView(p.id, "free:" + f.id)); app.say("el.kitAdded", "n" to kitName)
            }
            "new" -> {
                // the suggested name kept as its key, so it follows the language
                val rid = app.addPlumbRoom(p.id, kind, uz.metrx.app.data.suggestedName(uz.metrx.app.data.nextName(p, kindKey(kind), app.settings.lang), kindKey(kind), app.settings.lang))
                app.updatePRoom(p.id, rid) { it.copy(pend = it.pend + uz.metrx.app.plumb.PKitPick(k.id, o)) }
                app.popTo { it is Route.Project && it.id == p.id }
                app.openRoom(p.id, rid); app.say("el.kitPend")
            }
            else -> {
                val r = p.rooms.firstOrNull { it.id == where } ?: return
                app.popTo { it is Route.Project && it.id == p.id }
                if (ready3D(r, app.settings.angleSnap)) {
                    val got = app.applyPKit(p.id, r.id, k, o)
                    app.push(Route.PView(p.id, r.id)); app.say("sx.kitPlaced", "n" to got)
                } else {
                    app.updatePRoom(p.id, r.id) { it.copy(pend = it.pend + uz.metrx.app.plumb.PKitPick(k.id, o)) }
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
                BarTitle(tr("sx.kit.${k.id}"), eyebrow = tr("tl.stepN", "i" to at + 1, "n" to n))
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = if (imeOn) 16.dp else 168.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.align(Alignment.CenterHorizontally), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (0 until n).forEach { i -> Box(Modifier.size(if (i == at) 22.dp else 8.dp, 8.dp).clip(CircleShape).background(when { i == at -> G.cobalt; i < at -> G.cobalt.copy(alpha = .45f); else -> G.ink.copy(alpha = .15f) })) }
                }
                if (pv != null && cur != "where") Box(Modifier.fillMaxWidth().aspectRatio(1.25f).clip(RoundedCornerShape(22.dp)).border(1.dp, G.rim, RoundedCornerShape(22.dp))) {
                    var az by remember { mutableFloatStateOf(0f) }
                    Canvas(Modifier.fillMaxSize().pointerInput(Unit) { detectHorizontalDragGestures { ch, dx -> ch.consume(); az = (az - dx / 400f).coerceIn(-.45f, .45f) } }) { drawKitPreview(pv, az) }
                    Text(tr("fx.drag"), style = ui(11f, 600, G.ink3), modifier = Modifier.align(Alignment.BottomEnd).padding(10.dp))
                }
                if (pv != null && cur != "where") Text(fixSummary(pv.fixes), style = ui(13f, 600, G.ink2, 1.35f))
                when (cur) {
                    "main" -> Ask(tr("sx.s.main"), tr("sx.s.mainH")) {
                        if ("bath" in k.main) listOf("bath", "sh", "cab").forEach { v -> Option(tr("sx.t.$v"), tr("sx.s.${v}S"), bath == v) { bath = v } }
                        if ("heater" in k.main) listOf("gb", "wh").forEach { v -> Option(tr("sx.t.$v"), tr("sx.s.${v}S"), heater == v) { heater = v } }
                        if ("step" in k.main) listOf(100, 150, 200).forEach { v -> Option(tr("sx.s.stepV", "n" to v / 10), tr("sx.s.step${v}S"), step == v) { step = v } }
                        if ("cab" in k.main) Toggle(tr("sx.s.vanity"), tr("sx.s.vanityS"), cab) { cab = !cab }
                        if ("wm" in k.main) Toggle(tr("sx.t.wm"), tr("sx.s.wmS"), wm) { wm = !wm }
                        if ("tr" in k.main) Toggle(tr("sx.t.tr"), tr("sx.s.trS"), trl) { trl = !trl }
                        if ("basin" in k.main) Toggle(tr("sx.t.bsm"), tr("sx.s.bsmS"), basin) { basin = !basin }
                        if ("dw" in k.main) Toggle(tr("sx.t.dw"), tr("sx.s.dwS"), dw) { dw = !dw }
                    }
                    "heat" -> Ask(tr("sx.s.heat"), tr("sx.s.heatH")) {
                        Toggle(tr("sx.s.rad"), tr("sx.s.radS"), rad) { rad = !rad }
                        Toggle(tr("sx.s.ufh"), tr("sx.s.ufhS"), ufh) { ufh = !ufh }
                    }
                    "where" -> Ask(tr("fq.title"), tr("el.s.whereH")) {
                        p.rooms.forEach { r ->
                            val w = p.floors.firstOrNull { it.id == r.floorId }
                            val ready = measuredRoom(r, app.settings.angleSnap)
                            Option(w?.let { floorName(it, lang) } ?: dn(r.name, lang), if (ready && !r.isPoly) fmtLen(r.dim("A").v, LenUnit.M, en) + " × " + fmtLen(r.dim("B").v, LenUnit.M, en) + " " + tr("u.m")
                                else tr(if (ready) "tl.measured" else "el.s.later"), where == r.id) { where = r.id }
                        }
                        Option(tr("fz.newRoom"), tr("el.s.newS", "k" to tr(kindKey(if (k.kind == "heat") "room" else k.kind))), where == "new") { where = "new" }
                        Option(tr("tl.s.noRoom"), tr("sx.s.freeS"), where == "free") { where = "free" }
                        if (where == "free") Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            val uw = tr(if (unit == LenUnit.CM) "u.cm" else "u.m")
                            GField(tr("tl.pa"), tl, { v -> tl = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2,5", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
                            GField(tr("tl.pbW"), tw, { v -> tw = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
                            GField(tr("tl.pbH"), th, { v -> th = v.filter { c -> c.isDigit() || c == ',' || c == '.' }.take(7) }, "2,7", decimal = true, labelRight = uw, modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
            if (imeOn) FloatingFooter(Modifier) {
            if (at < n - 1) GBtn(tr("common.next"), { if (ok(cur)) at += 1 }, enabled = ok(cur))
            else GBtn(tr(if (where == "" || where == "free" || p.rooms.firstOrNull { it.id == where }?.let { ready3D(it, app.settings.angleSnap) } == true) "el.s.put" else "el.s.putLater"), ::save, enabled = steps.all { ok(it) })
            }
        }
        if (!imeOn) FloatingFooter(Modifier.align(Alignment.BottomCenter)) {
            if (at < n - 1) GBtn(tr("common.next"), { if (ok(cur)) at += 1 }, enabled = ok(cur))
            else GBtn(tr(if (where == "" || where == "free" || p.rooms.firstOrNull { it.id == where }?.let { ready3D(it, app.settings.angleSnap) } == true) "el.s.put" else "el.s.putLater"), ::save, enabled = steps.all { ok(it) })
        }
    }
}
