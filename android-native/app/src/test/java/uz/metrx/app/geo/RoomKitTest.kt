package uz.metrx.app.geo

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Poly
import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint

/** The room editor v2's rules (design/room-editor/mockup.html, approved 28 Oct 2026). */
class RoomKitTest {
    private fun rect(a: Int = 3400, b: Int = 2600, h: Int = 2700, ops: List<Opening> = emptyList(), pts: List<SitePoint> = emptyList(), rot: Int = 0) =
        Room("r", "f", "Oshxona", rot = rot, dims = mapOf("A" to Dim(a, "manual"), "B" to Dim(b, "manual"), "H" to Dim(h, "manual"), "T" to Dim(200, "default")),
            openings = ops, points = pts)

    /* ---- wall lengths ---- */

    @Test fun wallLengthsGoTo999999AndWarnAbove30m() {
        assertEquals("re.e.wallMin", wallLenErr(299))
        assertNull(wallLenErr(300))
        assertNull(wallLenErr(999_999))
        assertEquals("re.e.wallMax", wallLenErr(1_000_000))
        assertEquals("re.e.need", wallLenErr(null))
        assertFalse(bigWall(30_000)); assertTrue(bigWall(30_001)); assertFalse(bigWall(null))
        assertEquals(999_999, SHAPE_WALL_MAX)
        assertEquals(999_999, dimMax("A")); assertEquals(999_999, dimMax("F"))
        // the room-shape flow takes a 6-digit wall
        assertNull(wallValueError(450_000))
        assertNotNull(wallValueError(1_000_000))
    }

    /* ---- styles and standards ---- */

    @Test fun styleCatalogueMatchesTheMockup() {
        assertEquals(listOf("single", "double", "slide", "arch", "glass", "balcony", "fold"), STYLES["door"]!!.map { it.id })
        assertEquals(listOf("single", "double", "triple", "fort", "pano", "balcony"), STYLES["window"]!!.map { it.id })
        assertEquals(5, STYLES["socket"]!!.size); assertEquals(4, STYLES["switch"]!!.size); assertEquals(4, STYLES["rad"]!!.size)
        POINT_KINDS.forEach { assertTrue(it, STYLES[it]!!.isNotEmpty()); assertTrue(it, POINT_HS[it]!!.isNotEmpty()) }
        assertEquals(mapOf("w" to 800, "h" to 2100), styleOf("door", "single").std)
        assertEquals(mapOf("w" to 1500, "h" to 1500, "sill" to 900), styleOf("window", "double").std)
        assertEquals(mapOf("w" to 700, "h" to 1400, "sill" to 900), styleOf("window", "single").std)
        assertEquals(1100, styleOf("socket", "three").std["ph"])
        assertEquals(640, styleOf("rad", "alu").std["pw"])
        assertEquals(1000, styleOf("ac", "b18").std["pw"])
        assertEquals(100, styleOf("sewer", "d110").std["ph"])
        // an unknown or empty style is the first one
        assertEquals("single", styleOf("door", "").id); assertEquals("one", styleOf("socket", "zzz").id)
        // a panoramic window goes up to the ceiling
        assertEquals(3000, stdVals("window", styleOf("window", "pano"), 3000)["h"])
    }

    @Test fun olderOpeningsReadAsTheUsualStyle() {
        assertEquals("single", styleId(Opening("d", "door", "A", 800, 2100, 0)))
        assertEquals("double", styleId(Opening("w", "window", "A", 1500, 1500, 0, 900)))
        assertEquals("one", styleId(SitePoint("p", "socket", "A", 100, 300)))
    }

    @Test fun iconRowOrderFollowsTheTrade() {
        assertEquals(listOf(OPEN_KINDS, WATER_KINDS, ELEC_KINDS), kindGroups("furniture"))
        assertEquals(listOf(OPEN_KINDS, ELEC_KINDS, WATER_KINDS), kindGroups("elec"))
        assertEquals("door", kindGroups("plumb").first().first())
    }

