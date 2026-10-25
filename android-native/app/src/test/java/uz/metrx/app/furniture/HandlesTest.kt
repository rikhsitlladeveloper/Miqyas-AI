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
}
