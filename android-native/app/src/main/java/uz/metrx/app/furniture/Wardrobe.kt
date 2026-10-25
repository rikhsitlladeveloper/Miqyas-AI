package uz.metrx.app.furniture

import uz.metrx.app.data.Opening
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.pointSize
import uz.metrx.app.data.uid
import kotlin.math.max
import kotlin.math.roundToInt

/*
 * Wardrobe design rules (furniture plan section 8; design canvas screen 11). Pure Kotlin, unit-tested (WardrobeTest).
 *
 * A wardrobe is one module of type "wardrobe" on a wall: [Module.x] from the wall's start corner, its carcass split
 * into sections. Inside each section, shelves and rails are lines at a height; drawers, pull-out racks and the lift are
 * blocks. Heights are from the section's floor (the top of the bottom panel).
 */

/** Gaps left to the walls and the ceiling when the wardrobe fills a niche. */
const val W_GAP_SIDE = 10
const val W_GAP_TOP = 20
const val W_DEPTH = 600

/** How tall an insert is: blocks have a height ([Insert.h], or their usual one); shelves and rails are lines (0). */
fun blockH(x: Insert): Int = when (x.kind) {
    "drawer" -> x.h.takeIf { it > 0 } ?: 200
    "trouser" -> x.h.takeIf { it > 0 } ?: 120
    "shoe" -> x.h.takeIf { it > 0 } ?: 140
    "lift" -> x.h.takeIf { it > 0 } ?: 800
    else -> 0
}

/** Section widths: locked ones keep theirs; the others share what is left equally, the last one takes the remainder. */
fun splitSections(w: Int, secs: List<Section>): List<Section> {
    if (secs.size == 1) return listOf(secs[0].copy(w = w))
    val free = secs.count { !it.lock }
    if (free == 0 && secs.sumOf { it.w } == w) return secs
    val rest = w - secs.filter { it.lock }.sumOf { it.w }
    // the locked ones leave too little for the others (or none gives way): all share again
    if (free == 0 || rest < 150 * free) return if (secs.any { it.lock }) splitSections(w, secs.map { it.copy(lock = false) }) else secs
    val each = rest / free
    var k = 0
    return secs.map { s -> if (s.lock) s else { k++; s.copy(w = each + if (k == free) rest - each * free else 0) } }
}

/** About 600 mm a section: 2400 → 4, 1200 → 2, 700 → 1. */
fun sectionsFor(w: Int) = max(1, (w + 300) / 600)

/** Shelves evenly between the blocks at the bottom (and above any rail) and the top. */
fun spreadShelves(s: Section, ih: Int, t: Int): Section {
    val n = s.inserts.count { it.kind == "shelf" }
    if (n == 0) return s
    val others = s.inserts.filter { it.kind != "shelf" }
    val blocks = others.filter { blockH(it) > 0 && it.kind != "lift" }.maxOfOrNull { it.pos + blockH(it) } ?: 0
    val rails = others.filter { it.kind == "rail" }.maxOfOrNull { it.pos + 60 } ?: 0
    val lo = max(blocks, rails)
    val top = others.filter { it.kind == "lift" }.minOfOrNull { it.pos } ?: (ih - t)
    val step = (top - lo) / (n + 1)
    val shelves = (1..n).map { k -> Insert("shelf", pos = lo + step * k) }
    return s.copy(inserts = (others + shelves).sortedBy { it.pos })
}

/** Where a new insert of [kind] goes in a section [ih] high inside. */
fun nextPos(kind: String, s: Section, ih: Int, t: Int): Int {
    val ins = s.inserts
    val pos = when (kind) {
        "drawer", "trouser", "shoe" -> ins.filter { blockH(it) > 0 && it.kind != "lift" }.maxOfOrNull { it.pos + blockH(it) } ?: 0
        "rail" -> ins.filter { it.kind == "shelf" }.maxOfOrNull { it.pos - 60 } ?: (ih - 80)
        "lift" -> ih - blockH(Insert("lift")) - 20
        else -> {
            // the middle of the tallest free space
            val edges = ArrayList<Pair<Int, Int>>()
            edges += 0 to 0; edges += ih to ih
            ins.forEach { x -> edges += x.pos to x.pos + max(blockH(x), if (x.kind == "shelf") t else 0) }
            val sorted = edges.sortedBy { it.first }
            var best = 0 to 0
            for (i in 0 until sorted.size - 1) {
                val a = sorted[i].second; val b = sorted[i + 1].first
                if (b - a > best.second - best.first) best = a to b
            }
            (best.first + best.second) / 2
        }
    }
    return pos.coerceIn(0, max(0, ih - max(blockH(Insert(kind)), t)))
}

