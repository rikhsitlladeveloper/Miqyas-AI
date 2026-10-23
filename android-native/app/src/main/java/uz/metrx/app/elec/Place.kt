package uz.metrx.app.elec

import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.tiles.TRoomGeo
import uz.metrx.app.tiles.TWall
import uz.metrx.app.tiles.V2
import uz.metrx.app.tiles.roomGeo
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * A room as the devices see it, the room kits, and placing: a kit's points put on the walls and ceiling at their usual
 * spots, clear of the doors, windows, the door's swing and the water and gas; a device dragged on its wall snaps to
 * the usual heights and lines and is kept off the doors and windows.
 */

/** Water and gas on the walls: what sockets keep away from. */
val WATER = setOf("cold", "hot", "sewer")
val GAS = setOf("gas", "meter")
const val WATER_MM = 600
const val GAS_MM = 500

/**
 * One room for the electrician: a measured room, or one typed by size ([free], drawn as a plain box with a door). [g]
 * its walls and floor (plan mm), [kind] what room it is, [er] its settings, [entry] the door the cables come in by.
 */
class ECtx(val id: String, val room: Room, val g: TRoomGeo, val kind: String, val er: ElecRoom, val free: ElecFree? = null) {
    val H get() = g.H.toInt()
    val doors get() = room.openings.filter { it.type == "door" }
    val entry: Opening? get() = doors.firstOrNull { it.id == er.door } ?: doors.firstOrNull()
    fun wall(id: String?) = id?.let { g.wall(it) }
    /** Water and gas points on the walls. */
    val wet: List<SitePoint> get() = room.points.filter { it.t in WATER || it.t in GAS }
    /** The plan point of a device's centre (a wall device: on the wall's face). */
    fun planOf(d: ElecDev): V2 = if (d.onCeiling) V2(d.cx.toDouble(), d.cy.toDouble()) else wall(d.wall)?.at(d.off.toDouble()) ?: V2(d.cx.toDouble(), d.cy.toDouble())
    fun planOf(x: SitePoint): V2? = wall(x.wall)?.at(x.off.toDouble())
}

/** The made-up room of a room typed by size: [f]'s box with a door on wall A. */
fun freeRoom(f: ElecFree) = Room("free:${f.id}", "", f.name, dims = mapOf("A" to Dim(f.L), "B" to Dim(f.W), "H" to Dim(f.H), "T" to Dim(120, "default")),
    openings = listOf(Opening("fd", "door", "A", 900, minOf(2100, f.H - 200), 300)), floorColor = "#DDE2E8")

/** Room [rid] of order [p], ready for devices (null: not measured yet). [kindOf] the room's kind when not set ([guessKind]). */
fun ctxOf(p: Project, rid: String, snap: Boolean): ECtx? {
    if (rid.startsWith("free:")) return p.elec.free.firstOrNull { "free:${it.id}" == rid }?.let { freeCtx(it) }
    val r = p.rooms.firstOrNull { it.id == rid } ?: return null
    val g = roomGeo(r, snap, emptyList()) ?: return null
    val er = p.elec.room(rid)
    val kind = er.kind.ifEmpty { guessKind(p.floors.firstOrNull { it.id == r.floorId }?.type, r.name) }
    return ECtx(rid, r, g, kind, er)
}

fun freeCtx(f: ElecFree): ECtx? {
    val r = freeRoom(f)
    val g = roomGeo(r, true, emptyList()) ?: return null
    return ECtx(r.id, r, g, f.kind, ElecRoom(r.id, f.kind, link = f.link), f)
}

/** Every room of the order that devices can be in: the measured ones in order, then the typed ones. */
fun ctxs(p: Project, snap: Boolean): List<ECtx> =
    p.rooms.mapNotNull { ctxOf(p, it.id, snap) } + p.elec.free.mapNotNull { freeCtx(it) }

/** The devices of a room: placed ones, or a typed room's made from its counts. */
fun devsIn(p: Project, c: ECtx): List<ElecDev> = if (c.free != null) freeDevs(c.free, c) else p.elec.devs.filter { it.roomId == c.id }

/* ---------------- walls: what is in the way ---------------- */

/** Something on a wall a device must not overlap: [a0]…[a1] along it, [b0]…[b1] up, mm. */
class Block(val a0: Double, val a1: Double, val b0: Double, val b1: Double) {
    fun hits(x0: Double, x1: Double, y0: Double, y1: Double) = x0 < a1 && a0 < x1 && y0 < b1 && b0 < y1
}

