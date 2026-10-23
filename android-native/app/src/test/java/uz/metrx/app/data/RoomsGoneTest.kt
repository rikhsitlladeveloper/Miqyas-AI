package uz.metrx.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.elec.ElecDev
import uz.metrx.app.elec.ElecFree
import uz.metrx.app.elec.ElecOrder
import uz.metrx.app.elec.ElecPanel
import uz.metrx.app.elec.ElecRoom
import uz.metrx.app.plumb.PlFix
import uz.metrx.app.plumb.PlPoint
import uz.metrx.app.plumb.PlRiser
import uz.metrx.app.plumb.PlRoom
import uz.metrx.app.plumb.PlumbOrder
import uz.metrx.app.tiles.TSurf
import uz.metrx.app.tiles.TileLayout
import uz.metrx.app.tiles.TileRoom
import uz.metrx.app.win.WinItem
import uz.metrx.app.win.WinOrder

/** Deleting a room takes its trades' data along (and Undo puts it back); older orders lose what was left on deleted rooms. */
class RoomsGoneTest {
    private val a = Room("a", "w1", "Hammom", dims = mapOf("A" to Dim(3000), "B" to Dim(2000), "H" to Dim(2700), "T" to Dim(380)))
    private val b = Room("b", "w2", "Oshxona")
    private val p = Project("p", "T", floors = listOf(Workspace("w1", "Hammom"), Workspace("w2", "Oshxona")), rooms = listOf(a, b),
        tiles = listOf(TileLayout("ta", roomId = "a", surfs = listOf(TSurf("floor"))), TileLayout("tb", roomId = "b"), TileLayout("tf", roomId = null)),
        troom = listOf(TileRoom("a"), TileRoom("b")),
        elec = ElecOrder(listOf(ElecDev("da", "s1", "a", "A", 500, 300), ElecDev("db", "s1", "b", "A", 500, 300)), listOf(ElecRoom("a"), ElecRoom("b")),
            ElecPanel("a", "A", 1000), free = listOf(ElecFree("f"))),
        plumb = PlumbOrder(listOf(PlFix("fa", "wc", "a", "C", 500), PlFix("fb", "sink", "b", "C", 500)), listOf(PlPoint("pa", "cold", "a", "C", 900, 550)),
            listOf(PlRoom("a", "bath"), PlRoom("b", "kitchen")), PlRiser("a", "C", 140)),
        win = WinOrder(listOf(WinItem("wa", "w2", "a", "o1", w = 1260, h = 1360), WinItem("wb", "w2", "b", "o2", w = 1260, h = 1360))))

    @Test fun deletingARoomTakesItsTradesDataAndUndoPutsItBack() {
        val (q, g) = tradesOut(p, setOf("a"))
        assertEquals(listOf("tb", "tf"), q.tiles.map { it.id })
        assertEquals(listOf("b"), q.troom.map { it.roomId })
        assertEquals(listOf("db"), q.elec.devs.map { it.id }); assertEquals(listOf("b"), q.elec.rooms.map { it.roomId }); assertNull(q.elec.panel)
        assertEquals(listOf("fb"), q.plumb.fixes.map { it.id }); assertTrue(q.plumb.points.isEmpty()); assertNull(q.plumb.riser)
        assertEquals(listOf("b"), q.plumb.rooms.map { it.roomId })
        // its window stays, without a room, in a wall as thick as the room's
        val wa = q.win.item("wa")!!
        assertNull(wa.roomId); assertNull(wa.opening); assertEquals(380, wa.freeT); assertEquals(false, wa.fit)
        assertEquals("b", q.win.item("wb")!!.roomId)
        // Undo
        val back = tradesBack(q, g)
        assertEquals(p.tiles.map { it.id }.toSet(), back.tiles.map { it.id }.toSet())
        assertEquals(p.elec.devs.toSet(), back.elec.devs.toSet()); assertEquals(p.elec.panel, back.elec.panel)
        assertEquals(p.plumb.fixes.toSet(), back.plumb.fixes.toSet()); assertEquals(p.plumb.riser, back.plumb.riser)
        assertEquals(p.win.items, back.win.items)
        // another room's data is never touched
        assertEquals(p, tradesOut(p, emptySet()).first)
    }

    @Test fun anOlderOrdersDataOnDeletedRoomsGoesWhenItLoads() {
        val old = p.copy(rooms = listOf(b))
        val q = withoutOrphans(old)
        assertTrue(q.tiles.none { it.roomId == "a" }); assertTrue(q.elec.devs.none { it.roomId == "a" }); assertNull(q.elec.panel); assertNull(q.plumb.riser)
        assertNull(q.win.item("wa")!!.roomId)
        // rooms typed by size are not drawn rooms: kept
        assertEquals(p.elec.free, q.elec.free)
        assertEquals(q, withoutOrphans(q))
    }
}
