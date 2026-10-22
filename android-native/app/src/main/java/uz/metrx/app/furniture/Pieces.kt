package uz.metrx.app.furniture

import uz.metrx.app.data.uid
import kotlin.math.max
import kotlin.math.min

/*
 * The gallery's later models (decided 22 Oct 2026): pieces made of several boxes on the wardrobe's engine and the
 * board-built items (Items.kt). A stenka is pieces side by side on one wall (shelves hung over them), a corner wardrobe
 * or desk two arms on two walls, a vitrina and a washing-machine column one box on another, a loft bed its frame with
 * a desk or a wardrobe under it, a dressing table its drawers with a mirror over them. [packPiece] keeps the boxes where
 * they belong after every change. Pure Kotlin, unit-tested (PiecesTest).
 */

/** Pieces with their own short designer (Items.kt) instead of the wardrobe designer. */
val ITEM_TYPES = setOf("bed", "bunk", "loft", "dining", "coffee", "bar", "mirrorP")
/** Pieces of several boxes on the wardrobe's engine. */
val PIECE_TYPES = setOf("stenka", "cornerW", "cornerDesk", "vitrina", "washer")
/** Pieces on two walls round a corner: the first wall's run ends in the corner, the second starts past its depth. */
val CORNER_TYPES = setOf("cornerW", "cornerDesk")
/** One box standing on another. */
val STACK_TYPES = setOf("vitrina", "washer")

/** A bed's kinds, a table's legs, in the order their steps offer them. */
val BED_KINDS = listOf("legs", "drawers", "lift")
val LEG_KINDS = listOf("board", "metal4", "frame")
val UNDER_KINDS = listOf("desk", "ward", "open")

/** A box of a piece: a cabinet on the wardrobe's engine or an item. */
fun isBox(m: Module) = m.type == "wardrobe" || m.type in ITEM_MODS

fun boxes(f: Furniture) = f.modules.filter(::isBox)

/** A piece with the short designer (a bed, a table, the bar counter, a mirror panel). */
fun isItemPiece(f: Furniture) = f.kind == "wardrobe" && f.type in ITEM_TYPES

/** A box that hangs on the wall (or stands on another box): no legs, its bottom above the floor. */
fun hung(m: Module) = !m.legs && m.elev > 0

/** How high a box reaches from the floor. */
fun topOf(m: Module, ws: Workshop): Int = if (m.type in ITEM_MODS) itemTop(m, ws) else m.elev + outerH(m, ws)

/** The boxes standing on the piece's first wall (all but a corner piece's second arm; a hung one when nothing stands). */
fun firstRun(f: Furniture): List<Module> {
    val w0 = f.walls.firstOrNull() ?: wardOfF(f)?.wall
    val on = boxes(f).filter { it.wall == w0 }
    return on.filter { !hung(it) }.ifEmpty { on }
}

/** Where the piece starts on its first wall and how long it is there. */
fun runStart(f: Furniture): Int = firstRun(f).minOfOrNull { it.x } ?: 0
fun runLen(f: Furniture): Int = firstRun(f).let { r -> if (r.isEmpty()) 0 else r.maxOf { it.x + it.w } - r.minOf { it.x } }

/** The piece moved along its first wall so it starts at [x]. */
fun shiftRun(f: Furniture, x: Int): Furniture {
    val d = x - runStart(f)
    if (d == 0) return f
    val w0 = f.walls.firstOrNull() ?: wardOfF(f)?.wall
    return f.copy(modules = f.modules.map { if (isBox(it) && it.wall == w0) it.copy(x = it.x + d) else it })
}

/** Moisture-resistant board for a bathroom's carcass and fronts. */
const val MR_BOARD = "ldsp16mr"
fun bathMats() = FMats(carcass = MR_BOARD, front = MR_BOARD)

/* ---------------- keeping the boxes in place ---------------- */

/**
 * The piece's boxes where they belong: a corner piece's arms in the corner of a first wall [lenA] long (null: from its
 * start), a stenka's pieces side by side, a box on another one, a loft bed's under-part, a dressing table's mirror.
 * [changed]: the box just changed (it leads a stacked pair).
 */
fun packPiece(f: Furniture, lenA: Int? = null, changed: String? = null, ws: Workshop = Workshop()): Furniture = when {
    f.kind != "wardrobe" -> f
    f.type in CORNER_TYPES -> cornerFit(f, lenA)
    f.type == "stenka" -> stenkaPack(f)
    f.type in STACK_TYPES -> stackPack(f, changed, ws)
    f.type == "loft" -> loftPack(f, ws)
    f.modules.any { it.type == "mirror" } -> mirrorPack(f, ws)
    else -> f
}

