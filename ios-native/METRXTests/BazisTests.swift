import XCTest
@testable import METRX

/// The ideas taken from Bazis Mebelshchik (23 Oct 2026; Android BazisTest, same cases and numbers): remnants, labels,
/// the Check list, corner pieces, Change for all.
final class BazisTests: XCTestCase {
    private let ws = Workshop()
    private func piece(_ id: String, _ v: [String: Int] = [:]) -> Furniture { pieceOf(fModel(id)!, v, ws, id) }
    private func row(_ key: String, _ L: Int, _ W: Int, grain: Bool = false, mat: String = "ldsp16w") -> CutRow {
        CutRow(p: FPart(key: key, mod: "", role: "carcass", L: L, W: W, qty: 1, grain: grain), mat: mat, cutL: L, cutW: W)
    }
    private var n = 0
    private func nextId() -> String { n += 1; return "r\(n)" }

    /* ---------------- remnants ---------------- */

    func testAFittingRemnantIsUsedBeforeANewSheet() {
        let rows = [row("fp.shelf", 700, 400)]
        let l = layout(rows, "ldsp16w", 2800, 2070, 4, 10, [Remnant("a", "ldsp16w", 800, 500), Remnant("b", "ldsp18a", 800, 500)])
        XCTAssertEqual(l.sheets.count, 0); XCTAssertEqual(l.rems.count, 1); XCTAssertEqual(l.rems.first?.rem?.id, "a")
        // what is left of the remnant: the end of the strip and the width under it
        let rest = l.rems.first?.rest ?? []
        XCTAssertTrue(rest.contains(BoardRest(96, 400)) && rest.contains(BoardRest(800, 96)))
        // the smallest that fits goes first
        let two = layout(rows, "ldsp16w", 2800, 2070, 4, 10, [Remnant("big", "ldsp16w", 2000, 1000), Remnant("small", "ldsp16w", 720, 420)])
        XCTAssertEqual(two.rems.count, 1); XCTAssertEqual(two.rems.first?.rem?.id, "small")
    }

    func testARemnantKeepsTheGrain() {
        // the remnant is 450 along the grain and 800 across: a part with grain 700 long cannot lie across it
        let rem = [Remnant("g", "ldsp16k", 450, 800, grain: true)]
        let grained = layout([row("fp.door", 700, 400, grain: true, mat: "ldsp16k")], "ldsp16k", 2800, 2070, 4, 10, rem)
        XCTAssertEqual(grained.rems.count, 0); XCTAssertEqual(grained.sheets.count, 1)
        let plain = layout([row("fp.shelf", 700, 400, mat: "ldsp16k")], "ldsp16k", 2800, 2070, 4, 10, rem)
        XCTAssertEqual(plain.rems.count, 1); XCTAssertEqual(plain.sheets.count, 0)
        XCTAssertEqual(plain.rems.first?.placed.count, 1)
        XCTAssertEqual(plain.rems.first?.placed.first?.turned, true)
    }

    func testCuttingAnOrderTakesItsRemnantsAndKeepsItsOffcuts() {
        let store = [Remnant("old", "ldsp16w", 800, 500, src: "o0"), Remnant("other", "ldsp18a", 900, 900, src: "o0")]
        let f = piece("dresser")
        let lays = costOf([f], ws, MAT_PRESETS, HW_PRESETS, rems: remnantsFor(store, "o1", false)).layouts
        XCTAssertTrue(lays.contains { l in l.rems.contains { $0.rem?.id == "old" } })
        let after = cutDone(store, lays, MAT_PRESETS, "o1", 300, 5, { self.nextId() })
        let old = after.filter { $0.id == "old" }
        XCTAssertEqual(old.count, 1); XCTAssertEqual(old.first?.used, "o1")
        let kept = after.filter { $0.src == "o1" }
        XCTAssertFalse(kept.isEmpty); XCTAssertTrue(kept.allSatisfy { $0.L >= 300 && $0.W >= 300 && $0.used.isEmpty })
        // the kept board of a grained material says so
        XCTAssertTrue(kept.filter { $0.mat == "ldsp16k" }.allSatisfy { $0.grain })
        // another order: not the taken one, the new offcuts yes; the cut order: exactly what it took
        let next = remnantsFor(after, "o2", false)
        XCTAssertFalse(next.contains { $0.id == "old" }); XCTAssertTrue(kept.allSatisfy { k in next.contains(k) })
        XCTAssertEqual(remnantsFor(after, "o1", true).map(\.id), ["old"])
        // a deleted order's remnants stay taken: that board was cut
        XCTAssertFalse(remnantsFor(after, "o2", false).contains { $0.id == "old" })
        // undone: as before
        XCTAssertEqual(cutUndone(after, "o1"), store)
        // done twice: nothing kept twice
        XCTAssertEqual(cutDone(after, lays, MAT_PRESETS, "o1", 300, 6, { self.nextId() }).count, after.count)
    }

