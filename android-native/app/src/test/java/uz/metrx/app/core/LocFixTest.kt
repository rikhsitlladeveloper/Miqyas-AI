package uz.metrx.app.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.core.LocFix.Step

class LocFixTest {
    private fun fix(acc: Float, at: Long = 1_000_000L, cached: Boolean = false) = Fix(41.3111, 69.2797, acc, at, cached)

    /* ---- best fix ---- */

    @Test fun firstFixIsTheBest() {
        val a = fix(80f)
        assertSame(a, LocFix.better(null, a))
    }

    @Test fun moreAccurateWins() {
        val a = fix(80f); val b = fix(25f, 1_001_000L)
        assertSame(b, LocFix.better(a, b))
        assertSame(b, LocFix.better(b, fix(60f, 1_002_000L)))
    }

    @Test fun newerWinsOnATie() {
        val a = fix(30f, 1_000_000L); val b = fix(30f, 1_005_000L)
        assertSame(b, LocFix.better(a, b))
        assertSame(b, LocFix.better(b, a))
    }

    @Test fun liveBeatsCachedEvenWhenRougher() {
        val c = fix(15f, cached = true); val live = fix(60f)
        assertSame(live, LocFix.better(c, live))
        assertSame(live, LocFix.better(live, c))
    }

    @Test fun betterCachedReplacesWorseCached() {
        val c1 = fix(90f, cached = true); val c2 = fix(40f, cached = true)
        assertSame(c2, LocFix.better(c1, c2))
    }

    /* ---- stop rules ---- */

    @Test fun waitsWithoutAFix() = assertEquals(Step.WAIT, LocFix.step(null, 5_000L))

    @Test fun waitsWhileRough() = assertEquals(Step.WAIT, LocFix.step(fix(45f), 12_000L))

    @Test fun stopsAtTwentyMetres() {
        assertEquals(Step.DONE, LocFix.step(fix(20f), 3_000L))
        assertEquals(Step.DONE, LocFix.step(fix(4f), 0L))
        assertEquals(Step.WAIT, LocFix.step(fix(20.5f), 3_000L))
    }

    @Test fun aGoodCachedFixDoesNotStopTheSearch() = assertEquals(Step.WAIT, LocFix.step(fix(10f, cached = true), 2_000L))

    @Test fun afterThirtySecondsKeepsTheBest() {
        assertEquals(Step.DONE, LocFix.step(fix(150f), 30_000L))
        assertEquals(Step.DONE, LocFix.step(fix(40f, cached = true), 31_000L))
        assertEquals(Step.WAIT, LocFix.step(fix(150f), 29_999L))
    }

    @Test fun failsOnlyWithNoFixAfterThirtySeconds() {
        assertEquals(Step.FAIL, LocFix.step(null, 30_000L))
        assertEquals(Step.WAIT, LocFix.step(null, 29_000L))
    }

    @Test fun approximateOnlyStopsAtTheFirstLiveFix() {
        assertEquals(Step.DONE, LocFix.step(fix(2_000f), 1_000L, precise = false))
        assertEquals(Step.WAIT, LocFix.step(fix(2_000f, cached = true), 1_000L, precise = false))
    }

    /* ---- last known location ---- */

    @Test fun recentAndAccurateLastKnownIsUsed() {
        val now = 10_000_000L
        assertTrue(LocFix.freshEnough(fix(30f, now - 60_000L, true), now))
        assertTrue(LocFix.freshEnough(fix(100f, now - 119_000L, true), now))
    }

    @Test fun oldLastKnownIsNotUsed() {
        val now = 10_000_000L
        assertFalse(LocFix.freshEnough(fix(10f, now - 120_000L, true), now))
        assertFalse(LocFix.freshEnough(fix(10f, now - 3_600_000L, true), now))
    }

    @Test fun roughLastKnownIsNotUsed() {
        val now = 10_000_000L
        assertFalse(LocFix.freshEnough(fix(101f, now - 5_000L, true), now))
        assertFalse(LocFix.freshEnough(fix(0f, now - 5_000L, true), now))
    }

    @Test fun lastKnownFromTheFutureIsNotUsed() {
        val now = 10_000_000L
        assertFalse(LocFix.freshEnough(fix(10f, now + 5_000L, true), now))
    }

    @Test fun metresAreWholeAndAtLeastOne() {
        assertEquals(1, LocFix.metres(0.3f))
        assertEquals(13, LocFix.metres(12.6f))
    }
}
