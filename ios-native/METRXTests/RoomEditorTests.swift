import XCTest
@testable import METRX

/// The room editor v2 (room-editor mockup v2, approved 28 Oct 2026): the styles and their size steps, a typed size's
/// problems, the magnets, free places, the Tekshiruv rules, the model's new fields (saved only when set, older data
/// read), the room's walls and its changes (length, mirror), a balcony block's holes, the start dialog and the trades.
final class RoomEditorTests: XCTestCase {

    func testEveryKindHasStylesAndTheirSizeSteps() {
        for k in RE_KINDS { XCTAssertFalse(reStyles(k.id).isEmpty, k.id) }
        XCTAssertEqual(reSteps("door", "single"), ["w", "h"])
        XCTAssertEqual(reSteps("door", "balcony"), ["dw", "h", "ww", "wh"])
        XCTAssertEqual(reSteps("window", "double"), ["w", "h", "sill"])
        XCTAssertEqual(reSteps("window", "pano"), ["w", "h"])
        XCTAssertEqual(reSteps("window", "balcony"), ["ww", "wh", "dw", "h"])
        XCTAssertEqual(reSteps("rad", "alu"), ["pw", "ph"])
        XCTAssertEqual(reSteps("ac", "b9"), ["pw", "ph"])
        XCTAssertEqual(reSteps("socket", "one"), ["ph"])
        // an older opening's "" is a door's single, a window's double
        XCTAssertEqual(reStyle("door", "").id, "single")
        XCTAssertEqual(reStyle("window", "").id, "double")
        // the panoramic window goes up to the ceiling
        XCTAssertEqual(reStd("window", "pano", 2800)["h"], 2800)
        XCTAssertEqual(reStd("door", "double", 2700)["w"], 1200)
        XCTAssertEqual(reStd("socket", "three", 2700)["ph"], 1100)
    }

    func testTheChipsHoldTheStylesStandard() {
        let d = reChips("door", "double", "w", 2700)
        XCTAssertEqual(d.chips, [1000, 1200, 1400])
        XCTAssertEqual(d.std, 1200)
        let w = reChips("window", "single", "w", 2700)
        XCTAssertEqual(w.chips, [600, 700, 800])
        let rad = reChips("rad", "alu", "pw", 2700)
        XCTAssertEqual(rad.chips, [500, 640, 800, 1000, 1200])
        let ph = reChips("socket", "power", "ph", 2700)
        XCTAssertEqual(ph.chips, [300, 600, 1100, 1800])
        XCTAssertEqual(ph.std, 600)
    }

    func testATypedSizesProblems() {
        // wider than the wall
        XCTAssertEqual(reFieldErr("door", "single", ["w": 3000, "h": 2100], "w", wallL: 2600, roomH: 2700)?.code, "wide")
        XCTAssertEqual(reFieldErr("door", "single", ["w": 200, "h": 2100], "w", wallL: 2600, roomH: 2700), ReErr(code: "min", vars: ["m": 300]))
        XCTAssertNil(reFieldErr("door", "single", ["w": 800, "h": 2100], "w", wallL: 2600, roomH: 2700))
        // a radiator may be 200 wide
        XCTAssertNil(reFieldErr("rad", "towel", ["pw": 200, "ph": 1200], "pw", wallL: 2600, roomH: 2700))
        // above the ceiling
        XCTAssertEqual(reFieldErr("door", "single", ["w": 800, "h": 2800], "h", wallL: 2600, roomH: 2700)?.code, "ceil")
        XCTAssertEqual(reFieldErr("window", "double", ["w": 1500, "h": 1500, "sill": 1300], "sill", wallL: 3400, roomH: 2700)?.code, "sillCeil")
        XCTAssertEqual(reFieldErr("socket", "one", ["ph": 2800], "ph", wallL: 3400, roomH: 2700)?.code, "ceil")
        // a balcony block: the door at least 100 above the window's top, the window under the door
        XCTAssertEqual(reFieldErr("window", "balcony", ["ww": 1200, "wh": 1400, "dw": 700, "h": 1450], "h", wallL: 3400, roomH: 2700)?.code, "balDoor")
        XCTAssertEqual(reFieldErr("door", "balcony", ["dw": 700, "h": 2100, "ww": 1200, "wh": 2050], "wh", wallL: 3400, roomH: 2700)?.code, "balWin")
        XCTAssertEqual(reFieldErr("door", "balcony", ["dw": 700, "h": 2100, "ww": 3000, "wh": 1400], "ww", wallL: 3400, roomH: 2700)?.code, "balWide")
        // the first step with a problem
        let all = reCheckAll("window", "double", ["w": 1500, "h": 1500, "sill": 1300], wallL: 3400, roomH: 2700)
        XCTAssertEqual(all?.step, 2)
        XCTAssertNil(reCheckAll("door", "single", reStd("door", "single", 2700), wallL: 3400, roomH: 2700))
    }

