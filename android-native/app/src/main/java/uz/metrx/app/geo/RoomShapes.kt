package uz.metrx.app.geo

import uz.metrx.app.data.Pt
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/*
 * Room shapes (design/room-shapes/BUILD_SPEC.md §2 and "Geometry"): the 8 picture cards of the "Xona shakli" screen,
 * which sizes each one asks, and the plan they make. A port of the approved mockup's SH, params(), geom(), simple(),
 * tf(), area() and stepErr() (design/room-shapes/mockup.html, "shapes"), tested against shape-cases.json, which the
 * mockup itself generated (gen_cases.js), so both apps draw the same rooms.
 *
 * Pure Kotlin, no Android. Lengths are mm. Plan y points down, so the shapes run clockwise on screen.
 * Wall i runs from corner i to corner i + 1. Errors are codes plus values ([ShapeError]); the UI turns them into text.
 * A finished shape becomes a real [uz.metrx.app.data.Room] with [shapeToRoom] (ShapeRoom.kt).
 */

/* ---------------- the shapes ---------------- */

/** How a shape is built: walls at right angles (walked from wall A), the cut corner, the bay, or a free sketch. */
enum class ShapeKind { ORTHO, CUT, BAY, FREE }

/**
 * The 8 shapes, in the cards' order ([id] as in the mockup). [dirs]: for right-angle shapes the walk from wall A
 * (R right, D down, L left, U up); every wall but the last two is asked. [defaults]: each asked size's starting value.
 */
enum class RoomShape(val id: String, val kind: ShapeKind, val dirs: String, val defaults: List<Int>) {
    RECT("rect", ShapeKind.ORTHO, "RDLU", listOf(3400, 2600)),
    L("L", ShapeKind.ORTHO, "RDRDLU", listOf(1800, 1800, 2400, 1800)),
    U("U", ShapeKind.ORTHO, "RDRURDLU", listOf(1400, 1800, 1600, 1800, 1400, 3600)),
    CUT("cut", ShapeKind.CUT, "", listOf(3600, 2200, 2800, 3000)),
    T("T", ShapeKind.ORTHO, "RDLDLULU", listOf(4800, 1400, 1600, 2200, 1600, 2200)),
    Z("Z", ShapeKind.ORTHO, "RDRDLULU", listOf(2600, 1600, 1800, 2400, 2600, 1400)),
    BAY("bay", ShapeKind.BAY, "", listOf(4200, 3600, 1000, 2400, 800)),
    FREE("free", ShapeKind.FREE, "", emptyList());

    /** How many sizes the card says it asks (mockup askCount); 0 for the free sketch, which asks every drawn wall. */
    val askCount: Int get() = when (kind) { ShapeKind.ORTHO -> dirs.length - 2; ShapeKind.CUT -> 4; ShapeKind.BAY -> 5; ShapeKind.FREE -> 0 }

    /** How many walls the shape has; null for the free sketch (as many as drawn). */
    val wallCount: Int? get() = when (kind) { ShapeKind.ORTHO -> dirs.length; ShapeKind.CUT -> 5; ShapeKind.BAY -> 8; ShapeKind.FREE -> null }

    companion object {
        /** The shape with this mockup id ("rect", "L", "U", "cut", "T", "Z", "bay", "free"), or null. */
        fun of(id: String): RoomShape? = entries.firstOrNull { it.id == id }
    }
}

/** The mockup's wall letters: wall i is "ABCDEFGHIJ…"[i] (the bay's walls run A–H). See ShapeRoom.wallIds for the editor's. */
fun shapeWallLetter(i: Int): String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[i].toString()

/** A free sketch for the walls step: each drawn wall's direction (a unit vector, plan y down) and its drawn length (the field's hint), mm. */
data class FreeSketch(val dirs: List<Pt>, val hints: List<Int>) {
    init { require(dirs.size == hints.size) { "one hint per wall" } }
}

/**
 * The sketch the walls step asks about, from the corners the builder's sketch screen made (Sketch.kt sketchToMm: mm,
 * clockwise): one direction and one hint (rounded to 10 mm) per wall; walls shorter than 1 mm are skipped (mockup skToMm).
 */
