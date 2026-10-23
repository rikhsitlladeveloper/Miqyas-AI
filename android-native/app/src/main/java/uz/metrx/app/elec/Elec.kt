package uz.metrx.app.elec

import kotlinx.serialization.Serializable

/*
 * The electrician's app (Elektrik, 22 Oct 2026, built like the tiler's and the furniture maker's): devices (sockets,
 * switches, lights, low-voltage points, junction boxes) placed on a measured room's walls and ceiling from room kits,
 * the panel (shchit) on a wall, the circuits worked out from them, the cable routes from the panel along the walls
 * through the doorways, safety warnings, and in the advanced app the cable, breakers, boxes and labour. Rooms that are
 * not measured can be typed by size with point counts. Lengths are mm. Pure Kotlin, unit-tested (ElecTest):
 * placing in Place.kt, circuits and routes in Circuits.kt, warnings in Warn.kt, counting in Count.kt, 3D in Mesh.kt.
 */

/**
 * One device. On a wall: [wall], [off] from the wall's start corner to its centre and [h] from the floor to its centre;
 * on the ceiling ([wall] null): at plan point [cx], [cy]. [t] one of [DEV_TYPES]; [len] an LED strip's length; [w] its
 * power in watts when set by hand (0: the usual); [own] on its own line (a breaker of its own); [kit] the room kit that
 * placed it; [from] the room's site point it was taken from.
 */
@Serializable
data class ElecDev(
    val id: String,
    val t: String,
    val roomId: String,
    val wall: String? = null,
    val off: Int = 0,
    val h: Int = 0,
    val cx: Int = 0,
    val cy: Int = 0,
    val len: Int = 0,
    val w: Int = 0,
    val own: Boolean = false,
    val kit: String = "",
    val from: String? = null
) { val onCeiling get() = wall == null }

/** The panel: on [wall] of room [roomId], centred [off] along it and [h] up. [entry]: the flat's entrance door, if it is in this room. */
@Serializable
data class ElecPanel(val roomId: String, val wall: String, val off: Int, val h: Int = PANEL_H, val entry: String? = null)

/**
 * A room as the electrician sees it: its [kind] (kitchen, bath, bed, living, hall, office, other; "" until known),
 * the door the cables come in through ([door], null: its first door), the panel room's door they leave by ([pdoor],
 * null: that room's last door) and the cable between the two doors ([link], mm). [seen]: the room's sockets and
 * switches already taken in as devices; [kits] the kits put in it.
 */
@Serializable
data class ElecRoom(val roomId: String, val kind: String = "", val door: String? = null, val pdoor: String? = null, val link: Int = LINK_MM,
                    val seen: List<String> = emptyList(), val kits: List<String> = emptyList(), val pend: List<KitPick> = emptyList())

/** A kit chosen for a room not measured yet: put in once the room is measured. */
@Serializable
data class KitPick(val kit: String, val light: String = "", val led: Boolean = true, val ac: Boolean = true, val low: Boolean = true)

/**
 * A room typed by its size without measuring ([L] × [W] × [H]): how many sockets, switches, lights, low-voltage points
 * and power lines (stove, AC…) it has, and the cable between its door and the panel ([link]).
 */
@Serializable
data class ElecFree(val id: String, val name: String = "", val kind: String = "other", val L: Int = 4000, val W: Int = 3000, val H: Int = 2700,
                    val sock: Int = 4, val sw: Int = 1, val light: Int = 1, val low: Int = 0, val power: Int = 0, val link: Int = 4000, val kit: String = "",
                    /** The power points' types in order (pst stove, pov oven, pac AC, pwh water heater); past the list, or in an older order, AC. */
                    val powers: List<String> = emptyList())

