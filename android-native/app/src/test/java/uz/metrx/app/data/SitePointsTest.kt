package uz.metrx.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Site points on a furniture order's walls (furniture plan section 5; design canvas screen 6). */
class SitePointsTest {
    private fun pt(t: String, off: Int, h: Int, d: Int = 0, mh: Int = 0) = SitePoint("x", t, "A", off, h, d, mh)

    @Test fun defaultsFollowTheUsualHeights() {
        assertEquals(300, pointDefaults("socket").first)
        assertEquals(Triple(450, 50, 0), pointDefaults("sewer"))
        assertEquals(Triple(1500, 300, 400), pointDefaults("meter"))
    }

    @Test fun sizesOnTheWall() {
        assertEquals(86 to 86, pointSize(pt("socket", 0, 0)))
        assertEquals(110 to 110, pointSize(pt("sewer", 0, 0, 110)))
        assertEquals(300 to 400, pointSize(pt("meter", 0, 0, 300, 400)))
    }

    @Test fun aPointMustBeOnItsWall() {
        assertNull(pointProblem(pt("cold", 1250, 550), 3400, 2700))
        assertEquals("pt.offBig", pointProblem(pt("cold", 3500, 550), 3400, 2700))
        assertEquals("pt.hBig", pointProblem(pt("gas", 100, 2800), 3400, 2700))
        // not measured yet: nothing to check against
        assertNull(pointProblem(pt("gas", 9000, 9000), null, null))
    }
}
