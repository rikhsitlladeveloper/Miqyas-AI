package uz.metrx.app.elec

import uz.metrx.app.data.Project
import uz.metrx.app.data.Row
import uz.metrx.app.trades.TradeResult
import uz.metrx.app.trades.TradeSet
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/*
 * Counting from the real routes (the advanced app): cable by type with the spare in whole 100 m coils, breakers by
 * amps, RCDs, the main switch and the panel's size in modules, socket and junction boxes, pipe, channel and chase
 * metres, and the estimate's lines with the labour per point, per metre and for the panel.
 */

/** Cable [m] metres of type [type] ("1.5", "2.5", "6", "utp"), with the spare: [withSpare] m in [coils] coils. */
data class CableNeed(val type: String, val m: Double, val withSpare: Double, val coils: Int)

/** What an order takes. Lengths in metres. */
data class ECount(
    val circuits: Int = 0,
    val cables: List<CableNeed> = emptyList(),
    val breakers: Map<Int, Int> = emptyMap(),
    val rcds: Int = 0,
    val modules: Int = 0,
    val panelModules: Int = 0,
    val sockets: Int = 0, val switches: Int = 0, val lights: Int = 0, val low: Int = 0,
    val boxes: Int = 0, val jboxes: Int = 0,
    val chaseM: Double = 0.0, val gofraM: Double = 0.0, val channelM: Double = 0.0,
    val cableM: Double = 0.0
) {
    val points get() = sockets + switches + lights + low
}

/** Whole coils of [COIL] m for [m] metres. */
fun coilsFor(m: Double) = if (m <= 0) 0 else ceil(m / COIL - 1e-9).toInt()

/** The usual panel sizes, modules. */
val PANEL_SIZES = listOf(12, 18, 24, 36, 48, 54, 72)

/** The panel for [modules] used: the next size with a fifth spare. */
fun panelFor(modules: Int) = if (modules <= 0) 0 else PANEL_SIZES.firstOrNull { it >= ceil(modules * 1.2 - 1e-9) } ?: PANEL_SIZES.last()

/** The length of the union of stretches [iv] round a loop [P] long. */
fun unionLen(iv: List<Pair<Double, Double>>, P: Double): Double {
    if (iv.isEmpty() || P <= 0) return 0.0
    val flat = ArrayList<Pair<Double, Double>>()
    iv.forEach { (a0, b0) ->
        if (b0 - a0 >= P) { flat += 0.0 to P; return@forEach }
        val a = ((a0 % P) + P) % P; val b = a + (b0 - a0)
        if (b <= P) flat += a to b else { flat += a to P; flat += 0.0 to b - P }
    }
    var sum = 0.0; var cur0 = -1.0; var cur1 = -1.0
    flat.sortedBy { it.first }.forEach { (a, b) ->
        if (a > cur1) { if (cur1 > cur0) sum += cur1 - cur0; cur0 = a; cur1 = b } else cur1 = max(cur1, b)
    }
    if (cur1 > cur0) sum += cur1 - cur0
    return min(sum, P)
}

/** Everything order [p] takes, from its rooms [cs], circuits and routes. */
fun countOf(p: Project, cs: List<ECtx>, rt: Routes): ECount {
    val spare = (p.elec.spare ?: CABLE_SPARE).coerceIn(0, 100)
    val cab = LinkedHashMap<String, Double>()
    rt.circuits.forEach { c -> cab[c.cable] = (cab[c.cable] ?: 0.0) + rt.cableOf(c) / 1000 }
    val cables = listOf("1.5", "2.5", "6", "utp").mapNotNull { t -> cab[t]?.takeIf { it > 0 }?.let { m -> val ws = m * (1 + spare / 100.0); CableNeed(t, m, ws, coilsFor(ws)) } }
    val brk = rt.circuits.filter { it.amps > 0 }.groupingBy { it.amps }.eachCount().toSortedMap()
    val rcds = rt.circuits.count { it.rcd }
    val modules = brk.values.sum() + 2 * rcds + (if (brk.isNotEmpty()) 2 else 0)
    val all = cs.flatMap { devsIn(p, it) }
    fun cat(c: String) = all.count { devType(it.t).cat == c }
    val boxes = all.count { !it.onCeiling && devType(it.t).cat != "box" && it.t != "led" }
    // a junction box in every room with devices, where none was placed
    val jb = cs.sumOf { c -> val ds = devsIn(p, c); if (ds.any { it.t == "jb" }) ds.count { it.t == "jb" } else if (ds.any { devType(it.t).cat != "box" }) 1 else 0 }
    // chases and channels: each stretch of wall once (cables share them), each drop once; pipe: every cable its own
    var wallM = 0.0; var drops = 0.0; var ceilM = 0.0; var rises = 0.0
    cs.forEach { c ->
        val runs = rt.inRoom(c.id)
        if (runs.isEmpty()) return@forEach
        wallM += unionLen(runs.flatMap { it.runs }, Perim(c).P)
        drops += runs.flatMap { it.drops.entries }.associate { it.key to it.value }.values.sum()
        ceilM += runs.sumOf { it.ceil }
        rises = max(rises, runs.maxOf { it.rise })
    }
    val cableM = rt.circuits.sumOf { rt.cableOf(it) } / 1000
    val m = { v: Double -> v / 1000 }
    val (chase, gofra, channel) = when (rt.method) {
        "gofra" -> Triple(m(drops), m(ceilM + rises), 0.0)
        "channel" -> Triple(0.0, 0.0, m(wallM + drops + rises + ceilM))
        else -> Triple(m(wallM + drops + rises), m(ceilM), 0.0)
    }
    return ECount(rt.circuits.size, cables, brk, rcds, modules, panelFor(modules), cat("sock"), cat("sw"), cat("light"), cat("low"), boxes, jb, chase, gofra, channel, cableM)
}

