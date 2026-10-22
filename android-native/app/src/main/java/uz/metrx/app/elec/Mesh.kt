package uz.metrx.app.elec

import uz.metrx.app.geo.Face
import uz.metrx.app.geo.Part
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.V3
import uz.metrx.app.tiles.V2
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/*
 * The devices and routes in 3D: each device at its true height and size on its wall (a plate with its circuit's colour
 * on it) or on the ceiling (a disc), the panel, and every circuit's cable as a thin coloured strip along the walls and
 * over the ceiling. Faces of one colour on one wall go into one part, so a room is a few dozen meshes, and a wall's
 * devices fade with it when it faces the camera.
 */

/** Device plates and light colours. */
const val PLATE = 0xF8FAFC
const val SW_PLATE = 0xE8EDF3
const val LIGHT_RGB = 0xFDE68A
const val LED_RGB = 0xFACC15
const val BOX_RGB = 0x94A3B8
const val PANEL_RGB = 0xCBD5E1

private class Parts { val map = LinkedHashMap<String, Part>()
    fun of(wall: String?, rgb: Int, role: Role): Part = map.getOrPut("$wall|$rgb|$role") { Part(0, wall, role, rgb, 1f, tile = true) }
}

/** Where plan point [q] (mm) at [z] mm up is in the scene, the plan's corner at ([dx], [dz]) metres. */
private class Sc(val dx: Double, val dz: Double) { fun at(q: V2, z: Double) = V3(q.x / 1000 + dx, z / 1000, q.y / 1000 + dz) }

/** A box standing out of a wall: [a0]…[a1] along it, [b0]…[b1] up (mm), [d0]…[d1] metres into the room; its back is the wall. */
private fun wallBox(p: Part, s: Sc, o: V2, t: V2, n: V2, a0: Double, a1: Double, b0: Double, b1: Double, d0: Double, d1: Double) {
    fun pt(a: Double, b: Double, d: Double) = s.at(V2(o.x + t.x * a + n.x * d * 1000, o.y + t.y * a + n.y * d * 1000), b)
    val nn = V3(n.x, 0.0, n.y); val tt = V3(t.x, 0.0, t.y)
    p.faces += Face(nn, listOf(pt(a0, b0, d1), pt(a1, b0, d1), pt(a1, b1, d1), pt(a0, b1, d1)))
    p.faces += Face(V3(0.0, 1.0, 0.0), listOf(pt(a0, b1, d0), pt(a0, b1, d1), pt(a1, b1, d1), pt(a1, b1, d0)))
    p.faces += Face(V3(0.0, -1.0, 0.0), listOf(pt(a0, b0, d0), pt(a1, b0, d0), pt(a1, b0, d1), pt(a0, b0, d1)))
    p.faces += Face(tt * -1.0, listOf(pt(a0, b0, d0), pt(a0, b0, d1), pt(a0, b1, d1), pt(a0, b1, d0)))
    p.faces += Face(tt, listOf(pt(a1, b0, d0), pt(a1, b1, d0), pt(a1, b1, d1), pt(a1, b0, d1)))
}

/** A flat disc under the ceiling at plan point [q], [r] mm across radius, [z0]…[z1] mm up: seen from below and from above. */
private fun disc(p: Part, s: Sc, q: V2, r: Double, z0: Double, z1: Double, n: Int = 10) {
    val ring = (0 until n).map { i -> val a = 2 * PI * i / n; V2(q.x + r * cos(a), q.y + r * sin(a)) }
    p.faces += Face(V3(0.0, 1.0, 0.0), ring.map { s.at(it, z1) }.reversed())
    p.faces += Face(V3(0.0, -1.0, 0.0), ring.map { s.at(it, z0) })
    for (i in 0 until n) {
        val a = ring[i]; val b = ring[(i + 1) % n]
        val mx = (a.x + b.x) / 2 - q.x; val my = (a.y + b.y) / 2 - q.y; val l = hypot(mx, my)
        p.faces += Face(V3(mx / l, 0.0, my / l), listOf(s.at(a, z0), s.at(b, z0), s.at(b, z1), s.at(a, z1)))
    }
}

