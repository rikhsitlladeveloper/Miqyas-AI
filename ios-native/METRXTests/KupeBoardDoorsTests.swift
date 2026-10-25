import XCTest
@testable import METRX

/// A kupe's board doors cut as the 3D draws them (25 Oct 2026): the door's own board below its split rail, the upper
/// fronts' board over it, two panels even of one board (the split rail holds two); the heights by kupeFillH like the
/// mirror's (Android KupeBoardDoorsTest, the same cases and numbers).
final class KupeBoardDoorsTests: XCTestCase {
    private let ws = Workshop()

    /// A free-standing kupe 2400 × h × 600 (its own side panels, on its plinth), three board doors; up its upper fronts' board.
    private func kupe(_ h: Int = 2500, shelf: Int = 0, up: String? = "ldsp18a") -> Furniture {
        var f = newFreeWardrobe("Kupe", "s3", 2400, h, 600, false, "slide", ws)
        let ins: [Insert] = shelf > 0 ? [Insert("shelf", pos: shelf)] : []
        f.id = "s"; f.mats.frontUp = up
        f.modules = f.modules.map { m in
            var x = m; x.id = "sm"
            x.sections = m.sections.map { s in var y = s; y.inserts = ins; return y }
            return x
        }
        return f
    }

    private func onePart(_ f: Furniture, _ key: String) -> FPart? {
        let ps = partsOf(f.modules[0], ws).filter { $0.key == key }
        return ps.count == 1 ? ps[0] : nil
    }
    private func matsOf(_ f: Furniture, _ key: String) -> Set<String> { Set(partsWithMat(f, ws).filter { $0.0.key == key }.map { $0.1 }) }

    func testABoardDoorIsTwoPanelsSplitByItsRail() {
        let k = kupe()
        let m = k.modules[0]
        XCTAssertEqual(m.slide?.n, 3); XCTAssertTrue((0..<3).allSatisfy { m.slide!.panel($0) == "ldsp" })
        XCTAssertEqual(kupeSplit(m, ws.t)!, 1928, accuracy: 1e-9)
        XCTAssertEqual(kupeFillH(m, ws.t).low, 1881); XCTAssertEqual(kupeFillH(m, ws.t).up, 393)
        // below the rail the door's board, over it the upper fronts': one of each a door
        guard let low = onePart(k, "fp.slidePanel"), let up = onePart(k, "fp.slideUp") else { return XCTFail("no fillings") }
        XCTAssertEqual([low.L, low.W, low.qty], [1881, 769, 3])
        XCTAssertEqual([up.L, up.W, up.qty], [393, 769, 3])
        XCTAssertTrue(low.grain && up.grain)
        XCTAssertEqual(matsOf(k, "fp.slidePanel"), ["ldsp16k"]); XCTAssertEqual(matsOf(k, "fp.slideUp"), ["ldsp18a"])
        // the two and the rail between them (each 5 into its groove) are the whole filling
        XCTAssertEqual(slidePanel(m, ws.t).1, low.L + up.L + Int(KUPE_SR - 2 * KUPE_GROOVE))
        // the cut list: no full-height panel left
        let rows = cutList([k], ws)
        XCTAssertTrue(rows.contains { $0.mat == "ldsp16k" && $0.p.key == "fp.slidePanel" && $0.p.L == 1881 && $0.p.qty == 3 })
        XCTAssertTrue(rows.contains { $0.mat == "ldsp18a" && $0.p.key == "fp.slideUp" && $0.p.L == 393 && $0.p.qty == 3 })
        XCTAssertFalse(rows.contains { $0.p.L == 2278 })
    }

    func testOneBoardAboveAndBelowIsStillTwoPanels() {
        let k = kupe(up: nil)
        XCTAssertEqual(matsOf(k, "fp.slidePanel"), ["ldsp16k"]); XCTAssertEqual(matsOf(k, "fp.slideUp"), ["ldsp16k"])
        let rows = cutList([k], ws).filter { $0.p.key == "fp.slidePanel" || $0.p.key == "fp.slideUp" }
        XCTAssertEqual(rows.map { "\($0.p.key) \($0.p.L) \($0.p.qty)" }, ["fp.slidePanel 1881 3", "fp.slideUp 393 3"])
        XCTAssertTrue(rows.allSatisfy { $0.mat == "ldsp16k" && $0.p.W == 769 })
    }

    func testTheSplitMovesWithTheHatShelfAndALowDoorIsOnePanel() {
        let hat = kupe(shelf: 1900)
        XCTAssertEqual(kupeFillH(hat.modules[0], ws.t).low, 1841); XCTAssertEqual(kupeFillH(hat.modules[0], ws.t).up, 433)
        XCTAssertEqual(onePart(hat, "fp.slidePanel").map { [$0.L, $0.qty] }, [1841, 3])
        XCTAssertEqual(onePart(hat, "fp.slideUp").map { [$0.L, $0.qty] }, [433, 3])
        // a door under 1500 has no split: the whole filling of the door's board, nothing above
        let low = kupe(1500)
        XCTAssertNil(kupeSplit(low.modules[0], ws.t))
        XCTAssertEqual(onePart(low, "fp.slidePanel").map { [$0.L, $0.qty] }, [slidePanel(low.modules[0], ws.t).1, 3])
        XCTAssertNil(onePart(low, "fp.slideUp"))
    }

    func testLabelsHighlightAndPriceFollowTheTwoPanels() {
        let k = kupe()
        let ls = labelsOf([k], ws)
        let ups = ls.filter { $0.key == "fp.slideUp" }, lows = ls.filter { $0.key == "fp.slidePanel" }
        XCTAssertEqual(ups.count, 3); XCTAssertTrue(ups.allSatisfy { $0.L == 393 && $0.W == 769 && $0.mat == "ldsp18a" })
        XCTAssertEqual(lows.count, 3); XCTAssertTrue(lows.allSatisfy { $0.L == 1881 && $0.W == 769 && $0.mat == "ldsp16k" })
        // the Bazis view lights the upper panels in their box
        let rows = cutList([k], ws)
        guard let upRow = rows.first(where: { $0.p.key == "fp.slideUp" }), let lowRow = rows.first(where: { $0.p.key == "fp.slidePanel" }) else {
            return XCTFail("no rows")
        }
        let homes = partHomes([k], upRow, ws)
        XCTAssertEqual(homes.map(\.0), ["s"]); XCTAssertEqual(homes.first?.1.count, 1)
        XCTAssertEqual(homes.first?.1, partHomes([k], lowRow, ws).first?.1)
        // priced by the sheet as the boards are: the three upper panels take one sheet of the upper board
        let l = costOf([k], ws, MAT_PRESETS, HW_PRESETS, order: false).lines.filter { $0.key == "ldsp18a" }
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(l.first?.unit, "sheet"); XCTAssertEqual(l.first?.qty ?? 0, 1, accuracy: 1e-9); XCTAssertEqual(l.first?.amount, 720000)
    }
}
