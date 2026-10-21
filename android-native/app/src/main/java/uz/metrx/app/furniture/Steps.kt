package uz.metrx.app.furniture

import kotlin.math.min

/*
 * The furniture gallery and its size steps (decided 21 Oct 2026, mockup design/furniture/gallery-steps-mockup.html v5):
 * every model once, grouped by room; each main size asked on its own step; the piece built from what was typed (the
 * usual size while a field is empty, so the picture always shows a whole piece). Pure Kotlin, unit-tested (StepsTest).
 */

/** The gallery's groups by room (strings key of the name, models in order). */
val GALLERY: List<Pair<String, List<String>>> = listOf(
    "kitchen" to listOf("I", "L", "U", "O", "P"),
    "bedroom" to listOf("h2", "h3", "s2", "s3", "dresser", "nightstand", "vanity"),
    "living" to listOf("tv", "shelving", "sideboard"),
    "hall" to listOf("hallway", "op"),
    "office" to listOf("desk"),
)

/** One size on its own step: [key] in the values, its label and help (strings keys), the usual size and the range, mm. */
data class SizeStep(val key: String, val label: String, val help: String, val usual: Int, val min: Int, val max: Int)

/** The main sizes of a model, in the order they are asked: a kitchen's sides, its island or peninsula and the ceiling; a cabinet's width, height, depth. */
fun stepsOf(m: FModelDef): List<SizeStep> {
    if (m.kind == "kitchen") {
        val labels = when (m.layout) { "L" -> listOf("fz.w1", "fz.w2"); "U" -> listOf("fz.uL", "fz.uM", "fz.uR"); "O", "P" -> listOf("fz.pW"); else -> listOf("fz.len") }
        val helps = when (m.layout) { "L" -> listOf("fx.hW1", "fx.hW2"); "U" -> listOf("fx.hUL", "fx.hUM", "fx.hUR"); "O", "P" -> listOf("fx.hRun"); else -> listOf("fx.hLen") }
        val sides = labels.indices.map { i -> SizeStep("s$i", labels[i], helps[i], m.sides.getOrElse(i) { 3000 }, 600, 8000) }
        val island = when (m.layout) {
            "O" -> listOf(SizeStep("isl", "fz.isl", "fx.hIsl", m.island, 600, 6000))
            "P" -> listOf(SizeStep("isl", "fz.pP", "fx.hPen", m.island, 600, 6000))
            else -> emptyList()
        }
        return sides + island + SizeStep("h", "fz.ceil", "fx.hCeil", m.h, 2000, 4000)
    }
    // wardrobes stand high; the living room and bedroom pieces can be small
    val ward = m.type.isEmpty()
    val legs = !ward && typeSize(m.type).legs
    return listOf(
        SizeStep("w", "wd.w", "fx.hW", m.w, if (ward) 400 else 300, 6000),
        SizeStep("h", "fz.wH", if (legs) "fx.hHLegs" else "fx.hH", m.h, if (ward) 1200 else 300, 3200),
        SizeStep("d", "wd.d", "fx.hD", m.d, 250, 1000),
    )
}

/** What is wrong with [mm] for [s]: "fx.min" or "fx.max" with the limit, or null. */
fun stepIssue(s: SizeStep, mm: Int?): Pair<String, Int>? = when {
    mm == null -> null
    mm < s.min -> "fx.min" to s.min
    mm > s.max -> "fx.max" to s.max
    else -> null
}

/** The piece of model [m] with the sizes [v] (a missing one takes its usual size). */
fun pieceOf(m: FModelDef, v: Map<String, Int>, ws: Workshop, name: String, now: Long = 0): Furniture {
    val st = stepsOf(m).associateBy { it.key }
    fun g(k: String) = v[k] ?: st[k]?.usual ?: 0
    return when {
        m.kind == "kitchen" -> newFreeKitchen(name, m.id, m.layout, (0 until sidesOf(m.layout)).map { g("s$it") },
            if (m.layout == "O" || m.layout == "P") g("isl") else 0, g("h"), ws, now)
        m.type.isNotEmpty() -> newFreeCabinet(name, m.type, g("w"), g("h"), g("d"), ws, now)
        else -> newFreeWardrobe(name, m.id, g("w"), g("h"), g("d"), m.built, m.doors, ws, now, m.n)
    }
}

