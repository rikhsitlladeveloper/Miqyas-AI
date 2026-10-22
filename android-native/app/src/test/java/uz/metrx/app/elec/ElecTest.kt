package uz.metrx.app.elec

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint
import uz.metrx.app.data.Workspace
import uz.metrx.app.trades.TradeSet

/**
 * The electrician's devices, circuits and routes on two rooms: a hallway 3 × 2 × 2,7 m with the entrance door on wall
 * A (900 at 300) and the kitchen's doorway on wall B (800 at 600), and a kitchen 4 × 3 × 2,7 m with its door on wall A
 * (800 at 200), a window on wall C (1200 × 1400 at 900, 1400 from C's start) and a sink's cold water on wall C.
 */
class ElecTest {
    private fun dims(a: Int, b: Int, h: Int = 2700) = mapOf("A" to Dim(a), "B" to Dim(b), "H" to Dim(h), "T" to Dim(200, "default"))
    private val hall = Room("h", "wh", "Koridor", dims = dims(3000, 2000), openings = listOf(
        Opening("he", "door", "A", 900, 2100, 300), Opening("hk", "door", "B", 800, 2100, 600)))
    private val kitchen = Room("k", "wk", "Oshxona", dims = dims(4000, 3000), openings = listOf(
        Opening("kd", "door", "A", 800, 2100, 200), Opening("kw", "window", "C", 1200, 1400, 1400, 900)),
        points = listOf(SitePoint("cw", "cold", "C", 2900, 550)))
    private fun project(devs: List<ElecDev> = emptyList(), panel: ElecPanel? = null, method: String = "chase", free: List<ElecFree> = emptyList(), rooms: List<ElecRoom> = emptyList()) =
        Project("p", "Test", floors = listOf(Workspace("wh", "Koridor", "room"), Workspace("wk", "Oshxona", "kitchen")), rooms = listOf(hall, kitchen), industry = "elec",
            elec = ElecOrder(devs, rooms, panel, method, free))
    private var n = 0
    private fun id() = "d${n++}"

    @Test fun kitPlacesClearOfDoorsWindowsAndWater() {
        val p = project(rooms = listOf(ElecRoom("k", "kitchen")))
        val c = ctxOf(p, "k", true)!!
        assertEquals("kitchen", c.kind)
        val ds = placeKit(kitOf("kt.std")!!, c, emptyList(), ::id)
        assertTrue(ds.size >= 9)
        // no wall device on an opening (with its frame)
        for (d in ds.filter { !it.onCeiling }) {
            val (dw, dh) = devSize(d)
            val bad = c.room.openings.any { o -> o.wall == d.wall && d.off + dw / 2.0 > o.off - 100 && d.off - dw / 2.0 < o.off + o.w + 100 && d.h + dh / 2.0 > o.sill && d.h - dh / 2.0 < o.sill + o.h }
            assertFalse("${d.t} at ${d.wall} ${d.off}/${d.h}", bad)
        }
        // the switch beside the door on its latch side, at 900
        val sw = ds.first { it.t == "k2" }
        assertEquals("A", sw.wall); assertEquals(900, sw.h); assertTrue(sw.off > 200 + 800)
        // worktop sockets over the worktop on the sink's wall, none within 60 cm of the water
        val work = ds.filter { it.t == "s2" }
        assertEquals(3, work.size)
        assertTrue(work.all { it.h == 1100 && it.wall == "C" })
        assertTrue(devWarnings(c, ds).none { it.key == "el.w.water" || it.key == "el.w.open" || it.key == "el.w.door" })
        // the ceiling light in the middle
        val lc = ds.first { it.t == "lc" }
        assertEquals(2000, lc.cx); assertEquals(1500, lc.cy)
    }

