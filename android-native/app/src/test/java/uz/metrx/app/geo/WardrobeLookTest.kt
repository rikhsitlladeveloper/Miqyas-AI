package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.SLIDE_OV
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.freeRoom
import uz.metrx.app.furniture.middleFill
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.furniture.slideDoor
import uz.metrx.app.furniture.withCrown
import uz.metrx.app.furniture.withHandleType
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withMiddleFill
import uz.metrx.app.furniture.withPreset

/** Wardrobes drawn in the lit 3D (modern 3D part 5): kupe profiles and fills, mirrors, LED, handles, cornice. */
class WardrobeLookTest {
    private val ws = Workshop()

    /** A kupe 2400 × 2600 × 620 (three doors) as a new piece in design preset [preset] gets it. */
    private fun kupe(preset: String = "twotone"): Furniture =
        withPreset(pieceOf(fModel("s3")!!, mapOf("w" to 2400, "h" to 2600, "d" to 620), ws, "Kupe"), preset, fresh = true)

    /** A hinged wardrobe of three doors, 2400 high. */
    private fun hinged(preset: String = "twotone"): Furniture =
        withPreset(pieceOf(fModel("h3")!!, mapOf("w" to 1500, "h" to 2400, "d" to 600), ws, "Shkaf"), preset, fresh = true)

    private fun lit(f: Furniture, open: Map<String, Double> = emptyMap(), light: Boolean = false, ceil: Int? = 2700, bare: Boolean = false): Pair<Furn3D, WallBasis> {
        val b = buildShell(listOf(freeRoom(f)), true, true).bases
        val fr = furniture3D(listOf(f), b, ws, { 0xCDBFAE }, emptySet(), amt = { open[it] ?: 0.0 }, bare = bare, look = { Looks.board(0xCDBFAE) },
            mats = MAT_PRESETS, light = light, ceil = ceil)
        return fr to b.getValue(f.walls.first())
    }

    private fun Furn3D.withLook(l: Look) = parts.filter { it.look == l && it.faces.isNotEmpty() }
    private fun Furn3D.rgbMetal(rgb: Int) = parts.filter { it.look?.rgb == rgb && it.faces.isNotEmpty() }
    private fun Furn3D.glows() = parts.filter { it.look?.let { l -> l.emissive > 1f && l.alpha < 1f && l.rgb == 0xFFC98A } == true && it.faces.isNotEmpty() }
    private fun ys(p: Part) = p.faces.flatMap { f -> f.pts.map { it.y } }
    private fun along(w: WallBasis, q: V3) = (q.x - w.ox) * w.ux + (q.z - w.oz) * w.uz

    /* ---------------- kupe ---------------- */

    @Test fun kupeProfilesAreInTheHandleColour() {
        val want = mapOf("black" to 0x1E1F22, "brass" to 0xB9975B, "gold" to 0xE0B768, "chrome" to 0xECEEF1)
        for ((c, rgb) in want) {
            val f = withLook(kupe()) { it.copy(hcol = c) }
            val (fr, _) = lit(f)
            val prof = fr.rgbMetal(rgb)
            assertEquals(c, 1, prof.size)
            // the two tracks, and each of the three doors' two uprights, top and bottom rails and its split rail
            // (a chrome one is the rails' polished chrome too: one look, one part)
            if (c == "chrome") assertTrue(c, prof.single().faces.size > (2 + 3 * 5) * 6) else assertEquals(c, (2 + 3 * 5) * 6, prof.single().faces.size)
            if (c != "black") assertEquals(c, 1f, prof.single().look!!.metal)
        }
    }

    @Test fun theSplitRailSitsAtTheHatShelf() {
        val f = kupe(); val m = f.modules.single()
        val (fr, _) = lit(f)
        val (_, dh) = slideDoor(m, ws.t)
        val prof = fr.rgbMetal(0x1E1F22).single()
        // the split rails: 14 mm high bands between the top and the bottom of the doors
        val y0 = uz.metrx.app.furniture.wardBase(m) + ws.t + 20.0
        val mids = prof.faces.flatMap { it.pts }.map { it.y * 1000 - y0 }.filter { it > 500 && it < dh - 100 }.toSet()
        assertTrue(mids.isNotEmpty())
        val hat = m.sections.flatMap { s -> s.inserts.filter { it.kind == "shelf" } }.map { it.pos + ws.t / 2.0 - 20 }.filter { it >= dh * .6 && it <= dh - 250 }.maxOrNull()
        assertNotNull(hat)
        assertTrue(mids.any { kotlin.math.abs(it - (hat!! - 7)) < 1e-6 } && mids.any { kotlin.math.abs(it - (hat!! + 7)) < 1e-6 })
    }

