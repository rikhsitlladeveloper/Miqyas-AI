package uz.metrx.app.win

/*
 * A window's sashes and parts as seen from inside: x from the left edge, y up from the bottom, mm. The frame runs round
 * the outside; vertical mullions stand on the columns' axes the full height inside the frame, transoms cross their own
 * column; each sash's cell is what is left inside them. From the cells: the profile metres (frame, opening sashes,
 * mullions), the glass, the panels, the hardware, handles and nets.
 */

/** A rectangle on the product, mm: [x0]…[x1] from the left, [y0]…[y1] up from the bottom. */
data class WRect(val x0: Double, val y0: Double, val x1: Double, val y1: Double) {
    val w get() = x1 - x0
    val h get() = y1 - y0
    val area get() = w * h / 1e6
}

/** Sash [row] of column [col]: its cell (inside the frame and mullions) and how it opens. */
class WSash(val col: Int, val row: Int, val cell: WCell, val r: WRect) {
    val t get() = cell.t
    val opens get() = cell.t in OPENS
}

/** A mullion or transom on its axis, [a] to [b], mm; [vertical] a mullion between columns. */
class WBar(val x0: Double, val y0: Double, val x1: Double, val y1: Double, val vertical: Boolean, val col: Int, val row: Int) {
    val len get() = if (vertical) y1 - y0 else x1 - x0
}

/** Where the columns' axes are: 0, each mullion, the full width. */
fun colEdges(it: WinItem): List<Double> = it.cols.runningFold(0.0) { a, c -> a + c.w }

/** Where a column's transoms are, down from the top: 0, each transom, the full height. */
fun rowEdges(c: WCol): List<Double> = c.rows.runningFold(0.0) { a, r -> a + r.h }

/** Every sash of window [it] with its cell. */
fun sashesOf(it: WinItem): List<WSash> {
    if (it.cols.isEmpty()) return emptyList()
    val F = frameF(it.profile).toDouble(); val M = mullF(it.profile) / 2.0
    val xs = colEdges(it); val n = it.cols.size
    val W = it.w.toDouble(); val H = it.h.toDouble()
    val out = ArrayList<WSash>()
    it.cols.forEachIndexed { i, c ->
        val x0 = if (i == 0) F else xs[i] + M
        val x1 = if (i == n - 1) W - F else xs[i + 1] - M
        val ys = rowEdges(c); val m = c.rows.size
        c.rows.forEachIndexed { j, r ->
            val top = if (j == 0) H - F else H - ys[j] - M
            val bot = if (j == m - 1) F else H - ys[j + 1] + M
            out += WSash(i, j, r, WRect(x0, bot, x1, top))
        }
    }
    return out
}

/** Every mullion (between columns, the full height inside the frame) and transom (across its column's cell). */
fun barsOf(it: WinItem): List<WBar> {
    if (it.cols.isEmpty()) return emptyList()
    val F = frameF(it.profile).toDouble(); val M = mullF(it.profile) / 2.0
    val xs = colEdges(it); val n = it.cols.size; val H = it.h.toDouble(); val W = it.w.toDouble()
    val out = ArrayList<WBar>()
    for (i in 1 until n) out += WBar(xs[i], F, xs[i], H - F, true, i - 1, 0)
    it.cols.forEachIndexed { i, c ->
        val x0 = if (i == 0) F else xs[i] + M
        val x1 = if (i == n - 1) W - F else xs[i + 1] - M
        val ys = rowEdges(c)
        for (j in 1 until c.rows.size) out += WBar(x0, H - ys[j], x1, H - ys[j], false, i, j - 1)
    }
    return out
}

/** The glass a sash holds, m²: a fixed one its cell less the bead's seat, an opening one inside its own profile. */
fun glassOf(it: WinItem, s: WSash): Double = when (s.t) {
    "panel" -> 0.0
    in OPENS -> { val f = sashF(it.profile) * 2.0 - 16; ((s.r.w - f).coerceAtLeast(0.0) * (s.r.h - f).coerceAtLeast(0.0)) / 1e6 }
    else -> ((s.r.w - 16).coerceAtLeast(0.0) * (s.r.h - 16).coerceAtLeast(0.0)) / 1e6
}

/** A sash's weight, kg: its glass and its own profile. */
fun sashKg(it: WinItem, s: WSash): Double =
    glassOf(it, s) * (if (it.glass >= 2) GLASS_KG2 else GLASS_KG1) + (if (s.opens) 2 * (s.r.w + s.r.h) / 1000 * (if (it.profile == "alu") PROF_KG_ALU else PROF_KG_PVC) else 0.0)

/** Glass weight a m²: a one-chamber unit 4-16-4, a two-chamber 4-10-4-10-4; profile a metre, with its steel. */
const val GLASS_KG1 = 20.0
const val GLASS_KG2 = 30.0
const val PROF_KG_PVC = 1.8
const val PROF_KG_ALU = 1.2

/**
 * One product's parts (one piece; [qty] pieces multiply it): profile metres, glass and panels m², hardware by sash type,
 * handles and nets; the extras' lengths and areas for a reveal [r] deep; a door's area.
 */
data class WParts(
    val frameM: Double = 0.0, val sashM: Double = 0.0, val mullM: Double = 0.0,
    val glassM2: Double = 0.0, val panelM2: Double = 0.0,
    val hw: Map<String, Int> = emptyMap(), val handles: Int = 0, val nets: Int = 0,
    val sillM: Double = 0.0, val dripM: Double = 0.0, val revealM2: Double = 0.0,
    val areaM2: Double = 0.0, val doorM2: Double = 0.0
) {
    val profileM get() = frameM + sashM + mullM
}

/** The parts of one piece of [p] with an inside reveal [r] deep. */
fun partsOf(p: WinItem, r: Int): WParts {
    val area = p.w * p.h / 1e6
    val reveal = if (p.reveals) (2.0 * p.h + p.w) * r / 1e6 else 0.0
    if (p.isDoor) return WParts(handles = if (p.handles) 1 else 0, revealM2 = reveal, areaM2 = area, doorM2 = area, hw = mapOf("door" to 1))
    val ss = sashesOf(p)
    val open = ss.filter { s -> s.opens }
    return WParts(
        frameM = 2.0 * (p.w + p.h) / 1000,
        sashM = open.sumOf { s -> 2 * (s.r.w + s.r.h) / 1000 },
        mullM = barsOf(p).sumOf { b -> b.len } / 1000,
        glassM2 = ss.sumOf { s -> glassOf(p, s) },
        panelM2 = ss.filter { s -> s.t == "panel" }.sumOf { s -> s.r.area },
        hw = open.groupBy { s -> s.t }.mapValues { e -> e.value.size },
        handles = if (p.handles) open.size else 0,
        nets = if (p.net) open.size else 0,
        sillM = if (p.sill > 0) (p.w + 2.0 * SILL_EAR) / 1000 else 0.0,
        dripM = if (p.drip) (p.w + 2.0 * DRIP_EAR) / 1000 else 0.0,
        revealM2 = reveal,
        areaM2 = area
    )
}