    @Test fun snapsToUsualHeightsAndOffOpenings() {
        val p = project()
        val c = ctxOf(p, "k", true)!!
        val s = ElecDev("s", "s1", "k", "B", 1500, 300)
        assertEquals(300, snapWall(c, s, 1500, 330, emptyList()).second)
        assertEquals(700, snapWall(c, s, 1500, 700, emptyList()).second)
        val k = ElecDev("w", "k1", "k", "B", 1500, 900)
        assertEquals(900, snapWall(c, k, 1500, 870, emptyList()).second)
        assertEquals(1100, snapWall(c, ElecDev("x", "s2", "k", "B", 1500, 1100), 1500, 1080, emptyList()).second)
        // dragged onto the door: put beside it
        val (off, _) = snapWall(c, k.copy(wall = "A"), 600, 900, emptyList())
        assertTrue(off < 200 - 43 || off > 1000 + 43)
        // lined up with another device on the wall
        assertEquals(2010, snapWall(c, s, 2050, 300, listOf(ElecDev("o", "s1", "k", "B", 2010, 300))).first)
    }

    @Test fun routeLengthOnAKnownRoom() {
        // the panel in the kitchen on wall B at 1500 (top at 1600 + 210), one socket on wall B at 2500, 300 up
        val dev = ElecDev("s", "s1", "k", "B", 2500, 300)
        val p = project(listOf(dev), ElecPanel("k", "B", 1500, 1600))
        val cs = ctxs(p, true)
        val rt = routesOf(p, cs)
        val cc = rt.circuits.single()
        assertEquals("kitch", cc.group)
        val zone = 2700.0 - ZONE_DOWN
        val rise = zone - (1600 + 210)
        val run = 1000.0
        val drop = zone - (300 + 43)
        assertEquals(rise + run + drop + TAIL + TAIL, rt.cableOf(cc), 1e-6)
        // in pipe over the ceiling: up to the ceiling, across, down
        val g = routesOf(project(listOf(dev), ElecPanel("k", "B", 1500, 1600), "gofra"), cs)
        assertEquals((2700.0 - 1810) + 1000 + (2700 - 343) + 2 * TAIL, g.cableOf(g.circuits.single()), 1e-6)
    }

    @Test fun routesCrossRoomsThroughTheDoors() {
        // the panel in the hallway on wall A at 1600; the kitchen's socket on its wall B at 1000
        val dev = ElecDev("s", "s1", "k", "B", 1000, 300)
        val p = project(listOf(dev), ElecPanel("h", "A", 1600, 1600, "he"), rooms = listOf(ElecRoom("k", "kitchen", link = 1500)))
        val cs = ctxs(p, true)
        val rt = routesOf(p, cs)
        val cc = rt.circuits.single()
        assertEquals("kitch", cc.group)
        assertEquals(listOf("k", "h"), rt.runs.map { it.roomId })
        val zone = 2700.0 - ZONE_DOWN
        // hallway: up from the panel, round to the kitchen doorway on wall B (centre 1000): 1400 on A, then 1000 on B
        val hallPart = (zone - 1810) + (3000 - 1600) + 1000
        // kitchen: from its door's centre on A (600) round the corner to B at 1000: 3400 + 1000, then down to the socket
        val kitPart = (4000 - 600.0) + 1000 + (zone - 343) + TAIL + 1500
        assertEquals(hallPart, rt.runs.first { it.roomId == "h" }.len, 1e-6)
        assertEquals(kitPart, rt.runs.first { it.roomId == "k" }.len, 1e-6)
        assertEquals(hallPart + kitPart + TAIL, rt.cableOf(cc), 1e-6)
        // the hallway's exit door is the kitchen's doorway, not the entrance
        assertEquals("hk", exitDoor(cs.first { it.id == "h" }, p.elec.panel!!, ElecRoom("k"))!!.id)
    }

