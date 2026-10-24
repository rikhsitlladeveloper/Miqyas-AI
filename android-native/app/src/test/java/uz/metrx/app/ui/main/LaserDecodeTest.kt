package uz.metrx.app.ui.main

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

/** The laser test's decoders (main/LaserTest.kt): hex, ASCII and candidate distances. */
class LaserDecodeTest {
    @Test fun hexAndAscii() {
        val b = byteArrayOf(0x41, 0x00, 0x7F, 0xFF.toByte(), 0x7A)
        assertEquals("41 00 7F FF 7A", LaserDecode.hex(b))
        assertEquals("A...z", LaserDecode.ascii(b))
    }

    @Test fun fnirsiRule() {
        val b = ByteArray(23); b[14] = 0x04; b[15] = 0xD2.toByte() // 1234 mm
        assertEquals(1.234, LaserDecode.fnirsi(b)!!, 1e-9)
        assertNull(LaserDecode.fnirsi(ByteArray(15)))
    }

    @Test fun textNumbers() {
        assertEquals(listOf("1.234m = 1.234 m"), LaserDecode.textNumbers("D: 1.234m\r\n".toByteArray()))
        assertEquals(listOf("1234mm = 1.234 m"), LaserDecode.textNumbers("1234mm".toByteArray()))
        assertTrue(LaserDecode.textNumbers("12".toByteArray()).isEmpty())
        // binary data is not read as text
        assertTrue(LaserDecode.textNumbers(byteArrayOf(1, 2, 3, 0x31, 0x2E, 0x32, 4, 5, 6, 7)).isEmpty())
    }

    @Test fun shortUuids() {
        assertEquals("0x2A29 (Manufacturer)", LaserDecode.uuid(UUID.fromString("00002a29-0000-1000-8000-00805f9b34fb")))
        assertEquals("0xEE02 (FNIRSI-like notify)", LaserDecode.uuid(UUID.fromString("0000ee02-0000-1000-8000-00805f9b34fb")))
    }
}