    @Test fun mirrorsInTheirTint() {
        val want = mapOf("silver" to 0xD3DCE4, "bronze" to 0xC2A487, "graphite" to 0x9A9DA1)
        for ((t, rgb) in want) {
            val f = withLook(kupe()) { it.copy(mirror = t) }
            assertEquals("mirror", middleFill(f))
            val (fr, _) = lit(f)
            val mir = fr.parts.filter { it.look?.rgb == rgb && (it.look?.metal ?: 0f) > .3f && it.look?.rough!! < .1f }
            // the middle door's mirror below its split: one pane
            assertEquals(t, 1, mir.size); assertEquals(t, 6, mir.single().faces.size)
        }
    }

    @Test fun theMiddleDoorTakesItsFill() {
        val f0 = kupe(); val m = f0.modules.single()
        val (dw, _) = slideDoor(m, ws.t); val step = (dw - SLIDE_OV) / 1000.0
        val ax = (m.x + (if (m.sideL) ws.t else 0)) / 1000.0
        // the mirror: on the middle door only
        val (fm, w) = lit(withMiddleFill(f0, "mirror"))
        val mirror = Looks.surface(rgbOf(uz.metrx.app.furniture.MIRROR_RGB.getValue("graphite")), "mirror", null)
        val mp = fm.withLook(mirror).single()
        mp.faces.flatMap { it.pts }.forEach { q -> val a = along(w, q); assertTrue(a > ax + step - 1e-6 && a < ax + step + dw / 1000.0 + 1e-6) }
        // lacobel: in the lower fronts' colour (graphite of the two-tone preset), and no mirror
        val g = withMiddleFill(f0, "glass")
        assertEquals("glass", middleFill(g))
        val (fg, _) = lit(g)
        val front = uz.metrx.app.furniture.lookOf(g, null, "frontLow")
        assertEquals(1, fg.parts.count { it.look == Looks.lacobel.copy(rgb = rgbOf(front.rgb)) && it.faces.isNotEmpty() })
        assertTrue(fg.withLook(mirror).isEmpty())
        // the board: neither
        val (fb, _) = lit(withMiddleFill(f0, "ldsp"))
        assertTrue(fb.withLook(mirror).isEmpty())
        assertTrue(fb.parts.none { it.look?.clear == 1f && it.look?.rough == Looks.lacobel.rough && it.faces.isNotEmpty() })
    }

    @Test fun kupeDoorsSlideOnTwoTracks() {
        val f = kupe(); val m = f.modules.single()
        val (shut, w) = lit(f)
        val (open, _) = lit(f, mapOf("${m.id}:slide2" to 1.0))
        val (dw, _) = slideDoor(m, ws.t)
        fun at(fr: Furn3D, j: Int) = fr.picks.first { it.key == "${m.id}:slide$j" }.box
        // the right door slides one step left, over the middle one, in the other track
        assertEquals(-(dw - SLIDE_OV) / 1000.0, along(w, at(open, 2).o) - along(w, at(shut, 2).o), 1e-6)
        val n = { b: Obb -> (b.o.x - w.ox) * w.nx + (b.o.z - w.oz) * w.nz }
        assertTrue(n(at(shut, 1)) < n(at(shut, 2)) - .03)
        assertEquals(n(at(shut, 0)), n(at(shut, 2)), 1e-9)
        // the same parts with a door open (merged by look)
        assertEquals(shut.parts.size, open.parts.size)
    }

    /* ---------------- LED ---------------- */

    @Test fun ledOnlyWhenOnAndLitByItsDoor() {
        val f = hinged(); val m = f.modules.single()
        // no LED in the design: none drawn
        val (none, _) = lit(f)
        assertTrue(none.withLook(Looks.led).isEmpty() && none.withLook(Looks.ledOff).isEmpty())
        val on = withLook(f) { it.copy(led = true) }
        // doors shut: the strips off, no glow
        val (shut, _) = lit(on)
        assertEquals(m.sections.size * 6, shut.withLook(Looks.ledOff).single().faces.size)
        assertTrue(shut.withLook(Looks.led).isEmpty() && shut.glows().isEmpty())
        // the first section's door open: its strip lit, glowing on the back
        val (open, _) = lit(on, mapOf("${m.id}:s0:f0" to 1.0))
        assertEquals(6, open.withLook(Looks.led).single().faces.size)
        assertTrue(open.glows().isNotEmpty())
        // seeing inside: every strip lit; the light tier: no glow
        val (bare, _) = lit(on, bare = true)
        assertEquals(m.sections.size * 6, bare.withLook(Looks.led).single().faces.size)
        val (weak, _) = lit(on, mapOf("${m.id}:s0:f0" to 1.0), light = true)
        assertTrue(weak.withLook(Looks.led).isNotEmpty() && weak.glows().isEmpty())
    }

