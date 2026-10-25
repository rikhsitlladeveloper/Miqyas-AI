package uz.metrx.app.geo

import uz.metrx.app.furniture.BED_SINK
import uz.metrx.app.furniture.Board
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Mat
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.Opt
import uz.metrx.app.furniture.bedDrawers
import uz.metrx.app.furniture.bedPanelReach
import uz.metrx.app.furniture.bedPanelSpan
import uz.metrx.app.furniture.hasHandle
import uz.metrx.app.furniture.itemBoards
import uz.metrx.app.furniture.legsOf
import uz.metrx.app.furniture.lookOf
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/*
 * The board-built items in the lit 3D (modern 3D part 6b, 25 Oct 2026; the approved mockup scratchpad
 * modern3d/modern-3d.html buildBed): a bed's upholstered headboard by its design (vertical channels, carriage-tufted with
 * buttons, square panels) in its fabric, the soft wall panel behind it with LED over it, the mattress, sheet, duvet,
 * throw and pillows as soft rounded cushions, the slats of a lift-up bed, metal legs or a hidden base; a bunk or loft
 * bed's ladder and guards in the wood accent; tables' and bar counters' tops with a soft edge (round corners where
 * chosen) in their worktop's stone or wood, legs in the handles' metal; a mirror panel's coat hooks; a vanity's white
 * ceramic basin with its tap in the handles' colour. The boards are still [itemBoards]' (the parts list and the picture
 * agree); what only the picture shows is drawn here. The light tier draws no bedding detail, tufting or glow.
 * Furniture3D.kt calls in from two hooks ([itemLit], [basinLit]); the 2D painter keeps the plain boxes.
 */

/** White glazed ceramic (a basin; mockup porc). */
val CERAMIC = Look(0xF7F5F1, rough = .18f, clear = 1f, reflect = .55f)
/** A bed's hidden base: matte black, set back under the frame (mockup M.black). */
val BED_BASE = Look(0x141518, rough = .6f, reflect = .35f)
/** Bed linen (the pillows) and the duvet: woven cotton, off-white (mockup linen, duvet). */
val LINEN = Look(0xF2EFEA, rough = .93f, tex = "fabric", tint = true, reflect = .3f)
val DUVET = Look(0xECE7DF, rough = .93f, tex = "fabric", tint = true, reflect = .3f)

/** How deep an upholstered headboard's cushions stand out of the headboard board, mm (the mattress starts in front of them). */
const val HEAD_SOFT_D = 70

/** A rectangle on a face, mm: [u0]..[u1] across, [v0]..[v1] up. */
data class Cell(val u0: Double, val u1: Double, val v0: Double, val v1: Double)

/**
 * The cushions of an upholstered headboard or a soft wall panel [w] × [h] mm (mockup soft()): "vertical" channels about
 * 150 wide, "panels" squares about 440 × 420, otherwise ("tufted") one cushion over the whole.
 */
fun softCells(kind: String, w: Double, h: Double): List<Cell> = when (kind) {
    "vertical" -> { val n = max(3, (w / 150).roundToInt()); val s = w / n; (0 until n).map { Cell(it * s + 2, (it + 1) * s - 2, 0.0, h) } }
    "panels" -> {
        val c = max(2, (w / 440).roundToInt()); val r = max(1, (h / 420).roundToInt()); val cw = w / c; val rh = h / r
        (0 until c).flatMap { i -> (0 until r).map { j -> Cell(i * cw + 3, (i + 1) * cw - 3, j * rh + 3, (j + 1) * rh - 3) } }
    }
    else -> listOf(Cell(0.0, w, 0.0, h))
}

/** The soft wall panel's cushions go with the headboard (mockup): channels behind square panels, square panels otherwise. */
fun wallPanelKind(head: String) = if (head == "panels") "vertical" else "panels"

/** The spacing of a tufted cushion's buttons along a row, mm (every other point of an 80 mm grid: a diamond lattice). */
private const val TUFT = 160.0

/** Where a carriage-tufted cushion [w] wide starts its lattice: the buttons centred, at least 40 from the edges. */
private fun tuftOrigin(w: Double): Double = (w - floor(max(0.0, w - 80) / (TUFT / 2)) * (TUFT / 2)) / 2

/** The buttons of a carriage-tufted cushion [w] × [h] mm: a diamond lattice of 80 mm (mockup tuft), u across, v up. */
fun tuftButtons(w: Double, h: Double): List<Pair<Double, Double>> {
    val u0 = tuftOrigin(w); val v0 = tuftOrigin(h); val s = TUFT / 2
    val nu = floor((w - 2 * u0) / s + 1e-6).toInt(); val nv = floor((h - 2 * v0) / s + 1e-6).toInt()
    return (0..nu).flatMap { i -> (0..nv).mapNotNull { j -> if ((i + j) % 2 == 0) (u0 + i * s) to (v0 + j * s) else null } }
}

/**
 * How far a tufted cushion is drawn in at [u], [v] (from its corner, mm): a dimple round each button, a shallow pleat
 * along the diagonals from button to button.
 */
