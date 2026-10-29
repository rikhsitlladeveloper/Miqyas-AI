import XCTest
@testable import METRX

/// The guest room's gorka and the big dining table (Furniture/Core/Gorka.swift, modern 3D part 6a; Android GorkaTest,
/// the same numbers): boxes, parts, hardware, seats, prices, and the saved JSON.
final class GorkaTests: XCTestCase {
    private let ws = Workshop()
    private func piece(_ id: String, _ v: [String: Int] = [:]) -> Furniture { pieceOf(fModel(id)!, v, ws, id) }
    private func gorka(_ v: [String: Int] = [:]) -> Furniture { piece("gorka", v) }
    private func hw(_ f: Furniture) -> Counts { hardware([f], ws) }
    private func qty(_ ps: [FPart], _ key: String) -> Int { ps.filter { $0.key == key }.reduce(0) { $0 + $1.qty } }
    private func cabinets(_ f: Furniture) -> [Module] { f.modules.filter { $0.type == "wardrobe" } }
    /// f with box id changed by fn.
    private func with(_ f: Furniture, _ id: String, _ fn: (inout Module) -> Void) -> Furniture {
        var g = f
        g.modules = f.modules.map { m in var n = m; if m.id == id { fn(&n) }; return n }
        return g
    }

    /* ---------------- the gallery and the steps ---------------- */

    func testBothAreInTheGuestRoomGroupWithTheirSteps() {
        let living = GALLERY.first { $0.0 == "living" }!.1
        XCTAssertTrue(living.contains("gorka")); XCTAssertTrue(living.contains("dining12"))
        XCTAssertEqual(stepsOf(fModel("gorka")!).map(\.key), ["w", "h", "tw", "tv"])
        XCTAssertEqual(stepsOf(fModel("dining12")!).map(\.key), ["w", "d", "h", "st", "lg", "tk"])
        XCTAssertEqual(stepsOf(fModel("gorka")!).map(\.usual), [3000, 2100, 500, 1])
        XCTAssertEqual(stepsOf(fModel("dining12")!).map(\.usual), [2800, 1100, 760, 1, 0, 0])
        // what was asked comes back as asked, and both are newer models with parts, hardware and a price
        for id in ["gorka", "dining12"] {
            let f = piece(id)
            XCTAssertEqual(kindKey(f), "other", id)
            let v = valsOf(f, ws)
            for s in stepsOf(fModel(id)!) { XCTAssertEqual(v[s.key], s.usual, "\(id) \(s.key)") }
            XCTAssertFalse(cutList([f], ws).isEmpty, id)
            XCTAssertEqual(costOf([f], ws, MAT_PRESETS, HW_PRESETS).missing, 0, id)
        }
        XCTAssertTrue(canStandFree(piece("dining12"))); XCTAssertFalse(canStandFree(gorka()))
        XCTAssertTrue(isItemPiece(piece("dining12"))); XCTAssertFalse(isItemPiece(gorka()))
    }

    /* ---------------- the gorka's boxes ---------------- */