    /* ---- steps ---- */

    @Test fun sizeStepsPerKindAndStyle() {
        assertEquals(listOf("w", "h"), pkSteps("door", "single"))
        assertEquals(listOf("dw", "h", "ww", "wh"), pkSteps("door", "balcony"))
        assertEquals(listOf("w", "h", "sill"), pkSteps("window", "double"))
        assertEquals(listOf("w", "h"), pkSteps("window", "pano"))
        assertEquals(listOf("ww", "wh", "dw", "h"), pkSteps("window", "balcony"))
        assertEquals(listOf("pw", "ph"), pkSteps("rad", "alu"))
        assertEquals(listOf("pw", "ph"), pkSteps("ac", "b9"))
        assertEquals(listOf("ph"), pkSteps("socket", "two"))
    }

    @Test fun chipsCarryTheStyleStandard() {
        val c = stepChips("w", "door", "double", 2700)
        assertEquals(listOf(1000, 1200, 1400), c.chips); assertEquals(1200, c.std)
        val d = stepChips("w", "door", "glass", 2700)
        assertEquals(listOf(700, 800, 900), d.chips); assertEquals(800, d.std)
        assertEquals(listOf(2400, 2500, 2800), stepChips("h", "window", "pano", 2800).chips)
        assertEquals(listOf(800, 900), stepChips("sill", "window", "double", 2700).chips)
        // the socket's "three" standard (1 100) is among its heights already, the sewer's 100 is added in order
        assertEquals(listOf(300, 1100, 1800), stepChips("ph", "socket", "three", 2700).chips)
        assertEquals(listOf(100, 400, 500), stepChips("ph", "sewer", "d110", 2700).chips)
        assertEquals(listOf(500, 640, 800, 1000, 1200), stepChips("pw", "rad", "alu", 2700).chips)
    }

    @Test fun stepValidationSaysWhy() {
        val v = mapOf("w" to 3000, "h" to 2100)
        assertEquals(ReErr("re.e.wide", mapOf("l" to 2600, "x" to 3000)), fieldErr("door", "single", v, "w", 2600, 2700))
        assertEquals("re.e.min", fieldErr("door", "single", mapOf("w" to 250, "h" to 2100), "w", 2600, 2700)!!.key)
        assertEquals("re.e.ceil", fieldErr("door", "single", mapOf("w" to 800, "h" to 2800), "h", 3400, 2700)!!.key)
        assertNull(fieldErr("door", "single", mapOf("w" to 800, "h" to 2100), "h", 3400, 2700))
        assertEquals("re.e.sillCeil", fieldErr("window", "double", mapOf("w" to 1500, "h" to 1900, "sill" to 900), "sill", 3400, 2700)!!.key)
        // a radiator may be 200 wide, a door not
        assertNull(fieldErr("rad", "towel", mapOf("pw" to 200, "ph" to 1200), "pw", 3400, 2700))
        assertEquals("re.e.min", fieldErr("rad", "towel", mapOf("pw" to 150, "ph" to 1200), "pw", 3400, 2700)!!.key)
        // balcony: door + window must fit; the window at least 100 below the door's top
        assertEquals("re.e.balFit", fieldErr("door", "balcony", mapOf("dw" to 900, "ww" to 2000, "h" to 2100, "wh" to 1400), "ww", 2600, 2700)!!.key)
        assertEquals("re.e.balWin", fieldErr("door", "balcony", mapOf("dw" to 700, "ww" to 1200, "h" to 2100, "wh" to 2050), "wh", 3400, 2700)!!.key)
        assertEquals("re.e.balDoor", fieldErr("window", "balcony", mapOf("dw" to 700, "ww" to 1200, "h" to 1450, "wh" to 1400), "h", 3400, 2700)!!.key)
        assertEquals("re.e.ceil", fieldErr("socket", "one", mapOf("ph" to 2800), "ph", 3400, 2700)!!.key)
        assertEquals("re.e.need", fieldErr("door", "single", emptyMap(), "w", 3400, 2700)!!.key)
    }

