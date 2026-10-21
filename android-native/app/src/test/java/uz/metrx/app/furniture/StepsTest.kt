package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The gallery and its size steps (Steps.kt): the groups, the steps of a model, a piece from typed sizes and back. */
class StepsTest {
    private val ws = Workshop()

    @Test fun everyModelIsInTheGalleryOnce() {
        val ids = GALLERY.flatMap { it.second }
        assertEquals(ids.size, ids.toSet().size)
        assertEquals(F_MODELS.map { it.id }.toSet(), ids.toSet())
        assertEquals(listOf("kitchen", "bedroom", "living", "hall", "office"), GALLERY.map { it.first })
    }

    @Test fun aKitchenAsksItsSidesItsIslandAndTheCeiling() {
        assertEquals(listOf("s0", "h"), stepsOf(fModel("I")!!).map { it.key })
        assertEquals(listOf("s0", "s1", "h"), stepsOf(fModel("L")!!).map { it.key })
        assertEquals(listOf("s0", "s1", "s2", "h"), stepsOf(fModel("U")!!).map { it.key })
        assertEquals(listOf("s0", "isl", "h"), stepsOf(fModel("O")!!).map { it.key })
        assertEquals("fz.pP", stepsOf(fModel("P")!!)[1].label)
        assertEquals(listOf(3000, 2000, 2700), stepsOf(fModel("L")!!).map { it.usual })
    }

    @Test fun aCabinetAsksWidthHeightDepth() {
        val w = stepsOf(fModel("s3")!!)
        assertEquals(listOf("w", "h", "d"), w.map { it.key })
        assertEquals(listOf(2400, 2500, 600), w.map { it.usual })
        assertEquals(400, w[0].min); assertEquals(1200, w[1].min)
        val c = stepsOf(fModel("dresser")!!)
        assertEquals(300, c[0].min); assertEquals("fx.hHLegs", c[1].help)
        assertEquals("fx.min" to 600, stepIssue(stepsOf(fModel("I")!!)[0], 500))
        assertEquals("fx.max" to 4000, stepIssue(stepsOf(fModel("I")!!)[1], 4200))
        assertNull(stepIssue(stepsOf(fModel("I")!!)[0], 3400))
    }

    @Test fun aPieceFollowsItsTypedSizesAndGivesThemBack() {
        val k = pieceOf(fModel("L")!!, mapOf("s0" to 3400, "h" to 2650), ws, "Oshxona 1")
        assertEquals(listOf(3400, 2000), k.free!!.sides)
        assertEquals(2650, k.free!!.h)
        assertEquals(mapOf("s0" to 3400, "s1" to 2000, "h" to 2650), valsOf(k, ws))
        val d = pieceOf(fModel("dresser")!!, mapOf("w" to 1200, "h" to 900, "d" to 500), ws, "Komod 1")
        assertEquals("dresser", d.type)
        assertEquals(mapOf("w" to 1200, "h" to 900, "d" to 500), valsOf(d, ws))
        val s = pieceOf(fModel("s2")!!, emptyMap(), ws, "Shkaf 1")
        assertEquals(1800, wardOfF(s)!!.w); assertEquals(2, wardOfF(s)!!.slide!!.n)
        assertEquals("s3", modelOf(pieceOf(fModel("s3")!!, emptyMap(), ws, "x")).id)
    }

    @Test fun newSizesKeepTheSections() {
        val f = pieceOf(fModel("h3")!!, emptyMap(), ws, "Shkaf 1")
        val g = resized(f, mapOf("w" to 1800, "h" to 2300, "d" to 550), ws)
        val m = wardOfF(g)!!
        assertEquals(1800, m.w); assertEquals(2300, m.h); assertEquals(550, m.d)
        assertEquals(wardOfF(f)!!.sections.size, m.sections.size)
        val d = resized(pieceOf(fModel("dresser")!!, emptyMap(), ws, "Komod 1"), mapOf("h" to 900), ws)
        assertEquals(900, valsOf(d, ws)["h"])
        val k = resized(pieceOf(fModel("I")!!, mapOf("s0" to 3000), ws, "Oshxona 1"), mapOf("s0" to 2400), ws)
        assertEquals(listOf(2400), k.free!!.sides)
        assertTrue(k.modules.filter { !isUpper(it) }.sumOf { it.w } <= 2400)
    }

    @Test fun aMeasuredRoomGivesTheKitchenItsWalls() {
        val len = { id: String -> if (id == "A" || id == "C") 3400 else 2600 }
        val k = roomKitchen(fModel("L")!!, listOf("A", "B", "C", "D"), "A", len, 2700, ws, "Oshxona 1")
        assertEquals(listOf(3400, 2600), k.free!!.sides); assertEquals(2700, k.free!!.h)
        val (first, issues) = bestFirst(k, listOf("A", "B", "C", "D"), len, 2700, ws)
        assertEquals("A", first); assertTrue(issues.isEmpty())
        // a 4,3 m kupe fits no wall of a 4,2 × 3,6 room
        val big = pieceOf(fModel("s3")!!, mapOf("w" to 4300), ws, "Shkaf 1")
        assertEquals("fz.wide", bestFirst(big, listOf("A", "B", "C", "D"), { if (it == "A" || it == "C") 4200 else 3600 }, 2700, ws).second.first().key)
        val c = roomCabinet(fModel("s3")!!, 2000, 2600, ws, "Shkaf 1")
        assertEquals(2000 - 2 * W_GAP_SIDE, wardOfF(c)!!.w); assertEquals(2500, wardOfF(c)!!.h)
    }
}