/** A corner piece's first arm ends in the corner (or starts where it starts), the second starts past the first's depth. */
fun cornerFit(f: Furniture, lenA: Int?): Furniture {
    val wa = f.walls.getOrNull(0) ?: return f; val wb = f.walls.getOrNull(1) ?: return f
    val a = f.modules.filter { isBox(it) && it.wall == wa }
    val b = f.modules.filter { isBox(it) && it.wall == wb }
    val total = a.sumOf { it.w }
    var x = if (lenA != null) lenA - W_GAP_SIDE - total else (a.minOfOrNull { it.x } ?: W_GAP_SIDE)
    val xs = HashMap<String, Int>()
    a.forEach { m -> xs[m.id] = x; x += m.w }
    var y = a.lastOrNull()?.d ?: W_DEPTH
    b.forEach { m -> xs[m.id] = y; y += m.w }
    // the corner unit's blind part is as wide as the second arm is deep
    val bd = b.firstOrNull()?.d
    return f.copy(modules = f.modules.map { m -> (xs[m.id]?.let { m.copy(x = it) } ?: m).let { n ->
        if (bd != null && n.sections.any { it.blind > 0 }) n.copy(sections = n.sections.map { s -> if (s.blind > 0) s.copy(blind = min(bd, s.w - 200)) else s }) else n
    } })
}

/** A stenka: the floor pieces side by side in their order; each hung shelf centred over the floor piece before it. */
fun stenkaPack(f: Furniture): Furniture {
    val bs = boxes(f); if (bs.isEmpty()) return f
    val floor = bs.filter { !hung(it) }
    var x = floor.minOfOrNull { it.x } ?: W_GAP_SIDE
    val xs = HashMap<String, Int>()
    floor.forEach { m -> xs[m.id] = x; x += m.w }
    var under: Module? = floor.firstOrNull()
    bs.forEach { m ->
        if (!hung(m)) under = m
        else under?.let { u -> xs[m.id] = xs.getValue(u.id) + (u.w - m.w) / 2 }
    }
    return f.copy(modules = f.modules.map { m -> xs[m.id]?.let { m.copy(x = it) } ?: m })
}

/** A box on another: the upper one as wide as the lower and on it; the one just changed leads. */
fun stackPack(f: Furniture, changed: String?, ws: Workshop): Furniture {
    val bs = f.modules.filter { it.type == "wardrobe" }
    if (bs.size < 2) return f
    val lo = bs[0]; val up = bs[1]
    val lead = if (changed == up.id) up else lo
    fun fit(m: Module) = if (m.w == lead.w) m.copy(x = lead.x) else m.copy(x = lead.x, w = lead.w, sections = splitSections(lead.w, m.sections.map { it.copy(lock = false) }))
    val nlo = fit(lo); val nup = fit(up).copy(elev = topOf(nlo, ws))
    return f.copy(modules = f.modules.map { when (it.id) { lo.id -> nlo; up.id -> nup; else -> it } })
}

/** A loft bed: the desk or wardrobe under it at the end away from the ladder, under its platform, inside its frame. */
fun loftPack(f: Furniture, ws: Workshop): Furniture {
    val bed = f.modules.firstOrNull { it.type == "loft" } ?: return f
    val t = ws.t
    val o = bed.opt ?: Opt()
    return f.copy(modules = f.modules.map { m ->
        if (m.type != "wardrobe") m else {
            val w = min(m.w, bed.w - 2 * t - 10); val d = min(m.d, frameD(bed) - 2 * t)
            val room = upperDeck(bed) - 160 - (if (m.legs) legsOf(m, ws) else 0)
            val h = min(m.h, room)
            val x = if (o.ladder == "R") bed.x + t + 5 else bed.x + bed.w - t - 5 - w
            m.copy(x = x, w = w, d = d, h = h, wall = bed.wall, sections = if (w != m.w) splitSections(w, m.sections.map { it.copy(lock = false) }) else m.sections)
        }
    })
}

/** A dressing table's mirror: centred over the table, at least 50 over its top. */
fun mirrorPack(f: Furniture, ws: Workshop): Furniture {
    val cab = f.modules.firstOrNull { it.type == "wardrobe" } ?: return f
    return f.copy(modules = f.modules.map { m ->
        if (m.type != "mirror") m else m.copy(x = cab.x + (cab.w - m.w) / 2, wall = cab.wall, elev = max(m.elev, topOf(cab, ws) + 50))
    })
}

