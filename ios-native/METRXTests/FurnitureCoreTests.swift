import XCTest
@testable import METRX

/// The shared furniture core (furniture plan section 6; Android FurnitureCoreTest) against furniture-cases.json, which
/// the Android app's tests use too.
final class FurnitureCoreTests: XCTestCase {
    private let ws = Workshop()
    private struct Case { let name: String, module: Module, parts: [P: Int], hardware: [String: Int] }
    private struct P: Hashable { let key: String, L: Int, W: Int, bands: [Int] }

    private lazy var cases: [Case] = {
        let url = Bundle(for: FurnitureCoreTests.self).url(forResource: "furniture-cases", withExtension: "json")!
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        return (root["cases"] as! [[String: Any]]).map { c in
            let m = try! JSONDecoder().decode(Module.self, from: JSONSerialization.data(withJSONObject: c["module"]!))
            var parts: [P: Int] = [:]
            for a in c["parts"] as! [[Any]] { parts[P(key: a[0] as! String, L: a[1] as! Int, W: a[2] as! Int, bands: a[4] as! [Int])] = a[3] as? Int }
            return Case(name: c["name"] as! String, module: m, parts: parts, hardware: c["hardware"] as! [String: Int])
        }
    }()

    func testPartsMatchTheCases() {
        XCTAssertEqual(cases.count, 4)
        for c in cases {
            var got: [P: Int] = [:]
            for p in partsOf(c.module, ws) { got[P(key: p.key, L: p.L, W: p.W, bands: [p.bands.l1, p.bands.l2, p.bands.s1, p.bands.s2]), default: 0] += p.qty }
            XCTAssertEqual(got, c.parts, c.name)
        }
    }

    func testHardwareMatchesTheCases() {
        for c in cases { XCTAssertEqual(hardwareOf(c.module, ws).n, c.hardware, c.name) }
    }

    func testCutSizesLeaveRoomForTheBanding() {
        let rows = cutList([Furniture(id: "f", kind: "kitchen", modules: [cases[0].module])], ws)
        let door = rows.filter { $0.p.key == "fp.door" }, side = rows.filter { $0.p.key == "fp.side" }
        XCTAssertEqual(door.count, 1); XCTAssertEqual(side.count, 1)
        XCTAssertEqual([door[0].cutL, door[0].cutW], [713, 293])          // 2 mm thick banding all round
        XCTAssertEqual([side[0].cutL, side[0].cutW], [704, 558])          // banded on its front edge only
        XCTAssertEqual(door[0].mat, "ldsp16k"); XCTAssertEqual(side[0].mat, "ldsp16w")
    }

    func testBandingIsCountedWithTrimming() {
        let m = Module(id: "w", type: "wall", w: 600, h: 720, d: 300, fronts: Fronts("open", 0))
        let rows = cutList([Furniture(id: "f", kind: "kitchen", modules: [m])], ws)
        // sides 2 × (720 + 30), top and bottom 2 × (568 + 30): thick only
        let (thick, thin) = bandMetres(rows)
        XCTAssertEqual(thick, 2.696, accuracy: 1e-9); XCTAssertEqual(thin, 0, accuracy: 1e-9)
    }

    func testSheetLayoutPacksAndKeepsCutsApart() {
        let rows = [CutRow(p: FPart(key: "x", mod: "", role: "carcass", L: 1000, W: 1000, qty: 5), mat: "m", cutL: 1000, cutW: 1000)]
        let l = layout(rows, "m", 2800, 2070, 4, 10)
        // 2 across (1000 + 4 + 1000 ≤ 2780) and 2 strips (≤ 2050) a sheet: 5 pieces → 2 sheets
        XCTAssertEqual(l.sheets.count, 2); XCTAssertEqual(l.sheets[0].placed.count, 4)
        for s in l.sheets {
            for (i, a) in s.placed.enumerated() {
                XCTAssertTrue(a.x >= 0 && a.y >= 0 && a.x + a.w <= 2780 && a.y + a.h <= 2050)
                for (j, b) in s.placed.enumerated() where j != i {
                    let apart = a.x + a.w + 4 <= b.x || b.x + b.w + 4 <= a.x || a.y + a.h + 4 <= b.y || b.y + b.h + 4 <= a.y
                    XCTAssertTrue(apart, "pieces closer than the saw cut")
                }
            }
        }
    }

