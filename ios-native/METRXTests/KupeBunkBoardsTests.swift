import XCTest
@testable import METRX

/// The founder's answers of 25 Oct 2026 in the parts list and the price: a kupe's outer sides, top and plinth of the
/// fronts' board; its mirror and lacobel below the split rail only, the upper fronts' board above it; a bunk's or loft
/// bed's ladder and guards in the wood accent (Android KupeBunkBoardsTest, the same cases and numbers).
final class KupeBunkBoardsTests: XCTestCase {
    private let ws = Workshop()

    private func cost(_ f: Furniture) -> Cost { costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false) }
    private func line(_ f: Furniture, _ key: String) -> CostLine? {
        let ls = cost(f).lines.filter { $0.key == key }
        return ls.count == 1 ? ls[0] : nil
    }
    private func look(_ f: Furniture, _ fn: (inout PieceLook) -> Void) -> Furniture { withLook(f) { l in var n = l; fn(&n); return n } }

    /// A free-standing kupe 2400 × 2500 × 600 (its own side panels, on its plinth), no shelves, two colours, the middle door a mirror.
    private func kupe(_ h: Int = 2500, shelf: Int = 0) -> Furniture {
        var f = newFreeWardrobe("Kupe", "s3", 2400, h, 600, false, "slide", ws)
        let ins: [Insert] = shelf > 0 ? [Insert("shelf", pos: shelf)] : []
        f.id = "s"; f.mats.frontUp = "ldsp18a"
        f.modules = f.modules.map { m in
            var x = m; x.id = "sm"
            x.sections = m.sections.map { s in var y = s; y.inserts = ins; return y }
            return x
        }
        return withMiddleFill(f, "mirror")
    }

    private func mats(_ f: Furniture, _ key: String) -> Set<String> { Set(partsWithMat(f, ws).filter { $0.0.key == key }.map { $0.1 }) }
    private func part(_ m: Module, _ key: String) -> FPart? {
        let ps = partsOf(m, ws).filter { $0.key == key }
        return ps.count == 1 ? ps[0] : nil
    }

    func testAKupesOuterSidesTopAndPlinthAreOfTheFrontBoard() {
        let k = kupe()
        let m = k.modules[0]
        XCTAssertEqual(["fp.side", "fp.top", "fp.plinth", "fp.bottom", "fp.divider"].map { wardRole(m, $0) }, ["front", "front", "front", "carcass", "carcass"])
        // the lower fronts' board, also on a two-tone kupe; the bottom and the inside stay carcass
        XCTAssertEqual(mats(k, "fp.side"), ["ldsp16k"]); XCTAssertEqual(mats(k, "fp.top"), ["ldsp16k"]); XCTAssertEqual(mats(k, "fp.plinth"), ["ldsp16k"])
        XCTAssertEqual(mats(k, "fp.bottom"), ["ldsp16w"]); XCTAssertEqual(mats(k, "fp.divider"), ["ldsp16w"])
        XCTAssertEqual(part(m, "fp.side")?.qty, 2); XCTAssertEqual(part(m, "fp.top")?.qty, 1); XCTAssertEqual(part(m, "fp.bottom")?.qty, 1)
        // the cut list cuts them so
        let rows = cutList([k], ws)
        XCTAssertTrue(rows.contains { $0.mat == "ldsp16k" && $0.p.key == "fp.side" && $0.p.qty == 2 })
        XCTAssertFalse(rows.contains { $0.mat == "ldsp16w" && ["fp.side", "fp.top", "fp.plinth"].contains($0.p.key) })
        // a hinged wardrobe as before: its sides, top and bottom carcass
        let hinged = newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws)
        XCTAssertEqual(mats(hinged, "fp.side"), ["ldsp16w"]); XCTAssertEqual(part(hinged.modules[0], "fp.top")?.qty, 2)
        XCTAssertNil(part(hinged.modules[0], "fp.bottom"))
    }

    func testAKupesMirrorBelowItsSplitRailOnly() {
        let k = kupe()
        let m = k.modules[0]
        // doors 809 × 2348, fillings 769 wide; no hat shelf: the split rail 420 under the door's top
        XCTAssertEqual(slideDoor(m, ws.t).0, 809); XCTAssertEqual(slideDoor(m, ws.t).1, 2348)
        XCTAssertEqual(slidePanel(m, ws.t).0, 769); XCTAssertEqual(slidePanel(m, ws.t).1, 2278)
        XCTAssertEqual(kupeSplit(m, ws.t)!, 1928, accuracy: 1e-9)
        XCTAssertEqual(kupeFillH(m, ws.t).low, 1881); XCTAssertEqual(kupeFillH(m, ws.t).up, 393)
        // the mirror by its area below the split; the board over it from the upper fronts' board
        XCTAssertEqual(hardware([k], ws)["mirror"], 769 * 1881)
        XCTAssertEqual(line(k, "mirror")!.qty, 1.45, accuracy: 1e-9); XCTAssertEqual(line(k, "mirror")?.amount, 362500)
        let up = part(m, "fp.slideUp")!
        // every door's (the board doors' too: KupeBoardDoorsTests)
        XCTAssertEqual([up.L, up.W, up.qty], [393, 769, 3])
        XCTAssertEqual(mats(k, "fp.slideUp"), ["ldsp18a"])
        XCTAssertEqual(part(m, "fp.slidePanel")?.qty, 2)
        // lacobel the same
        let lac = withMiddleFill(k, "glass")
        XCTAssertEqual(hardware([lac], ws)["glass"], 769 * 1881)
        // a hat shelf sets the split: its top 1888 up the door
        let hat = kupe(shelf: 1900)
        XCTAssertEqual(kupeSplit(hat.modules[0], ws.t)!, 1888, accuracy: 1e-9)
        XCTAssertEqual(kupeFillH(hat.modules[0], ws.t).low, 1841); XCTAssertEqual(kupeFillH(hat.modules[0], ws.t).up, 433)
        // a door under 1500 has no split: the whole filling, nothing above
        let low = kupe(1500)
        XCTAssertNil(kupeSplit(low.modules[0], ws.t))
        XCTAssertEqual(kupeFillH(low.modules[0], ws.t).low, slidePanel(low.modules[0], ws.t).1); XCTAssertEqual(kupeFillH(low.modules[0], ws.t).up, 0)
        XCTAssertNil(part(low.modules[0], "fp.slideUp"))
        // all board doors: an upper part each too, as the 3D draws them (KupeBoardDoorsTests)
        XCTAssertEqual(part(withMiddleFill(k, "ldsp").modules[0], "fp.slideUp")?.qty, 3)
    }

    func testABunksLadderAndGuardsInTheWoodAccent() {
        for id in ["bunk", "loft"] {
            let f = pieceOf(fModel(id)!, [:], ws, id)
            let plain = look(f) { $0.accent = "" }
            // no accent: the fronts' board
            for k in ["fp.ladder", "fp.rung", "fp.guard"] { XCTAssertEqual(mats(plain, k), [plain.mats.front], id + k) }
            let wood = look(f) { $0.accent = "wd_walnut" }
            for k in ["fp.ladder", "fp.rung", "fp.guard"] { XCTAssertEqual(mats(wood, k), ["wd_walnut"], id + k) }
            // the bed's sides and rails stay of the fronts' board
            XCTAssertEqual(mats(wood, "fp.bedSide"), [wood.mats.front])
            // priced: the accent board by the m²
            let wl = line(wood, "wd_walnut")
            XCTAssertEqual(wl?.unit, "m2"); XCTAssertTrue((wl?.qty ?? 0) > 0)
            XCTAssertNil(line(plain, "wd_walnut"))
        }
    }
}