fun tuftDip(u: Double, v: Double, w: Double, h: Double): Double {
    val x = u - tuftOrigin(w); val y = v - tuftOrigin(h)
    fun fold(q: Double): Double { val m = ((q % TUFT) + TUFT) % TUFT; return min(m, TUFT - m) }
    fun sq(q: Double) = q * q
    val d1 = fold(x - y) / sqrt(2.0); val d2 = fold(x + y) / sqrt(2.0)
    val pleat = 6.0 * max(sq(max(0.0, 1 - d1 / 20)), sq(max(0.0, 1 - d2 / 20)))
    // the nearest button: the lattice is the integer points of ((x + y) / 160, (x - y) / 160)
    val p = ((x + y) / TUFT).roundToInt(); val q = ((x - y) / TUFT).roundToInt()
    val bx = TUFT / 2 * (p + q); val by = TUFT / 2 * (p - q)
    val dimple = 14.0 * sq(max(0.0, 1 - hypot(x - bx, y - by) / 55))
    return max(pleat, dimple)
}

/**
 * A bed's soft wall panel ([Look.panel]) by the rule the price uses too (Look.kt bedPanelSpan, priced by this area in
 * lookHardware): centred on the bed, 400 past each side, from 80 mm off the floor to 1380 or 150 over the headboard;
 * cut to the wall's [lo]..[hi] (mm along it from the bed's corner). Null without one.
 */
fun bedPanel(m: Module, on: Boolean, lo: Double = -1e9, hi: Double = 1e9): Cell? {
    if (!on) return null
    val s = bedPanelSpan(m, lo, hi) ?: return null
    return Cell(s.a0, s.a1, s.y0, s.y1)
}

/** The surface of a design part of [f] ([lookOf]) as the lit 3D draws it. */
private fun designLook(f: Furniture?, part: String, mats: List<Mat>, kind: String = "board"): Look {
    val s = lookOf(f ?: Furniture("", "wardrobe"), null, part, mats)
    return Looks.surface(rgbOf(s.rgb), s.finish, s.tex, kind)
}

