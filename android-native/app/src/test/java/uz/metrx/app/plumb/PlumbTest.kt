package uz.metrx.app.plumb

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.Workspace
import uz.metrx.app.tiles.V2
import uz.metrx.app.trades.TradeSet

/**
 * The plumber's fixtures, routes and counts on two rooms: a bathroom 2,6 × 2 × 2,7 m with its door on wall A (700 at
 * 200), and a kitchen 4 × 3 × 2,7 m with its door on wall A (800 at 200), a window on wall C (1200 × 1400 at 900, 1400
 * from C's start) and the sink's cold water and drain marked on wall C.
 */
class PlumbTest {
    private fun dims(a: Int, b: Int, h: Int = 2700) = mapOf("A" to Dim(a), "B" to Dim(b), "H" to Dim(h), "T" to Dim(200, "default"))
    private val bath = Room("b", "wb", "Hammom", dims = dims(2600, 2000), openings = listOf(Opening("bd", "door", "A", 700, 2100, 200)))
    private val kitchen = Room("k", "wk", "Oshxona", dims = dims(4000, 3000), openings = listOf(
        Opening("kd", "door", "A", 800, 2100, 200), Opening("kw", "window", "C", 1200, 1400, 1400, 900)),
        points = listOf(SitePoint("cw", "cold", "C", 2900, 550), SitePoint("sw", "sewer", "C", 2900, 500, 50)))
    private fun project(fixes: List<PlFix> = emptyList(), riser: PlRiser? = null, rooms: List<PlRoom> = emptyList(), points: List<PlPoint> = emptyList(),
                        free: List<PlFree> = emptyList(), run: String = "wall") =
        Project("p", "Test", floors = listOf(Workspace("wb", "Hammom", "bath"), Workspace("wk", "Oshxona", "kitchen")), rooms = listOf(bath, kitchen), industry = "plumb",
            plumb = PlumbOrder(fixes, points, rooms, riser, run = run, free = free))
    private var n = 0
    private fun id() = "f${n++}"
    private val riser = PlRiser("b", "C", 140)
    private fun fix(t: String, room: String, wall: String, off: Int, w: Int = 0) = PlFix("x$t$off", t, room, wall, off, w, pts = defaultPts(t, w))

    @Test fun kitPlacesClearOfDoorsAndEachOther() {
        val p = project()
        val c = ctxOf(p, "b", true)!!
        assertEquals("bath", c.kind)
        val r = riserIn(c)
        assertEquals("C", r.wall); assertEquals(140, r.off)
        val fs = placeKit(pkitOf("bt.bath")!!, c, emptyList(), r, ::id)
        assertEquals(listOf("bath", "wc", "bs", "wm"), fs.map { it.t })
        // the toilet goes beside the riser (its 110 drain short), the bath along the same wall clear of both
        val b = fs.first { it.t == "bath" }
        val w0 = fs.first { it.t == "wc" }
        assertEquals("C", w0.wall); assertEquals(580, w0.off)
        assertTrue(wcToRiser(c, w0, r) <= WC_MAX)
        assertEquals("C", b.wall); assertTrue(b.off - 850 >= w0.off + 190 + 30)
        for (f in fs) {
            assertFalse("${f.t} in the door's way", blocksDoor(c, f))
            assertFalse("${f.t} on the riser", convexHit(fixPoly(c, f)!!, riserPoly(c, r)!!))
            // nothing stands or hangs over another (only a heater or towel rail may hang above)
            for (g in fs) if (g.id != f.id && (fixZ0(g) < fixTop(f) && fixZ0(f) < fixTop(g) || listOf(f, g).none { fixType(it.t).cat == "heater" || it.t == "tr" }))
                assertFalse("${f.t} on ${g.t}", convexHit(fixPoly(c, f)!!, fixPoly(c, g)!!))
        }
        assertTrue(fixWarnings(c, fs, fs.flatMap { fixPoints(it) }).isEmpty())
        // the door's swing on wall A is never taken: a toilet pushed there moves out of it
        val wc = fs.first { it.t == "wc" }
        val x = snapFix(c, wc, "A", 500, fs, r)!!
        assertFalse(blocksDoor(c, moveFix(wc, "A", x)))
        assertTrue(x - 190 >= 900 || x + 190 <= 200)
        // the bath dragged onto wall A (no 1,7 m clear of the door there) stays where it was
        assertEquals(b.wall to b.off, snapFixPlan(c, b, V2(1500.0, 100.0), fs, r))
        assertEquals(null, snapFix(c, b, "A", 1500, fs, r))
    }

