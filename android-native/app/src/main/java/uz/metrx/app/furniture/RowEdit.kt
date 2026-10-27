package uz.metrx.app.furniture

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/*
 * Designer C v2 (founder's decisions and approved mockup, 27 Oct 2026, design/designer-c/mockup.html): the editing
 * rules of a row on the 2D front view, pure and unit-tested (RowEditTest). A row is a list of [Slot]s left to right: a
 * kitchen wall's lower or upper row (its modules, gaps and fillers, then the free space left at its end), or a
 * wardrobe's sections. The screens turn a piece into slots, edit them here and write the widths and order back.
 *
 *  - Width snaps to [W_SNAPS] (an appliance to its own widths); zoomed in past 2.5× it moves in 10 mm steps.
 *  - Absorb: the nearest filler or gap (the row's free end counts) takes the difference, otherwise the neighbour; a
 *    filler of 150 mm or more becomes a gap.
 *  - Delete leaves a gap; "Yopish ↔" closes it, the row's end filler or gap growing (before a corner unit).
 *  - Insert into a gap, or between two modules taking the room from the nearest gaps and fillers.
 *  - Copy goes to the right, its room from the nearest gaps and fillers; a wardrobe's copy divides it equally again.
 *  - A long-press move puts the module where its middle is nearest, the others sliding aside.
 */

/** What a slot is: a module, a gap ("Bo‘sh joy"), a filler, an appliance of fixed widths, a blind corner unit, the row's free end. */
enum class SK { MOD, GAP, FILLER, FIXED, CORNER, END }

/** One slot of a row: its id (a module's, a section's index as text, or [END_ID]), width, kind, the widths it may take (null: any). */
data class Slot(val id: String, val w: Int, val kind: SK, val allowed: List<Int>? = null, val min: Int = 150)

/** The width snaps of the founder's decision (mm). */
val W_SNAPS = listOf(150, 300, 350, 400, 450, 500, 600, 700, 800, 900, 1000, 1200)

/** A wall unit's height snaps (its top stays). */
val H_SNAPS = listOf(360, 500, 600, 720, 900)

/** A row with no length (an island): its free end never runs out. */
const val END_FREE = 1_000_000
const val END_ID = "#end"

private fun Slot.space() = kind == SK.GAP || kind == SK.FILLER || kind == SK.END

/** The narrowest a slot can be: a module its [Slot.min], a gap, a filler or the free end nothing. */
fun minOf(s: Slot) = if (s.space()) 0 else s.min

/** How much a slot can give: all of a gap's, a filler's or the free end's width, a module's down to its minimum. */
fun capOf(s: Slot) = if (s.space()) s.w else max(0, s.w - minOf(s))

/** An appliance of fixed widths never takes up a difference. */
fun canAbsorb(s: Slot) = s.kind != SK.FIXED

/**
 * Who takes the difference when slot [i] changes width: in a wardrobe ([secs]) the next section, else the one before;
 * in a kitchen row the nearest gap, filler or free end, otherwise the neighbour (right first). -1: nobody.
 */
fun absorber(row: List<Slot>, i: Int, secs: Boolean = false, grow: Boolean = true): Int {
    if (secs) return if (i + 1 < row.size) i + 1 else if (i > 0) i - 1 else -1
    var best = -1; var bd = Int.MAX_VALUE
    // the free end takes what a module gives back, but gives only what it has
    row.forEachIndexed { j, s -> if (j != i && s.space() && (s.kind != SK.END || s.w > 0 || !grow)) { val d = abs(j - i); if (d < bd) { bd = d; best = j } } }
    if (best >= 0) return best
    if (i + 1 < row.size && canAbsorb(row[i + 1]) && row[i + 1].kind != SK.END) return i + 1
    if (i > 0 && canAbsorb(row[i - 1])) return i - 1
    return -1
}

/** The widest slot [i] can get. */
fun maxW(row: List<Slot>, i: Int, secs: Boolean = false): Int = absorber(row, i, secs).let { a -> row[i].w + if (a < 0) 0 else capOf(row[a]) }

/** A resize's outcome: the row, who took the difference and its width before and after; [why] "min", "max" or "none" when it cannot. */
data class Resized(val row: List<Slot>, val ok: Boolean, val aid: String? = null, val aw0: Int = 0, val aw1: Int = 0, val why: String = "", val limit: Int = 0)

