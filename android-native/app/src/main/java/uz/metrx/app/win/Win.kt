package uz.metrx.app.win

import kotlinx.serialization.Serializable
import kotlin.math.max
import kotlin.math.roundToInt

/*
 * The windows-and-doors app (Deraza-eshik, 22 Oct 2026, built like the plumber's): products picked from a gallery by
 * group (windows, balcony, doors) fill the measured openings of a room (their size the opening's less the fitting gap
 * each side) or stand without a room at a typed size. A window is split into sashes (tabaqa) by vertical and horizontal
 * mullions (impost); each sash is fixed, turns, tilts, tilts and turns, slides or is an opaque panel; the profile is PVC
 * or aluminium with its chambers, the glass unit one- or two-chamber, the colour inside and out; the extras are the sill
 * (podokonnik), the drip (otliv), the reveals (otkos), the mosquito net and the handles. A door is its type, its size,
 * its hinge side and which way it opens. Rules warn; the advanced app prices it from its parts. Lengths are mm. Pure
 * Kotlin, unit-tested (WinTest): sashes and parts in Geo.kt, rooms and placing in Place.kt, warnings in Warn.kt,
 * counting and the estimate in Count.kt, 3D in Mesh.kt.
 */

/**
 * One sash of a window column: [h] its height between the transoms' axes (rows from the top), how it opens [t] (one of
 * [SASH_TYPES]) and its hinge side [hinge] as seen from inside ("L" or "R"; a sliding sash: the way it slides open).
 */
@Serializable
data class WCell(val h: Int, val t: String = "fix", val hinge: String = "L")

/** A column of a window between the mullions' axes: [w] wide, its sashes from the top. */
@Serializable
data class WCol(val w: Int, val rows: List<WCell>)

/**
 * A window or door: [kind] its gallery type ([W_KINDS]); in room [roomId] filling opening [opening] (both null: without
 * a room, [qty] alike, named [name], in a wall [freeT] thick); [w] × [h] its size; [gap] the fitting gap each side (a
 * door opening has none at the floor); [cols] a window's sashes. The profile [profile] (pvc, alu) with [chambers], the
 * glass unit's chambers [glass] (1, 2), the colour or laminate inside [colIn] and outside [colOut]. Extras: the sill
 * [sill] mm deep (0: none), the drip, the reveals, mosquito nets, handles. A door: [hinge] side seen from inside, opens
 * [swing] in (into this room) or out; a sliding one slides towards [hinge]. [fit]: its size follows its opening.
 */
@Serializable
data class WinItem(
    val id: String,
    val kind: String,
    val roomId: String? = null,
    val opening: String? = null,
    val w: Int,
    val h: Int,
    val gap: Int = GAP,
    val cols: List<WCol> = emptyList(),
    val profile: String = "pvc",
    val chambers: Int = 5,
    val glass: Int = 2,
    val colIn: String = "white",
    val colOut: String = "white",
    val sill: Int = 0,
    val drip: Boolean = false,
    val reveals: Boolean = false,
    val net: Boolean = false,
    val handles: Boolean = true,
    val hinge: String = "L",
    val swing: String = "in",
    val name: String = "",
    val qty: Int = 1,
    val freeT: Int = FREE_T,
    /** In a room: the size follows the opening (less the gap); false once a size is typed by hand. */
    val fit: Boolean = true
) {
    val isDoor get() = kind in DOOR_KINDS
    val inRoom get() = roomId != null && opening != null
}

/** A windows-and-doors order: its products, and the fitting gap new ones get. */
@Serializable
data class WinOrder(val items: List<WinItem> = emptyList(), val gap: Int = GAP) {
    val empty get() = items.isEmpty()
    fun item(id: String) = items.firstOrNull { it.id == id }
}

/** The fitting gap round a product in its opening, each side, mm (15–20 is usual); the range a maker can type. */
const val GAP = 20
const val GAP_MIN = 0
const val GAP_MAX = 60
/** A wall's thickness for a product without a room, mm. */
const val FREE_T = 300
/** The sill's ears into the side reveals and the drip's, each side; the sill's usual overhang past the wall's face; the most it may stick out. */
const val SILL_EAR = 50
const val DRIP_EAR = 25
const val SILL_OVER = 50
const val SILL_OVER_MAX = 100
/** A door's frame (korobka) seen from the front, mm; its depth. */
const val DOOR_FRAME = 40
const val DOOR_DEPTH = 100
/** A sash at least this high counts as a door's (a balcony door, a panoramic one): its own limits. */
const val DOOR_SASH_H = 1800

