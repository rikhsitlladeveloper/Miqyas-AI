package uz.metrx.app.geo

import uz.metrx.app.data.Diag
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.pointDefaults
import uz.metrx.app.data.uid
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.roundToInt

/*
 * A finished room shape (RoomShapes.kt) as the app's real Room, so the room editor, the 3D view, the furniture and
 * the trades take it as they take a room made today (BUILD_SPEC §2). Pure Kotlin, unit-tested (ShapeRoomTest).
 *
 * - To‘rtburchak is the app's plain rectangle: shape "rect", dims A and B, the turn in Room.rot (wall i sits on side
 *   (i + rot) % 4, as the editor draws it). Nothing downstream changes.
 * - Every other shape is a drawn room (shape "poly"): its corners as shown (mirror and turn applied), clockwise, wall A
 *   on the shape's wall A. Mirroring reverses the walk, so the other letters run the other way round: [ShapeRoom.wallIds]
 *   says which room wall each shape wall became.
 * - Walls are confirmed measurements (Dim(v, "manual"), like a typed one), so the editor does not ask for them again.
 *   Up to two worked-out walls are left empty for the editor's solver, which shows them as "=x" (status "calc"), as
 *   the mockup's "avtomat"; the rest (the bay's 45° sides and front) are stored measured.
 * - The height is a confirmed H; the optional diagonal is the drawn room's diagonal X1 from corner A.
 * - Doors and windows become Openings, water, sewer and gas become SitePoints ("cold", "sewer", "gas"), measured from
 *   the room wall's own start corner (clockwise), so a mirrored wall's distance is turned round.
 */

/**
 * A shape made into a [room]. [wallIds]: the room wall id of each shape wall (index = shape wall); [flipped]: whether
 * that room wall runs the other way (its start corner is the shape wall's end); [lens]: each room wall's length, mm.
 */
data class ShapeRoom(val room: Room, val wallIds: List<String>, val flipped: List<Boolean>, val lens: List<Int>) {
    /** The room wall id of shape wall [shapeWall]. */
    fun roomWall(shapeWall: Int): String = wallIds[shapeWall]

    /**
     * The room with [op] added: a door or window as an Opening (its near edge [ShapeOpening.dist] from the dot corner),
     * water, sewer or gas as a SitePoint at its default height and size (data/SitePoints.kt pointDefaults).
     */
    fun withOpening(op: ShapeOpening, id: String = uid()): ShapeRoom {
        val wall = wallIds[op.wall]; val L = lens[op.wall]; val flip = flipped[op.wall]
        return if (op.kind.isOpening) {
            val off = (if (flip) L - op.dist - op.w else op.dist).coerceAtLeast(0)
            val o = Opening(id, op.kind.id, wall, op.w, op.h, off, if (op.kind == OpKind.WINDOW) op.sill else 0)
            copy(room = room.copy(openings = room.openings + o))
        } else {
            val t = when (op.kind) { OpKind.WATER -> "cold"; OpKind.SEWER -> "sewer"; else -> "gas" }
            val (h, d, mh) = pointDefaults(t)
            val off = (if (flip) L - op.dist else op.dist).coerceIn(0, L)
            copy(room = room.copy(points = room.points + SitePoint(id, t, wall, off, h, d, mh, "manual")))
        }
    }
}

/**
 * The room for a finished shape: [values] as asked (RoomShapes.kt asks), mirror and turn from [spec], [height] mm, an
 * optional free-sketch [diagonal] and the added [openings]. Null when the shape does not close (shapeGeometry's error).
 * [angleSnap] is Poly.snap for a drawn room whose walls are all at 45° steps (the cut corner and an unsnapped sketch
 * get no snap, so their own angles are kept).
 */
