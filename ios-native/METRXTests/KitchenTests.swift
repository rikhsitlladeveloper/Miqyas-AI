import XCTest
@testable import METRX

/// Kitchen rules (furniture plan section 7; Android KitchenTest) on the design's L-kitchen: walls A 3400 and B 2600.
final class KitchenTests: XCTestCase {
    private let ws = Workshop()
    private let f0 = Furniture(id: "k", kind: "kitchen", walls: ["A", "B"], layout: "L")
    private var runs: [Run] { runsOf(f0) { ["A": 3400, "B": 2600][$0] } }
    private let water = [SitePoint(id: "w", t: "cold", wall: "A", off: 1300, h: 550), SitePoint(id: "s", t: "sewer", wall: "A", off: 1320, h: 450)]
    private func with(_ ms: [Module]) -> Furniture { var f = f0; f.modules = ms; return pack(f, runs) }

    func testTheNextWallStartsAfterTheCorner() {
        XCTAssertEqual(runs, [Run(wall: "A", len: 3400, lowStart: 0, upStart: 0), Run(wall: "B", len: 2600, lowStart: 600, upStart: 320)])
        XCTAssertEqual(worktopTop(ws), 858); XCTAssertEqual(wallElev(ws), 1458)
    }

    func testAutoFillUsesWholeUnitsAndPutsTheSinkOverTheWater() {
        let f = autoFill(f0, runs, ws, [], water)
        let lowA = f.modules.filter { $0.wall == "A" && !isUpper($0) }
        // A turns into B: its narrow piece at its start, a 50 filler, then a whole unit in the corner, blind behind
        // B's first unit (the filler keeps the door beside it clear of B's fronts)
        XCTAssertEqual(lowA.map(\.w), [350, 600, 600, 600, 600, 50, 600])
        XCTAssertEqual(lowA.map(\.x), [0, 350, 950, 1550, 2150, 2750, 2800])
        XCTAssertEqual(lowA[5].type, "filler")
        XCTAssertEqual(lowA[2].app, "sink")                      // 950–1550 holds the water at 1300
        XCTAssertEqual(lowA.last?.fronts.kind, "panel")
        // B starts past the corner with a 50 filler, so its doors and handles clear A's
        let lowB = f.modules.filter { $0.wall == "B" && !isUpper($0) }
        XCTAssertEqual(lowB.map(\.w), [50, 600, 600, 600, 150])
        XCTAssertEqual(lowB.first?.type, "filler"); XCTAssertEqual(lowB.last?.type, "filler")
        XCTAssertEqual(lowB.first?.x, 600)
        XCTAssertEqual(fillOf(f, runs[0], false), Fill(used: 3400, avail: 3400))
        let c = checks(f, runs, ws, [], water)
        XCTAssertFalse(c.contains { $0.level == "err" })
        XCTAssertTrue(c.contains { $0.key == "kc.sinkOk" })
    }

    func testWindowsLeaveASpaceInTheUpperRow() {
        let win = [Opening(id: "o", type: "window", wall: "B", w: 1200, h: 1400, off: 1000, sill: 900)]
        let f = autoFill(f0, runs, ws, win, [])
        // B's upper row past the corner: a 50 filler, then 370–970 is clear; 970–1570, 1570–2170 and 2170–2600 meet
        // the window at 1000–2200
        XCTAssertEqual(f.modules.filter { $0.wall == "B" && isUpper($0) }.map(\.type), ["filler", "wall", "gap", "gap", "gap"])
    }

    func testTooLongAndGapsAreReported() {
        let f = with([template("base", ws, "A", 2000), template("base", ws, "A", 1600), template("base", ws, "B", 1000)])
        let c = checks(f, runs, ws, [], [])
        XCTAssertTrue(c.contains { $0.key == "kc.over" && $0.vars["v"] == AnyHashable(200) && $0.vars["w"] == AnyHashable("A") })
        XCTAssertTrue(c.contains { $0.key == "kc.gap" && $0.vars["v"] == AnyHashable(1000) && $0.vars["w"] == AnyHashable("B") })
    }

    func testSocketsDoorsAndTheMeterAreChecked() {
        let f = with([template("drawers", ws, "A", 600), template("base", ws, "A", 600), template("pantry", ws, "B", 600)])
        let pts = [SitePoint(id: "p", t: "socket", wall: "A", off: 520, h: 300), SitePoint(id: "m", t: "meter", wall: "B", off: 900, h: 1500, d: 300, mh: 400)]
        let door = [Opening(id: "d", type: "door", wall: "A", w: 900, h: 2100, off: 1100, sill: 0)]
        let c = checks(f, runs, ws, door, pts)
        XCTAssertEqual(c.filter { $0.key == "kc.socket" }.map(\.mid), [f.modules[0].id])
        XCTAssertEqual(c.filter { $0.key == "kc.door" }.map(\.mid), [f.modules[1].id])
        XCTAssertEqual(c.filter { $0.key == "kc.meter" }.map(\.mid), [f.modules[2].id])
    }

    func testTheHoodNeedsMoreRoomOverGas() {
        var hood = template("hood", ws, "B"); hood.elev = worktopTop(ws) + 650
        let f = with([hood])
        XCTAssertFalse(checks(f, runs, ws, [], []).contains { $0.key == "kc.hood" })
        let gas = [SitePoint(id: "g", t: "gas", wall: "B", off: 900, h: 1000)]
        let c = checks(f, runs, ws, [], gas).filter { $0.key == "kc.hood" }
        XCTAssertEqual(c.count, 1)
        XCTAssertEqual(c.first?.vars["v"], AnyHashable(650)); XCTAssertEqual(c.first?.vars["n"], AnyHashable(750))
    }

    func testWorktopAndAppliancesMakeParts() {
        let f = autoFill(f0, runs, ws, [], water)
        XCTAssertEqual(worktopRuns(f), ["A": 3400, "B": 2000])
        XCTAssertEqual(worktopPieces(f, 4100), 2)
        let dw = partsOf(template("dishwasher", ws, "A"), ws)
        XCTAssertEqual(dw, [FPart(key: "fp.panel", mod: dw[0].mod, role: "front", L: 717, W: 597, qty: 1, bands: Bands(l1: 2, l2: 2, s1: 2, s2: 2), grain: true)])
        let fl = partsOf(template("fillerLow", ws, "A", 50), ws)
        XCTAssertEqual(fl.count, 1); XCTAssertEqual([fl[0].L, fl[0].W], [720, 50]); XCTAssertEqual(fl[0].key, "fp.filler")
        XCTAssertTrue(hardwareOf(template("fridge", ws, "A"), ws).keys.isEmpty)
    }

    func testTheWorktopIsPricedByTheMetreAndFridgePanelsStack() {
        let f = autoFill(f0, runs, ws, [], water)
        let line = costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false).lines.filter { $0.key == "wt38" }
        XCTAssertEqual(line.count, 1)
        XCTAssertEqual(line[0].qty, 5.4, accuracy: 1e-9)           // 3400 on A + 2000 on B
        XCTAssertEqual(line[0].amount, 1_944_000)                  // 5,4 × 360 000
        let fr = partsOf(template("fridgeB", ws, "A"), ws).filter { $0.key == "fp.panel" }
        XCTAssertEqual(fr.count, 1); XCTAssertEqual(fr[0].qty, 2)
        XCTAssertEqual(fr[0].W, 597)                               // full width: the two panels are one above the other
        XCTAssertFalse(hardwareOf(template("fridgeB", ws, "A"), ws).keys.contains { $0.hasPrefix("hinge") })
    }
}
