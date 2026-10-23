package uz.metrx.app.furniture

/*
 * The sheet layout, раскрой (furniture plan section 6.5): parts on full sheets with straight saw cuts edge to edge, as a
 * panel saw does. Shelf packing, biggest first: each sheet is cut into strips across its length, each strip into parts.
 * Saw cut and edge trim are kept; parts with grain keep their length along the sheet's length. Not optimal, but correct:
 * nothing overlaps and every cut can be made.
 */

/** A part on a sheet: [row] its cut list line, [x], [y] from the trimmed corner, [w] along the sheet's length, [h] across. */
data class Placed(val row: Int, val x: Int, val y: Int, val w: Int, val h: Int, val turned: Boolean)

/**
 * One board the parts went on: a new sheet, or [rem] a remnant from the workshop's store (bazis ideas, 23 Oct 2026);
 * [rest] the offcuts left on it that a saw can cut off whole, length (along the sheet's length) × width.
 */
class SheetPlan(val placed: List<Placed>, val rem: Remnant? = null, val rest: List<Pair<Int, Int>> = emptyList())

/**
 * One material's boards: the new sheets, what could not fit on any sheet, the waste; [rems] the remnants used before
 * any new sheet (only the new sheets are bought).
 */
data class Layout(val mat: String, val sheetL: Int, val sheetW: Int, val sheets: List<SheetPlan>, val unplaced: List<Int>, val rems: List<SheetPlan> = emptyList()) {
    val used: Long get() = sheets.sumOf { s -> s.placed.sumOf { it.w.toLong() * it.h } }
    /** The share of the bought sheets that is not parts, 0 to 1. */
    val waste: Double get() = if (sheets.isEmpty()) 0.0 else 1.0 - used.toDouble() / (sheets.size.toLong() * sheetL * sheetW)
}

private class Strip(val y: Int, val h: Int) { var x = 0 }
/** A board being filled: [uL] × [uW] usable (a sheet less its trimmed edges, a remnant whole). */
private class Stock(val uL: Int, val uW: Int, val rem: Remnant? = null) { val strips = ArrayList<Strip>(); val placed = ArrayList<Placed>(); var yNext = 0 }

/**
 * Lays out the cut list [rows] that use material [mat] (sheet [sheetL] × [sheetW]). Each of a line's pieces is placed
 * on its own; [grain] lines may not turn. The remnants [rems] of this material are filled first, the smallest first
 * (their length runs along the grain like a sheet's); then new sheets.
 */
fun layout(rows: List<CutRow>, mat: String, sheetL: Int, sheetW: Int, kerf: Int, trim: Int, rems: List<Remnant> = emptyList()): Layout {
    val uL = sheetL - 2 * trim; val uW = sheetW - 2 * trim
    data class Piece(val row: Int, val a: Int, val b: Int, val grain: Boolean)   // a: along the grain / length
    val pieces = rows.withIndex().filter { it.value.mat == mat }.flatMap { (i, r) -> List(r.p.qty) { Piece(i, r.cutL, r.cutW, r.p.grain) } }
    // the tallest strip height each piece would need, biggest first
    fun up(p: Piece) = if (p.grain) p.b else minOf(p.a, p.b)
    val order = pieces.sortedWith(compareByDescending<Piece> { up(it) }.thenByDescending { maxOf(it.a, it.b) })
    val remBoards = rems.filter { it.mat == mat && it.L > 0 && it.W > 0 }.sortedBy { it.L.toLong() * it.W }.map { Stock(it.L, it.W, it) }
    val sheets = ArrayList<Stock>(); val unplaced = ArrayList<Int>()
    fun orient(p: Piece, l: Int, w: Int): List<Pair<Int, Int>> {
        val o = ArrayList<Pair<Int, Int>>()
        if (p.a <= l && p.b <= w) o += p.a to p.b
        if (!p.grain && p.b <= l && p.a <= w && p.a != p.b) o += p.b to p.a
        return o
    }
    for (p in order) {
        if (orient(p, uL, uW).isEmpty()) { unplaced += p.row; continue }
        var done = false
        // an existing strip it fits in, the lowest waste of height first; remnants before the sheets
        loop@ for (s in remBoards + sheets) {
            val os = orient(p, s.uL, s.uW)
            if (os.isEmpty()) continue
            val fits = s.strips.flatMap { st -> os.filter { (w, h) -> h <= st.h && st.x + w <= s.uL }.map { st to it } }
                .minByOrNull { (st, o) -> st.h - o.second }
            if (fits != null) {
                val (st, o) = fits
                s.placed += Placed(p.row, st.x, st.y, o.first, o.second, o.first != p.a)
                st.x += o.first + kerf; done = true; break@loop
            }
            // a new strip on this board: the orientation with the lower height
            val o = os.minByOrNull { it.second }!!
            if (s.yNext + o.second <= s.uW) {
                val st = Strip(s.yNext, o.second); s.strips += st; s.yNext += o.second + kerf
                s.placed += Placed(p.row, 0, st.y, o.first, o.second, o.first != p.a)
                st.x = o.first + kerf; done = true; break@loop
            }
        }
        if (!done) {
            val s = Stock(uL, uW); sheets += s
            val o = orient(p, uL, uW).minByOrNull { it.second }!!
            val st = Strip(0, o.second); s.strips += st; s.yNext = o.second + kerf
            s.placed += Placed(p.row, 0, 0, o.first, o.second, o.first != p.a); st.x = o.first + kerf
        }
    }
    // what is left on a board, as a panel saw cuts it: the end of each strip, and the whole width under the last strip
    fun rest(b: Stock): List<Pair<Int, Int>> =
        (b.strips.map { (b.uL - it.x).coerceAtLeast(0) to it.h } + (b.uL to (b.uW - b.yNext).coerceAtLeast(0)))
            .filter { it.first > 0 && it.second > 0 }.sortedByDescending { it.first.toLong() * it.second }
    fun plan(b: Stock) = SheetPlan(b.placed.toList(), b.rem, rest(b))
    return Layout(mat, sheetL, sheetW, sheets.map(::plan), unplaced, remBoards.filter { it.placed.isNotEmpty() }.map(::plan))
}

/** Layouts for every material of the cut list that comes in sheets (banding is bought by the metre); the store's [rems] first. */
fun layouts(rows: List<CutRow>, mats: List<Mat>, ws: Workshop, rems: List<Remnant> = emptyList()): List<Layout> =
    rows.map { it.mat }.distinct().map { id ->
        val m = mats.firstOrNull { it.id == id }
        layout(rows, id, m?.l?.takeIf { it > 0 } ?: ws.sheetL, m?.w?.takeIf { it > 0 } ?: ws.sheetW, ws.kerf, ws.trim, rems)
    }