fun freeSketch(corners: List<Pt>): FreeSketch {
    val dirs = ArrayList<Pt>(); val hints = ArrayList<Int>()
    for (i in corners.indices) {
        val a = corners[i]; val b = corners[(i + 1) % corners.size]
        val dx = b.x - a.x; val dy = b.y - a.y; val l = hypot(dx, dy)
        if (l < 1) continue
        dirs += Pt(dx / l, dy / l); hints += (l / 10).roundToInt() * 10
    }
    return FreeSketch(dirs, hints)
}

/**
 * The chosen card with its "Ko‘zgu" (mirror: flips x) and "Burish" (each turn maps (x, y) → (−y, x)), and the free
 * sketch. A free card without its sketch (or with fewer than 3 walls) asks nothing and makes no room
 * ([ShapeErrorCode.EMPTY]), so a screen that reads it before the sketch is drawn does not crash.
 */
data class ShapeSpec(val shape: RoomShape, val mirror: Boolean = false, val turns: Int = 0, val sketch: FreeSketch? = null) {
    /** Turns as 0–3. */
    val turn: Int get() = ((turns % 4) + 4) % 4
    /** "Ko‘zgu" tapped. */
    fun mirrored() = copy(mirror = !mirror)
    /** "Burish" tapped: 90° more. */
    fun turned() = copy(turns = (turn + 1) % 4)
}

/* ---------------- the asked sizes (mockup params) ---------------- */

/** What a step asks: a wall's length, or the bay's width or depth. */
enum class AskKind { WALL, BAY_WIDTH, BAY_DEPTH }

/** One step of the walls screen: [wall] is the wall index for [AskKind.WALL] (null for the bay's width and depth); [default] prefills the field. */
data class ShapeAsk(val kind: AskKind, val wall: Int?, val default: Int)

/**
 * The sizes a shape asks, one per step, in order (mockup params). Right angles: walls A… except the last two. Cut
 * corner: A, B, D, E (C is worked out). Bay: G (opposite the bay), H (side), A (corner to the bay), the bay's width and
 * depth. Free: every drawn wall, prefilled with the drawn length.
 */
fun asks(spec: ShapeSpec): List<ShapeAsk> {
    val sh = spec.shape
    return when (sh.kind) {
        ShapeKind.ORTHO -> (0 until sh.dirs.length - 2).map { ShapeAsk(AskKind.WALL, it, sh.defaults[it]) }
        ShapeKind.CUT -> listOf(0, 1, 3, 4).mapIndexed { j, e -> ShapeAsk(AskKind.WALL, e, sh.defaults[j]) }
        ShapeKind.BAY -> listOf(ShapeAsk(AskKind.WALL, 6, sh.defaults[0]), ShapeAsk(AskKind.WALL, 7, sh.defaults[1]), ShapeAsk(AskKind.WALL, 0, sh.defaults[2]),
            ShapeAsk(AskKind.BAY_WIDTH, null, sh.defaults[3]), ShapeAsk(AskKind.BAY_DEPTH, null, sh.defaults[4]))
        ShapeKind.FREE -> spec.sketch?.hints.orEmpty().mapIndexed { i, h -> ShapeAsk(AskKind.WALL, i, h) }
    }
}

/* ---------------- errors ---------------- */

/** What is wrong, as a code; the UI maps it to a string. The values each code carries are listed with it. */
enum class ShapeErrorCode {
    /** A typed value outside its range: [ShapeError.value] (null when empty), [ShapeError.min], [ShapeError.limit] (the most). */
    OUT_OF_RANGE,
    /** Cut corner: wall D must be shorter than wall A; [ShapeError.limit] = A. */
    CUT_D_NOT_SHORTER,
    /** Cut corner: wall B must be shorter than wall E; [ShapeError.limit] = E. */
    CUT_B_NOT_SHORTER,
    /** Cut corner: no cut comes out (D < A and B < E both needed). */
    CUT_NO_CUT,
    /** Bay: A + the bay's width ([ShapeError.value]) must be shorter than wall G ([ShapeError.limit]). */
    BAY_NOT_FIT,
    /** Bay: too deep for its width, the 45° sides meet (the width must be more than twice the depth). */
    BAY_TOO_DEEP,
    /** Free sketch: the walls miss closing by [ShapeError.value] mm, more than max(30 mm, 1 % of the perimeter). */
    NOT_CLOSED,
    /** A worked-out wall comes out zero or negative: wall [ShapeError.wall], [ShapeError.value] its length. */
    WALL_NEGATIVE,
    /** The walls cross each other. */
    WALLS_CROSS,
    /** The diagonal ([ShapeError.value]) does not match the walls: they give [ShapeError.limit] (± 20 mm, the editor's SK_TOL; the founder's change to the mockup's max(30 mm, 2 %)). */
    DIAG_MISMATCH,
    /** An opening's field is empty; or a free shape has no sketch yet. */
    EMPTY,
    /** An opening's distance is past its wall: [ShapeError.wall], [ShapeError.limit] the wall's length. */
    OP_PAST_WALL,
    /** A door or window does not fit its wall: distance + width = [ShapeError.value], the wall [ShapeError.limit]. */
    OP_NOT_FIT,
    /** A window's sill + height ([ShapeError.value]) is above the room's height ([ShapeError.limit]). */
    OP_ABOVE_CEILING
}