/* ---------------- sliding doors (plan 1b-2) ---------------- */

/** How far one sliding door overlaps the next, mm. */
const val SLIDE_OV = 30
/** The depth the two tracks take in front of the shelves, mm: shelves, dividers and drawers are this much shallower. */
const val SLIDE_D = 100
/** The profile frame round a door's filling: each side, and top plus bottom together, mm. */
const val SLIDE_FRAME_W = 20
const val SLIDE_FRAME_H = 70
/** Room for the rollers and the top track: a door is this much lower than the opening, mm. */
const val SLIDE_CLEAR = 40

/**
 * A sliding door's frame as the 3D draws it (mockup kupeDoor): the top rail's, the bottom rail's and the split rail's
 * height, mm; a filling goes [KUPE_GROOVE] into each rail's groove (so the whole filling is [SLIDE_FRAME_H] less).
 */
const val KUPE_RAIL_T = 30
const val KUPE_RAIL_B = 50
const val KUPE_RAIL_S = 14
const val KUPE_GROOVE = 5
/** The split rail's middle this far under a door's top when no hat shelf sets it, mm; a door lower than [KUPE_SPLIT_MIN] has none. */
const val KUPE_SPLIT_TOP = 420
const val KUPE_SPLIT_MIN = 1500

/**
 * Where a sliding door of box [m] ([dh] mm high, its bottom [lift] mm over the inside's floor) has its split rail's
 * middle, mm up the door; one rule for the 3D and the price: at the shelf the wardrobe's top storage rests on (its
 * highest shelf between 60 % of the door and 250 mm under its top, the mockup's antresol), else [KUPE_SPLIT_TOP] under
 * its top; a door under [KUPE_SPLIT_MIN] has none (null).
 */
fun kupeSplit(m: Module, t: Int, dh: Double = slideDoor(m, t).second.toDouble(), lift: Double = SLIDE_CLEAR / 2.0): Double? {
    val v = m.sections.flatMap { s -> s.inserts.filter { it.kind == "shelf" } }.map { it.pos + t / 2.0 - lift }.filter { it >= dh * .6 && it <= dh - 250 }.maxOrNull()
    return v ?: if (dh >= KUPE_SPLIT_MIN) dh - KUPE_SPLIT_TOP else null
}

/**
 * The cut heights of a sliding door's fillings of box [m], mm: below its split rail and above it (0 without a split,
 * the whole filling [slidePanel] below): each as drawn between its rails, [KUPE_GROOVE] into each groove. A mirror or
 * lacobel door is mirror or lacobel below only; above it is the upper fronts' board (founder, 25 Oct 2026).
 */
fun kupeFillH(m: Module, t: Int): Pair<Int, Int> {
    val (_, dh) = slideDoor(m, t); val (_, ph) = slidePanel(m, t)
    val s = kupeSplit(m, t, dh.toDouble()) ?: return ph to 0
    val low = (s - KUPE_RAIL_S / 2.0 - KUPE_RAIL_B + 2 * KUPE_GROOVE).roundToInt()
    val up = (dh - KUPE_RAIL_T - s - KUPE_RAIL_S / 2.0 + 2 * KUPE_GROOVE).roundToInt()
    return max(0, low) to max(0, up)
}

/** A sliding wardrobe's (kupe's) outer boards that show: its sides, its top and its plinth (founder, 25 Oct 2026). */
val KUPE_FACES = setOf("fp.side", "fp.top", "fp.plinth")

/**
 * The role board [key] of wardrobe box [m] is cut from and drawn in: a kupe's outer sides, top and plinth are of the
 * fronts' board ("front": the lower one of two colours), its bottom and its inside the carcass's.
 */
