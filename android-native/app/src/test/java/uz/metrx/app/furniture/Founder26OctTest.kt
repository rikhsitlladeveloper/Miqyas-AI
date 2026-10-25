package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Project
import uz.metrx.app.data.Store
import uz.metrx.app.geo.Looks
import uz.metrx.app.geo.PartHi
import uz.metrx.app.geo.buildShell
import uz.metrx.app.geo.furniture3D
import java.math.BigInteger

/**
 * The founder's answers of 26 Oct 2026: a kupe's end without a wall gets a side panel of the fronts' board; the
 * neoclassic preset puts the cornice on tall wardrobes and kupe too; a Gola kitchen's wall units open by a push latch;
 * a kitchen vitrina's LED inside is priced and its accent back cut from the accent board (iPhone Founder26OctTests,
 * the same cases and numbers).
 */
class Founder26OctTest {
    private val ws = Workshop()

    private fun cost(f: Furniture) = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false)
    private fun line(f: Furniture, key: String) = cost(f).lines.singleOrNull { it.key == key }
    private fun mats(f: Furniture, key: String) = partsWithMat(f, ws).filter { it.first.key == key }.map { it.second }.toSet()

    /** A room-less built-in kupe 1800 × 2500 × 600, two doors (gallery model s2). */
    private fun kupe() = newFreeWardrobe("Kupe", "s2", 1800, 2500, 600, true, "slide", ws, n = 2).let { f -> f.copy(id = "s", modules = f.modules.map { it.copy(id = "sm") }) }

    /** How many side boards of [f] the 3D draws (lit up as Bazis lights the parts list's "fp.side" of the fronts' board). */
    private fun sides3D(f: Furniture): Int {
        val sh = buildShell(listOf(freeRoom(f)), true)
        val hi = PartHi("fp.side", "front", f.modules.map { "${f.id}|${it.label.ifEmpty { it.id }}" }.toSet())
        return furniture3D(listOf(f), sh.bases, ws, { 0xCDBFAE }, emptySet(), hi = hi).parts.filter { it.look == Looks.hi }.sumOf { it.faces.size } / 6
    }

    /* ---------------- 1. a kupe's ends without a wall ---------------- */

    @Test fun aRoomlessKupeHasASidePanelAtEachEnd() {
        val k = kupe()
        val m = k.modules[0]
        assertTrue(m.sideL && m.sideR)
        // its full height and depth, of the fronts' board, two of them
        val side = partsOf(m, ws).single { it.key == "fp.side" }
        assertEquals(Triple(2500, 600, 2), Triple(side.L, side.W, side.qty))
        assertEquals("front", side.role); assertEquals(setOf("ldsp16k"), mats(k, "fp.side"))
        // the doors close the opening between them: 1768 wide, two doors 899 each
        assertEquals(1768, slideOpening(m, ws.t).first); assertEquals(899 to 2348, slideDoor(m, ws.t))
        // in the 3D, the cut list and the labels
        assertEquals(2, sides3D(k))
        assertTrue(cutList(listOf(k), ws).any { it.mat == "ldsp16k" && it.p.key == "fp.side" && it.p.qty == 2 && it.p.L == 2500 && it.p.W == 600 })
        assertEquals(2, labelsOf(listOf(k), ws).count { it.key == "fp.side" && it.mat == "ldsp16k" && it.L == 2500 && it.W == 600 })
        // and in the price: the two sides' 3.0 m² of the fronts' board (its top, plinth and door boards 32 mm narrower:
        // 2.905 m² more in all; still 2 sheets, 1 380 000) and their banding, 21 m (16 without)
        val old = k.copy(modules = k.modules.map { it.copy(sideL = false, sideR = false) })
        assertEquals(0, sides3D(old))
        fun area(f: Furniture) = cutList(listOf(f), ws).filter { it.mat == "ldsp16k" }.sumOf { it.p.L.toLong() * it.p.W * it.p.qty }
        assertEquals(2905472L, area(k) - area(old))
        assertEquals(2.0, line(k, "ldsp16k")!!.qty, 1e-9); assertEquals(BigInteger("1380000"), line(k, "ldsp16k")!!.amount)
        line(k, "band2")!!.let { assertEquals(21.0, it.qty, 1e-9); assertEquals(BigInteger("94500"), it.amount) }
        assertEquals(16.0, line(old, "band2")!!.qty, 1e-9)
    }

    @Test fun anOlderRoomlessKupeGetsItsSidePanelsBack() {
        val old = kupe().let { f -> f.copy(modules = f.modules.map { it.copy(sideL = false, sideR = false) }) }
        val healed = withKupeEnds(old)
        assertTrue(healed.modules[0].sideL && healed.modules[0].sideR)
        assertEquals(2, sides3D(healed))
        // nothing to do: the same piece; a kupe in a room keeps what its walls gave it; a hinged wardrobe is left alone
        assertSame(healed, withKupeEnds(healed))
        val inRoom = old.copy(roomId = "r")
        assertSame(inRoom, withKupeEnds(inRoom))
        val hinged = newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, true, "door", ws)
        assertSame(hinged, withKupeEnds(hinged))
        // the store heals a saved order once, and leaves one with nothing to heal as it is
        val p = Project("p", "A", industry = "furniture", furniture = listOf(old, hinged))
        val q = Store.kupeEnds(p)
        assertTrue(q.furniture[0].modules[0].sideL && q.furniture[0].modules[0].sideR)
        assertSame(q, Store.kupeEnds(q))
    }

    @Test fun aKupeInARoomHasASidePanelAtAFreeEndOnly() {
        val k = kupe().copy(roomId = "r")
        val m = k.modules[0].copy(x = W_GAP_SIDE, wall = "A")
        // in the corner of a 3,0 m wall: none at the wall, one at the end in the room
        kupeSides(k, m, 3000).let { assertFalse(it.sideL); assertTrue(it.sideR); assertEquals(1, partsOf(it, ws).single { p -> p.key == "fp.side" }.qty) }
        // wall to wall: none; in the middle of the wall: both; the wall not known, or standing free: both
        assertTrue(partsOf(kupeSides(k, m.copy(w = 1800), 1820), ws).none { it.key == "fp.side" })
        kupeSides(k, m.copy(x = 600), 3000).let { assertTrue(it.sideL && it.sideR) }
        kupeSides(k, m, null).let { assertTrue(it.sideL && it.sideR) }
        kupeSides(k.copy(pose = Pose("A", 0, 900)), m, 3000).let { assertTrue(it.sideL && it.sideR) }
        // without a room: both, whatever the made-up room's walls
        kupeSides(k.copy(roomId = null), m.copy(sideL = false, sideR = false), 1820).let { assertTrue(it.sideL && it.sideR) }
        // a hinged wardrobe is not a kupe: as it is
        val h = m.copy(slide = null, sideL = false)
        assertSame(h, kupeSides(k, h, 3000))
    }

    /* ---------------- 2. the neoclassic cornice on tall wardrobes and kupe ---------------- */

    @Test fun neoclassicPutsTheCorniceOnTallWardrobesAndKupe() {
        // a kupe without a room: along its top (no free end in its made-up room), 2.4 m, 3 whole metres at 65 000
        val k = withPreset(newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws), "neo", ws = ws)
        assertEquals("cornice", k.look!!.crown); assertEquals("cornice", crownOf(k))
        assertEquals(2400, lookHardware(k, ws)["cornice"])
        line(k, "cornice")!!.let { assertEquals(3.0, it.qty, 1e-9); assertEquals(BigInteger("65000"), it.price); assertEquals(BigInteger("195000"), it.amount) }
        // a hinged wardrobe 1000 × 2200: 1 m
        val h = withPreset(newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, false, "door", ws), "neo", ws = ws)
        assertEquals("cornice", h.look!!.crown); assertEquals(BigInteger("65000"), line(h, "cornice")!!.amount)
        // in a room, 500 from the corner with its side panels: both ends turn back, 1800 + 2 × 676 = 3152, 4 m
        val r0 = newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws)
        val r = withPreset(r0.copy(roomId = "r", modules = r0.modules.map { it.copy(x = 500) }), "neo", ws = ws)
        assertEquals(3152, lookHardware(r, ws)["cornice"]); assertEquals(BigInteger("260000"), line(r, "cornice")!!.amount)
        // a low one (its top under 1800) takes none; nor a bed
        val low = withPreset(newFreeWardrobe("Shkaf", "h2", 1000, 1700, 600, false, "door", ws), "neo", ws = ws)
        assertEquals("", low.look!!.crown); assertNull(line(low, "cornice"))
        val bed = Furniture("b", "wardrobe", modules = listOf(Module("bm", "bed", 1700, 450, 2100, opt = Opt(bed = "legs", hb = 1100))), type = "bed")
        assertEquals("", withPreset(bed, "neo", ws = ws).look!!.crown)
        // the other presets leave the crown as it is: kept on the neoclassic one, none on a new one
        listOf("twotone", "gloss", "gola", "wood", "dark").forEach { id ->
            assertEquals(id, "cornice", withPreset(k, id, ws = ws).look!!.crown)
            assertEquals(id, "", withPreset(newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws), id, ws = ws).look!!.crown)
        }
        assertEquals("ceiling", withPreset(withCrown(k, "ceiling"), "gloss", ws = ws).look!!.crown)
        // a kitchen's own cornice as before (its extras), a gorka's as before
        val kit = withPreset(newFreeKitchen("Oshxona 1", "I", "I", listOf(3000), 0, 2700, ws), "neo", ws = ws)
        assertTrue(kit.kx!!.cornice); assertEquals("", kit.look!!.crown)
    }

    /* ---------------- 3. a Gola kitchen's wall units open by a push latch ---------------- */

    @Test fun aGolaKitchensWallUnitsOpenByAPushLatch() {
        fun at(m: Module, id: String, x: Int) = m.copy(id = id, x = x)
        val flap = at(template("wall", ws, "A"), "fl", 1200).copy(fronts = Fronts("door", 1), inserts = listOf(Insert("lift")))
        val mods = listOf(at(template("base", ws, "A"), "b", 0), at(template("drawers", ws, "A"), "d", 600),
            at(template("wall", ws, "A"), "w", 0), at(template("vitrina", ws, "A"), "v", 600), flap)
        val k = Furniture("k", "kitchen", walls = listOf("A"), modules = mods)
        val g = withHandleType(k, "gola")
        assertEquals(GOLA, g.handle)
        val hw = hardware(listOf(g), ws)
        // no handle at all; a latch for each wall unit's door and flap: 2 + 2 glass + 1 flap
        assertNull(hw["handle"]); assertEquals(5, hw["push"])
        // the base units keep their channels: one over the door unit, one over each of the 3 drawers
        assertEquals(600 + 3 * 600, hw["gola"])
        line(g, "push")!!.let { assertEquals(5.0, it.qty, 1e-9); assertEquals(BigInteger("150000"), it.amount) }
        // the usual handles before: 2 + 3 on the base units, 5 on the wall units
        assertEquals(10, hardware(listOf(k), ws)["handle"]); assertNull(hardware(listOf(k), ws)["push"])
        // the lit 3D shows no handle on any front
        val sh = buildShell(listOf(freeRoom(g)), true)
        val lit = furniture3D(listOf(g), sh.bases, ws, { 0xCDBFAE }, emptySet(), look = { Looks.board(0xCDBFAE) }, mats = MAT_PRESETS)
        assertTrue(lit.spots.isEmpty())
        assertTrue(furniture3D(listOf(k), sh.bases, ws, { 0xCDBFAE }, emptySet(), look = { Looks.board(0xCDBFAE) }, mats = MAT_PRESETS).spots.keys.any { it.startsWith("w:") })
    }

    /* ---------------- 4. the kitchen vitrina's LED and accent back ---------------- */

    private fun row(n: Int, led: Boolean, look: Look? = null, accentIn: Boolean = false): Furniture {
        val ms = (0 until n).map { i -> template("wall", ws, "A").copy(id = "w$i", x = 600 * i) } +
            template("vitrina", ws, "A").copy(id = "v", x = 600 * n, accentIn = accentIn)
        return Furniture("k", "kitchen", walls = listOf("A"), modules = ms, kx = KExtras(led = led), look = look)
    }

    @Test fun aVitrinasLedInsideIsPricedWithTheKitchensLed() {
        // two board wall units and a vitrina: 1800 under the wall units, 600 inside the vitrina; one driver
        val k = row(2, true)
        assertEquals(600, vitrinaLedMm(k))
        val hw = hardware(listOf(k), ws)
        assertEquals(2400, hw["led"]); assertEquals(1, hw["ledPsu"])
        line(k, "led")!!.let { assertEquals(3.0, it.qty, 1e-9); assertEquals(BigInteger("105000"), it.amount) }
        assertEquals(BigInteger("120000"), line(k, "ledPsu")!!.amount)
        // its share of the drivers: 4800 under and 600 inside take a second one (4800 alone, one)
        val long = row(7, true)
        assertEquals(5400, hardware(listOf(long), ws)["led"]); assertEquals(2, hardware(listOf(long), ws)["ledPsu"])
        assertEquals(BigInteger("240000"), line(long, "ledPsu")!!.amount)
        // only with the kitchen's LED on
        val off = row(2, false)
        assertEquals(0, vitrinaLedMm(off)); assertNull(hardware(listOf(off), ws)["led"]); assertNull(hardware(listOf(off), ws)["ledPsu"])
        // a board wall unit has none inside
        val board = k.copy(modules = k.modules.map { withGlassDoors(it, false) })
        assertEquals(0, vitrinaLedMm(board)); assertEquals(1800, hardware(listOf(board), ws)["led"])
    }

    @Test fun aVitrinasAccentBackIsCutFromTheAccentBoard() {
        val wood = Look(accent = "wd_walnut")
        val k = row(0, false, wood, accentIn = true)
        val v = k.modules.single()
        assertTrue(vitrinaAccentBack(k, v))
        // the back 716 × 596 of the walnut accent: in the cut list, the labels and the price (0.43 m² at 110 000)
        assertEquals(setOf("wd_walnut"), mats(k, "fp.back"))
        assertTrue(cutList(listOf(k), ws).any { it.mat == "wd_walnut" && it.p.key == "fp.back" && it.p.L == 716 && it.p.W == 596 })
        assertEquals(listOf("wd_walnut"), labelsOf(listOf(k), ws).filter { it.key == "fp.back" }.map { it.mat })
        line(k, "wd_walnut")!!.let { assertEquals("m2", it.unit); assertEquals(0.43, it.qty, 1e-9); assertEquals(BigInteger("47300"), it.amount) }
        assertNull(line(k, "hdf3"))
        // without the accent inside, or without an accent in the look: the usual back board
        val plain = row(0, false, wood)
        assertEquals(setOf("hdf3"), mats(plain, "fp.back")); assertNull(line(plain, "wd_walnut"))
        assertEquals(BigInteger("210000"), line(plain, "hdf3")!!.amount)
        val noAccent = row(0, false, Look(), accentIn = true)
        assertFalse(vitrinaAccentBack(noAccent, noAccent.modules.single())); assertEquals(setOf("hdf3"), mats(noAccent, "fp.back"))
        // the other parts keep their boards
        assertEquals(setOf("ldsp16w"), mats(k, "fp.side"))
    }
}
