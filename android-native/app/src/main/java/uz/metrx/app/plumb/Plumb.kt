package uz.metrx.app.plumb

import kotlinx.serialization.Serializable

/*
 * The plumber's app (Santexnik, 22 Oct 2026, built like the electrician's): fixtures (toilet, basin, bath, shower,
 * kitchen sink, washing and dish washers, water heater, gas boiler, radiators, towel rail, the underfloor heating's
 * manifold) placed against a measured room's walls from room kits, each with its water and drain outlets at their usual
 * heights; the riser (stoyak) with its meters, filters and main valves on a wall; the cold, hot, drain and heating
 * routes worked out from them along the walls and floor through the doorways; underfloor heating loops; rules that
 * warn; and in the advanced app the pipe, fittings, valves and labour. Rooms that are not measured can be typed by size
 * with fixture counts. Lengths are mm. Pure Kotlin, unit-tested (PlumbTest): placing in Place.kt, routes and heating in
 * Routes.kt, warnings in Warn.kt, counting in Count.kt, 3D in Mesh.kt.
 */

/** One outlet of a fixture: [t] cold, hot, drain, hs (heating supply) or hr (return); [dx] along the wall from the fixture's centre; [h] up; [d] a drain's diameter. */
@Serializable
data class FixPt(val t: String, val dx: Int, val h: Int, val d: Int = 0)

/**
 * One fixture against wall [wall] of room [roomId], centred [off] from the wall's start corner. [t] one of
 * [FIX_TYPES]; [w] its width along the wall when set (a radiator's, by the room's heat; 0: the type's); [opt] "cab" a
 * basin on a cabinet; [pts] its outlets (they move with it); [kit] the kit that placed it.
 */
@Serializable
data class PlFix(val id: String, val t: String, val roomId: String, val wall: String, val off: Int, val w: Int = 0, val opt: String = "",
                 val pts: List<FixPt> = emptyList(), val kit: String = "")

/** An outlet on its own (not a fixture's): [t] cold, hot, drain, hs or hr; [from] the room's site point it was taken from. */
@Serializable
data class PlPoint(val id: String, val t: String, val roomId: String, val wall: String, val off: Int, val h: Int, val d: Int = 0, val from: String? = null)

/** The riser (stoyak) with the meters, filters and main valves: on [wall] of room [roomId], [off] along it. [hot]: the building's hot water comes up it too. */
@Serializable
data class PlRiser(val roomId: String, val wall: String, val off: Int, val hot: Boolean = true)

/** The choices of a kit (the steps): bath, tray or cabin; basin on a cabinet; washer, towel rail, dishwasher, hand basin; heater; radiators; underfloor heating at [step] mm. */
@Serializable
data class POpts(val bath: String = "bath", val cab: Boolean = false, val wm: Boolean = true, val tr: Boolean = false, val dw: Boolean = true,
                 val basin: Boolean = true, val heater: String = "gb", val rad: Boolean = false, val ufh: Boolean = false, val step: Int = UFH_STEP)

/** A kit chosen for a room not measured yet: put in once the room is measured. */
@Serializable
data class PKitPick(val kit: String, val o: POpts = POpts())

/**
 * A room as the plumber sees it: its [kind] (bath, wc, kitchen, util, hall, room; "" until known), the door the pipes come
 * in by ([door], null: its first), the riser room's door they leave by ([pdoor]), the pipe between the two doors ([link]);
 * [ufh] underfloor heating at [step] mm; [seen] the room's water and drain site points already taken in; [kits] put in.
 */
@Serializable
data class PlRoom(val roomId: String, val kind: String = "", val door: String? = null, val pdoor: String? = null, val link: Int = LINK_MM,
                  val ufh: Boolean = false, val step: Int = UFH_STEP, val seen: List<String> = emptyList(), val kits: List<String> = emptyList(),
                  val pend: List<PKitPick> = emptyList())

/**
 * A room typed by size without measuring ([L] × [W] × [H]): how many of each fixture it has, its radiators, underfloor
 * heating, and the typical pipe from its door to the riser ([link]).
 */
@Serializable
data class PlFree(val id: String, val name: String = "", val kind: String = "bath", val L: Int = 2500, val W: Int = 2000, val H: Int = 2700,
                  val wc: Int = 1, val basin: Int = 1, val bath: Int = 1, val shower: Int = 0, val sink: Int = 0, val wm: Int = 0, val dw: Int = 0,
                  val wh: Int = 0, val gb: Int = 0, val rad: Int = 0, val ufh: Boolean = false, val link: Int = 3000, val kit: String = "",
                  /** The kit's choices kept: towel rails, the basins hand basins (cold only), the showers cabins. */
                  val tr: Int = 0, val small: Boolean = false, val cabin: Boolean = false,
                  /** Those choices are kept here (a room saved before they were takes its kit's, see withKit). */
                  val kept: Boolean = false)

