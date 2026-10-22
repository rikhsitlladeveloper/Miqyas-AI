package uz.metrx.app.furniture

import kotlin.math.min

/*
 * The furniture gallery and its size steps (decided 21 Oct 2026, mockup design/furniture/gallery-steps-mockup.html v5):
 * every model once, grouped by room; each main size asked on its own step; the piece built from what was typed (the
 * usual size while a field is empty, so the picture always shows a whole piece). Pure Kotlin, unit-tested (StepsTest).
 */

/** The gallery's groups by room (strings key of the name, models in order). */
val GALLERY: List<Pair<String, List<String>>> = listOf(
    "kitchen" to listOf("I", "L", "U", "O", "P", "dining", "bar", "pantry"),
    "bedroom" to listOf("h2", "h3", "s2", "s3", "cornerW", "bed", "dresser", "nightstand", "vanity", "shelfW", "tvBed"),
    "living" to listOf("tv", "stenka", "vitrina", "sideboard", "shelving", "coffee", "shelvesW"),
    "hall" to listOf("hallway", "shoe", "hallW", "mirrorP", "op"),
    "kids" to listOf("bunk", "loft", "kidsW", "toys"),
    "office" to listOf("desk", "cornerDesk", "bookcase", "officeC"),
    "bath" to listOf("sinkV", "mirrorC", "penal", "washer"),
)

/**
 * One size on its own step: [key] in the values, its label and help (strings keys), the usual size and the range, mm.
 * A step with [opts] asks a choice instead (strings keys; its value is the index, [usual] the one chosen at first);
 * [picks] are the usual sizes offered under the field (a mattress's).
 */
data class SizeStep(val key: String, val label: String, val help: String, val usual: Int, val min: Int, val max: Int,
                    val opts: List<String> = emptyList(), val picks: List<Int> = emptyList()) {
    val choice get() = opts.isNotEmpty()
}

/** A choice step: [opts] its strings keys, the first chosen unless [usual]. */
private fun choice(key: String, label: String, opts: List<String>, usual: Int = 0) = SizeStep(key, label, "$label.h", usual, 0, opts.size - 1, opts)

/** The steps of the newer models (22 Oct 2026); null for the older ones. */
private fun newSteps(m: FModelDef): List<SizeStep>? {
    val t = m.type
    fun w(u: Int, lo: Int, hi: Int, label: String = "wd.w") = SizeStep("w", label, "fx.hW", u, lo, hi)
    fun h(u: Int, lo: Int, hi: Int, help: String = "fx.hH") = SizeStep("h", "fz.wH", help, u, lo, hi)
    fun d(u: Int, lo: Int, hi: Int, label: String = "wd.d") = SizeStep("d", label, "fx.hD", u, lo, hi)
    val bunkMat = listOf(SizeStep("mw", "fb.mw", "fb.mw.h", 900, 700, 1000, picks = listOf(800, 900)), SizeStep("ml", "fb.ml", "fb.ml.h", 2000, 1600, 2100, picks = listOf(1900, 2000)))
    val ladder = choice("lad", "fb.lad", listOf("fb.lad.L", "fb.lad.R"), 1)
    val legs = choice("lg", "fb.lg", listOf("fb.lg.board", "fb.lg.metal4", "fb.lg.frame"))
    val round = choice("rc", "fb.rc", listOf("fb.rc.no", "fb.rc.yes"))
    return when (t) {
        "bed" -> listOf(choice("bt", "fb.bt", listOf("fb.bt.legs", "fb.bt.drawers", "fb.bt.lift")),
            SizeStep("mw", "fb.mw", "fb.mw.h", 1600, 700, 2000, picks = listOf(900, 1200, 1400, 1600, 1800)),
            SizeStep("ml", "fb.ml", "fb.ml.h", 2000, 1800, 2200, picks = listOf(1900, 2000)),
            SizeStep("h", "fb.h", "fb.h.h", 450, 250, 700), SizeStep("hb", "fb.hb", "fb.hb.h", 1000, 600, 1600))
        "bunk" -> bunkMat + h(1650, 1400, 2000, "fb.hBunk") + ladder
        "loft" -> bunkMat + h(1800, 1500, 2200, "fb.hLoft") + ladder + choice("und", "fb.und", listOf("fb.und.desk", "fb.und.ward", "fb.und.open"))
        "dining" -> listOf(w(1400, 600, 3000), d(800, 500, 1200), h(750, 600, 900), legs, choice("tp", "fb.tp", listOf("fb.tp.ldsp", "fb.tp.wt")), round)
        "coffee" -> listOf(w(1000, 400, 1600), d(600, 300, 1000), h(450, 300, 600), legs, round)
        "bar" -> listOf(w(1500, 600, 3000), h(1100, 900, 1250), d(600, 400, 900, "fb.barD"))
        "mirrorP" -> listOf(w(1000, 400, 2000), SizeStep("h", "fz.wH", "fb.hPanel", 1600, 600, 2200))
        "stenka" -> listOf(w(3000, 1500, 6000, "fz.wAll"), h(2200, 1500, 3000), d(400, 300, 650))
        "cornerW" -> listOf(SizeStep("w", "fz.wA", "fz.wA.h", 1800, 1000, 4000), SizeStep("w2", "fz.wB", "fz.wB.h", 1600, 1000, 4000), h(2200, 1500, 3000), d(600, 400, 700))
        "cornerDesk" -> listOf(SizeStep("w", "fz.wA", "fz.wA.h", 1400, 900, 3000), SizeStep("w2", "fz.wB", "fz.wB.h", 1200, 900, 3000), h(750, 650, 850, "fx.hHLegs"), d(600, 450, 800))
        "vitrina" -> listOf(w(800, 400, 1600), h(2000, 1400, 2500), d(400, 300, 600))
        "washer" -> listOf(w(650, 600, 900), h(2000, 1500, 2600), d(600, 550, 700))
        "vanity" -> listOf(w(1000, 600, 1800), h(750, 650, 850, "fx.hHLegs"), d(450, 350, 600),
            SizeStep("rw", "fz.mirW", "fz.mirW.h", 600, 300, 1600), SizeStep("rh", "fz.mirH", "fz.mirH.h", 800, 300, 1400))
        in HUNG_TYPES -> typeSize(t).let { s -> listOf(w(s.w, 300, 3000), SizeStep("h", "fz.wH", "fx.hH", s.h, 150, 1200), d(s.d, 100, 500),
            SizeStep("e", "fz.elev", "fz.elev.h", s.elev, 300, 2200)) }
        in MOUNT_TYPES -> typeSize(t).let { s -> listOf(w(s.w, 300, 1600), h(s.h, 400, 2400, "fx.hHLegs"), d(s.d, 250, 650), choice("mt", "fb.mt", listOf("fb.mt.legs", "fb.mt.wall"))) }
        else -> null
    }
}

