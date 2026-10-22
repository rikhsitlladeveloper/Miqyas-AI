import XCTest
@testable import METRX

/// The tiler's layouts on the 5 × 4 × 3 m room with a door 900 × 2100 on wall A and a window 1200 × 1500 at 900 on wall C:
/// the same cases and numbers as the Android unit test TilesTest.
final class TilesTests: XCTestCase {
    private var room: Room {
        var r = Room(id: "r", floorId: "w", name: "Hammom")
        r.dims = ["A": Dim(v: 5000), "B": Dim(v: 4000), "H": Dim(v: 3000), "T": Dim(v: 200, src: "default")]
        r.openings = [Opening(id: "d", type: "door", wall: "A", w: 900, h: 2100, off: 500), Opening(id: "o", type: "window", wall: "C", w: 1200, h: 1500, off: 1900, sill: 900)]
        return r
    }
    private func geo(_ fixes: [TFix] = []) -> TRoomGeo { roomGeo(room, true, fixes)! }
    private func floor(_ a: Int, _ b: Int, _ pattern: String = "straight", _ start: String = "corner", joint: Int = 0, rot: Int = 0) -> TileLayout {
        TileLayout(id: "f", pattern: pattern, a: a, b: b, joint: joint, start: start, rot: rot, look: "white", roomId: "r", surfs: [TSurf(id: "floor")])
    }
    private func sumArea(_ ps: [TPiece]) -> Double { ps.reduce(0.0) { $0 + $1.area } }
    private func project(tiles: [TileLayout] = [], rooms: [Room] = [], troom: [TileRoom] = []) -> Project {
        var p = Project(id: "p", name: "")
        p.tiles = tiles; p.rooms = rooms; p.troom = troom
        return p
    }

    func testWholeTilesFillAnExactFloor() {
        let laid = layRoom(floor(500, 500), geo(), nil)
        XCTAssertEqual(laid.pieces.count, 80)
        XCTAssertTrue(laid.pieces.allSatisfy { !$0.cut })
        XCTAssertEqual(sumArea(laid.pieces), 20e6, accuracy: 1.0)
    }

    func testCutsOffcutsSpareAndBoxes() {
        let l = floor(600, 600)
        let c = countLaid(l, layRoom(l, geo(), nil))
        XCTAssertEqual(c.needs.count, 1)
        let n = c.needs[0]
        XCTAssertEqual(n.whole, 48)                       // 8 × 6 whole tiles
        XCTAssertEqual(n.cut, 15)                         // 6 down the side, 8 along the far wall, 1 in the corner
        XCTAssertEqual(n.reused, 3)                       // the side's 200 mm strips: two from a tile
        XCTAssertEqual(n.tiles, 60)
        XCTAssertEqual(n.withSpare, 63)                   // + 5 %
        XCTAssertEqual(n.perBox, 4)
        XCTAssertEqual(n.boxes, 16)
        XCTAssertEqual(c.m2, 20.0, accuracy: 1e-6)
    }

    func testSpareIsTenForDiagonalAndHerringbone() {
        XCTAssertEqual(spareOf(floor(300, 300)), 5)
        XCTAssertEqual(spareOf(floor(300, 300, "diagonal")), 10)
        XCTAssertEqual(spareOf(floor(200, 600, "herring")), 10)
        XCTAssertEqual(spareOf(floor(300, 600, rot: 45)), 10)
        var s = floor(300, 300); s.spare = 7
        XCTAssertEqual(spareOf(s), 7)
    }

    func testDiagonalAndHerringboneCoverTheFloorOnce() {
        // with no joint every patch of floor is under exactly one tile: no gaps, no overlaps
        let ls = [floor(300, 300, "diagonal", "center"), floor(200, 600, "herring", "center"), floor(300, 600, "brick2", "center"), floor(200, 600, "brick3"),
                  floor(300, 600, rot: 45), floor(300, 300, "chess", "center")]
        for l in ls {
            let laid = layRoom(l, geo(), nil)
            XCTAssertEqual(sumArea(laid.pieces), 20e6, accuracy: 20.0, l.pattern + " \(l.rot)")
            XCTAssertTrue(laid.pieces.contains { $0.cut })
        }
        // a herringbone's tiles lie two ways
        let h = layRoom(floor(200, 600, "herring", "center"), geo(), nil)
        XCTAssertTrue(h.pieces.contains { $0.vert } && h.pieces.contains { !$0.vert })
        // the chessboard's second look
        XCTAssertTrue(layRoom(floor(300, 300, "chess"), geo(), nil).pieces.contains { $0.prod == 1 })
    }

