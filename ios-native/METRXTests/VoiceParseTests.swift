import XCTest
@testable import METRX

/// Spoken sizes to millimetres (UX upgrades section 9): every case of the shared list design/ux-upgrades/voice-cases.json,
/// which the Android unit tests run too.
final class VoiceParseTests: XCTestCase {
    private struct Case: Decodable { let lang: String; let text: String; let mm: Int? }

    func testSharedCases() throws {
        let url = try XCTUnwrap(Bundle(for: VoiceParseTests.self).url(forResource: "voice-cases", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(cases.count, 20)
        for c in cases { XCTAssertEqual(VoiceParse.mm(c.text), c.mm, "\(c.lang): \(c.text)") }
    }

    func testMoreWays() {
        XCTAssertEqual(VoiceParse.mm("3 400"), 3400)
        XCTAssertEqual(VoiceParse.mm("3,4 metr"), 3400)
        XCTAssertEqual(VoiceParse.mm("2.5"), 2500)
        XCTAssertEqual(VoiceParse.mm("3400 mm"), 3400)
        XCTAssertEqual(VoiceParse.mm("Уч минг тўрт юз."), 3400)
        XCTAssertEqual(VoiceParse.mm("uch ming to'rt yuz"), 3400)
        XCTAssertEqual(VoiceParse.mm("Три тысячи четыреста миллиметров"), 3400)
        XCTAssertNil(VoiceParse.mm(""))
    }
}
