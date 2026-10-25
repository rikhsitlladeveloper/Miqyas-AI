@file:OptIn(ExperimentalSerializationApi::class)

package uz.metrx.app.furniture

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable

/*
 * The shared furniture core's data (design/furniture/FURNITURE_PLAN.md, section 6). Every designer (kitchen, wardrobe,
 * later living room and bedroom) produces [Furniture] with [Module]s; the core turns them into parts, a cut list, a
 * sheet layout, hardware and a cost. Lengths are millimetres. Every field has a default so older orders still load.
 * Fields added later that are written only when set ([EncodeDefault.Mode.NEVER]) keep an older order's saved form,
 * and so an issued quote's fingerprint, as it was.
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
    val type: String = "",
    /** Standing away from the walls, dragged on the room's plan: a kitchen's island, or the whole piece (a desk…); null: the usual place. */
    val pose: Pose? = null,
    /** Kitchens: the legs' height under the units, mm (the carcass stays 720, the worktop follows); null: the workshop's. */
    val baseH: Int? = null,
    /** Corner pieces without a room: "L" the corner at the left end of the main wall (made-up walls D, A), "" at the right. */
    val hand: String = "",
    /** The handles' hardware id for the whole piece ("Change for all"); "" the workshop's usual handle. */
    val handle: String = ""
)

/** The workshop's rules as [f] is built: a kitchen with its own legs' height. */
fun wsOf(f: Furniture, ws: Workshop): Workshop = f.baseH?.takeIf { f.kind == "kitchen" }?.let { ws.copy(legH = it) } ?: ws

/**
 * A place in the room: [a] mm along wall [ref] from its start and [n] mm into the room is the back's left end; the
 * piece is turned [deg] from standing with its back to that wall. A piece on a wall is Pose(wall, x, 0, 0).
 */
@Serializable
data class Pose(val ref: String, val a: Int, val n: Int, val deg: Int = 0)

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
    /** Soft-close hinges; a wardrobe's section can differ ([Section.soft]). */
    val soft: Boolean = true,
    /** The piece's handles at all ("Tutqichsiz" in Change for all turns it off); the fronts left without one are in [noHandle] (Handles.kt). */
    val handles: Boolean = true,
    val label: String = "",
    /** What it is for: sink, hob, oven, dishwasher, fridge (free-standing), fridgeB (built-in), hood, micro; "" for storage. */
    val app: String = "",
    /** Wardrobes: a side panel at the left and right end; a built-in wardrobe has none where it meets a wall. */
    val sideL: Boolean = true,
    val sideR: Boolean = true,
    /** Wardrobes: sliding (купе) doors over the whole front instead of each section's doors (plan 1b-2); null: hinged. */
    val slide: Slide? = null,
    /** Wardrobes: the plinth's or the legs' height, mm; null: a plinth of 80, or the workshop's legs. */
    val base: Int? = null,
    /** An LED strip along the top inside (a vitrina's). */
    val led: Boolean = false,
    /** A board-built piece that is not a cabinet (bed, table, bar counter, mirror panel, mirror): its options (Items.kt). */
    val opt: Opt? = null,
    /** The box's own fronts without a handle (a push latch opens them): "f0".. a kitchen unit's doors or drawers, "bd0".. a bed's drawers (Handles.kt). */
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    val noHandle: List<String> = emptyList()
)

/**
 * A bed's, a table's, a bar counter's or a mirror panel's few options (Items.kt). Sizes are the module's own: across
 * ([Module.w]), out from the wall ([Module.d]) and up ([Module.h]).
 */
@Serializable
data class Opt(
    /** Beds: "legs" plain on legs, "drawers" drawers under, "lift" a lift-up base over a storage box. */
    val bed: String = "legs",
    /** Beds: the mattress, mm; the headboard's top above the floor. */
    val mw: Int = 1600, val ml: Int = 2000, val hb: Int = 1000,
    /** Tables: "board" panel legs, "metal4" four straight metal legs, "frame" a metal frame. */
    val legs: String = "board",
    /** Tables and bar counters: the top of "ldsp" (the front board) or "wt" (worktop board); rounded corners. */
    val top: String = "ldsp", val round: Boolean = false,
    /** Bunk and loft beds: the ladder at the "L" or "R" end of the front; a loft bed's space under it: "desk", "ward" or "open". */
    val ladder: String = "R", val under: String = "desk",
    /** Mirror panels: coat hooks, a hat shelf on top, the mirror's size (0: none). */
    val hooks: Int = 5, val shelf: Boolean = true, val mirW: Int = 0, val mirH: Int = 0,
    /** Bar counters: open shelves on the kitchen side, the top's overhang on the seating side, a footrest. */
    val shelves: Boolean = true, val over: Int = 300, val foot: Boolean = true
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
data class Insert(val kind: String, val pos: Int = 0, val qty: Int = 1, val h: Int = 0,
                  /** A drawer of an open section without a handle: a push latch opens it (Handles.kt). */
                  @EncodeDefault(EncodeDefault.Mode.NEVER)
                  val push: Boolean = false)

/** A wardrobe section: its width (centre to centre of the dividers, the outer ones to the sides' outer faces). */
@Serializable
data class Section(val w: Int, val fronts: Fronts = Fronts("door", 2), val inserts: List<Insert> = emptyList(), val lock: Boolean = false,
                   /** A desk's knee space: no bottom, back or inside (Cabinets.kt). */
                   val knee: Boolean = false,
                   /** A single door's hinge edge: "L" it opens to the left, "R" to the right; "" as usual (Wardrobe.kt hingeRight). */
                   val hinge: String = "",
                   /** A corner unit's blind part: this many mm at the right end of the front have no door (the other arm closes them). */
                   val blind: Int = 0,
                   /** The doors' face: "" the front board, "mirror" a mirror on the board, "glass" glass in an aluminium frame (a vitrina's). */
                   val face: String = "",
                   /** The doors (0 the left one) without a handle: a push latch opens them (Handles.kt). */
                   @EncodeDefault(EncodeDefault.Mode.NEVER)
                   val noHandle: List<Int> = emptyList(),
                   /** Soft-close hinges on this section's doors; null: as the box ([Module.soft]). */
                   @EncodeDefault(EncodeDefault.Mode.NEVER)
                   val soft: Boolean? = null)

/** The width the section's doors (or drawers) cover: all of it but a corner unit's blind part. */
fun frontW(s: Section) = (s.w - s.blind).coerceAtLeast(0)