fun shapeToRoom(
    spec: ShapeSpec, values: List<Int?>, height: Int, id: String, floorId: String, name: String, created: Long = 0,
    diagonal: Int? = null, openings: List<ShapeOpening> = emptyList(), angleSnap: Boolean = true
): ShapeRoom? {
    val g = shapeGeometry(spec, values)
    if (!g.ok) return null
    val P = g.cornersShown
    val n = P.size
    // clockwise on screen; mirroring made it anticlockwise: walk the other way, still starting with wall A
    val rev = polygonArea(P) < 0
    val roomOf = { j: Int -> if (rev) (n - j) % n else j }            // shape wall j -> room wall
    val cornerOf = { i: Int -> if (rev) ((1 - i) % n + n) % n else i } // shape corner i -> room corner
    val V0 = if (rev) List(n) { k -> P[((1 - k) % n + n) % n] } else P
    val mx = V0.minOf { it.x }; val my = V0.minOf { it.y }
    val V = V0.map { Pt(clean(it.x - mx), clean(it.y - my)) }
    val lens = List(n) { k -> val a = V[k]; val b = V[(k + 1) % n]; hypot(b.x - a.x, b.y - a.y).roundToInt() }
    val H = "H" to Dim(height, "manual"); val T = "T" to Dim(200, "default")
    val shapeLens = List(n) { j -> lens[roomOf(j)] }
    val flipped = List(n) { rev }

    if (spec.shape == RoomShape.RECT) {
        // the rectangle's wall A sits on side rot: 0 top (→), 1 right (↓), 2 bottom (←), 3 left (↑)
        val a = V[0]; val b = V[1]
        val rot = when { b.x - a.x > 0.5 -> 0; b.y - a.y > 0.5 -> 1; a.x - b.x > 0.5 -> 2; else -> 3 }
        val ids = listOf("A", "B", "C", "D")
        val room = Room(id, floorId, name, created = created, rot = rot,
            dims = mapOf("A" to Dim(lens[0], "manual"), "B" to Dim(lens[1], "manual"), H, T))
        return ShapeRoom(room, List(n) { ids[roomOf(it)] }, flipped, shapeLens).withAll(openings)
    }

    val ids = polyWallIds(n)
    // the worked-out walls the editor's solver can still find (at most two, not parallel) stay empty: shown "=x".
    // Those that are not whole mm (the cut, the bay's 45° sides) first, so every stored length is exact; then from the last.
    val open = ArrayList<Int>()
    val derived = (n - 1 downTo 0).filter { g.walls[it].derived }
    for (j in derived.filter { !whole(g.walls[it].len) } + derived.filter { whole(g.walls[it].len) }) {
        if (open.size == 2) break
        val k = roomOf(j)
        if (open.isEmpty() || !parallel(V, open[0], k)) open += k
    }
    val dims = HashMap<String, Dim>()
    for (k in 0 until n) dims[ids[k]] = if (k in open) Dim() else Dim(lens[k], "manual")
    dims += H; dims += T
    val diags = ArrayList<Diag>()
    if (diagonal != null) {
        diags += Diag("X1", cornerOf(0), cornerOf(diagonalCorner(spec)))
        dims["X1"] = Dim(diagonal, "manual")
    }
    val snap = angleSnap && (0 until n).all { k -> val a = V[k]; val b = V[(k + 1) % n]; onStep(atan2(b.y - a.y, b.x - a.x)) }
    val room = Room(id, floorId, name, template = "poly", shape = "poly", dims = dims,
        poly = Poly(V, diags, template = "rsh." + spec.shape.id, snap = snap), created = created)
    return ShapeRoom(room, List(n) { ids[roomOf(it)] }, flipped, shapeLens).withAll(openings)
}

/**
 * The room editor's id of each wall of the shape, before the room is made (the walls steps name walls as the editor
 * will): the same mapping as [shapeToRoom]'s [ShapeRoom.wallIds]. Mirroring reverses the walk (wall A stays A), the
 * rectangle's walls are A–D, a drawn room's are [polyWallIds] (no H, I, O, T, X: H is the height). [n]: the wall count.
 */
fun shapeWallIds(spec: ShapeSpec, n: Int): List<String> {
    val ids = if (spec.shape == RoomShape.RECT) listOf("A", "B", "C", "D") else polyWallIds(n)
    return List(n) { j -> ids[if (spec.mirror) (n - j) % n else j] }
}

private fun ShapeRoom.withAll(ops: List<ShapeOpening>) = ops.fold(this) { r, op -> r.withOpening(op) }

/** Rounds away float dust (−0, 2599.9999999), keeping real fractions (a free sketch's spread corners). */
private fun clean(x: Double): Double { val r = Math.round(x).toDouble(); return if (abs(x - r) < 1e-6) r + 0.0 else x }

private fun whole(x: Double) = abs(x - Math.round(x)) < 1e-6

private fun onStep(a: Double): Boolean { val s = PI / 4; val k = a / s; return abs(k - Math.round(k)) < 1e-6 }

private fun parallel(V: List<Pt>, i: Int, j: Int): Boolean {
    val n = V.size
    val ax = V[(i + 1) % n].x - V[i].x; val ay = V[(i + 1) % n].y - V[i].y
    val bx = V[(j + 1) % n].x - V[j].x; val by = V[(j + 1) % n].y - V[j].y
    return abs(ax * by - ay * bx) <= 1e-6 * hypot(ax, ay) * hypot(bx, by)
}
