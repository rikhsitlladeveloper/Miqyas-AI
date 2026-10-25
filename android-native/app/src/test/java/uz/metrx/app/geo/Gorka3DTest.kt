package uz.metrx.app.geo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Room
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.LOOK_FABRICS
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.gorkaRoles
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.furniture.wardOfF
import uz.metrx.app.furniture.withGorkaPanel
import uz.metrx.app.furniture.withLook
import uz.metrx.app.furniture.withPreset

/** The gorka's and the big table's lit 3D (Gorka3D.kt): what is drawn, in which looks, and what the light tier leaves out. */
class Gorka3DTest {
    private val ws = Workshop()
    private val room = Room("r", "f", "Mehmonxona", dims = mapOf("A" to Dim(4800, "manual"), "B" to Dim(5400, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")))
    private val bases = buildShell(listOf(room), true).bases
    private fun piece(id: String) = pieceOf(fModel(id)!!, emptyMap(), ws, id)
    private fun scene(f: Furniture, decor: Boolean = true) = furniture3D(listOf(f), bases, ws, { 0xCDBFAE }, emptySet(), decor = decor)
    private fun looks(f: Furniture, decor: Boolean = true) = scene(f, decor).parts.mapNotNull { it.look }

    @Test fun theGorkaHasItsTvGlassAndDishes() {
        val f = piece("gorka")
        val ls = looks(f)
        // the TV: a black-glass panel with a faintly lit screen; the panel's stone slab; glass doors and shelves; dishes
        assertTrue(TV_SCREEN in ls); assertTrue(TV_SCREEN.emissive in .1f..1f); assertTrue(Looks.blackGlass in ls)
        assertTrue(ls.any { it.tex == "marble_white" })
        assertTrue(Looks.clearGlass in ls)
        assertTrue(PORCELAIN in ls)
        // no LED without it in the look
        assertFalse(Looks.led in ls)
        // the light tier leaves the dishes and the books out, and draws fewer faces
        val light = looks(f, false)
        assertFalse(PORCELAIN in light); assertTrue(TV_SCREEN in light)
        assertTrue(scene(f, false).parts.sumOf { it.faces.size } < scene(f).parts.sumOf { it.faces.size })
        // the same looks are one part (the dishes of both towers are one)
        assertEquals(1, scene(f).parts.count { it.look == PORCELAIN })
    }

    @Test fun ledSlatsMouldingsAndTheCornice() {
        val f = withLook(piece("gorka")) { it.copy(led = true, crown = "cornice") }
        val r = gorkaRoles(f)!!
        val leds = r.ups.flatMap { gorkaBox(f, it, ws, true) }.filter { it.look == Looks.led }
        assertEquals(4, leds.size)
        assertTrue(gorkaBox(f, r.base!!, ws, true).any { it.look == Looks.led }); assertTrue(gorkaBox(f, r.bridge!!, ws, true).any { it.look == Looks.led })
        assertTrue(Looks.led in looks(f))
        // the cornice: three mouldings over each tower and the bridge, in the fronts' board
        assertEquals(3, gorkaBox(f, r.ups[0], ws, false).count { it.look == null && it.role == "front" })
        assertTrue(gorkaBox(f, r.lows[0], ws, false).isEmpty())
        // slats: about one every 45 mm over the panel, in the wood accent (walnut without one)
        val slats = withGorkaPanel(f, panel = "slats")
        val p = gorkaRoles(slats)!!.panel!!
        val boxes = tvPanel(slats, p, ws)
        assertEquals(41, boxes.count { it.look?.tex == "walnut" })
        assertTrue(guest3D(slats, p, ws)!!.own)
        // mouldings: a frame of four in the fronts' board
        val mould = withGorkaPanel(f, panel = "mould")
        assertEquals(4 + 1, tvPanel(mould, gorkaRoles(mould)!!.panel!!, ws).count { it.look == null })
        // the TV is held to the panel
        val big = withGorkaPanel(piece("gorka"), tv = 85)
        val tv = tvPanel(big, gorkaRoles(big)!!.panel!!, ws).single { it.look == TV_SCREEN }
        assertTrue(tv.a1 - tv.a0 <= 1840 - 40 + 1e-6)
    }

    @Test fun theBigTableHasItsChairsAndPendant() {
        val f = withLook(withPreset(piece("dining12"), "twotone", fresh = true)) { it }
        val m = wardOfF(f)!!
        val g = guest3D(f, m, ws)!!
        assertTrue(g.own)
        val fabric = surfaceLook(uz.metrx.app.furniture.lookOf(f, m, "fabric"))
        // twelve chairs of six boxes each (seat, back, four legs), seat and back in the look's fabric (olive velvet)
        assertEquals(24, g.boxes.count { it.look == fabric })
        assertEquals(LOOK_FABRICS.first { it.key == "olive" }.rgb.removePrefix("#").toInt(16), fabric.rgb)
        // the stone-look top
        assertTrue(g.boxes.any { it.look?.tex == "marble_white" && it.y1 == m.h.toDouble() })
        // the pendant and its light on the full tier only
        assertTrue(g.boxes.any { it.look == Looks.led }); assertFalse(guest3D(f, m, ws, false)!!.boxes.any { it.look == Looks.led || it.look == PORCELAIN })
        assertEquals(24, guest3D(f, m, ws, false)!!.boxes.count { it.look == fabric })
        // the whole scene builds, the chairs merged into one part
        assertEquals(1, scene(f).parts.count { it.look == fabric })
        // an ordinary table is drawn as before
        assertNull(guest3D(piece("dining"), wardOfF(piece("dining"))!!, ws))
    }

    @Test fun texturesAreTheBundledOnes() {
        assertEquals("oak_halifax", texFile("oak_light")); assertEquals("travertine", texFile("onyx_beige")); assertEquals("fabric_boucle", texFile("boucle"))
        assertNull(texFile("fluted")); assertEquals("walnut", texFile("walnut"))
        listOf("oak_light", "oak_tobacco", "oak_golden", "oak_dark", "walnut", "wenge", "marble_white", "onyx_beige", "stone_dark", "tile_white", "boucle", "velvet", "fabric")
            .forEach { assertNotNull(it, texFile(it)?.let { f -> TEXTURES[f] }) }
    }
}