/** The stretch behind a door when it stands open (its hinge side, as wide as the door): no switch there. */
fun swingBlock(o: Opening) = Block(o.off - o.w.toDouble(), o.off.toDouble(), 0.0, o.h.toDouble())

/**
 * What is in the way of a device of type [t] on wall [wall]: the doors and windows with their frames, the columns and
 * niches; for a switch the door's swing; for a socket the water ([WATER_MM]) and gas ([GAS_MM]); the other devices
 * [devs] and the panel. [skip] a device being moved.
 */
fun blocksOn(c: ECtx, wall: String, t: String, devs: List<ElecDev>, panel: ElecPanel? = null, skip: String? = null, openingsOnly: Boolean = false): List<Block> {
    val out = ArrayList<Block>()
    c.room.openings.filter { it.wall == wall }.forEach { o ->
        if (o.type == "door") out += Block(o.off - 120.0, o.off + o.w + 120.0, -1.0, o.h + 80.0)
        else out += Block(o.off - 100.0, o.off + o.w + 100.0, o.sill - 100.0, o.sill + o.h + 100.0)
    }
    if (c.g.rect) c.room.features.filter { it.wall == wall }.forEach { f ->
        if (f.type == "column") out += Block(f.off - 50.0, f.off + f.w + 50.0, -1.0, c.g.H + 1)
        else out += Block(f.off - 50.0, f.off + f.w + 50.0, f.sill - 50.0, (if (f.h > 0) f.sill + f.h else c.H) + 50.0)
    }
    if (openingsOnly) return out
    val ty = devType(t)
    if (ty.cat == "sw") c.room.openings.filter { it.wall == wall && it.type == "door" }.forEach { out += swingBlock(it) }
    if (ty.cat == "sock") c.wet.filter { it.wall == wall }.forEach { x ->
        val r = if (x.t in WATER) WATER_MM else GAS_MM
        out += Block(x.off - r.toDouble(), x.off + r.toDouble(), x.h - r.toDouble(), x.h + r.toDouble())
    }
    devs.filter { it.wall == wall && it.id != skip }.forEach { d ->
        val (dw, dh) = devSize(d)
        out += Block(d.off - dw / 2.0 - 60, d.off + dw / 2.0 + 60, d.h - dh / 2.0 - 60, d.h + dh / 2.0 + 60)
    }
    if (panel != null && panel.roomId == c.id && panel.wall == wall) {
        val (pw, ph) = panelSize(0)
        out += Block(panel.off - pw / 2.0 - 100, panel.off + pw / 2.0 + 100, panel.h - ph / 2.0 - 100, panel.h + ph / 2.0 + 100)
    }
    return out
}

/**
 * The free spot nearest [prefer] along wall [wall] for a [dw] × [dh] device centred [h] up, mm, clear of [blocks] and
 * 100 from the corners; null when the wall has none.
 */
fun spotOn(w: TWall, prefer: Double, h: Int, dw: Int, dh: Int, blocks: List<Block>): Int? {
    val lo = dw / 2.0 + 100; val hi = w.len - dw / 2.0 - 100
    if (hi < lo) return null
    val p0 = prefer.coerceIn(lo, hi)
    val y0 = h - dh / 2.0; val y1 = h + dh / 2.0
    fun free(x: Double) = blocks.none { it.hits(x - dw / 2.0, x + dw / 2.0, y0, y1) }
    var k = 0
    while (k * 10.0 <= w.len) {
        val a = p0 + k * 10; if (a <= hi && free(a)) return a.roundToInt()
        val b = p0 - k * 10; if (k > 0 && b >= lo && free(b)) return b.roundToInt()
        k++
    }
    return null
}

/* ---------------- choosing the walls ---------------- */

private fun hasType(c: ECtx, w: TWall, type: String) = c.room.openings.any { it.wall == w.id && it.type == type }

/** The room's main wall (beds, TVs): long, without a door, best without a window. */
fun mainWall(c: ECtx): TWall = c.g.walls.maxBy { w -> w.len - (if (hasType(c, w, "door")) 5000 else 0) - (if (hasType(c, w, "window")) 1500 else 0) }

