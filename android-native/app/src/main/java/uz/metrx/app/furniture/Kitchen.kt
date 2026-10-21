package uz.metrx.app.furniture

import uz.metrx.app.data.Opening
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.pointSize
import uz.metrx.app.data.uid

/*
 * Kitchen design rules (furniture plan section 7; design canvas screens 7–9). Pure Kotlin, unit-tested (KitchenTest).
 *
 * A kitchen runs along one to three walls of its room (or a wall and an island). On each wall the modules form two rows:
 * the lower row (base and tall units, appliance gaps, fillers) and the upper row (wall units). Each row is packed from
 * its start: the first wall from its start corner, every next wall after the corner unit of the wall before it.
 * Elevations are seen from inside the room, x from the wall's start corner, as in the wall view.
 */

const val K_BASE_H = 720
const val K_BASE_D = 560
const val K_TOP = 38
const val K_WALL_H = 720
const val K_WALL_D = 300
/** Worktop to the underside of the wall units. */
const val K_SPLASH = 600
/** Where the next wall's lower and upper rows start, past the corner unit of the wall before. */
const val K_CORNER = 600
const val K_UP_CORNER = 320
const val ISLAND = "island"

fun worktopTop(ws: Workshop) = ws.legH + K_BASE_H + K_TOP
fun wallElev(ws: Workshop) = worktopTop(ws) + K_SPLASH

/** The upper row: wall units, and fillers or gaps hung at wall-unit height. */
fun isUpper(m: Module) = m.type == "wall" || ((m.type == "filler" || m.type == "gap") && m.elev >= 1000)

/** A run of one wall: its length (null: the island, no limit) and where the lower and upper rows may start. */
data class Run(val wall: String, val len: Int?, val lowStart: Int, val upStart: Int)

fun runsOf(f: Furniture, wallLen: (String) -> Int?): List<Run> = f.walls.mapIndexed { i, w ->
    if (w == ISLAND) Run(w, null, 0, 0)
    else {
        val afterWall = i > 0 && f.walls[i - 1] != ISLAND
        Run(w, wallLen(w), if (afterWall) K_CORNER else 0, if (afterWall) K_UP_CORNER else 0)
    }
}

/** Every module's x: packed one after another along its run and row, in the order of [Furniture.modules]. */
fun pack(f: Furniture, runs: List<Run>): Furniture {
    val next = HashMap<String, Int>()
    runs.forEach { r -> next[r.wall + ":low"] = r.lowStart; next[r.wall + ":up"] = r.upStart }
    return f.copy(modules = f.modules.map { m ->
        val k = (m.wall ?: "") + if (isUpper(m)) ":up" else ":low"
        val x = next[k] ?: 0
        next[k] = x + m.w
        m.copy(x = x)
    })
}

/** How full a row is: the modules' widths and the room it has (null: no limit). */
data class Fill(val used: Int, val avail: Int?) {
    val left: Int? get() = avail?.let { it - used }
}

fun fillOf(f: Furniture, r: Run, upper: Boolean): Fill {
    val used = f.modules.filter { it.wall == r.wall && isUpper(it) == upper }.sumOf { it.w }
    return Fill(used, r.len?.let { it - if (upper) r.upStart else r.lowStart })
}

/* ---------------- the module library ---------------- */

/** Library kinds, by group: lower storage, upper storage, tall, appliances. */
val LIB_LOW = listOf("base", "drawers", "sink", "hob")
val LIB_UP = listOf("wall", "open", "hood", "micro")
val LIB_TALL = listOf("pantry", "oven", "fridgeB")
val LIB_APP = listOf("dishwasher", "fridge")