/** The 3D of room [c]'s devices [ds], the panel [pn] when in it, and the routes [runs]; the plan's corner at ([dx], [dz]) metres in the scene. */
fun elecParts(c: ECtx, ds: List<ElecDev>, pn: ElecPanel?, runs: List<CRun>, dx: Double, dz: Double, circuitOf: (String) -> Circuit?): List<Part> {
    val ps = Parts(); val s = Sc(dx, dz)
    val H = c.g.H
    for (d in ds) {
        val ty = devType(d.t)
        val col = circuitOf(d.id)?.rgb ?: BOX_RGB
        if (d.onCeiling) {
            val q = V2(d.cx.toDouble(), d.cy.toDouble())
            when (d.t) {
                "ls" -> { disc(ps.of(null, PLATE, Role.FURN), s, q, 48.0, H - 8, H - 2, 8); disc(ps.of(null, LIGHT_RGB, Role.FURN), s, q, 30.0, H - 10, H - 7, 8) }
                "lch" -> {
                    disc(ps.of(null, PLATE, Role.FURN), s, q, 60.0, H - 25, H - 2, 8)
                    disc(ps.of(null, 0x94A3B8, Role.FURN), s, q, 10.0, H - 420, H - 25, 6)
                    disc(ps.of(null, LIGHT_RGB, Role.FURN), s, q, ty.dw / 2.0, H - 560, H - 420, 12)
                }
                else -> { disc(ps.of(null, PLATE, Role.FURN), s, q, ty.dw / 2.0, H - 40, H - 2, 12); disc(ps.of(null, LIGHT_RGB, Role.FURN), s, q, ty.dw / 2.0 - 30, H - 44, H - 40, 12) }
            }
            continue
        }
        val w = c.wall(d.wall) ?: continue
        val (dw, dh) = devSize(d)
        val a0 = d.off - dw / 2.0; val a1 = d.off + dw / 2.0; val b0 = d.h - dh / 2.0; val b1 = d.h + dh / 2.0
        when {
            d.t == "led" -> wallBox(ps.of(w.id, LED_RGB, Role.OPENING), s, w.p0, w.t, w.nIn, a0, a1, b0, b1, 0.0, .012)
            d.t == "lw" -> { wallBox(ps.of(w.id, PLATE, Role.OPENING), s, w.p0, w.t, w.nIn, a0, a1, b0, b1, 0.0, .05); wallBox(ps.of(w.id, LIGHT_RGB, Role.OPENING), s, w.p0, w.t, w.nIn, a0 + 20, a1 - 20, b0 - 4, b0, .005, .045) }
            ty.cat == "box" -> wallBox(ps.of(w.id, BOX_RGB, Role.OPENING), s, w.p0, w.t, w.nIn, a0, a1, b0, b1, 0.0, .01)
            else -> {
                val plate = if (ty.cat == "sw") SW_PLATE else PLATE
                val dep = if (ty.cat == "sock" && ty.group != "sock") .025 else .014
                wallBox(ps.of(w.id, plate, Role.OPENING), s, w.p0, w.t, w.nIn, a0, a1, b0, b1, 0.0, dep)
                // the circuit's colour on the plate
                val m = minOf(dw, dh) * .22
                wallBox(ps.of(w.id, col, Role.OPENING), s, w.p0, w.t, w.nIn, d.off - m, d.off + m, d.h - m, d.h + m, dep, dep + .003)
            }
        }
    }
    if (pn != null && pn.roomId == c.id) c.wall(pn.wall)?.let { w ->
        val (pw, ph) = panelSize(0)
        val a0 = pn.off - pw / 2.0; val a1 = pn.off + pw / 2.0; val b0 = pn.h - ph / 2.0; val b1 = pn.h + ph / 2.0
        wallBox(ps.of(w.id, PANEL_RGB, Role.OPENING), s, w.p0, w.t, w.nIn, a0, a1, b0, b1, 0.0, .1)
        wallBox(ps.of(w.id, 0x64748B, Role.OPENING), s, w.p0, w.t, w.nIn, a0 + 20, a1 - 20, pn.h - 4.0, pn.h + 4.0, .1, .104)
    }
    // the routes: 16 mm strips just off the walls and under the ceiling
    for (r in runs) {
        val rgb = r.circuit.rgb
        for (g in r.segs) {
            if (g.len < 1) continue
            if (g.wall == null) {
                val dxp = g.b.x - g.a.x; val dyp = g.b.y - g.a.y; val l = hypot(dxp, dyp)
                val nx = -dyp / l * 8; val ny = dxp / l * 8
                val q = listOf(V2(g.a.x + nx, g.a.y + ny), V2(g.b.x + nx, g.b.y + ny), V2(g.b.x - nx, g.b.y - ny), V2(g.a.x - nx, g.a.y - ny))
                val p = ps.of(null, rgb, Role.FURN)
                p.faces += Face(V3(0.0, -1.0, 0.0), q.map { s.at(it, g.za) })
                p.faces += Face(V3(0.0, 1.0, 0.0), q.map { s.at(it, g.za) }.reversed())
                continue
            }
            val w = c.wall(g.wall) ?: continue
            val n = V3(w.nIn.x, 0.0, w.nIn.y)
            val vertical = kotlin.math.abs(g.za - g.zb) > 1
            val p = ps.of(w.id, rgb, Role.OPENING)
            val pts = if (vertical) listOf(s.at(V2(g.a.x - w.t.x * 8, g.a.y - w.t.y * 8), g.za), s.at(V2(g.a.x + w.t.x * 8, g.a.y + w.t.y * 8), g.za),
                    s.at(V2(g.b.x + w.t.x * 8, g.b.y + w.t.y * 8), g.zb), s.at(V2(g.b.x - w.t.x * 8, g.b.y - w.t.y * 8), g.zb))
                else listOf(s.at(g.a, g.za - 8), s.at(g.b, g.zb - 8), s.at(g.b, g.zb + 8), s.at(g.a, g.za + 8))
            p.faces += Face(n, pts)
        }
    }
    return ps.map.values.toList()
}
