package uz.metrx.app.plumb

import uz.metrx.app.data.Project
import uz.metrx.app.data.Row
import uz.metrx.app.elec.Perim
import uz.metrx.app.elec.unionLen
import uz.metrx.app.trades.TradeResult
import uz.metrx.app.trades.TradeSet
import kotlin.math.ceil

/*
 * Counting from the real routes (the advanced app): water and heating pipe by diameter with the spare in 4 m sticks
 * (PPR) or coils (metal-plastic, PEX), drains 50 and 110 by the metre with their bends and tees, the underfloor pipe
 * in coils, the elbows, tees, couplings, wall plates, ball valves, main valves, meters, filters and the manifold; the
 * estimate's lines with the labour per outlet, per fixture, per metre, per radiator and per metre of chase. The
 * fixtures themselves are the customer's and are not counted.
 */

/** Pipe of [kind] (water, heat, ufh) [dia] mm: [m] metres, [withSpare] with the spare, in [pieces] sticks or coils of [per] m ([unit] stick or coil). */
data class PipeNeed(val kind: String, val dia: Int, val m: Double, val withSpare: Double, val pieces: Int, val unit: String, val per: Int)

/** What an order takes. Lengths in metres. */
data class PCount(
    val pipes: List<PipeNeed> = emptyList(),
    val drain50: Double = 0.0, val drain110: Double = 0.0,
    val bends50: Int = 0, val bends110: Int = 0, val tees50: Int = 0, val tees110: Int = 0,
    val elbows: Int = 0, val tees: Int = 0, val couplings: Int = 0, val plates: Int = 0, val balls: Int = 0,
    val mainValves: Int = 0, val meters: Int = 0, val filters: Int = 0,
    val manifolds: Int = 0, val manifOuts: Int = 0, val loops: Int = 0,
    val points: Int = 0, val fixtures: Int = 0, val radiators: Int = 0,
    val waterM: Double = 0.0, val heatM: Double = 0.0, val ufhM: Double = 0.0, val chaseM: Double = 0.0
) {
    val drainM get() = drain50 + drain110
    /** Every metre of pipe laid (the labour by the metre). */
    val pipeM get() = waterM + heatM + drainM + ufhM
}

/** A coil's length for metal-plastic and PEX of [dia]: 100 m thin, 50 m thick. */
fun coilFor(dia: Int) = if (dia <= 20) 100 else 50

/** [m] metres of [kind] pipe [dia] in system [water] with [spare] %: whole sticks or coils. */
fun pipeNeed(kind: String, dia: Int, m: Double, water: String, spare: Int): PipeNeed {
    val ws = m * (1 + spare / 100.0)
    if (kind == "ufh") return PipeNeed(kind, 16, m, ws, if (ws <= 0) 0 else ceil(ws / UFH_COIL - 1e-9).toInt(), "coil", UFH_COIL)
    return if (water == "ppr") PipeNeed(kind, dia, m, ws, if (ws <= 0) 0 else ceil(ws / STICK - 1e-9).toInt(), "stick", STICK)
    else coilFor(dia).let { per -> PipeNeed(kind, dia, m, ws, if (ws <= 0) 0 else ceil(ws / per - 1e-9).toInt(), "coil", per) }
}

