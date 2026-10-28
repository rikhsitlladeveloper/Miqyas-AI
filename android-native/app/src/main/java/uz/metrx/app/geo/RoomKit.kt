package uz.metrx.app.geo

import uz.metrx.app.data.Diag
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * The room editor v2's pure logic (founder-approved mockup design/room-editor/mockup.html, 28 Oct 2026): what can go on
 * a wall, each kind's styles with their standard sizes, the size steps and their checks, the magnets, the wall-length
 * rule and the Tekshiruv rules. Shared by the openings step of the room flow and the room editor of every trade.
 * Pure Kotlin, unit-tested (RoomKitTest). Lengths are mm.
 */

/* ---------------- walls ---------------- */

/** A wall is at least 300 mm and at most 999 999 mm (6 digits); above 30 000 mm the app asks "Katta devor — to‘g‘rimi?". */
const val WALL_MIN = 300
const val WALL_MAX = 999_999
const val WALL_BIG = 30_000

/** What is wrong with a typed wall length: "re.e.need", "re.e.wallMin" or "re.e.wallMax"; null when it may be saved. */
fun wallLenErr(v: Int?): String? = when {
    v == null -> "re.e.need"
    v < WALL_MIN -> "re.e.wallMin"
    v > WALL_MAX -> "re.e.wallMax"
    else -> null
}

/** A wall long enough for the yellow "Katta devor — to‘g‘rimi?" note (it never blocks). */
fun bigWall(v: Int?) = v != null && v > WALL_BIG

/* ---------------- kinds ---------------- */

/** Doors and windows: openings in the wall. */
val OPEN_KINDS = listOf("door", "window")
/** Water, sewer and gas: the plumber's group. */
val WATER_KINDS = listOf("cold", "hot", "sewer", "gas", "meter", "boiler")
/** Electrics, heating and air: the electrician's group. */
val ELEC_KINDS = listOf("socket", "switch", "rad", "ac", "vent", "panel")
/** Every point kind (not an opening). */
val POINT_KINDS = WATER_KINDS + ELEC_KINDS

fun isOpenKind(k: String) = k in OPEN_KINDS

/** The icon row's groups for a trade: the electrician sees the electric group before water and gas. */
fun kindGroups(trade: String): List<List<String>> =
    if (trade == "elec") listOf(OPEN_KINDS, ELEC_KINDS, WATER_KINDS) else listOf(OPEN_KINDS, WATER_KINDS, ELEC_KINDS)

/** The Tekshiruv groups. */
private val ELEC_NEAR = listOf("socket", "switch", "panel")
private val WATER_NEAR = listOf("cold", "hot", "sewer")
private val GAS_NEAR = listOf("meter", "boiler")

/* ---------------- styles ---------------- */

/**
 * One style of a kind: its [id] (name "st.<kind>.<id>", a note "st.<kind>.<id>.d" when [note]), the standard sizes
 * [std] by field, its own width chips [cw]; [ceil]: the height goes up to the ceiling (a panoramic window).
 */
data class Style(val id: String, val std: Map<String, Int>, val cw: List<Int>? = null, val ceil: Boolean = false, val note: Boolean = false)

private fun s(id: String, vararg v: Pair<String, Int>, cw: List<Int>? = null, ceil: Boolean = false, note: Boolean = false) = Style(id, mapOf(*v), cw, ceil, note)

