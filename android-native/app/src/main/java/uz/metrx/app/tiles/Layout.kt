package uz.metrx.app.tiles

import uz.metrx.app.data.Room
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.earClip
import uz.metrx.app.geo.ready3D
import uz.metrx.app.geo.walls
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sign
import kotlin.math.sin

/*
 * Laying the tiles: each surface a layout covers (the floor, a wall or a band of it, a column's faces, a niche's back, a
 * bath's front) as an outline with holes in its own millimetres, and every tile of the pattern clipped to it. A piece
 * is whole or cut; the doors, windows, columns, niches, trays and baths are holes the tiles are cut round.
 */

/** A point or a direction on a surface, mm. */
data class V2(val x: Double, val y: Double) {
    operator fun plus(o: V2) = V2(x + o.x, y + o.y)
    operator fun minus(o: V2) = V2(x - o.x, y - o.y)
    operator fun times(k: Double) = V2(x * k, y * k)
    fun dot(o: V2) = x * o.x + y * o.y
    fun cross(o: V2) = x * o.y - y * o.x
}

/* ---------------- polygons ---------------- */

/** The signed area (shoelace); positive for the room's own corner order (clockwise on the plan, y down). */
fun area(p: List<V2>): Double {
    var s = 0.0
    for (i in p.indices) { val a = p[i]; val b = p[(i + 1) % p.size]; s += a.x * b.y - b.x * a.y }
    return s / 2
}

/** [p] cut by the line a→b: the side where s · (b − a) × (q − a) ≥ 0 stays. [p] may be concave; the area stays right. */
internal fun clipHalf(p: List<V2>, a: V2, b: V2, s: Double): List<V2> {
    if (p.size < 3) return emptyList()
    val out = ArrayList<V2>(p.size + 2)
    val d = b - a
    for (i in p.indices) {
        val c = p[i]; val n = p[(i + 1) % p.size]
        val fc = s * d.cross(c - a); val fn = s * d.cross(n - a)
        if (fc >= 0) out += c
        if ((fc >= 0) != (fn >= 0)) { val t = fc / (fc - fn); out += c + (n - c) * t }
    }
    return if (out.size < 3) emptyList() else out
}

/** [p] inside the convex polygon [k]. */
fun clipConvex(p: List<V2>, k: List<V2>): List<V2> {
    val s = sign(area(k)).takeIf { it != 0.0 } ?: return emptyList()
    var r = p
    for (i in k.indices) { r = clipHalf(r, k[i], k[(i + 1) % k.size], s); if (r.isEmpty()) return r }
    return r
}

/** [p] less the convex hole [h], as convex pieces when [p] is convex: one piece beyond each of the hole's edges. */
fun subtract(p: List<V2>, h: List<V2>): List<List<V2>> {
    val s = sign(area(h)).takeIf { it != 0.0 } ?: return listOf(p)
    val out = ArrayList<List<V2>>(); var rest = p
    for (i in h.indices) {
        val a = h[i]; val b = h[(i + 1) % h.size]
        val o = clipHalf(rest, a, b, -s)
        if (o.size >= 3 && abs(area(o)) > 1.0) out += o
        rest = clipHalf(rest, a, b, s)
        if (rest.isEmpty()) break
    }
    return out
}

internal class Box2(val x0: Double, val y0: Double, val x1: Double, val y1: Double) {
    fun hits(o: Box2) = x0 < o.x1 && o.x0 < x1 && y0 < o.y1 && o.y0 < y1
}
internal fun boxOf(p: List<V2>): Box2 = Box2(p.minOf { it.x }, p.minOf { it.y }, p.maxOf { it.x }, p.maxOf { it.y })

private fun same(a: V2, b: V2) = abs(a.x - b.x) < 1e-6 && abs(a.y - b.y) < 1e-6

/** Whether [p] is convex (straight runs allowed). */
fun isConvex(p: List<V2>): Boolean {
    var sg = 0.0
    for (i in p.indices) {
        val a = p[i]; val b = p[(i + 1) % p.size]; val c = p[(i + 2) % p.size]
        val cr = (b - a).cross(c - b)
        if (abs(cr) < 1e-6) continue
        if (sg == 0.0) sg = sign(cr) else if (sign(cr) != sg) return false
    }
    return true
}

