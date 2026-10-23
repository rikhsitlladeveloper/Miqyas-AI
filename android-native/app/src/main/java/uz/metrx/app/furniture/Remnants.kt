package uz.metrx.app.furniture

import kotlinx.serialization.Serializable

/*
 * Remnants (bazis ideas, 23 Oct 2026; Advanced only): the offcuts a cut list leaves, kept in the workshop's store with
 * their material and grain, and used before new sheets by the next order's cut list. Only new sheets are bought, so the
 * cost counts only them. Pure Kotlin, unit-tested (RemnantsTest).
 *
 * An order "takes" the remnants its layout used when the maker says it was cut ([cutDone]); its own offcuts go into the
 * store then. Until another order takes them they are free; an order already cut keeps exactly what it took, also once
 * that order is deleted (the board was cut: it is gone from the store).
 */

/**
 * A leftover piece of board: material [mat], [L] along the grain (the sheet's length) × [W] across, mm; [grain] the
 * material has a grain; [src] the order it was cut from, [used] the order that took it ("" free), [at] when it was kept.
 */
@Serializable
data class Remnant(val id: String, val mat: String, val L: Int, val W: Int, val grain: Boolean = false, val src: String = "", val used: String = "", val at: Long = 0)

/** The smallest remnant the workshop keeps by default, each way, mm. */
const val REM_MIN = 300

/**
 * The remnants order [order]'s cut list may use: once it was cut, the ones it took; before, the ones it holds and the
 * free ones from other orders. One taken by another order stays taken, even when that order was deleted.
 */
fun remnantsFor(all: List<Remnant>, order: String, cut: Boolean): List<Remnant> =
    if (cut) all.filter { it.used == order }
    else all.filter { it.used == order || (it.src != order && it.used.isEmpty()) }

/** Whether a remnant can be thrown away from the store: only a free one (a taken one was cut by its order). */
fun removable(r: Remnant) = r.used.isEmpty()

/** Whether order [order]'s cut can be undone: not once another order took one of its offcuts. */
fun canUndoCut(all: List<Remnant>, order: String) = all.none { it.src == order && it.used.isNotEmpty() && it.used != order }

/** The offcuts of [lays] at least [min] mm each way, as remnants cut for [order]. */
fun offcuts(lays: List<Layout>, mats: List<Mat>, min: Int, order: String, now: Long, id: () -> String): List<Remnant> =
    lays.flatMap { l ->
        val grain = mats.firstOrNull { it.id == l.mat }?.grain ?: false
        (l.sheets + l.rems).flatMap { it.rest }.filter { (a, b) -> a >= min && b >= min }.map { (a, b) -> Remnant(id(), l.mat, a, b, grain, order, "", now) }
    }

/**
 * The store once order [order] was cut by [lays]: the remnants it used are its (taken), its offcuts of [min] mm and more
 * are added. Done again it first undoes the last time, so nothing is kept twice: an offcut of this order another order
 * already took is not added again.
 */
fun cutDone(all: List<Remnant>, lays: List<Layout>, mats: List<Mat>, order: String, min: Int, now: Long, id: () -> String): List<Remnant> {
    val base = cutUndone(all, order)
    val took = lays.flatMap { l -> l.rems.mapNotNull { it.rem?.id } }.toSet()
    val had = base.filter { it.src == order }.toMutableList()
    val fresh = offcuts(lays, mats, min, order, now, id).filter { o ->
        val same = had.firstOrNull { it.mat == o.mat && it.L == o.L && it.W == o.W }
        if (same != null) { had.remove(same); false } else true
    }
    return base.map { if (it.id in took) it.copy(used = order) else it } + fresh
}

/** The store as if order [order] had not been cut: its offcuts that nobody took go, the remnants it took are free again. */
fun cutUndone(all: List<Remnant>, order: String): List<Remnant> =
    all.filter { !(it.src == order && it.used.isEmpty()) }.map { if (it.used == order) it.copy(used = "") else it }