/** Every kind's styles, in the style window's order (the mockup's STY; the founder accepted every standard). */
val STYLES: Map<String, List<Style>> = mapOf(
    "door" to listOf(
        s("single", "w" to 800, "h" to 2100),
        s("double", "w" to 1200, "h" to 2100, cw = listOf(1000, 1200, 1400)),
        s("slide", "w" to 900, "h" to 2100, cw = listOf(800, 900, 1000)),
        s("arch", "w" to 900, "h" to 2100, cw = listOf(800, 900, 1200)),
        s("glass", "w" to 800, "h" to 2100),
        s("balcony", "dw" to 700, "h" to 2100, "ww" to 1200, "wh" to 1400),
        s("fold", "w" to 900, "h" to 2100, cw = listOf(800, 900, 1200))),
    "window" to listOf(
        s("single", "w" to 700, "h" to 1400, "sill" to 900, cw = listOf(600, 700, 800)),
        s("double", "w" to 1500, "h" to 1500, "sill" to 900),
        s("triple", "w" to 2100, "h" to 1500, "sill" to 900, cw = listOf(1800, 2100, 2400)),
        s("fort", "w" to 1200, "h" to 1400, "sill" to 900),
        s("pano", "w" to 1800, "h" to 2700, cw = listOf(1500, 1800, 2400), ceil = true),
        s("balcony", "ww" to 1200, "wh" to 1400, "dw" to 700, "h" to 2100)),
    "socket" to listOf(s("one", "ph" to 300), s("two", "ph" to 300), s("three", "ph" to 1100, note = true), s("usb", "ph" to 1100), s("power", "ph" to 600)),
    "switch" to listOf(s("k1", "ph" to 900), s("k2", "ph" to 900), s("k3", "ph" to 900), s("pass", "ph" to 900, note = true)),
    "rad" to listOf(s("alu", "pw" to 640, "ph" to 600, note = true), s("steel", "pw" to 1000, "ph" to 600), s("cast", "pw" to 650, "ph" to 600, note = true),
        s("towel", "pw" to 500, "ph" to 1200, note = true)),
    "cold" to listOf(s("tap", "ph" to 500, note = true), s("mix", "ph" to 800, note = true), s("wm", "ph" to 600)),
    "hot" to listOf(s("tap", "ph" to 500, note = true), s("mix", "ph" to 800, note = true), s("wm", "ph" to 600, note = true)),
    "sewer" to listOf(s("d50", "ph" to 400, note = true), s("d110", "ph" to 100)),
    "gas" to listOf(s("g15", "ph" to 1800, note = true), s("g20", "ph" to 1800, note = true), s("g25", "ph" to 2200, note = true)),
    "meter" to listOf(s("g16", "ph" to 1600, note = true), s("g4", "ph" to 1600, note = true), s("smart", "ph" to 1600)),
    "boiler" to listOf(s("open", "ph" to 1500), s("turbo", "ph" to 1500), s("dual", "ph" to 1400, note = true)),
    "ac" to listOf(s("b7", "pw" to 700, "ph" to 2200, note = true), s("b9", "pw" to 800, "ph" to 2200, note = true), s("b12", "pw" to 850, "ph" to 2200, note = true),
        s("b18", "pw" to 1000, "ph" to 2200, note = true)),
    "vent" to listOf(s("r100", "ph" to 2300), s("r125", "ph" to 2300, note = true), s("sq", "ph" to 2300), s("fan", "ph" to 2300, note = true)),
    "panel" to listOf(s("m6", "ph" to 1700, note = true), s("m12", "ph" to 1700), s("m24", "ph" to 1700), s("m36", "ph" to 1700, note = true))
)

/** A kind's style [id] (its first style when the id is unknown or empty). */
fun styleOf(kind: String, id: String?): Style {
    val l = STYLES[kind] ?: return Style(id ?: "", emptyMap())
    return l.firstOrNull { it.id == id } ?: l.first()
}

/** An opening's style id ("" older openings: a single door, a double window). */
fun styleId(o: Opening): String = o.style.ifEmpty { if (o.type == "door") "single" else "double" }

/** A point's style id. */
fun styleId(p: SitePoint): String = p.style.ifEmpty { STYLES[p.t]?.first()?.id ?: "" }

/** A style's standard sizes in a room [rh] mm high (a panoramic window goes up to the ceiling). */
fun stdVals(kind: String, st: Style, rh: Int): Map<String, Int> = if (st.ceil) st.std + ("h" to rh) else st.std

/** The point kinds' usual heights (to the centre, mm): the chips of the Balandligi step and the slide's snaps. */
val POINT_HS: Map<String, List<Int>> = mapOf(
    "cold" to listOf(500, 600, 800), "hot" to listOf(500, 600, 800), "sewer" to listOf(400, 100, 500), "gas" to listOf(1800, 2000, 2200),
    "meter" to listOf(1600, 1400, 1800), "boiler" to listOf(1500, 1400, 1600), "socket" to listOf(300, 1100, 1800), "switch" to listOf(900, 1000, 1200),
    "rad" to listOf(600, 400), "ac" to listOf(2200, 2400, 2500), "vent" to listOf(2300, 2100, 2500), "panel" to listOf(1700, 1500, 1800)
)

