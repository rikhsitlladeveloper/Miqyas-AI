package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.GALLERY
import uz.metrx.app.furniture.HANDLE_RGB
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.MIRROR_RGB
import uz.metrx.app.furniture.Pose
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.freeRoom
import uz.metrx.app.furniture.lookHardware
import uz.metrx.app.furniture.lookOf
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withPreset
import kotlin.math.hypot

/** Beds, tables, mirror panels and the basin in the lit 3D (modern 3D part 6b, geo/Items3D.kt). */
class ItemsLookTest {
    private val ws = Workshop()

    private fun piece(id: String, vals: Map<String, Int> = emptyMap(), preset: String? = "twotone"): Furniture {
        val f = pieceOf(fModel(id)!!, vals, ws, id)
        return if (preset != null) withPreset(f, preset, fresh = true) else f
    }

    /** The lit 3D as the designers and the gallery cards show it (the design's looks from the workshop's materials). */
    private fun lit(f: Furniture, light: Boolean = false, open: Set<String> = emptySet()): Furn3D {
        val sh = buildShell(listOf(freeRoom(f)), true)
        return furniture3D(listOf(f), sh.bases, ws, { 0xCDBFAE }, open, look = { Looks.board(0xCDBFAE) }, mats = MAT_PRESETS, light = light)
    }

    private fun faces(d: Furn3D) = d.parts.sumOf { it.faces.size }
    private fun facesOf(d: Furn3D, lk: Look) = d.parts.filter { it.look == lk }.sumOf { it.faces.size }
    private fun pts(d: Furn3D) = d.parts.flatMap { p -> p.faces.flatMap { it.pts } }
    private fun fabric(f: Furniture) = lookOf(f, null, "fabric").let { Looks.surface(rgbOf(it.rgb), it.finish, it.tex) }
    private fun hardware(f: Furniture, part: String) = lookOf(f, null, part).let { Looks.surface(rgbOf(it.rgb), it.finish, it.tex, "hardware") }

    /* ---------------- beds ---------------- */

    @Test fun headboardStylesAddTheirCushions() {
        val bed = piece("bed")
        val by = listOf("", "vertical", "tufted", "panels").associateWith { h -> withLook(bed) { it.copy(head = h) } }
        val n = by.mapValues { (_, f) -> facesOf(lit(f), fabric(f)) }
        // a plain board headboard: the fabric is only the throw over the duvet; every soft one adds its cushions
        listOf("vertical", "tufted", "panels").forEach { assertTrue(it, n.getValue(it) > n.getValue("") + 100) }
        assertEquals(3, setOf(n["vertical"], n["tufted"], n["panels"]).size)
        // the cushions stand in front of the headboard board, over the frame
        assertTrue(lit(by.getValue("vertical")).parts.filter { it.look == fabric(bed) }.flatMap { p -> p.faces.flatMap { it.pts } }.any { it.y > bed.modules[0].h / 1000.0 + .3 })
        // channels about 150 wide, squares about 440 × 420, a tufted cushion is one with its buttons
        assertEquals(11, softCells("vertical", 1650.0, 600.0).size)
        assertEquals(4, softCells("panels", 1650.0, 600.0).size)
        assertEquals(1, softCells("tufted", 1650.0, 600.0).size)
        val btn = tuftButtons(1650.0, 600.0)
        assertTrue(btn.size > 40 && btn.all { (u, v) -> u >= 40 && u <= 1610 && v >= 40 && v <= 560 })
        // the buttons sit deepest; between them the cushion is full
        val (u, v) = btn[btn.size / 2]
        assertEquals(14.0, tuftDip(u, v, 1650.0, 600.0), 1e-6)
        assertTrue(tuftDip(u + 80, v, 1650.0, 600.0) < 1.0)
        // the light tier: a tufted cushion without its grid of pleats
        val tufted = by.getValue("tufted")
        assertTrue(facesOf(lit(tufted, light = true), fabric(tufted)) * 4 < facesOf(lit(tufted), fabric(tufted)))
    }

