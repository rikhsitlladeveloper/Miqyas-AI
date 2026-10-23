import XCTest
@testable import METRX

/// The plumber's fixtures, routes and counts on two rooms: a bathroom 2,6 × 2 × 2,7 m with its door on wall A (700 at
/// 200), and a kitchen 4 × 3 × 2,7 m with its door on wall A (800 at 200), a window on wall C (1200 × 1400 at 900, 1400
/// from C's start) and the sink's cold water and drain marked on wall C. The same cases and numbers as the Android unit
/// test PlumbTest.
final class PlumbTests: XCTestCase {
    private func dims(_ a: Int, _ b: Int, _ h: Int = 2700) -> [String: Dim] {
        ["A": Dim(v: a), "B": Dim(v: b), "H": Dim(v: h), "T": Dim(v: 200, src: "default")]
    }
    private var bath: Room {
        var r = Room(id: "b", floorId: "wb", name: "Hammom")
        r.dims = dims(2600, 2000)
        r.openings = [Opening(id: "bd", type: "door", wall: "A", w: 700, h: 2100, off: 200)]
        return r
    }
    private var kitchen: Room {
        var r = Room(id: "k", floorId: "wk", name: "Oshxona")
        r.dims = dims(4000, 3000)
        r.openings = [Opening(id: "kd", type: "door", wall: "A", w: 800, h: 2100, off: 200), Opening(id: "kw", type: "window", wall: "C", w: 1200, h: 1400, off: 1400, sill: 900)]
        r.points = [SitePoint(id: "cw", t: "cold", wall: "C", off: 2900, h: 550), SitePoint(id: "sw", t: "sewer", wall: "C", off: 2900, h: 500, d: 50)]
        return r
    }
    private func project(_ fixes: [PlFix] = [], _ riser: PlRiser? = nil, rooms: [PlRoom] = [], points: [PlPoint] = [], free: [PlFree] = [], run: String = "wall") -> Project {
        var p = Project(id: "p", name: "Test")
        p.floors = [Workspace(id: "wb", name: "Hammom", type: "bath"), Workspace(id: "wk", name: "Oshxona", type: "kitchen")]
        p.rooms = [bath, kitchen]
        p.industry = "plumb"
        p.plumb = PlumbOrder(fixes: fixes, points: points, rooms: rooms, riser: riser, run: run, free: free)
        return p
    }
    private var n = 0
    private func nextId() -> String { let s = "f\(n)"; n += 1; return s }
    private let riser = PlRiser(roomId: "b", wall: "C", off: 140)
    private func fix(_ t: String, _ room: String, _ wall: String, _ off: Int, _ w: Int = 0) -> PlFix {
        PlFix(id: "x\(t)\(off)", t: t, roomId: room, wall: wall, off: off, w: w, pts: defaultPts(t, w))
    }
    private func withPts(_ f: PlFix, _ k: String, _ h: Int) -> PlFix {
        var g = f
        g.pts = f.pts.map { q in
            var r = q
            if q.t == k { r.h = h }
            return r
        }
        return g
    }

    func testKitPlacesClearOfDoorsAndEachOther() {
        let p = project()
        let c = pCtxOf(p, "b", true)!
        XCTAssertEqual(c.kind, "bath")
        let r = riserIn(c)
        XCTAssertEqual(r.wall, "C"); XCTAssertEqual(r.off, 140)
        let fs = pPlaceKit(pkitOf("bt.bath")!, c, [], r, { self.nextId() })
        XCTAssertEqual(fs.map(\.t), ["bath", "wc", "bs", "wm"])
        // the toilet goes beside the riser (its 110 drain short), the bath along the same wall clear of both
        let b = fs.first { $0.t == "bath" }!
        let w0 = fs.first { $0.t == "wc" }!
        XCTAssertEqual(w0.wall, "C"); XCTAssertEqual(w0.off, 580)
        XCTAssertTrue(wcToRiser(c, w0, r) <= Double(WC_MAX))
        XCTAssertEqual(b.wall, "C"); XCTAssertTrue(b.off - 850 >= w0.off + 190 + 30)
        for f in fs {
            XCTAssertFalse(blocksDoor(c, f), "\(f.t) in the door's way")
            XCTAssertFalse(convexHit(fixPoly(c, f)!, riserPoly(c, r)!), "\(f.t) on the riser")
            // nothing stands or hangs over another (only a heater or towel rail may hang above)
            for g in fs where g.id != f.id {
                let overlapZ = fixZ0(g) < fixTop(f) && fixZ0(f) < fixTop(g)
                let noHanger = ![f, g].contains { fixType($0.t).cat == "heater" || $0.t == "tr" }
                if overlapZ || noHanger { XCTAssertFalse(convexHit(fixPoly(c, f)!, fixPoly(c, g)!), "\(f.t) on \(g.t)") }
            }
        }
        XCTAssertTrue(fixWarnings(c, fs, fs.flatMap { fixPoints($0) }).isEmpty)
        // the door's swing on wall A is never taken: a toilet pushed there moves out of it
        let wc = fs.first { $0.t == "wc" }!
        let x = snapFix(c, wc, "A", 500, fs, r)!
        XCTAssertFalse(blocksDoor(c, moveFix(wc, "A", x)))
        XCTAssertTrue(x - 190 >= 900 || x + 190 <= 200)
        // the bath dragged onto wall A (no 1,7 m clear of the door there) stays where it was
        let at = snapFixPlan(c, b, V2(1500, 100), fs, r)
        XCTAssertEqual(at.0, b.wall); XCTAssertEqual(at.1, b.off)
        XCTAssertNil(snapFix(c, b, "A", 1500, fs, r))
    }

