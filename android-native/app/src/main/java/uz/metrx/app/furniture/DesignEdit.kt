package uz.metrx.app.furniture

import uz.metrx.app.data.uid
import kotlin.math.max

/*
 * Designer C v2 (27 Oct 2026): a kitchen wall's rows and a wardrobe's sections as [Slot] rows (RowEdit.kt), written back
 * after an edit; a unit's type changed in place ("Turi"); a section's inside from its three counts ("Ichki"). Pure
 * Kotlin, unit-tested (RowEditTest).
 */

/** Appliances that keep their own widths and never take up a neighbour's difference. */
val FIXED_APPS = setOf("dishwasher", "hob", "hood", "oven", "fridgeB", "fridge", "micro")

/** A kitchen module's kind in its row. */
fun slotKind(m: Module): SK = when {
    m.type == "gap" && (m.app.isEmpty() || m.app == "space") -> SK.GAP
    m.type == "filler" -> SK.FILLER
    m.app in FIXED_APPS -> SK.FIXED
    (m.type == "base" || m.type == "wall") && m.fronts.kind == "panel" && m.app.isEmpty() -> SK.CORNER
    else -> SK.MOD
}

/** The widths a kitchen module may take (null: the usual snaps). */
fun allowedW(m: Module): List<Int>? = when {
    m.type == "filler" -> listOf(20, 30, 50, 80, 100)
    m.app == "dishwasher" -> listOf(450, 600)
    m.app == "hob" -> listOf(450, 600, 900)
    m.app == "hood" -> listOf(600, 900)
    m.app == "sink" -> listOf(450, 500, 600, 800, 900)
    m.app == "oven" -> listOf(450, 600)
    m.app == "fridgeB" -> listOf(600)
    m.app == "micro" -> listOf(500, 600)
    m.app == "fridge" -> listOf(600, 700, 900)
    m.type == "tall" -> listOf(400, 450, 500, 600)
    else -> null
}

/** A gap, a filler, a corner unit's front or the free end: what a long-press cannot pick up. */
fun movable(m: Module) = slotKind(m).let { it != SK.GAP && it != SK.CORNER }

/** A slot for module [m]. */
fun slotOf(m: Module) = slotKind(m).let { k -> Slot(m.id, m.w, k, allowedW(m), if (k == SK.FILLER) 10 else if (k == SK.GAP) 0 else 150) }

/** The modules of [run]'s lower or [upper] row, in order. */
fun rowMods(f: Furniture, wall: String, upper: Boolean) = f.modules.filter { it.wall == wall && isUpper(it) == upper }

/** The free length left at a row's end, mm ([END_FREE] on an island; 0 when it is full or over). */
fun rowFree(f: Furniture, r: Run, upper: Boolean): Int {
    val fl = fillOf(f, r, upper)
    return fl.left?.let { max(0, it) } ?: END_FREE
}

/** [r]'s lower or [upper] row as slots, its free end last. */
fun kRow(f: Furniture, r: Run, upper: Boolean): List<Slot> =
    rowMods(f, r.wall, upper).map(::slotOf) + Slot(END_ID, rowFree(f, r, upper), SK.END, min = 0)

/** An empty stretch ([SK.GAP]) or a filler of [w] on [wall]'s lower or [upper] row, id [id]. */
fun spaceModule(kind: SK, upper: Boolean, wall: String, w: Int, ws: Workshop, id: String = uid()): Module =
    template(if (kind == SK.FILLER) (if (upper) "fillerUp" else "fillerLow") else (if (upper) "spaceUp" else "spaceLow"), ws, wall, w).copy(id = id)

/**
 * [f] with [wall]'s lower or [upper] row as [row] says (widths, order, gaps and fillers made or gone); [extra] the new
 * modules by id (one put in, a copy). The other rows keep their place in [Furniture.modules]; the caller packs.
 */
fun applyRow(f: Furniture, wall: String, upper: Boolean, row: List<Slot>, ws0: Workshop, extra: Map<String, Module> = emptyMap()): Furniture {
    val ws = wsOf(f, ws0)
    val old = rowMods(f, wall, upper)
    val ids = old.map { it.id }.toSet()
    val byId = old.associateBy { it.id }
    val seq = row.filter { it.kind != SK.END }.map { s ->
        val m0 = byId[s.id] ?: extra[s.id] ?: spaceModule(s.kind, upper, wall, s.w, ws, s.id)
        when {
            s.kind == SK.GAP && slotKind(m0) != SK.GAP -> spaceModule(SK.GAP, upper, wall, s.w, ws, s.id)
            s.kind == SK.FILLER && slotKind(m0) != SK.FILLER -> spaceModule(SK.FILLER, upper, wall, s.w, ws, s.id).copy(front = m0.front)
            else -> m0.copy(w = s.w)
        }
    }
    val first = f.modules.indexOfFirst { it.id in ids }
    val rest = f.modules.filter { it.id !in ids }
    val at = if (first < 0) rest.size else f.modules.take(first).count { it.id !in ids }
    return f.copy(modules = rest.take(at) + seq + rest.drop(at))
}