    @Test fun theWallPanelOnlyWhenOn() {
        val bed = withLook(piece("bed")) { it.copy(head = "vertical", panel = false, led = true) }
        val m = bed.modules[0]
        val off = lit(bed)
        val on = withLook(bed) { it.copy(panel = true) }
        val panel = lit(on)
        // the panel reaches over the headboard (its wood accent on top), the bed alone does not
        val hb = maxOf(m.opt!!.hb, m.h + 100) / 1000.0
        fun top(d: Furn3D) = d.parts.filter { (it.look?.alpha ?: 1f) >= 1f }.flatMap { p -> p.faces.flatMap { it.pts } }.maxOf { it.y }
        assertEquals(hb, top(off), 1e-6)
        assertEquals((80 + 1300 + 36) / 1000.0, top(panel), 1e-6)
        // no LED without the panel; with it a strip and its glow on the wall (none on the light tier)
        assertEquals(0, facesOf(off, Looks.led))
        assertTrue(facesOf(panel, Looks.led) > 0)
        fun glow(d: Furn3D) = d.parts.filter { (it.look?.alpha ?: 1f) < 1f && (it.look?.emissive ?: 0f) > 1f }.sumOf { it.faces.size }
        assertEquals(0, glow(off)); assertTrue(glow(panel) > 0); assertEquals(0, glow(lit(on, light = true)))
        // as Look.kt prices it, (W + 800) × 1300, and cut to the wall; none on a bed pulled out into the room
        assertNull(bedPanel(m, false))
        bedPanel(m, true)!!.let { assertEquals(-400.0, it.u0, 1e-9); assertEquals(m.w + 400.0, it.u1, 1e-9); assertEquals(1300.0, it.v1 - it.v0, 1e-9) }
        bedPanel(m, true, -10.0, m.w + 10.0)!!.let { assertEquals(-10.0, it.u0, 1e-9); assertEquals(m.w + 10.0, it.u1, 1e-9) }
        val out = on.copy(pose = Pose("A", 500, 600))
        assertEquals(hb, top(lit(out)), 1e-6)
        // the price takes the panel the 3D draws (one rule, Look.kt bedPanelSpan): its LED strip as long as the drawn one
        val span = uz.metrx.app.furniture.bedPanelOf(on, m)!!
        assertEquals(Math.round(span.a1 - span.a0).toInt(), lookHardware(on, ws)["led"])
        val ledX = panel.parts.filter { it.look == Looks.led }.flatMap { p -> p.faces.flatMap { it.pts } }.map { it.x }
        assertEquals((span.a1 - span.a0) / 1000, ledX.max() - ledX.min(), 1e-6)
        assertEquals(span.area, lookHardware(on, ws)["softPanel"])
        assertNull(lookHardware(withLook(on) { it.copy(led = false) }, ws)["led"])
        // the panel follows the headboard: squares behind channels or tufting, channels behind squares
        assertEquals("panels", wallPanelKind("vertical")); assertEquals("panels", wallPanelKind("tufted")); assertEquals("vertical", wallPanelKind("panels"))
    }

    @Test fun legsOrAHiddenBase() {
        val bed = piece("bed", mapOf("bt" to 0))
        val hidden = lit(withLook(bed) { it.copy(legs = false) })
        val metal = withLook(bed) { it.copy(legs = true) }
        val legs = lit(metal)
        val leg = hardware(metal, "legs")
        assertTrue(facesOf(hidden, BED_BASE) > 0); assertEquals(0, facesOf(hidden, leg))
        assertTrue(facesOf(legs, leg) > 0); assertEquals(0, facesOf(legs, BED_BASE))
        // the legs in the handles' colour
        val gold = withLook(metal) { it.copy(hcol = "gold") }
        assertTrue(facesOf(lit(gold), Looks.metalOf(rgbOf(HANDLE_RGB.getValue("gold")))) > 0)
        // a bed with drawers stands on its boards: neither
        val dr = withLook(piece("bed", mapOf("bt" to 1))) { it.copy(legs = true) }
        val d = lit(dr)
        // (its drawers' handles are of the legs' metal: nothing of it near the floor)
        fun low(x: Furn3D, lk: Look) = x.parts.filter { it.look == lk }.flatMap { p -> p.faces.flatMap { it.pts } }.count { it.y < .03 }
        assertEquals(0, facesOf(d, BED_BASE)); assertEquals(0, low(d, hardware(dr, "legs")))
        assertTrue(low(legs, leg) > 0)
        assertEquals(4, d.keys.count { ":bd" in it })
        // the bedding: a duvet and a sheet's pillows on the full tier, the mattress and pillows only on the light one
        assertTrue(facesOf(hidden, DUVET) > 0 && facesOf(hidden, LINEN) > 0)
        val low = lit(bed, light = true)
        assertEquals(0, facesOf(low, DUVET)); assertTrue(facesOf(low, LINEN) > 0)
        assertTrue(faces(low) < faces(lit(bed)))
    }

    @Test fun aLiftUpBedStillRisesWithItsSlatsAndBedding() {
        val bed = piece("bed", mapOf("bt" to 2))
        val shut = lit(bed)
        val key = shut.keys.single { it.endsWith(":lift") }
        val open = lit(bed, open = setOf(key))
        assertTrue(pts(open).maxOf { it.y } > pts(shut).maxOf { it.y } + .5)
        assertEquals(shut.parts.size, open.parts.size)
        // the slats: many boards of birch, not one
        assertTrue(facesOf(shut, Looks.lamel) >= 6 * 15)
    }

