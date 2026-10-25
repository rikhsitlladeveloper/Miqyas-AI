package uz.metrx.app.geo

import uz.metrx.app.furniture.Furniture
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
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/*
 * Furniture in the room's 3D scene (furniture plan section 9): every board a box in its material's colour, on its
 * wall's frame ([WallBasis]). Doors swing open about 100°, drawers pull out; [Furn3D.picks] are what a tap can open.
 * Plain colours until Stage 3. Sizes come in millimetres and go out in metres.
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

class Furn3D(val parts: List<Part>, val edges: List<Edges>, val picks: List<Pick>, val keys: List<String>)

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
private val UP = V3(0.0, 1.0, 0.0)

/**
 * The faces of a box, each facing out, with texture coordinates in metres: u along the grain, which runs along
 * [grain] (one of the box's edges, or a direction) or else the box's longest edge (a board's long side).
 */
private fun obbFaces(p: Part, x: Obb, grain: V3? = null) {
    val ctr = x.o + (x.a + x.b + x.c) * .5
    val g = (grain ?: listOf(x.a, x.b, x.c).maxBy { it.len() }).unit()
    val (offU, offV) = grainOffset(x.o)
    fun along(e: V3) = kotlin.math.abs(e.unit().dot(g)) > .99
    fun face(q: List<V3>, e1: V3, e2: V3) {
        val fc = V3(q.sumOf { it.x } / 4, q.sumOf { it.y } / 4, q.sumOf { it.z } / 4)
        var n = (q[1] - q[0]).let { u -> (q[3] - q[0]).let { v -> V3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x) } }.unit()
        if (n.dot(fc - ctr) < 0) n = n * -1.0
        // the grain along the face's edge that follows it, else along its longer edge (a board's end)
        val first = along(e1) || (!along(e2) && e1.len() >= e2.len())
        val ua = (if (first) e1 else e2).unit(); val va = (if (first) e2 else e1).unit()
        p.faces += Face(n, q, uv = uvOf(q, x.o, ua, va, offU, offV))
    }
    val o = x.o; val a = x.a; val b = x.b; val c = x.c
    face(listOf(o, o + a, o + a + b, o + b), a, b); face(listOf(o + c, o + c + a, o + c + a + b, o + c + b), a, b)
    face(listOf(o, o + c, o + c + b, o + b), c, b); face(listOf(o + a, o + a + c, o + a + c + b, o + a + b), c, b)
    face(listOf(o, o + a, o + a + c, o + c), a, c); face(listOf(o + b, o + b + a, o + b + a + c, o + b + c), a, c)
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
    "fp.panel", "fp.filler", "fp.slidePanel", "fp.dSide", "fp.dFront", "fp.dBottom", "fp.endLow", "fp.endUp")
private const val HI = 0xF59E0B

/** A handle's length along its door or drawer, mm: the piece's handle type (a knob, a long bar, the usual 128 skoba). */
fun handleLen(id: String) = when (id) { "handleKnob" -> 24; "handleLong" -> 320; else -> 128 }

