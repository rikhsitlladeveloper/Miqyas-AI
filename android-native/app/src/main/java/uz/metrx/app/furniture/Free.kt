package uz.metrx.app.furniture

import kotlinx.serialization.Serializable
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.data.uid
import kotlin.math.max
import kotlin.math.min

/*
 * Furniture without a room (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html v4). A maker who only
 * has the furniture's sizes picks a ready model, types its sizes and designs it at once; the room can come later
 * ("Xonaga qo‘yish") and the furniture can leave it again ("Xonadan chiqarish"). Pure Kotlin, unit-tested (FreeTest).
 *
 * Room-less furniture ([Furniture.roomId] null) stands in a made-up room ([freeRoom]) whose walls are the typed sizes,
 * so the designers, the checks, the price and the documents work on it unchanged. A kitchen's sides are kept in
 * [Furniture.free] (in the order of its runs); a wardrobe's made-up room follows the wardrobe itself.
 */

/** The sizes a room-less kitchen was given: each run's length in the order of [Furniture.walls], the island, the ceiling. */
@Serializable
data class FreeSize(val sides: List<Int> = emptyList(), val island: Int = 0, val h: Int = 2700)

/** The made-up room's id starts with this, so screens can tell it from a measured one. */
const val FREE_ROOM = "free-"

fun isFreeRoom(r: Room?) = r?.id?.startsWith(FREE_ROOM) == true

/**
 * A ready model in the gallery: kitchens by layout ([sides] in run order, [island] for an island or a peninsula,
 * the ceiling [h]); wardrobes by their doors ([doors] door, slide or open) with [w] × [h] × [d].
 */
data class FModelDef(
    val id: String, val kind: String, val layout: String = "I", val sides: List<Int> = emptyList(), val island: Int = 0,
    val h: Int = 2700, val w: Int = 0, val d: Int = W_DEPTH, val built: Boolean = false, val doors: String = "door", val n: Int = 0,
    /** Stage 2 types (Cabinets.kt): the type, and its gallery group "living" or "bedroom". */
    val type: String = "", val group: String = ""
)

val F_MODELS = listOf(
    FModelDef("I", "kitchen", "I", listOf(3000)),
    FModelDef("L", "kitchen", "L", listOf(3000, 2000)),
    FModelDef("U", "kitchen", "U", listOf(2200, 3000, 2200)),
    FModelDef("O", "kitchen", "O", listOf(3000), island = 1800),
    FModelDef("P", "kitchen", "P", listOf(3000), island = 1600),
    FModelDef("h2", "wardrobe", w = 1000, h = 2200, n = 2),
    FModelDef("h3", "wardrobe", w = 1500, h = 2200, n = 3),
    FModelDef("s2", "wardrobe", w = 1800, h = 2500, built = true, doors = "slide", n = 2),
    FModelDef("s3", "wardrobe", w = 2400, h = 2500, built = true, doors = "slide", n = 3),
    FModelDef("op", "wardrobe", w = 1200, h = 2000, d = 400, doors = "open"),
) + CASE_TYPES.map { t -> typeSize(t).let { s -> FModelDef(t, "wardrobe", w = s.w, h = s.h, d = s.d, doors = "type", type = t, group = if (t in LIVING_TYPES) "living" else "bedroom") } }

/** The gallery of a kind: kitchens, wardrobes, or ("other") the living room and bedroom types. */
fun modelsOf(kind: String) = when (kind) {
    "other" -> F_MODELS.filter { it.type.isNotEmpty() }
    else -> F_MODELS.filter { it.kind == kind && it.type.isEmpty() }
}

/** A new room-less cabinet of a Stage 2 [type], [w] × [h] × [d]. */
fun newFreeCabinet(name: String, type: String, w: Int, h: Int, d: Int, ws: Workshop, now: Long = 0): Furniture =
    Furniture(uid(), "wardrobe", name, null, listOf("A"), listOf(cabinetTemplate(type, ws, "A", W_GAP_SIDE, w, h, d)), created = now, model = type, type = type)

/** What a piece counts as for the order's name and what is still wanted: kitchen, wardrobe or other. */
fun kindKey(f: Furniture) = if (f.kind == "wardrobe" && f.type.isNotEmpty()) "other" else f.kind

fun fModel(id: String): FModelDef? = F_MODELS.firstOrNull { it.id == id }

