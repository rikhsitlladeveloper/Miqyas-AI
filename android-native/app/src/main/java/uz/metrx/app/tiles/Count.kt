package uz.metrx.app.tiles

import uz.metrx.app.data.Project
import uz.metrx.app.data.Row
import uz.metrx.app.geo.V3
import uz.metrx.app.trades.TradeResult
import uz.metrx.app.trades.TradeSet
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/*
 * Counting from the real layout: the whole tiles and the cut pieces of every surface, a cut piece taken from an offcut
 * when one is big enough, then the spare and whole boxes; the adhesive, grout, skirting, corner profiles and
 * waterproofing, and the estimate's lines with the labour.
 */

/** One tile (look and size) a layout or an order needs: tiles laid whole, cut ones, cuts taken from offcuts, then the boxes. */
data class TileNeed(val look: String, val a: Int, val b: Int, val whole: Int, val cut: Int, val reused: Int, val tiles: Int, val skirtTiles: Int,
                    val spare: Int, val withSpare: Int, val perBox: Int, val boxes: Int, val m2: Double, val price: String = "",
                    /** Layouts of one tile merged with different box sizes: what their boxes hold together, m² (-1: from [boxes] × [perBox]). */
                    val boxed: Double = -1.0) {
    /** What the boxes hold, m². */
    val boxedM2 get() = if (boxed >= 0) boxed else boxes * perBox * a.toDouble() * b / 1e6
}

/** What a layout, a room or an order takes. Areas m², lengths m, weights kg. [tooMany]: a surface with too many tiles to count. */
data class TileCount(val needs: List<TileNeed> = emptyList(), val m2: Double = 0.0, val glueKg: Double = 0.0, val groutKg: Double = 0.0,
                     val skirtM: Double = 0.0, val profileM: Double = 0.0, val wpM2: Double = 0.0, val tooMany: Boolean = false) {
    val glueBags get() = ceil(glueKg / 25.0 - 1e-9).toInt()
    val boxes get() = needs.sumOf { it.boxes }

    operator fun plus(o: TileCount): TileCount {
        // a layout priced on its own stays its own line (the same tile at two prices is not one)
        val merged = (needs + o.needs).groupBy { listOf(it.look, it.a, it.b, it.price) }.map { (_, ns) ->
            val f = ns[0]; val ws = ns.sumOf { it.withSpare }
            // one box size: the boxes of the whole; layouts with their own box sizes: each one's boxes, added up.
            // The spare % is said only when it is the same for all ([spare] -1: they differ)
            val onePb = ns.all { it.perBox == f.perBox }
            f.copy(whole = ns.sumOf { it.whole }, cut = ns.sumOf { it.cut }, reused = ns.sumOf { it.reused }, tiles = ns.sumOf { it.tiles },
                skirtTiles = ns.sumOf { it.skirtTiles }, withSpare = ws, m2 = ns.sumOf { it.m2 },
                spare = if (ns.all { it.spare == f.spare }) f.spare else -1,
                boxes = if (onePb) ceil(ws.toDouble() / f.perBox - 1e-9).toInt() else ns.sumOf { it.boxes },
                perBox = if (onePb) f.perBox else 0, boxed = if (onePb) -1.0 else ns.sumOf { it.boxedM2 })
        }
        return TileCount(merged, m2 + o.m2, glueKg + o.glueKg, groutKg + o.groutKg, skirtM + o.skirtM, profileM + o.profileM, wpM2 + o.wpM2, tooMany || o.tooMany)
    }
}

/**
 * New tiles for the cut pieces [cuts] of a tile [b] × [a] and how many came out of offcuts: a piece about a rectangle
 * takes the smallest offcut it fits in ([turn]: turned too), the rest of the tile is cut in two and kept when both
 * sides are 40 mm or more; other shapes (a diagonal's triangles) share a tile two by two when their areas fit.
 */
