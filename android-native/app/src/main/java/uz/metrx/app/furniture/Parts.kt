package uz.metrx.app.furniture

/*
 * The parts generator (furniture plan section 6.3): every board of a module with its finished size, banding and
 * material role. Pure Kotlin; the expected sizes are in src/test/resources/furniture-cases.json, shared with the iPhone app.
 *
 * Construction (section 6.2): sides stand on the bottom; base units have two 100 mm rails instead of a top; wall, tall
 * and wardrobe carcasses have a top and a bottom between the sides; the back is nailed on 2 mm in from each edge (or
 * sits in 8 mm grooves); fronts leave a gap between them and at the outer edges.
 */

/** Banding on a part's two long edges and two short edges: 0 none, 1 thin, 2 thick. */
data class Bands(val l1: Int = 0, val l2: Int = 0, val s1: Int = 0, val s2: Int = 0) {
    val any get() = l1 + l2 + s1 + s2 > 0
}

/**
 * One kind of part: [key] its name's strings key, [mod] the module it belongs to, [role] carcass, front or back; [L] × [W]
 * the finished size, [L] the longer side (along the grain for fronts); [qty] how many.
 */
data class FPart(val key: String, val mod: String, val role: String, val L: Int, val W: Int, val qty: Int, val bands: Bands = Bands(), val grain: Boolean = false)

/** A part from two sizes and the banding of the edges that run along each: normalised so [FPart.L] is the longer one. */
private fun part(key: String, mod: String, role: String, a: Int, b: Int, qty: Int, ea: Pair<Int, Int> = 0 to 0, eb: Pair<Int, Int> = 0 to 0, grain: Boolean = false): FPart =
    if (grain || a >= b) FPart(key, mod, role, a, b, qty, Bands(ea.first, ea.second, eb.first, eb.second), grain)
    else FPart(key, mod, role, b, a, qty, Bands(eb.first, eb.second, ea.first, ea.second), grain)

private const val RAIL = 100
/** The plinth under a wardrobe without legs: the bottom panel sits on it, the sides go down to the floor. */
const val PLINTH = 80

/** Where a wardrobe's inside starts: the plinth, or nothing on legs. */
fun wardBase(m: Module) = if (m.legs) 0 else PLINTH

/** Section [i]'s width between its side or dividers (a divider takes half of [t] from each side, a missing side nothing). */
fun wardInner(m: Module, secs: List<Section>, i: Int, t: Int): Int {
    val s = secs[i]
    val left = if (i == 0) (if (m.sideL) t * 10 else 0) else t * 5
    val right = if (i == secs.lastIndex) (if (m.sideR) t * 10 else 0) else t * 5
    return (s.w * 10 - left - right) / 10
}

/** A wardrobe section's inside height: between the bottom and the top panels. */
fun wardInnerH(m: Module, t: Int) = m.h - wardBase(m) - 2 * t
private val THICK = 2 to 0
private val ALL = 2 to 2
private const val THIN = 1

/** The runner length for a box [d] deep: 50 mm steps, 300 to 600. */
fun runnerLen(d: Int) = ((d - 10) / 50 * 50).coerceIn(300, 600)

/** Hinges on a door by its height (furniture plan section 6.6): up to 900 → 2, 1600 → 3, 2000 → 4, more → 5. */
fun hingesFor(h: Int) = when { h <= 900 -> 2; h <= 1600 -> 3; h <= 2000 -> 4; else -> 5 }

/** The fronts of an opening [w] × [h] wide: doors side by side, drawers and appliance panels one above the other; sizes in whole mm. */
internal fun frontSizes(f: Fronts, w: Int, h: Int, ws: Workshop): List<Pair<Int, Int>> {
    if (f.kind == "open" || f.n <= 0) return emptyList()
    val n = f.n
    return if (f.kind == "drawer" || f.kind == "panel") {
        val each = (h * 10 - 2 * ws.edge10 - (n - 1) * ws.gap10) / n / 10
        List(n) { each to (w * 10 - 2 * ws.edge10) / 10 }
    } else {
        val each = (w * 10 - 2 * ws.edge10 - (n - 1) * ws.gap10) / n / 10
        List(n) { (h * 10 - 2 * ws.edge10) / 10 to each }
    }
}

/** A drawer's box behind a front [fh] high in an opening [iw] wide (between the sides) and [d] deep: sides, front and back, bottom. */
private fun drawerBox(mod: String, iw: Int, d: Int, fh: Int, t: Int): List<FPart> {
    val rl = runnerLen(d)
    val bh = (fh - 40).coerceIn(80, 150)
    val inner = iw - 26                       // 13 mm runner clearance each side
    return listOf(
        part("fp.dSide", mod, "carcass", rl, bh, 2, THIN to 0),
        part("fp.dFront", mod, "carcass", inner - 2 * t, bh - 10, 2, THIN to 0),
        part("fp.dBottom", mod, "back", inner, rl - 2, 1)
    )
}