/** How many runs along walls a layout has (an island or a peninsula is not one). */
fun sidesOf(layout: String) = when (layout) { "L" -> 2; "U" -> 3; else -> 1 }

/** The made-up room's walls for a layout: the first run on A; a U goes left wall D, back wall A, right wall B. */
fun freeWalls(layout: String): List<String> = when (layout) {
    "L" -> listOf("A", "B")
    "U" -> listOf("D", "A", "B")
    "O", "P" -> listOf("A", ISLAND)
    else -> listOf("A")
}

/** The running metres the price counts for typed sizes: every side, less 600 at each corner, plus the island. */
fun freeRunMm(layout: String, sides: List<Int>, island: Int): Int =
    sides.take(sidesOf(layout)).sum() - (sidesOf(layout) - 1) * K_CORNER + if (layout == "O" || layout == "P") island else 0

/** Where the rows of a run end, mm from its start (the corner zone of a later run included). */
fun runEnd(f: Furniture, r: Run): Int = max(fillOf(f, r, false).used + r.lowStart, fillOf(f, r, true).used + r.upStart)

/** A room-less kitchen's run lengths, by wall. */
fun freeLens(f: Furniture): Map<String, Int> {
    val ws = f.walls.filter { it != ISLAND }
    val sides = f.free?.sides ?: emptyList()
    return ws.mapIndexed { i, w ->
        w to (sides.getOrNull(i) ?: runEnd(f, runsOf(f) { null }.first { it.wall == w }).coerceAtLeast(600))
    }.toMap()
}

/** A run's length for a room-less piece (null when it stands in a room, or for the island). */
fun freeLen(f: Furniture, wall: String): Int? = if (f.roomId == null && f.kind == "kitchen") freeLens(f)[wall] else null

fun wardOfF(f: Furniture): Module? = f.modules.firstOrNull { it.type == "wardrobe" }

/**
 * The made-up room of room-less furniture: a rectangle whose walls carry the kitchen's sides (the U's first side
 * sets its depth) or that fits the wardrobe with its usual gaps; no doors, windows or site points.
 */
fun freeRoom(f: Furniture): Room {
    val a: Int; val b: Int; val h: Int
    if (f.kind == "wardrobe") {
        val m = wardOfF(f)
        a = m?.let { it.x + it.w + W_GAP_SIDE } ?: 2000
        b = max(2000, (m?.d ?: W_DEPTH) + 1400)
        h = (m?.h ?: 2200) + 300
    } else {
        val lens = freeLens(f); val ws = f.walls.filter { it != ISLAND }
        fun len(i: Int) = ws.getOrNull(i)?.let { lens[it] } ?: 3000
        when (f.layout) {
            "U" -> { a = len(1); b = max(len(0), len(2)) }
            "L" -> { a = len(0); b = len(1) }
            "O", "P" -> { a = len(0); b = 3000 }
            else -> { a = len(0); b = 1800 }
        }
        h = f.free?.h?.takeIf { it > 0 } ?: 2700
    }
    return Room(FREE_ROOM + f.id, "", f.name, dims = mapOf("A" to Dim(a, "manual"), "B" to Dim(b, "manual"), "H" to Dim(h, "manual"), "T" to Dim(200, "default")),
        floorColor = "#E3E8F0")
}

/** 600 mm units, the last one narrower (from 300) or a filler: the widths along [len]. */
private fun slots(len: Int): List<Int> {
    if (len <= 0) return emptyList()
    val n = len / 600; val rem = len - n * 600
    return List(n) { 600 } + if (rem > 0) listOf(rem) else emptyList()
}

/** A new room-less kitchen of [layout] with its sides (run order), island and ceiling, filled with plain units. */
fun newFreeKitchen(name: String, model: String, layout: String, sides: List<Int>, island: Int, h: Int, ws: Workshop, now: Long = 0): Furniture {
    val walls = freeWalls(layout)
    var f = Furniture(uid(), "kitchen", name, null, walls, created = now, layout = layout, free = FreeSize(sides.take(sidesOf(layout)), if (ISLAND in walls) island else 0, h), model = model,
        kx = kExtrasFor(layout))
    val runs = runsOf(f) { freeLen(f, it) }
    f = autoFill(f, runs, ws, emptyList(), usualPoints(runs))
    if (ISLAND in walls && island > 0) f = f.copy(modules = f.modules + slots(island).map { w -> template(if (w < 300) "fillerLow" else "base", ws, ISLAND, w) })
    return pack(f, runs)
}

