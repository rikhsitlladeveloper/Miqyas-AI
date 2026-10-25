package uz.metrx.app.ui

import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.furniture.Furniture
import uz.metrx.app.furniture.GALLERY
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.fModel
import uz.metrx.app.geo.Role
import uz.metrx.app.ui.furniture.cardShell
import uz.metrx.app.ui.furniture.galleryPiece
import uz.metrx.app.ui.furniture.matsLine
import uz.metrx.app.ui.three.CARD_RENDER_VERSION
import uz.metrx.app.ui.three.CardFallback
import uz.metrx.app.ui.three.CardKey
import uz.metrx.app.ui.three.Lru
import uz.metrx.app.ui.three.Tier
import uz.metrx.app.ui.three.cardSize
import uz.metrx.app.ui.three.digest
import uz.metrx.app.ui.three.pieceDigest

/** The gallery cards' cache keys and the fall-back to the 2D painter (modern 3D part 4). */
class CardCacheTest {
    private val json = Json { encodeDefaults = false }
    private fun key(f: Furniture) = pieceDigest(json.encodeToString(Furniture.serializer(), f))
    private val base = CardKey("L", "", "twotone", "m1", "", "HIGH", "p1")

    @Test fun everyPartOfTheKeyCounts() {
        val others = listOf(base.copy(model = "I"), base.copy(size = "s0=3200"), base.copy(style = "gola"), base.copy(mats = "m2"),
            base.copy(handle = "gola"), base.copy(tier = "LOW"), base.copy(piece = "p2"), base.copy(ver = CARD_RENDER_VERSION + 1))
        others.forEach { assertNotEquals(base.id, it.id); assertNotEquals(base.file, it.file) }
        assertEquals((others.map { it.file } + base.file).size, (others.map { it.file } + base.file).toSet().size)
    }

    @Test fun theKeyIsStable() {
        assertEquals(base.id, base.copy().id)
        assertEquals(base.file, CardKey("L", "", "twotone", "m1", "", "HIGH", "p1").file)
        assertTrue(base.id.startsWith("v$CARD_RENDER_VERSION|"))
        // a safe file name: hex and the WebP ending
        assertTrue(Regex("[0-9a-f]{32}\\.webp").matches(base.file))
        assertEquals(digest("abc"), digest("abc")); assertNotEquals(digest("abc"), digest("abd"))
    }

    @Test fun aModelGivesTheSameDigestEveryTimeItIsMade() {
        val ws = Workshop()
        for ((_, ids) in GALLERY) for (id in ids) {
            val m = fModel(id) ?: continue
            // the piece's and its boxes' ids are random: numbered, they do not change the key
            assertEquals(id, key(galleryPiece(m, ws, "")), key(galleryPiece(m, ws, "")))
            assertEquals(id, key(galleryPiece(m, ws, "neo")), key(galleryPiece(m, ws, "neo")))
        }
    }

    @Test fun theStyleTheSizeAndTheWorkshopChangeTheKey() {
        val m = fModel("L")!!; val ws = Workshop()
        assertNotEquals(key(galleryPiece(m, ws, "")), key(galleryPiece(m, ws, "twotone")))
        assertNotEquals(key(galleryPiece(m, ws, "twotone")), key(galleryPiece(m, ws, "gola")))
        // the board thickness is drawn from the workshop, not kept in the piece: the materials' part of the key has it
        assertNotEquals(matsLine(MAT_PRESETS, ws), matsLine(MAT_PRESETS, ws.copy(t = 18)))
        val recoloured = MAT_PRESETS.mapIndexed { i, x -> if (i == 0) x.copy(rgb = "#123456") else x }
        assertNotEquals(matsLine(MAT_PRESETS, ws), matsLine(recoloured, ws))
        assertEquals(matsLine(MAT_PRESETS, ws), matsLine(MAT_PRESETS.toList(), ws.copy()))
    }

    @Test fun cardsAreSmallerOnTheLightTier() {
        assertEquals(480 to 360, cardSize(Tier.HIGH))
        assertEquals(320 to 240, cardSize(Tier.LOW))
    }

    @Test fun theLruKeepsTheNewestWithinItsSize() {
        val c = Lru<String, IntArray>(10) { it.size.toLong() }
        c.put("a", IntArray(4)); c.put("b", IntArray(4))
        assertEquals(8, c.bytes)
        c["a"]   // a is used: b is the oldest now
        c.put("c", IntArray(4))
        assertNull(c["b"]); assertTrue(c["a"] != null && c["c"] != null)
        assertEquals(8, c.bytes)
        // one bigger than the whole cache is still kept, alone
        c.put("big", IntArray(20)); assertEquals(1, c.size); assertTrue(c["big"] != null)
        c.put("big", IntArray(2)); assertEquals(2, c.bytes)
    }

    @Test fun theRealThreeDFirstThePainterWhenItGivesNothing() = runBlocking {
        val fb = CardFallback(maxFails = 2)
        assertEquals("3d" to true, fb.pick({ "3d" }, { "2d" }))
        assertEquals("2d" to false, fb.pick({ null }, { "2d" }))
        assertEquals(0 + 1, fb.fails)
        // a working 3D resets the count
        assertEquals("3d" to true, fb.pick({ "3d" }, { "2d" })); assertEquals(0, fb.fails)
        // a 3D that throws is the same as none
        assertEquals("2d" to false, fb.pick({ error("no GL") }, { "2d" }))
        assertEquals("2d" to false, fb.pick({ null }, { "2d" }))
        assertTrue(fb.off)
        // off: the 3D is not tried again
        var tried = false
        assertEquals("2d" to false, fb.pick({ tried = true; "3d" }, { "2d" }))
        assertFalse(tried)
        // neither: no picture (the card keeps its placeholder)
        assertNull(CardFallback().pick<String>({ null }, { error("x") }))
    }

    @Test fun aCardsSceneIsTheFloorTheWallsBehindAndThePiece() {
        val ws = Workshop()
        for (id in listOf("L", "U", "O", "h2", "bed", "cornerW")) {
            val f = galleryPiece(fModel(id)!!, ws, "twotone")
            val s = cardShell(f, ws, MAT_PRESETS)
            assertTrue(id, s.parts.any { it.role == Role.FLOOR })
            assertTrue(id, s.parts.any { it.role == Role.FURN && it.look != null })
            val walls = s.parts.filter { it.role == Role.WALL }.mapNotNull { it.wall }.toSet()
            assertTrue(id, walls.isNotEmpty() && walls.all { it in f.walls })
            assertTrue(id, s.parts.none { it.role == Role.OPENING })
        }
    }
}