/** An error code with its values (see each [ShapeErrorCode]); [wall] is a wall index, lengths are mm. */
data class ShapeError(val code: ShapeErrorCode, val wall: Int? = null, val value: Double? = null, val limit: Double? = null, val min: Double? = null)

/** Walls (and the bay's sizes, the diagonal, door and window widths) are 300–20 000 mm. */
const val SHAPE_WALL_MIN = 300
const val SHAPE_WALL_MAX = 999_999
/** The room's height is 2 000–6 000 mm, 2 700 the first time. */
const val SHAPE_HEIGHT_MIN = 2_000
const val SHAPE_HEIGHT_MAX = 6_000
const val SHAPE_HEIGHT_DEFAULT = 2_700

/* ---------------- the geometry (mockup geom) ---------------- */

/**
 * One wall: index [index] (letter [shapeWallLetter]), from corner [from] to [to] (before mirror and turn). [len] is
 * the asked or worked-out length (the free sketch's typed one). [ask] is the step that asks it, null when it is
 * worked out ("avtomat", drawn dashed). [angle]: the cut wall's angle in whole degrees. [bad]: zero or negative.
 */
data class ShapeWall(val index: Int, val len: Double, val ask: Int?, val from: Pt, val to: Pt, val angle: Int? = null, val bad: Boolean = false) {
    val derived: Boolean get() = ask == null
    val letter: String get() = shapeWallLetter(index)
}

/** A size drawn as a guide line, not a wall (the bay's width and depth): from [a] to [b], asked by step [ask]. */
data class ShapeGuide(val a: Pt, val b: Pt, val ask: Int)

/**
 * A shape worked out from its values. [corners] before mirror and turn (an unclosed free sketch keeps its open end:
 * one corner more than walls); [walls] in order; [error] the first problem, null when the room closes; [values] the
 * asked values with defaults filled in; [gapFixed] the free sketch's closing gap spread over its walls, mm; [gap] its
 * gap when too big to spread (drawn from the open end back to corner 0); [guides] the bay's width and depth lines.
 */
data class ShapeGeo(
    val spec: ShapeSpec,
    val corners: List<Pt>,
    val walls: List<ShapeWall>,
    val error: ShapeError?,
    val values: List<Int>,
    val gapFixed: Double = 0.0,
    val gap: Double? = null,
    val guides: List<ShapeGuide> = emptyList()
) {
    val ok: Boolean get() = error == null
    /** The floor area, mm² (mockup Math.abs(area(pts))). */
    val areaMm2: Double get() = abs(polygonArea(corners))
    /** The corners as drawn, after mirror and turn (mockup tf). */
    val cornersShown: List<Pt> get() = corners.map { shownPoint(it, spec) }
    /** The bounding box's width and height, mm (the summary's "4 200 × 3 600 mm"). */
    val size: Pair<Double, Double> get() = (corners.maxOf { it.x } - corners.minOf { it.x }) to (corners.maxOf { it.y } - corners.minOf { it.y })
}

private val DV = mapOf('R' to Pt(1.0, 0.0), 'D' to Pt(0.0, 1.0), 'L' to Pt(-1.0, 0.0), 'U' to Pt(0.0, -1.0))

/**
 * The plan from the asked [values] (one per [asks] step; a missing or null one takes its default), as the mockup's
 * geom(): the corners, every wall, which are worked out, the cut's angle, the area and the first error.
 */