    func testAStyleKeepsTheItemsCentre() {
        var it = ReItem(id: "a", kind: "door", style: "single", wall: "A", dist: 1000, w: 800, h: 2100)
        it = reApply(it, "double", ["w": 1200, "h": 2100], wallL: 3400, centre: 1400)
        XCTAssertEqual(it.w, 1200)
        XCTAssertEqual(it.dist, 800)
        let bal = reApply(it, "balcony", ["dw": 700, "h": 2100, "ww": 1200, "wh": 1400], wallL: 3400, centre: 1400)
        XCTAssertEqual(bal.w, 1900)
        XCTAssertEqual(bal.dw, 700)
        XCTAssertEqual(bal.top, 2100)
        XCTAssertEqual(reVals(bal), ["dw": 700, "ww": 1200, "h": 2100, "wh": 1400])
        // a new door is fitted to a short wall and a low room
        let small = reNewItem("door", wall: "B", centre: 300, wallL: 600, roomH: 2000, id: "n")
        XCTAssertEqual(small.w, 600)
        XCTAssertEqual(small.h, 1900)
        XCTAssertEqual(small.dist, 0)
    }

    func testMagnetsAndFreePlaces() {
        // within 12 points (here 1 point = 10 mm, so 120 mm) of a corner or the middle it sticks
        XCTAssertEqual(reMagnet(800, 3400, 90, 0.1).v, 0)
        XCTAssertEqual(reMagnet(800, 3400, 90, 0.1).mag, "corner")
        XCTAssertEqual(reMagnet(800, 3400, 1250, 0.1).mag, "mid")
        XCTAssertEqual(reMagnet(800, 3400, 1250, 0.1).v, 1300)
        XCTAssertEqual(reMagnet(800, 3400, 2003, 0.1).v, 2000)
        XCTAssertNil(reMagnet(800, 3400, 2003, 0.1).mag)
        // a door over another moves to the nearest free place
        let a = ReItem(id: "a", kind: "door", style: "single", wall: "A", dist: 1000, w: 800, h: 2100)
        let b = ReItem(id: "b", kind: "window", style: "double", wall: "A", dist: 1200, w: 800, h: 1500)
        XCTAssertTrue(reOverlap(a, b))
        XCTAssertEqual(reFreeSpot(b, [a], 3400), 1800)
        XCTAssertEqual(reDists(a, 3400).r, 1600)
    }

    func testTheChecks() {
        let sock = { (d: Int) -> ReItem in var x = ReItem(id: "s", kind: "socket", style: "one", wall: "B", dist: d); x.ph = 300; return x }
        var water = ReItem(id: "w", kind: "cold", style: "tap", wall: "B", dist: 1000); water.ph = 500
        var meter = ReItem(id: "m", kind: "meter", style: "g4", wall: "B", dist: 1700); meter.ph = 1600
        let lens = ["A": 3400, "B": 2600, "C": 3400, "D": 2600]
        let near = reIssues([sock(1400), water, meter], lens: lens, roomH: 2700)
        XCTAssertTrue(near.contains { $0.id == "s" && $0.code == "water" && $0.vars["d"] == 400 })
        XCTAssertTrue(near.contains { $0.id == "m" && $0.code == "gas" && $0.vars["d"] == 300 })
        XCTAssertTrue(reIssues([sock(1700), water], lens: lens, roomH: 2700).filter { $0.code == "water" }.isEmpty)
        // a door past its wall and above the ceiling; two openings over each other; a point on a window
        let door = ReItem(id: "d", kind: "door", style: "single", wall: "B", dist: 2000, w: 800, h: 2800)
        let issues = reIssues([door], lens: lens, roomH: 2700)
        XCTAssertEqual(Set(issues.map(\.code)), ["out", "ceil"])
        let win = ReItem(id: "n", kind: "window", style: "double", wall: "A", dist: 900, w: 1500, h: 1500, sill: 900)
        var p = ReItem(id: "p", kind: "socket", style: "one", wall: "A", dist: 1500); p.ph = 1100
        XCTAssertTrue(reIssues([win, p], lens: lens, roomH: 2700).contains { $0.id == "p" && $0.code == "onOp" })
    }

