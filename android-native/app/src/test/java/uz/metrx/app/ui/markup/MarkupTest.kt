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
}
