package uz.metrx.app.ui.tiles

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.geo.V3
import uz.metrx.app.tiles.APRON_H0
import uz.metrx.app.tiles.APRON_H1
import uz.metrx.app.tiles.Laid
import uz.metrx.app.tiles.Look
import uz.metrx.app.tiles.Piece
import uz.metrx.app.tiles.Surf
import uz.metrx.app.tiles.T_MODELS
import uz.metrx.app.tiles.TFix
import uz.metrx.app.tiles.TRoomGeo
import uz.metrx.app.tiles.TSurf
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.V2
import uz.metrx.app.tiles.convexParts
import uz.metrx.app.tiles.cutRgb
import uz.metrx.app.tiles.drawInset
import uz.metrx.app.tiles.footprint
import uz.metrx.app.tiles.groutOf
import uz.metrx.app.tiles.layAll
import uz.metrx.app.tiles.layoutOf
import uz.metrx.app.tiles.lookFor
import uz.metrx.app.tiles.lookOf
import uz.metrx.app.tiles.roomGeo
import uz.metrx.app.tiles.scaleRgb
import uz.metrx.app.tiles.subtract
import uz.metrx.app.tiles.surfacesOf
import uz.metrx.app.tiles.tModel
import uz.metrx.app.tiles.toneOf
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.math.tan

/*
 * The tiles drawn by the app itself (no photos): a tile's look (a colour, or a drawn marble, wood or concrete), the
 * gallery's cards and the steps' picture (a sample corner of a room in perspective, with the real pattern on it), and
 * the swatches.
 */

fun rgbColor(rgb: Int, a: Float = 1f) = Color(((rgb shr 16) and 255) / 255f, ((rgb shr 8) and 255) / 255f, (rgb and 255) / 255f, a)

/** A tiny repeatable random number in [0, 1) from a seed. */
private fun rnd(seed: Int, k: Int): Float {
    var x = seed * 374761393 + k * 668265263
    x = (x xor (x ushr 13)) * 1274126177
    return ((x xor (x ushr 16)) and 0xFFFFFF) / 16777216f
}

/**
 * The texture of one tile: [at] maps the tile's own coordinates (s along its long side, t across, both 0…1) to the
 * screen. Marble veins, wood grain or concrete specks; a plain colour has none.
 */
private fun DrawScope.texture(look: Look, seed: Int, at: (Float, Float) -> Offset?, px: Float) {
    when (look.kind) {
        "m" -> {
            val vc = rgbColor(look.vein, .5f)
            repeat(2) { k ->
                val path = Path(); var first = true
                val t0 = rnd(seed, 10 + k); val t1 = rnd(seed, 20 + k)
                for (i in 0..8) {
                    val s = i / 8f
                    val t = t0 + (t1 - t0) * s + (rnd(seed, 30 + i + 9 * k) - .5f) * .12f
                    val o = at(s, t.coerceIn(0f, 1f)) ?: return
                    if (first) { path.moveTo(o.x, o.y); first = false } else path.lineTo(o.x, o.y)
                }
                drawPath(path, vc, style = Stroke(if (k == 0) 1.4f * px else .8f * px, cap = StrokeCap.Round))
            }
        }
        "w" -> {
            val gc = rgbColor(scaleRgb(look.rgb, .78), .38f)
            for (k in 0 until 5) {
                val path = Path(); var first = true
                val tb = (k + .5f) / 5f + (rnd(seed, 40 + k) - .5f) * .1f
                val ph = rnd(seed, 50 + k) * 6.28f
                for (i in 0..10) {
                    val s = i / 10f
                    val o = at(s, (tb + .03f * sin(ph + s * 9f)).coerceIn(0f, 1f)) ?: return
                    if (first) { path.moveTo(o.x, o.y); first = false } else path.lineTo(o.x, o.y)
                }
                drawPath(path, gc, style = Stroke(.8f * px))
            }
        }
        "k" -> {
            for (k in 0 until 9) {
                val o = at(rnd(seed, 60 + k), rnd(seed, 70 + k)) ?: return
                drawCircle(rgbColor(scaleRgb(look.rgb, if (k % 3 == 0) 1.15 else .8), .55f), (.6f + rnd(seed, 80 + k)) * px, o)
            }
        }
    }
}

private fun pathOf(pts: List<Offset>): Path = Path().apply { moveTo(pts[0].x, pts[0].y); for (i in 1 until pts.size) lineTo(pts[i].x, pts[i].y); close() }

