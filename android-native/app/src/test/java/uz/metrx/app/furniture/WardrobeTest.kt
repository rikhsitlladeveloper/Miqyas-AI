package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Opening
import uz.metrx.app.data.SitePoint

/** Wardrobe rules (furniture plan section 8) on the design's wardrobe: a 2420 niche, 2400 × 2500 × 600 on a plinth. */
class WardrobeTest {
    private val ws = Workshop()

    @Test fun lockedSectionsKeepTheirWidth() {
        val s = splitSections(2400, listOf(Section(0), Section(450, lock = true), Section(0), Section(0)))
        assertEquals(listOf(650, 450, 650, 650), s.map { it.w })
        assertEquals(listOf(600, 600, 601), splitSections(1801, List(3) { Section(0) }).map { it.w })
        assertEquals(4, sectionsFor(2400)); assertEquals(2, sectionsFor(1200)); assertEquals(1, sectionsFor(700))
    }

    @Test fun aBuiltInWardrobeHasNoSidesAtTheWalls() {
        val m = wardrobeTemplate(ws, "D", W_GAP_SIDE, 2400, 2500, builtIn = true)
        assertEquals(4, m.sections.size); assertEquals(2400, m.sections.sumOf { it.w })
        val ps = partsOf(m, ws)
        assertTrue(ps.none { it.key == "fp.side" })
        assertEquals(2400, ps.single { it.key == "fp.top" }.L)          // top and bottom run wall to wall
        assertEquals(2388, ps.single { it.key == "fp.divider" }.L)      // 2500 − plinth 80 − 2 × 16
        assertEquals(600 - 8, wardInner(m, m.sections, 0, 16))          // no side at the wall, half a divider
        val free = m.copy(sideL = true, sideR = true)
        assertEquals(2, partsOf(free, ws).single { it.key == "fp.side" }.qty)
        assertEquals(600 - 16 - 8, wardInner(free, free.sections, 0, 16))
        assertTrue(partsOf(m, ws).filter { it.key == "fp.door" }.all { it.L == 2417 })   // doors from the bottom panel up
    }

    @Test fun insertsFindTheirPlace() {
        val ih = wardInnerH(Module("m", "wardrobe", 600, 2500, 600, legs = false), 16)
        assertEquals(2388, ih)
        val s0 = Section(600)
        assertEquals(0, nextPos("drawer", s0, ih, 16))
        val s1 = s0.copy(inserts = listOf(Insert("drawer", 0, h = 200), Insert("drawer", 200, h = 200)))
        assertEquals(400, nextPos("drawer", s1, ih, 16))
        assertEquals((400 + ih) / 2, nextPos("shelf", s1, ih, 16))      // the middle of the tallest free space
        assertEquals(ih - 80, nextPos("rail", s0, ih, 16))
        val spread = spreadShelves(s1.copy(inserts = s1.inserts + List(3) { Insert("shelf") }), ih, 16)
        assertEquals(listOf(400 + 493, 400 + 2 * 493, 400 + 3 * 493), spread.inserts.filter { it.kind == "shelf" }.map { it.pos })
    }

    @Test fun checksFindWhatDoesNotFit() {
        val m = wardrobeTemplate(ws, "D", 10, 2400, 2500, builtIn = true)
        assertTrue(wardrobeChecks(m, 2420, 2520, ws, emptyList(), emptyList()).isEmpty())
        val c = wardrobeChecks(m.copy(w = 2500, x = 0), 2420, 2450, ws, listOf(Opening("o", "door", "D", 900, 2100, 1500, 0)),
            listOf(SitePoint("s", "socket", "D", 300, 300)))
        assertEquals(setOf("wc.wide", "wc.high", "wc.sum", "kc.door", "kc.socket"), c.map { it.key }.toSet())
        assertEquals(80, c.single { it.key == "wc.wide" }.vars["v"])
        // a rail with too little room under it, a drawer through a shelf, a wide door
        val s = Section(1100, Fronts("door", 1), listOf(Insert("shelf", pos = 1000), Insert("rail", pos = 1700), Insert("drawer", 900, h = 200)))
        val one = Module("w", "wardrobe", 1100, 2500, 600, wall = "A", legs = false, sections = listOf(s))
        val k = wardrobeChecks(one, null, null, ws, emptyList(), emptyList()).map { it.key }.toSet()
        assertEquals(setOf("wc.shelfWide", "wc.doorWide", "wc.overlap", "wc.hang"), k)
        assertFalse(wardrobeChecks(one.copy(sections = listOf(s.copy(w = 1100, fronts = Fronts("door", 2), inserts = emptyList()))), null, null, ws, emptyList(), emptyList()).any { it.level == "err" })
    }

    @Test fun theLiftIsHardware() {
        val m = Module("w", "wardrobe", 900, 2500, 600, legs = false, sections = listOf(Section(900, Fronts("open", 0), listOf(Insert("lift", pos = 1500)))))
        assertEquals(1, hardwareOf(m, ws)["lift"])
        assertTrue(HW_PRESETS.any { it.kind == "lift" })
    }

    @Test fun aNewWardrobeKeepsClearOfTheDoor() {
        assertEquals(Triple(10, 2400, true), placeOn(2420, "D", emptyList(), 2500))
        val door = listOf(Opening("o", "door", "D", 900, 2100, 1500, 0))
        assertEquals(0 to 1500, freeSpan(2600, "D", door, 2500))
        assertEquals(Triple(10, 1440, false), placeOn(2600, "D", door, 2500))
    }

    @Test fun theRailStaysWithinReach() {
        // at most 1800 from the floor however tall the wardrobe; a tall one keeps a shelf more over the hat shelf
        listOf(2200, 2500, 2700).forEach { h ->
            val ins = wardrobeTemplate(ws, "D", 10, 1200, h, builtIn = false).sections[0].inserts
            assertTrue("$h", PLINTH + ws.t + ins.single { it.kind == "rail" }.pos <= 1800)
            assertEquals("$h", if (h > 2200) 2 else 1, ins.count { it.kind == "shelf" })
        }
    }
}