/** [rgb] a share [k] of the way to white (the mockup's lighter fabric of the wall panel and the cushions). */
private fun lighter(rgb: Int, k: Double): Int {
    fun ch(s: Int) = (((rgb shr s) and 255) + (255 - ((rgb shr s) and 255)) * k).roundToInt().coerceIn(0, 255)
    return (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
}

/* ---------------- drawing in an item's frame ---------------- */

/**
 * Draws on wall frame [w] in an item's own millimetres: [x0] its start along the wall. While [th] is not 0 what is drawn
 * is turned about the line across the item at [py] up, [pn] out (a lift-up bed's base rising).
 */
private class Pen(val B: Builder3, val w: WallBasis, val x0: Double) {
    var th = 0.0; var py = 0.0; var pn = 0.0
    val sides get() = if (B.light) 8 else 14

    fun at(a: Double, y: Double, n: Double): V3 {
        if (th == 0.0) return w.at((x0 + a) / 1000, y / 1000, n / 1000)
        val c = cos(th); val s = sin(th); val dy = y - py; val dn = n - pn
        return w.at((x0 + a) / 1000, (py + dn * s + dy * c) / 1000, (pn + dn * c - dy * s) / 1000)
    }

    /** A plain box (a board, a leg): its grain along [grain], else its long side. */
    fun box(p: Part, a0: Double, a1: Double, y0: Double, y1: Double, n0: Double, n1: Double, line: Boolean = false, grain: V3? = null) {
        if (a1 - a0 < .1 || y1 - y0 < .1 || n1 - n0 < .1) return
        val o = at(a0, y0, n0)
        B.obb(p, Obb(o, at(a1, y0, n0) - o, at(a0, y1, n0) - o, at(a0, y0, n1) - o), line, grain)
    }

    fun board(p: Part, b: Board, line: Boolean = true) = box(p, b.a0.toDouble(), b.a1.toDouble(), b.y0.toDouble(), b.y1.toDouble(), b.n0.toDouble(), b.n1.toDouble(), line)

    /** A round rod from [a] to [b] (each along, up, out), radius [r0] to [r1]. */
    fun rod(p: Part, a: DoubleArray, b: DoubleArray, r0: Double, r1: Double = r0, n: Int = sides) =
        B.tube(p, at(a[0], a[1], a[2]), at(b[0], b[1], b[2]), r0 / 1000, r1 / 1000, n)

    /** One face [q] facing away from [inside] (or along [toward] when given), its texture along [ua], [va] from [o]. */
    fun face(p: Part, q: List<V3>, inside: V3, ua: V3, va: V3, o: V3, toward: V3? = null) {
        val n0 = cross(q[1] - q[0], q[q.size - 1] - q[0]).let { if (it.len() < 1e-12 && q.size > 3) cross(q[2] - q[1], q[0] - q[1]) else it }
        if (n0.len() < 1e-12) return
        var n = n0.unit()
        val fc = V3(q.sumOf { it.x } / q.size, q.sumOf { it.y } / q.size, q.sumOf { it.z } / q.size)
        if (n.dot(toward ?: (fc - inside)) < 0) n = n * -1.0
        val (ou, ov) = grainOffset(o)
        p.faces += Face(n, q, uv = uvOf(q, o, ua, va, ou, ov))
    }

    /**
     * A soft cushion (mockup RoundedBoxGeometry): the box [a0]..[a1], [y0]..[y1], [n0]..[n1] with its edges rounded to
     * [r0] in [seg] steps; [tilt] turns it about the across line through its middle (radians; above 0 its far end goes down
     * and its near end up: a pillow propped against the headboard).
     */
    fun soft(p: Part, a0: Double, a1: Double, y0: Double, y1: Double, n0: Double, n1: Double, r0: Double, seg: Int, tilt: Double = 0.0) {
        val lo = doubleArrayOf(a0, y0, n0); val hi = doubleArrayOf(a1, y1, n1)
        if ((0..2).any { hi[it] - lo[it] < .5 }) return
        val r = max(0.0, min(r0, (0..2).minOf { (hi[it] - lo[it]) / 2 } * .98))
        val c = DoubleArray(3) { (lo[it] + hi[it]) / 2 }
        val ct = cos(tilt); val st = sin(tilt)
        fun lin(q: DoubleArray): V3 { val dy = q[1] - c[1]; val dn = q[2] - c[2]; return at(q[0], c[1] + dy * ct - dn * st, c[2] + dy * st + dn * ct) }
        fun onto(q: DoubleArray): V3 {
            val inner = DoubleArray(3) { q[it].coerceIn(lo[it] + r, hi[it] - r) }
            val d = DoubleArray(3) { q[it] - inner[it] }; val l = sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2])
            return lin(DoubleArray(3) { if (l > 1e-9) inner[it] + d[it] / l * r else q[it] })
        }
        val k = if (r < .5) 0 else max(1, seg)
        // samples across a face: its rounded edge in even turns of the arc, the flat middle as one strip
        fun samples(l: Double, h: Double): DoubleArray = if (k == 0) doubleArrayOf(l, h) else
            DoubleArray(2 * k + 2) { i -> if (i <= k) l + r * (1 - tan(PI / 4 * (1 - i.toDouble() / k))) else h - r * (1 - tan(PI / 4 * ((i - k - 1).toDouble() / k))) }
        val mid = lin(c)
        val axes = (0..2).map { ax -> lin(DoubleArray(3) { c[it] + if (it == ax) 1.0 else 0.0 }) - mid }.map { it.unit() }
        for (ax in 0..2) {
            val i = (ax + 1) % 3; val j = (ax + 2) % 3
            val si = samples(lo[i], hi[i]); val sj = samples(lo[j], hi[j])
            for (side in listOf(lo[ax], hi[ax])) {
                val o = lin(DoubleArray(3) { when (it) { ax -> side; else -> lo[it] } })
                for (ii in 0 until si.size - 1) for (jj in 0 until sj.size - 1) {
                    if (si[ii + 1] - si[ii] < 1e-6 || sj[jj + 1] - sj[jj] < 1e-6) continue
                    fun pt(u: Double, v: Double) = onto(DoubleArray(3) { when (it) { ax -> side; i -> u; else -> v } })
                    val q = listOf(pt(si[ii], sj[jj]), pt(si[ii + 1], sj[jj]), pt(si[ii + 1], sj[jj + 1]), pt(si[ii], sj[jj + 1]))
                    if ((q[2] - q[0]).len() < 1e-7) continue
                    face(p, q, mid, axes[i], axes[j], o)
                }
            }
        }
    }

    /**
     * A carriage-tufted cushion over [a0]..[a1], [y0]..[y1], from [n0] out [depth]: its front a fine grid drawn in at the
     * buttons and along the pleats ([tuftDip]), its edges rolled round; the buttons in [btn].
     */
    fun tufted(p: Part, btn: Part, a0: Double, a1: Double, y0: Double, y1: Double, n0: Double, depth: Double) {
        val w0 = a1 - a0; val h0 = y1 - y0
        if (w0 < 60 || h0 < 60) return
        val nu = max(4, (w0 / 20).roundToInt()); val nv = max(4, (h0 / 20).roundToInt())
        val roll = min(30.0, depth * .6)
        fun z(u: Double, v: Double): Double {
            val d = min(min(u, w0 - u), min(v, h0 - v))
            val e = if (d < roll) roll - sqrt(max(0.0, roll * roll - (roll - d) * (roll - d))) else 0.0
            // the pleats and dimples fade out towards the rolled edge
            return n0 + depth - e - tuftDip(u, v, w0, h0) * ((d - 10) / 30).coerceIn(0.0, 1.0)
        }
        fun pt(i: Int, j: Int): V3 { val u = w0 * i / nu; val v = h0 * j / nv; return at(a0 + u, y0 + v, z(u, v)) }
        val grid = Array(nu + 1) { i -> Array(nv + 1) { j -> pt(i, j) } }
        val ua = (at(a1, y0, n0) - at(a0, y0, n0)).unit(); val va = UPV
        val out = (at(a0, y0, n0 + 1) - at(a0, y0, n0)).unit()
        val o = at(a0, y0, n0 + depth)
        for (i in 0 until nu) for (j in 0 until nv) face(p, listOf(grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]), o, ua, va, o, out)
        // the cushion's sides, from the board to its rolled front edge
        val mid = at(a0 + w0 / 2, y0 + h0 / 2, n0)
        fun back(q: V3) = q - out * ((q - mid).dot(out))
        val ring = (0 until nu).map { grid[it][0] } + (0 until nv).map { grid[nu][it] } + (nu downTo 1).map { grid[it][nv] } + (nv downTo 1).map { grid[0][it] }
        ring.indices.forEach { k ->
            val q0 = ring[k]; val q1 = ring[(k + 1) % ring.size]
            face(p, listOf(back(q0), back(q1), q1, q0), mid, (q1 - q0).unit(), out, o)
        }
        tuftButtons(w0, h0).forEach { (u, v) -> val zz = z(u, v); rod(btn, doubleArrayOf(a0 + u, y0 + v, zz - 3), doubleArrayOf(a0 + u, y0 + v, zz + 4), 7.0, 6.0, 8) }
    }

    /** A soft-edged slab (a table's top): the rounded rectangle [a0]..[a1] × [n0]..[n1] (corners [rc]) from [y0] to [y1], its top edge rounded [e]. */
    fun slab(p: Part, a0: Double, a1: Double, n0: Double, n1: Double, y0: Double, y1: Double, rc: Double, e: Double) {
        val k = 6
        fun outline(d: Double): List<DoubleArray> {
            val r = max(0.0, rc - d); val A0 = a0 + d; val A1 = a1 - d; val N0 = n0 + d; val N1 = n1 - d
            val cs = listOf(doubleArrayOf(A1 - r, N0 + r, -PI / 2), doubleArrayOf(A1 - r, N1 - r, 0.0), doubleArrayOf(A0 + r, N1 - r, PI / 2), doubleArrayOf(A0 + r, N0 + r, PI))
            return cs.flatMap { cc -> (0..k).map { s -> val t0 = cc[2] + PI / 2 * s / k; doubleArrayOf(cc[0] + r * cos(t0), cc[1] + r * sin(t0)) } }
        }
        val ee = min(e, (y1 - y0) * .45)
        val prof = listOf(0.0 to y0, 0.0 to y1 - ee) + (1..3).map { s -> val t0 = PI / 2 * s / 3; ee * (1 - cos(t0)) to (y1 - ee + ee * sin(t0)) }
        val rings = prof.map { (d, y) -> outline(d).map { at(it[0], y, it[1]) } }
        val inside = at((a0 + a1) / 2, (y0 + y1) / 2, (n0 + n1) / 2)
        val ua = (at(a1, y0, n0) - at(a0, y0, n0)).unit(); val va = (at(a0, y0, n1) - at(a0, y0, n0)).unit()
        val o = at(a0, y1, n0)
        for (r in 0 until rings.size - 1) {
            val lo = rings[r]; val hi = rings[r + 1]
            for (i in lo.indices) {
                val j = (i + 1) % lo.size
                if ((lo[j] - lo[i]).len() < 1e-7 && (hi[j] - hi[i]).len() < 1e-7) continue
                val q = if ((hi[j] - hi[i]).len() < 1e-7) listOf(lo[i], lo[j], hi[i]) else if ((lo[j] - lo[i]).len() < 1e-7) listOf(lo[i], hi[j], hi[i]) else listOf(lo[i], lo[j], hi[j], hi[i])
                face(p, q, inside, (q[1] - q[0]).unit().let { if (it.len() < .5) ua else it }, UPV, o)
            }
        }
        fun cap(ring: List<V3>) = ring.filterIndexed { i, q -> (q - ring[(i + ring.size - 1) % ring.size]).len() > 1e-7 }
        face(p, cap(rings.last()), inside, ua, va, o, UPV)
        face(p, cap(rings.first()).reversed(), inside, ua, va, o, UPV * -1.0)
    }
}

