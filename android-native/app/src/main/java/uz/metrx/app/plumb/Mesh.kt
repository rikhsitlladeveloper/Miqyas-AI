package uz.metrx.app.plumb

import uz.metrx.app.geo.Face
import uz.metrx.app.geo.Part
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.V3
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/*
 * The fixtures, riser and pipes in 3D: each fixture as a few plain boxes at its true size against its wall (a toilet's
 * bowl and cistern, a basin over its cabinet, a bath with its tub, a shower tray with its glass, a sink in its cabinet,
 * the machines with their doors, a heater's cylinder, a radiator's sections), the riser's pipes with the meters, every
 * pipe as a thin strip in its colour along the walls (or on the floor), the underfloor loops on the floor. Faces of one
 * colour go into one part, so a room is a few dozen meshes.
 */

const val CERAMIC = 0xF8FAFC
const val SEAT = 0xE8EDF3
const val CAB = 0xE7DCCB
const val CHROME = 0x94A3B8
const val TUB = 0xDCEBFA
const val GLASS_RGB = 0xBFDBFE
const val DARK = 0x475569

private class Parts { val map = LinkedHashMap<String, Part>()
    fun of(wall: String?, rgb: Int, role: Role, op: Float = 1f): Part = map.getOrPut("$wall|$rgb|$role|$op") { Part(0, wall, role, rgb, op, tile = true) }
}

/** Where plan point [q] (mm) at [z] mm up is in the scene, the plan's corner at ([dx], [dz]) metres. */
private class Sc(val dx: Double, val dz: Double) { fun at(q: V2, z: Double) = V3(q.x / 1000 + dx, z / 1000, q.y / 1000 + dz) }

/** A box against wall [w]: [a0]…[a1] along it, [d0]…[d1] into the room, [z0]…[z1] up (mm). Its back is left out unless [back]. */
private fun box(p: Part, s: Sc, w: TWall, a0: Double, a1: Double, d0: Double, d1: Double, z0: Double, z1: Double, back: Boolean = false) {
    fun pt(a: Double, d: Double, z: Double) = s.at(w.at(a, d), z)
    val n = V3(w.nIn.x, 0.0, w.nIn.y); val t = V3(w.t.x, 0.0, w.t.y)
    p.faces += Face(n, listOf(pt(a0, d1, z0), pt(a1, d1, z0), pt(a1, d1, z1), pt(a0, d1, z1)))
    p.faces += Face(V3(0.0, 1.0, 0.0), listOf(pt(a0, d0, z1), pt(a0, d1, z1), pt(a1, d1, z1), pt(a1, d0, z1)))
    if (z0 > 1) p.faces += Face(V3(0.0, -1.0, 0.0), listOf(pt(a0, d0, z0), pt(a1, d0, z0), pt(a1, d1, z0), pt(a0, d1, z0)))
    p.faces += Face(t * -1.0, listOf(pt(a0, d0, z0), pt(a0, d1, z0), pt(a0, d1, z1), pt(a0, d0, z1)))
    p.faces += Face(t, listOf(pt(a1, d0, z0), pt(a1, d0, z1), pt(a1, d1, z1), pt(a1, d1, z0)))
    if (back) p.faces += Face(n * -1.0, listOf(pt(a0, d0, z0), pt(a0, d0, z1), pt(a1, d0, z1), pt(a1, d0, z0)))
}

/** An upright cylinder (a water heater) at plan point [q], radius [r] mm, [z0]…[z1] up. */
private fun cyl(p: Part, s: Sc, q: V2, r: Double, z0: Double, z1: Double, n: Int = 12) {
    val ring = (0 until n).map { i -> val a = 2 * PI * i / n; V2(q.x + r * cos(a), q.y + r * sin(a)) }
    p.faces += Face(V3(0.0, 1.0, 0.0), ring.map { s.at(it, z1) }.reversed())
    p.faces += Face(V3(0.0, -1.0, 0.0), ring.map { s.at(it, z0) })
    for (i in 0 until n) {
        val a = ring[i]; val b = ring[(i + 1) % n]
        val mx = (a.x + b.x) / 2 - q.x; val my = (a.y + b.y) / 2 - q.y; val l = hypot(mx, my)
        p.faces += Face(V3(mx / l, 0.0, my / l), listOf(s.at(a, z0), s.at(b, z0), s.at(b, z1), s.at(a, z1)))
    }
}

