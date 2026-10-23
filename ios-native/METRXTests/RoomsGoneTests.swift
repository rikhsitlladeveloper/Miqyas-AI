import XCTest
@testable import METRX

/// Deleting a room takes its trades' data along (and Undo puts it back); older orders lose what was left on deleted
/// rooms (Data/RoomsGone.swift; Android RoomsGoneTest, same cases).
final class RoomsGoneTests: XCTestCase {
    private var a: Room {
        var r = Room(id: "a", floorId: "w1", name: "Hammom")
        r.dims = ["A": Dim(v: 3000), "B": Dim(v: 2000), "H": Dim(v: 2700), "T": Dim(v: 380)]
        return r
    }
    private var b: Room { Room(id: "b", floorId: "w2", name: "Oshxona") }
    private var p: Project {
        var p = Project(id: "p", name: "T")
        p.floors = [Workspace(id: "w1", name: "Hammom"), Workspace(id: "w2", name: "Oshxona")]
        p.rooms = [a, b]
        p.tiles = [TileLayout(id: "ta", roomId: "a", surfs: [TSurf(id: "floor")]), TileLayout(id: "tb", roomId: "b"), TileLayout(id: "tf", roomId: nil)]
        p.troom = [TileRoom(roomId: "a"), TileRoom(roomId: "b")]
        p.elec = ElecOrder(devs: [ElecDev(id: "da", t: "s1", roomId: "a", wall: "A", off: 500, h: 300), ElecDev(id: "db", t: "s1", roomId: "b", wall: "A", off: 500, h: 300)],
                           rooms: [ElecRoom(roomId: "a"), ElecRoom(roomId: "b")], panel: ElecPanel(roomId: "a", wall: "A", off: 1000), free: [ElecFree(id: "f")])
        p.plumb = PlumbOrder(fixes: [PlFix(id: "fa", t: "wc", roomId: "a", wall: "C", off: 500), PlFix(id: "fb", t: "sink", roomId: "b", wall: "C", off: 500)],
                             points: [PlPoint(id: "pa", t: "cold", roomId: "a", wall: "C", off: 900, h: 550)],
                             rooms: [PlRoom(roomId: "a", kind: "bath"), PlRoom(roomId: "b", kind: "kitchen")], riser: PlRiser(roomId: "a", wall: "C", off: 140))
        p.win = WinOrder(items: [WinItem(id: "wa", kind: "w2", roomId: "a", opening: "o1", w: 1260, h: 1360),
                                 WinItem(id: "wb", kind: "w2", roomId: "b", opening: "o2", w: 1260, h: 1360)])
        return p
    }

    func testDeletingARoomTakesItsTradesDataAndUndoPutsItBack() {
        let p0 = p
        let (q, g) = tradesOut(p0, ["a"])
        XCTAssertEqual(q.tiles.map(\.id), ["tb", "tf"])
        XCTAssertEqual(q.troom.map(\.roomId), ["b"])
        XCTAssertEqual(q.elec.devs.map(\.id), ["db"]); XCTAssertEqual(q.elec.rooms.map(\.roomId), ["b"]); XCTAssertNil(q.elec.panel)
        XCTAssertEqual(q.plumb.fixes.map(\.id), ["fb"]); XCTAssertTrue(q.plumb.points.isEmpty); XCTAssertNil(q.plumb.riser)
        XCTAssertEqual(q.plumb.rooms.map(\.roomId), ["b"])
        // its window stays, without a room, in a wall as thick as the room's
        let wa = q.win.item("wa")!
        XCTAssertNil(wa.roomId); XCTAssertNil(wa.opening); XCTAssertEqual(wa.freeT, 380); XCTAssertFalse(wa.fit)
        XCTAssertEqual(q.win.item("wb")?.roomId, "b")
        // Undo
        let back = tradesBack(q, g)
        XCTAssertEqual(Set(back.tiles.map(\.id)), Set(p0.tiles.map(\.id)))
        XCTAssertEqual(back.elec.devs.sorted { $0.id < $1.id }, p0.elec.devs.sorted { $0.id < $1.id }); XCTAssertEqual(back.elec.panel, p0.elec.panel)
        XCTAssertEqual(back.plumb.fixes.sorted { $0.id < $1.id }, p0.plumb.fixes.sorted { $0.id < $1.id }); XCTAssertEqual(back.plumb.riser, p0.plumb.riser)
        XCTAssertEqual(back.win.items, p0.win.items)
        // another room's data is never touched
        XCTAssertEqual(tradesOut(p0, []).0, p0)
    }

    func testAnOlderOrdersDataOnDeletedRoomsGoesWhenItLoads() {
        var old = p
        old.rooms = [b]
        let q = withoutOrphans(old)
        XCTAssertFalse(q.tiles.contains { $0.roomId == "a" }); XCTAssertFalse(q.elec.devs.contains { $0.roomId == "a" })
        XCTAssertNil(q.elec.panel); XCTAssertNil(q.plumb.riser)
        XCTAssertNil(q.win.item("wa")?.roomId)
        // rooms typed by size are not drawn rooms: kept
        XCTAssertEqual(q.elec.free, p.elec.free)
        XCTAssertEqual(withoutOrphans(q), q)
    }
}
