package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room

/** The numeric fixture of BUILD_PLAN.md and the prototype's parsing and validation rules. */
class GeometryTest {
    private fun room(a: Int?, b: Int?, h: Int?, ops: List<Opening> = emptyList()) = Room(
        "r", "f", "Xona", dims = mapOf("A" to Dim(a, "manual"), "B" to Dim(b, "manual"), "H" to Dim(h, "manual"), "T" to Dim(200, "default")), openings = ops
    )
    private val door = Opening("d", "door", "A", 900, 2100, 500, 0)
    private val window = Opening("w", "window", "C", 1200, 1500, 1000, 900)

    @Test fun fixture5x4x3() {
        val a = areas(room(5000, 4000, 3000, listOf(door, window)))!!
        assertEquals(20_000_000L, a.floor)
        assertEquals(18_000L, a.perim)
        assertEquals(54_000_000L, a.gross)
        assertEquals(1_890_000L + 1_800_000L, a.open)
        assertEquals("50,31", fmtArea(a.net))
    }

    @Test fun lengthSixMetres() {
        val a = areas(room(6000, 4000, 3000, listOf(door, window)))!!
        assertEquals("24,00", fmtArea(a.floor)); assertEquals(20_000L, a.perim); assertEquals("56,31", fmtArea(a.net))
    }

    @Test fun noFloorUntilBothSides() { assertNull(areas(room(5000, null, 3000))); assertNull(areas(room(5000, 4000, null))!!.net) }

    @Test fun formats() {
        assertEquals("5,00", fmtLen(5000)); assertEquals("4,255", fmtLen(4255)); assertEquals("5,000", fmtLen(5000, full = true))
        assertEquals("500", fmtLen(5000, LenUnit.CM)); assertEquals("500,5", fmtLen(5005, LenUnit.CM)); assertEquals("4.255", fmtLen(4255, english = true))
    }

    @Test fun parsing() {
        assertEquals(Parsed.Ok(4255), lenErr("4,255", 100_000, LenUnit.M, false))
        assertEquals(Parsed.Ok(4255), lenErr("4.255", 100_000, LenUnit.M, false))
        assertEquals(Parsed.Ok(4255), lenErr("4 255", 1_000_000_000, LenUnit.M, false).let { if (it is Parsed.Ok) Parsed.Ok(it.value / 1000) else it })
        assertEquals(Parsed.Ok(500), lenErr(".5", 100_000, LenUnit.M, false))
        assertEquals("err.format", (lenErr("abc", 100_000, LenUnit.M, false) as Parsed.Err).key)
        assertEquals("err.format", (lenErr("4.2.1", 100_000, LenUnit.M, false) as Parsed.Err).key)
        assertEquals("err.zero", (lenErr("0", 100_000, LenUnit.M, false) as Parsed.Err).key)
        assertEquals("err.max", (lenErr("150", 100_000, LenUnit.M, false) as Parsed.Err).key)
        assertEquals("err.precision", (lenErr("4,2555", 100_000, LenUnit.M, false) as Parsed.Err).key)
        assertEquals("err.negative", (lenErr("-1", 100_000, LenUnit.M, false) as Parsed.Err).key)
        assertEquals(Parsed.Ok(4255), lenErr("425,5", 100_000, LenUnit.CM, false))
    }

    @Test fun openingChecks() {
        val r = room(5000, 4000, 3000, listOf(door))
        assertNull(openingIssue(r, door, "Eshik", LenUnit.M, false))
        assertEquals("op.exceeds", openingIssue(r, door.copy(off = 4500), "Eshik", LenUnit.M, false)!!.key)
        assertEquals("op.tooTall", openingIssue(r, window.copy(wall = "A", off = 2000, sill = 2000), "Deraza", LenUnit.M, false)!!.key)
        assertEquals("op.overlap", openingIssue(r, window.copy(id = "w2", wall = "A", off = 1000), "Deraza", LenUnit.M, false)!!.key)
        assertEquals("op.needWall", openingIssue(room(null, 4000, 3000), door, "Eshik", LenUnit.M, false)!!.key)
        // touching edges are fine
        assertNull(openingIssue(r, window.copy(id = "w3", wall = "A", off = 1400, sill = 900), "Deraza", LenUnit.M, false))
    }

    @Test fun lShapeSolvesFromFourWalls() {
        val dims = polyDims(6).toMutableMap()
        // A=3000, B=1500, C=3000, D=3500 known; E and F are computed
        dims["A"] = Dim(3000, "manual"); dims["B"] = Dim(1500, "manual"); dims["C"] = Dim(3000, "manual"); dims["D"] = Dim(3500, "manual")
        val r = Room("p", "f", "L", template = "poly", shape = "poly", dims = dims, poly = Poly(L_SHAPE, template = "lshape"))
        val g = polyGeo(r)
        assertTrue(g.solved)
        assertEquals(listOf("E", "F"), g.computed)
        assertEquals(6000, g.walls[4].len); assertEquals(5000, g.walls[5].len)
        assertEquals(6000L * 5000 - 3000L * 1500, areas(r)!!.floor)
    }

    @Test fun selfCrossingIsFound() {
        val bow = listOf(Pt(0.0, 0.0), Pt(10.0, 10.0), Pt(10.0, 0.0), Pt(0.0, 10.0))
        assertTrue(selfIntersects(bow) != null)
        assertNull(selfIntersects(L_SHAPE))
    }
}
