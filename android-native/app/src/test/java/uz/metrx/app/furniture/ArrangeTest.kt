package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.InnerWall
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.geo.innerFaces
import uz.metrx.app.geo.syncFaces

/** "Mebel joylash" (mockup v3, approved 28 Oct 2026): pieces on a wall or free, the red and yellow checks, Devorga, flush. */
class ArrangeTest {
    private val ws = Workshop()
    // 4,0 × 3,0 m: a door on wall C near its end (x 1 200 → 300, opening in), a window in the middle of wall A
    private val room = Room("r1", "w1", "Xona", dims = mapOf("A" to Dim(4000), "B" to Dim(3000), "H" to Dim(2700)),
        openings = listOf(Opening("d1", "door", "C", 900, 2100, 2800), Opening("o1", "window", "A", 1200, 1500, 1400, sill = 900)))
    private val walls = planWalls(room, true)
    private val len = { id: String -> if (id == "A" || id == "C") 4000 else 3000 }

    private fun ward(name: String = "Shkaf 1", w: Int = 1500, wall: String = "D", off: Int = 200) =
        placed(newFreeWardrobe(name, "h3", w, 2200, 600, false, "door", ws), listOf(wall), "r1", "w1", off = off, len = len, ws = ws)

    private fun table(name: String, c: PlanPt, deg: Double = 0.0, w: Int = 1200, d: Int = 800): Furniture {
        val f = newFreeCabinet(name, "desk", w, 750, d, ws).let { placed(it, listOf("A"), "r1", "w1", len = len, ws = ws) }
        val b = bodyOf(f, walls, ws)!!; val fr = poseFrame(f, walls)!!
        return f.copy(pose = poseAt(walls, "A", b, fr, c, deg))
    }

    @Test fun anyCabinetMayStandFreeButNotACornerOrAKitchen() {
        assertTrue(canBeFree(ward()))
        assertTrue(canBeFree(newFreeCabinet("Stol", "desk", 1200, 750, 600, ws)))
        assertFalse(canBeFree(newFreeKitchen("Oshxona 1", "I", "I", listOf(2400), 0, 2700, ws)))
    }

    @Test fun aWallPiecesBoxAndItsFreePose() {
        val f = ward()
        val b = bodyOf(f, walls, ws)!!
        assertEquals(1500.0, b.w, 1.0); assertEquals(600.0, b.d, 1.0)
        assertFalse(isFree(f))
        // free in the middle, turned 30°: its box is there
        val g = f.copy(pose = poseAt(walls, "A", b, poseFrame(f, walls)!!, PlanPt(2000.0, 1500.0), 30.0))
        assertTrue(isFree(g))
        val b2 = bodyOf(g, walls, ws)!!
        assertEquals(2000.0, b2.c.x, 1.0); assertEquals(1500.0, b2.c.y, 1.0); assertEquals(30, b2.ang)
        assertEquals(1500.0, b2.w, 1.0)
        // its back where the wall was when it goes free where it stands
        val same = f.copy(pose = poseAt(walls, "A", b, poseFrame(f, walls)!!, b.c, b.ang.toDouble()))
        assertEquals(b.c.x, bodyOf(same, walls, ws)!!.c.x, 1.0); assertEquals(b.c.y, bodyOf(same, walls, ws)!!.c.y, 1.0)
    }

    @Test fun redWhenOnAnotherPieceInADoorsRoomOrThroughAWall() {
        val a = table("Stol 1", PlanPt(2000.0, 1500.0)); val b = table("Stol 2", PlanPt(2500.0, 1500.0))
        val c = fIssues(room, listOf(a, b), walls, ws)
        assertEquals("fp.r.piece", c.red[a.id]?.key); assertEquals("Stol 2", c.red[a.id]?.vars?.get("n"))
        // in the door's swing (wall C, x 300 – 1 200, 900 deep)
        val byDoor = table("Stol 3", PlanPt(750.0, 2500.0), w = 800, d = 600)
        assertEquals("fp.r.door", fIssues(room, listOf(byDoor), walls, ws).red[byDoor.id]?.key)
        // half through wall A
        val out = table("Stol 4", PlanPt(2000.0, 100.0))
        assertEquals("fp.r.out", fIssues(room, listOf(out), walls, ws).red[out.id]?.key)
        // on an inner wall
        val r2 = syncFaces(room.copy(inner = listOf(InnerWall("p1", "straight", 2000, 1500, 0, 1600))))
        val w2 = planWalls(r2, true)
        val t2 = table("Stol 5", PlanPt(2000.0, 1500.0)).let { it.copy(pose = poseAt(w2, "A", bodyOf(it, w2, ws)!!, poseFrame(it, w2)!!, PlanPt(2000.0, 1500.0), 0.0)) }
        assertEquals("fp.r.iw", fIssues(r2, listOf(t2), w2, ws).red[t2.id]?.key)
        // alone in the middle: fine
        assertTrue(fIssues(room, listOf(a), walls, ws).red.isEmpty())
    }

