import XCTest
@testable import METRX

/// Designer C's rules (Furniture/Core/DzcRules.swift): snaps, who takes a width's difference, a deleted unit's gap and
/// closing it, a copy to the right, moving along the row, the catalogue's tiles, sections, fronts and the new fields.
final class DesignerCTests: XCTestCase {
    private let ws = Workshop()

    private func unit(_ id: String, _ w: Int, _ kind: String = "base") -> Module {
        var m = template(kind, ws, "A", w)
        m.id = id
        return m
    }

    private func kitchen(_ ms: [Module]) -> Furniture {
        Furniture(id: "k", kind: "kitchen", walls: ["A"], modules: ms)
    }

    private func low(_ f: Furniture) -> [Module] { dzcRowMods(f, DzcRow(wall: "A", upper: false)) }

    /* ---------------- snaps ---------------- */

    func testSnapsToTheNearestWidth() {
        XCTAssertEqual(dzcSnapW(437, DZC_SNAP, fine: false, lo: 150, hi: 1200), 450)
        XCTAssertEqual(dzcSnapW(620, DZC_SNAP, fine: false, lo: 150, hi: 1200), 600)
        XCTAssertEqual(dzcSnapW(1500, DZC_SNAP, fine: false, lo: 150, hi: 1200), 1200)
    }

    func testZoomedInTheEdgeMovesInTenMillimetres() {
        XCTAssertEqual(dzcSnapW(437, DZC_SNAP, fine: true, lo: 150, hi: 1200), 440)
        // a snap within 15 mm still wins
        XCTAssertEqual(dzcSnapW(456, DZC_SNAP, fine: true, lo: 150, hi: 1200), 450)
        XCTAssertEqual(dzcSnapW(2000, DZC_SNAP, fine: true, lo: 150, hi: 900), 900)
    }

    func testAppliancesSnapOnlyToTheirWidths() {
        let dw = unit("d", 600, "dishwasher")
        XCTAssertEqual(dzcCandidates(dw, 1000), [450, 600])
        XCTAssertTrue(dzcFixedW(dw))
        let b = unit("b", 600)
        XCTAssertEqual(dzcCandidates(b, 700), [150, 300, 350, 400, 450, 500, 600, 700])
        // the widest it can get is a candidate too
        XCTAssertTrue(dzcCandidates(b, 640).contains(640))
    }

    /* ---------------- who takes the difference ---------------- */

