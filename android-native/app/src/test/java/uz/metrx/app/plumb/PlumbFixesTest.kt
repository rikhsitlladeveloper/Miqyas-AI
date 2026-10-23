package uz.metrx.app.plumb

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace

/** The plumber's fixes of 23 Oct 2026: the riser's sets, heating alone, manifolds, typed rooms' choices and small typed rooms. */
class PlumbFixesTest {
    private fun dims(a: Int, b: Int, h: Int = 2700) = mapOf("A" to Dim(a), "B" to Dim(b), "H" to Dim(h), "T" to Dim(200, "default"))
    private val bath = Room("b", "wb", "Hammom", dims = dims(2600, 2000), openings = listOf(Opening("bd", "door", "A", 700, 2100, 200)))
    private val living = Room("l", "wl", "Mehmonxona", dims = dims(4000, 3500), openings = listOf(Opening("ld", "door", "A", 800, 2100, 200)))
    private fun project(fixes: List<PlFix>, riser: PlRiser?, free: List<PlFree> = emptyList(), rooms: List<PlRoom> = emptyList()) =
        Project("p", "T", floors = listOf(Workspace("wb", "Hammom", "bath"), Workspace("wl", "Mehmonxona", "room")), rooms = listOf(bath, living), industry = "plumb",
            plumb = PlumbOrder(fixes, emptyList(), rooms, riser, free = free))
    private fun fix(t: String, room: String, wall: String, off: Int, w: Int = 0) = PlFix("x$t$off", t, room, wall, off, w, pts = defaultPts(t, w))
    private val riser = PlRiser("b", "C", 140)

    @Test fun theRisersHotSetOnlyWhenTheHotComesUpIt() {
        val wet = listOf(fix("bs", "b", "C", 1490), fix("wc", "b", "C", 970))
        assertEquals(2, calcOf(project(wet, riser), true).count.meters)
        // hot water from a gas boiler: one set, for the cold
        val gb = calcOf(project(wet + fix("gb", "b", "D", 1000), riser), true).count
        assertEquals(1, gb.meters); assertEquals(1, gb.filters); assertEquals(1, gb.mainValves)
    }

    @Test fun heatingAloneHasNoRiserAndBuysNoRiserParts() {
        val rads = listOf(fix("rad", "l", "C", 2000, 800), fix("gb", "l", "D", 1500))
        // a gas boiler needs cold water; radiators alone do not
        assertFalse(needsRiser(project(listOf(fix("rad", "l", "C", 2000, 800)), null)))
        assertTrue(needsRiser(project(rads, null)))
        val onlyRad = calcOf(project(listOf(fix("rad", "l", "C", 2000, 800)), riser), true).count
        assertEquals(0, onlyRad.meters); assertEquals(0, onlyRad.mainValves)
        assertTrue(calcOf(project(listOf(fix("rad", "l", "C", 2000, 800)), null), true).warns.none { it.key == "sx.w.noRiser" })
    }

    @Test fun eachManifoldPlacedIsCountedAndFeedsItsOwnRoom() {
        val fs = listOf(fix("manif", "b", "D", 1000), fix("manif", "l", "B", 1500))
        val p = project(fs, riser, rooms = listOf(PlRoom("b", "bath", ufh = true), PlRoom("l", "room", ufh = true)))
        val c = calcOf(p, true)
        assertEquals(2, c.count.manifolds)
        // each room's leads from its own manifold: the living room's are not run from the bathroom
        val one = calcOf(project(listOf(fs[0]), riser, rooms = listOf(PlRoom("b", "bath", ufh = true), PlRoom("l", "room", ufh = true))), true)
        assertTrue(c.routes.loops.first { it.roomId == "l" }.total < one.routes.loops.first { it.roomId == "l" }.total)
    }

    @Test fun aTypedRoomKeepsItsKitsChoices() {
        val k = pkitOf("bt.bath")!!
        val f = freeOf(k, k.opts.copy(tr = true), "f", "Hammom", 2600, 2000, 2700)
        assertEquals(1, f.tr)
        val wc = pkitOf("wc.basin")!!
        val h = freeOf(wc, wc.opts, "h", "Hojatxona", 1500, 1200, 2700)
        assertTrue(h.small)
        val p = Project("p", "T", industry = "plumb", plumb = PlumbOrder(free = listOf(f, h)))
        val cs = ctxs(p, true)
        assertTrue(fixesIn(p, cs.first { it.free?.id == "f" }).any { it.t == "tr" })
        assertTrue(fixesIn(p, cs.first { it.free?.id == "h" }).any { it.t == "bsm" })
        assertTrue(fixesIn(p, cs.first { it.free?.id == "h" }).none { it.t == "bs" })
    }

    @Test fun aSmallTypedRoomStillCountsWhatFitsAndSaysWhatDoesNot() {
        val k = pkitOf("bt.bath")!!
        val f = freeOf(k, k.opts, "x", "Hammom", 1200, 1000, 2700)
        val p = Project("p", "T", industry = "plumb", plumb = PlumbOrder(free = listOf(f)))
        val fs = fixesIn(p, ctxs(p, true).single())
        assertTrue(fs.any { it.t == "wc" })
        val calc = calcOf(p, true)
        assertTrue(calc.count.fixtures > 0)
        assertTrue(calc.warns.any { it.key == "sx.w.noFit" && it.vars["t"] == "~sx.t.bath" })
    }

    @Test fun aRiserOnADeletedRoomCountsAsNone() {
        val p = project(listOf(fix("wc", "b", "C", 970)), riser)
        assertEquals("b", liveRiser(p)?.roomId)
        assertNull(liveRiser(p.copy(rooms = listOf(living))))
    }
}
