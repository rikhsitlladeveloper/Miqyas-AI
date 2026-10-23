import XCTest
@testable import METRX

/// The furniture fixes of 23 Oct 2026 (Android FixesTest, same cases and numbers): a stenka's last floor piece and
/// shelves, corner arms, long parts priced, items fitted, a loft's under-part.
final class FurnitureFixesTests: XCTestCase {
    private let ws = Workshop()
    private func piece(_ id: String, _ v: [String: Int] = [:]) -> Furniture { pieceOf(fModel(id)!, v, ws, id) }
    private func with(_ f: Furniture, _ ms: [Module]) -> Furniture { var g = f; g.modules = ms; return g }

    func testAStenkaWithOnlyItsShelfLeftStillHasSizesAndKeepsItsLastFloorPiece() {
        let f = piece("stenka")
        let bs = boxes(f)
        let shelves = bs.filter { hung($0) }
        XCTAssertEqual(shelves.count, 1)
        let shelf = shelves[0]
        // an older order with every floor piece gone: its sizes are there
        let bare = with(f, f.modules.filter { $0.id == shelf.id })
        let v = valsOf(bare, ws)
        XCTAssertTrue((v["h"] ?? 0) > 0 && (v["d"] ?? 0) > 0)
        // the last floor piece cannot be taken away, a shelf always can
        let firstFloor = bs.first { !hung($0) }!
        let one = packPiece(with(f, f.modules.filter { hung($0) || $0.id == firstFloor.id }), ws: ws)
        let floorLeft = boxes(one).filter { !hung($0) }
        let shelfLeft = boxes(one).filter { hung($0) }
        XCTAssertEqual(floorLeft.count, 1); XCTAssertEqual(shelfLeft.count, 1)
        XCTAssertFalse(canDropBox(one, floorLeft[0]))
        XCTAssertTrue(canDropBox(one, shelfLeft[0]))
        XCTAssertTrue(canDropBox(f, firstFloor))
    }

    func testAStenkaShelfHangsOverALowPieceNeverATallOne() {
        let f = piece("stenka")
        let bs = boxes(f)
        let shelf = bs.first { hung($0) }!
        let lows = bs.filter { !hung($0) && $0.h < STENKA_TALL }
        XCTAssertEqual(lows.count, 1)
        let tv = lows[0]
        // moved left past the first tall cabinet in the list: still over the TV unit
        let moved = packPiece(with(f, [shelf] + f.modules.filter { $0.id != shelf.id }), ws: ws)
        let s2 = moved.modules.first { $0.id == shelf.id }!
        let tv2 = moved.modules.first { $0.id == tv.id }!
        XCTAssertEqual(s2.x, tv2.x + (tv2.w - s2.w) / 2)
        // a new shelf goes in next to the low piece, whichever box is picked
        let tvAt = bs.firstIndex { $0.id == tv.id }!
        XCTAssertEqual(stenkaShelfAt(f.modules, 0), tvAt + 1)
        XCTAssertEqual(stenkaShelfAt(f.modules, bs.count - 1), tvAt + 1)
    }

    func testCornerPiecesKeepTheTypedArmLengths() {
        XCTAssertEqual(valsOf(piece("cornerW", ["w": 1200, "d": 600]), ws)["w"], 1200)
        XCTAssertEqual(valsOf(piece("cornerW", ["w": 1000, "d": 700]), ws)["w"], 1000)
        XCTAssertEqual(valsOf(piece("cornerW"), ws)["w"], 1800)
        let desk = piece("cornerDesk", ["w2": 1100, "d": 800])
        XCTAssertEqual(valsOf(desk, ws)["w2"], 1100)
        // the corner wardrobe's arm starts in the corner when its unit takes the whole length
        let armA = boxes(piece("cornerW", ["w": 1000, "d": 700])).filter { $0.wall == "A" }
        XCTAssertEqual(armA.map(\.x).min(), W_GAP_SIDE)
    }