    func testJointsMakeRoomBetweenTiles() {
        let laid = layRoom(floor(600, 600, joint: 3), geo(), nil)
        let whole = laid.pieces.filter { !$0.cut }
        XCTAssertEqual(whole[0].area, 600.0 * 600, accuracy: 1e-6)
        // tiles + joints: the tiles cover less than the floor
        XCTAssertTrue(sumArea(laid.pieces) < 20e6 - 1e5)
    }

    func testDoorsAndWindowsAreLeftOut() {
        let a = TileLayout(id: "w", place: "wall", a: 500, b: 500, joint: 0, start: "corner", roomId: "r", surfs: [TSurf(id: "A")])
        XCTAssertEqual(sumArea(layRoom(a, geo(), nil).pieces), 5000.0 * 3000 - 900.0 * 2100, accuracy: 10.0)
        // up to 1,5 m on wall C: the window's part below that line goes
        var c = a; c.surfs = [TSurf(id: "C", mode: "to", h1: 1500)]
        XCTAssertEqual(sumArea(layRoom(c, geo(), nil).pieces), 5000.0 * 1500 - 1200.0 * 600, accuracy: 10.0)
        // a 600 backsplash band from 900 on wall C: the window from 900 to 2400 takes 1200 × 600 of it
        var band = a; band.surfs = [TSurf(id: "C", mode: "band", h0: 900, h1: 1500)]
        XCTAssertEqual(sumArea(layRoom(band, geo(), nil).pieces), 5000.0 * 600 - 1200.0 * 600, accuracy: 10.0)
    }

    func testSkirtingSkipsDoorsAndTiledWalls() {
        var f = floor(600, 600); f.skirt = 100
        XCTAssertEqual(skirtRuns(f, geo(), [f]).reduce(0.0) { $0 + $1.len }, 18000.0 - 900, accuracy: 1e-6)
        let w = TileLayout(id: "w", place: "wall", roomId: "r", surfs: [TSurf(id: "B")])
        XCTAssertEqual(skirtRuns(f, geo(), [f, w]).reduce(0.0) { $0 + $1.len }, 18000.0 - 900 - 4000, accuracy: 1e-6)
        // skirting is cut from the tile: 600 × 100 strips, six from a 600 tile (with the cut)
        let c = countLayout(project(tiles: [f], rooms: [room]), f, true)
        XCTAssertEqual(c.skirtM, 17.1, accuracy: 1e-9)
        XCTAssertEqual(c.needs.count, 1)
        XCTAssertTrue((4...6).contains(c.needs[0].skirtTiles))
    }

    func testWaterproofingFloorWallsAndShower() {
        let tray = TFix(id: "t", type: "tray", wall: "A", off: 0, w: 900, d: 900, h: 150)
        let g = geo([tray])
        // the tray in the corner of walls A and D
        XCTAssertNotNil(coverOn(g, g.wall("D")!, tray))
        let wp = wpM2(TileRoom(roomId: "r", fixes: [tray], wp: true, wpUp: 200, showerH: 1800), g)
        let walls: Double = (18000.0 - 900.0) * 200.0 / 1e6
        let shower: Double = 2.0 * 900.0 * 1600.0 / 1e6
        XCTAssertEqual(wp, 20.0 + walls + shower, accuracy: 1e-9)
    }

    func testTilesStopRoundTheBathAndItsFrontIsTiled() {
        let bath = TFix(id: "b", type: "bath", wall: "B", off: 0, w: 1700, d: 700, h: 600)
        let g = geo([bath])
        let l = TileLayout(id: "w", place: "bath", a: 500, b: 500, joint: 0, roomId: "r", surfs: [TSurf(id: "B"), TSurf(id: "bath:b")])
        let laid = layRoom(l, g, nil)
        let onWall = sumArea(laid.pieces.filter { laid.surfs[$0.s].key == "B" })
        let front = sumArea(laid.pieces.filter { laid.surfs[$0.s].key == "bath:b" })
        XCTAssertEqual(onWall, 4000.0 * 3000 - 1700.0 * 600, accuracy: 10.0)
        XCTAssertEqual(front, 1700.0 * 600, accuracy: 10.0)
        // the floor goes round it too
        XCTAssertEqual(sumArea(layRoom(floor(500, 500), g, nil).pieces), 20e6 - 1700.0 * 700, accuracy: 10.0)
    }

