package uz.metrx.app.report

/*
 * A small QR code maker for the part labels (bazis ideas, 23 Oct 2026): byte mode, error correction level M, versions
 * 1 to 6 (up to 106 bytes), the mask with the lowest penalty. Written from the QR code standard (ISO/IEC 18004); no
 * library, so the app stays offline and small. Pure Kotlin, unit-tested (QrTest).
 */

/** The modules of a QR code: [size] × [size], true for dark; row by row. */
class QrCode(val size: Int, private val dark: BooleanArray) {
    operator fun get(row: Int, col: Int) = dark[row * size + col]
}

/** Data and error-correction codewords per block, blocks, for level M of versions 1–6. */
private val M_BLOCKS = listOf(16 to 10, 28 to 16, 44 to 26, 32 to 18, 43 to 24, 27 to 16)
private val M_COUNT = listOf(1, 1, 1, 2, 2, 4)
private val ALIGN = listOf(0, 18, 22, 26, 30, 34)

/** [text] as a QR code (UTF-8 bytes), or null when longer than version 6 holds. */
fun qrOf(text: String): QrCode? {
    val bytes = text.toByteArray(Charsets.UTF_8)
    val v = (1..6).firstOrNull { (M_BLOCKS[it - 1].first * M_COUNT[it - 1]) * 8 >= 4 + 8 + bytes.size * 8 } ?: return null
    val (dataPer, eccPer) = M_BLOCKS[v - 1]; val nb = M_COUNT[v - 1]
    val cap = dataPer * nb
    // the bit stream: byte mode, the count, the bytes, a terminator, padding
    val bits = ArrayList<Boolean>()
    fun put(x: Int, n: Int) { for (i in n - 1 downTo 0) bits += (x ushr i) and 1 == 1 }
    put(4, 4); put(bytes.size, 8); bytes.forEach { put(it.toInt() and 0xFF, 8) }
    repeat(minOf(4, cap * 8 - bits.size)) { bits += false }
    while (bits.size % 8 != 0) bits += false
    val data = IntArray(cap)
    for (i in 0 until bits.size / 8) data[i] = (0 until 8).fold(0) { a, k -> (a shl 1) or (if (bits[i * 8 + k]) 1 else 0) }
    for (i in bits.size / 8 until cap) data[i] = if ((i - bits.size / 8) % 2 == 0) 0xEC else 0x11
    // error correction a block, then the blocks interleaved
    val div = rsDivisor(eccPer)
    val blocks = (0 until nb).map { b -> data.copyOfRange(b * dataPer, (b + 1) * dataPer) }
    val eccs = blocks.map { rsRemainder(it, div) }
    val all = ArrayList<Int>()
    for (i in 0 until dataPer) blocks.forEach { all += it[i] }
    for (i in 0 until eccPer) eccs.forEach { all += it[i] }
    val size = 17 + 4 * v
    val mod = BooleanArray(size * size); val fn = BooleanArray(size * size)
    fun set(r: Int, c: Int, d: Boolean) { mod[r * size + c] = d; fn[r * size + c] = true }
    for (i in 0 until size) { set(6, i, i % 2 == 0); set(i, 6, i % 2 == 0) }
    fun finder(r0: Int, c0: Int) {
        for (dr in -4..4) for (dc in -4..4) {
            val r = r0 + dr; val c = c0 + dc
            if (r in 0 until size && c in 0 until size) { val d = maxOf(kotlin.math.abs(dr), kotlin.math.abs(dc)); set(r, c, d != 2 && d != 4) }
        }
    }
    finder(3, 3); finder(3, size - 4); finder(size - 4, 3)
    if (v >= 2) { val a = ALIGN[v - 1]; for (dr in -2..2) for (dc in -2..2) set(a + dr, a + dc, maxOf(kotlin.math.abs(dr), kotlin.math.abs(dc)) != 1) }
    fun format(mask: Int) {
        // level M is 00
        val d = mask
        var rem = d
        repeat(10) { rem = (rem shl 1) xor ((rem ushr 9) * 0x537) }
        val f = ((d shl 10) or rem) xor 0x5412
        fun bit(i: Int) = (f ushr i) and 1 == 1
        for (i in 0..5) set(i, 8, bit(i))
        set(7, 8, bit(6)); set(8, 8, bit(7)); set(8, 7, bit(8))
        for (i in 9 until 15) set(8, 14 - i, bit(i))
        for (i in 0 until 8) set(8, size - 1 - i, bit(i))
        for (i in 8 until 15) set(size - 15 + i, 8, bit(i))
        set(size - 8, 8, true)
    }
    format(0)
    // the codewords up and down the columns in pairs, right to left, round the timing column
    var bi = 0
    var right = size - 1
    while (right >= 1) {
        if (right == 6) right = 5
        for (vert in 0 until size) for (j in 0..1) {
            val c = right - j
            val up = ((right + 1) and 2) == 0
            val r = if (up) size - 1 - vert else vert
            if (!fn[r * size + c] && bi < all.size * 8) { mod[r * size + c] = (all[bi ushr 3] ushr (7 - (bi and 7))) and 1 == 1; bi++ }
        }
        right -= 2
    }
    fun masked(m: Int): BooleanArray {
        val out = mod.copyOf()
        for (r in 0 until size) for (c in 0 until size) {
            if (fn[r * size + c]) continue
            val flip = when (m) {
                0 -> (r + c) % 2 == 0; 1 -> r % 2 == 0; 2 -> c % 3 == 0; 3 -> (r + c) % 3 == 0
                4 -> (r / 2 + c / 3) % 2 == 0; 5 -> r * c % 2 + r * c % 3 == 0; 6 -> (r * c % 2 + r * c % 3) % 2 == 0
                else -> ((r + c) % 2 + r * c % 3) % 2 == 0
            }
            if (flip) out[r * size + c] = !out[r * size + c]
        }
        return out
    }
    // each mask with its own format bits; the one with the lowest penalty
    var best = 0; var bestP = Int.MAX_VALUE
    for (m in 0 until 8) {
        format(m)
        val p = penalty(masked(m), size)
        if (p < bestP) { bestP = p; best = m }
    }
    format(best)
    return QrCode(size, masked(best))
}