    @Test fun standardFillsTheRestAndCheckAllFindsTheStep() {
        val v = mapOf("w" to 1800, "h" to 1400, "sill" to 100)
        assertEquals(mapOf("w" to 1800, "h" to 1500, "sill" to 900), fillStandard("window", "double", v, 0, 2700))
        assertNull(checkAll("window", "double", fillStandard("window", "double", v, 0, 2700), 3400, 2700))
        // too wide for wall B (2 600): the first step comes back
        assertEquals(0, checkAll("window", "triple", mapOf("w" to 3000, "h" to 1500, "sill" to 900), 2600, 2700)!!.first)
        assertEquals(1, checkAll("door", "single", mapOf("w" to 800, "h" to 2900), 2600, 2700)!!.first)
    }

    /* ---- items ---- */

    @Test fun applyValsKeepsTheCentreAndTheWall() {
        val base = Opening("o", "door", "A", 800, 2100, 1300)
        val d = applyVals(base, "double", mapOf("w" to 1200, "h" to 2100), 3400, 1700.0)
        assertEquals(1100, d.off); assertEquals(1200, d.w); assertEquals("double", d.style)
        // near the end it stays on the wall
        assertEquals(2200, applyVals(base, "double", mapOf("w" to 1200, "h" to 2100), 3400, 3300.0).off)
        val b = applyVals(base, "balcony", mapOf("dw" to 700, "ww" to 1200, "h" to 2100, "wh" to 1400), 3400, 1700.0)
        assertEquals(1900, b.w); assertEquals(700, b.dw); assertEquals(1400, b.wh); assertEquals(0, b.sill); assertEquals(750, b.off)
        assertTrue(b.balcony)
        assertEquals(mapOf("dw" to 700, "ww" to 1200, "h" to 2100, "wh" to 1400), valsOf(b))
        assertEquals(0, z0Of(b)); assertEquals(2100, topOf(b))
        // the balcony block takes the door part and the window part from the wall, not the whole rectangle
        assertEquals(700L * 2100 + 1200L * 1400, b.area)
        val w = applyVals(Opening("w", "window", "A", 1500, 1500, 0, 900), "pano", mapOf("w" to 1800, "h" to 2700), 3400, 1700.0)
        assertEquals(0, w.sill); assertEquals(mapOf("w" to 1800, "h" to 2700), valsOf(w))
        val win = Opening("w2", "window", "B", 1500, 1500, 500, 900)
        assertEquals(900, z0Of(win)); assertEquals(2400, topOf(win)); assertEquals(mapOf("w" to 1500, "h" to 1500, "sill" to 900), valsOf(win))
        val rad = applyVals(SitePoint("p", "rad", "A", 1000, 600), "steel", mapOf("pw" to 1000, "ph" to 600))
        assertEquals(1000, rad.pw); assertEquals("steel", rad.style)
        assertEquals(0, applyVals(SitePoint("s", "socket", "A", 1000, 300), "two", mapOf("ph" to 300, "pw" to 5)).pw)
        assertEquals(Dists(500, 2100), distsOf(Opening("x", "door", "A", 800, 2100, 500), 3400))
        assertEquals(Dists(1000, 2400), distsOf(SitePoint("p", "socket", "A", 1000, 300), 3400))
    }