/** A flat round face standing [d] into the room from wall [w] at [a] along it and [z] up (a machine's door). */
private fun ring(p: Part, s: Sc, w: TWall, a: Double, z: Double, d: Double, r: Double, n: Int = 12) {
    val pts = (0 until n).map { i -> val t = 2 * PI * i / n; s.at(w.at(a + r * cos(t), d), z + r * sin(t)) }
    p.faces += Face(V3(w.nIn.x, 0.0, w.nIn.y), pts.reversed())
}

/** Fixture [f]'s boxes in room [c]. */
private fun fixParts(ps: Parts, s: Sc, c: PCtx, f: PlFix) {
    val w = c.wall(f.wall) ?: return
    val x = f.off.toDouble(); val fw = fixW(f).toDouble(); val fd = fixD(f).toDouble(); val ty = fixType(f.t)
    val a0 = x - fw / 2; val a1 = x + fw / 2
    val white = ps.of(null, CERAMIC, Role.FURN)
    when (f.t) {
        "wc" -> {
            box(white, s, w, x - 170, x + 170, 160.0, fd - 40, 0.0, 400.0)
            box(ps.of(null, SEAT, Role.FURN), s, w, x - 180, x + 180, 180.0, fd, 400.0, 430.0)
            box(white, s, w, x - 190, x + 190, 0.0, 170.0, 400.0, ty.h.toDouble())
            box(ps.of(null, CHROME, Role.FURN), s, w, x - 30, x + 30, 60.0, 110.0, ty.h.toDouble(), ty.h + 6.0)
        }
        "bs", "bsm" -> {
            val top = ty.h.toDouble()
            box(white, s, w, a0, a1, 0.0, fd, top - 160, top)
            box(ps.of(null, TUB, Role.FURN), s, w, a0 + 60, a1 - 60, 60.0, fd - 60, top - 4, top + 1)
            box(ps.of(null, CHROME, Role.FURN), s, w, x - 15, x + 15, 60.0, 120.0, top + 1, top + 140)
            if (f.opt == "cab") box(ps.of(null, CAB, Role.FURN), s, w, a0 + 10, a1 - 10, 20.0, fd - 20, 0.0, top - 160)
            else box(ps.of(null, CHROME, Role.FURN), s, w, x - 25, x + 25, 40.0, 100.0, 480.0, top - 160)
        }
        "bath" -> {
            box(white, s, w, a0, a1, 0.0, fd, 0.0, ty.h.toDouble())
            box(ps.of(null, TUB, Role.FURN), s, w, a0 + 70, a1 - 70, 70.0, fd - 70, ty.h - 4.0, ty.h + 1.0)
        }
        "sh", "cab" -> {
            box(white, s, w, a0, a1, 0.0, fd, 0.0, 150.0)
            box(ps.of(null, TUB, Role.FURN), s, w, a0 + 50, a1 - 50, 50.0, fd - 50, 146.0, 151.0)
            if (f.t == "cab") {
                val g = ps.of(null, GLASS_RGB, Role.FURN, .35f)
                box(g, s, w, a0, a1, fd - 8, fd, 150.0, ty.h.toDouble())
                box(g, s, w, a1 - 8, a1, 0.0, fd, 150.0, ty.h.toDouble())
                box(ps.of(null, CHROME, Role.FURN), s, w, a0, a1, fd - 12, fd, ty.h - 30.0, ty.h.toDouble())
            }
            box(ps.of(null, CHROME, Role.FURN), s, w, x - 50, x + 50, 0.0, 140.0, 1900.0, 1920.0)
        }
        "sink" -> {
            box(ps.of(null, CAB, Role.FURN), s, w, a0, a1, 0.0, fd - 30, 0.0, 820.0)
            box(ps.of(null, 0xCBD5E1, Role.FURN), s, w, a0, a1, 0.0, fd, 820.0, 850.0)
            box(ps.of(null, 0x9CA3AF, Role.FURN), s, w, x - 250, x + 250, 100.0, fd - 100, 846.0, 851.0)
            box(ps.of(null, CHROME, Role.FURN), s, w, x - 15, x + 15, 40.0, 90.0, 851.0, 1100.0)
        }
        "wm", "dw" -> {
            box(white, s, w, a0, a1, 0.0, fd, 0.0, ty.h.toDouble())
            if (f.t == "wm") { ring(ps.of(null, CHROME, Role.FURN), s, w, x, 430.0, fd + 1, 210.0); ring(ps.of(null, DARK, Role.FURN), s, w, x, 430.0, fd + 2, 150.0) }
            else box(ps.of(null, CHROME, Role.FURN), s, w, a0 + 60, a1 - 60, fd, fd + 15, ty.h - 70.0, ty.h - 50.0)
        }
        "wh" -> cyl(white, s, w.at(x, fd / 2), fd / 2, ty.z0.toDouble(), ty.h.toDouble())
        "gb" -> {
            box(white, s, w, a0, a1, 0.0, fd, ty.z0.toDouble(), ty.h.toDouble())
            box(ps.of(null, DARK, Role.FURN), s, w, x - 80, x + 80, fd, fd + 3, ty.h - 200.0, ty.h - 150.0)
        }
        "rad" -> {
            val n = (fw / SEC_MM).toInt().coerceAtLeast(1); val sw = fw / n
            for (i in 0 until n) box(white, s, w, a0 + i * sw + 4, a0 + (i + 1) * sw - 4, 10.0, fd, ty.z0.toDouble(), ty.h.toDouble())
        }
        "tr" -> {
            val ch = ps.of(null, CHROME, Role.FURN)
            box(ch, s, w, a0, a0 + 25, 50.0, 80.0, ty.z0.toDouble(), ty.h.toDouble()); box(ch, s, w, a1 - 25, a1, 50.0, 80.0, ty.z0.toDouble(), ty.h.toDouble())
            for (i in 0 until 6) { val z = ty.z0 + 60.0 + i * (ty.h - ty.z0 - 120.0) / 5; box(ch, s, w, a0, a1, 55.0, 75.0, z, z + 18) }
        }
        "manif" -> {
            box(ps.of(null, 0xE2E8F0, Role.FURN), s, w, a0, a1, 0.0, fd, ty.z0.toDouble(), ty.h.toDouble())
            box(ps.of(null, kindRgb("hs"), Role.FURN), s, w, a0 + 40, a1 - 40, fd, fd + 25, 650.0, 680.0)
            box(ps.of(null, kindRgb("hr"), Role.FURN), s, w, a0 + 40, a1 - 40, fd, fd + 25, 450.0, 480.0)
        }
        else -> box(white, s, w, a0, a1, 0.0, fd, ty.z0.toDouble(), ty.h.toDouble())
    }
}