val SASH_TYPES = listOf("fix", "turn", "tilt", "tt", "slide", "panel")
/** Sash types that open (a handle, hardware, a net). */
val OPENS = setOf("turn", "tilt", "tt", "slide")
/** Sash types that swing into the room as they turn. */
val SWINGS = setOf("turn", "tt")
val PROFILES = listOf("pvc", "alu")
/** Chamber counts a profile comes in: PVC 3, 5, 6, 7; aluminium 1 (cold) or 3 (warm, with a thermal break). */
fun chambersOf(profile: String) = if (profile == "alu") listOf(1, 3) else listOf(3, 5, 6, 7)
val GLASSES = listOf(1, 2)
/** Colours and laminates: white, cream, golden oak, walnut, mahogany, anthracite, silver. */
val COLOURS = listOf("white", "cream", "goak", "walnut", "mahog", "anthr", "silver")
fun colourRgb(c: String) = when (c) {
    "cream" -> 0xEFE6D2; "goak" -> 0xB7813F; "walnut" -> 0x6E4B30; "mahog" -> 0x7B3A2B; "anthr" -> 0x3D434B; "silver" -> 0xB9C0C8; else -> 0xF4F5F2
}
val DOOR_KINDS = setOf("dint", "dent", "dsl", "dgl")

/** A frame's face seen from inside, mm: PVC 60, aluminium 50. */
fun frameF(profile: String) = if (profile == "alu") 50 else 60
/** A mullion's face, mm: PVC 80, aluminium 70. */
fun mullF(profile: String) = if (profile == "alu") 70 else 80
/** An opening sash's own profile inside its cell, mm: PVC 75, aluminium 60. */
fun sashF(profile: String) = if (profile == "alu") 60 else 75
/** How deep the frame is (into the wall), mm: PVC by its chambers, aluminium cold or warm. */
fun frameDepth(it: WinItem) = when {
    it.isDoor -> DOOR_DEPTH
    it.profile == "alu" -> if (it.chambers >= 3) 65 else 50
    else -> when (it.chambers) { 3 -> 58; 6 -> 76; 7 -> 82; else -> 70 }
}

/** The inside reveal's depth, mm: the frame stands in the middle of a wall [t] thick. */
fun revealOf(t: Int, depth: Int) = max(0, (t - depth) / 2)

/** The usual sill depth for a reveal [r] deep: past the wall's face by [SILL_OVER], in whole 50 mm. */
fun sillFor(r: Int) = max(150, ((r + SILL_OVER + 49) / 50) * 50)

/**
 * A gallery type: [group] win, balc or door; [w] × [h] its usual size; [cols] its sashes at that size; [profile] its
 * usual profile; [col] a door's usual colour.
 */
class WKind(val id: String, val group: String, val w: Int, val h: Int, val cols: List<WCol> = emptyList(), val profile: String = "pvc", val col: String = "white") {
    val isDoor get() = id in DOOR_KINDS
}

private fun c1(w: Int, h: Int, t: String, hinge: String = "L") = WCol(w, listOf(WCell(h, t, hinge)))

val W_KINDS = listOf(
    WKind("w1", "win", 700, 1400, listOf(c1(700, 1400, "tt", "L"))),
    WKind("w2", "win", 1300, 1400, listOf(c1(650, 1400, "fix"), c1(650, 1400, "tt", "R"))),
    WKind("w3", "win", 2000, 1400, listOf(c1(650, 1400, "turn", "L"), c1(700, 1400, "fix"), c1(650, 1400, "tt", "R"))),
    WKind("wfix", "win", 1400, 1800, listOf(WCol(700, listOf(WCell(450), WCell(1350, "tt", "L"))), WCol(700, listOf(WCell(450), WCell(1350))))),
    WKind("wtt", "win", 1400, 1400, listOf(c1(700, 1400, "tt", "L"), c1(700, 1400, "tt", "R"))),
    WKind("wsl", "win", 1800, 1400, listOf(c1(900, 1400, "slide", "R"), c1(900, 1400, "slide", "L")), "alu", "silver"),
    WKind("pano", "win", 2400, 2400, listOf(c1(800, 2400, "fix"), c1(800, 2400, "tt", "L"), c1(800, 2400, "fix"))),
    WKind("balc", "balc", 1950, 2100, listOf(c1(750, 2100, "tt", "L"), WCol(1200, listOf(WCell(1250), WCell(850, "panel"))))),
    WKind("bglz", "balc", 3000, 1400, listOf(c1(750, 1400, "slide", "R"), c1(750, 1400, "slide", "R"), c1(750, 1400, "slide", "L"), c1(750, 1400, "slide", "L")), "alu", "silver"),
    WKind("dint", "door", 800, 2000, col = "walnut"),
    WKind("dent", "door", 900, 2050, col = "anthr"),
    WKind("dsl", "door", 800, 2000, col = "white"),
    WKind("dgl", "door", 800, 2000, col = "silver")
)