private val UPV = V3(0.0, 1.0, 0.0)
private fun cross(u: V3, v: V3) = V3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)

/* ---------------- the hooks Furniture3D.kt calls ---------------- */

/** An item box [m] in the lit 3D; false: drawn as before (the mirror over a dressing table, anything else). */
internal fun itemLit(B: Builder3, w: WallBasis, m: Module): Boolean {
    val pen = Pen(B, w, m.x.toDouble())
    when (m.type) {
        "bed" -> bed3D(B, pen, m)
        "bunk", "loft" -> bunk3D(B, pen, m)
        "table", "bar" -> table3D(B, pen, m)
        "hooks" -> hooks3D(B, pen, m)
        else -> return false
    }
    return true
}

/** A bathroom vanity's basin in the lit 3D: white ceramic with a bowl and a rounded rim, the tap in the handles' colour. */
internal fun basinLit(B: Builder3, w: WallBasis, m: Module): Boolean {
    val top = (m.elev + legsOf(m, B.ws) + m.h).toDouble()
    val mid = m.x + m.w / 2.0; val bw = minOf(500.0, m.w - 120.0); val bd = minOf(380.0, m.d - 80.0)
    if (bw < 200 || bd < 200) return true
    val n0 = (m.d - bd) / 2 + 20; val cn = n0 + bd / 2
    val pen = Pen(B, w, 0.0)
    val cer = B.lookPart(CERAMIC)
    val k = if (B.light) 3 else 6
    val H = 130.0; val R = minOf(70.0, bw / 4, bd / 4)
    fun ring(d: Double, y: Double): List<V3> {
        val r = max(1.0, R - d * .6); val A0 = mid - bw / 2 + d; val A1 = mid + bw / 2 - d; val N0 = n0 + d; val N1 = n0 + bd - d
        val cs = listOf(Triple(A1 - r, N0 + r, -PI / 2), Triple(A1 - r, N1 - r, 0.0), Triple(A0 + r, N1 - r, PI / 2), Triple(A0 + r, N0 + r, PI))
        return cs.flatMap { (ca, cc, t0) -> (0..k).map { s -> val t = t0 + PI / 2 * s / k; pen.at(ca + r * cos(t), y, cc + r * sin(t)) } }
    }
    // outside up to the rim, over it, and down into the bowl
    val prof = listOf(0.0 to top, 0.0 to top + H - 8, 3.0 to top + H - 1.5, 9.0 to top + H, 18.0 to top + H, 24.0 to top + H - 4, 42.0 to top + H - 55, 64.0 to top + H - 100, 78.0 to top + H - 112)
    val rings = prof.map { (d, y) -> ring(d, y) }
    val ua = pen.at(1.0, 0.0, 0.0) - pen.at(0.0, 0.0, 0.0); val va = pen.at(0.0, 0.0, 1.0) - pen.at(0.0, 0.0, 0.0)
    val o = pen.at(mid - bw / 2, top, n0)
    for (r in 0 until rings.size - 1) {
        val lo = rings[r]; val hi = rings[r + 1]
        // the outside faces away from the basin's middle, the rim up, the bowl in towards its middle
        val inner = prof[r].first >= 18.0
        for (i in lo.indices) {
            val j = (i + 1) % lo.size
            if ((lo[j] - lo[i]).len() < 1e-7) continue
            val q = listOf(lo[i], lo[j], hi[j], hi[i])
            val fc = (q[0] + q[1] + q[2] + q[3]) * .25
            val axis = pen.at(mid, fc.y * 1000, cn)
            val toward = if (inner) (axis - fc).unit() + UPV * .3 else if (prof[r].second == prof[r + 1].second) UPV else (fc - axis).unit()
            pen.face(cer, q, axis, ua.unit(), va.unit(), o, toward)
        }
    }
    pen.face(cer, rings.last(), pen.at(mid, top, cn), ua.unit(), va.unit(), o, UPV)
    if (!B.light) pen.rod(B.p("metal"), doubleArrayOf(mid, top + H - 112, cn), doubleArrayOf(mid, top + H - 111, cn), 18.0)
    // the tap behind the bowl: its base, the riser, the spout reaching over the bowl, the lever
    val fp = B.p("faucet"); val tn = n0 - 28
    pen.rod(fp, doubleArrayOf(mid, top, tn), doubleArrayOf(mid, top + 30, tn), 22.0)
    pen.rod(fp, doubleArrayOf(mid, top + 30, tn), doubleArrayOf(mid, top + 250, tn), 13.0, 11.0)
    pen.rod(fp, doubleArrayOf(mid, top + 245, tn - 6), doubleArrayOf(mid, top + 238, tn + 125), 11.0, 10.0)
    pen.rod(fp, doubleArrayOf(mid, top + 238, tn + 122), doubleArrayOf(mid, top + 222, tn + 128), 10.0, 9.0)
    pen.rod(fp, doubleArrayOf(mid, top + 200, tn - 8), doubleArrayOf(mid + 8, top + 262, tn - 40), 6.0, 5.0)
    return true
}

