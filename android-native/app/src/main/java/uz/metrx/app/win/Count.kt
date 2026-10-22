package uz.metrx.app.win

import kotlinx.serialization.Serializable
import uz.metrx.app.data.Project
import uz.metrx.app.data.Row
import uz.metrx.app.trades.TradeResult
import kotlin.math.ceil

/*
 * Counting from the parts (the advanced app): profile metres of frame, opening sashes and mullions per profile system,
 * glass by the unit's chambers and panels in m², laminate by the metre and side, hardware by sash type, handles, nets,
 * sills, drips and reveals; doors by type and area with their lock and hinges; the labour per m² of window, per door
 * and per metre or m² of the extras. A price list per profile system (PVC, aluminium) and the rest common.
 */

/** One profile system's prices: frame, sash and mullion a metre; hardware per sash that turns, tilts, tilts and turns, slides; fitting a m² of window. */
@Serializable
data class WSys(val frameM: String, val sashM: String, val mullM: String, val hwTurn: String, val hwTilt: String, val hwTT: String, val hwSlide: String, val lM2: String) {
    fun hw(t: String) = when (t) { "turn" -> hwTurn; "tilt" -> hwTilt; "tt" -> hwTT; else -> hwSlide }
}

/**
 * The windows-and-doors maker's prices, one set for all orders (whole currency units): each profile system's, the glass
 * units and panels a m², laminating a metre of profile a side, the extras, doors a m² by type with their lock and hinges,
 * and the labour.
 */
@Serializable
data class WinPrices(
    val pvc: WSys = WSys("45000", "55000", "40000", "120000", "90000", "220000", "180000", "180000"),
    val alu: WSys = WSys("85000", "95000", "75000", "150000", "110000", "280000", "160000", "200000"),
    val glass1: String = "180000", val glass2: String = "260000", val panel: String = "150000", val lam: String = "25000",
    val sill: String = "120000", val drip: String = "60000", val reveal: String = "90000", val net: String = "70000", val handle: String = "35000",
    val dInt: String = "1200000", val dEnt: String = "2800000", val dSl: String = "1600000", val dGl: String = "2200000", val hwDoor: String = "250000",
    val lDoor: String = "300000", val lSill: String = "30000", val lReveal: String = "80000", val lDrip: String = "20000"
) {
    fun sys(s: String) = if (s == "alu") alu else pvc
    fun door(k: String) = when (k) { "dent" -> dEnt; "dsl" -> dSl; "dgl" -> dGl; else -> dInt }
}

/** Whether colour [c] is a laminate on [profile] (white PVC and silver aluminium are the profile's own). */
fun laminated(profile: String, c: String) = c != "white" && !(profile == "alu" && c == "silver")

/** A profile system's share of the order: metres, hardware by sash type, the windows' area. */
data class SysCount(val frameM: Double = 0.0, val sashM: Double = 0.0, val mullM: Double = 0.0, val hw: Map<String, Int> = emptyMap(), val winM2: Double = 0.0) {
    val profileM get() = frameM + sashM + mullM
    operator fun plus(o: SysCount) = SysCount(frameM + o.frameM, sashM + o.sashM, mullM + o.mullM, (hw.keys + o.hw.keys).associateWith { (hw[it] ?: 0) + (o.hw[it] ?: 0) }, winM2 + o.winM2)
}

/** What an order takes. */
data class WCount(
    val sys: Map<String, SysCount> = emptyMap(),
    val glass1: Double = 0.0, val glass2: Double = 0.0, val panel: Double = 0.0, val lamM: Double = 0.0,
    val sillM: Double = 0.0, val dripM: Double = 0.0, val revealM2: Double = 0.0, val nets: Int = 0, val handles: Int = 0,
    /** Doors by type: pieces and m². */
    val doors: Map<String, Pair<Int, Double>> = emptyMap(), val doorHw: Int = 0,
    val windows: Int = 0, val doorN: Int = 0
) {
    val pieces get() = windows + doorN
    val winM2 get() = sys.values.sumOf { it.winM2 }
    val glassM2 get() = glass1 + glass2
}

