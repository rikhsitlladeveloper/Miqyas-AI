import XCTest
@testable import METRX

/// The founder's answers of 26 Oct 2026: a kupe's end without a wall gets a side panel of the fronts' board; the
/// neoclassic preset puts the cornice on tall wardrobes and kupe too; a Gola kitchen's wall units open by a push latch;
/// a kitchen vitrina's LED inside is priced and its accent back cut from the accent board (Android Founder26OctTest,
/// the same cases and numbers).
final class Founder26OctTests: XCTestCase {
    private let ws = Workshop()
    private let rgb: (String) -> Int = { _ in 0xCDBFAE }
    private let noTex: (String) -> String? = { _ in nil }

    private func cost(_ f: Furniture) -> Cost { costOf([f], ws, MAT_PRESETS, HW_PRESETS, order: false) }
    private func line(_ f: Furniture, _ key: String) -> CostLine? {
        let ls = cost(f).lines.filter { $0.key == key }
        return ls.count == 1 ? ls[0] : nil
    }
    private func mats(_ f: Furniture, _ key: String) -> Set<String> {
        var out = Set<String>()
        for (p, m) in partsWithMat(f, ws) where p.key == key { out.insert(m) }
        return out
    }
    private func part(_ m: Module, _ key: String) -> FPart? {
        let ps = partsOf(m, ws).filter { $0.key == key }
        return ps.count == 1 ? ps[0] : nil
    }
    private func noSides(_ f: Furniture) -> Furniture {
        var g = f
        g.modules = f.modules.map { m in var x = m; x.sideL = false; x.sideR = false; return x }
        return g
    }

    /// A room-less built-in kupe 1800 × 2500 × 600, two doors (gallery model s2).
    private func kupe() -> Furniture {
        var f = newFreeWardrobe("Kupe", "s2", 1800, 2500, 600, true, "slide", ws, n: 2)
        f.id = "s"
        f.modules = f.modules.map { m in var x = m; x.id = "sm"; return x }
        return f
    }

    /// How many side boards of f the 3D draws (lit up as Bazis lights the parts list's "fp.side" of the fronts' board).
    private func sides3D(_ f: Furniture) -> Int {
        var mods = Set<String>()
        for m in f.modules { mods.insert(f.id + "|" + (m.label.isEmpty ? m.id : m.label)) }
        let d = furniture3D([f], buildShell([freeRoom(f)], single: true).bases, ws, rgb, [], hi: PartHi("fp.side", "front", mods), tex: noTex, detail: .flat)
        let hi = pieceLooks(f, rgb, noTex, MAT_PRESETS)["hi"]
        var n = 0
        for p in d.parts where p.look == hi { n += p.faces.count }
        return n / 6
    }

    /// The faces drawn in look key of f.
    private func faces(_ d: Furn3D, _ f: Furniture, _ key: String) -> Int {
        let l = pieceLooks(f, rgb, noTex, MAT_PRESETS)[key]
        var n = 0
        for p in d.parts where p.look == l { n += p.faces.count }
        return n
    }

    /* ---------------- 1. a kupe's ends without a wall ---------------- */

    func testARoomlessKupeHasASidePanelAtEachEnd() {
        let k = kupe()
        let m = k.modules[0]
        XCTAssertTrue(m.sideL && m.sideR)
        // its full height and depth, of the fronts' board, two of them
        let side = part(m, "fp.side")
        XCTAssertEqual(side?.L, 2500); XCTAssertEqual(side?.W, 600); XCTAssertEqual(side?.qty, 2)
        XCTAssertEqual(side?.role, "front"); XCTAssertEqual(mats(k, "fp.side"), ["ldsp16k"])
        // the doors close the opening between them: 1768 wide, two doors 899 each
        XCTAssertEqual(slideOpening(m, ws.t).0, 1768)
        XCTAssertEqual(slideDoor(m, ws.t).0, 899); XCTAssertEqual(slideDoor(m, ws.t).1, 2348)
        // in the 3D, the cut list and the labels
        XCTAssertEqual(sides3D(k), 2)
        XCTAssertTrue(cutList([k], ws).contains { $0.mat == "ldsp16k" && $0.p.key == "fp.side" && $0.p.qty == 2 && $0.p.L == 2500 && $0.p.W == 600 })
        XCTAssertEqual(labelsOf([k], ws).filter { $0.key == "fp.side" && $0.mat == "ldsp16k" && $0.L == 2500 && $0.W == 600 }.count, 2)
        // and in the price: the two sides' 3.0 m² of the fronts' board (its top, plinth and door boards 32 mm narrower:
        // 2.905 m² more in all; still 2 sheets, 1 380 000) and their banding, 21 m (16 without)
        let old = noSides(k)
        XCTAssertEqual(sides3D(old), 0)
        func area(_ f: Furniture) -> Int {
            var a = 0
            for r in cutList([f], ws) where r.mat == "ldsp16k" { a += r.p.L * r.p.W * r.p.qty }
            return a
        }
        XCTAssertEqual(area(k) - area(old), 2905472)
        XCTAssertEqual(line(k, "ldsp16k")?.qty, 2); XCTAssertEqual(line(k, "ldsp16k")?.amount, 1380000)
        XCTAssertEqual(line(k, "band2")?.qty, 21); XCTAssertEqual(line(k, "band2")?.amount, 94500)
        XCTAssertEqual(line(old, "band2")?.qty, 16)
    }