/* ---------------- beds ---------------- */

/**
 * A bed (mockup buildBed): its boards; on a plain bed on legs metal legs in the handles' metal or ([Look.legs] off) a
 * hidden black base set back under the frame; the upholstered headboard by [Look.head] in its fabric; the soft wall
 * panel ([Look.panel]) behind it in a lighter shade, a wood accent along its top and LED over that ([Look.led]) washing
 * the wall; the mattress, the duvet over its foot, a throw and pillows (the light tier: mattress and pillows only); a
 * lift-up bed's slats on their frame, rising with the mattress; the drawers in the fronts' style with handles.
 */
private fun bed3D(B: Builder3, P: Pen, m: Module) {
    val f = B.itemPiece; val l = f?.look; val ms = B.itemMats; val ws = B.ws
    val t = ws.t.toDouble(); val o = m.opt ?: Opt()
    val W = m.w.toDouble(); val D = m.d.toDouble(); val H = m.h.toDouble()
    val bs = itemBoards(m, ws)
    val head = l?.head ?: ""
    val hb = max(o.hb, m.h + 100).toDouble()
    val yp = H - BED_SINK
    val lift = o.bed == "lift"
    val liftKey = "${m.id}:lift"
    if (lift) B.keys += liftKey
    val th = if (lift) Math.toRadians(38.0) * B.how(liftKey) else 0.0
    val pivotY = (m.h - BED_SINK - 30).toDouble(); val pivotN = t + 4.0
    // the boards of the parts list as they are; the legs, the slats and the bedding drawn below
    bs.filter { it.role == "carcass" || it.role == "front" }.forEach { b -> P.board(B.role(if (b.role == "carcass") "carcass" else B.fr, b.key), b) }
    val legs = bs.filter { it.role == "metal" }
    if (legs.isNotEmpty()) {
        if (l?.legs == true) legs.forEach { b ->
            val ca = (b.a0 + b.a1) / 2.0; val cn = (b.n0 + b.n1) / 2.0
            P.rod(B.p("legs"), doubleArrayOf(ca, 0.0, cn), doubleArrayOf(ca, b.y1.toDouble(), cn), 14.0, 20.0)
        } else {
            val yb = legs.maxOf { it.y1 }.toDouble()
            P.box(B.lookPart(BED_BASE), t + 60, W - t - 60, 0.0, yb - 1, t + 60, D - t - 120)
        }
    }
    // the upholstered headboard over the frame's top, in front of the headboard board
    val fab = designLook(f, "fabric", ms)
    if (head.isNotEmpty() && hb - H > 100) {
        val y0 = H + 2; val hh = hb - y0; val n0 = t; val dd = HEAD_SOFT_D.toDouble()
        val fp = B.lookPart(fab)
        if (head == "tufted") { if (B.light) P.soft(fp, 0.0, W, y0, hb, n0, n0 + dd, 30.0, 1) else P.tufted(fp, fp, 0.0, W, y0, hb, n0, dd) }
        else softCells(head, W, hh).forEach { c ->
            val r = if (head == "vertical") min(dd * .48, (c.u1 - c.u0) * .45) else min(dd * .48, 35.0)
            P.soft(fp, c.u0, c.u1, y0 + c.v0, y0 + c.v1, n0, n0 + dd, r, if (B.light) 1 else 2)
        }
    }
    // the soft wall panel behind the bed (where the bed's back is at a wall), cut to the wall
    // (the same reach the price takes: Look.kt bedPanelReach, bedPanelOf)
    val panel = bedPanelReach(f?.pose, P.x0, P.w.len * 1000)?.let { (lo, hi) -> bedPanel(m, l?.panel == true, lo, hi) }
    if (panel != null) {
        val kind = wallPanelKind(head); val pd = t - 2
        val pp = B.lookPart(fab.copy(rgb = lighter(fab.rgb, .28)))
        softCells(kind, panel.u1 - panel.u0, panel.v1 - panel.v0).forEach { c ->
            val r = if (kind == "vertical") min(pd * .48, (c.u1 - c.u0) * .45) else min(pd * .48, 35.0)
            P.soft(pp, panel.u0 + c.u0, panel.u0 + c.u1, panel.v0 + c.v0, panel.v0 + c.v1, 0.0, pd, r, if (B.light) 1 else 2)
        }
        val acc = if (l?.accent.isNullOrEmpty()) B.role(B.fr) else B.lookPart(designLook(f, "accent", ms))
        P.box(acc, panel.u0 - 20, panel.u1 + 20, panel.v1, panel.v1 + 30, 0.0, 70.0, true)
        if (l?.led == true) {
            P.box(B.p("led"), panel.u0, panel.u1, panel.v1 + 30, panel.v1 + 36, 50.0, 62.0)
            // its light washing the wall over it, fading upwards (none on the light tier)
            if (!B.light) (0 until 8).forEach { i ->
                val b0 = panel.v1 + 36 + i * 70.0; val b1 = b0 + 70
                val q = listOf(P.at(panel.u0, b0, 4.0), P.at(panel.u1, b0, 4.0), P.at(panel.u1, b1, 4.0), P.at(panel.u0, b1, 4.0))
                B.flat(B.p("glow$i"), q, P.w.dir(0.0, 1.0))
            }
        }
    }
    // what rises with a lift-up base: its slats on their frame, the mattress and the bedding
    P.th = th; P.py = pivotY; P.pn = pivotN
    val lam = bs.firstOrNull { it.role == "lamel" }
    if (lam != null) {
        if (lift) {
            val st = B.p("metal"); val lp = B.p("lamel")
            val a0 = lam.a0.toDouble(); val a1 = lam.a1.toDouble(); val l0 = lam.n0.toDouble(); val l1 = lam.n1.toDouble()
            val y0 = lam.y0.toDouble(); val y1 = lam.y1.toDouble()
            P.box(st, a0, a0 + 30, y0, y1 - 8, l0, l1); P.box(st, a1 - 30, a1, y0, y1 - 8, l0, l1)
            P.box(st, a0 + 30, a1 - 30, y0, y1 - 8, l0, l0 + 30); P.box(st, a0 + 30, a1 - 30, y0, y1 - 8, l1 - 30, l1)
            val spine = o.mw >= 1400
            if (spine) P.box(st, W / 2 - 15, W / 2 + 15, y0, y1 - 8, l0 + 30, l1 - 30)
            val spans = if (spine) listOf(a0 + 4 to W / 2 - 4, W / 2 + 4 to a1 - 4) else listOf(a0 + 4 to a1 - 4)
            var n = l0 + 45
            while (n + 63 < l1 - 40) { spans.forEach { (s0, s1) -> P.box(lp, s0, s1, y1 - 8, y1, n, n + 63) }; n += 100 }
        } else P.board(B.p("lamel"), lam, false)
    }
    val ma0 = t + 6; val ma1 = W - t - 6
    val nb0 = t + 6 + (if (head.isNotEmpty() && hb - H > 100) HEAD_SOFT_D.toDouble() else 0.0); val nb1 = D - t - 6
    val my1 = yp + 200
    val fine = !B.light
    P.soft(B.p("mattress"), ma0, ma1, yp, my1, nb0, nb1, 45.0, if (fine) 3 else 1)
    if (fine) {
        P.soft(B.lookPart(DUVET), -6.0, W + 6, H + 4, my1 + 30, nb0 + (nb1 - nb0) * .38, D - t + 12, 60.0, 3)
        P.soft(B.lookPart(fab), -12.0, W + 12, H + 8, my1 + 45, D - t - 430, D - t + 20, 30.0, 3)
    }
    val two = o.mw >= 1200
    val pw = if (two) min(700.0, (ma1 - ma0 - 60) / 2) else min(700.0, ma1 - ma0 - 80)
    val cxs = if (two) listOf(W / 2 - pw / 2 - 15, W / 2 + pw / 2 + 15) else listOf(W / 2)
    val linen = B.lookPart(LINEN); val cush = B.lookPart(fab.copy(rgb = lighter(fab.rgb, .28)))
    cxs.forEach { cx ->
        // propped up against the headboard, their faces to the foot (the mockup's lean)
        P.soft(linen, cx - pw / 2, cx + pw / 2, my1 + 30, my1 + 190, nb0 + 10, nb0 + 470, 70.0, if (fine) 3 else 1, if (fine) .55 else 0.0)
        if (fine) { val c2 = W / 2 + (cx - W / 2) * .71; val cw = min(460.0, pw * .65)
            P.soft(cush, c2 - cw / 2, c2 + cw / 2, my1 + 20, my1 + 140, nb0 + 260, nb0 + 620, 50.0, 3, .45) }
    }
    P.th = 0.0
    if (lift) bs.firstOrNull { it.role == "mattress" }?.let { b ->
        B.picks += Pick(liftKey, Obb(P.at(b.a0.toDouble(), b.y0.toDouble(), b.n0.toDouble()), P.w.dir((b.a1 - b.a0) / 1000.0, 0.0), V3(0.0, (b.y1 - b.y0) / 1000.0, 0.0), P.w.dir(0.0, (b.n1 - b.n0) / 1000.0)))
    }
    // the drawers: each side's own frame, along the bed and out of that side (as the plain 3D)
    val w = P.w
    bedDrawers(m, ws).forEachIndexed { i, dr ->
        val right = dr.side > 0
        val o0 = w.at((P.x0 + if (right) m.w else 0) / 1000.0, 0.0, (if (right) m.d else 0) / 1000.0)
        val sb = if (right) WallBasis(o0.x, o0.z, -w.nx, -w.nz, w.ux, w.uz, m.d / 1000.0) else WallBasis(o0.x, o0.z, w.nx, w.nz, -w.ux, -w.uz, m.d / 1000.0)
        val a = if (right) m.d - dr.n1 else dr.n0
        B.drawer(sb, "${m.id}:bd$i", a.toDouble(), (dr.n1 - dr.n0).toDouble(), dr.y0.toDouble(), (dr.y1 - dr.y0).toDouble(), -t, dr.depth.toDouble(), hasHandle(m, "bd$i"))
    }
}

