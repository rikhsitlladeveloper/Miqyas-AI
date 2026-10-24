import XCTest
@testable import METRX

/// The ZB-08's JRT frames (Laser/LaserJrt.swift; Android JrtParserTest), with the two frames the real laser sent on
/// 24 Oct 2026.
final class LaserJrtTests: XCTestCase {
    private func bytes(_ hex: String) -> [UInt8] { hex.split(separator: " ").compactMap { UInt8($0, radix: 16) } }
    private let f128 = "AA 00 00 22 00 03 00 00 00 80 00 34 D9"
    private let f181 = "AA 00 00 22 00 03 00 00 00 B5 00 3D 17"

    private func mms(_ ev: [JrtEvent]) -> [Int] {
        ev.compactMap { e -> Int? in if case .reading(let mm, _, _) = e { return mm }; return nil }
    }
    private func quality(_ ev: [JrtEvent]) -> [Int] {
        ev.compactMap { e -> Int? in if case .reading(_, let q, _) = e { return q }; return nil }
    }

    func testTheTwoRealFrames() {
        let p = JrtParser()
        let a = p.feed(bytes(f128))
        XCTAssertEqual(mms(a), [128]); XCTAssertEqual(quality(a), [0x34])
        let b = p.feed(bytes(f181))
        XCTAssertEqual(mms(b), [181]); XCTAssertEqual(quality(b), [0x3D])
    }

    func testSplitAcrossNotifications() {
        let p = JrtParser()
        let all = bytes(f128)
        XCTAssertTrue(p.feed(Array(all[0..<1])).isEmpty)
        XCTAssertTrue(p.feed(Array(all[1..<5])).isEmpty)
        XCTAssertTrue(mms(p.feed(Array(all[5..<12]))).isEmpty)
        XCTAssertEqual(mms(p.feed(Array(all[12..<13]))), [128])
    }

    func testSplitOneByteAtATime() {
        let p = JrtParser()
        var got: [Int] = []
        for b in bytes(f181 + " " + f128) { got += mms(p.feed([b])) }
        XCTAssertEqual(got, [181, 128])
    }

    func testJoinedFrames() {
        let p = JrtParser()
        XCTAssertEqual(mms(p.feed(bytes(f128 + " " + f181 + " " + f128))), [128, 181, 128])
    }

    func testJoinedWithTheSecondSplit() {
        let p = JrtParser()
        let b = bytes(f128 + " " + f181)
        XCTAssertEqual(mms(p.feed(Array(b[0..<18]))), [128])
        XCTAssertEqual(mms(p.feed(Array(b[18...]))), [181])
    }

    func testBadChecksumIsDropped() {
        let p = JrtParser()
        let ev = p.feed(bytes("AA 00 00 22 00 03 00 00 00 80 00 34 D8"))
        XCTAssertTrue(mms(ev).isEmpty)
        XCTAssertTrue(ev.contains { if case .badChecksum = $0 { return true }; return false })
        // and the next good frame still comes through
        XCTAssertEqual(mms(p.feed(bytes(f181))), [181])
    }

    func testGarbageBeforeTheStart() {
        let p = JrtParser()
        let ev = p.feed(bytes("01 FF 00 13 37 " + f128))
        XCTAssertEqual(mms(ev), [128])
        XCTAssertEqual(ev.first, .skipped(hex: "01 FF 00 13 37"))
    }

    func testAFalseStartInsideGarbage() {
        // an AA that is not a frame (its count is far too big) gives way to the real frame after it
        let p = JrtParser()
        XCTAssertEqual(mms(p.feed(bytes("AA 12 34 56 FF FF " + f181))), [181])
    }

    func testOtherRegistersAreNotReadings() {
        let p = JrtParser()
        // register 0x0010 with one word, checksum = 00+00+10+00+01+00+05 = 0x16
        let ev = p.feed(bytes("AA 00 00 10 00 01 00 05 16 " + f128))
        XCTAssertEqual(mms(ev), [128])
        let regs = ev.compactMap { e -> Int? in if case .other(let r, _) = e { return r }; return nil }
        XCTAssertEqual(regs, [0x0010])
    }

    func testZeroIsParsedAndLeftToTheCaller() {
        // 0 mm comes out as a reading; RealLaser ignores it (sanity rule)
        let p = JrtParser()
        XCTAssertEqual(mms(p.feed(bytes("AA 00 00 22 00 03 00 00 00 00 00 00 25"))), [0])
    }

    func testBigDistance() {
        // 12 345 mm = 0x3039; checksum 22+03+30+39+00+40 = 0xCE
        let p = JrtParser()
        XCTAssertEqual(mms(p.feed(bytes("AA 00 00 22 00 03 00 00 30 39 00 40 CE"))), [12345])
    }

    func testAllOnesIsParsedButIsNoDistance() {
        // FF FF FF FF passes the checksum (25 + 4 × FF = 0x421 → 0x21) but is not a measurement: RealLaser and the router drop it
        let p = JrtParser()
        let r = mms(p.feed(bytes("AA 00 00 22 00 03 FF FF FF FF 00 00 21")))
        XCTAssertEqual(r, [Int(Int32.max)])
        XCTAssertFalse(JrtParser.plausible(r[0]))
    }

    func testTheDistanceLimits() {
        XCTAssertFalse(JrtParser.plausible(0)); XCTAssertFalse(JrtParser.plausible(-5))
        XCTAssertTrue(JrtParser.plausible(1)); XCTAssertTrue(JrtParser.plausible(128)); XCTAssertTrue(JrtParser.plausible(JrtParser.maxMm))
        XCTAssertFalse(JrtParser.plausible(JrtParser.maxMm + 1)); XCTAssertFalse(JrtParser.plausible(2_147_483_647))
    }

    func testAStaleHalfFrameIsForgotten() {
        let p = JrtParser()
        let all = bytes(f128)
        _ = p.feed(Array(all[0..<7]), now: 1_000)
        // seconds later a whole new frame: the half one left over does not spoil it
        XCTAssertEqual(mms(p.feed(bytes(f181), now: 1_000 + JrtParser.staleMs + 1)), [181])
    }
}
