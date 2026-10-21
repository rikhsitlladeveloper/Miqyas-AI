package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Furniture without a room (Free.kt): the made-up room, ready models, into a room and out again. */
class FreeTest {
    private val ws = Workshop()

    @Test fun aUKitchenStandsOnItsOwnSizes() {
        val f = newFreeKitchen("Oshxona 1", "U", "U", listOf(2200, 3000, 2400), 0, 2700, ws)
        assertNull(f.roomId)
        assertEquals(listOf("D", "A", "B"), f.walls)
        val r = freeRoom(f)
        assertTrue(isFreeRoom(r))
        assertEquals(3000, r.dim("A").v); assertEquals(2400, r.dim("B").v); assertEquals(2700, r.dim("H").v)
        val runs = runsOf(f) { freeLen(f, it) }
        assertEquals(listOf(2200, 3000, 2400), runs.map { it.len })
        // every lower row is full: the first from its start, the others after the corner
        runs.forEach { run -> assertEquals(run.len!! - run.lowStart, fillOf(f, run, false).used) }
        assertTrue(checks(f, runs, ws, emptyList(), emptyList()).none { it.level == "err" })
        assertEquals(6400, freeRunMm("U", listOf(2200, 3000, 2400), 0))
    }

    @Test fun anIslandKitchenGetsItsIslandUnits() {
        val f = newFreeKitchen("Oshxona 1", "O", "O", listOf(3000), 1800, 2700, ws)
        assertEquals(listOf("A", ISLAND), f.walls)
        assertEquals(listOf(600, 600, 600), f.modules.filter { it.wall == ISLAND }.map { it.w })
        assertEquals(listOf(0, 600, 1200), f.modules.filter { it.wall == ISLAND }.map { it.x })
        assertEquals(4800, freeRunMm("O", listOf(3000), 1800))
    }

    @Test fun anOpenShelfHasNoDoors() {
        val f = newFreeWardrobe("Shkaf 1", "op", 1200, 2000, 400, false, "open", ws)
        val m = wardOfF(f)!!
        assertEquals(2, m.sections.size)
        assertTrue(m.sections.all { it.fronts.kind == "open" && it.inserts.count { x -> x.kind == "shelf" } == 4 })
        assertEquals(1200 + 2 * W_GAP_SIDE, freeRoom(f).dim("A").v)
        assertTrue(wardrobeChecks(m, freeRoom(f).dim("A").v, freeRoom(f).dim("H").v, ws, emptyList(), emptyList()).none { it.level == "err" })
    }

    @Test fun placingAnLKitchenOnTooShortAWallSaysSoAndFits() {
        val f = newFreeKitchen("Oshxona 1", "L", "L", listOf(3000, 2000), 0, 2700, ws)
        val lens = mapOf("A" to 3400, "B" to 1800, "C" to 3400, "D" to 1800)
        val ids = listOf("A", "B", "C", "D")
        val walls = placeWalls(f, ids, "A")
        assertEquals(listOf("A", "B"), walls)
        val iss = fitIssues(f, walls, { lens[it] }, 2500, ws)
        assertEquals(listOf("fz.long"), iss.map { it.key })
        assertEquals(200, iss[0].vars["d"])                      // side 2 is 2000 on wall B 1800
        // on D the next side turns onto A
        assertEquals(listOf("D", "A"), placeWalls(f, ids, "D"))
        val p = fitTo(placed(f, walls, "r1", "w1"), walls, { lens[it] }, 2500, ws)
        assertEquals("r1", p.roomId); assertEquals("w1", p.ws)
        val runs = runsOf(p) { lens[it] }
        assertTrue(checks(p, runs, ws, emptyList(), emptyList()).none { it.level == "err" })
        assertEquals(1200, fillOf(p, runs[1], false).used)       // 1800 less the corner
    }

    @Test fun aWardrobeTooTallIsLoweredUnderTheCeiling() {
        val f = newFreeWardrobe("Shkaf 1", "h3", 1500, 2600, 600, false, "door", ws)
        val iss = fitIssues(f, listOf("B"), { 2000 }, 2500, ws)
        assertEquals(listOf("fz.high"), iss.map { it.key })
        val p = fitTo(placed(f, listOf("B"), "r1", "w1", off = 300), listOf("B"), { 2000 }, 2500, ws, off = 300)
        val m = wardOfF(p)!!
        assertEquals("B", m.wall); assertEquals(300, m.x)
        assertTrue(outerH(m, ws) <= 2500 - W_GAP_TOP)
        assertTrue(wardrobeChecks(m, 2000, 2500, ws, emptyList(), emptyList()).none { it.level == "err" })
    }

    @Test fun aCornerKitchenOnALongerFirstWallEndsInTheCorner() {
        val f = newFreeKitchen("Oshxona 1", "L", "L", listOf(3000, 2000), 0, 2700, ws)
        val lens = mapOf("A" to 3400, "B" to 2600, "C" to 3400, "D" to 2600)
        val p = placed(f, listOf("A", "B"), "r1", "w1", len = { lens[it] })
        val lowA = p.modules.filter { it.wall == "A" && !isUpper(it) }
        assertEquals("space", lowA.first().app); assertEquals(400, lowA.first().w); assertEquals(0, lowA.first().x)
        assertEquals(400, lowA[1].x)                              // the units follow, the last one in the corner
        val runs = runsOf(p) { lens[it] }
        assertEquals(Fill(3400, 3400), fillOf(p, runs[0], false))
        assertEquals(5000 - 600, runMm(p))                       // the empty stretch is not priced
        val out = takenOut(p, { lens[it] }, 2500)
        assertEquals(listOf(3000, 2000), out.free!!.sides)
        assertTrue(out.modules.none { it.app == "space" })
    }

    @Test fun takenOutKeepsWhatIsOnTheWalls() {
        val f = newFreeKitchen("Oshxona 1", "L", "L", listOf(3000, 2000), 0, 2700, ws)
        val lens = mapOf("A" to 3400, "B" to 2600, "C" to 3400, "D" to 2600)
        val inRoom = placed(f, listOf("C", "D"), "r1", "w1")
        assertTrue(inRoom.modules.all { it.wall == "C" || it.wall == "D" })
        val out = takenOut(inRoom, { lens[it] }, 2500)
        assertNull(out.roomId); assertEquals("", out.ws)
        assertEquals(listOf("A", "B"), out.walls)
        assertEquals(listOf(3000, 2000), out.free!!.sides)
        assertEquals(2500, out.free!!.h)
        assertEquals(f.modules.size, out.modules.size)
    }

    @Test fun sectionsNeverGoBelowNothing() {
        // one section is the whole wardrobe, locked or not
        assertEquals(listOf(1800), splitSections(1800, listOf(Section(600, lock = true))).map { it.w })
        // locked ones that no longer fit give way: all share again
        val s = splitSections(1000, listOf(Section(900, lock = true), Section(900, lock = true), Section(300)))
        assertTrue(s.all { it.w >= 150 && !it.lock }); assertEquals(1000, s.sumOf { it.w })
        // a fit with the wardrobe far from the corner still keeps 300 mm
        val f = newFreeWardrobe("Shkaf 1", "h3", 1500, 2200, 600, false, "door", ws)
        val p = fitTo(placed(f, listOf("B"), "r1", "w1", off = 1900), listOf("B"), { 2000 }, 2500, ws, off = 1900)
        assertTrue(wardOfF(p)!!.w >= 300)
    }
}