    func testTheCostCountsOnlyNewSheets() {
        let f = piece("dresser")
        let plain = costOf([f], ws, MAT_PRESETS, HW_PRESETS)
        guard let lay = plain.layouts.first(where: { $0.mat == f.mats.carcass }), let sheet = MAT_PRESETS.first(where: { $0.id == f.mats.carcass }) else {
            return XCTFail("no carcass layout")
        }
        let line0 = plain.lines.first { $0.group == "mat" && $0.key == f.mats.carcass }
        XCTAssertEqual(line0?.qty, Double(lay.sheets.count))
        // as many whole remnants as the carcass took sheets: no carcass sheet is bought
        let rems = (0..<lay.sheets.count).map { Remnant("w\($0)", f.mats.carcass, sheet.l - 2 * ws.trim, sheet.w - 2 * ws.trim) }
        let withRems = costOf([f], ws, MAT_PRESETS, HW_PRESETS, rems: rems)
        // no sheet bought: no line at all (not a 0-sheet line saying its price is missing)
        XCTAssertFalse(withRems.lines.contains { $0.group == "mat" && $0.key == f.mats.carcass })
        XCTAssertTrue(withRems.total < plain.total)
        // cutting them is still work
        XCTAssertEqual(plain.lines.first { $0.key == "fc.cut" }?.qty, withRems.lines.first { $0.key == "fc.cut" }?.qty)
        // the customer's price stays; the profit grows
        let fp = FPrice()
        XCTAssertEqual(priceOf([f], fp, ws, MAT_PRESETS, HW_PRESETS).price, priceOf([f], fp, ws, MAT_PRESETS, HW_PRESETS, rems).price)
    }

    /* ---------------- labels ---------------- */

    func testLabelsAreOneAPartTwentyFourToAPage() {
        XCTAssertEqual(LABELS_PER_PAGE, 24)
        XCTAssertEqual(labelPages(1), 1); XCTAssertEqual(labelPages(24), 1); XCTAssertEqual(labelPages(25), 2); XCTAssertEqual(labelPages(0), 0)
        func slot(_ i: Int) -> [Int] { let x = labelSlot(i); return [x.page, x.col, x.row] }
        XCTAssertEqual(slot(0), [0, 0, 0]); XCTAssertEqual(slot(2), [0, 2, 0]); XCTAssertEqual(slot(3), [0, 0, 1])
        XCTAssertEqual(slot(23), [0, 2, 7]); XCTAssertEqual(slot(24), [1, 0, 0])
        let fs = [piece("dresser"), piece("h3")]
        let ls = labelsOf(fs, ws)
        XCTAssertEqual(cutList(fs, ws).reduce(0) { $0 + $1.p.qty }, ls.count)
        XCTAssertEqual(ls.map(\.n), Array(1...max(1, ls.count)))
        XCTAssertTrue(ls.contains { $0.bands.any })
        XCTAssertEqual(labelId("abc123-xyz", 7), "MX-abc123-007")
    }

    /* ---------------- the Check list ---------------- */

    func testTheCheckListCollectsEveryPiecesProblems() {
        let wide = Module(id: "m1", type: "wardrobe", w: 1200, h: 2000, d: 600, wall: "A",
                          sections: [Section(1200, fronts: Fronts("open", 0), inserts: [Insert("shelf", pos: 400)])], legs: false)
        let shallow = Module(id: "m2", type: "wardrobe", w: 600, h: 1000, d: 300, wall: "A",
                             sections: [Section(600, fronts: Fronts("open", 0), inserts: [Insert("drawer", pos: 100, h: 200)])], legs: false)
        let tall = Module(id: "m3", type: "wardrobe", w: 600, h: 2900, d: 600, wall: "A", sections: [Section(600, fronts: Fronts("door", 1))], legs: false)
        let a = Furniture(id: "a", kind: "wardrobe", name: "A", roomId: nil, walls: ["A"], modules: [wide])
        let b = Furniture(id: "b", kind: "wardrobe", name: "B", roomId: nil, walls: ["A"], modules: [shallow, tall])
        var ok = piece("dresser"); ok.id = "c"
        let found = orderChecks([a, b, ok], ws, MAT_PRESETS) { f in
            f.id == "a" ? [OrderIssue("a", "err", "fz.doorsHit", ["n": "B"])] : []
        }
        XCTAssertTrue(found.contains { $0.fid == "a" && $0.key == "bz.ck.shelf" && $0.vars["v"] == AnyHashable(1166) && $0.vars["max"] == AnyHashable(1000) })
        XCTAssertTrue(found.contains { $0.fid == "b" && $0.key == "bz.ck.drawer" && $0.mid == "m2" })
        XCTAssertTrue(found.contains { $0.fid == "b" && $0.key == "bz.ck.sheet" && $0.vars["l"] == AnyHashable(2900) })
        XCTAssertTrue(found.contains { $0.fid == "a" && $0.key == "fz.doorsHit" })
        XCTAssertFalse(found.contains { $0.fid == "c" })
        // errors first
        XCTAssertEqual(found, found.filter { $0.level == "err" } + found.filter { $0.level != "err" })
        // 18 mm board carries 1100 mm; a usual corner wardrobe has nothing to say
        XCTAssertEqual(shelfSpanMax(18), 1100)
        var ws18 = ws; ws18.t = 18
        let shelf18 = orderChecks([a], ws18, MAT_PRESETS).filter { $0.key == "bz.ck.shelf" }
        XCTAssertEqual(shelf18.count, 1); XCTAssertEqual(shelf18.first?.vars["max"], AnyHashable(1100))
        for sh in 0...3 { XCTAssertTrue(orderChecks([piece("cornerW", ["sh": sh])], ws, MAT_PRESETS).isEmpty, "\(sh)") }
    }

