package uz.metrx.app.trades

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.InnerWall
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace

/**
 * Final check, 28 Oct 2026: a door in an inner partition is inside the room, so the electrician's cables and the
 * plumber's pipes never come in or leave by it, even when it was placed before the room's own door.
 */
class InnerWallTradesTest {
    private val room = Room("r", "w", "Mehmonxona",
        dims = mapOf("A" to Dim(4000, "manual"), "B" to Dim(3000, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")),
        // the partition's door first, the room's own door on wall C after it
        openings = listOf(Opening("di", "door", "E", 800, 2100, 500).copy(fk = "p1:0"), Opening("dc", "door", "C", 900, 2100, 600)),
        inner = listOf(InnerWall("p1", "straight", 2000, 1500, 0, 2000)))
    private val p = Project("p", "QA", floors = listOf(Workspace("w", "Mehmonxona", "room")), rooms = listOf(room))

    @Test fun anInnerDoorIsNotTheElectriciansEntry() {
        val c = uz.metrx.app.elec.ctxOf(p, "r", true)!!
        assertEquals(listOf("dc"), c.doors.map { it.id })
        assertEquals("dc", c.entry?.id)
    }

    @Test fun anInnerDoorIsNotThePlumbersWayInButFixturesStillKeepOutOfItsSwing() {
        val c = uz.metrx.app.plumb.ctxOf(p, "r", true)!!
        assertEquals("dc", c.entry?.id)
        assertEquals(listOf("dc"), c.ways.map { it.id })
        assertTrue(c.doors.any { it.id == "di" })
    }
}
