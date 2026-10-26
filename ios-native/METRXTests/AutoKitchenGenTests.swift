import XCTest
@testable import METRX

/// The auto kitchen (Joylan ideas, 26 Oct 2026; Furniture/Core/AutoKitchenGen.swift; Android AutoKitchenTest, the same
/// cases): the approved mockup's room, 3.4 × 2.8 m, a window on A (1000–2200), the door on C (1300–2100), the cold
/// water on A at 1600 and the gas on B at 400.
final class AutoKitchenGenTests: XCTestCase {
    private let ws = Workshop()
    private let dishes = AKApp(fridge: "fs", oven: "hob", dw: true, hood: "built")

    private func mockRoom() -> Room {
        var r = Room(id: "r", floorId: "w", name: "Oshxona")
        r.dims = ["A": Dim(v: 3400), "B": Dim(v: 2800), "H": Dim(v: 2700), "T": Dim(v: 200, src: "default")]
        r.openings = [Opening(id: "o1", type: "window", wall: "A", w: 1200, h: 1250, off: 1000, sill: 950),
                      Opening(id: "o2", type: "door", wall: "C", w: 800, h: 2050, off: 1300)]
        r.points = [SitePoint(id: "s1", t: "cold", wall: "A", off: 1600, h: 500), SitePoint(id: "s2", t: "gas", wall: "B", off: 400, h: 600)]
        return r
    }

    private func mock() -> AKRoom { akRoomOf(mockRoom(), true) }

    private func plan(_ walls: [String], _ layout: String, _ preset: String = "twotone", app: AKApp? = nil, room: AKRoom? = nil) -> AKPlan {
        let p = akGenerate(room ?? mock(), walls: walls, layout: layout, app: app ?? dishes, preset: preset)
        XCTAssertNotNil(p, "\(layout) \(walls) \(preset)")
        return p!
    }

    private let configs: [([String], String)] = [(["A"], "line"), (["D", "A"], "L"), (["D", "A", "B"], "U"), (["D", "B"], "two")]

    func testRoomFromMeasuredRoom() {
        let R = mock()
        XCTAssertEqual(R.walls.map(\.id), ["A", "B", "C", "D"])
        XCTAssertEqual(R.walls.map(\.L), [3400, 2800, 3400, 2800])
        XCTAssertEqual(R.wall("B")?.at(0), AKPt(3400, 0))
        XCTAssertEqual(R.wall("A")?.nx, 0); XCTAssertEqual(R.wall("A")?.ny, 1)
        XCTAssertEqual(R.windows, [AKOpen(wall: "A", a: 1000, b: 2200, sill: 950, top: 2200)])
        XCTAssertTrue(R.blocked("C"))
        XCTAssertEqual(R.water, AKSpot(wall: "A", t: 1600))
        XCTAssertEqual(R.gas, AKSpot(wall: "B", t: 400))
        XCTAssertEqual(R.next("D"), "A"); XCTAssertEqual(R.prev("A"), "D")
    }

    func testFitWidths() {
        XCTAssertEqual(akFitW(1000), [600, 400])
        XCTAssertEqual(akFitW(950), [600, 350])
        XCTAssertEqual(akFitW(800), [800])
        XCTAssertEqual(akFitW(1800), [600, 600, 600])
        XCTAssertEqual(akFitW(120), [-120])
        XCTAssertEqual(akFitW(0), [])
    }

    func testLayoutsFromWalls() {
        let R = mock()
        XCTAssertEqual(akDeriveLayout(R, ["A"]), "line")
        XCTAssertEqual(akDeriveLayout(R, ["D", "A"]), "L")
        XCTAssertEqual(akDeriveLayout(R, ["D", "B"]), "two")
        XCTAssertEqual(akDeriveLayout(R, ["D", "A", "B"]), "U")
        XCTAssertEqual(akWallsFor(R, "U", ["A"]), ["D", "A", "B"])
        // the wall facing A has the door: two rows go on B and D
        XCTAssertEqual(akWallsFor(R, "two", ["A"]), ["B", "D"])
        XCTAssertEqual(akWallsFor(R, "L", ["D", "A"]), ["D", "A"])
        XCTAssertEqual(akTapWall(["D", "A", "B"], "C"), ["A", "B", "C"])
        XCTAssertEqual(akTapWall(["D", "A"], "D"), ["A"])
        XCTAssertEqual(akStartWalls(R), ["D", "A"])
        XCTAssertEqual(akPathRuns(R, ["A", "D"], "L").map(\.w), ["D", "A"])
    }