fun shapeGeometry(spec: ShapeSpec, values: List<Int?>): ShapeGeo {
    val sh = spec.shape
    // a free card with no sketch (or under 3 walls) yet: nothing to draw, nothing to make
    if (sh.kind == ShapeKind.FREE && (spec.sketch?.dirs?.size ?: 0) < 3) return ShapeGeo(spec, listOf(Pt(0.0, 0.0)), emptyList(), ShapeError(ShapeErrorCode.EMPTY), emptyList())
    val P = asks(spec)
    val v = P.mapIndexed { i, p -> values.getOrNull(i) ?: p.default }
    val d = v.map { it.toDouble() }
    val pts = ArrayList<Pt>()
    val E = ArrayList<WallDraft>()
    var err: ShapeError? = null
    var guides = emptyList<ShapeGuide>()
    var gapFixed = 0.0
    var gap: Double? = null
    when (sh.kind) {
        ShapeKind.ORTHO -> {
            val dr = sh.dirs.map { DV.getValue(it) }; val n = dr.size
            var x = 0.0; var y = 0.0; pts += Pt(0.0, 0.0)
            for (i in 0 until n - 2) { x += dr[i].x * d[i]; y += dr[i].y * d[i]; pts += Pt(x, y) }
            val a = dr[n - 2]; val b = dr[n - 1]
            val l1: Double; val l2: Double
            if (a.x != 0.0) { l1 = -x / a.x; l2 = -y / b.y } else { l1 = -y / a.y; l2 = -x / b.x }
            pts += Pt(x + a.x * l1, y + a.y * l1)
            for (i in 0 until n) E += WallDraft(if (i < n - 2) i else null, if (i < n - 2) d[i] else if (i == n - 2) l1 else l2)
        }
        ShapeKind.CUT -> {
            val W = d[0]; val r1 = d[1]; val bb = d[2]; val H = d[3]; val cx = W - bb; val cy = H - r1
            pts += listOf(Pt(0.0, 0.0), Pt(W, 0.0), Pt(W, r1), Pt(bb, H), Pt(0.0, H))
            val bad = cx <= 0 || cy <= 0
            E += listOf(WallDraft(0, W), WallDraft(1, r1), WallDraft(null, hypot(cx, cy), bad, Math.round(atan2(cy, cx) * 180 / PI).toInt()), WallDraft(2, bb), WallDraft(3, H))
            if (bad) err = ShapeError(ShapeErrorCode.CUT_NO_CUT)
        }
        ShapeKind.BAY -> {
            val W2 = d[0]; val D = d[1]; val p = d[2]; val w = d[3]; val dp = d[4]; val fr = w - 2 * dp; val rs = W2 - p - w
            pts += listOf(Pt(0.0, 0.0), Pt(p, 0.0), Pt(p + dp, -dp), Pt(p + w - dp, -dp), Pt(p + w, 0.0), Pt(W2, 0.0), Pt(W2, D), Pt(0.0, D))
            val s2 = sqrt(2.0)
            E += listOf(WallDraft(2, p), WallDraft(null, dp * s2), WallDraft(null, fr, fr <= 0), WallDraft(null, dp * s2), WallDraft(null, rs, rs <= 0),
                WallDraft(null, D), WallDraft(0, W2), WallDraft(1, D))
            guides = listOf(ShapeGuide(Pt(p, 0.0), Pt(p + w, 0.0), 3), ShapeGuide(Pt(p + w / 2, 0.0), Pt(p + w / 2, -dp), 4))
            if (rs <= 0) err = ShapeError(ShapeErrorCode.BAY_NOT_FIT, value = p + w, limit = W2)
            else if (fr <= 0) err = ShapeError(ShapeErrorCode.BAY_TOO_DEEP)
        }
        ShapeKind.FREE -> {
            val dr = spec.sketch!!.dirs; val n2 = dr.size   // 3 or more: checked above
            var x2 = 0.0; var y2 = 0.0; var per = 0.0; pts += Pt(0.0, 0.0)
            for (j in 0 until n2) { x2 += dr[j].x * d[j]; y2 += dr[j].y * d[j]; per += d[j]; pts += Pt(x2, y2) }
            val g = hypot(x2, y2); val tol = max(30.0, per * 0.01)
            if (g <= tol) {
                var cum = 0.0
                for (j in 1..n2) { cum += d[j - 1]; pts[j] = Pt(pts[j].x - x2 * cum / per, pts[j].y - y2 * cum / per) }
                pts.removeAt(pts.size - 1); gapFixed = g
            } else { gap = g; err = ShapeError(ShapeErrorCode.NOT_CLOSED, value = g) }
            for (j in 0 until n2) E += WallDraft(j, d[j])
        }
    }
    val open = gap != null
    E.forEach { if (it.len <= 0.5) it.bad = true }
    if (err == null) {
        val bi = E.indexOfFirst { it.bad }
        if (bi >= 0) err = ShapeError(ShapeErrorCode.WALL_NEGATIVE, wall = bi, value = E[bi].len)
        else if (!isSimplePolygon(pts)) err = ShapeError(ShapeErrorCode.WALLS_CROSS)
    }
    val walls = E.mapIndexed { i, e -> ShapeWall(i, e.len, e.ask, pts[i], if (open) pts[i + 1] else pts[(i + 1) % pts.size], e.angle, e.bad) }
    return ShapeGeo(spec, pts, walls, err, v, gapFixed, gap, guides)
}

