package uz.metrx.app.geo

import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.LONG_V
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.crownOf
import uz.metrx.app.furniture.handleType
import uz.metrx.app.furniture.isUpperFront
import uz.metrx.app.furniture.lookOf
import uz.metrx.app.furniture.metalLegs
import uz.metrx.app.furniture.splashOf
import uz.metrx.app.furniture.waterfallEnds
import uz.metrx.app.furniture.worktopOf
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.K_BASE_D
import uz.metrx.app.furniture.K_TOP
import uz.metrx.app.furniture.K_WALL_D
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.PLINTH
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.blockH
import uz.metrx.app.furniture.fillOf
import uz.metrx.app.furniture.frontSizes
import uz.metrx.app.furniture.isUpper
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.wardBase
import uz.metrx.app.furniture.wardInner
import uz.metrx.app.furniture.worktopTop
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/*
 * Furniture in the room's 3D scene (furniture plan section 9): every board a box in its material's colour, on its
 * wall's frame ([WallBasis]). Doors swing open about 100°, drawers pull out; [Furn3D.picks] are what a tap can open.
 * Sizes come in millimetres and go out in metres. Given the looks (the lit 3D, modern 3D part 3, 25 Oct 2026) a
 * kitchen is drawn as the approved mockup draws it (scratchpad modern3d/modern-3d.html buildKitchen): flat, milled
 * (shaker) or fluted fronts, real handles by type, the Gola profile, a worktop with a rounded edge and a sink cut into
 * it, skinali, LED light, a hidden plinth or metal legs, a cornice or a row up to the ceiling, the island's waterfall;
 * without them (the 2D painter, PieceView) the boxes are as they were, six faces each.
 */

/** A box with corner [o] and edges [a], [b], [c] (perpendicular, not necessarily unit length). */
class Obb(val o: V3, val a: V3, val b: V3, val c: V3) {
    fun corners(): List<V3> = listOf(o, o + a, o + a + c, o + c, o + b, o + a + b, o + a + b + c, o + b + c)

    /** Where a ray from [e] along [d] first enters the box (its distance), or null. */
    fun hit(e: V3, d: V3): Double? {
        var t0 = 0.0; var t1 = Double.MAX_VALUE
        for (ax in listOf(a, b, c)) {
            val l2 = ax.dot(ax); if (l2 < 1e-12) return null
            // the box is 0..1 along each edge: (p - o)·ax / |ax|²
            val p = (e - o).dot(ax) / l2; val v = d.dot(ax) / l2
            if (kotlin.math.abs(v) < 1e-12) { if (p < 0 || p > 1) return null; continue }
            var ta = (0 - p) / v; var tb = (1 - p) / v
            if (ta > tb) { val x = ta; ta = tb; tb = x }
            t0 = max(t0, ta); t1 = min(t1, tb); if (t0 > t1) return null
        }
        return t0
    }
}

/** Something a tap opens: a door or a drawer ([key]), where it is now. */
class Pick(val key: String, val box: Obb)

class Furn3D(val parts: List<Part>, val edges: List<Edges>, val picks: List<Pick>, val keys: List<String>,
             /** Where each front's handle was put (the lit 3D only), by its door or drawer key. */
             val spots: Map<String, HandleSpot> = emptyMap(),
             /**
              * Built with split: each door, drawer, sliding door, rack and lift-up base on its own, shut, with how it
              * moves ([parts], [edges] and [picks] are then the rest, which stays put); else empty.
              */
             val fronts: List<Front3D> = emptyList(),
             /** Built with split: what is drawn one way while a door is open and another while shut (a wardrobe's LED). */
             val toggles: List<Toggle3D> = emptyList())

/**
 * A handle on a front, in the front's own frame (mm from its corner at the hinge side and the bottom): the middle
 * [u] across, [v] up; [len] its length; [vertical] along the front's height; a [knob].
 */
data class HandleSpot(val u: Double, val v: Double, val len: Double, val vertical: Boolean, val knob: Boolean = false)

/** The recess a Gola profile leaves over a front, mm (mockup: the fronts stop 34 mm under the worktop). */
const val GOLA_GAP = 34

/**
 * Where the handle of [type] ("bar", "long", "knob"; "gola" and "push" none: null) and hardware id [id] goes on a front
 * [w] x [h] mm: a door's ([kind] "door") near its opening edge, at the top of a base unit's ([pos] "top"), the bottom
 * of a wall unit's ("bottom"), round [mid] on a tall one ("mid"); a drawer's across its middle near its top; a lift-up
 * flap's along its bottom (the mockup's b.handle). A bar is the 128 skoba (168 long); long verticals 1024 on doors of
 * 1400 and more, 640 from 700, else 320, and 320 on drawers (Look.kt longHandleIds); none longer than a door less 60
 * or a drawer less 80.
 */
fun handleSpot(type: String, id: String, kind: String, pos: String, w: Double, h: Double, mid: Double = h / 2): HandleSpot? {
    if (type != "bar" && type != "long" && type != "knob") return null
    val across = kind == "drawer" || kind == "flap"
    if (type == "knob") return when {
        kind == "drawer" -> HandleSpot(w / 2, h - min(60.0, h / 2), 0.0, false, true)
        kind == "flap" -> HandleSpot(w / 2, min(60.0, h / 2), 0.0, false, true)
        else -> HandleSpot(w - min(42.0, w / 2), when (pos) { "bottom" -> min(70.0, h / 2); "top" -> h - min(70.0, h / 2); else -> mid.coerceIn(min(70.0, h / 2), max(h / 2, h - 70)) }, 0.0, true, true)
    }
    var len = when {
        type == "bar" -> 168.0
        id == "handle1024" -> 1024.0
        id == "handle640" -> 640.0
        id == LONG_V && !across -> if (h >= 1400) 1024.0 else if (h >= 700) 640.0 else 320.0
        else -> 320.0
    }
    if (across) {
        len = min(len, w - 80)
        if (len < 40) return null
        return HandleSpot(w / 2, if (kind == "flap") min(45.0, h / 2) else h - min(50.0, h / 2), len, false)
    }
    len = min(len, h - 60)
    if (len < 40) return null
    val lo = 45 + len / 2; val hi = max(lo, h - 45 - len / 2)
    return HandleSpot(w - min(34.0, w / 2), when (pos) { "bottom" -> lo; "top" -> hi; else -> mid.coerceIn(lo, hi) }, len, true)
}

/**
 * The Gola channels the 3D draws on box [m] of a Gola kitchen: one under the worktop (over a blind corner's panel too,
 * so the line runs on), one over each drawer, two round a built-in oven.
 */
fun golaChannels(m: Module): Int = when {
    isUpper(m) -> 0
    m.type == "gap" -> if (m.app == "dishwasher") 1 else 0
    m.type == "base" -> when (m.fronts.kind) { "drawer" -> m.fronts.n.coerceAtLeast(1); "door", "panel" -> 1; else -> 0 }
    m.type == "tall" && m.app == "oven" && m.fronts.kind == "door" && m.fronts.n == 1 -> 2
    else -> 0
}

/** A sink's cut-out in the worktop over box [m]: from, to along the wall; from, to out from it (mm). */
internal fun sinkHole(m: Module): DoubleArray {
    val cx = m.x + m.w / 2.0; val hw = min(max(300.0, m.w * .6), m.w - 120.0)
    return doubleArrayOf(cx - hw / 2, cx + hw / 2, 100.0, 480.0)
}

private const val METAL = 0xC5CBD4
private const val DARK = 0x1E293B
private const val HANDLE = 0x4B5563
private const val WHITE = 0xE8EAEE
private const val OPEN_DEG = 100.0
/** A door with a wall, another piece or a door beside its hinge stops at a right angle, not swinging into it. */
private const val SHUT_DEG = 90.0
private const val MIRROR = 0xC9D3DD
private const val GLASS_P = 0x8FA9C4
/** A vitrina's clear glass, seen through; a bed's mattress and slats; an LED strip's light. */
private const val CLEAR = 0xBFD8E8
private const val MATTRESS = 0xF1F3F6
private const val LAMEL = 0xD9C29A
private const val LED = 0xFFF3C4
/** The see-through of the LED glow's bands on the wall, from the wall units' bottom down (40 mm each). */
private val GLOW = listOf(.22f, .17f, .13f, .10f, .07f, .05f, .03f, .015f)
/** The same inside a wardrobe, from its LED down the back (70 mm each) and on the shelves under it: brighter, the light close by. */
private val WGLOW = listOf(.34f, .27f, .21f, .16f, .12f, .08f, .05f, .025f)
private val UP = V3(0.0, 1.0, 0.0)

/**
 * The faces of a box, each facing out, with texture coordinates in metres: u along the grain, which runs along
 * [grain] (one of the box's edges, or a direction) or else the box's longest edge (a board's long side).
 */
private fun obbFaces(p: Part, x: Obb, grain: V3? = null, fit: Boolean = false, org: V3? = null) {
    val ctr = x.o + (x.a + x.b + x.c) * .5
    val g = (grain ?: listOf(x.a, x.b, x.c).maxBy { it.len() }).unit()
    // a picture laid once over its panel starts at its corner; boards each at their own place in the grain
    val o0 = org ?: x.o
    val (offU, offV) = if (fit) 0.0 to 0.0 else grainOffset(o0)
    fun along(e: V3) = kotlin.math.abs(e.unit().dot(g)) > .99
    fun face(q: List<V3>, e1: V3, e2: V3) {
        val fc = V3(q.sumOf { it.x } / 4, q.sumOf { it.y } / 4, q.sumOf { it.z } / 4)
        var n = (q[1] - q[0]).let { u -> (q[3] - q[0]).let { v -> V3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x) } }.unit()
        if (n.dot(fc - ctr) < 0) n = n * -1.0
        // the grain along the face's edge that follows it, else along its longer edge (a board's end)
        val first = along(e1) || (!along(e2) && e1.len() >= e2.len())
        val ua = (if (first) e1 else e2).unit(); val va = (if (first) e2 else e1).unit()
        p.faces += Face(n, q, uv = uvOf(q, o0, ua, va, offU, offV))
    }
    val o = x.o; val a = x.a; val b = x.b; val c = x.c
    face(listOf(o, o + a, o + a + b, o + b), a, b); face(listOf(o + c, o + c + a, o + c + a + b, o + c + b), a, b)
    face(listOf(o, o + c, o + c + b, o + b), c, b); face(listOf(o + a, o + a + c, o + a + c + b, o + a + b), c, b)
    face(listOf(o, o + a, o + a + c, o + c), a, c); face(listOf(o + b, o + b + a, o + b + a + c, o + b + c), a, c)
}

private fun cross(u: V3, v: V3) = V3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)

/**
 * The faces of a prism: the convex polygon [base] (its points in order) pushed along [ext]; its sides' texture u
 * along [ext] (the lit 3D only: not six faces a box).
 */
private fun prismFaces(p: Part, base: List<V3>, ext: V3) {
    val n = base.size; if (n < 3) return
    val ctr = V3(base.sumOf { it.x } / n, base.sumOf { it.y } / n, base.sumOf { it.z } / n) + ext * .5
    val (offU, offV) = grainOffset(base[0])
    val eu = ext.unit()
    fun face(q: List<V3>, ua: V3) {
        val fc = V3(q.sumOf { it.x } / q.size, q.sumOf { it.y } / q.size, q.sumOf { it.z } / q.size)
        var nn = cross(q[1] - q[0], q[q.size - 1] - q[0]).unit()
        if (nn.dot(fc - ctr) < 0) nn = nn * -1.0
        val va = cross(nn, ua).unit()
        p.faces += Face(nn, q, uv = uvOf(q, base[0], ua, va, offU, offV))
    }
    for (i in 0 until n) { val a = base[i]; val b = base[(i + 1) % n]; if ((b - a).len() > 1e-7) face(listOf(a, b, b + ext, a + ext), eu) }
    val e0 = (base[1] - base[0]).unit()
    face(base, e0); face(base.map { it + ext }.reversed(), e0)
}

/** A round rod from [a] to [b] (metres), radius [r0] at [a] and [r1] at [b], [n] sides; its ends closed. */
private fun tubeFaces(p: Part, a: V3, b: V3, r0: Double, r1: Double, n: Int) {
    val ax = (b - a); if (ax.len() < 1e-7) return
    val d = ax.unit()
    val ref = if (kotlin.math.abs(d.y) < .9) V3(0.0, 1.0, 0.0) else V3(1.0, 0.0, 0.0)
    val u = cross(d, ref).unit(); val v = cross(d, u)
    fun ring(c: V3, r: Double) = (0 until n).map { k -> val t = 2 * PI * k / n; c + u * (r * cos(t)) + v * (r * sin(t)) }
    val ra = ring(a, r0); val rb = ring(b, r1)
    val (offU, offV) = grainOffset(a)
    for (k in 0 until n) {
        val q = listOf(ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k])
        val fc = (q[0] + q[1] + q[2] + q[3]) * .25
        var nn = cross(q[1] - q[0], q[3] - q[0]).unit()
        val axisPt = a + d * ((fc - a).dot(d))
        if (nn.dot(fc - axisPt) < 0) nn = nn * -1.0
        p.faces += Face(nn, q, uv = uvOf(q, a, d, cross(nn, d).unit(), offU, offV))
    }
    p.faces += Face(d * -1.0, ra, uv = uvOf(ra, a, u, v, offU, offV))
    p.faces += Face(d, rb, uv = uvOf(rb, b, u, v, offU, offV))
}

/** One flat face [q] (convex, in order) facing [n]: a printed ring, a glow on a wall. */
private fun flatFace(p: Part, q: List<V3>, n: V3) {
    val ua = (q[1] - q[0]).unit()
    p.faces += Face(n, q, uv = uvOf(q, q[0], ua, cross(n, ua).unit(), 0.0, 0.0))
}

private fun obbEdges(e: Edges, x: Obb) {
    val k = x.corners()
    for ((i, j) in listOf(0 to 1, 1 to 2, 2 to 3, 3 to 0, 4 to 5, 5 to 6, 6 to 7, 7 to 4, 0 to 4, 1 to 5, 2 to 6, 3 to 7)) { e.segs += k[i]; e.segs += k[j] }
}

/**
 * The furniture [fs] of a room whose walls are [bases]. [rgb] gives a material's colour; [open] holds the keys of open
 * doors and drawers.
 */
