package uz.metrx.app.tiles

import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.geo.Face
import uz.metrx.app.geo.Group
import uz.metrx.app.geo.Part
import uz.metrx.app.geo.Role
import uz.metrx.app.geo.Shell3D
import uz.metrx.app.geo.V3
import uz.metrx.app.geo.buildShell
import kotlin.math.max

/*
 * The tiles in 3D: every piece at its true place on the room's floor and walls in front of a joint-coloured backing,
 * the cut pieces a shade off, the skirting, and the tray and bath. Pieces of one colour on one wall go into one part,
 * so the whole room is a few dozen meshes (an old phone stays smooth), and a wall's tiles fade with the wall when it
 * faces the camera.
 */

/** Most pieces drawn in one picture: past it a surface is drawn as one slab of its tile, without joints. */
const val MAX_DRAWN = 7000

/** How far in front of its surface a tile sits, and its joints' backing, metres. */
private const val TILE_OFF = .004
private const val GROUT_OFF = .0022

/** The joints' colour for a tile: light grey for light tiles, dark grey for dark ones. */
fun groutOf(rgb: Int): Int = if (lum(rgb) > .45) 0xBEBCB6 else 0x3E3F42

fun lum(rgb: Int): Double = (.299 * ((rgb shr 16) and 255) + .587 * ((rgb shr 8) and 255) + .114 * (rgb and 255)) / 255

fun mixRgb(a: Int, b: Int, k: Double): Int {
    fun c(s: Int) = (((a shr s) and 255) * (1 - k) + ((b shr s) and 255) * k).toInt().coerceIn(0, 255)
    return (c(16) shl 16) or (c(8) shl 8) or c(0)
}

fun scaleRgb(a: Int, k: Double): Int {
    fun c(s: Int) = (((a shr s) and 255) * k).toInt().coerceIn(0, 255)
    return (c(16) shl 16) or (c(8) shl 8) or c(0)
}

/** A cut piece's shade: the tile's colour turned a little amber, so cuts show on light and dark tiles alike. */
fun cutRgb(rgb: Int, k: Double = .3) = mixRgb(rgb, 0xE0812F, k)

/** The tile's colour for one tile of a drawn look: wood planks and concrete vary from tile to tile, marble a little. */
fun toneOf(look: Look, seed: Int): Int {
    val ks = when (look.kind) { "w" -> doubleArrayOf(1.0, .9, 1.06, .95); "k" -> doubleArrayOf(1.0, .94, 1.05); "m" -> doubleArrayOf(1.0, .975, 1.015); else -> return look.rgb }
    return scaleRgb(look.rgb, ks[Math.floorMod(seed * 7 + (seed shr 3), ks.size)])
}

/** The look of a piece of layout [l]: the main one or the second. */
fun lookFor(l: TileLayout, prod: Int) = lookOf(if (prod == 0) l.look else l.look2)

/** The drawing's joint: at least 4 mm so a 1–2 mm joint still shows from across the room (the tiles keep their true pitch). */
fun drawInset(l: TileLayout) = max(0.0, (4.0 - l.joint) / 2)

/** Parts keyed by wall and colour as they fill. */
private class Parts { val map = LinkedHashMap<String, Part>()
    fun of(wall: String?, rgb: Int, role: Role): Part = map.getOrPut("$wall|$rgb|$role") { Part(0, wall, role, rgb, 1f, tile = true) }
}

private fun face(p: Part, fr: Frame, poly: List<V2>, off: Double) {
    if (poly.size < 3) return
    p.faces += Face(fr.n, poly.map { fr.at(it.x, it.y, off) })
}

/** The pieces of [laid] into [ps]; a surface past the budget [left] (pieces) as one slab. Returns what is left. */
private fun addLaid(ps: Parts, l: TileLayout, laid: Laid, left0: Int): Int {
    var left = left0
    val bySurf = laid.pieces.groupBy { it.s }
    laid.surfs.forEachIndexed { si, s ->
        val role = if (s.kind == "floor") Role.FLOOR else Role.OPENING
        val pcs = bySurf[si].orEmpty()
        val main = lookFor(l, if (s.alt) 1 else 0)
        val backing = convexParts(s.outline).flatMap { part -> s.holes.fold(listOf(part)) { acc, h -> acc.flatMap { subtract(it, h) } } }
        if (pcs.size > left || si in laid.tooMany) {
            // too many to draw: the surface in its tile's colour
            backing.forEach { face(ps.of(s.wall, main.rgb, role), s.frame, it, TILE_OFF) }
            return@forEachIndexed
        }
        left -= pcs.size
        backing.forEach { face(ps.of(s.wall, groutOf(main.rgb), role), s.frame, it, GROUT_OFF) }
        pcs.forEach { pc ->
            val lk = lookFor(l, pc.prod)
            val rgb = if (pc.cut) cutRgb(lk.rgb) else toneOf(lk, pc.seed)
            pc.polys.forEach { face(ps.of(s.wall, rgb, role), s.frame, it, TILE_OFF) }
        }
    }
    return left
}

/** A box between two plan points' heights: its footprint [fp] (scene points at the floor) up to [h] metres. */
private fun box(p: Part, fp: List<V3>, h: Double) {
    val top = fp.map { V3(it.x, h, it.z) }
    p.faces += Face(V3(0.0, 1.0, 0.0), top)
    val cx = fp.sumOf { it.x } / fp.size; val cz = fp.sumOf { it.z } / fp.size
    for (i in fp.indices) {
        val a = fp[i]; val b = fp[(i + 1) % fp.size]
        var nx = b.z - a.z; var nz = -(b.x - a.x)
        val l = kotlin.math.hypot(nx, nz).takeIf { it > 0 } ?: continue
        nx /= l; nz /= l
        if (((a.x + b.x) / 2 - cx) * nx + ((a.z + b.z) / 2 - cz) * nz < 0) { nx = -nx; nz = -nz }
        p.faces += Face(V3(nx, 0.0, nz), listOf(a, b, V3(b.x, h, b.z), V3(a.x, h, a.z)))
    }
}

