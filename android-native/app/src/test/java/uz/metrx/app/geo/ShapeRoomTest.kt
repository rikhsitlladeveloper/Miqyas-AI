package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import kotlin.math.abs
import kotlin.math.hypot

/** A finished room shape as the app's real Room: walls, closure, confirmed measurements, and where openings land. */
class ShapeRoomTest {
    private fun make(spec: ShapeSpec, vals: List<Int>, ops: List<ShapeOpening> = emptyList(), diag: Int? = null) =
        shapeToRoom(spec, vals, 2700, "r1", "f1", "Oshxona", 5L, diag, ops)!!

    /** Room walls as the editor sees them: length by id. */
    private fun lens(r: Room) = walls(r).associate { it.id to it.len }

    /** Every measurement confirmed (or worked out), so the editor asks nothing again. */
    private fun assertMeasured(r: Room) {
        assertEquals(0, unconfCount(r))
        assertTrue(allConfirmed(r, 0))
        assertTrue(ready3D(r))
    }

    @Test fun wallIdsBeforeTheRoomMatchTheRoomsOwn() {
        for (sh in RoomShape.entries.filter { it != RoomShape.FREE }) for (mir in listOf(false, true)) for (t in 0..3) {
            val spec = ShapeSpec(sh, mir, t)
            val sr = make(spec, asks(spec).map { it.default })
            assertEquals("$sh $mir $t", sr.wallIds, shapeWallIds(spec, sr.wallIds.size))
        }
        val sk = freeSketch(listOf(Pt(0.0, 0.0), Pt(4400.0, 0.0), Pt(4400.0, 2600.0), Pt(2400.0, 2600.0), Pt(2400.0, 4400.0), Pt(0.0, 4400.0)))
        val spec = ShapeSpec(RoomShape.FREE, sketch = sk)
        assertEquals(make(spec, sk.hints).wallIds, shapeWallIds(spec, 6))
        assertEquals(listOf("A", "B", "C", "D", "E", "F", "G", "J"), shapeWallIds(ShapeSpec(RoomShape.BAY), 8))
    }

    @Test fun rectangleIsTheAppsPlainRectangle() {
        val sr = make(ShapeSpec(RoomShape.RECT), listOf(4200, 3100))
        val r = sr.room
        assertEquals("rect", r.shape); assertEquals("rect", r.template); assertNull(r.poly); assertFalse(r.isPoly)
        assertEquals(0, r.rot)
        assertEquals(setOf("A", "B", "H", "T"), r.dims.keys)
        assertEquals(4200, r.dim("A").v); assertEquals("manual", r.dim("A").src)
        assertEquals(3100, r.dim("B").v); assertEquals(2700, r.dim("H").v); assertEquals(200, r.dim("T").v)
        assertEquals(listOf("A", "B", "C", "D"), sr.wallIds)
        assertMeasured(r)
        assertEquals(4200L * 3100, areas(r)!!.floor)
        assertEquals("r1", r.id); assertEquals("f1", r.floorId); assertEquals("Oshxona", r.name); assertEquals(5L, r.created)
        // the same kind of room the app makes today, with the sizes filled in
        val today = Room("r1", "f1", "Oshxona", created = 5L)
        assertEquals(today.copy(dims = r.dims), r)
    }

    @Test fun rectangleTurnsWithRot() {
        for (t in 0..3) {
            val r = make(ShapeSpec(RoomShape.RECT, turns = t), listOf(3400, 2600)).room
            assertEquals(t, r.rot); assertEquals(3400, r.dim("A").v); assertEquals(2600, r.dim("B").v)
        }
        // mirrored: A stays A, B and D swap sides
        val m = make(ShapeSpec(RoomShape.RECT, mirror = true), listOf(3400, 2600))
        assertEquals(0, m.room.rot); assertEquals(listOf("A", "D", "C", "B"), m.wallIds)
        assertEquals(listOf(true, true, true, true), m.flipped)
    }

