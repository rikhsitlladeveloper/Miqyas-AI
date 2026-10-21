package uz.metrx.app.furniture

import kotlinx.serialization.Serializable
import java.math.BigDecimal
import java.math.BigInteger
import java.math.RoundingMode

/*
 * The customer price of a furniture order (furniture plan section 6.7): the cost plus a margin, kitchens by the running
 * metre, or a price typed by hand. The cost is always worked out; the profit is the maker's only.
 */

/**
 * How the order is priced: [mode] "margin" (cost + [pct] %, the workshop's margin when null), "run" (kitchens: the lower
 * row's running metres × [rRun] plus tall units × [rTall]; other furniture by the margin) or "fixed" ([fixed]).
 * [days] to make it and [inst] to install it, working days, for the customer's PDF.
 */
@Serializable
data class FPrice(
    val mode: String = "margin",
    val pct: Int? = null,
    val rRun: String = "4400000",
    val rTall: String = "",
    val fixed: String = "",
    val days: Int = 18,
    val inst: Int = 1
)

/** One line of the customer's price: [key] a furniture id, or "deliver" for delivery and installation. */
data class PriceLine(val key: String, val amount: BigInteger)

/** The order's cost, the customer price (its lines; none when fixed), and the profit. */
data class Priced(val cost: Cost, val price: BigInteger, val lines: List<PriceLine>) {
    val profit: BigInteger get() = price - cost.total
    /** Profit as tenths of a percent of the price (231 = 23,1 %). */
    val profitPct10: Int get() = if (price.signum() == 0) 0 else BigDecimal(profit).multiply(BigDecimal(1000)).divide(BigDecimal(price), 0, RoundingMode.HALF_UP).toInt()
}

private fun money(s: String) = s.replace(" ", "").takeIf { it.isNotEmpty() }?.toBigIntegerOrNull()

/** Running metres of a kitchen's lower rows, in millimetres. */
fun runMm(f: Furniture) = f.modules.filter { !isUpper(it) && it.type != "tall" && !(it.type == "gap" && (it.app == "fridge" || it.app == "space")) }.sumOf { it.w }

fun priceOf(fs: List<Furniture>, fp: FPrice, ws: Workshop, mats: List<Mat>, hws: List<Hw>): Priced {
    val cost = costOf(fs, ws, mats, hws)
    val pct = fp.pct ?: ws.margin
    val built = fs.filter { it.modules.isNotEmpty() }
    // delivery and installation once an order, with the margin
    val orderLab = cost.lines.filter { it.group == "lab" && (it.key == "fc.install" || it.key == "fc.deliver") }.fold(BigInteger.ZERO) { a, l -> a + l.amount }
    fun byMargin(f: Furniture) = withMargin(costOf(listOf(f), ws, mats, hws, order = false).total, pct)
    if (fp.mode == "fixed") {
        val v = money(fp.fixed) ?: BigInteger.ZERO
        return Priced(cost, v, emptyList())
    }
    val lines = built.map { f ->
        val v = if (fp.mode == "run" && f.kind == "kitchen") {
            val run = BigDecimal(money(fp.rRun) ?: BigInteger.ZERO).multiply(BigDecimal(runMm(f))).divide(BigDecimal(1000), 0, RoundingMode.HALF_UP).toBigInteger()
            val talls = f.modules.count { it.type == "tall" }
            run + (money(fp.rTall) ?: BigInteger.ZERO) * BigInteger.valueOf(talls.toLong())
        } else byMargin(f)
        PriceLine(f.id, v)
    } + if (orderLab.signum() > 0) listOf(PriceLine("deliver", withMargin(orderLab, pct))) else emptyList()
    return Priced(cost, lines.fold(BigInteger.ZERO) { a, l -> a + l.amount }, lines)
}