/** The riser's pipes up the wall, its meters, filters and main valves. */
private fun riserParts(ps: Parts, s: Sc, c: PCtx, r: PlRiser) {
    val w = c.wall(r.wall) ?: return
    val x = r.off.toDouble(); val H = c.g.H
    box(ps.of(null, kindRgb("drain"), Role.FURN), s, w, x - 110, x, 30.0, 140.0, 0.0, H)
    val ks = if (r.hot) listOf("cold" to x + 40, "hot" to x + 100) else listOf("cold" to x + 40)
    ks.forEach { (k, a) ->
        box(ps.of(null, kindRgb(k), Role.FURN), s, w, a - 16, a + 16, 40.0, 72.0, 0.0, H)
        box(ps.of(null, 0xE5E7EB, Role.FURN), s, w, a - 30, a + 30, 30.0, 110.0, 760.0, 860.0)      // the meter
        box(ps.of(null, DARK, Role.FURN), s, w, a - 22, a + 22, 30.0, 100.0, 620.0, 690.0)          // the filter
        box(ps.of(null, 0xDC2626, Role.FURN), s, w, a - 8, a + 60, 72.0, 90.0, 960.0, 975.0)        // the valve's lever
    }
}

/** A pipe's strip: along the wall's face (on the floor when it lies there), [half] its half width. */
private fun strip(p: Part, s: Sc, g: PSeg, w: TWall?, half: Double) {
    if (g.len < 1) return
    val floor = g.za <= 80 && g.zb <= 80 && abs(g.za - g.zb) < 30
    if (w == null || floor) {
        val dx = g.b.x - g.a.x; val dy = g.b.y - g.a.y; val l = hypot(dx, dy)
        if (l < 1) return
        val nx = -dy / l * half; val ny = dx / l * half
        val q = listOf(V2(g.a.x + nx, g.a.y + ny), V2(g.b.x + nx, g.b.y + ny), V2(g.b.x - nx, g.b.y - ny), V2(g.a.x - nx, g.a.y - ny))
        p.faces += Face(V3(0.0, 1.0, 0.0), listOf(s.at(q[0], g.za + 2), s.at(q[3], g.za + 2), s.at(q[2], g.zb + 2), s.at(q[1], g.zb + 2)))
        p.faces += Face(V3(0.0, -1.0, 0.0), listOf(s.at(q[0], g.za + 2), s.at(q[1], g.zb + 2), s.at(q[2], g.zb + 2), s.at(q[3], g.za + 2)))
        return
    }
    val n = V3(w.nIn.x, 0.0, w.nIn.y)
    val vertical = abs(g.za - g.zb) > 1 && hypot(g.b.x - g.a.x, g.b.y - g.a.y) < 1
    val pts = if (vertical) listOf(s.at(V2(g.a.x - w.t.x * half, g.a.y - w.t.y * half), g.za), s.at(V2(g.a.x + w.t.x * half, g.a.y + w.t.y * half), g.za),
            s.at(V2(g.b.x + w.t.x * half, g.b.y + w.t.y * half), g.zb), s.at(V2(g.b.x - w.t.x * half, g.b.y - w.t.y * half), g.zb))
        else listOf(s.at(g.a, g.za - half), s.at(g.b, g.zb - half), s.at(g.b, g.zb + half), s.at(g.a, g.za + half))
    p.faces += Face(n, pts)
}