private class WallDraft(val ask: Int?, val len: Double, var bad: Boolean = false, val angle: Int? = null)

/** A plan point as drawn after mirror and turn (mockup tf): mirror flips x, then each turn maps (x, y) → (−y, x). */
fun shownPoint(p: Pt, spec: ShapeSpec): Pt {
    var x = p.x; var y = p.y
    if (spec.mirror) x = -x
    repeat(spec.turn) { val t = x; x = -y; y = t }
    return Pt(x, y)
}

/** The signed area, mm² (mockup area: positive when the corners run clockwise on screen, y down). */
fun polygonArea(pts: List<Pt>): Double {
    var a = 0.0
    for (i in pts.indices) { val p = pts[i]; val q = pts[(i + 1) % pts.size]; a += p.x * q.y - q.x * p.y }
    return a / 2
}

/** Whether a closed outline never crosses or touches itself (mockup simple). */
fun isSimplePolygon(p: List<Pt>): Boolean {
    val n = p.size
    for (i in 0 until n) for (j in i + 1 until n) {
        if (j == i + 1 || (i == 0 && j == n - 1)) continue
        if (segsMeet(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n])) return false
    }
    return true
}

private fun turnSign(a: Pt, b: Pt, c: Pt): Int {
    val v = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    return if (abs(v) < 1e-3) 0 else if (v > 0) 1 else -1
}

private fun onSeg(a: Pt, b: Pt, c: Pt): Boolean {
    val e = 1e-6
    return min(a.x, b.x) - e <= c.x && c.x <= max(a.x, b.x) + e && min(a.y, b.y) - e <= c.y && c.y <= max(a.y, b.y) + e
}

private fun segsMeet(a: Pt, b: Pt, c: Pt, d: Pt): Boolean {
    val o1 = turnSign(a, b, c); val o2 = turnSign(a, b, d); val o3 = turnSign(c, d, a); val o4 = turnSign(c, d, b)
    if (o1 != o2 && o3 != o4 && o1 != 0 && o2 != 0 && o3 != 0 && o4 != 0) return true
    if (o1 == 0 && onSeg(a, b, c)) return true
    if (o2 == 0 && onSeg(a, b, d)) return true
    if (o3 == 0 && onSeg(c, d, a)) return true
    if (o4 == 0 && onSeg(c, d, b)) return true
    return o1 != o2 && o3 != o4
}

/* ---------------- step errors (mockup wNext / stepErr) ---------------- */

/** A wall (or bay size) typed on the walls step: null when 300–20 000 mm, else [ShapeErrorCode.OUT_OF_RANGE]. */
fun wallValueError(v: Int?): ShapeError? =
    if (v == null || v < SHAPE_WALL_MIN || v > SHAPE_WALL_MAX) ShapeError(ShapeErrorCode.OUT_OF_RANGE, value = v?.toDouble(), min = SHAPE_WALL_MIN.toDouble(), limit = SHAPE_WALL_MAX.toDouble()) else null

/** The height step: null when 2 000–6 000 mm, else [ShapeErrorCode.OUT_OF_RANGE]. */
fun heightError(v: Int?): ShapeError? =
    if (v == null || v < SHAPE_HEIGHT_MIN || v > SHAPE_HEIGHT_MAX) ShapeError(ShapeErrorCode.OUT_OF_RANGE, value = v?.toDouble(), min = SHAPE_HEIGHT_MIN.toDouble(), limit = SHAPE_HEIGHT_MAX.toDouble()) else null

