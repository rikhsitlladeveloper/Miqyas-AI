package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The wardrobe's side panels, door hinges, base heights and inside spacing (Wardrobe.kt, Parts.kt). */
class WardrobeRulesTest {
    private val ws = Workshop()

    @Test fun singleDoorsHingeAsChosenElseInPairs() {
        val m = wardrobeTemplate(ws, "A", W_GAP_SIDE, 1500, 2200, false).copy(sections = List(3) { Section(500, Fronts("door", 1)) })
        assertEquals(listOf(false, true, true), m.sections.indices.map { hingeRight(m, it) })
        val chosen = m.copy(sections = m.sections.mapIndexed { i, s -> if (i == 1) s.copy(hinge = "L") else s })
        assertFalse(hingeRight(chosen, 1))
    }

    @Test fun aSlidingWardrobeUsesTheWallItMeetsAHingedOneKeepsItsSides() {
        val kupe = wardrobeTemplate(ws, "A", W_GAP_SIDE, 2000, 2500, true).copy(slide = Slide(2))
        // in the corner of a 3,0 m wall: no panel at the wall, one at the free end
        withSides(kupe, 3000).let { assertFalse(it.sideL); assertTrue(it.sideR) }
        // wall to wall: none
        withSides(kupe.copy(w = 2980), 3000).let { assertFalse(it.sideL); assertFalse(it.sideR) }
        // standing free: both
        withSides(kupe, 3000, free = true).let { assertTrue(it.sideL && it.sideR) }
        val hinged = wardrobeTemplate(ws, "A", W_GAP_SIDE, 2980, 2200, true)
        withSides(hinged, 3000).let { assertTrue(it.sideL && it.sideR) }
    }

    @Test fun legsAndAPlinthHaveTheirOwnHeights() {
        val m = wardrobeTemplate(ws, "A", W_GAP_SIDE, 1500, 2200, false)
        assertEquals(80, wardBase(m)); assertEquals(120, wardBase(m.copy(base = 120)))
        val legs = m.copy(legs = true, base = 150)
        assertEquals(150, legsOf(legs, ws)); assertEquals(legs.h + 150, outerH(legs, ws))
        assertEquals(0, wardBase(legs))
        // a kitchen on its own legs: the worktop follows
        val k = newFreeKitchen("Oshxona 1", "I", "I", listOf(3000), 0, 2700, ws).copy(baseH = 150)
        assertEquals(worktopTop(ws) + 50, worktopTop(wsOf(k, ws)))
    }

    @Test fun reorderedInsertsSpreadEvenlyAndARailKeepsItsHangingRoom() {
        // bottom first: a drawer, a rail, a shelf in a 2000 high section
        val out = respaced(listOf(Insert("drawer", h = 200), Insert("rail"), Insert("shelf")), 2000, 16)
        assertTrue(out.zipWithNext().all { (a, b) -> a.pos < b.pos })
        // the rail hangs at least 900 over the drawer's top
        assertTrue(out[1].pos - (out[0].pos + 200) >= 900)
        // three shelves: equal gaps
        val sh = respaced(List(3) { Insert("shelf") }, 1600, 16)
        val gaps = listOf(sh[0].pos) + sh.zipWithNext().map { (a, b) -> b.pos - a.pos - 16 }
        assertTrue(gaps.max() - gaps.min() <= 1)
    }
}
