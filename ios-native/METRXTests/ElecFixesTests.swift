import XCTest
@testable import METRX

/// The electrician's fixes of 23 Oct 2026 (Android ElecFixesTest, same cases and numbers): gofra rises, typed rooms'
/// power points, the water heater's socket, a panel left on a deleted room.
final class ElecFixesTests: XCTestCase {
    private func dims(_ a: Int, _ b: Int, _ h: Int = 2700) -> [String: Dim] {
        ["A": Dim(v: a), "B": Dim(v: b), "H": Dim(v: h), "T": Dim(v: 200, src: "default")]
    }
    private var hall: Room {
        var r = Room(id: "h", floorId: "wh", name: "Koridor")
        r.dims = dims(3000, 2000)
        r.openings = [Opening(id: "he", type: "door", wall: "A", w: 900, h: 2100, off: 300), Opening(id: "hk", type: "door", wall: "B", w: 800, h: 2100, off: 600)]
        return r
    }
    private var kitchen: Room {
        var r = Room(id: "k", floorId: "wk", name: "Oshxona")
        r.dims = dims(4000, 3000)
        r.openings = [Opening(id: "kd", type: "door", wall: "A", w: 800, h: 2100, off: 200)]
        return r
    }
    private func project(_ devs: [ElecDev], _ method: String, free: [ElecFree] = []) -> Project {
        var p = Project(id: "p", name: "T")
        p.floors = [Workspace(id: "wh", name: "Koridor", type: "room"), Workspace(id: "wk", name: "Oshxona", type: "kitchen")]
        p.rooms = [hall, kitchen]
        p.industry = "elec"
        p.elec = ElecOrder(devs: devs, rooms: [ElecRoom(roomId: "k", kind: "kitchen")], panel: ElecPanel(roomId: "h", wall: "A", off: 1600), method: method, free: free)
        return p
    }
    private var devs: [ElecDev] {
        [ElecDev(id: "l1", t: "lc", roomId: "h", wall: nil, cx: 1500, cy: 1000), ElecDev(id: "s1", t: "s1", roomId: "h", wall: "C", off: 1000, h: 300),
         ElecDev(id: "s2", t: "s1", roomId: "k", wall: "B", off: 1000, h: 300), ElecDev(id: "st", t: "pst", roomId: "k", wall: "B", off: 2000, h: 600)]
    }
    private var n = 0
    private func nextId() -> String { let s = "x\(n)"; n += 1; return s }

    func testInGofraEveryCircuitHasItsOwnRise() {
        let p = project(devs, "gofra")
        let calc = calcOf(p, true)
        let rises = calc.routes.runs.reduce(0.0) { $0 + $1.rise }
        let ceil = calc.routes.runs.reduce(0.0) { $0 + $1.ceil }
        XCTAssertTrue(calc.routes.runs.filter { $0.rise > 0 }.count > 1)
        XCTAssertEqual(calc.count.gofraM, (ceil + rises) / 1000, accuracy: 1e-9)
        XCTAssertTrue(rises > (calc.routes.runs.map(\.rise).max() ?? 0))
    }

    func testATypedKitchenKeepsItsStoveAndOvenLines() {
        let k = kitOf("kt.std")!
        let f = freeOf(k, defaultOpts(k), "x", "Oshxona", 3500, 3000, 2700)
        XCTAssertEqual(f.powers, ["pst", "pov"])
        let p = project([], "chase", free: [f])
        let c = ctxs(p, true).first { $0.free != nil }!
        let ds = devsIn(p, c)
        let st = ds.filter { $0.t == "pst" }, ov = ds.filter { $0.t == "pov" }
        XCTAssertEqual(st.count, 1); XCTAssertEqual(ov.count, 1)
        XCTAssertEqual(st.first?.h, 600); XCTAssertEqual(ov.first?.h, 600)
        XCTAssertFalse(ds.contains { $0.t == "pac" })
        // the stove on its own 32 A line of 6 mm²
        let stove = calcOf(p, true).circuits.filter { $0.group == "stove" }
        XCTAssertEqual(stove.count, 1)
        XCTAssertEqual(stove.first?.amps, 32); XCTAssertEqual(stove.first?.cable, "6")
        // an older typed room (no types kept) still gives its power points as AC lines
        var old = f
        old.powers = []
        let po = project([], "chase", free: [old])
        let co = ctxs(po, true).first { $0.free != nil }!
        XCTAssertEqual(devsIn(po, co).filter { $0.t == "pac" }.count, 2)
    }

    func testABathroomsHeaterSocketIsNotASplashWarningAndTypedBathSocketsAreSplashProof() {
        let k = kitOf("bt.std")!
        let f = freeOf(k, defaultOpts(k), "b", "Hammom", 2500, 2000, 2700)
        XCTAssertEqual(f.powers, ["pwh"])
        let p = project([], "chase", free: [f])
        let c = ctxs(p, true).first { $0.free != nil }!
        let ds = devsIn(p, c)
        XCTAssertTrue(ds.filter { devType($0.t).group == "sock" }.allSatisfy { $0.t == "sw" })
        let ws = devWarnings(c, ds)
        XCTAssertFalse(ws.contains { $0.key == "el.w.splash" })
    }

    func testAPanelOnADeletedRoomCountsAsNone() {
        let p = project(devs, "chase")
        XCTAssertEqual(livePanel(p)?.roomId, "h")
        var gone = p
        gone.rooms = [kitchen]
        XCTAssertNil(livePanel(gone))
        let cs = ctxs(gone, true)
        XCTAssertTrue(warningsOf(gone, cs, circuitsOf(gone, cs)).contains { $0.key == "el.w.noPanel" })
    }

    func testAKitSaysHowManyPointsItWants() {
        let p = project([], "chase")
        let c = ctxOf(p, "k", true)!
        let k = kitOf("kt.spots")!
        let want = kitWanted(k, c)
        let got = placeKit(k, c, [], { self.nextId() })
        XCTAssertTrue(got.count <= want)
        XCTAssertTrue(want >= spotGrid(c).count + 4)
    }
}
