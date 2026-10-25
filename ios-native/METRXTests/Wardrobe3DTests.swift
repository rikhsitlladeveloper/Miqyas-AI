import XCTest
@testable import METRX

/// Wardrobes in the modern 3D ("modern furniture 3D" part 5, 25 Oct 2026; Geo/Wardrobe3D.swift and FBuilder.wardrobe):
/// a kupe's profiles in the handle colour, its tracks and sliding doors, the mirror's tint, the middle door's fill, the
/// LED only when chosen, long handles on tall doors, the cornice and the row to the ceiling, a vitrina's glass, chrome
/// rails, legs, and the 2D drawings' boxes.
final class Wardrobe3DTests: XCTestCase {
    private let ws = Workshop()
    private let rgb: (String) -> Int = { _ in 0xCDBFAE }
    private let noTex: (String) -> String? = { _ in nil }
    private func near(_ a: Double, _ b: Double, _ e: Double = 1e-6) -> Bool { abs(a - b) < e }

    /// A built-in kupe of three doors, 2400 × 2500 × 600, four sections.
    private func kupe() -> Furniture {
        var k = newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws)
        k.id = "s"
        return k
    }
    /// A hinged wardrobe of two sections with one door each, 1000 × h × 600.
    private func hinged(_ h: Int = 2200) -> Furniture {
        var f = newFreeWardrobe("Shkaf", "h2", 1000, h, 600, false, "door", ws)
        f.id = "h"
        return f
    }
    private func look(_ f: Furniture, _ fn: (inout PieceLook) -> Void) -> Furniture { withLook(f) { l in var n = l; fn(&n); return n } }
    private func build(_ f: Furniture, _ detail: Quality3 = .high, open: Set<String> = [], bare: Bool = false, ceilH: Int = 2700) -> Furn3D {
        furniture3D([f], buildShell([freeRoom(f)], single: true).bases, ws, rgb, open, bare: bare, tex: noTex, detail: detail, ceilH: ceilH)
    }
    private func looks(_ f: Furniture) -> [String: Look] { pieceLooks(f, rgb, noTex, MAT_PRESETS) }
    /// The faces drawn in look key of f.
    private func faces(_ d: Furn3D, _ f: Furniture, _ key: String) -> [Face3] {
        let l = looks(f)[key]
        return d.parts.filter { $0.look == l }.flatMap(\.faces)
    }
    private func top(_ d: Furn3D) -> Double { d.parts.flatMap(\.faces).flatMap(\.pts).map(\.y).max() ?? 0 }

    /* ---------------- kupe ---------------- */

    func testKupeProfilesTakeTheHandleColour() {
        let gold = look(kupe()) { $0.hcol = "gold" }
        XCTAssertEqual(looks(gold)["frame"], handleLook("gold"))
        XCTAssertEqual(looks(gold)["frame"]?.metallic, 1)
        // three doors of two uprights, a top and a bottom rail and the split rail; the two tracks
        XCTAssertEqual(gold.modules[0].slide?.n, 3)
        XCTAssertEqual(faces(build(gold), gold, "frame").count, 3 * 5 * 6 + 2 * 6)
        // black profiles: the painted black; none chosen: aluminium (the metal look)
        let black = look(kupe()) { $0.hcol = "black" }
        XCTAssertEqual(looks(black)["frame"], handleLook("black"))
        let plain = kupe()
        XCTAssertEqual(looks(plain)["frame"], looks(plain)["metal"])
        XCTAssertFalse(faces(build(plain), plain, "frame").isEmpty)
        // seeing inside: the doors go, the tracks stay
        XCTAssertEqual(faces(build(gold, bare: true), gold, "frame").count, 2 * 6)
    }

    func testKupeDoorsRunInTwoTracksAndSlide() {
        let k = kupe()
        let d = build(k)
        func pick(_ d: Furn3D, _ j: Int) -> Obb { d.picks.first { $0.key.hasSuffix(":slide\(j)") }!.box }
        let p0 = pick(d, 0), p1 = pick(d, 1)
        let u = p0.a.unit, n = p0.c.unit
        // each door overlaps the next by SLIDE_OV, the next one 45 mm further out
        XCTAssertTrue(near((p0.o + p0.a).dot(u) - p1.o.dot(u), Double(SLIDE_OV) / 1000))
        XCTAssertTrue(near((p1.o - p0.o).dot(n), 0.045))
        XCTAssertTrue(near(p0.c.len, KUPE_PD / 1000))
        // a tapped door slides one step over its neighbour (a door less the overlap)
        let key = d.keys.first { $0.hasSuffix(":slide2") }!
        let moved = build(k, open: [key])
        let step = Double(slideDoor(k.modules[0], ws.t).0 - SLIDE_OV) / 1000
        XCTAssertTrue(near((pick(d, 2).o - pick(moved, 2).o).dot(u), step))
        XCTAssertEqual(d.parts.count, moved.parts.count)
        // the split rail: on a door from 1400 tall, 380 under its top
        XCTAssertNil(kupeSplit(1399))
        XCTAssertEqual(kupeSplit(2300), 2300 - KUPE_SPLIT_TOP)
    }

    func testTheMiddleDoorsFill() {
        let k = kupe()
        // the fills by panel: a mirror or lacobel below the split, the upper fronts' board above it
        XCTAssertEqual(kupeFills("mirror", split: true).low, "mirror")
        XCTAssertEqual(kupeFills("mirror", split: true).up, "frontUp")
        XCTAssertEqual(kupeFills("glass", split: false).low, "lacobel")
        XCTAssertNil(kupeFills("glass", split: false).up)
        XCTAssertEqual(kupeFills("ldsp", split: true).low, "front")
        // a mirror on the middle door only, under its split
        let mir = withMiddleFill(k, "mirror")
        XCTAssertEqual(middleFill(mir), "mirror")
        let d = build(mir)
        let door = d.picks.first { $0.key.hasSuffix(":slide1") }!.box
        let pts = faces(d, mir, "mirror").flatMap(\.pts)
        XCTAssertFalse(pts.isEmpty)
        for q in pts {
            let t = (q - door.o).dot(door.a) / door.a.dot(door.a)
            XCTAssertTrue(t > -1e-6 && t < 1 + 1e-6)
        }
        XCTAssertTrue((pts.map(\.y).max() ?? 9) < door.o.y + door.b.len - KUPE_SPLIT_TOP / 1000 + 1e-6)
        XCTAssertTrue(faces(d, mir, "lacobel").isEmpty)
        // lacobel: painted glass, mirror-smooth, no mirror
        let lac = withMiddleFill(k, "glass")
        XCTAssertEqual(middleFill(lac), "glass")
        XCTAssertFalse(faces(build(lac), lac, "lacobel").isEmpty)
        XCTAssertTrue(faces(build(lac), lac, "mirror").isEmpty)
        XCTAssertEqual(looks(lac)["lacobel"]?.clearcoat, 1)
        XCTAssertTrue((looks(lac)["lacobel"]?.roughness ?? 1) < 0.1)
        // the board: neither
        let b = withMiddleFill(k, "ldsp")
        XCTAssertTrue(faces(build(b), b, "mirror").isEmpty && faces(build(b), b, "lacobel").isEmpty)
        // a new piece of a preset gets the mirror on its middle door
        XCTAssertEqual(middleFill(withPreset(k, "twotone", fresh: true)), "mirror")
    }

    func testATwoToneKupeTakesTheUpperBoardOverTheSplit() {
        var k = kupe()
        k.mats.frontUp = "ag_white"
        let rgb2: (String) -> Int = { $0 == "ag_white" ? 0xF2F2EF : 0xCDBFAE }
        let l = pieceLooks(k, rgb2, noTex, MAT_PRESETS)
        XCTAssertNotEqual(l["frontUp"], l["front"])
        let d = furniture3D([k], buildShell([freeRoom(k)], single: true).bases, ws, rgb2, [], tex: noTex)
        let up = d.parts.filter { $0.look == l["frontUp"] }.flatMap(\.faces).flatMap(\.pts).map(\.y)
        let low = d.parts.filter { $0.look == l["front"] }.flatMap(\.faces).flatMap(\.pts).map(\.y)
        XCTAssertFalse(up.isEmpty); XCTAssertFalse(low.isEmpty)
        // the upper fronts' board over the split rail, the lower one under it
        XCTAssertTrue((up.min() ?? 0) > (low.max() ?? 9) - 1e-6)
    }

    func testTheMirrorTakesItsTint() {
        for (t, hex) in [("bronze", 0xC2A487), ("graphite", 0x9A9DA1), ("silver", 0xBCC0C4)] {
            let f = withMiddleFill(look(kupe()) { $0.mirror = t }, "mirror")
            let m = looks(f)["mirror"]!
            XCTAssertEqual(m.rgb, hex, t)
            XCTAssertEqual(m.metallic, 1); XCTAssertTrue(m.roughness <= 0.05)
            XCTAssertFalse(faces(build(f), f, "mirror").isEmpty, t)
        }
        // a weak phone: duller (Look.lowered)
        XCTAssertEqual(looks(look(kupe()) { $0.mirror = "bronze" })["mirror"]!.lowered().metallic, 0.35)
        // a hinged mirror door: the mirror on the board door
        var h = look(hinged()) { $0.mirror = "graphite" }
        h.modules[0].sections[0].face = "mirror"
        XCTAssertFalse(faces(build(h), h, "mirror").isEmpty)
    }

    /* ---------------- LED ---------------- */

    func testTheLedOnlyWhenOn() {
        let k = kupe()
        XCTAssertTrue(faces(build(k), k, "led").isEmpty)
        XCTAssertTrue(faces(build(k), k, "glow").isEmpty)
        let on = look(k) { $0.led = true }
        let d = build(on)
        // a strip in each section, its glow down the back
        XCTAssertEqual(faces(d, on, "led").count, 6 * on.modules[0].sections.count)
        XCTAssertFalse(faces(d, on, "glow").isEmpty)
        // a weak phone: the strip, no glow
        XCTAssertTrue(faces(build(on, .low), on, "glow").isEmpty)
        XCTAssertFalse(faces(build(on, .low), on, "led").isEmpty)
        // under the hat shelf over the rail; a section of shelves only, under its top
        let s = on.modules[0].sections[0]
        let rail = s.inserts.first { $0.kind == "rail" }!.pos
        XCTAssertEqual(secLedY(s, 2000), s.inserts.filter { $0.kind == "shelf" && $0.pos > rail }.map(\.pos).min())
        XCTAssertEqual(secLedY(Section(600, inserts: [Insert("shelf", pos: 300)]), 2000), 2000)
        // a hinged wardrobe too; a kitchen's LED stays its own (KExtras.led)
        let h = look(hinged()) { $0.led = true }
        XCTAssertFalse(faces(build(h), h, "led").isEmpty)
    }

    /* ---------------- handles ---------------- */

    func testLongHandlesOnTallDoors() {
        let f = hinged()
        func span(_ g: Furniture) -> Double {
            let ys = faces(build(g), g, "handle").flatMap(\.pts).map(\.y)
            return (ys.max() ?? 0) - (ys.min() ?? 0)
        }
        // the doors are over 1400 tall: long verticals take the 1024
        let lg = withHandleType(f, "long")
        XCTAssertEqual(handleType(lg), "long")
        XCTAssertTrue(near(span(lg), 1.024), "\(span(lg))")
        // the usual skoba: 168
        XCTAssertTrue(near(span(f), 0.168), "\(span(f))")
        // a lower one's doors (under 1400) take the 640
        let low = withHandleType(hinged(1300), "long")
        XCTAssertTrue(near(span(low), 0.64), "\(span(low))")
        // a door left without a handle keeps none; push latches: none at all; knobs drawn
        var nh = lg
        nh.modules[0].sections[0].noHandle = [0]
        XCTAssertEqual(faces(build(nh), nh, "handle").count * 2, faces(build(lg), lg, "handle").count)
        let push = withHandleType(f, "push")
        XCTAssertTrue(faces(build(push), push, "handle").isEmpty)
        let kn = withHandleType(f, "knob")
        XCTAssertFalse(faces(build(kn), kn, "handle").isEmpty)
        // in the handle colour
        let gold = look(lg) { $0.hcol = "gold" }
        XCTAssertEqual(looks(gold)["handle"], handleLook("gold"))
        XCTAssertFalse(faces(build(gold), gold, "handle").isEmpty)
    }

    /* ---------------- the crown ---------------- */

    func testCorniceAndCeilingHeights() {
        let k = kupe()
        let h = Double(outerH(k.modules[0], ws)) / 1000
        XCTAssertTrue(near(top(build(k)), h))
        let c = withCrown(k, "cornice")
        XCTAssertEqual(crownOf(c), "cornice")
        XCTAssertTrue(near(top(build(c)), h + 0.076))
        let up = withCrown(k, "ceiling")
        XCTAssertEqual(crownOf(up), "ceiling")
        XCTAssertTrue(near(top(build(up, ceilH: 2700)), 2.696))
        XCTAssertTrue(near(top(build(up, ceilH: 3000)), 2.996))
        // the rules: the cornice only under the ceiling, the row only with room for it, a low box none
        XCTAssertEqual(wardCrown("cornice", 2500, 2700), 76)
        XCTAssertEqual(wardCrown("cornice", 2650, 2700), 0)
        XCTAssertEqual(wardCrown("ceiling", 2500, 2700), 196)
        XCTAssertEqual(wardCrown("ceiling", 2620, 2700), 0)
        XCTAssertEqual(wardCrown("cornice", 900, 2700), 0)
        XCTAssertEqual(wardCrown("", 2500, 2700), 0)
        // a hinged wardrobe's row to the ceiling has its fronts' handles at their bottom
        let hu = withCrown(hinged(), "ceiling")
        XCTAssertTrue(near(top(build(hu)), 2.696))
        XCTAssertTrue((faces(build(hu), hu, "handle").flatMap(\.pts).map(\.y).max() ?? 0) > 2.2)
    }

    func testOnlyTheTallestBoxesTakeTheCrown() {
        // a stenka: its two tall cabinets, not the shelf hung between them
        let s = withCrown(pieceOf(fModel("stenka")!, [:], ws, "Stenka"), "cornice")
        let tall = Double(s.modules.map { outerH($0, ws) + $0.elev }.max() ?? 0) / 1000
        let d = build(s)
        XCTAssertTrue(near(top(d), tall + 0.076))
        // nothing of the fronts' board starts between the hung shelf's top and the talls' (no cornice there)
        let starts = faces(d, s, "frontUp").map { $0.pts.map(\.y).min() ?? 0 }
        XCTAssertFalse(starts.contains { $0 > 1.79 && $0 < 1.81 })
        XCTAssertTrue(starts.contains { near($0, tall) })
    }

    /* ---------------- vitrina, inside, legs ---------------- */

    func testAVitrinasGlassDoorsShelvesAndLight() {
        let v = pieceOf(fModel("vitrina")!, [:], ws, "Vitrina")
        let d = build(v)
        XCTAssertFalse(faces(d, v, "clear").isEmpty)
        XCTAssertFalse(faces(d, v, "shelfGlass").isEmpty)
        XCTAssertFalse(faces(d, v, "led").isEmpty)
        XCTAssertFalse(faces(d, v, "glow").isEmpty)
        XCTAssertTrue(faces(build(v, .low), v, "glow").isEmpty)
        // fluted glass when chosen, the frames in the handle colour
        let fl = look(v) { $0.fglass = true; $0.hcol = "black" }
        XCTAssertFalse(faces(build(fl), fl, "fglass").isEmpty)
        XCTAssertTrue(faces(build(fl), fl, "clear").isEmpty)
        XCTAssertEqual(looks(fl)["frame"], handleLook("black"))
        XCTAssertFalse(faces(build(fl), fl, "frame").isEmpty)
    }

    func testChromeRailsDrawersInTheFrontsAndLegs() {
        let f = hinged()
        let chrome = looks(f)["chrome"]!
        XCTAssertEqual(chrome.metallic, 1); XCTAssertTrue(chrome.roughness <= 0.06)
        XCTAssertFalse(faces(build(f), f, "chrome").isEmpty)
        // an office cabinet's drawers behind its door: seeing inside, their faces in the fronts' board stay
        let o = newFreeCabinet("Ofis", "officeC", 800, 2000, 400, ws)
        XCTAssertTrue(o.modules[0].sections.contains { s in s.fronts.kind == "door" && s.inserts.contains { $0.kind == "drawer" } })
        XCTAssertFalse(faces(build(o, bare: true), o, "front").isEmpty)
        // a cabinet on legs: round legs from the floor, in the handle colour
        let p = look(newFreeCabinet("Penal", "pantry", 600, 2100, 600, ws)) { $0.hcol = "gold" }
        XCTAssertTrue(p.modules[0].legs)
        let legs = faces(build(p), p, "legs").flatMap(\.pts).map(\.y)
        XCTAssertTrue(near(legs.min() ?? 1, 0))
        XCTAssertEqual(looks(p)["legs"], handleLook("gold"))
    }

    /* ---------------- the 2D drawings, opening ---------------- */

    func testThe2DDrawingsGetOnlyBoxesAndDoorsKeepTheParts() {
        let k = withCrown(withMiddleFill(look(kupe()) { $0.led = true; $0.style = "fluted"; $0.hcol = "gold"; $0.mirror = "bronze" }, "mirror"), "ceiling")
        let v = look(pieceOf(fModel("vitrina")!, [:], ws, "Vitrina")) { $0.fglass = true; $0.style = "shaker" }
        var h = withCrown(withHandleType(look(hinged()) { $0.led = true; $0.style = "shaker" }, "long"), "cornice")
        h.modules[0].legs = true
        for f in [k, v, h] {
            let flat = build(f, .flat)
            XCTAssertTrue(flat.parts.allSatisfy { $0.faces.count % 6 == 0 }, f.name)
            XCTAssertTrue(flat.parts.allSatisfy { $0.faces.allSatisfy { $0.pts.count == 4 } }, f.name)
            let shut = build(f)
            XCTAssertEqual(shut.parts.count, build(f, open: Set(shut.keys)).parts.count, f.name)
            for p in shut.parts { for fc in p.faces {
                XCTAssertTrue(abs((fc.grain ?? V3(0, 0, 0)).dot(fc.n)) < 1e-6)
                XCTAssertTrue(fc.pts.allSatisfy { abs(($0 - fc.pts[0]).dot(fc.n)) < 1e-9 })
                XCTAssertTrue(fc.pts.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            } }
        }
    }

    func testTheGalleryCardShowsTheKupe() {
        let k = look(kupe()) { $0.hcol = "chrome" }
        let s = cardShell(k, ws, MAT_PRESETS, .high)
        let fr = pieceLooks(k, { id in rgbOf(MAT_PRESETS.first { $0.id == id }?.rgb ?? "#F5F5F2") }, { id in MAT_PRESETS.first { $0.id == id }?.tex }, MAT_PRESETS)["frame"]
        XCTAssertEqual(fr, handleLook("chrome"))
        XCTAssertTrue(s.parts.contains { $0.look == fr && !$0.faces.isEmpty })
    }
}