fun cutTiles(cuts: List<Piece>, b: Double, a: Double, turn: Boolean, kerf: Double = 3.0): Pair<Int, Int> {
    var fresh = 0; var reused = 0
    val off = ArrayList<DoubleArray>()
    fun keep(w: Double, h: Double) { if (w >= 40 && h >= 40) off += doubleArrayOf(w, h) }
    fun split(w: Double, h: Double, pw: Double, ph: Double) {
        // of the two ways to cut the rest, the one that keeps the bigger offcut
        val rw = w - pw - kerf; val rh = h - ph - kerf
        if (rw * h >= w * rh) { keep(rw, h); keep(pw, rh) } else { keep(w, rh); keep(rw, ph) }
    }
    for (p in cuts.filter { it.rectish }.sortedByDescending { it.pw * it.ph }) {
        var best = -1; var bestA = Double.MAX_VALUE; var turned = false
        for (i in off.indices) {
            val o = off[i]; val ar = o[0] * o[1]
            if (ar >= bestA) continue
            if (o[0] >= p.pw - .5 && o[1] >= p.ph - .5) { best = i; bestA = ar; turned = false }
            else if (turn && o[0] >= p.ph - .5 && o[1] >= p.pw - .5) { best = i; bestA = ar; turned = true }
        }
        if (best >= 0) { val o = off.removeAt(best); reused++; if (turned) split(o[0], o[1], p.ph, p.pw) else split(o[0], o[1], p.pw, p.ph) }
        else { fresh++; split(b, a, p.pw, p.ph) }
        if (off.size > 400) { off.sortByDescending { it[0] * it[1] }; while (off.size > 300) off.removeAt(off.lastIndex) }
    }
    val rest = ArrayList<Double>()
    for (p in cuts.filter { !it.rectish }.sortedByDescending { it.area }) {
        val need = p.area * 1.04
        val i = rest.indexOfFirst { it >= need }
        if (i >= 0) { rest.removeAt(i); reused++ } else { fresh++; (b * a - need).takeIf { it > 0 }?.let { rest += it } }
    }
    return fresh to reused
}

/** Grout for tiles [a] × [b] with [joint] mm joints, kg a m² (joints' volume: tile thickness by size, grout 1,6 kg/l). */
fun groutKgM2(a: Int, b: Int, joint: Int): Double {
    val t = if (b <= 300) 8.0 else if (b <= 600) 9.0 else 10.0
    return (a + b).toDouble() / (a.toDouble() * b) * t * joint * 1.6
}

/** Adhesive a m²: the usual, a little more for big tiles (a thicker bed). */
fun glueKgM2(b: Int, base: Double) = base * when { b >= 1200 -> 1.4; b >= 600 -> 1.1; else -> 1.0 }

/** Counts the pieces [laid] of layout [l]; [skirtMm] of skirting cut from its tile, [profileMm] of corner profiles. */
fun countLaid(l: TileLayout, laid: Laid, skirtMm: Double = 0.0, profileMm: Double = 0.0, glueBase: Double = 5.0): TileCount {
    val spare = spareOf(l)
    val needs = ArrayList<TileNeed>()
    var grout = 0.0; var glue = 0.0
    laid.pieces.groupBy { it.prod }.toSortedMap().forEach { (prod, ps) ->
        val look = if (prod == 0) l.look else l.look2
        val a = if (prod == 2) l.sa else l.a; val b = if (prod == 2) l.sb else l.b
        val whole = ps.count { !it.cut }
        val cuts = ps.filter { it.cut }
        val (fresh, reused) = cutTiles(cuts, b.toDouble(), a.toDouble(), lookOf(look).kind != "w")
        val skirtTiles = if (prod == 0 && skirtMm > 0 && l.skirt > 0) {
            val strips = max(1, (a / (l.skirt + 3.0)).toInt())
            ceil(skirtMm / (b + l.joint) / strips - 1e-9).toInt()
        } else 0
        val tiles = whole + fresh
        val ws = ceil((tiles + skirtTiles) * (1 + spare / 100.0) - 1e-9).toInt()
        val pb = perBox(l, a, b)
        val m2 = ps.sumOf { it.area } / 1e6
        needs += TileNeed(look, a, b, whole, cuts.size, reused, tiles, skirtTiles, spare, ws, pb, ceil(ws.toDouble() / pb - 1e-9).toInt(), m2, l.price)
        grout += m2 * groutKgM2(a, b, l.joint) + (if (prod == 0) skirtMm / 1000 * l.skirt / 1000 * groutKgM2(a, b, l.joint) else 0.0)
        glue += m2 * glueKgM2(b, glueBase) + (if (prod == 0) skirtMm / 1000 * l.skirt / 1000 * glueBase else 0.0)
    }
    val m2 = laid.pieces.sumOf { it.area } / 1e6
    return TileCount(needs, m2, glue, grout, skirtMm / 1000, profileMm / 1000, 0.0, laid.tooMany.isNotEmpty())
}

/* ---------------- skirting, corner profiles, waterproofing ---------------- */

/** A stretch of skirting: on the vertical surface [frame], from [a0] to [a1] mm along it. */
class Run(val frame: Frame, val a0: Double, val a1: Double, val wall: String? = null) { val len get() = a1 - a0 }

