import XCTest
@testable import METRX

/// Dragging furniture on the room's plan (Placing.swift; Android PlacingTest): the walls, poses, what a piece covers and
/// what it gets in the way of.
final class PlacingTests: XCTestCase {
    private let ws = Workshop()
    // 4,0 × 3,0 m: a door on wall C near its end, a window in the middle of wall A
    private var room: Room {
        var r = Room(id: "r1", floorId: "w1", name: "Xona")
        r.dims = ["A": Dim(v: 4000), "B": Dim(v: 3000), "H": Dim(v: 2700)]
        r.openings = [Opening(id: "d1", type: "door", wall: "C", w: 900, h: 2100, off: 2800), Opening(id: "o1", type: "window", wall: "A", w: 1200, h: 1500, off: 1400, sill: 900)]
        return r
    }
    private var walls: [PlanWall] { planWalls(room, true) }

    func testEveryWallKnowsTheInsideOfTheRoom() {
        let a = walls.first { $0.id == "A" }!, c = walls.first { $0.id == "C" }!
        XCTAssertEqual(a.n.y, 1, accuracy: 1e-9); XCTAssertEqual(c.n.y, -1, accuracy: 1e-9)
        XCTAssertTrue(inside(walls.map(\.p0), a.at(2000, 500)))
    }

    func testAPoseComesBackFromItsFrame() {
        let p = Pose("B", 1200, 800, 30)
        XCTAssertEqual(poseOf(walls, "B", frameOf(walls, p)!), p)
        let fr = frameOf(walls, p)!, t = turned(fr, 1200, 600, 90)
        let mid = { (f: Frame) in f.o + f.u * 600 + f.n * 300 }
        XCTAssertEqual(mid(fr).x, mid(t).x, accuracy: 1e-6); XCTAssertEqual(mid(fr).y, mid(t).y, accuracy: 1e-6)
    }

    func testInFrontOfAWindowOrInADoorsSwingItSaysSo() {
        let clear = placed(newFreeWardrobe("Shkaf 1", "h3", 1500, 2200, 600, false, "door", ws), ["D"], "r1", "w1", off: 1200)
        XCTAssertTrue(placeWarnings(clear, [], room, walls, ws).isEmpty)
        let ward = placed(newFreeWardrobe("Shkaf 1", "h3", 1500, 2200, 600, false, "door", ws), ["A"], "r1", "w1", off: 1300)
        XCTAssertEqual(placeWarnings(ward, [], room, walls, ws).map(\.key), ["fz.hitWin"])
        let byDoor = placed(newFreeWardrobe("Shkaf 1", "h3", 1000, 2200, 600, false, "door", ws), ["C"], "r1", "w1", off: 2900)
        XCTAssertEqual(placeWarnings(byDoor, [], room, walls, ws).map(\.key), ["fz.hitDoor"])
    }

    func testTwoPiecesOnTopOfEachOtherAndOneOutside() {
        let a = placed(newFreeWardrobe("Shkaf 1", "h3", 1200, 2200, 600, false, "door", ws), ["B"], "r1", "w1", off: 200)
        let b = placed(newFreeWardrobe("Shkaf 2", "h3", 1200, 2200, 600, false, "door", ws), ["B"], "r1", "w1", off: 900)
        XCTAssertTrue(placeWarnings(b, [a], room, walls, ws).map(\.key).contains("fz.hitPiece"))
        // side by side they only touch, but a door hinged where they meet would hit the other's fronts…
        let c = placed(newFreeWardrobe("Shkaf 2", "h3", 1200, 2200, 600, false, "door", ws), ["B"], "r1", "w1", off: 1400)
        XCTAssertEqual(placeWarnings(c, [a], room, walls, ws).map(\.key), ["fz.doorsHit"])
        // …so 50 mm between them lets it open
        let c2 = placed(newFreeWardrobe("Shkaf 2", "h3", 1200, 2200, 600, false, "door", ws), ["B"], "r1", "w1", off: 1450)
        XCTAssertTrue(placeWarnings(c2, [a], room, walls, ws).isEmpty)
        var desk = newFreeCabinet("Stol 1", "desk", 1200, 750, 600, ws); desk.roomId = "r1"; desk.pose = Pose("A", 2500, 2700, 0)
        XCTAssertTrue(placeWarnings(desk, [], room, walls, ws).map(\.key).contains("fz.outside"))
    }

    func testAOneWallKitchenSlidesAlongItsWall() {
        let k = newFreeKitchen("Oshxona 1", "I", "I", [2400], 0, 2700, ws)
        let len = { (id: String) -> Int? in id == "A" || id == "C" ? 4000 : 3000 }
        let p = placed(k, ["C"], "r1", "w1", len: len, ws: ws, start: 800)
        XCTAssertEqual(leadOf(p), 800)
        XCTAssertEqual(footsOf(p, walls, ws).first { $0.floor }!.a0, 800, accuracy: 1e-9)
        XCTAssertEqual(leadOf(placed(p, ["C"], "r1", "w1", len: len, ws: ws, start: 300)), 300)
        XCTAssertEqual(fitIssues(k, ["C"], len, 2700, ws, start: 1700).map(\.key), ["fz.long"])
    }

    func testTheIslandStandsWhereItWasDragged() {
        var k = placed(newFreeKitchen("Oshxona 1", "O", "O", [3000], 1800, 2700, ws), ["A", ISLAND], "r1", "w1", ws: ws)
        // in front of wall A, its back 2,02 m out, the worktop 318 past it for sitting at
        XCTAssertTrue(footsOf(k, walls, ws).first { $0.island }!.pts.allSatisfy { (1400...2350).contains($0.y) })
        k.pose = Pose("A", 3000, 1500, 180)
        XCTAssertTrue(footsOf(k, walls, ws).first { $0.island }!.pts.allSatisfy { (900...1830).contains($0.y) })
        // a peninsula joins the end of its side at a right angle
        let p = placed(newFreeKitchen("Oshxona 1", "P", "P", [3000], 1600, 2700, ws), ["A", ISLAND], "r1", "w1", ws: ws)
        XCTAssertEqual(islandPoseIn(p, walls)?.deg, 90)
        XCTAssertTrue(footsOf(p, walls, ws).first { $0.island }!.pts.allSatisfy { $0.y >= 599 })
    }
}