    @Test fun everyShapeBecomesAClosedMeasuredRoom() {
        for (s in RoomShape.entries.filter { it != RoomShape.FREE }) for (mir in listOf(false, true)) for (t in 0..3) {
            val spec = ShapeSpec(s, mir, t)
            val g = shapeGeometry(spec, emptyList())
            val sr = make(spec, g.values)
            val r = sr.room
            val tag = "${s.id} mirror=$mir turns=$t"
            assertMeasured(r)
            // area kept
            assertEquals(tag, g.areaMm2, areas(r)!!.floor.toDouble(), g.areaMm2 * 5e-4)
            val ws = walls(r)
            assertEquals(tag, g.walls.size, ws.size)
            // each shape wall became the room wall of the same length
            g.walls.forEach { w -> assertEquals("$tag ${w.letter}", w.len, lens(r)[sr.roomWall(w.index)]!!.toDouble(), 0.5) }
            if (s == RoomShape.RECT) continue
            val pg = polyGeo(r)
            assertTrue(tag, pg.solved); assertNull(tag, pg.err)
            // clockwise on screen and closed: walking the walls comes back to corner A
            assertTrue(tag, shoelace(r.poly!!.verts) > 0)
            var x = 0.0; var y = 0.0
            ws.forEach { x += it.p1.x - it.p0.x; y += it.p1.y - it.p0.y; assertEquals(tag, it.len!!.toDouble(), hypot(it.p1.x - it.p0.x, it.p1.y - it.p0.y), 1.0) }
            assertTrue(tag, hypot(x, y) < 1e-6)
            assertEquals(tag, polyWallIds(g.walls.size).toSet(), sr.wallIds.toSet())
            // wall A stays A
            assertEquals(tag, "A", sr.roomWall(0))
        }
    }

    @Test fun lShapeWallsAndWorkedOutOnes() {
        val sr = make(ShapeSpec(RoomShape.L), listOf(2000, 1500, 1800, 2200))
        val r = sr.room
        assertEquals("poly", r.shape); assertEquals("rsh.L", r.poly!!.template); assertEquals(true, r.poly!!.snap)
        assertEquals(listOf(Pt(0.0, 0.0), Pt(2000.0, 0.0), Pt(2000.0, 1500.0), Pt(3800.0, 1500.0), Pt(3800.0, 3700.0), Pt(0.0, 3700.0)), r.poly!!.verts)
        val ws = walls(r)
        assertEquals(listOf(2000, 1500, 1800, 2200, 3800, 3700), ws.map { it.len })
        // the last two are left to the editor's solver: shown "=x", not asked again
        assertEquals(listOf("conf", "conf", "conf", "conf", "calc", "calc"), ws.map { it.status })
        assertNull(r.dim("E").v); assertNull(r.dim("F").v); assertEquals(1500, r.dim("B").v)
        assertEquals(2700, r.dim("H").v)
    }

    @Test fun cutCornerKeepsItsAngle() {
        val r = make(ShapeSpec(RoomShape.CUT), listOf(3600, 2200, 3000, 3000)).room
        assertEquals(false, r.poly!!.snap)
        val ws = walls(r)
        assertEquals(1000, ws[2].len); assertEquals("calc", ws[2].status)
        assertEquals(10_560_000.0, areas(r)!!.floor.toDouble(), 1000.0)
    }

    @Test fun bayLeavesItsSidesToTheSolver() {
        val sr = make(ShapeSpec(RoomShape.BAY), listOf(4200, 3600, 1000, 2400, 800))
        val r = sr.room
        assertEquals(true, r.poly!!.snap)
        val ws = walls(r)
        assertEquals(listOf(1000, 1131, 800, 1131, 800, 3600, 4200, 3600), ws.map { it.len })
        // the 45° sides are not whole mm: worked out by the editor; every stored length is exact
        assertEquals(listOf("conf", "calc", "conf", "calc", "conf", "conf", "conf", "conf"), ws.map { it.status })
        assertNull(r.dim("B").v); assertNull(r.dim("D").v); assertEquals(800, r.dim("E").v)
        // the room's own letters skip H (the height): the bay's side wall H is the room's J
        assertEquals(listOf("A", "B", "C", "D", "E", "F", "G", "J"), sr.wallIds)
        // corners moved so the plan starts at 0, 0 (the bay sticks out above wall A)
        assertEquals(Pt(0.0, 800.0), r.poly!!.verts[0])
        assertEquals(16_400_000.0, areas(r)!!.floor.toDouble(), 2000.0)
    }