/** [0, len] less the stretches [cuts]. */
internal fun gaps(len: Double, cuts: List<Pair<Double, Double>>): List<Pair<Double, Double>> {
    val out = ArrayList<Pair<Double, Double>>(); var cur = 0.0
    cuts.map { max(0.0, it.first) to min(len, it.second) }.filter { it.second > it.first }.sortedBy { it.first }.forEach { (a, b) ->
        if (a > cur + 1) out += cur to a
        cur = max(cur, b)
    }
    if (len > cur + 1) out += cur to len
    return out
}

/** Whether a wall of the room is tiled from the floor up by one of the room's layouts (then it needs no skirting). */
private fun tiledToFloor(all: List<TileLayout>, roomId: String, wall: String) =
    all.any { l -> l.roomId == roomId && l.surfs.any { it.id == wall && it.mode != "band" } }

/** The skirting of floor layout [l]: along every wall less its doors, the tray and bath, and walls tiled to the floor; round the columns. */
fun skirtRuns(l: TileLayout, g: TRoomGeo, all: List<TileLayout>): List<Run> {
    if (l.skirt <= 0 || l.surfs.none { it.id == "floor" }) return emptyList()
    val out = ArrayList<Run>()
    // an inner partition's faces get skirting too (geo/InnerWalls.kt), less an arch's passage
    for (w in g.walls + g.inner) {
        if (tiledToFloor(all, g.room.id, w.id)) continue
        val cuts = ArrayList<Pair<Double, Double>>()
        g.room.openings.filter { it.wall == w.id && it.type == "door" }.forEach { cuts += it.off.toDouble() to (it.off + it.w).toDouble() }
        if (g.inner.isNotEmpty()) uz.metrx.app.geo.archGap(g.room, w.id)?.let { (t0, t1, _) -> cuts += t0 to t1 }
        g.fixes.forEach { f -> coverOn(g, w, f)?.let { cuts += it } }
        val cols = if (g.rect) g.room.features.filter { it.wall == w.id && it.type == "column" } else emptyList()
        cols.forEach { cuts += it.off.toDouble() to (it.off + it.w).toDouble() }
        gaps(w.len, cuts).forEach { (a, b) -> out += Run(g.wallFrame(w), a, b, w.id) }
        cols.forEach { c ->
            val a0 = c.off.toDouble(); val a1 = (c.off + c.w).toDouble(); val d = c.d.toDouble()
            out += Run(g.wallFrame(w, d), a0, a1, w.id)
            out += Run(Frame(g.scene(w.at(a0)), V3(w.nIn.x, 0.0, w.nIn.y), V3(0.0, 1.0, 0.0), V3(-w.t.x, 0.0, -w.t.y)), 0.0, d, w.id)
            out += Run(Frame(g.scene(w.at(a1)), V3(w.nIn.x, 0.0, w.nIn.y), V3(0.0, 1.0, 0.0), V3(w.t.x, 0.0, w.t.y)), 0.0, d, w.id)
        }
    }
    return out
}

private fun overlap(a0: Double, a1: Double, b0: Double, b1: Double) = max(0.0, min(a1, b1) - max(a0, b0))

