package uz.metrx.app.furniture

/*
 * The sheet layout, раскрой (furniture plan section 6.5): parts on full sheets with straight saw cuts edge to edge, as a
 * panel saw does. Shelf packing, biggest first: each sheet is cut into strips across its length, each strip into parts.
 * Saw cut and edge trim are kept; parts with grain keep their length along the sheet's length. Not optimal, but correct:
 * nothing overlaps and every cut can be made.
 */

/** A part on a sheet: [row] its cut list line, [x], [y] from the trimmed corner, [w] along the sheet's length, [h] across. */
data class Placed(val row: Int, val x: Int, val y: Int, val w: Int, val h: Int, val turned: Boolean)

class SheetPlan(val placed: List<Placed>)

/** One material's sheets: what went where, what could not fit on any sheet, and the waste. */
data class Layout(val mat: String, val sheetL: Int, val sheetW: Int, val sheets: List<SheetPlan>, val unplaced: List<Int>) {
    val used: Long get() = sheets.sumOf { s -> s.placed.sumOf { it.w.toLong() * it.h } }
    /** The share of the bought sheets that is not parts, 0 to 1. */
    val waste: Double get() = if (sheets.isEmpty()) 0.0 else 1.0 - used.toDouble() / (sheets.size.toLong() * sheetL * sheetW)
}

private class Strip(val y: Int, val h: Int) { var x = 0 }
private class Sheet { val strips = ArrayList<Strip>(); val placed = ArrayList<Placed>(); var yNext = 0 }

/**
 * Lays out the cut list [rows] that use material [mat] (sheet [sheetL] × [sheetW]). Each of a line's pieces is placed
 * on its own; [grain] lines may not turn.
 */
fun layout(rows: List<CutRow>, mat: String, sheetL: Int, sheetW: Int, kerf: Int, trim: Int): Layout {
    val uL = sheetL - 2 * trim; val uW = sheetW - 2 * trim
    data class Piece(val row: Int, val a: Int, val b: Int, val grain: Boolean)   // a: along the grain / length
    val pieces = rows.withIndex().filter { it.value.mat == mat }.flatMap { (i, r) -> List(r.p.qty) { Piece(i, r.cutL, r.cutW, r.p.grain) } }
    // the tallest strip height each piece would need, biggest first
    fun up(p: Piece) = if (p.grain) p.b else minOf(p.a, p.b)
    val order = pieces.sortedWith(compareByDescending<Piece> { up(it) }.thenByDescending { maxOf(it.a, it.b) })
    val sheets = ArrayList<Sheet>(); val unplaced = ArrayList<Int>()
    fun orient(p: Piece): List<Pair<Int, Int>> {
        val o = ArrayList<Pair<Int, Int>>()
        if (p.a <= uL && p.b <= uW) o += p.a to p.b
        if (!p.grain && p.b <= uL && p.a <= uW && p.a != p.b) o += p.b to p.a
        return o
    }
    for (p in order) {
        val os = orient(p)
        if (os.isEmpty()) { unplaced += p.row; continue }
        var done = false
        // an existing strip it fits in, the lowest waste of height first
        loop@ for (s in sheets) {
            val fits = s.strips.flatMap { st -> os.filter { (w, h) -> h <= st.h && st.x + w <= uL }.map { st to it } }
                .minByOrNull { (st, o) -> st.h - o.second }
            if (fits != null) {
                val (st, o) = fits
                s.placed += Placed(p.row, st.x, st.y, o.first, o.second, o.first != p.a)
                st.x += o.first + kerf; done = true; break@loop
            }
            // a new strip on this sheet: the orientation with the lower height
            val o = os.minByOrNull { it.second }!!
            if (s.yNext + o.second <= uW) {
                val st = Strip(s.yNext, o.second); s.strips += st; s.yNext += o.second + kerf
                s.placed += Placed(p.row, 0, st.y, o.first, o.second, o.first != p.a)
                st.x = o.first + kerf; done = true; break@loop
            }
        }
        if (!done) {
            val s = Sheet(); sheets += s
            val o = os.minByOrNull { it.second }!!
            val st = Strip(0, o.second); s.strips += st; s.yNext = o.second + kerf
            s.placed += Placed(p.row, 0, 0, o.first, o.second, o.first != p.a); st.x = o.first + kerf
        }
    }
    return Layout(mat, sheetL, sheetW, sheets.map { SheetPlan(it.placed.toList()) }, unplaced)
}

/** Layouts for every material of the cut list that comes in sheets (banding is bought by the metre). */
fun layouts(rows: List<CutRow>, mats: List<Mat>, ws: Workshop): List<Layout> =
    rows.map { it.mat }.distinct().map { id ->
        val m = mats.firstOrNull { it.id == id }
        layout(rows, id, m?.l?.takeIf { it > 0 } ?: ws.sheetL, m?.w?.takeIf { it > 0 } ?: ws.sheetW, ws.kerf, ws.trim)
    }
