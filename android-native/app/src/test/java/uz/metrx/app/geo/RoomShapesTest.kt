package uz.metrx.app.geo

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Pt
import java.io.File
import kotlin.math.abs

/**
 * The room shapes against design/room-shapes/shape-cases.json, which the approved mockup generated from its own
 * geometry (gen_cases.js); the iPhone tests read the same file. Plus the step errors the walls screen shows.
 */
class RoomShapesTest {
    private val cases: List<JsonObject> by lazy {
        val f = listOf("../../design/room-shapes/shape-cases.json", "../design/room-shapes/shape-cases.json", "design/room-shapes/shape-cases.json")
            .map(::File).first { it.exists() }
        Json.parseToJsonElement(f.readText()).jsonObject["cases"]!!.jsonArray.map { it.jsonObject }
    }

    /** The free sketch of gen_cases.js (the cases file keeps only its values). */
    private val sketch = FreeSketch(listOf(Pt(1.0, 0.0), Pt(0.0, 1.0), Pt(-1.0, 0.0), Pt(0.0, 1.0), Pt(-1.0, 0.0), Pt(0.0, -1.0)), listOf(4400, 2600, 2000, 1800, 2400, 4400))

    private fun pts(e: JsonElement) = e.jsonArray.map { p -> p.jsonArray.let { Pt(it[0].jsonPrimitive.double, it[1].jsonPrimitive.double) } }
    private fun near(a: Double, b: Double, tol: Double = 0.01) = abs(a - b) <= tol

    @Test fun everyMockupCase() {
        assertEquals(34, cases.size)
        var errors = 0
        for ((ci, c) in cases.withIndex()) {
            val shape = RoomShape.of(c["shape"]!!.jsonPrimitive.content)!!
            val spec = ShapeSpec(shape, c["mirror"]!!.jsonPrimitive.boolean, c["turns"]!!.jsonPrimitive.int, if (shape == RoomShape.FREE) sketch else null)
            val tag = "case $ci ${shape.id} mirror=${spec.mirror} turns=${spec.turns}"
            val asked = asks(spec).map { if (it.kind == AskKind.WALL) "wall:" + shapeWallLetter(it.wall!!) else if (it.kind == AskKind.BAY_WIDTH) "bay.width" else "bay.depth" }
            assertEquals(tag, c["asked"]!!.jsonArray.map { it.jsonPrimitive.content }, asked)
            val input = c["input"]!!.jsonArray.map { it.jsonPrimitive.int }
            val g = shapeGeometry(spec, input)
            assertEquals(tag, c["ok"]!!.jsonPrimitive.boolean, g.ok)
            if (!g.ok) errors++
            for ((name, mine) in listOf("corners" to g.corners, "cornersShown" to g.cornersShown)) {
                val want = pts(c[name]!!)
                assertEquals("$tag $name", want.size, mine.size)
                want.zip(mine).forEachIndexed { i, (w, m) -> assertTrue("$tag $name[$i] $w vs $m", near(w.x, m.x) && near(w.y, m.y)) }
            }
            val walls = c["walls"]!!.jsonArray.map { it.jsonObject }
            assertEquals(tag, walls.size, g.walls.size)
            walls.zip(g.walls).forEach { (w, m) ->
                assertEquals(tag, w["wall"]!!.jsonPrimitive.content, m.letter)
                assertTrue("$tag wall ${m.letter} ${w["len"]} vs ${m.len}", near(w["len"]!!.jsonPrimitive.double, m.len))
                assertEquals("$tag wall ${m.letter} auto", w["auto"]!!.jsonPrimitive.boolean, m.derived)
                assertEquals("$tag wall ${m.letter} angle", w["angle"]?.jsonPrimitive?.intOrNull, m.angle)
            }
            assertTrue("$tag area ${c["areaMm2"]} vs ${g.areaMm2}", near(c["areaMm2"]!!.jsonPrimitive.double, g.areaMm2))
        }
        assertEquals(5, errors)
    }

    @Test fun cardCountsAndDefaults() {
        assertEquals(listOf("rect", "L", "U", "cut", "T", "Z", "bay", "free"), RoomShape.entries.map { it.id })
        assertEquals(listOf(2, 4, 6, 4, 6, 6, 5, 0), RoomShape.entries.map { it.askCount })
        assertEquals(listOf(4, 6, 8, 5, 8, 8, 8, null), RoomShape.entries.map { it.wallCount })
        RoomShape.entries.filter { it != RoomShape.FREE }.forEach { s ->
            assertEquals(s.askCount, asks(ShapeSpec(s)).size)
            assertTrue(s.id, shapeGeometry(ShapeSpec(s), emptyList()).ok)
        }
    }