fun wardRole(m: Module, key: String): String = if (m.type == "wardrobe" && m.slide != null && key in KUPE_FACES) "front" else "carcass"

/** Doors for a front [w] wide: 2 up to 1600, 3 up to 2600, then 4. */
fun slideDoorsFor(w: Int) = when { w <= 1600 -> 2; w <= 2600 -> 3; else -> 4 }

/** The opening the doors close: between the sides (or the walls) and between the bottom and top panels. */
fun slideOpening(m: Module, t: Int): Pair<Int, Int> =
    (m.w - (if (m.sideL) t else 0) - (if (m.sideR) t else 0)) to (m.h - wardBase(m) - 2 * t)

/** One sliding door, width × height: the opening shared out with the overlaps, less the clearance. */
fun slideDoor(m: Module, t: Int): Pair<Int, Int> {
    val n = (m.slide?.n ?: 2).coerceIn(2, 4)
    val (ow, oh) = slideOpening(m, t)
    return (ow + (n - 1) * SLIDE_OV) / n to (oh - SLIDE_CLEAR)
}

/** A door's filling inside its frame, width × height. */
fun slidePanel(m: Module, t: Int): Pair<Int, Int> = slideDoor(m, t).let { (w, h) -> (w - 2 * SLIDE_FRAME_W) to (h - SLIDE_FRAME_H) }

/** How deep a sliding wardrobe's shelves, dividers and drawers are. */
fun innerD(m: Module) = if (m.slide != null) m.d - SLIDE_D else m.d

/** A new wardrobe [w] × [h] on [wall] at [x]: built in (no sides at the walls) or free-standing, on a plinth. */
fun wardrobeTemplate(ws: Workshop, wall: String, x: Int, w: Int, h: Int, builtIn: Boolean, d: Int = W_DEPTH): Module {
    val n = sectionsFor(w)
    val base = Module(uid(), "wardrobe", w, h, d, x = x, wall = wall, legs = false, sideL = !builtIn, sideR = !builtIn)
    val ih = wardInnerH(base, ws.t)
    // the rail within reach, at most 1800 from the floor, the hat shelf over it; a tall wardrobe keeps a shelf more above
    val rail = minOf(ih - 420, 1800 - wardBase(base) - ws.t)
    val top = ih - (rail + 70 + ws.t)
    val hang = listOf(Insert("rail", pos = rail), Insert("shelf", pos = rail + 70)) + if (top > 500) listOf(Insert("shelf", pos = rail + 70 + ws.t + top / 2)) else emptyList()
    val secs = splitSections(w, List(n) { Section(0) }).mapIndexed { i, s ->
        val doors = Fronts("door", if (s.w >= 600) 2 else 1)
        if (i % 2 == 0) s.copy(fronts = doors, inserts = hang)
        else spreadShelves(s.copy(fronts = doors, inserts = List(5) { Insert("shelf") }), ih, ws.t)
    }
    return base.copy(sections = secs)
}

/** The whole height from the floor: on legs the carcass is [Workshop.legH] up. */
fun outerH(m: Module, ws: Workshop) = m.h + legsOf(m, ws)

/** Whether section [i]'s single door hinges on its right edge (its handle on the left): as chosen, else in pairs from the left, the last on the wardrobe's end. */
fun hingeRight(m: Module, i: Int): Boolean = when (m.sections.getOrNull(i)?.hinge) {
    "R" -> true
    "L" -> false
    else -> i % 2 == 1 || (i > 0 && i == m.sections.lastIndex)
}

/**
 * The side panels [m] needs where it stands on a wall [wallLen] long: an end in the room has one; at a wall a hinged
 * wardrobe keeps its own and a built-in sliding one uses the wall. Standing free ([free]) or on an unknown wall, both.
 */
fun withSides(m: Module, wallLen: Int?, free: Boolean = false): Module {
    if (free || m.slide == null || wallLen == null) return m.copy(sideL = true, sideR = true)
    return m.copy(sideL = m.x > W_GAP_SIDE + 30, sideR = m.x + m.w < wallLen - W_GAP_SIDE - 30)
}