    func testCornerProfilesRoundTheWindow() {
        let w = TileLayout(id: "w", place: "wall", roomId: "r", surfs: [TSurf(id: "C")], profiles: true)
        XCTAssertEqual(profileMm(w, geo()), 2 * 1500.0 + 1200 + 1200, accuracy: 1e-9)
        var off = w; off.profiles = false
        XCTAssertEqual(profileMm(off, geo()), 0.0, accuracy: 1e-9)
    }

    func testASurfaceWithoutARoom() {
        let l = TileLayout(id: "p", a: 600, b: 600, joint: 0, start: "corner", panel: TPanel(kind: "floor", a: 3000, b: 2000))
        let c = countLayout(project(), l, true)
        XCTAssertEqual(c.needs.count, 1)
        let n = c.needs[0]
        XCTAssertEqual(n.whole, 15)
        XCTAssertEqual(n.cut, 5)
        XCTAssertEqual(n.reused, 2)
        XCTAssertEqual(n.tiles, 18)
        XCTAssertEqual(c.m2, 6.0, accuracy: 1e-9)
        // and it can be drawn as a flat panel with its tiles
        let shell = panelScene(l)!
        XCTAssertTrue(shell.parts.contains { $0.tile && $0.faces.count >= 15 })
        var apron = l; apron.panel = TPanel(kind: "apron", a: 2400, b: 600)
        XCTAssertNotNil(panelScene(apron))
    }

    func testRoomPartsAndRows() {
        let f = floor(600, 600, joint: 2)
        let w = TileLayout(id: "w", place: "wall", a: 300, b: 600, look: "carrara", roomId: "r", surfs: [TSurf(id: "A"), TSurf(id: "B")])
        let p = project(tiles: [f, w], rooms: [room], troom: [TileRoom(roomId: "r", wp: true)])
        let parts = tileParts(p.tiles, geo(), p.tiles)
        XCTAssertTrue(!parts.isEmpty && parts.allSatisfy { $0.tile })
        // a drawn look varies from tile to tile; a cut piece is a shade off
        XCTAssertTrue(Set(parts.map(\.rgb)).count >= 4)
        let rows = tileRows(p, TradeSet(), true) { (k: String, v: [String: String]) -> String in
            let vals: String = v.keys.sorted().map { v[$0] ?? "" }.joined(separator: ",")
            return k + "(" + vals + ")"
        }
        XCTAssertEqual(rows.mats.map(\.id), ["t-tile0", "t-tile1", "t-glue", "t-grout", "t-wp"])
        XCTAssertEqual(rows.labor.map(\.id), ["t-lab", "t-labWp"])
        XCTAssertTrue(rows.mats[0].name.contains("~tl.lk.white"))
    }

    func testTooManyTilesAreNotWorkedOut() {
        let laid = layRoom(floor(10, 10), geo(), nil)
        XCTAssertFalse(laid.tooMany.isEmpty)
        XCTAssertTrue(countLaid(floor(10, 10), laid).tooMany)
    }

    func testClippingKeepsAreas() {
        let sq = [V2(0, 0), V2(100, 0), V2(100, 100), V2(0, 100)]
        let hole = [V2(20, 20), V2(40, 20), V2(40, 40), V2(20, 40)]
        XCTAssertEqual(polySubtract(sq, hole).reduce(0.0) { $0 + abs(polyArea($1)) }, 10000.0 - 400, accuracy: 1e-6)
        let l = [V2(0, 0), V2(300, 0), V2(300, 150), V2(600, 150), V2(600, 500), V2(0, 500)]
        let parts = convexParts(l)
        XCTAssertTrue(parts.allSatisfy { isConvex($0) })
        XCTAssertEqual(parts.reduce(0.0) { $0 + abs(polyArea($1)) }, abs(polyArea(l)), accuracy: 1e-6)
    }

    func testOldProjectsLoadWithoutTiles() throws {
        // a project saved before the tiler's app: no tiles, no troom
        let json = #"{"id":"x","name":"Old","industry":"build"}"#
        let p = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertTrue(p.tiles.isEmpty && p.troom.isEmpty)
        // a layout with only its id gets every default
        let l = try JSONDecoder().decode(TileLayout.self, from: Data(#"{"id":"l"}"#.utf8))
        XCTAssertEqual(l.a, 600); XCTAssertEqual(l.pattern, "straight"); XCTAssertTrue(l.align); XCTAssertNil(l.spare)
    }
}
