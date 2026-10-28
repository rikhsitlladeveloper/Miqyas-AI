package uz.metrx.app.trades

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.InnerWall
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace
import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecOrder
import uz.metrx.app.elec.ElecPanel
import uz.metrx.app.elec.Perim
import uz.metrx.app.plumb.PlPoint
import uz.metrx.app.plumb.PlRiser
import uz.metrx.app.plumb.PlumbOrder

/**
 * Final check, 28 Oct 2026: inner partitions in the electrician's and plumber's numbers. A door in a partition is
 * inside the room, so cables and pipes never come in or leave by it; a socket or a water point on a partition's face
 * is reached from the outer wall where the partition meets it, and that way across and along it is counted.
 */
class InnerWallTradesTest {
    private val dims = mapOf("A" to Dim(4000, "manual"), "B" to Dim(3000, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default"))
    private val room = Room("r", "w", "Mehmonxona", dims = dims,
        // the partition's door first, the room's own door on wall C after it
        openings = listOf(Opening("di", "door", "E", 800, 2100, 500).copy(fk = "p1:0"), Opening("dc", "door", "C", 900, 2100, 600)),
        inner = listOf(InnerWall("p1", "straight", 2000, 1500, 0, 2000)))
    private val p = Project("p", "QA", floors = listOf(Workspace("w", "Mehmonxona", "room")), rooms = listOf(room))

    /** A partition across the room from wall A to wall C, 2 000 mm in. */
    private val split = Room("s", "w", "Hammom", dims = dims, openings = listOf(Opening("sd", "door", "D", 800, 2100, 1000)),
        inner = listOf(InnerWall("p2", "straight", 2000, 1500, 90, 3000)))

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

    @Test fun aPointOnAPartitionIsReachedFromTheWallItMeets() {
        val c = uz.metrx.app.elec.ctxOf(Project("p", "QA", rooms = listOf(split)), "s", true)!!
        val per = Perim(c)
        val face = c.g.inner.first()
        val sp = per.spur(face.id, 1000.0)
        assertNotNull(sp)
        // the nearer end is on an outer wall, so the way is the 1 000 mm along the face (give or take the wall's ends)
        assertEquals(1000.0, sp!!.len, 60.0)
        assertTrue(kotlin.math.abs(sp.at.y) < 1 || kotlin.math.abs(sp.at.y - 3000) < 1)
        assertEquals(sp.s, per.s(face.id, 1000.0), 1e-9)
        assertEquals(null, per.spur("A", 100.0))
    }

    @Test fun theElectriciansCableGoesAcrossAndAlongThePartition() {
        val face = uz.metrx.app.elec.ctxOf(Project("p", "QA", rooms = listOf(split)), "s", true)!!.g.inner.first().id
        fun cable(wall: String, off: Int): Pair<Double, Double> {
            val d = ElecDev("s1", "s1", "s", wall, off, 300)
            val q = Project("p", "QA", rooms = listOf(split), industry = "elec", elec = ElecOrder(listOf(d), panel = ElecPanel("s", "D", 300), method = "chase"))
            val calc = uz.metrx.app.elec.calcOf(q, true)
            return calc.routes.runs.single().drops.getValue("s1") to calc.count.chaseM
        }
        val (onFace, chase) = cable(face, 1000)
        val (onA, _) = cable("A", 1000)
        // the drop as on an outer wall, plus about a metre across and along the partition, chased too
        assertEquals(onA + 1000, onFace, 60.0)
        assertTrue(chase * 1000 >= onFace)
    }

    @Test fun thePlumbersPipesGoAcrossAndAlongThePartition() {
        val face = uz.metrx.app.plumb.ctxOf(Project("p", "QA", rooms = listOf(split)), "s", true)!!.g.inner.first().id
        fun calc(wall: String) = uz.metrx.app.plumb.calcOf(Project("p", "QA", rooms = listOf(split), industry = "plumb",
            plumb = PlumbOrder(points = listOf(PlPoint("c", "cold", "s", wall, 1000, 550), PlPoint("d", "drain", "s", wall, 1000, 400, 50)), riser = PlRiser("s", "D", 300))), true)
        val inner = calc(face); val outer = calc("A")
        val cold = { c: uz.metrx.app.plumb.PlumbCalc -> c.routes.runs.single { it.kind == "cold" }.drops }
        assertEquals(cold(outer) + 1000, cold(inner), 60.0)
        val dr = { c: uz.metrx.app.plumb.PlumbCalc -> c.routes.drains.single() }
        assertTrue(dr(inner).horiz > 900)
    }
}