    func testTheNewFieldsAreSavedOnlyWhenSetAndOlderDataReads() throws {
        // an opening saved before the styles
        let old = #"{"id":"o1","type":"door","wall":"A","w":900,"h":2100,"off":600,"sill":0,"offDrag":false,"sillDrag":false}"#
        let o = try JSONDecoder().decode(Opening.self, from: Data(old.utf8))
        XCTAssertEqual(o.style, ""); XCTAssertEqual(o.dw, 0); XCTAssertEqual(o.sw, "")
        let back = String(data: try JSONEncoder().encode(o), encoding: .utf8) ?? ""
        XCTAssertFalse(back.contains("style")); XCTAssertFalse(back.contains("\"dw\""))
        var bal = o
        bal.style = "balcony"; bal.dw = 700; bal.wh = 1400; bal.w = 1900; bal.sw = "inR"; bal.thr = 20
        let again = try JSONDecoder().decode(Opening.self, from: try JSONEncoder().encode(bal))
        XCTAssertEqual(again, bal)
        XCTAssertTrue(again.balcony)
        XCTAssertEqual(again.area, Int64(700 * 2100 + 1200 * 1400))
        XCTAssertEqual(again.holes.count, 2)
        XCTAssertEqual(again.holes[1].off, 1300)
        XCTAssertEqual(again.holes[1].sill, 700)
        // a point
        let p0 = try JSONDecoder().decode(SitePoint.self, from: Data(#"{"id":"p","t":"socket","wall":"B","off":400,"h":300}"#.utf8))
        XCTAssertEqual(p0.style, ""); XCTAssertEqual(p0.pw, 0)
        XCTAssertFalse((String(data: try JSONEncoder().encode(p0), encoding: .utf8) ?? "").contains("pw"))
        var rad = p0; rad.t = "rad"; rad.style = "steel"; rad.pw = 1000
        XCTAssertEqual(try JSONDecoder().decode(SitePoint.self, from: try JSONEncoder().encode(rad)), rad)
        // a room's own wall thicknesses
        var r = Room(id: "r", floorId: "f", name: "x")
        XCTAssertFalse((String(data: try JSONEncoder().encode(r), encoding: .utf8) ?? "").contains("thick"))
        r.thick = ["B": 380]
        let r2 = try JSONDecoder().decode(Room.self, from: try JSONEncoder().encode(r))
        XCTAssertEqual(r2.thickOf("B"), 380); XCTAssertEqual(r2.thickOf("A"), 200)
    }

    func testTheItemsGoInAndOutOfTheRoom() {
        var r = Room(id: "r", floorId: "f", name: "x")
        r.dims["A"] = Dim(v: 3400, src: "manual"); r.dims["B"] = Dim(v: 2600, src: "manual"); r.dims["H"] = Dim(v: 2700, src: "manual")
        var it = reNewItem("window", wall: "A", centre: 1700, wallL: 3400, roomH: 2700, id: "w1")
        it = reApply(it, "pano", reStd("window", "pano", 2700), wallL: 3400, centre: 1700)
        rePut(&r, it)
        XCTAssertEqual(r.openings.count, 1)
        XCTAssertEqual(r.openings[0].style, "pano")
        XCTAssertEqual(r.openings[0].sill, 0)
        XCTAssertEqual(r.openings[0].h, 2700)
        var rad = reNewItem("rad", wall: "C", centre: 1000, wallL: 3400, roomH: 2700, id: "r1")
        rad.pw = 1000; rad.style = "steel"
        rePut(&r, rad)
        XCTAssertEqual(r.points.first?.t, "rad"); XCTAssertEqual(r.points.first?.pw, 1000); XCTAssertEqual(r.points.first?.style, "steel")
        XCTAssertEqual(reItems(r).count, 2)
        reRemove(&r, "w1")
        XCTAssertTrue(r.openings.isEmpty)
        var sewer = reNewItem("sewer", wall: "B", centre: 500, wallL: 2600, roomH: 2700, id: "s1")
        sewer.style = "d110"
        rePut(&r, sewer)
        XCTAssertEqual(r.points.last?.d, 110)
    }

    func testTheRoomsWallsAndItsChanges() {
        var r = Room(id: "r", floorId: "f", name: "x")
        r.dims["A"] = Dim(v: 3400, src: "manual"); r.dims["B"] = Dim(v: 2600, src: "manual"); r.dims["H"] = Dim(v: 2700, src: "manual")
        let g = reGeo(r)
        XCTAssertEqual(g.walls.map(\.id), ["A", "B", "C", "D"])
        XCTAssertEqual(g.lens, ["A": 3400, "B": 2600, "C": 3400, "D": 2600])
        XCTAssertEqual(g.prev("A"), "D"); XCTAssertEqual(g.next("D"), "A")
        XCTAssertEqual(reCornerAngle(g, "B"), 90)
        XCTAssertEqual(g.area, 3400.0 * 2600.0, accuracy: 0.5)
        // a turned rectangle keeps its lengths
        r.rot = 1
        XCTAssertEqual(reGeo(r).len("A"), 3400)
        r.rot = 0
        // a wall's length: up to 999 999, C follows A
        XCTAssertNil(reSetWallLen(&r, "C", 45_000))
        XCTAssertEqual(r.dim("A").v, 45_000)
        XCTAssertEqual(reSetWallLen(&r, "A", 1_000_000), "range")
        XCTAssertEqual(reSetWallLen(&r, "A", 299), "range")
        XCTAssertTrue(reWallBig(45_000)); XCTAssertFalse(reWallBig(30_000))
        // a shorter wall keeps its door on it
        r.openings = [Opening(id: "d", type: "door", wall: "B", w: 900, h: 2100, off: 1600)]
        XCTAssertNil(reSetWallLen(&r, "B", 2000))
        XCTAssertEqual(r.openings[0].off, 1100)
        // mirrored: B and D swap, the door is measured from the other corner
        reMirror(&r)
        XCTAssertEqual(r.openings[0].wall, "D")
        XCTAssertEqual(r.openings[0].off, 0)
        // turning
        reTurn(&r, 1); XCTAssertEqual(r.rot, 1)
        reTurn(&r, -1); XCTAssertEqual(r.rot, 0)
        // the shape: an L at its standard sizes, the height kept
        r.dims["A"] = Dim(v: 3400, src: "manual")
        XCTAssertNotNil(reChangeShape(&r, .L))
        XCTAssertEqual(reShapeOf(r), "L")
        XCTAssertEqual(reGeo(r).walls.count, 6)
        XCTAssertEqual(reHeight(r), 2700)
    }

    func testAnEdgeDraggedSticksToTheUsualSizes() {
        let it = ReItem(id: "d", kind: "door", style: "single", wall: "A", dist: 1000, w: 800, h: 2100)
        // the right edge pulled to 1905 mm along: 905 wide, sticks to 900
        XCTAssertEqual(reEdge(it, "r", t: 1905, hz: 0, L: 3400, rh: 2700, k: 0.5, fl: false).w, 900)
        // the left edge: the right side stays
        let l = reEdge(it, "l", t: 905, hz: 0, L: 3400, rh: 2700, k: 0.5, fl: false)
        XCTAssertEqual(l.dist + l.w, 1800)
        // the top: up to the ceiling at most
        XCTAssertEqual(reEdge(it, "t", t: 0, hz: 3500, L: 3400, rh: 2700, k: 0.5, fl: false).h, 2700)
        // a point's height sticks to its kind's usual ones
        XCTAssertEqual(reSnapH("socket", 1112, 0.5, 2700), 1100)
        XCTAssertEqual(reSnapH("socket", 700, 0.5, 2700), 700)
    }

    func testTheStartDialogsTrades() {
        var p = Project(id: "p", name: "x")
        XCTAssertEqual(sdTrade(p), "build")
        p.industry = "furniture"; XCTAssertEqual(sdTrade(p), "furn")
        p.industry = "tiler"; XCTAssertEqual(sdTrade(p), "tile")
        p.industry = "plumb"; XCTAssertEqual(sdTrade(p), "plumb")
        XCTAssertEqual(reGroups("elec")[1].first, "socket")
        XCTAssertEqual(reGroups("tiler")[1].first, "cold")
    }

    func testTheElectricianTakesInTheStyles() {
        func pt(_ t: String, _ s: String) -> SitePoint { SitePoint(id: "x", t: t, wall: "A", off: 100, h: 300, style: s) }
        XCTAssertEqual(elecTypeOf(pt("socket", "")), "s1")
        XCTAssertEqual(elecTypeOf(pt("socket", "two")), "s2")
        XCTAssertEqual(elecTypeOf(pt("socket", "power")), "pst")
        XCTAssertEqual(elecTypeOf(pt("switch", "k3")), "k2")
        XCTAssertEqual(elecTypeOf(pt("switch", "pass")), "kp")
        XCTAssertEqual(elecTypeOf(pt("ac", "b9")), "pac")
    }

    func testTheWallsLimitIs999999WithABigWallNote() {
        XCTAssertEqual(SHAPE_WALL_MAX, 999_999)
        XCTAssertEqual(Geo.dimMax("A"), 999_999)
        XCTAssertNil(wallValueError(500_000))
        XCTAssertNotNil(wallValueError(1_000_000))
        XCTAssertEqual(Geo.WALL_BIG, 30_000)
    }
}
