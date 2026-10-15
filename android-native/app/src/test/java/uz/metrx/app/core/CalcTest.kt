package uz.metrx.app.core

import org.junit.Assert.assertEquals
import org.junit.Test

/** The Measure page's brick tool (prototype qbCount): one layer, joints, spare rounded up, mortar left over. */
class CalcTest {
    @Test fun bricksForAWall() {
        // 2,435 × 2,723 m with 250×120×65 bricks, 10 mm joints, 5 % spare (checked on the emulator: 358 pcs, 0,13 m³)
        val (n, mortar) = brickCount(2435.0 * 2723, BrickSpec())
        assertEquals(358L, n)
        assertEquals(.1326, mortar, .0005)
    }

    @Test fun exactCountIsNotRoundedUp() {
        // 10 bricks' faces with joints and no spare stay 10
        assertEquals(10L, brickCount(10.0 * 260 * 75, BrickSpec(s = 0)).first)
    }
}