    func testOutletsAtTheirUsualHeights() {
        func pts(_ t: String) -> [String: FixPt] {
            var m: [String: FixPt] = [:]
            for q in defaultPts(t) { m[q.t] = q }
            return m
        }
        XCTAssertEqual(pts("bs")["cold"]!.h, 550); XCTAssertEqual(pts("bs")["hot"]!.h, 550); XCTAssertEqual(pts("bs")["drain"]!.h, 500)
        XCTAssertEqual(pts("wc")["drain"]!.h, 100); XCTAssertEqual(pts("wc")["drain"]!.d, 110); XCTAssertEqual(pts("wc")["cold"]!.h, 200)
        XCTAssertEqual(pts("wm")["cold"]!.h, 600)
        XCTAssertEqual(pts("sink")["cold"]!.h, 550)
        XCTAssertEqual(pts("sh")["cold"]!.h, 1100); XCTAssertEqual(pts("bath")["hot"]!.h, 800)
        // outlets follow their fixture
        let f = fix("bs", "b", "C", 1490)
        XCTAssertEqual(fixPoints(f).map(\.off), [1410, 1570, 1490])
        XCTAssertEqual(fixPoints(moveFix(f, "C", 1690)).map(\.off), [1610, 1770, 1690])
        // loose outlets snap to the usual heights in whole centimetres
        let c = pCtxOf(project(), "b", true)!
        let q = PlPoint(id: "q", t: "cold", roomId: "b", wall: "C", off: 1000, h: 550)
        let a = snapPoint(c, q, 1003, 530)
        XCTAssertEqual(a.0, 1000); XCTAssertEqual(a.1, 550)
        let b = snapPoint(c, q, 1007, 703)
        XCTAssertEqual(b.0, 1010); XCTAssertEqual(b.1, 700)
    }

    func testRoutesAndDrainSlopeOnAKnownRoom() {
        let basin = fix("bs", "b", "C", 1490)
        var cold0 = riser
        cold0.hot = false
        let p = project([basin], cold0)
        let calc = plumbCalcOf(p, true)
        let colds = calc.routes.runs.filter { $0.kind == "cold" }
        XCTAssertEqual(colds.count, 1)
        let cold = colds[0]
        // from the riser (C 140) along wall C to the cold outlet (C 1570) at 250 up, then up to 550
        XCTAssertEqual(cold.trunk, Double(RISER_TAIL) + 1430, accuracy: 1e-6)
        XCTAssertEqual(cold.drops, 300, accuracy: 1e-6)
        XCTAssertEqual(cold.dia, 20)
        // the drain: 1350 back to the riser at 3 cm a metre, down from 500 to where that slope starts
        XCTAssertEqual(calc.routes.drains.count, 1)
        let d = calc.routes.drains[0]
        XCTAssertEqual(d.horiz, 1350, accuracy: 1e-6)
        XCTAssertEqual(d.slope, Double(SLOPE_50), accuracy: 1e-6)
        XCTAssertEqual(d.vertical, 500 - (Double(DRAIN_IN) + 30 * 1.35), accuracy: 1e-6)
        // the drain falls towards the riser
        XCTAssertEqual(d.runs.count, 1)
        let segs = d.runs[0].segs
        XCTAssertTrue(segs[segs.count - 1].zb < segs[1].za)
        XCTAssertEqual(segs[segs.count - 1].zb, Double(DRAIN_IN), accuracy: 1e-6)
        // no hot water: the riser brings none and there is no heater
        XCTAssertTrue(calc.warns.contains { $0.key == "sx.w.noHot" })
        var p2 = p
        p2.plumb.riser = riser
        XCTAssertFalse(plumbCalcOf(p2, true).warns.contains { $0.key == "sx.w.noHot" })
    }