    func testTheGorkaIsTwoTowersABaseABridgeAndAPanel() {
        let f = gorka()
        let r = gorkaRoles(f)!
        XCTAssertEqual(r.lows.count, 2); XCTAssertEqual(r.ups.count, 2); XCTAssertNotNil(r.bridge); XCTAssertNotNil(r.panel)
        let lo = r.lows[0], up = r.ups[0]
        // a tower: 500 × 400, its drawer box 500 high on a 60 plinth, the glass box on it up to 2100
        XCTAssertEqual(lo.x, W_GAP_SIDE); XCTAssertEqual(lo.w, 500); XCTAssertEqual(lo.d, GK_TOWER_D); XCTAssertEqual(lo.h, GK_LOW_H); XCTAssertEqual(wardBase(lo), GK_PLINTH)
        XCTAssertEqual(up.x, lo.x); XCTAssertEqual(up.elev, GK_LOW_H); XCTAssertEqual(up.elev + up.h, 2100)
        XCTAssertEqual(up.sections.count, 1)
        XCTAssertEqual(up.sections[0].face, "glass"); XCTAssertEqual(up.sections[0].inserts.filter { $0.kind == "glass" }.count, 3)
        XCTAssertEqual(up.sections[0].hinge, "R"); XCTAssertEqual(r.ups[1].sections[0].hinge, "L")
        // the floating base between the towers: 2000 × 400 × 450, 220 off the floor, three drawers
        let b = r.base!
        XCTAssertEqual(b.x, 510); XCTAssertEqual(b.w, 2000); XCTAssertEqual(b.d, GK_BASE_D); XCTAssertEqual(b.elev, GK_BASE_ELEV); XCTAssertTrue(hung(b))
        XCTAssertEqual(b.sections.count, 3)
        XCTAssertTrue(b.sections.allSatisfy { $0.fronts.kind == "open" && $0.inserts.count == 1 && $0.inserts[0].kind == "drawer" })
        // the bridge on top, 300 deep, its top level with the towers'
        let br = r.bridge!
        XCTAssertEqual(br.x, b.x); XCTAssertEqual(br.w, b.w); XCTAssertEqual(br.elev + br.h, 2100); XCTAssertEqual(br.d, GK_BRIDGE_D)
        // the panel 80 in from each tower, from the base's top to 20 under the bridge; the second tower after the base
        let p = r.panel!
        XCTAssertEqual(p.x, 590); XCTAssertEqual(p.w, 1840); XCTAssertEqual(p.elev, 620); XCTAssertEqual(p.h, 1160)
        XCTAssertEqual(p.opt?.panel, "stone"); XCTAssertEqual(p.opt?.tv, 65)
        XCTAssertEqual(r.lows[1].x, 2510)
        XCTAssertEqual(runLen(f), 3000); XCTAssertEqual(runStart(f), W_GAP_SIDE)
        // the cabinets pass the wardrobe checks
        for m in cabinets(f) {
            let c = wardrobeChecks(m, 3100, 2700, ws, [], [])
            XCTAssertTrue(c.allSatisfy { $0.level != "err" }, "\(boxRole(f, m)): \(c)")
        }
        XCTAssertEqual(cabinets(f).map { boxRole(f, $0) }, ["gk.box.low", "gk.box.tower", "gk.box.base", "gk.box.bridge", "gk.box.low", "gk.box.tower"])
    }

    func testOneTowerNoBridgeAndANarrowGorkaKeepTheNiche() {
        let f = pieceResized(gorka(), ["one": 1, "nobr": 1], ws)
        let r = gorkaRoles(f)!
        XCTAssertEqual(r.lows.count, 1); XCTAssertNil(r.bridge)
        XCTAssertEqual(r.base!.w, 2500); XCTAssertEqual(valsOf(f, ws)["w"], 3000)
        // with one tower the floating base is the run too
        XCTAssertEqual(runLen(f), 3000)
        // the panel stops where a bridge would be
        XCTAssertEqual(r.panel!.elev + r.panel!.h, 2100 - GK_BRIDGE_H - GK_PANEL_GAP)
        XCTAssertEqual(valsOf(f, ws)["one"], 1); XCTAssertEqual(valsOf(f, ws)["nobr"], 1)
        // back to two towers and a bridge
        let g = pieceResized(f, ["one": 0, "nobr": 0], ws)
        XCTAssertEqual(cabinets(g).count, 6)
        // 1800 wide: the towers give way so the niche stays 900
        let n = gorka(["w": 1800])
        XCTAssertEqual(gorkaRoles(n)!.lows[0].w, 450); XCTAssertEqual(gorkaRoles(n)!.base!.w, GK_NICHE_MIN)
    }

    func testAChangedBoxCarriesTheOthers() {
        let f = gorka()
        let r = gorkaRoles(f)!
        // the first tower's drawer box made 600 wide: its glass box follows, the base and the second tower move on
        let wider = gorkaPack(with(f, r.lows[0].id) { $0.w = 600; $0.sections = splitSections(600, $0.sections) }, r.lows[0].id, ws)
        let r2 = gorkaRoles(wider)!
        XCTAssertEqual(r2.ups[0].w, 600); XCTAssertEqual(r2.base!.x, 610); XCTAssertEqual(r2.bridge!.x, 610)
        XCTAssertEqual(r2.lows[1].x, 2610); XCTAssertEqual(r2.ups[1].x, 2610)
        XCTAssertEqual(r2.panel!.x, 690)
        // the bridge made narrower leads the base
        let br = gorkaPack(with(f, r.bridge!.id) { $0.w = 1800; $0.sections = splitSections(1800, $0.sections) }, r.bridge!.id, ws)
        XCTAssertEqual(gorkaRoles(br)!.base!.w, 1800); XCTAssertEqual(gorkaRoles(br)!.lows[1].x, 2310); XCTAssertEqual(gorkaRoles(br)!.panel!.w, 1640)
        // a lower ceiling lowers the towers; the bridge stays level with them
        let low = fitTo(f, ["A"], { _ in 3200 }, 2000, ws)
        let r3 = gorkaRoles(low)!
        XCTAssertEqual(r3.ups[0].elev + r3.ups[0].h, 1980); XCTAssertEqual(r3.bridge!.elev + r3.bridge!.h, 1980)
    }