/** Slot [i] made [nw] wide, the difference taken by its [absorber]; a gap or filler left at 0 goes away. */
fun resize(row: List<Slot>, i: Int, nw: Int, secs: Boolean = false): Resized {
    val s = row[i]
    val d = nw - s.w
    if (d == 0) return Resized(row, true)
    if (nw < max(minOf(s), if (s.kind == SK.FILLER) 10 else 0)) return Resized(row, false, why = "min", limit = max(minOf(s), 10))
    val a = absorber(row, i, secs, d > 0)
    if (a < 0) return Resized(row, false, why = "none")
    val am = row[a]
    if (am.w - d < minOf(am)) return Resized(row, false, why = "max", limit = s.w + capOf(am))
    val out = row.toMutableList()
    out[i] = s.copy(w = nw); out[a] = am.copy(w = am.w - d)
    return Resized(tidy(out), true, am.id, am.w, am.w - d)
}

/** The widths offered for slot [i] up to [mx]: its allowed ones (or the snaps), and [mx] itself when any width will do. */
fun candidates(s: Slot, mx: Int): List<Int> {
    val lo = max(minOf(s), 150)
    val list = (s.allowed ?: W_SNAPS).filter { it in lo..mx }.toMutableList()
    if (s.allowed == null && mx >= lo && mx <= 1200 && mx !in list) list += mx
    return list.sorted()
}

/**
 * The width a drag to [raw] mm snaps to: the nearest candidate; zoomed in ([fine]) 10 mm steps for a slot of any width,
 * a candidate within 15 mm still winning. [cur] when there is no candidate.
 */
fun snapWidth(raw: Double, cands: List<Int>, fine: Boolean, freeW: Boolean, lo: Int, mx: Int, cur: Int): Int {
    if (fine && freeW) {
        val near = cands.firstOrNull { abs(it - raw) < 15 }
        return (near ?: ((raw / 10).roundToInt() * 10)).coerceIn(lo, max(lo, mx))
    }
    return cands.minByOrNull { abs(it - raw) } ?: cur
}

/** The nearest height snap. */
fun snapHeight(raw: Double): Int = H_SNAPS.minBy { abs(it - raw) }

/** Gaps and fillers of 0 go; a filler of 150 or more is a gap; two gaps side by side are one (a gap the user left stays a gap, even at the row's end). */
fun tidy(row: List<Slot>): List<Slot> {
    val out = row.filter { !((it.kind == SK.GAP || it.kind == SK.FILLER) && it.w <= 0) }
        .map { if (it.kind == SK.FILLER && it.w >= 150) it.copy(kind = SK.GAP, allowed = null) else it }.toMutableList()
    var i = out.size - 1
    while (i > 0) {
        val a = out[i - 1]; val b = out[i]
        if (a.kind == SK.GAP && b.kind == SK.GAP) { out[i - 1] = a.copy(w = a.w + b.w); out.removeAt(i) }
        i--
    }
    return out
}

/** Slot [i] deleted: a gap of its width stays (the "+" to add another). */
fun deleteToGap(row: List<Slot>, i: Int): List<Slot> = tidy(row.toMutableList().also { it[i] = it[i].copy(kind = SK.GAP, allowed = null, min = 0) })

/** A row edit's outcome: the row, the new slot's id, its width, who gave room ("id" to the mm), why not ([why] a strings key's tail). */
data class Planned(val row: List<Slot>, val ok: Boolean, val id: String? = null, val w: Int = 0, val took: List<Pair<String, Int>> = emptyList(),
                   val why: String = "", val free: Int = 0, val into: String? = null, val grew: Pair<String, Int>? = null, val adapted: Boolean = false)

/** Where the row's end is for "Yopish": past its corner unit(s), before the free end. */
private fun endIndex(row: List<Slot>): Int {
    var e = row.indexOfFirst { it.kind == SK.END }.let { if (it < 0) row.size else it }
    while (e > 0 && row[e - 1].kind == SK.CORNER) e--
    return e
}

/**
 * Gap [i] closed ("Yopish ↔"): the others close up and the row's end filler or gap grows by its width (before a corner
 * unit); with none there, the free end grows, or a new filler or gap goes in before the corner. [Planned.grew] who grew.
 */
