package uz.metrx.app.tiles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.trades.TradeSet

/** The tiler's fixes of 23 Oct 2026: the adhesive setting, merged counts with their own spares and boxes, labour priced as shown. */
class TileFixesTest {
    private val room = Room("r", "w", "Hammom", dims = mapOf("A" to Dim(5000), "B" to Dim(4000), "H" to Dim(3000), "T" to Dim(200, "default")))

    @Test fun anAdhesiveOfZeroIsKept() {
        assertEquals(0.0, glueBaseOf("0"), 0.0)
        assertEquals(4.5, glueBaseOf("4,5"), 0.0)
        assertEquals(5.0, glueBaseOf(""), 0.0)
        val panel = TileLayout("t", a = 300, b = 300, panel = TPanel("floor", 2000, 1000))
        assertEquals(0.0, countLayout(Project("p", "T"), panel, true, glueBaseOf("0")).glueKg, 0.0)
    }

    @Test fun mergedLayoutsKeepTheirOwnBoxesAndSaySpareOnlyWhenTheSame() {
        val a = TileNeed("white", 300, 600, 90, 10, 0, 100, 0, 5, 105, 8, 14, 18.0)
        val b = TileNeed("white", 300, 600, 90, 10, 0, 100, 0, 10, 110, 6, 19, 18.0)
        val m = (TileCount(listOf(a)) + TileCount(listOf(b))).needs.single()
        assertEquals(-1, m.spare)
        assertEquals(14 + 19, m.boxes)
        assertEquals(0, m.perBox)
        assertEquals(a.boxedM2 + b.boxedM2, m.boxedM2, 1e-9)
        val same = (TileCount(listOf(a)) + TileCount(listOf(a))).needs.single()
        assertEquals(5, same.spare); assertEquals(8, same.perBox); assertEquals(Math.ceil(210 / 8.0).toInt(), same.boxes)
    }

    @Test fun theLabourLineIsPricedByTheAreaItShows() {
        val l = TileLayout("f", a = 333, b = 333, joint = 3, roomId = "r", surfs = listOf(TSurf("floor"), TSurf("A")))
        val p = Project("p", "T", rooms = listOf(room), industry = "tiler", tiles = listOf(l))
        val t = TradeSet()
        val r = tileRows(p, t, true) { k, v -> k + v.entries.joinToString("") { "|" + it.key + "=" + it.value } }
        val lab = r.labor.first { it.name.startsWith("tl.e.lab|") }
        val a = lab.name.substringAfter("a=").toDouble()
        assertEquals(Math.round(a * t.lTile.toDouble()).toString(), lab.amount)
        assertTrue(a > 0)
    }
}
