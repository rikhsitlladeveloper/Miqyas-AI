import XCTest
@testable import METRX

/// The labels' QR codes (Report/QrCode.swift; Android QrTest): their size by length, the fixed patterns; pictures
/// written for a decoder to read back.
final class QrTests: XCTestCase {
    private func finderAt(_ q: QrCode, _ r0: Int, _ c0: Int) -> Bool {
        for r in 0..<7 {
            for c in 0..<7 {
                let ring = r == 0 || r == 6 || c == 0 || c == 6
                let core = r >= 2 && r <= 4 && c >= 2 && c <= 4
                if q[r0 + r, c0 + c] != (ring || core) { return false }
            }
        }
        return true
    }

    func testALabelsIdMakesASmallCodeWithItsPatterns() {
        guard let q = qrOf("MX-abc123-007") else { return XCTFail("no code") }
        XCTAssertEqual(q.size, 21)
        XCTAssertTrue(finderAt(q, 0, 0) && finderAt(q, 0, 14) && finderAt(q, 14, 0))
        // the timing pattern and the dark module
        XCTAssertTrue((8...12).allSatisfy { q[6, $0] == ($0 % 2 == 0) && q[$0, 6] == ($0 % 2 == 0) })
        XCTAssertTrue(q[13, 8])
        XCTAssertEqual(qrOf(String(repeating: "x", count: 20))?.size, 25)
        XCTAssertEqual(qrOf(String(repeating: "x", count: 100))?.size, 41)
        XCTAssertNil(qrOf(String(repeating: "x", count: 107)))
    }

    /// Writes codes as PGM pictures in the temporary folder (each module 8 pixels, a quiet zone of 4) for a decoder to check.
    func testWritesPicturesToDecode() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qr")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let texts = ["MX-abc123-007", "MX-4f2a9c-120", "METRX label test 0123456789 Oshxona Sh1/2", String(repeating: "x", count: 90)]
        for (i, s) in texts.enumerated() {
            guard let q = qrOf(s) else { return XCTFail("no code for \(s)") }
            let k = 8, n = (q.size + 8) * k
            var px = [UInt8](repeating: 255, count: n * n)
            for j in 0..<(n * n) {
                let r = j / n / k - 4, c = j % n / k - 4
                if r >= 0 && r < q.size && c >= 0 && c < q.size && q[r, c] { px[j] = 0 }
            }
            var data = Data("P5\n\(n) \(n)\n255\n".utf8)
            data.append(contentsOf: px)
            try data.write(to: dir.appendingPathComponent("qr\(i).pgm"))
            try Data(s.utf8).write(to: dir.appendingPathComponent("qr\(i).txt"))
        }
    }
}
