package uz.metrx.app.trades

import kotlinx.serialization.Serializable
import uz.metrx.app.data.Room
import uz.metrx.app.data.Row
import uz.metrx.app.geo.areas
import uz.metrx.app.geo.ready3D
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/*
 * The other trades on the industry picker: tiler, electrician, plumber, windows and doors. A trade's project is a
 * builder's project (rooms, measurements, estimate, quote); its calculator turns the measured rooms into estimate
 * lines. Pure Kotlin, unit-tested (TradesTest). Rates and prices are samples the maker changes once.
 */

val TRADES = listOf("tiler", "elec", "plumb", "win")

fun isTrade(industry: String?) = industry in TRADES

/**
 * Whether order [p]'s estimate already has the lines its trade's own count makes: "t-" lines named by [prefix]
 * ("tl.e.", "el.e.", "sx.e.", "dw.e."). The older trades' calculator's "t-" lines ("tr.…") do not count.
 */
fun madeBy(p: uz.metrx.app.data.Project, prefix: String, labourToo: Boolean = true): Boolean =
    (p.estimate.materials + (if (labourToo) p.estimate.labor else emptyList())).any { it.id.startsWith("t-") && it.name.startsWith("@$prefix") }

/**
 * The calculator's settings, one set for all trades. Lengths in mm; money as typed (whole currency units); amounts per
 * unit: tile per m², adhesive per 25 kg bag, grout per kg, cable and pipes per metre, the rest per piece.
 */
@Serializable
data class TradeSet(
    // tiler
    val tileW: Int = 300, val tileH: Int = 600, val boxM2: String = "1.44", val waste: Int = 10,
    val floor: Boolean = true, val wallH: Int = 0,
    val pTile: String = "120000", val glueKg: String = "5", val pGlue: String = "65000", val groutKg: String = "0.4", val pGrout: String = "25000",
    val lTile: String = "80000",
    // the tiler's layouts (tiles/Count.kt): corner profile and waterproofing per metre and m², labour for skirting, profiles, waterproofing
    val pProf: String = "15000", val pWp: String = "45000", val lSkirt: String = "20000", val lProf: String = "15000", val lWp: String = "25000",
    // electrician
    val lights: Int = 1, val pSocket: String = "35000", val pSwitch: String = "30000", val pLight: String = "40000",
    val pCable: String = "9000", val pConduit: String = "3000", val pBreaker: String = "45000", val lPoint: String = "60000",
    // the electrician's routes (elec/Count.kt): cable 3×1,5, 3×6 and UTP a metre, channel a metre, low-voltage point, socket and
    // junction box, RCD, main switch, the panel a module; labour per metre of chase and of cable, and the panel's assembly
    val pCab15: String = "6000", val pCab6: String = "25000", val pUtp: String = "3500", val pChan: String = "9000", val pLow: String = "40000",
    val pBox: String = "2500", val pJBox: String = "7000", val pRcd: String = "200000", val pMain: String = "150000", val pPanelM: String = "12000",
    val lChase: String = "20000", val lMetre: String = "3000", val lPanel: String = "300000",
    // plumber
    val pPipe: String = "12000", val pSewer: String = "18000", val pFitting: String = "6000", val pTap: String = "90000", val lPlumb: String = "120000",
    // the plumber's routes (plumb/Count.kt): water pipe 20, 25 and 32 a metre, heating and underfloor pipe a metre, drain 50 and 110 a
    // metre; elbow, tee, coupling, drain bend and tee, wall plate, ball valve, main valve, meter, filter, the manifold; labour per outlet,
    // per fixture, per metre of pipe, per radiator and per metre of chase
    val pX20: String = "8000", val pX25: String = "12000", val pX32: String = "18000", val pHeat: String = "12000", val pUfh: String = "9000",
    val pD50: String = "10000", val pD110: String = "22000", val pElbow: String = "3000", val pTee: String = "4000", val pCoup: String = "2000",
    val pDBend: String = "6000", val pDTee: String = "9000", val pPlate: String = "15000", val pBall: String = "45000", val pMainV: String = "90000",
    val pMeter: String = "250000", val pFilter: String = "120000", val pManif: String = "1500000",
    val lPPt: String = "120000", val lPFix: String = "150000", val lPM: String = "15000", val lPRad: String = "200000", val lPChase: String = "25000",
    // windows and doors
    val pWinM2: String = "900000", val pDoorM2: String = "1200000", val pSillM: String = "150000", val pRevealM: String = "60000", val lWin: String = "250000",
    // the windows-and-doors app's prices from the parts, a list per profile system (win/Count.kt)
    val win: uz.metrx.app.win.WinPrices = uz.metrx.app.win.WinPrices()
)

