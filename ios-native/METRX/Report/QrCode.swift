import Foundation

/*
 * A small QR code maker for the part labels (bazis ideas, 23 Oct 2026; Android report/Qr.kt, bit for bit): byte mode,
 * error correction level M, versions 1 to 6 (up to 106 bytes), the mask with the lowest penalty. Written from the QR
 * code standard (ISO/IEC 18004); no library, so the app stays offline and small. Unit-tested (QrTests).
 */

/// The modules of a QR code: size × size, true for dark; row by row.
struct QrCode: Equatable {
    let size: Int
    let dark: [Bool]
    subscript(_ row: Int, _ col: Int) -> Bool { dark[row * size + col] }
}

/// Data and error-correction codewords per block, blocks, for level M of versions 1–6.
private let QR_M_DATA: [Int] = [16, 28, 44, 32, 43, 27]
private let QR_M_ECC: [Int] = [10, 16, 26, 18, 24, 16]
private let QR_M_COUNT: [Int] = [1, 1, 1, 2, 2, 4]
private let QR_ALIGN: [Int] = [0, 18, 22, 26, 30, 34]

/// The QR symbol being built: its modules and which of them are fixed patterns.
private final class QrGrid {
    let size: Int
    var mod: [Bool]
    var fn: [Bool]
    init(_ size: Int) { self.size = size; mod = Array(repeating: false, count: size * size); fn = Array(repeating: false, count: size * size) }
    func set(_ r: Int, _ c: Int, _ d: Bool) { mod[r * size + c] = d; fn[r * size + c] = true }

    func finder(_ r0: Int, _ c0: Int) {
        for dr in -4...4 {
            for dc in -4...4 {
                let r = r0 + dr, c = c0 + dc
                if r >= 0 && r < size && c >= 0 && c < size {
                    let d = max(abs(dr), abs(dc))
                    set(r, c, d != 2 && d != 4)
                }
            }
        }
    }

    /// The format bits of level M with mask, both copies, and the dark module.
    func format(_ mask: Int) {
        // level M is 00
        let d = mask
        var rem = d
        for _ in 0..<10 { rem = (rem << 1) ^ ((rem >> 9) * 0x537) }
        let f = ((d << 10) | rem) ^ 0x5412
        func bit(_ i: Int) -> Bool { (f >> i) & 1 == 1 }
        for i in 0...5 { set(i, 8, bit(i)) }
        set(7, 8, bit(6)); set(8, 8, bit(7)); set(8, 7, bit(8))
        for i in 9..<15 { set(8, 14 - i, bit(i)) }
        for i in 0..<8 { set(8, size - 1 - i, bit(i)) }
        for i in 8..<15 { set(size - 15 + i, 8, bit(i)) }
        set(size - 8, 8, true)
    }

    func masked(_ m: Int) -> [Bool] {
        var out = mod
        for r in 0..<size {
            for c in 0..<size {
                if fn[r * size + c] { continue }
                let flip: Bool
                switch m {
                case 0: flip = (r + c) % 2 == 0
                case 1: flip = r % 2 == 0
                case 2: flip = c % 3 == 0
                case 3: flip = (r + c) % 3 == 0
                case 4: flip = (r / 2 + c / 3) % 2 == 0
                case 5: flip = r * c % 2 + r * c % 3 == 0
                case 6: flip = (r * c % 2 + r * c % 3) % 2 == 0
                default: flip = ((r + c) % 2 + r * c % 3) % 2 == 0
                }
                if flip { out[r * size + c] = !out[r * size + c] }
            }
        }
        return out
    }
}

