package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigInteger

/**
 * The prices of a wardrobe's crown, a bed's metal legs and its soft wall panel by its drawn area (Look.kt; iPhone
 * CrownBedPriceTests, the same cases and numbers).
 */
class CrownBedPriceTest {
    private val ws = Workshop()

    private fun cost(f: Furniture) = costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS, order = false)
    private fun line(f: Furniture, key: String) = cost(f).lines.singleOrNull { it.key == key }

    /** A built-in sliding wardrobe 2400 × 2500 × 600 without a room (no side panels: it stands wall to wall). */
    private fun kupe() = newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws).copy(id = "s")

    /** A hinged wardrobe 1800 × 2200 × 600 with its side panels, in a measured room, 500 from the wall's corner. */
    private fun shkaf(): Furniture {
        val f = newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws)
        return f.copy(id = "w", roomId = "r", modules = f.modules.map { it.copy(id = "wm", x = 500) })
    }

    private fun bed(bed: String = "legs", mw: Int = 1600, hb: Int = 1100, x: Int = 1000, room: String? = "r") =
        Furniture("b", "wardrobe", roomId = room, walls = listOf("A"), type = "bed",
            modules = listOf(Module("bm", "bed", mw + 100, 450, 2100, x = x, wall = "A", opt = Opt(bed = bed, mw = mw, hb = hb))))

    @Test fun aWardrobesCorniceByTheMetreWithItsFreeEnds() {
        // the built-in kupe: along its top only (2.4 m, 3 whole metres) at the kitchen's cornice item
        val k = withCrown(kupe(), "cornice")
        assertEquals(2400, lookHardware(k, ws)["cornice"])
        assertEquals(3.0, line(k, "cornice")!!.qty, 1e-9); assertEquals(BigInteger("65000"), line(k, "cornice")!!.price)
        assertEquals(BigInteger("195000"), line(k, "cornice")!!.amount)
        assertNull(line(k, "wdCeil"))
        // with its side panels, off the corner, its far end not known to the price: both ends turn back (600 + 2 × 38)
        val s = withCrown(shkaf(), "cornice")
        assertEquals(2, crownFreeEnds(s, s.modules[0], null))
        assertEquals(1800 + 2 * 676, lookHardware(s, ws)["cornice"])
        assertEquals(BigInteger("260000"), line(s, "cornice")!!.amount)
        // its far end at the wall: one free end; a neighbour box at its right: one; standing free in the room: two
        assertEquals(1, crownFreeEnds(s, s.modules[0], 2320))
        val two = s.copy(modules = s.modules + s.modules[0].copy(id = "wm2", x = 2300))
        assertEquals(listOf(1, 1), two.modules.map { crownFreeEnds(two, it, null) })
        assertEquals(2 * 1800 + 2 * 676, wardCorniceMm(two, ws))
        assertEquals(2, crownFreeEnds(s.copy(roomId = null, pose = Pose("A", 0, 900)), s.modules[0], 1820))
        // the same wardrobe without a room: its made-up room is wall to wall, so along the top only
        val free = withCrown(newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws), "cornice")
        assertEquals(1820, pieceWallLen(free, "A"))
        assertEquals(1800, lookHardware(free, ws)["cornice"])
    }

    @Test fun aWardrobesRowUpToTheCeilingByTheMetreOfItsWidth() {
        val k = withCrown(kupe(), "ceiling")
        assertEquals(2400, lookHardware(k, ws)["wdCeil"])
        val c = line(k, "wdCeil")!!
        assertEquals(3.0, c.qty, 1e-9); assertEquals("m", c.unit); assertEquals(BigInteger("800000"), c.price); assertEquals(BigInteger("2400000"), c.amount)
        assertNull(line(k, "cornice")); assertNull(line(k, "ceilUnit"))
        // an editable item of its own, by the metre
        assertEquals("m", hwUnit("wdCeil")); assertTrue(HW_PRESETS.any { it.id == "wdCeil" && it.kind == "wdCeil" && it.price == "800000" })
        // only boxes standing on the floor, 1800 high or more; not a gorka's (its own cornice), not a kitchen's
        val low = k.copy(modules = k.modules.map { it.copy(h = 1700) })
        assertTrue(crownBoxes(low, ws).isEmpty()); assertNull(lookHardware(low, ws)["wdCeil"])
        val hungBox = k.copy(modules = k.modules.map { it.copy(elev = 300, legs = false) })
        assertTrue(crownBoxes(hungBox, ws).isEmpty())
        assertTrue(crownBoxes(withCrown(k.copy(type = "gorka"), "cornice"), ws).isEmpty())
        val kitchen = newFreeKitchen("Oshxona 1", "I", "I", listOf(3000), 0, 2700, ws)
        assertNull(lookHardware(withCrown(kitchen, "ceiling"), ws)["wdCeil"])
        assertTrue((lookHardware(withCrown(kitchen, "ceiling"), ws)["ceilUnit"] ?: 0) > 0)
        // no crown: neither
        assertTrue(listOf("cornice", "wdCeil").none { line(withCrown(k, ""), it) != null })
    }

    @Test fun aBedOnMetalLegs() {
        val plain = bed()
        // its plain legs as before: four and one in the middle of a wide bed
        assertEquals(5, hardware(listOf(plain), ws)["leg"]); assertNull(hardware(listOf(plain), ws)["legMetal"])
        val metal = withLook(plain) { it.copy(legs = true) }
        assertEquals(4, bedMetalLegs(metal, metal.modules[0]))
        assertNull(hardware(listOf(metal), ws)["leg"])
        assertEquals(4.0, line(metal, "legMetal")!!.qty, 1e-9); assertEquals(BigInteger("180000"), line(metal, "legMetal")!!.amount)
        // six under a bed wider than 1600
        val wide = withLook(bed(mw = 1800)) { it.copy(legs = true) }
        assertEquals(6, hardware(listOf(wide), ws)["legMetal"]); assertEquals(BigInteger("270000"), line(wide, "legMetal")!!.amount)
        // none on a bed with drawers or a lift-up base
        listOf("drawers", "lift").forEach { k ->
            val b = withLook(bed(k)) { it.copy(legs = true) }
            assertEquals(0, bedMetalLegs(b, b.modules[0])); assertNull(line(b, "legMetal"))
        }
    }

    @Test fun aBedsWallPanelByItsDrawnArea() {
        // 400 past each side, from 80 up to 1380: (1700 + 800) × 1300
        val on = withLook(bed()) { it.copy(panel = true) }
        val p = bedPanelOf(on, on.modules[0])!!
        assertEquals(PanelSpan(-400.0, 2100.0, 80.0, 1380.0), p)
        assertEquals(2500 * 1300, lookHardware(on, ws)["softPanel"])
        assertEquals(3.25, line(on, "softPanel")!!.qty, 1e-9); assertEquals(BigInteger("2437500"), line(on, "softPanel")!!.amount)
        // a tall headboard: 150 over it
        val tall = withLook(bed(hb = 1600)) { it.copy(panel = true) }
        assertEquals(2500 * 1670, lookHardware(tall, ws)["softPanel"])
        assertEquals(4.18, line(tall, "softPanel")!!.qty, 1e-9); assertEquals(BigInteger("3135000"), line(tall, "softPanel")!!.amount)
        // cut to the wall: near its corner, and without a room to its made-up room's ends (10 past each side)
        val corner = withLook(bed(x = 150)) { it.copy(panel = true) }
        assertEquals(2250 * 1300, lookHardware(corner, ws)["softPanel"])
        val free = withLook(bed(x = W_GAP_SIDE, room = null)) { it.copy(panel = true) }
        assertEquals(1720, pieceWallLen(free, "A"))
        assertEquals(PanelSpan(-10.0, 1710.0, 80.0, 1380.0), bedPanelOf(free, free.modules[0]))
        assertEquals(1720 * 1300, lookHardware(free, ws)["softPanel"])
        // moved into the room: at the wall still its full panel, out in the room none
        assertEquals(2500 * 1300, lookHardware(on.copy(pose = Pose("A", 1000, 0)), ws)["softPanel"])
        assertNull(lookHardware(on.copy(pose = Pose("A", 1000, 600)), ws)["softPanel"])
        // its LED along the panel's top
        val lit = withLook(on) { it.copy(led = true) }
        assertEquals(2500, lookHardware(lit, ws)["led"]); assertEquals(1, lookHardware(lit, ws)["ledPsu"])
        assertNull(lookHardware(bed(), ws)["softPanel"])
        // one rule for the 3D and the price
        assertEquals(p, bedPanelSpan(on.modules[0], -1000.0, 1e9))
        assertNull(bedPanelSpan(on.modules[0], -10.0, 150.0))
    }
}