/** The frame of a piece standing at [p] (Pose: along and out from wall [p].ref, turned): [len] m long. */
fun poseBasis(w: WallBasis, p: uz.metrx.app.furniture.Pose, len: Double): WallBasis {
    val o = w.at(p.a / 1000.0, 0.0, p.n / 1000.0)
    val r = Math.toRadians(p.deg.toDouble()); val c = kotlin.math.cos(r); val s = kotlin.math.sin(r)
    // turned about the vertical: along u·c + n·s, into the room n·c − u·s
    return WallBasis(o.x, o.z, w.ux * c + w.nx * s, w.uz * c + w.nz * s, w.nx * c - w.ux * s, w.nz * c - w.uz * s, len)
}

/**
 * What to light up (parts list → 3D, bazis ideas 23 Oct 2026): boards of role [role] named [key] (Parts.kt) in the
 * modules or sections [mods], each "pieceId|module" as Parts.kt names them (a section "id/2").
 */
class PartHi(val key: String, val role: String, val mods: Set<String>)

/** The part names the 3D knows its boards by; the others light up every board of their role in their module. */
private val TAGGED = setOf("fp.side", "fp.top", "fp.bottom", "fp.divider", "fp.shelf", "fp.back", "fp.door", "fp.dFace", "fp.rail", "fp.plinth",
    "fp.panel", "fp.filler", "fp.slidePanel", "fp.slideUp", "fp.dSide", "fp.dFront", "fp.dBottom", "fp.endLow", "fp.endUp")
private const val HI = 0xF59E0B

/** A handle's length along its door or drawer, mm: the piece's handle type (a knob, a long bar, the usual 128 skoba). */
fun handleLen(id: String) = when (id) { "handleKnob" -> 24; "handleLong" -> 320; else -> 128 }

fun furniture3D(fs: List<Furniture>, bases: Map<String, WallBasis>, ws: Workshop, rgb: (String) -> Int, open: Set<String>,
                amt: ((String) -> Double)? = null,
                /** "See inside": no doors, drawer fronts or sliding doors (the drawers' boxes stay, shut). */
                bare: Boolean = false, hi: PartHi? = null,
                /**
                 * How a material id (a board, the worktop, the splashback) looks in the lit 3D: its colour, finish and
                 * decor picture. Without it, a matte board in its [rgb] colour, and the boxes plain (the 2D painter).
                 */
                look: ((String) -> Look)? = null,
                /** The workshop's materials: with them every surface looks as the piece's design says (furniture Look.kt lookOf). */
                mats: List<Mat>? = null,
                /** The light quality tier (weak phones): no glow on the wall, no small details. */
                light: Boolean = false,
                /** The room's height, mm (a kitchen's row of units up to the ceiling); null: a room-less piece's own, else 2700. */
                ceil: Int? = null,
                /**
                 * Every board one box of six faces even with [look] (the 2D painter, PieceView.kt, reads them six at a
                 * time): the looks' colours kept, none of the lit 3D's shaped details.
                 */
                boxes: Boolean = false,

                /** The small decor (a gorka's dishes, the big table's pendant…, Gorka3D.kt): left out on the light tier. */
                decor: Boolean = true,
                /**
                 * The 3D screens' build (Fronts3D.kt): every door, drawer, sliding door, rack and lift-up base built
                 * shut on its own ([Furn3D.fronts]) with how it moves, so opening one only moves it; [open] and [amt]
                 * are not read.
                 */
                split: Boolean = false): Furn3D {
    // how far each door or drawer is open, 0 to 1 (moving between the two while it opens or shuts); split: all shut
    val how: (String) -> Double = if (split) { _ -> 0.0 } else amt ?: { k -> if (k in open) 1.0 else 0.0 }
    val fronts = LinkedHashMap<String, FrontCap>(); val toggles = ArrayList<ToggleCap>()
    val parts = LinkedHashMap<Pair<String?, Any>, Part>(); val edges = LinkedHashMap<String?, Edges>()
    val picks = ArrayList<Pick>(); val keys = ArrayList<String>(); val spots = LinkedHashMap<String, HandleSpot>()
    val matLook = look ?: { id: String -> Looks.board(rgb(id)) }
    val rich = look != null && !boxes
    fs.forEach { f ->
        val ms = mats ?: MAT_PRESETS
        val upId = f.mats.frontUp ?: f.mats.front
        val topId = worktopOf(f)
        val splId = splashOf(f, ms)?.id ?: "splash6"
        val colors = mapOf("carcass" to rgb(f.mats.carcass), "front" to rgb(f.mats.front), "frontUp" to rgb(upId), "back" to rgb(f.mats.back), "top" to rgb(topId),
            "mirror" to MIRROR, "glass" to GLASS_P, "splash" to rgb(splId), "plinth" to rgb(f.mats.front),
            "metal" to METAL, "dark" to DARK, "handle" to HANDLE, "white" to WHITE,
            "clear" to CLEAR, "mattress" to MATTRESS, "lamel" to LAMEL, "led" to LED, "hi" to HI)
        // the design's look of each surface (mockup mats()): from the piece's design with the workshop's materials,
        // else from the materials' looks by id; the rest fixed
        val l = f.look
        fun sf(part: String, kind: String = "board") = lookOf(f, null, part, ms).let { s -> Looks.surface(rgbOf(s.rgb), s.finish, s.tex, kind) }
        val chrome = l?.hcol == "chrome" || l == null || l.hcol.isEmpty()
        val design: Map<String, Look> = if (mats != null) {
            val hw = sf("handle", "hardware")
            // plain glass skinali under dark upper fronts is a smoked glass (mockup: #3B3531)
            val sp = lookOf(f, null, "splash", ms); val upS = lookOf(f, null, "frontUp", ms)
            val dark = sp.finish == "glass" && sp.tex == null && upS.tex == null && ((rgbOf(upS.rgb) shr 16) and 255) < 0x80
            val splash = Looks.surface(if (dark) 0x3B3531 else rgbOf(sp.rgb), sp.finish, sp.tex, "splash")
            mapOf("carcass" to sf("carcass"), "front" to sf("frontLow"), "frontUp" to sf("frontUp"), "back" to sf("back").copy(rough = .85f),
                "top" to sf("worktop", "worktop"), "splash" to splash, "plinth" to sf("plinth"),
                "handle" to hw, "frame" to sf("frame", "hardware"), "gola" to sf("gola", "hardware"), "legs" to sf("legs", "hardware"),
                "mirror" to sf("mirror"), "clear" to sf("glass", "glass"), "faucet" to (if (chrome) Looks.steel else hw))
        } else {
            mapOf("carcass" to matLook(f.mats.carcass), "front" to matLook(f.mats.front), "frontUp" to matLook(upId), "back" to matLook(f.mats.back).copy(rough = .85f),
                "top" to (look?.invoke(topId) ?: Looks.worktop(rgb(topId))), "splash" to (look?.invoke(splId) ?: Looks.plain(rgb(splId)).copy(rough = .3f)),
                "plinth" to matLook(f.mats.front), "handle" to Looks.handle, "frame" to Looks.steel, "gola" to Looks.metalOf(0x232427), "legs" to Looks.steel,
                "mirror" to Looks.mirror, "clear" to Looks.clearGlass, "faucet" to Looks.steel)
        }
        // lacobel (a sliding door's painted glass) in the lower fronts' colour, white under a wood decor (modern 3D part 5)
        val lacobel = if (mats != null) lookOf(f, null, "frontLow", ms).let { s -> if (s.tex == null) Looks.lacobel.copy(rgb = rgbOf(s.rgb)) else Looks.lacobel.copy(rgb = 0xEDEAE4) } else Looks.lacobel
        val looks = design + mapOf("glass" to Looks.lacobel, "lacobel" to lacobel, "fglass" to Looks.flutedGlass,
            "rail" to Looks.chrome, "ledOff" to Looks.ledOff, "shelfGlass" to Looks.shelfGlass, "sheen0" to Looks.sheen(.06f), "sheen1" to Looks.sheen(.035f),
            "metal" to Looks.steel, "dark" to Looks.blackGlass, "white" to Looks.enamel, "mattress" to Looks.mattress, "lamel" to Looks.lamel,
            "led" to Looks.led, "hi" to Looks.hi, "ovenWin" to Looks.ovenWindow, "display" to Looks.display, "ring" to Looks.hobRing,
            "sinkIn" to (if (chrome) Looks.sinkSteel else Looks.granite),
            "lamp" to (if (f.kx?.led == true) Looks.led else Looks.steel.copy(metal = .2f, rough = .4f)),
            "glowTop0" to Looks.glow(.07f), "glowTop1" to Looks.glow(.04f), "glowTop2" to Looks.glow(.018f)) +
            GLOW.mapIndexed { i, a -> "glow$i" to Looks.glow(a) } + WGLOW.mapIndexed { i, a -> "wglow$i" to Looks.glow(a) }
        val fws = uz.metrx.app.furniture.wsOf(f, ws)
        val B = Builder3(fws, colors, looks, parts, edges, picks, keys, how, spots, fronts, toggles)
        B.split = split; B.bare = bare; B.hi = hi; B.piece = f.id; B.hLen = handleLen(f.handle).toDouble()
        B.rich = rich; B.light = light
        B.hType = handleType(f); B.hId = f.handle; B.style = l?.style ?: "flat"; B.fglass = l?.fglass == true
        B.metalLegs = metalLegs(f); B.plinth = f.kx?.plinth == true
        // a wardrobe's LED with door sensors, its cornice or panel up to the ceiling (the room's height, a room-less piece's own)
        // a gorka draws its own LED strips and cornice (Gorka3D.kt): not the wardrobe engine's as well
        B.ledLook = f.kind == "wardrobe" && f.type != "gorka" && l?.led == true
        B.crown = if (f.kind == "kitchen" || f.type == "gorka") "" else crownOf(f)
        B.ceilH = (ceil ?: f.free?.h ?: 2700).toDouble()
        B.itemPiece = f; B.itemMats = ms
        // the worktop's thickness: a slim 20 mm stone sits on the same carcasses, its top lower
        val wtT = if (rich) (ms.firstOrNull { it.id == topId }?.t ?: K_TOP).coerceIn(10, 60) else K_TOP
        B.wtT = wtT.toDouble(); B.wt = (worktopTop(fws) - K_TOP + wtT).toDouble()
        val first = f.walls.firstOrNull { it != ISLAND }
        // the island (or peninsula) stands where it was dragged, else 900 mm out from the front of the first wall's
        // units, its fronts facing them
        val island: WallBasis? = first?.let { bases[it] }?.let { w ->
            val r = runsOf(f) { id -> bases[id]?.let { (it.len * 1000).toInt() } }.firstOrNull { it.wall == ISLAND }
            val len = r?.let { fillOf(f, it, false).used } ?: 0
            val p = f.pose?.takeIf { f.kind == "kitchen" } ?: uz.metrx.app.furniture.islandPose(f, (w.len * 1000).toInt())
            (bases[p.ref] ?: w).let { poseBasis(it, p, len / 1000.0) }
        }
        val main = uz.metrx.app.furniture.wardOfF(f)
        f.modules.forEach { m ->
            // a piece standing free (a desk, a bed in the middle of the room) has its own frame from its main box's start
            val box = uz.metrx.app.furniture.isBox(m)
            val free = f.pose?.takeIf { f.kind == "wardrobe" && box }?.let { p -> bases[p.ref]?.let { poseBasis(it, p, m.w / 1000.0) } }
            val b = free ?: (if (m.wall == ISLAND) island else bases[m.wall ?: ""]) ?: return@forEach
            val mm = if (free != null) m.copy(x = m.x - (main?.x ?: m.x)) else m
            B.wall = m.wall
            B.mod = m.label.ifEmpty { m.id }; B.sec = ""
            // a two-tone piece's upper boxes take the upper fronts' board
            B.fr = if (isUpperFront(f, m)) "frontUp" else "front"
            // the gorka's and the big table's own (Gorka3D.kt): the TV panel and the table drawn there alone, a gorka's lights and dishes over its boxes
            val gx = guest3D(f, mm, fws, decor)
            if (gx != null && gx.own) gx.boxes.forEach { B.xbox(b, it) }
            else if (m.type == "wardrobe") {
                // what stands past each end along its wall: the wall's corner, or another box close by (of another piece or this one)
                val L = bases[m.wall ?: ""]?.let { (it.len * 1000).toInt() }
                fun near(at: Int) = fs.any { o -> o.pose == null && o.modules.any { it.id != m.id && it.wall == m.wall && (o.id != f.id || !uz.metrx.app.furniture.hung(it)) &&
                    (kotlin.math.abs(it.x + it.w - at) < 60 || kotlin.math.abs(it.x - at) < 60) } }
                B.freeL = free != null || (m.x > uz.metrx.app.furniture.W_GAP_SIDE + 40 && !near(m.x))
                B.freeR = free != null || (L != null && m.x + m.w < L - uz.metrx.app.furniture.W_GAP_SIDE - 40 && !near(m.x + m.w))
                B.wardrobe(b, mm)
            } else if (m.type in uz.metrx.app.furniture.ITEM_MODS) B.item(b, mm)
            else B.kitchenUnit(b, m)
            // a bathroom vanity carries its basin and tap on top
            if (f.type == "sinkV" && m.type == "wardrobe") B.basin(b, mm)
            if (gx != null && !gx.own) gx.boxes.forEach { B.xbox(b, it) }
        }
        B.fr = "front"
        // the worktop over the lower row of each wall (and over the corner it turns into)
        if (f.kind == "kitchen") {
            val wt = B.wt.roundToInt()
            val rs = runsOf(f) { id -> bases[id]?.let { (it.len * 1000).toInt() } }
            // a row up to the ceiling: the room's height, a room-less kitchen's own
            val ceilH = ceil ?: f.free?.h ?: 2700
            val crown = crownOf(f)
            val kx = f.kx
            rs.forEach { r ->
                val b = (if (r.wall == ISLAND) island else bases[r.wall]) ?: return@forEach
                B.wall = r.wall
                val low = f.modules.filter { it.wall == r.wall && !isUpper(it) && (it.type == "base" || it.type == "filler" || it.app == "dishwasher") }.sortedBy { it.x }
                val isl = r.wall == ISLAND
                val lo = low.firstOrNull()?.x ?: 0; val hi = low.maxOfOrNull { it.x + it.w } ?: 0
                // the waterfall: the island's worktop runs down its ends to the floor (a peninsula's at its free end)
                val wf = if (isl && rich) waterfallEnds(f) else 0
                val wfLo = wf >= 2; val wfHi = wf >= 1
                // one worktop over each stretch of touching units, no joint every unit; the corner square is the first
                // side's. An island's (a peninsula's) covers its cabinets and its finished back, no more.
                val n0 = if (isl) -uz.metrx.app.furniture.PEN_BACK else 0
                var a0 = -1; var a1 = -1
                fun piece() {
                    if (a1 <= a0) return
                    if (!rich) B.box(b, B.top, a0, a1, wt - K_TOP, wt, n0, 600, true)
                    else {
                        val s0 = if (wfLo && a0 == lo) a0 - wtT else a0; val s1 = if (wfHi && a1 == hi) a1 + wtT else a1
                        B.worktop(b, s0.toDouble(), s1.toDouble(), n0.toDouble(), 600.0, low.filter { it.app == "sink" && it.x >= a0 && it.x + it.w <= a1 }.map { sinkHole(it) })
                        if (s0 < a0) B.box(b, B.top, s0, a0, 0, wt - wtT, n0, 600, true, up = true)
                        if (s1 > a1) B.box(b, B.top, a1, s1, 0, wt - wtT, n0, 600, true, up = true)
                    }
                    if (isl) B.box(b, B.front, a0, a1, 0, wt - wtT, -18, 0, true)
                }
                low.forEach { m -> if (a0 >= 0 && m.x <= a1 + 1) a1 = maxOf(a1, m.x + m.w) else { piece(); a0 = m.x; a1 = m.x + m.w } }
                // a peninsula in its usual place: the side's worktop runs on over the peninsula's finished back to its outer edge
                if (f.layout == "P" && f.pose == null && r == rs.firstOrNull { it.wall != ISLAND } && a1 > a0) a1 += uz.metrx.app.furniture.PEN_BACK
                piece()
                // end panels where a row ends in the open room (not against a wall): the lower row's, the wall units'
                if (kx != null && low.isNotEmpty()) {
                    val wl = if (isl) null else (b.len * 1000).toInt()
                    // a peninsula's side ends at the peninsula, which covers it: no end panel there; nor where the worktop runs down
                    val penSide = f.layout == "P" && r == rs.firstOrNull { it.wall != ISLAND }
                    val ends = if (isl) listOf(lo to (f.layout != "P" && !wfLo), hi to !wfHi) else listOf(lo to (lo > 20), hi to (wl != null && hi < wl - 20 && !penSide))
                    // the end panels are parts of no module (KitchenExtras.extrasParts): lit up from the parts list by their own name
                    val sm = B.mod; val ss = B.sec; B.mod = ""; B.sec = ""
                    if (kx.ends > 0) ends.forEach { (a, free) -> if (free) B.box(b, B.role("front", "fp.endLow"), if (a == lo) a - 18 else a, if (a == lo) a else a + 18, 0, wt - B.wtT, 0, 600, true, up = true) }
                    val up = f.modules.filter { it.wall == r.wall && it.type == "wall" }
                    if (kx.endsUp > 0 && up.isNotEmpty() && wl != null) {
                        val u0 = up.minOf { it.x }; val u1 = up.maxOf { it.x + it.w }; val y0 = up.minOf { it.elev }; val y1 = up.maxOf { it.elev + it.h }; val d = up.maxOf { it.d }
                        if (u0 > 20) B.box(b, B.role("frontUp", "fp.endUp"), u0 - 18, u0, y0, y1, 0, d, true, up = true)
                        if (u1 < wl - 20) B.box(b, B.role("frontUp", "fp.endUp"), u1, u1 + 18, y0, y1, 0, d, true, up = true)
                    }
                    B.mod = sm; B.sec = ss
                }
                if (r.wall == ISLAND) return@forEach
                // extras: the backsplash panel on the wall over the worktop (up to the wall units over a slim worktop)
                if (kx != null) {
                    val s0 = if (r.lowStart > 0) 0 else low.minOfOrNull { it.x } ?: 0
                    val s1 = low.maxOfOrNull { it.x + it.w } ?: 0
                    if (kx.splash > 0 && s1 > s0) B.box(b, B.splash, s0, s1, wt, wt + kx.splash + (K_TOP - B.wtT), 0, 6, true, fit = rich)
                }
                val wl = (b.len * 1000).toInt()
                // the boxes along the wall's top: wall units (the hood's too) and tall units
                val tops = f.modules.filter { it.wall == r.wall && (it.type == "wall" || it.type == "tall") }.sortedBy { it.x }
                when {
                    // a row of units over every one of them, up to the ceiling (4 mm under it)
                    crown == "ceiling" -> tops.forEach { m -> B.fr = if (isUpperFront(f, m)) "frontUp" else "front"; B.ceilingUnit(b, m, ceilH - 4) }
                    crown == "cornice" && rich -> B.cornice(b, tops, wl)
                    crown == "cornice" -> tops.filter { it.type == "wall" }.forEach { m -> B.box(b, B.role("frontUp"), m.x, m.x + m.w, m.elev + m.h, m.elev + m.h + 60, 0, m.d + 30, true) }
                }
                B.fr = "front"
                // LED strips under the wall units (not the hood's: it has its own lights), and their glow on the wall below
                if (kx?.led == true) {
                    val lit = tops.filter { it.type == "wall" && it.app != "hood" }
                    lit.forEach { m -> B.box(b, B.led, m.x + 20, m.x + m.w - 20, m.elev - 8, m.elev, m.d - 50, m.d - 36) }
                    if (rich && !light) B.glow(b, lit, wt)
                }
            }
        }
    }
    return Furn3D(parts.values.toList(), edges.values.toList(), picks, keys, spots, fronts.values.map { it.done() }, toggles.map { it.done() })
}

