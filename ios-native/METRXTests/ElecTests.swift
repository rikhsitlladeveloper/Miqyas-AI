import XCTest
@testable import METRX

/// The electrician's devices, circuits and routes on two rooms: a hallway 3 × 2 × 2,7 m with the entrance door on wall A
/// (900 at 300) and the kitchen's doorway on wall B (800 at 600), and a kitchen 4 × 3 × 2,7 m with its door on wall A
/// (800 at 200), a window on wall C (1200 × 1400 at 900, 1400 from C's start) and a sink's cold water on wall C. The same
/// cases and numbers as the Android unit test ElecTest.
final class ElecTests: XCTestCase {
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
        r.openings = [Opening(id: "kd", type: "door", wall: "A", w: 800, h: 2100, off: 200), Opening(id: "kw", type: "window", wall: "C", w: 1200, h: 1400, off: 1400, sill: 900)]
        r.points = [SitePoint(id: "cw", t: "cold", wall: "C", off: 2900, h: 550)]
        return r
    }
    private func project(_ devs: [ElecDev] = [], _ panel: ElecPanel? = nil, method: String = "chase", free: [ElecFree] = [], rooms: [ElecRoom] = []) -> Project {
        var p = Project(id: "p", name: "Test")
        p.floors = [Workspace(id: "wh", name: "Koridor", type: "room"), Workspace(id: "wk", name: "Oshxona", type: "kitchen")]
        p.rooms = [hall, kitchen]
        p.industry = "elec"
        p.elec = ElecOrder(devs: devs, rooms: rooms, panel: panel, method: method, free: free)
        return p
    }
    private var n = 0
    private func nextId() -> String { let s = "d\(n)"; n += 1; return s }
    private func dev(_ id: String, _ t: String, _ room: String, _ wall: String?, _ off: Int = 0, _ h: Int = 0, cx: Int = 0, cy: Int = 0, w: Int = 0) -> ElecDev {
        ElecDev(id: id, t: t, roomId: room, wall: wall, off: off, h: h, cx: cx, cy: cy, w: w)
    }

    func testKitPlacesClearOfDoorsWindowsAndWater() {
        let p = project(rooms: [ElecRoom(roomId: "k", kind: "kitchen")])
        let c = ctxOf(p, "k", true)!
        XCTAssertEqual(c.kind, "kitchen")
        let ds = placeKit(kitOf("kt.std")!, c, [], { self.nextId() })
        XCTAssertTrue(ds.count >= 9)
        // no wall device on an opening (with its frame)
        for d in ds where !d.onCeiling {
            let (dw, dh) = devSize(d)
            let hw = Double(dw) / 2, hh = Double(dh) / 2
            let bad = c.room.openings.contains { o in
                o.wall == d.wall && Double(d.off) + hw > Double(o.off - 100) && Double(d.off) - hw < Double(o.off + o.w + 100)
                    && Double(d.h) + hh > Double(o.sill) && Double(d.h) - hh < Double(o.sill + o.h)
            }
            XCTAssertFalse(bad, "\(d.t) at \(d.wall ?? "") \(d.off)/\(d.h)")
        }
        // the switch beside the door on its latch side, at 900
        let sw = ds.first { $0.t == "k2" }!
        XCTAssertEqual(sw.wall, "A"); XCTAssertEqual(sw.h, 900); XCTAssertTrue(sw.off > 200 + 800)
        // worktop sockets over the worktop on the sink's wall, none within 60 cm of the water
        let work = ds.filter { $0.t == "s2" }
        XCTAssertEqual(work.count, 3)
        XCTAssertTrue(work.allSatisfy { $0.h == 1100 && $0.wall == "C" })
        XCTAssertTrue(devWarnings(c, ds).allSatisfy { $0.key != "el.w.water" && $0.key != "el.w.open" && $0.key != "el.w.door" })
        // the ceiling light in the middle
        let lc = ds.first { $0.t == "lc" }!
        XCTAssertEqual(lc.cx, 2000); XCTAssertEqual(lc.cy, 1500)
    }

    func testSnapsToUsualHeightsAndOffOpenings() {
        let p = project()
        let c = ctxOf(p, "k", true)!
        let s = dev("s", "s1", "k", "B", 1500, 300)
        XCTAssertEqual(snapWall(c, s, 1500, 330, []).1, 300)
        XCTAssertEqual(snapWall(c, s, 1500, 700, []).1, 700)
        let k = dev("w", "k1", "k", "B", 1500, 900)
        XCTAssertEqual(snapWall(c, k, 1500, 870, []).1, 900)
        XCTAssertEqual(snapWall(c, dev("x", "s2", "k", "B", 1500, 1100), 1500, 1080, []).1, 1100)
        // dragged onto the door: put beside it
        var onA = k; onA.wall = "A"
        let off = snapWall(c, onA, 600, 900, []).0
        XCTAssertTrue(off < 200 - 43 || off > 1000 + 43)
        // lined up with another device on the wall
        XCTAssertEqual(snapWall(c, s, 2050, 300, [dev("o", "s1", "k", "B", 2010, 300)]).0, 2010)
    }

    func testRouteLengthOnAKnownRoom() {
        // the panel in the kitchen on wall B at 1500 (top at 1600 + 210), one socket on wall B at 2500, 300 up
        let d = dev("s", "s1", "k", "B", 2500, 300)
        let p = project([d], ElecPanel(roomId: "k", wall: "B", off: 1500, h: 1600))
        let cs = ctxs(p, true)
        let rt = routesOf(p, cs)
        XCTAssertEqual(rt.circuits.count, 1)
        let cc = rt.circuits[0]
        XCTAssertEqual(cc.group, "kitch")
        let zone = 2700.0 - Double(ZONE_DOWN)
        let rise = zone - (1600 + 210)
        let run = 1000.0
        let drop = zone - (300 + 43)
        XCTAssertEqual(rt.cableOf(cc), rise + run + drop + Double(TAIL) + Double(TAIL), accuracy: 1e-6)
        // in pipe over the ceiling: up to the ceiling, across, down
        let g = routesOf(project([d], ElecPanel(roomId: "k", wall: "B", off: 1500, h: 1600), method: "gofra"), cs)
        XCTAssertEqual(g.circuits.count, 1)
        XCTAssertEqual(g.cableOf(g.circuits[0]), (2700.0 - 1810) + 1000 + (2700 - 343) + 2 * Double(TAIL), accuracy: 1e-6)
    }

    func testRoutesCrossRoomsThroughTheDoors() {
        // the panel in the hallway on wall A at 1600; the kitchen's socket on its wall B at 1000
        let d = dev("s", "s1", "k", "B", 1000, 300)
        let p = project([d], ElecPanel(roomId: "h", wall: "A", off: 1600, h: 1600, entry: "he"), rooms: [ElecRoom(roomId: "k", kind: "kitchen", link: 1500)])
        let cs = ctxs(p, true)
        let rt = routesOf(p, cs)
        XCTAssertEqual(rt.circuits.count, 1)
        let cc = rt.circuits[0]
        XCTAssertEqual(cc.group, "kitch")
        XCTAssertEqual(rt.runs.map(\.roomId), ["k", "h"])
        let zone = 2700.0 - Double(ZONE_DOWN)
        // hallway: up from the panel, round to the kitchen doorway on wall B (centre 1000): 1400 on A, then 1000 on B
        let hallPart = (zone - 1810) + (3000 - 1600) + 1000
        // kitchen: from its door's centre on A (600) round the corner to B at 1000: 3400 + 1000, then down to the socket
        let kitPart = (4000 - 600.0) + 1000 + (zone - 343) + Double(TAIL) + 1500
        XCTAssertEqual(rt.runs.first { $0.roomId == "h" }!.len, hallPart, accuracy: 1e-6)
        XCTAssertEqual(rt.runs.first { $0.roomId == "k" }!.len, kitPart, accuracy: 1e-6)
        XCTAssertEqual(rt.cableOf(cc), hallPart + kitPart + Double(TAIL), accuracy: 1e-6)
        // the hallway's exit door is the kitchen's doorway, not the entrance
        XCTAssertEqual(exitDoor(cs.first { $0.id == "h" }!, p.elec.panel!, ElecRoom(roomId: "k"))?.id, "hk")
    }

    func testCircuitsAndBreakers() {
        let ds = [
            dev("l1", "lc", "h", nil, cx: 1500, cy: 1000), dev("k1", "k1", "h", "A", 1500, 900),
            dev("l2", "lc", "k", nil, cx: 2000, cy: 1500), dev("s1", "s1", "h", "D", 1000, 300),
            dev("s2", "s2", "k", "C", 600, 1100), dev("s3", "s2", "k", "C", 1000, 1100),
            dev("st", "pst", "k", "B", 1500, 600), dev("ac", "pac", "h", "D", 500, 2400), dev("tv", "tv", "h", "C", 1000, 1100)
        ]
        let p = project(ds, ElecPanel(roomId: "h", wall: "A", off: 1600), rooms: [ElecRoom(roomId: "h", kind: "hall"), ElecRoom(roomId: "k", kind: "kitchen")])
        let calc = calcOf(p, true)
        XCTAssertEqual(calc.circuits.map(\.group), ["light", "sock", "kitch", "stove", "ac", "low"])
        XCTAssertEqual(calc.circuits.map(\.no), [1, 2, 3, 4, 5, 6])
        let c = calc.count
        XCTAssertEqual(c.breakers, [10: 1, 16: 3, 32: 1])
        XCTAssertEqual(c.rcds, 1)                          // the kitchen's sockets
        XCTAssertEqual(c.modules, 5 + 2 + 2)               // breakers, the RCD, the main switch
        XCTAssertEqual(c.panelModules, 12)
        XCTAssertEqual(c.cables.map(\.type), ["1.5", "2.5", "6", "utp"])
        XCTAssertTrue(c.cables.allSatisfy { $0.coils == coilsFor($0.withSpare) && $0.withSpare > $0.m })
    }

    func testCoilsAndPanelSizes() {
        XCTAssertEqual(coilsFor(0.0), 0); XCTAssertEqual(coilsFor(99.9), 1); XCTAssertEqual(coilsFor(100.0), 1); XCTAssertEqual(coilsFor(100.5), 2)
        XCTAssertEqual(ePanelFor(10), 12); XCTAssertEqual(ePanelFor(11), 18); XCTAssertEqual(ePanelFor(20), 24); XCTAssertEqual(ePanelFor(0), 0)
        let none = eCover(10.0, 0.0, [])
        XCTAssertEqual(none.0, 0.0); XCTAssertEqual(none.1, 0.0)
        // both ways round is shorter than all the way one way
        let both = eCover(10.0, 0.0, [1.0, 8.0])
        XCTAssertEqual(both.0, 1.0); XCTAssertEqual(both.1, 2.0)
        XCTAssertEqual(unionLen([(0.0, 2.0), (1.0, 3.0)], 10.0), 3.0, accuracy: 1e-9)
        XCTAssertEqual(unionLen([(-1.0, 2.0)], 10.0), 3.0, accuracy: 1e-9)
    }

    func testWarnings() {
        let p = project(rooms: [ElecRoom(roomId: "k", kind: "kitchen")])
        let c = ctxOf(p, "k", true)!
        // a socket 40 cm from the sink's water, a switch behind the door's swing (hinge at 200), one on the window
        let near = dev("n", "s1", "k", "C", 2900, 950)
        let behind = dev("b", "k1", "k", "A", 100, 900)
        let onWin = dev("o", "s1", "k", "C", 1600, 1000)
        let ws = devWarnings(c, [near, behind, onWin])
        XCTAssertTrue(ws.contains { $0.key == "el.w.water" && $0.devId == "n" })
        XCTAssertTrue(ws.contains { $0.key == "el.w.door" && $0.devId == "b" })
        XCTAssertTrue(ws.contains { $0.key == "el.w.open" && $0.devId == "o" })
        // the latch side is fine
        XCTAssertTrue(devWarnings(c, [dev("ok", "k1", "k", "A", 1200, 900)]).isEmpty)
        // a bathroom: an ordinary socket is in the splash zone, a waterproof one 1 m from the water is not
        let pb = project(rooms: [ElecRoom(roomId: "k", kind: "bath")])
        let cb = ctxOf(pb, "k", true)!
        XCTAssertTrue(devWarnings(cb, [dev("a", "s1", "k", "B", 1500, 1100)]).contains { $0.key == "el.w.splash" })
        XCTAssertTrue(devWarnings(cb, [dev("a", "sw", "k", "B", 1500, 1100)]).isEmpty)
        XCTAssertTrue(devWarnings(cb, [dev("a", "sw", "k", "C", 2600, 700)]).contains { $0.key == "el.w.splash" })
        // too much for its breaker: a 4 kW socket on a 16 A line; and too many sockets on one circuit
        let heavy = project([dev("h", "s1", "h", "D", 1000, 300, w: 4000)], ElecPanel(roomId: "h", wall: "A", off: 1600))
        XCTAssertTrue(calcOf(heavy, true).warns.contains { $0.key == "el.w.load" })
        let many = project((0..<11).map { dev("m\($0)", "s1", "k", "B", 300 + $0 * 220, 300) }, ElecPanel(roomId: "h", wall: "A", off: 1600), rooms: [ElecRoom(roomId: "k", kind: "bed")])
        XCTAssertTrue(calcOf(many, true).warns.contains { $0.key == "el.w.points" })
        // no panel
        XCTAssertTrue(calcOf(project([dev("s", "s1", "k", "B", 1000, 300)]), true).warns.contains { $0.key == "el.w.noPanel" })
    }

    func testRoomWithoutAPlan() {
        let f = ElecFree(id: "f", name: "Yotoqxona", kind: "bed", L: 4000, W: 3000, H: 2700, sock: 5, sw: 1, light: 1, low: 1, power: 1, link: 4000)
        var p = Project(id: "p", name: "T")
        p.industry = "elec"
        p.elec = ElecOrder(free: [f])
        let cs = ctxs(p, true)
        XCTAssertEqual(cs.count, 1)
        let ds = devsIn(p, cs[0])
        XCTAssertEqual(ds.filter { $0.t == "s1" }.count, 5); XCTAssertEqual(ds.filter { $0.t == "k1" }.count, 1); XCTAssertEqual(ds.filter { $0.t == "lc" }.count, 1)
        XCTAssertEqual(ds.filter { $0.t == "lan" }.count, 1); XCTAssertEqual(ds.filter { $0.t == "pac" }.count, 1)
        let calc = calcOf(p, true)
        XCTAssertEqual(calc.circuits.map(\.group), ["light", "sock", "ac", "low"])
        // each circuit's cable reaches the door and the 4 m to the panel
        XCTAssertTrue(calc.circuits.allSatisfy { calc.routes.cableOf($0) > 4000 })
        XCTAssertTrue(calc.count.cableM > 16)
        // a kit's counts for a room typed by size
        let kt = kitOf("kt.std")!
        let k = freeOf(kt, defaultOpts(kt), "x", "Oshxona", 3500, 3000, 2700)
        XCTAssertEqual(k.sock, 6); XCTAssertEqual(k.sw, 1); XCTAssertEqual(k.power, 2); XCTAssertEqual(k.kind, "kitchen")
    }

    func testEstimateRows() {
        let ds = [dev("l1", "lc", "h", nil, cx: 1500, cy: 1000), dev("k1", "k1", "h", "A", 1500, 900), dev("s1", "s1", "k", "B", 1000, 300),
                  dev("st", "pst", "k", "B", 2000, 600)]
        let p = project(ds, ElecPanel(roomId: "h", wall: "A", off: 1600), rooms: [ElecRoom(roomId: "k", kind: "kitchen")])
        let r = elecRows(p, TradeSet(), true) { k, v in k + v.keys.sorted().map { "|" + $0 + "=" + (v[$0] ?? "") }.joined() }
        XCTAssertTrue((r.mats + r.labor).allSatisfy { $0.id.hasPrefix("t-") })
        let cab = r.mats.filter { $0.name.hasPrefix("el.e.cab") }
        XCTAssertEqual(cab.count, 3)
        XCTAssertTrue(cab.allSatisfy { (Int($0.qty) ?? 1) % 100 == 0 })
        XCTAssertTrue(r.mats.contains { $0.name == "el.e.brk|a=32" && $0.qty == "1" })
        XCTAssertTrue(r.mats.contains { $0.name == "el.e.rcd" && $0.qty == "1" })
        XCTAssertTrue(r.mats.contains { $0.name.hasPrefix("el.e.panel") && $0.price == "\(12000 * 12)" })
        XCTAssertTrue(r.labor.contains { $0.name == "el.e.lPts|n=4" && $0.amount == "\(4 * 60000)" })
        XCTAssertTrue(r.labor.contains { $0.name.hasPrefix("el.e.lChase") })
        XCTAssertEqual(r.facts["points"] ?? -1, 4.0, accuracy: 0)
    }

    func testTakesInTheRoomsSocketsAndSwitches() {
        var r = kitchen
        r.points += [SitePoint(id: "x", t: "socket", wall: "B", off: 1200, h: 300), SitePoint(id: "y", t: "switch", wall: "A", off: 1200, h: 900)]
        var p = project()
        p.rooms = [hall, r]
        let c = ctxOf(p, "k", true)!
        let got = fromSitePoints(c, { self.nextId() })
        XCTAssertEqual(got.map(\.t), ["s1", "k1"])
        XCTAssertEqual(got.map { $0.from ?? "" }, ["x", "y"])
        var half = hall
        half.dims = ["A": Dim(v: 3000)]
        var p2 = p
        p2.rooms = [half]
        XCTAssertNil(ctxOf(p2, "h", true))
        var p3 = p
        p3.elec = ElecOrder(rooms: [ElecRoom(roomId: "h", kind: "hall")])
        let pn = defaultPanel(p3, true)
        XCTAssertNotNil(pn)
        XCTAssertEqual(pn?.roomId, "h"); XCTAssertEqual(pn?.wall, "A")
    }
}