    /* ---------------- corner pieces: the shape and whichever sides were measured ---------------- */

    func testACornerPieceIsBuiltFromWhicheverSidesWereMeasured() {
        let m = fModel("cornerW")!
        XCTAssertEqual(stepsOf(m, ["ms": 1]).map(\.key), ["sh", "ms", "ai", "bi", "h", "d"])
        XCTAssertEqual(stepsOf(m, ["ms": 2]).map(\.key), ["sh", "ms", "la", "lb", "h", "d"])
        // the fronts: arm A along its wall is its front plus the other arm's depth (less the gap at the corner)
        let fr = derive(m, ["ms": 1, "ai": 1500, "bi": 1200, "d": 600])
        XCTAssertEqual(fr["w"], 1500 + 600 - W_GAP_SIDE); XCTAssertEqual(fr["w2"], 1800)
        let v = valsOf(pieceOf(m, ["ms": 1, "ai": 1500, "bi": 1200, "d": 600], ws, "x"), ws)
        XCTAssertEqual(fr["w"], v["w"]); XCTAssertEqual(fr["w2"], v["w2"])
        // the walls: a gap at each end of the first, at the end of the second
        let wl = derive(m, ["ms": 2, "la": 2400, "lb": 2000])
        XCTAssertEqual(wl["w"], 2400 - 2 * W_GAP_SIDE); XCTAssertEqual(wl["w2"], 2000 - W_GAP_SIDE)
        // the usual sizes are the same piece whichever way it is measured
        let usualW = derive(m, ["ms": 0])["w"] ?? stepsOf(m).first { $0.key == "w" }?.usual
        XCTAssertEqual(usualW, derive(m, ["ms": 1])["w"])
        // what was worked out is shown: typed along the walls, the fronts and the walls come out
        let shown = derivedSides(m, ["ms": 0, "w": 1800, "w2": 1600, "d": 600])
        XCTAssertEqual(shown.map(\.key), ["bz.ai", "bz.bi", "bz.la", "bz.lb"])
        XCTAssertEqual(shown.map(\.mm), [1210, 1000, 1820, 1610])
        // a front too short for the piece is marked, and the piece stays within its sizes
        XCTAssertTrue(derivedSides(m, ["ms": 1, "ai": 300, "bi": 300, "d": 600]).contains { $0.bad })
        // the L kitchen: the worktop's front edges
        let k = fModel("L")!
        XCTAssertEqual(stepsOf(k, ["ms": 1]).map(\.key), ["sh", "ms", "f0", "f1", "h"])
        let kd = derive(k, ["ms": 1, "f0": 2400, "f1": 1400])
        XCTAssertEqual(kd["s0"], 3000); XCTAssertEqual(kd["s1"], 2000)
        XCTAssertEqual(pieceOf(k, ["ms": 1, "f0": 2400, "f1": 1400], ws, "k").free?.sides, [3000, 2000])
    }

