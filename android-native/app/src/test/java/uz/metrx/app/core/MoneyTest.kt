package uz.metrx.app.core

import org.junit.Assert.assertEquals
import org.junit.Test
import uz.metrx.app.data.Estimate
import uz.metrx.app.data.Project
import uz.metrx.app.data.Row
import java.math.BigInteger

/** The estimate's numbers against the prototype: the BUILD_PLAN fixture, typing rules, rounding and display. */
class MoneyTest {
    private fun p(mats: List<Row>, labs: List<Row>, precision: Int = 0) = Project("p", "P", precision = precision, estimate = Estimate(mats, labs))

    @Test fun buildPlanGrandTotal() {
        // Paint 12 × 50 000, flooring 22 × 120 000, labour 1 000 000 = 4 240 000 so'm
        val t = totals(p(listOf(Row("a", "Paint", "@u.can", "12", "50000"), Row("b", "Floor", "@u.m2", "22", "120000")), listOf(Row("c", "Labour", amount = "1000000"))))
        assertEquals(BigInteger.valueOf(3_240_000), t.m); assertEquals(BigInteger.valueOf(1_000_000), t.l)
        assertEquals("4 240 000", moneyStr(t.g, 0, false)); assertEquals("4,240,000", moneyStr(t.g, 0, true))
    }

    @Test fun typingRules() {
        assertEquals(Dec.Ok(BigInteger.valueOf(4250)), parseDec("4,25", 3))
        assertEquals(Dec.Ok(BigInteger.valueOf(4250)), parseDec("4.25", 3))
        assertEquals(Dec.Ok(BigInteger.valueOf(120000)), parseDec("120 000", 0))
        assertEquals(Dec.Empty, parseDec("  ", 0))
        assertEquals(Dec.Format, parseDec("12a", 0)); assertEquals(Dec.Format, parseDec(",", 3)); assertEquals(Dec.Format, parseDec("1,2,3", 3))
        assertEquals(Dec.Negative, parseDec("-5", 0))
        assertEquals(Dec.Precision(0), parseDec("12,5", 0)); assertEquals(Dec.Precision(3), parseDec("1,2345", 3))
        assertEquals("120000", canonOf("120 000")); assertEquals("4.50", canonOf("4,50")); assertEquals("7", canonOf("007")); assertEquals("5", canonOf("5."))
    }

    @Test fun roundingHalfUp() {
        assertEquals(BigInteger.valueOf(1667), lineTotal("1.667", "1000", 0))   // 1.667 × 1000
        assertEquals(BigInteger.valueOf(2), lineTotal("1.5", "1", 0))           // 1.5 rounds up
        assertEquals(BigInteger.valueOf(1), lineTotal("1.499", "1", 0))
        assertEquals(BigInteger.valueOf(1850), lineTotal("1.5", "12.33", 2))    // 18.495 → 18.50
        assertEquals(BigInteger.ZERO, lineTotal("", "1000", 0))
    }

    @Test fun display() {
        assertEquals("1 500,5", fmtNumStr("1500.5", false)); assertEquals("150", fmtNumStr("150", false))
        assertEquals("18,50", moneyStr(BigInteger.valueOf(1850), 2, false)); assertEquals("0,05", moneyStr(BigInteger.valueOf(5), 2, false))
        val q = p(listOf(Row("a", "Oboy", "@u.m2", "150", "120000")), listOf(Row("b", "Ish", amount = "1500000")))
        assertEquals("19,5" to "mln", shortMoney(q, totals(q).g, false, "mln"))
        assertEquals("—" to null, shortMoney(q, BigInteger.ZERO, false, "mln"))
        assertEquals(1, rowsMissing(p(listOf(Row("a", "x", "@u.pcs", "1", "")), emptyList())))
    }
}