    @Test fun aVitrinasLedIsAlwaysOnOverGlassShelves() {
        val v = withPreset(pieceOf(fModel("vitrina")!!, emptyMap(), ws, "Vitrina"), "gloss", fresh = true)
        val (fr, _) = lit(v)
        assertTrue(fr.withLook(Looks.led).isNotEmpty() && fr.glows().isNotEmpty())
        assertTrue(fr.withLook(Looks.shelfGlass).isNotEmpty())
        assertTrue(fr.withLook(Looks.ledOff).isEmpty())
    }

    /* ---------------- handles, inside ---------------- */

    @Test fun longHandlesOnTallDoors() {
        val f = withHandleType(hinged(), "long")
        val sp = lit(f).first.spots
        assertTrue(sp.isNotEmpty())
        // the doors are over 1400 mm: the 1024, upright, its middle about 1 m up
        sp.values.forEach { assertEquals(1024.0, it.len, 1e-9); assertTrue(it.vertical) }
        lit(withHandleType(hinged(), "bar")).first.spots.values.forEach { assertEquals(168.0, it.len, 1e-9) }
        assertTrue(lit(withHandleType(hinged(), "knob")).first.spots.values.all { it.knob })
        // a wardrobe has no Gola: push latches, no handles
        assertTrue(lit(withHandleType(hinged(), "gola")).first.spots.isEmpty())
        // a door chosen without a handle has none
        val m = f.modules.single()
        val off = f.copy(modules = listOf(m.copy(sections = m.sections.mapIndexed { i, s -> if (i == 0) s.copy(noHandle = listOf(0)) else s })))
        assertFalse("${m.id}:s0:f0" in lit(off).first.spots)
    }

    @Test fun chromeRailsInsideAndThePainterStillGetsBoxes() {
        val f = hinged()
        assertTrue(lit(f).first.withLook(Looks.chrome).isNotEmpty())
        // the 2D painter (PieceView) reads every board as six four-cornered faces
        for (g in listOf(f, kupe(), withLook(kupe("neo")) { it.copy(led = true) })) {
            val b = buildShell(listOf(freeRoom(g)), true, true).bases
            val fr = furniture3D(listOf(g), b, ws, { 0xCDBFAE }, emptySet(), look = { Looks.board(0xCDBFAE) }, boxes = true)
            fr.parts.forEach { p -> assertEquals(0, p.faces.size % 6); assertTrue(p.faces.all { it.pts.size == 4 }) }
        }
    }

    /* ---------------- crown ---------------- */

    @Test fun corniceAndCeilingHeights() {
        val f = hinged(); val m = f.modules.single()
        val top = (uz.metrx.app.furniture.legsOf(m, ws) + m.elev + m.h) / 1000.0
        // the upper fronts' board (white in the two-tone preset) is only the crown here
        val up = uz.metrx.app.furniture.lookOf(f, null, "frontUp").let { s -> Looks.surface(rgbOf(s.rgb), s.finish, s.tex) }
        fun upParts(fr: Furn3D) = fr.withLook(up)
        assertTrue(upParts(lit(f).first).isEmpty())
        val c = upParts(lit(withCrown(f, "cornice")).first)
        assertEquals(top + .076, c.flatMap(::ys).max(), 1e-9); assertEquals(top, c.flatMap(::ys).min(), 1e-9)
        // three layers, each further out
        assertEquals(3 * 6, c.sumOf { it.faces.size })
        val ceilF = withCrown(f, "ceiling")
        assertEquals(2.696, upParts(lit(ceilF, ceil = 2700).first).flatMap(::ys).max(), 1e-9)
        assertEquals(top + .046, upParts(lit(ceilF, ceil = (top * 1000).toInt() + 50).first).flatMap(::ys).max(), 1e-9)
        // less than 20 mm under the ceiling: no panel
        assertTrue(upParts(lit(ceilF, ceil = (top * 1000).toInt() + 10).first).isEmpty())
    }
}