    func testAPartLongerThanTheSheetIsPricedAndFlagged() {
        let ok = piece("h2")
        let tall = resized(ok, ["h": 3000], ws)
        let m = wardOfF(tall)!
        let cost = costOf([tall], ws, MAT_PRESETS, HW_PRESETS)
        guard let lay = cost.layouts.first(where: { !$0.unplaced.isEmpty }) else { return XCTFail("a part longer than the sheet") }
        let board = cost.lines.filter { $0.group == "mat" && $0.key == lay.mat }
        XCTAssertEqual(board.count, 1)
        XCTAssertEqual(board.first?.qty ?? -1, Double(lay.sheets.count + lay.unplaced.count), accuracy: 0)
        XCTAssertTrue(wardrobeChecks(m, nil, nil, ws, [], []).contains { $0.key == "wc.sheet" && $0.level == "err" })
        XCTAssertFalse(wardrobeChecks(wardOfF(ok)!, nil, nil, ws, [], []).contains { $0.key == "wc.sheet" })
    }

    func testGlassDoorsHaveNoHandles() {
        let up = piece("vitrina").modules[1]
        XCTAssertEqual(up.sections.count, 1)
        XCTAssertEqual(up.sections.first?.face, "glass")
        XCTAssertNil(hardwareOf(up, ws)["handle"])
        XCTAssertTrue((hardwareOf(piece("vitrina").modules[0], ws)["handle"] ?? 0) > 0)
    }

    func testANarrowMirrorPanelKeepsItsHooksOnIt() {
        let f = piece("mirrorP", ["w": 500])
        let m = wardOfF(f)!
        let hooks = itemBoards(m, ws).filter { $0.role == "metal" && $0.a1 - $0.a0 == 16 && $0.n1 - $0.n0 == 60 }
        XCTAssertFalse(hooks.isEmpty)
        for h in hooks { XCTAssertTrue(h.a0 >= 0 && h.a1 <= m.w, "\(h.a0)..\(h.a1) on a \(m.w) panel") }
    }

    func testALoftBedsUnderPartGrowsBackWithTheFrame() {
        let f = piece("loft")
        let bed = f.modules.first { $0.type == "loft" }!
        let desk0 = f.modules.first { $0.type == "wardrobe" }!
        let small = packPiece(with(f, f.modules.map { $0.id == bed.id ? itemSized(itemSet($0, "ml", 1600, ws), ws) : $0 }), changed: bed.id, ws: ws)
        let big = packPiece(with(small, small.modules.map { $0.id == bed.id ? itemSized(itemSet($0, "ml", 2000, ws), ws) : $0 }), changed: bed.id, ws: ws)
        XCTAssertEqual(big.modules.first { $0.type == "wardrobe" }?.w, desk0.w)
    }

    func testFitToTheWallNarrowsATableButNotABed() {
        let t = piece("dining", ["w": 1600])
        let fitted = fitTo(placed(t, ["A"], "r", "w", len: { _ in 1200 }), ["A"], { _ in 1200 }, 2700, ws)
        XCTAssertTrue(fitIssues(fitted, ["A"], { _ in 1200 }, 2700, ws).isEmpty)
        let bed = piece("bed", ["mw": 1600])
        let b2 = fitTo(placed(bed, ["A"], "r", "w", len: { _ in 1200 }), ["A"], { _ in 1200 }, 2700, ws)
        XCTAssertEqual(fitIssues(bed, ["A"], { _ in 1200 }, 2700, ws), fitIssues(b2, ["A"], { _ in 1200 }, 2700, ws))
        // deeper than the room in front of its wall: said, and fitting does not take it away
        XCTAssertTrue(fitIssues(bed, ["A"], { _ in 4000 }, 2700, ws, deep: { _ in 1500 }).contains { $0.key == "fz.deep" })
        let corners = [Pt(x: 0, y: 0), Pt(x: 4000, y: 0), Pt(x: 4000, y: 3000), Pt(x: 0, y: 3000)]
        XCTAssertEqual(depthFrom(Pt(x: 0, y: 0), Pt(x: 4000, y: 0), corners), 3000)
    }

    func testTheQuoteDescribesPiecesOfSeveralBoxesByTheirOwnSizes() {
        XCTAssertEqual(sizeLine(piece("stenka"), ws, "mm"), "3000 × 2200 × 400 mm")
        XCTAssertEqual(sizeLine(piece("bed", ["mw": 1600]), ws, "mm"), "1600 × 2000 · h 450 mm")
        XCTAssertTrue(sizeLine(piece("cornerW"), ws, "mm").hasPrefix("1800 + 1600"))
    }
}
