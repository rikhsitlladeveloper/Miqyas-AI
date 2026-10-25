package uz.metrx.app.geo

import uz.metrx.app.furniture.Board
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.GK_FACING
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Surface
import uz.metrx.app.furniture.TV_PANEL
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.chairPlaces
import uz.metrx.app.furniture.gorkaRoles
import uz.metrx.app.furniture.innerD
import uz.metrx.app.furniture.itemBoards
import uz.metrx.app.furniture.lookOf
import uz.metrx.app.furniture.tvSize
import uz.metrx.app.furniture.wardBase
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * The gorka's and the big dining table's 3D in the lit style (modern 3D part 6a; the approved mockup's buildGorka):
 * what Furniture3D.kt draws over a gorka's boxes (LED strips up its glass towers, under the floating base and the
 * bridge; dishes on the glass shelves; the neoclassic cornice), and the TV panel and the big table drawn here whole
 * (the panel's stone slab, wood slats or mouldings with a black-glass TV and its faintly lit screen; the table's
 * stone-look or wood top, its legs, the upholstered chairs in the look's fabric, a bowl, a vase and a linear pendant).
 * Each box is in its wall's frame, mm; equal looks become one part. The small decor (dishes, books, vases, the pendant)
 * is left out on the light tier ([decor] false). Pure Kotlin, unit-tested (GorkaTest).
 */

/**
 * A box of these: [a0]..[a1] along the wall, [y0]..[y1] up, [n0]..[n1] out from it, mm; drawn in [look], else in the
 * piece's board of [role] (its highlight from the parts list named [key]); [line] its outline; turned [rotN] degrees
 * in the wall's plane (an upright plate) or [rotY] about the upright (a bowl) round its middle; [up] its grain upright.
 */
class XBox(val a0: Double, val a1: Double, val y0: Double, val y1: Double, val n0: Double, val n1: Double, val look: Look? = null,
           val role: String = "front", val key: String = "", val line: Boolean = false, val rotN: Double = 0.0, val rotY: Double = 0.0, val up: Boolean = false)

/** What these add to a module ([own] false: drawn over its usual boxes) or draw instead of it ([own] true). */
class Guest3D(val own: Boolean, val boxes: List<XBox>)

/** The TV's screen: dark, faintly lit. */
val TV_SCREEN = Look(0x1D2A3E, rough = .08f, clear = 1f, emissive = .45f, reflect = .6f)
/** Porcelain (dishes, vases), books, the slats' dark backing. */
val PORCELAIN = Look(0xF4F2EE, rough = .25f, clear = .6f, reflect = .55f)
private val BOOKS = listOf(Look(0x2E3A52, rough = .7f), Look(0xD8CDBB, rough = .7f), Look(0x7A2E2E, rough = .7f))
private val SLAT_BACK = Look(0x1B1C1F, rough = .8f)

/** The bundled picture a decor's texture id stands for (Look.kt TEX_IDS; the iPhone's texSource table); null none. */
fun texFile(id: String?): String? = when (id) {
    null -> null
    "oak_light", "oak_tobacco" -> "oak_halifax"
    "oak_golden" -> "oak_craft"
    "oak_dark" -> "wenge"
    "onyx_beige" -> "travertine"
    "tile_white" -> "tile_subway"
    "boucle" -> "fabric_boucle"
    "velvet", "fabric" -> "fabric_weave"
    else -> id.takeIf { it in TEXTURES }
}

private fun rgbNum(s: String): Int = s.removePrefix("#").toLongOrNull(16)?.toInt()?.and(0xFFFFFF) ?: 0xCDBFAE

/** How the lit 3D draws a design's surface (furniture/Look.kt lookOf). */
fun surfaceLook(s: Surface): Look {
    val rgb = rgbNum(s.rgb); val tex = texFile(s.tex)
    return when (s.finish) {
        "gloss" -> Looks.board(rgb, tex, "gloss")
        "stone" -> Looks.worktop(rgb, tex)
        "glass" -> Looks.clearGlass
        "mirror" -> Looks.mirror.copy(rgb = rgb)
        "metal" -> Look(rgb, rough = .3f, metal = 1f)
        "fabric" -> Look(rgb, rough = .92f, tex = tex ?: "fabric_weave", tint = true, reflect = .3f)
        "velvet" -> Look(rgb, rough = .55f, tex = "fabric_weave", tint = true, reflect = .45f)
        "led" -> Looks.led
        else -> Looks.board(rgb, tex)
    }
}

private fun lk(f: Furniture, m: Module?, part: String) = surfaceLook(lookOf(f, m, part))

/** The gorka's or the big table's 3D for module [m] of [f] (its frame's x already in [m]); null for any other. */
fun guest3D(f: Furniture, m: Module, ws: Workshop, decor: Boolean = true): Guest3D? = when {
    m.type == TV_PANEL -> Guest3D(true, tvPanel(f, m, ws))
    m.type == "table" && (m.opt?.seats ?: 0) > 0 -> Guest3D(true, bigTable(f, m, ws, decor))
    f.type == "gorka" && m.type == "wardrobe" -> gorkaBox(f, m, ws, decor).takeIf { it.isNotEmpty() }?.let { Guest3D(false, it) }
    else -> null
}

/** A board of an item at [x0] along the wall, in [look] or in its role's board. */
private fun board(b: Board, x0: Int, look: Look? = null) = XBox((x0 + b.a0).toDouble(), (x0 + b.a1).toDouble(), b.y0.toDouble(), b.y1.toDouble(), b.n0.toDouble(), b.n1.toDouble(),
    look, if (b.role == "carcass") "carcass" else "front", b.key, line = true)

/** A disc [dd] across and [th] thick as three turned squares: upright in the wall's plane ([upright]) or lying flat. */
private fun disc(out: MutableList<XBox>, ca: Double, cy: Double, cn: Double, dd: Double, th: Double, upright: Boolean, look: Look) {
    val s = dd * .8
    listOf(0.0, 30.0, 60.0).forEach { r ->
        out += if (upright) XBox(ca - s / 2, ca + s / 2, cy - s / 2, cy + s / 2, cn - th / 2, cn + th / 2, look, rotN = r)
            else XBox(ca - s / 2, ca + s / 2, cy - th / 2, cy + th / 2, cn - s / 2, cn + s / 2, look, rotY = r)
    }
}

/** What goes over a gorka's box: its LED strips, the dishes on a tower's shelves, the cornice on a tower or the bridge. */
fun gorkaBox(f: Furniture, m: Module, ws: Workshop, decor: Boolean): List<XBox> {
    val r = gorkaRoles(f) ?: return emptyList()
    val out = ArrayList<XBox>()
    val t = ws.t.toDouble()
    val x0 = m.x.toDouble(); val x1 = x0 + m.w
    val sl = if (m.sideL) t else 0.0; val sr = if (m.sideR) t else 0.0
    val led = f.look?.led == true
    val yb = (m.elev + wardBase(m)).toDouble(); val yt = (m.elev + m.h).toDouble()
    val di = innerD(m).toDouble()
    val tower = r.ups.any { it.id == m.id }
    when {
        tower -> {
            // the light up each side of the glass box, at its front
            if (led) {
                out += XBox(x0 + sl + 4, x0 + sl + 12, yb + t, yt - t, di - 40, di - 32, Looks.led)
                out += XBox(x1 - sr - 12, x1 - sr - 4, yb + t, yt - t, di - 40, di - 32, Looks.led)
                // their warm light on the glass box's back, brightest at the top (mockup's lights in the towers; none on the light tier)
                if (decor) glow(out, x0 + sl, x1 - sr, yt - t, (yt - yb - 2 * t) / GK_GLOW.size, 8.0)
            }
            if (decor && m.sections.size == 1) dishes(out, m, x0 + sl, x1 - sr, yb + t, yt - t, t)
        }
        m.id == r.base?.id -> {
            if (led) out += XBox(x0 + 40, x1 - 40, m.elev - 6.0, m.elev.toDouble(), m.d - 60.0, m.d - 48.0, Looks.led)
            // and its glow on the wall under the floating base (mockup)
            if (led && decor && m.elev > 40) glow(out, x0 + 20, x1 - 20, m.elev.toDouble(), m.elev / GK_GLOW.size.toDouble(), 3.0)
            // a vase and a few books on the base
            if (decor && m.w >= 900) {
                val top = yt
                out += XBox(x0 + 250, x0 + 350, top, top + 220, m.d / 2.0 - 50, m.d / 2.0 + 50, PORCELAIN, line = false)
                BOOKS.forEachIndexed { i, b -> out += XBox(x1 - 420 + i * 30.0, x1 - 394 + i * 30.0, top, top + 200 + i * 15, m.d / 2.0 - 80, m.d / 2.0 + 80, b) }
            }
        }
        m.id == r.bridge?.id -> if (led) {
            out += XBox(x0 + 30, x1 - 30, m.elev - 7.0, m.elev.toDouble(), m.d - 60.0, m.d - 48.0, Looks.led)
            // its glow down the TV panel under it, 500 mm (mockup), just in front of the panel's face
            if (decor) glow(out, x0 + 80, x1 - 80, m.elev.toDouble(), 500.0 / GK_GLOW.size, t + GK_FACING + 1)
        }
    }
    // the neoclassic cornice: three stepped mouldings over each tower and the bridge, in the fronts' board
    if (f.look?.crown == "cornice" && (tower || m.id == r.bridge?.id)) {
        val d = m.d.toDouble()
        out += XBox(x0 - 5, x1 + 5, yt, yt + 22, 0.0, d + 10, role = "front", line = true)
        out += XBox(x0 - 15, x1 + 15, yt + 22, yt + 58, 0.0, d + 26, role = "front", line = true)
        out += XBox(x0 - 25, x1 + 25, yt + 58, yt + 76, 0.0, d + 38, role = "front", line = true)
    }
    return out
}

/** The see-through of a LED's glow bands, from the strip outwards (as the kitchen's GLOW in Furniture3D.kt). */
private val GK_GLOW = listOf(.22f, .17f, .13f, .10f, .07f, .05f, .03f, .015f)

/** A LED's soft glow over [a0]..[a1] from [top] down, [GK_GLOW] bands [band] mm each, a millimetre thin at [n] out from the wall. */
private fun glow(out: MutableList<XBox>, a0: Double, a1: Double, top: Double, band: Double, n: Double) {
    if (a1 - a0 < 1 || band < 1) return
    GK_GLOW.forEachIndexed { i, a -> out += XBox(a0, a1, top - (i + 1) * band, top - i * band, n, n + 1, Looks.glow(a)) }
}

/** Dishes on a tower's floor and shelves ([a0]..[a1] inside, [y0]..[y1] its floor to its top): plates and cups, bowls and a teapot, a vase on top. */
private fun dishes(out: MutableList<XBox>, m: Module, a0: Double, a1: Double, y0: Double, y1: Double, t: Double) {
    if (a1 - a0 < 300) return
    val cx = (a0 + a1) / 2
    val shelves = m.sections[0].inserts.filter { it.kind == "glass" || it.kind == "shelf" }.map { y0 + it.pos + if (it.kind == "glass") 6.0 else t }.sorted()
    val levels = listOf(y0) + shelves
    levels.forEachIndexed { i, y ->
        val room = (levels.getOrNull(i + 1) ?: y1) - y
        if (room < 160) return@forEachIndexed
        when {
            i == levels.lastIndex -> out += XBox(cx - 55, cx + 55, y, y + min(280.0, room - 40), 140.0, 250.0, PORCELAIN)
            i % 2 == 0 -> {
                // three plates standing at the back, two cups in front of them
                val dd = min(220.0, room - 30)
                listOf(-120.0 to .9, 0.0 to 1.0, 120.0 to .9).forEach { (dx, k) -> disc(out, cx + dx, y + dd * k / 2 + 2, 50.0, dd * k, 8.0, true, PORCELAIN) }
                listOf(-100.0, 100.0).forEach { dx -> out += XBox(cx + dx - 35, cx + dx + 35, y, y + 75, 200.0, 270.0, PORCELAIN) }
            }
            else -> {
                // a stack of two bowls and a teapot
                disc(out, cx - 100, y + 30, 170.0, 180.0, 60.0, false, PORCELAIN)
                disc(out, cx - 100, y + 82, 170.0, 160.0, 44.0, false, PORCELAIN)
                if (room > 220) out += XBox(cx + 30, cx + 160, y, y + 120, 120.0, 250.0, PORCELAIN)
            }
        }
    }
}

/**
 * A kitchen vitrina's glass shelves (Kitchen.kt glassDoors), mm above the floor of the shelf's underside: spaced
 * evenly in the box as its board shelves would be (the 3D's kitchen unit).
 */
fun vitrinaShelves(m: Module, t: Int): List<Double> {
    val n = m.inserts.filter { it.kind == "glass" }.sumOf { it.qty }
    return (1..n).map { k -> m.elev + (m.h - t) * k / (n + 1.0) }
}

/**
 * The dishes in a kitchen vitrina (mockup buildKitchen): plates standing at the back of its floor (up to three, 170 mm
 * apart) and cups on its first glass shelf (up to four, 130 mm apart), each where there is room. The light tier has none.
 */
fun vitrinaDishes(m: Module, t: Int): List<XBox> {
    val out = ArrayList<XBox>()
    val il = m.x + t.toDouble(); val iw = m.w - 2.0 * t
    if (iw < 250) return out
    val cx = il + iw / 2
    val floor = m.elev + t.toDouble(); val top = m.elev + m.h - t.toDouble()
    val ys = vitrinaShelves(m, t)
    val room = (ys.firstOrNull() ?: top) - floor
    if (room >= 160) {
        val dd = min(200.0, room - 40); val np = ((iw - 40) / 170).toInt().coerceIn(1, 3)
        for (i in 0 until np) disc(out, cx + (i - (np - 1) / 2.0) * 170, floor + dd / 2 + 2, 50.0, dd, 8.0, true, PORCELAIN)
    }
    ys.firstOrNull()?.let { y ->
        val ys0 = y + 6; val up = (ys.getOrNull(1) ?: top) - ys0
        if (up >= 110) {
            val nc = ((iw - 40) / 130).toInt().coerceIn(1, 4)
            for (i in 0 until nc) { val c = cx + (i - (nc - 1) / 2.0) * 130; out += XBox(c - 35, c + 35, ys0, ys0 + 75, 115.0, 185.0, PORCELAIN) }
        }
    }
    return out
}

/** The TV panel: its board, the facing over it (stone, slats or mouldings), the TV. */
fun tvPanel(f: Furniture, m: Module, ws: Workshop): List<XBox> {
    val out = ArrayList<XBox>()
    val t = ws.t.toDouble()
    val o = m.opt ?: uz.metrx.app.furniture.Opt()
    itemBoards(m, ws).forEach { out += board(it, m.x) }
    val x0 = m.x.toDouble(); val x1 = x0 + m.w; val e = m.elev.toDouble(); val top = e + m.h
    when (o.panel) {
        "slats" -> {
            // wood slats about 45 mm apart over a dark backing (the accent wood; walnut without one)
            val wood = if (f.look?.accent.isNullOrEmpty()) lk(f.copy(look = (f.look ?: uz.metrx.app.furniture.Look()).copy(accent = "wd_walnut")), m, "accent") else lk(f, m, "accent")
            out += XBox(x0, x1, e, top, t, t + 4, SLAT_BACK)
            val n = max(1, (m.w / 45.0).roundToInt()); val s = m.w.toDouble() / n
            for (i in 0 until n) out += XBox(x0 + i * s + 6, x0 + (i + 1) * s - 6, e, top, t, t + GK_FACING, wood, up = true)
        }
        "mould" -> {
            // a moulded frame set in from the panel's edges, in the fronts' board
            val i = 60.0; val b = 40.0; val d = t + 14
            out += XBox(x0 + i, x1 - i, top - i - b, top - i, t, d, role = "front", line = true)
            out += XBox(x0 + i, x1 - i, e + i, e + i + b, t, d, role = "front", line = true)
            out += XBox(x0 + i, x0 + i + b, e + i + b, top - i - b, t, d, role = "front", line = true)
            out += XBox(x1 - i - b, x1 - i, e + i + b, top - i - b, t, d, role = "front", line = true)
        }
        else -> out += XBox(x0, x1, e, top, t, t + GK_FACING - 2, lk(f, m, "worktop"), line = true)
    }
    // the TV on the panel, no wider than it less 40 mm, its middle about 1210 from the floor
    val (tw0, th0) = tvSize(o.tv.takeIf { it > 0 } ?: 65)
    val k = min(1.0, (m.w - 40.0) / tw0)
    val tw = tw0 * k; val th = th0 * k
    val cx = (x0 + x1) / 2; val cy = min(e + min(m.h.toDouble(), 1160.0) / 2 + 10, top - th / 2 - 20)
    val n0 = t + GK_FACING
    out += XBox(cx - tw / 2 - 10, cx + tw / 2 + 10, cy - th / 2 - 10, cy + th / 2 + 10, n0, n0 + 28, Looks.blackGlass)
    out += XBox(cx - tw / 2, cx + tw / 2, cy - th / 2, cy + th / 2, n0 + 28, n0 + 29.5, TV_SCREEN)
    return out
}

/** The big table: its top in the stone or wood look, its legs, the chairs round it; on the full tier a bowl, a vase and the pendant over it. */
fun bigTable(f: Furniture, m: Module, ws: Workshop, decor: Boolean): List<XBox> {
    val out = ArrayList<XBox>()
    val metal = lk(f, m, "legs")
    itemBoards(m, ws).forEach { b ->
        out += when (b.role) {
            "top" -> board(b, m.x, lk(f, m, "worktop"))
            "metal" -> board(b, m.x, metal)
            else -> board(b, m.x)
        }
    }
    val x0 = m.x.toDouble(); val H = m.h.toDouble(); val D = m.d.toDouble()
    val fabric = lk(f, m, "fabric")
    // the chairs' legs: metal with metal table legs, else the wood accent (walnut without one)
    val legs = if (m.opt?.legs == "board") (if (f.look?.accent.isNullOrEmpty()) Looks.board(0x634330, "walnut") else lk(f, m, "accent")) else metal
    chairPlaces(m).forEach { c -> chair(out, x0 + c.a, c.n.toDouble(), c.face, fabric, legs) }
    if (decor) {
        val cx = x0 + m.w / 2.0; val cn = D / 2
        disc(out, cx - 200, H + 40, cn, 280.0, 80.0, false, PORCELAIN)
        out += XBox(cx + 300, cx + 400, H, H + 300, cn - 50, cn + 50, PORCELAIN)
        // a linear pendant 900 over the top, on two short wires (the room has no ceiling to hang them from, and a
        // gallery card fits its picture round every box)
        val handle = lk(f, m, "handle")
        out += XBox(cx - 800, cx + 800, H + 900, H + 932, cn - 30, cn + 30, handle, line = true)
        out += XBox(cx - 780, cx + 780, H + 896, H + 900, cn - 20, cn + 20, Looks.led)
        listOf(-700.0, 700.0).forEach { dx -> out += XBox(cx + dx - 1.5, cx + dx + 1.5, H + 932, H + 1250, cn - 1.5, cn + 1.5, Looks.blackGlass) }
    }
    return out
}

/** An upholstered chair with its middle [ca], [cn] looking [face] (+n, -n, +a, -a): its seat, back and four legs. */
private fun chair(out: MutableList<XBox>, ca: Double, cn: Double, face: String, fabric: Look, legs: Look) {
    val h = 220.0
    out += XBox(ca - h, ca + h, 420.0, 495.0, cn - h, cn + h, fabric)
    listOf(-180.0, 180.0).forEach { da -> listOf(-180.0, 180.0).forEach { dn -> out += XBox(ca + da - 11, ca + da + 11, 0.0, 420.0, cn + dn - 11, cn + dn + 11, legs) } }
    out += when (face) {
        "+n" -> XBox(ca - 210, ca + 210, 495.0, 980.0, cn - h, cn - h + 55, fabric)
        "-n" -> XBox(ca - 210, ca + 210, 495.0, 980.0, cn + h - 55, cn + h, fabric)
        "+a" -> XBox(ca - h, ca - h + 55, 495.0, 980.0, cn - 210, cn + 210, fabric)
        else -> XBox(ca + h - 55, ca + h, 495.0, 980.0, cn - 210, cn + 210, fabric)
    }
}