/** A polygon as convex pieces: itself when convex, else its triangles joined back while they stay convex. */
fun convexParts(p: List<V2>): List<List<V2>> {
    if (p.size < 3) return emptyList()
    if (isConvex(p)) return listOf(p)
    val idx = earClip(p.map { it.x to it.y })
    val parts = ArrayList<List<V2>>()
    for (t in idx.indices step 3) parts += listOf(p[idx[t]], p[idx[t + 1]], p[idx[t + 2]])
    var merged = true
    while (merged) {
        merged = false
        loop@ for (i in parts.indices) for (j in i + 1 until parts.size) {
            val m = join(parts[i], parts[j]) ?: continue
            if (!isConvex(m)) continue
            parts[i] = m; parts.removeAt(j); merged = true; break@loop
        }
    }
    return parts
}

/** Two polygons with an edge in common as one, or null. */
private fun join(a: List<V2>, b: List<V2>): List<V2>? {
    for (i in a.indices) {
        val u = a[i]; val v = a[(i + 1) % a.size]
        for (j in b.indices) {
            val bu = b[j]; val bv = b[(j + 1) % b.size]
            val back = same(bu, v) && same(bv, u); val fwd = same(bu, u) && same(bv, v)
            if (!back && !fwd) continue
            val out = ArrayList<V2>()
            for (k in 0 until a.size) out += a[(i + 1 + k) % a.size]        // v … u
            if (back) for (k in 2 until b.size) out += b[(j + k) % b.size]  // after u … before v
            else for (k in 1 until b.size - 1) out += b[(j - k + 2 * b.size) % b.size]
            return out
        }
    }
    return null
}

/* ---------------- the room as surfaces ---------------- */

/** Where a surface is in the 3D scene: [o] in metres, [u] and [v] its axes, [n] the way it faces. */
class Frame(val o: V3, val u: V3, val v: V3, val n: V3) {
    /** The scene point of surface point ([a], [b]) mm, [off] metres in front of it. */
    fun at(a: Double, b: Double, off: Double = 0.0) = V3(o.x + (u.x * a + v.x * b) / 1000 + n.x * off, o.y + (u.y * a + v.y * b) / 1000 + n.y * off, o.z + (u.z * a + v.z * b) / 1000 + n.z * off)
}

/** A wall on the plan, mm: from [p0] along [t], [nIn] into the room. */
class TWall(val id: String, val p0: V2, val t: V2, val nIn: V2, val len: Double) {
    fun at(a: Double, d: Double = 0.0) = p0 + t * a + nIn * d
}

/**
 * A measured room as the tiles see it: its walls, its floor outline (plan mm), its height, its tray and bath, and
 * where the plan's corner is in the 3D scene ([dx], [dz] metres).
 */
class TRoomGeo(val room: Room, val walls: List<TWall>, val floor: List<V2>, val H: Double, val fixes: List<TFix>, val dx: Double, val dz: Double, val rect: Boolean) {
    fun wall(id: String) = walls.firstOrNull { it.id == id }
    fun scene(q: V2, y: Double = 0.0) = V3(q.x / 1000 + dx, y, q.y / 1000 + dz)
    fun wallFrame(w: TWall, depth: Double = 0.0): Frame {
        val o = scene(w.p0 + w.nIn * depth)
        return Frame(o, V3(w.t.x, 0.0, w.t.y), V3(0.0, 1.0, 0.0), V3(w.nIn.x, 0.0, w.nIn.y))
    }
    val floorFrame get() = Frame(V3(dx, 0.0, dz), V3(1.0, 0.0, 0.0), V3(0.0, 0.0, 1.0), V3(0.0, 1.0, 0.0))
}