val DOOR_W = listOf(700, 800, 900)
val WIN_W = listOf(1200, 1500, 1800)
val SILLS = listOf(800, 900)
val DOOR_H = listOf(2000, 2100, 2200)
val WIN_H = listOf(1200, 1400, 1500)
val THRESHOLDS = listOf(0, 20, 40)
/** Wall thicknesses (Qalinlik) and room heights (Balandlik) offered as chips. */
val THICKS = listOf(100, 120, 200, 250, 380, 510)
val ROOM_HS = listOf(2500, 2600, 2700, 2800, 3000, 3200)
/** The usual wall thickness, mm (drawn outward on the plan). */
const val THICK_STD = 200

/* ---------------- size steps ---------------- */

/** The sizes asked one per step after the style: door Eni → Bo‘yi; window + Tokcha; balcony door/window parts; points Balandligi. */
fun pkSteps(kind: String, style: String): List<String> = when (kind) {
    "door" -> if (style == "balcony") listOf("dw", "h", "ww", "wh") else listOf("w", "h")
    "window" -> when (style) { "balcony" -> listOf("ww", "wh", "dw", "h"); "pano" -> listOf("w", "h"); else -> listOf("w", "h", "sill") }
    "rad", "ac" -> listOf("pw", "ph")
    else -> listOf("ph")
}

/** A step's quick chips with the style's standard among them ([std], shown "st."). */
data class StepChips(val chips: List<Int>, val std: Int?)

fun stepChips(field: String, kind: String, style: String, rh: Int): StepChips {
    val st = styleOf(kind, style)
    val base: List<Int> = when (field) {
        "w" -> st.cw ?: if (kind == "door") DOOR_W else WIN_W
        "h" -> when { style == "balcony" || kind == "door" -> DOOR_H; style == "pano" -> listOf(2400, 2500, rh); else -> WIN_H }
        "sill" -> SILLS
        "dw" -> listOf(600, 700, 800)
        "ww" -> listOf(900, 1200, 1500)
        "wh" -> listOf(1200, 1400, 1500)
        "pw" -> if (kind == "rad") listOf(500, 640, 800, 1000, 1200) else listOf(700, 800, 850, 1000)
        else -> POINT_HS[kind] ?: listOf(500)
    }
    val sv = stdVals(kind, st, rh)[field]
    return StepChips((base + listOfNotNull(sv)).distinct().sorted(), sv)
}

/** A size step's problem: [key] a strings key, [args] its numbers. */
data class ReErr(val key: String, val args: Map<String, Int> = emptyMap())

/**
 * What is wrong with field [f] of a [kind] [style] item sized [v] on a wall [L] mm long in a room [rh] mm high (the
 * mockup's pkFieldErr): red with the reason, "Keyingi" off. Null when it may go on.
 */
fun fieldErr(kind: String, style: String, v: Map<String, Int>, f: String, L: Int, rh: Int): ReErr? {
    val x = v[f] ?: return ReErr("re.e.need")
    val steps = pkSteps(kind, style)
    fun later(a: String, b: String) = steps.indexOf(a) > steps.indexOf(b)
    return when (f) {
        "w", "pw" -> { val mn = if (f == "pw") 200 else 300
            when { x < mn -> ReErr("re.e.min", mapOf("m" to mn)); x > L -> ReErr("re.e.wide", mapOf("l" to L, "x" to x)); else -> null } }
        "dw", "ww" -> { val tw = (v["dw"] ?: 0) + (v["ww"] ?: 0)
            when { x < 300 -> ReErr("re.e.min", mapOf("m" to 300)); tw > L -> ReErr("re.e.balFit", mapOf("t" to tw, "l" to L)); else -> null } }
        "h" -> when {
            x < 300 -> ReErr("re.e.min", mapOf("m" to 300))
            x > rh -> ReErr("re.e.ceil", mapOf("x" to x, "r" to rh))
            style == "balcony" && later("h", "wh") && x < (v["wh"] ?: 0) + 100 -> ReErr("re.e.balDoor", mapOf("m" to (v["wh"] ?: 0) + 100))
            else -> null
        }
        "sill" -> { val h = v["h"] ?: 0; if (x + h > rh) ReErr("re.e.sillCeil", mapOf("s" to x, "h" to h, "t" to x + h, "r" to rh)) else null }
        "wh" -> when {
            x < 300 -> ReErr("re.e.min", mapOf("m" to 300))
            later("wh", "h") && x > (v["h"] ?: 0) - 100 -> ReErr("re.e.balWin", mapOf("m" to (v["h"] ?: 0) - 100))
            else -> null
        }
        "ph" -> if (x > rh) ReErr("re.e.ceil", mapOf("x" to x, "r" to rh)) else null
        else -> null
    }
}