fun furniture3D(fs: List<Furniture>, bases: Map<String, WallBasis>, ws: Workshop, rgb: (String) -> Int, open: Set<String>,
                amt: ((String) -> Double)? = null,
                /** "See inside": no doors, drawer fronts or sliding doors (the drawers' boxes stay, shut). */
                bare: Boolean = false, hi: PartHi? = null,
                /**
                 * How a material id (a board, the worktop, the splashback) looks in the lit 3D: its colour, finish and
                 * decor picture. Without it, a matte board in its [rgb] colour.
                 */
                look: ((String) -> Look)? = null): Furn3D {
    // how far each door or drawer is open, 0 to 1 (moving between the two while it opens or shuts)
    val how = amt ?: { k: String -> if (k in open) 1.0 else 0.0 }
    val parts = LinkedHashMap<Pair<String?, Any>, Part>(); val edges = LinkedHashMap<String?, Edges>()
    val picks = ArrayList<Pick>(); val keys = ArrayList<String>()
    val matLook = look ?: { id: String -> Looks.board(rgb(id)) }
    fs.forEach { f ->
        val colors = mapOf("carcass" to rgb(f.mats.carcass), "front" to rgb(f.mats.front), "back" to rgb(f.mats.back), "top" to rgb("wt38"),
            "mirror" to MIRROR, "glass" to GLASS_P, "splash" to rgb("splash6"),
            "metal" to METAL, "dark" to DARK, "handle" to HANDLE, "white" to WHITE,
            "clear" to CLEAR, "mattress" to MATTRESS, "lamel" to LAMEL, "led" to LED, "hi" to HI)
        // the same keys' looks: the boards from the workshop's list, the rest fixed (mockup mats())
        val top = look?.invoke("wt38") ?: Looks.worktop(rgb("wt38"))
        val looks = mapOf("carcass" to matLook(f.mats.carcass), "front" to matLook(f.mats.front), "back" to matLook(f.mats.back).copy(rough = .85f),
            "top" to top, "mirror" to Looks.mirror, "glass" to Looks.lacobel, "splash" to (look?.invoke("splash6") ?: Looks.plain(rgb("splash6")).copy(rough = .3f)),
            "metal" to Looks.steel, "dark" to Looks.blackGlass, "handle" to Looks.handle, "white" to Looks.enamel,
            "clear" to Looks.clearGlass, "mattress" to Looks.mattress, "lamel" to Looks.lamel, "led" to Looks.led, "hi" to Looks.hi)
        val fws = uz.metrx.app.furniture.wsOf(f, ws)
        val B = Builder3(fws, colors, looks, parts, edges, picks, keys, how)
        B.bare = bare; B.hi = hi; B.piece = f.id; B.hLen = handleLen(f.handle).toDouble()
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
            if (m.type == "wardrobe") {
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
        }
        // the worktop over the lower row of each wall (and over the corner it turns into)
        if (f.kind == "kitchen") {
            val wt = worktopTop(fws)
            val rs = runsOf(f) { id -> bases[id]?.let { (it.len * 1000).toInt() } }
            rs.forEach { r ->
                val b = (if (r.wall == ISLAND) island else bases[r.wall]) ?: return@forEach
                B.wall = r.wall
                val low = f.modules.filter { it.wall == r.wall && !isUpper(it) && (it.type == "base" || it.type == "filler" || it.app == "dishwasher") }.sortedBy { it.x }
                val isl = r.wall == ISLAND
                // one worktop over each stretch of touching units, no joint every unit; the corner square is the first
                // side's. An island's (a peninsula's) covers its cabinets and its finished back, no more.
                val n0 = if (isl) -uz.metrx.app.furniture.PEN_BACK else 0
                var a0 = -1; var a1 = -1
                fun piece() { if (a1 > a0) { B.box(b, B.top, a0, a1, wt - K_TOP, wt, n0, 600, true); if (isl) B.box(b, B.front, a0, a1, 0, wt - K_TOP, -18, 0, true) } }
                low.forEach { m -> if (a0 >= 0 && m.x <= a1 + 1) a1 = maxOf(a1, m.x + m.w) else { piece(); a0 = m.x; a1 = m.x + m.w } }
                // a peninsula in its usual place: the side's worktop runs on over the peninsula's finished back to its outer edge
                if (f.layout == "P" && f.pose == null && r == rs.firstOrNull { it.wall != ISLAND } && a1 > a0) a1 += uz.metrx.app.furniture.PEN_BACK
                piece()
                // end panels where a row ends in the open room (not against a wall): the lower row's, the wall units'
                val kx0 = f.kx
                if (kx0 != null && low.isNotEmpty()) {
                    val lo = low.first().x; val hi = low.maxOf { it.x + it.w }
                    val wl = if (isl) null else (b.len * 1000).toInt()
                    // a peninsula's side ends at the peninsula, which covers it: no end panel there
                    val penSide = f.layout == "P" && r == rs.firstOrNull { it.wall != ISLAND }
                    val ends = if (isl) listOf(lo to (f.layout != "P"), hi to true) else listOf(lo to (lo > 20), hi to (wl != null && hi < wl - 20 && !penSide))
                    // the end panels are parts of no module (KitchenExtras.extrasParts): lit up from the parts list by their own name
                    val sm = B.mod; val ss = B.sec; B.mod = ""; B.sec = ""
                    if (kx0.ends > 0) ends.forEach { (a, free) -> if (free) B.box(b, B.role("front", "fp.endLow"), if (a == lo) a - 18 else a, if (a == lo) a else a + 18, 0, wt - K_TOP, 0, 600, true, up = true) }
                    val up = f.modules.filter { it.wall == r.wall && it.type == "wall" }
                    if (kx0.endsUp > 0 && up.isNotEmpty() && wl != null) {
                        val u0 = up.minOf { it.x }; val u1 = up.maxOf { it.x + it.w }; val y0 = up.minOf { it.elev }; val y1 = up.maxOf { it.elev + it.h }; val d = up.maxOf { it.d }
                        if (u0 > 20) B.box(b, B.role("front", "fp.endUp"), u0 - 18, u0, y0, y1, 0, d, true, up = true)
                        if (u1 < wl - 20) B.box(b, B.role("front", "fp.endUp"), u1, u1 + 18, y0, y1, 0, d, true, up = true)
                    }
                    B.mod = sm; B.sec = ss
                }
                // extras: the backsplash panel on the wall over the worktop, the cornice on the wall units
                val kx = f.kx
                if (kx != null && r.wall != ISLAND) {
                    val a0 = if (r.lowStart > 0) 0 else low.minOfOrNull { it.x } ?: 0
                    val a1 = low.maxOfOrNull { it.x + it.w } ?: 0
                    if (kx.splash > 0 && a1 > a0) B.box(b, B.splash, a0, a1, wt, wt + kx.splash, 0, 6, true)
                    if (kx.cornice) f.modules.filter { it.wall == r.wall && it.type == "wall" }.forEach { m ->
                        B.box(b, B.front, m.x, m.x + m.w, m.elev + m.h, m.elev + m.h + 60, 0, m.d + 30, true)
                    }
                }
            }
        }
    }
    return Furn3D(parts.values.toList(), edges.values.toList(), picks, keys)
}

