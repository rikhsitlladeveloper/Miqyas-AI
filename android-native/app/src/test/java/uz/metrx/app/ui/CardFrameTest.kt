package uz.metrx.app.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.furniture.GALLERY
import uz.metrx.app.furniture.MAT_PRESETS
import uz.metrx.app.furniture.Workshop
import uz.metrx.app.furniture.fModel
import uz.metrx.app.furniture.pieceOf
import uz.metrx.app.ui.furniture.CARD_EL
import uz.metrx.app.ui.furniture.CARD_HALF
import uz.metrx.app.ui.furniture.PieceScene
import uz.metrx.app.ui.furniture.cardCamOf
import uz.metrx.app.ui.furniture.cardFrameOf
import uz.metrx.app.ui.furniture.galleryPiece
import uz.metrx.app.ui.furniture.pieceScene
import uz.metrx.app.ui.three.CARD_FILL
import uz.metrx.app.ui.three.CARD_PIECE_MIN
import uz.metrx.app.ui.three.Tier
import uz.metrx.app.ui.three.cardShare
import uz.metrx.app.ui.three.cardSize
import uz.metrx.app.ui.three.cardSpan
import kotlin.math.atan2
import kotlin.math.sqrt

/** The gallery cards' framing (26 Oct 2026, ui/three/CardCache.kt cardFrame): every piece with the same room round it. */
class CardFrameTest {
    private val ws = Workshop()
    private fun scene(id: String) = pieceScene(galleryPiece(fModel(id)!!, ws, ""), ws, MAT_PRESETS)

    private class Shares(val fit: Double, val piece: Double, val span: DoubleArray)

    private fun shares(s: PieceScene, tier: Tier): Shares {
        val (w, h) = cardSize(tier)
        val c = cardFrameOf(s, w, h); val a = w.toDouble() / h
        return Shares(cardShare(s.cardExt, c.at, c.dist, c.back, a, CARD_HALF), cardShare(s.ext, c.at, c.dist, c.back, a, CARD_HALF),
            cardSpan(s.ext, c.at, c.dist, c.back, a, CARD_HALF)!!)
    }

    /** The coffee table, the desk, the mirror cabinet, an L kitchen and a kupe: the framed box takes 70–82% of the tighter side. */
    @Test fun smallLowAndBigPiecesGetTheSameRoom() {
        for (id in listOf("coffee", "desk", "mirrorC", "L", "s2")) for (t in listOf(Tier.HIGH, Tier.LOW)) {
            val s = shares(scene(id), t)
            println("card $id $t: framed box ${"%.3f".format(s.fit)}, boards ${"%.3f".format(s.piece)}")
            assertTrue("$id $t: ${s.fit}", s.fit in .70..(.82))
            // the boards all in the picture, with room round them
            assertTrue("$id $t", s.span.all { it > -.9 && it < .9 })
        }
    }

    /** Every gallery model: the boards in the picture with room round them, and never tiny. */
    @Test fun everyModelIsFramed() {
        for ((_, ids) in GALLERY) for (id in ids) {
            val m = fModel(id) ?: continue
            val s = shares(pieceScene(galleryPiece(m, ws, ""), ws, MAT_PRESETS), Tier.HIGH)
            println("card $id: framed box ${"%.3f".format(s.fit)}, boards ${"%.3f".format(s.piece)}")
            assertTrue("$id: ${s.span.toList()}", s.span.all { it > -.95 && it < .95 })
            assertTrue("$id: ${s.piece}", s.piece >= CARD_PIECE_MIN - .005)
            // the framed box takes CARD_FILL, more only where the boards alone would be too small
            assertTrue("$id: ${s.fit}", s.fit >= CARD_FILL - .005 && (s.fit <= CARD_FILL + .005 || s.piece <= CARD_PIECE_MIN + .005))
        }
    }

    /**
     * A 400 mm-tall nightstand still reads well: its wall's 300 mm above it would leave it small, so the camera comes in
     * until the boards take [CARD_PIECE_MIN] of the card, the wall's top cut off rather than the piece.
     */
    @Test fun aSmallNightstandStillReadsWell() {
        val m = fModel("nightstand")!!
        val low = pieceScene(pieceOf(m, mapOf("h" to 400), ws, ""), ws, MAT_PRESETS)
        assertEquals(.4, low.ext.maxOf { it.y }, .03)
        for (s in listOf(scene("nightstand"), low)) for (t in listOf(Tier.HIGH, Tier.LOW)) {
            val r = shares(s, t)
            println("card nightstand ${"%.2f".format(s.ext.maxOf { it.y })} $t: framed box ${"%.3f".format(r.fit)}, boards ${"%.3f".format(r.piece)}")
            assertTrue("${r.piece}", r.piece >= CARD_PIECE_MIN - .005)
            assertTrue("${r.fit}", r.fit >= CARD_FILL - .005)
            assertTrue(r.span.toList().toString(), r.span.all { it > -.9 && it < .9 })
        }
    }

    /** The same 3/4 angle and height as before: the camera only moves along its line of sight. */
    @Test fun theAngleStays() {
        val s = scene("desk"); val (w, h) = cardSize(Tier.HIGH)
        val c = cardCamOf(s, w, h)
        val d = c.eye - c.at; val l = sqrt(d.dot(d))
        assertEquals(CARD_EL, kotlin.math.asin(d.y / l), 1e-6)
        assertEquals(s.az0, atan2(d.x, d.z), 1e-6)
        assertEquals(32.0, c.fovDeg, 1e-9)
        assertNotNull(c)
    }
}
