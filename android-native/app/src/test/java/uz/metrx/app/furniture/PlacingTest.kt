package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room

/** Dragging furniture on the room's plan (Placing.kt): the walls, poses, what a piece covers and what it gets in the way of. */
class PlacingTest {
    private val ws = Workshop()
    // 4,0 × 3,0 m: a door on wall C near its end, a window in the middle of wall A
    private val room = Room("r1", "w1", "Xona", dims = mapOf("A" to Dim(4000), "B" to Dim(3000), "H" to Dim(2700)),
        openings = listOf(Opening("d1", "door", "C", 900, 2100, 2800), Opening("o1", "window", "A", 1200, 1500, 1400, sill = 900)))
    private val walls = planWalls(room, true)

    @Test fun everyWallKnowsTheInsideOfTheRoom() {
        val a = walls.first { it.id == "A" }; val c = walls.first { it.id == "C" }
        assertEquals(1.0, a.n.y, 1e-9); assertEquals(-1.0, c.n.y, 1e-9)
        assertTrue(inside(walls.map { it.p0 }, a.at(2000.0, 500.0)))
    }

    @Test fun aPoseComesBackFromItsFrame() {
        val p = Pose("B", 1200, 800, 30)
        assertEquals(p, poseOf(walls, "B", frameOf(walls, p)!!))
        // turning keeps the middle where it was
        val fr = frameOf(walls, p)!!
        val t = turned(fr, 1200.0, 600.0, 90)
        val mid = { f: Frame -> f.o + f.u * 600.0 + f.n * 300.0 }
        assertEquals(mid(fr).x, mid(t).x, 1e-6); assertEquals(mid(fr).y, mid(t).y, 1e-6)
    }

    @Test fun aWardrobeOnAWallCoversItsWidthAndDepth() {
        val f = placed(newFreeWardrobe("Shkaf 1", "h3", 1500, 2200, 600, false, "door", ws), listOf("D"), "r1", "w1", off = 1200)
        val ft = footsOf(f, walls, ws).single()
        assertEquals("D", ft.wall); assertEquals(1200.0, ft.a0, 1e-9); assertEquals(2700.0, ft.a1, 1e-9)
        assertTrue(placeWarnings(f, emptyList(), room, walls, ws).isEmpty())
    }

    @Test fun inFrontOfAWindowOrInADoorsSwingItSaysSo() {
        // a 2,2 m wardrobe in the middle of wall A stands in front of the window
        val ward = placed(newFreeWardrobe("Shkaf 1", "h3", 1500, 2200, 600, false, "door", ws), listOf("A"), "r1", "w1", off = 1300)
        assertEquals(listOf("fz.hitWin"), placeWarnings(ward, emptyList(), room, walls, ws).map { it.key })
        // at the end of wall C it is where the door opens
        val byDoor = placed(newFreeWardrobe("Shkaf 1", "h3", 1000, 2200, 600, false, "door", ws), listOf("C"), "r1", "w1", off = 2900)
        assertEquals(listOf("fz.hitDoor"), placeWarnings(byDoor, emptyList(), room, walls, ws).map { it.key })
    }

    @Test fun twoPiecesOnTopOfEachOtherAndOneOutside() {
        val a = placed(newFreeWardrobe("Shkaf 1", "h3", 1200, 2200, 600, false, "door", ws), listOf("B"), "r1", "w1", off = 200)
        val b = placed(newFreeWardrobe("Shkaf 2", "h3", 1200, 2200, 600, false, "door", ws), listOf("B"), "r1", "w1", off = 900)
        assertTrue("fz.hitPiece" in placeWarnings(b, listOf(a), room, walls, ws).map { it.key })
        // side by side they only touch, but a door hinged where they meet would hit the other's fronts…
        val c = placed(newFreeWardrobe("Shkaf 2", "h3", 1200, 2200, 600, false, "door", ws), listOf("B"), "r1", "w1", off = 1400)
        assertEquals(listOf("fz.doorsHit"), placeWarnings(c, listOf(a), room, walls, ws).map { it.key })
        // …so 50 mm between them lets it open
        val c2 = placed(newFreeWardrobe("Shkaf 2", "h3", 1200, 2200, 600, false, "door", ws), listOf("B"), "r1", "w1", off = 1450)
        assertTrue(placeWarnings(c2, listOf(a), room, walls, ws).isEmpty())
        // a desk dragged half through wall C
        val desk = newFreeCabinet("Stol 1", "desk", 1200, 750, 600, ws).copy(roomId = "r1", pose = Pose("A", 2500, 2700, 0))
        assertTrue("fz.outside" in placeWarnings(desk, emptyList(), room, walls, ws).map { it.key })
    }

    @Test fun aOneWallKitchenSlidesAlongItsWall() {
        val k = newFreeKitchen("Oshxona 1", "I", "I", listOf(2400), 0, 2700, ws)
        val len = { id: String -> if (id == "A" || id == "C") 4000 else 3000 }
        val p = placed(k, listOf("C"), "r1", "w1", len = len, ws = ws, start = 800)
        assertEquals(800, leadOf(p))
        assertEquals(800.0, footsOf(p, walls, ws).first { it.floor }.a0, 1e-9)
        // placed again, the old stretch goes first: one stretch, the new one
        assertEquals(300, leadOf(placed(p, listOf("C"), "r1", "w1", len = len, ws = ws, start = 300)))
        assertEquals(listOf("fz.long"), fitIssues(k, listOf("C"), len, 2700, ws, start = 1700).map { it.key })
    }

    @Test fun theIslandStandsWhereItWasDragged() {
        val k = placed(newFreeKitchen("Oshxona 1", "O", "O", listOf(3000), 1800, 2700, ws), listOf("A", ISLAND), "r1", "w1", ws = ws)
        val usual = footsOf(k, walls, ws).single { it.island }
        // in front of wall A, its back 2,02 m out, the worktop over its cabinets and finished back
        assertTrue(usual.pts.all { it.y in 1400.0..2350.0 })
        val moved = k.copy(pose = Pose("A", 3000, 1500, 180))
        assertTrue(footsOf(moved, walls, ws).single { it.island }.pts.all { it.y in 900.0..1830.0 })
        // a peninsula joins the end of its side at a right angle
        val p = placed(newFreeKitchen("Oshxona 1", "P", "P", listOf(3000), 1600, 2700, ws), listOf("A", ISLAND), "r1", "w1", ws = ws)
        assertEquals(90, islandPoseIn(p, walls)!!.deg)
        assertTrue(footsOf(p, walls, ws).single { it.island }.pts.all { it.y >= 599.0 })
    }

    @Test fun emptyStretchesTakeNoRoomAndAPeninsulaStaysInside() {
        val k = newFreeKitchen("Oshxona 1", "I", "I", listOf(2400), 0, 2700, ws)
        val len = { id: String -> if (id == "A" || id == "C") 4000 else 3000 }
        val p = placed(k, listOf("C"), "r1", "w1", len = len, ws = ws, start = 800)
        // the wall units start where the units below them do, not at the empty stretch
        assertTrue(footsOf(p, walls, ws).filter { it.wall == "C" }.all { it.a0 >= 800.0 })
        // a peninsula on a side that fills its wall keeps its seating overhang inside the room
        val pk = placed(newFreeKitchen("Oshxona 1", "P", "P", listOf(4000), 1600, 2700, ws), listOf("A", ISLAND), "r1", "w1", ws = ws)
        assertTrue(placeWarnings(pk, emptyList(), room, walls, ws).none { it.key == "fz.outside" })
    }
}
