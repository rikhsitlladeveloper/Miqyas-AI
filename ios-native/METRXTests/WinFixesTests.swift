import XCTest
@testable import METRX

/// The windows' fixes of 23 Oct 2026 (Android WinFixesTest, same cases and numbers): mullions between narrow sashes,
/// splitting and merging, the size card's Apply, a product of the wrong kind.
final class WinFixesTests: XCTestCase {
    private func two(_ w: Int = 1300, _ h: Int = 1400) -> WinItem { wNewItem("i", wkind("w2"), w, h) }

    func testAMullionBetweenTwoNarrowColumnsDoesNotBreak() {
        let narrow = wNewItem("i", wkind("w3"), 400, 1400)
        var anyNarrow = false
        for i in 0..<(max(1, narrow.cols.count) - 1) where narrow.cols[i].w + narrow.cols[i + 1].w < 2 * 150 { anyNarrow = true }
        XCTAssertTrue(anyNarrow)
        XCTAssertEqual(wMoveMullion(narrow, 0, 200), narrow)
        XCTAssertEqual(wSetColW(narrow, 0, 100), narrow)
        var low = narrow
        low.cols = [WCol(w: 400, rows: [WCell(h: 100), WCell(h: 100)])]
        XCTAssertEqual(wMoveTransom(low, 0, 0, 50), low)
    }

    func testSplittingStopsAtTheLeastSashAndMergingGoesDownToOne() {
        var w = two()
        for _ in 0..<10 { w = wSplitCol(w, 0) }
        XCTAssertTrue(w.cols.allSatisfy { $0.w >= W_SPLIT_MIN })
        XCTAssertTrue(wSashesOf(w).allSatisfy { $0.r.w > 0 })
        for _ in 0..<20 { w = wSplitRow(w, 0, 0) }
        XCTAssertTrue(w.cols[0].rows.allSatisfy { $0.h >= W_SPLIT_MIN })
        for _ in 0..<30 { w = wMergeAt(w, 0, 0) }
        XCTAssertEqual(wSashesOf(w).count, 1)
        XCTAssertEqual(w.cols.count, 1)
        XCTAssertEqual(w.cols.first?.w, 1300)
    }

    func testApplyingANewGapRefitsWithoutMarkingItByHand() {
        let o = Opening(id: "w1", type: "window", wall: "C", w: 1300, h: 1400, off: 600, sill: 850)
        let x = wRefit(two(), o.w, o.h, o.type)
        let texts = x.cols.map { "\($0.w)" }
        let rows = x.cols[0].rows.map { "\($0.h)" }
        // the typed W and H are as shown (from the old gap): the new gap's size stays, and it still follows its opening
        let y = wSizeApplied(x, o, x.w, x.h, 15, (texts, texts), 0, (rows, rows))
        let s = wSizeFor(o.w, o.h, o.type, 15)
        XCTAssertEqual(y.w, s.0); XCTAssertEqual(y.h, s.1)
        XCTAssertTrue(y.fit)
    }

    func testApplyingANewSizeSharesTheColumnsAgainUnlessOneWasTyped() {
        let x = two()
        let texts = x.cols.map { "\($0.w)" }
        let y = wSizeApplied(x, nil, 1500, 1400, nil, (texts, texts), 0, (["1400"], ["1400"]))
        XCTAssertEqual(y.cols.map(\.w), [750, 750])
        let z = wSizeApplied(x, nil, 1500, 1400, nil, (texts, ["500", "650"]), 0, (["1400"], ["1400"]))
        XCTAssertEqual(z.cols.map(\.w), [500, 1000])
    }

    func testAProductOfTheWrongKindForItsOpeningIsSaid() {
        var room = Room(id: "r", floorId: "w", name: "Xona")
        room.dims = ["A": Dim(v: 4000), "B": Dim(v: 3500), "H": Dim(v: 2700), "T": Dim(v: 380)]
        room.openings = [Opening(id: "w1", type: "window", wall: "C", w: 1300, h: 1400, off: 600, sill: 850)]
        var p0 = Project(id: "p", name: "T")
        p0.floors = [Workspace(id: "w", name: "Xona", type: "room")]
        p0.rooms = [room]
        p0.industry = "win"
        let c = wCtxOf(p0, "r", true)!
        let it0 = wFillOpening("a", wkind("w2"), c, c.opening("w1")!, 20)
        var ok = p0
        ok.win = WinOrder(items: [it0])
        XCTAssertFalse(wWarningsOf(ok, [wCtxOf(ok, "r", true)!], true).contains { $0.key == "dw.w.type" })
        // the opening made a door afterwards
        var door = ok
        var r2 = room
        r2.openings = [Opening(id: "w1", type: "door", wall: "C", w: 1300, h: 1400, off: 600, sill: 0)]
        door.rooms = [r2]
        XCTAssertTrue(wWarningsOf(door, [wCtxOf(door, "r", true)!], true).contains { $0.key == "dw.w.type" })
        XCTAssertFalse(wFillsType("w2", "door")); XCTAssertTrue(wFillsType("balc", "door"))
    }
}