fun closeGap(row: List<Slot>, i: Int, newId: String = "gap+"): Planned {
    val g = row.getOrNull(i) ?: return Planned(row, false, why = "none")
    if (g.kind != SK.GAP) return Planned(row, false, why = "none")
    val out = row.toMutableList(); out.removeAt(i)
    val e = endIndex(out)
    // nothing after it but a corner unit or the free end: it already is the row's end
    if (e <= i) return Planned(row, false, why = "atEnd")
    val last = out[e - 1]
    if (last.kind == SK.GAP || last.kind == SK.FILLER) {
        out[e - 1] = last.copy(w = last.w + g.w)
        return Planned(tidy(out), true, grew = last.id to last.w + g.w)
    }
    if (out.getOrNull(e)?.kind == SK.END) {
        out[e] = out[e].copy(w = out[e].w + g.w)
        return Planned(tidy(out), true, grew = END_ID to out[e].w)
    }
    val ns = Slot(newId, g.w, if (g.w < 150) SK.FILLER else SK.GAP, min = 0)
    out.add(e, ns)
    return Planned(tidy(out), true, grew = newId to g.w)
}

/** The largest snap not wider than [lim] (0: none). */
fun largestSnap(lim: Int): Int = W_SNAPS.lastOrNull { it <= lim } ?: 0

/** Where each slot starts, mm from the row's start. */
fun starts(row: List<Slot>): List<Int> { var x = 0; return row.map { s -> val o = x; x += s.w; o } }

/**
 * A new slot [ns] put in at [u] mm from the row's start: into the gap (or free end) under [u], its room the gap's (a
 * module of any width narrower to fit, from 150); else between the two modules nearest [u], the room taken from the
 * nearest gaps, fillers and the free end. [fixed]: an appliance that cannot be narrower.
 */
fun insertAt(row: List<Slot>, u: Int, ns: Slot, fixed: Boolean): Planned {
    val lx = starts(row)
    row.forEachIndexed { i, g ->
        if ((g.kind == SK.GAP || g.kind == SK.END) && g.w > 0 && u >= lx[i] && u <= lx[i] + g.w) return intoGap(row, i, ns, fixed, g.kind != SK.END && u - lx[i] > g.w / 2)
    }
    // between: the boundary nearest [u], not past a corner unit at the row's end nor past the free end
    val hi = endIndex(row)
    var best = 0; var bd = Int.MAX_VALUE
    for (j in 0..hi) { val bx = if (j < row.size) lx[j] else lx.lastOrNull()?.let { it + row.last().w } ?: 0; val d = abs(bx - u); if (d < bd) { bd = d; best = j } }
    return between(row, best, ns, fixed)
}

/** Into gap [i] ([right]: at its right end). */
fun intoGap(row: List<Slot>, i: Int, ns: Slot, fixed: Boolean, right: Boolean = false): Planned {
    val g = row[i]
    var nw = ns.w; var adapted = false
    if (g.w < nw) {
        if (fixed || g.w < 150) return Planned(row, false, why = "gapSmall", free = g.w, w = ns.w)
        nw = largestSnap(g.w); adapted = true
    }
    val out = row.toMutableList()
    val rem = g.w - nw
    val n = ns.copy(w = nw)
    if (rem == 0 && g.kind != SK.END) out[i] = n
    else {
        out[i] = g.copy(w = rem, kind = if (g.kind == SK.GAP && rem in 1 until 100) SK.FILLER else g.kind)
        if (right) out.add(i + 1, n) else out.add(i, n)
    }
    return Planned(tidy(out), true, n.id, nw, listOf(g.id to nw), into = g.id, adapted = adapted)
}

/** Room for [need] mm taken from the gaps, fillers and free end of [out], nearest to [at] first. */
private fun take(out: MutableList<Slot>, at: Int, need: Int, skip: String): List<Pair<String, Int>> {
    val pool = out.indices.filter { out[it].space() && out[it].id != skip }.sortedBy { abs(it - at) }
    var rem = need; val took = ArrayList<Pair<String, Int>>()
    pool.forEach { ix -> if (rem <= 0) return@forEach; val tk = minOf(out[ix].w, rem); if (tk > 0) { took += out[ix].id to tk; out[ix] = out[ix].copy(w = out[ix].w - tk); rem -= tk } }
    return took
}

private fun freeOf(row: List<Slot>, skip: Int = -1) = row.withIndex().filter { (i, s) -> i != skip && s.space() }.sumOf { it.value.w }