    func testRoutesCrossRoomsThroughTheDoors() {
        let sink = fix("sink", "k", "C", 2900)
        let p = project([sink], riser, rooms: [PlRoom(roomId: "k", kind: "kitchen", link: 1500)])
        let calc = plumbCalcOf(p, true)
        let cold = calc.routes.runs.filter { $0.kind == "cold" }
        XCTAssertEqual(Set(cold.map(\.roomId)), ["b", "k"])
        // the kitchen: in through its doorway in the floor, up beside it, round walls D and C to the sink
        let ks = cold.filter { $0.roomId == "k" }
        XCTAssertEqual(ks.count, 1)
        XCTAssertEqual(ks[0].trunk, 1500.0 + 4620 + Double(WATER_Z - FLOOR_Z), accuracy: 1e-6)
        XCTAssertEqual(ks[0].drops, 300, accuracy: 1e-6)
        // the bathroom: from the riser to its door, dipping into the floor under it
        let bs = cold.filter { $0.roomId == "b" }
        XCTAssertEqual(bs.count, 1)
        XCTAssertEqual(bs[0].dips, 1)
        XCTAssertEqual(bs[0].segs[bs[0].segs.count - 1].zb, Double(FLOOR_Z), accuracy: 1e-6)
        // the sink's drain comes back through the doors to the riser
        XCTAssertEqual(calc.routes.drains.count, 1)
        let d = calc.routes.drains[0]
        XCTAssertEqual(Set(d.runs.map(\.roomId)), ["k", "b"])
        XCTAssertEqual(d.between, 1500, accuracy: 1e-6)
        XCTAssertTrue(d.horiz > 1500 + 3000)
    }

    func testPipeSizesSticksAndCoils() {
        XCTAssertEqual(trunkDia(3), 20); XCTAssertEqual(trunkDia(5), 25); XCTAssertEqual(trunkDia(13), 32)
        let s = pipeNeed("water", 20, 10, "ppr", 10)
        XCTAssertEqual(s.withSpare, 11, accuracy: 1e-9); XCTAssertEqual(s.pieces, 3); XCTAssertEqual(s.unit, "stick")
        let m = pipeNeed("water", 25, 49, "mp", 10)
        XCTAssertEqual(m.pieces, 2); XCTAssertEqual(m.per, 50); XCTAssertEqual(m.unit, "coil")
        XCTAssertEqual(pipeNeed("water", 20, 95, "pex", 5).pieces, 1)
        XCTAssertEqual(pipeNeed("ufh", 16, 250, "ppr", 0).pieces, 2)
        XCTAssertEqual(pipeNeed("water", 20, 0, "ppr", 10).pieces, 0)
        // a coiled pipe under 50 m with the spare is bought by the metre, as the electrician's cable; the underfloor pipe too
        let short = pipeNeed("water", 20, 40, "pex", 10)
        XCTAssertEqual(short.unit, "m"); XCTAssertEqual(short.pieces, 44); XCTAssertEqual(short.per, 1)
        XCTAssertEqual(pipeNeed("ufh", 16, 30, "ppr", 10).unit, "m")
        XCTAssertEqual(pipeNeed("ufh", 16, 46, "ppr", 10).unit, "coil")
        XCTAssertEqual(pipeNeed("heat", 20, 45, "mp", 10).unit, "m")
    }

    func testRadiatorsSizedByTheFloorUnderTheWindow() {
        XCTAssertEqual(radSections(12), 7); XCTAssertEqual(radSections(1), 3); XCTAssertEqual(radWidth(7), 560)
        let c = pCtxOf(project(), "k", true)!
        let rs = placeRadiators(c, [], nil, { self.nextId() })
        XCTAssertEqual(rs.count, 1)
        let r = rs[0]
        XCTAssertEqual(r.wall, "C"); XCTAssertEqual(r.off, 2000); XCTAssertEqual(fixW(r), 560)
        XCTAssertEqual(r.pts.map(\.dx), [-240, 240])
        XCTAssertEqual(radWatts(r), 1260)
        // a bigger radiator keeps its outlets at its ends
        XCTAssertEqual(resizeFix(r, 800).pts.map(\.dx), [-360, 360])
    }

