import XCTest
import CoreGraphics
@testable import METRX

/// Designer C's fixes after the Android emulator review (28 Oct 2026): the right edge takes room from the right first,
/// toasts fill every placeholder, labels stay inside the drawing, tool labels break between words, 3D taps meet what
/// is drawn (the view's own projection) and pick carcasses.
final class DesignerCFixesTests: XCTestCase {
    private let ws = Workshop()

    private func unit(_ id: String, _ w: Int, _ kind: String = "base") -> Module {
        var m = template(kind, ws, "A", w)
        m.id = id
        return m
    }

    private func kitchen(_ ms: [Module]) -> Furniture { Furniture(id: "k", kind: "kitchen", walls: ["A"], modules: ms) }

    private func low(_ f: Furniture) -> [Module] { dzcRowMods(f, DzcRow(wall: "A", upper: false)) }

    /* ---------------- the right edge: the right side first ---------------- */

    func testGrowingTakesTheGapOnTheRightNotTheNearerOneOnTheLeft() {
        // a gap right beside on the left, one two places away on the right: the right one gives
        let f = kitchen([unit("g1", 50, "fillerLow"), unit("a", 600), unit("b", 600), unit("g2", 100, "fillerLow")])
        let r = dzcResize(f, "a", 650, avail: 1350, ws: ws)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.taker, "g2"); XCTAssertFalse(r.left)
        XCTAssertEqual(low(r.f).map(\.w), [50, 650, 600, 50])
    }

    func testTheRowsFreeEndBeforeTheUnitOnTheRight() {
        let f = kitchen([unit("a", 600), unit("b", 600)])
        let r = dzcResize(f, "a", 700, avail: 1400, ws: ws)
        XCTAssertEqual(r.taker, ""); XCTAssertFalse(r.left)
        XCTAssertEqual(low(r.f).map(\.w), [700, 600])
    }

    func testOnlyWhenNothingOnTheRightCanTheLeftGivesAndSaysSo() {
        // the right: an appliance, no free end; the left: a filler
        let f = kitchen([unit("g", 100, "fillerLow"), unit("a", 600), unit("d", 600, "dishwasher")])
        let r = dzcResize(f, "a", 700, avail: 1300, ws: ws)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.taker, "g"); XCTAssertTrue(r.left)
        XCTAssertEqual(low(r.f).map(\.id), ["a", "d"])
        // the pure rule: right side first, then the left
        let row = low(f)
        XCTAssertEqual(dzcAbsorber(row, 1, 100, tail: 0), DzcAbsorb(j: 0, left: true))
        XCTAssertEqual(dzcAbsorber(row, 1, 100, tail: 200), DzcAbsorb(j: -1, left: false))
        // shrinking never goes left: the free end grows
        XCTAssertEqual(dzcAbsorber(row, 1, -100, tail: 0), DzcAbsorb(j: -1, left: false))
    }

    func testTheRightGapTooSmallTheUnitOnTheRightGives() {
        let f = kitchen([unit("a", 600), unit("b", 600)])
        let r = dzcResize(f, "a", 750, avail: 1200, ws: ws)
        XCTAssertEqual(r.taker, "b"); XCTAssertFalse(r.left)
        XCTAssertEqual(low(r.f).map(\.w), [750, 450])
    }

    func testASectionsRightNeighbourFirstThenTheLeft() {
        var m = wardrobeTemplate(ws, "A", 0, 1350, 2400, builtIn: false)
        m.sections = [Section(600), Section(600), Section(150)]
        // the middle one grows: the right one is at its narrowest, so the left one gives
        XCTAssertEqual(dzcSecTaker(m, 1, 100), 0)
        XCTAssertEqual(dzcSecResize(m, 1, 700).m.sections.map(\.w), [500, 700, 150])
        // shrinking: the right one takes it
        XCTAssertEqual(dzcSecTaker(m, 1, -100), 2)
        XCTAssertEqual(dzcSecMax(m, 1), 1050)
    }

    /* ---------------- toasts: every placeholder filled ---------------- */

    private func filled(_ key: String, _ vars: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(Strings.has(key), key, file: file, line: line)
        for l in Lang.allCases {
            let s = Strings.t(key, l, vars)
            XCTAssertFalse(s.contains("{"), "\(key) \(l): \(s)", file: file, line: line)
        }
    }

    func testTheDeleteToastSaysTheGapLeft() {
        // a unit deleted beside an empty space: the "+" left is both widths together
        var sp = template("spaceLow", ws, "A", 300)
        sp.id = "s"
        let f = kitchen([unit("a", 600), sp, unit("b", 600)])
        let v = dzcGapLeft(f, f.modules[0], ws)
        XCTAssertEqual(v, 900)
        filled("dzc.deleted", ["m": "Eshikli 600", "v": v, "w": 600])
        XCTAssertTrue(Strings.t("dzc.deleted", .en, ["m": "x", "v": v]).contains("900"))
        // alone: its own width
        let g = kitchen([unit("a", 600), unit("b", 600)])
        XCTAssertEqual(dzcGapLeft(g, g.modules[1], ws), 600)
    }

    func testTheToastsTheDesignersSayAreFilled() {
        filled("dzc.closed", ["v": 400])
        filled("dzc.closed0", [:])
        filled("dzc.closedTo", ["t": "x", "a": 1, "b": 2])
        filled("dzc.decorAll", ["c": "Oq", "d": "Oq"])
        filled("dzc.decorN", ["c": "Oq", "d": "Oq", "n": 2])
        filled("dzc.decorOne", ["c": "Oq", "d": "Oq", "m": "x"])
        filled("dzc.decorRowLow", ["c": "Oq"])
        filled("dzc.decorRowUp", ["c": "Oq"])
        filled("dzc.fit", ["v": 120])
        filled("dzc.fixed", ["m": "x"])
        filled("dzc.secMoved", ["n": 1, "v": 2, "a": 2])
        filled("dzc.softOn", ["m": "x"])
        filled("dzc.softOff", ["m": "x"])
        filled("dzc.wTook", ["m": "x", "a": 1, "b": 2, "t": "y", "c": 3, "d": 4])
        filled("dzc.secWDone", ["s": 1, "a": 1, "b": 2, "t": 2, "c": 3, "d": 4])
        filled("dzc.alignedTo", ["m": "x", "a": 1, "b": 2])
        filled("dzc.onlyF", ["f": "x"])
        filled("dzc.noRoom", ["f": 100, "n": 600])
        filled("dzc.spaceSmall", ["g": 100, "n": 600])
        filled("dzc.noCopy", ["f": 100, "n": 600])
        filled("dzc.maxW", ["v": 600])
        filled("dzc.minW", ["v": 150])
        filled("dzc.fromLeft", [:])
        for k in ["dzc.teachI1", "dzc.teachI2", "dzc.teach3", "dzc.tap3d"] { XCTAssertTrue(Strings.has(k), k) }
    }

    /* ---------------- labels inside the drawing, tool labels by words ---------------- */

    func testALabelAtTheEdgeIsMovedInside() {
        let area = CGSize(width: 390, height: 500), sz = CGSize(width: 180, height: 26)
        XCTAssertEqual(dzcClampCentre(10, 200, sz, area, 6).x, 96)
        XCTAssertEqual(dzcClampCentre(385, 200, sz, area, 6).x, 294)
        XCTAssertEqual(dzcClampCentre(200, 200, sz, area, 6), CGPoint(x: 200, y: 200))
        XCTAssertEqual(dzcClampCentre(200, 600, sz, area, 6).y, 481)
        // wider than the drawing: centred
        XCTAssertEqual(dzcClampCentre(0, 0, CGSize(width: 500, height: 26), area, 6).x, 195)
    }

    func testAToolLabelShrinksUntilItsLongestWordFits() {
        // a word fits when it is at most 6 letters a point of size over 10
        let fits: (String, CGFloat) -> Bool = { w, s in CGFloat(w.count) * s <= 60 }
        XCTAssertEqual(dzcLabelSize("Rang", 11, 8.5, 0.5, fits), 11)
        XCTAssertEqual(dzcLabelSize("Qo‘shimcha ish", 11, 8.5, 0.5, fits), 8.5)
        XCTAssertEqual(dzcLabelSize("Tutqich bor", 11, 8.5, 0.5, fits), 8.5)
        XCTAssertEqual(dzcLabelSize("Eshik turi", 11, 8.5, 0.5, fits), 11)
        XCTAssertEqual(dzcLabelSize("Chuqurl", 11, 8.5, 0.5, fits), 8.5)
        XCTAssertEqual(dzcLabelSize("Tekisla", 9, 8, 0.5, fits), 8.5)
    }

    /* ---------------- 3D: the tap's ray and the carcasses ---------------- */

    func testTheRayComesFromTheViewsOwnProjection() {
        // a projection 400 pt a metre sideways and 300 up (any field of view): the point 0.25 m right, 0.1 m up
        let p0 = CGPoint(x: 200, y: 400), ps = CGPoint(x: 240, y: 400), pu = CGPoint(x: 200, y: 370)
        guard let o = rayOffsetsFrom(300, 370, p0, ps, pu, 0.1) else { return XCTFail("no ray") }
        XCTAssertEqual(o.0, 0.25, accuracy: 1e-9)
        XCTAssertEqual(o.1, 0.1, accuracy: 1e-9)
        XCTAssertNil(rayOffsetsFrom(1, 1, p0, p0, p0, 0.1))
    }

    func testCarcassesArePickedAndHideWhatIsBehind() {
        let w = WallBasis(ox: 0, oz: 0, ux: 1, uz: 0, nx: 0, nz: 1, len: 3)
        // an open shelf unit (no fronts) and a filler: each a carcass box
        var open = unit("o", 600)
        open.fronts = Fronts("open", 0)
        let fl = unit("f", 50, "fillerLow")
        var placed = fl
        placed.x = 600
        let picks = bodyPicks(w, open, ws) + bodyPicks(w, placed, ws)
        XCTAssertEqual(picks.map(\.key), ["o:body", "f:body"])
        // a ray from the room at the shelf's middle meets it
        let eye = V3(0.3, 0.5, 3), dir = V3(0, 0, -1)
        XCTAssertEqual(rayPicks(picks, eye, dir).first, "o:body")
        // a door on a carcass's face wins over the carcass it closes
        let door = Pick(key: "o:f0", box: Obb(o: V3(0, 0.1, Double(open.d) / 1000), a: V3(0.6, 0, 0), b: V3(0, 0.7, 0), c: V3(0, 0, 0.018)))
        XCTAssertEqual(rayPicks(picks + [door], eye, dir).first, "o:f0")
        // a door behind a carcass (seen through it) is not what a tap finds
        let behind = Pick(key: "x:f0", box: Obb(o: V3(0, 0.1, -0.2), a: V3(0.6, 0, 0), b: V3(0, 0.7, 0), c: V3(0, 0, 0.018)))
        XCTAssertEqual(rayPicks(picks + [behind], eye, dir).first, "o:body")
        XCTAssertTrue(isBodyPick("o:body")); XCTAssertFalse(isBodyPick("o:f0"))
        // a wardrobe: a carcass a section
        var wd = wardrobeTemplate(ws, "A", 0, 1200, 2400, builtIn: false)
        wd.id = "w"
        wd.sections = [Section(600), Section(600)]
        XCTAssertEqual(bodyPicks(w, wd, ws).map(\.key), ["w:s0:body", "w:s1:body"])
    }

    func testAnOpenFrontIsOutlinedByItsCarcass() {
        XCTAssertEqual(selKeys(["k1:f0"], [], inside: false), ["k1:f0"])
        XCTAssertEqual(selKeys(["k1:f0"], ["k1:f0"], inside: false), ["k1:body"])
        XCTAssertEqual(selKeys(["w:s1:f0"], [], inside: true), ["w:s1:body"])
        XCTAssertEqual(selKeys(["w:slide1"], ["w:slide1"], inside: false), ["w:*"])
        XCTAssertEqual(selKeys(["k1:body"], ["k1:body"], inside: true), ["k1:body"])
    }
}