    /// The mockup's corner kitchen, as the approved mockup builds it (with the app's corners).
    func testMockupCornerKitchen() {
        let p = plan(["D", "A"], "L")
        XCTAssertEqual(p.err, 0); XCTAssertEqual(p.warn, 0)
        XCTAssertEqual(p.runs.map(\.w), ["D", "A"])
        XCTAssertEqual(p.sink.ri, 1); XCTAssertEqual(p.sink.a, 1200); XCTAssertEqual(p.sink.b, 2000)
        XCTAssertEqual(p.hob.ri, 1); XCTAssertEqual(p.hob.a, 2500); XCTAssertEqual(p.hob.b, 3100)
        XCTAssertEqual(p.runs[0].base.map(\.k), ["fridgeFS", "drawers", "doors", "doors", "cfill", "blind"])
        XCTAssertEqual(p.runs[1].base.map(\.k), ["cfill", "filler", "dw", "sink", "drawers", "hobOven", "drawers"])
        XCTAssertEqual(p.runs[0].ups.map(\.k), ["glass", "doors", "shelf", "blindUp"])
        XCTAssertEqual(p.runs[1].ups.map(\.k), ["cfillUp", "doors", "doors", "hood", "doors"])
        XCTAssertEqual(p.checks.map(\.key), ["ak.ck.sh", "ak.ck.hobClear", "ak.ck.frOk", "ak.ck.wOn", "ak.ck.gOk", "ak.ck.fitF", "ak.ck.frEnd", "ak.ck.dwOk"])
        XCTAssertEqual(p.dSH, 1200, accuracy: 0.5)
    }

    /// The gas far from every wall the kitchen may take: an error (the gas service moves the pipe), never a block.
    func testFarGasIsAnError() {
        var R = mock()
        R.gas = AKSpot(wall: "C", t: 3300)
        let p = plan(["A"], "line", room: R)
        XCTAssertEqual(p.err, 1); XCTAssertEqual(p.warn, 0)
        XCTAssertTrue(p.checks.contains { $0.key == "ak.ck.gFar" && $0.st == "err" })
    }

    /// A built-in fridge with the oven and a pantry beside it: no worktop by the fridge, a warning.
    func testTallBlockWarns() {
        let p = plan(["D", "A"], "L", "gola", app: AKApp(fridge: "bi", oven: "tall", dw: true, hood: "angled"))
        XCTAssertEqual(p.err, 0); XCTAssertEqual(p.warn, 1)
        XCTAssertEqual(p.runs[0].base.prefix(3).map(\.k), ["fridgeBI", "ovenT", "pantry"])
        XCTAssertTrue(p.checks.contains { $0.key == "ak.ck.frTall" })
        // the angled hood: no wall unit over the hob
        XCTAssertFalse(p.runs[1].ups.contains { $0.k == "hood" })
    }

    func testNoWaterNoGas() {
        var R = mock()
        R.water = nil; R.gas = nil
        let p = plan(["A"], "line", "neo", app: AKApp(fridge: "fs", oven: "hob", dw: false, hood: "built"), room: R)
        XCTAssertEqual(p.err, 0); XCTAssertEqual(p.warn, 1)
        XCTAssertTrue(p.checks.contains { $0.key == "ak.ck.noWater" })
        XCTAssertTrue(p.checks.contains { $0.key == "ak.ck.noGas" && $0.st == "ok" })
    }

    func testTooShortGivesNothing() {
        var r = mockRoom()
        r.dims["A"] = Dim(v: 1500); r.dims["B"] = Dim(v: 1200); r.openings = []; r.points = []
        XCTAssertNil(akGenerate(akRoomOf(r, true), walls: ["A"], layout: "line", app: AKApp(fridge: "fs", oven: "tall", dw: true, hood: "built"), preset: "dark"))
    }

    /// The numbers on a card are the checks' own: errors and warnings counted from them.
    func testCheckNumbers() {
        for (walls, lay) in configs {
            for pr in DESIGN_PRESETS {
                let p = plan(walls, lay, pr.id)
                XCTAssertEqual(p.err, p.checks.filter { $0.st == "err" }.count)
                XCTAssertEqual(p.warn, p.checks.filter { $0.st == "warn" }.count)
                XCTAssertTrue(p.checks.allSatisfy { ["ok", "warn", "err"].contains($0.st) && $0.key.hasPrefix("ak.ck.") })
            }
        }
    }