/** A new module of [kind] on [wall], [w] wide (its usual width when null). */
fun template(kind: String, ws: Workshop, wall: String, w: Int? = null): Module {
    val low = ws.legH; val up = wallElev(ws)
    fun base(width: Int, f: Fronts, ins: List<Insert>, app: String = "") = Module(uid(), "base", width, K_BASE_H, K_BASE_D, wall = wall, elev = low, fronts = f, inserts = ins, app = app)
    fun wallU(width: Int, h: Int, el: Int, f: Fronts, ins: List<Insert>, app: String = "") = Module(uid(), "wall", width, h, K_WALL_D, wall = wall, elev = el, fronts = f, inserts = ins, legs = false, app = app)
    // tall units end level with the wall units' tops
    fun tall(width: Int, f: Fronts, ins: List<Insert>, app: String = "") = Module(uid(), "tall", width, up + K_WALL_H - low, K_BASE_D, wall = wall, elev = low, fronts = f, inserts = ins, app = app)
    fun doors(width: Int) = Fronts("door", if (width >= 500) 2 else 1)
    return when (kind) {
        "drawers" -> base(w ?: 600, Fronts("drawer", 3), emptyList())
        "sink" -> (w ?: 800).let { base(it, doors(it), emptyList(), "sink") }
        "hob" -> base(w ?: 600, Fronts("drawer", 3), emptyList(), "hob")
        "wall" -> (w ?: 600).let { wallU(it, K_WALL_H, up, doors(it), listOf(Insert("shelf", qty = 2))) }
        "open" -> wallU(w ?: 600, K_WALL_H, up, Fronts("open", 0), listOf(Insert("shelf", qty = 1)))
        // the hood's cabinet ends level with the wall units, its visor 750 over the worktop
        "hood" -> wallU(w ?: 600, K_SPLASH + K_WALL_H - 750, worktopTop(ws) + 750, Fronts("door", 1), emptyList(), "hood")
        // the microwave's niche at the bottom of a wall unit of the usual height, a shelf over it
        "micro" -> wallU(w ?: 600, K_WALL_H, up, Fronts("open", 0), listOf(Insert("shelf", qty = 1)), "micro")
        "pantry" -> (w ?: 600).let { tall(it, doors(it), listOf(Insert("shelf", qty = 5))) }
        "oven" -> tall(w ?: 600, Fronts("door", 1), listOf(Insert("shelf", qty = 2)), "oven")
        "fridgeB" -> tall(w ?: 600, Fronts("panel", 2), emptyList(), "fridgeB")
        "dishwasher" -> Module(uid(), "gap", w ?: 600, K_BASE_H, K_BASE_D, wall = wall, elev = low, fronts = Fronts("panel", 1), legs = false, app = "dishwasher")
        "fridge" -> Module(uid(), "gap", w ?: 600, 2000, 650, wall = wall, elev = 0, fronts = Fronts("open", 0), legs = false, app = "fridge")
        "fillerLow" -> Module(uid(), "filler", w ?: 50, K_BASE_H, 20, wall = wall, elev = low, fronts = Fronts("open", 0), legs = false)
        "fillerUp" -> Module(uid(), "filler", w ?: 50, K_WALL_H, 20, wall = wall, elev = up, fronts = Fronts("open", 0), legs = false)
        "spaceUp" -> Module(uid(), "gap", w ?: 600, K_WALL_H, K_WALL_D, wall = wall, elev = up, fronts = Fronts("open", 0), legs = false)
        // an empty stretch of the lower row: no boards, no worktop, not in the running metres
        "spaceLow" -> Module(uid(), "gap", w ?: 600, K_BASE_H, K_BASE_D, wall = wall, elev = low, fronts = Fronts("open", 0), legs = false, app = "space")
        else -> (w ?: 600).let { base(it, doors(it), listOf(Insert("shelf", qty = 1))) }
    }
}

/** The library kind a module was made from, for its name. */
fun kindOf(m: Module): String = when {
    m.app == "space" -> "spaceLow"
    m.app.isNotEmpty() -> m.app
    m.type == "base" && m.fronts.kind == "drawer" -> "drawers"
    m.type == "wall" && m.fronts.kind == "open" -> "open"
    m.type == "tall" -> "pantry"
    m.type == "filler" -> if (isUpper(m)) "fillerUp" else "fillerLow"
    m.type == "gap" -> "spaceUp"
    else -> m.type
}

/**
 * Fills the empty rows of every wall: 600 mm units, the last one narrower (from 300) or a filler; the unit over the cold
 * water becomes the sink and the one at the gas pipe the hob. Upper units over a window leave a space.
 */
fun autoFill(f: Furniture, runs: List<Run>, ws: Workshop, openings: List<Opening>, points: List<SitePoint>): Furniture {
    val added = ArrayList<Module>()
    runs.filter { it.wall != ISLAND && it.len != null }.forEach { r ->
        val hasLow = f.modules.any { it.wall == r.wall && !isUpper(it) }
        val hasUp = f.modules.any { it.wall == r.wall && isUpper(it) }
        fun slots(avail: Int): List<Int> {
            val n = avail / 600; val rem = avail - n * 600
            return List(n) { 600 } + if (rem > 0) listOf(rem) else emptyList()
        }
        if (!hasLow) {
            var x = r.lowStart
            val water = points.firstOrNull { it.wall == r.wall && (it.t == "cold" || it.t == "sewer") }
            val gas = points.firstOrNull { it.wall == r.wall && it.t == "gas" }
            var sink = false; var hob = false
            slots(r.len!! - r.lowStart).forEach { w ->
                val inside = { p: SitePoint? -> p != null && p.off in x until x + w }
                added += when {
                    w < 300 -> template("fillerLow", ws, r.wall, w)
                    !sink && inside(water) -> { sink = true; template("sink", ws, r.wall, w) }
                    !hob && inside(gas) -> { hob = true; template("hob", ws, r.wall, w) }
                    else -> template("base", ws, r.wall, w)
                }
                x += w
            }
        }
        if (!hasUp) {
            var x = r.upStart
            val up0 = wallElev(ws); val up1 = up0 + K_WALL_H
            slots(r.len!! - r.upStart).forEach { w ->
                val window = openings.any { o -> o.wall == r.wall && o.type == "window" && o.off < x + w && o.off + o.w > x && o.sill < up1 && o.sill + o.h > up0 }
                added += when {
                    window -> template("spaceUp", ws, r.wall, w)
                    w < 300 -> template("fillerUp", ws, r.wall, w)
                    else -> template("wall", ws, r.wall, w)
                }
                x += w
            }
        }
    }
    return pack(f.copy(modules = f.modules + added), runs)
}