    func testUnderfloorLoopsSplitAtTheLongest() {
        let p = project(rooms: [PlRoom(roomId: "k", kind: "kitchen", ufh: true, step: 150)])
        let c = pCtxOf(p, "k", true)!
        let l = loopOf(c, [], nil, nil)
        XCTAssertEqual(l.area, 12, accuracy: 1e-9)
        XCTAssertEqual(l.total, 80_000 + 2000, accuracy: 1e-6)
        XCTAssertEqual(l.n, 2); XCTAssertEqual(l.each, 41_000, accuracy: 1e-6)
        // the bath stands on part of the floor; at 200 one loop does
        var p2 = p
        p2.plumb.rooms = [PlRoom(roomId: "k", kind: "kitchen", ufh: true, step: 200)]
        let l2 = loopOf(pCtxOf(p2, "k", true)!, [fix("bath", "k", "B", 1000)], nil, nil)
        XCTAssertEqual(l2.area, 12 - 1.7 * 0.75, accuracy: 1e-9)
        XCTAssertEqual(l2.n, 1)
        XCTAssertTrue(pSnake(c, 150).count > 20)
        // heating with no boiler warns
        XCTAssertTrue(plumbCalcOf(p, true).warns.contains { $0.key == "sx.w.noBoiler" })
    }

    func testWarnings() {
        // a shower tray laid flat (its drain at 60, where the riser takes it) has no fall 1,35 m from the riser; a toilet
        // on wall A is 2,4 m from it; a basin's cold at 90 cm
        let tray = withPts(fix("sh", "b", "C", 1490), "drain", 60)
        let wc = fix("wc", "b", "A", 2300)
        let basin = withPts(fix("bs", "b", "D", 1000), "cold", 900)
        let p = project([tray, wc, basin], riser)
        let ws = plumbCalcOf(p, true).warns
        XCTAssertTrue(ws.contains { $0.key == "sx.w.slope" && $0.target == tray.id })
        XCTAssertTrue(ws.contains { $0.key == "sx.w.wcFar" && $0.target == wc.id })
        XCTAssertTrue(ws.contains { $0.key == "sx.w.height" && $0.target == basin.id })
        XCTAssertFalse(ws.contains { $0.key == "sx.w.slope" && $0.target == wc.id })
        // a long 50 drain
        var far0 = riser
        far0.off = 1900
        var far = project([fix("bs", "b", "A", 2100)], far0, rooms: [PlRoom(roomId: "b", kind: "bath")], run: "wall")
        far.plumb.drainMax = 1000
        XCTAssertTrue(plumbCalcOf(far, true).warns.contains { $0.key == "sx.w.long" })
        // a fixture in the door's way
        let c = pCtxOf(p, "b", true)!
        XCTAssertTrue(fixWarnings(c, [fix("wm", "b", "A", 600)], []).contains { $0.key == "sx.w.door" })
        // no riser; a radiator with no boiler
        XCTAssertTrue(plumbCalcOf(project([tray]), true).warns.contains { $0.key == "sx.w.noRiser" })
        XCTAssertTrue(plumbCalcOf(project([fix("rad", "k", "C", 2000, 560)], riser), true).warns.contains { $0.key == "sx.w.noBoiler" })
        XCTAssertFalse(plumbCalcOf(project([fix("rad", "k", "C", 2000, 560), fix("gb", "b", "D", 1000)], riser), true).warns.contains { $0.key == "sx.w.noBoiler" })
    }

