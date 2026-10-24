package uz.metrx.app.laser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The radar page's pure rules (laser/LinkRules.kt): placing lasers, reading GATT drops, counting tries, waiting. */
class LinkRulesTest {
    private val eps = 1e-4f

    // ---- RSSI → distance from the centre ----

    @Test fun strongSignalSitsNearTheCentreWeakAtTheEdge() {
        assertEquals(RadarMath.R_MIN, RadarMath.radius(-45f), eps)
        assertEquals(RadarMath.R_MAX, RadarMath.radius(-90f), eps)
        assertEquals((RadarMath.R_MIN + RadarMath.R_MAX) / 2f, RadarMath.radius(-67.5f), eps)
    }

    @Test fun radiusIsClampedAndMonotonic() {
        assertEquals(RadarMath.R_MIN, RadarMath.radius(-20f), eps)
        assertEquals(RadarMath.R_MAX, RadarMath.radius(-110f), eps)
        var last = 0f
        for (r in -45 downTo -90) { val v = RadarMath.radius(r.toFloat()); assertTrue(v >= last); last = v }
    }

    @Test fun smoothingMovesPartWayAndTakesTheFirstValueAsItIs() {
        assertEquals(-60f, RadarMath.smooth(null, -60), eps)
        val s = RadarMath.smooth(-60f, -80)
        assertTrue(s < -60f && s > -80f)
        // many equal readings converge
        var v: Float? = null
        repeat(40) { v = RadarMath.smooth(v, -70) }
        assertEquals(-70f, v!!, .01f)
    }

    @Test fun barsAndWords() {
        assertEquals(4, RadarMath.bars(-50)); assertEquals(3, RadarMath.bars(-58)); assertEquals(2, RadarMath.bars(-70)); assertEquals(1, RadarMath.bars(-85))
        assertEquals("lr.sigGood", RadarMath.qualityKey(-58)); assertEquals("lr.sigOk", RadarMath.qualityKey(-70)); assertEquals("lr.sigWeak", RadarMath.qualityKey(-88))
    }

    // ---- stable angle ----

    @Test fun angleIsStablePerAddressAndInRange() {
        val a = RadarMath.angle("38:1F:C5:55:2E:C8")
        assertEquals(a, RadarMath.angle("38:1F:C5:55:2E:C8"), 0f)
        assertEquals(a, RadarMath.angle("38:1f:c5:55:2e:c8"), 0f)
        assertTrue(a >= 0f && a < 360f)
        val many = (0 until 50).map { RadarMath.angle("AA:BB:CC:DD:EE:%02X".format(it)) }
        assertTrue(many.all { it >= 0f && it < 360f })
        assertTrue("addresses spread round the radar", many.toSet().size > 40)
    }

    @Test fun staleLasersLeave() {
        assertFalse(RadarMath.stale(1_000, 1_000 + RadarMath.STALE_MS))
        assertTrue(RadarMath.stale(1_000, 1_001 + RadarMath.STALE_MS))
        assertFalse("never seen counts as fresh", RadarMath.stale(0, 99_999_999))
    }

    // ---- failure classification from GATT events ----

    @Test fun aReadyLinkThatDropsIsLost() {
        assertEquals(DropKind.LOST, LinkRules.drop(8, ready = true, gattUp = true, msSinceUp = 60_000))
        assertEquals(DropKind.LOST, LinkRules.drop(0, ready = true, gattUp = true, msSinceUp = 100))
    }

    @Test fun aDropRightAfterConnectingIsQuick() {
        assertEquals(DropKind.QUICK, LinkRules.drop(19, ready = false, gattUp = true, msSinceUp = 300))
        assertEquals(DropKind.QUICK, LinkRules.drop(0, ready = false, gattUp = true, msSinceUp = LinkRules.QUICK_MS))
        assertEquals(DropKind.NO_ANSWER, LinkRules.drop(0, ready = false, gattUp = true, msSinceUp = LinkRules.QUICK_MS + 1))
    }

    @Test fun refusalStatusesBeforeConnectingAreQuickOthersAreNoAnswer() {
        for (s in listOf(133, 8, 257)) assertEquals(DropKind.QUICK, LinkRules.drop(s, ready = false, gattUp = false, msSinceUp = -1))
        assertEquals(DropKind.NO_ANSWER, LinkRules.drop(62, ready = false, gattUp = false, msSinceUp = -1))
        assertEquals(DropKind.NO_ANSWER, LinkRules.drop(0, ready = false, gattUp = false, msSinceUp = -1))
    }

    @Test fun oneQuickDropIsRetriedTheSecondIsBusy() {
        assertFalse(LinkRules.isBusy(1))
        assertTrue(LinkRules.isBusy(2))
        assertTrue(LinkRules.isBusy(3))
    }

    // ---- attempt counting and backoff ----

    @Test fun threeFailedTriesShowTheHelpListForFixableReasonsOnly() {
        assertFalse(LinkRules.showMany(LaserFail.TIMEOUT, 2))
        assertTrue(LinkRules.showMany(LaserFail.TIMEOUT, 3))
        assertTrue(LinkRules.showMany(LaserFail.BUSY, 4))
        assertFalse(LinkRules.showMany(LaserFail.NOT_LASER, 5))
        assertFalse(LinkRules.showMany(LaserFail.BT_OFF, 3))
        assertFalse(LinkRules.showMany(LaserFail.PERMISSION, 3))
    }

    @Test fun backoffGrowsThenStaysAndTheOpenRadarCapsIt() {
        val waits = (0..9).map { LinkRules.backoffMs(it, radarOpen = false) }
        assertEquals(2_000L, waits[0])
        assertTrue(waits.zipWithNext().all { (a, b) -> b >= a })
        assertEquals(60_000L, waits.last())
        assertEquals(2_000L, LinkRules.backoffMs(0, radarOpen = true))
        assertEquals(LinkRules.LOST_WAIT_MS, LinkRules.backoffMs(6, radarOpen = true))
        assertEquals(2_000L, LinkRules.backoffMs(-3, radarOpen = false))
    }

    @Test fun countdownRoundsUpAndFillsTheBar() {
        assertEquals(4 to 0f, LinkRules.countdown(0, 4_000, 4_000))
        assertEquals(3, LinkRules.countdown(1_001, 4_000, 4_000).first)
        assertEquals(.5f, LinkRules.countdown(2_000, 4_000, 4_000).second, eps)
        assertEquals(0 to 1f, LinkRules.countdown(5_000, 4_000, 4_000))
        assertEquals(1f, LinkRules.countdown(0, 0, 0).second, eps)
    }
}
