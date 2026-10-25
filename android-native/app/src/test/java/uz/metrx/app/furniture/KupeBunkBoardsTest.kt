package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigInteger

/**
 * The founder's answers of 25 Oct 2026 in the parts list and the price: a kupe's outer sides, top and plinth of the
 * fronts' board; its mirror and lacobel below the split rail only, the upper fronts' board above it; a bunk's or loft
 * bed's ladder and guards in the wood accent (iPhone KupeBunkBoardsTests, the same cases and numbers).
 */
class KupeBunkBoardsTest {
    private val ws = Workshop()

    private fun cost(f: Furniture) = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false)
    private fun line(f: Furniture, key: String) = cost(f).lines.singleOrNull { it.key == key }

    /** A free-standing kupe 2400 × 2500 × 600 (its own side panels, on its plinth), no shelves, two colours, the middle door a mirror. */
    private fun kupe(h: Int = 2500, shelf: Int = 0): Furniture {
        val f = newFreeWardrobe("Kupe", "s3", 2400, h, 600, false, "slide", ws)
        val ins = if (shelf > 0) listOf(Insert("shelf", pos = shelf)) else emptyList()
        val g = f.copy(id = "s", mats = f.mats.copy(frontUp = "ldsp18a"), modules = f.modules.map { m -> m.copy(id = "sm", sections = m.sections.map { it.copy(inserts = ins) }) })
        return withMiddleFill(g, "mirror")
    }

    private fun mats(f: Furniture, key: String) = partsWithMat(f, ws).filter { it.first.key == key }.map { it.second }.toSet()

    @Test fun aKupesOuterSidesTopAndPlinthAreOfTheFrontBoard() {
        val k = kupe()
        val m = k.modules[0]
        assertEquals(listOf("front", "front", "front", "carcass", "carcass"), listOf("fp.side", "fp.top", "fp.plinth", "fp.bottom", "fp.divider").map { wardRole(m, it) })
        // the lower fronts' board, also on a two-tone kupe; the bottom and the inside stay carcass
        assertEquals(setOf("ldsp16k"), mats(k, "fp.side")); assertEquals(setOf("ldsp16k"), mats(k, "fp.top")); assertEquals(setOf("ldsp16k"), mats(k, "fp.plinth"))
        assertEquals(setOf("ldsp16w"), mats(k, "fp.bottom")); assertEquals(setOf("ldsp16w"), mats(k, "fp.divider"))
        val ps = partsOf(m, ws)
        assertEquals(2, ps.single { it.key == "fp.side" }.qty); assertEquals(1, ps.single { it.key == "fp.top" }.qty); assertEquals(1, ps.single { it.key == "fp.bottom" }.qty)
        // the cut list cuts them so
        val rows = cutList(listOf(k), ws)
        assertTrue(rows.any { it.mat == "ldsp16k" && it.p.key == "fp.side" && it.p.qty == 2 })
        assertTrue(rows.none { it.mat == "ldsp16w" && it.p.key in setOf("fp.side", "fp.top", "fp.plinth") })
        // a hinged wardrobe as before: its sides, top and bottom carcass
        val hinged = newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws)
        assertEquals(setOf("ldsp16w"), mats(hinged, "fp.side")); assertEquals(2, partsOf(hinged.modules[0], ws).single { it.key == "fp.top" }.qty)
        assertTrue(partsOf(hinged.modules[0], ws).none { it.key == "fp.bottom" })
    }

    @Test fun aKupesMirrorBelowItsSplitRailOnly() {
        val k = kupe()
        val m = k.modules[0]
        // doors 809 × 2348, fillings 769 wide; no hat shelf: the split rail 420 under the door's top
        assertEquals(809 to 2348, slideDoor(m, ws.t)); assertEquals(769 to 2278, slidePanel(m, ws.t))
        assertEquals(1928.0, kupeSplit(m, ws.t)!!, 1e-9)
        assertEquals(1881 to 393, kupeFillH(m, ws.t))
        // the mirror by its area below the split; the board over it from the upper fronts' board
        assertEquals(769 * 1881, hardware(listOf(k), ws)["mirror"])
        assertEquals(1.45, line(k, "mirror")!!.qty, 1e-9); assertEquals(BigInteger("362500"), line(k, "mirror")!!.amount)
        val up = partsOf(m, ws).single { it.key == "fp.slideUp" }
        // every door's (the board doors' too: KupeBoardDoorsTest)
        assertEquals(Triple(393, 769, 3), Triple(up.L, up.W, up.qty))
        assertEquals(setOf("ldsp18a"), mats(k, "fp.slideUp"))
        assertEquals(2, partsOf(m, ws).single { it.key == "fp.slidePanel" }.qty)
        // lacobel the same
        val lac = withMiddleFill(k, "glass")
        assertEquals(769 * 1881, hardware(listOf(lac), ws)["glass"])
        // a hat shelf sets the split: its top 1888 up the door
        val hat = kupe(shelf = 1900)
        assertEquals(1888.0, kupeSplit(hat.modules[0], ws.t)!!, 1e-9)
        assertEquals(1841 to 433, kupeFillH(hat.modules[0], ws.t))
        // a door under 1500 has no split: the whole filling, nothing above
        val low = kupe(h = 1500)
        assertNull(kupeSplit(low.modules[0], ws.t))
        assertEquals(slidePanel(low.modules[0], ws.t).second to 0, kupeFillH(low.modules[0], ws.t))
        assertTrue(partsOf(low.modules[0], ws).none { it.key == "fp.slideUp" })
        // all board doors: an upper part each too, as the 3D draws them (KupeBoardDoorsTest)
        assertEquals(3, partsOf(withMiddleFill(k, "ldsp").modules[0], ws).single { it.key == "fp.slideUp" }.qty)
    }

    @Test fun aBunksLadderAndGuardsInTheWoodAccent() {
        listOf("bunk", "loft").forEach { id ->
            val f = pieceOf(fModel(id)!!, emptyMap(), ws, id)
            val plain = withLook(f) { it.copy(accent = "") }
            // no accent: the fronts' board
            listOf("fp.ladder", "fp.rung", "fp.guard").forEach { assertEquals(id + it, setOf(plain.mats.front), mats(plain, it)) }
            val wood = withLook(f) { it.copy(accent = "wd_walnut") }
            listOf("fp.ladder", "fp.rung", "fp.guard").forEach { assertEquals(id + it, setOf("wd_walnut"), mats(wood, it)) }
            // the bed's sides and rails stay of the fronts' board
            assertEquals(setOf(wood.mats.front), mats(wood, "fp.bedSide"))
            // priced: the accent board by the m²
            val wl = line(wood, "wd_walnut")!!
            assertEquals("m2", wl.unit); assertTrue(wl.qty > 0)
            assertNull(line(plain, "wd_walnut"))
        }
    }
}