/** The room ready for tiles, or null until it can be drawn in 3D (its sizes and height known). */
fun roomGeo(r: Room, snap: Boolean, fixes: List<TFix>, dx: Double = 0.0, dz: Double = 0.0): TRoomGeo? {
    if (!ready3D(r, snap)) return null
    val H = r.dim("H").v ?: return null
    val ws = walls(r, snap).map { w ->
        val p0 = V2(w.p0.x, w.p0.y); val d = V2(w.p1.x, w.p1.y) - p0; val l = hypot(d.x, d.y)
        val t = if (l > 0) d * (1 / l) else V2(1.0, 0.0)
        TWall(w.id, p0, t, V2(-t.y, t.x), l)
    }
    if (ws.size < 3 || ws.any { it.len <= 0 }) return null
    return TRoomGeo(r, ws, ws.map { it.p0 }, H.toDouble(), fixes, dx, dz, !r.isPoly)
}

/** A tray's or bath's place on the plan: its four corners. */
fun footprint(g: TRoomGeo, f: TFix): List<V2>? {
    val w = g.wall(f.wall) ?: return null
    return listOf(w.at(f.off.toDouble()), w.at((f.off + f.w).toDouble()), w.at((f.off + f.w).toDouble(), f.d.toDouble()), w.at(f.off.toDouble(), f.d.toDouble()))
}

/** The stretch of wall [w] a tray or bath stands against, mm along it, or null when it does not touch it. */
fun coverOn(g: TRoomGeo, w: TWall, f: TFix): Pair<Double, Double>? {
    val fp = footprint(g, f) ?: return null
    val on = fp.filter { q -> abs((q - w.p0).dot(w.nIn)) < 3.0 }.map { q -> (q - w.p0).dot(w.t) }
    if (on.size < 2) return null
    val a = max(0.0, on.min()); val b = min(w.len, on.max())
    return if (b - a > 1) a to b else null
}

/** A column's footprint on the plan (rectangular rooms: columns and niches are drawn in 3D there only). */
private fun colFoot(g: TRoomGeo, f: uz.metrx.app.data.Feature): List<V2>? {
    val w = g.wall(f.wall) ?: return null
    return listOf(w.at(f.off.toDouble()), w.at((f.off + f.w).toDouble()), w.at((f.off + f.w).toDouble(), f.d.toDouble()), w.at(f.off.toDouble(), f.d.toDouble()))
}

private fun rect(x0: Double, y0: Double, x1: Double, y1: Double) = listOf(V2(x0, y0), V2(x1, y0), V2(x1, y1), V2(x0, y1))

/**
 * One surface to tile: its outline and holes in its own mm ([u] along, [v] up; the floor in plan mm), its frame in
 * the scene, the wall it belongs to (the floor none), [kind] floor, wall, col, niche, bath or panel, [alt] the second
 * tile on it. [zone] the band of a wall it covers (bottom, top); [cu] the middle of the first tile along it.
 */
class Surf(val key: String, val kind: String, val wall: String?, val outline: List<V2>, val holes: List<List<V2>>, val frame: Frame, val alt: Boolean,
           val lo: Double = 0.0, val hi: Double = 0.0, val len: Double = 0.0)

/** A wall surface's tiled band, bottom to top, mm. */
fun zoneOf(s: TSurf, H: Double): Pair<Double, Double> = when (s.mode) {
    "to" -> 0.0 to min(H, s.h1.toDouble().coerceAtLeast(1.0))
    "band" -> s.h0.toDouble().coerceIn(0.0, H) to s.h1.toDouble().coerceIn(0.0, H)
    else -> 0.0 to H
}