/** The worktop's (or a bathroom's sink) wall: the one with most water on it, else a long one without a door. */
fun workWall(c: ECtx): TWall {
    val wet = c.room.points.filter { it.t in WATER }
    if (wet.isNotEmpty()) return c.g.walls.maxBy { w -> wet.count { it.wall == w.id } * 100_000.0 + w.len }
    return c.g.walls.maxBy { w -> w.len - (if (hasType(c, w, "door")) 5000 else 0) - (if (hasType(c, w, "window")) 300 else 0) }
}

/** A wall with a window (a desk stands at it), else the main wall. */
fun windowWall(c: ECtx): TWall = c.g.walls.filter { hasType(c, it, "window") }.maxByOrNull { it.len } ?: mainWall(c)

/** The water point on wall [w] (a sink), along it. */
private fun waterOn(c: ECtx, w: TWall) = c.room.points.firstOrNull { it.wall == w.id && it.t in WATER }?.off

/* ---------------- kits ---------------- */

/** One point of a kit: type [t] placed by rule [at] ([n] of them), at height [h] (null: the usual), [dx] from the rule's spot. */
class KItem(val t: String, val at: String, val n: Int = 1, val h: Int? = null, val dx: Int = 0)

/** A room kit of the gallery: the points a room of [kind] usually gets. */
class Kit(val id: String, val kind: String, val items: List<KItem>)

val KITS = listOf(
    Kit("kt.std", "kitchen", listOf(KItem("k2", "door"), KItem("lc", "ceil"), KItem("led", "under"), KItem("s2", "work", 3, 1100), KItem("pst", "stove"),
        KItem("pov", "oven"), KItem("s1", "fridge"), KItem("s1", "hood", h = 2000), KItem("s1", "dw"), KItem("jb", "box"))),
    Kit("kt.spots", "kitchen", listOf(KItem("k2", "door"), KItem("ls", "spots"), KItem("led", "under"), KItem("s2", "work", 4, 1100), KItem("pst", "stove"),
        KItem("s1", "fridge"), KItem("s1", "hood", h = 2000), KItem("jb", "box"))),
    Kit("kt.small", "kitchen", listOf(KItem("k1", "door"), KItem("lc", "ceil"), KItem("s2", "work", 2, 1100), KItem("s1", "fridge"), KItem("s1", "hood", h = 2000), KItem("jb", "box"))),
    Kit("bt.std", "bath", listOf(KItem("k2", "door"), KItem("ls", "spots"), KItem("lw", "mirror"), KItem("sw", "mirrorS"), KItem("pwh", "wh"), KItem("sw", "wm", h = 1000), KItem("jb", "box"))),
    Kit("bt.small", "bath", listOf(KItem("k1", "door"), KItem("lc", "ceil"), KItem("sw", "mirrorS"), KItem("sw", "wm", h = 1000), KItem("jb", "box"))),
    Kit("bd.std", "bed", listOf(KItem("k1", "door"), KItem("lch", "ceil"), KItem("s2", "bed", 2, 700), KItem("lw", "bed", 2, 1300), KItem("s1", "corner", 2),
        KItem("pac", "ac"), KItem("jb", "box"))),
    Kit("bd.kids", "bed", listOf(KItem("k1", "door"), KItem("lc", "ceil"), KItem("s1", "corner", 3), KItem("s2", "desk", dx = 0), KItem("lan", "desk", dx = 250), KItem("jb", "box"))),
    Kit("lv.tv", "living", listOf(KItem("k2", "door"), KItem("lch", "ceil"), KItem("tv", "tv", dx = -180), KItem("s2", "tv", dx = 180), KItem("lan", "tv", dx = -380),
        KItem("led", "cove"), KItem("s1", "corner", 3), KItem("pac", "ac"), KItem("jb", "box"))),
    Kit("lv.spots", "living", listOf(KItem("kd", "door"), KItem("ls", "spots"), KItem("tv", "tv", dx = -180), KItem("s2", "tv", dx = 180), KItem("s1", "corner", 2),
        KItem("lw", "pair", 2), KItem("pac", "ac"), KItem("jb", "box"))),
    Kit("hl.std", "hall", listOf(KItem("kp", "door"), KItem("lc", "row", 2), KItem("s1", "doorIn"), KItem("int", "door2"), KItem("bell", "door3"), KItem("jb", "box"))),
    Kit("hl.spots", "hall", listOf(KItem("k1", "door"), KItem("ls", "row", 4), KItem("s1", "doorIn"), KItem("int", "door2"), KItem("cam", "cam"), KItem("jb", "box"))),
    Kit("of.std", "office", listOf(KItem("k1", "door"), KItem("lc", "ceil"), KItem("s2", "desk", dx = -200), KItem("s2", "desk", dx = 200), KItem("lan", "desk", dx = 450),
        KItem("su", "desk", dx = -450), KItem("s1", "corner", 2), KItem("pac", "ac"), KItem("jb", "box")))
)