/** An electrician's order: the devices, the rooms' settings, the panel, how the cables run (chase, gofra, channel), the rooms without a plan. */
@Serializable
data class ElecOrder(
    val devs: List<ElecDev> = emptyList(),
    val rooms: List<ElecRoom> = emptyList(),
    val panel: ElecPanel? = null,
    val method: String = "chase",
    val free: List<ElecFree> = emptyList(),
    /** The cable's spare, % (null: [CABLE_SPARE]). */
    val spare: Int? = null
) {
    fun room(id: String) = rooms.firstOrNull { it.roomId == id } ?: ElecRoom(id)
    val empty get() = devs.isEmpty() && free.isEmpty() && panel == null
}

const val PANEL_H = 1600
const val LINK_MM = 1000
const val CABLE_SPARE = 10
/** The horizontal run of chased or channel cable: this far under the ceiling. */
const val ZONE_DOWN = 150
/** Cable left at each end to connect, mm. */
const val TAIL = 200
const val COIL = 100

val METHODS = listOf("chase", "gofra", "channel")
val KINDS = listOf("kitchen", "bath", "bed", "living", "hall", "office", "other")

/**
 * A device type: [cat] sock, sw, light, low or box; [ceil] on the ceiling; [h] its usual height (negative: that far
 * under the ceiling); [dw] × [dh] its size on the wall (ceiling: [dw] across); [watts] its usual power; [group] the
 * circuit it goes on ("sock": the room's sockets, which a kitchen or bathroom makes its own group).
 */
class DevType(val id: String, val cat: String, val ceil: Boolean, val h: Int, val dw: Int, val dh: Int, val watts: Int, val group: String)

val DEV_TYPES = listOf(
    DevType("s1", "sock", false, 300, 86, 86, 300, "sock"),
    DevType("s2", "sock", false, 300, 156, 86, 500, "sock"),
    DevType("sw", "sock", false, 1100, 90, 90, 300, "sock"),
    DevType("su", "sock", false, 300, 86, 86, 100, "sock"),
    DevType("pst", "sock", false, 600, 100, 100, 7000, "stove"),
    DevType("pov", "sock", false, 600, 86, 86, 3500, "oven"),
    DevType("pac", "sock", false, -300, 86, 86, 2500, "ac"),
    DevType("pwh", "sock", false, 1800, 86, 86, 2000, "wh"),
    DevType("k1", "sw", false, 900, 86, 86, 0, "light"),
    DevType("k2", "sw", false, 900, 86, 86, 0, "light"),
    DevType("kp", "sw", false, 900, 86, 86, 0, "light"),
    DevType("kd", "sw", false, 900, 86, 86, 0, "light"),
    DevType("lc", "light", true, 0, 380, 0, 100, "light"),
    DevType("ls", "light", true, 0, 90, 0, 10, "light"),
    DevType("lw", "light", false, 1800, 220, 150, 40, "light"),
    DevType("led", "light", false, -60, 0, 14, 0, "light"),
    DevType("lch", "light", true, 0, 560, 0, 200, "light"),
    DevType("tv", "low", false, 1100, 86, 86, 0, "low"),
    DevType("lan", "low", false, 300, 86, 86, 0, "low"),
    DevType("int", "low", false, 1500, 120, 200, 0, "low"),
    DevType("cam", "low", false, -300, 100, 100, 0, "low"),
    DevType("bell", "low", false, 1500, 86, 86, 0, "low"),
    DevType("jb", "box", false, -ZONE_DOWN, 100, 100, 0, "")
)

/** The types by group on the "add" sheet. */
val CATS = listOf("sock", "sw", "light", "low", "box")

fun devType(t: String) = DEV_TYPES.firstOrNull { it.id == t } ?: DEV_TYPES[0]

/** A height that may count from the ceiling (negative) in mm from the floor, for a room [H] high. */
fun absH(h: Int, H: Int) = if (h < 0) H + h else h

