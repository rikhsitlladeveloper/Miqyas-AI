import XCTest
@testable import METRX

/// The wardrobe's side panels, door hinges, base heights and inside spacing (Wardrobe.swift, Parts.swift; Android
/// WardrobeRulesTest).
final class WardrobeRulesTests: XCTestCase {
    private let ws = Workshop()

    func testSingleDoorsHingeAsChosenElseInPairs() {
        var m = wardrobeTemplate(ws, "A", W_GAP_SIDE, 1500, 2200, builtIn: false)
        m.sections = Array(repeating: Section(500, fronts: Fronts("door", 1)), count: 3)
        XCTAssertEqual(m.sections.indices.map { hingeRight(m, $0) }, [false, true, true])
        var chosen = m
        chosen.sections[1].hinge = "L"
        XCTAssertFalse(hingeRight(chosen, 1))
    }

    func testASlidingWardrobeUsesTheWallItMeetsAHingedOneKeepsItsSides() {
        var kupe = wardrobeTemplate(ws, "A", W_GAP_SIDE, 2000, 2500, builtIn: true)
        kupe.slide = Slide(2)
        // in the corner of a 3,0 m wall: no panel at the wall, one at the free end
        let corner = withSides(kupe, 3000)
        XCTAssertFalse(corner.sideL); XCTAssertTrue(corner.sideR)
        // wall to wall: none
        var wide = kupe; wide.w = 2980
        let full = withSides(wide, 3000)
        XCTAssertFalse(full.sideL); XCTAssertFalse(full.sideR)
        // standing free: both
        let free = withSides(kupe, 3000, free: true)
        XCTAssertTrue(free.sideL && free.sideR)
        let hinged = withSides(wardrobeTemplate(ws, "A", W_GAP_SIDE, 2980, 2200, builtIn: true), 3000)
        XCTAssertTrue(hinged.sideL && hinged.sideR)
    }

    func testLegsAndAPlinthHaveTheirOwnHeights() {
        let m = wardrobeTemplate(ws, "A", W_GAP_SIDE, 1500, 2200, builtIn: false)
        var tall = m; tall.base = 120
        XCTAssertEqual(wardBase(m), 80); XCTAssertEqual(wardBase(tall), 120)
        var legs = m; legs.legs = true; legs.base = 150
        XCTAssertEqual(legsOf(legs, ws), 150); XCTAssertEqual(outerH(legs, ws), legs.h + 150)
        XCTAssertEqual(wardBase(legs), 0)
        // a kitchen on its own legs: the worktop follows
        var k = newFreeKitchen("Oshxona 1", "I", "I", [3000], 0, 2700, ws)
        k.baseH = 150
        XCTAssertEqual(worktopTop(wsOf(k, ws)), worktopTop(ws) + 50)
    }

    func testReorderedInsertsSpreadEvenlyAndARailKeepsItsHangingRoom() {
        // bottom first: a drawer, a rail, a shelf in a 2000 high section
        let out = respaced([Insert("drawer", h: 200), Insert("rail"), Insert("shelf")], 2000, 16)
        for i in 1..<out.count { XCTAssertTrue(out[i - 1].pos < out[i].pos) }
        // the rail hangs at least 900 over the drawer's top
        XCTAssertTrue(out[1].pos - (out[0].pos + 200) >= 900)
        // three shelves: equal gaps
        let sh = respaced(Array(repeating: Insert("shelf"), count: 3), 1600, 16)
        var gaps = [sh[0].pos]
        for i in 1..<sh.count { gaps.append(sh[i].pos - sh[i - 1].pos - 16) }
        XCTAssertTrue(gaps.max()! - gaps.min()! <= 1)
    }
}
