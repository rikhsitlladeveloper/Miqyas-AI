package uz.metrx.app.win

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace

/** The windows' fixes of 23 Oct 2026: mullions between narrow sashes, splitting and merging, the size card's Apply, a product of the wrong kind. */
class WinFixesTest {
    private fun two(w: Int = 1300, h: Int = 1400) = newItem("i", wkind("w2"), w, h)

    @Test fun aMullionBetweenTwoNarrowColumnsDoesNotThrow() {
        val narrow = newItem("i", wkind("w3"), 400, 1400)
        assertTrue(narrow.cols.zipWithNext().any { (a, b) -> a.w + b.w < 2 * 150 })
        assertEquals(narrow, moveMullion(narrow, 0, 200))
        assertEquals(narrow, setColW(narrow, 0, 100))
        val low = narrow.copy(cols = listOf(WCol(400, listOf(WCell(100), WCell(100)))))
        assertEquals(low, moveTransom(low, 0, 0, 50))
    }

    @Test fun splittingStopsAtTheLeastSashAndMergingGoesDownToOne() {
        var w = two()
        repeat(10) { w = splitCol(w, 0) }
        assertTrue(w.cols.all { it.w >= SPLIT_MIN })
        assertTrue(sashesOf(w).all { it.r.w > 0 })
        repeat(20) { w = splitRow(w, 0, 0) }
        assertTrue(w.cols[0].rows.all { it.h >= SPLIT_MIN })
        repeat(30) { w = mergeAt(w, 0, 0) }
        assertEquals(1, sashesOf(w).size)
        assertEquals(1300, w.cols.single().w)
    }

    @Test fun applyingANewGapRefitsWithoutMarkingItByHand() {
        val o = Opening("w1", "window", "C", 1300, 1400, 600, 850)
        val x = refit(two(), o.w, o.h, o.type)
        val texts = x.cols.map { "${it.w}" }
        val rows = x.cols[0].rows.map { "${it.h}" }
        // the typed W and H are as shown (from the old gap): the new gap's size stays, and it still follows its opening
        val y = sizeApplied(x, o, x.w, x.h, 15, texts to texts, 0, rows to rows)
        assertEquals(sizeFor(o.w, o.h, o.type, 15), y.w to y.h)
        assertTrue(y.fit)
    }

    @Test fun applyingANewSizeSharesTheColumnsAgainUnlessOneWasTyped() {
        val x = two()
        val texts = x.cols.map { "${it.w}" }
        val y = sizeApplied(x, null, 1500, 1400, null, texts to texts, 0, listOf("1400") to listOf("1400"))
        assertEquals(listOf(750, 750), y.cols.map { it.w })
        val z = sizeApplied(x, null, 1500, 1400, null, texts to listOf("500", "650"), 0, listOf("1400") to listOf("1400"))
        assertEquals(listOf(500, 1000), z.cols.map { it.w })
    }

    @Test fun aProductOfTheWrongKindForItsOpeningIsSaid() {
        val room = Room("r", "w", "Xona", dims = mapOf("A" to Dim(4000), "B" to Dim(3500), "H" to Dim(2700), "T" to Dim(380)),
            openings = listOf(Opening("w1", "window", "C", 1300, 1400, 600, 850)))
        val p0 = Project("p", "T", floors = listOf(Workspace("w", "Xona", "room")), rooms = listOf(room), industry = "win")
        val c = ctxOf(p0, "r", true)!!
        val it0 = fillOpening("a", wkind("w2"), c, c.opening("w1")!!, 20)
        val ok = p0.copy(win = WinOrder(listOf(it0)))
        assertFalse(warningsOf(ok, listOf(ctxOf(ok, "r", true)!!), true).any { it.key == "dw.w.type" })
        // the opening made a door afterwards
        val door = ok.copy(rooms = listOf(room.copy(openings = listOf(Opening("w1", "door", "C", 1300, 1400, 600, 0)))))
        assertTrue(warningsOf(door, listOf(ctxOf(door, "r", true)!!), true).any { it.key == "dw.w.type" })
        assertFalse(fillsType("w2", "door")); assertTrue(fillsType("balc", "door"))
    }
}