/**
 * A bunk or loft bed: its boards; the ladder and the upper guards in the wood accent (or, with [Look.legs], a ladder of
 * round tubes in the handles' metal); each level's mattress with a pillow and a duvet (the light tier: no duvet).
 */
private fun bunk3D(B: Builder3, P: Pen, m: Module) {
    val f = B.itemPiece; val l = f?.look; val ms = B.itemMats
    val bs = itemBoards(m, B.ws)
    val metal = l?.legs == true
    val wood = !l?.accent.isNullOrEmpty()
    val acc = if (wood) B.lookPart(designLook(f, "accent", ms)) else null
    // a board the parts list lights up stays in the highlight's colour
    fun lit(b: Board, alt: Part?): Part { val r = B.role(if (b.role == "carcass") "carcass" else B.fr, b.key); return if (alt == null || (B.hi != null && r === B.p("hi"))) r else alt }
    val fine = !B.light
    bs.forEach { b ->
        when {
            b.role == "carcass" || b.role == "front" -> when (b.key) {
                "fp.ladder", "fp.rung" -> if (metal) {
                    val p = lit(b, B.p("legs"))
                    val ca = (b.a0 + b.a1) / 2.0; val cn = (b.n0 + b.n1) / 2.0; val cy = (b.y0 + b.y1) / 2.0
                    if (b.key == "fp.ladder") P.rod(p, doubleArrayOf(ca, b.y0.toDouble(), cn), doubleArrayOf(ca, b.y1.toDouble(), cn), 16.0)
                    else P.rod(p, doubleArrayOf(b.a0 - 4.0, cy, cn), doubleArrayOf(b.a1 + 4.0, cy, cn), 12.0)
                } else P.board(lit(b, acc), b)
                "fp.guard" -> P.board(lit(b, acc), b)
                else -> P.board(lit(b, null), b)
            }
            b.role == "lamel" -> P.board(B.p("lamel"), b, false)
            b.role == "mattress" -> {
                P.soft(B.p("mattress"), b.a0.toDouble(), b.a1.toDouble(), b.y0.toDouble(), b.y1.toDouble(), b.n0.toDouble(), b.n1.toDouble(), 40.0, if (fine) 2 else 1)
                // the duvet over the mattress but the pillow's end
                val pil = bs.firstOrNull { it.role == "white" && it.y0 == b.y1 }
                if (fine && pil != null) {
                    val atLeft = pil.a0 - b.a0 < b.a1 - pil.a1
                    val d0 = if (atLeft) pil.a1 + 80.0 else b.a0 - 10.0; val d1 = if (atLeft) b.a1 + 10.0 else pil.a0 - 80.0
                    P.soft(B.lookPart(DUVET), d0, d1, b.y0 + 60.0, b.y1 + 28.0, b.n0 - 2.0, b.n1 + 4.0, 45.0, 2)
                }
            }
            b.role == "white" -> P.soft(B.lookPart(LINEN), b.a0 + 10.0, b.a1 - 10.0, b.y0 - 8.0, b.y1 + 20.0, b.n0.toDouble(), b.n1.toDouble(), 55.0, if (fine) 2 else 1)
            b.role == "metal" -> P.board(B.p("legs"), b, false)
            else -> P.board(B.p(b.role), b, false)
        }
    }
}