/** The first step with a problem (its index and the problem), for "Standart" / "Qo‘yish"; null when all are fine. */
fun checkAll(kind: String, style: String, v: Map<String, Int>, L: Int, rh: Int): Pair<Int, ReErr>? {
    pkSteps(kind, style).forEachIndexed { i, f -> fieldErr(kind, style, v, f, L, rh)?.let { return i to it } }
    return null
}

/** "Standart": the steps after [step] take the style's standard sizes, the ones up to it stay as typed. */
fun fillStandard(kind: String, style: String, v: Map<String, Int>, step: Int, rh: Int): Map<String, Int> {
    val std = stdVals(kind, styleOf(kind, style), rh)
    val m = v.toMutableMap()
    pkSteps(kind, style).forEachIndexed { i, f -> if (i > step) std[f]?.let { m[f] = it } }
    return m
}

/* ---------------- an item's sizes ---------------- */

private fun r10(v: Double) = (v / 10).roundToInt() * 10

/** An opening's sizes as the steps ask them. */
fun valsOf(o: Opening): Map<String, Int> {
    val st = styleId(o)
    if (st == "balcony") return mapOf("dw" to o.dw, "ww" to (o.w - o.dw), "h" to o.h, "wh" to o.wh)
    val m = mutableMapOf("w" to o.w, "h" to o.h)
    if (o.type == "window" && st != "pano") m["sill"] = o.sill
    return m
}

/** A point's sizes as the steps ask them. */
fun valsOf(p: SitePoint): Map<String, Int> = if (p.t == "rad" || p.t == "ac") mapOf("pw" to (if (p.pw > 0) p.pw else styleOf(p.t, p.style).std["pw"] ?: 600), "ph" to p.h) else mapOf("ph" to p.h)

/**
 * [base] with the style [style] and the sizes [v], kept centred on [center] (mm along the wall from its start) and on
 * the wall [L] mm long (the mockup's applyVals).
 */
fun applyVals(base: Opening, style: String, v: Map<String, Int>, L: Int, center: Double): Opening {
    val o = if (style == "balcony") {
        val dw = v["dw"] ?: 700; val ww = v["ww"] ?: 1200
        base.copy(style = style, dw = dw, w = dw + ww, h = v["h"] ?: 2100, wh = v["wh"] ?: 1400, sill = 0)
    } else base.copy(style = style, w = v["w"] ?: base.w, h = v["h"] ?: base.h, dw = 0, wh = 0,
        sill = if (base.type == "window" && style != "pano") v["sill"] ?: base.sill else 0)
    return o.copy(off = r10(center - o.w / 2.0).coerceIn(0, max(0, L - o.w)))
}

fun applyVals(base: SitePoint, style: String, v: Map<String, Int>): SitePoint =
    base.copy(style = style, h = v["ph"] ?: base.h, pw = if (base.t == "rad" || base.t == "ac") v["pw"] ?: base.pw else 0)

/** The height the opening starts at: a window's sill (a balcony block starts on the floor). */
fun z0Of(o: Opening): Int = if (o.type == "window" && styleId(o) != "balcony") o.sill else 0

/** Its top, mm from the floor. */
fun topOf(o: Opening): Int = if (styleId(o) == "balcony") o.h else z0Of(o) + o.h

/** The distances to both corners: an opening from its edges, a point from its centre. */
data class Dists(val left: Int, val right: Int)

fun distsOf(o: Opening, L: Int) = Dists(o.off, L - o.w - o.off)
fun distsOf(p: SitePoint, L: Int) = Dists(p.off, L - p.off)

/* ---------------- placing and sliding ---------------- */

/** A slide's place: [v] the distance, [at] "corner" or "mid" when a magnet took it. */
data class Mag(val v: Int, val at: String?)

/**
 * The magnets (Tasdiqlash: at the corners and the middle, 12 px on the screen; otherwise 10 mm steps): an item [w] mm
 * wide (0 a point) slid to [raw] mm along a wall [L] mm long; [thMm] is 12 px in mm at the current zoom (at most 250).
 */
fun magnet(w: Int, L: Int, raw: Double, thMm: Double): Mag {
    val hi = max(0, L - w)
    val th = min(250.0, thMm)
    var best: Pair<Double, Mag>? = null
    for ((x, at) in listOf(0.0 to "corner", hi.toDouble() to "corner", hi / 2.0 to "mid")) {
        val d = abs(raw - x)
        if (d < th && (best == null || d < best.first)) best = d to Mag(x.roundToInt(), at)
    }
    return best?.second ?: Mag(r10(raw).coerceIn(0, hi), null)
}

