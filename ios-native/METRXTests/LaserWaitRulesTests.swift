import XCTest
@testable import METRX

/// When a "Lazer" button waiting for the real laser stops waiting (Laser/LaserRouter.swift LaserWaitRules; Android
/// WaitRulesTest, the same cases).
final class LaserWaitRulesTests: XCTestCase {
    private let plan = Route.editor(pid: "p1", rid: "r1", mode: "plan")
    private let d3 = Route.editor(pid: "p1", rid: "r1", mode: "3d")

    func testTheEditorsPlanAnd3dAreOnePage() {
        XCTAssertEqual(LaserWaitRules.pageKey(plan), LaserWaitRules.pageKey(d3))
        XCTAssertTrue(LaserWaitRules.keeps(ownerPage: plan, ownerSheet: nil, top: d3, sheet: nil))
        XCTAssertTrue(LaserWaitRules.keeps(ownerPage: d3, ownerSheet: nil, top: plan, sheet: nil))
    }

    func testAnotherRoomOrPageIsNot() {
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: plan, ownerSheet: nil, top: .editor(pid: "p1", rid: "r2", mode: "plan"), sheet: nil))
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: plan, ownerSheet: nil, top: .root, sheet: nil))
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: .markup(pid: "p1", iid: "i1"), ownerSheet: nil, top: .markup(pid: "p1", iid: "i2"), sheet: nil))
    }

    func testAProjectsViewsAndTabsAreOnePage() {
        let rooms = Route.project(id: "p1", tab: "rooms")
        let other = Route.project(id: "p1", tab: "estimate", view: "3d", floor: "f2")
        XCTAssertTrue(LaserWaitRules.keeps(ownerPage: rooms, ownerSheet: nil, top: other, sheet: nil))
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: rooms, ownerSheet: nil, top: .project(id: "p2", tab: "rooms"), sheet: nil))
    }

    func testAButtonPressedInASheetStopsWhenTheSheetCloses() {
        let top = Route.fPlace(pid: "p1", fid: "f1", rid: "r1")
        let point = Sheet.pointForm(pid: "p1", rid: "r1", wall: "A", id: nil)
        XCTAssertTrue(LaserWaitRules.keeps(ownerPage: top, ownerSheet: point, top: top, sheet: point))
        // closed, or another sheet in its place
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: top, ownerSheet: point, top: top, sheet: nil))
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: top, ownerSheet: point, top: top, sheet: .device))
        let dim = Sheet.mkDim(eid: "e1")
        let mk = Route.markup(pid: nil, iid: "i1")
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: mk, ownerSheet: dim, top: mk, sheet: nil))
        XCTAssertFalse(LaserWaitRules.keeps(ownerPage: mk, ownerSheet: dim, top: mk, sheet: .mkDim(eid: "e2")))
    }

    func testAButtonOnThePageKeepsWaitingWhenASheetOpensOverIt() {
        XCTAssertTrue(LaserWaitRules.keeps(ownerPage: plan, ownerSheet: nil, top: plan, sheet: .device))
        XCTAssertTrue(LaserWaitRules.keeps(ownerPage: plan, ownerSheet: nil, top: plan, sheet: .measure(pid: "p1", rid: "r1", k: "A")))
    }
}