    @Test fun circuitsAndBreakers() {
        val ds = listOf(
            ElecDev("l1", "lc", "h", null, cx = 1500, cy = 1000), ElecDev("k1", "k1", "h", "A", 1500, 900),
            ElecDev("l2", "lc", "k", null, cx = 2000, cy = 1500), ElecDev("s1", "s1", "h", "D", 1000, 300),
            ElecDev("s2", "s2", "k", "C", 600, 1100), ElecDev("s3", "s2", "k", "C", 1000, 1100),
            ElecDev("st", "pst", "k", "B", 1500, 600), ElecDev("ac", "pac", "h", "D", 500, 2400), ElecDev("tv", "tv", "h", "C", 1000, 1100))
        val p = project(ds, ElecPanel("h", "A", 1600), rooms = listOf(ElecRoom("h", "hall"), ElecRoom("k", "kitchen")))
        val calc = calcOf(p, true)
        assertEquals(listOf("light", "sock", "kitch", "stove", "ac", "low"), calc.circuits.map { it.group })
        assertEquals(listOf(1, 2, 3, 4, 5, 6), calc.circuits.map { it.no })
        val c = calc.count
        assertEquals(mapOf(10 to 1, 16 to 3, 32 to 1), c.breakers)
        assertEquals(1, c.rcds)                         // the kitchen's sockets
        assertEquals(5 + 2 + 2, c.modules)               // breakers, the RCD, the main switch
        assertEquals(12, c.panelModules)
        assertEquals(listOf("1.5", "2.5", "6", "utp"), c.cables.map { it.type })
        assertTrue(c.cables.all { it.coils == coilsFor(it.withSpare) && it.withSpare > it.m })
    }

    @Test fun coilsAndPanelSizes() {
        assertEquals(0, coilsFor(0.0)); assertEquals(1, coilsFor(99.9)); assertEquals(1, coilsFor(100.0)); assertEquals(2, coilsFor(100.5))
        assertEquals(12, panelFor(10)); assertEquals(18, panelFor(11)); assertEquals(24, panelFor(20)); assertEquals(0, panelFor(0))
        assertEquals(0.0 to 0.0, cover(10.0, 0.0, emptyList()))
        // both ways round is shorter than all the way one way
        assertEquals(1.0 to 2.0, cover(10.0, 0.0, listOf(1.0, 8.0)))
        assertEquals(3.0, unionLen(listOf(0.0 to 2.0, 1.0 to 3.0), 10.0), 1e-9)
        assertEquals(3.0, unionLen(listOf(-1.0 to 2.0), 10.0), 1e-9)
    }

    @Test fun warnings() {
        val p = project(rooms = listOf(ElecRoom("k", "kitchen")))
        val c = ctxOf(p, "k", true)!!
        // a socket 40 cm from the sink's water, a switch behind the door's swing (hinge at 200), one on the window
        val near = ElecDev("n", "s1", "k", "C", 2900, 950)
        val behind = ElecDev("b", "k1", "k", "A", 100, 900)
        val onWin = ElecDev("o", "s1", "k", "C", 1600, 1000)
        val ws = devWarnings(c, listOf(near, behind, onWin))
        assertTrue(ws.any { it.key == "el.w.water" && it.devId == "n" })
        assertTrue(ws.any { it.key == "el.w.door" && it.devId == "b" })
        assertTrue(ws.any { it.key == "el.w.open" && it.devId == "o" })
        // the latch side is fine
        assertTrue(devWarnings(c, listOf(ElecDev("ok", "k1", "k", "A", 1200, 900))).isEmpty())
        // a bathroom: an ordinary socket is in the splash zone, a waterproof one 1 m from the water is not
        val pb = project(rooms = listOf(ElecRoom("k", "bath")))
        val cb = ctxOf(pb, "k", true)!!
        assertTrue(devWarnings(cb, listOf(ElecDev("a", "s1", "k", "B", 1500, 1100))).any { it.key == "el.w.splash" })
        assertTrue(devWarnings(cb, listOf(ElecDev("a", "sw", "k", "B", 1500, 1100))).isEmpty())
        assertTrue(devWarnings(cb, listOf(ElecDev("a", "sw", "k", "C", 2600, 700))).any { it.key == "el.w.splash" })
        // too much for its breaker: a 4 kW socket on a 16 A line; and too many sockets on one circuit
        val heavy = project(listOf(ElecDev("h", "s1", "h", "D", 1000, 300, w = 4000)), ElecPanel("h", "A", 1600))
        assertTrue(calcOf(heavy, true).warns.any { it.key == "el.w.load" })
        val many = project((0 until 11).map { ElecDev("m$it", "s1", "k", "B", 300 + it * 220, 300) }, ElecPanel("h", "A", 1600), rooms = listOf(ElecRoom("k", "bed")))
        assertTrue(calcOf(many, true).warns.any { it.key == "el.w.points" })
        // no panel
        assertTrue(calcOf(project(listOf(ElecDev("s", "s1", "k", "B", 1000, 300))), true).warns.any { it.key == "el.w.noPanel" })
    }

