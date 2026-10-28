import XCTest
@testable import METRX

/// Inner walls from ready pieces (room-editor mockup v3, approved 28 Oct 2026): a piece's body and faces, the smart
/// snap (an end within 300 mm of a wall stretches to it), the gaps to the walls, the faces lettered after the outer
/// walls, saving (left out when there are none), the door zones, turning and mirroring with the room, and the areas
/// the trades count.
final class InnerWallsTests: XCTestCase {

    private func room() -> Room {
        var r = Room(id: "r", floorId: "f", name: "x")
        r.dims["A"] = Dim(v: 5000, src: "manual"); r.dims["B"] = Dim(v: 4000, src: "manual"); r.dims["H"] = Dim(v: 2700, src: "manual")
        return r
    }
    private func piece(_ k: String, _ x: Int, _ y: Int, ang: Int = 0, len: Int = 2000, id: String = "w1") -> InnerWall {
        var p = InnerWall(id: id, k: k, x: x, y: y, ang: ang, len: len, len2: iwKind(k).len2, th: k == "col" ? 400 : 100, h: iwKind(k).h)
        if k == "arch" { p.op = InnerOp(w: 900, h: 2100) }
        return p
    }

    func testEachPieceHasItsBodyAndFaces() {
        let s = iwGeo(piece("straight", 2500, 2000), 2700)
        XCTAssertEqual(s.R.count, 1)
        XCTAssertEqual(s.F.count, 2)
        XCTAssertEqual(s.F[0].a, Pt(x: 1500, y: 2050))
        XCTAssertEqual(s.F[0].b, Pt(x: 3500, y: 2050))
        XCTAssertEqual(s.F[0].look, Pt(x: 0, y: 1))
        XCTAssertEqual(s.F[1].look, Pt(x: 0, y: -1))
        XCTAssertEqual(iwGeo(piece("L", 2500, 2000), 2700).F.count, 4)
        XCTAssertEqual(iwGeo(piece("T", 2500, 2000, len: 2400), 2700).F.count, 5)
        XCTAssertEqual(iwGeo(piece("col", 2500, 2000, len: 400), 2700).F.count, 0)
        let a = iwGeo(piece("arch", 2500, 2000, len: 2400), 2700)
        XCTAssertEqual(a.R.count, 2)
        XCTAssertNotNil(a.gap)
        // a half wall is its own height, a full one the room's
        XCTAssertEqual(iwGeo(piece("half", 2500, 2000, len: 1600), 2700).H, 1100)
        XCTAssertEqual(s.H, 2700)
    }

    func testAnEndNearAWallStretchesToIt() {
        var r = room()
        let g = reGeo(r)
        // 250 mm from walls A and C at both ends: it stretches to 4 000 and touches both
        let p = piece("straight", 2500, 2000, ang: 90, len: 3500)
        r.inner = [p]
        let m = iwSnap(r, g.outer, g.poly, p)
        XCTAssertTrue(m.stretched)
        XCTAssertEqual(m.p.len, 4000)
        XCTAssertEqual(m.p.y, 2000)
        XCTAssertTrue(m.hits.contains("oA"))
        XCTAssertTrue(m.hits.contains("oC"))
        // 1 000 mm away: it stays as it is
        let q = piece("straight", 2500, 2000, ang: 90, len: 2000)
        let n = iwSnap(r, g.outer, g.poly, q)
        XCTAssertFalse(n.stretched)
        XCTAssertEqual(n.p.len, 2000)
    }

    func testTheGapsToTheWalls() {
        var r = room()
        let p = piece("straight", 2500, 2000)
        r.inner = [p]
        let s = iwSides(r, reGeo(r).outer, p)
        XCTAssertEqual(s["S1"]?.gap, 1950)
        XCTAssertEqual(s["S0"]?.gap, 1950)
        XCTAssertEqual(s["E1"]?.gap, 1500)
        XCTAssertEqual(s["E0"]?.gap, 1500)
    }