/** The surfaces layout [l] covers in room [g]. */
fun surfacesOf(l: TileLayout, g: TRoomGeo): List<Surf> {
    val out = ArrayList<Surf>()
    val r = g.room
    for (s in l.surfs) {
        if (s.id == "floor") {
            val holes = ArrayList<List<V2>>()
            if (g.rect) r.features.filter { it.type == "column" }.forEach { f -> colFoot(g, f)?.let { holes += it } }
            g.fixes.forEach { f -> footprint(g, f)?.let { holes += it } }
            out += Surf("floor", "floor", null, g.floor, holes, g.floorFrame, s.alt)
            continue
        }
        if (s.id.startsWith("bath:")) {
            val f = g.fixes.firstOrNull { it.id == s.id.removePrefix("bath:") } ?: continue
            val w = g.wall(f.wall) ?: continue
            out += Surf(s.id, "bath", w.id, rect(f.off.toDouble(), 0.0, (f.off + f.w).toDouble(), f.h.toDouble()), emptyList(), g.wallFrame(w, f.d.toDouble()), s.alt, 0.0, f.h.toDouble(), w.len)
            continue
        }
        val w = g.wall(s.id) ?: continue
        val (lo, hi) = zoneOf(s, g.H)
        if (hi - lo < 1) continue
        val holes = ArrayList<List<V2>>()
        r.openings.filter { it.wall == w.id }.forEach { o ->
            // a balcony block (room editor v2): the door part from the floor, the window part level with its top
            if (o.balcony) {
                holes += rect(o.off.toDouble(), 0.0, (o.off + o.dw).toDouble(), o.h.toDouble())
                holes += rect((o.off + o.dw).toDouble(), (o.h - o.wh).toDouble(), (o.off + o.w).toDouble(), o.h.toDouble())
            } else holes += rect(o.off.toDouble(), o.sill.toDouble(), (o.off + o.w).toDouble(), (o.sill + o.h).toDouble())
        }
        g.fixes.forEach { f -> coverOn(g, w, f)?.let { (a, b) -> holes += rect(a, -1.0, b, f.h.toDouble()) } }
        val frame = g.wallFrame(w)
        if (g.rect) r.features.filter { it.wall == w.id }.forEach { f ->
            val a0 = f.off.toDouble(); val a1 = (f.off + f.w).toDouble(); val d = f.d.toDouble()
            if (f.type == "column") {
                holes += rect(a0, -1.0, a1, g.H + 1)
                out += Surf("${w.id}:c:${f.id}:f", "col", w.id, rect(a0, lo, a1, hi), emptyList(), g.wallFrame(w, d), s.alt, lo, hi, w.len)
                // the sides: u runs from the wall into the room
                val sideL = Frame(g.scene(w.at(a0)), V3(w.nIn.x, 0.0, w.nIn.y), V3(0.0, 1.0, 0.0), V3(-w.t.x, 0.0, -w.t.y))
                val sideR = Frame(g.scene(w.at(a1)), V3(w.nIn.x, 0.0, w.nIn.y), V3(0.0, 1.0, 0.0), V3(w.t.x, 0.0, w.t.y))
                out += Surf("${w.id}:c:${f.id}:l", "col", w.id, rect(0.0, lo, d, hi), emptyList(), sideL, s.alt, lo, hi, d)
                out += Surf("${w.id}:c:${f.id}:r", "col", w.id, rect(0.0, lo, d, hi), emptyList(), sideR, s.alt, lo, hi, d)
            } else {
                val sill = f.sill.toDouble(); val nh = (if (f.h > 0) f.h.toDouble() else g.H - sill).coerceAtMost(g.H - sill)
                holes += rect(a0, sill, a1, sill + nh)
                val b0 = max(lo, sill); val b1 = min(hi, sill + nh)
                if (b1 - b0 > 1) out += Surf("${w.id}:n:${f.id}", "niche", w.id, rect(a0, b0, a1, b1), emptyList(), g.wallFrame(w, -min(d, (r.dim("T").v ?: 200) - 10.0)), s.alt, b0, b1, w.len)
            }
        }
        out += Surf(w.id, "wall", w.id, rect(0.0, lo, w.len, hi), holes, frame, s.alt, lo, hi, w.len)
    }
    return out
}

/** A layout without a room: one surface, its frame given by the scene that shows it. */
fun panelSurf(l: TileLayout, frame: Frame): Surf? {
    val p = l.panel ?: return null
    if (p.a <= 0 || p.b <= 0) return null
    return Surf("panel", if (p.kind == "floor") "floor" else "panel", if (p.kind == "floor") null else "A", rect(0.0, 0.0, p.a.toDouble(), p.b.toDouble()), emptyList(), frame, false,
        0.0, p.b.toDouble(), p.a.toDouble())
}

/* ---------------- the pattern ---------------- */