/**
 * Where the water and the gas usually are in a kitchen without a room, so it gets a sink and a hob like a real one:
 * one side, the sink at its second unit and the hob two units from its end; a corner kitchen, the sink in the middle
 * of the first side (a U's back wall) and the hob in the middle of the next.
 */
private fun usualPoints(runs: List<Run>): List<uz.metrx.app.data.SitePoint> {
    val rs = runs.filter { it.wall != ISLAND && it.len != null }
    if (rs.isEmpty()) return emptyList()
    fun mid(r: Run) = r.lowStart + (r.len!! - r.lowStart) / 2
    fun pt(t: String, r: Run, off: Int) = uz.metrx.app.data.SitePoint("$t-${r.wall}", t, r.wall, off, 500)
    if (rs.size == 1) {
        val r = rs[0]; val l = r.len!! - r.lowStart
        return listOf(pt("cold", r, r.lowStart + 900)) + if (l >= 2400) listOf(pt("gas", r, r.lowStart + l - 900)) else emptyList()
    }
    val sink = if (rs.size >= 3) rs[1] else rs[0]; val hob = if (rs.size >= 3) rs[2] else rs[1]
    return listOf(pt("cold", sink, mid(sink)), pt("gas", hob, mid(hob)))
}

/** A new room-less wardrobe [w] × [h] × [d]: doors as the model has them, or open shelves. */
fun newFreeWardrobe(name: String, model: String, w: Int, h: Int, d: Int, built: Boolean, doors: String, ws: Workshop, now: Long = 0, n: Int = 0): Furniture {
    var m = wardrobeTemplate(ws, "A", W_GAP_SIDE, w, h, built, d)
    // sliding doors over the whole front: as many as the model has, or as suits the width
    if (doors == "slide") m = m.copy(slide = Slide(if (n in 2..4) n else slideDoorsFor(slideOpening(m, ws.t).first)))
    if (doors == "open") {
        val ih = wardInnerH(m, ws.t)
        m = m.copy(sections = m.sections.map { s -> spreadShelves(s.copy(fronts = Fronts("open", 0), inserts = List(4) { Insert("shelf") }), ih, ws.t) })
    }
    return Furniture(uid(), "wardrobe", name, null, listOf("A"), listOf(m), created = now, model = model)
}

/* ---------------- into a room and out again ---------------- */

/** The walls the piece takes in a room whose walls go [ids] (clockwise), its first side on [first]. */
fun placeWalls(f: Furniture, ids: List<String>, first: String): List<String> {
    val i0 = ids.indexOf(first).coerceAtLeast(0)
    if (f.kind != "kitchen") return listOf(ids.getOrElse(i0) { first })
    val n = f.walls.count { it != ISLAND }
    val out = (0 until n).map { ids[(i0 + it) % ids.size] }
    return if (ISLAND in f.walls) out + ISLAND else out
}

/** The piece with its walls renamed index by index (the island stays the island). */
fun onWalls(f: Furniture, walls: List<String>): Furniture {
    val old = f.walls
    val map = old.indices.associate { old[it] to walls.getOrElse(it) { old[it] } }
    return f.copy(walls = walls, modules = f.modules.map { m -> m.copy(wall = m.wall?.let { map[it] ?: it }) })
}

/** Something that does not fit: [key] its text, its numbers. */
data class FitIssue(val key: String, val vars: Map<String, Any>)

/**
 * What does not fit when [f] goes on [walls] of a room ([len] each wall's length, [roomH] its height); a wardrobe
 * stands [off] mm from the wall's start corner (null: in the corner).
 */
