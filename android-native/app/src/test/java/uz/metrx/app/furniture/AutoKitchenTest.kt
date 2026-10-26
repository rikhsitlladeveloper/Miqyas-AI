package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import kotlin.math.abs
import kotlin.math.hypot

/**
 * The auto kitchen (AutoKitchen.kt) on the approved mockup's room (3.4 × 2.8 m, the window on A, the door on C, the
 * water on A at 1600, the gas on B at 400) and a few others. Without a corner the plans are the mockup's own, unit for
 * unit (checked against its gen() run in node, 26 Oct 2026).
 */
class AutoKitchenTest {
    private val ws = Workshop()

    private fun room(a: Int, b: Int, openings: List<Opening>, points: List<SitePoint>) = Room("r", "f", "Oshxona",
        dims = mapOf("A" to Dim(a, "manual"), "B" to Dim(b, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")),
        openings = openings, points = points)

    /** The mockup's room. */
    private val mock = room(3400, 2800, listOf(Opening("w", "window", "A", 1200, 1250, 1000, 950), Opening("d", "door", "C", 800, 2050, 1300)),
        listOf(SitePoint("c", "cold", "A", 1600, 550), SitePoint("g", "gas", "B", 400, 1000)))
    /** A bigger room: the window on D, the water on B, the gas on A, the door on C near its end. */
    private val big = room(4200, 3000, listOf(Opening("w", "window", "D", 1400, 1400, 800, 900), Opening("d", "door", "C", 900, 2100, 3000)),
        listOf(SitePoint("c", "cold", "B", 1500, 550), SitePoint("s", "sewer", "B", 1550, 450), SitePoint("g", "gas", "A", 3500, 1100)))
    /** A small one: no window on the kitchen's walls, no points marked. */
    private val small = room(2600, 2400, listOf(Opening("d", "door", "D", 800, 2050, 800)), emptyList())
    private val rooms = listOf(mock, big, small)

    private fun siteOf(r: Room) = akSite(r, { null })

    /** Every row of every wall from its start to its end, nothing missing, nothing overlapping: the plan and the kitchen. */
    private fun assertWhole(site: AkSite, plan: AkPlan, fs: List<Furniture>) {
        plan.runs.forEach { r ->
            listOf(r.low, r.up).forEach { row ->
                assertEquals("${r.wall} starts at 0", 0, row.first().a)
                row.zipWithNext().forEach { (x, y) -> assertEquals("${r.wall}: ${x.k} meets ${y.k}", x.b, y.a) }
                assertEquals("${r.wall} ends at its end", r.len, row.last().b)
                row.forEach { assertTrue("${r.wall} ${it.k} ${it.w}", it.w > 0) }
            }
        }
        fs.forEach { f ->
            val runs = runsOf(f) { site.wall(it).len }
            runs.forEach { run ->
                listOf(false, true).forEach { up ->
                    val row = f.modules.filter { it.wall == run.wall && isUpper(it) == up }.sortedBy { it.x }
                    assertEquals("${run.wall} up=$up is full", 0, fillOf(f, run, up).left)
                    assertEquals(if (up) run.upStart else run.lowStart, row.first().x)
                    row.zipWithNext().forEach { (x, y) -> assertEquals("${run.wall} up=$up: no gap, no overlap", x.x + x.w, y.x) }
                }
            }
            // the app's own checks find nothing wrong with where the units stand
            val c = checks(f, runs, ws, mockOpenings(site), emptyList())
            assertTrue(c.filter { it.level == "err" }.toString(), c.none { it.level == "err" })
            assertTrue(c.none { it.key == "kc.tallUp" })
            // nothing in front of a window (the spaces left over it do not count), unless the tall units had to go there
            if (plan.checks.none { it.key == "ak.ck.frWin" }) assertTrue(c.filter { it.key == "kc.window" }.toString(), c.none { it.key == "kc.window" })
        }
        // two rows: the pieces do not share a wall
        assertEquals(fs.flatMap { it.walls }.size, fs.flatMap { it.walls }.toSet().size)
    }

    private fun mockOpenings(site: AkSite) = site.windows.map { Opening("w", "window", it.wall, it.b - it.a, it.top - it.sill, it.a, it.sill) } +
        site.doors.map { Opening("d", "door", it.wall, it.b - it.a, it.top - it.sill, it.a, it.sill) }

    @Test fun everyLayoutOnEveryRoomFillsTheWallsWithNoGapOrOverlap() {
        var n = 0
        for (r in rooms) {
            val site = siteOf(r)
            for (layout in AK_LAYOUTS) {
                val walls = akWallsFor(site, layout, akStart(site)) ?: continue
                assertEquals(layout, akLayoutOf(site, walls))
                for (app in listOf(AkApp(), AkApp("bi", "tall", false, "angled"))) for (p in DESIGN_PRESETS) {
                    val plan = akPlan(site, walls, layout, app, p.id, ws)
                    assertNotNull("${r.dims} $layout ${p.id}", plan); plan!!
                    val fs = akPieces(plan, site, ws, listOf("Oshxona 1", "Oshxona 2"))
                    assertEquals(if (layout == "two") 2 else 1, fs.size)
                    assertWhole(site, plan, fs)
                    // the preset's look is on it
                    fs.forEach { f -> assertEquals(p.id, presetOf(f)); assertEquals("r", f.roomId); assertEquals("f", f.ws) }
                    n++
                }
            }
        }
        assertTrue(n >= 3 * 4 * 2 * 6 - 2 * 6 * 2)
    }

    @Test fun withoutACornerItIsTheMockupsOwnPlan() {
        val site = siteOf(mock)
        val plan = akPlan(site, listOf("A"), "line", AkApp(), "twotone", ws)!!
        // mockup gen(): fridge, dishwasher, sink at the water, drawers, the hob (oven under it), drawers
        assertEquals(listOf("fridgeFS" to (0 to 600), "dw" to (600 to 1200), "sink" to (1200 to 2000), "drawers" to (2000 to 2500), "hobOven" to (2500 to 3100), "drawers" to (3100 to 3400)),
            plan.runs[0].low.map { it.k to (it.a to it.b) })
        // its wall units: the vitrina and the open shelf of the two-tone style, the hood over the hob, none over the window
        assertEquals(listOf("space", "shelf", "space", "doors", "hood", "doors"), plan.runs[0].up.map { it.k })
        assertEquals(950, plan.runs[0].up[1].b); assertEquals(2250, plan.runs[0].up[3].a)
        val two = akPlan(site, listOf("D", "B"), "two", AkApp(), "gola", ws)!!
        assertEquals(listOf("fridgeFS", "pantry", "doors", "dw", "sink"), two.runs[0].low.map { it.k })
        assertEquals(listOf(0, 600, 1050, 1400, 2000), two.runs[0].low.map { it.a })
        assertEquals(listOf("drawers", "hobOven", "drawers", "drawers", "drawers"), two.runs[1].low.map { it.k })
        assertEquals(listOf("warn", "ok", "warn", "warn", "ok", "ok", "ok", "ok"), two.checks.map { it.level })
    }

    @Test fun theSinkGoesToTheWaterAndTheHobToTheGas() {
        val site = siteOf(mock)
        for (p in DESIGN_PRESETS) {
            val plan = akPlan(site, listOf("A", "B"), "L", AkApp(), p.id, ws)!!
            val (sw, sink) = plan.sink
            assertEquals("A", sw)
            assertTrue("${p.id}: sink ${sink.a}..${sink.b} at the water 1600", 1600 in sink.a..sink.b)
            val (hw, hob) = plan.hob
            assertEquals("B", hw)
            // the gas at 400 on B, past the corner: as near as 300 mm clear of the corner run allows
            assertTrue("${p.id}: hob ${hob.a}..${hob.b}", hob.a in 650..1000)
            assertTrue(plan.checks.any { it.key == "ak.ck.gOk" && it.level == "ok" })
        }
        val b = siteOf(big)
        val u = akPlan(b, akWallsFor(b, "U", listOf("A"))!!, "U", AkApp(), "twotone", ws)!!
        assertEquals("B", u.sink.first)
        assertTrue(1500 in u.sink.second.a..u.sink.second.b)
        assertEquals("A", u.hob.first)
        assertTrue(abs((u.hob.second.a + u.hob.second.b) / 2 - 3500) <= 400)
    }

    @Test fun theFridgeIsNeverUnderAWindow() {
        for (r in rooms) {
            val site = siteOf(r)
            for (layout in AK_LAYOUTS) for (start in site.free) {
                val walls = akWallsFor(site, layout, listOf(start)) ?: continue
                for (app in listOf(AkApp(), AkApp("bi", "tall"))) for (p in DESIGN_PRESETS) {
                    val plan = akPlan(site, walls, layout, app, p.id, ws) ?: continue
                    val under = plan.runs.any { run ->
                        run.low.any { t -> t.k in setOf("fridgeFS", "fridgeBI", "ovenT", "pantry") && site.windows.any { it.wall == run.wall && t.a < it.b && t.b > it.a } }
                    }
                    // only when no wall end of the kitchen is clear of windows for them (a line on the big room's window wall D, 3 m with a 1,4 m window in its middle)
                    if (under) {
                        assertTrue("${p.id} $layout $walls", plan.checks.any { it.key == "ak.ck.frWin" && it.level == "warn" })
                        assertTrue("${p.id} $layout $walls", r === big && walls == listOf("D"))
                    } else assertTrue(plan.checks.any { it.key == "ak.ck.frEnd" })
                    if (r === mock) assertFalse(under)
                }
            }
        }
        // a wall that is all window: the tall units go under it only as the last resort, and that is said
        val glass = room(3000, 2600, listOf(Opening("w", "window", "A", 2900, 1300, 50, 900)), emptyList())
        val plan = akPlan(siteOf(glass), listOf("A"), "line", AkApp(), "twotone", ws)!!
        assertTrue(plan.checks.any { it.key == "ak.ck.frWin" && it.level == "warn" })
    }

    @Test fun theChecksNumbers() {
        val site = siteOf(mock)
        val plan = akPlan(site, listOf("A"), "line", AkApp(), "twotone", ws)!!
        fun c(k: String) = plan.checks.first { it.key == k }
        // the sink 1200–2000 and the hob 2500–3100, 300 mm out from wall A: 1,2 m apart
        assertEquals(1200, c("ak.ck.sh").vars["m"])
        assertEquals("ok", c("ak.ck.sh").level)
        // the hob ends 300 mm before the wall's end
        assertEquals(300, c("ak.ck.hobClear").vars["mm"]); assertEquals("ak.o.wall", c("ak.ck.hobClear").vars["o"])
        // the dishwasher's 600 beside the free-standing fridge is worktop
        assertEquals(600, c("ak.ck.frOk").vars["mm"])
        // the sink's middle is on the water point; the hob 2800 along A from the gas at (3400, 400)
        assertEquals("ak.ck.wOn", plan.checks.first { it.key.startsWith("ak.ck.w") }.key)
        assertEquals(Math.round(hypot(3400.0 - 2800, 400.0)).toInt(), c("ak.ck.gOk").vars["m"])
        assertEquals("350, 250", c("ak.ck.fit").vars["n"])
        assertEquals(0, plan.err); assertEquals(0, plan.warn)
        // two rows far apart: the walk from the sink to the hob is too long, the water far
        val two = akPlan(site, listOf("D", "B"), "two", AkApp(), "gola", ws)!!
        assertEquals("ak.ck.shFar", two.checks[0].key); assertEquals(2807, two.checks[0].vars["m"])
        assertEquals("ak.ck.wFar", two.checks[3].key); assertEquals(1649, two.checks[3].vars["m"])
        assertEquals(200, two.checks[4].vars["m"])
        assertEquals(3, two.warn)
        // a hob pressed against a tall unit, too close
        val tight = akPlan(site, listOf("B"), "line", AkApp("bi", "tall"), "neo", ws)!!
        assertEquals("ak.ck.hobTight", tight.checks[1].key); assertEquals(0, tight.checks[1].vars["mm"])
        assertEquals("ak.ck.dwNone", tight.checks.last().key)
    }

    @Test fun wallsAndLayouts() {
        val site = siteOf(mock)
        // the door's wall C cannot take the kitchen
        assertEquals(listOf("A", "B", "D"), site.free)
        assertEquals("line", akLayoutOf(site, listOf("A")))
        assertEquals("L", akLayoutOf(site, listOf("D", "A")))
        assertEquals("two", akLayoutOf(site, listOf("D", "B")))
        assertEquals("U", akLayoutOf(site, listOf("A", "D", "B")))
        assertEquals(listOf("D", "A", "B"), akChain(site, listOf("A", "D", "B")))
        assertEquals(listOf("D", "A", "B"), akWallsFor(site, "U", listOf("A")))
        assertEquals(listOf("B", "D"), akWallsFor(site, "two", listOf("D"))?.sorted())
        assertEquals(listOf("A"), akStart(site))
        // the corner as the app builds it: A turns into B, a 50 filler and the blind unit at A's end, B past it
        val l = akPieces(akPlan(site, listOf("A", "B"), "L", AkApp(), "wood", ws)!!, site, ws, listOf("Oshxona"))[0]
        val lowA = l.modules.filter { it.wall == "A" && !isUpper(it) }.sortedBy { it.x }
        assertEquals("panel", lowA.last().fronts.kind); assertEquals(600, lowA.last().w); assertEquals("filler", lowA[lowA.size - 2].type)
        val lowB = l.modules.filter { it.wall == "B" && !isUpper(it) }.sortedBy { it.x }
        assertEquals(600, lowB.first().x); assertEquals("filler", lowB.first().type); assertEquals(50, lowB.first().w)
        assertEquals("L", l.layout); assertEquals(listOf("A", "B"), l.walls)
        // the room too small for any kitchen of its tall units: none
        val tiny = room(800, 800, emptyList(), emptyList())
        assertNull(akPlan(siteOf(tiny), listOf("A"), "line", AkApp("bi", "tall"), "gola", ws))
    }
}
