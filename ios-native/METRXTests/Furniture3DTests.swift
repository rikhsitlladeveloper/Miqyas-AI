import XCTest
@testable import METRX

/// Furniture in 3D (furniture plan section 9; Android Furniture3DTest): placed on its wall, doors that swing, taps that
/// find them.
final class Furniture3DTests: XCTestCase {
    private let ws = Workshop()
    private var shell: Shell3D {
        var r = Room(id: "r", floorId: "f", name: "Oshxona")
        r.dims = ["A": Dim(v: 3400, src: "manual"), "B": Dim(v: 2600, src: "manual"), "H": Dim(v: 2700, src: "manual"), "T": Dim(v: 200, src: "default")]
        return buildShell([r], single: true)
    }
    private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-6 }

    func testWallFramesFollowTheRoom() {
        let s = shell
        let a = s.bases["A"]!, b = s.bases["B"]!, d = s.bases["D"]!
        XCTAssertTrue(near(a.ox, 0.2) && near(a.oz, 0) && near(a.nz, 1) && near(a.len, 3.4))
        XCTAssertTrue(near(b.ox, 3.6) && near(b.uz, 1) && near(b.nx, -1))
        // wall D runs from corner 4 back to corner 1: its far end is where wall A starts
        let end = d.at(d.len, 0, 0)
        XCTAssertTrue(near(end.x, a.ox) && near(end.z, a.oz))
    }

    func testDoorsSwingAndTapsFindThem() {
        let f0 = Furniture(id: "k", kind: "kitchen", walls: ["A", "B"], layout: "L")
        let f = autoFill(f0, runsOf(f0) { ["A": 3400, "B": 2600][$0] }, ws, [], [])
        let bases = shell.bases
        let shut = furniture3D([f], bases, ws, { _ in 0xCDBFAE }, [])
        let key = shut.keys.first { $0.hasSuffix(":f0") }!
        let opened = furniture3D([f], bases, ws, { _ in 0xCDBFAE }, [key])
        XCTAssertEqual(shut.parts.count, opened.parts.count)            // the camera keeps its place when a door opens
        let a = shut.picks.first { $0.key == key }!.box, b = opened.picks.first { $0.key == key }!.box
        // closed, the door lies along the wall; open (at 90°, a unit stands beside it) it stands straight out into the room
        XCTAssertTrue(abs(a.a.z) < 1e-9 && a.a.x > 0)
        XCTAssertTrue(b.a.z > 0.99 * b.a.len && abs(b.a.x) < 1e-6)
        // a ray straight at the door's middle, from inside the room, hits it
        let mid = a.o + (a.a + a.b + a.c) * 0.5
        let eye = V3(mid.x, mid.y, 2)
        XCTAssertNotNil(a.hit(eye, V3(0, 0, -1)))
        XCTAssertNil(a.hit(eye, V3(0, 0, 1)))
        XCTAssertEqual(shut.pick(eye, V3(0, 0, -1)), key)
    }

    func testAWardrobeHasNoSidesAtTheWalls() {
        let m = wardrobeTemplate(ws, "B", 10, 2580, 2680, builtIn: true)
        let fr = furniture3D([Furniture(id: "w", kind: "wardrobe", walls: ["B"], modules: [m])], shell.bases, ws, { _ in 0xF5F5F2 }, [])
        XCTAssertEqual(fr.keys.filter { $0.contains(":f") }.count, m.sections.reduce(0) { $0 + ($1.w >= 600 ? 2 : 1) })
        // everything stands between the walls A and C (z 0 … 2.6) and inside wall B (x ≤ 3.6)
        let pts = fr.parts.flatMap { $0.faces.flatMap(\.pts) }
        XCTAssertTrue(pts.allSatisfy { $0.z >= -1e-6 && $0.z <= 2.6 + 1e-6 && $0.x <= 3.6 + 1e-6 })
        XCTAssertTrue(fr.parts.allSatisfy { $0.role == .furn })
    }

    private func allFinite(_ d: Furn3D) -> Bool {
        for p in d.parts { for fc in p.faces { for q in fc.pts where !(q.x.isFinite && q.y.isFinite && q.z.isFinite) { return false } } }
        return true
    }

    func testEveryGalleryPieceBuildsIn3DAndOpens() {
        for id in GALLERY.flatMap({ $0.1 }) {
            let f = pieceOf(fModel(id)!, [:], ws, id)
            let sh = buildShell([freeRoom(f)], single: true)
            let shut = furniture3D([f], sh.bases, ws, { _ in 0xCDBFAE }, [])
            XCTAssertTrue(shut.parts.reduce(0) { $0 + $1.faces.count } > 0, id)
            XCTAssertTrue(allFinite(shut), id)
            let open = furniture3D([f], sh.bases, ws, { _ in 0xCDBFAE }, Set(shut.keys))
            XCTAssertTrue(allFinite(open), id)
        }
    }

    func testALiftUpBedRisesAndABedsDrawersPullOutSideways() {
        let lift = pieceOf(fModel("bed")!, ["bt": 2], ws, "Karavot")
        let sh = buildShell([freeRoom(lift)], single: true)
        let shut = furniture3D([lift], sh.bases, ws, { _ in 0xCDBFAE }, [])
        let lifts = shut.keys.filter { $0.hasSuffix(":lift") }
        XCTAssertEqual(lifts.count, 1)
        func top(_ d: Furn3D) -> Double { d.parts.flatMap { $0.faces }.flatMap { $0.pts }.map(\.y).max() ?? 0 }
        let open = furniture3D([lift], sh.bases, ws, { _ in 0xCDBFAE }, Set(lifts))
        XCTAssertTrue(top(open) > top(shut) + 0.5)
        let dr = pieceOf(fModel("bed")!, ["bt": 1], ws, "Karavot")
        let sh2 = buildShell([freeRoom(dr)], single: true)
        let d0 = furniture3D([dr], sh2.bases, ws, { _ in 0xCDBFAE }, [])
        XCTAssertEqual(d0.keys.filter { $0.contains(":bd") }.count, 4)
        let k = d0.keys.first { $0.contains(":bd") }!
        let a = d0.picks.first { $0.key == k }!.box
        let b = furniture3D([dr], sh2.bases, ws, { _ in 0xCDBFAE }, [k]).picks.first { $0.key == k }!.box
        // out of the bed's side: along the wall, not out from it
        XCTAssertTrue(abs(b.o.x - a.o.x) > 0.3 && abs(b.o.z - a.o.z) < 1e-6)
    }
}
