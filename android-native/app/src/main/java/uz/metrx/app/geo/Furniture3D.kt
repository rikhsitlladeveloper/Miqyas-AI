package uz.metrx.app.geo

import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.ISLAND
import uz.metrx.app.furniture.K_BASE_D
import uz.metrx.app.furniture.K_TOP
import uz.metrx.app.furniture.Module
import uz.metrx.app.furniture.PLINTH
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.blockH
import uz.metrx.app.furniture.fillOf
import uz.metrx.app.furniture.frontSizes
import uz.metrx.app.furniture.isUpper
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.wardBase
import uz.metrx.app.furniture.wardInner
import uz.metrx.app.furniture.worktopTop
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/*
 * Furniture in the room's 3D scene (furniture plan section 9): every board a box in its material's colour, on its
 * wall's frame ([WallBasis]). Doors swing open about 100°, drawers pull out; [Furn3D.picks] are what a tap can open.
 * Plain colours until Stage 3. Sizes come in millimetres and go out in metres.
 */

/** A box with corner [o] and edges [a], [b], [c] (perpendicular, not necessarily unit length). */
class Obb(val o: V3, val a: V3, val b: V3, val c: V3) {
    fun corners(): List<V3> = listOf(o, o + a, o + a + c, o + c, o + b, o + a + b, o + a + b + c, o + b + c)

    /** Where a ray from [e] along [d] first enters the box (its distance), or null. */
    fun hit(e: V3, d: V3): Double? {
        var t0 = 0.0; var t1 = Double.MAX_VALUE
        for (ax in listOf(a, b, c)) {
            val l2 = ax.dot(ax); if (l2 < 1e-12) return null
            // the box is 0..1 along each edge: (p - o)·ax / |ax|²
            val p = (e - o).dot(ax) / l2; val v = d.dot(ax) / l2
            if (kotlin.math.abs(v) < 1e-12) { if (p < 0 || p > 1) return null; continue }
            var ta = (0 - p) / v; var tb = (1 - p) / v
            if (ta > tb) { val x = ta; ta = tb; tb = x }
            t0 = max(t0, ta); t1 = min(t1, tb); if (t0 > t1) return null
        }
        return t0
    }
}

/** Something a tap opens: a door or a drawer ([key]), where it is now. */
class Pick(val key: String, val box: Obb)

class Furn3D(val parts: List<Part>, val edges: List<Edges>, val picks: List<Pick>, val keys: List<String>)

private const val METAL = 0xC5CBD4
private const val DARK = 0x1E293B
private const val HANDLE = 0x4B5563
private const val WHITE = 0xE8EAEE
private const val OPEN_DEG = 100.0
private const val MIRROR = 0xC9D3DD
private const val GLASS_P = 0x8FA9C4

/** The faces of a box, each facing out. */
private fun obbFaces(p: Part, x: Obb) {
    val ctr = x.o + (x.a + x.b + x.c) * .5
    fun face(q: List<V3>) {
        val fc = V3(q.sumOf { it.x } / 4, q.sumOf { it.y } / 4, q.sumOf { it.z } / 4)
        var n = (q[1] - q[0]).let { u -> (q[3] - q[0]).let { v -> V3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x) } }.unit()
        if (n.dot(fc - ctr) < 0) n = n * -1.0
        p.faces += Face(n, q)
    }
    val o = x.o; val a = x.a; val b = x.b; val c = x.c
    face(listOf(o, o + a, o + a + b, o + b)); face(listOf(o + c, o + c + a, o + c + a + b, o + c + b))
    face(listOf(o, o + c, o + c + b, o + b)); face(listOf(o + a, o + a + c, o + a + c + b, o + a + b))
    face(listOf(o, o + a, o + a + c, o + c)); face(listOf(o + b, o + b + a, o + b + a + c, o + b + c))
}

private fun obbEdges(e: Edges, x: Obb) {
    val k = x.corners()
    for ((i, j) in listOf(0 to 1, 1 to 2, 2 to 3, 3 to 0, 4 to 5, 5 to 6, 6 to 7, 7 to 4, 0 to 4, 1 to 5, 2 to 6, 3 to 7)) { e.segs += k[i]; e.segs += k[j] }
}

/**
 * The furniture [fs] of a room whose walls are [bases]. [rgb] gives a material's colour; [open] holds the keys of open
 * doors and drawers.
 */
