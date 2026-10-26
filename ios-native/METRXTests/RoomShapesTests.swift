import XCTest
@testable import METRX

/// Room shapes (design/room-shapes/BUILD_SPEC.md "Geometry"): every case of the shared list
/// design/room-shapes/shape-cases.json, made from the approved mockup by gen_cases.js and run by the Android tests too
/// (RoomShapesTest.kt), then the step checks, the item checks and the conversion into the app's Room (ShapeRoomTest.kt).
final class RoomShapesTests: XCTestCase {
    private struct WallCase: Decodable { let wall: String; let len: Double; let auto: Bool; let angle: Double? }
    private struct Case: Decodable {
        let shape: String
        let mirror: Bool
        let turns: Int
        let asked: [String]
        let input: [Int]
        let ok: Bool
        let error: Bool
        let corners: [[Double]]
        let cornersShown: [[Double]]
        let walls: [WallCase]
        let areaMm2: Double
    }
    private struct File: Decodable { let cases: [Case] }

    /// The free sketch gen_cases.js uses for its free cases (the json does not carry it).
    private let sketch = FreeSketch(
        dirs: [Pt(x: 1, y: 0), Pt(x: 0, y: 1), Pt(x: -1, y: 0), Pt(x: 0, y: 1), Pt(x: -1, y: 0), Pt(x: 0, y: -1)],
        hints: [4400, 2600, 2000, 1800, 2400, 4400])

