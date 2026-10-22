package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Opening
import uz.metrx.app.data.SitePoint

/** Kitchen rules (furniture plan section 7) on the design's L-kitchen: walls A 3400 and B 2600. */
class KitchenTest {
    private val ws = Workshop()
    private val lens = mapOf("A" to 3400, "B" to 2600)
    private val f0 = Furniture("k", "kitchen", walls = listOf("A", "B"), layout = "L")
    private val runs = runsOf(f0) { lens[it] }
    private val water = listOf(SitePoint("w", "cold", "A", 1300, 550), SitePoint("s", "sewer", "A", 1320, 450))

    @Test fun theNextWallStartsAfterTheCorner() {
        assertEquals(listOf(Run("A", 3400, 0, 0), Run("B", 2600, 600, 320)), runs)
        assertEquals(858, worktopTop(ws)); assertEquals(1458, wallElev(ws))
    }

    @Test fun autoFillUsesWholeUnitsAndPutsTheSinkOverTheWater() {
        val f = autoFill(f0, runs, ws, emptyList(), water)
        val lowA = f.modules.filter { it.wall == "A" && !isUpper(it) }
        // A turns into B: its narrow piece at its start, a whole unit in the corner, blind behind B's first unit
        assertEquals(listOf(400, 600, 600, 600, 600, 600), lowA.map { it.w })
        assertEquals(listOf(0, 400, 1000, 1600, 2200, 2800), lowA.map { it.x })
        assertEquals("sink", lowA[2].app)                       // 1000–1600 holds the water at 1300
        assertEquals("panel", lowA.last().fronts.kind)
        // B starts past the corner with a 50 filler, so its doors and handles clear A's
        val lowB = f.modules.filter { it.wall == "B" && !isUpper(it) }
        assertEquals(listOf(50, 600, 600, 600, 150), lowB.map { it.w })
        assertEquals("filler", lowB.first().type); assertEquals("filler", lowB.last().type)
        assertEquals(600, lowB.first().x)
        assertEquals(Fill(3400, 3400), fillOf(f, runs[0], false))
        val c = checks(f, runs, ws, emptyList(), water)
        assertTrue(c.none { it.level == "err" })
        assertTrue(c.any { it.key == "kc.sinkOk" })
    }

    @Test fun windowsLeaveASpaceInTheUpperRow() {
        val win = listOf(Opening("o", "window", "B", 1200, 1400, 1000, 900))
        val f = autoFill(f0, runs, ws, win, emptyList())
        val upB = f.modules.filter { it.wall == "B" && isUpper(it) }
        // B's upper row past the corner: a 50 filler, then 370–970 is clear; 970–1570, 1570–2170 and 2170–2600 meet
        // the window at 1000–2200
        assertEquals(listOf("filler", "wall", "gap", "gap", "gap"), upB.map { it.type })
    }

    @Test fun tooLongAndGapsAreReported() {
        val f = pack(f0.copy(modules = listOf(template("base", ws, "A", 2000), template("base", ws, "A", 1600), template("base", ws, "B", 1000))), runs)
        val c = checks(f, runs, ws, emptyList(), emptyList())
        assertTrue(c.any { it.key == "kc.over" && it.vars["v"] == 200 && it.vars["w"] == "A" })
        assertTrue(c.any { it.key == "kc.gap" && it.vars["v"] == 1000 && it.vars["w"] == "B" })
    }

    @Test fun socketsDoorsAndTheMeterAreChecked() {
        val f = pack(f0.copy(modules = listOf(template("drawers", ws, "A", 600), template("base", ws, "A", 600), template("pantry", ws, "B", 600))), runs)
        val pts = listOf(SitePoint("p", "socket", "A", 520, 300), SitePoint("m", "meter", "B", 900, 1500, 300, 400))
        val door = listOf(Opening("d", "door", "A", 900, 2100, 1100, 0))
        val c = checks(f, runs, ws, door, pts)
        assertEquals(f.modules[0].id, c.single { it.key == "kc.socket" }.mid)
        assertEquals(f.modules[1].id, c.single { it.key == "kc.door" }.mid)
        assertEquals(f.modules[2].id, c.single { it.key == "kc.meter" }.mid)
    }

    @Test fun theHoodNeedsMoreRoomOverGas() {
        val hood = template("hood", ws, "B").copy(elev = worktopTop(ws) + 650)
        val f = pack(f0.copy(modules = listOf(hood)), runs)
        assertTrue(checks(f, runs, ws, emptyList(), emptyList()).none { it.key == "kc.hood" })
        val gas = listOf(SitePoint("g", "gas", "B", 900, 1000))
        val c = checks(f, runs, ws, emptyList(), gas).single { it.key == "kc.hood" }
        assertEquals(650, c.vars["v"]); assertEquals(750, c.vars["n"])
    }

    @Test fun worktopAndAppliancesMakeParts() {
        val f = autoFill(f0, runs, ws, emptyList(), water)
        assertEquals(mapOf("A" to 3400, "B" to 2000), worktopRuns(f))
        assertEquals(2, worktopPieces(f, 4100))
        val dw = partsOf(template("dishwasher", ws, "A"), ws)
        assertEquals(listOf(FPart("fp.panel", dw[0].mod, "front", 717, 597, 1, Bands(2, 2, 2, 2), true)), dw)
        val fl = partsOf(template("fillerLow", ws, "A", 50), ws).single()
        assertEquals(Triple("fp.filler", 720, 50), Triple(fl.key, fl.L, fl.W))
        assertTrue(hardwareOf(template("fridge", ws, "A"), ws).isEmpty())
    }

    @Test fun theWorktopIsPricedByTheMetreAndFridgePanelsStack() {
        val f = autoFill(f0, runs, ws, emptyList(), water)
        val line = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false).lines.single { it.key == "wt38" }
        assertEquals(5.4, line.qty, 1e-9)                      // 3400 on A + 2000 on B
        assertEquals(java.math.BigInteger.valueOf(1_944_000), line.amount)   // 5,4 × 360 000
        val fr = partsOf(template("fridgeB", ws, "A"), ws).filter { it.key == "fp.panel" }
        assertEquals(1, fr.size); assertEquals(2, fr[0].qty)
        assertEquals(597, fr[0].W)                              // full width: the two panels are one above the other
        assertTrue(hardwareOf(template("fridgeB", ws, "A"), ws).keys.none { it.startsWith("hinge") })
    }
}