    @Test fun bunkAndLoftLaddersInTheAccent() {
        for (id in listOf("bunk", "loft")) {
            val f = piece(id)
            val acc = lookOf(f, null, "accent").let { Looks.surface(rgbOf(it.rgb), it.finish, it.tex) }
            val d = lit(f)
            assertTrue(id, facesOf(d, acc) > 0)
            // with metal: a ladder of tubes in the handles' colour
            val m = withLook(f) { it.copy(legs = true) }
            assertTrue(id, facesOf(lit(m), hardware(m, "legs")) > 0)
        }
    }

    /* ---------------- tables ---------------- */

    @Test fun tableTopsInTheirDecorAndRoundWhereChosen() {
        val t0 = piece("dining", mapOf("tp" to 1))
        val tab = t0.copy(mats = t0.mats.copy(top = "wt38m"))
        fun slab(f: Furniture) = lit(f).parts.filter { it.slab && it.faces.isNotEmpty() }
        assertEquals("marble_white", slab(tab).single().look!!.tex)
        assertEquals("oak_golden", slab(tab.copy(mats = tab.mats.copy(top = "wt38c"))).single().look!!.tex)
        // the corners: the soft corner of a square top, rounded ones where chosen
        val m = tab.modules[0]
        val sh = buildShell(listOf(freeRoom(tab)), true)
        val corner = sh.bases.getValue(m.wall!!).at(m.x / 1000.0, m.h / 1000.0, 0.0)
        fun nearest(f: Furniture) = slab(f).flatMap { p -> p.faces.flatMap { it.pts } }.minOf { hypot(it.x - corner.x, it.z - corner.z) }
        assertTrue(nearest(tab) < .005)
        val round = tab.copy(modules = tab.modules.map { it.copy(opt = it.opt!!.copy(round = true)) })
        assertTrue(nearest(round) > .03)
        // a top of the fronts' board is no worktop slab; metal legs in the handles' colour
        val board = piece("dining", mapOf("tp" to 0, "lg" to 1))
        assertTrue(slab(board).isEmpty())
        assertTrue(facesOf(lit(board), hardware(board, "legs")) > 0)
    }

    /* ---------------- bathroom, hall ---------------- */

    @Test fun bathroomUnitsInTheHandlesColour() {
        val v = piece("sinkV", preset = "neo")
        val d = lit(v)
        val gold = Looks.metalOf(rgbOf(HANDLE_RGB.getValue("gold")))
        assertTrue(d.spots.isNotEmpty() && d.spots.values.all { it.knob })
        assertTrue(facesOf(d, gold) > 0)
        // the basin white ceramic, its tap in the handles' colour: black handles, a black tap
        assertTrue(facesOf(d, CERAMIC) > 0)
        val black = withLook(v) { it.copy(hcol = "black") }
        val db = lit(black)
        assertEquals(0, facesOf(db, gold))
        assertTrue(facesOf(db, hardware(black, "handle")) > 0)
        val noHandles = black.copy(modules = black.modules.map { uz.metrx.app.furniture.allHandles(it, false) })
        assertTrue(facesOf(lit(noHandles), hardware(black, "handle")) in 1 until facesOf(db, hardware(black, "handle")))
        // the mirror cabinet's mirror in its tint
        val mc = withLook(piece("mirrorC")) { it.copy(mirror = "bronze") }
        assertTrue(lit(mc).parts.any { it.faces.isNotEmpty() && it.look?.rgb == rgbOf(MIRROR_RGB.getValue("bronze")) })
    }

    @Test fun aMirrorPanelsHooksAreMetal() {
        val p = piece("mirrorP")
        val d = lit(p)
        val hk = hardware(p, "handle")
        assertTrue(facesOf(d, hk) > 0)
        // no handle colour chosen: steel
        val plain = piece("mirrorP", preset = null)
        assertTrue(facesOf(lit(plain), Looks.steel) > 0)
        assertNotEquals(hk, Looks.steel)
    }

    @Test fun everyGalleryPieceBuildsInTheLit3D() {
        GALLERY.flatMap { it.second }.forEach { id ->
            for (light in listOf(false, true)) {
                val f = piece(id)
                val shut = lit(f, light)
                assertTrue(id, faces(shut) > 0)
                pts(shut).forEach { q -> assertTrue(id, q.x.isFinite() && q.y.isFinite() && q.z.isFinite()) }
                shut.parts.forEach { p -> p.faces.forEach { fc -> assertTrue(id, fc.n.len() > .99 && fc.pts.size >= 3) } }
                val open = lit(f, light, shut.keys.toSet())
                pts(open).forEach { q -> assertTrue(id, q.x.isFinite() && q.y.isFinite() && q.z.isFinite()) }
                assertFalse(id, shut.parts.isEmpty())
            }
        }
    }
}
