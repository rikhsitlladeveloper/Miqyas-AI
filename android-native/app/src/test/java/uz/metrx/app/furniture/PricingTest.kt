package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.report.labelled
import java.math.BigInteger

/** The customer price (furniture plan section 6.7): margin, per running metre, fixed; profit; module labels for the pack. */
class PricingTest {
    private val ws = Workshop()
    private val f0 = Furniture("k", "kitchen", "Oshxona 1", walls = listOf("A", "B"), layout = "L")
    private val kitchen = autoFill(f0, runsOf(f0) { mapOf("A" to 3400, "B" to 2600)[it] }, ws, emptyList(), emptyList())
    private val ward = Furniture("w", "wardrobe", "Shkaf 1", walls = listOf("D"), modules = listOf(wardrobeTemplate(ws, "D", 10, 2400, 2500, true)))
    private val fs = listOf(kitchen, ward)
    private fun b(v: Long) = BigInteger.valueOf(v)

    @Test fun marginPricesEachPieceAndTheDelivery() {
        val p = priceOf(fs, FPrice(), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(listOf("k", "w", "deliver"), p.lines.map { it.key })
        assertEquals(withMargin(costOf(listOf(kitchen), ws, MAT_PRESETS, HW_PRESETS, order = false).total, 30), p.lines[0].amount)
        assertEquals(withMargin(b(1_500_000 + 300_000), 30), p.lines[2].amount)
        assertEquals(p.lines.fold(BigInteger.ZERO) { a, l -> a + l.amount }, p.price)
        assertEquals(p.price - p.cost.total, p.profit)
        assertTrue(p.profit.signum() > 0)
    }

    @Test fun kitchensByTheRunningMetre() {
        val p = priceOf(fs, FPrice(mode = "run", rRun = "4400000", rTall = "1000000"), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(5400, runMm(kitchen))                                  // 3400 on A + 2000 on B (the corner is A's)
        assertEquals(b(5_400L * 4_400_000 / 1000), p.lines[0].amount)        // no tall units in this kitchen
        assertEquals(priceOf(fs, FPrice(), ws, MAT_PRESETS, HW_PRESETS).lines[1].amount, p.lines[1].amount)   // the wardrobe by the margin
    }

    @Test fun aFixedPriceAndALoss() {
        val p = priceOf(fs, FPrice(mode = "fixed", fixed = "10 000 000"), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(b(10_000_000), p.price); assertTrue(p.lines.isEmpty())
        assertTrue(p.profit.signum() < 0); assertTrue(p.profitPct10 < 0)
        assertEquals(231, Priced(p.cost, b(1000), emptyList()).let { Priced(Cost(listOf(CostLine("lab", "x", 1.0, "order", b(769), b(769), false)), emptyList(), emptyList()), b(1000), emptyList()).profitPct10 })
    }

    @Test fun modulesGetReadableLabels() {
        val l = labelled(fs)
        val a = l[0].modules.filter { it.wall == "A" }
        assertEquals("A1", a.first { !isUpper(it) }.label)
        assertTrue(a.filter { isUpper(it) }.all { it.label.startsWith("A") && it.label.drop(1).toInt() > 6 })   // the upper row after the lower one
        assertEquals("Sh1", l[1].modules.single().label)
    }
}