    @Test fun yellowWhenAPassageIsUnder700() {
        // a wardrobe on wall A (front at 600) and a table whose back is 500 mm in front of it
        val w = ward(wall = "A", off = 1400, w = 1200)
        val t = table("Stol 1", PlanPt(2000.0, 1500.0))
        val c = fIssues(room, listOf(w, t), walls, ws)
        assertTrue(c.red.isEmpty())
        assertEquals(500, c.yel[t.id]!!.minOf { it.gap })
        assertEquals(500, c.yel[w.id]!!.minOf { it.gap })
        // 20 mm counts as touching: no passage to check
        val touch = table("Stol 2", PlanPt(2000.0, 1020.0))
        assertNull(fIssues(room, listOf(w, touch), walls, ws).yel[touch.id]?.firstOrNull { it.gap < 100 })
    }

    @Test fun devorgaTakesTheNearestFreeWallFromItsMiddle() {
        val s = placeWall(room, walls, 1000.0, 600.0, emptyList(), ws)!!
        assertEquals("A", s.wall); assertEquals(1500, s.t); assertFalse(s.bad)
        // the middle of A taken: the next free place along it, 50 mm steps
        val taken = ward(wall = "A", off = 1400, w = 1200)
        val s2 = placeWall(room, walls, 1000.0, 600.0, listOf(taken), ws)!!
        assertEquals("A", s2.wall); assertTrue(s2.t + 1000 <= 1400 || s2.t >= 2600)
        // an inner wall's face counts as a wall
        val r2 = syncFaces(room.copy(inner = listOf(InnerWall("p1", "straight", 2000, 1500, 0, 1600))))
        val w2 = planWalls(r2, true)
        assertEquals(6, w2.size); assertTrue(w2[4].inner)
        assertEquals(innerFaces(r2).first().id, w2[4].id)
        assertTrue(placeWall(r2, w2, 1000.0, 600.0, emptyList(), ws)!!.wall in listOf("E", "F"))
    }

    @Test fun aFreePieceSticksFlushWithin60mm() {
        val t = table("Stol 1", PlanPt(2000.0, 1500.0))
        val b0 = bodyOf(t, walls, ws)!!
        // 40 mm from wall A: flush; 100 mm: stays
        val near = Body(PlanPt(1400.0, 40.0), b0.u, b0.n, 1200.0, 800.0)
        val (c, mg) = fFlush(near, planSegs(room, walls, emptyMap(), null, true))
        assertTrue(mg); assertEquals(400.0, c.y, 1e-6)
        val far = Body(PlanPt(1400.0, 100.0), b0.u, b0.n, 1200.0, 800.0)
        assertFalse(fFlush(far, planSegs(room, walls, emptyMap(), null, true)).second)
        // its four gaps: right, left, front, back
        val g = fGaps(bodyOf(t, walls, ws)!!, planSegs(room, walls, emptyMap(), null, true))
        assertEquals(listOf(1400, 1400, 1100, 1100), g.map { it!!.gap })
    }

    @Test fun aWallPieceSlidesWithMagnetsAndChangesWalls() {
        // near the corner (within 150 mm here): the corner
        val (w0, t0, m0) = slideOn(walls, "A", PlanPt(120.0, 300.0), 0.0, 1000.0, 150.0)
        assertEquals("A", w0); assertEquals(0, t0); assertEquals("corner", m0)
        // the middle
        assertEquals("mid", slideOn(walls, "A", PlanPt(1480.0, 300.0), 0.0, 1000.0, 150.0).third)
        // otherwise 10 mm steps
        assertEquals(1000, slideOn(walls, "A", PlanPt(1003.0, 300.0), 0.0, 1000.0, 150.0).second)
        // the finger 300 from wall B and 3 m from A: onto B
        assertEquals("B", slideOn(walls, "A", PlanPt(3700.0, 1500.0), 0.0, 1000.0, 150.0).first)
        assertNotNull(nearestWall(PlanPt(2000.0, 500.0), 1000.0, walls))
        assertEquals("A", nearestWall(PlanPt(2000.0, 500.0), 1000.0, walls)!!.first.id)
    }
}