/* ---------------- the newer models ---------------- */

/** A tall cabinet of a stenka: one door, five shelves, on a plinth. */
private fun tallCab(ws: Workshop, wall: String, x: Int, w: Int, h: Int, d: Int): Module {
    val m = cabinetTemplate("bookcase", ws, wall, x, w, h, d)
    return m.copy(sections = m.sections.map { it.copy(fronts = Fronts("door", if (w >= 700) 2 else 1)) })
}

/** A shelf hung over a stenka's low piece: open boxes about 600 wide. */
private fun hungShelf(ws: Workshop, wall: String, x: Int, w: Int, elev: Int): Module {
    val m = cabinetTemplate("shelfW", ws, wall, x, w, 350, 280).copy(elev = elev)
    return m.copy(sections = splitSections(w, List(sectionsFor(w)) { Section(0, Fronts("open", 0)) }))
}

/** A piece a stenka can take more of: a tall cabinet, a low one, a TV unit, a hung shelf. */
val STENKA_PARTS = listOf("tall", "low", "tv", "shelf")

/** A new box of kind [k] for stenka [f], as high as its talls and as deep as it is. */
fun stenkaPart(f: Furniture, k: String, ws: Workshop): Module {
    val wall = f.walls.firstOrNull() ?: "A"
    val floor = boxes(f).filter { !hung(it) }
    val h = floor.filter { outerH(it, ws) >= 1400 }.maxOfOrNull { outerH(it, ws) } ?: 2200
    val d = floor.maxOfOrNull { it.d } ?: 400
    return when (k) {
        "low" -> cabinetTemplate("sideboard", ws, wall, 0, 800, 850, d)
        "tv" -> cabinetTemplate("tv", ws, wall, 0, 1200, 500, max(d, 400))
        "shelf" -> hungShelf(ws, wall, 0, 1000, 1450)
        else -> tallCab(ws, wall, 0, 600, h, d)
    }
}

/** A stenka [w] wide: a tall cabinet at each end, a low TV unit between them, shelves hung over it. */
private fun stenka(ws: Workshop, w: Int, h: Int, d: Int): List<Module> {
    val tw = if (w >= 2400) 600 else max(400, w / 5)
    val tv = w - 2 * tw
    val x0 = W_GAP_SIDE
    val out = ArrayList<Module>()
    out += tallCab(ws, "A", x0, tw, h, d)
    if (tv >= 600) {
        out += cabinetTemplate("tv", ws, "A", x0 + tw, tv, 500, max(d, 400))
        out += hungShelf(ws, "A", x0 + tw + 100, max(600, tv - 200), min(1450, h - 350 - 100))
    }
    out += tallCab(ws, "A", x0 + tw + max(0, tv), tw, h, d)
    return out
}

/** A corner unit [d] + 400 wide: a door beside its blind part (the other arm closes it), a rail and a shelf inside. */
private fun cornerUnit(ws: Workshop, x: Int, h: Int, d: Int): Module {
    val cw = d + 400
    val base = Module(uid(), "wardrobe", cw, h, d, x = x, wall = "A", legs = false)
    val ih = wardInnerH(base, ws.t)
    val rail = minOf(ih - 420, 1800 - wardBase(base) - ws.t)
    return base.copy(sections = listOf(Section(cw, Fronts("door", 1), listOf(Insert("rail", pos = rail), Insert("shelf", pos = rail + 70)), hinge = "L", blind = d)))
}

/** A corner wardrobe [w] along the first wall and [w2] along the second (each with the corner's depth in it). */
private fun cornerWard(ws: Workshop, w: Int, w2: Int, h: Int, d: Int): List<Module> {
    val cw = d + 400
    val out = ArrayList<Module>()
    val aw = w - cw
    if (aw >= 300) out += wardrobeTemplate(ws, "A", W_GAP_SIDE, aw, h, false, d)
    out += cornerUnit(ws, W_GAP_SIDE + max(0, aw), h, d)
    val bw = w2 - d
    if (bw >= 300) out += wardrobeTemplate(ws, "B", d, bw, h, false, d)
    return out
}