/* ---------------- tables and the bar counter ---------------- */

/**
 * A table or bar counter: its top one slab with a soft rounded edge (round corners where chosen) in its worktop's decor
 * (stone or wood, Look.kt worktopOf) or the fronts' board; its legs and frames in the handles' metal; a bar counter's
 * front in the fronts' style, its footrest a round rail.
 */
private fun table3D(B: Builder3, P: Pen, m: Module) {
    val bs = itemBoards(m, B.ws)
    val tops = bs.filter { it.role == "top" || it.key == "fp.top" || it.key == "fp.topR" }
    val legs = B.p("legs")
    bs.forEach { b ->
        if (b in tops) return@forEach
        when {
            b.role == "metal" -> {
                val sa = b.a1 - b.a0; val sy = b.y1 - b.y0; val sn = b.n1 - b.n0
                // a bar's footrest and its brackets are round; table legs and frames square tube
                if (m.type == "bar") {
                    val ca = (b.a0 + b.a1) / 2.0; val cy = (b.y0 + b.y1) / 2.0; val cn = (b.n0 + b.n1) / 2.0
                    if (sa >= sn) P.rod(legs, doubleArrayOf(b.a0.toDouble(), cy, cn), doubleArrayOf(b.a1.toDouble(), cy, cn), min(sy, sn) / 2.0)
                    else P.rod(legs, doubleArrayOf(ca, cy, b.n0.toDouble()), doubleArrayOf(ca, cy, b.n1.toDouble()), min(sa, sy) / 2.0)
                } else P.board(legs, b, false)
            }
            b.key == "fp.barFront" && B.style != "flat" && !B.bare -> {
                val e = P.w.dir(1.0, 0.0); val tn = P.w.dir(0.0, 1.0)
                B.styledFront(P.at(b.a0.toDouble(), b.y0.toDouble(), b.n0.toDouble()), e, tn, B.role(B.fr, b.key), (b.a1 - b.a0).toDouble(), (b.y1 - b.y0).toDouble(), UPV)
            }
            b.role == "carcass" || b.role == "front" -> P.board(B.role(if (b.role == "carcass") "carcass" else B.fr, b.key), b)
            else -> P.board(B.p(b.role), b, false)
        }
    }
    if (tops.isEmpty()) return
    val wt = tops.any { it.role == "top" }
    val p = if (wt) B.p("top") else B.role(B.fr, tops.first().key)
    val y0 = tops.minOf { it.y0 }.toDouble(); val y1 = tops.maxOf { it.y1 }.toDouble()
    val b = tops.first()
    P.slab(p, b.a0.toDouble(), b.a1.toDouble(), b.n0.toDouble(), b.n1.toDouble(), y0, y1, max(b.round.toDouble(), 3.0), if (wt) 6.0 else min(5.0, (y1 - y0) / 3))
}