    @Test fun mirrorAndTurn() {
        val s = ShapeSpec(RoomShape.L)
        assertEquals(1, s.turned().turn); assertEquals(0, s.turned().turned().turned().turned().turn); assertTrue(s.mirrored().mirror)
        assertEquals(Pt(-0.0, 1.0), shownPoint(Pt(1.0, 0.0), s.turned()))
        assertEquals(Pt(-3.0, 2.0), shownPoint(Pt(3.0, 2.0), s.mirrored()))
        // a mirror then a turn: x flipped first
        assertEquals(Pt(-2.0, -3.0), shownPoint(Pt(3.0, 2.0), s.mirrored().turned()))
    }

    @Test fun rangeIsCheckedFirst() {
        val s = ShapeSpec(RoomShape.RECT)
        assertEquals(ShapeErrorCode.OUT_OF_RANGE, stepError(s, listOf(299), 0)!!.code)
        assertEquals(ShapeErrorCode.OUT_OF_RANGE, stepError(s, listOf(3400, 20_001), 1)!!.code)
        assertEquals(ShapeErrorCode.OUT_OF_RANGE, stepError(s, listOf(null), 0)!!.code)
        assertNull(stepError(s, listOf(3400, 2600), 1))
        assertNull(heightError(2700)); assertNotNull(heightError(1999)); assertNotNull(heightError(6001)); assertNotNull(heightError(null))
    }

    @Test fun cutErrorsShowWhereTheyAreKnown() {
        val s = ShapeSpec(RoomShape.CUT)
        // D (step 2) not shorter than A
        assertNull(stepError(s, listOf(3600, 2200), 1))
        stepError(s, listOf(3600, 2200, 3600), 2)!!.let { assertEquals(ShapeErrorCode.CUT_D_NOT_SHORTER, it.code); assertEquals(3600.0, it.limit) }
        // B not shorter than E (step 3)
        stepError(s, listOf(3600, 3000, 2800, 3000), 3)!!.let { assertEquals(ShapeErrorCode.CUT_B_NOT_SHORTER, it.code); assertEquals(3000.0, it.limit) }
        assertEquals(ShapeErrorCode.CUT_NO_CUT, shapeGeometry(s, listOf(3600, 3000, 2800, 3000)).error!!.code)
        // any angle works
        assertEquals(53, shapeGeometry(s, listOf(3600, 2200, 3000, 3000)).walls[2].angle)
    }

    @Test fun bayErrors() {
        val s = ShapeSpec(RoomShape.BAY)
        // doesn't fit from the width step on
        assertNull(stepError(s, listOf(4200, 3600, 2500), 2))
        stepError(s, listOf(4200, 3600, 2500, 2400), 3)!!.let { assertEquals(ShapeErrorCode.BAY_NOT_FIT, it.code); assertEquals(4900.0, it.value); assertEquals(4200.0, it.limit) }
        // too deep only on the depth step (the default depth would already be too deep for this width)
        assertNull(stepError(s, listOf(4200, 3600, 1000, 1400), 3))
        assertEquals(ShapeErrorCode.BAY_TOO_DEEP, stepError(s, listOf(4200, 3600, 1000, 1400, 800), 4)!!.code)
        assertNull(stepError(s, listOf(4200, 3600, 1000, 2400, 800), 4))
    }

    @Test fun closingWallNegativeOnTheLastStepOrWhenEditingOne() {
        val s = ShapeSpec(RoomShape.T)
        val v = listOf(4800, 1400, 3400, 2200, 1600, 2200)
        assertNull(stepError(s, v.take(3), 2))
        stepError(s, v, 5)!!.let { assertEquals(ShapeErrorCode.WALL_NEGATIVE, it.code); assertEquals(6, it.wall); assertEquals(-200.0, it.value!!, 1e-9) }
        assertEquals(ShapeErrorCode.WALL_NEGATIVE, stepError(s, v, 2, editingOne = true)!!.code)
    }

    @Test fun crossingWalls() {
        // a Z whose lower part comes back up through the upper one: every wall positive, but they cross
        val g = shapeGeometry(ShapeSpec(RoomShape.Z), listOf(2600, 1600, 1800, 2400, 1000, 3000))
        assertTrue(g.walls.none { it.bad })
        assertEquals(ShapeErrorCode.WALLS_CROSS, g.error!!.code)
    }