/** The order's circuits, routes and counts in one go. */
class ElecCalc(val ctxs: List<ECtx>, val circuits: List<Circuit>, val routes: Routes, val count: ECount, val warns: List<EWarn>)

fun calcOf(p: Project, snap: Boolean): ElecCalc {
    val cs = ctxs(p, snap)
    val cc = circuitsOf(p, cs)
    val rt = routesOf(p, cs, cc)
    return ElecCalc(cs, cc, rt, countOf(p, cs, rt), warningsOf(p, cs, cc))
}

private fun num(s: String) = s.replace(" ", "").replace(',', '.').toDoubleOrNull() ?: 0.0
private fun qty(v: Double) = if (v == Math.floor(v)) v.toLong().toString() else String.format(java.util.Locale.ROOT, "%.2f", v).trimEnd('0').trimEnd('.')
private fun money(v: Double) = Math.round(v).toString()

/** The cable's name in the lines: "3×1,5" or "UTP" (the comma is put in by the language). */
fun cableName(t: String) = if (t == "utp") "UTP" else "3×$t"

/**
 * The order's lines for the estimate (ids "t-…"): cable by type in whole coils, devices, boxes, breakers, RCDs, the
 * main switch, the panel, pipe and channel; the labour for the points, the chases, the cable and the panel. [name]
 * gives a line's stored words (strings key, values).
 */
fun elecRows(p: Project, t: TradeSet, snap: Boolean, name: (String, Map<String, Any>) -> String): TradeResult {
    val calc = calcOf(p, snap)
    val c = calc.count
    val mats = ArrayList<Row>(); val labor = ArrayList<Row>()
    fun mat(key: String, unit: String, q: Double, price: String, vars: Map<String, Any> = emptyMap(), id: String = key) {
        if (q > 0) mats += Row("t-$id", name("el.e.$key", vars), name("tu.$unit", emptyMap()), qty(q), price.replace(" ", "").let { if (it.isEmpty()) it else money(num(it)) })
    }
    fun lab(key: String, amount: Double, vars: Map<String, Any> = emptyMap()) { if (amount > 0) labor += Row("t-$key", name("el.e.$key", vars), amount = money(amount)) }
    c.cables.forEach { n ->
        val price = when (n.type) { "1.5" -> t.pCab15; "6" -> t.pCab6; "utp" -> t.pUtp; else -> t.pCable }
        mat("cab", "m", n.coils * COIL.toDouble(), price, mapOf("c" to (if (n.type == "utp") "UTP" else "VVG " + cableName(n.type)), "n" to n.coils), "cab" + n.type)
    }
    mat("sock", "pcs", c.sockets.toDouble(), t.pSocket)
    mat("sw", "pcs", c.switches.toDouble(), t.pSwitch)
    mat("light", "pcs", c.lights.toDouble(), t.pLight)
    mat("low", "pcs", c.low.toDouble(), t.pLow)
    mat("box", "pcs", c.boxes.toDouble(), t.pBox)
    mat("jbox", "pcs", c.jboxes.toDouble(), t.pJBox)
    c.breakers.forEach { (a, n) -> mat("brk", "pcs", n.toDouble(), t.pBreaker, mapOf("a" to a), "brk$a") }
    mat("rcd", "pcs", c.rcds.toDouble(), t.pRcd)
    if (c.breakers.isNotEmpty()) {
        mat("main", "pcs", 1.0, t.pMain)
        mat("panel", "pcs", 1.0, money(num(t.pPanelM) * c.panelModules), mapOf("n" to c.panelModules))
    }
    mat("gofra", "m", ceil(c.gofraM - 1e-9), t.pConduit)
    mat("chan", "m", ceil(c.channelM - 1e-9), t.pChan)
    lab("lPts", c.points * num(t.lPoint), mapOf("n" to c.points))
    lab("lChase", c.chaseM * num(t.lChase), mapOf("a" to qty(Math.round(c.chaseM * 10) / 10.0)))
    lab("lCable", c.cableM * num(t.lMetre), mapOf("a" to qty(Math.round(c.cableM * 10) / 10.0)))
    if (c.breakers.isNotEmpty()) lab("lPanel", num(t.lPanel), mapOf("n" to c.circuits))
    return TradeResult(mats, labor, mapOf("points" to c.points.toDouble(), "cable" to c.cableM))
}
