import XCTest
@testable import METRX

/// Handles per door and per drawer, push latches and soft close per section (founder's decisions, 25 Oct 2026; Android
/// HandlesTest, same cases and numbers).
final class HandlesTests: XCTestCase {
    private let ws = Workshop()

    /// 1800 wide on a plinth: a pair of doors, an open section with two drawers, a glass door.
    private func ward() -> Module {
        Module(id: "w", type: "wardrobe", w: 1800, h: 2000, d: 600, sections: [
            Section(900, fronts: Fronts("door", 2)),
            Section(450, fronts: Fronts("open", 0), inserts: [Insert("drawer", pos: 0, h: 200), Insert("drawer", pos: 210, h: 200)]),
            Section(450, fronts: Fronts("door", 1), face: "glass")], legs: false)
    }

    private func piece(_ m: Module) -> Furniture { Furniture(id: "f", kind: "wardrobe", modules: [m]) }

    /// With a handle, without: as one array (tuples are not Equatable).
    private func split(_ m: Module) -> [Int] { let s = handleSplit(m); return [s.on, s.off] }

    private func hwLine(_ c: Cost, _ key: String) -> CostLine? { c.lines.first { $0.group == "hw" && $0.key == key } }

    func testTheFrontsAndTheirKeys() {
        XCTAssertEqual(handleFronts(ward()).map(\.key), ["s0:f0", "s0:f1", "s1:d210", "s1:d0", "s2:f0"])
        XCTAssertTrue(handleFronts(ward()).first { $0.key == "s2:f0" }?.glass == true)
        XCTAssertEqual(handleFronts(Module(id: "k", type: "base", w: 600, h: 720, d: 560, fronts: Fronts("drawer", 3))).map(\.key), ["f0", "f1", "f2"])
        // a fridge's space has none; a dishwasher's front has one
        XCTAssertTrue(handleFronts(Module(id: "g", type: "gap", w: 600, h: 2000, d: 650, fronts: Fronts("open", 0), app: "fridge")).isEmpty)
        XCTAssertEqual(handleFronts(Module(id: "g", type: "gap", w: 600, h: 720, d: 560, fronts: Fronts("door", 1), app: "dishwasher")).map(\.key), ["f0"])
    }