fun fitIssues(f: Furniture, walls: List<String>, len: (String) -> Int?, roomH: Int?, ws: Workshop, off: Int? = null, start: Int? = null): List<FitIssue> {
    val out = ArrayList<FitIssue>()
    if (f.kind == "wardrobe") {
        val m = wardOfF(f) ?: return out
        val L = len(walls[0]); val x = off ?: W_GAP_SIDE
        if (L != null && x + m.w > L) out += FitIssue("fz.wide", mapOf("n" to f.name, "v" to x + m.w, "w" to walls[0], "d" to x + m.w - L, "l" to L))
        val H = outerH(m, ws)
        if (roomH != null && H > roomH) out += FitIssue("fz.high", mapOf("n" to f.name, "v" to H, "d" to H - roomH, "l" to roomH))
        return out
    }
    val runs = runsOf(f) { null }
    walls.forEachIndexed { i, w ->
        if (w == ISLAND) return@forEachIndexed
        val r = runs.getOrNull(i) ?: return@forEachIndexed
        // a one-wall kitchen slid along its wall needs its distance from the corner too
        val need = (f.free?.sides?.getOrNull(i)?.takeIf { f.roomId == null }?.let { max(it, runEnd(f, r)) } ?: runEnd(f, r)) + if (i == 0) start ?: 0 else 0
        val L = len(w) ?: return@forEachIndexed
        if (need > L) out += FitIssue("fz.long", mapOf("i" to i + 1, "v" to need, "w" to w, "d" to need - L, "l" to L))
    }
    return out
}

/** A row of a run cut to [avail]: units kept from its start while they fit, the rest of the room a narrower unit or a filler. */
private fun fitRow(f: Furniture, wall: String, upper: Boolean, start: Int, avail: Int, ws: Workshop): Furniture {
    val row = f.modules.filter { it.wall == wall && isUpper(it) == upper }
    if (row.sumOf { it.w } + start <= avail) return f
    var x = start
    val keep = ArrayList<Module>()
    row.forEach { m -> if (x + m.w <= avail) { keep += m; x += m.w } }
    val rem = avail - x
    if (rem > 0) keep += template(if (upper) (if (rem < 300) "fillerUp" else "wall") else (if (rem < 300) "fillerLow" else "base"), ws, wall, rem)
    val others = f.modules.filter { !(it.wall == wall && isUpper(it) == upper) }
    return f.copy(modules = others + keep)
}

/** The piece made to fit [walls]: kitchen rows cut to each wall, a wardrobe narrowed to the wall and lowered under the ceiling. */
fun fitTo(f: Furniture, walls: List<String>, len: (String) -> Int?, roomH: Int?, ws: Workshop, off: Int? = null): Furniture {
    if (f.kind == "wardrobe") {
        val m = wardOfF(f) ?: return f
        val x = off ?: W_GAP_SIDE
        val w = len(walls[0])?.let { min(m.w, it - x - W_GAP_SIDE).coerceAtLeast(min(m.w, 300)) } ?: m.w
        val legs = if (m.legs) ws.legH else 0
        val h = roomH?.let { min(m.h, it - W_GAP_TOP - legs) } ?: m.h
        val nm = m.copy(w = w, h = h, sections = if (w != m.w) splitSections(w, m.sections.map { it.copy(lock = false) }) else m.sections)
        return f.copy(modules = f.modules.map { if (it.id == m.id) nm else it })
    }
    var g = f
    val runs = runsOf(f) { len(it) }
    runs.filter { it.wall != ISLAND && it.len != null }.forEach { r ->
        g = fitRow(g, r.wall, false, r.lowStart, r.len!!, ws)
        g = fitRow(g, r.wall, true, r.upStart, r.len, ws)
    }
    return pack(g, runsOf(g) { len(it) })
}

/** Where a corner kitchen's first side starts on its wall: its units end in the corner, an empty stretch before them. */
fun firstStart(f: Furniture, wallLen: Int?): Int {
    if (f.kind != "kitchen" || f.walls.count { it != ISLAND } < 2 || wallLen == null) return 0
    val r = runsOf(f) { null }.first()
    return max(0, wallLen - runEnd(f, r))
}

/** Pieces that may stand away from the walls, turned any way (a kitchen's island always may): a desk, shelving as a divider. */
val FREE_TYPES = setOf("desk", "shelving")

fun canStandFree(f: Furniture) = f.kind == "wardrobe" && f.type in FREE_TYPES

/** The empty stretch a kitchen's first side starts with (its leading space gaps) taken off: what is left to place again. */
fun withoutLead(f: Furniture, len: (String) -> Int? = { null }): Furniture {
    if (f.kind != "kitchen") return f
    val w0 = f.walls.firstOrNull()
    val lead = f.modules.filter { it.wall == w0 && it.type == "gap" && it.x == 0 && (it.app == "space" || isUpper(it)) }.map { it.id }.toSet()
    return if (lead.isEmpty()) f else f.copy(modules = f.modules.filter { it.id !in lead }).let { pack(it, runsOf(it) { len(it) }) }
}