    @Test fun outletsAtTheirUsualHeights() {
        fun pts(t: String) = defaultPts(t).associate { it.t + (if (it.t == "drain") "" else "") to it }
        assertEquals(550, pts("bs")["cold"]!!.h); assertEquals(550, pts("bs")["hot"]!!.h); assertEquals(500, pts("bs")["drain"]!!.h)
        assertEquals(100, pts("wc")["drain"]!!.h); assertEquals(110, pts("wc")["drain"]!!.d); assertEquals(200, pts("wc")["cold"]!!.h)
        assertEquals(600, pts("wm")["cold"]!!.h)
        assertEquals(550, pts("sink")["cold"]!!.h)
        assertEquals(1100, pts("sh")["cold"]!!.h); assertEquals(800, pts("bath")["hot"]!!.h)
        // outlets follow their fixture
        val f = fix("bs", "b", "C", 1490)
        assertEquals(listOf(1410, 1570, 1490), fixPoints(f).map { it.off })
        assertEquals(listOf(1610, 1770, 1690), fixPoints(moveFix(f, "C", 1690)).map { it.off })
        // loose outlets snap to the usual heights in whole centimetres
        val c = ctxOf(project(), "b", true)!!
        val q = PlPoint("q", "cold", "b", "C", 1000, 550)
        assertEquals(1000 to 550, snapPoint(c, q, 1003, 530))
        assertEquals(1010 to 700, snapPoint(c, q, 1007, 703))
    }

    @Test fun routesAndDrainSlopeOnAKnownRoom() {
        val basin = fix("bs", "b", "C", 1490)
        val p = project(listOf(basin), riser.copy(hot = false))
        val calc = calcOf(p, true)
        val cold = calc.routes.runs.single { it.kind == "cold" }
        // from the riser (C 140) along wall C to the cold outlet (C 1570) at 250 up, then up to 550
        assertEquals(RISER_TAIL + 1430.0, cold.trunk, 1e-6)
        assertEquals(300.0, cold.drops, 1e-6)
        assertEquals(20, cold.dia)
        // the drain: 1350 back to the riser at 3 cm a metre, down from 500 to where that slope starts
        val d = calc.routes.drains.single()
        assertEquals(1350.0, d.horiz, 1e-6)
        assertEquals(SLOPE_50.toDouble(), d.slope, 1e-6)
        assertEquals(500 - (DRAIN_IN + 30 * 1.35), d.vertical, 1e-6)
        // the drain falls towards the riser
        val segs = d.runs.single().segs
        assertTrue(segs.last().zb < segs[1].za)
        assertEquals(DRAIN_IN.toDouble(), segs.last().zb, 1e-6)
        // no hot water: the riser brings none and there is no heater
        assertTrue(calc.warns.any { it.key == "sx.w.noHot" })
        assertTrue(calcOf(p.copy(plumb = p.plumb.copy(riser = riser)), true).warns.none { it.key == "sx.w.noHot" })
    }

    @Test fun routesCrossRoomsThroughTheDoors() {
        val sink = fix("sink", "k", "C", 2900)
        val p = project(listOf(sink), riser, rooms = listOf(PlRoom("k", "kitchen", link = 1500)))
        val calc = calcOf(p, true)
        val cold = calc.routes.runs.filter { it.kind == "cold" }
        assertEquals(setOf("b", "k"), cold.map { it.roomId }.toSet())
        // the kitchen: in through its doorway in the floor, up beside it, round walls D and C to the sink
        val k = cold.single { it.roomId == "k" }
        assertEquals(1500.0 + 4620 + (WATER_Z - FLOOR_Z), k.trunk, 1e-6)
        assertEquals(300.0, k.drops, 1e-6)
        // the bathroom: from the riser to its door, dipping into the floor under it
        val b = cold.single { it.roomId == "b" }
        assertEquals(1, b.dips)
        assertEquals(FLOOR_Z.toDouble(), b.segs.last().zb, 1e-6)
        // the sink's drain comes back through the doors to the riser
        val d = calc.routes.drains.single()
        assertEquals(setOf("k", "b"), d.runs.map { it.roomId }.toSet())
        assertEquals(1500.0, d.between, 1e-6)
        assertTrue(d.horiz > 1500 + 3000)
    }