private fun backPanel(mod: String, w: Int, h: Int, ws: Workshop): FPart =
    if (ws.back == "groove") part("fp.back", mod, "back", h - 2 * ws.t + 16, w - 2 * ws.t + 16, 1)
    else part("fp.back", mod, "back", h - 4, w - 4, 1)

/** Fronts: doors and panels with the grain upright (length = height), drawer faces with it across (length = width). */
private fun fronts(mod: String, f: Fronts, w: Int, h: Int, ws: Workshop): List<FPart> =
    frontSizes(f, w, h, ws).groupingBy { it }.eachCount().map { (sz, n) ->
        if (f.kind == "drawer") part("fp.dFace", mod, "front", sz.second, sz.first, n, ALL, ALL, grain = true)
        else part(if (f.kind == "panel") "fp.panel" else "fp.door", mod, "front", sz.first, sz.second, n, ALL, ALL, grain = true)
    }

/** All parts of one module. */
fun partsOf(m: Module, ws: Workshop): List<FPart> {
    val t = ws.t; val id = m.label.ifEmpty { m.id }
    val out = ArrayList<FPart>()
    fun shelves(iw: Int, d: Int, ins: List<Insert>) = ins.filter { it.kind == "shelf" }.sumOf { it.qty }.let { n ->
        if (n > 0) out += part("fp.shelf", id, "carcass", iw - 2, d - 20, n, THICK)
    }
    when (m.type) {
        "gap" -> out += fronts(id, m.fronts, m.w, m.h, ws)
        "filler" -> out += part("fp.filler", id, "front", m.h, m.w, 1, ALL, ALL, grain = true)
        "wardrobe" -> {
            val secs = m.sections.ifEmpty { listOf(Section(m.w)) }
            val base = wardBase(m)
            val sides = (if (m.sideL) 1 else 0) + (if (m.sideR) 1 else 0)
            val inW = m.w - sides * t
            if (sides > 0) out += part("fp.side", id, "carcass", m.h, m.d, sides, THICK)
            out += part("fp.top", id, "carcass", inW, m.d, 2, THICK)
            if (secs.size > 1) out += part("fp.divider", id, "carcass", m.h - base - 2 * t, m.d, secs.size - 1, THICK)
            if (!m.legs) out += part("fp.plinth", id, "carcass", inW, PLINTH, 1, THICK)
            secs.forEachIndexed { i, s ->
                val iw = wardInner(m, secs, i, t)
                val sid = "$id/${i + 1}"
                out += backPanel(sid, s.w, m.h - base, ws)
                s.inserts.filter { it.kind == "shelf" }.sumOf { it.qty }.let { n -> if (n > 0) out += part("fp.shelf", sid, "carcass", iw - 2, m.d - 20, n, THICK) }
                s.inserts.filter { it.kind == "drawer" }.forEach { dr ->
                    val fh = if (dr.h > 0) dr.h else 200
                    out += part("fp.dFace", sid, "carcass", iw - 4, fh, 1, ALL, ALL)
                    out += drawerBox(sid, iw, m.d, fh, t)
                }
                out += fronts(sid, s.fronts, s.w, m.h - base, ws)
            }
        }
        "base" -> {
            out += part("fp.bottom", id, "carcass", m.w, m.d, 1, THICK)
            out += part("fp.side", id, "carcass", m.h - t, m.d, 2, THICK)
            out += part("fp.rail", id, "carcass", m.w - 2 * t, RAIL, 2, THIN to 0)
            shelves(m.w - 2 * t, m.d, m.inserts)
            out += backPanel(id, m.w, m.h, ws)
            out += fronts(id, m.fronts, m.w, m.h, ws)
            if (m.fronts.kind == "drawer") frontSizes(m.fronts, m.w, m.h, ws).forEach { (fh, _) -> out += drawerBox(id, m.w - 2 * t, m.d, fh, t) }
        }
        else -> {   // wall and tall
            out += part("fp.side", id, "carcass", m.h, m.d, 2, THICK)
            out += part("fp.top", id, "carcass", m.w - 2 * t, m.d, 2, THICK)
            shelves(m.w - 2 * t, m.d, m.inserts)
            out += backPanel(id, m.w, m.h, ws)
            out += fronts(id, m.fronts, m.w, m.h, ws)
            if (m.fronts.kind == "drawer") frontSizes(m.fronts, m.w, m.h, ws).forEach { (fh, _) -> out += drawerBox(id, m.w - 2 * t, m.d, fh, t) }
        }
    }
    return merge(out)
}

/** Equal parts of one module become one line with their counts added. */
private fun merge(ps: List<FPart>): List<FPart> =
    ps.groupBy { it.copy(qty = 0) }.map { (k, v) -> k.copy(qty = v.sumOf { it.qty }) }
