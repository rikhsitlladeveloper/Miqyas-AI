import XCTest
@testable import METRX

/// The laser test's decoders (Main/LaserTest.swift; Android LaserDecodeTest): hex, ASCII and candidate distances.
final class LaserDecodeTests: XCTestCase {
    func testHexAndAscii() {
        let b: [UInt8] = [0x41, 0x00, 0x7F, 0xFF, 0x7A]
        XCTAssertEqual(LaserDecode.hex(b), "41 00 7F FF 7A")
        XCTAssertEqual(LaserDecode.ascii(b), "A...z")
    }

    func testFnirsiRule() {
        var b = [UInt8](repeating: 0, count: 23)
        b[14] = 0x04; b[15] = 0xD2   // 1234 mm
        XCTAssertEqual(LaserDecode.fnirsi(b) ?? 0, 1.234, accuracy: 1e-9)
        XCTAssertNil(LaserDecode.fnirsi([UInt8](repeating: 0, count: 15)))
    }

    func testTextNumbers() {
        XCTAssertEqual(LaserDecode.textNumbers(Array("D: 1.234m\r\n".utf8)), ["1.234m = 1.234 m"])
        XCTAssertEqual(LaserDecode.textNumbers(Array("1234mm".utf8)), ["1234mm = 1.234 m"])
        XCTAssertTrue(LaserDecode.textNumbers(Array("12".utf8)).isEmpty)
        // binary data is not read as text
        XCTAssertTrue(LaserDecode.textNumbers([1, 2, 3, 0x31, 0x2E, 0x32, 4, 5, 6, 7]).isEmpty)
    }

    func testShortUuids() {
        XCTAssertEqual(LaserDecode.uuid("00002a29-0000-1000-8000-00805f9b34fb"), "0x2A29 (Manufacturer)")
        XCTAssertEqual(LaserDecode.uuid("0000ee02-0000-1000-8000-00805f9b34fb"), "0xEE02 (FNIRSI-like notify)")
        // CoreBluetooth gives 16-bit UUIDs as four characters
        XCTAssertEqual(LaserDecode.uuid("2A29"), "0x2A29 (Manufacturer)")
        XCTAssertEqual(LaserDecode.uuid("0783B03E-8535-B5A0-7140-A304D2495CB8"), "0783b03e-8535-b5a0-7140-a304d2495cb8 (SPS TX (notify))")
    }
}