    func testGrainNeverTurnsAndTooLongIsReported() {
        let rows = [
            CutRow(p: FPart(key: "door", mod: "", role: "front", L: 2500, W: 400, qty: 1, grain: true), mat: "k", cutL: 2500, cutW: 400),
            CutRow(p: FPart(key: "tall", mod: "", role: "front", L: 2400, W: 400, qty: 1, grain: true), mat: "k", cutL: 300, cutW: 2400)   // its grain runs across 2400
        ]
        let l = layout(rows, "k", 2800, 2070, 4, 10)
        XCTAssertEqual(l.unplaced, [1])
        XCTAssertEqual(l.sheets.count, 1); XCTAssertEqual(l.sheets[0].placed.map(\.w), [2500])
    }

    func testOrderCostAddsUp() {
        let ms = cases.prefix(3).map(\.module)
        let c = costOf([Furniture(id: "f", kind: "kitchen", modules: ms)], ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(c.total, c.sum("mat") + c.sum("hw") + c.sum("lab"))
        XCTAssertEqual(c.missing, 0)
        // every material needs at least its parts' area in sheets, and the packing wastes at most one more sheet here
        for l in c.layouts {
            let area = c.rows.filter { $0.mat == l.mat }.reduce(0) { $0 + $1.cutL * $1.cutW * $1.p.qty }
            let least = Int((Double(area) / (2780.0 * 2050)).rounded(.up))
            XCTAssertTrue((least...least + 1).contains(l.sheets.count), "\(l.mat): \(l.sheets.count) sheets")
        }
        XCTAssertEqual(c.layouts.first { $0.mat == "ldsp16k" }?.sheets.count, 1)
        XCTAssertTrue(c.layouts.allSatisfy { $0.unplaced.isEmpty })
        // labour: every sheet cut, 3 modules, installation and delivery
        let sheets = c.layouts.reduce(0) { $0 + $1.sheets.count }
        let lab = c.lines.filter { $0.group == "lab" && $0.key != "fc.band" }.reduce(Decimal(0)) { $0 + $1.amount }
        XCTAssertEqual(lab, Decimal(sheets * 45000 + 3 * 120000 + 1500000 + 300000))
    }

    func testMarginRoundsHalfUp() {
        XCTAssertEqual(withMargin(24_667_000, 30), 32_067_100)
        XCTAssertEqual(withMargin(10, 25), 13)   // 12,5 → 13
    }

    func testRunnersAndHinges() {
        XCTAssertEqual(runnerLen(560), 550); XCTAssertEqual(runnerLen(280), 300); XCTAssertEqual(runnerLen(700), 600)
        XCTAssertEqual([717, 1500, 2000, 2497].map(hingesFor), [2, 3, 4, 5])
    }

    /// The worktop is priced by the running metre (Android KitchenTest).
    func testWorktopByTheMetre() {
        let ms = [Module(id: "a", type: "base", w: 600, h: 720, d: 560, wall: "w1"), Module(id: "b", type: "base", w: 450, h: 720, d: 560, wall: "w1"),
                  Module(id: "u", type: "wall", w: 600, h: 720, d: 300, wall: "w1", elev: 1458)]
        let c = costOf([Furniture(id: "f", kind: "kitchen", modules: ms)], ws, MAT_PRESETS, HW_PRESETS)
        let wt = c.lines.first { $0.key == "wt38" }
        XCTAssertEqual(wt?.qty ?? 0, 1.05, accuracy: 1e-9)
        XCTAssertEqual(wt?.amount, 378_000)                   // 1,05 m × 360 000
    }
}
