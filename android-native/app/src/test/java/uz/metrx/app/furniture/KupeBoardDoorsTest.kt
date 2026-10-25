package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.ui.furniture.partHomes
import java.math.BigInteger

/**
 * A kupe's board doors cut as the 3D draws them (25 Oct 2026): the door's own board below its split rail, the upper
 * fronts' board over it, two panels even of one board (the split rail holds two); the heights by kupeFillH like the
 * mirror's (iPhone KupeBoardDoorsTests, the same cases and numbers).
 */
class KupeBoardDoorsTest {
    private val ws = Workshop()

    /** A free-standing kupe 2400 × [h] × 600 (its own side panels, on its plinth), three board doors; [up] its upper fronts' board. */
    private fun kupe(h: Int = 2500, shelf: Int = 0, up: String? = "ldsp18a"): Furniture {
        val f = newFreeWardrobe("Kupe", "s3", 2400, h, 600, false, "slide", ws)
        val ins = if (shelf > 0) listOf(Insert("shelf", pos = shelf)) else emptyList()
        return f.copy(id = "s", mats = f.mats.copy(frontUp = up), modules = f.modules.map { m -> m.copy(id = "sm", sections = m.sections.map { it.copy(inserts = ins) }) })
    }

    private fun one(f: Furniture, key: String) = partsOf(f.modules[0], ws).single { it.key == key }
    private fun mats(f: Furniture, key: String) = partsWithMat(f, ws).filter { it.first.key == key }.map { it.second }.toSet()

    @Test fun aBoardDoorIsTwoPanelsSplitByItsRail() {
        val k = kupe()
        val m = k.modules[0]
        assertEquals(3, m.slide!!.n); assertTrue((0 until 3).all { m.slide!!.panel(it) == "ldsp" })
        assertEquals(1928.0, kupeSplit(m, ws.t)!!, 1e-9)
        assertEquals(1881 to 393, kupeFillH(m, ws.t))
        // below the rail the door's board, over it the upper fronts': one of each a door
        val low = one(k, "fp.slidePanel"); val up = one(k, "fp.slideUp")
        assertEquals(Triple(1881, 769, 3), Triple(low.L, low.W, low.qty))
        assertEquals(Triple(393, 769, 3), Triple(up.L, up.W, up.qty))
        assertTrue(low.grain && up.grain)
        assertEquals(setOf("ldsp16k"), mats(k, "fp.slidePanel")); assertEquals(setOf("ldsp18a"), mats(k, "fp.slideUp"))
        // the two and the rail between them (each 5 into its groove) are the whole filling
        assertEquals(slidePanel(m, ws.t).second, low.L + up.L + KUPE_RAIL_S - 2 * KUPE_GROOVE)
        // the cut list: no full-height panel left
        val rows = cutList(listOf(k), ws)
        assertTrue(rows.any { it.mat == "ldsp16k" && it.p.key == "fp.slidePanel" && it.p.L == 1881 && it.p.qty == 3 })
        assertTrue(rows.any { it.mat == "ldsp18a" && it.p.key == "fp.slideUp" && it.p.L == 393 && it.p.qty == 3 })
        assertTrue(rows.none { it.p.L == 2278 })
    }

    @Test fun oneBoardAboveAndBelowIsStillTwoPanels() {
        val k = kupe(up = null)
        assertEquals(setOf("ldsp16k"), mats(k, "fp.slidePanel")); assertEquals(setOf("ldsp16k"), mats(k, "fp.slideUp"))
        val rows = cutList(listOf(k), ws).filter { it.p.key == "fp.slidePanel" || it.p.key == "fp.slideUp" }
        assertEquals(listOf(Triple("fp.slidePanel", 1881, 3), Triple("fp.slideUp", 393, 3)), rows.map { Triple(it.p.key, it.p.L, it.p.qty) })
        assertTrue(rows.all { it.mat == "ldsp16k" && it.p.W == 769 })
    }

    @Test fun theSplitMovesWithTheHatShelfAndALowDoorIsOnePanel() {
        val hat = kupe(shelf = 1900)
        assertEquals(1841 to 433, kupeFillH(hat.modules[0], ws.t))
        assertEquals(1841 to 3, one(hat, "fp.slidePanel").let { it.L to it.qty })
        assertEquals(433 to 3, one(hat, "fp.slideUp").let { it.L to it.qty })
        // a door under 1500 has no split: the whole filling of the door's board, nothing above
        val low = kupe(h = 1500)
        assertNull(kupeSplit(low.modules[0], ws.t))
        assertEquals(slidePanel(low.modules[0], ws.t).second to 3, one(low, "fp.slidePanel").let { it.L to it.qty })
        assertTrue(partsOf(low.modules[0], ws).none { it.key == "fp.slideUp" })
    }

    @Test fun labelsHighlightAndPriceFollowTheTwoPanels() {
        val k = kupe()
        val ls = labelsOf(listOf(k), ws)
        val ups = ls.filter { it.key == "fp.slideUp" }; val lows = ls.filter { it.key == "fp.slidePanel" }
        assertEquals(3, ups.size); assertTrue(ups.all { it.L == 393 && it.W == 769 && it.mat == "ldsp18a" })
        assertEquals(3, lows.size); assertTrue(lows.all { it.L == 1881 && it.W == 769 && it.mat == "ldsp16k" })
        // the Bazis view lights the upper panels in their box
        val row = cutList(listOf(k), ws).single { it.p.key == "fp.slideUp" }
        val homes = partHomes(listOf(k), row, ws)
        assertEquals(setOf("s"), homes.keys); assertEquals(1, homes.getValue("s").size)
        assertEquals(homes, partHomes(listOf(k), cutList(listOf(k), ws).single { it.p.key == "fp.slidePanel" }, ws))
        // priced by the sheet as the boards are: the three upper panels take one sheet of the upper board
        val l = costOf(listOf(k), ws, MAT_PRESETS, HW_PRESETS, order = false).lines.single { it.key == "ldsp18a" }
        assertEquals("sheet", l.unit); assertEquals(1.0, l.qty, 1e-9); assertEquals(BigInteger("720000"), l.amount)
    }
}