    @Test fun freeSketchGapAndDiagonal() {
        val s = ShapeSpec(RoomShape.FREE, sketch = sketch)
        val g = shapeGeometry(s, listOf(4400, 2600, 2000, 1800, 2400, 4420))
        assertTrue(g.ok); assertEquals(20.0, g.gapFixed, 1e-9)
        val bad = shapeGeometry(s, listOf(4400, 2600, 2000, 1800, 2400, 4700))
        assertEquals(ShapeErrorCode.NOT_CLOSED, bad.error!!.code); assertEquals(300.0, bad.error!!.value!!, 1e-9)
        assertEquals(ShapeErrorCode.NOT_CLOSED, stepError(s, listOf(4400, 2600, 2000, 1800, 2400, 4700), 5)!!.code)
        // the diagonal from corner 0 to corner 3: (0,0) to (2400, 2600)
        val v = sketch.hints
        assertEquals(3, diagonalCorner(s))
        assertEquals(3538.36, expectedDiagonal(shapeGeometry(s, v)), 0.01)
        assertNull(diagonalError(s, v, 3540))
        assertNull(diagonalError(s, v, 3558))                 // within the editor's 20 mm
        assertNull(diagonalError(s, v, 3518))
        assertEquals(ShapeErrorCode.DIAG_MISMATCH, diagonalError(s, v, 3559)!!.code)
        assertEquals(ShapeErrorCode.DIAG_MISMATCH, diagonalError(s, v, 3600)!!.code)   // within 2 %, but past 20 mm
        diagonalError(s, v, 3700)!!.let { assertEquals(ShapeErrorCode.DIAG_MISMATCH, it.code); assertEquals(3538.36, it.limit!!, 0.01) }
        assertEquals(ShapeErrorCode.OUT_OF_RANGE, diagonalError(s, v, 100)!!.code)
    }

    @Test fun freeSketchFromTheSketchScreen() {
        val fs = freeSketch(listOf(Pt(0.0, 0.0), Pt(4404.0, 0.0), Pt(4404.0, 3000.0), Pt(0.0, 3000.0)))
        assertEquals(listOf(4400, 3000, 4400, 3000), fs.hints)
        assertEquals(listOf(Pt(1.0, 0.0), Pt(0.0, 1.0), Pt(-1.0, 0.0), Pt(0.0, -1.0)), fs.dirs)
    }

    @Test fun openingFieldsAndHints() {
        val g = shapeGeometry(ShapeSpec(RoomShape.RECT), listOf(3400, 2600))
        assertEquals(listOf(OpField.DIST, OpField.WIDTH, OpField.HEIGHT, OpField.SILL), opAsks(OpKind.WINDOW).map { it.field })
        assertEquals(900, opAsks(OpKind.WINDOW).last().default)
        assertEquals(listOf(OpField.DIST), opAsks(OpKind.GAS).map { it.field })
        assertEquals(ShapeErrorCode.EMPTY, opFieldError(g, 2700, OpKind.DOOR, 0, OpField.DIST, null)!!.code)
        assertEquals(ShapeErrorCode.OP_PAST_WALL, opFieldError(g, 2700, OpKind.DOOR, 1, OpField.DIST, 2700)!!.code)
        assertNull(opFieldError(g, 2700, OpKind.DOOR, 1, OpField.DIST, 2600))
        opFieldError(g, 2700, OpKind.DOOR, 1, OpField.WIDTH, 900, dist = 2000)!!.let { assertEquals(ShapeErrorCode.OP_NOT_FIT, it.code); assertEquals(2900.0, it.value); assertEquals(2600.0, it.limit) }
        assertEquals(ShapeErrorCode.OUT_OF_RANGE, opFieldError(g, 2700, OpKind.DOOR, 0, OpField.HEIGHT, 2800)!!.code)
        assertEquals(ShapeErrorCode.OP_ABOVE_CEILING, opFieldError(g, 2700, OpKind.WINDOW, 0, OpField.SILL, 1300, h = 1500)!!.code)
        assertNull(openingError(g, 2700, ShapeOpening(OpKind.WINDOW, 0, 900, 1500, 1500, 900)))
        assertNotNull(openingError(g, 2700, ShapeOpening(OpKind.WINDOW, 0, 2000, 1500, 1500, 900)))
        // hints shrink to fit a short wall
        assertEquals(600, opHint(g, 2700, OpKind.DOOR, 0, OpField.DIST))
        val small = shapeGeometry(ShapeSpec(RoomShape.RECT), listOf(1200, 1000))
        assertEquals(200, opHint(small, 2700, OpKind.DOOR, 0, OpField.DIST))
        assertEquals(700, opHint(small, 2700, OpKind.WINDOW, 1, OpField.WIDTH, dist = 300))
        assertEquals(900, opHint(g, 2700, OpKind.WINDOW, 0, OpField.SILL, h = 1500))
    }
}