    func testRoomWithoutAPlan() {
        var f = PlFree(id: "f", name: "Hammom", kind: "bath", L: 2600, W: 2000, H: 2700)
        f.wc = 1; f.basin = 1; f.bath = 1; f.link = 3000
        var p = Project(id: "p", name: "T")
        p.industry = "plumb"
        p.plumb = PlumbOrder(free: [f])
        let cs = pCtxs(p, true)
        XCTAssertEqual(cs.count, 1)
        let fs = fixesIn(p, cs[0])
        XCTAssertEqual(fs.map(\.t), ["bath", "wc", "bs"])
        let calc = plumbCalcOf(p, true)
        // every drain reaches the door and the 3 m to the riser
        XCTAssertEqual(calc.routes.drains.count, 3)
        XCTAssertTrue(calc.routes.drains.allSatisfy { $0.between == 3000 && $0.horiz > 3000 })
        XCTAssertTrue(calc.count.drain110 > 3 && calc.count.drain50 > 3)
        XCTAssertTrue(calc.routes.runs.filter { $0.kind == "cold" }.allSatisfy { $0.trunk >= 3000 })
        // a kit's counts for a room typed by size
        let kt = pkitOf("bt.shower")!
        let k = pFreeOf(kt, kt.opts, "x", "Hammom", 2500, 2000, 2700)
        XCTAssertEqual(k.shower, 1); XCTAssertEqual(k.wc, 1); XCTAssertEqual(k.basin, 1); XCTAssertEqual(k.wm, 1); XCTAssertEqual(k.bath, 0)
    }

    func testEstimateRows() {
        let p = project([fix("bs", "b", "C", 1490), fix("wc", "b", "C", 970), fix("sink", "k", "C", 2900)], riser)
        let nm: (String, [String: String]) -> String = { k, v in k + v.keys.sorted().map { "|" + $0 + "=" + (v[$0] ?? "") }.joined() }
        let r = plumbRows(p, TradeSet(), true, nm)
        XCTAssertTrue((r.mats + r.labor).allSatisfy { $0.id.hasPrefix("t-") })
        let pipe = r.mats.filter { $0.name.hasPrefix("sx.e.pipeS") }
        XCTAssertFalse(pipe.isEmpty)
        XCTAssertTrue(pipe.allSatisfy { (Int($0.qty) ?? 1) % STICK == 0 && $0.name.contains("s=~sx.sys.ppr") })
        XCTAssertTrue(r.mats.contains { $0.name == "sx.e.d110" })
        XCTAssertTrue(r.mats.contains { $0.name == "sx.e.d50" })
        XCTAssertTrue(r.mats.contains { $0.name == "sx.e.mainv" && $0.qty == "2" })
        XCTAssertTrue(r.mats.contains { $0.name == "sx.e.ball" && $0.qty == "5" })
        XCTAssertTrue(r.labor.contains { $0.name == "sx.e.lPts|n=8" && $0.amount == "\(8 * 120000)" })
        XCTAssertTrue(r.labor.contains { $0.name == "sx.e.lFix|n=3" })
        XCTAssertEqual(r.facts["points"] ?? -1, 8.0, accuracy: 0)
        // metal-plastic comes in coils
        var p2 = p
        p2.plumb.water = "mp"
        let m = plumbRows(p2, TradeSet(), true, nm)
        XCTAssertTrue(m.mats.contains { $0.name.hasPrefix("sx.e.pipeC") || $0.name.hasPrefix("sx.e.pipeM") })
        XCTAssertTrue(m.mats.filter { $0.name.hasPrefix("sx.e.pipeC") }.allSatisfy { (Int($0.qty) ?? 1) % 50 == 0 })
        XCTAssertTrue(m.mats.filter { $0.name.hasPrefix("sx.e.pipeM") }.allSatisfy { (Int($0.qty) ?? 50) < 50 })
        XCTAssertFalse(m.mats.contains { $0.name == "sx.e.coup" })
    }

    func testTakesInTheRoomsWaterOnce() {
        let p = project()
        let c = pCtxOf(p, "k", true)!
        let got = pFromSitePoints(c, { self.nextId() })
        XCTAssertEqual(got.map(\.t), ["cold", "drain"])
        XCTAssertEqual(got.map { $0.from ?? "" }, ["cw", "sw"])
        XCTAssertEqual(got[1].d, 50)
        var p2 = p
        p2.plumb.rooms = [PlRoom(roomId: "k", seen: ["cw", "sw"])]
        let c2 = pCtxOf(p2, "k", true)!
        XCTAssertTrue(pFromSitePoints(c2, { self.nextId() }).isEmpty)
        var p3 = p
        p3.plumb.fixes = [fix("wc", "b", "C", 970)]
        XCTAssertEqual(defaultRiser(p3, true)?.roomId, "b")
        XCTAssertEqual(pGuessKind(nil, "Hojatxona"), "wc"); XCTAssertEqual(pGuessKind("bath", "Hammom"), "bath"); XCTAssertEqual(pGuessKind(nil, "Oshxona"), "kitchen")
    }
}