/** A corner desk: a desk along each wall, the knee space going round the corner (the second arm has no side there). */
private fun cornerDesk(ws: Workshop, w: Int, w2: Int, h: Int, d: Int): List<Module> {
    val a = cabinetTemplate("desk", ws, "A", W_GAP_SIDE, w, h, d)
    val b0 = cabinetTemplate("desk", ws, "B", d, max(450, w2 - d), h, d)
    val b = b0.copy(sections = b0.sections.reversed(), sideL = false)
    return listOf(a, b)
}

/** A vitrina: a board cabinet below, glass doors in their frames over glass shelves above, an LED strip in its top. */
private fun vitrina(ws: Workshop, w: Int, h: Int, d: Int): List<Module> {
    val lo0 = Module(uid(), "wardrobe", w, 850, d, x = W_GAP_SIDE, wall = "A", legs = false)
    val lo = lo0.copy(sections = listOf(spreadShelves(Section(w, Fronts("door", if (w >= 600) 2 else 1), listOf(Insert("shelf"))), wardInnerH(lo0, ws.t), ws.t)))
    val up0 = Module(uid(), "wardrobe", w, max(400, h - 850), d, x = W_GAP_SIDE, wall = "A", legs = false, base = 0, elev = 850, led = true)
    val up = up0.copy(sections = listOf(spreadShelves(Section(w, Fronts("door", if (w >= 600) 2 else 1), List(3) { Insert("shelf") }, face = "glass"), wardInnerH(up0, ws.t), ws.t)
        .let { s -> s.copy(inserts = s.inserts.map { it.copy(kind = "glass") }) }))
    return listOf(lo, up)
}

/** A washing-machine column: an open niche for the machine (no bottom, no back), a cabinet with doors over it. */
private fun washer(ws: Workshop, w: Int, h: Int, d: Int): List<Module> {
    val lo = Module(uid(), "wardrobe", w, 900, d, x = W_GAP_SIDE, wall = "A", legs = false, base = 0, sections = listOf(Section(w, Fronts("open", 0), knee = true)))
    val up0 = Module(uid(), "wardrobe", w, max(400, h - 900), d, x = W_GAP_SIDE, wall = "A", legs = false, base = 0, elev = 900)
    val up = up0.copy(sections = listOf(spreadShelves(Section(w, Fronts("door", if (w >= 600) 2 else 1), List(2) { Insert("shelf") }), wardInnerH(up0, ws.t), ws.t)))
    return listOf(lo, up)
}

/** What goes under a loft bed: a desk, a two-door cabinet, or nothing. */
fun loftUnder(k: String, ws: Workshop, bed: Module): Module? {
    val w = min(if (k == "desk") 1200 else 1000, bed.w - 2 * ws.t - 10)
    val d = min(600, frameD(bed) - 2 * ws.t)
    return when (k) {
        "desk" -> cabinetTemplate("desk", ws, bed.wall ?: "A", bed.x, w, 750, d)
        "ward" -> {
            val h = upperDeck(bed) - 160
            val m0 = Module(uid(), "wardrobe", w, h, d, x = bed.x, wall = bed.wall, legs = false)
            val ih = wardInnerH(m0, ws.t)
            m0.copy(sections = splitSections(w, List(2) { Section(0, Fronts("door", 1), List(3) { Insert("shelf") }) }).map { spreadShelves(it, ih, ws.t) })
        }
        else -> null
    }
}

/** A loft bed with [k] under it. */
fun withUnder(f: Furniture, k: String, ws: Workshop): Furniture {
    val bed = f.modules.firstOrNull { it.type == "loft" } ?: return f
    val nb = bed.copy(opt = (bed.opt ?: Opt()).copy(under = k))
    return loftPack(f.copy(modules = listOf(nb) + listOfNotNull(loftUnder(k, ws, nb))), ws)
}