/** How far a one-wall kitchen starts from its wall's corner: the width of its leading empty stretch. */
fun leadOf(f: Furniture): Int {
    val w0 = f.walls.firstOrNull()
    return f.modules.firstOrNull { it.wall == w0 && it.type == "gap" && it.x == 0 && it.app == "space" && !isUpper(it) }?.w ?: 0
}

/** The island's (or peninsula's) length along its row. */
fun islandLen(f: Furniture): Int = runsOf(f) { null }.firstOrNull { it.wall == ISLAND }?.let { fillOf(f, it, false).used } ?: 0

/**
 * Where an island stands unless dragged: centred on the first side, 900 mm out from its units, its fronts facing them.
 * A peninsula joins the side's end at a right angle, going out into the room, its fronts towards the kitchen.
 */
fun islandPose(f: Furniture, wallLen: Int): Pose {
    val len = islandLen(f)
    val first = f.walls.first { it != ISLAND }
    if (f.layout == "P") {
        val end = runsOf(f) { null }.firstOrNull { it.wall != ISLAND }?.let { runEnd(f, it) } ?: wallLen
        return Pose(first, min(end, wallLen), 600, 90)
    }
    return Pose(first, (wallLen - len) / 2 + len, K_BASE_D + 900 + K_BASE_D, 180)
}

/**
 * The piece standing in room [roomId] (workspace [wsId]) on [walls] ([len] each wall's length); a wardrobe [off] from
 * the corner; [keep] its size kept. A corner kitchen's first side shorter than its wall gets an empty stretch at the
 * wall's start, so its last unit stands in the corner where the next side turns; a one-wall kitchen starts [start]
 * from the corner. [pose]: an island or a free-standing piece where it was dragged.
 */
fun placed(f: Furniture, walls: List<String>, roomId: String, wsId: String, off: Int? = null, keep: Boolean = false, len: (String) -> Int? = { null }, ws: Workshop = Workshop(),
           start: Int? = null, pose: Pose? = null): Furniture {
    var g = onWalls(withoutLead(f, len), walls).copy(roomId = roomId, ws = wsId, keep = keep, pose = pose)
    if (g.kind == "wardrobe") return g.copy(modules = g.modules.map { if (it.type == "wardrobe") it.copy(x = off ?: W_GAP_SIDE) else it })
    val gap = if (walls.count { it != ISLAND } == 1) start ?: 0 else firstStart(g, len(walls[0]))
    if (gap > 0) {
        val w0 = walls[0]
        // the empty stretch goes first in the module list, so it packs at the wall's start
        g = g.copy(modules = listOf(template("spaceLow", ws, w0, gap).copy(elev = g.modules.firstOrNull { it.wall == w0 && !isUpper(it) }?.elev ?: ws.legH),
            template("spaceUp", ws, w0, gap).copy(elev = g.modules.firstOrNull { it.wall == w0 && isUpper(it) }?.elev ?: wallElev(ws))) + g.modules)
        g = pack(g, runsOf(g) { len(it) })
    }
    return g
}

/** The piece taken out of its room: sizes from what is on each wall now, back on the made-up room's walls. */
fun takenOut(f: Furniture, len: (String) -> Int?, roomH: Int?): Furniture {
    if (f.kind == "wardrobe") {
        val g = onWalls(f, listOf("A")).copy(roomId = null, ws = "", keep = false, pose = null)
        return g.copy(modules = g.modules.map { if (it.type == "wardrobe") it.copy(x = W_GAP_SIDE) else it })
    }
    // the empty stretch before a corner kitchen's first side stays with the room, and so does where its island stood
    val f = withoutLead(f, len).copy(pose = null)
    val runs = runsOf(f) { len(it) }
    val sides = runs.filter { it.wall != ISLAND }.map { r -> max(runEnd(f, r), 600) }
    val island = runs.firstOrNull { it.wall == ISLAND }?.let { fillOf(f, it, false).used } ?: 0
    val g = onWalls(f, freeWalls(f.layout)).copy(roomId = null, ws = "", keep = false, free = FreeSize(sides, island, roomH ?: f.free?.h ?: 2700))
    return pack(g, runsOf(g) { freeLen(g, it) })
}