/** Everything order [p] takes, from its rooms [cs] and routes [rt]. */
fun countOf(p: Project, cs: List<PCtx>, rt: PRoutes): PCount {
    val pl = p.plumb
    val spare = (pl.spare ?: PIPE_SPARE).coerceIn(0, 100)
    val m = { v: Double -> v / 1000 }
    // water and heating: the trunk at its diameter, the branches 20
    fun byDia(kinds: Set<String>): Map<Int, Double> {
        val out = sortedMapOf<Int, Double>()
        rt.runs.filter { it.kind in kinds }.forEach { r -> out[r.dia] = (out[r.dia] ?: 0.0) + m(r.trunk); out[20] = (out[20] ?: 0.0) + m(r.drops) }
        return out.filterValues { it > 0 }
    }
    val water = byDia(setOf("cold", "hot")); val heat = byDia(setOf("hs", "hr"))
    val ufhM = rt.loops.sumOf { it.total } / 1000
    val pipes = water.map { (d, v) -> pipeNeed("water", d, v, pl.water, spare) } + heat.map { (d, v) -> pipeNeed("heat", d, v, pl.water, spare) } +
        (if (ufhM > 0) listOf(pipeNeed("ufh", 16, ufhM, pl.water, spare)) else emptyList())
    // drains: each stretch of wall once a diameter (the pipes join), a 50 where a 110 runs beside it is the 110's
    var d50 = 0.0; var d110 = 0.0
    cs.forEach { c ->
        val rs = rt.drains.flatMap { it.runs }.filter { it.roomId == c.id }
        if (rs.isEmpty()) return@forEach
        val P = Perim(c.g.walls).P
        val s110 = rs.filter { it.dia >= 100 }.flatMap { it.stretches }; val s50 = rs.filter { it.dia < 100 }.flatMap { it.stretches }
        val u110 = unionLen(s110, P)
        d110 += u110 + rs.filter { it.dia >= 100 }.sumOf { it.drops }
        d50 += (unionLen(s50 + s110, P) - u110) + rs.filter { it.dia < 100 }.sumOf { it.drops }
    }
    // the pipe between the doors, once a room and diameter
    rt.drains.filter { it.between > 0 }.groupBy { it.pt.roomId to (it.dia >= 100) }.forEach { (k, ds) -> val l = ds.maxOf { it.between }; if (k.second) d110 += l else d50 += l }
    val dr50 = rt.drains.filter { it.dia < 100 }; val dr110 = rt.drains.filter { it.dia >= 100 }
    val sup = rt.runs.filter { it.kind != "drain" }
    val ws = rt.runs.filter { it.kind == "cold" || it.kind == "hot" }
    val pieces = pipes.filter { it.kind != "ufh" }
    val all = cs.flatMap { c -> pointsIn(p, c) }
    val fixes = cs.flatMap { fixesIn(p, it) }
    // the riser's meter, filter and main valve: one set for its cold when cold water runs from it, another for its hot only
    // when the hot water comes up it (not from a gas boiler or a water heater); a heating-only order needs none
    val coldOut = rt.runs.any { it.kind == "cold" }
    val hotOut = rt.riser?.hot == true && rt.hot != null && rt.hot.fix == null && rt.runs.any { it.kind == "hot" }
    val riserKinds = if (rt.riser == null) 0 else (if (coldOut) 1 else 0) + (if (hotOut) 1 else 0)
    return PCount(
        pipes = pipes,
        drain50 = m(d50), drain110 = m(d110),
        bends50 = dr50.sumOf { 1 + it.runs.sumOf { r -> r.corners } }, bends110 = dr110.sumOf { 1 + it.runs.sumOf { r -> r.corners } },
        tees50 = dr50.size, tees110 = dr110.size,
        elbows = sup.sumOf { it.corners + 2 * it.dips + it.branches }, tees = sup.sumOf { it.branches },
        couplings = if (pl.water == "ppr") pieces.sumOf { it.pieces } else 0,
        plates = ws.sumOf { it.branches }, balls = sup.sumOf { it.branches },
        mainValves = riserKinds, meters = riserKinds, filters = riserKinds,
        // each manifold placed (a typed room with underfloor heating has its own)
        manifolds = if (rt.loops.isNotEmpty()) maxOf(1, fixes.count { it.t == "manif" }) else 0, manifOuts = rt.loops.sumOf { it.n }, loops = rt.loops.sumOf { it.n },
        points = all.size, fixtures = fixes.size, radiators = fixes.count { it.t == "rad" },
        waterM = m(ws.sumOf { it.len }), heatM = m(sup.filter { it.kind == "hs" || it.kind == "hr" }.sumOf { it.len }), ufhM = ufhM,
        chaseM = m(sup.sumOf { it.chase })
    )
}

/** The order's routes, counts and warnings in one go. */
class PlumbCalc(val ctxs: List<PCtx>, val routes: PRoutes, val count: PCount, val warns: List<PWarn>)

fun calcOf(p: Project, snap: Boolean): PlumbCalc {
    val cs = ctxs(p, snap)
    val rt = routesOf(p, cs)
    return PlumbCalc(cs, rt, countOf(p, cs, rt), warningsOf(p, cs, rt))
}