/** The standard's penalty of a masked symbol: long runs, 2 × 2 blocks, finder-like patterns, the dark share. */
private fun penalty(m: BooleanArray, n: Int): Int {
    var p = 0
    fun at(r: Int, c: Int) = m[r * n + c]
    for (horiz in listOf(true, false)) for (i in 0 until n) {
        var run = 1
        for (j in 1 until n) {
            val a = if (horiz) at(i, j) else at(j, i); val b = if (horiz) at(i, j - 1) else at(j - 1, i)
            if (a == b) { run++; if (run == 5) p += 3 else if (run > 5) p++ } else run = 1
        }
        for (j in 0..n - 11) {
            val s = (0 until 11).map { k -> if (horiz) at(i, j + k) else at(j + k, i) }
            val a = listOf(true, false, true, true, true, false, true, false, false, false, false)
            if (s == a || s == a.reversed()) p += 40
        }
    }
    for (r in 0 until n - 1) for (c in 0 until n - 1) { val v = at(r, c); if (at(r, c + 1) == v && at(r + 1, c) == v && at(r + 1, c + 1) == v) p += 3 }
    val dark = m.count { it }
    p += kotlin.math.abs(dark * 20 - n * n * 10) / (n * n) * 10
    return p
}

private fun gfMul(x: Int, y: Int): Int {
    var z = 0
    for (i in 7 downTo 0) { z = (z shl 1) xor ((z ushr 7) * 0x11D); z = z xor (((y ushr i) and 1) * x) }
    return z
}

private fun rsDivisor(degree: Int): IntArray {
    val r = IntArray(degree); r[degree - 1] = 1
    var root = 1
    repeat(degree) {
        for (j in r.indices) { r[j] = gfMul(r[j], root); if (j + 1 < r.size) r[j] = r[j] xor r[j + 1] }
        root = gfMul(root, 2)
    }
    return r
}

private fun rsRemainder(data: IntArray, div: IntArray): IntArray {
    val r = IntArray(div.size)
    for (b in data) {
        val f = b xor r[0]
        for (i in 0 until r.size - 1) r[i] = r[i + 1]
        r[r.size - 1] = 0
        for (i in r.indices) r[i] = r[i] xor gfMul(div[i], f)
    }
    return r
}
