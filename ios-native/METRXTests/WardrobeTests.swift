import XCTest
@testable import METRX

/// Wardrobe rules (furniture plan section 8; Android WardrobeTest) on the design's wardrobe: a 2420 niche,
/// 2400 × 2500 × 600 on a plinth.
final class WardrobeTests: XCTestCase {
    private let ws = Workshop()
    private func keys(_ c: [FCheck]) -> Set<String> { Set(c.map(\.key)) }

    func testLockedSectionsKeepTheirWidth() {
        let s = splitSections(2400, [Section(0), Section(450, lock: true), Section(0), Section(0)])
        XCTAssertEqual(s.map(\.w), [650, 450, 650, 650])
        XCTAssertEqual(splitSections(1801, Array(repeating: Section(0), count: 3)).map(\.w), [600, 600, 601])
        XCTAssertEqual(sectionsFor(2400), 4); XCTAssertEqual(sectionsFor(1200), 2); XCTAssertEqual(sectionsFor(700), 1)
    }

    func testABuiltInWardrobeHasNoSidesAtTheWalls() {
        let m = wardrobeTemplate(ws, "D", W_GAP_SIDE, 2400, 2500, builtIn: true)
        XCTAssertEqual(m.sections.count, 4); XCTAssertEqual(m.sections.reduce(0) { $0 + $1.w }, 2400)
        let ps = partsOf(m, ws)
        XCTAssertFalse(ps.contains { $0.key == "fp.side" })
        XCTAssertEqual(ps.filter { $0.key == "fp.top" }.map(\.L), [2400])           // top and bottom run wall to wall
        XCTAssertEqual(ps.filter { $0.key == "fp.divider" }.map(\.L), [2388])       // 2500 − plinth 80 − 2 × 16
        XCTAssertEqual(wardInner(m, m.sections, 0, 16), 600 - 8)                    // no side at the wall, half a divider
        var free = m; free.sideL = true; free.sideR = true
        XCTAssertEqual(partsOf(free, ws).filter { $0.key == "fp.side" }.map(\.qty), [2])
        XCTAssertEqual(wardInner(free, free.sections, 0, 16), 600 - 16 - 8)
        XCTAssertTrue(ps.filter { $0.key == "fp.door" }.allSatisfy { $0.L == 2417 })   // doors from the bottom panel up
    }

    func testInsertsFindTheirPlace() {
        let ih = wardInnerH(Module(id: "m", type: "wardrobe", w: 600, h: 2500, d: 600, legs: false), 16)
        XCTAssertEqual(ih, 2388)
        let s0 = Section(600)
        XCTAssertEqual(nextPos("drawer", s0, ih, 16), 0)
        var s1 = s0; s1.inserts = [Insert("drawer", pos: 0, h: 200), Insert("drawer", pos: 200, h: 200)]
        XCTAssertEqual(nextPos("drawer", s1, ih, 16), 400)
        XCTAssertEqual(nextPos("shelf", s1, ih, 16), (400 + ih) / 2)              // the middle of the tallest free space
        XCTAssertEqual(nextPos("rail", s0, ih, 16), ih - 80)
        var s2 = s1; s2.inserts += Array(repeating: Insert("shelf"), count: 3)
        XCTAssertEqual(spreadShelves(s2, ih, 16).inserts.filter { $0.kind == "shelf" }.map(\.pos), [400 + 493, 400 + 2 * 493, 400 + 3 * 493])
    }

    func testChecksFindWhatDoesNotFit() {
        let m = wardrobeTemplate(ws, "D", 10, 2400, 2500, builtIn: true)
        XCTAssertTrue(wardrobeChecks(m, 2420, 2520, ws, [], []).isEmpty)
        var wide = m; wide.w = 2500; wide.x = 0
        let c = wardrobeChecks(wide, 2420, 2450, ws, [Opening(id: "o", type: "door", wall: "D", w: 900, h: 2100, off: 1500, sill: 0)],
                               [SitePoint(id: "s", t: "socket", wall: "D", off: 300, h: 300)])
        XCTAssertEqual(keys(c), ["wc.wide", "wc.high", "wc.sum", "kc.door", "kc.socket"])
        XCTAssertEqual(c.first { $0.key == "wc.wide" }?.vars["v"], AnyHashable(80))
        // a rail with too little room under it, a drawer through a shelf, a wide door
        let s = Section(1100, fronts: Fronts("door", 1), inserts: [Insert("shelf", pos: 1000), Insert("rail", pos: 1700), Insert("drawer", pos: 900, h: 200)])
        let one = Module(id: "w", type: "wardrobe", w: 1100, h: 2500, d: 600, wall: "A", sections: [s], legs: false)
        XCTAssertEqual(keys(wardrobeChecks(one, nil, nil, ws, [], [])), ["wc.shelfWide", "wc.doorWide", "wc.overlap", "wc.hang"])
        var ok = one; ok.sections = [Section(1100, fronts: Fronts("door", 2))]
        XCTAssertFalse(wardrobeChecks(ok, nil, nil, ws, [], []).contains { $0.level == "err" })
    }

    func testTheLiftIsHardware() {
        let m = Module(id: "w", type: "wardrobe", w: 900, h: 2500, d: 600, sections: [Section(900, fronts: Fronts("open", 0), inserts: [Insert("lift", pos: 1500)])], legs: false)
        XCTAssertEqual(hardwareOf(m, ws)["lift"], 1)
        XCTAssertTrue(HW_PRESETS.contains { $0.kind == "lift" })
    }

    func testANewWardrobeKeepsClearOfTheDoor() {
        let a = placeOn(2420, "D", [], 2500)
        XCTAssertEqual([a.x, a.w], [10, 2400]); XCTAssertTrue(a.builtIn)
        let door = [Opening(id: "o", type: "door", wall: "D", w: 900, h: 2100, off: 1500, sill: 0)]
        let f = freeSpan(2600, "D", door, 2500)
        XCTAssertEqual([f.0, f.1], [0, 1500])
        let b = placeOn(2600, "D", door, 2500)
        XCTAssertEqual([b.x, b.w], [10, 1440]); XCTAssertFalse(b.builtIn)
    }
}