/** Corner profiles of a wall layout [l], mm: round its windows and niches, up the columns and the room's outside corners. */
fun profileMm(l: TileLayout, g: TRoomGeo): Double {
    if (!l.profiles) return 0.0
    var sum = 0.0
    val zones = l.surfs.filter { g.wall(it.id) != null }.associate { it.id to zoneOf(it, g.innerH[it.id] ?: g.H) }
    for ((wid, z) in zones) {
        val (lo, hi) = z
        fun edges(x0: Double, x1: Double, y0: Double, y1: Double) {
            val ov = overlap(y0, y1, lo, hi); if (ov <= 0) return
            sum += 2 * ov
            if (y1 > lo && y1 < hi) sum += x1 - x0
            if (y0 > lo + 1 && y0 < hi) sum += x1 - x0
        }
        g.room.openings.filter { it.wall == wid && it.type == "window" }.forEach { o -> edges(o.off.toDouble(), (o.off + o.w).toDouble(), o.sill.toDouble(), (o.sill + o.h).toDouble()) }
        if (g.rect) g.room.features.filter { it.wall == wid }.forEach { f ->
            if (f.type == "column") sum += 2 * (hi - lo)
            else { val sill = f.sill.toDouble(); val nh = (if (f.h > 0) f.h.toDouble() else g.H - sill).coerceAtMost(g.H - sill); edges(f.off.toDouble(), (f.off + f.w).toDouble(), sill, sill + nh) }
        }
    }
    // the outside corners of a drawn room (an L-shape's inner corner seen from the room is one), where both walls are tiled
    val sg = if (area(g.floor) >= 0) 1.0 else -1.0
    g.walls.forEachIndexed { i, w ->
        val prev = g.walls[(i - 1 + g.walls.size) % g.walls.size]
        if (prev.t.cross(w.t) * sg >= -1e-6) return@forEachIndexed
        val z0 = zones[prev.id] ?: return@forEachIndexed; val z1 = zones[w.id] ?: return@forEachIndexed
        sum += overlap(z0.first, z0.second, z1.first, z1.second)
    }
    // an inner partition (geo/InnerWalls.kt): its outside corners where both faces are tiled (an L's or T's), and the
    // two edges of an end standing free in the room (not against a wall)
    if (g.inner.isNotEmpty()) uz.metrx.app.geo.innerFaces(g.room).groupBy { it.pid }.values.forEach { fs ->
        val ws = fs.mapNotNull { f -> g.inner.firstOrNull { it.id == f.id } }
        fun same(a: V2, b: V2) = abs(a.x - b.x) < 1 && abs(a.y - b.y) < 1
        ws.forEach { w ->
            val z = zones[w.id]
            val end = w.at(w.len)
            ws.firstOrNull { it !== w && same(it.p0, end) }?.let { nx ->
                val z1 = zones[nx.id]
                if (w.t.cross(nx.t) < -1e-6 && z != null && z1 != null) sum += overlap(z.first, z.second, z1.first, z1.second)
            }
            if (z != null) for (q in listOf(w.p0, end)) {
                if (ws.any { it !== w && (same(it.p0, q) || same(it.at(it.len), q)) }) continue
                if (g.walls.minOf { segDist(q, it) } < 40) continue
                sum += z.second - z.first
            }
        }
    }
    return sum
}

/** How far plan point [q] is from wall [w]'s face, mm. */
private fun segDist(q: V2, w: TWall): Double { val a = ((q - w.p0).dot(w.t)).coerceIn(0.0, w.len); val p = w.at(a); return kotlin.math.hypot(q.x - p.x, q.y - p.y) }

/** A room's waterproofing, m²: the floor, [TileRoom.wpUp] up every wall (less its doors), and the walls by the tray and bath up to the shower height. */
fun wpM2(tr: TileRoom, g: TRoomGeo): Double {
    if (!tr.wp) return 0.0
    // the floor less what the inner partitions stand on, and their faces (up to the band) as walls
    var mm2 = abs(area(g.floor)) - uz.metrx.app.geo.innerAreas(g.room).floor
    for (w in g.walls + g.inner) {
        val doors = g.room.openings.filter { it.wall == w.id && it.type == "door" }.sumOf { it.w.toDouble() } +
            (if (g.inner.isNotEmpty()) uz.metrx.app.geo.archGap(g.room, w.id)?.let { (t0, t1, _) -> t1 - t0 } ?: 0.0 else 0.0)
        mm2 += max(0.0, w.len - doors) * min(tr.wpUp.toDouble(), g.innerH[w.id] ?: g.H)
        g.fixes.forEach { f -> coverOn(g, w, f)?.let { (a, b) -> mm2 += (b - a) * max(0.0, tr.showerH.toDouble().coerceAtMost(g.H) - tr.wpUp) } }
    }
    return mm2 / 1e6
}

/* ---------------- whole orders ---------------- */

/** A typed surface's frame: a floor lies flat, a wall or backsplash stands up. Only its shape matters for counting. */
fun panelFrame(kind: String) = if (kind == "floor") Frame(V3(0.0, 0.0, 0.0), V3(1.0, 0.0, 0.0), V3(0.0, 0.0, 1.0), V3(0.0, 1.0, 0.0))
    else Frame(V3(0.0, 0.0, 0.0), V3(1.0, 0.0, 0.0), V3(0.0, 1.0, 0.0), V3(0.0, 0.0, 1.0))

/** The room of a layout as the tiles see it (null: not measured yet). */
fun geoFor(p: Project, roomId: String?, snap: Boolean, dx: Double = 0.0, dz: Double = 0.0): TRoomGeo? {
    val r = p.rooms.firstOrNull { it.id == roomId } ?: return null
    return roomGeo(r, snap, p.troom.firstOrNull { it.roomId == r.id }?.fixes ?: emptyList(), dx, dz)
}

