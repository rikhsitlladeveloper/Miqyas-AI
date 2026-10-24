package uz.metrx.app.laser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The ZB-08's JRT frames (laser/Jrt.kt), with the two frames the real laser sent on 24 Oct 2026. */
class JrtParserTest {
    private fun bytes(hex: String) = hex.split(' ').filter { it.isNotBlank() }.map { it.toInt(16).toByte() }.toByteArray()
    private val f128 = "AA 00 00 22 00 03 00 00 00 80 00 34 D9"
    private val f181 = "AA 00 00 22 00 03 00 00 00 B5 00 3D 17"
    private fun readings(ev: List<JrtEvent>) = ev.filterIsInstance<JrtEvent.Reading>()

    @Test fun theTwoRealFrames() {
        val p = JrtParser()
        val a = readings(p.feed(bytes(f128)))
        assertEquals(1, a.size); assertEquals(128, a[0].mm); assertEquals(0x34, a[0].quality)
        val b = readings(p.feed(bytes(f181)))
        assertEquals(1, b.size); assertEquals(181, b[0].mm); assertEquals(0x3D, b[0].quality)
    }

    @Test fun splitAcrossNotifications() {
        val p = JrtParser()
        val all = bytes(f128)
        assertTrue(p.feed(all.copyOfRange(0, 1)).isEmpty())
        assertTrue(p.feed(all.copyOfRange(1, 5)).isEmpty())
        assertTrue(readings(p.feed(all.copyOfRange(5, 12))).isEmpty())
        assertEquals(listOf(128), readings(p.feed(all.copyOfRange(12, 13))).map { it.mm })
    }

    @Test fun splitOneByteAtATime() {
        val p = JrtParser()
        val got = bytes("$f181 $f128").flatMap { readings(p.feed(byteArrayOf(it))) }.map { it.mm }
        assertEquals(listOf(181, 128), got)
    }

    @Test fun joinedFrames() {
        val p = JrtParser()
        assertEquals(listOf(128, 181, 128), readings(p.feed(bytes("$f128 $f181 $f128"))).map { it.mm })
    }

    @Test fun joinedWithTheSecondSplit() {
        val p = JrtParser()
        val b = bytes("$f128 $f181")
        assertEquals(listOf(128), readings(p.feed(b.copyOfRange(0, 18))).map { it.mm })
        assertEquals(listOf(181), readings(p.feed(b.copyOfRange(18, b.size))).map { it.mm })
    }

    @Test fun badChecksumIsDropped() {
        val p = JrtParser()
        val ev = p.feed(bytes("AA 00 00 22 00 03 00 00 00 80 00 34 D8"))
        assertTrue(readings(ev).isEmpty())
        assertTrue(ev.any { it is JrtEvent.BadChecksum })
        // and the next good frame still comes through
        assertEquals(listOf(181), readings(p.feed(bytes(f181))).map { it.mm })
    }

    @Test fun garbageBeforeTheStart() {
        val p = JrtParser()
        val ev = p.feed(bytes("01 FF 00 13 37 $f128"))
        assertEquals(listOf(128), readings(ev).map { it.mm })
        assertEquals("01 FF 00 13 37", (ev.first() as JrtEvent.Skipped).hex)
    }

    @Test fun aFalseStartInsideGarbage() {
        // an AA that is not a frame (its count is far too big) gives way to the real frame after it
        val p = JrtParser()
        assertEquals(listOf(181), readings(p.feed(bytes("AA 12 34 56 FF FF $f181"))).map { it.mm })
    }

    @Test fun otherRegistersAreNotReadings() {
        val p = JrtParser()
        // register 0x0010 with one word, checksum = 00+00+10+00+01+00+05 = 0x16
        val ev = p.feed(bytes("AA 00 00 10 00 01 00 05 16 $f128"))
        assertEquals(listOf(128), readings(ev).map { it.mm })
        val other = ev.filterIsInstance<JrtEvent.Other>()
        assertEquals(1, other.size); assertEquals(0x0010, other[0].reg)
    }

    @Test fun zeroIsParsedAndLeftToTheCaller() {
        // 0 mm comes out as a reading; RealLaser ignores it (sanity rule)
        val p = JrtParser()
        assertEquals(listOf(0), readings(p.feed(bytes("AA 00 00 22 00 03 00 00 00 00 00 00 25"))).map { it.mm })
    }

    @Test fun bigDistance() {
        // 12 345 mm = 0x3039; checksum 22+03+30+39+00+40 = 0xCE
        val p = JrtParser()
        assertEquals(listOf(12345), readings(p.feed(bytes("AA 00 00 22 00 03 00 00 30 39 00 40 CE"))).map { it.mm })
    }

    @Test fun allOnesIsParsedButIsNoDistance() {
        // FF FF FF FF passes the checksum (25 + 4 × FF = 0x421 → 0x21) but is not a measurement: RealLaser and the router drop it
        val p = JrtParser()
        val r = readings(p.feed(bytes("AA 00 00 22 00 03 FF FF FF FF 00 00 21")))
        assertEquals(listOf(Int.MAX_VALUE), r.map { it.mm })
        assertFalse(JrtParser.plausible(r[0].mm))
    }

    @Test fun theDistanceLimits() {
        assertFalse(JrtParser.plausible(0)); assertFalse(JrtParser.plausible(-5))
        assertTrue(JrtParser.plausible(1)); assertTrue(JrtParser.plausible(128)); assertTrue(JrtParser.plausible(JrtParser.MAX_MM))
        assertFalse(JrtParser.plausible(JrtParser.MAX_MM + 1)); assertFalse(JrtParser.plausible(2_147_483_647))
    }

    @Test fun aStaleHalfFrameIsForgotten() {
        val p = JrtParser()
        val all = bytes(f128)
        p.feed(all.copyOfRange(0, 7), now = 1_000)
        // seconds later a whole new frame: the half one left over does not spoil it
        assertEquals(listOf(181), readings(p.feed(bytes(f181), now = 1_000 + JrtParser.STALE_MS + 1)).map { it.mm })
    }
}
