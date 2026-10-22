package uz.metrx.app.win

import uz.metrx.app.geo.Face
import uz.metrx.app.geo.Part
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.V3

/*
 * A product as boxes at its true size, seen in its own frame: [WBox.a] along the wall from its left edge (as seen from
 * inside), [WBox.d] into the room from the wall's inside face (negative: in the wall), [WBox.z] up from its bottom. A
 * window's frame and mullions (each split in an inside and an outside half for the two colours), its sashes' own
 * profile, the glass (see-through), the panels, the handles, the nets outside; the sill inside, the drip outside, the
 * reveals; a door's frame, its leaf (glass for a glass door, in front of the wall for a sliding one) and its handle.
 * The room's 3D and the gallery's pictures are both drawn from these boxes.
 */

/** A box of a product, mm in its own frame (see above); its colour and opacity; [glass] a pane. */
class WBox(val a0: Double, val a1: Double, val d0: Double, val d1: Double, val z0: Double, val z1: Double, val rgb: Int, val op: Float = 1f, val glass: Boolean = false)

const val GLASS_RGB = 0xA9C8EE
const val HANDLE_RGB = 0xE9EAE6
const val HANDLE_DARK = 0x5B6470
const val NET_RGB = 0x4B5563
const val SILL_RGB = 0xF7F7F4
const val DRIP_RGB = 0xD9DDE3

/** The boxes of [it] standing in a wall [t] thick (its frame [r] in from the inside face); [floor] in a door opening (no sill under it). */
fun productBoxes(it: WinItem, t: Int, floor: Boolean): List<WBox> {
    val out = ArrayList<WBox>()
    val D = frameDepth(it).toDouble(); val r = revealOf(t, frameDepth(it)).toDouble()
    val dIn = -r; val dOut = -r - D; val dMid = -r - D / 2
    val W = it.w.toDouble(); val H = it.h.toDouble()
    val cin = colourRgb(it.colIn); val cout = colourRgb(it.colOut)
    val handleRgb = if (it.colIn == "white") HANDLE_RGB else HANDLE_DARK
    /** A profile bar: the inside half in the inside colour, the outside half in the outside one. */
    fun bar(a0: Double, a1: Double, z0: Double, z1: Double, d0: Double = dOut, d1: Double = dIn) {
        val m = (d0 + d1) / 2
        out += WBox(a0, a1, m, d1, z0, z1, cin); out += WBox(a0, a1, d0, m, z0, z1, cout)
    }
    fun ring(x0: Double, y0: Double, x1: Double, y1: Double, f: Double, d0: Double, d1: Double) {
        bar(x0, x0 + f, y0, y1, d0, d1); bar(x1 - f, x1, y0, y1, d0, d1)
        bar(x0 + f, x1 - f, y0, y0 + f, d0, d1); bar(x0 + f, x1 - f, y1 - f, y1, d0, d1)
    }
    if (it.isDoor) {
        val F = DOOR_FRAME.toDouble()
        val dd0 = -r - D; val dd1 = -r
        out += WBox(0.0, F, dd0, dd1, 0.0, H, cin); out += WBox(W - F, W, dd0, dd1, 0.0, H, cin); out += WBox(F, W - F, dd0, dd1, H - F, H, cin)
        val left = it.hinge != "R"
        when (it.kind) {
            "dsl" -> {
                // the leaf hangs in front of the wall on its rail, closed over the opening
                out += WBox(-30.0, W + 30, 8.0, 48.0, 10.0, H + 10, cin)
                out += WBox(-40.0, 2 * W, 0.0, 60.0, H + 30, H + 80, DRIP_RGB)
                val hx = if (left) W - 20 else 20.0
                out += WBox(hx - 12, hx + 12, 48.0, 70.0, 900.0, 1100.0, HANDLE_DARK)
            }
            "dgl" -> {
                out += WBox(F + 2, W - F - 2, dIn - 34, dIn - 24, 10.0, H - F - 2, GLASS_RGB, .4f, true)
                out += WBox(F + 2, W - F - 2, dIn - 40, dIn - 18, 10.0, 90.0, colourRgb("silver")); out += WBox(F + 2, W - F - 2, dIn - 40, dIn - 18, H - F - 60, H - F - 2, colourRgb("silver"))
                val hx = if (left) W - F - 70 else F + 70
                out += WBox(hx - 12, hx + 12, dIn - 18, dIn + 40, 700.0, 1300.0, colourRgb("silver"))
            }
            else -> {
                val inSwing = it.swing == "in"
                val l0 = if (inSwing) dIn - 44 else dOut + 4; val l1 = l0 + 40
                out += WBox(F + 2, W - F - 2, l0, l1, 10.0, H - F - 2, cin)
                val hx = if (left) W - F - 70 else F + 70
                out += WBox(hx - 60, hx + 12, l1, l1 + 45, 990.0, 1015.0, if (it.kind == "dent") HANDLE_DARK else colourRgb("silver"))
                out += WBox(hx - 14, hx + 14, l1, l1 + 10, 940.0, 1060.0, if (it.kind == "dent") HANDLE_DARK else colourRgb("silver"))
            }
        }
        return out + extras(it, t, r, floor)
    }
    val F = frameF(it.profile).toDouble(); val M = mullF(it.profile) / 2.0; val S = sashF(it.profile).toDouble()
    ring(0.0, 0.0, W, H, F, dOut, dIn)
    barsOf(it).forEach { b -> if (b.vertical) bar(b.x0 - M, b.x0 + M, b.y0, b.y1) else bar(b.x0, b.x1, b.y0 - M, b.y0 + M) }
    for (s in sashesOf(it)) {
        val c = s.r
        when {
            s.t == "panel" -> out += WBox(c.x0, c.x1, dMid - 12, dMid + 12, c.y0, c.y1, cin)
            s.opens -> {
                // the sash's own profile inside its cell, standing a little into the room, and its glass
                val s0 = dIn - D * .55; val s1 = dIn + 8
                ring(c.x0, c.y0, c.x1, c.y1, S, s0, s1)
                out += WBox(c.x0 + S, c.x1 - S, (s0 + s1) / 2 - 4, (s0 + s1) / 2 + 4, c.y0 + S, c.y1 - S, GLASS_RGB, .35f, true)
                if (it.handles) {
                    val mid = (c.y0 + c.y1) / 2
                    when (s.t) {
                        "tilt" -> { val x = (c.x0 + c.x1) / 2; out += WBox(x - 70, x + 10, s1, s1 + 40, c.y1 - S / 2 - 12, c.y1 - S / 2 + 12, handleRgb) }
                        "slide" -> { val x = if (s.cell.hinge == "R") c.x0 + S / 2 else c.x1 - S / 2; out += WBox(x - 10, x + 10, s1, s1 + 30, mid - 90, mid + 90, handleRgb) }
                        else -> {
                            val x = if (s.cell.hinge == "R") c.x0 + S / 2 else c.x1 - S / 2
                            out += WBox(x - 12, x + 12, s1, s1 + 14, mid - 40, mid + 40, handleRgb)
                            out += WBox(x - 11, x + 11, s1 + 14, s1 + 50, mid - 130, mid - 20, handleRgb)
                        }
                    }
                }
                if (it.net) out += WBox(c.x0 + 10, c.x1 - 10, dOut - 10, dOut - 4, c.y0 + 10, c.y1 - 10, NET_RGB, .45f)
            }
            else -> out += WBox(c.x0, c.x1, dMid - 4, dMid + 4, c.y0, c.y1, GLASS_RGB, .35f, true)
        }
    }
    return out + extras(it, t, r, floor)
}