/** What a calculator worked out: material and labour lines for the estimate (ids start with "t-"), and how much of what. */
data class TradeResult(val mats: List<Row>, val labor: List<Row>, val facts: Map<String, Double>)

private fun num(s: String) = s.replace(" ", "").replace(',', '.').toDoubleOrNull() ?: 0.0
private fun qty(v: Double) = if (v == Math.floor(v)) v.toLong().toString() else String.format(java.util.Locale.ROOT, "%.2f", v).trimEnd('0').trimEnd('.')
private fun money(v: Double) = Math.round(v).toString()

/** A room's tiled area in m²: its floor, and its walls up to [wallH] less the doors and windows below that line. */
fun tileArea(r: Room, t: TradeSet, snap: Boolean = true): Double {
    val a = areas(r, snap) ?: return 0.0
    var mm2 = if (t.floor) a.floor.toDouble() else 0.0
    if (t.wallH > 0) {
        val H = r.dim("H").v ?: t.wallH
        val hh = min(t.wallH, H)
        val open = r.openings.sumOf { o -> o.w.toDouble() * max(0, min(o.sill + o.h, hh) - o.sill).toDouble() }
        // inner walls: both faces up to the line (a half wall only up to its top), their doors through both sides
        val ia = uz.metrx.app.geo.innerAreas(r, snap, hh)
        mm2 += (a.perim - ia.len).toDouble() * hh - open + ia.gross - ia.open / 2.0
    }
    return mm2 / 1e6
}

/**
 * The trade's lines for the measured rooms [rooms]; [name] gives a line's words (strings key, values), and a number in
 * them has the decimal mark of the language ([english]: a point, else a comma).
 */