fun kitOf(id: String) = KITS.firstOrNull { it.id == id }

/** A kit's choices (the steps): the main light ("lc", "lch", "ls"; "" as the kit has), an LED strip, AC power, the low-voltage points. */
data class KitOpts(val light: String = "", val led: Boolean = true, val ac: Boolean = true, val low: Boolean = true)

fun defaultOpts(k: Kit) = KitOpts("", k.items.any { it.t == "led" }, k.items.any { it.t == "pac" }, k.items.any { devType(it.t).cat == "low" })

/** The kit's points with the choices made. */
fun kitItems(k: Kit, o: KitOpts): List<KItem> {
    var items = k.items
    if (o.light.isNotEmpty()) items = items.map { i ->
        if (devType(i.t).ceil) when {
            o.light == "ls" && i.at == "ceil" -> KItem("ls", "spots")
            o.light == "ls" -> KItem("ls", i.at, maxOf(i.n, 3))
            i.at == "spots" -> KItem(o.light, "ceil")
            else -> KItem(o.light, i.at, if (i.at == "row") i.n.coerceAtMost(2) else i.n)
        } else i
    }
    if (!o.led) items = items.filter { it.t != "led" } else if (items.none { it.t == "led" }) items = items + KItem("led", if (k.kind == "kitchen") "under" else "cove")
    if (!o.ac) items = items.filter { it.t != "pac" } else if (items.none { it.t == "pac" } && k.kind != "bath" && k.kind != "hall") items = items + KItem("pac", "ac")
    if (!o.low) items = items.filter { devType(it.t).cat != "low" }
    return items
}

/** Spots over the ceiling: a grid about 1,1 m apart, 0,5 m and more from the walls, inside the room. */
fun spotGrid(c: ECtx): List<V2> {
    val f = c.g.floor
    val x0 = f.minOf { it.x }; val x1 = f.maxOf { it.x }; val y0 = f.minOf { it.y }; val y1 = f.maxOf { it.y }
    val nx = ((x1 - x0 - 600) / 1100).roundToInt().coerceIn(1, 6); val ny = ((y1 - y0 - 600) / 1100).roundToInt().coerceIn(1, 6)
    val out = ArrayList<V2>()
    for (i in 0 until nx) for (k in 0 until ny) {
        val q = V2(x0 + (x1 - x0) * (i + .5) / nx, y0 + (y1 - y0) * (k + .5) / ny)
        if (inside(f, q)) out += q
    }
    return out
}

/** Lights in a row along the room's longer side. */
fun rowOf(c: ECtx, n: Int): List<V2> {
    val f = c.g.floor
    val x0 = f.minOf { it.x }; val x1 = f.maxOf { it.x }; val y0 = f.minOf { it.y }; val y1 = f.maxOf { it.y }
    val along = x1 - x0 >= y1 - y0
    return (0 until n).map { i ->
        if (along) V2(x0 + (x1 - x0) * (i + .5) / n, (y0 + y1) / 2) else V2((x0 + x1) / 2, y0 + (y1 - y0) * (i + .5) / n)
    }.filter { inside(f, it) }.ifEmpty { listOf(centreOf(c)) }
}

/** The middle of the room's floor (its centroid; inside it). */
fun centreOf(c: ECtx): V2 = centreOf(c.g.floor)

/** The middle of floor outline [f] (its centroid; inside it). */
fun centreOf(f: List<V2>): V2 {
    var a = 0.0; var cx = 0.0; var cy = 0.0
    f.indices.forEach { i -> val p = f[i]; val q = f[(i + 1) % f.size]; val k = p.x * q.y - q.x * p.y; a += k; cx += (p.x + q.x) * k; cy += (p.y + q.y) * k }
    val m = if (abs(a) < 1e-6) V2(f.sumOf { it.x } / f.size, f.sumOf { it.y } / f.size) else V2(cx / (3 * a), cy / (3 * a))
    return if (inside(f, m)) m else V2(f.sumOf { it.x } / f.size, f.sumOf { it.y } / f.size)
}