/** The gallery's groups, in order. */
val W_GROUPS = listOf("win", "balc", "door")

fun wkind(id: String) = W_KINDS.firstOrNull { it.id == id } ?: W_KINDS[0]

/** Which openings a type fills: doors the doors, windows the windows, a balcony block either. */
fun fillsType(kind: String, openingType: String) = when (kind) {
    in DOOR_KINDS -> openingType == "door"
    "balc" -> true
    else -> openingType == "window"
}

/** [parts] mm shared out in proportion to [weights], in whole 5 mm, the last taking what is left. */
fun share(total: Int, weights: List<Int>): List<Int> {
    if (weights.isEmpty()) return emptyList()
    val sum = weights.sum().coerceAtLeast(1)
    val out = weights.dropLast(1).map { ((it.toDouble() * total / sum) / 5).roundToInt() * 5 }.toMutableList()
    out += total - out.sum()
    return out
}

/** The sashes [cols] stretched to [w] × [h], in proportion. */
fun scaled(cols: List<WCol>, w: Int, h: Int): List<WCol> {
    val ws = share(w, cols.map { it.w })
    return cols.mapIndexed { i, c -> val hs = share(h, c.rows.map { it.h }); WCol(ws[i], c.rows.mapIndexed { j, r -> r.copy(h = hs[j]) }) }
}

/** A product's size for an opening [ow] × [oh] of [type]: less the gap each side; a door opening has none at the floor. */
fun sizeFor(ow: Int, oh: Int, type: String, gap: Int): Pair<Int, Int> =
    max(100, ow - 2 * gap) to max(100, oh - (if (type == "door") gap else 2 * gap))

/** A new product of type [k] sized [w] × [h], with that type's usual sashes, profile and colours. */
fun newItem(id: String, k: WKind, w: Int = k.w, h: Int = k.h, gap: Int = GAP, roomId: String? = null, opening: String? = null): WinItem {
    val col = if (k.isDoor) k.col else if (k.profile == "alu") "silver" else "white"
    return WinItem(id, k.id, roomId, opening, w, h, gap, if (k.isDoor) emptyList() else scaled(k.cols, w, h), k.profile,
        if (k.profile == "alu") 3 else 5, 2, col, col, drip = !k.isDoor && roomId != null, sill = 0, handles = true)
}

/** [it] refitted to an opening [ow] × [oh] of [type] with its own gap: the size, the sashes in proportion. */
fun refit(it: WinItem, ow: Int, oh: Int, type: String): WinItem {
    val (w, h) = sizeFor(ow, oh, type, it.gap)
    return resized(it, w, h)
}

/** [it] at a new size, its sashes in proportion. */
fun resized(it: WinItem, w: Int, h: Int): WinItem = it.copy(w = w, h = h, cols = if (it.cols.isEmpty()) it.cols else scaled(it.cols, w, h))

/* ---------------- changing the sashes ---------------- */

/** Splits column [ci] in two halves (a new vertical mullion); the new half copies the sash. */
fun splitCol(it: WinItem, ci: Int): WinItem {
    val c = it.cols.getOrNull(ci) ?: return it
    val a = (c.w / 2 / 5) * 5
    val cs = it.cols.toMutableList()
    cs[ci] = c.copy(w = a); cs.add(ci + 1, c.copy(w = c.w - a, rows = c.rows.map { r -> r.copy(hinge = if (r.hinge == "L") "R" else "L") }))
    return it.copy(cols = cs)
}