    @Test fun pipeSizesSticksAndCoils() {
        assertEquals(20, trunkDia(3)); assertEquals(25, trunkDia(5)); assertEquals(32, trunkDia(13))
        val s = pipeNeed("water", 20, 10.0, "ppr", 10)
        assertEquals(11.0, s.withSpare, 1e-9); assertEquals(3, s.pieces); assertEquals("stick", s.unit)
        val m = pipeNeed("water", 25, 49.0, "mp", 10)
        assertEquals(2, m.pieces); assertEquals(50, m.per); assertEquals("coil", m.unit)
        assertEquals(1, pipeNeed("water", 20, 95.0, "pex", 5).pieces)
        assertEquals(2, pipeNeed("ufh", 16, 250.0, "ppr", 0).pieces)
        assertEquals(0, pipeNeed("water", 20, 0.0, "ppr", 10).pieces)
        // a coiled pipe under 50 m with the spare is bought by the metre, as the electrician's cable; the underfloor pipe too
        val short = pipeNeed("water", 20, 40.0, "pex", 10)
        assertEquals("m", short.unit); assertEquals(44, short.pieces); assertEquals(1, short.per)
        assertEquals("m", pipeNeed("ufh", 16, 30.0, "ppr", 10).unit)
        assertEquals("coil", pipeNeed("ufh", 16, 46.0, "ppr", 10).unit)
        assertEquals("m", pipeNeed("heat", 20, 45.0, "mp", 10).unit)
    }

    @Test fun radiatorsSizedByTheFloorUnderTheWindow() {
        assertEquals(7, radSections(12.0)); assertEquals(3, radSections(1.0)); assertEquals(560, radWidth(7))
        val c = ctxOf(project(), "k", true)!!
        val rs = placeRadiators(c, emptyList(), null, ::id)
        val r = rs.single()
        assertEquals("C", r.wall); assertEquals(2000, r.off); assertEquals(560, fixW(r))
        assertEquals(listOf(-240, 240), r.pts.map { it.dx })
        assertEquals(1260, radWatts(r))
        // a bigger radiator keeps its outlets at its ends
        assertEquals(listOf(-360, 360), resizeFix(r, 800).pts.map { it.dx })
    }

    @Test fun underfloorLoopsSplitAtTheLongest() {
        val p = project(rooms = listOf(PlRoom("k", "kitchen", ufh = true, step = 150)))
        val c = ctxOf(p, "k", true)!!
        val l = loopOf(c, emptyList(), null, null)
        assertEquals(12.0, l.area, 1e-9)
        assertEquals(80_000 + 2000.0, l.total, 1e-6)
        assertEquals(2, l.n); assertEquals(41_000.0, l.each, 1e-6)
        // the bath stands on part of the floor; at 200 one loop does
        val l2 = loopOf(c.let { ctxOf(p.copy(plumb = p.plumb.copy(rooms = listOf(PlRoom("k", "kitchen", ufh = true, step = 200)))), "k", true)!! }, listOf(fix("bath", "k", "B", 1000)), null, null)
        assertEquals(12.0 - 1.7 * .75, l2.area, 1e-9)
        assertEquals(1, l2.n)
        assertTrue(snake(c, 150).size > 20)
        // heating with no boiler warns
        assertTrue(calcOf(p, true).warns.any { it.key == "sx.w.noBoiler" })
    }

    @Test fun warnings() {
        // a shower tray laid flat (its drain at 60, where the riser takes it) has no fall 1,35 m from the riser; a toilet on wall A is 2,4 m from it; a basin's cold at 90 cm
        val tray = fix("sh", "b", "C", 1490).let { f -> f.copy(pts = f.pts.map { if (it.t == "drain") it.copy(h = 60) else it }) }
        val wc = fix("wc", "b", "A", 2300)
        val basin = fix("bs", "b", "D", 1000).let { f -> f.copy(pts = f.pts.map { if (it.t == "cold") it.copy(h = 900) else it }) }
        val p = project(listOf(tray, wc, basin), riser)
        val ws = calcOf(p, true).warns
        assertTrue(ws.any { it.key == "sx.w.slope" && it.target == tray.id })
        assertTrue(ws.any { it.key == "sx.w.wcFar" && it.target == wc.id })
        assertTrue(ws.any { it.key == "sx.w.height" && it.target == basin.id })
        assertTrue(ws.none { it.key == "sx.w.slope" && it.target == wc.id })
        // a long 50 drain
        val far = project(listOf(fix("bs", "b", "A", 2100)), riser.copy(off = 1900), rooms = listOf(PlRoom("b", "bath")), run = "wall")
        val pl = far.plumb.copy(drainMax = 1000)
        assertTrue(calcOf(far.copy(plumb = pl), true).warns.any { it.key == "sx.w.long" })
        // a fixture in the door's way
        val c = ctxOf(p, "b", true)!!
        assertTrue(fixWarnings(c, listOf(fix("wm", "b", "A", 600)), emptyList()).any { it.key == "sx.w.door" })
        // no riser; a radiator with no boiler
        assertTrue(calcOf(project(listOf(tray)), true).warns.any { it.key == "sx.w.noRiser" })
        assertTrue(calcOf(project(listOf(fix("rad", "k", "C", 2000, 560)), riser), true).warns.any { it.key == "sx.w.noBoiler" })
        assertTrue(calcOf(project(listOf(fix("rad", "k", "C", 2000, 560), fix("gb", "b", "D", 1000)), riser), true).warns.none { it.key == "sx.w.noBoiler" })
    }

