import XCTest
@testable import METRX

/// The tiler's fixes of 23 Oct 2026 (Android TileFixesTest, same cases and numbers): the adhesive setting, merged counts
/// with their own spares and boxes, labour priced as shown.
final class TileFixesTests: XCTestCase {
    private var room: Room {
        var r = Room(id: "r", floorId: "w", name: "Hammom")
        r.dims = ["A": Dim(v: 5000), "B": Dim(v: 4000), "H": Dim(v: 3000), "T": Dim(v: 200, src: "default")]
        return r
    }

    func testAnAdhesiveOfZeroIsKept() {
        XCTAssertEqual(glueBaseOf("0"), 0, accuracy: 0)
        XCTAssertEqual(glueBaseOf("4,5"), 4.5, accuracy: 0)
        XCTAssertEqual(glueBaseOf(""), 5, accuracy: 0)
        let panel = TileLayout(id: "t", a: 300, b: 300, panel: TPanel(kind: "floor", a: 2000, b: 1000))
        XCTAssertEqual(countLayout(Project(id: "p", name: "T"), panel, true, glueBaseOf("0")).glueKg, 0, accuracy: 0)
    }

    func testMergedLayoutsKeepTheirOwnBoxesAndSaySpareOnlyWhenTheSame() {
        let a = TileNeed(look: "white", a: 300, b: 600, whole: 90, cut: 10, reused: 0, tiles: 100, skirtTiles: 0, spare: 5, withSpare: 105, perBox: 8, boxes: 14, m2: 18)
        let b = TileNeed(look: "white", a: 300, b: 600, whole: 90, cut: 10, reused: 0, tiles: 100, skirtTiles: 0, spare: 10, withSpare: 110, perBox: 6, boxes: 19, m2: 18)
        let mixed = (TileCount(needs: [a]) + TileCount(needs: [b])).needs
        XCTAssertEqual(mixed.count, 1)
        let m = mixed[0]
        XCTAssertEqual(m.spare, -1)
        XCTAssertEqual(m.boxes, 14 + 19)
        XCTAssertEqual(m.perBox, 0)
        XCTAssertEqual(m.boxedM2, a.boxedM2 + b.boxedM2, accuracy: 1e-9)
        let same = (TileCount(needs: [a]) + TileCount(needs: [a])).needs
        XCTAssertEqual(same.count, 1)
        XCTAssertEqual(same[0].spare, 5); XCTAssertEqual(same[0].perBox, 8)
        XCTAssertEqual(same[0].boxes, Int((210.0 / 8.0).rounded(.up)))
    }

    func testTheLabourLineIsPricedByTheAreaItShows() {
        let l = TileLayout(id: "f", a: 333, b: 333, joint: 3, roomId: "r", surfs: [TSurf(id: "floor"), TSurf(id: "A")])
        var p = Project(id: "p", name: "T")
        p.rooms = [room]
        p.industry = "tiler"
        p.tiles = [l]
        let t = TradeSet()
        let r = tileRows(p, t, true) { k, v in k + v.keys.sorted().map { "|" + $0 + "=" + (v[$0] ?? "") }.joined() }
        guard let lab = r.labor.first(where: { $0.name.hasPrefix("tl.e.lab|") }) else { return XCTFail("the tiling line") }
        let a = Double(lab.name.components(separatedBy: "a=").last ?? "") ?? -1
        XCTAssertTrue(a > 0)
        let want = (a * (Double(t.lTile) ?? 0) + 0.5).rounded(.down)
        XCTAssertEqual(lab.amount, String(Int(want)))
    }
}