/** The step values a model's piece is built from: [v] a key's value (its usual one when not typed). */
fun newPiece(type: String, v: (String) -> Int, ws: Workshop, name: String, now: Long = 0): Furniture {
    val x = W_GAP_SIDE
    var walls = listOf("A")
    fun opt(k: String, list: List<String>) = list.getOrElse(v(k)) { list[0] }
    val mods: List<Module> = when (type) {
        "bed" -> listOf(itemModule("bed", ws, "A", x, 0, v("h"), 0, Opt(bed = opt("bt", BED_KINDS), mw = v("mw"), ml = v("ml"), hb = v("hb"))))
        "bunk" -> listOf(itemModule("bunk", ws, "A", x, 0, v("h"), 0, Opt(mw = v("mw"), ml = v("ml"), ladder = opt("lad", listOf("L", "R")))))
        "loft" -> {
            val bed = itemModule("loft", ws, "A", x, 0, v("h"), 0, Opt(mw = v("mw"), ml = v("ml"), ladder = opt("lad", listOf("L", "R")), under = opt("und", UNDER_KINDS)))
            listOf(bed) + listOfNotNull(loftUnder(bed.opt!!.under, ws, bed))
        }
        "dining", "coffee" -> listOf(itemModule("table", ws, "A", x, v("w"), v("h"), v("d"),
            Opt(legs = opt("lg", LEG_KINDS), top = if (v("tp") == 1) "wt" else "ldsp", round = v("rc") == 1)))
        "bar" -> listOf(itemModule("bar", ws, "A", x, v("w"), v("h"), v("d"), Opt(top = "wt")))
        "mirrorP" -> listOf(itemModule("hooks", ws, "A", x, v("w"), v("h"), 0, Opt(hooks = 4, shelf = true, mirW = 450, mirH = 1000), elev = 300))
        "stenka" -> stenka(ws, v("w"), v("h"), v("d"))
        "cornerW" -> { walls = listOf("A", "B"); cornerWard(ws, v("w"), v("w2"), v("h"), v("d")) }
        "cornerDesk" -> { walls = listOf("A", "B"); cornerDesk(ws, v("w"), v("w2"), v("h"), v("d")) }
        "vitrina" -> vitrina(ws, v("w"), v("h"), v("d"))
        "washer" -> washer(ws, v("w"), v("h"), v("d"))
        else -> {
            // one cabinet: hung ones from their height above the floor, a vanity or a tall one on legs or on the wall
            var m = cabinetTemplate(type, ws, "A", x, v("w"), v("h"), v("d"))
            if (type in HUNG_TYPES) m = m.copy(elev = v("e"))
            if (type in MOUNT_TYPES && v("mt") == 1) m = m.copy(legs = false, base = 0, elev = 300, h = max(300, v("h") - 300))
            val mirror = if (type == "vanity") listOf(Module(uid(), "mirror", v("rw"), v("rh"), 5, x = x, wall = "A", elev = topOf(m, ws) + 250,
                fronts = Fronts("open", 0), legs = false, base = 0)) else emptyList()
            listOf(m) + mirror
        }
    }
    val f = Furniture(uid(), "wardrobe", name, null, walls, mods, created = now, model = type, type = type, mats = if (type in BATH_TYPES) bathMats() else FMats())
    return packPiece(f, null, ws = ws)
}

/** A newer model's piece as step values (Steps.kt valsOf). */
fun pieceVals(f: Furniture, ws: Workshop): Map<String, Int> {
    val main = wardOfF(f) ?: return emptyMap()
    val o = main.opt ?: Opt()
    return when (f.type) {
        "bed" -> mapOf("bt" to BED_KINDS.indexOf(o.bed).coerceAtLeast(0), "mw" to o.mw, "ml" to o.ml, "h" to main.h, "hb" to o.hb)
        "bunk" -> mapOf("mw" to o.mw, "ml" to o.ml, "h" to main.h, "lad" to if (o.ladder == "L") 0 else 1)
        "loft" -> mapOf("mw" to o.mw, "ml" to o.ml, "h" to main.h, "lad" to if (o.ladder == "L") 0 else 1, "und" to UNDER_KINDS.indexOf(o.under).coerceAtLeast(0))
        "dining", "coffee" -> mapOf("w" to main.w, "d" to main.d, "h" to main.h, "lg" to LEG_KINDS.indexOf(o.legs).coerceAtLeast(0), "tp" to if (o.top == "wt") 1 else 0, "rc" to if (o.round) 1 else 0)
        "bar" -> mapOf("w" to main.w, "h" to main.h, "d" to main.d)
        "mirrorP" -> mapOf("w" to main.w, "h" to main.h)
        "stenka" -> {
            val fl = boxes(f).filter { !hung(it) }
            mapOf("w" to runLen(f), "h" to fl.maxOf { topOf(it, ws) }, "d" to fl.maxOf { it.d })
        }
        "cornerW", "cornerDesk" -> {
            val a = boxes(f).filter { it.wall == f.walls.getOrNull(0) }; val b = boxes(f).filter { it.wall == f.walls.getOrNull(1) }
            val d = a.lastOrNull()?.d ?: main.d
            mapOf("w" to a.sumOf { it.w }, "w2" to d + b.sumOf { it.w }, "h" to boxes(f).maxOf { topOf(it, ws) }, "d" to d)
        }
        "vitrina", "washer" -> mapOf("w" to main.w, "h" to boxes(f).maxOf { topOf(it, ws) }, "d" to main.d)
        else -> buildMap {
            put("w", main.w); put("d", main.d)
            when {
                f.type in HUNG_TYPES -> { put("h", main.h); put("e", main.elev) }
                f.type in MOUNT_TYPES -> { put("h", topOf(main, ws)); put("mt", if (hung(main)) 1 else 0) }
                else -> put("h", outerH(main, ws))
            }
            f.modules.firstOrNull { it.type == "mirror" }?.let { put("rw", it.w); put("rh", it.h) }
        }
    }
}