/* ---------------- the worktop ---------------- */

/** Worktop length on each wall: the lower row under it (base units, the dishwasher, fillers), mm. */
fun worktopRuns(f: Furniture): Map<String, Int> =
    f.modules.filter { !isUpper(it) && (it.type == "base" || it.type == "filler" || it.app == "dishwasher") }
        .groupBy { it.wall ?: "" }.mapValues { (_, ms) -> ms.sumOf { it.w } }

/** Worktop pieces to buy: each wall's run needs its own pieces of [pieceL] (corners are joined). */
fun worktopPieces(f: Furniture, pieceL: Int): Int =
    worktopRuns(f).values.filter { it > 0 }.sumOf { (it + pieceL - 1) / pieceL }

/* ---------------- fit checks ---------------- */

/** A finding about the design: [level] err, warn or ok; [key] its text; [mid] the module it is about. */
data class FCheck(val level: String, val key: String, val vars: Map<String, Any> = emptyMap(), val mid: String? = null)

private fun overlaps(a0: Int, a1: Int, b0: Int, b1: Int) = a0 < b1 && b0 < a1

/** What is wrong (or right) with the kitchen on its room's walls: [openings] and [points] of the room. */
fun checks(f: Furniture, runs: List<Run>, ws: Workshop, openings: List<Opening>, points: List<SitePoint>): List<FCheck> {
    val out = ArrayList<FCheck>()
    runs.forEach { r ->
        listOf(false, true).forEach { up ->
            val fl = fillOf(f, r, up)
            val left = fl.left
            if (left != null && left < 0) out += FCheck("err", if (up) "kc.overUp" else "kc.over", mapOf("w" to r.wall, "v" to -left))
            else if (!up && left != null && left > 0 && fl.used > 0) out += FCheck("warn", "kc.gap", mapOf("w" to r.wall, "v" to left))
        }
    }
    val talls = f.modules.filter { it.type == "tall" || (it.type == "gap" && it.app == "fridge") }
    f.modules.forEach { m ->
        val x0 = m.x; val x1 = m.x + m.w; val y0 = m.elev; val y1 = m.elev + m.h
        openings.filter { it.wall == m.wall }.forEach { o ->
            if (overlaps(x0, x1, o.off, o.off + o.w) && overlaps(y0, y1, o.sill, o.sill + o.h))
                out += FCheck(if (o.type == "door") "err" else "warn", if (o.type == "door") "kc.door" else "kc.window", mid = m.id)
        }
        points.filter { it.wall == m.wall }.forEach { p ->
            val (pw, ph) = pointSize(p)
            val inX = overlaps(x0, x1, p.off - pw / 2, p.off + pw / 2); val inY = overlaps(y0, y1, p.h - ph / 2, p.h + ph / 2)
            if (inX && inY) when (p.t) {
                "meter" -> out += FCheck("err", "kc.meter", mid = m.id)
                "socket", "switch" -> if (m.type != "gap") out += FCheck("warn", "kc.socket", mapOf("o" to p.off, "h" to p.h, "t" to p.t), m.id)
            }
        }
        if (isUpper(m) && m.type == "wall") talls.filter { it.wall == m.wall && overlaps(x0, x1, it.x, it.x + it.w) }.forEach { _ -> out += FCheck("warn", "kc.tallUp", mid = m.id) }
    }
    // the sink near its water and drain, the hood high enough over the hob
    f.modules.filter { it.app == "sink" }.forEach { s ->
        val c = s.x + s.w / 2
        val near = points.filter { it.wall == s.wall && (it.t == "cold" || it.t == "sewer") }.minOfOrNull { kotlin.math.abs(it.off - c) }
        if (points.any { it.t == "cold" || it.t == "sewer" }) {
            if (near == null || near > 1000) out += FCheck("warn", "kc.sinkFar", mapOf("v" to (near ?: -1)), s.id)
            else out += FCheck("ok", "kc.sinkOk", mid = s.id)
        }
    }
    f.modules.filter { it.app == "hood" }.forEach { h ->
        val gas = points.any { it.wall == h.wall && it.t == "gas" }
        val need = if (gas) 750 else 650
        val above = h.elev - worktopTop(ws)
        if (above < need) out += FCheck("warn", "kc.hood", mapOf("v" to above, "n" to need), h.id)
    }
    return out
}