/** Whether plan point [q] is inside the floor [f] (even-odd). */
fun inside(f: List<V2>, q: V2): Boolean {
    var c = false
    for (i in f.indices) {
        val a = f[i]; val b = f[(i + 1) % f.size]
        if ((a.y > q.y) != (b.y > q.y) && q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x) c = !c
    }
    return c
}

/** How many points kit [k] (with choices [o]) asks for in room [c] (its spots by the ceiling's grid). */
fun kitWanted(k: Kit, c: ECtx, o: KitOpts = defaultOpts(k)): Int = kitItems(k, o).sumOf { i ->
    when (i.at) {
        "spots" -> spotGrid(c).size
        "row" -> rowOf(c, i.n).size
        "bed", "pair" -> minOf(i.n, 2)
        "main", "work", "corner" -> i.n
        else -> 1
    }
}

/**
 * The points of kit [k] (with choices [o]) placed in room [c] among the devices it already has ([have]): each at its
 * usual height, the spot its rule picks, moved along the wall clear of what is in the way. [id] makes the new ids.
 */
fun placeKit(k: Kit, c: ECtx, have: List<ElecDev>, id: () -> String, o: KitOpts = defaultOpts(k), panel: ElecPanel? = null): List<ElecDev> {
    val out = ArrayList<ElecDev>()
    val H = c.H
    val entry = c.entry
    val dw0 = entry?.let { c.wall(it.wall) } ?: c.g.walls.first()
    val main = mainWall(c); val work = workWall(c); val win = windowWall(c)
    val others = c.g.walls.filter { it.id != main.id && it.id != dw0.id }.ifEmpty { c.g.walls.filter { it.id != main.id } }.ifEmpty { c.g.walls }
    var corner = 0
    val sinkX = waterOn(c, work)?.toDouble()
    // the stove: away from the sink, else at the worktop's far part
    val stoveX = sinkX?.let { s -> if (s + 1200 < work.len - 300) s + 1200.0 else max(400.0, s - 1200.0) } ?: (work.len * .7)
    fun put(t: String, w: TWall, prefer: Double, h: Int, len: Int = 0) {
        val ty = devType(t)
        if (t == "led") {
            // a strip goes on the longest stretch of the wall clear of its doors and windows at its height
            val (a, b) = freeStretch(c, w, h) ?: return
            val l = minOf(len, (b - a - 100).toInt()); if (l < 300) return
            val x = if (b - a >= len + 100) prefer.coerceIn(a + len / 2.0 + 50, b - len / 2.0 - 50) else (a + b) / 2
            out += ElecDev(id(), t, c.id, w.id, x.roundToInt(), h, len = l, kit = k.id)
            return
        }
        val x = spotOn(w, prefer, h, ty.dw, ty.dh, blocksOn(c, w.id, t, have + out, panel)) ?: return
        out += ElecDev(id(), t, c.id, w.id, x, h, kit = k.id)
    }
    fun ceil(t: String, q: V2) { out += ElecDev(id(), t, c.id, null, cx = q.x.roundToInt(), cy = q.y.roundToInt(), kit = k.id) }
    val doorEnd = entry?.let { (it.off + it.w).toDouble() } ?: 300.0
    for (item in kitItems(k, o)) {
        val ty = devType(item.t)
        val h = item.h ?: usualH(item.t, H, c.kind)
        when (item.at) {
            "door" -> put(item.t, dw0, doorEnd + 150 + ty.dw / 2.0, h)
            "door2" -> put(item.t, dw0, doorEnd + 420 + ty.dw / 2.0, h)
            "door3" -> put(item.t, dw0, doorEnd + 650 + ty.dw / 2.0, h)
            "doorIn" -> put(item.t, dw0, doorEnd + 450, h)
            "cam" -> put(item.t, dw0, doorEnd + 700, h)
            "box" -> put(item.t, dw0, entry?.let { e -> e.off + e.w / 2.0 } ?: 400.0, absH(-ZONE_DOWN, H))
            "main" -> repeat(item.n) { i -> put(item.t, main, main.len * (i + 1) / (item.n + 1), h) }
            "bed" -> listOf(-1, 1).take(item.n).forEach { s -> put(item.t, main, main.len / 2 + s * 1050.0 + item.dx, h) }
            "pair" -> listOf(-1, 1).take(item.n).forEach { s -> val w = others.first(); put(item.t, w, w.len / 2 + s * 800.0, h) }
            "tv" -> put(item.t, main, main.len / 2 + item.dx, h)
            "desk" -> put(item.t, win, win.len / 3 + item.dx, h)
            "corner" -> repeat(item.n) {
                val w = others[(corner / 2) % others.size]
                put(item.t, w, if (corner % 2 == 0) 400.0 else w.len - 400, h); corner++
            }
            "work" -> repeat(item.n) { i -> put(item.t, work, work.len * (i + 1) / (item.n + 1), h) }
            "stove" -> put(item.t, work, stoveX, h)
            "oven" -> put(item.t, work, stoveX + 350, h)
            "hood" -> put(item.t, work, stoveX, h)
            "fridge" -> put(item.t, work, if (sinkX != null && sinkX > work.len / 2) 350.0 else work.len - 350, h)
            "dw" -> put(item.t, work, (sinkX ?: work.len / 2.0) + 650, h)
            "ac" -> put(item.t, main, main.len - 450, h)
            "wh" -> put(item.t, work, (sinkX ?: (work.len - 500.0)) + 700, h)
            "mirror" -> put(item.t, work, sinkX?.toDouble() ?: (work.len / 2), h)
            "mirrorS" -> put(item.t, work, (sinkX ?: (work.len / 2.0)) + 650, h)
            "wm" -> { val w = others.firstOrNull { it.id != work.id } ?: work; put(item.t, w, w.len - 450, h) }
            "cove" -> put("led", main, main.len / 2, absH(-60, H), (main.len - 300).toInt().coerceAtLeast(300))
            "under" -> { val l = (work.len - 400).coerceAtMost(2400.0).toInt().coerceAtLeast(300); put("led", work, work.len / 2, 1450, l) }
            "ceil" -> ceil(item.t, centreOf(c))
            "spots" -> spotGrid(c).forEach { q -> ceil(item.t, q) }
            "row" -> rowOf(c, item.n).forEach { q -> ceil(item.t, q) }
        }
    }
    return out
}

