import XCTest
@testable import METRX

/// Furniture without a room, sliding doors, kitchen extras, the Stage 2 types, columns and niches, the trades and the
/// install date: the same cases as the Android unit tests (FreeTest, SlideTest, KitchenExtrasTest, CabinetsTest,
/// FeaturesTest, TradesTest, OrdersTest).
final class FreeTests: XCTestCase {
    private let ws = Workshop()

    func testAUKitchenStandsOnItsOwnSizes() {
        let f = newFreeKitchen("Oshxona 1", "U", "U", [2200, 3000, 2400], 0, 2700, ws)
        XCTAssertNil(f.roomId); XCTAssertEqual(f.walls, ["D", "A", "B"])
        let r = freeRoom(f)
        XCTAssertTrue(isFreeRoom(r))
        XCTAssertEqual(r.dim("A").v, 3000); XCTAssertEqual(r.dim("B").v, 2400); XCTAssertEqual(r.dim("H").v, 2700)
        let runs = runsOf(f) { freeLen(f, $0) }
        XCTAssertEqual(runs.map(\.len), [2200, 3000, 2400])
        for run in runs { XCTAssertEqual(fillOf(f, run, false).used, run.len! - run.lowStart) }
        XCTAssertFalse(checks(f, runs, ws, [], []).contains { $0.level == "err" })
        XCTAssertEqual(freeRunMm("U", [2200, 3000, 2400], 0), 6400)
    }

    func testAnIslandKitchenGetsItsIslandUnits() {
        let f = newFreeKitchen("Oshxona 1", "O", "O", [3000], 1800, 2700, ws)
        XCTAssertEqual(f.walls, ["A", ISLAND])
        XCTAssertEqual(f.modules.filter { $0.wall == ISLAND }.map(\.w), [600, 600, 600])
        XCTAssertEqual(f.modules.filter { $0.wall == ISLAND }.map(\.x), [0, 600, 1200])
        XCTAssertEqual(freeRunMm("O", [3000], 1800), 4800)
    }

    func testAnOpenShelfHasNoDoors() {
        let f = newFreeWardrobe("Shkaf 1", "op", 1200, 2000, 400, false, "open", ws)
        let m = wardOfF(f)!
        XCTAssertEqual(m.sections.count, 2)
        XCTAssertTrue(m.sections.allSatisfy { $0.fronts.kind == "open" && $0.inserts.filter { $0.kind == "shelf" }.count == 4 })
        XCTAssertEqual(freeRoom(f).dim("A").v, 1200 + 2 * W_GAP_SIDE)
    }

    func testPlacingAnLKitchenOnTooShortAWallSaysSoAndFits() {
        let f = newFreeKitchen("Oshxona 1", "L", "L", [3000, 2000], 0, 2700, ws)
        let lens = ["A": 3400, "B": 1800, "C": 3400, "D": 1800]
        let ids = ["A", "B", "C", "D"]
        let walls = placeWalls(f, ids, "A")
        XCTAssertEqual(walls, ["A", "B"])
        let iss = fitIssues(f, walls, { lens[$0] }, 2500, ws)
        XCTAssertEqual(iss.map(\.key), ["fz.long"]); XCTAssertEqual(iss[0].vars["d"], "200")
        XCTAssertEqual(placeWalls(f, ids, "D"), ["D", "A"])
        let p = fitTo(placed(f, walls, "r1", "w1"), walls, { lens[$0] }, 2500, ws)
        XCTAssertEqual(p.roomId, "r1"); XCTAssertEqual(p.ws, "w1")
        let runs = runsOf(p) { lens[$0] }
        XCTAssertFalse(checks(p, runs, ws, [], []).contains { $0.level == "err" })
        XCTAssertEqual(fillOf(p, runs[1], false).used, 1200)
    }

    func testACornerKitchenOnALongerFirstWallEndsInTheCorner() {
        let f = newFreeKitchen("Oshxona 1", "L", "L", [3000, 2000], 0, 2700, ws)
        let lens = ["A": 3400, "B": 2600, "C": 3400, "D": 2600]
        let p = placed(f, ["A", "B"], "r1", "w1", len: { lens[$0] })
        let lowA = p.modules.filter { $0.wall == "A" && !isUpper($0) }
        XCTAssertEqual(lowA.first?.app, "space"); XCTAssertEqual(lowA.first?.w, 400); XCTAssertEqual(lowA[1].x, 400)
        XCTAssertEqual(fillOf(p, runsOf(p) { lens[$0] }[0], false), Fill(used: 3400, avail: 3400))
        XCTAssertEqual(runMm(p), 5000 - 600)
        let out = takenOut(p, { lens[$0] }, 2500)
        XCTAssertEqual(out.free?.sides, [3000, 2000])
        XCTAssertFalse(out.modules.contains { $0.app == "space" })
    }

