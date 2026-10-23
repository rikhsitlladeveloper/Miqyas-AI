package uz.metrx.app.elec

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.Workspace

/** The electrician's fixes of 23 Oct 2026: gofra rises, typed rooms' power points, the water heater's socket, a panel left on a deleted room. */
class ElecFixesTest {
    private fun dims(a: Int, b: Int, h: Int = 2700) = mapOf("A" to Dim(a), "B" to Dim(b), "H" to Dim(h), "T" to Dim(200, "default"))
    private val hall = Room("h", "wh", "Koridor", dims = dims(3000, 2000), openings = listOf(Opening("he", "door", "A", 900, 2100, 300), Opening("hk", "door", "B", 800, 2100, 600)))
    private val kitchen = Room("k", "wk", "Oshxona", dims = dims(4000, 3000), openings = listOf(Opening("kd", "door", "A", 800, 2100, 200)))
    private fun project(devs: List<ElecDev>, method: String, free: List<ElecFree> = emptyList()) =
        Project("p", "T", floors = listOf(Workspace("wh", "Koridor", "room"), Workspace("wk", "Oshxona", "kitchen")), rooms = listOf(hall, kitchen), industry = "elec",
            elec = ElecOrder(devs, listOf(ElecRoom("k", "kitchen")), ElecPanel("h", "A", 1600), method, free))
    private val devs = listOf(ElecDev("l1", "lc", "h", null, cx = 1500, cy = 1000), ElecDev("s1", "s1", "h", "C", 1000, 300), ElecDev("s2", "s1", "k", "B", 1000, 300),
        ElecDev("st", "pst", "k", "B", 2000, 600))

    @Test fun inGofraEveryCircuitHasItsOwnRise() {
        val p = project(devs, "gofra")
        val calc = calcOf(p, true)
        val rises = calc.routes.runs.sumOf { it.rise }
        val ceil = calc.routes.runs.sumOf { it.ceil }
        assertTrue(calc.routes.runs.count { it.rise > 0 } > 1)
        assertEquals((ceil + rises) / 1000, calc.count.gofraM, 1e-9)
        assertTrue(rises > calc.routes.runs.maxOf { it.rise })
    }

    @Test fun aTypedKitchenKeepsItsStoveAndOvenLines() {
        val k = kitOf("kt.std")!!
        val f = freeOf(k, defaultOpts(k), "x", "Oshxona", 3500, 3000, 2700)
        assertEquals(listOf("pst", "pov"), f.powers)
        val p = project(emptyList(), "chase", free = listOf(f))
        val c = ctxs(p, true).single { it.free != null }
        val ds = devsIn(p, c)
        val st = ds.single { it.t == "pst" }; val ov = ds.single { it.t == "pov" }
        assertEquals(600, st.h); assertEquals(600, ov.h)
        assertTrue(ds.none { it.t == "pac" })
        // the stove on its own 32 A line of 6 mm²
        val cc = calcOf(p, true).circuits.single { it.group == "stove" }
        assertEquals(32, cc.amps); assertEquals("6", cc.cable)
        // an older typed room (no types kept) takes its kit's again; one without a kit gives its power points as AC lines
        val old = f.copy(powers = emptyList())
        val po = project(emptyList(), "chase", free = listOf(old))
        assertEquals(listOf("pst", "pov"), devsIn(po, ctxs(po, true).single { it.free != null }).filter { it.t == "pst" || it.t == "pov" }.map { it.t })
        val bare = old.copy(kit = "")
        val pb = project(emptyList(), "chase", free = listOf(bare))
        assertTrue(devsIn(pb, ctxs(pb, true).single { it.free != null }).count { it.t == "pac" } == 2)
    }

    @Test fun aBathroomsHeaterSocketIsNotASplashWarningAndTypedBathSocketsAreSplashProof() {
        val k = kitOf("bt.std")!!
        val f = freeOf(k, defaultOpts(k), "b", "Hammom", 2500, 2000, 2700)
        assertEquals(listOf("pwh"), f.powers)
        val p = project(emptyList(), "chase", free = listOf(f))
        val c = ctxs(p, true).single { it.free != null }
        val ds = devsIn(p, c)
        assertTrue(ds.filter { devType(it.t).group == "sock" }.all { it.t == "sw" })
        val ws = devWarnings(c, ds)
        assertTrue(ws.none { w -> w.key == "el.w.splash" && ds.first { it.id == w.devId }.t == "pwh" })
        assertTrue(ws.none { it.key == "el.w.splash" })
    }

    @Test fun aPanelOnADeletedRoomCountsAsNone() {
        val p = project(devs, "chase")
        assertEquals("h", livePanel(p)?.roomId)
        val gone = p.copy(rooms = listOf(kitchen))
        assertNull(livePanel(gone))
        assertTrue(warningsOf(gone, ctxs(gone, true), circuitsOf(gone, ctxs(gone, true))).any { it.key == "el.w.noPanel" })
    }

    @Test fun aKitSaysHowManyPointsItWants() {
        val p = project(emptyList(), "chase")
        val c = ctxOf(p, "k", true)!!
        val k = kitOf("kt.spots")!!
        val want = kitWanted(k, c)
        val got = placeKit(k, c, emptyList(), { "x" + (Math.random() * 1e9).toLong() })
        assertTrue(got.size <= want)
        assertTrue(want >= spotGrid(c).size + 4)
    }
}
