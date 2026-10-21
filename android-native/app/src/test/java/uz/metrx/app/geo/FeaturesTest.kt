package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Feature
import uz.metrx.app.data.Room

/** Columns and niches in a 5 × 4 × 3 m room. */
class FeaturesTest {
    private val room = Room("r", "w", "Xona", dims = mapOf("A" to Dim(5000), "B" to Dim(4000), "H" to Dim(3000), "T" to Dim(200, "default")))

    @Test fun aColumnTakesFloorAndAddsItsSides() {
        val r = room.copy(features = listOf(Feature("c", "column", "A", 1000, 400, 300)))
        val a = areas(r)!!
        assertEquals(20_000_000L - 400L * 300, a.floor)
        assertEquals(18_000L + 600, a.perim)
        assertEquals(18_000L * 3000 + 2L * 300 * 3000, a.gross)
    }

    @Test fun aWallNicheAddsItsFourInsideFaces() {
        val r = room.copy(features = listOf(Feature("n", "niche", "B", 500, 800, 150, sill = 900, h = 600)))
        val a = areas(r)!!
        assertEquals(20_000_000L, a.floor); assertEquals(18_000L, a.perim)
        assertEquals(18_000L * 3000 + 2L * 150 * 600 + 2L * 800 * 150, a.gross)
        assertNull(featureIssue(r, r.features[0]))
        assertEquals("ft.exceeds", featureIssue(r, r.features[0].copy(off = 3500)))
    }
}
