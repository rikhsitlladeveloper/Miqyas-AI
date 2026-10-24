import Foundation

/*
 * The ZB-08's measurements: JRT laser-module frames (decoded 24 Oct 2026, confirmed by the founder; Android laser/Jrt.kt).
 *
 *   AA | addr | reg hi reg lo | count hi count lo | 2 × count payload bytes | checksum
 *   AA   00     00     22       00       03         d3 d2 d1 d0  q1 q0       cs
 *
 * Register 0x0022 is a result: distance = big-endian uint32 in millimetres, q = signal quality.
 * cs = (sum of every byte after AA) & 0xFF. Frames may come split over notifications or several in one: the bytes are
 * buffered, the start is found again on 0xAA, and a frame with a wrong checksum gives up only its first byte.
 * Pure Swift (unit-tested); nothing here ever sends anything to the laser.
 */

/// What a run of bytes turned out to be.
enum JrtEvent: Equatable {
    /// A result frame (register 0x0022): mm the distance, quality the laser's signal quality.
    case reading(mm: Int, quality: Int, hex: String)
    /// A well-formed frame of another register (an error or a status): logged, not a measurement.
    case other(reg: Int, hex: String)
    /// A frame whose checksum is wrong.
    case badChecksum(hex: String)
    /// Bytes before a frame's start that belong to no frame.
    case skipped(hex: String)
}

final class JrtParser {
    static let start: UInt8 = 0xAA
    static let regResult = 0x0022
    static let staleMs: Int64 = 1500
    private static let head = 6
    private static let maxCount = 16
    private static let maxBuf = 256

    private var buf: [UInt8] = []
    private var lastFeed: Int64 = 0

    /// Forgets a half-received frame (a new connection).
    func reset() { buf = [] }

    /// Adds bytes and returns every whole frame now in the buffer. With now (ms), a half frame left from more than
    /// staleMs ago is dropped first: a measurement's bytes come within a few milliseconds of each other.
    func feed(_ bytes: [UInt8], now: Int64 = 0) -> [JrtEvent] {
        if now > 0 && lastFeed > 0 && now - lastFeed > JrtParser.staleMs && !buf.isEmpty { buf = [] }
        if now > 0 { lastFeed = now }
        buf.append(contentsOf: bytes)
        var out: [JrtEvent] = []
        var skipped: [UInt8] = []
        func flushSkipped() {
            if !skipped.isEmpty { out.append(.skipped(hex: JrtParser.hex(skipped))); skipped.removeAll() }
        }
        let head = JrtParser.head
        var i = 0
        while i < buf.count {
            if buf[i] != JrtParser.start { skipped.append(buf[i]); i += 1; continue }
            if buf.count - i < head { break }                    // the head is not all here yet
            let count = (Int(buf[i + 4]) << 8) | Int(buf[i + 5])
            if count > JrtParser.maxCount { skipped.append(buf[i]); i += 1; continue }   // not a frame start after all
            let len = head + 2 * count + 1
            if buf.count - i < len { break }                     // the rest comes in the next notification
            var sum = 0
            for j in (i + 1)..<(i + len - 1) { sum += Int(buf[j]) }
            let frame = Array(buf[i..<(i + len)])
            if (sum & 0xFF) != Int(buf[i + len - 1]) {
                flushSkipped()
                out.append(.badChecksum(hex: JrtParser.hex(frame)))
                i += 1
                continue
            }
            flushSkipped()
            let reg = (Int(buf[i + 2]) << 8) | Int(buf[i + 3])
            if reg == JrtParser.regResult && count >= 3 {
                let p = i + head
                var mm: Int64 = Int64(buf[p]) << 24
                mm |= Int64(buf[p + 1]) << 16
                mm |= Int64(buf[p + 2]) << 8
                mm |= Int64(buf[p + 3])
                let q = (Int(buf[p + 4]) << 8) | Int(buf[p + 5])
                let capped = Int(min(mm, Int64(Int32.max)))
                out.append(.reading(mm: capped, quality: q, hex: JrtParser.hex(frame)))
            } else {
                out.append(.other(reg: reg, hex: JrtParser.hex(frame)))
            }
            i += len
        }
        flushSkipped()
        buf = Array(buf[i...])
        if buf.count > JrtParser.maxBuf { buf = Array(buf.suffix(JrtParser.maxBuf)) }
        return out
    }

    static func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }
}