/**
 * A plumber's order: the fixtures, the loose outlets, the rooms' settings, the riser, the water pipe ([water] ppr, mp
 * metal-plastic, pex), how the water and the heating run ([run], [hrun]: along the walls or in the floor), the rooms
 * without a plan, the spare, and the rules' limits: the toilet's pipe to the riser ([wcMax]) and a 50 drain's ([drainMax]).
 */
@Serializable
data class PlumbOrder(
    val fixes: List<PlFix> = emptyList(),
    val points: List<PlPoint> = emptyList(),
    val rooms: List<PlRoom> = emptyList(),
    val riser: PlRiser? = null,
    val water: String = "ppr",
    val run: String = "wall",
    val hrun: String = "floor",
    val free: List<PlFree> = emptyList(),
    val spare: Int? = null,
    val wcMax: Int = WC_MAX,
    val drainMax: Int = DRAIN_MAX
) {
    fun room(id: String) = rooms.firstOrNull { it.roomId == id } ?: PlRoom(id)
    val empty get() = fixes.isEmpty() && points.isEmpty() && free.isEmpty() && riser == null && rooms.none { it.ufh }
}

const val LINK_MM = 1000
const val PIPE_SPARE = 10
const val WC_MAX = 1000
const val DRAIN_MAX = 3000
/** Water along the walls: cold this high, hot [KIND_DZ] above it; in the floor: this high. */
const val WATER_Z = 250
const val FLOOR_Z = 30
const val KIND_DZ = 60
/** Heating along the walls: just over the floor, behind the skirting. */
const val HEAT_Z = 120
/** A drain's height where it meets the riser (its centre), mm. */
const val DRAIN_IN = 60
/** The drains are laid at this slope (mm a metre) when the outlet is high enough; the rules' least slope. */
const val SLOPE_50 = 30
const val SLOPE_110 = 20
const val MIN_50 = 20
const val MIN_110 = 10
/** The riser's box (meters, filters, valves) on the wall, mm. */
const val RISER_W = 260
const val RISER_D = 260
/** Pipe at the riser for its meter, filter and valve, a kind. */
const val RISER_TAIL = 600
/** PPR sticks, metal-plastic and PEX coils, the underfloor pipe's coil, m. */
const val STICK = 4
const val UFH_COIL = 200
/** Underfloor heating: pipe spacing, the longest loop, mm. */
const val UFH_STEP = 150
const val LOOP_MAX = 80_000
/** Radiators: watts a m² of floor, a section's watts and width. */
const val W_M2 = 100
const val SEC_W = 180
const val SEC_MM = 80

val WATERS = listOf("ppr", "mp", "pex")
val RUNS = listOf("wall", "floor")
val KINDS = listOf("bath", "wc", "kitchen", "util", "hall", "room")
/** Outlet kinds: water, drain, heating supply and return. */
val PT_KINDS = listOf("cold", "hot", "drain", "hs", "hr")

/** A kind's colour in the drawings: cold blue, hot red, drain grey, heating supply orange and return purple; the underfloor loops amber. */
fun kindRgb(t: String) = when (t) { "cold" -> 0x2563EB; "hot" -> 0xDC2626; "drain" -> 0x6B7280; "hs" -> 0xEA580C; "hr" -> 0x7C3AED; else -> 0xF59E0B }
const val UFH_RGB = 0xF59E0B

/**
 * A fixture type: [cat] wet, kitchen, heater or heat; [w] × [d] its footprint (along the wall × into the room), [z0]…[h]
 * its height from the floor; [pts] its usual outlets; [tol] how far an outlet's height may be off before it warns; [hot]
 * it makes hot water; [heat] it heats.
 */
class FixType(val id: String, val cat: String, val w: Int, val d: Int, val h: Int, val z0: Int, val pts: List<FixPt>, val tol: Int = 150,
              val hot: Boolean = false, val heat: Boolean = false)

