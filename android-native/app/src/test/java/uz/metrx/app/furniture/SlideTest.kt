package uz.metrx.app.furniture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Sliding (купе) doors, plan 1b-2: sizes, parts and the hardware list. */
class SlideTest {
    private val ws = Workshop()
    // the kupe model: built in, 2400 × 2500 × 600, three doors
    private val m = wardrobeTemplate(ws, "A", W_GAP_SIDE, 2400, 2500, true, 600).copy(slide = Slide(3, listOf("ldsp", "mirror", "ldsp")))

    @Test fun doorsShareTheOpeningWithTheirOverlaps() {
        assertEquals(2400 to 2500 - PLINTH - 32, slideOpening(m, 16))      // built in: no sides
        val (w, h) = slideDoor(m, 16)
        assertEquals((2400 + 2 * SLIDE_OV) / 3, w)                         // 820
        assertEquals(2500 - PLINTH - 32 - SLIDE_CLEAR, h)
        assertEquals(w - 2 * SLIDE_FRAME_W to h - SLIDE_FRAME_H, slidePanel(m, 16))
        assertEquals(3, slideDoorsFor(2400)); assertEquals(2, slideDoorsFor(1600)); assertEquals(4, slideDoorsFor(3000))
    }

    @Test fun partsHaveTheBoardFillingsAndNoHingedDoors() {
        val ps = partsOf(m, ws)
        assertTrue(ps.none { it.key == "fp.door" })
        val fill = ps.single { it.key == "fp.slidePanel" }
        assertEquals(2, fill.qty)                                         // the mirror door is not a board
        // below the split rail; over it every door's own panel (KupeBoardDoorsTest)
        assertEquals(kupeFillH(m, 16).first, fill.L)
        assertEquals(3, ps.single { it.key == "fp.slideUp" }.qty)
        // the inside is shallower by the tracks
        assertTrue(ps.filter { it.key == "fp.shelf" }.all { it.W == 600 - SLIDE_D - 20 })
    }

    @Test fun hardwareCountsTracksProfilesRollersAndMirror() {
        val hw = hardwareOf(m, ws)
        val (dw, dh) = slideDoor(m, 16); val (pw, _) = slidePanel(m, 16)
        // the mirror below the split rail only, as the 3D draws it (the board above it: KupeBunkBoardsTest)
        val ph = kupeFillH(m, 16).first; assertTrue(ph < slidePanel(m, 16).second)
        assertEquals(2 * 2400, hw["slideTrack"]); assertEquals(2 * dh * 3, hw["slideV"]); assertEquals(2 * dw * 3, hw["slideH"])
        assertEquals(3, hw["slideRoller"]); assertEquals(pw * ph, hw["mirror"])
        assertEquals(null, hw["hinge"]); assertEquals(null, hw["hingeSoft"]); assertEquals(null, hw["handle"])
        val cost = costOf(listOf(Furniture("w", "wardrobe", modules = listOf(m))), ws, MAT_PRESETS, HW_PRESETS, order = false)
        val mirror = cost.lines.single { it.key == "mirror" }
        assertEquals("m2", mirror.unit)
        assertEquals(Math.ceil(pw * ph / 10000.0) / 100.0, mirror.qty, 1e-9)
        assertEquals("m", cost.lines.single { it.key == "slideTrack" }.unit)
        assertEquals(5.0, cost.lines.single { it.key == "slideTrack" }.qty, 1e-9)   // 4,8 m bought as 5
    }

    @Test fun theKupeModelStartsWithSlidingDoors() {
        val f = newFreeWardrobe("Shkaf 1", "s3", 2400, 2500, 600, true, "slide", ws, n = 3)
        assertEquals(3, wardOfF(f)!!.slide!!.n)
        assertTrue(F_MODELS.any { it.id == "s3" && it.doors == "slide" })
        assertTrue(wardrobeChecks(wardOfF(f)!!, 2420, 2600, ws, emptyList(), emptyList()).none { it.level == "err" })
    }
}
