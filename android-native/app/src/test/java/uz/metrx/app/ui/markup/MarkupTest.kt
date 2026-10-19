package uz.metrx.app.ui.markup

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.text.font.FontFamily
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.core.Lang
import uz.metrx.app.data.Item
import uz.metrx.app.data.MkEl
import uz.metrx.app.geo.LenUnit

/** Marks on drawings and photos (prototype mkBBox, mkSVG's fit, the value pill, the eraser's reach). */
class MarkupTest {
    private val f = MkFmt(LenUnit.M, false, "m", Lang.UZ, FontFamily.Default)
    private val dim = MkEl("d", "dim", listOf(listOf(352f, 112f), listOf(668f, 112f)), "red", v = 1200)
    private val photo = Item("p", "photo", W = 1000, H = 750, els = listOf(dim))

    @Test fun emptyDrawingHasNoMarkedArea() = assertNull(mkBBox(Item("a", "drawing")))

    @Test fun markedAreaHasAMarginAndAMinimumSize() {
        val b = mkBBox(Item("a", "drawing", els = listOf(MkEl("l", "line", listOf(listOf(100f, 100f), listOf(200f, 100f))))))!!
        assertEquals(420f, b.width, .01f); assertEquals(315f, b.height, .01f); assertEquals(Offset(150f, 100f), b.center)
    }

    @Test fun photoShowsWholeAndFitsInside() {
        val vb = mkViewBox(photo, MkMode.REPORT)
        assertEquals(Rect(0f, 0f, 1000f, 750f), vb)
        val (k, ox, oy) = mkFit(vb, Rect(0f, 0f, 500f, 500f))
        assertEquals(.5f, k, 1e-4f); assertEquals(0f, ox, 1e-3f); assertEquals(62.5f, oy, 1e-3f)
    }

    @Test fun tappingTheValueOpensTheDimension() {
        val pill = mkPill(dim, f)
        assertEquals(Offset(510f, 112f), pill.center)
        assertEquals("d", mkLabelAt(photo, Offset(510f, 120f), f)?.id)
        assertNull(mkLabelAt(photo, Offset(510f, 300f), f))
    }

    @Test fun eraserReachesNearTheLineOnly() {
        assertTrue(mkNear(dim, Offset(400f, 130f)))
        assertFalse(mkNear(dim, Offset(400f, 160f)))
    }

    /* ---------- photo edge measuring, part 1: letters, line ends, zoom and the loupe ---------- */

    @Test fun dimensionsAreLetteredInTheOrderDrawn() {
        val two = photo.copy(els = listOf(dim, MkEl("t", "text", listOf(listOf(10f, 10f)), txt = "x"), dim.copy(id = "e")))
        assertEquals(mapOf("d" to "A", "e" to "B"), mkLetters(two))
        // the letter makes the pill wider, around the same centre
        val plain = mkPill(dim, f); val lettered = mkPill(dim, f, letter = "A")
        assertEquals(plain.center, lettered.center); assertEquals(plain.width + 42f, lettered.width, .01f)
    }

    @Test fun pillsKeepTheirScreenSizeWhenZoomed() {
        val p = mkPill(dim, f, zoom = 2f)
        assertEquals(mkPill(dim, f).width / 2, p.width, .01f); assertEquals(28f, p.height, .01f)
        assertEquals("d", mkLabelAt(photo, Offset(510f, 112f), f, zoom = 2f)?.id)
    }

    @Test fun aLineEndIsFoundNearTheFinger() {
        assertEquals("d" to 1, mkEndAt(photo, Offset(660f, 118f), 20f)?.let { it.first.id to it.second })
        assertEquals(0, mkEndAt(photo, Offset(350f, 110f), 20f)?.second)
        assertNull(mkEndAt(photo, Offset(510f, 112f), 20f))
    }

    private val view = Rect(0f, 0f, 400f, 600f)   // a tall view: the 1000 × 750 photo fills its width, 300 high

    @Test fun zoomScalesAboutTheCentre() {
        assertEquals(view, mkZoomBox(view, 1f, Offset.Zero))
        val z = mkZoomBox(view, 2f, Offset(10f, 0f))
        assertEquals(Rect(-190f, -300f, 610f, 900f), z)
    }

    @Test fun panNeverLeavesAGap() {
        // at 1× the photo fits: no pan; at 2× it is 800 × 600 in a 400 × 600 view: 200 either way across, none down
        assertEquals(Offset.Zero, mkClampPan(photo, view, 1f, Offset(50f, 50f)))
        assertEquals(Offset(200f, 0f), mkClampPan(photo, view, 2f, Offset(500f, 80f)))
        mkClampPan(photo, view, 2f, Offset(-500f, -80f)).let { assertEquals(-200f, it.x, 1e-4f); assertEquals(0f, it.y, 1e-4f) }
    }

    @Test fun aPinchKeepsThePhotoUnderTheFingers() {
        val c = Offset(300f, 300f)
        val before = mkToItem(photo, mkZoomBox(view, 1f, Offset.Zero), c)
        val (z, pan) = mkPinch(photo, view, 1f, Offset.Zero, 2f, c, Offset.Zero)
        assertEquals(2f, z, 1e-4f)
        val after = mkToItem(photo, mkZoomBox(view, z, pan), c)
        assertEquals(before.x, after.x, .01f); assertEquals(before.y, after.y, .5f)
        // never past 4×, never under 1×
        assertEquals(4f, mkPinch(photo, view, 3f, Offset.Zero, 3f, c, Offset.Zero).first, 1e-4f)
        assertEquals(1f, mkPinch(photo, view, 1.2f, Offset.Zero, .5f, c, Offset.Zero).first, 1e-4f)
    }

    @Test fun theLoupeSitsAboveTheFingerOrBelowNearTheTop() {
        val size = androidx.compose.ui.geometry.Size(400f, 600f)
        assertEquals(Offset(200f, 206f), mkLoupeAt(Offset(200f, 300f), size, 60f, 34f))
        assertEquals(Offset(200f, 144f), mkLoupeAt(Offset(200f, 50f), size, 60f, 34f))
        assertEquals(60f, mkLoupeAt(Offset(10f, 300f), size, 60f, 34f).x, 1e-4f)
    }

    @Test fun theLoupeShowsTheFingersPointMagnified() {
        val s = Offset(120f, 250f); val l = Offset(120f, 156f)
        val lb = mkLoupeBox(view, s, l, 2.5f)
        assertEquals(view.width * 2.5f, lb.width, 1e-3f)
        // the photo point under the finger is at the loupe's centre
        val p = mkToItem(photo, view, s); val q = mkToItem(photo, lb, l)
        assertEquals(p.x, q.x, .01f); assertEquals(p.y, q.y, .01f)
    }
}