/** The longest stretch of wall [w] at height [h] clear of its doors and windows (with their frames), mm along it. */
fun freeStretch(c: ECtx, w: TWall, h: Int): Pair<Double, Double>? {
    val cuts = blocksOn(c, w.id, "led", emptyList(), openingsOnly = true).filter { it.b0 <= h && it.b1 >= h }.map { it.a0 to it.a1 }.sortedBy { it.first }
    val out = ArrayList<Pair<Double, Double>>(); var cur = 50.0
    cuts.forEach { (a, b) -> if (a > cur) out += cur to a; cur = max(cur, b) }
    if (w.len - 50 > cur) out += cur to w.len - 50
    return out.maxByOrNull { it.second - it.first }
}

/* ---------------- a room typed by size ---------------- */

/** A typed room's devices from its counts: switches by the door, sockets round the walls, lights over the ceiling. */
fun freeDevs(f: ElecFree, c: ECtx): List<ElecDev> {
    val out = ArrayList<ElecDev>()
    var n = 0
    fun id() = "f:${f.id}:${n++}"
    val door = c.entry
    val a = c.g.wall("A")!!
    val dEnd = (door?.let { it.off + it.w } ?: 300).toDouble()
    repeat(f.sw.coerceIn(0, 20)) { i -> spotOn(a, dEnd + 200 + i * 180.0, 900, 86, 86, blocksOn(c, "A", "k1", out))?.let { x -> out += ElecDev(id(), "k1", c.id, "A", x, 900) } }
    val ws = c.g.walls.filter { it.id != "A" } + a
    var k = 0
    // a bathroom's sockets are splash-proof ones
    val st = if (c.kind == "bath") "sw" else "s1"
    val sh = usualH(st, c.H, c.kind)
    repeat(f.sock.coerceIn(0, 60)) { _ ->
        val w = ws[k % ws.size]; val slot = k / ws.size; k++
        val prefer = w.len * (slot % 3 + 1) / 4
        spotOn(w, prefer, sh, 86, 86, blocksOn(c, w.id, st, out))?.let { x -> out += ElecDev(id(), st, c.id, w.id, x, sh) }
    }
    // each power point as its kit had it (a stove's on its 32 A line, a water heater's high), at its usual height
    repeat(f.power.coerceIn(0, 10)) { i ->
        val t = f.powers.getOrNull(i) ?: "pac"
        val h = usualH(t, c.H, c.kind)
        val w = ws[(i + 1) % ws.size]
        spotOn(w, w.len - 400.0 - (if (t == "pac") 0.0 else 700.0 * (i % 2)), h, 86, 86, blocksOn(c, w.id, t, out))?.let { x -> out += ElecDev(id(), t, c.id, w.id, x, h) }
    }
    repeat(f.low.coerceIn(0, 20)) { i ->
        val w = c.g.walls[(2 + i) % c.g.walls.size]
        spotOn(w, w.len / 2 + i * 200.0, 300, 86, 86, blocksOn(c, w.id, "lan", out))?.let { x -> out += ElecDev(id(), "lan", c.id, w.id, x, 300) }
    }
    val lights = f.light.coerceIn(0, 40)
    val pts = if (lights <= 1) listOf(centreOf(c)) else rowOf(c, lights)
    pts.take(lights).forEach { q -> out += ElecDev(id(), if (lights <= 1) "lc" else "ls", c.id, null, cx = q.x.roundToInt(), cy = q.y.roundToInt()) }
    return out
}

