package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import uz.metrx.app.data.Pt
import kotlin.math.sin

class SketchTest {
    /** A wobbly finger stroke round a 200 × 120 rectangle, ending near the start. */
    private fun stroke(): List<Pt> {
        val p = ArrayList<Pt>()
        fun seg(x0: Double, y0: Double, x1: Double, y1: Double) { for (i in 0 until 40) { val t = i / 40.0; val w = 2 * sin(i * .7); p += Pt(x0 + (x1 - x0) * t + w, y0 + (y1 - y0) * t - w) } }
        seg(60.0, 80.0, 260.0, 80.0); seg(260.0, 80.0, 260.0, 200.0); seg(260.0, 200.0, 60.0, 200.0); seg(60.0, 200.0, 60.0, 88.0)
        return p
    }

    @Test fun strokeBecomesRectangle() {
        val r = processSketch(stroke(), tap = false, tapClosed = false, snap = true)
        assertNull(r.err)
        assertEquals(4, r.verts.size)
        val mm = sketchToMm(r.verts)
        // clockwise from the top-left corner, walls at right angles
        assertEquals(mm[0].y, mm[1].y, 1.0); assertEquals(mm[1].x, mm[2].x, 1.0)
    }

    @Test fun tappedCornersClose() {
        val taps = listOf(Pt(50.0, 50.0), Pt(250.0, 52.0), Pt(252.0, 200.0), Pt(48.0, 198.0))
        val r = processSketch(taps, tap = true, tapClosed = true, snap = true)
        assertNull(r.err); assertEquals(4, r.verts.size)
    }

    @Test fun tooShort() { assertEquals("short", processSketch(listOf(Pt(0.0, 0.0), Pt(5.0, 5.0)), false, false, true).err) }
}
