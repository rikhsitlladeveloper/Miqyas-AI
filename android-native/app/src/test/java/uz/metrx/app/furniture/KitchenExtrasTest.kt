package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Kitchen extras, plan 1b-1, on the L-kitchen of KitchenTest (walls A 3400, B 2600) with a sink and a hob. */
class KitchenExtrasTest {
    private val ws = Workshop()
    private val lens = mapOf("A" to 3400, "B" to 2600)
    private val f0 = Furniture("k", "kitchen", walls = listOf("A", "B"), layout = "L")
    private val runs = runsOf(f0) { lens[it] }
    private val base = autoFill(f0, runs, ws, emptyList(), emptyList()).let { f ->
        // the second and third lower unit of wall A become the sink and the hob
        val low = f.modules.filter { it.wall == "A" && !isUpper(it) }
        f.copy(modules = f.modules.map { m -> when (m.id) { low[1].id -> m.copy(app = "sink"); low[2].id -> m.copy(app = "hob"); else -> m } })
    }

    @Test fun noExtrasOnAnOlderKitchen() {
        assertTrue(extrasHardware(base).isEmpty()); assertTrue(extrasParts(base, ws).isEmpty())
    }

    @Test fun cornerCutOutsEndsPlinthCorniceLed() {
        val f = base.copy(kx = KExtras(joint = "mitre", splash = 600, plinth = true, cornice = true, led = true, ends = 1, endsUp = 1))
        assertEquals(1, worktopJoints(f))
        val hw = extrasHardware(f)
        assertEquals(1, hw["wtMitre"]); assertEquals(null, hw["wtJoint"])
        assertEquals(2, hw["wtCut"])
        assertEquals(2, hw["wtEnd"])                              // two pieces, joined once: two free ends
        assertEquals(3400 + 2000, hw["plinthK"]); assertEquals(1, hw["plinthCorner"])
        val wu = f.modules.filter { it.type == "wall" }.sumOf { it.w }
        assertEquals(wu, hw["cornice"]); assertEquals(wu, hw["led"]); assertEquals((wu + 4999) / 5000, hw["ledPsu"])
        assertEquals(3400 + 2000, splashMm(f))
        val ends = extrasParts(f, ws)
        assertEquals(listOf("fp.endLow", "fp.endUp"), ends.map { it.key })
        assertEquals(ws.legH + K_BASE_H, ends[0].L)
        // in the cut list (front material) and the cost: the backsplash by the metre
        assertTrue(cutList(listOf(f), ws).any { it.p.key == "fp.endLow" && it.mat == f.mats.front })
        val cost = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false)
        assertEquals(5.4, cost.lines.single { it.key == "splash6" }.qty, 1e-9)
        assertEquals(6.0, cost.lines.single { it.key == "plinthK" }.qty, 1e-9)     // 5,4 m bought as 6
    }

    @Test fun newKitchensStartWithAPlinth() {
        val k = newFreeKitchen("Oshxona 1", "L", "L", listOf(3000, 2000), 0, 2700, ws)
        assertEquals(kExtrasFor("L"), k.kx)
        assertTrue(k.kx!!.plinth); assertEquals(0, kExtrasFor("U").ends); assertEquals(3, kExtrasFor("O").ends)
    }
}