/** Builds the boards of one piece of furniture on a wall frame; lengths in mm. */
private class Builder3(
    val ws: Workshop, val colors: Map<String, Int>, val looks: Map<String, Look>, val parts: LinkedHashMap<Pair<String?, Any>, Part>, val edgeMap: LinkedHashMap<String?, Edges>,
    val picks: ArrayList<Pick>, val keys: ArrayList<String>, val how: (String) -> Double
) {
    /**
     * The wall being furnished: the furniture on a wall that faces the camera goes see-through with it (an island's
     * never does). Parts are one per wall and colour, so opening a door does not change how many there are.
     */
    var wall: String? = null
    /** The piece being built has nothing past its left / right end (no wall, no neighbour): a door hinged there opens wide. */
    var freeL = false; var freeR = false
    /** See inside (no fronts); what to light up; the piece and module (and section) being built, as Parts.kt names them; the handles' length. */
    var bare = false; var hi: PartHi? = null; var piece = ""; var mod = ""; var sec = ""; var hLen = 128.0
    /** Board [k] of role [r] (carcass, front, back) being drawn: in the highlight's colour when it is the part asked for. */
    fun role(r: String, k: String = ""): Part {
        val h = hi ?: return p(r)
        val inMod = "$piece|$mod" in h.mods || (sec.isNotEmpty() && "$piece|$mod/$sec" in h.mods)
        val dBox = h.key == "fp.dSide" || h.key == "fp.dFront" || h.key == "fp.dBottom"
        val named = h.key !in TAGGED || k == h.key || (dBox && k == "fp.dBox")
        return if (inMod && named && (h.role == r || dBox)) p("hi") else p(r)
    }
    private fun p(k: String): Part {
        val c = colors.getValue(k); val w = if (wall == ISLAND) null else wall
        val lk = looks.getValue(k)
        // the worktop is a part of its own (even in the fronts' colour): its top and outline are drawn as a slab
        if (k == "top") return parts.getOrPut(("top|" + (w ?: "")) to lk) { Part(0, w, Role.FURN, c, 1f, slab = true, look = lk) }
        // clear glass is seen through; one part for each wall and look (a colour in two finishes is two parts)
        return parts.getOrPut(w to lk) { Part(0, w, Role.FURN, c, if (k == "clear") .38f else 1f, look = lk) }
    }
    val carcass get() = role("carcass"); val front get() = role("front"); val back get() = role("back"); val top get() = p("top")
    val metal get() = p("metal"); val dark get() = p("dark"); val handle get() = p("handle"); val white get() = p("white")
    val splash get() = p("splash")
    val edges get() = (if (wall == ISLAND) null else wall).let { w -> edgeMap.getOrPut(w) { Edges(0, "furn " + (w ?: "island")) } }

    val t = ws.t
    val g = ws.gap10 / 10.0; val edge = ws.edge10 / 10.0

    /** The worktop's light outline, kept apart from the dark one of the boards. */
    private val slabEdges get() = (if (wall == ISLAND) null else wall).let { w -> edgeMap.getOrPut("top|" + (w ?: "")) { Edges(0, "furn " + (w ?: "island"), SLAB_LINE) } }

    /** A box of [p]; its grain along [grain] (null: its long side). */
    fun obb(p: Part, x: Obb, line: Boolean, grain: V3? = null) { obbFaces(p, x, grain); if (line) obbEdges(if (p.slab) slabEdges else edges, x) }

    /**
     * An upright box [a0]..[a1] along the wall, [y0]..[y1] up, [n0]..[n1] out from the wall; [up] its grain upright
     * (fronts cut with the grain along their height, Parts.kt), else along its long side.
     */
    fun box(w: WallBasis, p: Part, a0: Number, a1: Number, y0: Number, y1: Number, n0: Number, n1: Number, line: Boolean = false, up: Boolean = false) {
        val A0 = a0.toDouble() / 1000; val A1 = a1.toDouble() / 1000; val Y0 = y0.toDouble() / 1000; val Y1 = y1.toDouble() / 1000
        val N0 = n0.toDouble() / 1000; val N1 = n1.toDouble() / 1000
        if (A1 - A0 < 1e-4 || Y1 - Y0 < 1e-4 || N1 - N0 < 1e-4) return
        obb(p, Obb(w.at(A0, Y0, N0), w.dir(A1 - A0, 0.0), V3(0.0, Y1 - Y0, 0.0), w.dir(0.0, N1 - N0)), line, if (up) UP else null)
    }

    /**
     * A door hinged at [ha] (the back corner of its hinge edge), [fw] wide, opening to the right ([s] +1) or left (-1);
     * its handle's middle [hy] above the door's bottom.
     */
    fun door(w: WallBasis, key: String, ha: Double, n: Double, y0: Double, h: Double, fw: Double, s: Int, handles: Boolean, hy: Double, p0: Part? = null,
             deg: Double = SHUT_DEG, face: String = "") {
        // seeing inside: no doors at all
        if (bare) return
        val p = p0 ?: role("front", "fp.door")
        keys += key
        val th = Math.toRadians(deg) * how(key)
        val e = w.dir(s * cos(th), sin(th)); val tn = w.dir(-s * sin(th), cos(th))
        val o = w.at(ha / 1000, y0 / 1000, n / 1000)
        val x = Obb(o, e * (fw / 1000), V3(0.0, h / 1000, 0.0), tn * (t / 1000.0))
        val up = V3(0.0, 1.0, 0.0)
        when (face) {
            // glass in an aluminium frame: the frame's four sides round a clear pane
            "glass" -> {
                val fr = .02; val W = fw / 1000; val H = h / 1000; val T = t / 1000.0
                obb(metal, Obb(o, e * fr, up * H, tn * T), true); obb(metal, Obb(o + e * (W - fr), e * fr, up * H, tn * T), true)
                obb(metal, Obb(o + e * fr, e * (W - 2 * fr), up * fr, tn * T), true); obb(metal, Obb(o + e * fr + up * (H - fr), e * (W - 2 * fr), up * fr, tn * T), true)
                obb(p("clear"), Obb(o + e * fr + up * fr + tn * (T / 2 - .002), e * (W - 2 * fr), up * (H - 2 * fr), tn * .004), false)
                picks += Pick(key, x)
            }
            // a mirror on the board door's face
            "mirror" -> { obb(p, x, true, up); obb(p("mirror"), Obb(o + e * .005 + up * .005 + tn * (t / 1000.0), e * (fw / 1000 - .01), up * (h / 1000 - .01), tn * .004), false); picks += Pick(key, x) }
            // a door's grain runs up it
            else -> { obb(p, x, true, up); picks += Pick(key, x) }
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
        val out = if (bare) 0.0 else d * .75 * how(key)
        val nn = n + out
        val o = w.at(a0 / 1000, y0 / 1000, nn / 1000)
        val x = Obb(o, w.dir(fw / 1000, 0.0), V3(0.0, fh / 1000, 0.0), w.dir(0.0, t / 1000.0))
        // seeing inside, an inner drawer's face (behind a door, of the carcass board) stays: only fronts go
        // a drawer front's grain runs across it (Parts.kt: its length is its width)
        if (!bare || pr != "front") { obb(role(pr, "fp.dFace"), x, true, x.a); if (!bare) picks += Pick(key, x) }
        if (box && (out > 0 || bare)) {
            val bh = min(fh - 40, 150.0).coerceAtLeast(60.0); val bx0 = a0 + 26; val bx1 = a0 + fw - 26; val by = y0 + 20
            val c = role("carcass", "fp.dBox")
            box(w, c, bx0, bx1, by, by + 12, nn - d + 40, nn)
            box(w, c, bx0, bx0 + 12, by, by + bh, nn - d + 40, nn); box(w, c, bx1 - 12, bx1, by, by + bh, nn - d + 40, nn)
            box(w, c, bx0, bx1, by, by + bh, nn - d + 40, nn - d + 52)
        }
        if (handles && !bare) {
            val hc = a0 + fw / 2
            // a long handle is no longer than the front less 40 mm
            val hl = min(hLen, max(20.0, fw - 40))
            val hh = if (hl < 60) hl / 1000 else .012
            obb(handle, Obb(w.at((hc - hl / 2) / 1000, (y0 + fh - min(40.0, fh / 3)) / 1000, (nn + t) / 1000), w.dir(hl / 1000, 0.0), V3(0.0, hh, 0.0), w.dir(0.0, .025)), false)
        }
    }

    /** A kitchen unit: base, wall or tall carcass with its fronts; appliance spaces and fillers. */
    fun kitchenUnit(w: WallBasis, m: Module) {
        val x0 = m.x.toDouble(); val x1 = x0 + m.w; val y0 = m.elev.toDouble(); val y1 = y0 + m.h; val d = m.d.toDouble()
        when (m.type) {
            // a strip of front board flush with the row's fronts
            "filler" -> { val fn = if (isUpper(m)) K_WALL_D.toDouble() else K_BASE_D.toDouble(); box(w, role("front", "fp.filler"), x0, x1, y0, y1, fn, fn + t, true, up = true); return }
            "gap" -> {
                when (m.app) {
                    "fridge" -> {
                        box(w, white, x0 + 5, x1 - 5, 0, m.h, 0, d, true)
                        val split = m.h * .64
                        box(w, metal, x0 + 5, x1 - 5, split - 4, split + 4, d, d + 2)
                        box(w, handle, x0 + 30, x0 + 42, split + 120, split + 420, d, d + 25); box(w, handle, x0 + 30, x0 + 42, split - 420, split - 120, d, d + 25)
                    }
                    "dishwasher" -> {
                        box(w, metal, x0 + 3, x1 - 3, y0, y1 - 10, 0, d - 20)
                        if (!bare) frontSizes(m.fronts, m.w, m.h, ws).firstOrNull()?.let { (fh, fw) ->
                            box(w, role("front", if (m.fronts.kind == "panel") "fp.panel" else "fp.door"), x0 + edge, x0 + edge + fw, y0 + edge, y0 + edge + fh, d, d + t, true, up = true)
                            if (uz.metrx.app.furniture.hasHandle(m, "f0")) box(w, handle, x0 + m.w / 2.0 - hLen / 2, x0 + m.w / 2.0 + hLen / 2, y0 + edge + fh - 46, y0 + edge + fh - 34, d + t, d + t + 25)
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
        // a plinth under base and tall units on legs
        if (m.legs && m.type != "wall" && y0 > 0) box(w, metal, x0, x1, 0, y0 - 2, d - 70, d - 54)
        // fronts
        val fs = frontSizes(m.fronts, m.w, m.h, ws)
        // an oven housing: the oven in its niche (800 to 1395 from the floor), a door under it and one over it
        val ovenNiche = m.app == "oven" && m.fronts.kind == "door" && fs.size == 1
        when (m.fronts.kind) {
            "door" -> if (ovenNiche) {
                val fw = fs[0].second.toDouble(); val lo = 800 - g / 2 - (y0 + edge); val y2 = 1395 + g / 2
                // the housing's one door in the lists: both halves follow its handle
                val hd = uz.metrx.app.furniture.hasHandle(m, "f0")
                door(w, "${m.id}:f0", x0 + edge, d, y0 + edge, lo, fw, 1, hd, lo - 90)
                door(w, "${m.id}:f1", x0 + edge, d, y2, y1 - edge - y2, fw, 1, hd, 90.0)
            } else fs.forEachIndexed { j, (fh, fw) ->
                val n = fs.size
                val a = x0 + edge + j * (fw + g)
                // single doors hinge on the left; pairs on the outer edges
                val right = n == 2 && j == 1
                // handles near the top of a low door, near the bottom of a wall unit's, at 1 m on a tall one
                val hy = when { m.type == "wall" -> 90.0; fh > 1200 -> (1000 - y0).coerceIn(minOf(150.0, fh / 2.0), maxOf(fh / 2.0, fh - 150.0)); else -> fh - 90.0 }
                door(w, "${m.id}:f$j", if (right) a + fw else a, d, y0 + edge, fh.toDouble(), fw.toDouble(), if (right) -1 else 1, uz.metrx.app.furniture.hasHandle(m, "f$j"), hy)
            }
            "drawer", "panel" -> {
                var y = y1 - edge
                fs.forEachIndexed { j, (fh, fw) ->
                    y -= fh
                    if (m.fronts.kind == "drawer") drawer(w, "${m.id}:f$j", x0 + edge, fw.toDouble(), y, fh.toDouble(), d, d, uz.metrx.app.furniture.hasHandle(m, "f$j"))
                    else if (!bare) box(w, role("front", "fp.panel"), x0 + edge, x0 + edge + fw, y, y + fh, d, d + t, true, up = true)
                    y -= g
                }
            }
        }
        // what shows the appliance
        val cx = (x0 + x1) / 2; val wt = worktopTop(ws).toDouble()
        when (m.app) {
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

    /** A wardrobe: sides (none at a wall), top and bottom, plinth, dividers, backs, inside, doors. */
    /** A vanity's basin on its top, the tap behind it. */
    fun basin(w: WallBasis, m: Module) {
        // a wall-hung vanity's top is its height above the floor up
        val top = m.elev + uz.metrx.app.furniture.legsOf(m, ws) + m.h
        val mid = m.x + m.w / 2.0; val bw = minOf(500.0, m.w - 120.0); val bd = minOf(380.0, m.d - 80.0)
        if (bw < 200 || bd < 200) return
        val n0 = (m.d - bd) / 2 + 20
        box(w, white, mid - bw / 2, mid + bw / 2, top, top + 130, n0, n0 + bd, true)
        box(w, metal, mid - 15, mid + 15, top, top + 230, n0 - 45, n0 - 15, true)
        box(w, metal, mid - 12, mid + 12, top + 200, top + 225, n0 - 15, n0 + 90, true)
    }

    fun wardrobe(w: WallBasis, m: Module) {
        val x0 = m.x.toDouble(); val x1 = x0 + m.w; val d = m.d.toDouble()
        // sliding doors take the front of the depth: the inside is shallower
        val di = uz.metrx.app.furniture.innerD(m).toDouble()
        // on legs, on a plinth, or hung (its bottom above the floor)
        val z0 = uz.metrx.app.furniture.legsOf(m, ws).toDouble() + m.elev
        val base = wardBase(m).toDouble()
        val yb = z0 + base; val yt = z0 + m.h
        val sl = if (m.sideL) t else 0; val sr = if (m.sideR) t else 0
        if (m.sideL) box(w, role("carcass", "fp.side"), x0, x0 + t, z0, yt, 0, d, true)
        if (m.sideR) box(w, role("carcass", "fp.side"), x1 - t, x1, z0, yt, 0, d, true)
        // the bottom under every section but a desk's knee space (a wardrobe's top and bottom are one part, a desk's bottoms their own)
        if (m.sections.none { it.knee }) box(w, role("carcass", "fp.top"), x0 + sl, x1 - sr, yb, yb + t, 0, d, true)
        else { var a = x0; m.sections.forEach { s -> if (!s.knee) box(w, role("carcass", "fp.bottom"), maxOf(a, x0 + sl), minOf(a + s.w, x1 - sr), yb, yb + t, 0, d, true); a += s.w } }
        box(w, role("carcass", "fp.top"), x0 + sl, x1 - sr, yt - t, yt, 0, d, true)
        if (!m.legs) box(w, role("carcass", "fp.plinth"), x0 + sl, x1 - sr, z0, z0 + wardBase(m), d - 60, d - 44, true)
        // on legs: a pair under each side and each divider, as the hardware list counts them
        // (none at an end without a side: a corner desk's second arm rests on the first there)
        else ((if (m.sideL) listOf(x0 + 20) else emptyList()) + m.sections.runningFold(x0) { a, s -> a + s.w }.drop(1).dropLast(1).map { it - 18 } +
            (if (m.sideR) listOf(x1 - 56) else emptyList())).forEach { a ->
            box(w, metal, a, a + 36, 0, z0, 40, 76); box(w, metal, a, a + 36, 0, z0, d - 76, d - 40)
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
                    "glass" -> box(w, p("clear"), il, il + iw, y, y + 6, 3, di - 17, true)
                    "rail" -> box(w, metal, il + 5, il + iw - 5, y - 12, y + 12, di / 2 - 12, di / 2 + 12)
                    "lift" -> { box(w, metal, il + 20, il + iw - 20, y + 30, y + 54, di / 2 - 12, di / 2 + 12); box(w, metal, il + 5, il + 25, y + 54, y + blockH(x), di / 2 - 15, di / 2 + 15) }
                    // in an open section the drawer's face is seen: front board, flush with the carcass, with a handle
                    "drawer" -> if (s.fronts.kind == "open") drawer(w, "${m.id}:s$i:d${x.pos}", il + 2, iw - 4.0, y, blockH(x).toDouble(), di - t, di - 60, uz.metrx.app.furniture.drawerHandle(m, x), "front")
                        // behind the doors: its own handle, or a push latch (Handles.kt)
                        else drawer(w, "${m.id}:s$i:d${x.pos}", il + 4, iw - 8.0, y, blockH(x).toDouble(), di - 40 - t, di - 60, uz.metrx.app.furniture.drawerHandle(m, x), "carcass")
                    else -> {
                        // trouser and shoe racks: a frame that pulls out
                        keys += "${m.id}:s$i:r${x.pos}"
                        // within the inside's depth: in a sliding wardrobe the doors run in front of it
                        val out = di * .7 * how("${m.id}:s$i:r${x.pos}")
                        val h = blockH(x).toDouble()
                        val o = w.at((il + 13) / 1000, y / 1000, (20 + out) / 1000)
                        val bx = Obb(o, w.dir((iw - 26) / 1000.0, 0.0), V3(0.0, h / 1000, 0.0), w.dir(0.0, (di - 60) / 1000))
                        obbEdges(edges, bx); picks += Pick("${m.id}:s$i:r${x.pos}", bx)
                        box(w, metal, il + 13, il + iw - 13, y, y + 10, 20 + out, di - 40 + out)
                        for (k in 1..4) { val yy = if (x.kind == "shoe") y + h * k / 5 else y + h - 12; val nn = 20 + out + (di - 60) * k / 5
                            box(w, metal, il + 13, il + iw - 13, yy, yy + 8, nn - 6, nn) }
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
            acc = a1
        }
        sec = ""
        // a vitrina's light along the inside of its top
        if (m.led) box(w, p("led"), x0 + sl + 10, x1 - sr - 10, yt - t - 8, yt - t, di - 70, di - 50)
        m.slide?.let { sl -> slidingDoors(w, m, sl, x0 + sl0(m), yb + t, d) }
    }

    private fun sl0(m: Module) = if (m.sideL) t else 0

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

    /**
     * A bed, a table, a bar counter, a mirror panel or a mirror: its boards (Items.kt); a bed's drawers pull out of its
     * long sides and a lift-up base rises on a tap.
     */
    fun item(w: WallBasis, m: Module) {
        val x0 = m.x
        val bs = uz.metrx.app.furniture.itemBoards(m, ws)
        val liftKey = "${m.id}:lift"
        val lifts = bs.any { it.lift }
        if (lifts) keys += liftKey
        val th = Math.toRadians(38.0) * (if (lifts) how(liftKey) else 0.0)
        val pivotY = (m.h - uz.metrx.app.furniture.BED_SINK - 30).toDouble(); val pivotN = t + 4.0
        bs.forEach { b ->
            val part = when (b.role) { "carcass" -> role("carcass", b.key); "top" -> top; "metal" -> metal; "white" -> white; "mattress" -> p("mattress"); "lamel" -> p("lamel"); "mirror" -> p("mirror"); else -> role("front", b.key) }
            val line = b.key.isNotEmpty() || b.role == "mirror"
            when {
                b.lift && th > 1e-6 -> tilted(w, part, x0, b, pivotY, pivotN, th, line)
                b.round > 0 -> roundTop(w, part, x0, b)
                else -> box(w, part, x0 + b.a0, x0 + b.a1, b.y0, b.y1, b.n0, b.n1, line)
            }
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
        val n = sl.n.coerceIn(2, 4)
        val (dw, dh) = uz.metrx.app.furniture.slideDoor(m, t)
        val step = (dw - uz.metrx.app.furniture.SLIDE_OV).toDouble()
        for (j in 0 until n) {
            val key = "${m.id}:slide$j"
            keys += key
            // a door slides one step towards the middle: the last one left, the others right
            val shift = (if (j == n - 1) -step else step) * how(key)
            val a = ax + j * step + shift
            val n0 = d - 95 + (j % 2) * 45; val n1 = n0 + 22
            val y = y0 + uz.metrx.app.furniture.SLIDE_CLEAR / 2.0
            val fill = when (sl.panel(j)) { "mirror" -> p("mirror"); "glass" -> p("glass"); else -> role("front", "fp.slidePanel") }
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