    @Test fun freeSketchWithSpreadGapAndDiagonal() {
        val sk = FreeSketch(listOf(Pt(1.0, 0.0), Pt(0.0, 1.0), Pt(-1.0, 0.0), Pt(0.0, 1.0), Pt(-1.0, 0.0), Pt(0.0, -1.0)), listOf(4400, 2600, 2000, 1800, 2400, 4400))
        val exact = make(ShapeSpec(RoomShape.FREE, sketch = sk), sk.hints, diag = 3540).room
        assertEquals(listOf(4400, 2600, 2000, 1800, 2400, 4400), walls(exact).map { it.len })
        assertEquals(listOf("X1"), exact.poly!!.diags.map { it.id }); assertEquals(0, exact.poly!!.diags[0].a); assertEquals(3, exact.poly!!.diags[0].b)
        assertEquals(3540, exact.dim("X1").v)
        assertEquals("ok", polyGeo(exact).diagStatus["X1"])
        assertMeasured(exact)
        // a 20 mm gap spread over the walls: still closes for the editor
        val spread = make(ShapeSpec(RoomShape.FREE, sketch = sk), listOf(4400, 2600, 2000, 1800, 2400, 4420)).room
        assertEquals(false, spread.poly!!.snap)
        assertTrue(polyGeo(spread).solved)
        assertMeasured(spread)
        walls(spread).zip(listOf(4400, 2600, 2000, 1800, 2400, 4420)).forEach { (w, v) -> assertTrue("${w.id} ${w.len}", abs(w.len!! - v) <= 20) }
        // too big a gap: no room
        assertNull(shapeToRoom(ShapeSpec(RoomShape.FREE, sketch = sk), listOf(4400, 2600, 2000, 1800, 2400, 4700), 2700, "x", "f", "n"))
    }

    @Test fun tinyWorkedOutWallIsStoredMeasured() {
        // T with the leg's bottom 3 170: the closing wall G comes out 30 mm, which the editor's solver would reject
        val sr = make(ShapeSpec(RoomShape.T), listOf(4800, 1400, 1600, 2200, 3170, 2200))
        val r = sr.room
        assertEquals(30, r.dim("G").v); assertEquals("manual", r.dim("G").src)
        assertNull(r.dim("J").v)                       // the other worked-out wall is still the solver's
        assertTrue(polyGeo(r).solved)
        assertEquals(30, walls(r).single { it.id == "G" }.len); assertEquals(1400, walls(r).single { it.id == "J" }.len)
        assertMeasured(r)
    }

    @Test fun askedValuesKeepTheirSource() {
        val rect = shapeToRoom(ShapeSpec(RoomShape.RECT), listOf(3400, 2600), 2700, "r", "f", "n", diagonal = null, src = "sim")!!.room
        assertEquals("sim", rect.dim("A").src); assertEquals("sim", rect.dim("B").src); assertEquals("sim", rect.dim("H").src); assertEquals("default", rect.dim("T").src)
        val bay = shapeToRoom(ShapeSpec(RoomShape.BAY), listOf(4200, 3600, 1000, 2400, 800), 2700, "r", "f", "n", src = "laser")!!.room
        // asked: G, J (H), A; worked out and stored: C (the front), E, F
        assertEquals("laser", bay.dim("G").src); assertEquals("laser", bay.dim("J").src); assertEquals("laser", bay.dim("A").src)
        assertEquals("manual", bay.dim("C").src); assertEquals("manual", bay.dim("E").src); assertEquals("manual", bay.dim("F").src)
        assertEquals("manual", make(ShapeSpec(RoomShape.L), listOf(1800, 1800, 2400, 1800)).room.dim("A").src)
    }

    @Test fun freeShapeWithoutSketchMakesNothing() {
        val spec = ShapeSpec(RoomShape.FREE)
        assertTrue(asks(spec).isEmpty())
        assertEquals(ShapeErrorCode.EMPTY, shapeGeometry(spec, emptyList()).error!!.code)
        assertNull(shapeToRoom(spec, emptyList(), 2700, "x", "f", "n"))
        assertEquals(ShapeErrorCode.EMPTY, shapeGeometry(ShapeSpec(RoomShape.FREE, sketch = FreeSketch(listOf(Pt(1.0, 0.0), Pt(-1.0, 0.0)), listOf(3000, 3000))), emptyList()).error!!.code)
    }

    @Test fun diagonalCornersAscendAndMatchTheEditorWithin20mm() {
        val sk = FreeSketch(listOf(Pt(1.0, 0.0), Pt(0.0, 1.0), Pt(-1.0, 0.0), Pt(0.0, 1.0), Pt(-1.0, 0.0), Pt(0.0, -1.0)), listOf(4400, 2600, 2000, 1800, 2400, 4400))
        for (mir in listOf(false, true)) for (t in 0..3) {
            val spec = ShapeSpec(RoomShape.FREE, mir, t, sk)
            val r = make(spec, sk.hints, diag = 3558).room
            val dg = r.poly!!.diags.single()
            assertTrue("$mir $t ${dg.a} ${dg.b}", dg.a < dg.b)
            // 20 mm off the walls' 3 538: the flow takes it, and the editor shows it "ok", not "warn"
            assertNull(diagonalError(spec, sk.hints, 3558))
            assertEquals("ok", polyGeo(r).diagStatus["X1"])
            assertNotNull(diagonalError(spec, sk.hints, 3559))
        }
    }

