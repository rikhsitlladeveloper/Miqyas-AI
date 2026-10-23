import XCTest
@testable import METRX

/// The plumber's fixes of 23 Oct 2026 (Android PlumbFixesTest, same cases and numbers): the riser's sets, heating alone,
/// manifolds, typed rooms' choices and small typed rooms.
final class PlumbFixesTests: XCTestCase {
    private func dims(_ a: Int, _ b: Int, _ h: Int = 2700) -> [String: Dim] {
        ["A": Dim(v: a), "B": Dim(v: b), "H": Dim(v: h), "T": Dim(v: 200, src: "default")]
    }
    private var bath: Room {
        var r = Room(id: "b", floorId: "wb", name: "Hammom")
        r.dims = dims(2600, 2000)
        r.openings = [Opening(id: "bd", type: "door", wall: "A", w: 700, h: 2100, off: 200)]
        return r
    }
    private var living: Room {
        var r = Room(id: "l", floorId: "wl", name: "Mehmonxona")
        r.dims = dims(4000, 3500)
        r.openings = [Opening(id: "ld", type: "door", wall: "A", w: 800, h: 2100, off: 200)]
        return r
    }
    private func project(_ fixes: [PlFix], _ riser: PlRiser?, free: [PlFree] = [], rooms: [PlRoom] = []) -> Project {
        var p = Project(id: "p", name: "T")
        p.floors = [Workspace(id: "wb", name: "Hammom", type: "bath"), Workspace(id: "wl", name: "Mehmonxona", type: "room")]
        p.rooms = [bath, living]
        p.industry = "plumb"
        p.plumb = PlumbOrder(fixes: fixes, rooms: rooms, riser: riser, free: free)
        return p
    }
    private func fix(_ t: String, _ room: String, _ wall: String, _ off: Int, _ w: Int = 0) -> PlFix {
        PlFix(id: "x\(t)\(off)", t: t, roomId: room, wall: wall, off: off, w: w, pts: defaultPts(t, w))
    }
    private let riser = PlRiser(roomId: "b", wall: "C", off: 140)

    func testTheRisersHotSetOnlyWhenTheHotComesUpIt() {
        let wet = [fix("bs", "b", "C", 1490), fix("wc", "b", "C", 970)]
        XCTAssertEqual(plumbCalcOf(project(wet, riser), true).count.meters, 2)
        // hot water from a gas boiler: one set, for the cold
        let gb = plumbCalcOf(project(wet + [fix("gb", "b", "D", 1000)], riser), true).count
        XCTAssertEqual(gb.meters, 1); XCTAssertEqual(gb.filters, 1); XCTAssertEqual(gb.mainValves, 1)
    }

    func testHeatingAloneHasNoRiserAndBuysNoRiserParts() {
        let rads = [fix("rad", "l", "C", 2000, 800), fix("gb", "l", "D", 1500)]
        // a gas boiler needs cold water; radiators alone do not
        XCTAssertFalse(needsRiser(project([fix("rad", "l", "C", 2000, 800)], nil)))
        XCTAssertTrue(needsRiser(project(rads, nil)))
        let onlyRad = plumbCalcOf(project([fix("rad", "l", "C", 2000, 800)], riser), true).count
        XCTAssertEqual(onlyRad.meters, 0); XCTAssertEqual(onlyRad.mainValves, 0)
        XCTAssertFalse(plumbCalcOf(project([fix("rad", "l", "C", 2000, 800)], nil), true).warns.contains { $0.key == "sx.w.noRiser" })
    }

    func testEachManifoldPlacedIsCountedAndFeedsItsOwnRoom() {
        let fs = [fix("manif", "b", "D", 1000), fix("manif", "l", "B", 1500)]
        let ufh = [PlRoom(roomId: "b", kind: "bath", ufh: true), PlRoom(roomId: "l", kind: "room", ufh: true)]
        let c = plumbCalcOf(project(fs, riser, rooms: ufh), true)
        XCTAssertEqual(c.count.manifolds, 2)
        // each room's leads from its own manifold: the living room's are not run from the bathroom
        let one = plumbCalcOf(project([fs[0]], riser, rooms: ufh), true)
        let own = c.routes.loops.first { $0.roomId == "l" }!.total
        let far = one.routes.loops.first { $0.roomId == "l" }!.total
        XCTAssertTrue(own < far)
    }

    func testATypedRoomKeepsItsKitsChoices() {
        let k = pkitOf("bt.bath")!
        var o = k.opts; o.tr = true
        let f = pFreeOf(k, o, "f", "Hammom", 2600, 2000, 2700)
        XCTAssertEqual(f.tr, 1)
        let wc = pkitOf("wc.basin")!
        let h = pFreeOf(wc, wc.opts, "h", "Hojatxona", 1500, 1200, 2700)
        XCTAssertTrue(h.small)
        var p = Project(id: "p", name: "T")
        p.industry = "plumb"
        p.plumb = PlumbOrder(free: [f, h])
        let cs = pCtxs(p, true)
        let cf = cs.first { $0.free?.id == "f" }!, ch = cs.first { $0.free?.id == "h" }!
        XCTAssertTrue(fixesIn(p, cf).contains { $0.t == "tr" })
        XCTAssertTrue(fixesIn(p, ch).contains { $0.t == "bsm" })
        XCTAssertFalse(fixesIn(p, ch).contains { $0.t == "bs" })
    }

    func testASmallTypedRoomStillCountsWhatFitsAndSaysWhatDoesNot() {
        let k = pkitOf("bt.bath")!
        let f = pFreeOf(k, k.opts, "x", "Hammom", 1200, 1000, 2700)
        var p = Project(id: "p", name: "T")
        p.industry = "plumb"
        p.plumb = PlumbOrder(free: [f])
        let cs = pCtxs(p, true)
        XCTAssertEqual(cs.count, 1)
        XCTAssertTrue(fixesIn(p, cs[0]).contains { $0.t == "wc" })
        let calc = plumbCalcOf(p, true)
        XCTAssertTrue(calc.count.fixtures > 0)
        XCTAssertTrue(calc.warns.contains { $0.key == "sx.w.noFit" && $0.vars["t"] == "~sx.t.bath" })
    }

    func testARiserOnADeletedRoomCountsAsNone() {
        let p = project([fix("wc", "b", "C", 970)], riser)
        XCTAssertEqual(liveRiser(p)?.roomId, "b")
        var gone = p
        gone.rooms = [living]
        XCTAssertNil(liveRiser(gone))
    }
}