    func testAWardrobeTooTallIsLoweredUnderTheCeiling() {
        let f = newFreeWardrobe("Shkaf 1", "h3", 1500, 2600, 600, false, "door", ws)
        XCTAssertEqual(fitIssues(f, ["B"], { _ in 2000 }, 2500, ws).map(\.key), ["fz.high"])
        let p = fitTo(placed(f, ["B"], "r1", "w1", off: 300), ["B"], { _ in 2000 }, 2500, ws, off: 300)
        let m = wardOfF(p)!
        XCTAssertEqual(m.wall, "B"); XCTAssertEqual(m.x, 300)
        XCTAssertTrue(outerH(m, ws) <= 2500 - W_GAP_TOP)
    }

    func testTakenOutKeepsWhatIsOnTheWalls() {
        let f = newFreeKitchen("Oshxona 1", "L", "L", [3000, 2000], 0, 2700, ws)
        let lens = ["A": 3400, "B": 2600, "C": 3400, "D": 2600]
        let inRoom = placed(f, ["C", "D"], "r1", "w1")
        let out = takenOut(inRoom, { lens[$0] }, 2500)
        XCTAssertNil(out.roomId); XCTAssertEqual(out.walls, ["A", "B"])
        XCTAssertEqual(out.free?.sides, [3000, 2000]); XCTAssertEqual(out.free?.h, 2500)
        XCTAssertEqual(out.modules.count, f.modules.count)
    }
}

final class SlideTests: XCTestCase {
    private let ws = Workshop()
    private var m: Module { var m = wardrobeTemplate(ws, "A", W_GAP_SIDE, 2400, 2500, builtIn: true, d: 600); m.slide = Slide(3, ["ldsp", "mirror", "ldsp"]); return m }

    func testDoorsShareTheOpeningWithTheirOverlaps() {
        XCTAssertEqual(slideOpening(m, 16).0, 2400); XCTAssertEqual(slideOpening(m, 16).1, 2500 - PLINTH - 32)
        let (w, h) = slideDoor(m, 16)
        XCTAssertEqual(w, (2400 + 2 * SLIDE_OV) / 3); XCTAssertEqual(h, 2500 - PLINTH - 32 - SLIDE_CLEAR)
        XCTAssertEqual(slidePanel(m, 16).0, w - 2 * SLIDE_FRAME_W)
        XCTAssertEqual(slideDoorsFor(2400), 3); XCTAssertEqual(slideDoorsFor(1600), 2); XCTAssertEqual(slideDoorsFor(3000), 4)
    }

    func testPartsAndHardware() {
        let ps = partsOf(m, ws)
        XCTAssertFalse(ps.contains { $0.key == "fp.door" })
        XCTAssertEqual(ps.first { $0.key == "fp.slidePanel" }?.qty, 2)
        XCTAssertTrue(ps.filter { $0.key == "fp.shelf" }.allSatisfy { $0.W == 600 - SLIDE_D - 20 })
        let hw = hardwareOf(m, ws)
        let (dw, dh) = slideDoor(m, 16), (pw, ph) = slidePanel(m, 16)
        XCTAssertEqual(hw["slideTrack"], 4800); XCTAssertEqual(hw["slideV"], 2 * dh * 3); XCTAssertEqual(hw["slideH"], 2 * dw * 3)
        XCTAssertEqual(hw["slideRoller"], 3); XCTAssertEqual(hw["mirror"], pw * ph)
        XCTAssertNil(hw["hinge"]); XCTAssertNil(hw["handle"])
        let cost = costOf([Furniture(id: "w", kind: "wardrobe", modules: [m])], ws, MAT_PRESETS, HW_PRESETS, order: false)
        XCTAssertEqual(cost.lines.first { $0.key == "mirror" }?.unit, "m2")
        XCTAssertEqual(cost.lines.first { $0.key == "slideTrack" }?.qty, 5)
    }

    func testTheKupeModelStartsWithSlidingDoors() {
        let f = newFreeWardrobe("Shkaf 1", "s3", 2400, 2500, 600, true, "slide", ws, n: 3)
        XCTAssertEqual(wardOfF(f)?.slide?.n, 3)
        XCTAssertFalse(wardrobeChecks(wardOfF(f)!, 2420, 2600, ws, [], []).contains { $0.level == "err" })
    }
}