/* ---------------- a unit's type ("Turi") ---------------- */

/** The lower row's types and the upper row's (strings dzc.t.<key>). */
val BASE_TYPES = listOf("door1", "door2", "drawer2", "drawer3", "drawer4", "open", "sink", "hob", "dw")
val WALL_TYPES = listOf("wdoor1", "wdoor2", "wglass", "wopen")

/** Which type key kitchen module [m] is now (null: none of the list, a tall unit or a corner). */
fun curType(m: Module): String? = when {
    m.type == "wall" && m.app.isEmpty() -> when { m.fronts.kind == "open" -> "wopen"; glassDoors(m) -> "wglass"; m.fronts.kind == "door" -> if (m.fronts.n >= 2) "wdoor2" else "wdoor1"; else -> null }
    m.app == "dishwasher" -> "dw"
    m.app == "sink" -> "sink"
    m.app == "hob" -> "hob"
    m.type == "base" && m.app.isEmpty() -> when (m.fronts.kind) { "door" -> if (m.fronts.n >= 2) "door2" else "door1"; "drawer" -> "drawer${m.fronts.n}"; "open" -> "open"; else -> null }
    else -> null
}

/** Whether module [m] takes a type of the list: a lower unit, a dishwasher, a wall unit (not a tall unit, a corner, a hood). */
fun typeable(m: Module) = curType(m) != null || (m.type == "base" && m.app.isEmpty() && m.fronts.kind != "panel")

/**
 * Kitchen module [m] made type [key] in place: its id, width, wall, height above the floor, depth, own board, soft
 * close and handles kept (the handle choices of fronts that are gone dropped). Null when it cannot be: a dishwasher
 * only 450 or 600 wide, an upper type for a lower unit or the other way round.
 */
fun retype(m: Module, key: String, ws: Workshop): Module? {
    val wall = m.wall ?: ""
    val upper = m.type == "wall"
    if (key in WALL_TYPES != upper) return null
    if (key == "dw" && m.w !in listOf(450, 600)) return null
    val shelves = m.inserts.filter { it.kind == "shelf" || it.kind == "glass" }.sumOf { it.qty }
    val t = when (key) {
        "door1", "door2" -> template("base", ws, wall, m.w).copy(fronts = Fronts("door", if (key == "door2") 2 else 1), inserts = listOf(Insert("shelf", qty = shelves.coerceAtLeast(1))))
        "drawer2", "drawer3", "drawer4" -> template("drawers", ws, wall, m.w).copy(fronts = Fronts("drawer", key.last() - '0'))
        "open" -> template("base", ws, wall, m.w).copy(fronts = Fronts("open", 0), inserts = listOf(Insert("shelf", qty = shelves.coerceAtLeast(1))))
        "sink" -> template("sink", ws, wall, m.w)
        "hob" -> template("hob", ws, wall, m.w)
        "dw" -> template("dishwasher", ws, wall, m.w)
        "wdoor1", "wdoor2" -> withGlassDoors(template("wall", ws, wall, m.w).copy(fronts = Fronts("door", if (key == "wdoor2") 2 else 1), h = m.h, elev = m.elev,
            inserts = listOf(Insert("shelf", qty = shelves.coerceAtLeast(1)))), false)
        "wglass" -> withGlassDoors(template("wall", ws, wall, m.w).copy(fronts = Fronts("door", if (m.w >= 500) 2 else 1), h = m.h, elev = m.elev,
            inserts = listOf(Insert("shelf", qty = shelves.coerceAtLeast(1)))), true)
        "wopen" -> template("open", ws, wall, m.w).copy(h = m.h, elev = m.elev, inserts = listOf(Insert("shelf", qty = shelves.coerceAtLeast(1))))
        else -> return null
    }
    val same = t.type == m.type
    val out = t.copy(id = m.id, x = m.x, elev = if (upper) m.elev else if (t.type == m.type) m.elev else t.elev, d = if (same) m.d else t.d,
        front = m.front, soft = m.soft, handles = m.handles, noHandle = m.noHandle, label = m.label)
    return frontsChanged(m, out).copy(hinges = if (out.fronts == m.fronts) m.hinges else emptyList())
}

/* ---------------- a wardrobe's sections ---------------- */

