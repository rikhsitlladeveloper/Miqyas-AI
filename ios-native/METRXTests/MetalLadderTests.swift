import XCTest
@testable import METRX

/// A bunk's or loft bed's metal ladder (PieceLook.legs; the 3D's round tubes): bought as one "ladderMetal" (650 000 a
/// bed), its board stringers and rungs off the parts list, the cut list and the labels; its guards stay boards in the
/// wood accent (Android MetalLadderTest, the same cases and numbers).
final class MetalLadderTests: XCTestCase {
    private let ws = Workshop()
    private let rgb: (String) -> Int = { _ in 0xCDBFAE }

    private func cost(_ f: Furniture) -> Cost { costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false) }
    private func line(_ f: Furniture, _ key: String) -> CostLine? {
        let ls = cost(f).lines.filter { $0.key == key }
        return ls.count == 1 ? ls[0] : nil
    }
    private func look(_ f: Furniture, _ fn: (inout PieceLook) -> Void) -> Furniture { withLook(f) { l in var n = l; fn(&n); return n } }
    private func piece(_ id: String) -> Furniture { pieceOf(fModel(id)!, [:], ws, id) }
    /// The piece in its made-up room, lit.
    private func build(_ f: Furniture) -> Furn3D {
        furniture3D([f], buildShell([freeRoom(f)], single: true).bases, ws, rgb, [], detail: .high)
    }
    private func looks(_ f: Furniture) -> [String: Look] { pieceLooks(f, rgb, { id in MAT_PRESETS.first { $0.id == id }?.tex }, MAT_PRESETS) }
    private func faces(_ d: Furn3D, _ l: Look?) -> [Face3] { d.parts.filter { $0.look == l }.flatMap(\.faces) }

    func testAMetalLadderIsBoughtNotCut() {
        for id in ["bunk", "loft"] {
            let f = piece(id)
            let wood = look(f) { $0.accent = "wd_walnut"; $0.legs = false }
            let metal = look(f) { $0.accent = "wd_walnut"; $0.legs = true }
            let m = metal.modules.first { $0.type == id }!
            XCTAssertTrue(metalLadder(metal, m), id); XCTAssertFalse(metalLadder(wood, m), id)
            // the box itself still has its board ladder (the 3D draws the tubes where those boards are)
            XCTAssertEqual(partsOf(m, ws).filter { $0.key == "fp.ladder" }.reduce(0) { $0 + $1.qty }, 2, id)
            XCTAssertTrue(partsOf(m, ws).contains { $0.key == "fp.rung" }, id)
            // in wood: the stringers, the rungs and the guards are cut, from the accent
            let wk = Set(partsWithMat(wood, ws).map { $0.0.key })
            XCTAssertTrue(wk.isSuperset(of: ["fp.ladder", "fp.rung", "fp.guard"]), id)
            // in metal: no stringers and rungs in the parts list, the cut list or the labels
            XCTAssertFalse(partsWithMat(metal, ws).contains { LADDER_KEYS.contains($0.0.key) }, id)
            XCTAssertFalse(cutList([metal], ws).contains { LADDER_KEYS.contains($0.p.key) }, id)
            XCTAssertFalse(labelsOf([metal], ws).contains { LADDER_KEYS.contains($0.key) }, id)
            // the guards stay boards in the accent, everything else as it was
            XCTAssertEqual(Set(partsWithMat(metal, ws).filter { $0.0.key == "fp.guard" }.map { $0.1 }), ["wd_walnut"], id)
            let rest = partsWithMat(wood, ws).filter { !LADDER_KEYS.contains($0.0.key) }
            let mp = partsWithMat(metal, ws)
            XCTAssertEqual(rest.map { $0.0 }, mp.map { $0.0 }, id); XCTAssertEqual(rest.map { $0.1 }, mp.map { $0.1 }, id)
            // the hardware: one metal ladder a bed, 650 000
            XCTAssertNil(hardware([wood], ws)["ladderMetal"], id)
            XCTAssertEqual(hardware([metal], ws)["ladderMetal"], 1, id)
            XCTAssertEqual(line(metal, "ladderMetal")?.qty, 1, id); XCTAssertEqual(line(metal, "ladderMetal")?.amount, 650000, id)
            XCTAssertNil(line(wood, "ladderMetal"), id)
            // less walnut to buy: only the guards
            XCTAssertTrue((line(metal, "wd_walnut")?.qty ?? 0) < (line(wood, "wd_walnut")?.qty ?? 0), id)
            // two beds, two ladders
            var second = metal; second.id = "b2"
            XCTAssertEqual(hardware([metal, second], ws)["ladderMetal"], 2, id)
        }
    }

    func testNoMetalLadderWithoutTheLooksMetalOrOnOtherBeds() {
        // a bunk with no look at all keeps its board ladder
        var bare = piece("bunk"); bare.look = nil
        XCTAssertTrue(partsWithMat(bare, ws).contains { $0.0.key == "fp.ladder" })
        XCTAssertNil(hardware([bare], ws)["ladderMetal"])
        // a bed on metal legs: its legs, no ladder
        let bed = look(piece("bed")) { $0.legs = true }
        XCTAssertFalse(metalLadder(bed, bed.modules[0]))
        XCTAssertNil(hardware([bed], ws)["ladderMetal"])
    }

    func testTheMetalLadderIsAWorkshopItem() {
        XCTAssertTrue(HW_PRESETS.contains { $0.id == "ladderMetal" && $0.kind == "ladderMetal" && $0.name == "Metall narvon" && $0.price == "650000" && $0.preset })
        XCTAssertEqual(hwUnit("ladderMetal"), "pcs")
    }

    /// The 3D draws the metal ladder as tubes in the handle colour (Android ItemsLookTest bunkAndLoftLaddersInTheAccent),
    /// so less of the accent: the guards only.
    func testTheMetalLadderIsDrawnInTheHandleColour() {
        for id in ["bunk", "loft"] {
            let wood = look(piece(id)) { $0.accent = "wd_walnut"; $0.legs = false }
            let metal = look(piece(id)) { $0.accent = "wd_walnut"; $0.legs = true }
            let lw = looks(wood), lm = looks(metal)
            XCTAssertTrue(faces(build(wood), lw["accent"]).count > 0, id)
            XCTAssertTrue(faces(build(metal), lm["legs"]).count > faces(build(wood), lw["legs"]).count, id)
            XCTAssertTrue(faces(build(metal), lm["accent"]).count > 0, id)
            XCTAssertTrue(faces(build(metal), lm["accent"]).count < faces(build(wood), lw["accent"]).count, id)
        }
    }
}