/* ---------------- the mirror panel ---------------- */

/**
 * A hall's mirror panel: its board in the fronts' style (flat under a mirror), the mirror in its tint, J-shaped coat
 * hooks and the hat shelf's brackets in the handles' metal (steel when none is chosen).
 */
private fun hooks3D(B: Builder3, P: Pen, m: Module) {
    val bs = itemBoards(m, B.ws)
    val l = B.itemPiece?.look
    val hk = if (l == null || l.hcol.isEmpty()) B.p("metal") else B.p("handle")
    val mirror = bs.any { it.role == "mirror" }
    bs.forEach { b ->
        when {
            b.key == "fp.panel" && !mirror && B.style != "flat" ->
                B.styledFront(P.at(b.a0.toDouble(), b.y0.toDouble(), b.n0.toDouble()), P.w.dir(1.0, 0.0), P.w.dir(0.0, 1.0), B.role(B.fr, b.key), (b.a1 - b.a0).toDouble(), (b.y1 - b.y0).toDouble(), UPV)
            b.role == "mirror" -> P.board(B.p("mirror"), b)
            b.role == "metal" && b.n1 - b.n0 <= 70 -> {
                // a coat hook: its rosette on the panel, the arm out and down, the tip turned up
                val a = (b.a0 + b.a1) / 2.0; val y = b.y1 - 30.0; val n0 = b.n0.toDouble()
                P.rod(hk, doubleArrayOf(a, y, n0), doubleArrayOf(a, y, n0 + 6), 11.0)
                P.rod(hk, doubleArrayOf(a, y, n0 + 6), doubleArrayOf(a, y - 18, n0 + 46), 5.0)
                P.rod(hk, doubleArrayOf(a, y - 18, n0 + 46), doubleArrayOf(a, y + 2, n0 + 56), 5.0, 4.5)
            }
            b.role == "metal" -> P.board(hk, b, false)
            b.role == "carcass" || b.role == "front" -> P.board(B.role(if (b.role == "carcass") "carcass" else B.fr, b.key), b)
            else -> P.board(B.p(b.role), b, false)
        }
    }
}
