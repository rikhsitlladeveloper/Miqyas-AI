package uz.metrx.app.trades

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.core.lineTotal
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint

/** The trades' calculators on the 5 × 4 × 3 m room with a door 900 × 2100 and a window 1200 × 1500 at 900. */
class TradesTest {
    private val room = Room("r", "w", "Xona", dims = mapOf("A" to Dim(5000), "B" to Dim(4000), "H" to Dim(3000), "T" to Dim(200, "default")),
        openings = listOf(Opening("d", "door", "A", 900, 2100, 500), Opening("o", "window", "C", 1200, 1500, 1900, 900)),
        points = listOf(SitePoint("s1", "socket", "A", 2000, 300), SitePoint("s2", "socket", "B", 1000, 300), SitePoint("w1", "switch", "A", 1600, 900),
            SitePoint("c", "cold", "B", 500, 600), SitePoint("h", "hot", "B", 700, 600), SitePoint("k", "sewer", "B", 600, 400)))
    private val name = { k: String, v: Map<String, Any> -> k + v.values.joinToString(",", prefix = "(", postfix = ")") }

    @Test fun tilerCountsBoxesFromFloorAndWalls() {
        val t = TradeSet(wallH = 1500)
        // floor 20 m², walls 18 m × 1,5 m = 27 m² less the door's lower 1,5 m (900 × 1500) and the window's 600 below 1,5 m
        val area = tileArea(room, t)
        assertEquals(20.0 + 27.0 - 0.9 * 1.5 - 1.2 * 0.6, area, 1e-9)
        val r = tradeRows("tiler", listOf(room), t, name)
        val boxes = Math.ceil(area * 1.1 / 1.44)
        assertEquals(boxes, r.facts["boxes"]!!, 1e-9)
        assertEquals(listOf("t-tile", "t-glue", "t-grout"), r.mats.map { it.id })
        assertTrue(lineTotal(r.mats[0].qty, r.mats[0].price, 0).signum() > 0)
        // priced by the area the line shows (to 0,1 m²), so quantity × rate is its amount
        assertEquals(Math.round(Math.round(area * 10) / 10.0 * 80000).toString(), r.labor.single().amount)
    }

    @Test fun electricianCountsPointsAndCable() {
        val r = tradeRows("elec", listOf(room), TradeSet(), name)
        assertEquals(4.0, r.facts["points"]!!, 1e-9)                         // 2 sockets, 1 switch, 1 light
        assertEquals(18.0 + 2.5 * 4, r.facts["cable"]!!, 1e-9)
        assertEquals("2", r.mats.single { it.id == "t-socket" }.qty)
        assertEquals("2", r.mats.single { it.id == "t-breaker" }.qty)
        assertEquals((4 * 60000).toString(), r.labor.single().amount)
    }

    @Test fun plumberAndWindows() {
        val p = tradeRows("plumb", listOf(room), TradeSet(), name)
        assertEquals(3.0, p.facts["points"]!!, 1e-9)
        assertEquals("24", p.mats.single { it.id == "t-pipe" }.qty)          // 3 m × 2 + 18 m round the walls
        val w = tradeRows("win", listOf(room), TradeSet(), name)
        assertEquals(listOf("t-door", "t-window", "t-sill", "t-reveal"), w.mats.map { it.id })
        assertEquals(Math.round(1.2 * 1.5 * 900000).toString(), w.mats[1].price)
        assertEquals("1.3", w.mats[2].qty)                                    // 1200 + 100 mm
    }
}