/** The sill (inside), the drip (outside) and the reveals of [it] in a wall [t] thick with its reveal [r]. */
private fun extras(it: WinItem, t: Int, r: Double, floor: Boolean): List<WBox> {
    val out = ArrayList<WBox>()
    val W = it.w.toDouble(); val H = it.h.toDouble(); val g = it.gap.toDouble()
    if (!it.isDoor && it.sill > 0 && !floor) out += WBox(-SILL_EAR.toDouble(), W + SILL_EAR, -r, it.sill - r, -22.0, -2.0, SILL_RGB)
    if (!it.isDoor && it.drip && !floor) out += WBox(-DRIP_EAR.toDouble(), W + DRIP_EAR, -t - 50.0, -r - frameDepth(it), -32.0, -18.0, DRIP_RGB)
    if (it.reveals) {
        val top = H + g; val bot = if (floor) 0.0 else -g
        out += WBox(-g, -g + 8, -r, 0.0, bot, top, SILL_RGB); out += WBox(W + g - 8, W + g, -r, 0.0, bot, top, SILL_RGB)
        out += WBox(-g, W + g, -r, 0.0, top - 8, top, SILL_RGB)
    }
    return out
}

/* ---------------- in the room's 3D ---------------- */

private class Parts { val map = LinkedHashMap<String, Part>()
    fun of(wall: String, rgb: Int, op: Float): Part = map.getOrPut("$wall|$rgb|$op") { Part(0, wall, Role.OPENING, rgb, op) }
}

/** The 3D of the products [pls] in room [c]; the plan's corner at ([dx], [dz]) metres in the scene. */
fun winParts(c: WCtx, pls: List<Placed>, dx: Double, dz: Double): List<Part> {
    val ps = Parts()
    for (pl in pls) {
        val w = pl.w
        fun at(a: Double, d: Double, z: Double): V3 { val q = w.at(pl.a0 + a, d); return V3(q.x / 1000 + dx, (pl.z0 + z) / 1000, q.y / 1000 + dz) }
        val n = V3(w.nIn.x, 0.0, w.nIn.y); val tt = V3(w.t.x, 0.0, w.t.y); val up = V3(0.0, 1.0, 0.0)
        for (b in productBoxes(pl.it, c.T, pl.doorOpening)) {
            if (b.a1 - b.a0 < .5 || b.d1 - b.d0 < .5 || b.z1 - b.z0 < .5) continue
            val f = ps.of(w.id, b.rgb, b.op).faces
            f += Face(n, listOf(at(b.a0, b.d1, b.z0), at(b.a1, b.d1, b.z0), at(b.a1, b.d1, b.z1), at(b.a0, b.d1, b.z1)))
            f += Face(n * -1.0, listOf(at(b.a0, b.d0, b.z0), at(b.a0, b.d0, b.z1), at(b.a1, b.d0, b.z1), at(b.a1, b.d0, b.z0)))
            f += Face(up, listOf(at(b.a0, b.d0, b.z1), at(b.a0, b.d1, b.z1), at(b.a1, b.d1, b.z1), at(b.a1, b.d0, b.z1)))
            f += Face(up * -1.0, listOf(at(b.a0, b.d0, b.z0), at(b.a1, b.d0, b.z0), at(b.a1, b.d1, b.z0), at(b.a0, b.d1, b.z0)))
            f += Face(tt * -1.0, listOf(at(b.a0, b.d0, b.z0), at(b.a0, b.d1, b.z0), at(b.a0, b.d1, b.z1), at(b.a0, b.d0, b.z1)))
            f += Face(tt, listOf(at(b.a1, b.d0, b.z0), at(b.a1, b.d0, b.z1), at(b.a1, b.d1, b.z1), at(b.a1, b.d1, b.z0)))
        }
    }
    return ps.map.values.toList()
}
