package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.DECOR_PRESETS
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.KExtras
import uz.metrx.app.furniture.LONG_V
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.TEX_IDS
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.autoFill
import uz.metrx.app.furniture.freeRoom
import uz.metrx.app.furniture.hasHandle
import uz.metrx.app.furniture.handleFronts
import uz.metrx.app.furniture.newFreeKitchen
import uz.metrx.app.furniture.runsOf
import uz.metrx.app.furniture.takesHandles
import uz.metrx.app.furniture.waterfallEnds
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withPreset
import uz.metrx.app.furniture.worktopTop
import java.io.File
import kotlin.math.abs

/** A kitchen's design drawn in the lit 3D (modern 3D part 3): handles, Gola, crown, waterfall, LED, the decors' pictures. */
class KitchenLookTest {
    private val ws = Workshop()
    private val room = Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2600, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")))
    private val shell = buildShell(listOf(room), true)

    private fun kitchen(preset: String? = null): Furniture {
        val f0 = Furniture("k", "kitchen", walls = listOf("A", "B"), layout = "L", kx = KExtras(splash = 600, plinth = true))
        val f = autoFill(f0, runsOf(f0) { mapOf("A" to 3400, "B" to 2600)[it] }, ws, emptyList(), emptyList())
        return if (preset != null) withPreset(f, preset) else f
    }

    /** The lit 3D of [fs] as the designers show it: the design's looks from the workshop's materials. */
    private fun lit(f: Furniture, bases: Map<String, WallBasis> = shell.bases, light: Boolean = false, ceil: Int? = 2700) =
        furniture3D(listOf(f), bases, ws, { 0xCDBFAE }, emptySet(), look = { Looks.board(0xCDBFAE) }, mats = MAT_PRESETS, light = light, ceil = ceil)

    private fun ys(p: Part) = p.faces.flatMap { f -> f.pts.map { it.y } }

    /* ---------------- handles ---------------- */

    @Test fun handlesSitWhereTheMockupPutsThem() {
        // a base unit's door: a 128 bar (168 long) upright near the opening edge, its top 45 under the door's top
        val base = handleSpot("bar", "", "door", "top", 296.0, 716.0)!!
        assertEquals(168.0, base.len, 1e-9); assertTrue(base.vertical); assertEquals(296.0 - 34, base.u, 1e-9)
        assertEquals(716.0 - 45, base.v + base.len / 2, 1e-9)
        // a wall unit's: at its bottom
        val wall = handleSpot("bar", "", "door", "bottom", 296.0, 716.0)!!
        assertEquals(45.0, wall.v - wall.len / 2, 1e-9)
        // a tall door's round the middle given (1 m from the floor), kept on the door
        assertEquals(900.0, handleSpot("bar", "", "door", "mid", 296.0, 2000.0, 900.0)!!.v, 1e-9)
        assertEquals(2000.0 - 45 - 84, handleSpot("bar", "", "door", "mid", 296.0, 2000.0, 5000.0)!!.v, 1e-9)
        // a drawer's across its middle, 50 mm under its top
        val dr = handleSpot("bar", "", "drawer", "", 596.0, 240.0)!!
        assertFalse(dr.vertical); assertEquals(298.0, dr.u, 1e-9); assertEquals(190.0, dr.v, 1e-9)
        // a lift-up flap's along its bottom
        assertEquals(45.0, handleSpot("bar", "", "flap", "", 596.0, 500.0)!!.v, 1e-9)
    }

    @Test fun longVerticalsByTheDoorsHeight() {
        assertEquals(1024.0, handleSpot("long", LONG_V, "door", "mid", 446.0, 2010.0)!!.len, 1e-9)
        assertEquals(640.0, handleSpot("long", LONG_V, "door", "top", 296.0, 716.0)!!.len, 1e-9)
        assertEquals(320.0, handleSpot("long", LONG_V, "door", "top", 296.0, 500.0)!!.len, 1e-9)
        // drawers take the 320, laid across; none longer than the front less 80
        handleSpot("long", LONG_V, "drawer", "", 596.0, 300.0)!!.let { assertEquals(320.0, it.len, 1e-9); assertFalse(it.vertical) }
        assertEquals(220.0, handleSpot("long", LONG_V, "drawer", "", 300.0, 300.0)!!.len, 1e-9)
        assertEquals(1000.0 - 60, handleSpot("long", "handle1024", "door", "mid", 446.0, 1000.0)!!.len, 1e-9)
        // the older "long handle" is the 320 everywhere
        assertEquals(320.0, handleSpot("long", "handleLong", "door", "top", 296.0, 716.0)!!.len, 1e-9)
    }

