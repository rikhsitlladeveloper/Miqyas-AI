package uz.metrx.app.geo

import kotlinx.serialization.json.Json
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
import uz.metrx.app.data.SitePoint

/** Inner walls (mockup v3, approved 28 Oct 2026): the pieces, their faces as walls, the snap, the gaps, the doors' room. */
class InnerWallsTest {
    private fun rect(a: Int = 3400, b: Int = 2600, h: Int = 2700, inner: List<InnerWall> = emptyList(), ops: List<Opening> = emptyList(), pts: List<SitePoint> = emptyList()) =
        Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(a, "manual"), "B" to Dim(b, "manual"), "H" to Dim(h, "manual"), "T" to Dim(200, "default")),
            openings = ops, points = pts, inner = inner)

    private fun wall(id: String = "p1", k: String = "straight", x: Int = 1700, y: Int = 1300, len: Int = 2000, ang: Int = 0, len2: Int = 0, th: Int = 100) =
        InnerWall(id, k, x, y, ang, len, len2, th, if (k == "half") 1100 else 0, false, if (k == "arch") 900 else 0, if (k == "arch") 2100 else 0)

    private fun near(a: V2, x: Double, y: Double) = kotlin.math.abs(a.x - x) < 1e-6 && kotlin.math.abs(a.y - y) < 1e-6

    /* ---- pieces ---- */

    @Test fun piecesHaveTheMockupsBodiesAndFaces() {
        val g = pieceGeo(wall(), 2700)
        assertEquals(1, g.R.size); assertEquals(2, g.F.size)
        assertTrue(near(g.F[0].a, 700.0, 1350.0)); assertTrue(near(g.F[0].b, 2700.0, 1350.0)); assertTrue(near(g.F[0].look, 0.0, 1.0))
        assertTrue(near(g.F[1].a, 2700.0, 1250.0)); assertTrue(near(g.F[1].b, 700.0, 1250.0)); assertTrue(near(g.F[1].look, 0.0, -1.0))
        assertEquals(2700, g.H)
        assertEquals(4, pieceGeo(wall(k = "L", len2 = 1200), 2700).F.size)
        assertEquals(2, pieceGeo(wall(k = "L", len2 = 1200), 2700).R.size)
        assertEquals(5, pieceGeo(wall(k = "T", len2 = 1200, len = 2400), 2700).F.size)
        assertEquals(0, pieceGeo(wall(k = "col", len = 400, th = 400), 2700).F.size)
        assertEquals(20, pieceGeo(wall(k = "col", len = 400, th = 400).copy(round = true), 2700).R[0].size)
        val a = pieceGeo(wall(k = "arch", len = 2400), 2700)
        assertEquals(2, a.R.size); assertEquals(2, a.F.size)
        assertTrue(near(a.gap!!.first, 1250.0, 1300.0)); assertTrue(near(a.gap!!.second, 2150.0, 1300.0))
        assertEquals(1100, pieceGeo(wall(k = "half", len = 1600), 2700).H)
        // turned a quarter: along y
        val t = pieceGeo(wall(ang = 90), 2700)
        assertTrue(near(t.P0, 1700.0, 300.0)); assertTrue(near(t.P1, 1700.0, 2300.0))
    }

    @Test fun newPiecesTakeTheApprovedStandards() {
        val c = V2(1700.0, 1300.0)
        assertEquals(2000, newPiece("straight", c, 2700).len)
        newPiece("L", c, 2700).let { assertEquals(2000, it.len); assertEquals(1200, it.len2) }
        newPiece("T", c, 2700).let { assertEquals(2400, it.len); assertEquals(1200, it.len2) }
        newPiece("half", c, 2700).let { assertEquals(1600, it.len); assertEquals(1100, it.h) }
        newPiece("col", c, 2700).let { assertEquals(400, it.len); assertEquals(400, it.th); assertFalse(it.round) }
        newPiece("arch", c, 2700).let { assertEquals(2400, it.len); assertEquals(900, it.opW); assertEquals(2100, it.opH) }
        // a low room: the passage stays 100 under the ceiling
        assertEquals(2000, newPiece("arch", c, 2100).opH)
        assertEquals(100, newPiece("straight", c, 2700).th)
    }

    @Test fun aNewPieceIsShortEnoughNotToStretchAtOnce() {
        assertEquals(2000, iwPlace(rect(), "straight").len)
        // 2 000 wide: 2 000 − 2 × (300 + 60) = 1 280
        val p = iwPlace(rect(a = 2000, b = 2000), "straight")
        assertEquals(1280, p.len); assertEquals(1000, p.x); assertEquals(1000, p.y); assertEquals(0, p.ang)
        // the arm too: up 1 000 − 50 − 300 − 60 = 590
        assertEquals(590, iwPlace(rect(a = 2000, b = 2000), "L").len2)
    }

    /* ---- faces as walls ---- */

    @Test fun facesAreLetteredAfterTheOuterWalls() {
        val r = rect(inner = listOf(wall("p1"), wall("p2", y = 700)))
        val f = innerFaces(r)
        assertEquals(listOf("E", "F", "G", "J"), f.map { it.id })   // the polygon letters skip H (the height)
        assertEquals(listOf("p1:0", "p1:1", "p2:0", "p2:1"), f.map { it.key })
        assertEquals(2000, wallLen(r, "E")); assertNull(wallLen(r, "K"))
        assertEquals(8, allWalls(r).size); assertEquals(4, walls(r).size)
        assertTrue(isInnerWall(r, "F")); assertFalse(isInnerWall(r, "A"))
        assertEquals(1100, wallHOf(rect(inner = listOf(wall(k = "half", len = 1600))), "E"))
        assertEquals("A2", wallLetter(21))
    }

    @Test fun syncFacesKeepsItemsOnTheirFaceByKey() {
        val door = Opening("d", "door", "G", 800, 2100, 400)
        var r = syncFaces(rect(inner = listOf(wall("p1"), wall("p2", y = 700)), ops = listOf(door, Opening("w", "window", "E", 900, 1200, 100, 900))))
        assertEquals("p2:0", r.openings.first { it.id == "d" }.fk)
        assertEquals("p1:0", r.openings.first { it.id == "w" }.fk)
        // the first piece goes: the door's face is now E, the window (on the gone piece) goes too
        r = syncFaces(r.copy(inner = r.inner.drop(1)))
        assertEquals(listOf("d"), r.openings.map { it.id })
        assertEquals("E", r.openings[0].wall); assertEquals("p2:0", r.openings[0].fk)
        // an outer wall's item and an unknown wall's item stay as they are
        val keep = rect(ops = listOf(Opening("a", "door", "A", 800, 2100, 0), Opening("z", "door", "Q", 800, 2100, 0)))
        assertEquals(keep, syncFaces(keep))
    }

    @Test fun olderRoomsDecodeAndEncodeAsBefore() {
        val js = Json { ignoreUnknownKeys = true; encodeDefaults = true }
        val old = """{"id":"r","floorId":"f","name":"Xona","openings":[{"id":"o","type":"door","wall":"A","w":800,"h":2100,"off":100}],"points":[{"id":"p","t":"socket","wall":"B","off":300,"h":300}]}"""
        val r = js.decodeFromString(Room.serializer(), old)
        assertTrue(r.inner.isEmpty()); assertEquals("", r.openings[0].fk); assertEquals("", r.points[0].fk)
        val out = js.encodeToString(Room.serializer(), r)
        assertFalse(out.contains("\"inner\"")); assertFalse(out.contains("\"fk\""))
        // a piece with its standards only writes what it has
        val p = js.encodeToString(InnerWall.serializer(), InnerWall("w", "straight", 10, 20, len = 2000))
        assertFalse(p.contains("ang")); assertFalse(p.contains("round"))
        assertEquals(InnerWall("w", "straight", 10, 20, len = 2000), js.decodeFromString(InnerWall.serializer(), p))
        val withIn = rect(inner = listOf(wall()))
        assertEquals(withIn, js.decodeFromString(Room.serializer(), js.encodeToString(Room.serializer(), withIn)))
    }

    /* ---- snap and gaps ---- */

    @Test fun anEndWithin300mmStretchesOrShrinksToTheWall() {
        val r = rect()
        val s = iwSnap(r, wall(len = 3000))
        assertTrue(s.str); assertEquals(3400, s.p.len); assertEquals(1700, s.p.x)
        assertEquals(setOf("B", "D"), s.outer.toSet())
        // through the walls: shrinks back to them
        assertEquals(3400, iwSnap(r, wall(len = 3600)).p.len)
        // far from both: nothing
        val f = iwSnap(r, wall(len = 2000))
        assertFalse(f.str); assertEquals(2000, f.p.len); assertTrue(f.outer.isEmpty())
        // only one end near: stretches that end, the centre moves
        val one = iwSnap(r, wall(x = 2300, len = 2000))   // ends 1 300 and 3 300 → 3 400
        assertEquals(2100, one.p.len); assertEquals(2350, one.p.x)
        // to another piece
        val other = wall("p2", k = "straight", x = 2900, y = 1300, len = 1200, ang = 90)
        val toP = iwSnap(rect(inner = listOf(other)), wall(x = 1600, len = 2400))   // right end 2 800; the other's body starts at 2 850
        assertEquals(listOf("p2"), toP.pieces); assertTrue(toP.outer.isEmpty())
        assertEquals(2450, toP.p.len); assertEquals(1625, toP.p.x)
        // a column never stretches
        assertFalse(iwSnap(r, wall(k = "col", len = 400, th = 400, x = 200)).str)
    }

    @Test fun theArmOfAnLStretchesToo() {
        // the L's arm from (2 650, 1 350) up to y = 2 400 (1 200 long + 50): the wall C at 2 600 is 200 away
        val s = iwSnap(rect(), wall(k = "L", len = 2000, len2 = 1100, y = 1300))
        assertTrue(s.str); assertEquals(1250, s.p.len2)
    }

    @Test fun liveGapsGoAcrossAndPastTheEnds() {
        val g = iwSides(rect(), wall())
        assertEquals(1250, g["S1"]!!.gap); assertEquals(1250, g["S0"]!!.gap)
        assertEquals(700, g["E1"]!!.gap); assertEquals(700, g["E0"]!!.gap)
        // a gap typed moves the piece that way
        val m = iwMoveGap(rect(), wall(), "E1", 500)!!
        assertEquals(1900, m.x)
        assertNull(iwMoveGap(rect(), wall(), "E1", 700))
        // a column on its four sides
        assertEquals(4, iwSides(rect(), wall(k = "col", len = 400, th = 400)).size)
    }

    @Test fun lengthKeepsTheStartAndTurnsAreQuarter() {
        val p = iwWithLen(wall(), 1000)
        assertEquals(1200, p.x); assertEquals(1000, p.len)
        val t = iwRotated(rect(), wall(len = 2000))
        assertEquals(90, t.p.ang)
        // 2 000 across a 2 600 room: each end 300 from the walls → stretches to 2 600
        assertEquals(2600, t.p.len)
        assertNotNull(iwCopyOf(rect(), wall()))
        assertEquals(1900, iwCopyOf(rect(), wall())!!.y)
    }

    /* ---- doors' room ---- */

    @Test fun aPieceInADoorsSwingOrDoorwayIsFlagged() {
        // a door on wall C (the bottom), 400 from its start (x 3 000 → 2 200), opening in: 800 deep
        val door = Opening("d", "door", "C", 800, 2100, 400, style = "single", sw = "inL")
        val z = doorZones(rect(ops = listOf(door)))
        assertEquals(1, z.size); assertTrue(z[0].sw)
        val inSwing = rect(inner = listOf(wall(x = 2600, y = 2100, len = 1000)), ops = listOf(door))
        assertEquals(listOf("iw.i.swing"), iwIssues(inSwing).map { it.key })
        assertEquals("C", iwIssues(inSwing)[0].args["w"])
        // a sliding door needs 300 in front: a piece at 2 100 is clear, one at 2 450 blocks the doorway
        val slide = door.copy(style = "slide", sw = "")
        assertTrue(iwIssues(rect(inner = listOf(wall(x = 2600, y = 2100, len = 1000)), ops = listOf(slide))).isEmpty())
        assertEquals(listOf("iw.i.block"), iwIssues(rect(inner = listOf(wall(x = 2600, y = 2450, len = 1000)), ops = listOf(slide))).map { it.key })
        // a door in the piece itself does not count against it
        val own = syncFaces(rect(inner = listOf(wall()), ops = listOf(Opening("d2", "door", "E", 800, 2100, 600, style = "single", sw = "inL"))))
        assertTrue(iwIssues(own).isEmpty())
        // a door through an inner wall opening outwards needs its other side too
        val out = syncFaces(rect(inner = listOf(wall()), ops = listOf(Opening("d3", "door", "E", 800, 2100, 600, style = "single", sw = "outL"))))
        assertEquals(2, doorZones(out).size)
    }

    /* ---- areas ---- */

    @Test fun innerWallsCountInTheAreas() {
        val r0 = rect(); val r1 = rect(inner = listOf(wall()))
        val a0 = areas(r0)!!; val a1 = areas(r1)!!
        assertEquals(a0.floor - 2000L * 100, a1.floor)
        assertEquals(a0.perim + 4000, a1.perim)
        assertEquals(a0.gross!! + 2L * 2000 * 2700, a1.gross)
        // a door through it comes off both sides
        val r2 = syncFaces(r1.copy(openings = listOf(Opening("d", "door", "E", 800, 2100, 600))))
        assertEquals(a1.net!! - 2L * 800 * 2100, areas(r2)!!.net)
        // the partition itself, one side, for bricks
        assertEquals(2000L * 2700 - 800L * 2100, innerAreas(r2).part)
        // an arch's passage is no wall
        val ar = innerAreas(rect(inner = listOf(wall(k = "arch", len = 2400))))
        assertEquals(2L * 2400 * 2700 - 2L * 900 * 2100, ar.gross)
        // a half wall up to its own height
        assertEquals(2L * 1600 * 1100, innerAreas(rect(inner = listOf(wall(k = "half", len = 1600)))).gross)
    }

    @Test fun tilesGoOnBothFacesUpToTheirLine() {
        val t = uz.metrx.app.trades.TradeSet(floor = false, wallH = 1500)
        val a0 = uz.metrx.app.trades.tileArea(rect(), t)
        val half = uz.metrx.app.trades.tileArea(rect(inner = listOf(wall(k = "half", len = 1600))), t)
        assertEquals(a0 + 2 * 1.6 * 1.1, half, 1e-6)
        val full = uz.metrx.app.trades.tileArea(rect(inner = listOf(wall())), t)
        assertEquals(a0 + 2 * 2.0 * 1.5, full, 1e-6)
    }

    @Test fun mirroringMovesThePiecesWithTheRoom() {
        val r = syncFaces(rect(inner = listOf(wall(x = 1000, len = 1000), wall("p2", k = "L", x = 2000, y = 800, len = 1000, len2 = 600)),
            ops = listOf(Opening("d", "door", "E", 300, 2000, 100))))
        val m = mirrorRoom(r)
        assertEquals(2400, m.inner[0].x); assertEquals(1300, m.inner[0].y)
        assertEquals(1400, m.inner[1].x)
        assertTrue(m.inner[1].mir)
        // the door stays on its piece, measured from the other end
        val d = m.openings.first { it.id == "d" }
        assertEquals("p1", d.fk.substringBefore(':'))
        assertEquals(1000 - 100 - 300, d.off)
        // the L's arm went to the other end: its body still covers the mirrored place
        val g0 = pieceGeo(r.inner[1], 2700).R.flatten(); val g1 = pieceGeo(m.inner[1], 2700).R.flatten()
        assertEquals(3400 - g0.maxOf { it.x }, g1.minOf { it.x }, 1e-6)
        assertEquals(g0.maxOf { it.y }, g1.maxOf { it.y }, 1e-6)
    }

    @Test fun theRoomsMiddleAndTheIssuesOfFaces() {
        assertTrue(near(roomCen(rect()), 1700.0, 1300.0))
        // a socket above a half wall's top
        val r = syncFaces(rect(inner = listOf(wall(k = "half", len = 1600)), pts = listOf(SitePoint("s", "socket", "E", 400, 1200))))
        val lens = allWalls(r).associate { it.id to (it.len ?: 0) }
        val wh = innerFaces(r).associate { it.id to it.h }
        assertEquals(listOf("iw.i.ceilP"), roomIssues(lens, 2700, r.openings, r.points, wh).map { it.key })
    }
}
