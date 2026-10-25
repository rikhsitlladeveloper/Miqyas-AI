import XCTest
@testable import METRX

/// The prices of a wardrobe's crown, a bed's metal legs and its soft wall panel by its drawn area (Core/PieceLook.swift;
/// Android CrownBedPriceTest, the same cases and numbers).
final class CrownBedPriceTests: XCTestCase {
    private let ws = Workshop()

    private func cost(_ f: Furniture) -> Cost { costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false) }
    private func line(_ f: Furniture, _ key: String) -> CostLine? {
        let ls = cost(f).lines.filter { $0.key == key }
        return ls.count == 1 ? ls[0] : nil
    }
    private func look(_ f: Furniture, _ fn: (inout PieceLook) -> Void) -> Furniture { withLook(f) { l in var n = l; fn(&n); return n } }

    /// A built-in sliding wardrobe 2400 × 2500 × 600 without a room (no side panels: it stands wall to wall).
    private func kupe() -> Furniture {
        var k = newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws)
        k.id = "s"
        return k
    }

    /// A hinged wardrobe 1800 × 2200 × 600 with its side panels, in a measured room, 500 from the wall's corner.
    private func shkaf() -> Furniture {
        var f = newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws)
        f.id = "w"; f.roomId = "r"
        f.modules = f.modules.map { m in var x = m; x.id = "wm"; x.x = 500; return x }
        return f
    }

    private func bed(_ kind: String = "legs", mw: Int = 1600, hb: Int = 1100, x: Int = 1000, room: String? = "r") -> Furniture {
        Furniture(id: "b", kind: "wardrobe", roomId: room, walls: ["A"],
                  modules: [Module(id: "bm", type: "bed", w: mw + 100, h: 450, d: 2100, x: x, wall: "A", opt: ItemOpt(bed: kind, mw: mw, hb: hb))], type: "bed")
    }

    func testAWardrobesCorniceByTheMetreWithItsFreeEnds() {
        // the built-in kupe: along its top only (2.4 m, 3 whole metres) at the kitchen's cornice item
        let k = withCrown(kupe(), "cornice")
        XCTAssertEqual(lookHardware(k, ws)["cornice"], 2400)
        XCTAssertEqual(line(k, "cornice")?.qty, 3); XCTAssertEqual(line(k, "cornice")?.price, 65000)
        XCTAssertEqual(line(k, "cornice")?.amount, 195000)
        XCTAssertNil(line(k, "wdCeil"))
        // with its side panels, off the corner, its far end not known to the price: both ends turn back (600 + 2 × 38)
        let s = withCrown(shkaf(), "cornice")
        XCTAssertEqual(crownFreeEnds(s, s.modules[0], nil), 2)
        XCTAssertEqual(lookHardware(s, ws)["cornice"], 1800 + 2 * 676)
        XCTAssertEqual(line(s, "cornice")?.amount, 260000)
        // its far end at the wall: one free end; a neighbour box at its right: one; standing free in the room: two
        XCTAssertEqual(crownFreeEnds(s, s.modules[0], 2320), 1)
        var two = s
        var m2 = s.modules[0]; m2.id = "wm2"; m2.x = 2300
        two.modules.append(m2)
        XCTAssertEqual(two.modules.map { crownFreeEnds(two, $0, nil) }, [1, 1])
        XCTAssertEqual(wardCorniceMm(two, ws), 2 * 1800 + 2 * 676)
        var posed = s
        posed.roomId = nil; posed.pose = Pose("A", 0, 900)
        XCTAssertEqual(crownFreeEnds(posed, s.modules[0], 1820), 2)
        // the same wardrobe without a room: its made-up room is wall to wall, so along the top only
        let free = withCrown(newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws), "cornice")
        XCTAssertEqual(pieceWallLen(free, "A"), 1820)
        XCTAssertEqual(lookHardware(free, ws)["cornice"], 1800)
    }

    func testAWardrobesRowUpToTheCeilingByTheMetreOfItsWidth() {
        let k = withCrown(kupe(), "ceiling")
        XCTAssertEqual(lookHardware(k, ws)["wdCeil"], 2400)
        let c = line(k, "wdCeil")!
        XCTAssertEqual(c.qty, 3); XCTAssertEqual(c.unit, "m"); XCTAssertEqual(c.price, 800000); XCTAssertEqual(c.amount, 2400000)
        XCTAssertNil(line(k, "cornice")); XCTAssertNil(line(k, "ceilUnit"))
        // an editable item of its own, by the metre
        XCTAssertEqual(hwUnit("wdCeil"), "m"); XCTAssertTrue(HW_PRESETS.contains { $0.id == "wdCeil" && $0.kind == "wdCeil" && $0.price == "800000" })
        // only boxes standing on the floor, 1800 high or more; not a gorka's (its own cornice), not a kitchen's
        var low = k
        low.modules = k.modules.map { m in var x = m; x.h = 1700; return x }
        XCTAssertTrue(crownBoxes(low, ws).isEmpty); XCTAssertNil(lookHardware(low, ws)["wdCeil"])
        var hungBox = k
        hungBox.modules = k.modules.map { m in var x = m; x.elev = 300; x.legs = false; return x }
        XCTAssertTrue(crownBoxes(hungBox, ws).isEmpty)
        var gorka = k
        gorka.type = "gorka"
        XCTAssertTrue(crownBoxes(withCrown(gorka, "cornice"), ws).isEmpty)
        let kitchen = newFreeKitchen("Oshxona 1", "I", "I", [3000], 0, 2700, ws)
        XCTAssertNil(lookHardware(withCrown(kitchen, "ceiling"), ws)["wdCeil"])
        XCTAssertTrue((lookHardware(withCrown(kitchen, "ceiling"), ws)["ceilUnit"] ?? 0) > 0)
        // no crown: neither
        XCTAssertTrue(["cornice", "wdCeil"].allSatisfy { line(withCrown(k, ""), $0) == nil })
    }

    func testABedOnMetalLegs() {
        let plain = bed()
        // its plain legs as before: four and one in the middle of a wide bed
        XCTAssertEqual(hardware([plain], ws)["leg"], 5); XCTAssertNil(hardware([plain], ws)["legMetal"])
        let metal = look(plain) { $0.legs = true }
        XCTAssertEqual(bedMetalLegs(metal, metal.modules[0]), 4)
        XCTAssertNil(hardware([metal], ws)["leg"])
        XCTAssertEqual(line(metal, "legMetal")?.qty, 4); XCTAssertEqual(line(metal, "legMetal")?.amount, 180000)
        // six under a bed wider than 1600
        let wide = look(bed(mw: 1800)) { $0.legs = true }
        XCTAssertEqual(hardware([wide], ws)["legMetal"], 6); XCTAssertEqual(line(wide, "legMetal")?.amount, 270000)
        // none on a bed with drawers or a lift-up base
        for k in ["drawers", "lift"] {
            let b = look(bed(k)) { $0.legs = true }
            XCTAssertEqual(bedMetalLegs(b, b.modules[0]), 0, k); XCTAssertNil(line(b, "legMetal"), k)
        }
    }

    func testABedsWallPanelByItsDrawnArea() {
        // 400 past each side, from 80 up to 1380: (1700 + 800) × 1300
        let on = look(bed()) { $0.panel = true }
        let p = bedPanelOf(on, on.modules[0])!
        XCTAssertEqual(p, PanelSpan(a0: -400, a1: 2100, y0: 80, y1: 1380))
        XCTAssertEqual(lookHardware(on, ws)["softPanel"], 2500 * 1300)
        XCTAssertEqual(line(on, "softPanel")!.qty, 3.25, accuracy: 1e-9); XCTAssertEqual(line(on, "softPanel")?.amount, 2437500)
        // a tall headboard: 150 over it
        let tall = look(bed(hb: 1600)) { $0.panel = true }
        XCTAssertEqual(lookHardware(tall, ws)["softPanel"], 2500 * 1670)
        XCTAssertEqual(line(tall, "softPanel")!.qty, 4.18, accuracy: 1e-9); XCTAssertEqual(line(tall, "softPanel")?.amount, 3135000)
        // cut to the wall: near its corner, and without a room to its made-up room's ends (10 past each side)
        let corner = look(bed(x: 150)) { $0.panel = true }
        XCTAssertEqual(lookHardware(corner, ws)["softPanel"], 2250 * 1300)
        let free = look(bed(x: W_GAP_SIDE, room: nil)) { $0.panel = true }
        XCTAssertEqual(pieceWallLen(free, "A"), 1720)
        XCTAssertEqual(bedPanelOf(free, free.modules[0]), PanelSpan(a0: -10, a1: 1710, y0: 80, y1: 1380))
        XCTAssertEqual(lookHardware(free, ws)["softPanel"], 1720 * 1300)
        // moved into the room: at the wall still its full panel, out in the room none
        var atWall = on; atWall.pose = Pose("A", 1000, 0)
        XCTAssertEqual(lookHardware(atWall, ws)["softPanel"], 2500 * 1300)
        var out = on; out.pose = Pose("A", 1000, 600)
        XCTAssertNil(lookHardware(out, ws)["softPanel"])
        // its LED along the panel's top
        let lit = look(on) { $0.led = true }
        XCTAssertEqual(lookHardware(lit, ws)["led"], 2500); XCTAssertEqual(lookHardware(lit, ws)["ledPsu"], 1)
        XCTAssertNil(lookHardware(bed(), ws)["softPanel"])
        // one rule for the 3D and the price
        XCTAssertEqual(bedPanelSpan(on.modules[0], -1000, 1e9), p)
        XCTAssertNil(bedPanelSpan(on.modules[0], -10, 150))
    }
}