/**
 * A kupe's ends where no wall closes them (founder, 26 Oct 2026). A kupe is built in: it uses the room's walls for its
 * ends. Without a room, standing free ([Furniture.pose]), or at an end that is in the room (not at the wall's corner:
 * [withSides]), it gets an outer side panel there: of the fronts' board ([wardRole]), the kupe's full height and
 * depth, in the 3D, the cut list, the labels and the price like any side. [wallLen] its wall's length (null: none known).
 * Not a kupe: as it is.
 */
fun kupeSides(f: Furniture, m: Module, wallLen: Int?): Module {
    if (m.type != "wardrobe" || m.slide == null) return m
    val free = f.roomId == null || f.pose != null
    return withSides(m, if (free) null else wallLen, free)
}

/**
 * [f] with its kupe's side panels where no wall closes its ends ([kupeSides]): a room-less one-box piece (an older
 * order's kupe was saved without them); [f] itself when nothing changes. A piece in a room keeps what [withSides] gave it.
 */
fun withKupeEnds(f: Furniture): Furniture {
    if (f.roomId != null || f.kind != "wardrobe" || boxes(f).size != 1 || f.modules.none { it.type == "wardrobe" && it.slide != null && !(it.sideL && it.sideR) }) return f
    return f.copy(modules = f.modules.map { kupeSides(f, it, null) })
}

/**
 * The inserts in [order] (bottom first) spread over a section [ih] high: equal gaps, counting each block's height and
 * a shelf's board; a rail keeps 900 mm to hang under it, the ones above it share what is left.
 */
fun respaced(order: List<Insert>, ih: Int, t: Int): List<Insert> {
    fun size(x: Insert) = blockH(x) + if (x.kind == "shelf") t else 0
    fun spread(items: List<Insert>, from: Int, to: Int): List<Insert> {
        val gap = ((to - from - items.sumOf { size(it) }).toDouble() / (items.size + 1)).coerceAtLeast(0.0)
        var y = from.toDouble()
        return items.map { x -> y += gap; val p = y.roundToInt(); y += size(x); x.copy(pos = p) }
    }
    var out = spread(order, 0, ih)
    for (i in out.indices) {
        if (out[i].kind != "rail") continue
        val below = if (i == 0) 0 else out[i - 1].pos + size(out[i - 1])
        if (out[i].pos - below >= 900) continue
        val p = minOf(below + 900, ih - 60).coerceAtLeast(out[i].pos)
        out = out.take(i) + out[i].copy(pos = p) + spread(out.drop(i + 1), p + 30, ih)
    }
    return out
}

/**
 * What is wrong with wardrobe [m] on its wall ([wallL] long, the room [roomH] high), with the wall's [openings] and
 * [points]. Section findings carry "s", the section's number from 1.
 */