    func testTheNearestFillerTakesTheDifferenceAndBecomesAGap() {
        let f = kitchen([unit("a", 600), unit("b", 600), unit("c", 50, "fillerLow"), unit("d", 600)])
        let r = dzcResize(f, "a", 450, avail: 1850, ws: ws)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.taker, "c"); XCTAssertEqual(r.w0, 50); XCTAssertEqual(r.w1, 200)
        let row = low(r.f)
        XCTAssertEqual(row.map(\.w), [450, 600, 200, 600])
        // a filler of 150 or more is an empty space now
        XCTAssertTrue(dzcSpace(row[2])); XCTAssertEqual(row[2].id, "c")
    }

    func testAFillerUsedUpGoes() {
        let f = kitchen([unit("a", 600), unit("c", 50, "fillerLow"), unit("d", 600)])
        let r = dzcResize(f, "a", 650, avail: 1250, ws: ws)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(low(r.f).map(\.id), ["a", "d"])
        XCTAssertEqual(low(r.f).map(\.w), [650, 600])
        // more than the filler has: not possible
        let no = dzcResize(f, "a", 700, avail: 1250, ws: ws)
        XCTAssertFalse(no.ok); XCTAssertEqual(no.why, "dzc.maxW"); XCTAssertEqual(no.vars["v"], 650)
    }

    func testGrowingUsesTheRowsFreeEnd() {
        let f = kitchen([unit("a", 600), unit("b", 600)])
        let r = dzcResize(f, "a", 800, avail: 1500, ws: ws)
        XCTAssertTrue(r.ok); XCTAssertEqual(r.taker, "")
        XCTAssertEqual(low(r.f).map(\.w), [800, 600])
    }

    func testOtherwiseTheNeighbourTakesIt() {
        let f = kitchen([unit("a", 600), unit("b", 600)])
        let r = dzcResize(f, "a", 450, avail: 1200, ws: ws)
        XCTAssertTrue(r.ok); XCTAssertEqual(r.taker, "b"); XCTAssertEqual(r.w1, 750)
        XCTAssertEqual(low(r.f).map(\.w), [450, 750])
        // the last unit's neighbour is the one on its left
        let r2 = dzcResize(f, "b", 700, avail: 1200, ws: ws)
        XCTAssertEqual(low(r2.f).map(\.w), [500, 700])
        // an appliance never takes it: shrinking, the row's free end grows; growing, nothing can give
        let g = kitchen([unit("a", 600), unit("d", 600, "dishwasher")])
        let rg = dzcResize(g, "a", 450, avail: 1200, ws: ws)
        XCTAssertTrue(rg.ok); XCTAssertEqual(rg.taker, "")
        XCTAssertEqual(low(rg.f).map(\.w), [450, 600])
        XCTAssertEqual(dzcResize(g, "a", 700, avail: 1200, ws: ws).why, "dzc.noTaker")
    }

    func testTheWidestAUnitCanGet() {
        let f = kitchen([unit("a", 600), unit("c", 100, "fillerLow"), unit("b", 600)])
        XCTAssertEqual(dzcMaxW(f, "a", avail: 1300), 700)
        let g = kitchen([unit("a", 600), unit("b", 600)])
        XCTAssertEqual(dzcMaxW(g, "a", avail: 1500), 1050)
    }

    /* ---------------- delete, close the gap ---------------- */

    func testDeleteLeavesAGapAndCloseMovesTheOthersUp() {
        let f = kitchen([unit("a", 600), unit("b", 600), unit("c", 600)])
        let d = dzcDelete(f, "b", ws: ws)
        XCTAssertTrue(d.ok)
        let row = low(d.f)
        XCTAssertEqual(row.map(\.w), [600, 600, 600])
        XCTAssertTrue(dzcSpace(row[1])); XCTAssertEqual(row[1].id, "b"); XCTAssertEqual(d.newId, "b")
        let c = dzcCloseGap(d.f, "b", avail: 1800, ws: ws)
        XCTAssertTrue(c.ok)
        let after = low(c.f)
        XCTAssertEqual(after.map(\.id).prefix(2), ["a", "c"])
        XCTAssertEqual(after.map(\.w), [600, 600, 600])
        XCTAssertTrue(dzcSpace(after[2]))
    }

    func testClosingGrowsTheFillerAtTheEndBeforeTheCorner() {
        var corner = unit("z", 600)
        corner.fronts = Fronts("panel", 1)
        let f = kitchen([unit("a", 600), unit("g", 600, "spaceLow"), unit("b", 600), unit("e", 50, "fillerLow"), corner])
        let c = dzcCloseGap(f, "g", avail: 2450, ws: ws)
        XCTAssertTrue(c.ok); XCTAssertEqual(c.taker, "e"); XCTAssertEqual(c.w1, 650)
        let row = low(c.f)
        XCTAssertEqual(row.map(\.id), ["a", "b", "e", "z"])
        XCTAssertTrue(dzcSpace(row[2]))       // 650 wide: an empty space now
        XCTAssertEqual(row.last?.fronts.kind, "panel")
        // a gap already at the end has nothing to close
        let end = kitchen([unit("a", 600), unit("g", 600, "spaceLow")])
        XCTAssertEqual(dzcCloseGap(end, "g", avail: 1200, ws: ws).why, "dzc.atEnd")
    }

    /* ---------------- copy ---------------- */

    func testCopyGoesRightAndTakesTheRoomOfAGap() {
        let f = kitchen([unit("a", 600), unit("b", 450), unit("g", 600, "spaceLow")])
        let r = dzcCopy(f, "b", avail: 1650, ws: ws, id: "b2")
        XCTAssertTrue(r.ok); XCTAssertEqual(r.newId, "b2")
        let row = low(r.f)
        XCTAssertEqual(row.map(\.id), ["a", "b", "b2", "g"])
        XCTAssertEqual(row.map(\.w), [600, 450, 450, 150])
        // no room: says how much is free and needed
        let full = kitchen([unit("a", 600), unit("b", 600)])
        let no = dzcCopy(full, "a", avail: 1300, ws: ws)
        XCTAssertFalse(no.ok); XCTAssertEqual(no.why, "dzc.noCopy"); XCTAssertEqual(no.vars["f"], 100); XCTAssertEqual(no.vars["n"], 600)
    }

    /* ---------------- move ---------------- */

    func testMoveAlongTheRowTheBlindCornerStaysLast() {
        var corner = unit("z", 600)
        corner.fronts = Fronts("panel", 1)
        let f = kitchen([unit("a", 600), unit("b", 450), unit("c", 800), corner])
        XCTAssertEqual(low(dzcMove(f, "a", to: 2, ws: ws).f).map(\.id), ["b", "c", "a", "z"])
        XCTAssertEqual(low(dzcMove(f, "a", to: 9, ws: ws).f).map(\.id), ["b", "c", "a", "z"])
        XCTAssertEqual(low(dzcMove(f, "c", to: 0, ws: ws).f).map(\.id), ["c", "a", "b", "z"])
        XCTAssertNil(dzcStep(f, "z", -1, ws: ws))
        XCTAssertEqual(dzcStep(f, "a", 1, ws: ws).map { low($0.f).map(\.id) }, ["b", "a", "c", "z"])
    }

    func testALiftedUnitDropsWhereItsCentreIsNearest() {
        let row = [unit("a", 600), unit("b", 600), unit("c", 600)]
        XCTAssertEqual(dzcDropSlot(row, "a", start: 0, gx: 1150), 2)
        XCTAssertEqual(dzcDropSlot(row, "a", start: 0, gx: 520), 1)
        XCTAssertEqual(dzcDropSlot(row, "c", start: 0, gx: -100), 0)
    }

    /* ---------------- the catalogue ---------------- */

    func testATileGoesIntoAGap() {
        let row = [unit("a", 600), unit("g", 800, "spaceLow")]
        let t = DZC_TILES.first { $0.kind == "base" && $0.w == 600 }!
        let p = dzcPlanInto(row, 1, t, ws: ws, right: false)
        XCTAssertTrue(p.ok); XCTAssertEqual(p.space, "g")
        XCTAssertEqual(p.row.map(\.w), [600, 600, 200])
        XCTAssertTrue(dzcSpace(p.row[2]))
        // a gap left under 100 becomes a filler
        let p2 = dzcPlanInto([unit("g", 650, "spaceLow")], 0, t, ws: ws, right: false)
        XCTAssertEqual(p2.row.map(\.type), ["base", "filler"])
        // too wide: the biggest snap that fits, but an appliance does not shrink
        let p3 = dzcPlanInto([unit("g", 500, "spaceLow")], 0, t, ws: ws, right: false)
        XCTAssertTrue(p3.ok); XCTAssertTrue(p3.adapted); XCTAssertEqual(p3.w, 500)
        let dw = DZC_TILES.first { $0.kind == "dishwasher" && $0.w == 600 }!
        let p4 = dzcPlanInto([unit("g", 500, "spaceLow")], 0, dw, ws: ws, right: false)
        XCTAssertFalse(p4.ok); XCTAssertEqual(p4.why, "dzc.spaceSmall")
    }

    func testATileBetweenTwoUnitsTakesTheFreeEnd() {
        let row = [unit("a", 600), unit("b", 600)]
        let t = DZC_TILES.first { $0.kind == "drawers" && $0.w == 450 }!
        let p = dzcPlanAt(row, t, u: 620, start: 0, avail: 2000, ws: ws, wall: "A")
        XCTAssertTrue(p.ok)
        XCTAssertEqual(p.row.map(\.w), [600, 450, 600])
        XCTAssertEqual(p.row[1].fronts.kind, "drawer")
        let no = dzcPlanAt(row, t, u: 620, start: 0, avail: 1300, ws: ws, wall: "A")
        XCTAssertFalse(no.ok); XCTAssertEqual(no.why, "dzc.noRoom")
    }

    func testATappedTileFillsTheFirstGapThatFits() {
        var f = kitchen([unit("a", 600), unit("g", 300, "spaceLow"), unit("b", 600), unit("h", 600, "spaceLow")])
        f = pack(f, runsOf(f) { _ in 2100 })
        let runs = runsOf(f) { _ in 2100 }
        let t = DZC_TILES.first { $0.kind == "base" && $0.w == 600 }!
        let r = dzcTapPlan(f, runs, cur: "A", sel: nil, t, ws: ws)
        XCTAssertTrue(r.plan.ok)
        // the 300 gap takes a 300 unit (the biggest snap that fits)
        XCTAssertEqual(r.plan.space, "g"); XCTAssertEqual(r.plan.w, 300)
    }

    /* ---------------- wall units ---------------- */

    func testAWallUnitsHeightKeepsItsTop() {
        var w = template("wall", ws, "A", 600)
        w.id = "w"
        let f = kitchen([w])
        let top = w.elev + w.h
        let g = dzcHeight(f, "w", 360)
        XCTAssertEqual(g.modules[0].h, 360); XCTAssertEqual(g.modules[0].elev + 360, top)
    }

    /* ---------------- type, fronts ---------------- */

    func testRetypeKeepsTheUnitsPlaceAndWidth() {
        var b = unit("a", 450)
        b.front = "x1"
        let r = dzcRetype(b, "drawer3", ws: ws)!
        XCTAssertEqual(r.id, "a"); XCTAssertEqual(r.w, 450)
        XCTAssertEqual(r.fronts, Fronts("drawer", 3)); XCTAssertEqual(r.front, "x1")
        XCTAssertEqual(dzcTypeOf(r), "drawer3")
        // a dishwasher only in its widths
        XCTAssertNil(dzcRetype(unit("b", 500), "dishwasher", ws: ws))
    }

    func testFrontsForOneARowOrTheWholeKitchen() {
        var w = template("wall", ws, "A", 600)
        w.id = "w"
        var f = kitchen([unit("a", 600), unit("b", 600), w])
        f.mats.front = "oak"
        let one = dzcFrontOne(f, ["a"], "grey")
        XCTAssertEqual(one.modules[0].front, "grey"); XCTAssertNil(one.modules[1].front)
        XCTAssertEqual(frontOf(one, one.modules[0]), "grey")
        // the lower row: the upper fronts keep their board
        let row = dzcFrontRow(one, upper: false, "white")
        XCTAssertEqual(row.mats.front, "white"); XCTAssertEqual(row.mats.frontUp, "oak")
        XCTAssertNil(row.modules[0].front)
        XCTAssertEqual(frontOf(row, row.modules[2]), "oak")
        let all = dzcFrontAll(one, "black")
        XCTAssertEqual(all.mats.front, "black"); XCTAssertNil(all.mats.frontUp)
        XCTAssertTrue(all.modules.allSatisfy { $0.front == nil })
    }

    func testAUnitsOwnBoardIsCutForItsFronts() {
        var b = unit("a", 600)
        b.front = "mdf18"
        let f = kitchen([b, unit("c", 600)])
        let mats = Set(partsWithMat(f, ws).filter { $0.0.role == "front" }.map(\.1))
        XCTAssertTrue(mats.contains("mdf18")); XCTAssertTrue(mats.contains(f.mats.front))
    }

    func testTheNewFieldsAreWrittenOnlyWhenSet() throws {
        let plain = unit("a", 600)
        let s = String(data: try JSONEncoder().encode(plain), encoding: .utf8)!
        XCTAssertFalse(s.contains("\"front\"")); XCTAssertFalse(s.contains("\"hinges\""))
        var set = withHinge(plain, -1, "R")
        set.front = "mdf18"
        let back = try JSONDecoder().decode(Module.self, from: JSONEncoder().encode(set))
        XCTAssertEqual(back.front, "mdf18"); XCTAssertEqual(back.hinges, ["R", "R"])
        XCTAssertTrue(kHingeRight(back, 0, 2)); XCTAssertTrue(kHingeRight(back, 1, 2))
        XCTAssertFalse(kHingeRight(plain, 0, 2))
        XCTAssertTrue(kHingeRight(plain, 1, 2))
        // the usual choice again: nothing written
        XCTAssertEqual(withHinge(withHinge(plain, 0, "L"), 1, "R").hinges, [])
    }

    func testTheKitchensBaseMovesItsUnits() {
        let f = kitchen([unit("a", 600)])
        let e0 = f.modules[0].elev
        let g = dzcKitchenBase(f, "metal", ws.legH + 50, ws: ws)
        XCTAssertEqual(g.modules[0].elev, e0 + 50)
        XCTAssertEqual(dzcKitchenBaseKind(g), "metal")
        XCTAssertEqual(g.kx?.plinth, false)
        XCTAssertEqual(dzcKitchenBaseKind(dzcKitchenBase(g, "plinth", ws.legH, ws: ws)), "plinth")
    }

    /* ---------------- sections ---------------- */

    private func wardrobe(_ ws0: [Int]) -> Module {
        var m = wardrobeTemplate(ws, "A", 0, ws0.reduce(0, +), 2400, builtIn: false)
        m.sections = ws0.map { Section($0) }
        return m
    }

    func testASectionsNeighbourTakesTheDifference() {
        let m = wardrobe([600, 600, 600])
        let r = dzcSecResize(m, 0, 450)
        XCTAssertTrue(r.ok); XCTAssertEqual(r.taker, 1)
        XCTAssertEqual(r.m.sections.map(\.w), [450, 750, 600])
        // the last one's neighbour is on its left
        XCTAssertEqual(dzcSecResize(m, 2, 700).m.sections.map(\.w), [600, 500, 700])
        XCTAssertFalse(dzcSecResize(m, 0, 1100).ok)
        XCTAssertEqual(dzcSecMax(m, 0), 1050)
    }

    func testSectionsCopyDeleteAndMove() {
        let m = wardrobe([600, 600, 600])
        XCTAssertEqual(dzcSecCopy(m, 0)?.sections.map(\.w), [450, 450, 450, 450])
        XCTAssertEqual(dzcSecDelete(m, 1)?.sections.map(\.w), [1200, 600])
        XCTAssertNil(dzcSecDelete(wardrobe([900]), 0))
        var n = m
        n.sections[0].inserts = [Insert("rail", pos: 1500)]
        let moved = dzcSecMove(n, 0, to: 2)
        XCTAssertEqual(moved.sections.last?.inserts.first?.kind, "rail")
        XCTAssertEqual(dzcSecSlot(m, 0, gx: 1150), 2)
        XCTAssertEqual(dzcSecCount(m, 4, ws).sections.count, 4)
    }

    func testASectionsType() {
        let s = Section(600)
        XCTAssertEqual(dzcSecType(dzcSecRetype(s, "d1")), "d1")
        XCTAssertEqual(dzcSecRetype(s, "mirror").face, "mirror")
        XCTAssertEqual(dzcSecRetype(s, "open").fronts.kind, "open")
    }
}