/**
 * How tiles go on a region: the pattern's origin [o] (surface mm) and angle [ang] (radians), the tile [a] × [b]
 * (long side [b] along the pattern), the joint [j]; [kind] straight, brick2, brick3 or herring; [chess] alternate
 * tiles in the second look; [prod] what the tiles are: 0 the main tile, 1 the second look, 2 the border strip's tile.
 */
class Spec(val o: V2, val ang: Double, val a: Double, val b: Double, val j: Double, val kind: String, val chess: Boolean, val prod: Int)

/**
 * One tile on a surface: its pieces (convex polygons, surface mm), its area, the whole tile's area, which tile it is,
 * its cut piece's size along and across the tile ([pw] × [ph], mm), whether that piece is about a rectangle, and the
 * tile's drawn corners [c] (c0 → c1 along its long side when not [vert]) for its texture. [s] is the surface index.
 */
class Piece(val polys: List<List<V2>>, val area: Double, val full: Double, val prod: Int, val pw: Double, val ph: Double, val rectish: Boolean,
            val c: List<V2>, val vert: Boolean, val seed: Int, val s: Int) {
    val cut get() = area < full * .995
}

/** Rotating by [ang] about nothing. */
private fun rot(p: V2, c: Double, s: Double) = V2(p.x * c - p.y * s, p.x * s + p.y * c)

/** A tile of the pattern in its own frame: corner, size along x and y, its row and column, standing up (herringbone). */
private class TR(val x: Double, val y: Double, val w: Double, val h: Double, val i: Int, val k: Int, val vert: Boolean)

/** Most tiles worked out for one region: a 10 mm mosaic on a big floor would otherwise take seconds. */
const val MAX_TILES = 60_000

/** The pattern's tiles that may touch the box [bx] (pattern frame). */
private fun tilesIn(sp: Spec, x0: Double, y0: Double, x1: Double, y1: Double): List<TR>? {
    val a = sp.a; val b = sp.b; val j = sp.j
    val out = ArrayList<TR>()
    when (sp.kind) {
        "herring" -> {
            // a staircase of a lying tile and a standing one, repeated by (S, S) and (L, −L)
            val L = b + j; val S = a + j
            val kMin = floor((x0 + y0) / (2 * S)).toInt() - 2; val kMax = ceil((x1 + y1) / (2 * S)).toInt() + 2
            val mMin = floor((x0 - y1) / (2 * L)).toInt() - 2; val mMax = ceil((x1 - y0) / (2 * L)).toInt() + 2
            if ((kMax - kMin).toLong() * (mMax - mMin) * 2 > MAX_TILES * 4L) return null
            for (k in kMin..kMax) for (m in mMin..mMax) {
                val hx = k * S + m * L; val hy = k * S - m * L
                if (hx < x1 && hx + b > x0 && hy < y1 && hy + a > y0) out += TR(hx, hy, b, a, k, m, false)
                val vy = hy + S
                if (hx < x1 && hx + a > x0 && vy < y1 && vy + b > y0) out += TR(hx, vy, a, b, k, m, true)
                if (out.size > MAX_TILES) return null
            }
        }
        else -> {
            val pw = b + j; val ph = a + j
            val kMin = floor(y0 / ph).toInt() - 1; val kMax = ceil(y1 / ph).toInt() + 1
            if ((kMax - kMin).toLong() * ((x1 - x0) / pw + 3) > MAX_TILES) return null
            for (k in kMin..kMax) {
                val shift = when (sp.kind) { "brick2" -> Math.floorMod(k, 2) * pw / 2; "brick3" -> Math.floorMod(k, 3) * pw / 3; else -> 0.0 }
                val iMin = floor((x0 - shift) / pw).toInt() - 1; val iMax = ceil((x1 - shift) / pw).toInt() + 1
                for (i in iMin..iMax) out += TR(i * pw + shift, k * ph, b, a, i, k, false)
            }
        }
    }
    return out
}

/**
 * The tiles of [sp] on the region [region] (any polygon) less [holes] (convex), as pieces of surface [si]; [inset]
 * shrinks each tile before it is cut (the drawing's joints, so a 2 mm joint still shows). Null: too many tiles.
 */