    func testACornerPiecesShapeIsBuiltAsPictured() {
        let m = fModel("cornerW")!
        XCTAssertEqual(shapesOf(m).count, 4); XCTAssertEqual(shapesOf(fModel("cornerDesk")!).count, 2); XCTAssertEqual(shapesOf(fModel("L")!).count, 2)
        XCTAssertTrue(shapesOf(fModel("I")!).isEmpty)
        let right = piece("cornerW")
        XCTAssertEqual(right.walls, ["A", "B"]); XCTAssertEqual(right.hand, "")
        // corner on the left, open shelves: the same arms on the made-up room's left and back walls
        let openL = piece("cornerW", ["sh": 3])
        XCTAssertEqual(openL.walls, ["D", "A"]); XCTAssertEqual(openL.hand, "L")
        let corners = boxes(openL).filter { b in b.sections.contains { $0.blind > 0 } }
        XCTAssertEqual(corners.count, 1)
        let corner = corners[0]
        XCTAssertEqual(corner.sections.count, 1)
        XCTAssertEqual(corner.sections.first?.fronts.kind, "open")
        XCTAssertTrue((corner.sections.first?.inserts.filter { $0.kind == "shelf" }.count ?? 0) >= 3)
        XCTAssertEqual(valsOf(openL, ws)["sh"], 3)
        // its made-up room: the left wall carries the first arm, the back wall the second
        let r = freeRoom(openL)
        XCTAssertEqual(r.dim("B").v, (valsOf(openL, ws)["w"] ?? 0) + 2 * W_GAP_SIDE)
        // no hinges on the open corner
        XCTAssertTrue((hardware([openL], ws)["hingeSoft"] ?? 0) < (hardware([right], ws)["hingeSoft"] ?? 0))
        // sizes changed later keep the shape
        let bigger = resized(openL, ["w": 2000], ws)
        XCTAssertEqual(bigger.hand, "L"); XCTAssertEqual(bigger.walls, ["D", "A"])
        // the L kitchen with its corner on the left goes D then A; taken out of a room it stays so
        let kl = piece("L", ["sh": 1, "s0": 3200, "s1": 2100])
        XCTAssertEqual(kl.walls, ["D", "A"]); XCTAssertEqual(kl.hand, "L")
        // its runs go from the side wall (2100) to the main, back wall (3200); the sizes come back as typed
        XCTAssertEqual(kl.free?.sides, [2100, 3200])
        XCTAssertEqual(freeRoom(kl).dim("A").v, 3200); XCTAssertEqual(freeRoom(kl).dim("B").v, 2100)
        XCTAssertEqual(valsOf(kl, ws)["sh"], 1); XCTAssertEqual(valsOf(kl, ws)["s0"], 3200); XCTAssertEqual(valsOf(kl, ws)["s1"], 2100)
        XCTAssertEqual(resized(kl, ["s0": 3400], ws).free?.sides, [2100, 3400])
        let desk = piece("cornerDesk", ["sh": 1])
        XCTAssertEqual(desk.walls, ["D", "A"])
        XCTAssertEqual(takenOut(placed(desk, ["B", "C"], "room", "w", ws: ws), { _ in 3000 }, 2700).walls, ["D", "A"])
    }

    /* ---------------- Change for all ---------------- */

    func testChangeForAllChangesEveryPieceAndTheOldOnesComeBack() {
        let fs = [piece("dresser"), piece("h3"), piece("L")]
        let fronts = swapAll(fs, front: "mdf18")
        XCTAssertTrue(fronts.allSatisfy { $0.mats.front == "mdf18" }); XCTAssertEqual(commonFront(fronts), "mdf18")
        XCTAssertEqual(fs.map(\.mats.carcass), fronts.map(\.mats.carcass))
        let none = swapAll(fronts, handle: NO_HANDLES)
        XCTAssertEqual(commonHandle(none), NO_HANDLES)
        XCTAssertEqual(hardware(none, ws)["handle"] ?? 0, 0)
        let knobs = swapAll(none, handle: "handleKnob")
        XCTAssertEqual(commonHandle(knobs), "handleKnob")
        // the knobs are priced as knobs, not as the usual handle
        let c = costOf(knobs, ws, MAT_PRESETS, HW_PRESETS)
        let nHandles = hardware(knobs, ws)["handle"] ?? 0
        XCTAssertTrue(nHandles > 0)
        let knobLines = c.lines.filter { $0.group == "hw" && $0.key == "handleKnob" }
        XCTAssertEqual(knobLines.count, 1); XCTAssertEqual(knobLines.first?.qty, Double(nHandles))
        XCTAssertFalse(c.lines.contains { $0.group == "hw" && $0.key == "handle" })
        // Undo: the pieces kept from before are the pieces as they were
        XCTAssertNotEqual(fs, knobs)
        XCTAssertEqual(fs.map(\.mats.front), ["ldsp16k", "ldsp16k", "ldsp16k"])
        XCTAssertTrue(fs.allSatisfy { f in f.modules.filter { $0.type != "gap" }.allSatisfy { $0.handles } })
        // the usual price is the skoba's, whatever handle presets came after it
        XCTAssertEqual(usualHw(HW_PRESETS, "handle")?.id, "handle")
        XCTAssertEqual(costOf(fs, ws, MAT_PRESETS, HW_PRESETS).total, costOf(swapAll(fs, handle: ""), ws, MAT_PRESETS, HW_PRESETS).total)
    }
}
