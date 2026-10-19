package uz.metrx.app.geo

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.float
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import javax.imageio.ImageIO
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.roundToInt

/**
 * The edge finder on the shared test photos (test resources edges/, cases in edge-cases.json, read by the iPhone
 * tests too): the drawn table, door and plain wall of the approved mockup, and a frame from the emulator's camera.
 */
class EdgeFinderTest {
    /** A test photo as the app sees it: shrunk to the finder's size, grey, results in item units (1000 wide). */
    private fun detect(file: String): PhotoEdges {
        val src = ImageIO.read(javaClass.classLoader!!.getResourceAsStream("edges/$file"))
        val k = EdgeFinder.WORK.toFloat() / maxOf(src.width, src.height)
        val w = (src.width * k).roundToInt(); val h = (src.height * k).roundToInt()
        val small = BufferedImage(w, h, BufferedImage.TYPE_INT_RGB)
        small.createGraphics().apply { setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR); drawImage(src, 0, 0, w, h, null); dispose() }
        val g = FloatArray(w * h) { EdgeFinder.grey(small.getRGB(it % w, it / w)) }
        return EdgeFinder.find(g, w, h, 1000f, 1000f * src.height / src.width)
    }

    private val photos: List<JsonObject> by lazy {
        Json.parseToJsonElement(javaClass.classLoader!!.getResource("edge-cases.json")!!.readText()).jsonObject["photos"]!!.jsonArray.map { it.jsonObject }
    }
    private fun JsonObject.arr(k: String) = this[k]!!.jsonArray
    private fun pt(a: kotlinx.serialization.json.JsonElement) = a.jsonArray.let { it[0].jsonPrimitive.float to it[1].jsonPrimitive.float }
    private fun near(a: Pair<Float, Float>, b: Pair<Float, Float>, tol: Float) = hypot(a.first - b.first, a.second - b.second) <= tol

    @Test fun findsTheEdgesCornersAndRectangleOfEachPhoto() {
        for (c in photos) {
            val f = c["file"]!!.jsonPrimitive.content; val tol = c["tol"]!!.jsonPrimitive.float
            val e = detect(f)
            val r = c.arr("edges")
            assertTrue("$f: ${e.segs.size} edges", e.segs.size in r[0].jsonPrimitive.int..r[1].jsonPrimitive.int)
            c.arr("corners").forEach { p -> assertTrue("$f: corner ${pt(p)}", e.corners.any { near(it.x to it.y, pt(p), tol) }) }
            val want = c["rect"] ?: continue
            if (want is JsonNull) { assertNull("$f: no rectangle", e.rect); continue }
            val got = e.rect; assertNotNull("$f: a rectangle", got)
            assertEquals(4, got!!.pts.size)
            (want as JsonArray).forEach { p -> assertTrue("$f: rectangle corner ${pt(p)} in ${got.pts}", got.pts.any { near(it, pt(p), tol) }) }
        }
    }

    @Test fun lineEndsSnapToCornersFirstThenEdges() {
        for (c in photos) {
            val f = c["file"]!!.jsonPrimitive.content; val sn = c.arr("snaps"); if (sn.isEmpty()) continue
            val e = detect(f)
            sn.forEach { s0 ->
                val s = s0.jsonObject; val at = pt(s["at"]!!); val rr = s.arr("r"); val to = pt(s["to"]!!)
                val got = edgeSnap(e, at.first, at.second, rr[0].jsonPrimitive.float, rr[1].jsonPrimitive.float)
                val kind = when { got.snap == null -> "free"; got.snap.corner -> "corner"; else -> "edge" }
                assertEquals("$f at $at", s["kind"]!!.jsonPrimitive.content, kind)
                assertTrue("$f at $at: ${got.x},${got.y}", near(got.x to got.y, to, 6f))
            }
        }
    }

    @Test fun bothEndsOnOneEdgeLockTheLineAlongIt() {
        val c = photos.first { it.containsKey("lock") }; val lk = c["lock"]!!.jsonObject; val rr = lk.arr("r")
        val rc = rr[0].jsonPrimitive.float; val re = rr[1].jsonPrimitive.float
        val e = detect(c["file"]!!.jsonPrimitive.content)
        val a = pt(lk["a"]!!); val b = pt(lk["b"]!!)
        val sa = edgeSnap(e, a.first, a.second, rc, re); val sb = edgeSnap(e, b.first, b.second, rc, re)
        val shared = sharedEdge(sa.snap, sb.snap)
        assertNotNull("the front corners share the front edge", shared)
        val (la, lb) = lockAlong(e, sa, sb); val s = e.segs[shared!!]
        // both ends lie on the edge's line
        fun off(x: Float, y: Float) = abs((x - s.x1) * (s.y2 - s.y1) - (y - s.y1) * (s.x2 - s.x1)) / s.len
        assertEquals(0f, off(la.x, la.y), .01f); assertEquals(0f, off(lb.x, lb.y), .01f)
        // a free end does not lock
        val free = edgeSnap(e, 500f, 250f, rc, re)
        assertEquals(sa to free, lockAlong(e, sa, free))
    }

    @Test fun theRectangleOffersItsLevelSideThenTheOther() {
        for (c in photos) {
            val want = c["sides"]?.jsonArray ?: continue
            val f = c["file"]!!.jsonPrimitive.content; val tol = c["tol"]!!.jsonPrimitive.float
            val got = rectSides(detect(f).rect!!)
            assertEquals(2, got.size)
            want.forEachIndexed { i, s ->
                val (a, b) = s.jsonArray.let { pt(it[0]) to pt(it[1]) }
                assertTrue("$f side $i: ${got[i]}", near(got[i].first, a, tol) && near(got[i].second, b, tol))
            }
        }
    }

    @Test fun anEmptyOrFlatImageHasNoEdges() {
        assertEquals(PhotoEdges.NONE, EdgeFinder.find(FloatArray(0), 0, 0, 1000f, 750f))
        assertEquals(0, EdgeFinder.find(FloatArray(64 * 48) { 128f }, 64, 48, 1000f, 750f).segs.size)
    }
}
