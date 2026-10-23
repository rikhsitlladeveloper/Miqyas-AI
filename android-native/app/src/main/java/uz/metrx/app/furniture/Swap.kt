package uz.metrx.app.furniture

/*
 * "Change for all" (bazis ideas, 23 Oct 2026): the fronts' board or the handles of every piece of an order in one
 * tap; the screen keeps the pieces as they were for Undo. Pure Kotlin, unit-tested (BazisTest).
 */

/** No handles at all: the fronts open by a push latch. */
const val NO_HANDLES = "none"

/**
 * Every piece of [fs] with [front] as its fronts' board (null: as it was) and [handle] as its handles (a hardware id;
 * [NO_HANDLES] none; null: as they were). Room-less pieces and pieces in rooms alike; empty ones stay as they are.
 */
fun swapAll(fs: List<Furniture>, front: String? = null, handle: String? = null): List<Furniture> = fs.map { f ->
    var g = f
    if (front != null) g = g.copy(mats = g.mats.copy(front = front))
    if (handle != null) {
        val on = handle != NO_HANDLES
        g = g.copy(handle = if (on) handle else g.handle, modules = g.modules.map { m -> if (!takesHandles(m)) m else m.copy(handles = on) })
    }
    g
}

/** A unit that can have handles: not a kitchen's space for a fridge or a cooker (a dishwasher's gap has its front). */
fun takesHandles(m: Module) = !(m.type == "gap" && m.app != "dishwasher")

/** Whether a piece shows handles anywhere (its spaces for a fridge or cooker do not count). */
fun hasHandles(f: Furniture) = f.modules.any { it.handles && takesHandles(it) }

/** The fronts' board all of [fs] share, or null when they differ (or there are none). */
fun commonFront(fs: List<Furniture>): String? = fs.map { it.mats.front }.distinct().singleOrNull()

/** The handles all of [fs] share: a hardware id, "" the usual one, [NO_HANDLES]; null when they differ. */
fun commonHandle(fs: List<Furniture>): String? = fs.filter { f -> f.modules.any { it.type != "gap" } }.map { f ->
    if (!hasHandles(f)) NO_HANDLES else f.handle
}.distinct().singleOrNull()