fun furniture3D(fs: List<Furniture>, bases: Map<String, WallBasis>, ws: Workshop, rgb: (String) -> Int, open: Set<String>): Furn3D {
    val parts = LinkedHashMap<Pair<String?, Int>, Part>(); val edges = LinkedHashMap<String?, Edges>()
    val picks = ArrayList<Pick>(); val keys = ArrayList<String>()
    fs.forEach { f ->
        val colors = mapOf("carcass" to rgb(f.mats.carcass), "front" to rgb(f.mats.front), "back" to rgb(f.mats.back), "top" to rgb("wt38"),
            "mirror" to MIRROR, "glass" to GLASS_P, "splash" to rgb("splash6"),
            "metal" to METAL, "dark" to DARK, "handle" to HANDLE, "white" to WHITE)
        val B = Builder3(ws, colors, parts, edges, picks, keys, open)
        val first = f.walls.firstOrNull { it != ISLAND }
        // the island (or peninsula) stands 900 mm out from the front of the first wall's units, its fronts facing them
        val island: WallBasis? = first?.let { bases[it] }?.let { w ->
            val r = runsOf(f) { id -> bases[id]?.let { (it.len * 1000).toInt() } }.firstOrNull { it.wall == ISLAND }
            val len = r?.let { fillOf(f, it, false).used } ?: 0
            val s = (w.len - len / 1000.0) / 2
            val back = (K_BASE_D + 900 + K_BASE_D) / 1000.0
            val o = w.at(s + len / 1000.0, 0.0, back)
            WallBasis(o.x, o.z, -w.ux, -w.uz, -w.nx, -w.nz, len / 1000.0)
        }
        f.modules.forEach { m ->
            val b = (if (m.wall == ISLAND) island else bases[m.wall ?: ""]) ?: return@forEach
            B.wall = m.wall
            if (m.type == "wardrobe") B.wardrobe(b, m) else B.kitchenUnit(b, m)
        }
        // the worktop over the lower row of each wall (and over the corner it turns into)
        if (f.kind == "kitchen") {
            val wt = worktopTop(ws)
            val rs = runsOf(f) { id -> bases[id]?.let { (it.len * 1000).toInt() } }
            rs.forEach { r ->
                val b = (if (r.wall == ISLAND) island else bases[r.wall]) ?: return@forEach
                B.wall = r.wall
                val low = f.modules.filter { it.wall == r.wall && !isUpper(it) && (it.type == "base" || it.type == "filler" || it.app == "dishwasher") }
                low.forEach { m -> B.box(b, B.top, m.x, m.x + m.w, wt - K_TOP, wt, 0, 600, true) }
                if (r.lowStart > 0 && low.isNotEmpty()) B.box(b, B.top, 0, r.lowStart, wt - K_TOP, wt, 0, 600, true)
                // extras: the backsplash panel on the wall over the worktop, the cornice on the wall units
                val kx = f.kx
                if (kx != null && r.wall != ISLAND) {
                    val a0 = if (r.lowStart > 0) 0 else low.minOfOrNull { it.x } ?: 0
                    val a1 = low.maxOfOrNull { it.x + it.w } ?: 0
                    if (kx.splash > 0 && a1 > a0) B.box(b, B.splash, a0, a1, wt, wt + kx.splash, 0, 6, true)
                    if (kx.cornice) f.modules.filter { it.wall == r.wall && it.type == "wall" }.forEach { m ->
                        B.box(b, B.front, m.x, m.x + m.w, m.elev + m.h, m.elev + m.h + 60, 0, m.d + 30, true)
                    }
                }
            }
        }
    }
    return Furn3D(parts.values.toList(), edges.values.toList(), picks, keys)
}