private fun num(s: String) = s.replace(" ", "").replace(',', '.').toDoubleOrNull() ?: 0.0
private fun qty(v: Double) = if (v == Math.floor(v)) v.toLong().toString() else String.format(java.util.Locale.ROOT, "%.2f", v).trimEnd('0').trimEnd('.')
private fun money(v: Double) = Math.round(v).toString()

/**
 * The order's lines for the estimate (ids "t-…"): pipe by diameter in whole sticks or coils, drains, the underfloor
 * pipe, fittings, valves, meters, filters and the manifold; the labour per outlet, fixture, metre, radiator and chase.
 * [name] gives a line's stored words (strings key, values).
 */
fun plumbRows(p: Project, t: TradeSet, snap: Boolean, name: (String, Map<String, Any>) -> String): TradeResult {
    val c = calcOf(p, snap).count
    val mats = ArrayList<Row>(); val labor = ArrayList<Row>()
    fun mat(key: String, unit: String, q: Double, price: String, vars: Map<String, Any> = emptyMap(), id: String = key) {
        if (q > 0) mats += Row("t-$id", name("sx.e.$key", vars), name("tu.$unit", emptyMap()), qty(q), price.replace(" ", "").let { if (it.isEmpty()) it else money(num(it)) })
    }
    fun lab(key: String, amount: Double, vars: Map<String, Any> = emptyMap()) { if (amount > 0) labor += Row("t-$key", name("sx.e.$key", vars), amount = money(amount)) }
    val sys = "~sx.sys.${p.plumb.water}"
    c.pipes.forEach { n ->
        val price = when (n.kind) { "ufh" -> t.pUfh; "heat" -> t.pHeat; else -> when (n.dia) { 32 -> t.pX32; 25 -> t.pX25; else -> t.pX20 } }
        val key = when (n.kind) { "ufh" -> "ufh"; "heat" -> if (n.unit == "stick") "heatS" else "heatC"; else -> if (n.unit == "stick") "pipeS" else "pipeC" }
        mat(key, "m", (n.pieces * n.per).toDouble(), price, mapOf("s" to sys, "d" to n.dia, "n" to n.pieces), key + n.dia)
    }
    mat("d50", "m", ceil(c.drain50 - 1e-9), t.pD50)
    mat("d110", "m", ceil(c.drain110 - 1e-9), t.pD110)
    mat("bend", "pcs", c.bends50.toDouble(), t.pDBend, mapOf("d" to 50), "bend50")
    mat("bend", "pcs", c.bends110.toDouble(), t.pDBend, mapOf("d" to 110), "bend110")
    mat("dtee", "pcs", c.tees50.toDouble(), t.pDTee, mapOf("d" to 50), "dtee50")
    mat("dtee", "pcs", c.tees110.toDouble(), t.pDTee, mapOf("d" to 110), "dtee110")
    mat("elbow", "pcs", c.elbows.toDouble(), t.pElbow)
    mat("tee", "pcs", c.tees.toDouble(), t.pTee)
    mat("coup", "pcs", c.couplings.toDouble(), t.pCoup)
    mat("plate", "pcs", c.plates.toDouble(), t.pPlate)
    mat("ball", "pcs", c.balls.toDouble(), t.pBall)
    mat("mainv", "pcs", c.mainValves.toDouble(), t.pMainV)
    mat("meter", "pcs", c.meters.toDouble(), t.pMeter)
    mat("filter", "pcs", c.filters.toDouble(), t.pFilter)
    mat("manif", "pcs", c.manifolds.toDouble(), t.pManif, mapOf("n" to c.manifOuts))
    lab("lPts", c.points * num(t.lPPt), mapOf("n" to c.points))
    lab("lFix", c.fixtures * num(t.lPFix), mapOf("n" to c.fixtures))
    // the metres the line shows are the ones it is priced by, so quantity × rate is its amount
    val pipeM = Math.round(c.pipeM * 10) / 10.0; val chaseM = Math.round(c.chaseM * 10) / 10.0
    lab("lMetre", pipeM * num(t.lPM), mapOf("a" to qty(pipeM)))
    lab("lRad", c.radiators * num(t.lPRad), mapOf("n" to c.radiators))
    lab("lChase", chaseM * num(t.lPChase), mapOf("a" to qty(chaseM)))
    return TradeResult(mats, labor, mapOf("points" to c.points.toDouble(), "pipe" to c.pipeM))
}
