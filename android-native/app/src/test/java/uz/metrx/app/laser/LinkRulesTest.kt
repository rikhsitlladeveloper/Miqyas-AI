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

    @Test fun refusalStatusesBeforeConnectingAreRefusalsOthersAreNoAnswer() {
        for (s in listOf(133, 8, 257)) assertEquals(DropKind.REFUSED, LinkRules.drop(s, ready = false, gattUp = false, msSinceUp = -1))
        assertEquals(DropKind.NO_ANSWER, LinkRules.drop(62, ready = false, gattUp = false, msSinceUp = -1))
        assertEquals(DropKind.NO_ANSWER, LinkRules.drop(0, ready = false, gattUp = false, msSinceUp = -1))
    }

    @Test fun busyOnlyAfterALinkWasEstablished() {
        // two quick 133s before any "connected" (Android 8 Xiaomi/Samsung): never QUICK, so never counted towards busy
        repeat(2) { assertEquals(DropKind.REFUSED, LinkRules.drop(133, ready = false, gattUp = false, msSinceUp = -1)) }
        // two drops right after "connected": QUICK, and the second is busy
        val quick = (1..2).map { LinkRules.drop(133, ready = false, gattUp = true, msSinceUp = 200) }
        assertTrue(quick.all { it == DropKind.QUICK })
        assertTrue(LinkRules.isBusy(quick.size))
    }

    @Test fun refusalsAndFailedDiscoveriesAreRetriedOnceForTheBuilder() {
        assertTrue(LinkRules.softRetry(1, user = true))
        assertFalse(LinkRules.softRetry(2, user = true))
        // a background try is not retried at once: its plan tries again later
        assertFalse(LinkRules.softRetry(1, user = false))
    }

    // ---- service discovery ----

    @Test fun aFailedDiscoveryIsRetriedNeverNotALaser() {
        assertEquals(Discovery.RETRY, LinkRules.discovery(133, 0, sps = false))
        assertEquals(Discovery.RETRY, LinkRules.discovery(129, 5, sps = false))
        assertEquals(Discovery.RETRY, LinkRules.discovery(133, 5, sps = true))
        // "success" with nothing in it (a stale GATT cache) says nothing about the device either
        assertEquals(Discovery.RETRY, LinkRules.discovery(0, 0, sps = false))
    }

    @Test fun notALaserOnlyAfterADiscoveryThatWorked() {
        assertEquals(Discovery.NOT_LASER, LinkRules.discovery(0, 4, sps = false))
        assertEquals(Discovery.OK, LinkRules.discovery(0, 4, sps = true))
    }

    // ---- background tries ----

    @Test fun backgroundTriesStopAfterFiveOrThreeWithTheRadarOpen() {
        assertFalse(LinkRules.bgCapped(LinkRules.BG_TRIES - 1, radarOpen = false))
        assertTrue(LinkRules.bgCapped(LinkRules.BG_TRIES, radarOpen = false))
        assertFalse(LinkRules.bgCapped(2, radarOpen = true))
        assertTrue(LinkRules.bgCapped(LinkRules.RADAR_BG_TRIES, radarOpen = true))
        assertTrue(LinkRules.RADAR_BG_TRIES < LinkRules.BG_TRIES)
    }

    @Test fun theFallbackScanKnowsTheRememberedLaserByAddressOrName() {
        val addr = "38:1F:C5:55:2E:C8"
        assertTrue(LinkRules.sameLaser(addr, "ZB-08", addr, null))
        assertTrue(LinkRules.sameLaser(addr, "ZB-08", addr.lowercase(), "ZB-08"))
        // a new address with the same name: re-learned
        assertTrue(LinkRules.sameLaser(addr, "ZB-08", "11:22:33:44:55:66", " zb-08 "))
        // another laser, or no name to go by
        assertFalse(LinkRules.sameLaser(addr, "ZB-08", "11:22:33:44:55:66", "ZB-10"))
        assertFalse(LinkRules.sameLaser(addr, "ZB-08", "11:22:33:44:55:66", null))
        assertFalse(LinkRules.sameLaser(addr, null, "11:22:33:44:55:66", "ZB-08"))
    }

    // ---- scan starts ----

    @Test fun atMostFourScanStartsIn30Seconds() {
        val g = ScanGate()
        var t = 1_000L
        repeat(ScanGate.MAX) { assertEquals(0L, g.waitMs(t)); g.started(t); t += 1_000 }
        // the 5th within 30 s waits until the first start is 30 s old
        assertEquals(1_000L + ScanGate.WINDOW_MS - t, g.waitMs(t))
        assertEquals(0L, g.waitMs(1_000L + ScanGate.WINDOW_MS))
    }

    @Test fun aFailedScanWaits30Seconds() {
        val g = ScanGate()
        g.started(0); g.failed(300)
        assertEquals(ScanGate.FAIL_WAIT_MS, g.waitMs(300))
        assertEquals(ScanGate.FAIL_WAIT_MS - 10_000, g.waitMs(10_300))
        assertEquals(0L, g.waitMs(300 + ScanGate.FAIL_WAIT_MS))
        // Bluetooth turned off and on: at once
        g.failed(50_000); g.clearFail()
        assertEquals(0L, g.waitMs(50_001))
    }

    // ---- redrawing the radar ----

    @Test fun aDeviceIsRedrawnAtMostTwiceASecondUnlessItReallyChanged() {
        val a = FoundDev("A", "ZB-08", -60, true, -60f, 1_000)
        assertTrue(RadarMath.publish(null, a, 1_000))
        assertFalse(RadarMath.publish(a, a.copy(rssi = -61, avg = -60.4f, seen = 1_200), 1_200))
        assertTrue(RadarMath.publish(a, a.copy(avg = -60.4f, seen = 1_500), 1_500))
        assertTrue(RadarMath.publish(a, a.copy(avg = -62f, seen = 1_100), 1_100))
        assertTrue(RadarMath.publish(a, a.copy(laser = false, seen = 1_100), 1_100))
        assertTrue(RadarMath.publish(a, a.copy(name = "ZB-09", seen = 1_100), 1_100))
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