/** A kit's counts for a room typed by size: sockets, switches, lights, low-voltage and power points. */
fun freeOf(k: Kit, o: KitOpts, id: String, name: String, L: Int, W: Int, H: Int): ElecFree {
    val items = kitItems(k, o)
    fun cnt(f: (KItem) -> Boolean) = items.filter(f).sumOf { if (it.at == "bed" || it.at == "pair") it.n else if (it.at == "spots") 4 else it.n }
    return ElecFree(id, name, k.kind, L, W, H,
        sock = cnt { devType(it.t).cat == "sock" && devType(it.t).group == "sock" },
        sw = cnt { devType(it.t).cat == "sw" },
        light = cnt { devType(it.t).ceil },
        low = cnt { devType(it.t).cat == "low" },
        power = cnt { devType(it.t).cat == "sock" && devType(it.t).group != "sock" }, kit = k.id,
        powers = items.filter { devType(it.t).cat == "sock" && devType(it.t).group != "sock" }.flatMap { i -> List(i.n) { i.t } })
}

/* ---------------- moving a device ---------------- */

/** Where a device dragged to ([rawOff], [rawH]) on its wall lands: snapped heights and lines, clear of the doors and windows. */
fun snapWall(c: ECtx, d: ElecDev, rawOff: Int, rawH: Int, devs: List<ElecDev>): Pair<Int, Int> {
    val w = c.wall(d.wall) ?: return rawOff to rawH
    val (dw, dh) = devSize(d)
    val H = c.H
    val hs = snapHeights(H) + usualH(d.t, H, c.kind)
    // off the usual heights a device moves in whole centimetres
    val h = (hs.minByOrNull { abs(it - rawH) }?.takeIf { abs(it - rawH) <= 80 } ?: ((rawH + 5) / 10 * 10)).coerceIn(dh / 2 + 30, max(dh / 2 + 30, H - dh / 2 - 30))
    val xs = ArrayList<Double>()
    c.room.openings.filter { it.wall == w.id }.forEach { o ->
        xs += o.off + o.w + 150.0 + dw / 2; xs += o.off - 150.0 - dw / 2
    }
    devs.filter { it.wall == w.id && it.id != d.id && it.t != "led" }.forEach { xs += it.off.toDouble() }
    xs += 300.0 + dw / 2; xs += w.len - 300 - dw / 2
    val x0 = (xs.minByOrNull { abs(it - rawOff) }?.takeIf { abs(it - rawOff) <= 60 } ?: ((rawOff + 5) / 10 * 10).toDouble()).coerceIn(dw / 2.0 + 50, max(dw / 2.0 + 50, w.len - dw / 2.0 - 50))
    val bl = blocksOn(c, w.id, d.t, emptyList(), openingsOnly = true)
    val x = if (bl.none { it.hits(x0 - dw / 2.0, x0 + dw / 2.0, h - dh / 2.0, h + dh / 2.0) }) x0.roundToInt() else spotOn(w, x0, h, dw, dh, bl) ?: x0.roundToInt()
    return x to h
}