    @Test fun knobsAndNoHandles() {
        handleSpot("knob", "handleKnob", "door", "top", 296.0, 716.0)!!.let { assertTrue(it.knob); assertEquals(296.0 - 42, it.u, 1e-9); assertEquals(716.0 - 70, it.v, 1e-9) }
        handleSpot("knob", "handleKnob", "door", "bottom", 296.0, 716.0)!!.let { assertEquals(70.0, it.v, 1e-9) }
        handleSpot("knob", "handleKnob", "drawer", "", 596.0, 240.0)!!.let { assertEquals(298.0, it.u, 1e-9); assertEquals(180.0, it.v, 1e-9) }
        assertNull(handleSpot("gola", "gola", "door", "top", 296.0, 716.0))
        assertNull(handleSpot("push", "none", "drawer", "", 596.0, 240.0))
    }

    @Test fun everyFrontWithAHandleGetsOneInTheLit3D() {
        for (pr in listOf("twotone", "gloss", "neo", "wood", "dark")) {
            val k = kitchen(pr)
            val want = k.modules.filter { takesHandles(it) }.flatMap { m -> handleFronts(m).filter { hasHandle(m, it.key) }.map { "${m.id}:${it.key}" } }.toSet()
            val got = lit(k).spots
            // an oven housing's one door is drawn as two halves (f0, f1), both with the handle
            assertTrue(pr, got.keys.containsAll(want))
            if (pr == "neo") assertTrue(got.values.all { it.knob })
            // long verticals: 640 on the 716 doors of base and wall units, from the set of three
            if (pr == "gloss") assertTrue(got.values.any { abs(it.len - 640) < 1e-9 } && got.values.all { it.len in setOf(320.0, 640.0, 1024.0) })
        }
        // a front chosen without a handle (a push latch) has none; the 2D painter's boxes record none
        val k = kitchen("twotone"); val m = k.modules.first { it.type == "base" && it.fronts.kind == "door" }
        val off = k.copy(modules = k.modules.map { if (it.id == m.id) uz.metrx.app.furniture.withHandle(it, "f0", false) else it })
        assertFalse("${m.id}:f0" in lit(off).spots)
        assertTrue(furniture3D(listOf(k), shell.bases, ws, { 0xCDBFAE }, emptySet()).spots.isEmpty())
    }

    /* ---------------- Gola ---------------- */

    @Test fun aGolaKitchenHasChannelsAndNoHandles() {
        val k = kitchen("gola")
        val fr = lit(k)
        assertTrue(fr.spots.isEmpty())
        val golaLook = Looks.surface(rgbOf(uz.metrx.app.furniture.lookOf(k, null, "gola").rgb), "metal", null, "hardware")
        val gp = fr.parts.filter { it.look == golaLook }
        // one box a channel: one under the worktop on each base unit and the dishwasher, one over each drawer, two round the oven
        val want = k.modules.sumOf { golaChannels(it) }
        assertTrue(want > 0)
        assertEquals(want, gp.sumOf { it.faces.size } / 6)
        assertEquals(1, golaChannels(k.modules.first { it.type == "base" && it.fronts.kind == "door" }))
        k.modules.firstOrNull { it.type == "base" && it.fronts.kind == "drawer" }?.let { assertEquals(it.fronts.n, golaChannels(it)) }
        assertEquals(0, golaChannels(k.modules.first { it.type == "wall" }))
        // a base unit's doors stop 34 mm short, under the channel
        val m = k.modules.first { it.type == "base" && it.fronts.kind == "door" }
        val plain = lit(withPreset(k, "twotone")).picks.first { it.key == "${m.id}:f0" }.box.b.len()
        val short = fr.picks.first { it.key == "${m.id}:f0" }.box.b.len()
        assertEquals(GOLA_GAP / 1000.0, plain - short, 1e-6)
    }