/** A pipe's strip half width, mm: its diameter, a little thicker so it reads. */
fun pipeHalf(kind: String, dia: Int) = if (kind == "drain") dia / 2.0 else 12.0

/**
 * The 3D of room [c]'s fixtures [fs], outlets [pts], the riser [rs] when in it, the routes [runs] and the underfloor
 * loops [loop] (with its spacing); the plan's corner at ([dx], [dz]) metres in the scene.
 */
fun plumbParts(c: PCtx, fs: List<PlFix>, pts: List<APt>, rs: PlRiser?, runs: List<PRun>, loop: PLoop?, dx: Double, dz: Double): List<Part> {
    val ps = Parts(); val s = Sc(dx, dz)
    fs.forEach { fixParts(ps, s, c, it) }
    if (rs != null && rs.roomId == c.id) riserParts(ps, s, c, rs)
    // the outlets: a small coloured plate on the wall
    for (q in pts) {
        val w = c.wall(q.wall) ?: continue
        box(ps.of(w.id, kindRgb(q.t), Role.OPENING), s, w, q.off - 22.0, q.off + 22.0, 0.0, 26.0, q.h - 22.0, q.h + 22.0)
    }
    for (r in runs) {
        val half = pipeHalf(r.kind, r.dia)
        for (g in r.segs) strip(ps.of(g.wall, kindRgb(r.kind), Role.OPENING), s, g, c.wall(g.wall), half)
    }
    if (loop != null && loop.n > 0) {
        val p = ps.of(null, UFH_RGB, Role.FURN)
        for (k in 0 until loop.n) snake(c, loop.step, k, loop.n).forEach { (a, b) -> strip(p, s, PSeg(a, 6.0, b, 6.0, null), null, 8.0) }
    }
    return ps.map.values.toList()
}
