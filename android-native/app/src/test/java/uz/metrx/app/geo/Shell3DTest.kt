package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import kotlin.math.abs

/** The 3D shell against the prototype's build3D: wall pieces, labels, limits, light and the rows of rooms. */
class Shell3DTest {
    private fun rect(id: String, a: Int, b: Int, h: Int, ops: List<Opening> = emptyList()) = Room(
        id, "f", id, dims = mapOf("A" to Dim(a, "manual"), "B" to Dim(b, "manual"), "H" to Dim(h, "manual"), "T" to Dim(200, "default")), openings = ops
    )
    // BUILD_PLAN fixture: 5 × 4 × 3 m, door 0.9 × 2.1 on A, window 1.2 × 1.5 on B
    private val fixture = rect("r", 5000, 4000, 3000, listOf(
        Opening("d", "door", "A", 900, 2100, 600, 0), Opening("w", "window", "B", 1200, 1500, 1400, 900)
    ))

    private fun wallBoxes(s: Shell3D, w: String) = s.parts.filter { it.role == Role.WALL && it.wall == w }.sumOf { it.faces.size } / 6

    @Test fun wallPiecesAroundOpenings() {
        val s = buildShell(listOf(fixture), true)
        assertEquals(3, wallBoxes(s, "A"))   // left of the door, over it, right of it (a door has no piece under it)
        assertEquals(4, wallBoxes(s, "B"))   // before, under and over the window, after
        assertEquals(1, wallBoxes(s, "C")); assertEquals(1, wallBoxes(s, "D"))
        assertEquals(3 * 12 * 2, s.edges.first { it.wall == "A" }.segs.size)
    }

    @Test fun sizesLabelsAndLimits() {
        val s = buildShell(listOf(fixture), true)
        assertEquals(5.4, s.L, 1e-9); assertEquals(4.0, s.W, 1e-9); assertEquals(3.0, s.H, 1e-9)
        assertEquals(listOf("A", "B", "C", "D"), s.labels.map { it.text })
        val a = s.labels[0].p; assertEquals(2.7, a.x, 1e-9); assertEquals(3.25, a.y, 1e-9); assertEquals(-.1, a.z, 1e-9)
        assertEquals(2.7, s.tgt.x, 1e-9); assertEquals(.9, s.tgt.y, 1e-9); assertEquals(2.0, s.tgt.z, 1e-9)
        assertEquals(.81, s.bounds.x0, 1e-9); assertEquals(4.59, s.bounds.x1, 1e-9)
        assertNull(s.theta)
        // the prototype's start distance on a 360 × 389 picture (its labels land where ours do)
        assertEquals(12.968, v3Fit(s.fit[0], s.fit[1], s.fit[2], 360.0 / 389) * s.fit[3], 1e-3)
        assertEquals(19, s.gridDiv); assertEquals(9.4, s.gridSize, 1e-9)
    }

    @Test fun lambertLikeThePrototype() {
        val s = buildShell(listOf(fixture), true)
        // wall A's inside face, read off the running prototype: rgb(245, 244, 240)
        val c = shade(0xECE8E1, V3(0.0, 0.0, 1.0), s.light)
        val got = intArrayOf((c shr 16) and 255, (c shr 8) and 255, c and 255)
        intArrayOf(245, 244, 240).forEachIndexed { i, v -> assertTrue("channel $i: ${got[i]}", abs(got[i] - v) <= 2) }
    }

    @Test fun drawnLShape() {
        val v = listOf(Pt(0.0, 0.0), Pt(5000.0, 0.0), Pt(5000.0, 2000.0), Pt(3000.0, 2000.0), Pt(3000.0, 4000.0), Pt(0.0, 4000.0))
        val dims = mapOf("A" to 5000, "B" to 2000, "C" to 2000, "D" to 2000, "E" to 3000, "F" to 4000, "H" to 2700).mapValues { Dim(it.value, "manual") } + ("T" to Dim(200, "default"))
        val r = Room("l", "f", "L", template = "L", shape = "poly", dims = dims, poly = Poly(v, template = "L"),
            openings = listOf(Opening("w", "window", "E", 1200, 1500, 900, 900)))
        assertTrue(ready3D(r))
        val s = buildShell(listOf(r), true)
        assertEquals(6, s.groups[0].normals.size)
        assertEquals(listOf("A", "B", "C", "D", "E", "F"), s.labels.map { it.text })
        val floor = s.parts.first { it.role == Role.FLOOR }.faces[0]
        val tris = floor.tris!!
        assertEquals(4 * 3, tris.size)
        var area = 0.0
        for (i in tris.indices step 3) {
            val a = floor.pts[tris[i]]; val b = floor.pts[tris[i + 1]]; val c = floor.pts[tris[i + 2]]
            area += abs((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) / 2
        }
        assertEquals(16.0, area, 1e-6)   // 5 × 4 less the 2 × 2 notch
        assertNotNull(s.parts.firstOrNull { it.role == Role.GLASS })
        assertEquals(4, wallBoxesPoly(s, "E"))
    }

    private fun wallBoxesPoly(s: Shell3D, w: String) = s.parts.filter { it.role == Role.WALL && it.wall == w }.sumOf { it.faces.size } / 6

    @Test fun roomsInRows() {
        val rs = listOf(rect("a", 5000, 4000, 3000), rect("b", 3500, 3000, 2800), rect("c", 4200, 3600, 2800), rect("d", 2400, 1800, 2600))
        val s = buildShell(rs, false)
        val list = s.rooms3!!
        assertEquals(4, list.size)
        assertTrue(s.rooms3.map { it.cz }.distinct().size > 1)   // more than one row
        // no two rooms overlap
        for (i in list.indices) for (j in i + 1 until list.size) {
            val p = list[i]; val q = list[j]
            val apart = abs(p.cx - q.cx) >= (p.w + q.w) / 2 - 1e-9 || abs(p.cz - q.cz) >= (p.d + q.d) / 2 - 1e-9
            assertTrue("${p.id} and ${q.id} overlap", apart)
        }
        assertEquals(.9, s.phi!!, 1e-9)
        assertEquals(list.minOf { it.cx }, s.bounds.x0, 1e-9)
    }

    @Test fun piecesOfAWall() {
        val p = pieces(0.0, 4.0, listOf(doubleArrayOf(1.4, 2.6, .9, 1.5, 0.0)), 3.0)
        assertEquals(4, p.size)
        assertEquals(listOf(0.0, 1.4, 0.0, 3.0), p[0].toList()); assertEquals(listOf(1.4, 2.6, 0.0, .9), p[1].toList())
        assertEquals(listOf(1.4, 2.6, 2.4, 3.0), p[2].toList().map { Math.round(it * 1e9) / 1e9 }); assertEquals(listOf(2.6, 4.0, 0.0, 3.0), p[3].toList())
    }
}