    func testGlassDoorsPanelAndTvChangeInPlace() {
        let f = gorka()
        let solid = withGorkaGlass(f, false)
        XCTAssertFalse(gorkaGlass(solid)); XCTAssertEqual(valsOf(solid, ws)["solid"], 1)
        XCTAssertTrue(gorkaRoles(solid)!.ups.allSatisfy { u in u.sections[0].inserts.allSatisfy { $0.kind == "shelf" } })
        XCTAssertTrue(gorkaGlass(withGorkaGlass(solid, true)))
        // the doors stay as they were when the gorka is built again (new sizes)
        XCTAssertEqual(valsOf(pieceResized(solid, ["w": 3200], ws), ws)["solid"], 1)
        let slats = withGorkaPanel(f, panel: "slats", tv: 75)
        XCTAssertEqual(gorkaRoles(slats)!.panel!.opt?.panel, "slats"); XCTAssertEqual(valsOf(slats, ws)["tv"], 2)
        // a 75″ TV (1660 wide) fits the 1840 panel; an 85″ (1882) does not, nor a 55″ on the narrowest gorka
        XCTAssertTrue(tvFits(slats)); XCTAssertFalse(tvFits(withGorkaPanel(f, tv: 85)))
        XCTAssertFalse(tvFits(withGorkaPanel(gorka(["w": 1800]), tv: 55)))
        XCTAssertEqual(tvSize(65).0, 1439); XCTAssertEqual(tvSize(65).1, 809)
    }

    /// The design stays when a piece of several boxes is built again (the pieceResized fix).
    func testTheLookStaysWhenTheGorkaIsBuiltAgain() {
        let f = withLook(gorka()) { l in var n = l; n.led = true; n.crown = "cornice"; return n }
        let g = pieceResized(f, ["w": 3200], ws)
        XCTAssertEqual(g.look, f.look)
        XCTAssertEqual(g.look?.led, true); XCTAssertEqual(g.look?.crown, "cornice")
    }

    /* ---------------- parts and hardware ---------------- */

    func testTheGorkasPartsAndHardware() {
        let f = gorka()
        let parts = f.modules.flatMap { partsOf($0, ws) }
        // glass doors are bought, not cut: only the bridge's four doors are board doors (2000 / 4: each under 600)
        XCTAssertEqual(qty(parts, "fp.door"), 4)
        // five drawers: one in each tower, three in the base; each with its box
        XCTAssertEqual(qty(parts, "fp.dFace"), 5)
        XCTAssertEqual(qty(parts, "fp.dSide"), 10)
        XCTAssertEqual(qty(parts, "gk.panelBack"), 1)
        let h = hw(f)
        // the towers' glass doors (497 × 1597) and glass shelves; hinges: 3 a tower door, 2 each of the bridge's 4 doors
        XCTAssertEqual(h["glassDoor"], 2 * 497 * 1597); XCTAssertEqual(h["glassShelf"], 2 * 3 * (468 - 4) * (GK_TOWER_D - 25))
        XCTAssertEqual(h["hingeSoft"], 14); XCTAssertEqual(h["runner"], 5)
        // the glass doors open by a push latch; the drawers and the bridge's doors have handles
        XCTAssertEqual(h["push"], 2); XCTAssertEqual(h["handle"], 9)
        // four boxes hang (the glass boxes on their drawer boxes, the base, the bridge)
        XCTAssertEqual(h["hanger"], 8)
        // the panel's stone facing by the m²
        XCTAssertEqual(h["tvStone"], 1840 * 1160); XCTAssertNil(h["led"]); XCTAssertNil(h["cornice"])
        XCTAssertEqual(hw(withGorkaPanel(f, panel: "mould"))["tvMould"], 1840 * 1160)
        XCTAssertEqual(cutList([withGorkaPanel(f, panel: "mould")], ws).filter { $0.p.key == "gk.panel" }.count, 1)
    }