    private func loadCases() throws -> [Case] {
        let url = try XCTUnwrap(Bundle(for: RoomShapesTests.self).url(forResource: "shape-cases", withExtension: "json"))
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).cases
    }

    private func near(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) <= tol }

    func testSharedCases() throws {
        let cases = try loadCases()
        XCTAssertEqual(cases.count, 34)
        for (n, c) in cases.enumerated() {
            let shape = try XCTUnwrap(RoomShape.of(c.shape))
            let spec = ShapeSpec(shape, mirror: c.mirror, turns: c.turns, sketch: shape == .free ? sketch : nil)
            let tag = "case \(n) \(c.shape) mirror \(c.mirror) turns \(c.turns) \(c.input)"
            XCTAssertEqual(asks(spec).map(\.key), c.asked, tag)
            let g = shapeGeometry(spec, c.input)
            XCTAssertEqual(g.values, c.input, tag)
            XCTAssertEqual(g.ok, c.ok, tag + " error \(String(describing: g.error))")
            XCTAssertEqual(g.error != nil, c.error, tag)
            XCTAssertEqual(g.corners.count, c.corners.count, tag + " corners")
            for (i, p) in g.corners.enumerated() where i < c.corners.count {
                XCTAssertTrue(near(p.x, c.corners[i][0]) && near(p.y, c.corners[i][1]), tag + " corner \(i): \(p) vs \(c.corners[i])")
            }
            let shown = g.cornersShown
            XCTAssertEqual(shown.count, c.cornersShown.count, tag + " cornersShown")
            for (i, p) in shown.enumerated() where i < c.cornersShown.count {
                XCTAssertTrue(near(p.x, c.cornersShown[i][0]) && near(p.y, c.cornersShown[i][1]), tag + " shown \(i): \(p) vs \(c.cornersShown[i])")
            }
            XCTAssertEqual(g.walls.count, c.walls.count, tag + " walls")
            for (i, w) in g.walls.enumerated() where i < c.walls.count {
                let e = c.walls[i]
                XCTAssertEqual(w.letter, e.wall, tag)
                XCTAssertTrue(near(w.len, e.len), tag + " wall \(e.wall): \(w.len) vs \(e.len)")
                XCTAssertEqual(w.derived, e.auto, tag + " wall \(e.wall) derived")
                XCTAssertEqual(w.angle, e.angle.map { Int($0) }, tag + " wall \(e.wall) angle")
            }
            XCTAssertTrue(near(g.areaMm2, c.areaMm2), tag + " area \(g.areaMm2) vs \(c.areaMm2)")
        }
    }

    func testShapesAndDefaults() throws {
        let cases = try loadCases()
        XCTAssertEqual(RoomShape.allCases.map(\.id), ["rect", "L", "U", "cut", "T", "Z", "bay", "free"])
        XCTAssertEqual(RoomShape.allCases.map(\.askCount), [2, 4, 6, 4, 6, 6, 5, 0])
        XCTAssertEqual(RoomShape.allCases.map(\.wallCount), [4, 6, 8, 5, 8, 8, 8, nil])
        for s in RoomShape.allCases where s != .free {
            let spec = ShapeSpec(s)
            let first = try XCTUnwrap(cases.first { $0.shape == s.id })
            XCTAssertEqual(asks(spec).map(\.def), first.input, s.id)
            // nothing typed: the defaults
            XCTAssertEqual(shapeGeometry(spec, []), shapeGeometry(spec, first.input), s.id)
            XCTAssertTrue(shapeGeometry(spec, []).ok, s.id)
        }
        XCTAssertNil(RoomShape.of("nope"))
        XCTAssertEqual(asks(ShapeSpec(.free)).count, 0)
        XCTAssertEqual(shapeGeometry(ShapeSpec(.free), []).error?.code, .empty)
        XCTAssertEqual(asks(ShapeSpec(.bay)).map(\.kind), [.wall, .wall, .wall, .bayWidth, .bayDepth])
        // the bay's width and depth guide lines
        let bay = shapeGeometry(ShapeSpec(.bay), [])
        XCTAssertEqual(bay.guides, [ShapeGuide(a: Pt(x: 1000, y: 0), b: Pt(x: 3400, y: 0), ask: 3), ShapeGuide(a: Pt(x: 2200, y: 0), b: Pt(x: 2200, y: -800), ask: 4)])
        XCTAssertEqual(bay.size.w, 4200, accuracy: 1e-9)
        XCTAssertEqual(bay.size.h, 4400, accuracy: 1e-9)
    }

    func testErrorCodes() {
        func err(_ s: RoomShape, _ v: [Int?]) -> ShapeError? { shapeGeometry(ShapeSpec(s, sketch: s == .free ? sketch : nil), v).error }
        XCTAssertEqual(err(.cut, [3600, 3000, 2800, 3000]), ShapeError(.cutNoCut))
        XCTAssertEqual(err(.T, [4800, 1400, 3400, 2200, 1600, 2200]), ShapeError(.wallNegative, wall: 6, value: -200))
        XCTAssertEqual(err(.Z, [2600, 1600, 1800, 2400, 5000, 1400]), ShapeError(.wallNegative, wall: 6, value: -600))
        XCTAssertEqual(err(.bay, [4200, 3600, 1000, 1400, 800]), ShapeError(.bayTooDeep))
        XCTAssertEqual(err(.bay, [4200, 3600, 2500, 2400, 800]), ShapeError(.bayNotFit, value: 4900, limit: 4200))
        // U whose last side is shorter than its arms: the closing wall cuts through them
        XCTAssertEqual(err(.U, [1400, 1800, 1600, 1800, 1400, 1000]), ShapeError(.wallsCross))
        let gap = err(.free, [4400, 2600, 2000, 1800, 2400, 4700])
        XCTAssertEqual(gap?.code, .notClosed)
        XCTAssertEqual(gap?.value ?? 0, 300, accuracy: 0.001)
        // a 20 mm gap is spread, and said
        let g = shapeGeometry(ShapeSpec(.free, sketch: sketch), [4400, 2600, 2000, 1800, 2400, 4420])
        XCTAssertNil(g.error)
        XCTAssertEqual(g.gapFixed, 20, accuracy: 0.001)
        XCTAssertEqual(ShapeErrorCode.wallsCross.rawValue, "WALLS_CROSS")
        XCTAssertEqual(ShapeErrorCode.outOfRange.rawValue, "OUT_OF_RANGE")
    }

    func testCrossingWalls() {
        XCTAssertFalse(isSimplePolygon([Pt(x: 0, y: 0), Pt(x: 100, y: 100), Pt(x: 100, y: 0), Pt(x: 0, y: 100)]))
        XCTAssertTrue(isSimplePolygon([Pt(x: 0, y: 0), Pt(x: 100, y: 0), Pt(x: 100, y: 100), Pt(x: 0, y: 100)]))
        // a corner touching another wall counts as crossing
        XCTAssertFalse(isSimplePolygon([Pt(x: 0, y: 0), Pt(x: 200, y: 0), Pt(x: 200, y: 100), Pt(x: 100, y: 0), Pt(x: 0, y: 100)]))
    }

    func testMirrorAndTurn() {
        let s = ShapeSpec(.L)
        XCTAssertTrue(s.mirrored().mirror)
        XCTAssertEqual(s.mirrored().mirrored(), s)
        XCTAssertEqual(s.turned().turned().turned().turned(), s)
        XCTAssertEqual(s.turned().turns, 1)
        XCTAssertEqual(ShapeSpec(.L, turns: -1).turn, 3)
        XCTAssertEqual(shownPoint(Pt(x: 3, y: 5), ShapeSpec(.L, mirror: true, turns: 1)), Pt(x: -5, y: -3))
        // the plan itself does not change with mirror or turn, only how it is shown
        XCTAssertEqual(shapeGeometry(ShapeSpec(.U, mirror: true, turns: 3), []).corners, shapeGeometry(ShapeSpec(.U), []).corners)
        XCTAssertGreaterThan(polygonArea(shapeGeometry(ShapeSpec(.U), []).corners), 0)
        XCTAssertLessThan(polygonArea(shapeGeometry(ShapeSpec(.U, mirror: true), []).cornersShown), 0)
    }

    func testStepErrors() {
        let cut = ShapeSpec(.cut)
        XCTAssertEqual(stepError(cut, [3600, 2200, 3600], 2), ShapeError(.cutDNotShorter, wall: 3, limit: 3600))
        XCTAssertNil(stepError(cut, [3600, 2200, 2800], 2))
        XCTAssertEqual(stepError(cut, [3600, 3000, 2800, 3000], 3), ShapeError(.cutBNotShorter, wall: 1, limit: 3000))
        XCTAssertNil(stepError(cut, [3600, 2200, 2800, 3000], 3))
        let bay = ShapeSpec(.bay)
        // the bay's width step: only "does not fit the wall" is said this early
        XCTAssertEqual(stepError(bay, [4200, 3600, 2500, 2400], 3)?.code, .bayNotFit)
        XCTAssertNil(stepError(bay, [4200, 3600, 1000, 1400], 3))
        XCTAssertEqual(stepError(bay, [4200, 3600, 1000, 1400, 800], 4)?.code, .bayTooDeep)
        XCTAssertNil(stepError(bay, [4200, 3600, 1000], 2))
        let t = ShapeSpec(.T)
        // T: the negative closing wall is said on the last step, or when one value is changed from the summary
        XCTAssertNil(stepError(t, [4800, 1400, 3400], 2))
        XCTAssertEqual(stepError(t, [4800, 1400, 3400, 2200, 1600, 2200], 2, editingOne: true)?.code, .wallNegative)
        XCTAssertEqual(stepError(t, [4800, 1400, 3400, 2200, 1600, 2200], 5)?.code, .wallNegative)
        // the range of a typed size, before anything else
        XCTAssertEqual(stepError(t, [299], 0)?.code, .outOfRange)
        XCTAssertEqual(stepError(t, [20_001], 0)?.code, .outOfRange)
        XCTAssertEqual(stepError(t, [nil], 0)?.code, .outOfRange)
        XCTAssertEqual(stepError(t, [], 0)?.code, .outOfRange)
        XCTAssertNil(stepError(t, [300], 0))
        XCTAssertEqual(wallValueError(250), ShapeError(.outOfRange, value: 250, limit: 20_000, min: 300))
        // height
        XCTAssertNil(heightError(2700))
        XCTAssertNil(heightError(2000))
        XCTAssertNil(heightError(6000))
        XCTAssertEqual(heightError(1999)?.code, .outOfRange)
        XCTAssertEqual(heightError(6001)?.code, .outOfRange)
        XCTAssertEqual(heightError(nil)?.code, .outOfRange)
    }

    func testDiagonal() {
        let f = ShapeSpec(.free, sketch: sketch)
        let v: [Int?] = [4400, 2600, 2000, 1800, 2400, 4400]
        XCTAssertEqual(diagonalCorner(f), 3)
        XCTAssertEqual(expectedDiagonal(shapeGeometry(f, v)), hypot(2400, 2600), accuracy: 0.001)
        // within 20 mm (the editor's tolerance) of the walls' 3 538
        XCTAssertNil(diagonalError(f, v, 3550))
        XCTAssertEqual(diagonalError(f, v, 3560)?.code, .diagMismatch)
        XCTAssertEqual(diagonalError(f, v, 3700)?.code, .diagMismatch)
        XCTAssertEqual(diagonalError(f, v, 200)?.code, .outOfRange)
        XCTAssertEqual(diagonalError(f, v, nil)?.code, .outOfRange)
    }

    func testFreeSketchFromCorners() {
        let sk = freeSketch([Pt(x: 0, y: 0), Pt(x: 4400, y: 0), Pt(x: 4400, y: 2600), Pt(x: 2400, y: 2600), Pt(x: 2400, y: 4400), Pt(x: 0, y: 4400)])
        XCTAssertEqual(sk, sketch)
    }

    func testOpeningFields() {
        XCTAssertEqual(opAsks(.door).map(\.field), [.dist, .width, .height])
        XCTAssertEqual(opAsks(.window), [OpAsk(field: .dist, def: 900), OpAsk(field: .width, def: 1500), OpAsk(field: .height, def: 1500), OpAsk(field: .sill, def: 900)])
        XCTAssertEqual(opAsks(.gas).map(\.field), [.dist])
        let big = shapeGeometry(ShapeSpec(.rect), [3400, 2600])
        let small = shapeGeometry(ShapeSpec(.rect), [1200, 2600])
        XCTAssertEqual(opHint(big, 2700, .door, 0, .dist), 600)
        XCTAssertEqual(opHint(small, 2700, .door, 0, .dist), 200)
        XCTAssertEqual(opHint(small, 2700, .door, 0, .width, dist: 500), 700)
        XCTAssertEqual(opHint(big, 2000, .door, 0, .height), 2000)
        XCTAssertEqual(opHint(big, 2700, .window, 0, .sill, h: 1500), 900)
        XCTAssertEqual(opHint(big, 2700, .window, 0, .sill, h: 2000), 700)
        XCTAssertEqual(opHint(big, 2700, .gas, 1, .dist), 1200)
        XCTAssertEqual(opFieldError(big, 2700, .door, 0, .dist, 3500), ShapeError(.opPastWall, wall: 0, value: 3500, limit: 3400))
        XCTAssertNil(opFieldError(big, 2700, .door, 0, .dist, 3400))
        XCTAssertEqual(opFieldError(big, 2700, .door, 0, .width, 200, dist: 400)?.code, .outOfRange)
        XCTAssertEqual(opFieldError(big, 2700, .door, 0, .width, 3100, dist: 400), ShapeError(.opNotFit, wall: 0, value: 3500, limit: 3400))
        XCTAssertEqual(opFieldError(big, 2700, .door, 0, .height, 2800)?.code, .outOfRange)
        XCTAssertEqual(opFieldError(big, 2700, .window, 0, .sill, 1300, h: 1500), ShapeError(.opAboveCeiling, value: 2800, limit: 2700))
        XCTAssertNil(opFieldError(big, 2700, .window, 0, .sill, 1200, h: 1500))
        XCTAssertEqual(opFieldError(big, 2700, .gas, 0, .dist, nil)?.code, .empty)
        XCTAssertNil(openingError(big, 2700, ShapeOpening(.door, 2, 400, 900, 2100)))
        XCTAssertEqual(openingError(big, 2700, ShapeOpening(.window, 0, 2500, 1500, 1500, 900))?.code, .opNotFit)
        XCTAssertEqual(openingError(big, 2700, ShapeOpening(.gas, 9, 100))?.code, .empty)
    }

    /* ---------------- the Room ---------------- */

    private func make(_ spec: ShapeSpec, _ vals: [Int?], _ ops: [ShapeOpening] = [], diag: Int? = nil) throws -> ShapeRoom {
        try XCTUnwrap(shapeToRoom(spec, vals, height: 2700, id: uid(), floorId: "f1", name: "Oshxona", created: 5, diagonal: diag, openings: ops))
    }

    /// Room walls as the editor sees them: length by id.
    private func lens(_ r: Room) -> [String: Int] {
        var out: [String: Int] = [:]
        for w in Geo.walls(r) { out[w.id] = w.len ?? -1 }
        return out
    }

    /// Every measurement confirmed (or worked out), so the editor asks nothing again.
    private func assertMeasured(_ r: Room, _ tag: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Geo.unconfCount(r), 0, tag, file: file, line: line)
        XCTAssertTrue(Geo.allConfirmed(r, 0), tag, file: file, line: line)
        XCTAssertTrue(Geo.ready3D(r), tag, file: file, line: line)
    }

    func testRectangleIsTheAppsPlainRectangle() throws {
        let sr = try XCTUnwrap(shapeToRoom(ShapeSpec(.rect), [4200, 3100], height: 2700, id: "r1", floorId: "f1", name: "Oshxona", created: 5))
        let r = sr.room
        XCTAssertEqual(r.shape, "rect")
        XCTAssertEqual(r.template, "rect")
        XCTAssertNil(r.poly)
        XCTAssertFalse(r.isPoly)
        XCTAssertEqual(r.rot, 0)
        XCTAssertEqual(Set(r.dims.keys), ["A", "B", "H", "T"])
        XCTAssertEqual(r.dim("A"), Dim(v: 4200, src: "manual"))
        XCTAssertEqual(r.dim("B"), Dim(v: 3100, src: "manual"))
        XCTAssertEqual(r.dim("H"), Dim(v: 2700, src: "manual"))
        XCTAssertEqual(r.dim("T"), Dim(v: 200, src: "default"))
        XCTAssertEqual(sr.wallIds, ["A", "B", "C", "D"])
        assertMeasured(r)
        XCTAssertEqual(Geo.areas(r)?.floor, 4200 * 3100)
        // the same room the app makes today (NewRoomSheet / addFurnRoom), with the sizes filled in
        var today = Room(id: "r1", floorId: "f1", name: "Oshxona", created: 5)
        today.dims["A"] = Dim(v: 4200, src: "manual")
        today.dims["B"] = Dim(v: 3100, src: "manual")
        today.dims["H"] = Dim(v: 2700, src: "manual")
        XCTAssertEqual(r, today)
    }

    func testRectangleTurnsWithRot() throws {
        for t in 0...3 {
            let r = try make(ShapeSpec(.rect, turns: t), [3400, 2600]).room
            XCTAssertEqual(r.rot, t)
            XCTAssertEqual(r.dim("A").v, 3400)
            XCTAssertEqual(r.dim("B").v, 2600)
        }
        // mirrored: A stays A, B and D swap sides
        let m = try make(ShapeSpec(.rect, mirror: true), [3400, 2600])
        XCTAssertEqual(m.room.rot, 0)
        XCTAssertEqual(m.wallIds, ["A", "D", "C", "B"])
        XCTAssertEqual(m.flipped, [true, true, true, true])
        let mt = try make(ShapeSpec(.rect, mirror: true, turns: 1), [3400, 2600])
        XCTAssertEqual(mt.room.rot, 1)
    }

    func testEveryShapeBecomesAClosedMeasuredRoom() throws {
        for s in RoomShape.allCases where s != .free {
            for mir in [false, true] {
                for t in 0...3 {
                    let spec = ShapeSpec(s, mirror: mir, turns: t)
                    let g = shapeGeometry(spec, [])
                    let sr = try make(spec, g.values)
                    let r = sr.room
                    let tag = "\(s.id) mirror \(mir) turns \(t)"
                    assertMeasured(r, tag)
                    let fl = try XCTUnwrap(Geo.areas(r)?.floor, tag)
                    XCTAssertEqual(Double(fl), g.areaMm2, accuracy: g.areaMm2 * 5e-4, tag)
                    let ws = Geo.walls(r)
                    XCTAssertEqual(ws.count, g.walls.count, tag)
                    let byId = lens(r)
                    for w in g.walls {
                        let got = Double(byId[sr.roomWall(w.index)] ?? -1)
                        XCTAssertEqual(got, w.len, accuracy: 0.5, tag + " " + w.letter)
                    }
                    if s == .rect { continue }
                    let pg = Geo.polyGeo(r)
                    XCTAssertTrue(pg.solved, tag)
                    XCTAssertNil(pg.err, tag)
                    // clockwise on screen and closed: walking the walls comes back to corner A
                    XCTAssertGreaterThan(Geo.shoelace(r.poly?.verts ?? []), 0, tag)
                    var x = 0.0, y = 0.0
                    for w in ws {
                        x += w.p1.x - w.p0.x
                        y += w.p1.y - w.p0.y
                        XCTAssertEqual(Double(w.len ?? -1), hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y), accuracy: 1, tag)
                    }
                    XCTAssertLessThan(hypot(x, y), 1e-6, tag)
                    XCTAssertEqual(Set(Geo.polyWallIds(g.walls.count)), Set(sr.wallIds), tag)
                    // wall A stays A
                    XCTAssertEqual(sr.roomWall(0), "A", tag)
                }
            }
        }
    }

    func testLShapeWallsAndWorkedOutOnes() throws {
        let r = try make(ShapeSpec(.L), [2000, 1500, 1800, 2200]).room
        XCTAssertEqual(r.shape, "poly")
        XCTAssertEqual(r.template, "poly")
        XCTAssertEqual(r.poly?.template, "rsh.L")
        XCTAssertEqual(r.poly?.snap, true)
        XCTAssertEqual(r.poly?.verts, [Pt(x: 0, y: 0), Pt(x: 2000, y: 0), Pt(x: 2000, y: 1500), Pt(x: 3800, y: 1500), Pt(x: 3800, y: 3700), Pt(x: 0, y: 3700)])
        let ws = Geo.walls(r)
        XCTAssertEqual(ws.map(\.len), [2000, 1500, 1800, 2200, 3800, 3700])
        // the last two are left to the editor's solver: shown computed, not asked again
        XCTAssertEqual(ws.map(\.status), ["conf", "conf", "conf", "conf", "calc", "calc"])
        XCTAssertNil(r.dim("E").v)
        XCTAssertNil(r.dim("F").v)
        XCTAssertEqual(r.dim("B").v, 1500)
        XCTAssertEqual(r.dim("H").v, 2700)
    }

    func testCutCornerKeepsItsAngle() throws {
        let r = try make(ShapeSpec(.cut), [3600, 2200, 3000, 3000]).room
        XCTAssertEqual(r.poly?.snap, false)
        let ws = Geo.walls(r)
        XCTAssertEqual(ws[2].len, 1000)
        XCTAssertEqual(ws[2].status, "calc")
        let fl = try XCTUnwrap(Geo.areas(r)?.floor)
        XCTAssertEqual(Double(fl), 10_560_000, accuracy: 1000)
        // the 45° default keeps the snap
        let c45 = try make(ShapeSpec(.cut), [])
        XCTAssertEqual(c45.room.poly?.snap, true)
    }

    func testBayLeavesItsSidesToTheSolver() throws {
        let sr = try make(ShapeSpec(.bay), [4200, 3600, 1000, 2400, 800])
        let r = sr.room
        XCTAssertEqual(r.poly?.snap, true)
        let ws = Geo.walls(r)
        XCTAssertEqual(ws.map(\.len), [1000, 1131, 800, 1131, 800, 3600, 4200, 3600])
        // the 45° sides are not whole mm: worked out by the editor; every stored length is exact
        XCTAssertEqual(ws.map(\.status), ["conf", "calc", "conf", "calc", "conf", "conf", "conf", "conf"])
        XCTAssertNil(r.dim("B").v)
        XCTAssertNil(r.dim("D").v)
        XCTAssertEqual(r.dim("E").v, 800)
        // the room's own letters skip H (the height): the bay's side wall H is the room's J
        XCTAssertEqual(sr.wallIds, ["A", "B", "C", "D", "E", "F", "G", "J"])
        XCTAssertEqual(r.dim("J"), Dim(v: 3600, src: "manual"))
        XCTAssertEqual(r.dim("H"), Dim(v: 2700, src: "manual"))
        // corners moved so the plan starts at 0, 0 (the bay sticks out above wall A)
        XCTAssertEqual(r.poly?.verts.first, Pt(x: 0, y: 800))
        let fl = try XCTUnwrap(Geo.areas(r)?.floor)
        XCTAssertEqual(Double(fl), 16_400_000, accuracy: 2000)
    }

    func testFreeSketchWithSpreadGapAndDiagonal() throws {
        let spec = ShapeSpec(.free, sketch: sketch)
        let exact = try make(spec, sketch.hints, diag: 3540).room
        XCTAssertEqual(exact.poly?.template, "rsh.free")
        XCTAssertEqual(exact.poly?.snap, true)
        XCTAssertEqual(Geo.walls(exact).map(\.len), [4400, 2600, 2000, 1800, 2400, 4400])
        XCTAssertEqual(exact.poly?.diags, [Diag(id: "X1", a: 0, b: 3)])
        XCTAssertEqual(exact.dim("X1"), Dim(v: 3540, src: "manual"))
        XCTAssertEqual(Geo.polyGeo(exact).diagStatus["X1"], "ok")
        assertMeasured(exact)
        // a 20 mm gap spread over the walls: still closes for the editor
        let spread = try make(spec, [4400, 2600, 2000, 1800, 2400, 4420]).room
        XCTAssertEqual(spread.poly?.snap, false)
        XCTAssertTrue(Geo.polyGeo(spread).solved)
        assertMeasured(spread)
        let typed = [4400, 2600, 2000, 1800, 2400, 4420]
        for (w, v) in zip(Geo.walls(spread), typed) { XCTAssertLessThanOrEqual(abs((w.len ?? 0) - v), 20, w.id) }
        // too big a gap: no room
        XCTAssertNil(shapeToRoom(spec, [4400, 2600, 2000, 1800, 2400, 4700], height: 2700, id: "x", floorId: "f", name: "n"))
    }

    func testBrokenShapesMakeNoRoom() {
        XCTAssertNil(shapeToRoom(ShapeSpec(.T), [4800, 1400, 3400, 2200, 1600, 2200], height: 2700, id: "x", floorId: "f", name: "n"))
        XCTAssertNil(shapeToRoom(ShapeSpec(.cut), [3600, 3000, 2800, 3000], height: 2700, id: "x", floorId: "f", name: "n"))
        XCTAssertNil(shapeToRoom(ShapeSpec(.free), [], height: 2700, id: "x", floorId: "f", name: "n"))
    }

    func testOpeningsLandOnTheirWall() throws {
        let ops = [
            ShapeOpening(.door, 2, 400, 900, 2100),
            ShapeOpening(.window, 0, 1000, 1500, 1500, 900),
            ShapeOpening(.water, 1, 400),
            ShapeOpening(.sewer, 1, 700),
            ShapeOpening(.gas, 3, 1200),
        ]
        let r = try make(ShapeSpec(.rect), [3400, 2600], ops).room
        let door = try XCTUnwrap(r.openings.first { $0.type == "door" })
        XCTAssertEqual(door.wall, "C")
        XCTAssertEqual([door.off, door.w, door.h, door.sill], [400, 900, 2100, 0])
        let win = try XCTUnwrap(r.openings.first { $0.type == "window" })
        XCTAssertEqual(win.wall, "A")
        XCTAssertEqual(win.off, 1000)
        XCTAssertEqual(win.sill, 900)
        for o in r.openings { XCTAssertNil(Geo.openingIssue(r, o, o.type, .mm, false), o.type) }
        let cold = try XCTUnwrap(r.points.first { $0.t == "cold" })
        XCTAssertEqual(cold.wall, "B")
        XCTAssertEqual(cold.off, 400)
        XCTAssertEqual(cold.h, 550)
        let sewer = try XCTUnwrap(r.points.first { $0.t == "sewer" })
        XCTAssertEqual(sewer.off, 700)
        XCTAssertEqual(sewer.d, 50)
        let gas = try XCTUnwrap(r.points.first { $0.t == "gas" })
        XCTAssertEqual(gas.wall, "D")
        XCTAssertEqual(gas.off, 1200)
        XCTAssertEqual(gas.h, 1000)
        XCTAssertEqual(Set(r.openings.map(\.id) + r.points.map(\.id)).count, 5)
    }

    func testMirroredOpeningsAreMeasuredFromTheRoomWallsOwnCorner() throws {
        // L mirrored: shape wall B (index 1, 1 800 long) becomes the room's last wall, running the other way
        let spec = ShapeSpec(.L, mirror: true)
        let g = shapeGeometry(spec, [])
        let sr = try make(spec, g.values, [ShapeOpening(.door, 1, 200, 900, 2100), ShapeOpening(.gas, 1, 300)])
        let r = sr.room
        XCTAssertEqual(sr.roomWall(1), "F")
        XCTAssertEqual(r.poly?.verts, [Pt(x: 2400, y: 0), Pt(x: 4200, y: 0), Pt(x: 4200, y: 3600), Pt(x: 0, y: 3600), Pt(x: 0, y: 1800), Pt(x: 2400, y: 1800)])
        XCTAssertEqual(sr.wallIds, ["A", "F", "E", "D", "C", "B"])
        let door = try XCTUnwrap(r.openings.first)
        XCTAssertEqual(door.wall, "F")
        XCTAssertEqual(door.off, 1800 - 200 - 900)
        XCTAssertEqual(r.points.first?.off, 1800 - 300)
        // the door is where the shape put it: its far edge 200 mm from the shape wall's start corner
        let w = try XCTUnwrap(Geo.walls(r).first { $0.id == "F" })
        let wlen = try XCTUnwrap(w.len)
        let wl = Double(wlen)
        let shownStart = shownPoint(g.walls[1].from, spec)
        let t = Double(door.off + door.w) / wl
        let farX = w.p0.x + (w.p1.x - w.p0.x) * t
        let farY = w.p0.y + (w.p1.y - w.p0.y) * t
        // the room's corners were moved by the same offset as the shown ones (room corner 0 is shown corner 1)
        let v0 = try XCTUnwrap(r.poly?.verts.first)
        let dx = v0.x - g.cornersShown[1].x, dy = v0.y - g.cornersShown[1].y
        XCTAssertEqual(hypot(farX - (shownStart.x + dx), farY - (shownStart.y + dy)), 200, accuracy: 1e-6)
        XCTAssertNil(Geo.openingIssue(r, door, "door", .mm, false))
    }

    func testTurnedPolygonsAreBakedIntoTheCorners() throws {
        let r = try make(ShapeSpec(.L, turns: 1), [1800, 1800, 2400, 1800]).room
        XCTAssertEqual(r.rot, 0)
        // wall A runs down the right-hand side after the turn
        let a = try XCTUnwrap(Geo.walls(r).first { $0.id == "A" })
        XCTAssertEqual(a.p1.x - a.p0.x, 0, accuracy: 1e-9)
        XCTAssertEqual(a.p1.y - a.p0.y, 1800, accuracy: 1e-9)
    }

    func testRoomSpaceHelpers() {
        var r = Room(id: uid(), floorId: "w", name: "x")
        let o = placeOpening(&r, type: "window", wall: "B", off: 300, w: 1200, h: 1400, sill: 900)
        XCTAssertEqual(o.sill, 900)
        let d = placeOpening(&r, type: "door", wall: "A", off: 100, w: 800, h: 2000, sill: 300)
        XCTAssertEqual(d.sill, 0)
        let p = placeSitePoint(&r, kind: .water, wall: "C", off: 900)
        XCTAssertEqual(p.t, "cold")
        XCTAssertEqual(p.off, 900)
        XCTAssertEqual(p.h, pointDefaults("cold").h)
        XCTAssertEqual(r.openings.count, 2)
        XCTAssertEqual(r.points.count, 1)
        // the laser's readings keep their source
        let laser = shapeToRoom(ShapeSpec(.rect), [4200, 3100], height: 2700, id: "l", floorId: "f", name: "n", src: "laser")
        XCTAssertEqual(laser?.room.dim("A"), Dim(v: 4200, src: "laser"))
    }
}