/**
 * Draws the pieces of [laid] for layout [l]; [map] puts a surface's point on the screen (null: behind the eye).
 * [textures] draws the looks' veins and grain on tiles bigger than a few pixels.
 */
fun DrawScope.drawLaid(laid: Laid, l: TileLayout, map: (Surf) -> ((V2) -> Offset?), textures: Boolean, cutK: Double = .3, outline: Boolean = false) {
    val bySurf = laid.pieces.groupBy { it.s }
    val px = density
    laid.surfs.forEachIndexed { si, s ->
        val m = map(s)
        val main = lookFor(l, if (s.alt) 1 else 0)
        // the joints: the surface less its holes, in the grout's colour
        convexParts(s.outline).flatMap { part -> s.holes.fold(listOf(part)) { acc, h -> acc.flatMap { subtract(it, h) } } }.forEach { poly ->
            val pts = poly.map { m(it) ?: return@forEach }
            drawPath(pathOf(pts), rgbColor(groutOf(main.rgb)))
        }
        bySurf[si].orEmpty().forEach { pc -> drawPiece(pc, l, m, textures, px, cutK, if (outline) rgbColor(groutOf(main.rgb)) else null) }
    }
}

/** Above this many pieces a 2D drawing fills the surfaces in their look's colour instead of tile by tile (a mosaic stays quick). */
const val MAX_DRAWN_2D = 4000

/**
 * Like [drawLaid], but with more than [most] pieces each surface is filled in its tile's colour; a surface whose tiles
 * were too many to work out is filled so too (not left in the grout's colour).
 */
fun DrawScope.drawLaidCapped(laid: Laid, l: TileLayout, map: (Surf) -> ((V2) -> Offset?), most: Int = MAX_DRAWN_2D, outline: Boolean = false) {
    val flat = laid.pieces.size > most
    if (!flat) drawLaid(laid, l, map, false, outline = outline)
    laid.surfs.forEachIndexed { si, s ->
        if (!flat && si !in laid.tooMany) return@forEachIndexed
        val m = map(s)
        val main = lookFor(l, if (s.alt) 1 else 0)
        convexParts(s.outline).flatMap { part -> s.holes.fold(listOf(part)) { acc, h -> acc.flatMap { subtract(it, h) } } }.forEach { poly ->
            val pts = poly.map { m(it) ?: return@forEach }
            drawPath(pathOf(pts), rgbColor(main.rgb))
        }
    }
}

private fun DrawScope.drawPiece(pc: Piece, l: TileLayout, m: (V2) -> Offset?, textures: Boolean, px: Float, cutK: Double, line: Color?) {
    val lk = lookFor(l, pc.prod)
    val rgb = if (pc.cut && cutK > 0) cutRgb(lk.rgb, cutK) else toneOf(lk, pc.seed)
    val paths = pc.polys.map { poly -> pathOf(poly.map { m(it) ?: return }) }
    paths.forEach { drawPath(it, rgbColor(rgb)) }
    // small pictures: the joints as thin lines, or a 2 mm joint would vanish
    if (line != null) paths.forEach { drawPath(it, line, style = Stroke(.6f * px)) }
    if (!textures || lk.kind == "c") return
    val c = pc.c
    val along = if (pc.vert) c[3] - c[0] else c[1] - c[0]
    val across = if (pc.vert) c[1] - c[0] else c[3] - c[0]
    val o0 = m(c[0]) ?: return; val o1 = m(c[0] + along) ?: return
    if (hypot(o1.x - o0.x, o1.y - o0.y) < 9 * px) return
    val at = { s: Float, t: Float -> m(c[0] + along * s.toDouble() + across * t.toDouble()) }
    if (pc.cut) paths.forEach { p -> clipPath(p) { texture(lk, pc.seed, at, px) } } else texture(lk, pc.seed, at, px)
}

/* ---------------- a sample corner of a room in perspective ---------------- */