/** Whether two openings on the same wall overlap. */
fun overlaps(a: Opening, b: Opening) = a.id != b.id && a.wall == b.wall && a.off < b.off + b.w && b.off < a.off + a.w

/**
 * The nearest free place for [o] on its wall [L] mm long among [others] (Yana shu / a copy put next to another): in
 * 50 mm steps either way from where it is; null when there is none.
 */
fun freeSpot(o: Opening, others: List<Opening>, L: Int): Int? {
    var s = 0
    while (s <= L) {
        for (d in listOf(o.off + s, o.off - s)) {
            if (d < 0 || d + o.w > L) continue
            val t = o.copy(off = d)
            if (others.none { overlaps(t, it) }) return d
        }
        s += 50
    }
    return null
}

/* ---------------- Tekshiruv ---------------- */

/** One problem on the room: on item [id] (an opening or a point), [key] its words, [args] the kinds and numbers. */
data class ReIssue(val id: String, val key: String, val args: Map<String, Any> = emptyMap())

/**
 * The room's problems (the mockup's issues()): an item out of its wall, above the ceiling, openings over each other,
 * a point on an opening, a socket, switch or panel closer than 600 mm to water on the same wall, a gas meter or boiler
 * closer than 500 mm to electrics. [lens]: each wall's length by id; [rh] the room's height.
 */
fun roomIssues(lens: Map<String, Int>, rh: Int, ops: List<Opening>, pts: List<SitePoint>, wh: Map<String, Int> = emptyMap()): List<ReIssue> {
    val out = ArrayList<ReIssue>()
    // an inner face ([wh]) has its own height: a half wall's is lower than the ceiling ("devordan baland")
    for (o in ops) {
        val L = lens[o.wall] ?: continue
        if (o.off < 0 || o.off + o.w > L) out += ReIssue(o.id, "re.i.out", mapOf("k" to o.type, "w" to o.wall))
        val top = topOf(o); val h = wh[o.wall]
        if (h != null) { if (top > h) out += ReIssue(o.id, "iw.i.ceil", mapOf("k" to o.type, "t" to top, "r" to h)) }
        else if (top > rh) out += ReIssue(o.id, "re.i.ceil", mapOf("k" to o.type, "t" to top, "r" to rh))
    }
    for (p in pts) {
        val L = lens[p.wall] ?: continue
        if (p.off < 0 || p.off > L) out += ReIssue(p.id, "re.i.out", mapOf("k" to p.t, "w" to p.wall))
        val h = wh[p.wall]
        if (h != null) { if (p.h > h) out += ReIssue(p.id, "iw.i.ceilP", mapOf("k" to p.t)) }
        else if (p.h > rh) out += ReIssue(p.id, "re.i.ceilP", mapOf("k" to p.t))
    }
    for (i in ops.indices) for (j in i + 1 until ops.size) {
        val a = ops[i]; val b = ops[j]
        if (overlaps(a, b)) out += ReIssue(b.id, "re.i.over", mapOf("a" to a.type, "b" to b.type, "w" to a.wall))
    }
    for (p in pts) for (o in ops) if (o.wall == p.wall && p.off > o.off && p.off < o.off + o.w && p.h > z0Of(o) && p.h < topOf(o))
        out += ReIssue(p.id, "re.i.onOp", mapOf("k" to p.t, "o" to o.type))
    for (e in pts) {
        if (e.t !in ELEC_NEAR) continue
        var bw: Pair<Int, SitePoint>? = null; var bg: Pair<Int, SitePoint>? = null
        for (q in pts) {
            if (q.wall != e.wall || q.id == e.id) continue
            val d = abs(e.off - q.off)
            if (q.t in WATER_NEAR && (bw == null || d < bw.first)) bw = d to q
            if (q.t in GAS_NEAR && (bg == null || d < bg.first)) bg = d to q
        }
        if (bw != null && bw.first < 600) out += ReIssue(e.id, "re.i.water", mapOf("k" to e.t, "d" to bw.first))
        if (bg != null && bg.first < 500) out += ReIssue(bg.second.id, "re.i.gas", mapOf("k" to bg.second.t, "d" to bg.first))
    }
    return out
}

