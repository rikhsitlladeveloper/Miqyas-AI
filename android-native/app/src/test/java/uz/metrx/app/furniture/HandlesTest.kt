package uz.metrx.app.furniture

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Handles per door and per drawer, push latches and soft close per section (founder's decisions, 25 Oct 2026). */
class HandlesTest {
    private val ws = Workshop()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    /** 1800 wide on a plinth: a pair of doors, an open section with two drawers, a glass door. */
    private fun ward() = Module("w", "wardrobe", 1800, 2000, 600, legs = false, sections = listOf(
        Section(900, Fronts("door", 2)),
        Section(450, Fronts("open", 0), listOf(Insert("drawer", 0, h = 200), Insert("drawer", 210, h = 200))),
        Section(450, Fronts("door", 1), face = "glass")))

    private fun piece(m: Module) = Furniture("f", "wardrobe", modules = listOf(m))

    @Test fun theFrontsAndTheirKeys() {
        assertEquals(listOf("s0:f0", "s0:f1", "s1:d210", "s1:d0", "s2:f0"), handleFronts(ward()).map { it.key })
        assertTrue(handleFronts(ward()).single { it.key == "s2:f0" }.glass)
        assertEquals(listOf("f0", "f1", "f2"), handleFronts(Module("k", "base", 600, 720, 560, fronts = Fronts("drawer", 3))).map { it.key })
        // a fridge's space has none; a dishwasher's front has one
        assertTrue(handleFronts(Module("g", "gap", 600, 2000, 650, app = "fridge", fronts = Fronts("open", 0))).isEmpty())
        assertEquals(listOf("f0"), handleFronts(Module("g", "gap", 600, 720, 560, app = "dishwasher", fronts = Fronts("door", 1))).map { it.key })
    }

    @Test fun theHardwareCountsAPushLatchForEachFrontWithoutAHandle() {
        val m = ward()
        // as built: a glass door never has a handle
        hardwareOf(m, ws).let { assertEquals(4, it["handle"]); assertEquals(1, it["push"]) }
        val mixed = toggleHandle(toggleHandle(m, "s0:f1"), "s1:d0")
        assertTrue(hasHandle(mixed, "s0:f0")); assertFalse(hasHandle(mixed, "s0:f1"))
        assertTrue(hasHandle(mixed, "s1:d210")); assertFalse(hasHandle(mixed, "s1:d0"))
        hardwareOf(mixed, ws).let { assertEquals(2, it["handle"]); assertEquals(3, it["push"]); assertEquals(2, it["runner"]) }
        assertEquals(2 to 3, handleSplit(mixed))
        // a glass door cannot be given one
        assertFalse(hasHandle(withHandle(m, "s2:f0", true), "s2:f0"))
        // a kitchen unit of three drawers, the middle one pushed
        val k = toggleHandle(Module("k", "base", 600, 720, 560, fronts = Fronts("drawer", 3)), "f1")
        hardwareOf(k, ws).let { assertEquals(3, it["runner"]); assertEquals(2, it["handle"]); assertEquals(1, it["push"]) }
        // a bed's four drawers, one pushed
        val bed = Module("b", "bed", 1700, 1000, 2100, opt = Opt(bed = "drawers", mw = 1600, ml = 2000))
        assertEquals(4, handleFronts(bed).size)
        hardwareOf(toggleHandle(bed, "bd2"), ws).let { assertEquals(3, it["handle"]); assertEquals(1, it["push"]) }
        // the cost prices the push latches at their preset
        val c = costOf(listOf(piece(mixed)), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(3.0, c.lines.single { it.group == "hw" && it.key == "push" }.qty, 0.0)
        assertEquals(java.math.BigInteger("90000"), c.lines.single { it.group == "hw" && it.key == "push" }.amount)
    }

    @Test fun tappingOneFrontOfABoxWithoutHandlesLeavesTheOthersAsTheyLook() {
        val off = ward().copy(handles = false)
        assertEquals(0 to 5, handleSplit(off))
        val one = toggleHandle(off, "s0:f0")
        assertTrue(one.handles)
        assertEquals(listOf(true, false, false, false, false), handleFronts(one).map { hasHandle(one, it.key) })
        // all, then none
        assertEquals(4 to 1, handleSplit(allHandles(one, true)))
        assertEquals(0 to 5, handleSplit(allHandles(one, false)))
    }

    @Test fun anOlderOrderLoadsAndSavesAsBefore() {
        val old = """{"id":"w","type":"wardrobe","w":1800,"h":2000,"d":600,"legs":false,"soft":true,"handles":false,
            "sections":[{"w":900,"fronts":{"kind":"door","n":2},"inserts":[]},{"w":900,"fronts":{"kind":"open","n":0},"inserts":[{"kind":"drawer","pos":0,"h":200}]}]}"""
        val m = json.decodeFromString(Module.serializer(), old)
        // its box-wide switch is every front's value
        assertEquals(0 to 3, handleSplit(m))
        assertEquals(3, hardwareOf(m, ws)["push"]); assertNull(hardwareOf(m, ws)["handle"])
        assertTrue(m.noHandle.isEmpty() && m.sections.all { it.noHandle.isEmpty() && it.soft == null })
        // saved again it has none of the new fields (an issued quote's fingerprint stays)
        val out = json.encodeToString(Module.serializer(), m)
        assertFalse(out.contains("noHandle")); assertFalse(out.contains("\"push\"")); assertFalse(out.contains("\"soft\":null"))
        // an older order with handles: all of them, no latch
        val on = json.decodeFromString(Module.serializer(), old.replace("\"handles\":false", "\"handles\":true"))
        assertEquals(3 to 0, handleSplit(on)); assertNull(hardwareOf(on, ws)["push"])
        // the new fields saved and read back
        val mixed = withSoft(toggleHandle(toggleHandle(on, "s0:f1"), "s1:d0"), 0, false)
        assertEquals(mixed, json.decodeFromString(Module.serializer(), json.encodeToString(Module.serializer(), mixed)))
    }

    @Test fun changeForAllKeepsTheChoicesAndNoHandlesThenATypePutsThemAllBack() {
        val mixed = piece(toggleHandle(ward(), "s0:f1"))
        val knobs = swapAll(listOf(mixed), handle = "handleKnob").single()
        assertEquals("handleKnob", knobs.handle)
        assertFalse(hasHandle(knobs.modules[0], "s0:f1")); assertTrue(hasHandle(knobs.modules[0], "s0:f0"))
        assertEquals("handleKnob", commonHandle(listOf(knobs)))
        val none = swapAll(listOf(knobs), handle = NO_HANDLES).single()
        assertFalse(hasHandles(none)); assertFalse(none.modules[0].handles)
        assertEquals(NO_HANDLES, commonHandle(listOf(none)))
        val back = swapAll(listOf(none), handle = "handleLong").single()
        assertTrue(back.modules[0].handles)
        assertEquals(4 to 1, handleSplit(back.modules[0]))
        // the costs: knobs at the knob's price, the pushed door at the latch's
        val c = costOf(listOf(knobs), ws, MAT_PRESETS, HW_PRESETS)
        assertEquals(3.0, c.lines.single { it.key == "handleKnob" }.qty, 0.0)
        assertEquals(2.0, c.lines.single { it.key == "push" }.qty, 0.0)
        // every door pushed one by one reads as no handles, and a type then puts them back too
        val allOff = handleFronts(ward()).fold(ward()) { m, fr -> withHandle(m, fr.key, false) }
        assertEquals(NO_HANDLES, commonHandle(listOf(piece(allOff))))
        assertEquals(4 to 1, handleSplit(swapAll(listOf(piece(allOff)), handle = "handle").single().modules[0]))
    }

    @Test fun softCloseIsEachSectionsOwn() {
        val m = ward()
        // a pair of 1917 mm doors and a glass door: four hinges each
        assertEquals(12, hardwareOf(m, ws)["hingeSoft"]); assertNull(hardwareOf(m, ws)["hinge"])
        val one = withSoft(m, 2, false)
        assertTrue(softOf(one, 0)); assertFalse(softOf(one, 2))
        hardwareOf(one, ws).let { assertEquals(8, it["hingeSoft"]); assertEquals(4, it["hinge"]) }
        // back to the box's value: no choice of its own kept
        assertNull(withSoft(one, 2, true).sections[2].soft)
        // "Hammasiga": every section as the one picked
        val all = softAll(one, false)
        assertFalse(all.soft); assertTrue(all.sections.all { it.soft == null })
        hardwareOf(all, ws).let { assertEquals(12, it["hinge"]); assertNull(it["hingeSoft"]) }
    }

    @Test fun newDoorsDropTheOldChoices() {
        val s = Section(900, Fronts("door", 2), noHandle = listOf(1))
        assertTrue(frontsChanged(s, s.copy(fronts = Fronts("door", 1))).noHandle.isEmpty())
        assertEquals(listOf(1), frontsChanged(s, s.copy(w = 1000)).noHandle)
        val k = Module("k", "base", 600, 720, 560, fronts = Fronts("drawer", 3), noHandle = listOf("f2"))
        assertTrue(frontsChanged(k, k.copy(fronts = Fronts("drawer", 2))).noHandle.isEmpty())
        assertTrue(frontsChanged(k, k.copy(fronts = Fronts("door", 2))).noHandle.isEmpty())
        // a drawer moved keeps its choice: it is the drawer's own
        val w = toggleHandle(ward(), "s1:d0")
        val moved = w.copy(sections = w.sections.mapIndexed { i, sc -> if (i != 1) sc else sc.copy(inserts = respaced(sc.inserts.reversed(), 1800, 16).sortedBy { it.pos }) })
        assertEquals(1, moved.sections[1].inserts.count { it.push })
    }

    @Test fun aPieceBuiltAgainKeepsItsPushedFronts() {
        val st = pieceOf(fModel("stenka")!!, emptyMap(), ws, "stenka")
        val m0 = st.modules.first { handleFronts(it).isNotEmpty() }
        val key = handleFronts(m0).first().key
        val mixed = st.copy(modules = st.modules.map { if (it.id == m0.id) toggleHandle(it, key) else it })
        val big = pieceResized(mixed, mapOf("w" to pieceVals(mixed, ws).getValue("w") + 400), ws)
        val i = mixed.modules.filter { takesHandles(it) }.indexOfFirst { it.id == m0.id }
        assertFalse(hasHandle(big.modules.filter { takesHandles(it) }[i], key))
        assertTrue(hasHandles(big))
    }

    /* ---- the founder's answers (25 Oct 2026): drawers behind doors, the mirror cabinet, the dishwasher's front ---- */

    /** A pair of doors with two drawers behind them, and an open section with one drawer. */
    private fun behind() = Module("w", "wardrobe", 1300, 2000, 600, legs = false, sections = listOf(
        Section(900, Fronts("door", 2), listOf(Insert("drawer", 0, h = 200), Insert("drawer", 210, h = 200), Insert("shelf", 900))),
        Section(400, Fronts("open", 0), listOf(Insert("drawer", 0, h = 200)))))

    @Test fun drawersBehindDoorsTakeAHandleOrAPushLatch() {
        val m = behind()
        val fr = handleFronts(m)
        assertEquals(listOf("s0:f0", "s0:f1", "s0:d210", "s0:d0", "s1:d0"), fr.map { it.key })
        // the ones behind the doors are marked: they are not on the doors' picture
        assertEquals(listOf("s0:d210", "s0:d0"), fr.filter { it.inner }.map { it.key })
        assertTrue(fr.filter { it.inner }.all { it.drawer && it.sec == 0 })
        assertEquals(listOf("s0:f0", "s0:f1", "s1:d0"), uz.metrx.app.ui.furniture.wardFrontBoxes(m, ws).map { it.f.key })
        // as built: every door and drawer has a handle
        hardwareOf(m, ws).let { assertEquals(5, it["handle"]); assertNull(it["push"]); assertEquals(3, it["runner"]) }
        // one behind the doors pushed: the same Insert.push flag as an open section's drawer
        val one = toggleHandle(m, "s0:d0")
        assertTrue(one.sections[0].inserts.single { it.kind == "drawer" && it.pos == 0 }.push)
        assertFalse(hasHandle(one, "s0:d0")); assertTrue(hasHandle(one, "s0:d210")); assertFalse(drawerHandle(one, one.sections[0].inserts.first { it.pos == 0 }))
        hardwareOf(one, ws).let { assertEquals(4, it["handle"]); assertEquals(1, it["push"]) }
        assertEquals(4 to 1, handleSplit(one))
        // none, then all: per box
        assertEquals(0 to 5, handleSplit(allHandles(one, false)))
        hardwareOf(allHandles(one, false), ws).let { assertNull(it["handle"]); assertEquals(5, it["push"]) }
        assertEquals(5 to 0, handleSplit(allHandles(one, true)))
        // a box without handles: tapping one door leaves the drawers behind it pushed
        val tap = toggleHandle(m.copy(handles = false), "s0:f0")
        assertEquals(listOf(true, false, false, false, false), handleFronts(tap).map { hasHandle(tap, it.key) })
        // an older order without handles: the drawers behind its doors are pushed open too
        assertEquals(5, hardwareOf(m.copy(handles = false), ws)["push"])
    }

    @Test fun drawersBehindSlidingDoorsAreListedToo() {
        val m = behind().copy(slide = Slide(2))
        val fr = handleFronts(m)
        // the sliding doors take none; every drawer behind them does
        assertEquals(listOf("s0:d210", "s0:d0", "s1:d0"), fr.map { it.key })
        assertTrue(fr.all { it.inner })
        hardwareOf(toggleHandle(m, "s1:d0"), ws).let { assertEquals(2, it["handle"]); assertEquals(1, it["push"]) }
    }

    @Test fun theMirrorCabinetOpensByItsEdgeWithoutALatch() {
        val f = pieceOf(fModel("mirrorC")!!, emptyMap(), ws, "mirrorC")
        assertEquals("mirrorC", f.type); assertTrue(opensByEdge(f))
        val m = f.modules.single { it.type == "wardrobe" }
        assertFalse(m.handles)
        assertTrue(handleFronts(m).isNotEmpty())
        // the order's hardware: no handle and no push latch for its doors
        hardware(listOf(f), ws).let { assertNull(it["handle"]); assertNull(it["push"]); assertTrue((it["hingeSoft"] ?: 0) > 0) }
        assertTrue(costOf(listOf(f), ws, MAT_PRESETS, HW_PRESETS).lines.none { it.group == "hw" && (it.key == "push" || it.key == "handle") })
        // a door given a handle counts it; the other still needs no latch
        val k = handleFronts(m).first().key
        val g = f.copy(modules = f.modules.map { if (it.id == m.id) toggleHandle(it, k) else it })
        hardware(listOf(g), ws).let { assertEquals(1, it["handle"]); assertNull(it["push"]) }
        // the same box in another piece is pushed open as before
        assertEquals(handleFronts(m).size, hardware(listOf(f.copy(type = "")), ws)["push"])
        assertFalse(opensByEdge(f.copy(type = "")))
    }

    @Test fun theDishwashersFrontCountsItsHandleOrALatch() {
        // as the kitchen's library makes it: a gap with a panel front
        val dw = template("dishwasher", ws, "A")
        assertEquals("gap", dw.type); assertEquals("dishwasher", dw.app)
        assertEquals(listOf("f0"), handleFronts(dw).map { it.key })
        assertEquals(mapOf("handle" to 1), hardwareOf(dw, ws))
        val off = toggleHandle(dw, "f0")
        assertEquals(listOf("f0"), off.noHandle)
        assertEquals(mapOf("push" to 1), hardwareOf(off, ws))
        assertEquals(mapOf("push" to 1), hardwareOf(allHandles(dw, false), ws))
        // a fridge's space has none
        assertTrue(hardwareOf(template("fridge", ws, "A"), ws).isEmpty())
        // in the order's cost
        val k = Furniture("k", "kitchen", modules = listOf(off))
        assertEquals(1.0, costOf(listOf(k), ws, MAT_PRESETS, HW_PRESETS).lines.single { it.group == "hw" && it.key == "push" }.qty, 0.0)
    }

    @Test fun changeForAllPutsNoHandleOnTheMirrorCabinet() {
        val mc = pieceOf(fModel("mirrorC")!!, emptyMap(), ws, "mirrorC")
        val w = Furniture("f", "wardrobe", modules = listOf(behind()))
        // it has none whatever the others have: the shared handle still reads as one
        assertEquals("", commonHandle(listOf(w, mc)))
        assertNull(commonHandle(listOf(mc)))
        // a type for all: the mirror cabinet stays as it is, no handle put on it
        val knobs = swapAll(listOf(w, mc), handle = "handleKnob")
        assertEquals("handleKnob", commonHandle(knobs))
        assertEquals(mc, knobs[1])
        assertNull(hardware(listOf(knobs[1]), ws)["handle"])
        // "Tutqichsiz", then a type: the wardrobe's come back, the mirror cabinet's do not
        val back = swapAll(swapAll(knobs, handle = NO_HANDLES), handle = "handleLong")
        assertTrue(hasHandles(back[0])); assertFalse(hasHandles(back[1]))
        assertEquals("handleLong", commonHandle(back))
        // a door given a handle on its own takes the new type
        val k = handleFronts(mc.modules.single { it.type == "wardrobe" }).first().key
        val one = mc.copy(modules = mc.modules.map { if (it.type == "wardrobe") toggleHandle(it, k) else it })
        swapAll(listOf(one), handle = "handleKnob").single().let { assertEquals("handleKnob", it.handle); assertEquals(1, hardware(listOf(it), ws)["handle"]) }
    }
}