fun lay(region: List<V2>, holes: List<List<V2>>, sp: Spec, si: Int, inset: Double = 0.0): List<Piece>? {
    if (region.size < 3) return emptyList()
    val parts = convexParts(region).map { it to boxOf(it) }
    val hb = holes.map { it to boxOf(it) }
    val rb = boxOf(region)
    val c = cos(sp.ang); val s = sin(sp.ang)
    // the region's box in the pattern's frame
    val corners = listOf(V2(rb.x0, rb.y0), V2(rb.x1, rb.y0), V2(rb.x1, rb.y1), V2(rb.x0, rb.y1)).map { rot(it - sp.o, c, -s) }
    val tiles = tilesIn(sp, corners.minOf { it.x }, corners.minOf { it.y }, corners.maxOf { it.x }, corners.maxOf { it.y }) ?: return null
    val out = ArrayList<Piece>()
    for (t in tiles) {
        val e = min(inset, min(t.w, t.h) / 4)
        val q = listOf(V2(t.x + e, t.y + e), V2(t.x + t.w - e, t.y + e), V2(t.x + t.w - e, t.y + t.h - e), V2(t.x + e, t.y + t.h - e)).map { sp.o + rot(it, c, s) }
        val qb = boxOf(q)
        if (!qb.hits(rb)) continue
        val polys = ArrayList<List<V2>>()
        for ((pp, pb) in parts) {
            if (!qb.hits(pb)) continue
            val inP = clipConvex(q, pp)
            if (inP.size < 3) continue
            var cur = listOf(inP)
            for ((h, b) in hb) {
                if (!qb.hits(b)) continue
                cur = cur.flatMap { subtract(it, h) }
                if (cur.isEmpty()) break
            }
            polys += cur
        }
        if (polys.isEmpty()) continue
        val ar = polys.sumOf { abs(area(it)) }
        if (ar < 4.0) continue
        // the piece's size in the tile's own frame (long side first)
        var lx0 = Double.MAX_VALUE; var ly0 = Double.MAX_VALUE; var lx1 = -Double.MAX_VALUE; var ly1 = -Double.MAX_VALUE
        polys.forEach { pl -> pl.forEach { v -> val p = rot(v - sp.o, c, -s); lx0 = min(lx0, p.x - t.x); ly0 = min(ly0, p.y - t.y); lx1 = max(lx1, p.x - t.x); ly1 = max(ly1, p.y - t.y) } }
        val ex = (lx1 - lx0).coerceIn(0.0, t.w); val ey = (ly1 - ly0).coerceIn(0.0, t.h)
        val pw = if (t.vert) ey else ex; val ph = if (t.vert) ex else ey
        val full = (t.w - 2 * e) * (t.h - 2 * e)
        val prod = if (sp.chess && Math.floorMod(t.i + t.k, 2) == 1) 1 else sp.prod
        out += Piece(polys, ar, full, prod, pw, ph, ar / max(1.0, ex * ey) > .97, q, t.vert, 31 * t.i + 17 * t.k + (if (t.vert) 7 else 0), si)
    }
    return out
}

/** The tiles' angle of a layout: its turn, and the pattern's own (a diagonal 45°, a herringbone's staircase −45°). */
fun angleOf(l: TileLayout): Double {
    val deg = l.rot + when (l.pattern) { "diagonal" -> 45; "herring" -> -45; else -> 0 }
    return deg * PI / 180
}

private fun kindOf(l: TileLayout) = when (l.pattern) { "brick2", "brick3", "herring" -> l.pattern; else -> "straight" }

/** How far a tile of [a] × [b] at angle [ang] reaches along the unit direction [d]. */
private fun reach(a: Double, b: Double, ang: Double, d: V2): Double {
    val c = cos(ang); val s = sin(ang)
    return abs(V2(c, s).dot(d)) * b + abs(V2(-s, c).dot(d)) * a
}

/** The pattern origin that puts the middle of a tile at [mid]. */
private fun originAt(mid: V2, a: Double, b: Double, ang: Double): V2 = mid - rot(V2(b / 2, a / 2), cos(ang), sin(ang))