    func testLedAndTheNeoclassicCornice() {
        let f = withLook(gorka()) { l in var n = l; n.led = true; return n }
        let h = hw(f)
        // up both sides of each glass box, under the base and the bridge, one driver for every 5 m; no door sensors
        let mm = 2 * 2 * (1600 - 32) + (2000 - 80) + (2000 - 60)
        XCTAssertEqual(gorkaLedMm(f, ws), mm); XCTAssertEqual(h["led"], mm); XCTAssertEqual(h["ledPsu"], 3); XCTAssertNil(h["ledSensor"])
        // the neoclassic preset: milled fronts and the cornice on the towers and the bridge
        let neo = withPreset(gorka(), "neo", fresh: true)
        XCTAssertEqual(neo.look?.crown, "cornice"); XCTAssertEqual(neo.look?.style, "shaker")
        let hn = hw(neo)
        XCTAssertEqual(hn["cornice"], 500 + 500 + 2000); XCTAssertTrue((hn["frontShaker"] ?? 0) > 0)
        // a modern preset has none
        XCTAssertNil(hw(withPreset(gorka(), "twotone", fresh: true))["cornice"])
        XCTAssertEqual(withPreset(neo, "dark").look?.crown, "")
    }

    func testTheGorkaIsPricedWithItsOptions() {
        let f = withLook(withGorkaPanel(gorka(), panel: "slats")) { l in var n = l; n.led = true; n.crown = "cornice"; return n }
        let c = costOf([f], ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(c.missing, 0)
        let keys = c.lines.filter { $0.group == "hw" }.map(\.key)
        for k in ["tvSlats", "led", "ledPsu", "cornice", "glassDoor", "glassShelf", "runner", "hingeSoft"] { XCTAssertTrue(keys.contains(k), k) }
        let slats = c.lines.filter { $0.key == "tvSlats" }
        XCTAssertEqual(slats.count, 1)
        // 1840 × 1160 = 2,1344 m², up to 0,01
        XCTAssertEqual(slats[0].qty, 2.14, accuracy: 1e-9)
        XCTAssertEqual(slats[0].amount, Decimal(1_177_000))
        XCTAssertTrue(c.total > costOf([gorka()], ws, MAT_PRESETS, HW_PRESETS).total)
    }

    /* ---------------- the big dining table ---------------- */

    private func spacing(_ c: [Chair]) -> [Int] {
        let a = c.filter { $0.face == "+n" }.map(\.a).sorted()
        return zip(a, a.dropFirst()).map { $1 - $0 }
    }

    func testTheBigTableSeatsTwelveOrTen() {
        let f = piece("dining12")
        let m = wardOfF(f)!
        XCTAssertEqual(m.type, "table"); XCTAssertEqual(m.w, 2800); XCTAssertEqual(m.d, 1100); XCTAssertEqual(m.h, 760); XCTAssertEqual(m.opt?.seats, 12)
        let cs = chairPlaces(m)
        XCTAssertEqual(cs.count, 12); XCTAssertEqual(seatsOf(m), 12)
        // five a side, one at each end
        XCTAssertEqual(cs.filter { $0.face == "+n" }.count, 5); XCTAssertEqual(cs.filter { $0.face == "-n" }.count, 5)
        XCTAssertEqual(cs.filter { $0.face == "+a" }.count, 1); XCTAssertEqual(cs.filter { $0.face == "-a" }.count, 1)
        XCTAssertEqual(spacing(cs), [540, 540, 540, 540])
        // the side chairs stay within the table's length, centred, out from its edges
        let side = cs.filter { $0.face == "+n" }
        let lo = side.map(\.a).min()!, hi = side.map(\.a).max()!
        XCTAssertTrue(lo - DT_CHAIR_W / 2 >= 0 && hi + DT_CHAIR_W / 2 <= m.w)
        XCTAssertEqual(lo + hi, m.w)
        XCTAssertTrue(cs.filter { $0.face == "+n" }.allSatisfy { $0.n == -DT_CHAIR_OUT })
        XCTAssertTrue(cs.filter { $0.face == "-n" }.allSatisfy { $0.n == m.d + DT_CHAIR_OUT })
        // ten: four a side, further apart
        let ten = wardOfF(pieceResized(f, ["st": 0], ws))!
        XCTAssertEqual(seatsOf(ten), 10); XCTAssertEqual(spacing(chairPlaces(ten)), [620, 620, 620])
        // a table too short for twelve takes fewer, never closer than the pitch
        let short = wardOfF(pieceResized(f, ["w": 1800], ws))!
        XCTAssertEqual(short.opt?.seats, 12); XCTAssertEqual(seatsOf(short), 8)
        XCTAssertTrue(spacing(chairPlaces(short)).allSatisfy { $0 >= DT_PITCH })
        // an ordinary dining table has no chairs
        XCTAssertTrue(chairPlaces(wardOfF(piece("dining"))!).isEmpty)
    }

    func testTheBigTablesPartsHardwareAndPrice() {
        let f = piece("dining12")
        let m = wardOfF(f)!
        let parts = partsOf(m, ws)
        // two panel legs of two boards each, a rail between them; the top is worktop board, not cut
        XCTAssertEqual(qty(parts, "fp.tLeg"), 4); XCTAssertEqual(qty(parts, "fp.apron"), 1)
        XCTAssertTrue(parts.allSatisfy { $0.key != "fp.top" })
        XCTAssertEqual(topStrips(m), 2); XCTAssertEqual(itemWorktopMm(m), 5600)
        let h = hw(f)
        XCTAssertEqual(h["confirmat"], 16); XCTAssertEqual(h["wtJoint"], 1); XCTAssertNil(h["tableLeg"])
        let c = costOf([f], ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(c.missing, 0)
        let wt = c.lines.filter { $0.key == "wt38m" }
        XCTAssertEqual(wt.count, 1)
        XCTAssertEqual(wt[0].qty, 5.6, accuracy: 1e-9); XCTAssertEqual(wt[0].amount, Decimal(56 * 420_000 / 10))
        // metal legs and a wood top
        let g = pieceResized(f, ["lg": 1, "tk": 1], ws)
        XCTAssertEqual(wardOfF(g)?.opt?.legs, "metal4"); XCTAssertEqual(g.mats.top, "wt38h")
        XCTAssertEqual(valsOf(g, ws)["tk"], 1); XCTAssertEqual(valsOf(g, ws)["lg"], 1)
        XCTAssertEqual(hw(g)["tableLeg"], 4); XCTAssertEqual(hw(g)["confirmat"], 8)
        XCTAssertTrue(costOf([g], ws, MAT_PRESETS, HW_PRESETS).lines.contains { $0.key == "wt38h" })
        // back to stone keeps a stone decor
        XCTAssertEqual(pieceResized(g, ["tk": 0], ws).mats.top, "wt38m")
        XCTAssertEqual(dtTop("stone", "wt38o"), "wt38o"); XCTAssertEqual(dtTop("wood", "wt38c"), "wt38c")
        // its designer's sizes
        XCTAssertEqual(itemRange(m, "w"), 1800...3600); XCTAssertEqual(itemRange(m, "d"), 900...1300)
        // an older dining table is priced as before
        XCTAssertEqual(itemWorktopMm(wardOfF(piece("dining", ["tp": 1]))!), 1400)
    }

    /* ---------------- the saved JSON ---------------- */

    /// Keys sorted: JSONEncoder's own key order is not fixed from one call to the next.
    private func encode<T: Encodable>(_ v: T) -> String {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        return String(decoding: try! e.encode(v), as: UTF8.self)
    }

    func testTheNewOptionsAreWrittenOnlyWhenSet() throws {
        // an older piece's options keep their saved form: no seats, panel or tv
        let plain = encode(ItemOpt())
        XCTAssertFalse(plain.contains("\"seats\"")); XCTAssertFalse(plain.contains("\"panel\"")); XCTAssertFalse(plain.contains("\"tv\""))
        XCTAssertEqual(plain, #"{"bed":"legs","foot":true,"hb":1000,"hooks":5,"ladder":"R","legs":"board","mirH":0,"mirW":0,"ml":2000,"mw":1600,"# +
                       #""over":300,"round":false,"shelf":true,"shelves":true,"top":"ldsp","under":"desk"}"#)
        // the big table's seats and the panel's facing and TV are written, and read back
        let table = ItemOpt(legs: "metal4", top: "wt", seats: 12)
        XCTAssertTrue(encode(table).contains("\"seats\":12")); XCTAssertFalse(encode(table).contains("\"tv\""))
        let panel = ItemOpt(panel: "slats", tv: 75)
        let s = encode(panel)
        XCTAssertTrue(s.contains("\"panel\":\"slats\"")); XCTAssertTrue(s.contains("\"tv\":75")); XCTAssertFalse(s.contains("\"seats\""))
        XCTAssertEqual(try JSONDecoder().decode(ItemOpt.self, from: Data(encode(table).utf8)), table)
        XCTAssertEqual(try JSONDecoder().decode(ItemOpt.self, from: Data(s.utf8)), panel)
        // a whole gorka and a big table round-trip as they are
        for f in [gorka(), piece("dining12")] {
            let back = try JSONDecoder().decode(Furniture.self, from: Data(encode(f).utf8))
            XCTAssertEqual(back, f, f.type)
            XCTAssertEqual(encode(back), encode(f), f.type)
        }
    }
}