    @Test fun magnetsAtCornersAndMiddleElseTenMm() {
        // a 800 door on 3 400: corners 0 and 2 600, middle 1 300
        assertEquals(Mag(0, "corner"), magnet(800, 3400, 60.0, 100.0))
        assertEquals(Mag(2600, "corner"), magnet(800, 3400, 2560.0, 100.0))
        assertEquals(Mag(1300, "mid"), magnet(800, 3400, 1340.0, 100.0))
        assertEquals(Mag(870, null), magnet(800, 3400, 873.0, 100.0))
        // the threshold is at most 250 mm, and the result stays on the wall
        assertEquals(Mag(400, null), magnet(800, 3400, 400.0, 1000.0))
        assertEquals(Mag(2600, "corner"), magnet(800, 3400, 3900.0, 10.0).let { if (it.at == null) Mag(it.v, "corner") else it })
        // a point: middle of the whole wall
        assertEquals(Mag(1700, "mid"), magnet(0, 3400, 1690.0, 50.0))
    }

    @Test fun freeSpotMovesPastOthers() {
        val a = Opening("a", "door", "A", 800, 2100, 1000)
        val b = Opening("b", "door", "A", 800, 2100, 1200)
        val spot = freeSpot(b, listOf(a), 3400)!!
        assertFalse(overlaps(b.copy(off = spot), a))
        assertNull(freeSpot(Opening("c", "door", "A", 3000, 2100, 0), listOf(a), 3400))
    }

    /* ---- Tekshiruv ---- */

    @Test fun issuesFollowTheMockupRules() {
        val lens = mapOf("A" to 3400, "B" to 2600, "C" to 3400, "D" to 2600)
        val ops = listOf(
            Opening("d1", "door", "C", 800, 2100, 400),
            Opening("d2", "door", "C", 800, 2100, 900),          // over d1
            Opening("w1", "window", "A", 1500, 1500, 3000, 900), // past the wall's end, and 2 400 is fine
            Opening("w2", "window", "B", 1200, 2000, 500, 900)   // top 2 900 above the 2 700 ceiling
        )
        val pts = listOf(
            SitePoint("s1", "socket", "B", 1500, 1100), SitePoint("c1", "cold", "D", 450, 600), SitePoint("s2", "socket", "D", 900, 300),
            SitePoint("m1", "meter", "D", 1300, 1600), SitePoint("g1", "gas", "A", 200, 2900), SitePoint("p1", "socket", "B", 800, 1200)
        )
        val iss = roomIssues(lens, 2700, ops, pts)
        fun has(id: String, key: String) = iss.any { it.id == id && it.key == key }
        assertTrue(has("d2", "re.i.over"))
        assertTrue(has("w1", "re.i.out"))
        assertTrue(has("w2", "re.i.ceil"))
        assertTrue(has("g1", "re.i.ceilP"))
        // socket 450 mm from cold water on wall D (< 600): on the socket
        assertTrue(has("s2", "re.i.water"))
        assertEquals(450, iss.first { it.id == "s2" && it.key == "re.i.water" }.args["d"])
        // gas meter 400 mm from that socket (< 500): on the meter
        assertTrue(has("m1", "re.i.gas"))
        // the socket on wall B at 800 / 1 200 is on window w2 (500–1 700, 900–2 900)
        assertTrue(has("p1", "re.i.onOp"))
        assertFalse(has("s1", "re.i.water"))
        assertTrue(roomIssues(lens, 2700, listOf(Opening("ok", "door", "A", 800, 2100, 100)), emptyList()).isEmpty())
    }

    /* ---- mirror ---- */

    @Test fun mirrorARectangleSwapsTheSideWalls() {
        val r = rect(ops = listOf(Opening("d", "door", "B", 800, 2100, 300, sw = "inL"), Opening("w", "window", "A", 1500, 1500, 400, 900)),
            pts = listOf(SitePoint("p", "socket", "C", 1000, 300)))
        val m = mirrorRoom(r)
        val d = m.openings.first { it.id == "d" }
        assertEquals("D", d.wall); assertEquals(2600 - 300 - 800, d.off); assertEquals("inR", d.sw)
        val w = m.openings.first { it.id == "w" }
        assertEquals("A", w.wall); assertEquals(3400 - 400 - 1500, w.off)
        assertEquals(2400, m.points.first().off)
        // twice is the same room
        assertEquals(r.openings, mirrorRoom(m).openings); assertEquals(r.points, mirrorRoom(m).points)
        // turned a quarter: up and down swap
        assertEquals("B", mirrorRoom(rect(ops = listOf(Opening("d", "door", "B", 800, 2100, 300)), rot = 1)).openings.first().wall)
    }