/**
 * What stops "Keyingi" on walls step [step], with [values] holding everything typed so far including this step's
 * value (mockup wNext + stepErr). Each error shows on the step where it becomes knowable: the range at once; the cut
 * from its D step (D < A) and E step (B < E); the bay's "doesn't fit" from its width step and "too deep" at the depth
 * step; anything else (a wall worked out negative, crossing walls, the free sketch not closing) on the last step, or
 * on any step when [editingOne] (changing one value from the summary).
 */
fun stepError(spec: ShapeSpec, values: List<Int?>, step: Int, editingOne: Boolean = false): ShapeError? {
    wallValueError(values.getOrNull(step))?.let { return it }
    val n = asks(spec).size
    val last = step >= n - 1 || editingOne
    val g = shapeGeometry(spec, values)
    val v = g.values
    return when (spec.shape.kind) {
        ShapeKind.CUT -> when {
            step >= 2 && v[0] - v[2] <= 0 -> ShapeError(ShapeErrorCode.CUT_D_NOT_SHORTER, wall = 3, limit = v[0].toDouble())
            step >= 3 && v[3] - v[1] <= 0 -> ShapeError(ShapeErrorCode.CUT_B_NOT_SHORTER, wall = 1, limit = v[3].toDouble())
            else -> if (last) g.error else null
        }
        ShapeKind.BAY -> when {
            step >= 3 && g.error?.code == ShapeErrorCode.BAY_NOT_FIT -> g.error
            step >= 4 -> g.error
            else -> if (last) g.error else null
        }
        else -> if (last) g.error else null
    }
}

/* ---------------- the diagonal (free sketch, optional) ---------------- */

/** The diagonal runs from corner 0 to this corner (mockup diagK: half the asked walls). */
fun diagonalCorner(spec: ShapeSpec): Int = asks(spec).size / 2

/** The diagonal the walls give, mm (the field's hint is this rounded to 10 mm). */
fun expectedDiagonal(g: ShapeGeo): Double { val a = g.corners[0]; val b = g.corners[diagonalCorner(g.spec)]; return hypot(a.x - b.x, a.y - b.y) }

/**
 * A typed diagonal: out of range, or off the walls' by more than the room editor's own tolerance ([SK_TOL], 20 mm,
 * against the length rounded to whole mm, as Geometry.kt checks a drawn room's diagonal), so a diagonal the flow takes
 * never shows "warn" in the editor ([ShapeErrorCode.DIAG_MISMATCH]; decided 27 Oct 2026 instead of the mockup's
 * max(30 mm, 2 %)); null when it matches.
 */
fun diagonalError(spec: ShapeSpec, values: List<Int?>, diag: Int?): ShapeError? {
    wallValueError(diag)?.let { return it }
    val d = expectedDiagonal(shapeGeometry(spec, values))
    return if (abs(diag!! - d.roundToInt()) > SK_TOL) ShapeError(ShapeErrorCode.DIAG_MISMATCH, value = diag.toDouble(), limit = d) else null
}

/* ---------------- doors, windows and pipes on the plan (mockup OP, opNext, opHint) ---------------- */

/** What the "Eshik, deraza, suv, gaz bormi?" step adds: a door, a window, cold water, the sewer or a gas pipe. */
enum class OpKind(val id: String) { DOOR("door"), WINDOW("window"), WATER("water"), SEWER("sewer"), GAS("gas");
    /** A door or window (an opening in the wall), not a pipe (a site point). */
    val isOpening: Boolean get() = this == DOOR || this == WINDOW
}

/** One field of an added item: the distance from the wall's start corner (the dot), the width, the height, a window's sill. */
enum class OpField { DIST, WIDTH, HEIGHT, SILL }

/** A field asked for an item, in order, with the value it starts from. */
data class OpAsk(val field: OpField, val default: Int)