/** The middle of the floor's first tile: the room's middle, its first corner or the door, moved by hand. */
fun floorStart(l: TileLayout, g: TRoomGeo): V2 {
    val a = l.a.toDouble(); val b = l.b.toDouble(); val ang = angleOf(l); val j = l.joint.toDouble()
    val door = g.room.openings.firstOrNull { it.type == "door" }?.let { o -> g.wall(o.wall)?.let { w -> w to (o.off + o.w / 2.0) } }
    val mid = when {
        l.start == "corner" -> { val w = g.walls[0]; w.p0 + w.t * ((reach(a, b, ang, w.t) + j) / 2) + w.nIn * ((reach(a, b, ang, w.nIn) + j) / 2) }
        l.start == "door" && door != null -> { val (w, u) = door; w.at(u) + w.nIn * ((reach(a, b, ang, w.nIn) + j) / 2) }
        else -> centroid(g.floor)
    }
    return mid + V2(l.ox.toDouble(), l.oy.toDouble())
}

fun centroid(v: List<V2>): V2 {
    var ar = 0.0; var cx = 0.0; var cy = 0.0
    v.forEachIndexed { i, p -> val q = v[(i + 1) % v.size]; val cr = p.x * q.y - q.x * p.y; ar += cr; cx += (p.x + q.x) * cr; cy += (p.y + q.y) * cr }
    return if (abs(ar) < 1e-9) V2(v.sumOf { it.x } / v.size, v.sumOf { it.y } / v.size) else V2(cx / (3 * ar), cy / (3 * ar))
}

/** The middle, along a wall, of its first tile: the wall's middle, its start corner, the door's edge, or in line with the floor's tiles. */
private fun wallStartU(l: TileLayout, g: TRoomGeo?, wallId: String?, len: Double, floorMid: V2?): Double {
    val a = l.a.toDouble(); val b = l.b.toDouble(); val ang = angleOf(l)
    val along = reach(a, b, ang, V2(1.0, 0.0))
    val w = wallId?.let { g?.wall(it) }
    if (l.align && w != null && floorMid != null) return (floorMid - w.p0).dot(w.t)
    return when (l.start) {
        "corner" -> along / 2
        "door" -> g?.room?.openings?.firstOrNull { it.wall == wallId && it.type == "door" }?.let { it.off + along / 2 } ?: len / 2
        else -> len / 2
    }
}

/**
 * Every piece of layout [l] on [surfs]; [floorMid] the room's floor tile middle the walls line up with (null: none);
 * [inset] see [lay]. A surface whose tiles are too many to work out has none ([tooMany] lists them).
 */
class Laid(val surfs: List<Surf>, val pieces: List<Piece>, val tooMany: Set<Int>)