    func testTheFacesAreWallsLetteredAfterTheOuterOnes() {
        var r = room()
        r.inner = [piece("straight", 2500, 2000)]
        let g = reGeo(r)
        XCTAssertEqual(g.outer.map(\.id), ["A", "B", "C", "D"])
        XCTAssertEqual(g.walls.count, 6)
        XCTAssertEqual(g.walls[4].id, "w1:0")
        XCTAssertEqual(g.label("w1:0"), "E")
        XCTAssertEqual(g.label("w1:1"), "F")
        XCTAssertEqual(reWL("w1:1"), "F")
        XCTAssertEqual(g.len("w1:0"), 2000)
        XCTAssertEqual(g.perimeter, 18000)
        XCTAssertEqual(g.bodies.count, 1)
        // a door on a face stays while its piece does
        r.openings = [Opening(id: "d", type: "door", wall: "w1:0", w: 800, h: 2100, off: 300)]
        reClampItems(&r)
        XCTAssertEqual(r.openings.count, 1)
        r.inner = []
        reClampItems(&r)
        XCTAssertTrue(r.openings.isEmpty)
    }

    func testSavedOnlyWhenThereAreSome() throws {
        let plain = String(data: try JSONEncoder().encode(room()), encoding: .utf8)!
        XCTAssertFalse(plain.contains("\"inner\""))
        var r = room()
        var p = piece("straight", 2500, 2000)
        p.ang = 90
        r.inner = [p, piece("arch", 1000, 1000, len: 2400, id: "w2")]
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(Room.self, from: data)
        XCTAssertEqual(back.inner, r.inner)
        let one = String(data: try JSONEncoder().encode(p), encoding: .utf8)!
        XCTAssertFalse(one.contains("len2"))
        XCTAssertFalse(one.contains("round"))
        XCTAssertFalse(one.contains("\"op\""))
        // an older room has none
        let old = try JSONDecoder().decode(Room.self, from: plain.data(using: .utf8)!)
        XCTAssertTrue(old.inner.isEmpty)
    }

    func testAPieceInADoorsSwingIsSaid() {
        var r = room()
        r.openings = [Opening(id: "d", type: "door", wall: "A", w: 800, h: 2100, off: 2000)]
        r.inner = [piece("straight", 2400, 500)]
        let iss = reRoomIssues(r, reGeo(r))
        XCTAssertTrue(iss.contains { $0.id == "w1" && $0.code == "iw.swing" })
        r.inner = [piece("straight", 2400, 2500)]
        XCTAssertFalse(reRoomIssues(r, reGeo(r)).contains { $0.id == "w1" })
    }

    func testThePiecesTurnAndMirrorWithTheRoom() {
        var r = room()
        r.inner = [piece("straight", 1000, 2000, ang: 90, len: 2000)]
        let before = r.inner
        for _ in 0..<4 { reTurn(&r, 1) }
        XCTAssertEqual(r.inner, before)
        reMirror(&r)
        XCTAssertEqual(r.inner[0].x, 4000)
        XCTAssertEqual(r.inner[0].y, 2000)
        reMirror(&r)
        XCTAssertEqual(r.inner[0].x, before[0].x)
        XCTAssertEqual(r.inner[0].y, before[0].y)
    }

    func testTheTradesCountBothFaces() {
        var r = room()
        let a0 = Geo.areas(r)!
        r.inner = [piece("straight", 2500, 2000)]
        let iw = iwAreas(r, 2700)
        XCTAssertEqual(iw.floor, 200_000)
        XCTAssertEqual(iw.wall, 2 * 2000 * 2700)
        let a1 = Geo.areas(r)!
        XCTAssertEqual(a1.floor, a0.floor - 200_000)
        XCTAssertEqual(a1.gross, (a0.gross ?? 0) + 2 * 2000 * 2700)
    }

    func testANewPieceDoesNotStretchAtOnce() {
        let r = room()
        let g = reGeo(r)
        let c = iwRoomCentre(g)
        XCTAssertEqual(c, Pt(x: 2500, y: 2000))
        // the room is 5 000 wide: a 2 000 straight wall fits with its ends 1 500 from the walls
        XCTAssertEqual(iwNew("straight", c, r, g.outer, id: "n").len, 2000)
        var small = room()
        small.dims["A"] = Dim(v: 2400, src: "manual")
        let gs = reGeo(small)
        let p = iwNew("straight", iwRoomCentre(gs), small, gs.outer, id: "n")
        XCTAssertLessThanOrEqual(Double(p.len), 2400 - 2 * (IW_MAG + 60))
    }
}