final class KitchenExtrasTests: XCTestCase {
    private let ws = Workshop()
    private var base: Furniture {
        let f0 = Furniture(id: "k", kind: "kitchen", walls: ["A", "B"], layout: "L")
        var f = autoFill(f0, runsOf(f0) { ["A": 3400, "B": 2600][$0] }, ws, [], [])
        let low = f.modules.filter { $0.wall == "A" && !isUpper($0) }
        f.modules = f.modules.map { m in var x = m; if m.id == low[1].id { x.app = "sink" }; if m.id == low[2].id { x.app = "hob" }; return x }
        return f
    }

    func testNoExtrasOnAnOlderKitchen() { XCTAssertTrue(extrasHardware(base).pairs.isEmpty); XCTAssertTrue(extrasParts(base, ws).isEmpty) }

    func testCornerCutOutsEndsPlinthCorniceLed() {
        var f = base; f.kx = KExtras(joint: "mitre", splash: 600, plinth: true, cornice: true, led: true, ends: 1, endsUp: 1)
        XCTAssertEqual(worktopJoints(f), 1)
        let hw = extrasHardware(f)
        XCTAssertEqual(hw["wtMitre"], 1); XCTAssertNil(hw["wtJoint"]); XCTAssertEqual(hw["wtCut"], 2); XCTAssertEqual(hw["wtEnd"], 2)
        XCTAssertEqual(hw["plinthK"], 5400); XCTAssertEqual(hw["plinthCorner"], 1)
        let wu = f.modules.filter { $0.type == "wall" }.reduce(0) { $0 + $1.w }
        XCTAssertEqual(hw["cornice"], wu); XCTAssertEqual(hw["ledPsu"], (wu + 4999) / 5000)
        XCTAssertEqual(splashMm(f), 5400)
        XCTAssertEqual(extrasParts(f, ws).map(\.key), ["fp.endLow", "fp.endUp"])
        let cost = costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false)
        XCTAssertEqual(cost.lines.first { $0.key == "splash6" }?.qty ?? 0, 5.4, accuracy: 1e-9)
        XCTAssertEqual(cost.lines.first { $0.key == "plinthK" }?.qty, 6)
    }
}

final class CabinetsTests: XCTestCase {
    private let ws = Workshop()

    func testEveryTypeFillsItsWidthAndPassesTheChecks() {
        for t in CASE_TYPES {
            let s = typeSize(t)
            let m = cabinetTemplate(t, ws, "A", 10, s.w, s.h, s.d)
            XCTAssertEqual(m.sections.reduce(0) { $0 + $1.w }, s.w, t)
            XCTAssertFalse(wardrobeChecks(m, s.w + 20, 2700, ws, [], []).contains { $0.level == "err" }, t)
        }
    }

    func testADresserAndADesk() {
        let dr = cabinetTemplate("dresser", ws, "A", 10, 1000, 850, 450)
        let faces = partsOf(dr, ws).filter { $0.key == "fp.dFace" }
        XCTAssertEqual(faces.reduce(0) { $0 + $1.qty }, 4); XCTAssertTrue(faces.allSatisfy { $0.role == "front" })
        XCTAssertEqual(hardwareOf(dr, ws)["handle"], 4)
        let desk = cabinetTemplate("desk", ws, "A", 10, 1200, 750, 600)
        XCTAssertTrue(hasKnee(desk))
        let ps = partsOf(desk, ws)
        XCTAssertEqual(ps.filter { $0.key == "fp.bottom" }.reduce(0) { $0 + $1.qty }, 1)
        XCTAssertEqual(ps.first { $0.key == "fp.divider" }?.L, 750 - ws.legH - 16)
        XCTAssertEqual(modelsOf("other").count, CASE_TYPES.count + PIECE_TYPES.count + ITEM_TYPES.count)
        XCTAssertEqual(kindKey(newFreeCabinet("TV 1", "tv", 1800, 500, 450, ws)), "other")
    }
}