/** The fields each kind asks (a window's sill is prefilled with 900, BUILD_SPEC §2.6). */
fun opAsks(kind: OpKind): List<OpAsk> = when (kind) {
    OpKind.DOOR -> listOf(OpAsk(OpField.DIST, 600), OpAsk(OpField.WIDTH, 900), OpAsk(OpField.HEIGHT, 2100))
    OpKind.WINDOW -> listOf(OpAsk(OpField.DIST, 900), OpAsk(OpField.WIDTH, 1500), OpAsk(OpField.HEIGHT, 1500), OpAsk(OpField.SILL, 900))
    OpKind.WATER -> listOf(OpAsk(OpField.DIST, 400))
    OpKind.SEWER -> listOf(OpAsk(OpField.DIST, 700))
    OpKind.GAS -> listOf(OpAsk(OpField.DIST, 1200))
}

/**
 * An item added on the plan: on shape wall [wall], [dist] mm from that wall's start corner (ShapeWall.from, the dot)
 * to the door's or window's near edge, or to the pipe. [w], [h] and [sill] for doors and windows only.
 */
data class ShapeOpening(val kind: OpKind, val wall: Int, val dist: Int, val w: Int = 0, val h: Int = 0, val sill: Int = 0)

/**
 * The value a field starts from on wall [wall] (mockup opHint): the default, shrunk so it fits the wall; [dist] and
 * [w] are the fields typed before it.
 */
fun opHint(g: ShapeGeo, roomHeight: Int, kind: OpKind, wall: Int, field: OpField, dist: Int = 0, w: Int = 0, h: Int = 0): Int {
    val f = opAsks(kind); val def = f.first { it.field == field }.default; val L = g.walls[wall].len
    return when (field) {
        OpField.DIST -> { val ww = f.getOrNull(1)?.default ?: 0; max(0, min(def, (floor((L - ww - 100) / 10) * 10).toInt())) }
        OpField.WIDTH -> max(SHAPE_WALL_MIN, min(def, (floor((L - dist) / 10) * 10).toInt()))
        OpField.HEIGHT -> min(def, roomHeight)
        OpField.SILL -> max(0, min(def, roomHeight - h))
    }
}

/**
 * What stops "Keyingi" on an item's field (mockup opNext): [value] typed for [field]; [dist], [w], [h] typed before.
 * Distance: at most the wall. Width: 300–20 000 and distance + width within the wall. Height: 300 up to the room's
 * height. Sill: sill + height up to the room's height.
 */
fun opFieldError(g: ShapeGeo, roomHeight: Int, kind: OpKind, wall: Int, field: OpField, value: Int?, dist: Int = 0, w: Int = 0, h: Int = 0): ShapeError? {
    if (value == null) return ShapeError(ShapeErrorCode.EMPTY)
    val L = g.walls[wall].len
    return when (field) {
        OpField.DIST -> if (value < 0) ShapeError(ShapeErrorCode.OUT_OF_RANGE, value = value.toDouble(), min = 0.0, limit = L)
            else if (value > L) ShapeError(ShapeErrorCode.OP_PAST_WALL, wall = wall, value = value.toDouble(), limit = L) else null
        OpField.WIDTH -> wallValueError(value) ?: if (dist + value > L) ShapeError(ShapeErrorCode.OP_NOT_FIT, wall = wall, value = (dist + value).toDouble(), limit = L) else null
        OpField.HEIGHT -> if (value < SHAPE_WALL_MIN || value > roomHeight) ShapeError(ShapeErrorCode.OUT_OF_RANGE, value = value.toDouble(), min = SHAPE_WALL_MIN.toDouble(), limit = roomHeight.toDouble()) else null
        OpField.SILL -> if (value < 0) ShapeError(ShapeErrorCode.OUT_OF_RANGE, value = value.toDouble(), min = 0.0, limit = (roomHeight - h).toDouble())
            else if (value + h > roomHeight) ShapeError(ShapeErrorCode.OP_ABOVE_CEILING, value = (value + h).toDouble(), limit = roomHeight.toDouble()) else null
    }
}

/** The first problem with a whole item, field by field, or null. */
fun openingError(g: ShapeGeo, roomHeight: Int, op: ShapeOpening): ShapeError? {
    if (op.wall !in g.walls.indices) return ShapeError(ShapeErrorCode.EMPTY)
    for (a in opAsks(op.kind)) {
        val v = when (a.field) { OpField.DIST -> op.dist; OpField.WIDTH -> op.w; OpField.HEIGHT -> op.h; OpField.SILL -> op.sill }
        opFieldError(g, roomHeight, op.kind, op.wall, a.field, v, op.dist, op.w, op.h)?.let { return it }
    }
    return null
}