/** [ns] between slots [at] - 1 and [at], its room from the nearest gaps and fillers (narrower to fit when it can be). */
fun between(row: List<Slot>, at: Int, ns: Slot, fixed: Boolean): Planned {
    val free = freeOf(row)
    var need = ns.w; var adapted = false
    if (free < need) {
        if (!fixed && largestSnap(free) >= 150) { need = largestSnap(free); adapted = true }
        else return Planned(row, false, why = "noRoom", free = free, w = ns.w)
    }
    val out = row.toMutableList()
    val n = ns.copy(w = need)
    out.add(at.coerceIn(0, out.size), n)
    val took = take(out, at, need, n.id)
    return Planned(tidy(out), true, n.id, need, took, adapted = adapted)
}

/** Slot [i] copied ([copy] its new id) to its right, the room from the nearest gaps and fillers; not when there is too little. */
fun copyRight(row: List<Slot>, i: Int, copyId: String): Planned {
    val s = row[i]
    val free = freeOf(row, i)
    if (free < s.w) return Planned(row, false, why = "noRoom", free = free, w = s.w)
    val out = row.toMutableList()
    val c = s.copy(id = copyId)
    out.add(i + 1, c)
    val took = take(out, i + 1, s.w, c.id)
    return Planned(tidy(out), true, copyId, s.w, took)
}

/**
 * Slot [from] dragged so its middle is at [centre] mm from the row's start: the place among the others where its middle
 * is nearest (never past a corner unit at the row's end or the free end), the others sliding aside. The new row and
 * where it went.
 */
fun moveOrder(row: List<Slot>, from: Int, centre: Double): Pair<List<Slot>, Int> {
    val m = row[from]
    val end = row.filter { it.kind == SK.END }
    val lx = row.filterIndexed { i, s -> i != from && s.kind != SK.END }
    var hi = lx.size
    while (hi > 0 && lx[hi - 1].kind == SK.CORNER) hi--
    var best = 0; var bd = Double.MAX_VALUE; var acc = 0
    for (j in 0..hi) {
        val c = acc + m.w / 2.0
        val d = abs(c - centre)
        if (d < bd) { bd = d; best = j }
        if (j < lx.size) acc += lx[j].w
    }
    val out = lx.toMutableList().apply { add(best, m) } + end
    return out to best
}

/** Slot [i] one place to the left ([d] -1) or right (+1); null when that side is the row's end, a corner unit or the free end. */
fun moveBy(row: List<Slot>, i: Int, d: Int): List<Slot>? {
    val j = i + d
    val o = row.getOrNull(j) ?: return null
    if (o.kind == SK.END || o.kind == SK.CORNER || row[i].kind == SK.CORNER) return null
    return row.toMutableList().also { it[i] = o; it[j] = row[i] }
}

/**
 * A wall unit [i] made as wide as the unit under it and over it ([x0] .. [x0] + [w] mm from the row's start): its
 * neighbours give and take the difference. Null when a neighbour would get too narrow (or there is none).
 */
fun alignTo(row: List<Slot>, i: Int, x0: Int, w: Int): List<Slot>? {
    val lx = starts(row)
    val dl = x0 - lx[i]; val dr = (x0 + w) - (lx[i] + row[i].w)
    val out = row.toMutableList()
    if (dl != 0) {
        val l = row.getOrNull(i - 1) ?: return null
        if (l.kind == SK.FIXED || l.w + dl < minOf(l)) return null
        out[i - 1] = l.copy(w = l.w + dl)
    }
    if (dr != 0) {
        val r = row.getOrNull(i + 1) ?: return null
        if (r.kind == SK.FIXED || r.w - dr < minOf(r)) return null
        out[i + 1] = r.copy(w = r.w - dr)
    }
    out[i] = row[i].copy(w = w)
    return tidy(out)
}

/* ---------------- a wardrobe's sections ---------------- */

/** [total] split into [n] equal sections, the last one taking what rounding leaves (10 mm steps). */
fun equalSplit(total: Int, n: Int): List<Int> {
    if (n <= 1) return listOf(total)
    val base = total / n / 10 * 10
    return List(n) { if (it < n - 1) base else total - base * (n - 1) }
}

/** Section [i] deleted: the one beside it (left, else right) takes its width; null when it is the last one. */
fun secDelete(ws: List<Int>, i: Int): List<Int>? {
    if (ws.size <= 1 || i !in ws.indices) return null
    val nb = if (i > 0) i - 1 else i + 1
    return ws.toMutableList().also { it[nb] += it[i]; it.removeAt(i) }
}

/** Section [i] copied to its right, every section the same width again; null past [max] sections. */
fun secCopy(ws: List<Int>, i: Int, max: Int = 6): List<Int>? = if (ws.size >= max || i !in ws.indices) null else equalSplit(ws.sum(), ws.size + 1)
