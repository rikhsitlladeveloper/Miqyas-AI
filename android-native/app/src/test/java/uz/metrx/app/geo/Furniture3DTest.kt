package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.autoFill
import uz.metrx.app.furniture.cabinetTemplate
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.wardrobeTemplate
import kotlin.math.abs

/** Furniture in 3D (furniture plan section 9): placed on its wall, doors that swing, taps that find them. */
class Furniture3DTest {
    private val ws = Workshop()
    private val room = Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2600, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")))
    private val shell = buildShell(listOf(room), true)
    private fun near(a: Double, b: Double) = abs(a - b) < 1e-6

    @Test fun wallFramesFollowTheRoom() {
        val a = shell.bases.getValue("A"); val b = shell.bases.getValue("B"); val d = shell.bases.getValue("D")
        assertTrue(near(a.ox, .2) && near(a.oz, 0.0) && near(a.nz, 1.0) && near(a.len, 3.4))
        assertTrue(near(b.ox, 3.6) && near(b.uz, 1.0) && near(b.nx, -1.0))
        // wall D runs from corner 4 back to corner 1: its far end is where wall A starts
        val end = d.at(d.len, 0.0, 0.0)
        assertTrue(near(end.x, a.ox) && near(end.z, a.oz))
    }

    @Test fun doorsSwingAndTapsFindThem() {
        val f0 = Furniture("k", "kitchen", walls = listOf("A", "B"), layout = "L")
        val f = autoFill(f0, runsOf(f0) { mapOf("A" to 3400, "B" to 2600)[it] }, ws, emptyList(), emptyList())
        val shut = furniture3D(listOf(f), shell.bases, ws, { 0xCDBFAE }, emptySet())
        val key = shut.keys.first { it.endsWith(":f0") }
        val opened = furniture3D(listOf(f), shell.bases, ws, { 0xCDBFAE }, setOf(key))
        assertEquals(shut.parts.size, opened.parts.size)             // the camera keeps its place when a door opens
        val a = shut.picks.single { it.key == key }.box; val b = opened.picks.single { it.key == key }.box
        // closed, the door lies along the wall; open at 100°, it stands out into the room
        assertTrue(abs(a.a.z) < 1e-9 && a.a.x > 0)
        assertTrue(b.a.z > .9 * b.a.len() && b.a.x < 0)
        // a ray straight at the door's middle, from inside the room, hits it
        val mid = a.o + (a.a + a.b + a.c) * .5
        val eye = V3(mid.x, mid.y, 2.0)
        assertNotNull(a.hit(eye, V3(0.0, 0.0, -1.0)))
        assertNull(a.hit(eye, V3(0.0, 0.0, 1.0)))
    }

    @Test fun aWardrobeHasNoSidesAtTheWalls() {
        val m = wardrobeTemplate(ws, "B", 10, 2580, 2680, builtIn = true)
        val fr = furniture3D(listOf(Furniture("w", "wardrobe", walls = listOf("B"), modules = listOf(m))), shell.bases, ws, { 0xF5F5F2 }, emptySet())
        assertEquals(m.sections.sumOf { s -> if (s.w >= 600) 2 else 1 }, fr.keys.count { ":f" in it })
        // everything stands between the walls A and C (z 0 … 2.6) and inside wall B (x ≤ 3.6)
        val pts = fr.parts.flatMap { p -> p.faces.flatMap { it.pts } }
        assertTrue(pts.all { it.z >= -1e-6 && it.z <= 2.6 + 1e-6 && it.x <= 3.6 + 1e-6 })
    }

    @Test fun aCabinetOnLegsStandsOnThem() {
        val m = cabinetTemplate("desk", ws, "A", 10, 1200, 750, 600)
        val fr = furniture3D(listOf(Furniture("d", "wardrobe", walls = listOf("A"), modules = listOf(m), type = "desk")), shell.bases, ws, { 0xF5F5F2 }, emptySet())
        // a pair of legs under each side and the divider, as the hardware list counts them; the boards above them
        val legs = fr.parts.filter { it.rgb == 0xC5CBD4 }.flatMap { it.faces }
        assertEquals(6 * 6, legs.size)
        assertTrue(legs.flatMap { it.pts }.all { it.y in -1e-9..ws.legH / 1000.0 + 1e-9 })
        assertTrue(fr.parts.filter { it.rgb != 0xC5CBD4 }.flatMap { p -> p.faces.flatMap { it.pts } }.all { it.y >= ws.legH / 1000.0 - 1e-9 })
    }
}