    /* ---------------- crown ---------------- */

    @Test fun crownHeights() {
        val k = kitchen("twotone")
        val wallTop = k.modules.filter { it.type == "wall" || it.type == "tall" }.maxOf { it.elev + it.h } / 1000.0
        fun top(f: Furniture, ceil: Int? = 2700) = lit(f, ceil = ceil).parts.flatMap { ys(it) }.max()
        assertEquals(wallTop, top(k), 1e-6)
        // the cornice: three layers, 76 mm over the wall units' tops
        assertEquals(wallTop + .076, top(kitchen("neo")), 1e-6)
        // the row up to the ceiling: 4 mm under it, the room's height, else a room-less kitchen's own, else 2700
        assertEquals(2.696, top(kitchen("dark")), 1e-6)
        assertEquals(2.996, top(kitchen("dark"), 3000), 1e-6)
        val free = newFreeKitchen("k", "L", "L", listOf(3000, 2000), 0, 2900, ws).let { withPreset(it, "dark") }
        val fb = buildShell(listOf(freeRoom(free)), true).bases
        assertEquals(2.896, lit(free, fb, ceil = null).parts.flatMap { ys(it) }.max(), 1e-6)
        // the 2D painter's boxes have the row too (six faces a box)
        val flat = furniture3D(listOf(kitchen("dark")), shell.bases, ws, { 0xCDBFAE }, emptySet(), ceil = 2700)
        assertEquals(2.696, flat.parts.flatMap { ys(it) }.max(), 1e-6)
        flat.parts.forEach { assertEquals(0, it.faces.size % 6) }
    }

    /* ---------------- waterfall ---------------- */

    @Test fun aWaterfallOnlyWhenChosen() {
        val k = newFreeKitchen("k", "O", "O", listOf(3000), 1800, 2700, ws).let { withPreset(it, "twotone") }
        val bases = buildShell(listOf(freeRoom(k)), true).bases
        val topY = (worktopTop(ws) - 38) / 1000.0
        fun lowest(f: Furniture) = lit(f, bases).parts.filter { it.slab }.flatMap { ys(it) }.min()
        assertEquals(0, waterfallEnds(k))
        assertEquals(topY, lowest(k), 1e-6)
        val wf = withLook(k) { it.copy(waterfall = true) }
        assertEquals(2, waterfallEnds(wf))
        assertEquals(0.0, lowest(wf), 1e-6)
        // the island's two ends run down; its end panels go
        val n = lit(wf, bases).parts.filter { it.slab }.sumOf { p -> p.faces.count { f -> f.pts.any { it.y < .001 } && abs(f.n.y) < .5 } }
        assertEquals(8, n)
    }

    /* ---------------- worktop, splash, LED ---------------- */

    @Test fun theSinkIsCutIntoTheWorktopAndTheSlimTopSitsLower() {
        val k0 = kitchen("twotone"); val s0 = k0.modules.first { it.type == "base" && it.fronts.n == 2 }
        val k = k0.copy(modules = k0.modules.map { if (it.id == s0.id) it.copy(app = "sink") else it })
        val sink = k.modules.first { it.app == "sink" }
        val fr = lit(k)
        // no worktop face covers the middle of the sink's cut-out
        val h = sinkHole(sink); val b = shell.bases.getValue(sink.wall!!)
        val mid = b.at((h[0] + h[1]) / 2000, 0.0, (h[2] + h[3]) / 2000)
        val wtY = worktopTop(ws) / 1000.0
        val over = fr.parts.filter { it.slab }.flatMap { it.faces }.filter { f -> f.n.y > .9 && abs(f.pts[0].y - wtY) < 1e-6 }.any { f ->
            val xs = f.pts.map { it.x }; val zs = f.pts.map { it.z }
            mid.x > xs.min() + 1e-6 && mid.x < xs.max() - 1e-6 && mid.z > zs.min() + 1e-6 && mid.z < zs.max() - 1e-6
        }
        assertFalse(over)
        // a 20 mm stone: the worktop's top 18 mm lower
        val slim = k.copy(mats = k.mats.copy(top = "wt20m"))
        assertEquals(wtY - .018, lit(slim).parts.filter { it.slab }.flatMap { ys(it) }.max(), 1e-6)
    }