fun wardrobeChecks(m: Module, wallL: Int?, roomH: Int?, ws: Workshop, openings: List<Opening>, points: List<SitePoint>): List<FCheck> {
    val out = ArrayList<FCheck>()
    val t = ws.t
    val H = outerH(m, ws)
    if (wallL != null && m.x + m.w > wallL) out += FCheck("err", "wc.wide", mapOf("v" to m.x + m.w - wallL), m.id)
    if (roomH != null && H > roomH) out += FCheck("err", "wc.high", mapOf("v" to H - roomH), m.id)
    val sum = m.sections.sumOf { it.w }
    if (m.sections.isNotEmpty() && sum != m.w) out += FCheck("err", "wc.sum", mapOf("v" to sum, "w" to m.w), m.id)
    openings.filter { it.wall == m.wall && it.off < m.x + m.w && it.off + it.w > m.x && it.sill < H }.forEach { o ->
        out += FCheck(if (o.type == "door") "err" else "warn", if (o.type == "door") "kc.door" else "kc.window", mid = m.id)
    }
    points.filter { it.wall == m.wall }.forEach { p ->
        val (pw, ph) = pointSize(p)
        if (p.off + pw / 2 > m.x && p.off - pw / 2 < m.x + m.w && p.h - ph / 2 < H) when (p.t) {
            "meter" -> out += FCheck("err", "kc.meter", mid = m.id)
            "socket", "switch" -> out += FCheck("warn", "kc.socket", mapOf("o" to p.off, "h" to p.h, "t" to p.t), m.id)
        }
    }
    // a part longer than the sheet's usable length cannot be cut from it (the price counts a sheet of its own for it)
    val uL = ws.sheetL - 2 * ws.trim; val uW = ws.sheetW - 2 * ws.trim
    partsOf(m, ws).filter { p -> !((p.L <= uL && p.W <= uW) || (!p.grain && p.L <= uW && p.W <= uL)) }.maxOfOrNull { it.L }?.let { v ->
        out += FCheck("err", "wc.sheet", mapOf("v" to v, "max" to uL), m.id)
    }
    val ih = wardInnerH(m, t)
    // sliding doors: a door wider than 1100 or narrower than 500 runs badly
    m.slide?.let { sl ->
        val (dw, _) = slideDoor(m, t)
        if (dw > 1100) out += FCheck("warn", "wc.slideWide", mapOf("v" to dw, "n" to sl.n), m.id)
        if (dw < 500) out += FCheck("warn", "wc.slideNarrow", mapOf("v" to dw, "n" to sl.n), m.id)
        if (m.d < 450 + SLIDE_D) out += FCheck("warn", "wc.slideShallow", mapOf("v" to m.d - SLIDE_D), m.id)
    }
    m.sections.forEachIndexed { i, s ->
        val n = i + 1
        val iw = wardInner(m, m.sections, i, t)
        if (shelfTooLong(iw, t) && s.inserts.any { it.kind == "shelf" }) out += FCheck("warn", "wc.shelfWide", mapOf("s" to n, "v" to iw - 2, "max" to shelfSpanMax(t)), m.id)
        if (m.slide == null) frontSizes(s.fronts, frontW(s), m.h - wardBase(m), ws).maxOfOrNull { it.second }?.let { fw ->
            if (s.fronts.kind == "door" && fw > 600) out += FCheck("warn", "wc.doorWide", mapOf("s" to n, "v" to fw), m.id)
        }
        // inside: everything within the section, blocks apart, room under the rails to hang clothes
        val spans = s.inserts.map { x -> Triple(x, x.pos, x.pos + max(blockH(x), if (x.kind == "shelf") t else 0)) }
        if (spans.any { it.second < 0 || it.third > ih }) out += FCheck("err", "wc.out", mapOf("s" to n), m.id)
        val blocks = spans.filter { blockH(it.first) > 0 }
        val clash = spans.any { a -> blocks.any { b -> a.first !== b.first && a.second < b.third && b.second < a.third } }
        if (clash) out += FCheck("err", "wc.overlap", mapOf("s" to n), m.id)
        s.inserts.filter { it.kind == "rail" }.forEach { r ->
            val below = spans.filter { it.first !== r && it.third <= r.pos }.maxOfOrNull { it.third } ?: 0
            if (r.pos - below < 900) out += FCheck("warn", "wc.hang", mapOf("s" to n, "v" to r.pos - below), m.id)
        }
    }
    return out
}

/** The longest stretch of a wall [len] long that is clear of its doors (and of windows lower than [h]): start and length. */
fun freeSpan(len: Int, wall: String, openings: List<Opening>, h: Int): Pair<Int, Int> {
    val blocks = openings.filter { it.wall == wall && (it.type == "door" || it.sill < h) }.map { it.off to it.off + it.w }.sortedBy { it.first }
    var best = 0 to 0; var at = 0
    (blocks + (len to len)).forEach { (a, b) -> if (a - at > best.second) best = at to (a - at); at = max(at, b) }
    return best
}

/**
 * Where a new wardrobe goes on a wall [len] long: the whole wall as a niche (built in, 10 mm from each wall), or the
 * longest stretch clear of doors and windows (free-standing, 10 mm from a wall, 50 mm from an opening). x, width, built in.
 */
fun placeOn(len: Int, wall: String, openings: List<Opening>, h: Int): Triple<Int, Int, Boolean> {
    val (a, n) = freeSpan(len, wall, openings, h)
    if (a == 0 && n == len) return Triple(W_GAP_SIDE, len - 2 * W_GAP_SIDE, true)
    val g0 = if (a == 0) W_GAP_SIDE else 50; val g1 = if (a + n == len) W_GAP_SIDE else 50
    return Triple(a + g0, max(300, n - g0 - g1), false)
}