/** Models built by Pieces.kt (newPiece / pieceVals / pieceResized) rather than the older rules. */
fun isNewModel(type: String) = type.isNotEmpty() && (type in ITEM_TYPES || type in PIECE_TYPES || type in MORE_TYPES || type == "vanity")

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
    newSteps(m)?.let { return it }
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
        isNewModel(m.type) -> newPiece(m.type, ::g, ws, name, now)
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
    if (isNewModel(f.type)) return pieceVals(f, ws)
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
    if (isNewModel(f.type)) return pieceResized(f, v, ws)
    val m = wardOfF(f) ?: return f
    val w = v["w"] ?: m.w; val d = v["d"] ?: m.d
    val h = (v["h"] ?: outerH(m, ws)).let { if (f.type.isNotEmpty() && m.legs) it - legsOf(m, ws) else it }
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
    // an island runs along its side; a peninsula out from it, so it is held to the room's other way less the side's
    // units and a 900 way round its end
    val cap = if (m.layout == "P") ids.getOrNull((ids.indexOf(on.firstOrNull() ?: first) + 1) % ids.size.coerceAtLeast(1))?.let(len)?.let { it - 600 - 900 }
        else v["s0"]?.let { it - 600 }
    if (usual != null) v["isl"] = min(usual, cap ?: usual).coerceAtLeast(600)
    roomH?.let { v["h"] = it }
    return pieceOf(m, v, ws, name, now)
}

/** A cabinet for a measured room: its usual size, no wider than the wall [first] and no higher than the ceiling allows. */
fun roomCabinet(m: FModelDef, wallLen: Int?, roomH: Int?, ws: Workshop, name: String, now: Long = 0): Furniture {
    val st = stepsOf(m).associate { it.key to it.usual }
    // a bed or a table keeps its usual size; a corner piece's first arm is held to the wall
    if ("w" !in st || m.type in ITEM_TYPES) return pieceOf(m, emptyMap(), ws, name, now)
    if (m.type in CORNER_TYPES) return pieceOf(m, mapOf("w" to (wallLen?.let { min(st.getValue("w"), it - 2 * W_GAP_SIDE) } ?: st.getValue("w")).coerceAtLeast(900)), ws, name, now)
    val w = wallLen?.let { min(st.getValue("w"), it - 2 * W_GAP_SIDE) } ?: st.getValue("w")
    val h = if (m.type.isEmpty() && roomH != null) min(st.getValue("h"), roomH - W_GAP_TOP) else st.getValue("h")
    return pieceOf(m, st + mapOf("w" to w.coerceAtLeast(300), "h" to h, "d" to st.getValue("d")), ws, name, now)
}