/** The skirting of layout [l] in its tile: pieces [l.b] long, [l.skirt] high, along its runs. */
private fun addSkirt(ps: Parts, l: TileLayout, runs: List<Run>) {
    if (runs.isEmpty()) return
    val lk = lookOf(l.look)
    val pitch = l.b + l.joint.toDouble(); val gap = max(l.joint.toDouble(), 4.0)
    runs.forEach { r ->
        var a = r.a0; var k = 0
        while (a < r.a1 - 1) {
            val e = minOf(a + l.b, r.a1)
            val p = ps.of(r.wall, if (e - a < l.b - 1) cutRgb(lk.rgb) else toneOf(lk, k), Role.OPENING)
            face(p, r.frame, listOf(V2(a + gap / 2, 0.0), V2(e - gap / 2, 0.0), V2(e - gap / 2, l.skirt.toDouble()), V2(a + gap / 2, l.skirt.toDouble())), .009)
            a += pitch; k++
        }
    }
}

/** The 3D parts of the room's layouts [ls] (the order's [all] decide the lining up and the skirting), and its tray and bath. */
fun tileParts(ls: List<TileLayout>, g: TRoomGeo, all: List<TileLayout>, cap: Int = MAX_DRAWN): List<Part> {
    val ps = Parts()
    var left = cap
    val fl = floorLayout(all, g.room.id)
    for (l in ls) {
        left = addLaid(ps, l, layRoom(l, g, fl?.takeIf { it.id != l.id }, drawInset(l)), left)
        addSkirt(ps, l, skirtRuns(l, g, all))
    }
    g.fixes.forEach { f ->
        val fp = footprint(g, f) ?: return@forEach
        // a bath's front is tiled when a layout covers it, so it stands just behind its tiles
        box(ps.of(null, if (f.type == "bath") 0xF7F7F4 else 0xF1F2F0, Role.FURN), fp.map { g.scene(it) }, f.h / 1000.0)
    }
    return ps.map.values.toList()
}

/* ---------------- a surface without a room ---------------- */

/** The made-up room a typed surface is shown in: the floor alone, or the wall (a backsplash over a worktop). */
private fun panelRoom(p: TPanel): Room {
    val floor = p.kind == "floor"
    val h = if (floor) 2400 else p.b + if (p.kind == "apron") APRON_H0 + 300 else 0
    return Room("panel", "", "", dims = mapOf("A" to Dim(p.a), "B" to Dim(if (floor) p.b else 1400), "H" to Dim(h), "T" to Dim(120, "default")), floorColor = "#DDE2E8")
}

/** The 3D of a layout without a room: a flat floor, or a wall panel (a backsplash over a worktop), with its real tiles. */
fun panelScene(l: TileLayout, cap: Int = MAX_DRAWN): Shell3D? {
    val p = l.panel ?: return null
    if (p.a <= 0 || p.b <= 0) return null
    val base = buildShell(listOf(panelRoom(p)), true)
    val T = .12
    val shell = if (p.kind == "floor") base.floorOnly()
        else Shell3D(base.parts.filter { it.role == Role.FLOOR || (it.wall == "A" && it.role == Role.WALL) }, base.edges.filter { it.wall == "A" },
            base.groups.map { Group(it.cx, it.cz, emptyMap()) }, emptyList(), null, base.L, base.W, base.H, base.tgt, base.r, base.theta, base.phi, base.bounds, base.rMin, base.fit,
            base.gridSize, base.gridDiv, base.gridCx, base.gridCz, base.light, base.far, base.bases)
    val y0 = if (p.kind == "apron") APRON_H0 / 1000.0 else 0.0
    val frame = if (p.kind == "floor") Frame(V3(T, 0.0, 0.0), V3(1.0, 0.0, 0.0), V3(0.0, 0.0, 1.0), V3(0.0, 1.0, 0.0))
        else Frame(V3(T, y0, 0.0), V3(1.0, 0.0, 0.0), V3(0.0, 1.0, 0.0), V3(0.0, 0.0, 1.0))
    val s = panelSurf(l, frame) ?: return null
    val ps = Parts()
    addLaid(ps, l, layAll(l, listOf(s), null, null, drawInset(l)), cap)
    if (p.kind == "apron") {
        // the worktop and the units under it
        val fp = listOf(V3(T, 0.0, 0.0), V3(T + p.a / 1000.0, 0.0, 0.0), V3(T + p.a / 1000.0, 0.0, .6), V3(T, 0.0, .6))
        box(ps.of(null, 0xF4F4F2, Role.FURN), fp, y0 - .04)
        val top = Part(0, null, Role.FURN, 0x8A7560, 1f, tile = true)
        box(top, fp.map { V3(it.x, 0.0, it.z) }, y0)
        // only the worktop's top band: lift its faces onto the units
        top.faces.replaceAll { f -> Face(f.n, f.pts.map { q -> V3(q.x, if (q.y > 0) y0 else y0 - .04, q.z) }) }
        return shell.plus(ps.map.values.toList() + top, emptyList())
    }
    return shell.plus(ps.map.values.toList(), emptyList())
}