/** Where a ceiling device dragged to plan point ([x], [y]) lands: on the room's middle lines when near them, inside the room. */
fun snapCeil(c: ECtx, x: Double, y: Double): Pair<Int, Int> {
    val m = centreOf(c)
    val sx = if (abs(x - m.x) <= 80) m.x else x; val sy = if (abs(y - m.y) <= 80) m.y else y
    val f = c.g.floor
    val q = V2(sx.coerceIn(f.minOf { it.x } + 100, f.maxOf { it.x } - 100), sy.coerceIn(f.minOf { it.y } + 100, f.maxOf { it.y } - 100))
    return if (inside(f, q)) q.x.roundToInt() to q.y.roundToInt() else m.x.roundToInt() to m.y.roundToInt()
}

/* ---------------- the panel ---------------- */

/** The panel's box for [modules] (0: a 24-module one), mm wide × high. */
fun panelSize(modules: Int): Pair<Int, Int> = when {
    modules in 1..12 -> 260 to 300
    modules in 13..24 || modules == 0 -> 320 to 420
    modules in 25..36 -> 320 to 560
    else -> 320 to 700
}

/** Where the panel goes by default: the hallway (or the room with most doors), on the entrance door's wall beside it. */
fun defaultPanel(p: Project, snap: Boolean): ElecPanel? {
    val cs = p.rooms.mapNotNull { ctxOf(p, it.id, snap) }
    val c = cs.firstOrNull { it.kind == "hall" } ?: cs.maxByOrNull { it.doors.size } ?: return null
    return panelIn(c, p.elec.devs.filter { it.roomId == c.id })
}

/** The panel put in room [c]: beside its first door (the entrance), clear of the devices there. */
fun panelIn(c: ECtx, devs: List<ElecDev>): ElecPanel {
    val e = c.doors.firstOrNull()
    val w = e?.let { c.wall(it.wall) } ?: mainWall(c)
    val (pw, ph) = panelSize(0)
    val bl = blocksOn(c, w.id, "jb", devs)
    val x = spotOn(w, (e?.let { it.off + it.w + 700.0 } ?: (w.len / 2)), PANEL_H, pw, ph, bl) ?: spotOn(w, w.len / 2, PANEL_H, pw, ph, emptyList()) ?: (w.len / 2).roundToInt()
    return ElecPanel(c.id, w.id, x, PANEL_H, e?.id)
}

/** Dragging the panel along its wall: the usual heights, clear of doors and windows. */
fun snapPanel(c: ECtx, pn: ElecPanel, rawOff: Int, rawH: Int): ElecPanel {
    val w = c.wall(pn.wall) ?: return pn
    val (pw, ph) = panelSize(0)
    val h = (listOf(PANEL_H, 1500, 1700, 1800).minByOrNull { abs(it - rawH) }?.takeIf { abs(it - rawH) <= 80 } ?: ((rawH + 5) / 10 * 10)).coerceIn(ph / 2 + 300, max(ph / 2 + 300, c.H - ph / 2 - 50))
    val x0 = ((rawOff + 5) / 10 * 10).toDouble().coerceIn(pw / 2.0 + 50, max(pw / 2.0 + 50, w.len - pw / 2.0 - 50))
    val bl = blocksOn(c, w.id, "jb", emptyList(), openingsOnly = true)
    val x = spotOn(w, x0, h, pw, ph, bl) ?: x0.roundToInt()
    return pn.copy(off = x, h = h)
}

/** Nearest distance from plan point [q] to the walls: the wall, how far along it, how far away. */
fun nearestWall(c: ECtx, q: V2): Triple<TWall, Double, Double> = nearestWall(c.g.walls, q)

/** Nearest distance from plan point [q] to walls [ws]: the wall, how far along it, how far away. */
fun nearestWall(ws: List<TWall>, q: V2): Triple<TWall, Double, Double> = ws.map { w ->
    val a = (q - w.p0).dot(w.t).coerceIn(0.0, w.len)
    Triple(w, a, hypot(q.x - w.at(a).x, q.y - w.at(a).y))
}.minBy { it.third }

/** The site points of a room taken in as devices: its sockets as single sockets and switches as single switches. */
fun fromSitePoints(c: ECtx, id: () -> String): List<ElecDev> = c.room.points.filter { (it.t == "socket" || it.t == "switch") && it.id !in c.er.seen }.mapNotNull { x ->
    if (c.wall(x.wall) == null) null else ElecDev(id(), if (x.t == "socket") "s1" else "k1", c.id, x.wall, x.off, min(max(x.h, 60), c.H - 60), from = x.id)
}