/** A front's own frame: its corner [o] at the hinge side and the bottom, unit directions across it [e], up it, out of it [tn]. */
private class Frame(val o: V3, val e: V3, val up: V3, val tn: V3) {
    /** The point [u] across, [v] up and [w] out, mm. */
    fun at(u: Double, v: Double, w: Double) = o + e * (u / 1000) + up * (v / 1000) + tn * (w / 1000)
    fun obb(u0: Double, u1: Double, v0: Double, v1: Double, w0: Double, w1: Double) =
        Obb(at(u0, v0, w0), e * ((u1 - u0) / 1000), up * ((v1 - v0) / 1000), tn * ((w1 - w0) / 1000))
}

/** Builds the boards of one piece of furniture on a wall frame; lengths in mm. */
internal class Builder3(
    val ws: Workshop, val colors: Map<String, Int>, val looks: Map<String, Look>, private val parts0: LinkedHashMap<Pair<String?, Any>, Part>,
    private val edges0: LinkedHashMap<String?, Edges>, private val picks0: ArrayList<Pick>, val keys: ArrayList<String>, val how: (String) -> Double,
    val spots: MutableMap<String, HandleSpot>,
    private val fronts: LinkedHashMap<String, FrontCap> = LinkedHashMap(), private val toggles: ArrayList<ToggleCap> = ArrayList()
) {
    /** Building each front on its own (Fronts3D.kt); [cap] what is being drawn into now (null: the piece's parts). */
    var split = false
    private var cap: Cap? = null
    val parts: LinkedHashMap<Pair<String?, Any>, Part> get() = cap?.parts ?: parts0
    val edgeMap: LinkedHashMap<String?, Edges> get() = cap?.edges ?: edges0
    val picks: ArrayList<Pick> get() = cap?.picks ?: picks0

    /**
     * What [body] draws is front [key], moving as [motion] (split only; else, or inside another front, it is drawn
     * with the rest).
     */
    fun moving(key: String, motion: () -> Motion, body: () -> Unit) {
        if (!split || cap != null) { body(); return }
        val fc = fronts.getOrPut(key) { FrontCap(key, motion()) }
        cap = fc.main
        try { body() } finally { cap = null }
    }

    /** While drawing front [key]: what [body] draws shows only while it is open, a drawer's box (split; else as it is). */
    fun innerOf(key: String, body: () -> Unit) {
        val fc = fronts[key]
        if (!split || fc == null || cap !== fc.main) { body(); return }
        cap = fc.inner
        try { body() } finally { cap = fc.main }
    }

    /** What [body] draws shows only while any of [deps] is open ([whenOpen]) or only while all are shut (split only). */
    fun toggle(deps: List<String>, whenOpen: Boolean, body: () -> Unit) {
        if (!split || cap != null) { body(); return }
        val tc = ToggleCap(deps, whenOpen).also { toggles += it }
        cap = tc.cap
        try { body() } finally { cap = null }
    }

    /**
     * The wall being furnished: the furniture on a wall that faces the camera goes see-through with it (an island's
     * never does). Parts are one per wall and colour, so opening a door does not change how many there are.
     */
    var wall: String? = null
    /** The piece being built has nothing past its left / right end (no wall, no neighbour): a door hinged there opens wide. */
    var freeL = false; var freeR = false
    /** See inside (no fronts); what to light up; the piece and module (and section) being built, as Parts.kt names them; the handles' length. */
    var bare = false; var hi: PartHi? = null; var piece = ""; var mod = ""; var sec = ""; var hLen = 128.0
    /** The lit 3D's detail (else the plain boxes of the 2D painter); the light tier's (no glow, fewer small details). */
    var rich = false; var light = false
    /** The design: handle type and hardware id, front style, fluted glass, metal legs or the hidden plinth (Look.kt). */
    var hType = "bar"; var hId = ""; var style = "flat"; var fglass = false; var metalLegs = false; var plinth = false
    /** A wardrobe's LED inside with door sensors (Look.led); on top of it: "", "cornice" or "ceiling"; the ceiling's height, mm. */
    var ledLook = false; var crown = ""; var ceilH = 2700.0
    /** The front board of the box being built: "front" (the lower fronts) or "frontUp" (a two-tone piece's upper ones). */
    var fr = "front"
    /** The worktop's top above the floor and its thickness, mm. */
    var wt = 0.0; var wtT = K_TOP.toDouble()
    val gola get() = rich && hType == "gola"

    /**
     * Board [k] of role [r] (carcass, front, frontUp, back) being drawn: in the highlight's colour when it is the part
     * asked for, else in the look of [show] (a wardrobe's inner drawer faces, of carcass board, shown in the fronts' look).
     */
    fun role(r: String, k: String = "", show: String = r): Part {
        val h = hi ?: return p(show)
        val inMod = "$piece|$mod" in h.mods || (sec.isNotEmpty() && "$piece|$mod/$sec" in h.mods)
        val dBox = h.key == "fp.dSide" || h.key == "fp.dFront" || h.key == "fp.dBottom"
        val named = h.key !in TAGGED || k == h.key || (dBox && k == "fp.dBox")
        val rr = if (r == "frontUp") "front" else r
        return if (inMod && named && (h.role == rr || dBox)) p("hi") else p(show)
    }
    fun p(k: String): Part {
        val lk = looks.getValue(k); val c = colors[k] ?: lk.rgb; val w = if (wall == ISLAND) null else wall
        // the worktop is a part of its own (even in the fronts' colour): its top and outline are drawn as a slab
        if (k == "top") return parts.getOrPut(("top|" + (w ?: "")) to lk) { Part(0, w, Role.FURN, c, 1f, slab = true, look = lk) }
        // clear glass is seen through; one part for each wall and look (a colour in two finishes is two parts)
        return parts.getOrPut(w to lk) { Part(0, w, Role.FURN, c, if (k == "clear") .38f else lk.alpha, look = lk) }
    }
    val carcass get() = role("carcass"); val front get() = role("front"); val back get() = role("back"); val top get() = p("top")
    val metal get() = p("metal"); val dark get() = p("dark"); val handle get() = p("handle"); val white get() = p("white")
    val splash get() = p("splash"); val led get() = p("led")
    val edges get() = (if (wall == ISLAND) null else wall).let { w -> edgeMap.getOrPut(w) { Edges(0, "furn " + (w ?: "island")) } }

    val t = ws.t
    val g = ws.gap10 / 10.0; val edge = ws.edge10 / 10.0

    /** The worktop's light outline, kept apart from the dark one of the boards. */
    private val slabEdges get() = (if (wall == ISLAND) null else wall).let { w -> edgeMap.getOrPut("top|" + (w ?: "")) { Edges(0, "furn " + (w ?: "island"), SLAB_LINE) } }

    /** A box of [p]; its grain along [grain] (null: its long side); [fit] its picture laid once from its corner; [org] where its grain starts. */
    fun obb(p: Part, x: Obb, line: Boolean, grain: V3? = null, fit: Boolean = false, org: V3? = null) {
        obbFaces(p, x, grain, fit, org); if (line) obbEdges(if (p.slab) slabEdges else edges, x)
    }

    /**
     * An upright box [a0]..[a1] along the wall, [y0]..[y1] up, [n0]..[n1] out from the wall; [up] its grain upright
     * (fronts cut with the grain along their height, Parts.kt), else along its long side (or [grain]).
     */
    fun box(w: WallBasis, p: Part, a0: Number, a1: Number, y0: Number, y1: Number, n0: Number, n1: Number, line: Boolean = false, up: Boolean = false,
            fit: Boolean = false, grain: V3? = null, org: V3? = null) {
        val A0 = a0.toDouble() / 1000; val A1 = a1.toDouble() / 1000; val Y0 = y0.toDouble() / 1000; val Y1 = y1.toDouble() / 1000
        val N0 = n0.toDouble() / 1000; val N1 = n1.toDouble() / 1000
        if (A1 - A0 < 1e-4 || Y1 - Y0 < 1e-4 || N1 - N0 < 1e-4) return
        obb(p, Obb(w.at(A0, Y0, N0), w.dir(A1 - A0, 0.0), V3(0.0, Y1 - Y0, 0.0), w.dir(0.0, N1 - N0)), line, if (up) UP else grain, fit, org)
    }

    /** A box in a front's frame (mm); its grain up the front (else across). */
    private fun fbox(ff: Frame, p: Part, u0: Double, u1: Double, v0: Double, v1: Double, w0: Double, w1: Double, line: Boolean, grain: V3? = ff.up) {
        if (u1 - u0 < .1 || v1 - v0 < .1 || w1 - w0 < .1) return
        obb(p, ff.obb(u0, u1, v0, v1, w0, w1), line, grain)
    }

    /** A rod between two points of the wall's frame (mm), radius [r0] to [r1] mm. */
    private fun rod(w: WallBasis, p: Part, a: Triple<Double, Double, Double>, b: Triple<Double, Double, Double>, r0: Double, r1: Double = r0, n: Int = if (light) 8 else 14) =
        tubeFaces(p, w.at(a.first / 1000, a.second / 1000, a.third / 1000), w.at(b.first / 1000, b.second / 1000, b.third / 1000), r0 / 1000, r1 / 1000, n)

    /* ---------------- fronts and handles (the mockup's b.front, b.bar, b.knob, b.handle, b.glassDoor) ---------------- */

    /**
     * A front [fw] × [fh] × [th] mm in frame [ff] in the piece's style: flat; milled (shaker: a frame of rails 4 mm
     * proud round a panel sunk 6 mm, a small bead round the panel); fluted (half-round ribs about 30 mm apart on a
     * thinner board). Returns how far its face stands out of the frame, mm (where a handle sits).
     */
    private fun frontBody(ff: Frame, p: Part, fw: Double, fh: Double, th: Double, grain: V3?): Double = when {
        style == "shaker" && fw > 140 && fh > 120 -> {
            val rw = min(68.0, min(fw * .2, fh * .22)); val t2 = th + 4
            fbox(ff, p, 0.0, rw, 0.0, fh, 0.0, t2, true, ff.up); fbox(ff, p, fw - rw, fw, 0.0, fh, 0.0, t2, true, ff.up)
            fbox(ff, p, rw, fw - rw, 0.0, rw, 0.0, t2, true, ff.e); fbox(ff, p, rw, fw - rw, fh - rw, fh, 0.0, t2, true, ff.e)
            fbox(ff, p, rw, fw - rw, rw, fh - rw, 0.0, th - 6, false, grain)
            if (!light) {
                val bd = 11.0; val ix = rw + 6; val iy = rw + 6; val iw = fw - 2 * rw - 12; val ih = fh - 2 * rw - 12; val z0 = th - 6; val z1 = th + 1
                if (iw > 40 && ih > 40) {
                    fbox(ff, p, ix, ix + bd, iy, iy + ih, z0, z1, false); fbox(ff, p, ix + iw - bd, ix + iw, iy, iy + ih, z0, z1, false)
                    fbox(ff, p, ix + bd, ix + iw - bd, iy, iy + bd, z0, z1, false, ff.e); fbox(ff, p, ix + bd, ix + iw - bd, iy + ih - bd, iy + ih, z0, z1, false, ff.e)
                }
            }
            t2
        }
        style == "fluted" && fw > 100 -> {
            val z0 = max(6.0, th - 8); val dz = 12.0
            fbox(ff, p, 0.0, fw, 0.0, fh, 0.0, z0, false, grain)
            ribs(ff, p, 0.0, fw, 1.5, fh - 1.5, z0, dz, 30.0)
            obbEdges(edges, ff.obb(0.0, fw, 0.0, fh, 0.0, z0 + dz))
            z0 + dz
        }
        else -> { fbox(ff, p, 0.0, fw, 0.0, fh, 0.0, th, true, grain); th }
    }

    /** Upright half-round ribs about [pitch] mm apart over [u0]..[u1], [v0]..[v1], standing [dz] out of [z0] (fluted fronts and glass). */
    private fun ribs(ff: Frame, p: Part, u0: Double, u1: Double, v0: Double, v1: Double, z0: Double, dz: Double, pitch: Double) {
        val n = max(3, ((u1 - u0) / pitch).roundToInt()); val sw = (u1 - u0) / n
        val steps = if (light) 2 else 5
        for (i in 0 until n) {
            val a = u0 + i * sw + .4; val b = u0 + (i + 1) * sw - .4; val c = (a + b) / 2; val r = (b - a) / 2
            val base = (0..steps).map { k -> val th = PI * k / steps; ff.at(c + r * cos(th), v0, z0 + dz * sin(th)) }
            prismFaces(p, base, ff.up * ((v1 - v0) / 1000))
        }
    }

    /** The handle of front [key] ([fw] × [fh], its face [zf] mm out) as the piece's type puts it ([handleSpot]). */
    private fun handleOn(ff: Frame, key: String, fw: Double, fh: Double, zf: Double, kind: String, pos: String, mid: Double = fh / 2) {
        val s = handleSpot(hType, hId, kind, pos, fw, fh, mid) ?: return
        spots[key] = s
        if (s.knob) knob(ff, s.u, s.v, zf) else bar(ff, s.u, s.v, zf, s.len, s.vertical)
    }

    /** A bar handle [len] mm long on two standoffs 24 mm out of the face (mockup b.bar). */
    private fun bar(ff: Frame, cu: Double, cv: Double, zf: Double, len: Double, vert: Boolean, p: Part = handle) {
        val c = max(50.0, len - 40); val so = 24.0; val hb = 11.0; val n = if (light) 6 else 10
        for (k in listOf(-1.0, 1.0)) {
            val u = if (vert) cu else cu + k * c / 2; val v = if (vert) cv + k * c / 2 else cv
            tubeFaces(p, ff.at(u, v, zf), ff.at(u, v, zf + so), .0042, .0042, n)
        }
        if (vert) fbox(ff, p, cu - hb / 2, cu + hb / 2, cv - len / 2, cv + len / 2, zf + so, zf + so + hb, false)
        else fbox(ff, p, cu - len / 2, cu + len / 2, cv - hb / 2, cv + hb / 2, zf + so, zf + so + hb, false, ff.e)
    }

    /**
     * A mirror's pane [u0]..[u1] × [v0]..[v1] in frame [ff], its face [z] mm out: two faint light streaks slanting up
     * across it, the room it shows (the mockup's mirrors reflect the room; ours have the studio's soft light only, and
     * without them read as a grey panel). The light tier has none.
     */
    private fun sheen(ff: Frame, u0: Double, u1: Double, v0: Double, v1: Double, z: Double) {
        if (light) return
        val w = u1 - u0; val h = v1 - v0; val k = min(w * .6, h * .3)
        listOf(Triple(.28, .11, "sheen0"), Triple(.45, .04, "sheen1")).forEach { (at, wd, key) ->
            val a = v0 + h * at; val b = a + h * wd
            if (w > 60 && b + k <= v1) flatFace(p(key), listOf(ff.at(u0, a, z), ff.at(u1, a + k, z), ff.at(u1, b + k, z), ff.at(u0, b, z)), ff.tn)
        }
    }

    /** A round knob: a rosette, a stem and a flattened ball (mockup b.knob). */
    private fun knob(ff: Frame, u: Double, v: Double, zf: Double) {
        val p = handle; val n = if (light) 8 else 16
        fun ring(w0: Double, w1: Double, r0: Double, r1: Double) = tubeFaces(p, ff.at(u, v, zf + w0), ff.at(u, v, zf + w1), r0 / 1000, r1 / 1000, n)
        ring(0.0, 4.0, 11.0, 11.0); ring(4.0, 14.0, 6.0, 6.0); ring(14.0, 21.0, 8.0, 14.5); ring(21.0, 29.0, 14.5, 12.0); ring(29.0, 32.0, 12.0, 6.0)
    }

    /**
     * A glass door (mockup b.glassDoor): an aluminium frame 20 mm in the handles' colour round clear glass, or fluted
     * glass; a milled (neoclassic) piece's frame of front board, 55 mm.
     */
    private fun glassDoor(ff: Frame, fw: Double, fh: Double) {
        val sh = style == "shaker"; val bw = if (sh) 55.0 else 20.0; val fd = 20.0
        val fm = if (sh) role(fr, "fp.door") else p("frame")
        fbox(ff, fm, 0.0, bw, 0.0, fh, 0.0, fd, true); fbox(ff, fm, fw - bw, fw, 0.0, fh, 0.0, fd, true)
        fbox(ff, fm, bw, fw - bw, 0.0, bw, 0.0, fd, true, ff.e); fbox(ff, fm, bw, fw - bw, fh - bw, fh, 0.0, fd, true, ff.e)
        if (fglass) ribs(ff, p("fglass"), bw, fw - bw, bw, fh - bw, 6.0, 7.0, 22.0)
        else fbox(ff, p("clear"), bw, fw - bw, bw, fh - bw, 8.0, 12.0, false)
    }

    /**
     * A door hinged at [ha] (the back corner of its hinge edge), [fw] wide, opening to the right ([s] +1) or left (-1);
     * its handle's middle [hy] above the door's bottom ([pos] "top", "bottom" or "mid" in the lit 3D: [handleSpot]).
     */
    fun door(w: WallBasis, key: String, ha: Double, n: Double, y0: Double, h: Double, fw: Double, s: Int, handles: Boolean, hy: Double, p0: Part? = null,
             deg: Double = SHUT_DEG, face: String = "", pos: String = "mid") {
        // seeing inside: no doors at all
        if (bare) return
        keys += key
        // split: built shut, turning about its hinge edge (the line up through [ha]) by [deg], its free edge into the room
        moving(key, { Motion.turn(w.at(ha / 1000, y0 / 1000, n / 1000), cross(w.dir(1.0, 0.0), w.dir(0.0, s.toDouble())), Math.toRadians(deg)) }) {
            doorAt(w, key, ha, n, y0, h, fw, s, handles, hy, p0, deg, face, pos)
        }
    }

    private fun doorAt(w: WallBasis, key: String, ha: Double, n: Double, y0: Double, h: Double, fw: Double, s: Int, handles: Boolean, hy: Double, p0: Part?,
                       deg: Double, face: String, pos: String) {
        val p = p0 ?: role(fr, "fp.door")
        val th = Math.toRadians(deg) * how(key)
        val e = w.dir(s * cos(th), sin(th)); val tn = w.dir(-s * sin(th), cos(th))
        val o = w.at(ha / 1000, y0 / 1000, n / 1000)
        val x = Obb(o, e * (fw / 1000), V3(0.0, h / 1000, 0.0), tn * (t / 1000.0))
        val up = V3(0.0, 1.0, 0.0)
        picks += Pick(key, x)
        if (rich) {
            val ff = Frame(o, e, up, tn)
            when (face) {
                "glass" -> glassDoor(ff, fw, h)
                "mirror" -> { obb(p, x, true, up); obb(p("mirror"), Obb(o + e * .005 + up * .005 + tn * (t / 1000.0), e * (fw / 1000 - .01), up * (h / 1000 - .01), tn * .004), false)
                    sheen(ff, 5.0, fw - 5, 5.0, h - 5, t + 4.5)
                    if (handles) handleOn(ff, key, fw, h, t + 4.0, "door", pos, hy) }
                else -> { val zf = frontBody(ff, p, fw, h, t.toDouble(), up); if (handles) handleOn(ff, key, fw, h, zf, "door", pos, hy) }
            }
            return
        }
        when (face) {
            // glass in an aluminium frame: the frame's four sides round a clear pane
            "glass" -> {
                val fr = .02; val W = fw / 1000; val H = h / 1000; val T = t / 1000.0
                obb(metal, Obb(o, e * fr, up * H, tn * T), true); obb(metal, Obb(o + e * (W - fr), e * fr, up * H, tn * T), true)
                obb(metal, Obb(o + e * fr, e * (W - 2 * fr), up * fr, tn * T), true); obb(metal, Obb(o + e * fr + up * (H - fr), e * (W - 2 * fr), up * fr, tn * T), true)
                obb(p("clear"), Obb(o + e * fr + up * fr + tn * (T / 2 - .002), e * (W - 2 * fr), up * (H - 2 * fr), tn * .004), false)
            }
            // a mirror on the board door's face
            "mirror" -> { obb(p, x, true, up); obb(p("mirror"), Obb(o + e * .005 + up * .005 + tn * (t / 1000.0), e * (fw / 1000 - .01), up * (h / 1000 - .01), tn * .004), false) }
            // a door's grain runs up it
            else -> obb(p, x, true, up)
        }
        if (handles) {
            // a knob is as wide as it is long; a long handle is no longer than the door less 40 mm
            val hl = min(hLen, max(20.0, h - 40))
            val hw = if (hl < 60) hl / 1000 else .012
            val ho = o + e * ((fw - 40) / 1000) + tn * (t / 1000.0) + V3(0.0, (hy - hl / 2) / 1000, 0.0)
            obb(handle, Obb(ho, e * hw, V3(0.0, hl / 1000, 0.0), tn * .025), false)
        }
    }

    /** A drawer front (and its box, out when open): [a0] along, [y0] up, the front's back face at [n]. */
    fun drawer(w: WallBasis, key: String, a0: Double, fw: Double, y0: Double, fh: Double, n: Double, d: Double, handles: Boolean, pr: String = "front", box: Boolean = true) {
        // seeing inside: the drawer's box stays (shut), its front goes
        if (!bare) keys += key
        // split: built shut, pulled out three quarters of its depth; its box shows only while it is out
        if (bare) drawerAt(w, key, a0, fw, y0, fh, n, d, handles, pr, box)
        else moving(key, { Motion.move(w.dir(0.0, d * .75 / 1000)) }) { drawerAt(w, key, a0, fw, y0, fh, n, d, handles, pr, box) }
    }

    private fun drawerAt(w: WallBasis, key: String, a0: Double, fw: Double, y0: Double, fh: Double, n: Double, d: Double, handles: Boolean, pr: String, box: Boolean) {
        val out = if (bare) 0.0 else d * .75 * how(key)
        val nn = n + out
        val o = w.at(a0 / 1000, y0 / 1000, nn / 1000)
        val x = Obb(o, w.dir(fw / 1000, 0.0), V3(0.0, fh / 1000, 0.0), w.dir(0.0, t / 1000.0))
        val ff = Frame(o, w.dir(1.0, 0.0), UP, w.dir(0.0, 1.0))
        var zf = t.toDouble()
        // seeing inside, an inner drawer's face (behind a door, of the carcass board) stays: only fronts go
        // a drawer front's grain runs across it (Parts.kt: its length is its width)
        if (!bare || pr != "front") {
            // the lit 3D shows a wardrobe's inner drawers (their faces cut from the carcass board) in the fronts' look (mockup)
            val inner = rich && pr == "carcass"
            val p = role(if (pr == "front") fr else pr, "fp.dFace", show = if (inner) fr else if (pr == "front") fr else pr)
            if (rich && (pr == "front" || inner)) zf = frontBody(ff, p, fw, fh, t.toDouble(), x.a) else obb(p, x, true, x.a)
            if (!bare) picks += Pick(key, x)
        }
        if (box && (out > 0 || bare || (split && !bare))) innerOf(key) {
            val bh = min(fh - 40, 150.0).coerceAtLeast(60.0); val bx0 = a0 + 26; val bx1 = a0 + fw - 26; val by = y0 + 20
            val c = role("carcass", "fp.dBox")
            box(w, c, bx0, bx1, by, by + 12, nn - d + 40, nn)
            box(w, c, bx0, bx0 + 12, by, by + bh, nn - d + 40, nn); box(w, c, bx1 - 12, bx1, by, by + bh, nn - d + 40, nn)
            box(w, c, bx0, bx1, by, by + bh, nn - d + 40, nn - d + 52)
        }
        if (handles && !bare) {
            if (rich) { handleOn(ff, key, fw, fh, zf, "drawer", ""); return }
            val hc = a0 + fw / 2
            // a long handle is no longer than the front less 40 mm
            val hl = min(hLen, max(20.0, fw - 40))
            val hh = if (hl < 60) hl / 1000 else .012
            obb(handle, Obb(w.at((hc - hl / 2) / 1000, (y0 + fh - min(40.0, fh / 3)) / 1000, (nn + t) / 1000), w.dir(hl / 1000, 0.0), V3(0.0, hh, 0.0), w.dir(0.0, .025)), false)
        }
    }

    /** A fixed front (an appliance's panel, a lift-up flap of the top row) [a0]..+[fw] along, [y0]..+[fh] up, its back at [n]. */
    private fun panel(w: WallBasis, p: Part, a0: Double, fw: Double, y0: Double, fh: Double, n: Double, kind: String = "", key: String = "") {
        if (!rich) { box(w, p, a0, a0 + fw, y0, y0 + fh, n, n + t, true, up = true); return }
        val ff = Frame(w.at(a0 / 1000, y0 / 1000, n / 1000), w.dir(1.0, 0.0), UP, w.dir(0.0, 1.0))
        val zf = frontBody(ff, p, fw, fh, t.toDouble(), UP)
        if (kind.isNotEmpty()) handleOn(ff, key, fw, fh, zf, kind, "")
    }

    /** A Gola channel along a base unit [x0]..[x1]: the recess over a front whose top is [yTop] − [GOLA_GAP], to [yTop]. */
    private fun channel(w: WallBasis, x0: Double, x1: Double, yTop: Double, d: Double) =
        box(w, p("gola"), x0, x1, yTop - GOLA_GAP - 18, yTop, d - 28, d + 1)

    /** A kitchen unit: base, wall or tall carcass with its fronts; appliance spaces and fillers. */
    fun kitchenUnit(w: WallBasis, m: Module) {
        val x0 = m.x.toDouble(); val x1 = x0 + m.w; val y0 = m.elev.toDouble(); val y1 = y0 + m.h; val d = m.d.toDouble()
        // a Gola kitchen's lower units: the fronts stop under a channel (Look.kt lookSwap counts the same ones)
        val gl = gola && !isUpper(m)
        when (m.type) {
            // a strip of front board flush with the row's fronts
            "filler" -> { val fn = if (isUpper(m)) K_WALL_D.toDouble() else K_BASE_D.toDouble(); box(w, role(fr, "fp.filler"), x0, x1, y0, y1, fn, fn + t, true, up = true); return }
            "gap" -> {
                when (m.app) {
                    "fridge" -> {
                        box(w, white, x0 + 5, x1 - 5, 0, m.h, 0, d, true)
                        val split = m.h * .64
                        box(w, metal, x0 + 5, x1 - 5, split - 4, split + 4, d, d + 2)
                        box(w, if (rich) metal else handle, x0 + 30, x0 + 42, split + 120, split + 420, d, d + 25); box(w, if (rich) metal else handle, x0 + 30, x0 + 42, split - 420, split - 120, d, d + 25)
                    }
                    "dishwasher" -> {
                        box(w, metal, x0 + 3, x1 - 3, y0, y1 - 10, 0, d - 20)
                        if (!bare) frontSizes(m.fronts, m.w, m.h, ws).firstOrNull()?.let { (fh, fw) ->
                            val pp = role(fr, if (m.fronts.kind == "panel") "fp.panel" else "fp.door")
                            if (rich) {
                                val h2 = if (gl) fh - GOLA_GAP.toDouble() else fh.toDouble()
                                panel(w, pp, x0 + edge, fw.toDouble(), y0 + edge, h2, d, if (uz.metrx.app.furniture.hasHandle(m, "f0")) "drawer" else "", "${m.id}:f0")
                                if (gl) channel(w, x0, x1, y1, d)
                            } else {
                                box(w, pp, x0 + edge, x0 + edge + fw, y0 + edge, y0 + edge + fh, d, d + t, true, up = true)
                                if (uz.metrx.app.furniture.hasHandle(m, "f0")) box(w, handle, x0 + m.w / 2.0 - hLen / 2, x0 + m.w / 2.0 + hLen / 2, y0 + edge + fh - 46, y0 + edge + fh - 34, d + t, d + t + 25)
                            }
                        }
                    }
                }
                return
            }
        }
        // the carcass: sides, bottom, top (two rails on base units), back, shelves
        val side = role("carcass", "fp.side")
        box(w, side, x0, x0 + t, y0, y1, 0, d, true); box(w, side, x1 - t, x1, y0, y1, 0, d, true)
        // a base unit's bottom is its own part; a wall or tall unit's top and bottom are one
        box(w, role("carcass", if (m.type == "base") "fp.bottom" else "fp.top"), x0 + t, x1 - t, y0, y0 + t, 0, d, true)
        if (m.type == "base") { val r = role("carcass", "fp.rail"); box(w, r, x0 + t, x1 - t, y1 - t, y1, d - 100, d, true); box(w, r, x0 + t, x1 - t, y1 - t, y1, 0, 100, true) }
        else box(w, role("carcass", "fp.top"), x0 + t, x1 - t, y1 - t, y1, 0, d, true)
        // the back sits in grooves between the sides, the bottom and the top (Parts.kt backPanel)
        box(w, role("back", "fp.back"), x0 + t, x1 - t, y0 + t, y1 - t, 0, 3)
        val shelves = m.inserts.filter { it.kind == "shelf" }.sumOf { it.qty }
        if (m.fronts.kind != "drawer") for (k in 1..shelves) { val y = y0 + (m.h - t) * k / (shelves + 1.0); box(w, role("carcass", "fp.shelf"), x0 + t, x1 - t, y, y + t, 20, d - 20, true) }
        // under base and tall units on legs: the visible metal legs of the design, the hidden plinth in the lower
        // fronts' board 50 mm back from the fronts, else the plinth strip as before
        if (m.legs && m.type != "wall" && y0 > 0) when {
            rich && metalLegs -> listOf(x0 + 50, x1 - 50).forEach { a -> listOf(70.0, d - 60).forEach { n -> rod(w, p("legs"), Triple(a, 0.0, n), Triple(a, y0, n), 13.0, 16.0) } }
            rich && plinth -> box(w, p("plinth"), x0, x1, 0, y0 - 2, d - 66, d - 50, true)
            else -> box(w, metal, x0, x1, 0, y0 - 2, d - 70, d - 54)
        }
        // fronts
        val fs = frontSizes(m.fronts, m.w, m.h, ws)
        // an oven housing: the oven in its niche (800 to 1395 from the floor), a door under it and one over it
        val ovenNiche = m.app == "oven" && m.fronts.kind == "door" && fs.size == 1
        when (m.fronts.kind) {
            "door" -> if (ovenNiche) {
                val fw = fs[0].second.toDouble(); var lo = 800 - g / 2 - (y0 + edge); var y2 = 1395 + g / 2
                // a Gola kitchen: a channel under the oven and one over it, the doors short of them
                if (gl) { lo -= GOLA_GAP; y2 += GOLA_GAP; channel(w, x0, x1, 800.0, d); box(w, p("gola"), x0, x1, 1395.0, 1395.0 + GOLA_GAP + 18, d - 28, d + 1) }
                // the housing's one door in the lists: both halves follow its handle
                val hd = uz.metrx.app.furniture.hasHandle(m, "f0")
                door(w, "${m.id}:f0", x0 + edge, d, y0 + edge, lo, fw, 1, hd, lo - 90, pos = "top")
                door(w, "${m.id}:f1", x0 + edge, d, y2, y1 - edge - y2, fw, 1, hd, 90.0, pos = "bottom")
            } else {
                // a Gola base unit's doors stop under the channel
                val cut = if (gl && m.type == "base") GOLA_GAP.toDouble() else 0.0
                if (cut > 0) channel(w, x0, x1, y1, d)
                fs.forEachIndexed { j, (fh0, fw) ->
                    val fh = fh0 - cut
                    val n = fs.size
                    val a = x0 + edge + j * (fw + g)
                    // single doors hinge on the left; pairs on the outer edges
                    val right = n == 2 && j == 1
                    // handles near the top of a low door, near the bottom of a wall unit's, at 1 m on a tall one
                    val hy = when { m.type == "wall" -> 90.0; fh > 1200 -> (1000 - y0).coerceIn(minOf(150.0, fh / 2.0), maxOf(fh / 2.0, fh - 150.0)); else -> fh - 90.0 }
                    val pos = when { m.type == "wall" -> "bottom"; fh > 1200 -> "mid"; else -> "top" }
                    door(w, "${m.id}:f$j", if (right) a + fw else a, d, y0 + edge, fh, fw.toDouble(), if (right) -1 else 1, uz.metrx.app.furniture.hasHandle(m, "f$j"), hy, pos = pos)
                }
            }
            "drawer", "panel" -> if (gl && m.fronts.kind == "drawer" && m.type == "base") {
                // a Gola drawer unit: a channel over each drawer, the drawers sharing what is left
                val n = fs.size; val fh = (m.h - edge) / n - GOLA_GAP
                var top = y1
                fs.forEachIndexed { j, (_, fw) ->
                    channel(w, x0, x1, top, d)
                    val y = top - GOLA_GAP - fh
                    drawer(w, "${m.id}:f$j", x0 + edge, fw.toDouble(), y, fh, d, d, uz.metrx.app.furniture.hasHandle(m, "f$j"))
                    top = y
                }
            } else {
                // a Gola base unit's panel (a blind corner) stops under the channel too
                val cut = if (gl && m.type == "base" && m.fronts.kind == "panel") GOLA_GAP.toDouble() else 0.0
                if (cut > 0) channel(w, x0, x1, y1, d)
                var y = y1 - edge - cut
                fs.forEachIndexed { j, (fh, fw) ->
                    y -= fh
                    if (m.fronts.kind == "drawer") drawer(w, "${m.id}:f$j", x0 + edge, fw.toDouble(), y, fh.toDouble(), d, d, uz.metrx.app.furniture.hasHandle(m, "f$j"))
                    else if (!bare) panel(w, role(fr, "fp.panel"), x0 + edge, fw.toDouble(), y, fh.toDouble(), d)
                    y -= g
                }
            }
        }
        // what shows the appliance
        val cx = (x0 + x1) / 2; val wt = this.wt
        if (rich) when (m.app) {
            "sink" -> sink(w, m)
            "hob" -> hob(w, cx)
            "oven" -> if (ovenNiche) oven(w, x0 + edge, x1 - edge, 800 + g / 2, 1395 - g / 2, d) else oven(w, x0 + edge + 20, x1 - edge - 20, 800.0, 1380.0, d + t)
            "micro" -> micro(w, x0 + t + 10, x0 + m.w * .72, y0 + t, d)
            "hood" -> hood(w, x0, x1, y0, d)
        } else when (m.app) {
            "sink" -> {
                box(w, metal, cx - m.w * .36, cx + m.w * .36, wt, wt + 2, 80, 520)
                box(w, metal, cx - 15, cx + 15, wt, wt + 300, 40, 70); box(w, metal, cx - 12, cx + 12, wt + 280, wt + 300, 70, 260)
            }
            "hob" -> {
                box(w, dark, cx - 290, cx + 290, wt, wt + 6, 40, 560)
                listOf(-140.0 to 160.0, 140.0 to 160.0, -140.0 to 420.0, 140.0 to 420.0).forEach { (dx, dn) -> box(w, metal, cx + dx - 45, cx + dx + 45, wt + 6, wt + 9, dn - 45, dn + 45) }
            }
            "oven" -> if (ovenNiche) {
                box(w, dark, x0 + edge, x1 - edge, 800 + g / 2, 1395 - g / 2, d, d + t, true)
                box(w, metal, x0 + edge + 40, x1 - edge - 40, 1395 - 60, 1395 - 48, d + t, d + t + 25)
            } else box(w, dark, x0 + edge + 20, x1 - edge - 20, 800, 1380, d + t, d + t + 2)
            "micro" -> box(w, dark, x0 + t + 10, x0 + m.w * .72, y0 + t, y0 + t + 290, 40, d - 10, true)
            "hood" -> box(w, metal, x0 + 10, x1 - 10, y0 - 60, y0, 30, d + 40, true)
        }
    }

    /* ---------------- appliances (the lit 3D) ---------------- */

    /** A sink bowl under its cut-out in the worktop (190 deep, 8 mm walls) and a gooseneck tap behind it (mockup). */
    private fun sink(w: WallBasis, m: Module) {
        val (a0, a1, n0, n1) = sinkHole(m).let { listOf(it[0], it[1], it[2], it[3]) }
        val sk = p("sinkIn"); val dep = 190.0; val th = 8.0
        box(w, sk, a0, a1, wt - dep - 10, wt - dep, n0, n1)
        box(w, sk, a0, a1, wt - dep, wt - 1, n0, n0 + th); box(w, sk, a0, a1, wt - dep, wt - 1, n1 - th, n1)
        box(w, sk, a0, a0 + th, wt - dep, wt - 1, n0, n1); box(w, sk, a1 - th, a1, wt - dep, wt - 1, n0, n1)
        val cx = (a0 + a1) / 2
        if (!light) rod(w, metal, Triple(cx, wt - dep, (n0 + n1) / 2), Triple(cx, wt - dep + 4, (n0 + n1) / 2), 35.0)
        // the tap: its base, the riser, the gooseneck over the bowl, the spout, the lever
        val fp = p("faucet"); val fz = 60.0; val r0 = 85.0; val top = wt + 320
        rod(w, fp, Triple(cx, wt, fz), Triple(cx, wt + 40, fz), 24.0)
        rod(w, fp, Triple(cx, wt + 40, fz), Triple(cx, top, fz), 12.0)
        val segs = if (light) 5 else 9
        for (k in 0 until segs) {
            val t0 = PI - PI * k / segs; val t1 = PI - PI * (k + 1) / segs
            rod(w, fp, Triple(cx, top + r0 * sin(t0), fz + r0 + r0 * cos(t0)), Triple(cx, top + r0 * sin(t1), fz + r0 + r0 * cos(t1)), 12.0)
        }
        rod(w, fp, Triple(cx, top, fz + 2 * r0), Triple(cx, top - 60, fz + 2 * r0), 12.0, 10.0)
        box(w, fp, cx + 24, cx + 84, wt + 114, wt + 126, 54, 66)
    }

    /** A black glass hob with its rings (mockup drawHob): two large burners and two small ones, the touch controls. */
    private fun hob(w: WallBasis, cx: Double) {
        val a0 = cx - 295; val n0 = 35.0
        box(w, dark, a0, cx + 295, wt, wt + 6, n0, n0 + 520)
        val y = (wt + 6.4) / 1000; val ring = p("ring")
        fun annulus(ca: Double, cn: Double, r: Double, wd: Double) {
            val k = if (light) 20 else 32
            for (i in 0 until k) {
                val t0 = 2 * PI * i / k; val t1 = 2 * PI * (i + 1) / k
                fun pt(rr: Double, tt: Double) = w.at((ca + rr * cos(tt)) / 1000, y, (cn + rr * sin(tt)) / 1000)
                flatFace(ring, listOf(pt(r - wd, t0), pt(r - wd, t1), pt(r, t1), pt(r, t0)), UP)
            }
        }
        listOf(Triple(171.0, 156.0, 95.0), Triple(425.0, 146.0, 72.0), Triple(165.0, 385.0, 72.0), Triple(419.0, 364.0, 95.0)).forEach { (u, v, r) ->
            annulus(a0 + u, n0 + v, r, 3.0)
            if (!light) annulus(a0 + u, n0 + v, r * .62, 1.6)
        }
        if (!light) for (i in 0 until 7) { val u = a0 + 190 + i * 35; box(w, ring, u - 3, u + 3, wt + 6, wt + 6.4, n0 + 488, n0 + 494) }
    }

    /** A built-in oven's black glass door [a0]..[a1], [b0]..[b1] at [n0]: its window, the steel strip, knobs, display, handle (mockup). */
    private fun oven(w: WallBasis, a0: Double, a1: Double, b0: Double, b1: Double, n0: Double) {
        val h = b1 - b0; val f0 = n0 + 22
        box(w, dark, a0, a1, b0, b1, n0, f0, true)
        box(w, p("ovenWin"), a0 + 35, a1 - 35, b0 + 60, b0 + 60 + h * .52, f0, f0 + 1.2)
        box(w, metal, a0, a1, b1 - 75, b1, f0, f0 + 3)
        listOf(a0 + 60, a1 - 60).forEach { kx -> rod(w, metal, Triple(kx, b1 - 37, f0 + 3), Triple(kx, b1 - 37, f0 + 21), 17.0) }
        val cx = (a0 + a1) / 2
        if (!light) box(w, p("display"), cx - 55, cx + 55, b1 - 52, b1 - 22, f0 + 3, f0 + 4)
        bar(Frame(w.at(a0 / 1000, b0 / 1000, f0 / 1000), w.dir(1.0, 0.0), UP, w.dir(0.0, 1.0)), (a1 - a0) / 2, h - 120, 0.0, a1 - a0 - 90, false, metal)
    }

    /** A microwave in its niche: black glass, a window, its display. */
    private fun micro(w: WallBasis, a0: Double, a1: Double, b0: Double, d: Double) {
        box(w, dark, a0, a1, b0, b0 + 290, 40, d - 10, true)
        box(w, p("ovenWin"), a0 + 30, a0 + (a1 - a0) * .66, b0 + 50, b0 + 240, d - 10, d - 8.8)
        if (!light) box(w, p("display"), a0 + (a1 - a0) * .75, a0 + (a1 - a0) * .9, b0 + 200, b0 + 225, d - 10, d - 9)
    }

    /** A hood's steel visor under its unit, a black glass front and two lamps underneath. */
    private fun hood(w: WallBasis, a0: Double, a1: Double, y0: Double, d: Double) {
        box(w, metal, a0 + 10, a1 - 10, y0 - 70, y0, 30, d + 40, true)
        box(w, dark, a0 + 10, a1 - 10, y0 - 70, y0, d + 40, d + 48)
        val cx = (a0 + a1) / 2; val n = (30 + d + 40) / 2
        listOf(cx - 140, cx + 140).forEach { a -> rod(w, p("lamp"), Triple(a, y0 - 74, n), Triple(a, y0 - 70, n), 26.0) }
    }

    /* ---------------- the worktop, crown and light (the lit 3D) ---------------- */

    /**
     * A worktop [a0]..[a1] along, [n0]..[n1] out (its top at [wt], [wtT] thick) with a slightly rounded front edge and
     * the sinks' cut-outs [holes]; its picture runs on unbroken over the pieces round a cut-out.
     */
    fun worktop(w: WallBasis, a0: Double, a1: Double, n0: Double, n1: Double, holes: List<DoubleArray>) {
        val y0 = wt - wtT; val y1 = wt; val r = if (wtT > 30) 6.0 else 3.0
        val org = w.at(a0 / 1000, y0 / 1000, n0 / 1000); val along = w.dir(1.0, 0.0)
        val tp = top
        fun slab(s0: Double, s1: Double, m0: Double, m1: Double, nose: Boolean) {
            if (s1 - s0 < .1 || m1 - m0 < .1) return
            if (!nose) { box(w, tp, s0, s1, y0, y1, m0, m1, grain = along, org = org); return }
            box(w, tp, s0, s1, y0, y1, m0, m1 - r, grain = along, org = org)
            // the front edge: a quarter round of radius r along the top
            val prof = listOf(m1 - r to y0, m1 to y0) + (0..3).map { k -> val th = PI / 2 * k / 3; (m1 - r + r * cos(th)) to (y1 - r + r * sin(th)) }
            prismFaces(tp, prof.map { (n, y) -> w.at(s0 / 1000, y / 1000, n / 1000) }, w.dir((s1 - s0) / 1000, 0.0))
        }
        var cur = a0
        holes.sortedBy { it[0] }.forEach { h ->
            if (h[0] < cur || h[1] > a1) return@forEach
            slab(cur, h[0], n0, n1, true); slab(h[0], h[1], n0, h[2], false); slab(h[0], h[1], h[3], n1, true)
            cur = h[1]
        }
        slab(cur, a1, n0, n1, true)
        obbEdges(slabEdges, Obb(w.at(a0 / 1000, y0 / 1000, n0 / 1000), w.dir((a1 - a0) / 1000, 0.0), V3(0.0, (y1 - y0) / 1000, 0.0), w.dir(0.0, (n1 - n0) / 1000)))
    }

    /**
     * A cornice along the tops of [tops] (wall and tall units on one wall [wl] mm long): three profiled layers of the
     * upper fronts' board, 76 mm high, each further out (mockup cornice); over each stretch of touching boxes of one
     * height and depth, carried past an end that stands in the room.
     */
    fun cornice(w: WallBasis, tops: List<Module>, wl: Int) {
        val pc = role("frontUp")
        val groups = ArrayList<MutableList<Module>>()
        tops.forEach { m ->
            val last = groups.lastOrNull()?.last()
            if (last != null && kotlin.math.abs(last.x + last.w - m.x) < 3 && last.elev + last.h == m.elev + m.h && last.d == m.d) groups.last() += m else groups += mutableListOf(m)
        }
        groups.forEach { gm ->
            val a0 = gm.first().x.toDouble(); val a1 = gm.last().x + gm.last().w.toDouble(); val y = (gm.first().elev + gm.first().h).toDouble(); val d = gm.first().d.toDouble()
            val freeA = a0 > 20; val freeB = a1 < wl - 20
            listOf(Triple(0.0, 22.0, 10.0), Triple(22.0, 58.0, 26.0), Triple(58.0, 76.0, 38.0)).forEach { (h0, h1, out) ->
                box(w, pc, if (freeA) a0 - out else a0, if (freeB) a1 + out else a1, y + h0, y + h1, 0, d + out, true)
            }
        }
    }

    /** The top row over box [m]: a unit up to [ceil] mm, its lift-up flap of the box's fronts' board (mockup crown "ceiling"). */
    fun ceilingUnit(w: WallBasis, m: Module, ceil: Int) {
        val x0 = m.x.toDouble(); val x1 = x0 + m.w; val y0 = (m.elev + m.h).toDouble(); val d = m.d.toDouble(); val h = ceil - y0
        if (h < 100) return
        val c = role("carcass")
        box(w, c, x0, x0 + t, y0, y0 + h, 0, d, true); box(w, c, x1 - t, x1, y0, y0 + h, 0, d, true)
        box(w, c, x0 + t, x1 - t, y0, y0 + t, 0, d, true); box(w, c, x0 + t, x1 - t, y0 + h - t, y0 + h, 0, d, true)
        box(w, role("back"), x0 + t, x1 - t, y0 + t, y0 + h - t, 0, 3)
        if (bare) return
        panel(w, role(fr, "fp.door"), x0 + edge, m.w - 2 * edge, y0 + g / 2, h - g, d, if (m.handles) "flap" else "", "${m.id}:top")
    }

    /**
     * The LED strips' soft warm light: on the backsplash under the wall units [lit] (eight bands fading downwards), and
     * faintly on the worktop at the wall (mockup glow; the light tier has none).
     */
    fun glow(w: WallBasis, lit: List<Module>, wt: Int) {
        val nn = V3(w.nx, 0.0, w.nz)
        // over each stretch of touching wall units of one height
        val runs = ArrayList<MutableList<Module>>()
        lit.sortedBy { it.x }.forEach { m -> val l = runs.lastOrNull()?.last(); if (l != null && kotlin.math.abs(l.x + l.w - m.x) < 5 && l.elev == m.elev) runs.last() += m else runs += mutableListOf(m) }
        runs.forEach { r ->
            val a0 = r.first().x + 20.0; val a1 = r.last().x + r.last().w - 20.0; val top = r.first().elev.toDouble()
            fun q(b0: Double, b1: Double, n: Double) = listOf(w.at(a0 / 1000, b0 / 1000, n), w.at(a1 / 1000, b0 / 1000, n), w.at(a1 / 1000, b1 / 1000, n), w.at(a0 / 1000, b1 / 1000, n))
            // eight bands, 40 mm each, fainter downwards (each its own see-through look: GLOW)
            GLOW.forEachIndexed { i, _ -> val b1 = top - i * 40.0; val b0 = max(wt + 1.0, b1 - 40); if (b1 > b0) flatFace(p("glow$i"), q(b0, b1, .0068), nn) }
            // on the worktop, fading out from the wall (short of a sink's cut-out, 100 mm from the wall)
            val y = (wt + .6) / 1000
            listOf(7.0 to 35.0, 35.0 to 65.0, 65.0 to 95.0).forEachIndexed { i, (n0, n1) ->
                flatFace(p("glowTop$i"), listOf(w.at(a0 / 1000, y, n0 / 1000), w.at(a1 / 1000, y, n0 / 1000), w.at(a1 / 1000, y, n1 / 1000), w.at(a0 / 1000, y, n1 / 1000)), UP)
            }
        }
    }

    /** A vanity's basin on its top, the tap behind it. */
    fun basin(w: WallBasis, m: Module) {
        if (rich && basinLit(this, w, m)) return
        // a wall-hung vanity's top is its height above the floor up
        val top = m.elev + uz.metrx.app.furniture.legsOf(m, ws) + m.h
        val mid = m.x + m.w / 2.0; val bw = minOf(500.0, m.w - 120.0); val bd = minOf(380.0, m.d - 80.0)
        if (bw < 200 || bd < 200) return
        val n0 = (m.d - bd) / 2 + 20
        box(w, white, mid - bw / 2, mid + bw / 2, top, top + 130, n0, n0 + bd, true)
        box(w, metal, mid - 15, mid + 15, top, top + 230, n0 - 45, n0 - 15, true)
        box(w, metal, mid - 12, mid + 12, top + 200, top + 225, n0 - 15, n0 + 90, true)
    }

    /**
     * A wardrobe (and every cabinet on its engine): sides (none at a wall), top and bottom, plinth or legs, dividers,
     * backs, inside, doors. In the lit 3D (modern 3D part 5, the mockup's buildKupe): the doors in the design's style
     * with its handles, mirrors in their tint, glass doors in frames; round legs in the handles' colour; chrome rails,
     * glass shelves, inner drawers in the fronts' look; the LED inside ([ledLook] with door sensors, a vitrina's always
     * on) and its glow; the cornice or the panel up to the ceiling ([crown]); sliding doors in aluminium profiles.
     */
    fun wardrobe(w: WallBasis, m: Module) {
        val x0 = m.x.toDouble(); val x1 = x0 + m.w; val d = m.d.toDouble()
        // sliding doors take the front of the depth: the inside is shallower
        val di = uz.metrx.app.furniture.innerD(m).toDouble()
        // on legs, on a plinth, or hung (its bottom above the floor)
        val z0 = uz.metrx.app.furniture.legsOf(m, ws).toDouble() + m.elev
        val base = wardBase(m).toDouble()
        val yb = z0 + base; val yt = z0 + m.h
        val sl = if (m.sideL) t else 0; val sr = if (m.sideR) t else 0
        // a kupe's outer sides, top and plinth in the fronts' board, as the parts list cuts them (Wardrobe.kt wardRole)
        val sideP = role(uz.metrx.app.furniture.wardRole(m, "fp.side"), "fp.side")
        if (m.sideL) box(w, sideP, x0, x0 + t, z0, yt, 0, d, true)
        if (m.sideR) box(w, sideP, x1 - t, x1, z0, yt, 0, d, true)
        // the bottom under every section but a desk's knee space (a wardrobe's top and bottom are one part, a desk's
        // bottoms their own, a kupe's bottom its own: its top is of the fronts' board)
        val ownTop = uz.metrx.app.furniture.wardRole(m, "fp.top") != "carcass"
        if (m.sections.none { it.knee }) box(w, role("carcass", if (ownTop) "fp.bottom" else "fp.top"), x0 + sl, x1 - sr, yb, yb + t, 0, d, true)
        else { var a = x0; m.sections.forEach { s -> if (!s.knee) box(w, role("carcass", "fp.bottom"), maxOf(a, x0 + sl), minOf(a + s.w, x1 - sr), yb, yb + t, 0, d, true); a += s.w } }
        box(w, role(uz.metrx.app.furniture.wardRole(m, "fp.top"), "fp.top"), x0 + sl, x1 - sr, yt - t, yt, 0, d, true)
        if (!m.legs) box(w, role(uz.metrx.app.furniture.wardRole(m, "fp.plinth"), "fp.plinth"), x0 + sl, x1 - sr, z0, z0 + wardBase(m), d - 60, d - 44, true)
        // on legs: a pair under each side and each divider, as the hardware list counts them
        // (none at an end without a side: a corner desk's second arm rests on the first there)
        else ((if (m.sideL) listOf(x0 + 20) else emptyList()) + m.sections.runningFold(x0) { a, s -> a + s.w }.drop(1).dropLast(1).map { it - 18 } +
            (if (m.sideR) listOf(x1 - 56) else emptyList())).forEach { a ->
            // the lit 3D: round legs, a little wider at the foot, in the handles' colour
            if (rich) listOf(58.0, d - 58).forEach { n -> rod(w, p("legs"), Triple(a + 18, 0.0, n), Triple(a + 18, z0, n), 15.0, 13.0) }
            else { box(w, metal, a, a + 36, 0, z0, 40, 76); box(w, metal, a, a + 36, 0, z0, d - 76, d - 40) }
        }
        var acc = x0
        val secs = m.sections
        secs.forEachIndexed { i, s ->
            val a0 = acc; val a1 = acc + s.w
            sec = ""
            if (i > 0) {
                // beside a knee space the divider stands on the floor (or the legs) like a side
                val toFloor = s.knee || secs[i - 1].knee
                box(w, role("carcass", "fp.divider"), a0 - t / 2.0, a0 + t / 2.0, if (toFloor) z0 else yb + t, yt - t, 0, if (toFloor) d else di, true)
            }
            sec = "${i + 1}"
            if (s.knee) { acc = a1; return@forEachIndexed }
            val iw = wardInner(m, secs, i, t)
            val il = if (i == 0) a0 + sl else a0 + t / 2.0
            // the back sits in grooves between the sides (or dividers), the bottom and the top
            box(w, role("back", "fp.back"), il, il + iw, yb + t, yt - t, 0, 3)
            val floor = yb + t
            s.inserts.forEach { x ->
                val y = floor + x.pos
                when (x.kind) {
                    "shelf" -> box(w, role("carcass", "fp.shelf"), il, il + iw, y, y + t, 3, di - 17, true)
                    "glass" -> box(w, p(if (rich) "shelfGlass" else "clear"), il, il + iw, y, y + 6, 3, di - 17, true)
                    "rail" -> if (rich) rail(w, il, iw.toDouble(), y, di / 2) else box(w, metal, il + 5, il + iw - 5, y - 12, y + 12, di / 2 - 12, di / 2 + 12)
                    "lift" -> { box(w, metal, il + 20, il + iw - 20, y + 30, y + 54, di / 2 - 12, di / 2 + 12); box(w, metal, il + 5, il + 25, y + 54, y + blockH(x), di / 2 - 15, di / 2 + 15) }
                    // in an open section the drawer's face is seen: front board, flush with the carcass, with a handle
                    "drawer" -> if (s.fronts.kind == "open") drawer(w, "${m.id}:s$i:d${x.pos}", il + 2, iw - 4.0, y, blockH(x).toDouble(), di - t, di - 60, uz.metrx.app.furniture.drawerHandle(m, x), "front")
                        // behind the doors: its own handle, or a push latch (Handles.kt)
                        else drawer(w, "${m.id}:s$i:d${x.pos}", il + 4, iw - 8.0, y, blockH(x).toDouble(), di - 40 - t, di - 60, uz.metrx.app.furniture.drawerHandle(m, x), "carcass")
                    else -> {
                        // trouser and shoe racks: a frame that pulls out
                        val rk = "${m.id}:s$i:r${x.pos}"
                        keys += rk
                        // within the inside's depth: in a sliding wardrobe the doors run in front of it
                        moving(rk, { Motion.move(w.dir(0.0, di * .7 / 1000)) }) {
                            val out = di * .7 * how(rk)
                            val h = blockH(x).toDouble()
                            val o = w.at((il + 13) / 1000, y / 1000, (20 + out) / 1000)
                            val bx = Obb(o, w.dir((iw - 26) / 1000.0, 0.0), V3(0.0, h / 1000, 0.0), w.dir(0.0, (di - 60) / 1000))
                            obbEdges(edges, bx); picks += Pick(rk, bx)
                            box(w, metal, il + 13, il + iw - 13, y, y + 10, 20 + out, di - 40 + out)
                            for (k in 1..4) { val yy = if (x.kind == "shoe") y + h * k / 5 else y + h - 12; val nn = 20 + out + (di - 60) * k / 5
                                box(w, metal, il + 13, il + iw - 13, yy, yy + 8, nn - 6, nn) }
                        }
                    }
                }
            }
            // the section's doors over its width, from the bottom panel up
            val fs = frontSizes(s.fronts, uz.metrx.app.furniture.frontW(s), m.h - wardBase(m), ws)
            if (s.fronts.kind == "door" && m.slide == null) fs.forEachIndexed { j, (fh, fw) ->
                val a = a0 + edge + j * (fw + g)
                // a pair hinges on its outer edges; single doors pair up two by two, the last one hinged on the wardrobe's end
                val right = if (fs.size == 2) j == 1 else uz.metrx.app.furniture.hingeRight(m, i)
                // only a hinge at the piece's free end opens wide; beside a divider, a wall or a neighbour it stops at 90°
                val wide = if (right) i == secs.lastIndex && j == fs.lastIndex && freeR else i == 0 && j == 0 && freeL
                door(w, "${m.id}:s$i:f$j", if (right) a + fw else a, d, yb + edge, fh.toDouble(), fw.toDouble(), if (right) -1 else 1, uz.metrx.app.furniture.doorHandle(m, i, j),
                    (1000 - yb).coerceIn(minOf(150.0, fh / 2.0), maxOf(fh / 2.0, fh - 150.0)), deg = if (wide) OPEN_DEG else SHUT_DEG, face = s.face)
            }
            // the LED inside, along the section's front: lit while a door before it is open (its door sensor), seeing
            // inside, behind glass doors and in a vitrina (always on); off, a plain aluminium strip, behind shut doors
            if (rich && (m.led || ledLook)) {
                val always = bare || m.led || s.face == "glass" || (m.slide == null && s.fronts.kind != "door")
                // the doors whose sensors light it: the sliding doors, else the section's own
                val deps = m.slide?.let { sd -> (0 until sd.n.coerceIn(2, 4)).map { "${m.id}:slide$it" } } ?: fs.indices.map { "${m.id}:s$i:f$it" }
                val tops = s.inserts.filter { it.kind == "shelf" || it.kind == "glass" }.map { floor + it.pos + if (it.kind == "glass") 6.0 else t.toDouble() } + floor
                val ly = ledY(m, s, floor, yt)
                // split: both, the lit one shown while a door is open, the plain strip while all are shut
                if (split && !always) {
                    toggle(deps, true) { ledIn(w, il, iw.toDouble(), ly, di, floor, true, tops) }
                    toggle(deps, false) { ledIn(w, il, iw.toDouble(), ly, di, floor, false, tops) }
                } else ledIn(w, il, iw.toDouble(), ly, di, floor, always || deps.any { how(it) > .02 }, tops)
            }
            acc = a1
        }
        sec = ""
        // the 2D painter: a vitrina's light along the inside of its top
        if (m.led && !rich) box(w, p("led"), x0 + sl + 10, x1 - sr - 10, yt - t - 8, yt - t, di - 70, di - 50)
        m.slide?.let { sl -> slidingDoors(w, m, sl, x0 + sl0(m), yb + t, d) }
        // on top of a tall box standing on the floor: the cornice, or a panel up to the ceiling; in front of the doors
        if (crown.isNotEmpty() && !uz.metrx.app.furniture.hung(m) && yt >= 1800) wardCrown(w, x0, x1, yt, if (m.slide != null) d else d + t)
    }

    /**
     * Where a section's LED goes (its top, mm above the floor): a vitrina's under its top; the design's under the
     * lowest shelf from 1600 mm up (the hat shelf over the rail, the mockup's), else under the top.
     */
    private fun ledY(m: Module, s: uz.metrx.app.furniture.Section, floor: Double, yt: Double): Double {
        if (!m.led) s.inserts.filter { it.kind == "shelf" || it.kind == "glass" }.map { floor + it.pos }.filter { it >= 1600 && it <= yt - t - 150 }.minOrNull()?.let { return it }
        return yt - t
    }

    /**
     * A LED strip [il]..+[iw] along a section, its top at [y], near the front of the inside ([di] deep); [lit]: glowing,
     * and its soft light on the back panel under it (eight bands, fainter downwards, to the section's [floor]) and on
     * the tops of the shelves [tops] (mm above the floor) within 640 mm under it, fainter further down. The light tier
     * has none.
     */
    private fun ledIn(w: WallBasis, il: Double, iw: Double, y: Double, di: Double, floor: Double, lit: Boolean, tops: List<Double> = emptyList()) {
        box(w, p(if (lit) "led" else "ledOff"), il + 20, il + iw - 20, y - 8, y, di - 70, di - 52)
        if (!lit || light) return
        val nn = V3(w.nx, 0.0, w.nz); val a0 = (il + 2) / 1000; val a1 = (il + iw - 2) / 1000
        val ua = V3(w.ux, 0.0, w.uz); val n1 = (di - 20) / 1000
        WGLOW.forEachIndexed { i, _ ->
            val b1 = y - 8 - i * 70.0; val b0 = max(floor + 1, b1 - 70)
            if (b1 <= b0) return@forEachIndexed
            val B0 = b0 / 1000; val B1 = b1 / 1000
            flatFace(p("wglow$i"), listOf(w.at(a0, B0, .0045), w.at(a1, B0, .0045), w.at(a1, B1, .0045), w.at(a0, B1, .0045)), nn)
            // and on the section's two sides (the side or divider each end), which the view sees past the open door
            flatFace(p("wglow$i"), listOf(w.at(a0 - .0015, B0, .004), w.at(a0 - .0015, B0, n1), w.at(a0 - .0015, B1, n1), w.at(a0 - .0015, B1, .004)), ua)
            flatFace(p("wglow$i"), listOf(w.at(a1 + .0015, B0, .004), w.at(a1 + .0015, B1, .004), w.at(a1 + .0015, B1, n1), w.at(a1 + .0015, B0, n1)), ua * -1.0)
        }
        tops.filter { it < y - 30 && it > y - 640 }.forEach { yy ->
            val k = ((y - yy) / 80).toInt().coerceIn(1, WGLOW.lastIndex)
            val h = (yy + .6) / 1000
            flatFace(p("wglow$k"), listOf(w.at(a0, h, .004), w.at(a1, h, .004), w.at(a1, h, (di - 20) / 1000), w.at(a0, h, (di - 20) / 1000)), UP)
        }
    }

    /** A chrome hanging rail [il]..+[iw] at [y] (its middle), [n] out from the wall, on a flange at each end. */
    private fun rail(w: WallBasis, il: Double, iw: Double, y: Double, n: Double) {
        val pr = p("rail")
        rod(w, pr, Triple(il + 2, y, n), Triple(il + iw - 2, y, n), 12.5)
        if (!light) listOf(il to il + 3, il + iw - 3 to il + iw).forEach { (a, b) -> rod(w, pr, Triple(a, y, n), Triple(b, y, n), 18.0) }
    }

    /**
     * On top of a wardrobe [x0]..[x1] whose top is [yt], its front [front] mm out from the wall: the cornice (three
     * profiled layers of the upper fronts' board, 76 mm high, each further out, carried past a free end: as the
     * kitchen's) or a panel of that board up to 4 mm under the ceiling ([ceilH]; none when less than 20 mm is left).
     */
    fun wardCrown(w: WallBasis, x0: Double, x1: Double, yt: Double, front: Double) {
        val pc = role("frontUp")
        if (crown == "ceiling") { val top = ceilH - 4; if (top - yt >= 20) box(w, pc, x0, x1, yt, top, 0, front, true, up = true); return }
        if (crown != "cornice") return
        listOf(Triple(0.0, 22.0, 10.0), Triple(22.0, 58.0, 26.0), Triple(58.0, 76.0, 38.0)).forEach { (h0, h1, out) ->
            box(w, pc, if (freeL) x0 - out else x0, if (freeR) x1 + out else x1, yt + h0, yt + h1, 0, front + out, true)
        }
    }

    private fun sl0(m: Module) = if (m.sideL) t else 0

    /**
     * The lit 3D's sliding doors (mockup buildKupe / kupeDoor): the top track (30 mm) and the bottom one (12 mm) in the
     * profiles' colour across the opening ([ax] along, from [y0] up, the front at [d]); each door in its track (the
     * even ones in front, the odd ones behind, 34 mm deep), each overlapping the next; a frame of aluminium profiles in
     * the handles' colour (uprights 42 wide, the top rail 30, the bottom one 50) and a split rail at [kupeSplit]. Below
     * the split the door's own filling: the front board in its style, a mirror in its tint, lacobel in the fronts'
     * colour; above it the upper fronts' board. A tapped door slides over its neighbour.
     */
    private fun slidingRich(w: WallBasis, m: Module, sl: uz.metrx.app.furniture.Slide, ax: Double, y0: Double, d: Double) {
        val n = sl.n.coerceIn(2, 4)
        val (dw0, dh0) = uz.metrx.app.furniture.slideDoor(m, t)
        val dw = dw0.toDouble(); val dh = dh0.toDouble()
        val (ow, oh) = uz.metrx.app.furniture.slideOpening(m, t)
        val step = dw - uz.metrx.app.furniture.SLIDE_OV
        val pf = p("frame")
        val yTop = y0 + oh
        box(w, pf, ax, ax + ow, yTop - 30, yTop, d - 98, d - 2, true); box(w, pf, ax, ax + ow, y0, y0 + 12, d - 98, d - 2, true)
        val y = y0 + uz.metrx.app.furniture.SLIDE_CLEAR / 2.0
        // the price's rule too (Wardrobe.kt kupeSplit, kupeFillH)
        val split = uz.metrx.app.furniture.kupeSplit(m, t, dh, y - y0)
        val pw = min(42.0, dw / 6); val rt = 30.0; val rb = 50.0; val pd = 34.0
        for (j in 0 until n) {
            val key = "${m.id}:slide$j"
            keys += key
            // a door slides one step towards the middle: the last one left, the others right (split: built shut, moved along)
            moving(key, { Motion.move(w.dir((if (j == n - 1) -step else step) / 1000, 0.0)) }) { slideRichAt(w, sl, key, j, n, ax, y, d, dw, dh, step, split, pw, rt, rb, pd) }
        }
    }

    /** Sliding door [j] of [n] (the part of [slidingRich] each door moves with); [split] the kupe split rail's height, mm. */
    private fun slideRichAt(w: WallBasis, sl: uz.metrx.app.furniture.Slide, key: String, j: Int, n: Int, ax: Double, y: Double, d: Double, dw: Double, dh: Double,
                            step: Double, split: Double?, pw: Double, rt: Double, rb: Double, pd: Double) {
        val pf = p("frame")
        run {
            val shift = (if (j == n - 1) -step else step) * how(key)
            val a = ax + j * step + shift
            val n0 = if (j % 2 == 0) d - 56 else d - 93
            val ff = Frame(w.at(a / 1000, y / 1000, n0 / 1000), w.dir(1.0, 0.0), UP, w.dir(0.0, 1.0))
            fbox(ff, pf, 0.0, pw, 0.0, dh, 0.0, pd, true); fbox(ff, pf, dw - pw, dw, 0.0, dh, 0.0, pd, true)
            fbox(ff, pf, pw, dw - pw, dh - rt, dh, 4.0, pd - 4, true, ff.e); fbox(ff, pf, pw, dw - pw, 0.0, rb, 4.0, pd - 4, true, ff.e)
            if (split != null) fbox(ff, pf, pw, dw - pw, split - 7, split + 7, 6.0, pd - 6, true, ff.e)
            fun fill(v0: Double, v1: Double, kind: String, board: String, k: String = "fp.slidePanel") {
                if (v1 - v0 < 1) return
                when (kind) {
                    "mirror" -> { fbox(ff, p("mirror"), pw, dw - pw, v0, v1, 13.0, 19.0, false); sheen(ff, pw, dw - pw, v0, v1, 19.5) }
                    "glass" -> fbox(ff, p("lacobel"), pw, dw - pw, v0, v1, 13.0, 19.0, false)
                    else -> frontBody(Frame(ff.at(pw, v0, 12.0), ff.e, ff.up, ff.tn), role(board, k), dw - 2 * pw, v1 - v0, 10.0, ff.up)
                }
            }
            if (split == null) fill(rb, dh - rt, sl.panel(j), fr)
            else { fill(rb, split - 7, sl.panel(j), fr); fill(split + 7, dh - rt, "ldsp", "frontUp", "fp.slideUp") }
            picks += Pick(key, ff.obb(0.0, dw, 0.0, dh, 0.0, pd))
        }
    }

    /** A box of Gorka3D.kt: in its own look (one part for each wall and look) or the piece's board of its role; turned round its middle. */
    fun xbox(w: WallBasis, x: XBox) {
        val p = x.look?.let { lk -> val wl = if (wall == ISLAND) null else wall
            parts.getOrPut(wl to lk) { Part(0, wl, Role.FURN, lk.rgb, if (lk.alpha < 1f) .38f else 1f, look = lk) } } ?: role(x.role, x.key)
        if (x.rotN == 0.0 && x.rotY == 0.0) { box(w, p, x.a0, x.a1, x.y0, x.y1, x.n0, x.n1, x.line, x.up); return }
        val ax = w.dir(1.0, 0.0); val nx = w.dir(0.0, 1.0)
        var a = ax; var y = UP; var n = nx
        if (x.rotN != 0.0) { val r = Math.toRadians(x.rotN); a = ax * cos(r) + UP * sin(r); y = UP * cos(r) - ax * sin(r) }
        if (x.rotY != 0.0) { val r = Math.toRadians(x.rotY); val a2 = a * cos(r) + nx * sin(r); n = nx * cos(r) - a * sin(r); a = a2 }
        val sa = (x.a1 - x.a0) / 1000; val sy = (x.y1 - x.y0) / 1000; val sn = (x.n1 - x.n0) / 1000
        val c = w.at((x.a0 + x.a1) / 2000, (x.y0 + x.y1) / 2000, (x.n0 + x.n1) / 2000)
        obb(p, Obb(c - a * (sa / 2) - y * (sy / 2) - n * (sn / 2), a * sa, y * sy, n * sn), x.line)
    }

    /**
     * How a lift-up bed's base rises (split): 38° about the line along wall frame [w] at [pivotY] up and [pivotN] out
     * (mm), its far side going up ([tilted], Items3D.kt Pen.at).
     */
    fun liftMotion(w: WallBasis, pivotY: Double, pivotN: Double) =
        Motion.turn(w.at(0.0, pivotY / 1000, pivotN / 1000), cross(UP, w.dir(0.0, -1.0)), Math.toRadians(38.0))

    /** A box [b] of an item, tilted [th] about a line across it at [pivotY] up and [pivotN] out (a lift-up bed's base rising). */
    private fun tilted(w: WallBasis, p: Part, x0: Int, b: uz.metrx.app.furniture.Board, pivotY: Double, pivotN: Double, th: Double, line: Boolean) {
        val c = cos(th); val s = sin(th)
        fun pt(y: Double, n: Double): Pair<Double, Double> { val dy = y - pivotY; val dn = n - pivotN; return (pivotY + dn * s + dy * c) to (pivotN + dn * c - dy * s) }
        val (oy, on) = pt(b.y0.toDouble(), b.n0.toDouble())
        val lb = (b.y1 - b.y0) / 1000.0; val lc = (b.n1 - b.n0) / 1000.0
        val up = V3(0.0, 1.0, 0.0)
        obb(p, Obb(w.at((x0 + b.a0) / 1000.0, oy / 1000, on / 1000), w.dir((b.a1 - b.a0) / 1000.0, 0.0),
            w.dir(0.0, -lb * s) + up * (lb * c), w.dir(0.0, lc * c) + up * (lc * s)), line)
    }

    /** A table top's rounded corner [r]: a cross of two boards and an octagon in each corner. */
    private fun roundTop(w: WallBasis, p: Part, x0: Int, b: uz.metrx.app.furniture.Board) {
        val r = b.round; val a0 = x0 + b.a0; val a1 = x0 + b.a1
        box(w, p, a0 + r, a1 - r, b.y0, b.y1, b.n0, b.n1, true); box(w, p, a0, a1, b.y0, b.y1, b.n0 + r, b.n1 - r, true)
        val up = V3(0.0, (b.y1 - b.y0) / 1000.0, 0.0); val R = r / 1000.0; val q = R * .7071
        listOf(a0 + r to b.n0 + r, a1 - r to b.n0 + r, a0 + r to b.n1 - r, a1 - r to b.n1 - r).forEach { (ca, cn) ->
            val c = w.at(ca / 1000.0, b.y0 / 1000.0, cn / 1000.0)
            obb(p, Obb(c - w.dir(q, q), w.dir(2 * q, 0.0), up, w.dir(0.0, 2 * q)), false)
            obb(p, Obb(c - w.dir(R, 0.0), w.dir(R, -R), up, w.dir(R, R)), false)
        }
    }

    /* ---------------- the lit items' port (Items3D.kt draws beds, tables, mirror panels and the basin with it) ---------------- */

    /** The piece being built and the workshop's materials: Items3D.kt reads the piece's design from them. */
    var itemPiece: Furniture? = null; var itemMats: List<Mat> = MAT_PRESETS
    /** A part in a look of its own (fabrics, bedding, ceramic): one for each wall and look. */
    fun lookPart(lk: Look): Part {
        val wl = if (wall == ISLAND) null else wall
        return parts.getOrPut(wl to lk) { Part(0, wl, Role.FURN, lk.rgb, if (lk.alpha < 1f) .38f else 1f, look = lk) }
    }
    fun tube(p: Part, a: V3, b: V3, r0: Double, r1: Double, n: Int) = tubeFaces(p, a, b, r0, r1, n)
    fun flat(p: Part, q: List<V3>, n: V3) = flatFace(p, q, n)
    /** A front [fw] × [fh] in the piece's style, its corner at [o], across [e], out of it [tn]: how far its face stands out, mm. */
    fun styledFront(o: V3, e: V3, tn: V3, p: Part, fw: Double, fh: Double, grain: V3?): Double = frontBody(Frame(o, e, UP, tn), p, fw, fh, t.toDouble(), grain)

    /**
     * A bed, a table, a bar counter, a mirror panel or a mirror: its boards (Items.kt); a bed's drawers pull out of its
     * long sides and a lift-up base rises on a tap.
     */
    fun item(w: WallBasis, m: Module) {
        if (rich && itemLit(this, w, m)) return
        val x0 = m.x
        val bs = uz.metrx.app.furniture.itemBoards(m, ws)
        val liftKey = "${m.id}:lift"
        val lifts = bs.any { it.lift }
        if (lifts) keys += liftKey
        val th = Math.toRadians(38.0) * (if (lifts) how(liftKey) else 0.0)
        val pivotY = (m.h - uz.metrx.app.furniture.BED_SINK - 30).toDouble(); val pivotN = t + 4.0
        bs.forEach { b ->
            fun draw() {
                val part = when (b.role) { "carcass" -> role("carcass", b.key); "top" -> top; "metal" -> metal; "white" -> white; "mattress" -> p("mattress"); "lamel" -> p("lamel"); "mirror" -> p("mirror"); else -> role(fr, b.key) }
                val line = b.key.isNotEmpty() || b.role == "mirror"
                when {
                    b.lift && th > 1e-6 -> tilted(w, part, x0, b, pivotY, pivotN, th, line)
                    b.round > 0 -> roundTop(w, part, x0, b)
                    else -> box(w, part, x0 + b.a0, x0 + b.a1, b.y0, b.y1, b.n0, b.n1, line)
                }
            }
            // split: what rises is built down and turned with the lift-up base
            if (b.lift) moving(liftKey, { liftMotion(w, pivotY, pivotN) }) { draw() } else draw()
        }
        if (lifts) bs.firstOrNull { it.role == "mattress" }?.let { b ->
            picks += Pick(liftKey, Obb(w.at((x0 + b.a0) / 1000.0, b.y0 / 1000.0, b.n0 / 1000.0), w.dir((b.a1 - b.a0) / 1000.0, 0.0), V3(0.0, (b.y1 - b.y0) / 1000.0, 0.0), w.dir(0.0, (b.n1 - b.n0) / 1000.0)))
        }
        // a bed's drawers: each side's own frame, along the bed and out of that side
        uz.metrx.app.furniture.bedDrawers(m, ws).forEachIndexed { i, dr ->
            val right = dr.side > 0
            val o = w.at((x0 + if (right) m.w else 0) / 1000.0, 0.0, (if (right) m.d else 0) / 1000.0)
            val sb = if (right) WallBasis(o.x, o.z, -w.nx, -w.nz, w.ux, w.uz, m.d / 1000.0) else WallBasis(o.x, o.z, w.nx, w.nz, -w.ux, -w.uz, m.d / 1000.0)
            val a = if (right) m.d - dr.n1 else dr.n0
            drawer(sb, "${m.id}:bd$i", a.toDouble(), (dr.n1 - dr.n0).toDouble(), dr.y0.toDouble(), (dr.y1 - dr.y0).toDouble(), -t.toDouble(), dr.depth.toDouble(), uz.metrx.app.furniture.hasHandle(m, "bd$i"))
        }
    }

    /**
     * Sliding doors: [n] in two tracks at the front, each overlapping the next; a frame of profiles round its filling
     * (board, mirror or glass). A tapped door slides over its neighbour.
     */
    fun slidingDoors(w: WallBasis, m: Module, sl: uz.metrx.app.furniture.Slide, ax: Double, y0: Double, d: Double) {
        if (bare) return
        if (rich) { slidingRich(w, m, sl, ax, y0, d); return }
        val n = sl.n.coerceIn(2, 4)
        val (dw, dh) = uz.metrx.app.furniture.slideDoor(m, t)
        val step = (dw - uz.metrx.app.furniture.SLIDE_OV).toDouble()
        for (j in 0 until n) {
            val key = "${m.id}:slide$j"
            keys += key
            // a door slides one step towards the middle: the last one left, the others right (split: built shut, moved along)
            moving(key, { Motion.move(w.dir((if (j == n - 1) -step else step) / 1000, 0.0)) }) {
                val shift = (if (j == n - 1) -step else step) * how(key)
                val a = ax + j * step + shift
                val n0 = d - 95 + (j % 2) * 45; val n1 = n0 + 22
                val y = y0 + uz.metrx.app.furniture.SLIDE_CLEAR / 2.0
                val fill = when (sl.panel(j)) { "mirror" -> p("mirror"); "glass" -> p("glass"); else -> role(fr, "fp.slidePanel") }
                val fw = uz.metrx.app.furniture.SLIDE_FRAME_W.toDouble(); val fh = uz.metrx.app.furniture.SLIDE_FRAME_H / 2.0
                box(w, fill, a + fw, a + dw - fw, y + fh, y + dh - fh, n0 + 6, n1 - 6, true, up = true)
                // the frame: two uprights, the top and the bottom
                box(w, metal, a, a + fw, y, y + dh, n0, n1, true); box(w, metal, a + dw - fw, a + dw, y, y + dh, n0, n1, true)
                box(w, metal, a + fw, a + dw - fw, y, y + fh, n0, n1, true); box(w, metal, a + fw, a + dw - fw, y + dh - fh, y + dh, n0, n1, true)
                val o = w.at(a / 1000, y / 1000, n0 / 1000)
                picks += Pick(key, Obb(o, w.dir(dw / 1000.0, 0.0), V3(0.0, dh / 1000.0, 0.0), w.dir(0.0, (n1 - n0) / 1000.0)))
            }
        }
    }
}