/** Splits sash [ri] of column [ci] in two (a new transom), the upper half fixed. */
fun splitRow(it: WinItem, ci: Int, ri: Int): WinItem {
    val c = it.cols.getOrNull(ci) ?: return it
    val r = c.rows.getOrNull(ri) ?: return it
    val top = (r.h / 2 / 5) * 5
    val rows = c.rows.toMutableList()
    rows[ri] = r.copy(h = r.h - top); rows.add(ri, WCell(top, "fix"))
    return it.copy(cols = it.cols.mapIndexed { i, x -> if (i == ci) x.copy(rows = rows) else x })
}

/** Takes away the mullion beside sash [ri] of column [ci]: the transom over it (else under it), else the column's mullion to its right (else left). */
fun mergeAt(it: WinItem, ci: Int, ri: Int): WinItem {
    val c = it.cols.getOrNull(ci) ?: return it
    if (c.rows.size > 1) {
        val other = if (ri > 0) ri - 1 else ri + 1
        val keep = c.rows[ri]
        val rows = c.rows.toMutableList()
        val lo = minOf(ri, other)
        rows[lo] = keep.copy(h = c.rows[ri].h + c.rows[other].h); rows.removeAt(lo + 1)
        return it.copy(cols = it.cols.mapIndexed { i, x -> if (i == ci) x.copy(rows = rows) else x })
    }
    if (it.cols.size < 2) return it
    val other = if (ci < it.cols.size - 1) ci + 1 else ci - 1
    val lo = minOf(ci, other)
    val cs = it.cols.toMutableList()
    cs[lo] = c.copy(w = c.w + it.cols[other].w); cs.removeAt(lo + 1)
    return it.copy(cols = cs)
}

/** Moves the vertical mullion after column [ci] to [x] mm from the left (each column kept at least [min] wide). */
fun moveMullion(it: WinItem, ci: Int, x: Int, min: Int = 150): WinItem {
    if (ci < 0 || ci >= it.cols.size - 1) return it
    val start = it.cols.take(ci).sumOf { it.w }
    val pair = it.cols[ci].w + it.cols[ci + 1].w
    val a = (x - start).coerceIn(min, pair - min)
    return it.copy(cols = it.cols.mapIndexed { i, c -> when (i) { ci -> c.copy(w = a); ci + 1 -> c.copy(w = pair - a); else -> c } })
}

/** Moves the transom under sash [ri] of column [ci] to [y] mm down from the top. */
fun moveTransom(it: WinItem, ci: Int, ri: Int, y: Int, min: Int = 150): WinItem {
    val c = it.cols.getOrNull(ci) ?: return it
    if (ri < 0 || ri >= c.rows.size - 1) return it
    val start = c.rows.take(ri).sumOf { it.h }
    val pair = c.rows[ri].h + c.rows[ri + 1].h
    val a = (y - start).coerceIn(min, pair - min)
    return it.copy(cols = it.cols.mapIndexed { i, x -> if (i != ci) x else x.copy(rows = x.rows.mapIndexed { j, r -> when (j) { ri -> r.copy(h = a); ri + 1 -> r.copy(h = pair - a); else -> r } }) })
}

/** Sets column [ci]'s width to [w], the next column (else the one before) taking the difference. */
fun setColW(it: WinItem, ci: Int, w: Int): WinItem {
    if (it.cols.size < 2 || ci !in it.cols.indices) return it
    return if (ci < it.cols.size - 1) moveMullion(it, ci, it.cols.take(ci).sumOf { it.w } + w)
    else moveMullion(it, ci - 1, it.w - w)
}

/** Sets sash [ri]'s height in column [ci] to [h], the sash under it (else over it) taking the difference. */
fun setRowH(it: WinItem, ci: Int, ri: Int, h: Int): WinItem {
    val c = it.cols.getOrNull(ci) ?: return it
    if (c.rows.size < 2 || ri !in c.rows.indices) return it
    return if (ri < c.rows.size - 1) moveTransom(it, ci, ri, c.rows.take(ri).sumOf { it.h } + h)
    else moveTransom(it, ci, ri - 1, c.rows.sumOf { it.h } - h)
}

/** Changes sash [ri] of column [ci]. */
fun setCell(it: WinItem, ci: Int, ri: Int, f: (WCell) -> WCell): WinItem =
    it.copy(cols = it.cols.mapIndexed { i, c -> if (i != ci) c else c.copy(rows = c.rows.mapIndexed { j, r -> if (j == ri) f(r) else r }) })