    func testAnOlderRoomlessKupeGetsItsSidePanelsBack() {
        let old = noSides(kupe())
        let healed = withKupeEnds(old)
        XCTAssertTrue(healed.modules[0].sideL && healed.modules[0].sideR)
        XCTAssertEqual(sides3D(healed), 2)
        // nothing to do: the same piece; a kupe in a room keeps what its walls gave it; a hinged wardrobe is left alone
        XCTAssertEqual(withKupeEnds(healed), healed)
        var inRoom = old; inRoom.roomId = "r"
        XCTAssertEqual(withKupeEnds(inRoom), inRoom)
        let hinged = newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, true, "door", ws)
        XCTAssertEqual(withKupeEnds(hinged), hinged)
        // the store heals a saved order once, and leaves one with nothing to heal as it is
        var p = Project(id: "p", name: "A")
        p.furniture = [old, hinged]
        let q = Store.kupeEnds(p)
        XCTAssertTrue(q.furniture[0].modules[0].sideL && q.furniture[0].modules[0].sideR)
        XCTAssertEqual(Store.kupeEnds(q), q)
    }

    func testAKupeInARoomHasASidePanelAtAFreeEndOnly() {
        var k = kupe(); k.roomId = "r"
        var m = k.modules[0]; m.x = W_GAP_SIDE; m.wall = "A"
        // in the corner of a 3,0 m wall: none at the wall, one at the end in the room
        let corner = kupeSides(k, m, 3000)
        XCTAssertFalse(corner.sideL); XCTAssertTrue(corner.sideR); XCTAssertEqual(part(corner, "fp.side")?.qty, 1)
        // wall to wall: none; in the middle of the wall: both; the wall not known, or standing free: both
        var full = m; full.w = 1800
        XCTAssertNil(part(kupeSides(k, full, 1820), "fp.side"))
        var mid = m; mid.x = 600
        let a = kupeSides(k, mid, 3000); XCTAssertTrue(a.sideL && a.sideR)
        let b = kupeSides(k, m, nil); XCTAssertTrue(b.sideL && b.sideR)
        var posed = k; posed.pose = Pose("A", 0, 900)
        let c = kupeSides(posed, m, 3000); XCTAssertTrue(c.sideL && c.sideR)
        // without a room: both, whatever the made-up room's walls
        var free = k; free.roomId = nil
        var bare = m; bare.sideL = false; bare.sideR = false
        let e = kupeSides(free, bare, 1820); XCTAssertTrue(e.sideL && e.sideR)
        // a hinged wardrobe is not a kupe: as it is
        var h = m; h.slide = nil; h.sideL = false
        XCTAssertEqual(kupeSides(k, h, 3000), h)
    }

    /* ---------------- 2. the neoclassic cornice on tall wardrobes and kupe ---------------- */

    func testNeoclassicPutsTheCorniceOnTallWardrobesAndKupe() {
        // a kupe without a room: along its top (no free end in its made-up room), 2.4 m, 3 whole metres at 65 000
        let k = withPreset(newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws), "neo", ws: ws)
        XCTAssertEqual(k.look?.crown, "cornice"); XCTAssertEqual(crownOf(k), "cornice")
        XCTAssertEqual(lookHardware(k, ws)["cornice"], 2400)
        XCTAssertEqual(line(k, "cornice")?.qty, 3); XCTAssertEqual(line(k, "cornice")?.price, 65000); XCTAssertEqual(line(k, "cornice")?.amount, 195000)
        // a hinged wardrobe 1000 × 2200: 1 m
        let h = withPreset(newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, false, "door", ws), "neo", ws: ws)
        XCTAssertEqual(h.look?.crown, "cornice"); XCTAssertEqual(line(h, "cornice")?.amount, 65000)
        // in a room, 500 from the corner with its side panels: both ends turn back, 1800 + 2 × 676 = 3152, 4 m
        var r0 = newFreeWardrobe("Shkaf", "d3", 1800, 2200, 600, false, "door", ws)
        r0.roomId = "r"
        r0.modules = r0.modules.map { m in var x = m; x.x = 500; return x }
        let r = withPreset(r0, "neo", ws: ws)
        XCTAssertEqual(lookHardware(r, ws)["cornice"], 3152); XCTAssertEqual(line(r, "cornice")?.amount, 260000)
        // a low one (its top under 1800) takes none; nor a bed
        let low = withPreset(newFreeWardrobe("Shkaf", "h2", 1000, 1700, 600, false, "door", ws), "neo", ws: ws)
        XCTAssertEqual(low.look?.crown, ""); XCTAssertNil(line(low, "cornice"))
        let bed = Furniture(id: "b", kind: "wardrobe", modules: [Module(id: "bm", type: "bed", w: 1700, h: 450, d: 2100, opt: ItemOpt(bed: "legs", hb: 1100))], type: "bed")
        XCTAssertEqual(withPreset(bed, "neo", ws: ws).look?.crown, "")
        // the other presets leave the crown as it is: kept on the neoclassic one, none on a new one
        for id in ["twotone", "gloss", "gola", "wood", "dark"] {
            XCTAssertEqual(withPreset(k, id, ws: ws).look?.crown, "cornice", id)
            XCTAssertEqual(withPreset(newFreeWardrobe("Kupe", "s3", 2400, 2500, 600, true, "slide", ws), id, ws: ws).look?.crown, "", id)
        }
        XCTAssertEqual(withPreset(withCrown(k, "ceiling"), "gloss", ws: ws).look?.crown, "ceiling")
        // a kitchen's own cornice as before (its extras), a gorka's as before
        let kit = withPreset(newFreeKitchen("Oshxona 1", "I", "I", [3000], 0, 2700, ws), "neo", ws: ws)
        XCTAssertEqual(kit.kx?.cornice, true); XCTAssertEqual(kit.look?.crown, "")
    }

    /* ---------------- 3. a Gola kitchen's wall units open by a push latch ---------------- */

    private func at(_ kind: String, _ id: String, _ x: Int) -> Module { var m = template(kind, ws, "A"); m.id = id; m.x = x; return m }

    func testAGolaKitchensWallUnitsOpenByAPushLatch() {
        var flap = at("wall", "fl", 1200); flap.fronts = Fronts("door", 1); flap.inserts = [Insert("lift")]
        let mods = [at("base", "b", 0), at("drawers", "d", 600), at("wall", "w", 0), at("vitrina", "v", 600), flap]
        let k = Furniture(id: "k", kind: "kitchen", walls: ["A"], modules: mods)
        let g = withHandleType(k, "gola")
        XCTAssertEqual(g.handle, GOLA)
        let hw = hardware([g], ws)
        // no handle at all; a latch for each wall unit's door and flap: 2 + 2 glass + 1 flap
        XCTAssertNil(hw["handle"]); XCTAssertEqual(hw["push"], 5)
        // the base units keep their channels: one over the door unit, one over each of the 3 drawers
        XCTAssertEqual(hw["gola"], 600 + 3 * 600)
        XCTAssertEqual(line(g, "push")?.qty, 5); XCTAssertEqual(line(g, "push")?.amount, 150000)
        // the usual handles before: 2 + 3 on the base units, 5 on the wall units
        XCTAssertEqual(hardware([k], ws)["handle"], 10); XCTAssertNil(hardware([k], ws)["push"])
        // the 3D shows no handle on any front (the plain kitchen shows its handles)
        let bases = buildShell([freeRoom(g)], single: true).bases
        XCTAssertEqual(faces(furniture3D([g], bases, ws, rgb, [], tex: noTex), g, "handle"), 0)
        XCTAssertGreaterThan(faces(furniture3D([k], bases, ws, rgb, [], tex: noTex), k, "handle"), 0)
    }

    /* ---------------- 4. the kitchen vitrina's LED and accent back ---------------- */

    private func row(_ n: Int, led: Bool, look: PieceLook? = nil, accentIn: Bool = false) -> Furniture {
        var ms: [Module] = []
        for i in 0..<n { ms.append(at("wall", "w\(i)", 600 * i)) }
        var v = at("vitrina", "v", 600 * n); v.accentIn = accentIn
        ms.append(v)
        return Furniture(id: "k", kind: "kitchen", walls: ["A"], modules: ms, kx: KExtras(led: led), look: look)
    }

    func testAVitrinasLedInsideIsPricedWithTheKitchensLed() {
        // two board wall units and a vitrina: 1800 under the wall units, 600 inside the vitrina; one driver
        let k = row(2, led: true)
        XCTAssertEqual(vitrinaLedMm(k), 600)
        let hw = hardware([k], ws)
        XCTAssertEqual(hw["led"], 2400); XCTAssertEqual(hw["ledPsu"], 1)
        XCTAssertEqual(line(k, "led")?.qty, 3); XCTAssertEqual(line(k, "led")?.amount, 105000)
        XCTAssertEqual(line(k, "ledPsu")?.amount, 120000)
        // its share of the drivers: 4800 under and 600 inside take a second one (4800 alone, one)
        let long = row(7, led: true)
        XCTAssertEqual(hardware([long], ws)["led"], 5400); XCTAssertEqual(hardware([long], ws)["ledPsu"], 2)
        XCTAssertEqual(line(long, "ledPsu")?.amount, 240000)
        // only with the kitchen's LED on
        let off = row(2, led: false)
        XCTAssertEqual(vitrinaLedMm(off), 0); XCTAssertNil(hardware([off], ws)["led"]); XCTAssertNil(hardware([off], ws)["ledPsu"])
        // a board wall unit has none inside
        var board = k
        board.modules = k.modules.map { withGlassDoors($0, false) }
        XCTAssertEqual(vitrinaLedMm(board), 0); XCTAssertEqual(hardware([board], ws)["led"], 1800)
    }

    func testAVitrinasAccentBackIsCutFromTheAccentBoard() {
        let wood = PieceLook(accent: "wd_walnut")
        let k = row(0, led: false, look: wood, accentIn: true)
        XCTAssertTrue(vitrinaAccentBack(k, k.modules[0]))
        // the back 716 × 596 of the walnut accent: in the cut list, the labels and the price (0.43 m² at 110 000)
        XCTAssertEqual(mats(k, "fp.back"), ["wd_walnut"])
        XCTAssertTrue(cutList([k], ws).contains { $0.mat == "wd_walnut" && $0.p.key == "fp.back" && $0.p.L == 716 && $0.p.W == 596 })
        XCTAssertEqual(labelsOf([k], ws).filter { $0.key == "fp.back" }.map(\.mat), ["wd_walnut"])
        let wl = line(k, "wd_walnut")
        XCTAssertEqual(wl?.unit, "m2"); XCTAssertEqual(wl?.qty ?? 0, 0.43, accuracy: 1e-9); XCTAssertEqual(wl?.amount, 47300)
        XCTAssertNil(line(k, "hdf3"))
        // without the accent inside, or without an accent in the look: the usual back board
        let plain = row(0, led: false, look: wood)
        XCTAssertEqual(mats(plain, "fp.back"), ["hdf3"]); XCTAssertNil(line(plain, "wd_walnut"))
        XCTAssertEqual(line(plain, "hdf3")?.amount, 210000)
        let noAccent = row(0, led: false, look: PieceLook(), accentIn: true)
        XCTAssertFalse(vitrinaAccentBack(noAccent, noAccent.modules[0])); XCTAssertEqual(mats(noAccent, "fp.back"), ["hdf3"])
        // the other parts keep their boards
        XCTAssertEqual(mats(k, "fp.side"), ["ldsp16w"])
    }
}