final class FeaturesAndTradesTests: XCTestCase {
    private var room: Room {
        var r = Room(id: "r", floorId: "w", name: "Xona")
        r.dims = ["A": Dim(v: 5000), "B": Dim(v: 4000), "H": Dim(v: 3000), "T": Dim(v: 200, src: "default")]
        r.openings = [Opening(id: "d", type: "door", wall: "A", w: 900, h: 2100, off: 500), Opening(id: "o", type: "window", wall: "C", w: 1200, h: 1500, off: 1900, sill: 900)]
        r.points = [SitePoint(id: "s1", t: "socket", wall: "A", off: 2000, h: 300), SitePoint(id: "s2", t: "socket", wall: "B", off: 1000, h: 300),
                    SitePoint(id: "w1", t: "switch", wall: "A", off: 1600, h: 900), SitePoint(id: "c", t: "cold", wall: "B", off: 500, h: 600),
                    SitePoint(id: "h", t: "hot", wall: "B", off: 700, h: 600), SitePoint(id: "k", t: "sewer", wall: "B", off: 600, h: 400)]
        return r
    }
    private let words: (String, [String: String]) -> String = { k, _ in k }

    func testAColumnAndANiche() {
        var r = room; r.openings = []; r.features = [Feature(id: "c", type: "column", wall: "A", off: 1000, w: 400, d: 300)]
        var a = Geo.areas(r)!
        XCTAssertEqual(a.floor, Int64(20_000_000 - 400 * 300)); XCTAssertEqual(a.perim, 18_600)
        let colGross: Int64 = 18_000 * 3000 + 2 * 300 * 3000
        XCTAssertEqual(a.gross, colGross)
        r.features = [Feature(id: "n", type: "niche", wall: "B", off: 500, w: 800, d: 150, sill: 900, h: 600)]
        a = Geo.areas(r)!
        let nicheGross: Int64 = 18_000 * 3000 + 2 * 150 * 600 + 2 * 800 * 150
        XCTAssertEqual(a.gross, nicheGross)
        XCTAssertNil(Geo.featureIssue(r, r.features[0]))
    }

    func testTheTrades() {
        let t = TradeSet()
        var tw = t; tw.wallH = 1500
        let area = tileArea(room, tw)
        let want: Double = 20 + 27 - 0.9 * 1.5 - 1.2 * 0.6
        XCTAssertEqual(area, want, accuracy: 1e-9)
        let tr = tradeRows("tiler", [room], tw, words)
        XCTAssertEqual(tr.mats.map(\.id), ["t-tile", "t-glue", "t-grout"])
        let e = tradeRows("elec", [room], t, words)
        XCTAssertEqual(e.facts["points"], 4); XCTAssertEqual(e.facts["cable"] ?? 0, 18 + 10, accuracy: 1e-9)
        XCTAssertEqual(e.labor.first?.amount, "240000")
        let p = tradeRows("plumb", [room], t, words)
        XCTAssertEqual(p.mats.first { $0.id == "t-pipe" }?.qty, "24")
        let w = tradeRows("win", [room], t, words)
        XCTAssertEqual(w.mats.map(\.id), ["t-door", "t-window", "t-sill", "t-reveal"])
        XCTAssertEqual(w.mats[2].qty, "1.3")
    }

    func testInstallDateSkipsSundays() {
        // 2026-10-17 is a Saturday: 1 working day later is Monday the 19th
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 17
        let sat = Calendar(identifier: .gregorian).date(from: c)!
        let mon = addWorkDays(sat, 1)
        XCTAssertEqual(Calendar(identifier: .gregorian).component(.weekday, from: mon), 2)
        var p = Project(id: "p", name: "TEST"); p.industry = "furniture"; p.stage = "approved"
        p.approvedAt = Ms(sat.timeIntervalSince1970 * 1000); p.fprice.days = 1; p.fprice.inst = 0
        XCTAssertEqual(installDate(p), dayOf(Ms(mon.timeIntervalSince1970 * 1000)))
    }

    func testSectionsNeverGoBelowNothing() {
        // one section is the whole wardrobe, locked or not
        XCTAssertEqual(splitSections(1800, [Section(600, lock: true)]).map(\.w), [1800])
        // locked ones that no longer fit give way: all share again
        let s = splitSections(1000, [Section(900, lock: true), Section(900, lock: true), Section(300)])
        XCTAssertTrue(s.allSatisfy { $0.w >= 150 && !$0.lock }); XCTAssertEqual(s.reduce(0) { $0 + $1.w }, 1000)
        // a fit with the wardrobe far from the corner still keeps 300 mm
        let f = newFreeWardrobe("Shkaf 1", "h3", 1500, 2200, 600, false, "door", Workshop())
        let p = fitTo(placed(f, ["B"], "r1", "w1", off: 1900), ["B"], { _ in 2000 }, 2500, Workshop(), off: 1900)
        XCTAssertGreaterThanOrEqual(wardOfF(p)!.w, 300)
    }
}
