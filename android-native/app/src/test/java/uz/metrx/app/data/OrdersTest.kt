package uz.metrx.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.math.BigInteger

/** A furniture order's stages and money (furniture plan section 4; design canvas screen 5). */
class OrdersTest {
    private fun order(stage: String = "quote") = Project("p1", "Oshxona", industry = "furniture", stage = stage)
    private fun b(v: Long) = BigInteger.valueOf(v)

    @Test fun approvingRecordsPriceAndPrepayment() {
        val p = approve(order(), b(32067100), halfOf(b(32067100)), 1L)
        assertEquals("approved", p.stage)
        assertEquals(b(16033550), orderMoney(p).paid)
        assertEquals(b(16033550), orderMoney(p).left)
        assertEquals(true, p.payments.single().pre)
    }

    @Test fun halfRoundsHalfUp() {
        assertEquals(b(16033550), halfOf(b(32067100)))
        assertEquals(b(6), halfOf(b(11)))
    }

    @Test fun approvingIsNotAPlainNextStep() {
        assertEquals("quote", nextStage(order("quote")).stage)
        assertEquals("design", nextStage(order("measure")).stage)
        assertEquals("installed", nextStage(order("production")).stage)
    }

    @Test fun lastPaymentOfAnInstalledOrderMakesItPaid() {
        var p = approve(order(), b(1000), b(500), 1L)
        p = nextStage(nextStage(p))                     // production, installed
        assertEquals("installed", p.stage)
        p = addPayment(p, b(500), "", 2L)
        assertEquals("paid", p.stage)
        assertEquals(BigInteger.ZERO, orderMoney(p).left)
        // taking that payment away again puts the order back to installed
        p = removePayment(p, p.payments.last().id)
        assertEquals("installed", p.stage)
    }

    @Test fun paidInProductionStaysInProduction() {
        var p = nextStage(approve(order(), b(1000), b(1000), 1L))
        assertEquals("production", p.stage)
        p = nextStage(p)                                 // installed with nothing left → paid
        assertEquals("paid", p.stage)
    }

    @Test fun owedCountsApprovedOrdersOnly() {
        val design = order("design").copy(id = "a", agreed = "999")
        val approved = approve(order().copy(id = "b"), b(1000), b(400), 1L)
        val builder = Project("c", "Uy", agreed = "5000", stage = "work")
        assertEquals(b(600) to 1, owed(listOf(design, approved, builder)))
    }

    @Test fun noPriceMeansNothingLeft() {
        assertNull(orderMoney(order()).left)
        assertEquals(0, fStage(Project("x", "y", stage = "estimate")))
    }
}
