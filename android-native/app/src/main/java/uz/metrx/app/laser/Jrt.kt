package uz.metrx.app.laser

/*
 * The ZB-08's measurements: JRT laser-module frames (decoded 24 Oct 2026, confirmed by the founder).
 *
 *   AA | addr | reg hi reg lo | count hi count lo | 2 × count payload bytes | checksum
 *   AA   00     00     22       00       03         d3 d2 d1 d0  q1 q0       cs
 *
 * Register 0x0022 is a result: distance = big-endian uint32 in millimetres, q = signal quality.
 * cs = (sum of every byte after AA) & 0xFF. Frames may come split over notifications or several in one: the bytes are
 * buffered, the start is found again on 0xAA, and a frame with a wrong checksum gives up only its first byte.
 * Pure Kotlin (unit-tested); nothing here ever sends anything to the laser.
 */

/** What a run of bytes turned out to be. */
sealed interface JrtEvent {
    /** A result frame (register 0x0022): [mm] the distance, [quality] the laser's signal quality. */
    data class Reading(val mm: Int, val quality: Int, val hex: String) : JrtEvent
    /** A well-formed frame of another register (an error or a status): logged, not a measurement. */
    data class Other(val reg: Int, val hex: String) : JrtEvent
    /** A frame whose checksum is wrong. */
    data class BadChecksum(val hex: String) : JrtEvent
    /** Bytes before a frame's start that belong to no frame. */
    data class Skipped(val hex: String) : JrtEvent
}

class JrtParser {
    private var buf = ByteArray(0)
    private var lastFeed = 0L

    /** Forgets a half-received frame (a new connection). */
    fun reset() { buf = ByteArray(0) }

    /**
     * Adds [bytes] and returns every whole frame now in the buffer. With [now] (ms), a half frame left from more than
     * [STALE_MS] ago is dropped first: a measurement's bytes come within a few milliseconds of each other.
     */
    fun feed(bytes: ByteArray, now: Long = 0L): List<JrtEvent> {
        if (now > 0 && lastFeed > 0 && now - lastFeed > STALE_MS && buf.isNotEmpty()) buf = ByteArray(0)
        if (now > 0) lastFeed = now
        buf += bytes
        val out = ArrayList<JrtEvent>()
        var i = 0
        val skipped = ArrayList<Byte>()
        fun flushSkipped() { if (skipped.isNotEmpty()) { out += JrtEvent.Skipped(hex(skipped.toByteArray())); skipped.clear() } }
        while (i < buf.size) {
            if (u(buf[i]) != START) { skipped += buf[i]; i++; continue }
            if (buf.size - i < HEAD) break                       // the head is not all here yet
            val count = (u(buf[i + 4]) shl 8) or u(buf[i + 5])
            if (count > MAX_COUNT) { skipped += buf[i]; i++; continue }   // not a frame start after all
            val len = HEAD + 2 * count + 1
            if (buf.size - i < len) break                        // the rest comes in the next notification
            var sum = 0
            for (j in i + 1 until i + len - 1) sum += u(buf[j])
            val frame = buf.copyOfRange(i, i + len)
            if ((sum and 0xFF) != u(buf[i + len - 1])) { flushSkipped(); out += JrtEvent.BadChecksum(hex(frame)); i++; continue }
            flushSkipped()
            val reg = (u(buf[i + 2]) shl 8) or u(buf[i + 3])
            out += if (reg == REG_RESULT && count >= 3) {
                val p = i + HEAD
                val mm = (u(buf[p]).toLong() shl 24) or (u(buf[p + 1]).toLong() shl 16) or (u(buf[p + 2]).toLong() shl 8) or u(buf[p + 3]).toLong()
                val q = (u(buf[p + 4]) shl 8) or u(buf[p + 5])
                JrtEvent.Reading(mm.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(), q, hex(frame))
            } else JrtEvent.Other(reg, hex(frame))
            i += len
        }
        flushSkipped()
        buf = buf.copyOfRange(i, buf.size)
        if (buf.size > MAX_BUF) buf = buf.copyOfRange(buf.size - MAX_BUF, buf.size)
        return out
    }

    companion object {
        const val START = 0xAA
        const val REG_RESULT = 0x0022
        private const val HEAD = 6
        private const val MAX_COUNT = 16
        private const val MAX_BUF = 256
        const val STALE_MS = 1500L
        private fun u(b: Byte) = b.toInt() and 0xFF
        fun hex(b: ByteArray): String = b.joinToString(" ") { "%02X".format(it.toInt() and 0xFF) }
    }
}