fun layAll(l: TileLayout, surfs: List<Surf>, g: TRoomGeo?, floorMid: V2?, inset: Double = 0.0): Laid {
    val out = ArrayList<Piece>(); val many = HashSet<Int>()
    val a = l.a.toDouble(); val b = l.b.toDouble(); val j = l.joint.toDouble(); val ang = angleOf(l); val kind = kindOf(l)
    val chess = l.pattern == "chess"
    surfs.forEachIndexed { si, s ->
        val prod = if (s.alt) 1 else 0
        fun add(region: List<V2>, sp: Spec) { val ps = lay(region, s.holes, sp, si, inset); if (ps == null) many += si else out += ps }
        if (s.kind == "floor") {
            val mid = if (g != null && s.key == "floor") floorStart(l, g) else if (s.key == "panel") panelMid(l, s) else centroid(s.outline)
            if (l.pattern == "border") {
                // a strip of the second tile round the edge, mitred at the corners; the field inside it
                val bw = l.sa + j
                val inner = insetPoly(s.outline, bw)
                for (i in s.outline.indices) {
                    val p0 = s.outline[i]; val p1 = s.outline[(i + 1) % s.outline.size]
                    val d = p1 - p0; val ln = hypot(d.x, d.y); if (ln < 1) continue
                    val band = listOf(p0, p1, inner[(i + 1) % inner.size], inner[i])
                    add(band, Spec(p0, kotlin.math.atan2(d.y, d.x), l.sa.toDouble(), l.sb.toDouble(), j, "straight", false, 2))
                }
                add(inner, Spec(originAt(mid, a, b, angleOf(l.copy(pattern = "straight"))), angleOf(l.copy(pattern = "straight")), a, b, j, "straight", false, prod))
            } else add(s.outline, Spec(originAt(mid, a, b, ang), ang, a, b, j, kind, chess, prod))
        } else {
            val lo = s.lo
            val u = if (s.kind == "col" && (s.key.endsWith(":l") || s.key.endsWith(":r"))) reach(a, b, ang, V2(1.0, 0.0)) / 2 else wallStartU(l, g, s.wall, s.len, floorMid)
            val v = lo + reach(a, b, ang, V2(0.0, 1.0)) / 2
            if (l.pattern == "border" && s.kind != "col") {
                val b0 = l.band.toDouble().coerceIn(s.lo, s.hi); val b1 = (b0 + l.sa).coerceAtMost(s.hi)
                val bx = boxOf(s.outline)
                val sp = Spec(originAt(V2(u, v), a, b, 0.0), 0.0, a, b, j, "straight", false, prod)
                if (b0 - bx.y0 > 1) add(rect(bx.x0, bx.y0, bx.x1, b0 - j / 2), sp)
                if (bx.y1 - b1 > 1) add(rect(bx.x0, b1 + j / 2, bx.x1, bx.y1), Spec(originAt(V2(u, b1 + j / 2 + a / 2), a, b, 0.0), 0.0, a, b, j, "straight", false, prod))
                if (b1 - b0 > 1) add(rect(bx.x0, b0, bx.x1, b1), Spec(originAt(V2(u, (b0 + b1) / 2), l.sa.toDouble(), l.sb.toDouble(), 0.0), 0.0, l.sa.toDouble(), l.sb.toDouble(), j, "straight", false, 2))
            } else add(s.outline, Spec(originAt(V2(u, v), a, b, ang), ang, a, b, j, kind, chess, prod))
        }
    }
    return Laid(surfs, out, many)
}

/** A typed floor's first tile: its middle, or its first corner. */
private fun panelMid(l: TileLayout, s: Surf): V2 {
    val a = l.a.toDouble(); val b = l.b.toDouble(); val ang = angleOf(l)
    val c = if (l.start == "corner") V2((reach(a, b, ang, V2(1.0, 0.0)) + l.joint) / 2, (reach(a, b, ang, V2(0.0, 1.0)) + l.joint) / 2) else centroid(s.outline)
    return c + V2(l.ox.toDouble(), l.oy.toDouble())
}

/** The polygon [p] (the room's corner order) moved in by [d] on every side, mitred. */
fun insetPoly(p: List<V2>, d: Double): List<V2> {
    val n = p.size
    val nin = p.indices.map { i -> val q = p[(i + 1) % n] - p[i]; val l = hypot(q.x, q.y).takeIf { it > 0 } ?: 1.0; V2(-q.y / l, q.x / l) }
    val sg = if (area(p) >= 0) 1.0 else -1.0
    return p.indices.map { i ->
        val a = nin[(i - 1 + n) % n] * sg; val b = nin[i] * sg; val k = 1 + a.dot(b)
        if (k < .15) p[i] + b * d else p[i] + (a + b) * (d / k)
    }
}

/** The pieces of a layout in a room: its surfaces, then the tiles; the walls line up with the room's floor layout [floorOf]. */
fun layRoom(l: TileLayout, g: TRoomGeo, floorOf: TileLayout?, inset: Double = 0.0): Laid {
    val fm = floorOf?.takeIf { it.surfs.any { s -> s.id == "floor" } && (angleOf(it) * 180 / PI).let { d -> abs(d % 90) < 1e-6 } }?.let { floorStart(it, g) }
    return layAll(l, surfacesOf(l, g), g, fm, inset)
}

/** The room's floor layout the walls line up with: the first one that covers the floor. */
fun floorLayout(ls: List<TileLayout>, roomId: String) = ls.firstOrNull { it.roomId == roomId && it.surfs.any { s -> s.id == "floor" } }
