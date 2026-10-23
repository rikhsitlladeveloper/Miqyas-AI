package uz.metrx.app.report

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** The labels' QR codes: their size by length, the fixed patterns; pictures written for a decoder to read back. */
class QrTest {
    private fun finderAt(q: QrCode, r0: Int, c0: Int): Boolean =
        (0 until 7).all { r -> (0 until 7).all { c -> q[r0 + r, c0 + c] == (r == 0 || r == 6 || c == 0 || c == 6 || (r in 2..4 && c in 2..4)) } }

    @Test fun aLabelsIdMakesASmallCodeWithItsPatterns() {
        val q = qrOf("MX-abc123-007")!!
        assertEquals(21, q.size)
        assertTrue(finderAt(q, 0, 0) && finderAt(q, 0, 14) && finderAt(q, 14, 0))
        // the timing pattern and the dark module
        assertTrue((8..12).all { q[6, it] == (it % 2 == 0) && q[it, 6] == (it % 2 == 0) })
        assertTrue(q[13, 8])
        assertEquals(25, qrOf("x".repeat(20))!!.size)
        assertEquals(41, qrOf("x".repeat(100))!!.size)
        assertNull(qrOf("x".repeat(107)))
    }

    /** Writes codes as PGM pictures under build/qr (each module 8 pixels, a quiet zone of 4) for a decoder to check. */
    @Test fun writesPicturesToDecode() {
        val dir = File("build/qr").apply { mkdirs() }
        listOf("MX-abc123-007", "MX-4f2a9c-120", "METRX label test 0123456789 Oshxona Sh1/2", "x".repeat(90)).forEachIndexed { i, s ->
            val q = qrOf(s)!!
            val k = 8; val n = (q.size + 8) * k
            val px = ByteArray(n * n) { j -> val r = j / n / k - 4; val c = j % n / k - 4; if (r in 0 until q.size && c in 0 until q.size && q[r, c]) 0 else 255.toByte() }
            File(dir, "qr$i.pgm").outputStream().use { it.write("P5\n$n $n\n255\n".toByteArray()); it.write(px) }
            File(dir, "qr$i.txt").writeText(s)
        }
    }
}