/** Builds the boards of one piece of furniture on a wall frame; lengths in mm. */
private class Builder3(
    val ws: Workshop, val colors: Map<String, Int>, val parts: LinkedHashMap<Pair<String?, Int>, Part>, val edgeMap: LinkedHashMap<String?, Edges>,
    val picks: ArrayList<Pick>, val keys: ArrayList<String>, val open: Set<String>
) {
    /**
     * The wall being furnished: the furniture on a wall that faces the camera goes see-through with it (an island's
     * never does). Parts are one per wall and colour, so opening a door does not change how many there are.
     */
    var wall: String? = null
    private fun p(k: String): Part {
        val c = colors.getValue(k); val w = if (wall == ISLAND) null else wall
        return parts.getOrPut(w to c) { Part(0, w, Role.FURN, c, 1f) }
    }
    val carcass get() = p("carcass"); val front get() = p("front"); val back get() = p("back"); val top get() = p("top")
    val metal get() = p("metal"); val dark get() = p("dark"); val handle get() = p("handle"); val white get() = p("white")
    val splash get() = p("splash")
    val edges get() = (if (wall == ISLAND) null else wall).let { w -> edgeMap.getOrPut(w) { Edges(0, w ?: "island") } }

    val t = ws.t
    val g = ws.gap10 / 10.0; val edge = ws.edge10 / 10.0

    fun obb(p: Part, x: Obb, line: Boolean) { obbFaces(p, x); if (line) obbEdges(edges, x) }

    /** An upright box [a0]..[a1] along the wall, [y0]..[y1] up, [n0]..[n1] out from the wall. */
    fun box(w: WallBasis, p: Part, a0: Number, a1: Number, y0: Number, y1: Number, n0: Number, n1: Number, line: Boolean = false) {
        val A0 = a0.toDouble() / 1000; val A1 = a1.toDouble() / 1000; val Y0 = y0.toDouble() / 1000; val Y1 = y1.toDouble() / 1000
        val N0 = n0.toDouble() / 1000; val N1 = n1.toDouble() / 1000
        if (A1 - A0 < 1e-4 || Y1 - Y0 < 1e-4 || N1 - N0 < 1e-4) return
        obb(p, Obb(w.at(A0, Y0, N0), w.dir(A1 - A0, 0.0), V3(0.0, Y1 - Y0, 0.0), w.dir(0.0, N1 - N0)), line)
    }

    /**
     * A door hinged at [ha] (the back corner of its hinge edge), [fw] wide, opening to the right ([s] +1) or left (-1);
     * its handle's middle [hy] above the door's bottom.
     */
    fun door(w: WallBasis, key: String, ha: Double, n: Double, y0: Double, h: Double, fw: Double, s: Int, handles: Boolean, hy: Double, p: Part = front) {
        keys += key
        val th = if (key in open) Math.toRadians(OPEN_DEG) else 0.0
        val e = w.dir(s * cos(th), sin(th)); val tn = w.dir(-s * sin(th), cos(th))
        val o = w.at(ha / 1000, y0 / 1000, n / 1000)
        val x = Obb(o, e * (fw / 1000), V3(0.0, h / 1000, 0.0), tn * (t / 1000.0))
        obb(p, x, true); picks += Pick(key, x)
        if (handles) {
            val ho = o + e * ((fw - 40) / 1000) + tn * (t / 1000.0) + V3(0.0, (hy - 64) / 1000, 0.0)
            obb(handle, Obb(ho, e * .012, V3(0.0, .128, 0.0), tn * .025), false)
        }
    }

    /** A drawer front (and its box, out when open): [a0] along, [y0] up, the front's back face at [n]. */
    fun drawer(w: WallBasis, key: String, a0: Double, fw: Double, y0: Double, fh: Double, n: Double, d: Double, handles: Boolean, p: Part = front, box: Boolean = true) {
        keys += key
        val out = if (key in open) d * .75 else 0.0
        val nn = n + out
        val o = w.at(a0 / 1000, y0 / 1000, nn / 1000)
        val x = Obb(o, w.dir(fw / 1000, 0.0), V3(0.0, fh / 1000, 0.0), w.dir(0.0, t / 1000.0))
        obb(p, x, true); picks += Pick(key, x)
        if (box && out > 0) {
            val bh = min(fh - 40, 150.0).coerceAtLeast(60.0); val bx0 = a0 + 26; val bx1 = a0 + fw - 26; val by = y0 + 20
            box(w, carcass, bx0, bx1, by, by + 12, nn - d + 40, nn)
            box(w, carcass, bx0, bx0 + 12, by, by + bh, nn - d + 40, nn); box(w, carcass, bx1 - 12, bx1, by, by + bh, nn - d + 40, nn)
            box(w, carcass, bx0, bx1, by, by + bh, nn - d + 40, nn - d + 52)
        }
        if (handles) {
            val hc = a0 + fw / 2
            obb(handle, Obb(w.at((hc - 64) / 1000, (y0 + fh - min(40.0, fh / 3)) / 1000, (nn + t) / 1000), w.dir(.128, 0.0), V3(0.0, .012, 0.0), w.dir(0.0, .025)), false)
        }
    }

    /** A kitchen unit: base, wall or tall carcass with its fronts; appliance spaces and fillers. */
    fun kitchenUnit(w: WallBasis, m: Module) {
        val x0 = m.x.toDouble(); val x1 = x0 + m.w; val y0 = m.elev.toDouble(); val y1 = y0 + m.h; val d = m.d.toDouble()
        when (m.type) {
            "filler" -> { box(w, front, x0, x1, y0, y1, d - 20, d, true); return }
            "gap" -> {
                when (m.app) {
                    "fridge" -> {
                        box(w, white, x0 + 5, x1 - 5, 0, m.h, 0, d, true)
                        val split = m.h * .64
                        box(w, metal, x0 + 5, x1 - 5, split - 4, split + 4, d, d + 2)
                        box(w, handle, x0 + 30, x0 + 42, split + 120, split + 420, d, d + 25); box(w, handle, x0 + 30, x0 + 42, split - 420, split - 120, d, d + 25)
                    }
                    "dishwasher" -> {
                        box(w, metal, x0 + 3, x1 - 3, y0, y1 - 10, 0, d - 20)
                        frontSizes(m.fronts, m.w, m.h, ws).firstOrNull()?.let { (fh, fw) ->
                            box(w, front, x0 + edge, x0 + edge + fw, y0 + edge, y0 + edge + fh, d, d + t, true)
                            if (m.handles) box(w, handle, x0 + m.w / 2.0 - 64, x0 + m.w / 2.0 + 64, y0 + edge + fh - 46, y0 + edge + fh - 34, d + t, d + t + 25)
                        }
                    }
                }
                return
            }
        }
        // the carcass: sides, bottom, top (two rails on base units), back, shelves
        box(w, carcass, x0, x0 + t, y0, y1, 0, d, true); box(w, carcass, x1 - t, x1, y0, y1, 0, d, true)
        box(w, carcass, x0 + t, x1 - t, y0, y0 + t, 0, d, true)
        if (m.type == "base") { box(w, carcass, x0 + t, x1 - t, y1 - t, y1, d - 100, d, true); box(w, carcass, x0 + t, x1 - t, y1 - t, y1, 0, 100, true) }
        else box(w, carcass, x0 + t, x1 - t, y1 - t, y1, 0, d, true)
        box(w, back, x0 + 2, x1 - 2, y0 + 2, y1 - 2, 0, 3)
        val shelves = m.inserts.filter { it.kind == "shelf" }.sumOf { it.qty }
        if (m.fronts.kind != "drawer") for (k in 1..shelves) { val y = y0 + (m.h - t) * k / (shelves + 1.0); box(w, carcass, x0 + t, x1 - t, y, y + t, 20, d - 20, true) }
        // a plinth under base and tall units on legs
        if (m.legs && m.type != "wall" && y0 > 0) box(w, metal, x0, x1, 0, y0 - 2, d - 70, d - 54)
        // fronts
        val fs = frontSizes(m.fronts, m.w, m.h, ws)
        when (m.fronts.kind) {
            "door" -> fs.forEachIndexed { j, (fh, fw) ->
                val n = fs.size
                val a = x0 + edge + j * (fw + g)
                // single doors hinge on the left; pairs on the outer edges
                val right = n == 2 && j == 1
                // handles near the top of a low door, near the bottom of a wall unit's, at 1 m on a tall one
                val hy = when { m.type == "wall" -> 90.0; fh > 1200 -> (1000 - y0).coerceIn(150.0, fh - 150.0); else -> fh - 90.0 }
                door(w, "${m.id}:f$j", if (right) a + fw else a, d, y0 + edge, fh.toDouble(), fw.toDouble(), if (right) -1 else 1, m.handles, hy)
            }
            "drawer", "panel" -> {
                var y = y1 - edge
                fs.forEachIndexed { j, (fh, fw) ->
                    y -= fh
                    if (m.fronts.kind == "drawer") drawer(w, "${m.id}:f$j", x0 + edge, fw.toDouble(), y, fh.toDouble(), d, d, m.handles)
                    else box(w, front, x0 + edge, x0 + edge + fw, y, y + fh, d, d + t, true)
                    y -= g
                }
            }
        }
        // what shows the appliance
        val cx = (x0 + x1) / 2; val wt = worktopTop(ws).toDouble()
        when (m.app) {
            "sink" -> {
                box(w, metal, cx - m.w * .36, cx + m.w * .36, wt - 1, wt + 1, 80, 520)
                box(w, metal, cx - 15, cx + 15, wt, wt + 300, 40, 70); box(w, metal, cx - 12, cx + 12, wt + 280, wt + 300, 70, 260)
            }
            "hob" -> {
                box(w, dark, cx - 290, cx + 290, wt, wt + 6, 40, 560)
                listOf(-140.0 to 160.0, 140.0 to 160.0, -140.0 to 420.0, 140.0 to 420.0).forEach { (dx, dn) -> box(w, metal, cx + dx - 45, cx + dx + 45, wt + 6, wt + 9, dn - 45, dn + 45) }
            }
            "oven" -> box(w, dark, x0 + edge + 20, x1 - edge - 20, 800, 1380, d + t, d + t + 2)
            "micro" -> box(w, dark, x0 + t + 10, x0 + m.w * .72, y0 + 60, y1 - 60, 40, d - 10, true)
            "hood" -> box(w, metal, x0 + 10, x1 - 10, y0 - 60, y0, 30, d + 40, true)
        }
    }

    /** A wardrobe: sides (none at a wall), top and bottom, plinth, dividers, backs, inside, doors. */
    fun wardrobe(w: WallBasis, m: Module) {
        val x0 = m.x.toDouble(); val x1 = x0 + m.w; val d = m.d.toDouble()
        // sliding doors take the front of the depth: the inside is shallower
        val di = uz.metrx.app.furniture.innerD(m).toDouble()
        val z0 = if (m.legs) ws.legH.toDouble() else 0.0
        val base = wardBase(m).toDouble()
        val yb = z0 + base; val yt = z0 + m.h
        val sl = if (m.sideL) t else 0; val sr = if (m.sideR) t else 0
        if (m.sideL) box(w, carcass, x0, x0 + t, z0, yt, 0, d, true)
        if (m.sideR) box(w, carcass, x1 - t, x1, z0, yt, 0, d, true)
        // the bottom under every section but a desk's knee space
        if (m.sections.none { it.knee }) box(w, carcass, x0 + sl, x1 - sr, yb, yb + t, 0, d, true)
        else { var a = x0; m.sections.forEach { s -> if (!s.knee) box(w, carcass, maxOf(a, x0 + sl), minOf(a + s.w, x1 - sr), yb, yb + t, 0, d, true); a += s.w } }
        box(w, carcass, x0 + sl, x1 - sr, yt - t, yt, 0, d, true)
        if (!m.legs) box(w, carcass, x0 + sl, x1 - sr, 0, PLINTH, d - 60, d - 44, true)
        var acc = x0
        val secs = m.sections
        secs.forEachIndexed { i, s ->
            val a0 = acc; val a1 = acc + s.w
            if (i > 0) {
                // beside a knee space the divider stands on the floor like a side
                val toFloor = s.knee || secs[i - 1].knee
                box(w, carcass, a0 - t / 2.0, a0 + t / 2.0, if (toFloor) 0.0 else yb + t, yt - t, 0, if (toFloor) d else di, true)
            }
            if (s.knee) { acc = a1; return@forEachIndexed }
            val iw = wardInner(m, secs, i, t)
            val il = if (i == 0) a0 + sl else a0 + t / 2.0
            box(w, back, a0 + 2, a1 - 2, yb + 2, yt - 2, 0, 3)
            val floor = yb + t
            s.inserts.forEach { x ->
                val y = floor + x.pos
                when (x.kind) {
                    "shelf" -> box(w, carcass, il, il + iw, y, y + t, 0, di - 20, true)
                    "rail" -> box(w, metal, il + 5, il + iw - 5, y - 12, y + 12, di / 2 - 12, di / 2 + 12)
                    "lift" -> { box(w, metal, il + 20, il + iw - 20, y + 30, y + 54, di / 2 - 12, di / 2 + 12); box(w, metal, il + 5, il + 25, y + 54, y + blockH(x), di / 2 - 15, di / 2 + 15) }
                    // in an open section the drawer's face is seen: front board, flush with the carcass, with a handle
                    "drawer" -> if (s.fronts.kind == "open") drawer(w, "${m.id}:s$i:d${x.pos}", il + 4, iw - 8.0, y, blockH(x).toDouble(), di - t, di - 60, m.handles, front)
                        else drawer(w, "${m.id}:s$i:d${x.pos}", il + 4, iw - 8.0, y, blockH(x).toDouble(), di - 40 - t, di - 60, m.handles, carcass)
                    else -> {
                        // trouser and shoe racks: a frame that pulls out
                        keys += "${m.id}:s$i:r${x.pos}"
                        val out = if ("${m.id}:s$i:r${x.pos}" in open) d * .7 else 0.0
                        val h = blockH(x).toDouble()
                        val o = w.at((il + 13) / 1000, y / 1000, (20 + out) / 1000)
                        val bx = Obb(o, w.dir((iw - 26) / 1000.0, 0.0), V3(0.0, h / 1000, 0.0), w.dir(0.0, (d - 60) / 1000))
                        obbEdges(edges, bx); picks += Pick("${m.id}:s$i:r${x.pos}", bx)
                        box(w, metal, il + 13, il + iw - 13, y, y + 10, 20 + out, d - 40 + out)
                        for (k in 1..4) { val yy = if (x.kind == "shoe") y + h * k / 5 else y + h - 12; val nn = if (x.kind == "shoe") 20 + out + (d - 60) * k / 5 else 20 + out + (d - 60) * k / 5
                            box(w, metal, il + 13, il + iw - 13, yy, yy + 8, nn - 6, nn) }
                    }
                }
            }
            // the section's doors over its width, from the bottom panel up
            val fs = frontSizes(s.fronts, s.w, m.h - wardBase(m), ws)
            if (s.fronts.kind == "door" && m.slide == null) fs.forEachIndexed { j, (fh, fw) ->
                val a = a0 + edge + j * (fw + g)
                val right = if (fs.size == 2) j == 1 else i % 2 == 1
                door(w, "${m.id}:s$i:f$j", if (right) a + fw else a, d, yb + edge, fh.toDouble(), fw.toDouble(), if (right) -1 else 1, m.handles,
                    (1000 - yb).coerceIn(150.0, fh - 150.0))
            }
            acc = a1
        }
        m.slide?.let { sl -> slidingDoors(w, m, sl, x0 + sl0(m), yb + t, d) }
    }

    private fun sl0(m: Module) = if (m.sideL) t else 0

    /**
     * Sliding doors: [n] in two tracks at the front, each overlapping the next; a frame of profiles round its filling
     * (board, mirror or glass). A tapped door slides over its neighbour.
     */
    fun slidingDoors(w: WallBasis, m: Module, sl: uz.metrx.app.furniture.Slide, ax: Double, y0: Double, d: Double) {
        val n = sl.n.coerceIn(2, 4)
        val (dw, dh) = uz.metrx.app.furniture.slideDoor(m, t)
        val step = (dw - uz.metrx.app.furniture.SLIDE_OV).toDouble()
        for (j in 0 until n) {
            val key = "${m.id}:slide$j"
            keys += key
            // a door slides one step towards the middle: the last one left, the others right
            val shift = if (key in open) (if (j == n - 1) -step else step) else 0.0
            val a = ax + j * step + shift
            val n0 = d - 95 + (j % 2) * 45; val n1 = n0 + 22
            val y = y0 + uz.metrx.app.furniture.SLIDE_CLEAR / 2.0
            val fill = when (sl.panel(j)) { "mirror" -> p("mirror"); "glass" -> p("glass"); else -> front }
            val fw = uz.metrx.app.furniture.SLIDE_FRAME_W.toDouble(); val fh = uz.metrx.app.furniture.SLIDE_FRAME_H / 2.0
            box(w, fill, a + fw, a + dw - fw, y + fh, y + dh - fh, n0 + 6, n1 - 6, true)
            // the frame: two uprights, the top and the bottom
            box(w, metal, a, a + fw, y, y + dh, n0, n1, true); box(w, metal, a + dw - fw, a + dw, y, y + dh, n0, n1, true)
            box(w, metal, a + fw, a + dw - fw, y, y + fh, n0, n1, true); box(w, metal, a + fw, a + dw - fw, y + dh - fh, y + dh, n0, n1, true)
            val o = w.at(a / 1000, y / 1000, n0 / 1000)
            picks += Pick(key, Obb(o, w.dir(dw / 1000.0, 0.0), V3(0.0, dh / 1000.0, 0.0), w.dir(0.0, (n1 - n0) / 1000.0)))
        }
    }
}