/**
 * A newer model's piece with new step values: an item keeps its other options, a cabinet its sections (spread again
 * over a new width); the pieces of several boxes are built again from their sizes.
 */
fun pieceResized(f: Furniture, v: Map<String, Int>, ws: Workshop): Furniture {
    val main = wardOfF(f) ?: return f
    val cur = pieceVals(f, ws)
    fun g(k: String) = v[k] ?: cur[k] ?: 0
    if (f.type in PIECE_TYPES || f.type == "loft") {
        val n = newPiece(f.type, ::g, ws, f.name, f.created)
        val r = onWalls(n, f.walls.ifEmpty { n.walls }).copy(id = f.id, roomId = f.roomId, ws = f.ws, mats = f.mats, keep = f.keep, pose = f.pose, model = f.model)
        return if (f.type in CORNER_TYPES) r else shiftRun(r, runStart(f))
    }
    if (f.type in ITEM_TYPES) {
        var m = main
        listOf("w", "h", "d", "mw", "ml", "hb").forEach { k -> v[k]?.let { m = itemSet(m, k, it, ws) } }
        val o = m.opt ?: Opt()
        m = m.copy(opt = o.copy(
            bed = v["bt"]?.let { BED_KINDS.getOrElse(it) { o.bed } } ?: o.bed,
            ladder = v["lad"]?.let { if (it == 0) "L" else "R" } ?: o.ladder,
            legs = v["lg"]?.let { LEG_KINDS.getOrElse(it) { o.legs } } ?: o.legs,
            top = v["tp"]?.let { if (it == 1) "wt" else "ldsp" } ?: o.top,
            round = v["rc"]?.let { it == 1 } ?: o.round))
        return f.copy(modules = f.modules.map { if (it.id == main.id) itemSized(m, ws) else it })
    }
    // one cabinet: as the older types, with its height above the floor, how it stands and its mirror
    var m = main
    val w = g("w"); val d = g("d")
    m = m.copy(w = w, d = d, sections = if (w != m.w) splitSections(w, m.sections.map { it.copy(lock = false) }) else m.sections)
    when {
        f.type in HUNG_TYPES -> m = m.copy(h = g("h"), elev = g("e"))
        f.type in MOUNT_TYPES -> {
            val wall = g("mt") == 1
            m = if (wall) m.copy(legs = false, base = 0, elev = if (hung(m)) m.elev else 300).let { it.copy(h = max(300, g("h") - it.elev)) }
                else m.copy(legs = true, base = null, elev = 0, h = max(300, g("h") - ws.legH))
        }
        else -> m = m.copy(h = g("h") - legsOf(m, ws))
    }
    val out = f.copy(modules = f.modules.map { when {
        it.id == main.id -> m
        it.type == "mirror" -> it.copy(w = v["rw"] ?: it.w, h = v["rh"] ?: it.h)
        else -> it
    } })
    return packPiece(out, ws = ws)
}

/** What a box of a piece is called in the designer (strings key): a stenka's tall or low piece or shelf, a corner's arms, a stack's halves. */
fun boxRole(f: Furniture, m: Module): String = when {
    f.type in CORNER_TYPES -> when {
        m.wall == f.walls.getOrNull(1) -> "pc.armB"
        m.sections.any { it.blind > 0 } -> "pc.corner"
        else -> "pc.armA"
    }
    f.type in STACK_TYPES -> if (hung(m)) "pc.upper" else "pc.lower"
    f.type == "loft" && m.type == "wardrobe" -> "pc.under"
    hung(m) -> "pc.shelf"
    m.h >= 1200 -> "pc.tall"
    else -> "pc.low"
}