/** The wall's thickness a product stands in: its room's (200 when not typed), its own without a room. */
fun wallT(p: Project, it: WinItem): Int = if (!it.inRoom) it.freeT else p.rooms.firstOrNull { r -> r.id == it.roomId }?.dim("T")?.v ?: 200

/** The parts of products [list] (each with its reveal's depth), [qty] pieces each. */
fun countItems(list: List<Pair<WinItem, Int>>): WCount {
    var c = WCount()
    for ((it, r) in list) {
        val q = it.qty.coerceIn(1, 999).toDouble()
        val pt = partsOf(it, r)
        if (it.isDoor) {
            val d = c.doors[it.kind] ?: (0 to 0.0)
            c = c.copy(doors = c.doors + (it.kind to (d.first + q.toInt() to d.second + pt.doorM2 * q)), doorHw = c.doorHw + q.toInt(), doorN = c.doorN + q.toInt(),
                handles = c.handles + 0, revealM2 = c.revealM2 + pt.revealM2 * q)
            continue
        }
        val s = SysCount(pt.frameM * q, pt.sashM * q, pt.mullM * q, pt.hw.mapValues { (it.value * q).toInt() }, pt.areaM2 * q)
        val sides = (if (laminated(it.profile, it.colIn)) 1 else 0) + (if (laminated(it.profile, it.colOut)) 1 else 0)
        c = c.copy(
            sys = c.sys + (it.profile to ((c.sys[it.profile] ?: SysCount()) + s)),
            glass1 = c.glass1 + if (it.glass < 2) pt.glassM2 * q else 0.0, glass2 = c.glass2 + if (it.glass >= 2) pt.glassM2 * q else 0.0,
            panel = c.panel + pt.panelM2 * q, lamM = c.lamM + pt.profileM * sides * q,
            sillM = c.sillM + pt.sillM * q, dripM = c.dripM + pt.dripM * q, revealM2 = c.revealM2 + pt.revealM2 * q,
            nets = c.nets + (pt.nets * q).toInt(), handles = c.handles + (pt.handles * q).toInt(), windows = c.windows + q.toInt()
        )
    }
    return c
}

/** Each product of order [p] with its reveal's depth. */
fun withReveals(p: Project): List<Pair<WinItem, Int>> = p.win.items.map { it to revealOf(wallT(p, it), frameDepth(it)) }

fun countOf(p: Project): WCount = countItems(withReveals(p))

/** The order's rooms, counts and warnings in one go. */
class WinCalc(val ctxs: List<WCtx>, val count: WCount, val warns: List<WWarn>)

fun calcOf(p: Project, snap: Boolean): WinCalc {
    val cs = ctxs(p, snap)
    return WinCalc(cs, countOf(p), warningsOf(p, cs, snap))
}

private fun num(s: String) = s.replace(" ", "").replace(',', '.').toDoubleOrNull() ?: 0.0
private fun qty(v: Double) = if (v == Math.floor(v)) v.toLong().toString() else String.format(java.util.Locale.ROOT, "%.2f", v).trimEnd('0').trimEnd('.')
private fun money(v: Double) = Math.round(v).toString()
/** Metres up to the next 10 cm, m² up to the next 0,01. */
fun upM(v: Double) = ceil(v * 10 - 1e-9) / 10
fun upM2(v: Double) = ceil(v * 100 - 1e-9) / 100

/**
 * The lines for the estimate (ids "t-…") of products [list]: per profile system its frame, sash and mullion metres and
 * hardware by sash type; glass, panels, laminate, the extras, doors by type and their hardware; the labour. [name]
 * gives a line's stored words (strings key, values).
 */