fun tradeRows(trade: String, rooms: List<Room>, t: TradeSet, name: (String, Map<String, Any>) -> String, snap: Boolean = true, english: Boolean = true): TradeResult {
    val mats = ArrayList<Row>(); val labor = ArrayList<Row>(); val facts = LinkedHashMap<String, Double>()
    // prices are whole currency units: one saved with decimals before the calculator checked them is rounded
    fun mat(key: String, unit: String, q: Double, price: String, vars: Map<String, Any> = emptyMap()) {
        if (q > 0) mats += Row("t-$key", name("tr.$key", vars), name("tu.$unit", emptyMap()), qty(q), price.replace(" ", "").let { if (it.isEmpty()) it else money(num(it)) })
    }
    fun lab(key: String, amount: Double, vars: Map<String, Any> = emptyMap()) { if (amount > 0) labor += Row("t-$key", name("tr.$key", vars), amount = money(amount)) }
    val measured = rooms.filter { ready3D(it, snap) }
    // counts saved before the calculator checked them can be absurd: kept in range so the sums never overflow
    val lightsEach = t.lights.coerceIn(0, 100); val waste = t.waste.coerceIn(0, 100)
    when (trade) {
        "tiler" -> {
            val area = measured.sumOf { tileArea(it, t, snap) }
            facts["area"] = area
            val box = num(t.boxM2).takeIf { it > 0 } ?: 1.0
            val boxes = ceil(area * (1 + waste / 100.0) / box - 1e-9)
            facts["boxes"] = boxes
            mat("tile", "m2", boxes * box, t.pTile, mapOf("w" to t.tileW, "h" to t.tileH, "n" to boxes.toLong()))
            mat("glue", "bag", ceil(area * num(t.glueKg) / 25.0 - 1e-9), t.pGlue)
            mat("grout", "kg", ceil(area * num(t.groutKg) - 1e-9), t.pGrout)
            // priced by the area it shows, so quantity × rate is its amount
            lab("tileLab", Math.round(area * 10) / 10.0 * num(t.lTile), mapOf("a" to uz.metrx.app.core.fmtNumStr(qty(Math.round(area * 10) / 10.0), english)))
        }
        "elec" -> {
            val sockets = measured.sumOf { r -> r.points.count { it.t == "socket" } }
            val switches = measured.sumOf { r -> r.points.count { it.t == "switch" } }
            val lights = measured.size * lightsEach
            val points = sockets + switches + lights
            // cable: round each room's walls once, and 2,5 m down to each point and up to each light
            val cable = measured.sumOf { r -> (areas(r, snap)?.perim ?: 0L) / 1000.0 + 2.5 * (r.points.count { it.t == "socket" || it.t == "switch" } + lightsEach) }
            facts["points"] = points.toDouble(); facts["cable"] = cable
            mat("socket", "pcs", sockets.toDouble(), t.pSocket); mat("switch", "pcs", switches.toDouble(), t.pSwitch); mat("light", "pcs", lights.toDouble(), t.pLight)
            mat("cable", "m", ceil(cable * 1.1 - 1e-9), t.pCable); mat("conduit", "m", ceil(cable - 1e-9), t.pConduit)
            mat("breaker", "pcs", if (measured.isEmpty()) 0.0 else (measured.size + 1).toDouble(), t.pBreaker)
            lab("elecLab", points * num(t.lPoint), mapOf("n" to points))
        }
        "plumb" -> {
            val water = measured.sumOf { r -> r.points.count { it.t == "cold" || it.t == "hot" } }
            val sewer = measured.sumOf { r -> r.points.count { it.t == "sewer" } }
            // supply: 3 m to each water point and once round the walls of a room that has water; drain: 2,5 m a point
            val pipe = measured.sumOf { r -> val w = r.points.count { it.t == "cold" || it.t == "hot" }; if (w == 0) 0.0 else 3.0 * w + (areas(r, snap)?.perim ?: 0L) / 1000.0 }
            facts["points"] = (water + sewer).toDouble(); facts["pipe"] = pipe
            mat("pipe", "m", ceil(pipe - 1e-9), t.pPipe); mat("sewer", "m", ceil(2.5 * sewer - 1e-9), t.pSewer)
            mat("fitting", "pcs", 4.0 * (water + sewer), t.pFitting); mat("tap", "pcs", water.toDouble(), t.pTap)
            lab("plumbLab", (water + sewer) * num(t.lPlumb), mapOf("n" to water + sewer))
        }
        "win" -> {
            val ops = measured.flatMap { it.openings }
            // one line a size: windows priced by their m², doors too; sills and reveals by the metre
            ops.groupBy { Triple(it.type, it.w, it.h) }.toSortedMap(compareBy({ it.first }, { -it.second }, { -it.third })).forEach { (k, list) ->
                val (type, w, h) = k
                val m2 = w * h / 1e6
                mat(if (type == "door") "door" else "window", "pcs", list.size.toDouble(), money(m2 * num(if (type == "door") t.pDoorM2 else t.pWinM2)),
                    mapOf("w" to w, "h" to h))
            }
            val wins = ops.filter { it.type == "window" }
            mat("sill", "m", ceil(wins.sumOf { (it.w + 100) / 1000.0 } * 10 - 1e-9) / 10, t.pSillM)
            mat("reveal", "m", ceil(ops.sumOf { (it.w + 2 * it.h) / 1000.0 } * 10 - 1e-9) / 10, t.pRevealM)
            facts["count"] = ops.size.toDouble()
            lab("winLab", ops.size * num(t.lWin), mapOf("n" to ops.size))
        }
    }
    return TradeResult(mats, labor, facts)
}