    func testTheHardwareCountsAPushLatchForEachFrontWithoutAHandle() {
        let m = ward()
        // as built: a glass door never has a handle
        let built = hardwareOf(m, ws)
        XCTAssertEqual(built["handle"], 4); XCTAssertEqual(built["push"], 1)
        let mixed = toggleHandle(toggleHandle(m, "s0:f1"), "s1:d0")
        XCTAssertTrue(hasHandle(mixed, "s0:f0")); XCTAssertFalse(hasHandle(mixed, "s0:f1"))
        XCTAssertTrue(hasHandle(mixed, "s1:d210")); XCTAssertFalse(hasHandle(mixed, "s1:d0"))
        let hw = hardwareOf(mixed, ws)
        XCTAssertEqual(hw["handle"], 2); XCTAssertEqual(hw["push"], 3); XCTAssertEqual(hw["runner"], 2)
        XCTAssertEqual(split(mixed), [2, 3])
        // a glass door cannot be given one
        XCTAssertFalse(hasHandle(withHandle(m, "s2:f0", true), "s2:f0"))
        // a kitchen unit of three drawers, the middle one pushed
        let k = toggleHandle(Module(id: "k", type: "base", w: 600, h: 720, d: 560, fronts: Fronts("drawer", 3)), "f1")
        let kh = hardwareOf(k, ws)
        XCTAssertEqual(kh["runner"], 3); XCTAssertEqual(kh["handle"], 2); XCTAssertEqual(kh["push"], 1)
        // a bed's four drawers, one pushed
        let bed = Module(id: "b", type: "bed", w: 1700, h: 1000, d: 2100, opt: ItemOpt(bed: "drawers", mw: 1600, ml: 2000))
        XCTAssertEqual(handleFronts(bed).count, 4)
        let bh = hardwareOf(toggleHandle(bed, "bd2"), ws)
        XCTAssertEqual(bh["handle"], 3); XCTAssertEqual(bh["push"], 1)
        // the cost prices the push latches at their preset
        let c = costOf([piece(mixed)], ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(hwLine(c, "push")?.qty, 3)
        XCTAssertEqual(hwLine(c, "push")?.amount, Decimal(90000))
    }

    func testTappingOneFrontOfABoxWithoutHandlesLeavesTheOthersAsTheyLook() {
        var off = ward(); off.handles = false
        XCTAssertEqual(split(off), [0, 5])
        let one = toggleHandle(off, "s0:f0")
        XCTAssertTrue(one.handles)
        XCTAssertEqual(handleFronts(one).map { hasHandle(one, $0.key) }, [true, false, false, false, false])
        // all, then none
        XCTAssertEqual(split(allHandles(one, true)), [4, 1])
        XCTAssertEqual(split(allHandles(one, false)), [0, 5])
    }

    func testAnOlderOrderLoadsAndSavesAsBefore() throws {
        let old = #"{"id":"w","type":"wardrobe","w":1800,"h":2000,"d":600,"legs":false,"soft":true,"handles":false,"sections":[{"w":900,"fronts":{"kind":"door","n":2},"inserts":[]},{"w":900,"fronts":{"kind":"open","n":0},"inserts":[{"kind":"drawer","pos":0,"h":200}]}]}"#
        let m = try JSONDecoder().decode(Module.self, from: Data(old.utf8))
        // its box-wide switch is every front's value
        XCTAssertEqual(split(m), [0, 3])
        XCTAssertEqual(hardwareOf(m, ws)["push"], 3); XCTAssertNil(hardwareOf(m, ws)["handle"])
        XCTAssertTrue(m.noHandle.isEmpty && m.sections.allSatisfy { $0.noHandle.isEmpty && $0.soft == nil })
        // saved again it has none of the new fields (an issued quote's fingerprint stays)
        let out = String(decoding: try JSONEncoder().encode(m), as: UTF8.self)
        XCTAssertFalse(out.contains("noHandle")); XCTAssertFalse(out.contains("\"push\"")); XCTAssertFalse(out.contains("\"soft\":null"))
        XCTAssertEqual(out.components(separatedBy: "\"soft\"").count - 1, 1)
        // an older order with handles: all of them, no latch
        let on = try JSONDecoder().decode(Module.self, from: Data(old.replacingOccurrences(of: "\"handles\":false", with: "\"handles\":true").utf8))
        XCTAssertEqual(split(on), [3, 0]); XCTAssertNil(hardwareOf(on, ws)["push"])
        // the new fields saved and read back
        let mixed = withSoft(toggleHandle(toggleHandle(on, "s0:f1"), "s1:d0"), 0, false)
        XCTAssertEqual(mixed, try JSONDecoder().decode(Module.self, from: JSONEncoder().encode(mixed)))
        let kitchen = toggleHandle(Module(id: "k", type: "base", w: 600, h: 720, d: 560, fronts: Fronts("drawer", 3)), "f2")
        XCTAssertEqual(kitchen, try JSONDecoder().decode(Module.self, from: JSONEncoder().encode(kitchen)))
    }

    func testChangeForAllKeepsTheChoicesAndNoHandlesThenATypePutsThemAllBack() {
        let mixed = piece(toggleHandle(ward(), "s0:f1"))
        let knobs = swapAll([mixed], handle: "handleKnob")[0]
        XCTAssertEqual(knobs.handle, "handleKnob")
        XCTAssertFalse(hasHandle(knobs.modules[0], "s0:f1")); XCTAssertTrue(hasHandle(knobs.modules[0], "s0:f0"))
        XCTAssertEqual(commonHandle([knobs]), "handleKnob")
        let none = swapAll([knobs], handle: NO_HANDLES)[0]
        XCTAssertFalse(hasHandles(none)); XCTAssertFalse(none.modules[0].handles)
        XCTAssertEqual(commonHandle([none]), NO_HANDLES)
        let back = swapAll([none], handle: "handleLong")[0]
        XCTAssertTrue(back.modules[0].handles)
        XCTAssertEqual(split(back.modules[0]), [4, 1])
        // the costs: knobs at the knob's price, the pushed door at the latch's
        let c = costOf([knobs], ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(hwLine(c, "handleKnob")?.qty, 3)
        XCTAssertEqual(hwLine(c, "push")?.qty, 2)
        // every door pushed one by one reads as no handles, and a type then puts them back too
        let allOff = handleFronts(ward()).reduce(ward()) { m, fr in withHandle(m, fr.key, false) }
        XCTAssertEqual(commonHandle([piece(allOff)]), NO_HANDLES)
        XCTAssertEqual(split(swapAll([piece(allOff)], handle: "handle")[0].modules[0]), [4, 1])
    }

    func testSoftCloseIsEachSectionsOwn() {
        let m = ward()
        // a pair of 1917 mm doors and a glass door: four hinges each
        XCTAssertEqual(hardwareOf(m, ws)["hingeSoft"], 12); XCTAssertNil(hardwareOf(m, ws)["hinge"])
        let one = withSoft(m, 2, false)
        XCTAssertTrue(softOf(one, 0)); XCTAssertFalse(softOf(one, 2))
        let hw = hardwareOf(one, ws)
        XCTAssertEqual(hw["hingeSoft"], 8); XCTAssertEqual(hw["hinge"], 4)
        // back to the box's value: no choice of its own kept
        XCTAssertNil(withSoft(one, 2, true).sections[2].soft)
        // "Hammasiga": every section as the one picked
        let all = softAll(one, false)
        XCTAssertFalse(all.soft); XCTAssertTrue(all.sections.allSatisfy { $0.soft == nil })
        let ah = hardwareOf(all, ws)
        XCTAssertEqual(ah["hinge"], 12); XCTAssertNil(ah["hingeSoft"])
    }

    func testNewDoorsDropTheOldChoices() {
        let s = Section(900, fronts: Fronts("door", 2), noHandle: [1])
        var one = s; one.fronts = Fronts("door", 1)
        XCTAssertTrue(frontsChanged(s, one).noHandle.isEmpty)
        var wider = s; wider.w = 1000
        XCTAssertEqual(frontsChanged(s, wider).noHandle, [1])
        let k = Module(id: "k", type: "base", w: 600, h: 720, d: 560, fronts: Fronts("drawer", 3), noHandle: ["f2"])
        var two = k; two.fronts = Fronts("drawer", 2)
        XCTAssertTrue(frontsChanged(k, two).noHandle.isEmpty)
        var doors = k; doors.fronts = Fronts("door", 2)
        XCTAssertTrue(frontsChanged(k, doors).noHandle.isEmpty)
        // a drawer moved keeps its choice: it is the drawer's own
        var moved = toggleHandle(ward(), "s1:d0")
        moved.sections[1].inserts = respaced(Array(moved.sections[1].inserts.reversed()), 1800, 16).sorted { $0.pos < $1.pos }
        XCTAssertEqual(moved.sections[1].inserts.filter(\.push).count, 1)
    }

    func testAPieceBuiltAgainKeepsItsPushedFronts() {
        let st = pieceOf(fModel("stenka")!, [:], ws, "stenka")
        guard let m0 = st.modules.first(where: { !handleFronts($0).isEmpty }), let key = handleFronts(m0).first?.key else { return XCTFail("no fronts") }
        var mixed = st
        mixed.modules = st.modules.map { $0.id == m0.id ? toggleHandle($0, key) : $0 }
        let big = pieceResized(mixed, ["w": (pieceVals(mixed, ws)["w"] ?? 0) + 400], ws)
        guard let i = mixed.modules.filter({ takesHandles($0) }).firstIndex(where: { $0.id == m0.id }) else { return XCTFail("no box") }
        let boxes = big.modules.filter { takesHandles($0) }
        XCTAssertTrue(i < boxes.count)
        if i < boxes.count { XCTAssertFalse(hasHandle(boxes[i], key)) }
        XCTAssertTrue(hasHandles(big))
    }

    func testTheTapTargetsSitOnTheDrawnFronts() {
        // the pair of doors share the section less the gaps; the open section's top drawer is the higher box
        let m = ward()
        let boxes = wardFrontBoxes(m, ws)
        XCTAssertEqual(boxes.map(\.f.key), handleFronts(m).map(\.key))
        let d210 = boxes.first { $0.f.key == "s1:d210" }, d0 = boxes.first { $0.f.key == "s1:d0" }
        XCTAssertTrue((d210?.y0 ?? 0) > (d0?.y0 ?? 0))
        let f0 = boxes[0], f1 = boxes[1]
        XCTAssertTrue(f0.x1 <= f1.x0 && f1.x1 <= 900)
        // a kitchen unit's drawers top down
        let u = unitFrontBoxes(Module(id: "k", type: "base", w: 600, h: 720, d: 560, fronts: Fronts("drawer", 3)), ws)
        XCTAssertEqual(u.count, 3)
        XCTAssertTrue(u[0].y0 > u[1].y0 && u[1].y0 > u[2].y0)
    }
}
