package uz.metrx.app.furniture

import kotlinx.serialization.Serializable

/*
 * The shared furniture core's data (design/furniture/FURNITURE_PLAN.md, section 6). Every designer (kitchen, wardrobe,
 * later living room and bedroom) produces [Furniture] with [Module]s; the core turns them into parts, a cut list, a
 * sheet layout, hardware and a cost. Lengths are millimetres. Every field has a default so older orders still load.
 */

/** A piece of furniture in an order: [kind] kitchen or wardrobe; its [modules]; which material plays which role. */
@Serializable
data class Furniture(
    val id: String,
    val kind: String,
    val name: String = "",
    val roomId: String? = null,
    val walls: List<String> = emptyList(),
    val modules: List<Module> = emptyList(),
    val mats: FMats = FMats(),
    val created: Long = 0,
    /** Kitchens: I (one wall), L, U, O (a wall and an island), P (a wall and a peninsula). */
    val layout: String = "I",
    /** The workspace it belongs to ("" for furniture without a room). */
    val ws: String = "",
    /** Without a room ([roomId] null): the typed sizes (Free.kt). */
    val free: FreeSize? = null,
    /** The gallery model it started from (Free.kt F_MODELS), "" when made in a room. */
    val model: String = "",
    /** Put in a room although bigger than its wall or ceiling ("O‘lchamni saqlash"). */
    val keep: Boolean = false,
    /** Kitchens: the worktop joints and cut-outs, backsplash, plinth, cornice, LED and end panels (KitchenExtras.kt). */
    val kx: KExtras? = null,
    /** A cabinet on the wardrobe's engine ([kind] "wardrobe"): "" a wardrobe, or a Stage 2 type (Cabinets.kt CASE_TYPES). */
    val type: String = ""
)

/** Material ids (from the workshop's list) for the carcass, the fronts and the back panel. */
@Serializable
data class FMats(val carcass: String = "ldsp16w", val front: String = "ldsp16k", val back: String = "hdf3")

/**
 * One box. [type]: base (on legs, two rails on top), wall (hung), tall (on legs, full height), wardrobe (one carcass
 * split into [sections] by dividers), gap (no carcass: a dishwasher's panel or a free-standing fridge's space) or filler
 * (a strip of front board closing a gap). [w] × [h] × [d] is the carcass (legs not included); [x] along its run on [wall],
 * [elev] its bottom above the floor (wall units).
 */
@Serializable
data class Module(
    val id: String,
    val type: String,
    val w: Int,
    val h: Int,
    val d: Int,
    val x: Int = 0,
    val wall: String? = null,
    val elev: Int = 0,
    val fronts: Fronts = Fronts(),
    val inserts: List<Insert> = emptyList(),
    val sections: List<Section> = emptyList(),
    val legs: Boolean = true,
    val soft: Boolean = true,
    val handles: Boolean = true,
    val label: String = "",
    /** What it is for: sink, hob, oven, dishwasher, fridge (free-standing), fridgeB (built-in), hood, micro; "" for storage. */
    val app: String = "",
    /** Wardrobes: a side panel at the left and right end; a built-in wardrobe has none where it meets a wall. */
    val sideL: Boolean = true,
    val sideR: Boolean = true,
    /** Wardrobes: sliding (купе) doors over the whole front instead of each section's doors (plan 1b-2); null: hinged. */
    val slide: Slide? = null
)

/**
 * Sliding doors (furniture plan section 8, Stage 1b): [n] doors (2–4) in two tracks, each overlapping the next; each
 * door's filling in [panels]: "ldsp" (the front board), "mirror" or "glass" (lacobel), in a profile frame.
 */
@Serializable
data class Slide(val n: Int = 2, val panels: List<String> = emptyList()) {
    fun panel(i: Int) = panels.getOrElse(i) { "ldsp" }
}

/** What closes a box or a section: [kind] door, drawer, open or panel (an appliance's front); [n] how many. */
@Serializable
data class Fronts(val kind: String = "door", val n: Int = 1)

/**
 * Inside a box or a section: [kind] shelf, rail, drawer, trouser (pull-out rack), shoe (pull-out rack) or lift (a
 * pull-down rail); [pos] mm above the section's floor (its bottom edge, for blocks); [qty] for shelves; [h] for blocks.
 */
@Serializable
data class Insert(val kind: String, val pos: Int = 0, val qty: Int = 1, val h: Int = 0)

/** A wardrobe section: its width (centre to centre of the dividers, the outer ones to the sides' outer faces). */
@Serializable
data class Section(val w: Int, val fronts: Fronts = Fronts("door", 2), val inserts: List<Insert> = emptyList(), val lock: Boolean = false,
                   /** A desk's knee space: no bottom, back or inside (Cabinets.kt). */
                   val knee: Boolean = false)
