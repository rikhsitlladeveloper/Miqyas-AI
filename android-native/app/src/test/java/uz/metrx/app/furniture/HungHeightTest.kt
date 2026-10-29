package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 1.0.2: a wall-hung piece is named by its box (W × H × D) everywhere, its height from the floor a line of its own
 * (Steps.kt pieceLift, shownVals, sizeLine); the step still asks the height to its top.
 */
class HungHeightTest {
    private val ws = Workshop()
    private fun piece(id: String, v: Map<String, Int> = emptyMap()) = pieceOf(fModel(id)!!, v, ws, id)

    @Test fun aWallSinkCabinetIsItsBoxWithItsHeightFromTheFloorApart() {
        val f = piece("sinkV", mapOf("mt" to 1))
        // the step's height is to its top (850); the box is 550, 300 above the floor
        assertEquals(850, valsOf(f, ws)["h"])
        assertEquals(550, shownVals(f, ws)["h"])
        assertEquals(300, pieceLift(f))
        assertEquals("800 × 550 × 450 mm", sizeLine(f, ws, "mm"))
        // the height from the floor moves with it, the box stays its size
        val up = resized(f, mapOf("h" to 1050), ws)
        assertEquals(750, shownVals(up, ws)["h"]); assertEquals(300, pieceLift(up))
    }

    @Test fun onLegsOrOnTheFloorThereIsNoHeightLine() {
        val legs = piece("sinkV")
        assertNull(pieceLift(legs))
        // on legs: the box with its legs, as before (850)
        assertEquals(850, shownVals(legs, ws)["h"]); assertEquals("800 × 850 × 450 mm", sizeLine(legs, ws, "mm"))
        assertNull(pieceLift(piece("h2")))
        assertNull(pieceLift(piece("dresser")))
    }

    @Test fun otherHungPiecesHaveTheirLineToo() {
        val mc = piece("mirrorC")
        assertEquals(1250, pieceLift(mc))
        assertEquals(wardOfF(mc)!!.h, shownVals(mc, ws)["h"])
        val sh = piece("shelfW")
        assertEquals(wardOfF(sh)!!.elev, pieceLift(sh))
        val pen = piece("penal", mapOf("mt" to 1))
        assertEquals(300, pieceLift(pen)); assertEquals(wardOfF(pen)!!.h, shownVals(pen, ws)["h"])
    }

    @Test fun aPieceOfSeveralBoxesIsNamedByItsWholeSize() {
        // a gorka stands on the floor as a whole; its hung boxes say their own height in the designer (boxLift)
        val g = piece("gorka")
        assertNull(pieceLift(g))
        val r = gorkaRoles(g)!!
        assertEquals(r.bridge!!.elev, boxLift(r.bridge!!)); assertEquals(GK_BASE_ELEV, boxLift(r.base!!))
        assertNull(boxLift(r.lows[0]))
        // a kitchen never has one
        assertNull(pieceLift(newFreeKitchen("K", "I", "I", listOf(3000), 0, 2700, ws, 0)))
    }
}
