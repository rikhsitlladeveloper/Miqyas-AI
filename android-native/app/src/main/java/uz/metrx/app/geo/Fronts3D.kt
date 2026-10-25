package uz.metrx.app.geo

import kotlin.math.cos
import kotlin.math.sin

/*
 * Doors and drawers that move without the room being rebuilt (smooth on weak phones, 25 Oct 2026). With
 * furniture3D(split = true) each door, drawer, sliding door, rack and lift-up bed base is built once, shut, as a
 * [Front3D] of its own: its boards, handle and outlines, and how it moves ([Motion]: a turn about its hinge, a pull
 * out or a slide). The 3D (Scene3D.kt) draws it as its own small entities and on every step of the animation only
 * sets their transform; the rest of the piece ([Furn3D.parts]) is built and merged per look once and stays put.
 */

/**
 * How a front moves when fully open: turned [angle] radians (right-handed) about the line through [pivot] along the
 * unit [axis], then moved by [shift] (metres). Partly open ([at]) both go in proportion, as the full rebuild did
 * (a door's angle, a drawer's pull and a sliding door's shift are all linear in how far it is open).
 */
class Motion(val pivot: V3, val axis: V3, val angle: Double, val shift: V3) {
    /** The rigid move of a front [k] (0 shut … 1 open) of the way open. */
    fun at(k: Double): Rigid {
        val a = angle * k
        val m = if (a == 0.0) Rigid.I else rotation(axis, a)
        // p' = R (p − pivot) + pivot + shift k
        val rp = mul(m, pivot)
        return Rigid(m, V3(pivot.x - rp.x + shift.x * k, pivot.y - rp.y + shift.y * k, pivot.z - rp.z + shift.z * k))
    }

    companion object {
        private val ZERO = V3(0.0, 0.0, 0.0)
        /** Turned [angle] about the line through [pivot] along [axis] (a hinge, a lift-up bed's base). */
        fun turn(pivot: V3, axis: V3, angle: Double) = Motion(pivot, axis.unit(), angle, ZERO)
        /** Moved along [by] (a drawer pulled out, a sliding door, a rack). */
        fun move(by: V3) = Motion(ZERO, V3(0.0, 1.0, 0.0), 0.0, by)

        /** Rodrigues: the rotation by [a] about unit [k], row-major. */
        private fun rotation(k: V3, a: Double): DoubleArray {
            val c = cos(a); val s = sin(a); val t = 1 - c
            val x = k.x; val y = k.y; val z = k.z
            return doubleArrayOf(
                t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c)
        }
        internal fun mul(m: DoubleArray, v: V3) = V3(m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z, m[6] * v.x + m[7] * v.y + m[8] * v.z)
    }
}

/** A rigid move: rotation [m] (3 × 3, row-major) then translation [t]. */
class Rigid(val m: DoubleArray, val t: V3) {
    fun point(p: V3) = Motion.mul(m, p) + t
    fun dir(v: V3) = Motion.mul(m, v)
    /** The box moved with it (its corner moved, its edges turned). */
    fun obb(x: Obb) = Obb(point(x.o), dir(x.a), dir(x.b), dir(x.c))

    /** As Filament's TransformManager takes it: 4 × 4, column-major. */
    fun columns(): FloatArray = floatArrayOf(
        m[0].toFloat(), m[3].toFloat(), m[6].toFloat(), 0f,
        m[1].toFloat(), m[4].toFloat(), m[7].toFloat(), 0f,
        m[2].toFloat(), m[5].toFloat(), m[8].toFloat(), 0f,
        t.x.toFloat(), t.y.toFloat(), t.z.toFloat(), 1f)

    companion object {
        val I = doubleArrayOf(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    }
}

/**
 * One door, drawer, sliding door, rack or lift-up base ([key]), built shut: its [parts] (its board in the piece's
 * style, its handle, a mirror, glass…) and [edges], its tap boxes [picks], and [inner], what shows only while it is
 * open at all (a drawer's box, which the full rebuild left out when shut). [motion] moves all of them together.
 */
class Front3D(val key: String, val motion: Motion, val parts: List<Part>, val edges: List<Edges>, val picks: List<Pick>,
              val inner: List<Part>, val innerEdges: List<Edges>) {
    /** Where it is [k] of the way open. */
    fun at(k: Double): Rigid = motion.at(k)
}

/**
 * Something that is drawn one way while any of [deps] is open and another while all are shut (a wardrobe's LED with
 * door sensors: lit and its glow, or a plain strip): [whenOpen] says which of the two this is.
 */
class Toggle3D(val deps: List<String>, val whenOpen: Boolean, val parts: List<Part>, val edges: List<Edges>) {
    /** Shown with doors and drawers as open as [amt] says (more than 2 % open counts, as before). */
    fun shown(amt: (String) -> Double): Boolean = deps.any { amt(it) > .02 } == whenOpen
}

/** What the builder collects into while it draws one front (or one toggle). */
internal class Cap {
    val parts = LinkedHashMap<Pair<String?, Any>, Part>(); val edges = LinkedHashMap<String?, Edges>(); val picks = ArrayList<Pick>()
}

internal class FrontCap(val key: String, val motion: Motion) {
    val main = Cap(); val inner = Cap()
    fun done() = Front3D(key, motion, main.parts.values.filter { it.faces.isNotEmpty() }, main.edges.values.filter { it.segs.isNotEmpty() }, main.picks,
        inner.parts.values.filter { it.faces.isNotEmpty() }, inner.edges.values.filter { it.segs.isNotEmpty() })
}

internal class ToggleCap(val deps: List<String>, val whenOpen: Boolean) {
    val cap = Cap()
    fun done() = Toggle3D(deps, whenOpen, cap.parts.values.filter { it.faces.isNotEmpty() }, cap.edges.values.filter { it.segs.isNotEmpty() })
}

/** The tap boxes of everything that can be opened, each where it is with the fronts as open as [amt] says. */
fun Furn3D.picksAt(amt: (String) -> Double): List<Pick> =
    if (fronts.isEmpty()) picks
    else picks + fronts.flatMap { fr -> val k = amt(fr.key); val r = fr.at(k); fr.picks.map { Pick(it.key, if (k == 0.0) it.box else r.obb(it.box)) } }