/** A camera looking into the sample room's corner from beyond its open side. */
class TCam(eye: V3, tgt: V3, val w: Float, val h: Float, half: Double = .5) {
    private val e = eye
    private val f = (tgt - eye).unit()
    private val r = cr(f, V3(0.0, 1.0, 0.0)).unit()
    private val u = cr(r, f)
    private val foc = (h / 2) / tan(half)
    fun p(q: V3): Offset? {
        val d = q - e; val z = d.dot(f)
        if (z < .05) return null
        return Offset((w / 2 + d.dot(r) / z * foc).toFloat(), (h / 2 - d.dot(u) / z * foc).toFloat())
    }
    private fun cr(a: V3, b: V3) = V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

/** The sample room the gallery and the steps show a layout in: [laid] its tiles, which walls stand, and a bath or worktop. */
class TPreview(val l: TileLayout, val g: TRoomGeo, val laid: Laid, val floorTiled: Boolean, val bath: TFix?, val counter: Boolean)

private val SAMPLE = Room("sample", "", "", dims = mapOf("A" to Dim(3200), "B" to Dim(2600), "H" to Dim(2400), "T" to Dim(120, "default")))

/** The surfaces a layout of [place] shows in the sample room: the floor, the two far walls, the backsplash band, the bath's front. */
fun sampleSurfs(l: TileLayout): List<TSurf> {
    val m = tModel(l.model)
    val surf = when {
        l.place == "floor" -> "floor"
        l.place == "apron" -> "apron"
        m?.surf == "floor" -> "floor"
        l.surfs.isNotEmpty() && l.surfs.all { it.id == "floor" } -> "floor"
        else -> "walls"
    }
    return when (surf) {
        "floor" -> listOf(TSurf("floor"))
        "apron" -> listOf(TSurf("A", "band", APRON_H0, APRON_H1))
        else -> listOf(TSurf("A"), TSurf("D", alt = l.accent)) + (if (l.place == "bath") listOf(TSurf("bath:b")) else emptyList())
    }
}

fun previewOf(l0: TileLayout): TPreview {
    val bath = if (l0.place == "bath") TFix("b", "bath", "A", 0, 1700, 700, 560) else null
    val g = roomGeo(SAMPLE, true, listOfNotNull(bath))!!
    val l = l0.copy(surfs = sampleSurfs(l0), roomId = "sample", ox = 0, oy = 0, align = false)
    val laid = layAll(l, surfacesOf(l, g), g, null, drawInset(l))
    return TPreview(l, g, laid, l.surfs.any { it.id == "floor" }, bath, l0.place == "apron")
}

private const val WALL_RGB = 0xEEF0F3
private const val FLOOR_RGB = 0xE2E6EC

/** Draws a sample room's corner with the layout on it; [az] turns the view a little (a drag). */
fun DrawScope.drawPreview(pv: TPreview, az: Float = 0f, textures: Boolean = true, cutK: Double = .15) {
    drawRect(Color(0xFFF6F8FC))
    val g = pv.g
    val L = 3.2 + .12; val W = 2.6; val H = 2.4
    val a = .78 + az
    val dist = 5.2
    val tgt = V3(L * .42, if (pv.l.place == "floor" || pv.floorTiled) .2 else H * .42, W * .4)
    val eye = V3(tgt.x + dist * cos(a) * .95, tgt.y + (if (pv.floorTiled) 3.4 else 1.5), tgt.z + dist * sin(a) * .95)
    val cam = TCam(eye, tgt, size.width, size.height, if (pv.floorTiled) .37 else .41)
    val fl = g.floorFrame
    fun quad(pts: List<V3>, c: Color) { val o = pts.map { cam.p(it) ?: return }; drawPath(pathOf(o), c) }
    // the floor, and the far walls A and D
    quad(g.floor.map { fl.at(it.x, it.y) }, rgbColor(FLOOR_RGB))
    listOf("A", "D").forEach { id ->
        val w = g.wall(id) ?: return@forEach
        val fr = g.wallFrame(w)
        quad(listOf(fr.at(0.0, 0.0), fr.at(w.len, 0.0), fr.at(w.len, g.H), fr.at(0.0, g.H)), rgbColor(if (id == "A") WALL_RGB else scaleRgb(WALL_RGB, .96)))
    }
    // a mosaic (thousands of small tiles) is filled flat, so a drag stays smooth
    if (pv.laid.pieces.size > MAX_DRAWN_2D) drawLaidCapped(pv.laid, pv.l, { s -> { q -> cam.p(s.frame.at(q.x, q.y, .002)) } })
    else drawLaid(pv.laid, pv.l, { s -> { q -> cam.p(s.frame.at(q.x, q.y, .002)) } }, textures, cutK, outline = true)
    // the corner's line
    g.wall("A")?.let { w -> val fr = g.wallFrame(w); val p0 = cam.p(fr.at(0.0, 0.0)); val p1 = cam.p(fr.at(0.0, g.H)); if (p0 != null && p1 != null) drawLine(Color(0x33101828), p0, p1, density) }
    // a bath, or the worktop and the units under it
    val box = pv.bath?.let { f -> footprint(g, f)?.let { it to f.h.toDouble() } }
        ?: if (pv.counter) g.wall("A")?.let { w -> listOf(w.at(0.0), w.at(w.len), w.at(w.len, 600.0), w.at(0.0, 600.0)) to (APRON_H0 - 40.0) } else null
    if (box != null) {
        val (fp, h) = box
        val sc = fp.map { g.scene(it) }
        val top = sc.map { V3(it.x, h / 1000, it.z) }
        val cx = sc.sumOf { it.x } / 4; val cz = sc.sumOf { it.z } / 4
        for (i in sc.indices) {
            val p = sc[i]; val q = sc[(i + 1) % 4]
            var nx = q.z - p.z; var nz = -(q.x - p.x)
            if (((p.x + q.x) / 2 - cx) * nx + ((p.z + q.z) / 2 - cz) * nz < 0) { nx = -nx; nz = -nz }
            if (nx * (eye.x - p.x) + nz * (eye.z - p.z) <= 0) continue
            // the bath's front is tiled (its tiles are drawn on it below)
            quad(listOf(p, q, V3(q.x, h / 1000, q.z), V3(p.x, h / 1000, p.z)), rgbColor(if (pv.counter) 0xE9E7E2 else 0xF4F4F1))
        }
        quad(top, rgbColor(if (pv.counter) 0x8E7962 else 0xFBFBFA))
        if (pv.counter) quad(top.map { V3(it.x, h / 1000 + .04, it.z) }, rgbColor(0x9C8670))
        // a bath's front panel with its tiles, again over the box
        val front = pv.laid.surfs.indexOfFirst { it.kind == "bath" }
        if (front >= 0) {
            val s = pv.laid.surfs[front]
            val sub = Laid(listOf(s), pv.laid.pieces.filter { it.s == front }.map { Piece(it.polys, it.area, it.full, it.prod, it.pw, it.ph, it.rectish, it.c, it.vert, it.seed, 0) }, emptySet())
            drawLaid(sub, pv.l, { ss -> { q -> cam.p(ss.frame.at(q.x, q.y, .003)) } }, textures, cutK, outline = true)
        }
    }
}

/** A layout's picture as a still image (the gallery's cards). */
fun previewPicture(l: TileLayout, w: Int, h: Int, density: Float): ImageBitmap {
    val img = ImageBitmap(w, h)
    val pv = previewOf(l)
    CanvasDrawScope().draw(Density(density), LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(img), Size(w.toFloat(), h.toFloat())) { drawPreview(pv, cutK = 0.0) }
    return img
}

/** The gallery's pictures, made once from the app's own drawing of each card's layout. */
object TilePics {
    val pics = mutableStateMapOf<String, ImageBitmap>()
    suspend fun make(w: Int, h: Int, density: Float) {
        for (m in T_MODELS) {
            if (pics[m.id] != null) continue
            val img = withContext(Dispatchers.Default) { runCatching { previewPicture(layoutOf(m, m.id), w, h, density) }.getOrNull() }
            if (img != null) pics[m.id] = img
        }
    }
}

/** The layout live in the sample room: a drag turns it a little. */
@Composable
fun PreviewView(pv: TPreview, modifier: Modifier) {
    var az by remember { mutableFloatStateOf(0f) }
    Canvas(modifier.pointerInput(Unit) { detectHorizontalDragGestures { ch, dx -> ch.consume(); az = (az - dx / 400f).coerceIn(-.55f, .55f) } }) { drawPreview(pv, az) }
}

/** A tile's look as a swatch: four tiles with their joints. */
@Composable
fun LookSwatch(id: String, modifier: Modifier) {
    val lk = lookOf(id)
    Canvas(modifier) {
        drawRect(rgbColor(groutOf(lk.rgb)))
        val g = 2 * density; val n = 2
        val s = (size.width - g * (n - 1)) / n
        for (i in 0 until n) for (k in 0 until n) {
            val x0 = i * (s + g); val y0 = k * (s + g)
            drawRect(rgbColor(toneOf(lk, i * 3 + k)), Offset(x0, y0), Size(s, s))
            texture(lk, i * 5 + k * 11 + 3, { a, b -> Offset(x0 + a * s, y0 + b * s) }, density)
        }
    }
}
