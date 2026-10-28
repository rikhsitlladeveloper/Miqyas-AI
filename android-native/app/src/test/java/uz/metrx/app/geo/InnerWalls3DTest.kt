package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.InnerWall
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Pose
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.isFree
import uz.metrx.app.furniture.newFreeCabinet
import uz.metrx.app.furniture.newFreeWardrobe
import uz.metrx.app.furniture.placed
import uz.metrx.app.furniture.refaced

/** Inner walls in the 3D, the tiles and the furniture's letters, and older orders' free pieces (mockup v3, 28 Oct 2026). */
class InnerWalls3DTest {
    private fun rect(inner: List<InnerWall> = emptyList(), ops: List<Opening> = emptyList()) =
        Room("r", "f", "Xona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2600, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")),
            openings = ops, inner = inner)

    private val piece = InnerWall("p1", "straight", 1700, 1300, 0, 2000)

    @Test fun theRealThreeDDrawsThePiecesCutByTheirDoors() {
        val plain = buildShell(listOf(rect(listOf(piece))), true)
        val iw = plain.parts.filter { it.wall == "iw" }
        assertEquals(1, iw.size)
        // one prism: two caps and four sides
        assertEquals(6, iw[0].faces.size)
        // its faces are walls the furniture stands against, with their letters
        assertNotNull(plain.bases["E"]); assertNotNull(plain.bases["F"])
        assertTrue(plain.labels.any { it.text == "E" })
        // a door through it: the wall in three pieces (before, over, after)
        val withDoor = buildShell(listOf(syncFaces(rect(listOf(piece), listOf(Opening("d", "door", "E", 800, 2100, 600))))), true)
        assertEquals(18, withDoor.parts.first { it.wall == "iw" }.faces.size)
        // an arch: two parts and the lintel
        val arch = buildShell(listOf(rect(listOf(piece.copy(k = "arch", len = 2400, op = uz.metrx.app.data.IwOp(900, 2100))))), true)
        assertEquals(18, arch.parts.first { it.wall == "iw" }.faces.size)
    }

    @Test fun aTilerTilesBothFacesUpToTheirHeight() {
        val r = rect(listOf(piece.copy(k = "half", len = 1600, h = 1100)))
        val g = uz.metrx.app.tiles.roomGeo(r, true, emptyList())!!
        assertEquals(2, g.inner.size)
        assertNotNull(g.wall("E")); assertEquals(1100.0, g.innerH["E"]!!, 1e-9)
        // the outline stays the outer walls
        assertEquals(4, g.floor.size)
    }

    @Test fun furnitureFollowsItsFaceWhenLettersMove() {
        val ws = Workshop()
        val two = rect(listOf(piece, piece.copy(id = "p2", y = 600)))
        // a wardrobe against the second piece's face (G)
        val ward = placed(newFreeWardrobe("Shkaf", "h3", 1000, 2200, 500, false, "door", ws), listOf("G"), "r", "f", off = 200)
        val one = rect(listOf(piece.copy(id = "p2", y = 600)))
        val moved = refaced(listOf(ward), two, one).single()
        assertEquals(listOf("E"), moved.walls)
        assertTrue(moved.modules.filter { it.wall != null }.all { it.wall == "E" })
        // its face gone: it stands free where it was
        val gone = refaced(listOf(ward), two, rect(listOf(piece))).single()
        assertTrue(isFree(gone)); assertEquals("A", gone.pose!!.ref)
        // nothing changes for a room without inner walls
        val outer = placed(newFreeWardrobe("Shkaf", "h3", 1000, 2200, 500, false, "door", ws), listOf("A"), "r", "f")
        assertEquals(listOf(outer), refaced(listOf(outer), rect(), rect()))
    }

    @Test fun olderOrdersFreePiecesStayFree() {
        val ws = Workshop()
        // a desk dragged off the walls before 28 Oct 2026 (Pose on a wall): the new free mode
        val desk = newFreeCabinet("Stol 1", "desk", 1200, 750, 600, ws).copy(roomId = "r", pose = Pose("A", 800, 900, 30))
        assertTrue(isFree(desk))
        val js = kotlinx.serialization.json.Json { ignoreUnknownKeys = true; encodeDefaults = true }
        val back = js.decodeFromString(uz.metrx.app.furniture.Furniture.serializer(), js.encodeToString(uz.metrx.app.furniture.Furniture.serializer(), desk))
        assertEquals(desk, back)
        // a kitchen's island keeps its own pose and is not a free piece
        val k = placed(uz.metrx.app.furniture.newFreeKitchen("Oshxona 1", "O", "O", listOf(3000), 1800, 2700, ws), listOf("A", uz.metrx.app.furniture.ISLAND), "r", "f", ws = ws)
        assertFalse(isFree(k.copy(pose = Pose("A", 3000, 1500, 180))))
    }
}