/** Box [m]'s sections at widths [ws] (each one kept, so the split stays as it was dragged). */
fun withSecWidths(m: Module, ws: List<Int>): Module =
    m.copy(sections = m.sections.mapIndexed { i, s -> s.copy(w = ws.getOrElse(i) { s.w }, lock = m.sections.size > 1) })

/** Box [m] with [n] equal sections: the ones there kept in order (doors, inside), new ones with a door each and shelves. */
fun withSecCount(m: Module, n: Int, ws: Workshop): Module {
    val ih = wardInnerH(m, ws.t)
    val ws0 = equalSplit(m.w, n)
    val secs = List(n) { i ->
        val s = m.sections.getOrNull(i) ?: spreadShelves(Section(ws0[i], Fronts("door", if (ws0[i] >= 600) 2 else 1), List(4) { Insert("shelf") }), ih, ws.t)
            .copy(hinge = if (i % 2 == 1) "R" else "L")
        s.copy(w = ws0[i], lock = false)
    }
    return m.copy(sections = secs)
}

/** Box [m]'s sections reordered as [order] (old indices), their widths moving with them. */
fun withSecOrder(m: Module, order: List<Int>): Module = m.copy(sections = order.map { m.sections[it] })

/** A section's inside as the "Ichki" row counts it: a rail, shelves, drawers. */
data class SecFill(val rail: Boolean, val shelves: Int, val drawers: Int)

fun secFill(s: Section) = SecFill(s.inserts.any { it.kind == "rail" }, s.inserts.count { it.kind == "shelf" }, s.inserts.count { it.kind == "drawer" })

/**
 * Section [s] ([ih] high inside) with [fill]: drawers stacked from the floor, a rail where it hangs best, the shelves
 * evenly between; what else it has (racks, a lift, glass shelves) kept.
 */
fun withFill(s: Section, fill: SecFill, ih: Int, t: Int): Section {
    var x = s.copy(inserts = s.inserts.filter { it.kind != "rail" && it.kind != "shelf" && it.kind != "drawer" })
    repeat(fill.drawers.coerceIn(0, 6)) { x = x.copy(inserts = (x.inserts + Insert("drawer", pos = nextPos("drawer", x, ih, t), h = 200)).sortedBy { it.pos }) }
    if (fill.rail) {
        // the rail about 1.1 m over the drawers, or under the hat shelf 320 mm from the top
        val lo = x.inserts.filter { blockH(it) > 0 && it.kind != "lift" }.maxOfOrNull { it.pos + blockH(it) } ?: 0
        val pos = (ih - 320 - 70).coerceAtLeast(lo + 900).coerceAtMost(ih - 80)
        x = x.copy(inserts = (x.inserts + Insert("rail", pos = pos)).sortedBy { it.pos })
    }
    val n = fill.shelves.coerceIn(0, 8)
    if (n > 0) {
        if (fill.rail) {
            // over a rail the shelves go above it (the hat shelf), the rest below the rail's hanging space
            val rail = x.inserts.first { it.kind == "rail" }.pos
            val over = (ih - t - rail - 60).coerceAtLeast(0)
            val up = if (over >= 150) 1 else 0
            val shelves = (0 until up).map { Insert("shelf", pos = rail + 60) } +
                (0 until n - up).map { k -> val lo = x.inserts.filter { blockH(it) > 0 && it.kind != "lift" }.maxOfOrNull { it.pos + blockH(it) } ?: 0
                    val hi = (rail - 1000).coerceAtLeast(lo + 60); Insert("shelf", pos = lo + (hi - lo) * (k + 1) / (n - up + 1)) }
            x = x.copy(inserts = (x.inserts + shelves).sortedBy { it.pos })
        } else x = spreadShelves(x.copy(inserts = x.inserts + List(n) { Insert("shelf") }), ih, t)
    }
    return x
}

/** A section's type ("Turi"): "door" its doors on the board, "mirror" mirrored ones, "glass" in a frame, "open" none. */
fun secType(s: Section): String = when { s.fronts.kind == "open" -> "open"; s.face == "mirror" -> "mirror"; s.face == "glass" -> "glass"; else -> "door" }

/** Section [s] as type [k]: its doors kept (one or two by its width when it had none), the face changed. */
fun withSecType(s: Section, k: String): Section {
    val doors = if (s.fronts.kind == "door") s.fronts else Fronts("door", if (s.w >= 600) 2 else 1)
    val out = when (k) {
        "open" -> s.copy(fronts = Fronts("open", 0), face = "")
        "mirror" -> s.copy(fronts = doors, face = "mirror")
        "glass" -> s.copy(fronts = doors, face = "glass")
        else -> s.copy(fronts = doors, face = "")
    }
    return frontsChanged(s, out)
}