/** What layout [l] of order [p] takes; zero until its room is measured. */
/** The adhesive's kg a m² as typed in the trade's prices; 0 is kept (no adhesive bought), blank or wrong is the usual 5. */
fun glueBaseOf(s: String) = s.replace(" ", "").replace(',', '.').toDoubleOrNull()?.takeIf { it >= 0 } ?: 5.0

fun countLayout(p: Project, l: TileLayout, snap: Boolean, glueBase: Double = 5.0): TileCount {
    if (l.roomId == null) {
        val s = panelSurf(l, panelFrame(l.panel?.kind ?: "floor")) ?: return TileCount()
        return countLaid(l, layAll(l, listOf(s), null, null), glueBase = glueBase)
    }
    val g = geoFor(p, l.roomId, snap) ?: return TileCount()
    val laid = layRoom(l, g, floorLayout(p.tiles, l.roomId).takeIf { it?.id != l.id })
    val skirt = skirtRuns(l, g, p.tiles).sumOf { it.len }
    return countLaid(l, laid, skirt, profileMm(l, g), glueBase)
}

/** What a room's layouts (or, [roomId] null, the whole order) take, with the rooms' waterproofing. */
fun countOrder(p: Project, snap: Boolean, glueBase: Double = 5.0, roomId: String? = null, all: Boolean = roomId == null): TileCount {
    var c = TileCount()
    p.tiles.filter { all || it.roomId == roomId }.forEach { c += countLayout(p, it, snap, glueBase) }
    p.troom.filter { all || it.roomId == roomId }.forEach { tr -> geoFor(p, tr.roomId, snap)?.let { g -> c += TileCount(wpM2 = wpM2(tr, g)) } }
    return c
}

private fun num(s: String) = s.replace(" ", "").replace(',', '.').toDoubleOrNull() ?: 0.0
private fun qty(v: Double) = if (v == Math.floor(v)) v.toLong().toString() else String.format(java.util.Locale.ROOT, "%.2f", v).trimEnd('0').trimEnd('.')
private fun money(v: Double) = Math.round(v).toString()

/**
 * The order's lines for the estimate (ids "t-…"): each tile in m² of whole boxes, adhesive bags, grout, corner
 * profiles, waterproofing, and the labour for the tiling, skirting, profiles and waterproofing. [name] gives a line's
 * stored words (strings key, values).
 */
fun tileRows(p: Project, t: TradeSet, snap: Boolean, name: (String, Map<String, Any>) -> String): TradeResult {
    val c = countOrder(p, snap, glueBaseOf(t.glueKg))
    val mats = ArrayList<Row>(); val labor = ArrayList<Row>()
    fun mat(key: String, unit: String, q: Double, price: String, vars: Map<String, Any> = emptyMap(), id: String = key) {
        if (q > 0) mats += Row("t-$id", name("tl.e.$key", vars), name("tu.$unit", emptyMap()), qty(q), price.replace(" ", "").let { if (it.isEmpty()) it else money(num(it)) })
    }
    fun lab(key: String, amount: Double, vars: Map<String, Any> = emptyMap()) { if (amount > 0) labor += Row("t-$key", name("tl.e.$key", vars), amount = money(amount)) }
    c.needs.forEachIndexed { i, n ->
        mat("tile", "m2", Math.round(n.boxedM2 * 100) / 100.0, n.price.ifBlank { t.pTile }, mapOf("a" to n.a, "b" to n.b, "n" to n.boxes, "l" to "~tl.lk.${n.look}"), "tile$i")
    }
    mat("glue", "bag", c.glueBags.toDouble(), t.pGlue)
    mat("grout", "kg", ceil(c.groutKg - 1e-9), t.pGrout)
    mat("prof", "m", ceil(c.profileM * 1.05 * 10 - 1e-9) / 10, t.pProf)
    mat("wp", "m2", ceil(c.wpM2 * 10 - 1e-9) / 10, t.pWp)
    // each labour line is priced by the quantity it shows, so quantity × rate is its amount
    fun r1(v: Double) = Math.round(v * 10) / 10.0
    val m2r = r1(c.m2)
    lab("lab", m2r * num(t.lTile), mapOf("a" to qty(m2r)))
    lab("labSkirt", r1(c.skirtM) * num(t.lSkirt), mapOf("a" to qty(r1(c.skirtM))))
    lab("labProf", r1(c.profileM) * num(t.lProf), mapOf("a" to qty(r1(c.profileM))))
    lab("labWp", r1(c.wpM2) * num(t.lWp), mapOf("a" to qty(r1(c.wpM2))))
    return TradeResult(mats, labor, mapOf("area" to c.m2, "boxes" to c.boxes.toDouble()))
}