    @Test fun brokenShapesMakeNoRoom() {
        assertNull(shapeToRoom(ShapeSpec(RoomShape.T), listOf(4800, 1400, 3400, 2200, 1600, 2200), 2700, "x", "f", "n"))
        assertNull(shapeToRoom(ShapeSpec(RoomShape.CUT), listOf(3600, 3000, 2800, 3000), 2700, "x", "f", "n"))
    }

    @Test fun openingsLandOnTheirWall() {
        val ops = listOf(
            ShapeOpening(OpKind.DOOR, 2, 400, 900, 2100),
            ShapeOpening(OpKind.WINDOW, 0, 1000, 1500, 1500, 900),
            ShapeOpening(OpKind.WATER, 1, 400),
            ShapeOpening(OpKind.SEWER, 1, 700),
            ShapeOpening(OpKind.GAS, 3, 1200)
        )
        val r = make(ShapeSpec(RoomShape.RECT), listOf(3400, 2600), ops).room
        val door = r.openings.single { it.type == "door" }
        assertEquals("C", door.wall); assertEquals(400, door.off); assertEquals(900, door.w); assertEquals(2100, door.h); assertEquals(0, door.sill)
        val win = r.openings.single { it.type == "window" }
        assertEquals("A", win.wall); assertEquals(1000, win.off); assertEquals(900, win.sill)
        r.openings.forEach { assertNull(it.type, openingIssue(r, it, it.type, LenUnit.MM, false)) }
        val cold = r.points.single { it.t == "cold" }
        assertEquals("B", cold.wall); assertEquals(400, cold.off); assertEquals(550, cold.h)
        val sewer = r.points.single { it.t == "sewer" }
        assertEquals(700, sewer.off); assertEquals(50, sewer.d)
        val gas = r.points.single { it.t == "gas" }
        assertEquals("D", gas.wall); assertEquals(1200, gas.off); assertEquals(1000, gas.h)
        assertEquals(setOf(r.openings.size + r.points.size), setOf((r.openings.map { it.id } + r.points.map { it.id }).toSet().size))
    }

    @Test fun mirroredOpeningsAreMeasuredFromTheRoomWallsOwnCorner() {
        // L mirrored: shape wall B (index 1, 1800 long) becomes the room's last wall, running the other way
        val spec = ShapeSpec(RoomShape.L, mirror = true)
        val g = shapeGeometry(spec, emptyList())
        val sr = make(spec, g.values, listOf(ShapeOpening(OpKind.DOOR, 1, 200, 900, 2100), ShapeOpening(OpKind.GAS, 1, 300)))
        val r = sr.room
        assertEquals("F", sr.roomWall(1))
        val door = r.openings.single()
        assertEquals("F", door.wall); assertEquals(1800 - 200 - 900, door.off)
        assertEquals(1800 - 300, r.points.single().off)
        // the door is where the shape put it: its far edge 200 mm from the shape wall's start corner
        val w = walls(r).single { it.id == "F" }
        val shown = shownPoint(g.walls[1].from, spec)
        val farEdge = Pt(w.p0.x + (w.p1.x - w.p0.x) * (door.off + door.w) / w.len!!, w.p0.y + (w.p1.y - w.p0.y) * (door.off + door.w) / w.len!!)
        // the room's corners were moved by the same offset as the shown ones
        val v = r.poly!!.verts; val shownAll = g.cornersShown
        val dx = v[0].x - shownAll[1].x; val dy = v[0].y - shownAll[1].y
        assertEquals(200.0, hypot(farEdge.x - (shown.x + dx), farEdge.y - (shown.y + dy)), 1e-6)
        assertNull(openingIssue(r, door, "door", LenUnit.MM, false))
    }

    @Test fun turnedPolygonsAreBakedIntoTheCorners() {
        val sr = make(ShapeSpec(RoomShape.L, turns = 1), listOf(1800, 1800, 2400, 1800))
        val r = sr.room
        assertEquals(0, r.rot)
        // wall A runs down the right-hand side after the turn
        val a = walls(r).first { it.id == "A" }
        assertEquals(0.0, a.p1.x - a.p0.x, 1e-9); assertEquals(1800.0, a.p1.y - a.p0.y, 1e-9)
        assertNotNull(r.poly)
    }
}