    @Test fun roomWithoutAPlan() {
        val f = PlFree("f", "Hammom", "bath", 2600, 2000, 2700, wc = 1, basin = 1, bath = 1, link = 3000)
        val p = Project("p", "T", industry = "plumb", plumb = PlumbOrder(free = listOf(f)))
        val cs = ctxs(p, true)
        assertEquals(1, cs.size)
        val fs = fixesIn(p, cs[0])
        assertEquals(listOf("bath", "wc", "bs"), fs.map { it.t })
        val calc = calcOf(p, true)
        // every drain reaches the door and the 3 m to the riser
        assertEquals(3, calc.routes.drains.size)
        assertTrue(calc.routes.drains.all { it.between == 3000.0 && it.horiz > 3000 })
        assertTrue(calc.count.drain110 > 3 && calc.count.drain50 > 3)
        assertTrue(calc.routes.runs.filter { it.kind == "cold" }.all { it.trunk >= 3000 })
        // a kit's counts for a room typed by size
        val k = freeOf(pkitOf("bt.shower")!!, pkitOf("bt.shower")!!.opts, "x", "Hammom", 2500, 2000, 2700)
        assertEquals(1, k.shower); assertEquals(1, k.wc); assertEquals(1, k.basin); assertEquals(1, k.wm); assertEquals(0, k.bath)
    }

    @Test fun estimateRows() {
        val p = project(listOf(fix("bs", "b", "C", 1490), fix("wc", "b", "C", 970), fix("sink", "k", "C", 2900)), riser)
        val r = plumbRows(p, TradeSet(), true) { k, v -> k + v.entries.joinToString("") { "|" + it.key + "=" + it.value } }
        assertTrue((r.mats + r.labor).all { it.id.startsWith("t-") })
        val pipe = r.mats.filter { it.name.startsWith("sx.e.pipeS") }
        assertTrue(pipe.isNotEmpty())
        assertTrue(pipe.all { it.qty.toInt() % STICK == 0 && it.name.contains("s=~sx.sys.ppr") })
        assertTrue(r.mats.any { it.name == "sx.e.d110" })
        assertTrue(r.mats.any { it.name == "sx.e.d50" })
        assertTrue(r.mats.any { it.name == "sx.e.mainv" && it.qty == "2" })
        assertTrue(r.mats.any { it.name == "sx.e.ball" && it.qty == "5" })
        assertTrue(r.labor.any { it.name == "sx.e.lPts|n=8" && it.amount == (8 * 120000).toString() })
        assertTrue(r.labor.any { it.name == "sx.e.lFix|n=3" })
        assertEquals(8.0, r.facts["points"]!!, 0.0)
        // metal-plastic comes in coils
        val m = plumbRows(p.copy(plumb = p.plumb.copy(water = "mp")), TradeSet(), true) { k, v -> k + v.entries.joinToString("") { "|" + it.key + "=" + it.value } }
        assertTrue(m.mats.any { it.name.startsWith("sx.e.pipeC") || it.name.startsWith("sx.e.pipeM") })
        assertTrue(m.mats.filter { it.name.startsWith("sx.e.pipeC") }.all { it.qty.toInt() % 50 == 0 })
        assertTrue(m.mats.filter { it.name.startsWith("sx.e.pipeM") }.all { it.qty.toInt() < 50 })
        assertTrue(m.mats.none { it.name == "sx.e.coup" })
    }

    @Test fun takesInTheRoomsWaterOnce() {
        val p = project()
        val c = ctxOf(p, "k", true)!!
        val got = fromSitePoints(c, ::id)
        assertEquals(listOf("cold", "drain"), got.map { it.t })
        assertEquals(listOf("cw", "sw"), got.map { it.from })
        assertEquals(50, got[1].d)
        val c2 = ctxOf(p.copy(plumb = p.plumb.copy(rooms = listOf(PlRoom("k", seen = listOf("cw", "sw"))))), "k", true)!!
        assertTrue(fromSitePoints(c2, ::id).isEmpty())
        assertNotNull(defaultRiser(p.copy(plumb = p.plumb.copy(fixes = listOf(fix("wc", "b", "C", 970)))), true)?.takeIf { it.roomId == "b" })
        assertEquals("wc", guessKind(null, "Hojatxona")); assertEquals("bath", guessKind("bath", "Hammom")); assertEquals("kitchen", guessKind(null, "Oshxona"))
    }
}
