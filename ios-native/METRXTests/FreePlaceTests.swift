import XCTest
@testable import METRX

/// "Mebel joylash" (room-editor mockup v3): any cabinet-engine piece free in the room by its pose, moved flush to a
/// wall within 60 mm, turned about its middle, back on a wall; red for an overlap, an inner wall or a door, yellow for a
/// passage under 700 mm; the inner walls brought into the plan's millimetres.
final class FreePlaceTests: XCTestCase {
    private let ws = Workshop()
    private func piece(_ id: String) -> Furniture { pieceOf(fModel(id)!, [:], ws, id) }
    private func room() -> Room {
        var r = Room(id: "r", floorId: "w", name: "Xona")
        r.dims = ["A": Dim(v: 5000), "B": Dim(v: 4000), "H": Dim(v: 2700)]
        return r
    }

    func testAnyCabinetCanStandFreeButNotACornerOrAKitchen() {
        XCTAssertTrue(canBeFree(piece("bed")))
        XCTAssertTrue(canBeFree(piece("bookcase")))
        XCTAssertFalse(canBeFree(piece("cornerW")))
    }

    func testFreedItStaysWhereItWasThenMovesAndTurns() {
        let r = room()
        let walls = planWalls(r, true)
        let f = placed(piece("bookcase"), ["A"], "r", "w", off: 1000)
        let p0 = fpPiece(f, walls, ws)!
        XCTAssertFalse(p0.free)
        XCTAssertEqual(p0.wall, "A")
        let free = fpToFree(f, walls)
        XCTAssertNotNil(free.pose)
        let p1 = fpPiece(free, walls, ws)!
        XCTAssertTrue(p1.free)
        XCTAssertEqual(p1.c.x, p0.c.x, accuracy: 1); XCTAssertEqual(p1.c.y, p0.c.y, accuracy: 1)
        // to the middle of the room, then turned 90° about its middle
        let g = fpGeo(r, true).g
        let mv = fpMove(free, p1, PlanPt(2500, 2000), walls, g, [])
        let p2 = fpPiece(mv.f, walls, ws)!
        XCTAssertEqual(p2.c.x, 2500, accuracy: 1); XCTAssertEqual(p2.c.y, 2000, accuracy: 1)
        XCTAssertFalse(mv.magnet)
        let t = fpTurn(mv.f, p2, walls, 90)
        let p3 = fpPiece(t, walls, ws)!
        XCTAssertEqual(fpAngle(p3), 90)
        XCTAssertEqual(p3.c.x, 2500, accuracy: 1); XCTAssertEqual(p3.c.y, 2000, accuracy: 1)
    }

    func testItSticksFlushWithinSixtyMillimetres() {
        let r = room()
        let walls = planWalls(r, true)
        let g = fpGeo(r, true).g
        let free = fpToFree(placed(piece("bookcase"), ["A"], "r", "w", off: 1000), walls)
        let p = fpPiece(free, walls, ws)!
        // its right side 40 mm from wall B: it goes flush
        let c = PlanPt(5000 - p.w / 2 - 40, 2000)
        let mv = fpMove(free, p, c, walls, g, [])
        XCTAssertTrue(mv.magnet)
        let q = fpPiece(mv.f, walls, ws)!
        XCTAssertEqual(q.c.x + q.w / 2, 5000, accuracy: 1)
    }

    func testOverlapsAndNarrowPassagesAreSaid() {
        var r = room()
        let walls = planWalls(r, true)
        let a = fpToFree(placed(piece("bookcase"), ["A"], "r", "w", off: 1000), walls)
        var b = fpToFree(placed(piece("bookcase"), ["A"], "r", "w", off: 1000), walls)
        b.id = "b"; b.name = "b"
        let pa = fpPiece(a, walls, ws)!, pb = fpPiece(b, walls, ws)!
        let g = fpGeo(r, true).g
        // the same place: both red
        let c1 = fpCheck(r, g, [pa, pb])
        XCTAssertEqual(c1.red[pa.id]?.key, "fp.r.over")
        // one in the middle with an inner wall 400 mm from it: a narrow passage
        let mid = fpPiece(fpMove(b, pb, PlanPt(2500, 2000), walls, g, []).f, walls, ws)!
        r.inner = [InnerWall(id: "w1", k: "straight", x: 2500, y: Int(2000 + mid.d / 2 + 400 + 50), len: 1600)]
        let g2 = fpGeo(r, true).g
        let c2 = fpCheck(r, g2, [mid])
        XCTAssertNil(c2.red[mid.id])
        XCTAssertNotNil(c2.yel[mid.id])
        // standing on the inner wall: red
        r.inner = [InnerWall(id: "w1", k: "straight", x: 2500, y: 2000, len: 1600)]
        let c3 = fpCheck(r, fpGeo(r, true).g, [mid])
        XCTAssertEqual(c3.red[mid.id]?.key, "fp.r.iw")
    }

    func testBackOnTheNearestWall() {
        let r = room()
        let walls = planWalls(r, true)
        let g = fpGeo(r, true).g
        let free = fpToFree(placed(piece("bookcase"), ["A"], "r", "w", off: 1000), walls)
        let p = fpPiece(free, walls, ws)!
        // near wall D (x = 0), turned to face into the room
        let near = fpTurn(fpMove(free, p, PlanPt(700, 2000), walls, g, []).f, fpPiece(fpMove(free, p, PlanPt(700, 2000), walls, g, []).f, walls, ws)!, walls, 270)
        let s = fpStick(near, fpPiece(near, walls, ws)!, r, walls, ws)
        XCTAssertEqual(s?.wall, "D")
        XCTAssertNil(s?.f.pose)
    }

    func testTheInnerWallsComeIntoThePlansMillimetres() {
        var r = room()
        r.rot = 1
        // in the editor's plan (turned) the piece stands 1 000 mm in front of wall A's middle
        let ge = reGeo(r)
        let fa = reWallAFrame(ge)!
        let wa = ge.outer[0]
        let mx = (wa.a.x + wa.b.x) / 2 + fa.n.x * 1000, my = (wa.a.y + wa.b.y) / 2 + fa.n.y * 1000
        r.inner = [InnerWall(id: "w1", k: "col", x: Int(mx.rounded()), y: Int(my.rounded()), len: 400, th: 400)]
        let x = fpGeo(r, true).room.inner[0]
        // in the plan's millimetres wall A runs along x from (0, 0): the column is at (2 500, 1 000)
        XCTAssertEqual(x.x, 2500); XCTAssertEqual(x.y, 1000)
    }
}