fun rowsFor(list: List<Pair<WinItem, Int>>, t: WinPrices, name: (String, Map<String, Any>) -> String): TradeResult {
    val c = countItems(list)
    val mats = ArrayList<Row>(); val labor = ArrayList<Row>()
    fun mat(key: String, unit: String, q: Double, price: String, vars: Map<String, Any> = emptyMap(), id: String = key) {
        if (q > 0) mats += Row("t-$id", name("dw.e.$key", vars), name("tu.$unit", emptyMap()), qty(q), price.replace(" ", "").let { if (it.isEmpty()) it else money(num(it)) })
    }
    fun lab(key: String, amount: Double, vars: Map<String, Any> = emptyMap(), id: String = key) { if (amount > 0) labor += Row("t-$id", name("dw.e.$key", vars), amount = money(amount)) }
    PROFILES.forEach { s ->
        val sc = c.sys[s] ?: return@forEach
        val ps = t.sys(s); val sv = mapOf("s" to "~dw.p.$s")
        mat("frame", "m", upM(sc.frameM), ps.frameM, sv, "frame-$s")
        mat("sash", "m", upM(sc.sashM), ps.sashM, sv, "sash-$s")
        mat("mull", "m", upM(sc.mullM), ps.mullM, sv, "mull-$s")
        listOf("turn", "tilt", "tt", "slide").forEach { k -> mat("hw", "pcs", (sc.hw[k] ?: 0).toDouble(), ps.hw(k), sv + mapOf("k" to "~dw.t.$k"), "hw-$s-$k") }
    }
    mat("glass", "m2", upM2(c.glass1), t.glass1, mapOf("n" to 1), "glass1")
    mat("glass", "m2", upM2(c.glass2), t.glass2, mapOf("n" to 2), "glass2")
    mat("panel", "m2", upM2(c.panel), t.panel)
    mat("lam", "m", upM(c.lamM), t.lam)
    DOOR_KINDS.sorted().forEach { k -> c.doors[k]?.let { (n, a) -> mat("door", "m2", upM2(a), t.door(k), mapOf("k" to "~dw.k.$k", "n" to n), "door-$k") } }
    mat("doorHw", "pcs", c.doorHw.toDouble(), t.hwDoor)
    mat("sill", "m", upM(c.sillM), t.sill)
    mat("drip", "m", upM(c.dripM), t.drip)
    mat("reveal", "m2", upM2(c.revealM2), t.reveal)
    mat("net", "pcs", c.nets.toDouble(), t.net)
    mat("handle", "pcs", c.handles.toDouble(), t.handle)
    PROFILES.forEach { s -> c.sys[s]?.let { sc -> lab("lWin", upM2(sc.winM2) * num(t.sys(s).lM2), mapOf("s" to "~dw.p.$s", "a" to qty(upM2(sc.winM2))), "lWin-$s") } }
    lab("lDoor", c.doorN * num(t.lDoor), mapOf("n" to c.doorN))
    lab("lSill", upM(c.sillM) * num(t.lSill), mapOf("a" to qty(upM(c.sillM))))
    lab("lReveal", upM2(c.revealM2) * num(t.lReveal), mapOf("a" to qty(upM2(c.revealM2))))
    lab("lDrip", upM(c.dripM) * num(t.lDrip), mapOf("a" to qty(upM(c.dripM))))
    return TradeResult(mats, labor, mapOf("pieces" to c.pieces.toDouble(), "area" to c.winM2))
}

/** The order's lines for the estimate. */
fun winRows(p: Project, t: WinPrices, name: (String, Map<String, Any>) -> String): TradeResult = rowsFor(withReveals(p), t, name)

/** What lines [r] come to, whole currency units. */
fun total(r: TradeResult): Double = r.mats.sumOf { num(it.qty) * num(it.price) } + r.labor.sumOf { num(it.amount) }

/** What one product (all its pieces) comes to with its reveal [r]. */
fun itemCost(it: WinItem, r: Int, t: WinPrices): Double = total(rowsFor(listOf(it to r), t) { k, _ -> k })
