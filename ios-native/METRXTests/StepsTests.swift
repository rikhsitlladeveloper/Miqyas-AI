import XCTest
@testable import METRX

/// The gallery and its size steps (Steps.swift; Android StepsTest): the groups, the steps of a model, a piece from typed sizes and back.
final class StepsTests: XCTestCase {
    private let ws = Workshop()

    func testEveryModelIsInTheGalleryOnce() {
        let ids = GALLERY.flatMap { $0.1 }
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(Set(F_MODELS.map(\.id)), Set(ids))
        XCTAssertEqual(GALLERY.map { $0.0 }, ["kitchen", "bedroom", "living", "hall", "kids", "office", "bath"])
    }

    func testAKitchenAsksItsSidesItsIslandAndTheCeiling() {
        XCTAssertEqual(stepsOf(fModel("I")!).map(\.key), ["s0", "h"])
        XCTAssertEqual(stepsOf(fModel("L")!).map(\.key), ["sh", "ms", "s0", "s1", "h"])
        XCTAssertEqual(stepsOf(fModel("U")!).map(\.key), ["s0", "s1", "s2", "h"])
        XCTAssertEqual(stepsOf(fModel("O")!).map(\.key), ["s0", "isl", "h"])
        XCTAssertEqual(stepsOf(fModel("P")!)[1].label, "fz.pP")
        XCTAssertEqual(stepsOf(fModel("L")!).map(\.usual), [0, 0, 3000, 2000, 2700])
    }

    func testACabinetAsksWidthHeightDepth() {
        let w = stepsOf(fModel("s3")!)
        XCTAssertEqual(w.map(\.key), ["w", "h", "d"])
        XCTAssertEqual(w.map(\.usual), [2400, 2500, 600])
        XCTAssertEqual(w[0].min, 400); XCTAssertEqual(w[1].min, 1200)
        let c = stepsOf(fModel("dresser")!)
        XCTAssertEqual(c[0].min, 300); XCTAssertEqual(c[1].help, "fx.hHLegs")
        let i = stepsOf(fModel("I")!)
        XCTAssertEqual(stepIssue(i[0], 500)?.0, "fx.min"); XCTAssertEqual(stepIssue(i[0], 500)?.1, 600)
        XCTAssertEqual(stepIssue(i[1], 4200)?.0, "fx.max")
        XCTAssertNil(stepIssue(i[0], 3400))
    }

    func testAPieceFollowsItsTypedSizesAndGivesThemBack() {
        let k = pieceOf(fModel("L")!, ["s0": 3400, "h": 2650], ws, "Oshxona 1")
        XCTAssertEqual(k.free?.sides, [3400, 2000])
        XCTAssertEqual(k.free?.h, 2650)
        XCTAssertEqual(valsOf(k, ws), ["s0": 3400, "s1": 2000, "h": 2650, "sh": 0, "ms": 0])
        let d = pieceOf(fModel("dresser")!, ["w": 1200, "h": 900, "d": 500], ws, "Komod 1")
        XCTAssertEqual(d.type, "dresser")
        XCTAssertEqual(valsOf(d, ws), ["w": 1200, "h": 900, "d": 500])
        let s = pieceOf(fModel("s2")!, [:], ws, "Shkaf 1")
        XCTAssertEqual(wardOfF(s)?.w, 1800); XCTAssertEqual(wardOfF(s)?.slide?.n, 2)
        XCTAssertEqual(modelOf(pieceOf(fModel("s3")!, [:], ws, "x")).id, "s3")
    }

    func testNewSizesKeepTheSections() {
        let f = pieceOf(fModel("h3")!, [:], ws, "Shkaf 1")
        let m = wardOfF(resized(f, ["w": 1800, "h": 2300, "d": 550], ws))!
        XCTAssertEqual(m.w, 1800); XCTAssertEqual(m.h, 2300); XCTAssertEqual(m.d, 550)
        XCTAssertEqual(m.sections.count, wardOfF(f)!.sections.count)
        let d = resized(pieceOf(fModel("dresser")!, [:], ws, "Komod 1"), ["h": 900], ws)
        XCTAssertEqual(valsOf(d, ws)["h"], 900)
        let k = resized(pieceOf(fModel("I")!, ["s0": 3000], ws, "Oshxona 1"), ["s0": 2400], ws)
        XCTAssertEqual(k.free?.sides, [2400])
        XCTAssertLessThanOrEqual(k.modules.filter { !isUpper($0) }.reduce(0) { $0 + $1.w }, 2400)
    }

    func testAMeasuredRoomGivesTheKitchenItsWalls() {
        let len = { (id: String) -> Int? in id == "A" || id == "C" ? 3400 : 2600 }
        let k = roomKitchen(fModel("L")!, ["A", "B", "C", "D"], "A", len, 2700, ws, "Oshxona 1")
        XCTAssertEqual(k.free?.sides, [3400, 2600]); XCTAssertEqual(k.free?.h, 2700)
        let best = bestFirst(k, ["A", "B", "C", "D"], len, 2700, ws)
        XCTAssertEqual(best.0, "A"); XCTAssertTrue(best.1.isEmpty)
        // a 4,3 m kupe fits no wall of a 4,2 × 3,6 room
        let big = pieceOf(fModel("s3")!, ["w": 4300], ws, "Shkaf 1")
        XCTAssertEqual(bestFirst(big, ["A", "B", "C", "D"], { $0 == "A" || $0 == "C" ? 4200 : 3600 }, 2700, ws).1.first?.key, "fz.wide")
        let c = roomCabinet(fModel("s3")!, 2000, 2600, ws, "Shkaf 1")
        XCTAssertEqual(wardOfF(c)?.w, 2000 - 2 * W_GAP_SIDE); XCTAssertEqual(wardOfF(c)?.h, 2500)
    }
}