    func testSinkNearWaterHobNearGasFridgeNotUnderWindow() {
        let R = mock()
        for (walls, lay) in configs {
            for pr in DESIGN_PRESETS {
                let p = plan(walls, lay, pr.id)
                let s = p.runs[p.sink.ri], h = p.runs[p.hob.ri]
                // the sink by the water whenever the water's wall is in the kitchen
                if walls.contains("A") {
                    XCTAssertEqual(s.w, "A")
                    XCTAssertLessThanOrEqual(abs((p.sink.a + p.sink.b) / 2 - 1600), 400, "\(lay) \(pr.id)")
                }
                // the hob within the hose's reach of the gas pipe when its wall or a wall beside it is in the kitchen
                let hc = R.at(h.w, (p.hob.a + p.hob.b) / 2)
                if walls.contains("B") || walls.contains("A") { XCTAssertLessThanOrEqual(akDist(hc, R.spot(R.gas)!), 1500, "\(lay) \(pr.id)") }
                for r in p.runs {
                    for t in r.items where t.k.hasPrefix("fridge") {
                        XCTAssertFalse(R.windowsOn(r.w).contains { t.a < $0.b && t.b > $0.a }, "\(lay) \(pr.id)")
                        XCTAssertTrue(abs(t.a - r.lo) < 1 || abs(t.b - r.hi) < 1, "a fridge at a wall end")
                    }
                }
            }
        }
    }

    /// The kitchens made: every wall's lower row packed from its start to the wall's end, the upper row from its start,
    /// no gaps and no overlaps; one sink and one hob; the preset's look on.
    func testFurnitureRowsHaveNoGapsOrOverlaps() {
        let room = mockRoom()
        for (walls, lay) in configs {
            for pr in DESIGN_PRESETS {
                let p = plan(walls, lay, pr.id)
                let fs = akFurniture(p, room, pr.id, ws, snap: true)
                XCTAssertEqual(fs.count, lay == "two" ? 2 : 1)
                XCTAssertEqual(fs.flatMap { $0.modules }.filter { $0.app == "sink" }.count, 1)
                XCTAssertEqual(fs.flatMap { $0.modules }.filter { $0.app == "hob" }.count, 1)
                XCTAssertEqual(fs.flatMap { $0.modules }.filter { $0.app == "dishwasher" }.count, 1)
                for f in fs {
                    XCTAssertEqual(f.roomId, "r"); XCTAssertEqual(f.ws, "w"); XCTAssertEqual(f.look?.preset, pr.id)
                    XCTAssertEqual(f.layout, lay == "L" ? "L" : lay == "U" ? "U" : "I")
                    for (i, w) in f.walls.enumerated() {
                        let L = Int(room.dim(w == "A" || w == "C" ? "A" : "B").v!)
                        let low = f.modules.filter { $0.wall == w && !isUpper($0) }.sorted { $0.x < $1.x }
                        let up = f.modules.filter { $0.wall == w && isUpper($0) }.sorted { $0.x < $1.x }
                        XCTAssertEqual(low.first?.x, i > 0 ? K_CORNER : 0, "\(lay) \(pr.id) \(w)")
                        XCTAssertEqual(low.last.map { $0.x + $0.w }, L, "\(lay) \(pr.id) \(w)")
                        for k in 1..<max(1, low.count) { XCTAssertEqual(low[k].x, low[k - 1].x + low[k - 1].w, "\(lay) \(pr.id) \(w) low \(k)") }
                        XCTAssertEqual(up.first?.x, i > 0 ? K_UP_CORNER : 0, "\(lay) \(pr.id) \(w)")
                        for k in 1..<max(1, up.count) { XCTAssertEqual(up[k].x, up[k - 1].x + up[k - 1].w, "\(lay) \(pr.id) \(w) up \(k)") }
                        XCTAssertLessThanOrEqual(up.last.map { $0.x + $0.w } ?? 0, L)
                        XCTAssertTrue(low.allSatisfy { $0.w > 0 } && up.allSatisfy { $0.w > 0 })
                    }
                }
            }
        }
    }

    /// The card's facts: units counted without fillers and spaces, metres of the lower rows.
    func testCardFacts() {
        let fs = akFurniture(plan(["D", "A"], "L"), mockRoom(), "twotone", ws, snap: true)
        XCTAssertGreaterThan(akUnits(fs), 10)
        XCTAssertEqual(akUnits(fs), fs[0].modules.filter { ["base", "tall", "wall"].contains($0.type) || $0.app == "dishwasher" }.count)
        XCTAssertGreaterThan(akRunMm(fs), 4000)
        XCTAssertTrue(fs[0].modules.contains { glassDoors($0) && $0.accentIn })
    }
}