/** The usual height of a new device of type [t] in a room [H] high; a kitchen's ordinary sockets go over the worktop. */
fun usualH(t: String, H: Int, kind: String = "") = when {
    kind == "kitchen" && (t == "s1" || t == "s2") -> 1100
    kind == "bath" && t == "sw" -> 1100
    else -> absH(devType(t).h, H)
}

/** A device's power, W: as typed, or the usual (an LED strip by its length, 12 W a metre). */
fun watts(d: ElecDev) = if (d.w > 0) d.w else if (d.t == "led") (d.len * 12 + 999) / 1000 else devType(d.t).watts

/** A device's size on the wall, mm (an LED strip: its length × 14). */
fun devSize(d: ElecDev): Pair<Int, Int> = devType(d.t).let { if (d.t == "led") d.len.coerceAtLeast(100) to it.dh else it.dw to it.dh }

/** The snapping heights (mm from the floor) for a room [H] high. */
fun snapHeights(H: Int) = listOf(300, 600, 900, 1100, 1500, 1800, H - 300, H - ZONE_DOWN, H - 60).filter { it in 100 until H }.distinct()

/* ---------------- circuits' groups ---------------- */

/**
 * A circuit group: [amps] its breaker, [cable] its cable ("1.5", "2.5", "6" mm² VVG, "utp" low-voltage), [rcd] behind
 * an RCD (UZO), [maxPts] most points before it is too many, [rgb] its colour in the drawings.
 */
class GroupDef(val id: String, val amps: Int, val cable: String, val rcd: Boolean, val maxPts: Int, val rgb: Int)

val GROUPS = listOf(
    GroupDef("light", 10, "1.5", false, 20, 0xF59E0B),
    GroupDef("sock", 16, "2.5", false, 10, 0x2563EB),
    GroupDef("kitch", 16, "2.5", true, 8, 0x16A34A),
    GroupDef("bath", 16, "2.5", true, 6, 0x7C3AED),
    GroupDef("stove", 32, "6", false, 1, 0xDC2626),
    GroupDef("oven", 16, "2.5", false, 1, 0xEA580C),
    GroupDef("ac", 16, "2.5", false, 1, 0x0891B2),
    GroupDef("wh", 16, "2.5", true, 1, 0xDB2777),
    GroupDef("own", 16, "2.5", false, 1, 0x475569),
    GroupDef("low", 0, "utp", false, 1000, 0x0F766E)
)

fun groupDef(id: String) = GROUPS.firstOrNull { it.id == id } ?: GROUPS[1]

/** The group device [d] in a room of [kind] goes on; null for a junction box. */
fun groupOf(d: ElecDev, kind: String): String? {
    val ty = devType(d.t)
    if (ty.cat == "box") return null
    if (ty.cat == "low") return "low"
    if (d.own && ty.cat == "sock") return "own"
    if (ty.group != "sock") return ty.group
    return when (kind) { "kitchen" -> "kitch"; "bath" -> "bath"; else -> "sock" }
}

/** The kind a room of workspace type [wsType] named [name] is, when the electrician has not said. */
fun guessKind(wsType: String?, name: String): String {
    val n = name.lowercase()
    return when {
        wsType == "kitchen" || "oshxona" in n || "кух" in n || "ошхона" in n || "kitchen" in n -> "kitchen"
        wsType == "bath" || "hammom" in n || "ванн" in n || "ҳаммом" in n || "bath" in n || "hojat" in n || "туал" in n -> "bath"
        "koridor" in n || "корид" in n || "dahliz" in n || "прихож" in n || "hall" in n || "kirish" in n -> "hall"
        "yotoq" in n || "спал" in n || "ётоқ" in n || "bed" in n || "bolalar" in n || "дет" in n -> "bed"
        "mehmon" in n || "гост" in n || "меҳмон" in n || "living" in n || "zal" in n || "зал" in n -> "living"
        "ishxona" in n || "кабин" in n || "office" in n || "ишхона" in n -> "office"
        else -> "other"
    }
}
