package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Stage 2 types on the cabinet engine (Cabinets.kt). */
class CabinetsTest {
    private val ws = Workshop()

    @Test fun everyTypeHasSectionsThatFillItsWidthAndPassTheChecks() {
        CASE_TYPES.forEach { t ->
            val s = typeSize(t)
            val m = cabinetTemplate(t, ws, "A", 10, s.w, s.h, s.d)
            assertEquals(t, s.w, m.sections.sumOf { it.w })
            val c = wardrobeChecks(m, s.w + 20, 2700, ws, emptyList(), emptyList())
            assertTrue("$t: ${c.filter { it.level == "err" }}", c.none { it.level == "err" })
            assertTrue(t, partsOf(m, ws).isNotEmpty())
        }
    }

    @Test fun aDresserHasFourDrawersWithFrontFacesAndHandles() {
        val m = cabinetTemplate("dresser", ws, "A", 10, 1000, 850, 450)
        val ps = partsOf(m, ws)
        val faces = ps.filter { it.key == "fp.dFace" }
        assertEquals(4, faces.sumOf { it.qty }); assertTrue(faces.all { it.role == "front" })
        val hw = hardwareOf(m, ws)
        assertEquals(4, hw["runner"]); assertEquals(4, hw["handle"]); assertEquals(null, hw["hinge"])
    }

    @Test fun drawerFacesKeepTheDoorsGap() {
        val m = cabinetTemplate("dresser", ws, "A", 10, 1000, 850, 450)
        val ds = m.sections[0].inserts
        assertEquals(3, ds.first().pos)                                  // 3 mm over the bottom, 3 mm apart, inside the top
        ds.zipWithNext().forEach { (a, b) -> assertEquals(3, b.pos - (a.pos + a.h)) }
        assertTrue(ds.last().pos + ds.last().h <= wardInnerH(m, ws.t) - 3)
    }

    @Test fun aDeskHasNoBottomOrBackUnderItsKneeSpace() {
        val m = cabinetTemplate("desk", ws, "A", 10, 1200, 750, 600)
        assertTrue(hasKnee(m))
        val ps = partsOf(m, ws)
        assertEquals(1, ps.filter { it.key == "fp.top" }.sumOf { it.qty })
        assertEquals(1, ps.filter { it.key == "fp.bottom" }.sumOf { it.qty })      // under the pedestal only
        assertEquals(1, ps.filter { it.key == "fp.back" }.sumOf { it.qty })
        assertEquals(750 - ws.legH - 16, ps.single { it.key == "fp.divider" }.L)   // beside the knee space, down to the floor (750 with the legs)
    }

    @Test fun roomLessCabinetsAndTheGallery() {
        val f = newFreeCabinet("TV tumba 1", "tv", 1800, 500, 450, ws)
        assertEquals("wardrobe", f.kind); assertEquals("tv", f.type); assertEquals("other", kindKey(f))
        assertEquals(CASE_TYPES.size + PIECE_TYPES.size + ITEM_TYPES.size, modelsOf("other").size)
        assertTrue(modelsOf("wardrobe").none { it.type.isNotEmpty() })
    }
}