    @Test fun ledGlowsAndTheLightTierDrawsLess() {
        val k = kitchen("twotone").let { it.copy(kx = it.kx!!.copy(led = true)) }
        val hi = lit(k); val lo = lit(k, light = true)
        assertTrue(hi.parts.any { it.look == Looks.led && it.faces.isNotEmpty() })
        assertTrue(lo.parts.any { it.look == Looks.led && it.faces.isNotEmpty() })
        // the glow on the wall: see-through, glowing; none on the light tier
        assertTrue(hi.parts.any { (it.look?.alpha ?: 1f) < 1f && (it.look?.emissive ?: 0f) > 1f })
        assertFalse(lo.parts.any { (it.look?.alpha ?: 1f) < 1f && (it.look?.emissive ?: 0f) > 1f })
        assertTrue(lo.parts.sumOf { it.faces.size } < hi.parts.sumOf { it.faces.size })
        // without LED, no strip
        assertFalse(lit(kitchen("twotone")).parts.any { it.look == Looks.led })
    }

    @Test fun twoToneFrontsAndStyles() {
        val k = kitchen("twotone")
        val fr = lit(k)
        val up = Looks.surface(rgbOf("#F2F2EF"), "gloss", null); val low = Looks.surface(rgbOf("#41454C"), "gloss", null)
        assertTrue(fr.parts.any { it.look == up } && fr.parts.any { it.look == low })
        // milled fronts have many more faces than flat ones; fluted more still
        val faces = { f: Furniture -> lit(f).parts.sumOf { it.faces.size } }
        val flat = faces(withLook(kitchen("neo")) { it.copy(style = "flat") })
        val shaker = faces(kitchen("neo"))
        val fluted = faces(withLook(kitchen("neo")) { it.copy(style = "fluted") })
        assertTrue(shaker > flat * 1.3 && fluted > shaker)
    }

    @Test fun doorsStillOpenAndPartsStayPut() {
        val k = kitchen("neo")
        val shut = lit(k)
        val key = shut.keys.first { it.endsWith(":f0") }
        val opened = furniture3D(listOf(k), shell.bases, ws, { 0xCDBFAE }, setOf(key), look = { Looks.board(0xCDBFAE) }, mats = MAT_PRESETS)
        assertEquals(shut.parts.size, opened.parts.size)
        val a = shut.picks.single { it.key == key }.box; val b = opened.picks.single { it.key == key }.box
        assertTrue(abs(a.a.z) < 1e-9 && b.a.z > .99 * b.a.len())
        // the handle moved with the door: the handle part's faces differ
        val hl = Looks.surface(rgbOf(uz.metrx.app.furniture.lookOf(k, null, "handle").rgb), "metal", null, "hardware")
        assertTrue(shut.parts.first { it.look == hl }.faces.map { it.pts } != opened.parts.first { it.look == hl }.faces.map { it.pts })
    }

    /* ---------------- the decors' pictures ---------------- */

    @Test fun everyDecorIdResolvesToABundledPicture() {
        val dir = listOf(File("src/main/assets/tex"), File("app/src/main/assets/tex")).first { it.exists() }
        val geometry = setOf("fluted", "fluted_glass")
        (TEX_IDS - geometry + DECOR_PRESETS.mapNotNull { it.tex }).forEach { id ->
            val t = TEXTURES[id]
            assertTrue(id, t != null)
            assertTrue(id, File(dir, "512/${t!!.file}.webp").exists() && File(dir, "256/${t.file}.webp").exists())
        }
        geometry.forEach { assertNull(TEXTURES[it]) }
        // a shade of another decor's picture is recoloured to its own colour
        assertEquals("oak_halifax", TEXTURES.getValue("oak_tobacco").file); assertEquals(0x7A5A40, TEXTURES.getValue("oak_tobacco").tint)
        assertEquals("wenge", TEXTURES.getValue("oak_dark").file)
        assertTrue(TEXTURES.getValue("skinali_print").fit)
    }
}