/* ---------------- mirroring a room (Burish → Ko‘zgu) ---------------- */

/**
 * The room mirrored on the screen's left–right (its plan turned [Room.rot] quarter turns: an odd turn mirrors the plan's
 * up–down). The walls stay clockwise and keep their letters' order from the first corner; doors, windows, points,
 * columns, niches and thicknesses move with their walls and are measured from the other end.
 */
fun mirrorRoom(r: Room, snap: Boolean = true): Room {
    val ws = walls(r, snap)
    val lens = ws.associate { it.id to (it.len ?: Math.round(kotlin.math.hypot(it.p1.x - it.p0.x, it.p1.y - it.p0.y)).toInt()) }
    val map: Map<String, String>
    var out = r
    if (!r.isPoly) {
        // x: A and C stay, B ↔ D; y: B and D stay, A ↔ C
        map = if (r.rot % 2 == 0) mapOf("A" to "A", "B" to "D", "C" to "C", "D" to "B") else mapOf("A" to "C", "B" to "B", "C" to "A", "D" to "D")
    } else {
        val poly = r.poly!!
        val V = poly.verts
        val n = V.size
        val ids = polyWallIds(n)
        val flipX = r.rot % 2 == 0
        val mx = V.maxOf { it.x }; val my = V.maxOf { it.y }
        val M = { p: Pt -> if (flipX) Pt(mx - p.x, p.y) else Pt(p.x, my - p.y) }
        val nv = List(n) { j -> M(V[(n - j) % n]) }
        map = (0 until n).associate { j -> ids[(n - 1 - j) % n] to ids[j] }
        val dims = HashMap<String, Dim>()
        r.dims.forEach { (k, d) -> dims[map[k] ?: k] = d }
        val diags = poly.diags.map { d -> val a = (n - d.a) % n; val b = (n - d.b) % n; Diag(d.id, min(a, b), max(a, b)) }
        out = out.copy(dims = dims, poly = poly.copy(verts = nv, diags = diags))
    }
    fun wl(w: String) = map[w] ?: w
    // the inner walls: the outline's mirror maps the old plan onto the new one (box to box)
    val (pieces, iops, ipts) = if (r.inner.isEmpty()) Triple(r.inner, r.openings, r.points) else {
        val o0 = ws.map { it.p0 }; val o1 = walls(out.copy(inner = emptyList()), snap).map { it.p0 }
        val flipX = r.rot % 2 == 0
        val x0 = o0.minOf { it.x }; val x1 = o0.maxOf { it.x }; val y0 = o0.minOf { it.y }; val y1 = o0.maxOf { it.y }
        val nx0 = o1.minOf { it.x }; val ny0 = o1.minOf { it.y }
        mirrorInner(r, { p -> if (flipX) V2(nx0 + (x1 - p.x), ny0 + (p.y - y0)) else V2(nx0 + (p.x - x0), ny0 + (y1 - p.y)) },
            { v -> if (flipX) V2(-v.x, v.y) else V2(v.x, -v.y) })
    }
    val faceOps = iops.filter { it.fk.isNotEmpty() }.associateBy { it.id }; val facePts = ipts.filter { it.fk.isNotEmpty() }.associateBy { it.id }
    return syncFaces(out.copy(
        openings = r.openings.map { o -> faceOps[o.id] ?: run { val L = lens[o.wall] ?: return@map o; o.copy(wall = wl(o.wall), off = (L - o.off - o.w).coerceAtLeast(0), sw = mirrorSwing(o.sw)) } },
        points = r.points.map { p -> facePts[p.id] ?: run { val L = lens[p.wall] ?: return@map p; p.copy(wall = wl(p.wall), off = (L - p.off).coerceAtLeast(0)) } },
        features = r.features.map { f -> val L = lens[f.wall] ?: return@map f; f.copy(wall = wl(f.wall), off = (L - f.off - f.w).coerceAtLeast(0)) },
        thick = r.thick.mapKeys { wl(it.key) },
        inner = pieces
    ), snap)
}

/** A hinge side seen in a mirror: left ↔ right. */
fun mirrorSwing(sw: String): String = when {
    sw.endsWith("L") -> sw.dropLast(1) + "R"
    sw.endsWith("R") -> sw.dropLast(1) + "L"
    else -> sw
}

/** A wall's thickness: its own, else the room's T, else 200 mm. */
fun thickOf(r: Room, wall: String): Int = r.thick[wall] ?: r.dim("T").v ?: THICK_STD