/** A piece's sizes as step values: a kitchen's typed sides, island and ceiling; a cabinet's outer width, height (legs in) and depth. */
fun valsOf(f: Furniture, ws: Workshop): Map<String, Int> {
    if (f.kind == "kitchen") {
        val fs = f.free ?: return emptyMap()
        return buildMap {
            fs.sides.forEachIndexed { i, s -> put("s$i", s) }
            if (fs.island > 0) put("isl", fs.island)
            put("h", fs.h)
        }
    }
    val m = wardOfF(f) ?: return emptyMap()
    return mapOf("w" to m.w, "h" to if (f.type.isNotEmpty()) outerH(m, ws) else m.h, "d" to m.d)
}

/** The model a piece was made from (a kitchen made before the gallery: its layout's model; a wardrobe: two doors). */
fun modelOf(f: Furniture): FModelDef =
    fModel(f.model) ?: fModel(if (f.type.isNotEmpty()) f.type else if (f.kind == "kitchen") f.layout else "h2") ?: F_MODELS.first()

/**
 * The piece with new sizes [v]: a room-less kitchen's runs follow its sides (units that no longer fit are cut, the rest
 * stays); a cabinet keeps its sections, spread again over a new width.
 */
fun resized(f: Furniture, v: Map<String, Int>, ws: Workshop): Furniture {
    if (f.kind == "kitchen") {
        val n = sidesOf(f.layout)
        val old = f.free ?: FreeSize()
        val nf = f.copy(free = FreeSize((0 until n).map { v["s$it"] ?: old.sides.getOrElse(it) { 3000 } }, if (ISLAND in f.walls) v["isl"] ?: old.island else 0, v["h"] ?: old.h))
        return fitTo(nf, nf.walls, { id -> freeLen(nf, id) }, null, ws)
    }
    val m = wardOfF(f) ?: return f
    val w = v["w"] ?: m.w; val d = v["d"] ?: m.d
    val h = (v["h"] ?: outerH(m, ws)).let { if (f.type.isNotEmpty() && m.legs) it - ws.legH else it }
    val secs = if (w != m.w) splitSections(w, m.sections.map { it.copy(lock = false) }) else m.sections
    val nm = m.copy(w = w, h = h, d = d, sections = secs)
    return f.copy(modules = f.modules.map { if (it.id == m.id) nm else it })
}

/** Where a piece fits best in a room whose walls go [ids]: the first wall with nothing wrong, else the one with the fewest issues. */
fun bestFirst(f: Furniture, ids: List<String>, len: (String) -> Int?, roomH: Int?, ws: Workshop): Pair<String, List<FitIssue>> =
    ids.map { w -> w to fitIssues(f, placeWalls(f, ids, w), len, roomH, ws) }.minByOrNull { it.second.size } ?: ((ids.firstOrNull() ?: "A") to emptyList())

/**
 * A kitchen for a measured room: it takes the walls it goes on whole (from [first], clockwise), their lengths its sides;
 * an island or peninsula keeps its usual length where it fits; the ceiling is the room's.
 */
fun roomKitchen(m: FModelDef, ids: List<String>, first: String, len: (String) -> Int?, roomH: Int?, ws: Workshop, name: String, now: Long = 0): Furniture {
    val probe = pieceOf(m, emptyMap(), ws, name, now)
    val on = placeWalls(probe, ids, first).filter { it != ISLAND }
    val v = HashMap<String, Int>()
    on.forEachIndexed { i, w -> v["s$i"] = len(w) ?: m.sides.getOrElse(i) { 3000 } }
    val usual = stepsOf(m).firstOrNull { it.key == "isl" }?.usual
    if (usual != null) v["isl"] = min(usual, (v["s0"] ?: usual) - 600).coerceAtLeast(600)
    roomH?.let { v["h"] = it }
    return pieceOf(m, v, ws, name, now)
}

/** A cabinet for a measured room: its usual size, no wider than the wall [first] and no higher than the ceiling allows. */
fun roomCabinet(m: FModelDef, wallLen: Int?, roomH: Int?, ws: Workshop, name: String, now: Long = 0): Furniture {
    val st = stepsOf(m).associate { it.key to it.usual }
    val w = wallLen?.let { min(st.getValue("w"), it - 2 * W_GAP_SIDE) } ?: st.getValue("w")
    val h = if (m.type.isEmpty() && roomH != null) min(st.getValue("h"), roomH - W_GAP_TOP) else st.getValue("h")
    return pieceOf(m, mapOf("w" to w.coerceAtLeast(300), "h" to h, "d" to st.getValue("d")), ws, name, now)
}