/// text as a QR code (UTF-8 bytes), or nil when longer than version 6 holds.
func qrOf(_ text: String) -> QrCode? {
    let bytes: [UInt8] = Array(text.utf8)
    var v = 0
    for k in 1...6 {
        let capBits = QR_M_DATA[k - 1] * QR_M_COUNT[k - 1] * 8
        if capBits >= 4 + 8 + bytes.count * 8 { v = k; break }
    }
    if v == 0 { return nil }
    let dataPer = QR_M_DATA[v - 1], eccPer = QR_M_ECC[v - 1], nb = QR_M_COUNT[v - 1]
    let cap = dataPer * nb
    // the bit stream: byte mode, the count, the bytes, a terminator, padding
    var bits: [Bool] = []
    func put(_ x: Int, _ n: Int) {
        var i = n - 1
        while i >= 0 { bits.append((x >> i) & 1 == 1); i -= 1 }
    }
    put(4, 4); put(bytes.count, 8)
    for b in bytes { put(Int(b), 8) }
    let term = min(4, cap * 8 - bits.count)
    if term > 0 { for _ in 0..<term { bits.append(false) } }
    while bits.count % 8 != 0 { bits.append(false) }
    var data: [Int] = Array(repeating: 0, count: cap)
    let full = bits.count / 8
    for i in 0..<full {
        var a = 0
        for k in 0..<8 { a = (a << 1) | (bits[i * 8 + k] ? 1 : 0) }
        data[i] = a
    }
    if full < cap { for i in full..<cap { data[i] = (i - full) % 2 == 0 ? 0xEC : 0x11 } }
    // error correction a block, then the blocks interleaved
    let div = qrDivisor(eccPer)
    var blocks: [[Int]] = []
    for b in 0..<nb { blocks.append(Array(data[(b * dataPer)..<((b + 1) * dataPer)])) }
    let eccs: [[Int]] = blocks.map { qrRemainder($0, div) }
    var all: [Int] = []
    for i in 0..<dataPer { for b in blocks { all.append(b[i]) } }
    for i in 0..<eccPer { for e in eccs { all.append(e[i]) } }
    let size = 17 + 4 * v
    let g = QrGrid(size)
    for i in 0..<size { g.set(6, i, i % 2 == 0); g.set(i, 6, i % 2 == 0) }
    g.finder(3, 3); g.finder(3, size - 4); g.finder(size - 4, 3)
    if v >= 2 {
        let a = QR_ALIGN[v - 1]
        for dr in -2...2 { for dc in -2...2 { g.set(a + dr, a + dc, max(abs(dr), abs(dc)) != 1) } }
    }
    g.format(0)
    // the codewords up and down the columns in pairs, right to left, round the timing column
    var bi = 0
    var right = size - 1
    let total = all.count * 8
    while right >= 1 {
        if right == 6 { right = 5 }
        for vert in 0..<size {
            for j in 0...1 {
                let c = right - j
                let up = ((right + 1) & 2) == 0
                let r = up ? size - 1 - vert : vert
                if !g.fn[r * size + c] && bi < total {
                    g.mod[r * size + c] = (all[bi >> 3] >> (7 - (bi & 7))) & 1 == 1
                    bi += 1
                }
            }
        }
        right -= 2
    }
    // each mask with its own format bits; the one with the lowest penalty
    var best = 0, bestP = Int.max
    for m in 0..<8 {
        g.format(m)
        let p = qrPenalty(g.masked(m), size)
        if p < bestP { bestP = p; best = m }
    }
    g.format(best)
    return QrCode(size: size, dark: g.masked(best))
}

/// The standard's penalty of a masked symbol: long runs, 2 × 2 blocks, finder-like patterns, the dark share.
private func qrPenalty(_ m: [Bool], _ n: Int) -> Int {
    var p = 0
    func at(_ r: Int, _ c: Int) -> Bool { m[r * n + c] }
    let pat: [Bool] = [true, false, true, true, true, false, true, false, false, false, false]
    let patR: [Bool] = Array(pat.reversed())
    for horiz in [true, false] {
        for i in 0..<n {
            var run = 1
            for j in 1..<n {
                let a = horiz ? at(i, j) : at(j, i)
                let b = horiz ? at(i, j - 1) : at(j - 1, i)
                if a == b {
                    run += 1
                    if run == 5 { p += 3 } else if run > 5 { p += 1 }
                } else { run = 1 }
            }
            if n >= 11 {
                for j in 0...(n - 11) {
                    var s: [Bool] = []
                    for k in 0..<11 { s.append(horiz ? at(i, j + k) : at(j + k, i)) }
                    if s == pat || s == patR { p += 40 }
                }
            }
        }
    }
    for r in 0..<(n - 1) {
        for c in 0..<(n - 1) {
            let v = at(r, c)
            if at(r, c + 1) == v && at(r + 1, c) == v && at(r + 1, c + 1) == v { p += 3 }
        }
    }
    var dark = 0
    for x in m where x { dark += 1 }
    p += abs(dark * 20 - n * n * 10) / (n * n) * 10
    return p
}

private func qrMul(_ x: Int, _ y: Int) -> Int {
    var z = 0
    var i = 7
    while i >= 0 {
        z = (z << 1) ^ ((z >> 7) * 0x11D)
        z = z ^ (((y >> i) & 1) * x)
        i -= 1
    }
    return z
}

private func qrDivisor(_ degree: Int) -> [Int] {
    var r: [Int] = Array(repeating: 0, count: degree)
    r[degree - 1] = 1
    var root = 1
    for _ in 0..<degree {
        for j in 0..<r.count {
            r[j] = qrMul(r[j], root)
            if j + 1 < r.count { r[j] = r[j] ^ r[j + 1] }
        }
        root = qrMul(root, 2)
    }
    return r
}

private func qrRemainder(_ data: [Int], _ div: [Int]) -> [Int] {
    var r: [Int] = Array(repeating: 0, count: div.count)
    for b in data {
        let f = b ^ r[0]
        for i in 0..<(r.count - 1) { r[i] = r[i + 1] }
        r[r.count - 1] = 0
        for i in 0..<r.count { r[i] = r[i] ^ qrMul(div[i], f) }
    }
    return r
}