    @Test fun roomWithoutAPlan() {
        val f = ElecFree("f", "Yotoqxona", "bed", 4000, 3000, 2700, sock = 5, sw = 1, light = 1, low = 1, power = 1, link = 4000)
        val p = Project("p", "T", industry = "elec", elec = ElecOrder(free = listOf(f)))
        val cs = ctxs(p, true)
        assertEquals(1, cs.size)
        val ds = devsIn(p, cs[0])
        assertEquals(5, ds.count { it.t == "s1" }); assertEquals(1, ds.count { it.t == "k1" }); assertEquals(1, ds.count { it.t == "lc" })
        assertEquals(1, ds.count { it.t == "lan" }); assertEquals(1, ds.count { it.t == "pac" })
        val calc = calcOf(p, true)
        assertEquals(listOf("light", "sock", "ac", "low"), calc.circuits.map { it.group })
        // each circuit's cable reaches the door and the 4 m to the panel
        assertTrue(calc.circuits.all { calc.routes.cableOf(it) > 4000 })
        assertTrue(calc.count.cableM > 16)
        // a kit's counts for a room typed by size
        val k = freeOf(kitOf("kt.std")!!, defaultOpts(kitOf("kt.std")!!), "x", "Oshxona", 3500, 3000, 2700)
        assertEquals(6, k.sock); assertEquals(1, k.sw); assertEquals(2, k.power); assertEquals("kitchen", k.kind)
    }

    @Test fun estimateRows() {
        val ds = listOf(ElecDev("l1", "lc", "h", null, cx = 1500, cy = 1000), ElecDev("k1", "k1", "h", "A", 1500, 900), ElecDev("s1", "s1", "k", "B", 1000, 300),
            ElecDev("st", "pst", "k", "B", 2000, 600))
        val p = project(ds, ElecPanel("h", "A", 1600), rooms = listOf(ElecRoom("k", "kitchen")))
        val r = elecRows(p, TradeSet(), true) { k, v -> k + v.entries.joinToString("") { "|" + it.key + "=" + it.value } }
        assertTrue((r.mats + r.labor).all { it.id.startsWith("t-") })
        val cab = r.mats.filter { it.name.startsWith("el.e.cab") }
        assertEquals(3, cab.size)
        assertTrue(cab.all { it.qty.toInt() % 100 == 0 })
        assertTrue(r.mats.any { it.name == "el.e.brk|a=32" && it.qty == "1" })
        assertTrue(r.mats.any { it.name == "el.e.rcd" && it.qty == "1" })
        assertTrue(r.mats.any { it.name.startsWith("el.e.panel") && it.price == (12000 * 12).toString() })
        assertTrue(r.labor.any { it.name == "el.e.lPts|n=4" && it.amount == (4 * 60000).toString() })
        assertTrue(r.labor.any { it.name.startsWith("el.e.lChase") })
        assertEquals(4.0, r.facts["points"]!!, 0.0)
    }

    @Test fun takesInTheRoomsSocketsAndSwitches() {
        val r = kitchen.copy(points = kitchen.points + SitePoint("x", "socket", "B", 1200, 300) + SitePoint("y", "switch", "A", 1200, 900))
        val p = project().copy(rooms = listOf(hall, r))
        val c = ctxOf(p, "k", true)!!
        val got = fromSitePoints(c, ::id)
        assertEquals(listOf("s1", "k1"), got.map { it.t })
        assertEquals(listOf("x", "y"), got.map { it.from })
        assertNull(ctxOf(p.copy(rooms = listOf(hall.copy(dims = mapOf("A" to Dim(3000))))), "h", true))
        assertNotNull(defaultPanel(p.copy(elec = ElecOrder(rooms = listOf(ElecRoom("h", "hall")))), true)?.takeIf { it.roomId == "h" && it.wall == "A" })
    }
}