    @Test fun mirrorAnLShape() {
        // an L: 6 walls, clockwise from the top-left
        val v = listOf(Pt(0.0, 0.0), Pt(3000.0, 0.0), Pt(3000.0, 1500.0), Pt(6000.0, 1500.0), Pt(6000.0, 5000.0), Pt(0.0, 5000.0))
        val ids = polyWallIds(6)
        val dims = ids.mapIndexed { i, k -> k to Dim(Math.round(kotlin.math.hypot(v[(i + 1) % 6].x - v[i].x, v[(i + 1) % 6].y - v[i].y)).toInt(), "manual") }.toMap() +
            mapOf("H" to Dim(2700, "manual"), "T" to Dim(200, "default"))
        val r = Room("r", "f", "L", template = "poly", shape = "poly", dims = dims, poly = Poly(v, snap = true),
            openings = listOf(Opening("d", "door", "A", 800, 2100, 200)))
        val m = mirrorRoom(r)
        assertEquals(6, m.poly!!.verts.size)
        assertTrue(shoelace(m.poly!!.verts) > 0 == shoelace(v) > 0)
        // wall A (3 000) became the last wall, its door measured from the other end
        val d = m.openings.first()
        assertEquals(ids[5], d.wall); assertEquals(3000 - 200 - 800, d.off)
        assertEquals(3000, m.dims[ids[5]]!!.v)
        // the mirrored room's walls have the lengths their dims say
        walls(m).forEach { w -> assertEquals(w.id, m.dims[w.id]!!.v, w.len) }
    }

    @Test fun thicknessPerWall() {
        val r = rect().copy(thick = mapOf("B" to 380))
        assertEquals(380, thickOf(r, "B")); assertEquals(200, thickOf(r, "A"))
    }

    /* ---- the model's new fields load and save as before ---- */

    @Test fun newFieldsKeepOldFilesAndAreLeftOutWhenEmpty() {
        val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
        val old = """{"id":"o","type":"door","wall":"A","w":800,"h":2100,"off":100}"""
        val o = json.decodeFromString(Opening.serializer(), old)
        assertEquals("", o.style); assertEquals(0, o.dw); assertFalse(o.balcony)
        val enc = json.encodeToString(Opening.serializer(), o)
        assertFalse(enc.contains("style")); assertFalse(enc.contains("\"dw\"")); assertFalse(enc.contains("\"sw\""))
        val b = o.copy(style = "balcony", dw = 700, w = 1900, wh = 1400)
        assertEquals(b, json.decodeFromString(Opening.serializer(), json.encodeToString(Opening.serializer(), b)))
        val p = SitePoint("p", "rad", "A", 100, 600, style = "alu", pw = 640)
        assertEquals(p, json.decodeFromString(SitePoint.serializer(), json.encodeToString(SitePoint.serializer(), p)))
        assertFalse(json.encodeToString(SitePoint.serializer(), SitePoint("q", "socket", "A", 1, 300)).contains("pw"))
        val r = rect().copy(thick = mapOf("A" to 120))
        assertEquals(r.thick, json.decodeFromString(Room.serializer(), json.encodeToString(Room.serializer(), r)).thick)
        assertFalse(json.encodeToString(Room.serializer(), rect()).contains("thick"))
    }

    @Test fun areasUseTheBalconyArea() {
        val b = Opening("b", "door", "A", 1900, 2100, 100, style = "balcony", dw = 700, wh = 1400)
        val a = areas(rect(ops = listOf(b)))!!
        assertEquals(700L * 2100 + 1200L * 1400, a.open)
    }
}