val FIX_TYPES = listOf(
    FixType("wc", "wet", 380, 650, 780, 0, listOf(FixPt("drain", 0, 100, 110), FixPt("cold", 250, 200)), tol = 100),
    FixType("bs", "wet", 600, 480, 850, 650, listOf(FixPt("hot", -80, 550), FixPt("cold", 80, 550), FixPt("drain", 0, 500, 50))),
    FixType("bsm", "wet", 450, 320, 850, 650, listOf(FixPt("cold", 60, 550), FixPt("drain", 0, 500, 50))),
    FixType("bath", "wet", 1700, 750, 580, 0, listOf(FixPt("hot", -625, 800), FixPt("cold", -475, 800), FixPt("drain", -700, 150, 50))),
    FixType("sh", "wet", 900, 900, 150, 0, listOf(FixPt("hot", -75, 1100), FixPt("cold", 75, 1100), FixPt("drain", 0, 100, 50))),
    FixType("cab", "wet", 900, 900, 2150, 0, listOf(FixPt("hot", -75, 1100), FixPt("cold", 75, 1100), FixPt("drain", 0, 100, 50))),
    FixType("sink", "kitchen", 800, 600, 850, 0, listOf(FixPt("hot", -80, 550), FixPt("cold", 80, 550), FixPt("drain", 0, 500, 50))),
    FixType("wm", "wet", 600, 600, 850, 0, listOf(FixPt("cold", 150, 600), FixPt("drain", -150, 600, 50))),
    FixType("dw", "kitchen", 600, 600, 820, 0, listOf(FixPt("cold", 150, 400), FixPt("drain", -150, 400, 50))),
    FixType("wh", "heater", 450, 450, 2000, 1150, listOf(FixPt("cold", 100, 1050), FixPt("hot", -100, 1050)), hot = true),
    FixType("gb", "heater", 400, 320, 1850, 1150, listOf(FixPt("hs", -140, 1050), FixPt("hot", -50, 1050), FixPt("cold", 50, 1050), FixPt("hr", 140, 1050)), hot = true, heat = true),
    FixType("rad", "heat", 560, 90, 680, 100, listOf(FixPt("hs", -240, 600), FixPt("hr", 240, 150)), tol = 100),
    FixType("tr", "heat", 500, 110, 1700, 900, listOf(FixPt("hot", -200, 1600), FixPt("hot", -200, 1000)), tol = 200),
    FixType("manif", "heat", 500, 120, 900, 300, listOf(FixPt("hs", -150, 400), FixPt("hr", 150, 400)), tol = 200)
)

fun fixType(t: String) = FIX_TYPES.firstOrNull { it.id == t } ?: FIX_TYPES[0]

/** The fixture types by group on the "add" sheet. */
val FIX_CATS = listOf("wet", "kitchen", "heater", "heat")

/** A fixture's width along the wall, mm. */
fun fixW(f: PlFix) = if (f.w > 0) f.w else fixType(f.t).w
fun fixD(f: PlFix) = fixType(f.t).d
/** The bottom of a fixture: a basin on a cabinet stands on the floor. */
fun fixZ0(f: PlFix) = if (f.opt == "cab") 0 else fixType(f.t).z0
fun fixTop(f: PlFix) = fixType(f.t).h

/** A radiator's outlets for its width [w]: the supply at the top of one end, the return at the bottom of the other. */
fun radPts(w: Int) = listOf(FixPt("hs", -w / 2 + 40, 600), FixPt("hr", w / 2 - 40, 150))

/** The usual outlets of a new fixture of type [t], [w] wide. */
fun defaultPts(t: String, w: Int = 0) = if (t == "rad") radPts(if (w > 0) w else fixType(t).w) else fixType(t).pts

/** The usual heights a loose outlet snaps to, mm from the floor. */
val SNAP_H = listOf(60, 100, 150, 200, 250, 400, 500, 550, 600, 800, 1000, 1050, 1100, 1200)

/** The usual height of a new loose outlet of kind [t]. */
fun usualPtH(t: String) = when (t) { "drain" -> 500; "hs" -> 600; "hr" -> 150; else -> 550 }

/** The diameter of a drain outlet [d] (0: 50). */
fun drainD(d: Int) = if (d >= 100) 110 else 50

/** The kind a room of workspace type [wsType] named [name] is, when the plumber has not said. */
fun guessKind(wsType: String?, name: String): String {
    val n = name.lowercase()
    return when {
        "hojat" in n || "туал" in n || "ҳожат" in n || "санузел" in n || "toilet" in n || n == "wc" || "uborn" in n -> "wc"
        "qozon" in n || "котел" in n || "котёл" in n || "котель" in n || "boiler" in n || "kotyol" in n || "utility" in n || "кир" in n || "kir " in n -> "util"
        else -> when (uz.metrx.app.elec.guessKind(wsType, name)) { "kitchen" -> "kitchen"; "bath" -> "bath"; "hall" -> "hall"; else -> "room" }
    }
}
