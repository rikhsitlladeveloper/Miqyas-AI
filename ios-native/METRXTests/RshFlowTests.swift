import XCTest
@testable import METRX

/// The room-shape flow's draft (Rooms/RshModel.swift): the field's "put in" value, the letters, the errors in words and
/// the room it makes.
final class RshFlowTests: XCTestCase {
    func testAFreshValueIsReplacedByWhatIsTyped() {
        XCTAssertEqual(rshReplaceFresh("2700", "27003"), "3")
        XCTAssertEqual(rshReplaceFresh("2700", "32700"), "3")
        XCTAssertEqual(rshReplaceFresh("2700", "27300"), "3")
        XCTAssertEqual(rshReplaceFresh("2,7", "2,73"), "3")
        XCTAssertEqual(rshReplaceFresh("2700", "270"), "")
        XCTAssertEqual(rshReplaceFresh("2700", "2700"), "2700")
    }

    func testTheDraftMakesTheRoomWithItsDoor() throws {
        let d = RshDraft(key: "k", pid: "p", trade: "furniture", kind: "kitchen", name: "Oshxona", wid: nil, fid: nil, h0: 2700)
        d.shape = "L"
        d.vals = [0: 1800, 1: 1800, 2: 2400, 3: 1800]
        let geo = rshGeo(d)
        XCTAssertTrue(geo.g.ok)
        XCTAssertEqual(geo.letters, ["A", "B", "C", "D", "E", "F"])
        d.ops = [ShapeOpening(.door, 0, 600, 900, 2100)]
        let base = Room(id: "r", floorId: "w", name: "Oshxona")
        let r = rshRoom(base, d)
        XCTAssertEqual(r.id, "r")
        XCTAssertEqual(r.shape, "poly")
        XCTAssertEqual(r.openings.count, 1)
        XCTAssertEqual(r.dim("H").v, 2700)
        // a wall worked out negative says which one, in words (the mockup's T with C 3 400: G comes out negative)
        d.shape = "T"
        let bad: [Int: Int] = [0: 4800, 1: 1400, 2: 3400, 3: 2200, 4: 1600, 5: 2200]
        let e = rshStepErr(d, bad, 5)
        XCTAssertNotNil(e)
        XCTAssertFalse(e?.hasPrefix("rsh.") ?? true)
        // the free card before its sketch is a rectangle
        d.shape = "free"
        XCTAssertEqual(specOf(d).shape, .rect)
    }

    func testTheFieldsOfAWindowEndWithItsSill() {
        XCTAssertEqual(opAsks(.window).map(\.field), [.dist, .width, .height, .sill])
        XCTAssertEqual(opAsks(.window).last?.def, 900)
        XCTAssertEqual(opFieldKey(.window, .sill), "rsh.f.sill")
        XCTAssertEqual(opFieldKey(.door, .width), "rsh.f.doorW")
    }
}
