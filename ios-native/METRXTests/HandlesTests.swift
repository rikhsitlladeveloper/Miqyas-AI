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

    /* ---- the founder's answers (25 Oct 2026): drawers behind doors, the mirror cabinet, the dishwasher's front ---- */

    /// A pair of doors with two drawers behind them, and an open section with one drawer.
    private func behind() -> Module {
        Module(id: "w", type: "wardrobe", w: 1300, h: 2000, d: 600, sections: [
            Section(900, fronts: Fronts("door", 2), inserts: [Insert("drawer", pos: 0, h: 200), Insert("drawer", pos: 210, h: 200), Insert("shelf", pos: 900)]),
            Section(400, fronts: Fronts("open", 0), inserts: [Insert("drawer", pos: 0, h: 200)])], legs: false)
    }

    private func mirrorCabinet() -> Furniture { pieceOf(fModel("mirrorC")!, [:], ws, "mirrorC") }

    func testDrawersBehindDoorsTakeAHandleOrAPushLatch() {
        let m = behind()
        let fr = handleFronts(m)
        XCTAssertEqual(fr.map(\.key), ["s0:f0", "s0:f1", "s0:d210", "s0:d0", "s1:d0"])
        // the ones behind the doors are marked: they are not on the doors' picture
        XCTAssertEqual(fr.filter(\.inner).map(\.key), ["s0:d210", "s0:d0"])
        XCTAssertTrue(fr.filter(\.inner).allSatisfy { $0.drawer && $0.sec == 0 })
        XCTAssertEqual(wardFrontBoxes(m, ws).map(\.f.key), ["s0:f0", "s0:f1", "s1:d0"])
        // as built: every door and drawer has a handle
        let built = hardwareOf(m, ws)
        XCTAssertEqual(built["handle"], 5); XCTAssertNil(built["push"]); XCTAssertEqual(built["runner"], 3)
        // one behind the doors pushed: the same Insert.push flag as an open section's drawer
        let one = toggleHandle(m, "s0:d0")
        XCTAssertEqual(one.sections[0].inserts.first { $0.kind == "drawer" && $0.pos == 0 }?.push, true)
        XCTAssertFalse(hasHandle(one, "s0:d0")); XCTAssertTrue(hasHandle(one, "s0:d210"))
        if let x = one.sections[0].inserts.first(where: { $0.pos == 0 }) { XCTAssertFalse(drawerHandle(one, x)) } else { XCTFail("no drawer") }
        let oh = hardwareOf(one, ws)
        XCTAssertEqual(oh["handle"], 4); XCTAssertEqual(oh["push"], 1)
        XCTAssertEqual(split(one), [4, 1])
        // none, then all: per box
        XCTAssertEqual(split(allHandles(one, false)), [0, 5])
        let nh = hardwareOf(allHandles(one, false), ws)
        XCTAssertNil(nh["handle"]); XCTAssertEqual(nh["push"], 5)
        XCTAssertEqual(split(allHandles(one, true)), [5, 0])
        // a box without handles: tapping one door leaves the drawers behind it pushed
        var off = m; off.handles = false
        let tap = toggleHandle(off, "s0:f0")
        XCTAssertEqual(handleFronts(tap).map { hasHandle(tap, $0.key) }, [true, false, false, false, false])
        // an older order without handles: the drawers behind its doors are pushed open too
        XCTAssertEqual(hardwareOf(off, ws)["push"], 5)
    }

    func testDrawersBehindSlidingDoorsAreListedToo() {
        var m = behind(); m.slide = Slide(2)
        let fr = handleFronts(m)
        // the sliding doors take none; every drawer behind them does
        XCTAssertEqual(fr.map(\.key), ["s0:d210", "s0:d0", "s1:d0"])
        XCTAssertTrue(fr.allSatisfy(\.inner))
        let hw = hardwareOf(toggleHandle(m, "s1:d0"), ws)
        XCTAssertEqual(hw["handle"], 2); XCTAssertEqual(hw["push"], 1)
    }

    func testTheMirrorCabinetOpensByItsEdgeWithoutALatch() {
        let f = mirrorCabinet()
        XCTAssertEqual(f.type, "mirrorC"); XCTAssertTrue(opensByEdge(f))
        let boxes = f.modules.filter { $0.type == "wardrobe" }
        XCTAssertEqual(boxes.count, 1)
        guard let m = boxes.first, let k = handleFronts(m).first?.key else { return XCTFail("no fronts") }
        XCTAssertFalse(m.handles)
        // the order's hardware: no handle and no push latch for its doors
        let hw = hardware([f], ws)
        XCTAssertNil(hw["handle"]); XCTAssertNil(hw["push"]); XCTAssertTrue((hw["hingeSoft"] ?? 0) > 0)
        XCTAssertFalse(costOf([f], ws, MAT_PRESETS, HW_PRESETS).lines.contains { $0.group == "hw" && ($0.key == "push" || $0.key == "handle") })
        // a door given a handle counts it; the other still needs no latch
        var g = f
        g.modules = f.modules.map { $0.id == m.id ? toggleHandle($0, k) : $0 }
        let gh = hardware([g], ws)
        XCTAssertEqual(gh["handle"], 1); XCTAssertNil(gh["push"])
        // the same box in another piece is pushed open as before
        var plain = f; plain.type = ""
        XCTAssertEqual(hardware([plain], ws)["push"], handleFronts(m).count)
        XCTAssertFalse(opensByEdge(plain))
    }

    func testTheDishwashersFrontCountsItsHandleOrALatch() {
        // as the kitchen's library makes it: a gap with a panel front
        let dw = template("dishwasher", ws, "A")
        XCTAssertEqual(dw.type, "gap"); XCTAssertEqual(dw.app, "dishwasher")
        XCTAssertEqual(handleFronts(dw).map(\.key), ["f0"])
        XCTAssertEqual(hardwareOf(dw, ws).n, ["handle": 1])
        let off = toggleHandle(dw, "f0")
        XCTAssertEqual(off.noHandle, ["f0"])
        XCTAssertEqual(hardwareOf(off, ws).n, ["push": 1])
        XCTAssertEqual(hardwareOf(allHandles(dw, false), ws).n, ["push": 1])
        // a fridge's space has none
        XCTAssertTrue(hardwareOf(template("fridge", ws, "A"), ws).keys.isEmpty)
        // in the order's cost
        let k = Furniture(id: "k", kind: "kitchen", modules: [off])
        XCTAssertEqual(costOf([k], ws, MAT_PRESETS, HW_PRESETS).lines.filter { $0.group == "hw" && $0.key == "push" }.map(\.qty), [1.0])
    }

    func testChangeForAllPutsNoHandleOnTheMirrorCabinet() {
        let mc = mirrorCabinet()
        let w = piece(behind())
        // it has none whatever the others have: the shared handle still reads as one
        XCTAssertEqual(commonHandle([w, mc]), "")
        XCTAssertNil(commonHandle([mc]))
        // a type for all: the mirror cabinet stays as it is, no handle put on it
        let knobs = swapAll([w, mc], handle: "handleKnob")
        XCTAssertEqual(commonHandle(knobs), "handleKnob")
        XCTAssertEqual(knobs[1], mc)
        XCTAssertNil(hardware([knobs[1]], ws)["handle"])
        // "Tutqichsiz", then a type: the wardrobe's come back, the mirror cabinet's do not
        let back = swapAll(swapAll(knobs, handle: NO_HANDLES), handle: "handleLong")
        XCTAssertTrue(hasHandles(back[0])); XCTAssertFalse(hasHandles(back[1]))
        XCTAssertEqual(commonHandle(back), "handleLong")
        // a door given a handle on its own takes the new type
        guard let m = mc.modules.first(where: { $0.type == "wardrobe" }), let k = handleFronts(m).first?.key else { return XCTFail("no fronts") }
        var one = mc
        one.modules = mc.modules.map { $0.type == "wardrobe" ? toggleHandle($0, k) : $0 }
        let swapped = swapAll([one], handle: "handleKnob")[0]
        XCTAssertEqual(swapped.handle, "handleKnob"); XCTAssertEqual(hardware([swapped], ws)["handle"], 1)
    }
}
